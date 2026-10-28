param(
    [string]$Root =
        "artifacts\windows-avalonia-online-room-note-sound-loopback-slice-20260728-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedBeforePlaybackScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedAfterTriggerScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia online room Note Sound verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-online-room-note-sound-loopback-slice-20260728-r1"))).TrimEnd('\')
$formalRoot = if ([IO.Path]::IsPathRooted($Root)) {
    [IO.Path]::GetFullPath($Root).TrimEnd('\')
}
else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
}
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal online room Note Sound root must be exactly $expectedRoot"
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

foreach ($hash in @(
        $ExpectedBeforePlaybackScreenshotSha256,
        $ExpectedAfterTriggerScreenshotSha256)) {
    Assert ($hash -match '^[0-9A-Fa-f]{64}$') (
        "A screenshot SHA-256 is invalid.")
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
    audioLoopbackProbe =
        Assert-StrictBuild (Join-Path $formalRoot "build\build-audio_probe.log")
    onlineGuiServer =
        Assert-StrictBuild (Join-Path $formalRoot "build\build-online_gui_server.log")
}

$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs = Get-Content -Raw -LiteralPath $specsPath | ConvertFrom-Json
$checks = @($specs.checks)
$passedChecks = @($checks | Where-Object passed)
$focusedSpecs = @(
    "windows-key-sound-preload-paths-are-existing-custom-files-only-and-deduplicated",
    "windows-key-sound-valid-shared-lease-completes-on-single-scheduler-owner",
    "online-frozen-note-sound-verifies-length-and-sha-before-assignment",
    "windows-room-sync-http-ack-loss-sse-reconnect-and-delta-recovery-converge"
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
Assert ($gui.schema -eq (
    "lumachart.windows.avalonia.online-room-note-sound-loopback-gui-evidence.v2")) (
    "Unexpected GUI schema: $($gui.schema)")
Assert ($gui.status -eq "passed-migration-incomplete" -and
    $gui.formalMigrationAuthority -eq $true) (
    "GUI evidence is not a passed formal migration authority.")
Assert ($gui.windowsAvaloniaOnly -eq $true) "GUI evidence is not Windows-only."
Assert ($gui.productionServerMutationPerformed -eq $false) (
    "GUI evidence mutated production Server.")
Assert ($gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false) (
    "GUI evidence touched mobile projects.")
Assert ($gui.pureDotnetRelease -eq $true) "GUI evidence is not ordinary Release."
Assert ($gui.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "GUI evidence used forbidden protection/AOT.")
Assert ($gui.physicalMouseInputUsed -eq $true -and
    $gui.enterKeyUsed -eq $false) (
    "GUI evidence did not preserve the declared physical-input/IME boundary.")

$expectedMcSha =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$expectedSoundSha =
    "00AA7780330A022D7F5D0C4C2BEA23625D31F48BA8CAC2AF25117249BEA05151"
$expectedRoomSoundSha =
    "C0D0F473C26A4FC626C8BE503333DDAC124C2CB5D06D7191A0A5015563B81381"
$expectedInstallerSha =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
$fixtureMc = File-Evidence (
    "D:\osu!\Songs\Resound\0\1781536331.mc")
$fixtureSound = File-Evidence (
    "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg")
$installer = File-Evidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert ($fixtureMc.sha256 -ceq $expectedMcSha) "Real Resound MC fixture changed."
Assert ($fixtureSound.sha256 -ceq $expectedSoundSha) (
    "Real Resound OGG fixture changed.")
Assert ($installer.sha256 -ceq $expectedInstallerSha) (
    "Frozen WPF installer changed.")
Assert ([string]$gui.hashes.fixtureBefore.sha256 -ceq $expectedMcSha -and
    [string]$gui.hashes.fixtureAfter.sha256 -ceq $expectedMcSha) (
    "GUI did not preserve the real MC fixture.")
$roomSoundSha = [string]$gui.hashes.frozenSoundBefore.sha256
Assert (-not [string]::IsNullOrWhiteSpace($roomSoundSha) -and
    $roomSoundSha -ceq $expectedRoomSoundSha -and
    [long]$gui.hashes.frozenSoundBefore.length -ge 50000 -and
    [string]$gui.hashes.frozenSoundAfter.sha256 -ceq $roomSoundSha -and
    [string]$gui.hashes.memberMaterializedSoundSha256 -ceq $roomSoundSha) (
    "Source and member-materialized room Note Sound hashes differ.")
Assert ([string]$gui.hashes.releasedInstallerBefore.sha256 -ceq
        $expectedInstallerSha -and
    [string]$gui.hashes.releasedInstallerAfter.sha256 -ceq
        $expectedInstallerSha) (
    "GUI run did not preserve the frozen WPF installer.")

Assert ($gui.room.private -eq $true -and
    $gui.room.hidden -eq $true -and
    $gui.room.invitationAction -ceq "join" -and
    $gui.room.resourcesReady -eq $true) (
    "The room was not the required hidden invitation resource-ready room.")
Assert ([int]$gui.room.acceptedOperationCountAfter -eq
        [int]$gui.room.acceptedOperationCountBefore + 1) (
    "The room did not accept exactly one Note Sound assignment operation.")
Assert ($gui.noteSound.nonSoundFieldsPreserved -eq $true -and
    $gui.noteSound.sound -ceq "LumaChart-room-note-key-sound.wav" -and
    [string]$gui.noteSound.sourceSha256 -ceq $roomSoundSha -and
    [string]$gui.noteSound.materializedSha256 -ceq $roomSoundSha) (
    "The exact room Note Sound assignment was not preserved.")
Assert ([string]$gui.noteSound.targetAfter.sound -ceq
        "LumaChart-room-note-key-sound.wav") (
    "The authoritative Note no longer references the synchronized room sample.")

Assert ([double]$gui.audio.musicVolumeAfter.value -le .001 -and
    [int]$gui.audio.wheelSnapDivision -eq 24 -and
    $gui.audio.redLineStartedBeforeTarget -eq $true -and
    $gui.audio.songMutedWhileOverlayRemainedAudible -eq $true) (
    "The playback run did not isolate the room Note Sound from chart music.")
Assert ([int]$gui.runtime.triggerAcceptedDelta -ge 1 -and
    [int]$gui.runtime.sharedAcceptedDelta -ge 1 -and
    [int]$gui.runtime.standaloneAcceptedDelta -eq 0 -and
    $gui.runtime.diagnosticRefreshOccurredAfterLoopbackClosed -eq $true) (
    "The room Note Sound did not use the accepted shared playback path.")

$probe = $gui.loopback.probe
Assert ($probe.status -ceq "captured" -and
    $probe.captureScope -ceq "process-tree" -and
    [int]$probe.targetProcessId -eq [int]$gui.processIds.member -and
    [long]$probe.capture.bytes -gt 0 -and
    $probe.capture.timelineIncludesInsertedSilence -eq $true) (
    "The probe did not capture the member process tree.")
Assert ([int]$probe.format.sampleRate -eq 44100 -and
    [int]$probe.format.channels -eq 2 -and
    [int]$probe.format.bitsPerSample -eq 16 -and
    $probe.format.encoding -ceq "Pcm") (
    "The process loopback format changed.")
$analysis = $probe.analysis
Assert ([int]$analysis.detectedPulseCount -ge 1 -and
    [double]$analysis.peak -ge .005 -and
    [double]$analysis.signalToNoiseDb -ge 20 -and
    [int]$analysis.configuredReferenceFrameCount -ge 1000 -and
    [double]$analysis.bestConfiguredReferenceCorrelation -ge .12 -and
    [double]$analysis.bestConfiguredReferenceSpectralSimilarity -ge .24) (
    "The waveform does not prove the materialized room Note Sound.")
Assert ($gui.loopback.configuredReferenceIsMaterializedRoomNoteSound -eq $true -and
    [double]$gui.loopback.strongestPulseFromPlaybackMilliseconds -ge -120 -and
    [double]$gui.loopback.strongestPulseFromPlaybackMilliseconds -le 1600) (
    "The strongest room-sample-correlated pulse was not aligned with playback.")

$expectedScreenshotHashes = [ordered]@{
    "member-key-sound-before-playback" =
        $ExpectedBeforePlaybackScreenshotSha256.ToUpperInvariant()
    "member-key-sound-after-trigger" =
        $ExpectedAfterTriggerScreenshotSha256.ToUpperInvariant()
}
$screenshotEvidence = [ordered]@{}
foreach ($property in @($gui.screenshots.PSObject.Properties)) {
    $name = $property.Name
    $declared = $property.Value
    $full = [IO.Path]::GetFullPath([string]$declared.path)
    Assert ($full.StartsWith(
        (Join-Path $formalRoot "gui") + '\',
        [StringComparison]::OrdinalIgnoreCase)) (
        "Screenshot escaped formal GUI root: $full")
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
Assert ($screenshotEvidence.Count -ge 2) (
    "Expected at least the two target formal screenshots.")

$wavePath = [IO.Path]::GetFullPath([string]$gui.paths.probeWave)
$wave = File-Evidence $wavePath
Assert ($wave.sha256 -ceq [string]$gui.hashes.probeWaveSha256) (
    "Loopback WAV hash differs from GUI evidence.")
$guiEvidence = File-Evidence $guiPath
$specsEvidence = File-Evidence $specsPath
$mainSpecsEvidence = File-Evidence $mainSpecsPath
$changedFiles = @(
    "LumaChart.Avalonia\LumaChart.Avalonia.csproj",
    "LumaChart.Avalonia\Controls\TimelineSurface.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsAppUpdatePolicy.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsExternalUriPolicy.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "LumaChart.Avalonia.Specs\WindowsAppUpdatePolicySpecs.cs",
    "LumaChart.Avalonia.Specs\WindowsAvaloniaInstallerSpecs.cs",
    "LumaChart.Avalonia.Specs\WindowsRoomSyncResilienceSpecs.cs",
    "installer\LumaChartAvaloniaPreview.iss",
    "tools\WindowsAudioLoopbackProbe\WindowsAudioLoopbackProbe.csproj",
    "tools\WindowsAudioLoopbackProbe\Program.cs",
    "tools\WindowsAudioLoopbackProbe\ProcessLoopbackCapture.cs",
    "tools\Capture-WindowsAvaloniaTwoClientOnlineGui.ps1",
    "tools\Build-WindowsAvaloniaPreviewInstaller.ps1",
    "tools\New-WindowsAvaloniaOnlineRoomNoteSoundLoopbackSliceEvidence.ps1",
    "tools\Test-WindowsAvaloniaPreviewInstaller.ps1"
) | ForEach-Object { File-Evidence (Join-Path $projectRoot $_) }

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.online-room-note-sound-loopback-slice-verification.v1"
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
        hiddenInvitation = $true
        exactRoomNoteSoundMaterialized = $true
        immutableRealOggPreserved = $true
        noteNonSoundFieldsPreserved = $true
    }
    audio = [ordered]@{
        wave = $wave
        captureScope = [string]$probe.captureScope
        targetProcessId = [int]$probe.targetProcessId
        targetProcessWasMember = $true
        analysis = $analysis
        strongestPulseFromPlaybackMilliseconds =
            [double]$gui.loopback.strongestPulseFromPlaybackMilliseconds
    }
    immutableInputs = [ordered]@{
        realMc = $fixtureMc
        realOgg = $fixtureSound
        frozenInstaller = $installer
    }
    changedFiles = $changedFiles
    remainingDifferences = @(
        "主功能优先；像素级 UI、布局和快捷操作差异按用户要求后置并由用户后续人工反馈。",
        "真实网卡离线、客户端重启、Server 重启和剩余权限竞态仍需继续闭合。",
        "SingleChart、RatePack、osu rate-mode、WPF/Malody/osu! 实开与格式失败矩阵仍开放。",
        "普通 ClientSecurity、真实更新包下载/验证/升级回滚、安装和卸载尚未全部通过。",
        "物理 60/120 Hz、真 4K、display Present、端到端输入及同机 WPF A/B 性能终门禁仍开放。",
        "用户尚未人工确认 Avalonia Windows 版可替代 WPF。"
    )
}
$verification | ConvertTo-Json -Depth 70 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
Write-Output (
    "Windows Avalonia online room Note Sound loopback slice verification: " +
    "passed-migration-incomplete")
Write-Output "Evidence: $verificationPath"
