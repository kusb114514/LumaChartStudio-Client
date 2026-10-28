param(
    [string]$Root =
        "artifacts\windows-avalonia-installer-lifecycle-slice-20260729-r2",
    [string]$UpgradeFixtureSetupPath =
        ".codex-temp\avalonia-installer-upgrade-fixture-1.0.9-20260728-r1\installer\LumaChartStudio-Avalonia-Preview-Setup.exe"
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia installer lifecycle evidence requires PowerShell Core on Windows."
}

$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-installer-lifecycle-slice-20260729-r2"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals(
        $expectedRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal installer lifecycle root must be exactly $expectedRoot"
}
if (Test-Path -LiteralPath $formalRoot) {
    throw "Formal installer lifecycle root already exists: $formalRoot"
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
        "$Label changed during formal installer lifecycle verification.")
}

function Invoke-DotnetLogged(
    [string]$LogPath,
    [Parameter(Mandatory = $true)][scriptblock]$Action) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($LogPath)) |
        Out-Null
    & $Action 2>&1 | Tee-Object -FilePath $LogPath
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet command failed with exit code $LASTEXITCODE; log=$LogPath"
    }
}

function Invoke-PowerShellLogged(
    [string]$LogPath,
    [Parameter(Mandatory = $true)][scriptblock]$Action) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($LogPath)) |
        Out-Null
    & $Action 2>&1 | Tee-Object -FilePath $LogPath
    if ($LASTEXITCODE -ne 0) {
        throw "PowerShell command failed with exit code $LASTEXITCODE; log=$LogPath"
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
$formatAuthorityRoot = Join-Path $projectRoot (
    "artifacts\windows-avalonia-format-modes-slice-20260729-r1")
$mczPath = Join-Path $formatAuthorityRoot (
    "malody-rate-pack-export\export\Resound 0.8-1.1.mcz")
$osuPath = Join-Path $formatAuthorityRoot (
    "osu-single-chart-export\export\Resound.osu")
$oszPath = Join-Path $formatAuthorityRoot (
    "osu-rate-pack-export\export\Resound 0.8-1.1.osz")
$frozenInstallerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$upgradeFixtureSetup = [IO.Path]::GetFullPath(
    (Join-Path $projectRoot $UpgradeFixtureSetupPath))
$sourceBefore = File-Evidence $sourceChartPath
$mczBefore = File-Evidence $mczPath
$osuBefore = File-Evidence $osuPath
$oszBefore = File-Evidence $oszPath
$frozenInstallerBefore = File-Evidence $frozenInstallerPath
$upgradeFixtureBefore = File-Evidence $upgradeFixtureSetup
Assert ($sourceBefore.sha256 -ceq
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") (
    "Real Resound MC baseline hash mismatch.")
Assert ($frozenInstallerBefore.sha256 -ceq
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") (
    "Frozen WPF installer baseline hash mismatch.")
Assert ($upgradeFixtureBefore.sha256 -ceq
    "0064F79585F4AED8A0B9EB8F4BA265B6F156606FB818234EF0885D31A39A2353") (
    "Controlled 1.0.9 upgrade fixture hash mismatch.")

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

Invoke-DotnetLogged (Join-Path $buildRoot "avalonia-build.log") {
    dotnet build (Join-Path $projectRoot (
        "LumaChart.Avalonia\LumaChart.Avalonia.csproj")) `
        -c Release --no-restore -p:TreatWarningsAsErrors=true -warnaserror
}
Invoke-DotnetLogged (Join-Path $buildRoot "avalonia-specs-build.log") {
    dotnet build (Join-Path $projectRoot (
        "LumaChart.Avalonia.Specs\LumaChart.Avalonia.Specs.csproj")) `
        -c Release --no-restore -p:TreatWarningsAsErrors=true -warnaserror
}
Invoke-DotnetLogged (Join-Path $buildRoot "main-specs-build.log") {
    dotnet build (Join-Path $projectRoot (
        "LumaChart.Specs\LumaChart.Specs.csproj")) `
        -c Release --no-restore -p:TreatWarningsAsErrors=true -warnaserror
}
Invoke-DotnetLogged (Join-Path $testsRoot "avalonia-specs-run.log") {
    dotnet run --project (Join-Path $projectRoot (
        "LumaChart.Avalonia.Specs\LumaChart.Avalonia.Specs.csproj")) `
        -c Release --no-build -- `
        --output (Join-Path $testsRoot "avalonia-specs-evidence.json")
}
Invoke-DotnetLogged (Join-Path $testsRoot "main-specs-run.log") {
    dotnet run --project (Join-Path $projectRoot (
        "LumaChart.Specs\LumaChart.Specs.csproj")) `
        -c Release --no-build
}

$installerBuildLog = Join-Path $buildRoot "installer-build-run.log"
Invoke-PowerShellLogged $installerBuildLog {
    & (Join-Path $PSScriptRoot "Build-WindowsAvaloniaPreviewInstaller.ps1") `
        -OutputRoot $installerBuildRoot `
        -FormalMigrationAuthority
}
$setupPath = Join-Path $installerBuildRoot (
    "installer\LumaChartStudio-Avalonia-Preview-Setup.exe")
$setupEvidenceBeforeLifecycle = File-Evidence $setupPath
$installerBuildEvidencePath = Join-Path $installerBuildRoot (
    "build-evidence.json")

$lifecycleLog = Join-Path $buildRoot "installer-lifecycle-run.log"
Invoke-PowerShellLogged $lifecycleLog {
    & (Join-Path $PSScriptRoot "Test-WindowsAvaloniaPreviewInstaller.ps1") `
        -SetupPath $setupPath `
        -UpgradeFromSetupPath $upgradeFixtureSetup `
        -OutputRoot $lifecycleRoot `
        -FormalMigrationAuthority `
        -ExerciseInstalledGui `
        -ExerciseInstalledAssociationsGui `
        -InstalledGuiChartPath $sourceChartPath `
        -InstalledMczPath $mczPath `
        -InstalledOsuPath $osuPath `
        -InstalledOszPath $oszPath `
        -TimeoutSeconds 180
}
$lifecycleEvidencePath = Join-Path $lifecycleRoot "evidence.json"
$lifecycleEvidence =
    Get-Content -LiteralPath $lifecycleEvidencePath -Raw |
        ConvertFrom-Json -Depth 100
Assert ($lifecycleEvidence.status -ceq "passed-migration-incomplete") (
    "Formal installer lifecycle evidence did not pass.")
Assert ($lifecycleEvidence.lifecycle.corruptedHigherVersionPackage.rejection.rejected -eq
        $true -and
    $lifecycleEvidence.lifecycle.corruptedHigherVersionPackage.installedAppUnchanged -eq
        $true -and
    $lifecycleEvidence.lifecycle.corruptedHigherVersionPackage.editingCacheUnchanged -eq
        $true) (
    "Corrupted-package fail-closed lifecycle evidence differs.")
Assert (@(
        $lifecycleEvidence.associations.installedOpenWithTargetGui.psobject.Properties
    ).Count -eq 4) (
    "Installed OpenWith target did not exercise all four formats.")

$setupEvidenceAfterLifecycle = File-Evidence $setupPath
Assert ($setupEvidenceAfterLifecycle.sha256 -ceq
    $setupEvidenceBeforeLifecycle.sha256) (
    "Fresh Avalonia setup changed during lifecycle verification.")
$publishedStagingCleanup = Remove-ExactStagingDirectory (
    Join-Path $installerBuildRoot "publish")
$installerTempCleanup = Remove-ExactStagingDirectory (
    Join-Path $installerBuildRoot "temp")

$sourceAfter = File-Evidence $sourceChartPath
$mczAfter = File-Evidence $mczPath
$osuAfter = File-Evidence $osuPath
$oszAfter = File-Evidence $oszPath
$frozenInstallerAfter = File-Evidence $frozenInstallerPath
Assert-Unchanged $sourceBefore $sourceAfter "Real Resound MC"
Assert-Unchanged $mczBefore $mczAfter "Formal MCZ fixture"
Assert-Unchanged $osuBefore $osuAfter "Formal osu fixture"
Assert-Unchanged $oszBefore $oszAfter "Formal OSZ fixture"
Assert-Unchanged $frozenInstallerBefore $frozenInstallerAfter (
    "Frozen WPF installer")

$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.installer-lifecycle-slice-capture.v1"
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    formalMigrationAuthority = $true
    completion = $false
    migrationComplete = $false
    windowsAvaloniaOnly = $true
    pureDotnetRelease = $true
    selfContained = $true
    publishSingleFile = $false
    publishTrimmed = $false
    publishAot = $false
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    productionServerMutationPerformed = $false
    setup = [ordered]@{
        beforeLifecycle = $setupEvidenceBeforeLifecycle
        afterLifecycle = $setupEvidenceAfterLifecycle
        unchanged = $true
        buildEvidence = File-Evidence $installerBuildEvidencePath
        buildRun = File-Evidence $installerBuildLog
    }
    lifecycle = [ordered]@{
        evidence = File-Evidence $lifecycleEvidencePath
        run = File-Evidence $lifecycleLog
        corruptPackageRejectedAndOldInstallPreserved = $true
        validUpgradeRepairAndUninstallPassed = $true
        installedRealMcGuiPassed = $true
        installedOpenWithTargetFormats = @("mc", "mcz", "osu", "osz")
    }
    builds = [ordered]@{
        avalonia = File-Evidence (Join-Path $buildRoot "avalonia-build.log")
        avaloniaSpecs =
            File-Evidence (Join-Path $buildRoot "avalonia-specs-build.log")
        mainSpecs = File-Evidence (Join-Path $buildRoot "main-specs-build.log")
    }
    tests = [ordered]@{
        avaloniaSpecs =
            File-Evidence (Join-Path $testsRoot "avalonia-specs-evidence.json")
        avaloniaSpecsRun =
            File-Evidence (Join-Path $testsRoot "avalonia-specs-run.log")
        mainSpecs = File-Evidence (Join-Path $testsRoot "main-specs-run.log")
    }
    immutableInputs = [ordered]@{
        realMcBefore = $sourceBefore
        realMcAfter = $sourceAfter
        mczBefore = $mczBefore
        mczAfter = $mczAfter
        osuBefore = $osuBefore
        osuAfter = $osuAfter
        oszBefore = $oszBefore
        oszAfter = $oszAfter
        frozenWpfInstallerBefore = $frozenInstallerBefore
        frozenWpfInstallerAfter = $frozenInstallerAfter
        controlledUpgradeFixture = $upgradeFixtureBefore
    }
    artifactSizeControl = [ordered]@{
        compiledSetupRetained = $true
        publishedPayloadRetained = $false
        publishedStagingCleanup = $publishedStagingCleanup
        installerTempCleanup = $installerTempCleanup
    }
    remainingDifferences = @(
        "All-users Program Files/UAC and clean disposable-VM install/upgrade/uninstall remain external gates because this process is not elevated.",
        "A valid setup interrupted during its file transaction still requires disposable-VM fault injection; this slice proves a corrupted package is rejected before mutation.",
        "The preview setup is intentionally unsigned and keeps an independent AppId until replacement is approved.",
        "WPF 1.1.0 only opens the server-provided http/https download link; no out-of-scope in-client package downloader is introduced. Production signing and release-link operations remain release gates.")
}
$evidencePath = Join-Path $formalRoot "capture-evidence.json"
Write-Utf8 $evidencePath ($evidence | ConvertTo-Json -Depth 50)
Write-Output (
    "Windows Avalonia installer lifecycle formal capture: " +
    "passed-migration-incomplete")
Write-Output "Evidence: $evidencePath"
