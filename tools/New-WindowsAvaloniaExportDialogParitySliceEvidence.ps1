param(
    [string]$Root =
        "artifacts\windows-avalonia-export-dialog-parity-slice-20260727-r1"
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia export-dialog verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath(
    (Join-Path $projectRoot (
        "artifacts\windows-avalonia-export-dialog-parity-slice-20260727-r1"))).
    TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).
    TrimEnd('\')
if (-not $formalRoot.Equals(
        $expectedRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal export-dialog root must be exactly $expectedRoot"
}
if (-not (Test-Path -LiteralPath $formalRoot -PathType Container)) {
    throw "Formal export-dialog root does not exist: $formalRoot"
}
$verificationPath = Join-Path $formalRoot "verification-evidence.json"
if (Test-Path -LiteralPath $verificationPath) {
    throw "Verification evidence already exists: $verificationPath"
}

function Get-FileEvidence {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Required evidence file is missing: $fullPath"
    }
    $item = Get-Item -LiteralPath $fullPath
    return [ordered]@{
        path = [IO.Path]::GetRelativePath(
            $projectRoot,
            $fullPath).Replace("/", "\")
        length = [long]$item.Length
        sha256 = (
            Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    }
}

function Assert-StrictBuildLog {
    param([Parameter(Mandatory = $true)][string]$Path)

    $text = Get-Content -LiteralPath $Path -Raw
    if ($text -notmatch "已成功生成" -or
        $text -notmatch "0 个警告" -or
        $text -notmatch "0 个错误" -or
        $text -match "生成失败") {
        throw "Strict ordinary Release build did not prove 0 warning / 0 error: $Path"
    }
    return Get-FileEvidence $Path
}

function Require-Equal {
    param(
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if ($Actual -ne $Expected) {
        throw "$Description differs. Expected '$Expected'; actual '$Actual'."
    }
}

$buildLogs = [ordered]@{
    avalonia = Assert-StrictBuildLog (
        Join-Path $formalRoot "build\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuildLog (
        Join-Path $formalRoot "build\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuildLog (
        Join-Path $formalRoot "build\main-specs-build.log")
}

$avaloniaSpecsPath = Join-Path (
    $formalRoot) "tests\avalonia-specs-evidence.json"
$avaloniaSpecs = Get-Content -LiteralPath $avaloniaSpecsPath -Raw |
    ConvertFrom-Json
$avaloniaChecks = @($avaloniaSpecs.checks)
$failedAvaloniaChecks = @($avaloniaChecks | Where-Object {
    -not [bool]$_.passed
})
if ([string]$avaloniaSpecs.status -cne "passed" -or
    $avaloniaChecks.Count -ne 427 -or
    $failedAvaloniaChecks.Count -ne 0) {
    throw "Avalonia Specs did not prove 427/427."
}
$requiredCheckNames = @(
    "dialog-chart-export-options-use-measured-wpf-110-geometry",
    "dialog-chart-export-results-use-native-wpf-message-box-semantics"
)
$focusedChecks = @($avaloniaChecks | Where-Object {
    [string]$_.name -in $requiredCheckNames
})
if ($focusedChecks.Count -ne 2) {
    throw "The two focused chart-export parity checks were not present exactly once."
}
foreach ($name in $requiredCheckNames) {
    $matching = @($focusedChecks | Where-Object {
        [string]$_.name -ceq $name -and [bool]$_.passed
    })
    if ($matching.Count -ne 1) {
        throw "Focused Avalonia check did not pass exactly once: $name"
    }
}

$avaloniaSpecsLogPath = Join-Path (
    $formalRoot) "tests\avalonia-specs-run.log"
$avaloniaSpecsLog = Get-Content -LiteralPath $avaloniaSpecsLogPath -Raw
if ($avaloniaSpecsLog -notmatch
    "Avalonia slice verification: passed") {
    throw "Avalonia Specs run log did not report passed."
}
$mainSpecsLogPath = Join-Path (
    $formalRoot) "tests\main-specs-run.log"
$mainSpecsLog = Get-Content -LiteralPath $mainSpecsLogPath -Raw
if ($mainSpecsLog -notmatch "79/79 specs passed\.") {
    throw "Main Specs did not prove 79/79."
}

$guiPath = Join-Path $formalRoot "gui\gui-evidence.json"
$gui = Get-Content -LiteralPath $guiPath -Raw | ConvertFrom-Json
$trustedChartSha256 =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$trustedInstallerSha256 =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
if ([string]$gui.schema -cne
        "lumachart.windows.avalonia.export-dialog-parity-gui-evidence.v1" -or
    [string]$gui.status -cne "passed-migration-incomplete" -or
    [string]$gui.scope.platform -cne "Windows Avalonia only" -or
    [bool]$gui.scope.productionServerContacted -or
    [bool]$gui.scope.mobilePlatformTouched -or
    [bool]$gui.scope.ollvmUsed -or
    [bool]$gui.scope.obfuscationUsed -or
    [bool]$gui.scope.packingUsed -or
    [bool]$gui.scope.codeVirtualizationUsed -or
    [bool]$gui.scope.aotUsed -or
    [bool]$gui.scope.nativeAotUsed) {
    throw "GUI evidence scope/status does not prove Windows-only ordinary managed Release."
}
if (-not [bool]$gui.fixture.unchanged -or
    [string]$gui.fixture.sha256Before -cne $trustedChartSha256 -or
    [string]$gui.fixture.sha256After -cne $trustedChartSha256 -or
    [string]$gui.frozenInstaller.sha256Before -cne
        $trustedInstallerSha256 -or
    [string]$gui.frozenInstaller.sha256After -cne
        $trustedInstallerSha256 -or
    -not [bool]$gui.frozenInstaller.unchanged) {
    throw "Real MC or frozen installer changed during formal GUI capture."
}

$avaloniaGui = $gui.avalonia
$actualExport = $avaloniaGui.actualExport
if (-not [bool]$avaloniaGui.fiveOptionStatesVerified -or
    -not [bool]$avaloniaGui.allModeSelectionsUsedPhysicalPointer -or
    [bool]$avaloniaGui.meaningfulSelectionOrResultAutomationFallbackUsed -or
    [bool]$avaloniaGui.aggregateAutomationFallbackUsed -or
    -not [bool]$avaloniaGui.defaultFullPackage.verified -or
    -not [bool]$avaloniaGui.singleChart.verified -or
    -not [bool]$avaloniaGui.singleRatePackage.verified -or
    -not [bool]$avaloniaGui.ratePack.verified -or
    -not [bool]$avaloniaGui.hiddenFieldValidation.verified -or
    -not [bool]$avaloniaGui.singleRatePackage.pitchAction.
        physicalClickRetained -or
    [bool]$avaloniaGui.singleRatePackage.pitchAction.
        automationToggleFallbackUsed -or
    -not [bool]$actualExport.verified -or
    [string]$actualExport.requested.format -cne "Malody" -or
    [string]$actualExport.requested.mode -cne "SingleRatePackage" -or
    [double]$actualExport.requested.rate -ne 1.0 -or
    [bool]$actualExport.requested.preservePitch -or
    [bool]$actualExport.modeSelection.automationSelectionFallbackUsed -or
    [bool]$actualExport.rateInput.automationValueFallbackUsed -or
    [bool]$actualExport.rateInput.automationInputFocusFallbackUsed -or
    [bool]$actualExport.rateInput.automationFocusFallbackUsed -or
    [bool]$actualExport.preservePitch.automationToggleFallbackUsed -or
    [bool]$actualExport.nativeSave.automationValueFallbackUsed -or
    [bool]$actualExport.nativeSave.automationInputFocusFallbackUsed -or
    -not [bool]$actualExport.nativeSave.physicalInputRetained -or
    [string]$actualExport.result.dialogClassName -cne "#32770" -or
    [string]$actualExport.result.message.automationId -cne "65535" -or
    [string]$actualExport.result.confirm.automationId -cne "2" -or
    [string]$actualExport.result.confirm.name -cne "确定" -or
    -not [bool]$actualExport.result.physicalConfirmClickRetained -or
    [bool]$actualExport.result.closeAutomationFallbackUsed) {
    throw "Formal Avalonia GUI did not prove a zero-fallback physical export flow."
}

$geometry = $gui.geometry
if ([double]$geometry.displayScale -ne 1.5 -or
    [double]$geometry.tolerancePixels -ne 1 -or
    [Math]::Abs(
        [double]$geometry.avalonia.format.width -
        [double]$geometry.wpf.format.width) -gt 1 -or
    [Math]::Abs(
        [double]$geometry.avalonia.format.height -
        [double]$geometry.wpf.format.height) -gt 1 -or
    [Math]::Abs(
        [double]$geometry.avalonia.mode.width -
        [double]$geometry.wpf.mode.width) -gt 1 -or
    [Math]::Abs(
        [double]$geometry.avalonia.mode.height -
        [double]$geometry.wpf.mode.height) -gt 1 -or
    [Math]::Abs(
        [double]$geometry.avalonia.cancel.width -
        [double]$geometry.wpf.cancel.width) -gt 1 -or
    [Math]::Abs(
        [double]$geometry.avalonia.cancel.height -
        [double]$geometry.wpf.cancel.height) -gt 1 -or
    [Math]::Abs(
        [double]$geometry.avalonia.confirm.width -
        [double]$geometry.wpf.confirm.width) -gt 1 -or
    [Math]::Abs(
        [double]$geometry.avalonia.confirm.height -
        [double]$geometry.wpf.confirm.height) -gt 1 -or
    -not [bool]$geometry.actionButtonDimensionsWithinOnePhysicalPixel -or
    -not [bool]$geometry.initialPreservePitchEnabledExact) {
    throw "Avalonia export controls differ from live WPF geometry beyond one physical pixel."
}

$wpf = $gui.wpfReference
if (-not [bool]$wpf.launchedOnlyExportDialog -or
    [bool]$wpf.mainClientStarted -or
    [bool]$wpf.productionServerContacted -or
    [string]$wpf.nativeResult.dialog.className -cne "#32770" -or
    [string]$wpf.nativeResult.message.automationId -cne "65535" -or
    [string]$wpf.nativeResult.message.className -cne "Static" -or
    [string]$wpf.nativeResult.confirm.automationId -cne "2" -or
    [string]$wpf.nativeResult.confirm.name -cne "确定" -or
    [string]$wpf.nativeResult.confirm.className -cne "Button" -or
    [bool]$wpf.close.automationFallbackUsed -or
    [bool]$wpf.nativeResultConfirm.automationFallbackUsed) {
    throw "Live WPF reference did not prove the exact dialog/native-result baseline."
}

$archivePath = [string]$gui.archive.file.path
$archiveFile = Get-FileEvidence $archivePath
if ([string]$archiveFile.sha256 -cne
        [string]$gui.archive.file.sha256 -or
    [long]$archiveFile.length -ne [long]$gui.archive.file.length -or
    [int]$gui.archive.entryCount -ne 3 -or
    @($gui.archive.entries).Count -ne 3 -or
    [int]$gui.archive.noteCount -lt 2753 -or
    -not [bool]$gui.archive.compactMcJsonParsed -or
    -not [bool]$gui.archive.resourcesRetained) {
    throw "Formal real-chart MCZ output does not match its declared compact archive evidence."
}

$visual = $gui.visualComparison
$normalizedFile = Get-FileEvidence (
    [string]$visual.normalizedAvalonia.path)
$wpfImageFile = Get-FileEvidence ([string]$visual.wpf.path)
if ([string]$normalizedFile.sha256 -cne
        [string]$visual.normalizedAvalonia.sha256 -or
    [string]$wpfImageFile.sha256 -cne [string]$visual.wpf.sha256 -or
    [int]$visual.normalization.targetWidth -ne 810 -or
    [int]$visual.normalization.targetHeight -ne 1050 -or
    [int]$visual.normalization.cropLeft -ne 20 -or
    [int]$visual.normalization.cropTop -ne 20 -or
    [double]$visual.sampledMetrics.meanAbsoluteRgbDifference -gt 4.0 -or
    [double]$visual.sampledMetrics.within16Fraction -lt 0.94) {
    throw "Normalized Avalonia/WPF default-page visual comparison exceeded the established preflight gate."
}

$screenshots = [Collections.Generic.List[object]]::new()
foreach ($property in $gui.screenshots.PSObject.Properties) {
    $file = Get-FileEvidence ([string]$property.Value.path)
    if ([string]$file.sha256 -cne [string]$property.Value.sha256 -or
        [long]$file.length -ne [long]$property.Value.length) {
        throw "Screenshot differs from declared evidence: $($property.Name)"
    }
    $screenshots.Add([ordered]@{
        name = $property.Name
        file = $file
    })
}
if ($screenshots.Count -ne 10) {
    throw "Formal export-dialog GUI evidence must contain exactly ten screenshots."
}

$capturePath = [string]$avaloniaGui.capture.path
$capture = Get-Content -LiteralPath $capturePath -Raw | ConvertFrom-Json
$testProcessIds = @(
    [int]$capture.processId,
    [int]$wpf.dialogHostProcessId,
    [int]$wpf.resultHostProcessId)
$leftoverTestProcesses = [Collections.Generic.List[int]]::new()
foreach ($processId in $testProcessIds) {
    if ($processId -gt 0 -and
        $null -ne (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
        $leftoverTestProcesses.Add($processId)
    }
}
if ($leftoverTestProcesses.Count -ne 0) {
    throw "Formal GUI left evidence-owned test processes running: $($leftoverTestProcesses -join ', ')"
}

$changedFiles = [Collections.Generic.List[object]]::new()
foreach ($relativePath in @(
        "LumaChart.Avalonia\Dialogs\MalodyFullPackageExportDialog.cs",
        "LumaChart.Avalonia\Infrastructure\WindowsChartExportDialogParityPolicy.cs",
        "LumaChart.Avalonia\Infrastructure\WindowsNativeMessageBox.cs",
        "LumaChart.Avalonia\MainWindow.cs",
        "LumaChart.Avalonia.Specs\WindowsDialogParitySpecs.cs",
        "tools\Capture-WindowsAvaloniaGui.ps1",
        "tools\Capture-WindowsAvaloniaExportDialogParityGui.ps1",
        "tools\New-WindowsAvaloniaExportDialogParitySliceEvidence.ps1")) {
    $changedFiles.Add(
        (Get-FileEvidence (Join-Path $projectRoot $relativePath)))
}
$removedResultDialog =
    "LumaChart.Avalonia\Dialogs\MalodyFullPackageExportResultDialog.cs"
if (Test-Path -LiteralPath (Join-Path $projectRoot $removedResultDialog)) {
    throw "Obsolete custom dark export-result dialog still exists."
}

$installer = Get-FileEvidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
if ([string]$installer.sha256 -cne $trustedInstallerSha256) {
    throw "Frozen WPF installer hash changed."
}
$predecessor = Get-FileEvidence (
    Join-Path $projectRoot (
        "artifacts\windows-avalonia-startup-offline-slice-20260727-r1\" +
        "verification-evidence.json"))
if ([string]$predecessor.sha256 -cne
    "E6C537F857AB3CC3FD5F9523CA0DA1C6C78841CB810B7E211011D94026F63339") {
    throw "Startup/offline predecessor authority changed."
}

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.export-dialog-parity-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        platform = "Windows Avalonia only"
        wpfVersion = "1.1.0"
        covered = @(
            "540x700 WPF export chooser visual and geometry parity",
            "five real option-state transitions and hidden-field validation",
            "whole-row PreservePitch physical pointer semantics",
            "real Resound SingleRatePackage MCZ export",
            "native #32770 success MessageBox and physical OK",
            "live isolated WPF dialog and MessageBox reference")
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
            passed = 427
            total = 427
            failed = 0
            focusedChecks = $focusedChecks
            evidence = Get-FileEvidence $avaloniaSpecsPath
            log = Get-FileEvidence $avaloniaSpecsLogPath
        }
        mainSpecs = [ordered]@{
            passed = 79
            total = 79
            failed = 0
            log = Get-FileEvidence $mainSpecsLogPath
        }
    }
    gui = [ordered]@{
        status = "passed"
        cleanRerunAfterUserMouseClarification = $true
        physicalPointerAndKeyboard = $true
        automationFallbackUsed = $false
        realChartSha256 = $trustedChartSha256
        sourceUnchanged = $true
        fiveOptionStatesVerified = $true
        compactMczParsed = $true
        archive = $archiveFile
        nativeResult = [ordered]@{
            dialogClassName = "#32770"
            messageAutomationId = "65535"
            confirmAutomationId = "2"
            confirmName = "确定"
            physicalConfirmClickRetained = $true
        }
        geometry = $geometry
        visualComparison = $visual
        manualVisualReview = [ordered]@{
            required = $true
            performed = $true
            result = "passed"
            reviewedImages = @(
                "Avalonia normalized default",
                "WPF default",
                "Avalonia native result",
                "WPF native result")
        }
        evidence = Get-FileEvidence $guiPath
        capture = Get-FileEvidence $capturePath
        runtime = Get-FileEvidence ([string]$avaloniaGui.runtime.path)
        interaction =
            Get-FileEvidence ([string]$avaloniaGui.interaction.path)
        screenshots = $screenshots
        evidenceOwnedProcessIds = $testProcessIds
        leftoverEvidenceOwnedProcessIds = @()
    }
    source = [ordered]@{
        changedFiles = $changedFiles
        removedFiles = @(
            [ordered]@{
                path = $removedResultDialog
                exists = $false
                reason = "WPF uses a native MessageBox instead of a custom result window"
            })
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
        thisSlicePassed = $true
        fullWindowsMigrationComplete = $false
        userReplacementApproval = $false
        otherPlatformAuthorization = $false
    }
}
$verification | ConvertTo-Json -Depth 30 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
Get-FileEvidence $verificationPath | ConvertTo-Json -Depth 6
