using System.Text.Json;
using LumaChart.Core.Editing;

namespace LumaChart.Avalonia.Infrastructure;

public enum WindowsNoteAnchorMode
{
    GridLine,
    CellCenter,
    LineAbove,
    CellBottom
}

public enum WindowsFullscreenMode
{
    Windowed,
    Borderless
}

/// <summary>
/// Windows editor geometry and local-backup preferences expressed in effective
/// DIPs. The defaults and limits intentionally match WPF 1.1.0.
/// </summary>
public sealed class WindowsEditorViewSettings
{
    public const double DefaultGridLaneWidth = 84;
    public const double DefaultGridBeatHeight = 280;
    public const double DefaultNoteWidth = 77;
    public const double DefaultNoteHeight = 41;
    public const double DefaultJudgementLinePosition = .79;
    public const double DefaultJudgementLineThickness = 1.5;
    public const double DefaultJudgementLineOpacity = .85;
    public const double DefaultBarLineThickness = 2.2;
    public const double DefaultSubdivisionLineThickness = 1.6;
    public const double DefaultTrackOpacity = .7;
    public const int DefaultAutoBackupMinutes = 5;
    public const int DefaultSnapDivision = 4;
    public const int DefaultFixedSnapDivision = 16;
    public const int DefaultUnsnapScrollDivision = 8;
    public const int DefaultCurveDenseDivision = 16;
    public const int DefaultCurveSparseDivision = 1;
    public const CurveDensityShape DefaultCurveShape = CurveDensityShape.DenseSparseDense;
    public const CurveLaneArrangement DefaultCurveLaneOrder = CurveLaneArrangement.Single;
    public const double DefaultPlaybackRate = 1;
    public const double DefaultMusicVolume = .8;
    public const int DefaultFrameRateLimit = WindowsFrameRateOptions.Default;

    public WindowsEditorViewSettings(
        double gridLaneWidth = DefaultGridLaneWidth,
        double gridBeatHeight = DefaultGridBeatHeight,
        double mainEditorHorizontalOffset = 0,
        double noteWidth = DefaultNoteWidth,
        double noteHeight = DefaultNoteHeight,
        double noteOpacity = 1,
        double judgementLinePosition = DefaultJudgementLinePosition,
        double judgementLineThickness = DefaultJudgementLineThickness,
        double judgementLineOpacity = DefaultJudgementLineOpacity,
        bool autoBackupEnabled = true,
        int autoBackupMinutes = DefaultAutoBackupMinutes,
        double quickPaletteX = 0,
        double quickPaletteY = 0,
        bool quickPaletteCollapsed = false,
        double quickValuesPaletteX = 0,
        double quickValuesPaletteY = 0,
        bool quickValuesPaletteCollapsed = false,
        int snapDivision = DefaultSnapDivision,
        double playbackRate = DefaultPlaybackRate,
        double difficultyCardX = 0,
        double difficultyCardY = 0,
        bool difficultyCardCollapsed = false,
        int frameRateLimit = DefaultFrameRateLimit,
        WindowsNoteAnchorMode noteAnchor = WindowsNoteAnchorMode.CellBottom,
        double musicVolume = DefaultMusicVolume,
        bool preservePitch = false,
        WindowsFullscreenMode fullscreenMode = WindowsFullscreenMode.Windowed,
        double barLineThickness = DefaultBarLineThickness,
        double subdivisionLineThickness = DefaultSubdivisionLineThickness,
        int fixedSnapDivision = DefaultFixedSnapDivision,
        double trackOpacity = DefaultTrackOpacity,
        int unsnapScrollDivision = DefaultUnsnapScrollDivision,
        bool quickRangeCopy = false,
        int curveDenseDivision = DefaultCurveDenseDivision,
        int curveSparseDivision = DefaultCurveSparseDivision,
        CurveDensityShape curveShape = DefaultCurveShape,
        CurveLaneArrangement curveLaneOrder = DefaultCurveLaneOrder)
    {
        GridLaneWidth = Math.Clamp(FiniteOr(gridLaneWidth, DefaultGridLaneWidth), 32, 180);
        GridBeatHeight = Math.Clamp(FiniteOr(gridBeatHeight, DefaultGridBeatHeight), 24, 480);
        MainEditorHorizontalOffset = Math.Clamp(
            Math.Round(FiniteOr(mainEditorHorizontalOffset, 0)),
            -600,
            600);
        NoteWidth = Math.Clamp(FiniteOr(noteWidth, DefaultNoteWidth), 12, 172);
        NoteHeight = Math.Clamp(FiniteOr(noteHeight, DefaultNoteHeight), 8, 128);
        NoteOpacity = Math.Clamp(FiniteOr(noteOpacity, 1), .05, 1);
        JudgementLinePosition = Math.Clamp(
            FiniteOr(judgementLinePosition, DefaultJudgementLinePosition),
            .15,
            .95);
        JudgementLineThickness = Math.Clamp(
            FiniteOr(judgementLineThickness, DefaultJudgementLineThickness),
            .5,
            6);
        JudgementLineOpacity = Math.Clamp(
            FiniteOr(judgementLineOpacity, DefaultJudgementLineOpacity),
            .1,
            1);
        AutoBackupEnabled = autoBackupEnabled;
        AutoBackupMinutes = Math.Clamp(autoBackupMinutes, 1, 120);
        QuickPaletteX = Math.Clamp(Math.Round(FiniteOr(quickPaletteX, 0)), -4000, 4000);
        QuickPaletteY = Math.Clamp(Math.Round(FiniteOr(quickPaletteY, 0)), -4000, 4000);
        QuickPaletteCollapsed = quickPaletteCollapsed;
        QuickValuesPaletteX = Math.Clamp(
            Math.Round(FiniteOr(quickValuesPaletteX, 0)),
            -4000,
            4000);
        QuickValuesPaletteY = Math.Clamp(
            Math.Round(FiniteOr(quickValuesPaletteY, 0)),
            -4000,
            4000);
        QuickValuesPaletteCollapsed = quickValuesPaletteCollapsed;
        SnapDivision = snapDivision is >= 1 and <= 1920
            ? snapDivision
            : DefaultSnapDivision;
        PlaybackRate = double.IsFinite(playbackRate) && playbackRate is >= .2 and <= 1
            ? Math.Round(playbackRate, 2)
            : DefaultPlaybackRate;
        DifficultyCardX = Math.Clamp(Math.Round(FiniteOr(difficultyCardX, 0)), -4000, 4000);
        DifficultyCardY = Math.Clamp(Math.Round(FiniteOr(difficultyCardY, 0)), -4000, 4000);
        DifficultyCardCollapsed = difficultyCardCollapsed;
        FrameRateLimit = WindowsFrameRateOptions.Normalize(frameRateLimit);
        NoteAnchor = Enum.IsDefined(noteAnchor)
            ? noteAnchor
            : WindowsNoteAnchorMode.GridLine;
        MusicVolume = Math.Clamp(FiniteOr(musicVolume, DefaultMusicVolume), 0, 1);
        PreservePitch = preservePitch;
        FullscreenMode = Enum.IsDefined(fullscreenMode)
            ? fullscreenMode
            : WindowsFullscreenMode.Windowed;
        BarLineThickness = Math.Clamp(
            FiniteOr(barLineThickness, DefaultBarLineThickness),
            .5,
            6);
        SubdivisionLineThickness = Math.Clamp(
            FiniteOr(subdivisionLineThickness, DefaultSubdivisionLineThickness),
            .3,
            3);
        FixedSnapDivision = fixedSnapDivision is >= 1 and <= 1920
            ? fixedSnapDivision
            : DefaultFixedSnapDivision;
        TrackOpacity = Math.Clamp(FiniteOr(trackOpacity, DefaultTrackOpacity), 0, 1);
        UnsnapScrollDivision = unsnapScrollDivision is >= 1 and <= 1920
            ? unsnapScrollDivision
            : DefaultUnsnapScrollDivision;
        QuickRangeCopy = quickRangeCopy;
        CurveDenseDivision = curveDenseDivision is >= 1 and <= 1920
            ? curveDenseDivision
            : DefaultCurveDenseDivision;
        CurveSparseDivision = curveSparseDivision is >= 1 and <= 1920
            ? curveSparseDivision
            : DefaultCurveSparseDivision;
        CurveShape = Enum.IsDefined(curveShape) ? curveShape : DefaultCurveShape;
        CurveLaneOrder = Enum.IsDefined(curveLaneOrder)
            ? curveLaneOrder
            : DefaultCurveLaneOrder;
    }

    public static WindowsEditorViewSettings Default => new();

    public double GridLaneWidth { get; }
    public double GridBeatHeight { get; }
    public double MainEditorHorizontalOffset { get; }
    public double NoteWidth { get; }
    public double NoteHeight { get; }
    public double NoteOpacity { get; }
    public double JudgementLinePosition { get; }
    public double JudgementLineThickness { get; }
    public double JudgementLineOpacity { get; }
    public bool AutoBackupEnabled { get; }
    public int AutoBackupMinutes { get; }
    public double QuickPaletteX { get; }
    public double QuickPaletteY { get; }
    public bool QuickPaletteCollapsed { get; }
    public double QuickValuesPaletteX { get; }
    public double QuickValuesPaletteY { get; }
    public bool QuickValuesPaletteCollapsed { get; }
    public int SnapDivision { get; }
    public int FixedSnapDivision { get; }
    public double PlaybackRate { get; }
    public double DifficultyCardX { get; }
    public double DifficultyCardY { get; }
    public bool DifficultyCardCollapsed { get; }
    public int FrameRateLimit { get; }
    public WindowsNoteAnchorMode NoteAnchor { get; }
    public double MusicVolume { get; }
    public bool PreservePitch { get; }
    public WindowsFullscreenMode FullscreenMode { get; }
    public double BarLineThickness { get; }
    public double SubdivisionLineThickness { get; }
    public double TrackOpacity { get; }
    public int UnsnapScrollDivision { get; }
    public bool QuickRangeCopy { get; }
    /// <summary>Shortest gap of a generated density curve, as 1/N of a beat.</summary>
    public int CurveDenseDivision { get; }
    /// <summary>Longest gap of a generated density curve, as 1/N of a beat.</summary>
    public int CurveSparseDivision { get; }
    /// <summary>Density curve shape kept from the last toolbox run.</summary>
    public CurveDensityShape CurveShape { get; }
    /// <summary>How generated curve notes are spread over the lanes.</summary>
    public CurveLaneArrangement CurveLaneOrder { get; }

    public WindowsEditorViewSettings Normalize() => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithView(
        double gridLaneWidth,
        double gridBeatHeight,
        double mainEditorHorizontalOffset,
        double noteWidth,
        double noteHeight,
        double noteOpacity,
        double judgementLinePosition,
        double judgementLineThickness,
        double judgementLineOpacity) => new(
        gridLaneWidth,
        gridBeatHeight,
        mainEditorHorizontalOffset,
        noteWidth,
        noteHeight,
        noteOpacity,
        judgementLinePosition,
        judgementLineThickness,
        judgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithTrackOpacity(double opacity) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        opacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithAutoBackup(bool enabled, int minutes) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        enabled,
        minutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithQuickPalette(
        double x,
        double y,
        bool collapsed) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        x,
        y,
        collapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithQuickValuesPalette(
        double x,
        double y,
        bool collapsed) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        x,
        y,
        collapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithSnapDivision(int division) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        division,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithFixedSnapDivision(int division) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        division,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    /// <summary>
    /// The subdivision a wheel notch uses while the snap division is Un-snap.
    /// 1/1440 of a beat is thinner than a pixel, so stepping by it would move
    /// the playhead by nothing at all; this keeps scrolling usable there.
    /// </summary>
    public WindowsEditorViewSettings WithUnsnapScrollDivision(int division) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        division,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    /// <summary>
    /// When enabled, the copy shortcut marks one playhead position and copies
    /// every note between it and the second mark instead of copying the
    /// selection.
    /// </summary>
    public WindowsEditorViewSettings WithQuickRangeCopy(bool enabled) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        enabled,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    /// <summary>Shortest gap of a generated density curve, as 1/N of a beat.</summary>
    public WindowsEditorViewSettings WithCurveDenseDivision(int division) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        division,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    /// <summary>Longest gap of a generated density curve, as 1/N of a beat.</summary>
    public WindowsEditorViewSettings WithCurveSparseDivision(int division) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        division,
        CurveShape,
        CurveLaneOrder);

    /// <summary>Shape the density curve keeps for the next run.</summary>
    public WindowsEditorViewSettings WithCurveShape(CurveDensityShape shape) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        Enum.IsDefined(shape) ? shape : DefaultCurveShape,
        CurveLaneOrder);

    /// <summary>How the next generated curve spreads over the lanes.</summary>
    public WindowsEditorViewSettings WithCurveLaneOrder(CurveLaneArrangement order) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        Enum.IsDefined(order) ? order : DefaultCurveLaneOrder);

    public WindowsEditorViewSettings WithPlaybackRate(double rate) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        rate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithMusicVolume(double volume) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        volume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithPreservePitch(bool preservePitch) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        preservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithFullscreenMode(
        WindowsFullscreenMode fullscreenMode) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        fullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithDifficultyCard(
        double x,
        double y,
        bool collapsed) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        x,
        y,
        collapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings ResetFloatingLayout() =>
        WithQuickPalette(0, 0, collapsed: false)
            .WithQuickValuesPalette(0, 0, collapsed: false)
            .WithDifficultyCard(0, 0, collapsed: false);

    public WindowsEditorViewSettings WithFrameRateLimit(int frameRateLimit) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        frameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithNoteAnchor(
        WindowsNoteAnchorMode noteAnchor) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        noteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithBarLineThickness(double thickness) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        thickness,
        SubdivisionLineThickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    public WindowsEditorViewSettings WithSubdivisionLineThickness(double thickness) => new(
        GridLaneWidth,
        GridBeatHeight,
        MainEditorHorizontalOffset,
        NoteWidth,
        NoteHeight,
        NoteOpacity,
        JudgementLinePosition,
        JudgementLineThickness,
        JudgementLineOpacity,
        AutoBackupEnabled,
        AutoBackupMinutes,
        QuickPaletteX,
        QuickPaletteY,
        QuickPaletteCollapsed,
        QuickValuesPaletteX,
        QuickValuesPaletteY,
        QuickValuesPaletteCollapsed,
        SnapDivision,
        PlaybackRate,
        DifficultyCardX,
        DifficultyCardY,
        DifficultyCardCollapsed,
        FrameRateLimit,
        NoteAnchor,
        MusicVolume,
        PreservePitch,
        FullscreenMode,
        BarLineThickness,
        thickness,
        FixedSnapDivision,
        TrackOpacity,
        UnsnapScrollDivision,
        QuickRangeCopy,
        CurveDenseDivision,
        CurveSparseDivision,
        CurveShape,
        CurveLaneOrder);

    private static double FiniteOr(double value, double fallback) =>
        double.IsFinite(value) ? value : fallback;
}

/// <summary>
/// Atomic Avalonia-only persistence. It never reads or writes WPF's
/// view-settings.json while both clients remain installed side by side.
/// </summary>
public static class WindowsEditorViewSettingsStore
{
    public const int CurrentSchemaVersion = 1;
    private const string FileName = "editor-view-settings.json";
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true
    };

    public static string SettingsPath => Path.Combine(AvaloniaAppPaths.LocalDataRoot, FileName);

    public static WindowsEditorViewSettings Load()
    {
        string? path = null;
        try
        {
            path = SettingsPath;
            if (!WindowsSettingsFileGuard.TryReadExisting(path, out var bytes))
                return WindowsEditorViewSettings.Default;
            var persisted = JsonSerializer.Deserialize<PersistedSettings>(
                bytes,
                JsonOptions);
            return persisted?.SchemaVersion == CurrentSchemaVersion
                ? new WindowsEditorViewSettings(
                    persisted.GridLaneWidth,
                    persisted.GridBeatHeight,
                    persisted.MainEditorHorizontalOffset,
                    persisted.NoteWidth,
                    persisted.NoteHeight,
                    persisted.NoteOpacity,
                    persisted.JudgementLinePosition,
                    persisted.JudgementLineThickness,
                    persisted.JudgementLineOpacity,
                    persisted.AutoBackupEnabled,
                    persisted.AutoBackupMinutes,
                    persisted.QuickPaletteX,
                    persisted.QuickPaletteY,
                    persisted.QuickPaletteCollapsed,
                    persisted.QuickValuesPaletteX,
                    persisted.QuickValuesPaletteY,
                    persisted.QuickValuesPaletteCollapsed,
                    persisted.SnapDivision,
                    persisted.PlaybackRate,
                    persisted.DifficultyCardX,
                    persisted.DifficultyCardY,
                    persisted.DifficultyCardCollapsed,
                    persisted.FrameRateLimit,
                    persisted.NoteAnchor,
                    persisted.MusicVolume,
                    persisted.PreservePitch,
                    persisted.FullscreenMode,
                    persisted.BarLineThickness,
                    persisted.SubdivisionLineThickness,
                    persisted.FixedSnapDivision,
                    persisted.TrackOpacity,
                    persisted.UnsnapScrollDivision,
                    persisted.QuickRangeCopy,
                    persisted.CurveDenseDivision,
                    persisted.CurveSparseDivision,
                    Enum.TryParse<CurveDensityShape>(
                        persisted.CurveShape,
                        ignoreCase: true,
                        out var persistedShape)
                        ? persistedShape
                        : WindowsEditorViewSettings.DefaultCurveShape,
                    ResolveCurveLaneOrder(
                        persisted.CurveLaneOrder,
                        persisted.CurveSpreadAcrossLanes))
                : WindowsEditorViewSettings.Default;
        }
        catch (Exception exception)
        {
            if (path != null) WindowsSettingsFileGuard.ReportLoadFailure(path, exception);
            return WindowsEditorViewSettings.Default;
        }
    }

    /// <summary>
    /// Reads the arrangement by name. A file written before arrangements
    /// existed only has the spread flag, which maps onto the stairs walk.
    /// </summary>
    private static CurveLaneArrangement ResolveCurveLaneOrder(
        string? name,
        bool legacySpread) =>
        Enum.TryParse<CurveLaneArrangement>(name, ignoreCase: true, out var parsed) &&
        Enum.IsDefined(parsed)
            ? parsed
            : legacySpread
                ? CurveLaneArrangement.Stairs
                : CurveLaneArrangement.Single;

    public static void Save(WindowsEditorViewSettings settings)
    {
        ArgumentNullException.ThrowIfNull(settings);
        var normalized = settings.Normalize();
        var root = AvaloniaAppPaths.LocalDataRoot;
        var destination = Path.Combine(root, FileName);
        // An existing file that could not be read this session is kept intact.
        if (!WindowsSettingsFileGuard.CanWrite(destination)) return;
        Directory.CreateDirectory(root);
        var temporary = Path.Combine(root, $".{FileName}.{Guid.NewGuid():N}.tmp");
        try
        {
            var bytes = JsonSerializer.SerializeToUtf8Bytes(
                new PersistedSettings
                {
                    SchemaVersion = CurrentSchemaVersion,
                    GridLaneWidth = normalized.GridLaneWidth,
                    GridBeatHeight = normalized.GridBeatHeight,
                    MainEditorHorizontalOffset = normalized.MainEditorHorizontalOffset,
                    NoteWidth = normalized.NoteWidth,
                    NoteHeight = normalized.NoteHeight,
                    NoteOpacity = normalized.NoteOpacity,
                    JudgementLinePosition = normalized.JudgementLinePosition,
                    JudgementLineThickness = normalized.JudgementLineThickness,
                    JudgementLineOpacity = normalized.JudgementLineOpacity,
                    AutoBackupEnabled = normalized.AutoBackupEnabled,
                    AutoBackupMinutes = normalized.AutoBackupMinutes,
                    QuickPaletteX = normalized.QuickPaletteX,
                    QuickPaletteY = normalized.QuickPaletteY,
                    QuickPaletteCollapsed = normalized.QuickPaletteCollapsed,
                    QuickValuesPaletteX = normalized.QuickValuesPaletteX,
                    QuickValuesPaletteY = normalized.QuickValuesPaletteY,
                    QuickValuesPaletteCollapsed = normalized.QuickValuesPaletteCollapsed,
                    SnapDivision = normalized.SnapDivision,
                    FixedSnapDivision = normalized.FixedSnapDivision,
                    PlaybackRate = normalized.PlaybackRate,
                    DifficultyCardX = normalized.DifficultyCardX,
                    DifficultyCardY = normalized.DifficultyCardY,
                    DifficultyCardCollapsed = normalized.DifficultyCardCollapsed,
                    FrameRateLimit = normalized.FrameRateLimit,
                    NoteAnchor = normalized.NoteAnchor,
                    MusicVolume = normalized.MusicVolume,
                    PreservePitch = normalized.PreservePitch,
                    FullscreenMode = normalized.FullscreenMode,
                    BarLineThickness = normalized.BarLineThickness,
                    SubdivisionLineThickness = normalized.SubdivisionLineThickness,
                    TrackOpacity = normalized.TrackOpacity,
                    UnsnapScrollDivision = normalized.UnsnapScrollDivision,
                    QuickRangeCopy = normalized.QuickRangeCopy,
                    CurveDenseDivision = normalized.CurveDenseDivision,
                    CurveSparseDivision = normalized.CurveSparseDivision,
                    CurveShape = normalized.CurveShape.ToString(),
                    CurveLaneOrder = normalized.CurveLaneOrder.ToString(),
                    CurveSpreadAcrossLanes =
                        normalized.CurveLaneOrder != CurveLaneArrangement.Single
                },
                JsonOptions);
            using (var output = new FileStream(
                       temporary,
                       FileMode.CreateNew,
                       FileAccess.Write,
                       FileShare.None,
                       16 * 1024,
                       FileOptions.WriteThrough))
            {
                output.Write(bytes);
                output.Flush(flushToDisk: true);
            }

            if (File.Exists(destination))
                File.Replace(
                    temporary,
                    destination,
                    destinationBackupFileName: null,
                    ignoreMetadataErrors: true);
            else
                File.Move(temporary, destination);
        }
        finally
        {
            try
            {
                if (File.Exists(temporary)) File.Delete(temporary);
            }
            catch
            {
                // Preserve the primary settings-write failure.
            }
        }
    }

    private sealed class PersistedSettings
    {
        public int SchemaVersion { get; set; }
        public double GridLaneWidth { get; set; } = WindowsEditorViewSettings.DefaultGridLaneWidth;
        public double GridBeatHeight { get; set; } = WindowsEditorViewSettings.DefaultGridBeatHeight;
        public double MainEditorHorizontalOffset { get; set; }
        public double NoteWidth { get; set; } = WindowsEditorViewSettings.DefaultNoteWidth;
        public double NoteHeight { get; set; } = WindowsEditorViewSettings.DefaultNoteHeight;
        public double NoteOpacity { get; set; } = 1;
        public double JudgementLinePosition { get; set; } =
            WindowsEditorViewSettings.DefaultJudgementLinePosition;
        public double JudgementLineThickness { get; set; } =
            WindowsEditorViewSettings.DefaultJudgementLineThickness;
        public double JudgementLineOpacity { get; set; } =
            WindowsEditorViewSettings.DefaultJudgementLineOpacity;
        public bool AutoBackupEnabled { get; set; } = true;
        public int AutoBackupMinutes { get; set; } =
            WindowsEditorViewSettings.DefaultAutoBackupMinutes;
        public double QuickPaletteX { get; set; }
        public double QuickPaletteY { get; set; }
        public bool QuickPaletteCollapsed { get; set; }
        public double QuickValuesPaletteX { get; set; }
        public double QuickValuesPaletteY { get; set; }
        public bool QuickValuesPaletteCollapsed { get; set; }
        public int SnapDivision { get; set; } = WindowsEditorViewSettings.DefaultSnapDivision;
        public int FixedSnapDivision { get; set; } =
            WindowsEditorViewSettings.DefaultFixedSnapDivision;
        public double PlaybackRate { get; set; } = WindowsEditorViewSettings.DefaultPlaybackRate;
        public double DifficultyCardX { get; set; }
        public double DifficultyCardY { get; set; }
        public bool DifficultyCardCollapsed { get; set; }
        public int FrameRateLimit { get; set; } = WindowsEditorViewSettings.DefaultFrameRateLimit;
        public WindowsNoteAnchorMode NoteAnchor { get; set; } =
            WindowsNoteAnchorMode.CellBottom;
        public double MusicVolume { get; set; } = WindowsEditorViewSettings.DefaultMusicVolume;
        public bool PreservePitch { get; set; }
        public WindowsFullscreenMode FullscreenMode { get; set; } =
            WindowsFullscreenMode.Windowed;
        public double BarLineThickness { get; set; } =
            WindowsEditorViewSettings.DefaultBarLineThickness;
        public double SubdivisionLineThickness { get; set; } =
            WindowsEditorViewSettings.DefaultSubdivisionLineThickness;
        public double TrackOpacity { get; set; } =
            WindowsEditorViewSettings.DefaultTrackOpacity;
        public int UnsnapScrollDivision { get; set; } =
            WindowsEditorViewSettings.DefaultUnsnapScrollDivision;
        public bool QuickRangeCopy { get; set; }
        public int CurveDenseDivision { get; set; } =
            WindowsEditorViewSettings.DefaultCurveDenseDivision;
        public int CurveSparseDivision { get; set; } =
            WindowsEditorViewSettings.DefaultCurveSparseDivision;
        // Stored by name, not ordinal: reordering the enum later must not
        // silently turn every persisted curve into a different shape.
        public string CurveShape { get; set; } =
            nameof(CurveDensityShape.DenseSparseDense);
        // Name, not ordinal, for the same reason as CurveShape.
        public string? CurveLaneOrder { get; set; }
        /// <summary>
        /// Older file layout: a single flag for "spread over the lanes". Still
        /// written so a rollback to an earlier build keeps the arrangement it
        /// understands, and read when <see cref="CurveLaneOrder"/> is absent.
        /// </summary>
        public bool CurveSpreadAcrossLanes { get; set; }
    }
}
