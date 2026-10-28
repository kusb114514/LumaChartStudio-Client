using LumaChart.Avalonia.Infrastructure;
using LumaChart.Avalonia.Rendering;
using LumaChart.Core.Editing;
using LumaChart.Core.IO;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Specs;

/// <summary>
/// Un-snap is the editor's name for 1/1440 — the finest beat denominator a
/// Malody .mc can hold. These checks pin the three facts that make it read as
/// free placement rather than as a very fine grid: the stored value, what the
/// UI calls it, and that a placement survives a save/load round trip unchanged.
/// </summary>
internal static class UnsnapDivisionSpecs
{
    private const double PixelsPerBeat = 140;

    public static int Run()
    {
        try
        {
            VerifyDivisionIdentity();
            VerifyPlacementKeepsPointerPosition();
            VerifyPlacementSurvivesSaveRoundTrip();
            VerifyCellCenterNeverStoresFinerThanMalodySupports();
            VerifyCoarserDivisionsAreUnchanged();
            VerifyFillStaysPlayable();
            Console.WriteLine($"Un-snap contracts: passed ({Count} checks)");
            return 0;
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine(exception);
            Console.Error.WriteLine(
                $"Un-snap contracts: failed after {Count} checks");
            return 1;
        }
    }

    private static int Count;

    private static void VerifyDivisionIdentity()
    {
        Require(
            TimelineSubdivisionCheckPalette.UnsnapDivision == 1440,
            "Un-snap is 1/1440, the densest denominator a Malody chart can store");
        Require(
            TimelineSubdivisionCheckPalette.IsUnsnap(1440) &&
            !TimelineSubdivisionCheckPalette.IsUnsnap(1920) &&
            !TimelineSubdivisionCheckPalette.IsUnsnap(4),
            "only 1/1440 is treated as Un-snap");
        Require(
            TimelineSubdivisionCheckPalette.FormatDivisionLabel(1440) == "Un-snap",
            "Un-snap is named Un-snap, not 1/1440");
        Require(
            TimelineSubdivisionCheckPalette.FormatDivisionLabel(4) == "1/4",
            "every other subdivision keeps its 1/N label");
        var divisions = TimelineSubdivisionCheckPalette.EditorDivisions;
        var unsnapIndex = -1;
        var thirtySecondIndex = -1;
        for (var index = 0; index < divisions.Count; index++)
        {
            if (divisions[index] == TimelineSubdivisionCheckPalette.UnsnapDivision)
                unsnapIndex = index;
            if (divisions[index] == 32) thirtySecondIndex = index;
        }
        Require(
            unsnapIndex >= 0 && unsnapIndex == thirtySecondIndex + 1,
            "Un-snap sits directly below 1/32 in the division list");
    }

    private static void VerifyPlacementKeepsPointerPosition()
    {
        // A pointer position that is deliberately not on any useful grid.
        const double pointerBeat = 1.234567;
        var stored = TimelinePlacementGeometry.PointerToStoredBeat(
            pointerBeat,
            WindowsNoteAnchorMode.GridLine,
            TimelineSubdivisionCheckPalette.UnsnapDivision,
            WindowsEditorViewSettings.DefaultNoteHeight,
            PixelsPerBeat);
        var error = Math.Abs(stored.Value - pointerBeat);
        Require(
            error <= 1d / TimelineSubdivisionCheckPalette.UnsnapDivision,
            $"a placement lands where the pointer is (off by {error:0.0000000} beats)");
        Require(
            stored.Denominator <= TimelineSubdivisionCheckPalette.UnsnapDivision,
            $"the stored denominator stays at or below 1440 (was {stored.Denominator})");
        // The note must also draw back at the beat it was stored at, otherwise
        // it would appear to move the moment it is placed.
        var render = TimelinePlacementGeometry.StoredToRenderBeat(
            stored,
            WindowsNoteAnchorMode.GridLine,
            TimelineSubdivisionCheckPalette.UnsnapDivision,
            WindowsEditorViewSettings.DefaultNoteHeight,
            PixelsPerBeat);
        Require(
            Math.Abs(render - stored.Value) < 1e-9,
            "a placed note draws back at its stored beat");
    }

    private static void VerifyPlacementSurvivesSaveRoundTrip()
    {
        var document = new ChartDocument();
        var lanes = 0;
        foreach (var pointerBeat in new[] { 1.234567, 2.000694, 8.499999 })
        {
            var beat = TimelinePlacementGeometry.PointerToStoredBeat(
                pointerBeat,
                WindowsNoteAnchorMode.GridLine,
                TimelineSubdivisionCheckPalette.UnsnapDivision,
                WindowsEditorViewSettings.DefaultNoteHeight,
                PixelsPerBeat);
            document.Notes.Add(new ChartNote { Lane = lanes++ % 4, Beat = beat });
        }
        var json = MalodyMcSerializer.Serialize(document);
        var reloaded = MalodyMcSerializer.Parse(json);
        Require(
            reloaded.Notes.Count == document.Notes.Count,
            $"every Un-snap note survives a .mc round trip ({reloaded.Notes.Count}/{document.Notes.Count})");
        for (var index = 0; index < document.Notes.Count; index++)
        {
            var before = document.Notes[index].Beat;
            var after = reloaded.Notes[index].Beat;
            Require(
                Math.Abs(before.Value - after.Value) < 1e-9,
                $"note {index} keeps its position through .mc ({before} -> {after})");
            Require(
                after.Denominator <= TimelineSubdivisionCheckPalette.UnsnapDivision,
                $"note {index} reloads with a denominator Malody accepts ({after.Denominator})");
        }
    }

    private static void VerifyCellCenterNeverStoresFinerThanMalodySupports()
    {
        // Cell-centre stores (2k+1)/(2N). At N=1440 that is a 1/2880 denominator,
        // which Malody cannot hold, so Un-snap must fall back to the pointer beat.
        var stored = TimelinePlacementGeometry.PointerToStoredBeat(
            3.3333,
            WindowsNoteAnchorMode.CellCenter,
            TimelineSubdivisionCheckPalette.UnsnapDivision,
            WindowsEditorViewSettings.DefaultNoteHeight,
            PixelsPerBeat);
        Require(
            stored.Denominator <= TimelineSubdivisionCheckPalette.UnsnapDivision,
            $"cell-centre at Un-snap cannot store 1/2880 (was 1/{stored.Denominator})");
    }

    private static void VerifyCoarserDivisionsAreUnchanged()
    {
        // Regression guard: Un-snap must not disturb ordinary snapping.
        var stored = TimelinePlacementGeometry.PointerToStoredBeat(
            1.3,
            WindowsNoteAnchorMode.GridLine,
            4,
            WindowsEditorViewSettings.DefaultNoteHeight,
            PixelsPerBeat);
        Require(
            Math.Abs(stored.Value - 1.25) < 1e-9,
            $"1/4 still snaps 1.3 to 1.25 (was {stored.Value:0.0000})");
        var cellCenter = TimelinePlacementGeometry.PointerToStoredBeat(
            1.3,
            WindowsNoteAnchorMode.CellCenter,
            8,
            WindowsEditorViewSettings.DefaultNoteHeight,
            PixelsPerBeat);
        Require(
            cellCenter.Denominator == 16,
            $"cell-centre at 1/8 still keeps its 2N denominator (was {cellCenter.Denominator})");
    }

    private static void VerifyFillStaysPlayable()
    {
        // "Long note to a stream of taps" fills at the active subdivision. At
        // 1/1440 a four-beat hold would become 5760 notes stacked milliseconds
        // apart, so Fill falls back to quarter beats there.
        var document = new ChartDocument();
        var hold = new ChartNote
        {
            Lane = 1,
            Beat = BeatPosition.Preserve(0, 0, 4),
            EndBeat = BeatPosition.Preserve(4, 0, 4)
        };
        document.Notes.Add(hold);
        var result = NoteTypeTransformService.ConvertLongNotesToTaps(
            document,
            new HashSet<Guid> { hold.Id },
            TimelineSubdivisionCheckPalette.UnsnapDivision,
            LongNoteToTapMode.Fill);
        Require(
            result.CreatedCount is > 0 and <= 32,
            $"Fill at Un-snap produces a playable stream, not 5760 notes (created {result.CreatedCount})");

        // A coarse subdivision must still fill at its own step.
        var fine = new ChartDocument();
        var eightBeat = new ChartNote
        {
            Lane = 0,
            Beat = BeatPosition.Preserve(0, 0, 4),
            EndBeat = BeatPosition.Preserve(4, 0, 4)
        };
        fine.Notes.Add(eightBeat);
        var eightResult = NoteTypeTransformService.ConvertLongNotesToTaps(
            fine,
            new HashSet<Guid> { eightBeat.Id },
            8,
            LongNoteToTapMode.Fill);
        Require(
            eightResult.CreatedCount == 32,
            $"Fill at 1/8 still creates one note per eighth (created {eightResult.CreatedCount})");
    }

    private static void Require(bool condition, string message)
    {
        Count++;
        if (condition)
        {
            Console.WriteLine($"  ok    {message}");
            return;
        }
        Console.WriteLine($"  FAIL  {message}");
        throw new InvalidOperationException("Un-snap contract failed: " + message);
    }
}
