param(
    [string]$ChartPath,
    [string]$EvidencePath,
    [string]$InteractionEvidencePath,
    [string]$ApplicationExecutablePath,
    [Parameter(Mandatory = $true)][string]$ScreenshotPath,
    [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
    [Parameter(Mandatory = $true)][string]$LocalDataRoot,
    [Parameter(Mandatory = $true)][string]$EditingRoot,
    [switch]$LibraryHome,
    [switch]$ExerciseLibraryNoResults,
    [string]$LibraryNoResultsQuery = "zzzz-lumachart-no-result-zzzz",
    [switch]$FocusLibraryDeletion,
    [switch]$ExerciseLibraryDeleteCancel,
    [switch]$ExerciseLibraryDeleteConfirm,
    [switch]$ExerciseLibraryBatchDeleteConfirm,
    [switch]$ExerciseLibraryOpenDocumentBlock,
    [string]$LibraryDeleteTargetName,
    [string]$LibraryDeleteTargetPath,
    [string]$LibraryDeleteSecondTargetName,
    [string]$LibraryDeleteSecondTargetPath,
    [string]$LibraryContextMenuScreenshotPath,
    [string]$LibraryDeleteDialogScreenshotPath,
    [switch]$FocusChartValidation,
    [switch]$ExerciseChartValidation,
    [string]$ChartValidationManualDialogScreenshotPath,
    [string]$ChartValidationSaveBlockedDialogScreenshotPath,
    [switch]$FocusTiming,
    [switch]$FocusHoldTail,
    [switch]$FocusNoteProperty,
    [string]$FocusNotePropertyBeat,
    [switch]$FocusGroup,
    [string]$FocusGroupBeat,
    [switch]$FocusProEditor,
    [switch]$FocusKeySound,
    [switch]$FocusDisplayScale,
    [switch]$EnableBackgroundWaveform,
    [switch]$EnableBackgroundSpectrogram,
    [switch]$ExerciseEdgeScroll,
    [switch]$ExerciseHoldTailResize,
    [switch]$ExerciseLongToTap,
    [switch]$ExerciseNoteProperty,
    [switch]$SaveAfterNoteProperty,
    [switch]$ExerciseSourceSaveFailure,
    [string]$SourceSaveFailureDialogScreenshotPath,
    [switch]$DeriveNotePropertyFromSelection,
    [string]$NotePropertyBeat = "258:3/8",
    [string]$NotePropertyEndBeat = "258:7/8",
    [string]$NotePropertyLane = "2",
    [string]$NotePropertyVolume = "73",
    [string]$NotePropertySound = "",
    [string]$NotePropertyGroup = "7",
    [switch]$ExerciseGroupAssign,
    [switch]$SaveAfterGroupAssign,
    [switch]$ExerciseGroupVisibility,
    [switch]$ExerciseGroupPlacement,
    [string]$HoldPlacementPreviewScreenshotPath,
    [switch]$ExerciseProEditorReveal,
    [switch]$ExerciseProEditorPan,
    [switch]$ExerciseProEditorEdit,
    [switch]$SaveAfterProEditorEdit,
    [switch]$ExerciseProEditorSaveAsOsu,
    [switch]$ExerciseMalodyFullPackageExport,
    [string]$MalodyFullPackageExportPath,
    [string]$MalodyFullPackageSourceRoot,
    [string]$MalodyFullPackageOptionsScreenshotPath,
    [string]$MalodyFullPackageResultScreenshotPath,
    [string]$MalodyFullPackageFreshImportEvidencePath,
    [string]$MalodyFullPackageFreshImportInteractionEvidencePath,
    [string]$MalodyFullPackageFreshImportDialogScreenshotPath,
    [string]$MalodyFullPackageFreshImportScreenshotPath,
    [string]$MalodyFullPackageFreshImportWorkspaceRoot,
    [string]$MalodyFullPackageFreshImportLocalDataRoot,
    [string]$MalodyFullPackageFreshImportEditingRoot,
    [ValidateRange(1, 256)][int]$MalodyFullPackageExpectedChartCount = 8,
    [switch]$ExerciseOsuFullPackageExport,
    [switch]$ExerciseMalodyToOsuFullPackageExport,
    [switch]$ExerciseOsuToMalodyFullPackageExport,
    [switch]$ExerciseChartExportModes,
    [string]$ChartExportModesDefaultScreenshotPath,
    [string]$ChartExportModesSingleChartScreenshotPath,
    [string]$ChartExportModesSingleRateScreenshotPath,
    [string]$ChartExportModesRatePackScreenshotPath,
    [string]$ChartExportModesHiddenValidationScreenshotPath,
    [switch]$ChartExportModesContinueToExport,
    [ValidateSet("Malody", "OsuMania")][string]$ChartExportModesExportFormat = "Malody",
    [ValidateSet("SingleChart", "SingleRatePackage", "RatePack")][string]$ChartExportModesExportMode = "SingleRatePackage",
    [string]$ChartExportModesExportPath,
    [ValidateRange(0.2, 3.0)][double]$ChartExportModesExportRate = 1.2,
    [ValidateRange(0.2, 3.0)][double]$ChartExportModesExportMinimumRate = 0.8,
    [ValidateRange(0.2, 3.0)][double]$ChartExportModesExportMaximumRate = 1.2,
    [ValidateRange(0.01, 1.0)][double]$ChartExportModesExportRateStep = 0.1,
    [bool]$ChartExportModesExportPreservePitch = $false,
    [string]$ChartExportModesExportResultScreenshotPath,
    [ValidateSet("None", "CancelThenCorrectPickerSuffixAndOverwriteLongPath")]
    [string]$ChartExportModesNativeSaveEdgeScenario = "None",
    [string]$ChartExportModesCancelScreenshotPath,
    [string]$ChartExportModesOverwriteScreenshotPath,
    [string]$ChartExportModesForbiddenOutputPath,
    [string]$OsuFullPackageExportPath,
    [string]$OsuFullPackageSourceRoot,
    [string]$OsuFullPackageOptionsScreenshotPath,
    [string]$OsuFullPackageResultScreenshotPath,
    [string]$OsuFullPackageFreshImportEvidencePath,
    [string]$OsuFullPackageFreshImportInteractionEvidencePath,
    [string]$OsuFullPackageFreshImportDialogScreenshotPath,
    [string]$OsuFullPackageFreshImportFirstCalibrationScreenshotPath,
    [string]$OsuFullPackageFreshImportSecondCalibrationScreenshotPath,
    [string]$OsuFullPackageFreshImportScreenshotPath,
    [string]$OsuFullPackageFreshImportWorkspaceRoot,
    [string]$OsuFullPackageFreshImportLocalDataRoot,
    [string]$OsuFullPackageFreshImportEditingRoot,
    [ValidateRange(1, 256)][int]$OsuFullPackageExpectedChartCount = 2,
    [ValidateRange(0, 10)][double]$OsuFullPackageOverallDifficulty = 8.75,
    [ValidateRange(0, 10)][double]$OsuFullPackageHpDrainRate = 9,
    [switch]$ExerciseKeySoundRuntime,
    [switch]$ExerciseDisplayScale,
    [switch]$ExerciseAudioPanels,
    [switch]$FocusAudioPanels,
    [ValidateRange(50, 200)][double]$DisplayScaleUiPercent = 135,
    [ValidateRange(50, 200)][double]$DisplayScaleFontPercent = 125,
    [switch]$AllowExistingLocalDataRoot,
    [switch]$AllowExistingEditingRoot,
    [switch]$AllowCodexTempEvidenceRoot,
    [string]$ProEditorSaveAsOsuPath,
    [string]$GroupId = "7",
    [ValidateRange(0, 1000000)][int]$SyntheticNoteCount = 0,
    [ValidateRange(1000, 60000)][int]$InteractionDelayMilliseconds = 1800,
    [ValidateRange(10, 120)][int]$TimeoutSeconds = 45
)

if ($PSVersionTable.PSEdition -ne "Core") {
    throw "Windows Avalonia GUI capture requires PowerShell Core. Run this script with pwsh."
}
if (-not $IsWindows) {
    throw "Windows Avalonia GUI capture is Windows-only."
}

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$artifactBoundary = [IO.Path]::GetFullPath((Join-Path $projectRoot "artifacts")).TrimEnd('\') + '\'
$codexTempBoundary =
    [IO.Path]::GetFullPath((Join-Path $projectRoot ".codex-temp")).TrimEnd('\') + '\'

function Resolve-ArtifactPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = [IO.Path]::GetFullPath($Path)
    $insideArtifacts = $resolved.StartsWith(
        $artifactBoundary,
        [StringComparison]::OrdinalIgnoreCase)
    $insideCodexTemp = $AllowCodexTempEvidenceRoot -and $resolved.StartsWith(
        $codexTempBoundary,
        [StringComparison]::OrdinalIgnoreCase)
    if (-not $insideArtifacts -and -not $insideCodexTemp) {
        throw (
            "Evidence paths and isolated GUI roots must stay under " +
            $(if ($AllowCodexTempEvidenceRoot) {
                "$artifactBoundary or $codexTempBoundary"
            } else { $artifactBoundary }))
    }
    return $resolved
}

$chartFullPath = $null
if (-not $LibraryHome) {
    if ([string]::IsNullOrWhiteSpace($ChartPath) -or [string]::IsNullOrWhiteSpace($EvidencePath)) {
        throw "ChartPath and EvidencePath are required for editor GUI capture."
    }
    $chartFullPath = [IO.Path]::GetFullPath($ChartPath)
    if (-not (Test-Path -LiteralPath $chartFullPath -PathType Leaf)) {
        throw "Chart fixture does not exist: $chartFullPath"
    }
    $chartExtension = [IO.Path]::GetExtension($chartFullPath)
    if ($chartExtension -notin ".mc", ".osu") {
        throw "GUI fixture must be a real MC or osu chart."
    }
}

$evidenceFullPath = if ($LibraryHome) { $null } else { Resolve-ArtifactPath $EvidencePath }
$interactionEvidenceFullPath = if ([string]::IsNullOrWhiteSpace($InteractionEvidencePath)) {
    $null
} else {
    Resolve-ArtifactPath $InteractionEvidencePath
}
$groupExerciseEnabled = $ExerciseGroupAssign -or $ExerciseGroupVisibility -or $ExerciseGroupPlacement
if (-not [string]::IsNullOrWhiteSpace($HoldPlacementPreviewScreenshotPath) -and
    -not $ExerciseGroupPlacement) {
    throw "HoldPlacementPreviewScreenshotPath requires ExerciseGroupPlacement."
}
$holdPlacementPreviewScreenshotFullPath =
    if ([string]::IsNullOrWhiteSpace($HoldPlacementPreviewScreenshotPath)) {
        $null
    }
    else {
        [IO.Path]::GetFullPath($HoldPlacementPreviewScreenshotPath)
    }
$proEditorExerciseEnabled = $ExerciseProEditorReveal -or $ExerciseProEditorPan -or $ExerciseProEditorEdit -or
    $ExerciseProEditorSaveAsOsu
$libraryDeleteExerciseEnabled = $ExerciseLibraryDeleteCancel -or $ExerciseLibraryDeleteConfirm -or
    $ExerciseLibraryBatchDeleteConfirm -or $ExerciseLibraryOpenDocumentBlock
$chartValidationExerciseEnabled = [bool]$ExerciseChartValidation
$chartExportModesExerciseEnabled = [bool]$ExerciseChartExportModes
$chartExportModesActualExportEnabled = [bool]($chartExportModesExerciseEnabled -and
    $ChartExportModesContinueToExport)
$chartExportModesNativeSaveEdgeEnabled =
    $ChartExportModesNativeSaveEdgeScenario -ne "None"
$fullPackageExportExerciseEnabled = [bool]($ExerciseMalodyFullPackageExport -or
    $ExerciseOsuFullPackageExport -or $ExerciseMalodyToOsuFullPackageExport -or
    $ExerciseOsuToMalodyFullPackageExport)
$targetOsuFullPackage = [bool]($ExerciseOsuFullPackageExport -or
    $ExerciseMalodyToOsuFullPackageExport)
$sourceOsuFullPackage = [bool]($ExerciseOsuFullPackageExport -or
    $ExerciseOsuToMalodyFullPackageExport)
$malodyToOsuFullPackage = [bool]$ExerciseMalodyToOsuFullPackageExport
$osuToMalodyFullPackage = [bool]$ExerciseOsuToMalodyFullPackageExport
$crossFormatFullPackage = [bool]($malodyToOsuFullPackage -or $osuToMalodyFullPackage)
$fullPackageExerciseCount = @(
    @(
        $ExerciseMalodyFullPackageExport,
        $ExerciseOsuFullPackageExport,
        $ExerciseMalodyToOsuFullPackageExport,
        $ExerciseOsuToMalodyFullPackageExport) |
        Where-Object { [bool]$_ }
    ).Count
if ($fullPackageExerciseCount -gt 1) {
    throw "Malody, osu!, Malody-to-osu!, and osu!-to-Malody FullPackage GUI exercises must use separate captures."
}
if (($ExerciseLibraryNoResults -or $ExerciseEdgeScroll -or $ExerciseHoldTailResize -or $ExerciseLongToTap -or $ExerciseNoteProperty -or
     $groupExerciseEnabled -or $proEditorExerciseEnabled -or $ExerciseKeySoundRuntime -or
     $ExerciseDisplayScale -or $ExerciseAudioPanels -or $libraryDeleteExerciseEnabled -or
     $chartValidationExerciseEnabled -or $chartExportModesExerciseEnabled -or
     $fullPackageExportExerciseEnabled) -and
    -not $interactionEvidenceFullPath -and
    -not $chartExportModesActualExportEnabled) {
    throw "InteractionEvidencePath is required when an actual pointer exercise is enabled."
}
$exerciseCount = (@(
        $ExerciseLibraryNoResults,
        $ExerciseLibraryDeleteCancel,
        $ExerciseLibraryDeleteConfirm,
        $ExerciseLibraryBatchDeleteConfirm,
        $ExerciseLibraryOpenDocumentBlock,
        $ExerciseChartValidation,
        $ExerciseEdgeScroll,
        $ExerciseHoldTailResize,
        $ExerciseLongToTap,
        $ExerciseNoteProperty,
        $ExerciseGroupAssign,
        $ExerciseGroupVisibility,
        $ExerciseGroupPlacement,
        $ExerciseProEditorReveal,
        $ExerciseProEditorPan,
        $ExerciseProEditorEdit,
        $ExerciseProEditorSaveAsOsu,
        $ExerciseChartExportModes,
        $fullPackageExportExerciseEnabled,
        $ExerciseKeySoundRuntime,
        $ExerciseDisplayScale,
        $ExerciseAudioPanels) |
    Where-Object { [bool]$_ }).Count
if ($exerciseCount -gt 1) {
    throw "Each pointer/UI exercise must use a separate GUI capture."
}
if ($FocusAudioPanels -and $exerciseCount -gt 0) {
    throw "FocusAudioPanels is non-interactive and cannot be combined with any pointer/UI exercise."
}
if ($ExerciseLibraryNoResults -and -not $LibraryHome) {
    throw "ExerciseLibraryNoResults is only valid with LibraryHome."
}
if ($ExerciseLibraryNoResults -and [string]::IsNullOrWhiteSpace($LibraryNoResultsQuery)) {
    throw "LibraryNoResultsQuery must not be empty."
}
if ($libraryDeleteExerciseEnabled -and -not $FocusLibraryDeletion) {
    throw "FocusLibraryDeletion is required for library delete exercises."
}
if ($chartValidationExerciseEnabled -and -not $FocusChartValidation) {
    throw "FocusChartValidation is required for the chart-validation exercise."
}
if ($libraryDeleteExerciseEnabled -and
    ([string]::IsNullOrWhiteSpace($LibraryDeleteTargetName) -or
     [string]::IsNullOrWhiteSpace($LibraryDeleteTargetPath) -or
     [string]::IsNullOrWhiteSpace($LibraryContextMenuScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($LibraryDeleteDialogScreenshotPath))) {
    throw "Library delete exercises require target name/path and both intermediate screenshot paths."
}
if ($ExerciseLibraryBatchDeleteConfirm -and
    ([string]::IsNullOrWhiteSpace($LibraryDeleteSecondTargetName) -or
     [string]::IsNullOrWhiteSpace($LibraryDeleteSecondTargetPath))) {
    throw "The library batch-delete exercise requires a second target name/path."
}
if (-not $ExerciseLibraryBatchDeleteConfirm -and
    (-not [string]::IsNullOrWhiteSpace($LibraryDeleteSecondTargetName) -or
     -not [string]::IsNullOrWhiteSpace($LibraryDeleteSecondTargetPath))) {
    throw "The second library target name/path is reserved for the batch-delete exercise."
}
if ($chartValidationExerciseEnabled -and
    ([string]::IsNullOrWhiteSpace($ChartValidationManualDialogScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($ChartValidationSaveBlockedDialogScreenshotPath))) {
    throw "Chart-validation exercise requires both manual-check and save-blocked dialog screenshot paths."
}
if (($ExerciseHoldTailResize -or $ExerciseLongToTap) -and -not $FocusHoldTail) {
    throw "FocusHoldTail is required for LN-tail and Note-transform exercises."
}
if ($ExerciseNoteProperty -and -not $FocusNoteProperty) {
    throw "FocusNoteProperty is required for the Note-property exercise."
}
if ($SaveAfterNoteProperty -and -not $ExerciseNoteProperty) {
    throw "SaveAfterNoteProperty is only valid with ExerciseNoteProperty."
}
if ($ExerciseSourceSaveFailure -and -not $ExerciseNoteProperty) {
    throw "ExerciseSourceSaveFailure is only valid with ExerciseNoteProperty."
}
if ($ExerciseSourceSaveFailure -and $SaveAfterNoteProperty) {
    throw "ExerciseSourceSaveFailure and SaveAfterNoteProperty are mutually exclusive."
}
if ($ExerciseSourceSaveFailure -and
    [string]::IsNullOrWhiteSpace($SourceSaveFailureDialogScreenshotPath)) {
    throw "ExerciseSourceSaveFailure requires SourceSaveFailureDialogScreenshotPath."
}
if ($ExerciseSourceSaveFailure -and $InteractionDelayMilliseconds -lt 12000) {
    throw "ExerciseSourceSaveFailure requires InteractionDelayMilliseconds of at least 12000 ms."
}
if ($DeriveNotePropertyFromSelection -and -not $ExerciseNoteProperty) {
    throw "DeriveNotePropertyFromSelection is only valid with ExerciseNoteProperty."
}
if ($groupExerciseEnabled -and -not $FocusGroup) {
    throw "FocusGroup is required for Group Manager exercises."
}
if ($proEditorExerciseEnabled -and -not $FocusProEditor) {
    throw "FocusProEditor is required for ProEditor exercises."
}
if ($ExerciseKeySoundRuntime -and -not $FocusKeySound) {
    throw "FocusKeySound is required for the Key-sound runtime exercise."
}
if ($ExerciseDisplayScale -and -not $FocusDisplayScale) {
    throw "FocusDisplayScale is required for the display-scale exercise."
}
if ($ExerciseAudioPanels -and $LibraryHome) {
    throw "ExerciseAudioPanels requires a real chart editor capture."
}
if ($ExerciseAudioPanels -and $InteractionDelayMilliseconds -lt 2200) {
    throw "ExerciseAudioPanels requires InteractionDelayMilliseconds of at least 2200 ms."
}
if ($libraryDeleteExerciseEnabled -and $InteractionDelayMilliseconds -lt 6000) {
    throw "Library deletion exercises require InteractionDelayMilliseconds of at least 6000 ms."
}
if ($ExerciseLibraryOpenDocumentBlock -and $InteractionDelayMilliseconds -lt 12000) {
    throw "The open-document deletion-block exercise requires InteractionDelayMilliseconds of at least 12000 ms."
}
if ($ExerciseLibraryBatchDeleteConfirm -and $InteractionDelayMilliseconds -lt 18000) {
    throw "The batch-delete exercise requires InteractionDelayMilliseconds of at least 18000 ms."
}
if ($chartValidationExerciseEnabled -and $InteractionDelayMilliseconds -lt 16000) {
    throw "Chart-validation exercise requires InteractionDelayMilliseconds of at least 16000 ms."
}
if ($chartExportModesExerciseEnabled -and $InteractionDelayMilliseconds -lt 26000) {
    throw "Chart-export mode exercise requires InteractionDelayMilliseconds of at least 26000 ms."
}
if ($chartExportModesActualExportEnabled -and $InteractionDelayMilliseconds -lt 40000) {
    throw "Chart-export mode exercise with an actual export requires InteractionDelayMilliseconds of at least 40000 ms."
}
if ($fullPackageExportExerciseEnabled -and $InteractionDelayMilliseconds -lt 28000) {
    throw "FullPackage export requires InteractionDelayMilliseconds of at least 28000 ms."
}
if ($LibraryHome -and $FocusKeySound) {
    throw "FocusKeySound requires a real chart editor capture."
}
if ($LibraryHome -and $FocusDisplayScale) {
    throw "FocusDisplayScale requires a real chart editor capture."
}
if ($LibraryHome -and $FocusAudioPanels) {
    throw "FocusAudioPanels requires a real chart editor capture."
}
if ($LibraryHome -and $FocusLibraryDeletion) {
    throw "FocusLibraryDeletion requires a real chart editor capture."
}
if ($LibraryHome -and $FocusChartValidation) {
    throw "FocusChartValidation requires a real chart editor capture."
}
if ($FocusChartValidation -and $SyntheticNoteCount -gt 0) {
    throw "FocusChartValidation requires an unchanged real-chart baseline and cannot use SyntheticNoteCount."
}
if ($AllowExistingLocalDataRoot -and
    -not ($FocusDisplayScale -or $FocusAudioPanels -or $FocusLibraryDeletion -or
          $FocusChartValidation -or $AllowExistingEditingRoot)) {
    throw "AllowExistingLocalDataRoot is reserved for persisted-settings or explicit editing-recovery gates."
}
if ($AllowExistingEditingRoot -and -not $AllowExistingLocalDataRoot) {
    throw "AllowExistingEditingRoot requires AllowExistingLocalDataRoot for one isolated restart gate."
}
if ($SaveAfterProEditorEdit -and -not $ExerciseProEditorEdit) {
    throw "SaveAfterProEditorEdit is only valid with ExerciseProEditorEdit."
}
if ($ExerciseProEditorSaveAsOsu -and [string]::IsNullOrWhiteSpace($ProEditorSaveAsOsuPath)) {
    throw "ProEditorSaveAsOsuPath is required with a ProEditor native Save As exercise."
}
if ($fullPackageExportExerciseEnabled -and -not $FocusNoteProperty) {
    throw "FullPackage export requires FocusNoteProperty for deterministic dirty exact-Beat injection."
}
if ($fullPackageExportExerciseEnabled -and
    [string]::IsNullOrWhiteSpace($FocusNotePropertyBeat)) {
    throw "FullPackage export requires an explicit FocusNotePropertyBeat."
}
if ($fullPackageExportExerciseEnabled -and $LibraryHome) {
    throw "FullPackage export requires a real chart editor capture."
}
if ($chartExportModesExerciseEnabled -and $LibraryHome) {
    throw "Chart-export mode exercise requires a real chart editor capture."
}
if ($chartExportModesExerciseEnabled -and
    ([string]::IsNullOrWhiteSpace($ChartExportModesDefaultScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($ChartExportModesSingleChartScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($ChartExportModesSingleRateScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($ChartExportModesRatePackScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($ChartExportModesHiddenValidationScreenshotPath))) {
    throw "Chart-export mode exercise requires default, SingleChart, SingleRate, RatePack, and hidden-validation screenshots."
}
if ($ChartExportModesContinueToExport -and -not $chartExportModesExerciseEnabled) {
    throw "ChartExportModesContinueToExport is only valid with ExerciseChartExportModes."
}
if ($chartExportModesNativeSaveEdgeEnabled -and -not $chartExportModesActualExportEnabled) {
    throw "A chart-export native Save edge scenario requires an actual chart-export mode exercise."
}
if ($chartExportModesActualExportEnabled -and
    ([string]::IsNullOrWhiteSpace($ChartExportModesExportPath) -or
     [string]::IsNullOrWhiteSpace($ChartExportModesExportResultScreenshotPath))) {
    throw "An actual chart-export mode exercise requires its destination and result screenshot paths."
}
if ($chartExportModesActualExportEnabled -and
    $ChartExportModesExportMode -eq "RatePack" -and
    $ChartExportModesExportMaximumRate -lt $ChartExportModesExportMinimumRate) {
    throw "Actual RatePack maximum rate cannot be smaller than its minimum rate."
}
if ($chartExportModesNativeSaveEdgeEnabled -and
    ([string]::IsNullOrWhiteSpace($ChartExportModesCancelScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($ChartExportModesOverwriteScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($ChartExportModesForbiddenOutputPath))) {
    throw "The native Save edge scenario requires cancel, overwrite, and forbidden-output evidence paths."
}
if ($chartExportModesNativeSaveEdgeEnabled -and
    ($ChartExportModesExportMode -ne "SingleChart" -or
     $ChartExportModesExportFormat -ne "OsuMania" -or
     $ChartExportModesExportPreservePitch)) {
    throw "The current fail-closed native Save edge scenario is restricted to osu!mania SingleChart without PreservePitch."
}
if (($ExerciseMalodyFullPackageExport -or $ExerciseOsuToMalodyFullPackageExport) -and
    ([string]::IsNullOrWhiteSpace($MalodyFullPackageExportPath) -or
     [string]::IsNullOrWhiteSpace($MalodyFullPackageSourceRoot) -or
     [string]::IsNullOrWhiteSpace($MalodyFullPackageOptionsScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($MalodyFullPackageResultScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($MalodyFullPackageFreshImportEvidencePath) -or
     [string]::IsNullOrWhiteSpace($MalodyFullPackageFreshImportInteractionEvidencePath) -or
     [string]::IsNullOrWhiteSpace($MalodyFullPackageFreshImportDialogScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($MalodyFullPackageFreshImportScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($MalodyFullPackageFreshImportWorkspaceRoot) -or
     [string]::IsNullOrWhiteSpace($MalodyFullPackageFreshImportLocalDataRoot) -or
     [string]::IsNullOrWhiteSpace($MalodyFullPackageFreshImportEditingRoot))) {
    throw "Malody-target FullPackage export requires destination/source, dialog screenshots, and a complete fresh-import evidence root set."
}
if ($targetOsuFullPackage -and
    ([string]::IsNullOrWhiteSpace($OsuFullPackageExportPath) -or
     [string]::IsNullOrWhiteSpace($OsuFullPackageSourceRoot) -or
     [string]::IsNullOrWhiteSpace($OsuFullPackageOptionsScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($OsuFullPackageResultScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($OsuFullPackageFreshImportEvidencePath) -or
     [string]::IsNullOrWhiteSpace($OsuFullPackageFreshImportInteractionEvidencePath) -or
     [string]::IsNullOrWhiteSpace($OsuFullPackageFreshImportDialogScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($OsuFullPackageFreshImportFirstCalibrationScreenshotPath) -or
     ($sourceOsuFullPackage -and
      [string]::IsNullOrWhiteSpace($OsuFullPackageFreshImportSecondCalibrationScreenshotPath)) -or
     [string]::IsNullOrWhiteSpace($OsuFullPackageFreshImportScreenshotPath) -or
     [string]::IsNullOrWhiteSpace($OsuFullPackageFreshImportWorkspaceRoot) -or
     [string]::IsNullOrWhiteSpace($OsuFullPackageFreshImportLocalDataRoot) -or
     [string]::IsNullOrWhiteSpace($OsuFullPackageFreshImportEditingRoot))) {
    throw "osu! FullPackage export requires destination/source, dialog screenshots, the required calibration screenshot set, and a complete fresh-import evidence root set."
}
$selectedFullPackageFormat = if ($targetOsuFullPackage) { "OsuMania" } else { "Malody" }
$selectedFullPackageSourceFormat = if ($sourceOsuFullPackage) { "OsuMania" } else { "Malody" }
$selectedFullPackageExportPath = if ($targetOsuFullPackage) {
    $OsuFullPackageExportPath
} else { $MalodyFullPackageExportPath }
$selectedFullPackageSourceRoot = if ($targetOsuFullPackage) {
    $OsuFullPackageSourceRoot
} else { $MalodyFullPackageSourceRoot }
$selectedFullPackageOptionsScreenshotPath = if ($targetOsuFullPackage) {
    $OsuFullPackageOptionsScreenshotPath
} else { $MalodyFullPackageOptionsScreenshotPath }
$selectedFullPackageResultScreenshotPath = if ($targetOsuFullPackage) {
    $OsuFullPackageResultScreenshotPath
} else { $MalodyFullPackageResultScreenshotPath }
$selectedFullPackageFreshImportEvidencePath = if ($targetOsuFullPackage) {
    $OsuFullPackageFreshImportEvidencePath
} else { $MalodyFullPackageFreshImportEvidencePath }
$selectedFullPackageFreshImportInteractionEvidencePath = if ($targetOsuFullPackage) {
    $OsuFullPackageFreshImportInteractionEvidencePath
} else { $MalodyFullPackageFreshImportInteractionEvidencePath }
$selectedFullPackageFreshImportDialogScreenshotPath = if ($targetOsuFullPackage) {
    $OsuFullPackageFreshImportDialogScreenshotPath
} else { $MalodyFullPackageFreshImportDialogScreenshotPath }
$selectedFullPackageFreshImportScreenshotPath = if ($targetOsuFullPackage) {
    $OsuFullPackageFreshImportScreenshotPath
} else { $MalodyFullPackageFreshImportScreenshotPath }
$selectedFullPackageFreshImportWorkspaceRoot = if ($targetOsuFullPackage) {
    $OsuFullPackageFreshImportWorkspaceRoot
} else { $MalodyFullPackageFreshImportWorkspaceRoot }
$selectedFullPackageFreshImportLocalDataRoot = if ($targetOsuFullPackage) {
    $OsuFullPackageFreshImportLocalDataRoot
} else { $MalodyFullPackageFreshImportLocalDataRoot }
$selectedFullPackageFreshImportEditingRoot = if ($targetOsuFullPackage) {
    $OsuFullPackageFreshImportEditingRoot
} else { $MalodyFullPackageFreshImportEditingRoot }
$selectedFullPackageExpectedChartCount = if ($targetOsuFullPackage) {
    $OsuFullPackageExpectedChartCount
} else { $MalodyFullPackageExpectedChartCount }
$proEditorSaveAsOsuFullPath = if ([string]::IsNullOrWhiteSpace($ProEditorSaveAsOsuPath)) {
    $null
} else {
    $resolvedSaveAs = Resolve-ArtifactPath $ProEditorSaveAsOsuPath
    if ([IO.Path]::GetExtension($resolvedSaveAs) -ne ".osu") {
        throw "ProEditor Save As destination must use the .osu extension."
    }
    if (Test-Path -LiteralPath $resolvedSaveAs) {
        throw "ProEditor Save As destination already exists: $resolvedSaveAs"
    }
    if ($chartFullPath -and -not [IO.Path]::GetDirectoryName($resolvedSaveAs).Equals(
            [IO.Path]::GetDirectoryName($chartFullPath),
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "ProEditor Save As destination must stay in the source chart directory."
    }
    $resolvedSaveAs
}
$malodyFullPackageExportFullPath = if ([string]::IsNullOrWhiteSpace($selectedFullPackageExportPath)) {
    $null
} else {
    $resolvedExport = Resolve-ArtifactPath $selectedFullPackageExportPath
    $expectedArchiveExtension = if ($targetOsuFullPackage) { ".osz" } else { ".mcz" }
    if (-not [IO.Path]::GetExtension($resolvedExport).Equals(
            $expectedArchiveExtension,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "FullPackage export destination must use the $expectedArchiveExtension extension."
    }
    if (Test-Path -LiteralPath $resolvedExport) {
        throw "FullPackage export destination already exists: $resolvedExport"
    }
    $resolvedExport
}
$malodyFullPackageSourceRootFullPath = if (
    [string]::IsNullOrWhiteSpace($selectedFullPackageSourceRoot)) {
    $null
} else {
    $resolvedSourceRoot = Resolve-ArtifactPath $selectedFullPackageSourceRoot
    if (-not (Test-Path -LiteralPath $resolvedSourceRoot -PathType Container)) {
        throw "Isolated FullPackage source root does not exist: $resolvedSourceRoot"
    }
    $resolvedSourceRoot.TrimEnd('\')
}
if ($fullPackageExportExerciseEnabled) {
    $sourceBoundary = $malodyFullPackageSourceRootFullPath + '\'
    if (-not $chartFullPath.StartsWith($sourceBoundary, [StringComparison]::OrdinalIgnoreCase)) {
        throw "The chart must stay inside the isolated FullPackage source root."
    }
    if ($malodyFullPackageExportFullPath.StartsWith(
            $sourceBoundary,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "The archive destination must stay outside the isolated package source tree."
    }
    $fixtureItem = Get-Item -LiteralPath $chartFullPath
    $fixtureSha256 = (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
    if ($ExerciseOsuFullPackageExport) {
        $expectedFixtureName =
            "Minori Chihara - Michishirube (eZmmR) [Dear You,  Gilbert Bougainvillea .].osu"
        $expectedFixtureSha256 =
            "511866870F99BDC7443006FA7420C7A9D21198F49B9EC13B50A32293E7F58E57"
        if (-not [IO.Path]::GetExtension($chartFullPath).Equals(
                ".osu",
                [StringComparison]::OrdinalIgnoreCase) -or
            -not $fixtureItem.Name.Equals($expectedFixtureName, [StringComparison]::Ordinal) -or
            $fixtureSha256 -ne $expectedFixtureSha256) {
            throw "osu! FullPackage GUI evidence requires the trusted Michishirube osu fixture and exact SHA-256."
        }
        if (-not [IO.Path]::GetFileName($malodyFullPackageExportFullPath).Equals(
                "out.osz",
                [StringComparison]::Ordinal) -or
            -not $FocusNotePropertyBeat.Trim().Equals(
                "15:5/6",
                [StringComparison]::Ordinal)) {
            throw "osu! FullPackage GUI evidence requires out.osz and the exact 15:5/6 Tap focus."
        }
        $sourceOsuFiles = @(Get-ChildItem -LiteralPath $malodyFullPackageSourceRootFullPath -File |
            Where-Object { $_.Extension.Equals('.osu', [StringComparison]::OrdinalIgnoreCase) })
        if ($sourceOsuFiles.Count -ne $OsuFullPackageExpectedChartCount) {
            throw "osu! FullPackage GUI evidence requires exactly $OsuFullPackageExpectedChartCount sibling osu charts."
        }
        $malodyFullPackageFixtureEvidence = [ordered]@{
            sourceFormat = "OsuMania"
            targetFormat = "OsuMania"
            format = "OsuMania"
            path = $chartFullPath
            fileName = $fixtureItem.Name
            length = [long]$fixtureItem.Length
            sha256 = $fixtureSha256
            expectedSha256 = $expectedFixtureSha256
            sha256Verified = $true
            focusBeat = [ordered]@{ text = "15:5/6"; bar = 15; numerator = 5; denominator = 6 }
            submittedBeat = [ordered]@{ text = "15:10/12"; bar = 15; numerator = 10; denominator = 12 }
            lane = 2
            submittedLane = 3
            expectedChartCount = $sourceOsuFiles.Count
            expectedOverallDifficulty = $OsuFullPackageOverallDifficulty
            expectedHpDrainRate = $OsuFullPackageHpDrainRate
            exactFixtureVerified = $true
        }
        $selectedFullPackageMainChartFileName = $fixtureItem.Name
        $selectedFullPackageExpectedHitObjectTime = 11920
        $selectedFullPackageOriginalLane = 2
        $selectedFullPackageExpectedExportedLane = 3
        $selectedFullPackageExpectedEntryCount = 7
        $selectedFullPackageMinimumCollisionEntryCount = 2
        $selectedFullPackageExpectSourceOsuSiblings = $true
    }
    elseif ($osuToMalodyFullPackage) {
        $expectedFixtureName =
            "Minori Chihara - Michishirube (eZmmR) [Dear You,  Gilbert Bougainvillea .].osu"
        $expectedFixtureSha256 =
            "511866870F99BDC7443006FA7420C7A9D21198F49B9EC13B50A32293E7F58E57"
        if (-not [IO.Path]::GetExtension($chartFullPath).Equals(
                ".osu",
                [StringComparison]::OrdinalIgnoreCase) -or
            -not $fixtureItem.Name.Equals($expectedFixtureName, [StringComparison]::Ordinal) -or
            $fixtureSha256 -ne $expectedFixtureSha256 -or
            -not [IO.Path]::GetFileName($malodyFullPackageExportFullPath).Equals(
                "out.mcz",
                [StringComparison]::Ordinal) -or
            -not $FocusNotePropertyBeat.Trim().Equals(
                "15:5/6",
                [StringComparison]::Ordinal) -or
            $selectedFullPackageExpectedChartCount -ne 1) {
            throw "osu!-to-Malody FullPackage GUI evidence requires the trusted Michishirube osu fixture, out.mcz, exact 15:5/6 Tap focus, exact SHA-256, and one exported chart."
        }
        if (-not [IO.Path]::GetDirectoryName($chartFullPath).Equals(
                $malodyFullPackageSourceRootFullPath,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "osu!-to-Malody FullPackage GUI evidence requires a flat isolated Michishirube source root."
        }
        $sourceOsuFiles = @(Get-ChildItem -LiteralPath $malodyFullPackageSourceRootFullPath -File |
            Where-Object { $_.Extension.Equals('.osu', [StringComparison]::OrdinalIgnoreCase) })
        $sourceMcDecoys = @(Get-ChildItem -LiteralPath $malodyFullPackageSourceRootFullPath -File |
            Where-Object { $_.Extension.Equals('.mc', [StringComparison]::OrdinalIgnoreCase) })
        $sourceArchiveDecoys = @(Get-ChildItem -LiteralPath $malodyFullPackageSourceRootFullPath -File |
            Where-Object { $_.Extension -in '.mcz', '.osz', '.luma-part' })
        $sourceResourceFiles = @(Get-ChildItem -LiteralPath $malodyFullPackageSourceRootFullPath -File |
            Where-Object { $_.Extension -notin '.mc', '.osu', '.mcz', '.osz', '.luma-part' })
        if ($sourceOsuFiles.Count -lt 2 -or $sourceMcDecoys.Count -lt 1 -or
            $sourceArchiveDecoys.Count -lt 3 -or $sourceResourceFiles.Count -lt 3) {
            throw "osu!-to-Malody FullPackage GUI evidence requires a real osu sibling, an MC chart decoy, MCZ/OSZ/luma-part archive decoys, and at least three real resources."
        }
        $malodyFullPackageFixtureEvidence = [ordered]@{
            sourceFormat = "OsuMania"
            targetFormat = "Malody"
            crossFormat = $true
            format = "Malody"
            path = $chartFullPath
            fileName = $fixtureItem.Name
            length = [long]$fixtureItem.Length
            sha256 = $fixtureSha256
            expectedSha256 = $expectedFixtureSha256
            sha256Verified = $true
            focusBeat = [ordered]@{ text = "15:5/6"; bar = 15; numerator = 5; denominator = 6 }
            submittedBeat = [ordered]@{ text = "15:10/12"; bar = 15; numerator = 10; denominator = 12 }
            lane = 2
            submittedLane = 3
            expectedChartCount = 1
            sourceOsuCharts = @($sourceOsuFiles | ForEach-Object { $_.Name } | Sort-Object)
            chartDecoys = @($sourceMcDecoys | ForEach-Object { $_.Name } | Sort-Object)
            archiveDecoys = @($sourceArchiveDecoys | ForEach-Object { $_.Name } | Sort-Object)
            resources = @($sourceResourceFiles | ForEach-Object { $_.Name } | Sort-Object)
            exactFixtureVerified = $true
        }
        # Malody cross-format exports derive a Unix-time MC leaf at runtime.
        $selectedFullPackageMainChartFileName = $null
        $selectedFullPackageExpectedHitObjectTime = 11920
        $selectedFullPackageOriginalLane = 2
        $selectedFullPackageExpectedExportedLane = 3
        $selectedFullPackageExpectedEntryCount = 6
        $selectedFullPackageMinimumCollisionEntryCount = 2
        $selectedFullPackageExpectSourceOsuSiblings = $false
    }
    elseif ($malodyToOsuFullPackage) {
        $expectedFixtureSha256 =
            "72755927BC97EF334747343E61FF00FA9E1E5A134F1455A7EDF18DB779CBE2CF"
        $expectedMainChartFileName =
            "HyuN - Infinity Heaven (舞线Ignite) [4K Stream Lv.28].osu"
        if (-not [IO.Path]::GetExtension($chartFullPath).Equals(
                ".mc",
                [StringComparison]::OrdinalIgnoreCase) -or
            -not $fixtureItem.Name.Equals("1622528438.mc", [StringComparison]::Ordinal) -or
            -not [IO.Path]::GetFileName($malodyFullPackageExportFullPath).Equals(
                "out.osz",
                [StringComparison]::Ordinal) -or
            -not $FocusNotePropertyBeat.Trim().Equals(
                "182:1/4",
                [StringComparison]::Ordinal) -or
            $fixtureSha256 -ne $expectedFixtureSha256 -or
            $selectedFullPackageExpectedChartCount -ne 1) {
            throw "Malody-to-osu! FullPackage GUI evidence requires the trusted 1622528438.mc Infinity fixture, out.osz, exact 182:1/4 Tap focus, exact SHA-256, and one exported chart."
        }
        if (-not [IO.Path]::GetDirectoryName($chartFullPath).Equals(
                $malodyFullPackageSourceRootFullPath,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Malody-to-osu! FullPackage GUI evidence requires a flat isolated Infinity source root."
        }
        $fixtureChartJson = Get-Content -LiteralPath $chartFullPath -Raw | ConvertFrom-Json
        $fixtureFocusMatches = @($fixtureChartJson.note | Where-Object {
                $null -ne $_.column -and $null -ne $_.beat -and
                @($_.beat).Count -ge 3 -and
                [int]$_.column -eq 1 -and
                [int]$_.beat[0] -eq 182 -and
                [int]$_.beat[1] -eq 1 -and
                [int]$_.beat[2] -eq 4 -and
                $null -eq $_.endbeat
            })
        if ($fixtureFocusMatches.Count -ne 1) {
            throw "Trusted 1622528438.mc must contain exactly one lane-1 Tap at 182:1/4."
        }
        $sourceChartDecoys = @(Get-ChildItem -LiteralPath $malodyFullPackageSourceRootFullPath -File |
            Where-Object {
                $_.FullName -ne $chartFullPath -and
                $_.Extension -in '.mc', '.osu'
            })
        $sourceArchiveDecoys = @(Get-ChildItem -LiteralPath $malodyFullPackageSourceRootFullPath -File |
            Where-Object { $_.Extension -in '.mcz', '.osz', '.luma-part' })
        if ($sourceChartDecoys.Count -lt 2 -or $sourceArchiveDecoys.Count -lt 3) {
            throw "Malody-to-osu! FullPackage GUI evidence requires isolated MC/osu chart decoys and MCZ/OSZ/luma-part archive decoys."
        }
        $malodyFullPackageFixtureEvidence = [ordered]@{
            sourceFormat = "Malody"
            targetFormat = "OsuMania"
            crossFormat = $true
            format = "OsuMania"
            path = $chartFullPath
            fileName = $fixtureItem.Name
            length = [long]$fixtureItem.Length
            sha256 = $fixtureSha256
            expectedSha256 = $expectedFixtureSha256
            sha256Verified = $true
            focusBeat = [ordered]@{ text = "182:1/4"; bar = 182; numerator = 1; denominator = 4 }
            submittedBeat = [ordered]@{ text = "182:2/8"; bar = 182; numerator = 2; denominator = 8 }
            lane = 1
            submittedLane = 2
            expectedChartCount = 1
            expectedMainChartFileName = $expectedMainChartFileName
            expectedHitObjectTime = 68066
            expectedOverallDifficulty = $OsuFullPackageOverallDifficulty
            expectedHpDrainRate = $OsuFullPackageHpDrainRate
            chartDecoys = @($sourceChartDecoys | ForEach-Object { $_.Name } | Sort-Object)
            archiveDecoys = @($sourceArchiveDecoys | ForEach-Object { $_.Name } | Sort-Object)
            tapMatchCount = $fixtureFocusMatches.Count
            exactFixtureVerified = $true
        }
        $selectedFullPackageMainChartFileName = $expectedMainChartFileName
        $selectedFullPackageExpectedHitObjectTime = 68066
        $selectedFullPackageOriginalLane = 1
        $selectedFullPackageExpectedExportedLane = 2
        $selectedFullPackageExpectedEntryCount = 5
        $selectedFullPackageMinimumCollisionEntryCount = 2
        $selectedFullPackageExpectSourceOsuSiblings = $false
    }
    else {
        $expectedFixtureSha256 =
            "72755927BC97EF334747343E61FF00FA9E1E5A134F1455A7EDF18DB779CBE2CF"
        if (-not [IO.Path]::GetExtension($chartFullPath).Equals(
                ".mc",
                [StringComparison]::OrdinalIgnoreCase) -or
            -not $fixtureItem.Name.Equals("1622528438.mc", [StringComparison]::OrdinalIgnoreCase) -or
            -not [IO.Path]::GetFileName($malodyFullPackageExportFullPath).Equals(
                "out.mcz",
                [StringComparison]::Ordinal) -or
            -not $FocusNotePropertyBeat.Trim().Equals(
                "182:1/4",
                [StringComparison]::Ordinal) -or
            $fixtureSha256 -ne $expectedFixtureSha256) {
            throw "Malody FullPackage GUI evidence requires the trusted 1622528438.mc fixture, out.mcz, 182:1/4, and exact SHA-256."
        }
        $fixtureChartJson = Get-Content -LiteralPath $chartFullPath -Raw | ConvertFrom-Json
        $fixtureFocusMatches = @($fixtureChartJson.note | Where-Object {
                $null -ne $_.column -and $null -ne $_.beat -and
                @($_.beat).Count -ge 3 -and
                [int]$_.column -eq 1 -and
                [int]$_.beat[0] -eq 182 -and
                [int]$_.beat[1] -eq 1 -and
                [int]$_.beat[2] -eq 4 -and
                $null -eq $_.endbeat
            })
        if ($fixtureFocusMatches.Count -ne 1) {
            throw "Trusted 1622528438.mc must contain exactly one lane-1 Tap at 182:1/4."
        }
        $malodyFullPackageFixtureEvidence = [ordered]@{
            sourceFormat = "Malody"
            targetFormat = "Malody"
            format = "Malody"
            path = $chartFullPath
            fileName = $fixtureItem.Name
            length = [long]$fixtureItem.Length
            sha256 = $fixtureSha256
            expectedSha256 = $expectedFixtureSha256
            sha256Verified = $true
            focusBeat = [ordered]@{ text = "182:1/4"; bar = 182; numerator = 1; denominator = 4 }
            submittedBeat = [ordered]@{ text = "182:2/8"; bar = 182; numerator = 2; denominator = 8 }
            lane = 1
            submittedLane = 1
            tapMatchCount = $fixtureFocusMatches.Count
            exactFixtureVerified = $true
        }
        $selectedFullPackageMainChartFileName = $fixtureItem.Name
        $selectedFullPackageExpectedHitObjectTime = 0
        $selectedFullPackageOriginalLane = 1
        $selectedFullPackageExpectedExportedLane = 1
        $selectedFullPackageExpectedEntryCount = 13
        $selectedFullPackageMinimumCollisionEntryCount = 1
        $selectedFullPackageExpectSourceOsuSiblings = $false
    }
}
if (-not [string]::IsNullOrWhiteSpace($FocusGroupBeat) -and -not $FocusGroup) {
    throw "FocusGroupBeat is only valid with FocusGroup."
}
if ($SaveAfterGroupAssign -and -not $ExerciseGroupAssign) {
    throw "SaveAfterGroupAssign is only valid with ExerciseGroupAssign."
}
$groupIdValue = 0
if (($FocusGroup -or $groupExerciseEnabled) -and
    (-not [int]::TryParse($GroupId, [ref]$groupIdValue) -or
     $groupIdValue -lt 0 -or $groupIdValue -gt [ushort]::MaxValue)) {
    throw "GroupId must be an integer from 0 through 65535."
}
$screenshotFullPath = Resolve-ArtifactPath $ScreenshotPath
$workspaceFullPath = Resolve-ArtifactPath $WorkspaceRoot
$localDataFullPath = Resolve-ArtifactPath $LocalDataRoot
$editingFullPath = Resolve-ArtifactPath $EditingRoot
$libraryDeleteTargetFullPath = if ([string]::IsNullOrWhiteSpace($LibraryDeleteTargetPath)) {
    $null
} else {
    [IO.Path]::GetFullPath($LibraryDeleteTargetPath)
}
$libraryDeleteSecondTargetFullPath = if (
    [string]::IsNullOrWhiteSpace($LibraryDeleteSecondTargetPath)) {
    $null
} else {
    [IO.Path]::GetFullPath($LibraryDeleteSecondTargetPath)
}
$libraryContextMenuScreenshotFullPath = if ([string]::IsNullOrWhiteSpace($LibraryContextMenuScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $LibraryContextMenuScreenshotPath }
$libraryDeleteDialogScreenshotFullPath = if ([string]::IsNullOrWhiteSpace($LibraryDeleteDialogScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $LibraryDeleteDialogScreenshotPath }
$chartValidationManualDialogScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($ChartValidationManualDialogScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $ChartValidationManualDialogScreenshotPath }
$chartValidationSaveBlockedDialogScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($ChartValidationSaveBlockedDialogScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $ChartValidationSaveBlockedDialogScreenshotPath }
$sourceSaveFailureDialogScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($SourceSaveFailureDialogScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $SourceSaveFailureDialogScreenshotPath }
$chartExportModesDefaultScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($ChartExportModesDefaultScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $ChartExportModesDefaultScreenshotPath }
$chartExportModesSingleChartScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($ChartExportModesSingleChartScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $ChartExportModesSingleChartScreenshotPath }
$chartExportModesSingleRateScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($ChartExportModesSingleRateScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $ChartExportModesSingleRateScreenshotPath }
$chartExportModesRatePackScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($ChartExportModesRatePackScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $ChartExportModesRatePackScreenshotPath }
$chartExportModesHiddenValidationScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($ChartExportModesHiddenValidationScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $ChartExportModesHiddenValidationScreenshotPath }
$chartExportModesExportFullPath = if (
    [string]::IsNullOrWhiteSpace($ChartExportModesExportPath)) {
    $null
} else { Resolve-ArtifactPath $ChartExportModesExportPath }
$chartExportModesExportResultScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($ChartExportModesExportResultScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $ChartExportModesExportResultScreenshotPath }
$chartExportModesCancelScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($ChartExportModesCancelScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $ChartExportModesCancelScreenshotPath }
$chartExportModesOverwriteScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($ChartExportModesOverwriteScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $ChartExportModesOverwriteScreenshotPath }
$chartExportModesForbiddenOutputFullPath = if (
    [string]::IsNullOrWhiteSpace($ChartExportModesForbiddenOutputPath)) {
    $null
} else { Resolve-ArtifactPath $ChartExportModesForbiddenOutputPath }
if ($chartExportModesExerciseEnabled) {
    $chartExportModeCapturePaths = @(
        $screenshotFullPath,
        $chartExportModesDefaultScreenshotFullPath,
        $chartExportModesSingleChartScreenshotFullPath,
        $chartExportModesSingleRateScreenshotFullPath,
        $chartExportModesRatePackScreenshotFullPath,
        $chartExportModesHiddenValidationScreenshotFullPath)
    if ($chartExportModesNativeSaveEdgeEnabled) {
        $chartExportModeCapturePaths += @(
            $chartExportModesCancelScreenshotFullPath,
            $chartExportModesOverwriteScreenshotFullPath)
    }
    if (@($chartExportModeCapturePaths | Sort-Object -Unique).Count -ne
        $chartExportModeCapturePaths.Count) {
        $duplicatePaths = @(
            $chartExportModeCapturePaths |
                Group-Object |
                Where-Object Count -gt 1 |
                ForEach-Object Name)
        throw ("Chart-export mode screenshots and the final GUI screenshot must use distinct paths. " +
            "Duplicates: " + ($duplicatePaths -join ", "))
    }
}
if ($chartExportModesActualExportEnabled) {
    $expectedChartExportExtension = if ($ChartExportModesExportMode -eq "SingleChart") {
        if ($ChartExportModesExportFormat -eq "OsuMania") { ".osu" } else { ".mc" }
    }
    elseif ($ChartExportModesExportFormat -eq "OsuMania") { ".osz" }
    else { ".mcz" }
    if ($chartExportModesNativeSaveEdgeEnabled) {
        $actualExtension = [IO.Path]::GetExtension($chartExportModesExportFullPath)
        if (-not $actualExtension.Equals(
                $expectedChartExportExtension,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "The native Save edge destination must be the corrected existing .osu target."
        }
        if (-not (Test-Path -LiteralPath $chartExportModesExportFullPath -PathType Leaf)) {
            throw "The native Save edge destination must already exist before its overwrite exercise."
        }
        $expectedForbiddenOutput = $chartExportModesExportFullPath + ".mc"
        if (-not $chartExportModesForbiddenOutputFullPath.Equals(
                $expectedForbiddenOutput,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "The forbidden output must be the exact picker-appended .osu.mc path: $expectedForbiddenOutput"
        }
        if (Test-Path -LiteralPath $chartExportModesForbiddenOutputFullPath) {
            throw "The forbidden secondary-extension output already exists: $chartExportModesForbiddenOutputFullPath"
        }
        if ($chartExportModesExportFullPath.Length -le 260 -or
            -not $chartExportModesExportFullPath.Contains(' ') -or
            $chartExportModesExportFullPath -notmatch '[^\u0000-\u007F]') {
            throw "The corrected native Save edge destination must contain Unicode and spaces and exceed 260 ordinary absolute-path characters."
        }
    }
    else {
        if (-not [IO.Path]::GetExtension($chartExportModesExportFullPath).Equals(
                $expectedChartExportExtension,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Actual $ChartExportModesExportMode export destination must use $expectedChartExportExtension."
        }
        if (Test-Path -LiteralPath $chartExportModesExportFullPath) {
            throw "Actual chart-export destination already exists: $chartExportModesExportFullPath"
        }
    }
    if ($chartExportModeCapturePaths -contains $chartExportModesExportResultScreenshotFullPath -or
        $screenshotFullPath.Equals(
            $chartExportModesExportResultScreenshotFullPath,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "Actual export result screenshot must use a distinct path."
    }
    if ($chartExportModesNativeSaveEdgeEnabled -and
        ($chartExportModeCapturePaths -contains $chartExportModesExportResultScreenshotFullPath -or
         $chartExportModesExportResultScreenshotFullPath.Equals(
             $chartExportModesCancelScreenshotFullPath,
             [StringComparison]::OrdinalIgnoreCase) -or
         $chartExportModesExportResultScreenshotFullPath.Equals(
             $chartExportModesOverwriteScreenshotFullPath,
             [StringComparison]::OrdinalIgnoreCase))) {
        throw "Native Save edge and result screenshots must use distinct paths."
    }
}
$malodyFullPackageOptionsScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($selectedFullPackageOptionsScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $selectedFullPackageOptionsScreenshotPath }
$malodyFullPackageResultScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($selectedFullPackageResultScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $selectedFullPackageResultScreenshotPath }
$malodyFullPackageFreshImportEvidenceFullPath = if (
    [string]::IsNullOrWhiteSpace($selectedFullPackageFreshImportEvidencePath)) {
    $null
} else { Resolve-ArtifactPath $selectedFullPackageFreshImportEvidencePath }
$malodyFullPackageFreshImportInteractionEvidenceFullPath = if (
    [string]::IsNullOrWhiteSpace($selectedFullPackageFreshImportInteractionEvidencePath)) {
    $null
} else { Resolve-ArtifactPath $selectedFullPackageFreshImportInteractionEvidencePath }
$malodyFullPackageFreshImportDialogScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($selectedFullPackageFreshImportDialogScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $selectedFullPackageFreshImportDialogScreenshotPath }
$malodyFullPackageFreshImportScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($selectedFullPackageFreshImportScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $selectedFullPackageFreshImportScreenshotPath }
$malodyFullPackageFreshImportWorkspaceFullPath = if (
    [string]::IsNullOrWhiteSpace($selectedFullPackageFreshImportWorkspaceRoot)) {
    $null
} else { Resolve-ArtifactPath $selectedFullPackageFreshImportWorkspaceRoot }
$malodyFullPackageFreshImportLocalDataFullPath = if (
    [string]::IsNullOrWhiteSpace($selectedFullPackageFreshImportLocalDataRoot)) {
    $null
} else { Resolve-ArtifactPath $selectedFullPackageFreshImportLocalDataRoot }
$malodyFullPackageFreshImportEditingFullPath = if (
    [string]::IsNullOrWhiteSpace($selectedFullPackageFreshImportEditingRoot)) {
    $null
} else { Resolve-ArtifactPath $selectedFullPackageFreshImportEditingRoot }
$osuFullPackageFreshImportFirstCalibrationScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($OsuFullPackageFreshImportFirstCalibrationScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $OsuFullPackageFreshImportFirstCalibrationScreenshotPath }
$osuFullPackageFreshImportSecondCalibrationScreenshotFullPath = if (
    [string]::IsNullOrWhiteSpace($OsuFullPackageFreshImportSecondCalibrationScreenshotPath)) {
    $null
} else { Resolve-ArtifactPath $OsuFullPackageFreshImportSecondCalibrationScreenshotPath }
if ($fullPackageExportExerciseEnabled) {
    $freshRoots = @(
        $malodyFullPackageFreshImportWorkspaceFullPath,
        $malodyFullPackageFreshImportLocalDataFullPath,
        $malodyFullPackageFreshImportEditingFullPath)
    if (@($freshRoots | Sort-Object -Unique).Count -ne 3) {
        throw "Fresh archive import workspace/local-data/editing roots must be distinct."
    }
    foreach ($freshRoot in $freshRoots) {
        if ($freshRoot.Equals($workspaceFullPath, [StringComparison]::OrdinalIgnoreCase) -or
            $freshRoot.Equals($localDataFullPath, [StringComparison]::OrdinalIgnoreCase) -or
            $freshRoot.Equals($editingFullPath, [StringComparison]::OrdinalIgnoreCase) -or
            $freshRoot.StartsWith(
                $malodyFullPackageSourceRootFullPath.TrimEnd('\') + '\',
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fresh archive import roots must be isolated from the export process and source tree."
        }
        if ((Test-Path -LiteralPath $freshRoot) -and
            (Get-ChildItem -LiteralPath $freshRoot -Force | Select-Object -First 1)) {
            throw "Fresh archive import root must be empty: $freshRoot"
        }
    }
}
if ($libraryDeleteExerciseEnabled) {
    $workspaceBoundary = $workspaceFullPath.TrimEnd('\') + '\'
    if (-not $libraryDeleteTargetFullPath.StartsWith(
            $workspaceBoundary,
            [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $libraryDeleteTargetFullPath -PathType Container)) {
        throw "Library deletion target must be an existing child folder of the isolated workspace."
    }
}
if ($ExerciseLibraryBatchDeleteConfirm) {
    $workspaceBoundary = $workspaceFullPath.TrimEnd('\') + '\'
    if (-not $libraryDeleteSecondTargetFullPath.StartsWith(
            $workspaceBoundary,
            [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $libraryDeleteSecondTargetFullPath -PathType Container)) {
        throw "The second library deletion target must be an existing child folder of the isolated workspace."
    }
    if ($libraryDeleteTargetFullPath.Equals(
            $libraryDeleteSecondTargetFullPath,
            [StringComparison]::OrdinalIgnoreCase) -or
        $LibraryDeleteTargetName.Equals(
            $LibraryDeleteSecondTargetName,
            [StringComparison]::Ordinal)) {
        throw "The two library batch-delete targets must have distinct paths and names."
    }
    $firstTargetBoundary = $libraryDeleteTargetFullPath.TrimEnd('\') + '\'
    $secondTargetBoundary = $libraryDeleteSecondTargetFullPath.TrimEnd('\') + '\'
    if ($libraryDeleteSecondTargetFullPath.StartsWith(
            $firstTargetBoundary,
            [StringComparison]::OrdinalIgnoreCase) -or
        $libraryDeleteTargetFullPath.StartsWith(
            $secondTargetBoundary,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "The two library batch-delete targets must be non-nested folders."
    }
    if ($chartFullPath.StartsWith($firstTargetBoundary, [StringComparison]::OrdinalIgnoreCase) -or
        $chartFullPath.StartsWith($secondTargetBoundary, [StringComparison]::OrdinalIgnoreCase)) {
        throw "The batch-delete chart fixture must stay outside both deletion targets."
    }
}
if ($ExerciseLibraryOpenDocumentBlock) {
    $targetBoundary = $libraryDeleteTargetFullPath.TrimEnd('\') + '\'
    if (-not $chartFullPath.StartsWith($targetBoundary, [StringComparison]::OrdinalIgnoreCase)) {
        throw "The open-document deletion-block ChartPath must be inside the deletion target."
    }
}
$applicationPath = if ([string]::IsNullOrWhiteSpace($ApplicationExecutablePath)) {
    Join-Path $projectRoot "LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"
}
else {
    [IO.Path]::GetFullPath($ApplicationExecutablePath)
}
if (-not (Test-Path -LiteralPath $applicationPath -PathType Leaf)) {
    throw "Windows Avalonia executable is missing: $applicationPath"
}
if (-not [IO.Path]::GetFileName($applicationPath).Equals(
        "LumaChart.Avalonia.exe",
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "GUI capture may only launch LumaChart.Avalonia.exe: $applicationPath"
}

if ((Test-Path -LiteralPath $localDataFullPath) -and
    (Get-ChildItem -LiteralPath $localDataFullPath -Force | Select-Object -First 1) -and
    -not $AllowExistingLocalDataRoot) {
    throw "Isolated GUI local-data root must be empty unless an explicit isolated-settings gate is requested: $localDataFullPath"
}
if ((Test-Path -LiteralPath $editingFullPath) -and
    (Get-ChildItem -LiteralPath $editingFullPath -Force | Select-Object -First 1) -and
    -not $AllowExistingEditingRoot) {
    throw "Isolated GUI editing root must be empty: $editingFullPath"
}
New-Item -ItemType Directory -Path $workspaceFullPath, $localDataFullPath, $editingFullPath -Force | Out-Null
if ($evidenceFullPath) {
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($evidenceFullPath)) -Force | Out-Null
}
if ($interactionEvidenceFullPath) {
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($interactionEvidenceFullPath)) -Force | Out-Null
}
New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($screenshotFullPath)) -Force | Out-Null
if ($malodyFullPackageExportFullPath) {
    # The Windows common Save dialog can accept an absolute filename, but its
    # parent directory must already exist before the native picker submits it.
    New-Item -ItemType Directory `
        -Path ([IO.Path]::GetDirectoryName($malodyFullPackageExportFullPath)) `
        -Force |
        Out-Null
}
if ($chartExportModesExportFullPath) {
    New-Item -ItemType Directory `
        -Path ([IO.Path]::GetDirectoryName($chartExportModesExportFullPath)) `
        -Force | Out-Null
}
foreach ($intermediateScreenshot in @(
        $libraryContextMenuScreenshotFullPath,
        $libraryDeleteDialogScreenshotFullPath,
        $chartValidationManualDialogScreenshotFullPath,
        $chartValidationSaveBlockedDialogScreenshotFullPath,
        $sourceSaveFailureDialogScreenshotFullPath,
        $chartExportModesDefaultScreenshotFullPath,
        $chartExportModesSingleChartScreenshotFullPath,
        $chartExportModesSingleRateScreenshotFullPath,
        $chartExportModesRatePackScreenshotFullPath,
        $chartExportModesHiddenValidationScreenshotFullPath,
        $chartExportModesExportResultScreenshotFullPath,
        $chartExportModesCancelScreenshotFullPath,
        $chartExportModesOverwriteScreenshotFullPath,
        $malodyFullPackageOptionsScreenshotFullPath,
        $malodyFullPackageResultScreenshotFullPath,
        $malodyFullPackageFreshImportDialogScreenshotFullPath,
        $osuFullPackageFreshImportFirstCalibrationScreenshotFullPath,
        $osuFullPackageFreshImportSecondCalibrationScreenshotFullPath,
        $malodyFullPackageFreshImportScreenshotFullPath)) {
    if ($intermediateScreenshot) {
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($intermediateScreenshot)) -Force | Out-Null
    }
}
if ($evidenceFullPath -and (Test-Path -LiteralPath $evidenceFullPath)) {
    throw "Evidence output already exists: $evidenceFullPath"
}
if ($interactionEvidenceFullPath -and (Test-Path -LiteralPath $interactionEvidenceFullPath)) {
    throw "Interaction evidence output already exists: $interactionEvidenceFullPath"
}
if (Test-Path -LiteralPath $screenshotFullPath) {
    throw "Screenshot output already exists: $screenshotFullPath"
}
foreach ($intermediateScreenshot in @(
        $libraryContextMenuScreenshotFullPath,
        $libraryDeleteDialogScreenshotFullPath,
        $chartValidationManualDialogScreenshotFullPath,
        $chartValidationSaveBlockedDialogScreenshotFullPath,
        $sourceSaveFailureDialogScreenshotFullPath,
        $chartExportModesDefaultScreenshotFullPath,
        $chartExportModesSingleChartScreenshotFullPath,
        $chartExportModesSingleRateScreenshotFullPath,
        $chartExportModesRatePackScreenshotFullPath,
        $chartExportModesHiddenValidationScreenshotFullPath,
        $chartExportModesExportResultScreenshotFullPath,
        $chartExportModesCancelScreenshotFullPath,
        $chartExportModesOverwriteScreenshotFullPath,
        $malodyFullPackageOptionsScreenshotFullPath,
        $malodyFullPackageResultScreenshotFullPath,
        $malodyFullPackageFreshImportDialogScreenshotFullPath,
        $osuFullPackageFreshImportFirstCalibrationScreenshotFullPath,
        $osuFullPackageFreshImportSecondCalibrationScreenshotFullPath,
        $malodyFullPackageFreshImportScreenshotFullPath)) {
    if ($intermediateScreenshot -and (Test-Path -LiteralPath $intermediateScreenshot)) {
        throw "Intermediate screenshot output already exists: $intermediateScreenshot"
    }
}

# Establish the fail-closed source baseline before the product process exists.
# This makes startup-time writes observable instead of sampling only after launch.
$chartValidationSourceBefore = if ($chartValidationExerciseEnabled) {
    $chartItem = Get-Item -LiteralPath $chartFullPath
    [ordered]@{
        path = $chartFullPath
        length = [long]$chartItem.Length
        lastWriteTimeUtc = $chartItem.LastWriteTimeUtc.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
        sha256 = (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
    }
} else { $null }
$chartExportModesExistingTargetBefore = if ($chartExportModesNativeSaveEdgeEnabled) {
    $existingTargetItem = Get-Item -LiteralPath $chartExportModesExportFullPath
    [ordered]@{
        path = $chartExportModesExportFullPath
        length = [long]$existingTargetItem.Length
        lastWriteTimeUtc = $existingTargetItem.LastWriteTimeUtc.ToString(
            "O",
            [Globalization.CultureInfo]::InvariantCulture)
        sha256 = (Get-FileHash -LiteralPath $chartExportModesExportFullPath -Algorithm SHA256).Hash
    }
} else { $null }

$processStart = [Diagnostics.ProcessStartInfo]::new($applicationPath)
$processStart.UseShellExecute = $false
$processStart.WorkingDirectory = [IO.Path]::GetDirectoryName($applicationPath)
$processStart.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataFullPath
$processStart.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingFullPath
$processStart.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceFullPath
if (-not $LibraryHome) {
    $processStart.ArgumentList.Add("--evidence-chart")
    $processStart.ArgumentList.Add($chartFullPath)
    $processStart.ArgumentList.Add("--evidence-output")
    $processStart.ArgumentList.Add($evidenceFullPath)
    if ($interactionEvidenceFullPath) {
        $processStart.ArgumentList.Add("--evidence-interaction-output")
        $processStart.ArgumentList.Add($interactionEvidenceFullPath)
    }
    if ($FocusTiming) {
        $processStart.ArgumentList.Add("--evidence-focus-timing")
    }
    if ($FocusHoldTail) {
        $processStart.ArgumentList.Add("--evidence-focus-hold-tail")
    }
    if ($FocusNoteProperty) {
        $processStart.ArgumentList.Add("--evidence-focus-note-property")
        if (-not [string]::IsNullOrWhiteSpace($FocusNotePropertyBeat)) {
            $processStart.ArgumentList.Add("--evidence-focus-note-property-beat")
            $processStart.ArgumentList.Add($FocusNotePropertyBeat)
        }
    }
    if ($FocusGroup) {
        $processStart.ArgumentList.Add("--evidence-focus-group")
        if (-not [string]::IsNullOrWhiteSpace($FocusGroupBeat)) {
            $processStart.ArgumentList.Add("--evidence-focus-group-beat")
            $processStart.ArgumentList.Add($FocusGroupBeat)
        }
    }
    if ($FocusProEditor) {
        $processStart.ArgumentList.Add("--evidence-focus-proeditor")
    }
    if ($FocusKeySound) {
        $processStart.ArgumentList.Add("--evidence-focus-key-sound")
    }
    if ($FocusDisplayScale) {
        $processStart.ArgumentList.Add("--evidence-focus-display-scale")
    }
    if ($FocusAudioPanels -or $ExerciseAudioPanels) {
        $processStart.ArgumentList.Add("--evidence-focus-audio-panels")
    }
    if ($FocusLibraryDeletion) {
        $processStart.ArgumentList.Add("--evidence-focus-library-deletion")
    }
    if ($FocusChartValidation) {
        $processStart.ArgumentList.Add("--evidence-focus-chart-validation")
    }
    if ($fullPackageExportExerciseEnabled) {
        $processStart.ArgumentList.Add("--evidence-suppress-export-reveal")
        $processStart.ArgumentList.Add("--evidence-file-picker-start-directory")
        $processStart.ArgumentList.Add(
            [IO.Path]::GetDirectoryName($malodyFullPackageExportFullPath))
    }
    if ($chartExportModesActualExportEnabled) {
        $processStart.ArgumentList.Add("--evidence-suppress-export-reveal")
        $processStart.ArgumentList.Add("--evidence-file-picker-start-directory")
        $processStart.ArgumentList.Add(
            [IO.Path]::GetDirectoryName($chartExportModesExportFullPath))
    }
    if ($ExerciseGroupPlacement) {
        $processStart.ArgumentList.Add("--evidence-placement-probe-viewport")
    }
    if ($EnableBackgroundWaveform) {
        $processStart.ArgumentList.Add("--evidence-background-waveform")
    }
    if ($EnableBackgroundSpectrogram) {
        $processStart.ArgumentList.Add("--evidence-background-spectrogram")
    }
    if ($interactionEvidenceFullPath) {
        $processStart.ArgumentList.Add("--evidence-interaction-delay-ms")
        $processStart.ArgumentList.Add(
            $InteractionDelayMilliseconds.ToString([Globalization.CultureInfo]::InvariantCulture))
    }
    if ($SyntheticNoteCount -gt 0) {
        $processStart.ArgumentList.Add("--evidence-synthetic-notes")
        $processStart.ArgumentList.Add($SyntheticNoteCount.ToString([Globalization.CultureInfo]::InvariantCulture))
    }
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class LumaChartAvaloniaCaptureNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr window, IntPtr deviceContext, uint flags);

    [DllImport("user32.dll")]
    public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr value);

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct HARDWAREINPUT
    {
        public uint uMsg;
        public ushort wParamL;
        public ushort wParamH;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct INPUTUNION
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT
    {
        public uint type;
        public INPUTUNION U;
    }

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT point);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    public const uint GA_ROOT = 2;

    [DllImport("user32.dll")]
    public static extern IntPtr WindowFromPoint(POINT point);

    [DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr window, uint flags);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint inputCount, INPUT[] inputs, int inputSize);

    [DllImport("kernel32.dll", EntryPoint = "SetLastError")]
    private static extern void ClearLastError(uint errorCode);

    public static int InputStructSize => Marshal.SizeOf<INPUT>();

    public static int LastSendInputError { get; private set; }

    public static uint SendUnicodeText(string text)
    {
        if (text == null)
            throw new ArgumentNullException(nameof(text));

        const uint INPUT_KEYBOARD = 1;
        const uint KEYEVENTF_KEYUP = 0x0002;
        const uint KEYEVENTF_UNICODE = 0x0004;
        var inputs = new INPUT[text.Length * 2];
        var index = 0;
        foreach (var character in text)
        {
            inputs[index++] = new INPUT
            {
                type = INPUT_KEYBOARD,
                U = new INPUTUNION
                {
                    ki = new KEYBDINPUT
                    {
                        wVk = 0,
                        wScan = character,
                        dwFlags = KEYEVENTF_UNICODE,
                        time = 0,
                        dwExtraInfo = UIntPtr.Zero
                    }
                }
            };
            inputs[index++] = new INPUT
            {
                type = INPUT_KEYBOARD,
                U = new INPUTUNION
                {
                    ki = new KEYBDINPUT
                    {
                        wVk = 0,
                        wScan = character,
                        dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP,
                        time = 0,
                        dwExtraInfo = UIntPtr.Zero
                    }
                }
            };
        }

        ClearLastError(0);
        var sent = SendInput((uint)inputs.Length, inputs, InputStructSize);
        LastSendInputError = Marshal.GetLastWin32Error();
        return sent;
    }

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint firstThread, uint secondThread, bool attach);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr window);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int GetWindowText(IntPtr window, StringBuilder text, int maximumCount);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int GetWindowTextLength(IntPtr window);

    public static bool TryActivateWindow(IntPtr window)
    {
        if (window == IntPtr.Zero)
            return false;

        var foreground = GetForegroundWindow();
        if (foreground == window)
            return true;

        var currentThread = GetCurrentThreadId();
        var foregroundThread = foreground == IntPtr.Zero
            ? 0
            : GetWindowThreadProcessId(foreground, out _);
        var targetThread = GetWindowThreadProcessId(window, out _);
        var attachedForeground = false;
        var attachedTarget = false;
        try
        {
            if (foregroundThread != 0 && foregroundThread != currentThread)
                attachedForeground = AttachThreadInput(currentThread, foregroundThread, true);
            if (targetThread != 0 && targetThread != currentThread && targetThread != foregroundThread)
                attachedTarget = AttachThreadInput(currentThread, targetThread, true);

            ShowWindowAsync(window, 9);
            BringWindowToTop(window);
            SetForegroundWindow(window);
            return GetForegroundWindow() == window;
        }
        finally
        {
            if (attachedTarget)
                AttachThreadInput(currentThread, targetThread, false);
            if (attachedForeground)
                AttachThreadInput(currentThread, foregroundThread, false);
        }
    }

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);
}
'@

function Set-ForegroundWindowVerified {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$WindowHandle,
        [ValidateRange(100, 5000)][int]$TimeoutMilliseconds = 2000)

    if ($WindowHandle -eq [IntPtr]::Zero) {
        throw "Cannot activate a zero window handle before physical GUI input."
    }
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        if ([LumaChartAvaloniaCaptureNative]::GetForegroundWindow() -eq $WindowHandle) {
            return
        }
        [LumaChartAvaloniaCaptureNative]::TryActivateWindow($WindowHandle) | Out-Null
        Start-Sleep -Milliseconds 40
    }
    while ([DateTime]::UtcNow -lt $deadline)

    throw "Timed out activating GUI window '$WindowHandle'; foreground is " +
        "'$([LumaChartAvaloniaCaptureNative]::GetForegroundWindow())'."
}

function Get-FocusedAutomationElementEvidence {
    $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
    if (-not $focused) {
        throw "UI Automation did not expose a focused element before real keyboard input."
    }
    $bounds = $focused.Current.BoundingRectangle
    return [pscustomobject]@{
        Element = $focused
        Evidence = [ordered]@{
            name = [string]$focused.Current.Name
            automationId = [string]$focused.Current.AutomationId
            className = [string]$focused.Current.ClassName
            controlType = [string]$focused.Current.ControlType.ProgrammaticName
            nativeWindowHandle = [long]$focused.Current.NativeWindowHandle
            processId = [int]$focused.Current.ProcessId
            isKeyboardFocusable = [bool]$focused.Current.IsKeyboardFocusable
            hasKeyboardFocus = [bool]$focused.Current.HasKeyboardFocus
            bounds = [ordered]@{
                left = [double]$bounds.Left
                top = [double]$bounds.Top
                width = [double]$bounds.Width
                height = [double]$bounds.Height
            }
        }
    }
}

function Find-AutomationElementByName {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [IntPtr]$RootWindowHandle = [IntPtr]::Zero,
        [ValidateRange(100, 10000)][int]$TimeoutMilliseconds = 4000
    )

    $processCondition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
        $TargetProcessId)
    $nameCondition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::NameProperty,
        $Name)
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        if ($RootWindowHandle -ne [IntPtr]::Zero) {
            try {
                $root = [System.Windows.Automation.AutomationElement]::FromHandle($RootWindowHandle)
                $candidate = $root.FindFirst(
                    [System.Windows.Automation.TreeScope]::Descendants,
                    $nameCondition)
                if ($candidate) { return $candidate }
            }
            catch [System.Windows.Automation.ElementNotAvailableException] { }
            catch [Runtime.InteropServices.COMException] { }
        }
        else {
            try {
                $windows = [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
                    [System.Windows.Automation.TreeScope]::Children,
                    $processCondition)
                foreach ($window in $windows) {
                    try {
                        if ([string]::Equals($window.Current.Name, $Name, [StringComparison]::Ordinal)) {
                            return $window
                        }
                        $candidate = $window.FindFirst(
                            [System.Windows.Automation.TreeScope]::Descendants,
                            $nameCondition)
                        if ($candidate) { return $candidate }
                    }
                    catch [System.Windows.Automation.ElementNotAvailableException] { }
                    catch [Runtime.InteropServices.COMException] { }
                }
            }
            catch [Runtime.InteropServices.COMException] { }
        }
        Start-Sleep -Milliseconds 50
    }
    while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation element '$Name' for process $TargetProcessId."
}

function Find-AutomationElementById {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [IntPtr]$RootWindowHandle = [IntPtr]::Zero,
        [ValidateRange(100, 10000)][int]$TimeoutMilliseconds = 4000
    )

    $processCondition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
        $TargetProcessId)
    $idCondition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = if ($RootWindowHandle -ne [IntPtr]::Zero) {
                @([System.Windows.Automation.AutomationElement]::FromHandle($RootWindowHandle))
            } else {
                @([System.Windows.Automation.AutomationElement]::RootElement.FindAll(
                    [System.Windows.Automation.TreeScope]::Children,
                    $processCondition))
            }
            foreach ($root in $roots) {
                if ([string]::Equals(
                        $root.Current.AutomationId,
                        $AutomationId,
                        [StringComparison]::Ordinal)) {
                    return $root
                }
                $candidate = $root.FindFirst(
                    [System.Windows.Automation.TreeScope]::Descendants,
                    $idCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [System.Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 50
    }
    while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $TargetProcessId."
}

function Get-AutomationElementObservationByIdSingleShot {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    if ($RootWindowHandle -eq [IntPtr]::Zero) {
        throw "Single-shot UI Automation observation requires a native root window handle."
    }
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($RootWindowHandle)
    if ([int]$root.Current.ProcessId -ne $TargetProcessId) {
        throw "Single-shot UI Automation root belongs to a different process."
    }
    $idCondition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $element = if ([string]::Equals(
            [string]$root.Current.AutomationId,
            $AutomationId,
            [StringComparison]::Ordinal)) {
        $root
    } else {
        $root.FindFirst(
            [System.Windows.Automation.TreeScope]::Descendants,
            $idCondition)
    }
    if ($null -eq $element) {
        throw "Single-shot UI Automation id '$AutomationId' was not available for process $TargetProcessId."
    }
    if ([int]$element.Current.ProcessId -ne $TargetProcessId) {
        throw "Single-shot UI Automation element '$AutomationId' belongs to a different process."
    }
    $bounds = $element.Current.BoundingRectangle
    if ($element.Current.IsOffscreen -or
        $bounds.IsEmpty -or
        $bounds.Width -le 1 -or
        $bounds.Height -le 1) {
        throw "Single-shot UI Automation id '$AutomationId' is offscreen or has invalid bounds."
    }
    return [pscustomobject]@{
        Element = $element
        Evidence = [ordered]@{
            automationId = [string]$element.Current.AutomationId
            name = [string]$element.Current.Name
            controlType = [string]$element.Current.ControlType.ProgrammaticName
            isEnabled = [bool]$element.Current.IsEnabled
            isOffscreen = [bool]$element.Current.IsOffscreen
            bounds = [ordered]@{
                left = [double]$bounds.Left
                top = [double]$bounds.Top
                width = [double]$bounds.Width
                height = [double]$bounds.Height
            }
        }
    }
}

function Convert-EvidencePointToScreen {
    param(
        [Parameter(Mandatory = $true)]$Point,
        [Parameter(Mandatory = $true)]$Evidence,
        [Parameter(Mandatory = $true)]$WindowRectangle,
        [Parameter(Mandatory = $true)][int]$WindowWidth,
        [Parameter(Mandatory = $true)][int]$WindowHeight
    )

    $clientWidthDip = [double]$Evidence.window.clientWidthDip
    $clientHeightDip = [double]$Evidence.window.clientHeightDip
    if ($null -eq $Point -or $clientWidthDip -le 0 -or $clientHeightDip -le 0) {
        throw "GUI evidence did not expose a usable pointer target."
    }
    [pscustomobject]@{
        X = $WindowRectangle.Left + [int][Math]::Round(
            [double]$Point.x * $WindowWidth / $clientWidthDip)
        Y = $WindowRectangle.Top + [int][Math]::Round(
            [double]$Point.y * $WindowHeight / $clientHeightDip)
    }
}

function Invoke-MouseClick {
    param([Parameter(Mandatory = $true)][int]$X, [Parameter(Mandatory = $true)][int]$Y)
    if (-not [LumaChartAvaloniaCaptureNative]::SetCursorPos($X, $Y)) {
        throw "SetCursorPos failed before real mouse click."
    }
    Start-Sleep -Milliseconds 80
    [LumaChartAvaloniaCaptureNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 70
    [LumaChartAvaloniaCaptureNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Invoke-MouseRightClick {
    param(
        [Parameter(Mandatory = $true)][int]$X,
        [Parameter(Mandatory = $true)][int]$Y,
        [IntPtr]$ExpectedForegroundWindow = [IntPtr]::Zero)
    if ($ExpectedForegroundWindow -ne [IntPtr]::Zero -and
        [LumaChartAvaloniaCaptureNative]::GetForegroundWindow() -ne $ExpectedForegroundWindow) {
        throw "The expected GUI window lost foreground ownership before right-click positioning."
    }
    if (-not [LumaChartAvaloniaCaptureNative]::SetCursorPos($X, $Y)) {
        throw "SetCursorPos failed before real mouse right-click."
    }
    Start-Sleep -Milliseconds 80
    if ($ExpectedForegroundWindow -ne [IntPtr]::Zero -and
        [LumaChartAvaloniaCaptureNative]::GetForegroundWindow() -ne $ExpectedForegroundWindow) {
        throw "The expected GUI window lost foreground ownership before right-button down."
    }
    [LumaChartAvaloniaCaptureNative]::mouse_event(0x0008, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 70
    [LumaChartAvaloniaCaptureNative]::mouse_event(0x0010, 0, 0, 0, [UIntPtr]::Zero)
}

function Invoke-ModifiedMouseClick {
    param(
        [Parameter(Mandatory = $true)]$Element,
        [Parameter(Mandatory = $true)][ValidateSet("Shift", "Control")][string]$Modifier)

    $virtualKey = if ($Modifier -eq "Shift") { [byte]0x10 } else { [byte]0x11 }
    $modifierDown = $false
    try {
        [LumaChartAvaloniaCaptureNative]::keybd_event(
            $virtualKey,
            0,
            0,
            [UIntPtr]::Zero)
        $modifierDown = $true
        Start-Sleep -Milliseconds 70
        # This is deliberately a physical pointer click. Multi-selection gates
        # must never substitute SelectionItemPattern.Select/AddToSelection.
        Click-AutomationElementWithMouse -Element $Element
        Start-Sleep -Milliseconds 90
    }
    finally {
        if ($modifierDown) {
            [LumaChartAvaloniaCaptureNative]::keybd_event(
                $virtualKey,
                0,
                0x0002,
                [UIntPtr]::Zero)
        }
    }

    return [ordered]@{
        modifier = $Modifier
        input = "keybd_event+physical-left-click"
        virtualKey = [int]$virtualKey
        keyReleasedInFinally = $modifierDown
        automationSelectionFallbackUsed = $false
    }
}

function Invoke-PhysicalControlC {
    $controlDown = $false
    $cDown = $false
    try {
        [LumaChartAvaloniaCaptureNative]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero)
        $controlDown = $true
        Start-Sleep -Milliseconds 50
        try {
            [LumaChartAvaloniaCaptureNative]::keybd_event(0x43, 0, 0, [UIntPtr]::Zero)
            $cDown = $true
            Start-Sleep -Milliseconds 70
        }
        finally {
            if ($cDown) {
                [LumaChartAvaloniaCaptureNative]::keybd_event(
                    0x43,
                    0,
                    0x0002,
                    [UIntPtr]::Zero)
            }
        }
    }
    finally {
        if ($controlDown) {
            [LumaChartAvaloniaCaptureNative]::keybd_event(
                0x11,
                0,
                0x0002,
                [UIntPtr]::Zero)
        }
    }

    return [ordered]@{
        chord = "Ctrl+C"
        input = "keybd_event"
        controlReleasedInFinally = $controlDown
        cReleasedInFinally = $cDown
        automationKeyboardFallbackUsed = $false
    }
}

function Get-ClipboardTextWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$ExpectedText,
        [ValidateRange(100, 5000)][int]$TimeoutMilliseconds = 2500)

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    $lastText = $null
    do {
        Start-Sleep -Milliseconds 80
        try { $lastText = Get-Clipboard -Raw }
        catch { $lastText = $null }
        if ([string]$lastText -ceq $ExpectedText) { return [string]$lastText }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Physical Ctrl+C did not place the exact deletion-block message on the clipboard."
}

function Save-ScreenRegionScreenshot {
    param(
        [Parameter(Mandatory = $true)][int]$Left,
        [Parameter(Mandatory = $true)][int]$Top,
        [Parameter(Mandatory = $true)][int]$Width,
        [Parameter(Mandatory = $true)][int]$Height,
        [Parameter(Mandatory = $true)][string]$Path)

    if ($Width -le 0 -or $Height -le 0) { throw "Screen screenshot bounds are invalid." }
    $bitmap = [Drawing.Bitmap]::new($Width, $Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen($Left, $Top, 0, 0, [Drawing.Size]::new($Width, $Height))
        }
        finally { $graphics.Dispose() }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $bitmap.Dispose() }
}

function Save-AutomationElementScreenshot {
    param(
        [Alias("Element")][Parameter(Mandatory = $true)]$Observation,
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateRange(0, 200)][int]$Padding = 20)

    $bounds = if ($Observation -is [System.Windows.Automation.AutomationElement]) {
        $rectangle = $Observation.Current.BoundingRectangle
        [ordered]@{
            left = [double]$rectangle.Left
            top = [double]$rectangle.Top
            width = [double]$rectangle.Width
            height = [double]$rectangle.Height
        }
    } else { $Observation.Evidence.bounds }
    $left = [int][Math]::Max(0, [Math]::Floor([double]$bounds.left - $Padding))
    $top = [int][Math]::Max(0, [Math]::Floor([double]$bounds.top - $Padding))
    Save-ScreenRegionScreenshot `
        -Left $left `
        -Top $top `
        -Width ([int][Math]::Ceiling([double]$bounds.width + 2 * $Padding)) `
        -Height ([int][Math]::Ceiling([double]$bounds.height + 2 * $Padding)) `
        -Path $Path
}

function Invoke-MouseDrag {
    param(
        [Parameter(Mandatory = $true)][int]$StartX,
        [Parameter(Mandatory = $true)][int]$StartY,
        [Parameter(Mandatory = $true)][int]$EndX,
        [Parameter(Mandatory = $true)][int]$EndY,
        [ValidateRange(2, 20)][int]$Steps = 6
    )
    if (-not [LumaChartAvaloniaCaptureNative]::SetCursorPos($StartX, $StartY)) {
        throw "SetCursorPos failed before real mouse drag."
    }
    Start-Sleep -Milliseconds 80
    [LumaChartAvaloniaCaptureNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    try {
        for ($step = 1; $step -le $Steps; $step++) {
            $fraction = $step / [double]$Steps
            $x = [int][Math]::Round($StartX + ($EndX - $StartX) * $fraction)
            $y = [int][Math]::Round($StartY + ($EndY - $StartY) * $fraction)
            if (-not [LumaChartAvaloniaCaptureNative]::SetCursorPos($x, $y)) {
                throw "SetCursorPos failed during real mouse drag."
            }
            Start-Sleep -Milliseconds 55
        }
    }
    finally {
        [LumaChartAvaloniaCaptureNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    }
}

function Scroll-AutomationElementIntoView {
    param([Parameter(Mandatory = $true)]$Element)

    try {
        $scrollPatternObject = $null
        if ($Element.TryGetCurrentPattern(
                [System.Windows.Automation.ScrollItemPattern]::Pattern,
                [ref]$scrollPatternObject)) {
            ([System.Windows.Automation.ScrollItemPattern]$scrollPatternObject).ScrollIntoView()
            Start-Sleep -Milliseconds 180
        }
    }
    catch [System.Windows.Automation.ElementNotAvailableException] { throw }
    catch [Runtime.InteropServices.COMException] { }

    if (-not $Element.Current.IsOffscreen -and -not $Element.Current.BoundingRectangle.IsEmpty) {
        return
    }

    # Avalonia peers normally expose ScrollItemPattern. If a nested inspector
    # host omits it, deterministically walk the nearest vertical ScrollPattern
    # from top to bottom until the requested peer is actually on screen. Giving
    # the peer focus is a final BringIntoView-style fallback for focusable input.
    $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
    $ancestor = $walker.GetParent($Element)
    $depth = 0
    while ($ancestor -and $depth -lt 12 -and $Element.Current.IsOffscreen) {
        $ancestorScrollObject = $null
        if ($ancestor.TryGetCurrentPattern(
                [System.Windows.Automation.ScrollPattern]::Pattern,
                [ref]$ancestorScrollObject)) {
            $ancestorScroll = [System.Windows.Automation.ScrollPattern]$ancestorScrollObject
            if ($ancestorScroll.Current.VerticallyScrollable) {
                try {
                    $ancestorScroll.SetScrollPercent(
                        [System.Windows.Automation.ScrollPattern]::NoScroll,
                        0)
                    Start-Sleep -Milliseconds 100
                    for ($step = 0; $step -lt 40 -and $Element.Current.IsOffscreen; $step++) {
                        $ancestorScroll.Scroll(
                            [System.Windows.Automation.ScrollAmount]::NoAmount,
                            [System.Windows.Automation.ScrollAmount]::SmallIncrement)
                        Start-Sleep -Milliseconds 45
                    }
                }
                catch [System.Windows.Automation.ElementNotEnabledException] { }
                catch [System.Windows.Automation.ElementNotAvailableException] { throw }
                catch [Runtime.InteropServices.COMException] { }
            }
        }
        $ancestor = $walker.GetParent($ancestor)
        $depth++
    }
    if ($Element.Current.IsOffscreen -or $Element.Current.BoundingRectangle.IsEmpty) {
        try {
            $Element.SetFocus()
            Start-Sleep -Milliseconds 180
        }
        catch [System.Windows.Automation.ElementNotEnabledException] { }
        catch [System.Windows.Automation.ElementNotAvailableException] { throw }
        catch [Runtime.InteropServices.COMException] { }
        catch [InvalidOperationException] { }
    }
}

function Get-AutomationElementObservation {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle,
        [ValidateRange(100, 15000)][int]$TimeoutMilliseconds = 6000
    )

    $element = Find-AutomationElementById `
        -TargetProcessId $TargetProcessId `
        -AutomationId $AutomationId `
        -RootWindowHandle $RootWindowHandle `
        -TimeoutMilliseconds $TimeoutMilliseconds
    Scroll-AutomationElementIntoView -Element $element
    Start-Sleep -Milliseconds 80
    $element = Find-AutomationElementById `
        -TargetProcessId $TargetProcessId `
        -AutomationId $AutomationId `
        -RootWindowHandle $RootWindowHandle `
        -TimeoutMilliseconds $TimeoutMilliseconds
    $bounds = $element.Current.BoundingRectangle
    if ($element.Current.IsOffscreen -or $bounds.IsEmpty -or $bounds.Width -le 1 -or $bounds.Height -le 1) {
        throw "UI Automation id '$AutomationId' is offscreen or has invalid bounds."
    }
    return [pscustomobject]@{
        Element = $element
        Evidence = [ordered]@{
            automationId = $AutomationId
            name = [string]$element.Current.Name
            helpText = [string]$element.Current.HelpText
            controlType = [string]$element.Current.ControlType.ProgrammaticName
            isEnabled = [bool]$element.Current.IsEnabled
            isOffscreen = [bool]$element.Current.IsOffscreen
            bounds = [ordered]@{
                left = [double]$bounds.Left
                top = [double]$bounds.Top
                width = [double]$bounds.Width
                height = [double]$bounds.Height
            }
        }
    }
}

function Get-AutomationElementObservationByName {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle,
        [ValidateRange(100, 10000)][int]$TimeoutMilliseconds = 6000
    )

    $element = Find-AutomationElementByName `
        -TargetProcessId $TargetProcessId `
        -Name $Name `
        -RootWindowHandle $RootWindowHandle `
        -TimeoutMilliseconds $TimeoutMilliseconds
    Scroll-AutomationElementIntoView -Element $element
    Start-Sleep -Milliseconds 80
    $element = Find-AutomationElementByName `
        -TargetProcessId $TargetProcessId `
        -Name $Name `
        -RootWindowHandle $RootWindowHandle `
        -TimeoutMilliseconds $TimeoutMilliseconds
    $bounds = $element.Current.BoundingRectangle
    if ($element.Current.IsOffscreen -or $bounds.IsEmpty -or $bounds.Width -le 1 -or $bounds.Height -le 1) {
        throw "UI Automation name '$Name' is offscreen or has invalid bounds."
    }
    return [pscustomobject]@{
        Element = $element
        Evidence = [ordered]@{
            automationId = [string]$element.Current.AutomationId
            name = [string]$element.Current.Name
            controlType = [string]$element.Current.ControlType.ProgrammaticName
            isEnabled = [bool]$element.Current.IsEnabled
            isOffscreen = [bool]$element.Current.IsOffscreen
            bounds = [ordered]@{
                left = [double]$bounds.Left
                top = [double]$bounds.Top
                width = [double]$bounds.Width
                height = [double]$bounds.Height
            }
        }
    }
}

function Get-LibraryFolderItemObservation {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$UniqueName,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle,
        [ValidateRange(100, 15000)][int]$TimeoutMilliseconds = 10000
    )

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    $locator = $null
    $item = $null
    do {
        $list = Find-AutomationElementById `
            -TargetProcessId $TargetProcessId `
            -AutomationId "Library.List" `
            -RootWindowHandle $RootWindowHandle `
            -TimeoutMilliseconds 1000
        $folderIdCondition = [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
            "Library.FolderItem")
        $folderPeers = $list.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            $folderIdCondition)
        $peerMatches = [Collections.Generic.List[object]]::new()
        for ($index = 0; $index -lt $folderPeers.Count; $index++) {
            $candidate = $folderPeers.Item($index)
            $candidateName = [string]$candidate.Current.Name
            if ($candidateName.Equals($UniqueName, [StringComparison]::Ordinal) -or
                $candidateName.StartsWith(
                    $UniqueName + " · ",
                    [StringComparison]::Ordinal)) {
                $peerMatches.Add($candidate)
            }
        }
        if ($peerMatches.Count -gt 1) {
            throw "Library folder peer name '$UniqueName' is not unique."
        }
        if ($peerMatches.Count -eq 1) {
            $item = $peerMatches[0]
            $locator = "Library.FolderItem+unique-name"
            break
        }

        # Compatibility fallback for a materialized text peer: locate the
        # unique text and walk to its ListItem ancestor. Actions still fail
        # closed unless the ancestor is Library.FolderItem and exposes
        # SelectionItemPattern.
        $nameCondition = [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::NameProperty,
            $UniqueName)
        $textMatches = $list.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            $nameCondition)
        if ($textMatches.Count -gt 1) {
            throw "Library text fallback name '$UniqueName' is not unique."
        }
        if ($textMatches.Count -eq 1) {
            $candidate = $textMatches.Item(0)
            $walker = [System.Windows.Automation.TreeWalker]::RawViewWalker
            for ($depth = 0; $candidate -and $depth -lt 12; $depth++) {
                if ([string]$candidate.Current.AutomationId -eq "Library.FolderItem") {
                    $item = $candidate
                    $locator = "unique-text+Library.FolderItem-ancestor"
                    break
                }
                $candidate = $walker.GetParent($candidate)
            }
            if ($item) { break }
        }
        Start-Sleep -Milliseconds 80
    } while ([DateTime]::UtcNow -lt $deadline)

    if (-not $item) {
        throw "Timed out finding unique Library.FolderItem '$UniqueName'."
    }
    Scroll-AutomationElementIntoView -Element $item
    Start-Sleep -Milliseconds 100
    $bounds = $item.Current.BoundingRectangle
    $selectionItemObject = $null
    if ([string]$item.Current.AutomationId -ne "Library.FolderItem" -or
        [string]$item.Current.ControlType.ProgrammaticName -ne "ControlType.ListItem" -or
        -not $item.TryGetCurrentPattern(
            [System.Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$selectionItemObject) -or
        $item.Current.IsOffscreen -or $bounds.IsEmpty -or
        $bounds.Width -le 1 -or $bounds.Height -le 1) {
        throw "Library target '$UniqueName' is not a visible selectable Library.FolderItem ListItem."
    }
    $selectionItem = [System.Windows.Automation.SelectionItemPattern]$selectionItemObject
    return [pscustomobject]@{
        Element = $item
        Evidence = [ordered]@{
            automationId = [string]$item.Current.AutomationId
            name = [string]$item.Current.Name
            controlType = [string]$item.Current.ControlType.ProgrammaticName
            locator = $locator
            selectionItemPattern = $true
            isSelected = [bool]$selectionItem.Current.IsSelected
            isEnabled = [bool]$item.Current.IsEnabled
            isOffscreen = [bool]$item.Current.IsOffscreen
            bounds = [ordered]@{
                left = [double]$bounds.Left
                top = [double]$bounds.Top
                width = [double]$bounds.Width
                height = [double]$bounds.Height
            }
        }
    }
}

function Get-LibrarySelectionItemEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Automation.AutomationElement]$Element
    )

    $bounds = $Element.Current.BoundingRectangle
    $selectionItemObject = $null
    if ([string]$Element.Current.AutomationId -ne "Library.FolderItem" -or
        [string]$Element.Current.ControlType.ProgrammaticName -ne "ControlType.ListItem" -or
        -not $Element.TryGetCurrentPattern(
            [System.Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$selectionItemObject)) {
        throw "Library selection observation encountered a non-selectable FolderItem ListItem."
    }
    $selectionItem = [System.Windows.Automation.SelectionItemPattern]$selectionItemObject
    $selectionContainer = $selectionItem.Current.SelectionContainer
    if ($null -eq $selectionContainer -or
        [string]$selectionContainer.Current.AutomationId -ne "Library.List") {
        throw "Library.FolderItem SelectionContainer is not Library.List."
    }
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        controlType = [string]$Element.Current.ControlType.ProgrammaticName
        isSelected = [bool]$selectionItem.Current.IsSelected
        selectionContainer = [ordered]@{
            automationId = [string]$selectionContainer.Current.AutomationId
            controlType = [string]$selectionContainer.Current.ControlType.ProgrammaticName
            runtimeId = @($selectionContainer.GetRuntimeId())
        }
        bounds = [ordered]@{
            left = [double]$bounds.Left
            top = [double]$bounds.Top
            width = [double]$bounds.Width
            height = [double]$bounds.Height
        }
    }
}

function Get-LibraryListSelectionObservation {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    $list = Find-AutomationElementById `
        -TargetProcessId $TargetProcessId `
        -AutomationId "Library.List" `
        -RootWindowHandle $RootWindowHandle `
        -TimeoutMilliseconds 6000
    $selectionObject = $null
    if (-not $list.TryGetCurrentPattern(
            [System.Windows.Automation.SelectionPattern]::Pattern,
            [ref]$selectionObject)) {
        throw "Library.List does not expose SelectionPattern."
    }
    $selection = [System.Windows.Automation.SelectionPattern]$selectionObject
    if (-not $selection.Current.CanSelectMultiple) {
        throw "Library.List SelectionPattern does not permit multiple selection."
    }
    $selectionPatternElements = @($selection.Current.GetSelection())
    $selectionPatternItems = foreach ($selectedElement in $selectionPatternElements) {
        $evidence = Get-LibrarySelectionItemEvidence -Element $selectedElement
        if (-not [bool]$evidence.isSelected) {
            throw "Library.List SelectionPattern returned an item that is not selected."
        }
        $evidence
    }

    # Avalonia 12.1.0's Win32 bridge can return an empty parent
    # SelectionPattern array while the realized ListItem peers already expose
    # the correct SelectionItemPattern state during an open ContextMenu. Read
    # those peer states without invoking Select/Focus/Invoke and retain the raw
    # parent result alongside the effective observation.
    $folderIdCondition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
        "Library.FolderItem")
    $folderPeers = $list.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        $folderIdCondition)
    $realizedSelectedItems = [Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $folderPeers.Count; $index++) {
        $candidate = $folderPeers.Item($index)
        $selectionItemObject = $null
        if (-not $candidate.TryGetCurrentPattern(
                [System.Windows.Automation.SelectionItemPattern]::Pattern,
                [ref]$selectionItemObject)) {
            throw "Library.FolderItem does not expose SelectionItemPattern."
        }
        $selectionItem = [System.Windows.Automation.SelectionItemPattern]$selectionItemObject
        if ($selectionItem.Current.IsSelected) {
            $realizedSelectedItems.Add(
                (Get-LibrarySelectionItemEvidence -Element $candidate))
        }
    }
    $selectionPatternNames = @(
        $selectionPatternItems | ForEach-Object { [string]$_.name } | Sort-Object)
    $realizedNames = @(
        $realizedSelectedItems | ForEach-Object { [string]$_.name } | Sort-Object)
    $selectionPatternMatchesRealized =
        @($selectionPatternItems).Count -eq $realizedSelectedItems.Count -and
        [string]::Join("`n", $selectionPatternNames) -ceq
            [string]::Join("`n", $realizedNames)
    $effectiveItems = if ($realizedSelectedItems.Count -gt 0 -or
        @($selectionPatternItems).Count -eq 0) {
        @($realizedSelectedItems)
    } else {
        @($selectionPatternItems)
    }
    return [ordered]@{
        listAutomationId = [string]$list.Current.AutomationId
        listControlType = [string]$list.Current.ControlType.ProgrammaticName
        selectionPattern = $true
        canSelectMultiple = [bool]$selection.Current.CanSelectMultiple
        isSelectionRequired = [bool]$selection.Current.IsSelectionRequired
        selectionPatternSelectedCount = @($selectionPatternItems).Count
        selectionPatternSelectedItems = @($selectionPatternItems)
        realizedFolderItemCount = $folderPeers.Count
        selectionPatternMatchesRealized = $selectionPatternMatchesRealized
        selectionEvidenceSource = if ($selectionPatternMatchesRealized) {
            "SelectionPattern+SelectionItemPattern"
        } else {
            "SelectionItemPatternRealizedPeers"
        }
        selectedCount = @($effectiveItems).Count
        selectedItems = @($effectiveItems)
    }
}

function Assert-LibrarySelectionNames {
    param(
        [Parameter(Mandatory = $true)]$Observation,
        [Parameter(Mandatory = $true)][string[]]$ExpectedNames,
        [Parameter(Mandatory = $true)][string]$Step
    )

    $actualNames = @($Observation.selectedItems | ForEach-Object { [string]$_.name } | Sort-Object)
    $expectedSorted = @($ExpectedNames | Sort-Object)
    if ([int]$Observation.selectedCount -ne $expectedSorted.Count -or
        [string]::Join("`n", $actualNames) -cne [string]::Join("`n", $expectedSorted)) {
        throw "Library selection mismatch after $Step. Expected '$($expectedSorted -join ' | ')'; " +
              "observed '$($actualNames -join ' | ')'; parent SelectionPattern count=" +
              "'$([int]$Observation.selectionPatternSelectedCount)'."
    }
}

function Wait-LibrarySelectionNames {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle,
        [Parameter(Mandatory = $true)][string[]]$ExpectedNames,
        [Parameter(Mandatory = $true)][string]$Step,
        [int]$TimeoutMilliseconds = 3000,
        [int]$PollMilliseconds = 80
    )

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    $latestObservation = $null
    do {
        $latestObservation = Get-LibraryListSelectionObservation `
            -TargetProcessId $TargetProcessId `
            -RootWindowHandle $RootWindowHandle
        $actualNames = @(
            $latestObservation.selectedItems |
                ForEach-Object { [string]$_.name } |
                Sort-Object)
        $expectedSorted = @($ExpectedNames | Sort-Object)
        if ([int]$latestObservation.selectedCount -eq $expectedSorted.Count -and
            [string]::Join("`n", $actualNames) -ceq [string]::Join("`n", $expectedSorted)) {
            return $latestObservation
        }
        if ([DateTime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds $PollMilliseconds
        }
    } while ([DateTime]::UtcNow -lt $deadline)

    Assert-LibrarySelectionNames `
        -Observation $latestObservation `
        -ExpectedNames $ExpectedNames `
        -Step $Step
    throw "Library selection wait ended without an observation."
}

function Test-AutomationElementAbsentById {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [IntPtr]$RootWindowHandle = [IntPtr]::Zero
    )

    try {
        Find-AutomationElementById `
            -TargetProcessId $TargetProcessId `
            -AutomationId $AutomationId `
            -RootWindowHandle $RootWindowHandle `
            -TimeoutMilliseconds 350 | Out-Null
        return $false
    }
    catch {
        if ($_.Exception.Message -like "Timed out finding UI Automation id '*") {
            return $true
        }
        throw
    }
}

function Wait-AutomationToggleStateById {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][System.Windows.Automation.ToggleState]$ExpectedState,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle,
        [ValidateRange(100, 15000)][int]$TimeoutMilliseconds = 6000
    )

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $element = Find-AutomationElementById `
                -TargetProcessId $TargetProcessId `
                -AutomationId $AutomationId `
                -RootWindowHandle $RootWindowHandle `
                -TimeoutMilliseconds 500
            $toggleObject = $null
            if ($element.TryGetCurrentPattern(
                    [System.Windows.Automation.TogglePattern]::Pattern,
                    [ref]$toggleObject) -and
                ([System.Windows.Automation.TogglePattern]$toggleObject).Current.ToggleState -eq
                    $ExpectedState) {
                return $element
            }
        }
        catch [System.Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 80
    }
    while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out waiting for UI Automation id '$AutomationId' to reach $ExpectedState."
}

function Set-AutomationToggleStateWithMouse {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][System.Windows.Automation.ToggleState]$ExpectedState,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    $observation = Get-AutomationElementObservation `
        -TargetProcessId $TargetProcessId `
        -AutomationId $AutomationId `
        -RootWindowHandle $RootWindowHandle
    $toggleObject = $null
    if (-not $observation.Element.TryGetCurrentPattern(
            [System.Windows.Automation.TogglePattern]::Pattern,
            [ref]$toggleObject)) {
        throw "UI Automation id '$AutomationId' does not expose TogglePattern."
    }
    $toggle = [System.Windows.Automation.TogglePattern]$toggleObject
    if ($toggle.Current.ToggleState -eq $ExpectedState) {
        return $observation.Element
    }

    # Exercise one real mouse click. If foreground activation or a settling
    # ScrollViewer swallows it, use one explicit UIA fallback instead of issuing
    # repeated physical clicks at potentially stale screen coordinates.
    Click-AutomationElementWithMouse -Element $observation.Element
    try {
        return Wait-AutomationToggleStateById `
            -TargetProcessId $TargetProcessId `
            -AutomationId $AutomationId `
            -ExpectedState $ExpectedState `
            -RootWindowHandle $RootWindowHandle `
            -TimeoutMilliseconds 1800
    }
    catch {
        $observation = Get-AutomationElementObservation `
            -TargetProcessId $TargetProcessId `
            -AutomationId $AutomationId `
            -RootWindowHandle $RootWindowHandle
        $toggleObject = $null
        if (-not $observation.Element.TryGetCurrentPattern(
                [System.Windows.Automation.TogglePattern]::Pattern,
                [ref]$toggleObject)) {
            throw "UI Automation id '$AutomationId' lost TogglePattern after its physical click."
        }
        $toggle = [System.Windows.Automation.TogglePattern]$toggleObject
        if ($toggle.Current.ToggleState -ne $ExpectedState) {
            $toggle.Toggle()
            $script:keySoundToggleAutomationFallbackUsed = $true
        }
        return Wait-AutomationToggleStateById `
            -TargetProcessId $TargetProcessId `
            -AutomationId $AutomationId `
            -ExpectedState $ExpectedState `
            -RootWindowHandle $RootWindowHandle
    }
}

function Set-AutomationRangeValue {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][double]$Value,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    $observation = Get-AutomationElementObservation `
        -TargetProcessId $TargetProcessId `
        -AutomationId $AutomationId `
        -RootWindowHandle $RootWindowHandle
    $rangeObject = $null
    if (-not $observation.Element.TryGetCurrentPattern(
            [System.Windows.Automation.RangeValuePattern]::Pattern,
            [ref]$rangeObject)) {
        throw "UI Automation id '$AutomationId' does not expose RangeValuePattern."
    }
    $range = [System.Windows.Automation.RangeValuePattern]$rangeObject
    if ($range.Current.IsReadOnly) {
        throw "UI Automation id '$AutomationId' is read-only."
    }
    if ($Value -lt $range.Current.Minimum -or $Value -gt $range.Current.Maximum) {
        throw "Value $Value is outside '$AutomationId' range $($range.Current.Minimum)..$($range.Current.Maximum)."
    }
    $range.SetValue($Value)
    $deadline = [DateTime]::UtcNow.AddSeconds(4)
    do {
        Start-Sleep -Milliseconds 80
        $element = Find-AutomationElementById `
            -TargetProcessId $TargetProcessId `
            -AutomationId $AutomationId `
            -RootWindowHandle $RootWindowHandle `
            -TimeoutMilliseconds 500
        $updatedObject = $null
        if ($element.TryGetCurrentPattern(
                [System.Windows.Automation.RangeValuePattern]::Pattern,
                [ref]$updatedObject)) {
            $updated = [System.Windows.Automation.RangeValuePattern]$updatedObject
            if ([Math]::Abs([double]$updated.Current.Value - $Value) -le .001) {
                return [double]$updated.Current.Value
            }
        }
    }
    while ([DateTime]::UtcNow -lt $deadline)
    throw "UI Automation id '$AutomationId' did not retain range value $Value."
}

function Get-AutomationRangeValueObservation {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    $observation = Get-AutomationElementObservation `
        -TargetProcessId $TargetProcessId `
        -AutomationId $AutomationId `
        -RootWindowHandle $RootWindowHandle
    $rangeObject = $null
    if (-not $observation.Element.TryGetCurrentPattern(
            [System.Windows.Automation.RangeValuePattern]::Pattern,
            [ref]$rangeObject)) {
        throw "UI Automation id '$AutomationId' does not expose RangeValuePattern."
    }
    $range = [System.Windows.Automation.RangeValuePattern]$rangeObject
    return [pscustomobject]@{
        Element = $observation.Element
        Evidence = $observation.Evidence
        Value = [double]$range.Current.Value
        Minimum = [double]$range.Current.Minimum
        Maximum = [double]$range.Current.Maximum
        SmallChange = [double]$range.Current.SmallChange
        LargeChange = [double]$range.Current.LargeChange
    }
}

function Set-AutomationRangeValueWithMouse {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][double]$Value,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    # RangeValue is the authoritative, visible control operation. Follow it with
    # one real pointer click on the corresponding slider position. If platform
    # track padding makes that click land on a neighbouring step, restore the
    # exact requested value once through RangeValue and record the fallback.
    $actual = Set-AutomationRangeValue `
        -TargetProcessId $TargetProcessId `
        -AutomationId $AutomationId `
        -Value $Value `
        -RootWindowHandle $RootWindowHandle
    $rangeObservation = Get-AutomationRangeValueObservation `
        -TargetProcessId $TargetProcessId `
        -AutomationId $AutomationId `
        -RootWindowHandle $RootWindowHandle
    $bounds = $rangeObservation.Element.Current.BoundingRectangle
    $span = $rangeObservation.Maximum - $rangeObservation.Minimum
    if ($span -le 0 -or $bounds.IsEmpty -or $bounds.Width -le 16 -or $bounds.Height -le 2) {
        throw "UI Automation id '$AutomationId' has no usable visible slider range."
    }

    $fraction = ($Value - $rangeObservation.Minimum) / $span
    $pointerX = [int][Math]::Round($bounds.Left + 8 + ($bounds.Width - 16) * $fraction)
    $pointerY = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    $pointerClickAttempted = $false
    $pointerClickRetainedValue = $false
    $fallbackUsed = $false
    $pointerErrorType = $null
    try {
        Set-ForegroundWindowVerified -WindowHandle $RootWindowHandle
        $pointerClickAttempted = $true
        Invoke-MouseClick -X $pointerX -Y $pointerY
        Start-Sleep -Milliseconds 180
        $afterPointer = Get-AutomationRangeValueObservation `
            -TargetProcessId $TargetProcessId `
            -AutomationId $AutomationId `
            -RootWindowHandle $RootWindowHandle
        $pointerClickRetainedValue = [Math]::Abs($afterPointer.Value - $Value) -le .001
        if ($pointerClickRetainedValue) {
            $actual = $afterPointer.Value
        } else {
            $fallbackUsed = $true
            $actual = Set-AutomationRangeValue `
                -TargetProcessId $TargetProcessId `
                -AutomationId $AutomationId `
                -Value $Value `
                -RootWindowHandle $RootWindowHandle
        }
    }
    catch {
        $fallbackUsed = $true
        $pointerErrorType = $_.Exception.GetType().FullName
        $actual = Set-AutomationRangeValue `
            -TargetProcessId $TargetProcessId `
            -AutomationId $AutomationId `
            -Value $Value `
            -RootWindowHandle $RootWindowHandle
    }

    return [pscustomobject]@{
        RequestedValue = $Value
        ActualValue = [double]$actual
        PointerClickAttempted = $pointerClickAttempted
        PointerClickRetainedValue = $pointerClickRetainedValue
        PointerX = $pointerX
        PointerY = $pointerY
        AutomationFallbackUsed = $fallbackUsed
        PointerErrorType = $pointerErrorType
    }
}

function Get-AutomationSelectionValue {
    param([Parameter(Mandatory = $true)]$Element)

    $selectionObject = $null
    if ($Element.TryGetCurrentPattern(
            [System.Windows.Automation.SelectionPattern]::Pattern,
            [ref]$selectionObject)) {
        $selected = @(([System.Windows.Automation.SelectionPattern]$selectionObject).Current.GetSelection())
        if ($selected.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$selected[0].Current.Name)) {
            return [string]$selected[0].Current.Name
        }
    }
    $valueObject = $null
    if ($Element.TryGetCurrentPattern(
            [System.Windows.Automation.ValuePattern]::Pattern,
            [ref]$valueObject)) {
        $value = [string]([System.Windows.Automation.ValuePattern]$valueObject).Current.Value
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
    }
    $descendants = $Element.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition)
    for ($index = 0; $index -lt $descendants.Count; $index++) {
        $candidate = $descendants.Item($index)
        $selectionItemObject = $null
        if ($candidate.TryGetCurrentPattern(
                [System.Windows.Automation.SelectionItemPattern]::Pattern,
                [ref]$selectionItemObject) -and
            ([System.Windows.Automation.SelectionItemPattern]$selectionItemObject).Current.IsSelected) {
            return [string]$candidate.Current.Name
        }
    }
    return [string]$Element.Current.Name
}

function Click-AutomationElementWithMouse {
    param(
        [Parameter(Mandatory = $true)]$Element,
        [switch]$SkipScroll
    )

    if (-not $SkipScroll) {
        Scroll-AutomationElementIntoView -Element $Element
    }
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.IsEmpty -or $bounds.Width -le 1 -or $bounds.Height -le 1) {
        throw "UI Automation element '$($Element.Current.Name)' has invalid bounds."
    }
    $x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    if (-not [LumaChartAvaloniaCaptureNative]::SetCursorPos($x, $y)) {
        throw "SetCursorPos failed for UI Automation element '$($Element.Current.Name)'."
    }
    Start-Sleep -Milliseconds 80
    [LumaChartAvaloniaCaptureNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [LumaChartAvaloniaCaptureNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Get-StateConfirmedUnsavedDialogObservation {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][IntPtr]$DialogHandle,
        [Parameter(Mandatory = $true)][string]$ExpectedName
    )

    $isWindow = $DialogHandle -ne [IntPtr]::Zero -and
        [LumaChartAvaloniaCaptureNative]::IsWindow($DialogHandle)
    $element = $null
    $uiaAvailable = $false
    $name = $null
    $processId = 0
    $observedNativeWindowHandle = 0L
    $isEnabled = $false
    $isOffscreen = $true
    $boundsEvidence = [ordered]@{
        left = 0.0
        top = 0.0
        width = 0.0
        height = 0.0
    }
    if ($isWindow) {
        try {
            $element = [System.Windows.Automation.AutomationElement]::FromHandle(
                $DialogHandle)
            $bounds = $element.Current.BoundingRectangle
            $name = [string]$element.Current.Name
            $processId = [int]$element.Current.ProcessId
            $observedNativeWindowHandle =
                [long]$element.Current.NativeWindowHandle
            $isEnabled = [bool]$element.Current.IsEnabled
            $isOffscreen = [bool]$element.Current.IsOffscreen
            $boundsEvidence = [ordered]@{
                left = [double]$bounds.Left
                top = [double]$bounds.Top
                width = [double]$bounds.Width
                height = [double]$bounds.Height
            }
            $uiaAvailable = $true
        }
        catch [System.Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
    }
    $identityMatches = $uiaAvailable -and
        $processId -eq $TargetProcessId -and
        $observedNativeWindowHandle -eq [long]$DialogHandle -and
        [string]::Equals($name, $ExpectedName, [StringComparison]::Ordinal)
    $verified = $isWindow -and
        $identityMatches -and
        $isEnabled -and
        -not $isOffscreen -and
        [double]$boundsEvidence.width -gt 1 -and
        [double]$boundsEvidence.height -gt 1
    return [pscustomobject]@{
        Element = if ($verified) { $element } else { $null }
        Evidence = [ordered]@{
            expectedName = $ExpectedName
            targetProcessId = $TargetProcessId
            nativeWindowHandle = [long]$DialogHandle
            observedNativeWindowHandle = $observedNativeWindowHandle
            nativeWindowHandleMatches =
                $observedNativeWindowHandle -eq [long]$DialogHandle
            isWindow = $isWindow
            uiaAvailable = $uiaAvailable
            name = $name
            processId = $processId
            isEnabled = $isEnabled
            isOffscreen = $isOffscreen
            bounds = $boundsEvidence
            identityMatches = $identityMatches
            verified = $verified
        }
    }
}

function Get-StateConfirmedPhysicalButtonObservation {
    param(
        [Parameter(Mandatory = $true)]$DialogElement,
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$ExpectedName
    )

    $nameCondition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::NameProperty,
        $ExpectedName)
    try {
        $candidates = $DialogElement.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            $nameCondition)
    }
    catch [System.Windows.Automation.ElementNotAvailableException] {
        $candidates = $null
    }
    catch [Runtime.InteropServices.COMException] {
        $candidates = $null
    }
    $candidateCount = if ($null -eq $candidates) { 0 } else { $candidates.Count }
    $eligible = [Collections.Generic.List[object]]::new()
    if ($null -ne $candidates) {
        for ($candidateIndex = 0;
             $candidateIndex -lt $candidates.Count;
             $candidateIndex++) {
            try {
                $candidate = $candidates.Item($candidateIndex)
                $candidateBounds = $candidate.Current.BoundingRectangle
                if ([int]$candidate.Current.ProcessId -eq $TargetProcessId -and
                    [string]::Equals(
                        [string]$candidate.Current.Name,
                        $ExpectedName,
                        [StringComparison]::Ordinal) -and
                    [string]$candidate.Current.ControlType.ProgrammaticName -ceq
                        "ControlType.Button" -and
                    [bool]$candidate.Current.IsEnabled -and
                    -not [bool]$candidate.Current.IsOffscreen -and
                    -not $candidateBounds.IsEmpty -and
                    $candidateBounds.Width -gt 1 -and
                    $candidateBounds.Height -gt 1) {
                    $eligible.Add($candidate)
                }
            }
            catch [System.Windows.Automation.ElementNotAvailableException] { }
            catch [Runtime.InteropServices.COMException] { }
        }
    }
    $button = if ($eligible.Count -eq 1) { $eligible[0] } else { $null }
    $buttonBoundsEvidence = [ordered]@{
        left = 0.0
        top = 0.0
        width = 0.0
        height = 0.0
    }
    $buttonEvidence = [ordered]@{
        expectedName = $ExpectedName
        candidateCount = $candidateCount
        eligibleCount = $eligible.Count
        name = $null
        automationId = $null
        className = $null
        controlType = $null
        processId = 0
        isEnabled = $false
        isOffscreen = $true
        bounds = $buttonBoundsEvidence
        verified = $false
    }
    if ($null -ne $button) {
        try {
            $buttonBounds = $button.Current.BoundingRectangle
            $buttonEvidence.name = [string]$button.Current.Name
            $buttonEvidence.automationId = [string]$button.Current.AutomationId
            $buttonEvidence.className = [string]$button.Current.ClassName
            $buttonEvidence.controlType =
                [string]$button.Current.ControlType.ProgrammaticName
            $buttonEvidence.processId = [int]$button.Current.ProcessId
            $buttonEvidence.isEnabled = [bool]$button.Current.IsEnabled
            $buttonEvidence.isOffscreen = [bool]$button.Current.IsOffscreen
            $buttonEvidence.bounds = [ordered]@{
                left = [double]$buttonBounds.Left
                top = [double]$buttonBounds.Top
                width = [double]$buttonBounds.Width
                height = [double]$buttonBounds.Height
            }
            $buttonEvidence.verified =
                $buttonEvidence.processId -eq $TargetProcessId -and
                [string]::Equals(
                    [string]$buttonEvidence.name,
                    $ExpectedName,
                    [StringComparison]::Ordinal) -and
                [string]$buttonEvidence.controlType -ceq "ControlType.Button" -and
                [bool]$buttonEvidence.isEnabled -and
                -not [bool]$buttonEvidence.isOffscreen -and
                [double]$buttonEvidence.bounds.width -gt 1 -and
                [double]$buttonEvidence.bounds.height -gt 1
        }
        catch [System.Windows.Automation.ElementNotAvailableException] {
            $button = $null
            $buttonEvidence.verified = $false
        }
        catch [Runtime.InteropServices.COMException] {
            $button = $null
            $buttonEvidence.verified = $false
        }
    }
    return [pscustomobject]@{
        Element = if ([bool]$buttonEvidence.verified) { $button } else { $null }
        Evidence = $buttonEvidence
    }
}

function Invoke-StateConfirmedUnsavedDiscardPhysicalClick {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][IntPtr]$DialogHandle,
        [Parameter(Mandatory = $true)][int]$AttemptNumber,
        [Parameter(Mandatory = $true)][string]$Reason
    )

    $dialogName = "未保存的更改"
    $buttonName = "放弃更改"
    $dialogBefore = Get-StateConfirmedUnsavedDialogObservation `
        -TargetProcessId $TargetProcessId `
        -DialogHandle $DialogHandle `
        -ExpectedName $dialogName
    if (-not [bool]$dialogBefore.Evidence.verified) {
        throw "Discard attempt $AttemptNumber did not observe the same live unsaved-changes dialog."
    }
    $buttonBefore = Get-StateConfirmedPhysicalButtonObservation `
        -DialogElement $dialogBefore.Element `
        -TargetProcessId $TargetProcessId `
        -ExpectedName $buttonName
    if (-not [bool]$buttonBefore.Evidence.verified) {
        throw "Discard attempt $AttemptNumber did not observe exactly one enabled visible discard button with valid bounds."
    }

    $foregroundBefore = [LumaChartAvaloniaCaptureNative]::GetForegroundWindow()
    Set-ForegroundWindowVerified -WindowHandle $DialogHandle
    $dialogAtClick = Get-StateConfirmedUnsavedDialogObservation `
        -TargetProcessId $TargetProcessId `
        -DialogHandle $DialogHandle `
        -ExpectedName $dialogName
    if (-not [bool]$dialogAtClick.Evidence.verified) {
        throw "Discard attempt $AttemptNumber lost the same unsaved-changes dialog after foreground activation."
    }
    $buttonAtClick = Get-StateConfirmedPhysicalButtonObservation `
        -DialogElement $dialogAtClick.Element `
        -TargetProcessId $TargetProcessId `
        -ExpectedName $buttonName
    if (-not [bool]$buttonAtClick.Evidence.verified) {
        throw "Discard attempt $AttemptNumber lost the enabled visible discard button before physical click."
    }
    $foregroundAtClick = [LumaChartAvaloniaCaptureNative]::GetForegroundWindow()
    if ($foregroundAtClick -ne $DialogHandle) {
        throw "Discard attempt $AttemptNumber did not retain the unsaved dialog as foreground."
    }
    $buttonBounds = $buttonAtClick.Element.Current.BoundingRectangle
    $clickX = [int][Math]::Round($buttonBounds.Left + $buttonBounds.Width / 2)
    $clickY = [int][Math]::Round($buttonBounds.Top + $buttonBounds.Height / 2)
    if (-not [LumaChartAvaloniaCaptureNative]::SetCursorPos($clickX, $clickY)) {
        throw "Discard attempt $AttemptNumber could not position the real cursor over the discard button."
    }
    Start-Sleep -Milliseconds 80
    $hitPoint = [LumaChartAvaloniaCaptureNative+POINT]::new()
    $hitPoint.X = $clickX
    $hitPoint.Y = $clickY
    $foregroundBeforeMouseDown =
        [LumaChartAvaloniaCaptureNative]::GetForegroundWindow()
    $hitWindowHandle =
        [LumaChartAvaloniaCaptureNative]::WindowFromPoint($hitPoint)
    $hitRootWindowHandle = if ($hitWindowHandle -ne [IntPtr]::Zero) {
        [LumaChartAvaloniaCaptureNative]::GetAncestor(
            $hitWindowHandle,
            [LumaChartAvaloniaCaptureNative]::GA_ROOT)
    } else {
        [IntPtr]::Zero
    }
    [uint32]$hitRootProcessId = 0
    $hitRootThreadId = if ($hitRootWindowHandle -ne [IntPtr]::Zero) {
        [LumaChartAvaloniaCaptureNative]::GetWindowThreadProcessId(
            $hitRootWindowHandle,
            [ref]$hitRootProcessId)
    } else {
        0
    }
    $hitWindowIsWindow = $hitWindowHandle -ne [IntPtr]::Zero -and
        [LumaChartAvaloniaCaptureNative]::IsWindow($hitWindowHandle)
    $hitRootWindowIsWindow = $hitRootWindowHandle -ne [IntPtr]::Zero -and
        [LumaChartAvaloniaCaptureNative]::IsWindow($hitRootWindowHandle)
    $hitTestVerified = $foregroundBeforeMouseDown -eq $DialogHandle -and
        $hitWindowIsWindow -and
        $hitRootWindowIsWindow -and
        $hitRootWindowHandle -eq $DialogHandle -and
        [uint32]$hitRootProcessId -eq [uint32]$TargetProcessId
    $hitTestObservedAtUtc = [DateTimeOffset]::UtcNow
    if (-not $hitTestVerified) {
        throw "Discard attempt $AttemptNumber hit-test was obstructed before mouse-down; foreground=$foregroundBeforeMouseDown hit=$hitWindowHandle root=$hitRootWindowHandle rootPid=$hitRootProcessId."
    }
    $attemptObservedAtUtc = [DateTimeOffset]::UtcNow
    [LumaChartAvaloniaCaptureNative]::mouse_event(
        0x0002,
        0,
        0,
        0,
        [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [LumaChartAvaloniaCaptureNative]::mouse_event(
        0x0004,
        0,
        0,
        0,
        [UIntPtr]::Zero)
    $hitTestEvidence = [ordered]@{
        cursorPoint = [ordered]@{
            x = $clickX
            y = $clickY
        }
        foregroundWindowHandle = [long]$foregroundBeforeMouseDown
        expectedDialogWindowHandle = [long]$DialogHandle
        hitWindowHandle = [long]$hitWindowHandle
        rootWindowHandle = [long]$hitRootWindowHandle
        rootThreadId = [uint32]$hitRootThreadId
        rootProcessId = [uint32]$hitRootProcessId
        targetProcessId = $TargetProcessId
        hitWindowIsWindow = $hitWindowIsWindow
        rootWindowIsWindow = $hitRootWindowIsWindow
        foregroundMatchesExpectedDialog =
            $foregroundBeforeMouseDown -eq $DialogHandle
        rootMatchesExpectedDialog = $hitRootWindowHandle -eq $DialogHandle
        rootProcessMatchesTarget =
            [uint32]$hitRootProcessId -eq [uint32]$TargetProcessId
        verified = $hitTestVerified
        observedAtUtc = $hitTestObservedAtUtc
    }
    return [ordered]@{
        attemptNumber = $AttemptNumber
        reason = $Reason
        sameDialogAsInitial = $true
        observedAtUtc = $attemptObservedAtUtc
        dialog = $dialogAtClick.Evidence
        foregroundBeforeActivation = [long]$foregroundBefore
        foregroundAtClick = [long]$foregroundAtClick
        button = $buttonAtClick.Evidence
        hitTest = $hitTestEvidence
        physicalClick = $true
        invokePatternUsed = $false
        clickedAtUtc = [DateTimeOffset]::UtcNow
    }
}

function Invoke-AutomationElement {
    param([Parameter(Mandatory = $true)]$Element)

    $invokePatternObject = $null
    if (-not $Element.TryGetCurrentPattern(
            [System.Windows.Automation.InvokePattern]::Pattern,
            [ref]$invokePatternObject)) {
        throw "UI Automation element '$($Element.Current.Name)' does not expose InvokePattern."
    }
    ([System.Windows.Automation.InvokePattern]$invokePatternObject).Invoke()
}

function Wait-AutomationToggleState {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][System.Windows.Automation.ToggleState]$ExpectedState,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle,
        [ValidateRange(100, 15000)][int]$TimeoutMilliseconds = 6000
    )

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $element = Find-AutomationElementByName `
                -TargetProcessId $TargetProcessId `
                -Name $Name `
                -RootWindowHandle $RootWindowHandle `
                -TimeoutMilliseconds 500
            $togglePatternObject = $null
            if ($element.TryGetCurrentPattern(
                    [System.Windows.Automation.TogglePattern]::Pattern,
                    [ref]$togglePatternObject) -and
                ([System.Windows.Automation.TogglePattern]$togglePatternObject).Current.ToggleState -eq
                    $ExpectedState) {
                return $element
            }
        }
        catch { }
        Start-Sleep -Milliseconds 80
    }
    while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out waiting for UI Automation element '$Name' to reach $ExpectedState."
}

function Invoke-IdempotentButtonAndWaitForToggleState {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$ButtonName,
        [Parameter(Mandatory = $true)][string]$ToggleName,
        [Parameter(Mandatory = $true)][System.Windows.Automation.ToggleState]$ExpectedState,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle,
        [ValidateRange(100, 15000)][int]$TimeoutMilliseconds = 6000
    )

    $button = Find-AutomationElementByName `
        -TargetProcessId $TargetProcessId `
        -Name $ButtonName `
        -RootWindowHandle $RootWindowHandle
    Click-AutomationElementWithMouse -Element $button
    try {
        $toggle = Wait-AutomationToggleState `
            -TargetProcessId $TargetProcessId `
            -Name $ToggleName `
            -ExpectedState $ExpectedState `
            -RootWindowHandle $RootWindowHandle `
            -TimeoutMilliseconds 1200
        return [pscustomobject]@{
            Element = $toggle
            AutomationFallbackUsed = $false
        }
    }
    catch {
        # The physical pointer path can lose its first click when Windows denies a
        # foreground transition. This action is idempotent, so invoke the same
        # visible button once through UI Automation and keep the structural/state
        # assertions below as the fail-closed proof of the resulting behavior.
        $button = Find-AutomationElementByName `
            -TargetProcessId $TargetProcessId `
            -Name $ButtonName `
            -RootWindowHandle $RootWindowHandle
        Invoke-AutomationElement -Element $button
        $toggle = Wait-AutomationToggleState `
            -TargetProcessId $TargetProcessId `
            -Name $ToggleName `
            -ExpectedState $ExpectedState `
            -RootWindowHandle $RootWindowHandle `
            -TimeoutMilliseconds $TimeoutMilliseconds
        return [pscustomobject]@{
            Element = $toggle
            AutomationFallbackUsed = $true
        }
    }
}

function Set-AutomationElementValue {
    param(
        [Parameter(Mandatory = $true)]$Element,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string]$Value
    )

    $patternObject = $null
    if (-not $Element.TryGetCurrentPattern(
            [System.Windows.Automation.ValuePattern]::Pattern,
            [ref]$patternObject)) {
        throw "UI Automation element '$($Element.Current.Name)' does not expose ValuePattern."
    }
    $pattern = [System.Windows.Automation.ValuePattern]$patternObject
    if ($pattern.Current.IsReadOnly) {
        throw "UI Automation element '$($Element.Current.Name)' is read-only."
    }
    $pattern.SetValue($Value)
}

function Get-AutomationElementValueObservation {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    $observation = Get-AutomationElementObservation `
        -TargetProcessId $TargetProcessId `
        -AutomationId $AutomationId `
        -RootWindowHandle $RootWindowHandle
    $patternObject = $null
    if (-not $observation.Element.TryGetCurrentPattern(
            [System.Windows.Automation.ValuePattern]::Pattern,
            [ref]$patternObject)) {
        throw "UI Automation id '$AutomationId' does not expose ValuePattern."
    }
    return [pscustomobject]@{
        Element = $observation.Element
        Evidence = $observation.Evidence
        Value = [string]([System.Windows.Automation.ValuePattern]$patternObject).Current.Value
    }
}

function Get-AutomationToggleObservation {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    $observation = Get-AutomationElementObservation `
        -TargetProcessId $TargetProcessId `
        -AutomationId $AutomationId `
        -RootWindowHandle $RootWindowHandle
    $patternObject = $null
    if (-not $observation.Element.TryGetCurrentPattern(
            [System.Windows.Automation.TogglePattern]::Pattern,
            [ref]$patternObject)) {
        throw "UI Automation id '$AutomationId' does not expose TogglePattern."
    }
    $toggleState = ([System.Windows.Automation.TogglePattern]$patternObject).Current.ToggleState
    return [pscustomobject]@{
        Element = $observation.Element
        Evidence = [ordered]@{
            automationId = $observation.Evidence.automationId
            name = $observation.Evidence.name
            controlType = $observation.Evidence.controlType
            isEnabled = $observation.Evidence.isEnabled
            isOffscreen = $observation.Evidence.isOffscreen
            bounds = $observation.Evidence.bounds
            toggleState = [string]$toggleState
            isChecked = $toggleState -eq [System.Windows.Automation.ToggleState]::On
        }
    }
}

function Select-AutomationComboItemWithRecordedMouse {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$ComboAutomationId,
        [Parameter(Mandatory = $true)][string]$ItemName,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    Set-ForegroundWindowVerified -WindowHandle $RootWindowHandle
    $comboBefore = Get-AutomationElementObservation `
        -TargetProcessId $TargetProcessId `
        -AutomationId $ComboAutomationId `
        -RootWindowHandle $RootWindowHandle
    Click-AutomationElementWithMouse -Element $comboBefore.Element
    $item = Find-AutomationElementByName `
        -TargetProcessId $TargetProcessId `
        -Name $ItemName `
        -TimeoutMilliseconds 4000
    $itemEvidence = [ordered]@{
        name = [string]$item.Current.Name
        automationId = [string]$item.Current.AutomationId
        controlType = [string]$item.Current.ControlType.ProgrammaticName
    }
    Click-AutomationElementWithMouse -Element $item
    Start-Sleep -Milliseconds 220
    $comboAfter = Get-AutomationElementObservation `
        -TargetProcessId $TargetProcessId `
        -AutomationId $ComboAutomationId `
        -RootWindowHandle $RootWindowHandle
    $physicalSelectionRetained = [string]$comboAfter.Evidence.name -eq $ItemName
    $automationSelectionFallbackUsed = $false
    if (-not $physicalSelectionRetained) {
        Click-AutomationElementWithMouse -Element $comboAfter.Element
        $item = Find-AutomationElementByName `
            -TargetProcessId $TargetProcessId `
            -Name $ItemName `
            -TimeoutMilliseconds 4000
        $selectionObject = $null
        if (-not $item.TryGetCurrentPattern(
                [System.Windows.Automation.SelectionItemPattern]::Pattern,
                [ref]$selectionObject)) {
            throw "Chart export mode item '$ItemName' did not expose SelectionItemPattern for the explicit fallback."
        }
        ([System.Windows.Automation.SelectionItemPattern]$selectionObject).Select()
        $automationSelectionFallbackUsed = $true
        Start-Sleep -Milliseconds 220
        $comboAfter = Get-AutomationElementObservation `
            -TargetProcessId $TargetProcessId `
            -AutomationId $ComboAutomationId `
            -RootWindowHandle $RootWindowHandle
    }
    if ([string]$comboAfter.Evidence.name -ne $ItemName) {
        throw "Chart export mode ComboBox did not retain '$ItemName'."
    }
    return [ordered]@{
        requested = $ItemName
        input = "physical Win32 mouse clicks on ComboBox and exact item"
        physicalClickAttempted = $true
        physicalSelectionRetained = $physicalSelectionRetained
        automationSelectionFallbackUsed = $automationSelectionFallbackUsed
        item = $itemEvidence
        before = $comboBefore.Evidence
        after = $comboAfter.Evidence
    }
}

function Set-AutomationTextWithCommittedPhysicalInput {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$CommitByFocusLossAutomationId,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    Set-ForegroundWindowVerified -WindowHandle $RootWindowHandle
    $before = Get-AutomationElementValueObservation `
        -TargetProcessId $TargetProcessId `
        -AutomationId $AutomationId `
        -RootWindowHandle $RootWindowHandle
    Click-AutomationElementWithMouse -Element $before.Element
    Start-Sleep -Milliseconds 100
    $focusBefore = Get-FocusedAutomationElementEvidence
    $inputFocusAutomationFallbackUsed = $false
    $inputFocusAutomationFallbackError = ""
    if ([string]$focusBefore.Evidence.automationId -ne $AutomationId) {
        $inputFocusAutomationFallbackUsed = $true
        try {
            $before.Element.SetFocus()
        }
        catch {
            $inputFocusAutomationFallbackError = $_.Exception.Message
        }
        Start-Sleep -Milliseconds 120
        $focusBefore = Get-FocusedAutomationElementEvidence
    }
    if ([string]$focusBefore.Evidence.automationId -ne $AutomationId -or
        [int]$focusBefore.Evidence.processId -ne $TargetProcessId) {
        throw "UI Automation id '$AutomationId' did not receive keyboard focus after its physical click and recorded fallback. Fallback error: $inputFocusAutomationFallbackError"
    }
    [System.Windows.Forms.SendKeys]::SendWait("^a")
    $expectedInputEventCount = [uint]($Value.Length * 2)
    $sentInputEventCount = [LumaChartAvaloniaCaptureNative]::SendUnicodeText($Value)
    $sendInputError = [LumaChartAvaloniaCaptureNative]::LastSendInputError
    $focusLossTarget = Get-AutomationElementObservation `
        -TargetProcessId $TargetProcessId `
        -AutomationId $CommitByFocusLossAutomationId `
        -RootWindowHandle $RootWindowHandle
    Click-AutomationElementWithMouse -Element $focusLossTarget.Element
    [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
    Start-Sleep -Milliseconds 250
    $focusAfterPhysicalLoss = Get-FocusedAutomationElementEvidence
    $focusLossAutomationFallbackUsed = $false
    $focusLossAutomationFallbackError = ""
    if ([string]$focusAfterPhysicalLoss.Evidence.automationId -eq $AutomationId) {
        $focusLossAutomationFallbackUsed = $true
        try {
            $focusLossTarget.Element.SetFocus()
        }
        catch {
            $focusLossAutomationFallbackError = $_.Exception.Message
            Click-AutomationElementWithMouse -Element $focusLossTarget.Element
        }
        Start-Sleep -Milliseconds 120
        $focusAfterPhysicalLoss = Get-FocusedAutomationElementEvidence
    }
    if ([string]$focusAfterPhysicalLoss.Evidence.automationId -eq $AutomationId) {
        throw "UI Automation id '$AutomationId' retained keyboard focus after its explicit focus-loss commit. Fallback error: $focusLossAutomationFallbackError"
    }
    if ([int]$focusAfterPhysicalLoss.Evidence.processId -ne $TargetProcessId) {
        throw "Keyboard focus left the chart-export process during the explicit focus-loss commit."
    }
    $after = Get-AutomationElementValueObservation `
        -TargetProcessId $TargetProcessId `
        -AutomationId $AutomationId `
        -RootWindowHandle $RootWindowHandle
    $physicalInputRetained = $sentInputEventCount -eq $expectedInputEventCount -and
        $after.Value -eq $Value
    $automationValueFallbackUsed = $false
    if (-not $physicalInputRetained) {
        Set-AutomationElementValue -Element $after.Element -Value $Value
        $automationValueFallbackUsed = $true
        Click-AutomationElementWithMouse -Element $after.Element
        Start-Sleep -Milliseconds 100
        $fallbackInputFocus = Get-FocusedAutomationElementEvidence
        if ([string]$fallbackInputFocus.Evidence.automationId -ne $AutomationId) {
            $inputFocusAutomationFallbackUsed = $true
            try {
                $after.Element.SetFocus()
            }
            catch {
                $inputFocusAutomationFallbackError = $_.Exception.Message
            }
            Start-Sleep -Milliseconds 120
            $fallbackInputFocus = Get-FocusedAutomationElementEvidence
        }
        if ([string]$fallbackInputFocus.Evidence.automationId -ne $AutomationId -or
            [int]$fallbackInputFocus.Evidence.processId -ne $TargetProcessId) {
            throw "UI Automation id '$AutomationId' did not receive keyboard focus while committing the explicit ValuePattern fallback. Fallback error: $inputFocusAutomationFallbackError"
        }
        $focusLossTarget = Get-AutomationElementObservation `
            -TargetProcessId $TargetProcessId `
            -AutomationId $CommitByFocusLossAutomationId `
            -RootWindowHandle $RootWindowHandle
        Click-AutomationElementWithMouse -Element $focusLossTarget.Element
        [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
        Start-Sleep -Milliseconds 250
        $focusAfterFallbackCommit = Get-FocusedAutomationElementEvidence
        $fallbackFocusLossAutomationFallbackUsed = $false
        if ([string]$focusAfterFallbackCommit.Evidence.automationId -eq $AutomationId) {
            $fallbackFocusLossAutomationFallbackUsed = $true
            try {
                $focusLossTarget.Element.SetFocus()
            }
            catch {
                $focusLossAutomationFallbackError = $_.Exception.Message
                Click-AutomationElementWithMouse -Element $focusLossTarget.Element
            }
            Start-Sleep -Milliseconds 120
            $focusAfterFallbackCommit = Get-FocusedAutomationElementEvidence
        }
        $focusLossAutomationFallbackUsed = $focusLossAutomationFallbackUsed -or
            $fallbackFocusLossAutomationFallbackUsed
        if ([string]$focusAfterFallbackCommit.Evidence.automationId -eq $AutomationId -or
            [int]$focusAfterFallbackCommit.Evidence.processId -ne $TargetProcessId) {
            throw "UI Automation id '$AutomationId' did not leave keyboard focus while committing the explicit ValuePattern fallback. Fallback error: $focusLossAutomationFallbackError"
        }
        $focusAfterPhysicalLoss = $focusAfterFallbackCommit
        $after = Get-AutomationElementValueObservation `
            -TargetProcessId $TargetProcessId `
            -AutomationId $AutomationId `
            -RootWindowHandle $RootWindowHandle
    }
    if ($after.Value -ne $Value) {
        throw "UI Automation id '$AutomationId' did not retain the requested text '$Value'."
    }
    return [ordered]@{
        automationId = $AutomationId
        requested = $Value
        input = "physical focus + Ctrl+A + Win32 SendInput KEYEVENTF_UNICODE + explicit physical focus loss"
        imeCommitGuard = "Unicode input bypasses the IME composition buffer and an explicit pointer focus loss commits the field"
        commitByFocusLossAutomationId = $CommitByFocusLossAutomationId
        focusLossTarget = $focusLossTarget.Evidence
        focusAfterCommit = $focusAfterPhysicalLoss.Evidence
        physicalFocusLossObserved = -not $focusLossAutomationFallbackUsed
        automationFocusFallbackUsed = $focusLossAutomationFallbackUsed
        automationFocusFallbackError = $focusLossAutomationFallbackError
        automationInputFocusFallbackUsed = $inputFocusAutomationFallbackUsed
        automationInputFocusFallbackError = $inputFocusAutomationFallbackError
        focusBeforeInput = $focusBefore.Evidence
        expectedSendInputEventCount = [int]$expectedInputEventCount
        sentInputEventCount = [int]$sentInputEventCount
        sendInputError = [int]$sendInputError
        physicalInputRetained = $physicalInputRetained
        automationValueFallbackUsed = $automationValueFallbackUsed
        fallbackAlsoCommittedWithExplicitFocusLoss = $automationValueFallbackUsed
        before = [ordered]@{ control = $before.Evidence; value = $before.Value }
        after = [ordered]@{ control = $after.Evidence; value = $after.Value }
    }
}

function Get-NativeFilePickerAddressEvidence {
    param(
        [Parameter(Mandatory = $true)]$DialogElement,
        [Parameter(Mandatory = $true)][string]$ExpectedDirectory,
        [ValidateRange(250, 10000)][int]$TimeoutMilliseconds = 5000
    )

    $resolvedDirectory = [IO.Path]::GetFullPath($ExpectedDirectory)
    if (-not (Test-Path -LiteralPath $resolvedDirectory -PathType Container)) {
        throw "Native file-picker expected directory does not exist: $resolvedDirectory"
    }
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    $observedAddressNames = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    do {
        $allControls = $DialogElement.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            [System.Windows.Automation.Condition]::TrueCondition)
        $exactMatches = [Collections.Generic.List[object]]::new()
        for ($index = 0; $index -lt $allControls.Count; $index++) {
            $candidate = $allControls.Item($index)
            if ([string]$candidate.Current.AutomationId -ne "1001" -or
                [string]$candidate.Current.ClassName -ne "ToolbarWindow32") {
                continue
            }
            $name = [string]$candidate.Current.Name
            if ($name -notmatch '^(地址|Address)\s*:') { continue }
            [void]$observedAddressNames.Add($name)
            $separatorIndex = $name.IndexOf(':')
            $reportedDirectory = $name.Substring($separatorIndex + 1).Trim()
            $comparableReportedDirectory = if ($reportedDirectory.StartsWith(
                    '\\?\UNC\',
                    [StringComparison]::OrdinalIgnoreCase)) {
                '\\' + $reportedDirectory.Substring(8)
            }
            elseif ($reportedDirectory.StartsWith(
                    '\\?\',
                    [StringComparison]::OrdinalIgnoreCase)) {
                $reportedDirectory.Substring(4)
            }
            else {
                $reportedDirectory
            }
            if ($comparableReportedDirectory.Equals(
                    $resolvedDirectory,
                    [StringComparison]::OrdinalIgnoreCase)) {
                $exactMatches.Add([pscustomobject]@{
                    Element = $candidate
                    Name = $name
                    ReportedDirectory = $reportedDirectory
                    ComparableReportedDirectory = $comparableReportedDirectory
                })
            }
        }
        if ($exactMatches.Count -eq 1) {
            $match = $exactMatches[0]
            $bounds = $match.Element.Current.BoundingRectangle
            return [ordered]@{
                injected = $true
                requestedDirectory = $resolvedDirectory
                reportedDirectory = $match.ReportedDirectory
                comparableReportedDirectory = $match.ComparableReportedDirectory
                exactDirectoryVerified = $true
                automationId = [string]$match.Element.Current.AutomationId
                className = [string]$match.Element.Current.ClassName
                name = $match.Name
                controlType = [string]$match.Element.Current.ControlType.ProgrammaticName
                bounds = [ordered]@{
                    left = [double]$bounds.Left
                    top = [double]$bounds.Top
                    width = [double]$bounds.Width
                    height = [double]$bounds.Height
                }
            }
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)

    throw "Native file picker address toolbar did not exactly report '$resolvedDirectory'. Observed: $(@($observedAddressNames) -join '; ')"
}

function Get-NativeDialogElementEvidence {
    param([Parameter(Mandatory = $true)]$Element)

    $bounds = $Element.Current.BoundingRectangle
    [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        className = [string]$Element.Current.ClassName
        controlType = [string]$Element.Current.ControlType.ProgrammaticName
        processId = [int]$Element.Current.ProcessId
        nativeWindowHandle = [long]$Element.Current.NativeWindowHandle
        isEnabled = [bool]$Element.Current.IsEnabled
        isOffscreen = [bool]$Element.Current.IsOffscreen
        bounds = [ordered]@{
            left = [double]$bounds.Left
            top = [double]$bounds.Top
            width = [double]$bounds.Width
            height = [double]$bounds.Height
        }
    }
}

function Find-NativeDialogButton {
    param(
        [Parameter(Mandatory = $true)]$DialogElement,
        [Parameter(Mandatory = $true)][string]$NamePattern,
        [string[]]$PreferredAutomationIds = @()
    )

    $descendants = $DialogElement.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition)
    # Do not use the name $matches here: PowerShell's case-insensitive
    # automatic $Matches variable is replaced by every -match/-notmatch below.
    $buttonCandidates = [Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $descendants.Count; $index++) {
        $candidate = $descendants.Item($index)
        $bounds = $candidate.Current.BoundingRectangle
        if ([string]$candidate.Current.Name -notmatch $NamePattern -or
            -not [bool]$candidate.Current.IsEnabled -or
            [bool]$candidate.Current.IsOffscreen -or
            $bounds.IsEmpty -or $bounds.Width -le 1 -or $bounds.Height -le 1) {
            continue
        }
        $buttonCandidates.Add($candidate)
    }
    if ($buttonCandidates.Count -gt 1 -and $PreferredAutomationIds.Count -gt 0) {
        $preferred = @($buttonCandidates | Where-Object {
                $PreferredAutomationIds -contains [string]$_.Current.AutomationId
            })
        if ($preferred.Count -eq 1) {
            $preferredButton = $preferred[0]
            $buttonCandidates.Clear()
            $buttonCandidates.Add($preferredButton)
        }
    }
    if ($buttonCandidates.Count -ne 1) {
        $diagnostics = @($buttonCandidates | ForEach-Object {
                "id='$([string]$_.Current.AutomationId)' name='$([string]$_.Current.Name)'"
            }) -join '; '
        throw "Native dialog did not expose one enabled visible button matching '$NamePattern'; found $($buttonCandidates.Count). $diagnostics"
    }
    $button = $buttonCandidates[0]
    [pscustomobject]@{
        Element = $button
        Evidence = Get-NativeDialogElementEvidence -Element $button
    }
}

function Find-NativeOverwriteConfirmation {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$ExpectedLeaf,
        [ValidateRange(250, 10000)][int]$TimeoutMilliseconds = 6000
    )

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    $observedTitles = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal)
    do {
        $windows = [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
            [System.Windows.Automation.TreeScope]::Children,
            [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($window in $windows) {
            $title = [string]$window.Current.Name
            if (-not [string]::IsNullOrWhiteSpace($title)) { [void]$observedTitles.Add($title) }
            if ($title -notmatch '^(确认另存为|Confirm Save As)$') { continue }
            $handle = [IntPtr]$window.Current.NativeWindowHandle
            if ($handle -eq [IntPtr]::Zero -or
                -not [LumaChartAvaloniaCaptureNative]::IsWindow($handle)) {
                continue
            }
            $descendants = $window.FindAll(
                [System.Windows.Automation.TreeScope]::Descendants,
                [System.Windows.Automation.Condition]::TrueCondition)
            $unsortedNames = @(
                for ($index = 0; $index -lt $descendants.Count; $index++) {
                    $name = [string]$descendants.Item($index).Current.Name
                    if (-not [string]::IsNullOrWhiteSpace($name)) { $name }
                })
            $names = @($unsortedNames | Sort-Object -Unique)
            $existingMessagePresent = @($names | Where-Object {
                    $_ -match '(已存在|already exists)' -and
                    $_.Contains($ExpectedLeaf, [StringComparison]::OrdinalIgnoreCase)
                }).Count -ge 1
            if (-not $existingMessagePresent) { continue }
            $confirm = Find-NativeDialogButton `
                -DialogElement $window `
                -NamePattern '^(是|Yes|替换|Replace)' `
                -PreferredAutomationIds @('6', 'CommandButton_6')
            return [pscustomobject]@{
                Dialog = $window
                ConfirmButton = $confirm.Element
                Evidence = [ordered]@{
                    dialog = Get-NativeDialogElementEvidence -Element $window
                    childNames = $names
                    expectedLeaf = $ExpectedLeaf
                    existingTargetMessagePresent = $true
                    requestedProcessId = $TargetProcessId
                    actualProcessId = [int]$window.Current.ProcessId
                    confirm = $confirm.Evidence
                }
            }
        }
        Start-Sleep -Milliseconds 80
    }
    while ([DateTime]::UtcNow -lt $deadline)

    throw "Native overwrite confirmation for '$ExpectedLeaf' was not found. Observed desktop-window titles: $(@($observedTitles) -join '; ')"
}

function Get-IntegerGreatestCommonDivisor {
    param(
        [Parameter(Mandatory = $true)][int]$Left,
        [Parameter(Mandatory = $true)][int]$Right
    )

    $leftValue = [Math]::Abs([long]$Left)
    $rightValue = [Math]::Abs([long]$Right)
    while ($rightValue -ne 0) {
        $remainder = $leftValue % $rightValue
        $leftValue = $rightValue
        $rightValue = $remainder
    }
    return [int]$leftValue
}

function Test-BeatEvidenceEqual {
    param($Left, $Right)

    return $null -ne $Left -and $null -ne $Right -and
        [int]$Left.bar -eq [int]$Right.bar -and
        [int]$Left.numerator -eq [int]$Right.numerator -and
        [int]$Left.denominator -eq [int]$Right.denominator
}

function Test-PlacementTargetEvidenceEqual {
    param($Left, $Right)

    return $null -ne $Left -and $null -ne $Right -and
        [int]$Left.lane -eq [int]$Right.lane -and
        (Test-BeatEvidenceEqual -Left $Left.beat -Right $Right.beat) -and
        $null -ne $Left.windowPointDip -and $null -ne $Right.windowPointDip -and
        [double]$Left.windowPointDip.x -eq [double]$Right.windowPointDip.x -and
        [double]$Left.windowPointDip.y -eq [double]$Right.windowPointDip.y
}

function Test-ProEditorTargetEvidenceEqual {
    param($Left, $Right)

    return $null -ne $Left -and $null -ne $Right -and
        [int]$Left.workspaceColumn -eq [int]$Right.workspaceColumn -and
        [bool]$Left.isDraft -eq [bool]$Right.isDraft -and
        (Test-BeatEvidenceEqual -Left $Left.beat -Right $Right.beat) -and
        $null -ne $Left.windowPointDip -and $null -ne $Right.windowPointDip -and
        [double]$Left.windowPointDip.x -eq [double]$Right.windowPointDip.x -and
        [double]$Left.windowPointDip.y -eq [double]$Right.windowPointDip.y
}

function Assert-InteractionWindowRemaining {
    param(
        [Parameter(Mandatory = $true)]$PrimaryEvidence,
        [ValidateRange(250, 30000)][int]$MinimumMilliseconds
    )

    $primaryGeneratedAt = [DateTimeOffset]::Parse(
        [string]$PrimaryEvidence.generatedAtUtc,
        [Globalization.CultureInfo]::InvariantCulture)
    $conservativeCaptureAt = $primaryGeneratedAt.AddMilliseconds($InteractionDelayMilliseconds)
    $remaining = ($conservativeCaptureAt - [DateTimeOffset]::UtcNow).TotalMilliseconds
    if ($remaining -lt $MinimumMilliseconds) {
        throw "Only $([Math]::Round($remaining)) ms remain before the interaction sample; " +
              "$MinimumMilliseconds ms are required for this real GUI exercise."
    }
}

function Get-DirectoryTreeEvidence {
    param([Parameter(Mandatory = $true)][string]$Root)

    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $fullRoot -PathType Container)) {
        throw "Directory tree does not exist: $fullRoot"
    }
    $files = @(
        Get-ChildItem -LiteralPath $fullRoot -Recurse -File -Force |
            Sort-Object FullName |
            ForEach-Object {
                $relative = [IO.Path]::GetRelativePath($fullRoot, $_.FullName).
                    Replace([IO.Path]::DirectorySeparatorChar, '/')
                [pscustomobject][ordered]@{
                    relativePath = $relative
                    length = [long]$_.Length
                    lastWriteTimeUtc = $_.LastWriteTimeUtc.ToString(
                        "O",
                        [Globalization.CultureInfo]::InvariantCulture)
                    sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
                }
            })
    $contentLines = @($files | ForEach-Object {
            "{0}|{1}|{2}" -f $_.relativePath, $_.length, $_.sha256
        })
    $fullLines = @($files | ForEach-Object {
            "{0}|{1}|{2}|{3}" -f $_.relativePath, $_.length, $_.lastWriteTimeUtc, $_.sha256
        })
    $contentBytes = [Text.Encoding]::UTF8.GetBytes(($contentLines -join "`n"))
    $fullBytes = [Text.Encoding]::UTF8.GetBytes(($fullLines -join "`n"))
    [pscustomobject][ordered]@{
        root = $fullRoot
        fileCount = $files.Count
        totalBytes = [long](($files | Measure-Object -Property length -Sum).Sum ?? 0)
        contentSha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($contentBytes))
        fullSha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($fullBytes))
        files = $files
    }
}

function Test-DirectoryTreeEvidenceEqual {
    param($Before, $After)

    return $null -ne $Before -and $null -ne $After -and
        [int]$Before.fileCount -eq [int]$After.fileCount -and
        [long]$Before.totalBytes -eq [long]$After.totalBytes -and
        [string]$Before.contentSha256 -ceq [string]$After.contentSha256 -and
        [string]$Before.fullSha256 -ceq [string]$After.fullSha256
}

function Add-JsonSemanticMapNode {
    param(
        $Value,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Path,
        [Parameter(Mandatory = $true)]$Map
    )

    $nodePath = if ([string]::IsNullOrEmpty($Path)) { '/' } else { $Path }
    if ($null -eq $Value) {
        $Map[$nodePath] = 'null'
        return
    }
    if ($Value -is [pscustomobject]) {
        $properties = @($Value.PSObject.Properties | Sort-Object Name)
        $Map[$nodePath] = "object:$($properties.Count)"
        foreach ($property in $properties) {
            $escapedName = ([string]$property.Name).Replace('~', '~0').Replace('/', '~1')
            $childPath = if ([string]::IsNullOrEmpty($Path)) {
                "/$escapedName"
            } else {
                "$Path/$escapedName"
            }
            Add-JsonSemanticMapNode -Value $property.Value -Path $childPath -Map $Map
        }
        return
    }
    if ($Value -is [Collections.IDictionary]) {
        $keys = @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)
        $Map[$nodePath] = "object:$($keys.Count)"
        foreach ($key in $keys) {
            $escapedName = $key.Replace('~', '~0').Replace('/', '~1')
            $childPath = if ([string]::IsNullOrEmpty($Path)) {
                "/$escapedName"
            } else {
                "$Path/$escapedName"
            }
            Add-JsonSemanticMapNode -Value $Value[$key] -Path $childPath -Map $Map
        }
        return
    }
    if ($Value -is [Collections.IList] -and $Value -isnot [string]) {
        $Map[$nodePath] = "array:$($Value.Count)"
        for ($index = 0; $index -lt $Value.Count; $index++) {
            $childPath = if ([string]::IsNullOrEmpty($Path)) {
                "/$index"
            } else {
                "$Path/$index"
            }
            Add-JsonSemanticMapNode -Value $Value[$index] -Path $childPath -Map $Map
        }
        return
    }
    if ($Value -is [bool]) {
        $Map[$nodePath] = if ([bool]$Value) { 'boolean:true' } else { 'boolean:false' }
        return
    }
    if ($Value -is [string]) {
        $Map[$nodePath] = 'string:' + [string]$Value
        return
    }
    if ($Value -is [IFormattable]) {
        $Map[$nodePath] = 'number:' + $Value.ToString(
            $null,
            [Globalization.CultureInfo]::InvariantCulture)
        return
    }
    $Map[$nodePath] = 'value:' + [string]$Value
}

function ConvertTo-JsonSemanticMap {
    param([Parameter(Mandatory = $true)]$Value)

    $map = [Collections.Generic.SortedDictionary[string, string]]::new(
        [StringComparer]::Ordinal)
    Add-JsonSemanticMapNode -Value $Value -Path '' -Map $map
    return ,$map
}

function Compare-JsonSemanticMaps {
    param(
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)]$Actual
    )

    $keys = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    foreach ($key in $Expected.Keys) { [void]$keys.Add([string]$key) }
    foreach ($key in $Actual.Keys) { [void]$keys.Add([string]$key) }
    $differences = [Collections.Generic.List[object]]::new()
    foreach ($key in $keys) {
        $hasExpected = $Expected.ContainsKey($key)
        $hasActual = $Actual.ContainsKey($key)
        $expectedValue = if ($hasExpected) { [string]$Expected[$key] } else { $null }
        $actualValue = if ($hasActual) { [string]$Actual[$key] } else { $null }
        if (-not $hasExpected -or -not $hasActual -or
            -not $expectedValue.Equals($actualValue, [StringComparison]::Ordinal)) {
            $differences.Add([pscustomobject][ordered]@{
                    path = $key
                    kind = if (-not $hasExpected) {
                        'unexpected'
                    } elseif (-not $hasActual) {
                        'missing'
                    } else {
                        'changed'
                    }
                    expected = $expectedValue
                    actual = $actualValue
                }) | Out-Null
        }
    }
    return @($differences)
}

function Get-JsonSemanticSha256 {
    param([Parameter(Mandatory = $true)]$Value)

    $map = ConvertTo-JsonSemanticMap -Value $Value
    $memory = [IO.MemoryStream]::new()
    try {
        $writer = [IO.BinaryWriter]::new(
            $memory,
            [Text.UTF8Encoding]::new($false),
            $true)
        try {
            foreach ($entry in $map.GetEnumerator()) {
                $pathBytes = [Text.Encoding]::UTF8.GetBytes([string]$entry.Key)
                $valueBytes = [Text.Encoding]::UTF8.GetBytes([string]$entry.Value)
                $writer.Write([int]$pathBytes.Length)
                $writer.Write($pathBytes, 0, $pathBytes.Length)
                $writer.Write([int]$valueBytes.Length)
                $writer.Write($valueBytes, 0, $valueBytes.Length)
            }
            $writer.Flush()
        }
        finally {
            $writer.Dispose()
        }
        return [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($memory.ToArray()))
    }
    finally {
        $memory.Dispose()
    }
}

function Get-ContentManifestSha256 {
    param([Parameter(Mandatory = $true)][object[]]$Rows)

    $canonicalLines = @($Rows | Sort-Object relativePath | ForEach-Object {
            "{0}|{1}|{2}" -f
                [string]$_.relativePath,
                [long]$_.length,
                [string]$_.sha256
        })
    $bytes = [Text.Encoding]::UTF8.GetBytes(($canonicalLines -join "`n"))
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes))
}

function Get-MalodyFullPackageArchiveEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$MainChartFileName,
        [Parameter(Mandatory = $true)]$ExpectedBeat,
        [Parameter(Mandatory = $true)]$OriginalBeat,
        [Parameter(Mandatory = $true)][int]$ExpectedLane
    )

    Add-Type -AssemblyName System.IO.Compression
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Malody package does not exist: $fullPath"
    }
    $entries = [Collections.Generic.List[object]]::new()
    $archive = [IO.Compression.ZipFile]::OpenRead($fullPath)
    try {
        foreach ($entry in $archive.Entries | Sort-Object FullName) {
            if ([string]::IsNullOrWhiteSpace($entry.Name)) { continue }
            $memory = [IO.MemoryStream]::new()
            try {
                $stream = $entry.Open()
                try { $stream.CopyTo($memory) } finally { $stream.Dispose() }
                $bytes = $memory.ToArray()
            }
            finally {
                $memory.Dispose()
            }
            $isMc = [IO.Path]::GetExtension($entry.FullName).Equals(
                ".mc",
                [StringComparison]::OrdinalIgnoreCase)
            $jsonValid = $null
            $compactJson = $null
            $utf8Bom = $null
            $exactBeatMatchCount = $null
            $originalBeatMatchCount = $null
            $matchingNotes = $null
            if ($isMc) {
                $jsonText = [Text.Encoding]::UTF8.GetString($bytes)
                try {
                    # PowerShell expands byte[] when binding overloaded methods;
                    # parse the exact UTF-8 text so valid compact MC entries are
                    # not misclassified by overload resolution.
                    $json = [Text.Json.JsonDocument]::Parse($jsonText)
                    $json.Dispose()
                    $jsonValid = $true
                }
                catch {
                    $jsonValid = $false
                }
                $utf8Bom = $bytes.Length -ge 3 -and
                    $bytes[0] -eq [byte]0xEF -and
                    $bytes[1] -eq [byte]0xBB -and
                    $bytes[2] -eq [byte]0xBF
                $compactJson = -not ($bytes -contains [byte]10) -and
                    -not ($bytes -contains [byte]13) -and
                    -not $utf8Bom
                if ([IO.Path]::GetFileName($entry.FullName).Equals(
                        $MainChartFileName,
                        [StringComparison]::OrdinalIgnoreCase)) {
                    $parsedMainChart = $jsonText | ConvertFrom-Json
                    $playableNotes = @($parsedMainChart.note | Where-Object {
                            $null -ne $_.column -and $null -ne $_.beat -and
                            @($_.beat).Count -ge 3 -and
                            [int]$_.column -eq $ExpectedLane
                        })
                    $matchingNotes = @($playableNotes | Where-Object {
                            [int]$_.beat[0] -eq [int]$ExpectedBeat.bar -and
                            [int]$_.beat[1] -eq [int]$ExpectedBeat.numerator -and
                            [int]$_.beat[2] -eq [int]$ExpectedBeat.denominator
                        } | ForEach-Object {
                            [ordered]@{
                                beat = @([int]$_.beat[0], [int]$_.beat[1], [int]$_.beat[2])
                                column = [int]$_.column
                                endBeat = if ($null -eq $_.endbeat) { $null } else { @($_.endbeat) }
                                volume = if ($null -eq $_.vol) { 100 } else { [int]$_.vol }
                                sound = if ($null -eq $_.sound) { $null } else { [string]$_.sound }
                                group = if ($null -eq $_.group) { 0 } else { [int]$_.group }
                            }
                        })
                    $exactBeatMatchCount = $matchingNotes.Count
                    $originalBeatMatchCount = @($playableNotes | Where-Object {
                            [int]$_.beat[0] -eq [int]$OriginalBeat.bar -and
                            [int]$_.beat[1] -eq [int]$OriginalBeat.numerator -and
                            [int]$_.beat[2] -eq [int]$OriginalBeat.denominator
                        }).Count
                }
            }
            $entries.Add([pscustomobject][ordered]@{
                fullName = $entry.FullName.Replace('\', '/')
                length = [long]$entry.Length
                compressedLength = [long]$entry.CompressedLength
                sha256 = [Convert]::ToHexString(
                    [Security.Cryptography.SHA256]::HashData($bytes))
                isMalodyChart = $isMc
                jsonValid = $jsonValid
                compactJson = $compactJson
                utf8Bom = $utf8Bom
                exactBeatMatchCount = $exactBeatMatchCount
                originalBeatMatchCount = $originalBeatMatchCount
                matchingNotes = $matchingNotes
            })
        }
    }
    finally {
        $archive.Dispose()
    }

    $entryNames = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $entries) { [void]$entryNames.Add([string]$entry.fullName) }
    $collisionEntries = @($entries | Where-Object {
            $directory = [IO.Path]::GetDirectoryName([string]$_.fullName)?.Replace('\', '/')
            $stem = [IO.Path]::GetFileNameWithoutExtension([string]$_.fullName)
            $extension = [IO.Path]::GetExtension([string]$_.fullName)
            if ($stem -notmatch '^(?<base>.+)_(?<index>[2-9][0-9]*)$') { return $false }
            $baseName = $Matches.base + $extension
            $basePath = if ([string]::IsNullOrWhiteSpace($directory)) {
                $baseName
            } else {
                "$directory/$baseName"
            }
            return $entryNames.Contains($basePath)
        } | Select-Object -ExpandProperty fullName)
    $chartEntries = @($entries | Where-Object { $_.isMalodyChart })
    $mainEntry = @($chartEntries | Where-Object {
            [IO.Path]::GetFileName([string]$_.fullName).Equals(
                $MainChartFileName,
                [StringComparison]::OrdinalIgnoreCase)
        })
    $unsafeEntries = @($entries | Where-Object {
            $name = [string]$_.fullName
            $name.StartsWith('/') -or $name.Contains(':') -or
            @($name.Split('/') | Where-Object { $_ -in '.', '..' }).Count -gt 0
        } | Select-Object -ExpandProperty fullName)
    [pscustomobject][ordered]@{
        path = $fullPath
        sizeBytes = (Get-Item -LiteralPath $fullPath).Length
        sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
        entryCount = $entries.Count
        chartEntryCount = $chartEntries.Count
        allChartsValidJson = @($chartEntries | Where-Object { -not $_.jsonValid }).Count -eq 0
        allChartsCompact = @($chartEntries | Where-Object { -not $_.compactJson }).Count -eq 0
        mainChartEntryCount = $mainEntry.Count
        mainChartEntry = $mainEntry | Select-Object -First 1
        mainChartExactBeatMatchCount = if ($mainEntry.Count -eq 1) {
            [int]$mainEntry[0].exactBeatMatchCount
        } else { 0 }
        mainChartOriginalBeatMatchCount = if ($mainEntry.Count -eq 1) {
            [int]$mainEntry[0].originalBeatMatchCount
        } else { 0 }
        collisionEntryCount = $collisionEntries.Count
        collisionEntries = $collisionEntries
        unsafeEntryCount = $unsafeEntries.Count
        unsafeEntries = $unsafeEntries
        entries = $entries
    }
}

function Get-OsuToMalodyFullPackageArchiveEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)]$ExpectedBeat,
        [Parameter(Mandatory = $true)]$OriginalBeat,
        [Parameter(Mandatory = $true)][int]$ExpectedLane,
        [Parameter(Mandatory = $true)][int]$OriginalLane
    )

    Add-Type -AssemblyName System.IO.Compression
    $fullPath = [IO.Path]::GetFullPath($Path)
    $sourceRootFullPath = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $sourceRootFullPath -PathType Container)) {
        throw "osu!-to-Malody package or isolated source root is missing."
    }

    $archive = [IO.Compression.ZipFile]::OpenRead($fullPath)
    try {
        $fileEntries = @($archive.Entries | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_.Name)
            })
        $mcEntries = @($fileEntries | Where-Object {
                [IO.Path]::GetExtension($_.FullName).Equals(
                    '.mc',
                    [StringComparison]::OrdinalIgnoreCase)
            })
        if ($mcEntries.Count -ne 1) {
            throw "osu!-to-Malody MCZ must contain exactly one target MC; found $($mcEntries.Count)."
        }
        $mainChartFileName = [IO.Path]::GetFileName($mcEntries[0].FullName)
        if ($mcEntries[0].FullName.Replace('\', '/') -cne $mainChartFileName -or
            $mainChartFileName -cnotmatch '^\d+_1x\.mc$') {
            throw "osu!-to-Malody MCZ main chart did not use the exact flat Unix-time *_1x.mc identity."
        }
        $mainMemory = [IO.MemoryStream]::new()
        try {
            $mainStream = $mcEntries[0].Open()
            try { $mainStream.CopyTo($mainMemory) } finally { $mainStream.Dispose() }
            $mainBytes = $mainMemory.ToArray()
        }
        finally { $mainMemory.Dispose() }
    }
    finally { $archive.Dispose() }

    $baseEvidence = Get-MalodyFullPackageArchiveEvidence `
        -Path $fullPath `
        -MainChartFileName $mainChartFileName `
        -ExpectedBeat $ExpectedBeat `
        -OriginalBeat $OriginalBeat `
        -ExpectedLane $ExpectedLane
    $mainChart = [Text.Encoding]::UTF8.GetString($mainBytes) | ConvertFrom-Json
    $playableNotes = @($mainChart.note | Where-Object {
            $null -ne $_.column -and $null -ne $_.beat -and @($_.beat).Count -ge 3
        })
    $exactTargetNotes = @($playableNotes | Where-Object {
            [int]$_.column -eq $ExpectedLane -and $null -eq $_.endbeat -and
            [int]$_.beat[0] -eq [int]$ExpectedBeat.bar -and
            [int]$_.beat[1] -eq [int]$ExpectedBeat.numerator -and
            [int]$_.beat[2] -eq [int]$ExpectedBeat.denominator
        })
    $originalTargetNotes = @($playableNotes | Where-Object {
            [int]$_.column -eq $OriginalLane -and $null -eq $_.endbeat -and
            [int]$_.beat[0] -eq [int]$OriginalBeat.bar -and
            [int]$_.beat[1] -eq [int]$OriginalBeat.numerator -and
            [int]$_.beat[2] -eq [int]$OriginalBeat.denominator
        })

    $sourceArtifactFiles = @(Get-ChildItem -LiteralPath $sourceRootFullPath -File |
        Where-Object { $_.Extension -in '.osu', '.mc', '.mcz', '.osz', '.luma-part' })
    $sourceArtifactEvidence = @($sourceArtifactFiles | ForEach-Object {
            $sourceArtifact = $_
            $matches = @($baseEvidence.entries | Where-Object {
                    ([string]$_.fullName).Equals(
                        $sourceArtifact.Name,
                        [StringComparison]::OrdinalIgnoreCase)
                })
            [pscustomobject][ordered]@{
                name = $sourceArtifact.Name
                sourcePath = $sourceArtifact.FullName
                sourceLength = [long]$sourceArtifact.Length
                sourceSha256 = (Get-FileHash -LiteralPath $sourceArtifact.FullName -Algorithm SHA256).Hash
                archiveMatchCount = $matches.Count
                excluded = $matches.Count -eq 0
            }
        } | Sort-Object name)

    $sourceResourceFiles = @(Get-ChildItem -LiteralPath $sourceRootFullPath -File |
        Where-Object { $_.Extension -notin '.osu', '.mc', '.mcz', '.osz', '.luma-part' })
    $resourceChains = [Collections.Generic.List[object]]::new()
    $claimedResourceEntryNames = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    foreach ($sourceResource in $sourceResourceFiles) {
        $sourceHash = (Get-FileHash -LiteralPath $sourceResource.FullName -Algorithm SHA256).Hash
        $stem = [Text.RegularExpressions.Regex]::Escape(
            [IO.Path]::GetFileNameWithoutExtension($sourceResource.Name))
        $extension = [Text.RegularExpressions.Regex]::Escape($sourceResource.Extension)
        $namePattern = '^' + $stem + '(?:_[2-9][0-9]*)?' + $extension + '$'
        $matches = @($baseEvidence.entries | Where-Object {
                [IO.Path]::GetFileName([string]$_.fullName) -cmatch $namePattern
            })
        foreach ($match in $matches) {
            [void]$claimedResourceEntryNames.Add([string]$match.fullName)
        }
        $exact = $matches.Count -ge 1 -and
            @($matches | Where-Object {
                    [string]$_.sha256 -cne $sourceHash -or
                    [long]$_.length -ne [long]$sourceResource.Length
                }).Count -eq 0
        $resourceChains.Add([pscustomobject][ordered]@{
                sourceName = $sourceResource.Name
                sourcePath = $sourceResource.FullName
                sourceLength = [long]$sourceResource.Length
                sourceSha256 = $sourceHash
                archiveEntries = @($matches | ForEach-Object {
                        [ordered]@{
                            relativePath = [string]$_.fullName
                            length = [long]$_.length
                            sha256 = [string]$_.sha256
                        }
                    })
                exact = $exact
            }) | Out-Null
    }
    $archiveResourceEntries = @($baseEvidence.entries | Where-Object {
            -not [bool]$_.isMalodyChart
        })
    $unclaimedResourceEntries = @($archiveResourceEntries | Where-Object {
            -not $claimedResourceEntryNames.Contains([string]$_.fullName)
        } | Select-Object -ExpandProperty fullName)
    $entryNameGroups = @($baseEvidence.entries |
        Group-Object { ([string]$_.fullName).ToUpperInvariant() })
    $allEntriesFlat = @($baseEvidence.entries | Where-Object {
            [string]$_.fullName -cne [IO.Path]::GetFileName([string]$_.fullName)
        }).Count -eq 0
    $unexpectedChartArtifacts = @($baseEvidence.entries | Where-Object {
            $extension = [IO.Path]::GetExtension([string]$_.fullName)
            $extension -in '.osu', '.mcz', '.osz', '.mc_', '.luma-part'
        } | Select-Object -ExpandProperty fullName)
    $audioReference = [string]$mainChart.meta.song.file
    $backgroundReference = [string]$mainChart.meta.background
    $referencedResourceNames = @(
        $audioReference,
        $backgroundReference,
        @($mainChart.note | ForEach-Object { [string]$_.sound } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
        Sort-Object -Unique
    $resolvedResourceReferences = @($referencedResourceNames | ForEach-Object {
            $reference = [string]$_
            $matches = @($baseEvidence.entries | Where-Object {
                    ([string]$_.fullName).Equals($reference, [StringComparison]::Ordinal)
                })
            [pscustomobject][ordered]@{
                reference = $reference
                archiveMatchCount = $matches.Count
                resolved = $matches.Count -eq 1
                sha256 = if ($matches.Count -eq 1) { [string]$matches[0].sha256 } else { $null }
            }
        })
    $archiveKeySoundNodes = @(
        for ($noteIndex = 0; $noteIndex -lt @($mainChart.note).Count; $noteIndex++) {
            $note = $mainChart.note[$noteIndex]
            $sound = [string]$note.sound
            if (-not [string]::IsNullOrWhiteSpace($sound)) {
                [pscustomobject][ordered]@{
                    index = $noteIndex
                    beat = @($note.beat)
                    type = if ($null -eq $note.type) { $null } else { [int]$note.type }
                    offset = if ($null -eq $note.offset) { $null } else { [int]$note.offset }
                    hasColumnProperty =
                        @($note.PSObject.Properties.Name) -contains 'column'
                    column = if ($null -eq $note.column) { $null } else { [int]$note.column }
                    sound = $sound
                }
            }
        })
    $archiveKeySoundValue = if ($archiveKeySoundNodes.Count -eq 1) {
        [string]$archiveKeySoundNodes[0].sound
    } else { '' }
    $archiveKeySoundNodeVerified = $archiveKeySoundNodes.Count -eq 1 -and
        [int]$archiveKeySoundNodes[0].index -eq 2468 -and
        @($archiveKeySoundNodes[0].beat).Count -eq 3 -and
        [int]$archiveKeySoundNodes[0].beat[0] -eq 0 -and
        [int]$archiveKeySoundNodes[0].beat[1] -eq 0 -and
        [int]$archiveKeySoundNodes[0].beat[2] -eq 1 -and
        [int]$archiveKeySoundNodes[0].type -eq 1 -and
        [int]$archiveKeySoundNodes[0].offset -eq -1000 -and
        -not [bool]$archiveKeySoundNodes[0].hasColumnProperty -and
        $archiveKeySoundValue.Equals(
            $audioReference,
            [StringComparison]::Ordinal)

    $result = [ordered]@{}
    foreach ($property in $baseEvidence.PSObject.Properties) {
        $result[$property.Name] = $property.Value
    }
    $result['mainChartFileName'] = $mainChartFileName
    $result['mainChartDynamicNameVerified'] = $true
    $result['playableNoteCount'] = $playableNotes.Count
    $result['longNoteCount'] = @($playableNotes | Where-Object { $null -ne $_.endbeat }).Count
    $result['serializedTimingCount'] = @($mainChart.time).Count
    $result['serializedEffectCount'] = @($mainChart.effect).Count
    $result['serializedTimingAndEffectCount'] =
        [int]$result['serializedTimingCount'] + [int]$result['serializedEffectCount']
    $result['keyCount'] = [int]$mainChart.meta.mode_ext.column
    $result['exactTargetTapCount'] = $exactTargetNotes.Count
    $result['originalTargetTapCount'] = $originalTargetNotes.Count
    $result['sourceArtifactExclusions'] = $sourceArtifactEvidence
    $result['allSourceArtifactsExcluded'] = @($sourceArtifactEvidence | Where-Object {
            -not [bool]$_.excluded
        }).Count -eq 0
    $result['resourceChains'] = @($resourceChains)
    $result['resourceChainsVerified'] = $sourceResourceFiles.Count -ge 3 -and
        @($resourceChains | Where-Object { -not [bool]$_.exact }).Count -eq 0 -and
        $unclaimedResourceEntries.Count -eq 0
    $result['unclaimedResourceEntries'] = $unclaimedResourceEntries
    $result['referencedResources'] = $resolvedResourceReferences
    $result['allReferencedResourcesResolved'] = $resolvedResourceReferences.Count -ge 2 -and
        @($resolvedResourceReferences | Where-Object { -not [bool]$_.resolved }).Count -eq 0
    $result['keySoundNodes'] = $archiveKeySoundNodes
    $result['keySoundNodeVerified'] = $archiveKeySoundNodeVerified
    $result['audioReference'] = $audioReference
    $result['backgroundReference'] = $backgroundReference
    $result['allEntriesFlat'] = $allEntriesFlat
    $result['caseInsensitiveDuplicateCount'] = @($entryNameGroups | Where-Object { $_.Count -gt 1 }).Count
    $result['unexpectedChartArtifacts'] = $unexpectedChartArtifacts
    $result['unexpectedChartArtifactCount'] = $unexpectedChartArtifacts.Count
    return $result
}

function Get-OsuFullPackageArchiveEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$MainChartFileName,
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][int]$ExpectedChartCount,
        [Parameter(Mandatory = $true)][double]$ExpectedOverallDifficulty,
        [Parameter(Mandatory = $true)][double]$ExpectedHpDrainRate,
        [Parameter(Mandatory = $true)][int]$ExpectedHitObjectTime,
        [Parameter(Mandatory = $true)][int]$OriginalLane,
        [Parameter(Mandatory = $true)][int]$ExpectedLane,
        [bool]$ExpectSourceOsuSiblings = $true
    )

    Add-Type -AssemblyName System.IO.Compression
    $fullPath = [IO.Path]::GetFullPath($Path)
    $sourceRootFullPath = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $sourceRootFullPath -PathType Container)) {
        throw "osu! package or source root is missing."
    }

    $entries = [Collections.Generic.List[object]]::new()
    $archive = [IO.Compression.ZipFile]::OpenRead($fullPath)
    try {
        foreach ($entry in $archive.Entries | Sort-Object FullName) {
            if ([string]::IsNullOrWhiteSpace($entry.Name)) { continue }
            $memory = [IO.MemoryStream]::new()
            try {
                $stream = $entry.Open()
                try { $stream.CopyTo($memory) } finally { $stream.Dispose() }
                $bytes = $memory.ToArray()
            }
            finally { $memory.Dispose() }
            $normalizedName = $entry.FullName.Replace('\', '/')
            $isOsu = [IO.Path]::GetExtension($normalizedName).Equals(
                ".osu",
                [StringComparison]::OrdinalIgnoreCase)
            $isMalodyChart = [IO.Path]::GetExtension($normalizedName).Equals(
                ".mc",
                [StringComparison]::OrdinalIgnoreCase)
            $text = if ($isOsu) { [Text.Encoding]::UTF8.GetString($bytes) } else { $null }
            $entries.Add([pscustomobject][ordered]@{
                    fullName = $normalizedName
                    name = $entry.Name
                    length = [long]$bytes.Length
                    sha256 = [Convert]::ToHexString(
                        [Security.Cryptography.SHA256]::HashData($bytes))
                    isOsu = $isOsu
                    isMalodyChart = $isMalodyChart
                    text = $text
                    isFlat = $normalizedName -ceq $entry.Name
                    unsafe = [IO.Path]::IsPathRooted($normalizedName) -or
                        @($normalizedName -split '/' | Where-Object { $_ -eq '..' }).Count -gt 0
                }) | Out-Null
        }
    }
    finally { $archive.Dispose() }

    $mainEntries = @($entries | Where-Object {
            [string]$_.fullName -ieq $MainChartFileName
        })
    if ($mainEntries.Count -ne 1) {
        throw "OSZ did not contain exactly one main osu entry named '$MainChartFileName'."
    }
    $mainEntry = $mainEntries[0]
    $mainText = [string]$mainEntry.text
    $expectedOdText = $ExpectedOverallDifficulty.ToString(
        "0.################",
        [Globalization.CultureInfo]::InvariantCulture)
    $expectedHpText = $ExpectedHpDrainRate.ToString(
        "0.################",
        [Globalization.CultureInfo]::InvariantCulture)
    $originalX = $OriginalLane * 128 + 64
    $expectedX = $ExpectedLane * 128 + 64
    $mainLines = @($mainText -split "`r?`n")
    $expectedHitObjectMatchCount = @($mainLines | Where-Object {
            $_ -match "^$expectedX,192,$ExpectedHitObjectTime,(1|128),"
        }).Count
    $originalHitObjectMatchCount = @($mainLines | Where-Object {
            $_ -match "^$originalX,192,$ExpectedHitObjectTime,(1|128),"
        }).Count
    $mainFormatVerified =
        $mainText.Contains("osu file format v14", [StringComparison]::Ordinal) -and
        $mainText.Contains("Mode: 3", [StringComparison]::Ordinal) -and
        $mainText.Contains("OverallDifficulty:$expectedOdText", [StringComparison]::Ordinal) -and
        $mainText.Contains("HPDrainRate:$expectedHpText", [StringComparison]::Ordinal) -and
        $expectedHitObjectMatchCount -eq 1 -and
        $originalHitObjectMatchCount -eq 0

    $sourceSiblingFiles = if ($ExpectSourceOsuSiblings) {
        @(Get-ChildItem -LiteralPath $sourceRootFullPath -File |
            Where-Object {
                $_.Extension.Equals('.osu', [StringComparison]::OrdinalIgnoreCase) -and
                -not $_.Name.Equals($MainChartFileName, [StringComparison]::OrdinalIgnoreCase)
            })
    } else { @() }
    $siblingEvidence = [Collections.Generic.List[object]]::new()
    foreach ($sourceSibling in $sourceSiblingFiles) {
        $archiveMatches = @($entries | Where-Object {
                [string]$_.fullName -ieq $sourceSibling.Name
            })
        $sourceSha256 = (Get-FileHash -LiteralPath $sourceSibling.FullName -Algorithm SHA256).Hash
        $exact = $archiveMatches.Count -eq 1 -and
            [string]$archiveMatches[0].sha256 -eq $sourceSha256 -and
            [long]$archiveMatches[0].length -eq [long]$sourceSibling.Length
        $siblingEvidence.Add([pscustomobject][ordered]@{
                name = $sourceSibling.Name
                sourcePath = $sourceSibling.FullName
                sourceLength = [long]$sourceSibling.Length
                sourceSha256 = $sourceSha256
                archiveMatchCount = $archiveMatches.Count
                archiveLength = if ($archiveMatches.Count -eq 1) {
                    [long]$archiveMatches[0].length
                } else { $null }
                archiveSha256 = if ($archiveMatches.Count -eq 1) {
                    [string]$archiveMatches[0].sha256
                } else { $null }
                exact = $exact
            }) | Out-Null
    }
    $caseInsensitiveNames = @($entries | Group-Object { ([string]$_.fullName).ToUpperInvariant() })
    $collisionEntryCount = @($entries | Where-Object {
            [IO.Path]::GetFileNameWithoutExtension([string]$_.fullName) -match '_2$'
        }).Count
    $excludedSourceArtifactFiles = if ($ExpectSourceOsuSiblings) {
        @()
    } else {
        @(Get-ChildItem -LiteralPath $sourceRootFullPath -File | Where-Object {
                $_.Extension -in '.mc', '.osu', '.mcz', '.osz', '.luma-part'
            })
    }
    $excludedSourceArtifacts = @($excludedSourceArtifactFiles | ForEach-Object {
            $sourceArtifact = $_
            $archiveMatchCount = @($entries | Where-Object {
                    ([string]$_.fullName).Equals(
                        $sourceArtifact.Name,
                        [StringComparison]::OrdinalIgnoreCase)
                }).Count
            [pscustomobject][ordered]@{
                name = $sourceArtifact.Name
                sourcePath = $sourceArtifact.FullName
                sourceLength = [long]$sourceArtifact.Length
                sourceSha256 = (Get-FileHash -LiteralPath $sourceArtifact.FullName -Algorithm SHA256).Hash
                archiveMatchCount = $archiveMatchCount
                excluded = $archiveMatchCount -eq 0
            }
        } | Sort-Object name)
    return [ordered]@{
        path = $fullPath
        length = [long](Get-Item -LiteralPath $fullPath).Length
        sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
        entryCount = $entries.Count
        chartEntryCount = @($entries | Where-Object { [bool]$_.isOsu }).Count
        malodyChartEntryCount = @($entries | Where-Object { [bool]$_.isMalodyChart }).Count
        siblingChartEntryCount = @($entries | Where-Object {
                [bool]$_.isOsu -and
                -not ([string]$_.fullName).Equals(
                    $MainChartFileName,
                    [StringComparison]::OrdinalIgnoreCase)
            }).Count
        expectedChartCount = $ExpectedChartCount
        mainChartEntryCount = $mainEntries.Count
        mainChartEntry = $mainEntry
        mainChartText = $mainText
        mainChartFormatVerified = $mainFormatVerified
        mainChartExpectedHitObjectMatchCount = $expectedHitObjectMatchCount
        mainChartOriginalHitObjectMatchCount = $originalHitObjectMatchCount
        siblingCharts = @($siblingEvidence)
        sourceSiblingPreservationExpected = $ExpectSourceOsuSiblings
        siblingChartsExact = if ($ExpectSourceOsuSiblings) {
            $sourceSiblingFiles.Count -eq ($ExpectedChartCount - 1) -and
                @($siblingEvidence | Where-Object { -not [bool]$_.exact }).Count -eq 0
        } else {
            $ExpectedChartCount -eq 1 -and
                @($entries | Where-Object {
                        [bool]$_.isOsu -and
                        -not ([string]$_.fullName).Equals(
                            $MainChartFileName,
                            [StringComparison]::OrdinalIgnoreCase)
                    }).Count -eq 0
        }
        allEntriesFlat = @($entries | Where-Object { -not [bool]$_.isFlat }).Count -eq 0
        unsafeEntryCount = @($entries | Where-Object { [bool]$_.unsafe }).Count
        caseInsensitiveDuplicateCount = @($caseInsensitiveNames | Where-Object { $_.Count -gt 1 }).Count
        collisionEntryCount = $collisionEntryCount
        excludedSourceArtifacts = $excludedSourceArtifacts
        allExcludedSourceArtifactsAbsent = @($excludedSourceArtifacts | Where-Object {
                -not [bool]$_.excluded
            }).Count -eq 0
        expectedOverallDifficulty = $expectedOdText
        expectedHpDrainRate = $expectedHpText
        entries = @($entries | ForEach-Object {
                [ordered]@{
                    fullName = $_.fullName
                    length = $_.length
                    sha256 = $_.sha256
                    isOsu = $_.isOsu
                    isMalodyChart = $_.isMalodyChart
                    isFlat = $_.isFlat
                    unsafe = $_.unsafe
                }
            })
    }
}

function Invoke-MalodyFullPackageFreshImportEvidence {
    param(
        [ValidateSet("Malody", "OsuMania")][string]$ArchiveFormat = "Malody",
        [ValidateSet("Malody", "OsuMania")][string]$SourceChartFormat = $ArchiveFormat,
        [Parameter(Mandatory = $true)][string]$ApplicationPath,
        [Parameter(Mandatory = $true)][string]$SeedChartPath,
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$MainChartFileName,
        [Parameter(Mandatory = $true)][int]$ExpectedChartCount,
        [Parameter(Mandatory = $true)][string]$ExpectedWorkingChartPath,
        [Parameter(Mandatory = $true)][string]$ExpectedStructureSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedMainEntrySha256,
        [Parameter(Mandatory = $true)][int]$ExpectedKeyCount,
        [Parameter(Mandatory = $true)][int]$ExpectedNoteCount,
        [Parameter(Mandatory = $true)][int]$ExpectedLongNoteCount,
        [Parameter(Mandatory = $true)][int]$ExpectedTimingCount,
        [Parameter(Mandatory = $true)]$ExpectedBeat,
        [Parameter(Mandatory = $true)]$OriginalBeat,
        [Parameter(Mandatory = $true)][int]$ExpectedLane,
        [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$LocalDataRoot,
        [Parameter(Mandatory = $true)][string]$EditingRoot,
        [Parameter(Mandatory = $true)][string]$EvidencePath,
        [Parameter(Mandatory = $true)][string]$InteractionEvidencePath,
        [Parameter(Mandatory = $true)][string]$ImportDialogScreenshotPath,
        [string]$FirstCalibrationScreenshotPath,
        [string]$SecondCalibrationScreenshotPath,
        [ValidateRange(0, 10)][double]$ExpectedOverallDifficulty = 8,
        [ValidateRange(0, 10)][double]$ExpectedHpDrainRate = 8,
        [int]$ExpectedHitObjectTime = 0,
        [int]$OriginalLane = 0,
        [int]$ExpectedExportedLane = 0,
        [bool]$ExpectSourceOsuSiblings = $true,
        [Parameter(Mandatory = $true)][string]$FinalScreenshotPath
    )

    $isOsuFreshImport = $ArchiveFormat -eq "OsuMania"
    $sourceIsMalody = $SourceChartFormat -eq "Malody"
    $isCrossFormat = $SourceChartFormat -ne $ArchiveFormat

    $sourceRootFullPath = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\')
    $sourceBoundary = $sourceRootFullPath + '\'
    $seedChartFullPath = [IO.Path]::GetFullPath($SeedChartPath)
    if (-not (Test-Path -LiteralPath $sourceRootFullPath -PathType Container) -or
        -not $seedChartFullPath.StartsWith(
            $sourceBoundary,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "Fresh archive manifest source root is missing or does not contain the seed chart."
    }

    foreach ($path in @($WorkspaceRoot, $LocalDataRoot, $EditingRoot)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    if ($isOsuFreshImport -and
        ($ExpectedChartCount -notin 1, 2 -or
         [string]::IsNullOrWhiteSpace($FirstCalibrationScreenshotPath) -or
         ($ExpectedChartCount -eq 2 -and
          [string]::IsNullOrWhiteSpace($SecondCalibrationScreenshotPath)))) {
        throw "Fresh OSZ import requires one or two calibration screenshot paths matching its expected chart count."
    }
    foreach ($path in @(
            $EvidencePath,
            $InteractionEvidencePath,
            $ImportDialogScreenshotPath,
            $(if ($isOsuFreshImport) { $FirstCalibrationScreenshotPath } else { $null }),
            $(if ($isOsuFreshImport -and $ExpectedChartCount -eq 2) {
                    $SecondCalibrationScreenshotPath
                } else { $null }),
            $FinalScreenshotPath)) {
        if ([string]::IsNullOrWhiteSpace([string]$path)) {
            continue
        }
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($path)) -Force |
            Out-Null
        if (Test-Path -LiteralPath $path) {
            throw "Fresh archive import output already exists: $path"
        }
    }

    $expectedWorkingChartFullPath = [IO.Path]::GetFullPath($ExpectedWorkingChartPath)
    if (-not (Test-Path -LiteralPath $expectedWorkingChartFullPath -PathType Leaf)) {
        throw "Pre-export working baseline does not exist: $expectedWorkingChartFullPath"
    }
    $expectedWorkingChartSha256 =
        (Get-FileHash -LiteralPath $expectedWorkingChartFullPath -Algorithm SHA256).Hash
    if ($sourceIsMalody) {
    $expectedDirtyChart = Get-Content -LiteralPath $expectedWorkingChartFullPath -Raw |
        ConvertFrom-Json
    $cleanWorkingSemanticMap = ConvertTo-JsonSemanticMap -Value $expectedDirtyChart
    $originalBeatCandidates = [Collections.Generic.List[object]]::new()
    $submittedBeatCandidates = [Collections.Generic.List[object]]::new()
    for ($noteIndex = 0; $noteIndex -lt @($expectedDirtyChart.note).Count; $noteIndex++) {
        $candidateNote = $expectedDirtyChart.note[$noteIndex]
        if ($null -eq $candidateNote.column -or $null -eq $candidateNote.beat -or
            @($candidateNote.beat).Count -lt 3 -or
            [int]$candidateNote.column -ne $OriginalLane) {
            continue
        }
        $candidateEvidence = [ordered]@{
            index = $noteIndex
            note = $candidateNote
        }
        if ([int]$candidateNote.beat[0] -eq [int]$OriginalBeat.bar -and
            [int]$candidateNote.beat[1] -eq [int]$OriginalBeat.numerator -and
            [int]$candidateNote.beat[2] -eq [int]$OriginalBeat.denominator) {
            $originalBeatCandidates.Add($candidateEvidence) | Out-Null
        }
        if ([int]$candidateNote.beat[0] -eq [int]$ExpectedBeat.bar -and
            [int]$candidateNote.beat[1] -eq [int]$ExpectedBeat.numerator -and
            [int]$candidateNote.beat[2] -eq [int]$ExpectedBeat.denominator) {
            $submittedBeatCandidates.Add($candidateEvidence) | Out-Null
        }
    }
    if ($originalBeatCandidates.Count -ne 1 -or
        $submittedBeatCandidates.Count -ne 0) {
        throw "Pre-export working MC baseline did not expose exactly one original target Beat and zero already-submitted target Beats."
    }
    $expectedDirtyTarget = $originalBeatCandidates[0]
    $expectedDirtyBeatBefore = @(
        [int]$expectedDirtyTarget.note.beat[0],
        [int]$expectedDirtyTarget.note.beat[1],
        [int]$expectedDirtyTarget.note.beat[2])
    $expectedDirtyTarget.note.beat = @(
        [int]$ExpectedBeat.bar,
        [int]$ExpectedBeat.numerator,
        [int]$ExpectedBeat.denominator)
    if ($isCrossFormat) {
        $expectedDirtyTarget.note.column = $ExpectedLane
    }
    $expectedDirtyBeatPath = "/note/$($expectedDirtyTarget.index)/beat"
    $dirtyWorkingSemanticMap = ConvertTo-JsonSemanticMap -Value $expectedDirtyChart
    $dirtyProjectionDifferences = @(
        Compare-JsonSemanticMaps `
            -Expected $cleanWorkingSemanticMap `
            -Actual $dirtyWorkingSemanticMap)
    $expectedDirtyProjectionDifferences = @(
        [pscustomobject][ordered]@{
            path = "$expectedDirtyBeatPath/1"
            kind = "changed"
            expected = "number:$([int]$OriginalBeat.numerator)"
            actual = "number:$([int]$ExpectedBeat.numerator)"
        },
        [pscustomobject][ordered]@{
            path = "$expectedDirtyBeatPath/2"
            kind = "changed"
            expected = "number:$([int]$OriginalBeat.denominator)"
            actual = "number:$([int]$ExpectedBeat.denominator)"
        })
    if ($isCrossFormat) {
        $expectedDirtyProjectionDifferences += [pscustomobject][ordered]@{
            path = "/note/$($expectedDirtyTarget.index)/column"
            kind = "changed"
            expected = "number:$OriginalLane"
            actual = "number:$ExpectedLane"
        }
    }
    $expectedDirtyRawDifferenceCount = if ($isCrossFormat) { 3 } else { 2 }
    if ($expectedDirtyBeatPath -cne "/note/804/beat" -or
        $dirtyProjectionDifferences.Count -ne $expectedDirtyRawDifferenceCount -or
        (($dirtyProjectionDifferences | ConvertTo-Json -Depth 4 -Compress) -cne
         ($expectedDirtyProjectionDifferences | ConvertTo-Json -Depth 4 -Compress))) {
        throw "Pre-export working MC dirty projection was not exactly its expected rational Beat and optional cross-format lane components."
    }

    $sourceChartDirectory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($SeedChartPath))
    $sourceChartBoundary = $sourceChartDirectory.TrimEnd('\') + '\'
    $baselineBackgroundReference = [string]$expectedDirtyChart.meta.background
    $baselineSongReference = [string]$expectedDirtyChart.meta.song.file
    if ([string]::IsNullOrWhiteSpace($baselineBackgroundReference) -or
        [string]::IsNullOrWhiteSpace($baselineSongReference) -or
        -not [IO.Path]::GetFileName($baselineBackgroundReference).Equals(
            $baselineBackgroundReference,
            [StringComparison]::Ordinal) -or
        -not [IO.Path]::GetFileName($baselineSongReference).Equals(
            $baselineSongReference,
            [StringComparison]::Ordinal)) {
        throw "Pre-export working MC did not expose filename-only background and song resource references."
    }
    $baselineKeySoundIndices = @(
        for ($noteIndex = 0; $noteIndex -lt @($expectedDirtyChart.note).Count; $noteIndex++) {
            $sound = [string]$expectedDirtyChart.note[$noteIndex].sound
            if (-not [string]::IsNullOrWhiteSpace($sound) -and
                $sound.Equals($baselineSongReference, [StringComparison]::Ordinal)) {
                $noteIndex
            }
        })
    if ($baselineKeySoundIndices.Count -ne 1) {
        throw "Pre-export working MC did not expose exactly one Key-sound reference to its song resource."
    }
    $baselineKeySoundIndex = [int]$baselineKeySoundIndices[0]
    $expectedPackagedBackgroundReference =
        [IO.Path]::GetFileNameWithoutExtension($baselineBackgroundReference) + '_2' +
        [IO.Path]::GetExtension($baselineBackgroundReference)
    $expectedPackagedSongReference =
        [IO.Path]::GetFileNameWithoutExtension($baselineSongReference) + '_2' +
        [IO.Path]::GetExtension($baselineSongReference)
    $sourceBackgroundPath = [IO.Path]::GetFullPath(
        (Join-Path $sourceChartDirectory $baselineBackgroundReference))
    $sourceSongPath = [IO.Path]::GetFullPath(
        (Join-Path $sourceChartDirectory $baselineSongReference))
    foreach ($sourceResourcePath in @($sourceBackgroundPath, $sourceSongPath)) {
        if (-not $sourceResourcePath.StartsWith(
                $sourceChartBoundary,
                [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $sourceResourcePath -PathType Leaf)) {
            throw "Pre-export source resource was missing or escaped its source directory: $sourceResourcePath"
        }
    }
    }
    if ($isOsuFreshImport) {
        $osuArchiveEvidencePreflight = Get-OsuFullPackageArchiveEvidence `
            -Path $ArchivePath `
            -MainChartFileName $MainChartFileName `
            -SourceRoot $sourceRootFullPath `
            -ExpectedChartCount $ExpectedChartCount `
            -ExpectedOverallDifficulty $ExpectedOverallDifficulty `
            -ExpectedHpDrainRate $ExpectedHpDrainRate `
            -ExpectedHitObjectTime $ExpectedHitObjectTime `
            -OriginalLane $OriginalLane `
            -ExpectedLane $ExpectedExportedLane `
            -ExpectSourceOsuSiblings $ExpectSourceOsuSiblings
        $expectedOsuChartFileNames = @($osuArchiveEvidencePreflight.entries |
            Where-Object { [bool]$_.isOsu } |
            ForEach-Object { [IO.Path]::GetFileName([string]$_.fullName) } |
            Sort-Object)
        if ($expectedOsuChartFileNames.Count -ne $ExpectedChartCount -or
            -not [bool]$osuArchiveEvidencePreflight.mainChartFormatVerified -or
            -not [bool]$osuArchiveEvidencePreflight.siblingChartsExact -or
            -not [bool]$osuArchiveEvidencePreflight.allExcludedSourceArtifactsAbsent -or
            -not [bool]$osuArchiveEvidencePreflight.allEntriesFlat -or
            [int]$osuArchiveEvidencePreflight.unsafeEntryCount -ne 0 -or
            [int]$osuArchiveEvidencePreflight.caseInsensitiveDuplicateCount -ne 0) {
            throw "Preflight OSZ did not prove the expected flat safe osu chart set, requested difficulty, dirty HitObject, and required sibling policy."
        }
    }

    $start = [Diagnostics.ProcessStartInfo]::new($ApplicationPath)
    $start.UseShellExecute = $false
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $LocalDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $EditingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $WorkspaceRoot
    foreach ($argument in @(
            "--evidence-chart", $SeedChartPath,
            "--evidence-output", $EvidencePath,
            "--evidence-interaction-output", $InteractionEvidencePath,
            "--evidence-interaction-delay-ms", $(if ($isOsuFreshImport) { "45000" } else { "30000" }),
            "--evidence-follow-active-tab",
            "--evidence-file-picker-start-directory",
            [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($ArchivePath)))) {
        $start.ArgumentList.Add($argument)
    }

    $freshProcess = [Diagnostics.Process]::Start($start)
    $freshScratchRoot = Join-Path $EditingRoot ("_scratch\session_{0}" -f $freshProcess.Id)
    $normalExit = $false
    try {
        $primaryDeadline = [DateTime]::UtcNow.AddSeconds(60)
        do {
            Start-Sleep -Milliseconds 150
            $freshProcess.Refresh()
        } while (-not $freshProcess.HasExited -and
                 ($freshProcess.MainWindowHandle -eq [IntPtr]::Zero -or
                  -not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) -and
                 [DateTime]::UtcNow -lt $primaryDeadline)
        if ($freshProcess.HasExited) {
            throw "Fresh Avalonia import process exited before primary evidence."
        }
        if ($freshProcess.MainWindowHandle -eq [IntPtr]::Zero -or
            -not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
            throw "Fresh Avalonia import process did not expose its main window and primary evidence."
        }
        $primary = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
        $expectedPickerStartDirectory = [IO.Path]::GetDirectoryName(
            [IO.Path]::GetFullPath($ArchivePath))
        if ([bool]$primary.evidenceInteractionFollowsActiveTab -ne $true -or
            -not [bool]$primary.evidenceFilePickerStartDirectoryInjected -or
            -not [IO.Path]::GetFullPath(
                [string]$primary.evidenceFilePickerStartDirectory).Equals(
                    $expectedPickerStartDirectory,
                    [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fresh Avalonia primary evidence did not enable active-tab follow mode and the exact evidence file-picker start directory."
        }

        Set-ForegroundWindowVerified -WindowHandle $freshProcess.MainWindowHandle
        $openButton = Find-AutomationElementByName `
            -TargetProcessId $freshProcess.Id `
            -Name "打开谱面" `
            -RootWindowHandle $freshProcess.MainWindowHandle `
            -TimeoutMilliseconds 6000
        Click-AutomationElementWithMouse -Element $openButton
        $openDialog = Find-AutomationElementByName `
            -TargetProcessId $freshProcess.Id `
            -Name "打开 Malody / osu! 谱面或谱包" `
            -TimeoutMilliseconds 7000
        $openDialogHandle = [IntPtr]$openDialog.Current.NativeWindowHandle
        $openDialogTitle = [string]$openDialog.Current.Name
        $openDialogTitle = [string]$openDialog.Current.Name
        if ($openDialogHandle -eq [IntPtr]::Zero) {
            throw "Fresh MCZ native Open picker did not expose a window handle."
        }
        $requestedOpenPath = [IO.Path]::GetFullPath($ArchivePath)
        $requestedOpenDirectory = [IO.Path]::GetDirectoryName($requestedOpenPath)
        $requestedOpenFileName = [IO.Path]::GetFileName($requestedOpenPath)
        $openDirectoryNavigation = Get-NativeFilePickerAddressEvidence `
            -DialogElement $openDialog `
            -ExpectedDirectory $requestedOpenDirectory
        $allOpenControls = $openDialog.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            [System.Windows.Automation.Condition]::TrueCondition)
        $legacyFilenameCandidates = [Collections.Generic.List[object]]::new()
        for ($controlIndex = 0; $controlIndex -lt $allOpenControls.Count; $controlIndex++) {
            $candidate = $allOpenControls.Item($controlIndex)
            $candidateBounds = $candidate.Current.BoundingRectangle
            $candidateHandle = [IntPtr]$candidate.Current.NativeWindowHandle
            if ([string]$candidate.Current.AutomationId -eq "1148" -and
                [string]$candidate.Current.ClassName -eq "Edit" -and
                [string]$candidate.Current.ControlType.ProgrammaticName -eq
                    "ControlType.Pane" -and
                $candidateHandle -ne [IntPtr]::Zero -and
                [LumaChartAvaloniaCaptureNative]::IsWindow($candidateHandle) -and
                [bool]$candidate.Current.IsEnabled -and
                -not [bool]$candidate.Current.IsOffscreen -and
                -not $candidateBounds.IsEmpty -and
                $candidateBounds.Width -gt 1 -and
                $candidateBounds.Height -gt 1) {
                $legacyFilenameCandidates.Add($candidate)
            }
        }
        if ($legacyFilenameCandidates.Count -ne 1) {
            throw "Fresh MCZ legacy Open picker did not expose exactly one enabled, visible native 1148/Edit filename control; found $($legacyFilenameCandidates.Count)."
        }
        $openName = $legacyFilenameCandidates[0]
        $openFilenameProvider = "Legacy GetOpenFileName 1148/Edit"
        $openNameBounds = $openName.Current.BoundingRectangle
        $openNameHandle = [IntPtr]$openName.Current.NativeWindowHandle
        $openNameAutomationId = [string]$openName.Current.AutomationId
        $openNameClassName = [string]$openName.Current.ClassName
        $openNameControlType = [string]$openName.Current.ControlType.ProgrammaticName
        $openNameIsEnabled = [bool]$openName.Current.IsEnabled
        $openNameIsOffscreen = [bool]$openName.Current.IsOffscreen
        if (-not $openFilenameProvider.Equals(
                "Legacy GetOpenFileName 1148/Edit",
                [StringComparison]::Ordinal)) {
            throw "Fresh MCZ GUI evidence requires the observed legacy 1148/Edit Open provider for exact WM_GETTEXT validation."
        }
        if ($openNameHandle -eq [IntPtr]::Zero -or
            -not [LumaChartAvaloniaCaptureNative]::IsWindow($openNameHandle)) {
            throw "Fresh MCZ legacy Open filename control did not expose a usable native HWND."
        }
        $fileListDeadline = [DateTime]::UtcNow.AddSeconds(5)
        $exactFileListMatches = [Collections.Generic.List[object]]::new()
        do {
            $exactFileListMatches.Clear()
            $currentOpenControls = $openDialog.FindAll(
                [System.Windows.Automation.TreeScope]::Descendants,
                [System.Windows.Automation.Condition]::TrueCondition)
            for ($controlIndex = 0; $controlIndex -lt $currentOpenControls.Count; $controlIndex++) {
                $candidate = $currentOpenControls.Item($controlIndex)
                $candidateBounds = $candidate.Current.BoundingRectangle
                if ([string]$candidate.Current.Name -ceq $requestedOpenFileName -and
                    [string]$candidate.Current.ClassName -eq "UIItem" -and
                    $candidate.Current.ControlType -eq
                        [System.Windows.Automation.ControlType]::ListItem -and
                    [bool]$candidate.Current.IsEnabled -and
                    -not [bool]$candidate.Current.IsOffscreen -and
                    -not $candidateBounds.IsEmpty -and
                    $candidateBounds.Width -gt 1 -and
                    $candidateBounds.Height -gt 1) {
                    $exactFileListMatches.Add($candidate)
                }
            }
            if ($exactFileListMatches.Count -eq 1) { break }
            Start-Sleep -Milliseconds 100
        }
        while ([DateTime]::UtcNow -lt $fileListDeadline)
        if ($exactFileListMatches.Count -ne 1) {
            throw "Fresh MCZ native Open picker did not expose exactly one enabled, visible exact out.mcz UIItem/ListItem; found $($exactFileListMatches.Count)."
        }
        $openFileListItem = $exactFileListMatches[0]
        $openFileListItemBounds = $openFileListItem.Current.BoundingRectangle
        $openFileListSelectionPatternObject = $null
        if (-not $openFileListItem.TryGetCurrentPattern(
                [System.Windows.Automation.SelectionItemPattern]::Pattern,
                [ref]$openFileListSelectionPatternObject)) {
            throw "Fresh MCZ exact out.mcz UIItem/ListItem did not expose SelectionItemPattern."
        }
        $openFileListSelectionPattern =
            [System.Windows.Automation.SelectionItemPattern]$openFileListSelectionPatternObject
        $openFileListSelectedBeforeClick =
            [bool]$openFileListSelectionPattern.Current.IsSelected
        Set-ForegroundWindowVerified -WindowHandle $openDialogHandle
        Click-AutomationElementWithMouse -Element $openFileListItem
        Start-Sleep -Milliseconds 220
        $openFileListSelectedAfterClick =
            [bool]$openFileListSelectionPattern.Current.IsSelected
        if (-not $openFileListSelectedAfterClick) {
            throw "Fresh MCZ exact out.mcz UIItem/ListItem was not selected after its physical click."
        }
        $openDialogOpenAfterFileListSelection =
            [LumaChartAvaloniaCaptureNative]::IsWindow($openDialogHandle)
        if (-not $openDialogOpenAfterFileListSelection) {
            throw "Fresh MCZ native Open picker closed during exact file ListItem physical selection."
        }
        $openFileListSelectionEvidence = [ordered]@{
            automationId = [string]$openFileListItem.Current.AutomationId
            name = [string]$openFileListItem.Current.Name
            className = [string]$openFileListItem.Current.ClassName
            controlType = [string]$openFileListItem.Current.ControlType.ProgrammaticName
            nativeWindowHandle = [long]$openFileListItem.Current.NativeWindowHandle
            bounds = [ordered]@{
                left = [double]$openFileListItemBounds.Left
                top = [double]$openFileListItemBounds.Top
                width = [double]$openFileListItemBounds.Width
                height = [double]$openFileListItemBounds.Height
            }
            selectionItemPatternAvailable = $true
            physicalClickAttempted = $true
            isSelectedBeforeClick = $openFileListSelectedBeforeClick
            isSelectedAfterClick = $openFileListSelectedAfterClick
        }
        $nativeTextLength = [LumaChartAvaloniaCaptureNative]::GetWindowTextLength(
            $openNameHandle)
        $nativeText = [Text.StringBuilder]::new($nativeTextLength + 1)
        [void][LumaChartAvaloniaCaptureNative]::GetWindowText(
            $openNameHandle,
            $nativeText,
            $nativeText.Capacity)
        $openFilenameEditValue = $nativeText.ToString()
        $openFilenameEditValueAvailable = $openFilenameEditValue.Length -gt 0
        $openFilenameEditMirrorsSelection =
            $openFilenameEditValueAvailable -and
            $openFilenameEditValue.Equals(
                $requestedOpenFileName,
                [StringComparison]::OrdinalIgnoreCase)
        if ($openFilenameEditValueAvailable -and
            -not $openFilenameEditMirrorsSelection) {
            throw "Fresh MCZ legacy 1148/Edit exposed a non-empty filename that disagreed with the exact selected native file ListItem: '$openFilenameEditValue'."
        }
        $openInputMode = "exact native output-directory out.mcz UIItem/ListItem physical click + SelectionItemPattern IsSelected + exact address/selected-item path; legacy 1148/Edit mirror recorded and validated only when non-empty; no keyboard/IME/clipboard/value injection"
        $openUiaName = [string]$openName.Current.Name
        if (-not [string]::IsNullOrWhiteSpace($openUiaName) -and
            -not $openUiaName.Equals(
                $requestedOpenFileName,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fresh MCZ legacy Open UIA Name disagreed with the exact native filename readback: '$openUiaName'."
        }
        Start-Sleep -Milliseconds 150
        [string]$openFilenameText = [string]$openFileListItem.Current.Name
        if (-not $openFilenameText.Equals(
                $requestedOpenFileName,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fresh MCZ native Open picker did not retain the exact requested leaf '$requestedOpenFileName': '$openFilenameText'."
        }
        [string]$openReportedDirectoryText = if (
            $null -eq $openDirectoryNavigation.reportedDirectory) {
            ""
        } else { [string]$openDirectoryNavigation.reportedDirectory }
        $openReportedDirectory = [IO.Path]::GetFullPath($openReportedDirectoryText)
        $openFilenameLeaf = $openFilenameText
        $resolvedNativeSelectionPath = [IO.Path]::GetFullPath(
            [IO.Path]::Combine($openReportedDirectory, $openFilenameLeaf))
        if (-not $resolvedNativeSelectionPath.Equals(
                $requestedOpenPath,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fresh MCZ native Open picker resolved '$resolvedNativeSelectionPath' instead of '$requestedOpenPath' from directory '$openReportedDirectory' and exact leaf '$openFilenameLeaf'."
        }
        $openIdCondition = [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
            "1")
        $openCandidates = $openDialog.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            $openIdCondition)
        $nativeOpenMatches = [Collections.Generic.List[object]]::new()
        for ($openIndex = 0; $openIndex -lt $openCandidates.Count; $openIndex++) {
            $candidateOpen = $openCandidates.Item($openIndex)
            $candidateBounds = $candidateOpen.Current.BoundingRectangle
            $candidateHandle = [IntPtr]$candidateOpen.Current.NativeWindowHandle
            if ([string]$candidateOpen.Current.ClassName -eq "Button" -and
                [string]$candidateOpen.Current.ControlType.ProgrammaticName -eq
                    "ControlType.Pane" -and
                [string]$candidateOpen.Current.Name -match '^打开|^Open' -and
                $candidateHandle -ne [IntPtr]::Zero -and
                [LumaChartAvaloniaCaptureNative]::IsWindow($candidateHandle) -and
                [bool]$candidateOpen.Current.IsEnabled -and
                -not [bool]$candidateOpen.Current.IsOffscreen -and
                -not $candidateBounds.IsEmpty -and
                $candidateBounds.Width -gt 1 -and
                $candidateBounds.Height -gt 1) {
                $nativeOpenMatches.Add($candidateOpen)
            }
        }
        if ($nativeOpenMatches.Count -ne 1) {
            throw "Fresh MCZ native Open picker did not expose exactly one enabled, visible native id=1 Open Button; found $($nativeOpenMatches.Count)."
        }
        $nativeOpen = $nativeOpenMatches[0]
        $openButtonBounds = $nativeOpen.Current.BoundingRectangle
        $openSubmitControlEvidence = [ordered]@{
            automationId = [string]$nativeOpen.Current.AutomationId
            name = [string]$nativeOpen.Current.Name
            className = [string]$nativeOpen.Current.ClassName
            controlType = [string]$nativeOpen.Current.ControlType.ProgrammaticName
            isEnabled = [bool]$nativeOpen.Current.IsEnabled
            isOffscreen = [bool]$nativeOpen.Current.IsOffscreen
            nativeWindowHandle = [long]$nativeOpen.Current.NativeWindowHandle
            bounds = [ordered]@{
                left = [double]$openButtonBounds.Left
                top = [double]$openButtonBounds.Top
                width = [double]$openButtonBounds.Width
                height = [double]$openButtonBounds.Height
            }
        }
        Set-ForegroundWindowVerified -WindowHandle $openDialogHandle
        Click-AutomationElementWithMouse -Element $nativeOpen
        $openSubmitPath = "unique native id=1 Open Button physical click"
        $openDialogCloseDeadline = [DateTime]::UtcNow.AddSeconds(4)
        while ([LumaChartAvaloniaCaptureNative]::IsWindow($openDialogHandle) -and
               [DateTime]::UtcNow -lt $openDialogCloseDeadline) {
            Start-Sleep -Milliseconds 80
        }
        if ([LumaChartAvaloniaCaptureNative]::IsWindow($openDialogHandle)) {
            throw "Fresh MCZ native Open picker did not close after the physical Open button click."
        }
        $openDialogClosedAfterSubmit = $true

        $importDialog = Find-AutomationElementByName `
            -TargetProcessId $freshProcess.Id `
            -Name "谱包已导入" `
            -TimeoutMilliseconds 10000
        $importDialogHandle = [IntPtr]$importDialog.Current.NativeWindowHandle
        $importDialogTitle = [string]$importDialog.Current.Name
        if ($importDialogHandle -eq [IntPtr]::Zero) {
            throw "Fresh MCZ import preview did not expose a window handle."
        }
        Set-ForegroundWindowVerified -WindowHandle $importDialogHandle
        $dialogFindAllDeadline = [DateTime]::UtcNow.AddSeconds(5)
        $dialogFindAllAttemptCount = 0
        $dialogFindAllTransientFailures = [Collections.Generic.List[object]]::new()
        $dialogDescendants = $null
        while ($null -eq $dialogDescendants) {
            $dialogFindAllAttemptCount++
            if (-not [LumaChartAvaloniaCaptureNative]::IsWindow($importDialogHandle)) {
                throw "Fresh MCZ import preview window disappeared while its UIA tree was being read."
            }
            try {
                $dialogRoot = [System.Windows.Automation.AutomationElement]::FromHandle(
                    $importDialogHandle)
                $dialogDescendants = $dialogRoot.FindAll(
                    [System.Windows.Automation.TreeScope]::Descendants,
                    [System.Windows.Automation.Condition]::TrueCondition)
            }
            catch {
                $dialogFindAllTransientException = $null
                $dialogFindAllExceptionCandidate = $_.Exception
                $dialogFindAllExceptionDepth = 0
                while ($null -ne $dialogFindAllExceptionCandidate -and
                       $dialogFindAllExceptionDepth -lt 8) {
                    if ($dialogFindAllExceptionCandidate -is
                            [System.Runtime.InteropServices.COMException] -or
                        $dialogFindAllExceptionCandidate -is
                            [System.Windows.Automation.ElementNotAvailableException]) {
                        $dialogFindAllTransientException =
                            $dialogFindAllExceptionCandidate
                        break
                    }
                    $dialogFindAllExceptionCandidate =
                        $dialogFindAllExceptionCandidate.InnerException
                    $dialogFindAllExceptionDepth++
                }
                if ($null -eq $dialogFindAllTransientException) {
                    throw
                }
                $dialogFindAllHResult = '0x' +
                    $dialogFindAllTransientException.HResult.ToString(
                    'X8',
                    [Globalization.CultureInfo]::InvariantCulture)
                $dialogFindAllTransientFailures.Add([ordered]@{
                        attempt = $dialogFindAllAttemptCount
                        exceptionType =
                            $dialogFindAllTransientException.GetType().FullName
                        hResult = $dialogFindAllHResult
                    }) | Out-Null
                if ([DateTime]::UtcNow -ge $dialogFindAllDeadline) {
                    throw "Fresh MCZ import preview UIA FindAll did not succeed within 5000 ms; last HRESULT was $dialogFindAllHResult."
                }
                Start-Sleep -Milliseconds 100
            }
        }
        $dialogNames = @($dialogDescendants | ForEach-Object {
                try {
                    if (-not [string]::IsNullOrWhiteSpace([string]$_.Current.Name)) {
                        [string]$_.Current.Name
                    }
                }
                catch { }
            } | Sort-Object -Unique)
        $expectedOpenText = "打开 $ExpectedChartCount 张"
        $previewCountText = @($dialogNames | Where-Object {
                $_ -like "$ExpectedChartCount 张键音谱可打开*" -and
                $_ -like "*0 张其他模式*" -and
                $_ -like "*0 张损坏*"
            }) | Select-Object -First 1
        if (-not $previewCountText) {
            throw "Fresh MCZ import preview did not report $ExpectedChartCount valid charts and zero failures."
        }
        Save-AutomationElementScreenshot `
            -Element $importDialog `
            -Path $ImportDialogScreenshotPath
        $openImported = Find-AutomationElementByName `
            -TargetProcessId $freshProcess.Id `
            -Name $expectedOpenText `
            -RootWindowHandle $importDialogHandle `
            -TimeoutMilliseconds 6000
        Click-AutomationElementWithMouse -Element $openImported

        $osuImportModes = $null
        if ($isOsuFreshImport) {
            $calibrationScreenshots = [string[]]@(
                $FirstCalibrationScreenshotPath
                if ($ExpectedChartCount -eq 2) { $SecondCalibrationScreenshotPath }
            )
            $calibrationDialogs = [Collections.Generic.List[object]]::new()
            for ($calibrationIndex = 0;
                 $calibrationIndex -lt $ExpectedChartCount;
                 $calibrationIndex++) {
                $expectedOsuChartName = [string]$expectedOsuChartFileNames[$calibrationIndex]
                $calibrationDeadline = [DateTime]::UtcNow.AddSeconds(15)
                $calibrationDialog = $null
                $calibrationDialogHandle = [IntPtr]::Zero
                $chartNameObservation = $null
                do {
                    Start-Sleep -Milliseconds 100
                    try {
                        $candidateDialog = Find-AutomationElementById `
                            -TargetProcessId $freshProcess.Id `
                            -AutomationId "OsuImportMode.Dialog" `
                            -TimeoutMilliseconds 350
                        $candidateHandle = [IntPtr]$candidateDialog.Current.NativeWindowHandle
                        if ($candidateHandle -ne [IntPtr]::Zero -and
                            [LumaChartAvaloniaCaptureNative]::IsWindow($candidateHandle)) {
                            $candidateChartName = Get-AutomationElementObservation `
                                -TargetProcessId $freshProcess.Id `
                                -AutomationId "OsuImportMode.ChartName" `
                                -RootWindowHandle $candidateHandle `
                                -TimeoutMilliseconds 500
                            if ([string]$candidateChartName.Evidence.name -ceq $expectedOsuChartName) {
                                $calibrationDialog = $candidateDialog
                                $calibrationDialogHandle = $candidateHandle
                                $chartNameObservation = $candidateChartName
                            }
                        }
                    }
                    catch {
                        if ([DateTime]::UtcNow -ge $calibrationDeadline) { throw }
                    }
                } while ($null -eq $calibrationDialog -and
                         [DateTime]::UtcNow -lt $calibrationDeadline)
                if ($null -eq $calibrationDialog) {
                    throw "Fresh OSZ import did not expose the ordered calibration dialog for '$expectedOsuChartName'."
                }

                Set-ForegroundWindowVerified -WindowHandle $calibrationDialogHandle
                $calibrationDialogAutomationId = [string]$calibrationDialog.Current.AutomationId
                $calibrateButton = Get-AutomationElementObservation `
                    -TargetProcessId $freshProcess.Id `
                    -AutomationId "OsuImportMode.Calibrate" `
                    -RootWindowHandle $calibrationDialogHandle
                Save-AutomationElementScreenshot `
                    -Element $calibrationDialog `
                    -Path $calibrationScreenshots[$calibrationIndex]
                $clickedAtUtc = [DateTimeOffset]::UtcNow
                Click-AutomationElementWithMouse -Element $calibrateButton.Element
                $dismissDeadline = [DateTime]::UtcNow.AddSeconds(8)
                $dismissed = $false
                do {
                    Start-Sleep -Milliseconds 80
                    if (-not [LumaChartAvaloniaCaptureNative]::IsWindow($calibrationDialogHandle)) {
                        $dismissed = $true
                        break
                    }
                    try {
                        $oldDialogRoot = [System.Windows.Automation.AutomationElement]::FromHandle(
                            $calibrationDialogHandle)
                        $oldChartName = Find-AutomationElementById `
                            -TargetProcessId $freshProcess.Id `
                            -AutomationId "OsuImportMode.ChartName" `
                            -RootWindowHandle $calibrationDialogHandle `
                            -TimeoutMilliseconds 150
                        if (-not ([string]$oldChartName.Current.Name).Equals(
                                $expectedOsuChartName,
                                [StringComparison]::Ordinal)) {
                            $dismissed = $true
                            break
                        }
                    }
                    catch [System.Windows.Automation.ElementNotAvailableException] {
                        $dismissed = $true
                    }
                    catch [Runtime.InteropServices.COMException] {
                        $dismissed = $true
                    }
                } while ([DateTime]::UtcNow -lt $dismissDeadline)
                if (-not $dismissed) {
                    throw "Fresh OSZ calibration dialog for '$expectedOsuChartName' did not dismiss after its physical click."
                }
                $calibrationDialogs.Add([pscustomobject][ordered]@{
                        index = $calibrationIndex
                        expectedChartName = $expectedOsuChartName
                        dialogAutomationId = $calibrationDialogAutomationId
                        nativeWindowHandle = [long]$calibrationDialogHandle
                        chartName = $chartNameObservation.Evidence
                        action = "Calibrate"
                        button = $calibrateButton.Evidence
                        foregroundVerified = $true
                        input = "physical Win32 mouse click at UI Automation bounds"
                        physicalClick = $true
                        invokePatternUsed = $false
                        clickedAtUtc = $clickedAtUtc
                        dismissedAfterPhysicalClick = $dismissed
                        screenshotPath = $calibrationScreenshots[$calibrationIndex]
                        screenshotSha256 = (Get-FileHash `
                            -LiteralPath $calibrationScreenshots[$calibrationIndex] `
                            -Algorithm SHA256).Hash
                    }) | Out-Null
            }
            $osuImportModes = [ordered]@{
                expectedCount = $ExpectedChartCount
                observedCount = $calibrationDialogs.Count
                expectedChartNames = $expectedOsuChartFileNames
                allCalibratePhysical =
                    @($calibrationDialogs | Where-Object {
                            -not [bool]$_.physicalClick -or
                            [bool]$_.invokePatternUsed -or
                            -not [bool]$_.dismissedAfterPhysicalClick
                        }).Count -eq 0
                dialogs = @($calibrationDialogs)
            }
            if ($calibrationDialogs.Count -ne $ExpectedChartCount -or
                -not [bool]$osuImportModes.allCalibratePhysical) {
                throw "Fresh OSZ import did not physically calibrate every ordered osu chart."
            }
        }

        $chartTabCondition = [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
            "Editor.ChartTab")
        $workspaceBoundary = [IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\') + '\'
        $tabDeadline = [DateTime]::UtcNow.AddSeconds(15)
        $tabFindAllAttemptCount = 0
        $tabFindAllTransientFailures = [Collections.Generic.List[object]]::new()
        $importedTabs = @()
        do {
            Start-Sleep -Milliseconds 180
            $freshProcess.Refresh()
            if ($freshProcess.HasExited) {
                throw "Fresh MCZ GUI exited while imported chart tabs were being enumerated."
            }
            $freshMainWindowHandle = [IntPtr]$freshProcess.MainWindowHandle
            if ($freshMainWindowHandle -eq [IntPtr]::Zero -or
                -not [LumaChartAvaloniaCaptureNative]::IsWindow($freshMainWindowHandle)) {
                throw "Fresh MCZ GUI main window became unavailable while imported chart tabs were being enumerated."
            }
            $tabFindAllAttemptCount++
            try {
                $mainRoot = [System.Windows.Automation.AutomationElement]::FromHandle(
                    $freshMainWindowHandle)
                $allTabPeers = $mainRoot.FindAll(
                    [System.Windows.Automation.TreeScope]::Descendants,
                    $chartTabCondition)
            }
            catch {
                $tabFindAllTransientException = $null
                $tabFindAllExceptionCandidate = $_.Exception
                $tabFindAllExceptionDepth = 0
                while ($null -ne $tabFindAllExceptionCandidate -and
                       $tabFindAllExceptionDepth -lt 8) {
                    if ($tabFindAllExceptionCandidate -is
                            [System.Runtime.InteropServices.COMException] -or
                        $tabFindAllExceptionCandidate -is
                            [System.Windows.Automation.ElementNotAvailableException]) {
                        $tabFindAllTransientException = $tabFindAllExceptionCandidate
                        break
                    }
                    $tabFindAllExceptionCandidate =
                        $tabFindAllExceptionCandidate.InnerException
                    $tabFindAllExceptionDepth++
                }
                if ($null -eq $tabFindAllTransientException) {
                    throw
                }
                $tabFindAllHResult = '0x' +
                    $tabFindAllTransientException.HResult.ToString(
                        'X8',
                        [Globalization.CultureInfo]::InvariantCulture)
                $tabFindAllTransientFailures.Add([ordered]@{
                        attempt = $tabFindAllAttemptCount
                        mainWindowHandle = [long]$freshMainWindowHandle
                        exceptionType = $tabFindAllTransientException.GetType().FullName
                        hResult = $tabFindAllHResult
                    }) | Out-Null
                if ([DateTime]::UtcNow -ge $tabDeadline) {
                    throw "Fresh MCZ GUI imported-tab UIA FindAll did not succeed within 15000 ms; last HRESULT was $tabFindAllHResult."
                }
                continue
            }
            $importedTabs = @($allTabPeers | ForEach-Object {
                    try {
                        $source = [string]$_.Current.HelpText
                        if (-not [string]::IsNullOrWhiteSpace($source) -and
                            [IO.Path]::GetFullPath($source).StartsWith(
                                $workspaceBoundary,
                                [StringComparison]::OrdinalIgnoreCase)) {
                            [pscustomobject]@{
                                Element = $_
                                Name = [string]$_.Current.Name
                                SourcePath = [IO.Path]::GetFullPath($source)
                            }
                        }
                    }
                    catch { }
                })
        } while ($importedTabs.Count -lt $ExpectedChartCount -and
                 [DateTime]::UtcNow -lt $tabDeadline)
        if ($importedTabs.Count -ne $ExpectedChartCount) {
            throw "Fresh MCZ GUI opened $($importedTabs.Count) imported chart tabs; $ExpectedChartCount were required."
        }
        $mainImportedTabs = @($importedTabs | Where-Object {
                [IO.Path]::GetFileName($_.SourcePath).Equals(
                    $MainChartFileName,
                    [StringComparison]::OrdinalIgnoreCase)
            })
        if ($mainImportedTabs.Count -ne 1) {
            throw "Fresh MCZ GUI did not expose one unique imported main-chart tab."
        }
        Scroll-AutomationElementIntoView -Element $mainImportedTabs[0].Element
        Click-AutomationElementWithMouse -Element $mainImportedTabs[0].Element
        Start-Sleep -Milliseconds 300
        $importActionCompletedAt = [DateTimeOffset]::UtcNow

        $interactionDeadline = [DateTime]::UtcNow.AddSeconds(
            $(if ($isOsuFreshImport) { 55 } else { 35 }))
        while (-not (Test-Path -LiteralPath $InteractionEvidencePath -PathType Leaf) -and
               -not $freshProcess.HasExited -and
               [DateTime]::UtcNow -lt $interactionDeadline) {
            Start-Sleep -Milliseconds 150
            $freshProcess.Refresh()
        }
        if (-not (Test-Path -LiteralPath $InteractionEvidencePath -PathType Leaf)) {
            throw "Fresh Avalonia import did not write post-import interaction evidence."
        }
        $interaction = Get-Content -LiteralPath $InteractionEvidencePath -Raw | ConvertFrom-Json
        $interactionGenerated = [DateTimeOffset]::Parse(
            [string]$interaction.generatedAtUtc,
            [Globalization.CultureInfo]::InvariantCulture)
        $importedSourcePath = [IO.Path]::GetFullPath([string]$interaction.chart.sourcePath)
        $freshSourceSha256 =
            (Get-FileHash -LiteralPath $importedSourcePath -Algorithm SHA256).Hash
        if (-not $isOsuFreshImport) {
        $freshMainChart = Get-Content -LiteralPath $importedSourcePath -Raw | ConvertFrom-Json
        $freshPackagedBackgroundReference = [string]$freshMainChart.meta.background
        $freshPackagedSongReference = [string]$freshMainChart.meta.song.file
        $freshKeySoundReference = [string]$freshMainChart.note[$baselineKeySoundIndex].sound
        if (-not $freshPackagedBackgroundReference.Equals(
                $expectedPackagedBackgroundReference,
                [StringComparison]::Ordinal) -or
            -not $freshPackagedSongReference.Equals(
                $expectedPackagedSongReference,
                [StringComparison]::Ordinal) -or
            -not $freshKeySoundReference.Equals(
                $expectedPackagedSongReference,
                [StringComparison]::Ordinal)) {
            throw "Fresh MCZ main chart did not expose the three exact deterministic _2 resource references."
        }

        $expectedDirtySemanticMap = ConvertTo-JsonSemanticMap -Value $expectedDirtyChart
        $freshSemanticMap = ConvertTo-JsonSemanticMap -Value $freshMainChart
        $differencesBeforeResourceNormalization = @(
            Compare-JsonSemanticMaps `
                -Expected $expectedDirtySemanticMap `
                -Actual $freshSemanticMap)
        $allowedResourceDifferencePaths = @(
            '/meta/background',
            '/meta/song/file',
            "/note/$baselineKeySoundIndex/sound") | Sort-Object
        $actualResourceDifferencePaths = @(
            $differencesBeforeResourceNormalization |
                Select-Object -ExpandProperty path |
                Sort-Object)
        if ($differencesBeforeResourceNormalization.Count -ne 3 -or
            ($allowedResourceDifferencePaths -join '|') -ne
                ($actualResourceDifferencePaths -join '|')) {
            throw "Fresh MCZ main chart semantic diff was not limited to the three deterministic resource-reference paths."
        }
        $resourceDifferenceExpectations = @{
            '/meta/background' = [pscustomobject][ordered]@{
                expected = 'string:' + $baselineBackgroundReference
                actual = 'string:' + $expectedPackagedBackgroundReference
            }
            '/meta/song/file' = [pscustomobject][ordered]@{
                expected = 'string:' + $baselineSongReference
                actual = 'string:' + $expectedPackagedSongReference
            }
            "/note/$baselineKeySoundIndex/sound" = [pscustomobject][ordered]@{
                expected = 'string:' + $baselineSongReference
                actual = 'string:' + $expectedPackagedSongReference
            }
        }
        foreach ($difference in $differencesBeforeResourceNormalization) {
            $differencePath = [string]($difference.path)
            $expectation = $resourceDifferenceExpectations[$differencePath]
            $expectedDifferenceValue = [string]($difference.expected)
            $actualDifferenceValue = [string]($difference.actual)
            $expectedMappingValue = if ($null -eq $expectation) {
                $null
            } else {
                [string]($expectation.expected)
            }
            $actualMappingValue = if ($null -eq $expectation) {
                $null
            } else {
                [string]($expectation.actual)
            }
            if ($null -eq $expectation -or
                -not $expectedDifferenceValue.Equals(
                    $expectedMappingValue,
                    [StringComparison]::Ordinal) -or
                -not $actualDifferenceValue.Equals(
                    $actualMappingValue,
                    [StringComparison]::Ordinal)) {
                throw "Fresh MCZ resource-reference diff values at '$differencePath' did not match the exact deterministic _2 mapping."
            }
        }

        $expectedDirtyChart.meta.background = $expectedPackagedBackgroundReference
        $expectedDirtyChart.meta.song.file = $expectedPackagedSongReference
        $expectedDirtyChart.note[$baselineKeySoundIndex].sound =
            $expectedPackagedSongReference
        $normalizedExpectedSemanticMap = ConvertTo-JsonSemanticMap -Value $expectedDirtyChart
        $resourceProjectionDifferences = @(
            Compare-JsonSemanticMaps `
                -Expected $expectedDirtySemanticMap `
                -Actual $normalizedExpectedSemanticMap)
        if ($resourceProjectionDifferences.Count -ne 3 -or
            (($resourceProjectionDifferences | ConvertTo-Json -Depth 4 -Compress) -cne
             ($differencesBeforeResourceNormalization | ConvertTo-Json -Depth 4 -Compress))) {
            throw "Expected MCZ resource projection was not exactly the three observed deterministic _2 reference changes."
        }
        $differencesAfterResourceNormalization = @(
            Compare-JsonSemanticMaps `
                -Expected $normalizedExpectedSemanticMap `
                -Actual $freshSemanticMap)
        if ($differencesAfterResourceNormalization.Count -ne 0) {
            throw "Fresh MCZ main chart retained semantic differences after the three proven resource-reference mappings were normalized."
        }

        $freshArchiveEvidence = Get-MalodyFullPackageArchiveEvidence `
            -Path $ArchivePath `
            -MainChartFileName $MainChartFileName `
            -ExpectedBeat $ExpectedBeat `
            -OriginalBeat $OriginalBeat `
            -ExpectedLane $ExpectedLane
        $archiveBackgroundEntries = @($freshArchiveEvidence.entries | Where-Object {
                ([string]$_.fullName) -ceq $expectedPackagedBackgroundReference
            })
        $archiveSongEntries = @($freshArchiveEvidence.entries | Where-Object {
                ([string]$_.fullName) -ceq $expectedPackagedSongReference
            })
        if ($archiveBackgroundEntries.Count -ne 1 -or $archiveSongEntries.Count -ne 1) {
            throw "Fresh MCZ archive did not contain one exact entry for each deterministic _2 resource."
        }
        $freshResourceDirectory = [IO.Path]::GetDirectoryName($importedSourcePath)
        $freshBackgroundPath = [IO.Path]::GetFullPath(
            (Join-Path $freshResourceDirectory $expectedPackagedBackgroundReference))
        $freshSongPath = [IO.Path]::GetFullPath(
            (Join-Path $freshResourceDirectory $expectedPackagedSongReference))
        foreach ($freshResourcePath in @($freshBackgroundPath, $freshSongPath)) {
            if (-not (Test-Path -LiteralPath $freshResourcePath -PathType Leaf)) {
                throw "Fresh MCZ import did not extract an expected deterministic _2 resource: $freshResourcePath"
            }
        }
        $sourceBackgroundItem = Get-Item -LiteralPath $sourceBackgroundPath
        $sourceSongItem = Get-Item -LiteralPath $sourceSongPath
        $freshBackgroundItem = Get-Item -LiteralPath $freshBackgroundPath
        $freshSongItem = Get-Item -LiteralPath $freshSongPath
        $sourceBackgroundSha256 =
            (Get-FileHash -LiteralPath $sourceBackgroundPath -Algorithm SHA256).Hash
        $sourceSongSha256 =
            (Get-FileHash -LiteralPath $sourceSongPath -Algorithm SHA256).Hash
        $freshBackgroundSha256 =
            (Get-FileHash -LiteralPath $freshBackgroundPath -Algorithm SHA256).Hash
        $freshSongSha256 =
            (Get-FileHash -LiteralPath $freshSongPath -Algorithm SHA256).Hash
        $resourceBytesVerified =
            $sourceBackgroundSha256 -eq [string]$archiveBackgroundEntries[0].sha256 -and
            $sourceBackgroundSha256 -eq $freshBackgroundSha256 -and
            [long]$sourceBackgroundItem.Length -eq [long]$archiveBackgroundEntries[0].length -and
            [long]$sourceBackgroundItem.Length -eq [long]$freshBackgroundItem.Length -and
            $sourceSongSha256 -eq [string]$archiveSongEntries[0].sha256 -and
            $sourceSongSha256 -eq $freshSongSha256 -and
            [long]$sourceSongItem.Length -eq [long]$archiveSongEntries[0].length -and
            [long]$sourceSongItem.Length -eq [long]$freshSongItem.Length
        if (-not $resourceBytesVerified) {
            throw "Fresh MCZ deterministic _2 resource references did not preserve exact source/archive/import bytes."
        }
        $resourceRenameMappings = @(
            [ordered]@{
                jsonPointer = '/meta/background'
                sourceReference = $baselineBackgroundReference
                packagedReference = $expectedPackagedBackgroundReference
                sourcePath = $sourceBackgroundPath
                sourceLength = [long]$sourceBackgroundItem.Length
                sourceSha256 = $sourceBackgroundSha256
                archiveEntry = [string]$archiveBackgroundEntries[0].fullName
                archiveLength = [long]$archiveBackgroundEntries[0].length
                archiveSha256 = [string]$archiveBackgroundEntries[0].sha256
                freshPath = $freshBackgroundPath
                freshLength = [long]$freshBackgroundItem.Length
                freshSha256 = $freshBackgroundSha256
            },
            [ordered]@{
                jsonPointer = '/meta/song/file'
                sourceReference = $baselineSongReference
                packagedReference = $expectedPackagedSongReference
                sourcePath = $sourceSongPath
                sourceLength = [long]$sourceSongItem.Length
                sourceSha256 = $sourceSongSha256
                archiveEntry = [string]$archiveSongEntries[0].fullName
                archiveLength = [long]$archiveSongEntries[0].length
                archiveSha256 = [string]$archiveSongEntries[0].sha256
                freshPath = $freshSongPath
                freshLength = [long]$freshSongItem.Length
                freshSha256 = $freshSongSha256
            },
            [ordered]@{
                jsonPointer = "/note/$baselineKeySoundIndex/sound"
                sourceReference = $baselineSongReference
                packagedReference = $expectedPackagedSongReference
                sharedResourcePointer = '/meta/song/file'
                sourceSha256 = $sourceSongSha256
                archiveSha256 = [string]$archiveSongEntries[0].sha256
                freshSha256 = $freshSongSha256
            })

        $freshResourceDirectoryFullPath = [IO.Path]::GetFullPath(
            $freshResourceDirectory).TrimEnd('\')
        $expectedFreshResourceDirectory = [IO.Path]::GetFullPath(
            (Join-Path `
                $WorkspaceRoot `
                ([IO.Path]::GetFileNameWithoutExtension($ArchivePath)))).TrimEnd('\')
        if (-not $freshResourceDirectoryFullPath.Equals(
                $expectedFreshResourceDirectory,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fresh MCZ extraction directory was not the exact workspace/out directory."
        }

        $workspaceTopLevelChildren = @(
            Get-ChildItem -LiteralPath $WorkspaceRoot -Force)
        if ($workspaceTopLevelChildren.Count -ne 1 -or
            -not $workspaceTopLevelChildren[0].PSIsContainer -or
            -not [IO.Path]::GetFullPath(
                $workspaceTopLevelChildren[0].FullName).Equals(
                    $freshResourceDirectoryFullPath,
                    [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fresh MCZ workspace did not contain exactly one top-level out directory."
        }

        $sourceChartFiles = @(
            Get-ChildItem `
                -LiteralPath $sourceRootFullPath `
                -Recurse `
                -File `
                -Filter "*.mc" |
                Sort-Object FullName)
        $sourceRelativePaths = @($sourceChartFiles | ForEach-Object {
                [IO.Path]::GetRelativePath($sourceRootFullPath, $_.FullName).
                    Replace([IO.Path]::DirectorySeparatorChar, '/')
            })
        $sourceArchiveLeafNames = @($sourceChartFiles | ForEach-Object { $_.Name })
        $sourceLeafSet = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase)
        foreach ($leafName in $sourceArchiveLeafNames) {
            [void]$sourceLeafSet.Add([string]$leafName)
        }
        if ($sourceChartFiles.Count -ne $ExpectedChartCount -or
            $sourceRelativePaths.Count -ne $ExpectedChartCount -or
            $sourceLeafSet.Count -ne $ExpectedChartCount -or
            @($sourceRelativePaths | Where-Object {
                    [string]$_ -cnotmatch '^0/[^/]+\.mc$'
                }).Count -ne 0) {
            throw "MCZ source-chart manifest did not expose eight unique 0/<leaf>.mc identities."
        }

        $archiveChartEntries = @(
            $freshArchiveEvidence.entries |
                Where-Object { [bool]$_.isMalodyChart } |
                Sort-Object fullName)
        $expectedArchiveChartNames = @($sourceArchiveLeafNames | Sort-Object)
        $actualArchiveChartNames = @(
            $archiveChartEntries | ForEach-Object { [string]$_.fullName })
        if ($archiveChartEntries.Count -ne $ExpectedChartCount -or
            ($expectedArchiveChartNames -join "`n") -cne
                ($actualArchiveChartNames -join "`n")) {
            throw "MCZ archive chart-entry identity set did not exactly match the eight source leaf names."
        }

        $freshChildDirectories = @(
            Get-ChildItem `
                -LiteralPath $freshResourceDirectoryFullPath `
                -Recurse `
                -Directory `
                -Force)
        $freshPackageTree = Get-DirectoryTreeEvidence -Root $freshResourceDirectoryFullPath
        $archiveTreeRows = @(
            $freshArchiveEvidence.entries | ForEach-Object {
                [pscustomobject][ordered]@{
                    relativePath = [string]$_.fullName
                    length = [long]$_.length
                    sha256 = [string]$_.sha256
                }
            } | Sort-Object relativePath)
        $freshTreeRows = @(
            $freshPackageTree.files | ForEach-Object {
                [pscustomobject][ordered]@{
                    relativePath = [string]$_.relativePath
                    length = [long]$_.length
                    sha256 = [string]$_.sha256
                }
            } | Sort-Object relativePath)
        $archiveTreeContentSha256 = Get-ContentManifestSha256 -Rows $archiveTreeRows
        $freshTreeContentSha256 = Get-ContentManifestSha256 -Rows $freshTreeRows
        if ($archiveTreeRows.Count -ne 13 -or
            $freshTreeRows.Count -ne 13 -or
            $freshChildDirectories.Count -ne 0 -or
            $archiveTreeContentSha256 -cne $freshTreeContentSha256 -or
            (($archiveTreeRows | ConvertTo-Json -Depth 4 -Compress) -cne
             ($freshTreeRows | ConvertTo-Json -Depth 4 -Compress))) {
            throw "Fresh MCZ extraction tree was not the exact flat 13-file archive byte manifest."
        }

        $expectedFreshChartPaths = @($sourceChartFiles | ForEach-Object {
                [IO.Path]::GetFullPath(
                    (Join-Path $freshResourceDirectoryFullPath $_.Name))
            } | Sort-Object)
        $actualImportedTabPaths = @($importedTabs | ForEach-Object {
                [IO.Path]::GetFullPath([string]$_.SourcePath)
            } | Sort-Object)
        $importedTabPathMismatch =
            $expectedFreshChartPaths.Count -ne $actualImportedTabPaths.Count
        if (-not $importedTabPathMismatch) {
            for ($pathIndex = 0;
                 $pathIndex -lt $expectedFreshChartPaths.Count;
                 $pathIndex++) {
                if (-not $expectedFreshChartPaths[$pathIndex].Equals(
                        $actualImportedTabPaths[$pathIndex],
                        [StringComparison]::OrdinalIgnoreCase)) {
                    $importedTabPathMismatch = $true
                    break
                }
            }
        }
        if ($importedTabPathMismatch) {
            throw "Fresh MCZ imported-tab source paths did not exactly match the eight chart manifest paths."
        }

        $chartManifestEntries = [Collections.Generic.List[object]]::new()
        foreach ($sourceChartFile in $sourceChartFiles) {
            $sourceRelativePath = [IO.Path]::GetRelativePath(
                $sourceRootFullPath,
                $sourceChartFile.FullName).
                Replace([IO.Path]::DirectorySeparatorChar, '/')
            $archiveEntryName = $sourceChartFile.Name
            $matchingArchiveEntries = @($archiveChartEntries | Where-Object {
                    [string]$_.fullName -ceq $archiveEntryName
                })
            if ($matchingArchiveEntries.Count -ne 1) {
                throw "MCZ chart manifest did not find one exact archive entry for '$archiveEntryName'."
            }
            $archiveEntry = $matchingArchiveEntries[0]
            $freshChartPath = [IO.Path]::GetFullPath(
                (Join-Path $freshResourceDirectoryFullPath $archiveEntryName))
            if (-not (Test-Path -LiteralPath $freshChartPath -PathType Leaf)) {
                throw "MCZ chart manifest fresh file is missing: $freshChartPath"
            }

            $sourceChart = Get-Content -LiteralPath $sourceChartFile.FullName -Raw |
                ConvertFrom-Json
            $freshChart = Get-Content -LiteralPath $freshChartPath -Raw |
                ConvertFrom-Json
            $isMainChart = $archiveEntryName.Equals(
                $MainChartFileName,
                [StringComparison]::Ordinal)
            $expectedChart = if ($isMainChart) { $expectedDirtyChart } else { $sourceChart }
            $expectedSemanticMap = ConvertTo-JsonSemanticMap -Value $expectedChart
            $freshChartSemanticMap = ConvertTo-JsonSemanticMap -Value $freshChart
            $semanticDifferences = @(
                Compare-JsonSemanticMaps `
                    -Expected $expectedSemanticMap `
                    -Actual $freshChartSemanticMap)
            $sourceSemanticSha256 = Get-JsonSemanticSha256 -Value $sourceChart
            $expectedSemanticSha256 = Get-JsonSemanticSha256 -Value $expectedChart
            $freshSemanticSha256 = Get-JsonSemanticSha256 -Value $freshChart
            $sourceChartSha256 =
                (Get-FileHash -LiteralPath $sourceChartFile.FullName -Algorithm SHA256).Hash
            $freshChartSha256 =
                (Get-FileHash -LiteralPath $freshChartPath -Algorithm SHA256).Hash
            $archiveEntrySha256 = [string]$archiveEntry.sha256
            $archiveFreshBytesExact =
                $archiveEntrySha256 -ceq $freshChartSha256 -and
                [long]$archiveEntry.length -eq [long](Get-Item -LiteralPath $freshChartPath).Length
            $entryVerified =
                $semanticDifferences.Count -eq 0 -and
                $expectedSemanticSha256 -ceq $freshSemanticSha256 -and
                $archiveFreshBytesExact -and
                ($isMainChart -or $sourceSemanticSha256 -ceq $expectedSemanticSha256)
            if (-not $entryVerified) {
                throw "MCZ chart manifest semantic/byte chain failed for '$archiveEntryName'."
            }

            $chartManifestEntries.Add([pscustomobject][ordered]@{
                    isMain = $isMainChart
                    sourceRelativePath = $sourceRelativePath
                    sourcePath = $sourceChartFile.FullName
                    sourceLength = [long]$sourceChartFile.Length
                    sourceSha256 = $sourceChartSha256
                    sourceSemanticSha256 = $sourceSemanticSha256
                    semanticBaselineKind = if ($isMainChart) {
                        "workingProjected"
                    } else { "sourceMc" }
                    semanticBaselinePath = if ($isMainChart) {
                        $expectedWorkingChartFullPath
                    } else { $sourceChartFile.FullName }
                    expectedSemanticSha256 = $expectedSemanticSha256
                    archiveEntry = $archiveEntryName
                    archiveLength = [long]$archiveEntry.length
                    archiveSha256 = $archiveEntrySha256
                    archiveSemanticSha256 = $freshSemanticSha256
                    freshRelativePath = $archiveEntryName
                    freshPath = $freshChartPath
                    freshLength = [long](Get-Item -LiteralPath $freshChartPath).Length
                    freshSha256 = $freshChartSha256
                    freshSemanticSha256 = $freshSemanticSha256
                    semanticDifferenceCount = $semanticDifferences.Count
                    semanticDifferences = $semanticDifferences
                    archiveFreshBytesExact = $archiveFreshBytesExact
                    verified = $entryVerified
                }) | Out-Null
        }
        $mainManifestEntries = @($chartManifestEntries | Where-Object { [bool]$_.isMain })
        if ($chartManifestEntries.Count -ne $ExpectedChartCount -or
            $mainManifestEntries.Count -ne 1 -or
            @($chartManifestEntries | Where-Object { -not [bool]$_.verified }).Count -ne 0) {
            throw "MCZ chart manifest did not prove exactly eight entries and one projected main chart."
        }

        $chartManifestEvidence = [ordered]@{
            schema = "lumachart.windows.avalonia.mcz-chart-manifest.v1"
            identityRule =
                "exact source relative path + case-preserved flat archive leaf + exact fresh relative path + imported-tab source path"
            sourceRoot = $sourceRootFullPath
            archivePath = [IO.Path]::GetFullPath($ArchivePath)
            freshExtractionRoot = $freshResourceDirectoryFullPath
            expectedChartCount = $ExpectedChartCount
            entryCount = $chartManifestEntries.Count
            mainEntry = $MainChartFileName
            sourceRelativePaths = $sourceRelativePaths
            archiveChartEntries = $actualArchiveChartNames
            freshChartPaths = $expectedFreshChartPaths
            importedTabPaths = $actualImportedTabPaths
            dirtyProjection = [ordered]@{
                logicalJsonPointer = $expectedDirtyBeatPath
                baselineBeat = $expectedDirtyBeatBefore
                submittedBeat = @(
                    [int]$ExpectedBeat.bar,
                    [int]$ExpectedBeat.numerator,
                    [int]$ExpectedBeat.denominator)
                logicalDifferenceCount = 1
                rawDifferenceCount = $dirtyProjectionDifferences.Count
                rawDifferences = $dirtyProjectionDifferences
                verified = $true
            }
            resourceProjection = [ordered]@{
                rule = "WPF-compatible deterministic same-name resource collision suffix _2"
                differenceCount = $resourceProjectionDifferences.Count
                differences = $resourceProjectionDifferences
                mappings = $resourceRenameMappings
                verified = $true
            }
            archiveFreshTree = [ordered]@{
                expectedEntryCount = 13
                archiveEntryCount = $archiveTreeRows.Count
                freshFileCount = $freshTreeRows.Count
                freshDirectoryCount = $freshChildDirectories.Count
                workspaceTopLevelChildCount = $workspaceTopLevelChildren.Count
                workspaceTopLevelDirectoryName = $workspaceTopLevelChildren[0].Name
                archiveContentSha256 = $archiveTreeContentSha256
                freshContentSha256 = $freshTreeContentSha256
                exact = $true
            }
            entries = @($chartManifestEntries)
            importedTabPathsExact = $true
            verified = $true
        }
        $freshPlayableNotes = @($freshMainChart.note | Where-Object {
                $null -ne $_.column -and $null -ne $_.beat -and
                @($_.beat).Count -ge 3 -and
                [int]$_.column -eq $ExpectedLane
            })
        $freshExactBeatMatchCount = @($freshPlayableNotes | Where-Object {
                [int]$_.beat[0] -eq [int]$ExpectedBeat.bar -and
                [int]$_.beat[1] -eq [int]$ExpectedBeat.numerator -and
                [int]$_.beat[2] -eq [int]$ExpectedBeat.denominator
            }).Count
        $freshOriginalBeatMatchCount = @($freshPlayableNotes | Where-Object {
                [int]$_.beat[0] -eq [int]$OriginalBeat.bar -and
                [int]$_.beat[1] -eq [int]$OriginalBeat.numerator -and
                [int]$_.beat[2] -eq [int]$OriginalBeat.denominator
            }).Count
        $freshVerified =
            $interactionGenerated -ge $importActionCompletedAt -and
            [bool]$interaction.evidenceInteractionFollowsActiveTab -and
            [bool]$interaction.evidenceFilePickerStartDirectoryInjected -and
            [IO.Path]::GetFullPath(
                [string]$interaction.evidenceFilePickerStartDirectory).Equals(
                    $expectedPickerStartDirectory,
                    [StringComparison]::OrdinalIgnoreCase) -and
            $importedSourcePath.StartsWith($workspaceBoundary, [StringComparison]::OrdinalIgnoreCase) -and
            [IO.Path]::GetFileName($importedSourcePath).Equals(
                $MainChartFileName,
                [StringComparison]::OrdinalIgnoreCase) -and
            [int]$freshArchiveEvidence.mainChartEntryCount -eq 1 -and
            [string]$freshArchiveEvidence.mainChartEntry.sha256 -eq $ExpectedMainEntrySha256 -and
            [int]$freshArchiveEvidence.mainChartExactBeatMatchCount -eq 1 -and
            [int]$freshArchiveEvidence.mainChartOriginalBeatMatchCount -eq 0 -and
            $freshSourceSha256 -eq $ExpectedMainEntrySha256 -and
            [string]$interaction.chart.sourceSha256 -eq $ExpectedMainEntrySha256 -and
            [string]$interaction.chart.structure.sha256 -eq $ExpectedMainEntrySha256 -and
            [int]$interaction.chart.structure.keyCount -eq $ExpectedKeyCount -and
            [int]$interaction.chart.structure.noteCount -eq $ExpectedNoteCount -and
            [int]$interaction.chart.structure.longNoteCount -eq $ExpectedLongNoteCount -and
            [int]$interaction.chart.structure.timingCount -eq $ExpectedTimingCount -and
            $differencesBeforeResourceNormalization.Count -eq 3 -and
            $differencesAfterResourceNormalization.Count -eq 0 -and
            $resourceBytesVerified -and
            [bool]$chartManifestEvidence.verified -and
            [int]$chartManifestEvidence.entryCount -eq $ExpectedChartCount -and
            [bool]$chartManifestEvidence.importedTabPathsExact -and
            [bool]$chartManifestEvidence.archiveFreshTree.exact -and
            $freshExactBeatMatchCount -eq 1 -and
            $freshOriginalBeatMatchCount -eq 0 -and
            -not [bool]$interaction.timeline.sessionIsDirty -and
            [long]$interaction.timeline.sessionChangeSerial -eq 0
        if (-not $freshVerified) {
            throw "Fresh Avalonia MCZ import did not preserve exact compact bytes, normalized structure, counts, dirty Beat, resources, and clean-tab state."
        }
        }
        else {
            $freshArchiveEvidence = Get-OsuFullPackageArchiveEvidence `
                -Path $ArchivePath `
                -MainChartFileName $MainChartFileName `
                -SourceRoot $sourceRootFullPath `
                -ExpectedChartCount $ExpectedChartCount `
                -ExpectedOverallDifficulty $ExpectedOverallDifficulty `
                -ExpectedHpDrainRate $ExpectedHpDrainRate `
                -ExpectedHitObjectTime $ExpectedHitObjectTime `
                -OriginalLane $OriginalLane `
                -ExpectedLane $ExpectedExportedLane `
                -ExpectSourceOsuSiblings $ExpectSourceOsuSiblings
            $freshMainText = Get-Content -LiteralPath $importedSourcePath -Raw
            $freshResourceDirectoryFullPath = [IO.Path]::GetFullPath(
                [IO.Path]::GetDirectoryName($importedSourcePath)).TrimEnd('\')
            $freshFiles = @(Get-ChildItem -LiteralPath $freshResourceDirectoryFullPath -File)
            $freshChildDirectories = @(
                Get-ChildItem -LiteralPath $freshResourceDirectoryFullPath -Directory)
            $manifestEntries = [Collections.Generic.List[object]]::new()
            foreach ($archiveEntry in @($freshArchiveEvidence.entries)) {
                $freshMatches = @($freshFiles | Where-Object {
                        $_.Name.Equals(
                            [string]$archiveEntry.fullName,
                            [StringComparison]::OrdinalIgnoreCase)
                    })
                $freshLength = if ($freshMatches.Count -eq 1) {
                    [long]$freshMatches[0].Length
                } else { $null }
                $freshSha256 = if ($freshMatches.Count -eq 1) {
                    (Get-FileHash -LiteralPath $freshMatches[0].FullName -Algorithm SHA256).Hash
                } else { $null }
                $exact = $freshMatches.Count -eq 1 -and
                    $freshLength -eq [long]$archiveEntry.length -and
                    $freshSha256 -eq [string]$archiveEntry.sha256
                $manifestEntries.Add([pscustomobject][ordered]@{
                        relativePath = [string]$archiveEntry.fullName
                        archiveLength = [long]$archiveEntry.length
                        archiveSha256 = [string]$archiveEntry.sha256
                        freshMatchCount = $freshMatches.Count
                        freshPath = if ($freshMatches.Count -eq 1) {
                            $freshMatches[0].FullName
                        } else { $null }
                        freshLength = $freshLength
                        freshSha256 = $freshSha256
                        exact = $exact
                    }) | Out-Null
            }
            $expectedFreshChartPaths = @($freshArchiveEvidence.entries |
                Where-Object { [bool]$_.isOsu } |
                ForEach-Object {
                    [IO.Path]::GetFullPath(
                        (Join-Path $freshResourceDirectoryFullPath ([string]$_.fullName)))
                } | Sort-Object)
            $actualImportedTabPaths = @($importedTabs.SourcePath | Sort-Object)
            $importedTabPathsExact =
                ($expectedFreshChartPaths.Count -eq $actualImportedTabPaths.Count) -and
                (($expectedFreshChartPaths | ForEach-Object { $_.ToUpperInvariant() }) -join '|') -ceq
                (($actualImportedTabPaths | ForEach-Object { $_.ToUpperInvariant() }) -join '|')

            $mainAudioLine = @($freshMainText -split "`r?`n" | Where-Object {
                    $_ -match '^AudioFilename:'
                } | Select-Object -First 1)
            $mainAudioReference = if ($mainAudioLine.Count -eq 1) {
                ([string]$mainAudioLine[0]).Substring(
                    ([string]$mainAudioLine[0]).IndexOf(':') + 1).Trim()
            } else { $null }
            $backgroundMatch = [Text.RegularExpressions.Regex]::Match(
                $freshMainText,
                '(?m)^0,0,"([^"]+)",0,0\s*$')
            $mainBackgroundReference = if ($backgroundMatch.Success) {
                $backgroundMatch.Groups[1].Value
            } else { $null }
            $mainAudioPath = if ([string]::IsNullOrWhiteSpace($mainAudioReference)) {
                $null
            } else {
                [IO.Path]::GetFullPath(
                    (Join-Path $freshResourceDirectoryFullPath $mainAudioReference))
            }
            $mainBackgroundPath = if ([string]::IsNullOrWhiteSpace($mainBackgroundReference)) {
                $null
            } else {
                [IO.Path]::GetFullPath(
                    (Join-Path $freshResourceDirectoryFullPath $mainBackgroundReference))
            }
            $mainReferencesVerified =
                $null -ne $mainAudioPath -and
                (Test-Path -LiteralPath $mainAudioPath -PathType Leaf) -and
                ($null -eq $mainBackgroundPath -or
                 (Test-Path -LiteralPath $mainBackgroundPath -PathType Leaf))

            $sourceResourceFiles = @(Get-ChildItem -LiteralPath $sourceRootFullPath -File |
                Where-Object {
                    $_.Extension -notin '.osu', '.mc', '.mcz', '.osz', '.luma-part'
                })
            $resourceChains = [Collections.Generic.List[object]]::new()
            foreach ($sourceResource in $sourceResourceFiles) {
                $sourceResourceSha256 =
                    (Get-FileHash -LiteralPath $sourceResource.FullName -Algorithm SHA256).Hash
                $stem = [IO.Path]::GetFileNameWithoutExtension($sourceResource.Name)
                $extension = $sourceResource.Extension
                $matchingArchiveEntries = @($freshArchiveEvidence.entries | Where-Object {
                        ([string]$_.fullName).Equals(
                            $sourceResource.Name,
                            [StringComparison]::OrdinalIgnoreCase) -or
                        ([string]$_.fullName).Equals(
                            ($stem + '_2' + $extension),
                            [StringComparison]::OrdinalIgnoreCase)
                    })
                $matchingFreshEntries = @($manifestEntries | Where-Object {
                        ([string]$_.relativePath).Equals(
                            $sourceResource.Name,
                            [StringComparison]::OrdinalIgnoreCase) -or
                        ([string]$_.relativePath).Equals(
                            ($stem + '_2' + $extension),
                            [StringComparison]::OrdinalIgnoreCase)
                    })
                $exact = $matchingArchiveEntries.Count -ge 1 -and
                    $matchingArchiveEntries.Count -eq $matchingFreshEntries.Count -and
                    @($matchingArchiveEntries | Where-Object {
                            [string]$_.sha256 -ne $sourceResourceSha256 -or
                            [long]$_.length -ne [long]$sourceResource.Length
                        }).Count -eq 0 -and
                    @($matchingFreshEntries | Where-Object {
                            -not [bool]$_.exact -or
                            [string]$_.freshSha256 -ne $sourceResourceSha256
                        }).Count -eq 0
                $resourceChains.Add([pscustomobject][ordered]@{
                        sourcePath = $sourceResource.FullName
                        sourceLength = [long]$sourceResource.Length
                        sourceSha256 = $sourceResourceSha256
                        archiveEntries = @($matchingArchiveEntries | ForEach-Object {
                                [ordered]@{
                                    relativePath = $_.fullName
                                    length = $_.length
                                    sha256 = $_.sha256
                                }
                            })
                        freshEntries = @($matchingFreshEntries)
                        exact = $exact
                    }) | Out-Null
            }
            $resourceChainsVerified = $sourceResourceFiles.Count -ge 1 -and
                @($resourceChains | Where-Object { -not [bool]$_.exact }).Count -eq 0 -and
                (-not $isCrossFormat -or
                 ($sourceResourceFiles.Count -eq 2 -and
                  @($resourceChains | Where-Object {
                          @($_.archiveEntries).Count -ne 2 -or
                          @($_.freshEntries).Count -ne 2
                      }).Count -eq 0))
            $workspaceTopLevelChildren = @(Get-ChildItem -LiteralPath $WorkspaceRoot -Force)
            $freshOsuChartCount = @($freshFiles | Where-Object {
                    $_.Extension.Equals('.osu', [StringComparison]::OrdinalIgnoreCase)
                }).Count
            $freshMalodyChartCount = @($freshFiles | Where-Object {
                    $_.Extension.Equals('.mc', [StringComparison]::OrdinalIgnoreCase)
                }).Count
            $freshSiblingChartCount = @($freshFiles | Where-Object {
                    $_.Extension.Equals('.osu', [StringComparison]::OrdinalIgnoreCase) -and
                    -not $_.Name.Equals(
                        $MainChartFileName,
                        [StringComparison]::OrdinalIgnoreCase)
                }).Count
            $chartManifestEvidence = [ordered]@{
                schema = "lumachart.windows.avalonia.osz-chart-manifest.v1"
                sourceRoot = $sourceRootFullPath
                archivePath = [IO.Path]::GetFullPath($ArchivePath)
                freshExtractionRoot = $freshResourceDirectoryFullPath
                expectedChartCount = $ExpectedChartCount
                entryCount = $manifestEntries.Count
                importedTabPathsExact = $importedTabPathsExact
                expectedFreshChartPaths = $expectedFreshChartPaths
                importedTabPaths = $actualImportedTabPaths
                archiveChartCounts = [ordered]@{
                    osu = [int]$freshArchiveEvidence.chartEntryCount
                    malody = [int]$freshArchiveEvidence.malodyChartEntryCount
                    sibling = [int]$freshArchiveEvidence.siblingChartEntryCount
                }
                freshChartCounts = [ordered]@{
                    osu = $freshOsuChartCount
                    malody = $freshMalodyChartCount
                    sibling = $freshSiblingChartCount
                }
                archiveFreshTree = [ordered]@{
                    archiveEntryCount = [int]$freshArchiveEvidence.entryCount
                    freshFileCount = $freshFiles.Count
                    freshDirectoryCount = $freshChildDirectories.Count
                    workspaceTopLevelChildCount = $workspaceTopLevelChildren.Count
                    exact = $manifestEntries.Count -eq [int]$freshArchiveEvidence.entryCount -and
                        $freshFiles.Count -eq [int]$freshArchiveEvidence.entryCount -and
                        $freshChildDirectories.Count -eq 0 -and
                        $workspaceTopLevelChildren.Count -eq 1 -and
                        @($manifestEntries | Where-Object { -not [bool]$_.exact }).Count -eq 0
                }
                resourceChains = @($resourceChains)
                resourceChainsVerified = $resourceChainsVerified
                crossFormatResourceCopiesPerSource = if ($isCrossFormat) { 2 } else { $null }
                entries = @($manifestEntries)
                verified = $importedTabPathsExact -and
                    $resourceChainsVerified -and
                    $mainReferencesVerified -and
                    [int]$freshArchiveEvidence.chartEntryCount -eq $ExpectedChartCount -and
                    [int]$freshArchiveEvidence.malodyChartEntryCount -eq 0 -and
                    [int]$freshArchiveEvidence.siblingChartEntryCount -eq
                        ($ExpectedChartCount - 1) -and
                    $freshOsuChartCount -eq $ExpectedChartCount -and
                    $freshMalodyChartCount -eq 0 -and
                    $freshSiblingChartCount -eq ($ExpectedChartCount - 1)
            }
            $osuStructuralEquivalence = [ordered]@{
                archiveMainEntry = [string]$freshArchiveEvidence.mainChartEntry.fullName
                archiveMainEntrySha256 = [string]$freshArchiveEvidence.mainChartEntry.sha256
                freshSourcePath = $importedSourcePath
                freshSourceSha256 = $freshSourceSha256
                interactionSourceSha256 = [string]$interaction.chart.sourceSha256
                mainTextV14Mode3DifficultyAndDirtyHitObject =
                    [bool]$freshArchiveEvidence.mainChartFormatVerified
                siblingSourceArchiveExact = [bool]$freshArchiveEvidence.siblingChartsExact
                archiveFreshTreeExact = [bool]$chartManifestEvidence.archiveFreshTree.exact
                importedTabPathsExact = $importedTabPathsExact
                mainAudioReference = $mainAudioReference
                mainBackgroundReference = $mainBackgroundReference
                mainReferencesVerified = $mainReferencesVerified
                resourceChainsVerified = $resourceChainsVerified
                counts = [ordered]@{
                    expected = [ordered]@{
                        keyCount = $ExpectedKeyCount
                        noteCount = $ExpectedNoteCount
                        longNoteCount = $ExpectedLongNoteCount
                        timingCount = $ExpectedTimingCount
                    }
                    fresh = [ordered]@{
                        keyCount = [int]$interaction.chart.structure.keyCount
                        noteCount = [int]$interaction.chart.structure.noteCount
                        longNoteCount = [int]$interaction.chart.structure.longNoteCount
                        timingCount = [int]$interaction.chart.structure.timingCount
                    }
                }
            }
            $freshVerified =
                $interactionGenerated -ge $importActionCompletedAt -and
                [bool]$interaction.evidenceInteractionFollowsActiveTab -and
                [bool]$interaction.evidenceFilePickerStartDirectoryInjected -and
                [IO.Path]::GetFullPath(
                    [string]$interaction.evidenceFilePickerStartDirectory).Equals(
                        $expectedPickerStartDirectory,
                        [StringComparison]::OrdinalIgnoreCase) -and
                $importedSourcePath.StartsWith(
                    $workspaceBoundary,
                    [StringComparison]::OrdinalIgnoreCase) -and
                [IO.Path]::GetFileName($importedSourcePath).Equals(
                    $MainChartFileName,
                    [StringComparison]::OrdinalIgnoreCase) -and
                $freshSourceSha256 -eq [string]$freshArchiveEvidence.mainChartEntry.sha256 -and
                [string]$interaction.chart.sourceSha256 -eq $freshSourceSha256 -and
                [bool]$freshArchiveEvidence.mainChartFormatVerified -and
                [bool]$freshArchiveEvidence.siblingChartsExact -and
                [bool]$freshArchiveEvidence.allExcludedSourceArtifactsAbsent -and
                [bool]$freshArchiveEvidence.allEntriesFlat -and
                [int]$freshArchiveEvidence.unsafeEntryCount -eq 0 -and
                [int]$freshArchiveEvidence.caseInsensitiveDuplicateCount -eq 0 -and
                [bool]$chartManifestEvidence.verified -and
                [bool]$chartManifestEvidence.archiveFreshTree.exact -and
                [bool]$osuImportModes.allCalibratePhysical -and
                [int]$osuImportModes.observedCount -eq $ExpectedChartCount -and
                [int]$interaction.chart.structure.keyCount -eq $ExpectedKeyCount -and
                [int]$interaction.chart.structure.noteCount -eq $ExpectedNoteCount -and
                [int]$interaction.chart.structure.longNoteCount -eq $ExpectedLongNoteCount -and
                [int]$interaction.chart.structure.timingCount -eq $ExpectedTimingCount -and
                -not [bool]$interaction.timeline.sessionIsDirty -and
                [long]$interaction.timeline.sessionChangeSerial -eq 0
            $osuStructuralEquivalence['verified'] = $freshVerified
            if (-not $freshVerified) {
                throw "Fresh Avalonia OSZ import did not preserve archive/fresh bytes, sibling/resources, every calibrated tab, requested difficulty, dirty HitObject, counts, and clean-tab state."
            }
        }
        Set-ForegroundWindowVerified -WindowHandle $freshProcess.MainWindowHandle
        $freshRootElement = [System.Windows.Automation.AutomationElement]::FromHandle(
            $freshProcess.MainWindowHandle)
        Save-AutomationElementScreenshot `
            -Element $freshRootElement `
            -Path $FinalScreenshotPath `
            -Padding 0
        $workspaceTree = Get-DirectoryTreeEvidence -Root $WorkspaceRoot

        $freshProcess.CloseMainWindow() | Out-Null
        if (-not $freshProcess.WaitForExit(12000)) {
            throw "Fresh Avalonia MCZ import process did not exit normally."
        }
        $normalExit = $true
        if (Test-Path -LiteralPath $freshScratchRoot) {
            throw "Fresh Avalonia MCZ import left its session scratch root after normal exit: $freshScratchRoot"
        }
        return [ordered]@{
            processId = $freshProcess.Id
            nativeOpen = [ordered]@{
                title = $openDialogTitle
                requestedPath = $requestedOpenPath
                resolvedSelectionPath = $resolvedNativeSelectionPath
                startDirectory = $openDirectoryNavigation
                filenameProvider = $openFilenameProvider
                filenameControl = [ordered]@{
                    automationId = $openNameAutomationId
                    className = $openNameClassName
                    controlType = $openNameControlType
                    isEnabled = $openNameIsEnabled
                    isOffscreen = $openNameIsOffscreen
                    nativeWindowHandle = [long]$openNameHandle
                    bounds = [ordered]@{
                        left = [double]$openNameBounds.Left
                        top = [double]$openNameBounds.Top
                        width = [double]$openNameBounds.Width
                        height = [double]$openNameBounds.Height
                    }
                    readApi = "GetWindowTextW"
                    value = $openFilenameEditValue
                    valueAvailable = $openFilenameEditValueAvailable
                    mirrorsSelection = $openFilenameEditMirrorsSelection
                }
                inputMode = $openInputMode
                selectionSource = "exact selected native file ListItem"
                fileListSelection = $openFileListSelectionEvidence
                keyboardInputUsed = $false
                imeCommitRequired = $false
                imeCommitEnter = $false
                clipboardUsed = $false
                valueInjectionUsed = $false
                dialogOpenAfterFileListSelection =
                    $openDialogOpenAfterFileListSelection
                filenameValue = $openFilenameText
                submitPath = $openSubmitPath
                submitControl = $openSubmitControlEvidence
                dialogClosedAfterSubmit = $openDialogClosedAfterSubmit
            }
            preview = [ordered]@{
                title = $importDialogTitle
                countText = [string]$previewCountText
                openButton = $expectedOpenText
                uiaFindAll = [ordered]@{
                    attemptCount = $dialogFindAllAttemptCount
                    retryBudgetMilliseconds = 5000
                    retryDelayMilliseconds = 100
                    transientFailures = @($dialogFindAllTransientFailures)
                }
                screenshotPath = $ImportDialogScreenshotPath
                screenshotSha256 = (Get-FileHash -LiteralPath $ImportDialogScreenshotPath -Algorithm SHA256).Hash
            }
            tabPolling = [ordered]@{
                expectedChartCount = $ExpectedChartCount
                totalDeadlineMilliseconds = 15000
                pollDelayMilliseconds = 180
                findAllAttemptCount = $tabFindAllAttemptCount
                transientFailures = @($tabFindAllTransientFailures)
            }
            importedTabs = @($importedTabs | ForEach-Object {
                    [ordered]@{
                        name = $_.Name
                        sourcePath = $_.SourcePath
                        isMain = $_.SourcePath.Equals(
                            $mainImportedTabs[0].SourcePath,
                            [StringComparison]::OrdinalIgnoreCase)
                    }
                })
            importedTabCount = $importedTabs.Count
            chartManifest = $chartManifestEvidence
            primaryEvidencePath = $EvidencePath
            primaryEvidenceSha256 = (Get-FileHash -LiteralPath $EvidencePath -Algorithm SHA256).Hash
            interactionEvidencePath = $InteractionEvidencePath
            interactionEvidenceSha256 = (Get-FileHash -LiteralPath $InteractionEvidencePath -Algorithm SHA256).Hash
            importedSourcePath = $importedSourcePath
            structureSha256 = [string]$interaction.chart.structure.sha256
            sourceSha256 = [string]$interaction.chart.sourceSha256
            structuralEquivalence = if ($isOsuFreshImport) {
                $osuStructuralEquivalence
            } else { [ordered]@{
                preExportSessionStructureSha256 = $ExpectedStructureSha256
                workingBaseline = [ordered]@{
                    path = $expectedWorkingChartFullPath
                    sha256 = $expectedWorkingChartSha256
                }
                dirtyBeatProjection = [ordered]@{
                    jsonPointer = $expectedDirtyBeatPath
                    baselineBeat = $expectedDirtyBeatBefore
                    baselineAlreadySubmitted = $submittedBeatCandidates.Count -eq 1
                    submittedBeat = @(
                        [int]$ExpectedBeat.bar,
                        [int]$ExpectedBeat.numerator,
                        [int]$ExpectedBeat.denominator)
                    exactFreshMatchCount = $freshExactBeatMatchCount
                    originalFreshMatchCount = $freshOriginalBeatMatchCount
                }
                rawCompact = [ordered]@{
                    archiveMainEntry = [string]$freshArchiveEvidence.mainChartEntry.fullName
                    archiveMainEntryLength = [long]$freshArchiveEvidence.mainChartEntry.length
                    archiveMainEntrySha256 = [string]$freshArchiveEvidence.mainChartEntry.sha256
                    freshSourcePath = $importedSourcePath
                    freshSourceSha256 = $freshSourceSha256
                    freshEvidenceSourceSha256 = [string]$interaction.chart.sourceSha256
                    freshEvidenceStructureSha256 = [string]$interaction.chart.structure.sha256
                    allExact =
                        [string]$freshArchiveEvidence.mainChartEntry.sha256 -eq $ExpectedMainEntrySha256 -and
                        $freshSourceSha256 -eq $ExpectedMainEntrySha256 -and
                        [string]$interaction.chart.sourceSha256 -eq $ExpectedMainEntrySha256 -and
                        [string]$interaction.chart.structure.sha256 -eq $ExpectedMainEntrySha256
                }
                counts = [ordered]@{
                    expected = [ordered]@{
                        keyCount = $ExpectedKeyCount
                        noteCount = $ExpectedNoteCount
                        longNoteCount = $ExpectedLongNoteCount
                        timingCount = $ExpectedTimingCount
                    }
                    fresh = [ordered]@{
                        keyCount = [int]$interaction.chart.structure.keyCount
                        noteCount = [int]$interaction.chart.structure.noteCount
                        longNoteCount = [int]$interaction.chart.structure.longNoteCount
                        timingCount = [int]$interaction.chart.structure.timingCount
                    }
                }
                resourceReferenceNormalization = [ordered]@{
                    rule = 'WPF-compatible deterministic same-name resource collision suffix _2'
                    allowedJsonPointers = $allowedResourceDifferencePaths
                    differenceCountBefore = $differencesBeforeResourceNormalization.Count
                    differencesBefore = $differencesBeforeResourceNormalization
                    mappings = $resourceRenameMappings
                    differenceCountAfter = $differencesAfterResourceNormalization.Count
                    differencesAfter = $differencesAfterResourceNormalization
                    resourceBytesVerified = $resourceBytesVerified
                }
                verified = $freshVerified
            } }
            exactBeat = if ($isOsuFreshImport) { $null } else { [ordered]@{
                bar = [int]$ExpectedBeat.bar
                numerator = [int]$ExpectedBeat.numerator
                denominator = [int]$ExpectedBeat.denominator
                lane = $ExpectedLane
                exactMatchCount = $freshExactBeatMatchCount
                originalRepresentationMatchCount = $freshOriginalBeatMatchCount
                verified = $freshExactBeatMatchCount -eq 1 -and
                    $freshOriginalBeatMatchCount -eq 0
            } }
            archiveFormat = $ArchiveFormat
            sourceChartFormat = $SourceChartFormat
            crossFormat = $isCrossFormat
            osuImportModes = $osuImportModes
            cleanSession = -not [bool]$interaction.timeline.sessionIsDirty
            finalScreenshotPath = $FinalScreenshotPath
            finalScreenshotSha256 = (Get-FileHash -LiteralPath $FinalScreenshotPath -Algorithm SHA256).Hash
            workspaceTree = $workspaceTree
            normalExit = $normalExit
            sessionScratchRoot = $freshScratchRoot
            sessionScratchRemovedAfterExit = -not (Test-Path -LiteralPath $freshScratchRoot)
            verified = $freshVerified
        }
    }
    finally {
        if (-not $freshProcess.HasExited) {
            $freshProcess.CloseMainWindow() | Out-Null
            if (-not $freshProcess.WaitForExit(5000)) {
                $freshProcess.Kill($true)
                $freshProcess.WaitForExit(5000) | Out-Null
            }
        }
        $freshProcess.Dispose()
    }
}

function Invoke-OsuToMalodyFullPackageFreshImportEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$ApplicationPath,
        [Parameter(Mandatory = $true)][string]$SeedChartPath,
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$MainChartFileName,
        [Parameter(Mandatory = $true)]$ArchiveEvidence,
        [Parameter(Mandatory = $true)][string]$ExpectedWorkingChartPath,
        [Parameter(Mandatory = $true)][string]$ExpectedStructureSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedMainEntrySha256,
        [Parameter(Mandatory = $true)][int]$ExpectedKeyCount,
        [Parameter(Mandatory = $true)][int]$ExpectedNoteCount,
        [Parameter(Mandatory = $true)][int]$ExpectedLongNoteCount,
        [Parameter(Mandatory = $true)][int]$ExpectedTimingCount,
        [Parameter(Mandatory = $true)]$ExpectedBeat,
        [Parameter(Mandatory = $true)]$OriginalBeat,
        [Parameter(Mandatory = $true)][int]$OriginalLane,
        [Parameter(Mandatory = $true)][int]$ExpectedLane,
        [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$LocalDataRoot,
        [Parameter(Mandatory = $true)][string]$EditingRoot,
        [Parameter(Mandatory = $true)][string]$EvidencePath,
        [Parameter(Mandatory = $true)][string]$InteractionEvidencePath,
        [Parameter(Mandatory = $true)][string]$ImportDialogScreenshotPath,
        [Parameter(Mandatory = $true)][string]$FinalScreenshotPath
    )

    $sourceRootFullPath = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\')
    $archiveFullPath = [IO.Path]::GetFullPath($ArchivePath)
    $expectedWorkingChartFullPath = [IO.Path]::GetFullPath($ExpectedWorkingChartPath)
    if (-not (Test-Path -LiteralPath $sourceRootFullPath -PathType Container) -or
        -not (Test-Path -LiteralPath $archiveFullPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $expectedWorkingChartFullPath -PathType Leaf)) {
        throw "osu!-to-Malody fresh import is missing its isolated source, MCZ, or pre-export working baseline."
    }
    if ([int]$ArchiveEvidence.entryCount -ne 6 -or
        [int]$ArchiveEvidence.chartEntryCount -ne 1 -or
        -not [bool]$ArchiveEvidence.mainChartDynamicNameVerified -or
        -not ([string]$ArchiveEvidence.mainChartFileName).Equals(
            $MainChartFileName,
            [StringComparison]::Ordinal) -or
        -not [bool]$ArchiveEvidence.resourceChainsVerified -or
        -not [bool]$ArchiveEvidence.allSourceArtifactsExcluded) {
        throw "osu!-to-Malody fresh import preflight did not receive the proven six-entry archive manifest."
    }
    $sourceTreeBefore = Get-DirectoryTreeEvidence -Root $sourceRootFullPath
    $workingCacheRoot = [IO.Path]::GetDirectoryName($expectedWorkingChartFullPath)
    $workingTreeBefore = Get-DirectoryTreeEvidence -Root $workingCacheRoot
    $archiveItemBefore = Get-Item -LiteralPath $archiveFullPath
    $archiveBefore = [ordered]@{
        length = [long]$archiveItemBefore.Length
        lastWriteTimeUtc = $archiveItemBefore.LastWriteTimeUtc.ToString(
            'O',
            [Globalization.CultureInfo]::InvariantCulture)
        sha256 = (Get-FileHash -LiteralPath $archiveFullPath -Algorithm SHA256).Hash
    }

    foreach ($path in @($WorkspaceRoot, $LocalDataRoot, $EditingRoot)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        if (Get-ChildItem -LiteralPath $path -Force | Select-Object -First 1) {
            throw "osu!-to-Malody fresh import root must be empty: $path"
        }
    }
    foreach ($path in @(
            $EvidencePath,
            $InteractionEvidencePath,
            $ImportDialogScreenshotPath,
            $FinalScreenshotPath)) {
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($path)) -Force |
            Out-Null
        if (Test-Path -LiteralPath $path) {
            throw "osu!-to-Malody fresh import output already exists: $path"
        }
    }

    $cleanWorkingChart = Get-Content -LiteralPath $expectedWorkingChartFullPath -Raw |
        ConvertFrom-Json
    $baselineWorkingSemanticMap = ConvertTo-JsonSemanticMap -Value $cleanWorkingChart
    $workingOriginalMatches = [Collections.Generic.List[object]]::new()
    $workingSubmittedMatches = [Collections.Generic.List[object]]::new()
    for ($noteIndex = 0; $noteIndex -lt @($cleanWorkingChart.note).Count; $noteIndex++) {
        $candidate = $cleanWorkingChart.note[$noteIndex]
        if ($null -eq $candidate.column -or $null -eq $candidate.beat -or
            @($candidate.beat).Count -lt 3 -or $null -ne $candidate.endbeat) {
            continue
        }
        if ([int]$candidate.column -eq $OriginalLane -and
            [int]$candidate.beat[0] -eq [int]$OriginalBeat.bar -and
            [int]$candidate.beat[1] -eq [int]$OriginalBeat.numerator -and
            [int]$candidate.beat[2] -eq [int]$OriginalBeat.denominator) {
            $workingOriginalMatches.Add([ordered]@{ index = $noteIndex; note = $candidate }) |
                Out-Null
        }
        if ([int]$candidate.column -eq $ExpectedLane -and
            [int]$candidate.beat[0] -eq [int]$ExpectedBeat.bar -and
            [int]$candidate.beat[1] -eq [int]$ExpectedBeat.numerator -and
            [int]$candidate.beat[2] -eq [int]$ExpectedBeat.denominator) {
            $workingSubmittedMatches.Add([ordered]@{ index = $noteIndex; note = $candidate }) |
                Out-Null
        }
    }
    if ($workingOriginalMatches.Count -ne 1 -or $workingSubmittedMatches.Count -ne 0) {
        throw "Pre-export osu working MC did not expose exactly one lane-2 15:5/6 Tap and zero lane-3 15:10/12 Taps."
    }
    $dirtyTarget = $workingOriginalMatches[0]
    $dirtyTarget.note.beat = @(
        [int]$ExpectedBeat.bar,
        [int]$ExpectedBeat.numerator,
        [int]$ExpectedBeat.denominator)
    $dirtyTarget.note.column = $ExpectedLane
    $dirtyBeatPointer = "/note/$($dirtyTarget.index)/beat"
    $dirtyLanePointer = "/note/$($dirtyTarget.index)/column"
    $cleanWorkingChartSha256 =
        (Get-FileHash -LiteralPath $expectedWorkingChartFullPath -Algorithm SHA256).Hash

    $baselineAudioReference = [string]$cleanWorkingChart.meta.song.file
    $baselineBackgroundReference = [string]$cleanWorkingChart.meta.background
    $expectedPackagedAudioReference =
        [IO.Path]::GetFileNameWithoutExtension($baselineAudioReference) + '_2' +
        [IO.Path]::GetExtension($baselineAudioReference)
    $expectedPackagedBackgroundReference =
        [IO.Path]::GetFileNameWithoutExtension($baselineBackgroundReference) + '_2' +
        [IO.Path]::GetExtension($baselineBackgroundReference)
    if ([string]::IsNullOrWhiteSpace($baselineAudioReference) -or
        [string]::IsNullOrWhiteSpace($baselineBackgroundReference) -or
        -not ([string]$ArchiveEvidence.audioReference).Equals(
            $expectedPackagedAudioReference,
            [StringComparison]::Ordinal) -or
        -not ([string]$ArchiveEvidence.backgroundReference).Equals(
            $expectedPackagedBackgroundReference,
            [StringComparison]::Ordinal)) {
        throw "osu!-to-Malody archive did not expose the exact deterministic audio/background _2 references."
    }
    $baselineKeySoundIndices = @(
        for ($noteIndex = 0; $noteIndex -lt @($cleanWorkingChart.note).Count; $noteIndex++) {
            $soundReference = [string]$cleanWorkingChart.note[$noteIndex].sound
            if (-not [string]::IsNullOrWhiteSpace($soundReference) -and
                $soundReference.Equals(
                    $baselineAudioReference,
                    [StringComparison]::Ordinal)) {
                $noteIndex
            }
        })
    if ($baselineKeySoundIndices.Count -ne 1 -or
        [int]$baselineKeySoundIndices[0] -ne 2468) {
        throw "Trusted Michishirube working MC did not expose exactly one audio Key-sound reference at /note/2468/sound."
    }
    $baselineKeySoundIndex = [int]$baselineKeySoundIndices[0]
    $baselineKeySoundNode = $cleanWorkingChart.note[$baselineKeySoundIndex]
    $baselineKeySoundHasColumn =
        @($baselineKeySoundNode.PSObject.Properties.Name) -contains 'column'
    if (@($baselineKeySoundNode.beat).Count -ne 3 -or
        [int]$baselineKeySoundNode.beat[0] -ne 0 -or
        [int]$baselineKeySoundNode.beat[1] -ne 0 -or
        [int]$baselineKeySoundNode.beat[2] -ne 1 -or
        [int]$baselineKeySoundNode.type -ne 1 -or
        [int]$baselineKeySoundNode.offset -ne -1000 -or
        $baselineKeySoundHasColumn) {
        throw "Trusted Michishirube /note/2468/sound node did not retain beat [0,0,1], type 1, offset -1000, and no column."
    }
    $cleanWorkingChart.meta.song.file = $expectedPackagedAudioReference
    $cleanWorkingChart.meta.background = $expectedPackagedBackgroundReference
    $cleanWorkingChart.note[$baselineKeySoundIndex].sound = $expectedPackagedAudioReference
    $expectedDirtySemanticMap = ConvertTo-JsonSemanticMap -Value $cleanWorkingChart
    $expectedDirtySemanticSha256 = Get-JsonSemanticSha256 -Value $cleanWorkingChart
    $projectionDifferences = @(
        Compare-JsonSemanticMaps `
            -Expected $baselineWorkingSemanticMap `
            -Actual $expectedDirtySemanticMap)
    $expectedProjectionPaths = @(
        "$dirtyBeatPointer/1",
        "$dirtyBeatPointer/2",
        $dirtyLanePointer,
        '/meta/background',
        '/meta/song/file',
        "/note/$baselineKeySoundIndex/sound") | Sort-Object
    $actualProjectionPaths = @($projectionDifferences | Select-Object -ExpandProperty path |
        Sort-Object)
    if ($projectionDifferences.Count -ne 6 -or
        ($expectedProjectionPaths -join '|') -cne ($actualProjectionPaths -join '|')) {
        throw "osu!-to-Malody expected dirty projection was not limited to Beat numerator/denominator, lane, audio, background, and the unique /note/2468/sound Key-sound reference."
    }

    $start = [Diagnostics.ProcessStartInfo]::new($ApplicationPath)
    $start.UseShellExecute = $false
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $LocalDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $EditingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $WorkspaceRoot
    foreach ($argument in @(
            "--evidence-chart", $SeedChartPath,
            "--evidence-output", $EvidencePath,
            "--evidence-interaction-output", $InteractionEvidencePath,
            "--evidence-interaction-delay-ms", "30000",
            "--evidence-follow-active-tab",
            "--evidence-focus-note-property",
            "--evidence-focus-note-property-beat",
            ("{0}:{1}/{2}" -f
                [int]$ExpectedBeat.bar,
                [int]$ExpectedBeat.numerator,
                [int]$ExpectedBeat.denominator),
            "--evidence-file-picker-start-directory",
            [IO.Path]::GetDirectoryName($archiveFullPath))) {
        $start.ArgumentList.Add([string]$argument)
    }

    $freshProcess = [Diagnostics.Process]::Start($start)
    $freshScratchRoot = Join-Path $EditingRoot ("_scratch\session_{0}" -f $freshProcess.Id)
    $normalExit = $false
    try {
        $primaryDeadline = [DateTime]::UtcNow.AddSeconds(60)
        do {
            Start-Sleep -Milliseconds 150
            $freshProcess.Refresh()
        } while (-not $freshProcess.HasExited -and
                 ($freshProcess.MainWindowHandle -eq [IntPtr]::Zero -or
                  -not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) -and
                 [DateTime]::UtcNow -lt $primaryDeadline)
        if ($freshProcess.HasExited -or
            $freshProcess.MainWindowHandle -eq [IntPtr]::Zero -or
            -not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
            throw "Fresh osu!-to-Malody GUI did not expose its main window and primary evidence."
        }
        $primary = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
        $expectedPickerDirectory = [IO.Path]::GetDirectoryName($archiveFullPath)
        if (-not [bool]$primary.evidenceInteractionFollowsActiveTab -or
            -not [bool]$primary.evidenceFilePickerStartDirectoryInjected -or
            -not [IO.Path]::GetFullPath(
                [string]$primary.evidenceFilePickerStartDirectory).Equals(
                    $expectedPickerDirectory,
                    [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fresh osu!-to-Malody primary evidence did not enable active-tab follow and the exact picker directory."
        }

        Set-ForegroundWindowVerified -WindowHandle $freshProcess.MainWindowHandle
        $openButton = Find-AutomationElementByName `
            -TargetProcessId $freshProcess.Id `
            -Name "打开谱面" `
            -RootWindowHandle $freshProcess.MainWindowHandle `
            -TimeoutMilliseconds 6000
        Click-AutomationElementWithMouse -Element $openButton
        $openDialog = Find-AutomationElementByName `
            -TargetProcessId $freshProcess.Id `
            -Name "打开 Malody / osu! 谱面或谱包" `
            -TimeoutMilliseconds 7000
        $openDialogHandle = [IntPtr]$openDialog.Current.NativeWindowHandle
        if ($openDialogHandle -eq [IntPtr]::Zero) {
            throw "Fresh osu!-to-Malody native Open picker did not expose a window handle."
        }
        $openDirectoryNavigation = Get-NativeFilePickerAddressEvidence `
            -DialogElement $openDialog `
            -ExpectedDirectory $expectedPickerDirectory
        $requestedOpenFileName = [IO.Path]::GetFileName($archiveFullPath)
        $fileListDeadline = [DateTime]::UtcNow.AddSeconds(5)
        $fileListMatches = [Collections.Generic.List[object]]::new()
        do {
            $fileListMatches.Clear()
            $openControls = $openDialog.FindAll(
                [System.Windows.Automation.TreeScope]::Descendants,
                [System.Windows.Automation.Condition]::TrueCondition)
            for ($controlIndex = 0; $controlIndex -lt $openControls.Count; $controlIndex++) {
                $candidate = $openControls.Item($controlIndex)
                $bounds = $candidate.Current.BoundingRectangle
                if ([string]$candidate.Current.Name -ceq $requestedOpenFileName -and
                    [string]$candidate.Current.ClassName -eq 'UIItem' -and
                    $candidate.Current.ControlType -eq
                        [System.Windows.Automation.ControlType]::ListItem -and
                    [bool]$candidate.Current.IsEnabled -and
                    -not [bool]$candidate.Current.IsOffscreen -and
                    -not $bounds.IsEmpty) {
                    $fileListMatches.Add($candidate)
                }
            }
            if ($fileListMatches.Count -eq 1) { break }
            Start-Sleep -Milliseconds 100
        } while ([DateTime]::UtcNow -lt $fileListDeadline)
        if ($fileListMatches.Count -ne 1) {
            throw "Fresh osu!-to-Malody native Open picker did not expose one exact out.mcz file ListItem."
        }
        $fileListItem = $fileListMatches[0]
        Set-ForegroundWindowVerified -WindowHandle $openDialogHandle
        Click-AutomationElementWithMouse -Element $fileListItem
        Start-Sleep -Milliseconds 200
        $selectionPatternObject = $null
        if (-not $fileListItem.TryGetCurrentPattern(
                [System.Windows.Automation.SelectionItemPattern]::Pattern,
                [ref]$selectionPatternObject)) {
            throw "Fresh osu!-to-Malody out.mcz ListItem did not expose SelectionItemPattern."
        }
        $selectionPattern =
            [System.Windows.Automation.SelectionItemPattern]$selectionPatternObject
        if (-not [bool]$selectionPattern.Current.IsSelected) {
            throw "Fresh osu!-to-Malody out.mcz ListItem was not selected after its physical click."
        }
        $openIdCondition = [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
            '1')
        $openCandidates = $openDialog.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            $openIdCondition)
        $nativeOpenButtons = @(
            for ($openIndex = 0; $openIndex -lt $openCandidates.Count; $openIndex++) {
                $candidate = $openCandidates.Item($openIndex)
                $bounds = $candidate.Current.BoundingRectangle
                if ([string]$candidate.Current.ClassName -eq 'Button' -and
                    [string]$candidate.Current.Name -match '^打开|^Open' -and
                    [bool]$candidate.Current.IsEnabled -and
                    -not [bool]$candidate.Current.IsOffscreen -and
                    -not $bounds.IsEmpty) {
                    $candidate
                }
            })
        if ($nativeOpenButtons.Count -ne 1) {
            throw "Fresh osu!-to-Malody native picker did not expose one enabled Open button."
        }
        Click-AutomationElementWithMouse -Element $nativeOpenButtons[0]

        $importDialog = Find-AutomationElementByName `
            -TargetProcessId $freshProcess.Id `
            -Name "谱包已导入" `
            -TimeoutMilliseconds 10000
        $importDialogHandle = [IntPtr]$importDialog.Current.NativeWindowHandle
        $importDialogTitle = [string]$importDialog.Current.Name
        if ($importDialogHandle -eq [IntPtr]::Zero) {
            throw "Fresh osu!-to-Malody import preview did not expose a window handle."
        }
        Set-ForegroundWindowVerified -WindowHandle $importDialogHandle
        $dialogDescendants = $importDialog.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            [System.Windows.Automation.Condition]::TrueCondition)
        $dialogNames = @($dialogDescendants | ForEach-Object {
                try { [string]$_.Current.Name } catch { }
            } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique)
        $previewCountText = @($dialogNames | Where-Object {
                $_ -like '1 张键音谱可打开*' -and
                $_ -like '*0 张其他模式*' -and
                $_ -like '*0 张损坏*'
            } | Select-Object -First 1)
        if ($previewCountText.Count -ne 1) {
            throw "Fresh osu!-to-Malody preview did not report exactly one valid chart and zero failures."
        }
        Start-Sleep -Milliseconds 850
        if (-not [LumaChartAvaloniaCaptureNative]::IsWindow($importDialogHandle)) {
            throw "Fresh osu!-to-Malody preview disappeared during the render-settle window."
        }
        $importDialog = [System.Windows.Automation.AutomationElement]::FromHandle(
            $importDialogHandle)
        Save-AutomationElementScreenshot `
            -Element $importDialog `
            -Path $ImportDialogScreenshotPath
        $openImported = Find-AutomationElementByName `
            -TargetProcessId $freshProcess.Id `
            -Name '打开 1 张' `
            -RootWindowHandle $importDialogHandle `
            -TimeoutMilliseconds 6000
        Click-AutomationElementWithMouse -Element $openImported
        $importActionCompletedAt = [DateTimeOffset]::UtcNow

        Start-Sleep -Milliseconds 1200
        $unexpectedCalibration = $null
        try {
            $unexpectedCalibration = Find-AutomationElementById `
                -TargetProcessId $freshProcess.Id `
                -AutomationId 'OsuImportMode.Dialog' `
                -TimeoutMilliseconds 700
        }
        catch { }
        if ($null -ne $unexpectedCalibration) {
            throw "Fresh MCZ import unexpectedly opened an osu calibration dialog."
        }

        $chartTabCondition = [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
            'Editor.ChartTab')
        $workspaceBoundary = [IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\') + '\'
        $tabDeadline = [DateTime]::UtcNow.AddSeconds(15)
        $importedTabs = @()
        do {
            Start-Sleep -Milliseconds 180
            $freshProcess.Refresh()
            if ($freshProcess.HasExited) {
                throw "Fresh osu!-to-Malody GUI exited while its imported tab was being enumerated."
            }
            $mainRoot = [System.Windows.Automation.AutomationElement]::FromHandle(
                $freshProcess.MainWindowHandle)
            $tabPeers = $mainRoot.FindAll(
                [System.Windows.Automation.TreeScope]::Descendants,
                $chartTabCondition)
            $importedTabs = @($tabPeers | ForEach-Object {
                    try {
                        $source = [string]$_.Current.HelpText
                        if (-not [string]::IsNullOrWhiteSpace($source) -and
                            [IO.Path]::GetFullPath($source).StartsWith(
                                $workspaceBoundary,
                                [StringComparison]::OrdinalIgnoreCase)) {
                            [pscustomobject]@{
                                Element = $_
                                Name = [string]$_.Current.Name
                                SourcePath = [IO.Path]::GetFullPath($source)
                            }
                        }
                    }
                    catch { }
                })
        } while ($importedTabs.Count -lt 1 -and [DateTime]::UtcNow -lt $tabDeadline)
        if ($importedTabs.Count -ne 1 -or
            -not [IO.Path]::GetFileName($importedTabs[0].SourcePath).Equals(
                $MainChartFileName,
                [StringComparison]::Ordinal)) {
            throw "Fresh osu!-to-Malody GUI did not expose exactly one dynamic-main imported tab."
        }
        Click-AutomationElementWithMouse -Element $importedTabs[0].Element

        $interactionDeadline = [DateTime]::UtcNow.AddSeconds(40)
        while (-not (Test-Path -LiteralPath $InteractionEvidencePath -PathType Leaf) -and
               -not $freshProcess.HasExited -and
               [DateTime]::UtcNow -lt $interactionDeadline) {
            Start-Sleep -Milliseconds 150
            $freshProcess.Refresh()
        }
        if (-not (Test-Path -LiteralPath $InteractionEvidencePath -PathType Leaf)) {
            throw "Fresh osu!-to-Malody GUI did not write post-import interaction evidence."
        }
        $interaction = Get-Content -LiteralPath $InteractionEvidencePath -Raw |
            ConvertFrom-Json
        $interactionGenerated = [DateTimeOffset]::Parse(
            [string]$interaction.generatedAtUtc,
            [Globalization.CultureInfo]::InvariantCulture)
        $importedSourcePath = [IO.Path]::GetFullPath([string]$interaction.chart.sourcePath)
        if (-not $importedSourcePath.Equals(
                $importedTabs[0].SourcePath,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fresh osu!-to-Malody interaction evidence did not follow the imported main tab."
        }

        $extractionRoot = [IO.Path]::GetDirectoryName($importedSourcePath)
        $expectedExtractionRoot = [IO.Path]::GetFullPath(
            (Join-Path $WorkspaceRoot ([IO.Path]::GetFileNameWithoutExtension($archiveFullPath))))
        if (-not [IO.Path]::GetFullPath($extractionRoot).Equals(
                $expectedExtractionRoot,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fresh osu!-to-Malody extraction root was not the exact workspace/out directory."
        }
        $freshTree = Get-DirectoryTreeEvidence -Root $extractionRoot
        $archiveRows = @($ArchiveEvidence.entries | ForEach-Object {
                [pscustomobject][ordered]@{
                    relativePath = [string]$_.fullName
                    length = [long]$_.length
                    sha256 = [string]$_.sha256
                }
            } | Sort-Object relativePath)
        $freshRows = @($freshTree.files | ForEach-Object {
                [pscustomobject][ordered]@{
                    relativePath = [string]$_.relativePath
                    length = [long]$_.length
                    sha256 = [string]$_.sha256
                }
            } | Sort-Object relativePath)
        $freshChildDirectories = @(Get-ChildItem -LiteralPath $extractionRoot -Recurse -Directory -Force)
        $archiveFreshTreeExact = $archiveRows.Count -eq 6 -and
            $freshRows.Count -eq 6 -and
            $freshChildDirectories.Count -eq 0 -and
            (Get-ContentManifestSha256 -Rows $archiveRows) -ceq
                (Get-ContentManifestSha256 -Rows $freshRows) -and
            (($archiveRows | ConvertTo-Json -Depth 4 -Compress) -ceq
             ($freshRows | ConvertTo-Json -Depth 4 -Compress))
        if (-not $archiveFreshTreeExact) {
            throw "Fresh osu!-to-Malody extraction was not the exact flat six-entry archive byte tree."
        }

        $freshMainSha256 = (Get-FileHash -LiteralPath $importedSourcePath -Algorithm SHA256).Hash
        $freshMainChart = Get-Content -LiteralPath $importedSourcePath -Raw | ConvertFrom-Json
        $freshSemanticMap = ConvertTo-JsonSemanticMap -Value $freshMainChart
        $semanticDifferences = @(
            Compare-JsonSemanticMaps `
                -Expected $expectedDirtySemanticMap `
                -Actual $freshSemanticMap)
        $freshSemanticSha256 = Get-JsonSemanticSha256 -Value $freshMainChart
        if ($semanticDifferences.Count -ne 0 -or
            $freshSemanticSha256 -cne $expectedDirtySemanticSha256) {
            throw "Fresh osu!-to-Malody main MC was not semantically identical to the dirty working projection after deterministic resource normalization."
        }

        $freshPlayableNotes = @($freshMainChart.note | Where-Object {
                $null -ne $_.column -and $null -ne $_.beat -and @($_.beat).Count -ge 3
            })
        $freshExactTargetCount = @($freshPlayableNotes | Where-Object {
                [int]$_.column -eq $ExpectedLane -and $null -eq $_.endbeat -and
                [int]$_.beat[0] -eq [int]$ExpectedBeat.bar -and
                [int]$_.beat[1] -eq [int]$ExpectedBeat.numerator -and
                [int]$_.beat[2] -eq [int]$ExpectedBeat.denominator
            }).Count
        $freshOriginalTargetCount = @($freshPlayableNotes | Where-Object {
                [int]$_.column -eq $OriginalLane -and $null -eq $_.endbeat -and
                [int]$_.beat[0] -eq [int]$OriginalBeat.bar -and
                [int]$_.beat[1] -eq [int]$OriginalBeat.numerator -and
                [int]$_.beat[2] -eq [int]$OriginalBeat.denominator
            }).Count
        $selectedNotes = @($interaction.timeline.selectedNotes)
        $targetNavigationVerified = $selectedNotes.Count -eq 1 -and
            [int]$selectedNotes[0].lane -eq $ExpectedLane -and
            [int]$selectedNotes[0].beat.bar -eq [int]$ExpectedBeat.bar -and
            [int]$selectedNotes[0].beat.numerator -eq [int]$ExpectedBeat.numerator -and
            [int]$selectedNotes[0].beat.denominator -eq [int]$ExpectedBeat.denominator -and
            [Math]::Abs(
                [double]$interaction.timeline.currentBeat -
                ([double]$ExpectedBeat.bar +
                 ([double]$ExpectedBeat.numerator / [double]$ExpectedBeat.denominator))) -le .000001

        $freshResourceChains = @($ArchiveEvidence.resourceChains | ForEach-Object {
                $chain = $_
                $freshEntries = @($chain.archiveEntries | ForEach-Object {
                        $archiveResourceEntry = $_
                        $freshPath = Join-Path $extractionRoot ([string]$archiveResourceEntry.relativePath)
                        [ordered]@{
                            relativePath = [string]$archiveResourceEntry.relativePath
                            path = $freshPath
                            exists = Test-Path -LiteralPath $freshPath -PathType Leaf
                            length = if (Test-Path -LiteralPath $freshPath -PathType Leaf) {
                                [long](Get-Item -LiteralPath $freshPath).Length
                            } else { $null }
                            sha256 = if (Test-Path -LiteralPath $freshPath -PathType Leaf) {
                                (Get-FileHash -LiteralPath $freshPath -Algorithm SHA256).Hash
                            } else { $null }
                            exact = (Test-Path -LiteralPath $freshPath -PathType Leaf) -and
                                [long](Get-Item -LiteralPath $freshPath).Length -eq
                                    [long]$archiveResourceEntry.length -and
                                (Get-FileHash -LiteralPath $freshPath -Algorithm SHA256).Hash -ceq
                                    [string]$archiveResourceEntry.sha256
                        }
                    })
                [pscustomobject][ordered]@{
                    sourceName = [string]$chain.sourceName
                    sourceSha256 = [string]$chain.sourceSha256
                    entries = $freshEntries
                    exact = $freshEntries.Count -ge 1 -and
                        @($freshEntries | Where-Object { -not [bool]$_.exact }).Count -eq 0
                }
            })
        $freshResourcesVerified = $freshResourceChains.Count -ge 3 -and
            @($freshResourceChains | Where-Object { -not [bool]$_.exact }).Count -eq 0
        $sourceTreeAfter = Get-DirectoryTreeEvidence -Root $sourceRootFullPath
        $workingTreeAfter = Get-DirectoryTreeEvidence -Root $workingCacheRoot
        $archiveItemAfter = Get-Item -LiteralPath $archiveFullPath
        $archiveAfter = [ordered]@{
            length = [long]$archiveItemAfter.Length
            lastWriteTimeUtc = $archiveItemAfter.LastWriteTimeUtc.ToString(
                'O',
                [Globalization.CultureInfo]::InvariantCulture)
            sha256 = (Get-FileHash -LiteralPath $archiveFullPath -Algorithm SHA256).Hash
        }
        $sourceTreeUnchanged = Test-DirectoryTreeEvidenceEqual `
            -Before $sourceTreeBefore `
            -After $sourceTreeAfter
        $workingTreeUnchanged = Test-DirectoryTreeEvidenceEqual `
            -Before $workingTreeBefore `
            -After $workingTreeAfter
        $archiveUnchanged =
            [long]$archiveBefore.length -eq [long]$archiveAfter.length -and
            [string]$archiveBefore.lastWriteTimeUtc -ceq [string]$archiveAfter.lastWriteTimeUtc -and
            [string]$archiveBefore.sha256 -ceq [string]$archiveAfter.sha256

        $freshVerified =
            $interactionGenerated -ge $importActionCompletedAt -and
            [bool]$interaction.evidenceInteractionFollowsActiveTab -and
            [bool]$interaction.evidenceFilePickerStartDirectoryInjected -and
            $freshMainSha256 -ceq $ExpectedMainEntrySha256 -and
            [string]$interaction.chart.sourceSha256 -ceq $ExpectedMainEntrySha256 -and
            [string]$interaction.chart.structure.sha256 -ceq $ExpectedMainEntrySha256 -and
            [int]$interaction.chart.structure.keyCount -eq $ExpectedKeyCount -and
            [int]$interaction.chart.structure.noteCount -eq $ExpectedNoteCount -and
            [int]$interaction.chart.structure.longNoteCount -eq $ExpectedLongNoteCount -and
            [int]$interaction.chart.structure.timingCount -eq $ExpectedTimingCount -and
            [int]$ArchiveEvidence.serializedTimingAndEffectCount -eq $ExpectedTimingCount -and
            $freshExactTargetCount -eq 1 -and
            $freshOriginalTargetCount -eq 0 -and
            $archiveFreshTreeExact -and
            $freshResourcesVerified -and
            $sourceTreeUnchanged -and
            $workingTreeUnchanged -and
            $archiveUnchanged -and
            $targetNavigationVerified -and
            -not [bool]$interaction.timeline.sessionIsDirty -and
            [long]$interaction.timeline.sessionChangeSerial -eq 0
        if (-not $freshVerified) {
            throw "Fresh osu!-to-Malody GUI did not preserve exact archive bytes, full timing/effect structure, resources, target Beat/lane, clean state, and target-note navigation."
        }

        Set-ForegroundWindowVerified -WindowHandle $freshProcess.MainWindowHandle
        Start-Sleep -Milliseconds 850
        $freshProcess.Refresh()
        if ($freshProcess.MainWindowHandle -eq [IntPtr]::Zero -or
            -not [LumaChartAvaloniaCaptureNative]::IsWindow($freshProcess.MainWindowHandle)) {
            throw "Fresh osu!-to-Malody main window disappeared during the target-note render-settle window."
        }
        $freshRootElement = [System.Windows.Automation.AutomationElement]::FromHandle(
            $freshProcess.MainWindowHandle)
        Save-AutomationElementScreenshot `
            -Element $freshRootElement `
            -Path $FinalScreenshotPath `
            -Padding 0
        $workspaceTree = Get-DirectoryTreeEvidence -Root $WorkspaceRoot

        $freshProcess.CloseMainWindow() | Out-Null
        if (-not $freshProcess.WaitForExit(12000)) {
            throw "Fresh osu!-to-Malody GUI did not exit normally."
        }
        $freshExitCode = $freshProcess.ExitCode
        if ($freshExitCode -ne 0) {
            throw "Fresh osu!-to-Malody GUI exited with code $freshExitCode."
        }
        $normalExit = $true
        $freshTreeAfterExit = Get-DirectoryTreeEvidence -Root $extractionRoot
        $freshRowsAfterExit = @($freshTreeAfterExit.files | ForEach-Object {
                [pscustomobject][ordered]@{
                    relativePath = [string]$_.relativePath
                    length = [long]$_.length
                    sha256 = [string]$_.sha256
                }
            } | Sort-Object relativePath)
        $freshChildDirectoriesAfterExit = @(
            Get-ChildItem -LiteralPath $extractionRoot -Recurse -Directory -Force)
        $archiveFreshTreeExactAfterExit = $archiveRows.Count -eq 6 -and
            $freshRowsAfterExit.Count -eq 6 -and
            $freshChildDirectoriesAfterExit.Count -eq 0 -and
            (Get-ContentManifestSha256 -Rows $archiveRows) -ceq
                (Get-ContentManifestSha256 -Rows $freshRowsAfterExit) -and
            (($archiveRows | ConvertTo-Json -Depth 4 -Compress) -ceq
             ($freshRowsAfterExit | ConvertTo-Json -Depth 4 -Compress))
        if (-not $archiveFreshTreeExactAfterExit) {
            throw "Fresh osu!-to-Malody shutdown changed the exact flat six-entry extracted archive byte tree."
        }
        $workspaceTreeAfterExit = Get-DirectoryTreeEvidence -Root $WorkspaceRoot
        $sourceTreeAfterExit = Get-DirectoryTreeEvidence -Root $sourceRootFullPath
        $workingTreeAfterExit = Get-DirectoryTreeEvidence -Root $workingCacheRoot
        $archiveItemAfterExit = Get-Item -LiteralPath $archiveFullPath
        $archiveAfterExit = [ordered]@{
            length = [long]$archiveItemAfterExit.Length
            lastWriteTimeUtc = $archiveItemAfterExit.LastWriteTimeUtc.ToString(
                'O',
                [Globalization.CultureInfo]::InvariantCulture)
            sha256 = (Get-FileHash -LiteralPath $archiveFullPath -Algorithm SHA256).Hash
        }
        $sourceTreeUnchangedAfterExit = Test-DirectoryTreeEvidenceEqual `
            -Before $sourceTreeBefore `
            -After $sourceTreeAfterExit
        $workingTreeUnchangedAfterExit = Test-DirectoryTreeEvidenceEqual `
            -Before $workingTreeBefore `
            -After $workingTreeAfterExit
        $archiveUnchangedAfterExit =
            [long]$archiveBefore.length -eq [long]$archiveAfterExit.length -and
            [string]$archiveBefore.lastWriteTimeUtc -ceq
                [string]$archiveAfterExit.lastWriteTimeUtc -and
            [string]$archiveBefore.sha256 -ceq [string]$archiveAfterExit.sha256
        if (-not $sourceTreeUnchangedAfterExit -or
            -not $workingTreeUnchangedAfterExit -or
            -not $archiveUnchangedAfterExit) {
            throw "Fresh osu!-to-Malody shutdown changed the isolated source tree, pre-export working/cache tree, or exported MCZ."
        }
        $freshVerified = $freshVerified -and
            $archiveFreshTreeExactAfterExit -and
            $sourceTreeUnchangedAfterExit -and
            $workingTreeUnchangedAfterExit -and
            $archiveUnchangedAfterExit
        if (Test-Path -LiteralPath $freshScratchRoot) {
            throw "Fresh osu!-to-Malody GUI left its session scratch root after normal exit."
        }
        return [ordered]@{
            processId = $freshProcess.Id
            archiveFormat = 'Malody'
            sourceChartFormat = 'OsuMania'
            crossFormat = $true
            dynamicMainChartFileName = $MainChartFileName
            nativeOpen = [ordered]@{
                title = $openDialogTitle
                requestedPath = $archiveFullPath
                startDirectory = $openDirectoryNavigation
                selectedFileName = $requestedOpenFileName
                fileListPhysicalClick = $true
                selectionItemPatternVerified = $true
                openButtonPhysicalClick = $true
                keyboardInputUsed = $false
                imeCommitRequired = $false
                clipboardUsed = $false
                valueInjectionUsed = $false
            }
            preview = [ordered]@{
                title = $importDialogTitle
                countText = [string]$previewCountText[0]
                validChartCount = 1
                otherModeCount = 0
                corruptCount = 0
                screenshotPath = $ImportDialogScreenshotPath
                screenshotSha256 = (Get-FileHash -LiteralPath $ImportDialogScreenshotPath -Algorithm SHA256).Hash
            }
            osuCalibration = [ordered]@{
                expected = $false
                observedCount = 0
                verifiedAbsent = $true
            }
            importedTabCount = $importedTabs.Count
            importedTabs = @($importedTabs | ForEach-Object {
                    [ordered]@{ name = $_.Name; sourcePath = $_.SourcePath; isMain = $true }
                })
            primaryEvidencePath = $EvidencePath
            primaryEvidenceSha256 = (Get-FileHash -LiteralPath $EvidencePath -Algorithm SHA256).Hash
            interactionEvidencePath = $InteractionEvidencePath
            interactionEvidenceSha256 =
                (Get-FileHash -LiteralPath $InteractionEvidencePath -Algorithm SHA256).Hash
            importedSourcePath = $importedSourcePath
            importedSourceSha256 = $freshMainSha256
            archiveFreshTree = [ordered]@{
                archiveEntryCount = $archiveRows.Count
                archiveContentSha256 = Get-ContentManifestSha256 -Rows $archiveRows
                preExit = [ordered]@{
                    freshFileCount = $freshRows.Count
                    freshDirectoryCount = $freshChildDirectories.Count
                    freshContentSha256 = Get-ContentManifestSha256 -Rows $freshRows
                    exact = $archiveFreshTreeExact
                }
                afterExit = [ordered]@{
                    freshFileCount = $freshRowsAfterExit.Count
                    freshDirectoryCount = $freshChildDirectoriesAfterExit.Count
                    freshContentSha256 = Get-ContentManifestSha256 -Rows $freshRowsAfterExit
                    exact = $archiveFreshTreeExactAfterExit
                }
                sampledAfterFreshProcessExit = $true
                exact = $archiveFreshTreeExact -and $archiveFreshTreeExactAfterExit
            }
            structuralEquivalence = [ordered]@{
                preExportSessionStructureSha256 = $ExpectedStructureSha256
                preExportStructureTraceMeaning =
                    'normalization-before: dirty session still references original source resource leaves'
                archiveStructureTraceMeaning =
                    'normalization-after: compact MC references deterministic packaged _2 resource leaves'
                workingBaseline = [ordered]@{
                    path = $expectedWorkingChartFullPath
                    sha256 = $cleanWorkingChartSha256
                }
                expectedDirtySemanticSha256 = $expectedDirtySemanticSha256
                projectionDifferenceCount = $projectionDifferences.Count
                projectionDifferences = $projectionDifferences
                freshSemanticSha256 = $freshSemanticSha256
                semanticDifferenceCount = $semanticDifferences.Count
                semanticDifferences = $semanticDifferences
                counts = [ordered]@{
                    expected = [ordered]@{
                        keyCount = $ExpectedKeyCount
                        noteCount = $ExpectedNoteCount
                        longNoteCount = $ExpectedLongNoteCount
                        timingCount = $ExpectedTimingCount
                        serializedTimingCount = 2
                        serializedEffectCount = 11
                    }
                    fresh = [ordered]@{
                        keyCount = [int]$interaction.chart.structure.keyCount
                        noteCount = [int]$interaction.chart.structure.noteCount
                        longNoteCount = [int]$interaction.chart.structure.longNoteCount
                        timingCount = [int]$interaction.chart.structure.timingCount
                        serializedTimingCount = @($freshMainChart.time).Count
                        serializedEffectCount = @($freshMainChart.effect).Count
                    }
                }
                verified = $freshVerified
            }
            dirtyProjection = [ordered]@{
                beatJsonPointer = $dirtyBeatPointer
                laneJsonPointer = $dirtyLanePointer
                originalBeat = @(
                    [int]$OriginalBeat.bar,
                    [int]$OriginalBeat.numerator,
                    [int]$OriginalBeat.denominator)
                expectedBeat = @(
                    [int]$ExpectedBeat.bar,
                    [int]$ExpectedBeat.numerator,
                    [int]$ExpectedBeat.denominator)
                originalLane = $OriginalLane
                expectedLane = $ExpectedLane
                exactFreshMatchCount = $freshExactTargetCount
                originalFreshMatchCount = $freshOriginalTargetCount
                deliberatelyNonReduced =
                    (Get-IntegerGreatestCommonDivisor `
                        -Left ([int]$ExpectedBeat.numerator) `
                        -Right ([int]$ExpectedBeat.denominator)) -gt 1
                verified = $freshExactTargetCount -eq 1 -and
                    $freshOriginalTargetCount -eq 0
            }
            targetNavigation = [ordered]@{
                selectedNotes = $selectedNotes
                currentBeat = [double]$interaction.timeline.currentBeat
                verified = $targetNavigationVerified
            }
            resources = [ordered]@{
                baselineAudioReference = $baselineAudioReference
                packagedAudioReference = $expectedPackagedAudioReference
                baselineBackgroundReference = $baselineBackgroundReference
                packagedBackgroundReference = $expectedPackagedBackgroundReference
                keySoundJsonPointer = "/note/$baselineKeySoundIndex/sound"
                keySoundBaselineReference = $baselineAudioReference
                keySoundPackagedReference = $expectedPackagedAudioReference
                keySoundBeat = @($baselineKeySoundNode.beat)
                keySoundType = [int]$baselineKeySoundNode.type
                keySoundOffset = [int]$baselineKeySoundNode.offset
                keySoundHasColumnProperty = $baselineKeySoundHasColumn
                keySoundNodeVerified = [bool]$ArchiveEvidence.keySoundNodeVerified
                chains = $freshResourceChains
                verified = $freshResourcesVerified
            }
            preservation = [ordered]@{
                sourceTreeBefore = $sourceTreeBefore
                sourceTreeBeforeFreshProcessExit = $sourceTreeAfter
                sourceTreeUnchangedBeforeFreshProcessExit = $sourceTreeUnchanged
                sourceTreeAfterFreshProcessExit = $sourceTreeAfterExit
                sourceTreeUnchangedByFreshProcessExit = $sourceTreeUnchangedAfterExit
                workingTreeBefore = $workingTreeBefore
                workingTreeBeforeFreshProcessExit = $workingTreeAfter
                workingTreeUnchangedBeforeFreshProcessExit = $workingTreeUnchanged
                workingTreeAfterFreshProcessExit = $workingTreeAfterExit
                workingTreeUnchangedByFreshProcessExit = $workingTreeUnchangedAfterExit
                archiveBefore = $archiveBefore
                archiveBeforeFreshProcessExit = $archiveAfter
                archiveUnchangedBeforeFreshProcessExit = $archiveUnchanged
                archiveAfterFreshProcessExit = $archiveAfterExit
                archiveUnchangedByFreshProcessExit = $archiveUnchangedAfterExit
                sampledAfterFreshProcessExit = $true
            }
            cleanSession = -not [bool]$interaction.timeline.sessionIsDirty
            finalScreenshotPath = $FinalScreenshotPath
            finalScreenshotSha256 =
                (Get-FileHash -LiteralPath $FinalScreenshotPath -Algorithm SHA256).Hash
            workspaceTreePreExit = $workspaceTree
            workspaceTreeAfterExit = $workspaceTreeAfterExit
            normalExit = $normalExit
            exitCode = $freshExitCode
            sessionScratchRoot = $freshScratchRoot
            sessionScratchRemovedAfterExit = -not (Test-Path -LiteralPath $freshScratchRoot)
            verified = $freshVerified
        }
    }
    finally {
        if (-not $freshProcess.HasExited) {
            $freshProcess.CloseMainWindow() | Out-Null
            if (-not $freshProcess.WaitForExit(5000)) {
                $freshProcess.Kill($true)
                $freshProcess.WaitForExit(5000) | Out-Null
            }
        }
        $freshProcess.Dispose()
    }
}

function Get-AudioPanelControlEvidence {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    $controls = [ordered]@{}
    foreach ($automationId in @(
            "Audio.WaveformMode",
            "Audio.WaveformCollapse",
            "Audio.SpectrogramMode",
            "Audio.SpectrogramCollapse")) {
        $observation = Get-AutomationElementObservation `
            -TargetProcessId $TargetProcessId `
            -AutomationId $automationId `
            -RootWindowHandle $RootWindowHandle
        $controls[$automationId] = $observation.Evidence
    }
    return $controls
}

function Get-AudioPanelFastObservation {
    param(
        [Parameter(Mandatory = $true)][int]$TargetProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    $element = Find-AutomationElementById `
        -TargetProcessId $TargetProcessId `
        -AutomationId $AutomationId `
        -RootWindowHandle $RootWindowHandle
    $bounds = $element.Current.BoundingRectangle
    if ($element.Current.IsOffscreen -or $bounds.IsEmpty -or $bounds.Width -le 1 -or $bounds.Height -le 1) {
        throw "Audio-panel UI Automation id '$AutomationId' is offscreen or has invalid bounds."
    }
    return [pscustomobject]@{
        Element = $element
        Evidence = [ordered]@{
            automationId = $AutomationId
            name = [string]$element.Current.Name
            controlType = [string]$element.Current.ControlType.ProgrammaticName
            isEnabled = [bool]$element.Current.IsEnabled
            isOffscreen = [bool]$element.Current.IsOffscreen
            bounds = [ordered]@{
                left = [double]$bounds.Left
                top = [double]$bounds.Top
                width = [double]$bounds.Width
                height = [double]$bounds.Height
            }
        }
    }
}

function Convert-AudioPanelUiState {
    param([Parameter(Mandatory = $true)]$Controls)

    $readMode = {
        param([string]$Name)
        if ($Name -eq "背") { return "Side" }
        if ($Name -eq "侧") { return "Background" }
        return "Unknown"
    }
    $readCollapsed = {
        param([string]$Name)
        if ($Name -eq "+") { return $true }
        if ($Name -eq "—" -or $Name -eq "-") { return $false }
        return $null
    }

    return [ordered]@{
        waveform = [ordered]@{
            mode = & $readMode ([string]$Controls["Audio.WaveformMode"].name)
            collapsed = & $readCollapsed ([string]$Controls["Audio.WaveformCollapse"].name)
            modeButtonBounds = $Controls["Audio.WaveformMode"].bounds
            collapseButtonBounds = $Controls["Audio.WaveformCollapse"].bounds
        }
        spectrogram = [ordered]@{
            mode = & $readMode ([string]$Controls["Audio.SpectrogramMode"].name)
            collapsed = & $readCollapsed ([string]$Controls["Audio.SpectrogramCollapse"].name)
            modeButtonBounds = $Controls["Audio.SpectrogramMode"].bounds
            collapseButtonBounds = $Controls["Audio.SpectrogramCollapse"].bounds
        }
    }
}

$malodyFullPackageSourceTreeBefore = if ($fullPackageExportExerciseEnabled) {
    Get-DirectoryTreeEvidence -Root $malodyFullPackageSourceRootFullPath
} else { $null }
if ($fullPackageExportExerciseEnabled) {
    $expectedSourceChartExtension = if ($sourceOsuFullPackage) { ".osu" } else { ".mc" }
    $sourceChartCount = @(
        $malodyFullPackageSourceTreeBefore.files |
            Where-Object { [IO.Path]::GetExtension([string]$_.relativePath).Equals(
                    $expectedSourceChartExtension,
                    [StringComparison]::OrdinalIgnoreCase) }).Count
    if (-not $crossFormatFullPackage -and
        $sourceChartCount -ne $selectedFullPackageExpectedChartCount) {
        throw "Isolated FullPackage source tree contains $sourceChartCount $expectedSourceChartExtension files; " +
              "$selectedFullPackageExpectedChartCount were required."
    }
    if ($malodyToOsuFullPackage -and $sourceChartCount -lt 2) {
        throw "Isolated Malody-to-osu! source tree must contain the trusted main MC plus at least one excluded MC decoy."
    }
    if ($osuToMalodyFullPackage -and $sourceChartCount -lt 2) {
        throw "Isolated osu!-to-Malody source tree must contain the trusted main osu plus at least one excluded osu sibling."
    }
}

[LumaChartAvaloniaCaptureNative]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
$process = [Diagnostics.Process]::Start($processStart)
$libraryNoResultsExercised = $false
$libraryNoResultsEvidence = $null
$libraryDeletionExercised = $false
$libraryDeletionAction = $null
$libraryDeletionInteractionRuntimeEvidence = $null
$libraryDeleteTargetExistedBefore = if ($libraryDeleteTargetFullPath) {
    Test-Path -LiteralPath $libraryDeleteTargetFullPath -PathType Container
} else { $null }
$libraryDeleteSecondTargetExistedBefore = if ($libraryDeleteSecondTargetFullPath) {
    Test-Path -LiteralPath $libraryDeleteSecondTargetFullPath -PathType Container
} else { $null }
$libraryDeleteTargetExistsAfter = $null
$libraryDeleteSecondTargetExistsAfter = $null
$libraryContextMenuScreenshotSha256 = $null
$libraryDeleteDialogScreenshotSha256 = $null
$chartValidationExercised = $false
$chartValidationAction = $null
$chartValidationInteractionRuntimeEvidence = $null
$chartValidationManualDialogScreenshotSha256 = $null
$chartValidationSaveBlockedDialogScreenshotSha256 = $null
$chartValidationSourceAfter = $null
$chartExportModesExercised = $false
$chartExportModesEvidence = $null
$chartExportModesDefaultScreenshotSha256 = $null
$chartExportModesSingleChartScreenshotSha256 = $null
$chartExportModesSingleRateScreenshotSha256 = $null
$chartExportModesRatePackScreenshotSha256 = $null
$chartExportModesHiddenValidationScreenshotSha256 = $null
$chartExportModesCancelScreenshotSha256 = $null
$chartExportModesOverwriteScreenshotSha256 = $null
$edgeScrollExercised = $false
$holdTailResizeExercised = $false
$longToTapExercised = $false
$notePropertyExercised = $false
$notePropertySaved = $false
$notePropertyPhysicalActions = [Collections.Generic.List[object]]::new()
$sourceSaveFailureAction = $null
$sourceSaveFailureDialogScreenshotSha256 = $null
$groupAssignExercised = $false
$groupAssignSaved = $false
$groupVisibilityExercised = $false
$groupPlacementExercised = $false
$groupVisibilityAutomationFallbackUsed = $false
$groupPlacementHideAutomationFallbackUsed = $false
$proEditorPanExercised = $false
$proEditorRevealExercised = $false
$proEditorEditExercised = $false
$proEditorEditSaved = $false
$proEditorSaveAsOsuExercised = $false
$proEditorActivationEvidence = $null
$proEditorSaveAsInitialDirectoryVerified = $false
$proEditorSaveAsVisibleSourceName = $null
$malodyFullPackageExportExercised = $false
$malodyFullPackageDirtyInjection = $null
$malodyFullPackageOptionsEvidence = $null
$malodyFullPackageNativeSaveEvidence = $null
$malodyFullPackageResultEvidence = $null
$malodyFullPackageOptionsScreenshotSha256 = $null
$malodyFullPackageResultScreenshotSha256 = $null
$malodyFullPackageWorkingTreeAfterDirty = $null
$malodyFullPackageWorkingTreeAfterExport = $null
$malodyFullPackageWorkingTreeUnchangedByExport = $null
$malodyFullPackageSourceTreeAfter = $null
$malodyFullPackageSourceTreeUnchanged = $null
$malodyFullPackageArchiveEvidence = $null
$malodyFullPackageScratchRoot = if ($fullPackageExportExerciseEnabled) {
    Join-Path $editingFullPath ("_scratch\session_{0}" -f $process.Id)
} else { $null }
$malodyFullPackageScratchExportsAfter = $null
$malodyFullPackageInteractionRuntime = $null
$malodyFullPackageFreshImportEvidence = $null
$malodyFullPackageMainProcessNormalExit = $false
$malodyFullPackageMainScratchRemovedAfterExit = $null
$malodyFullPackageCloseEvidence = $null
$malodyFullPackageCleanWorkingChart = $null
$malodyFullPackageCleanWorkingSemanticMap = $null
$malodyFullPackageCleanWorkingCacheTree = $null
$malodyFullPackageCleanWorkingContract = $null
$malodyFullPackageArchiveBeforeMainExit = $null
$malodyFullPackageFinalStateAfterMainProcessExit = $null
$keySoundRuntimeExercised = $false
$keySoundControlEvidence = $null
$keySoundSubmittedSettings = $null
$keySoundPreviewCompleted = $false
$keySoundPlayCompleted = $false
$keySoundStopCompleted = $false
$keySoundSourceMode = $null
$keySoundToggleAutomationFallbackUsed = $false
$displayScaleExercised = $false
$displayScaleControlEvidence = $null
$displayScaleRequestedValues = if ($FocusDisplayScale) {
    [ordered]@{
        uiPercent = $DisplayScaleUiPercent
        fontPercent = $DisplayScaleFontPercent
    }
} else { $null }
$displayScaleActualValues = $null
$displayScalePointerEvidence = $null
$displayScaleAutomationFallbackUsed = $false
$displayScaleDebounceWaitMilliseconds = 750
$displayScaleRuntimeWindowEvidence = $null
$audioPanelsExercised = $false
$audioPanelInitialControls = $null
$audioPanelFinalControls = $null
$audioPanelInitialState = $null
$audioPanelFinalState = $null
$audioPanelActions = $null
$audioPanelAutomationFallbackUsed = $false
$audioPanelDragAutomationFallbackUsed = $false
$audioPanelSettingsPath = if ($FocusAudioPanels -or $ExerciseAudioPanels) {
    Join-Path $localDataFullPath "audio-panel-settings.json"
} else { $null }
$audioPanelSettingsSha256 = $null
$audioPanelPersistedSettings = $null
$audioPanelDebounceWaitMilliseconds = 750
$audioPanelInteractionRuntimeEvidence = $null
$groupFocusBeat = $FocusGroupBeat
$interactionActionsCompletedAtUtc = $null
$interactionCapturedAfterActions = $false
$interactionExercised = $false
try {
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $evidencePending = -not $LibraryHome
    do {
        Start-Sleep -Milliseconds 200
        $process.Refresh()
        if (($ExerciseEdgeScroll -or $ExerciseHoldTailResize -or $ExerciseLongToTap -or $ExerciseNoteProperty -or
             $groupExerciseEnabled -or $proEditorExerciseEnabled -or $ExerciseKeySoundRuntime -or
             $ExerciseDisplayScale -or $ExerciseAudioPanels -or $libraryDeleteExerciseEnabled -or
             $chartValidationExerciseEnabled -or $chartExportModesExerciseEnabled -or
             $fullPackageExportExerciseEnabled) -and
            -not $interactionExercised -and
            -not $process.HasExited -and $process.MainWindowHandle -ne [IntPtr]::Zero -and
            (Test-Path -LiteralPath $evidenceFullPath)) {
            # The primary probe has stopped moving CurrentBeat. Exercise the real
            # captured-pointer path, then let the app write a second state sample.
            Start-Sleep -Milliseconds 100
            $exerciseRectangle = [LumaChartAvaloniaCaptureNative+RECT]::new()
            if (-not [LumaChartAvaloniaCaptureNative]::GetWindowRect(
                    $process.MainWindowHandle,
                    [ref]$exerciseRectangle)) {
                throw "GetWindowRect failed before edge-scroll exercise."
            }
            $exerciseWidth = $exerciseRectangle.Right - $exerciseRectangle.Left
            $exerciseHeight = $exerciseRectangle.Bottom - $exerciseRectangle.Top
            if ($exerciseWidth -le 0 -or $exerciseHeight -le 0) {
                throw "Window bounds were invalid before edge-scroll exercise."
            }

            $savedCursor = [LumaChartAvaloniaCaptureNative+POINT]::new()
            $haveSavedCursor = [LumaChartAvaloniaCaptureNative]::GetCursorPos([ref]$savedCursor)
            $buttonDown = $false
            try {
                Set-ForegroundWindowVerified -WindowHandle $process.MainWindowHandle
                $primaryGroupActionEvidence = $null
                if ($groupExerciseEnabled) {
                    $primaryGroupActionEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw |
                        ConvertFrom-Json
                    $minimumInteractionBudget = if ($ExerciseGroupPlacement) {
                        12000
                    } elseif ($ExerciseGroupAssign) {
                        6000
                    } else {
                        9000
                    }
                    Assert-InteractionWindowRemaining `
                        -PrimaryEvidence $primaryGroupActionEvidence `
                        -MinimumMilliseconds $minimumInteractionBudget
                }
                $primaryProEditorActionEvidence = $null
                if ($proEditorExerciseEnabled) {
                    $primaryProEditorActionEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw |
                        ConvertFrom-Json
                    $minimumInteractionBudget = if ($ExerciseProEditorSaveAsOsu) { 12000 } else { 7000 }
                    Assert-InteractionWindowRemaining `
                        -PrimaryEvidence $primaryProEditorActionEvidence `
                        -MinimumMilliseconds $minimumInteractionBudget
                }
                if ($libraryDeleteExerciseEnabled) {
                    $primaryLibraryDeleteEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw |
                        ConvertFrom-Json
                    $libraryInteractionBudget = if ($ExerciseLibraryBatchDeleteConfirm) {
                        16000
                    } elseif ($ExerciseLibraryOpenDocumentBlock) { 10000 } else { 9000 }
                    Assert-InteractionWindowRemaining `
                        -PrimaryEvidence $primaryLibraryDeleteEvidence `
                        -MinimumMilliseconds $libraryInteractionBudget

                    $targetCard = Get-LibraryFolderItemObservation `
                        -TargetProcessId $process.Id `
                        -UniqueName $LibraryDeleteTargetName `
                        -RootWindowHandle $process.MainWindowHandle `
                        -TimeoutMilliseconds 10000
                    $targetPeerName = [string]$targetCard.Evidence.name
                    $secondTargetCard = if ($ExerciseLibraryBatchDeleteConfirm) {
                        Get-LibraryFolderItemObservation `
                            -TargetProcessId $process.Id `
                            -UniqueName $LibraryDeleteSecondTargetName `
                            -RootWindowHandle $process.MainWindowHandle `
                            -TimeoutMilliseconds 10000
                    } else { $null }
                    $secondTargetPeerName = if ($secondTargetCard) {
                        [string]$secondTargetCard.Evidence.name
                    } else { $null }
                    $selectionSteps = [Collections.Generic.List[object]]::new()

                    if ($ExerciseLibraryBatchDeleteConfirm) {
                        Click-AutomationElementWithMouse -Element $targetCard.Element
                        Start-Sleep -Milliseconds 220
                        $plainSelection = Get-LibraryListSelectionObservation `
                            -TargetProcessId $process.Id `
                            -RootWindowHandle $process.MainWindowHandle
                        Assert-LibrarySelectionNames `
                            -Observation $plainSelection `
                            -ExpectedNames @($targetPeerName) `
                            -Step "plain first-target click"
                        $selectionSteps.Add([ordered]@{
                            sequence = 1
                            action = "plain-left-click-first"
                            input = "physical-left-click"
                            target = $targetCard.Evidence
                            automationSelectionFallbackUsed = $false
                            selection = $plainSelection
                        })

                        $secondTargetCard = Get-LibraryFolderItemObservation `
                            -TargetProcessId $process.Id `
                            -UniqueName $LibraryDeleteSecondTargetName `
                            -RootWindowHandle $process.MainWindowHandle
                        $shiftInput = Invoke-ModifiedMouseClick `
                            -Element $secondTargetCard.Element `
                            -Modifier Shift
                        Start-Sleep -Milliseconds 220
                        $shiftSelection = Get-LibraryListSelectionObservation `
                            -TargetProcessId $process.Id `
                            -RootWindowHandle $process.MainWindowHandle
                        Assert-LibrarySelectionNames `
                            -Observation $shiftSelection `
                            -ExpectedNames @($targetPeerName, $secondTargetPeerName) `
                            -Step "Shift+second-target click"
                        $selectionSteps.Add([ordered]@{
                            sequence = 2
                            action = "shift-left-click-second"
                            input = $shiftInput
                            target = $secondTargetCard.Evidence
                            selection = $shiftSelection
                        })

                        $secondTargetCard = Get-LibraryFolderItemObservation `
                            -TargetProcessId $process.Id `
                            -UniqueName $LibraryDeleteSecondTargetName `
                            -RootWindowHandle $process.MainWindowHandle
                        $firstControlInput = Invoke-ModifiedMouseClick `
                            -Element $secondTargetCard.Element `
                            -Modifier Control
                        Start-Sleep -Milliseconds 220
                        $controlRemoveSelection = Get-LibraryListSelectionObservation `
                            -TargetProcessId $process.Id `
                            -RootWindowHandle $process.MainWindowHandle
                        Assert-LibrarySelectionNames `
                            -Observation $controlRemoveSelection `
                            -ExpectedNames @($targetPeerName) `
                            -Step "first Ctrl+second-target click"
                        $selectionSteps.Add([ordered]@{
                            sequence = 3
                            action = "control-left-click-second-remove"
                            input = $firstControlInput
                            target = $secondTargetCard.Evidence
                            selection = $controlRemoveSelection
                        })

                        $secondTargetCard = Get-LibraryFolderItemObservation `
                            -TargetProcessId $process.Id `
                            -UniqueName $LibraryDeleteSecondTargetName `
                            -RootWindowHandle $process.MainWindowHandle
                        $secondControlInput = Invoke-ModifiedMouseClick `
                            -Element $secondTargetCard.Element `
                            -Modifier Control
                        Start-Sleep -Milliseconds 220
                        $controlRestoreSelection = Get-LibraryListSelectionObservation `
                            -TargetProcessId $process.Id `
                            -RootWindowHandle $process.MainWindowHandle
                        Assert-LibrarySelectionNames `
                            -Observation $controlRestoreSelection `
                            -ExpectedNames @($targetPeerName, $secondTargetPeerName) `
                            -Step "second Ctrl+second-target click"
                        $selectionSteps.Add([ordered]@{
                            sequence = 4
                            action = "control-left-click-second-restore"
                            input = $secondControlInput
                            target = $secondTargetCard.Evidence
                            selection = $controlRestoreSelection
                        })
                        $secondTargetCard = Get-LibraryFolderItemObservation `
                            -TargetProcessId $process.Id `
                            -UniqueName $LibraryDeleteSecondTargetName `
                            -RootWindowHandle $process.MainWindowHandle
                    }

                    $selectionBeforeRightClick = Get-LibraryListSelectionObservation `
                        -TargetProcessId $process.Id `
                        -RootWindowHandle $process.MainWindowHandle
                    $rightClickTarget = if ($ExerciseLibraryBatchDeleteConfirm) {
                        $secondTargetCard
                    } else { $targetCard }
                    $rightClickBounds = $rightClickTarget.Evidence.bounds
                    $cardPointerX = [int][Math]::Round(
                        [double]$rightClickBounds.left + [double]$rightClickBounds.width * .62)
                    $cardPointerY = [int][Math]::Round(
                        [double]$rightClickBounds.top + [double]$rightClickBounds.height * .5)
                    Set-ForegroundWindowVerified -WindowHandle $process.MainWindowHandle
                    Start-Sleep -Milliseconds 80
                    Invoke-MouseRightClick `
                        -X $cardPointerX `
                        -Y $cardPointerY `
                        -ExpectedForegroundWindow $process.MainWindowHandle
                    Start-Sleep -Milliseconds 500
                    # WPF applies its right-click selection rule from
                    # ContextMenuOpening.  First prove the popup is actually
                    # open, then observe SelectionPattern; sampling before the
                    # popup peer exists races that same opening callback on a
                    # busy first-run UI thread.
                    try {
                        $deleteMenuItem = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Library.DeleteContextMenuItem" `
                            -RootWindowHandle ([IntPtr]::Zero) `
                            -TimeoutMilliseconds 10000
                    }
                    catch {
                        $menuDiscoveryError = $_.Exception.Message
                        $selectionOnMenuFailure = $null
                        $selectionOnMenuFailureError = $null
                        try {
                            $selectionOnMenuFailure = Get-LibraryListSelectionObservation `
                                -TargetProcessId $process.Id `
                                -RootWindowHandle $process.MainWindowHandle
                        }
                        catch {
                            $selectionOnMenuFailureError = $_.Exception.Message
                        }
                        $cursorOnMenuFailure = [LumaChartAvaloniaCaptureNative+POINT]::new()
                        [LumaChartAvaloniaCaptureNative]::GetCursorPos(
                            [ref]$cursorOnMenuFailure) | Out-Null
                        Save-AutomationElementScreenshot `
                            -Observation $rightClickTarget `
                            -Path $libraryContextMenuScreenshotFullPath `
                            -Padding 160
                        $selectionDiagnostic = if ($selectionOnMenuFailure) {
                            $selectionOnMenuFailure | ConvertTo-Json -Compress -Depth 10
                        } else { "unavailable: $selectionOnMenuFailureError" }
                        throw "Library context menu did not open after a physical right-click. " +
                            "mainWindowHandle=$($process.MainWindowHandle); " +
                            "foregroundWindowHandle=$([LumaChartAvaloniaCaptureNative]::GetForegroundWindow()); " +
                            "cursor=($($cursorOnMenuFailure.X),$($cursorOnMenuFailure.Y)); " +
                            "target=($cardPointerX,$cardPointerY); " +
                            "selection=$selectionDiagnostic; " +
                            "diagnosticScreenshot='$libraryContextMenuScreenshotFullPath'. " +
                            "Original error: $menuDiscoveryError"
                    }
                    $expectedSelectedPeerNames = if ($ExerciseLibraryBatchDeleteConfirm) {
                        @($targetPeerName, $secondTargetPeerName)
                    } else { @($targetPeerName) }
                    try {
                        $selectionAfterRightClick = Wait-LibrarySelectionNames `
                            -TargetProcessId $process.Id `
                            -RootWindowHandle $process.MainWindowHandle `
                            -ExpectedNames $expectedSelectedPeerNames `
                            -Step ("right-click target selection policy after ContextMenu opened; " +
                                "menu='$([string]$deleteMenuItem.Evidence.name)'")
                    }
                    catch {
                        $selectionItemObject = $null
                        $targetIsSelected = $rightClickTarget.Element.TryGetCurrentPattern(
                            [System.Windows.Automation.SelectionItemPattern]::Pattern,
                            [ref]$selectionItemObject) -and
                            [bool]([System.Windows.Automation.SelectionItemPattern]$selectionItemObject).
                                Current.IsSelected
                        throw "$($_.Exception.Message) Target SelectionItem.IsSelected=" +
                            "'$targetIsSelected'."
                    }

                    $expectedDeleteMenuText = if ($ExerciseLibraryBatchDeleteConfirm) {
                        "删除所选 2 个歌曲文件夹"
                    } else { "删除此歌曲文件夹" }
                    if ([string]$deleteMenuItem.Evidence.name -cne $expectedDeleteMenuText) {
                        throw "Library context-menu text did not match '$expectedDeleteMenuText'."
                    }
                    $menuBounds = $deleteMenuItem.Evidence.bounds
                    $menuHoverX = [int][Math]::Round(
                        [double]$menuBounds.left + [double]$menuBounds.width * .5)
                    $menuHoverY = [int][Math]::Round(
                        [double]$menuBounds.top + [double]$menuBounds.height * .5)
                    if (-not [LumaChartAvaloniaCaptureNative]::SetCursorPos(
                            $menuHoverX,
                            $menuHoverY)) {
                        throw "Failed to move the physical pointer onto the danger MenuItem."
                    }
                    Start-Sleep -Milliseconds 300
                    $hoveredDeleteMenuItem = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Library.DeleteContextMenuItem" `
                        -RootWindowHandle ([IntPtr]::Zero) `
                        -TimeoutMilliseconds 3000
                    if ([bool]$hoveredDeleteMenuItem.Evidence.isOffscreen) {
                        throw "Danger MenuItem became offscreen during physical hover."
                    }
                    $menuCaptureLeft = [int][Math]::Max(0, [Math]::Floor(
                        [Math]::Min([double]$rightClickBounds.left, [double]$menuBounds.left) - 40))
                    $menuCaptureTop = [int][Math]::Max(0, [Math]::Floor(
                        [Math]::Min([double]$rightClickBounds.top, [double]$menuBounds.top) - 120))
                    $menuCaptureRight = [int][Math]::Ceiling(
                        [Math]::Max(
                            [double]$rightClickBounds.left + [double]$rightClickBounds.width,
                            [double]$menuBounds.left + [double]$menuBounds.width) + 20)
                    $menuCaptureBottom = [int][Math]::Ceiling(
                        [Math]::Max(
                            [double]$rightClickBounds.top + [double]$rightClickBounds.height,
                            [double]$menuBounds.top + [double]$menuBounds.height) + 30)
                    Save-ScreenRegionScreenshot `
                        -Left $menuCaptureLeft `
                        -Top $menuCaptureTop `
                        -Width ($menuCaptureRight - $menuCaptureLeft) `
                        -Height ($menuCaptureBottom - $menuCaptureTop) `
                        -Path $libraryContextMenuScreenshotFullPath
                    $libraryContextMenuScreenshotSha256 =
                        (Get-FileHash -LiteralPath $libraryContextMenuScreenshotFullPath -Algorithm SHA256).Hash
                    Click-AutomationElementWithMouse -Element $deleteMenuItem.Element
                    Start-Sleep -Milliseconds 500

                    $dialog = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Library.DeleteDialog" `
                        -RootWindowHandle ([IntPtr]::Zero) `
                        -TimeoutMilliseconds 10000
                    $dialogMessage = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Library.DeleteDialog.Message" `
                        -RootWindowHandle ([IntPtr]::Zero) `
                        -TimeoutMilliseconds 10000
                    $dialogIcon = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Library.DeleteDialog.Icon" `
                        -RootWindowHandle ([IntPtr]::Zero) `
                        -TimeoutMilliseconds 10000
                    $dialogCancel = $null
                    $dialogRecycle = $null
                    $dialogConfirm = $null
                    $dialogCancelAbsent = $false
                    $dialogRecycleAbsent = $false
                    $dialogConfirmAbsent = $false
                    if ($ExerciseLibraryOpenDocumentBlock) {
                        $dialogConfirm = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Library.DeleteDialog.Confirm" `
                            -RootWindowHandle ([IntPtr]::Zero) `
                            -TimeoutMilliseconds 10000
                        $dialogCancelAbsent = Test-AutomationElementAbsentById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Library.DeleteDialog.Cancel"
                        $dialogRecycleAbsent = Test-AutomationElementAbsentById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Library.DeleteDialog.Recycle"
                        if ([string]$dialog.Evidence.name -cne "无法删除" -or
                            [string]$dialogIcon.Evidence.name -cne "!" -or
                            [string]$dialogIcon.Evidence.helpText -cne "警告" -or
                            [string]$dialogConfirm.Evidence.name -cne "确定" -or
                            -not ([string]$dialogMessage.Evidence.name -cmatch
                                '^选中文件夹中有正在编辑的谱面：.+。\r?\n\r?\n请先关闭对应谱面标签，再执行删除。$') -or
                            -not $dialogCancelAbsent -or
                            -not $dialogRecycleAbsent) {
                            $observedMessage = ([string]$dialogMessage.Evidence.name).
                                Replace("`r", "<CR>").Replace("`n", "<LF>")
                            throw "Open-document block dialog did not expose exact warning copy and Confirm-only controls. " +
                                "dialog='$([string]$dialog.Evidence.name)'; " +
                                "icon='$([string]$dialogIcon.Evidence.name)'; " +
                                "confirm='$([string]$dialogConfirm.Evidence.name)'; " +
                                "cancelAbsent='$dialogCancelAbsent'; recycleAbsent='$dialogRecycleAbsent'; " +
                                "message='$observedMessage'."
                        }
                    } else {
                        $dialogCancel = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Library.DeleteDialog.Cancel" `
                            -RootWindowHandle ([IntPtr]::Zero) `
                            -TimeoutMilliseconds 10000
                        $dialogRecycle = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Library.DeleteDialog.Recycle" `
                            -RootWindowHandle ([IntPtr]::Zero) `
                            -TimeoutMilliseconds 10000
                        $dialogConfirmAbsent = Test-AutomationElementAbsentById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Library.DeleteDialog.Confirm"
                        $expectedFolderCount = if ($ExerciseLibraryBatchDeleteConfirm) { 2 } else { 1 }
                        if ([string]$dialog.Evidence.name -cne "删除歌曲" -or
                            [string]$dialogIcon.Evidence.name -cne "?" -or
                            [string]$dialogIcon.Evidence.helpText -cne "问题" -or
                            [string]$dialogCancel.Evidence.name -cne "取消" -or
                            [string]$dialogRecycle.Evidence.name -cne "移入回收站" -or
                            -not ([string]$dialogMessage.Evidence.name).StartsWith(
                                "确定将 $expectedFolderCount 个歌曲文件夹移入回收站吗？`n",
                                [StringComparison]::Ordinal) -or
                            -not $dialogConfirmAbsent) {
                            throw "Library confirmation dialog did not expose question tone and neutral Cancel/Recycle controls."
                        }
                    }
                    $dialogButtonId = if ($ExerciseLibraryOpenDocumentBlock) {
                        "Library.DeleteDialog.Confirm"
                    } elseif ($ExerciseLibraryDeleteConfirm -or $ExerciseLibraryBatchDeleteConfirm) {
                        "Library.DeleteDialog.Recycle"
                    } else { "Library.DeleteDialog.Cancel" }
                    $dialogButton = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId $dialogButtonId `
                        -RootWindowHandle ([IntPtr]::Zero) `
                        -TimeoutMilliseconds 10000
                    $dialogBounds = $dialog.Evidence.bounds
                    $dialogCaptureLeft = [int][Math]::Max(0, [Math]::Floor([double]$dialogBounds.left - 20))
                    $dialogCaptureTop = [int][Math]::Max(0, [Math]::Floor([double]$dialogBounds.top - 20))
                    Save-ScreenRegionScreenshot `
                        -Left $dialogCaptureLeft `
                        -Top $dialogCaptureTop `
                        -Width ([int][Math]::Ceiling([double]$dialogBounds.width + 40)) `
                        -Height ([int][Math]::Ceiling([double]$dialogBounds.height + 40)) `
                        -Path $libraryDeleteDialogScreenshotFullPath
                    $libraryDeleteDialogScreenshotSha256 =
                        (Get-FileHash -LiteralPath $libraryDeleteDialogScreenshotFullPath -Algorithm SHA256).Hash
                    $clipboardInput = $null
                    $clipboardText = $null
                    if ($ExerciseLibraryOpenDocumentBlock) {
                        $dialogNativeHandle = [IntPtr][int]$dialog.Element.Current.NativeWindowHandle
                        if ($dialogNativeHandle -ne [IntPtr]::Zero) {
                            Set-ForegroundWindowVerified -WindowHandle $dialogNativeHandle
                        }
                        $dialogButton.Element.SetFocus()
                        Start-Sleep -Milliseconds 100
                        $clipboardInput = Invoke-PhysicalControlC
                        $clipboardText = Get-ClipboardTextWithRetry `
                            -ExpectedText ([string]$dialogMessage.Evidence.name)
                    }
                    Click-AutomationElementWithMouse -Element $dialogButton.Element

                    $outcomeDeadline = [DateTime]::UtcNow.AddSeconds(5)
                    do {
                        Start-Sleep -Milliseconds 100
                        $libraryDeleteTargetExistsAfter = Test-Path `
                            -LiteralPath $libraryDeleteTargetFullPath `
                            -PathType Container
                        $libraryDeleteSecondTargetExistsAfter = if ($libraryDeleteSecondTargetFullPath) {
                            Test-Path -LiteralPath $libraryDeleteSecondTargetFullPath -PathType Container
                        } else { $null }
                        $expectedOutcomeObserved = if ($ExerciseLibraryBatchDeleteConfirm) {
                            -not $libraryDeleteTargetExistsAfter -and
                            -not $libraryDeleteSecondTargetExistsAfter
                        } elseif ($ExerciseLibraryDeleteConfirm) {
                            -not $libraryDeleteTargetExistsAfter
                        } else { $libraryDeleteTargetExistsAfter }
                    } while (-not $expectedOutcomeObserved -and
                             [DateTime]::UtcNow -lt $outcomeDeadline)
                    if (-not $expectedOutcomeObserved) {
                        throw "Library deletion dialog outcome did not produce the expected target-path state."
                    }
                    if ($ExerciseLibraryOpenDocumentBlock -and
                        -not (Test-AutomationElementAbsentById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Library.DeleteDialog")) {
                        throw "Open-document block dialog remained open after clicking Confirm."
                    }
                    $libraryDeletionAction = [ordered]@{
                        mode = if ($ExerciseLibraryBatchDeleteConfirm) {
                            "batch-delete-confirm"
                        } elseif ($ExerciseLibraryOpenDocumentBlock) {
                            "open-document-block"
                        } elseif ($ExerciseLibraryDeleteConfirm) {
                            "single-delete-confirm"
                        } else { "single-delete-cancel" }
                        targetAutomationName = $LibraryDeleteTargetName
                        targetPath = $libraryDeleteTargetFullPath
                        targetCard = $targetCard.Evidence
                        secondTargetAutomationName = $LibraryDeleteSecondTargetName
                        secondTargetPath = $libraryDeleteSecondTargetFullPath
                        secondTargetCard = if ($secondTargetCard) { $secondTargetCard.Evidence } else { $null }
                        selectionPatternOnly = $false
                        selectionItemPatternReadOnly = $true
                        parentSelectionPatternBridgeMismatchObserved =
                            -not [bool]$selectionAfterRightClick.selectionPatternMatchesRealized
                        selectionAutomationFallbackUsed = $false
                        selectionSteps = @($selectionSteps)
                        selectionBeforeRightClick = $selectionBeforeRightClick
                        selectionAfterRightClick = $selectionAfterRightClick
                        rightClickPreservedSelection =
                            [int]$selectionBeforeRightClick.selectedCount -eq
                                [int]$selectionAfterRightClick.selectedCount -and
                            [string]::Join("`n", @($selectionBeforeRightClick.selectedItems.name | Sort-Object)) -ceq
                                [string]::Join("`n", @($selectionAfterRightClick.selectedItems.name | Sort-Object))
                        pointer = [ordered]@{ x = $cardPointerX; y = $cardPointerY; button = "right" }
                        contextMenuItem = $deleteMenuItem.Evidence
                        dangerMenuPhysicalHover = [ordered]@{
                            pointer = [ordered]@{
                                x = $menuHoverX
                                y = $menuHoverY
                            }
                            item = $hoveredDeleteMenuItem.Evidence
                            screenshotCaptured = $true
                            automationFallbackUsed = $false
                        }
                        dialog = $dialog.Evidence
                        dialogMessage = $dialogMessage.Evidence
                        dialogIcon = $dialogIcon.Evidence
                        dialogCancel = if ($dialogCancel) { $dialogCancel.Evidence } else { $null }
                        dialogRecycle = if ($dialogRecycle) { $dialogRecycle.Evidence } else { $null }
                        dialogConfirm = if ($dialogConfirm) { $dialogConfirm.Evidence } else { $null }
                        cancelAbsent = $dialogCancelAbsent
                        recycleAbsent = $dialogRecycleAbsent
                        confirmAbsent = $dialogConfirmAbsent
                        questionTone = [string]$dialogIcon.Evidence.name -ceq "?" -and
                            [string]$dialogIcon.Evidence.helpText -ceq "问题"
                        warningTone = [string]$dialogIcon.Evidence.name -ceq "!" -and
                            [string]$dialogIcon.Evidence.helpText -ceq "警告"
                        neutralCancelRecycleDecision = $null -ne $dialogCancel -and
                            $null -ne $dialogRecycle -and $dialogConfirmAbsent
                        clipboardInput = $clipboardInput
                        clipboardText = $clipboardText
                        clipboardExactMessage = if ($ExerciseLibraryOpenDocumentBlock) {
                            $clipboardText -ceq [string]$dialogMessage.Evidence.name
                        } else { $null }
                        dialogButton = $dialogButton.Evidence
                        requestedOutcome = if ($ExerciseLibraryBatchDeleteConfirm -or
                            $ExerciseLibraryDeleteConfirm) { "Recycle" } elseif (
                            $ExerciseLibraryOpenDocumentBlock) { "Blocked" } else { "Cancel" }
                        targetExistedBefore = $libraryDeleteTargetExistedBefore
                        targetExistsAfter = $libraryDeleteTargetExistsAfter
                        secondTargetExistedBefore = $libraryDeleteSecondTargetExistedBefore
                        secondTargetExistsAfter = $libraryDeleteSecondTargetExistsAfter
                        contextMenuScreenshotPath = $libraryContextMenuScreenshotFullPath
                        contextMenuScreenshotSha256 = $libraryContextMenuScreenshotSha256
                        dialogScreenshotPath = $libraryDeleteDialogScreenshotFullPath
                        dialogScreenshotSha256 = $libraryDeleteDialogScreenshotSha256
                    }
                    $libraryDeletionExercised = $true
                }
                if ($chartValidationExerciseEnabled) {
                    $primaryChartValidationEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw |
                        ConvertFrom-Json
                    Assert-InteractionWindowRemaining `
                        -PrimaryEvidence $primaryChartValidationEvidence `
                        -MinimumMilliseconds 14000

                    $commandMenuToggle = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Editor.CommandMenuToggle" `
                        -RootWindowHandle $process.MainWindowHandle `
                        -TimeoutMilliseconds 10000
                    Click-AutomationElementWithMouse -Element $commandMenuToggle.Element
                    Start-Sleep -Milliseconds 250
                    $checkButton = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Editor.ChartCheck" `
                        -RootWindowHandle $process.MainWindowHandle `
                        -TimeoutMilliseconds 10000
                    Click-AutomationElementWithMouse -Element $checkButton.Element

                    $manualDialog = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "ChartValidation.Dialog" `
                        -RootWindowHandle ([IntPtr]::Zero) `
                        -TimeoutMilliseconds 10000
                    $manualMessage = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "ChartValidation.Dialog.Message" `
                        -RootWindowHandle ([IntPtr]::Zero) `
                        -TimeoutMilliseconds 10000
                    $manualConfirm = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "ChartValidation.Dialog.Confirm" `
                        -RootWindowHandle ([IntPtr]::Zero) `
                        -TimeoutMilliseconds 10000
                    Save-AutomationElementScreenshot `
                        -Observation $manualDialog `
                        -Path $chartValidationManualDialogScreenshotFullPath
                    $chartValidationManualDialogScreenshotSha256 =
                        (Get-FileHash -LiteralPath $chartValidationManualDialogScreenshotFullPath -Algorithm SHA256).Hash
                    Click-AutomationElementWithMouse -Element $manualConfirm.Element
                    Start-Sleep -Milliseconds 300

                    $noteInspectorTab = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Inspector.NoteTab" `
                        -RootWindowHandle $process.MainWindowHandle `
                        -TimeoutMilliseconds 10000
                    $selectionPatternObject = $null
                    $noteInspectorSelected =
                        $noteInspectorTab.Element.TryGetCurrentPattern(
                            [System.Windows.Automation.SelectionItemPattern]::Pattern,
                            [ref]$selectionPatternObject) -and
                        ([System.Windows.Automation.SelectionItemPattern]$selectionPatternObject).Current.IsSelected
                    $manualStatusObservation = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Editor.Status" `
                        -RootWindowHandle $process.MainWindowHandle `
                        -TimeoutMilliseconds 10000

                    $saveButton = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Editor.Save" `
                        -RootWindowHandle $process.MainWindowHandle `
                        -TimeoutMilliseconds 10000
                    Click-AutomationElementWithMouse -Element $saveButton.Element

                    $saveBlockedDialog = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "ChartValidation.Dialog" `
                        -RootWindowHandle ([IntPtr]::Zero) `
                        -TimeoutMilliseconds 10000
                    $saveBlockedMessage = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "ChartValidation.Dialog.Message" `
                        -RootWindowHandle ([IntPtr]::Zero) `
                        -TimeoutMilliseconds 10000
                    $saveBlockedConfirm = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "ChartValidation.Dialog.Confirm" `
                        -RootWindowHandle ([IntPtr]::Zero) `
                        -TimeoutMilliseconds 10000
                    Save-AutomationElementScreenshot `
                        -Observation $saveBlockedDialog `
                        -Path $chartValidationSaveBlockedDialogScreenshotFullPath
                    $chartValidationSaveBlockedDialogScreenshotSha256 =
                        (Get-FileHash -LiteralPath $chartValidationSaveBlockedDialogScreenshotFullPath -Algorithm SHA256).Hash
                    Click-AutomationElementWithMouse -Element $saveBlockedConfirm.Element
                    Start-Sleep -Milliseconds 300

                    $statusObservation = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Editor.Status" `
                        -RootWindowHandle $process.MainWindowHandle `
                        -TimeoutMilliseconds 10000

                    $chartAfterItem = Get-Item -LiteralPath $chartFullPath
                    $chartValidationSourceAfter = [ordered]@{
                        path = $chartFullPath
                        length = [long]$chartAfterItem.Length
                        lastWriteTimeUtc = $chartAfterItem.LastWriteTimeUtc.ToString(
                            "O",
                            [Globalization.CultureInfo]::InvariantCulture)
                        sha256 = (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
                    }
                    if ([long]$chartValidationSourceBefore.length -ne [long]$chartValidationSourceAfter.length -or
                        [string]$chartValidationSourceBefore.sha256 -ne [string]$chartValidationSourceAfter.sha256 -or
                        [string]$chartValidationSourceBefore.lastWriteTimeUtc -ne
                            [string]$chartValidationSourceAfter.lastWriteTimeUtc) {
                        throw "Chart-validation Save must leave the source file byte-for-byte and timestamp unchanged."
                    }

                    $chartValidationAction = [ordered]@{
                        checkButton = $checkButton.Evidence
                        manualDialog = $manualDialog.Evidence
                        manualMessage = $manualMessage.Evidence
                        manualConfirm = $manualConfirm.Evidence
                        manualDialogScreenshotPath = $chartValidationManualDialogScreenshotFullPath
                        manualDialogScreenshotSha256 = $chartValidationManualDialogScreenshotSha256
                        noteInspectorTab = $noteInspectorTab.Evidence
                        noteInspectorSelected = [bool]$noteInspectorSelected
                        manualInspectorSummary = $null
                        manualStatus = $manualStatusObservation.Evidence
                        status = $statusObservation.Evidence
                        saveButton = $saveButton.Evidence
                        saveBlockedDialog = $saveBlockedDialog.Evidence
                        saveBlockedMessage = $saveBlockedMessage.Evidence
                        saveBlockedConfirm = $saveBlockedConfirm.Evidence
                        saveBlockedDialogScreenshotPath = $chartValidationSaveBlockedDialogScreenshotFullPath
                        saveBlockedDialogScreenshotSha256 = $chartValidationSaveBlockedDialogScreenshotSha256
                        sourceBefore = $chartValidationSourceBefore
                        sourceAfter = $chartValidationSourceAfter
                    }
                    $chartValidationExercised = $true
                }
                $primaryDisplayScaleActionEvidence = $null
                if ($ExerciseDisplayScale) {
                    $primaryDisplayScaleActionEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw |
                        ConvertFrom-Json
                    Assert-InteractionWindowRemaining `
                        -PrimaryEvidence $primaryDisplayScaleActionEvidence `
                        -MinimumMilliseconds 7000
                }
                $primaryKeySoundActionEvidence = $null
                if ($ExerciseDisplayScale) {
                    $settingsTabObservation = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Inspector.SettingsTab" `
                        -RootWindowHandle $process.MainWindowHandle
                    Click-AutomationElementWithMouse -Element $settingsTabObservation.Element
                    Start-Sleep -Milliseconds 350

                    $requiredDisplayScaleControlIds = @(
                        "Settings.UiScale",
                        "Settings.FontScale",
                        "Settings.UiScaleValue",
                        "Settings.FontScaleValue")
                    $displayScaleControlEvidence = [ordered]@{
                        "Inspector.SettingsTab" = $settingsTabObservation.Evidence
                    }
                    foreach ($automationId in $requiredDisplayScaleControlIds) {
                        $controlObservation = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId $automationId `
                            -RootWindowHandle $process.MainWindowHandle
                        $displayScaleControlEvidence[$automationId] = $controlObservation.Evidence
                    }

                    $uiResult = Set-AutomationRangeValueWithMouse `
                        -TargetProcessId $process.Id `
                        -AutomationId "Settings.UiScale" `
                        -Value $DisplayScaleUiPercent `
                        -RootWindowHandle $process.MainWindowHandle
                    # Persistence is debounced at 350 ms. Wait more than 600 ms
                    # after each user-facing scale operation before proceeding.
                    Start-Sleep -Milliseconds $displayScaleDebounceWaitMilliseconds
                    $fontResult = Set-AutomationRangeValueWithMouse `
                        -TargetProcessId $process.Id `
                        -AutomationId "Settings.FontScale" `
                        -Value $DisplayScaleFontPercent `
                        -RootWindowHandle $process.MainWindowHandle
                    Start-Sleep -Milliseconds $displayScaleDebounceWaitMilliseconds

                    $displayScaleAutomationFallbackUsed =
                        [bool]$uiResult.AutomationFallbackUsed -or
                        [bool]$fontResult.AutomationFallbackUsed
                    $displayScalePointerEvidence = [ordered]@{
                        uiScale = $uiResult
                        fontScale = $fontResult
                    }
                    $displayScaleExercised =
                        [Math]::Abs([double]$uiResult.ActualValue - $DisplayScaleUiPercent) -le .001 -and
                        [Math]::Abs([double]$fontResult.ActualValue - $DisplayScaleFontPercent) -le .001
                    if (-not $displayScaleExercised) {
                        throw "Display-scale UI exercise did not retain the requested UI/font percentages."
                    }
                }
                elseif ($ExerciseKeySoundRuntime) {
                    $primaryKeySoundActionEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw |
                        ConvertFrom-Json
                    Assert-InteractionWindowRemaining `
                        -PrimaryEvidence $primaryKeySoundActionEvidence `
                        -MinimumMilliseconds 10000
                    $keySoundSourceMode = if ([bool]$primaryKeySoundActionEvidence.audio.sourceExists) {
                        "shared-audio-candidate"
                    } else {
                        "silent-clock-candidate"
                    }
                }
                if ($ExerciseKeySoundRuntime) {
                    $audioTabObservation = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Inspector.AudioTab" `
                        -RootWindowHandle $process.MainWindowHandle
                    Click-AutomationElementWithMouse -Element $audioTabObservation.Element
                    Start-Sleep -Milliseconds 350

                    $requiredKeySoundControlIds = @(
                        "KeySound.Panel",
                        "KeySound.Enabled",
                        "KeySound.Preset",
                        "KeySound.Volume",
                        "KeySound.LongNoteEnd",
                        "KeySound.GlobalOffset",
                        "KeySound.ChartOffset",
                        "KeySound.Preview",
                        "Audio.PlayPause",
                        "Audio.Stop")
                    $initialKeySoundControls = [ordered]@{}
                    foreach ($automationId in $requiredKeySoundControlIds) {
                        $controlObservation = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId $automationId `
                            -RootWindowHandle $process.MainWindowHandle
                        $initialKeySoundControls[$automationId] = $controlObservation.Evidence
                    }

                    $presetObservation = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "KeySound.Preset" `
                        -RootWindowHandle $process.MainWindowHandle
                    $observedPreset = Get-AutomationSelectionValue -Element $presetObservation.Element
                    if ([string]::IsNullOrWhiteSpace($observedPreset) -or
                        ($observedPreset.IndexOf("Snare", [StringComparison]::OrdinalIgnoreCase) -lt 0 -and
                         $observedPreset.IndexOf("军鼓", [StringComparison]::Ordinal) -lt 0)) {
                        throw "KeySound.Preset did not retain the default Snare selection; observed '$observedPreset'."
                    }

                    Set-AutomationToggleStateWithMouse `
                        -TargetProcessId $process.Id `
                        -AutomationId "KeySound.Enabled" `
                        -ExpectedState ([System.Windows.Automation.ToggleState]::On) `
                        -RootWindowHandle $process.MainWindowHandle | Out-Null
                    $submittedVolume = Set-AutomationRangeValue `
                        -TargetProcessId $process.Id `
                        -AutomationId "KeySound.Volume" `
                        -Value 70 `
                        -RootWindowHandle $process.MainWindowHandle
                    Set-AutomationToggleStateWithMouse `
                        -TargetProcessId $process.Id `
                        -AutomationId "KeySound.LongNoteEnd" `
                        -ExpectedState ([System.Windows.Automation.ToggleState]::On) `
                        -RootWindowHandle $process.MainWindowHandle | Out-Null
                    $submittedGlobalOffset = Set-AutomationRangeValue `
                        -TargetProcessId $process.Id `
                        -AutomationId "KeySound.GlobalOffset" `
                        -Value -15 `
                        -RootWindowHandle $process.MainWindowHandle
                    $submittedChartOffset = Set-AutomationRangeValue `
                        -TargetProcessId $process.Id `
                        -AutomationId "KeySound.ChartOffset" `
                        -Value 5 `
                        -RootWindowHandle $process.MainWindowHandle

                    $keySoundControlEvidence = [ordered]@{
                        "Inspector.AudioTab" = $audioTabObservation.Evidence
                    }
                    foreach ($automationId in $requiredKeySoundControlIds) {
                        $controlObservation = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId $automationId `
                            -RootWindowHandle $process.MainWindowHandle
                        $keySoundControlEvidence[$automationId] = $controlObservation.Evidence
                    }
                    $keySoundSubmittedSettings = [ordered]@{
                        enabled = $true
                        preset = "Snare"
                        observedPreset = $observedPreset
                        volume = $submittedVolume
                        playLongNoteEndSound = $true
                        globalOffsetMilliseconds = $submittedGlobalOffset
                        chartOffsetMilliseconds = $submittedChartOffset
                    }

                    # Shared-audio plans publish after the settings debounce and
                    # background snapshot build; the silent-clock path completes
                    # inline. Give both paths a deterministic stable window.
                    Start-Sleep -Milliseconds 900

                    $previewObservation = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "KeySound.Preview" `
                        -RootWindowHandle $process.MainWindowHandle
                    if (-not $previewObservation.Element.Current.IsEnabled) {
                        throw "KeySound.Preview is visible but disabled after enabling Key sounds."
                    }
                    Click-AutomationElementWithMouse -Element $previewObservation.Element
                    $keySoundPreviewCompleted = $true
                    # Cold standalone WASAPI/WaveOut initialization can outlive a
                    # single UI animation frame. Let the awaited click handler
                    # finish before starting the transport so the formal probe
                    # distinguishes Preview submission from scheduled playback.
                    Start-Sleep -Milliseconds 1500

                    $playObservation = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Audio.PlayPause" `
                        -RootWindowHandle $process.MainWindowHandle
                    if (-not $playObservation.Element.Current.IsEnabled) {
                        throw "Audio.PlayPause is visible but disabled for the selected Key-sound fixture."
                    }
                    Click-AutomationElementWithMouse -Element $playObservation.Element
                    $keySoundPlayCompleted = $true
                    # Keep the real transport running long enough for the 33-ms
                    # scheduler and its background plan/output path to execute.
                    Start-Sleep -Milliseconds 1500

                    $stopObservation = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Audio.Stop" `
                        -RootWindowHandle $process.MainWindowHandle
                    if (-not $stopObservation.Element.Current.IsEnabled) {
                        throw "Audio.Stop is visible but disabled after the Key-sound playback window."
                    }
                    Click-AutomationElementWithMouse -Element $stopObservation.Element
                    $keySoundStopCompleted = $true
                    Start-Sleep -Milliseconds 450

                    # Leave the Key-sound panel itself in view for the formal
                    # PrintWindow screenshot; each required peer was separately
                    # observed on screen with non-empty bounds above.
                    $panelObservation = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "KeySound.Panel" `
                        -RootWindowHandle $process.MainWindowHandle
                    $keySoundControlEvidence["KeySound.Panel"] = $panelObservation.Evidence
                    $keySoundRuntimeExercised =
                        $keySoundPreviewCompleted -and
                        $keySoundPlayCompleted -and
                        $keySoundStopCompleted
                }
                elseif ($ExerciseAudioPanels) {
                    $primaryAudioPanelActionEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw |
                        ConvertFrom-Json
                    Assert-InteractionWindowRemaining `
                        -PrimaryEvidence $primaryAudioPanelActionEvidence `
                        -MinimumMilliseconds 1700

                    $audioPanelInitialControls = Get-AudioPanelControlEvidence `
                        -TargetProcessId $process.Id `
                        -RootWindowHandle $process.MainWindowHandle
                    $audioPanelInitialState = Convert-AudioPanelUiState $audioPanelInitialControls
                    if ($audioPanelInitialState.waveform.mode -ne "Side" -or
                        $audioPanelInitialState.waveform.collapsed -ne $false -or
                        $audioPanelInitialState.spectrogram.mode -ne "Side" -or
                        $audioPanelInitialState.spectrogram.collapsed -ne $true) {
                        throw "Audio-panel exercise did not start from the WPF-compatible expanded Waveform / collapsed Spectrogram Side layout."
                    }

                    $audioPanelActions = @()
                    Set-ForegroundWindowVerified -WindowHandle $process.MainWindowHandle

                    # Real Win32 pointer click: Waveform Side -> Background. UIA
                    # Invoke is used only if the physical click demonstrably did
                    # not change either the button name or the panel geometry.
                    $waveModeBefore = Get-AudioPanelFastObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Audio.WaveformMode" `
                        -RootWindowHandle $process.MainWindowHandle
                    $waveModeBounds = $waveModeBefore.Evidence.bounds
                    $waveModePointer = [ordered]@{
                        x = [int][Math]::Round([double]$waveModeBounds.left + [double]$waveModeBounds.width / 2)
                        y = [int][Math]::Round([double]$waveModeBounds.top + [double]$waveModeBounds.height / 2)
                    }
                    Click-AutomationElementWithMouse -Element $waveModeBefore.Element
                    # Switching to Background also rebuilds the timeline audio
                    # scene; allow the real pointer click to settle before deciding
                    # that an explicitly recorded UIA Invoke fallback is needed.
                    Start-Sleep -Milliseconds 400
                    $waveModeAfter = Get-AudioPanelFastObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Audio.WaveformMode" `
                        -RootWindowHandle $process.MainWindowHandle
                    $waveModePointerTransitionObserved =
                        $waveModeAfter.Evidence.name -ne $waveModeBefore.Evidence.name
                    $waveModeFallbackUsed = $false
                    if (-not $waveModePointerTransitionObserved) {
                        Invoke-AutomationElement -Element $waveModeAfter.Element
                        $waveModeFallbackUsed = $true
                        Start-Sleep -Milliseconds 140
                        $waveModeAfter = Get-AudioPanelFastObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Audio.WaveformMode" `
                            -RootWindowHandle $process.MainWindowHandle
                    }
                    $waveModeTransitionObserved =
                        $waveModeAfter.Evidence.name -ne $waveModeBefore.Evidence.name
                    if (-not $waveModeTransitionObserved) {
                        throw "Waveform mode did not transition from Side to Background after pointer click or explicit UIA fallback."
                    }
                    $audioPanelActions += [pscustomobject][ordered]@{
                        action = "waveform-side-to-background"
                        targetAutomationId = "Audio.WaveformMode"
                        physicalPointerAttempted = $true
                        pointer = $waveModePointer
                        beforeControl = $waveModeBefore.Evidence
                        afterControl = $waveModeAfter.Evidence
                        primaryPanelRuntime = $primaryAudioPanelActionEvidence.audio.panels.waveform
                        pointerTransitionObserved = $waveModePointerTransitionObserved
                        automationInvokeFallbackUsed = $waveModeFallbackUsed
                        transitionObserved = $waveModeTransitionObserved
                    }

                    # Real Win32 pointer click: collapsed Spectrogram -> expanded.
                    $spectrumCollapseBefore = Get-AudioPanelFastObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Audio.SpectrogramCollapse" `
                        -RootWindowHandle $process.MainWindowHandle
                    $spectrumCollapseBounds = $spectrumCollapseBefore.Evidence.bounds
                    $spectrumCollapsePointer = [ordered]@{
                        x = [int][Math]::Round([double]$spectrumCollapseBounds.left + [double]$spectrumCollapseBounds.width / 2)
                        y = [int][Math]::Round([double]$spectrumCollapseBounds.top + [double]$spectrumCollapseBounds.height / 2)
                    }
                    Click-AutomationElementWithMouse -Element $spectrumCollapseBefore.Element
                    # Scene creation can briefly occupy the UI thread on the first
                    # real-audio expansion.  Match the waveform transition grace
                    # period before deciding whether a UIA fallback is necessary.
                    Start-Sleep -Milliseconds 400
                    $spectrumCollapseAfter = Get-AudioPanelFastObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Audio.SpectrogramCollapse" `
                        -RootWindowHandle $process.MainWindowHandle
                    $spectrumPointerTransitionObserved =
                        $spectrumCollapseAfter.Evidence.name -ne $spectrumCollapseBefore.Evidence.name
                    $spectrumCollapseFallbackUsed = $false
                    if (-not $spectrumPointerTransitionObserved) {
                        Invoke-AutomationElement -Element $spectrumCollapseAfter.Element
                        $spectrumCollapseFallbackUsed = $true
                        Start-Sleep -Milliseconds 400
                        $spectrumCollapseAfter = Get-AudioPanelFastObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Audio.SpectrogramCollapse" `
                            -RootWindowHandle $process.MainWindowHandle
                    }
                    $spectrumTransitionObserved =
                        $spectrumCollapseAfter.Evidence.name -ne $spectrumCollapseBefore.Evidence.name
                    if (-not $spectrumTransitionObserved) {
                        throw "Spectrogram did not expand after pointer click or explicit UIA fallback."
                    }
                    $audioPanelActions += [pscustomobject][ordered]@{
                        action = "spectrogram-collapsed-to-expanded"
                        targetAutomationId = "Audio.SpectrogramCollapse"
                        physicalPointerAttempted = $true
                        pointer = $spectrumCollapsePointer
                        beforeControl = $spectrumCollapseBefore.Evidence
                        afterControl = $spectrumCollapseAfter.Evidence
                        primaryPanelRuntime = $primaryAudioPanelActionEvidence.audio.panels.spectrogram
                        pointerTransitionObserved = $spectrumPointerTransitionObserved
                        automationInvokeFallbackUsed = $spectrumCollapseFallbackUsed
                        transitionObserved = $spectrumTransitionObserved
                    }

                    # Borders do not expose AutomationPeers in Avalonia. Derive a
                    # safe toolbar-title point immediately left of the discoverable
                    # mode Button, and observe the real drag through that same
                    # Button's changed screen bounds. No UIA drag fallback exists.
                    $waveModeBeforeDrag = Get-AudioPanelFastObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Audio.WaveformMode" `
                        -RootWindowHandle $process.MainWindowHandle
                    $waveCollapseBeforeDrag = Get-AudioPanelFastObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Audio.WaveformCollapse" `
                        -RootWindowHandle $process.MainWindowHandle
                    $primaryWavePanelEvidence = $primaryAudioPanelActionEvidence.audio.panels.waveform
                    $primaryClientWidthDip = [double]$primaryAudioPanelActionEvidence.window.clientWidthDip
                    $primaryClientHeightDip = [double]$primaryAudioPanelActionEvidence.window.clientHeightDip
                    if ($null -eq $primaryWavePanelEvidence -or
                        $primaryClientWidthDip -le 0 -or $primaryClientHeightDip -le 0) {
                        throw "Primary GUI evidence did not expose audio.panels.waveform and usable client DIPs."
                    }
                    $panelScaleX = $exerciseWidth / $primaryClientWidthDip
                    $panelScaleY = $exerciseHeight / $primaryClientHeightDip
                    $modeBoundsBeforeDrag = $waveModeBeforeDrag.Evidence.bounds
                    $collapseBoundsBeforeDrag = $waveCollapseBeforeDrag.Evidence.bounds
                    $headerHeightPixels = 25 * $panelScaleY
                    $titleOffsetPixels = [Math]::Clamp(16 * $panelScaleX, 12, 20)
                    $modeCenterY = [double]$modeBoundsBeforeDrag.top +
                        [double]$modeBoundsBeforeDrag.height / 2
                    $collapseCenterY = [double]$collapseBoundsBeforeDrag.top +
                        [double]$collapseBoundsBeforeDrag.height / 2
                    $dragStartX = [int][Math]::Round(
                        [double]$modeBoundsBeforeDrag.left - $titleOffsetPixels)
                    $dragStartY = [int][Math]::Round($modeCenterY)
                    $derivedHeaderTop = $modeCenterY - $headerHeightPixels / 2
                    $derivedToolbarRight = [double]$collapseBoundsBeforeDrag.left +
                        [double]$collapseBoundsBeforeDrag.width + 3 * $panelScaleX
                    $derivedToolbarLeft = $derivedToolbarRight -
                        [double]$primaryWavePanelEvidence.actualWidthDip * $panelScaleX
                    $pointInsideHeader =
                        $dragStartX -gt $derivedToolbarLeft + 2 -and
                        $dragStartX -lt [double]$modeBoundsBeforeDrag.left - 2 -and
                        $dragStartY -gt $derivedHeaderTop -and
                        $dragStartY -lt $derivedHeaderTop + $headerHeightPixels
                    $toolbarOnlyGeometryVerified =
                        [Math]::Abs($modeCenterY - $collapseCenterY) -le
                            [Math]::Max(3, 3 * $panelScaleY) -and
                        $waveModeBeforeDrag.Evidence.name -eq "侧"
                    if (-not $pointInsideHeader -or -not $toolbarOnlyGeometryVerified) {
                        throw "Derived Waveform drag point is not inside the safe 25-DIP toolbar title region."
                    }
                    $requestedDragX = [int][Math]::Round(44 * $panelScaleX)
                    $requestedDragY = [int][Math]::Round(26 * $panelScaleY)
                    $dragDeltaX = if ($dragStartX + $requestedDragX -lt $exerciseRectangle.Right - 20) {
                        $requestedDragX
                    } else { -$requestedDragX }
                    $dragDeltaY = if ($dragStartY + $requestedDragY -lt $exerciseRectangle.Bottom - 40) {
                        $requestedDragY
                    } else { -$requestedDragY }
                    $dragEndX = $dragStartX + $dragDeltaX
                    $dragEndY = $dragStartY + $dragDeltaY
                    Invoke-MouseDrag `
                        -StartX $dragStartX `
                        -StartY $dragStartY `
                        -EndX $dragEndX `
                        -EndY $dragEndY `
                        -Steps 6
                    Start-Sleep -Milliseconds 400
                    $waveModeAfterDrag = Get-AudioPanelFastObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Audio.WaveformMode" `
                        -RootWindowHandle $process.MainWindowHandle
                    $waveCollapseAfterDrag = Get-AudioPanelFastObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Audio.WaveformCollapse" `
                        -RootWindowHandle $process.MainWindowHandle
                    $dragObservedDeltaX = [double]$waveModeAfterDrag.Evidence.bounds.left -
                        [double]$waveModeBeforeDrag.Evidence.bounds.left
                    $dragObservedDeltaY = [double]$waveModeAfterDrag.Evidence.bounds.top -
                        [double]$waveModeBeforeDrag.Evidence.bounds.top
                    $collapseObservedDeltaX = [double]$waveCollapseAfterDrag.Evidence.bounds.left -
                        [double]$waveCollapseBeforeDrag.Evidence.bounds.left
                    $collapseObservedDeltaY = [double]$waveCollapseAfterDrag.Evidence.bounds.top -
                        [double]$waveCollapseBeforeDrag.Evidence.bounds.top
                    $audioPanelDragObserved =
                        [Math]::Abs($dragObservedDeltaX) -ge 5 -and
                        [Math]::Abs($dragObservedDeltaY) -ge 5 -and
                        [Math]::Abs($collapseObservedDeltaX - $dragObservedDeltaX) -le 2 -and
                        [Math]::Abs($collapseObservedDeltaY - $dragObservedDeltaY) -le 2
                    if (-not $audioPanelDragObserved) {
                        throw "Background Waveform toolbar did not move in both X and Y after the real pointer drag."
                    }
                    $audioPanelActions += [pscustomobject][ordered]@{
                        action = "waveform-background-toolbar-drag"
                        anchorAutomationId = "Audio.WaveformMode"
                        targetRegion = "derived-25-dip-header-title-area"
                        headerAutomationPeerRequired = $false
                        physicalPointerAttempted = $true
                        pointerStart = [ordered]@{ x = $dragStartX; y = $dragStartY }
                        pointerEnd = [ordered]@{ x = $dragEndX; y = $dragEndY }
                        requestedDelta = [ordered]@{ x = $dragDeltaX; y = $dragDeltaY }
                        observedDelta = [ordered]@{ x = $dragObservedDeltaX; y = $dragObservedDeltaY }
                        derivation = [ordered]@{
                            panelScaleX = $panelScaleX
                            panelScaleY = $panelScaleY
                            headerHeightDip = 25
                            headerHeightPixels = $headerHeightPixels
                            titleOffsetPixels = $titleOffsetPixels
                            derivedToolbarLeft = $derivedToolbarLeft
                            derivedToolbarRight = $derivedToolbarRight
                            derivedHeaderTop = $derivedHeaderTop
                            pointInsideHeader = $pointInsideHeader
                            toolbarOnlyGeometryVerified = $toolbarOnlyGeometryVerified
                            primaryActualWindowXDip = $primaryWavePanelEvidence.actualWindowXDip
                            primaryActualWindowYDip = $primaryWavePanelEvidence.actualWindowYDip
                            primaryActualWidthDip = $primaryWavePanelEvidence.actualWidthDip
                        }
                        beforeModeButton = $waveModeBeforeDrag.Evidence
                        afterModeButton = $waveModeAfterDrag.Evidence
                        beforeCollapseButton = $waveCollapseBeforeDrag.Evidence
                        afterCollapseButton = $waveCollapseAfterDrag.Evidence
                        automationFallbackUsed = $false
                        transitionObserved = $audioPanelDragObserved
                    }
                    $interactionActionsCompletedAtUtc = [DateTimeOffset]::UtcNow

                    $audioPanelAutomationFallbackUsed =
                        $waveModeFallbackUsed -or $spectrumCollapseFallbackUsed
                    Start-Sleep -Milliseconds $audioPanelDebounceWaitMilliseconds
                    $settingsDeadline = [DateTime]::UtcNow.AddSeconds(4)
                    while (-not (Test-Path -LiteralPath $audioPanelSettingsPath -PathType Leaf) -and
                           [DateTime]::UtcNow -lt $settingsDeadline) {
                        Start-Sleep -Milliseconds 100
                    }
                    if (-not (Test-Path -LiteralPath $audioPanelSettingsPath -PathType Leaf)) {
                        throw "Audio-panel settings were not persisted after the 350-ms debounce window."
                    }
                    $audioPanelPersistedSettings = Get-Content -LiteralPath $audioPanelSettingsPath -Raw |
                        ConvertFrom-Json
                    $audioPanelSettingsSha256 =
                        (Get-FileHash -LiteralPath $audioPanelSettingsPath -Algorithm SHA256).Hash

                    $audioPanelFinalControls = Get-AudioPanelControlEvidence `
                        -TargetProcessId $process.Id `
                        -RootWindowHandle $process.MainWindowHandle
                    $audioPanelFinalState = Convert-AudioPanelUiState $audioPanelFinalControls
                    $persistedStateVerified =
                        [int]$audioPanelPersistedSettings.SchemaVersion -eq 1 -and
                        [string]$audioPanelPersistedSettings.Waveform.Mode -eq "Background" -and
                        -not [bool]$audioPanelPersistedSettings.Waveform.Collapsed -and
                        -not [bool]$audioPanelPersistedSettings.Waveform.Docked -and
                        [string]$audioPanelPersistedSettings.Spectrogram.Mode -eq "Side" -and
                        -not [bool]$audioPanelPersistedSettings.Spectrogram.Collapsed
                    $finalGeometryVerified =
                        [double]$audioPanelFinalControls["Audio.WaveformMode"].bounds.width -gt 1 -and
                        [double]$audioPanelFinalControls["Audio.WaveformMode"].bounds.height -gt 1 -and
                        [double]$audioPanelFinalControls["Audio.SpectrogramCollapse"].bounds.width -gt 1 -and
                        [double]$audioPanelFinalControls["Audio.SpectrogramCollapse"].bounds.height -gt 1 -and
                        $audioPanelFinalState.waveform.mode -eq "Background" -and
                        $audioPanelFinalState.waveform.collapsed -eq $false -and
                        $audioPanelFinalState.spectrogram.mode -eq "Side" -and
                        $audioPanelFinalState.spectrogram.collapsed -eq $false
                    $audioPanelsExercised =
                        $waveModeTransitionObserved -and
                        $spectrumTransitionObserved -and
                        $audioPanelDragObserved -and
                        $persistedStateVerified -and
                        $finalGeometryVerified
                    if (-not $audioPanelsExercised) {
                        throw "Audio-panel exercise did not retain Background Waveform, expanded Side Spectrogram, free toolbar position, and persisted state."
                    }
                }
                elseif ($chartExportModesExerciseEnabled) {
                    $primaryExportModesEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw |
                        ConvertFrom-Json
                    Assert-InteractionWindowRemaining `
                        -PrimaryEvidence $primaryExportModesEvidence `
                        -MinimumMilliseconds 22000

                    $commandMenuToggle = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Editor.CommandMenuToggle" `
                        -RootWindowHandle $process.MainWindowHandle `
                        -TimeoutMilliseconds 10000
                    Click-AutomationElementWithMouse -Element $commandMenuToggle.Element
                    Start-Sleep -Milliseconds 250
                    $exportButton = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Editor.Export" `
                        -RootWindowHandle $process.MainWindowHandle
                    if (-not [bool]$exportButton.Evidence.isEnabled) {
                        throw "Chart export button was disabled before the four-mode GUI exercise."
                    }
                    Click-AutomationElementWithMouse -Element $exportButton.Element
                    $optionsDialog = $null
                    $launchAutomationFallbackUsed = $false
                    try {
                        $optionsDialog = Find-AutomationElementById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog" `
                            -TimeoutMilliseconds 1800
                    }
                    catch {
                        if ($_.Exception.Message -notlike
                            "Timed out finding UI Automation id 'Export.MalodyFullPackage.Dialog'*") {
                            throw
                        }
                        Invoke-AutomationElement -Element $exportButton.Element
                        $launchAutomationFallbackUsed = $true
                        $optionsDialog = Find-AutomationElementById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog" `
                            -TimeoutMilliseconds 4500
                    }
                    $optionsDialogHandle = [IntPtr]$optionsDialog.Current.NativeWindowHandle
                    if ($optionsDialogHandle -eq [IntPtr]::Zero) {
                        throw "Chart export mode dialog did not expose a native window handle."
                    }
                    Set-ForegroundWindowVerified -WindowHandle $optionsDialogHandle
                    $defaultFormat = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Export.MalodyFullPackage.Dialog.Format" `
                        -RootWindowHandle $optionsDialogHandle

                    $readExportModeState = {
                        param([string]$ExpectedMode)

                        $mode = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                            -RootWindowHandle $optionsDialogHandle
                        if ([string]$mode.Evidence.name -ne $ExpectedMode) {
                            throw "Chart export mode was '$($mode.Evidence.name)' instead of '$ExpectedMode'."
                        }
                        $singleRateAbsent = Test-AutomationElementAbsentById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.SingleRate" `
                            -RootWindowHandle $optionsDialogHandle
                        $ratePackAbsent = Test-AutomationElementAbsentById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.MinimumRate" `
                            -RootWindowHandle $optionsDialogHandle
                        $singleRatePanel = if (-not $singleRateAbsent) {
                            $visibilityAnchor = Get-AutomationElementObservation `
                                -TargetProcessId $process.Id `
                                -AutomationId "Export.MalodyFullPackage.Dialog.SingleRate" `
                                -RootWindowHandle $optionsDialogHandle
                            [ordered]@{
                                requestedContainerAutomationId =
                                    "Export.MalodyFullPackage.Dialog.SingleRatePanel"
                                visibilityAnchorAutomationId =
                                    "Export.MalodyFullPackage.Dialog.SingleRate"
                                visibilityAnchor = $visibilityAnchor.Evidence
                                note = "Avalonia layout-only StackPanel is not emitted into the Windows UIA tree; the visible interactive Edit is the acceptance anchor."
                            }
                        } else { $null }
                        $singleRate = if (-not $singleRateAbsent) {
                            $valueObservation = Get-AutomationElementValueObservation `
                                -TargetProcessId $process.Id `
                                -AutomationId "Export.MalodyFullPackage.Dialog.SingleRate" `
                                -RootWindowHandle $optionsDialogHandle
                            [ordered]@{
                                control = $valueObservation.Evidence
                                value = $valueObservation.Value
                            }
                        } else { $null }
                        $ratePackPanel = if (-not $ratePackAbsent) {
                            $visibilityAnchor = Get-AutomationElementObservation `
                                -TargetProcessId $process.Id `
                                -AutomationId "Export.MalodyFullPackage.Dialog.MinimumRate" `
                                -RootWindowHandle $optionsDialogHandle
                            [ordered]@{
                                requestedContainerAutomationId =
                                    "Export.MalodyFullPackage.Dialog.RatePackPanel"
                                visibilityAnchorAutomationId =
                                    "Export.MalodyFullPackage.Dialog.MinimumRate"
                                visibilityAnchor = $visibilityAnchor.Evidence
                                note = "Avalonia layout-only StackPanel is not emitted into the Windows UIA tree; the visible interactive Edit is the acceptance anchor."
                            }
                        } else { $null }
                        $minimumRate = $null
                        $maximumRate = $null
                        $rateStep = $null
                        if (-not $ratePackAbsent) {
                            $minimumRateObservation = Get-AutomationElementValueObservation `
                                -TargetProcessId $process.Id `
                                -AutomationId "Export.MalodyFullPackage.Dialog.MinimumRate" `
                                -RootWindowHandle $optionsDialogHandle
                            $maximumRateObservation = Get-AutomationElementValueObservation `
                                -TargetProcessId $process.Id `
                                -AutomationId "Export.MalodyFullPackage.Dialog.MaximumRate" `
                                -RootWindowHandle $optionsDialogHandle
                            $rateStepObservation = Get-AutomationElementValueObservation `
                                -TargetProcessId $process.Id `
                                -AutomationId "Export.MalodyFullPackage.Dialog.RateStep" `
                                -RootWindowHandle $optionsDialogHandle
                            $minimumRate = [ordered]@{
                                control = $minimumRateObservation.Evidence
                                value = $minimumRateObservation.Value
                            }
                            $maximumRate = [ordered]@{
                                control = $maximumRateObservation.Evidence
                                value = $maximumRateObservation.Value
                            }
                            $rateStep = [ordered]@{
                                control = $rateStepObservation.Evidence
                                value = $rateStepObservation.Value
                            }
                        }
                        $preservePitch = Get-AutomationToggleObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.PreservePitch" `
                            -RootWindowHandle $optionsDialogHandle
                        return [ordered]@{
                            expectedMode = $ExpectedMode
                            mode = $mode.Evidence
                            singleRatePanelVisible = -not $singleRateAbsent
                            singleRatePanel = $singleRatePanel
                            singleRate = $singleRate
                            ratePackPanelVisible = -not $ratePackAbsent
                            ratePackPanel = $ratePackPanel
                            minimumRate = $minimumRate
                            maximumRate = $maximumRate
                            rateStep = $rateStep
                            preservePitch = $preservePitch.Evidence
                        }
                    }

                    $defaultState = & $readExportModeState "整谱压缩包"
                    $defaultCancel = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Export.MalodyFullPackage.Dialog.Cancel" `
                        -RootWindowHandle $optionsDialogHandle
                    $defaultConfirm = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Export.MalodyFullPackage.Dialog.Confirm" `
                        -RootWindowHandle $optionsDialogHandle
                    Save-AutomationElementScreenshot `
                        -Element $optionsDialog `
                        -Path $chartExportModesDefaultScreenshotFullPath
                    $chartExportModesDefaultScreenshotSha256 =
                        (Get-FileHash -LiteralPath $chartExportModesDefaultScreenshotFullPath -Algorithm SHA256).Hash

                    $singleChartSelection = Select-AutomationComboItemWithRecordedMouse `
                        -TargetProcessId $process.Id `
                        -ComboAutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                        -ItemName "单谱文件（不包含资源）" `
                        -RootWindowHandle $optionsDialogHandle
                    $singleChartState = & $readExportModeState "单谱文件（不包含资源）"
                    Save-AutomationElementScreenshot `
                        -Element $optionsDialog `
                        -Path $chartExportModesSingleChartScreenshotFullPath
                    $chartExportModesSingleChartScreenshotSha256 =
                        (Get-FileHash -LiteralPath $chartExportModesSingleChartScreenshotFullPath -Algorithm SHA256).Hash

                    $singleRateSelection = Select-AutomationComboItemWithRecordedMouse `
                        -TargetProcessId $process.Id `
                        -ComboAutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                        -ItemName "单一倍速压缩包" `
                        -RootWindowHandle $optionsDialogHandle
                    $singleRateStateBeforePitch = & $readExportModeState "单一倍速压缩包"
                    $preservePitchBeforeToggle = Get-AutomationToggleObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Export.MalodyFullPackage.Dialog.PreservePitch" `
                        -RootWindowHandle $optionsDialogHandle
                    Click-AutomationElementWithMouse -Element $preservePitchBeforeToggle.Element
                    $preservePitchAutomationFallbackUsed = $false
                    try {
                        Wait-AutomationToggleStateById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.PreservePitch" `
                            -ExpectedState ([System.Windows.Automation.ToggleState]::On) `
                            -RootWindowHandle $optionsDialogHandle `
                            -TimeoutMilliseconds 1600 | Out-Null
                    }
                    catch {
                        $preservePitchAfterPhysical = Get-AutomationToggleObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.PreservePitch" `
                            -RootWindowHandle $optionsDialogHandle
                        $toggleObject = $null
                        if (-not $preservePitchAfterPhysical.Element.TryGetCurrentPattern(
                                [System.Windows.Automation.TogglePattern]::Pattern,
                                [ref]$toggleObject)) {
                            throw "PreservePitch lost TogglePattern after its physical click."
                        }
                        ([System.Windows.Automation.TogglePattern]$toggleObject).Toggle()
                        $preservePitchAutomationFallbackUsed = $true
                        Wait-AutomationToggleStateById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.PreservePitch" `
                            -ExpectedState ([System.Windows.Automation.ToggleState]::On) `
                            -RootWindowHandle $optionsDialogHandle | Out-Null
                    }
                    $singleRateState = & $readExportModeState "单一倍速压缩包"
                    $preservePitchAction = [ordered]@{
                        input = "physical Win32 mouse click at checkbox UI Automation bounds"
                        requestedState = "On"
                        before = $preservePitchBeforeToggle.Evidence
                        after = $singleRateState.preservePitch
                        physicalClickAttempted = $true
                        physicalClickRetained = -not $preservePitchAutomationFallbackUsed
                        automationToggleFallbackUsed = $preservePitchAutomationFallbackUsed
                    }
                    Save-AutomationElementScreenshot `
                        -Element $optionsDialog `
                        -Path $chartExportModesSingleRateScreenshotFullPath
                    $chartExportModesSingleRateScreenshotSha256 =
                        (Get-FileHash -LiteralPath $chartExportModesSingleRateScreenshotFullPath -Algorithm SHA256).Hash

                    $ratePackSelection = Select-AutomationComboItemWithRecordedMouse `
                        -TargetProcessId $process.Id `
                        -ComboAutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                        -ItemName "范围倍速包" `
                        -RootWindowHandle $optionsDialogHandle
                    $ratePackState = & $readExportModeState "范围倍速包"
                    Save-AutomationElementScreenshot `
                        -Element $optionsDialog `
                        -Path $chartExportModesRatePackScreenshotFullPath
                    $chartExportModesRatePackScreenshotSha256 =
                        (Get-FileHash -LiteralPath $chartExportModesRatePackScreenshotFullPath -Algorithm SHA256).Hash

                    $singleRateInvalidSelection = Select-AutomationComboItemWithRecordedMouse `
                        -TargetProcessId $process.Id `
                        -ComboAutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                        -ItemName "单一倍速压缩包" `
                        -RootWindowHandle $optionsDialogHandle
                    $hiddenRateInput = Set-AutomationTextWithCommittedPhysicalInput `
                        -TargetProcessId $process.Id `
                        -AutomationId "Export.MalodyFullPackage.Dialog.SingleRate" `
                        -Value "invalid" `
                        -CommitByFocusLossAutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                        -RootWindowHandle $optionsDialogHandle
                    $fullPackageReturnSelection = Select-AutomationComboItemWithRecordedMouse `
                        -TargetProcessId $process.Id `
                        -ComboAutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                        -ItemName "整谱压缩包" `
                        -RootWindowHandle $optionsDialogHandle
                    $retainedFullPackageState = & $readExportModeState "整谱压缩包"
                    $validationBeforeConfirm = $null
                    try {
                        $validationBeforeConfirm = Find-AutomationElementById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.Validation" `
                            -RootWindowHandle $optionsDialogHandle `
                            -TimeoutMilliseconds 500
                    }
                    catch {
                        if ($_.Exception.Message -notlike
                            "Timed out finding UI Automation id 'Export.MalodyFullPackage.Dialog.Validation'*") {
                            throw
                        }
                    }
                    $validationBeforeConfirmName = if ($validationBeforeConfirm) {
                        [string]$validationBeforeConfirm.Current.Name
                    } else { "" }
                    if (-not [string]::IsNullOrEmpty($validationBeforeConfirmName)) {
                        throw "Chart export validation was already visible before the hidden-field Confirm click."
                    }
                    $confirm = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Export.MalodyFullPackage.Dialog.Confirm" `
                        -RootWindowHandle $optionsDialogHandle
                    Click-AutomationElementWithMouse -Element $confirm.Element
                    $validationExpected = "倍速范围为 0.2–3，结束值不能小于起始值，间隔范围为 0.01–1。"
                    $validation = $null
                    $validationDeadline = [DateTime]::UtcNow.AddMilliseconds(1800)
                    do {
                        try {
                            $validation = Get-AutomationElementObservation `
                                -TargetProcessId $process.Id `
                                -AutomationId "Export.MalodyFullPackage.Dialog.Validation" `
                                -RootWindowHandle $optionsDialogHandle `
                                -TimeoutMilliseconds 300
                        }
                        catch { }
                        if ($validation -and [string]$validation.Evidence.name -eq $validationExpected) { break }
                        Start-Sleep -Milliseconds 80
                    }
                    while ([DateTime]::UtcNow -lt $validationDeadline)
                    $confirmAutomationFallbackUsed = $false
                    if (-not $validation -or [string]$validation.Evidence.name -ne $validationExpected) {
                        Invoke-AutomationElement -Element $confirm.Element
                        $confirmAutomationFallbackUsed = $true
                        Start-Sleep -Milliseconds 180
                        $validation = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.Validation" `
                            -RootWindowHandle $optionsDialogHandle
                    }
                    if ([string]$validation.Evidence.name -ne $validationExpected) {
                        throw "Hidden SingleRate validation did not block FullPackage confirmation with the exact WPF-compatible message."
                    }
                    Save-AutomationElementScreenshot `
                        -Element $optionsDialog `
                        -Path $chartExportModesHiddenValidationScreenshotFullPath
                    $chartExportModesHiddenValidationScreenshotSha256 =
                        (Get-FileHash -LiteralPath $chartExportModesHiddenValidationScreenshotFullPath -Algorithm SHA256).Hash

                    $defaultsVerified =
                        [string]$defaultFormat.Evidence.name -eq "Malody (.mc / .mcz)" -and
                        -not [bool]$defaultState.singleRatePanelVisible -and
                        -not [bool]$defaultState.ratePackPanelVisible -and
                        [bool]$defaultState.preservePitch.isEnabled -and
                        -not [bool]$defaultState.preservePitch.isChecked
                    $singleChartVerified =
                        -not [bool]$singleChartState.singleRatePanelVisible -and
                        -not [bool]$singleChartState.ratePackPanelVisible -and
                        -not [bool]$singleChartState.preservePitch.isEnabled
                    $singleRateVerified =
                        [string]$singleRateStateBeforePitch.singleRate.value -eq "1.2" -and
                        [bool]$singleRateStateBeforePitch.preservePitch.isEnabled -and
                        -not [bool]$singleRateStateBeforePitch.preservePitch.isChecked -and
                        [bool]$singleRateState.singleRatePanelVisible -and
                        -not [bool]$singleRateState.ratePackPanelVisible -and
                        [string]$singleRateState.singleRate.value -eq "1.2" -and
                        [bool]$singleRateState.preservePitch.isEnabled -and
                        [bool]$singleRateState.preservePitch.isChecked
                    $ratePackVerified =
                        -not [bool]$ratePackState.singleRatePanelVisible -and
                        [bool]$ratePackState.ratePackPanelVisible -and
                        [string]$ratePackState.minimumRate.value -eq "0.8" -and
                        [string]$ratePackState.maximumRate.value -eq "1.2" -and
                        [string]$ratePackState.rateStep.value -eq "0.1" -and
                        [bool]$ratePackState.preservePitch.isEnabled -and
                        [bool]$ratePackState.preservePitch.isChecked
                    $retentionVerified =
                        -not [bool]$retainedFullPackageState.singleRatePanelVisible -and
                        -not [bool]$retainedFullPackageState.ratePackPanelVisible -and
                        -not [bool]$retainedFullPackageState.preservePitch.isEnabled -and
                        [bool]$retainedFullPackageState.preservePitch.isChecked
                    $hiddenValidationVerified =
                        [string]$hiddenRateInput.after.value -eq "invalid" -and
                        -not [bool]$retainedFullPackageState.singleRatePanelVisible -and
                        [string]$validation.Evidence.name -eq $validationExpected
                    $chartExportModesExercised = $defaultsVerified -and
                        $singleChartVerified -and $singleRateVerified -and
                        $ratePackVerified -and $retentionVerified -and
                        $hiddenValidationVerified
                    if (-not $chartExportModesExercised) {
                        $verificationDiagnostics = [ordered]@{
                            defaultsVerified = $defaultsVerified
                            singleChartVerified = $singleChartVerified
                            singleRateVerified = $singleRateVerified
                            ratePackVerified = $ratePackVerified
                            retentionVerified = $retentionVerified
                            hiddenValidationVerified = $hiddenValidationVerified
                            defaultState = $defaultState
                            singleChartState = $singleChartState
                            singleRateStateBeforePitch = $singleRateStateBeforePitch
                            singleRateState = $singleRateState
                            ratePackState = $ratePackState
                            retainedFullPackageState = $retainedFullPackageState
                            hiddenRateInputAfter = $hiddenRateInput.after
                            validationName = [string]$validation.Evidence.name
                            validationExpected = $validationExpected
                        }
                        $verificationDiagnosticsJson = $verificationDiagnostics |
                            ConvertTo-Json -Depth 12 -Compress
                        throw "Chart export four-mode state, pitch retention, defaults, or hidden-field validation did not match the required WPF behavior. Diagnostics: $verificationDiagnosticsJson"
                    }
                    $chartExportModesEvidence = [ordered]@{
                        dialog = [ordered]@{
                            automationId = [string]$optionsDialog.Current.AutomationId
                            name = [string]$optionsDialog.Current.Name
                            nativeWindowHandle = [long]$optionsDialogHandle
                            bounds = [ordered]@{
                                left = [double]$optionsDialog.Current.BoundingRectangle.Left
                                top = [double]$optionsDialog.Current.BoundingRectangle.Top
                                width = [double]$optionsDialog.Current.BoundingRectangle.Width
                                height = [double]$optionsDialog.Current.BoundingRectangle.Height
                            }
                        }
                        launch = [ordered]@{
                            input = "physical Win32 mouse click at Editor.Export UI Automation bounds"
                            button = $exportButton.Evidence
                            physicalClickAttempted = $true
                            physicalClickRetained = -not $launchAutomationFallbackUsed
                            automationInvokeFallbackUsed = $launchAutomationFallbackUsed
                        }
                        defaultFullPackage = [ordered]@{
                            format = $defaultFormat.Evidence
                            state = $defaultState
                            cancel = $defaultCancel.Evidence
                            confirm = $defaultConfirm.Evidence
                            screenshotPath = $chartExportModesDefaultScreenshotFullPath
                            screenshotSha256 = $chartExportModesDefaultScreenshotSha256
                            verified = $defaultsVerified
                        }
                        singleChart = [ordered]@{
                            selection = $singleChartSelection
                            state = $singleChartState
                            screenshotPath = $chartExportModesSingleChartScreenshotFullPath
                            screenshotSha256 = $chartExportModesSingleChartScreenshotSha256
                            verified = $singleChartVerified
                        }
                        singleRatePackage = [ordered]@{
                            selection = $singleRateSelection
                            stateBeforePitch = $singleRateStateBeforePitch
                            pitchAction = $preservePitchAction
                            state = $singleRateState
                            screenshotPath = $chartExportModesSingleRateScreenshotFullPath
                            screenshotSha256 = $chartExportModesSingleRateScreenshotSha256
                            verified = $singleRateVerified
                        }
                        ratePack = [ordered]@{
                            selection = $ratePackSelection
                            state = $ratePackState
                            screenshotPath = $chartExportModesRatePackScreenshotFullPath
                            screenshotSha256 = $chartExportModesRatePackScreenshotSha256
                            verified = $ratePackVerified
                        }
                        hiddenFieldValidation = [ordered]@{
                            returnToSingleRateSelection = $singleRateInvalidSelection
                            invalidInput = $hiddenRateInput
                            returnToFullPackageSelection = $fullPackageReturnSelection
                            fullPackageState = $retainedFullPackageState
                            confirm = [ordered]@{
                                input = "physical Win32 mouse click at Confirm UI Automation bounds"
                                physicalClickAttempted = $true
                                physicalClickRetained = -not $confirmAutomationFallbackUsed
                                automationInvokeFallbackUsed = $confirmAutomationFallbackUsed
                                control = $confirm.Evidence
                            }
                            expectedMessage = $validationExpected
                            validationBeforeConfirm = [ordered]@{
                                elementPresent = $null -ne $validationBeforeConfirm
                                name = $validationBeforeConfirmName
                                empty = [string]::IsNullOrEmpty($validationBeforeConfirmName)
                            }
                            validation = $validation.Evidence
                            screenshotPath = $chartExportModesHiddenValidationScreenshotFullPath
                            screenshotSha256 = $chartExportModesHiddenValidationScreenshotSha256
                            preservedPitchCheckedWhileDisabled = $retentionVerified
                            hiddenSingleRateRejected = $hiddenValidationVerified
                            verified = $retentionVerified -and $hiddenValidationVerified
                        }
                        modeSwitchCount = 5
                        allModeSelectionsUsedPhysicalPointer =
                            -not [bool]$singleChartSelection.automationSelectionFallbackUsed -and
                            -not [bool]$singleRateSelection.automationSelectionFallbackUsed -and
                            -not [bool]$ratePackSelection.automationSelectionFallbackUsed -and
                            -not [bool]$singleRateInvalidSelection.automationSelectionFallbackUsed -and
                            -not [bool]$fullPackageReturnSelection.automationSelectionFallbackUsed
                        anyAutomationFallbackUsed =
                            [bool]$launchAutomationFallbackUsed -or
                            [bool]$singleChartSelection.automationSelectionFallbackUsed -or
                            [bool]$singleRateSelection.automationSelectionFallbackUsed -or
                            [bool]$ratePackSelection.automationSelectionFallbackUsed -or
                            [bool]$singleRateInvalidSelection.automationSelectionFallbackUsed -or
                            [bool]$fullPackageReturnSelection.automationSelectionFallbackUsed -or
                            [bool]$preservePitchAutomationFallbackUsed -or
                            [bool]$hiddenRateInput.automationValueFallbackUsed -or
                            [bool]$hiddenRateInput.automationInputFocusFallbackUsed -or
                            [bool]$hiddenRateInput.automationFocusFallbackUsed -or
                            [bool]$confirmAutomationFallbackUsed
                        verified = $chartExportModesExercised
                    }

                    if ($chartExportModesActualExportEnabled) {
                        $configureActualExportDialog = {
                            param([Parameter(Mandatory = $true)][IntPtr]$DialogHandle)

                            $hiddenRateRepair = $null
                            if ($ChartExportModesExportMode -ne "SingleRatePackage") {
                                $hiddenRateRepairSelection =
                                    Select-AutomationComboItemWithRecordedMouse `
                                        -TargetProcessId $process.Id `
                                        -ComboAutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                                        -ItemName "单一倍速压缩包" `
                                        -RootWindowHandle $DialogHandle
                                $hiddenRateRepairInput =
                                    Set-AutomationTextWithCommittedPhysicalInput `
                                        -TargetProcessId $process.Id `
                                        -AutomationId "Export.MalodyFullPackage.Dialog.SingleRate" `
                                        -Value "1.2" `
                                        -CommitByFocusLossAutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                                        -RootWindowHandle $DialogHandle
                                $hiddenRateRepair = [ordered]@{
                                    reason =
                                        "The preceding fail-closed parity gate intentionally " +
                                        "left the shared dialog's hidden SingleRate invalid."
                                    selection = $hiddenRateRepairSelection
                                    input = $hiddenRateRepairInput
                                    restoredValue = "1.2"
                                }
                            }
                            $requestedModeItem = switch ($ChartExportModesExportMode) {
                                "SingleChart" { "单谱文件（不包含资源）" }
                                "SingleRatePackage" { "单一倍速压缩包" }
                                "RatePack" { "范围倍速包" }
                                default { throw "Unsupported actual chart-export mode: $ChartExportModesExportMode" }
                            }
                            $modeSelection = Select-AutomationComboItemWithRecordedMouse `
                                -TargetProcessId $process.Id `
                                -ComboAutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                                -ItemName $requestedModeItem `
                                -RootWindowHandle $DialogHandle
                            $rateInput = $null
                            if ($ChartExportModesExportMode -eq "SingleRatePackage") {
                                $actualRateText = $ChartExportModesExportRate.ToString(
                                    "0.################",
                                    [Globalization.CultureInfo]::InvariantCulture)
                                $rateInput = Set-AutomationTextWithCommittedPhysicalInput `
                                    -TargetProcessId $process.Id `
                                    -AutomationId "Export.MalodyFullPackage.Dialog.SingleRate" `
                                    -Value $actualRateText `
                                    -CommitByFocusLossAutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                                    -RootWindowHandle $DialogHandle
                            }
                            $rangeInputs = $null
                            if ($ChartExportModesExportMode -eq "RatePack") {
                                $minimumRateText =
                                    $ChartExportModesExportMinimumRate.ToString(
                                        "0.################",
                                        [Globalization.CultureInfo]::InvariantCulture)
                                $maximumRateText =
                                    $ChartExportModesExportMaximumRate.ToString(
                                        "0.################",
                                        [Globalization.CultureInfo]::InvariantCulture)
                                $rateStepText =
                                    $ChartExportModesExportRateStep.ToString(
                                        "0.################",
                                        [Globalization.CultureInfo]::InvariantCulture)
                                $rangeInputs = [ordered]@{
                                    minimum = Set-AutomationTextWithCommittedPhysicalInput `
                                        -TargetProcessId $process.Id `
                                        -AutomationId "Export.MalodyFullPackage.Dialog.MinimumRate" `
                                        -Value $minimumRateText `
                                        -CommitByFocusLossAutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                                        -RootWindowHandle $DialogHandle
                                    maximum = Set-AutomationTextWithCommittedPhysicalInput `
                                        -TargetProcessId $process.Id `
                                        -AutomationId "Export.MalodyFullPackage.Dialog.MaximumRate" `
                                        -Value $maximumRateText `
                                        -CommitByFocusLossAutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                                        -RootWindowHandle $DialogHandle
                                    step = Set-AutomationTextWithCommittedPhysicalInput `
                                        -TargetProcessId $process.Id `
                                        -AutomationId "Export.MalodyFullPackage.Dialog.RateStep" `
                                        -Value $rateStepText `
                                        -CommitByFocusLossAutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                                        -RootWindowHandle $DialogHandle
                                }
                            }
                            $formatSelection = $null
                            if ($ChartExportModesExportFormat -eq "OsuMania") {
                                $formatSelection = Select-AutomationComboItemWithRecordedMouse `
                                    -TargetProcessId $process.Id `
                                    -ComboAutomationId "Export.MalodyFullPackage.Dialog.Format" `
                                    -ItemName "osu!mania v14 (.osu / .osz)" `
                                    -RootWindowHandle $DialogHandle
                            }
                            else {
                                $actualFormat = Get-AutomationElementObservation `
                                    -TargetProcessId $process.Id `
                                    -AutomationId "Export.MalodyFullPackage.Dialog.Format" `
                                    -RootWindowHandle $DialogHandle
                                if ([string]$actualFormat.Evidence.name -ne "Malody (.mc / .mcz)") {
                                    throw "Actual $ChartExportModesExportMode export did not retain the requested Malody format."
                                }
                                $formatSelection = [ordered]@{
                                    requested = "Malody (.mc / .mcz)"
                                    input = "retained default selection"
                                    physicalClickAttempted = $false
                                    physicalSelectionRetained = $true
                                    automationSelectionFallbackUsed = $false
                                    after = $actualFormat.Evidence
                                }
                            }
                            $pitchBefore = Get-AutomationToggleObservation `
                                -TargetProcessId $process.Id `
                                -AutomationId "Export.MalodyFullPackage.Dialog.PreservePitch" `
                                -RootWindowHandle $DialogHandle
                            $pitchSupported = $ChartExportModesExportMode -in
                                @("SingleRatePackage", "RatePack")
                            $pitchFallbackUsed = $false
                            $pitchNeedsClick = $pitchSupported -and
                                (([bool]$pitchBefore.Evidence.isChecked) -ne
                                 [bool]$ChartExportModesExportPreservePitch)
                            if (-not $pitchSupported -and [bool]$pitchBefore.Evidence.isEnabled) {
                                throw "$ChartExportModesExportMode unexpectedly enabled PreservePitch."
                            }
                            if ($pitchNeedsClick) {
                                $desiredPitchState = if ($ChartExportModesExportPreservePitch) {
                                    [System.Windows.Automation.ToggleState]::On
                                } else { [System.Windows.Automation.ToggleState]::Off }
                                Click-AutomationElementWithMouse -Element $pitchBefore.Element
                                try {
                                    Wait-AutomationToggleStateById `
                                        -TargetProcessId $process.Id `
                                        -AutomationId "Export.MalodyFullPackage.Dialog.PreservePitch" `
                                        -ExpectedState $desiredPitchState `
                                        -RootWindowHandle $DialogHandle `
                                        -TimeoutMilliseconds 1600 | Out-Null
                                }
                                catch {
                                    $actualPitchRetry = Get-AutomationToggleObservation `
                                        -TargetProcessId $process.Id `
                                        -AutomationId "Export.MalodyFullPackage.Dialog.PreservePitch" `
                                        -RootWindowHandle $DialogHandle
                                    $toggleObject = $null
                                    if (-not $actualPitchRetry.Element.TryGetCurrentPattern(
                                            [System.Windows.Automation.TogglePattern]::Pattern,
                                            [ref]$toggleObject)) {
                                        throw "Actual export PreservePitch lost TogglePattern after its physical click."
                                    }
                                    ([System.Windows.Automation.TogglePattern]$toggleObject).Toggle()
                                    $pitchFallbackUsed = $true
                                    Wait-AutomationToggleStateById `
                                        -TargetProcessId $process.Id `
                                        -AutomationId "Export.MalodyFullPackage.Dialog.PreservePitch" `
                                        -ExpectedState $desiredPitchState `
                                        -RootWindowHandle $DialogHandle | Out-Null
                                }
                            }
                            $pitchAfter = Get-AutomationToggleObservation `
                                -TargetProcessId $process.Id `
                                -AutomationId "Export.MalodyFullPackage.Dialog.PreservePitch" `
                                -RootWindowHandle $DialogHandle
                            if ($pitchSupported -and
                                (([bool]$pitchAfter.Evidence.isChecked) -ne
                                 [bool]$ChartExportModesExportPreservePitch)) {
                                throw "Actual export PreservePitch did not retain the requested state."
                            }
                            [ordered]@{
                                modeSelection = $modeSelection
                                rateInput = $rateInput
                                rangeInputs = $rangeInputs
                                hiddenRateRepair = $hiddenRateRepair
                                formatSelection = $formatSelection
                                preservePitch = [ordered]@{
                                    supported = $pitchSupported
                                    before = $pitchBefore.Evidence
                                    after = $pitchAfter.Evidence
                                    physicalClickAttempted = $pitchNeedsClick
                                    automationToggleFallbackUsed = $pitchFallbackUsed
                                }
                            }
                        }

                        $actualConfiguration = & $configureActualExportDialog $optionsDialogHandle
                        $edgeCancelEvidence = $null
                        if ($chartExportModesNativeSaveEdgeEnabled) {
                            $cancelConfirm = Get-AutomationElementObservation `
                                -TargetProcessId $process.Id `
                                -AutomationId "Export.MalodyFullPackage.Dialog.Confirm" `
                                -RootWindowHandle $optionsDialogHandle
                            Click-AutomationElementWithMouse -Element $cancelConfirm.Element
                            $cancelSaveDialog = Find-AutomationElementByName `
                                -TargetProcessId $process.Id `
                                -Name "选择导出位置" `
                                -TimeoutMilliseconds 7000
                            $cancelSaveHandle = [IntPtr]$cancelSaveDialog.Current.NativeWindowHandle
                            if ($cancelSaveHandle -eq [IntPtr]::Zero) {
                                throw "Native Save cancellation picker did not expose a window handle."
                            }
                            $cancelPickerEvidence =
                                Get-NativeDialogElementEvidence -Element $cancelSaveDialog
                            Set-ForegroundWindowVerified -WindowHandle $cancelSaveHandle
                            $cancelDirectoryEvidence = Get-NativeFilePickerAddressEvidence `
                                -DialogElement $cancelSaveDialog `
                                -ExpectedDirectory ([IO.Path]::GetDirectoryName(
                                    $chartExportModesExportFullPath))
                            Save-AutomationElementScreenshot `
                                -Element $cancelSaveDialog `
                                -Path $chartExportModesCancelScreenshotFullPath
                            $chartExportModesCancelScreenshotSha256 =
                                (Get-FileHash `
                                    -LiteralPath $chartExportModesCancelScreenshotFullPath `
                                    -Algorithm SHA256).Hash
                            $cancelButton = Find-NativeDialogButton `
                                -DialogElement $cancelSaveDialog `
                                -NamePattern '^(取消|Cancel)' `
                                -PreferredAutomationIds @('2', 'CommandButton_2')
                            Click-AutomationElementWithMouse -Element $cancelButton.Element
                            $cancelCloseDeadline = [DateTime]::UtcNow.AddSeconds(5)
                            while ([LumaChartAvaloniaCaptureNative]::IsWindow($cancelSaveHandle) -and
                                   [DateTime]::UtcNow -lt $cancelCloseDeadline) {
                                Start-Sleep -Milliseconds 80
                            }
                            if ([LumaChartAvaloniaCaptureNative]::IsWindow($cancelSaveHandle)) {
                                throw "Native Save picker did not close after its physical Cancel click."
                            }
                            $targetAfterCancel = Get-Item -LiteralPath $chartExportModesExportFullPath
                            $targetAfterCancelSha256 = (Get-FileHash `
                                -LiteralPath $chartExportModesExportFullPath `
                                -Algorithm SHA256).Hash
                            if ([long]$targetAfterCancel.Length -ne
                                    [long]$chartExportModesExistingTargetBefore.length -or
                                $targetAfterCancelSha256 -cne
                                    [string]$chartExportModesExistingTargetBefore.sha256 -or
                                (Test-Path -LiteralPath $chartExportModesForbiddenOutputFullPath)) {
                                throw "Canceling the first native Save changed the existing target or created the forbidden secondary-extension output."
                            }
                            $reopenExportButton = $null
                            $reopenExportDeadline = [DateTime]::UtcNow.AddSeconds(5)
                            do {
                                $reopenExportButton = Get-AutomationElementObservation `
                                    -TargetProcessId $process.Id `
                                    -AutomationId "Editor.Export" `
                                    -RootWindowHandle $process.MainWindowHandle
                                if ([bool]$reopenExportButton.Evidence.isEnabled) { break }
                                Start-Sleep -Milliseconds 80
                            } while ([DateTime]::UtcNow -lt $reopenExportDeadline)
                            if (-not [bool]$reopenExportButton.Evidence.isEnabled) {
                                throw "Editor.Export was not re-enabled after the native Save cancellation."
                            }
                            Set-ForegroundWindowVerified -WindowHandle $process.MainWindowHandle
                            Click-AutomationElementWithMouse -Element $reopenExportButton.Element
                            $optionsDialog = Find-AutomationElementById `
                                -TargetProcessId $process.Id `
                                -AutomationId "Export.MalodyFullPackage.Dialog" `
                                -TimeoutMilliseconds 5000
                            $optionsDialogHandle = [IntPtr]$optionsDialog.Current.NativeWindowHandle
                            if ($optionsDialogHandle -eq [IntPtr]::Zero) {
                                throw "Chart export dialog did not reopen after native Save cancellation."
                            }
                            Set-ForegroundWindowVerified -WindowHandle $optionsDialogHandle
                            $configurationBeforeCancel = $actualConfiguration
                            $actualConfiguration = & $configureActualExportDialog $optionsDialogHandle
                            $edgeCancelEvidence = [ordered]@{
                                scenario = $ChartExportModesNativeSaveEdgeScenario
                                confirm = $cancelConfirm.Evidence
                                picker = $cancelPickerEvidence
                                directory = $cancelDirectoryEvidence
                                screenshotPath = $chartExportModesCancelScreenshotFullPath
                                screenshotSha256 = $chartExportModesCancelScreenshotSha256
                                cancelButton = $cancelButton.Evidence
                                input = "physical Win32 mouse click at native Cancel button bounds"
                                dialogClosedAfterCancel = $true
                                existingTargetBefore = $chartExportModesExistingTargetBefore
                                existingTargetAfterCancel = [ordered]@{
                                    path = $chartExportModesExportFullPath
                                    length = [long]$targetAfterCancel.Length
                                    sha256 = $targetAfterCancelSha256
                                }
                                targetUnchanged = $true
                                forbiddenOutputAbsent = $true
                                exportButtonAfterCancel = $reopenExportButton.Evidence
                                reopenedWithPhysicalPointer = $true
                                configurationBeforeCancel = $configurationBeforeCancel
                                configurationAfterReopen = $actualConfiguration
                                verified = $true
                            }
                        }
                        $actualModeSelection = $actualConfiguration.modeSelection
                        $actualRateInput = $actualConfiguration.rateInput
                        $actualRangeInputs = $actualConfiguration.rangeInputs
                        $actualHiddenRateRepair = $actualConfiguration.hiddenRateRepair
                        $actualFormatSelection = $actualConfiguration.formatSelection
                        $actualPitchBefore = $actualConfiguration.preservePitch.before
                        $actualPitchAfter = $actualConfiguration.preservePitch.after
                        $actualPitchNeedsClick =
                            [bool]$actualConfiguration.preservePitch.physicalClickAttempted
                        $actualPitchFallbackUsed =
                            [bool]$actualConfiguration.preservePitch.automationToggleFallbackUsed
                        $actualConfirm = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.Confirm" `
                            -RootWindowHandle $optionsDialogHandle
                        Click-AutomationElementWithMouse -Element $actualConfirm.Element

                        $nativeSaveDialog = Find-AutomationElementByName `
                            -TargetProcessId $process.Id `
                            -Name "选择导出位置" `
                            -TimeoutMilliseconds 7000
                        $nativeSaveHandle = [IntPtr]$nativeSaveDialog.Current.NativeWindowHandle
                        if ($nativeSaveHandle -eq [IntPtr]::Zero) {
                            throw "Actual $ChartExportModesExportMode native Save picker did not expose a window handle."
                        }
                        $nativeDirectory = [IO.Path]::GetDirectoryName($chartExportModesExportFullPath)
                        $nativeLeaf = if ($chartExportModesNativeSaveEdgeEnabled) {
                            [IO.Path]::GetFileName($chartExportModesForbiddenOutputFullPath)
                        } else {
                            [IO.Path]::GetFileName($chartExportModesExportFullPath)
                        }
                        $nativeDirectoryEvidence = Get-NativeFilePickerAddressEvidence `
                            -DialogElement $nativeSaveDialog `
                            -ExpectedDirectory $nativeDirectory
                        $fileNameHost = Find-AutomationElementById `
                            -TargetProcessId $process.Id `
                            -AutomationId "FileNameControlHost" `
                            -RootWindowHandle $nativeSaveHandle `
                            -TimeoutMilliseconds 5000
                        $filenameIdCondition = [System.Windows.Automation.PropertyCondition]::new(
                            [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
                            "1001")
                        $saveName = $fileNameHost.FindFirst(
                            [System.Windows.Automation.TreeScope]::Descendants,
                            $filenameIdCondition)
                        if (-not $saveName) {
                            throw "Actual $ChartExportModesExportMode Save picker did not expose editable filename child 1001."
                        }
                        Set-ForegroundWindowVerified -WindowHandle $nativeSaveHandle
                        Click-AutomationElementWithMouse -Element $saveName
                        Start-Sleep -Milliseconds 100
                        $nativeFocusBefore = Get-FocusedAutomationElementEvidence
                        $nativeInputFocusAutomationFallbackUsed = $false
                        $nativeInputFocusAutomationFallbackError = ""
                        if ([string]$nativeFocusBefore.Evidence.automationId -ne "1001" -or
                            [int]$nativeFocusBefore.Evidence.processId -ne $process.Id) {
                            $nativeInputFocusAutomationFallbackUsed = $true
                            try {
                                $saveName.SetFocus()
                            }
                            catch {
                                $nativeInputFocusAutomationFallbackError = $_.Exception.Message
                            }
                            Start-Sleep -Milliseconds 120
                            $nativeFocusBefore = Get-FocusedAutomationElementEvidence
                        }
                        if ([string]$nativeFocusBefore.Evidence.automationId -ne "1001" -or
                            [int]$nativeFocusBefore.Evidence.processId -ne $process.Id) {
                            throw "Actual $ChartExportModesExportMode filename field did not receive keyboard focus after its physical click and recorded fallback. Fallback error: $nativeInputFocusAutomationFallbackError"
                        }
                        [System.Windows.Forms.SendKeys]::SendWait("^a")
                        $expectedNativeInputEvents = [uint]($nativeLeaf.Length * 2)
                        $nativeInputEvents = [LumaChartAvaloniaCaptureNative]::SendUnicodeText($nativeLeaf)
                        Start-Sleep -Milliseconds 180
                        $nativeNamePatternObject = $null
                        $nativeNamePattern = $null
                        $nativeFilenameReadProvider = "AutomationElement.Current.Name"
                        if ($saveName.TryGetCurrentPattern(
                                [System.Windows.Automation.ValuePattern]::Pattern,
                                [ref]$nativeNamePatternObject)) {
                            $nativeNamePattern =
                                [System.Windows.Automation.ValuePattern]$nativeNamePatternObject
                            $nativeFilenameReadProvider = "ValuePattern.Current.Value"
                            $nativeRetainedLeaf = [string]$nativeNamePattern.Current.Value
                        }
                        else {
                            $nativeRetainedLeaf = [string]$saveName.Current.Name
                        }
                        $nativeFilenameFallbackUsed = $false
                        if ($nativeInputEvents -ne $expectedNativeInputEvents -or
                            $nativeRetainedLeaf -ne $nativeLeaf) {
                            if ($nativeNamePattern) {
                                $nativeNamePattern.SetValue($nativeLeaf)
                                $nativeFilenameFallbackUsed = $true
                            }
                            else {
                                Set-ForegroundWindowVerified -WindowHandle $nativeSaveHandle
                                Click-AutomationElementWithMouse -Element $saveName
                                [System.Windows.Forms.SendKeys]::SendWait("%n")
                                [System.Windows.Forms.SendKeys]::SendWait("^a")
                                $nativeInputEvents =
                                    [LumaChartAvaloniaCaptureNative]::SendUnicodeText($nativeLeaf)
                            }
                            Start-Sleep -Milliseconds 180
                            if ($nativeNamePattern) {
                                $nativeRetainedLeaf = [string]$nativeNamePattern.Current.Value
                            }
                            else {
                                $nativeRetainedLeaf = [string]$saveName.Current.Name
                            }
                        }
                        if ($nativeRetainedLeaf -ne $nativeLeaf) {
                            throw "Actual $ChartExportModesExportMode Save picker did not retain exact leaf '$nativeLeaf'."
                        }
                        $nativeSubmitButtonEvidence = $null
                        if ($chartExportModesNativeSaveEdgeEnabled) {
                            $nativeSubmitButton = Find-NativeDialogButton `
                                -DialogElement $nativeSaveDialog `
                                -NamePattern '^(保存|Save)' `
                                -PreferredAutomationIds @('1', 'CommandButton_1')
                            Set-ForegroundWindowVerified `
                                -WindowHandle $nativeSaveHandle
                            Click-AutomationElementWithMouse `
                                -Element $nativeSubmitButton.Element
                            $nativeSubmitButtonEvidence =
                                $nativeSubmitButton.Evidence
                        }
                        else {
                            [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
                        }
                        $edgeOverwriteEvidence = $null
                        if ($chartExportModesNativeSaveEdgeEnabled) {
                            Start-Sleep -Milliseconds 300
                            $exportResolutionObservation =
                                Get-AutomationElementObservation `
                                    -TargetProcessId $process.Id `
                                    -AutomationId "Editor.Export" `
                                    -RootWindowHandle $process.MainWindowHandle
                            try {
                                $overwriteDialog = Get-AutomationElementObservation `
                                    -TargetProcessId $process.Id `
                                    -AutomationId "ChartExport.OverwriteDialog" `
                                    -RootWindowHandle ([IntPtr]::Zero) `
                                    -TimeoutMilliseconds 6000
                                $overwriteMessage = Get-AutomationElementObservation `
                                    -TargetProcessId $process.Id `
                                    -AutomationId "ChartExport.OverwriteDialog.Message" `
                                    -RootWindowHandle ([IntPtr]::Zero) `
                                    -TimeoutMilliseconds 6000
                                $overwriteConfirm = Get-AutomationElementObservation `
                                    -TargetProcessId $process.Id `
                                    -AutomationId "ChartExport.OverwriteDialog.Yes" `
                                    -RootWindowHandle ([IntPtr]::Zero) `
                                    -TimeoutMilliseconds 6000
                            }
                            catch {
                                throw (
                                    "Owner-bound overwrite confirmation was not found. " +
                                    $_.Exception.Message +
                                    " Editor.Export HelpText: " +
                                    [string]$exportResolutionObservation.Evidence.helpText)
                            }
                            $expectedOverwriteLeaf =
                                [IO.Path]::GetFileName($chartExportModesExportFullPath)
                            $overwriteMessageContainsLeaf =
                                [string]$overwriteMessage.Evidence.name -like
                                    "*$expectedOverwriteLeaf*"
                            if (-not $overwriteMessageContainsLeaf) {
                                throw "Owner-bound overwrite confirmation did not name '$expectedOverwriteLeaf'."
                            }
                            $overwriteHandle =
                                [IntPtr]$overwriteDialog.Element.Current.NativeWindowHandle
                            Set-ForegroundWindowVerified -WindowHandle $overwriteHandle
                            Save-AutomationElementScreenshot `
                                -Element $overwriteDialog.Element `
                                -Path $chartExportModesOverwriteScreenshotFullPath
                            $chartExportModesOverwriteScreenshotSha256 =
                                (Get-FileHash `
                                    -LiteralPath $chartExportModesOverwriteScreenshotFullPath `
                                    -Algorithm SHA256).Hash
                            Click-AutomationElementWithMouse `
                                -Element $overwriteConfirm.Element
                            $overwriteCloseDeadline = [DateTime]::UtcNow.AddSeconds(5)
                            while ([LumaChartAvaloniaCaptureNative]::IsWindow($overwriteHandle) -and
                                   [DateTime]::UtcNow -lt $overwriteCloseDeadline) {
                                Start-Sleep -Milliseconds 80
                            }
                            if ([LumaChartAvaloniaCaptureNative]::IsWindow($overwriteHandle)) {
                                throw "Owner-bound overwrite confirmation did not close after its physical affirmative click."
                            }
                            $edgeOverwriteEvidence = [ordered]@{
                                dialog = $overwriteDialog.Evidence
                                message = $overwriteMessage.Evidence
                                expectedLeaf = $expectedOverwriteLeaf
                                existingTargetMessagePresent = $overwriteMessageContainsLeaf
                                confirm = $overwriteConfirm.Evidence
                                input = "physical Win32 mouse click at owner-bound affirmative overwrite button bounds"
                                exportResolution = $exportResolutionObservation.Evidence
                                screenshotPath = $chartExportModesOverwriteScreenshotFullPath
                                screenshotSha256 = $chartExportModesOverwriteScreenshotSha256
                                dialogClosedAfterConfirm = $true
                                verified = $true
                            }
                        }
                        $nativeCloseDeadline = [DateTime]::UtcNow.AddSeconds(5)
                        while ([LumaChartAvaloniaCaptureNative]::IsWindow($nativeSaveHandle) -and
                               [DateTime]::UtcNow -lt $nativeCloseDeadline) {
                            Start-Sleep -Milliseconds 80
                        }
                        if ([LumaChartAvaloniaCaptureNative]::IsWindow($nativeSaveHandle)) {
                            throw "Actual $ChartExportModesExportMode native Save picker did not close after explicit Enter and any required overwrite confirmation."
                        }
            $actualExportTimeoutSeconds = switch ($ChartExportModesExportMode) {
                "RatePack" { 90 }
                "SingleRatePackage" { 60 }
                default { 18 }
            }
            $actualExportDeadline =
                [DateTime]::UtcNow.AddSeconds($actualExportTimeoutSeconds)
                        $actualExportReady = $false
                        do {
                            if (Test-Path -LiteralPath $chartExportModesExportFullPath -PathType Leaf) {
                                $candidateExportItem = Get-Item -LiteralPath $chartExportModesExportFullPath
                                $candidateExportSha256 = (Get-FileHash `
                                    -LiteralPath $chartExportModesExportFullPath `
                                    -Algorithm SHA256).Hash
                                $actualExportReady = -not $chartExportModesNativeSaveEdgeEnabled -or
                                    [long]$candidateExportItem.Length -ne
                                        [long]$chartExportModesExistingTargetBefore.length -or
                                    $candidateExportSha256 -cne
                                        [string]$chartExportModesExistingTargetBefore.sha256
                            }
                            if ($actualExportReady) { break }
                            Start-Sleep -Milliseconds 100
                        } while ([DateTime]::UtcNow -lt $actualExportDeadline)
                        if (-not $actualExportReady) {
                            throw "Actual $ChartExportModesExportMode export did not create or atomically replace the requested destination."
                        }
                        $actualExportItem = Get-Item -LiteralPath $chartExportModesExportFullPath
                        if ($actualExportItem.Length -le 0) {
                            throw "Actual $ChartExportModesExportMode export created an empty destination."
                        }
                        if ($chartExportModesNativeSaveEdgeEnabled -and
                            (Test-Path -LiteralPath $chartExportModesForbiddenOutputFullPath)) {
                            throw "Actual SingleChart export created the forbidden secondary-extension output: $chartExportModesForbiddenOutputFullPath"
                        }

                        $resultDialog = Find-AutomationElementByName `
                            -TargetProcessId $process.Id `
                            -Name "导出" `
                            -TimeoutMilliseconds 8000
                        $resultDialogHandle = [IntPtr]$resultDialog.Current.NativeWindowHandle
                        if ($resultDialogHandle -eq [IntPtr]::Zero -or
                            [string]$resultDialog.Current.ClassName -ne "#32770") {
                            throw "Actual $ChartExportModesExportMode result was not WPF's native #32770 information MessageBox."
                        }
                        $resultDialogAutomationId =
                            [string]$resultDialog.Current.AutomationId
                        $resultDialogClassName =
                            [string]$resultDialog.Current.ClassName
                        Set-ForegroundWindowVerified -WindowHandle $resultDialogHandle
                        $resultMessage = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "65535" `
                            -RootWindowHandle $resultDialogHandle
                        $actualResultMessage = [string]$resultMessage.Evidence.name
                        $expectedResultLeaf = if (
                            $chartExportModesNativeSaveEdgeEnabled) {
                            [IO.Path]::GetFileName(
                                $chartExportModesExportFullPath)
                        }
                        else {
                            $nativeLeaf
                        }
                        if (-not $actualResultMessage.TrimStart().StartsWith(
                                "导出完成",
                                [StringComparison]::Ordinal) -or
                            -not $actualResultMessage.Contains(
                                $expectedResultLeaf,
                                [StringComparison]::OrdinalIgnoreCase)) {
                            throw "Actual $ChartExportModesExportMode result dialog did not report the requested successful destination."
                        }
                        Save-AutomationElementScreenshot `
                            -Element $resultDialog `
                            -Path $chartExportModesExportResultScreenshotFullPath
                        $actualResultScreenshotSha256 =
                            (Get-FileHash -LiteralPath $chartExportModesExportResultScreenshotFullPath -Algorithm SHA256).Hash
                        $resultConfirm = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "2" `
                            -RootWindowHandle $resultDialogHandle
                        if ([string]$resultConfirm.Evidence.name -ne "确定" -or
                            [string]$resultConfirm.Element.Current.ClassName -ne "Button") {
                            throw "Actual export native result did not expose WPF's id=2 确定 button."
                        }
                        Click-AutomationElementWithMouse -Element $resultConfirm.Element
                        $resultCloseDeadline = [DateTime]::UtcNow.AddSeconds(3)
                        while ([LumaChartAvaloniaCaptureNative]::IsWindow($resultDialogHandle) -and
                               [DateTime]::UtcNow -lt $resultCloseDeadline) {
                            Start-Sleep -Milliseconds 80
                        }
                        if ([LumaChartAvaloniaCaptureNative]::IsWindow($resultDialogHandle)) {
                            throw "Actual export native result did not close after its physical 确定 click."
                        }
                        $resultCloseFallbackUsed = $false
                        $chartExportModesEvidence["actualExport"] = [ordered]@{
                            requested = [ordered]@{
                                format = $ChartExportModesExportFormat
                                mode = $ChartExportModesExportMode
                                path = $chartExportModesExportFullPath
                                expectedExtension = $expectedChartExportExtension
                                rate = $ChartExportModesExportRate
                                minimumRate = $ChartExportModesExportMinimumRate
                                maximumRate = $ChartExportModesExportMaximumRate
                                rateStep = $ChartExportModesExportRateStep
                                preservePitch = [bool]$ChartExportModesExportPreservePitch
                                nativeSaveEdgeScenario = $ChartExportModesNativeSaveEdgeScenario
                            }
                            modeSelection = $actualModeSelection
                            rateInput = $actualRateInput
                            rangeInputs = $actualRangeInputs
                            hiddenRateRepair = $actualHiddenRateRepair
                            formatSelection = $actualFormatSelection
                            preservePitch = $actualConfiguration.preservePitch
                            cancelThenRetry = $edgeCancelEvidence
                            confirm = [ordered]@{
                                input = "physical Win32 mouse click at Confirm UI Automation bounds"
                                control = $actualConfirm.Evidence
                                automationInvokeFallbackUsed = $false
                            }
                            nativeSave = [ordered]@{
                                directory = $nativeDirectoryEvidence
                                filename = $nativeLeaf
                                readProvider = $nativeFilenameReadProvider
                                focusBeforeInput = $nativeFocusBefore.Evidence
                                automationInputFocusFallbackUsed =
                                    $nativeInputFocusAutomationFallbackUsed
                                automationInputFocusFallbackError =
                                    $nativeInputFocusAutomationFallbackError
                                input = if ($chartExportModesNativeSaveEdgeEnabled) {
                                    "physical focus + Ctrl+A + Win32 SendInput KEYEVENTF_UNICODE + physical Win32 mouse click at native Save button bounds"
                                } else {
                                    "physical focus + Ctrl+A + Win32 SendInput KEYEVENTF_UNICODE + explicit Enter"
                                }
                                submitButton = $nativeSubmitButtonEvidence
                                expectedSendInputEventCount = [int]$expectedNativeInputEvents
                                sentInputEventCount = [int]$nativeInputEvents
                                sendInputError = [int][LumaChartAvaloniaCaptureNative]::LastSendInputError
                                physicalInputRetained = -not $nativeFilenameFallbackUsed
                                automationValueFallbackUsed = $nativeFilenameFallbackUsed
                                explicitEnterSubmitted =
                                    -not $chartExportModesNativeSaveEdgeEnabled
                                physicalSaveClickSubmitted =
                                    [bool]$chartExportModesNativeSaveEdgeEnabled
                                dialogClosedAfterSubmit = $true
                                overwriteConfirmation = $edgeOverwriteEvidence
                            }
                            file = [ordered]@{
                                path = $chartExportModesExportFullPath
                                length = [long]$actualExportItem.Length
                                sha256 = (Get-FileHash -LiteralPath $chartExportModesExportFullPath -Algorithm SHA256).Hash
                                extension = [IO.Path]::GetExtension($chartExportModesExportFullPath)
                                ordinaryAbsolutePathLength = $chartExportModesExportFullPath.Length
                                containsSpace = $chartExportModesExportFullPath.Contains(' ')
                                containsNonAscii =
                                    $chartExportModesExportFullPath -match '[^\u0000-\u007F]'
                            }
                            nativeSaveEdge = if ($chartExportModesNativeSaveEdgeEnabled) {
                                [ordered]@{
                                    scenario = $ChartExportModesNativeSaveEdgeScenario
                                    existingTargetBefore = $chartExportModesExistingTargetBefore
                                    cancel = $edgeCancelEvidence
                                    overwrite = $edgeOverwriteEvidence
                                    pickerReturnedPath =
                                        $chartExportModesForbiddenOutputFullPath
                                    correctedDestinationPath =
                                        $chartExportModesExportFullPath
                                    expectedFormatExtension = $expectedChartExportExtension
                                    pickerExtension = [IO.Path]::GetExtension(
                                        $chartExportModesForbiddenOutputFullPath)
                                    explicitWrongExtensionRetained =
                                        -not [IO.Path]::GetExtension(
                                            $chartExportModesForbiddenOutputFullPath).Equals(
                                                $expectedChartExportExtension,
                                                [StringComparison]::OrdinalIgnoreCase)
                                    forbiddenOutputPath = $chartExportModesForbiddenOutputFullPath
                                    forbiddenOutputAbsent =
                                        -not (Test-Path -LiteralPath $chartExportModesForbiddenOutputFullPath)
                                    ordinaryAbsolutePathLength =
                                        $chartExportModesExportFullPath.Length
                                    exceeds260Characters =
                                        $chartExportModesExportFullPath.Length -gt 260
                                    containsSpace =
                                        $chartExportModesExportFullPath.Contains(' ')
                                    containsNonAscii =
                                        $chartExportModesExportFullPath -match '[^\u0000-\u007F]'
                                    verified =
                                        [bool]$edgeCancelEvidence.verified -and
                                        [bool]$edgeOverwriteEvidence.verified -and
                                        -not (Test-Path -LiteralPath $chartExportModesForbiddenOutputFullPath)
                                }
                            } else { $null }
                            result = [ordered]@{
                                dialogAutomationId = $resultDialogAutomationId
                                dialogClassName = $resultDialogClassName
                                nativeWindowHandle = [long]$resultDialogHandle
                                message = $resultMessage.Evidence
                                confirm = $resultConfirm.Evidence
                                screenshotPath = $chartExportModesExportResultScreenshotFullPath
                                screenshotSha256 = $actualResultScreenshotSha256
                                physicalConfirmClickRetained = $true
                                closeAutomationFallbackUsed = $resultCloseFallbackUsed
                            }
                            verified = $true
                        }
                        $chartExportModesEvidence["anyAutomationFallbackUsed"] =
                            [bool]$chartExportModesEvidence.anyAutomationFallbackUsed -or
                            [bool]$actualModeSelection.automationSelectionFallbackUsed -or
                            [bool]$actualRateInput.automationValueFallbackUsed -or
                            [bool]$actualRateInput.automationInputFocusFallbackUsed -or
                            [bool]$actualRateInput.automationFocusFallbackUsed -or
                            [bool]$actualRangeInputs.minimum.automationValueFallbackUsed -or
                            [bool]$actualRangeInputs.minimum.automationInputFocusFallbackUsed -or
                            [bool]$actualRangeInputs.minimum.automationFocusFallbackUsed -or
                            [bool]$actualRangeInputs.maximum.automationValueFallbackUsed -or
                            [bool]$actualRangeInputs.maximum.automationInputFocusFallbackUsed -or
                            [bool]$actualRangeInputs.maximum.automationFocusFallbackUsed -or
                            [bool]$actualRangeInputs.step.automationValueFallbackUsed -or
                            [bool]$actualRangeInputs.step.automationInputFocusFallbackUsed -or
                            [bool]$actualRangeInputs.step.automationFocusFallbackUsed -or
                            [bool]$actualHiddenRateRepair.selection.automationSelectionFallbackUsed -or
                            [bool]$actualHiddenRateRepair.input.automationValueFallbackUsed -or
                            [bool]$actualHiddenRateRepair.input.automationInputFocusFallbackUsed -or
                            [bool]$actualHiddenRateRepair.input.automationFocusFallbackUsed -or
                            [bool]$actualFormatSelection.automationSelectionFallbackUsed -or
                            $actualPitchFallbackUsed -or
                            $nativeInputFocusAutomationFallbackUsed -or
                            $nativeFilenameFallbackUsed -or
                            $resultCloseFallbackUsed
                    }
                    else {
                        $closeButton = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.Close" `
                            -RootWindowHandle $optionsDialogHandle
                        Click-AutomationElementWithMouse -Element $closeButton.Element
                        Start-Sleep -Milliseconds 250
                        $closeAutomationFallbackUsed = $false
                        if (-not (Test-AutomationElementAbsentById `
                                    -TargetProcessId $process.Id `
                                    -AutomationId "Export.MalodyFullPackage.Dialog")) {
                            Invoke-AutomationElement -Element $closeButton.Element
                            $closeAutomationFallbackUsed = $true
                            Start-Sleep -Milliseconds 250
                        }
                        if (-not (Test-AutomationElementAbsentById `
                                    -TargetProcessId $process.Id `
                                    -AutomationId "Export.MalodyFullPackage.Dialog")) {
                            throw "Chart export mode dialog did not close after its explicit Close action."
                        }
                        $chartExportModesEvidence["close"] = [ordered]@{
                            input = "physical Win32 mouse click at Close UI Automation bounds"
                            physicalClickAttempted = $true
                            physicalClickRetained = -not $closeAutomationFallbackUsed
                            automationInvokeFallbackUsed = $closeAutomationFallbackUsed
                            dialogAbsentAfter = $true
                        }
                        $chartExportModesEvidence["anyAutomationFallbackUsed"] =
                            [bool]$chartExportModesEvidence.anyAutomationFallbackUsed -or
                            $closeAutomationFallbackUsed
                    }
                    $interactionActionsCompletedAtUtc = [DateTimeOffset]::UtcNow
                }
                elseif ($fullPackageExportExerciseEnabled) {
                    $primaryExportEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw |
                        ConvertFrom-Json
                    $expectedExportPickerStartDirectory = [IO.Path]::GetDirectoryName(
                        [IO.Path]::GetFullPath($malodyFullPackageExportFullPath))
                    if (-not [bool]$primaryExportEvidence.evidenceFilePickerStartDirectoryInjected -or
                        -not [IO.Path]::GetFullPath(
                            [string]$primaryExportEvidence.evidenceFilePickerStartDirectory).Equals(
                                $expectedExportPickerStartDirectory,
                                [StringComparison]::OrdinalIgnoreCase)) {
                        throw "Malody export primary runtime did not record the exact evidence file-picker start directory."
                    }
                    Assert-InteractionWindowRemaining `
                        -PrimaryEvidence $primaryExportEvidence `
                        -MinimumMilliseconds 22000
                    $selected = @($primaryExportEvidence.timeline.selectedNotes)
                    if ($selected.Count -ne 1 -or $null -ne $selected[0].endBeat) {
                        throw "Malody export evidence requires exactly one selected Tap Note."
                    }
                    $authored = $selected[0].beat
                    $expectedFixtureFocusBeat = $malodyFullPackageFixtureEvidence.focusBeat
                    $expectedFixtureSubmittedBeat = $malodyFullPackageFixtureEvidence.submittedBeat
                    $exactFocusedTapVerified =
                        [int]$selected[0].lane -eq [int]$malodyFullPackageFixtureEvidence.lane -and
                        [int]$authored.bar -eq [int]$expectedFixtureFocusBeat.bar -and
                        [int]$authored.numerator -eq [int]$expectedFixtureFocusBeat.numerator -and
                        [int]$authored.denominator -eq [int]$expectedFixtureFocusBeat.denominator
                    if (-not $exactFocusedTapVerified) {
                        throw "FullPackage export UI selection did not resolve the exact trusted Tap; nearest-note fallback is forbidden."
                    }
                    $expandedDenominator = [int]$authored.denominator * 2
                    if ([int]$authored.denominator -le 0 -or $expandedDenominator -gt 1000000) {
                        throw "Selected Note denominator cannot be safely expanded for exact-Beat export evidence."
                    }
                    $expandedNumerator = [int]$authored.numerator * 2
                    $expandedGreatestCommonDivisor = Get-IntegerGreatestCommonDivisor `
                        -Left $expandedNumerator `
                        -Right $expandedDenominator
                    $exactBeatExpansionVerified =
                        [int]$authored.numerator -ne 0 -and
                        $expandedNumerator -ne 0 -and
                        $expandedDenominator -gt [int]$authored.denominator -and
                        $expandedGreatestCommonDivisor -gt 1
                    if (-not $exactBeatExpansionVerified) {
                        throw "Malody export exact-Beat evidence requires a non-zero authored fraction expanded to a deliberately non-reduced equivalent fraction."
                    }
                    $exactSubmittedBeatVerified =
                        [int]$authored.bar -eq [int]$expectedFixtureSubmittedBeat.bar -and
                        $expandedNumerator -eq [int]$expectedFixtureSubmittedBeat.numerator -and
                        $expandedDenominator -eq [int]$expectedFixtureSubmittedBeat.denominator -and
                        $expandedGreatestCommonDivisor -eq 2
                    if (-not $exactSubmittedBeatVerified) {
                        throw "FullPackage export dirty Beat did not match the trusted deliberately non-reduced expression."
                    }
                    $dirtyBeat = "{0}:{1}/{2}" -f `
                        [int]$authored.bar, `
                        $expandedNumerator, `
                        $expandedDenominator
                    $dirtyFields = [ordered]@{
                        "Note Beat" = $dirtyBeat
                        "Note End Beat" = ""
                        "Note Lane" = ([int]$selected[0].lane + $(if (
                                $targetOsuFullPackage -or $osuToMalodyFullPackage) {
                                2
                            } else { 1 })).ToString(
                            [Globalization.CultureInfo]::InvariantCulture)
                        "Note Volume" = ([int]$selected[0].volume).ToString(
                            [Globalization.CultureInfo]::InvariantCulture)
                        "Note Sound" = if ($null -eq $selected[0].sound) {
                            ""
                        } else { [string]$selected[0].sound }
                        "Note Group" = ([int]$selected[0].group).ToString(
                            [Globalization.CultureInfo]::InvariantCulture)
                    }
                    foreach ($entry in $dirtyFields.GetEnumerator()) {
                        $field = Find-AutomationElementByName `
                            -TargetProcessId $process.Id `
                            -Name $entry.Key `
                            -RootWindowHandle $process.MainWindowHandle
                        Set-AutomationElementValue -Element $field -Value ([string]$entry.Value)
                    }
                    $dirtyLaneText = [string]$dirtyFields["Note Lane"]
                    $expectedApplyStatus =
                        "已应用 Note 属性 · Beat $dirtyBeat · 轨道 $dirtyLaneText · Tap"
                    $initialApplyStatusObservation =
                        Get-AutomationElementObservationByIdSingleShot `
                        -TargetProcessId $process.Id `
                        -AutomationId "Editor.Status" `
                        -RootWindowHandle $process.MainWindowHandle
                    $initialApplyStatusName =
                        [string]$initialApplyStatusObservation.Evidence.name
                    if ($initialApplyStatusName.Equals(
                            $expectedApplyStatus,
                            [StringComparison]::Ordinal)) {
                        throw "Editor.Status reported the dirty Note apply success before the physical Apply click."
                    }
                    $applyAttempts = [Collections.Generic.List[object]]::new()
                    $applyStatusEvidence = $null
                    foreach ($applyAttempt in 1..2) {
                        Set-ForegroundWindowVerified -WindowHandle $process.MainWindowHandle
                        $applyButtonObservation = Get-AutomationElementObservationByName `
                            -TargetProcessId $process.Id `
                            -Name "应用 Note" `
                            -RootWindowHandle $process.MainWindowHandle `
                            -TimeoutMilliseconds 3000
                        if (-not [bool]$applyButtonObservation.Evidence.isEnabled) {
                            throw "Malody FullPackage dirty Note Apply button was disabled before its physical click."
                        }
                        $statusBeforeClickObservation =
                            Get-AutomationElementObservationByIdSingleShot `
                            -TargetProcessId $process.Id `
                            -AutomationId "Editor.Status" `
                            -RootWindowHandle $process.MainWindowHandle
                        $statusBeforeClickName =
                            [string]$statusBeforeClickObservation.Evidence.name
                        if (-not $statusBeforeClickName.Equals(
                                $initialApplyStatusName,
                                [StringComparison]::Ordinal)) {
                            throw "Editor.Status changed before the next physical Note Apply click; retrying could create a duplicate history mutation."
                        }
                        Click-AutomationElementWithMouse `
                            -Element $applyButtonObservation.Element `
                            -SkipScroll

                        $statusWaitBudgetMilliseconds =
                            if ($applyAttempt -eq 1) { 3000 } else { 5000 }
                        $statusWaitTimer = [Diagnostics.Stopwatch]::StartNew()
                        $observedStatusNames = [Collections.Generic.HashSet[string]]::new(
                            [StringComparer]::Ordinal)
                        $statusObservationCount = 0
                        $matchedStatusEvidence = $null
                        while ($true) {
                            $statusObservation =
                                Get-AutomationElementObservationByIdSingleShot `
                                -TargetProcessId $process.Id `
                                -AutomationId "Editor.Status" `
                                -RootWindowHandle $process.MainWindowHandle
                            $statusObservationCount++
                            $observedStatusName = [string]$statusObservation.Evidence.name
                            [void]$observedStatusNames.Add($observedStatusName)
                            if ($observedStatusName.Equals(
                                    $expectedApplyStatus,
                                    [StringComparison]::Ordinal)) {
                                $matchedStatusEvidence = $statusObservation.Evidence
                                break
                            }
                            if (-not $observedStatusName.Equals(
                                    $statusBeforeClickName,
                                    [StringComparison]::Ordinal)) {
                                throw "Editor.Status changed to an unexpected result after the physical Note Apply click: $observedStatusName"
                            }
                            if ($statusWaitTimer.ElapsedMilliseconds -ge
                                $statusWaitBudgetMilliseconds) { break }
                            Start-Sleep -Milliseconds 80
                        }
                        $statusWaitTimer.Stop()

                        $applyAttempts.Add([pscustomobject][ordered]@{
                                attempt = $applyAttempt
                                mainWindowForegroundVerified = $true
                                button = $applyButtonObservation.Evidence
                                input = "physical Win32 mouse click at UI Automation bounds"
                                statusBeforeClick = $statusBeforeClickObservation.Evidence
                                statusCheckedImmediatelyBeforeClick = $true
                                scrollAfterStatusCheck = $false
                                statusWaitBudgetMilliseconds = $statusWaitBudgetMilliseconds
                                statusObservationCount = $statusObservationCount
                                waitElapsedMilliseconds = [long]$statusWaitTimer.ElapsedMilliseconds
                                allStatusReadsSucceeded = $true
                                baselineRetainedThroughout = $true
                                expectedStatus = $expectedApplyStatus
                                observedStatusNames = @($observedStatusNames)
                                statusMatched = $null -ne $matchedStatusEvidence
                                timedOut = $null -eq $matchedStatusEvidence
                                retryEligible = $null -eq $matchedStatusEvidence
                                status = $matchedStatusEvidence
                            })
                        if ($null -ne $matchedStatusEvidence) {
                            $applyStatusEvidence = $matchedStatusEvidence
                            break
                        }
                    }
                    if ($null -eq $applyStatusEvidence) {
                        throw "The Malody FullPackage dirty Note Apply action did not report its exact successful Editor.Status after two bounded physical-click attempts."
                    }
                    $applyEvidence = [ordered]@{
                        path = "foreground verification + physical Win32 mouse clicks + exact Editor.Status observation"
                        maximumAttempts = 2
                        attemptCount = $applyAttempts.Count
                        retryUsed = $applyAttempts.Count -gt 1
                        boundedWaitBudgetMilliseconds = 8000
                        allPhysicalClicks =
                            @($applyAttempts | Where-Object {
                                    [string]$_.input -cne
                                        "physical Win32 mouse click at UI Automation bounds"
                                }).Count -eq 0
                        automationFallbackUsed = $false
                        singleShotStatusReads = $true
                        retryRequiresStableBaseline = $true
                        duplicateHistoryMutationPrevented = $true
                        statusBeforeFirstClick = $initialApplyStatusObservation.Evidence
                        expectedStatus = $expectedApplyStatus
                        statusMatched = $true
                        status = $applyStatusEvidence
                        attempts = @($applyAttempts)
                    }
                    $malodyFullPackageDirtyInjection = [ordered]@{
                        input = "UI Automation ValuePattern fields + state-confirmed physical Apply button click"
                        noteId = [string]$selected[0].noteId
                        exactFocusedTapVerified = $exactFocusedTapVerified
                        beforeBeat = $authored
                        beforeLane = [int]$selected[0].lane
                        submittedLane = [int]$malodyFullPackageFixtureEvidence.submittedLane
                        submittedLaneUiText = $dirtyLaneText
                        laneChanged = [int]$selected[0].lane -ne
                            [int]$malodyFullPackageFixtureEvidence.submittedLane
                        submittedBeat = [ordered]@{
                            text = $dirtyBeat
                            bar = [int]$authored.bar
                            numerator = $expandedNumerator
                            denominator = $expandedDenominator
                            mathematicallyEquivalent = $true
                            expressionExpanded = $expandedDenominator -gt [int]$authored.denominator
                            numeratorNonZero = $expandedNumerator -ne 0
                            greatestCommonDivisor = $expandedGreatestCommonDivisor
                            deliberatelyNonReduced = $expandedGreatestCommonDivisor -gt 1
                            exactExpansionVerified = $exactBeatExpansionVerified
                            expectedExpressionVerified = $exactSubmittedBeatVerified
                        }
                        otherFieldsPreserved = $true
                        saveInvoked = $false
                        apply = $applyEvidence
                    }
                    $malodyFullPackageWorkingTreeAfterDirty =
                        Get-DirectoryTreeEvidence -Root $editingFullPath

                    $commandMenuToggle = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Editor.CommandMenuToggle" `
                        -RootWindowHandle $process.MainWindowHandle `
                        -TimeoutMilliseconds 10000
                    Click-AutomationElementWithMouse -Element $commandMenuToggle.Element
                    Start-Sleep -Milliseconds 250
                    $optionsDialog = $null
                    $optionsLaunchAttempts = [Collections.Generic.List[object]]::new()
                    foreach ($launchAttempt in 1..2) {
                        Set-ForegroundWindowVerified -WindowHandle $process.MainWindowHandle
                        $exportButtonObservation = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Editor.Export" `
                            -RootWindowHandle $process.MainWindowHandle `
                            -TimeoutMilliseconds 3000
                        if (-not [bool]$exportButtonObservation.Evidence.isEnabled) {
                            throw "Malody FullPackage export button was disabled before its physical click."
                        }
                        Click-AutomationElementWithMouse -Element $exportButtonObservation.Element
                        $dialogWaitBudgetMilliseconds = if ($launchAttempt -eq 1) { 4500 } else { 6500 }
                        $dialogTimeout = $null
                        try {
                            $optionsDialog = Find-AutomationElementById `
                                -TargetProcessId $process.Id `
                                -AutomationId "Export.MalodyFullPackage.Dialog" `
                                -TimeoutMilliseconds $dialogWaitBudgetMilliseconds
                        }
                        catch {
                            $dialogTimeout = [string]$_.Exception.Message
                            if ($dialogTimeout -notmatch
                                "^Timed out finding UI Automation id 'Export\.MalodyFullPackage\.Dialog' for process [0-9]+\.$") {
                                throw
                            }
                        }
                        $optionsLaunchAttempts.Add([pscustomobject][ordered]@{
                                attempt = $launchAttempt
                                mainWindowForegroundVerified = $true
                                button = $exportButtonObservation.Evidence
                                input = "physical Win32 mouse click at UI Automation bounds"
                                dialogWaitBudgetMilliseconds = $dialogWaitBudgetMilliseconds
                                dialogFound = $null -ne $optionsDialog
                                timedOut = $null -eq $optionsDialog
                                timeoutMessage = $dialogTimeout
                            })
                        if ($null -ne $optionsDialog) { break }
                    }
                    if ($null -eq $optionsDialog) {
                        throw "Timed out finding the Malody FullPackage options dialog after two bounded physical-click attempts."
                    }
                    $malodyFullPackageOptionsLaunchEvidence = [ordered]@{
                        path = "foreground verification + physical Win32 mouse clicks + UI Automation observation"
                        maximumAttempts = 2
                        attemptCount = $optionsLaunchAttempts.Count
                        retryUsed = $optionsLaunchAttempts.Count -gt 1
                        boundedWaitBudgetMilliseconds = 11000
                        allPhysicalClicks =
                            @($optionsLaunchAttempts | Where-Object {
                                    [string]$_.input -cne
                                        "physical Win32 mouse click at UI Automation bounds"
                                }).Count -eq 0
                        automationFallbackUsed = $false
                        dialogFound = $true
                        attempts = @($optionsLaunchAttempts)
                    }
                    $optionsDialogHandle = [IntPtr]$optionsDialog.Current.NativeWindowHandle
                    if ($optionsDialogHandle -eq [IntPtr]::Zero) {
                        throw "Malody FullPackage options dialog did not expose a native window handle."
                    }
                    Set-ForegroundWindowVerified -WindowHandle $optionsDialogHandle
                    $formatField = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Export.MalodyFullPackage.Dialog.Format" `
                        -RootWindowHandle $optionsDialogHandle
                    $modeField = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Export.MalodyFullPackage.Dialog.Mode" `
                        -RootWindowHandle $optionsDialogHandle
                    $preservePitchField = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "Export.MalodyFullPackage.Dialog.PreservePitch" `
                        -RootWindowHandle $optionsDialogHandle
                    $formatSelectionEvidence = [ordered]@{
                        requested = $selectedFullPackageFormat
                        input = "default selection"
                        physicalClick = $false
                    }
                    $osuDifficultyEvidence = $null
                    if ($targetOsuFullPackage) {
                        Set-ForegroundWindowVerified -WindowHandle $optionsDialogHandle
                        Click-AutomationElementWithMouse -Element $formatField.Element
                        $osuFormatItem = Find-AutomationElementByName `
                            -TargetProcessId $process.Id `
                            -Name "osu!mania v14 (.osu / .osz)" `
                            -TimeoutMilliseconds 4000
                        Click-AutomationElementWithMouse -Element $osuFormatItem
                        Start-Sleep -Milliseconds 250
                        $formatField = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.Format" `
                            -RootWindowHandle $optionsDialogHandle
                        if ([string]$formatField.Evidence.name -ne "osu!mania v14 (.osu / .osz)") {
                            throw "FullPackage format ComboBox did not retain the physically selected osu!mania format."
                        }
                        $odField = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.OsuOverallDifficulty" `
                            -RootWindowHandle $optionsDialogHandle
                        $hpField = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.OsuHpDrainRate" `
                            -RootWindowHandle $optionsDialogHandle
                        $odText = $OsuFullPackageOverallDifficulty.ToString(
                            "0.################",
                            [Globalization.CultureInfo]::InvariantCulture)
                        $hpText = $OsuFullPackageHpDrainRate.ToString(
                            "0.################",
                            [Globalization.CultureInfo]::InvariantCulture)
                        Set-AutomationElementValue -Element $odField.Element -Value $odText
                        Set-AutomationElementValue -Element $hpField.Element -Value $hpText
                        $odField = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.OsuOverallDifficulty" `
                            -RootWindowHandle $optionsDialogHandle
                        $hpField = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.OsuHpDrainRate" `
                            -RootWindowHandle $optionsDialogHandle
                        $odValueObject = $null
                        $hpValueObject = $null
                        if (-not $odField.Element.TryGetCurrentPattern(
                                [System.Windows.Automation.ValuePattern]::Pattern,
                                [ref]$odValueObject) -or
                            -not $hpField.Element.TryGetCurrentPattern(
                                [System.Windows.Automation.ValuePattern]::Pattern,
                                [ref]$hpValueObject)) {
                            throw "osu! FullPackage OD/HP fields did not expose ValuePattern after input."
                        }
                        $retainedOdText = [string]([System.Windows.Automation.ValuePattern]$odValueObject).Current.Value
                        $retainedHpText = [string]([System.Windows.Automation.ValuePattern]$hpValueObject).Current.Value
                        $formatSelectionEvidence = [ordered]@{
                            requested = $selectedFullPackageFormat
                            input = "physical Win32 mouse clicks on ComboBox and exact osu!mania item"
                            physicalClick = $true
                            selectedItem = [ordered]@{
                                name = [string]$osuFormatItem.Current.Name
                                automationId = [string]$osuFormatItem.Current.AutomationId
                                controlType = [string]$osuFormatItem.Current.ControlType.ProgrammaticName
                            }
                        }
                        $osuDifficultyEvidence = [ordered]@{
                            input = "UI Automation ValuePattern; no keyboard, IME, clipboard, or Enter"
                            overallDifficulty = $odField.Evidence
                            hpDrainRate = $hpField.Evidence
                            expectedOverallDifficulty = $odText
                            expectedHpDrainRate = $hpText
                            retainedOverallDifficulty = $retainedOdText
                            retainedHpDrainRate = $retainedHpText
                            retained = $retainedOdText -eq $odText -and
                                $retainedHpText -eq $hpText
                        }
                        if (-not [bool]$osuDifficultyEvidence.retained) {
                            throw "osu! FullPackage OD/HP fields did not retain the exact requested invariant values; OD='$retainedOdText' expected '$odText', HP='$retainedHpText' expected '$hpText'."
                        }
                    }
                    elseif ($osuToMalodyFullPackage) {
                        Set-ForegroundWindowVerified -WindowHandle $optionsDialogHandle
                        Click-AutomationElementWithMouse -Element $formatField.Element
                        $malodyFormatItem = Find-AutomationElementByName `
                            -TargetProcessId $process.Id `
                            -Name "Malody (.mc / .mcz)" `
                            -TimeoutMilliseconds 4000
                        Click-AutomationElementWithMouse -Element $malodyFormatItem
                        Start-Sleep -Milliseconds 250
                        $formatField = Get-AutomationElementObservation `
                            -TargetProcessId $process.Id `
                            -AutomationId "Export.MalodyFullPackage.Dialog.Format" `
                            -RootWindowHandle $optionsDialogHandle
                        if ([string]$formatField.Evidence.name -ne "Malody (.mc / .mcz)") {
                            throw "FullPackage format ComboBox did not retain the physically selected Malody format."
                        }
                        $formatSelectionEvidence = [ordered]@{
                            requested = $selectedFullPackageFormat
                            input = "physical Win32 mouse clicks on ComboBox and exact Malody item"
                            physicalClick = $true
                            selectedItem = [ordered]@{
                                name = [string]$malodyFormatItem.Current.Name
                                automationId = [string]$malodyFormatItem.Current.AutomationId
                                controlType = [string]$malodyFormatItem.Current.ControlType.ProgrammaticName
                            }
                        }
                    }
                    $malodyFullPackageOptionsEvidence = [ordered]@{
                        automationId = [string]$optionsDialog.Current.AutomationId
                        name = [string]$optionsDialog.Current.Name
                        nativeWindowHandle = [long]$optionsDialogHandle
                        launch = $malodyFullPackageOptionsLaunchEvidence
                        format = $formatField.Evidence
                        formatSelection = $formatSelectionEvidence
                        osuDifficulty = $osuDifficultyEvidence
                        mode = $modeField.Evidence
                        preservePitch = $preservePitchField.Evidence
                        defaultsVerified =
                            [string]$formatField.Evidence.name -eq $(if ($targetOsuFullPackage) {
                                "osu!mania v14 (.osu / .osz)"
                            } else { "Malody (.mc / .mcz)" }) -and
                            [string]$modeField.Evidence.name -eq "整谱压缩包" -and
                            -not [bool]$preservePitchField.Evidence.isEnabled -and
                            (-not $targetOsuFullPackage -or
                             [bool]$osuDifficultyEvidence.retained)
                    }
                    if (-not $malodyFullPackageOptionsEvidence.defaultsVerified) {
                        throw "Chart export dialog did not expose the required Malody/FullPackage defaults with rate-only pitch preservation disabled."
                    }
                    Save-AutomationElementScreenshot `
                        -Element $optionsDialog `
                        -Path $malodyFullPackageOptionsScreenshotFullPath
                    $malodyFullPackageOptionsScreenshotSha256 =
                        (Get-FileHash -LiteralPath $malodyFullPackageOptionsScreenshotFullPath -Algorithm SHA256).Hash
                    $optionsConfirm = Find-AutomationElementById `
                        -TargetProcessId $process.Id `
                        -AutomationId "Export.MalodyFullPackage.Dialog.Confirm" `
                        -RootWindowHandle $optionsDialogHandle
                    Click-AutomationElementWithMouse -Element $optionsConfirm

                    $nativeSaveDialog = Find-AutomationElementByName `
                        -TargetProcessId $process.Id `
                        -Name "选择导出位置" `
                        -TimeoutMilliseconds 7000
                    $nativeSaveHandle = [IntPtr]$nativeSaveDialog.Current.NativeWindowHandle
                    if ($nativeSaveHandle -eq [IntPtr]::Zero) {
                        throw "Native MCZ Save picker did not expose a window handle."
                    }
                    $requestedNativePath = [IO.Path]::GetFullPath($malodyFullPackageExportFullPath)
                    $requestedNativeDirectory = [IO.Path]::GetDirectoryName($requestedNativePath)
                    $requestedNativeFileName = [IO.Path]::GetFileName($requestedNativePath)
                    $nativeDirectoryNavigation = Get-NativeFilePickerAddressEvidence `
                        -DialogElement $nativeSaveDialog `
                        -ExpectedDirectory $requestedNativeDirectory
                    $fileTypeHost = Find-AutomationElementById `
                        -TargetProcessId $process.Id `
                        -AutomationId "FileTypeControlHost" `
                        -RootWindowHandle $nativeSaveHandle `
                        -TimeoutMilliseconds 5000
                    $fileNameHost = Find-AutomationElementById `
                        -TargetProcessId $process.Id `
                        -AutomationId "FileNameControlHost" `
                        -RootWindowHandle $nativeSaveHandle `
                        -TimeoutMilliseconds 5000
                    $filenameIdCondition = [System.Windows.Automation.PropertyCondition]::new(
                        [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
                        "1001")
                    $saveName = $fileNameHost.FindFirst(
                        [System.Windows.Automation.TreeScope]::Descendants,
                        $filenameIdCondition)
                    if (-not $saveName) {
                        throw "Native MCZ Save picker did not expose editable filename child 1001."
                    }
                    $initialFilenamePattern = $null
                    $initialNativeFilenameValue = if ($saveName.TryGetCurrentPattern(
                            [System.Windows.Automation.ValuePattern]::Pattern,
                            [ref]$initialFilenamePattern)) {
                        ([System.Windows.Automation.ValuePattern]$initialFilenamePattern).Current.Value
                    } else { [string]$saveName.Current.Name }
                    [string]$initialNativeFilenameText = if (
                        $null -eq $initialNativeFilenameValue) {
                        ""
                    } else { [string]$initialNativeFilenameValue }
                    $expectedProductSuggestedFileName = if ($targetOsuFullPackage) {
                        $initialNativeFilenameText
                    } elseif ($osuToMalodyFullPackage) {
                        $initialNativeFilenameText
                    } else { "HyuN - Infinity Heaven [4K Stream Lv.28].mcz" }
                    $suggestedFileNameVerified = if ($targetOsuFullPackage) {
                        -not [string]::IsNullOrWhiteSpace($initialNativeFilenameText) -and
                        [IO.Path]::GetExtension($initialNativeFilenameText).Equals(
                            ".osz",
                            [StringComparison]::OrdinalIgnoreCase) -and
                        -not $initialNativeFilenameText.Equals(
                            $requestedNativeFileName,
                            [StringComparison]::OrdinalIgnoreCase)
                    } elseif ($osuToMalodyFullPackage) {
                        -not [string]::IsNullOrWhiteSpace($initialNativeFilenameText) -and
                        [IO.Path]::GetExtension($initialNativeFilenameText).Equals(
                            ".mcz",
                            [StringComparison]::OrdinalIgnoreCase) -and
                        -not $initialNativeFilenameText.Equals(
                            $requestedNativeFileName,
                            [StringComparison]::OrdinalIgnoreCase)
                    } else {
                        $initialNativeFilenameText.Equals(
                            $expectedProductSuggestedFileName,
                            [StringComparison]::Ordinal)
                    }
                    if (-not $suggestedFileNameVerified) {
                        throw "Native FullPackage Save picker did not expose a valid format-compatible product SuggestedFileName: '$initialNativeFilenameText'."
                    }
                    if ($requestedNativeFileName -match '[\+\^%~\(\)\{\}\[\]]') {
                        throw "Native MCZ Save physical keyboard input requires a SendKeys-safe evidence leaf: '$requestedNativeFileName'."
                    }
                    $saveNameBounds = $saveName.Current.BoundingRectangle
                    $saveNameAutomationId = [string]$saveName.Current.AutomationId
                    $saveNameClassName = [string]$saveName.Current.ClassName
                    $saveNameControlType =
                        [string]$saveName.Current.ControlType.ProgrammaticName
                    $saveNameIsEnabled = [bool]$saveName.Current.IsEnabled
                    $saveNameIsOffscreen = [bool]$saveName.Current.IsOffscreen
                    $saveNameHandle = [IntPtr]$saveName.Current.NativeWindowHandle
                    if ($saveNameBounds.IsEmpty -or
                        $saveNameBounds.Width -le 1 -or
                        $saveNameBounds.Height -le 1 -or
                        $saveNameIsOffscreen -or
                        -not $saveNameIsEnabled -or
                        $saveNameAutomationId -cne "1001" -or
                        $saveNameClassName -cne "Edit" -or
                        $saveNameControlType -cne "ControlType.Pane" -or
                        $saveNameHandle -eq [IntPtr]::Zero -or
                        -not [LumaChartAvaloniaCaptureNative]::IsWindow($saveNameHandle)) {
                        throw "Native MCZ Save filename control was not the enabled, visible native 1001/Edit ControlType.Pane with a usable HWND."
                    }
                    $nativeFilenameInputAttempts = [Collections.Generic.List[object]]::new()
                    $nativeFilenameValue = ""
                    $nativeUnicodeCharCount = $requestedNativeFileName.Length
                    $nativeUnicodeExpectedEventCount = $nativeUnicodeCharCount * 2
                    $nativeInputStructSize = [LumaChartAvaloniaCaptureNative]::InputStructSize
                    if ($nativeInputStructSize -ne 40) {
                        throw "Native MCZ Save SendInput INPUT struct size was $nativeInputStructSize instead of the required x64 size 40."
                    }
                    for ($filenameAttempt = 1; $filenameAttempt -le 3; $filenameAttempt++) {
                        $beforeAttemptName = [string]$saveName.Current.Name
                        Set-ForegroundWindowVerified -WindowHandle $nativeSaveHandle
                        $foregroundBeforeClick = [long][LumaChartAvaloniaCaptureNative]::GetForegroundWindow()
                        Click-AutomationElementWithMouse -Element $saveName
                        Start-Sleep -Milliseconds 100
                        $foregroundAfterClick = [long][LumaChartAvaloniaCaptureNative]::GetForegroundWindow()
                        $fileNameHost.SetFocus()
                        Start-Sleep -Milliseconds 100
                        $focusAfterHostSetFocus = Get-FocusedAutomationElementEvidence
                        Set-ForegroundWindowVerified -WindowHandle $nativeSaveHandle
                        [System.Windows.Forms.SendKeys]::SendWait("%n")
                        Start-Sleep -Milliseconds 100
                        Set-ForegroundWindowVerified -WindowHandle $nativeSaveHandle
                        $foregroundAfterMnemonic = [long][LumaChartAvaloniaCaptureNative]::GetForegroundWindow()
                        $focusBeforeInput = Get-FocusedAutomationElementEvidence
                        $focusBeforeInputAllowed =
                            (([string]$focusBeforeInput.Evidence.automationId -eq
                                "FileNameControlHost") -or
                             ([string]$focusBeforeInput.Evidence.automationId -eq "1001" -and
                              [string]$focusBeforeInput.Evidence.className -eq "Edit")) -and
                            [int]$focusBeforeInput.Evidence.processId -eq $process.Id -and
                            [bool]$focusBeforeInput.Evidence.hasKeyboardFocus
                        if (-not $focusBeforeInputAllowed) {
                            throw "Native MCZ Save focus was not on FileNameControlHost or its 1001/Edit descendant before keyboard input."
                        }
                        [System.Windows.Forms.SendKeys]::SendWait("^a")
                        $nativeUnicodeReturnedEventCount = [int][LumaChartAvaloniaCaptureNative]::SendUnicodeText(
                            $requestedNativeFileName)
                        $nativeUnicodeLastError =
                            [LumaChartAvaloniaCaptureNative]::LastSendInputError
                        if ($nativeUnicodeReturnedEventCount -ne
                                $nativeUnicodeExpectedEventCount -or
                            $nativeUnicodeLastError -ne 0) {
                            throw "Native MCZ Save SendInput emitted $nativeUnicodeReturnedEventCount/$nativeUnicodeExpectedEventCount Unicode keyboard events; Win32 last error was $nativeUnicodeLastError."
                        }
                        Start-Sleep -Milliseconds 180
                        $focusAfterUnicodeInput = Get-FocusedAutomationElementEvidence
                        $focusAfterUnicodeInputAllowed =
                            (([string]$focusAfterUnicodeInput.Evidence.automationId -eq
                                "FileNameControlHost") -or
                             ([string]$focusAfterUnicodeInput.Evidence.automationId -eq "1001" -and
                              [string]$focusAfterUnicodeInput.Evidence.className -eq "Edit")) -and
                            [int]$focusAfterUnicodeInput.Evidence.processId -eq $process.Id -and
                            [bool]$focusAfterUnicodeInput.Evidence.hasKeyboardFocus
                        if (-not $focusAfterUnicodeInputAllowed) {
                            throw "Native MCZ Save focus left FileNameControlHost/1001 Edit after Unicode keyboard input."
                        }
                        $dialogOpenAfterUnicodeInput =
                            [LumaChartAvaloniaCaptureNative]::IsWindow($nativeSaveHandle)
                        if (-not $dialogOpenAfterUnicodeInput) {
                            throw "Native MCZ Save picker closed during SendInput Unicode filename entry."
                        }
                        $foregroundAfterKeyboard = [long][LumaChartAvaloniaCaptureNative]::GetForegroundWindow()
                        $nativeFilenameValue = [string]$saveName.Current.Name
                        $attemptRetainedExactName = $nativeFilenameValue.Equals(
                            $requestedNativeFileName,
                            [StringComparison]::OrdinalIgnoreCase)
                        $nativeFilenameInputAttempts.Add([pscustomobject][ordered]@{
                            attempt = $filenameAttempt
                            beforeName = $beforeAttemptName
                            afterName = $nativeFilenameValue
                            expectedForegroundHandle = [long]$nativeSaveHandle
                            foregroundBeforeClick = $foregroundBeforeClick
                            physicalFilenameClickAttempted = $true
                            foregroundAfterClick = $foregroundAfterClick
                            focusAfterHostSetFocus = $focusAfterHostSetFocus.Evidence
                            mnemonic = "Alt+N native filename accelerator"
                            foregroundAfterMnemonic = $foregroundAfterMnemonic
                            focusBeforeInput = $focusBeforeInput.Evidence
                            keyboardInput = "Ctrl+A + Win32 SendInput KEYEVENTF_UNICODE exact leaf"
                            focusAfterUnicodeInput = $focusAfterUnicodeInput.Evidence
                            inputStructSize = $nativeInputStructSize
                            unicodeCharCount = $nativeUnicodeCharCount
                            expectedUnicodeEventCount = $nativeUnicodeExpectedEventCount
                            returnedUnicodeEventCount = $nativeUnicodeReturnedEventCount
                            win32LastError = $nativeUnicodeLastError
                            imeCommitRequired = $false
                            imeCommitEnter = $false
                            dialogOpenAfterUnicodeInput = $dialogOpenAfterUnicodeInput
                            foregroundAfterKeyboard = $foregroundAfterKeyboard
                            exactUiaNameRetained = $attemptRetainedExactName
                        })
                        if ($attemptRetainedExactName) {
                            break
                        }
                    }
                    $nativeFilenameInput =
                        "verified foreground + physical FileNameControlHost/1001 focus + Alt+N native filename focus + Ctrl+A + Win32 SendInput KEYEVENTF_UNICODE exact leaf; no Enter/value injection"
                    if (-not $nativeFilenameValue.Equals(
                            $requestedNativeFileName,
                            [StringComparison]::OrdinalIgnoreCase)) {
                        throw "Native MCZ Save UIA Name did not retain the exact physically entered leaf '$requestedNativeFileName' after three real keyboard attempts: '$nativeFilenameValue'."
                    }
                    $nativeFilenameWindowText = $null
                    $nativeFilenameWindowTextLength = $null
                    $nativeFilenameWindowTextAvailable = $false
                    if ($saveNameHandle -ne [IntPtr]::Zero) {
                        if (-not [LumaChartAvaloniaCaptureNative]::IsWindow($saveNameHandle)) {
                            throw "Native MCZ Save filename control exposed a stale native HWND."
                        }
                        $saveNameTextLength =
                            [LumaChartAvaloniaCaptureNative]::GetWindowTextLength($saveNameHandle)
                        $nativeFilenameWindowTextLength = [int]$saveNameTextLength
                        $saveNameText = [Text.StringBuilder]::new($saveNameTextLength + 1)
                        [void][LumaChartAvaloniaCaptureNative]::GetWindowText(
                            $saveNameHandle,
                            $saveNameText,
                            $saveNameText.Capacity)
                        $nativeFilenameWindowText = $saveNameText.ToString()
                        $nativeFilenameWindowTextAvailable =
                            $saveNameTextLength -gt 0 -or
                            $nativeFilenameWindowText.Length -gt 0
                        if ($nativeFilenameWindowTextAvailable -and
                            -not $nativeFilenameWindowText.Equals(
                                $requestedNativeFileName,
                                [StringComparison]::OrdinalIgnoreCase)) {
                            throw "Native MCZ Save WM_GETTEXT disagreed with the exact physically entered leaf '$requestedNativeFileName': '$nativeFilenameWindowText'."
                        }
                    }
                    $unexpectedSuggestedPath =
                        Join-Path $requestedNativeDirectory $expectedProductSuggestedFileName
                    if (Test-Path -LiteralPath $unexpectedSuggestedPath) {
                        throw "Native MCZ Save evidence destination already contains the product suggested-name archive: $unexpectedSuggestedPath"
                    }
                    $malodyFullPackageNativeSaveEvidence = [ordered]@{
                        title = [string]$nativeSaveDialog.Current.Name
                        nativeWindowHandle = [long]$nativeSaveHandle
                        fileTypeName = [string]$fileTypeHost.Current.Name
                        startDirectory = $nativeDirectoryNavigation
                        filenameInput = $nativeFilenameInput
                        inputStructSize = $nativeInputStructSize
                        unicodeCharCount = $nativeUnicodeCharCount
                        expectedUnicodeEventCount = $nativeUnicodeExpectedEventCount
                        returnedUnicodeEventCount = $nativeUnicodeReturnedEventCount
                        win32LastError = $nativeUnicodeLastError
                        imeCommitRequired = $false
                        imeCommitEnter = $false
                        dialogOpenAfterUnicodeInput = $dialogOpenAfterUnicodeInput
                        filenameInputAttemptCount = $nativeFilenameInputAttempts.Count
                        filenameInputAttempts = @($nativeFilenameInputAttempts)
                        filenameProvider = "Common Item Dialog FileNameControlHost/1001 UIA Name after Win32 SendInput KEYEVENTF_UNICODE"
                        filenameControl = [ordered]@{
                            automationId = $saveNameAutomationId
                            className = $saveNameClassName
                            controlType = $saveNameControlType
                            isEnabled = $saveNameIsEnabled
                            isOffscreen = $saveNameIsOffscreen
                            nativeWindowHandle = [long]$saveNameHandle
                            bounds = [ordered]@{
                                left = [double]$saveNameBounds.Left
                                top = [double]$saveNameBounds.Top
                                width = [double]$saveNameBounds.Width
                                height = [double]$saveNameBounds.Height
                            }
                        }
                        initialFilenameValue = $initialNativeFilenameText
                        expectedInitialFilenameValue = $expectedProductSuggestedFileName
                        initialSuggestedFileNameVerified = $suggestedFileNameVerified
                        filenameValue = [string]$nativeFilenameValue
                        filenameWindowTextAvailable =
                            [bool]$nativeFilenameWindowTextAvailable
                        filenameWindowTextLength = $nativeFilenameWindowTextLength
                        filenameWindowText = $nativeFilenameWindowText
                        requestedFileName = $requestedNativeFileName
                        requestedPath = $requestedNativePath
                        extension = [IO.Path]::GetExtension($requestedNativePath)
                    }
                    $saveIdCondition = [System.Windows.Automation.PropertyCondition]::new(
                        [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
                        "1")
                    $saveCandidates = $nativeSaveDialog.FindAll(
                        [System.Windows.Automation.TreeScope]::Descendants,
                        $saveIdCondition)
                    $nativeSaveMatches = [Collections.Generic.List[object]]::new()
                    for ($saveIndex = 0; $saveIndex -lt $saveCandidates.Count; $saveIndex++) {
                        $candidateSave = $saveCandidates.Item($saveIndex)
                        $candidateBounds = $candidateSave.Current.BoundingRectangle
                        $candidateHandle = [IntPtr]$candidateSave.Current.NativeWindowHandle
                        if ([string]$candidateSave.Current.ClassName -eq "Button" -and
                            [string]$candidateSave.Current.ControlType.ProgrammaticName -eq
                                "ControlType.Pane" -and
                            [string]$candidateSave.Current.Name -match '^保存|^Save' -and
                            $candidateHandle -ne [IntPtr]::Zero -and
                            [LumaChartAvaloniaCaptureNative]::IsWindow($candidateHandle) -and
                            [bool]$candidateSave.Current.IsEnabled -and
                            -not [bool]$candidateSave.Current.IsOffscreen -and
                            -not $candidateBounds.IsEmpty -and
                            $candidateBounds.Width -gt 1 -and
                            $candidateBounds.Height -gt 1) {
                            $nativeSaveMatches.Add($candidateSave)
                        }
                    }
                    if ($nativeSaveMatches.Count -ne 1) {
                        throw "Native MCZ Save picker did not expose exactly one enabled, visible native id=1 Save Button; found $($nativeSaveMatches.Count)."
                    }
                    $nativeSave = $nativeSaveMatches[0]
                    $saveButtonBounds = $nativeSave.Current.BoundingRectangle
                    $malodyFullPackageNativeSaveEvidence["submitControl"] = [ordered]@{
                        automationId = [string]$nativeSave.Current.AutomationId
                        name = [string]$nativeSave.Current.Name
                        className = [string]$nativeSave.Current.ClassName
                        controlType = [string]$nativeSave.Current.ControlType.ProgrammaticName
                        isEnabled = [bool]$nativeSave.Current.IsEnabled
                        isOffscreen = [bool]$nativeSave.Current.IsOffscreen
                        nativeWindowHandle = [long]$nativeSave.Current.NativeWindowHandle
                        bounds = [ordered]@{
                            left = [double]$saveButtonBounds.Left
                            top = [double]$saveButtonBounds.Top
                            width = [double]$saveButtonBounds.Width
                            height = [double]$saveButtonBounds.Height
                        }
                    }
                    Set-ForegroundWindowVerified -WindowHandle $nativeSaveHandle
                    Click-AutomationElementWithMouse -Element $nativeSave
                    $malodyFullPackageNativeSaveEvidence["submitPath"] =
                        "unique enabled visible native id=1 Save Button physical click"
                    $saveDialogCloseDeadline = [DateTime]::UtcNow.AddSeconds(4)
                    while ([LumaChartAvaloniaCaptureNative]::IsWindow($nativeSaveHandle) -and
                           [DateTime]::UtcNow -lt $saveDialogCloseDeadline) {
                        Start-Sleep -Milliseconds 80
                    }
                    if ([LumaChartAvaloniaCaptureNative]::IsWindow($nativeSaveHandle)) {
                        throw "Native MCZ Save picker did not close after the physical Save button click."
                    }
                    $nativeSubmitDeadline = [DateTime]::UtcNow.AddSeconds(12)
                    while (-not (Test-Path -LiteralPath $malodyFullPackageExportFullPath -PathType Leaf) -and
                           [DateTime]::UtcNow -lt $nativeSubmitDeadline) {
                        Start-Sleep -Milliseconds 100
                    }
                    if (-not (Test-Path -LiteralPath $malodyFullPackageExportFullPath -PathType Leaf)) {
                        throw "Native MCZ Save picker did not create the requested archive."
                    }
                    if (Test-Path -LiteralPath $unexpectedSuggestedPath) {
                        throw "Native MCZ Save picker created the product suggested-name archive instead of only the exact requested archive: $unexpectedSuggestedPath"
                    }
                    $malodyFullPackageNativeSaveEvidence["dialogClosedAfterSubmit"] = $true

                    $resultDialog = Find-AutomationElementByName `
                        -TargetProcessId $process.Id `
                        -Name "导出" `
                        -TimeoutMilliseconds 8000
                    $resultDialogHandle = [IntPtr]$resultDialog.Current.NativeWindowHandle
                    if ($resultDialogHandle -eq [IntPtr]::Zero -or
                        [string]$resultDialog.Current.ClassName -ne "#32770") {
                        throw "Malody export result was not WPF's native #32770 information MessageBox."
                    }
                    $resultDialogAutomationId =
                        [string]$resultDialog.Current.AutomationId
                    $resultDialogName = [string]$resultDialog.Current.Name
                    $resultDialogClassName =
                        [string]$resultDialog.Current.ClassName
                    Set-ForegroundWindowVerified -WindowHandle $resultDialogHandle
                    $resultMessage = Get-AutomationElementObservation `
                        -TargetProcessId $process.Id `
                        -AutomationId "65535" `
                        -RootWindowHandle $resultDialogHandle
                    $resultHelpText = [string]$resultDialog.Current.HelpText
                    $resultMessageText = [string]$resultMessage.Evidence.name
                    $requestedResultLeaf = [IO.Path]::GetFileName(
                        $malodyFullPackageExportFullPath)
                    $helpTextSuccess = $resultHelpText -eq "导出完成"
                    $helpTextCompatible = [string]::IsNullOrWhiteSpace($resultHelpText) -or
                        $helpTextSuccess
                    $visibleMessageSuccess =
                        $resultMessageText.TrimStart().StartsWith(
                            "导出完成",
                            [StringComparison]::Ordinal) -and
                        -not $resultMessageText.Contains(
                            "导出失败",
                            [StringComparison]::Ordinal) -and
                        $resultMessageText.Contains(
                            $requestedResultLeaf,
                            [StringComparison]::OrdinalIgnoreCase)
                    $resultIdentityVerified =
                        $resultDialogClassName -eq "#32770" -and
                        $resultDialogName -eq "导出" -and
                        [string]$resultMessage.Evidence.automationId -eq
                            "65535" -and
                        [string]$resultMessage.Element.Current.ClassName -eq
                            "Static"
                    $malodyFullPackageResultEvidence = [ordered]@{
                        automationId = $resultDialogAutomationId
                        name = $resultDialogName
                        className = $resultDialogClassName
                        nativeWindowHandle = [long]$resultDialogHandle
                        helpText = $resultHelpText
                        message = $resultMessage.Evidence
                        destinationMentioned = $resultMessageText.Contains(
                            $requestedResultLeaf,
                            [StringComparison]::OrdinalIgnoreCase)
                        helpTextSuccess = $helpTextSuccess
                        helpTextCompatible = $helpTextCompatible
                        visibleMessageSuccess = $visibleMessageSuccess
                        resultIdentityVerified = $resultIdentityVerified
                        successTone = $visibleMessageSuccess -and
                            $helpTextCompatible -and
                            $resultIdentityVerified
                    }
                    if (-not $malodyFullPackageResultEvidence.successTone) {
                        throw "Malody export result dialog did not prove successful completion for the requested archive."
                    }
                    Save-AutomationElementScreenshot `
                        -Element $resultDialog `
                        -Path $malodyFullPackageResultScreenshotFullPath
                    $malodyFullPackageResultScreenshotSha256 =
                        (Get-FileHash -LiteralPath $malodyFullPackageResultScreenshotFullPath -Algorithm SHA256).Hash

                    if ($targetOsuFullPackage) {
                        $malodyFullPackageArchiveEvidence = Get-OsuFullPackageArchiveEvidence `
                            -Path $malodyFullPackageExportFullPath `
                            -MainChartFileName $selectedFullPackageMainChartFileName `
                            -SourceRoot $malodyFullPackageSourceRootFullPath `
                            -ExpectedChartCount $selectedFullPackageExpectedChartCount `
                            -ExpectedOverallDifficulty $OsuFullPackageOverallDifficulty `
                            -ExpectedHpDrainRate $OsuFullPackageHpDrainRate `
                            -ExpectedHitObjectTime $selectedFullPackageExpectedHitObjectTime `
                            -OriginalLane $selectedFullPackageOriginalLane `
                            -ExpectedLane $selectedFullPackageExpectedExportedLane `
                            -ExpectSourceOsuSiblings $selectedFullPackageExpectSourceOsuSiblings
                        if ([int]$malodyFullPackageArchiveEvidence.entryCount -ne
                                $selectedFullPackageExpectedEntryCount -or
                            [int]$malodyFullPackageArchiveEvidence.chartEntryCount -ne
                                $selectedFullPackageExpectedChartCount -or
                            [int]$malodyFullPackageArchiveEvidence.malodyChartEntryCount -ne 0 -or
                            [int]$malodyFullPackageArchiveEvidence.siblingChartEntryCount -ne
                                ($selectedFullPackageExpectedChartCount - 1) -or
                            [int]$malodyFullPackageArchiveEvidence.mainChartEntryCount -ne 1 -or
                            -not [bool]$malodyFullPackageArchiveEvidence.mainChartFormatVerified -or
                            -not [bool]$malodyFullPackageArchiveEvidence.siblingChartsExact -or
                            -not [bool]$malodyFullPackageArchiveEvidence.allExcludedSourceArtifactsAbsent -or
                            -not [bool]$malodyFullPackageArchiveEvidence.allEntriesFlat -or
                            [int]$malodyFullPackageArchiveEvidence.unsafeEntryCount -ne 0 -or
                            [int]$malodyFullPackageArchiveEvidence.caseInsensitiveDuplicateCount -ne 0 -or
                            [int]$malodyFullPackageArchiveEvidence.collisionEntryCount -lt
                                $selectedFullPackageMinimumCollisionEntryCount) {
                            throw "Exported OSZ failed expected manifest, sibling policy, v14/difficulty/dirty-HitObject, safety, or resource validation."
                        }
                    }
                    elseif ($osuToMalodyFullPackage) {
                        $malodyFullPackageArchiveEvidence =
                            Get-OsuToMalodyFullPackageArchiveEvidence `
                                -Path $malodyFullPackageExportFullPath `
                                -SourceRoot $malodyFullPackageSourceRootFullPath `
                                -ExpectedBeat $malodyFullPackageDirtyInjection.submittedBeat `
                                -OriginalBeat $malodyFullPackageDirtyInjection.beforeBeat `
                                -ExpectedLane $selectedFullPackageExpectedExportedLane `
                                -OriginalLane $selectedFullPackageOriginalLane
                        $selectedFullPackageMainChartFileName =
                            [string]$malodyFullPackageArchiveEvidence.mainChartFileName
                        if ([int]$malodyFullPackageArchiveEvidence.entryCount -ne
                                $selectedFullPackageExpectedEntryCount -or
                            [int]$malodyFullPackageArchiveEvidence.chartEntryCount -ne 1 -or
                            -not [bool]$malodyFullPackageArchiveEvidence.allChartsValidJson -or
                            -not [bool]$malodyFullPackageArchiveEvidence.allChartsCompact -or
                            [int]$malodyFullPackageArchiveEvidence.mainChartEntryCount -ne 1 -or
                            -not [bool]$malodyFullPackageArchiveEvidence.mainChartDynamicNameVerified -or
                            [int]$malodyFullPackageArchiveEvidence.mainChartExactBeatMatchCount -ne 1 -or
                            [int]$malodyFullPackageArchiveEvidence.exactTargetTapCount -ne 1 -or
                            [int]$malodyFullPackageArchiveEvidence.originalTargetTapCount -ne 0 -or
                            [int]$malodyFullPackageArchiveEvidence.keyCount -ne
                                [int]$primaryExportEvidence.chart.structure.keyCount -or
                            [int]$malodyFullPackageArchiveEvidence.playableNoteCount -ne
                                [int]$primaryExportEvidence.chart.structure.noteCount -or
                            [int]$malodyFullPackageArchiveEvidence.longNoteCount -ne
                                [int]$primaryExportEvidence.chart.structure.longNoteCount -or
                            [int]$malodyFullPackageArchiveEvidence.serializedTimingCount -ne 2 -or
                            [int]$malodyFullPackageArchiveEvidence.serializedEffectCount -ne 11 -or
                            [int]$malodyFullPackageArchiveEvidence.serializedTimingAndEffectCount -ne
                                [int]$primaryExportEvidence.chart.structure.timingCount -or
                            [int]$malodyFullPackageArchiveEvidence.unsafeEntryCount -ne 0 -or
                            -not [bool]$malodyFullPackageArchiveEvidence.allEntriesFlat -or
                            [int]$malodyFullPackageArchiveEvidence.caseInsensitiveDuplicateCount -ne 0 -or
                            [int]$malodyFullPackageArchiveEvidence.unexpectedChartArtifactCount -ne 0 -or
                            -not [bool]$malodyFullPackageArchiveEvidence.allSourceArtifactsExcluded -or
                            -not [bool]$malodyFullPackageArchiveEvidence.resourceChainsVerified -or
                            -not [bool]$malodyFullPackageArchiveEvidence.allReferencedResourcesResolved -or
                            -not [bool]$malodyFullPackageArchiveEvidence.keySoundNodeVerified -or
                            [int]$malodyFullPackageArchiveEvidence.collisionEntryCount -lt
                                $selectedFullPackageMinimumCollisionEntryCount) {
                            throw "Exported osu!-to-Malody MCZ failed its unique dynamic MC, exact rational Beat/lane, compact JSON, structure, decoy exclusion, flat safety, or resource hash-chain gate."
                        }
                    }
                    else {
                        $malodyFullPackageArchiveEvidence = Get-MalodyFullPackageArchiveEvidence `
                            -Path $malodyFullPackageExportFullPath `
                            -MainChartFileName ([IO.Path]::GetFileName($chartFullPath)) `
                            -ExpectedBeat $malodyFullPackageDirtyInjection.submittedBeat `
                            -OriginalBeat $malodyFullPackageDirtyInjection.beforeBeat `
                            -ExpectedLane ([int]$selected[0].lane)
                        if ([int]$malodyFullPackageArchiveEvidence.chartEntryCount -ne
                                $selectedFullPackageExpectedChartCount -or
                            -not [bool]$malodyFullPackageArchiveEvidence.allChartsValidJson -or
                            -not [bool]$malodyFullPackageArchiveEvidence.allChartsCompact -or
                            [int]$malodyFullPackageArchiveEvidence.mainChartEntryCount -ne 1 -or
                            [int]$malodyFullPackageArchiveEvidence.mainChartExactBeatMatchCount -ne 1 -or
                            [int]$malodyFullPackageArchiveEvidence.mainChartOriginalBeatMatchCount -ne 0 -or
                            [int]$malodyFullPackageArchiveEvidence.unsafeEntryCount -ne 0 -or
                            [int]$malodyFullPackageArchiveEvidence.collisionEntryCount -lt 1) {
                            throw "Exported MCZ failed sibling-chart, compact-JSON, safe-entry, main-entry, or resource-collision validation."
                        }
                    }
                    $resultConfirm = Find-AutomationElementById `
                        -TargetProcessId $process.Id `
                        -AutomationId "2" `
                        -RootWindowHandle $resultDialogHandle
                    if ([string]$resultConfirm.Current.Name -ne "确定" -or
                        [string]$resultConfirm.Current.ClassName -ne "Button") {
                        throw "Malody native result did not expose WPF's id=2 确定 button."
                    }
                    $resultConfirmEvidence =
                        Get-AutomationElementEvidence -Element $resultConfirm
                    Click-AutomationElementWithMouse -Element $resultConfirm
                    $resultCloseDeadline = [DateTime]::UtcNow.AddSeconds(3)
                    while ([LumaChartAvaloniaCaptureNative]::IsWindow($resultDialogHandle) -and
                           [DateTime]::UtcNow -lt $resultCloseDeadline) {
                        Start-Sleep -Milliseconds 80
                    }
                    if ([LumaChartAvaloniaCaptureNative]::IsWindow($resultDialogHandle)) {
                        throw "Malody native result did not close after its physical 确定 click."
                    }
                    $malodyFullPackageResultEvidence["confirm"] =
                        $resultConfirmEvidence
                    $malodyFullPackageResultEvidence["physicalConfirmClickRetained"] = $true

                    $malodyFullPackageWorkingTreeAfterExport =
                        Get-DirectoryTreeEvidence -Root $editingFullPath
                    $malodyFullPackageWorkingTreeUnchangedByExport =
                        Test-DirectoryTreeEvidenceEqual `
                            -Before $malodyFullPackageWorkingTreeAfterDirty `
                            -After $malodyFullPackageWorkingTreeAfterExport
                    $malodyFullPackageSourceTreeAfter =
                        Get-DirectoryTreeEvidence -Root $malodyFullPackageSourceRootFullPath
                    $malodyFullPackageSourceTreeUnchanged =
                        Test-DirectoryTreeEvidenceEqual `
                            -Before $malodyFullPackageSourceTreeBefore `
                            -After $malodyFullPackageSourceTreeAfter
                    $scratchExportsRoot = Join-Path $malodyFullPackageScratchRoot "exports"
                    $scratchChildren = if (Test-Path -LiteralPath $scratchExportsRoot -PathType Container) {
                        @(Get-ChildItem -LiteralPath $scratchExportsRoot -Force)
                    } else { @() }
                    $malodyFullPackageScratchExportsAfter = [ordered]@{
                        sessionScratchRoot = $malodyFullPackageScratchRoot
                        exportsRoot = $scratchExportsRoot
                        exportsRootExists = Test-Path -LiteralPath $scratchExportsRoot -PathType Container
                        childCount = $scratchChildren.Count
                        clean = $scratchChildren.Count -eq 0
                    }
                    if (-not $malodyFullPackageWorkingTreeUnchangedByExport -or
                        -not $malodyFullPackageSourceTreeUnchanged -or
                        -not $malodyFullPackageScratchExportsAfter.clean) {
                        throw "Malody export changed the dirty working tree or source tree, or left scratch staging behind."
                    }
                    $malodyFullPackageExportExercised = $true
                    $interactionActionsCompletedAtUtc = [DateTimeOffset]::UtcNow
                }
                elseif ($proEditorExerciseEnabled) {
                    $proEditorActivationTarget = $null
                    if (-not $ExerciseProEditorSaveAsOsu) {
                        $activationWaitBudgets = @(1500, 2000, 5000)
                        $activationAttempts = [Collections.Generic.List[object]]::new()
                        for ($activationIndex = 0;
                             $activationIndex -lt $activationWaitBudgets.Count;
                             $activationIndex++) {
                            Set-ForegroundWindowVerified -WindowHandle $process.MainWindowHandle
                            $toggleObservation = Get-AutomationElementObservation `
                                -TargetProcessId $process.Id `
                                -AutomationId "ProEditor.Toggle" `
                                -RootWindowHandle $process.MainWindowHandle `
                                -TimeoutMilliseconds 3000
                            if (-not [bool]$toggleObservation.Evidence.isEnabled) {
                                throw "ProEditor toggle was disabled before its physical click."
                            }
                            Click-AutomationElementWithMouse -Element $toggleObservation.Element
                            $activationTimeout = $null
                            try {
                                $proEditorActivationTarget = Find-AutomationElementById `
                                    -TargetProcessId $process.Id `
                                    -AutomationId "ProEditor.HorizontalPan" `
                                    -RootWindowHandle $process.MainWindowHandle `
                                    -TimeoutMilliseconds $activationWaitBudgets[$activationIndex]
                            }
                            catch {
                                $activationTimeout = [string]$_.Exception.Message
                                if ($activationTimeout -notmatch
                                    "^Timed out finding UI Automation id 'ProEditor\.HorizontalPan' for process [0-9]+\.$") {
                                    throw
                                }
                            }
                            $activationAttempts.Add([pscustomobject][ordered]@{
                                    attempt = $activationIndex + 1
                                    mainWindowForegroundVerified = $true
                                    toggle = $toggleObservation.Evidence
                                    input = "physical Win32 mouse click at UI Automation bounds"
                                    targetAutomationId = "ProEditor.HorizontalPan"
                                    targetWaitBudgetMilliseconds =
                                        $activationWaitBudgets[$activationIndex]
                                    targetFound = $null -ne $proEditorActivationTarget
                                    timedOut = $null -eq $proEditorActivationTarget
                                    timeoutMessage = $activationTimeout
                                })
                            if ($null -ne $proEditorActivationTarget) { break }
                        }
                        if ($null -eq $proEditorActivationTarget) {
                            throw "Timed out opening ProEditor after three bounded physical-toggle attempts."
                        }
                        $proEditorActivationEvidence = [ordered]@{
                            path = "foreground verification + physical Win32 mouse clicks + UI Automation state observation"
                            maximumAttempts = 3
                            attemptCount = $activationAttempts.Count
                            retryUsed = $activationAttempts.Count -gt 1
                            boundedTargetWaitBudgetMilliseconds = 8500
                            allPhysicalClicks =
                                @($activationAttempts | Where-Object {
                                        [string]$_.input -cne
                                            "physical Win32 mouse click at UI Automation bounds"
                                    }).Count -eq 0
                            automationFallbackUsed = $false
                            targetFound = $true
                            targetAutomationId = "ProEditor.HorizontalPan"
                            attempts = @($activationAttempts)
                        }
                    }

                    if ($ExerciseProEditorReveal) {
                        Start-Sleep -Milliseconds 250
                    }
                    elseif ($ExerciseProEditorPan) {
                        $panSlider = $proEditorActivationTarget
                        $rangePatternObject = $null
                        if (-not $panSlider.TryGetCurrentPattern(
                                [System.Windows.Automation.RangeValuePattern]::Pattern,
                                [ref]$rangePatternObject)) {
                            throw "ProEditor horizontal pan slider does not expose RangeValuePattern."
                        }
                        $rangePattern = [System.Windows.Automation.RangeValuePattern]$rangePatternObject
                        $range = $rangePattern.Current.Maximum - $rangePattern.Current.Minimum
                        if ($range -le 0) { throw "ProEditor horizontal pan slider has no movable range." }
                        $bounds = $panSlider.Current.BoundingRectangle
                        if ($bounds.IsEmpty -or $bounds.Width -le 20 -or $bounds.Height -le 2) {
                            throw "ProEditor horizontal pan slider has invalid bounds."
                        }
                        $startFraction = ($rangePattern.Current.Value - $rangePattern.Current.Minimum) / $range
                        $startX = [int][Math]::Round($bounds.Left + 8 + ($bounds.Width - 16) * $startFraction)
                        # Draft fixture columns D8-D10 live to the right of the
                        # official 4K track. A negative pan brings those columns
                        # into the clipped viewport for the formal screenshot.
                        $targetX = [int][Math]::Round($bounds.Left + 8 + ($bounds.Width - 16) * .18)
                        $sliderY = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
                        Invoke-MouseDrag -StartX $startX -StartY $sliderY -EndX $targetX -EndY $sliderY
                        Start-Sleep -Milliseconds 350
                    }
                    elseif ($ExerciseProEditorEdit) {
                        $probe = $primaryProEditorActionEvidence.timeline.proEditor.probe
                        if ($null -eq $probe -or $null -eq $probe.draftTapTarget.windowPointDip -or
                            $null -eq $probe.officialMoveTarget.windowPointDip -or
                            $null -eq $probe.draftHoldStartTarget.windowPointDip -or
                            $null -eq $probe.draftHoldEndTarget.windowPointDip) {
                            throw "Primary GUI evidence did not expose deterministic ProEditor pointer targets."
                        }
                        $draftTap = Convert-EvidencePointToScreen `
                            -Point $probe.draftTapTarget.windowPointDip `
                            -Evidence $primaryProEditorActionEvidence `
                            -WindowRectangle $exerciseRectangle `
                            -WindowWidth $exerciseWidth `
                            -WindowHeight $exerciseHeight
                        $officialMove = Convert-EvidencePointToScreen `
                            -Point $probe.officialMoveTarget.windowPointDip `
                            -Evidence $primaryProEditorActionEvidence `
                            -WindowRectangle $exerciseRectangle `
                            -WindowWidth $exerciseWidth `
                            -WindowHeight $exerciseHeight
                        $holdStart = Convert-EvidencePointToScreen `
                            -Point $probe.draftHoldStartTarget.windowPointDip `
                            -Evidence $primaryProEditorActionEvidence `
                            -WindowRectangle $exerciseRectangle `
                            -WindowWidth $exerciseWidth `
                            -WindowHeight $exerciseHeight
                        $holdEnd = Convert-EvidencePointToScreen `
                            -Point $probe.draftHoldEndTarget.windowPointDip `
                            -Evidence $primaryProEditorActionEvidence `
                            -WindowRectangle $exerciseRectangle `
                            -WindowWidth $exerciseWidth `
                            -WindowHeight $exerciseHeight

                        $tapTool = Find-AutomationElementById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Timeline.Tool.Tap" `
                            -RootWindowHandle $process.MainWindowHandle
                        Click-AutomationElementWithMouse -Element $tapTool
                        Invoke-MouseClick -X $draftTap.X -Y $draftTap.Y
                        Start-Sleep -Milliseconds 220

                        $selectTool = Find-AutomationElementById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Timeline.Tool.Select" `
                            -RootWindowHandle $process.MainWindowHandle
                        Click-AutomationElementWithMouse -Element $selectTool
                        Invoke-MouseDrag `
                            -StartX $draftTap.X -StartY $draftTap.Y `
                            -EndX $officialMove.X -EndY $officialMove.Y
                        Start-Sleep -Milliseconds 250

                        $holdTool = Find-AutomationElementById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Timeline.Tool.Hold" `
                            -RootWindowHandle $process.MainWindowHandle
                        Click-AutomationElementWithMouse -Element $holdTool
                        Invoke-MouseDrag `
                            -StartX $holdStart.X -StartY $holdStart.Y `
                            -EndX $holdEnd.X -EndY $holdEnd.Y
                        Start-Sleep -Milliseconds 300
                        if ($SaveAfterProEditorEdit) {
                            $saveButton = Find-AutomationElementById `
                                -TargetProcessId $process.Id `
                                -AutomationId "Editor.Save" `
                                -RootWindowHandle $process.MainWindowHandle
                            Click-AutomationElementWithMouse -Element $saveButton
                            Start-Sleep -Milliseconds 900
                        }
                    }
                    elseif ($ExerciseProEditorSaveAsOsu) {
                        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($proEditorSaveAsOsuFullPath)) -Force |
                            Out-Null
                        $saveAsButton = Find-AutomationElementById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Editor.SaveAs" `
                            -RootWindowHandle $process.MainWindowHandle
                        Click-AutomationElementWithMouse -Element $saveAsButton
                        $saveDialog = Find-AutomationElementByName `
                            -TargetProcessId $process.Id `
                            -Name "另存谱面" `
                            -TimeoutMilliseconds 6000
                        $saveDialogHandle = [IntPtr]$saveDialog.Current.NativeWindowHandle
                        if ($saveDialogHandle -eq [IntPtr]::Zero) {
                            throw "Native Save As dialog did not expose a window handle."
                        }
                        $filenameIdCondition = [System.Windows.Automation.PropertyCondition]::new(
                            [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
                            "1001")
                        $destinationDirectory = [IO.Path]::GetDirectoryName($proEditorSaveAsOsuFullPath)
                        if (-not $destinationDirectory.Equals(
                                [IO.Path]::GetDirectoryName($chartFullPath),
                                [StringComparison]::OrdinalIgnoreCase)) {
                            throw "Native Save As destination must match the source chart directory."
                        }
                        $sourceFileName = [IO.Path]::GetFileName($chartFullPath)
                        $sourceNameCondition = [System.Windows.Automation.PropertyCondition]::new(
                            [System.Windows.Automation.AutomationElement]::NameProperty,
                            $sourceFileName)
                        $listItemCondition = [System.Windows.Automation.PropertyCondition]::new(
                            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                            [System.Windows.Automation.ControlType]::ListItem)
                        $sourceListItemCondition = [System.Windows.Automation.AndCondition]::new(
                            $sourceNameCondition,
                            $listItemCondition)
                        $sourceListItemDeadline = [DateTime]::UtcNow.AddSeconds(4)
                        $sourceListItem = $null
                        do {
                            $sourceListItem = $saveDialog.FindFirst(
                                [System.Windows.Automation.TreeScope]::Descendants,
                                $sourceListItemCondition)
                            if (-not $sourceListItem) { Start-Sleep -Milliseconds 100 }
                        } while (-not $sourceListItem -and [DateTime]::UtcNow -lt $sourceListItemDeadline)
                        if (-not $sourceListItem) {
                            throw "Native Save As did not open in the source chart directory; '$sourceFileName' was not visible as a ListItem."
                        }
                        $proEditorSaveAsInitialDirectoryVerified = $true
                        $proEditorSaveAsVisibleSourceName = [string]$sourceListItem.Current.Name
                        $fileTypeHost = Find-AutomationElementById `
                            -TargetProcessId $process.Id `
                            -AutomationId "FileTypeControlHost" `
                            -RootWindowHandle $saveDialogHandle `
                            -TimeoutMilliseconds 4000
                        Click-AutomationElementWithMouse -Element $fileTypeHost
                        Start-Sleep -Milliseconds 120
                        # MC is the first source-driven suggestion; osu!mania is
                        # the second product-provided choice. Select it through
                        # the native dialog keyboard path before typing the name.
                        [System.Windows.Forms.SendKeys]::SendWait("{END}")
                        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
                        Start-Sleep -Milliseconds 180
                        $fileNameHost = Find-AutomationElementById `
                            -TargetProcessId $process.Id `
                            -AutomationId "FileNameControlHost" `
                            -RootWindowHandle $saveDialogHandle `
                            -TimeoutMilliseconds 6000
                        $saveName = $fileNameHost.FindFirst(
                            [System.Windows.Automation.TreeScope]::Descendants,
                            $filenameIdCondition)
                        if (-not $saveName) {
                            throw "Native Save As filename host did not expose its editable 1001 child."
                        }
                        $saveNameValuePattern = $null
                        if (-not $saveName.TryGetCurrentPattern(
                                [System.Windows.Automation.ValuePattern]::Pattern,
                                [ref]$saveNameValuePattern)) {
                            $editCondition = [System.Windows.Automation.PropertyCondition]::new(
                                [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                                [System.Windows.Automation.ControlType]::Edit)
                            $saveNameEdit = $saveName.FindFirst(
                                [System.Windows.Automation.TreeScope]::Descendants,
                                $editCondition)
                            if ($saveNameEdit) { $saveName = $saveNameEdit }
                        }
                        $editablePattern = $null
                        if ($saveName.TryGetCurrentPattern(
                                [System.Windows.Automation.ValuePattern]::Pattern,
                                [ref]$editablePattern)) {
                            Set-AutomationElementValue `
                                -Element $saveName `
                                -Value ([IO.Path]::GetFileName($proEditorSaveAsOsuFullPath))
                        } else {
                            # Windows 11's native picker may expose this ComboBox
                            # through keyboard focus only.
                            Click-AutomationElementWithMouse -Element $saveName
                            Start-Sleep -Milliseconds 120
                            [System.Windows.Forms.SendKeys]::SendWait("^a")
                            [System.Windows.Forms.SendKeys]::SendWait(
                                [IO.Path]::GetFileName($proEditorSaveAsOsuFullPath))
                            Start-Sleep -Milliseconds 150
                        }
                        if ([string]$saveName.Current.Name -notmatch '\.osu$') {
                            throw "Native Save As filename control did not accept the requested .osu path; current value is '$($saveName.Current.Name)'."
                        }
                        # Submit while the real filename control still owns focus;
                        # this is the most stable default-button path on the
                        # Windows 11 common file dialog.
                        Set-ForegroundWindowVerified -WindowHandle $saveDialogHandle
                        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
                        $focusedSubmitDeadline = [DateTime]::UtcNow.AddMilliseconds(1400)
                        while (-not (Test-Path -LiteralPath $proEditorSaveAsOsuFullPath) -and
                               [DateTime]::UtcNow -lt $focusedSubmitDeadline) {
                            Start-Sleep -Milliseconds 80
                        }
                        $nativeSave = $null
                        if (-not (Test-Path -LiteralPath $proEditorSaveAsOsuFullPath)) {
                            $saveIdCondition = [System.Windows.Automation.PropertyCondition]::new(
                                [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
                                "1")
                            $saveCandidates = $saveDialog.FindAll(
                                [System.Windows.Automation.TreeScope]::Descendants,
                                $saveIdCondition)
                            for ($saveIndex = 0; $saveIndex -lt $saveCandidates.Count; $saveIndex++) {
                                $candidateSave = $saveCandidates.Item($saveIndex)
                                if ([string]$candidateSave.Current.Name -match '^保存|^Save') {
                                    $nativeSave = $candidateSave
                                    break
                                }
                            }
                            if (-not $nativeSave) {
                                $controlSummary = [Collections.Generic.List[string]]::new()
                                $allDialogControls = $saveDialog.FindAll(
                                    [System.Windows.Automation.TreeScope]::Descendants,
                                    [System.Windows.Automation.Condition]::TrueCondition)
                                for ($controlIndex = 0;
                                     $controlIndex -lt [Math]::Min(80, $allDialogControls.Count);
                                     $controlIndex++) {
                                    $control = $allDialogControls.Item($controlIndex)
                                    if (-not [string]::IsNullOrWhiteSpace([string]$control.Current.Name)) {
                                        $controlSummary.Add(("{0}|{1}|{2}" -f
                                            $control.Current.ControlType.ProgrammaticName,
                                            $control.Current.AutomationId,
                                            $control.Current.Name))
                                    }
                                }
                                throw "Native Save As dialog did not expose a Save button. Controls: $($controlSummary -join '; ')"
                            }
                            Click-AutomationElementWithMouse -Element $nativeSave
                            $mouseSaveDeadline = [DateTime]::UtcNow.AddMilliseconds(1200)
                            while (-not (Test-Path -LiteralPath $proEditorSaveAsOsuFullPath) -and
                                   [DateTime]::UtcNow -lt $mouseSaveDeadline) {
                                Start-Sleep -Milliseconds 80
                            }
                            if (-not (Test-Path -LiteralPath $proEditorSaveAsOsuFullPath)) {
                                # Some Windows 11 builds expose the native Save button
                                # as a Pane whose clickable bounds do not invoke it.
                                # Enter is the dialog's real default-button keyboard
                                # path, not a product-method bypass.
                                Set-ForegroundWindowVerified -WindowHandle $saveDialogHandle
                                [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
                            }
                        }
                        $saveAsDeadline = [DateTime]::UtcNow.AddSeconds(8)
                        while (-not (Test-Path -LiteralPath $proEditorSaveAsOsuFullPath) -and
                               [DateTime]::UtcNow -lt $saveAsDeadline) {
                            Start-Sleep -Milliseconds 100
                        }
                        if (-not (Test-Path -LiteralPath $proEditorSaveAsOsuFullPath)) {
                            throw "Native Save As did not create the requested osu file."
                        }
                        $proToggle = Find-AutomationElementById `
                            -TargetProcessId $process.Id `
                            -AutomationId "ProEditor.Toggle" `
                            -RootWindowHandle $process.MainWindowHandle
                        Click-AutomationElementWithMouse -Element $proToggle
                        Start-Sleep -Milliseconds 500
                    }
                }
                elseif ($ExerciseNoteProperty) {
                    if ($DeriveNotePropertyFromSelection) {
                        $primaryEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw | ConvertFrom-Json
                        $selected = @($primaryEvidence.timeline.selectedNotes)
                        if ($selected.Count -ne 1 -or $selected[0].endBeat) {
                            throw "Primary GUI evidence did not expose exactly one Tap Note for property editing."
                        }
                        $authored = $selected[0].beat
                        $sourceDenominator = [int]$authored.denominator
                        if ($sourceDenominator -le 0 -or $sourceDenominator -gt 10000) {
                            throw "Selected Note denominator cannot be safely expanded for the property gate."
                        }
                        $NotePropertyBeat = "{0}:{1}/{2}" -f `
                            [int]$authored.bar, `
                            ([int]$authored.numerator * 2), `
                            ($sourceDenominator * 2)
                        $NotePropertyEndBeat = "{0}:{1}/{2}" -f `
                            [int]$authored.bar, `
                            ([int]$authored.numerator * 100 + 1), `
                            ($sourceDenominator * 100)
                        $NotePropertyLane = ([int]$selected[0].lane + 1).ToString(
                            [Globalization.CultureInfo]::InvariantCulture)
                        $NotePropertySound = if ($null -eq $selected[0].sound) {
                            ""
                        } else {
                            [string]$selected[0].sound
                        }
                    }
                    $propertyValues = [ordered]@{
                        "Note Beat" = $NotePropertyBeat
                        "Note End Beat" = $NotePropertyEndBeat
                        "Note Lane" = $NotePropertyLane
                        "Note Volume" = $NotePropertyVolume
                        "Note Sound" = $NotePropertySound
                        "Note Group" = $NotePropertyGroup
                    }
                    foreach ($entry in $propertyValues.GetEnumerator()) {
                        $field = Find-AutomationElementByName `
                            -TargetProcessId $process.Id `
                            -Name $entry.Key `
                            -RootWindowHandle $process.MainWindowHandle
                        Set-AutomationElementValue -Element $field -Value ([string]$entry.Value)
                    }
                    $applyButton = Find-AutomationElementByName `
                        -TargetProcessId $process.Id `
                        -Name "应用 Note" `
                        -RootWindowHandle $process.MainWindowHandle
                    $applyBounds = $applyButton.Current.BoundingRectangle
                    Click-AutomationElementWithMouse -Element $applyButton
                    $notePropertyPhysicalActions.Add([ordered]@{
                        action = "apply-note"
                        automationName = "应用 Note"
                        input = "physical Win32 mouse click at UI Automation bounds"
                        x = [int][Math]::Round($applyBounds.Left + $applyBounds.Width / 2)
                        y = [int][Math]::Round($applyBounds.Top + $applyBounds.Height / 2)
                    })
                    Start-Sleep -Milliseconds 500
                    if ($SaveAfterNoteProperty -or $ExerciseSourceSaveFailure) {
                        $sourceSaveFailureLock = $null
                        $sourceBeforeFailedSave = $null
                        if ($ExerciseSourceSaveFailure) {
                            $sourceBeforeFailedSaveItem =
                                Get-Item -LiteralPath $chartFullPath
                            $sourceBeforeFailedSave = [ordered]@{
                                path = $chartFullPath
                                length = [long]$sourceBeforeFailedSaveItem.Length
                                lastWriteTimeUtc =
                                    $sourceBeforeFailedSaveItem.LastWriteTimeUtc.ToString(
                                        "O",
                                        [Globalization.CultureInfo]::InvariantCulture)
                                sha256 = (Get-FileHash `
                                    -LiteralPath $chartFullPath `
                                    -Algorithm SHA256).Hash
                            }
                            $sourceSaveFailureLock = [IO.File]::Open(
                                $chartFullPath,
                                [IO.FileMode]::Open,
                                [IO.FileAccess]::ReadWrite,
                                [IO.FileShare]::None)
                        }
                        try {
                            $commandMenuToggle = Find-AutomationElementById `
                                -TargetProcessId $process.Id `
                                -AutomationId "Editor.CommandMenuToggle" `
                                -RootWindowHandle $process.MainWindowHandle
                            $commandMenuToggleBounds =
                                $commandMenuToggle.Current.BoundingRectangle
                            Click-AutomationElementWithMouse -Element $commandMenuToggle
                            $notePropertyPhysicalActions.Add([ordered]@{
                                action = "open-command-menu"
                                automationId = "Editor.CommandMenuToggle"
                                input = "physical Win32 mouse click at UI Automation bounds"
                                x = [int][Math]::Round(
                                    $commandMenuToggleBounds.Left +
                                    $commandMenuToggleBounds.Width / 2)
                                y = [int][Math]::Round(
                                    $commandMenuToggleBounds.Top +
                                    $commandMenuToggleBounds.Height / 2)
                            })
                            Start-Sleep -Milliseconds 250
                            $saveButton = Find-AutomationElementById `
                                -TargetProcessId $process.Id `
                                -AutomationId "Editor.Save" `
                                -RootWindowHandle $process.MainWindowHandle
                            $saveBounds = $saveButton.Current.BoundingRectangle
                            Click-AutomationElementWithMouse -Element $saveButton
                            $notePropertyPhysicalActions.Add([ordered]@{
                                action = "save"
                                automationId = "Editor.Save"
                                input = "physical Win32 mouse click at UI Automation bounds"
                                x = [int][Math]::Round(
                                    $saveBounds.Left + $saveBounds.Width / 2)
                                y = [int][Math]::Round(
                                    $saveBounds.Top + $saveBounds.Height / 2)
                            })
                            if ($ExerciseSourceSaveFailure) {
                                $failureDialog = Find-AutomationElementByName `
                                    -TargetProcessId $process.Id `
                                    -Name "LumaChart Studio" `
                                    -TimeoutMilliseconds 10000
                                $failureDialogHandle =
                                    [IntPtr]$failureDialog.Current.NativeWindowHandle
                                $failureDialogName =
                                    [string]$failureDialog.Current.Name
                                $failureDialogClassName =
                                    [string]$failureDialog.Current.ClassName
                                if ($failureDialogHandle -eq [IntPtr]::Zero -or
                                    $failureDialogClassName -ne "#32770") {
                                    throw "Source-save failure did not expose the WPF-compatible native error dialog."
                                }
                                $failureMessage = Get-AutomationElementObservation `
                                    -TargetProcessId $process.Id `
                                    -AutomationId "65535" `
                                    -RootWindowHandle $failureDialogHandle `
                                    -TimeoutMilliseconds 10000
                                if (-not [string]$failureMessage.Evidence.name.StartsWith(
                                        "无法保存原谱面；软件旁缓存已保留",
                                        [StringComparison]::Ordinal)) {
                                    throw "Source-save failure dialog did not explain that the software-side cache was retained."
                                }
                                Set-ForegroundWindowVerified `
                                    -WindowHandle $failureDialogHandle
                                Save-AutomationElementScreenshot `
                                    -Element $failureDialog `
                                    -Path $sourceSaveFailureDialogScreenshotFullPath
                                $sourceSaveFailureDialogScreenshotSha256 =
                                    (Get-FileHash `
                                        -LiteralPath $sourceSaveFailureDialogScreenshotFullPath `
                                        -Algorithm SHA256).Hash
                                $failureConfirm = Get-AutomationElementObservation `
                                    -TargetProcessId $process.Id `
                                    -AutomationId "2" `
                                    -RootWindowHandle $failureDialogHandle `
                                    -TimeoutMilliseconds 10000
                                Click-AutomationElementWithMouse `
                                    -Element $failureConfirm.Element
                                $failureDialogCloseDeadline =
                                    [DateTime]::UtcNow.AddSeconds(4)
                                while ([LumaChartAvaloniaCaptureNative]::IsWindow(
                                        $failureDialogHandle) -and
                                       [DateTime]::UtcNow -lt
                                            $failureDialogCloseDeadline) {
                                    Start-Sleep -Milliseconds 80
                                }
                                if ([LumaChartAvaloniaCaptureNative]::IsWindow(
                                        $failureDialogHandle)) {
                                    throw "Source-save failure dialog did not close after its physical 确定 click."
                                }
                                $sourceSaveFailureLock.Dispose()
                                $sourceSaveFailureLock = $null
                                $sourceAfterFailedSaveItem =
                                    Get-Item -LiteralPath $chartFullPath
                                $sourceAfterFailedSave = [ordered]@{
                                    path = $chartFullPath
                                    length = [long]$sourceAfterFailedSaveItem.Length
                                    lastWriteTimeUtc =
                                        $sourceAfterFailedSaveItem.LastWriteTimeUtc.ToString(
                                            "O",
                                            [Globalization.CultureInfo]::InvariantCulture)
                                    sha256 = (Get-FileHash `
                                        -LiteralPath $chartFullPath `
                                        -Algorithm SHA256).Hash
                                }
                                $sourceUnchanged =
                                    [long]$sourceBeforeFailedSave.length -eq
                                        [long]$sourceAfterFailedSave.length -and
                                    [string]$sourceBeforeFailedSave.lastWriteTimeUtc -eq
                                        [string]$sourceAfterFailedSave.lastWriteTimeUtc -and
                                    [string]$sourceBeforeFailedSave.sha256 -eq
                                        [string]$sourceAfterFailedSave.sha256
                                if (-not $sourceUnchanged) {
                                    throw "Failed source Save changed the locked source file."
                                }
                                $sourceSaveFailureAction = [ordered]@{
                                    sourceBefore = $sourceBeforeFailedSave
                                    sourceAfter = $sourceAfterFailedSave
                                    sourceUnchanged = $sourceUnchanged
                                    lockMode =
                                        "FileAccess.ReadWrite + FileShare.None"
                                    dialog = [ordered]@{
                                        name = $failureDialogName
                                        className = $failureDialogClassName
                                        nativeWindowHandle =
                                            [long]$failureDialogHandle
                                        message = $failureMessage.Evidence
                                        confirm = $failureConfirm.Evidence
                                        screenshotPath =
                                            $sourceSaveFailureDialogScreenshotFullPath
                                        screenshotSha256 =
                                            $sourceSaveFailureDialogScreenshotSha256
                                        physicalConfirmClickRetained = $true
                                        closedAfterConfirm = $true
                                    }
                                    verified = $true
                                }
                            }
                            Start-Sleep -Milliseconds 900
                        }
                        finally {
                            if ($null -ne $sourceSaveFailureLock) {
                                $sourceSaveFailureLock.Dispose()
                            }
                        }
                    }
                }
                elseif ($ExerciseGroupAssign) {
                    $groupField = Find-AutomationElementByName `
                        -TargetProcessId $process.Id `
                        -Name "Group ID" `
                        -RootWindowHandle $process.MainWindowHandle
                    Set-AutomationElementValue -Element $groupField -Value $GroupId
                    $assignButton = Find-AutomationElementByName `
                        -TargetProcessId $process.Id `
                        -Name "Group 分配选择" `
                        -RootWindowHandle $process.MainWindowHandle
                    Click-AutomationElementWithMouse -Element $assignButton
                    Start-Sleep -Milliseconds 500
                    if ($SaveAfterGroupAssign) {
                        $commandMenuToggle = Find-AutomationElementById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Editor.CommandMenuToggle" `
                            -RootWindowHandle $process.MainWindowHandle
                        Click-AutomationElementWithMouse -Element $commandMenuToggle
                        Start-Sleep -Milliseconds 250
                        $saveButton = Find-AutomationElementById `
                            -TargetProcessId $process.Id `
                            -AutomationId "Editor.Save" `
                            -RootWindowHandle $process.MainWindowHandle
                        Click-AutomationElementWithMouse -Element $saveButton
                        Start-Sleep -Milliseconds 900
                    }
                    $assignedGroupToggle = Wait-AutomationToggleState `
                        -TargetProcessId $process.Id `
                        -Name ("Group {0} 显示" -f $groupIdValue) `
                        -ExpectedState ([System.Windows.Automation.ToggleState]::On) `
                        -RootWindowHandle $process.MainWindowHandle
                    Scroll-AutomationElementIntoView -Element $assignedGroupToggle
                }
                elseif ($ExerciseGroupVisibility) {
                    $hideResult = Invoke-IdempotentButtonAndWaitForToggleState `
                        -TargetProcessId $process.Id `
                        -ButtonName "Group 隐藏非零" `
                        -ToggleName ("Group {0} 显示" -f $groupIdValue) `
                        -ExpectedState ([System.Windows.Automation.ToggleState]::Off) `
                        -RootWindowHandle $process.MainWindowHandle
                    $hiddenGroupToggle = $hideResult.Element
                    $groupVisibilityAutomationFallbackUsed =
                        [bool]$hideResult.AutomationFallbackUsed
                    Scroll-AutomationElementIntoView -Element $hiddenGroupToggle
                    Start-Sleep -Milliseconds 300
                }
                elseif ($ExerciseGroupPlacement) {
                    $primaryEvidence = $primaryGroupActionEvidence
                    $placementProbe = $primaryEvidence.timeline.placementProbe
                    $tapTarget = $placementProbe.tapTarget
                    $holdStartTarget = $placementProbe.holdStartTarget
                    $holdEndTarget = $placementProbe.holdEndTarget
                    $clientWidthDip = [double]$primaryEvidence.window.clientWidthDip
                    $clientHeightDip = [double]$primaryEvidence.window.clientHeightDip
                    if (-not $placementProbe -or -not $tapTarget.windowPointDip -or
                        -not $holdStartTarget.windowPointDip -or -not $holdEndTarget.windowPointDip -or
                        [int]$holdStartTarget.lane -ne [int]$holdEndTarget.lane -or
                        $clientWidthDip -le 0 -or $clientHeightDip -le 0) {
                        throw "Primary GUI evidence did not expose usable frozen Tap/Hold placement targets."
                    }

                    # Prove the same visible workflow a user performs: hide all
                    # non-zero groups, set Group 7 as current (which unhides it),
                    # then place both a Tap and an LN through real mouse input.
                    $placementHideResult = Invoke-IdempotentButtonAndWaitForToggleState `
                        -TargetProcessId $process.Id `
                        -ButtonName "Group 隐藏非零" `
                        -ToggleName ("Group {0} 显示" -f $groupIdValue) `
                        -ExpectedState ([System.Windows.Automation.ToggleState]::Off) `
                        -RootWindowHandle $process.MainWindowHandle
                    $groupPlacementHideAutomationFallbackUsed =
                        [bool]$placementHideResult.AutomationFallbackUsed

                    $groupField = Find-AutomationElementByName `
                        -TargetProcessId $process.Id `
                        -Name "Group ID" `
                        -RootWindowHandle $process.MainWindowHandle
                    Set-AutomationElementValue -Element $groupField -Value $GroupId
                    $setCurrentButton = Find-AutomationElementByName `
                        -TargetProcessId $process.Id `
                        -Name "Group 设为当前" `
                        -RootWindowHandle $process.MainWindowHandle
                    Click-AutomationElementWithMouse -Element $setCurrentButton
                    $visibleGroupToggle = Wait-AutomationToggleState `
                        -TargetProcessId $process.Id `
                        -Name ("Group {0} 显示" -f $groupIdValue) `
                        -ExpectedState ([System.Windows.Automation.ToggleState]::On) `
                        -RootWindowHandle $process.MainWindowHandle

                    $scaleX = $exerciseWidth / $clientWidthDip
                    $scaleY = $exerciseHeight / $clientHeightDip
                    $tapX = $exerciseRectangle.Left + [int][Math]::Round(
                        [double]$tapTarget.windowPointDip.x * $scaleX)
                    $tapY = $exerciseRectangle.Top + [int][Math]::Round(
                        [double]$tapTarget.windowPointDip.y * $scaleY)
                    $holdStartX = $exerciseRectangle.Left + [int][Math]::Round(
                        [double]$holdStartTarget.windowPointDip.x * $scaleX)
                    $holdStartY = $exerciseRectangle.Top + [int][Math]::Round(
                        [double]$holdStartTarget.windowPointDip.y * $scaleY)
                    $holdEndX = $exerciseRectangle.Left + [int][Math]::Round(
                        [double]$holdEndTarget.windowPointDip.x * $scaleX)
                    $holdEndY = $exerciseRectangle.Top + [int][Math]::Round(
                        [double]$holdEndTarget.windowPointDip.y * $scaleY)

                    $tapButton = Find-AutomationElementByName `
                        -TargetProcessId $process.Id `
                        -Name "Timeline Tool Tap" `
                        -RootWindowHandle $process.MainWindowHandle
                    Click-AutomationElementWithMouse -Element $tapButton
                    if (-not [LumaChartAvaloniaCaptureNative]::SetCursorPos($tapX, $tapY)) {
                        throw "SetCursorPos failed before Group Tap placement."
                    }
                    Start-Sleep -Milliseconds 80
                    [LumaChartAvaloniaCaptureNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
                    $buttonDown = $true
                    Start-Sleep -Milliseconds 80
                    [LumaChartAvaloniaCaptureNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
                    $buttonDown = $false
                    Start-Sleep -Milliseconds 220

                    $holdButton = Find-AutomationElementByName `
                        -TargetProcessId $process.Id `
                        -Name "Timeline Tool Hold" `
                        -RootWindowHandle $process.MainWindowHandle
                    Click-AutomationElementWithMouse -Element $holdButton
                    if (-not [LumaChartAvaloniaCaptureNative]::SetCursorPos($holdStartX, $holdStartY)) {
                        throw "SetCursorPos failed before Group Hold placement."
                    }
                    Start-Sleep -Milliseconds 80
                    [LumaChartAvaloniaCaptureNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
                    $buttonDown = $true
                    Start-Sleep -Milliseconds 80
                    for ($step = 1; $step -le 4; $step++) {
                        $fraction = $step / 4.0
                        $moveX = [int][Math]::Round($holdStartX + ($holdEndX - $holdStartX) * $fraction)
                        $moveY = [int][Math]::Round($holdStartY + ($holdEndY - $holdStartY) * $fraction)
                        if (-not [LumaChartAvaloniaCaptureNative]::SetCursorPos($moveX, $moveY)) {
                            throw "SetCursorPos failed during Group Hold placement."
                        }
                        Start-Sleep -Milliseconds 45
                    }
                    if ($holdPlacementPreviewScreenshotFullPath) {
                        Start-Sleep -Milliseconds 120
                        Save-ScreenRegionScreenshot `
                            -Left $exerciseRectangle.Left `
                            -Top $exerciseRectangle.Top `
                            -Width $exerciseWidth `
                            -Height $exerciseHeight `
                            -Path $holdPlacementPreviewScreenshotFullPath
                    }
                    [LumaChartAvaloniaCaptureNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
                    $buttonDown = $false
                    Start-Sleep -Milliseconds 300

                    # Keep the Group 7 current/visible state in the formal screenshot.
                    $visibleGroupToggle = Wait-AutomationToggleState `
                        -TargetProcessId $process.Id `
                        -Name ("Group {0} 显示" -f $groupIdValue) `
                        -ExpectedState ([System.Windows.Automation.ToggleState]::On) `
                        -RootWindowHandle $process.MainWindowHandle
                    Scroll-AutomationElementIntoView -Element $visibleGroupToggle
                }
                elseif ($ExerciseLongToTap) {
                    $transformButton = Find-AutomationElementByName `
                        -TargetProcessId $process.Id `
                        -Name "面 → 米" `
                        -RootWindowHandle $process.MainWindowHandle
                    Click-AutomationElementWithMouse -Element $transformButton
                    $includeTailButton = Find-AutomationElementByName `
                        -TargetProcessId $process.Id `
                        -Name "带面尾"
                    Click-AutomationElementWithMouse -Element $includeTailButton
                    Start-Sleep -Milliseconds 220
                }
                elseif ($ExerciseHoldTailResize) {
                    $primaryEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw | ConvertFrom-Json
                    $target = $primaryEvidence.timeline.selectedHoldTail.windowPointDip
                    $clientWidthDip = [double]$primaryEvidence.window.clientWidthDip
                    $clientHeightDip = [double]$primaryEvidence.window.clientHeightDip
                    if (-not $target -or $clientWidthDip -le 0 -or $clientHeightDip -le 0 -or
                        $primaryEvidence.timeline.snapDivision -le 0) {
                        throw "Primary GUI evidence did not expose a usable selected LN-tail target."
                    }
                    $scaleX = $exerciseWidth / $clientWidthDip
                    $scaleY = $exerciseHeight / $clientHeightDip
                    $startX = $exerciseRectangle.Left + [int][Math]::Round([double]$target.x * $scaleX)
                    $startY = $exerciseRectangle.Top + [int][Math]::Round([double]$target.y * $scaleY)
                    # Aim four DIPs just beyond the LN body while remaining well
                    # inside the tail handle's 18-DIP minimum hit tolerance. This
                    # avoids a one-pixel DPI/window rounding error being routed as
                    # a whole-LN body move when the tail sits on the judgement line.
                    $startY -= [int][Math]::Round(4 * $scaleY)
                    $dragDip = [Math]::Max(
                        50,
                        [double]$primaryEvidence.timeline.pixelsPerBeat /
                            [double]$primaryEvidence.timeline.snapDivision * 2)
                    $targetY = $startY - [int][Math]::Round($dragDip * $scaleY)
                    $targetY = [Math]::Max($exerciseRectangle.Top + 8, $targetY)

                    # A harmless physical click on the already-active Select tool
                    # gives Windows one foreground transition before the tail drag.
                    # If the activation click is consumed, the subsequent captured
                    # pointer gesture still reaches the intended TimelineSurface.
                    $selectTool = Find-AutomationElementById `
                        -TargetProcessId $process.Id `
                        -AutomationId "Timeline.Tool.Select" `
                        -RootWindowHandle $process.MainWindowHandle
                    Click-AutomationElementWithMouse -Element $selectTool
                    Start-Sleep -Milliseconds 120
                }
                else {
                    $startX = $exerciseRectangle.Left + [int]($exerciseWidth * .72)
                    $startY = $exerciseRectangle.Top + [int]($exerciseHeight * .55)
                    # Stay inside TimelineSurface so the move is delivered even on
                    # drivers that suppress captured non-client cursor transitions.
                    # The custom title, tab strip and toolbar occupy roughly 16% of
                    # the maximized window; 18% is inside the surface's 42-DIP band.
                    $targetY = $exerciseRectangle.Top + [int]($exerciseHeight * .18)
                }
                if ($ExerciseGroupPlacement) {
                    Start-Sleep -Milliseconds 300
                }
                elseif ($ExerciseHoldTailResize) {
                    Invoke-MouseDrag `
                        -StartX $startX -StartY $startY `
                        -EndX $startX -EndY $targetY `
                        -Steps 12
                    # Retained waveform/spectrogram scenes can keep the UI
                    # thread busy briefly after the final Win32 move. Hold the
                    # release position long enough for Avalonia to dispatch the
                    # captured PointerReleased event before restoring the user's
                    # cursor; otherwise the exact same valid tail target can be
                    # observed without committing on the smaller WPF-parity
                    # 1320x800 startup window.
                    Start-Sleep -Milliseconds 900
                }
                elseif (-not $ExerciseLongToTap -and -not $ExerciseNoteProperty -and
                        -not $ExerciseGroupAssign -and -not $ExerciseGroupVisibility -and
                        -not $ExerciseKeySoundRuntime -and -not $ExerciseDisplayScale -and
                        -not $ExerciseAudioPanels -and -not $libraryDeleteExerciseEnabled -and
                        -not $chartValidationExerciseEnabled -and
                        -not $chartExportModesExerciseEnabled -and
                        -not $fullPackageExportExerciseEnabled) {
                    if (-not [LumaChartAvaloniaCaptureNative]::SetCursorPos($startX, $startY)) {
                        throw "SetCursorPos failed before captured-pointer press."
                    }
                    Start-Sleep -Milliseconds 80
                    [LumaChartAvaloniaCaptureNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
                    $buttonDown = $true
                    Start-Sleep -Milliseconds 80
                    if (-not [LumaChartAvaloniaCaptureNative]::SetCursorPos($startX, $targetY)) {
                        throw "SetCursorPos failed during captured-pointer drag."
                    }
                    Start-Sleep -Milliseconds $(if ($ExerciseHoldTailResize) { 180 } else { 800 })
                }
            }
            finally {
                if ($buttonDown) {
                    [LumaChartAvaloniaCaptureNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
                }
                if ($haveSavedCursor) {
                    [LumaChartAvaloniaCaptureNative]::SetCursorPos($savedCursor.X, $savedCursor.Y) | Out-Null
                }
            }
            if (-not $interactionActionsCompletedAtUtc) {
                $interactionActionsCompletedAtUtc = [DateTimeOffset]::UtcNow
            }
            $interactionExercised = $true
            if ($ExerciseEdgeScroll) { $edgeScrollExercised = $true }
            if ($ExerciseHoldTailResize) { $holdTailResizeExercised = $true }
            if ($ExerciseLongToTap) { $longToTapExercised = $true }
            if ($ExerciseProEditorPan) { $proEditorPanExercised = $true }
            if ($ExerciseProEditorReveal) { $proEditorRevealExercised = $true }
            if ($ExerciseProEditorEdit) { $proEditorEditExercised = $true }
            if ($ExerciseProEditorSaveAsOsu) { $proEditorSaveAsOsuExercised = $true }
            if ($ExerciseKeySoundRuntime -and -not $keySoundRuntimeExercised) {
                throw "Key-sound runtime exercise did not complete Preview, Play and Stop."
            }
            if ($ExerciseDisplayScale -and -not $displayScaleExercised) {
                throw "Display-scale runtime exercise did not complete both requested RangeValue changes."
            }
            if ($ExerciseAudioPanels -and -not $audioPanelsExercised) {
                throw "Audio-panel runtime exercise did not complete its two pointer clicks and toolbar drag."
            }
            if ($chartExportModesExerciseEnabled -and -not $chartExportModesExercised) {
                throw "Chart-export mode runtime exercise did not complete all four modes and hidden-field validation."
            }
            if ($fullPackageExportExerciseEnabled -and -not $malodyFullPackageExportExercised) {
                throw "Malody FullPackage runtime exercise did not complete its dirty-note, options, native Save, and result path."
            }
            if ($libraryDeleteExerciseEnabled -and -not $libraryDeletionExercised) {
                throw "Library deletion exercise did not complete its right-click, menu and dialog path."
            }
        }
        $evidencePending = -not $LibraryHome -and
            ((-not (Test-Path -LiteralPath $evidenceFullPath)) -or
             ($interactionEvidenceFullPath -and
              -not (Test-Path -LiteralPath $interactionEvidenceFullPath)))
    }
    while (($evidencePending -or
             $process.MainWindowHandle -eq [IntPtr]::Zero) -and
           -not $process.HasExited -and
           [DateTime]::UtcNow -lt $deadline)

    if ($process.HasExited) {
        throw "Avalonia exited before GUI capture (exit code $($process.ExitCode))."
    }
    if ($ExerciseLibraryNoResults) {
        # Wait for a real indexed library result before applying a query that is
        # guaranteed not to match. This distinguishes search-zero from a truly
        # empty workspace instead of accepting the same placeholder visually.
        $initialList = Get-AutomationElementObservation `
            -TargetProcessId $process.Id `
            -AutomationId "Library.List" `
            -RootWindowHandle $process.MainWindowHandle `
            -TimeoutMilliseconds 10000
        $searchBefore = Get-AutomationElementObservation `
            -TargetProcessId $process.Id `
            -AutomationId "Library.Search" `
            -RootWindowHandle $process.MainWindowHandle `
            -TimeoutMilliseconds 6000

        Set-ForegroundWindowVerified -WindowHandle $process.MainWindowHandle
        Click-AutomationElementWithMouse -Element $searchBefore.Element
        Start-Sleep -Milliseconds 120
        $searchBefore.Element.SetFocus()
        Start-Sleep -Milliseconds 120
        [System.Windows.Forms.SendKeys]::SendWait("^a")
        [System.Windows.Forms.SendKeys]::SendWait($LibraryNoResultsQuery)
        Start-Sleep -Milliseconds 450

        $searchAfter = Get-AutomationElementObservation `
            -TargetProcessId $process.Id `
            -AutomationId "Library.Search" `
            -RootWindowHandle $process.MainWindowHandle `
            -TimeoutMilliseconds 6000
        $searchValueObject = $null
        if (-not $searchAfter.Element.TryGetCurrentPattern(
                [System.Windows.Automation.ValuePattern]::Pattern,
                [ref]$searchValueObject)) {
            throw "Library.Search did not expose ValuePattern after physical keyboard input."
        }
        $searchValue = ([System.Windows.Automation.ValuePattern]$searchValueObject).Current.Value
        $keyboardInputRetainedValue = $searchValue -eq $LibraryNoResultsQuery
        $librarySearchAutomationFallbackUsed = $false
        if (-not $keyboardInputRetainedValue) {
            Set-AutomationElementValue -Element $searchAfter.Element -Value $LibraryNoResultsQuery
            $librarySearchAutomationFallbackUsed = $true
            Start-Sleep -Milliseconds 450
            $searchAfter = Get-AutomationElementObservation `
                -TargetProcessId $process.Id `
                -AutomationId "Library.Search" `
                -RootWindowHandle $process.MainWindowHandle `
                -TimeoutMilliseconds 6000
            $searchValueObject = $null
            if (-not $searchAfter.Element.TryGetCurrentPattern(
                    [System.Windows.Automation.ValuePattern]::Pattern,
                    [ref]$searchValueObject)) {
                throw "Library.Search did not expose ValuePattern after deterministic UI Automation fallback."
            }
            $searchValue = ([System.Windows.Automation.ValuePattern]$searchValueObject).Current.Value
        }
        try {
            $emptyTitle = Get-AutomationElementObservationByName `
                -TargetProcessId $process.Id `
                -Name "没有符合筛选条件的项目" `
                -RootWindowHandle $process.MainWindowHandle `
                -TimeoutMilliseconds 6000
        }
        catch {
            $automationRoot = [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)
            $visibleNames = @($automationRoot.FindAll(
                    [System.Windows.Automation.TreeScope]::Descendants,
                    [System.Windows.Automation.Condition]::TrueCondition) | ForEach-Object {
                    try {
                        if (-not $_.Current.IsOffscreen -and -not [string]::IsNullOrWhiteSpace($_.Current.Name)) {
                            [string]$_.Current.Name
                        }
                    }
                    catch { }
                } | Sort-Object -Unique)
            throw "Library no-result title was unavailable after search value '$searchValue'. " +
                  "Visible UIA names: $($visibleNames -join ' | ')"
        }
        $emptySubtitle = Get-AutomationElementObservationByName `
            -TargetProcessId $process.Id `
            -Name "当前搜索没有匹配结果；请清空搜索或更换筛选条件。" `
            -RootWindowHandle $process.MainWindowHandle `
            -TimeoutMilliseconds 6000

        $launcherExists = $false
        $launcherVisible = $false
        try {
            $launcher = Find-AutomationElementById `
                -TargetProcessId $process.Id `
                -AutomationId "Library.CreateProject" `
                -RootWindowHandle $process.MainWindowHandle `
                -TimeoutMilliseconds 500
            $launcherExists = $true
            $launcherBounds = $launcher.Current.BoundingRectangle
            $launcherVisible = -not $launcher.Current.IsOffscreen -and
                -not $launcherBounds.IsEmpty -and $launcherBounds.Width -gt 1 -and $launcherBounds.Height -gt 1
        }
        catch { }

        $listExistsAfter = $false
        $listVisibleAfter = $false
        try {
            $listAfter = Find-AutomationElementById `
                -TargetProcessId $process.Id `
                -AutomationId "Library.List" `
                -RootWindowHandle $process.MainWindowHandle `
                -TimeoutMilliseconds 500
            $listExistsAfter = $true
            $listBoundsAfter = $listAfter.Current.BoundingRectangle
            $listVisibleAfter = -not $listAfter.Current.IsOffscreen -and
                -not $listBoundsAfter.IsEmpty -and $listBoundsAfter.Width -gt 1 -and $listBoundsAfter.Height -gt 1
        }
        catch { }

        $libraryNoResultsExercised =
            $searchValue -eq $LibraryNoResultsQuery -and
            [string]$emptyTitle.Evidence.name -eq "没有符合筛选条件的项目" -and
            [string]$emptySubtitle.Evidence.name -eq "当前搜索没有匹配结果；请清空搜索或更换筛选条件。" -and
            -not $launcherVisible -and -not $listVisibleAfter
        if (-not $libraryNoResultsExercised) {
            throw "Library search-zero GUI did not match WPF empty-result semantics."
        }

        $interactionActionsCompletedAtUtc = [DateTimeOffset]::UtcNow
        $libraryNoResultsEvidence = [ordered]@{
            schema = "lumachart.windows.avalonia.library-search-evidence.v1"
            generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed"
            query = $LibraryNoResultsQuery
            physicalPointerFocusAttempted = $true
            physicalKeyboardInput = $true
            keyboardInputRetainedValue = $keyboardInputRetainedValue
            automationFallbackUsed = $librarySearchAutomationFallbackUsed
            initialVisibleList = $initialList.Evidence
            searchBefore = $searchBefore.Evidence
            searchAfter = $searchAfter.Evidence
            searchValue = $searchValue
            emptyTitle = $emptyTitle.Evidence
            emptySubtitle = $emptySubtitle.Evidence
            launcherExistsInAutomationTree = $launcherExists
            launcherVisible = $launcherVisible
            listExistsInAutomationTreeAfterSearch = $listExistsAfter
            listVisibleAfterSearch = $listVisibleAfter
            passed = $libraryNoResultsExercised
        }
        [IO.File]::WriteAllText(
            $interactionEvidenceFullPath,
            ($libraryNoResultsEvidence | ConvertTo-Json -Depth 8),
            [Text.UTF8Encoding]::new($false))
        $interactionExercised = $true
    }
    if (-not $LibraryHome -and -not (Test-Path -LiteralPath $evidenceFullPath)) {
        throw "Timed out waiting for Avalonia GUI runtime evidence."
    }
    if ($interactionEvidenceFullPath -and
        -not (Test-Path -LiteralPath $interactionEvidenceFullPath)) {
        throw "Timed out waiting for Avalonia GUI interaction evidence."
    }
    if ($ExerciseHoldTailResize) {
        $primaryHoldEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw | ConvertFrom-Json
        $interactionHoldEvidence = Get-Content -LiteralPath $interactionEvidenceFullPath -Raw |
            ConvertFrom-Json
        $beforeTail = $primaryHoldEvidence.timeline.selectedHoldTail
        $afterTail = $interactionHoldEvidence.timeline.selectedHoldTail
        $holdTailResizeExercised =
            $null -ne $beforeTail -and $null -ne $afterTail -and
            $beforeTail.noteId -eq $afterTail.noteId -and
            [double]$beforeTail.endBeat.value -ne [double]$afterTail.endBeat.value -and
            [long]$interactionHoldEvidence.timeline.sessionChangeSerial -gt
                [long]$primaryHoldEvidence.timeline.sessionChangeSerial -and
            $interactionHoldEvidence.chart.structure.sha256 -ne
                $primaryHoldEvidence.chart.structure.sha256
        if (-not $holdTailResizeExercised) {
            throw "LN-tail interaction evidence did not prove one captured-pointer resize."
        }
    }
    if ($ExerciseNoteProperty) {
        $primaryPropertyEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw | ConvertFrom-Json
        $interactionPropertyEvidence = Get-Content -LiteralPath $interactionEvidenceFullPath -Raw | ConvertFrom-Json
        $notePropertyExercised =
            [long]$interactionPropertyEvidence.timeline.sessionChangeSerial -eq
                ([long]$primaryPropertyEvidence.timeline.sessionChangeSerial + 1) -and
            $interactionPropertyEvidence.chart.structure.sha256 -ne
                $primaryPropertyEvidence.chart.structure.sha256
        if (-not $notePropertyExercised) {
            throw "Note-property interaction evidence did not prove one structural mutation."
        }
        if ($SaveAfterNoteProperty) {
            $savedChartSha256 = (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
            $notePropertySaved =
                -not [bool]$interactionPropertyEvidence.timeline.sessionIsDirty -and
                $interactionPropertyEvidence.chart.sourceSha256 -eq $savedChartSha256
            if (-not $notePropertySaved) {
                throw "Note-property interaction evidence did not prove a clean saved file."
            }
        }
        elseif ($ExerciseSourceSaveFailure) {
            $workingPaths = @(
                $interactionPropertyEvidence.settings.openTabCachePaths |
                    ForEach-Object { [string]$_ })
            $sourceSaveFailureRetained =
                [bool]$sourceSaveFailureAction.verified -and
                [bool]$sourceSaveFailureAction.sourceUnchanged -and
                [bool]$interactionPropertyEvidence.timeline.sessionIsDirty -and
                $interactionPropertyEvidence.chart.sourceSha256 -eq
                    [string]$sourceSaveFailureAction.sourceBefore.sha256 -and
                $workingPaths.Count -eq 1 -and
                (Test-Path -LiteralPath $workingPaths[0] -PathType Container)
            if (-not $sourceSaveFailureRetained) {
                throw "Failed source Save did not retain one exact dirty software-side cache."
            }
            $sourceSaveFailureAction["interaction"] = [ordered]@{
                sessionIsDirty =
                    [bool]$interactionPropertyEvidence.timeline.sessionIsDirty
                sessionChangeSerial =
                    [long]$interactionPropertyEvidence.timeline.sessionChangeSerial
                dirtyStructureSha256 =
                    [string]$interactionPropertyEvidence.chart.structure.sha256
                sourceSha256 =
                    [string]$interactionPropertyEvidence.chart.sourceSha256
                workingCachePaths = $workingPaths
                retained = $sourceSaveFailureRetained
            }
        }
    }
    if ($groupExerciseEnabled) {
        $primaryGroupEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw | ConvertFrom-Json
        $interactionGroupEvidence = Get-Content -LiteralPath $interactionEvidenceFullPath -Raw | ConvertFrom-Json
        $focusedGroupNotes = @($primaryGroupEvidence.timeline.selectedNotes)
        if ($focusedGroupNotes.Count -eq 1) {
            $focusedGroupBeat = $focusedGroupNotes[0].beat
            $groupFocusBeat = "{0}:{1}/{2}" -f `
                [int]$focusedGroupBeat.bar, `
                [int]$focusedGroupBeat.numerator, `
                [int]$focusedGroupBeat.denominator
        }
        if ($ExerciseGroupAssign) {
            $beforeNotes = @($primaryGroupEvidence.timeline.selectedNotes)
            $afterNotes = @($interactionGroupEvidence.timeline.selectedNotes)
            $groupAssignExercised =
                $beforeNotes.Count -eq 1 -and $afterNotes.Count -eq 1 -and
                $afterNotes[0].noteId -eq $beforeNotes[0].noteId -and
                [int]$afterNotes[0].group -eq $groupIdValue -and
                [long]$interactionGroupEvidence.timeline.sessionChangeSerial -eq
                    ([long]$primaryGroupEvidence.timeline.sessionChangeSerial + 1)
            if (-not $groupAssignExercised) {
                throw "Group assignment evidence did not prove one selected Note mutation."
            }
            if ($SaveAfterGroupAssign) {
                $savedChartSha256 = (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
                $groupAssignSaved =
                    -not [bool]$interactionGroupEvidence.timeline.sessionIsDirty -and
                    $interactionGroupEvidence.chart.sourceSha256 -eq $savedChartSha256
                if (-not $groupAssignSaved) {
                    throw "Group assignment evidence did not prove a clean saved file."
                }
            }
        }
        elseif ($ExerciseGroupVisibility) {
            $groupVisibilityExercised =
                @($primaryGroupEvidence.timeline.selectedNotes).Count -eq 1 -and
                [int]$primaryGroupEvidence.timeline.selectedNotes[0].group -eq $groupIdValue -and
                [int]$interactionGroupEvidence.timeline.selectedNoteCount -eq 0 -and
                @($interactionGroupEvidence.timeline.hiddenGroups) -contains $groupIdValue -and
                [long]$interactionGroupEvidence.timeline.sessionChangeSerial -eq
                    [long]$primaryGroupEvidence.timeline.sessionChangeSerial -and
                $interactionGroupEvidence.chart.structure.sha256 -eq
                    $primaryGroupEvidence.chart.structure.sha256
            if (-not $groupVisibilityExercised) {
                throw "Group visibility evidence did not prove a view-only hide and selection clear."
            }
        }
        elseif ($ExerciseGroupPlacement) {
            $beforeProbe = $primaryGroupEvidence.timeline.placementProbe
            $afterProbe = $interactionGroupEvidence.timeline.placementProbe
            $tapObservation = $afterProbe.tapObservation
            $holdObservation = $afterProbe.holdObservation
            $placedNotes = @($interactionGroupEvidence.timeline.selectedNotes)
            $beforeGroupRows = @($primaryGroupEvidence.timeline.groupManager.rows |
                Where-Object { [int]$_.group -eq $groupIdValue })
            $afterGroupRows = @($interactionGroupEvidence.timeline.groupManager.rows |
                Where-Object { [int]$_.group -eq $groupIdValue })
            $groupPlacementExercised =
                $null -ne $beforeProbe -and $null -ne $afterProbe -and
                $null -eq $beforeProbe.tapObservation -and
                $null -eq $beforeProbe.holdObservation -and
                (Test-PlacementTargetEvidenceEqual `
                    -Left $beforeProbe.tapTarget -Right $afterProbe.tapTarget) -and
                (Test-PlacementTargetEvidenceEqual `
                    -Left $beforeProbe.holdStartTarget -Right $afterProbe.holdStartTarget) -and
                (Test-PlacementTargetEvidenceEqual `
                    -Left $beforeProbe.holdEndTarget -Right $afterProbe.holdEndTarget) -and
                $null -ne $tapObservation -and $null -ne $holdObservation -and
                $tapObservation.noteId -ne $holdObservation.noteId -and
                $null -eq $tapObservation.endBeat -and
                [int]$tapObservation.group -eq $groupIdValue -and
                [int]$tapObservation.lane -eq [int]$afterProbe.tapTarget.lane -and
                (Test-BeatEvidenceEqual `
                    -Left $tapObservation.beat -Right $afterProbe.tapTarget.beat) -and
                $null -ne $holdObservation.endBeat -and
                [int]$holdObservation.group -eq $groupIdValue -and
                [int]$holdObservation.lane -eq [int]$afterProbe.holdStartTarget.lane -and
                (Test-BeatEvidenceEqual `
                    -Left $holdObservation.beat -Right $afterProbe.holdStartTarget.beat) -and
                (Test-BeatEvidenceEqual `
                    -Left $holdObservation.endBeat -Right $afterProbe.holdEndTarget.beat) -and
                $placedNotes.Count -eq 1 -and
                $placedNotes[0].noteId -eq $holdObservation.noteId -and
                [int]$placedNotes[0].group -eq $groupIdValue -and
                [int]$interactionGroupEvidence.timeline.activePlacementGroup -eq $groupIdValue -and
                [int]$interactionGroupEvidence.timeline.groupManager.activePlacementGroup -eq
                    $groupIdValue -and
                [string]$interactionGroupEvidence.timeline.currentTool -eq "Hold" -and
                @($interactionGroupEvidence.timeline.hiddenGroups) -notcontains $groupIdValue -and
                [long]$interactionGroupEvidence.timeline.sessionChangeSerial -eq
                    ([long]$primaryGroupEvidence.timeline.sessionChangeSerial + 2) -and
                [bool]$interactionGroupEvidence.timeline.sessionIsDirty -and
                $interactionGroupEvidence.chart.sourceSha256 -eq
                    $primaryGroupEvidence.chart.sourceSha256 -and
                $interactionGroupEvidence.chart.structure.sha256 -ne
                    $primaryGroupEvidence.chart.structure.sha256 -and
                [int]$interactionGroupEvidence.chart.structure.noteCount -eq
                    ([int]$primaryGroupEvidence.chart.structure.noteCount + 2) -and
                [int]$interactionGroupEvidence.chart.structure.longNoteCount -eq
                    ([int]$primaryGroupEvidence.chart.structure.longNoteCount + 1) -and
                [int]$interactionGroupEvidence.chart.structure.keyCount -eq
                    [int]$primaryGroupEvidence.chart.structure.keyCount -and
                [int]$interactionGroupEvidence.chart.structure.timingCount -eq
                    [int]$primaryGroupEvidence.chart.structure.timingCount -and
                [int]$interactionGroupEvidence.timeline.visibleDocumentNoteCount -eq
                    ([int]$primaryGroupEvidence.timeline.visibleDocumentNoteCount + 2) -and
                $beforeGroupRows.Count -eq 1 -and $afterGroupRows.Count -eq 1 -and
                [int]$afterGroupRows[0].noteCount -eq
                    ([int]$beforeGroupRows[0].noteCount + 2) -and
                [bool]$afterGroupRows[0].isVisible -and [bool]$afterGroupRows[0].isCurrent
            if (-not $groupPlacementExercised) {
                throw "Group placement evidence did not prove exact grouped Tap/Hold placement after hide/set-current."
            }
        }
    }
    if ($proEditorExerciseEnabled) {
        $primaryProEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw | ConvertFrom-Json
        $interactionProEvidence = Get-Content -LiteralPath $interactionEvidenceFullPath -Raw |
            ConvertFrom-Json
        $beforePro = $primaryProEvidence.timeline.proEditor
        $afterPro = $interactionProEvidence.timeline.proEditor
        $beforeGeometry = $beforePro.geometry
        $afterGeometry = $afterPro.geometry
        if ([bool]$beforePro.enabled -or -not [bool]$afterPro.enabled -or
            [long]$primaryProEvidence.timeline.sessionChangeSerial -ne 0 -or
            [bool]$primaryProEvidence.timeline.sessionIsDirty -or
            [int]$beforePro.visibleDraftNoteCount -ne 0 -or
            [int]$beforePro.configuredColumnRange.minimum -ne -4 -or
            [int]$beforePro.configuredColumnRange.maximum -ne 7 -or
            [int]$beforePro.visibleColumnRange.minimum -ne 0 -or
            [int]$beforePro.visibleColumnRange.maximum -ne 3 -or
            [int]$afterPro.visibleDraftNoteCount -ne [int]$afterPro.draftDocumentNoteCount -or
            [int]$afterPro.visibleOfficialNoteCount -ne [int]$afterPro.officialDocumentNoteCount -or
            [double]$beforeGeometry.laneWidthDip -le 0 -or
            [Math]::Abs(
                ([double]$beforeGeometry.officialTrackRightSurfaceDip -
                 [double]$beforeGeometry.officialTrackLeftSurfaceDip) -
                [double]$beforeGeometry.laneWidthDip * 4) -gt .01 -or
            [double]$beforeGeometry.officialTrackRightWindowDip -le
                [double]$beforeGeometry.officialTrackLeftWindowDip) {
            throw "Primary/interaction ProEditor evidence did not prove the expected 4K hidden/revealed view state."
        }
        if ($ExerciseProEditorReveal) {
            $proEditorRevealExercised =
                [long]$interactionProEvidence.timeline.sessionChangeSerial -eq 0 -and
                -not [bool]$interactionProEvidence.timeline.sessionIsDirty -and
                $interactionProEvidence.chart.structure.sha256 -eq
                    $primaryProEvidence.chart.structure.sha256
            if (-not $proEditorRevealExercised) {
                throw "ProEditor reveal evidence changed document state."
            }
        }
        elseif ($ExerciseProEditorPan) {
            $draftNotesInsideViewport = @($afterPro.documentNotes | Where-Object {
                if (-not [bool]$_.isDraft) { return $false }
                $center = [double]$afterGeometry.officialTrackLeftWindowDip +
                    (([double]$_.workspaceColumn + .5) * [double]$afterGeometry.laneWidthDip)
                return $center -gt [double]$afterGeometry.timelineViewportLeftWindowDip -and
                    $center -lt [double]$afterGeometry.timelineViewportRightWindowDip
            }).Count
            $proEditorPanExercised =
                [long]$interactionProEvidence.timeline.sessionChangeSerial -eq 0 -and
                -not [bool]$interactionProEvidence.timeline.sessionIsDirty -and
                $interactionProEvidence.chart.structure.sha256 -eq
                    $primaryProEvidence.chart.structure.sha256 -and
                [int]$afterPro.visibleDraftNoteCount -eq 3 -and
                [bool]$afterPro.horizontalPan.enabled -and
                [double]$afterPro.horizontalPan.value -lt -1 -and
                $null -ne $afterGeometry.timelineViewportLeftWindowDip -and
                $null -ne $afterGeometry.timelineViewportRightWindowDip -and
                [double]$afterGeometry.officialTrackLeftSurfaceDip -lt
                    [double]$beforeGeometry.officialTrackLeftSurfaceDip -and
                $draftNotesInsideViewport -eq 3
            if (-not $proEditorPanExercised) {
                throw "ProEditor pan evidence did not prove a real view-only horizontal slider drag."
            }
        }
        elseif ($ExerciseProEditorEdit) {
            $beforeProbe = $beforePro.probe
            $afterProbe = $afterPro.probe
            $moved = $afterProbe.movedOfficialObservation
            $hold = $afterProbe.draftHoldObservation
            $selected = @($interactionProEvidence.timeline.selectedNotes)
            $proEditorEditExercised =
                [int]$beforePro.officialDocumentNoteCount -eq 2 -and
                [int]$beforePro.draftDocumentNoteCount -eq 3 -and
                $null -ne $beforeProbe -and $null -ne $afterProbe -and
                (Test-ProEditorTargetEvidenceEqual `
                    -Left $beforeProbe.draftTapTarget -Right $afterProbe.draftTapTarget) -and
                (Test-ProEditorTargetEvidenceEqual `
                    -Left $beforeProbe.officialMoveTarget -Right $afterProbe.officialMoveTarget) -and
                (Test-ProEditorTargetEvidenceEqual `
                    -Left $beforeProbe.draftHoldStartTarget -Right $afterProbe.draftHoldStartTarget) -and
                (Test-ProEditorTargetEvidenceEqual `
                    -Left $beforeProbe.draftHoldEndTarget -Right $afterProbe.draftHoldEndTarget) -and
                $null -ne $moved -and -not [bool]$moved.isDraft -and
                [int]$moved.workspaceColumn -eq 3 -and $null -eq $moved.endBeat -and
                $null -ne $hold -and [bool]$hold.isDraft -and
                [int]$hold.workspaceColumn -eq 4 -and $null -ne $hold.endBeat -and
                $selected.Count -eq 1 -and $selected[0].noteId -eq $hold.noteId -and
                [long]$interactionProEvidence.timeline.sessionChangeSerial -eq 3 -and
                [int]$afterPro.officialDocumentNoteCount -eq 3 -and
                [int]$afterPro.draftDocumentNoteCount -eq 4 -and
                [int]$interactionProEvidence.chart.structure.noteCount -eq 7 -and
                [int]$interactionProEvidence.chart.structure.longNoteCount -eq 1 -and
                $interactionProEvidence.chart.structure.sha256 -eq
                    "6995CDE6268B0BF071718286363C45112E50829D9C063AC12A82D01EED50E68B"
            if (-not $proEditorEditExercised) {
                throw "ProEditor edit evidence did not prove Tap, boundary move and draft Hold via real mouse input."
            }
            if ($SaveAfterProEditorEdit) {
                $savedChartSha256 = (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
                $proEditorEditSaved =
                    -not [bool]$interactionProEvidence.timeline.sessionIsDirty -and
                    $savedChartSha256 -eq
                        "6995CDE6268B0BF071718286363C45112E50829D9C063AC12A82D01EED50E68B" -and
                    [long](Get-Item -LiteralPath $chartFullPath).Length -eq 591
                if (-not $proEditorEditSaved) {
                    throw "ProEditor edit Save did not produce the trusted compact 591-byte MC file."
                }
            }
        }
        elseif ($ExerciseProEditorSaveAsOsu) {
            $savedOsuText = Get-Content -LiteralPath $proEditorSaveAsOsuFullPath -Raw
            $hitObjectSection = ($savedOsuText -split '\[HitObjects\]', 2)
            $hitObjectLines = if ($hitObjectSection.Count -eq 2) {
                @($hitObjectSection[1] -split "`r?`n" | Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_) -and -not $_.TrimStart().StartsWith("//")
                })
            } else { @() }
            $savedOsuSha256 = (Get-FileHash -LiteralPath $proEditorSaveAsOsuFullPath -Algorithm SHA256).Hash
            $proEditorSaveAsOsuExercised =
                $proEditorSaveAsInitialDirectoryVerified -and
                $proEditorSaveAsVisibleSourceName -eq [IO.Path]::GetFileName($chartFullPath) -and
                [long]$interactionProEvidence.timeline.sessionChangeSerial -eq 0 -and
                -not [bool]$interactionProEvidence.timeline.sessionIsDirty -and
                (Test-Path -LiteralPath $proEditorSaveAsOsuFullPath -PathType Leaf) -and
                $savedOsuText.Contains("[HitObjects]") -and
                $hitObjectLines.Count -eq 3 -and
                [IO.Path]::GetFullPath([string]$interactionProEvidence.chart.sourcePath) -eq
                    $proEditorSaveAsOsuFullPath -and
                [string]$interactionProEvidence.chart.sourceSha256 -eq $savedOsuSha256
            if (-not $proEditorSaveAsOsuExercised) {
                throw "ProEditor native Save As did not produce a clean osu document."
            }
        }
    }
    if ($interactionEvidenceFullPath -and $interactionActionsCompletedAtUtc) {
        $interactionEvidence = Get-Content -LiteralPath $interactionEvidenceFullPath -Raw | ConvertFrom-Json
        $interactionGeneratedValue = $interactionEvidence.generatedAtUtc
        $interactionCapturedAtUtc = if ($interactionGeneratedValue -is [DateTime]) {
            [DateTimeOffset]$interactionGeneratedValue
        } else {
            [DateTimeOffset]::Parse(
                [string]$interactionGeneratedValue,
                [Globalization.CultureInfo]::InvariantCulture)
        }
        $interactionCapturedAfterActions = $interactionCapturedAtUtc -ge $interactionActionsCompletedAtUtc
        if (-not $interactionCapturedAfterActions) {
            throw "GUI interaction evidence was captured before the real UI actions completed."
        }
        if ($ExerciseAudioPanels) {
            $audioPanelInteractionRuntimeEvidence = $interactionEvidence.audio.panels
            $runtimeWaveformPanel = $audioPanelInteractionRuntimeEvidence.waveform
            $runtimeSpectrogramPanel = $audioPanelInteractionRuntimeEvidence.spectrogram
            $runtimeAudioPanelSettingsPath =
                [IO.Path]::GetFullPath([string]$audioPanelInteractionRuntimeEvidence.settingsPath)
            $audioPanelRuntimeVerified =
                $null -ne $audioPanelInteractionRuntimeEvidence -and
                $runtimeAudioPanelSettingsPath.Equals(
                    [IO.Path]::GetFullPath($audioPanelSettingsPath),
                    [StringComparison]::OrdinalIgnoreCase) -and
                [bool]$audioPanelInteractionRuntimeEvidence.settingsFileExists -and
                [bool]$audioPanelInteractionRuntimeEvidence.settingsIsolatedFromWpf -and
                [int]$audioPanelInteractionRuntimeEvidence.sideCustomSurfaceCount -eq 2 -and
                [int]$audioPanelInteractionRuntimeEvidence.perSampleAvaloniaControlCount -eq 0 -and
                [bool]$audioPanelInteractionRuntimeEvidence.visibleAreaClipping -and
                [string]$runtimeWaveformPanel.mode -eq "Background" -and
                -not [bool]$runtimeWaveformPanel.collapsed -and
                -not [bool]$runtimeWaveformPanel.docked -and
                -not [bool]$runtimeWaveformPanel.surfaceVisible -and
                [bool]$runtimeWaveformPanel.backgroundEnabled -and
                [bool]$runtimeWaveformPanel.surfaceClipToBounds -and
                $null -ne $runtimeWaveformPanel.diagnostics -and
                [string]$runtimeSpectrogramPanel.mode -eq "Side" -and
                -not [bool]$runtimeSpectrogramPanel.collapsed -and
                [bool]$runtimeSpectrogramPanel.surfaceVisible -and
                -not [bool]$runtimeSpectrogramPanel.backgroundEnabled -and
                [bool]$runtimeSpectrogramPanel.surfaceClipToBounds -and
                $null -ne $runtimeSpectrogramPanel.diagnostics
            if (-not $audioPanelRuntimeVerified) {
                throw "Interaction runtime evidence did not prove isolated settings, two clipped custom surfaces, zero per-sample Controls, Background Waveform, and expanded Side Spectrogram."
            }
        }
        if ($fullPackageExportExerciseEnabled) {
            $malodyFullPackageInteractionRuntime = $interactionEvidence
            $primaryExportEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw |
                ConvertFrom-Json
            $beforeSelected = @($primaryExportEvidence.timeline.selectedNotes)
            $afterSelected = @($interactionEvidence.timeline.selectedNotes)
            $submittedBeat = $malodyFullPackageDirtyInjection.submittedBeat
            $archiveRuntimeVerified = if ($targetOsuFullPackage) {
                [int]$malodyFullPackageArchiveEvidence.entryCount -eq
                    $selectedFullPackageExpectedEntryCount -and
                [int]$malodyFullPackageArchiveEvidence.chartEntryCount -eq
                    $selectedFullPackageExpectedChartCount -and
                [int]$malodyFullPackageArchiveEvidence.malodyChartEntryCount -eq 0 -and
                [int]$malodyFullPackageArchiveEvidence.siblingChartEntryCount -eq
                    ($selectedFullPackageExpectedChartCount - 1) -and
                [bool]$malodyFullPackageArchiveEvidence.mainChartFormatVerified -and
                [bool]$malodyFullPackageArchiveEvidence.siblingChartsExact -and
                [bool]$malodyFullPackageArchiveEvidence.allExcludedSourceArtifactsAbsent -and
                [bool]$malodyFullPackageArchiveEvidence.allEntriesFlat -and
                [int]$malodyFullPackageArchiveEvidence.unsafeEntryCount -eq 0 -and
                [int]$malodyFullPackageArchiveEvidence.caseInsensitiveDuplicateCount -eq 0 -and
                [int]$malodyFullPackageArchiveEvidence.mainChartExpectedHitObjectMatchCount -eq 1 -and
                [int]$malodyFullPackageArchiveEvidence.mainChartOriginalHitObjectMatchCount -eq 0
            } elseif ($osuToMalodyFullPackage) {
                [int]$malodyFullPackageArchiveEvidence.entryCount -eq
                    $selectedFullPackageExpectedEntryCount -and
                [int]$malodyFullPackageArchiveEvidence.chartEntryCount -eq 1 -and
                [bool]$malodyFullPackageArchiveEvidence.allChartsValidJson -and
                [bool]$malodyFullPackageArchiveEvidence.allChartsCompact -and
                [int]$malodyFullPackageArchiveEvidence.mainChartEntryCount -eq 1 -and
                [bool]$malodyFullPackageArchiveEvidence.mainChartDynamicNameVerified -and
                [int]$malodyFullPackageArchiveEvidence.exactTargetTapCount -eq 1 -and
                [int]$malodyFullPackageArchiveEvidence.originalTargetTapCount -eq 0 -and
                [int]$malodyFullPackageArchiveEvidence.serializedTimingCount -eq 2 -and
                [int]$malodyFullPackageArchiveEvidence.serializedEffectCount -eq 11 -and
                [int]$malodyFullPackageArchiveEvidence.serializedTimingAndEffectCount -eq
                    [int]$interactionEvidence.chart.structure.timingCount -and
                [bool]$malodyFullPackageArchiveEvidence.allSourceArtifactsExcluded -and
                [bool]$malodyFullPackageArchiveEvidence.resourceChainsVerified -and
                [bool]$malodyFullPackageArchiveEvidence.allReferencedResourcesResolved -and
                [bool]$malodyFullPackageArchiveEvidence.keySoundNodeVerified -and
                [bool]$malodyFullPackageArchiveEvidence.allEntriesFlat -and
                [int]$malodyFullPackageArchiveEvidence.unsafeEntryCount -eq 0 -and
                [int]$malodyFullPackageArchiveEvidence.caseInsensitiveDuplicateCount -eq 0 -and
                [int]$malodyFullPackageArchiveEvidence.unexpectedChartArtifactCount -eq 0
            } else {
                [int]$malodyFullPackageArchiveEvidence.chartEntryCount -eq
                    $selectedFullPackageExpectedChartCount -and
                [bool]$malodyFullPackageArchiveEvidence.allChartsValidJson -and
                [bool]$malodyFullPackageArchiveEvidence.allChartsCompact -and
                [int]$malodyFullPackageArchiveEvidence.mainChartEntryCount -eq 1 -and
                [int]$malodyFullPackageArchiveEvidence.mainChartExactBeatMatchCount -eq 1 -and
                [int]$malodyFullPackageArchiveEvidence.mainChartOriginalBeatMatchCount -eq 0 -and
                [int]$malodyFullPackageArchiveEvidence.collisionEntryCount -ge 1 -and
                [int]$malodyFullPackageArchiveEvidence.unsafeEntryCount -eq 0
            }
            $runtimeExportVerified =
                [string]$primaryExportEvidence.schema -eq "lumachart.windows.avalonia.gui-evidence.v14" -and
                [string]$interactionEvidence.schema -eq "lumachart.windows.avalonia.gui-evidence.v14" -and
                [bool]$primaryExportEvidence.evidenceExportRevealSuppressed -and
                [bool]$interactionEvidence.evidenceExportRevealSuppressed -and
                [bool]$primaryExportEvidence.evidenceFilePickerStartDirectoryInjected -and
                [bool]$interactionEvidence.evidenceFilePickerStartDirectoryInjected -and
                [IO.Path]::GetFullPath(
                    [string]$primaryExportEvidence.evidenceFilePickerStartDirectory).Equals(
                        $expectedExportPickerStartDirectory,
                        [StringComparison]::OrdinalIgnoreCase) -and
                [IO.Path]::GetFullPath(
                    [string]$interactionEvidence.evidenceFilePickerStartDirectory).Equals(
                        $expectedExportPickerStartDirectory,
                        [StringComparison]::OrdinalIgnoreCase) -and
                $beforeSelected.Count -eq 1 -and $afterSelected.Count -eq 1 -and
                [string]$beforeSelected[0].noteId -eq [string]$afterSelected[0].noteId -and
                [int]$afterSelected[0].beat.bar -eq [int]$submittedBeat.bar -and
                [int]$afterSelected[0].beat.numerator -eq [int]$submittedBeat.numerator -and
                [int]$afterSelected[0].beat.denominator -eq [int]$submittedBeat.denominator -and
                [int]$afterSelected[0].lane -eq
                    $(if ($targetOsuFullPackage -or $osuToMalodyFullPackage) {
                            $selectedFullPackageExpectedExportedLane
                        } else { [int]$beforeSelected[0].lane }) -and
                [bool]$submittedBeat.numeratorNonZero -and
                [int]$submittedBeat.greatestCommonDivisor -gt 1 -and
                [bool]$submittedBeat.deliberatelyNonReduced -and
                [bool]$submittedBeat.exactExpansionVerified -and
                [bool]$submittedBeat.expectedExpressionVerified -and
                [long]$interactionEvidence.timeline.sessionChangeSerial -eq
                    ([long]$primaryExportEvidence.timeline.sessionChangeSerial + 1) -and
                [bool]$interactionEvidence.timeline.sessionIsDirty -and
                [IO.Path]::GetFullPath([string]$interactionEvidence.chart.sourcePath).Equals(
                    [IO.Path]::GetFullPath([string]$primaryExportEvidence.chart.sourcePath),
                    [StringComparison]::OrdinalIgnoreCase) -and
                [string]$interactionEvidence.chart.sourceSha256 -eq
                    [string]$primaryExportEvidence.chart.sourceSha256 -and
                [string]$interactionEvidence.chart.structure.sha256 -ne
                    [string]$primaryExportEvidence.chart.structure.sha256 -and
                [int]$interactionEvidence.chart.structure.keyCount -eq
                    [int]$primaryExportEvidence.chart.structure.keyCount -and
                [int]$interactionEvidence.chart.structure.noteCount -eq
                    [int]$primaryExportEvidence.chart.structure.noteCount -and
                [int]$interactionEvidence.chart.structure.longNoteCount -eq
                    [int]$primaryExportEvidence.chart.structure.longNoteCount -and
                [int]$interactionEvidence.chart.structure.timingCount -eq
                    [int]$primaryExportEvidence.chart.structure.timingCount -and
                [bool]$malodyFullPackageOptionsEvidence.defaultsVerified -and
                [bool]$malodyFullPackageResultEvidence.destinationMentioned -and
                [bool]$malodyFullPackageResultEvidence.successTone -and
                [bool]$malodyFullPackageWorkingTreeUnchangedByExport -and
                [bool]$malodyFullPackageSourceTreeUnchanged -and
                [bool]$malodyFullPackageScratchExportsAfter.clean -and
                $archiveRuntimeVerified
            if (-not $runtimeExportVerified) {
                throw "FullPackage interaction evidence did not preserve the dirty Note, source path/hash, change serial, source/working trees, scratch cleanup, and selected archive-format invariants."
            }
            $malodyFullPackageExportExercised = $true
        }
        if ($libraryDeleteExerciseEnabled) {
            $libraryDeletionInteractionRuntimeEvidence = $interactionEvidence.library
            $runtimeDeletion = $libraryDeletionInteractionRuntimeEvidence.lastDeletion
            $runtimePopupScale = $libraryDeletionInteractionRuntimeEvidence.contextMenuScale
            $runtimeDialogScale = $runtimeDeletion.dialogScale
            $runtimeTargetPaths = @($runtimeDeletion.targetFullPaths | ForEach-Object {
                [IO.Path]::GetFullPath([string]$_)
            })
            $expectedRuntimeTargetPaths = if ($ExerciseLibraryBatchDeleteConfirm) {
                @($libraryDeleteTargetFullPath, $libraryDeleteSecondTargetFullPath)
            } else { @($libraryDeleteTargetFullPath) }
            $runtimeTargetPathsMatch = $runtimeTargetPaths.Count -eq $expectedRuntimeTargetPaths.Count
            foreach ($expectedRuntimeTargetPath in $expectedRuntimeTargetPaths) {
                if (-not ($runtimeTargetPaths | Where-Object {
                        $_.Equals(
                            $expectedRuntimeTargetPath,
                            [StringComparison]::OrdinalIgnoreCase)
                    })) {
                    $runtimeTargetPathsMatch = $false
                }
            }
            $expectedMenuText = if ($ExerciseLibraryBatchDeleteConfirm) {
                "删除所选 2 个歌曲文件夹"
            } else { "删除此歌曲文件夹" }
            $expectedRuntimeFolderCount = if ($ExerciseLibraryBatchDeleteConfirm) { 2 } else { 1 }
            $runtimePlanVerified = if ($ExerciseLibraryOpenDocumentBlock) {
                -not [bool]$runtimeDeletion.canExecute -and
                [string]$runtimeDeletion.blockReason -eq "OpenDocument" -and
                [int]$runtimeDeletion.folderCount -eq 1 -and
                $runtimeTargetPathsMatch -and
                [string]$runtimeDeletion.blockMessage -ceq
                    [string]$libraryDeletionAction.dialogMessage.name -and
                @($runtimeDeletion.blockingDocumentTitles).Count -eq 1 -and
                $null -eq $runtimeDeletion.confirmationMessage
            } else {
                [bool]$runtimeDeletion.canExecute -and
                [string]$runtimeDeletion.blockReason -eq "None" -and
                [int]$runtimeDeletion.folderCount -eq $expectedRuntimeFolderCount -and
                $runtimeTargetPathsMatch -and
                [string]$runtimeDeletion.confirmationMessage -ceq
                    [string]$libraryDeletionAction.dialogMessage.name
            }
            $runtimeActionVerified =
                -not [bool]$libraryDeletionAction.selectionPatternOnly -and
                [bool]$libraryDeletionAction.selectionItemPatternReadOnly -and
                [bool]$libraryDeletionAction.parentSelectionPatternBridgeMismatchObserved -and
                -not [bool]$libraryDeletionAction.selectionAutomationFallbackUsed -and
                [string]$libraryDeletionAction.targetCard.automationId -eq "Library.FolderItem" -and
                [string]$libraryDeletionAction.targetCard.controlType -eq "ControlType.ListItem" -and
                [string]$libraryDeletionAction.contextMenuItem.name -ceq $expectedMenuText -and
                [string]$libraryDeletionAction.dialogMessage.name -ne "" -and
                [bool]$libraryDeletionAction.clipboardExactMessage -eq
                    [bool]$ExerciseLibraryOpenDocumentBlock
            if ($ExerciseLibraryBatchDeleteConfirm) {
                $selectionSteps = @($libraryDeletionAction.selectionSteps)
                $runtimeActionVerified = $runtimeActionVerified -and
                    [string]$libraryDeletionAction.secondTargetCard.automationId -eq
                        "Library.FolderItem" -and
                    [string]$libraryDeletionAction.secondTargetCard.controlType -eq
                        "ControlType.ListItem" -and
                    $selectionSteps.Count -eq 4 -and
                    [int]$selectionSteps[0].selection.selectedCount -eq 1 -and
                    [int]$selectionSteps[1].selection.selectedCount -eq 2 -and
                    [int]$selectionSteps[2].selection.selectedCount -eq 1 -and
                    [int]$selectionSteps[3].selection.selectedCount -eq 2 -and
                    -not [bool]$selectionSteps[0].automationSelectionFallbackUsed -and
                    -not [bool]$selectionSteps[1].input.automationSelectionFallbackUsed -and
                    -not [bool]$selectionSteps[2].input.automationSelectionFallbackUsed -and
                    -not [bool]$selectionSteps[3].input.automationSelectionFallbackUsed -and
                    [bool]$selectionSteps[1].input.keyReleasedInFinally -and
                    [bool]$selectionSteps[2].input.keyReleasedInFinally -and
                    [bool]$selectionSteps[3].input.keyReleasedInFinally -and
                    [int]$libraryDeletionAction.selectionBeforeRightClick.selectedCount -eq 2 -and
                    [int]$libraryDeletionAction.selectionAfterRightClick.selectedCount -eq 2 -and
                    [bool]$libraryDeletionAction.rightClickPreservedSelection -and
                    [bool]$libraryDeletionAction.questionTone -and
                    [bool]$libraryDeletionAction.neutralCancelRecycleDecision -and
                    [string]$libraryDeletionAction.dialogIcon.name -ceq "?" -and
                    [string]$libraryDeletionAction.dialogIcon.helpText -ceq "问题" -and
                    [string]$libraryDeletionAction.dialogCancel.name -ceq "取消" -and
                    [string]$libraryDeletionAction.dialogRecycle.name -ceq "移入回收站" -and
                    [bool]$libraryDeletionAction.confirmAbsent
            }
            if ($ExerciseLibraryOpenDocumentBlock) {
                $runtimeActionVerified = $runtimeActionVerified -and
                    [int]$libraryDeletionAction.selectionAfterRightClick.selectedCount -eq 1 -and
                    [bool]$libraryDeletionAction.warningTone -and
                    [string]$libraryDeletionAction.dialog.name -ceq "无法删除" -and
                    [string]$libraryDeletionAction.dialogIcon.name -ceq "!" -and
                    [string]$libraryDeletionAction.dialogIcon.helpText -ceq "警告" -and
                    [string]$libraryDeletionAction.dialogConfirm.name -ceq "确定" -and
                    [bool]$libraryDeletionAction.cancelAbsent -and
                    [bool]$libraryDeletionAction.recycleAbsent -and
                    [string]$libraryDeletionAction.clipboardInput.chord -eq "Ctrl+C" -and
                    [string]$libraryDeletionAction.clipboardInput.input -eq "keybd_event" -and
                    [bool]$libraryDeletionAction.clipboardInput.controlReleasedInFinally -and
                    [bool]$libraryDeletionAction.clipboardInput.cReleasedInFinally -and
                    -not [bool]$libraryDeletionAction.clipboardInput.automationKeyboardFallbackUsed
            }
            $runtimeBaseVerified =
                $null -ne $libraryDeletionInteractionRuntimeEvidence -and
                [string]$interactionEvidence.schema -eq "lumachart.windows.avalonia.gui-evidence.v14" -and
                [string]$libraryDeletionInteractionRuntimeEvidence.selectionMode -eq "Multiple" -and
                $null -ne $runtimeDeletion -and
                $runtimePlanVerified -and
                $runtimeActionVerified -and
                $null -ne $runtimePopupScale -and
                [bool]$runtimePopupScale.popupRootFound -and
                [Math]::Abs([double]$runtimePopupScale.actualPopupRootScaleX -
                    [double]$runtimePopupScale.requestedUiScale) -le .000001 -and
                [Math]::Abs([double]$runtimePopupScale.actualPopupRootScaleY -
                    [double]$runtimePopupScale.requestedUiScale) -le .000001 -and
                [Math]::Abs([double]$runtimePopupScale.appliedFontSize -
                    12 * [double]$runtimePopupScale.requestedFontScale) -le .000001 -and
                $null -ne $runtimeDialogScale -and
                [bool]$runtimeDialogScale.usesLayoutTransform -and
                [Math]::Abs([double]$runtimeDialogScale.actualRootScaleX -
                    [double]$runtimeDialogScale.requestedUiScale) -le .000001 -and
                [Math]::Abs([double]$runtimeDialogScale.actualRootScaleY -
                    [double]$runtimeDialogScale.requestedUiScale) -le .000001 -and
                @($runtimeDeletion.failureMessages).Count -eq 0
            if (-not $runtimeBaseVerified) {
                throw "Library deletion interaction evidence did not prove the exact v14 plan, read-only selection peer actions, PopupRoot scale, buttons, and dialog scale."
            }

            if ($ExerciseLibraryBatchDeleteConfirm) {
                $runtimeRecycleResults = @($runtimeDeletion.recycleResults)
                $runtimeRecyclePaths = @($runtimeRecycleResults | ForEach-Object {
                    [IO.Path]::GetFullPath([string]$_.fullPath)
                })
                $runtimeRecyclePathsMatch = $runtimeRecyclePaths.Count -eq 2
                foreach ($expectedRuntimeTargetPath in $expectedRuntimeTargetPaths) {
                    if (-not ($runtimeRecyclePaths | Where-Object {
                            $_.Equals(
                                $expectedRuntimeTargetPath,
                                [StringComparison]::OrdinalIgnoreCase)
                        })) {
                        $runtimeRecyclePathsMatch = $false
                    }
                }
                $libraryDeleteOutcomeVerified =
                    [bool]$runtimeDeletion.confirmed -and
                    -not [bool]$runtimeDeletion.canceled -and
                    $runtimeRecycleResults.Count -eq 2 -and
                    $runtimeRecyclePathsMatch -and
                    @($runtimeRecycleResults | Where-Object {
                        [int]$_.shellResult -eq 0 -and
                        -not [bool]$_.anyOperationsAborted -and
                        [bool]$_.allowUndoRequested
                    }).Count -eq 2 -and
                    -not [bool]$libraryDeleteTargetExistsAfter -and
                    -not [bool]$libraryDeleteSecondTargetExistsAfter
            } elseif ($ExerciseLibraryOpenDocumentBlock) {
                $libraryDeleteOutcomeVerified =
                    -not [bool]$runtimeDeletion.confirmed -and
                    -not [bool]$runtimeDeletion.canceled -and
                    @($runtimeDeletion.recycleResults).Count -eq 0 -and
                    [bool]$libraryDeleteTargetExistsAfter -and
                    [IO.Path]::GetFullPath([string]$interactionEvidence.chart.sourcePath).StartsWith(
                        $libraryDeleteTargetFullPath.TrimEnd('\') + '\',
                        [StringComparison]::OrdinalIgnoreCase)
            } elseif ($ExerciseLibraryDeleteConfirm) {
                $runtimeRecycleResults = @($runtimeDeletion.recycleResults)
                $libraryDeleteOutcomeVerified =
                    [bool]$runtimeDeletion.confirmed -and
                    -not [bool]$runtimeDeletion.canceled -and
                    $runtimeRecycleResults.Count -eq 1 -and
                    [int]$runtimeRecycleResults[0].shellResult -eq 0 -and
                    -not [bool]$runtimeRecycleResults[0].anyOperationsAborted -and
                    [bool]$runtimeRecycleResults[0].allowUndoRequested -and
                    -not [bool]$libraryDeleteTargetExistsAfter
            } else {
                $libraryDeleteOutcomeVerified =
                    -not [bool]$runtimeDeletion.confirmed -and
                    [bool]$runtimeDeletion.canceled -and
                    @($runtimeDeletion.recycleResults).Count -eq 0 -and
                    [bool]$libraryDeleteTargetExistsAfter
            }
            if (-not $libraryDeleteOutcomeVerified) {
                throw "Library deletion interaction evidence did not prove the requested block/cancel/recycle outcome."
            }
        }
        if ($chartValidationExerciseEnabled) {
            $chartValidationInteractionRuntimeEvidence = $interactionEvidence.validation
            $primaryValidation = $primaryChartValidationEvidence.validation
            $runtimeValidation = $chartValidationInteractionRuntimeEvidence
            $primaryNavigation = $primaryValidation.navigation
            $runtimeNavigation = $runtimeValidation.navigation
            $primaryHiddenGroups = @($primaryChartValidationEvidence.timeline.hiddenGroups | ForEach-Object { [int]$_ })
            $runtimeHiddenGroups = @($interactionEvidence.timeline.hiddenGroups | ForEach-Object { [int]$_ })
            $expectedNoteIds = @($runtimeValidation.firstIssue.noteIds | ForEach-Object { [string]$_ } | Sort-Object)
            $selectedNoteIds = @($interactionEvidence.timeline.selectedNotes |
                ForEach-Object { [string]$_.noteId } | Sort-Object)
            $navigationNoteIds = @($runtimeNavigation.noteIds | ForEach-Object { [string]$_ } | Sort-Object)
            $beat = $runtimeValidation.firstIssue.beat
            $expectedManualMessage =
                "发现 2 项错误：重叠键 1，LN 交叉 1。`n`n" +
                "已定位最靠下的一项：$($runtimeValidation.firstIssue.message)" +
                "（$($beat.bar):$($beat.numerator)/$($beat.denominator)）。"
            $expectedSaveMessage =
                "保存已暂停：发现 2 项谱面错误。`n`n" +
                "重叠键：1`nLN 交叉：1`n`n" +
                "已定位并选中最靠下的一项，请修复后再次保存。"
            $expectedStatus =
                "谱面错误：$($runtimeValidation.firstIssue.message) · " +
                "$($beat.bar):$($beat.numerator)/$($beat.denominator)"
            $expectedBeatDisplay = [double]$beat.value
            $expectedBeatDisplayText = $expectedBeatDisplay.ToString(
                "F3",
                [Globalization.CultureInfo]::InvariantCulture)
            $manualScale = $runtimeValidation.manualDialogScale
            $saveScale = $runtimeValidation.saveDialogScale
            $manualMessageFromUi = ([string]$chartValidationAction.manualMessage.name) -replace "`r", ""
            $saveMessageFromUi = ([string]$chartValidationAction.saveBlockedMessage.name) -replace "`r", ""

            $chartValidationRuntimeVerified =
                $null -ne $primaryValidation -and
                $null -ne $runtimeValidation -and
                [string]$primaryChartValidationEvidence.schema -eq "lumachart.windows.avalonia.gui-evidence.v14" -and
                [string]$interactionEvidence.schema -eq "lumachart.windows.avalonia.gui-evidence.v14" -and
                [int]$primaryValidation.totalIssueCount -eq 2 -and
                [int]$primaryValidation.overlappingNoteCount -eq 1 -and
                [int]$primaryValidation.crossingLongNoteCount -eq 1 -and
                -not [bool]$primaryValidation.canSave -and
                [int]$runtimeValidation.totalIssueCount -eq 2 -and
                [int]$runtimeValidation.overlappingNoteCount -eq 1 -and
                [int]$runtimeValidation.crossingLongNoteCount -eq 1 -and
                -not [bool]$runtimeValidation.canSave -and
                @($runtimeValidation.issues).Count -eq 2 -and
                [string]$runtimeValidation.firstIssue.kind -eq "OverlappingNotes" -and
                $expectedNoteIds.Count -eq 2 -and
                [string]$runtimeValidation.issues[1].kind -eq "CrossingLongNotes" -and
                [bool]$runtimeValidation.timeline.matchesPresentation -and
                [int]$runtimeValidation.timeline.totalIssueCount -eq 2 -and
                [bool]$runtimeValidation.lastNavigationMatchesPresentation -and
                $null -ne $primaryNavigation -and
                @($primaryNavigation.hiddenGroupsToReveal).Count -eq 1 -and
                [int]$primaryNavigation.hiddenGroupsToReveal[0] -eq 7 -and
                $null -ne $runtimeNavigation -and
                @($runtimeNavigation.hiddenGroupsToReveal).Count -eq 0 -and
                ($primaryHiddenGroups -contains 7) -and
                ($primaryHiddenGroups -contains 8) -and
                [int]$primaryChartValidationEvidence.timeline.selectedNoteCount -eq 0 -and
                [bool]$primaryChartValidationEvidence.timeline.sessionIsDirty -and
                [bool]$interactionEvidence.timeline.sessionIsDirty -and
                [long]$primaryChartValidationEvidence.timeline.sessionChangeSerial -eq
                    [long]$interactionEvidence.timeline.sessionChangeSerial -and
                [string]$primaryChartValidationEvidence.chart.structure.sha256 -eq
                    [string]$interactionEvidence.chart.structure.sha256 -and
                -not ($runtimeHiddenGroups -contains 7) -and
                ($runtimeHiddenGroups -contains 8) -and
                [int]$interactionEvidence.timeline.selectedNoteCount -eq 2 -and
                ($expectedNoteIds -join "|") -eq ($selectedNoteIds -join "|") -and
                ($expectedNoteIds -join "|") -eq ($navigationNoteIds -join "|") -and
                [int]$runtimeNavigation.exactBeat.bar -eq [int]$beat.bar -and
                [int]$runtimeNavigation.exactBeat.numerator -eq [int]$beat.numerator -and
                [int]$runtimeNavigation.exactBeat.denominator -eq [int]$beat.denominator -and
                [Math]::Abs([double]$interactionEvidence.timeline.currentBeat - [double]$beat.value) -le .000001 -and
                [bool]$runtimeValidation.manualCheckShown -and
                [bool]$runtimeValidation.saveBlockedShown -and
                [string]$runtimeValidation.lastDialogMode -eq "save-warning" -and
                [string]$runtimeValidation.manualCheckMessage -eq $expectedManualMessage -and
                [string]$runtimeValidation.saveBlockingMessage -eq $expectedSaveMessage -and
                $manualMessageFromUi -eq $expectedManualMessage -and
                $saveMessageFromUi -eq $expectedSaveMessage -and
                [bool]$chartValidationAction.noteInspectorSelected -and
                [string]$chartValidationAction.manualStatus.name -eq $expectedStatus -and
                [string]$runtimeNavigation.hoverStatusText -eq $expectedStatus -and
                [string]$chartValidationAction.status.name -eq
                    $expectedStatus -and
                $null -ne $manualScale -and [bool]$manualScale.usesLayoutTransform -and
                [Math]::Abs([double]$manualScale.requestedUiScale - 1.35) -le .000001 -and
                [Math]::Abs([double]$manualScale.requestedFontScale - 1.25) -le .000001 -and
                [Math]::Abs([double]$manualScale.actualRootScaleX - 1.35) -le .000001 -and
                [Math]::Abs([double]$manualScale.actualRootScaleY - 1.35) -le .000001 -and
                [Math]::Abs([double]$manualScale.messageFontSize - 16.25) -le .000001 -and
                $null -ne $saveScale -and [bool]$saveScale.usesLayoutTransform -and
                [Math]::Abs([double]$saveScale.requestedUiScale - 1.35) -le .000001 -and
                [Math]::Abs([double]$saveScale.requestedFontScale - 1.25) -le .000001 -and
                [Math]::Abs([double]$saveScale.actualRootScaleX - 1.35) -le .000001 -and
                [Math]::Abs([double]$saveScale.actualRootScaleY - 1.35) -le .000001 -and
                [Math]::Abs([double]$saveScale.messageFontSize - 16.25) -le .000001 -and
                [string]$chartValidationSourceBefore.sha256 -eq [string]$chartValidationSourceAfter.sha256 -and
                [long]$chartValidationSourceBefore.length -eq [long]$chartValidationSourceAfter.length -and
                [string]$chartValidationSourceBefore.lastWriteTimeUtc -eq
                    [string]$chartValidationSourceAfter.lastWriteTimeUtc -and
                [string]$interactionEvidence.chart.sourceSha256 -eq [string]$chartValidationSourceBefore.sha256
            if (-not $chartValidationRuntimeVerified) {
                throw "Chart-validation evidence did not prove exact WPF copy, first-issue navigation, hidden-group reveal, Note selection, independent scaled dialogs, timeline cross-check, and fail-closed source preservation."
            }
        }
    }
    if ($fullPackageExportExerciseEnabled) {
        $preExportWorkingCharts = @(Get-ChildItem `
                -LiteralPath $editingFullPath `
                -Recurse `
                -File `
                -Filter 'working.mc' | Where-Object {
                -not $_.FullName.StartsWith(
                    (Join-Path $editingFullPath '_scratch'),
                    [StringComparison]::OrdinalIgnoreCase)
            })
        if ($preExportWorkingCharts.Count -ne 1) {
            throw "FullPackage semantic round-trip gate requires exactly one isolated pre-export working.mc baseline; found $($preExportWorkingCharts.Count)."
        }
        if ($osuToMalodyFullPackage) {
            $cleanWorkingPath = [IO.Path]::GetFullPath($preExportWorkingCharts[0].FullName)
            $cleanWorkingItem = Get-Item -LiteralPath $cleanWorkingPath
            $malodyFullPackageCleanWorkingChart =
                Get-Content -LiteralPath $cleanWorkingPath -Raw | ConvertFrom-Json
            $malodyFullPackageCleanWorkingSemanticMap =
                ConvertTo-JsonSemanticMap -Value $malodyFullPackageCleanWorkingChart
            $malodyFullPackageCleanWorkingCacheTree =
                Get-DirectoryTreeEvidence -Root ([IO.Path]::GetDirectoryName($cleanWorkingPath))
            $cleanWorkingNotes = @($malodyFullPackageCleanWorkingChart.note)
            $cleanOriginalIndices = @(
                for ($noteIndex = 0; $noteIndex -lt $cleanWorkingNotes.Count; $noteIndex++) {
                    $candidate = $cleanWorkingNotes[$noteIndex]
                    $candidateBeat = @($candidate.beat)
                    if ($null -ne $candidate.column -and $candidateBeat.Count -ge 3 -and
                        $null -eq $candidate.endbeat -and
                        [int]$candidate.column -eq $selectedFullPackageOriginalLane -and
                        [int]$candidateBeat[0] -eq
                            [int]$malodyFullPackageDirtyInjection.beforeBeat.bar -and
                        [int]$candidateBeat[1] -eq
                            [int]$malodyFullPackageDirtyInjection.beforeBeat.numerator -and
                        [int]$candidateBeat[2] -eq
                            [int]$malodyFullPackageDirtyInjection.beforeBeat.denominator) {
                        $noteIndex
                    }
                })
            $cleanTargetIndices = @(
                for ($noteIndex = 0; $noteIndex -lt $cleanWorkingNotes.Count; $noteIndex++) {
                    $candidate = $cleanWorkingNotes[$noteIndex]
                    $candidateBeat = @($candidate.beat)
                    if ($null -ne $candidate.column -and $candidateBeat.Count -ge 3 -and
                        $null -eq $candidate.endbeat -and
                        [int]$candidate.column -eq $selectedFullPackageExpectedExportedLane -and
                        [int]$candidateBeat[0] -eq
                            [int]$malodyFullPackageDirtyInjection.submittedBeat.bar -and
                        [int]$candidateBeat[1] -eq
                            [int]$malodyFullPackageDirtyInjection.submittedBeat.numerator -and
                        [int]$candidateBeat[2] -eq
                            [int]$malodyFullPackageDirtyInjection.submittedBeat.denominator) {
                        $noteIndex
                    }
                })
            if ($cleanOriginalIndices.Count -ne 1 -or $cleanTargetIndices.Count -ne 0 -or
                $cleanWorkingNotes.Count -le 2468) {
                throw "osu!-to-Malody clean working baseline did not contain exactly one original Tap, zero dirty-target Taps, and the required Key-sound node."
            }
            $cleanKeySoundNode = $cleanWorkingNotes[2468]
            $cleanKeySoundBeat = @($cleanKeySoundNode.beat)
            $cleanKeySoundHasColumn =
                @($cleanKeySoundNode.PSObject.Properties.Name) -contains 'column'
            if ($cleanKeySoundBeat.Count -ne 3 -or
                [int]$cleanKeySoundBeat[0] -ne 0 -or
                [int]$cleanKeySoundBeat[1] -ne 0 -or
                [int]$cleanKeySoundBeat[2] -ne 1 -or
                [int]$cleanKeySoundNode.type -ne 1 -or
                [int]$cleanKeySoundNode.offset -ne -1000 -or
                $cleanKeySoundHasColumn -or
                [string]::IsNullOrWhiteSpace([string]$cleanKeySoundNode.sound)) {
                throw "osu!-to-Malody clean working baseline Key-sound node was not the trusted /note/2468 shape."
            }
            $cleanTargetIndex = [int]$cleanOriginalIndices[0]
            $malodyFullPackageCleanWorkingContract = [ordered]@{
                path = $cleanWorkingPath
                length = [long]$cleanWorkingItem.Length
                sha256 = (Get-FileHash -LiteralPath $cleanWorkingPath -Algorithm SHA256).Hash
                semanticSha256 =
                    Get-JsonSemanticSha256 -Value $malodyFullPackageCleanWorkingChart
                noteIndex = $cleanTargetIndex
                beatJsonPointer = "/note/$cleanTargetIndex/beat"
                laneJsonPointer = "/note/$cleanTargetIndex/column"
                originalBeat = @(
                    [int]$malodyFullPackageDirtyInjection.beforeBeat.bar,
                    [int]$malodyFullPackageDirtyInjection.beforeBeat.numerator,
                    [int]$malodyFullPackageDirtyInjection.beforeBeat.denominator)
                expectedBeat = @(
                    [int]$malodyFullPackageDirtyInjection.submittedBeat.bar,
                    [int]$malodyFullPackageDirtyInjection.submittedBeat.numerator,
                    [int]$malodyFullPackageDirtyInjection.submittedBeat.denominator)
                originalLane = $selectedFullPackageOriginalLane
                expectedLane = $selectedFullPackageExpectedExportedLane
                resources = [ordered]@{
                    audio = [string]$malodyFullPackageCleanWorkingChart.meta.song.file
                    background = [string]$malodyFullPackageCleanWorkingChart.meta.background
                    keySoundIndex = 2468
                    keySound = [string]$cleanKeySoundNode.sound
                }
            }
            $archiveBeforeMainExitItem =
                Get-Item -LiteralPath $malodyFullPackageExportFullPath
            $malodyFullPackageArchiveBeforeMainExit = [ordered]@{
                path = $malodyFullPackageExportFullPath
                length = [long]$archiveBeforeMainExitItem.Length
                lastWriteTimeUtc = $archiveBeforeMainExitItem.LastWriteTimeUtc.ToString(
                    'O',
                    [Globalization.CultureInfo]::InvariantCulture)
                sha256 = (Get-FileHash `
                    -LiteralPath $malodyFullPackageExportFullPath `
                    -Algorithm SHA256).Hash
            }
            $malodyFullPackageFreshImportEvidence =
                Invoke-OsuToMalodyFullPackageFreshImportEvidence `
                    -ApplicationPath $applicationPath `
                    -SeedChartPath $chartFullPath `
                    -SourceRoot $malodyFullPackageSourceRootFullPath `
                    -ArchivePath $malodyFullPackageExportFullPath `
                    -MainChartFileName $selectedFullPackageMainChartFileName `
                    -ArchiveEvidence $malodyFullPackageArchiveEvidence `
                    -ExpectedWorkingChartPath $preExportWorkingCharts[0].FullName `
                    -ExpectedStructureSha256 ([string]$malodyFullPackageInteractionRuntime.chart.structure.sha256) `
                    -ExpectedMainEntrySha256 ([string]$malodyFullPackageArchiveEvidence.mainChartEntry.sha256) `
                    -ExpectedKeyCount ([int]$malodyFullPackageInteractionRuntime.chart.structure.keyCount) `
                    -ExpectedNoteCount ([int]$malodyFullPackageInteractionRuntime.chart.structure.noteCount) `
                    -ExpectedLongNoteCount ([int]$malodyFullPackageInteractionRuntime.chart.structure.longNoteCount) `
                    -ExpectedTimingCount ([int]$malodyFullPackageInteractionRuntime.chart.structure.timingCount) `
                    -ExpectedBeat $malodyFullPackageDirtyInjection.submittedBeat `
                    -OriginalBeat $malodyFullPackageDirtyInjection.beforeBeat `
                    -OriginalLane $selectedFullPackageOriginalLane `
                    -ExpectedLane $selectedFullPackageExpectedExportedLane `
                    -WorkspaceRoot $malodyFullPackageFreshImportWorkspaceFullPath `
                    -LocalDataRoot $malodyFullPackageFreshImportLocalDataFullPath `
                    -EditingRoot $malodyFullPackageFreshImportEditingFullPath `
                    -EvidencePath $malodyFullPackageFreshImportEvidenceFullPath `
                    -InteractionEvidencePath $malodyFullPackageFreshImportInteractionEvidenceFullPath `
                    -ImportDialogScreenshotPath $malodyFullPackageFreshImportDialogScreenshotFullPath `
                    -FinalScreenshotPath $malodyFullPackageFreshImportScreenshotFullPath
        }
        else {
            $malodyFullPackageFreshImportEvidence = Invoke-MalodyFullPackageFreshImportEvidence `
                -ArchiveFormat $selectedFullPackageFormat `
                -SourceChartFormat $selectedFullPackageSourceFormat `
                -ApplicationPath $applicationPath `
                -SeedChartPath $chartFullPath `
                -SourceRoot $malodyFullPackageSourceRootFullPath `
                -ArchivePath $malodyFullPackageExportFullPath `
                -MainChartFileName $selectedFullPackageMainChartFileName `
                -ExpectedChartCount $selectedFullPackageExpectedChartCount `
                -ExpectedWorkingChartPath $preExportWorkingCharts[0].FullName `
                -ExpectedStructureSha256 ([string]$malodyFullPackageInteractionRuntime.chart.structure.sha256) `
                -ExpectedMainEntrySha256 ([string]$malodyFullPackageArchiveEvidence.mainChartEntry.sha256) `
                -ExpectedKeyCount ([int]$malodyFullPackageInteractionRuntime.chart.structure.keyCount) `
                -ExpectedNoteCount ([int]$malodyFullPackageInteractionRuntime.chart.structure.noteCount) `
                -ExpectedLongNoteCount ([int]$malodyFullPackageInteractionRuntime.chart.structure.longNoteCount) `
                -ExpectedTimingCount ([int]$malodyFullPackageInteractionRuntime.chart.structure.timingCount) `
                -ExpectedBeat $malodyFullPackageDirtyInjection.submittedBeat `
                -OriginalBeat $malodyFullPackageDirtyInjection.beforeBeat `
                -ExpectedLane ([int]$malodyFullPackageInteractionRuntime.timeline.selectedNotes[0].lane) `
                -FirstCalibrationScreenshotPath $osuFullPackageFreshImportFirstCalibrationScreenshotFullPath `
                -SecondCalibrationScreenshotPath $osuFullPackageFreshImportSecondCalibrationScreenshotFullPath `
                -ExpectedOverallDifficulty $OsuFullPackageOverallDifficulty `
                -ExpectedHpDrainRate $OsuFullPackageHpDrainRate `
                -ExpectedHitObjectTime $selectedFullPackageExpectedHitObjectTime `
                -OriginalLane $selectedFullPackageOriginalLane `
                -ExpectedExportedLane $selectedFullPackageExpectedExportedLane `
                -ExpectSourceOsuSiblings $selectedFullPackageExpectSourceOsuSiblings `
                -WorkspaceRoot $malodyFullPackageFreshImportWorkspaceFullPath `
                -LocalDataRoot $malodyFullPackageFreshImportLocalDataFullPath `
                -EditingRoot $malodyFullPackageFreshImportEditingFullPath `
                -EvidencePath $malodyFullPackageFreshImportEvidenceFullPath `
                -InteractionEvidencePath $malodyFullPackageFreshImportInteractionEvidenceFullPath `
                -ImportDialogScreenshotPath $malodyFullPackageFreshImportDialogScreenshotFullPath `
                -FinalScreenshotPath $malodyFullPackageFreshImportScreenshotFullPath
        }
        if (-not [bool]$malodyFullPackageFreshImportEvidence.verified -or
            -not [bool]$malodyFullPackageFreshImportEvidence.normalExit -or
            [int]$malodyFullPackageFreshImportEvidence.exitCode -ne 0 -or
            -not [bool]$malodyFullPackageFreshImportEvidence.sessionScratchRemovedAfterExit) {
            throw "Fresh Avalonia FullPackage GUI import did not complete its clean normal-exit gate."
        }
    }
    if ($FocusAudioPanels) {
        $audioPanelFocusEvidence = Get-Content -LiteralPath $evidenceFullPath -Raw | ConvertFrom-Json
        $audioPanelInteractionRuntimeEvidence = $audioPanelFocusEvidence.audio.panels
        if ($null -eq $audioPanelInteractionRuntimeEvidence) {
            throw "Focused audio-panel runtime evidence is missing audio.panels."
        }
        $runtimeAudioPanelSettingsPath =
            [IO.Path]::GetFullPath([string]$audioPanelInteractionRuntimeEvidence.settingsPath)
        $audioPanelFocusRuntimeVerified =
            $runtimeAudioPanelSettingsPath.Equals(
                [IO.Path]::GetFullPath($audioPanelSettingsPath),
                [StringComparison]::OrdinalIgnoreCase) -and
            [bool]$audioPanelInteractionRuntimeEvidence.settingsIsolatedFromWpf -and
            [int]$audioPanelInteractionRuntimeEvidence.sideCustomSurfaceCount -eq 2 -and
            [int]$audioPanelInteractionRuntimeEvidence.perSampleAvaloniaControlCount -eq 0 -and
            [bool]$audioPanelInteractionRuntimeEvidence.visibleAreaClipping
        if (-not $audioPanelFocusRuntimeVerified) {
            throw "Focused audio-panel runtime evidence did not prove isolated settings, two clipped custom surfaces, and zero per-sample Controls."
        }
        if (Test-Path -LiteralPath $audioPanelSettingsPath -PathType Leaf) {
            $audioPanelPersistedSettings = Get-Content -LiteralPath $audioPanelSettingsPath -Raw |
                ConvertFrom-Json
            $audioPanelSettingsSha256 =
                (Get-FileHash -LiteralPath $audioPanelSettingsPath -Algorithm SHA256).Hash
        }
    }
    if ($FocusDisplayScale) {
        Set-ForegroundWindowVerified -WindowHandle $process.MainWindowHandle
        $settingsTabObservation = Get-AutomationElementObservation `
            -TargetProcessId $process.Id `
            -AutomationId "Inspector.SettingsTab" `
            -RootWindowHandle $process.MainWindowHandle
        Click-AutomationElementWithMouse -Element $settingsTabObservation.Element
        Start-Sleep -Milliseconds 350

        $displayScaleControlEvidence = [ordered]@{
            "Inspector.SettingsTab" = $settingsTabObservation.Evidence
        }
        foreach ($automationId in @(
                "Settings.UiScale",
                "Settings.FontScale",
                "Settings.UiScaleValue",
                "Settings.FontScaleValue")) {
            $controlObservation = Get-AutomationElementObservation `
                -TargetProcessId $process.Id `
                -AutomationId $automationId `
                -RootWindowHandle $process.MainWindowHandle
            $displayScaleControlEvidence[$automationId] = $controlObservation.Evidence
        }
        $actualUiScale = Get-AutomationRangeValueObservation `
            -TargetProcessId $process.Id `
            -AutomationId "Settings.UiScale" `
            -RootWindowHandle $process.MainWindowHandle
        $actualFontScale = Get-AutomationRangeValueObservation `
            -TargetProcessId $process.Id `
            -AutomationId "Settings.FontScale" `
            -RootWindowHandle $process.MainWindowHandle
        $displayScaleActualValues = [ordered]@{
            uiPercent = $actualUiScale.Value
            fontPercent = $actualFontScale.Value
            uiValueText = [string]$displayScaleControlEvidence["Settings.UiScaleValue"].name
            fontValueText = [string]$displayScaleControlEvidence["Settings.FontScaleValue"].name
        }
        if ([Math]::Abs([double]$actualUiScale.Value - $DisplayScaleUiPercent) -gt .001 -or
            [Math]::Abs([double]$actualFontScale.Value - $DisplayScaleFontPercent) -gt .001) {
            throw "Display-scale focused capture did not expose the requested/restored $DisplayScaleUiPercent%/$DisplayScaleFontPercent% values."
        }
        $runtimeDisplayScaleEvidence = if ($interactionEvidenceFullPath) {
            Get-Content -LiteralPath $interactionEvidenceFullPath -Raw | ConvertFrom-Json
        } else {
            Get-Content -LiteralPath $evidenceFullPath -Raw | ConvertFrom-Json
        }
        $displayScaleRuntimeWindowEvidence = $runtimeDisplayScaleEvidence.window.displayScale
    }
    if ($process.MainWindowHandle -eq [IntPtr]::Zero) {
        throw "Avalonia main window handle was unavailable."
    }

    Start-Sleep -Milliseconds $(if ($LibraryHome) { 4000 } else { 500 })
    $rectangle = [LumaChartAvaloniaCaptureNative+RECT]::new()
    if (-not [LumaChartAvaloniaCaptureNative]::GetWindowRect($process.MainWindowHandle, [ref]$rectangle)) {
        throw "GetWindowRect failed."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -le 0 -or $height -le 0) { throw "Avalonia window bounds are invalid." }

    $bitmap = [Drawing.Bitmap]::new($width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $deviceContext = $graphics.GetHdc()
            try {
                if (-not [LumaChartAvaloniaCaptureNative]::PrintWindow(
                        $process.MainWindowHandle,
                        $deviceContext,
                        2)) {
                    throw "PrintWindow failed."
                }
            }
            finally {
                $graphics.ReleaseHdc($deviceContext)
            }
        }
        finally {
            $graphics.Dispose()
        }
        $sampleColors = [Collections.Generic.HashSet[int]]::new()
        $sampleLuminance = [Collections.Generic.List[double]]::new()
        $sampleOpaquePixels = 0
        for ($sampleY = 0; $sampleY -lt 16; $sampleY++) {
            $pixelY = [Math]::Min($height - 1, [int](($sampleY + .5) * $height / 16))
            for ($sampleX = 0; $sampleX -lt 16; $sampleX++) {
                $pixelX = [Math]::Min($width - 1, [int](($sampleX + .5) * $width / 16))
                $pixel = $bitmap.GetPixel($pixelX, $pixelY)
                [void]$sampleColors.Add($pixel.ToArgb())
                if ($pixel.A -gt 0) { $sampleOpaquePixels++ }
                $sampleLuminance.Add(.2126 * $pixel.R + .7152 * $pixel.G + .0722 * $pixel.B)
            }
        }
        $sampleMean = ($sampleLuminance | Measure-Object -Average).Average
        $sampleVariance = ($sampleLuminance | ForEach-Object {
            $difference = $_ - $sampleMean
            $difference * $difference
        } | Measure-Object -Average).Average
        $sampleLuminanceStdDev = [Math]::Sqrt([double]$sampleVariance)
        $minimumSampleColors = if ($ExerciseLibraryNoResults) { 3 } else { 8 }
        $minimumLuminanceStdDev = if ($ExerciseLibraryNoResults) { .25 } else { 1.5 }
        if ($sampleColors.Count -lt $minimumSampleColors -or $sampleOpaquePixels -lt 240 -or
            $sampleLuminanceStdDev -lt $minimumLuminanceStdDev) {
            throw "PrintWindow produced an empty or near-uniform screenshot: " +
                  "colors=$($sampleColors.Count); opaque=$sampleOpaquePixels; " +
                  "luminanceStdDev=$sampleLuminanceStdDev."
        }
        $bitmap.Save($screenshotFullPath, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }

    if ($fullPackageExportExerciseEnabled) {
        $closeWaitBudgetMilliseconds = 45000
        $closeRetryEarliestMilliseconds = 15000
        $closeTimer = [Diagnostics.Stopwatch]::StartNew()
        $closeRequestedAtUtc = [DateTimeOffset]::UtcNow
        $closeMainWindowReturned = $process.CloseMainWindow()
        $unsavedDialog = Find-AutomationElementByName `
            -TargetProcessId $process.Id `
            -Name "未保存的更改" `
            -TimeoutMilliseconds 7000
        $unsavedDialogHandle = [IntPtr]$unsavedDialog.Current.NativeWindowHandle
        if ($unsavedDialogHandle -eq [IntPtr]::Zero) {
            throw "Normal export-process close did not expose the unsaved-changes dialog."
        }
        $initialUnsavedDialogObservation =
            Get-StateConfirmedUnsavedDialogObservation `
                -TargetProcessId $process.Id `
                -DialogHandle $unsavedDialogHandle `
                -ExpectedName "未保存的更改"
        if (-not [bool]$initialUnsavedDialogObservation.Evidence.verified) {
            throw "Normal export-process close did not expose one live enabled visible unsaved-changes dialog with stable HWND identity."
        }
        $closeAttempts = [Collections.Generic.List[object]]::new()
        $closeAttempts.Add(
            (Invoke-StateConfirmedUnsavedDiscardPhysicalClick `
                -TargetProcessId $process.Id `
                -DialogHandle $unsavedDialogHandle `
                -AttemptNumber 1 `
                -Reason "initial state-confirmed physical discard")) | Out-Null
        $dialogIdentityWasLost = $false
        $dialogWasObservedClosed = $false
        $retryButtonUnavailableObservationCount = 0
        $processExitObservedWithinBudget = $false
        $processExitObservedAtUtc = $null
        while ($closeTimer.ElapsedMilliseconds -lt $closeWaitBudgetMilliseconds) {
            if ($process.HasExited) {
                $processExitObservedWithinBudget = $true
                $processExitObservedAtUtc = [DateTimeOffset]::UtcNow
                break
            }
            $remainingCloseWaitMilliseconds = [Math]::Max(
                1,
                $closeWaitBudgetMilliseconds -
                    [int]$closeTimer.ElapsedMilliseconds)
            $closePollMilliseconds = [Math]::Min(
                100,
                $remainingCloseWaitMilliseconds)
            if ($process.WaitForExit($closePollMilliseconds)) {
                $processExitObservedWithinBudget = $true
                $processExitObservedAtUtc = [DateTimeOffset]::UtcNow
                break
            }
            $currentUnsavedDialogObservation =
                Get-StateConfirmedUnsavedDialogObservation `
                    -TargetProcessId $process.Id `
                    -DialogHandle $unsavedDialogHandle `
                    -ExpectedName "未保存的更改"
            if (-not [bool]$currentUnsavedDialogObservation.Evidence.isWindow) {
                $dialogWasObservedClosed = $true
                continue
            }
            if ([bool]$currentUnsavedDialogObservation.Evidence.uiaAvailable -and
                -not [bool]$currentUnsavedDialogObservation.Evidence.identityMatches) {
                $dialogIdentityWasLost = $true
                continue
            }
            if ($dialogWasObservedClosed -or $dialogIdentityWasLost -or
                $closeAttempts.Count -ge 2 -or
                $closeTimer.ElapsedMilliseconds -lt $closeRetryEarliestMilliseconds -or
                -not [bool]$currentUnsavedDialogObservation.Evidence.verified) {
                continue
            }
            $retryButtonObservation =
                Get-StateConfirmedPhysicalButtonObservation `
                    -DialogElement $currentUnsavedDialogObservation.Element `
                    -TargetProcessId $process.Id `
                    -ExpectedName "放弃更改"
            if (-not [bool]$retryButtonObservation.Evidence.verified) {
                $retryButtonUnavailableObservationCount++
                continue
            }
            $closeAttempts.Add(
                (Invoke-StateConfirmedUnsavedDiscardPhysicalClick `
                    -TargetProcessId $process.Id `
                    -DialogHandle $unsavedDialogHandle `
                    -AttemptNumber 2 `
                -Reason "same-dialog state-confirmed retry after bounded wait")) | Out-Null
        }
        $closeTimer.Stop()
        $processExit = $process.HasExited
        $finalUnsavedDialogObservation =
            Get-StateConfirmedUnsavedDialogObservation `
                -TargetProcessId $process.Id `
                -DialogHandle $unsavedDialogHandle `
                -ExpectedName "未保存的更改"
        $malodyFullPackageCloseEvidence = [ordered]@{
            method =
                "CloseMainWindow + state-confirmed bounded physical discard click"
            requestedAtUtc = $closeRequestedAtUtc
            closeMainWindowReturned = $closeMainWindowReturned
            waitBudgetMilliseconds = $closeWaitBudgetMilliseconds
            retryEarliestMilliseconds = $closeRetryEarliestMilliseconds
            maximumAttemptCount = 2
            initialDialog = $initialUnsavedDialogObservation.Evidence
            attemptCount = $closeAttempts.Count
            retryUsed = $closeAttempts.Count -eq 2
            attempts = @($closeAttempts)
            dialogWasObservedClosed = $dialogWasObservedClosed
            dialogIdentityWasLost = $dialogIdentityWasLost
            retryButtonUnavailableObservationCount =
                $retryButtonUnavailableObservationCount
            dialogStillPresent =
                [bool]$finalUnsavedDialogObservation.Evidence.isWindow
            finalDialog = $finalUnsavedDialogObservation.Evidence
            processExit = $processExit
            processExitObservedWithinBudget = $processExitObservedWithinBudget
            processExitObservedAtUtc = $processExitObservedAtUtc
            elapsedMilliseconds = $closeTimer.Elapsed.TotalMilliseconds
            exitCode = if ($processExit) { [int]$process.ExitCode } else { $null }
            invokePatternUsed = $false
            blindRetryUsed = $false
        }
        if (-not $processExit -or -not $processExitObservedWithinBudget) {
            throw "Export-process did not exit normally within the 45-second state-confirmed discard close budget."
        }
        if ([int]$process.ExitCode -ne 0) {
            throw "Export-process state-confirmed discard close returned exit code $($process.ExitCode)."
        }
        $malodyFullPackageMainProcessNormalExit = $true
        $malodyFullPackageMainScratchRemovedAfterExit =
            -not (Test-Path -LiteralPath $malodyFullPackageScratchRoot)
        if (-not $malodyFullPackageMainScratchRemovedAfterExit) {
            throw "Export-process left its session scratch root after normal exit: $malodyFullPackageScratchRoot"
        }
        $malodyFullPackageSourceTreeAfterExit =
            Get-DirectoryTreeEvidence -Root $malodyFullPackageSourceRootFullPath
        if (-not (Test-DirectoryTreeEvidenceEqual `
                -Before $malodyFullPackageSourceTreeBefore `
                -After $malodyFullPackageSourceTreeAfterExit)) {
            throw "Normal export-process discard/exit changed the isolated source tree."
        }
        if ($osuToMalodyFullPackage) {
            if ($null -eq $malodyFullPackageCleanWorkingContract -or
                $null -eq $malodyFullPackageCleanWorkingChart -or
                $null -eq $malodyFullPackageCleanWorkingSemanticMap -or
                $null -eq $malodyFullPackageCleanWorkingCacheTree -or
                $null -eq $malodyFullPackageArchiveBeforeMainExit) {
                throw "osu!-to-Malody final-state gate is missing its captured clean working/archive baseline."
            }
            $finalWorkingPath =
                [IO.Path]::GetFullPath([string]$malodyFullPackageCleanWorkingContract.path)
            if (-not (Test-Path -LiteralPath $finalWorkingPath -PathType Leaf)) {
                throw "osu!-to-Malody final working.mc is missing after the main export process exited."
            }
            $finalWorkingRoot = [IO.Path]::GetDirectoryName($finalWorkingPath)
            $finalWorkingTree = Get-DirectoryTreeEvidence -Root $finalWorkingRoot
            $finalWorkingItem = Get-Item -LiteralPath $finalWorkingPath
            $finalWorkingChart = Get-Content -LiteralPath $finalWorkingPath -Raw |
                ConvertFrom-Json
            $finalWorkingSemanticMap = ConvertTo-JsonSemanticMap -Value $finalWorkingChart
            $finalWorkingSemanticDifferences = @(
                Compare-JsonSemanticMaps `
                    -Expected $malodyFullPackageCleanWorkingSemanticMap `
                    -Actual $finalWorkingSemanticMap)
            $expectedFinalDifferencePaths = @(
                ([string]$malodyFullPackageCleanWorkingContract.beatJsonPointer + '/1'),
                ([string]$malodyFullPackageCleanWorkingContract.beatJsonPointer + '/2'),
                [string]$malodyFullPackageCleanWorkingContract.laneJsonPointer) |
                Sort-Object
            $actualFinalDifferencePaths = @(
                $finalWorkingSemanticDifferences |
                    ForEach-Object { [string]$_.path } |
                    Sort-Object)
            $finalWorkingNotes = @($finalWorkingChart.note)
            $finalExactTargetIndices = @(
                for ($noteIndex = 0; $noteIndex -lt $finalWorkingNotes.Count; $noteIndex++) {
                    $candidate = $finalWorkingNotes[$noteIndex]
                    $candidateBeat = @($candidate.beat)
                    if ($null -ne $candidate.column -and $candidateBeat.Count -ge 3 -and
                        $null -eq $candidate.endbeat -and
                        [int]$candidate.column -eq
                            [int]$malodyFullPackageCleanWorkingContract.expectedLane -and
                        [int]$candidateBeat[0] -eq
                            [int]$malodyFullPackageCleanWorkingContract.expectedBeat[0] -and
                        [int]$candidateBeat[1] -eq
                            [int]$malodyFullPackageCleanWorkingContract.expectedBeat[1] -and
                        [int]$candidateBeat[2] -eq
                            [int]$malodyFullPackageCleanWorkingContract.expectedBeat[2]) {
                        $noteIndex
                    }
                })
            $finalOriginalIndices = @(
                for ($noteIndex = 0; $noteIndex -lt $finalWorkingNotes.Count; $noteIndex++) {
                    $candidate = $finalWorkingNotes[$noteIndex]
                    $candidateBeat = @($candidate.beat)
                    if ($null -ne $candidate.column -and $candidateBeat.Count -ge 3 -and
                        $null -eq $candidate.endbeat -and
                        [int]$candidate.column -eq
                            [int]$malodyFullPackageCleanWorkingContract.originalLane -and
                        [int]$candidateBeat[0] -eq
                            [int]$malodyFullPackageCleanWorkingContract.originalBeat[0] -and
                        [int]$candidateBeat[1] -eq
                            [int]$malodyFullPackageCleanWorkingContract.originalBeat[1] -and
                        [int]$candidateBeat[2] -eq
                            [int]$malodyFullPackageCleanWorkingContract.originalBeat[2]) {
                        $noteIndex
                    }
                })
            $finalTargetAtCleanIndex =
                $finalExactTargetIndices.Count -eq 1 -and
                [int]$finalExactTargetIndices[0] -eq
                    [int]$malodyFullPackageCleanWorkingContract.noteIndex
            $finalAudioReference = [string]$finalWorkingChart.meta.song.file
            $finalBackgroundReference = [string]$finalWorkingChart.meta.background
            $finalKeySoundNode = if ($finalWorkingNotes.Count -gt 2468) {
                $finalWorkingNotes[2468]
            } else { $null }
            $finalKeySoundReference = if ($null -ne $finalKeySoundNode) {
                [string]$finalKeySoundNode.sound
            } else { $null }
            $workingResourcesRetainedOriginalNames =
                $finalAudioReference.Equals(
                    [string]$malodyFullPackageCleanWorkingContract.resources.audio,
                    [StringComparison]::Ordinal) -and
                $finalBackgroundReference.Equals(
                    [string]$malodyFullPackageCleanWorkingContract.resources.background,
                    [StringComparison]::Ordinal) -and
                $finalKeySoundReference.Equals(
                    [string]$malodyFullPackageCleanWorkingContract.resources.keySound,
                    [StringComparison]::Ordinal) -and
                -not $finalAudioReference.Equals(
                    [string]$malodyFullPackageArchiveEvidence.audioReference,
                    [StringComparison]::Ordinal) -and
                -not $finalBackgroundReference.Equals(
                    [string]$malodyFullPackageArchiveEvidence.backgroundReference,
                    [StringComparison]::Ordinal) -and
                -not $finalKeySoundReference.Equals(
                    [string]$malodyFullPackageArchiveEvidence.keySoundNodes[0].sound,
                    [StringComparison]::Ordinal)

            $cleanWorkingRows = @($malodyFullPackageCleanWorkingCacheTree.files)
            $finalWorkingRows = @($finalWorkingTree.files)
            $cleanWorkingPaths = @($cleanWorkingRows | ForEach-Object {
                    [string]$_.relativePath
                } | Sort-Object)
            $finalWorkingPaths = @($finalWorkingRows | ForEach-Object {
                    [string]$_.relativePath
                } | Sort-Object)
            $workingPathSetUnchanged =
                ($cleanWorkingPaths -join '|') -ceq ($finalWorkingPaths -join '|')
            $nonChartWorkingMismatches = @(
                foreach ($cleanRow in $cleanWorkingRows) {
                    if ([string]$cleanRow.relativePath -ceq 'working.mc') { continue }
                    $matches = @($finalWorkingRows | Where-Object {
                            [string]$_.relativePath -ceq [string]$cleanRow.relativePath
                        })
                    if ($matches.Count -ne 1 -or
                        [long]$matches[0].length -ne [long]$cleanRow.length -or
                        [string]$matches[0].lastWriteTimeUtc -cne
                            [string]$cleanRow.lastWriteTimeUtc -or
                        [string]$matches[0].sha256 -cne [string]$cleanRow.sha256) {
                        [string]$cleanRow.relativePath
                    }
                })
            $finalArchiveItem = Get-Item -LiteralPath $malodyFullPackageExportFullPath
            $finalArchive = [ordered]@{
                path = $malodyFullPackageExportFullPath
                length = [long]$finalArchiveItem.Length
                lastWriteTimeUtc = $finalArchiveItem.LastWriteTimeUtc.ToString(
                    'O',
                    [Globalization.CultureInfo]::InvariantCulture)
                sha256 = (Get-FileHash `
                    -LiteralPath $malodyFullPackageExportFullPath `
                    -Algorithm SHA256).Hash
            }
            $archiveUnchangedAfterMainExit =
                [long]$finalArchive.length -eq
                    [long]$malodyFullPackageArchiveBeforeMainExit.length -and
                [string]$finalArchive.lastWriteTimeUtc -ceq
                    [string]$malodyFullPackageArchiveBeforeMainExit.lastWriteTimeUtc -and
                [string]$finalArchive.sha256 -ceq
                    [string]$malodyFullPackageArchiveBeforeMainExit.sha256
            $sourceUnchangedAfterMainExit = Test-DirectoryTreeEvidenceEqual `
                -Before $malodyFullPackageSourceTreeBefore `
                -After $malodyFullPackageSourceTreeAfterExit
            $finalWorkingProjectionVerified =
                $finalWorkingSemanticDifferences.Count -eq 3 -and
                ($expectedFinalDifferencePaths -join '|') -ceq
                    ($actualFinalDifferencePaths -join '|') -and
                $finalExactTargetIndices.Count -eq 1 -and
                $finalOriginalIndices.Count -eq 0 -and
                $finalTargetAtCleanIndex -and
                $workingResourcesRetainedOriginalNames -and
                $workingPathSetUnchanged -and
                $nonChartWorkingMismatches.Count -eq 0
            $finalWorkingFile = [ordered]@{
                path = $finalWorkingPath
                length = [long]$finalWorkingItem.Length
                lastWriteTimeUtc = $finalWorkingItem.LastWriteTimeUtc.ToString(
                    'O',
                    [Globalization.CultureInfo]::InvariantCulture)
                sha256 = (Get-FileHash -LiteralPath $finalWorkingPath -Algorithm SHA256).Hash
                semanticSha256 = Get-JsonSemanticSha256 -Value $finalWorkingChart
            }
            $malodyFullPackageFinalStateAfterMainProcessExit = [ordered]@{
                sampledAfterMainProcessExit = $true
                processId = $process.Id
                processExitCode = [int]$process.ExitCode
                sourceTreeBefore = $malodyFullPackageSourceTreeBefore
                sourceTree = $malodyFullPackageSourceTreeAfterExit
                sourceTreeUnchanged = $sourceUnchangedAfterMainExit
                workingTreeBeforeMainExit = $malodyFullPackageCleanWorkingCacheTree
                workingTree = $finalWorkingTree
                workingPathSetUnchanged = $workingPathSetUnchanged
                nonChartWorkingMismatchCount = $nonChartWorkingMismatches.Count
                nonChartWorkingMismatches = @($nonChartWorkingMismatches)
                workingMc = [ordered]@{
                    cleanBaseline = $malodyFullPackageCleanWorkingContract
                    finalFile = $finalWorkingFile
                    expectedSemanticDifferencePaths = $expectedFinalDifferencePaths
                    semanticDifferenceCount = $finalWorkingSemanticDifferences.Count
                    semanticDifferences = $finalWorkingSemanticDifferences
                    exactTargetCount = $finalExactTargetIndices.Count
                    originalTargetCount = $finalOriginalIndices.Count
                    targetAtCleanNoteIndex = $finalTargetAtCleanIndex
                    resources = [ordered]@{
                        cleanAudio =
                            [string]$malodyFullPackageCleanWorkingContract.resources.audio
                        finalAudio = $finalAudioReference
                        packagedAudio =
                            [string]$malodyFullPackageArchiveEvidence.audioReference
                        cleanBackground =
                            [string]$malodyFullPackageCleanWorkingContract.resources.background
                        finalBackground = $finalBackgroundReference
                        packagedBackground =
                            [string]$malodyFullPackageArchiveEvidence.backgroundReference
                        cleanKeySound =
                            [string]$malodyFullPackageCleanWorkingContract.resources.keySound
                        finalKeySound = $finalKeySoundReference
                        packagedKeySound =
                            [string]$malodyFullPackageArchiveEvidence.keySoundNodes[0].sound
                        retainedOriginalNames = $workingResourcesRetainedOriginalNames
                    }
                    verified = $finalWorkingProjectionVerified
                }
                archiveBeforeMainExit = $malodyFullPackageArchiveBeforeMainExit
                archive = $finalArchive
                archiveUnchanged = $archiveUnchangedAfterMainExit
                verified =
                    $sourceUnchangedAfterMainExit -and
                    $archiveUnchangedAfterMainExit -and
                    $finalWorkingProjectionVerified
            }
            if (-not [bool]$malodyFullPackageFinalStateAfterMainProcessExit.verified) {
                throw "osu!-to-Malody main-process exit did not retain source/archive bytes or persist exactly the dirty-only working.mc projection with original cache resource names."
            }
        }
    }

    [pscustomobject]@{
        processId = $process.Id
        mode = if ($LibraryHome) { "library-home" } elseif ($SyntheticNoteCount -gt 0) { "synthetic-note-editor" } else { "real-chart-editor" }
        libraryNoResultsExercised = $libraryNoResultsExercised
        libraryNoResults = $libraryNoResultsEvidence
        chartPath = $chartFullPath
        focusTiming = [bool]$FocusTiming
        focusHoldTail = [bool]$FocusHoldTail
        focusNoteProperty = [bool]$FocusNoteProperty
        focusNotePropertyBeat = $FocusNotePropertyBeat
        focusGroup = [bool]$FocusGroup
        focusGroupBeat = $FocusGroupBeat
        focusProEditor = [bool]$FocusProEditor
        focusKeySound = [bool]$FocusKeySound
        focusDisplayScale = [bool]$FocusDisplayScale
        focusAudioPanels = [bool]($FocusAudioPanels -or $ExerciseAudioPanels)
        focusLibraryDeletion = [bool]$FocusLibraryDeletion
        focusChartValidation = [bool]$FocusChartValidation
        chartValidationExercised = $chartValidationExercised
        chartValidationAction = $chartValidationAction
        chartValidationRuntime = $chartValidationInteractionRuntimeEvidence
        chartValidationManualDialogScreenshotPath = $chartValidationManualDialogScreenshotFullPath
        chartValidationManualDialogScreenshotSha256 = $chartValidationManualDialogScreenshotSha256
        chartValidationSaveBlockedDialogScreenshotPath = $chartValidationSaveBlockedDialogScreenshotFullPath
        chartValidationSaveBlockedDialogScreenshotSha256 = $chartValidationSaveBlockedDialogScreenshotSha256
        chartValidationSourceBefore = $chartValidationSourceBefore
        chartValidationSourceAfter = $chartValidationSourceAfter
        chartExportModesExercised = $chartExportModesExercised
        chartExportModes = if ($chartExportModesExerciseEnabled) {
            $chartExportModesEvidence
        } else { $null }
        chartExportModesScreenshots = if ($chartExportModesExerciseEnabled) {
            [ordered]@{
                defaultFullPackage = [ordered]@{
                    path = $chartExportModesDefaultScreenshotFullPath
                    sha256 = $chartExportModesDefaultScreenshotSha256
                }
                singleChart = [ordered]@{
                    path = $chartExportModesSingleChartScreenshotFullPath
                    sha256 = $chartExportModesSingleChartScreenshotSha256
                }
                singleRatePackage = [ordered]@{
                    path = $chartExportModesSingleRateScreenshotFullPath
                    sha256 = $chartExportModesSingleRateScreenshotSha256
                }
                ratePack = [ordered]@{
                    path = $chartExportModesRatePackScreenshotFullPath
                    sha256 = $chartExportModesRatePackScreenshotSha256
                }
                hiddenFieldValidation = [ordered]@{
                    path = $chartExportModesHiddenValidationScreenshotFullPath
                    sha256 = $chartExportModesHiddenValidationScreenshotSha256
                }
                nativeSaveCancel = if ($chartExportModesNativeSaveEdgeEnabled) {
                    [ordered]@{
                        path = $chartExportModesCancelScreenshotFullPath
                        sha256 = $chartExportModesCancelScreenshotSha256
                    }
                } else { $null }
                nativeOverwriteConfirmation = if ($chartExportModesNativeSaveEdgeEnabled) {
                    [ordered]@{
                        path = $chartExportModesOverwriteScreenshotFullPath
                        sha256 = $chartExportModesOverwriteScreenshotSha256
                    }
                } else { $null }
            }
        } else { $null }
        libraryDeletionExercised = $libraryDeletionExercised
        libraryBatchDeleteConfirmExercised = [bool]($ExerciseLibraryBatchDeleteConfirm -and
            $libraryDeletionExercised)
        libraryOpenDocumentBlockExercised = [bool]($ExerciseLibraryOpenDocumentBlock -and
            $libraryDeletionExercised)
        libraryDeletionRequestedOutcome = if ($ExerciseLibraryDeleteConfirm -or
            $ExerciseLibraryBatchDeleteConfirm) {
            "Recycle"
        } elseif ($ExerciseLibraryOpenDocumentBlock) {
            "Blocked"
        } elseif ($ExerciseLibraryDeleteCancel) { "Cancel" } else { $null }
        libraryDeletionAction = $libraryDeletionAction
        libraryDeletionRuntime = $libraryDeletionInteractionRuntimeEvidence
        libraryDeleteTargetPath = $libraryDeleteTargetFullPath
        libraryDeleteTargetExistedBefore = $libraryDeleteTargetExistedBefore
        libraryDeleteTargetExistsAfter = $libraryDeleteTargetExistsAfter
        libraryDeleteSecondTargetPath = $libraryDeleteSecondTargetFullPath
        libraryDeleteSecondTargetExistedBefore = $libraryDeleteSecondTargetExistedBefore
        libraryDeleteSecondTargetExistsAfter = $libraryDeleteSecondTargetExistsAfter
        libraryContextMenuScreenshotPath = $libraryContextMenuScreenshotFullPath
        libraryContextMenuScreenshotSha256 = $libraryContextMenuScreenshotSha256
        libraryDeleteDialogScreenshotPath = $libraryDeleteDialogScreenshotFullPath
        libraryDeleteDialogScreenshotSha256 = $libraryDeleteDialogScreenshotSha256
        placementProbeViewport = [bool]$ExerciseGroupPlacement
        backgroundWaveformEnabled = [bool]$EnableBackgroundWaveform
        backgroundSpectrogramEnabled = [bool]$EnableBackgroundSpectrogram
        audioPanelsExercised = $audioPanelsExercised
        audioPanelControlsInitial = $audioPanelInitialControls
        audioPanelControlsFinal = $audioPanelFinalControls
        audioPanelStateInitial = $audioPanelInitialState
        audioPanelStateFinal = $audioPanelFinalState
        audioPanelActions = $audioPanelActions
        audioPanelAutomationFallbackUsed = $audioPanelAutomationFallbackUsed
        audioPanelDragAutomationFallbackUsed = $audioPanelDragAutomationFallbackUsed
        audioPanelSettingsPath = $audioPanelSettingsPath
        audioPanelSettingsSha256 = $audioPanelSettingsSha256
        audioPanelSettings = if ($FocusAudioPanels -or $ExerciseAudioPanels) {
            [ordered]@{
                path = $audioPanelSettingsPath
                exists = Test-Path -LiteralPath $audioPanelSettingsPath -PathType Leaf
                sha256 = $audioPanelSettingsSha256
                debounceMilliseconds = 350
                waitedMilliseconds = if ($ExerciseAudioPanels) {
                    $audioPanelDebounceWaitMilliseconds
                } else { 0 }
                persisted = $audioPanelPersistedSettings
            }
        } else { $null }
        audioPanelRuntime = $audioPanelInteractionRuntimeEvidence
        audioPanelInteractionRuntime = $audioPanelInteractionRuntimeEvidence
        edgeScrollExercised = $edgeScrollExercised
        holdTailResizeExercised = $holdTailResizeExercised
        longToTapExercised = $longToTapExercised
        notePropertyExercised = $notePropertyExercised
        notePropertySaved = $notePropertySaved
        sourceSaveFailureExercised = [bool]$ExerciseSourceSaveFailure
        sourceSaveFailure = $sourceSaveFailureAction
        sourceSaveFailureDialogScreenshotPath =
            $sourceSaveFailureDialogScreenshotFullPath
        sourceSaveFailureDialogScreenshotSha256 =
            $sourceSaveFailureDialogScreenshotSha256
        notePropertySubmitted = if ($ExerciseNoteProperty) {
            [ordered]@{
                beat = $NotePropertyBeat
                endBeat = $NotePropertyEndBeat
                lane = $NotePropertyLane
                volume = $NotePropertyVolume
                sound = $NotePropertySound
                group = $NotePropertyGroup
                derivedFromSelection = [bool]$DeriveNotePropertyFromSelection
            }
        } else { $null }
        notePropertyPhysicalActions = @($notePropertyPhysicalActions)
        groupAssignExercised = $groupAssignExercised
        groupAssignSaved = $groupAssignSaved
        groupVisibilityExercised = $groupVisibilityExercised
        groupPlacementExercised = $groupPlacementExercised
        groupVisibilityAutomationFallbackUsed = $groupVisibilityAutomationFallbackUsed
        groupPlacementHideAutomationFallbackUsed = $groupPlacementHideAutomationFallbackUsed
        proEditorPanExercised = $proEditorPanExercised
        proEditorRevealExercised = $proEditorRevealExercised
        proEditorEditExercised = $proEditorEditExercised
        proEditorEditSaved = $proEditorEditSaved
        proEditorActivation = $proEditorActivationEvidence
        proEditorSaveAsOsuExercised = $proEditorSaveAsOsuExercised
        proEditorSaveAsInitialDirectoryVerified = $proEditorSaveAsInitialDirectoryVerified
        proEditorSaveAsVisibleSourceName = $proEditorSaveAsVisibleSourceName
        proEditorSaveAsOsuPath = $proEditorSaveAsOsuFullPath
        proEditorSaveAsOsuSha256 = if ($proEditorSaveAsOsuFullPath -and
            (Test-Path -LiteralPath $proEditorSaveAsOsuFullPath)) {
            (Get-FileHash -LiteralPath $proEditorSaveAsOsuFullPath -Algorithm SHA256).Hash
        } else { $null }
        malodyFullPackageExportExercised = $malodyFullPackageExportExercised
        fullPackageExportFormat = if ($fullPackageExportExerciseEnabled) {
            $selectedFullPackageFormat
        } else { $null }
        fullPackageSourceFormat = if ($fullPackageExportExerciseEnabled) {
            $selectedFullPackageSourceFormat
        } else { $null }
        fullPackageCrossFormat = if ($fullPackageExportExerciseEnabled) {
            $crossFormatFullPackage
        } else { $false }
        malodyFullPackageExport = if ($fullPackageExportExerciseEnabled) {
            [ordered]@{
                format = $selectedFullPackageFormat
                sourceFormat = $selectedFullPackageSourceFormat
                crossFormat = $crossFormatFullPackage
                destinationPath = $malodyFullPackageExportFullPath
                sourceRoot = $malodyFullPackageSourceRootFullPath
                fixture = $malodyFullPackageFixtureEvidence
                expectedChartCount = $selectedFullPackageExpectedChartCount
                expectedMainChartFileName = $selectedFullPackageMainChartFileName
                expectedArchiveEntryCount = $selectedFullPackageExpectedEntryCount
                explorerRevealSuppressedForEvidence = $true
                evidenceFilePickerStartDirectory = [ordered]@{
                    injected = $true
                    path = [IO.Path]::GetDirectoryName($malodyFullPackageExportFullPath)
                    primaryRuntimeRecorded =
                        [bool]$primaryExportEvidence.evidenceFilePickerStartDirectoryInjected
                    interactionRuntimeRecorded =
                        [bool]$malodyFullPackageInteractionRuntime.evidenceFilePickerStartDirectoryInjected
                }
                dirtyInjection = $malodyFullPackageDirtyInjection
                options = $malodyFullPackageOptionsEvidence
                nativeSave = $malodyFullPackageNativeSaveEvidence
                result = $malodyFullPackageResultEvidence
                optionsScreenshotPath = $malodyFullPackageOptionsScreenshotFullPath
                optionsScreenshotSha256 = $malodyFullPackageOptionsScreenshotSha256
                resultScreenshotPath = $malodyFullPackageResultScreenshotFullPath
                resultScreenshotSha256 = $malodyFullPackageResultScreenshotSha256
                archive = $malodyFullPackageArchiveEvidence
                sourceTreeBefore = $malodyFullPackageSourceTreeBefore
                sourceTreeAfter = $malodyFullPackageSourceTreeAfter
                sourceTreeUnchanged = $malodyFullPackageSourceTreeUnchanged
                workingTreeAfterDirty = $malodyFullPackageWorkingTreeAfterDirty
                workingTreeAfterExport = $malodyFullPackageWorkingTreeAfterExport
                workingTreeUnchangedByExport = $malodyFullPackageWorkingTreeUnchangedByExport
                scratch = $malodyFullPackageScratchExportsAfter
                interactionRuntime = $malodyFullPackageInteractionRuntime
                freshImport = $malodyFullPackageFreshImportEvidence
                freshImportCalibrationScreenshots = if ($targetOsuFullPackage) {
                    if ($selectedFullPackageExpectedChartCount -eq 1) {
                        @($osuFullPackageFreshImportFirstCalibrationScreenshotFullPath)
                    } else {
                        @(
                            $osuFullPackageFreshImportFirstCalibrationScreenshotFullPath,
                            $osuFullPackageFreshImportSecondCalibrationScreenshotFullPath)
                    }
                } else { @() }
                mainProcessNormalExit = $malodyFullPackageMainProcessNormalExit
                close = $malodyFullPackageCloseEvidence
                mainSessionScratchRemovedAfterExit =
                    $malodyFullPackageMainScratchRemovedAfterExit
                finalStateAfterMainProcessExit =
                    $malodyFullPackageFinalStateAfterMainProcessExit
            }
        } else { $null }
        keySoundRuntimeExercised = $keySoundRuntimeExercised
        keySoundSourceMode = $keySoundSourceMode
        keySoundControls = $keySoundControlEvidence
        keySoundSubmittedSettings = $keySoundSubmittedSettings
        keySoundPreviewCompleted = $keySoundPreviewCompleted
        keySoundPlayCompleted = $keySoundPlayCompleted
        keySoundStopCompleted = $keySoundStopCompleted
        keySoundToggleAutomationFallbackUsed = $keySoundToggleAutomationFallbackUsed
        keySoundAudibleOrLoopbackValidated = $false
        displayScaleExercised = $displayScaleExercised
        displayScaleControls = $displayScaleControlEvidence
        displayScaleRequested = $displayScaleRequestedValues
        displayScaleActual = $displayScaleActualValues
        displayScalePointer = $displayScalePointerEvidence
        displayScaleAutomationFallbackUsed = $displayScaleAutomationFallbackUsed
        displayScaleDebounceWaitMilliseconds = if ($ExerciseDisplayScale) {
            $displayScaleDebounceWaitMilliseconds
        } else { $null }
        displayScaleRuntimeWindow = $displayScaleRuntimeWindowEvidence
        displayScaleIsolation = if ($FocusDisplayScale) {
            $settingsPath = Join-Path $localDataFullPath "display-scale-settings.json"
            [ordered]@{
                workspaceRoot = $workspaceFullPath
                localDataRoot = $localDataFullPath
                editingRoot = $editingFullPath
                existingLocalDataRootExplicitlyAllowed = [bool]$AllowExistingLocalDataRoot
                settingsPath = $settingsPath
                settingsExists = Test-Path -LiteralPath $settingsPath -PathType Leaf
                settingsSha256 = if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
                    (Get-FileHash -LiteralPath $settingsPath -Algorithm SHA256).Hash
                } else { $null }
            }
        } else { $null }
        groupSubmitted = if ($groupExerciseEnabled) {
            [ordered]@{
                group = $groupIdValue
                focusBeat = $groupFocusBeat
            }
        } else { $null }
        interactionDelayMilliseconds = if ($interactionEvidenceFullPath) {
            $InteractionDelayMilliseconds
        } else { $null }
        interactionActionsCompletedAtUtc = $interactionActionsCompletedAtUtc
        interactionCapturedAfterActions = $interactionCapturedAfterActions
        evidencePath = $evidenceFullPath
        evidenceSha256 = if ($evidenceFullPath) { (Get-FileHash -LiteralPath $evidenceFullPath -Algorithm SHA256).Hash } else { $null }
        interactionEvidencePath = $interactionEvidenceFullPath
        interactionEvidenceSha256 = if ($interactionEvidenceFullPath) { (Get-FileHash -LiteralPath $interactionEvidenceFullPath -Algorithm SHA256).Hash } else { $null }
        screenshotPath = $screenshotFullPath
        screenshotWidth = $width
        screenshotHeight = $height
        screenshotSha256 = (Get-FileHash -LiteralPath $screenshotFullPath -Algorithm SHA256).Hash
        screenshotSampledPixels = $sampleLuminance.Count
        screenshotSampledUniqueColors = $sampleColors.Count
        screenshotSampledOpaquePixels = $sampleOpaquePixels
        screenshotSampledLuminanceStdDev = $sampleLuminanceStdDev
        screenshotMinimumSampleColors = $minimumSampleColors
        screenshotMinimumLuminanceStdDev = $minimumLuminanceStdDev
    } | ConvertTo-Json -Depth 12
}
finally {
    if (-not $process.HasExited) {
        $process.CloseMainWindow() | Out-Null
        if (-not $process.WaitForExit(5000)) {
            $process.Kill($true)
            $process.WaitForExit(5000) | Out-Null
        }
    }
    $process.Dispose()
}
