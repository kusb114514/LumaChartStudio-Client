using System.Reflection;
using System.Runtime.InteropServices;
using System.Diagnostics;
using NAudio.CoreAudioApi;
using NAudio.Wave;

namespace LumaChart.Avalonia.Audio;

/// <summary>
/// What the caller needs from a sink. The music transport favours a stable
/// render at the configured latency; the standalone Key-sound output favours
/// the shortest path to audible feedback and accepts a shallower buffer.
/// </summary>
/// <param name="FallbackLatencyMilliseconds">
/// Latency to ask a fallback sink for when it cannot honour the primary
/// request. A shallow WASAPI request is not safe to repeat verbatim on the
/// older WaveOut path, so the caller states the safer figure instead of the
/// sink guessing one. Null means reuse
/// <paramref name="RequestedLatencyMilliseconds"/>.
/// </param>
public readonly record struct PlatformAudioOutputRequest(
    double RequestedLatencyMilliseconds,
    bool PrioritizeLatencyOverStability,
    double? FallbackLatencyMilliseconds = null);

/// <summary>
/// Platform output boundary for the audio stack. The shared decode, rate,
/// pitch and overlay-mixing chain always ends in an <see cref="IWaveProvider"/>;
/// only the sink that consumes it is platform code. Windows renders through
/// WASAPI, Android through AudioTrack, and neither side needs a second copy of
/// the mixing pipeline.
/// </summary>
public interface IPlatformAudioOutputFactory
{
    /// <summary>
    /// Creates a sink already initialized with <paramref name="provider"/> and
    /// ready for <see cref="IWavePlayer.Play"/>.
    /// </summary>
    IWavePlayer CreateOutput(IWaveProvider provider, PlatformAudioOutputRequest request);
}

public static class PlatformAudioOutputs
{
    private static IPlatformAudioOutputFactory? current;

    /// <summary>
    /// Set once by the host during startup. Windows registers the WASAPI
    /// factory and Android the AudioTrack factory. Leaving it unset is a host
    /// wiring bug rather than something to paper over with a desktop default,
    /// because the desktop sink fails on Android with an opaque winmm error.
    /// </summary>
    public static IPlatformAudioOutputFactory Current
    {
        get => current ?? throw new InvalidOperationException(
            "音频输出平台适配器尚未注册。");
        set => current = value ?? throw new ArgumentNullException(nameof(value));
    }

    /// <summary>
    /// The rate the endpoint's shared-mode mixer runs at. A stream initialised
    /// with any other rate makes WASAPI insert its own sample-rate converter,
    /// whose buffering is invisible to <c>AudioClient.CurrentPadding</c> — the
    /// one number every latency compensation in this editor reads. Callers that
    /// can choose their format should choose this one.
    /// </summary>
    public static int ResolveMixSampleRate(int fallback)
    {
        try
        {
            using var enumerator = new MMDeviceEnumerator();
            using var endpoint = enumerator.GetDefaultAudioEndpoint(DataFlow.Render, Role.Console);
            var rate = endpoint.AudioClient.MixFormat.SampleRate;
            return rate > 0 ? rate : fallback;
        }
        catch
        {
            return fallback;
        }
    }

    public static IWavePlayer CreateOutput(
        IWaveProvider provider,
        PlatformAudioOutputRequest request) =>
        Current.CreateOutput(provider, request);
}

/// <summary>
/// Windows sink. Shared-mode WASAPI is preferred for its low latency and audio
/// clock; WaveOut remains the fallback for sessions where WASAPI cannot open.
/// </summary>
public sealed class WindowsAudioOutputFactory : IPlatformAudioOutputFactory
{
    public IWavePlayer CreateOutput(
        IWaveProvider provider,
        PlatformAudioOutputRequest request)
    {
        ArgumentNullException.ThrowIfNull(provider);
        var latency = (int)Math.Round(request.RequestedLatencyMilliseconds);
        IWavePlayer? wasapi = null;
        MMDevice? endpoint = null;
        try
        {
            // The endpoint is resolved here rather than by the WasapiOut
            // default constructor, which leaves its enumerator and device to
            // the finalizer. Every seek builds a fresh output, so those piled
            // up between collections.
            using (var enumerator = new MMDeviceEnumerator())
                endpoint = enumerator.GetDefaultAudioEndpoint(DataFlow.Render, Role.Console);
            var owned = new EndpointOwningWasapiOut(endpoint, latency);
            endpoint = null;
            wasapi = owned;
            owned.Init(provider);
            return owned;
        }
        catch
        {
            try { wasapi?.Dispose(); } catch { }
            try { endpoint?.Dispose(); } catch { }
            WaveOutEvent? fallback = null;
            try
            {
                fallback = new WaveOutEvent
                {
                    DesiredLatency = (int)Math.Round(
                        request.FallbackLatencyMilliseconds
                        ?? request.RequestedLatencyMilliseconds),
                    NumberOfBuffers = request.PrioritizeLatencyOverStability ? 2 : 3
                };
                fallback.Init(provider);
                return fallback;
            }
            catch
            {
                try { fallback?.Dispose(); } catch { }
                throw;
            }
        }
    }

    /// <summary>
    /// A shared-mode <see cref="WasapiOut"/> that releases what NAudio leaves to
    /// the finalizer: the endpoint it was created for, and the frame event
    /// Init allocates but Dispose never closes. It stays a WasapiOut, so the
    /// engine's audio-clock and padding probes keep working on it. The
    /// release goes through <see cref="IWavePlayer"/>, which is how every
    /// owner of an output disposes it.
    /// </summary>
    private sealed class EndpointOwningWasapiOut : WasapiOut, IWavePlayer, IDisposable
    {
        private static readonly FieldInfo AudioClientField = typeof(WasapiOut).GetField(
            "audioClient",
            BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new MissingFieldException(typeof(WasapiOut).FullName, "audioClient");
        private static readonly FieldInfo? FrameEventField = typeof(WasapiOut).GetField(
            "frameEventWaitHandle",
            BindingFlags.Instance | BindingFlags.NonPublic);
        // MMDevice.Dispose releases only the sub-objects it cached, never the
        // IMMDevice itself. One ReleaseComObject balances the one reference
        // this output's endpoint lookup brought into the runtime.
        private static readonly FieldInfo? EndpointInterfaceField = typeof(MMDevice).GetField(
            "deviceInterface",
            BindingFlags.Instance | BindingFlags.NonPublic);
        private readonly MMDevice endpoint;
        private bool devicePaused;
        private bool initialStartPending;
        private ulong initialClockPosition;
        private int released;

        public EndpointOwningWasapiOut(MMDevice endpoint, int latency)
            : base(endpoint, AudioClientShareMode.Shared, true, latency)
        {
            this.endpoint = endpoint;
        }

        // NAudio 2.2.1 Pause only stops refilling the endpoint. Its audio client
        // keeps running, draining queued music and then advancing through silence.
        // Freezing the editor clock at that point loses chart time on every
        // resume. Stop the client as well, retaining its buffer and device clock.
        void IWavePlayer.Pause()
        {
            if (PlaybackState != PlaybackState.Playing) return;
            var client = (AudioClient)AudioClientField.GetValue(this)!;
            if (initialStartPending)
            {
                // The first base.Play starts a thread which unconditionally
                // calls AudioClient.Start after filling its first buffer. An
                // immediate Pause must wait for that Start; otherwise the old
                // thread can restart the device after our Stop has returned.
                // Transport commands run on the audio worker, not the UI thread.
                var startup = Stopwatch.StartNew();
                while (PlaybackState == PlaybackState.Playing)
                {
                    if (client.AudioClockClient.GetPosition(out var position, out _) &&
                        position > initialClockPosition) break;
                    if (startup.ElapsedMilliseconds >= 500)
                        throw new TimeoutException("WASAPI did not start before the pause deadline.");
                    Thread.Sleep(1);
                }
                initialStartPending = false;
            }
            base.Pause();
            client.Stop();
            devicePaused = true;
        }

        void IWavePlayer.Play()
        {
            if (PlaybackState == PlaybackState.Stopped)
            {
                ((AudioClient)AudioClientField.GetValue(this)!).AudioClockClient.GetPosition(
                    out initialClockPosition, out _);
                initialStartPending = true;
            }
            if (devicePaused && PlaybackState == PlaybackState.Paused)
            {
                ((AudioClient)AudioClientField.GetValue(this)!).Start();
                devicePaused = false;
            }
            base.Play();
        }

        void IWavePlayer.Stop()
        {
            base.Stop();
            devicePaused = false;
            initialStartPending = false;
        }

        void IDisposable.Dispose()
        {
            if (Interlocked.Exchange(ref released, 1) != 0) return;
            try
            {
                // Stops and joins the render thread before the client goes, so
                // nothing waits on the event once it is closed below.
                Dispose();
            }
            finally
            {
                try { (FrameEventField?.GetValue(this) as IDisposable)?.Dispose(); } catch { }
                try { endpoint.Dispose(); } catch { }
                try
                {
                    if (EndpointInterfaceField?.GetValue(endpoint) is { } endpointInterface &&
                        Marshal.IsComObject(endpointInterface))
                        Marshal.ReleaseComObject(endpointInterface);
                }
                catch
                {
                    // A removed endpoint can reject its final release.
                }
            }
        }
    }
}
