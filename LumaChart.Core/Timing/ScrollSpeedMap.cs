using LumaChart.Core.Models;

namespace LumaChart.Core.Timing;

/// <summary>
/// Converts musical beats into a cumulative playfield distance. Scroll effects
/// change the distance produced by subsequent beats; BPM deliberately does not
/// live here because <see cref="TimingMap"/> already controls how quickly audio
/// time advances through those beats.
/// </summary>
public sealed class ScrollSpeedMap
{
    /// <summary>倍率上限。超过这个数在画面上已经没有区别，只会把坐标算到溢出。</summary>
    public const double MaximumMultiplier = 100;

    private readonly Segment[] segments;

    /// <param name="minimumMultiplier">
    /// Lower bound for a scroll multiplier. Play and playtest deliberately clamp at 0
    /// (a chart can never scroll backwards there), but the SV template preview has to
    /// show negative speeds as what they are — otherwise a reverse-flow template looks
    /// like the note simply stopped.
    /// </param>
    public ScrollSpeedMap(IEnumerable<TimingEvent> events, double minimumMultiplier = 0)
    {
        var floor = double.IsFinite(minimumMultiplier) ? Math.Min(0, minimumMultiplier) : 0;
        MinimumMultiplier = floor;
        var points = events.Select((item, index) => (Item: item, Index: index))
            .Where(entry => entry.Item.Effect == TimingEffectKind.Scroll && double.IsFinite(entry.Item.EffectValue))
            .OrderBy(entry => entry.Item.Beat)
            .ThenBy(entry => entry.Index)
            .Select(entry => entry.Item)
            .ToList();

        var result = new List<Segment> { new(0, 1, 0) };
        foreach (var point in points)
        {
            var beat = Math.Max(0, point.Beat.Value);
            var multiplier = Math.Clamp(point.EffectValue, floor, MaximumMultiplier);
            var previous = result[^1];
            var position = previous.StartPosition + (beat - previous.StartBeat) * previous.Multiplier;
            if (Math.Abs(previous.StartBeat - beat) < 1e-9)
                result[^1] = new Segment(beat, multiplier, previous.StartPosition);
            else
                result.Add(new Segment(beat, multiplier, position));
        }
        segments = result.ToArray();
    }

    /// <summary>这张图允许的最低倍率。别的表（<see cref="JumpOffsetMap"/>）要用同一个下限夹，否则两边算的不是同一套坐标。</summary>
    public double MinimumMultiplier { get; }

    /// <summary>Returns cumulative distance in scroll-adjusted beats.</summary>
    public double PositionAt(BeatPosition beat)
    {
        var value = beat.Value;
        var segment = segments[FindSegment(value)];
        return segment.StartPosition + (value - segment.StartBeat) * segment.Multiplier;
    }

    public double Distance(BeatPosition from, BeatPosition to) => PositionAt(to) - PositionAt(from);

    public double MultiplierAt(BeatPosition beat) => segments[FindSegment(beat.Value)].Multiplier;

    private int FindSegment(double beat)
    {
        var low = 0;
        var high = segments.Length - 1;
        while (low < high)
        {
            var middle = (low + high + 1) / 2;
            if (segments[middle].StartBeat <= beat) low = middle;
            else high = middle - 1;
        }
        return low;
    }

    private readonly record struct Segment(double StartBeat, double Multiplier, double StartPosition);
}
