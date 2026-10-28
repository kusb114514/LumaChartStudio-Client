using LumaChart.Application.Editing;
using LumaChart.Application.Workspaces;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Editing;

/// <summary>
/// Chart-analysis blocks: create one from the selection, jump to one, retarget
/// one, delete one.
///
/// Nothing here writes the document. An annotation is editor metadata stored
/// beside the client's own settings, so adding or rewriting one cannot change a
/// note and must not open an undo entry — the undo stack belongs to the chart,
/// and a mapper pressing Ctrl+Z after writing a note should get the note back,
/// not their comment.
/// </summary>
public static class WindowsAnnotationCommand
{
    /// <summary>
    /// Notes are remembered by column and beat, never by id: the serializers do
    /// not persist <see cref="ChartNote.Id"/>, so a guid would point at nothing
    /// after the chart is reopened. ProEditor 额外轨道上的草稿 note 也一样 ——
    /// 它们的列存在 <see cref="ChartNote.DraftColumn"/> 里，由
    /// <see cref="ChartNoteKey.ForNote"/> 统一取出，所以两个轨道上的 note
    /// 都能被批注点到。
    /// </summary>
    public static ChartNoteKey NoteKeyFor(ChartNote note) => ChartNoteKey.ForNote(note);

    /// <summary>
    /// Creates a block covering the current selection and returns its id, or 0
    /// when nothing is selected. The text starts empty and is filled in from the
    /// 批注 tab, so the shortcut is a single keystroke and the typing happens
    /// where the mapper can see what they are annotating.
    /// </summary>
    public static int AddFromSelection(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        var notes = SelectedNotes(tab);
        if (notes.Count == 0) return 0;
        var id = tab.AnnotationCatalog.NextId();
        var annotation = tab.AnnotationCatalog.Ensure(id);
        annotation.Text = string.Empty;
        annotation.Notes = notes.Select(NoteKeyFor).Distinct().ToList();
        annotation.AnchorBeat = notes.Min(note => note.Beat);
        FileIntoActivePreset(tab, id);
        return id;
    }

    /// <summary>
    /// A block created while a preset is on screen lands in that preset.
    ///
    /// Display is decided by the preset, so a block created under 「按手感」
    /// would otherwise belong to no preset and disappear from the very list the
    /// mapper is looking at — the panel would answer a keystroke with nothing.
    /// The panel shows only what the preset names, so the new block joins it.
    /// </summary>
    private static void FileIntoActivePreset(DesktopChartTab tab, int annotationId)
    {
        if (tab.ActiveAnnotationPreset is not { } preset) return;
        tab.AnnotationCatalog.AssignAnnotationToPreset(annotationId, preset);
    }

    // ---- Presets -------------------------------------------------------------
    // A preset decides which blocks are on screen; it never touches a note, a
    // group or a group scheme, so none of these open a history entry. The
    // group side is deliberately the other way round — there a preset *is* the
    // grouping, so switching one re-groups the chart.

    /// <summary>
    /// Creates a preset and switches to it. It takes over every block that no
    /// preset already names, so the blocks the mapper was just looking at stay
    /// on screen — a preset is a filter, and a new one that filtered everything
    /// away would read as having deleted their notes.
    /// </summary>
    public static int CreatePresetAndUse(DesktopChartTab tab)
    {
        ArgumentNullException.ThrowIfNull(tab);
        var id = tab.AnnotationCatalog.NextPresetId();
        var preset = tab.AnnotationCatalog.EnsurePreset(id);
        preset.AnnotationIds = [.. tab.AnnotationCatalog.UnassignedAnnotationIds()];
        tab.ActiveAnnotationPreset = id;
        return id;
    }

    public static void SetActivePreset(DesktopChartTab tab, int? presetId)
    {
        ArgumentNullException.ThrowIfNull(tab);
        tab.ActiveAnnotationPreset = presetId;
    }

    public static bool RenamePreset(DesktopChartTab tab, int presetId, string? name)
    {
        ArgumentNullException.ThrowIfNull(tab);
        if (presetId <= 0) return false;
        var trimmed = (name ?? string.Empty).Trim();
        if (trimmed.Length > ChartAnnotationCatalog.MaximumPresetNameLength)
            trimmed = trimmed[..ChartAnnotationCatalog.MaximumPresetNameLength];
        var preset = tab.AnnotationCatalog.EnsurePreset(presetId);
        if (preset.Name == trimmed) return false;
        preset.Name = trimmed;
        return true;
    }

    /// <summary>
    /// Drops a drawer. Its blocks survive — only the drawer goes — so deleting
    /// one can never cost a mapper their annotations.
    /// </summary>
    public static bool RemovePreset(DesktopChartTab tab, int presetId)
    {
        ArgumentNullException.ThrowIfNull(tab);
        if (!tab.AnnotationCatalog.RemovePreset(presetId)) return false;
        if (tab.ActiveAnnotationPreset == presetId) tab.ActiveAnnotationPreset = null;
        return true;
    }

    public static bool AssignAnnotationToPreset(DesktopChartTab tab, int annotationId, int? presetId)
    {
        ArgumentNullException.ThrowIfNull(tab);
        return tab.AnnotationCatalog.AssignAnnotationToPreset(annotationId, presetId);
    }

    /// <summary>
    /// Re-points an existing block at the current selection. This is what makes
    /// a block reusable while the chart is still being written: fix a run,
    /// reselect it, and the block follows instead of being deleted and retyped.
    /// Returns the number of notes now covered.
    /// </summary>
    public static int RetargetFromSelection(DesktopChartTab tab, int annotationId)
    {
        ArgumentNullException.ThrowIfNull(tab);
        if (tab.AnnotationCatalog.Find(annotationId) is not { } annotation) return 0;
        var notes = SelectedNotes(tab);
        if (notes.Count == 0) return annotation.Notes.Count;
        annotation.Notes = notes.Select(NoteKeyFor).Distinct().ToList();
        annotation.AnchorBeat = notes.Min(note => note.Beat);
        return annotation.Notes.Count;
    }

    public static bool SetText(DesktopChartTab tab, int annotationId, string? text)
    {
        ArgumentNullException.ThrowIfNull(tab);
        if (tab.AnnotationCatalog.Find(annotationId) is not { } annotation) return false;
        var trimmed = (text ?? string.Empty).Trim();
        if (trimmed.Length > ChartAnnotationCatalog.MaximumTextLength)
            trimmed = trimmed[..ChartAnnotationCatalog.MaximumTextLength];
        if (annotation.Text == trimmed) return false;
        annotation.Text = trimmed;
        return true;
    }

    public static bool Remove(DesktopChartTab tab, int annotationId)
    {
        ArgumentNullException.ThrowIfNull(tab);
        return tab.AnnotationCatalog.Remove(annotationId);
    }

    public static int SelectNotes(DesktopChartTab tab, int annotationId, bool additive) =>
        tab.AnnotationCatalog.Find(annotationId) is { } annotation
            ? SelectNotes(tab.Session, annotation.Notes, additive)
            : 0;

    /// <summary>
    /// Selects every note a block names. Used both by the 批注 list and by a
    /// click on the sticky card, so both routes land on the same selection.
    /// </summary>
    public static int SelectNotes(
        EditorSession session,
        IEnumerable<ChartNoteKey> keys,
        bool additive)
    {
        ArgumentNullException.ThrowIfNull(session);
        ArgumentNullException.ThrowIfNull(keys);
        var wanted = keys.ToHashSet();
        if (wanted.Count == 0) return 0;
        var ids = session.Document.Notes
            .Where(note => wanted.Contains(NoteKeyFor(note)))
            .Select(note => note.Id)
            .ToArray();
        if (!additive) session.Selection.Clear();
        session.Selection.UnionWith(ids);
        return ids.Length;
    }

    /// <summary>
    /// Where a block sits on the chart. Falls back to the stored anchor when the
    /// notes it named are gone, so a stale block still has a place to jump to
    /// instead of being unclickable.
    /// </summary>
    public static double AnchorBeatFor(EditorSession session, ChartAnnotation annotation)
    {
        ArgumentNullException.ThrowIfNull(session);
        ArgumentNullException.ThrowIfNull(annotation);
        var wanted = annotation.Notes.ToHashSet();
        if (wanted.Count > 0)
        {
            var resolved = session.Document.Notes
                .Where(note => wanted.Contains(NoteKeyFor(note)))
                .Select(note => note.Beat)
                .ToArray();
            if (resolved.Length > 0) return resolved.Min(position => position.Value);
        }
        return annotation.AnchorBeat.Value;
    }

    /// <summary>
    /// How many of a block's notes still exist. The 批注 tab shows this so a
    /// block whose chart was edited under it reads as "3 / 8 有效" instead of
    /// quietly pointing at nothing.
    /// </summary>
    public static (int Resolved, int Total) Measure(EditorSession session, ChartAnnotation annotation)
    {
        ArgumentNullException.ThrowIfNull(session);
        ArgumentNullException.ThrowIfNull(annotation);
        if (annotation.Notes.Count == 0) return (0, 0);
        var wanted = annotation.Notes.ToHashSet();
        var resolved = session.Document.Notes.Count(
            note => wanted.Contains(NoteKeyFor(note)));
        return (resolved, wanted.Count);
    }

    private static IReadOnlyList<ChartNote> SelectedNotes(DesktopChartTab tab)
    {
        if (tab.Session.Selection.Count == 0) return [];
        return tab.Session.Document.Notes
            .Where(note => tab.Session.Selection.Contains(note.Id))
            .OrderBy(note => note.Beat)
            // 排序按有效列，不能按 Lane：草稿 note 的 Lane 恒为 0，按它排会把
            // 所有草稿塌成同一列，锚点也会跟着错。
            .ThenBy(note => note.IsDraft ? note.DraftColumn : note.Lane)
            .ToArray();
    }
}
