using System.Collections.Concurrent;
using System.Reflection;
using LumaChart.Avalonia.Audio;
using NAudio.CoreAudioApi;
using NAudio.Wave;

namespace LumaChart.Avalonia.Specs;

// Explicit hardware regression suite. It creates its own quiet pulse WAV and
// measures absolute source/clock alignment, not just the clock's running speed.
internal static class WindowsAudioPauseSpecs
{
    private static readonly FieldInfo AudioClientField = typeof(WasapiOut).GetField(
        "audioClient", BindingFlags.Instance | BindingFlags.NonPublic)!;

    public static async Task<int> RunAsync()
    {
        var root = Path.Combine(Path.GetTempPath(), "LumaChart-Avalonia-Specs",
            $"audio-pause-{Guid.NewGuid():N}");
        Directory.CreateDirectory(root);
        try
        {
            await VerifyDevicePauseAsync();
            foreach (var rate in new[] { .5, 1d, 2d })
                await VerifyAbsoluteAlignmentAsync(root, rate);
            Console.WriteLine("Audio pause contracts: passed (4 checks)");
            return 0;
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine(exception);
            return 1;
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    private static async Task VerifyDevicePauseAsync()
    {
        for (var attempt = 0; attempt < 4; attempt++)
        {
            using var output = new WindowsAudioOutputFactory().CreateOutput(
                new SilentWaveProvider(), new PlatformAudioOutputRequest(40, true));
            if (output is not WasapiOut wasapi)
                throw new InvalidOperationException("This hardware suite requires a WASAPI endpoint.");
            var client = (AudioClient)AudioClientField.GetValue(wasapi)!;
            output.Play();
            if (attempt == 0) await Task.Delay(100);
            output.Pause();
            // Include a cold Play immediately followed by Pause: the render
            // thread must not start the device after the pause already returned.
            client.AudioClockClient.GetPosition(out var before, out _);
            await Task.Delay(80);
            client.AudioClockClient.GetPosition(out var after, out _);
            var advanced = (after - before) * 1000d / client.AudioClockClient.Frequency;
            if (advanced > 5)
                throw new InvalidOperationException($"Paused device advanced {advanced:F2}ms (attempt {attempt}).");
            output.Play();
            await Task.Delay(60);
            client.AudioClockClient.GetPosition(out var resumed, out _);
            if (resumed <= after || output.PlaybackState != PlaybackState.Playing)
                throw new InvalidOperationException("Device failed to resume after physical pause.");
        }
        Console.WriteLine("  ok    wasapi-pause-stops-device-clock-and-resumes-including-cold-start");
    }

    private static async Task VerifyAbsoluteAlignmentAsync(string root, double rate)
    {
        var path = Path.Combine(root, $"pulse-{rate}.wav");
        using (var writer = new WaveFileWriter(path, WaveFormat.CreateIeeeFloatWaveFormat(48000, 2)))
        {
            var samples = new float[48000 * 2 * 20];
            for (var pulse = 1; pulse < 100; pulse++)
                Array.Fill(samples, .005f, pulse * 19200, 32);
            writer.WriteSamples(samples, 0, samples.Length);
        }
        var probe = new PulseOutputFactory(rate);
        PlatformAudioOutputs.Current = probe;
        await using var audio = new WindowsAudioPlaybackService(TimeSpan.Zero);
        probe.Audio = audio;
        await audio.SetPlaybackRateAsync(rate);
        await audio.LoadAsync(path);
        await audio.PlayAsync();
        await Task.Delay(900);
        probe.Phase = "burst";
        for (var attempt = 0; attempt < 16; attempt++)
        {
            await audio.PauseAsync();
            await Task.Delay(attempt % 3 == 0 ? 1 : 45);
            await audio.PlayAsync();
            await Task.Delay(70);
        }
        probe.Phase = "after";
        await Task.Delay(900);
        await audio.PauseAsync();
        var before = probe.Observations.Where(row => row.Phase == "before").ToArray();
        var after = probe.Observations.Where(row => row.Phase == "after").ToArray();
        if (before.Length < 2 || after.Length < 2)
            throw new InvalidOperationException("Not enough PCM pulses were observed.");
        var drift = Math.Abs(after.Average(row => row.Error) - before.Average(row => row.Error)) / rate;
        if (drift > 10)
            throw new InvalidOperationException($"Absolute clock drift after 16 rapid toggles: {drift:F2}ms at {rate}x.");
        Console.WriteLine($"  ok    absolute-pcm-clock-alignment-after-16-toggles rate={rate} drift={drift:F3}ms");
    }

    private sealed class SilentWaveProvider : IWaveProvider
    {
        public WaveFormat WaveFormat { get; } = WaveFormat.CreateIeeeFloatWaveFormat(48000, 2);
        public int Read(byte[] buffer, int offset, int count)
        {
            Array.Clear(buffer, offset, count);
            return count;
        }
    }

    private sealed class PulseOutputFactory(double rate) : IPlatformAudioOutputFactory
    {
        public WindowsAudioPlaybackService? Audio;
        public volatile string Phase = "before";
        public ConcurrentQueue<(string Phase, double Error)> Observations { get; } = new();

        public IWavePlayer CreateOutput(IWaveProvider provider, PlatformAudioOutputRequest request)
        {
            var monitor = new PulseMonitor(provider, this, rate);
            var output = new WindowsAudioOutputFactory().CreateOutput(monitor, request);
            monitor.Output = output as WasapiOut
                ?? throw new InvalidOperationException("PCM alignment suite requires WASAPI.");
            return output;
        }

        private sealed class PulseMonitor(IWaveProvider source, PulseOutputFactory owner, double rate)
            : IWaveProvider
        {
            public WasapiOut? Output;
            private int pulse;
            private bool wasSignal;
            public WaveFormat WaveFormat => source.WaveFormat;
            public int Read(byte[] buffer, int offset, int count)
            {
                var read = source.Read(buffer, offset, count);
                var position = owner.Audio?.Position.TotalMilliseconds ?? 0;
                var client = Output == null ? null : (AudioClient)AudioClientField.GetValue(Output)!;
                var padding = (client?.CurrentPadding ?? 0) * 1000d / WaveFormat.SampleRate;
                for (var index = 0; index < read; index += sizeof(float))
                {
                    var signal = Math.Abs(BitConverter.ToSingle(buffer, offset + index)) > .0001;
                    if (signal && !wasSignal)
                    {
                        var audible = position + rate * (padding + index * 1000d / WaveFormat.AverageBytesPerSecond);
                        owner.Observations.Enqueue((owner.Phase, audible - ++pulse * 200));
                    }
                    wasSignal = signal;
                }
                return read;
            }
        }
    }
}
