using Avalonia;
using Avalonia.Automation;
using Avalonia.Controls;
using Avalonia.Media;
using LumaChart.Application.Playtest;
using LumaChart.Avalonia.Infrastructure;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Controls;

public sealed record PlaytestSurfaceDiagnostics(
    int RuntimeNoteCount,
    int PerNoteControlCount,
    int LastVisitedNotes,
    int MaximumVisitedNotes,
    bool VisibleAreaClipping,
    bool SingleCustomControl);

/// <summary>
/// One clipped custom-drawn playfield. Notes, holds and lane slots are drawing
/// primitives; no Note or lane is represented by an Avalonia Control.
/// </summary>
public sealed class PlaytestSurface : Control
{
    private static readonly IBrush BackgroundBrush = Brush("#101315");
    private static readonly IBrush LaneABrush = Brush("#171B1E");
    private static readonly IBrush LaneBBrush = Brush("#1B2023");
    private static readonly IBrush NoteFillBrush = Brush("#D7E0E2");
    private static readonly IBrush HoldHeadFillBrush = Brush("#35C8FE");
    private static readonly IBrush HoldFillBrush = Brush("#8C6BA3F9");
    private static readonly IBrush HoldActiveFillBrush = Brush("#C46BA3F9");
    private static readonly IBrush MissFillBrush = Brush("#665A6063");
    private static readonly IBrush SlotFillBrush = Brush("#242A2D");
    private static readonly IBrush SlotPressedFillBrush = Brush("#315A5E");
    private static readonly Pen SlotPen = new(Brush("#68757A"), 2.2);
    private static readonly Pen SlotPressedPen = new(Brush("#8CD5DA"), 2.6);
    private static readonly Pen NotePen = new(Brush("#EEF1F2"), 1.5);
    private static readonly Pen HoldHeadPen = new(Brush("#2E83B4"), 1.5);
    private static readonly Pen HoldBodyPen = new(Brush("#A06BA3F9"), 1.5);
    private static readonly Pen HoldActivePen = new(Brush("#E06BA3F9"), 1.8);

    private PlaytestSession? session;
    private IReadOnlyList<PlaytestRuntimeNote> notes = [];
    private readonly List<PlaytestRuntimeNote> visibleNotes = [];
    private PositionIntervalNode? positionIntervals;
    private bool[] pressed = [];
    private double currentMilliseconds;
    private double currentScrollPosition;
    private WindowsPlaytestNoteStyle style = WindowsPlaytestNoteStyle.Brick;
    private double noteWidth = .82;
    private double noteHeight = 28;
    private double playfieldWidth = 520;
    private double scrollSpeed = 760;
    private double baseBpm = WindowsPlaytestScrollVelocityPolicy.DefaultBaseBpm;
    private double judgementLinePosition = .84;
    private int lastVisitedNotes;
    private int maximumVisitedNotes;

    /// <summary>
    /// 快路径时间窗（拍）。<b>只影响走哪条查询路径，不影响画什么</b>：窗内按时间二分，
    /// 窗外一律交给坐标区间树。前后不对称只是为了窗尽量贴合屏内实际内容。
    /// </summary>
    /// <remarks>
    /// 这两个数以前是可见性的硬剪枝，用来压住「滚动坐标折叠」带来的乱象
    /// （抖动段一条 `jump` 把坐标系往回甩二十多拍，几拍前的 note 会重新出现在屏上）。
    /// 代价是谱面预览整段不显示 —— 它靠 `scroll` 倒流把 +100 拍的谱折进屏内，
    /// 任何按时间收窄的窗口都会把它剪光。折叠是这套坐标系的真实行为（Malody 也这么画），
    /// 所以现在改成坐标说了算，时间窗降级成性能优化。
    /// </remarks>
    private const double MinimumForwardWindowBeats = 4.5;
    private const double MaximumForwardWindowBeats = 5;
    private const double BackwardWindowBeats = 2;

    /// <summary>
    /// 「同一个时间段」的宽度（拍）。屏只装 1.81 拍，取 8 拍是给慢速段和长条留余量：
    /// 实测正常的多收最长出现在 +6.6 拍（regain 224–226），要裁的从 +17 拍起（regain 182–187）。
    /// </summary>
    private const double NearbyBeatWindowBeats = 8;

    public PlaytestSurface()
    {
        ClipToBounds = true;
        Focusable = false;
        AutomationProperties.SetAutomationId(this, "Playtest.Surface");
        AutomationProperties.SetName(this, "测试演奏自绘轨道");
    }

    public PlaytestSurfaceDiagnostics Diagnostics => new(
        notes.Count,
        0,
        lastVisitedNotes,
        maximumVisitedNotes,
        ClipToBounds,
        true);

    public void SetSession(PlaytestSession value)
    {
        session = value ?? throw new ArgumentNullException(nameof(value));
        // 主扫描按「时间」排序，不能按滚动坐标：坐标会被负速度和 jump 拉回去，
        // 整张谱 79 处逆序，二分查找在非单调数组上返回的区间是没有意义的。
        // 时间（毫秒）是单调的，二分才成立。
        notes = session.Notes
            .OrderBy(note => note.StartMilliseconds)
            .ThenBy(note => note.Note.Lane)
            .ThenBy(note => note.StartScrollPosition)
            .ToArray();
        // 另一份按「坐标序」建区间树。坐标非单调（负速、jump、折叠），所以不能二分区间，
        // 只能靠树的「子树端点极值」剪枝；数组按端点较小值排序、取中点递归，树天然平衡。
        var byPosition = session.Notes
            .OrderBy(note => Math.Min(note.StartScrollPosition, note.EndScrollPosition))
            .ThenBy(note => note.StartMilliseconds)
            .ThenBy(note => note.Note.Lane)
            .ToArray();
        positionIntervals = BuildPositionIntervals(byPosition, 0, byPosition.Length);
        pressed = new bool[session.KeyCount];
        baseBpm = WindowsPlaytestScrollVelocityPolicy.ResolveBaseBpm(session.Document);
        currentMilliseconds = session.StartMilliseconds;
        currentScrollPosition = session.ScrollPositionAt(
            session.TimingMap.MillisecondsToBeat(currentMilliseconds));
        InvalidateVisual();
    }

    public void Configure(WindowsPlaytestSettings settings)
    {
        ArgumentNullException.ThrowIfNull(settings);
        style = settings.NoteStyle;
        noteWidth = settings.NoteWidth;
        noteHeight = settings.NoteHeight;
        playfieldWidth = settings.PlayfieldWidth;
        scrollSpeed = settings.ScrollSpeed;
        judgementLinePosition = settings.JudgementLinePosition;
        InvalidateVisual();
    }

    public void SetCurrentTime(double milliseconds)
    {
        if (session == null || !double.IsFinite(milliseconds)) return;
        if (Math.Abs(currentMilliseconds - milliseconds) < .01) return;
        currentMilliseconds = milliseconds;
        currentScrollPosition = session.ScrollPositionAt(
            session.TimingMap.MillisecondsToBeat(milliseconds));
        InvalidateVisual();
    }

    public void SetLanePressed(int lane, bool value)
    {
        if (lane < 0 || lane >= pressed.Length || pressed[lane] == value) return;
        pressed[lane] = value;
        InvalidateVisual();
    }

    /// <summary>
    /// Runs the same visible-range query used by <see cref="Render"/> without
    /// allocating drawing primitives. This is the deterministic verification seam
    /// for the 100,000-Note single-control/culling contract.
    /// </summary>
    public PlaytestSurfaceDiagnostics EvaluateViewportForDiagnostics(double viewportHeight)
    {
        if (session == null || !double.IsFinite(viewportHeight) || viewportHeight <= 0)
            return Diagnostics;
        CollectVisible(viewportHeight, visibleNotes);
        return Diagnostics;
    }

    /// <summary>诊断用：当前时刻屏内真正会被画出来的 note（与 <see cref="Render"/> 同一条路径）。</summary>
    public IReadOnlyList<PlaytestRuntimeNote> EvaluateVisibleNotes(double viewportHeight)
    {
        CollectVisible(viewportHeight, visibleNotes);
        return visibleNotes;
    }

    /// <summary>
    /// 可见集合的唯一计算入口。诊断和渲染都走这里，免得两套筛选逻辑各改一半漂掉。
    /// </summary>
    private void CollectVisible(double viewportHeight, List<PlaytestRuntimeNote> into)
    {
        into.Clear();
        if (session == null || !double.IsFinite(viewportHeight) || viewportHeight <= 0) return;
        var pixelsPerBeat =
            WindowsPlaytestScrollVelocityPolicy.PixelsPerScrollBeat(scrollSpeed, baseBpm);
        var judgementY = viewportHeight * judgementLinePosition;
        var margin = Math.Max(1, noteHeight / pixelsPerBeat + .5);
        var minimumStart = currentScrollPosition -
                           (viewportHeight - judgementY) / pixelsPerBeat - margin;
        var maximumStart = currentScrollPosition + judgementY / pixelsPerBeat + margin;
        var (windowStart, windowEnd) = VisibleTimeWindow(viewportHeight);
        var visited = 0;
        for (var index = LowerBoundStart(notes, windowStart);
             index < notes.Count && notes[index].StartMilliseconds <= windowEnd;
             index++)
        {
            var note = notes[index];
            visited++;
            if (note.Completed || !IsSpanVisible(note, minimumStart, maximumStart)) continue;
            into.Add(note);
        }
        // 时间窗只是快路径，不是可见性判据。谱面预览（33582 的 164–180）就是靠 `scroll` 倒流
        // 加 `jump 5000` 把 +100 拍的 note 折进同一个屏幕窗口，任何以「时间离得近」为前提的剪枝
        // 都会把它整段剪光（实测 164.5 之后 vis 恒为 0）。所以窗外的 note 一律交回坐标判据。
        CollectFolded(
            positionIntervals,
            minimumStart,
            maximumStart,
            windowStart,
            windowEnd,
            into,
            ref visited);
        DropFoldedDistantNotes(into);
        lastVisitedNotes = visited;
        maximumVisitedNotes = Math.Max(maximumVisitedNotes, visited);
    }

    /// <summary>
    /// 一屏只画同一个时间段：屏内已经有「时间上就在附近」的 note 时，
    /// 被 <c>jump</c> 从十几拍以后折进来的那些不再画。
    /// </summary>
    /// <remarks>
    /// <para>抖动 / 频闪段是拿一串反向 <c>jump</c> 去抵掉 <c>scroll</c> 前进的量。
    /// regain 182–187 实测：坐标只前进 <c>+9.83</c> 拍，jump 却倒退 <c>−8.81</c> 拍，
    /// 于是净位移只有 <c>+1.02</c> 拍 —— 二十拍以后的谱面被折进同一个屏幕窗口，
    /// 和正在往下流的谱面叠在一起。这一段在 Malody 里看不见这些 note。</para>
    /// <para>不裁的情况：整屏都是折进来的内容。帧定格（AX 132–144）、谱面预览
    /// （33582 164–180，屏上是 +100 拍处的谱）、倒流段都属于这一类，
    /// 那时屏幕本来就是用来显示别的时间段的。</para>
    /// <para>只裁「整条都在未来且离得远」的 note。已经过去的 note 被负速段送回来
    /// （198–212 实测 −19.8 拍）不裁，那是倒流写法本身的结果；长条只要有一端
    /// 落在附近窗口里就保留，否则跨屏长条会缺一块。</para>
    /// </remarks>
    private void DropFoldedDistantNotes(List<PlaytestRuntimeNote> into)
    {
        if (session == null || into.Count == 0) return;
        var nowBeat = session.TimingMap.MillisecondsToBeat(currentMilliseconds).Value;
        var nearby = false;
        foreach (var note in into)
        {
            var (head, tail) = BeatSpan(note);
            if (Math.Abs(head - nowBeat) <= NearbyBeatWindowBeats ||
                Math.Abs(tail - nowBeat) <= NearbyBeatWindowBeats)
            {
                nearby = true;
                break;
            }
        }
        if (!nearby) return;
        into.RemoveAll(note =>
        {
            var (head, tail) = BeatSpan(note);
            return head - nowBeat > NearbyBeatWindowBeats && tail - nowBeat > NearbyBeatWindowBeats;
        });
    }

    /// <summary>note 的拍号区间。单点 note 两个端点相同。</summary>
    private static (double Head, double Tail) BeatSpan(PlaytestRuntimeNote note) =>
        note.Note.IsHold
            ? (note.Note.Beat.Value, note.Note.EndBeat?.Value ?? note.Note.Beat.Value)
            : (note.Note.Beat.Value, note.Note.Beat.Value);

    public override void Render(DrawingContext context)
    {
        base.Render(context);
        var size = Bounds.Size;
        if (size.Width <= 0 || size.Height <= 0) return;
        using var clip = context.PushClip(new Rect(size));
        context.FillRectangle(BackgroundBrush, new Rect(size));
        var keyCount = session?.KeyCount ?? 4;
        var width = Math.Min(size.Width, playfieldWidth);
        var origin = (size.Width - width) / 2;
        var laneWidth = width / Math.Max(1, keyCount);
        for (var lane = 0; lane < keyCount; lane++)
        {
            context.FillRectangle(
                lane % 2 == 0 ? LaneABrush : LaneBBrush,
                new Rect(origin + lane * laneWidth, 0, laneWidth, size.Height));
        }
        var judgementY = size.Height * judgementLinePosition;
        DrawSlots(context, keyCount, origin, laneWidth, judgementY);
        DrawNotes(context, size.Height, origin, laneWidth, judgementY);
    }

    private void DrawSlots(
        DrawingContext context,
        int keyCount,
        double origin,
        double laneWidth,
        double judgementY)
    {
        var slotWidth = laneWidth * noteWidth;
        for (var lane = 0; lane < keyCount; lane++)
        {
            var active = lane < pressed.Length && pressed[lane];
            var fill = active ? SlotPressedFillBrush : SlotFillBrush;
            var pen = active ? SlotPressedPen : SlotPen;
            var center = new Point(origin + (lane + .5) * laneWidth, judgementY);
            if (style == WindowsPlaytestNoteStyle.Circle)
                context.DrawEllipse(fill, pen, center, slotWidth / 2, noteHeight / 2);
            else
            {
                var height = Math.Max(24, noteHeight * 1.35);
                context.DrawRectangle(
                    fill,
                    pen,
                    new Rect(center.X - slotWidth / 2, judgementY - height / 2, slotWidth, height),
                    6,
                    6);
            }
        }
    }

    private void DrawNotes(
        DrawingContext context,
        double height,
        double origin,
        double laneWidth,
        double judgementY)
    {
        var pixelsPerBeat =
            WindowsPlaytestScrollVelocityPolicy.PixelsPerScrollBeat(scrollSpeed, baseBpm);
        CollectVisible(height, visibleNotes);
        foreach (var note in visibleNotes)
            DrawNote(context, note, origin, laneWidth, judgementY, pixelsPerBeat);
    }

    /// <summary>
    /// 快路径的时间窗（拍）。<b>它不是可见性判据</b>，只是让 99% 的帧不用碰区间树。
    /// </summary>
    /// <remarks>
    /// 前后不对称：往前 4.5~5 拍（慢速段和长条会把更远的 note 提前拉进屏幕），往回 2 拍
    /// （屏幕下方本来就只留半拍）。窗外的 note 由 <see cref="CollectFolded"/> 按坐标补，
    /// 所以这个窗给窄了不会漏画，只会多走一次树查询。
    /// </remarks>
    private (double Start, double End) VisibleTimeWindow(double viewportHeight)
    {
        var pixelsPerBeat =
            WindowsPlaytestScrollVelocityPolicy.PixelsPerScrollBeat(scrollSpeed, baseBpm);
        var screenBeats = pixelsPerBeat > 0 ? viewportHeight / pixelsPerBeat : 0;
        var forwardBeats = Math.Clamp(
            screenBeats * 1.2,
            MinimumForwardWindowBeats,
            MaximumForwardWindowBeats);
        var beat = session?.TimingMap.MillisecondsToBeat(currentMilliseconds) ?? BeatPosition.Zero;
        var bpm = session?.TimingMap.BpmAt(beat) ?? baseBpm;
        var millisecondsPerBeat = bpm > 0 && double.IsFinite(bpm) ? 60000d / bpm : 60000d / baseBpm;
        return (currentMilliseconds - BackwardWindowBeats * millisecondsPerBeat,
                currentMilliseconds + forwardBeats * millisecondsPerBeat);
    }

    /// <summary>
    /// note 在屏幕上的纵向占位是 [head, tail]；只要这个区间和屏幕窗口有交集就要画。
    /// 这样长条跨窗口的情况（头已经在屏幕上方、身体还挂在屏上）不用另开一套判断。
    /// </summary>
    private static bool IsSpanVisible(
        PlaytestRuntimeNote note,
        double minimumStart,
        double maximumStart)
    {
        var head = note.StartScrollPosition;
        var tail = note.Note.IsHold ? note.EndScrollPosition : head;
        return Math.Max(head, tail) >= minimumStart && Math.Min(head, tail) <= maximumStart;
    }

    private void DrawNote(
        DrawingContext context,
        PlaytestRuntimeNote runtime,
        double origin,
        double laneWidth,
        double judgementY,
        double pixelsPerBeat)
    {
        if (runtime.Note.Lane < 0 || session == null || runtime.Note.Lane >= session.KeyCount) return;
        var width = laneWidth * noteWidth;
        var x = origin + runtime.Note.Lane * laneWidth + (laneWidth - width) / 2;
        var naturalHeadY = judgementY -
                           (runtime.StartScrollPosition - currentScrollPosition) * pixelsPerBeat;
        var headY = runtime.Note.IsHold && runtime.HeadJudged ? judgementY : naturalHeadY;
        var tailY = judgementY -
                    (runtime.EndScrollPosition - currentScrollPosition) * pixelsPerBeat;
        var fill = runtime.Grade == PlaytestHitGrade.Miss
            ? MissFillBrush
            : runtime.Note.IsHold ? HoldHeadFillBrush : NoteFillBrush;
        if (!runtime.Note.IsHold)
        {
            DrawHead(context, new Rect(x, headY - noteHeight / 2, width, noteHeight), fill, NotePen);
            return;
        }

        var top = Math.Min(headY, tailY);
        var bottom = Math.Max(headY, tailY);
        var bodyWidth = Math.Max(
            6,
            width * (style == WindowsPlaytestNoteStyle.Circle ? .58 : .72));
        var body = new Rect(x + (width - bodyWidth) / 2, top, bodyWidth, Math.Max(1, bottom - top));
        var radius = style == WindowsPlaytestNoteStyle.Circle ? bodyWidth / 2 : 3;
        var bodyFill = runtime.Grade == PlaytestHitGrade.Miss
            ? MissFillBrush
            : runtime.Holding ? HoldActiveFillBrush : HoldFillBrush;
        context.DrawRectangle(
            bodyFill,
            runtime.Holding ? HoldActivePen : HoldBodyPen,
            body,
            radius,
            radius);
        if (!runtime.HeadJudged)
            DrawHead(
                context,
                new Rect(x, headY - noteHeight / 2, width, noteHeight),
                fill,
                HoldHeadPen);
    }

    private void DrawHead(DrawingContext context, Rect rect, IBrush fill, Pen pen)
    {
        if (style == WindowsPlaytestNoteStyle.Circle)
            context.DrawEllipse(
                fill,
                pen,
                new Point(rect.X + rect.Width / 2, rect.Y + rect.Height / 2),
                rect.Width / 2,
                rect.Height / 2);
        else
            context.DrawRectangle(fill, pen, rect, 4, 4);
    }

    /// <summary>
    /// 按<b>时间</b>二分。数组必须是时间序（<see cref="SetSession"/> 里排的），
    /// 不能按滚动坐标——坐标非单调，二分在那种数组上返回的区间是随机的。
    /// </summary>
    private static int LowerBoundStart(
        IReadOnlyList<PlaytestRuntimeNote> source,
        double milliseconds)
    {
        var low = 0;
        var high = source.Count;
        while (low < high)
        {
            var middle = low + (high - low) / 2;
            if (source[middle].StartMilliseconds < milliseconds) low = middle + 1;
            else high = middle;
        }
        return low;
    }

    /// <summary>
    /// 补「时间窗之外、但滚动坐标落在屏幕窗口里」的 note。
    /// </summary>
    /// <remarks>
    /// <para>四种情况会落到这里：长条从窗口外伸进来、负速段把后面的谱面倒着送到屏上、
    /// <c>jump</c> 把远处的 note 折进来（震颤 / 帧定格）、以及谱面预览（把 +100 拍的整段谱折进屏内）。</para>
    /// <para>树按「两个端点的较小值」排序建平衡 BST，节点存子树里端点较大值的最大值，剪枝靠这两条：
    /// 子树最小端点都超过屏幕上界 → 整棵在屏上方，砍；子树最大端点都不够屏幕下界 → 整棵在屏下方，砍。
    /// 命中条件是区间相交（头的坐标 ≤ 上界 且 尾的坐标 ≥ 下界），单点 note 两个端点相同、自然退化成一个点查询。</para>
    /// <para>只在时间窗外的 note 才收：窗内的已经由主循环按时间二分扫过了，
    /// 不区分的话长条会被收两遍（表现是半透明条子叠色变深、可见数虚高）。</para>
    /// </remarks>
    private static void CollectFolded(
        PositionIntervalNode? node,
        double minimumStart,
        double maximumStart,
        double windowStart,
        double windowEnd,
        List<PlaytestRuntimeNote> into,
        ref int visited)
    {
        if (node == null || node.SubtreeMaximumEnd < minimumStart) return;
        if (node.Left is { } left && left.SubtreeMaximumEnd >= minimumStart)
            CollectFolded(left, minimumStart, maximumStart, windowStart, windowEnd, into, ref visited);
        visited++;
        var note = node.Note;
        if (!note.Completed &&
            IsSpanVisible(note, minimumStart, maximumStart) &&
            (note.StartMilliseconds < windowStart || note.StartMilliseconds > windowEnd))
            into.Add(note);
        if (node.Right is { } right && right.SubtreeMinimumStart <= maximumStart)
            CollectFolded(right, minimumStart, maximumStart, windowStart, windowEnd, into, ref visited);
    }

    private static PositionIntervalNode? BuildPositionIntervals(
        IReadOnlyList<PlaytestRuntimeNote> source,
        int start,
        int end)
    {
        if (start >= end) return null;
        var middle = start + (end - start) / 2;
        return new PositionIntervalNode(
            source[middle],
            BuildPositionIntervals(source, start, middle),
            BuildPositionIntervals(source, middle + 1, end));
    }

    private static IBrush Brush(string value) => new SolidColorBrush(Color.Parse(value));

    private sealed class PositionIntervalNode
    {
        public PositionIntervalNode(
            PlaytestRuntimeNote note,
            PositionIntervalNode? left,
            PositionIntervalNode? right)
        {
            Note = note;
            Left = left;
            Right = right;
            var minimum = Math.Min(note.StartScrollPosition, note.EndScrollPosition);
            var maximum = Math.Max(note.StartScrollPosition, note.EndScrollPosition);
            SubtreeMinimumStart = Math.Min(
                minimum,
                Math.Min(
                    left?.SubtreeMinimumStart ?? double.PositiveInfinity,
                    right?.SubtreeMinimumStart ?? double.PositiveInfinity));
            SubtreeMaximumEnd = Math.Max(
                maximum,
                Math.Max(
                    left?.SubtreeMaximumEnd ?? double.NegativeInfinity,
                    right?.SubtreeMaximumEnd ?? double.NegativeInfinity));
        }

        public PlaytestRuntimeNote Note { get; }
        public PositionIntervalNode? Left { get; }
        public PositionIntervalNode? Right { get; }
        public double SubtreeMinimumStart { get; }
        public double SubtreeMaximumEnd { get; }
    }
}
