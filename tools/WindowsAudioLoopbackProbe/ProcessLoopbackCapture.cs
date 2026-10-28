using System.Runtime.InteropServices;
using NAudio.CoreAudioApi;
using NAudio.CoreAudioApi.Interfaces;
using NAudio.Wasapi.CoreAudioApi.Interfaces;
using NAudio.Wave;

internal sealed class ProcessLoopbackCapture : IWaveIn, IDisposable
{
    private const string VirtualProcessLoopbackDevice = "VAD\\Process_Loopback";
    private static readonly Guid AudioClientInterfaceId =
        new("1CB9AD4C-DBFA-4C32-B178-C2F568A703B2");

    private readonly AudioClient audioClient;
    private readonly AudioCaptureClient captureClient;
    private readonly EventWaitHandle sampleReady = new(false, EventResetMode.AutoReset);
    private readonly object lifecycleGate = new();
    private Thread? captureThread;
    private bool stopRequested;
    private bool disposed;

    private ProcessLoopbackCapture(AudioClient audioClient)
    {
        this.audioClient = audioClient;
        WaveFormat = new WaveFormat(44_100, 16, 2);
        this.audioClient.Initialize(
            AudioClientShareMode.Shared,
            AudioClientStreamFlags.Loopback |
            AudioClientStreamFlags.EventCallback |
            AudioClientStreamFlags.AutoConvertPcm,
            0,
            0,
            WaveFormat,
            Guid.Empty);
        this.audioClient.SetEventHandle(sampleReady.SafeWaitHandle.DangerousGetHandle());
        captureClient = this.audioClient.AudioCaptureClient;
    }

    public WaveFormat WaveFormat { get; set; }

    public event EventHandler<WaveInEventArgs>? DataAvailable;

    public event EventHandler<StoppedEventArgs>? RecordingStopped;

    public static async Task<ProcessLoopbackCapture> CreateAsync(
        int processId,
        CancellationToken cancellationToken = default)
    {
        if (processId <= 0)
            throw new ArgumentOutOfRangeException(
                nameof(processId),
                "Process loopback capture requires a positive process ID.");

        var activationParams = new AudioClientActivationParams
        {
            ActivationType = AudioClientActivationType.ProcessLoopback,
            ProcessLoopbackParams = new AudioClientProcessLoopbackParams
            {
                TargetProcessId = checked((uint)processId),
                ProcessLoopbackMode = ProcessLoopbackMode.IncludeTargetProcessTree
            }
        };
        var activationBlob = Marshal.AllocHGlobal(
            Marshal.SizeOf<AudioClientActivationParams>());
        var propVariantPointer = IntPtr.Zero;
        try
        {
            Marshal.StructureToPtr(activationParams, activationBlob, false);
            var propVariant = new PropVariant
            {
                vt = (short)VarEnum.VT_BLOB,
                blobVal = new Blob
                {
                    Length = Marshal.SizeOf<AudioClientActivationParams>(),
                    Data = activationBlob
                }
            };
            propVariantPointer = Marshal.AllocHGlobal(Marshal.SizeOf<PropVariant>());
            Marshal.StructureToPtr(propVariant, propVariantPointer, false);

            var completion = new ActivationCompletionHandler();
            ActivateAudioInterfaceAsync(
                VirtualProcessLoopbackDevice,
                AudioClientInterfaceId,
                propVariantPointer,
                completion,
                out var operation);
            var activated = await completion.Task
                .WaitAsync(TimeSpan.FromSeconds(10), cancellationToken)
                .ConfigureAwait(false);
            GC.KeepAlive(operation);
            return new ProcessLoopbackCapture(activated);
        }
        finally
        {
            if (propVariantPointer != IntPtr.Zero)
                Marshal.FreeHGlobal(propVariantPointer);
            Marshal.FreeHGlobal(activationBlob);
        }
    }

    public void StartRecording()
    {
        lock (lifecycleGate)
        {
            ObjectDisposedException.ThrowIf(disposed, this);
            if (captureThread != null)
                throw new InvalidOperationException("Process loopback capture is already running.");
            stopRequested = false;
            captureThread = new Thread(CaptureLoop)
            {
                IsBackground = true,
                Name = "LumaChart process audio loopback"
            };
            captureThread.Start();
        }
    }

    public void StopRecording()
    {
        lock (lifecycleGate)
        {
            if (captureThread == null) return;
            stopRequested = true;
            sampleReady.Set();
        }
    }

    public void Dispose()
    {
        Thread? thread;
        lock (lifecycleGate)
        {
            if (disposed) return;
            disposed = true;
            stopRequested = true;
            thread = captureThread;
            sampleReady.Set();
        }
        if (thread != null && thread != Thread.CurrentThread)
            thread.Join(TimeSpan.FromSeconds(5));
        captureClient.Dispose();
        audioClient.Dispose();
        sampleReady.Dispose();
    }

    private void CaptureLoop()
    {
        Exception? failure = null;
        try
        {
            audioClient.Start();
            while (true)
            {
                sampleReady.WaitOne(250);
                lock (lifecycleGate)
                {
                    if (stopRequested) break;
                }
                DrainPackets();
            }
            DrainPackets();
        }
        catch (Exception exception)
        {
            failure = exception;
        }
        finally
        {
            try
            {
                audioClient.Stop();
            }
            catch (Exception exception) when (failure == null)
            {
                failure = exception;
            }
            lock (lifecycleGate)
            {
                captureThread = null;
            }
            RecordingStopped?.Invoke(this, new StoppedEventArgs(failure));
        }
    }

    private void DrainPackets()
    {
        while (captureClient.GetNextPacketSize() > 0)
        {
            var bufferPointer = captureClient.GetBuffer(
                out var frames,
                out var flags,
                out _,
                out _);
            try
            {
                if (frames <= 0) continue;
                var byteCount = checked(frames * WaveFormat.BlockAlign);
                var buffer = new byte[byteCount];
                if ((flags & AudioClientBufferFlags.Silent) == 0)
                    Marshal.Copy(bufferPointer, buffer, 0, byteCount);
                DataAvailable?.Invoke(this, new WaveInEventArgs(buffer, byteCount));
            }
            finally
            {
                captureClient.ReleaseBuffer(frames);
            }
        }
    }

    [DllImport("Mmdevapi.dll", ExactSpelling = true, PreserveSig = false)]
    private static extern void ActivateAudioInterfaceAsync(
        [In, MarshalAs(UnmanagedType.LPWStr)] string deviceInterfacePath,
        [In, MarshalAs(UnmanagedType.LPStruct)] Guid interfaceId,
        [In] IntPtr activationParams,
        [In] IActivateAudioInterfaceCompletionHandler completionHandler,
        [Out] out IActivateAudioInterfaceAsyncOperation activationOperation);

    [StructLayout(LayoutKind.Sequential)]
    private struct AudioClientActivationParams
    {
        public AudioClientActivationType ActivationType;
        public AudioClientProcessLoopbackParams ProcessLoopbackParams;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct AudioClientProcessLoopbackParams
    {
        public uint TargetProcessId;
        public ProcessLoopbackMode ProcessLoopbackMode;
    }

    private enum AudioClientActivationType
    {
        Default,
        ProcessLoopback
    }

    private enum ProcessLoopbackMode
    {
        IncludeTargetProcessTree,
        ExcludeTargetProcessTree
    }

    [ComVisible(true)]
    private sealed class ActivationCompletionHandler :
        IActivateAudioInterfaceCompletionHandler
    {
        private readonly TaskCompletionSource<AudioClient> completion =
            new(TaskCreationOptions.RunContinuationsAsynchronously);

        public Task<AudioClient> Task => completion.Task;

        public void ActivateCompleted(IActivateAudioInterfaceAsyncOperation operation)
        {
            try
            {
                operation.GetActivateResult(
                    out var activationResult,
                    out var activatedInterface);
                Marshal.ThrowExceptionForHR(activationResult);
                completion.TrySetResult(new AudioClient((IAudioClient)activatedInterface));
            }
            catch (Exception exception)
            {
                completion.TrySetException(exception);
            }
        }
    }
}
