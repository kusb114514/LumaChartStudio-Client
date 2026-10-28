using LumaChart.Core.Editing;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Specs;

/// <summary>
/// Gap fill is a plain even division, so the checks are about the spacing
/// itself: equal steps, the requested count, no position off the grid Malody
/// can store, and nothing overwritten. The preview has to agree with the run,
/// because the panel shows that count before the user commits.
/// </summary>
internal static class GapFillSpecs
{
    public static int Run()
    {
        try
        {
            VerifyEvenSpacing();
            VerifyFractionalStepStaysOnGrid();
            VerifyExistingNotesAreSkipped();
            VerifyPairsComeFromNeighbours();
            VerifyGuards();
            VerifyPlanMatchesRun();
            Console.WriteLine($"Gap fill contracts: passed ({Count} checks)");
            return 0;
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine(exception);
            Console.Error.WriteLine($"Gap fill contracts: failed after {Count} checks");
            return 1;
        }
    }

    private static void VerifyEvenSpacing()
    {
        var start = Tap(lane: 0, beat: 1, group: 2);
        var end = Tap(lane: 0, beat: 5, group: 9);
        var document = new ChartDocument { KeyCount = 4, Notes = [start, end] };
        var result = NoteGapFillService.FillGaps(
            document,
            new HashSet<Guid> { start.Id, end.Id },
            insertCount: 3);

        var written = document.Notes.OrderBy(note => note.Beat.Value).ToArray();
        Require(
            result.CreatedCount == 3 && written.Length == 5,
            $"three notes land between the pair (created {result.CreatedCount})");
        Require(
            written.Select(note => note.Beat.Value)
                .SequenceEqual(
                    new double[] { 1, 2, 3, 4, 5 },
                    comparer: new Nearly()),
            $"a 4 beat gap with 3 notes is one beat per step (got {Positions(written)})");
        Require(
            written.All(note => !note.IsHold) && written.All(note => note.Lane == 0),
            "every inserted note is a tap in the pair's own lane");
        // The start note's group wins for the inserted run; the user's own end
        // note keeps whatever group it already had.
        Require(
            written.Take(4).All(note => note.Group == 2) && written[^1].Group == 9,
            $"the inserted notes take the group of the note they sit behind (got {string.Join(',', written.Select(n => n.Group))})");
        Require(
            result.Selection.Contains(start.Id) &&
            result.Selection.Contains(end.Id) &&
            result.Selection.Count == 5,
            $"the pair stays selected together with what was inserted ({result.Selection.Count} selected)");
    }

    private static void VerifyFractionalStepStaysOnGrid()
    {
        // 4 beats split into three: each step is 1 + 1/3, which cannot be
        // written as a decimal beat but has an exact denominator Malody keeps.
        var start = Tap(lane: 1, beat: 4);
        var end = Tap(lane: 1, beat: 8);
        var document = new ChartDocument { KeyCount = 4, Notes = [start, end] };
        NoteGapFillService.FillGaps(
            document,
            new HashSet<Guid> { start.Id, end.Id },
            insertCount: 2);

        var written = document.Notes.OrderBy(note => note.Beat.Value).ToArray();
        Require(
            written.Select(note => note.Beat.Value)
                .SequenceEqual(
                    new double[] { 4, 4 + 4d / 3, 4 + 8d / 3, 8 },
                    comparer: new Nearly()),
            $"two notes over 4 beats sit at thirds (got {Positions(written)})");
        Require(
            written.All(note => Math.Abs(note.Beat.Value * NoteGapFillService.MalodyDenominator -
                                         Math.Round(note.Beat.Value * NoteGapFillService.MalodyDenominator)) < 1e-6),
            "every written position sits on the 1/1440 grid Malody can store");
    }

    private static void VerifyExistingNotesAreSkipped()
    {
        var start = Tap(lane: 2, beat: 1);
        var end = Tap(lane: 2, beat: 5);
        var occupant = Tap(lane: 2, beat: 3);
        var document = new ChartDocument { KeyCount = 4, Notes = [start, end, occupant] };
        var result = NoteGapFillService.FillGaps(
            document,
            new HashSet<Guid> { start.Id, end.Id },
            insertCount: 3);

        var written = document.Notes.OrderBy(note => note.Beat.Value).ToArray();
        Require(
            result.CreatedCount == 2 && result.SkippedCount == 1,
            $"the occupied cell is skipped, not replaced (created {result.CreatedCount}, skipped {result.SkippedCount})");
        Require(
            written.Count(note => Math.Abs(note.Beat.Value - 3) < 1e-9) == 1,
            "the note that was already at 3 beats is still exactly one note");
    }

    private static void VerifyPairsComeFromNeighbours()
    {
        // Three taps on one lane means two gaps, four means three.
        var a = Tap(lane: 0, beat: 0);
        var b = Tap(lane: 0, beat: 4);
        var c = Tap(lane: 0, beat: 8);
        var document = new ChartDocument { KeyCount = 4, Notes = [a, b, c] };
        var result = NoteGapFillService.FillGaps(
            document,
            new HashSet<Guid> { a.Id, b.Id, c.Id },
            insertCount: 1);
        Require(
            result.ConvertedCount == 2 && result.CreatedCount == 2,
            $"three taps in a lane fill both neighbouring gaps (pairs {result.ConvertedCount}, created {result.CreatedCount})");
        Require(
            document.Notes.Select(note => note.Beat.Value).Order()
                .SequenceEqual(new double[] { 0, 2, 4, 6, 8 }, comparer: new Nearly()),
            $"the filled positions are the two midpoints (got {Positions(document.Notes.OrderBy(n => n.Beat.Value))})");

        // A tap on another lane is a separate run, so a lone tap there pairs
        // with nobody and inserts nothing.
        var other = Tap(lane: 3, beat: 2);
        var mixed = new ChartDocument { KeyCount = 4, Notes = [a, b, other] };
        var mixedResult = NoteGapFillService.FillGaps(
            mixed,
            new HashSet<Guid> { a.Id, b.Id, other.Id },
            insertCount: 2);
        Require(
            mixedResult.ConvertedCount == 1 && mixedResult.CreatedCount == 2,
            $"a lone tap on another lane inserts nothing (pairs {mixedResult.ConvertedCount}, created {mixedResult.CreatedCount})");

        // Long notes are not endpoints: only taps define a gap.
        var hold = new ChartNote
        {
            Lane = 1,
            Beat = BeatPosition.Preserve(0, 0, 1),
            EndBeat = BeatPosition.Preserve(4, 0, 1)
        };
        var holdEndTap = Tap(lane: 1, beat: 8);
        var withHold = new ChartDocument { KeyCount = 4, Notes = [hold, holdEndTap] };
        var holdResult = NoteGapFillService.FillGaps(
            withHold,
            new HashSet<Guid> { hold.Id, holdEndTap.Id },
            insertCount: 2);
        Require(
            holdResult.CreatedCount == 0,
            "a long note is not treated as the start of a gap");
    }

    private static void VerifyGuards()
    {
        // Two 1/1440 cells cannot hold three notes in between.
        var start = Tap(lane: 0, beat: 0);
        var end = Tap(lane: 0, beat: 2d / NoteGapFillService.MalodyDenominator);
        var document = new ChartDocument { KeyCount = 4, Notes = [start, end] };
        var plan = NoteGapFillService.PlanGapFill(
            document,
            new HashSet<Guid> { start.Id, end.Id },
            insertCount: 3);
        Require(
            plan.Pairs == 0 && plan.Notes == 0 && plan.TooShort == 1,
            $"a gap too short for the count is refused instead of stacking notes (pairs {plan.Pairs}, tooShort {plan.TooShort})");

        // Out-of-range counts are clamped rather than throwing: the box is a
        // free-text field, and 0 or 999 is a slip, not an intent.
        var wide = new ChartDocument
        {
            KeyCount = 4,
            Notes = [Tap(lane: 0, beat: 0), Tap(lane: 0, beat: 16)]
        };
        var ids = wide.Notes.Select(note => note.Id).ToHashSet();
        var clampedLow = NoteGapFillService.PlanGapFill(wide, ids, 0);
        var clampedHigh = NoteGapFillService.PlanGapFill(wide, ids, 999);
        Require(
            clampedLow.Notes == NoteGapFillService.MinimumCount &&
            clampedHigh.Notes == NoteGapFillService.MaximumCount,
            $"counts outside 1–{NoteGapFillService.MaximumCount} are clamped (0 → {clampedLow.Notes}, 999 → {clampedHigh.Notes})");

        // Nothing selected is a no-op, not an exception.
        var empty = NoteGapFillService.FillGaps(wide, new HashSet<Guid>(), 2);
        Require(
            empty.CreatedCount == 0 && wide.Notes.Count == 2,
            "an empty selection writes nothing");
    }

    private static void VerifyPlanMatchesRun()
    {
        var a = Tap(lane: 0, beat: 0);
        var b = Tap(lane: 0, beat: 6);
        var c = Tap(lane: 1, beat: 2);
        var d = Tap(lane: 1, beat: 3);
        // One position of the second lane is already taken (2 + 1/3, exactly
        // where the first inserted note would go), so the plan has to count it
        // as skipped instead of promising it.
        var occupant = Tap(lane: 1, beat: 2 + 1d / 3);
        var document = new ChartDocument { KeyCount = 4, Notes = [a, b, c, d] };
        var ids = new HashSet<Guid> { a.Id, b.Id, c.Id, d.Id };
        var plan = NoteGapFillService.PlanGapFill(document, ids, 2);

        document.Notes.Add(occupant);
        ids = new HashSet<Guid> { a.Id, b.Id, c.Id, d.Id };
        var withOccupantPlan = NoteGapFillService.PlanGapFill(document, ids, 2);
        var result = NoteGapFillService.FillGaps(document, ids, 2);

        Require(
            withOccupantPlan.Notes == result.CreatedCount,
            $"the preview count matches what the run creates (plan {withOccupantPlan.Notes}, created {result.CreatedCount})");
        Require(
            withOccupantPlan.Blocked == result.SkippedCount && withOccupantPlan.Blocked == 1,
            $"the plan reports the blocked cells the run skips (blocked {withOccupantPlan.Blocked}, skipped {result.SkippedCount})");
        Require(
            plan.Notes == 4,
            $"without the occupant every requested note fits (planned {plan.Notes})");
    }

    private static ChartNote Tap(int lane, double beat, int group = 0) => new()
    {
        Lane = lane,
        Group = group,
        Beat = BeatPosition.FromDouble(beat, NoteGapFillService.MalodyDenominator)
    };

    private static string Positions(IEnumerable<ChartNote> notes) =>
        string.Join(", ", notes.Select(note => note.Beat.Value.ToString("0.###")));

    private sealed class Nearly : IEqualityComparer<double>
    {
        public bool Equals(double x, double y) => Math.Abs(x - y) < 1e-9;

        public int GetHashCode(double value) => 0;
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
        throw new InvalidOperationException("Gap fill contract failed: " + message);
    }
}
