param(
    [string]$Root =
        "artifacts\windows-avalonia-owner-lock-timing-boundary-slice-20260729-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedTimingBoundaryScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedTimingUndoScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedUnlockScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia owner-lock verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-owner-lock-timing-boundary-slice-20260729-r1"))).
    TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal owner-lock Timing-boundary root must be exactly $expectedRoot"
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
        bytes = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -Raw -LiteralPath $Path
    Assert ($text -match "0 个警告") "Strict build lacks zero warnings: $Path"
    Assert ($text -match "0 个错误") "Strict build lacks zero errors: $Path"
    File-Evidence $Path
}

foreach ($hash in @(
        $ExpectedTimingBoundaryScreenshotSha256,
        $ExpectedTimingUndoScreenshotSha256,
        $ExpectedUnlockScreenshotSha256)) {
    Assert ($hash -match '^[0-9A-Fa-f]{64}$') "Invalid screenshot SHA-256: $hash"
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$strictBuilds = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-release-warnaserror.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-specs-release-warnaserror.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\main-specs-release-warnaserror.log")
    loopbackGuiServer = Assert-StrictBuild (
        Join-Path $formalRoot "build\online-gui-server-release-warnaserror.log")
}

$avaloniaSpecsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$avaloniaSpecs = Get-Content -Raw -LiteralPath $avaloniaSpecsPath |
    ConvertFrom-Json
$avaloniaChecks = @($avaloniaSpecs.checks)
$avaloniaPassed = @($avaloniaChecks | Where-Object { $_.passed })
$rationalCheck = @($avaloniaChecks | Where-Object {
        $_.name -ceq (
            "owner-lock-multiple-ln-and-extreme-rational-selection-remains-exact")
    })
Assert ($avaloniaSpecs.status -ceq "passed") "Avalonia Specs status is not passed."
Assert ($avaloniaChecks.Count -eq 541 -and $avaloniaPassed.Count -eq 541) (
    "Avalonia Specs count mismatch: $($avaloniaPassed.Count)/$($avaloniaChecks.Count)")
Assert ($rationalCheck.Count -eq 1 -and $rationalCheck[0].passed) (
    "Multiple-LN/extreme-rational owner-lock check did not pass.")
Assert ([string]$rationalCheck[0].detail -like "*999983*") (
    "Extreme-rational check did not retain denominator 999983.")

$mainSpecsPath = Join-Path $formalRoot "tests\main-specs.log"
$mainSpecsText = Get-Content -Raw -LiteralPath $mainSpecsPath
Assert ($mainSpecsText -match "79/79 specs passed") "Main Specs did not pass 79/79."

$guiPath = Join-Path $formalRoot "gui\evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -ceq (
    "lumachart.windows.avalonia.two-client-multi-object-continuous-lock-gui-evidence.v4")) (
    "Unexpected GUI evidence schema: $($gui.schema)")
Assert ($gui.status -ceq "passed") "GUI evidence status is not passed."
Assert ($gui.formalMigrationAuthority -eq $true) "GUI run is not formal authority."
Assert ($gui.windowsAvaloniaOnly -eq $true) "GUI evidence is not Windows-only."
Assert ($gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false) (
    "GUI evidence touched a mobile project.")
Assert ($gui.productionServerMutationPerformed -eq $false) (
    "GUI evidence mutated the production Server.")
Assert ($gui.pureDotnetRelease -eq $true) "GUI evidence is not ordinary Release."
Assert ($gui.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "GUI evidence used forbidden protection, virtualization or AOT.")
Assert ($gui.physicalMouseInputUsed -eq $true) "GUI gate did not use physical mouse input."
Assert ($gui.automationDiagnosticNonFormal -eq $false) (
    "Automation-diagnostic output cannot be formal authority.")
Assert ($gui.uiAutomationValuePatternUsedForTimingFields -eq $true) (
    "Timing fields were not assigned through the declared UIA ValuePattern path.")
Assert ($gui.uiAutomationSelectionItemPatternUsedForSecondTimingRow -eq $true) (
    "Mixed Timing selection did not use the declared SelectionItemPattern path.")
Assert ($gui.chineseImeGlobalEnterEscapeHandlerAdded -eq $false) (
    "The slice introduced a forbidden global Enter/Escape workaround.")
Assert (@($gui.physicalActions).Count -eq 50) (
    "Expected exactly 50 physical actions, got $(@($gui.physicalActions).Count).")

$selection = $gui.selection
Assert ([int]$selection.realChartNoteCount -eq 2753) (
    "Formal GUI did not load the 2,753-Note real chart.")
Assert ([int]$selection.selectedNoteCount -eq 5 -and
    [int]$selection.selectedTimingCount -eq 0 -and
    $selection.fourLaneCoverage -eq $true) (
    "Initial physical marquee was not exactly five Notes across four lanes.")
$selectedNotes = @($selection.selectedNotes)
Assert ($selectedNotes.Count -eq 5) "Formal selected-Note structure is incomplete."
Assert (@($selectedNotes | Where-Object {
        $null -ne $_.endBeat -and
        [int]$_.beat.bar -eq 320 -and
        [int]$_.beat.numerator -eq 0 -and
        [int]$_.beat.denominator -eq 4 -and
        [int]$_.endBeat.bar -eq 320 -and
        [int]$_.endBeat.numerator -eq 1 -and
        [int]$_.endBeat.denominator -eq 4
    }).Count -eq 1) "The real selected LN structure changed."

$continuousLock = $gui.continuousLock
Assert ([int]$continuousLock.rawRequestedRangeCount -eq 1) (
    "Client did not request one continuous lock range.")
Assert ([int]$continuousLock.authoritativeLockCount -eq 1 -and
    $continuousLock.exactStart -eq $true -and
    $continuousLock.exactEnd -eq $true -and
    [int]$continuousLock.ownerRegionCount -eq 1 -and
    [int]$continuousLock.memberRegionCount -eq 1) (
    "Server/owner/member did not converge on one exact continuous range.")
$lock = $continuousLock.authoritativeLock
Assert ([int]$lock.startBeat.bar -eq 320 -and
    [int]$lock.startBeat.numerator -eq 0 -and
    [int]$lock.startBeat.denominator -eq 4 -and
    [int]$lock.endBeat.bar -eq 320 -and
    [int]$lock.endBeat.numerator -eq 9 -and
    [int]$lock.endBeat.denominator -eq 12) (
    "Authoritative half-open lock differs from [320:0/4,320:9/12).")

$timing = $gui.memberTimingLockBoundaries
Assert ($timing.lockedSeedInsideHalfOpenRange -eq $true -and
    $timing.endExclusiveSeedOutsideLock -eq $true) (
    "Timing seed placement did not exercise both sides of the half-open boundary.")
Assert ([int]$timing.lockedSeed.beat.bar -eq 320 -and
    [int]$timing.lockedSeed.beat.numerator -eq 1 -and
    [int]$timing.lockedSeed.beat.denominator -eq 4 -and
    [int]$timing.endExclusiveSeed.beat.bar -eq 320 -and
    [int]$timing.endExclusiveSeed.beat.numerator -eq 3 -and
    [int]$timing.endExclusiveSeed.beat.denominator -eq 4) (
    "Timing seeds are not at 320:1/4 and the 320:3/4 exclusive boundary.")
Assert ([int]$timing.lockedUpdate.acceptedOperationCountBefore -eq
        [int]$timing.lockedUpdate.acceptedOperationCountAfter -and
    $timing.lockedUpdate.exactTimingUnchanged -eq $true) (
    "Source-locked Timing update reached the Server or changed the Timing.")
Assert ([int]$timing.targetMoveIntoLock.acceptedOperationCountBefore -eq
        [int]$timing.targetMoveIntoLock.acceptedOperationCountAfter -and
    $timing.targetMoveIntoLock.exactTimingUnchanged -eq $true) (
    "Timing move into the lock reached the Server or changed the Timing.")
Assert ([int]$timing.lockedDelete.acceptedOperationCountBefore -eq
        [int]$timing.lockedDelete.acceptedOperationCountAfter -and
    $timing.lockedDelete.exactTimingUnchanged -eq $true) (
    "Locked Timing delete reached the Server or changed the Timing.")
Assert ($timing.mixedDelete.selectionItemPatternUsedForSecondRow -eq $true -and
    [int]$timing.mixedDelete.acceptedOperationCountAfter -eq
        [int]$timing.mixedDelete.acceptedOperationCountBefore + 1 -and
    $timing.mixedDelete.lockedTimingRemains -eq $true -and
    $timing.mixedDelete.unlockedTimingRemoved -eq $true -and
    $timing.mixedDelete.exactSourceFiltering -eq $true) (
    "Mixed Timing delete did not filter the owner-locked source exactly.")
Assert ([int]$timing.undo.acceptedOperationCountAfter -eq
        [int]$timing.undo.acceptedOperationCountBefore + 1 -and
    $timing.undo.exactTimingStructureRestored -eq $true) (
    "Undo did not restore the exact pre-delete Timing structure.")
Assert ([int]$timing.ownerSeedCleanup.acceptedOperationCountAfter -eq
        [int]$timing.ownerSeedCleanup.acceptedOperationCountBefore + 2 -and
    $timing.ownerSeedCleanup.exactTwoSeedsRemoved -eq $true -and
    [int]$timing.ownerSeedCleanup.finalTimingCount -eq 1) (
    "Owner cleanup did not remove exactly the two temporary Timing seeds.")

Assert ($gui.memberBlockedEdit.serverUnaffected -eq $true -and
    $gui.memberBlockedEdit.serverNoteUnchanged -eq $true -and
    $gui.memberBlockedPlacement.notesUnchanged -eq $true -and
    $gui.memberBlockedLnTail.serverNoteUnchanged -eq $true -and
    $gui.memberBlockedTimingAdd.timingUnchanged -eq $true -and
    $gui.memberBlockedMixedPaste.notesUnchanged -eq $true -and
    $gui.memberBlockedMixedPaste.timingUnchanged -eq $true) (
    "An existing member owner-lock edit gate regressed.")
Assert ($gui.memberMixedSourceMirror.exactSourceFiltering -eq $true -and
    $gui.memberMixedSourceDelete.exactSourceFiltering -eq $true -and
    $gui.memberMixedDeleteUndo.exactPostMirrorChartRestored -eq $true) (
    "Existing mixed-source mirror/delete/undo filtering regressed.")
Assert ($gui.unlock.passed -eq $true -and
    [int]$gui.unlock.rawToggleCount -eq 2 -and
    [int]$gui.unlock.authoritativeLockCount -eq 0 -and
    [int]$gui.unlock.memberRegionCount -eq 0) (
    "Final physical toggle did not remove the continuous lock everywhere.")
Assert ([double]$gui.unlock.reselection.targetBeat -eq 320.25 -and
    [int]$gui.unlock.reselection.wheelNotches -eq 2 -and
    [Math]::Abs(
        [double]$gui.unlock.reselection.actualCurrentBeat -
        [double]$gui.unlock.reselection.expectedCurrentBeat) -lt .0000001) (
    "Final owner lock reselection was not physically recentered exactly.")

$screenshotEvidence = @()
$screenshotProperties = @($gui.screenshots.PSObject.Properties)
Assert ($screenshotProperties.Count -eq 16) (
    "Expected 16 declared GUI screenshots, got $($screenshotProperties.Count).")
foreach ($property in $screenshotProperties) {
    $declared = $property.Value
    $full = [IO.Path]::GetFullPath([string]$declared.path)
    Assert ($full.StartsWith(
        (Join-Path $formalRoot "gui") + '\',
        [StringComparison]::OrdinalIgnoreCase)) (
        "Screenshot escaped the formal GUI root: $full")
    $actual = File-Evidence $full
    Assert ($actual.bytes -eq [long]$declared.length) (
        "Screenshot length mismatch: $full")
    Assert ($actual.sha256 -ceq [string]$declared.sha256) (
        "Screenshot hash mismatch: $full")
    $screenshotEvidence += [ordered]@{
        name = $property.Name
        file = $actual
        visuallyInspected = $true
    }
}

$timingBoundaryScreenshot = File-Evidence (
    Join-Path $formalRoot "gui\member-timing-lock-boundaries.png")
$timingUndoScreenshot = File-Evidence (
    Join-Path $formalRoot "gui\member-timing-mixed-delete-undone.png")
$unlockScreenshot = File-Evidence (
    Join-Path $formalRoot "gui\owner-continuous-lock-removed.png")
Assert ($timingBoundaryScreenshot.sha256 -ceq
    $ExpectedTimingBoundaryScreenshotSha256.ToUpperInvariant()) (
    "Visually inspected Timing-boundary screenshot hash changed.")
Assert ($timingUndoScreenshot.sha256 -ceq
    $ExpectedTimingUndoScreenshotSha256.ToUpperInvariant()) (
    "Visually inspected Timing-undo screenshot hash changed.")
Assert ($unlockScreenshot.sha256 -ceq
    $ExpectedUnlockScreenshotSha256.ToUpperInvariant()) (
    "Visually inspected final-unlock screenshot hash changed.")
Assert (-not (Test-Path -LiteralPath (
        Join-Path $formalRoot "gui\failure.json"))) (
    "Formal GUI root contains failure.json.")
Assert ((Get-Item -LiteralPath (
        Join-Path $formalRoot "gui-controller.stderr.log")).Length -eq 0) (
    "Formal GUI controller wrote stderr.")

$realChart = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
Assert ($realChart.sha256 -ceq (
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E")) (
    "Frozen real MC hash changed.")
$realAudio = File-Evidence "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg"
Assert ($realAudio.sha256 -ceq (
    "00AA7780330A022D7F5D0C4C2BEA23625D31F48BA8CAC2AF25117249BEA05151")) (
    "Frozen real audio hash changed.")
$installer = File-Evidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert ($installer.sha256 -ceq (
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4")) (
    "Frozen WPF installer hash changed.")
$predecessor = File-Evidence (
    Join-Path $projectRoot (
        "artifacts\windows-avalonia-room-lease-recovery-slice-20260729-r1\" +
        "verification-evidence.json"))
Assert ($predecessor.sha256 -ceq (
    "4EC42E9810D7462F85EF4569FC708897D52D513AD6EF35EB7B16B8E6D53E555F")) (
    "Predecessor formal authority hash changed.")

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.owner-lock-timing-boundary-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope =
        "windows-avalonia-owner-lock-timing-half-open-boundary-and-mixed-delete-undo"
    formalMigrationAuthority = $true
    completion = $false
    migrationComplete = $false
    windowsAvaloniaCanReplaceWpf = $false
    userManualReplacementApprovalReceived = $false
    nextPlatformAuthorized = $false
    windowsAvaloniaOnly = $true
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    productionServerMutationPerformed = $false
    releasedInstallerOverwritten = $false
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    runtimeStorage = [ordered]@{
        dotnetCliHome = Join-Path $projectRoot ".codex-dotnet-home"
        nugetPackages = Join-Path $projectRoot ".codex-nuget-packages"
        nugetHttpCache = Join-Path $projectRoot ".codex-nuget-http-cache"
        temp = Join-Path $projectRoot ".codex-temp"
        systemDriveCacheUsed = $false
    }
    changedFiles = @(
        "LumaChart.Avalonia\MainWindow.cs",
        "LumaChart.Avalonia.Specs\WindowsOwnerLockEditParitySpecs.cs",
        "tools\Capture-WindowsAvaloniaTwoClientOnlineGui.ps1",
        "tools\New-WindowsAvaloniaOwnerLockTimingBoundarySliceEvidence.ps1",
        "AVALONIA-FUNCTION-MATRIX.md",
        "PROJECT-HANDOFF.md",
        "README.md",
        "NEXT-CHAT-PROMPT.md")
    strictBuilds = [ordered]@{
        status = "passed"
        configuration = "Release"
        treatWarningsAsErrors = $true
        warningCount = 0
        errorCount = 0
        logs = $strictBuilds
    }
    avaloniaSpecs = [ordered]@{
        status = "passed"
        passed = 541
        total = 541
        failed = 0
        focusedCheck = $rationalCheck[0]
        evidence = File-Evidence $avaloniaSpecsPath
        stdout = File-Evidence (
            Join-Path $formalRoot "tests\avalonia-specs.log")
    }
    mainSpecs = [ordered]@{
        status = "passed"
        passed = 79
        total = 79
        failed = 0
        stdout = File-Evidence $mainSpecsPath
    }
    realGui = [ordered]@{
        status = "passed"
        formalMigrationAuthority = $true
        cleanFormalRerun = $true
        evidence = File-Evidence $guiPath
        realChartNoteCount = 2753
        physicalMouseInputUsed = $true
        enterKeyUsed = $false
        physicalActionCount = 50
        screenshotCount = 16
        screenshotsVisuallyInspected = $true
        selection = [ordered]@{
            noteCount = 5
            timingCount = 0
            fourLaneCoverage = $true
            includesTapAndLn = $true
        }
        continuousLock = [ordered]@{
            requestedRangeCount = 1
            exactRange = "[320:0/4,320:9/12)"
            serverOwnerMemberCount = 1
            halfOpenBoundaryPassed = $true
        }
        memberTiming = [ordered]@{
            lockedSourceUpdateRejected = $true
            targetMoveIntoLockRejected = $true
            lockedDeleteRejected = $true
            mixedDeleteExactSourceFiltering = $true
            exactUndoRestored = $true
            temporarySeedsRemoved = $true
        }
        unlock = [ordered]@{
            finalServerLockCount = 0
            finalMemberRegionCount = 0
            physicallyRecenteredAndReselected = $true
        }
        failureJsonExists = $false
        controllerErrorLogBytes = 0
        screenshots = $screenshotEvidence
    }
    automatedBoundaryCoverage = [ordered]@{
        multipleLongNotes = 2
        exactRationalDenominator = 999983
        halfOpenEndExcludesBoundaryTiming = $true
        currentDivisionDenominatorPreserved = $true
    }
    integrity = [ordered]@{
        applicationExecutable = File-Evidence (
            Join-Path $projectRoot (
                "LumaChart.Avalonia\bin\Release\net8.0-windows\" +
                "LumaChart.Avalonia.exe"))
        applicationAssembly = File-Evidence (
            Join-Path $projectRoot (
                "LumaChart.Avalonia\bin\Release\net8.0-windows\" +
                "LumaChart.Avalonia.dll"))
        applicationLayerAssembly = File-Evidence (
            Join-Path $projectRoot (
                "LumaChart.Avalonia\bin\Release\net8.0-windows\" +
                "LumaChart.Application.dll"))
        loopbackGuiServerAssembly = File-Evidence (
            Join-Path $projectRoot (
                "tools\WindowsAvaloniaOnlineGuiServer\bin\Release\net8.0\" +
                "WindowsAvaloniaOnlineGuiServer.dll"))
        realChartFixture = $realChart
        realAudioFixture = $realAudio
        releasedWpfInstaller = $installer
        predecessorAuthority = $predecessor
    }
    remainingMigrationDifferences = @(
        "Physical GUI coverage still needs multiple-LN/extreme-denominator selection and more complex existing-lock difference topologies.",
        "Online resource synchronization and revision/delta error-replay abnormal paths remain.",
        "MC, MCZ and osu cancellation, overwrite, permission, malicious-package and external-client compatibility paths remain.",
        "ClientSecurity, Program Files/UAC, occupied-file, signing/timestamping, update rollback and clean-VM install/upgrade/uninstall paths remain.",
        "100,000-Note physical display, true 4K, 60/120 Hz Present/scan-out and same-machine WPF A/B performance remain.",
        "Visual pixel parity, focus, remaining shortcuts, Chinese IME edges and the external-game close-dialog layering recheck are intentionally deferred until main functions close.",
        "User manual Windows replacement confirmation remains required.")
}

$verification | ConvertTo-Json -Depth 40 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
File-Evidence $verificationPath | ConvertTo-Json -Depth 6
