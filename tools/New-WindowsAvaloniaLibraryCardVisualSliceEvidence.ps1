param(
    [string]$FormalRoot = (
        Join-Path $PSScriptRoot `
            "..\artifacts\windows-avalonia-library-card-visual-slice-20260728-r1"),
    [string]$ChartActionsDirectoryName = "library-actions-r3"
)

$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$formalRoot = [IO.Path]::GetFullPath($FormalRoot)
$projectBoundary = $projectRoot.TrimEnd('\') + '\'
if (-not $formalRoot.StartsWith(
        $projectBoundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal root must stay below the project root: $formalRoot"
}
if (-not (Test-Path -LiteralPath $formalRoot -PathType Container)) {
    throw "Formal root not found: $formalRoot"
}

Add-Type -AssemblyName System.Drawing

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Read-Json([string]$Path) {
    Assert (
        Test-Path -LiteralPath $Path -PathType Leaf) (
        "Missing JSON: $Path")
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 |
        ConvertFrom-Json
}

function File-Evidence([string]$Path) {
    Assert (
        Test-Path -LiteralPath $Path -PathType Leaf) (
        "Missing evidence file: $Path")
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        bytes = [long]$item.Length
        sha256 = (
            Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    Assert (
        ($text.Contains("0 个警告", [StringComparison]::Ordinal) -and
        $text.Contains("0 个错误", [StringComparison]::Ordinal)) -or
        ($text.Contains("0 Warning(s)", [StringComparison]::Ordinal) -and
        $text.Contains("0 Error(s)", [StringComparison]::Ordinal))) (
        "Strict build is not 0 warning / 0 error: $Path")
    foreach ($forbidden in @(
            "OLLVM",
            "Obfuscator",
            "NativeAOT",
            "PublishAot=true",
            "code virtualization",
            "Android",
            "iOS",
            "MacCatalyst",
            "WebAssembly")) {
        Assert (
            -not $text.Contains(
                $forbidden,
                [StringComparison]::OrdinalIgnoreCase)) (
            "Strict build contains forbidden text '$forbidden': $Path")
    }
    return File-Evidence $Path
}

function Assert-BelowFormalRoot([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (
        $full.StartsWith(
            $formalRoot.TrimEnd('\') + '\',
            [StringComparison]::OrdinalIgnoreCase)) (
        "$Label escaped the formal root: $full")
    return $full
}

function New-FocusedScreenshot {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][Drawing.Rectangle]$Crop,
        [Parameter(Mandatory = $true)][string]$Purpose
    )

    $source = [Drawing.Bitmap]::new($SourcePath)
    try {
        Assert (
            $Crop.X -ge 0 -and
            $Crop.Y -ge 0 -and
            $Crop.Right -le $source.Width -and
            $Crop.Bottom -le $source.Height) (
            "Focused screenshot crop exceeds source bounds: $SourcePath")
        $destinationDirectory =
            [IO.Path]::GetDirectoryName($DestinationPath)
        [IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null
        $focused = [Drawing.Bitmap]::new(
            $Crop.Width,
            $Crop.Height,
            [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $graphics = [Drawing.Graphics]::FromImage($focused)
            try {
                $graphics.DrawImage(
                    $source,
                    [Drawing.Rectangle]::new(
                        0,
                        0,
                        $Crop.Width,
                        $Crop.Height),
                    $Crop,
                    [Drawing.GraphicsUnit]::Pixel)
            }
            finally { $graphics.Dispose() }
            $focused.Save(
                $DestinationPath,
                [Drawing.Imaging.ImageFormat]::Png)
        }
        finally { $focused.Dispose() }
    }
    finally { $source.Dispose() }

    $evidence = File-Evidence $DestinationPath
    $evidence["crop"] = [ordered]@{
        x = $Crop.X
        y = $Crop.Y
        width = $Crop.Width
        height = $Crop.Height
    }
    $evidence["purpose"] = $Purpose
    $evidence["captureKind"] =
        "derived focus crop from hash-verified physical desktop capture"
    return $evidence
}

$chartActionsRoot =
    Join-Path $formalRoot "gui\$ChartActionsDirectoryName"
$chartActionsPath = Join-Path $chartActionsRoot "evidence.json"
$largeGuiRoot = Join-Path $formalRoot "gui\large-library"
$largeGuiPath = Join-Path $largeGuiRoot "gui-evidence.json"
$largeRuntimePath = Join-Path $largeGuiRoot "runtime-evidence.json"
$avaloniaSpecsPath =
    Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$avaloniaSpecsLogPath =
    Join-Path $formalRoot "tests\avalonia-specs.log"
$mainSpecsLogPath = Join-Path $formalRoot "tests\main-specs.log"

$chartActions = Read-Json $chartActionsPath
$largeGui = Read-Json $largeGuiPath
$largeRuntime = Read-Json $largeRuntimePath
$avaloniaSpecs = Read-Json $avaloniaSpecsPath

Assert (
    [string]$chartActions.schema -ceq
        "lumachart.windows.avalonia.library-chart-actions-gui.v1" -and
    [string]$chartActions.status -ceq "passed-migration-incomplete" -and
    [string]$chartActions.platform -ceq "Windows Avalonia only") (
    "Library chart-action GUI boundary drifted.")
Assert (
    [int]$chartActions.process.exitCode -eq 0 -and
    -not [bool]$chartActions.process.topmostAtStart -and
    -not [bool]$chartActions.process.topmostBeforeClose) (
    "Chart-action process exit or non-topmost evidence drifted.")
Assert (
    [bool]$chartActions.inputs.currentTurnDesktopConsent -and
    [long]$chartActions.inputs.minimumIdleMilliseconds -ge 3000 -and
    [long]$chartActions.inputs.initialIdleMilliseconds -ge 3000 -and
    [bool]$chartActions.inputs.postedTargetPointerMessagesUsed -and
    [bool]$chartActions.inputs.uiaInvokeUsed -and
    -not [bool]$chartActions.inputs.win32MouseInputInjectionUsed -and
    -not [bool]$chartActions.inputs.hardwareMouseInputClaimed -and
    -not [bool]$chartActions.inputs.hardwareKeyboardInputClaimed -and
    -not [bool]$chartActions.inputs.enterKeySent -and
    [bool]$chartActions.inputs.uiaWindowCloseUsed -and
    -not [bool]$chartActions.inputs.persistentTopmostUsed) (
    "Chart-action consent, input provenance or topmost evidence drifted.")

$folderExpandActions = @(
    $chartActions.inputs.actions |
    Where-Object { $_.automationId -ceq "Library.FolderExpand" })
Assert ($folderExpandActions.Count -eq 2) (
    "Expected two real-MC folder expansion actions.")
foreach ($action in $folderExpandActions) {
    Assert (
        [string]$action.name -clike "收起谱面 · Resound · *" -and
        [string]$action.input -ceq "UI Automation InvokePattern" -and
        [int]$action.x -ge 600 -and
        [int]$action.x -le 900) (
        "Real-MC folder expansion did not use the WPF-positioned UIA action.")
}

$chartActionResult = $chartActions.chartActions
Assert (
    [bool]$chartActionResult.openChartDeletionBlocked -and
    [bool]$chartActionResult.targetChartMissingAfterUiRecycle -and
    [bool]$chartActionResult.targetRowAbsentAfterUiRefresh -and
    [bool]$chartActionResult.deleteFolderPreserved -and
    [bool]$chartActionResult.audioSiblingPreserved -and
    [bool]$chartActionResult.imageSiblingPreserved -and
    [int]$chartActionResult.recycleBinCountBefore -eq 0 -and
    [int]$chartActionResult.recycleBinCountAfter -eq 1 -and
    [bool]$chartActionResult.recycleBinUniqueTargetObserved -and
    [bool]$chartActionResult.restoredForCleanup -and
    [bool]$chartActionResult.restoreAttempted) (
    "Real-MC chart action, recycle-bin or restoration chain drifted.")
Assert (
    [string]$chartActionResult.targetChartSha256 -ceq
        "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") (
    "The isolated real-MC target hash drifted.")

$chartActionScreenshots = @()
foreach ($screenshot in @($chartActions.screenshots)) {
    $path = Assert-BelowFormalRoot (
        [string]$screenshot.path) "Chart-action screenshot"
    $file = File-Evidence $path
    Assert (
        $file.sha256 -ceq [string]$screenshot.sha256 -and
        $file.bytes -eq [long]$screenshot.bytes -and
        [int]$screenshot.width -eq 2560 -and
        [int]$screenshot.height -eq 1528 -and
        [string]$screenshot.captureKind -ceq
            "physical desktop window including popup/owner") (
        "Chart-action screenshot hash, dimensions or provenance drifted.")
    $chartActionScreenshots += $file
}
Assert ($chartActionScreenshots.Count -eq 5) (
    "Expected five chart-action screenshots.")

Assert (
    [string]$largeGui.schema -ceq
        "lumachart.windows.avalonia.library-virtualization-gui.v2" -and
    [string]$largeGui.status -ceq "passed-migration-incomplete" -and
    [string]$largeGui.platform -ceq "Windows Avalonia only") (
    "Large-library GUI evidence boundary drifted.")
Assert (
    [int]$largeGui.process.exitCode -eq 0 -and
    -not [bool]$largeGui.process.topmostAtStart -and
    -not [bool]$largeGui.process.topmostBeforeClose -and
    [double]$largeGui.process.processToEvidenceMilliseconds -le 10000) (
    "Large-library process exit, non-topmost or startup evidence drifted.")
Assert (
    [bool]$largeGui.input.currentTurnDesktopConsent -and
    [long]$largeGui.input.minimumIdleMilliseconds -ge 3000 -and
    [long]$largeGui.input.initialIdleMilliseconds -ge 3000 -and
    [bool]$largeGui.input.uiaScrollPatternObserved -and
    -not [bool]$largeGui.input.externalScrollIssued -and
    -not [bool]$largeGui.input.uiaSetFocusUsed -and
    -not [bool]$largeGui.input.uiaInvokeUsed -and
    -not [bool]$largeGui.input.uiaInvokeStateChanged -and
    [bool]$largeGui.input.uiaWindowCloseUsed -and
    -not [bool]$largeGui.input.postedTargetPointerMessagesUsed -and
    -not [bool]$largeGui.input.win32MouseInputInjectionUsed -and
    -not [bool]$largeGui.input.win32KeyboardInputInjectionUsed -and
    -not [bool]$largeGui.input.hardwareMouseInputClaimed -and
    -not [bool]$largeGui.input.hardwareKeyboardInputClaimed -and
    -not [bool]$largeGui.input.enterKeySent -and
    -not [bool]$largeGui.input.persistentTopmostUsed) (
    "Large-library consent or controlled-input evidence drifted.")
$largeActions = @($largeGui.input.actions)
Assert (
    $largeActions.Count -eq 1 -and
    [string]$largeActions[0].automationId -ceq "Library.FolderExpand" -and
    [string]$largeActions[0].name -ceq "Virtual Chart 04589" -and
    [string]$largeActions[0].input -ceq
        "controlled in-process SetExpanded on the current rebound card") (
    "Controlled recycled-card expansion evidence drifted.")
Assert (
    [int]$largeGui.fixture.folderCount -eq 9184 -and
    [int]$largeGui.fixture.chartCount -eq 9184 -and
    [long]$largeGui.fixture.payloadBytes -eq 1469440 -and
    [string]$largeGui.fixture.manifestSha256 -ceq
        "57AD627CD974B25B8DCC9FC0996AF13C40749B315AB2C535EF73504520754064" -and
    -not [bool]$largeGui.fixture.retainedInArtifacts) (
    "The isolated 9,184-chart fixture evidence drifted.")

$largeRuntimeEvidence = File-Evidence $largeRuntimePath
Assert (
    [IO.Path]::GetFullPath([string]$largeGui.runtime.path) -ceq
        [IO.Path]::GetFullPath($largeRuntimePath) -and
    [long]$largeGui.runtime.bytes -eq $largeRuntimeEvidence.bytes -and
    [string]$largeGui.runtime.sha256 -ceq
        $largeRuntimeEvidence.sha256) (
    "Large-library runtime path, length or hash drifted.")
Assert (
    [string]$largeRuntime.schema -ceq
        "lumachart.windows.avalonia.library-virtualization-runtime.v1" -and
    [string]$largeRuntime.status -ceq
        "captured-migration-incomplete" -and
    [string]$largeRuntime.platform -ceq "Windows Avalonia only") (
    "Large-library runtime boundary drifted.")
Assert (
    [int]$largeRuntime.indexedChartCount -eq 9184 -and
    [int]$largeRuntime.indexedFolderCount -eq 9184 -and
    [int]$largeRuntime.visibleFolderCount -eq 9184 -and
    [double]$largeRuntime.initializationMilliseconds -le 5000) (
    "Large-library indexing count or initialization threshold drifted.")
Assert (
    [bool]$largeRuntime.containerTemplateOwnsStableCard -and
    -not [bool]$largeRuntime.funcDataTemplateUsed -and
    [string]$largeRuntime.itemsPanelType -ceq
        "Avalonia.Controls.VirtualizingStackPanel" -and
    [int]$largeRuntime.scrollSampleCount -eq 180 -and
    [int]$largeRuntime.maximumRealizedContainerCount -le 64 -and
    [int]$largeRuntime.uniqueListBoxItemInstances -le 96 -and
    [int]$largeRuntime.uniqueCardInstances -le 96 -and
    [int]$largeRuntime.staleBindingMismatchCount -eq 0 -and
    [int]$largeRuntime.maximumMaterializedCollapsedChartRows -eq 0) (
    "Stable recyclable-card or lazy-row materialization contract drifted.")
Assert (
    [string]$largeRuntime.evidenceExpandedDisplayTitle -ceq
        "Virtual Chart 04589" -and
    [int]$largeRuntime.evidenceExpandedChartRowCount -eq 1 -and
    [bool]$largeRuntime.evidenceExpandedBindingMatched -and
    [string]$largeRuntime.evidenceExpandedChartPath -clike
        "*\Song-04589\chart-04589.mc") (
    "Expansion state did not survive card recycling with the current chart.")
Assert (
    [int]$largeRuntime.scrollSettleMilliseconds.samples -eq 180 -and
    [double]$largeRuntime.scrollSettleMilliseconds.p95 -le 50 -and
    [double]$largeRuntime.scrollSettleMilliseconds.p99 -le 100 -and
    [int]$largeRuntime.inputQueueDelayMilliseconds.samples -eq 180 -and
    [double]$largeRuntime.inputQueueDelayMilliseconds.p95 -le 25 -and
    [double]$largeRuntime.inputQueueDelayMilliseconds.p99 -le 50) (
    "Scroll-settle or input-queue latency exceeded the slice threshold.")
Assert (
    [long]$largeRuntime.memory.managedBytesAfter -le 268435456 -and
    [long]$largeRuntime.memory.workingSetBytesAfter -le 1073741824) (
    "Large-library memory exceeded the slice threshold.")
Assert (
    -not (Test-Path -LiteralPath ([string]$largeRuntime.workspaceRoot))) (
    "The generated 9,184-chart fixture was retained after GUI verification.")
Assert (
    [bool]$largeGui.guiRebind.currentBindingMatched -and
    [string]$largeGui.guiRebind.expandedFolderName -ceq
        "Virtual Chart 04589" -and
    [string]$largeGui.guiRebind.materializedChartActionName -ceq
        "打开编辑 · Virtual Chart 04589  [Stress] · Song-04589\chart-04589.mc") (
    "Visible GUI binding or current chart action drifted.")

$largeScreenshotPath = Assert-BelowFormalRoot (
    [string]$largeGui.screenshot.path) "Large-library screenshot"
$largeScreenshotEvidence = File-Evidence $largeScreenshotPath
Assert (
    $largeScreenshotEvidence.sha256 -ceq
        [string]$largeGui.screenshot.sha256 -and
    $largeScreenshotEvidence.bytes -eq
        [long]$largeGui.screenshot.bytes -and
    [int]$largeGui.screenshot.width -eq 2560 -and
    [int]$largeGui.screenshot.height -eq 1528 -and
    [string]$largeGui.screenshot.captureKind -ceq
        "physical desktop window") (
    "Large-library screenshot hash, dimensions or provenance drifted.")

$focusedRoot = Join-Path $formalRoot "visual-focus"
$focusedChartActions = New-FocusedScreenshot `
    -SourcePath (
        Join-Path $chartActionsRoot "open-chart-context-menu.png") `
    -DestinationPath (
        Join-Path $focusedRoot "library-card-actions-focus.png") `
    -Crop ([Drawing.Rectangle]::new(0, 0, 2560, 1000)) `
    -Purpose (
        "WPF-aligned real-MC folder header, expanded chart row, " +
        "right-side action and context menu; bottom desktop overlay excluded")
$focusedLargeLibrary = New-FocusedScreenshot `
    -SourcePath $largeScreenshotPath `
    -DestinationPath (
        Join-Path $focusedRoot "library-card-large-focus.png") `
    -Crop ([Drawing.Rectangle]::new(0, 0, 1980, 1528)) `
    -Purpose (
        "9,184-folder recycled-card visual and expanded target row; " +
        "right-side external desktop notification region excluded")

$checks = @($avaloniaSpecs.checks)
Assert (
    [string]$avaloniaSpecs.schema -ceq
        "lumachart.windows.avalonia.slice-specs.v2" -and
    [string]$avaloniaSpecs.status -ceq "passed" -and
    $checks.Count -eq 497 -and
    @($checks | Where-Object { -not $_.passed }).Count -eq 0) (
    "Avalonia Specs are not 497/497.")
$dedicatedSpecs = @(
    "windows-library-card-expansion-folder-scoped",
    "windows-library-card-rebind-clears-stale-rows",
    "windows-library-card-rebound-action-current-chart",
    "windows-library-card-expand-action-current-state",
    "windows-library-card-wpf-geometry")
foreach ($name in $dedicatedSpecs) {
    $matches = @($checks | Where-Object { $_.name -ceq $name })
    Assert (
        $matches.Count -eq 1 -and [bool]$matches[0].passed) (
        "Dedicated library-card spec missing or failed: $name")
}

$mainSpecsText =
    Get-Content -LiteralPath $mainSpecsLogPath -Raw -Encoding UTF8
Assert (
    $mainSpecsText.Contains(
        "79/79 specs passed.",
        [StringComparison]::Ordinal)) (
    "Main Specs are not 79/79.")

$builds = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $formalRoot "build\build-avalonia.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\build-avalonia_specs.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\build-main_specs.log")
    onlineGuiServer = Assert-StrictBuild (
        Join-Path $formalRoot "build\build-loopback_gui_server.log")
}

$captureScriptPaths = @(
    (Join-Path $projectRoot `
        "tools\Capture-WindowsAvaloniaLibraryChartActionsGui.ps1"),
    (Join-Path $projectRoot `
        "tools\Capture-WindowsAvaloniaLibraryVirtualizationGui.ps1"))
foreach ($captureScriptPath in $captureScriptPaths) {
    $captureScriptText =
        Get-Content -LiteralPath $captureScriptPath -Raw -Encoding UTF8
    foreach ($forbidden in @(
            "HWND_TOPMOST",
            "SetWindowPos",
            "SendKeys",
            "{ENTER}",
            "keybd_event")) {
        Assert (
            -not $captureScriptText.Contains(
                $forbidden,
                [StringComparison]::OrdinalIgnoreCase)) (
            "GUI capture script contains forbidden API '$forbidden'.")
    }
}

$wpfBaseline = File-Evidence (
    Join-Path $projectRoot `
        "artifacts\final-audit-20260721\wpf-gui-populated-library.png")
$realMc = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
$installer = File-Evidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert (
    $realMc.sha256 -ceq
        "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") (
    "Frozen real MC fixture changed.")
Assert (
    $installer.sha256 -ceq
        "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") (
    "Frozen WPF installer changed.")

$sourceFiles = @(
    "LumaChart.Avalonia\Controls\LibraryFolderCard.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsLibraryFolderExpansionState.cs",
    "LumaChart.Avalonia\Evidence\WindowsLibraryVirtualizationRuntimeEvidence.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\WindowsLibraryFolderCardSpecs.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "tools\Capture-WindowsAvaloniaLibraryChartActionsGui.ps1",
    "tools\Capture-WindowsAvaloniaLibraryVirtualizationGui.ps1",
    "tools\New-WindowsAvaloniaLibraryCardVisualSliceEvidence.ps1")
$sourceEvidence = @(
    $sourceFiles |
    ForEach-Object { File-Evidence (Join-Path $projectRoot $_) })

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.library-card-visual-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    platform = "Windows Avalonia only"
    buildMode = "ordinary .NET Release"
    formalRoot = $formalRoot
    chartActionsDirectoryName = $ChartActionsDirectoryName
    results = [ordered]@{
        avaloniaStrictBuildWarnings = 0
        avaloniaStrictBuildErrors = 0
        avaloniaSpecsStrictBuildWarnings = 0
        avaloniaSpecsStrictBuildErrors = 0
        mainSpecsStrictBuildWarnings = 0
        mainSpecsStrictBuildErrors = 0
        onlineGuiServerStrictBuildWarnings = 0
        onlineGuiServerStrictBuildErrors = 0
        avaloniaSpecsPassed = 497
        avaloniaSpecsTotal = 497
        mainSpecsPassed = 79
        mainSpecsTotal = 79
        realMcFolderExpandUiaInvokeCount = 2
        realMcOpenChartDeletionBlocked = $true
        realMcTargetMovedToRecycleBin = $true
        isolatedTargetRestoredForCleanup = $true
        indexedFolders = 9184
        indexedCharts = 9184
        initializationMilliseconds =
            [double]$largeRuntime.initializationMilliseconds
        scrollSamples = 180
        realizedContainersMaximum =
            [int]$largeRuntime.maximumRealizedContainerCount
        uniqueListBoxItems =
            [int]$largeRuntime.uniqueListBoxItemInstances
        uniqueLibraryCards =
            [int]$largeRuntime.uniqueCardInstances
        staleBindingMismatches = 0
        materializedCollapsedRowsMaximum = 0
        expandedStateSurvivedRecycling = $true
        scrollSettleP50Milliseconds =
            [double]$largeRuntime.scrollSettleMilliseconds.p50
        scrollSettleP95Milliseconds =
            [double]$largeRuntime.scrollSettleMilliseconds.p95
        scrollSettleP99Milliseconds =
            [double]$largeRuntime.scrollSettleMilliseconds.p99
        inputQueueP50Milliseconds =
            [double]$largeRuntime.inputQueueDelayMilliseconds.p50
        inputQueueP95Milliseconds =
            [double]$largeRuntime.inputQueueDelayMilliseconds.p95
        inputQueueP99Milliseconds =
            [double]$largeRuntime.inputQueueDelayMilliseconds.p99
        renderScaling = [double]$largeRuntime.renderScaling
        reportedRefreshRate = [int]$largeGui.display.reportedRefreshRate
        chartActionWin32MouseInputInjectionUsed = $false
        largeProbeExternalInputIssued = $false
        enterKeySent = $false
        persistentTopmostUsed = $false
        fixtureRetained = $false
        productionServerDeployed = $false
        mobileProjectsTouched = $false
        protectionOrAotUsed = $false
        releaseInstallerOverwritten = $false
        windowsAvaloniaCanReplaceWpf = $false
        userManualReplacementApprovalReceived = $false
    }
    visualComparison = [ordered]@{
        wpfScreenshot = $wpfBaseline
        geometrySpecs = $dedicatedSpecs
        focusedScreenshots = @(
            $focusedChartActions,
            $focusedLargeLibrary)
        sourcePhysicalCapturesRetained = $true
        focusCropReason =
            "A persistent external QQ desktop notification was present in " +
            "the source physical captures; focus crops exclude only that " +
            "desktop-overlay region and preserve the hash-verified sources."
    }
    immutable = [ordered]@{
        realMc = $realMc
        frozenWpfInstaller = $installer
    }
    files = [ordered]@{
        chartActionsEvidence = File-Evidence $chartActionsPath
        chartActionScreenshots = $chartActionScreenshots
        largeGuiEvidence = File-Evidence $largeGuiPath
        largeRuntimeEvidence = $largeRuntimeEvidence
        largeScreenshot = $largeScreenshotEvidence
        avaloniaSpecsEvidence = File-Evidence $avaloniaSpecsPath
        avaloniaSpecsRun = File-Evidence $avaloniaSpecsLogPath
        mainSpecsRun = File-Evidence $mainSpecsLogPath
        builds = $builds
        sourceAndTools = $sourceEvidence
    }
    residuals = @(
        "After 180 recycled jumps the external UIA provider did not reliably invoke the recycled expansion button, so the large probe used the explicitly recorded controlled in-process SetExpanded path; two isolated real-MC cards did pass external UIA Invoke.",
        "The source physical screenshots contain a persistent external QQ desktop notification; hash-verified focus crops exclude only that notification region.",
        "A physical mouse card-action run and same-machine WPF/Avalonia visual A/B remain open.",
        "The physical 120 Hz, true 4K and same-machine WPF/Avalonia large-library A/B gates remain open.",
        "The complete 214-row matrix, remaining online/format/security/installer gates and user replacement approval remain open.")
}

$outputPath = Join-Path $formalRoot "verification-evidence.json"
$verification | ConvertTo-Json -Depth 16 |
    Set-Content -LiteralPath $outputPath -Encoding utf8NoBOM
$verification | ConvertTo-Json -Depth 16
