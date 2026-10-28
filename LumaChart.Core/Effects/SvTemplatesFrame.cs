using System.Globalization;
using LumaChart.Core.Models;

namespace LumaChart.Core.Effects;

/// <summary>
/// One accentuated shove: the speed overshoots inside a short sub-span, then sits
/// below normal for the rest of the span, then resets.
/// </summary>
/// <remarks>
/// The two segments are solved so the mean is exactly the target speed:
/// <c>Ls = (1-s)·m</c>, <c>Hs = m·(1 + s·(1-p)/p)</c>, hence <c>p·Hs + (1-p)·Ls = m</c>.
/// With <c>m = 1, p = 0.25, s = 0.75</c> this yields 3.25 → 0.25, which is exactly the
/// three-row form used by <c>Another Xronixle</c>; those values are the acceptance case.
/// </remarks>
public sealed class SvPushTemplate : SvTemplate
{
    public override SvTemplateDefinition Definition { get; } = new(
        "push", "冲一下",
        "跨度内前半段拉高、后半段压在低速，末尾复位。净位移由目标速度精确守恒，不会越用越偏。",
        SvTemplateGroup.Displacement,
        [
            new SvTemplateSlot(
                "share", "冲程占比", SvSlotKind.Number, 0.25, 0.1, 0.9, "",
                "冲出去那一段占整个跨度的比例；越小越炸，3.25 倍的那一版是 0.25"),
            new SvTemplateSlot(
                "strength", "强度", SvSlotKind.Number, 0.75, 0.05, 0.95, "",
                "高低差距。0.75 得到 3.25 / 0.25，1 附近低速接近停住")
        ],
        PreferredStepDenominator: 16,
        Presets:
        [
            SvTemplatePreset.Of("轻推", ("share", 0.35), ("strength", 0.35)),
            SvTemplatePreset.Of("标准", ("share", 0.25), ("strength", 0.75)),
            SvTemplatePreset.Of("狠狠窜", ("share", 0.15), ("strength", 0.9)),
            SvTemplatePreset.Of("停住再窜", ("share", 0.2), ("strength", 0.97))
        ]);

    /// <summary>Span of one shove, in beats. Four 1/16 rows.</summary>
    private const int SpanSteps = 4;

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var share = Math.Clamp(context.Slot("share", 0.25), 0.05, 0.95);
        var strength = Math.Clamp(context.Slot("strength", 0.75), 0.01, 0.99);
        var span = SpanSteps * context.StepBeats;
        var mean = context.TargetDisplacement;

        var low = mean * (1 - strength);
        var high = mean * (1 + strength * (1 - share) / share);
        var switchBeat = SvBeatMath.AddBeats(context.Start, span * share, context.StepDenominator * 4);
        var endBeat = SvBeatMath.AddBeats(context.Start, span, context.StepDenominator);

        var rows = new List<SvTemplateRow>
        {
            ScrollRow(context.Start, high),
            ScrollRow(switchBeat, low),
            ScrollRow(endBeat, context.TailValue)
        };

        var warnings = new List<string>();
        if (Math.Abs(high) > 8)
            warnings.Add($"冲的那一段算出 {high:0.##} 倍速，超过 8 倍；把强度或目标速度调小");
        if (Math.Abs(low) < 0.05 && Math.Abs(mean) > 0.05)
            warnings.Add("低速段几乎停住，观感会更接近「顿一下」而不是「冲一下」");

        return FromRows(context, rows, mean * span, span, 2, MillisecondsPerStep(context), warnings);
    }

    public override IReadOnlyList<string> Describe(SvTemplateContext context, SvTemplateDraft draft)
    {
        var share = Math.Clamp(context.Slot("share", 0.25), 0.05, 0.95);
        var strength = Math.Clamp(context.Slot("strength", 0.75), 0.01, 0.99);
        var mean = context.TargetDisplacement;
        var high = mean * (1 + strength * (1 - share) / share);
        var low = mean * (1 - strength);
        var span = draft.WindowBeats;
        var fast = span * share;
        var slow = Math.Max(0, span - fast);
        var verb = high >= 4 ? "画面在这一小段猛地窜出去"
            : high >= 2 ? "画面在这一小段明显往前冲一段"
            : "画面在这一小段轻轻快一下";
        return
        [
            $"开头 {Number(fast)} 拍（占整段的 {ShareText(share)}）拉到 {Number(high)} 倍速 —— {verb}",
            $"后面 {Number(slow)} 拍压到 {Number(low)} 倍速 —— 慢慢往回爬，像是被拽住了",
            ShiftText(draft)
        ];
    }

    private static double MillisecondsPerStep(SvTemplateContext context) =>
        double.IsFinite(context.BpmAtStart) && context.BpmAtStart > 0
            ? 60000d * context.StepBeats / context.BpmAtStart
            : 0;
}

/// <summary>
/// V-shaped envelope: speed ramps down to <c>depth</c>, holds, then ramps back.
/// Two jump rows carry the displacement the slowdown swallowed, so the net travel
/// stays equal to what normal speed would have produced.
/// </summary>
public sealed class SvStutterTemplate : SvTemplate
{
    public override SvTemplateDefinition Definition { get; } = new(
        "stutter", "顿一下",
        "先降速、冻住一小段、再升回原速。冻结期间靠 jump 把少走的位移补回来，所以不会累积偏差。",
        SvTemplateGroup.Shape,
        [
            new SvTemplateSlot(
                "depth", "谷底速度", SvSlotKind.Number, 0.0001, 0.00001, 0.95, "×",
                "0.0001 = 完全冻住；0.5 = 只是一次减速"),
            new SvTemplateSlot(
                "half", "半宽", SvSlotKind.Number, 0.25, 0.0625, 1, "拍",
                "从中点到一侧的长度，两倍就是整段跨度"),
            new SvTemplateSlot(
                "freeze", "冻结帧", SvSlotKind.Integer, 1, 0, 8, "",
                "谷底停几步；0 表示只有一次快速减速，不真正冻住")
        ],
        PreferredStepDenominator: 40,
        Presets:
        [
            SvTemplatePreset.Of("轻微减速", ("depth", 0.5), ("half", 0.25), ("freeze", 0)),
            SvTemplatePreset.Of("卡住一下", ("depth", 0.0001), ("half", 0.125), ("freeze", 1)),
            SvTemplatePreset.Of("停久一点", ("depth", 0.0001), ("half", 0.25), ("freeze", 3))
        ]);

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var depth = Math.Clamp(context.Slot("depth", 0.0001), 0.00001, 0.95);
        var half = Math.Max(context.Slot("half", 0.25), context.StepBeats);
        var hold = Math.Clamp((int)Math.Round(context.Slot("freeze", 1)), 0, 8);
        var nominal = context.TargetDisplacement;
        var step = context.StepBeats;
        var rampSteps = Math.Max(1, (int)Math.Round(half / step, MidpointRounding.AwayFromZero));

        // Down ramp includes the starting speed, so the first row replaces whatever the
        // previous section left behind instead of stepping down from it.
        var values = new List<double>(rampSteps * 2 + hold + 1);
        for (var i = 0; i <= rampSteps; i++)
            values.Add(nominal + (depth - nominal) * i / rampSteps);
        for (var i = 0; i < hold; i++) values.Add(depth);
        for (var i = rampSteps - 1; i >= 0; i--)
            values.Add(nominal + (depth - nominal) * i / rampSteps);

        var travelled = values.Sum() * step;
        var expected = values.Count * step * nominal;
        var gap = expected - travelled;

        var rows = new List<SvTemplateRow>(values.Count + 3);
        for (var i = 0; i < values.Count; i++)
            rows.Add(ScrollRow(SvBeatMath.Offset(context.Start, i, context.StepDenominator), values[i]));
        if (Math.Abs(nominal - context.TailValue) > 1e-9)
            rows.Add(ScrollRow(SvBeatMath.Offset(context.Start, values.Count, context.StepDenominator),
                context.TailValue));

        var warnings = new List<string>();
        if (Math.Abs(gap) > 1e-9)
        {
            var bpm = context.BpmAtStart;
            var halfGap = gap / 2;
            var jump = halfGap * 60000d / (depth * bpm);
            var firstBeat = SvBeatMath.Offset(context.Start, rampSteps, context.StepDenominator);
            var secondBeat = SvBeatMath.Offset(context.Start, rampSteps + Math.Max(1, hold),
                context.StepDenominator);
            if (hold == 0)
            {
                rows.Add(JumpRow(firstBeat, jump * 2));
                warnings.Add("冻结帧是 0，补位移合成了一记 jump；观感上会是一次小跳而不是均匀推进");
            }
            else
            {
                rows.Add(JumpRow(firstBeat, jump));
                rows.Add(JumpRow(secondBeat, jump));
            }
            if (!double.IsFinite(jump) || Math.Abs(jump) > 1e10)
                warnings.Add("谷底速度太小，补位移的 jump 值已经超过 1e10；把谷底速度调到 0.001 以上");
        }

        var window = values.Count * step;
        var millis = 60000d * step / context.BpmAtStart;
        return FromRows(context, rows, travelled + gap, window, values.Count, millis, warnings);
    }

    public override IReadOnlyList<string> Describe(SvTemplateContext context, SvTemplateDraft draft)
    {
        var depth = Math.Clamp(context.Slot("depth", 0.0001), 0.00001, 0.95);
        var hold = Math.Clamp((int)Math.Round(context.Slot("freeze", 1)), 0, 8);
        var step = context.StepBeats;
        var frozen = depth <= 0.01;
        return
        [
            frozen
                ? "速度一路降到几乎停住 —— 画面定在那儿不动"
                : $"速度一路降到 {Number(depth)} 倍速，明显变慢但还在走",
            hold > 0
                ? $"在谷底停 {hold} 步（约 {Number(hold * step)} 拍），然后升回正常速度"
                : "谷底不停留，降到最低就直接升回正常速度",
            "少走的位移被偷偷补回去了，" + ShiftText(draft).Replace("整段走完，", "", StringComparison.Ordinal),
            "补位移那两下是瞬移，观感上是「卡一下然后弹过去」，不是匀速爬"
        ];
    }
}

/// <summary>
/// Frame lock: scroll is frozen, and every mark swaps the whole screen for the next
/// frame with two jump rows — one throwing the previous frame off screen, one placing
/// the next frame at an exact height.
/// </summary>
/// <remarks>
/// Verified against the twenty-frame grid of <c>_song_27543</c> beats 132–145: the
/// displacement unit is <c>U = 60000 / (freeze × bpm)</c> per beat, the clearing throw
/// is <c>clear × U</c> placed a hair <b>after</b> the mark, and the height row is
/// <c>h × U</c> placed a hair <b>before</b> the next mark. Because the clearing throw
/// lands after its own mark, that mark's notes do not receive it and drop out of view.
/// </remarks>
public sealed class SvFrameLockTemplate : SvTemplate
{
    public override SvTemplateDefinition Definition { get; } = new(
        "frame-lock", "帧定格",
        "滚动冻死，每个节奏点整屏换成下一帧，并停在你给的高度上。高度表循环使用，也可以写成每帧累加（+0.1667）变成一格一格走。",
        SvTemplateGroup.Frame,
        [
            new SvTemplateSlot(
                "heights", "高度表", SvSlotKind.Text, 0, 0, 0, "拍",
                "逗号分隔，循环使用；0 表示停在判定线上。以 + 开头表示每帧累加（例 +0.1667 = 每帧走 1/6 拍）",
                "0.25,0.5,0.75,0"),
            new SvTemplateSlot(
                "clear", "甩出距离", SvSlotKind.Number, 4, 0.5, 64, "拍",
                "每帧开始时把上一帧推走多远；要大于视口高度（约 1.8 拍）才真的看不见"),
            new SvTemplateSlot(
                "frame", "帧间隔", SvSlotKind.Number, 1, 1d / 16, 8, "拍",
                "没有选中 note 时按这个间隔自己排帧；选中 note 时以 note 的拍为准，这一项被忽略")
        ],
        UsesTarget: false,
        PreferredStepDenominator: 4,
        UsesMarks: true,
        Presets:
        [
            SvTemplatePreset.OfText("一格格往上走", "heights", "0.25,0.5,0.75,1,0"),
            SvTemplatePreset.OfText("一路往上爬", "heights", "+0.1667"),
            SvTemplatePreset.OfText("原地停住换帧", "heights", "0"),
            SvTemplatePreset.OfText("上下弹跳", "heights", "0,0.75,0,0.75")
        ]);

    /// <summary>Scroll multiplier the frozen section holds. Matches the sampled charts.</summary>
    private const double FreezeMultiplier = 1e-5;

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var frames = ResolveFrames(context);
        if (frames.Count < 2)
            throw new ArgumentException("帧定格至少要两个节奏点，否则换不出一帧。");

        var clear = Math.Clamp(context.Slot("clear", 4), 0.01, 512);
        var bpm = context.BpmAtStart;
        var unit = 60000d / (FreezeMultiplier * bpm);

        var heights = ParseHeights(context.TextSlot("heights", "0.25,0.5,0.75,0"));
        var gaps = new double[frames.Count];
        for (var k = 0; k < frames.Count; k++)
        {
            var span = k + 1 < frames.Count ? frames[k + 1].First.Value - frames[k].First.Value : gaps[k - 1];
            gaps[k] = span > 0 ? span : 1;
        }
        var epsilon = Math.Min(1d / 400, gaps.Min() / 8);

        // Freeze happens a hair earlier than the first frame so that frame's own notes
        // can still receive their height row (a jump only reaches notes at or after it).
        var rows = new List<SvTemplateRow>(frames.Count * 2 + 2)
        {
            ScrollRow(SvBeatMath.AddBeats(frames[0].First, -2 * epsilon), FreezeMultiplier)
        };

        var warnings = new List<string>();
        if (clear <= 1.81)
            warnings.Add($"甩出距离 {clear:0.##} 拍没有超过视口高度（约 1.81 拍），上一帧会留在屏幕上");

        for (var k = 0; k < frames.Count; k++)
        {
            // The first mark is the sacrifice: its own clearing throw is what removes the
            // section before the effect, so it never appears on screen and takes no height.
            if (k > 0)
            {
                var h = NextHeight(heights, k - 1);
                if (Math.Abs(h) > 1e-9)
                    rows.Add(JumpRow(SvBeatMath.AddBeats(frames[k].First, -epsilon), h * unit));
            }
            // The clearing throw has to land after every note of this frame (a doubled note
            // is often written a few thousandths of a beat later) and before the next frame.
            rows.Add(JumpRow(SvBeatMath.AddBeats(frames[k].Last, epsilon), clear * unit));
        }

        var tail = SvBeatMath.AddBeats(frames[^1].Last, 2 * epsilon);
        rows.Add(ScrollRow(tail, context.TailValue));

        if (Math.Abs(unit) > 1e12)
            warnings.Add("BPM 或冻结倍数算出极大的 jump 值，检查谱面 BPM 是否正常");
        if (rows.Count > 800)
            warnings.Add($"将写入 {rows.Count} 行，Timing 列表会很长");

        var window = tail.Value - frames[0].First.Value;
        var millis = 60000d * Math.Max(window, 1e-6) / bpm;
        return FromRows(context, rows, 0, window, frames.Count, millis, warnings);
    }

    public override IReadOnlyList<string> Describe(SvTemplateContext context, SvTemplateDraft draft)
    {
        var heights = ParseHeights(context.TextSlot("heights", "0.25,0.5,0.75,0"));
        var frames = Math.Max(1, draft.Steps);
        var table = heights.Cumulative
            ? $"每帧比上一帧高 {Number(heights.Values[0])} 拍（一路往上爬）"
            : $"高度表 {string.Join(", ", heights.Values.Select(Number))} 循环使用（0 = 停在判定线上）";
        return
        [
            "整段滚动冻死 —— note 不再朝判定线移动，也不会自己消失",
            $"每到一个节奏点，整屏直接换成下一帧：上一帧被甩出屏幕，下一帧停在指定高度。{table}",
            frames >= 2
                ? $"用了 {frames} 个节奏点，实际能看见 {frames - 1} 帧 —— 第一帧会被自己那记甩出动作带走"
                : "至少要两个节奏点，否则换不出一帧",
            "位置对，高度是你定的；哪一帧出现哪几个键，跟原谱在这个节奏点上有哪几个 note 一致"
        ];
    }

    private static IReadOnlyList<(BeatPosition First, BeatPosition Last)> ResolveFrames(SvTemplateContext context)
    {
        var selected = context.MarksInWindow();
        if (selected.Count >= 2) return MergeCloseMarks(selected);

        var frame = Math.Max(context.Slot("frame", 1), context.StepBeats);
        var count = Math.Clamp((int)Math.Round(context.LengthBeats / frame, MidpointRounding.AwayFromZero), 2, 400);
        var marks = new List<(BeatPosition, BeatPosition)>(count);
        for (var i = 0; i < count; i++)
        {
            var beat = SvBeatMath.AddBeats(context.Start, i * frame);
            marks.Add((beat, beat));
        }
        return marks;
    }

    /// <summary>
    /// Collapses notes that land within 1/64 beat of each other into one frame, keeping
    /// both the first and the last beat of the group: the height row must precede the
    /// whole group, and the clearing throw must follow it.
    /// </summary>
    private static IReadOnlyList<(BeatPosition First, BeatPosition Last)> MergeCloseMarks(
        IReadOnlyList<BeatPosition> marks)
    {
        const double tolerance = 1d / 64;
        var kept = new List<(BeatPosition First, BeatPosition Last)>(marks.Count);
        foreach (var mark in marks)
        {
            if (kept.Count > 0 && mark.Value - kept[^1].First.Value < tolerance)
                kept[^1] = (kept[^1].First, mark);
            else
                kept.Add((mark, mark));
        }
        return kept;
    }

    public static (double[] Values, bool Cumulative) ParseHeights(string text)
    {
        var trimmed = (text ?? string.Empty).Trim();
        if (trimmed.StartsWith('+'))
        {
            var step = ParseNumber(trimmed[1..], 1d / 6);
            return ([step], true);
        }

        var parts = trimmed.Split([',', '，', ' ', ';'], StringSplitOptions.RemoveEmptyEntries);
        var values = new List<double>(parts.Length);
        foreach (var part in parts)
        {
            if (double.TryParse(part.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out var value))
                values.Add(value);
        }
        if (values.Count == 0) values.Add(0);
        return (values.ToArray(), false);
    }

    private static double NextHeight((double[] Values, bool Cumulative) table, int index)
    {
        if (table.Cumulative) return table.Values[0] * (index + 1);
        return table.Values[index % table.Values.Length];
    }

    private static double ParseNumber(string text, double fallback) =>
        double.TryParse(text.Trim().Replace("，", ","), NumberStyles.Float, CultureInfo.InvariantCulture,
            out var value)
            ? value
            : fallback;
}
