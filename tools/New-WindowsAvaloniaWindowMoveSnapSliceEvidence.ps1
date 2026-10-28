param(
    [string]$Root =
        "artifacts\windows-avalonia-window-move-snap-slice-20260727-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedWindowedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedCaptionMaximizedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedCaptionRestoredScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedTopSnappedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedTopRestoredScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedLeftSnappedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedLeftRestoredScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedRightSnappedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedRightRestoredScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedAdminConfigurationScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedAdminConfigurationSavedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedAdminUserScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedAdminUserSavedScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia window-move/Snap verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-window-move-snap-slice-20260727-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal window-move/Snap root must be exactly $expectedRoot"
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

function Assert-BoundsNear(
    [object]$Actual,
    [object]$Expected,
    [long]$Tolerance,
    [string]$Description) {
    foreach ($field in @("left", "top", "right", "bottom", "width", "height")) {
        Assert ([Math]::Abs(
                [long]$Actual.$field - [long]$Expected.$field) -le $Tolerance) (
            "$Description differs at $field.")
    }
}

$expectedScreenshotHashes = [ordered]@{
    "titlebar-windowed" = $ExpectedWindowedScreenshotSha256
    "window-move-maximized" = $ExpectedCaptionMaximizedScreenshotSha256
    "window-move-restored-from-maximized" =
        $ExpectedCaptionRestoredScreenshotSha256
    "window-move-snapped-top" = $ExpectedTopSnappedScreenshotSha256
    "window-move-restored-from-top" = $ExpectedTopRestoredScreenshotSha256
    "window-move-snapped-left" = $ExpectedLeftSnappedScreenshotSha256
    "window-move-unsnapped-left" = $ExpectedLeftRestoredScreenshotSha256
    "window-move-snapped-right" = $ExpectedRightSnappedScreenshotSha256
    "window-move-unsnapped-right" = $ExpectedRightRestoredScreenshotSha256
}
foreach ($hash in $expectedScreenshotHashes.Values) {
    Assert ($hash -match '^[0-9A-Fa-f]{64}$') "A screenshot SHA-256 is invalid."
}
$expectedAdminScreenshotHashes = [ordered]@{
    loadedConfiguration = $ExpectedAdminConfigurationScreenshotSha256
    savedConfiguration = $ExpectedAdminConfigurationSavedScreenshotSha256
    loadedUser = $ExpectedAdminUserScreenshotSha256
    savedUser = $ExpectedAdminUserSavedScreenshotSha256
}
foreach ($hash in $expectedAdminScreenshotHashes.Values) {
    Assert ($hash -match '^[0-9A-Fa-f]{64}$') (
        "An owner-admin screenshot SHA-256 is invalid.")
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
    onlineGuiServer = Assert-StrictBuild (
        Join-Path $formalRoot "build\online-gui-server-build.log")
}

$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs = Get-Content -Raw -LiteralPath $specsPath | ConvertFrom-Json -Depth 100
$checks = @($specs.checks)
$passedChecks = @($checks | Where-Object { $_.passed })
$focusedName = "titlebar-window-snap-placement-and-restore-are-exact"
$focusedChecks = @($checks | Where-Object { $_.name -ceq $focusedName })
$managedSecurityName =
    "managed-client-security-owner-admin-routes-fail-closed-without-native-policy"
$managedSecurityChecks = @($checks | Where-Object {
    $_.name -ceq $managedSecurityName
})
$adminSurfaceName =
    "online-owner-admin-surface-uses-managed-owner-gated-session-routes"
$adminSurfaceChecks = @($checks | Where-Object {
    $_.name -ceq $adminSurfaceName
})
Assert ($specs.status -ceq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 465 -and $passedChecks.Count -eq 465) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
Assert ($focusedChecks.Count -eq 1 -and $focusedChecks[0].passed) (
    "The window Snap placement and restore Spec did not pass.")
Assert ($managedSecurityChecks.Count -eq 1 -and $managedSecurityChecks[0].passed) (
    "The managed ClientSecurity owner/admin Spec did not pass.")
Assert ($adminSurfaceChecks.Count -eq 1 -and $adminSurfaceChecks[0].passed) (
    "The owner admin surface Spec did not pass.")

$mainLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainText = Get-Content -Raw -LiteralPath $mainLogPath
Assert ($mainText -match "79/79 specs passed") "Main Specs did not pass 79/79."

$guiPath = Join-Path $formalRoot "gui\titlebar-gui-evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json -Depth 100
Assert ($gui.schema -ceq (
    "lumachart.windows.avalonia.window-move-snap-gui-evidence.v1")) (
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
    [long]$inputEvidence.physicalActionCount -eq 9 -and
    [long]$inputEvidence.physicalClickCount -eq 2 -and
    [long]$inputEvidence.physicalDragCount -eq 7 -and
    [long]$inputEvidence.physicalSetupClickCount -eq 1 -and
    [long]$inputEvidence.foregroundActivationMouseClickCount -ge 1 -and
    $inputEvidence.hardwareInputClaimed -eq $false) (
    "Current-slice physical input contract differs from the formal gate.")
Assert ([long]$gui.chrome.titleBarHeight -eq 38 -and
    [long]$gui.chrome.captionButtonWidth -eq 46 -and
    $gui.chrome.formatBadge -ceq "MALODY" -and
    $gui.chrome.documentTab -like "谱面标签 Resound*") (
    "WPF title-bar metrics or real-chart identity changed.")
Assert ([Math]::Abs([double]$gui.environment.activeWindowsScale - 1.5) -le
    0.001 -and
    [long]$gui.environment.screenCount -eq 1 -and
    $gui.environment.multiScreenTested -eq $false -and
    $gui.environment.perMonitorDpiTransitionTested -eq $false) (
    "The formal single-screen 150 percent environment contract changed.")

$move = $gui.windowMoveAndSnap
Assert ($move.passed -eq $true -and
    $move.maximizeDragRestorePassed -eq $true -and
    $move.topSnapAndRestorePassed -eq $true -and
    $move.leftSnapAndRestorePassed -eq $true -and
    $move.rightSnapAndRestorePassed -eq $true -and
    $move.physicalCloseExitedProcess -eq $true) (
    "One or more physical maximize/Snap transitions did not pass.")
Assert ($move.saveStateBefore -ceq "· 已保存" -and
    $move.saveStateAfter -ceq "· 已保存" -and
    $move.sessionCleanBeforeAndAfter -eq $true -and
    $move.timelineFocusedBefore -eq $true -and
    $move.timelineFocusedAfter -eq $true) (
    "Window move/Snap actions changed the chart or lost timeline focus.")

$normal = $move.initialBounds
$maximized = $move.maximizedBounds
$expectedLeft = [ordered]@{
    left = 0; top = 0; right = 1620; bottom = 1528
    width = 1620; height = 1528
}
$expectedRight = [ordered]@{
    left = 940; top = 0; right = 2560; bottom = 1528
    width = 1620; height = 1528
}
Assert ([long]$normal.width -eq 1980 -and [long]$normal.height -eq 1200) (
    "Initial window does not equal 1320x800 DIPs at 150 percent.")
Assert ([long]$maximized.left -eq 0 -and [long]$maximized.top -eq 0 -and
    [long]$maximized.width -eq 2560 -and [long]$maximized.height -eq 1528) (
    "Maximized bounds are not exact on the formal desktop.")
Assert-BoundsNear $move.topSnappedBounds $maximized 4 "Top Snap maximize"
Assert-BoundsNear $move.snappedLeftBounds $expectedLeft 4 "Left Snap placement"
Assert-BoundsNear $move.snappedRightBounds $expectedRight 4 "Right Snap placement"
Assert-BoundsNear $move.expectedLeftSnapBounds $expectedLeft 0 (
    "Declared expected left Snap placement")
Assert-BoundsNear $move.expectedRightSnapBounds $expectedRight 0 (
    "Declared expected right Snap placement")
foreach ($restored in @(
        $move.restoredFromMaximizedBounds,
        $move.restoredFromTopBounds,
        $move.unsnappedLeftBounds,
        $move.unsnappedRightBounds)) {
    Assert ([Math]::Abs([long]$restored.width - [long]$normal.width) -le 12 -and
        [Math]::Abs([long]$restored.height - [long]$normal.height) -le 12) (
        "A drag-away restore did not recover the WPF normal size.")
}

$baseline = $move.snapDiagnosticsBaseline
$final = $move.snapDiagnosticsFinal
Assert ([long]$final.scheduled -eq ([long]$baseline.scheduled + 7) -and
    [long]$final.applied -eq ([long]$baseline.applied + 7) -and
    [long]$final.noTarget -eq ([long]$baseline.noTarget + 4) -and
    $final.lastOutcome -ceq "None") (
    "Runtime Snap diagnostics did not observe all seven physical drags.")

$expectedActionNames = @(
    "caption-maximize-before-drag",
    "maximized-titlebar-drag-restore",
    "titlebar-snap-top-maximize",
    "top-snapped-titlebar-drag-restore",
    "titlebar-snap-left",
    "titlebar-unsnap-left",
    "titlebar-snap-right",
    "titlebar-unsnap-right",
    "caption-close-after-window-move")
$expectedOutcomes = @($null, "None", "Maximize", "None", "Left", "None",
    "Right", "None", $null)
$actions = @($move.actions)
Assert ($actions.Count -eq 9) "Expected exactly nine physical move/Snap actions."
for ($index = 0; $index -lt $actions.Count; $index++) {
    Assert ($actions[$index].name -ceq $expectedActionNames[$index]) (
        "Unexpected move/Snap action at index $index.")
    $expectedInput = if ($index -in @(0, 8)) {
        "Win32 SendInput physical mouse click"
    }
    else {
        "Win32 SendInput physical mouse drag"
    }
    Assert ($actions[$index].input -ceq $expectedInput) (
        "Unexpected physical input type at move/Snap action $index.")
    if ($null -ne $expectedOutcomes[$index]) {
        Assert ($actions[$index].snapDiagnostics.lastOutcome -ceq
            $expectedOutcomes[$index]) (
            "Unexpected runtime Snap outcome at action $index.")
    }
}

$captureNames = @(
    "windowed",
    "maximized",
    "restoredFromMaximized",
    "snappedTop",
    "restoredFromTop",
    "snappedLeft",
    "unsnappedLeft",
    "snappedRight",
    "unsnappedRight")
foreach ($name in $captureNames) {
    $capture = $gui.captures.$name
    Assert ([long]$capture.sampledUniqueColors -ge 64 -and
        [long]$capture.length -gt 100000) (
        "GUI capture $name is incomplete.")
}

$screenshotEvidence = @()
$screenshotProperties = @($gui.screenshots.PSObject.Properties)
Assert ($screenshotProperties.Count -eq 9) (
    "Expected nine declared GUI screenshots.")
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

$adminGuiPath = Join-Path $formalRoot (
    "gui\owner-admin\online-surface-gui-evidence.json")
$adminGuiRaw = Get-Content -Raw -LiteralPath $adminGuiPath
Assert ($adminGuiRaw -notmatch (
    "(?i)windows-avalonia-gui-(owner|member)-token|authorization" +
    "\s*[:=]\s*[`"']?bearer")) (
    "Owner-admin GUI evidence contains an authentication secret.")
$adminGui = $adminGuiRaw | ConvertFrom-Json -Depth 100
Assert ($adminGui.schema -ceq (
    "lumachart.windows.avalonia.owner-admin-gui-evidence.v1")) (
    "Unexpected owner-admin GUI schema: $($adminGui.schema)")
Assert ($adminGui.status -ceq "passed" -and
    $adminGui.sessionRestored -eq $true -and
    $adminGui.ownerRoleObserved -eq $true) (
    "Owner-admin GUI did not restore an owner session and pass.")
Assert ($adminGui.mouseInputUsed -eq $true -and
    $adminGui.automationValuePatternUsed -eq $true -and
    $adminGui.keyboardInputUsed -eq $false -and
    [long]$adminGui.physicalActionCount -eq 15 -and
    [long]$adminGui.physicalSetupClickCount -eq 1) (
    "Owner-admin GUI input contract differs from the formal gate.")
Assert ($adminGui.hostedInMainWindow -eq $true -and
    $adminGui.separateNativeWindowCreated -eq $false -and
    $adminGui.close.invokedPhysically -eq $true -and
    $adminGui.close.surfaceHidden -eq $true) (
    "Owner-admin surface hosting or physical close differs.")
Assert ($adminGui.migrationComplete -eq $false -and
    $adminGui.windowsParityComplete -eq $false) (
    "Owner-admin evidence overstates migration completion.")

$adminServer = $adminGui.server
Assert ([long]$adminServer.adminConfigurationUpdateCount -eq 1 -and
    [long]$adminServer.adminUserReadCount -eq 1 -and
    [long]$adminServer.adminUserUpdateCount -eq 1 -and
    [long]$adminServer.adminUserLabelUpdateCount -eq 1 -and
    [long]$adminServer.adminUserAvatarResetCount -eq 1 -and
    [long]$adminServer.adminUserAvatarUploadCount -eq 1 -and
    [long]$adminServer.adminUserAvatarUploadBytes -eq
        [long]$adminGui.userAdministration.avatarFixture.length) (
    "Owner-admin loopback request counts differ.")
Assert ($adminGui.userAdministration.avatarUploadPending -eq $false -and
    $adminGui.userAdministration.nativeAvatarPicker.title -ceq
        "选择用户头像图片" -and
    $adminGui.userAdministration.nativeAvatarPicker.submission -ceq
        "ValuePattern exact path + physical native Open button click") (
    "Owner avatar native picker did not pass the formal physical contract.")
$adminAvatarFixture = File-Evidence (
    [string]$adminGui.userAdministration.avatarFixture.path)
Assert ([IO.Path]::GetFullPath(
        [string]$adminGui.userAdministration.avatarFixture.path).StartsWith(
        (Join-Path $formalRoot "gui\owner-admin") + '\',
        [StringComparison]::OrdinalIgnoreCase)) (
    "Owner avatar fixture escaped its formal GUI root.")
Assert ($adminAvatarFixture.length -eq
        [long]$adminGui.userAdministration.avatarFixture.length -and
    $adminAvatarFixture.sha256 -ceq
        [string]$adminGui.userAdministration.avatarFixture.sha256) (
    "Owner avatar fixture file evidence differs.")
Assert ($adminServer.appConfiguration.aboutContent -ceq
        "Windows Avalonia owner 管理 GUI 已通过隔离验收。" -and
    $adminServer.appConfiguration.latestVersion -ceq "1.1.0-admin-gui" -and
    $adminServer.appConfiguration.minimumLoginVersion -ceq "1.1.0" -and
    $adminServer.appConfiguration.updateNotice -ceq
        "隔离 loopback：内容后台保存已验收。" -and
    $adminServer.appConfiguration.downloadUrl -ceq
        "https://example.invalid/avalonia-admin-gui") (
    "Owner-admin application configuration payload differs.")
$adminMember = @($adminServer.adminUsers) |
    Where-Object { [long]$_.id -eq 4202 } |
    Select-Object -First 1
Assert ($null -ne $adminMember -and
    $adminMember.displayName -ceq "Avalonia 成员（管理员验收）" -and
    $adminMember.bio -ceq
        "Windows Avalonia owner 用户资料与标签 GUI 验收。" -and
    $adminMember.customLabel -ceq "Avalonia owner GUI 验收" -and
    $adminMember.avatarKey -ceq "default") (
    "Owner-admin stored member profile differs.")
$adminNameColorTags = @($adminMember.tags | Where-Object {
    $_.name -ceq "管理员验收" -and
    $_.color -ceq "#5BC0BE" -and
    $_.isNameColor -eq $true
})
Assert ($adminNameColorTags.Count -eq 1) (
    "Owner-admin tag/name-color payload differs.")

$adminScreenshotDeclarations = [ordered]@{
    loadedConfiguration =
        $adminGui.applicationConfiguration.loadedScreenshotPath
    savedConfiguration =
        $adminGui.applicationConfiguration.savedScreenshotPath
    loadedUser = $adminGui.userAdministration.loadedScreenshotPath
    savedUser = $adminGui.userAdministration.savedScreenshotPath
}
$adminDeclaredHashes = [ordered]@{
    loadedConfiguration =
        $adminGui.applicationConfiguration.loadedScreenshotSha256
    savedConfiguration =
        $adminGui.applicationConfiguration.savedScreenshotSha256
    loadedUser = $adminGui.userAdministration.loadedScreenshotSha256
    savedUser = $adminGui.userAdministration.savedScreenshotSha256
}
$adminScreenshotEvidence = @()
foreach ($name in $adminScreenshotDeclarations.Keys) {
    $full = [IO.Path]::GetFullPath(
        [string]$adminScreenshotDeclarations[$name])
    Assert ($full.StartsWith(
        (Join-Path $formalRoot "gui\owner-admin") + '\',
        [StringComparison]::OrdinalIgnoreCase)) (
        "Owner-admin screenshot escaped its formal GUI root: $full")
    $actual = File-Evidence $full
    Assert ($actual.length -gt 60000) (
        "Owner-admin GUI screenshot is incomplete: $full")
    Assert ($actual.sha256 -ceq [string]$adminDeclaredHashes[$name]) (
        "Owner-admin declared screenshot hash differs: $name")
    Assert ($actual.sha256 -ceq
        $expectedAdminScreenshotHashes[$name].ToUpperInvariant()) (
        "Reviewed owner-admin screenshot hash changed: $name")
    $adminScreenshotEvidence += [ordered]@{
        name = $name
        file = $actual
    }
}

$realChartHash =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$installerHash =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
$predecessorHash =
    "7346AB9BCC610957718556F3AB2320B154B0361DBA5A6CAA918BC175B442E878"
Assert ($gui.source.unchanged -eq $true -and
    $gui.source.sha256Before -ceq $gui.source.sha256After -and
    $gui.source.sha256Before -ceq $realChartHash) (
    "Real MC fixture changed during formal GUI acceptance.")
Assert ($gui.frozenInstaller.unchanged -eq $true -and
    $gui.frozenInstaller.sha256Before -ceq $gui.frozenInstaller.sha256After -and
    $gui.frozenInstaller.sha256Before -ceq $installerHash) (
    "Frozen WPF installer changed during formal GUI acceptance.")
Assert ($gui.predecessor.sha256 -ceq $predecessorHash) (
    "Caption-lifecycle predecessor authority changed.")
Assert ($gui.completion.windowMoveSnapSlicePassed -eq $true -and
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
        "artifacts\windows-avalonia-caption-lifecycle-slice-20260727-r1\" +
        "verification-evidence.json"))
Assert ($predecessor.sha256 -ceq $predecessorHash) (
    "Caption-lifecycle predecessor verification changed.")

$sourcePaths = @(
    "LumaChart.Avalonia\Infrastructure\WindowsWindowSnapPolicy.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsTitleBarParityPolicy.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsOnlineSurfaceParityPolicy.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia\Dialogs\OnlineCommunityDialog.cs",
    "LumaChart.Online\OnlineAccountSession.cs",
    "LumaChart.Avalonia.Specs\WindowsAccountSessionSpecs.cs",
    "LumaChart.Avalonia.Specs\WindowsOnlineSurfaceParitySpecs.cs",
    "LumaChart.Avalonia.Specs\WindowsTitleBarParitySpecs.cs",
    "tools\WindowsAvaloniaOnlineGuiServer\Program.cs",
    "tools\Capture-WindowsAvaloniaOnlineSurfaceGui.ps1",
    "tools\Capture-WindowsAvaloniaTitleBarGui.ps1",
    "tools\New-WindowsAvaloniaWindowMoveSnapSliceEvidence.ps1")
$sourceEvidence = @($sourcePaths | ForEach-Object {
    File-Evidence (Join-Path $projectRoot $_)
})

$leftovers = @()
if (Get-Process -Id ([int]$gui.processId) -ErrorAction SilentlyContinue) {
    $leftovers += [int]$gui.processId
}
if (Get-Process -Id ([int]$adminGui.processId) -ErrorAction SilentlyContinue) {
    $leftovers += [int]$adminGui.processId
}
Assert ($leftovers.Count -eq 0) "Evidence-owned client process remains: $leftovers"

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.window-move-snap-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        windowsAvaloniaOnly = $true
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        formalAuthority = "window-move-snap-r1"
    }
    builds = [ordered]@{
        warnings = 0
        errors = 0
        logs = $builds
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 465
            total = 465
            failed = 0
            focusedCheck = $focusedChecks[0]
            managedClientSecurityCheck = $managedSecurityChecks[0]
            ownerAdminSurfaceCheck = $adminSurfaceChecks[0]
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
        physicalActionCount = 9
        physicalClickCount = 2
        physicalDragCount = 7
        physicalSetupActivationClickCount = 1
        maximizeDragRestorePassed = $true
        topSnapAndRestorePassed = $true
        leftSnapAndRestorePassed = $true
        rightSnapAndRestorePassed = $true
        exact150PercentPlacementPassed = $true
        physicalCleanCloseExitedExactProcess = $true
        sessionCleanBeforeAndAfter = $true
        timelineFocusPreserved = $true
        screenshotCount = 13
        manualVisualReviewPassed = $true
        evidence = File-Evidence $guiPath
        screenshots = $screenshotEvidence
        ownerAdmin = [ordered]@{
            physicalActionCount = 15
            physicalSetupActivationClickCount = 1
            managedValuePatternUsed = $true
            appConfigurationSaved = $true
            userProfileAndNameColorSaved = $true
            customLabelSaved = $true
            avatarUploadNativePickerPassed = $true
            avatarResetPassed = $true
            evidence = File-Evidence $adminGuiPath
            avatarFixture = $adminAvatarFixture
            screenshots = $adminScreenshotEvidence
        }
        leftoverEvidenceOwnedProcessIds = $leftovers
    }
    source = [ordered]@{
        changedFiles = $sourcePaths
        files = $sourceEvidence
    }
    frozenBaselines = [ordered]@{
        realChart = $fixture
        installer = $installer
        predecessorCaptionLifecycle = $predecessor
    }
    remainingDifferences = @(
        "Only one physical screen was attached; multi-screen and Per-Monitor DPI transitions remain open.",
        "Native Windows 11 Snap Layout hover UI and keyboard-only Snap remain separate acceptance items.",
        "Remaining focus/IME, online, format, installer and physical performance gates remain open.")
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
