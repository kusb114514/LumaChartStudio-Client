using System.Text.Json;
using System.Text.Json.Serialization;
using LumaChart.Avalonia.Infrastructure;
using LumaChart.Core.IO;
using LumaChart.Core.Models;

namespace LumaChart.Cli;

// ---------------------------------------------------------------------------
// Wire format
//
// One JSON shape is both what `dump` prints and what `write` accepts. Keeping
// them the same type means a dump can be edited by hand and fed straight back,
// which is the whole point of the tool: a model reads the chart, decides what
// to change, and writes the same structure back.
//
// Every list in the patch is optional and, when present, REPLACES that whole
// category. Absent means "leave alone". Replace rather than merge because a
// generator produces a complete answer, and a merge would silently keep stale
// notes the generator meant to drop.
// ---------------------------------------------------------------------------

internal sealed class ChartDump
{
    public string Chart { get; set; } = string.Empty;
    public int KeyCount { get; set; }
    public MetadataDto Metadata { get; set; } = new();
    public List<TimingDto> Timing { get; set; } = [];
    public List<NoteDto> Notes { get; set; } = [];
    public List<DraftDto> Drafts { get; set; } = [];
    public List<GroupDto> Groups { get; set; } = [];
    public List<PresetDto> Presets { get; set; } = [];

    /// <summary>
    /// Which scheme the chart's own note groups belong to, or null when no
    /// preset owns them. The .mc file only stores one integer per note, so this
    /// is what says which scheme those integers are the answer to.
    /// </summary>
    public int? ActivePreset { get; set; }

    public List<AnnotationDto> Annotations { get; set; } = [];
}

internal sealed class MetadataDto
{
    public string Title { get; set; } = string.Empty;
    public string Artist { get; set; } = string.Empty;
    public string Creator { get; set; } = string.Empty;
    public string Version { get; set; } = string.Empty;
    public double Bpm { get; set; }
    public string AudioFile { get; set; } = string.Empty;
}

/// <summary>Read-only in v1: shown so a reader can see the grid, never written back.</summary>
internal sealed class TimingDto
{
    public string Beat { get; set; } = string.Empty;
    public double? Bpm { get; set; }
    public double Delay { get; set; }
}

internal sealed class NoteDto
{
    public int Lane { get; set; }
    public string Beat { get; set; } = string.Empty;
    public string? EndBeat { get; set; }
    public int Group { get; set; }
    public string? Sound { get; set; }
    public int Volume { get; set; } = 100;
}

/// <summary>
/// A note on a ProEditor column. <see cref="DraftColumn"/> is relative to the
/// first official lane, so column 0 sits under lane 0.
/// </summary>
internal sealed class DraftDto
{
    public int Column { get; set; }
    public string Beat { get; set; } = string.Empty;
    public string? EndBeat { get; set; }
    public int Group { get; set; }
    public string? Sound { get; set; }
    public int Volume { get; set; } = 100;
}

internal sealed class GroupDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
    public int? ParentId { get; set; }

    /// <summary>
    /// 解散 was pressed on this group and 撤销 has not brought it back: the notes
    /// are ungrouped and no scheme lists it, while its name, colour and nesting
    /// are kept so the undo still has something to restore. **省略 = false**, so
    /// a patch written before this field existed keeps behaving exactly as it did.
    /// </summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public bool Retired { get; set; }
}

/// <summary>
/// One grouping scheme: a name, the notes it groups, and the group ids it owns.
/// A preset is a whole reading of the chart rather than a container of groups,
/// so what travels is the note-to-group table; <see cref="GroupIds"/> rides along
/// because the editor lists that scheme's own groups only, and without it the
/// panel would fall back to whatever the table happens to name.
/// </summary>
internal sealed class PresetDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// The groups this scheme lists. Optional on write: absent (null) leaves the
    /// roster to the assignment table, which is what a patch that only moves
    /// notes wants. An empty list is a scheme that owns nothing — the assignment
    /// table still puts its groups back, since a group holding notes is listed.
    /// </summary>
    public List<int>? GroupIds { get; set; }

    public List<PresetAssignmentDto> Assignments { get; set; } = [];
}

/// <summary>One note's group in one scheme. Notes are named by lane + beat.</summary>
internal sealed class PresetAssignmentDto
{
    public int Lane { get; set; }
    public string Beat { get; set; } = string.Empty;
    public int Group { get; set; }
}

internal sealed class NoteKeyDto
{
    /// <summary>
    /// 有效列：正式轨是 lane（0 起），草稿轨是 draftColumn（可负）。由
    /// <see cref="IsDraft"/> 决定读哪一套。
    /// </summary>
    public int Lane { get; set; }

    public string Beat { get; set; } = string.Empty;

    /// <summary>
    /// 一个批注键指向的是 ProEditor 额外轨道上的草稿 note。**省略 = false**，
    /// 所以老 patch 和老 dump 都还是「正式轨」，JSON 形状不变。
    /// </summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public bool IsDraft { get; set; }
}

internal sealed class AnnotationDto
{
    public int Id { get; set; }
    public string Text { get; set; } = string.Empty;
    public string AnchorBeat { get; set; } = string.Empty;
    public List<NoteKeyDto> Notes { get; set; } = [];
}

/// <summary>A dump with any subset of the lists present; absent lists are untouched.</summary>
internal sealed class ChartPatch
{
    public List<NoteDto>? Notes { get; set; }
    public List<DraftDto>? Drafts { get; set; }
    public List<GroupDto>? Groups { get; set; }
    public List<PresetDto>? Presets { get; set; }

    /// <summary>Set the active scheme. Absent leaves the stored one alone.</summary>
    public int? ActivePreset { get; set; }

    public List<AnnotationDto>? Annotations { get; set; }
}

internal static class ChartToolJson
{
    public static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        // Chinese in a chart title must stay readable in the dump; the default
        // encoder would turn it into \uXXXX and make the file useless to read.
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
    };
}

/// <summary>Raised for anything the caller did wrong, so Program can print it plainly.</summary>
internal sealed class ChartToolException(string message) : Exception(message);

internal static class ChartTool
{
    /// <summary>
    /// Ceiling on one scheme's table. A scheme names grouped notes only, so this
    /// is well above any real chart and exists to bound a hand-written patch.
    /// </summary>
    public const int MaximumPresetAssignments = 262144;

    public static ChartDump Dump(string chartPath)
    {
        var document = LoadDocument(chartPath);
        var groups = WindowsGroupCatalogStore.Load(chartPath);
        var annotations = WindowsGroupCatalogStore.LoadAnnotations(chartPath);

        var dump = new ChartDump
        {
            Chart = Path.GetFullPath(chartPath),
            ActivePreset = groups.ActivePresetId,
            KeyCount = document.KeyCount,
            Metadata = new MetadataDto
            {
                Title = document.Metadata.Title,
                Artist = document.Metadata.Artist,
                Creator = document.Metadata.Creator,
                Version = document.Metadata.Version,
                Bpm = document.Metadata.Bpm,
                AudioFile = document.Metadata.AudioFile
            },
            Timing = document.Timing
                .OrderBy(entry => entry.Beat)
                .Select(entry => new TimingDto
                {
                    Beat = entry.Beat.ToString(),
                    Bpm = entry.Bpm,
                    Delay = entry.Delay
                })
                .ToList()
        };

        foreach (var note in document.Notes.OrderBy(note => note.Beat).ThenBy(note => note.Lane))
        {
            if (note.IsDraft)
                dump.Drafts.Add(new DraftDto
                {
                    Column = note.DraftColumn,
                    Beat = note.Beat.ToString(),
                    EndBeat = note.EndBeat?.ToString(),
                    Group = note.Group,
                    Sound = note.Sound,
                    Volume = note.Volume
                });
            else
                dump.Notes.Add(new NoteDto
                {
                    Lane = note.Lane,
                    Beat = note.Beat.ToString(),
                    EndBeat = note.EndBeat?.ToString(),
                    Group = note.Group,
                    Sound = note.Sound,
                    Volume = note.Volume
                });
        }

        foreach (var group in groups.Groups)
            dump.Groups.Add(new GroupDto
            {
                Id = group.Id,
                Name = group.Name,
                Color = group.Color,
                ParentId = group.ParentId,
                Retired = group.Retired
            });

        foreach (var preset in groups.Presets)
            dump.Presets.Add(new PresetDto
            {
                Id = preset.Id,
                Name = preset.Name,
                GroupIds = [.. preset.GroupIds],
                Assignments = preset.Assignments
                    .Select(assignment => new PresetAssignmentDto
                    {
                        Lane = assignment.Lane,
                        Beat = assignment.Beat.ToString(),
                        Group = assignment.Group
                    })
                    .ToList()
            });

        foreach (var annotation in annotations.InBeatOrder())
            dump.Annotations.Add(new AnnotationDto
            {
                Id = annotation.Id,
                Text = annotation.Text,
                AnchorBeat = annotation.AnchorBeat.ToString(),
                Notes = annotation.Notes
                    .Select(key => new NoteKeyDto
                    {
                        Lane = key.Lane,
                        Beat = key.Beat.ToString(),
                        IsDraft = key.IsDraft
                    })
                    .ToList()
            });

        return dump;
    }

    /// <summary>
    /// Applies a patch and reports what changed. Nothing is written until every
    /// category has been built and validated, so a bad beat string in the last
    /// annotation cannot leave a half-written chart behind.
    /// </summary>
    public static IReadOnlyList<string> Apply(string chartPath, ChartPatch patch, bool dryRun)
    {
        var document = LoadDocument(chartPath);
        var changes = new List<string>();

        if (patch.Notes is { } notes)
        {
            var replacement = new List<ChartNote>(notes.Count);
            foreach (var dto in notes) replacement.Add(BuildNote(dto));
            RejectDroppedNotes(document, replacement, "notes");
            var before = document.Notes.Count(note => !note.IsDraft);
            document.Notes.RemoveAll(note => !note.IsDraft);
            document.Notes.AddRange(replacement);
            changes.Add($"notes: {before} -> {replacement.Count}");
        }

        if (patch.Drafts is { } drafts)
        {
            var replacement = new List<ChartNote>(drafts.Count);
            foreach (var dto in drafts) replacement.Add(BuildDraft(dto));
            var before = document.Notes.Count(note => note.IsDraft);
            document.Notes.RemoveAll(note => note.IsDraft);
            document.Notes.AddRange(replacement);
            changes.Add($"drafts: {before} -> {replacement.Count}");
        }

        var touchedMetadata = patch.Groups is not null || patch.Presets is not null;
        var catalog = touchedMetadata
            ? WindowsGroupCatalogStore.Load(chartPath)
            : null;
        if (patch.Groups is { } groups)
        {
            var rebuilt = new ChartGroupCatalog();
            foreach (var dto in groups)
            {
                if (dto.Id <= 0)
                    throw new ChartToolException(
                        "a group needs a positive id (group 0 is 'ungrouped' and has no definition)");
                rebuilt.Ensure(dto.Id).CopyFrom(new ChartGroupDefinition
                {
                    Id = dto.Id,
                    Name = dto.Name,
                    Color = dto.Color,
                    ParentId = dto.ParentId,
                    Retired = dto.Retired
                });
            }
            rebuilt.Normalize();
            if (rebuilt.Groups.Count != groups.Count)
                throw new ChartToolException(
                    $"group list would shrink from {groups.Count} to {rebuilt.Groups.Count}: " +
                    "check duplicate ids and parent ids that point at a group not in the list");
            CopyGroups(rebuilt, catalog!);
            changes.Add($"groups: {rebuilt.Groups.Count}");
        }

        if (patch.Presets is { } presets)
        {
            var rebuilt = new ChartGroupCatalog();
            foreach (var dto in presets)
            {
                if (dto.Id <= 0) throw new ChartToolException("a preset needs a positive id");
                if (dto.Assignments.Count > MaximumPresetAssignments)
                    throw new ChartToolException(
                        $"preset {dto.Id} lists {dto.Assignments.Count} assignments, " +
                        $"over the {MaximumPresetAssignments} allowed");
                var assignments = new List<ChartNoteGroupAssignment>(dto.Assignments.Count);
                foreach (var assignment in dto.Assignments)
                    assignments.Add(new ChartNoteGroupAssignment
                    {
                        Lane = assignment.Lane,
                        Beat = ParseBeat(assignment.Beat, "preset assignment beat"),
                        Group = assignment.Group
                    });
                var preset = rebuilt.EnsurePreset(dto.Id);
                preset.CopyFrom(new ChartGroupPreset
                {
                    Id = dto.Id,
                    Name = dto.Name,
                    Assignments = assignments
                });
                // A roster the patch names is honoured; one it leaves out is left
                // to the assignment table, so a patch that only moves notes does
                // not have to restate which groups the scheme is written in.
                if (dto.GroupIds is { } roster) preset.GroupIds = [.. roster];
            }
            rebuilt.Normalize();
            CopyPresets(rebuilt, catalog!);
            changes.Add($"presets: {rebuilt.Presets.Count}");
        }

        var catalogChanged = patch.Groups is not null || patch.Presets is not null;
        if (patch.ActivePreset is { } activePreset && catalog is not null)
        {
            if (activePreset < 0)
                throw new ChartToolException("activePreset must be a preset id or null");
            catalog.ActivePresetId = activePreset == 0 ? null : activePreset;
            catalogChanged = true;
            changes.Add($"activePreset: {catalog.ActivePresetId?.ToString() ?? "none"}");
        }

        ChartAnnotationCatalog? annotationsBuilt = null;
        if (patch.Annotations is { } annotationDtos)
        {
            var rebuilt = new ChartAnnotationCatalog();
            foreach (var dto in annotationDtos)
            {
                var id = dto.Id > 0 ? dto.Id : rebuilt.NextId();
                var annotation = rebuilt.Ensure(id);
                annotation.Text = dto.Text;
                annotation.AnchorBeat = ParseBeat(dto.AnchorBeat, "annotation anchorBeat");
                annotation.Notes = dto.Notes
                    .Select(key => new ChartNoteKey(
                        key.Lane,
                        ParseBeat(key.Beat, "annotation note beat"),
                        key.IsDraft))
                    .ToList();
            }
            rebuilt.Normalize();
            annotationsBuilt = rebuilt;
            changes.Add($"annotations: {rebuilt.Annotations.Count}");
        }

        // Everything from here down is a side effect. A dry run has to stop
        // before the first one, or "nothing was written" is a lie -- and it used
        // to be exactly that, because the annotation save sat above this line.
        if (dryRun) return changes;

        if (patch.Notes is not null || patch.Drafts is not null)
        {
            Backup(chartPath);
            document.Normalize();
            MalodyMcSerializer.Save(document, chartPath);
        }

        // Groups and annotations share one settings file and each save merges
        // into whatever is already stored, so order decides what survives: the
        // group save goes first and the annotation save last, which leaves the
        // final write carrying both.
        if (catalogChanged) WindowsGroupCatalogStore.Save(chartPath, catalog!);
        if (annotationsBuilt is not null)
            WindowsGroupCatalogStore.SaveAnnotations(chartPath, annotationsBuilt);

        Verify(chartPath, document, catalogChanged ? catalog : null, annotationsBuilt);
        return changes;
    }

    /// <summary>
    /// Reads the files back and compares them with what was meant to be written.
    ///
    /// Both stores swallow their own write failures on purpose -- in a running
    /// editor a lost settings write is better than a dialog -- so a disk that
    /// was not written looks exactly like a disk that was. For a tool whose whole
    /// output is "I changed your file", that is the one failure that must not be
    /// silent, so nothing here trusts the write path: it re-opens the files.
    ///
    /// The catalog is read with a raw JSON parse rather than through the store,
    /// because the store keeps a process-wide cache and would just hand back the
    /// copy this run edited in memory.
    /// </summary>
    private static void Verify(
        string chartPath,
        ChartDocument document,
        ChartGroupCatalog? catalog,
        ChartAnnotationCatalog? annotations)
    {
        var problems = new List<string>();

        if (catalog is not null || annotations is not null)
        {
            var key = WindowsGroupCatalogStore.KeyFor(chartPath);
            if (!TryCountStoredEntries(key, out var groups, out var presets, out var stored))
            {
                problems.Add("the local group/annotation catalog could not be read back");
            }
            else
            {
                if (catalog is not null && groups != catalog.Groups.Count)
                    problems.Add($"groups: wrote {catalog.Groups.Count}, the file has {groups}");
                if (catalog is not null && presets != catalog.Presets.Count)
                    problems.Add($"presets: wrote {catalog.Presets.Count}, the file has {presets}");
                if (annotations is not null && stored != annotations.Annotations.Count)
                    problems.Add(
                        $"annotations: wrote {annotations.Annotations.Count}, the file has {stored}");
            }
        }

        var reloaded = MalodyMcSerializer.Load(chartPath);
        var expectedNotes = document.Notes.Count(note => !note.IsDraft);
        var expectedDrafts = document.Notes.Count(note => note.IsDraft);
        var diskNotes = reloaded.Notes.Count(note => !note.IsDraft);
        var diskDrafts = reloaded.Notes.Count(note => note.IsDraft);
        if (diskNotes != expectedNotes)
            problems.Add($"notes: wrote {expectedNotes}, the file has {diskNotes}");
        if (diskDrafts != expectedDrafts)
            problems.Add($"drafts: wrote {expectedDrafts}, the file has {diskDrafts}");

        if (problems.Count == 0) return;
        throw new ChartToolException(
            "the write did not land:" + Environment.NewLine +
            "  - " + string.Join(Environment.NewLine + "  - ", problems) +
            Environment.NewLine +
            "The chart file and the local catalog may now disagree. " +
            $".mc backups from this run are beside the chart as *.bak-*.");
    }

    private static bool TryCountStoredEntries(
        string key,
        out int groups,
        out int presets,
        out int annotations)
    {
        groups = presets = annotations = -1;
        var path = WindowsGroupCatalogStore.SettingsPath;
        if (!File.Exists(path)) return false;
        try
        {
            using var stream = File.OpenRead(path);
            using var json = JsonDocument.Parse(stream);
            if (!json.RootElement.TryGetProperty("Entries", out var entries)) return false;
            foreach (var entry in entries.EnumerateArray())
            {
                if (!entry.TryGetProperty("Path", out var stored)) continue;
                if (!string.Equals(
                        WindowsGroupCatalogStore.KeyFor(stored.GetString()),
                        key,
                        StringComparison.Ordinal))
                    continue;
                groups = CountOf(entry, "Groups");
                presets = CountOf(entry, "Presets");
                annotations = CountOf(entry, "Annotations");
                return true;
            }
        }
        catch (Exception exception) when (exception is JsonException or IOException)
        {
            return false;
        }
        return false;

        static int CountOf(JsonElement entry, string name) =>
            entry.TryGetProperty(name, out var array) ? array.GetArrayLength() : 0;
    }

    private static ChartDocument LoadDocument(string chartPath)
    {
        if (!File.Exists(chartPath))
            throw new ChartToolException($"no such chart: {chartPath}");
        if (!Path.GetExtension(chartPath).Equals(".mc", StringComparison.OrdinalIgnoreCase))
            throw new ChartToolException(
                $"only Malody .mc charts are supported right now, got '{Path.GetExtension(chartPath)}'");
        return MalodyMcSerializer.Load(chartPath);
    }

    private static ChartNote BuildNote(NoteDto dto) => new()
    {
        Lane = dto.Lane,
        Beat = ParseBeat(dto.Beat, "note beat"),
        EndBeat = dto.EndBeat is null ? null : ParseBeat(dto.EndBeat, "note endBeat"),
        Group = dto.Group,
        Sound = string.IsNullOrWhiteSpace(dto.Sound) ? null : dto.Sound,
        Volume = dto.Volume
    };

    private static ChartNote BuildDraft(DraftDto dto) => new()
    {
        IsDraft = true,
        DraftColumn = dto.Column,
        Beat = ParseBeat(dto.Beat, "draft beat"),
        EndBeat = dto.EndBeat is null ? null : ParseBeat(dto.EndBeat, "draft endBeat"),
        Group = dto.Group,
        Sound = string.IsNullOrWhiteSpace(dto.Sound) ? null : dto.Sound,
        Volume = dto.Volume
    };

    /// <summary>
    /// Normalize silently discards notes whose lane is outside the key count or
    /// whose beat is negative. For a generator that is the worst possible
    /// failure -- the write succeeds and the notes are simply gone -- so the
    /// replacement is checked before anything touches the document.
    /// </summary>
    private static void RejectDroppedNotes(
        ChartDocument document,
        List<ChartNote> replacement,
        string label)
    {
        var probe = new ChartDocument { KeyCount = document.KeyCount, Notes = [.. replacement] };
        probe.Normalize();
        if (probe.Notes.Count == replacement.Count) return;

        var kept = probe.Notes
            .Select(note => (note.Beat, note.Lane))
            .ToHashSet();
        var offender = replacement.First(note => !kept.Contains((note.Beat, note.Lane)));
        throw new ChartToolException(
            $"{label}: a note at lane {offender.Lane}, beat {offender.Beat} would be dropped " +
            $"(lanes must be 0..{document.KeyCount - 1} and beats must not be negative). " +
            "Nothing was written.");
    }

    private static BeatPosition ParseBeat(string? text, string label) =>
        BeatPosition.TryParse(text, out var position)
            ? position
            : throw new ChartToolException(
                $"{label}: '{text}' is not a beat. Expected bar:numerator/denominator, e.g. 23:2/4");

    private static void CopyGroups(ChartGroupCatalog source, ChartGroupCatalog target)
    {
        // Replacing a definition goes through Remove, which also takes the id out
        // of every scheme's roster. The schemes are not what this edit is about,
        // so their rosters are carried across and put back — without that, a
        // patch that only renames a group would quietly empty the panel of every
        // scheme that had listed it.
        var rosters = target.Presets.ToDictionary(
            preset => preset.Id,
            preset => preset.GroupIds.ToArray());
        foreach (var existing in target.Groups.ToArray()) target.Remove(existing.Id);
        foreach (var group in source.Groups)
            target.Ensure(group.Id).CopyFrom(group);
        foreach (var preset in target.Presets)
            if (rosters.TryGetValue(preset.Id, out var kept))
                preset.GroupIds = [.. kept];
        target.Normalize();
    }

    private static void CopyPresets(ChartGroupCatalog source, ChartGroupCatalog target)
    {
        foreach (var existing in target.Presets.ToArray()) target.RemovePreset(existing.Id);
        foreach (var preset in source.Presets)
            target.EnsurePreset(preset.Id).CopyFrom(preset);
        target.Normalize();
    }

    private static void Backup(string chartPath)
    {
        var stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
        var destination = $"{chartPath}.bak-{stamp}";
        File.Copy(chartPath, destination, overwrite: true);
    }
}
