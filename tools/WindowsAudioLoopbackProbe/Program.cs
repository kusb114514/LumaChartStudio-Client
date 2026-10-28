using System.Diagnostics;
using System.Text.Json;
using NAudio.CoreAudioApi;
using NAudio.Dsp;
using NAudio.Vorbis;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;

var options = ProbeOptions.Parse(args);
Directory.CreateDirectory(Path.GetDirectoryName(options.OutputPath)!);
Directory.CreateDirectory(Path.GetDirectoryName(options.WavePath)!);
Directory.CreateDirectory(Path.GetDirectoryName(options.ReadyPath)!);

using var enumerator = new MMDeviceEnumerator();
using var device = enumerator.GetDefaultAudioEndpoint(DataFlow.Render, Role.Multimedia);
IWaveIn capture = options.ProcessId is { } processId
    ? await ProcessLoopbackCapture.CreateAsync(processId)
    : new WasapiLoopbackCapture(device);
using var captureLifetime = (IDisposable)capture;
using var writer = new WaveFileWriter(options.WavePath, capture.WaveFormat);
var stopped = new TaskCompletionSource<Exception?>(TaskCreationOptions.RunContinuationsAsynchronously);
var writeGate = new object();
var capturedBytes = 0L;
var chunks = 0L;
var writtenFrames = 0L;
var writtenBytes = 0L;
var startedUtc = DateTimeOffset.UtcNow;
var stopwatch = Stopwatch.StartNew();
var sampleRate = capture.WaveFormat.SampleRate;
var blockAlign = capture.WaveFormat.BlockAlign;
var requestedFrames = (long)Math.Round(
    options.DurationMilliseconds * (double)sampleRate / 1_000d);
var zeroBuffer = new byte[Math.Max(blockAlign, capture.WaveFormat.AverageBytesPerSecond / 10)];

void WriteSilenceLocked(long frames)
{
    while (frames > 0)
    {
        var chunkFrames = (int)Math.Min(frames, zeroBuffer.Length / blockAlign);
        var bytes = chunkFrames * blockAlign;
        writer.Write(zeroBuffer, 0, bytes);
        writtenFrames += chunkFrames;
        writtenBytes += bytes;
        frames -= chunkFrames;
    }
}

capture.DataAvailable += (_, eventArgs) =>
{
    lock (writeGate)
    {
        var availableDataFrames = eventArgs.BytesRecorded / blockAlign;
        var callbackEndFrame = Math.Min(
            requestedFrames,
            (long)Math.Round(stopwatch.Elapsed.TotalSeconds * sampleRate));
        var dataFrames = (int)Math.Min(
            (long)availableDataFrames,
            Math.Max(0L, callbackEndFrame - writtenFrames));
        var targetStartFrame = Math.Max(writtenFrames, callbackEndFrame - dataFrames);
        WriteSilenceLocked(targetStartFrame - writtenFrames);
        if (dataFrames > 0)
        {
            var bytesToWrite = dataFrames * blockAlign;
            writer.Write(eventArgs.Buffer, 0, bytesToWrite);
            writtenFrames += dataFrames;
            writtenBytes += bytesToWrite;
        }
        capturedBytes += eventArgs.BytesRecorded;
        chunks++;
    }
};
capture.RecordingStopped += (_, eventArgs) => stopped.TrySetResult(eventArgs.Exception);

capture.StartRecording();
var ready = new
{
    schema = "lumachart.windows.audio-loopback-ready.v1",
    startedUtc = startedUtc.ToString("O"),
    processId = Environment.ProcessId,
    captureScope = options.ProcessId is { } ? "process-tree" : "render-device",
    targetProcessId = options.ProcessId,
    deviceId = device.ID,
    deviceName = device.FriendlyName,
    sampleRate = capture.WaveFormat.SampleRate,
    channels = capture.WaveFormat.Channels,
    bitsPerSample = capture.WaveFormat.BitsPerSample,
    encoding = capture.WaveFormat.Encoding.ToString()
};
File.WriteAllText(options.ReadyPath, JsonSerializer.Serialize(ready, ProbeJson.Options));

await Task.Delay(options.DurationMilliseconds);
capture.StopRecording();
var stopException = await stopped.Task.WaitAsync(TimeSpan.FromSeconds(10));
stopwatch.Stop();
if (stopException != null) throw new InvalidOperationException("WASAPI loopback capture failed.", stopException);
lock (writeGate)
{
    WriteSilenceLocked(Math.Max(0, requestedFrames - writtenFrames));
    writer.Flush();
}
writer.Dispose();

var analysis = LoopbackAnalysis.Analyze(
    options.WavePath,
    options.ReferenceAudioPath,
    options.ContinuityReferenceAudioPath,
    options.PlaybackMarkerPath,
    startedUtc);
var output = new
{
    schema = "lumachart.windows.audio-loopback-probe.v1",
    generatedUtc = DateTimeOffset.UtcNow.ToString("O"),
    status = "captured",
    startedUtc = startedUtc.ToString("O"),
    requestedDurationMilliseconds = options.DurationMilliseconds,
    elapsedMilliseconds = stopwatch.Elapsed.TotalMilliseconds,
    device = new
    {
        id = device.ID,
        name = device.FriendlyName,
        state = device.State.ToString()
    },
    captureScope = options.ProcessId is { } ? "process-tree" : "render-device",
    targetProcessId = options.ProcessId,
    format = new
    {
        sampleRate = capture.WaveFormat.SampleRate,
        channels = capture.WaveFormat.Channels,
        bitsPerSample = capture.WaveFormat.BitsPerSample,
        blockAlign = capture.WaveFormat.BlockAlign,
        averageBytesPerSecond = capture.WaveFormat.AverageBytesPerSecond,
        encoding = capture.WaveFormat.Encoding.ToString()
    },
    capture = new
    {
        chunks,
        bytes = capturedBytes,
        writtenFrames,
        writtenBytes,
        timelineIncludesInsertedSilence = true,
        wavePath = options.WavePath,
        waveBytes = new FileInfo(options.WavePath).Length
    },
    analysis
};
File.WriteAllText(options.OutputPath, JsonSerializer.Serialize(output, ProbeJson.Options));

internal sealed record ProbeOptions(
    string OutputPath,
    string WavePath,
    string ReadyPath,
    int DurationMilliseconds,
    string? ReferenceAudioPath,
    string? ContinuityReferenceAudioPath,
    string? PlaybackMarkerPath,
    int? ProcessId)
{
    public static ProbeOptions Parse(string[] arguments)
    {
        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        for (var index = 0; index < arguments.Length; index++)
        {
            var key = arguments[index];
            if (!key.StartsWith("--", StringComparison.Ordinal) || index + 1 >= arguments.Length)
                throw new ArgumentException($"Invalid argument at index {index}: '{key}'.");
            values[key] = arguments[++index];
        }

        static string Required(Dictionary<string, string> source, string key)
        {
            if (!source.TryGetValue(key, out var value) || string.IsNullOrWhiteSpace(value))
                throw new ArgumentException($"Missing required argument {key}.");
            return Path.GetFullPath(value);
        }

        var duration = values.TryGetValue("--duration-ms", out var durationText) &&
                       int.TryParse(durationText, out var parsedDuration)
            ? parsedDuration
            : 3_500;
        if (duration is < 1_000 or > 180_000)
            throw new ArgumentOutOfRangeException(nameof(arguments), "Duration must be 1000..180000 ms.");
        var referenceAudioPath = values.TryGetValue("--reference-audio", out var referenceText) &&
                                 !string.IsNullOrWhiteSpace(referenceText)
            ? Path.GetFullPath(referenceText)
            : null;
        if (referenceAudioPath != null && !File.Exists(referenceAudioPath))
            throw new FileNotFoundException(
                "Configured reference audio file does not exist.",
                referenceAudioPath);
        var continuityReferenceAudioPath =
            values.TryGetValue("--continuity-reference-audio", out var continuityReferenceText) &&
            !string.IsNullOrWhiteSpace(continuityReferenceText)
                ? Path.GetFullPath(continuityReferenceText)
                : null;
        if (continuityReferenceAudioPath != null && !File.Exists(continuityReferenceAudioPath))
            throw new FileNotFoundException(
                "Configured continuity reference audio file does not exist.",
                continuityReferenceAudioPath);
        var playbackMarkerPath =
            values.TryGetValue("--playback-marker", out var playbackMarkerText) &&
            !string.IsNullOrWhiteSpace(playbackMarkerText)
                ? Path.GetFullPath(playbackMarkerText)
                : null;
        if ((continuityReferenceAudioPath == null) != (playbackMarkerPath == null))
            throw new ArgumentException(
                "--continuity-reference-audio and --playback-marker must be supplied together.");
        int? processId = null;
        if (values.TryGetValue("--process-id", out var processIdText))
        {
            if (!int.TryParse(processIdText, out var parsedProcessId) ||
                parsedProcessId <= 0)
                throw new ArgumentException(
                    "--process-id must be a positive Windows process ID.");
            processId = parsedProcessId;
        }
        return new ProbeOptions(
            Required(values, "--output"),
            Required(values, "--wav"),
            Required(values, "--ready"),
            duration,
            referenceAudioPath,
            continuityReferenceAudioPath,
            playbackMarkerPath,
            processId);
    }
}

internal static class ProbeJson
{
    public static JsonSerializerOptions Options { get; } = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };
}

internal static class LoopbackAnalysis
{
    private const int WindowMilliseconds = 10;
    private const int ProductSampleRate = 44_100;
    private const int MaximumProductCustomSoundSeconds = 10;
    private const int ConfiguredReferenceMilliseconds = 750;

    public static object Analyze(
        string wavePath,
        string? configuredReferencePath,
        string? continuityReferencePath,
        string? playbackMarkerPath,
        DateTimeOffset captureStartedUtc)
    {
        using var reader = new AudioFileReader(wavePath);
        var sampleRate = reader.WaveFormat.SampleRate;
        var channels = reader.WaveFormat.Channels;
        var interleaved = new float[Math.Max(8_192, sampleRate * channels / 2)];
        var mono = new List<float>(sampleRate * 5);
        while (true)
        {
            var read = reader.Read(interleaved, 0, interleaved.Length);
            if (read <= 0) break;
            var frames = read / channels;
            for (var frame = 0; frame < frames; frame++)
            {
                var offset = frame * channels;
                var sum = 0d;
                for (var channel = 0; channel < channels; channel++) sum += interleaved[offset + channel];
                mono.Add((float)(sum / channels));
            }
        }

        var configuredReference = string.IsNullOrWhiteSpace(configuredReferencePath)
            ? []
            : Resample(
                LoadProductCustomSoundReference(configuredReferencePath),
                ProductSampleRate,
                sampleRate);
        var configuredReferenceFrameCount = Math.Min(
            configuredReference.Length,
            sampleRate * ConfiguredReferenceMilliseconds / 1_000);
        if (configuredReference.Length != configuredReferenceFrameCount)
            configuredReference = configuredReference[..configuredReferenceFrameCount];

        if (mono.Count == 0)
        {
            return new
            {
                durationMilliseconds = 0d,
                frameCount = 0,
                peak = 0d,
                rms = 0d,
                baselineRmsMedian = 0d,
                baselineRmsP95 = 0d,
                activeRmsThreshold = .0015d,
                detectedPulseCount = 0,
                signalToNoiseDb = (double?)null,
                bestSnareReferenceCorrelation = 0d,
                configuredReferencePath,
                configuredReferenceFrameCount,
                bestConfiguredReferenceCorrelation = 0d,
                bestConfiguredReferenceSpectralSimilarity = 0d,
                continuityReference = (ContinuityReferenceAnalysis?)null,
                strongestPulse = (SignalPulse?)null,
                pulses = Array.Empty<SignalPulse>()
            };
        }
        var windowFrames = Math.Max(1, sampleRate * WindowMilliseconds / 1_000);
        var windows = BuildWindows(mono, windowFrames);
        var baselineWindowCount = Math.Clamp(400 / WindowMilliseconds, 1, windows.Count);
        var baselineValues = windows.Take(baselineWindowCount).Select(item => item.Rms).Order().ToArray();
        var baselineMedian = Percentile(baselineValues, .5);
        var baselineP95 = Percentile(baselineValues, .95);
        var threshold = Math.Max(.0015, Math.Max(baselineMedian * 8, baselineP95 * 4));
        var pulses = DetectPulses(windows, threshold, sampleRate, mono);
        var peak = mono.Max(value => Math.Abs(value));
        var rms = Math.Sqrt(mono.Sum(value => (double)value * value) / mono.Count);
        var strongest = pulses.OrderByDescending(item => item.Rms).FirstOrDefault();
        var reference = Resample(CreateSnareReference(), 44_100, sampleRate);
        var correlation = strongest == null
            ? 0
            : BestCorrelation(mono, reference, strongest.StartFrame, sampleRate);
        var configuredCorrelation = strongest == null || configuredReference.Length == 0
            ? 0
            : BestCorrelation(
                mono,
                configuredReference,
                strongest.StartFrame - sampleRate / 10,
                strongest.StartFrame + sampleRate / 10,
                stride: 16);
        var configuredSpectralSimilarity =
            strongest == null || configuredReference.Length == 0
                ? 0
                : BestSpectralSimilarity(
                    mono,
                    configuredReference,
                    Math.Max(0, strongest.StartFrame - sampleRate / 10),
                    Math.Min(
                        mono.Count,
                        strongest.StartFrame +
                        configuredReference.Length +
                        sampleRate / 10),
                    sampleRate);
        var strongestRms = strongest?.Rms ?? 0;
        var signalToNoiseDb = strongestRms <= 0
            ? (double?)null
            : 20 * Math.Log10(strongestRms / Math.Max(1e-8, baselineMedian));
        var continuityReference =
            string.IsNullOrWhiteSpace(continuityReferencePath) ||
            string.IsNullOrWhiteSpace(playbackMarkerPath)
                ? null
                : AnalyzeContinuityReference(
                    mono,
                    sampleRate,
                    continuityReferencePath,
                    playbackMarkerPath,
                    captureStartedUtc);
        return new
        {
            durationMilliseconds = mono.Count * 1_000d / sampleRate,
            frameCount = mono.Count,
            peak,
            rms,
            baselineRmsMedian = baselineMedian,
            baselineRmsP95 = baselineP95,
            activeRmsThreshold = threshold,
            detectedPulseCount = pulses.Count,
            signalToNoiseDb,
            bestSnareReferenceCorrelation = correlation,
            configuredReferencePath,
            configuredReferenceFrameCount,
            bestConfiguredReferenceCorrelation = configuredCorrelation,
            bestConfiguredReferenceSpectralSimilarity =
                configuredSpectralSimilarity,
            continuityReference,
            strongestPulse = strongest,
            pulses
        };
    }

    private static List<SignalWindow> BuildWindows(IReadOnlyList<float> mono, int windowFrames)
    {
        var result = new List<SignalWindow>((mono.Count + windowFrames - 1) / windowFrames);
        for (var start = 0; start < mono.Count; start += windowFrames)
        {
            var end = Math.Min(mono.Count, start + windowFrames);
            var sum = 0d;
            var peak = 0d;
            for (var index = start; index < end; index++)
            {
                var value = mono[index];
                sum += value * value;
                peak = Math.Max(peak, Math.Abs(value));
            }
            result.Add(new SignalWindow(start, Math.Sqrt(sum / Math.Max(1, end - start)), peak));
        }
        return result;
    }

    private static ContinuityReferenceAnalysis AnalyzeContinuityReference(
        IReadOnlyList<float> capture,
        int sampleRate,
        string referencePath,
        string playbackMarkerPath,
        DateTimeOffset captureStartedUtc)
    {
        var marker = ReadPlaybackMarker(playbackMarkerPath);
        var maximumReferenceFrames = checked((int)Math.Min(
            int.MaxValue,
            Math.Ceiling(
                (marker.SourcePositionMilliseconds +
                 marker.RequestedPlaybackMilliseconds +
                 12_000) *
                sampleRate / 1_000d)));
        var reference = LoadMonoReference(
            referencePath,
            sampleRate,
            maximumReferenceFrames);
        var referenceStartFrame = Math.Clamp(
            (int)Math.Round(marker.SourcePositionMilliseconds * sampleRate / 1_000d),
            0,
            Math.Max(0, reference.Length - 1));
        var markerCaptureFrame = Math.Max(
            0,
            (int)Math.Round(
                (marker.PlaybackStartedUtc - captureStartedUtc).TotalSeconds * sampleRate));
        var (alignedCaptureFrame, alignmentCorrelation) = FindContinuityAlignment(
            capture,
            reference,
            referenceStartFrame,
            markerCaptureFrame,
            sampleRate);
        var requestedFrames = Math.Max(
            1,
            (int)Math.Round(marker.RequestedPlaybackMilliseconds * sampleRate / 1_000d));
        var comparedFrames = Math.Min(
            requestedFrames,
            Math.Min(
                capture.Count - alignedCaptureFrame,
                reference.Length - referenceStartFrame));
        if (comparedFrames <= 0)
            throw new InvalidOperationException(
                "The playback marker falls outside the captured/reference audio interval.");

        var windowFrames = Math.Max(1, sampleRate * WindowMilliseconds / 1_000);
        var windowCount = (comparedFrames + windowFrames - 1) / windowFrames;
        var referenceRms = new double[windowCount];
        var captureRms = new double[windowCount];
        var ratios = new List<double>(Math.Min(windowCount, 2_000));
        for (var window = 0; window < windowCount; window++)
        {
            var relativeStart = window * windowFrames;
            var count = Math.Min(windowFrames, comparedFrames - relativeStart);
            referenceRms[window] = CalculateRms(
                reference,
                referenceStartFrame + relativeStart,
                count);
            captureRms[window] = CalculateRms(
                capture,
                alignedCaptureFrame + relativeStart,
                count);
            if (window < 2_000 &&
                referenceRms[window] >= .006 &&
                captureRms[window] >= .0005)
                ratios.Add(captureRms[window] / referenceRms[window]);
        }

        ratios.Sort();
        var gain = ratios.Count == 0
            ? 1d
            : Percentile(ratios, .5);
        const int minimumGapWindows = 6;
        var gaps = new List<ContinuitySilentGap>();
        var activeComparableWindows = 0;
        var gapStart = -1;
        var maximumGapMilliseconds = 0d;
        for (var window = 0; window <= windowCount; window++)
        {
            var expectedActive = window < windowCount &&
                                 referenceRms[window] >= .006 &&
                                 referenceRms[window] * gain >= .0015;
            var unexpectedlySilent = expectedActive &&
                                     captureRms[window] <
                                     Math.Max(.00045, referenceRms[window] * gain * .10);
            if (expectedActive) activeComparableWindows++;
            if (unexpectedlySilent)
            {
                if (gapStart < 0) gapStart = window;
                continue;
            }
            if (gapStart < 0) continue;
            var gapWindowCount = window - gapStart;
            if (gapWindowCount >= minimumGapWindows)
            {
                var duration = gapWindowCount * WindowMilliseconds;
                maximumGapMilliseconds = Math.Max(maximumGapMilliseconds, duration);
                if (gaps.Count < 64)
                    gaps.Add(new ContinuitySilentGap(
                        gapStart * WindowMilliseconds,
                        duration));
            }
            gapStart = -1;
        }

        var markerOffsetMilliseconds =
            (marker.PlaybackStartedUtc - captureStartedUtc).TotalMilliseconds;
        var alignedStartMilliseconds = alignedCaptureFrame * 1_000d / sampleRate;
        return new ContinuityReferenceAnalysis(
            referencePath,
            playbackMarkerPath,
            marker.PlaybackStartedUtc.ToString("O"),
            marker.SourcePositionMilliseconds,
            marker.RequestedPlaybackMilliseconds,
            markerOffsetMilliseconds,
            alignedStartMilliseconds,
            alignedStartMilliseconds - markerOffsetMilliseconds,
            alignmentCorrelation,
            gain,
            comparedFrames * 1_000d / sampleRate,
            activeComparableWindows,
            gaps.Count,
            maximumGapMilliseconds,
            gaps);
    }

    private static PlaybackMarker ReadPlaybackMarker(string path)
    {
        if (!File.Exists(path))
            throw new FileNotFoundException("Playback marker was not written.", path);
        using var document = JsonDocument.Parse(File.ReadAllText(path));
        var root = document.RootElement;
        var startedText = root.GetProperty("playbackStartedUtc").GetString();
        if (!DateTimeOffset.TryParse(startedText, out var playbackStartedUtc))
            throw new InvalidDataException("Playback marker contains an invalid playbackStartedUtc.");
        var requestedPlaybackMilliseconds =
            root.GetProperty("requestedPlaybackMilliseconds").GetDouble();
        var sourcePositionMilliseconds =
            root.TryGetProperty("sourcePositionMilliseconds", out var sourcePosition)
                ? sourcePosition.GetDouble()
                : 0;
        if (requestedPlaybackMilliseconds <= 0 || sourcePositionMilliseconds < 0)
            throw new InvalidDataException("Playback marker contains an invalid playback interval.");
        return new PlaybackMarker(
            playbackStartedUtc,
            requestedPlaybackMilliseconds,
            sourcePositionMilliseconds);
    }

    private static float[] LoadMonoReference(
        string path,
        int targetSampleRate,
        int maximumFrames)
    {
        using var source = OpenAudio(path);
        var declaredFrames = Math.Max(0, source.Length - source.Position) /
                             Math.Max(1, source.WaveFormat.BlockAlign);
        maximumFrames = (int)Math.Min(maximumFrames, declaredFrames);
        ISampleProvider samples = source.ToSampleProvider();
        if (samples.WaveFormat.SampleRate != targetSampleRate)
            samples = new WdlResamplingSampleProvider(samples, targetSampleRate);
        var channels = samples.WaveFormat.Channels;
        var buffer = new float[Math.Max(8_192, targetSampleRate * channels / 2)];
        var estimatedFrames = (long)Math.Ceiling(
            source.TotalTime.TotalSeconds * targetSampleRate);
        var mono = new List<float>((int)Math.Clamp(estimatedFrames, 0, int.MaxValue));
        while (mono.Count < maximumFrames)
        {
            var remainingFrames = maximumFrames - mono.Count;
            var requestedSamples = Math.Min(buffer.Length, remainingFrames * channels);
            var read = samples.Read(buffer, 0, requestedSamples);
            if (read <= 0) break;
            var frames = read / channels;
            for (var frame = 0; frame < frames; frame++)
            {
                var offset = frame * channels;
                var sum = 0d;
                for (var channel = 0; channel < channels; channel++)
                    sum += buffer[offset + channel];
                mono.Add((float)(sum / channels));
            }
        }
        return mono.ToArray();
    }

    private static (int CaptureFrame, double Correlation) FindContinuityAlignment(
        IReadOnlyList<float> capture,
        IReadOnlyList<float> reference,
        int referenceStartFrame,
        int markerCaptureFrame,
        int sampleRate)
    {
        var minimumCaptureFrame = Math.Max(0, markerCaptureFrame - sampleRate / 20);
        var maximumCaptureFrame = Math.Min(
            capture.Count - 1,
            markerCaptureFrame + sampleRate * 3 / 4);
        var comparisonFrames = Math.Min(
            sampleRate * 8,
            reference.Count - referenceStartFrame);
        comparisonFrames = Math.Min(
            comparisonFrames,
            capture.Count - maximumCaptureFrame);
        if (comparisonFrames < sampleRate)
            throw new InvalidOperationException(
                "Not enough audio remained to align the continuity reference.");

        var candidateStep = Math.Max(1, sampleRate / 500);
        const int comparisonStride = 64;
        var bestFrame = minimumCaptureFrame;
        var bestCorrelation = double.NegativeInfinity;
        for (var candidate = minimumCaptureFrame;
             candidate <= maximumCaptureFrame;
             candidate += candidateStep)
        {
            var dot = 0d;
            var captureEnergy = 0d;
            var referenceEnergy = 0d;
            for (var relative = 0; relative < comparisonFrames; relative += comparisonStride)
            {
                var left = capture[candidate + relative];
                var right = reference[referenceStartFrame + relative];
                dot += left * right;
                captureEnergy += left * left;
                referenceEnergy += right * right;
            }
            if (captureEnergy <= 1e-12 || referenceEnergy <= 1e-12) continue;
            var correlation = Math.Abs(dot / Math.Sqrt(captureEnergy * referenceEnergy));
            if (correlation <= bestCorrelation) continue;
            bestCorrelation = correlation;
            bestFrame = candidate;
        }

        var refinementMinimum = Math.Max(
            minimumCaptureFrame,
            bestFrame - candidateStep);
        var refinementMaximum = Math.Min(
            maximumCaptureFrame,
            bestFrame + candidateStep);
        var refinementStep = Math.Max(1, sampleRate / 4_000);
        var refinementFrames = Math.Min(comparisonFrames, sampleRate * 4);
        for (var candidate = refinementMinimum;
             candidate <= refinementMaximum;
             candidate += refinementStep)
        {
            var dot = 0d;
            var captureEnergy = 0d;
            var referenceEnergy = 0d;
            for (var relative = 0; relative < refinementFrames; relative += 32)
            {
                var left = capture[candidate + relative];
                var right = reference[referenceStartFrame + relative];
                dot += left * right;
                captureEnergy += left * left;
                referenceEnergy += right * right;
            }
            if (captureEnergy <= 1e-12 || referenceEnergy <= 1e-12) continue;
            var correlation = Math.Abs(dot / Math.Sqrt(captureEnergy * referenceEnergy));
            if (correlation <= bestCorrelation) continue;
            bestCorrelation = correlation;
            bestFrame = candidate;
        }
        if (!double.IsFinite(bestCorrelation) || bestCorrelation < .05)
            throw new InvalidOperationException(
                $"Continuity reference alignment failed (correlation={bestCorrelation:F4}).");
        return (bestFrame, bestCorrelation);
    }

    private static double CalculateRms(
        IReadOnlyList<float> samples,
        int start,
        int count)
    {
        var sum = 0d;
        var end = Math.Min(samples.Count, start + count);
        for (var index = start; index < end; index++)
        {
            var value = samples[index];
            sum += value * value;
        }
        return Math.Sqrt(sum / Math.Max(1, end - start));
    }

    private static List<SignalPulse> DetectPulses(
        IReadOnlyList<SignalWindow> windows,
        double threshold,
        int sampleRate,
        IReadOnlyList<float> mono)
    {
        const int maximumInactiveGapWindows = 5;
        var pulses = new List<SignalPulse>();
        var activeStart = -1;
        var lastActive = -1;
        for (var index = 0; index <= windows.Count; index++)
        {
            var active = index < windows.Count && windows[index].Rms >= threshold;
            if (active)
            {
                if (activeStart < 0) activeStart = index;
                lastActive = index;
                continue;
            }
            if (activeStart < 0 || index < windows.Count && index - lastActive <= maximumInactiveGapWindows)
                continue;
            var startFrame = windows[activeStart].StartFrame;
            var endFrame = index < windows.Count
                ? windows[Math.Min(windows.Count - 1, lastActive + 1)].StartFrame
                : mono.Count;
            endFrame = Math.Clamp(endFrame, startFrame + 1, mono.Count);
            var duration = (endFrame - startFrame) * 1_000d / sampleRate;
            var sum = 0d;
            var peak = 0d;
            var peakFrame = startFrame;
            for (var frame = startFrame; frame < endFrame; frame++)
            {
                var value = mono[frame];
                sum += value * value;
                if (Math.Abs(value) <= peak) continue;
                peak = Math.Abs(value);
                peakFrame = frame;
            }
            var pulseRms = Math.Sqrt(sum / (endFrame - startFrame));
            if (duration >= 20 && peak >= .0025)
            {
                pulses.Add(new SignalPulse(
                    startFrame,
                    endFrame,
                    startFrame * 1_000d / sampleRate,
                    duration,
                    peakFrame * 1_000d / sampleRate,
                    pulseRms,
                    peak));
            }
            activeStart = -1;
            lastActive = -1;
        }
        return pulses;
    }

    private static double Percentile(IReadOnlyList<double> sorted, double fraction)
    {
        if (sorted.Count == 0) return 0;
        var position = Math.Clamp(fraction, 0, 1) * (sorted.Count - 1);
        var lower = (int)Math.Floor(position);
        var upper = (int)Math.Ceiling(position);
        if (lower == upper) return sorted[lower];
        var weight = position - lower;
        return sorted[lower] * (1 - weight) + sorted[upper] * weight;
    }

    private static float[] CreateSnareReference()
    {
        const int sampleRate = 44_100;
        var frames = (int)(sampleRate * .19);
        var data = new float[frames];
        var random = new Random(0x4C554D41);
        var previous = 0d;
        for (var frame = 0; frame < frames; frame++)
        {
            var time = frame / (double)sampleRate;
            var envelope = Math.Exp(-time * 25) * Math.Min(1, time * 900);
            var noise = random.NextDouble() * 2 - 1;
            var bright = noise - previous * .66;
            previous = noise;
            var body = Math.Sin(2 * Math.PI * (185 - time * 220) * time) * Math.Exp(-time * 35);
            data[frame] = (float)Math.Clamp((bright * .5 + body * .38) * envelope, -.95, .95);
        }
        return data;
    }

    private static float[] LoadProductCustomSoundReference(string path)
    {
        using var source = OpenAudio(path);
        ISampleProvider samples = source.ToSampleProvider();
        if (samples.WaveFormat.SampleRate != ProductSampleRate)
            samples = new WdlResamplingSampleProvider(samples, ProductSampleRate);
        var channels = samples.WaveFormat.Channels;
        var maximumFrames = ProductSampleRate * MaximumProductCustomSoundSeconds;
        var sourceBuffer = new float[Math.Max(8_192, ProductSampleRate * channels)];
        var stereo = new List<float>(Math.Min(maximumFrames * 2, ProductSampleRate * 4));
        while (stereo.Count < maximumFrames * 2)
        {
            var remainingFrames = maximumFrames - stereo.Count / 2;
            var requested = Math.Min(sourceBuffer.Length, remainingFrames * channels);
            var read = samples.Read(sourceBuffer, 0, requested);
            if (read <= 0) break;
            var frames = read / channels;
            for (var frame = 0; frame < frames; frame++)
            {
                var offset = frame * channels;
                stereo.Add(sourceBuffer[offset]);
                stereo.Add(channels == 1
                    ? sourceBuffer[offset]
                    : sourceBuffer[offset + 1]);
            }
        }

        var trimmed = TrimLeadingSilence(stereo.ToArray());
        var mono = new float[trimmed.Length / 2];
        for (var frame = 0; frame < mono.Length; frame++)
            mono[frame] = (trimmed[frame * 2] + trimmed[frame * 2 + 1]) * .5f;
        return mono;
    }

    private static WaveStream OpenAudio(string path)
    {
        var extension = Path.GetExtension(path);
        return extension.Equals(".ogg", StringComparison.OrdinalIgnoreCase)
            ? new VorbisWaveReader(path)
            : extension.Equals(".mp3", StringComparison.OrdinalIgnoreCase)
                ? new Mp3FileReader(path)
                : new AudioFileReader(path);
    }

    private static float[] TrimLeadingSilence(float[] samples)
    {
        if (samples.Length < 4) return samples;
        var peak = 0f;
        for (var index = 0; index < samples.Length; index++)
            peak = Math.Max(peak, Math.Abs(samples[index]));
        if (peak < .001f) return samples;

        var threshold = Math.Max(.0015f, peak * .015f);
        var maximumScanFrames = Math.Min(
            samples.Length / 2,
            ProductSampleRate / 2);
        var onsetFrame = 0;
        for (; onsetFrame < maximumScanFrames; onsetFrame++)
        {
            var offset = onsetFrame * 2;
            if (Math.Max(
                    Math.Abs(samples[offset]),
                    Math.Abs(samples[offset + 1])) >= threshold)
                break;
        }
        if (onsetFrame >= maximumScanFrames) return samples;
        var startFrame = Math.Max(
            0,
            onsetFrame - (int)(ProductSampleRate * .002));
        return startFrame == 0 ? samples : samples[(startFrame * 2)..];
    }

    private static float[] Resample(IReadOnlyList<float> source, int sourceRate, int targetRate)
    {
        if (sourceRate == targetRate) return source.ToArray();
        var targetLength = (int)Math.Ceiling(
            source.Count * (double)targetRate / sourceRate);
        var target = new float[targetLength];
        for (var index = 0; index < target.Length; index++)
        {
            var sourcePosition = index * (double)sourceRate / targetRate;
            var lower = Math.Min(source.Count - 1, (int)Math.Floor(sourcePosition));
            var upper = Math.Min(source.Count - 1, lower + 1);
            var weight = sourcePosition - lower;
            target[index] = (float)(source[lower] * (1 - weight) + source[upper] * weight);
        }
        return target;
    }

    private static double BestCorrelation(
        IReadOnlyList<float> capture,
        IReadOnlyList<float> reference,
        int detectedStartFrame,
        int sampleRate)
    {
        var searchRadius = sampleRate / 10;
        return BestCorrelation(
            capture,
            reference,
            detectedStartFrame - searchRadius,
            detectedStartFrame + searchRadius,
            stride: 4);
    }

    private static double BestCorrelation(
        IReadOnlyList<float> capture,
        IReadOnlyList<float> reference,
        int minimumStartFrame,
        int maximumStartFrame,
        int stride)
    {
        var minimum = Math.Max(0, minimumStartFrame);
        var maximum = Math.Min(capture.Count - reference.Count, maximumStartFrame);
        if (maximum < minimum || reference.Count < stride * 4) return 0;
        var best = 0d;
        for (var lag = minimum; lag <= maximum; lag += stride)
        {
            var dot = 0d;
            var captureEnergy = 0d;
            var referenceEnergy = 0d;
            for (var index = 0; index < reference.Count; index += stride)
            {
                var left = capture[lag + index];
                var right = reference[index];
                dot += left * right;
                captureEnergy += left * left;
                referenceEnergy += right * right;
            }
            if (captureEnergy <= 1e-12 || referenceEnergy <= 1e-12) continue;
            var correlation = Math.Abs(dot / Math.Sqrt(captureEnergy * referenceEnergy));
            best = Math.Max(best, correlation);
        }
        return best;
    }

    private static double BestSpectralSimilarity(
        IReadOnlyList<float> capture,
        IReadOnlyList<float> reference,
        int captureStartFrame,
        int captureEndFrame,
        int sampleRate)
    {
        const int fftLength = 1_024;
        const int hopLength = fftLength / 2;
        const int bandCount = 24;
        var captureFeatures = BuildSpectralFeatures(
            capture,
            Math.Max(0, captureStartFrame),
            Math.Min(capture.Count, captureEndFrame),
            sampleRate,
            fftLength,
            hopLength,
            bandCount);
        var referenceFeatures = BuildSpectralFeatures(
            reference,
            0,
            reference.Count,
            sampleRate,
            fftLength,
            hopLength,
            bandCount);
        if (referenceFeatures.Count == 0 ||
            captureFeatures.Count < referenceFeatures.Count) {
            return 0;
        }

        var best = 0d;
        for (var start = 0;
             start <= captureFeatures.Count - referenceFeatures.Count;
             start++)
        {
            var sum = 0d;
            for (var frame = 0; frame < referenceFeatures.Count; frame++)
            {
                var captureFeature = captureFeatures[start + frame];
                var referenceFeature = referenceFeatures[frame];
                var dot = 0d;
                for (var band = 0; band < bandCount; band++)
                    dot += captureFeature[band] * referenceFeature[band];
                sum += dot;
            }
            best = Math.Max(best, sum / referenceFeatures.Count);
        }
        return best;
    }

    private static List<float[]> BuildSpectralFeatures(
        IReadOnlyList<float> samples,
        int startFrame,
        int endFrame,
        int sampleRate,
        int fftLength,
        int hopLength,
        int bandCount)
    {
        var result = new List<float[]>();
        var exponent = (int)Math.Log2(fftLength);
        var minimumFrequency = 80d;
        var maximumFrequency = Math.Min(12_000d, sampleRate * .45);
        var bandEdges = new double[bandCount + 1];
        for (var band = 0; band <= bandCount; band++)
        {
            bandEdges[band] = minimumFrequency *
                Math.Pow(
                    maximumFrequency / minimumFrequency,
                    band / (double)bandCount);
        }

        for (var frameStart = startFrame;
             frameStart + fftLength <= endFrame;
             frameStart += hopLength)
        {
            var fft = new Complex[fftLength];
            for (var index = 0; index < fftLength; index++)
            {
                fft[index].X = samples[frameStart + index] *
                    (float)FastFourierTransform.HannWindow(index, fftLength);
            }
            FastFourierTransform.FFT(true, exponent, fft);

            var feature = new float[bandCount];
            var maximumBin = fftLength / 2;
            for (var bin = 1; bin < maximumBin; bin++)
            {
                var frequency = bin * (double)sampleRate / fftLength;
                if (frequency < minimumFrequency ||
                    frequency >= maximumFrequency) {
                    continue;
                }
                var band = Array.BinarySearch(bandEdges, frequency);
                band = band >= 0 ? Math.Min(bandCount - 1, band) : ~band - 1;
                if (band < 0 || band >= bandCount) continue;
                var real = fft[bin].X;
                var imaginary = fft[bin].Y;
                feature[band] += real * real + imaginary * imaginary;
            }

            var energy = 0d;
            for (var band = 0; band < bandCount; band++)
            {
                feature[band] = MathF.Sqrt(feature[band]);
                energy += feature[band] * feature[band];
            }
            var scale = energy <= 1e-18 ? 0d : 1d / Math.Sqrt(energy);
            for (var band = 0; band < bandCount; band++)
                feature[band] = (float)(feature[band] * scale);
            result.Add(feature);
        }
        return result;
    }

    private sealed record SignalWindow(int StartFrame, double Rms, double Peak);

    private sealed record SignalPulse(
        int StartFrame,
        int EndFrame,
        double StartMilliseconds,
        double DurationMilliseconds,
        double PeakMilliseconds,
        double Rms,
        double Peak);

    private sealed record PlaybackMarker(
        DateTimeOffset PlaybackStartedUtc,
        double RequestedPlaybackMilliseconds,
        double SourcePositionMilliseconds);

    private sealed record ContinuitySilentGap(
        double StartMilliseconds,
        double DurationMilliseconds);

    private sealed record ContinuityReferenceAnalysis(
        string ReferencePath,
        string PlaybackMarkerPath,
        string PlaybackStartedUtc,
        double SourcePositionMilliseconds,
        double RequestedPlaybackMilliseconds,
        double MarkerOffsetMilliseconds,
        double AlignedCaptureStartMilliseconds,
        double AlignmentLatencyMilliseconds,
        double AlignmentCorrelation,
        double CaptureToReferenceGain,
        double ComparedDurationMilliseconds,
        int ActiveComparableWindows,
        int UnexpectedSilentGapCount,
        double MaximumUnexpectedSilentGapMilliseconds,
        IReadOnlyList<ContinuitySilentGap> UnexpectedSilentGaps);
}
