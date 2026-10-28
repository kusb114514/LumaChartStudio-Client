using LumaChart.Core.Effects;
using LumaChart.Core.Models;

namespace LumaChart.Application.Editing;

public sealed record SvTemplateApplyResult(
    bool Applied,
    int Removed,
    int Added,
    string Message);

/// <summary>
/// Writes a generated SV draft into the timing table as ONE undoable mutation.
/// The replacement rule lives here (not in the templates): the window's existing
/// rows are dropped when asked, and a row is never duplicated on the same beat
/// because Malody would silently let the later one win.
/// </summary>
public static class SvTemplateEditingService
{
    public static SvTemplateApplyResult Apply(
        EditorSession session,
        SvTemplateDraft draft,
        bool replaceInWindow)
    {
        ArgumentNullException.ThrowIfNull(session);
        ArgumentNullException.ThrowIfNull(draft);
        if (draft.Rows.Count == 0)
            return new SvTemplateApplyResult(false, 0, 0, "模板没有生成任何行");

        if (session.IsReadOnly)
            throw new InvalidOperationException("当前谱面为只读状态，不能写入 Effect。");
        if (!session.CanEditTiming)
            throw new InvalidOperationException("当前没有编辑 Timing / Effect 的权限。");

        var ordered = draft.Rows
            .OrderBy(row => row.Beat)
            .ThenBy(row => row.Kind)
            .ToArray();
        var windowStart = ordered[0].Beat;
        var windowEnd = ordered[^1].Beat;
        if (!session.AllowOwnerProtectedEdits &&
            ordered.Any(row => session.IsBeatOwnerProtected(row.Beat)))
        {
            throw new InvalidOperationException("区间触及房主锁定选区，成员不能在其中写入 Effect。");
        }

        var newBeats = new HashSet<string>(ordered.Select(row => BeatKey(row.Beat)));
        var removed = 0;
        var added = 0;
        session.Mutate(document =>
        {
            removed += document.Timing.RemoveAll(timing =>
            {
                if (!timing.Effect.HasValue) return false;
                var inWindow = timing.Beat.CompareTo(windowStart) >= 0 &&
                               timing.Beat.CompareTo(windowEnd) <= 0;
                var sameBeat = newBeats.Contains(BeatKey(timing.Beat));
                return sameBeat || (replaceInWindow && inWindow);
            });

            foreach (var row in ordered)
            {
                document.Timing.Add(new TimingEvent
                {
                    Beat = row.Beat,
                    Effect = row.Kind,
                    EffectValue = row.Value,
                    EffectValueText = row.ValueText
                });
                added++;
            }
        });

        if (added == 0)
            return new SvTemplateApplyResult(false, removed, 0, "没有写入任何行（可能被权限或锁区拒绝）");
        var message = removed > 0
            ? $"已写入 {added} 行，替换掉区间内 {removed} 条旧 Effect"
            : $"已写入 {added} 行";
        return new SvTemplateApplyResult(true, removed, added, message);
    }

    private static string BeatKey(BeatPosition beat) =>
        beat.Bar.ToString("D", System.Globalization.CultureInfo.InvariantCulture) + ":" +
        beat.Numerator.ToString("D", System.Globalization.CultureInfo.InvariantCulture) + "/" +
        beat.Denominator.ToString("D", System.Globalization.CultureInfo.InvariantCulture);
}
