using LumaChart.Core.Models;

namespace LumaChart.Core.Editing;

/// <summary>Shape of the gap curve, measured from the head of the range.</summary>
public enum CurveDensityShape
{
    /// <summary>Dense at both ends, sparse in the middle.</summary>
    DenseSparseDense,
    /// <summary>Starts sparse, ends dense.</summary>
    SparseToDense,
    /// <summary>Starts dense, ends sparse.</summary>
    DenseToSparse
}

/// <summary>How the stream is spread over the lanes, counted from the source column.</summary>
public enum CurveLaneArrangement
{
    /// <summary>Every note stays in the source long note's column.</summary>
    Single,
    /// <summary>Walks the ring of lanes one step at a time: 1→2→3→4→1.</summary>
    Stairs,
    /// <summary>Swings between two neighbouring lanes: 1→2→1→2.</summary>
    Alternate
}

/// <summary>
/// Parameters for turning a long note into a stream whose gaps follow a curve.
/// Divisions are expressed the way the editor expresses snap (1/N of a beat),
/// so "dense 1/16, sparse 1/1" reads the same as the grid.
/// </summary>
/// <param name="LaneArrangement">
/// Where the generated notes go. All three start at the source column, so a
/// long note on lane 3 spreads as 3→4→1→2 rather than jumping to lane 1.
/// </param>
public sealed record CurveDensityOptions(
    CurveDensityShape Shape,
    int DenseDivision,
    int SparseDivision,
    int MaximumNotes = CurveDensityService.DefaultMaximumNotes,
    CurveLaneArrangement LaneArrangement = CurveLaneArrangement.Single);

/// <summary>
/// Generates the note positions of a density curve. This is deliberately
/// separate from the document mutation: the dialog needs to show the expected
/// note count before anything is written, and the specs need to inspect the
/// positions without a chart.
/// </summary>
public static class CurveDensityService
{
    /// <summary>
    /// Malody stores beat denominators up to 1440; anything finer would be
    /// rejected on save, so every generated position is folded onto that grid.
    /// </summary>
    public const int MalodyDenominator = 1440;

    /// <summary>
    /// A curve can ask for an absurd number of notes (a 64 beat range at 1/1440
    /// is 92160 of them). Refusing is better than emitting a chart nobody can
    /// play or scroll.
    /// </summary>
    public const int DefaultMaximumNotes = 4096;

    /// <summary>
    /// Positions in beats, relative to the head of the range, always starting
    /// at 0 and ending exactly at <paramref name="lengthBeats"/>.
    /// </summary>
    public static IReadOnlyList<double> BuildOffsets(
        double lengthBeats,
        CurveDensityOptions options)
    {
        ArgumentNullException.ThrowIfNull(options);
        var (gapMin, gapMax) = ResolveGaps(options);
        if (!(lengthBeats > 0)) return [0];
        if (lengthBeats <= gapMin) return [0, lengthBeats];

        var offsets = EstimateGapCount(
            lengthBeats,
            gapMin,
            gapMax,
            options.Shape,
            options.MaximumNotes);
        if (offsets.Count > options.MaximumNotes)
            throw new InvalidOperationException(
                $"曲线会在区间内生成 {offsets.Count} 个 Note，超过上限 {options.MaximumNotes}。" +
                "请增大最密间隔或缩短区间。");
        return offsets;
    }

    /// <summary>How many notes the curve would produce, without building them.</summary>
    public static int EstimateNoteCount(double lengthBeats, CurveDensityOptions options) =>
        BuildOffsets(lengthBeats, options).Count;

    /// <summary>
    /// Gap length in beats at progress <paramref name="u"/> (0 = range head,
    /// 1 = range tail). Interpolation is geometric, so equal steps of the shape
    /// function multiply the gap by the same ratio — that is what makes the
    /// acceleration feel even instead of bunched up at the sparse end.
    /// </summary>
    public static double GapAt(double u, CurveDensityOptions options)
    {
        var (gapMin, gapMax) = ResolveGaps(options);
        var weight = ShapeWeight(Math.Clamp(u, 0, 1), options.Shape);
        return gapMin * Math.Pow(gapMax / gapMin, weight);
    }

    /// <summary>0 = densest, 1 = sparsest.</summary>
    public static double ShapeWeight(double u, CurveDensityShape shape) => shape switch
    {
        CurveDensityShape.SparseToDense => 1 - u,
        CurveDensityShape.DenseToSparse => u,
        // sin(pi*u) peaks exactly in the middle of the range and is zero at both
        // ends, which is the "dense, sparse, dense" shape mappers draw by hand.
        _ => Math.Sin(Math.PI * u)
    };

    /// <summary>
    /// Converts selected long notes into streams. The long note's own column,
    /// group and sample are reused for every generated note, and its head
    /// becomes the first note of the stream.
    /// <see cref="CurveDensityOptions.LaneArrangement"/> decides which column
    /// each following note lands in; the rhythm is the same either way.
    /// </summary>
    public static NoteTransformResult FillCurveDensity(
        ChartDocument document,
        IReadOnlySet<Guid> selectedIds,
        CurveDensityOptions options)
    {
        ArgumentNullException.ThrowIfNull(document);
        var holds = document.Notes
            .Where(note => selectedIds.Contains(note.Id) && note.IsHold)
            .OrderBy(note => note.Beat)
            .ToArray();
        var nextSelection = new HashSet<Guid>();
        var converted = 0;
        var created = 0;
        var skipped = 0;

        foreach (var note in holds)
        {
            var head = note.Beat;
            var tail = note.EndBeat!.Value;
            var length = tail.Value - head.Value;
            IReadOnlyList<double> offsets;
            try
            {
                offsets = BuildOffsets(length, options);
            }
            catch (InvalidOperationException)
            {
                // One oversized range must not abort the rest of the batch.
                skipped++;
                continue;
            }

            note.EndBeat = null;
            nextSelection.Add(note.Id);
            converted++;

            // The arrangement walks lanes from the long note's own column, so a
            // note on lane 1 produces 1→2→3→4→1 and a note already on lane 3
            // still starts where the source note was.
            var spread = options.LaneArrangement != CurveLaneArrangement.Single &&
                         !note.IsDraft &&
                         document.KeyCount > 1;
            var baseLane = note.Lane;
            var index = 0;

            foreach (var offset in offsets)
            {
                if (offset <= 0) continue;
                var beat = BeatPosition.FromDouble(head.Value + offset, MalodyDenominator);
                if (beat.CompareTo(head) <= 0) continue;
                if (beat.Value > tail.Value + 1e-9) break;
                index++;
                var lane = spread
                    ? ResolveLane(options.LaneArrangement, baseLane, index, document.KeyCount)
                    : note.Lane;
                if (HasNoteAt(document.Notes, note, lane, beat)) { skipped++; continue; }

                var tap = note.Clone();
                tap.Id = Guid.NewGuid();
                tap.Beat = beat;
                tap.EndBeat = null;
                tap.Lane = lane;
                document.Notes.Add(tap);
                nextSelection.Add(tap.Id);
                created++;
            }
        }

        return new NoteTransformResult(converted, created, skipped, nextSelection);
    }

    /// <summary>
    /// Column of the note at position <paramref name="index"/> (1 = the first
    /// note after the head). Both arrangements are relative to the source
    /// column, which is why they wrap instead of restarting at lane 1.
    /// </summary>
    private static int ResolveLane(
        CurveLaneArrangement arrangement,
        int baseLane,
        int index,
        int keyCount) => arrangement switch
    {
        CurveLaneArrangement.Stairs => (baseLane + index) % keyCount,
        CurveLaneArrangement.Alternate => (baseLane + index % 2) % keyCount,
        _ => baseLane
    };

    private static (double Min, double Max) ResolveGaps(CurveDensityOptions options)
    {
        var dense = Math.Clamp(options.DenseDivision, 1, 1920);
        var sparse = Math.Clamp(options.SparseDivision, 1, 1920);
        // Choosing them the wrong way round is a slip, not an intent, so the
        // service sorts instead of throwing.
        if (dense < sparse) (dense, sparse) = (sparse, dense);
        return (1d / dense, 1d / sparse);
    }

    /// <summary>
    /// Finds the largest gap count whose gaps still fit in the range, then
    /// scales that one shortfall across every gap. Fitting the count first is
    /// what keeps the scale factor within a single gap of 1 — a proportional
    /// guess can land far enough off that the "densest 1/16" end is no longer
    /// 1/16 at all.
    /// </summary>
    private static IReadOnlyList<double> EstimateGapCount(
        double length,
        double gapMin,
        double gapMax,
        CurveDensityShape shape,
        int maximumNotes)
    {
        // sum(0) = 0 <= length, and sum(upper) >= upper*gapMin >= length, so the
        // two ends bracket the answer without a special case. The cap keeps a
        // pathological 1/1440 range from building a six-figure array: it settles
        // at the cap instead, which the caller then rejects.
        // The +1 lets the search settle at the cap itself when even the cap is
        // too short to fill the range; that count is then one note over the
        // limit and the caller rejects it.
        var hardCap = Math.Max(2, maximumNotes);
        var upper = (int)Math.Min(
            hardCap + 1.0,
            Math.Max(2, Math.Ceiling(length / gapMin) + 1));
        var low = 0;
        var high = upper;
        while (high - low > 1)
        {
            var middle = low + (high - low) / 2;
            if (SumGaps(length, gapMin, gapMax, shape, middle) <= length) low = middle;
            else high = middle;
        }

        var count = Math.Max(1, low);
        var offsets = Build(length, gapMin, gapMax, shape, count);
        var scale = offsets[^1] > 0 ? length / offsets[^1] : 1;
        for (var index = 0; index < offsets.Length - 1; index++) offsets[index] *= scale;
        offsets[^1] = length;
        return offsets;
    }

    private static double SumGaps(
        double length,
        double gapMin,
        double gapMax,
        CurveDensityShape shape,
        int count)
    {
        var total = 0d;
        for (var index = 0; index < count; index++)
        {
            var u = length > 0 ? Math.Min(1, total / length) : 0;
            total += gapMin * Math.Pow(gapMax / gapMin, ShapeWeight(u, shape));
        }
        return total;
    }

    private static double[] Build(
        double length,
        double gapMin,
        double gapMax,
        CurveDensityShape shape,
        int count)
    {
        var offsets = new double[count + 1];
        var total = 0d;
        for (var index = 0; index < count; index++)
        {
            // Progress is taken from the accumulated position, so a sparse
            // section does not "advance" the curve faster than it does time.
            var u = length > 0 ? Math.Min(1, offsets[index] / length) : 0;
            var weight = ShapeWeight(u, shape);
            total += gapMin * Math.Pow(gapMax / gapMin, weight);
            offsets[index + 1] = total;
        }
        return offsets;
    }

    private static bool HasNoteAt(
        IEnumerable<ChartNote> notes,
        ChartNote source,
        int lane,
        BeatPosition beat) =>
        notes.Any(candidate =>
            candidate.IsDraft == source.IsDraft &&
            (source.IsDraft ? candidate.DraftColumn == source.DraftColumn : candidate.Lane == lane) &&
            candidate.Beat.CompareTo(beat) == 0);

}
