param(
    [string]$FormalRoot = (
        Join-Path $PSScriptRoot `
            "..\artifacts\windows-avalonia-library-placeholder-slice-20260728-r1"),
    [string]$ChartActionsDirectoryName = "library-actions"
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
$avaloniaSpecsPath =
    Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$avaloniaSpecsLogPath =
    Join-Path $formalRoot "tests\avalonia-specs.log"
$mainSpecsLogPath = Join-Path $formalRoot "tests\main-specs.log"

$chartActions = Read-Json $chartActionsPath
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

$focusedScreenshot = New-FocusedScreenshot `
    -SourcePath (
        Join-Path $chartActionsRoot "open-chart-context-menu.png") `
    -DestinationPath (
        Join-Path $formalRoot `
            "visual-focus\library-placeholder-actions-focus.png") `
    -Crop ([Drawing.Rectangle]::new(0, 0, 2560, 1000)) `
    -Purpose (
        "WPF-aligned 160x90 empty-cover frame, mountain and sun geometry " +
        "on both real-MC folder cards; bottom desktop overlay excluded")

$checks = @($avaloniaSpecs.checks)
Assert (
    [string]$avaloniaSpecs.schema -ceq
        "lumachart.windows.avalonia.slice-specs.v2" -and
    [string]$avaloniaSpecs.status -ceq "passed" -and
    $checks.Count -eq 498 -and
    @($checks | Where-Object { -not $_.passed }).Count -eq 0) (
    "Avalonia Specs are not 498/498.")
$dedicatedSpecs = @(
    "windows-library-card-expansion-folder-scoped",
    "windows-library-card-rebind-clears-stale-rows",
    "windows-library-card-rebound-action-current-chart",
    "windows-library-card-expand-action-current-state",
    "windows-library-card-wpf-geometry",
    "windows-library-thumbnail-placeholder-wpf-geometry")
foreach ($name in $dedicatedSpecs) {
    $matches = @($checks | Where-Object { $_.name -ceq $name })
    Assert (
        $matches.Count -eq 1 -and [bool]$matches[0].passed) (
        "Dedicated library-card spec missing or failed: $name")
}
$placeholderCheck = @(
    $checks |
    Where-Object {
        $_.name -ceq
            "windows-library-thumbnail-placeholder-wpf-geometry"
    })[0]
Assert (
    [string]$placeholderCheck.detail -clike
        "*160x90*frame=56,24,48,35*stroke=2*" -and
    [string]$placeholderCheck.detail -clike
        "*sun=91.5,32.5,r3.5*#191D20/#4D5B60*" -and
    [string]$placeholderCheck.detail -clike
        "*visible=True*imageNull=True*") (
    "Dedicated placeholder geometry detail drifted.")

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

$captureScriptPath = Join-Path $projectRoot `
    "tools\Capture-WindowsAvaloniaLibraryChartActionsGui.ps1"
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
    "LumaChart.Avalonia\Controls\LibraryThumbnailPlaceholderSurface.cs",
    "LumaChart.Avalonia\Controls\LibraryFolderCard.cs",
    "LumaChart.Avalonia.Specs\WindowsLibraryFolderCardSpecs.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "tools\Capture-WindowsAvaloniaLibraryChartActionsGui.ps1",
    "tools\New-WindowsAvaloniaLibraryPlaceholderSliceEvidence.ps1")
$sourceEvidence = @(
    $sourceFiles |
    ForEach-Object { File-Evidence (Join-Path $projectRoot $_) })

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.library-placeholder-slice-verification.v1"
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
        avaloniaSpecsPassed = 498
        avaloniaSpecsTotal = 498
        mainSpecsPassed = 79
        mainSpecsTotal = 79
        dedicatedLibraryCardSpecsPassed = $dedicatedSpecs.Count
        placeholderWidthDips = 160
        placeholderHeightDips = 90
        placeholderFrameX = 56
        placeholderFrameY = 24
        placeholderFrameWidth = 48
        placeholderFrameHeight = 35
        placeholderStrokeDips = 2
        placeholderSunCenterX = 91.5
        placeholderSunCenterY = 32.5
        placeholderSunRadius = 3.5
        placeholderBackground = "#191D20"
        placeholderForeground = "#4D5B60"
        realMcFolderExpandUiaInvokeCount = 2
        realMcOpenChartDeletionBlocked = $true
        realMcTargetMovedToRecycleBin = $true
        isolatedTargetRestoredForCleanup = $true
        enterKeySent = $false
        persistentTopmostUsed = $false
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
        focusedScreenshot = $focusedScreenshot
        sourcePhysicalCapturesRetained = $true
        focusCropReason =
            "A persistent external QQ desktop notification was present in " +
            "the source physical capture; the focus crop excludes only that " +
            "bottom desktop-overlay region and preserves the hash-verified source."
    }
    immutable = [ordered]@{
        realMc = $realMc
        frozenWpfInstaller = $installer
    }
    files = [ordered]@{
        chartActionsEvidence = File-Evidence $chartActionsPath
        chartActionScreenshots = $chartActionScreenshots
        avaloniaSpecsEvidence = File-Evidence $avaloniaSpecsPath
        avaloniaSpecsRun = File-Evidence $avaloniaSpecsLogPath
        mainSpecsRun = File-Evidence $mainSpecsLogPath
        builds = $builds
        sourceAndTools = $sourceEvidence
    }
    residuals = @(
        "The source physical screenshot contains a persistent external QQ desktop notification; the hash-verified focus crop excludes only that bottom notification region.",
        "Actual image-cover rendering and a broader populated-library visual matrix remain open.",
        "A physical mouse card-action run and same-machine WPF/Avalonia visual A/B remain open.",
        "The physical 120 Hz, true 4K and same-machine WPF/Avalonia performance A/B gates remain open.",
        "The complete 214-row matrix, remaining UI/shortcut/online/format/security/installer gates and user replacement approval remain open.")
}

$outputPath = Join-Path $formalRoot "verification-evidence.json"
$verification | ConvertTo-Json -Depth 16 |
    Set-Content -LiteralPath $outputPath -Encoding utf8NoBOM
$verification | ConvertTo-Json -Depth 16
