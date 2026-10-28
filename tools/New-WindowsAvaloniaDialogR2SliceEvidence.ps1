param(
    [Parameter(Mandatory = $true)][string]$FormalRoot
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Dialog r2 evidence is Windows-only and requires PowerShell Core."
}

$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath(
    (Join-Path $projectRoot "artifacts\windows-avalonia-dialog-slice-20260727-r2"))
$formalFullPath = [IO.Path]::GetFullPath($FormalRoot).TrimEnd('\')
if (-not $formalFullPath.Equals(
        $expectedRoot.TrimEnd('\'),
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal dialog r2 root must be exactly $expectedRoot"
}

$verificationPath = Join-Path $formalFullPath "verification-evidence.json"
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
        avalonia = Join-Path $formalFullPath "build\avalonia.log"
        avaloniaSpecs = Join-Path $formalFullPath "build\avalonia-specs.log"
        mainSpecs = Join-Path $formalFullPath "build\main-specs.log"
    }).GetEnumerator()) {
    $text = Get-Content -LiteralPath $entry.Value -Raw
    if ($text -notmatch "0 个警告" -or
        $text -notmatch "0 个错误" -or
        $text -match "生成失败") {
        throw "Strict build did not prove 0 warning / 0 error: $($entry.Value)"
    }
    $buildLogs[$entry.Key] = Get-FileEvidence $entry.Value
}

$avaloniaSpecsPath = Join-Path $formalFullPath "specs\avalonia-specs-evidence.json"
$avaloniaSpecs = Get-Content -LiteralPath $avaloniaSpecsPath -Raw | ConvertFrom-Json
$checks = @($avaloniaSpecs.checks)
$dialogChecks = @($checks | Where-Object { [string]$_.name -like "dialog-*" })
if ([string]$avaloniaSpecs.status -cne "passed" -or
    $checks.Count -ne 418 -or
    @($checks | Where-Object { -not [bool]$_.passed }).Count -ne 0 -or
    $dialogChecks.Count -ne 4 -or
    @($dialogChecks | Where-Object { -not [bool]$_.passed }).Count -ne 0) {
    throw "Avalonia Specs did not prove 418/418 and four dialog checks."
}

$mainSpecsPath = Join-Path $formalFullPath "specs\main-specs.log"
$mainSpecsText = Get-Content -LiteralPath $mainSpecsPath -Raw
if ($mainSpecsText -notmatch "79/79 specs passed\.") {
    throw "Main Specs did not prove 79/79."
}

$capturePath = Join-Path $formalFullPath "gui\capture-result.json"
$capture = Get-Content -LiteralPath $capturePath -Raw | ConvertFrom-Json
$action = $capture.libraryDeletionAction
if ([string]$capture.mode -cne "real-chart-editor" -or
    -not [bool]$capture.libraryDeletionExercised -or
    -not [bool]$capture.libraryOpenDocumentBlockExercised -or
    [string]$action.mode -cne "open-document-block" -or
    [string]$action.dialog.automationId -cne "Library.DeleteDialog" -or
    [string]$action.dialog.helpText -cne
        "契约=wpf-1.1.0-dialog-r1; 标题=无法删除" -or
    [string]$action.dialogMessage.automationId -cne
        "Library.DeleteDialog.Message" -or
    [string]$action.dialogIcon.automationId -cne
        "Library.DeleteDialog.Icon" -or
    [string]$action.dialogIcon.helpText -cne "警告" -or
    [string]$action.dialogConfirm.automationId -cne
        "Library.DeleteDialog.Confirm" -or
    -not [bool]$action.clipboardExactMessage -or
    -not [bool]$action.targetExistsAfter -or
    [bool]$action.dangerMenuPhysicalHover.automationFallbackUsed) {
    throw "Formal GUI did not prove the shared library warning dialog contract."
}

$runtimePath = Join-Path $formalFullPath "gui\runtime-evidence.json"
$runtime = Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json
if ([string]$runtime.schema -cne "lumachart.windows.avalonia.gui-evidence.v14" -or
    [string]$runtime.platformScope -cne "Windows-only" -or
    [int]$runtime.chart.structure.noteCount -ne 2753 -or
    [int]$runtime.chart.structure.longNoteCount -ne 771) {
    throw "Formal GUI runtime is not the trusted real Resound MC workload."
}

$trustedChartSha =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$isolatedChartPath = Join-Path $formalFullPath (
    "gui\workspace\Dialog R2 Open Chart\1781536331.mc")
$isolatedChart = Get-FileEvidence $isolatedChartPath
if ([string]$runtime.chart.sourceSha256 -cne $trustedChartSha -or
    [string]$isolatedChart.sha256 -cne $trustedChartSha) {
    throw "The isolated real MC changed during GUI verification."
}

$screenshots = [Collections.Generic.List[object]]::new()
foreach ($path in @(
        [string]$action.contextMenuScreenshotPath,
        [string]$action.dialogScreenshotPath,
        [string]$capture.screenshotPath)) {
    $screenshots.Add((Get-FileEvidence $path))
}
if ([string]$screenshots[0].sha256 -cne
        [string]$action.contextMenuScreenshotSha256 -or
    [string]$screenshots[1].sha256 -cne
        [string]$action.dialogScreenshotSha256 -or
    [string]$screenshots[2].sha256 -cne
        [string]$capture.screenshotSha256) {
    throw "A formal GUI screenshot hash differs from capture evidence."
}

$changedPaths = @(
    "LumaChart.Avalonia\Dialogs\WindowsWpf110ChoiceDialog.cs",
    "LumaChart.Avalonia\Dialogs\LibraryDeleteConfirmationDialog.cs",
    "LumaChart.Avalonia\Dialogs\ChartValidationDialog.cs",
    "LumaChart.Avalonia\Dialogs\SettingsActionDialog.cs",
    "LumaChart.Avalonia.Specs\WindowsDialogParitySpecs.cs",
    "tools\New-WindowsAvaloniaDialogR2SliceEvidence.ps1"
)
$changedFiles = [Collections.Generic.List[object]]::new()
foreach ($path in $changedPaths) {
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
        "artifacts\windows-avalonia-dialog-slice-20260727-r1\" +
        "verification-evidence.json"))
if ([string]$predecessor.sha256 -cne
    "AFDCA77CC54C5A191C43240F286B63B46B66BD3E91274D34178496E4AAC9C6D4") {
    throw "Dialog r1 predecessor authority changed."
}

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.dialog-slice-verification.v2"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        platform = "Windows Avalonia only"
        contract = "wpf-1.1.0-dialog-r1"
        covered = @(
            "library-delete shared wrapper and legacy UIA",
            "chart-validation shared wrapper automated contract",
            "settings/cache shared wrapper automated contract",
            "real MC physical library open-document warning flow")
        guiNotYetClaimed = @(
            "chart-validation manual and save-blocked dialog flow",
            "settings backup/cache confirmation flow")
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
                Join-Path $formalFullPath "specs\avalonia-specs.log")
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
        screen = "2560x1600@150%"
        realChart = [ordered]@{
            noteCount = 2753
            longNoteCount = 771
            sha256 = $trustedChartSha
            sourceUnchanged = $true
            isolatedFile = $isolatedChart
        }
        interaction = [ordered]@{
            contextMenu = "physical right click and foreground pointer hover"
            dialog = "physical confirm click"
            clipboard = "physical Ctrl+C"
            automationFallbackUsedForDangerHover = $false
            targetFolderPreserved = $true
        }
        capture = Get-FileEvidence $capturePath
        runtime = Get-FileEvidence $runtimePath
        interactionEvidence = Get-FileEvidence (
            Join-Path $formalFullPath "gui\interaction-evidence.json")
        screenshots = $screenshots
    }
    source = [ordered]@{
        changedFiles = $changedFiles
        formalRootMiB = [Math]::Round(
            [double](Get-ChildItem -LiteralPath $formalFullPath -Recurse -File |
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

$verification | ConvertTo-Json -Depth 28 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
$result = Get-FileEvidence $verificationPath
$result | ConvertTo-Json -Depth 5
