param(
    [string]$Root =
        "artifacts\windows-avalonia-online-creator-marker-slice-20260727-r1"
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia online creator-marker verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-online-creator-marker-slice-20260727-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal online creator-marker root must be exactly $expectedRoot"
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
    Assert ($text -match "0 个警告") "Strict build log lacks zero-warning result: $Path"
    Assert ($text -match "0 个错误") "Strict build log lacks zero-error result: $Path"
    Assert ($text -notmatch "(?i)ollvm|obfuscat|virtuali[sz]ation|nativeaot|publish-aot") (
        "Strict build log contains forbidden protection or AOT markers: $Path")
    File-Evidence $Path
}

$expectedScreenshotHashes = [ordered]@{
    "member-editor-bound" =
        "C1E53A93017BED52C963F2897A962BBE17826D2233A37B3A3D2619DEECFDB4BE"
    "member-own-creator-avatar-hover" =
        "261D22BCF6A25D7C35B169D4A3B9D8A9378184574C55C11C0E86F1B9707F50E9"
    "owner-creator-markers-playback-suppressed" =
        "EA2AA606439B4C0D642C74F1E02EAB6073792C2C845FD29DFA3D059D6B957924"
    "owner-creator-markers-restored" =
        "71419256BB30A9BAFCDB12B95200FA6C2B956BC83CE44CA1ADAD4ADC73055B75"
    "owner-editor-bound" =
        "9C6AEBBA2D78E846342E59FC4D6317CA97478D0C26330834E058AC33B049FC6F"
    "owner-member-creator-avatar-hover" =
        "59C34112B5B6BC8A1E68250692796DFE66CA403AF8E898DEC479B670192C8EEC"
    "owner-own-creator-avatar-hover" =
        "85A14F7962BE702CF9434201D50A6AE49A82C94D49611DFFE2A13424C9E3639C"
    "owner-room-create" =
        "FC02051040B2F3EDDB04036C569E346F482E1E8FD98F8061019AF8FFB6A9379D"
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$builds = [ordered]@{
    avalonia = Assert-StrictBuild (Join-Path $formalRoot "build\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (Join-Path $formalRoot "build\main-specs-build.log")
    onlineGuiServer = Assert-StrictBuild (
        Join-Path $formalRoot "build\online-gui-server-build.log")
}

$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs = Get-Content -Raw -LiteralPath $specsPath | ConvertFrom-Json
$checks = @($specs.checks)
$passedChecks = @($checks | Where-Object { $_.passed })
$focusedNames = @(
    "online-creator-marker-geometry-matches-wpf-110",
    "online-creator-marker-hidden-during-playback",
    "online-creator-marker-color-is-user-id-deterministic",
    "online-creator-marker-fallback-initial-matches-wpf",
    "online-creator-hover-status-and-tooltip-match-wpf")
$focusedChecks = @($checks | Where-Object { $_.name -in $focusedNames })
Assert ($specs.status -eq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 446 -and $passedChecks.Count -eq 446) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
Assert ($focusedChecks.Count -eq 5 -and @($focusedChecks | Where-Object {
    -not $_.passed
}).Count -eq 0) "Online creator-marker focused Specs did not all pass."

$mainLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainText = Get-Content -Raw -LiteralPath $mainLogPath
Assert ($mainText -match "79/79 specs passed") "Main Specs did not pass 79/79."

$guiPath = Join-Path $formalRoot "gui\evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -eq (
    "lumachart.windows.avalonia.two-client-online-creator-marker-gui-evidence.v1")) (
    "Unexpected GUI schema: $($gui.schema)")
Assert ($gui.status -eq "passed" -and $gui.passed -eq $true) (
    "Creator-marker GUI evidence is not passed.")
Assert ($gui.formalMigrationAuthority -eq $true -and
    $gui.windowsAvaloniaOnly -eq $true -and
    $gui.physicalMouseInputUsed -eq $true) (
    "GUI evidence is not formal Windows-only physical-input evidence.")
Assert ($gui.productionServerMutationPerformed -eq $false -and
    $gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false -and
    $gui.pureDotnetRelease -eq $true -and
    $gui.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "GUI evidence violated platform, server, or pure-Release constraints.")
Assert ([string]$gui.creatorMarkerContract -ceq (
    "wpf-1.1.0-online-creator-marker-r1")) (
    "Unexpected online creator-marker contract.")

$actions = @($gui.physicalActions)
Assert ($actions.Count -eq 9) "Expected exactly nine physical mouse actions."
$expectedActions = @(
    "member-physically-select-tap-tool",
    "member-physically-place-attributed-tap",
    "member-physically-select-hover-tool",
    "member-physically-hover-own-created-note",
    "owner-physically-hover-member-created-note",
    "owner-physically-hover-owner-created-note",
    "owner-physically-start-playback",
    "owner-physically-pause-playback",
    "owner-physically-hover-member-note-after-pause")
Assert (-not (Compare-Object $expectedActions $actions -SyncWindow 0)) (
    "Physical creator-marker action sequence changed.")

$chart = $gui.realChart
Assert ([int]$chart.noteCountBefore -eq 2753 -and
    [int]$chart.noteCountAfter -eq 2754 -and
    [int]$chart.timingCountBefore -eq 1) (
    "Real Resound Note or Timing structure is unexpected.")
Assert ([long]$chart.initializedRowsCreatorUserId -eq 4101 -and
    [long]$chart.memberCreatedNoteCreatorUserId -eq 4202 -and
    [long]$chart.memberCreatedNote.creatorUserId -eq 4202) (
    "Room initialization or member-created Note attribution is unexpected.")

$avatars = $gui.avatars
Assert ([int]$avatars.serverDownloadCountBeforePlacement -eq 4 -and
    [int]$avatars.serverDownloadCountFinal -eq 4 -and
    [int]$avatars.ownerTimelineAvatarCount -eq 2 -and
    [int]$avatars.memberTimelineAvatarCount -eq 2) (
    "Both timelines did not preload exactly two remote avatars.")
$avatarKeys = @($avatars.downloadKeys)
Assert ($avatarKeys.Count -eq 4 -and
    @($avatarKeys | Where-Object { $_ -ceq "owner-avatar-v1" }).Count -eq 2 -and
    @($avatarKeys | Where-Object { $_ -ceq "member-avatar-v1" }).Count -eq 2) (
    "Remote avatar download keys or counts changed.")

$timelines = $gui.creatorTimelines
Assert ([int]$timelines.ownerReady.creatorAttributedNoteCount -eq 2753 -and
    [int]$timelines.ownerReady.creatorAttributedTimingCount -eq 1 -and
    [int]$timelines.memberReady.creatorAttributedNoteCount -eq 2753 -and
    [int]$timelines.memberReady.creatorAttributedTimingCount -eq 1) (
    "The initialized room chart was not fully creator-attributed.")
Assert ([long]$timelines.memberHover.lastCreatorHoverUserId -eq 4202 -and
    [string]$timelines.memberHover.creatorHoverTooltip -ceq (
        "创建者  Avalonia 成员")) (
    "Member did not physically hover its own attributed Note.")
Assert ([long]$timelines.ownerMemberHover.lastCreatorHoverUserId -eq 4202 -and
    [string]$timelines.ownerMemberHover.creatorHoverTooltip -ceq (
        "创建者  Avalonia 成员")) (
    "Owner did not see the member creator tooltip.")
Assert ([long]$timelines.ownerOwnHover.lastCreatorHoverUserId -eq 4101 -and
    [string]$timelines.ownerOwnHover.creatorHoverTooltip -ceq (
        "创建者  Avalonia 房主")) (
    "Owner did not see the owner creator tooltip.")
Assert ($timelines.ownerPlayback.creatorMarkersPlaybackSuppressed -eq $true -and
    [long]$timelines.ownerPlayback.lastCreatorHoverUserId -eq 0 -and
    [string]$timelines.ownerPlayback.creatorHoverTooltip -ceq "none") (
    "Creator markers or hover state were not suppressed during playback.")
Assert ($timelines.ownerRestored.creatorMarkersPlaybackSuppressed -eq $false -and
    [long]$timelines.ownerRestored.lastCreatorHoverUserId -eq 4202 -and
    [string]$timelines.ownerRestored.creatorHoverTooltip -ceq (
        "创建者  Avalonia 成员")) (
    "Creator markers and hover did not restore after pausing.")

$controls = $gui.controls
Assert ([string]$controls.memberCreatorHoverStatus.name -ceq (
        "L1  ·  320:5/8  ·  创建者 Avalonia 成员") -and
    [string]$controls.ownerMemberCreatorHoverStatus.name -ceq (
        "L1  ·  320:5/8  ·  创建者 Avalonia 成员") -and
    [string]$controls.ownerOwnCreatorHoverStatus.name -ceq (
        "L3  ·  320:1/8  ·  创建者 Avalonia 房主")) (
    "WPF-compatible creator hover status text changed.")
Assert ([string]$controls.memberCreatorTooltip.rendering -ceq (
        "single-custom-timeline-overlay") -and
    $controls.memberCreatorTooltip.physicalPointerHit -eq $true -and
    $controls.ownerMemberCreatorTooltip.physicalPointerHit -eq $true -and
    $controls.ownerOwnCreatorTooltip.physicalPointerHit -eq $true) (
    "Creator tooltip did not stay inside the single custom timeline surface.")

$captures = @($gui.captures.PSObject.Properties)
Assert ($captures.Count -eq 8) "Expected eight declared GUI captures."
foreach ($captureProperty in $captures) {
    Assert ([int]$captureProperty.Value.width -eq 1980 -and
        [int]$captureProperty.Value.height -eq 1200 -and
        [int]$captureProperty.Value.sampledUniqueColors -ge 16) (
        "Unexpected or blank GUI capture: $($captureProperty.Name)")
}

$screenshotEvidence = @()
$screenshotProperties = @($gui.screenshots.PSObject.Properties)
Assert ($screenshotProperties.Count -eq 8) (
    "Expected eight declared GUI screenshots, got $($screenshotProperties.Count).")
foreach ($property in $screenshotProperties) {
    $name = [string]$property.Name
    Assert ($expectedScreenshotHashes.Contains($name)) (
        "Unexpected screenshot declaration: $name")
    $declared = $property.Value
    $full = [IO.Path]::GetFullPath([string]$declared.path)
    Assert ($full.StartsWith(
        (Join-Path $formalRoot "gui") + '\',
        [StringComparison]::OrdinalIgnoreCase)) (
        "Screenshot escaped formal GUI root: $full")
    $actual = File-Evidence $full
    Assert ($actual.sha256 -ceq [string]$declared.sha256) (
        "Screenshot hash differs from GUI evidence: $full")
    Assert ($actual.sha256 -ceq $expectedScreenshotHashes[$name]) (
        "Formal screenshot hash changed: $name")
    $screenshotEvidence += [ordered]@{
        name = $name
        file = $actual
    }
}

$fixture = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
Assert ($fixture.sha256 -ceq (
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E")) (
    "Frozen real MC hash changed.")
Assert ([string]$gui.hashes.fixtureBefore -ceq $fixture.sha256 -and
    [string]$gui.hashes.fixtureAfter -ceq $fixture.sha256) (
    "GUI run did not preserve the frozen real MC.")
$installer = File-Evidence (Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert ($installer.sha256 -ceq (
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4")) (
    "Frozen installer hash changed.")
$predecessor = File-Evidence (
    Join-Path $projectRoot (
        "artifacts\windows-avalonia-last-effect-memory-slice-20260727-r1\" +
        "verification-evidence.json"))
Assert ($predecessor.sha256 -ceq (
    "3D761D9EB9AAADE16E1AD39F125D535B0C755A3899E5E56AAAA8BE39B2F2BCAF")) (
    "Predecessor authority hash changed.")

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.online-creator-marker-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        windowsAvaloniaOnly = $true
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        formalAuthority = "online-creator-marker-r1"
    }
    builds = [ordered]@{
        warnings = 0
        errors = 0
        logs = $builds
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 446
            total = 446
            failed = 0
            focusedChecks = $focusedChecks
            evidence = File-Evidence $specsPath
            log = File-Evidence (Join-Path $formalRoot "tests\avalonia-specs-run.log")
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
        realChart = "Resound"
        noteCountBefore = 2753
        noteCountAfter = 2754
        physicalActionCount = 9
        screenshotCount = 8
        ownerCreatorUserId = 4101
        memberCreatorUserId = 4202
        remoteAvatarDownloadCount = 4
        playbackSuppressionPassed = $true
        pauseRestorationPassed = $true
        manualVisualReviewPassed = $true
        evidence = File-Evidence $guiPath
        screenshots = $screenshotEvidence
    }
    source = [ordered]@{
        changedFiles = @(
            "LumaChart.Avalonia\Editing\WindowsOnlineCreatorMarkerPolicy.cs",
            "LumaChart.Avalonia\Controls\TimelineSurface.cs",
            "LumaChart.Avalonia\MainWindow.cs",
            "LumaChart.Avalonia.Specs\WindowsOnlineCreatorMarkerSpecs.cs",
            "LumaChart.Avalonia.Specs\Program.cs",
            "tools\WindowsAvaloniaOnlineGuiServer\Program.cs",
            "tools\Capture-WindowsAvaloniaTwoClientOnlineGui.ps1",
            "tools\New-WindowsAvaloniaOnlineCreatorMarkerSliceEvidence.ps1")
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
File-Evidence $verificationPath | ConvertTo-Json -Depth 6
