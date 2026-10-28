param(
    [Parameter(Mandatory = $true)][string]$FormalRoot
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Dialog r3 evidence is Windows-only and requires PowerShell Core."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath(
    (Join-Path $projectRoot "artifacts\windows-avalonia-dialog-slice-20260727-r3"))
$formalRoot = [IO.Path]::GetFullPath($FormalRoot).TrimEnd('\')
if (-not $formalRoot.Equals(
        $expectedRoot.TrimEnd('\'),
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal dialog r3 root must be exactly $expectedRoot"
}
$verificationPath = Join-Path $formalRoot "verification-evidence.json"
if (Test-Path -LiteralPath $verificationPath) {
    throw "Verification output already exists: $verificationPath"
}

function Get-FileEvidence {
    param([Parameter(Mandatory = $true)][string]$Path)
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Required file is missing: $fullPath"
    }
    $item = Get-Item -LiteralPath $fullPath
    [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $fullPath)
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    }
}

$buildLogs = [ordered]@{}
foreach ($entry in ([ordered]@{
        avalonia = Join-Path $formalRoot "build\avalonia.log"
        avaloniaSpecs = Join-Path $formalRoot "build\avalonia-specs.log"
        mainSpecs = Join-Path $formalRoot "build\main-specs.log"
    }).GetEnumerator()) {
    $text = Get-Content -LiteralPath $entry.Value -Raw
    if ($text -notmatch "0 个警告" -or
        $text -notmatch "0 个错误" -or
        $text -match "生成失败") {
        throw "Strict build did not prove 0 warning / 0 error: $($entry.Value)"
    }
    $buildLogs[$entry.Key] = Get-FileEvidence $entry.Value
}

$avaloniaSpecsPath = Join-Path $formalRoot "specs\avalonia-specs-evidence.json"
$avaloniaSpecs = Get-Content -LiteralPath $avaloniaSpecsPath -Raw | ConvertFrom-Json
$checks = @($avaloniaSpecs.checks)
$dialogChecks = @($checks | Where-Object { [string]$_.name -like "dialog-*" })
if ([string]$avaloniaSpecs.status -cne "passed" -or
    $checks.Count -ne 418 -or
    @($checks | Where-Object { -not [bool]$_.passed }).Count -ne 0 -or
    $dialogChecks.Count -ne 4) {
    throw "Avalonia Specs did not prove 418/418 and four dialog checks."
}
$mainSpecsPath = Join-Path $formalRoot "specs\main-specs.log"
if ((Get-Content -LiteralPath $mainSpecsPath -Raw) -notmatch
    "79/79 specs passed\.") {
    throw "Main Specs did not prove 79/79."
}

$trustedChartSha =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$settingsPath = Join-Path $formalRoot (
    "settings\settings-cache-gui-evidence.json")
$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
if ([string]$settings.schema -cne
        "lumachart.windows.avalonia.settings-cache-gui-evidence.v1" -or
    [string]$settings.status -cne "passed-migration-incomplete" -or
    -not [bool]$settings.fixture.unchanged -or
    -not [bool]$settings.fixture.isolatedSourceUnchanged -or
    [string]$settings.fixture.sha256Before -cne $trustedChartSha -or
    [string]$settings.fixture.sha256After -cne $trustedChartSha -or
    -not [bool]$settings.backupRestore.structuredMatch -or
    -not [bool]$settings.backupRestore.restoredTabMarkedUnsaved -or
    -not [bool]$settings.cacheCleanup.protectedOpenTabWorkingCopyExists -or
    -not [bool]$settings.cacheCleanup.orphanEditingCacheDeleted -or
    -not [bool]$settings.cacheCleanup.onlineResourceCacheContentsDeleted -or
    -not [bool]$settings.cacheCleanup.unselectedBackupRetained -or
    [string]$settings.runtimeEvidence.schema -cne
        "lumachart.windows.avalonia.gui-evidence.v14" -or
    -not [bool]$settings.runtimeEvidence.settings.settingsIsolatedFromWpf -or
    -not [bool]$settings.runtimeEvidence.timeline.singleCustomControl -or
    [int]$settings.runtimeEvidence.timeline.perNoteAvaloniaControlCount -ne 0) {
    throw "Settings/cache GUI did not prove the required isolated real-chart flow."
}
$settingsScreenshots = [Collections.Generic.List[object]]::new()
foreach ($property in $settings.screenshots.PSObject.Properties) {
    $actual = Get-FileEvidence ([string]$property.Value.path)
    if ([string]$actual.sha256 -cne [string]$property.Value.sha256 -or
        [long]$actual.length -ne [long]$property.Value.length) {
        throw "Settings screenshot differs from its declared evidence: $($property.Name)"
    }
    $settingsScreenshots.Add($actual)
}
if ($settingsScreenshots.Count -ne 5) {
    throw "Settings/cache GUI must declare exactly five screenshots."
}

$validationPath = Join-Path $formalRoot "validation\capture-result.json"
$validation = Get-Content -LiteralPath $validationPath -Raw | ConvertFrom-Json
$validationAction = $validation.chartValidationAction
$validationRuntime = $validation.chartValidationRuntime
if ([string]$validation.mode -cne "real-chart-editor" -or
    -not [bool]$validation.chartValidationExercised -or
    [string]$validationAction.checkButton.automationId -cne "Editor.ChartCheck" -or
    [string]$validationAction.manualDialog.automationId -cne
        "ChartValidation.Dialog" -or
    [string]$validationAction.manualDialog.helpText -cne
        "契约=wpf-1.1.0-dialog-r1; 标题=谱面检查器" -or
    [string]$validationAction.manualConfirm.name -cne "确定" -or
    [string]$validationAction.saveButton.automationId -cne "Editor.Save" -or
    [string]$validationAction.saveBlockedDialog.automationId -cne
        "ChartValidation.Dialog" -or
    [string]$validationAction.saveBlockedConfirm.name -cne "确定" -or
    -not [bool]$validationAction.noteInspectorSelected -or
    [string]$validationAction.sourceBefore.sha256 -cne $trustedChartSha -or
    [string]$validationAction.sourceAfter.sha256 -cne $trustedChartSha -or
    [string]$validationAction.sourceBefore.lastWriteTimeUtc -cne
        [string]$validationAction.sourceAfter.lastWriteTimeUtc -or
    [int]$validationRuntime.totalIssueCount -ne 2 -or
    [int]$validationRuntime.overlappingNoteCount -ne 1 -or
    [int]$validationRuntime.crossingLongNoteCount -ne 1 -or
    -not [bool]$validationRuntime.manualCheckShown -or
    -not [bool]$validationRuntime.saveBlockedShown -or
    -not [bool]$validationRuntime.lastNavigationMatchesPresentation -or
    [double]$validationRuntime.manualDialogScale.requestedUiScale -ne 1.35 -or
    [double]$validationRuntime.manualDialogScale.requestedFontScale -ne 1.25 -or
    -not [bool]$validationRuntime.manualDialogScale.usesLayoutTransform -or
    -not [bool]$validationRuntime.saveDialogScale.usesLayoutTransform) {
    throw "Chart-validation GUI did not prove the manual/save-blocked WPF dialog flow."
}
$validationScreenshots = [Collections.Generic.List[object]]::new()
foreach ($path in @(
        [string]$validationAction.manualDialogScreenshotPath,
        [string]$validationAction.saveBlockedDialogScreenshotPath,
        [string]$validation.screenshotPath)) {
    $validationScreenshots.Add((Get-FileEvidence $path))
}
if ([string]$validationScreenshots[0].sha256 -cne
        [string]$validationAction.manualDialogScreenshotSha256 -or
    [string]$validationScreenshots[1].sha256 -cne
        [string]$validationAction.saveBlockedDialogScreenshotSha256 -or
    [string]$validationScreenshots[2].sha256 -cne
        [string]$validation.screenshotSha256) {
    throw "Chart-validation screenshot hash differs from capture evidence."
}

$changedFiles = [Collections.Generic.List[object]]::new()
foreach ($path in @(
        "tools\Capture-WindowsAvaloniaGui.ps1",
        "tools\Test-WindowsAvaloniaSlice.ps1",
        "tools\New-WindowsAvaloniaDialogR3SliceEvidence.ps1")) {
    $changedFiles.Add((Get-FileEvidence (Join-Path $projectRoot $path)))
}
$installer = Get-FileEvidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
if ([string]$installer.sha256 -cne
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
    throw "Frozen WPF installer hash changed."
}
$predecessor = Get-FileEvidence (
    Join-Path $projectRoot (
        "artifacts\windows-avalonia-dialog-slice-20260727-r2\" +
        "verification-evidence.json"))
if ([string]$predecessor.sha256 -cne
    "CE2B72992D478701873F74F569371BA35FFD8ECE532F9B7234102BA00EF62B37") {
    throw "Dialog r2 predecessor authority changed."
}

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.dialog-slice-verification.v3"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        platform = "Windows Avalonia only"
        contract = "wpf-1.1.0-dialog-r1"
        covered = @(
            "chart-validation responsive command-menu physical flow",
            "manual validation and save-blocked dialogs",
            "settings backup-complete and restore-confirmation dialogs",
            "real backup restore and isolated cache cleanup")
        excluded = @(
            "Android", "iOS", "macOS", "Linux", "WebAssembly",
            "production Server deployment", "installer replacement",
            "OLLVM", "obfuscation", "packing", "code virtualization",
            "AOT", "NativeAOT")
    }
    builds = [ordered]@{
        configuration = "ordinary .NET Release"
        warnings = 0
        errors = 0
        logs = $buildLogs
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 418
            total = 418
            failed = 0
            dialogChecks = $dialogChecks
            evidence = Get-FileEvidence $avaloniaSpecsPath
            log = Get-FileEvidence (
                Join-Path $formalRoot "specs\avalonia-specs.log")
        }
        mainSpecs = [ordered]@{
            passed = 79
            total = 79
            failed = 0
            log = Get-FileEvidence $mainSpecsPath
        }
    }
    gui = [ordered]@{
        status = "passed"
        realChartSha256 = $trustedChartSha
        settings = [ordered]@{
            interaction = "UIA-driven real backup/restore/cache workflow; no Enter/Escape"
            evidence = Get-FileEvidence $settingsPath
            runtime = Get-FileEvidence ([string]$settings.runtimeEvidence.path)
            screenshots = $settingsScreenshots
        }
        chartValidation = [ordered]@{
            interaction = "physical command-menu/check/confirm/save/confirm pointer clicks"
            sourceUnchanged = $true
            evidence = Get-FileEvidence $validationPath
            runtime = Get-FileEvidence (
                Join-Path $formalRoot "validation\runtime-evidence.json")
            interactionEvidence = Get-FileEvidence (
                Join-Path $formalRoot "validation\interaction-evidence.json")
            screenshots = $validationScreenshots
        }
    }
    source = [ordered]@{
        changedFiles = $changedFiles
        formalRootMiB = [Math]::Round(
            [double](Get-ChildItem -LiteralPath $formalRoot -Recurse -File |
                Measure-Object Length -Sum).Sum / 1MB,
            2)
    }
    frozenBaselines = [ordered]@{
        installer = $installer
        predecessor = $predecessor
    }
    completion = [ordered]@{
        fullWindowsMigrationComplete = $false
        userReplacementApproval = $false
        otherPlatformAuthorization = $false
    }
}
$verification | ConvertTo-Json -Depth 30 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
Get-FileEvidence $verificationPath | ConvertTo-Json -Depth 5
