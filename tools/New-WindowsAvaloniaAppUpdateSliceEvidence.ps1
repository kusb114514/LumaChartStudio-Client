param(
    [string]$Root =
        "artifacts\windows-avalonia-app-update-slice-20260727-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedAvailablePromptScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedAvailableAfterOfflineScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedRequiredPromptScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedRequiredAfterOfflineScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedSettingsScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedAboutScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedCurrentScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia app-update verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-app-update-slice-20260727-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals(
        $expectedRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal app-update root must be exactly $expectedRoot"
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

function Assert-PhysicalAction([object]$Action, [string]$AutomationId) {
    Assert ($Action.automationId -ceq $AutomationId -and
        $Action.mechanism -ceq "Win32 physical mouse click" -and
        $Action.physicalInput -eq $true) (
        "Formal action '$AutomationId' was not an exact physical mouse click.")
}

function Assert-ActivationSetup([object]$Setup) {
    Assert ($Setup.mechanism -ceq (
            "recorded physical title-bar activation click") -and
        $Setup.physicalInput -eq $true -and
        $Setup.behaviorAction -eq $false) (
        "A scenario lacks its separately recorded physical activation setup.")
}

$expectedScreenshotHashes = [ordered]@{
    availablePrompt = $ExpectedAvailablePromptScreenshotSha256
    availableAfterOffline = $ExpectedAvailableAfterOfflineScreenshotSha256
    requiredPrompt = $ExpectedRequiredPromptScreenshotSha256
    requiredAfterOffline = $ExpectedRequiredAfterOfflineScreenshotSha256
    settings = $ExpectedSettingsScreenshotSha256
    about = $ExpectedAboutScreenshotSha256
    current = $ExpectedCurrentScreenshotSha256
}
foreach ($hash in $expectedScreenshotHashes.Values) {
    Assert ($hash -match '^[0-9A-Fa-f]{64}$') (
        "A reviewed screenshot SHA-256 is invalid.")
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$builds = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\main-specs-build.log")
    onlineGuiServer = Assert-StrictBuild (
        Join-Path $formalRoot "build\online-gui-server-build.log")
}

$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs = Get-Content -Raw -LiteralPath $specsPath |
    ConvertFrom-Json -Depth 100
$checks = @($specs.checks)
$passedChecks = @($checks | Where-Object { $_.passed })
$expectedAppUpdateChecks = @(
    "app-update-geometry-and-colors-match-wpf-110",
    "app-update-managed-version-comparison-preserves-wpf-normalization",
    "app-update-current-version-presentation-matches-wpf-110",
    "app-update-available-presentation-matches-wpf-110",
    "app-update-minimum-version-blocks-login-but-keeps-offline-mode",
    "app-update-startup-current-version-stays-silent-and-settings-stays-informative",
    "app-update-required-policy-fetch-failure-preserves-offline-route",
    "app-update-main-shell-login-and-owner-admin-routing-are-wired",
    "app-update-policy-has-no-native-clientsecurity-or-ollvm-dependency")
$appUpdateChecks = @($checks | Where-Object {
    $_.name -in $expectedAppUpdateChecks
})
Assert ($specs.status -ceq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 465 -and $passedChecks.Count -eq 465) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
Assert ($appUpdateChecks.Count -eq 9 -and
    @($appUpdateChecks | Where-Object { $_.passed }).Count -eq 9) (
    "One or more managed app-update policy Specs did not pass.")

$mainLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainText = Get-Content -Raw -LiteralPath $mainLogPath
Assert ($mainText -match "79/79 specs passed") "Main Specs did not pass 79/79."

$guiPath = Join-Path $formalRoot "gui\gui-evidence.json"
$guiRaw = Get-Content -Raw -LiteralPath $guiPath
Assert ($guiRaw -notmatch (
    "(?i)windows-avalonia-gui-(owner|member)-token|authorization" +
    "\s*[:=]\s*[`"']?bearer")) (
    "App-update GUI evidence contains an authentication secret.")
$gui = $guiRaw | ConvertFrom-Json -Depth 100
Assert ($gui.schema -ceq (
    "lumachart.windows.avalonia.app-update-gui-evidence.v1")) (
    "Unexpected app-update GUI schema: $($gui.schema)")
Assert ($gui.status -ceq "passed-migration-incomplete") (
    "App-update GUI status is not passed-migration-incomplete.")
Assert ($gui.windowsAvaloniaOnly -eq $true -and
    $gui.productionServerMutationPerformed -eq $false -and
    $gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false -and
    $gui.pureDotnetRelease -eq $true -and
    $gui.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "Formal app-update scope or build policy differs.")

$inputEvidence = $gui.input
Assert ($gui.formalPhysicalInput -eq $true -and
    $inputEvidence.physicalMouseInputUsed -eq $true -and
    [long]$inputEvidence.physicalBehaviorActionCount -eq 8 -and
    [long]$inputEvidence.physicalSetupActivationClickCount -eq 3 -and
    [long]$inputEvidence.automationScrollSetupCount -eq 2 -and
    $inputEvidence.keyboardInputUsed -eq $false -and
    $inputEvidence.uncommittedImeCompositionRequired -eq $false -and
    $inputEvidence.hardwareInputClaimed -eq $false -and
    $inputEvidence.externalDownloadLinkClicked -eq $false -and
    $inputEvidence.browserOpened -eq $false) (
    "Formal app-update input contract differs.")

$scenarios = @($gui.scenarios)
Assert ($scenarios.Count -eq 2 -and
    $scenarios[0].id -ceq "available" -and
    $scenarios[1].id -ceq "required") (
    "Expected exactly available and required startup scenarios.")
$available = $scenarios[0]
$required = $scenarios[1]
foreach ($scenario in $scenarios) {
    Assert-ActivationSetup $scenario.activationSetup
    Assert-PhysicalAction $scenario.dismiss "Update.Later"
    Assert ([long]$scenario.observed.layer.nativeWindowHandle -eq 0) (
        "Update layer opened a separate native window.")
    Assert ([long]$scenario.loginRequestCount -eq 0) (
        "A startup update scenario attempted login.")
}

Assert ($available.expected.latest -ceq "1.2.0" -and
    $available.expected.minimum -ceq "1.0.0" -and
    $available.expected.notice -ceq
        "Windows Avalonia 发现新版本 GUI 验收。" -and
    $available.expected.download -ceq
        "https://example.invalid/avalonia-update" -and
    $available.observed.title.name -ceq "发现新版本" -and
    $available.observed.version.name -ceq
        "当前 1.1.0  →  最新 1.2.0" -and
    $available.observed.notice.name -ceq
        "Windows Avalonia 发现新版本 GUI 验收。" -and
    $available.observed.later.name -ceq "关闭" -and
    $available.observed.download.name -ceq "打开下载链接" -and
    $available.observed.download.isEnabled -eq $true -and
    $available.policyHelpText -ceq
        "BlocksLogin=False; DownloadEnabled=True" -and
    [long]$available.appConfigurationRequestCount -eq 2) (
    "Available-update presentation or routing differs.")
Assert-PhysicalAction $available.after.offlineDismiss (
    "OnlineAccount.ContinueOffline")
Assert ($available.after.account.nativeWindowHandle -eq 0 -and
    $available.after.offline.name -ceq "不登录，离线使用 →") (
    "Available-update offline continuation differs.")

Assert ($required.expected.latest -ceq "2.0.0" -and
    $required.expected.minimum -ceq "1.1.1" -and
    $required.expected.notice -ceq
        "Windows Avalonia 最低版本登录门禁 GUI 验收。" -and
    $required.expected.download -ceq "" -and
    $required.observed.title.name -ceq "必须更新后才能登录" -and
    $required.observed.version.name -ceq
        "当前 1.1.0  →  最新 2.0.0" -and
    $required.observed.notice.name -ceq
        "Windows Avalonia 最低版本登录门禁 GUI 验收。" -and
    $required.observed.later.name -ceq "离线使用" -and
    $required.observed.download.name -ceq "暂未提供链接" -and
    $required.observed.download.isEnabled -eq $false -and
    $required.policyHelpText -ceq
        "BlocksLogin=True; DownloadEnabled=False" -and
    [long]$required.appConfigurationRequestCount -eq 1 -and
    $required.after.accountLayerVisible -eq $false -and
    $required.after.libraryRefresh.isOffscreen -eq $false) (
    "Minimum-version login gate or offline route differs.")

Assert ($available.appConfiguration.aboutContent -ceq
        "Windows Avalonia 更新 GUI 隔离验收。" -and
    $available.appConfiguration.latestVersion -ceq "1.2.0" -and
    $available.appConfiguration.minimumLoginVersion -ceq "1.0.0" -and
    $required.appConfiguration.aboutContent -ceq
        "Windows Avalonia 更新 GUI 隔离验收。" -and
    $required.appConfiguration.latestVersion -ceq "2.0.0" -and
    $required.appConfiguration.minimumLoginVersion -ceq "1.1.1") (
    "Loopback public app configurations differ.")

$settings = $gui.settingsAboutAndCurrent
Assert-ActivationSetup $settings.activationSetup
Assert-PhysicalAction $settings.settingsTabSelection "Inspector.SettingsTab"
Assert ($settings.aboutScrollSetup.automationSetupUsed -eq $true -and
    $settings.checkScrollSetup.automationSetupUsed -eq $true) (
    "Settings materialization setup was not explicitly recorded.")
Assert-PhysicalAction $settings.aboutOpen "Settings.About"
Assert-PhysicalAction $settings.aboutDismiss "About.Close"
Assert-PhysicalAction $settings.checkAction "Settings.CheckForUpdates"
Assert-PhysicalAction $settings.currentDismiss "Update.Later"
Assert ($settings.settingsVersion.name -ceq
        "当前版本 1.1.0 · 最新 1.1.0" -and
    [long]$settings.aboutLayer.nativeWindowHandle -eq 0 -and
    $settings.aboutVersion.name -ceq "版本 1.1.0" -and
    $settings.aboutContent.name -ceq
        "Windows Avalonia 更新 GUI 隔离验收。" -and
    $settings.currentTitle.name -ceq "已经是最新版本" -and
    $settings.currentVersion.name -ceq
        "当前 1.1.0  →  最新 1.1.0" -and
    $settings.currentNotice.name -ceq
        "当前客户端已经是最新版本。" -and
    [long]$settings.appConfigurationRequestCount -eq 3 -and
    [long]$settings.loginRequestCount -eq 0) (
    "Settings/About/current-version presentation or routing differs.")

$screenshotDeclarations = [ordered]@{
    availablePrompt = $available.promptScreenshot
    availableAfterOffline = $available.afterScreenshot
    requiredPrompt = $required.promptScreenshot
    requiredAfterOffline = $required.afterScreenshot
    settings = $settings.settingsScreenshot
    about = $settings.aboutScreenshot
    current = $settings.currentScreenshot
}
$screenshotEvidence = @()
foreach ($name in $screenshotDeclarations.Keys) {
    $declared = $screenshotDeclarations[$name]
    $full = [IO.Path]::GetFullPath([string]$declared.path)
    Assert ($full.StartsWith(
        (Join-Path $formalRoot "gui") + '\',
        [StringComparison]::OrdinalIgnoreCase)) (
        "Screenshot escaped formal GUI root: $full")
    $actual = File-Evidence $full
    Assert ([long]$declared.width -eq 1980 -and
        [long]$declared.height -eq 1200 -and
        [long]$actual.length -gt 60000) (
        "GUI screenshot dimensions or length differ: $name")
    Assert ($actual.sha256 -ceq [string]$declared.sha256 -and
        $actual.sha256 -ceq
            $expectedScreenshotHashes[$name].ToUpperInvariant()) (
        "Reviewed screenshot hash changed: $name")
    $screenshotEvidence += [ordered]@{
        name = $name
        file = $actual
    }
}
Assert ($screenshotEvidence.Count -eq 7) (
    "Expected exactly seven reviewed screenshots.")

$realChartHash =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$installerHash =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
$predecessorHash =
    "4E33A23D38E5E45D6712BF51FC7DE3F6A12BF084F79495CBF60AD00D99C36972"
Assert ($gui.source.unchanged -eq $true -and
    $gui.source.sha256Before -ceq $realChartHash -and
    $gui.source.sha256After -ceq $realChartHash -and
    $settings.chartSha256Before -ceq $realChartHash -and
    $settings.chartSha256After -ceq $realChartHash) (
    "Real MC fixture changed during formal app-update GUI acceptance.")
Assert ($gui.frozenInstaller.unchanged -eq $true -and
    $gui.frozenInstaller.sha256Before -ceq $installerHash -and
    $gui.frozenInstaller.sha256After -ceq $installerHash) (
    "Frozen WPF installer changed during formal app-update GUI acceptance.")
Assert ($gui.predecessor.sha256 -ceq $predecessorHash) (
    "Window-move/Snap predecessor authority changed.")
Assert ($gui.completion.appUpdatePresentationAndMinimumLoginGateSlicePassed -eq
        $true -and
    $gui.completion.actualDownloadInstallUpgradeRollbackRestartTested -eq
        $false -and
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
        "artifacts\windows-avalonia-window-move-snap-slice-20260727-r1\" +
        "verification-evidence.json"))
Assert ($predecessor.sha256 -ceq $predecessorHash) (
    "Window-move/Snap predecessor verification changed.")

$sourcePaths = @(
    "LumaChart.Avalonia\Infrastructure\WindowsAppUpdatePolicy.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia\Dialogs\OnlineAccountDialog.cs",
    "LumaChart.Avalonia\Dialogs\OnlineCommunityDialog.cs",
    "LumaChart.Avalonia.Specs\WindowsAppUpdatePolicySpecs.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "tools\WindowsAvaloniaOnlineGuiServer\Program.cs",
    "tools\Capture-WindowsAvaloniaAppUpdateGui.ps1",
    "tools\New-WindowsAvaloniaAppUpdateSliceEvidence.ps1")
$sourceEvidence = @($sourcePaths | ForEach-Object {
    File-Evidence (Join-Path $projectRoot $_)
})

$leftovers = @()
foreach ($processId in @(
        @($scenarios | ForEach-Object {
            [int]$_.applicationPid
            [int]$_.serverPid
        }) +
        @(
            [int]$settings.applicationPid,
            [int]$settings.serverPid
        ))) {
    if (Get-Process -Id $processId -ErrorAction SilentlyContinue) {
        $leftovers += $processId
    }
}
Assert ($leftovers.Count -eq 0) (
    "Evidence-owned client/server process remains: $leftovers")

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.app-update-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        windowsAvaloniaOnly = $true
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        formalAuthority = "app-update-r1"
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
            appUpdateChecks = $appUpdateChecks
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
        physicalBehaviorActionCount = 8
        physicalSetupActivationClickCount = 3
        automationScrollSetupCount = 2
        keyboardInputUsed = $false
        startupAvailablePassed = $true
        minimumVersionLoginBlockAndOfflineRoutePassed = $true
        settingsAboutAndCurrentVersionPassed = $true
        externalDownloadLinkNotClicked = $true
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
        predecessorWindowMoveSnap = $predecessor
    }
    remainingDifferences = @(
        "The actual package download, signature/hash validation, install/upgrade, rollback and restart path remains open.",
        "Installer upgrade/uninstall and managed ClientSecurity release gates remain open.",
        "Remaining focus/IME, shortcut, online, format, multi-screen/DPI and physical performance gates remain open.")
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
