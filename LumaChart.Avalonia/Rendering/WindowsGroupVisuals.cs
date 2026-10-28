using System.Collections.Concurrent;
using Avalonia;
using Avalonia.Media;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Rendering;

/// <summary>
/// How the note colour reads the group tree.
/// <list type="bullet">
/// <item><see cref="Off"/> — every note keeps the stock grey-white plate.</item>
/// <item><see cref="Leaf"/> — a note takes the colour of the group it is
/// assigned to, so a nested chart reads at the finest level.</item>
/// <item><see cref="Root"/> — a note takes the colour of its outermost group,
/// so the same chart reads at the coarse level without re-tagging anything.</item>
/// </list>
/// </summary>
public enum WindowsGroupColorMode
{
    Off,
    Leaf,
    Root
}

/// <summary>
/// One annotation card placed by the last timeline render. Keeping the geometry
/// means a click on the canvas can be routed to an annotation without
/// re-deriving the card layout (and without the two ever disagreeing).
/// </summary>
public readonly record struct TimelineAnnotationCard(
    int Annotation,
    Rect Bounds,
    bool IsDockedRight);

/// <summary>
/// The brushes one note needs once a group colour is applied. Derived once per
/// colour and cached: the timeline renders thousands of notes per frame and
/// allocating brushes inside the draw loop was measurable.
/// </summary>
public sealed class WindowsNoteAccent
{
    private WindowsNoteAccent(Color color)
    {
        Color = color;
        var plate = WindowsGroupVisuals.Shade(color, .34);
        Plate = new SolidColorBrush(Color.FromArgb(0xF2, plate.R, plate.G, plate.B));
        Rail = new SolidColorBrush(color);
        var contour = WindowsGroupVisuals.Shade(color, .62);
        Contour = new Pen(new SolidColorBrush(contour), 2.1);
        HoldOuter = new SolidColorBrush(color);
        HoldFace = new SolidColorBrush(WindowsGroupVisuals.Shade(color, .58));
        Leader = new SolidColorBrush(Color.FromArgb(0xD8, color.R, color.G, color.B));
        LeaderPen = new Pen(Leader, 1.6);
        var card = WindowsGroupVisuals.Shade(color, .20);
        CardFill = new SolidColorBrush(Color.FromArgb(0xF2, card.R, card.G, card.B));
        CardPen = new Pen(new SolidColorBrush(color), 1.4);
        CardHeader = new SolidColorBrush(color);
        // Legibility is decided against the card fill, not against the accent:
        // the fill is a dark shade of the accent, so a dark custom colour must
        // still produce light text.
        CardText = new SolidColorBrush(WindowsGroupVisuals.ReadableText(card));
        Selection = new SolidColorBrush(Color.FromArgb(0x3A, color.R, color.G, color.B));
    }

    private static readonly ConcurrentDictionary<uint, WindowsNoteAccent> Cache = new();

    public static WindowsNoteAccent For(Color color)
    {
        var key = ((uint)color.A << 24) | ((uint)color.R << 16) | ((uint)color.G << 8) | color.B;
        return Cache.GetOrAdd(key, _ => new WindowsNoteAccent(color));
    }

    public Color Color { get; }
    public IBrush Plate { get; }
    public IBrush Rail { get; }
    public IPen Contour { get; }
    public IBrush HoldOuter { get; }
    public IBrush HoldFace { get; }
    public IBrush Leader { get; }
    public IPen LeaderPen { get; }
    public IBrush CardFill { get; }
    public IPen CardPen { get; }
    public IBrush CardHeader { get; }
    public IBrush CardText { get; }
    public IBrush Selection { get; }
}

/// <summary>
/// Resolves what a group id should look like right now: its name, its colour
/// and its place in the tree. One instance is handed to the timeline so the
/// renderer never has to reach back into the window for group state.
/// </summary>
public sealed class WindowsGroupVisuals
{
    /// <summary>
    /// The fixed palette. Order is part of the editor's identity: group N maps
    /// to <c>(N - 1) % Count</c> and the spec pins those indices, so append to
    /// this list only when a deliberate re-colour is wanted.
    /// </summary>
    public static readonly IReadOnlyList<string> PaletteHex =
    [
        "#FFE7B6A2",
        "#FFE4CE88",
        "#FFC5D98A",
        "#FFA8D887",
        "#FF8FD4BC",
        "#FF8BCBDD",
        "#FF9CB7E2",
        "#FFB7A8DE",
        "#FFD5A5CA",
        "#FFE4A2AE",
        "#FFB9C4C8",
        "#FFD0B58C"
    ];

    public static readonly IReadOnlyList<Color> Palette =
        PaletteHex.Select(Color.Parse).ToArray();

    public static WindowsGroupVisuals Default { get; } = new();

    /// <summary>
    /// The stock note plate: what an unassigned note already looks like. An
    /// annotation pinned to ungrouped notes borrows exactly this, so "未分组"
    /// reads as the same white in the card as it does on the note. The value is
    /// the timeline's own <c>NoteRailBrush</c>.
    /// </summary>
    public static WindowsNoteAccent Ungrouped { get; } =
        WindowsNoteAccent.For(Color.Parse("#FFD0DEDC"));

    public ChartGroupCatalog Catalog { get; init; } = new();

    public ChartAnnotationCatalog Annotations { get; init; } = new();

    /// <summary>
    /// The blocks the active annotation preset puts on screen, or null for 全部.
    /// The timeline honours the same choice the annotation panel does, so
    /// selecting a preset changes the chart itself and not just the list beside
    /// it. Null means "draw everything" and keeps the common case allocation-free.
    /// </summary>
    public IReadOnlySet<int>? VisibleAnnotationIds { get; init; }

    public WindowsGroupColorMode ColorMode { get; init; } = WindowsGroupColorMode.Leaf;

    /// <summary>Draw the group id inside each note. Off by default: the colour
    /// already carries the group and the badge was the thing that read badly.</summary>
    public bool ShowGroupNumbers { get; init; }

    public bool ShowAnnotations { get; init; } = true;

    /// <summary>Dock annotation cards on the right of the track, else the left.</summary>
    public bool AnnotationsDockRight { get; init; } = true;

    public static int PaletteIndex(int group) => (group - 1) % Palette.Count;

    public static Color PaletteColor(int group) => Palette[PaletteIndex(group)];

    /// <summary>Parses "#RRGGBB"/"#AARRGGBB", falling back when unusable.</summary>
    public static Color ParseColor(string? text, Color fallback) =>
        ChartGroupCatalog.IsValidColorText(text) && Color.TryParse(text!.Trim(), out var parsed)
            ? parsed
            : fallback;

    public static Color Shade(Color color, double factor)
    {
        factor = Math.Clamp(factor, 0, 1);
        return Color.FromArgb(
            color.A,
            (byte)Math.Clamp(Math.Round(color.R * factor), 0, 255),
            (byte)Math.Clamp(Math.Round(color.G * factor), 0, 255),
            (byte)Math.Clamp(Math.Round(color.B * factor), 0, 255));
    }

    /// <summary>Black or white, whichever stays legible on <paramref name="background"/>.</summary>
    public static Color ReadableText(Color background)
    {
        var luminance = (.299 * background.R + .587 * background.G + .114 * background.B) / 255;
        return luminance > .6
            ? Color.FromRgb(0x17, 0x20, 0x24)
            : Color.FromRgb(0xF2, 0xF5, 0xF5);
    }

    /// <summary>
    /// The id whose colour a note of <paramref name="group"/> should wear, or 0
    /// when unassigned / colouring is off.
    /// </summary>
    public int ResolveDisplayGroup(int group)
    {
        if (ColorMode == WindowsGroupColorMode.Off) return 0;
        if (group is < 1 or > ushort.MaxValue) return 0;
        return ColorMode == WindowsGroupColorMode.Root ? Catalog.RootOf(group) : group;
    }

    /// <summary>The colour for a note in <paramref name="group"/>, or null to keep the stock chrome.</summary>
    public Color? ResolveColor(int group)
    {
        var display = ResolveDisplayGroup(group);
        if (display is < 1 or > ushort.MaxValue) return null;
        var custom = Catalog.ColorOf(display);
        return ChartGroupCatalog.IsValidColorText(custom)
            ? ParseColor(custom, PaletteColor(display))
            : PaletteColor(display);
    }

    /// <summary>The cached brush set for <paramref name="group"/>, or null for the stock chrome.</summary>
    public WindowsNoteAccent? ResolveAccent(int group) =>
        ResolveColor(group) is { } color ? WindowsNoteAccent.For(color) : null;

    public string NameOf(int group) => Catalog.NameOf(group);

    /// <summary>
    /// The group a set of notes reads as. The dominant group wins rather than
    /// the first one, because a block usually covers a run that may clip a
    /// stray note from a neighbouring group and the block should read as its
    /// bulk, not its exception. Returns 0 when nothing is grouped.
    /// </summary>
    public static int DominantGroup(IEnumerable<int> noteGroups)
    {
        var counts = new Dictionary<int, int>();
        foreach (var group in noteGroups)
        {
            if (group is < 1 or > ushort.MaxValue) continue;
            counts[group] = counts.GetValueOrDefault(group) + 1;
        }
        return counts.Count == 0
            ? 0
            : counts
                .OrderByDescending(pair => pair.Value)
                .ThenBy(pair => pair.Key)
                .First()
                .Key;
    }

    /// <summary>
    /// The card colour for an annotation reading as <paramref name="dominantGroup"/>:
    /// that group's colour, or the stock white for 未分组.
    /// </summary>
    public WindowsNoteAccent AnnotationAccent(int dominantGroup) =>
        ResolveAccent(dominantGroup) ?? Ungrouped;
}
