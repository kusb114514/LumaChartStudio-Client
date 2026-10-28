using AudioToolbox;
using AVFoundation;
using Foundation;
using LumaChart.Avalonia.Audio;
using NAudio.Wave;

namespace LumaChart.iOS.Platform;

/// <summary>
/// iOS sink for the shared audio chain.
///
/// The decode, rate, pitch and overlay-mixing pipeline is managed code that
/// ends in an <see cref="IWaveProvider"/>; only the device end is platform
/// code, exactly as on Android. This uses AudioQueue rather than a RemoteIO
/// audio unit on purpose: a RemoteIO render callback runs on a hard realtime
/// thread, where a GC pause is an audible dropout, while AudioQueue's completion
/// callback is a buffered, non-realtime queue that is designed to be filled from
/// ordinary code.
/// </summary>
internal sealed class IOSAudioOutputFactory : IPlatformAudioOutputFactory
{
    public IOSAudioOutputFactory()
    {
        // Process-wide and done once. Without an explicit Playback category the
        // session defaults to SoloAmbient, which the hardware mute switch
        // silences — the editor would then look like it plays while producing
        // nothing, on a device where the switch is easy to leave on.
        try
        {
            var session = AVAudioSession.SharedInstance();
            var categoryError = session.SetCategory(AVAudioSessionCategory.Playback);
            if (categoryError != null)
                IOSLaunchLog.Write($"audio: SetCategory failed: {categoryError.LocalizedDescription}");

            session.SetActive(true, out var activationError);
            if (activationError != null)
                IOSLaunchLog.Write($"audio: SetActive failed: {activationError.LocalizedDescription}");
        }
        catch (Exception exception)
        {
            // A session that cannot be configured still usually plays; refusing
            // to construct the factory would take playback away entirely.
            IOSLaunchLog.WriteException("audio session configuration", exception);
        }
    }

    public IWavePlayer CreateOutput(
        IWaveProvider provider,
        PlatformAudioOutputRequest request)
    {
        ArgumentNullException.ThrowIfNull(provider);
        try
        {
            return new IOSAudioQueuePlayer(provider, request);
        }
        catch (Exception exception)
        {
            // Never let this fail silently. WindowsAudioDeviceEngine wraps the
            // whole rebuild in a catch that nulls its rate, pitch and mixer
            // providers before rethrowing, so a throw from here does not merely
            // cost one output — it leaves the engine with no chain at all, which
            // presents as "no sound, and the tempo controls do nothing". The
            // rethrow is preserved; this only makes the cause recoverable.
            var format = provider.WaveFormat;
            IOSLaunchLog.WriteException(
                $"audio output creation ({format.Encoding} {format.BitsPerSample}bit " +
                $"{format.SampleRate}Hz x{format.Channels}, " +
                $"{request.RequestedLatencyMilliseconds:0}ms)",
                exception);
            throw;
        }
    }
}

/// <summary>
/// Streams an <see cref="IWaveProvider"/> into an
/// <see cref="OutputAudioQueue"/>. Position and rate stay the shared engine's
/// business; this type only owns the sink.
/// </summary>
internal sealed unsafe class IOSAudioQueuePlayer : IWavePlayer
{
    /// <summary>
    /// Three is the conventional AudioQueue depth: one being played, one ready,
    /// one being filled. Fewer cannot cover a refill; more only adds latency,
    /// because latency here is buffer count times buffer duration.
    /// </summary>
    private const int BufferCount = 3;

    /// <summary>
    /// How many consecutive empty reads are covered with silence before the
    /// source is declared finished. At the buffer sizes below this is on the
    /// order of a tenth of a second — long enough for a time-stretch stage to
    /// prime, short enough that a genuinely finished track does not linger.
    /// </summary>
    private const int MaxEmptyReadsBeforeEndOfStream = 8;

    /// <summary>
    /// Per-output tracing, off unless asked for:
    /// <c>dvt launch --env LUMACHART_IOS_AUDIO_TRACE=1</c>. The key-sound service
    /// builds and tears down an output every time its mixer runs dry, so this is
    /// far too chatty to leave on, but it is the only way to watch the sequence
    /// of creations, starts and stops that produced a silent engine.
    /// </summary>
    private static readonly bool AudioTraceEnabled =
        Environment.GetEnvironmentVariable("LUMACHART_IOS_AUDIO_TRACE") == "1";

    private readonly IWaveProvider provider;
    private readonly OutputAudioQueue queue;
    private readonly IntPtr[] buffers = new IntPtr[BufferCount];
    private readonly byte[] renderBuffer;
    private readonly int bufferByteSize;
    private readonly int bytesPerFrame;
    private readonly object gate = new();
    private volatile PlaybackState state = PlaybackState.Stopped;
    private volatile float volume = 1f;
    private int consecutiveEmptyReads;
    private bool enqueueFailureReported;
    private int disposed;

    // Guarded by gate. See DrainQueueOffThread: playGeneration tells a drain
    // whether the run it was asked to stop is still the current one,
    // drainsInProgress counts drains inside AudioQueueStop/Reset (a Stop can
    // land while an earlier one is still draining), and restartAfterDrain is a
    // Play that arrived while any of them was.
    private int playGeneration;
    private int drainsInProgress;
    private bool restartAfterDrain;

    public IOSAudioQueuePlayer(IWaveProvider provider, PlatformAudioOutputRequest request)
    {
        this.provider = provider ?? throw new ArgumentNullException(nameof(provider));

        var format = provider.WaveFormat;
        if (format.Channels is < 1 or > 2)
            throw new NotSupportedException(
                $"iOS 输出只支持单声道或立体声，当前为 {format.Channels} 声道。");
        if (format.BitsPerSample != 32 || format.Encoding != WaveFormatEncoding.IeeeFloat)
            throw new NotSupportedException(
                "iOS 输出只接受 32 位浮点 PCM，这是共享混音链的输出格式。");

        bytesPerFrame = format.Channels * sizeof(float);

        // Latency is buffer count times buffer duration, so each buffer covers
        // a third of what the caller asked for. The floor is not arbitrary: the
        // refill happens in managed code, so a buffer has to outlast a GC pause,
        // and 512 frames is about 11 ms at 48 kHz.
        var requestedFrames = request.RequestedLatencyMilliseconds * format.SampleRate / 1000d;
        var framesPerBuffer = (int)Math.Round(requestedFrames / BufferCount);
        framesPerBuffer = Math.Clamp(framesPerBuffer, 512, 8192);
        bufferByteSize = framesPerBuffer * bytesPerFrame;
        renderBuffer = new byte[bufferByteSize];

        var description = new AudioStreamBasicDescription
        {
            Format = AudioFormatType.LinearPCM,
            FormatFlags = AudioFormatFlags.IsFloat | AudioFormatFlags.IsPacked,
            SampleRate = format.SampleRate,
            ChannelsPerFrame = format.Channels,
            BitsPerChannel = 32,
            BytesPerFrame = bytesPerFrame,
            FramesPerPacket = 1,
            BytesPerPacket = bytesPerFrame
        };

        // Deliberately no AVAudioSession.SetPreferredIOBufferDuration here.
        //
        // It was advisory, and it cost frames. The session is process-wide, so
        // asking it for a new IO period tears down and restarts the audio unit;
        // the key-sound service disposes and rebuilds its standalone output
        // every time the mixer runs dry, so that reconfiguration ran over and
        // over during editing and dropped an M4 iPad from 120 to 80fps.
        //
        // Nothing is lost: the buffer depth below is what actually sets this
        // sink's latency, and it sits comfortably above whatever period iOS
        // chooses for the route. If a route's default ever proves too coarse,
        // set the preference once in the factory, not per output.
        queue = new OutputAudioQueue(description);
        queue.BufferCompleted += OnBufferCompleted;

        for (var index = 0; index < BufferCount; index++)
        {
            // The IntPtr overload is obsolete; the buffers are kept as IntPtr
            // anyway because that is what BufferCompletedEventArgs hands back.
            var status = queue.AllocateBuffer(bufferByteSize, out AudioQueueBuffer* allocated);
            buffers[index] = (IntPtr)allocated;
            if (status != AudioQueueStatus.Ok)
            {
                DisposeQueue();
                throw new InvalidOperationException(
                    $"iOS 音频输出无法分配缓冲区（AudioQueueStatus={status}）。");
            }
        }

        queue.Volume = volume;
        Trace($"created {format.SampleRate}Hz x{format.Channels}, " +
              $"{BufferCount}x{framesPerBuffer} frames " +
              $"({request.RequestedLatencyMilliseconds:0}ms requested)");
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
            try { queue.Volume = clamped; } catch (Exception) { }
        }
    }

    public WaveFormat OutputWaveFormat => provider.WaveFormat;

    public void Init(IWaveProvider waveProvider)
    {
        // The provider is supplied at construction so the queue never observes a
        // half-configured sink.
        if (!ReferenceEquals(waveProvider, provider))
            throw new InvalidOperationException("iOS 输出已绑定到另一个音频源。");
    }

    /// <summary>
    /// Callers check <see cref="PlaybackState"/> immediately after this returns,
    /// so the state is published before the device is touched.
    /// </summary>
    public void Play()
    {
        if (Volatile.Read(ref disposed) != 0) return;

        var exhausted = false;
        lock (gate)
        {
            if (state == PlaybackState.Playing) return;
            state = PlaybackState.Playing;
            playGeneration++;
            consecutiveEmptyReads = 0;

            // The previous run's drain is inside AudioQueueStop/Reset right now,
            // and starting the queue here would be undone by it a moment later.
            // The drain starts this run itself once the queue has settled.
            if (drainsInProgress > 0)
            {
                restartAfterDrain = true;
                Trace("start deferred until the previous stop has drained");
                return;
            }

            exhausted = !StartPlaybackLocked();
        }

        if (exhausted) RaiseStoppedAsync();
    }

    /// <summary>
    /// Primes every buffer and starts the queue. Called with <see cref="gate"/>
    /// held and <see cref="state"/> already Playing; returns false, with the state
    /// back at Stopped, when the source has nothing to play at all.
    /// </summary>
    private bool StartPlaybackLocked()
    {
        // Every buffer is refilled here rather than only on resume: after a
        // pause the queue still holds its buffers, and AudioQueue silently
        // ignores an enqueue of a buffer it already owns, so priming only
        // reaches the ones that actually came back through the callback.
        foreach (var buffer in buffers)
        {
            if (buffer == IntPtr.Zero) continue;
            if (!TryFillAndEnqueue(buffer, out var endOfStream) && endOfStream)
            {
                // Nothing to play at all. Report it the way an IWavePlayer
                // is expected to and leave the queue stopped.
                state = PlaybackState.Stopped;
                return false;
            }
        }

        // The status is checked because ignoring it is indistinguishable from
        // success: a queue that refuses to start still reports
        // PlaybackState.Playing to the engine and simply produces nothing.
        var status = queue.Start();
        if (status != AudioQueueStatus.Ok)
            IOSLaunchLog.Write($"audio: AudioQueueStart failed ({status})");
        else
            Trace("started");
        return true;
    }

    /// <summary>
    /// Not raised inline. Android's sink raises this from its own render thread,
    /// so it is asynchronous by construction there; matching that keeps a
    /// PlaybackStopped handler — which disposes and rebuilds outputs — from
    /// re-entering the very call that is still setting this one up.
    /// </summary>
    private void RaiseStoppedAsync() =>
        Task.Run(() =>
        {
            if (Volatile.Read(ref disposed) == 0) RaiseStopped(null);
        });

    public void Pause()
    {
        if (Volatile.Read(ref disposed) != 0) return;
        lock (gate)
        {
            if (state != PlaybackState.Playing) return;
            state = PlaybackState.Paused;
            try { queue.Pause(); } catch (Exception) { }
        }
    }

    public void Stop()
    {
        if (Volatile.Read(ref disposed) != 0) return;
        int generation;
        lock (gate)
        {
            if (state == PlaybackState.Stopped) return;
            state = PlaybackState.Stopped;
            generation = playGeneration;
            // Pause is cheap and silences the device straight away; the blocking
            // part of stopping is handed off below. See DrainQueueOffThread.
            try { queue.Pause(); } catch (Exception) { }
        }

        DrainQueueOffThread(dispose: false, generation);
        RaiseStopped(null);
    }

    public void Dispose()
    {
        // The flag is published first so any completion callback already in
        // flight returns before it reaches the lock.
        if (Interlocked.Exchange(ref disposed, 1) != 0) return;
        lock (gate)
        {
            state = PlaybackState.Stopped;
            try { queue.Pause(); } catch (Exception) { }
        }

        DrainQueueOffThread(dispose: true, generation: 0);
    }

    /// <summary>
    /// Finishes tearing the queue down somewhere other than the caller's thread.
    ///
    /// AudioQueueStop(immediate), AudioQueueReset and AudioQueueDispose all block
    /// until the queue's own thread has settled. The engine tears an output down
    /// from the UI thread every time it rebuilds its chain — toggling
    /// 变速不变调 does exactly that — and the key-sound service does it again
    /// whenever its mixer runs dry, so those blocking calls landed on the thread
    /// that draws the editor. The symptom was not a crash but a stall: audio cut
    /// out, input went erratic for a while, then everything recovered.
    ///
    /// Pausing first means the device is already silent before this runs, so
    /// nothing is audible during the hand-off.
    ///
    /// Being deferred, a stop can land after the next Play on the same player —
    /// end of stream followed straight away by a replay, or Stop then Play. It
    /// used to stop and reset the queue regardless, discarding the buffers the
    /// new run had just primed and leaving the engine at PlaybackState.Playing
    /// with a silent device. So a stop drains only while the run it was asked to
    /// end (<paramref name="generation"/>) is still current, and a Play that
    /// arrives while the blocking calls are in progress is started here once
    /// they return. <see cref="gate"/> cannot simply be held across them: they
    /// wait for the queue thread, whose completion callback takes it.
    /// </summary>
    private void DrainQueueOffThread(bool dispose, int generation)
    {
        var doomedQueue = queue;
        var doomedBuffers = dispose ? (IntPtr[])buffers.Clone() : [];
        if (dispose) Array.Clear(buffers);

        Task.Run(() =>
        {
            if (!dispose)
            {
                lock (gate)
                {
                    if (generation != playGeneration || state == PlaybackState.Playing)
                    {
                        Trace("stop skipped: a newer run owns the queue");
                        return;
                    }
                    drainsInProgress++;
                }
            }

            try { doomedQueue.Stop(true); } catch (Exception) { }
            try { doomedQueue.Reset(); } catch (Exception) { }
            if (!dispose)
            {
                var exhausted = false;
                lock (gate)
                {
                    // Only the last drain to finish may start the waiting run;
                    // an earlier one returning would hand it a queue that is
                    // about to be reset again.
                    if (--drainsInProgress == 0)
                    {
                        var restart = restartAfterDrain &&
                                      state == PlaybackState.Playing &&
                                      Volatile.Read(ref disposed) == 0;
                        restartAfterDrain = false;
                        if (restart) exhausted = !StartPlaybackLocked();
                    }
                }

                if (exhausted) RaiseStoppedAsync();
                return;
            }

            try { doomedQueue.BufferCompleted -= OnBufferCompleted; } catch (Exception) { }
            foreach (var buffer in doomedBuffers)
            {
                if (buffer == IntPtr.Zero) continue;
                try { doomedQueue.FreeBuffer(buffer); } catch (Exception) { }
            }

            try { doomedQueue.Dispose(); } catch (Exception) { }
            Trace("disposed");
        });
    }

    /// <summary>
    /// AudioQueue hands each buffer back here once the device has consumed it.
    /// This is a queue thread, not a realtime one, so pulling from the managed
    /// mixing chain is safe.
    /// </summary>
    private void OnBufferCompleted(object? sender, BufferCompletedEventArgs args)
    {
        if (Volatile.Read(ref disposed) != 0) return;

        var reachedEnd = false;
        var generation = 0;
        lock (gate)
        {
            // While a drain is inside Stop/Reset, buffers handed back belong to
            // the run being torn down even if a new Play is already waiting; the
            // drain primes them afresh for that run once the queue has settled.
            if (state != PlaybackState.Playing || drainsInProgress > 0) return;
            if (!TryFillAndEnqueue(args.IntPtrBuffer, out reachedEnd) && reachedEnd)
            {
                // An IWavePlayer reports end of stream by stopping and raising
                // PlaybackStopped. The shared key-sound service waits on that to
                // release and rebuild its standalone output; writing endless
                // silence instead holds the device open forever and leaves the
                // service believing a finished output is still live.
                state = PlaybackState.Stopped;
                generation = playGeneration;
                // Pause only. This runs on the queue's own callback thread, and
                // AudioQueueStop(immediate) waits for that thread to settle —
                // calling it from inside a completion callback is a deadlock
                // waiting to happen. The blocking half goes to the pool below.
                try { queue.Pause(); } catch (Exception) { }
            }
        }

        if (reachedEnd)
        {
            DrainQueueOffThread(dispose: false, generation);
            RaiseStopped(null);
        }
    }

    /// <summary>
    /// Pulls one buffer's worth from the shared chain and hands it to the
    /// device. Returns false when nothing was enqueued; <paramref name="endOfStream"/>
    /// distinguishes a finished source from a transient failure.
    /// </summary>
    private bool TryFillAndEnqueue(IntPtr bufferPointer, out bool endOfStream)
    {
        endOfStream = false;
        try
        {
            var read = provider.Read(renderBuffer, 0, bufferByteSize);
            if (read <= 0)
            {
                // An empty read is not automatically the end. A pitch-preserving
                // chain returns nothing for its first few reads while SoundTouch
                // accumulates enough input to emit a frame, and treating that as
                // end of stream stopped the queue before it ever started: toggling
                // 变速不变调 on and back off left the engine silent with no error
                // anywhere, because the stop was reported while the engine was
                // still inside RecreateOutputAt and had not yet published the new
                // output for its own PlaybackStopped guard to recognise.
                //
                // So a bounded run of empty reads is covered with silence, which
                // keeps buffers cycling and keeps the decision on the queue
                // thread. The bound matters: an unbounded one would hold the
                // device open forever and leave the key-sound service believing a
                // finished output is still live.
                if (++consecutiveEmptyReads > MaxEmptyReadsBeforeEndOfStream)
                {
                    Trace($"end of stream after {consecutiveEmptyReads} empty reads");
                    endOfStream = true;
                    return false;
                }

                Array.Clear(renderBuffer, 0, bufferByteSize);
                read = bufferByteSize;
            }
            else
            {
                consecutiveEmptyReads = 0;
            }

            // A partial read is enqueued as-is rather than padded with silence:
            // the queue accepts a short buffer, and padding would push the
            // reported position past the material that actually exists.
            // Truncate to whole frames, because AudioQueue takes byte counts and
            // a split frame would swap the channels of everything after it.
            read -= read % bytesPerFrame;
            if (read <= 0)
            {
                endOfStream = true;
                return false;
            }

            var buffer = (AudioQueueBuffer*)bufferPointer;
            System.Runtime.InteropServices.Marshal.Copy(
                renderBuffer, 0, buffer->AudioData, read);

            // Packet descriptions are for variable-bitrate formats; linear PCM
            // has none, and the binding's parameter is not nullable.
            var status = queue.EnqueueBuffer(
                bufferPointer, read, Array.Empty<AudioStreamPacketDescription>());
            if (status == AudioQueueStatus.Ok) return true;

            // Reported once per output rather than per buffer: a queue that has
            // started refusing buffers refuses all of them, and one line names
            // the cause without burying the log under a hundred a second.
            if (!enqueueFailureReported)
            {
                enqueueFailureReported = true;
                IOSLaunchLog.Write($"audio: AudioQueueEnqueueBuffer failed ({status})");
            }

            return false;
        }
        catch (Exception exception)
        {
            // A fault here silently ends playback, so make it visible instead of
            // looking like audio that simply never starts.
            IOSLaunchLog.WriteException("iOS audio render", exception);
            return false;
        }
    }

    /// <summary>
    /// Synchronous teardown, used only when construction fails and there is no
    /// queue worth handing to the pool.
    /// </summary>
    private void DisposeQueue()
    {
        try { queue.BufferCompleted -= OnBufferCompleted; } catch (Exception) { }
        for (var index = 0; index < buffers.Length; index++)
        {
            if (buffers[index] == IntPtr.Zero) continue;
            try { queue.FreeBuffer(buffers[index]); } catch (Exception) { }
            buffers[index] = IntPtr.Zero;
        }

        try { queue.Dispose(); } catch (Exception) { }
    }

    private void RaiseStopped(Exception? exception) =>
        PlaybackStopped?.Invoke(this, new StoppedEventArgs(exception));

    private static void Trace(string message)
    {
        if (AudioTraceEnabled) IOSLaunchLog.Write($"audio: {message}");
    }
}
