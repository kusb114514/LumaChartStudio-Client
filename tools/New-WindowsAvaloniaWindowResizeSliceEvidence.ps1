param(
    [string]$Root =
        "artifacts\windows-avalonia-window-resize-slice-20260727-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedWindowedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedRightEdgeScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedMinimumScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedRestoredScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia window-resize verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-window-resize-slice-20260727-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal window-resize root must be exactly $expectedRoot"
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
    "window-resize-right-edge" = $ExpectedRightEdgeScreenshotSha256
    "window-resize-minimum" = $ExpectedMinimumScreenshotSha256
    "window-resize-restored" = $ExpectedRestoredScreenshotSha256
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
$focusedNames = @(
    "titlebar-wpf-chrome-metrics-are-exact",
    "titlebar-borderless-resize-hit-zones-are-exact")
$focusedChecks = @($checks | Where-Object { $_.name -in $focusedNames })
Assert ($specs.status -eq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 452 -and $passedChecks.Count -eq 452) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
Assert ($focusedChecks.Count -eq 2 -and @($focusedChecks | Where-Object {
    -not $_.passed
}).Count -eq 0) "Window-resize focused Specs did not both pass."

$mainLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainText = Get-Content -Raw -LiteralPath $mainLogPath
Assert ($mainText -match "79/79 specs passed") "Main Specs did not pass 79/79."

$guiPath = Join-Path $formalRoot "gui\titlebar-gui-evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json -Depth 100
Assert ($gui.schema -eq (
    "lumachart.windows.avalonia.window-resize-gui-evidence.v1")) (
    "Unexpected GUI schema: $($gui.schema)")
Assert ($gui.status -eq "passed-migration-incomplete") (
    "GUI evidence status is not passed-migration-incomplete.")
Assert ($gui.windowsAvaloniaOnly -eq $true) "GUI evidence is not Windows-only."
Assert ($gui.productionServerMutationPerformed -eq $false) (
    "GUI evidence mutated production Server.")
Assert ($gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false) (
    "GUI evidence touched mobile projects.")
Assert ($gui.pureDotnetRelease -eq $true) "GUI evidence is not ordinary Release."
Assert ($gui.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "GUI evidence used forbidden protection or AOT.")
Assert ($gui.currentSliceInput.physicalMouseInputUsed -eq $true -and
    $gui.currentSliceInput.input -ceq "Win32 SendInput physical mouse drag" -and
    [long]$gui.currentSliceInput.physicalWindowResizeActionCount -eq 19 -and
    $gui.currentSliceInput.timelineFocusSetup -ceq "UI Automation SetFocus" -and
    $gui.currentSliceInput.keyboardInjectionUsed -eq $false -and
    $gui.currentSliceInput.hardwareInputClaimed -eq $false) (
    "Current-slice physical input contract differs from the formal gate.")

$resize = $gui.windowResize
$scale = [double]$resize.activeWindowsScale
Assert ([double]::IsFinite($scale) -and $scale -gt 0) (
    "Active Windows scale is invalid.")
Assert ($resize.nativeBorderlessCanResize -eq $true -and
    $resize.physicalMouseInputUsed -eq $true -and
    $resize.passed -eq $true) "Borderless resize did not pass."
Assert (@($resize.testedEdges).Count -eq 4 -and
    (@($resize.testedEdges) -join ",") -ceq "left,top,right,bottom") (
    "The four physical edges were not tested in the expected order.")
Assert (@($resize.testedCorners).Count -eq 4 -and
    (@($resize.testedCorners) -join ",") -ceq (
        "top-left,top-right,bottom-left,bottom-right")) (
    "The four physical corners were not tested in the expected order.")
Assert ([long]$gui.chrome.titleBarHeight -eq 38 -and
    [long]$gui.chrome.captionButtonWidth -eq 46 -and
    [long]$gui.chrome.resizeBorderThickness -eq 6 -and
    [long]$gui.chrome.minimumWindowWidth -eq 1080 -and
    [long]$gui.chrome.minimumWindowHeight -eq 680) (
    "WPF title-bar or resize metrics changed.")
Assert ($gui.chrome.formatBadge -ceq "MALODY" -and
    $gui.chrome.documentTab -like "谱面标签 Resound*" -and
    [Math]::Abs(([double]$gui.chrome.tabCloseWidth / $scale) - 25) -le 1.0) (
    "The document-tab chrome differs from the WPF baseline.")

$expectedMinimumWidth = [long][Math]::Round(1080 * $scale)
$expectedMinimumHeight = [long][Math]::Round(680 * $scale)
$expectedInitialWidth = [long][Math]::Round(1320 * $scale)
$expectedInitialHeight = [long][Math]::Round(800 * $scale)
Assert ([long]$resize.expectedMinimumWidth -eq $expectedMinimumWidth -and
    [long]$resize.expectedMinimumHeight -eq $expectedMinimumHeight -and
    [long]$resize.minimumBounds.width -eq $expectedMinimumWidth -and
    [long]$resize.minimumBounds.height -eq $expectedMinimumHeight) (
    "Native minimum bounds do not equal 1080x680 DIPs at the active scale.")
Assert ([long]$resize.initialBounds.width -eq $expectedInitialWidth -and
    [long]$resize.initialBounds.height -eq $expectedInitialHeight) (
    "Initial window bounds do not equal the WPF 1320x800 baseline.")
Assert-BoundsEqual $resize.restoredBounds $resize.initialBounds (
    "Restored window bounds")
Assert ([long]$resize.representativeRightEdgeBounds.width -lt
    [long]$resize.initialBounds.width -and
    [long]$resize.representativeRightEdgeBounds.height -eq
    [long]$resize.initialBounds.height -and
    [long]$resize.representativeRightEdgeBounds.left -eq
    [long]$resize.initialBounds.left) (
    "Representative right-edge drag did not resize only the right edge.")
Assert ($resize.minimumCaptionCloseVisible -eq $true) (
    "Caption close button was not visible at the native minimum.")
$close = $resize.minimumCaptionCloseBounds
Assert ([double]$close.left -ge [double]$resize.minimumBounds.left -and
    [double]$close.right -le [double]$resize.minimumBounds.right -and
    [double]$close.top -ge [double]$resize.minimumBounds.top -and
    [double]$close.bottom -le [double]$resize.minimumBounds.bottom) (
    "Caption close button escaped the minimum window bounds.")
Assert ($resize.timelineFocusedBeforeResize -eq $true -and
    $resize.timelineFocusedAfterResize -eq $true) (
    "Timeline keyboard focus was not preserved across window resize.")
Assert ($resize.saveStateBeforeResize -ceq "· 已保存" -and
    $resize.saveStateAfterResize -ceq "· 已保存" -and
    $resize.sessionCleanBeforeResize -eq $true -and
    $resize.sessionCleanAfterResize -eq $true) (
    "Window resizing dirtied or mutated the chart session.")

$expectedActionNames = @(
    "right-edge-inward",
    "right-edge-restore",
    "bottom-edge-inward",
    "bottom-edge-restore",
    "left-edge-inward",
    "left-edge-restore",
    "top-edge-inward",
    "top-edge-restore",
    "top-left-corner-inward",
    "top-left-corner-restore",
    "top-right-corner-inward",
    "top-right-corner-restore",
    "bottom-left-corner-inward",
    "bottom-left-corner-restore",
    "bottom-right-corner-inward",
    "bottom-right-corner-restore",
    "right-edge-minimum-clamp",
    "bottom-edge-minimum-clamp",
    "bottom-right-corner-restore-from-minimum")
$actions = @($resize.actions)
Assert ($actions.Count -eq $expectedActionNames.Count) (
    "Expected exactly 19 physical resize actions.")
for ($index = 0; $index -lt $expectedActionNames.Count; $index++) {
    Assert ($actions[$index].name -ceq $expectedActionNames[$index]) (
        "Unexpected resize action at index $index.")
    Assert ($actions[$index].input -ceq (
        "Win32 SendInput physical mouse drag")) (
        "Resize action $index was not a physical mouse drag.")
}
foreach ($restoreIndex in @(1, 3, 5, 7, 9, 11, 13, 15, 18)) {
    Assert-BoundsEqual $actions[$restoreIndex].after $resize.initialBounds (
        "Restore action $restoreIndex")
}
Assert ([long]$actions[0].after.width -lt [long]$actions[0].before.width -and
    [long]$actions[2].after.height -lt [long]$actions[2].before.height -and
    [long]$actions[4].after.left -gt [long]$actions[4].before.left -and
    [long]$actions[6].after.top -gt [long]$actions[6].before.top) (
    "One or more edge drags did not move the intended native border.")
foreach ($index in @(8, 10, 12, 14)) {
    Assert ([long]$actions[$index].after.width -lt
        [long]$actions[$index].before.width -and
        [long]$actions[$index].after.height -lt
        [long]$actions[$index].before.height) (
        "Corner drag $index did not resize both dimensions.")
}
Assert ([long]$actions[16].after.width -eq $expectedMinimumWidth -and
    [long]$actions[17].after.width -eq $expectedMinimumWidth -and
    [long]$actions[17].after.height -eq $expectedMinimumHeight) (
    "Physical minimum-size clamps were not exact.")

$captureNames = @(
    "windowed",
    "rightEdgeResize",
    "minimumResize",
    "resizeRestored")
$captureExpectedBounds = @(
    $resize.initialBounds,
    $resize.representativeRightEdgeBounds,
    $resize.minimumBounds,
    $resize.restoredBounds)
for ($index = 0; $index -lt $captureNames.Count; $index++) {
    $capture = $gui.captures.($captureNames[$index])
    Assert ([long]$capture.width -eq
        [long]$captureExpectedBounds[$index].width -and
        [long]$capture.height -eq
        [long]$captureExpectedBounds[$index].height -and
        [long]$capture.sampledUniqueColors -ge 64 -and
        [long]$capture.length -gt 100000) (
        "GUI capture $($captureNames[$index]) is incomplete.")
}

$screenshotEvidence = @()
$screenshotProperties = @($gui.screenshots.PSObject.Properties)
Assert ($screenshotProperties.Count -eq 4) (
    "Expected four declared GUI screenshots.")
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

Assert ($gui.source.unchanged -eq $true -and
    $gui.source.sha256Before -ceq $gui.source.sha256After -and
    $gui.source.sha256Before -ceq (
        "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E")) (
    "Real MC fixture changed during formal GUI acceptance.")
Assert ($gui.frozenInstaller.unchanged -eq $true -and
    $gui.frozenInstaller.sha256Before -ceq
    $gui.frozenInstaller.sha256After -and
    $gui.frozenInstaller.sha256Before -ceq (
        "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4")) (
    "Frozen WPF installer changed during formal GUI acceptance.")
Assert ($gui.completion.windowResizeSlicePassed -eq $true -and
    $gui.completion.windowsAvaloniaOneToOneComplete -eq $false -and
    $gui.completion.userReplacementApprovalReceived -eq $false -and
    $gui.completion.nextPlatformAuthorized -eq $false) (
    "GUI completion markers overstate the migration status.")

$fixture = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
Assert ($fixture.sha256 -ceq (
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E")) (
    "Frozen real MC hash changed.")
$installer = File-Evidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert ($installer.sha256 -ceq (
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4")) (
    "Frozen installer hash changed.")
$predecessor = File-Evidence (
    Join-Path $projectRoot (
        "artifacts\windows-avalonia-metadata-preview-race-slice-20260727-r2\" +
        "verification-evidence.json"))
Assert ($predecessor.sha256 -ceq (
    "DABBBDE51F95EFE0B1B030AF59F78CF35FC5FEC2E8FE562A45E0A40A2FF330F5")) (
    "Previous overall formal authority hash changed.")
Assert ($gui.predecessorPhysicalAuthority.sha256 -ceq (
    "95ACA55697D840D500B446A45C2CAF3EDCE00EA96E2E1F7D4E420F5FA21689F4") -and
    $gui.predecessorPhysicalAuthority.titleBarDoubleClickMaximized -eq $true -and
    $gui.predecessorPhysicalAuthority.f11EnterAndExit -eq $true) (
    "Previous title-bar physical authority changed.")

$sourcePaths = @(
    "LumaChart.Avalonia\Infrastructure\WindowsTitleBarParityPolicy.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsDisplayScaleController.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\WindowsTitleBarParitySpecs.cs",
    "tools\Capture-WindowsAvaloniaTitleBarGui.ps1",
    "tools\New-WindowsAvaloniaWindowResizeSliceEvidence.ps1")
$sourceEvidence = @($sourcePaths | ForEach-Object {
    File-Evidence (Join-Path $projectRoot $_)
})

$leftovers = @()
if (Get-Process -Id ([int]$gui.processId) -ErrorAction SilentlyContinue) {
    $leftovers += [int]$gui.processId
}
Assert ($leftovers.Count -eq 0) "Evidence-owned client process remains: $leftovers"

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.window-resize-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        windowsAvaloniaOnly = $true
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        formalAuthority = "window-resize-r1"
    }
    builds = [ordered]@{
        warnings = 0
        errors = 0
        logs = $builds
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 452
            total = 452
            failed = 0
            focusedChecks = $focusedChecks
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
        physicalResizeActionCount = 19
        edgesPassed = 4
        cornersPassed = 4
        nativeMinimumDip = "1080x680"
        nativeMinimumPhysical = (
            "$expectedMinimumWidth" + "x" + "$expectedMinimumHeight")
        sessionCleanBeforeAndAfter = $true
        timelineFocusPreserved = $true
        captionControlsVisibleAtMinimum = $true
        screenshotCount = 4
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
        predecessorOverall = $predecessor
        predecessorPhysicalTitleBar = [ordered]@{
            path = $gui.predecessorPhysicalAuthority.path
            sha256 = $gui.predecessorPhysicalAuthority.sha256
        }
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
