using LumaChart.Core.Models;

namespace LumaChart.Core.Editing;

public enum LongNoteToTapMode
{
    IncludeTail,
    Fill,
    HeadOnly
}

public sealed record NoteTransformResult(
    int ConvertedCount,
    int CreatedCount,
    int SkippedCount,
    IReadOnlySet<Guid> Selection);

/// <summary>
/// Deterministic note-type conversions shared by the desktop editor and future
/// mobile clients. Callers are responsible for filtering hidden/locked notes
/// before passing the selection.
/// </summary>
public static class NoteTypeTransformService
{
    public static NoteTransformResult ConvertLongNotesToTaps(
        ChartDocument document,
        IReadOnlySet<Guid> selectedIds,
        int division,
        LongNoteToTapMode mode)
    {
        division = Math.Clamp(division, 1, 1920);
        var selectedLongNotes = document.Notes
            .Where(note => selectedIds.Contains(note.Id) && note.IsHold)
            .OrderBy(note => note.Beat)
            .ToArray();
        var nextSelection = new HashSet<Guid>();
        var converted = 0;
        var created = 0;
        var skipped = 0;

        foreach (var note in selectedLongNotes)
        {
            var tail = note.EndBeat!.Value;
            note.EndBeat = null;
            nextSelection.Add(note.Id);
            converted++;

            IEnumerable<BeatPosition> additions = mode switch
            {
                LongNoteToTapMode.HeadOnly => [],
                LongNoteToTapMode.IncludeTail => [tail],
                _ => FillPositions(note.Beat, tail, ResolveFillDivision(division))
            };

            foreach (var beat in additions)
            {
                if (beat.CompareTo(note.Beat) <= 0 ||
                    HasNoteAt(document.Notes, note, beat))
                {
                    skipped++;
                    continue;
                }

                var tap = note.Clone();
                tap.Id = Guid.NewGuid();
                tap.Beat = beat;
                tap.EndBeat = null;
                document.Notes.Add(tap);
                nextSelection.Add(tap.Id);
                created++;
            }
        }

        return new NoteTransformResult(converted, created, skipped, nextSelection);
    }

    public static NoteTransformResult ConvertTapsToLongNotes(
        ChartDocument document,
        IReadOnlySet<Guid> selectedIds,
        int division)
    {
        division = Math.Clamp(division, 1, 1920);
        // Resolve every boundary from the pre-edit chart so converting one tap
        // cannot change the next tap's result in the same batch.
        var allNotes = document.Notes.ToArray();
        var selectedTaps = allNotes
            .Where(note => selectedIds.Contains(note.Id) && !note.IsHold)
            .OrderBy(note => note.Beat)
            .ToArray();
        var nextSelection = new HashSet<Guid>();
        var converted = 0;
        var skipped = 0;

        foreach (var note in selectedTaps)
        {
            var next = allNotes
                .Where(candidate => candidate.Id != note.Id && SameColumn(candidate, note) &&
                                    candidate.Beat.CompareTo(note.Beat) > 0)
                .OrderBy(candidate => candidate.Beat)
                .FirstOrDefault();
            if (next == null)
            {
                skipped++;
                continue;
            }

            var tail = SubtractGridUnit(next.Beat, division);
            if (tail.CompareTo(note.Beat) <= 0)
            {
                skipped++;
                continue;
            }

            note.EndBeat = tail;
            nextSelection.Add(note.Id);
            converted++;
        }

        return new NoteTransformResult(converted, 0, skipped, nextSelection);
    }

    /// <summary>
    /// Links neighbouring taps of one column into holds: the earlier tap stays as
    /// the head, the later one becomes the tail and is folded into it. Selection
    /// order does not matter — each column is read top to bottom and consumed two
    /// at a time, so a tap left without a partner afterwards keeps its own type.
    /// </summary>
    public static NoteTransformResult ConvertTapPairsToLongNotes(
        ChartDocument document,
        IReadOnlySet<Guid> selectedIds)
    {
        var byColumn = document.Notes
            .Where(note => selectedIds.Contains(note.Id) && !note.IsHold && !note.IsDraft)
            .GroupBy(note => note.Lane)
            .ToArray();

        var nextSelection = new HashSet<Guid>();
        var converted = 0;
        var skipped = 0;

        foreach (var column in byColumn)
        {
            var ordered = column.OrderBy(note => note.Beat).ToArray();
            for (var index = 0; index + 1 < ordered.Length; index += 2)
            {
                var head = ordered[index];
                var tail = ordered[index + 1];
                // Two taps can share (or nearly share) a beat in a hand-edited
                // chart. An endbeat that short is shown as a tap by the renderer,
                // so writing one would look like nothing happened.
                if (tail.Beat.Value - head.Beat.Value <= ChartNote.MinimumHoldLength)
                {
                    nextSelection.Add(head.Id);
                    nextSelection.Add(tail.Id);
                    skipped += 2;
                    continue;
                }

                head.EndBeat = tail.Beat;
                document.Notes.Remove(tail);
                nextSelection.Add(head.Id);
                converted++;
            }

            if (ordered.Length % 2 == 1)
            {
                // The odd one out stays a tap; keeping it selected shows which one
                // had no partner instead of silently dropping it from the result.
                nextSelection.Add(ordered[^1].Id);
                skipped++;
            }
        }

        return new NoteTransformResult(converted, 0, skipped, nextSelection);
    }

    /// <summary>Subdivision used by Fill when the active one is too fine to be a rhythm.</summary>
    private const int FillFallbackDivision = 4;

    /// <summary>
    /// Above this the active subdivision stops describing a playable stream.
    /// Un-snap (1/1440) is the extreme case: filling a four-beat hold at that
    /// step would emit 5760 notes all within a few milliseconds of each other —
    /// technically valid data, useless as a chart, and slow enough to stall the
    /// editor. Filling keeps the active subdivision up to here and falls back to
    /// quarter beats beyond it.
    /// </summary>
    private const int FillDivisionCeiling = 96;

    private static int ResolveFillDivision(int division) =>
        division > FillDivisionCeiling ? FillFallbackDivision : division;

    private static IEnumerable<BeatPosition> FillPositions(
        BeatPosition head,
        BeatPosition tail,
        int division)
    {        var step = 1d / division;
        for (var index = 1; index <= 2_000_000; index++)
        {
            var value = head.Value + index * step;
            if (value > tail.Value + 1e-9) yield break;
            var position = BeatPosition.FromDouble(value, division * Math.Max(1, head.Denominator) <= 1920
                ? division * Math.Max(1, head.Denominator)
                : 1920);
            if (position.CompareTo(tail) > 0) yield break;
            yield return position;
        }
    }

    private static BeatPosition SubtractGridUnit(BeatPosition beat, int division)
    {
        var precision = LeastCommonMultipleWithinLimit(beat.Denominator, division, 1920);
        return BeatPosition.FromDouble(beat.Value - 1d / division, precision);
    }

    private static int LeastCommonMultipleWithinLimit(int left, int right, int limit)
    {
        var gcd = GreatestCommonDivisor(left, right);
        var candidate = (long)left / gcd * right;
        return candidate is > 0 and <= 1920 ? (int)candidate : limit;
    }

    private static int GreatestCommonDivisor(int left, int right)
    {
        left = Math.Abs(left);
        right = Math.Abs(right);
        while (right != 0) (left, right) = (right, left % right);
        return Math.Max(1, left);
    }

    private static bool HasNoteAt(IEnumerable<ChartNote> notes, ChartNote source, BeatPosition beat) =>
        notes.Any(candidate => SameColumn(candidate, source) && candidate.Beat.CompareTo(beat) == 0);

    private static bool SameColumn(ChartNote left, ChartNote right) =>
        left.IsDraft == right.IsDraft &&
        (left.IsDraft ? left.DraftColumn == right.DraftColumn : left.Lane == right.Lane);
}
