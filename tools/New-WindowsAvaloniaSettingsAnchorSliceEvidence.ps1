param(
    [string]$Root =
        "artifacts\windows-avalonia-settings-anchor-slice-20260728-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedGridLineScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedLineAboveScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedCellCenterScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedCellBottomScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedFocusStartScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedFocusMiddleScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedFocusEndScreenshotSha256
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia settings/anchor verification requires PowerShell Core on Windows."
}

$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-settings-anchor-slice-20260728-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals(
        $expectedRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal settings/anchor root must be exactly $expectedRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-HashArgument([string]$Hash, [string]$Label) {
    Assert ($Hash -match '^[0-9A-Fa-f]{64}$') (
        "$Label SHA-256 is invalid.")
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

function Read-Json([string]$Path) {
    Assert (Test-Path -LiteralPath $Path -PathType Leaf) "Missing JSON: $Path"
    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    Assert ($text -match "(0 个警告|0 Warning\(s\))") (
        "Strict build log lacks zero-warning result: $Path")
    Assert ($text -match "(0 个错误|0 Error\(s\))") (
        "Strict build log lacks zero-error result: $Path")
    Assert ($text -notmatch (
        "(?i)ollvm|obfuscat|virtuali[sz]ation|nativeaot|publish-aot")) (
        "Strict build log contains a forbidden protection or AOT marker: $Path")
    File-Evidence $Path
}

function Assert-Screenshot(
    [string]$Path,
    [string]$ExpectedHash,
    [object]$Captured,
    [string]$Label) {
    $file = File-Evidence $Path
    Assert ($file.sha256 -ceq $ExpectedHash.ToUpperInvariant()) (
        "$Label screenshot hash differs from the visually approved image.")
    Assert ($Captured.sha256 -ceq $file.sha256) (
        "$Label screenshot metadata hash differs from the file.")
    Assert ([int]$Captured.width -eq 1980 -and [int]$Captured.height -eq 1200) (
        "$Label screenshot dimensions differ from the formal GUI viewport.")
    Assert ([int]$Captured.sampledUniqueColors -ge 20) (
        "$Label screenshot is visually degenerate.")
    Assert ([long]$Captured.length -eq [long]$file.length) (
        "$Label screenshot metadata length differs from the file.")
    $file
}

foreach ($hashArgument in @(
        @($ExpectedGridLineScreenshotSha256, "Grid-line"),
        @($ExpectedLineAboveScreenshotSha256, "Line-above"),
        @($ExpectedCellCenterScreenshotSha256, "Cell-center"),
        @($ExpectedCellBottomScreenshotSha256, "Cell-bottom"),
        @($ExpectedFocusStartScreenshotSha256, "Focus-start"),
        @($ExpectedFocusMiddleScreenshotSha256, "Focus-middle"),
        @($ExpectedFocusEndScreenshotSha256, "Focus-end"))) {
    Assert-HashArgument $hashArgument[0] $hashArgument[1]
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists: $verificationPath")

$guiRoot = Join-Path $formalRoot "settings-anchor-gui"
$guiEvidencePath = Join-Path $guiRoot "settings-anchor-gui-evidence.json"
$gui = Read-Json $guiEvidencePath
Assert ($gui.schema -ceq
    "lumachart.windows.avalonia.settings-anchor-gui-evidence.v1") (
    "Settings/anchor GUI schema mismatch.")
Assert ($gui.status -ceq "passed-migration-incomplete") (
    "Settings/anchor GUI did not pass.")
Assert ($gui.platform -ceq "Windows Avalonia only") (
    "Settings/anchor GUI platform scope drifted.")
Assert ([bool]$gui.windowsAvaloniaOnly) (
    "Settings/anchor GUI is not Windows-only.")
Assert (-not [bool]$gui.mobileProjectsBuiltModifiedInstalledOrTested) (
    "Settings/anchor GUI evidence reports mobile work.")
Assert (-not [bool]$gui.productionServerMutationPerformed) (
    "Settings/anchor GUI evidence reports a production Server mutation.")
Assert ([bool]$gui.pureDotnetRelease) (
    "Settings/anchor GUI was not an ordinary .NET Release run.")
Assert (-not [bool]$gui.ollvmObfuscationPackingVirtualizationOrAotUsed) (
    "Settings/anchor GUI reports a forbidden protection or AOT mechanism.")
Assert (-not [bool]$gui.migrationComplete) (
    "Slice evidence must not claim the Windows migration is complete.")

Assert ($gui.customSnap.requestedText -ceq "1/17") (
    "Custom Snap request differs from 1/17.")
Assert ([bool]$gui.customSnap.committedWithoutEnter) (
    "Custom Snap was not committed without Enter.")
Assert ($gui.customSnap.commitTrigger -ceq
    "editable ComboBox TextChanged debounce") (
    "Custom Snap did not use the IME-safe text-change debounce.")
Assert ($gui.customSnap.valuePatternTargetAutomationId -ceq "Settings.Snap") (
    "Custom Snap targeted the wrong control.")
Assert ([int]$gui.customSnap.persistedSnapDivisionBeforeReopen -eq 17 -and
       [int]$gui.customSnap.persistedSnapDivisionAfterReopen -eq 17) (
    "Custom Snap 1/17 did not persist across close/reopen.")
Assert ($gui.customSnap.reopenedHelpText -match
    "(^|;\s*)SnapDivision=17(;|$)") (
    "Reopened Snap UIA state does not expose division 17.")

$anchorCases = @($gui.noteAnchors.cases)
Assert ([int]$gui.noteAnchors.physicalClickCount -eq 4 -and
       $anchorCases.Count -eq 4) (
    "Four physical Note-anchor clicks were not recorded.")
Assert ([bool]$gui.noteAnchors.uniqueTimelineSurface -and
       -not [bool]$gui.noteAnchors.notePerAvaloniaControl) (
    "Timeline rendering regressed from the single-surface design.")

$expectedAnchorCases = @(
    [ordered]@{
        id = "Settings.AnchorLine"
        mode = "GridLine"
        display = "穿线居中"
        file = "anchor-grid-line.png"
        hash = $ExpectedGridLineScreenshotSha256
    },
    [ordered]@{
        id = "Settings.AnchorLineAbove"
        mode = "LineAbove"
        display = "贴在线上"
        file = "anchor-line-above.png"
        hash = $ExpectedLineAboveScreenshotSha256
    },
    [ordered]@{
        id = "Settings.AnchorCell"
        mode = "CellCenter"
        display = "格内居中"
        file = "anchor-cell-center.png"
        hash = $ExpectedCellCenterScreenshotSha256
    },
    [ordered]@{
        id = "Settings.AnchorCellBottom"
        mode = "CellBottom"
        display = "格内靠下"
        file = "anchor-cell-bottom.png"
        hash = $ExpectedCellBottomScreenshotSha256
    }
)

$anchorScreenshotFiles = [Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $expectedAnchorCases.Count; $index++) {
    $actual = $anchorCases[$index]
    $expected = $expectedAnchorCases[$index]
    Assert ($actual.activeAutomationId -ceq $expected.id) (
        "Anchor $index active AutomationId mismatch.")
    Assert ($actual.activeMode -ceq $expected.mode) (
        "Anchor $index mode mismatch.")
    Assert ($actual.displayName -ceq $expected.display) (
        "Anchor $index display name mismatch.")
    Assert ($actual.timelineHelpText.Contains(
            "NoteAnchor=$($expected.mode)",
            [StringComparison]::Ordinal) -and
           $actual.timelineHelpText.Contains(
            "Note 对齐 $($expected.display)",
            [StringComparison]::Ordinal)) (
        "Anchor $index timeline state is stale.")
    foreach ($button in $expectedAnchorCases) {
        $help = $actual.buttonHelpText.($button.id)
        $expectedActive = $button.id -ceq $expected.id
        Assert ($help -ceq (
            "NoteAnchor=$($button.mode); Active=$expectedActive")) (
            "Anchor $index button state mismatch for $($button.id).")
    }
    Assert ([int]$actual.click.x -gt 0 -and [int]$actual.click.y -gt 0) (
        "Anchor $index lacks a physical click coordinate.")
    $anchorScreenshotFiles.Add((
        Assert-Screenshot `
            (Join-Path $guiRoot $expected.file) `
            $expected.hash.ToUpperInvariant() `
            $actual.screenshot `
            $expected.mode))
}

Assert ([int]$gui.noteAnchors.persistedFinalModeValue -eq 3) (
    "Final CellBottom enum value did not persist.")
Assert ($gui.noteAnchors.reopenedFinalState.activeAutomationId -ceq
        "Settings.AnchorCellBottom" -and
       $gui.noteAnchors.reopenedFinalState.activeMode -ceq "CellBottom" -and
       $gui.noteAnchors.reopenedFinalState.displayName -ceq "格内靠下") (
    "Reopened Note-anchor state is not CellBottom.")

$focus = $gui.settingsFocus
$focusRecords = @($focus.records)
Assert ([int]$focus.physicalTabKeyCount -eq 74 -and
       [int]$focus.expectedControlCount -eq 75 -and
       [bool]$focus.exactOrderPassed -and
       $focusRecords.Count -eq 75) (
    "The exact 75-control Settings focus route did not pass.")
for ($index = 0; $index -lt $focusRecords.Count; $index++) {
    $record = $focusRecords[$index]
    Assert ([int]$record.index -eq $index) (
        "Settings focus record index mismatch at $index.")
    Assert ($record.expectedAutomationId -ceq $record.resolvedAutomationId) (
        "Settings focus route mismatch at $index.")
}
Assert ($focusRecords[0].resolvedAutomationId -ceq "Settings.Snap" -and
       $focusRecords[70].resolvedAutomationId -ceq "Audio.PreservePitch" -and
       $focusRecords[74].resolvedAutomationId -ceq
        "Settings.CheckForUpdates") (
    "Settings focus boundary controls differ from WPF 1.1.0.")

$focusScreenshotFiles = @(
    Assert-Screenshot `
        (Join-Path $guiRoot "settings-focus-start.png") `
        $ExpectedFocusStartScreenshotSha256.ToUpperInvariant() `
        $focus.startCapture `
        "Focus-start"
    Assert-Screenshot `
        (Join-Path $guiRoot "settings-focus-middle.png") `
        $ExpectedFocusMiddleScreenshotSha256.ToUpperInvariant() `
        $focus.middleCapture `
        "Focus-middle"
    Assert-Screenshot `
        (Join-Path $guiRoot "settings-focus-end.png") `
        $ExpectedFocusEndScreenshotSha256.ToUpperInvariant() `
        $focus.endCapture `
        "Focus-end"
)

Assert ([bool]$gui.nonTopmost.firstClient -and
       [bool]$gui.nonTopmost.duringPhysicalFocusTraversal -and
       [bool]$gui.nonTopmost.reopenedClient) (
    "A Settings/anchor GUI window gained a persistent topmost style.")

$expectedFixtureHash =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$expectedInstallerHash =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
Assert ($gui.chart.sourceFixtureSha256Before -ceq $expectedFixtureHash -and
       $gui.chart.sourceFixtureSha256After -ceq $expectedFixtureHash -and
       $gui.chart.isolatedChartSha256Before -ceq
        $gui.chart.isolatedChartSha256After) (
    "Real MC or isolated chart hash changed.")
Assert ($gui.installer.sha256Before -ceq $expectedInstallerHash -and
       $gui.installer.sha256After -ceq $expectedInstallerHash) (
    "Frozen WPF installer hash changed.")

$safetyPath = Join-Path $formalRoot "gui-automation-safety.json"
$safety = Read-Json $safetyPath
Assert ($safety.schema -ceq
    "lumachart.windows.avalonia.gui-automation-safety.v1" -and
       $safety.status -ceq "passed") (
    "GUI automation safety scan did not pass.")
Assert ([bool]$safety.windowsAvaloniaOnly -and
       [bool]$safety.foregroundAutomationRequiresExplicitUserConsent -and
       [int]$safety.minimumSystemIdleMilliseconds -ge 3000 -and
       [bool]$safety.heldModifierGateRequired -and
       -not [bool]$safety.persistentTopmostUsed) (
    "GUI automation safety boundaries drifted.")
Assert ([int]$safety.captureScriptCount -ge 25 -and
       @($safety.scripts | Where-Object {
           $_.path -match "Capture-WindowsAvaloniaSettingsAnchorGui\.ps1$"
       }).Count -eq 1) (
    "Settings/anchor GUI script is absent from the safety scan.")

$buildRoot = Join-Path $formalRoot "build"
$buildEvidence = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $buildRoot "avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $buildRoot "avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $buildRoot "main-specs-build.log")
    onlineGuiServer = Assert-StrictBuild (
        Join-Path $buildRoot "online-gui-server-build.log")
}

$testsRoot = Join-Path $formalRoot "tests"
$avaloniaSpecsPath = Join-Path $testsRoot "avalonia-specs-evidence.json"
$avaloniaSpecs = Read-Json $avaloniaSpecsPath
Assert ($avaloniaSpecs.Status -ceq "passed") (
    "Avalonia Specs evidence did not pass.")
Assert (@($avaloniaSpecs.Checks).Count -eq 482 -and
       @($avaloniaSpecs.Checks | Where-Object { -not [bool]$_.Passed }).Count -eq 0) (
    "Avalonia Specs are not 482/482.")
$mainSpecsPath = Join-Path $testsRoot "main-specs-run.log"
$mainSpecsText = Get-Content -LiteralPath $mainSpecsPath -Raw -Encoding UTF8
Assert ($mainSpecsText -match "(?m)^79/79 specs passed\.\s*$") (
    "Main Specs are not 79/79.")

$sourceFiles = @(
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia\Controls\TimelineSurface.cs",
    "LumaChart.Avalonia\Rendering\TimelinePlacementGeometry.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsInspectorParityPolicy.cs",
    "LumaChart.Avalonia.Specs\WindowsInspectorParitySpecs.cs",
    "tools\Capture-WindowsAvaloniaSettingsAnchorGui.ps1",
    "tools\New-WindowsAvaloniaSettingsAnchorSliceEvidence.ps1"
) | ForEach-Object { File-Evidence (Join-Path $projectRoot $_) }

$evidence = [ordered]@{
    schema =
        "lumachart.windows.avalonia.settings-anchor-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        platform = "Windows Avalonia only"
        buildMode = "ordinary .NET Release"
        windowsAvaloniaOnly = $true
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    }
    builds = $buildEvidence
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            result = "482/482"
            evidence = File-Evidence $avaloniaSpecsPath
            runLog = File-Evidence (
                Join-Path $testsRoot "avalonia-specs-run.log")
        }
        mainSpecs = [ordered]@{
            result = "79/79"
            runLog = File-Evidence $mainSpecsPath
        }
    }
    gui = [ordered]@{
        result = "passed"
        evidence = File-Evidence $guiEvidencePath
        runtimeFirst = File-Evidence (
            Join-Path $guiRoot "settings-anchor-runtime-first.json")
        runtimeReopen = File-Evidence (
            Join-Path $guiRoot "settings-anchor-runtime-reopen.json")
        safety = File-Evidence $safetyPath
        snapDivision = 17
        snapCommittedWithoutEnter = $true
        physicalAnchorClickCount = 4
        focusControlCount = 75
        physicalTabKeyCount = 74
        nonTopmost = $true
        anchorScreenshots = @($anchorScreenshotFiles)
        focusScreenshots = @($focusScreenshotFiles)
    }
    source = @($sourceFiles)
    frozenBaselines = [ordered]@{
        realMcSha256 = $expectedFixtureHash
        installerSha256 = $expectedInstallerHash
    }
    remainingDifferences = @($gui.remainingDifferences)
    completion = [ordered]@{
        migrationComplete = $false
        userReplacementApprovalGranted = $false
    }
}

$evidence |
    ConvertTo-Json -Depth 20 |
    Set-Content -LiteralPath $verificationPath -Encoding UTF8

Write-Host "Windows Avalonia settings/anchor verification: passed"
Write-Host "Evidence: $verificationPath"
