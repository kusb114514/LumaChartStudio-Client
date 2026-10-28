using LumaChart.Application.Editing;
using LumaChart.Avalonia.Editing;
using LumaChart.Core.Editing;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Specs;

/// <summary>
/// The density curve is the one transform whose output is a shape rather than
/// a fixed rule, so the checks look at the gaps: the densest end has to be the
/// configured densest division, the sparsest end the configured sparsest, the
/// monotone halves have to actually go one way, and every position has to stay
/// inside what Malody can store.
/// </summary>
internal static class CurveDensitySpecs
{
    /// <summary>Matches the hand-built reference passage: 355+11/12 to 379+9/16.</summary>
    private const double ReferenceLength = 23.645833333333332;

    public static int Run()
    {
        try
        {
            VerifyReferenceShape();
            VerifyEachShapeGoesTheRightWay();
            VerifyReversedDivisionsAreSorted();
            VerifyGuards();
            VerifyDocumentConversion();
            VerifySpreadAcrossLanes();
            Console.WriteLine($"Curve density contracts: passed ({Count} checks)");
            return 0;
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine(exception);
            Console.Error.WriteLine($"Curve density contracts: failed after {Count} checks");
            return 1;
        }
    }

    private static void VerifyReferenceShape()
    {
        var options = new CurveDensityOptions(CurveDensityShape.DenseSparseDense, 16, 1);
        var offsets = CurveDensityService.BuildOffsets(ReferenceLength, options);
        var gaps = Gaps(offsets);
        var count = offsets.Count;

        // The hand-built passage used 71 notes across the same range; a curve
        // that lands anywhere near that is usable, one that lands at 900 is not.
        Require(
            count is > 60 and < 130,
            $"the reference range yields a plausible note count (got {count})");
        Require(
            Math.Abs(offsets[0]) < 1e-9 && Math.Abs(offsets[^1] - ReferenceLength) < 1e-9,
            $"the stream starts at the head and ends exactly on the tail (got {offsets[0]:0.####} .. {offsets[^1]:0.####}, want 0 .. {ReferenceLength:0.####})");

        var densest = gaps.Min();
        var sparsest = gaps.Max();
        Require(
            Math.Abs(densest - 1d / 16) / (1d / 16) < 0.05,
            $"the densest gap is the configured 1/16 (got 1/{1 / densest:0.##})");
        Require(
            Math.Abs(sparsest - 1) / 1 < 0.05,
            $"the sparsest gap is the configured 1/1 (got {sparsest:0.###})");

        var quarter = gaps.Length / 4;
        var headAverage = gaps.Take(quarter).Average();
        var middleAverage = gaps.Skip(gaps.Length / 2 - quarter / 2).Take(quarter).Average();
        var tailAverage = gaps.Skip(gaps.Length - quarter).Average();
        Require(
            headAverage < middleAverage && tailAverage < middleAverage,
            $"both ends are denser than the middle (head {headAverage:0.###}, middle {middleAverage:0.###}, tail {tailAverage:0.###})");

        var forwardSteps = CountForwardSteps(gaps.Take(gaps.Length / 2));
        Require(
            forwardSteps >= gaps.Length / 2 - 3,
            $"the first half opens up almost monotonically ({forwardSteps} of {gaps.Length / 2 - 1} steps widen)");

        // Malody stores beat denominators up to 1440. A generated position that
        // falls between two such ticks would be rounded on save and drift.
        var offGrid = offsets
            .Where(offset => Math.Abs(offset * CurveDensityService.MalodyDenominator -
                                      Math.Round(offset * CurveDensityService.MalodyDenominator)) > 1e-6)
            .Count();
        Require(
            offGrid > 0,
            $"raw offsets are continuous, so the caller must snap them ({offGrid} of {offsets.Count} are off the 1/1440 grid)");
    }

    private static void VerifyEachShapeGoesTheRightWay()
    {
        var sparseToDense = Gaps(CurveDensityService.BuildOffsets(
            ReferenceLength,
            new CurveDensityOptions(CurveDensityShape.SparseToDense, 16, 1)));
        Require(
            sparseToDense[0] > sparseToDense[^1],
            $"sparse → dense starts wide and ends narrow (start {sparseToDense[0]:0.###}, end {sparseToDense[^1]:0.###})");

        var denseToSparse = Gaps(CurveDensityService.BuildOffsets(
            ReferenceLength,
            new CurveDensityOptions(CurveDensityShape.DenseToSparse, 16, 1)));
        Require(
            denseToSparse[0] < denseToSparse[^1],
            $"dense → sparse starts narrow and ends wide (start {denseToSparse[0]:0.###}, end {denseToSparse[^1]:0.###})");
    }

    private static void VerifyReversedDivisionsAreSorted()
    {
        var forwards = CurveDensityService.BuildOffsets(
            ReferenceLength,
            new CurveDensityOptions(CurveDensityShape.DenseSparseDense, 16, 1));
        var backwards = CurveDensityService.BuildOffsets(
            ReferenceLength,
            new CurveDensityOptions(CurveDensityShape.DenseSparseDense, 1, 16));
        Require(
            forwards.Count == backwards.Count &&
            Math.Abs(forwards[1] - backwards[1]) < 1e-9,
            $"1/16 + 1/1 and 1/1 + 1/16 produce the same curve (got {forwards.Count} vs {backwards.Count} notes)");
    }

    private static void VerifyGuards()
    {
        // The sparse end is what keeps a curve bounded: 1/1440 to 1/1 over 64
        // beats is only a couple of hundred notes. A curve that is dense at
        // both ends is the case that explodes, and that is what the cap is for.
        var dense = new CurveDensityOptions(CurveDensityShape.DenseSparseDense, 1440, 1440);
        var refused = false;
        try
        {
            CurveDensityService.BuildOffsets(64, dense);
        }
        catch (InvalidOperationException)
        {
            refused = true;
        }
        Require(refused, "a 64 beat range at a flat 1/1440 is refused instead of emitting six figures of notes");

        // A 1440x ratio is geometric, so the dense ends eat almost every note:
        // 1/1440 to 1/1 over 64 beats is over the cap as well. What matters is
        // that a realistic ratio stays comfortably inside it.
        var realistic = CurveDensityService.BuildOffsets(
            64,
            new CurveDensityOptions(CurveDensityShape.DenseSparseDense, 32, 1));
        Require(
            realistic.Count < 4096,
            $"1/32 to 1/1 over 64 beats stays inside the cap (got {realistic.Count} notes)");

        var shortRange = CurveDensityService.BuildOffsets(
            0.03,
            new CurveDensityOptions(CurveDensityShape.DenseSparseDense, 16, 1));
        Require(
            shortRange.Count == 2 &&
            Math.Abs(shortRange[1] - 0.03) < 1e-9,
            $"a range shorter than one gap still becomes head + tail (got {shortRange.Count} positions)");
    }

    private static void VerifyDocumentConversion()
    {
        var hold = new ChartNote
        {
            Lane = 2,
            Group = 3,
            Beat = BeatPosition.Preserve(4, 0, 1),
            EndBeat = BeatPosition.Preserve(12, 0, 1)
        };
        var document = new ChartDocument { KeyCount = 4, Notes = [hold] };
        var result = CurveDensityService.FillCurveDensity(
            document,
            new HashSet<Guid> { hold.Id },
            new CurveDensityOptions(CurveDensityShape.DenseSparseDense, 16, 1));

        var written = document.Notes.OrderBy(note => note.Beat).ToArray();
        Require(
            result.ConvertedCount == 1 && result.CreatedCount > 10,
            $"one long note became a stream (converted {result.ConvertedCount}, created {result.CreatedCount})");
        Require(
            written.All(note => !note.IsHold) && written.All(note => note.Lane == 2),
            "every generated note is a tap in the long note's own lane");
        Require(
            written.All(note => note.Group == 3),
            "the group assignment survives the conversion");
        Require(
            written[0].Id == hold.Id &&
            Math.Abs(written[0].Beat.Value - 4) < 1e-9 &&
            Math.Abs(written[^1].Beat.Value - 12) < 1e-9,
            $"the original head is reused and the last note lands on the old tail (got {written[0].Beat.Value:0.####} .. {written[^1].Beat.Value:0.####})");
        Require(
            written.All(note => Math.Abs(note.Beat.Value * 1440 -
                                         Math.Round(note.Beat.Value * 1440)) < 1e-6),
            "every written position sits on the 1/1440 grid Malody can store");

        // A note already sitting in the lane must not be overwritten. A flat
        // one-beat grid is used so a generated position is guaranteed to land on
        // the occupant; with a curved grid the collision would be a coincidence.
        var blockedHold = new ChartNote
        {
            Lane = 2,
            Beat = BeatPosition.Preserve(4, 0, 1),
            EndBeat = BeatPosition.Preserve(12, 0, 1)
        };
        var occupant = new ChartNote { Lane = 2, Beat = BeatPosition.Preserve(6, 0, 1) };
        var blockedDocument = new ChartDocument
        {
            KeyCount = 4,
            Notes = [blockedHold, occupant]
        };
        var blocked = CurveDensityService.FillCurveDensity(
            blockedDocument,
            new HashSet<Guid> { blockedHold.Id },
            new CurveDensityOptions(CurveDensityShape.DenseSparseDense, 1, 1));
        Require(
            blocked.SkippedCount >= 1 &&
            blockedDocument.Notes.Count(note =>
                note.Lane == 2 && Math.Abs(note.Beat.Value - 6) < 1e-9) == 1,
            $"an existing note in the lane is skipped, not replaced (skipped {blocked.SkippedCount})");

        var tapOnly = new ChartDocument
        {
            KeyCount = 4,
            Notes = [new ChartNote { Lane = 0, Beat = BeatPosition.Zero }]
        };
        var none = CurveDensityService.FillCurveDensity(
            tapOnly,
            new HashSet<Guid> { tapOnly.Notes[0].Id },
            new CurveDensityOptions(CurveDensityShape.DenseSparseDense, 16, 1));
        Require(
            none.ConvertedCount == 0 && none.CreatedCount == 0,
            "selecting taps does nothing, because only a long note defines a range");
    }

    /// <summary>
    /// Lane arrangements: the same curve, only the column of each note changes.
    /// " stairs" walks 1→2→3→4→1, "alternate" swings 1→2→1→2, and both count
    /// from the source long note's own column.
    /// </summary>
    private static void VerifySpreadAcrossLanes()
    {
        static ChartNote Source(int lane) => new()
        {
            Lane = lane,
            Group = 1,
            Beat = BeatPosition.Preserve(4, 0, 1),
            EndBeat = BeatPosition.Preserve(12, 0, 1)
        };

        var hold = Source(0);
        var document = new ChartDocument { KeyCount = 4, Notes = [hold] };
        var spread = CurveDensityService.FillCurveDensity(
            document,
            new HashSet<Guid> { hold.Id },
            new CurveDensityOptions(
                CurveDensityShape.DenseSparseDense,
                16,
                1,
                LaneArrangement: CurveLaneArrangement.Stairs));
        var written = document.Notes.OrderBy(note => note.Beat).ToArray();
        var lanes = written.Skip(1).Select(note => note.Lane).ToArray();
        Require(
            spread.CreatedCount > 10 && written.All(note => !note.IsHold),
            $"spread mode still produces a tap stream (created {spread.CreatedCount})");
        Require(
            written[0].Lane == 0,
            "the reused head keeps the source lane, so the curve still starts where the long note was");
        Require(
            lanes.Select((lane, index) => lane == (index + 1) % 4).All(ok => ok),
            $"lanes walk 1→2→3→4→1 (got {string.Join(',', lanes.Take(10).Select(l => l + 1))})");

        // Starting on lane 3 must run 4→1→2→3, not reset to lane 1.
        var offCentre = Source(2);
        var offCentreDocument = new ChartDocument { KeyCount = 4, Notes = [offCentre] };
        CurveDensityService.FillCurveDensity(
            offCentreDocument,
            new HashSet<Guid> { offCentre.Id },
            new CurveDensityOptions(
                CurveDensityShape.DenseSparseDense,
                16,
                1,
                LaneArrangement: CurveLaneArrangement.Stairs));
        var offCentreLanes = offCentreDocument.Notes
            .OrderBy(note => note.Beat)
            .Skip(1)
            .Take(4)
            .Select(note => note.Lane)
            .ToArray();
        Require(
            offCentreLanes.SequenceEqual([3, 0, 1, 2]),
            $"a source on lane 3 walks 4→1→2→3 (got {string.Join(',', offCentreLanes.Select(l => l + 1))})");

        // Same range, same settings, only the spread flag differs: the count
        // has to match, otherwise the flag is changing the curve itself.
        var plainHold = Source(0);
        var plainDocument = new ChartDocument { KeyCount = 4, Notes = [plainHold] };
        var plain = CurveDensityService.FillCurveDensity(
            plainDocument,
            new HashSet<Guid> { plainHold.Id },
            new CurveDensityOptions(CurveDensityShape.DenseSparseDense, 16, 1));
        Require(
            plain.CreatedCount == spread.CreatedCount,
            $"spreading changes only the lane, not the note count (plain {plain.CreatedCount}, spread {spread.CreatedCount})");

        // Alternate swings between the source column and the next one: 1→2→1→2.
        var swingHold = Source(0);
        var swingDocument = new ChartDocument { KeyCount = 4, Notes = [swingHold] };
        CurveDensityService.FillCurveDensity(
            swingDocument,
            new HashSet<Guid> { swingHold.Id },
            new CurveDensityOptions(
                CurveDensityShape.DenseSparseDense,
                16,
                1,
                LaneArrangement: CurveLaneArrangement.Alternate));
        var swingLanes = swingDocument.Notes
            .OrderBy(note => note.Beat)
            .Skip(1)
            .Take(6)
            .Select(note => note.Lane)
            .ToArray();
        Require(
            swingLanes.SequenceEqual([1, 0, 1, 0, 1, 0]),
            $"alternate swings 2→1→2→1 from a source on lane 1 (got {string.Join(',', swingLanes.Select(l => l + 1))})");

        // Started from lane 3 it swings 4→3, not 2→1: the pairing is relative
        // to where the long note was, same as stairs.
        var swingCentre = Source(2);
        var swingCentreDocument = new ChartDocument { KeyCount = 4, Notes = [swingCentre] };
        CurveDensityService.FillCurveDensity(
            swingCentreDocument,
            new HashSet<Guid> { swingCentre.Id },
            new CurveDensityOptions(
                CurveDensityShape.DenseSparseDense,
                16,
                1,
                LaneArrangement: CurveLaneArrangement.Alternate));
        var swingCentreLanes = swingCentreDocument.Notes
            .OrderBy(note => note.Beat)
            .Skip(1)
            .Take(4)
            .Select(note => note.Lane)
            .ToArray();
        Require(
            swingCentreLanes.SequenceEqual([3, 2, 3, 2]),
            $"a source on lane 3 alternates 4→3→4→3 (got {string.Join(',', swingCentreLanes.Select(l => l + 1))})");

        // A one-key chart has nowhere to spread to; it must not divide by it.
        var monoHold = Source(0);
        var monoDocument = new ChartDocument { KeyCount = 1, Notes = [monoHold] };
        var mono = CurveDensityService.FillCurveDensity(
            monoDocument,
            new HashSet<Guid> { monoHold.Id },
            new CurveDensityOptions(
                CurveDensityShape.DenseSparseDense,
                16,
                1,
                LaneArrangement: CurveLaneArrangement.Stairs));
        Require(
            mono.CreatedCount > 0 && monoDocument.Notes.All(note => note.Lane == 0),
            $"a 1-key chart ignores the arrangement instead of dividing by zero (created {mono.CreatedCount})");
    }

    private static double[] Gaps(IReadOnlyList<double> offsets)
    {
        var gaps = new double[offsets.Count - 1];
        for (var index = 0; index < gaps.Length; index++)
            gaps[index] = offsets[index + 1] - offsets[index];
        return gaps;
    }

    private static int CountForwardSteps(IEnumerable<double> gaps)
    {
        var previous = double.NaN;
        var forward = 0;
        foreach (var gap in gaps)
        {
            if (!double.IsNaN(previous) && gap >= previous - 1e-9) forward++;
            previous = gap;
        }
        return forward;
    }

    private static int Count;

    private static void Require(bool condition, string message)
    {
        Count++;
        if (condition)
        {
            Console.WriteLine($"  ok    {message}");
            return;
        }
        Console.WriteLine($"  FAIL  {message}");
        throw new InvalidOperationException("Curve density contract failed: " + message);
    }
}
