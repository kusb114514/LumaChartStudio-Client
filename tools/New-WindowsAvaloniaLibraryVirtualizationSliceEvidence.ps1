param(
    [string]$FormalRoot = (
        Join-Path $PSScriptRoot `
            "..\artifacts\windows-avalonia-library-virtualization-slice-20260728-r1")
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
        $text.Contains("0 个警告", [StringComparison]::Ordinal) -and
        $text.Contains("0 个错误", [StringComparison]::Ordinal)) (
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
            "Strict build contains forbidden platform/protection text '$forbidden': $Path")
    }
    return File-Evidence $Path
}

$guiPath = Join-Path $formalRoot "gui\gui-evidence.json"
$runtimePath = Join-Path $formalRoot "gui\runtime-evidence.json"
$avaloniaSpecsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$avaloniaSpecsLogPath = Join-Path $formalRoot "tests\avalonia-specs.log"
$mainSpecsLogPath = Join-Path $formalRoot "tests\main-specs.log"
$gui = Read-Json $guiPath
$runtime = Read-Json $runtimePath
$avaloniaSpecs = Read-Json $avaloniaSpecsPath

Assert (
    [string]$gui.schema -ceq
        "lumachart.windows.avalonia.library-virtualization-gui.v1" -and
    [string]$gui.status -ceq "passed-migration-incomplete" -and
    [string]$gui.platform -ceq "Windows Avalonia only") (
    "Library virtualization GUI evidence boundary drifted.")
Assert (
    [int]$gui.process.exitCode -eq 0 -and
    -not [bool]$gui.process.topmostAtStart -and
    -not [bool]$gui.process.topmostBeforeClose -and
    [double]$gui.process.processToEvidenceMilliseconds -le 10000) (
    "GUI process exit, non-topmost or startup evidence drifted.")
Assert (
    [bool]$gui.input.currentTurnDesktopConsent -and
    [long]$gui.input.minimumIdleMilliseconds -ge 3000 -and
    [long]$gui.input.initialIdleMilliseconds -ge 3000 -and
    [bool]$gui.input.uiaScrollPatternObserved -and
    -not [bool]$gui.input.externalScrollIssued -and
    -not [bool]$gui.input.uiaSetFocusUsed -and
    -not [bool]$gui.input.uiaInvokeUsed -and
    [bool]$gui.input.uiaWindowCloseUsed -and
    -not [bool]$gui.input.postedTargetPointerMessagesUsed -and
    -not [bool]$gui.input.win32MouseInputInjectionUsed -and
    -not [bool]$gui.input.win32KeyboardInputInjectionUsed -and
    -not [bool]$gui.input.hardwareMouseInputClaimed -and
    -not [bool]$gui.input.hardwareKeyboardInputClaimed -and
    -not [bool]$gui.input.enterKeySent -and
    -not [bool]$gui.input.persistentTopmostUsed) (
    "GUI consent or zero-input safety evidence drifted.")
$actions = @($gui.input.actions)
Assert (
    $actions.Count -eq 1 -and
    [string]$actions[0].automationId -ceq "Library.FolderExpand" -and
    [string]$actions[0].name -ceq "Virtual Chart 04589" -and
    [string]$actions[0].input -ceq
        "controlled in-process SetExpanded on the current rebound card") (
    "Controlled recycled-card expansion evidence drifted.")

Assert (
    [int]$gui.fixture.folderCount -eq 9184 -and
    [int]$gui.fixture.chartCount -eq 9184 -and
    [long]$gui.fixture.payloadBytes -eq 1469440 -and
    [string]$gui.fixture.manifestSha256 -ceq
        "57AD627CD974B25B8DCC9FC0996AF13C40749B315AB2C535EF73504520754064" -and
    -not [bool]$gui.fixture.retainedInArtifacts) (
    "The isolated 9,184-chart fixture evidence drifted.")

$runtimeEvidence = File-Evidence $runtimePath
Assert (
    [IO.Path]::GetFullPath([string]$gui.runtime.path) -ceq
        [IO.Path]::GetFullPath($runtimePath) -and
    [long]$gui.runtime.bytes -eq $runtimeEvidence.bytes -and
    [string]$gui.runtime.sha256 -ceq $runtimeEvidence.sha256) (
    "Runtime evidence path, length or hash drifted.")
Assert (
    [string]$runtime.schema -ceq
        "lumachart.windows.avalonia.library-virtualization-runtime.v1" -and
    [string]$runtime.status -ceq "captured-migration-incomplete" -and
    [string]$runtime.platform -ceq "Windows Avalonia only") (
    "Library virtualization runtime evidence boundary drifted.")
Assert (
    [int]$runtime.indexedChartCount -eq 9184 -and
    [int]$runtime.indexedFolderCount -eq 9184 -and
    [int]$runtime.visibleFolderCount -eq 9184 -and
    [double]$runtime.initializationMilliseconds -le 5000) (
    "Large-library indexing count or initialization threshold drifted.")
Assert (
    [bool]$runtime.containerTemplateOwnsStableCard -and
    -not [bool]$runtime.funcDataTemplateUsed -and
    [string]$runtime.itemsPanelType -ceq
        "Avalonia.Controls.VirtualizingStackPanel" -and
    [int]$runtime.scrollSampleCount -eq 180 -and
    [int]$runtime.maximumRealizedContainerCount -le 64 -and
    [int]$runtime.uniqueListBoxItemInstances -le 96 -and
    [int]$runtime.uniqueCardInstances -le 96 -and
    [int]$runtime.staleBindingMismatchCount -eq 0 -and
    [int]$runtime.maximumMaterializedCollapsedChartRows -eq 0) (
    "Stable recyclable-card or lazy-row materialization contract drifted.")
Assert (
    [string]$runtime.evidenceExpandedDisplayTitle -ceq
        "Virtual Chart 04589" -and
    [int]$runtime.evidenceExpandedChartRowCount -eq 1 -and
    [bool]$runtime.evidenceExpandedBindingMatched -and
    [string]$runtime.evidenceExpandedChartPath -clike
        "*\Song-04589\chart-04589.mc") (
    "Expansion state did not survive card recycling with the correct chart.")
Assert (
    [int]$runtime.scrollSettleMilliseconds.samples -eq 180 -and
    [double]$runtime.scrollSettleMilliseconds.p95 -le 50 -and
    [double]$runtime.scrollSettleMilliseconds.p99 -le 100 -and
    [int]$runtime.inputQueueDelayMilliseconds.samples -eq 180 -and
    [double]$runtime.inputQueueDelayMilliseconds.p95 -le 25 -and
    [double]$runtime.inputQueueDelayMilliseconds.p99 -le 50) (
    "Scroll-settle or input-queue latency exceeded the slice threshold.")
Assert (
    [long]$runtime.memory.managedBytesAfter -le 268435456 -and
    [long]$runtime.memory.workingSetBytesAfter -le 1073741824) (
    "Large-library memory exceeded the slice threshold.")
Assert (
    -not (Test-Path -LiteralPath ([string]$runtime.workspaceRoot))) (
    "The generated 9,184-chart fixture was retained after GUI verification.")

Assert (
    [bool]$gui.guiRebind.currentBindingMatched -and
    [string]$gui.guiRebind.expandedFolderName -ceq
        "Virtual Chart 04589" -and
    [string]$gui.guiRebind.materializedChartActionName -ceq
        "打开编辑 · Virtual Chart 04589  [Stress] · Song-04589\chart-04589.mc") (
    "Visible GUI binding or current chart action drifted.")

$screenshotPath = [IO.Path]::GetFullPath([string]$gui.screenshot.path)
Assert (
    $screenshotPath.StartsWith(
        $formalRoot.TrimEnd('\') + '\',
        [StringComparison]::OrdinalIgnoreCase)) (
    "Library virtualization screenshot escaped the formal root.")
$screenshotEvidence = File-Evidence $screenshotPath
Assert (
    $screenshotEvidence.sha256 -ceq [string]$gui.screenshot.sha256 -and
    $screenshotEvidence.bytes -eq [long]$gui.screenshot.bytes -and
    [int]$gui.screenshot.width -eq 2560 -and
    [int]$gui.screenshot.height -eq 1528 -and
    [string]$gui.screenshot.captureKind -ceq "physical desktop window") (
    "Screenshot hash, dimensions or capture kind drifted.")

$checks = @($avaloniaSpecs.checks)
Assert (
    [string]$avaloniaSpecs.schema -ceq
        "lumachart.windows.avalonia.slice-specs.v2" -and
    [string]$avaloniaSpecs.status -ceq "passed" -and
    $checks.Count -eq 495 -and
    @($checks | Where-Object { -not $_.passed }).Count -eq 0) (
    "Avalonia Specs are not 495/495.")
$dedicatedSpecs = @(
    "windows-library-card-expansion-folder-scoped",
    "windows-library-card-rebind-clears-stale-rows",
    "windows-library-card-rebound-action-current-chart")
foreach ($name in $dedicatedSpecs) {
    $matches = @($checks | Where-Object { $_.name -ceq $name })
    Assert (
        $matches.Count -eq 1 -and [bool]$matches[0].passed) (
        "Dedicated recyclable-card spec missing or failed: $name")
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

$captureScriptPath =
    Join-Path $projectRoot "tools\Capture-WindowsAvaloniaLibraryVirtualizationGui.ps1"
$captureScriptText =
    Get-Content -LiteralPath $captureScriptPath -Raw -Encoding UTF8
foreach ($forbidden in @(
        "mouse_event",
        "PostMessage",
        "SetCursorPos",
        "SendInput",
        "keybd_event",
        "HWND_TOPMOST",
        "SetWindowPos",
        "SendKeys",
        "{ENTER}")) {
    Assert (
        -not $captureScriptText.Contains(
            $forbidden,
            [StringComparison]::OrdinalIgnoreCase)) (
        "GUI capture script contains forbidden input/topmost API '$forbidden'.")
}

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
    "tools\Capture-WindowsAvaloniaLibraryVirtualizationGui.ps1",
    "tools\New-WindowsAvaloniaLibraryVirtualizationSliceEvidence.ps1")
$sourceEvidence = @(
    $sourceFiles |
    ForEach-Object { File-Evidence (Join-Path $projectRoot $_) })

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.library-virtualization-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    platform = "Windows Avalonia only"
    buildMode = "ordinary .NET Release"
    formalRoot = $formalRoot
    results = [ordered]@{
        avaloniaStrictBuildWarnings = 0
        avaloniaStrictBuildErrors = 0
        avaloniaSpecsStrictBuildWarnings = 0
        avaloniaSpecsStrictBuildErrors = 0
        mainSpecsStrictBuildWarnings = 0
        mainSpecsStrictBuildErrors = 0
        onlineGuiServerStrictBuildWarnings = 0
        onlineGuiServerStrictBuildErrors = 0
        avaloniaSpecsPassed = 495
        avaloniaSpecsTotal = 495
        mainSpecsPassed = 79
        mainSpecsTotal = 79
        indexedFolders = 9184
        indexedCharts = 9184
        initializationMilliseconds = [double]$runtime.initializationMilliseconds
        scrollSamples = 180
        realizedContainersMaximum = [int]$runtime.maximumRealizedContainerCount
        uniqueListBoxItems = [int]$runtime.uniqueListBoxItemInstances
        uniqueLibraryCards = [int]$runtime.uniqueCardInstances
        staleBindingMismatches = 0
        materializedCollapsedRowsMaximum = 0
        expandedStateSurvivedRecycling = $true
        scrollSettleP50Milliseconds =
            [double]$runtime.scrollSettleMilliseconds.p50
        scrollSettleP95Milliseconds =
            [double]$runtime.scrollSettleMilliseconds.p95
        scrollSettleP99Milliseconds =
            [double]$runtime.scrollSettleMilliseconds.p99
        inputQueueP50Milliseconds =
            [double]$runtime.inputQueueDelayMilliseconds.p50
        inputQueueP95Milliseconds =
            [double]$runtime.inputQueueDelayMilliseconds.p95
        inputQueueP99Milliseconds =
            [double]$runtime.inputQueueDelayMilliseconds.p99
        renderScaling = [double]$runtime.renderScaling
        reportedRefreshRate = [int]$gui.display.reportedRefreshRate
        physicalInputClaimed = $false
        win32InputInjectionUsed = $false
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
    immutable = [ordered]@{
        realMc = $realMc
        frozenWpfInstaller = $installer
    }
    files = [ordered]@{
        guiEvidence = File-Evidence $guiPath
        runtimeEvidence = $runtimeEvidence
        screenshot = $screenshotEvidence
        avaloniaSpecsEvidence = File-Evidence $avaloniaSpecsPath
        avaloniaSpecsRun = File-Evidence $avaloniaSpecsLogPath
        mainSpecsRun = File-Evidence $mainSpecsLogPath
        builds = $builds
        sourceAndTools = $sourceEvidence
    }
    residuals = @(
        "The expansion proof used the controlled in-process card API because external UIA Invoke did not activate the container-template button.",
        "The physical 120 Hz, true 4K and same-machine WPF/Avalonia A/B gates remain open.",
        "The complete 214-row matrix, remaining online/format/security/installer gates and user replacement approval remain open.")
}

$outputPath = Join-Path $formalRoot "verification-evidence.json"
$verification | ConvertTo-Json -Depth 14 |
    Set-Content -LiteralPath $outputPath -Encoding utf8NoBOM
$verification | ConvertTo-Json -Depth 14
