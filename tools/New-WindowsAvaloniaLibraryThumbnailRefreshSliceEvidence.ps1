param(
    [string]$FormalRoot = (
        Join-Path $PSScriptRoot `
            "..\artifacts\windows-avalonia-library-thumbnail-refresh-slice-20260728-r1"),
    [string]$GuiDirectoryName = "thumbnail-refresh",
    [string]$ExpectedDisplayTitle = "Resound",
    [string]$ExpectedCoverPath =
        "D:\osu!\Songs\Resound\0\Resound - Nhato.jpg",
    [long]$ExpectedCoverBytes = 918570,
    [string]$ExpectedCoverSha256 =
        "3A1D4D064756C3B23C91217B3909AD5181FEB0A3700BE9D74348C57283B43760",
    [string]$ExpectedChartPath =
        "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$ExpectedChartSha256 =
        "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E",
    [ValidateRange(1, 10000)][int]$ExpectedAvaloniaSpecs = 499,
    [string]$AdditionalDedicatedSpec = "",
    [string]$VerificationSchema =
        "lumachart.windows.avalonia.library-thumbnail-refresh-slice-verification.v1",
    [string]$CoverDescription = "Real Resound JPG",
    [string]$FormatResidual =
        "This slice uses a real JPEG cover and an explicit corrupt-file transition; PNG and other decoder formats, an osu background path and concurrent file replacement remain open."
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
        [Parameter(Mandatory = $true)][string]$Purpose
    )
    $crop = [Drawing.Rectangle]::new(0, 0, 1800, 700)
    $source = [Drawing.Bitmap]::new($SourcePath)
    try {
        Assert (
            $crop.Right -le $source.Width -and
            $crop.Bottom -le $source.Height) (
            "Focused screenshot crop exceeds source bounds: $SourcePath")
        [IO.Directory]::CreateDirectory(
            [IO.Path]::GetDirectoryName($DestinationPath)) | Out-Null
        $focused = [Drawing.Bitmap]::new(
            $crop.Width,
            $crop.Height,
            [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $graphics = [Drawing.Graphics]::FromImage($focused)
            try {
                $graphics.DrawImage(
                    $source,
                    [Drawing.Rectangle]::new(
                        0,
                        0,
                        $crop.Width,
                        $crop.Height),
                    $crop,
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
        x = 0
        y = 0
        width = 1800
        height = 700
    }
    $evidence["purpose"] = $Purpose
    $evidence["captureKind"] =
        "derived focus crop from hash-verified physical desktop capture"
    return $evidence
}

$guiRoot = Join-Path $formalRoot "gui\$GuiDirectoryName"
$guiPath = Join-Path $guiRoot "evidence.json"
$avaloniaSpecsPath =
    Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$avaloniaSpecsLogPath =
    Join-Path $formalRoot "tests\avalonia-specs.log"
$mainSpecsLogPath = Join-Path $formalRoot "tests\main-specs.log"

$gui = Read-Json $guiPath
$avaloniaSpecs = Read-Json $avaloniaSpecsPath

Assert (
    [string]$gui.schema -ceq
        "lumachart.windows.avalonia.library-thumbnail-refresh-gui.v1" -and
    [string]$gui.status -ceq "passed-migration-incomplete" -and
    [string]$gui.platform -ceq "Windows Avalonia only") (
    "Library thumbnail GUI boundary drifted.")
Assert (
    [int]$gui.process.exitCode -eq 0 -and
    -not [bool]$gui.process.topmostAtStart -and
    -not [bool]$gui.process.topmostBeforeClose) (
    "Library thumbnail process exit or non-topmost evidence drifted.")
Assert (
    [bool]$gui.inputs.currentTurnDesktopConsent -and
    [long]$gui.inputs.minimumIdleMilliseconds -ge 3000 -and
    [long]$gui.inputs.initialIdleMilliseconds -ge 3000 -and
    [bool]$gui.inputs.uiaInvokeUsed -and
    -not [bool]$gui.inputs.postedTargetPointerMessagesUsed -and
    [bool]$gui.inputs.uiaWindowCloseUsed -and
    -not [bool]$gui.inputs.win32MouseInputInjectionUsed -and
    -not [bool]$gui.inputs.win32KeyboardInputInjectionUsed -and
    -not [bool]$gui.inputs.hardwareMouseInputClaimed -and
    -not [bool]$gui.inputs.hardwareKeyboardInputClaimed -and
    -not [bool]$gui.inputs.enterKeySent -and
    -not [bool]$gui.inputs.persistentTopmostUsed) (
    "Thumbnail consent, input provenance or topmost evidence drifted.")
$actions = @($gui.inputs.actions)
Assert (
    $actions.Count -eq 2 -and
    @($actions | Where-Object {
        [string]$_.automationId -ceq "Library.Refresh" -and
        [string]$_.name -ceq "刷新索引" -and
        [string]$_.input -ceq "UI Automation InvokePattern"
    }).Count -eq 2) (
    "Expected exactly two UIA Refresh invocations.")

$thumbnail = $gui.thumbnail
Assert (
    [bool]$thumbnail.validToCorruptToValid -and
    [int]$thumbnail.refreshInvokeCount -eq 2) (
    "Valid/corrupt/restored thumbnail state chain drifted.")
Assert (
    [string]$thumbnail.initial.automationId -ceq
        "Library.FolderThumbnailImage" -and
    [string]$thumbnail.initial.name -ceq
        "封面 · $ExpectedDisplayTitle" -and
    [string]$thumbnail.initial.controlType -ceq "ControlType.Image" -and
    -not [bool]$thumbnail.initial.isOffscreen -and
    [string]$thumbnail.corruptFallback.automationId -ceq
        "Library.FolderThumbnailPlaceholder" -and
    [string]$thumbnail.corruptFallback.name -ceq "无封面占位图" -and
    [string]$thumbnail.corruptFallback.controlType -ceq
        "ControlType.Custom" -and
    -not [bool]$thumbnail.corruptFallback.isOffscreen -and
    [string]$thumbnail.restored.automationId -ceq
        "Library.FolderThumbnailImage" -and
    [string]$thumbnail.restored.name -ceq
        "封面 · $ExpectedDisplayTitle" -and
    [string]$thumbnail.restored.controlType -ceq "ControlType.Image" -and
    -not [bool]$thumbnail.restored.isOffscreen) (
    "Thumbnail UI Automation states drifted.")
foreach ($observation in @(
        $thumbnail.initial,
        $thumbnail.corruptFallback,
        $thumbnail.restored)) {
    Assert (
        [double]$observation.bounds.left -eq 86 -and
        [double]$observation.bounds.top -eq 308 -and
        [double]$observation.bounds.width -eq 240 -and
        [double]$observation.bounds.height -eq 135) (
        "Thumbnail physical bounds drifted from 160x90 DIP at 150%.")
}

$realCoverHash = $ExpectedCoverSha256.ToUpperInvariant()
$corruptHash =
    "00389EF0DCF9592E2ACB823A001ED62AF887D4813305B75CCFDAEB2B5796F828"
Assert (
    [long]$thumbnail.sourceFingerprint.bytes -eq
        $ExpectedCoverBytes -and
    [string]$thumbnail.sourceFingerprint.sha256 -ceq $realCoverHash -and
    [string]$thumbnail.isolatedInitialFingerprint.sha256 -ceq
        $realCoverHash -and
    [long]$thumbnail.corruptFingerprint.bytes -eq 8 -and
    [string]$thumbnail.corruptFingerprint.sha256 -ceq $corruptHash -and
    [string]$thumbnail.restoredFingerprint.sha256 -ceq $realCoverHash -and
    [string]$thumbnail.isolatedFinalFingerprint.sha256 -ceq
        $realCoverHash) (
    "Real, corrupt or restored cover fingerprint chain drifted.")

$screenshots = @()
foreach ($screenshot in @($gui.screenshots)) {
    $path = Assert-BelowFormalRoot (
        [string]$screenshot.path) "Thumbnail screenshot"
    $file = File-Evidence $path
    Assert (
        $file.sha256 -ceq [string]$screenshot.sha256 -and
        $file.bytes -eq [long]$screenshot.bytes -and
        [int]$screenshot.width -eq 2560 -and
        [int]$screenshot.height -eq 1528 -and
        [string]$screenshot.captureKind -ceq
            "physical desktop window") (
        "Thumbnail screenshot hash, dimensions or provenance drifted.")
    $screenshots += $file
}
Assert ($screenshots.Count -eq 3) (
    "Expected three thumbnail screenshots.")

$focusedRoot = Join-Path $formalRoot "visual-focus"
$focusedScreenshots = @(
    (New-FocusedScreenshot `
        -SourcePath (Join-Path $guiRoot "cover-valid.png") `
        -DestinationPath (
            Join-Path $focusedRoot "cover-valid-focus.png") `
        -Purpose (
            "$CoverDescription rendered with WPF UniformToFill card geometry")),
    (New-FocusedScreenshot `
        -SourcePath (
            Join-Path $guiRoot "cover-corrupt-fallback.png") `
        -DestinationPath (
            Join-Path $focusedRoot "cover-corrupt-fallback-focus.png") `
        -Purpose (
            "Same-path corrupt cover fell back to the WPF placeholder")),
    (New-FocusedScreenshot `
        -SourcePath (Join-Path $guiRoot "cover-restored.png") `
        -DestinationPath (
            Join-Path $focusedRoot "cover-restored-focus.png") `
        -Purpose (
            "Same-path restored $CoverDescription rendered again after refresh")))

$checks = @($avaloniaSpecs.checks)
Assert (
    [string]$avaloniaSpecs.schema -ceq
        "lumachart.windows.avalonia.slice-specs.v2" -and
    [string]$avaloniaSpecs.status -ceq "passed" -and
    $checks.Count -eq $ExpectedAvaloniaSpecs -and
    @($checks | Where-Object { -not $_.passed }).Count -eq 0) (
    "Avalonia Specs are not $ExpectedAvaloniaSpecs/$ExpectedAvaloniaSpecs.")
$dedicatedSpecs = @(
    "windows-library-card-expansion-folder-scoped",
    "windows-library-card-rebind-clears-stale-rows",
    "windows-library-card-rebound-action-current-chart",
    "windows-library-card-expand-action-current-state",
    "windows-library-card-wpf-geometry",
    "windows-library-thumbnail-placeholder-wpf-geometry",
    "windows-library-thumbnail-refresh-and-failure-fallback")
if (-not [string]::IsNullOrWhiteSpace($AdditionalDedicatedSpec)) {
    $dedicatedSpecs += $AdditionalDedicatedSpec
}
foreach ($name in $dedicatedSpecs) {
    $matches = @($checks | Where-Object { $_.name -ceq $name })
    Assert (
        $matches.Count -eq 1 -and [bool]$matches[0].passed) (
        "Dedicated library-thumbnail spec missing or failed: $name")
}
$refreshSpec = @(
    $checks |
    Where-Object {
        $_.name -ceq
            "windows-library-thumbnail-refresh-and-failure-fallback"
    })[0]
Assert (
    [string]$refreshSpec.detail -ceq
        "fallback→image→fallback=True/True/True; loaderCalls=3; " +
        "samePath=True; cacheBound=512") (
    "Thumbnail refresh spec detail drifted.")

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
    "tools\Capture-WindowsAvaloniaLibraryThumbnailRefreshGui.ps1"
$captureScriptText =
    Get-Content -LiteralPath $captureScriptPath -Raw -Encoding UTF8
foreach ($forbidden in @(
        "HWND_TOPMOST",
        "SetWindowPos",
        "SendKeys",
        "{ENTER}",
        "keybd_event",
        "mouse_event",
        "SetCursorPos")) {
    Assert (
        -not $captureScriptText.Contains(
            $forbidden,
            [StringComparison]::OrdinalIgnoreCase)) (
        "GUI capture script contains forbidden API '$forbidden'.")
}

$wpfBaseline = File-Evidence (
    Join-Path $projectRoot `
        "artifacts\final-audit-20260721\wpf-gui-populated-library.png")
$realChart = File-Evidence $ExpectedChartPath
$realCover = File-Evidence $ExpectedCoverPath
$installer = File-Evidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert (
    $realChart.sha256 -ceq $ExpectedChartSha256.ToUpperInvariant()) (
    "Frozen real chart fixture changed.")
Assert ($realCover.sha256 -ceq $realCoverHash) (
    "Frozen real cover fixture changed.")
Assert (
    $installer.sha256 -ceq
        "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") (
    "Frozen WPF installer changed.")

$sourceFiles = @(
    "LumaChart.Avalonia\Services\AvaloniaLibraryThumbnailCache.cs",
    "LumaChart.Avalonia\Controls\LibraryThumbnailPlaceholderSurface.cs",
    "LumaChart.Avalonia\Controls\LibraryFolderCard.cs",
    "LumaChart.Avalonia.Specs\WindowsLibraryFolderCardSpecs.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "tools\Capture-WindowsAvaloniaLibraryThumbnailRefreshGui.ps1",
    "tools\New-WindowsAvaloniaLibraryThumbnailRefreshSliceEvidence.ps1")
$sourceEvidence = @(
    $sourceFiles |
    ForEach-Object { File-Evidence (Join-Path $projectRoot $_) })

$verification = [ordered]@{
    schema = $VerificationSchema
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    platform = "Windows Avalonia only"
    buildMode = "ordinary .NET Release"
    formalRoot = $formalRoot
    guiDirectoryName = $GuiDirectoryName
    results = [ordered]@{
        avaloniaStrictBuildWarnings = 0
        avaloniaStrictBuildErrors = 0
        avaloniaSpecsStrictBuildWarnings = 0
        avaloniaSpecsStrictBuildErrors = 0
        mainSpecsStrictBuildWarnings = 0
        mainSpecsStrictBuildErrors = 0
        onlineGuiServerStrictBuildWarnings = 0
        onlineGuiServerStrictBuildErrors = 0
        avaloniaSpecsPassed = $ExpectedAvaloniaSpecs
        avaloniaSpecsTotal = $ExpectedAvaloniaSpecs
        mainSpecsPassed = 79
        mainSpecsTotal = 79
        dedicatedLibraryThumbnailSpecsPassed = $dedicatedSpecs.Count
        realCoverBytes = $ExpectedCoverBytes
        realCoverSha256 = $realCoverHash
        decodedWidthPixels = 320
        logicalWidthDips = 160
        logicalHeightDips = 90
        renderScaling = 1.5
        validToCorruptToValid = $true
        refreshUiaInvokeCount = 2
        cacheMaximumRetainedEntries = 512
        placeholderAutomationPeerObserved = $true
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
        focusedScreenshots = $focusedScreenshots
        sourcePhysicalCapturesRetained = $true
        focusCropReason =
            "A persistent external QQ desktop notification was present in " +
            "the source physical captures; the focus crops exclude only that " +
            "bottom-right desktop-overlay region and preserve the hash-verified sources."
    }
    immutable = [ordered]@{
        realChart = $realChart
        realCover = $realCover
        frozenWpfInstaller = $installer
    }
    files = [ordered]@{
        guiEvidence = File-Evidence $guiPath
        screenshots = $screenshots
        avaloniaSpecsEvidence = File-Evidence $avaloniaSpecsPath
        avaloniaSpecsRun = File-Evidence $avaloniaSpecsLogPath
        mainSpecsRun = File-Evidence $mainSpecsLogPath
        builds = $builds
        sourceAndTools = $sourceEvidence
    }
    residuals = @(
        "The source physical screenshots contain a persistent external QQ desktop notification; hash-verified focus crops exclude only that bottom-right notification region.",
        $FormatResidual,
        "The cache is structurally bounded at 512 weak entries, but a large physical library with hundreds of live covers and same-machine WPF memory A/B remain open.",
        "A physical mouse refresh run, multi-DPI image comparison and same-machine WPF/Avalonia pixel A/B remain open.",
        "The complete 214-row matrix, remaining UI/shortcut/online/format/security/installer gates and user replacement approval remain open.")
}

$outputPath = Join-Path $formalRoot "verification-evidence.json"
$verification | ConvertTo-Json -Depth 16 |
    Set-Content -LiteralPath $outputPath -Encoding utf8NoBOM
$verification | ConvertTo-Json -Depth 16
