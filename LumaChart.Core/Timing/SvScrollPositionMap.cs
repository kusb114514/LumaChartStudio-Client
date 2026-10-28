namespace LumaChart.Core.Timing;

/// <summary>
/// Cumulative playfield position for a list of (beat, value) scroll points,
/// WITHOUT the 0..100 clamp that <see cref="ScrollSpeedMap"/> applies for the
/// playtest. Templates rely on this: teleports reach four-figure multipliers and
/// reverse sections are negative, and both must keep their real geometry here.
/// Negative positions are legal: they mean "behind the judgement line".
/// </summary>
public sealed class SvScrollPositionMap
{
    private readonly Segment[] segments;

    public SvScrollPositionMap(IEnumerable<(double Beat, double Value)> points, double initialValue = 1)
    {
        var ordered = points
            .Where(point => double.IsFinite(point.Beat) && double.IsFinite(point.Value))
            .OrderBy(point => point.Beat)
            .ToArray();

        var result = new List<Segment> { new(double.NegativeInfinity, initialValue, 0) };
        foreach (var point in ordered)
        {
            var previous = result[^1];
            var startBeat = point.Beat;
            var position = double.IsFinite(previous.StartBeat)
                ? previous.StartPosition + (startBeat - previous.StartBeat) * previous.Value
                : previous.StartPosition;
            if (result.Count > 1 && Math.Abs(previous.StartBeat - startBeat) < 1e-9)
            {
                // Same beat: the later row wins (Malody reads effects in order).
                result[^1] = new Segment(startBeat, point.Value, previous.StartPosition);
            }
            else
            {
                result.Add(new Segment(startBeat, point.Value, position));
            }
        }
        segments = result.ToArray();
    }

    public double ValueAt(double beat) => segments[FindSegment(beat)].Value;

    public double PositionAt(double beat)
    {
        var segment = segments[FindSegment(beat)];
        return double.IsFinite(segment.StartBeat)
            ? segment.StartPosition + (beat - segment.StartBeat) * segment.Value
            : segment.StartPosition;
    }

    public double Distance(double from, double to) => PositionAt(to) - PositionAt(from);

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

    private readonly record struct Segment(double StartBeat, double Value, double StartPosition);
}
