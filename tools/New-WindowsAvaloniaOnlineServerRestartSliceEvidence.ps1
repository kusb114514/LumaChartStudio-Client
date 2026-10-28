param(
    [string]$Root =
        "artifacts\windows-avalonia-online-server-restart-slice-20260728-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedMemberOutageScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedOwnerOutageScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedMemberRecoveredScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedOwnerRecoveredScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia online Server-restart verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-online-server-restart-slice-20260728-r1"))).TrimEnd('\')
$formalRoot = if ([IO.Path]::IsPathRooted($Root)) {
    [IO.Path]::GetFullPath($Root).TrimEnd('\')
}
else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
}
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal online Server-restart root must be exactly $expectedRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "Missing file: $full"
    $item = Get-Item -LiteralPath $full
    [ordered]@{
        path = if ($full.StartsWith(
                $projectRoot + '\',
                [StringComparison]::OrdinalIgnoreCase)) {
            [IO.Path]::GetRelativePath($projectRoot, $full)
        }
        else {
            $full
        }
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -Raw -LiteralPath $Path
    Assert ($text -match "0 个警告|0 Warning") (
        "Strict build log lacks zero-warning result: $Path")
    Assert ($text -match "0 个错误|0 Error") (
        "Strict build log lacks zero-error result: $Path")
    File-Evidence $Path
}

function Assert-InsideFormalGui([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    $guiRoot = [IO.Path]::GetFullPath((Join-Path $formalRoot "gui")).TrimEnd('\')
    Assert ($full.StartsWith(
        $guiRoot + '\',
        [StringComparison]::OrdinalIgnoreCase)) (
        "$Label escaped the formal GUI root: $full")
    $full
}

function Parse-Beat([string]$Beat, [string]$Label) {
    $match = [regex]::Match($Beat, '^(?<bar>-?\d+):(?<num>-?\d+)/(?<den>\d+)$')
    Assert $match.Success "$Label is not an exact rational Beat: $Beat"
    [ordered]@{
        text = $Beat
        bar = [int]$match.Groups["bar"].Value
        numerator = [int]$match.Groups["num"].Value
        denominator = [int]$match.Groups["den"].Value
    }
}

function Test-SavedCompactMc(
    [string]$Path,
    [object]$OwnerBeat,
    [int]$OwnerLane,
    [object]$MemberBeat,
    [int]$MemberLane,
    [string]$Label) {
    $full = Assert-InsideFormalGui $Path "$Label saved MC"
    $raw = Get-Content -Raw -LiteralPath $full
    Assert (-not [string]::IsNullOrWhiteSpace($raw)) "$Label saved MC is empty."
    Assert (@($raw -split '\r?\n' | Where-Object { $_.Length -gt 0 }).Count -eq 1) (
        "$Label saved MC is not the compact one-line game-compatible export.")
    $document = $raw | ConvertFrom-Json
    $playable = @($document.note | Where-Object { $null -ne $_.column })
    Assert ($playable.Count -eq 2755) (
        "$Label saved MC playable Note count is $($playable.Count), expected 2755.")
    $ownerMatches = @($playable | Where-Object {
        [int]$_.column -eq $OwnerLane -and
        [int]$_.beat[0] -eq [int]$OwnerBeat.bar -and
        [int]$_.beat[1] -eq [int]$OwnerBeat.numerator -and
        [int]$_.beat[2] -eq [int]$OwnerBeat.denominator
    })
    $memberMatches = @($playable | Where-Object {
        [int]$_.column -eq $MemberLane -and
        [int]$_.beat[0] -eq [int]$MemberBeat.bar -and
        [int]$_.beat[1] -eq [int]$MemberBeat.numerator -and
        [int]$_.beat[2] -eq [int]$MemberBeat.denominator
    })
    Assert ($ownerMatches.Count -eq 1 -and $memberMatches.Count -eq 1) (
        "$Label saved MC did not contain both exact offline Notes exactly once.")
    [ordered]@{
        file = File-Evidence $full
        playableNoteCount = $playable.Count
        ownerExactNoteMatches = $ownerMatches.Count
        memberExactNoteMatches = $memberMatches.Count
        compactOneLine = $true
    }
}

foreach ($hash in @(
        $ExpectedMemberOutageScreenshotSha256,
        $ExpectedOwnerOutageScreenshotSha256,
        $ExpectedMemberRecoveredScreenshotSha256,
        $ExpectedOwnerRecoveredScreenshotSha256)) {
    Assert ($hash -match '^[0-9A-Fa-f]{64}$') "A screenshot SHA-256 is invalid."
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$builds = [ordered]@{
    avalonia =
        Assert-StrictBuild (Join-Path $formalRoot "build\build-avalonia.log")
    avaloniaSpecs =
        Assert-StrictBuild (Join-Path $formalRoot "build\build-avalonia_specs.log")
    mainSpecs =
        Assert-StrictBuild (Join-Path $formalRoot "build\build-main_specs.log")
    onlineGuiServer =
        Assert-StrictBuild (Join-Path $formalRoot "build\build-online_gui_server.log")
}

$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs = Get-Content -Raw -LiteralPath $specsPath | ConvertFrom-Json
$checks = @($specs.checks)
$passedChecks = @($checks | Where-Object passed)
$focusedSpecs = @(
    "windows-room-sync-http-ack-loss-sse-reconnect-and-delta-recovery-converge",
    "timeline-uia-exposes-live-current-beat-scale-and-exact-selected-note"
)
Assert ($specs.status -eq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 518 -and $passedChecks.Count -eq 518) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
$focusedChecks = @(
    foreach ($name in $focusedSpecs) {
        $match = @($checks | Where-Object name -eq $name)
        Assert ($match.Count -eq 1 -and $match[0].passed) (
            "Focused Avalonia Spec did not pass: $name")
        $match[0]
    }
)

$mainSpecsPath = Join-Path $formalRoot "tests\main-specs.log"
$mainSpecsText = Get-Content -Raw -LiteralPath $mainSpecsPath
Assert ($mainSpecsText -match "79/79 specs passed") (
    "Main Specs did not pass 79/79.")

$guiPath = Join-Path $formalRoot "gui\evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -ceq (
    "lumachart.windows.avalonia.two-client-server-restart-gui-evidence.v1")) (
    "Unexpected GUI schema: $($gui.schema)")
Assert ($gui.status -ceq "passed-migration-incomplete" -and
    $gui.formalMigrationAuthority -eq $true -and
    $gui.passed -eq $true) (
    "GUI evidence is not a passed formal migration authority.")
Assert ($gui.windowsAvaloniaOnly -eq $true) "GUI evidence is not Windows-only."
Assert ($gui.productionServerMutationPerformed -eq $false) (
    "GUI evidence mutated production Server.")
Assert ($gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false) (
    "GUI evidence touched mobile projects.")
Assert ($gui.pureDotnetRelease -eq $true) "GUI evidence is not ordinary Release."
Assert ($gui.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "GUI evidence used forbidden protection/AOT.")
Assert ($gui.serverRestartOnly -eq $true -and
    $gui.physicalMouseInputUsed -eq $true -and
    $gui.enterKeyUsed -eq $false) (
    "GUI evidence did not preserve the focused physical-input/IME boundary.")
Assert ([string]$gui.endpoint -like "http://127.0.0.1:*") (
    "The GUI Server endpoint was not loopback-only.")

$restart = $gui.processRestart
Assert ([int]$restart.firstProcessId -gt 0 -and
    [int]$restart.secondProcessId -gt 0 -and
    [int]$restart.firstProcessId -ne [int]$restart.secondProcessId -and
    $restart.distinctProcessIds -eq $true -and
    $restart.sameEndpoint -eq $true) (
    "The Server was not restarted as a distinct process on the same endpoint.")
Assert ([int]$restart.processGeneration -eq 2 -and
    $restart.restoredFromCheckpoint -eq $true) (
    "The second Server process did not restore generation 2 from checkpoint.")
Assert ([double]$restart.downtimeMilliseconds -gt 0 -and
    [double]$restart.downtimeMilliseconds -lt 60000) (
    "Server downtime was missing or exceeded the 60-second focused gate.")
Assert ([long]$restart.checkpointLengthBeforeRestart -gt 1000000 -and
    [string]$restart.checkpointSha256BeforeRestart -match '^[0-9A-F]{64}$') (
    "The pre-restart full room checkpoint was not recorded.")

Assert ([int]$gui.baseline.noteCount -eq 2753 -and
    [long]$gui.baseline.revision -eq 1) (
    "The real-room baseline was not 2,753 Notes at revision 1.")
$memberBeat = Parse-Beat ([string]$gui.offlineEdits.member.beat) "Member offline Beat"
$ownerBeat = Parse-Beat ([string]$gui.offlineEdits.owner.beat) "Owner offline Beat"
Assert ([int]$memberBeat.denominator -eq 24 -and
    [int]$ownerBeat.denominator -eq 24 -and
    [int]$gui.offlineEdits.exactDenominator -eq 24) (
    "Offline edits did not retain the selected exact denominator 24.")
Assert ($memberBeat.text -cne $ownerBeat.text -and
    [string]$gui.offlineEdits.member.noteId -cne
        [string]$gui.offlineEdits.owner.noteId) (
    "The two clients did not create distinct offline Notes.")
$memberOperationId = [Guid]::Empty
$ownerOperationId = [Guid]::Empty
Assert ([Guid]::TryParse(
        [string]$gui.offlineEdits.member.pendingOperationId,
        [ref]$memberOperationId) -and
    $memberOperationId -ne [Guid]::Empty) (
    "Member pending operation id was not a non-empty GUID.")
Assert ([Guid]::TryParse(
        [string]$gui.offlineEdits.owner.pendingOperationId,
        [ref]$ownerOperationId) -and
    $ownerOperationId -ne [Guid]::Empty) (
    "Owner pending operation id was not a non-empty GUID.")
Assert ($memberOperationId -ne $ownerOperationId -and
    $gui.offlineEdits.distinctOperationIds -eq $true) (
    "The two offline edits reused one operation id.")
foreach ($offline in @($gui.offlineEdits.member, $gui.offlineEdits.owner)) {
    Assert ([int]$offline.workFailuresBeforeRestart -ge 1 -and
        [string]$offline.workStatusBeforeRestart -ceq "BackingOff") (
        "A client did not visibly retain a pending operation while Server was down.")
}

$recovery = $gui.recovery
Assert ([long]$recovery.revision -eq 3 -and
    [int]$recovery.noteCount -eq 2755) (
    "Recovered room did not converge to revision 3 with 2,755 Notes.")
Assert ([string]$recovery.ownerRecoveredBeat -ceq $ownerBeat.text -and
    [string]$recovery.memberRecoveredBeat -ceq $memberBeat.text) (
    "Recovered authoritative Beats differ from the offline exact Beats.")
$ownerAttempts = @($recovery.ownerOperationAttempts)
$memberAttempts = @($recovery.memberOperationAttempts)
Assert ($ownerAttempts.Count -eq 1 -and
    $memberAttempts.Count -eq 1 -and
    [string]$ownerAttempts[0].operationId -ceq $ownerOperationId.ToString("D") -and
    [string]$memberAttempts[0].operationId -ceq $memberOperationId.ToString("D")) (
    "Each offline operation did not arrive exactly once after restart.")
Assert ([int]$recovery.ownerAcceptedCount -eq 1 -and
    [int]$recovery.memberAcceptedCount -eq 1 -and
    $recovery.exactlyOnce -eq $true) (
    "Each offline operation was not committed exactly once.")
Assert ($recovery.ownerSelectedMemberRemoteNote -eq $true -and
    $recovery.memberSelectedOwnerRemoteNote -eq $true) (
    "Both live clients did not physically select the other client's recovered Note.")

Assert ([int]$gui.savedCompatibility.ownerPlayableNoteCount -eq 2755 -and
    [int]$gui.savedCompatibility.memberPlayableNoteCount -eq 2755 -and
    $gui.savedCompatibility.ownerContainsBothExactNotes -eq $true -and
    $gui.savedCompatibility.memberContainsBothExactNotes -eq $true) (
    "GUI saved-compatibility assertions were incomplete.")
$ownerSaved = Test-SavedCompactMc `
    ([string]$gui.paths.ownerSavedChart) `
    $ownerBeat ([int]$gui.offlineEdits.owner.lane) `
    $memberBeat ([int]$gui.offlineEdits.member.lane) "Owner"
$memberSaved = Test-SavedCompactMc `
    ([string]$gui.paths.memberSavedChart) `
    $ownerBeat ([int]$gui.offlineEdits.owner.lane) `
    $memberBeat ([int]$gui.offlineEdits.member.lane) "Member"
Assert ($ownerSaved.file.sha256 -ceq $memberSaved.file.sha256 -and
    [string]$gui.hashes.ownerChartAfter -ceq $ownerSaved.file.sha256 -and
    [string]$gui.hashes.memberChartAfter -ceq $memberSaved.file.sha256) (
    "Owner/member compact MC outputs did not converge byte-for-byte.")

$checkpointPath = Assert-InsideFormalGui ([string]$gui.paths.checkpoint) "Checkpoint"
$checkpoint = File-Evidence $checkpointPath
$expectedMcSha =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$expectedInstallerSha =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
$fixture = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
$installer = File-Evidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert ($fixture.sha256 -ceq $expectedMcSha -and
    [string]$gui.hashes.fixtureBefore -ceq $expectedMcSha -and
    [string]$gui.hashes.fixtureAfter -ceq $expectedMcSha) (
    "The frozen real Resound MC changed.")
Assert ($installer.sha256 -ceq $expectedInstallerSha) (
    "The frozen WPF installer changed.")

$expectedScreenshotHashes = [ordered]@{
    "member-server-outage-local-edit" =
        $ExpectedMemberOutageScreenshotSha256.ToUpperInvariant()
    "owner-server-outage-local-edit" =
        $ExpectedOwnerOutageScreenshotSha256.ToUpperInvariant()
    "member-server-restart-recovered" =
        $ExpectedMemberRecoveredScreenshotSha256.ToUpperInvariant()
    "owner-server-restart-recovered" =
        $ExpectedOwnerRecoveredScreenshotSha256.ToUpperInvariant()
}
$screenshotEvidence = [ordered]@{}
foreach ($property in @($gui.screenshots.PSObject.Properties)) {
    $name = $property.Name
    $declared = $property.Value
    $full = Assert-InsideFormalGui ([string]$declared.path) "Screenshot"
    $actual = File-Evidence $full
    Assert ($actual.length -eq [long]$declared.length -and
        $actual.sha256 -ceq [string]$declared.sha256) (
        "Screenshot evidence changed: $name")
    if ($expectedScreenshotHashes.Contains($name)) {
        Assert ($actual.sha256 -ceq [string]$expectedScreenshotHashes[$name]) (
            "Visually approved screenshot changed: $name")
    }
    $screenshotEvidence[$name] = $actual
}
foreach ($name in @($expectedScreenshotHashes.Keys)) {
    Assert ($screenshotEvidence.Contains($name)) (
        "Missing visually approved target screenshot: $name")
}
Assert ($screenshotEvidence.Count -ge 7) (
    "Expected all seven focused GUI screenshots.")
Assert (@($gui.physicalActions).Count -ge 20) (
    "The focused run did not record the full physical action sequence.")

$guiEvidence = File-Evidence $guiPath
$specsEvidence = File-Evidence $specsPath
$mainSpecsEvidence = File-Evidence $mainSpecsPath
$changedFiles = @(
    "LumaChart.Avalonia\Controls\TimelineSurface.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\WindowsInspectorParitySpecs.cs",
    "tools\WindowsAvaloniaOnlineGuiServer\Program.cs",
    "tools\Capture-WindowsAvaloniaTwoClientOnlineGui.ps1",
    "tools\New-WindowsAvaloniaOnlineServerRestartSliceEvidence.ps1"
) | ForEach-Object { File-Evidence (Join-Path $projectRoot $_) }

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.online-server-restart-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    windowsAvaloniaOnly = $true
    windowsAvaloniaCanReplaceWpf = $false
    userReplacementApprovalReceived = $false
    nextPlatformAuthorized = $false
    productionServerDeploymentPerformed = $false
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    priority = "main-functions-first-ui-parity-deferred-by-user"
    builds = $builds
    tests = [ordered]@{
        avaloniaSpecs = $specsEvidence
        avaloniaSpecsPassed = 518
        avaloniaSpecsTotal = 518
        focused = $focusedChecks
        mainSpecs = $mainSpecsEvidence
        mainSpecsPassed = 79
        mainSpecsTotal = 79
    }
    gui = [ordered]@{
        evidence = $guiEvidence
        screenshots = $screenshotEvidence
        physicalMouseInputUsed = $true
        enterKeyUsed = $false
        firstServerProcessId = [int]$restart.firstProcessId
        secondServerProcessId = [int]$restart.secondProcessId
        sameEndpoint = $true
        checkpoint = $checkpoint
        downtimeMilliseconds = [double]$restart.downtimeMilliseconds
        exactOfflineBeats = @($memberBeat, $ownerBeat)
        ownerSavedMc = $ownerSaved
        memberSavedMc = $memberSaved
        exactlyOnceRecovery = $true
    }
    immutableInputs = [ordered]@{
        realMc = $fixture
        frozenInstaller = $installer
    }
    changedFiles = $changedFiles
    remainingDifferences = @(
        "主功能优先；像素级 UI、布局和快捷操作差异按用户要求后置并由用户后续人工反馈。",
        "SingleChart、RatePack、osu rate-mode、WPF/Malody/osu! 实开与格式失败矩阵仍需继续闭合。",
        "普通 ClientSecurity、真实更新包下载/验证/升级回滚、安装和卸载尚未全部通过。",
        "物理 60/120 Hz、真 4K、display Present、端到端输入及同机 WPF A/B 性能终门禁仍开放。",
        "用户尚未人工确认 Avalonia Windows 版可替代 WPF。"
    )
}
$verification | ConvertTo-Json -Depth 70 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
Write-Output (
    "Windows Avalonia online Server-restart slice verification: " +
    "passed-migration-incomplete")
Write-Output "Evidence: $verificationPath"
