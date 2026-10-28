using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;

namespace LumaChart.Avalonia.Controls;

/// <summary>
/// A static picture of what a template does, drawn for someone who has never written
/// a scroll effect: the horizontal axis is the window's own time, the vertical axis is
/// picture speed with <b>1× drawn as a labelled baseline</b>. Anything above the line
/// runs faster than the chart usually does, anything below runs slower, anything sitting
/// on the floor is frozen. Vertical ticks mark the rows that carry no speed of their own
/// (frame swaps, teleports) so those effects are not just an empty strip.
/// </summary>
/// <remarks>
/// Deliberately not animated. The rolling preview is far better at showing feel, but it
/// needs a whole window; this has to read at a glance inside a 300 px inspector column.
/// </remarks>
public sealed class SvSpeedStrip : Control
{
    private static readonly IBrush BackgroundBrush = new SolidColorBrush(Color.Parse("#101315"));
    private static readonly IBrush FastBrush = new SolidColorBrush(Color.Parse("#79B8BD"));
    private static readonly IBrush SlowBrush = new SolidColorBrush(Color.Parse("#3F6C71"));
    private static readonly IBrush FrozenBrush = new SolidColorBrush(Color.Parse("#C98A6B"));
    private static readonly IBrush ReverseBrush = new SolidColorBrush(Color.Parse("#C4697A"));
    private static readonly IBrush NormalBrush = new SolidColorBrush(Color.Parse("#4F6164"));
    private static readonly IBrush MutedBrush = new SolidColorBrush(Color.Parse("#8A979A"));
    private static readonly IBrush TextBrush = new SolidColorBrush(Color.Parse("#C9D4D6"));
    private static readonly IPen BaselinePen =
        new Pen(new SolidColorBrush(Color.Parse("#5E6F72")), 1, new DashStyle([3, 3], 0));
    private static readonly IPen MarkPen = new Pen(new SolidColorBrush(Color.Parse("#7E6A55")), 1);

    private IReadOnlyList<(double Beat, double Value)> points = [];
    private IReadOnlyList<double> marks = [];
    private double windowStart;
    private double windowEnd = 1;
    private string emptyHint = string.Empty;

    public SvSpeedStrip()
    {
        ClipToBounds = true;
        MinHeight = 64;
        Height = 72;
    }

    public void SetContent(
        IReadOnlyList<(double Beat, double Value)> scrollPoints,
        double startBeat,
        double endBeat,
        IReadOnlyList<double> markBeats,
        string hint)
    {
        points = scrollPoints;
        marks = markBeats;
        windowStart = startBeat;
        windowEnd = Math.Max(endBeat, startBeat + 1e-6);
        emptyHint = hint;
        InvalidateVisual();
    }

    public override void Render(DrawingContext context)
    {
        var width = Bounds.Width;
        var height = Bounds.Height;
        if (width < 40 || height < 30) return;

        context.DrawRectangle(BackgroundBrush, null, new Rect(0, 0, width, height));

        const double padLeft = 26;
        const double padRight = 8;
        var plotLeft = padLeft;
        var plotRight = Math.Max(plotLeft + 10, width - padRight);
        var plotWidth = plotRight - plotLeft;
        const double padTop = 12;
        const double padBottom = 12;
        var plotTop = padTop;
        var plotBottom = Math.Max(plotTop + 8, height - padBottom);
        var plotHeight = plotBottom - plotTop;

        if (points.Count == 0)
        {
            DrawText(context, emptyHint, new Point(8, height / 2 - 7), 10.5, MutedBrush);
            return;
        }

        var min = 0d;
        var max = 2d;
        foreach (var point in points)
        {
            if (!double.IsFinite(point.Value)) continue;
            min = Math.Min(min, point.Value);
            max = Math.Max(max, point.Value);
        }
        var range = Math.Max(1e-6, max - min);
        double Y(double value) => plotBottom - (Math.Clamp(value, min, max) - min) / range * plotHeight;
        double X(double beat) =>
            plotLeft + Math.Clamp((beat - windowStart) / (windowEnd - windowStart), 0, 1) * plotWidth;

        var baseline = Y(1);

        // Time markers first, so the bars paint over them and they read as background.
        // Frame-lock writes two rows per frame, which would smear into a solid block —
        // skip ticks closer than a few pixels and let them read as a texture.
        var lastMarkX = double.NegativeInfinity;
        foreach (var mark in marks)
        {
            if (mark < windowStart || mark > windowEnd) continue;
            var x = X(mark);
            if (x - lastMarkX < 4) continue;
            lastMarkX = x;
            context.DrawLine(MarkPen, new Point(x, plotTop), new Point(x, plotBottom));
        }

        // Bars: each scroll row holds until the next one.
        for (var i = 0; i < points.Count; i++)
        {
            var point = points[i];
            var nextBeat = i + 1 < points.Count ? points[i + 1].Beat : windowEnd;
            if (nextBeat <= windowStart || point.Beat >= windowEnd) continue;
            var x1 = X(Math.Max(point.Beat, windowStart));
            var x2 = X(Math.Min(nextBeat, windowEnd));
            if (x2 - x1 < 0.5) x2 = x1 + 0.5;
            var y = Y(point.Value);
            var top = Math.Min(y, baseline);
            var barHeight = Math.Max(1, Math.Abs(y - baseline));
            context.DrawRectangle(BrushFor(point.Value), null, new Rect(x1, top, x2 - x1, barHeight));

            // Label only when there is room; otherwise the shape has to speak for itself.
            if (x2 - x1 >= 34 && !IsNormal(point.Value))
                DrawText(context, FormatMultiplier(point.Value),
                    new Point(x1 + 3, Math.Min(plotBottom - 13, top + 1)), 9.5, TextBrush);
        }

        context.DrawLine(BaselinePen, new Point(plotLeft, baseline), new Point(plotRight, baseline));
        DrawText(context, "1×", new Point(3, baseline - 7), 9.5, MutedBrush);
        DrawText(context, FormatMultiplier(max), new Point(2, plotTop - 2), 9.5, MutedBrush);
        DrawText(context, "0", new Point(6, Y(0) - 7), 9.5, MutedBrush);
    }

    private static bool IsNormal(double value) => Math.Abs(value - 1) < 0.05;

    private static IBrush BrushFor(double value)
    {
        if (value < -1e-9) return ReverseBrush;
        if (value <= 0.01) return FrozenBrush;
        if (value < 0.95) return SlowBrush;
        if (value > 1.05) return FastBrush;
        return NormalBrush;
    }

    private static string FormatMultiplier(double value) =>
        Math.Abs(value) < 0.001
            ? "0×"
            : value.ToString("0.##", CultureInfo.InvariantCulture) + "×";

    private static void DrawText(
        DrawingContext context,
        string text,
        Point origin,
        double size,
        IBrush brush)
    {
        if (string.IsNullOrEmpty(text)) return;
        var formatted = new FormattedText(
            text,
            CultureInfo.InvariantCulture,
            FlowDirection.LeftToRight,
            new Typeface("Segoe UI"),
            size,
            brush);
        context.DrawText(formatted, origin);
    }
}
