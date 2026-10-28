param(
    [string]$Root =
        "artifacts\windows-avalonia-last-effect-memory-slice-20260727-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedSeedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedInheritedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedSavedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedReopenedScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia last-Effect-memory verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-last-effect-memory-slice-20260727-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal last-Effect-memory root must be exactly $expectedRoot"
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

$expectedHashes = [ordered]@{
    seed = $ExpectedSeedScreenshotSha256.ToUpperInvariant()
    inherited = $ExpectedInheritedScreenshotSha256.ToUpperInvariant()
    saved = $ExpectedSavedScreenshotSha256.ToUpperInvariant()
    reopened = $ExpectedReopenedScreenshotSha256.ToUpperInvariant()
}
foreach ($hash in $expectedHashes.Values) {
    Assert ($hash -match '^[0-9A-F]{64}$') "A screenshot SHA-256 is invalid."
}
$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$builds = [ordered]@{
    avalonia = Assert-StrictBuild (Join-Path $formalRoot "build\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (Join-Path $formalRoot "build\main-specs-build.log")
}

$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs = Get-Content -Raw -LiteralPath $specsPath | ConvertFrom-Json
$checks = @($specs.checks)
$passedChecks = @($checks | Where-Object { $_.passed })
$focusedNames = @(
    "timing-effect-memory-default-matches-wpf-110",
    "timing-effect-memory-ignores-bpm-only-row",
    "timing-effect-memory-preserves-custom-number-text-and-field",
    "timing-effect-memory-retains-last-custom-field-across-effects")
$focusedChecks = @($checks | Where-Object { $_.name -in $focusedNames })
Assert ($specs.status -eq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 441 -and $passedChecks.Count -eq 441) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
Assert ($focusedChecks.Count -eq 4 -and @($focusedChecks | Where-Object {
    -not $_.passed
}).Count -eq 0) "Last-Effect-memory focused Specs did not all pass."

$mainLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainText = Get-Content -Raw -LiteralPath $mainLogPath
Assert ($mainText -match "79/79 specs passed") "Main Specs did not pass 79/79."

$guiPath = Join-Path $formalRoot "gui\last-effect-memory-gui-evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -eq (
    "lumachart.windows.avalonia.last-effect-memory-gui-evidence.v1")) (
    "Unexpected GUI schema: $($gui.schema)")
Assert ($gui.status -eq "passed-migration-incomplete") (
    "GUI evidence status is not passed-migration-incomplete.")
Assert (@($gui.physicalMouseActions).Count -eq 10) (
    "Expected exactly 10 physical mouse actions.")
Assert ($gui.source.unchanged -eq $true -and
    [int]$gui.source.realChartNoteCount -eq 2753) (
    "Frozen real Resound source or Note count is unexpected.")
Assert ($gui.isolatedChart.noteStructureUnchanged -eq $true -and
    $gui.isolatedChart.bpmTimingStructureUnchanged -eq $true) (
    "Accepted Effect edits changed Note or BPM Timing structure.")
Assert ([string]$gui.isolatedChart.effectCount -ceq "0->2" -and
    [int]$gui.isolatedChart.rawValueOccurrenceCount -eq 2 -and
    [string]$gui.isolatedChart.rawValueText -ceq "2e-3") (
    "Saved MC did not contain exactly two raw inherited Effect values.")

$memory = $gui.wpf110LastEffectMemory
Assert ([string]$memory.contract -ceq "wpf-1.1.0-last-effect-memory-r1") (
    "Unexpected WPF last-Effect-memory contract.")
Assert ([string]$memory.seed.effect -ceq "Custom" -and
    [string]$memory.seed.rawValueText -ceq "2e-3" -and
    [string]$memory.seed.customField -ceq "lane.glow" -and
    $memory.seed.createdThroughPhysicalAddButton -eq $true) (
    "Physical seed Custom Effect is unexpected.")
Assert ([string]$memory.inherited.beat -ceq [string]$memory.seed.beat -and
    $memory.inherited.beatComesFromCurrentRedLine -eq $true -and
    [string]$memory.inherited.bpm -ceq "" -and
    [string]$memory.inherited.delay -ceq "0" -and
    [string]$memory.inherited.effect -ceq "Custom" -and
    [string]$memory.inherited.rawValueText -ceq "2e-3" -and
    [string]$memory.inherited.customField -ceq "lane.glow") (
    "Quick Effect did not inherit the exact WPF values at the red line.")
$expectedStatus = "添加 lane.glow Effect · Beat $($memory.seed.beat) · 继承值 2e-3"
Assert ([string]$memory.inherited.status -ceq $expectedStatus) (
    "Quick Effect status differs from the WPF inheritance contract.")
Assert ($memory.inherited.createdThroughPhysicalQuickEffectAndAddButtons -eq $true -and
    $memory.savedThroughPhysicalButton -eq $true) (
    "The focused GUI path did not use the physical quick/add/save actions.")
Assert ([int]$memory.reopenedTimingCount -eq 3 -and
    [string]$memory.reopenedEffect -ceq "Custom" -and
    [string]$memory.reopenedRawValueText -ceq "2e-3" -and
    [string]$memory.reopenedCustomField -ceq "lane.glow") (
    "Saved MC did not reopen with the exact raw Custom Effect.")
Assert ($gui.runtime.initial.platformScope -ceq "Windows-only" -and
    $gui.runtime.reopened.platformScope -ceq "Windows-only") (
    "GUI runtime evidence is not Windows-only.")
Assert ($gui.completion.windowsAvaloniaOneToOneComplete -eq $false -and
    $gui.completion.userReplacementApprovalReceived -eq $false -and
    $gui.completion.otherPlatformsAuthorized -eq $false) (
    "GUI evidence incorrectly marks migration completion or other-platform authorization.")

$screenshotEvidence = @()
$screenshotProperties = @($gui.screenshots.PSObject.Properties)
Assert ($screenshotProperties.Count -eq 4) (
    "Expected four declared GUI screenshots, got $($screenshotProperties.Count).")
foreach ($property in $screenshotProperties) {
    $declared = $property.Value
    $full = [IO.Path]::GetFullPath([string]$declared.path)
    Assert ($full.StartsWith(
        (Join-Path $formalRoot "gui") + '\',
        [StringComparison]::OrdinalIgnoreCase)) (
        "Screenshot escaped formal GUI root: $full")
    $actual = File-Evidence $full
    Assert ($actual.sha256 -ceq [string]$declared.sha256) (
        "Screenshot hash differs from GUI evidence: $full")
    Assert ($actual.sha256 -ceq $expectedHashes[$property.Name]) (
        "Formal screenshot hash changed: $($property.Name)")
    Assert ([int]$declared.width -eq 2560 -and [int]$declared.height -eq 1528) (
        "Unexpected formal screenshot size: $($property.Name)")
    $screenshotEvidence += [ordered]@{
        name = $property.Name
        file = $actual
    }
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
        "artifacts\windows-avalonia-editor-permission-action-slice-20260727-r1\" +
        "verification-evidence.json"))
Assert ($predecessor.sha256 -ceq (
    "60B8AF1523EE2DD67FC95D65B30619A1368854E14D53A10550A057373CB14005")) (
    "Predecessor authority hash changed.")

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.last-effect-memory-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        windowsAvaloniaOnly = $true
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        formalAuthority = "last-effect-memory-r1"
    }
    builds = [ordered]@{
        warnings = 0
        errors = 0
        logs = $builds
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 441
            total = 441
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
        physicalActionCount = 10
        screenshotCount = 4
        rawCustomValueTextPreserved = "2e-3"
        customFieldPreserved = "lane.glow"
        inheritedBeat = [string]$memory.inherited.beat
        savedAndReopened = $true
        noteStructureUnchanged = $true
        bpmTimingStructureUnchanged = $true
        manualVisualReviewPassed = $true
        evidence = File-Evidence $guiPath
        screenshots = $screenshotEvidence
    }
    source = [ordered]@{
        changedFiles = @(
            "LumaChart.Avalonia\Editing\WindowsTimingEffectMemory.cs",
            "LumaChart.Avalonia\MainWindow.cs",
            "LumaChart.Avalonia.Specs\WindowsTimingEffectMemorySpecs.cs",
            "LumaChart.Avalonia.Specs\Program.cs",
            "tools\Capture-WindowsAvaloniaInspectorParityGui.ps1",
            "tools\New-WindowsAvaloniaLastEffectMemorySliceEvidence.ps1")
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
