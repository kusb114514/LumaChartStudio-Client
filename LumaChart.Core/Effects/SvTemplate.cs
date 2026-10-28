using System.Globalization;
using LumaChart.Core.Models;

namespace LumaChart.Core.Effects;

/// <summary>Picker section. Presentation only; adding a template never touches the UI.</summary>
public enum SvTemplateGroup
{
    Displacement,
    Shape,
    Event,
    /// <summary>Scroll frozen, whole frames swapped by jump rows.</summary>
    Frame,
    Bpm
}

public enum SvSlotKind
{
    Number,
    Integer,
    Curve,
    /// <summary>Free text the template parses itself (height lists and similar).</summary>
    Text
}

public enum SvCurveKind
{
    Linear,
    EaseIn,
    EaseOut,
    EaseInOut,
    Sine,
    Exponential
}

/// <summary>
/// One clickable starting point: a named set of slot values.
/// <para>
/// Presets exist because the slot values are scroll-engine numbers, and a mapper who
/// has never written a scroll effect cannot guess what 0.0001 versus 0.5 looks like.
/// Picking a preset fills every slot at once, so the first usable result takes one
/// click instead of an understanding of the field.
/// </para>
/// </summary>
public sealed record SvTemplatePreset(
    string Name,
    IReadOnlyDictionary<string, double> Values,
    IReadOnlyDictionary<string, string>? TextValues = null)
{
    private static readonly IReadOnlyDictionary<string, string> NoText =
        new Dictionary<string, string>(StringComparer.Ordinal);

    /// <summary>Preset that only sets numeric slots.</summary>
    public static SvTemplatePreset Of(string name, params (string Id, double Value)[] values) =>
        new(name,
            values.ToDictionary(pair => pair.Id, pair => pair.Value, StringComparer.Ordinal),
            NoText);

    /// <summary>Preset that sets one free-text slot (a height list) plus numeric slots.</summary>
    public static SvTemplatePreset OfText(
        string name,
        string textSlotId,
        string text,
        params (string Id, double Value)[] values) =>
        new(name,
            values.ToDictionary(pair => pair.Id, pair => pair.Value, StringComparer.Ordinal),
            new Dictionary<string, string>(StringComparer.Ordinal) { [textSlotId] = text });

    public IReadOnlyDictionary<string, string> Texts => TextValues ?? NoText;
}

/// <summary>One editable field a template exposes; the dialog builds its form from these.</summary>
public sealed record SvTemplateSlot(
    string Id,
    string Label,
    SvSlotKind Kind,
    double Default,
    double Minimum,
    double Maximum,
    string Unit = "",
    string Help = "",
    string DefaultText = "")
{
    public double Clamp(double value) => !double.IsFinite(value)
        ? Default
        : Math.Clamp(value, Minimum, Maximum);
}

public sealed record SvTemplateDefinition(
    string Id,
    string Title,
    string Summary,
    SvTemplateGroup Group,
    IReadOnlyList<SvTemplateSlot> Slots,
    bool UsesTarget = true,
    int PreferredStepDenominator = 8,
    /// <summary>True when the template uses the selected notes as its beat marks.</summary>
    bool UsesMarks = false,
    /// <summary>Clickable starting points; empty means "the slot defaults are the only one".</summary>
    IReadOnlyList<SvTemplatePreset>? Presets = null)
{
    public IReadOnlyList<SvTemplatePreset> StartingPoints => Presets ?? [];
}

/// <summary>Everything a template needs to turn slots into timing rows.</summary>
public sealed class SvTemplateContext
{
    public required BeatPosition Start { get; init; }
    public required double LengthBeats { get; init; }
    /// <summary>Rows per beat: 8 means one row every 1/8 beat.</summary>
    public required int StepDenominator { get; init; }
    /// <summary>Net displacement divided by window length. 1 = strictly readable.</summary>
    public required double TargetDisplacement { get; init; }
    public required IReadOnlyDictionary<string, double> Slots { get; init; }
    /// <summary>Text slots, keyed the same way as <see cref="Slots"/>.</summary>
    public IReadOnlyDictionary<string, string> TextSlots { get; init; } =
        new Dictionary<string, string>(StringComparer.Ordinal);
    /// <summary>
    /// Beat marks taken from the current selection, ascending. Templates that declare
    /// <see cref="SvTemplateDefinition.UsesMarks"/> read frame boundaries / accents from
    /// here instead of synthesizing them, so the mapper marks the rhythm and the template
    /// only supplies the mechanics.
    /// </summary>
    public IReadOnlyList<BeatPosition> Marks { get; init; } = [];
    public required Func<BeatPosition, double> BpmAt { get; init; }
    /// <summary>Chart reference BPM, used by the BPM-balance template when base is 0.</summary>
    public double ReferenceBpm { get; init; } = 120;
    public double TailValue { get; init; } = 1;

    public double Slot(string id, double fallback)
    {
        if (!Slots.TryGetValue(id, out var value) || !double.IsFinite(value)) return fallback;
        return value;
    }

    public string TextSlot(string id, string fallback) =>
        TextSlots.TryGetValue(id, out var text) && !string.IsNullOrWhiteSpace(text) ? text : fallback;

    /// <summary>Marks inside the window only, ascending, duplicates collapsed.</summary>
    public IReadOnlyList<BeatPosition> MarksInWindow()
    {
        if (Marks.Count == 0) return Marks;
        var start = Start;
        var end = SvBeatMath.AddBeats(Start, LengthBeats);
        var kept = new List<BeatPosition>(Marks.Count);
        foreach (var mark in Marks.OrderBy(mark => mark.Value))
        {
            if (mark.CompareTo(start) < 0 || mark.CompareTo(end) > 0) continue;
            if (kept.Count > 0 && kept[^1].CompareTo(mark) == 0) continue;
            kept.Add(mark);
        }
        return kept;
    }

    public double StepBeats => 1d / Math.Max(1, StepDenominator);

    public double BpmAtStart
    {
        get
        {
            var bpm = BpmAt(Start);
            return double.IsFinite(bpm) && bpm > 0 ? bpm : 120;
        }
    }
}

public sealed record SvTemplateRow(BeatPosition Beat, TimingEffectKind Kind, double Value, string ValueText);

public sealed record SvTemplateDraft(
    string TemplateId,
    IReadOnlyList<SvTemplateRow> Rows,
    double NetDisplacement,
    double WindowBeats,
    double Peak,
    double Valley,
    int Steps,
    double MillisecondsPerStep,
    IReadOnlyList<string> Warnings)
{
    public int ScrollRowCount => Rows.Count(row => row.Kind == TimingEffectKind.Scroll);
}

/// <summary>
/// A template is a plain class: a fixed <see cref="Definition"/> plus a Build
/// method. Registering it in <see cref="SvTemplateCatalog.All"/> is the only
/// wiring a new formula needs — the dialog renders its form from the slots, so
/// nothing in the UI has to change.
/// </summary>
public abstract class SvTemplate
{
    public abstract SvTemplateDefinition Definition { get; }

    public abstract SvTemplateDraft Build(SvTemplateContext context);

    /// <summary>
    /// Plain-language account of what this build does on screen, for someone who has
    /// never written a scroll effect. Two rules: never use the engine's words
    /// ("net displacement", "peak / valley", "sample step"), and always answer the
    /// question every first-timer actually has — <b>does this shift the rest of the
    /// chart?</b> Lines are shown as a bullet list, so keep each one to a sentence.
    /// </summary>
    public virtual IReadOnlyList<string> Describe(SvTemplateContext context, SvTemplateDraft draft)
    {
        var lines = new List<string>(3);
        if (draft.WindowBeats > 0)
            lines.Add($"这段跨 {Number(draft.WindowBeats)} 拍，画面速度在 {Number(draft.Valley)} ~ " +
                $"{Number(draft.Peak)} 倍之间变化（1 倍 = 正常速度）");
        lines.Add(ShiftText(draft));
        return lines;
    }

    /// <summary>Does the finished effect put the chart back where normal speed would have?</summary>
    protected static string ShiftText(SvTemplateDraft draft)
    {
        var delta = draft.NetDisplacement - draft.WindowBeats;
        if (Math.Abs(delta) < 1e-6)
            return "整段走完，谱面位置和正常速度一模一样 —— 后面的谱不会错位";
        var amount = Number(Math.Abs(delta));
        return delta > 0
            ? $"整段比正常速度多走了 {amount} 拍 —— 后面的谱会整体往前挪，得靠下一段补回来"
            : $"整段比正常速度少走了 {amount} 拍 —— 后面的谱会整体往后拖，得靠下一段补回来";
    }

    /// <summary>Turns a 0..1 share into "1/4" when it is a clean fraction, else a percentage.</summary>
    protected static string ShareText(double share)
    {
        if (!double.IsFinite(share) || share <= 0) return "0";
        var denominator = (int)Math.Round(1 / share);
        if (denominator is >= 2 and <= 16 && Math.Abs(1d / denominator - share) < 0.005)
            return "1/" + denominator.ToString(CultureInfo.InvariantCulture);
        return Number(share * 100) + "%";
    }

    /// <summary>Number for prose: at most three decimals, no trailing zeros.</summary>
    protected static string Number(double value) =>
        double.IsFinite(value) ? value.ToString("0.###", CultureInfo.InvariantCulture) : "?";

    /// <summary>Canonical short text for a numeric effect value.</summary>
    public static string FormatValue(double value)
    {
        if (!double.IsFinite(value)) return "1";
        var rounded = Math.Round(value, 6, MidpointRounding.AwayFromZero);
        if (Math.Abs(rounded) < 1e-9) return "0";
        return rounded.ToString("R", CultureInfo.InvariantCulture);
    }

    protected static SvTemplateRow ScrollRow(BeatPosition beat, double value) =>
        new(beat, TimingEffectKind.Scroll, value, FormatValue(value));

    protected static SvTemplateRow JumpRow(BeatPosition beat, double value) =>
        new(beat, TimingEffectKind.Jump, value, FormatValue(value));

    /// <summary>
    /// Shared composer for v(t) templates: values are equally spaced from
    /// <see cref="SvTemplateContext.Start"/>, and a tail row lands on the window
    /// end so the effect cannot bleed into the next section.
    /// </summary>
    protected SvTemplateDraft Compose(
        SvTemplateContext context,
        IReadOnlyList<double> values,
        IEnumerable<string>? extraWarnings = null)
    {
        var n = values.Count;
        var rows = new List<SvTemplateRow>(n + 1);
        for (var i = 0; i < n; i++)
            rows.Add(ScrollRow(SvBeatMath.Offset(context.Start, i, context.StepDenominator), values[i]));
        rows.Add(ScrollRow(SvBeatMath.Offset(context.Start, n, context.StepDenominator), context.TailValue));

        var window = n * context.StepBeats;
        var net = n == 0 ? 0 : values.Sum() * context.StepBeats;
        var peak = n == 0 ? context.TailValue : values.Max();
        var valley = n == 0 ? context.TailValue : values.Min();
        var milliseconds = 60000d * context.StepBeats / context.BpmAtStart;

        var warnings = new List<string>();
        if (extraWarnings != null) warnings.AddRange(extraWarnings);
        if (milliseconds < 1.05 && context.StepDenominator > 1)
            warnings.Add($"每步只有 {milliseconds:0.##} ms，Malody 按 1 ms 取整，这一步可能看不出");
        if (n > 600) warnings.Add($"将写入 {n + 1} 行，Timing 列表会很长，谱面文件也会变大");
        if (Math.Abs(peak) > 8 || Math.Abs(valley) > 8)
            warnings.Add("峰值或谷值超过 8 倍速，密集段落里读谱压力很大");
        if (n == 0) warnings.Add("这个实例没有生成采样行，只会写一条复位行");

        return new SvTemplateDraft(
            Definition.Id, rows, net, window, peak, valley, n, milliseconds, warnings);
    }

    /// <summary>Composer for templates whose rows are not an equally spaced v(t) sample.</summary>
    protected SvTemplateDraft FromRows(
        SvTemplateContext context,
        IReadOnlyList<SvTemplateRow> rows,
        double netDisplacement,
        double windowBeats,
        int steps,
        double millisecondsPerStep,
        IEnumerable<string>? extraWarnings = null)
    {
        var warnings = new List<string>();
        if (extraWarnings != null) warnings.AddRange(extraWarnings);
        if (rows.Count > 600) warnings.Add($"将写入 {rows.Count} 行，Timing 列表会很长");
        var scrollValues = rows
            .Where(row => row.Kind == TimingEffectKind.Scroll)
            .Select(row => row.Value)
            .ToArray();
        return new SvTemplateDraft(
            Definition.Id,
            rows,
            netDisplacement,
            windowBeats,
            scrollValues.Length == 0 ? 1 : scrollValues.Max(),
            scrollValues.Length == 0 ? 1 : scrollValues.Min(),
            steps,
            millisecondsPerStep,
            warnings);
    }
}

/// <summary>
/// Exact beat arithmetic on the (bar, numerator, denominator) representation, so
/// a 1/200 beat step stays 1/200 instead of being rounded to 1/1920.
/// </summary>
public static class SvBeatMath
{
    public static (long Numerator, long Denominator) ToFraction(BeatPosition beat)
    {
        var denominator = beat.Denominator == 0 ? 1 : beat.Denominator;
        return Reduce((long)beat.Bar * denominator + beat.Numerator, denominator);
    }

    public static BeatPosition FromFraction(long numerator, long denominator)
    {
        var (num, den) = Reduce(numerator, denominator);
        if (den <= 0) return BeatPosition.Zero;
        var bar = num / den;
        var remainder = num - bar * den;
        if (remainder < 0)
        {
            bar -= 1;
            remainder += den;
        }
        if (bar is < int.MinValue or > int.MaxValue) return BeatPosition.Zero;
        if (den <= BeatPosition.MaximumPreservedDenominator)
            return BeatPosition.Preserve((int)bar, (int)remainder, (int)den);
        return BeatPosition.FromDouble(bar + (double)remainder / den);
    }

    /// <summary>start + steps / stepsPerBeat, exactly.</summary>
    public static BeatPosition Offset(BeatPosition start, int steps, int stepsPerBeat)
    {
        if (stepsPerBeat <= 0) return start;
        var (num, den) = ToFraction(start);
        return FromFraction(num * stepsPerBeat + (long)steps * den, den * stepsPerBeat);
    }

    /// <summary>start + beats, where beats is a double rounded to 1/denominator.</summary>
    public static BeatPosition AddBeats(BeatPosition start, double beats, int denominator = 1920)
    {
        denominator = Math.Clamp(denominator, 1, BeatPosition.MaximumPreservedDenominator);
        var scaled = (long)Math.Round(beats * denominator, MidpointRounding.AwayFromZero);
        var (num, den) = ToFraction(start);
        return FromFraction(num * denominator + scaled * den, den * denominator);
    }

    private static (long, long) Reduce(long numerator, long denominator)
    {
        if (denominator < 0)
        {
            numerator = -numerator;
            denominator = -denominator;
        }
        if (denominator == 0) return (numerator, 1);
        var a = Math.Abs(numerator);
        var b = denominator;
        while (b != 0) (a, b) = (b, a % b);
        if (a == 0) return (0, 1);
        return (numerator / a, denominator / a);
    }
}
