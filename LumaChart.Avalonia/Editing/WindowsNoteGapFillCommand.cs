using LumaChart.Application.Editing;
using LumaChart.Core.Editing;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Editing;

/// <summary>
/// Windows Avalonia adapter for <see cref="NoteGapFillService"/>. It owns the
/// editor-side concerns (permission, owner lock, history, selection) and leaves
/// the spacing math to the shared service.
/// </summary>
public static class WindowsNoteGapFillCommand
{
    public static int CountSelectedTaps(
        EditorSession session,
        IReadOnlySet<int>? hiddenGroups = null)
    {
        ArgumentNullException.ThrowIfNull(session);
        return SelectEditableIds(session, hiddenGroups).Count;
    }

    public static GapFillPlan Plan(
        EditorSession session,
        int insertCount,
        IReadOnlySet<int>? hiddenGroups = null)
    {
        ArgumentNullException.ThrowIfNull(session);
        return NoteGapFillService.PlanGapFill(
            session.Document,
            SelectEditableIds(session, hiddenGroups),
            insertCount);
    }

    public static NoteTransformResult FillGaps(
        EditorSession session,
        int insertCount,
        IReadOnlySet<int>? hiddenGroups = null)
    {
        ArgumentNullException.ThrowIfNull(session);
        EnsureNoteEditAllowed(session);
        var ids = SelectEditableIds(session, hiddenGroups);
        if (ids.Count < 2) return new NoteTransformResult(0, 0, 0, new HashSet<Guid>());

        // Same shape as the curve density command: rehearse on a clone so a
        // range the member cannot touch fails before any history entry opens.
        var preview = session.Document.Clone();
        var previewResult = NoteGapFillService.FillGaps(preview, ids, insertCount);
        if (!session.AllowOwnerProtectedEdits && preview.Notes
                .Where(note => previewResult.Selection.Contains(note.Id))
                .Any(note => session.IntersectsOwnerProtectedRegion(
                    note.Beat,
                    note.EndBeat ?? note.Beat)))
            throw new InvalidOperationException("填充目标与房主锁定范围相交，成员不能修改。");

        NoteTransformResult? result = null;
        session.Mutate(document => result = NoteGapFillService.FillGaps(
            document,
            ids,
            insertCount));
        result ??= new NoteTransformResult(0, 0, 0, new HashSet<Guid>());

        session.Selection.Clear();
        session.Selection.UnionWith(result.Selection);
        return result;
    }

    private static HashSet<Guid> SelectEditableIds(
        EditorSession session,
        IReadOnlySet<int>? hiddenGroups)
    {
        ArgumentNullException.ThrowIfNull(session);
        return session.Document.Notes
            .Where(note => session.Selection.Contains(note.Id) &&
                           (hiddenGroups == null || !hiddenGroups.Contains(note.Group)) &&
                           !note.IsHold &&
                           !note.IsDraft &&
                           (session.AllowOwnerProtectedEdits || !session.IsOwnerProtected(note)))
            .Select(note => note.Id)
            .ToHashSet();
    }

    private static void EnsureNoteEditAllowed(EditorSession session)
    {
        if (session.IsReadOnly)
            throw new InvalidOperationException("当前谱面为只读状态，不能填充音符。");
        if (!session.CanEditNotes)
            throw new InvalidOperationException("当前没有编辑 Note 的权限。");
    }
}
