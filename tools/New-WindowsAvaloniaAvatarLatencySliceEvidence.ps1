param(
    [string]$Root =
        "artifacts\windows-avalonia-avatar-latency-slice-20260727-r1"
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia avatar/latency verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-avatar-latency-slice-20260727-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal avatar/latency root must be exactly $expectedRoot"
}
if (-not (Test-Path -LiteralPath $formalRoot -PathType Container)) {
    throw "Formal avatar/latency root does not exist: $formalRoot"
}
$guiPath = Join-Path $formalRoot "gui\gui-evidence.json"
$verificationPath = Join-Path $formalRoot "verification-evidence.json"
foreach ($output in @($guiPath, $verificationPath)) {
    if (Test-Path -LiteralPath $output) {
        throw "Formal output already exists: $output"
    }
}

function Get-FileEvidence {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "Required evidence file is missing: $full"
    }
    $item = Get-Item -LiteralPath $full
    return [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $full).Replace("/", "\")
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Assert-StrictBuildLog {
    param([Parameter(Mandatory = $true)][string]$Path)
    $text = Get-Content -LiteralPath $Path -Raw
    if ($text -notmatch "已成功生成" -or
        $text -notmatch "0 个警告" -or
        $text -notmatch "0 个错误" -or
        $text -match "生成失败") {
        throw "Strict ordinary Release build did not prove 0 warning / 0 error: $Path"
    }
    return Get-FileEvidence $Path
}

function Assert-DeclaredFile {
    param(
        [Parameter(Mandatory = $true)]$Declared,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $actual = Get-FileEvidence ([string]$Declared.path)
    if ([long]$actual.length -ne [long]$Declared.length -or
        [string]$actual.sha256 -cne [string]$Declared.sha256) {
        throw "$Label differs from its declared length/hash."
    }
    return $actual
}

$buildLogs = [ordered]@{
    avalonia = Assert-StrictBuildLog (
        Join-Path $formalRoot "build\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuildLog (
        Join-Path $formalRoot "build\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuildLog (
        Join-Path $formalRoot "build\main-specs-build.log")
    loopbackServer = Assert-StrictBuildLog (
        Join-Path $formalRoot "build\loopback-server-build.log")
}

$avaloniaSpecsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$avaloniaSpecs = Get-Content -LiteralPath $avaloniaSpecsPath -Raw | ConvertFrom-Json
$checks = @($avaloniaSpecs.checks)
$failedChecks = @($checks | Where-Object { -not [bool]$_.passed })
if ([string]$avaloniaSpecs.status -cne "passed" -or
    $checks.Count -ne 429 -or $failedChecks.Count -ne 0) {
    throw "Avalonia Specs did not prove 429/429."
}
$requiredChecks = @(
    "online-default-avatar-and-login-identity-match-wpf-110",
    "titlebar-online-round-trip-latency-label-is-exact")
$focusedChecks = @($checks | Where-Object {
    [string]$_.name -in $requiredChecks
})
foreach ($name in $requiredChecks) {
    if (@($focusedChecks | Where-Object {
            [string]$_.name -ceq $name -and [bool]$_.passed
        }).Count -ne 1) {
        throw "Focused Avalonia check did not pass exactly once: $name"
    }
}
$avaloniaSpecsLogPath = Join-Path $formalRoot "tests\avalonia-specs-run.log"
$mainSpecsLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
if ((Get-Content -LiteralPath $avaloniaSpecsLogPath -Raw) -notmatch
        "Avalonia slice verification: passed") {
    throw "Avalonia Specs run log did not report passed."
}
if ((Get-Content -LiteralPath $mainSpecsLogPath -Raw) -notmatch
        "79/79 specs passed\.") {
    throw "Main Specs did not prove 79/79."
}

$startupPath = Join-Path $formalRoot "gui\startup\evidence.json"
$startup = Get-Content -LiteralPath $startupPath -Raw | ConvertFrom-Json
if ([string]$startup.schema -cne
        "lumachart.windows.avalonia.startup-offline-gui-evidence.v1" -or
    [string]$startup.status -cne "passed" -or
    -not [bool]$startup.endpointIsLoopback -or
    [bool]$startup.productionEndpointContacted -or
    -not [bool]$startup.hostedInMainWindow -or
    [bool]$startup.separateNativeWindowCreated -or
    [int]$startup.navigationClickCount -ne 0 -or
    [int]$startup.offlineClickCount -ne 1 -or
    -not [bool]$startup.mouseInputUsed -or
    [bool]$startup.keyboardInputUsed -or
    [bool]$startup.offlineAction.sessionTokenExists -or
    [double]$startup.startup.windowDpi -ne 144 -or
    [double]$startup.startup.windowScale -ne 1.5 -or
    [double]$startup.startup.loginAvatar.bounds.width -ne 189 -or
    [double]$startup.startup.loginAvatar.bounds.height -ne 189 -or
    [double]$startup.startup.titleAvatar.bounds.width -ne 36 -or
    [double]$startup.startup.titleAvatar.bounds.height -ne 36 -or
    [string]$startup.startup.loginAvatar.name -cne "默认用户头像" -or
    [string]$startup.startup.titleAvatar.name -cne "默认用户头像") {
    throw "Formal startup GUI did not prove WPF 126/24 DIP default-avatar parity."
}
if ([bool]$startup.isolation.ollvmUsed -or
    [bool]$startup.isolation.obfuscationUsed -or
    [bool]$startup.isolation.codeVirtualizationUsed -or
    [bool]$startup.isolation.aotUsed -or
    [bool]$startup.isolation.mobilePlatformTouched -or
    -not [bool]$startup.isolation.ordinaryReleaseOnly) {
    throw "Startup GUI scope was not Windows-only ordinary managed Release."
}

$onlinePath = Join-Path $formalRoot "gui\online\evidence.json"
$online = Get-Content -LiteralPath $onlinePath -Raw | ConvertFrom-Json
if ([string]$online.schema -cne
        "lumachart.windows.avalonia.hidden-private-invitation-gui-evidence.v1" -or
    [string]$online.status -cne "passed" -or
    -not [bool]$online.windowsAvaloniaOnly -or
    [bool]$online.productionServerMutationPerformed -or
    [bool]$online.mobileProjectsBuiltModifiedInstalledOrTested -or
    -not [bool]$online.pureDotnetRelease -or
    [bool]$online.ollvmObfuscationPackingVirtualizationOrAotUsed -or
    -not [bool]$online.physicalMouseInputUsed -or
    -not ([string]$online.endpoint).StartsWith(
        "http://127.0.0.1:",
        [StringComparison]::Ordinal)) {
    throw "Formal two-client GUI scope/status is invalid."
}
$ownerInitial = [string]$online.controls.ownerLiveLatencyInitial.name
$memberInitial = [string]$online.controls.memberLiveLatencyInitial.name
$ownerMeasured = [string]$online.controls.ownerLiveLatencyMeasured.name
$memberMeasured = [string]$online.controls.memberLiveLatencyMeasured.name
if ($ownerInitial -cne "-- ms" -or $memberInitial -cne "-- ms" -or
    $ownerMeasured -notmatch '^\d{1,5} ms$' -or
    $memberMeasured -notmatch '^\d{1,5} ms$' -or
    [string]$online.controls.ownerLiveBadgeLatency.name -notmatch
        "^联机 #7654321 \d{1,5} ms$" -or
    [string]$online.controls.memberLiveBadgeLatency.name -notmatch
        "^联机 #7654321 \d{1,5} ms$" -or
    [string]$online.controls.ownerLiveBadgeLatency.helpText -notlike
        "*与联机服务器最近一次请求的往返延迟*" -or
    [string]$online.controls.memberLiveBadgeLatency.helpText -notlike
        "*与联机服务器最近一次请求的往返延迟*") {
    throw "Formal two-client GUI did not prove both dynamic WPF latency labels."
}
$server = $online.room.finalServerState
$activeIds = @($server.activeMemberIds | ForEach-Object { [long]$_ } | Sort-Object)
if (-not [bool]$server.roomCreated -or
    $activeIds.Count -ne 2 -or
    $activeIds[0] -ne 4101 -or $activeIds[1] -ne 4202 -or
    [int]$server.resourceEntryCount -ne 3 -or
    [int]$server.downloadedBlobCount -lt 3 -or
    [int]$server.invitationJoinCount -ne 1 -or
    [int]$server.memberNormalJoinRequestCount -ne 0 -or
    [int]$server.memberJoinPasswordSubmissionCount -ne 0 -or
    -not [bool]$online.invitation.roomPrivate -or
    -not [bool]$online.invitation.roomHidden -or
    -not [bool]$online.invitation.passwordBypassPassed -or
    -not [bool]$online.invitation.passwordAbsentFromMemberUiAutomation) {
    throw "Formal invitation room lost membership/resource/password-bypass guarantees."
}

$screenshots = [Collections.Generic.List[object]]::new()
foreach ($entry in @(
        [ordered]@{
            name = "startup-login"
            path = [string]$startup.startup.screenshotPath
            sha256 = [string]$startup.startup.screenshotSha256
        },
        [ordered]@{
            name = "offline-library"
            path = [string]$startup.offlineAction.screenshotPath
            sha256 = [string]$startup.offlineAction.screenshotSha256
        })) {
    $file = Get-FileEvidence $entry.path
    if ([string]$file.sha256 -cne [string]$entry.sha256) {
        throw "Startup screenshot hash differs: $($entry.name)"
    }
    $screenshots.Add([ordered]@{ name = $entry.name; file = $file })
}
foreach ($property in $online.screenshots.PSObject.Properties) {
    $file = Assert-DeclaredFile $property.Value "Online screenshot $($property.Name)"
    $screenshots.Add([ordered]@{ name = $property.Name; file = $file })
}
if ($screenshots.Count -ne 13) {
    throw "Formal avatar/latency slice must contain exactly 13 screenshots."
}

$trustedChartSha256 =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$trustedInstallerSha256 =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
$fixture = Get-FileEvidence "D:\osu!\Songs\Resound\0\1781536331.mc"
$installer = Get-FileEvidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
if ([string]$fixture.sha256 -cne $trustedChartSha256 -or
    [string]$installer.sha256 -cne $trustedInstallerSha256) {
    throw "Real MC or frozen installer hash changed."
}
$predecessor = Get-FileEvidence (
    Join-Path $projectRoot (
        "artifacts\windows-avalonia-export-dialog-parity-slice-20260727-r1\" +
        "verification-evidence.json"))
if ([string]$predecessor.sha256 -cne
    "69962868A6FAA870D07CAF58A3FA0B630AABE02F01B42D20F2E6082144A54FC1") {
    throw "Export-dialog predecessor authority changed."
}

$testProcessIds = @(
    [int]$startup.processId,
    [int]$online.processIds.server,
    [int]$online.processIds.owner,
    [int]$online.processIds.member)
$leftovers = @($testProcessIds | Where-Object {
    $_ -gt 0 -and $null -ne (Get-Process -Id $_ -ErrorAction SilentlyContinue)
})
if ($leftovers.Count -ne 0) {
    throw "Formal GUI left evidence-owned processes running: $($leftovers -join ', ')"
}

$gui = [ordered]@{
    schema = "lumachart.windows.avalonia.avatar-latency-gui-evidence.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        platform = "Windows Avalonia only"
        productionServerContacted = $false
        mobilePlatformTouched = $false
        ordinaryDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    }
    defaultAvatar = [ordered]@{
        contract = "wpf-1.1.0-default-user-avatar-r1"
        source = "LumaChart.Avalonia\Assets\default-user-avatar.svg"
        background = "#181D20"
        foreground = "#8AADAF"
        loginDipSize = 126
        titleDipSize = 24
        dpi = [double]$startup.startup.windowDpi
        scale = [double]$startup.startup.windowScale
        loginObservation = $startup.startup.loginAvatar
        titleObservation = $startup.startup.titleAvatar
    }
    latency = [ordered]@{
        contract = "WPF online document-tab round-trip label"
        ownerInitial = $online.controls.ownerLiveLatencyInitial
        memberInitial = $online.controls.memberLiveLatencyInitial
        ownerMeasured = $online.controls.ownerLiveLatencyMeasured
        memberMeasured = $online.controls.memberLiveLatencyMeasured
        ownerBadge = $online.controls.ownerLiveBadgeLatency
        memberBadge = $online.controls.memberLiveBadgeLatency
        thresholdsMilliseconds = @(80, 180)
        colors = @("#89C9AD", "#DAB770", "#DC8474", "#809497")
    }
    online = [ordered]@{
        loopbackEndpoint = [string]$online.endpoint
        hiddenPrivateInvitationDirectJoin = $true
        activeMemberIds = $activeIds
        resourceEntryCount = [int]$server.resourceEntryCount
        downloadedBlobCount = [int]$server.downloadedBlobCount
        physicalActionCount = @($online.physicalActions).Count
    }
    manualVisualReview = [ordered]@{
        required = $true
        performed = $true
        result = "passed"
        reviewedImages = @(
            "startup-login",
            "owner-online-latency",
            "member-online-latency")
    }
    sourceEvidence = [ordered]@{
        startup = Get-FileEvidence $startupPath
        online = Get-FileEvidence $onlinePath
    }
    screenshots = $screenshots
    evidenceOwnedProcessIds = $testProcessIds
    leftoverEvidenceOwnedProcessIds = @()
    completion = [ordered]@{
        thisSlicePassed = $true
        fullWindowsMigrationComplete = $false
        userReplacementApproval = $false
        otherPlatformAuthorization = $false
    }
}
$gui | ConvertTo-Json -Depth 25 |
    Set-Content -LiteralPath $guiPath -Encoding utf8NoBOM

$changedFiles = [Collections.Generic.List[object]]::new()
foreach ($relativePath in @(
        "LumaChart.Avalonia\Controls\WindowsDefaultUserAvatar.cs",
        "LumaChart.Avalonia\Dialogs\OnlineAccountDialog.cs",
        "LumaChart.Avalonia\Dialogs\OnlineCommunityDialog.cs",
        "LumaChart.Avalonia\Infrastructure\WindowsOnlineSurfaceParityPolicy.cs",
        "LumaChart.Avalonia\Infrastructure\WindowsTitleBarParityPolicy.cs",
        "LumaChart.Avalonia\MainWindow.cs",
        "LumaChart.Avalonia.Specs\WindowsOnlineSurfaceParitySpecs.cs",
        "LumaChart.Avalonia.Specs\WindowsTitleBarParitySpecs.cs",
        "tools\Capture-WindowsAvaloniaStartupOfflineGui.ps1",
        "tools\Capture-WindowsAvaloniaTwoClientOnlineGui.ps1",
        "tools\New-WindowsAvaloniaAvatarLatencySliceEvidence.ps1")) {
    $changedFiles.Add((Get-FileEvidence (Join-Path $projectRoot $relativePath)))
}

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.avatar-latency-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        platform = "Windows Avalonia only"
        covered = @(
            "WPF default avatar asset geometry/colors",
            "startup login identity avatar and spacing",
            "title and community fallback avatars",
            "live document-tab round-trip latency text/colors/tooltip",
            "two isolated clients in a hidden private room")
        excluded = @(
            "Android", "iOS", "macOS", "Linux", "WebAssembly",
            "production Server deployment", "installer replacement",
            "OLLVM", "obfuscation", "packing", "code virtualization",
            "AOT", "NativeAOT")
    }
    builds = [ordered]@{
        configuration = "ordinary .NET Release"
        warnings = 0
        errors = 0
        logs = $buildLogs
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 429
            total = 429
            failed = 0
            focusedChecks = $focusedChecks
            evidence = Get-FileEvidence $avaloniaSpecsPath
            log = Get-FileEvidence $avaloniaSpecsLogPath
        }
        mainSpecs = [ordered]@{
            passed = 79
            total = 79
            failed = 0
            log = Get-FileEvidence $mainSpecsLogPath
        }
    }
    gui = [ordered]@{
        cleanRerunAfterUserMouseClarification = $true
        startupAvatarPhysicalGeometryPassed = $true
        twoClientLatencyTransitionPassed = $true
        hiddenInvitationAndResourcesPassed = $true
        manualVisualReviewPassed = $true
        evidence = Get-FileEvidence $guiPath
        screenshots = $screenshots
        evidenceOwnedProcessIds = $testProcessIds
        leftoverEvidenceOwnedProcessIds = @()
    }
    source = [ordered]@{
        changedFiles = $changedFiles
    }
    frozenBaselines = [ordered]@{
        realChart = $fixture
        installer = $installer
        predecessor = $predecessor
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
Get-FileEvidence $verificationPath | ConvertTo-Json -Depth 6
