param(
    [string]$FormalRoot = (
        Join-Path $PSScriptRoot `
            "..\artifacts\windows-avalonia-input-edges-slice-20260728-r1")
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
    Assert (Test-Path -LiteralPath $Path -PathType Leaf) "Missing JSON: $Path"
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function File-Evidence([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        bytes = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
}

function Assert-OrdinaryStrictBuild([string]$Path) {
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    Assert (
        $text.Contains("0 个警告", [StringComparison]::Ordinal) -and
        $text.Contains("0 个错误", [StringComparison]::Ordinal)) (
        "Strict build log is not 0 warning / 0 error: $Path")
    Assert (
        -not $text.Contains("OLLVM", [StringComparison]::OrdinalIgnoreCase) -and
        -not $text.Contains("NativeAOT", [StringComparison]::OrdinalIgnoreCase)) (
        "Strict build log contains a forbidden protection/AOT path: $Path")
    return File-Evidence $Path
}

$settingsPath = Join-Path `
    $formalRoot `
    "settings-focus-gui\settings-anchor-gui-evidence.json"
$imePath = Join-Path `
    $formalRoot `
    "ime-candidate-edges-gui\evidence.json"
$avaloniaSpecsPath = Join-Path `
    $formalRoot `
    "tests\avalonia-specs-evidence.json"
$mainSpecsLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$safetyPath = Join-Path $formalRoot "gui-automation-safety.json"
$settings = Read-Json $settingsPath
$ime = Read-Json $imePath
$avaloniaSpecs = Read-Json $avaloniaSpecsPath
$safety = Read-Json $safetyPath

$expectedFocusOrder = @(
    "Settings.Snap",
    "Settings.AnchorLine",
    "Settings.AnchorLineAbove",
    "Settings.AnchorCell",
    "Settings.AnchorCellBottom",
    "Settings.GridLaneWidth",
    "Settings.MainEditorHorizontalOffset",
    "Settings.GridBeatHeight",
    "Settings.NoteWidth",
    "Settings.NoteHeight",
    "Settings.NoteOpacity",
    "Settings.JudgementLinePosition",
    "Settings.JudgementLineThickness",
    "Settings.JudgementLineOpacity",
    "Settings.ProEditorColumns",
    "Settings.UiScale",
    "Settings.FontScale",
    "FrameRateLimitBox",
    "Settings.ResetEditorView",
    "Settings.ResetFloatingLayout",
    "Settings.AutoBackupEnabled",
    "Settings.AutoBackupMinutes",
    "Settings.BackupNow",
    "Settings.RestoreBackup",
    "Settings.OpenBackupFolder",
    "Settings.Cache.Backups",
    "Settings.Cache.UnopenedEditing",
    "Settings.Cache.OnlineResources",
    "Settings.Cache.CleanSelected",
    "Settings.Shortcuts.Reset",
    "Shortcut_New",
    "Shortcut_Open",
    "Shortcut_Save",
    "Shortcut_SaveAs",
    "Shortcut_Undo",
    "Shortcut_Redo",
    "Shortcut_Cut",
    "Shortcut_Copy",
    "Shortcut_Paste",
    "Shortcut_SelectAll",
    "Shortcut_ToolSelect",
    "Shortcut_ToolTap",
    "Shortcut_ToolHold",
    "Shortcut_ToolErase",
    "Shortcut_PlayPause",
    "Shortcut_Delete",
    "Shortcut_StepForward",
    "Shortcut_StepBack",
    "Shortcut_GoHome",
    "Shortcut_TogglePro",
    "Shortcut_ToggleFullscreen",
    "Shortcut_Group0",
    "Shortcut_Group1",
    "Shortcut_Group2",
    "Shortcut_Group3",
    "Shortcut_Group4",
    "Shortcut_Group5",
    "Shortcut_Group6",
    "Shortcut_Group7",
    "Shortcut_Group8",
    "Shortcut_Group9",
    "Audio.Volume",
    "KeySound.Enabled",
    "KeySound.Preset",
    "KeySound.CustomFile",
    "KeySound.Preview",
    "KeySound.Volume",
    "KeySound.LongNoteEnd",
    "KeySound.GlobalOffset",
    "KeySound.ChartOffset",
    "Audio.PreservePitch",
    "Settings.About",
    "Settings.Bilibili",
    "Settings.Sponsor",
    "Settings.CheckForUpdates")

Assert (
    $settings.schema -ceq
        "lumachart.windows.avalonia.settings-anchor-gui-evidence.v1" -and
    $settings.status -ceq "passed-migration-incomplete" -and
    [bool]$settings.windowsAvaloniaOnly -and
    [bool]$settings.pureDotnetRelease -and
    -not [bool]$settings.ollvmObfuscationPackingVirtualizationOrAotUsed) (
    "Settings focus GUI evidence boundary drifted.")
$focus = $settings.settingsFocus
$forward = @($focus.forwardRecords)
$reverse = @($focus.reverseRecords)
Assert (
    [int]$focus.expectedControlCount -eq 75 -and
    [int]$focus.physicalTabKeyCount -eq 74 -and
    [int]$focus.physicalShiftTabKeyCount -eq 74 -and
    [bool]$focus.exactForwardOrderPassed -and
    [bool]$focus.exactReverseOrderPassed -and
    $forward.Count -eq 75 -and
    $reverse.Count -eq 75) (
    "Settings forward/reverse focus counts drifted.")
for ($index = 0; $index -lt $expectedFocusOrder.Count; $index++) {
    Assert (
        [string]$forward[$index].resolvedAutomationId -ceq
            $expectedFocusOrder[$index]) (
        "Forward Settings focus mismatch at index $index.")
    Assert (
        [string]$reverse[$index].resolvedAutomationId -ceq
            $expectedFocusOrder[$expectedFocusOrder.Count - 1 - $index]) (
        "Reverse Settings focus mismatch at traversal index $index.")
}
Assert (
    [bool]$settings.nonTopmost.firstClient -and
    [bool]$settings.nonTopmost.duringPhysicalFocusTraversal -and
    [bool]$settings.nonTopmost.reopenedClient) (
    "Settings focus GUI used or gained a persistent topmost state.")

Assert (
    $ime.schema -ceq
        "lumachart.windows.avalonia.ime-candidate-edges-gui-evidence.v1" -and
    $ime.status -ceq "passed" -and
    [bool]$ime.formalMigrationAuthority -and
    -not [bool]$ime.completion.windowsAvaloniaCanReplaceWpf -and
    -not [bool]$ime.completion.userManualReplacementApprovalReceived -and
    -not [bool]$ime.completion.nextPlatformAuthorized) (
    "IME candidate-edge GUI evidence boundary drifted.")
$actualIme = $ime.inputBoundary.actualIme
$candidateEdges = $actualIme.candidateEdges
Assert (
    [bool]$ime.inputBoundary.actualImeCompositionValidated -and
    [bool]$actualIme.actualImeCompositionValidated -and
    [bool]$actualIme.physicalPinyinKeyEventsUsed -and
    [bool]$actualIme.candidateOverlayCapturedFromPhysicalDesktop -and
    -not [bool]$actualIme.enterKeySent -and
    [string]$actualIme.librarySearch.committedValueBeforeCandidateSelection -ceq "" -and
    [string]$candidateEdges.candidatePageGesture -ceq "PageDown" -and
    [string]$candidateEdges.committedValueAfterCandidatePage -ceq "" -and
    [bool]$candidateEdges.candidatePageChangedPhysicalPixels -and
    [string]$candidateEdges.cancelGesture -ceq "Escape" -and
    [string]$candidateEdges.committedValueAfterCancel -ceq "" -and
    [bool]$candidateEdges.textHostFocusRetainedAfterCancel -and
    [string]$candidateEdges.committedValueBeforeSecondCandidateSelection -ceq "" -and
    [string]$actualIme.librarySearch.committedValueAfterCandidateSelection -ceq "中文") (
    "Microsoft Pinyin page/cancel/re-entry/Space-commit contract drifted.")
Assert (
    [string]$candidateEdges.candidateScreenshotSha256BeforePage -cne
        [string]$candidateEdges.candidateScreenshotSha256AfterPage) (
    "Microsoft Pinyin candidate screenshots did not change across PageDown.")

$screenshots = @($ime.screenshots)
Assert ($screenshots.Count -eq 4) "Expected exactly four IME edge screenshots."
$screenshotEvidence = @()
foreach ($screenshot in $screenshots) {
    $path = [string]$screenshot.path
    Assert (Test-Path -LiteralPath $path -PathType Leaf) "Missing screenshot: $path"
    $file = File-Evidence $path
    Assert (
        $file.sha256 -ceq [string]$screenshot.sha256 -and
        [int]$screenshot.width -eq 2560 -and
        [int]$screenshot.height -eq 1528) (
        "Screenshot hash or dimensions drifted: $path")
    $screenshotEvidence += $file
}

$checks = @($avaloniaSpecs.Checks)
Assert (
    $avaloniaSpecs.Schema -ceq "lumachart.windows.avalonia.slice-specs.v2" -and
    $avaloniaSpecs.Status -ceq "passed" -and
    $checks.Count -eq 482 -and
    @($checks | Where-Object { -not $_.Passed }).Count -eq 0) (
    "Avalonia Specs are not 482/482.")
$mainSpecsText =
    Get-Content -LiteralPath $mainSpecsLogPath -Raw -Encoding UTF8
Assert (
    $mainSpecsText.Contains(
        "79/79 specs passed.",
        [StringComparison]::Ordinal)) (
    "Main Specs are not 79/79.")
Assert (
    $safety.schema -ceq
        "lumachart.windows.avalonia.gui-automation-safety.v1" -and
    $safety.status -ceq "passed" -and
    [bool]$safety.windowsAvaloniaOnly -and
    [bool]$safety.foregroundAutomationRequiresExplicitUserConsent -and
    [int]$safety.minimumSystemIdleMilliseconds -ge 3000 -and
    [bool]$safety.heldModifierGateRequired -and
    -not [bool]$safety.persistentTopmostUsed) (
    "GUI automation safety boundary drifted.")

$realMcSha256 =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$installerSha256 =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
Assert (
    [string]$settings.chart.sourceFixtureSha256Before -ceq $realMcSha256 -and
    [string]$settings.chart.sourceFixtureSha256After -ceq $realMcSha256 -and
    [string]$settings.installer.sha256Before -ceq $installerSha256 -and
    [string]$settings.installer.sha256After -ceq $installerSha256 -and
    [string]$ime.source.before.sha256 -ceq $realMcSha256 -and
    [string]$ime.source.after.sha256 -ceq $realMcSha256 -and
    [string]$ime.frozenInstaller.before.sha256 -ceq $installerSha256 -and
    [string]$ime.frozenInstaller.after.sha256 -ceq $installerSha256) (
    "Real MC fixture or frozen installer changed.")

$buildEvidence = [ordered]@{}
foreach ($buildName in @(
        "avalonia-build.log",
        "avalonia-specs-build.log",
        "main-specs-build.log",
        "online-gui-server-build.log")) {
    $buildEvidence[$buildName] =
        Assert-OrdinaryStrictBuild (Join-Path $formalRoot "build\$buildName")
}

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.input-edges-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    platform = "Windows Avalonia only"
    buildMode = "ordinary .NET Release"
    buildBoundary = [ordered]@{
        ollvm = $false
        obfuscation = $false
        packing = $false
        codeVirtualization = $false
        aot = $false
        nativeAot = $false
        strictBuilds = $buildEvidence
    }
    automatedTests = [ordered]@{
        avalonia = [ordered]@{
            passed = 482
            total = 482
            evidence = File-Evidence $avaloniaSpecsPath
        }
        main = [ordered]@{
            passed = 79
            total = 79
            log = File-Evidence $mainSpecsLogPath
        }
    }
    gui = [ordered]@{
        settingsFocus = [ordered]@{
            controls = 75
            physicalTabKeys = 74
            physicalShiftTabKeys = 74
            exactForwardOrder = $true
            exactReverseOrder = $true
            cleanPhysicalExitAfterFocusTraversal = $true
            evidence = File-Evidence $settingsPath
        }
        microsoftPinyinCandidateEdges = [ordered]@{
            pageDownWithoutCommit = $true
            escapeCanceledComposition = $true
            focusRetainedAfterEscape = $true
            reentryCommittedWithSpace = "中文"
            enterKeySent = $false
            screenshotCount = $screenshots.Count
            screenshotsVisuallyInspected = $true
            screenshots = $screenshotEvidence
            evidence = File-Evidence $imePath
        }
        persistentTopmostUsed = $false
        safety = File-Evidence $safetyPath
    }
    fixedRegression = [ordered]@{
        symptom =
            "Closing after Settings focus loss could refresh a disposed audio ViewModel."
        teardownSuppressesLateFocusAndStatusMutation = $true
        physicalCloseAfterBidirectionalTraversalExitCodeZero = $true
    }
    integrity = [ordered]@{
        realMcSha256 = $realMcSha256
        frozenInstallerSha256 = $installerSha256
        productionServerDeployed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
    }
    completion = [ordered]@{
        windowsAvaloniaCanReplaceWpf = $false
        userManualReplacementApprovalReceived = $false
        nextPlatformAuthorized = $false
    }
    remainingDifferences = @(
        "The complete Windows parity matrix remains open.",
        "Other dedicated popup/modal focus paths and keyboard models remain open.",
        "Update/install, multi-DPI, format/game, ClientSecurity and display-present performance gates remain open.")
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
$verification |
    ConvertTo-Json -Depth 24 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
[pscustomobject]@{
    verificationPath = $verificationPath
    verificationBytes = (Get-Item -LiteralPath $verificationPath).Length
    verificationSha256 =
        (Get-FileHash -LiteralPath $verificationPath -Algorithm SHA256).Hash
    status = "passed-migration-incomplete"
}
