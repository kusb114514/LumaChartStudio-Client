using System;
using System.Diagnostics;
using System.Threading;
using Avalonia.Threading;

namespace LumaChart.Avalonia.Infrastructure;

/// <summary>
/// Measures how long the UI thread takes to run a piece of work that was
/// handed to it, by timing a round trip from a background thread.
///
/// This exists because the frame-gap probe cannot see the hitch it was written
/// for: the hitch happens while the playback state flips, and a probe that
/// skips state transitions skips every event around a toggle. A round trip is
/// independent of which clock is running, so a stall is reported no matter what
/// the transport is doing.
///
/// The probe is armed for a short window after each transport toggle and is
/// fully asleep the rest of the time, so it costs nothing during ordinary
/// editing and cannot keep the dispatcher from going idle.
/// </summary>
internal sealed class WindowsUiResponsivenessProbe : IDisposable
{
    /// <summary>
    /// Below this a delay is indistinguishable from a normal frame, so it is
    /// not worth a log line.
    /// </summary>
    private const double ReportThresholdMilliseconds = 25;

    /// <summary>
    /// A one-shot dispatch stamps its own time; if a reply never arrives the
    /// probe must not stop measuring forever.
    /// </summary>
    private const double AbandonedRoundTripMilliseconds = 4000;

    private readonly Action<double> report;
    private readonly object sync = new();
    private long armedUntilTimestamp;
    private long postedTimestamp;
    private int roundTripInFlight;
    private Thread? thread;
    private volatile bool stopped;

    public WindowsUiResponsivenessProbe(Action<double> report)
    {
        this.report = report;
    }

    /// <summary>
    /// Keeps the probe awake for the next <paramref name="seconds"/>.
    /// </summary>
    public void Arm(double seconds)
    {
        var until = Stopwatch.GetTimestamp() + (long)(Math.Max(0, seconds) * Stopwatch.Frequency);
        lock (sync)
        {
            if (until > armedUntilTimestamp) armedUntilTimestamp = until;
            if (thread != null) return;
            thread = new Thread(Run)
            {
                IsBackground = true,
                Name = "LumaChart UI responsiveness probe",
                // Measuring must not compete with what is being measured.
                Priority = ThreadPriority.BelowNormal
            };
            thread.Start();
        }
    }

    public void Dispose()
    {
        stopped = true;
    }

    private void Run()
    {
        while (!stopped)
        {
            long armedUntil;
            lock (sync) armedUntil = armedUntilTimestamp;
            if (Stopwatch.GetTimestamp() > armedUntil)
            {
                Thread.Sleep(25);
                continue;
            }

            if (Volatile.Read(ref roundTripInFlight) != 0)
            {
                if (Stopwatch.GetElapsedTime(Interlocked.Read(ref postedTimestamp))
                        .TotalMilliseconds < AbandonedRoundTripMilliseconds)
                {
                    Thread.Sleep(1);
                    continue;
                }

                // The reply was lost. Drop the round trip instead of blocking.
                Interlocked.Exchange(ref roundTripInFlight, 0);
            }

            if (Interlocked.CompareExchange(ref roundTripInFlight, 1, 0) != 0) continue;
            Interlocked.Exchange(ref postedTimestamp, Stopwatch.GetTimestamp());
            try
            {
                Dispatcher.UIThread.Post(CompleteRoundTrip);
            }
            catch (Exception)
            {
                Interlocked.Exchange(ref roundTripInFlight, 0);
                return;
            }

            // 8 ms is enough to resolve a hitch an order of magnitude larger than
            // the threshold, and keeps the injected load at ~125 jobs/s so the
            // probe cannot itself disturb the pacing it is measuring.
            Thread.Sleep(8);
        }
    }

    private void CompleteRoundTrip()
    {
        var started = Interlocked.Read(ref postedTimestamp);
        Interlocked.Exchange(ref roundTripInFlight, 0);
        var delay = Stopwatch.GetElapsedTime(started).TotalMilliseconds;
        if (delay < ReportThresholdMilliseconds) return;
        try
        {
            report(delay);
        }
        catch (Exception)
        {
            // A diagnostic must never take the editor down with it.
        }
    }
}
