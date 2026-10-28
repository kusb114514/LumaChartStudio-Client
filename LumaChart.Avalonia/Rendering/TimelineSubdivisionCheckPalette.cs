using System.Collections.ObjectModel;
using Avalonia.Media;

namespace LumaChart.Avalonia.Rendering;

public readonly record struct TimelineSubdivisionCheckStyle(Color Color, bool IsWarning);

public static class TimelineSubdivisionCheckPalette
{
    /// <summary>
    /// The densest subdivision a Malody chart can store. A .mc note beat is an
    /// integer numerator over a denominator no larger than 1440, so 1/1440 of a
    /// beat is the finest position that survives a round trip through the format.
    /// The editor exposes it as "Un-snap": one 1440th of a beat is far below a
    /// pixel at any zoom the timeline allows, so a placement keeps the pointer's
    /// position and reads as free placement rather than as a grid.
    /// </summary>
    public const int UnsnapDivision = 1440;

    public const string UnsnapLabel = "Un-snap";

    private static readonly int[] EditorDivisionValues =
    [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 32, UnsnapDivision, 48, 64, 96, 192,
        480, 960, 1920
    ];

    private static readonly int[] RegularDivisionValues =
        [1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48];

    private static readonly int[] SupportedDenominatorValues = RegularDivisionValues
        .Concat(RegularDivisionValues.Select(division => checked(division * 2)))
        .Distinct()
        .Order()
        .ToArray();

    private static readonly Color[] BrightNormalColors =
    [
        Color.Parse("#FFFFD400"),
        Color.Parse("#FF00E5FF"),
        Color.Parse("#FFB6FF00"),
        Color.Parse("#FFFF8A00"),
        Color.Parse("#FF9B5CFF"),
        Color.Parse("#FF00FF9D"),
        Color.Parse("#FFFF4FD8"),
        Color.Parse("#FF4DFFEA"),
        Color.Parse("#FFC8FF4D"),
        Color.Parse("#FFFFB84D"),
        Color.Parse("#FF6EA8FF"),
        Color.Parse("#FF59FF6E"),
        Color.Parse("#FFD66EFF")
    ];

    private static readonly IReadOnlyDictionary<int, TimelineSubdivisionCheckStyle> NormalStyles =
        SupportedDenominatorValues
            .Select((denominator, index) => new
            {
                Denominator = denominator,
                Style = new TimelineSubdivisionCheckStyle(BrightNormalColors[index], false)
            })
            .ToDictionary(item => item.Denominator, item => item.Style);

    private static readonly TimelineSubdivisionCheckStyle WarningStyle =
        new(Color.Parse("#FFFF4055"), true);

    public static IReadOnlyList<int> EditorDivisions { get; } =
        new ReadOnlyCollection<int>(EditorDivisionValues);

    public static IReadOnlyList<int> SupportedDenominators { get; } =
        new ReadOnlyCollection<int>(SupportedDenominatorValues);

    public static Color WarningColor => WarningStyle.Color;

    public static int NormalizeDenominator(int denominator) => denominator <= 0 ? 1 : denominator;

    public static bool IsUnsnap(int division) => division == UnsnapDivision;

    /// <summary>How a subdivision is named everywhere the user can see it.</summary>
    public static string FormatDivisionLabel(int division) =>
        IsUnsnap(division) ? UnsnapLabel : $"1/{division}";

    public static bool IsSupportedDenominator(int denominator) =>
        NormalStyles.ContainsKey(NormalizeDenominator(denominator));

    public static TimelineSubdivisionCheckStyle Resolve(int denominator)
    {
        denominator = NormalizeDenominator(denominator);
        return NormalStyles.TryGetValue(denominator, out var style) ? style : WarningStyle;
    }

}
