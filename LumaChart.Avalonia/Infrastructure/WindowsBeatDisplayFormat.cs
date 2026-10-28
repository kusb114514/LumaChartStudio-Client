using System.Globalization;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Infrastructure;

/// <summary>
/// The beat number a mapper reads and types, which is the stored one plus one.
///
/// <see cref="BeatPosition.Bar"/> is the persisted index and counts from zero:
/// that is what the .mc/.osu files, the per-chart catalog and the editor archive
/// all carry, and it is what <see cref="BeatPosition.ToString"/> spells. Every
/// beat a person actually reads or types — the timeline rail, the Note property
/// box, the Timing box, the navigation markers, the annotation list — is numbered
/// from one instead, which is also how Malody's own editor numbers it. So a
/// downbeat the rail labels beat 5 reads back out of the inspector as beat 5, not
/// as beat 4, and a mapper can retype what they see.
///
/// The offset deliberately lives here, at the presentation edge, rather than in
/// <see cref="BeatPosition"/>: moving the stored spelling would silently
/// reinterpret every position already written to disk by a previous build.
/// </summary>
public static class WindowsBeatDisplayFormat
{
    /// <summary>
    /// Formats a position exactly the way <see cref="BeatPosition.ToString"/>
    /// does, with the bar shifted to its one-based beat number.
    /// </summary>
    public static string Format(BeatPosition position)
    {
        // A long keeps the shift from overflowing on the extreme bar values
        // FromDouble accepts; the spelling is identical for every real chart.
        var beat = (long)position.Bar + 1;
        return position.Denominator == 0
            ? string.Create(CultureInfo.InvariantCulture, $"{beat}:{position.Numerator}/1")
            : string.Create(
                CultureInfo.InvariantCulture,
                $"{beat}:{position.Numerator}/{position.Denominator}");
    }

    /// <summary>
    /// Formats an optional position the way the editor spells an absent one:
    /// empty text, not a placeholder. Hold tails are the common case, and a Tap
    /// note's End Beat box is the same thing.
    /// </summary>
    public static string Format(BeatPosition? position) =>
        position is { } value ? Format(value) : string.Empty;

    /// <summary>
    /// Parses what <see cref="Format"/> produced, including the plain decimal
    /// form the editor's boxes also accept. Anything that would land before
    /// beat 1 is rejected rather than shifted, because the editor never shows a
    /// beat 0 and a mapper cannot have meant one.
    /// </summary>
    public static bool TryParse(string? text, out BeatPosition position)
    {
        position = BeatPosition.Zero;
        if (!BeatPosition.TryParse(text, out var parsed)) return false;
        if (parsed.Denominator == 0 || parsed.Bar < 1) return false;
        try
        {
            position = BeatPosition.Preserve(
                parsed.Bar - 1,
                parsed.Numerator,
                parsed.Denominator);
            return true;
        }
        catch (ArgumentOutOfRangeException) { return false; }
        catch (OverflowException) { return false; }
    }
}
