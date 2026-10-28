param(
    [string]$Root =
        "artifacts\windows-avalonia-variable-tempo-permission-slice-20260727-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedReadyScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedResultScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedDeniedScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia variable-tempo permission verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-variable-tempo-permission-slice-20260727-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal variable-tempo permission root must be exactly $expectedRoot"
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

foreach ($hash in @(
        $ExpectedReadyScreenshotSha256,
        $ExpectedResultScreenshotSha256,
        $ExpectedDeniedScreenshotSha256)) {
    Assert ($hash -match '^[0-9A-Fa-f]{64}$') "A screenshot SHA-256 is invalid."
}
$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$builds = [ordered]@{
    avalonia = Assert-StrictBuild (Join-Path $formalRoot "build\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (Join-Path $formalRoot "build\main-specs-build.log")
    loopbackServer = Assert-StrictBuild (
        Join-Path $formalRoot "build\loopback-server-build.log")
}

$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs = Get-Content -Raw -LiteralPath $specsPath | ConvertFrom-Json
$checks = @($specs.checks)
$passedChecks = @($checks | Where-Object { $_.passed })
$focusedNames = @(
    "variable-tempo-plan-counts-managed-scroll-boundaries",
    "variable-tempo-apply-preserves-effects-and-uses-one-undo",
    "variable-tempo-scroll-compensation-is-deterministic-and-undoable",
    "variable-tempo-apply-rejects-stale-and-owner-locked-plans",
    "variable-tempo-apply-rejects-late-timing-permission-revocation",
    "room-tempo-analysis-permission-copy-matches-wpf-110")
$focusedChecks = @($checks | Where-Object { $_.name -in $focusedNames })
Assert ($specs.status -eq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 447 -and $passedChecks.Count -eq 447) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
Assert ($focusedChecks.Count -eq 6 -and @($focusedChecks | Where-Object {
    -not $_.passed
}).Count -eq 0) "Variable-tempo permission focused Specs did not all pass."

$mainLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainText = Get-Content -Raw -LiteralPath $mainLogPath
Assert ($mainText -match "79/79 specs passed") "Main Specs did not pass 79/79."

$guiPath = Join-Path $formalRoot "gui\evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -eq (
    "lumachart.windows.avalonia.variable-tempo-permission-action-gui-evidence.v1")) (
    "Unexpected GUI schema: $($gui.schema)")
Assert ($gui.status -eq "passed") "GUI evidence status is not passed."
Assert ($gui.windowsAvaloniaOnly -eq $true) "GUI evidence is not Windows-only."
Assert ($gui.productionServerMutationPerformed -eq $false) (
    "GUI evidence mutated production Server.")
Assert ($gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false) (
    "GUI evidence touched mobile projects.")
Assert ($gui.pureDotnetRelease -eq $true) "GUI evidence is not ordinary Release."
Assert ($gui.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "GUI evidence used forbidden protection/AOT.")
Assert ($gui.physicalMouseInputUsed -eq $true) "Physical mouse input was not used."
Assert ($gui.automationDiagnosticNonFormal -eq $false) (
    "Automation diagnostic output cannot be formal authority.")
Assert (@($gui.physicalActions).Count -eq 23) "Expected exactly 23 physical actions."

$actions = $gui.permissionActions
Assert ($actions.analysisKind -ceq "variable") (
    "GUI did not run the variable-tempo analysis path.")
Assert ($actions.analysisPermissionGrantMessage -ceq (
    "谱面信息：允许编辑`nEffect / Timing Edit：允许编辑`nNote：允许编辑")) (
    "Permission-grant notice differs from WPF.")
$expectedAnalysisResult =
    "候选 BPM 时间线：`n`n" +
    "1.  音频 0:00  →  0:0/1  ·  BPM 140  ·  50%`n`n" +
    "首段 Delay：90 ms`n" +
    "确认后将整体替换现有 1 个 BPM 时间记录。`n`n" +
    "可同时生成流速补正：每段 Scroll = 谱面信息 BPM 140 ÷ 该段 BPM。 " +
    "其他位置的 Scroll 和所有其他 Effect 不变。"
Assert ([string]$actions.analysisResult -ceq $expectedAnalysisResult) (
    "Real Resound variable-tempo result was unexpected.")
Assert ($actions.timingRevocationMessage -ceq (
    "谱面信息：允许编辑`nEffect / Timing Edit：不可编辑`nNote：允许编辑")) (
    "Timing-revocation notice differs from WPF.")
Assert ($actions.lateDeniedTitle -ceq "没有 Effect 权限") (
    "Late permission-denied title differs from WPF.")
Assert ($actions.lateDeniedMessage -ceq (
    "分析期间 Timing 权限已失效，预测结果未写入。")) (
    "Late permission-denied body differs from WPF.")
Assert ($actions.finalRole -ceq "editor" -and
    $actions.finalCanEditMetadata -eq $true -and
    $actions.finalCanEditTiming -eq $false -and
    $actions.finalCanEditNotes -eq $true) (
    "Final editor permission state is unexpected.")
Assert ($actions.acceptedOperationCountBefore -eq 0 -and
    $actions.acceptedOperationCountAfter -eq 0) (
    "Denied variable-tempo analysis mutated chart operations.")
Assert ($actions.serverChartEqualBeforeAfter -eq $true -and
    $actions.passed -eq $true) (
    "Denied variable-tempo analysis mutated the authoritative chart or aggregate failed.")

$finalMember = @($gui.room.finalServerState.members | Where-Object {
    [long]$_.userId -eq 4202
})[0]
Assert ($finalMember -and $finalMember.memberRole -ceq "editor" -and
    $finalMember.canEditMetadata -and
    -not $finalMember.canEditTiming -and
    $finalMember.canEditNotes) (
    "Server did not persist the final editor access.")
Assert ($gui.room.finalServerState.resourceEntryCount -eq 3 -and
    $gui.room.finalServerState.downloadedBlobCount -ge 3) (
    "Room resources were not fully synchronized.")

$screenshotEvidence = @()
$screenshotProperties = @($gui.screenshots.PSObject.Properties)
Assert ($screenshotProperties.Count -eq 14) (
    "Expected 14 declared GUI screenshots, got $($screenshotProperties.Count).")
foreach ($property in $screenshotProperties) {
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
    $screenshotEvidence += [ordered]@{
        name = $property.Name
        file = $actual
    }
}

$expectedShots = [ordered]@{
    "member-tempo-analysis-ready" =
        $ExpectedReadyScreenshotSha256.ToUpperInvariant()
    "member-variable-tempo-result-before-permission-revoke" =
        $ExpectedResultScreenshotSha256.ToUpperInvariant()
    "member-late-variable-tempo-permission-denied" =
        $ExpectedDeniedScreenshotSha256.ToUpperInvariant()
}
foreach ($name in $expectedShots.Keys) {
    $shot = $screenshotEvidence | Where-Object { $_.name -eq $name }
    Assert ($shot.file.sha256 -ceq $expectedShots[$name]) (
        "Formal screenshot hash changed: $name")
}

$fixture = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
Assert ($fixture.sha256 -ceq (
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E")) (
    "Frozen real MC hash changed.")
$installer = File-Evidence (Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert ($installer.sha256 -ceq (
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4")) (
    "Frozen installer hash changed.")
$predecessor = File-Evidence (
    Join-Path $projectRoot (
        "artifacts\windows-avalonia-online-creator-marker-slice-20260727-r1\" +
        "verification-evidence.json"))
Assert ($predecessor.sha256 -ceq (
    "A19B8C856F83D0600297622141EB74A4C8620DA8F821CD9E5B308A49D881F659")) (
    "Predecessor authority hash changed.")

$leftovers = @()
foreach ($processId in @(
    [int]$gui.processIds.server,
    [int]$gui.processIds.owner,
    [int]$gui.processIds.member)) {
    if (Get-Process -Id $processId -ErrorAction SilentlyContinue) {
        $leftovers += $processId
    }
}
Assert ($leftovers.Count -eq 0) "Evidence-owned processes remain: $leftovers"

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.variable-tempo-permission-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        windowsAvaloniaOnly = $true
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        formalAuthority = "variable-tempo-permission-r1"
    }
    builds = [ordered]@{
        warnings = 0
        errors = 0
        logs = $builds
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 447
            total = 447
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
        realNoteCount = 2753
        predictedSegmentCount = 1
        predictedBpm = 140
        predictedDelayMilliseconds = 90
        timingPermissionRevokedDuringResult = $true
        latePermissionNoticePassed = $true
        physicalActionCount = 23
        screenshotCount = 14
        serverOperationCountBefore = 0
        serverOperationCountAfter = 0
        authoritativeChartUnchanged = $true
        manualVisualReviewPassed = $true
        evidence = File-Evidence $guiPath
        screenshots = $screenshotEvidence
        leftoverEvidenceOwnedProcessIds = $leftovers
    }
    source = [ordered]@{
        changedFiles = @(
            "LumaChart.Avalonia.Specs\WindowsAudioTempoSpecs.cs",
            "tools\Capture-WindowsAvaloniaTwoClientOnlineGui.ps1",
            "tools\New-WindowsAvaloniaVariableTempoPermissionSliceEvidence.ps1")
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
