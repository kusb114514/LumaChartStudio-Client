using Avalonia.Logging;

namespace LumaChart.iOS.Platform;

/// <summary>
/// Sends Avalonia's own warnings and errors to <see cref="IOSLaunchLog"/>.
///
/// Avalonia logs through <see cref="Logger"/> and installs no sink by default,
/// so anything it reports is discarded. That matters most for the one thing
/// this host cannot otherwise see: <c>DefaultRenderLoop.TimerTick</c> catches
/// every exception a frame throws and logs it as "Exception in render loop".
/// With no sink, a render task that fails on every single tick produces no
/// crash, no device-log entry and no drawing — the app simply sits there with a
/// black screen and an idle GPU. Finding that took several device rounds on
/// 1.2.0.9; the bridge exists so the next one is a file read.
///
/// Warning and above only. Avalonia is chatty at Information, and this writes
/// to a file on the device.
/// </summary>
internal sealed class AvaloniaLogBridge : ILogSink
{
    private const LogEventLevel Threshold = LogEventLevel.Warning;

    private static bool installed;

    public static void Install()
    {
        if (installed) return;
        installed = true;
        Logger.Sink = new AvaloniaLogBridge();
        IOSLaunchLog.Write("avalonia log bridge installed (warning and above)");
    }

    public bool IsEnabled(LogEventLevel level, string area) => level >= Threshold;

    public void Log(LogEventLevel level, string area, object? source, string messageTemplate) =>
        Record(level, area, messageTemplate);

    public void Log(LogEventLevel level, string area, object? source, string messageTemplate,
        params object?[] propertyValues) =>
        Record(level, area, Fill(messageTemplate, propertyValues));

    /// <summary>
    /// Substitutes the values into the template's holes in order. Avalonia's
    /// templates name their holes — "Exception in render loop: {Error}" — and
    /// the value behind such a hole is usually the exception itself, whose
    /// ToString carries the managed stack. Positional substitution is enough to
    /// keep that intact, which is the whole point of the file.
    /// </summary>
    private static string Fill(string template, object?[] values)
    {
        var text = template;
        foreach (var value in values)
        {
            var open = text.IndexOf('{');
            if (open < 0) break;
            var close = text.IndexOf('}', open);
            if (close < 0) break;
            text = text[..open] + (value?.ToString() ?? "null") + text[(close + 1)..];
        }
        return text;
    }

    private static string? lastEntry;

    private static void Record(LogEventLevel level, string area, string message)
    {
        var entry = $"[avalonia {level}/{area}] {message}";

        // A failing render task fails identically every frame, at up to 120 of
        // them a second. Collapsing consecutive repeats keeps the file readable
        // and stops it growing without bound.
        if (entry == lastEntry) return;
        lastEntry = entry;

        IOSLaunchLog.Write(entry);
    }
}
