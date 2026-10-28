namespace LumaChart.Core.Effects;

/// <summary>
/// Named easing shapes used by the ramp / wobble templates. Every shape is a
/// plain function of t in [0, 1]; the templates subtract its mean so the target
/// displacement stays exact. Adding a curve means one enum member plus one case
/// here — no template or UI change.
/// </summary>
public static class SvCurveLibrary
{
    public static IReadOnlyList<SvCurveKind> All { get; } =
    [
        SvCurveKind.Linear,
        SvCurveKind.EaseIn,
        SvCurveKind.EaseOut,
        SvCurveKind.EaseInOut,
        SvCurveKind.Sine,
        SvCurveKind.Exponential
    ];

    public static string Label(SvCurveKind kind) => kind switch
    {
        SvCurveKind.Linear => "直线",
        SvCurveKind.EaseIn => "缓入（慢起步）",
        SvCurveKind.EaseOut => "缓出（慢收尾）",
        SvCurveKind.EaseInOut => "S 形（两头缓）",
        SvCurveKind.Sine => "正弦",
        SvCurveKind.Exponential => "指数",
        _ => "直线"
    };

    /// <summary>Shape value for progress t in [0, 1]; not necessarily centered.</summary>
    public static double Raw(SvCurveKind kind, double t)
    {
        t = Math.Clamp(t, 0, 1);
        return kind switch
        {
            SvCurveKind.Linear => t,
            SvCurveKind.EaseIn => t * t,
            SvCurveKind.EaseOut => t * (2 - t),
            SvCurveKind.EaseInOut => t * t * (3 - 2 * t),
            SvCurveKind.Sine => Math.Sin(Math.PI * t),
            SvCurveKind.Exponential => (Math.Exp(2 * t) - 1) / (Math.E * Math.E - 1),
            _ => t
        };
    }

    /// <summary>
    /// Samples a shape into v(t) values whose mean is exactly <paramref name="target"/>,
    /// which is what makes any curve usable in the strictly-readable mode.
    /// </summary>
    public static IReadOnlyList<double> Sample(
        SvCurveKind kind,
        int count,
        double amplitude,
        double target)
    {
        if (count <= 0) return [];
        var raw = new double[count];
        for (var i = 0; i < count; i++)
        {
            var t = count == 1 ? 0 : i / (count - 1d);
            raw[i] = Raw(kind, t);
        }
        var mean = raw.Average();
        var values = new double[count];
        for (var i = 0; i < count; i++) values[i] = target + amplitude * (raw[i] - mean);
        return values;
    }
}
