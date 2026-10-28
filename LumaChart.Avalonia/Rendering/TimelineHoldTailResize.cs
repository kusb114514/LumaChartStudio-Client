using Avalonia;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Rendering;

/// <summary>
/// Pure LN-tail hit and preview rules. Pointer moves never mutate the document;
/// the accepted target is committed once by the shared editing command.
/// </summary>
public static class TimelineHoldTailResize
{
    /// <summary>
    /// 头尾在画面上至少隔开这么多像素，才算"有个可以抓的面尾"。
    /// 谱面里存在 endbeat 只晚 1/200 拍的长条（整张谱最薄的一片），它的头和尾落在同一个像素上：
    /// 此时任何一次普通点击都会被判成"抓面尾"，而 <see cref="ResolveTarget"/> 又会因为它
    /// 拖不过头部而给出 null → 松手就把这条长条缩成 Tap。这是纯粹的误操作，不是用户的意图。
    /// </summary>
    public const double MinimumTailGrabSeparation = 8;

    public static double HitTolerance(double renderedNoteHeight) =>
        Math.Clamp(renderedNoteHeight * 1.15, 18, 40);

    public static bool IsHit(
        Point point,
        double noteLeft,
        double noteRight,
        double headY,
        double tailY,
        double renderedNoteHeight)
    {
        var tailDistance = Math.Abs(point.Y - tailY);
        return point.X >= noteLeft - 12 &&
            point.X <= noteRight + 12 &&
            Math.Abs(tailY - headY) >= MinimumTailGrabSeparation &&
            tailDistance <= HitTolerance(renderedNoteHeight) &&
            tailDistance <= Math.Abs(point.Y - headY);
    }

    public static BeatPosition? ResolveTarget(
        BeatPosition headBeat,
        BeatPosition authoredPointerBeat) =>
        authoredPointerBeat.CompareTo(headBeat) <= 0 ? null : authoredPointerBeat;

    public static BeatPosition? KeepLastLegal(
        BeatPosition headBeat,
        BeatPosition? current,
        BeatPosition? candidate,
        Func<BeatPosition, BeatPosition, bool> intersectsProtectedRegion,
        out bool accepted)
    {
        ArgumentNullException.ThrowIfNull(intersectsProtectedRegion);
        if (intersectsProtectedRegion(headBeat, candidate ?? headBeat))
        {
            accepted = false;
            return current;
        }
        accepted = true;
        return candidate;
    }

    public static bool IsInterrupted(long gestureChangeSerial, long currentChangeSerial) =>
        gestureChangeSerial != currentChangeSerial;

    public static bool HasChange(BeatPosition? original, BeatPosition? current) =>
        !Nullable.Equals(original, current);
}
