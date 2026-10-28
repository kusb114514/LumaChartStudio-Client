using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace LumaChart.Core.Models;

/// <summary>
/// Editor-only metadata for one note group.
///
/// A note only ever carries the integer <see cref="ChartNote.Group"/>; that is
/// what Malody and osu! round-trip. Everything a mapper actually reads on
/// screen — the name, the colour and the nesting — lives here, so the chart
/// file stays byte-compatible with both formats while the editor still gets a
/// real group model.
/// </summary>
public sealed class ChartGroupDefinition
{
    public int Id { get; set; }

    /// <summary>Display name. Empty falls back to "Group N".</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// "#RRGGBB" or "#AARRGGBB". Empty selects the built-in palette colour for
    /// the id, so a chart with no custom colours still reads as coloured notes.
    /// </summary>
    public string Color { get; set; } = string.Empty;

    /// <summary>
    /// Parent group id, or null at top level. This is the "分组的分组" edge: a
    /// group keeps its own identity while also belonging to a coarser one, so
    /// the same notes can be read by lane or by hand-feel without being
    /// re-tagged.
    /// </summary>
    public int? ParentId { get; set; }

    /// <summary>
    /// Retired by 解散: the group is out of every reading, but its name, colour
    /// and nesting are kept, because 撤销 only ever brings the notes back.
    ///
    /// 解散 is two writes that land in different places — the notes in the
    /// document, which the history stack holds, and this definition in the
    /// editor's own catalog, which it does not. Forget the definition and Ctrl+Z
    /// restores a group whose name has silently reverted to "Group N", and, since
    /// the roster no longer lists it either, one the panel will not show while
    /// its notes are on screen. Retiring keeps the row's identity intact for that
    /// undo. A group that is used, renamed, coloured or reopened with notes on it
    /// is brought back to life by <see cref="ChartGroupCatalog.Ensure"/>.
    ///
    /// Written only when true, so a catalog that has never dissolved a group
    /// keeps its exact shape on disk.
    /// </summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public bool Retired { get; set; }

    /// <summary>Copies persisted fields in without touching this object's identity.</summary>
    public void CopyFrom(ChartGroupDefinition source)
    {
        ArgumentNullException.ThrowIfNull(source);
        Name = source.Name;
        Color = source.Color;
        ParentId = source.ParentId;
        Retired = source.Retired;
    }

    public ChartGroupDefinition Clone() => new()
    {
        Id = Id,
        Name = Name,
        Color = Color,
        ParentId = ParentId,
        Retired = Retired
    };
}

/// <summary>
/// One note's membership in a preset: in this scheme, the note at
/// (<see cref="Lane"/>, <see cref="Beat"/>) counts as <see cref="Group"/>.
///
/// The note is named by lane + beat instead of by <see cref="ChartNote.Id"/>
/// because the id is a per-run <see cref="System.Guid"/> that neither Malody
/// nor osu! persists — lane and beat are the pair every other tool can see.
/// </summary>
public sealed class ChartNoteGroupAssignment
{
    public int Lane { get; set; }

    public BeatPosition Beat { get; set; } = BeatPosition.Zero;

    public int Group { get; set; }

    public void CopyFrom(ChartNoteGroupAssignment source)
    {
        ArgumentNullException.ThrowIfNull(source);
        Lane = source.Lane;
        Beat = source.Beat;
        Group = source.Group;
    }

    public ChartNoteGroupAssignment Clone() => new()
    {
        Lane = Lane,
        Beat = Beat,
        Group = Group
    };
}

/// <summary>
/// One complete way of grouping a chart — the preset a mapper switches between.
///
/// A preset is not a parent group. A note carries exactly one
/// <see cref="ChartNote.Group"/>, so two reading axes ("按音轨" and "按手感")
/// can never both live in that field at once. A preset resolves that by owning
/// its own whole assignment table: selecting 「按音轨」 makes every note count as
/// its 音轨 group, selecting 「按手感」 re-reads the same notes as 左手 / 右手.
/// Switching schemes is therefore a real re-grouping of the chart, not a filter
/// over the panel.
///
/// Only notes that are actually grouped are listed; an absent note reads as
/// 未分组, which is exactly how the chart file stores it.
/// </summary>
public sealed class ChartGroupPreset
{
    public int Id { get; set; }

    /// <summary>Display name. Empty falls back to "预设 N".</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// The groups this reading is written in — the roster the panel lists while
    /// the scheme is on screen.
    ///
    /// The roster belongs to the scheme rather than to the chart because a group
    /// made while 「按音轨」 is on screen is a group *of* 按音轨: 按手感 was laid
    /// out before that group existed and has no business showing it. A group
    /// that a note actually carries is always listed here too — the catalog
    /// keeps the two in step on every write — so a row holding notes can never
    /// be the one that got filtered out.
    /// </summary>
    public List<int> GroupIds { get; set; } = [];

    /// <summary>Which notes this scheme groups, and as what. Group 0 is never stored.</summary>
    public List<ChartNoteGroupAssignment> Assignments { get; set; } = [];

    public void CopyFrom(ChartGroupPreset source)
    {
        ArgumentNullException.ThrowIfNull(source);
        Name = source.Name;
        GroupIds = [.. source.GroupIds];
        Assignments = source.Assignments.Select(item => item.Clone()).ToList();
    }

    public ChartGroupPreset Clone() => new()
    {
        Id = Id,
        Name = Name,
        GroupIds = [.. GroupIds],
        Assignments = Assignments.Select(item => item.Clone()).ToList()
    };
}

/// <summary>
/// The per-chart group tree. Pure domain state: it holds no view state (which
/// groups are hidden stays on the tab) and no document state (the note's
/// <see cref="ChartNote.Group"/> is the assignment).
///
/// Every id that appears on a note may or may not have a definition; the
/// catalog creates one lazily so an imported chart with bare integer groups
/// still opens with sensible names and colours.
/// </summary>
public sealed class ChartGroupCatalog
{
    public const int MaximumGroups = 4096;
    public const int MaximumNameLength = 64;
    public const int MaximumPresets = 128;
    public const int MaximumPresetNameLength = 64;

    private static readonly Regex HexColor = new(
        "^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    private readonly List<ChartGroupDefinition> groups = [];
    private readonly Dictionary<int, ChartGroupDefinition> index = [];
    private readonly List<ChartGroupPreset> presets = [];
    private readonly Dictionary<int, ChartGroupPreset> presetIndex = [];

    public IReadOnlyList<ChartGroupDefinition> Groups => groups;

    public IReadOnlyList<ChartGroupPreset> Presets => presets;

    public bool IsEmpty => groups.Count == 0;

    public static string DefaultName(int id) => id == 0 ? "未分组" : $"Group {id}";

    public static string DefaultPresetName(int id) => $"预设 {id}";

    public static bool IsValidColorText(string? text) =>
        !string.IsNullOrWhiteSpace(text) && HexColor.IsMatch(text.Trim());

    public static bool IsValidGroupId(int id) => id is >= 0 and <= ushort.MaxValue;

    public ChartGroupDefinition? Find(int id) => index.GetValueOrDefault(id);

    /// <summary>
    /// Returns the definition for <paramref name="id"/>, creating it when absent.
    ///
    /// This is also the one place a retired group comes back into use: using,
    /// naming, colouring or nesting a group, and seeding definitions from the
    /// notes on load, all mean the same thing — whatever 解散 retired, this is
    /// not it any more.
    /// </summary>
    public ChartGroupDefinition Ensure(int id)
    {
        if (index.TryGetValue(id, out var existing))
        {
            existing.Retired = false;
            return existing;
        }
        var created = new ChartGroupDefinition { Id = id };
        groups.Add(created);
        index[id] = created;
        groups.Sort((left, right) => left.Id.CompareTo(right.Id));
        return created;
    }

    /// <summary>Seeds a definition for every id a note actually uses.</summary>
    public void Observe(IEnumerable<int> usedGroupIds)
    {
        foreach (var id in usedGroupIds)
            if (id is >= 1 and <= ushort.MaxValue)
                Ensure(id);
    }

    /// <summary>
    /// Removes a definition for good. Children are re-parented to the removed
    /// node's own parent so dissolving a middle group never orphans the branch
    /// below it. The id is taken out of every scheme's roster — a retired group
    /// is not a group any reading still has — while every scheme's assignment
    /// table is left alone: rewriting another scheme's notes on a dissolve would
    /// silently edit an axis the mapper is not looking at.
    ///
    /// Nothing in the editor calls this; it exists for a whole-list replacement
    /// (the CLI's `groups` patch), which rebuilds the catalog from a file and has
    /// the names in hand. 解散 uses <see cref="Retire"/>, which keeps them.
    /// </summary>
    public bool Remove(int id)
    {
        if (!index.TryGetValue(id, out var removed)) return false;
        var grandParent = removed.ParentId;
        index.Remove(id);
        groups.Remove(removed);
        foreach (var group in groups)
            if (group.ParentId == id)
                group.ParentId = grandParent;
        foreach (var preset in presets) preset.GroupIds.Remove(id);
        return true;
    }

    /// <summary>
    /// Takes a group out of every reading without forgetting what it was.
    /// Children move up one level rather than orphan, and the id leaves every
    /// scheme's roster, so the row is gone from the panel — but the definition
    /// stays, marked <see cref="ChartGroupDefinition.Retired"/>, because 解散
    /// cannot put its own half on the undo stack and Ctrl+Z must still be able to
    /// bring the group back with the name it had.
    ///
    /// A group with no definition has nothing to remember; only its roster entry
    /// is cleaned up, which is also what takes a bare number someone typed into
    /// 使用 back off the panel.
    /// </summary>
    public bool Retire(int id)
    {
        if (!IsValidGroupId(id) || id == 0) return false;
        var changed = false;
        if (index.TryGetValue(id, out var definition))
        {
            var grandParent = definition.ParentId;
            if (!definition.Retired)
            {
                definition.Retired = true;
                changed = true;
            }
            foreach (var group in groups)
            {
                if (group.ParentId != id) continue;
                group.ParentId = grandParent;
                changed = true;
            }
        }
        foreach (var preset in presets) changed |= preset.GroupIds.Remove(id);
        return changed;
    }

    public string NameOf(int id) =>
        Find(id) is { Name.Length: > 0 } definition
            ? definition.Name
            : DefaultName(id);

    /// <summary>Resolved colour text, or empty when the palette default applies.</summary>
    public string ColorOf(int id) =>
        Find(id) is { Color.Length: > 0 } definition ? definition.Color : string.Empty;

    // ---- presets ---------------------------------------------------------

    /// <summary>
    /// The scheme the chart's own <see cref="ChartNote.Group"/> values currently
    /// belong to, or null when the grouping is not owned by any preset (the
    /// state a chart starts in). Persisted with the catalog: reopening a chart
    /// has to know which scheme its saved grouping is the answer to.
    /// </summary>
    public int? ActivePresetId { get; set; }

    public ChartGroupPreset? FindPreset(int id) => presetIndex.GetValueOrDefault(id);

    /// <summary>Returns the preset for <paramref name="id"/>, creating it when absent.</summary>
    public ChartGroupPreset EnsurePreset(int id)
    {
        if (presetIndex.TryGetValue(id, out var existing)) return existing;
        var created = new ChartGroupPreset { Id = id };
        presets.Add(created);
        presetIndex[id] = created;
        presets.Sort((left, right) => left.Id.CompareTo(right.Id));
        return created;
    }

    public bool RemovePreset(int id)
    {
        if (!presetIndex.TryGetValue(id, out var removed)) return false;
        presetIndex.Remove(id);
        presets.Remove(removed);
        if (ActivePresetId == id) ActivePresetId = null;
        return true;
    }

    /// <summary>The smallest unused positive preset id.</summary>
    public int NextPresetId()
    {
        for (var candidate = 1; candidate <= MaximumPresets; candidate++)
            if (!presetIndex.ContainsKey(candidate)) return candidate;
        return presets.Count == 0 ? 1 : presets[^1].Id + 1;
    }

    public string PresetNameOf(int id) =>
        FindPreset(id) is { Name.Length: > 0 } preset
            ? preset.Name
            : DefaultPresetName(id);

    /// <summary>
    /// One preset's assignments as a lookup, so applying a scheme to a chart is
    /// one pass over the notes instead of a scan per note.
    /// </summary>
    public IReadOnlyDictionary<ChartNoteKey, int> AssignmentLookup(int presetId)
    {
        var result = new Dictionary<ChartNoteKey, int>();
        if (FindPreset(presetId) is not { } preset) return result;
        foreach (var assignment in preset.Assignments)
            result[new ChartNoteKey(assignment.Lane, assignment.Beat)] = assignment.Group;
        return result;
    }

    /// <summary>
    /// Replaces a preset's whole assignment table. Group 0 is dropped rather
    /// than stored: an absent note already reads as 未分组, and keeping those
    /// rows would bloat every scheme with the notes it deliberately leaves out.
    /// Every group the kept table names joins the scheme's roster, because a
    /// group holding notes is on screen by definition — the roster is derived
    /// from the table here rather than being able to disagree with it.
    /// </summary>
    public void ReplaceAssignments(int presetId, IEnumerable<ChartNoteGroupAssignment> assignments)
    {
        var preset = EnsurePreset(presetId);
        var kept = new List<ChartNoteGroupAssignment>();
        var seen = new HashSet<ChartNoteKey>();
        foreach (var assignment in assignments)
        {
            if (assignment.Lane < 0) continue;
            if (!IsValidGroupId(assignment.Group) || assignment.Group == 0) continue;
            if (!seen.Add(new ChartNoteKey(assignment.Lane, assignment.Beat))) continue;
            kept.Add(assignment.Clone());
        }
        preset.Assignments = kept;
        AdoptGroups(presetId, kept.Select(assignment => assignment.Group));
    }

    /// <summary>
    /// The group <paramref name="key"/> reads as under <paramref name="presetId"/>,
    /// or 0 when this scheme leaves it ungrouped.
    /// </summary>
    public int GroupOf(int presetId, ChartNoteKey key)
    {
        if (FindPreset(presetId) is not { } preset) return 0;
        foreach (var assignment in preset.Assignments)
            if (assignment.Lane == key.Lane && assignment.Beat.Equals(key.Beat))
                return assignment.Group;
        return 0;
    }

    /// <summary>The scheme every active-preset switch has to end up pointing at.</summary>
    public ChartGroupPreset? ActivePreset =>
        ActivePresetId is { } id ? FindPreset(id) : null;

    /// <summary>One scheme's roster, or empty when there is no such scheme.</summary>
    public IReadOnlyList<int> GroupIdsOf(int presetId) => FindPreset(presetId)?.GroupIds ?? [];

    /// <summary>
    /// The groups the panel lists while the active scheme is the one on screen,
    /// or null when the chart's grouping belongs to no scheme — the state a
    /// chart starts in, and the state deleting the selected scheme leaves
    /// behind. Null means every group is on screen, which is what makes that
    /// state a usable fallback instead of a blank panel.
    /// </summary>
    public IReadOnlySet<int>? VisibleGroupIds() =>
        ActivePresetId is { } active && FindPreset(active) is { } preset
            ? preset.GroupIds.ToHashSet()
            : null;

    /// <summary>
    /// Adds groups to a scheme's roster. Called whenever a group is made or put
    /// into use while that scheme is on screen: the group is part of this
    /// reading, so it is listed here — and, just as deliberately, not in the
    /// other readings, which were laid out before it existed.
    /// </summary>
    public void AdoptGroups(int? presetId, IEnumerable<int> groupIds)
    {
        if (presetId is not { } id || FindPreset(id) is not { } preset) return;
        var added = false;
        foreach (var group in groupIds)
        {
            if (!IsValidGroupId(group) || group == 0) continue;
            if (preset.GroupIds.Contains(group)) continue;
            preset.GroupIds.Add(group);
            added = true;
        }
        if (added) preset.GroupIds.Sort();
    }

    /// <summary>id, then its parents from nearest to furthest. Never includes id twice.</summary>
    public IReadOnlyList<int> Ancestors(int id)
    {
        var chain = new List<int>();
        var seen = new HashSet<int> { id };
        var current = Find(id)?.ParentId;
        while (current is { } parent && IsValidGroupId(parent) && seen.Add(parent))
        {
            chain.Add(parent);
            current = Find(parent)?.ParentId;
        }
        return chain;
    }

    /// <summary>The outermost group id <paramref name="id"/> belongs to.</summary>
    public int RootOf(int id)
    {
        var root = id;
        var guard = 0;
        while (Find(root)?.ParentId is { } parent &&
               IsValidGroupId(parent) &&
               parent != root &&
               guard++ < MaximumGroups)
            root = parent;
        return root;
    }

    /// <summary>Depth of <paramref name="id"/> in the tree; a top-level group is 0.</summary>
    public int DepthOf(int id) => Ancestors(id).Count;

    /// <summary>id and every group nested underneath it, in stable id order.</summary>
    public IReadOnlyList<int> Descendants(int id)
    {
        var result = new List<int> { id };
        var frontier = new List<int> { id };
        var seen = new HashSet<int> { id };
        while (frontier.Count > 0)
        {
            var next = new List<int>();
            foreach (var group in groups)
            {
                if (group.ParentId is not { } parent || !frontier.Contains(parent)) continue;
                if (!seen.Add(group.Id)) continue;
                result.Add(group.Id);
                next.Add(group.Id);
            }
            frontier = next;
        }
        result.Sort();
        return result;
    }

    /// <summary>
    /// True when <paramref name="parentId"/> may become the parent of
    /// <paramref name="id"/>: no self-parenting, no invalid id, and no cycle
    /// (a group may not be nested under one of its own descendants).
    /// </summary>
    public bool CanReparent(int id, int? parentId)
    {
        if (!IsValidGroupId(id)) return false;
        if (parentId is not { } parent) return true;
        if (!IsValidGroupId(parent) || parent == id) return false;
        return !Descendants(id).Contains(parent);
    }

    /// <summary>
    /// Sets the parent, rejecting the change when it would build a cycle.
    /// Returns true when the tree actually changed.
    /// </summary>
    public bool SetParent(int id, int? parentId)
    {
        if (!CanReparent(id, parentId)) return false;
        if (parentId is { } parent) Ensure(parent);
        var definition = Ensure(id);
        if (definition.ParentId == parentId) return false;
        definition.ParentId = parentId;
        return true;
    }

    /// <summary>Ids ordered so a parent is always listed before its children.</summary>
    public IReadOnlyList<int> FlattenedOrder()
    {
        var roots = groups
            .Where(group => group.ParentId is not { } parent || Find(parent) == null)
            .Select(group => group.Id)
            .Distinct()
            .OrderBy(id => id)
            .ToArray();
        var ordered = new List<int>(groups.Count);
        var seen = new HashSet<int>();
        foreach (var root in roots) Append(root, ordered, seen, 0);
        foreach (var group in groups)
            if (seen.Add(group.Id))
                ordered.Add(group.Id);
        return ordered;

        void Append(int id, List<int> target, HashSet<int> visited, int depth)
        {
            if (depth > MaximumGroups || !visited.Add(id)) return;
            target.Add(id);
            foreach (var child in groups
                         .Where(candidate => candidate.ParentId == id)
                         .Select(candidate => candidate.Id)
                         .OrderBy(candidate => candidate))
                Append(child, target, visited, depth + 1);
        }
    }

    /// <summary>
    /// Drops definitions that cannot be trusted (bad ids, bad colours, cycles,
    /// missing parents) and clamps text. Called on every load so a hand-edited
    /// or truncated catalog cannot close the editor.
    /// </summary>
    public void Normalize()
    {
        for (var index = groups.Count - 1; index >= 0; index--)
        {
            var group = groups[index];
            if (!IsValidGroupId(group.Id) || group.Id == 0)
            {
                groups.RemoveAt(index);
                continue;
            }
            group.Name = Clamp(group.Name, MaximumNameLength);
            if (!IsValidColorText(group.Color)) group.Color = string.Empty;
            else group.Color = group.Color.Trim().ToUpperInvariant();
            if (group.ParentId is { } parent &&
                (!IsValidGroupId(parent) || parent == group.Id || parent == 0))
                group.ParentId = null;
        }

        RebuildIndex();
        // A parent that has no definition of its own is not a level; it would
        // make the group look nested while the tree cannot show where.
        foreach (var group in groups)
        {
            if (group.ParentId is { } missing && !index.ContainsKey(missing))
                group.ParentId = null;
        }
        // A cycle can only come from a hand-edited file. Break it by detaching
        // the group whose ancestor walk returns to itself.
        foreach (var group in groups)
        {
            var walk = group.Id;
            var guard = 0;
            while (Find(walk)?.ParentId is { } parent && guard++ < MaximumGroups)
            {
                if (parent == group.Id)
                {
                    group.ParentId = null;
                    break;
                }
                walk = parent;
            }
        }

        while (groups.Count > MaximumGroups) groups.RemoveAt(groups.Count - 1);
        RebuildIndex();
        groups.Sort((left, right) => left.Id.CompareTo(right.Id));
        NormalizePresets();
    }

    /// <summary>
    /// Preset clean-up. Drops unusable presets and duplicate ids, clamps names,
    /// and makes each scheme well-formed on both of its halves: the same note may
    /// be listed once and group 0 is dropped (an absent note already reads as
    /// 未分组), and the roster keeps only usable ids, once each, plus every group
    /// the table names.
    /// </summary>
    private void NormalizePresets()
    {
        for (var position = presets.Count - 1; position >= 0; position--)
            if (!IsValidGroupId(presets[position].Id) || presets[position].Id == 0)
                presets.RemoveAt(position);

        presets.Sort((left, right) => left.Id.CompareTo(right.Id));
        RebuildPresetIndex();

        foreach (var preset in presets)
        {
            preset.Name = Clamp(preset.Name, MaximumPresetNameLength);
            var kept = new List<ChartNoteGroupAssignment>(preset.Assignments.Count);
            var seen = new HashSet<ChartNoteKey>();
            foreach (var assignment in preset.Assignments)
            {
                if (assignment.Lane < 0) continue;
                if (!IsValidGroupId(assignment.Group) || assignment.Group == 0) continue;
                if (!seen.Add(new ChartNoteKey(assignment.Lane, assignment.Beat))) continue;
                kept.Add(assignment);
            }
            preset.Assignments = kept;

            var roster = new List<int>(preset.GroupIds.Count);
            var claimed = new HashSet<int>();
            foreach (var group in preset.GroupIds)
            {
                if (!IsValidGroupId(group) || group == 0) continue;
                if (!claimed.Add(group)) continue;
                roster.Add(group);
            }
            // A scheme's table and its roster are two views of the same thing, so
            // a hand-edited file that lists one and not the other is repaired
            // here rather than allowed to leave a group on the panel's blind side.
            foreach (var assignment in preset.Assignments)
                if (claimed.Add(assignment.Group))
                    roster.Add(assignment.Group);
            roster.Sort();
            preset.GroupIds = roster;
        }

        while (presets.Count > MaximumPresets) presets.RemoveAt(presets.Count - 1);
        RebuildPresetIndex();
        if (ActivePresetId is { } active && FindPreset(active) == null) ActivePresetId = null;
    }

    public ChartGroupCatalog Clone()
    {
        var copy = new ChartGroupCatalog { ActivePresetId = ActivePresetId };
        foreach (var group in groups) copy.groups.Add(group.Clone());
        foreach (var preset in presets) copy.presets.Add(preset.Clone());
        copy.RebuildIndex();
        copy.RebuildPresetIndex();
        return copy;
    }

    private void RebuildPresetIndex()
    {
        presetIndex.Clear();
        for (var position = presets.Count - 1; position >= 0; position--)
        {
            var preset = presets[position];
            if (presetIndex.ContainsKey(preset.Id))
            {
                presets.RemoveAt(position);
                continue;
            }
            presetIndex[preset.Id] = preset;
        }
    }

    private void RebuildIndex()
    {
        index.Clear();
        for (var position = groups.Count - 1; position >= 0; position--)
        {
            var group = groups[position];
            if (index.ContainsKey(group.Id))
            {
                groups.RemoveAt(position);
                continue;
            }
            index[group.Id] = group;
        }
    }

    private static string Clamp(string? text, int maximum)
    {
        var trimmed = (text ?? string.Empty).Trim();
        return trimmed.Length <= maximum ? trimmed : trimmed[..maximum];
    }
}
