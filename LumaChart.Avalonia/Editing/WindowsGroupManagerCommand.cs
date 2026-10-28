using System.Globalization;
using LumaChart.Application.Editing;
using LumaChart.Application.Workspaces;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Editing;

public sealed record WindowsGroupManagerRow(
    int Group,
    string Name,
    string ColorText,
    int? ParentId,
    int Depth,
    int NoteCount,
    string? DominantSound,
    bool IsVisible,
    bool IsCurrent);

public sealed record WindowsGroupManagerSnapshot(
    int ActivePlacementGroup,
    int VisibleEditableSelectionCount,
    IReadOnlyList<WindowsGroupManagerRow> Rows);

public sealed record WindowsGroupMutationResult(
    int CandidateCount,
    int ChangedCount,
    bool Applied);

/// <summary>
/// Windows Group Manager command boundary.
///
/// Two kinds of state meet here, and keeping them apart is the point:
/// <list type="bullet">
/// <item><b>Document state</b> — the integer group on each note. Assigning and
/// dissolving are the only document mutations and each opens at most one
/// history entry.</item>
/// <item><b>Editor metadata</b> — the per-tab catalog holding names, colours,
/// nesting and annotations, plus the per-tab placement/visibility view state.
/// None of it touches the document, so none of it opens history.</item>
/// </list>
/// </summary>
public static class WindowsGroupManagerCommand
{
    public static WindowsGroupManagerSnapshot ReadSnapshot(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        var catalog = tab.GroupCatalog;
        var notesByGroup = tab.Session.Document.Notes
            .GroupBy(note => note.Group)
            .ToDictionary(group => group.Key, group => group.ToArray());

        // What the panel can list is what is really on screen: the groups notes
        // carry (including ProEditor scratch notes, which carry groups of their
        // own), the group new notes are being placed into, the definitions still
        // in play, and the groups the scheme on screen lists. A retired group —
        // 解散 has happened and 撤销 has not — is deliberately none of those, so
        // the row really does leave the panel; the one thing that always brings
        // it back is a note still carrying it, which is exactly the state the
        // undo creates.
        var roster = catalog.VisibleGroupIds();
        var groups = notesByGroup.Keys
            .Append(0)
            .Append(tab.ActivePlacementGroup)
            .Concat(catalog.Groups
                .Where(definition => !definition.Retired)
                .Select(definition => definition.Id))
            .Concat(roster is { } listed ? listed : Enumerable.Empty<int>())
            .Where(ChartGroupCatalog.IsValidGroupId)
            .Distinct()
            .ToHashSet();
        tab.HiddenGroups.IntersectWith(groups);

        var ordered = OrderForDisplay(groups, catalog);
        var rows = ordered.Select(group =>
        {
            var notes = notesByGroup.GetValueOrDefault(group) ?? [];
            var dominantSound = notes
                .Where(note => !string.IsNullOrWhiteSpace(note.Sound))
                .GroupBy(note => note.Sound!, StringComparer.OrdinalIgnoreCase)
                .OrderByDescending(soundGroup => soundGroup.Count())
                .Select(soundGroup => Path.GetFileName(soundGroup.Key))
                .FirstOrDefault();
            var definition = catalog.Find(group);
            return new WindowsGroupManagerRow(
                group,
                catalog.NameOf(group),
                definition?.Color ?? string.Empty,
                definition?.ParentId,
                catalog.DepthOf(group),
                notes.Length,
                dominantSound,
                !tab.HiddenGroups.Contains(group),
                group == tab.ActivePlacementGroup);
        }).ToArray();

        return new WindowsGroupManagerSnapshot(
            tab.ActivePlacementGroup,
            VisibleEditableSelectionIds(tab).Count,
            rows);
    }

    /// <summary>
    /// "未分组" first, then the catalog tree parent-before-child, then any group
    /// that only exists on a note. Reordering this is user-visible, and the spec
    /// pins the flat case (no catalog) to plain ascending ids.
    /// </summary>
    private static IReadOnlyList<int> OrderForDisplay(
        HashSet<int> groups,
        ChartGroupCatalog catalog)
    {
        var ordered = new List<int>(groups.Count);
        var seen = new HashSet<int>();
        if (groups.Contains(0) && seen.Add(0)) ordered.Add(0);
        foreach (var id in catalog.FlattenedOrder())
            if (groups.Contains(id) && seen.Add(id))
                ordered.Add(id);
        foreach (var id in groups.Where(id => !seen.Contains(id)).OrderBy(id => id))
        {
            seen.Add(id);
            ordered.Add(id);
        }
        return ordered;
    }

    public static int ParseGroupId(string? text)
    {
        if (!int.TryParse(
                text?.Trim(),
                NumberStyles.Integer,
                CultureInfo.InvariantCulture,
                out var group) ||
            !ChartGroupCatalog.IsValidGroupId(group))
            throw new FormatException("Group ID 范围为 0–65535。");
        return group;
    }

    public static void SetPlacementGroup(DesktopChartTab tab, int group)
    {
        ArgumentNullException.ThrowIfNull(tab);
        ValidateGroup(group);
        tab.ActivePlacementGroup = group;
        tab.HiddenGroups.Remove(group);
        // 使用 makes the group part of the reading on screen: a group the mapper
        // has just started using belongs to this scheme, and a roster that left
        // it out would hide the row that says what new notes are about to join.
        tab.GroupCatalog.AdoptGroups(tab.ActiveGroupPreset, [group]);
    }

    public static int CreateAndUse(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        var next = NextAvailableGroupId(tab);
        tab.GroupCatalog.Ensure(next);
        SetPlacementGroup(tab, next);
        return next;
    }

    /// <summary>
    /// Creates a group nested under <paramref name="parentId"/> and makes it the
    /// placement target. The new child is not assigned to anything yet, so
    /// "分组的分组" can be laid out before the notes exist.
    /// </summary>
    public static int CreateChildAndUse(DesktopChartTab tab, int parentId)
    {
        ArgumentNullException.ThrowIfNull(tab);
        ValidateGroup(parentId);
        if (parentId == 0)
            throw new ArgumentOutOfRangeException(
                nameof(parentId),
                "未分组（0）不能作为父分组。");
        var next = NextAvailableGroupId(tab);
        tab.GroupCatalog.Ensure(parentId);
        tab.GroupCatalog.Ensure(next);
        tab.GroupCatalog.SetParent(next, parentId);
        // Both ends of the nesting have to be in the roster, or the child would
        // render one level deep under a parent the panel is not showing.
        tab.GroupCatalog.AdoptGroups(tab.ActiveGroupPreset, [parentId, next]);
        SetPlacementGroup(tab, next);
        return next;
    }

    /// <summary>The lowest unused group id, capped like the Malody field.</summary>
    public static int NextAvailableGroupId(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        var maximum = tab.Session.Document.Notes
            .Select(note => note.Group)
            .Concat(tab.GroupCatalog.Groups.Select(definition => definition.Id))
            .Append(tab.ActivePlacementGroup)
            .Append(0)
            .Max();
        return maximum >= ushort.MaxValue ? ushort.MaxValue : maximum + 1;
    }

    public static WindowsGroupMutationResult AssignSelection(DesktopChartTab tab, int group)
    {
        ArgumentNullException.ThrowIfNull(tab);
        ValidateGroup(group);
        EnsureNoteEditAllowed(tab.Session);
        var ids = VisibleEditableSelectionIds(tab);
        if (ids.Count == 0) return new WindowsGroupMutationResult(0, 0, false);
        var changedCount = tab.Session.Document.Notes.Count(note =>
            ids.Contains(note.Id) && note.Group != group);
        tab.HiddenGroups.Remove(group);
        if (group != 0)
        {
            tab.GroupCatalog.Ensure(group);
            // Assigning notes to a group makes it a group of the scheme on
            // screen, even when the id was typed in rather than picked from a
            // row: the notes are now grouped by it, so the panel has to show it.
            tab.GroupCatalog.AdoptGroups(tab.ActiveGroupPreset, [group]);
        }
        if (changedCount == 0)
            return new WindowsGroupMutationResult(ids.Count, 0, false);
        var serial = tab.Session.ChangeSerial;
        tab.Session.Mutate(document =>
        {
            foreach (var note in document.Notes.Where(note => ids.Contains(note.Id)))
                note.Group = group;
        });
        return new WindowsGroupMutationResult(
            ids.Count,
            changedCount,
            tab.Session.ChangeSerial != serial);
    }

    /// <summary>
    /// The one-keystroke version of "加入 / 移出当前使用分组". All selected notes
    /// already in the active group means the mapper wants them out, so they go
    /// back to 未分组 (0); anything else means they want them in. The test is
    /// "all", not "any", so a mixed selection joins rather than half-leaves.
    ///
    /// This writes the document — unlike renaming or colouring a group — so it
    /// opens a history entry, exactly like <see cref="AssignSelection"/>.
    /// </summary>
    public static WindowsGroupMutationResult ToggleMembership(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        var group = tab.ActivePlacementGroup;
        ValidateGroup(group);
        if (group == 0)
            return new WindowsGroupMutationResult(0, 0, false);
        EnsureNoteEditAllowed(tab.Session);
        var ids = VisibleEditableSelectionIds(tab);
        if (ids.Count == 0) return new WindowsGroupMutationResult(0, 0, false);

        var selected = tab.Session.Document.Notes
            .Where(note => ids.Contains(note.Id))
            .ToArray();
        var target = selected.All(note => note.Group == group) ? 0 : group;
        var changedCount = selected.Count(note => note.Group != target);
        if (changedCount == 0)
            return new WindowsGroupMutationResult(ids.Count, 0, false);
        tab.HiddenGroups.Remove(target);
        if (target != 0)
        {
            tab.GroupCatalog.Ensure(target);
            tab.GroupCatalog.AdoptGroups(tab.ActiveGroupPreset, [target]);
        }
        var serial = tab.Session.ChangeSerial;
        tab.Session.Mutate(document =>
        {
            foreach (var note in document.Notes.Where(note => ids.Contains(note.Id)))
                note.Group = target;
        });
        return new WindowsGroupMutationResult(
            ids.Count,
            changedCount,
            tab.Session.ChangeSerial != serial);
    }

    // ---- Presets -------------------------------------------------------------
    // A preset is a whole grouping scheme, not a drawer. The chart file itself
    // can only remember one integer per note, so the scheme that is on screen
    // keeps its assignments in the document and every other scheme keeps its
    // own table in the catalog. Switching therefore hands the document's
    // grouping back to the scheme it came from and writes the next scheme's
    // table out — the one preset action that does edit notes, and it opens a
    // single history entry the mapper can undo.
    //
    // Each scheme also owns a roster: which groups it reads the chart with. The
    // panel lists the active scheme's roster rather than every group that
    // exists, so a group made under 「按音轨」 stays a group of 按音轨 instead of
    // turning up in 按手感 as well.

    /// <summary>
    /// Snapshots the document's grouping into the active preset. Called before
    /// any switch, and on load, so a scheme always describes what was last
    /// actually on screen rather than what was last written to disk.
    /// </summary>
    public static void CaptureActivePreset(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        if (tab.ActiveGroupPreset is not { } preset) return;
        if (tab.GroupCatalog.FindPreset(preset) == null) return;
        tab.GroupCatalog.ReplaceAssignments(preset, CaptureAssignments(tab));
    }

    /// <summary>
    /// The document's grouping as a scheme table. Draft notes are left out on
    /// purpose: a ProEditor scratch note is addressed by its column, not by
    /// lane and beat, so it cannot share this table without colliding with the
    /// note it sits under.
    /// </summary>
    private static IEnumerable<ChartNoteGroupAssignment> CaptureAssignments(DesktopChartTab tab) =>
        tab.Session.Document.Notes
            .Where(note => !note.IsDraft && note.Group != 0)
            .Select(note => new ChartNoteGroupAssignment
            {
                Lane = note.Lane,
                Beat = note.Beat,
                Group = note.Group
            });

    /// <summary>
    /// The roster a new scheme is born with: the active scheme's own, or every
    /// group the chart still reads with while no scheme owns the grouping yet.
    /// Read before the new scheme becomes active, which is what makes the new one
    /// a copy of the one on screen instead of a copy of itself.
    ///
    /// A group 解散 retired is not one of them: it was taken out of the readings
    /// on purpose, and a scheme created afterwards has even less business
    /// inheriting it than the ones that were open at the time.
    /// </summary>
    private static IEnumerable<int> TemplateGroupIds(DesktopChartTab tab) =>
        tab.GroupCatalog.VisibleGroupIds() ??
        tab.GroupCatalog.Groups
            .Where(group => !group.Retired)
            .Select(group => group.Id);

    /// <summary>
    /// Takes the placement target back to 未分组 when the scheme that just came
    /// on screen does not list it. 使用 targets a group of the reading on
    /// screen, so leaving it pointed at another scheme's group would keep the
    /// panel highlighting a row it has just stopped showing.
    /// </summary>
    private static void DropPlacementOutOfScheme(DesktopChartTab tab)
    {
        if (tab.ActivePlacementGroup == 0) return;
        // No scheme on screen means every group is on screen, so nothing to drop.
        if (tab.GroupCatalog.VisibleGroupIds() is not { } listed) return;
        if (listed.Contains(tab.ActivePlacementGroup)) return;
        tab.ActivePlacementGroup = 0;
    }

    /// <summary>
    /// Creates a scheme and switches to it. The new preset starts as a copy of
    /// what is on screen — the grouping and the group roster both — so a mapper
    /// who only wants a second axis keeps the first one as the starting point
    /// instead of facing an ungrouped chart with an empty panel.
    ///
    /// This writes the catalog and nothing else: no note changes group, so it
    /// stays available on a chart that cannot be edited.
    /// </summary>
    public static int CreatePresetAndUse(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        CaptureActivePreset(tab);
        var id = tab.GroupCatalog.NextPresetId();
        tab.GroupCatalog.ReplaceAssignments(id, CaptureAssignments(tab));
        tab.GroupCatalog.AdoptGroups(id, TemplateGroupIds(tab));
        tab.ActiveGroupPreset = id;
        return id;
    }

    /// <summary>
    /// Switches schemes. Returns true when the chart was actually re-grouped,
    /// which is what tells the caller to refresh and to persist the catalog.
    /// </summary>
    public static bool SetActivePreset(DesktopChartTab tab, int? presetId)
    {
        ArgumentNullException.ThrowIfNull(tab);
        if (presetId is { } target)
        {
            ValidateGroup(target);
            if (target == 0) presetId = null;
        }
        if (tab.ActiveGroupPreset == presetId) return false;
        if (presetId is { } incoming && tab.GroupCatalog.FindPreset(incoming) == null)
            return false;

        CaptureActivePreset(tab);
        // A chart whose grouping was never owned by a scheme has nothing to
        // hand back, so only a target with a table to write re-groups anything.
        if (presetId is null)
        {
            tab.ActiveGroupPreset = null;
            DropPlacementOutOfScheme(tab);
            return false;
        }
        EnsureNoteEditAllowed(tab.Session);
        tab.ActiveGroupPreset = presetId;
        DropPlacementOutOfScheme(tab);
        return ApplyActivePreset(tab);
    }

    /// <summary>
    /// Writes the active scheme's table onto the document. Every note is
    /// decided, including the ones the scheme leaves out — they become 未分组,
    /// because a preset is a complete reading of the chart, not a patch on top
    /// of whatever was there before.
    /// </summary>
    public static bool ApplyActivePreset(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        if (tab.ActiveGroupPreset is not { } preset) return false;
        EnsureNoteEditAllowed(tab.Session);
        var lookup = tab.GroupCatalog.AssignmentLookup(preset);
        var changed = tab.Session.Document.Notes.Any(note =>
            !note.IsDraft &&
            (lookup.TryGetValue(new ChartNoteKey(note.Lane, note.Beat), out var group) ? group : 0)
            != note.Group);
        if (!changed) return false;
        tab.Session.Mutate(document =>
        {
            foreach (var note in document.Notes)
            {
                if (note.IsDraft) continue;
                note.Group = lookup.TryGetValue(new ChartNoteKey(note.Lane, note.Beat), out var group)
                    ? group
                    : 0;
            }
        });
        return true;
    }

    public static bool RenamePreset(DesktopChartTab tab, int presetId, string? name)
    {
        ArgumentNullException.ThrowIfNull(tab);
        ValidateGroup(presetId);
        if (presetId == 0) return false;
        var trimmed = (name ?? string.Empty).Trim();
        if (trimmed.Length > ChartGroupCatalog.MaximumPresetNameLength)
            trimmed = trimmed[..ChartGroupCatalog.MaximumPresetNameLength];
        var preset = tab.GroupCatalog.EnsurePreset(presetId);
        if (preset.Name == trimmed) return false;
        preset.Name = trimmed;
        return true;
    }

    /// <summary>
    /// Drops a scheme. Only that scheme disappears — the grouping currently on
    /// screen stays exactly where it is, and because that grouping is now owned
    /// by no scheme the panel goes back to listing every group. Nothing is
    /// written into another scheme: adopting the chart's grouping into the next
    /// scheme in line would silently overwrite a reading the mapper never
    /// deleted, which is the one thing this command must not do.
    /// </summary>
    public static bool RemovePreset(DesktopChartTab tab, int presetId)
    {
        ArgumentNullException.ThrowIfNull(tab);
        ValidateGroup(presetId);
        if (!tab.GroupCatalog.RemovePreset(presetId)) return false;
        DropPlacementOutOfScheme(tab);
        return true;
    }

    /// <summary>
    /// Picks a scheme for a freshly loaded chart without re-grouping it: the
    /// notes are already the answer, so the scheme is filled in from them.
    ///
    /// Only a scheme with nothing of its own is eligible, because adopting
    /// writes the chart's grouping into it. A scheme that already describes a
    /// chart means the grouping on screen belongs to no scheme — the selected
    /// one was deleted — and the honest answer there is to select none of them.
    /// An entry written before schemes existed, or after the last one was
    /// deleted, has empty tables, which is exactly the case this serves.
    /// </summary>
    public static bool AdoptPresetForLoadedChart(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        if (tab.ActiveGroupPreset is not null) return false;
        if (tab.GroupCatalog.Presets.FirstOrDefault(preset => preset.Assignments.Count == 0)
            is not { } target)
            return false;
        tab.ActiveGroupPreset = target.Id;
        CaptureActivePreset(tab);
        return true;
    }

    /// <summary>
    /// How many notes 解散 would take out of <paramref name="group"/> right now.
    ///
    /// 解散 asks before it acts, so the number the prompt shows has to come from
    /// the same rule the command applies below — a prompt that promises a
    /// different count than the action delivers is worse than no prompt at all.
    /// </summary>
    public static int DissolvableNoteCount(DesktopChartTab tab, int group)
    {
        ArgumentNullException.ThrowIfNull(tab);
        ValidateGroup(group);
        return group == 0 ? 0 : DissolvableNotes(tab, group).Count();
    }

    /// <summary>The notes 解散 is allowed to ungroup: this group's, and not locked to the owner.</summary>
    private static IEnumerable<ChartNote> DissolvableNotes(DesktopChartTab tab, int group) =>
        tab.Session.Document.Notes.Where(note => note.Group == group &&
                                                 (tab.Session.AllowOwnerProtectedEdits ||
                                                  !tab.Session.IsOwnerProtected(note)));

    public static WindowsGroupMutationResult Dissolve(DesktopChartTab tab, int group)
    {
        ArgumentNullException.ThrowIfNull(tab);
        ValidateGroup(group);
        if (group == 0 || tab.HiddenGroups.Contains(group))
            return new WindowsGroupMutationResult(0, 0, false);

        EnsureNoteEditAllowed(tab.Session);
        var ids = DissolvableNotes(tab, group).Select(note => note.Id).ToHashSet();
        tab.HiddenGroups.Remove(group);
        if (tab.ActivePlacementGroup == group) tab.ActivePlacementGroup = 0;
        // The definition is retired rather than dropped, and still before the
        // mutation: the group stops being a group of this reading whether or not
        // a note was editable. What changed is that nothing is destroyed. 解散 is
        // one document edit with a catalog write beside it, and only the document
        // half is on the undo stack — a deleted definition would come back as a
        // nameless row the panel filters out, which is how a Ctrl+Z after a
        // mis-click lost the group's name and its row while keeping its notes.
        tab.GroupCatalog.Retire(group);
        if (ids.Count == 0) return new WindowsGroupMutationResult(0, 0, false);
        var serial = tab.Session.ChangeSerial;
        tab.Session.Mutate(document =>
        {
            foreach (var note in document.Notes.Where(note => ids.Contains(note.Id)))
                note.Group = 0;
        });
        return new WindowsGroupMutationResult(
            ids.Count,
            ids.Count,
            tab.Session.ChangeSerial != serial);
    }

    public static int SetGroupVisible(DesktopChartTab tab, int group, bool visible)
    {
        ArgumentNullException.ThrowIfNull(tab);
        ValidateGroup(group);
        // Visibility follows the tree: hiding a parent hides everything nested
        // under it, and showing a nested group also reveals its ancestors — a
        // visible child of a hidden parent would contradict itself, and the
        // renderer only ever asks about one note's own group.
        var affected = new HashSet<int>(tab.GroupCatalog.Descendants(group));
        if (visible)
        {
            foreach (var ancestor in tab.GroupCatalog.Ancestors(group)) affected.Add(ancestor);
            foreach (var id in affected) tab.HiddenGroups.Remove(id);
        }
        else
        {
            foreach (var id in affected) tab.HiddenGroups.Add(id);
        }
        return RemoveHiddenSelection(tab);
    }

    public static void ShowAll(DesktopChartTab tab) => tab.HiddenGroups.Clear();

    public static int HideNonzero(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        tab.HiddenGroups.Clear();
        foreach (var group in tab.Session.Document.Notes
                     .Select(note => note.Group)
                     .Where(group => group != 0)
                     .Distinct()
                     .ToArray())
            foreach (var id in tab.GroupCatalog.Descendants(group))
                tab.HiddenGroups.Add(id);
        return RemoveHiddenSelection(tab);
    }

    // ---- Editor metadata: names, colours, nesting ----------------------------
    // None of these touch the document, so none of them open a history entry.

    public static bool RenameGroup(DesktopChartTab tab, int group, string? name)
    {
        ArgumentNullException.ThrowIfNull(tab);
        ValidateGroup(group);
        if (group == 0) return false;
        var trimmed = (name ?? string.Empty).Trim();
        if (trimmed.Length > ChartGroupCatalog.MaximumNameLength)
            trimmed = trimmed[..ChartGroupCatalog.MaximumNameLength];
        var definition = tab.GroupCatalog.Ensure(group);
        if (definition.Name == trimmed) return false;
        definition.Name = trimmed;
        return true;
    }

    public static bool SetGroupColor(DesktopChartTab tab, int group, string? colorText)
    {
        ArgumentNullException.ThrowIfNull(tab);
        ValidateGroup(group);
        if (group == 0) return false;
        var normalized = (colorText ?? string.Empty).Trim();
        if (normalized.Length > 0 && !ChartGroupCatalog.IsValidColorText(normalized))
            throw new FormatException("分组颜色必须是 #RRGGBB 或 #AARRGGBB。");
        var definition = tab.GroupCatalog.Ensure(group);
        var value = normalized.ToUpperInvariant();
        if (definition.Color == value) return false;
        definition.Color = value;
        return true;
    }

    public static bool SetGroupParent(DesktopChartTab tab, int group, int? parentId)
    {
        ArgumentNullException.ThrowIfNull(tab);
        ValidateGroup(group);
        if (group == 0) return false;
        if (parentId is { } parent)
        {
            ValidateGroup(parent);
            if (parent == 0) parentId = null;
        }
        if (parentId is { } target && !tab.GroupCatalog.CanReparent(group, target))
            throw new InvalidOperationException("不能把分组挂到它自己的子分组下面。");
        if (!tab.GroupCatalog.SetParent(group, parentId)) return false;
        // A nested group is meaningless while its parent is hidden.
        if (parentId is { } newParent && tab.HiddenGroups.Contains(newParent))
            tab.HiddenGroups.Add(group);
        return true;
    }

    /// <summary>Selects every note of a group so a card click can act on the whole set.</summary>
    public static int SelectGroupNotes(EditorSession session, int group, bool additive)
    {
        ArgumentNullException.ThrowIfNull(session);
        ValidateGroup(group);
        var ids = session.Document.Notes
            .Where(note => note.Group == group)
            .Select(note => note.Id)
            .ToArray();
        if (!additive) session.Selection.Clear();
        session.Selection.UnionWith(ids);
        return ids.Length;
    }

    /// <summary>
    /// Seeds a catalog entry for every group a note actually carries, so an
    /// imported chart opens with named, coloured groups instead of bare numbers.
    /// </summary>
    public static int EnsureDefinitionsFor(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        var before = tab.GroupCatalog.Groups.Count;
        tab.GroupCatalog.Observe(
            tab.Session.Document.Notes.Select(note => note.Group).Distinct());
        return tab.GroupCatalog.Groups.Count - before;
    }

    public static int RemoveHiddenSelection(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        return RemoveHiddenSelection(tab.Session, tab.HiddenGroups);
    }

    public static int RemoveHiddenSelection(
        EditorSession session,
        IReadOnlySet<int> hiddenGroups)
    {
        ArgumentNullException.ThrowIfNull(session);
        ArgumentNullException.ThrowIfNull(hiddenGroups);
        if (hiddenGroups.Count == 0 || session.Selection.Count == 0) return 0;
        var before = session.Selection.Count;
        var hiddenSelectedIds = session.Document.Notes
            .Where(note =>
                session.Selection.Contains(note.Id) &&
                hiddenGroups.Contains(note.Group))
            .Select(note => note.Id)
            .ToArray();
        session.Selection.ExceptWith(hiddenSelectedIds);
        return before - session.Selection.Count;
    }

    public static HashSet<Guid> VisibleSelectionIds(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        return tab.Session.Document.Notes
            .Where(note => tab.Session.Selection.Contains(note.Id) &&
                           !tab.HiddenGroups.Contains(note.Group))
            .Select(note => note.Id)
            .ToHashSet();
    }

    public static HashSet<Guid> VisibleEditableSelectionIds(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        return VisibleEditableSelectionIds(tab.Session, tab.HiddenGroups);
    }

    public static HashSet<Guid> VisibleEditableSelectionIds(
        EditorSession session,
        IReadOnlySet<int> hiddenGroups)
    {
        ArgumentNullException.ThrowIfNull(session);
        ArgumentNullException.ThrowIfNull(hiddenGroups);
        return session.Document.Notes
            .Where(note => session.Selection.Contains(note.Id) &&
                           !hiddenGroups.Contains(note.Group) &&
                           (session.AllowOwnerProtectedEdits ||
                            !session.IsOwnerProtected(note)))
            .Select(note => note.Id)
            .ToHashSet();
    }

    private static void ValidateGroup(int group)
    {
        if (!ChartGroupCatalog.IsValidGroupId(group))
            throw new ArgumentOutOfRangeException(nameof(group), "Group ID 范围为 0–65535。");
    }

    private static void EnsureNoteEditAllowed(EditorSession session)
    {
        if (session.IsReadOnly)
            throw new InvalidOperationException("当前谱面为只读状态，不能修改 Note 分组。");
        if (!session.CanEditNotes)
            throw new InvalidOperationException("当前没有编辑 Note 分组的权限。");
    }
}
