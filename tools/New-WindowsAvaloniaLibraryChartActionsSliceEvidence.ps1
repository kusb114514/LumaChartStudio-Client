param(
    [string]$FormalRoot = (
        Join-Path $PSScriptRoot `
            "..\artifacts\windows-avalonia-library-chart-actions-slice-20260728-r1")
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
    Assert (
        -not $text.Contains(
            "System.Collections.Hashtable.Artifact",
            [StringComparison]::Ordinal)) (
        "Strict build used the invalid hashtable artifact path: $Path")
    foreach ($forbidden in @(
            "OLLVM",
            "Obfuscator",
            "NativeAOT",
            "PublishAot=true",
            "code virtualization")) {
        Assert (
            -not $text.Contains(
                $forbidden,
                [StringComparison]::OrdinalIgnoreCase)) (
            "Strict build contains forbidden protection/AOT text '$forbidden': $Path")
    }
    return File-Evidence $Path
}

function Assert-VisibleElement(
    [object]$Element,
    [string]$AutomationId,
    [string]$Name) {
    Assert (
        [string]$Element.automationId -ceq $AutomationId -and
        [string]$Element.name -ceq $Name -and
        [bool]$Element.isEnabled -and
        -not [bool]$Element.isOffscreen -and
        [double]$Element.bounds.left -ge 0 -and
        [double]$Element.bounds.top -ge 0 -and
        [double]$Element.bounds.width -gt 0 -and
        [double]$Element.bounds.height -gt 0) (
        "Visible UI Automation element drifted: $AutomationId / $Name")
}

$guiPath = Join-Path $formalRoot "library-chart-actions-gui\evidence.json"
$avaloniaSpecsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$mainSpecsLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$gui = Read-Json $guiPath
$avaloniaSpecs = Read-Json $avaloniaSpecsPath

Assert (
    $gui.schema -ceq
        "lumachart.windows.avalonia.library-chart-actions-gui.v1" -and
    $gui.status -ceq "passed-migration-incomplete" -and
    $gui.platform -ceq "Windows Avalonia only") (
    "Library chart-action GUI evidence boundary drifted.")

$realMcSha256 =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$installerSha256 =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
Assert (
    [string]$gui.immutable.realMcBefore.sha256 -ceq $realMcSha256 -and
    [string]$gui.immutable.realMcAfter.sha256 -ceq $realMcSha256 -and
    [long]$gui.immutable.realMcBefore.bytes -eq
        [long]$gui.immutable.realMcAfter.bytes) (
    "Real MC fixture changed.")
Assert (
    [string]$gui.immutable.frozenInstallerBefore.sha256 -ceq
        $installerSha256 -and
    [string]$gui.immutable.frozenInstallerAfter.sha256 -ceq
        $installerSha256 -and
    [long]$gui.immutable.frozenInstallerBefore.bytes -eq
        [long]$gui.immutable.frozenInstallerAfter.bytes) (
    "Frozen WPF installer changed.")
Assert (
    [string]$gui.immutable.openChartBefore.sha256 -ceq $realMcSha256 -and
    [string]$gui.immutable.openChartAfter.sha256 -ceq $realMcSha256) (
    "Open chart changed during blocked deletion verification.")

$actions = @($gui.inputs.actions)
Assert (
    [bool]$gui.inputs.currentTurnDesktopConsent -and
    [int]$gui.inputs.minimumIdleMilliseconds -ge 3000 -and
    -not [bool]$gui.inputs.win32MouseInputInjectionUsed -and
    [bool]$gui.inputs.postedTargetPointerMessagesUsed -and
    [bool]$gui.inputs.uiaInvokeUsed -and
    -not [bool]$gui.inputs.hardwareMouseInputClaimed -and
    -not [bool]$gui.inputs.hardwareKeyboardInputClaimed -and
    -not [bool]$gui.inputs.enterKeySent -and
    [bool]$gui.inputs.uiaWindowCloseUsed -and
    -not [bool]$gui.inputs.persistentTopmostUsed -and
    $actions.Count -eq 8) (
    "GUI input or action-count contract drifted.")
Assert (
    [int]$gui.process.exitCode -eq 0 -and
    -not [bool]$gui.process.topmostAtStart -and
    -not [bool]$gui.process.topmostBeforeClose) (
    "GUI process exit or topmost evidence drifted.")

$chartActions = $gui.chartActions
Assert (
    [bool]$chartActions.openChartDeletionBlocked -and
    [bool]$chartActions.targetChartMissingAfterUiRecycle -and
    [bool]$chartActions.targetRowAbsentAfterUiRefresh -and
    [bool]$chartActions.deleteFolderPreserved -and
    [bool]$chartActions.audioSiblingPreserved -and
    [bool]$chartActions.imageSiblingPreserved -and
    [int]$chartActions.recycleBinCountAfter -eq
        [int]$chartActions.recycleBinCountBefore + 1 -and
    [bool]$chartActions.recycleBinUniqueTargetObserved -and
    [bool]$chartActions.restoreAttempted -and
    [bool]$chartActions.restoredForCleanup) (
    "Single-chart recycle, shared-resource or cleanup evidence drifted.")
Assert (
    [string]$chartActions.blocked.message.name -ceq
        "这张谱面正在编辑。请先关闭对应谱面标签，再执行删除。") (
    "Open-chart block copy drifted from WPF 1.1.0.")
$confirmation = [string]$chartActions.confirmation.message.name
Assert (
    $confirmation.StartsWith(
        "确定将这张谱面移入回收站吗？",
        [StringComparison]::Ordinal) -and
    $confirmation.Contains(
        "只移除谱面文件，不影响同目录的共用音频和图片。",
        [StringComparison]::Ordinal)) (
    "Single-chart confirmation copy drifted from WPF 1.1.0.")
foreach ($menu in @(
        $chartActions.blocked.menu,
        $chartActions.confirmation.menu)) {
    Assert-VisibleElement `
        $menu.reveal `
        "Library.ChartReveal" `
        "在文件资源管理器中打开"
    Assert-VisibleElement `
        $menu.delete `
        "Library.ChartDelete" `
        "删除此谱面"
}

$screenshots = @($gui.screenshots)
Assert ($screenshots.Count -eq 5) "Expected exactly five GUI screenshots."
$screenshotEvidence = [Collections.Generic.List[object]]::new()
foreach ($screenshot in $screenshots) {
    $path = [IO.Path]::GetFullPath([string]$screenshot.path)
    Assert (
        $path.StartsWith(
            $formalRoot.TrimEnd('\') + '\',
            [StringComparison]::OrdinalIgnoreCase)) (
        "Screenshot escaped the formal root: $path")
    $file = File-Evidence $path
    Assert (
        $file.sha256 -ceq [string]$screenshot.sha256 -and
        $file.bytes -eq [long]$screenshot.bytes -and
        [int]$screenshot.width -eq 2560 -and
        [int]$screenshot.height -eq 1528 -and
        [string]$screenshot.captureKind -ceq
            "physical desktop window including popup/owner") (
        "Screenshot hash, length, dimensions or capture kind drifted: $path")
    [void]$screenshotEvidence.Add($file)
}

$checks = @($avaloniaSpecs.checks)
Assert (
    $avaloniaSpecs.schema -ceq "lumachart.windows.avalonia.slice-specs.v2" -and
    $avaloniaSpecs.status -ceq "passed" -and
    $checks.Count -eq 487 -and
    @($checks | Where-Object { -not $_.passed }).Count -eq 0) (
    "Avalonia Specs are not 487/487.")
$dedicatedSpecNames = @(
    "desktop-library-chart-deletion-invalid-or-outside-path-fails-closed",
    "desktop-library-chart-deletion-matches-wpf-single-file-confirmation",
    "desktop-library-chart-deletion-blocks-the-exact-open-chart")
foreach ($name in $dedicatedSpecNames) {
    $matches = @($checks | Where-Object { $_.name -ceq $name })
    Assert (
        $matches.Count -eq 1 -and [bool]$matches[0].passed) (
        "Dedicated library chart-deletion spec missing or failed: $name")
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
        Join-Path $formalRoot "builds\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "builds\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "builds\main-specs-build.log")
    onlineGuiServer = Assert-StrictBuild (
        Join-Path $formalRoot "builds\online-gui-server-build.log")
}

Assert (
    -not [bool]$gui.boundaries.productionServerDeployed -and
    -not [bool]$gui.boundaries.mobileProjectsTouched -and
    -not [bool]$gui.boundaries.protectionOrAotUsed -and
    -not [bool]$gui.boundaries.releaseInstallerOverwritten -and
    -not [bool]$gui.boundaries.windowsAvaloniaCanReplaceWpf -and
    -not [bool]$gui.boundaries.userManualReplacementApprovalReceived) (
    "Platform, release or completion boundary drifted.")

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.library-chart-actions-slice-verification.v1"
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
        avaloniaSpecsPassed = 487
        avaloniaSpecsTotal = 487
        mainSpecsPassed = 79
        mainSpecsTotal = 79
        guiBusinessActions = 8
        openChartDeletionBlocked = $true
        targetChartRecycled = $true
        targetRowAbsentAfterUiRefresh = $true
        songFolderPreserved = $true
        sharedAudioPreserved = $true
        sharedImagePreserved = $true
        recycledTestChartRestoredForCleanup = $true
        physicalInputClaimed = $false
        enterKeySent = $false
        persistentTopmostUsed = $false
        realChartUnchanged = $true
        frozenInstallerUnchanged = $true
        productionServerDeployed = $false
        mobileProjectsTouched = $false
        protectionOrAotUsed = $false
        windowsAvaloniaCanReplaceWpf = $false
    }
    files = [ordered]@{
        guiEvidence = File-Evidence $guiPath
        screenshots = @($screenshotEvidence)
        avaloniaSpecsEvidence = File-Evidence $avaloniaSpecsPath
        avaloniaSpecsRun = File-Evidence (
            Join-Path $formalRoot "tests\avalonia-specs-run.log")
        mainSpecsRun = File-Evidence $mainSpecsLogPath
        guiRun = File-Evidence (
            Join-Path $formalRoot "tests\library-chart-actions-gui-run.log")
        builds = $builds
    }
}

$outputPath = Join-Path $formalRoot "verification-evidence.json"
$verification | ConvertTo-Json -Depth 12 |
    Set-Content -LiteralPath $outputPath -Encoding utf8NoBOM
$verification | ConvertTo-Json -Depth 12
