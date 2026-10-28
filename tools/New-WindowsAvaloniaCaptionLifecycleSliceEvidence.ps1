param(
    [string]$Root =
        "artifacts\windows-avalonia-caption-lifecycle-slice-20260727-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedWindowedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedButtonMaximizedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedButtonRestoredScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedDoubleClickMaximizedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedDoubleClickRestoredScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedDraggedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedDragRestoredScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia caption-lifecycle verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-caption-lifecycle-slice-20260727-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal caption-lifecycle root must be exactly $expectedRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "Missing file: $full"
    $item = Get-Item -LiteralPath $full
    [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $full)
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -Raw -LiteralPath $Path
    Assert ($text -match "(0 个警告|0 Warning\(s\))") (
        "Strict build log lacks zero-warning result: $Path")
    Assert ($text -match "(0 个错误|0 Error\(s\))") (
        "Strict build log lacks zero-error result: $Path")
    Assert ($text -notmatch (
        "(?i)ollvm|obfuscat|virtuali[sz]ation|nativeaot|publish-aot")) (
        "Strict build log contains forbidden protection or AOT markers: $Path")
    File-Evidence $Path
}

function Assert-BoundsEqual(
    [object]$Actual,
    [object]$Expected,
    [string]$Description) {
    foreach ($field in @("left", "top", "right", "bottom", "width", "height")) {
        Assert ([long]$Actual.$field -eq [long]$Expected.$field) (
            "$Description differs at $field.")
    }
}

$expectedScreenshotHashes = [ordered]@{
    "titlebar-windowed" = $ExpectedWindowedScreenshotSha256
    "caption-button-maximized" = $ExpectedButtonMaximizedScreenshotSha256
    "caption-button-restored" = $ExpectedButtonRestoredScreenshotSha256
    "caption-double-click-maximized" =
        $ExpectedDoubleClickMaximizedScreenshotSha256
    "caption-double-click-restored" =
        $ExpectedDoubleClickRestoredScreenshotSha256
    "caption-window-dragged" = $ExpectedDraggedScreenshotSha256
    "caption-window-drag-restored" = $ExpectedDragRestoredScreenshotSha256
}
foreach ($hash in $expectedScreenshotHashes.Values) {
    Assert ($hash -match '^[0-9A-Fa-f]{64}$') "A screenshot SHA-256 is invalid."
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$builds = [ordered]@{
    avalonia = Assert-StrictBuild (Join-Path $formalRoot "build\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\main-specs-build.log")
}

$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs = Get-Content -Raw -LiteralPath $specsPath | ConvertFrom-Json -Depth 100
$checks = @($specs.checks)
$passedChecks = @($checks | Where-Object { $_.passed })
$focusedName = "titlebar-caption-window-state-transitions-are-exact"
$focusedChecks = @($checks | Where-Object { $_.name -ceq $focusedName })
Assert ($specs.status -ceq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 453 -and $passedChecks.Count -eq 453) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
Assert ($focusedChecks.Count -eq 1 -and $focusedChecks[0].passed) (
    "The caption window-state transition Spec did not pass.")

$mainLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainText = Get-Content -Raw -LiteralPath $mainLogPath
Assert ($mainText -match "79/79 specs passed") "Main Specs did not pass 79/79."

$guiPath = Join-Path $formalRoot "gui\titlebar-gui-evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json -Depth 100
Assert ($gui.schema -ceq (
    "lumachart.windows.avalonia.caption-lifecycle-gui-evidence.v1")) (
    "Unexpected GUI schema: $($gui.schema)")
Assert ($gui.status -ceq "passed-migration-incomplete") (
    "GUI evidence status is not passed-migration-incomplete.")
Assert ($gui.windowsAvaloniaOnly -eq $true) "GUI evidence is not Windows-only."
Assert ($gui.productionServerMutationPerformed -eq $false) (
    "GUI evidence mutated production Server.")
Assert ($gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false) (
    "GUI evidence touched mobile projects.")
Assert ($gui.pureDotnetRelease -eq $true) "GUI evidence is not ordinary Release."
Assert ($gui.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "GUI evidence used forbidden protection or AOT.")

$inputEvidence = $gui.currentSliceInput
Assert ($inputEvidence.physicalMouseInputUsed -eq $true -and
    [long]$inputEvidence.physicalActionCount -eq 8 -and
    [long]$inputEvidence.physicalClickCount -eq 4 -and
    [long]$inputEvidence.physicalDoubleClickCount -eq 2 -and
    [long]$inputEvidence.physicalDragCount -eq 2 -and
    $inputEvidence.nativeRestoreAfterMinimizeUsedAsSetup -eq $true -and
    $inputEvidence.keyboardInjectionUsed -eq $false -and
    $inputEvidence.hardwareInputClaimed -eq $false) (
    "Current-slice physical input contract differs from the formal gate.")
Assert ([long]$gui.chrome.titleBarHeight -eq 38 -and
    [long]$gui.chrome.captionButtonWidth -eq 46 -and
    [Math]::Abs([double]$gui.chrome.windowScale - 1.5) -le 0.001 -and
    $gui.chrome.formatBadge -ceq "MALODY" -and
    $gui.chrome.documentTab -like "谱面标签 Resound*") (
    "WPF title-bar metrics or real-chart identity changed.")

$caption = $gui.captionLifecycle
Assert ($caption.passed -eq $true -and
    $caption.physicalMinimizePassed -eq $true -and
    $caption.physicalCloseExitedProcess -eq $true) (
    "Physical caption minimize or close did not pass.")
Assert ($caption.saveStateBefore -ceq "· 已保存" -and
    $caption.saveStateAfter -ceq "· 已保存" -and
    $caption.sessionCleanBeforeAndAfter -eq $true) (
    "Caption actions dirtied or mutated the chart session.")
Assert ($caption.timelineFocusedBeforeWindowDrag -eq $true -and
    $caption.timelineFocusedAfterWindowDrag -eq $true) (
    "Timeline keyboard focus was not preserved across native window drag.")

$normal = $caption.initialBounds
$buttonMax = $caption.captionButtonMaximizedBounds
$doubleMax = $caption.doubleClickMaximizedBounds
Assert ([long]$normal.width -eq 1980 -and [long]$normal.height -eq 1200) (
    "Initial window does not equal 1320x800 DIPs at 150 percent.")
Assert-BoundsEqual $caption.nativeRestoreAfterMinimizeBounds $normal (
    "Native setup restore after physical minimize")
Assert-BoundsEqual $caption.captionButtonRestoredBounds $normal (
    "Caption-button restore")
Assert-BoundsEqual $caption.doubleClickRestoredBounds $normal (
    "Title-bar double-click restore")
Assert-BoundsEqual $caption.dragRestoredBounds $normal (
    "Title-bar drag restore")
Assert-BoundsEqual $doubleMax $buttonMax (
    "Button and title-bar double-click maximized bounds")
Assert ([long]$buttonMax.left -eq 0 -and [long]$buttonMax.top -eq 0 -and
    [long]$buttonMax.width -eq 2560 -and [long]$buttonMax.height -eq 1528 -and
    [long]$buttonMax.width -gt [long]$normal.width -and
    [long]$buttonMax.height -gt [long]$normal.height) (
    "Native maximized bounds are not exact on the formal desktop.")
Assert ([long]$caption.draggedBounds.left -eq ([long]$normal.left + 180) -and
    [long]$caption.draggedBounds.top -eq ([long]$normal.top + 120) -and
    [long]$caption.draggedBounds.width -eq [long]$normal.width -and
    [long]$caption.draggedBounds.height -eq [long]$normal.height) (
    "Physical title-bar drag did not move the window by exactly +180,+120 pixels.")

$expectedActionNames = @(
    "caption-minimize",
    "caption-maximize",
    "caption-restore",
    "titlebar-double-click-maximize",
    "titlebar-double-click-restore",
    "titlebar-window-drag",
    "titlebar-window-drag-restore",
    "caption-close")
$expectedActionInputs = @(
    "Win32 SendInput physical mouse click",
    "Win32 SendInput physical mouse click",
    "Win32 SendInput physical mouse click",
    "Win32 SendInput physical mouse double-click",
    "Win32 SendInput physical mouse double-click",
    "Win32 SendInput physical mouse drag",
    "Win32 SendInput physical mouse drag",
    "Win32 SendInput physical mouse click")
$actions = @($caption.actions)
Assert ($actions.Count -eq 8) "Expected exactly eight physical caption actions."
for ($index = 0; $index -lt $actions.Count; $index++) {
    Assert ($actions[$index].name -ceq $expectedActionNames[$index]) (
        "Unexpected caption action at index $index.")
    Assert ($actions[$index].input -ceq $expectedActionInputs[$index]) (
        "Unexpected physical input type at caption action $index.")
}
Assert ($actions[0].isIconicAfter -eq $true -and
    $actions[1].isZoomedAfter -eq $true -and
    $actions[2].isZoomedAfter -eq $false -and
    $actions[3].isZoomedAfter -eq $true -and
    $actions[4].isZoomedAfter -eq $false) (
    "One or more native caption state transitions were not observed.")
Assert-BoundsEqual $actions[1].after $buttonMax "Caption maximize action"
Assert-BoundsEqual $actions[2].after $normal "Caption restore action"
Assert-BoundsEqual $actions[3].after $buttonMax "Double-click maximize action"
Assert-BoundsEqual $actions[4].after $normal "Double-click restore action"
Assert-BoundsEqual $actions[5].after $caption.draggedBounds "Title-bar drag action"
Assert-BoundsEqual $actions[6].after $normal "Title-bar drag restore action"

$captureNames = @(
    "windowed",
    "captionButtonMaximized",
    "captionButtonRestored",
    "doubleClickMaximized",
    "doubleClickRestored",
    "dragged",
    "dragRestored")
foreach ($name in $captureNames) {
    $capture = $gui.captures.$name
    Assert ([long]$capture.sampledUniqueColors -ge 64 -and
        [long]$capture.length -gt 100000) (
        "GUI capture $name is incomplete.")
}
Assert ([long]$gui.captures.windowed.width -eq [long]$normal.width -and
    [long]$gui.captures.captionButtonMaximized.width -eq
        [long]$buttonMax.width -and
    [long]$gui.captures.doubleClickMaximized.width -eq
        [long]$buttonMax.width) (
    "GUI capture dimensions do not match the native window states.")

$screenshotEvidence = @()
$screenshotProperties = @($gui.screenshots.PSObject.Properties)
Assert ($screenshotProperties.Count -eq 7) (
    "Expected seven declared GUI screenshots.")
foreach ($property in $screenshotProperties) {
    Assert ($expectedScreenshotHashes.Contains($property.Name)) (
        "Unexpected screenshot key: $($property.Name)")
    $declared = $property.Value
    $full = [IO.Path]::GetFullPath([string]$declared.path)
    Assert ($full.StartsWith(
        (Join-Path $formalRoot "gui") + '\',
        [StringComparison]::OrdinalIgnoreCase)) (
        "Screenshot escaped formal GUI root: $full")
    $actual = File-Evidence $full
    Assert ($actual.length -eq [long]$declared.length) (
        "Screenshot length mismatch: $full")
    Assert ($actual.sha256 -ceq [string]$declared.sha256) (
        "Screenshot hash mismatch: $full")
    Assert ($actual.sha256 -ceq
        $expectedScreenshotHashes[$property.Name].ToUpperInvariant()) (
        "Reviewed screenshot hash changed: $($property.Name)")
    $screenshotEvidence += [ordered]@{
        name = $property.Name
        file = $actual
    }
}

$realChartHash =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$installerHash =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
$predecessorHash =
    "0050566EBC54E0FF74BA1FBF3EC72B111BE451C21C2CD8743AE426D33DC3AD1C"
Assert ($gui.source.unchanged -eq $true -and
    $gui.source.sha256Before -ceq $gui.source.sha256After -and
    $gui.source.sha256Before -ceq $realChartHash) (
    "Real MC fixture changed during formal GUI acceptance.")
Assert ($gui.frozenInstaller.unchanged -eq $true -and
    $gui.frozenInstaller.sha256Before -ceq $gui.frozenInstaller.sha256After -and
    $gui.frozenInstaller.sha256Before -ceq $installerHash) (
    "Frozen WPF installer changed during formal GUI acceptance.")
Assert ($gui.predecessor.sha256 -ceq $predecessorHash) (
    "Window-resize predecessor authority changed.")
Assert ($gui.completion.captionLifecycleSlicePassed -eq $true -and
    $gui.completion.windowsAvaloniaOneToOneComplete -eq $false -and
    $gui.completion.userReplacementApprovalReceived -eq $false -and
    $gui.completion.nextPlatformAuthorized -eq $false) (
    "GUI completion markers overstate the migration status.")

$fixture = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
Assert ($fixture.sha256 -ceq $realChartHash) "Frozen real MC hash changed."
$installer = File-Evidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert ($installer.sha256 -ceq $installerHash) "Frozen installer hash changed."
$predecessor = File-Evidence (
    Join-Path $projectRoot (
        "artifacts\windows-avalonia-window-resize-slice-20260727-r1\" +
        "verification-evidence.json"))
Assert ($predecessor.sha256 -ceq $predecessorHash) (
    "Window-resize predecessor verification changed.")

$sourcePaths = @(
    "LumaChart.Avalonia\Infrastructure\WindowsTitleBarParityPolicy.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\WindowsTitleBarParitySpecs.cs",
    "tools\Capture-WindowsAvaloniaTitleBarGui.ps1",
    "tools\New-WindowsAvaloniaCaptionLifecycleSliceEvidence.ps1")
$sourceEvidence = @($sourcePaths | ForEach-Object {
    File-Evidence (Join-Path $projectRoot $_)
})

$leftovers = @()
if (Get-Process -Id ([int]$gui.processId) -ErrorAction SilentlyContinue) {
    $leftovers += [int]$gui.processId
}
Assert ($leftovers.Count -eq 0) "Evidence-owned client process remains: $leftovers"

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.caption-lifecycle-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        windowsAvaloniaOnly = $true
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        formalAuthority = "caption-lifecycle-r1"
    }
    builds = [ordered]@{
        warnings = 0
        errors = 0
        logs = $builds
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 453
            total = 453
            failed = 0
            focusedCheck = $focusedChecks[0]
            evidence = File-Evidence $specsPath
            log = File-Evidence (
                Join-Path $formalRoot "tests\avalonia-specs-run.log")
        }
        mainSpecs = [ordered]@{
            passed = 79
            total = 79
            failed = 0
            log = File-Evidence $mainLogPath
        }
    }
    gui = [ordered]@{
        cleanFormalRerun = $true
        physicalActionCount = 8
        physicalClickCount = 4
        physicalDoubleClickCount = 2
        physicalDragCount = 2
        physicalMinimizePassed = $true
        captionMaximizeAndRestorePassed = $true
        titleBarDoubleClickMaximizeAndRestorePassed = $true
        titleBarMoveAndExactRestorePassed = $true
        physicalCleanCloseExitedExactProcess = $true
        sessionCleanBeforeAndAfter = $true
        timelineFocusPreserved = $true
        screenshotCount = 7
        manualVisualReviewPassed = $true
        evidence = File-Evidence $guiPath
        screenshots = $screenshotEvidence
        leftoverEvidenceOwnedProcessIds = $leftovers
    }
    source = [ordered]@{
        changedFiles = $sourcePaths
        files = $sourceEvidence
    }
    frozenBaselines = [ordered]@{
        realChart = $fixture
        installer = $installer
        predecessorWindowResize = $predecessor
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
File-Evidence $verificationPath | ConvertTo-Json -Depth 6
