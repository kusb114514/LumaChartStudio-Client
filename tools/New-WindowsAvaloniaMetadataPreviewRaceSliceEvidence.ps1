param(
    [string]$Root =
        "artifacts\windows-avalonia-metadata-preview-race-slice-20260727-r2",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedDirtyMergeScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedPreviewScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedRevokedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedDisabledScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedRestoredScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedOwnerFinalScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedMemberFinalScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia metadata/preview verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-metadata-preview-race-slice-20260727-r2"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal metadata/preview root must be exactly $expectedRoot"
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
    File-Evidence $Path
}

$expectedScreenshotHashes = @(
    $ExpectedDirtyMergeScreenshotSha256,
    $ExpectedPreviewScreenshotSha256,
    $ExpectedRevokedScreenshotSha256,
    $ExpectedDisabledScreenshotSha256,
    $ExpectedRestoredScreenshotSha256,
    $ExpectedOwnerFinalScreenshotSha256,
    $ExpectedMemberFinalScreenshotSha256)
foreach ($hash in $expectedScreenshotHashes) {
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
    "metadata-dirty-draft-rebases-over-authoritative-fields-like-wpf",
    "metadata-preview-rebase-preserves-unapplied-local-fields",
    "metadata-scroll-footer-keeps-apply-and-status-physically-reachable")
$focusedChecks = @($checks | Where-Object { $_.name -in $focusedNames })
Assert ($specs.status -eq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 451 -and $passedChecks.Count -eq 451) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
Assert ($focusedChecks.Count -eq 3 -and @($focusedChecks | Where-Object {
    -not $_.passed
}).Count -eq 0) "Metadata/preview focused Specs did not all pass."

$mainLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainText = Get-Content -Raw -LiteralPath $mainLogPath
Assert ($mainText -match "79/79 specs passed") "Main Specs did not pass 79/79."

$guiPath = Join-Path $formalRoot "gui\evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -eq (
    "lumachart.windows.avalonia.metadata-preview-race-gui-evidence.v1")) (
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
Assert (@($gui.physicalActions).Count -eq 33) "Expected exactly 33 physical actions."

$race = $gui.metadataPreviewRace
Assert ($race.initialRole -ceq "editor" -and
    $race.initialCanEditMetadata -eq $false) (
    "Initial member metadata permission differs from the expected baseline.")
$grantMessage = (
    "谱面信息：允许编辑`nEffect / Timing Edit：不可编辑`nNote：允许编辑")
$revokeMessage = (
    "谱面信息：不可编辑`nEffect / Timing Edit：不可编辑`nNote：允许编辑")
Assert ($race.grantMessage -ceq $grantMessage -and
    $race.restoreMessage -ceq $grantMessage -and
    $race.revokeMessage -ceq $revokeMessage) (
    "Metadata permission notice copy differs from WPF.")
Assert ($race.dirtyMergeStatus -ceq (
    "远端谱面信息已同步；未应用的本地输入已保留")) (
    "Dirty metadata rebase status differs from WPF.")
Assert ($race.titlePreservedAfterRemoteArtist -eq $true -and
    $race.titlePreservedAfterPreviewHere -eq $true -and
    $race.artistPreservedAfterPreviewHere -eq $true) (
    "A local or authoritative metadata field was lost during rebase.")
Assert ([long]$race.chosenPreviewTime -eq
    [long]$race.baselinePreviewTime - 20000 -and
    $race.previewChanged -eq $true) (
    "Preview Here did not make the exact expected timeline change.")
Assert ([long]$race.disabledAttemptOperationCountBefore -eq 2 -and
    [long]$race.disabledAttemptOperationCountAfter -eq 2 -and
    $race.disabledAttemptChartEqual -eq $true) (
    "Revoked metadata actions changed the authoritative room.")
Assert ([long]$race.acceptedOperationCountBefore -eq 0 -and
    [long]$race.acceptedOperationCountAfter -eq 3 -and
    [long]$race.revisionAfter -eq [long]$race.revisionBefore + 3) (
    "Metadata race did not produce exactly three accepted revisions.")
Assert ($race.finalTitle -ceq $race.localPendingTitle -and
    $race.finalArtist -ceq $race.ownerRemoteArtist -and
    [long]$race.finalPreviewTime -eq [long]$race.chosenPreviewTime) (
    "Final metadata did not preserve the intended Title/Artist/Preview fields.")
Assert ($race.otherMetadataFieldsEqual -eq $true -and
    $race.notesTimingLocksAndKeyCountEqual -eq $true -and
    $race.ownerMemberUiConverged -eq $true -and
    $race.passed -eq $true) (
    "Metadata race structural or GUI convergence check failed.")
Assert ($race.ownerFinalStatus -like "*revision $($race.revisionAfter)*" -and
    $race.memberFinalStatus -like "*revision $($race.revisionAfter)*") (
    "A final convergence screenshot was captured before both clients displayed the final revision.")

$operations = @($race.acceptedMetadataOperations)
Assert ($operations.Count -eq 3) "Expected exactly three Metadata operations."
$expectedActors = @(4101, 4202, 4202)
for ($index = 0; $index -lt $operations.Count; $index++) {
    $operation = $operations[$index]
    Assert ([long]$operation.revision -eq [long]$race.revisionBefore + $index + 1) (
        "Metadata operation revision sequence is not contiguous.")
    Assert ([long]$operation.actorUserId -eq $expectedActors[$index]) (
        "Metadata operation actor sequence is incorrect.")
    Assert ([long]$operation.upsertNoteCount -eq 0 -and
        [long]$operation.deleteNoteCount -eq 0 -and
        [long]$operation.upsertTimingCount -eq 0 -and
        [long]$operation.deleteTimingCount -eq 0 -and
        $null -eq $operation.keyCount) (
        "A Metadata operation mutated Notes, Timing, or KeyCount.")
}
Assert ($operations[0].metadata.title -ceq $race.baselineTitle -and
    $operations[0].metadata.artist -ceq $race.ownerRemoteArtist -and
    [long]$operations[0].metadata.previewTime -eq [long]$race.baselinePreviewTime) (
    "Owner remote Artist operation carried unexpected fields.")
Assert ($operations[1].metadata.title -ceq $race.baselineTitle -and
    $operations[1].metadata.artist -ceq $race.ownerRemoteArtist -and
    [long]$operations[1].metadata.previewTime -eq [long]$race.chosenPreviewTime) (
    "Member Preview Here operation carried unexpected fields.")
Assert ($operations[2].metadata.title -ceq $race.localPendingTitle -and
    $operations[2].metadata.artist -ceq $race.ownerRemoteArtist -and
    [long]$operations[2].metadata.previewTime -eq [long]$race.chosenPreviewTime) (
    "Member final Title operation lost authoritative fields.")

$finalState = $gui.room.finalServerState
Assert ([long]$finalState.revision -eq [long]$race.revisionAfter -and
    [long]$finalState.acceptedOperationCount -eq 3) (
    "Final Server revision or operation count is incorrect.")
Assert ([long]$finalState.chart.noteCount -eq 2753 -and
    [long]$finalState.chart.timingCount -eq 1 -and
    [long]$finalState.chart.keyCount -eq 4) (
    "Final Server chart structure changed outside Metadata.")
Assert ($finalState.chart.metadata.title -ceq $race.finalTitle -and
    $finalState.chart.metadata.artist -ceq $race.finalArtist -and
    [long]$finalState.chart.metadata.previewTime -eq [long]$race.finalPreviewTime) (
    "Final Server metadata differs from GUI race evidence.")
Assert ([long]$finalState.resourceEntryCount -eq 3 -and
    [long]$finalState.downloadedBlobCount -ge 3) (
    "Room resources were not fully synchronized.")

$screenshotEvidence = @()
$screenshotProperties = @($gui.screenshots.PSObject.Properties)
Assert ($screenshotProperties.Count -eq 19) (
    "Expected 19 declared GUI screenshots, got $($screenshotProperties.Count).")
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

$expectedKeyScreenshots = [ordered]@{
    "member-metadata-dirty-draft-merged" =
        $ExpectedDirtyMergeScreenshotSha256
    "member-preview-here-preserves-draft" =
        $ExpectedPreviewScreenshotSha256
    "member-metadata-permission-revoked" =
        $ExpectedRevokedScreenshotSha256
    "member-metadata-draft-disabled-after-revoke" =
        $ExpectedDisabledScreenshotSha256
    "member-metadata-permission-restored" =
        $ExpectedRestoredScreenshotSha256
    "owner-metadata-final-convergence" =
        $ExpectedOwnerFinalScreenshotSha256
    "member-metadata-final-convergence" =
        $ExpectedMemberFinalScreenshotSha256
}
foreach ($entry in $expectedKeyScreenshots.GetEnumerator()) {
    $screenshot = @($screenshotEvidence | Where-Object {
        $_.name -ceq $entry.Key
    })
    Assert ($screenshot.Count -eq 1) "Missing key screenshot: $($entry.Key)"
    Assert ($screenshot[0].file.sha256 -ceq
        $entry.Value.ToUpperInvariant()) (
        "Formal key screenshot hash changed: $($entry.Key)")
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
        "artifacts\windows-avalonia-viewer-editor-role-slice-20260727-r5\" +
        "verification-evidence.json"))
Assert ($predecessor.sha256 -ceq (
    "F19E100AD024B5F175A926C4284C849A4C3787B32501BBE2687360966EAC9181")) (
    "Predecessor authority hash changed.")

$sourcePaths = @(
    "LumaChart.Application\Editing\ChartMetadataEditingService.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsInspectorParityPolicy.cs",
    "LumaChart.Avalonia.Specs\WindowsMetadataEditorSpecs.cs",
    "LumaChart.Avalonia.Specs\WindowsInspectorParitySpecs.cs",
    "tools\Capture-WindowsAvaloniaTwoClientOnlineGui.ps1",
    "tools\WindowsAvaloniaOnlineGuiServer\Program.cs",
    "tools\New-WindowsAvaloniaMetadataPreviewRaceSliceEvidence.ps1")
$sourceEvidence = @($sourcePaths | ForEach-Object {
    File-Evidence (Join-Path $projectRoot $_)
})

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
    schema = "lumachart.windows.avalonia.metadata-preview-race-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        windowsAvaloniaOnly = $true
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        formalAuthority = "metadata-preview-race-r2"
    }
    builds = [ordered]@{
        warnings = 0
        errors = 0
        logs = $builds
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 451
            total = 451
            failed = 0
            focusedChecks = $focusedChecks
            evidence = File-Evidence $specsPath
            log = File-Evidence (
                Join-Path $formalRoot "tests\avalonia-specs-run.log")
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
        dirtyDraftRebasePassed = $true
        previewHereRebasePassed = $true
        metadataPermissionRacePassed = $true
        physicalActionCount = 33
        screenshotCount = 19
        serverOperationCountBefore = 0
        serverOperationCountAfter = 3
        authoritativeChartChange = "metadata-only-title-artist-preview"
        ownerMemberConverged = $true
        manualVisualReviewPassed = $true
        evidence = File-Evidence $guiPath
        screenshots = $screenshotEvidence
        leftoverEvidenceOwnedProcessIds = $leftovers
    }
    source = [ordered]@{
        changedFiles = $sourcePaths
        files = $sourceEvidence
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
