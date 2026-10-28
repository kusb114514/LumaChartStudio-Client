using LumaChart.Core.Editing;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Specs;

/// <summary>
/// Tap pairing builds a hold from the two taps the player pointed at: the earlier
/// one is the head, the later one is the tail and stops existing as a tap. The
/// checks below pin down which taps pair up, what happens to a tap without a
/// partner, and that nothing else in the chart is disturbed.
/// </summary>
internal static class TapPairToLongSpecs
{
    public static int Run()
    {
        try
        {
            VerifyPairBecomesOneHold();
            VerifyColumnsAreIndependent();
            VerifyLeftoverTapIsUntouched();
            VerifyHoldEndpointsAreIgnored();
            VerifySamePositionPairIsRefused();
            VerifyHeadKeepsItsOwnProperties();
            VerifyGuards();
            Console.WriteLine($"Tap pair contracts: passed ({Count} checks)");
            return 0;
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine(exception);
            Console.Error.WriteLine($"Tap pair contracts: failed after {Count} checks");
            return 1;
        }
    }

    private static void VerifyPairBecomesOneHold()
    {
        var head = Tap(lane: 0, beat: 1);
        var tail = Tap(lane: 0, beat: 5);
        var document = new ChartDocument { KeyCount = 4, Notes = [head, tail] };
        var result = NoteTypeTransformService.ConvertTapPairsToLongNotes(
            document,
            new HashSet<Guid> { head.Id, tail.Id });

        Require(
            result.ConvertedCount == 1 && result.SkippedCount == 0,
            $"one pair makes one hold (converted {result.ConvertedCount}, skipped {result.SkippedCount})");
        Require(
            document.Notes.Count == 1 && document.Notes[0].Id == head.Id,
            $"the tail tap is folded into the head instead of staying beside it ({document.Notes.Count} notes left)");
        Require(
            document.Notes[0].IsHold &&
            Math.Abs(document.Notes[0].Beat.Value - 1) < 1e-9 &&
            Math.Abs(document.Notes[0].EndBeat!.Value.Value - 5) < 1e-9,
            $"the earlier tap is the head and the later one the tail (got {Positions(document.Notes)})");
        Require(
            result.Selection.SetEquals([head.Id]),
            $"the finished hold is what stays selected ({result.Selection.Count} selected)");
    }

    private static void VerifyColumnsAreIndependent()
    {
        // Two pairs on two lanes are handled in one run; pairing never looks
        // across lanes even though the beats interleave.
        var a0 = Tap(lane: 0, beat: 0);
        var a1 = Tap(lane: 0, beat: 4);
        var b0 = Tap(lane: 2, beat: 2);
        var b1 = Tap(lane: 2, beat: 6);
        var document = new ChartDocument { KeyCount = 4, Notes = [a0, a1, b0, b1] };
        var result = NoteTypeTransformService.ConvertTapPairsToLongNotes(
            document,
            new HashSet<Guid> { a0.Id, a1.Id, b0.Id, b1.Id });

        Require(
            result.ConvertedCount == 2 && document.Notes.Count == 2,
            $"each lane pairs on its own (converted {result.ConvertedCount}, {document.Notes.Count} notes left)");
        Require(
            document.Notes.All(note => note.IsHold) &&
            document.Notes.Single(note => note.Lane == 0).EndBeat!.Value.Value == 4 &&
            document.Notes.Single(note => note.Lane == 2).EndBeat!.Value.Value == 6,
            $"both holds keep their own lane and range (got {Positions(document.Notes)})");
    }

    private static void VerifyLeftoverTapIsUntouched()
    {
        var first = Tap(lane: 1, beat: 0);
        var second = Tap(lane: 1, beat: 4);
        var third = Tap(lane: 1, beat: 8);
        var document = new ChartDocument { KeyCount = 4, Notes = [first, second, third] };
        var result = NoteTypeTransformService.ConvertTapPairsToLongNotes(
            document,
            new HashSet<Guid> { first.Id, second.Id, third.Id });

        Require(
            result.ConvertedCount == 1 && result.SkippedCount == 1,
            $"three taps make one hold plus one unpaired tap (converted {result.ConvertedCount}, skipped {result.SkippedCount})");
        Require(
            document.Notes.Count == 2 &&
            document.Notes.Single(note => !note.IsHold).Id == third.Id &&
            Math.Abs(document.Notes.Single(note => !note.IsHold).Beat.Value - 8) < 1e-9,
            $"the tap without a partner keeps its own type and position (got {Positions(document.Notes)})");
        Require(
            result.Selection.Contains(first.Id) && result.Selection.Contains(third.Id),
            "the unpaired tap stays selected so it is visible as the odd one");
    }

    private static void VerifyHoldEndpointsAreIgnored()
    {
        // An existing hold cannot be a head or a tail; only taps pair up.
        var existing = new ChartNote
        {
            Lane = 0,
            Beat = BeatPosition.Preserve(0, 0, 1),
            EndBeat = BeatPosition.Preserve(2, 0, 1)
        };
        var a = Tap(lane: 0, beat: 4);
        var b = Tap(lane: 0, beat: 8);
        var document = new ChartDocument { KeyCount = 4, Notes = [existing, a, b] };
        var result = NoteTypeTransformService.ConvertTapPairsToLongNotes(
            document,
            new HashSet<Guid> { existing.Id, a.Id, b.Id });

        Require(
            result.ConvertedCount == 1,
            $"the two taps pair with each other rather than with the existing hold (converted {result.ConvertedCount})");
        Require(
            document.Notes.Count == 2 &&
            document.Notes.Single(note => note.Id == existing.Id).EndBeat!.Value.Value == 2 &&
            document.Notes.Single(note => note.Id == a.Id).EndBeat!.Value.Value == 8,
            $"the existing hold is left exactly as it was (got {Positions(document.Notes)})");
    }

    private static void VerifySamePositionPairIsRefused()
    {
        // Two taps on the same beat would make an endbeat the renderer still
        // shows as a tap, i.e. a conversion that looks like nothing happened.
        var head = Tap(lane: 3, beat: 6);
        var tail = Tap(lane: 3, beat: 6);
        var document = new ChartDocument { KeyCount = 4, Notes = [head, tail] };
        var result = NoteTypeTransformService.ConvertTapPairsToLongNotes(
            document,
            new HashSet<Guid> { head.Id, tail.Id });

        Require(
            result.ConvertedCount == 0 && result.SkippedCount == 2,
            $"a zero-length pair is refused (converted {result.ConvertedCount}, skipped {result.SkippedCount})");
        Require(
            document.Notes.Count == 2 && document.Notes.All(note => !note.IsHold),
            "both taps of a refused pair survive untouched");

        // Just above the minimum hold length it does convert, so the cutoff is
        // the renderer's threshold and not an arbitrary one.
        var shortHead = Tap(lane: 3, beat: 10);
        var shortTail = Tap(lane: 3, beat: 10 + ChartNote.MinimumHoldLength * 2);
        var shortDocument = new ChartDocument { KeyCount = 4, Notes = [shortHead, shortTail] };
        var shortResult = NoteTypeTransformService.ConvertTapPairsToLongNotes(
            shortDocument,
            new HashSet<Guid> { shortHead.Id, shortTail.Id });
        Require(
            shortResult.ConvertedCount == 1,
            $"a pair above the minimum hold length converts (converted {shortResult.ConvertedCount})");
    }

    private static void VerifyHeadKeepsItsOwnProperties()
    {
        var head = Tap(lane: 2, beat: 3, group: 7);
        head.Sound = "clap";
        head.Volume = 55;
        var tail = Tap(lane: 2, beat: 9, group: 4);
        var document = new ChartDocument { KeyCount = 4, Notes = [head, tail] };
        NoteTypeTransformService.ConvertTapPairsToLongNotes(
            document,
            new HashSet<Guid> { head.Id, tail.Id });

        var hold = document.Notes.Single();
        Require(
            hold.Group == 7 && hold.Sound == "clap" && hold.Volume == 55,
            $"group, sound and volume come from the head, not the tail (group {hold.Group}, sound {hold.Sound}, volume {hold.Volume})");
    }

    private static void VerifyGuards()
    {
        // An empty selection is a no-op, not an exception.
        var document = new ChartDocument { KeyCount = 4, Notes = [Tap(0, 0), Tap(0, 4)] };
        var empty = NoteTypeTransformService.ConvertTapPairsToLongNotes(
            document,
            new HashSet<Guid>());
        Require(
            empty.ConvertedCount == 0 && document.Notes.Count == 2 &&
            document.Notes.All(note => !note.IsHold),
            "an empty selection writes nothing");

        // Unselected notes never take part, even when they sit between the pair.
        var head = Tap(lane: 0, beat: 0);
        var tail = Tap(lane: 0, beat: 8);
        var between = Tap(lane: 0, beat: 4);
        var mixed = new ChartDocument { KeyCount = 4, Notes = [head, between, tail] };
        var result = NoteTypeTransformService.ConvertTapPairsToLongNotes(
            mixed,
            new HashSet<Guid> { head.Id, tail.Id });
        Require(
            result.ConvertedCount == 1 && mixed.Notes.Count == 2 &&
            mixed.Notes.Single(note => note.Id == between.Id).Beat.Value == 4,
            $"the marked pair spans the range even with an unselected note inside (converted {result.ConvertedCount})");
        Require(
            Math.Abs(mixed.Notes.Single(note => note.IsHold).EndBeat!.Value.Value - 8) < 1e-9,
            "the hold ends on the later selected tap, not on the note in between");
    }

    private static ChartNote Tap(int lane, double beat, int group = 0) => new()
    {
        Lane = lane,
        Group = group,
        Beat = BeatPosition.FromDouble(beat, NoteGapFillService.MalodyDenominator)
    };

    private static string Positions(IEnumerable<ChartNote> notes) =>
        string.Join(", ", notes.Select(note => note.IsHold
            ? $"{note.Beat.Value:0.###}-{note.EndBeat!.Value.Value:0.###}"
            : note.Beat.Value.ToString("0.###")));

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
        throw new InvalidOperationException("Tap pair contract failed: " + message);
    }
}
