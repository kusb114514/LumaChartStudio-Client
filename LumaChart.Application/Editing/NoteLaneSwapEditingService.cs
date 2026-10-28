using LumaChart.Core.Models;

namespace LumaChart.Application.Editing;

/// <summary>
/// Swaps the outer and inner lane of the same hand: lane 0 with 1, lane 2 with 3.
/// Read as columns that is <c>lane ^ 1</c>, which is only a valid pairing for a
/// 4-key chart — every other key count leaves a lane without a partner, so the
/// command refuses those charts before touching the document. Permission,
/// owner-lock and single-undo semantics stay centralized here, matching
/// <see cref="NoteMirrorEditingService"/>.
/// </summary>
public static class NoteLaneSwapEditingService
{
    /// <summary>The only key count this pairing is defined for.</summary>
    public const int SupportedKeyCount = 4;

    public static int SwapOuterInner(EditorSession session, IEnumerable<Guid> selectedNoteIds)
    {
        ArgumentNullException.ThrowIfNull(session);
        ArgumentNullException.ThrowIfNull(selectedNoteIds);

        if (session.IsReadOnly)
            throw new InvalidOperationException("当前谱面为只读状态，不能对调 Note。");
        if (!session.CanEditNotes)
            throw new InvalidOperationException("当前没有编辑 Note 的权限，不能对调 Note。");

        var keyCount = Math.Clamp(session.Document.KeyCount, 1, 18);
        if (keyCount != SupportedKeyCount)
            throw new InvalidOperationException(
                $"内外对调只对 {SupportedKeyCount}K 谱面有效（当前 {keyCount}K）。");

        var requested = selectedNoteIds.Distinct().ToHashSet();
        if (requested.Count == 0) return 0;
        var notes = session.Document.Notes
            .Where(note => requested.Contains(note.Id))
            .ToArray();
        if (notes.Length == 0) return 0;

        if (!session.AllowOwnerProtectedEdits && notes.Any(session.IsOwnerProtected))
            throw new InvalidOperationException(
                "对调目标与房主锁定选区相交，成员不能移动 Note。");

        // Draft columns live outside the official lanes; "outer/inner" has no
        // meaning out there, so they stay where they are — same rule the
        // randomizer uses.
        var changedIds = notes
            .Where(note => !note.IsDraft && note.Lane >= 0 && note.Lane < keyCount)
            .Select(note => note.Id)
            .ToHashSet();
        if (changedIds.Count == 0) return 0;

        session.Mutate(document =>
        {
            foreach (var note in document.Notes.Where(note => changedIds.Contains(note.Id)))
                note.Lane ^= 1;
        });
        return changedIds.Count;
    }
}
