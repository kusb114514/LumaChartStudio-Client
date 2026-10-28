param(
    [string]$Root =
        "artifacts\windows-avalonia-note-sound-picker-slice-20260727-r2",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedInitialScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedKeyboardItemScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedEscapeRestoredScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedAssignedScreenshotSha256
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia Note Sound picker verification requires PowerShell Core on Windows."
}

$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-note-sound-picker-slice-20260727-r2"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals(
        $expectedRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal Note Sound picker root must be exactly $expectedRoot"
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

function Assert-HashArgument([string]$Hash, [string]$Label) {
    Assert ($Hash -match '^[0-9A-Fa-f]{64}$') (
        "$Label SHA-256 is invalid.")
}

function Assert-PhysicalAction(
    [object]$Action,
    [int]$Index,
    [string]$Kind,
    [string]$ExpectedValue) {
    Assert ([int]$Action.index -eq $Index) (
        "Physical action index mismatch at $Index.")
    Assert ($Action.kind -ceq $Kind) (
        "Physical action $Index kind mismatch.")
    if ($Kind -ceq "mouse") {
        Assert ($Action.automationId -ceq "Inspector.Note.SoundExisting") (
            "Physical mouse action $Index targeted the wrong control.")
        Assert ($Action.action -ceq $ExpectedValue) (
            "Physical mouse action $Index description mismatch.")
        Assert ([int]$Action.x -gt 0 -and [int]$Action.y -gt 0) (
            "Physical mouse action $Index lacks screen coordinates.")
    }
    else {
        Assert ($Action.key -ceq $ExpectedValue) (
            "Physical keyboard action $Index key mismatch.")
    }
}

Assert-HashArgument $ExpectedInitialScreenshotSha256 "Initial screenshot"
Assert-HashArgument $ExpectedKeyboardItemScreenshotSha256 "Keyboard item screenshot"
Assert-HashArgument $ExpectedEscapeRestoredScreenshotSha256 "Escape-restored screenshot"
Assert-HashArgument $ExpectedAssignedScreenshotSha256 "Assigned screenshot"

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
$expectedNoteSoundChecks = @(
    "note-sound-picker-assignment-mutates-only-sound-and-is-one-undo",
    "note-sound-picker-rejects-unfrozen-online-resource-without-mutation",
    "note-sound-picker-geometry-and-colors-match-wpf-110",
    "note-sound-picker-declarative-tab-navigation-cycles",
    "note-sound-picker-tab-cycles-forward-and-backward",
    "note-sound-picker-arrows-home-and-end-stay-inside-popup",
    "note-sound-picker-unfocused-navigation-enters-deterministically",
    "note-sound-picker-escape-always-closes-and-restores-entry-focus",
    "note-sound-picker-does-not-steal-modified-or-unrelated-keys"
)
$noteSoundChecks = @($checks | Where-Object {
        $_.name -like "note-sound-picker-*"
    })
Assert ($specs.status -ceq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 478 -and $passedChecks.Count -eq 478) (
    "Avalonia Specs are not 478/478.")
Assert ($noteSoundChecks.Count -eq $expectedNoteSoundChecks.Count) (
    "Unexpected Note Sound picker Specs count.")
foreach ($checkName in $expectedNoteSoundChecks) {
    $matching = @($noteSoundChecks | Where-Object {
            $_.name -ceq $checkName -and $_.passed
        })
    Assert ($matching.Count -eq 1) (
        "Required Note Sound picker check did not pass exactly once: $checkName")
}

$mainSpecsPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainSpecsText = Get-Content -Raw -LiteralPath $mainSpecsPath
Assert ($mainSpecsText -match "79/79 specs passed\.") (
    "Main Specs are not 79/79.")

$guiPath = Join-Path $formalRoot "gui\gui-evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath |
    ConvertFrom-Json -Depth 100
Assert ($gui.schema -ceq (
        "lumachart.windows.avalonia.note-sound-picker-gui-evidence.v1")) (
    "Unexpected Note Sound picker GUI schema.")
Assert ($gui.status -ceq "passed-migration-incomplete") (
    "Formal Note Sound picker GUI status is not passed-migration-incomplete.")
Assert ($gui.scope.windowsAvaloniaOnly -and
    $gui.scope.pureDotnetRelease -and
    -not $gui.scope.ollvmObfuscationPackingVirtualizationOrAotUsed -and
    -not $gui.scope.mobileProjectsBuiltModifiedInstalledOrTested -and
    -not $gui.scope.productionServerMutationPerformed -and
    -not $gui.scope.userApplicationsClosedOrModified) (
    "Formal GUI scope escaped Windows-only plain .NET migration constraints.")
Assert ($gui.input.win32SendInputUsed -and
    -not $gui.input.hardwareInputClaimed -and
    $gui.input.foregroundAutomationExplicitlyAuthorized -and
    $gui.input.foregroundAutomationConsentEnvironmentVerified -and
    $gui.input.uncommittedImeCompositionRequired -eq $false -and
    $gui.input.enterUsedOnlyToActivateFocusedPopupItem) (
    "Formal GUI input provenance or IME safety is invalid.")
Assert ([int]$gui.input.systemIdleBeforeLaunchMilliseconds -ge
    [int]$gui.input.minimumSystemIdleRequiredMilliseconds) (
    "Formal GUI did not satisfy the system-idle launch gate.")
Assert ([int]$gui.input.minimumSystemIdleRequiredMilliseconds -eq 3000 -and
    $gui.input.foregroundProcessOwnershipCheckedBeforeEveryKey -and
    $gui.input.heldModifierConflictCheckedBeforeEveryKey) (
    "Formal GUI lacks foreground or modifier conflict protection.")
Assert (-not $gui.foregroundSafety.windowForcedTopmost -and
    -not $gui.foregroundSafety.persistentTopmostUsed -and
    $gui.foregroundSafety.hwndNotTopmostAppliedBeforeActivation -and
    $gui.foregroundSafety.hwndNotTopmostAppliedAgainDuringCleanup -and
    $gui.foregroundSafety.exactEvidenceProcessOnlyCleanup) (
    "Formal GUI foreground safety allows persistent topmost behavior.")

$automationSafetyPath = Join-Path (
    Join-Path $formalRoot "tests") "gui-automation-safety.json"
$automationSafety = Get-Content -Raw -LiteralPath $automationSafetyPath |
    ConvertFrom-Json -Depth 100
Assert ($automationSafety.schema -ceq
        "lumachart.windows.avalonia.gui-automation-safety.v1" -and
    $automationSafety.status -ceq "passed" -and
    $automationSafety.foregroundAutomationRequiresExplicitUserConsent -and
    [int]$automationSafety.minimumSystemIdleMilliseconds -eq 3000 -and
    $automationSafety.heldModifierGateRequired -and
    -not $automationSafety.persistentTopmostUsed -and
    [int]$automationSafety.captureScriptCount -eq 23) (
    "Windows Avalonia GUI automation safety gate did not pass.")

$actions = @($gui.input.actions)
Assert ([int]$gui.input.setupActivationClickCount -eq 1 -and
    [int]$gui.input.businessActionCount -eq 11 -and
    $actions.Count -eq 11) (
    "Formal GUI physical action count mismatch.")
Assert-PhysicalAction $actions[0] 1 "mouse" "open WPF Note Sound picker"
Assert-PhysicalAction $actions[1] 2 "keyboard" "Down"
Assert-PhysicalAction $actions[2] 3 "keyboard" "Tab"
Assert-PhysicalAction $actions[3] 4 "keyboard" "Shift+Tab"
Assert-PhysicalAction $actions[4] 5 "keyboard" "Home"
Assert-PhysicalAction $actions[5] 6 "keyboard" "End"
Assert-PhysicalAction $actions[6] 7 "keyboard" "Escape"
Assert-PhysicalAction $actions[7] 8 "mouse" "reopen WPF Note Sound picker"
Assert-PhysicalAction $actions[8] 9 "keyboard" "Down"
Assert-PhysicalAction $actions[9] 10 "keyboard" "Enter"
Assert-PhysicalAction $actions[10] 11 "keyboard" "Ctrl+Z"

Assert ($gui.popup.dedicatedPopup -and -not $gui.popup.contextMenuUsed) (
    "Formal GUI did not use the dedicated WPF-parity popup.")
Assert ($gui.popup.initialHelpText -match "PickerOpen=True" -and
    $gui.popup.initialHelpText -match "FocusableCount=2" -and
    $gui.popup.initialHelpText -match "CandidateCount=1" -and
    $gui.popup.initialHelpText -match "FocusedIndex=0" -and
    $gui.popup.initialHelpText -match "Width=330" -and
    $gui.popup.initialHelpText -match "MaxHeight=370" -and
    $gui.popup.initialHelpText -match "ScrollMaxHeight=250" -and
    $gui.popup.initialHelpText -match "VerticalOffset=5") (
    "Formal GUI initial popup automation state is incomplete.")
Assert ($gui.popup.countText -ceq "1 个" -and
    $gui.popup.clearInitiallyFocused -and
    $gui.popup.downFocusedFirstSound -and
    $gui.popup.tabWrappedToClear -and
    $gui.popup.shiftTabWrappedToSound -and
    $gui.popup.homeFocusedClear -and
    $gui.popup.endFocusedSound -and
    $gui.popup.escapeClosed -and
    $gui.popup.escapeRestoredEntryFocus -and
    $gui.popup.keyboardAssignment -ceq "Resound - Nhato.ogg" -and
    $gui.popup.assignmentUndoRestoredOriginal) (
    "Formal GUI keyboard or assignment parity failed.")
Assert ($gui.popup.restoredEntryHelpText -match "PickerOpen=False" -and
    $gui.popup.restoredEntryHelpText -match "FocusedIndex=-1" -and
    $gui.popup.restoredEntryHelpText -match "EscapeRestoredFocus=True" -and
    $gui.popup.restoredEntryHelpText -match "LastNavigation=Escape:close-restore") (
    "Formal GUI Escape focus restoration state is invalid.")

$geometry = $gui.popup.geometry
Assert ([double]$geometry.widthDip -eq 330 -and
    [double]$geometry.maxHeightDip -eq 370 -and
    [double]$geometry.scrollMaxHeightDip -eq 250 -and
    [double]$geometry.verticalOffsetDip -eq 5) (
    "Formal GUI popup DIP geometry differs from WPF 1.1.0.")
Assert ([Math]::Abs(
        [double]$geometry.actualWidthPixels -
        [double]$geometry.expectedWidthPixels) -le 4) (
    "Formal GUI popup physical width mismatch.")
Assert ([Math]::Abs(
        [double]$geometry.actualVerticalOffsetPixels -
        [double]$geometry.expectedVerticalOffsetPixels) -le 2) (
    "Formal GUI popup physical vertical offset mismatch.")
Assert ($geometry.measuredBy -ceq (
        "captured-window border pixels plus strict parity policy specs") -and
    $geometry.borderColor -ceq "#4A5A60") (
    "Formal GUI popup geometry was not measured from the captured border.")

$screenshotExpectations = [ordered]@{
    initial = $ExpectedInitialScreenshotSha256
    keyboardItem = $ExpectedKeyboardItemScreenshotSha256
    escapeRestored = $ExpectedEscapeRestoredScreenshotSha256
    assigned = $ExpectedAssignedScreenshotSha256
}
$screenshots = [ordered]@{}
foreach ($entry in $screenshotExpectations.GetEnumerator()) {
    $screenshot = $gui.screenshots.($entry.Key)
    $file = File-Evidence $screenshot.path
    Assert ($file.sha256 -ceq $entry.Value.ToUpperInvariant()) (
        "Reviewed screenshot hash mismatch: $($entry.Key)")
    Assert ([long]$screenshot.length -eq [long]$file.length -and
        $screenshot.sha256 -ceq $file.sha256 -and
        [int]$screenshot.width -gt 0 -and
        [int]$screenshot.height -gt 0) (
        "Screenshot metadata mismatch: $($entry.Key)")
    $screenshots[$entry.Key] = $file
}

$requiredChartHash =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$requiredSoundHash =
    "00AA7780330A022D7F5D0C4C2BEA23625D31F48BA8CAC2AF25117249BEA05151"
$requiredInstallerHash =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
Assert ($gui.frozenBaselines.realChart.unchanged -and
    $gui.frozenBaselines.realChart.sha256Before -ceq $requiredChartHash -and
    $gui.frozenBaselines.realChart.sha256After -ceq $requiredChartHash) (
    "Frozen real MC changed during formal GUI acceptance.")
Assert ($gui.frozenBaselines.realSound.unchanged -and
    $gui.frozenBaselines.realSound.sha256Before -ceq $requiredSoundHash -and
    $gui.frozenBaselines.realSound.sha256After -ceq $requiredSoundHash) (
    "Frozen real OGG changed during formal GUI acceptance.")
Assert ($gui.frozenBaselines.isolatedChart.unchanged -and
    $gui.frozenBaselines.isolatedChart.sha256Before -ceq $requiredChartHash -and
    $gui.frozenBaselines.isolatedChart.sha256After -ceq $requiredChartHash) (
    "Isolated MC changed after assignment and undo.")
Assert ($gui.frozenBaselines.installer.sha256 -ceq $requiredInstallerHash) (
    "Frozen installer hash changed.")
Assert ($gui.completion.thisSlicePassed -and
    -not $gui.completion.fullWindowsMigrationComplete -and
    -not $gui.completion.userReplacementApproval -and
    -not $gui.completion.otherPlatformAuthorization) (
    "Formal GUI completion boundary is invalid.")

$predecessorPath = Join-Path $projectRoot (
    "artifacts\windows-avalonia-app-update-slice-20260727-r1\" +
    "verification-evidence.json")
$predecessor = File-Evidence $predecessorPath
Assert ($predecessor.sha256 -ceq (
        "2C21E883E86E946A05FFDBB14F732CCE7F409341961CBD2E12114CD9B4A1B7EF")) (
    "Predecessor app-update authority hash changed.")

$sourceFiles = [ordered]@{
    mainWindow = File-Evidence (
        Join-Path $projectRoot "LumaChart.Avalonia\MainWindow.cs")
    policy = File-Evidence (
        Join-Path $projectRoot (
            "LumaChart.Avalonia\Infrastructure\" +
            "WindowsNoteSoundPickerParityPolicy.cs"))
    inspectorPolicy = File-Evidence (
        Join-Path $projectRoot (
            "LumaChart.Avalonia\Infrastructure\" +
            "WindowsInspectorParityPolicy.cs"))
    specs = File-Evidence (
        Join-Path $projectRoot (
            "LumaChart.Avalonia.Specs\" +
            "WindowsNoteSoundPickerParitySpecs.cs"))
    inspectorSpecs = File-Evidence (
        Join-Path $projectRoot (
            "LumaChart.Avalonia.Specs\" +
            "WindowsInspectorParitySpecs.cs"))
    specsProgram = File-Evidence (
        Join-Path $projectRoot "LumaChart.Avalonia.Specs\Program.cs")
    capture = File-Evidence (
        Join-Path $projectRoot (
            "tools\Capture-WindowsAvaloniaNoteSoundPickerGui.ps1"))
    foregroundConsent = File-Evidence (
        Join-Path $projectRoot (
            "tools\Assert-WindowsAvaloniaForegroundAutomationConsent.ps1"))
    automationSafetyVerifier = File-Evidence (
        Join-Path $projectRoot (
            "tools\Test-WindowsAvaloniaGuiAutomationSafety.ps1"))
    verifier = File-Evidence $PSCommandPath
}

$evidence = [ordered]@{
    schema =
        "lumachart.windows.avalonia.note-sound-picker-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    authority = [ordered]@{
        root = [IO.Path]::GetRelativePath($projectRoot, $formalRoot)
        predecessor = $predecessor
        diagnosticPreflightsAreNotAuthority = $true
    }
    scope = [ordered]@{
        windowsAvaloniaOnly = $true
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        frozenWpfModifiedBuiltOrStopped = $false
        frozenInstallerOverwritten = $false
        userApplicationsClosedOrModified = $false
    }
    builds = $builds
    specs = [ordered]@{
        avalonia = File-Evidence $specsPath
        total = $checks.Count
        passed = $passedChecks.Count
        noteSoundPickerChecks = @($noteSoundChecks | ForEach-Object {
                [ordered]@{
                    name = $_.name
                    passed = [bool]$_.passed
                    detail = $_.detail
                }
            })
        main = File-Evidence $mainSpecsPath
        mainPassed = "79/79"
    }
    gui = [ordered]@{
        evidence = File-Evidence $guiPath
        runtime = File-Evidence (
            Join-Path $formalRoot "gui\runtime.json")
        captureLog = File-Evidence (
            Join-Path $formalRoot "gui\capture-run.log")
        actionCount = $actions.Count
        systemIdleGatePassed = $true
        persistentTopmostUsed = $false
        screenshots = $screenshots
        popupGeometry = [ordered]@{
            widthDip = [double]$geometry.widthDip
            actualWidthPixels = [double]$geometry.actualWidthPixels
            expectedWidthPixels = [double]$geometry.expectedWidthPixels
            verticalOffsetDip = [double]$geometry.verticalOffsetDip
            actualVerticalOffsetPixels =
                [double]$geometry.actualVerticalOffsetPixels
            expectedVerticalOffsetPixels =
                [double]$geometry.expectedVerticalOffsetPixels
        }
    }
    sourceFiles = $sourceFiles
    frozenBaselines = [ordered]@{
        realChartSha256 = $requiredChartHash
        realSoundSha256 = $requiredSoundHash
        installerSha256 = $requiredInstallerHash
        allUnchanged = $true
    }
    conclusions = [ordered]@{
        dedicatedWpfParityPopupPassed = $true
        tabShiftTabArrowHomeEndPassed = $true
        escapeCloseAndFocusRestorePassed = $true
        keyboardAssignmentAndSingleUndoPassed = $true
        chineseImeUncommittedCompositionNotRequired = $true
        foregroundAutomationCannotPersistTopmost = $true
        fullWindowsMigrationComplete = $false
        remainingMatrixDifferencesStillExist = $true
        userReplacementApproval = $false
        otherPlatformAuthorization = $false
    }
}

$evidence |
    ConvertTo-Json -Depth 16 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
Get-Content -Raw -LiteralPath $verificationPath
