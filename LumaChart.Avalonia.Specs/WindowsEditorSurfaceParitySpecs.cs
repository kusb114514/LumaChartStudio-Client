using LumaChart.Avalonia.Infrastructure;
using LumaChart.Avalonia.Rendering;
using LumaChart.Avalonia.ViewModels;
using LumaChart.Application.Workspaces;
using LumaChart.Core.Models;
using System.Collections.Specialized;

namespace LumaChart.Avalonia.Specs;

internal static class WindowsEditorSurfaceParitySpecs
{
    public static IReadOnlyList<WindowsEditorSurfaceParitySpecResult> Run()
    {
        return
        [
            VerifyWheelDirectionMatchesWpf(),
            VerifyTimelineGridHierarchyMatchesWpf(),
            VerifyTimelineSubdivisionCheckPalette(),
            VerifyHiddenLongNoteBodyMode(),
            VerifyImeDuplicateCommitGuardHook(),
            VerifyTimelineMeasureNumbersMatchWpf(),
            VerifyHoldInteractionChromeMatchesWpf(),
            VerifyPlaybackHoverCannotEnterSeekPipeline(),
            VerifyManualTimelineNavigationPausesPlayback(),
            VerifyChartExportDefaultsToDownloads(),
            VerifyCompactOnlineSurfacesAreWired(),
            VerifyQuickValueAdjustmentsRestoreTimelineFocus(),
            VerifyNavigationMarkersAreWired(),
            VerifyPresetDrawersAndInlineAnnotationEditorAreWired(),
            VerifyLargeLibraryStartupStaysResponsive(),
            VerifyPlaybackChromeAndInspectorFitAreWired(),
            VerifyRoomUploadAndActualAvatarsAreWired(),
            VerifyRoomChatPanelClampIsWired(),
            VerifyLoginLibraryAndPlayerListRegressionsAreWired()
        ];
    }

    private static WindowsEditorSurfaceParitySpecResult VerifyTimelineSubdivisionCheckPalette()
    {
        var mainWindowSource = ReadMainWindowSource();
        var timelineSource = ReadProjectSource(
            "LumaChart.Avalonia",
            "Controls",
            "TimelineSurface.cs");
        var normalColors = TimelineSubdivisionCheckPalette.SupportedDenominators
            .Select(denominator => TimelineSubdivisionCheckPalette.Resolve(denominator))
            .ToArray();
        var warning46 = TimelineSubdivisionCheckPalette.Resolve(46);
        var warning47 = TimelineSubdivisionCheckPalette.Resolve(47);
        var warning960 = TimelineSubdivisionCheckPalette.Resolve(960);
        var normalColorsAreBright = normalColors.All(style =>
            Math.Max(style.Color.R, Math.Max(style.Color.G, style.Color.B)) >= 229 &&
            (int)style.Color.R + style.Color.G + style.Color.B >= 360);
        var passed =
            normalColors.All(style => !style.IsWarning) &&
            normalColorsAreBright &&
            normalColors.Select(style => style.Color).Distinct().Count() == normalColors.Length &&
            !TimelineSubdivisionCheckPalette.IsSupportedDenominator(14) &&
            TimelineSubdivisionCheckPalette.IsSupportedDenominator(64) &&
            TimelineSubdivisionCheckPalette.IsSupportedDenominator(96) &&
            !TimelineSubdivisionCheckPalette.IsSupportedDenominator(46) &&
            !TimelineSubdivisionCheckPalette.IsSupportedDenominator(192) &&
            !TimelineSubdivisionCheckPalette.IsSupportedDenominator(480) &&
            !TimelineSubdivisionCheckPalette.IsSupportedDenominator(960) &&
            warning46.IsWarning &&
            warning960.IsWarning &&
            warning46.Color == TimelineSubdivisionCheckPalette.WarningColor &&
            warning46.Color == warning47.Color &&
            warning46.Color == warning960.Color &&
            mainWindowSource.Contains("Editor.SubdivisionCheck", StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "timeline.SetSubdivisionCheckEnabled(enabled)",
                StringComparison.Ordinal) &&
            timelineSource.Contains(
                "ResolveSubdivisionCheckPen(beat.Denominator)",
                StringComparison.Ordinal) &&
            timelineSource.Contains(
                "endBeat.Value.Denominator",
                StringComparison.Ordinal);
        return Result(
            "windows-timeline-subdivision-check-colors-exact-denominators-and-warns-outliers",
            passed,
            $"normal={normalColors.Length}; bright={normalColorsAreBright}; " +
            $"unique={normalColors.Select(style => style.Color).Distinct().Count()}; " +
            $"46/960={warning46.Color}/{warning960.Color}; " +
            $"cellCenter64/96={TimelineSubdivisionCheckPalette.IsSupportedDenominator(64)}/" +
            $"{TimelineSubdivisionCheckPalette.IsSupportedDenominator(96)}");
    }

    private static WindowsEditorSurfaceParitySpecResult VerifyHiddenLongNoteBodyMode()
    {
        var mainWindowSource = ReadMainWindowSource();
        var timelineSource = ReadProjectSource(
            "LumaChart.Avalonia",
            "Controls",
            "TimelineSurface.cs");
        var passed =
            // The toggle lives in the toolbox list now, so the hook that is
            // worth pinning is the action key and the call it makes — the
            // per-button icon this used to check no longer exists.
            mainWindowSource.Contains(
                "private const string ToolboxHideBodies = \"hideBodies\";",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "timeline.SetHideLongNoteBodies(enabled);",
                StringComparison.Ordinal) &&
            timelineSource.Contains("HiddenHoldHeadPen", StringComparison.Ordinal) &&
            timelineSource.Contains(
                "Color.Parse(\"#FF9A86B8\")",
                StringComparison.Ordinal) &&
            timelineSource.Contains(
                "HiddenHoldHeadBorderThickness = 3;",
                StringComparison.Ordinal) &&
            timelineSource.Contains(
                "DrawTapNote(context, headRect, headSubdivisionPen ?? HiddenHoldHeadPen);",
                StringComparison.Ordinal) &&
            !timelineSource.Contains("HiddenHoldTailPen", StringComparison.Ordinal) &&
            !timelineSource.Contains("HiddenHoldTailBrush", StringComparison.Ordinal) &&
            timelineSource.Contains(
                "hideLongNoteBodies && note.EndBeat.HasValue",
                StringComparison.Ordinal) &&
            timelineSource.Contains(
                "Math.Abs(pointerY - startY)",
                StringComparison.Ordinal) &&
            !timelineSource.Contains(
                "Math.Abs(pointerY - endY)",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "只画长条头部的方块，面身和尾巴不画。",
                StringComparison.Ordinal);
        return Result(
            "windows-hidden-ln-body-renders-only-border-colored-head-note",
            passed,
            "head=normal Note with 3-DIP soft purple border; body/tail hidden; " +
            "only the visible head remains clickable");
    }

    private static WindowsEditorSurfaceParitySpecResult VerifyImeDuplicateCommitGuardHook()
    {
        var mainWindowSource = ReadMainWindowSource();
        var passed =
            mainWindowSource.Contains(
                "InputElement.TextInputEvent,",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "imeDuplicateCommitGuard.ObserveKeyDown(",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "imeDuplicateCommitGuard.ShouldSuppressReplay(",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "eventArgs.Handled = true;",
                StringComparison.Ordinal);
        return Result(
            "windows-wechat-ime-shift-replay-is-filtered-before-textbox-insertion",
            passed,
            "first composed TextInput is retained; exact per-character replay is handled in tunnel");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyHoldInteractionChromeMatchesWpf()
    {
        var style = WindowsTimelineVisualParityPolicy.HoldInteractionStyle;
        var source = ReadProjectSource(
            "LumaChart.Avalonia",
            "Controls",
            "TimelineSurface.cs");
        var placementPreview = Between(
            source,
            "private void DrawPlacementPreview(",
            "private Rect GetNoteBounds(");
        var tailPreview = Between(
            source,
            "private void DrawHoldTailResizePreview(",
            "private void DrawPlacementPreview(");
        var passed =
            style == new WindowsTimelineHoldInteractionStyle(true, .94, 7) &&
            placementPreview.Contains(
                "DrawHoldInteractionPreview(",
                StringComparison.Ordinal) &&
            tailPreview.Contains(
                "DrawHoldInteractionPreview(",
                StringComparison.Ordinal) &&
            source.Contains(
                "DrawLongNote(",
                StringComparison.Ordinal) &&
            !placementPreview.Contains(
                "HoldPreviewBrush",
                StringComparison.Ordinal) &&
            !tailPreview.Contains(
                "HoldTailPreviewBrush",
                StringComparison.Ordinal);
        return Result(
            "windows-ln-drag-and-tail-resize-use-final-wpf-note-chrome",
            passed,
            $"finalChrome={style.UseFinalLongNoteChrome}; " +
            $"opacity={style.Opacity:0.00}; tailInset={style.TailLineInset:0}");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyWheelDirectionMatchesWpf()
    {
        var up =
            WindowsTimelineVisualParityPolicy.ResolveWheelDirection(120);
        var down =
            WindowsTimelineVisualParityPolicy.ResolveWheelDirection(-120);
        var idle =
            WindowsTimelineVisualParityPolicy.ResolveWheelDirection(0);
        return Result(
            "windows-timeline-wheel-direction-matches-wpf",
            up == 1 && down == -1 && idle == 0,
            $"up={up}; down={down}; idle={idle}");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyTimelineGridHierarchyMatchesWpf()
    {
        var irregular = WindowsTimelineVisualParityPolicy.ResolveGridLineStyle(
            WindowsTimelineGridLineKind.Irregular);
        var quarter = WindowsTimelineVisualParityPolicy.ResolveGridLineStyle(
            WindowsTimelineGridLineKind.Quarter);
        var sixth = WindowsTimelineVisualParityPolicy.ResolveGridLineStyle(
            WindowsTimelineGridLineKind.Sixth);
        var half = WindowsTimelineVisualParityPolicy.ResolveGridLineStyle(
            WindowsTimelineGridLineKind.Half);
        var beat = WindowsTimelineVisualParityPolicy.ResolveGridLineStyle(
            WindowsTimelineGridLineKind.Beat);
        var bar = WindowsTimelineVisualParityPolicy.ResolveGridLineStyle(
            WindowsTimelineGridLineKind.Bar);
        var configuredIrregular =
            WindowsTimelineVisualParityPolicy.ResolveConfiguredGridLineThickness(
                WindowsTimelineGridLineKind.Irregular,
                1.6,
                3.25);
        var configuredQuarter =
            WindowsTimelineVisualParityPolicy.ResolveConfiguredGridLineThickness(
                WindowsTimelineGridLineKind.Quarter,
                1.6,
                3.25);
        var configuredBeat =
            WindowsTimelineVisualParityPolicy.ResolveConfiguredGridLineThickness(
                WindowsTimelineGridLineKind.Beat,
                1.6,
                3.25);
        var configuredBar =
            WindowsTimelineVisualParityPolicy.ResolveConfiguredGridLineThickness(
                WindowsTimelineGridLineKind.Bar,
                1.6,
                3.25);
        var passed =
            WindowsTimelineVisualParityPolicy.ResolveGridLineKind(4, 0) ==
            WindowsTimelineGridLineKind.Bar &&
            WindowsTimelineVisualParityPolicy.ResolveGridLineKind(4, 4) ==
            WindowsTimelineGridLineKind.Beat &&
            WindowsTimelineVisualParityPolicy.ResolveGridLineKind(4, 2) ==
            WindowsTimelineGridLineKind.Half &&
            WindowsTimelineVisualParityPolicy.ResolveGridLineKind(4, 1) ==
            WindowsTimelineGridLineKind.Quarter &&
            WindowsTimelineVisualParityPolicy.ResolveGridLineKind(6, 1) ==
            WindowsTimelineGridLineKind.Sixth &&
            WindowsTimelineVisualParityPolicy.ResolveGridLineKind(8, 1) ==
            WindowsTimelineGridLineKind.Irregular &&
            irregular == new WindowsTimelineGridLineStyle("#765A6266", .8) &&
            quarter == new WindowsTimelineGridLineStyle("#A8A96552", 1) &&
            sixth == new WindowsTimelineGridLineStyle("#A777679C", 1) &&
            half == new WindowsTimelineGridLineStyle("#B06E8792", 1) &&
            beat == new WindowsTimelineGridLineStyle("#B7929A9F", 1.25) &&
            bar == new WindowsTimelineGridLineStyle("#D0C2B5A3", 1.55) &&
            Math.Abs(configuredIrregular - 1.6) < 1e-12 &&
            Math.Abs(configuredQuarter - 2) < 1e-12 &&
            Math.Abs(configuredBeat - 2.5) < 1e-12 &&
            Math.Abs(configuredBar - 3.25) < 1e-12;
        return Result(
            "windows-timeline-grid-hierarchy-and-colors-match-wpf",
            passed,
            $"kinds=bar/beat/half/quarter/sixth/irregular; " +
            $"colors={bar.Color}/{beat.Color}/{half.Color}/" +
            $"{quarter.Color}/{sixth.Color}/{irregular.Color}; configured=" +
            $"{configuredBar:0.00}/{configuredBeat:0.00}/" +
            $"{configuredQuarter:0.00}/{configuredIrregular:0.00}");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyTimelineMeasureNumbersMatchWpf()
    {
        var source = ReadProjectSource(
            "LumaChart.Avalonia",
            "Controls",
            "TimelineSurface.cs");
        var passed =
            WindowsTimelineVisualParityPolicy.ResolveMeasureNumber(4, 0) == 1 &&
            WindowsTimelineVisualParityPolicy.ResolveMeasureNumber(4, 4) == 2 &&
            WindowsTimelineVisualParityPolicy.ResolveMeasureNumber(4, 1396) == 350 &&
            WindowsTimelineVisualParityPolicy.ResolveMeasureNumber(4, 1397) == null &&
            source.Contains(
                "Matrix.CreateRotation(-Math.PI / 2)",
                StringComparison.Ordinal) &&
            source.Contains(
                "geometry.TrackLeft - MeasureNumberRailWidth",
                StringComparison.Ordinal);
        return Result(
            "windows-timeline-shows-rotated-measure-numbers-left-of-grid",
            passed,
            "whole beats use the one-based beat number Malody's own editor shows " +
            "(the same number the Note/Timing boxes print, so the rail label is " +
            "what a mapper types back); the stored index is zero-based and is not " +
            "what the rail prints; subdivision omitted; rotated left rail reserves " +
            "space from Timing labels");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyPlaybackHoverCannotEnterSeekPipeline()
    {
        var source = ReadMainWindowSource();
        var passed =
            source.Contains(
                "timeline.HoverChanged += (_, status) => statusText.Text = status;",
                StringComparison.Ordinal) &&
            !source.Contains(
                "timeline.HoverChanged += (_, status) => viewModel.SetStatus(status);",
                StringComparison.Ordinal) &&
            source.Contains(
                "SetProgrammaticPlaybackBeat(activeTab.CurrentBeat);",
                StringComparison.Ordinal);
        return Result(
            "windows-playback-hover-is-ui-only-and-programmatic-refresh-cannot-seek",
            passed,
            "hover→statusText only; UpdateUi beat write is guarded as programmatic");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyManualTimelineNavigationPausesPlayback()
    {
        var mainWindowSource = ReadMainWindowSource();
        var timelineSource = ReadProjectSource(
            "LumaChart.Avalonia",
            "Controls",
            "TimelineSurface.cs");
        var queueSeek = Between(
            mainWindowSource,
            "private bool QueueEditorSeek(",
            "private void UpdatePendingEditorSeekTarget(");
        var passed =
            timelineSource.Contains(
                "ManualNavigationRequested?.Invoke(",
                StringComparison.Ordinal) &&
            timelineSource.Contains(
                "SetCurrentBeatFromManualNavigation(",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "timeline.ManualNavigationRequested += Timeline_ManualNavigationRequested;",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "PauseEditorPlaybackForManualNavigationAsync()",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "resumeAfterSeek: DateTimeOffset.UtcNow > editorSeekResumeSuppressedUntilUtc",
                StringComparison.Ordinal) &&
            queueSeek.Contains(
                "if (!resumeAfterSeek) editorSeekResumeRequested = false;",
                StringComparison.Ordinal) &&
            queueSeek.Contains(
                "resumeAfterSeek && (musicWasPlaying || usesSilent)",
                StringComparison.Ordinal);
        return Result(
            "windows-wheel-and-pointer-navigation-pause-without-resuming-playback",
            passed,
            "wheel/pan emits manual navigation; pending seeks suppress resume; " +
            "non-beat scroll modes pause directly");
    }

    private static WindowsEditorSurfaceParitySpecResult VerifyRoomChatPanelClampIsWired()
    {
        var source = ReadMainWindowSource();
        var queuedClamp = Between(
            source,
            "private void QueueFloatingPaletteClamp()",
            "private void SeparateFloatingPalettesIfNeeded()");
        var visibility = Between(
            source,
            "private void RefreshRoomCollaborationPanelVisibility()",
            "private bool IsRoomChatActivelyVisible()");
        var passed =
            queuedClamp.Contains(
                "ClampRoomCollaborationPosition();",
                StringComparison.Ordinal) &&
            visibility.Contains(
                "if (visible) QueueFloatingPaletteClamp();",
                StringComparison.Ordinal) &&
            source.Contains(
                "roomCollaborationPanel.SizeChanged += (_, _) => QueueFloatingPaletteClamp();",
                StringComparison.Ordinal) &&
            source.Contains(
                "ApplyRoomCollaborationCollapsedState();",
                StringComparison.Ordinal);
        return Result(
            "windows-room-chat-panel-keeps-draggable-header-in-workbench",
            passed,
            "clamped after resize, reveal, collapse and expansion");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyChartExportDefaultsToDownloads()
    {
        var source = ReadMainWindowSource();
        var resolver = Between(
            source,
            "private async Task<IStorageFolder?> ResolveChartExportStartLocationAsync(",
            "private Task RevealExportedFileAsync(");
        var passed =
            source.Contains(
                "SuggestedStartLocation = exportStartLocation",
                StringComparison.Ordinal) &&
            resolver.Contains(
                "WellKnownFolder.Downloads",
                StringComparison.Ordinal) &&
            resolver.Contains(
                "Environment.SpecialFolder.UserProfile",
                StringComparison.Ordinal);
        return Result(
            "windows-chart-export-picker-defaults-to-downloads",
            passed,
            "Windows Downloads known folder; conventional Downloads fallback; " +
            "source directory used only when Downloads cannot be resolved");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyCompactOnlineSurfacesAreWired()
    {
        var source = ReadMainWindowSource();
        var quickButton = Between(
            source,
            "private static Button QuickPaletteButton(",
            "private void RegisterQuickShortcutButton(");
        var quickValueButton = Between(
            source,
            "private static Button QuickValueButton(",
            "private static void ConfigureQuickValueText(");
        var roomPoll = Between(
            source,
            "private async Task RunOnlineRoomPresenceLoopAsync(",
            "private void ApplyOnlineRoomLiveState(");
        var passed =
            source.Contains(
                "async (_, _) => await ToggleFriendsPanelAsync()",
                StringComparison.Ordinal) &&
            source.Contains(
                "private Control BuildFriendsPanel()",
                StringComparison.Ordinal) &&
            source.Contains(
                "private Control BuildRoomCollaborationPanel()",
                StringComparison.Ordinal) &&
            roomPoll.Contains(
                "GetRoomLiveStateAsync(",
                StringComparison.Ordinal) &&
            roomPoll.Contains(
                "roomChartSyncRoomId == roomId ? latestRoomMessageId : 0",
                StringComparison.Ordinal) &&
            !roomPoll.Contains(
                "SendRoomHeartbeatAsync(",
                StringComparison.Ordinal) &&
            source.Contains(
                "roomChatUnreadDot.IsVisible = unread;",
                StringComparison.Ordinal) &&
            source.Contains(
                "editorWorkbench.SizeChanged += (_, _) => QueueFloatingPaletteClamp();",
                StringComparison.Ordinal) &&
            source.Contains(
                "ClampFloatingControl(quickValuesPalette, quickValuesPaletteTransform);",
                StringComparison.Ordinal) &&
            quickButton.Contains("Width = 84", StringComparison.Ordinal) &&
            quickButton.Contains(
                "TextAlignment = TextAlignment.Center",
                StringComparison.Ordinal) &&
            quickValueButton.Contains(
                "BorderBrush = Brushes.Transparent",
                StringComparison.Ordinal) &&
            quickValueButton.Contains(
                "Height = WindowsInspectorParityPolicy.QuickValuesControlHeight",
                StringComparison.Ordinal) &&
            quickValueButton.Contains(
                "VerticalContentAlignment = VerticalAlignment.Center",
                StringComparison.Ordinal) &&
            !quickValueButton.Contains(
                "BorderBrush = StrokeBrush",
                StringComparison.Ordinal);
        return Result(
            "windows-compact-friends-room-chat-and-centered-palettes-wired",
            passed,
            "friends=compact overlay; room=draggable chat+unread; " +
            "quickEdit=centered grid; quickValues=transparent idle borders");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyQuickValueAdjustmentsRestoreTimelineFocus()
    {
        var source = ReadMainWindowSource();
        var quickValueSection = Between(
            source,
            "private Control BuildQuickValueSection(",
            "private static Button QuickValueButton(");
        var passed =
            quickValueSection.Contains(
                "increaseButton.Click += (_, _) => timeline.Focus();",
                StringComparison.Ordinal) &&
            quickValueSection.Contains(
                "decreaseButton.Click += (_, _) => timeline.Focus();",
                StringComparison.Ordinal);
        return Result(
            "windows-quick-value-adjustments-return-focus-to-timeline",
            passed,
            "snap/grid/rate arrow clicks restore timeline focus before Space transport");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyPlaybackChromeAndInspectorFitAreWired()
    {
        var source = ReadMainWindowSource();
        var cancelSeek = Between(
            source,
            "private Task CancelPendingEditorSeek()",
            "private void SetProgrammaticPlaybackBeat(");
        var passed =
            source.Contains(
                "new DispatcherTimer(DispatcherPriority.Normal)",
                StringComparison.Ordinal) &&
            cancelSeek.Contains("return pauseTask.IsCompletedSuccessfully", StringComparison.Ordinal) &&
            !cancelSeek.Contains("Task.WhenAll(pauseTask, commitTask)", StringComparison.Ordinal) &&
            source.Contains("private AvaloniaPath? quickPlayIcon;", StringComparison.Ordinal) &&
            source.Contains(
                "\"M2,1 H6 V16 H2 Z M10,1 H14 V16 H10 Z\"",
                StringComparison.Ordinal) &&
            source.Contains(
                "Data = Geometry.Parse(\"M2,2 L11,11 M11,2 L2,11\")",
                StringComparison.Ordinal) &&
            source.Contains(
                "ConstrainInspectorSlider(audioVolumeSlider);",
                StringComparison.Ordinal) &&
            source.Contains(
                "ApplyWpfPrimaryButtonStyle(check);",
                StringComparison.Ordinal) &&
            !source.Contains("proGridColumnSlider.Width = 104;", StringComparison.Ordinal);
        return Result(
            "windows-playback-command-chrome-and-inspector-fit-regressions-wired",
            passed,
            "seek cancellation nonblocking; play/pause+tab icons explicit; " +
            "settings sliders constrained; update accent; ProEditor slider stretches");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyNavigationMarkersAreWired()
    {
        var source = ReadMainWindowSource();
        var overview = ReadProjectSource(
            "LumaChart.Avalonia",
            "Controls",
            "EditorOverviewSurface.cs");
        var firstId = Guid.Parse("00000000-0000-0000-0000-000000000001");
        var secondId = Guid.Parse("00000000-0000-0000-0000-000000000002");
        var duplicateId = Guid.Parse("00000000-0000-0000-0000-000000000003");
        var early = new DesktopNavigationMarker(
            secondId,
            BeatPosition.Preserve(1, 0, 1));
        var late = new DesktopNavigationMarker(
            firstId,
            BeatPosition.Preserve(4, 1, 2));
        var duplicate = new DesktopNavigationMarker(
            duplicateId,
            BeatPosition.Preserve(1, 0, 2));
        var normalized = WindowsNavigationMarkerPolicy.Normalize(
            [late, duplicate, early]);
        var added = WindowsNavigationMarkerPolicy.Add(
            normalized,
            new DesktopNavigationMarker(
                Guid.Parse("00000000-0000-0000-0000-000000000004"),
                BeatPosition.Preserve(7, 0, 1)),
            out var duplicateAdd);
        var full = Enumerable.Range(0, WindowsNavigationMarkerPolicy.MaximumMarkers)
            .Select(index => new DesktopNavigationMarker(
                Guid.NewGuid(),
                BeatPosition.Preserve(index, 0, 1)))
            .ToArray();
        var capped = WindowsNavigationMarkerPolicy.Add(
            full,
            new DesktopNavigationMarker(
                Guid.Parse("00000000-0000-0000-0000-000000000005"),
                BeatPosition.Preserve(100, 0, 1)),
            out var fullDuplicate);
        var removed = WindowsNavigationMarkerPolicy.Remove(
            added,
            firstId);
        var passed =
            normalized.Count == 2 &&
            normalized[0].Beat.Equals(early.Beat) &&
            normalized[1].Beat.Equals(late.Beat) &&
            !duplicateAdd &&
            added.Count == 3 &&
            !fullDuplicate &&
            capped.Count == WindowsNavigationMarkerPolicy.MaximumMarkers &&
            !capped.Any(marker => marker.Beat.Value == 100) &&
            removed.All(marker => marker.Id != firstId) &&
            source.Contains("BuildNavigationMarkerPopup()", StringComparison.Ordinal) &&
            source.Contains(
                "NavigationMarkerSeekRequested += beat",
                StringComparison.Ordinal) &&
            source.Contains(
                "editorOverview.SetNavigationMarkers(activeTab.NavigationMarkers)",
                StringComparison.Ordinal) &&
            source.Contains(
                "PersistPendingNavigationMarkersAsync(force: true)",
                StringComparison.Ordinal) &&
            overview.Contains(
                "NavigationMarkerSeekRequested",
                StringComparison.Ordinal) &&
            overview.Contains(
                "context.DrawEllipse(",
                StringComparison.Ordinal) &&
            overview.Contains(
                "marker.Value.Beat",
                StringComparison.Ordinal);
        return Result(
            "windows-navigation-markers-are-local-exact-and-bounded",
            passed,
            $"normalized={normalized.Count}; added={added.Count}; capped={capped.Count}; " +
            $"removed={removed.Count}; exact-seek={overview.Contains(
                "NavigationMarkerSeekRequested",
                StringComparison.Ordinal)}");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyLargeLibraryStartupStaysResponsive()
    {
        var mainWindow = ReadMainWindowSource();
        var viewModel = ReadProjectSource(
            "LumaChart.Avalonia",
            "ViewModels",
            "MainWindowViewModel.cs");
        var collection = new BatchObservableCollection<int>();
        var notifications = 0;
        NotifyCollectionChangedAction? lastAction = null;
        collection.CollectionChanged += (_, eventArgs) =>
        {
            notifications++;
            lastAction = eventArgs.Action;
        };
        collection.ReplaceAll(Enumerable.Range(0, 4_096));
        var passed =
            collection.Count == 4_096 &&
            notifications == 1 &&
            lastAction == NotifyCollectionChangedAction.Reset &&
            mainWindow.Contains(
                "scanLibrary: !deferInitialLibraryScan",
                StringComparison.Ordinal) &&
            mainWindow.Contains(
                "StartDeferredLibraryScan,",
                StringComparison.Ordinal) &&
            mainWindow.Contains(
                "viewModel.CancelLibraryScan();",
                StringComparison.Ordinal) &&
            viewModel.Contains(
                "libraryEntries.ReplaceAll(entries);",
                StringComparison.Ordinal) &&
            viewModel.Contains(
                "libraryFolders.ReplaceAll(folders);",
                StringComparison.Ordinal);
        return Result(
            "windows-large-library-startup-defers-scan-and-batches-ui-notifications",
            passed,
            $"entries={collection.Count}; notifications={notifications}; action={lastAction}");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyRoomUploadAndActualAvatarsAreWired()
    {
        var source = ReadMainWindowSource();
        var upload = Between(
            source,
            "private async Task InitializeOwnedRoomChartAsync(",
            "private void ApplyInitialRoomSnapshot(");
        var passed =
            source.Contains(
                "\"RoomUpload.Progress.Popup\"",
                StringComparison.Ordinal) &&
            source.Contains(
                "\"RoomUpload.Progress.Bar\"",
                StringComparison.Ordinal) &&
            upload.Contains(
                "ShowRoomUploadProgress(room.Id, room.Name, package);",
                StringComparison.Ordinal) &&
            upload.Contains(
                "UpdateRoomUploadProgress(room.Id, value);",
                StringComparison.Ordinal) &&
            upload.Contains(
                "await HideRoomUploadProgressAsync(room.Id, uploadSucceeded);",
                StringComparison.Ordinal) &&
            source.Contains(
                "private readonly WindowsDefaultUserAvatar titleUserAvatar",
                StringComparison.Ordinal) &&
            source.Contains(
                "BindRemoteAvatar(titleUserAvatar,",
                StringComparison.Ordinal) &&
            source.Contains(
                "BindRemoteAvatar(memberAvatar, member.AvatarKey, member.DisplayName);",
                StringComparison.Ordinal) &&
            source.Contains(
                "BindRemoteAvatar(messageAvatar, message.AvatarKey, message.DisplayName);",
                StringComparison.Ordinal);
        return Result(
            "windows-room-create-upload-progress-and-real-avatars-wired",
            passed,
            "create upload exposes byte progress popup; title/member/chat bind AvatarKey");
    }

    private static WindowsEditorSurfaceParitySpecResult
        VerifyLoginLibraryAndPlayerListRegressionsAreWired()
    {
        var main = ReadMainWindowSource();
        var login = ReadProjectSource(
            "LumaChart.Avalonia",
            "Dialogs",
            "OnlineAccountDialog.cs");
        var community = ReadProjectSource(
            "LumaChart.Avalonia",
            "Dialogs",
            "OnlineCommunityDialog.cs");
        var libraryCard = ReadProjectSource(
            "LumaChart.Avalonia",
            "Controls",
            "LibraryFolderCard.cs");
        var passed =
            login.Contains(
                "HorizontalAlignment = HorizontalAlignment.Center",
                StringComparison.Ordinal) &&
            login.Contains(
                "TextAlignment = TextAlignment.Center",
                StringComparison.Ordinal) &&
            login.Contains(
                "text.Padding = new Thickness(12, 0);",
                StringComparison.Ordinal) &&
            login.Contains(
                "text.VerticalContentAlignment = VerticalAlignment.Center;",
                StringComparison.Ordinal) &&
            main.Contains(
                "MaxWidth = WindowsInspectorParityPolicy.NoteHintMaximumWidth",
                StringComparison.Ordinal) &&
            community.Contains(
                "ApplyPlayerDirectoryListStyles(directoryList);",
                StringComparison.Ordinal) &&
            main.Contains(
                "ApplyCompactPlayerListStyles(roomMemberList);",
                StringComparison.Ordinal) &&
            libraryCard.Contains(
                "SynchronizeCurrentViewFromContainer();",
                StringComparison.Ordinal) &&
            libraryCard.Contains(
                ".Content as DesktopLibraryFolderView;",
                StringComparison.Ordinal);
        return Result(
            "windows-login-note-library-and-player-list-regressions-wired",
            passed,
            "login identity+inputs centered; Note hint bounded; player selection themed; " +
            "recycled library card synchronizes before first click");
    }

    /// <summary>
    /// Two things that are easy to regress by accident. A group preset is a whole
    /// grouping scheme, not a drawer over one list: the panel reads it as browser
    /// tabs — one scheme on screen, the row sitting under the inspector's own tabs
    /// and styled with their palette, right-clicking a tab renaming it where it
    /// sits without a rebuild — and switching one re-groups the chart *and* swaps
    /// the panel over to that scheme's own group roster, so the active scheme
    /// belongs in the panel signature, the rows have to be filtered by the scheme
    /// on screen, a group made under a scheme has to join that scheme only, and
    /// the command has to hand the document's grouping back to the scheme it came
    /// from before it writes the new one. And a sticky note has to be writable
    /// where it sits: the surface draws its own cards and cannot own a text box,
    /// so it reports the card's last rendered bounds and the window floats an
    /// editor over that spot.
    /// </summary>
    private static WindowsEditorSurfaceParitySpecResult
        VerifyPresetDrawersAndInlineAnnotationEditorAreWired()
    {
        var mainWindowSource = ReadMainWindowSource();
        var timelineSource = ReadProjectSource(
            "LumaChart.Avalonia",
            "Controls",
            "TimelineSurface.cs");
        var commandSource = ReadProjectSource(
            "LumaChart.Avalonia",
            "Editing",
            "WindowsGroupManagerCommand.cs");
        var storeSource = ReadProjectSource(
            "LumaChart.Avalonia",
            "Infrastructure",
            "WindowsGroupCatalogStore.cs");
        var tabBody = Between(
            mainWindowSource,
            "private Control BuildPresetTab(",
            "return button;");
        var renameBody = Between(
            mainWindowSource,
            "private void BeginPresetRename(int preset)",
            "private void CancelPresetRename()");
        // Which scheme is on screen decides how the whole chart reads, so the
        // command has to snapshot the outgoing scheme before it writes the
        // incoming one — otherwise the first scheme would lose the grouping that
        // was on screen the moment it is left.
        var setActiveBody = Between(
            commandSource,
            "public static bool SetActivePreset(DesktopChartTab tab, int? presetId)",
            "public static bool ApplyActivePreset(DesktopChartTab tab)");
        var applyBody = Between(
            commandSource,
            "public static bool ApplyActivePreset(DesktopChartTab tab)",
            "public static bool RenamePreset(");
        var removePresetBody = Between(
            commandSource,
            "public static bool RemovePreset(DesktopChartTab tab, int presetId)",
            "public static bool AdoptPresetForLoadedChart(DesktopChartTab tab)");
        var adoptBody = Between(
            commandSource,
            "public static bool AdoptPresetForLoadedChart(DesktopChartTab tab)",
            "public static WindowsGroupMutationResult Dissolve(");
        var panelRowsBody = Between(
            mainWindowSource,
            "private static List<WindowsGroupManagerRow> GroupPanelRows(",
            "private bool RebuildGroupPanel(");
        // UpdateUi runs on every state change, and a status line is a state
        // change. It used to force a group-panel rebuild on the way through,
        // which put the panel back to its label form inside the same call that
        // swapped the rename box in: the mapper pressed 重命名 and nothing
        // happened, and any half-typed group name lost the caret with it.
        var updateUiBody = Between(
            mainWindowSource,
            "private void UpdateUi()",
            "private void RequestMissingAudioRecovery(");
        var drawersAreTabs =
            mainWindowSource.Contains(
                "private static List<WindowsGroupManagerRow> GroupPanelRows(",
                StringComparison.Ordinal) &&
            // The panel lists a scheme's own groups, not every group that exists:
            // a group made under 按音轨 must not still be sitting in the list after
            // switching to 按手感, which never used it. 未分组 and any group notes
            // are actually carrying are the two exceptions, because a row that is
            // invisible while its notes are on screen is how work gets lost.
            panelRowsBody.Contains(
                "if (tab.GroupCatalog.VisibleGroupIds() is not { } owned) return [.. snapshot.Rows];",
                StringComparison.Ordinal) &&
            panelRowsBody.Contains(
                "row.Group == 0 || owned.Contains(row.Group) || onNotes.Contains(row.Group)",
                StringComparison.Ordinal) &&
            // And the roster only changes when the panel is rebuilt, so the rows
            // fed into the signature have to be the filtered ones.
            mainWindowSource.Contains(
                "var rows = GroupPanelRows(tab, snapshot);",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "var signature = BuildGroupPanelSignature(tab, rows);",
                StringComparison.Ordinal) &&
            // A group is born into the scheme on screen — both when it is made
            // and when it is merely put into use — and a new scheme is a copy of
            // that scheme's roster rather than of the whole catalog.
            commandSource.Contains(
                "tab.GroupCatalog.AdoptGroups(tab.ActiveGroupPreset, [group]);",
                StringComparison.Ordinal) &&
            commandSource.Contains(
                "tab.GroupCatalog.AdoptGroups(id, TemplateGroupIds(tab));",
                StringComparison.Ordinal) &&
            // 使用 targets a group of the reading on screen, so a scheme that does
            // not list it takes the target back to 未分组 instead of leaving the
            // panel highlighting a row that is no longer listed.
            setActiveBody.Contains("DropPlacementOutOfScheme(tab);", StringComparison.Ordinal) &&
            // Deleting a scheme must not write the chart's grouping into the next
            // scheme in line: that would overwrite a reading the mapper never
            // deleted. Nothing happens to the chart at all.
            !removePresetBody.Contains("CaptureActivePreset", StringComparison.Ordinal) &&
            !removePresetBody.Contains("ApplyActivePreset", StringComparison.Ordinal) &&
            // Adopting on load writes the chart's grouping into a scheme, so it
            // has to refuse a scheme that already has a table of its own.
            adoptBody.Contains(
                "preset.Assignments.Count == 0",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "groupPresetTabStrip.Children.Add(BuildPresetTab(",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "() => button.BringIntoView()",
                StringComparison.Ordinal) &&
            // The open scheme decides how the chart reads, and its note count is
            // rendered into the tab, so it has to force a rebuild — switching
            // schemes has to change the panel even when no group was touched.
            mainWindowSource.Contains(
                "(tab.ActiveGroupPreset ?? 0)",
                StringComparison.Ordinal) &&
            // The tab row is page chrome under the inspector's own tabs, not
            // content of the page: it is the first row of the 分组 page and sits
            // outside that page's scroller.
            mainWindowSource.Contains(
                "private Control BuildGroupInspectorPage(Control groupManager)",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "Grid.SetRow(BuildPresetTabBar(), 0);",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "BuildGroupInspectorPage(BuildGroupManager())",
                StringComparison.Ordinal) &&
            // Styled with the WPF 1.1.0 tab palette, so the two rows read as one
            // control: selected plate, 2-DIP accent underline, hover wash.
            mainWindowSource.Contains(
                "private static void ApplyPresetTabAppearance(",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "BorderThickness = new Thickness(0, 0, 0, 2)",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "PresetTabHoverBrush",
                StringComparison.Ordinal) &&
            // Right-click has to be caught on the way down: a Button consumes the
            // press itself, so a plain bubble handler never sees it.
            tabBody.Contains("RoutingStrategies.Tunnel", StringComparison.Ordinal) &&
            tabBody.Contains("IsRightButtonPressed", StringComparison.Ordinal) &&
            tabBody.Contains("BeginPresetRename(preset)", StringComparison.Ordinal) &&
            // Renaming swaps one tab's content and rebuilds nothing. A rebuild
            // detaches the box, and the commit raised by that detach would
            // rebuild the strip from inside the rebuild still running — which is
            // what left a second copy of every tab on the strip.
            mainWindowSource.Contains(
                "private TextBox BuildPresetRenameBox(",
                StringComparison.Ordinal) &&
            renameBody.Contains("host.Content = box;", StringComparison.Ordinal) &&
            !renameBody.Contains("RefreshGroupPanel", StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "private void ClosePresetRenameBox()",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "FlushPresetRename();",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "if (rebuildingGroupPanel) return false;",
                StringComparison.Ordinal) &&
            // The signature is recorded only by a rebuild that actually ran. A
            // rebuild refused by the guard has to leave it alone, or the panel
            // believes it is showing a shape it never rendered.
            mainWindowSource.Contains(
                "if (RebuildGroupPanel(tab, snapshot)) groupPanelSignature = signature;",
                StringComparison.Ordinal) &&
            // A whole-refresh pass must not invalidate the panel: see above. The
            // body is proven to be the real one first, or an unmatched marker
            // would make this pass on an empty string.
            updateUiBody.Contains("RebuildTabs();", StringComparison.Ordinal) &&
            !updateUiBody.Contains("groupPanelSignature", StringComparison.Ordinal) &&
            // 重命名 answers a press with no scheme on screen by opening one
            // instead of refusing, so it may never be disabled into silence;
            // 删除 has no target there and is dimmed as well as disabled, because
            // the skin paints a disabled button like a live one.
            !mainWindowSource.Contains(
                "groupRenamePresetButton.IsEnabled",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "groupDeletePresetButton.Opacity = openScheme is not null ? 1 : 0.45;",
                StringComparison.Ordinal) &&
            !mainWindowSource.Contains(
                "groupPresetRenameTarget",
                StringComparison.Ordinal) &&
            // Switching schemes is the one preset action that edits the chart, so
            // it has to be a single document mutation the mapper can undo: the
            // outgoing scheme is snapshotted first, then the incoming scheme's
            // whole table is written over every note.
            setActiveBody.Contains("CaptureActivePreset(tab);", StringComparison.Ordinal) &&
            setActiveBody.Contains("return ApplyActivePreset(tab);", StringComparison.Ordinal) &&
            commandSource.Contains(
                "if (tab.ActiveGroupPreset is not { } preset) return;",
                StringComparison.Ordinal) &&
            applyBody.Contains("tab.Session.Mutate(", StringComparison.Ordinal) &&
            applyBody.Contains(
                "foreach (var note in document.Notes)",
                StringComparison.Ordinal) &&
            // A chart file only remembers the grouping, never which scheme it is
            // the answer to, so the active scheme has to be persisted beside it or
            // reopening would silently re-own the grouping.
            storeSource.Contains(
                "catalog.ActivePresetId = entry.ActiveGroupPresetId;",
                StringComparison.Ordinal) &&
            storeSource.Contains(
                "ActiveAnnotationPresetId = annotations?.ActivePresetId",
                StringComparison.Ordinal) &&
            // An annotation preset is a display filter, so both halves of the
            // screen have to honour it: the panel list and the timeline cards.
            mainWindowSource.Contains(
                "VisibleAnnotationIds = annotations.VisibleAnnotationIds(),",
                StringComparison.Ordinal) &&
            timelineSource.Contains(
                "var visibleAnnotations = groupVisuals.VisibleAnnotationIds;",
                StringComparison.Ordinal);
        var editsInPlace =
            timelineSource.Contains(
                "public event EventHandler<AnnotationEditRequestedEventArgs>? AnnotationEditRequested;",
                StringComparison.Ordinal) &&
            timelineSource.Contains(
                "AnnotationEditRequested?.Invoke(",
                StringComparison.Ordinal) &&
            timelineSource.Contains(
                "public bool TryGetAnnotationCardBounds(int annotation, out Rect bounds)",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "private void BuildAnnotationEditorOverlay()",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "OpenAnnotationEditor(eventArgs.Annotation, eventArgs.CardBounds);",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "annotationEditorBox.LostFocus += (_, _) => CloseAnnotationEditor();",
                StringComparison.Ordinal);
        // 解散 is one click in a row that also carries 使用 and ＋子, and its two
        // halves land in different places — the notes in the document, the group
        // itself in the editor's own catalog. It asks first, and the number it
        // quotes comes from the rule the command applies rather than a second
        // guess at it.
        var dissolveBody = Between(
            mainWindowSource,
            "private void DissolveGroup(int group)",
            "private bool TryReadGroupId(");
        var dissolveAsksFirst =
            dissolveBody.Contains(
                "private async Task DissolveGroupAsync(int group)",
                StringComparison.Ordinal) &&
            dissolveBody.Contains("new SettingsActionDialog(", StringComparison.Ordinal) &&
            dissolveBody.Contains("if (!confirmed) return;", StringComparison.Ordinal) &&
            dissolveBody.Contains(
                "WindowsGroupManagerCommand.DissolvableNoteCount(tab, group)",
                StringComparison.Ordinal) &&
            mainWindowSource.Contains(
                "var dissolve = PrimaryButton(\"解散\", (_, _) => DissolveGroup(group));",
                StringComparison.Ordinal);
        return Result(
            "windows-preset-tabs-read-one-scheme-and-sticky-notes-edit-in-place",
            drawersAreTabs && editsInPlace && dissolveAsksFirst,
            $"schemeTabs={drawersAreTabs}; inlineEditor={editsInPlace}; " +
            $"dissolveAsksFirst={dissolveAsksFirst}; " +
            $"renameInPlace={renameBody.Contains("host.Content = box;", StringComparison.Ordinal)}");
    }

    private static string ReadMainWindowSource()
    {
        var projectRoot = Path.GetFullPath(
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", ".."));
        return File.ReadAllText(
            Path.Combine(projectRoot, "LumaChart.Avalonia", "MainWindow.cs"));
    }

    private static string ReadProjectSource(params string[] segments)
    {
        var projectRoot = Path.GetFullPath(
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", ".."));
        return File.ReadAllText(
            Path.Combine([projectRoot, .. segments]));
    }

    private static string Between(
        string source,
        string startMarker,
        string endMarker)
    {
        var start = source.IndexOf(startMarker, StringComparison.Ordinal);
        var end = source.IndexOf(
            endMarker,
            Math.Max(0, start),
            StringComparison.Ordinal);
        return start >= 0 && end > start
            ? source[start..end]
            : string.Empty;
    }

    private static WindowsEditorSurfaceParitySpecResult Result(
        string name,
        bool passed,
        string detail) => new(name, passed, detail);
}

internal sealed record WindowsEditorSurfaceParitySpecResult(
    string Name,
    bool Passed,
    string Detail);
