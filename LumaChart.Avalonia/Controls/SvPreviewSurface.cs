using System.Diagnostics;
using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Threading;
using LumaChart.Core.Timing;

namespace LumaChart.Avalonia.Controls;

/// <summary>
/// The template dialog's live preview: a playfield that scrolls with the
/// generated rows in real time. It deliberately does not use the editor's
/// clamped <see cref="ScrollSpeedMap"/> — teleports and reverse sections must
/// keep their true geometry here, which is the whole point of the preview.
/// </summary>
public sealed class SvPreviewSurface : Control
{
    private const double JudgeMargin = 30;
    private const double VisibleBeats = 5;
    private const double LeadInBeats = 1.5;

    private static readonly IBrush BackgroundBrush = new SolidColorBrush(Color.Parse("#0F1214"));
    private static readonly IBrush LaneBrush = new SolidColorBrush(Color.Parse("#161B1E"));
    private static readonly IBrush NoteBrush = new SolidColorBrush(Color.Parse("#C8E6E4"));
    private static readonly IBrush NoteEdgeBrush = new SolidColorBrush(Color.Parse("#7FA4A7"));
    private static readonly IBrush JudgeBrush = new SolidColorBrush(Color.Parse("#D36974"));
    private static readonly IBrush MutedBrush = new SolidColorBrush(Color.Parse("#8A979A"));
    private static readonly IBrush TextBrush = new SolidColorBrush(Color.Parse("#E3E6E8"));
    private static readonly IBrush StripBrush = new SolidColorBrush(Color.Parse("#B9D9D9"));
    private static readonly IBrush StripNegativeBrush = new SolidColorBrush(Color.Parse("#D3917A"));
    private static readonly IBrush FadedOverlayBrush = new SolidColorBrush(Color.FromArgb(78, 15, 18, 20));
    private static readonly IPen LanePen = new Pen(new SolidColorBrush(Color.Parse("#232B2F")), 1);
    private static readonly IPen JudgePen = new Pen(JudgeBrush, 1.5);
    private static readonly IPen BaselinePen =
        new Pen(new SolidColorBrush(Color.Parse("#4F6164")), 1, new DashStyle([3, 3], 0));

    private readonly List<(double Beat, int Lane)> previewNotes = [];
    private SvScrollPositionMap map = new([]);
    private IReadOnlyList<(double Beat, double Value)> points = [];
    private DispatcherTimer? timer;
    private long lastTick;
    private double playhead;
    private double windowStart;
    private double windowEnd = 1;
    private double bpm = 120;
    private int keyCount = 4;
    private bool playing = true;

    public SvPreviewSurface()
    {
        ClipToBounds = true;
        MinHeight = 220;
    }

    public bool IsPlaying => playing;

    public void SetContent(
        double startBeat,
        double endBeat,
        IReadOnlyList<(double Beat, double Value)> scrollPoints,
        double currentBpm,
        int lanes)
    {
        windowStart = startBeat;
        windowEnd = Math.Max(endBeat, startBeat + 1e-6);
        bpm = double.IsFinite(currentBpm) && currentBpm > 0 ? currentBpm : 120;
        keyCount = Math.Clamp(lanes, 1, 10);
        points = scrollPoints;
        map = new SvScrollPositionMap(scrollPoints);

        previewNotes.Clear();
        var first = windowStart - 8;
        var last = windowEnd + 1;
        for (var beat = first; beat <= last; beat += 0.25)
        {
            var index = (int)Math.Round(beat * 4);
            previewNotes.Add((beat, ((index % keyCount) + keyCount) % keyCount));
        }

        if (playhead < windowStart - LeadInBeats || playhead > windowEnd + 1)
            playhead = windowStart - LeadInBeats;
        InvalidateVisual();
    }

    public void SetPlaying(bool value)
    {
        playing = value;
        if (playing)
        {
            lastTick = 0;
            EnsureTimer();
        }
        else
        {
            timer?.Stop();
        }
        InvalidateVisual();
    }

    public void SkipToStart()
    {
        playhead = windowStart - LeadInBeats;
        InvalidateVisual();
    }

    public void StopAnimation() => timer?.Stop();

    private void EnsureTimer()
    {
        if (timer == null)
        {
            timer = new DispatcherTimer(TimeSpan.FromMilliseconds(16), DispatcherPriority.Render, OnTick);
        }
        timer.Start();
    }

    private void OnTick(object? sender, EventArgs e)
    {
        var now = Stopwatch.GetTimestamp();
        if (lastTick == 0)
        {
            lastTick = now;
            return;
        }
        var seconds = (now - lastTick) / (double)Stopwatch.Frequency;
        lastTick = now;
        if (seconds > 0.25) seconds = 0.25;
        playhead += seconds * bpm / 60d;
        if (playhead > windowEnd + 0.75) playhead = windowStart - LeadInBeats;
        InvalidateVisual();
    }

    public override void Render(DrawingContext context)
    {
        var width = Bounds.Width;
        var height = Bounds.Height;
        if (width < 40 || height < 60) return;

        context.DrawRectangle(BackgroundBrush, null, new Rect(0, 0, width, height));

        const double pad = 8;
        var stripHeight = 34d;
        var fieldBottom = height - stripHeight - 4;
        var judgeY = fieldBottom - JudgeMargin;
        var laneWidth = (width - pad * 2) / keyCount;
        var pxPerBeat = Math.Max(6, (judgeY - 14) / VisibleBeats);

        for (var lane = 0; lane < keyCount; lane++)
        {
            var x = pad + lane * laneWidth;
            var rect = new Rect(x + 1, 8, Math.Max(1, laneWidth - 2), Math.Max(1, judgeY - 8));
            context.DrawRectangle(lane % 2 == 0 ? LaneBrush : BackgroundBrush, null, rect);
            context.DrawLine(LanePen, new Point(x, 8), new Point(x, judgeY));
        }
        context.DrawLine(LanePen, new Point(pad + keyCount * laneWidth, 8),
            new Point(pad + keyCount * laneWidth, judgeY));

        var nowPosition = map.PositionAt(playhead);
        var notePen = new Pen(NoteEdgeBrush, 1);
        foreach (var note in previewNotes)
        {
            var delta = map.PositionAt(note.Beat) - nowPosition;
            var y = judgeY - delta * pxPerBeat;
            if (y < -16 || y > height + 16) continue;
            var x = pad + note.Lane * laneWidth + 4;
            var noteWidth = Math.Max(4, laneWidth - 8);
            var noteHeight = 9d;
            context.DrawRectangle(
                NoteBrush,
                notePen,
                new Rect(x, y - noteHeight / 2, noteWidth, noteHeight),
                2,
                2);
            if (y > judgeY)
            {
                context.DrawRectangle(
                    FadedOverlayBrush,
                    null,
                    new Rect(x, y - noteHeight / 2, noteWidth, noteHeight),
                    2,
                    2);
            }
        }

        context.DrawLine(JudgePen, new Point(pad, judgeY), new Point(width - pad, judgeY));

        // current multiplier: bar grows upward for positive, downward for negative
        var value = map.ValueAt(playhead);
        var gaugeX = width - pad - 6;
        var gaugeHeight = Math.Min(judgeY - 16, Math.Abs(Math.Clamp(value, -4, 4)) / 4 * (judgeY - 20));
        var gaugeBrush = value < 0 ? StripNegativeBrush : NoteBrush;
        var gaugeRect = value < 0
            ? new Rect(gaugeX, judgeY, 5, gaugeHeight)
            : new Rect(gaugeX, judgeY - gaugeHeight, 5, gaugeHeight);
        context.DrawRectangle(gaugeBrush, null, gaugeRect);

        DrawText(context, $"拍 {playhead:0.00}   速度 {value:0.###}×", new Point(pad + 4, 10), 11, TextBrush);
        var state = playing ? "播放中" : "已暂停";
        DrawText(context, state, new Point(width - pad - 46, 10), 10, MutedBrush);

        DrawSpeedStrip(context, new Rect(pad, height - stripHeight, width - pad * 2, stripHeight - 6));
    }

    private void DrawSpeedStrip(DrawingContext context, Rect area)
    {
        if (points.Count == 0) return;
        var baseline = area.Top + area.Height * 0.5;
        var max = Math.Max(2, points.Max(point => Math.Abs(point.Value)));
        context.DrawLine(BaselinePen, new Point(area.Left, baseline), new Point(area.Right, baseline));

        var span = Math.Max(1e-6, windowEnd - windowStart);
        for (var i = 0; i < points.Count; i++)
        {
            var point = points[i];
            if (point.Beat < windowStart - 1e-9 || point.Beat > windowEnd + span) continue;
            var nextBeat = i + 1 < points.Count ? points[i + 1].Beat : point.Beat + 0.01;
            var x1 = area.Left + Math.Clamp((point.Beat - windowStart) / span, 0, 1.4) * area.Width;
            var x2 = area.Left + Math.Clamp((nextBeat - windowStart) / span, 0, 1.4) * area.Width;
            var y = baseline - Math.Clamp(point.Value, -max, max) / max * (area.Height * 0.44);
            var brush = point.Value < 0 ? StripNegativeBrush : StripBrush;
            context.DrawRectangle(
                brush,
                null,
                new Rect(Math.Min(x1, x2), Math.Min(y, baseline), Math.Max(0.8, Math.Abs(x2 - x1)),
                    Math.Max(0.8, Math.Abs(baseline - y))));
        }
        var playX = area.Left + Math.Clamp((playhead - windowStart) / span, 0, 1) * area.Width;
        context.DrawLine(JudgePen, new Point(playX, area.Top), new Point(playX, area.Bottom));
    }

    private static void DrawText(
        DrawingContext context,
        string text,
        Point origin,
        double size,
        IBrush brush)
    {
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
