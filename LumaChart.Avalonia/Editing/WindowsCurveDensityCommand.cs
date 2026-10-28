using LumaChart.Application.Editing;
using LumaChart.Core.Editing;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Editing;

/// <summary>
/// Windows Avalonia adapter for <see cref="CurveDensityService"/>. It owns the
/// editor-side concerns (permission, owner lock, history, selection) and leaves
/// the curve math to the shared service.
/// </summary>
public static class WindowsCurveDensityCommand
{
    public static int CountSelectedLongNotes(
        EditorSession session,
        IReadOnlySet<int>? hiddenGroups = null)
    {
        ArgumentNullException.ThrowIfNull(session);
        return SelectEditableIds(session, hiddenGroups).Count;
    }

    /// <summary>First selected long note, used to preview the curve length.</summary>
    public static ChartNote? FirstSelectedLongNote(
        EditorSession session,
        IReadOnlySet<int>? hiddenGroups = null)
    {
        ArgumentNullException.ThrowIfNull(session);
        var ids = SelectEditableIds(session, hiddenGroups);
        return session.Document.Notes
            .Where(note => ids.Contains(note.Id))
            .OrderBy(note => note.Beat)
            .FirstOrDefault();
    }

    public static NoteTransformResult FillCurveDensity(
        EditorSession session,
        CurveDensityOptions options,
        IReadOnlySet<int>? hiddenGroups = null)
    {
        ArgumentNullException.ThrowIfNull(session);
        ArgumentNullException.ThrowIfNull(options);
        EnsureNoteEditAllowed(session);
        var ids = SelectEditableIds(session, hiddenGroups);
        if (ids.Count == 0) return new NoteTransformResult(0, 0, 0, new HashSet<Guid>());

        // Preview against a clone before opening a history entry, matching the
        // other transforms: a range the members cannot touch must fail before
        // anything is written, not after.
        var preview = session.Document.Clone();
        var previewResult = CurveDensityService.FillCurveDensity(preview, ids, options);
        if (!session.AllowOwnerProtectedEdits && preview.Notes
                .Where(note => previewResult.Selection.Contains(note.Id))
                .Any(note => session.IntersectsOwnerProtectedRegion(
                    note.Beat,
                    note.EndBeat ?? note.Beat)))
            throw new InvalidOperationException("曲线密度目标与房主锁定范围相交，成员不能修改。");

        NoteTransformResult? result = null;
        session.Mutate(document => result = CurveDensityService.FillCurveDensity(
            document,
            ids,
            options));
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
                           note.IsHold &&
                           (session.AllowOwnerProtectedEdits || !session.IsOwnerProtected(note)))
            .Select(note => note.Id)
            .ToHashSet();
    }

    private static void EnsureNoteEditAllowed(EditorSession session)
    {
        if (session.IsReadOnly)
            throw new InvalidOperationException("当前谱面为只读状态，不能生成曲线密度。");
        if (!session.CanEditNotes)
            throw new InvalidOperationException("当前没有编辑 Note 的权限。");
    }
}
