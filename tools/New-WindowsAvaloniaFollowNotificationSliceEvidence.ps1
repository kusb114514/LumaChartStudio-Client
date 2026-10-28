param(
    [string]$FormalRoot = (
        Join-Path $PSScriptRoot `
            "..\artifacts\windows-avalonia-follow-notification-slice-20260728-r1")
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
            "code virtualization")) {
        Assert (
            -not $text.Contains(
                $forbidden,
                [StringComparison]::OrdinalIgnoreCase)) (
            "Strict build contains forbidden protection/AOT text '$forbidden': $Path")
    }
    return File-Evidence $Path
}

$guiPath = Join-Path $formalRoot "follow-notification-gui\evidence.json"
$avaloniaSpecsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$mainSpecsLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$gui = Read-Json $guiPath
$avaloniaSpecs = Read-Json $avaloniaSpecsPath

Assert (
    $gui.schema -ceq
        "lumachart.windows.avalonia.follow-notification-gui-evidence.v1" -and
    $gui.status -ceq "passed-migration-incomplete" -and
    $gui.platform -ceq "Windows Avalonia only" -and
    $gui.buildMode -ceq "ordinary .NET Release") (
    "Follow-notification GUI evidence boundary drifted.")
Assert (
    [bool]$gui.safety.explicitCurrentTurnConsent -and
    [int]$gui.safety.minimumIdleMilliseconds -ge 3000 -and
    [bool]$gui.safety.heldModifierGate -and
    -not [bool]$gui.safety.productionServerDeployed -and
    -not [bool]$gui.safety.mobileProjectsBuiltModifiedInstalledOrTested -and
    -not [bool]$gui.safety.ollvmObfuscationPackingVirtualizationOrAotUsed) (
    "GUI safety or platform boundary drifted.")
Assert (
    -not [bool]$gui.completion.windowsAvaloniaCanReplaceWpf -and
    -not [bool]$gui.completion.userManualReplacementApprovalReceived -and
    -not [bool]$gui.completion.nextPlatformAuthorized) (
    "Completion boundary drifted.")

$realMcSha256 =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$installerSha256 =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
Assert (
    [string]$gui.gui.realChart.sha256Before -ceq $realMcSha256 -and
    [string]$gui.gui.realChart.sha256After -ceq $realMcSha256 -and
    [bool]$gui.gui.realChart.sourceUnchanged) (
    "Real MC fixture changed.")
Assert (
    [string]$gui.frozenInstaller.sha256Before -ceq $installerSha256 -and
    [string]$gui.frozenInstaller.sha256After -ceq $installerSha256) (
    "Frozen WPF installer changed.")

$first = $gui.gui.firstToast
$second = $gui.gui.secondToast
Assert (
    [string]$first.observation.helpText -ceq
        "Visible=True; Message=Avalonia 成员关注了你。; DurationMilliseconds=4000; Width=360; Top=50; Right=14; Pending=1" -and
    [string]$second.observation.helpText -ceq
        "Visible=True; Message=匿名用户关注了你。; DurationMilliseconds=4000; Width=360; Top=50; Right=14; Pending=0") (
    "WPF 1.1.0 follow-notification queue contract drifted.")
foreach ($toast in @($first, $second)) {
    Assert (
        [double]$toast.visibleDurationMilliseconds -ge 3200 -and
        [double]$toast.visibleDurationMilliseconds -le 5000 -and
        -not [bool]$toast.observation.isOffscreen -and
        [double]$toast.observation.bounds.width -gt 0 -and
        [double]$toast.observation.bounds.height -gt 0) (
        "A queued follow-notification Toast duration or bounds drifted.")
    $screenshot = File-Evidence ([string]$toast.screenshot.path)
    Assert (
        $screenshot.sha256 -ceq [string]$toast.screenshot.sha256 -and
        $screenshot.bytes -eq [long]$toast.screenshot.bytes -and
        [int]$toast.screenshot.width -eq 1980 -and
        [int]$toast.screenshot.height -eq 1200) (
        "Follow-notification screenshot hash, length or dimensions drifted.")
}

$community = $gui.gui.communityHistory
$communityNames = @($community.descendantNames)
Assert (
    [bool]$community.firstNotificationRetained -and
    [bool]$community.anonymousNotificationRetained -and
    @($communityNames | Where-Object {
            $_.Contains(
                "Avalonia 成员关注了你。",
                [StringComparison]::Ordinal)
        }).Count -eq 1 -and
    @($communityNames | Where-Object {
            $_.Contains(
                "匿名用户关注了你。",
                [StringComparison]::Ordinal)
        }).Count -eq 1) (
    "Community history did not retain both main-shell notifications.")
$communityScreenshot = File-Evidence ([string]$community.screenshot.path)
Assert (
    $communityScreenshot.sha256 -ceq [string]$community.screenshot.sha256 -and
    $communityScreenshot.bytes -eq [long]$community.screenshot.bytes -and
    [int]$community.screenshot.width -eq 1980 -and
    [int]$community.screenshot.height -eq 1200) (
    "Community notification-history screenshot drifted.")

Assert (
    [int]$gui.gui.highWaterFetchCount -eq 1 -and
    [long]$gui.gui.firstInjection.id -eq 1 -and
    [long]$gui.gui.secondInjection.id -eq 2 -and
    [int]$gui.gui.server.notificationInjectionCount -eq 2 -and
    [int]$gui.gui.server.notificationFetchCount -ge 2 -and
    @($gui.gui.server.notifications).Count -eq 2) (
    "Loopback notification high-water/injection evidence drifted.")
Assert (
    [bool]$gui.gui.uiaInvokePatternUsed -and
    [bool]$gui.gui.uiaWindowClosePatternUsed -and
    -not [bool]$gui.gui.win32InputInjectionUsed -and
    -not [bool]$gui.gui.hardwareMouseInputClaimed -and
    -not [bool]$gui.gui.hardwareKeyboardInputClaimed -and
    -not [bool]$gui.gui.enterKeySent -and
    -not [bool]$gui.gui.persistentTopmostUsed -and
    -not [bool]$gui.gui.topmostAtStart -and
    -not [bool]$gui.gui.topmostBeforeClose -and
    [int]$gui.gui.processExitCode -eq 0) (
    "Follow-notification GUI interaction/topmost evidence drifted.")

$checks = @($avaloniaSpecs.Checks)
Assert (
    $avaloniaSpecs.Schema -ceq "lumachart.windows.avalonia.slice-specs.v2" -and
    $avaloniaSpecs.Status -ceq "passed" -and
    $checks.Count -eq 484 -and
    @($checks | Where-Object { -not $_.Passed }).Count -eq 0) (
    "Avalonia Specs are not 484/484.")
$sessionSpec = @(
    $checks | Where-Object {
        $_.Name -ceq
            "account-session-notification-high-water-and-page-chain-match-wpf"
    })
Assert (
    $sessionSpec.Count -eq 1 -and
    [bool]$sessionSpec[0].Passed -and
    [string]$sessionSpec[0].Detail -ceq
        "high-water, ordered broadcast, subscriber isolation, bounded history and logout reset") (
    "Shared notification session spec drifted.")
$toastSpec = @(
    $checks | Where-Object {
        $_.Name -ceq
            "global-follow-toast-matches-wpf-110-queue-and-visual-contract"
    })
Assert (
    $toastSpec.Count -eq 1 -and
    [bool]$toastSpec[0].Passed -and
    [string]$toastSpec[0].Detail -ceq
        "360@top50/right14; padding=14/11; poll=5000ms; toast=4000ms") (
    "Dedicated WPF follow-notification Toast parity spec drifted.")

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

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.follow-notification-slice-verification.v1"
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
        avaloniaSpecsPassed = 484
        avaloniaSpecsTotal = 484
        mainSpecsPassed = 79
        mainSpecsTotal = 79
        highWaterBootstrapDidNotReplayHistory = $true
        committedNotificationsBroadcastToAllConsumers = $true
        notificationHistoryBoundedToNewest100 = $true
        throwingSubscriberIsolated = $true
        historyResetOnLogout = $true
        sequentialToastCount = 2
        toastDurationMilliseconds = 4000
        firstToastVisibleDurationMilliseconds =
            [double]$first.visibleDurationMilliseconds
        secondToastVisibleDurationMilliseconds =
            [double]$second.visibleDurationMilliseconds
        communityRetainedBothNotifications = $true
        realChartUnchanged = $true
        frozenInstallerUnchanged = $true
        persistentTopmostUsed = $false
        physicalInputClaimed = $false
        productionServerDeployed = $false
        mobileProjectsTouched = $false
        protectionOrAotUsed = $false
        windowsAvaloniaCanReplaceWpf = $false
    }
    files = [ordered]@{
        guiEvidence = File-Evidence $guiPath
        firstToastScreenshot = File-Evidence ([string]$first.screenshot.path)
        secondToastScreenshot = File-Evidence ([string]$second.screenshot.path)
        communityScreenshot = $communityScreenshot
        avaloniaSpecsEvidence = File-Evidence $avaloniaSpecsPath
        avaloniaSpecsRun = File-Evidence (
            Join-Path $formalRoot "tests\avalonia-specs-run.log")
        mainSpecsRun = File-Evidence $mainSpecsLogPath
        builds = $builds
    }
}

$outputPath = Join-Path $formalRoot "verification-evidence.json"
$verification | ConvertTo-Json -Depth 12 |
    Set-Content -LiteralPath $outputPath -Encoding utf8NoBOM
$verification | ConvertTo-Json -Depth 12
