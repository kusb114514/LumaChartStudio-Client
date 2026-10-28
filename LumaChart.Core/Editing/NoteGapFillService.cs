using LumaChart.Core.Models;

namespace LumaChart.Core.Editing;

/// <summary>What one gap fill would do, computed without touching the document.</summary>
/// <param name="Pairs">Selected tap pairs that have room for the requested count.</param>
/// <param name="Notes">Notes that would actually be created.</param>
/// <param name="Blocked">Positions left alone because a note is already there.</param>
/// <param name="TooShort">Pairs skipped because the gap cannot hold that many notes.</param>
public readonly record struct GapFillPlan(int Pairs, int Notes, int Blocked, int TooShort);

/// <summary>
/// Puts evenly spaced notes between two taps of the same lane. The pairs come
/// from the selection: every two neighbouring selected taps in one lane define
/// one gap, so three selected taps on a lane fill the two gaps between them.
/// </summary>
public static class NoteGapFillService
{
    /// <summary>
    /// Malody stores beat denominators up to 1440, so inserting more notes than
    /// the range has 1/1440 cells would produce positions the file cannot keep.
    /// </summary>
    public const int MalodyDenominator = 1440;

    public const int MinimumCount = 1;
    public const int MaximumCount = 32;

    public static NoteTransformResult FillGaps(
        ChartDocument document,
        IReadOnlySet<Guid> selectedIds,
        int insertCount)
    {
        ArgumentNullException.ThrowIfNull(document);
        ArgumentNullException.ThrowIfNull(selectedIds);
        insertCount = Math.Clamp(insertCount, MinimumCount, MaximumCount);
        var placements = ComputePlacements(
            document,
            selectedIds,
            insertCount,
            out var pairs,
            out _);

        var nextSelection = new HashSet<Guid>(selectedIds);
        var created = 0;
        var blocked = 0;
        foreach (var placement in placements)
        {
            if (placement.Blocked)
            {
                blocked++;
                continue;
            }
            // Group, sound and volume follow the head of the pair: an inserted
            // note belongs to the same run as the note it sits behind.
            var note = placement.Source.Clone();
            note.Id = Guid.NewGuid();
            note.Beat = placement.Beat;
            note.EndBeat = null;
            document.Notes.Add(note);
            nextSelection.Add(note.Id);
            created++;
        }

        return new NoteTransformResult(pairs, created, blocked, nextSelection);
    }

    public static GapFillPlan PlanGapFill(
        ChartDocument document,
        IReadOnlySet<Guid> selectedIds,
        int insertCount)
    {
        ArgumentNullException.ThrowIfNull(document);
        ArgumentNullException.ThrowIfNull(selectedIds);
        insertCount = Math.Clamp(insertCount, MinimumCount, MaximumCount);
        var placements = ComputePlacements(
            document,
            selectedIds,
            insertCount,
            out var pairs,
            out var tooShort);
        var blocked = 0;
        foreach (var placement in placements)
        {
            if (placement.Blocked) blocked++;
        }
        return new GapFillPlan(pairs, placements.Count - blocked, blocked, tooShort);
    }

    private readonly record struct Placement(ChartNote Source, BeatPosition Beat, bool Blocked);

    /// <summary>
    /// Positions of the notes a fill would add. Occupied cells are marked here
    /// rather than in <see cref="FillGaps"/> so the preview and the real run
    /// agree on which positions count as taken.
    /// </summary>
    private static List<Placement> ComputePlacements(
        ChartDocument document,
        IReadOnlySet<Guid> selectedIds,
        int insertCount,
        out int pairs,
        out int tooShort)
    {
        pairs = 0;
        tooShort = 0;
        var placements = new List<Placement>();

        // One bucket per lane of the beats that already exist. Draft notes live
        // in their own scratch column and never block a real position.
        var taken = new Dictionary<int, List<double>>();
        foreach (var note in document.Notes)
        {
            if (note.IsDraft) continue;
            if (!taken.TryGetValue(note.Lane, out var beats))
                taken[note.Lane] = beats = [];
            beats.Add(note.Beat.Value);
        }

        var selected = document.Notes
            .Where(note => selectedIds.Contains(note.Id) && !note.IsHold && !note.IsDraft)
            .GroupBy(note => note.Lane);
        foreach (var lane in selected)
        {
            var ordered = lane.OrderBy(note => note.Beat.Value).ToArray();
            for (var index = 1; index < ordered.Length; index++)
            {
                var start = ordered[index - 1];
                var end = ordered[index];
                var span = end.Beat.Value - start.Beat.Value;
                // Every inserted note needs its own 1/1440 cell, otherwise two
                // of them fold onto the same position on save.
                if (span <= 0 || insertCount + 1 > span * MalodyDenominator + 1e-9)
                {
                    tooShort++;
                    continue;
                }

                pairs++;
                var step = span / (insertCount + 1);
                if (!taken.TryGetValue(start.Lane, out var laneBeats))
                    taken[start.Lane] = laneBeats = [];
                for (var stepIndex = 1; stepIndex <= insertCount; stepIndex++)
                {
                    var beat = BeatPosition.FromDouble(
                        start.Beat.Value + step * stepIndex,
                        MalodyDenominator);
                    if (beat.CompareTo(start.Beat) <= 0 || beat.CompareTo(end.Beat) >= 0)
                        continue;
                    var blocked = laneBeats.Any(existing =>
                        Math.Abs(existing - beat.Value) < 1e-7);
                    placements.Add(new Placement(start, beat, blocked));
                    // A generated note blocks the next one too: a degenerate
                    // step must not stack two notes on a single cell.
                    if (!blocked) laneBeats.Add(beat.Value);
                }
            }
        }

        return placements;
    }
}
