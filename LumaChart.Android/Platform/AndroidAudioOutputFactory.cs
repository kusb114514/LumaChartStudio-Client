using Android.Media;
using Android.OS;
using LumaChart.Avalonia.Audio;
using NAudio.Wave;

namespace LumaChart.Android.Platform;

/// <summary>
/// Android sink for the shared audio chain. The decode, rate, pitch and
/// overlay-mixing pipeline is managed code, so the render loop pulls from it on
/// a normal thread and pushes into <see cref="AudioTrack"/> with blocking
/// writes. A native callback engine would have to re-enter managed code on a
/// realtime thread, where a GC pause turns into an audible dropout.
/// </summary>
internal sealed class AndroidAudioOutputFactory : IPlatformAudioOutputFactory
{
    private readonly int nativeSampleRate;
    private readonly int nativeFramesPerBuffer;

    public AndroidAudioOutputFactory(global::Android.Content.Context context)
    {
        ArgumentNullException.ThrowIfNull(context);
        // Feeding the device its own rate and burst size keeps the stream on
        // the fast mixer path; anything else silently engages the system
        // resampler and costs far more latency than the buffer maths saves.
        var manager = context.GetSystemService(
            global::Android.Content.Context.AudioService) as AudioManager;
        nativeSampleRate = ParseProperty(
            manager?.GetProperty(AudioManager.PropertyOutputSampleRate),
            fallback: 48_000,
            minimum: 8_000,
            maximum: 192_000);
        nativeFramesPerBuffer = ParseProperty(
            manager?.GetProperty(AudioManager.PropertyOutputFramesPerBuffer),
            fallback: 256,
            minimum: 32,
            maximum: 4_096);
    }

    public int NativeSampleRate => nativeSampleRate;

    public IWavePlayer CreateOutput(
        IWaveProvider provider,
        PlatformAudioOutputRequest request)
    {
        ArgumentNullException.ThrowIfNull(provider);
        return new AndroidAudioTrackPlayer(
            provider,
            nativeFramesPerBuffer,
            request);
    }

    private static int ParseProperty(string? value, int fallback, int minimum, int maximum) =>
        int.TryParse(value, out var parsed) && parsed >= minimum && parsed <= maximum
            ? parsed
            : fallback;
}

/// <summary>
/// Streams an <see cref="IWaveProvider"/> into an <see cref="AudioTrack"/>.
/// Position and rate stay the shared engine's business; this type only owns the
/// sink and its render thread.
/// </summary>
internal sealed class AndroidAudioTrackPlayer : IWavePlayer
{
    private readonly IWaveProvider provider;
    private readonly AudioTrack track;
    private readonly byte[] renderBuffer;
    private readonly float[] writeBuffer;
    private readonly int bytesPerFrame;
    private readonly ManualResetEventSlim resumeGate = new(false);
    private readonly CancellationTokenSource lifetime = new();
    private readonly Thread renderThread;
    private volatile PlaybackState state = PlaybackState.Stopped;
    private volatile float volume = 1f;
    private int disposed;

    public AndroidAudioTrackPlayer(
        IWaveProvider provider,
        int nativeFramesPerBuffer,
        PlatformAudioOutputRequest request)
    {
        this.provider = provider ?? throw new ArgumentNullException(nameof(provider));
        var format = provider.WaveFormat;
        if (format.Channels is < 1 or > 2)
            throw new NotSupportedException(
                $"Android 输出只支持单声道或立体声，当前为 {format.Channels} 声道。");

        bytesPerFrame = format.Channels * sizeof(float);
        var channelMask = format.Channels == 1
            ? ChannelOut.Mono
            : ChannelOut.Stereo;
        // The shared chain hands out 32-bit float, so the track takes float and
        // no conversion pass is needed between the mixer and the device.
        var encoding = Encoding.PcmFloat;

        var minimumBytes = AudioTrack.GetMinBufferSize(
            format.SampleRate,
            channelMask,
            encoding);
        if (minimumBytes <= 0)
            throw new InvalidOperationException(
                "Android 无法为当前音频格式分配输出缓冲。");

        // The render thread is managed code, so the buffer has to cover a GC
        // pause as well as the device period. A couple of bursts is roughly
        // 9 ms here, which underruns constantly and shows up as a hiss that
        // tracks the signal level. Honour the requested latency but keep a
        // floor of several bursts so the writer stays ahead of the device.
        var burstFrames = Math.Max(nativeFramesPerBuffer, 64);
        var burstBytes = burstFrames * bytesPerFrame;
        var requestedFrames = request.RequestedLatencyMilliseconds * format.SampleRate / 1000d;
        var requestedBursts = (int)Math.Ceiling(requestedFrames / burstFrames);
        var floorBursts = request.PrioritizeLatencyOverStability ? 8 : 16;
        var targetBytes = Math.Max(
            minimumBytes,
            Math.Max(floorBursts, requestedBursts) * burstBytes);

        var attributes = new AudioAttributes.Builder()!
            .SetUsage(AudioUsageKind.Media)!
            .SetContentType(AudioContentType.Music)!
            .Build()!;
        var trackFormat = new AudioFormat.Builder()!
            .SetEncoding(encoding)!
            .SetSampleRate(format.SampleRate)!
            .SetChannelMask(channelMask)!
            .Build()!;
        var builder = new AudioTrack.Builder()
            .SetAudioAttributes(attributes)!
            .SetAudioFormat(trackFormat)!
            .SetTransferMode(AudioTrackMode.Stream)!
            .SetBufferSizeInBytes(targetBytes)!;
        if (Build.VERSION.SdkInt >= BuildVersionCodes.O)
            builder = builder.SetPerformanceMode(AudioTrackPerformanceMode.LowLatency)!;

        track = builder.Build();
        if (track.State != AudioTrackState.Initialized)
        {
            track.Release();
            throw new InvalidOperationException("Android 音频输出初始化失败。");
        }

        // Two bursts per write keeps the JNI crossing rate down without
        // adding latency of its own; the buffer above is what sets latency.
        renderBuffer = new byte[burstBytes * 2];
        writeBuffer = new float[renderBuffer.Length / sizeof(float)];
        track.SetVolume(volume);
        renderThread = new Thread(RenderLoop)
        {
            IsBackground = true,
            Name = "LumaChart.AndroidAudioTrack",
            Priority = System.Threading.ThreadPriority.Highest
        };
        renderThread.Start();
    }

    public event EventHandler<StoppedEventArgs>? PlaybackStopped;

    public PlaybackState PlaybackState => state;

    public float Volume
    {
        get => volume;
        set
        {
            var clamped = Math.Clamp(value, 0f, 1f);
            volume = clamped;
            try { track.SetVolume(clamped); } catch (Exception) { }
        }
    }

    public WaveFormat OutputWaveFormat => provider.WaveFormat;

    public void Init(IWaveProvider waveProvider)
    {
        // The provider is supplied at construction so the render thread never
        // observes a half-configured sink.
        if (!ReferenceEquals(waveProvider, provider))
            throw new InvalidOperationException(
                "Android 输出已绑定到另一个音频源。");
    }

    public void Play()
    {
        if (Volatile.Read(ref disposed) != 0) return;
        state = PlaybackState.Playing;
        try { track.Play(); } catch (Exception) { }
        resumeGate.Set();
    }

    public void Pause()
    {
        if (Volatile.Read(ref disposed) != 0) return;
        state = PlaybackState.Paused;
        resumeGate.Reset();
        try { track.Pause(); } catch (Exception) { }
    }

    public void Stop()
    {
        if (Volatile.Read(ref disposed) != 0) return;
        state = PlaybackState.Stopped;
        resumeGate.Reset();
        try
        {
            track.Pause();
            track.Flush();
        }
        catch (Exception)
        {
        }
        RaiseStopped(null);
    }

    public void Dispose()
    {
        if (Interlocked.Exchange(ref disposed, 1) != 0) return;
        state = PlaybackState.Stopped;
        lifetime.Cancel();
        resumeGate.Set();
        if (!renderThread.Join(TimeSpan.FromSeconds(2)))
        {
            // The render thread only blocks inside AudioTrack.Write, which the
            // stop below releases; never block shutdown waiting on the device.
        }
        try { track.Stop(); } catch (Exception) { }
        try { track.Release(); } catch (Exception) { }
        track.Dispose();
        resumeGate.Dispose();
        lifetime.Dispose();
    }

    private void RenderLoop()
    {
        var token = lifetime.Token;
        try
        {
            while (!token.IsCancellationRequested)
            {
                if (state != PlaybackState.Playing)
                {
                    resumeGate.Wait(token);
                    continue;
                }

                var read = provider.Read(renderBuffer, 0, renderBuffer.Length);
                if (read <= 0)
                {
                    // An IWavePlayer reports end of stream by stopping and
                    // raising PlaybackStopped. The shared key-sound service
                    // waits on that to release and rebuild its standalone
                    // output; writing endless silence instead holds the device
                    // open forever and leaves the service believing a finished
                    // output is still live.
                    state = PlaybackState.Stopped;
                    resumeGate.Reset();
                    try
                    {
                        track.Pause();
                        track.Flush();
                    }
                    catch (Exception)
                    {
                    }
                    RaiseStopped(null);
                    continue;
                }

                if (read < renderBuffer.Length)
                {
                    Array.Clear(renderBuffer, read, renderBuffer.Length - read);
                    read = renderBuffer.Length;
                }

                // AudioTrack's byte[] overload is defined for 8- and 16-bit PCM
                // only. The shared chain emits 32-bit float, which has to go
                // through the float[] overload; the byte[] one leaves the track
                // running and audibly silent.
                var floats = read / sizeof(float);
                Buffer.BlockCopy(renderBuffer, 0, writeBuffer, 0, floats * sizeof(float));


                var offset = 0;
                while (offset < floats && !token.IsCancellationRequested)
                {
                    var written = track.Write(
                        writeBuffer,
                        offset,
                        floats - offset,
                        WriteMode.Blocking);
                    if (written <= 0) break;
                    offset += written;
                }
            }
        }
        catch (System.OperationCanceledException)
        {
        }
        catch (Exception exception)
        {
            // A fault here silently ends playback, so make sure it is visible
            // instead of looking like audio that simply never starts.
            global::Android.Util.Log.Error(
                "LumaChartAudio",
                $"Android audio render loop failed: {exception}");
            state = PlaybackState.Stopped;
            RaiseStopped(exception);
        }
    }

    private void RaiseStopped(Exception? exception) =>
        PlaybackStopped?.Invoke(this, new StoppedEventArgs(exception));
}
