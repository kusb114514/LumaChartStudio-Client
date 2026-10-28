param(
    [Parameter(Mandatory = $true)]
    [string]$OutputRoot,
    [string]$IsccPath = "",
    [string]$IconFile =
        (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\Assets\app-icon.ico"),
    # Defaults to the Version declared in LumaChart.Avalonia.csproj (or to the
    # 1.1.0 migration baseline under -FormalMigrationAuthority); see below.
    [ValidatePattern('^\d+\.\d+\.\d+(?:\.\d+)?(?:-[0-9A-Za-z][0-9A-Za-z.-]*)?$')]
    [string]$PreviewVersion = "",
    [string]$PreviewFileVersion = "",
    [string]$PreviewDisplayVersion = "",
    [switch]$AllowUpgradeFixtureVersion,
    [switch]$FormalMigrationAuthority
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia installer build requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$output = [IO.Path]::GetFullPath($OutputRoot)
$releaseRoot = [IO.Path]::GetFullPath(
    (Join-Path $projectRoot "release")).TrimEnd('\')
if ([string]::IsNullOrWhiteSpace($IsccPath)) {
    $isccCandidates = @(
        (Join-Path $projectRoot ".codex-tools\inno-setup-7.0.2\portable\ISCC.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe")
    )
    if (${env:ProgramFiles(x86)}) {
        $isccCandidates += Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"
    }
    if ($env:ProgramFiles) {
        $isccCandidates += Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe"
    }
    $isccCandidates = $isccCandidates | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and
        (Test-Path -LiteralPath $_ -PathType Leaf)
    }
    $IsccPath = $isccCandidates | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($IsccPath)) {
        throw "Inno Setup compiler was not found; pass -IsccPath explicitly."
    }
}
$iscc = [IO.Path]::GetFullPath($IsccPath)
$icon = [IO.Path]::GetFullPath($IconFile)
$installerScript = Join-Path $projectRoot "installer\LumaChartAvaloniaPreview.iss"
$project = Join-Path $projectRoot "LumaChart.Avalonia\LumaChart.Avalonia.csproj"

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "Missing file: $full"
    $item = Get-Item -LiteralPath $full
    [ordered]@{
        path = if ($full.StartsWith(
                $projectRoot + '\',
                [StringComparison]::OrdinalIgnoreCase)) {
            [IO.Path]::GetRelativePath($projectRoot, $full)
        }
        else {
            $full
        }
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Invoke-LoggedCommand(
    [string]$Executable,
    [string[]]$Arguments,
    [string]$LogPath,
    [string]$Label)
{
    & $Executable @Arguments 2>&1 |
        Set-Content -LiteralPath $LogPath -Encoding utf8NoBOM
    if ($LASTEXITCODE -ne 0) {
        Get-Content -LiteralPath $LogPath -Tail 100
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

# The version comes from one place: the Version the Windows project declares,
# which is what the published binary and the client itself report. The script
# used to default to a fixed 1.1.0, so an installer built without
# -PreviewVersion carried a version the program inside it did not have.
Assert (Test-Path -LiteralPath $project -PathType Leaf) "Missing input: $project"
$projectXml = [xml](Get-Content -LiteralPath $project -Raw)
$productVersion = [string](@($projectXml.Project.PropertyGroup |
    ForEach-Object { $_.Version } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) | Select-Object -First 1)
Assert (-not [string]::IsNullOrWhiteSpace($productVersion)) (
    "LumaChart.Avalonia.csproj does not declare a Version.")
$productVersion = $productVersion.Trim()

# 1.1.0 is the formal WPF-to-Avalonia migration baseline, not the product
# version. The installer lifecycle evidence harness (the InstallerLifecycle and
# RunningClientRepair capture/verify scripts and Test-WindowsAvaloniaPreviewInstaller)
# builds with -FormalMigrationAuthority and asserts exactly 1.1.0 above a 1.0.9
# fixture, so a formal-authority build keeps that baseline. Any other version
# than the one expected here is a controlled upgrade fixture.
$migrationBaselineVersion = "1.1.0"
$expectedPreviewVersion = if ($FormalMigrationAuthority) {
    $migrationBaselineVersion
}
else {
    $productVersion
}
if (-not $PSBoundParameters.ContainsKey('PreviewVersion')) {
    $PreviewVersion = $expectedPreviewVersion
}

$previewVersionMatch = [regex]::Match(
    $PreviewVersion,
    '^(?<numeric>\d+\.\d+\.\d+(?:\.\d+)?)(?:-[0-9A-Za-z][0-9A-Za-z.-]*)?$')
Assert ($previewVersionMatch.Success) (
    "PreviewVersion must start with a normalized numeric version.")
$previewNumericVersion = $previewVersionMatch.Groups['numeric'].Value
$parsedPreviewVersion = $null
Assert ([Version]::TryParse(
        $previewNumericVersion,
        [ref]$parsedPreviewVersion)) (
    "PreviewVersion must begin with a valid numeric version.")
$previewVersionComponents = $previewNumericVersion.Split('.').Count
Assert ($parsedPreviewVersion.ToString($previewVersionComponents) -ceq $previewNumericVersion) (
    "PreviewVersion numeric prefix must be normalized.")
if ([string]::IsNullOrWhiteSpace($PreviewFileVersion)) {
    $PreviewFileVersion = if ($previewVersionComponents -eq 3) {
        "$previewNumericVersion.0"
    }
    else {
        $previewNumericVersion
    }
}
$parsedPreviewFileVersion = $null
Assert ([Version]::TryParse(
        $PreviewFileVersion,
        [ref]$parsedPreviewFileVersion)) (
    "PreviewFileVersion must be a valid numeric version.")
Assert ($parsedPreviewFileVersion.ToString($PreviewFileVersion.Split('.').Count) -ceq $PreviewFileVersion) (
    "PreviewFileVersion must be normalized.")
if ([string]::IsNullOrWhiteSpace($PreviewDisplayVersion)) {
    $PreviewDisplayVersion = $PreviewVersion
}
# A prerelease label on the expected version is still that version; only a
# different number makes the build an upgrade fixture.
$expectedNumericVersion = [regex]::Match(
    $expectedPreviewVersion,
    '^\d+\.\d+\.\d+(?:\.\d+)?').Value
$controlledUpgradeFixture = $previewNumericVersion -cne $expectedNumericVersion
if ($controlledUpgradeFixture) {
    Assert ($AllowUpgradeFixtureVersion) (
        "PreviewVersion $PreviewVersion is not $expectedPreviewVersion; a controlled upgrade fixture requires AllowUpgradeFixtureVersion.")
    Assert (-not $FormalMigrationAuthority) (
        "A controlled upgrade fixture cannot be formal migration authority.")
}
Assert (-not (Test-Path -LiteralPath $output)) (
    "Installer build output root already exists: $output")
Assert (-not $output.Equals(
    $releaseRoot,
    [StringComparison]::OrdinalIgnoreCase)) (
    "Avalonia preview installer must not write to the reserved release root.")
Assert (-not $output.StartsWith(
    $releaseRoot + '\',
    [StringComparison]::OrdinalIgnoreCase)) (
    "Avalonia preview installer output must not be inside release.")
foreach ($file in @(
    $iscc,
    $icon,
    $installerScript,
    $project)) {
    Assert (Test-Path -LiteralPath $file -PathType Leaf) "Missing input: $file"
}
$isccSignature = Get-AuthenticodeSignature -LiteralPath $iscc
Assert ($isccSignature.Status -eq [Management.Automation.SignatureStatus]::Valid) (
    "ISCC Authenticode signature is not valid.")

New-Item -ItemType Directory -Path $output | Out-Null
$publishRoot = Join-Path $output "publish"
$installerRoot = Join-Path $output "installer"
$logRoot = Join-Path $output "logs"
$runtimeTemp = Join-Path $output "temp"
$portableDataRoot = Join-Path $output "portable-data"
$portableLocalData = Join-Path $portableDataRoot "local-data"
$portableEditing = Join-Path $portableDataRoot "editing"
$portableWorkspace = Join-Path $portableDataRoot "workspace"
foreach ($directory in @(
        $publishRoot,
        $installerRoot,
        $logRoot,
        $runtimeTemp,
        $portableLocalData,
        $portableEditing,
        $portableWorkspace)) {
    New-Item -ItemType Directory -Path $directory | Out-Null
}
$dotnetHome = Join-Path $projectRoot ".codex-dotnet-home"
$nugetPackages = Join-Path $projectRoot ".codex-nuget-packages"
$nugetHttpCache = Join-Path $projectRoot ".codex-nuget-http-cache"
foreach ($directory in @($dotnetHome, $nugetPackages, $nugetHttpCache)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}
$env:DOTNET_CLI_HOME = $dotnetHome
$env:NUGET_PACKAGES = $nugetPackages
$env:NUGET_HTTP_CACHE_PATH = $nugetHttpCache
$env:TEMP = $runtimeTemp
$env:TMP = $runtimeTemp

$restoreLog = Join-Path $logRoot "restore-win-x64.log"
$publishLog = Join-Path $logRoot "publish-win-x64.log"
$isccLog = Join-Path $logRoot "iscc.log"
Invoke-LoggedCommand "dotnet" @(
    "restore",
    $project,
    "-r",
    "win-x64",
    "-p:TreatWarningsAsErrors=true",
    "-nologo",
    "-v:minimal") $restoreLog "win-x64 restore"
Invoke-LoggedCommand "dotnet" @(
    "publish",
    $project,
    "-c",
    "Release",
    "-r",
    "win-x64",
    "--self-contained",
    "true",
    "--no-restore",
    "-warnaserror",
    "-p:TreatWarningsAsErrors=true",
    "-p:PublishSingleFile=false",
    "-p:PublishAot=false",
    "-p:PublishTrimmed=false",
    "-p:Version=$PreviewVersion",
    "-p:AssemblyVersion=$PreviewFileVersion",
    "-p:FileVersion=$PreviewFileVersion",
    "-p:InformationalVersion=$PreviewVersion",
    "-o",
    $publishRoot,
    "-nologo",
    "-v:minimal") $publishLog "ordinary .NET self-contained publish"

$publishedApp = Join-Path $publishRoot "LumaChart.Avalonia.exe"
$publishedAppEvidence = File-Evidence $publishedApp
$publishedVersion = (Get-Item -LiteralPath $publishedApp).VersionInfo
$publishedFiles = @(
    Get-ChildItem -LiteralPath $publishRoot -Recurse -File)
$publishedBytes = [long](
    $publishedFiles | Measure-Object Length -Sum).Sum
Assert ($publishedVersion.FileVersion -ceq $PreviewFileVersion -and
    $publishedVersion.ProductVersion -like "$PreviewVersion*") (
    "Published Avalonia binary version metadata does not match $PreviewVersion / $PreviewFileVersion.")
Assert ($publishedFiles.Count -ge 500) (
    "Published self-contained payload is unexpectedly small.")
Assert (Test-Path -LiteralPath (
    Join-Path $publishRoot "README.md") -PathType Leaf) (
    "Published README.md is missing.")
Assert (Test-Path -LiteralPath (
    Join-Path $publishRoot "THIRD-PARTY-NOTICES.md") -PathType Leaf) (
    "Published THIRD-PARTY-NOTICES.md is missing.")
# NAIST/ICOT requires its notice on every copy of the IPADIC dictionary, and
# OFL 1.1 requires its text to accompany the font. Both are in the payload, so
# shipping without these files is a licence breach rather than an omission.
foreach ($licenceFile in @(
        "LICENSE",
        "licenses\IPADIC-COPYING.txt",
        "licenses\IPADIC-AUTHORS.txt",
        "licenses\OFL-1.1-SourceHanSans.txt")) {
    Assert (Test-Path -LiteralPath (
        Join-Path $publishRoot $licenceFile) -PathType Leaf) (
        "Published $licenceFile is missing; the payload carries the IPADIC " +
        "dictionary and the bundled font, whose licences require it.")
}
Assert (-not (Test-Path -LiteralPath (
    Join-Path $publishRoot "LumaChart.ClientSecurity.dll"))) (
    "Forbidden historical native ClientSecurity payload was published.")

$portableLauncher = Join-Path $output "Run-Portable-Demo.cmd"
$portableLauncherText = @"
@echo off
setlocal
set "DEMO_ROOT=%~dp0"
set "LUMACHART_AVALONIA_LOCAL_DATA_ROOT=%DEMO_ROOT%portable-data\local-data"
set "LUMACHART_AVALONIA_EDITING_ROOT=%DEMO_ROOT%portable-data\editing"
if not exist "%DEMO_ROOT%portable-data\local-data\workspace.json" set "LUMACHART_AVALONIA_WORKSPACE_ROOT=%DEMO_ROOT%portable-data\workspace"
set "LUMACHART_AVALONIA_SINGLE_INSTANCE_SCOPE=preview-portable"
start "LumaChart Studio Avalonia Preview" "%DEMO_ROOT%publish\LumaChart.Avalonia.exe"
endlocal
"@
[IO.File]::WriteAllText(
    $portableLauncher,
    $portableLauncherText.Replace("`n", "`r`n"),
    [Text.UTF8Encoding]::new($false))

Invoke-LoggedCommand $iscc @(
    "/DSourceDir=$publishRoot",
    "/DOutputDir=$installerRoot",
    "/DIconFile=$icon",
    "/DAppVersion=$PreviewDisplayVersion",
    "/DAppFileVersion=$PreviewFileVersion",
    $installerScript) $isccLog "Inno Setup compile"
$setup = Join-Path $installerRoot (
    "LumaChartStudio-Avalonia-Preview-Setup.exe")
$setupEvidence = File-Evidence $setup
$setupVersion = (Get-Item -LiteralPath $setup).VersionInfo
Assert ($setupVersion.FileVersion.Trim() -ceq $PreviewFileVersion -and
    $setupVersion.ProductVersion.Trim() -ceq $PreviewFileVersion) (
    "Compiled preview installer version metadata does not match $PreviewDisplayVersion / $PreviewFileVersion.")

$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.preview-installer-build.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = if ($FormalMigrationAuthority) {
        "passed-migration-incomplete"
    }
    elseif ($controlledUpgradeFixture) {
        "upgrade-fixture-passed-nonformal"
    }
    else {
        "preflight-passed-nonformal"
    }
    formalMigrationAuthority = [bool]$FormalMigrationAuthority
    completion = $false
    migrationComplete = $false
    windowsAvaloniaOnly = $true
    pureDotnetRelease = $true
    selfContained = $true
    publishSingleFile = $false
    publishTrimmed = $false
    publishAot = $false
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    productionServerMutationPerformed = $false
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    previewVersion = $PreviewVersion
    previewDisplayVersion = $PreviewDisplayVersion
    previewFileVersion = $PreviewFileVersion
    productVersion = $productVersion
    controlledUpgradeFixture = [bool]$controlledUpgradeFixture
    paths = [ordered]@{
        outputRoot = $output
        publishRoot = $publishRoot
        installerRoot = $installerRoot
        portableDataRoot = $portableDataRoot
        portableLauncher = $portableLauncher
        temp = $runtimeTemp
        dotnetHome = $dotnetHome
        nugetPackages = $nugetPackages
        nugetHttpCache = $nugetHttpCache
    }
    toolchain = [ordered]@{
        iscc = File-Evidence $iscc
        isccSignatureStatus = [string]$isccSignature.Status
        isccSigner = $isccSignature.SignerCertificate.Subject
        installerScript = File-Evidence $installerScript
        icon = File-Evidence $icon
    }
    publish = [ordered]@{
        fileCount = $publishedFiles.Count
        bytes = $publishedBytes
        application = $publishedAppEvidence
        fileVersion = $publishedVersion.FileVersion
        productVersion = $publishedVersion.ProductVersion
        readmePresent = $true
        thirdPartyNoticesPresent = $true
        nativeClientSecurityPresent = $false
    }
    portable = [ordered]@{
        launcher = File-Evidence $portableLauncher
        workspaceOverrideIsFirstLaunchOnly = $true
        localDataIsEmpty = @(
            Get-ChildItem -LiteralPath $portableLocalData -Force).Count -eq 0
        editingDataIsEmpty = @(
            Get-ChildItem -LiteralPath $portableEditing -Force).Count -eq 0
        workspaceIsEmpty = @(
            Get-ChildItem -LiteralPath $portableWorkspace -Force).Count -eq 0
    }
    installer = [ordered]@{
        file = $setupEvidence
        fileVersion = $setupVersion.FileVersion.Trim()
        productVersion = $setupVersion.ProductVersion.Trim()
        authenticodeStatus = [string](
            Get-AuthenticodeSignature -LiteralPath $setup).Status
    }
    logs = [ordered]@{
        restore = File-Evidence $restoreLog
        publish = File-Evidence $publishLog
        iscc = File-Evidence $isccLog
    }
    remainingDifferences = @(
        "The preview installer is intentionally unsigned and requires signing before public distribution.",
        "Install/start/upgrade/rollback/uninstall, Program Files/UAC, file association, VM, and user approval gates remain separate.",
        "The preview AppId must remain independent until replacement is explicitly approved."
    )
}
$evidencePath = Join-Path $output "build-evidence.json"
$evidence | ConvertTo-Json -Depth 30 |
    Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
Write-Output (
    "Windows Avalonia preview installer build: " + $evidence.status)
Write-Output "Installer: $setup"
Write-Output "Evidence: $evidencePath"
