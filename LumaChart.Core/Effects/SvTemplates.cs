using LumaChart.Core.Models;

namespace LumaChart.Core.Effects;

internal static class SvTemplateMath
{
    public static int StepCount(SvTemplateContext context, double minimumWindow = 0)
    {
        var window = Math.Max(context.LengthBeats, minimumWindow);
        var steps = (int)Math.Round(window * context.StepDenominator, MidpointRounding.AwayFromZero);
        return Math.Clamp(steps, 1, 4000);
    }
}

/// <summary>Holds one speed for the whole window, then resets.</summary>
public sealed class SvHoldTemplate : SvTemplate
{
    public override SvTemplateDefinition Definition { get; } = new(
        "hold", "保持 / 复位",
        "区间内速度恒定，结束时复位成 1。用来截断上一段效果。",
        SvTemplateGroup.Displacement,
        [new SvTemplateSlot("value", "速度", SvSlotKind.Number, 1, -16, 16, "×")],
        UsesTarget: false,
        PreferredStepDenominator: 4);

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var value = context.Slot("value", 1);
        var end = SvBeatMath.AddBeats(context.Start, context.LengthBeats);
        var rows = new List<SvTemplateRow>
        {
            ScrollRow(context.Start, value),
            ScrollRow(end, context.TailValue)
        };
        return FromRows(context, rows, value * context.LengthBeats, context.LengthBeats, 0, 0, null);
    }

    public override IReadOnlyList<string> Describe(SvTemplateContext context, SvTemplateDraft draft)
    {
        var value = context.Slot("value", 1);
        return
        [
            $"整段把速度钉在 {Number(value)} 倍不动（1 倍 = 正常速度）",
            "它本身没什么观感，作用是把上一段留下的效果截断，让后面从正常速度重新开始",
            ShiftText(draft)
        ];
    }
}

/// <summary>Two-step speed jump: one value for a fraction of the window, the other for the rest.</summary>
public sealed class SvTwoStepTemplate : SvTemplate
{
    private readonly bool slowFirst;

    public SvTwoStepTemplate(bool slowFirst)
    {
        this.slowFirst = slowFirst;
        Definition = new SvTemplateDefinition(
            slowFirst ? "bump-slow-fast" : "bump-fast-slow",
            slowFirst ? "先慢后快（刹车）" : "先快后慢（冲撞）",
            slowFirst
                ? "前段降速、后段加速补回位移，播放前会先顿一下再冲出去。"
                : "前段提速、后段降速补回位移，进拍瞬间冲击力更强。",
            SvTemplateGroup.Displacement,
            [
                new SvTemplateSlot("split", "第一段占比", SvSlotKind.Number, 0.5, 0.05, 0.95, "", "第一段占整个区间的比例"),
                new SvTemplateSlot("value", "第一段速度", SvSlotKind.Number, slowFirst ? 0.5 : 1.75, -8, 16, "×")
            ],
            PreferredStepDenominator: 4);
    }

    public override SvTemplateDefinition Definition { get; }

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var n = SvTemplateMath.StepCount(context);
        var split = context.Slot("split", 0.5);
        var first = Math.Clamp((int)Math.Round(n * split), 1, Math.Max(1, n - 1));
        var value = context.Slot("value", slowFirst ? 0.5 : 1.75);
        var second = (context.TargetDisplacement * n - value * first) / (n - first);
        var values = new double[n];
        for (var i = 0; i < n; i++) values[i] = i < first ? value : second;
        return Compose(context, values,
            Math.Abs(second) > 16
                ? [$"补偿段算出 {second:0.##} 倍速，超过 16 倍；把第一段占比或速度改小一点"]
                : null);
    }
}

/// <summary>Zero speed for most of the window, then one fast segment covering the whole displacement.</summary>
public sealed class SvStopPulseTemplate : SvTemplate
{
    public override SvTemplateDefinition Definition { get; } = new(
        "stop-pulse", "停顿 + 瞬移",
        "先停住不动，最后一段突然补位移。单周期版本。",
        SvTemplateGroup.Displacement,
        [new SvTemplateSlot("split", "停顿占比", SvSlotKind.Number, 0.75, 0.1, 0.95, "", "停住的时间占整个区间的比例")],
        PreferredStepDenominator: 8);

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var n = SvTemplateMath.StepCount(context);
        var split = context.Slot("split", 0.75);
        var stopped = Math.Clamp((int)Math.Round(n * split), 1, Math.Max(1, n - 1));
        var high = context.TargetDisplacement * n / (n - stopped);
        var values = new double[n];
        for (var i = stopped; i < n; i++) values[i] = high;
        return Compose(context, values);
    }
}

/// <summary>Repeats the stop pulse: the frame-drop look.</summary>
public sealed class SvPulseTrainTemplate : SvTemplate
{
    public override SvTemplateDefinition Definition { get; } = new(
        "pulse-train", "卡顿列",
        "停顿脉冲重复若干次，周期越短越像掉帧。",
        SvTemplateGroup.Displacement,
        [
            new SvTemplateSlot("period", "周期", SvSlotKind.Number, 0.5, 0.0625, 4, "拍"),
            new SvTemplateSlot("split", "停顿占比", SvSlotKind.Number, 0.75, 0.1, 0.95)
        ],
        PreferredStepDenominator: 8,
        Presets:
        [
            SvTemplatePreset.Of("微抖", ("period", 0.25), ("split", 0.6)),
            SvTemplatePreset.Of("掉帧", ("period", 0.5), ("split", 0.75)),
            SvTemplatePreset.Of("硬卡", ("period", 2), ("split", 0.9))
        ]);

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var n = SvTemplateMath.StepCount(context);
        var split = context.Slot("split", 0.75);
        var period = context.Slot("period", 0.5);
        var periodSteps = Math.Max(2, (int)Math.Round(period * context.StepDenominator));
        var stopped = Math.Clamp((int)Math.Round(periodSteps * split), 1, periodSteps - 1);
        var high = context.TargetDisplacement * periodSteps / (periodSteps - stopped);
        var values = new double[n];
        for (var i = 0; i < n; i++)
            values[i] = i % periodSteps < stopped ? 0 : high;
        return Compose(context, values);
    }
}

/// <summary>Straight ramp between two speeds.</summary>
public sealed class SvRampLinearTemplate : SvTemplate
{
    public override SvTemplateDefinition Definition { get; } = new(
        "ramp-linear", "匀速加/减速",
        "速度沿直线从起值变到终值；勾选平移时平均速度会被拉到目标位移。",
        SvTemplateGroup.Shape,
        [
            new SvTemplateSlot("from", "起值", SvSlotKind.Number, 1.5, -8, 16, "×"),
            new SvTemplateSlot("to", "终值", SvSlotKind.Number, 0.5, -8, 16, "×"),
            new SvTemplateSlot("compensate", "按目标位移平移", SvSlotKind.Integer, 1, 0, 1)
        ],
        PreferredStepDenominator: 10,
        Presets:
        [
            SvTemplatePreset.Of("缓缓加速", ("from", 0.5), ("to", 1.5)),
            SvTemplatePreset.Of("缓缓刹车", ("from", 1.5), ("to", 0.5)),
            SvTemplatePreset.Of("从停住起步", ("from", 0.05), ("to", 1.5))
        ]);

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var n = SvTemplateMath.StepCount(context);
        var from = context.Slot("from", 1.5);
        var to = context.Slot("to", 0.5);
        var values = new double[n];
        for (var i = 0; i < n; i++)
            values[i] = n == 1 ? from : from + (to - from) * i / (n - 1d);
        if (context.Slot("compensate", 1) >= 0.5)
        {
            var shift = context.TargetDisplacement - values.Average();
            for (var i = 0; i < n; i++) values[i] += shift;
        }
        return Compose(context, values);
    }

    public override IReadOnlyList<string> Describe(SvTemplateContext context, SvTemplateDraft draft)
    {
        var from = context.Slot("from", 1.5);
        var to = context.Slot("to", 0.5);
        var direction = to > from + 1e-9 ? "越来越快"
            : to < from - 1e-9 ? "越来越慢"
            : "一直不变";
        return
        [
            $"整段速度{direction}：从 {Number(from)} 倍连续变到 {Number(to)} 倍 —— 不是突变，是慢慢过渡",
            "画面上 note 的间距会慢慢变松或者变紧，没有「咔」的一下",
            ShiftText(draft)
        ];
    }
}

/// <summary>Any named easing shape, normalized so the mean equals the target displacement.</summary>
public sealed class SvRampCurveTemplate : SvTemplate
{
    public override SvTemplateDefinition Definition { get; } = new(
        "ramp-curve", "曲线加/减速",
        "沿缓动曲线变速；均值会被归一化，所以任何曲线都精确满足目标位移。",
        SvTemplateGroup.Shape,
        [
            new SvTemplateSlot("curve", "曲线", SvSlotKind.Curve, (double)SvCurveKind.EaseInOut, 0, 5),
            new SvTemplateSlot("amplitude", "幅度", SvSlotKind.Number, 0.5, 0, 3, "×")
        ],
        PreferredStepDenominator: 10);

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var n = SvTemplateMath.StepCount(context);
        var kind = (SvCurveKind)(int)Math.Round(context.Slot("curve", (double)SvCurveKind.EaseInOut));
        var amplitude = Math.Max(0, context.Slot("amplitude", 0.5));
        var values = SvCurveLibrary.Sample(kind, n, amplitude, context.TargetDisplacement);
        var warnings = new List<string>();
        if (values.Min() < 0)
            warnings.Add("曲线穿到 0 以下（出现倒流），这是当前幅度的结果，确认是否需要");
        return Compose(context, values, warnings);
    }
}

/// <summary>Sine wobble around the target speed.</summary>
public sealed class SvWobbleSineTemplate : SvTemplate
{
    public override SvTemplateDefinition Definition { get; } = new(
        "wobble-sine", "正弦往复",
        "速度在目标值上下按正弦摆动，长音段落常用来做呼吸感。",
        SvTemplateGroup.Shape,
        [
            new SvTemplateSlot("cycles", "周期数", SvSlotKind.Number, 2, 0.5, 16, "个"),
            new SvTemplateSlot("amplitude", "幅度", SvSlotKind.Number, 0.3, 0, 2, "×")
        ],
        PreferredStepDenominator: 20,
        Presets:
        [
            SvTemplatePreset.Of("轻轻呼吸", ("cycles", 1), ("amplitude", 0.15)),
            SvTemplatePreset.Of("明显来回", ("cycles", 3), ("amplitude", 0.5))
        ]);

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var n = SvTemplateMath.StepCount(context);
        var cycles = context.Slot("cycles", 2);
        var amplitude = Math.Max(0, context.Slot("amplitude", 0.3));
        var raw = new double[n];
        for (var i = 0; i < n; i++)
            raw[i] = Math.Sin(2 * Math.PI * cycles * i / n);
        var mean = raw.Average();
        var values = new double[n];
        for (var i = 0; i < n; i++)
            values[i] = context.TargetDisplacement + amplitude * (raw[i] - mean);
        return Compose(context, values);
    }
}

/// <summary>One micro-step that covers a chosen distance, then resume.</summary>
public sealed class SvTeleportTemplate : SvTemplate
{
    public override SvTemplateDefinition Definition { get; } = new(
        "teleport", "瞬移 / 闪现入场",
        "用一步走完指定距离，然后立刻复位。",
        SvTemplateGroup.Displacement,
        [
            new SvTemplateSlot("distance", "距离", SvSlotKind.Number, 10, 0.01, 128, "拍"),
            new SvTemplateSlot("resume", "复位值", SvSlotKind.Number, 1, -8, 16, "×")
        ],
        UsesTarget: false,
        PreferredStepDenominator: 200,
        Presets:
        [
            SvTemplatePreset.Of("跳一小段", ("distance", 4)),
            SvTemplatePreset.Of("跳半张谱", ("distance", 16)),
            SvTemplatePreset.Of("整段换掉", ("distance", 40))
        ]);

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var distance = context.Slot("distance", 10);
        var resume = context.Slot("resume", 1);
        var value = distance * context.StepDenominator;
        var rows = new List<SvTemplateRow>
        {
            ScrollRow(context.Start, value),
            ScrollRow(SvBeatMath.Offset(context.Start, 1, context.StepDenominator), resume)
        };
        var window = context.StepBeats;
        var milliseconds = 60000d * window / context.BpmAtStart;
        var warnings = new List<string>();
        if (milliseconds < 1.05)
            warnings.Add($"这一步只有 {milliseconds:0.##} ms，Malody 按 1 ms 取整，位移可能被吃掉");
        if (Math.Abs(distance) > 32)
            warnings.Add("瞬移距离超过 32 拍，谱面位置会整体偏移很远");
        return FromRows(context, rows, distance, window, 1, milliseconds, warnings);
    }

    public override IReadOnlyList<string> Describe(SvTemplateContext context, SvTemplateDraft draft)
    {
        var distance = context.Slot("distance", 10);
        var resume = context.Slot("resume", 1);
        return
        [
            $"在一步之内（1/{context.StepDenominator} 拍）把谱面整个推 {Number(Math.Abs(distance))} 拍，" +
                $"紧接着换成 {Number(resume)} 倍速",
            "观感是画面「啪」地换了个位置，note 忽然出现在别处 —— 不是滚动，是一下子跳过去的",
            Math.Abs(resume - 1) < 1e-9
                ? $"跳完速度回到 1 倍，但谱面已经整体{(distance >= 0 ? "往前" : "往后")}挪了 " +
                    $"{Number(Math.Abs(distance))} 拍 —— 这是真位移，不会自己回来，要靠下一段补"
                : $"跳完停在 {Number(resume)} 倍速；谱面已经整体挪了 {Number(Math.Abs(distance))} 拍，不会自己回来"
        ];
    }
}

/// <summary>Negative window: notes travel backwards, optionally returning to the same place.</summary>
public sealed class SvReverseTemplate : SvTemplate
{
    public override SvTemplateDefinition Definition { get; } = new(
        "reverse", "倒流 / 反向段",
        "负速度让 note 从判定线往回走；目标位移 0 表示冲过来再回去。",
        SvTemplateGroup.Displacement,
        [
            new SvTemplateSlot("value", "倒流速度", SvSlotKind.Number, -1.5, -16, -0.01, "×"),
            new SvTemplateSlot("split", "倒流占比", SvSlotKind.Number, 0.5, 0.1, 0.9)
        ],
        PreferredStepDenominator: 4,
        Presets:
        [
            SvTemplatePreset.Of("慢慢倒回来", ("value", -1), ("split", 0.5)),
            SvTemplatePreset.Of("猛地倒回去", ("value", -4), ("split", 0.3))
        ]);

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var n = SvTemplateMath.StepCount(context);
        var value = Math.Min(-0.01, context.Slot("value", -1.5));
        var split = context.Slot("split", 0.5);
        var first = Math.Clamp((int)Math.Round(n * split), 1, Math.Max(1, n - 1));
        var second = (context.TargetDisplacement * n - value * first) / (n - first);
        var values = new double[n];
        for (var i = 0; i < n; i++) values[i] = i < first ? value : second;
        return Compose(context, values);
    }
}

/// <summary>Opposite jump pairs: the chart blinks to another position and back.</summary>
public sealed class SvJumpFlickerTemplate : SvTemplate
{
    public override SvTemplateDefinition Definition { get; } = new(
        "jump-flicker", "闪烁 / 抽帧",
        "向外跳一段再跳回来；间隔太短看不出，太长会像换了一张谱。",
        SvTemplateGroup.Event,
        [
            new SvTemplateSlot("gap", "间隔", SvSlotKind.Number, 1d / 32, 0.001, 1, "拍"),
            new SvTemplateSlot("distance", "跳跃距离", SvSlotKind.Number, 2, 0.05, 64, "拍"),
            new SvTemplateSlot("repeats", "重复", SvSlotKind.Integer, 1, 1, 64, "组")
        ],
        UsesTarget: false,
        PreferredStepDenominator: 32);

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var gap = context.Slot("gap", 1d / 32);
        var distance = context.Slot("distance", 2);
        var repeats = Math.Clamp((int)Math.Round(context.Slot("repeats", 1)), 1, 64);
        var bpm = context.BpmAtStart;
        var scroll = Math.Abs(context.TargetDisplacement) < 1e-6 ? 1 : context.TargetDisplacement;
        var jump = distance * 60000d / (scroll * bpm);
        var rows = new List<SvTemplateRow>();
        var gapMs = 60000d * gap / bpm;
        for (var i = 0; i < repeats; i++)
        {
            var start = SvBeatMath.AddBeats(context.Start, i * gap * 2);
            var end = SvBeatMath.AddBeats(context.Start, i * gap * 2 + gap);
            rows.Add(JumpRow(start, jump));
            rows.Add(JumpRow(end, -jump));
        }
        var warnings = new List<string>();
        if (gapMs < 15)
            warnings.Add($"单帧只有 {gapMs:0.#} ms，低于 15 ms 通常看不出闪烁");
        if (gapMs > 400)
            warnings.Add($"单帧 {gapMs:0} ms，太长的闪烁会被当成另一张谱");
        return FromRows(context, rows, 0, repeats * gap * 2, 0, gapMs, warnings);
    }

    public override IReadOnlyList<string> Describe(SvTemplateContext context, SvTemplateDraft draft)
    {
        var gap = context.Slot("gap", 1d / 32);
        var gapMs = 60000d * gap / context.BpmAtStart;
        var repeats = Math.Clamp((int)Math.Round(context.Slot("repeats", 1)), 1, 64);
        return
        [
            $"整屏跳到另一个位置再跳回来，重复 {repeats} 次，每次间隔 {Number(gapMs)} ms",
            "速度本身没变，变的是位置 —— 看起来像抽帧、画面抖了一下",
            "跳完回到原处，谱面位置不变"
        ];
    }
}

/// <summary>Keeps the visual speed constant across BPM changes.</summary>
public sealed class SvBpmBalanceTemplate : SvTemplate
{
    public override SvTemplateDefinition Definition { get; } = new(
        "bpm-balance", "BPM 补偿",
        "按 基准BPM ÷ 当前BPM 逐段写，让视觉速度不随 BPM 变化。这是流速补正，不是特效。",
        SvTemplateGroup.Bpm,
        [new SvTemplateSlot("base", "基准 BPM（0=自动）", SvSlotKind.Number, 0, 0, 1000, "BPM")],
        UsesTarget: false,
        PreferredStepDenominator: 4);

    public override SvTemplateDraft Build(SvTemplateContext context)
    {
        var n = SvTemplateMath.StepCount(context);
        var baseBpm = context.Slot("base", 0);
        if (!double.IsFinite(baseBpm) || baseBpm <= 0) baseBpm = context.ReferenceBpm;
        var values = new double[n];
        for (var i = 0; i < n; i++)
        {
            var beat = SvBeatMath.Offset(context.Start, i, context.StepDenominator);
            var bpm = context.BpmAt(beat);
            values[i] = bpm > 0 && double.IsFinite(bpm) ? baseBpm / bpm : 1;
        }
        var warnings = new List<string>();
        if (values.Distinct().Count() == 1)
            warnings.Add("这个区间里 BPM 没有变化，补偿结果全是同一个值，可以不写");
        return Compose(context, values, warnings);
    }
}

/// <summary>Registry: adding a formula means adding a class and one entry here.</summary>
public static class SvTemplateCatalog
{
    public static IReadOnlyList<SvTemplate> All { get; } =
    [
        new SvHoldTemplate(),
        new SvTwoStepTemplate(slowFirst: true),
        new SvTwoStepTemplate(slowFirst: false),
        new SvStopPulseTemplate(),
        new SvPulseTrainTemplate(),
        new SvPushTemplate(),
        new SvRampLinearTemplate(),
        new SvRampCurveTemplate(),
        new SvWobbleSineTemplate(),
        new SvStutterTemplate(),
        new SvTeleportTemplate(),
        new SvReverseTemplate(),
        new SvJumpFlickerTemplate(),
        new SvFrameLockTemplate(),
        new SvBpmBalanceTemplate()
    ];

    public static SvTemplate? Find(string id) =>
        All.FirstOrDefault(template => template.Definition.Id.Equals(id, StringComparison.Ordinal));

    public static string GroupLabel(SvTemplateGroup group) => group switch
    {
        SvTemplateGroup.Displacement => "位移",
        SvTemplateGroup.Shape => "曲线",
        SvTemplateGroup.Event => "事件",
        SvTemplateGroup.Frame => "帧表",
        SvTemplateGroup.Bpm => "BPM",
        _ => "其他"
    };
}
