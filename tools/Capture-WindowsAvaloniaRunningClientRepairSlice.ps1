param(
    [string]$Root =
        "artifacts\windows-avalonia-running-client-repair-slice-20260729-r1"
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia running-client repair evidence requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-running-client-repair-slice-20260729-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals(
        $expectedRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal running-client repair root must be exactly $expectedRoot"
}
if (Test-Path -LiteralPath $formalRoot) {
    throw "Formal running-client repair root already exists: $formalRoot"
}
if ($env:LUMACHART_FOREGROUND_AUTOMATION_CONSENT -cne
    "USER_CONFIRMED_DESKTOP_AVAILABLE") {
    throw "Explicit foreground GUI automation consent is required."
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Write-Utf8([string]$Path, [string]$Text) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) |
        Out-Null
    [IO.File]::WriteAllText(
        $Path,
        $Text,
        [Text.UTF8Encoding]::new($false))
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
        lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString("O")
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Assert-Unchanged(
    [System.Collections.IDictionary]$Before,
    [System.Collections.IDictionary]$After,
    [string]$Label) {
    Assert ($Before.sha256 -ceq $After.sha256 -and
        $Before.length -eq $After.length -and
        $Before.lastWriteTimeUtc -ceq $After.lastWriteTimeUtc) (
        "$Label changed during the formal running-client repair slice.")
}

function Invoke-Logged(
    [string]$LogPath,
    [Parameter(Mandatory = $true)][scriptblock]$Action,
    [switch]$RequireLastExitCode) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($LogPath)) |
        Out-Null
    & $Action 2>&1 | Tee-Object -FilePath $LogPath
    if ($RequireLastExitCode -and $LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE; log=$LogPath"
    }
}

function Remove-ExactStagingDirectory([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    Assert ($full.StartsWith(
            $formalRoot + '\',
            [StringComparison]::OrdinalIgnoreCase)) (
        "Refusing to remove staging outside the formal root: $full")
    Assert (-not $full.Equals(
            $formalRoot,
            [StringComparison]::OrdinalIgnoreCase)) (
        "Refusing to remove the formal root.")
    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        return [ordered]@{
            path = [IO.Path]::GetRelativePath($projectRoot, $full)
            fileCount = 0
            bytes = 0L
            removed = $false
        }
    }
    $files = @(Get-ChildItem -LiteralPath $full -Recurse -File -Force)
    $bytes = if ($files.Count -eq 0) {
        0L
    }
    else {
        [long]($files | Measure-Object Length -Sum).Sum
    }
    $result = [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $full)
        fileCount = $files.Count
        bytes = $bytes
        removed = $true
    }
    Remove-Item -LiteralPath $full -Recurse -Force
    Assert (-not (Test-Path -LiteralPath $full)) (
        "Installer staging directory remained after cleanup: $full")
    $result
}

$sourceChartPath = "D:\osu!\Songs\Resound\0\1781536331.mc"
$sourceAudioPath = "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg"
$frozenInstallerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$sourceChartBefore = File-Evidence $sourceChartPath
$sourceAudioBefore = File-Evidence $sourceAudioPath
$frozenInstallerBefore = File-Evidence $frozenInstallerPath
Assert ($sourceChartBefore.sha256 -ceq
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") (
    "Real Resound MC baseline hash mismatch.")
Assert ($sourceAudioBefore.sha256 -ceq
    "00AA7780330A022D7F5D0C4C2BEA23625D31F48BA8CAC2AF25117249BEA05151") (
    "Real Resound OGG baseline hash mismatch.")
Assert ($frozenInstallerBefore.sha256 -ceq
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") (
    "Frozen WPF installer baseline hash mismatch.")

[IO.Directory]::CreateDirectory($formalRoot) | Out-Null
$buildRoot = Join-Path $formalRoot "build"
$testsRoot = Join-Path $formalRoot "tests"
$installerBuildRoot = Join-Path $formalRoot "installer-build"
$lifecycleRoot = Join-Path $formalRoot "lifecycle"
$env:DOTNET_CLI_HOME = Join-Path $projectRoot ".codex-dotnet-home"
$env:NUGET_PACKAGES = Join-Path $projectRoot ".codex-nuget-packages"
$env:NUGET_HTTP_CACHE_PATH = Join-Path $projectRoot ".codex-nuget-http-cache"
$env:TEMP = Join-Path $projectRoot ".codex-temp"
$env:TMP = $env:TEMP

Invoke-Logged (Join-Path $buildRoot "avalonia-build.log") {
    dotnet build (Join-Path $projectRoot (
        "LumaChart.Avalonia\LumaChart.Avalonia.csproj")) `
        -c Release --no-restore -p:TreatWarningsAsErrors=true -warnaserror `
        -nologo -v:minimal
} -RequireLastExitCode
Invoke-Logged (Join-Path $buildRoot "avalonia-specs-build.log") {
    dotnet build (Join-Path $projectRoot (
        "LumaChart.Avalonia.Specs\LumaChart.Avalonia.Specs.csproj")) `
        -c Release --no-restore -p:TreatWarningsAsErrors=true -warnaserror `
        -nologo -v:minimal
} -RequireLastExitCode
Invoke-Logged (Join-Path $buildRoot "main-specs-build.log") {
    dotnet build (Join-Path $projectRoot (
        "LumaChart.Specs\LumaChart.Specs.csproj")) `
        -c Release --no-restore -p:TreatWarningsAsErrors=true -warnaserror `
        -nologo -v:minimal
} -RequireLastExitCode
Invoke-Logged (Join-Path $testsRoot "avalonia-specs-run.log") {
    dotnet run --project (Join-Path $projectRoot (
        "LumaChart.Avalonia.Specs\LumaChart.Avalonia.Specs.csproj")) `
        -c Release --no-build -- `
        --output (Join-Path $testsRoot "avalonia-specs-evidence.json")
} -RequireLastExitCode
Invoke-Logged (Join-Path $testsRoot "main-specs-run.log") {
    dotnet run --project (Join-Path $projectRoot (
        "LumaChart.Specs\LumaChart.Specs.csproj")) `
        -c Release --no-build
} -RequireLastExitCode
Invoke-Logged (Join-Path $testsRoot "gui-automation-safety-run.log") {
    & (Join-Path $PSScriptRoot (
        "Test-WindowsAvaloniaGuiAutomationSafety.ps1")) `
        -OutputPath (Join-Path $testsRoot "gui-automation-safety.json")
}

$installerBuildRun = Join-Path $buildRoot "installer-build-run.log"
Invoke-Logged $installerBuildRun {
    & (Join-Path $PSScriptRoot (
        "Build-WindowsAvaloniaPreviewInstaller.ps1")) `
        -OutputRoot $installerBuildRoot `
        -FormalMigrationAuthority
}
$setupPath = Join-Path $installerBuildRoot (
    "installer\LumaChartStudio-Avalonia-Preview-Setup.exe")
$setupBefore = File-Evidence $setupPath
$lifecycleRun = Join-Path $buildRoot "installer-lifecycle-run.log"
Invoke-Logged $lifecycleRun {
    & (Join-Path $PSScriptRoot (
        "Test-WindowsAvaloniaPreviewInstaller.ps1")) `
        -SetupPath $setupPath `
        -OutputRoot $lifecycleRoot `
        -FormalMigrationAuthority `
        -ExerciseRunningClientRepair `
        -InstalledGuiChartPath $sourceChartPath `
        -TimeoutSeconds 180
}

$lifecycleEvidencePath = Join-Path $lifecycleRoot "evidence.json"
$lifecycle =
    Get-Content -LiteralPath $lifecycleEvidencePath -Raw |
        ConvertFrom-Json -Depth 100
$repair = $lifecycle.lifecycle.runningClientRepair
Assert ($lifecycle.status -ceq "passed-migration-incomplete") (
    "Formal installer lifecycle evidence did not pass.")
Assert ($repair.processExitedDuringRepair -eq $true -and
    [int]$repair.processExitCode -eq 0 -and
    [int]$repair.repairExitCode -eq 0 -and
    $repair.restartRequired -eq $false -and
    $repair.shutdownCloseReason -ceq "WindowClosing" -and
    $repair.shutdownWasProgrammatic -eq $false -and
    $repair.realChartAndAudioReopened -eq $true -and
    $repair.sourceUnchanged -eq $true) (
    "Running-client repair lifecycle evidence differs.")

$setupAfter = File-Evidence $setupPath
Assert ($setupAfter.sha256 -ceq $setupBefore.sha256) (
    "Fresh setup changed during the lifecycle.")
$publishCleanup = Remove-ExactStagingDirectory (
    Join-Path $installerBuildRoot "publish")
$installerTempCleanup = Remove-ExactStagingDirectory (
    Join-Path $installerBuildRoot "temp")
$lifecycleTempCleanup = Remove-ExactStagingDirectory (
    Join-Path $lifecycleRoot "temp")

$sourceChartAfter = File-Evidence $sourceChartPath
$sourceAudioAfter = File-Evidence $sourceAudioPath
$frozenInstallerAfter = File-Evidence $frozenInstallerPath
Assert-Unchanged $sourceChartBefore $sourceChartAfter "Real Resound MC"
Assert-Unchanged $sourceAudioBefore $sourceAudioAfter "Real Resound OGG"
Assert-Unchanged $frozenInstallerBefore $frozenInstallerAfter (
    "Frozen WPF installer")

$capture = [ordered]@{
    schema =
        "lumachart.windows.avalonia.running-client-repair-slice-capture.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    formalMigrationAuthority = $true
    completion = $false
    migrationComplete = $false
    windowsAvaloniaOnly = $true
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    productionServerMutationPerformed = $false
    setup = [ordered]@{
        beforeLifecycle = $setupBefore
        afterLifecycle = $setupAfter
        unchanged = $true
        buildEvidence = File-Evidence (
            Join-Path $installerBuildRoot "build-evidence.json")
    }
    lifecycle = [ordered]@{
        evidence = File-Evidence $lifecycleEvidencePath
        run = File-Evidence $lifecycleRun
        repairLog = File-Evidence (
            Join-Path $lifecycleRoot "lifecycle\repair-install.log")
        runningClientRepair = $repair
    }
    builds = [ordered]@{
        avalonia = File-Evidence (
            Join-Path $buildRoot "avalonia-build.log")
        avaloniaSpecs = File-Evidence (
            Join-Path $buildRoot "avalonia-specs-build.log")
        mainSpecs = File-Evidence (
            Join-Path $buildRoot "main-specs-build.log")
    }
    tests = [ordered]@{
        avaloniaSpecs = File-Evidence (
            Join-Path $testsRoot "avalonia-specs-evidence.json")
        avaloniaSpecsRun = File-Evidence (
            Join-Path $testsRoot "avalonia-specs-run.log")
        mainSpecs = File-Evidence (
            Join-Path $testsRoot "main-specs-run.log")
        guiAutomationSafety = File-Evidence (
            Join-Path $testsRoot "gui-automation-safety.json")
    }
    immutableInputs = [ordered]@{
        realMcBefore = $sourceChartBefore
        realMcAfter = $sourceChartAfter
        realOggBefore = $sourceAudioBefore
        realOggAfter = $sourceAudioAfter
        frozenWpfInstallerBefore = $frozenInstallerBefore
        frozenWpfInstallerAfter = $frozenInstallerAfter
    }
    artifactSizeControl = [ordered]@{
        compiledSetupRetained = $true
        publishedPayloadRetained = $false
        publishCleanup = $publishCleanup
        installerTempCleanup = $installerTempCleanup
        lifecycleTempCleanup = $lifecycleTempCleanup
    }
    remainingDifferences = @(
        "Running repair with a dirty document intentionally remains blocked so the installer cannot discard unsaved work.",
        "Valid setup interruption, Program Files/UAC, signing/timestamp, and a clean disposable VM remain release gates.",
        "The independent Preview AppId remains separate from the frozen WPF installation until the user approves replacement.")
}
$capturePath = Join-Path $formalRoot "capture-evidence.json"
Write-Utf8 $capturePath ($capture | ConvertTo-Json -Depth 60)
Write-Output (
    "Windows Avalonia running-client repair formal capture: " +
    "passed-migration-incomplete")
Write-Output "Evidence: $capturePath"
