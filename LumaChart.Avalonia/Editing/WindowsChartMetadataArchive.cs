using System.Globalization;
using System.Text.Json;
using LumaChart.Application.Editing;
using LumaChart.Application.Workspaces;
using LumaChart.Avalonia.Infrastructure;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Editing;

/// <summary>
/// One note's group, remembered the way an annotation remembers a note: by lane
/// and beat, never by <see cref="ChartNote.Id"/>. The id is a per-run guid the
/// chart formats do not persist, so it would point at nothing after a reload.
/// </summary>
public sealed class WindowsChartArchiveGroupAssignment
{
    public int Lane { get; set; }
    public BeatPosition Beat { get; set; } = BeatPosition.Zero;
    public int Group { get; set; }
}

/// <summary>One ProEditor scratch note on the archive's own terms.</summary>
public sealed class WindowsChartArchiveDraft
{
    public int Column { get; set; }
    public BeatPosition Beat { get; set; } = BeatPosition.Zero;
    public BeatPosition? EndBeat { get; set; }
    public int Volume { get; set; } = 100;
    public string Sound { get; set; } = string.Empty;
}

/// <summary>
/// The editor-side archive of one chart: everything the client keeps *about* a
/// chart rather than *in* it, in one portable file.
///
/// The chart's own notes, timing and metadata stay in the .mc/.osu file; what
/// this carries is the work that would otherwise be lost the moment the chart
/// file moves — the group names, colours and drawers, which notes were filed
/// into which group, the analysis blocks and their drawers, and the ProEditor
/// scratch notes. That is exactly what the per-chart catalog cannot survive on
/// its own, because the catalog is keyed by the chart's absolute path.
/// </summary>
public sealed class WindowsChartMetadataArchive
{
    public const string FormatMarker = "lumachart.editor-archive";
    public const int FormatVersion = 1;

    public string Format { get; set; } = FormatMarker;
    public int Version { get; set; } = FormatVersion;
    public DateTime ExportedUtc { get; set; }
    public string ChartTitle { get; set; } = string.Empty;
    public string SourcePath { get; set; } = string.Empty;
    public List<ChartGroupDefinition> Groups { get; set; } = [];
    public List<ChartGroupPreset> GroupPresets { get; set; } = [];
    public List<WindowsChartArchiveGroupAssignment> GroupAssignments { get; set; } = [];
    public List<ChartAnnotation> Annotations { get; set; } = [];
    public List<ChartAnnotationPreset> AnnotationPresets { get; set; } = [];
    public List<WindowsChartArchiveDraft> Drafts { get; set; } = [];
}

/// <summary>What one import actually wrote, so the caller can say it out loud.</summary>
public sealed record WindowsChartMetadataArchiveApplyResult(
    int Groups,
    int GroupPresets,
    int GroupAssignments,
    int Annotations,
    int AnnotationPresets,
    int Drafts,
    bool DocumentChanged,
    bool DocumentEditsAllowed);

public sealed record WindowsChartMetadataArchiveParseResult(
    bool Ok,
    WindowsChartMetadataArchive? Archive,
    string Error);

/// <summary>
/// Reads and writes <see cref="WindowsChartMetadataArchive"/>, and moves one in
/// and out of a live tab.
///
/// Export is a pure read of the tab. Import merges rather than replaces: the
/// editor metadata (group names / colours / drawers, annotation blocks and
/// drawers) is written over the ids the archive names and everything else is
/// left alone, the archived group numbers are re-applied to the notes that
/// still match by lane and beat, and the ProEditor scratch track is set to the
/// archive's. Nothing there can cost the mapper work the archive does not
/// mention, and the one destructive step — the scrub track — is a document
/// mutation, so it is a single Ctrl+Z away from coming back.
/// </summary>
public static class WindowsChartMetadataArchiveCodec
{
    public const int MaximumDrafts = 65536;
    public const int MaximumAssignments = 262144;
    public const string SuggestedExtension = "luma-archive.json";

    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
        Converters = { new BeatPositionJsonConverter() }
    };

    public static WindowsChartMetadataArchive Capture(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        // The active scheme keeps its table in the document, so it has to be
        // snapshotted before the preset list is read — otherwise the archive
        // would ship every scheme except the one that is actually on screen.
        WindowsGroupManagerCommand.CaptureActivePreset(tab);
        var archive = new WindowsChartMetadataArchive
        {
            ExportedUtc = DateTime.UtcNow,
            ChartTitle = tab.DisplayTitle,
            SourcePath = tab.SourcePath ?? string.Empty
        };

        foreach (var group in tab.GroupCatalog.Groups)
            archive.Groups.Add(group.Clone());
        foreach (var preset in tab.GroupCatalog.Presets)
            archive.GroupPresets.Add(preset.Clone());

        // Every note that carries a group, so a restore puts the membership back
        // too — not just the names and colours hanging off it.
        foreach (var note in tab.Session.Document.Notes
                     .Where(note => !note.IsDraft && note.Group != 0))
            archive.GroupAssignments.Add(new WindowsChartArchiveGroupAssignment
            {
                Lane = note.Lane,
                Beat = note.Beat,
                Group = note.Group
            });

        foreach (var annotation in tab.AnnotationCatalog.Annotations)
            archive.Annotations.Add(annotation.Clone());
        foreach (var preset in tab.AnnotationCatalog.Presets)
            archive.AnnotationPresets.Add(preset.Clone());

        foreach (var note in tab.Session.Document.Notes.Where(note => note.IsDraft))
            archive.Drafts.Add(new WindowsChartArchiveDraft
            {
                Column = note.DraftColumn,
                Beat = note.Beat,
                EndBeat = note.EndBeat,
                Volume = note.Volume,
                Sound = note.Sound ?? string.Empty
            });

        return archive;
    }

    public static string Serialize(WindowsChartMetadataArchive archive)
    {
        ArgumentNullException.ThrowIfNull(archive);
        return JsonSerializer.Serialize(archive, Options);
    }

    public static WindowsChartMetadataArchiveParseResult Read(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return new WindowsChartMetadataArchiveParseResult(false, null, "文件是空的。");
        WindowsChartMetadataArchive? parsed;
        try
        {
            parsed = JsonSerializer.Deserialize<WindowsChartMetadataArchive>(text, Options);
        }
        catch (Exception exception) when (exception is JsonException or NotSupportedException)
        {
            return new WindowsChartMetadataArchiveParseResult(
                false,
                null,
                AvaloniaLocalizationCatalog.Format("不是有效的存档文件：{0}", exception.Message));
        }

        if (parsed == null)
            return new WindowsChartMetadataArchiveParseResult(false, null, "存档文件没有内容。");
        if (!string.Equals(parsed.Format, WindowsChartMetadataArchive.FormatMarker, StringComparison.Ordinal))
            return new WindowsChartMetadataArchiveParseResult(
                false,
                null,
                "这不是 LumaChart 编辑器存档（缺少 format 标记）。");
        if (parsed.Version is < 1 or > WindowsChartMetadataArchive.FormatVersion)
            return new WindowsChartMetadataArchiveParseResult(
                false,
                null,
                AvaloniaLocalizationCatalog.Format(
                    "存档版本 {0} 不受支持（本客户端支持 1–{1}）。",
                    parsed.Version,
                    WindowsChartMetadataArchive.FormatVersion));
        return new WindowsChartMetadataArchiveParseResult(true, parsed, string.Empty);
    }

    public static WindowsChartMetadataArchiveApplyResult Apply(
        DesktopChartTab tab,
        WindowsChartMetadataArchive archive)
    {
        ArgumentNullException.ThrowIfNull(tab);
        ArgumentNullException.ThrowIfNull(archive);

        var groups = MergeGroupCatalog(tab, archive);
        var annotations = MergeAnnotationCatalog(tab, archive);
        var assignments = ApplyGroupAssignments(tab, archive);
        var drafts = ApplyDrafts(tab, archive);

        // The archived group numbers just became the chart's own grouping, so
        // they are also what the scheme on screen now means.
        WindowsGroupManagerCommand.CaptureActivePreset(tab);

        // Schemes the archive does not define cannot stay active.
        if (tab.ActiveGroupPreset is { } groupPreset &&
            tab.GroupCatalog.FindPreset(groupPreset) == null)
            tab.ActiveGroupPreset = null;
        if (tab.ActiveAnnotationPreset is { } annotationPreset &&
            tab.AnnotationCatalog.FindPreset(annotationPreset) == null)
            tab.ActiveAnnotationPreset = null;

        return new WindowsChartMetadataArchiveApplyResult(
            groups.Groups,
            groups.Presets,
            assignments.Count,
            annotations.Annotations,
            annotations.Presets,
            drafts.Count,
            assignments.Changed || drafts.Changed,
            CanEditNotes(tab));
    }

    /// <summary>
    /// Merges the archive's groups and drawers into the live catalog: an id the
    /// archive names is overwritten with the archived name / colour / nesting,
    /// and anything the archive does not mention is left exactly as it is.
    ///
    /// Merging rather than replacing is what makes an import safe to try: the
    /// catalog is not undoable, so a replace would silently throw away grouping
    /// work that took longer to make than the archive did. It is also the whole
    /// point of the feature — restoring after the chart file moved lands on an
    /// empty catalog, so a merge there *is* a restore.
    /// </summary>
    private static (int Groups, int Presets) MergeGroupCatalog(
        DesktopChartTab tab,
        WindowsChartMetadataArchive archive)
    {
        var catalog = tab.GroupCatalog;
        var groups = 0;
        foreach (var definition in archive.Groups)
        {
            if (definition == null || !ChartGroupCatalog.IsValidGroupId(definition.Id) || definition.Id == 0)
                continue;
            catalog.Ensure(definition.Id).CopyFrom(definition);
            groups++;
        }
        var presets = 0;
        foreach (var preset in archive.GroupPresets)
        {
            if (preset == null || preset.Id <= 0) continue;
            catalog.EnsurePreset(preset.Id).CopyFrom(preset);
            presets++;
        }
        catalog.Normalize();
        return (groups, presets);
    }

    private static (int Annotations, int Presets) MergeAnnotationCatalog(
        DesktopChartTab tab,
        WindowsChartMetadataArchive archive)
    {
        var catalog = tab.AnnotationCatalog;
        var annotations = 0;
        foreach (var annotation in archive.Annotations)
        {
            if (annotation == null || annotation.Id <= 0) continue;
            catalog.Ensure(annotation.Id).CopyFrom(annotation);
            annotations++;
        }
        var presets = 0;
        foreach (var preset in archive.AnnotationPresets)
        {
            if (preset == null || preset.Id <= 0) continue;
            catalog.EnsurePreset(preset.Id).CopyFrom(preset);
            presets++;
        }
        catalog.Normalize();
        return (annotations, presets);
    }

    private static (int Count, bool Changed) ApplyGroupAssignments(
        DesktopChartTab tab,
        WindowsChartMetadataArchive archive)
    {
        if (archive.GroupAssignments.Count == 0) return (0, false);
        if (!CanEditNotes(tab)) return (0, false);

        var wanted = new List<WindowsChartArchiveGroupAssignment>(
            Math.Min(archive.GroupAssignments.Count, MaximumAssignments));
        foreach (var assignment in archive.GroupAssignments)
        {
            if (assignment == null) continue;
            if (!ChartGroupCatalog.IsValidGroupId(assignment.Group) || assignment.Group == 0) continue;
            if (wanted.Count >= MaximumAssignments) break;
            wanted.Add(assignment);
        }
        if (wanted.Count == 0) return (0, false);

        // Match on lane + beat; a note the archive does not name is left alone.
        var byKey = new Dictionary<(int Lane, BeatPosition Beat), int>();
        foreach (var assignment in wanted)
            byKey[(assignment.Lane, assignment.Beat)] = assignment.Group;
        var resolved = tab.Session.Document.Notes
            .Where(note => !note.IsDraft && note.Group != byKey.GetValueOrDefault((note.Lane, note.Beat)))
            .Select(note => (Note: note, Group: byKey.GetValueOrDefault((note.Lane, note.Beat))))
            .Where(pair => pair.Group != 0)
            .ToArray();
        if (resolved.Length == 0) return (0, false);

        var changed = resolved.Length;
        tab.Session.Mutate(document =>
        {
            foreach (var (lane, beat, group) in resolved
                         .Select(pair => (pair.Note.Lane, pair.Note.Beat, pair.Group))
                         .ToArray())
            {
                foreach (var note in document.Notes)
                    if (!note.IsDraft && note.Lane == lane && note.Beat.Equals(beat))
                        note.Group = group;
            }
        });
        return (changed, true);
    }

    private static (int Count, bool Changed) ApplyDrafts(
        DesktopChartTab tab,
        WindowsChartMetadataArchive archive)
    {
        if (!CanEditNotes(tab)) return (0, false);
        var keyCount = tab.Session.Document.KeyCount;
        var desired = new List<WindowsChartArchiveDraft>();
        foreach (var draft in archive.Drafts)
        {
            if (draft == null) continue;
            if (desired.Count >= MaximumDrafts) break;
            var column = Math.Clamp(draft.Column, -64, keyCount + 63);
            var beat = draft.Beat;
            if (beat.CompareTo(BeatPosition.Zero) < 0) continue;
            var endBeat = draft.EndBeat;
            if (endBeat.HasValue && endBeat.Value.CompareTo(beat) <= 0) endBeat = null;
            desired.Add(new WindowsChartArchiveDraft
            {
                Column = column,
                Beat = beat,
                EndBeat = endBeat,
                Volume = Math.Clamp(draft.Volume, 0, 100),
                Sound = Path.GetFileName(draft.Sound ?? string.Empty)
            });
        }

        var existing = tab.Session.Document.Notes.Where(note => note.IsDraft).ToArray();
        if (SameDrafts(existing, desired)) return (0, false);

        tab.Session.Mutate(document =>
        {
            document.Notes.RemoveAll(note => note.IsDraft);
            foreach (var draft in desired)
                document.Notes.Add(new ChartNote
                {
                    Lane = 0,
                    Beat = draft.Beat,
                    EndBeat = draft.EndBeat,
                    Volume = draft.Volume,
                    Sound = string.IsNullOrWhiteSpace(draft.Sound) ? null : draft.Sound,
                    IsDraft = true,
                    DraftColumn = draft.Column
                });
        });
        // The mutation may have removed notes that were selected.
        tab.Session.Selection.IntersectWith(tab.Session.Document.Notes.Select(note => note.Id));
        return (desired.Count, true);
    }

    /// <summary>
    /// Whether an import would actually change the ProEditor track. Order-free:
    /// the archive records the track top to bottom, but two tracks holding the
    /// same notes are the same track, and a restore that only re-orders must not
    /// open an undo entry.
    /// </summary>
    private static bool SameDrafts(
        IReadOnlyList<ChartNote> existing,
        IReadOnlyList<WindowsChartArchiveDraft> desired)
    {
        if (existing.Count != desired.Count) return false;
        var left = existing
            .Select(note => string.Create(
                CultureInfo.InvariantCulture,
                $"{note.DraftColumn}|{note.Beat}|{note.EndBeat?.ToString() ?? "-"}|" +
                $"{note.Volume}|{note.Sound ?? string.Empty}"))
            .OrderBy(text => text, StringComparer.Ordinal)
            .ToArray();
        var right = desired
            .Select(draft => string.Create(
                CultureInfo.InvariantCulture,
                $"{draft.Column}|{draft.Beat}|{draft.EndBeat?.ToString() ?? "-"}|" +
                $"{draft.Volume}|{draft.Sound}"))
            .OrderBy(text => text, StringComparer.Ordinal)
            .ToArray();
        for (var index = 0; index < left.Length; index++)
            if (!string.Equals(left[index], right[index], StringComparison.Ordinal))
                return false;
        return true;
    }

    private static bool CanEditNotes(DesktopChartTab tab) =>
        !tab.Session.IsReadOnly && tab.Session.CanEditNotes;

    /// <summary>A filename-safe suggestion for the save picker.</summary>
    public static string SuggestedFileName(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        var title = tab.DisplayTitle;
        foreach (var invalid in Path.GetInvalidFileNameChars())
            title = title.Replace(invalid, '_');
        if (string.IsNullOrWhiteSpace(title)) title = "chart";
        return string.Create(
            CultureInfo.InvariantCulture,
            $"{title}.{SuggestedExtension}");
    }
}
