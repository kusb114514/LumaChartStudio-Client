using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text.Json;
using System.Threading;
using System.Windows.Automation;
using LumaChart.Core.IO;
using LumaChart.Core.Models;

return await ProgramEntry.RunAsync(args);

internal static class ProgramEntry
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    public static async Task<int> RunAsync(string[] args)
    {
        if (!OperatingSystem.IsWindows())
        {
            Console.Error.WriteLine("WindowsFrameProbe is Windows-only.");
            return 2;
        }

        if (args.Length == 0)
        {
            PrintUsage();
            return 2;
        }

        try
        {
            var command = args[0];
            var options = CommandOptions.Parse(args.Skip(1).ToArray());
            return command switch
            {
                "fixture" => await BuildFixtureAsync(options),
                "display-list" => WriteJson(DisplayModeController.Describe()),
                "display-set" => SetDisplayMode(options),
                "probe" => await RunProbeAsync(options),
                "uia-input-probe" => await RunUiaInputProbeAsync(options),
                _ => throw new ArgumentException($"Unknown command: {command}")
            };
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine(exception);
            return 1;
        }
    }

    private static async Task<int> BuildFixtureAsync(CommandOptions options)
    {
        var sourcePath = Path.GetFullPath(options.Required("source"));
        var destinationPath = Path.GetFullPath(options.Required("destination"));
        var noteCount = options.Int32("note-count", 100_000, 1, 1_000_000);
        if (!File.Exists(sourcePath))
            throw new FileNotFoundException("Source MC fixture is missing.", sourcePath);
        if (File.Exists(destinationPath))
            throw new IOException($"Destination already exists: {destinationPath}");

        var sourceHash = await HashFileAsync(sourcePath);
        var chart = MalodyMcSerializer.Load(sourcePath).Clone();
        chart.Metadata.Title = $"LumaChart Performance {noteCount:N0}";
        chart.Metadata.Version = $"{noteCount:N0} Notes";
        chart.Notes = new List<ChartNote>(noteCount);
        for (var index = 0; index < noteCount; index++)
        {
            var bar = Math.DivRem(index, 16, out var numerator);
            var beat = BeatPosition.Preserve(bar, numerator, 16);
            var isHold = index % 7 == 0;
            chart.Notes.Add(new ChartNote
            {
                Id = DeterministicNoteId(index),
                Lane = index % chart.KeyCount,
                Beat = beat,
                EndBeat = isHold
                    ? BeatPosition.Preserve(bar, numerator + 2, 16)
                    : null,
                Volume = 100,
                Group = 0
            });
        }
        chart.Normalize();

        var destinationDirectory = Path.GetDirectoryName(destinationPath)
            ?? throw new InvalidOperationException("Destination directory is unavailable.");
        Directory.CreateDirectory(destinationDirectory);
        MalodyMcSerializer.Save(chart, destinationPath);

        var copiedAssets = new List<object>();
        foreach (var relativePath in new[]
                 {
                     chart.Metadata.AudioFile,
                     chart.Metadata.CoverFile,
                     chart.Metadata.BackgroundFile
                 }.Where(path => !string.IsNullOrWhiteSpace(path))
                 .Distinct(StringComparer.OrdinalIgnoreCase))
        {
            var normalized = relativePath.Replace('/', Path.DirectorySeparatorChar);
            var sourceAsset = Path.GetFullPath(
                Path.Combine(Path.GetDirectoryName(sourcePath)!, normalized));
            if (!File.Exists(sourceAsset))
                continue;
            var destinationAsset = Path.GetFullPath(
                Path.Combine(destinationDirectory, normalized));
            if (!destinationAsset.StartsWith(
                    destinationDirectory.TrimEnd(Path.DirectorySeparatorChar) +
                    Path.DirectorySeparatorChar,
                    StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException($"Asset path escaped the fixture root: {relativePath}");
            Directory.CreateDirectory(Path.GetDirectoryName(destinationAsset)!);
            File.Copy(sourceAsset, destinationAsset, overwrite: false);
            copiedAssets.Add(new
            {
                path = destinationAsset,
                length = new FileInfo(destinationAsset).Length,
                sha256 = await HashFileAsync(destinationAsset)
            });
        }

        var parsed = MalodyMcSerializer.Load(destinationPath);
        if (parsed.Notes.Count != noteCount)
            throw new InvalidDataException(
                $"Generated fixture round-trip count differs: {parsed.Notes.Count}/{noteCount}");

        return WriteJson(new
        {
            schema = "lumachart.windows.performance-fixture.v1",
            generatedUtc = DateTimeOffset.UtcNow,
            source = new
            {
                path = sourcePath,
                length = new FileInfo(sourcePath).Length,
                sha256 = sourceHash
            },
            destination = new
            {
                path = destinationPath,
                length = new FileInfo(destinationPath).Length,
                sha256 = await HashFileAsync(destinationPath)
            },
            chart = new
            {
                keyCount = parsed.KeyCount,
                noteCount = parsed.Notes.Count,
                longNoteCount = parsed.Notes.Count(note => note.IsHold),
                minimumBeat = parsed.Notes.Min(note => note.Beat).ToString(),
                maximumBeat = parsed.Notes.Max(note => note.EndBeat ?? note.Beat).ToString()
            },
            assets = copiedAssets
        });
    }

    private static int SetDisplayMode(CommandOptions options)
    {
        var width = options.Int32("width", 0, 1, 16_384);
        var height = options.Int32("height", 0, 1, 16_384);
        var refresh = options.Int32("refresh", 0, 1, 1_000);
        var result = DisplayModeController.Set(width, height, refresh);
        return WriteJson(result);
    }

    private static async Task<int> RunProbeAsync(CommandOptions options)
    {
        var dpiAware = Native.SetProcessDpiAwarenessContext(new IntPtr(-4));
        var dpiAwarenessError = dpiAware ? 0 : Marshal.GetLastWin32Error();
        if (!dpiAware && dpiAwarenessError != 5)
            throw new InvalidOperationException(
                $"SetProcessDpiAwarenessContext failed: {dpiAwarenessError}");

        var processId = options.Int32("process-id", 0, 1, int.MaxValue);
        var outputPath = Path.GetFullPath(options.Required("output"));
        var compositionFrames = options.Int32("composition-frames", 600, 120, 5_000);
        var inputTrials = options.Int32("input-trials", 50, 10, 500);
        var windowWidth = options.Int32("window-width", 1_980, 800, 8_192);
        var windowHeight = options.Int32("window-height", 1_200, 600, 8_192);
        if (File.Exists(outputPath))
            throw new IOException($"Probe output already exists: {outputPath}");

        using var process = Process.GetProcessById(processId);
        var window = await WaitForMainWindowAsync(process, TimeSpan.FromSeconds(30));
        var display = DisplayModeController.Current();
        using var capture = new VisiblePixelCapture(window, windowWidth, windowHeight);
        capture.Activate();

        var processStart = SnapshotProcess(process);
        var dwmFlushBaseline = VisiblePixelCapture.MeasureDwmFlushBaseline(240);
        capture.FocusTimeline();
        capture.PreRollForward(32);
        capture.WarmUp(24);

        var cadence = capture.MeasureInputDrivenCadence(compositionFrames);
        capture.WarmUp(8);
        var input = capture.MeasureInputToVisible(inputTrials);
        process.Refresh();
        var processEnd = SnapshotProcess(process);

        var result = new
        {
            schema = "lumachart.windows.visible-frame-probe.v1",
            generatedUtc = DateTimeOffset.UtcNow,
            status = cadence.VisibleChangeIntervals.Samples >= compositionFrames / 3 &&
                     input.CompletedTrials >= inputTrials * 9 / 10
                ? "passed"
                : "insufficient-visible-updates",
            semantics = new
            {
                synchronization = "DwmFlush composition boundary followed by visible desktop BitBlt sampling",
                frameInterval = "interval between successive target-window visible-pixel changes under one Win32 wheel input per composition boundary",
                inputLatency = "Stopwatch timestamp immediately before Win32 SendInput wheel event to first changed visible-pixel sample after DwmFlush",
                presentMon = false,
                gpuPresentAttribution = false,
                hardwareInputClaimed = false,
                win32SendInputUsed = true
            },
            target = new
            {
                processId,
                processName = process.ProcessName,
                executable = TryGetProcessPath(process),
                windowHandle = window.ToInt64(),
                capture.Window,
                capture.Region
            },
            display,
            dwmFlushBaseline,
            cadence,
            input,
            process = new
            {
                before = processStart,
                after = processEnd,
                cpuDeltaMilliseconds =
                    (processEnd.TotalProcessorTime - processStart.TotalProcessorTime).TotalMilliseconds,
                workingSetDeltaBytes = processEnd.WorkingSetBytes - processStart.WorkingSetBytes,
                privateBytesDelta = processEnd.PrivateBytes - processStart.PrivateBytes
            }
        };

        Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
        var temporary = outputPath + ".tmp-" + Guid.NewGuid().ToString("N");
        await File.WriteAllTextAsync(temporary, JsonSerializer.Serialize(result, JsonOptions));
        File.Move(temporary, outputPath);
        Console.WriteLine(JsonSerializer.Serialize(new
        {
            output = outputPath,
            status = result.status,
            visibleInterval = cadence.VisibleChangeIntervals,
            inputLatency = input.LatencyMilliseconds
        }, JsonOptions));
        return result.status == "passed" ? 0 : 3;
    }

    private static async Task<int> RunUiaInputProbeAsync(CommandOptions options)
    {
        var dpiAware = Native.SetProcessDpiAwarenessContext(new IntPtr(-4));
        var dpiAwarenessError = dpiAware ? 0 : Marshal.GetLastWin32Error();
        if (!dpiAware && dpiAwarenessError != 5)
            throw new InvalidOperationException(
                $"SetProcessDpiAwarenessContext failed: {dpiAwarenessError}");

        var processId = options.Int32("process-id", 0, 1, int.MaxValue);
        var outputPath = Path.GetFullPath(options.Required("output"));
        var inputTrials = options.Int32("input-trials", 50, 10, 500);
        if (File.Exists(outputPath))
            throw new IOException($"Probe output already exists: {outputPath}");

        using var process = Process.GetProcessById(processId);
        var window = await WaitForMainWindowAsync(process, TimeSpan.FromSeconds(30));
        using var capture = new VisiblePixelCapture(window, 1_980, 1_200);
        capture.Activate();
        var root = AutomationElement.FromHandle(window);
        var timeline = root.FindFirst(
            TreeScope.Descendants,
            new PropertyCondition(
                AutomationElement.AutomationIdProperty,
                "Timeline.Surface"))
            ?? throw new InvalidOperationException(
                "Avalonia timeline UI Automation element was not found.");
        var timelineBounds = timeline.Current.BoundingRectangle;
        if (timelineBounds.IsEmpty ||
            timelineBounds.Width < 100 ||
            timelineBounds.Height < 100)
            throw new InvalidOperationException(
                $"Avalonia timeline UI Automation bounds are invalid: {timelineBounds}.");
        capture.FocusPoint(
            checked((int)Math.Round(timelineBounds.Left + timelineBounds.Width * 0.5)),
            checked((int)Math.Round(timelineBounds.Top + timelineBounds.Height * 0.6)));
        capture.PreRollForward(8);
        Thread.Sleep(200);
        var initialState = ReadTimelineAutomationState(timeline);

        var trials = new List<object>(inputTrials);
        var latencies = new List<double>(inputTrials);
        var timeouts = 0;
        for (var trial = 0; trial < inputTrials; trial++)
        {
            var before = ReadTimelineAutomationState(timeline);
            var sentAt = Stopwatch.GetTimestamp();
            capture.SendWheelStep(trial % 2 == 0 ? -120 : 120);
            var deadline = Stopwatch.StartNew();
            TimelineAutomationState? after = null;
            while (deadline.Elapsed < TimeSpan.FromMilliseconds(500))
            {
                var candidate = ReadTimelineAutomationState(timeline);
                if (Math.Abs(candidate.CurrentBeat - before.CurrentBeat) > 1e-9 &&
                    candidate.InputToRenderSamples > before.InputToRenderSamples)
                {
                    after = candidate;
                    break;
                }
                Thread.SpinWait(128);
            }

            if (after == null)
            {
                timeouts++;
                trials.Add(new
                {
                    trial,
                    status = "timeout",
                    beforeBeat = before.CurrentBeat,
                    beforeInputSamples = before.InputToRenderSamples
                });
                continue;
            }

            var latency = Stopwatch.GetElapsedTime(sentAt).TotalMilliseconds;
            latencies.Add(latency);
            trials.Add(new
            {
                trial,
                status = "observed",
                beforeBeat = before.CurrentBeat,
                afterBeat = after.CurrentBeat,
                beforeInputSamples = before.InputToRenderSamples,
                afterInputSamples = after.InputToRenderSamples,
                latencyMilliseconds = latency,
                applicationInputToRender = new
                {
                    after.InputToRenderP50,
                    after.InputToRenderP95,
                    after.InputToRenderP99
                }
            });
        }

        process.Refresh();
        var result = new
        {
            schema = "lumachart.windows.uia-input-to-render-probe.v1",
            generatedUtc = DateTimeOffset.UtcNow,
            status = latencies.Count >= inputTrials * 9 / 10
                ? "passed"
                : "insufficient-input-renders",
            semantics = new
            {
                latency =
                    "external QPC timestamp immediately before Win32 SendInput to first UIA observation of both changed CurrentBeat and a new TimelineSurface input-to-render sample",
                includes =
                    "Win32 input queue, Avalonia input dispatch, TimelineSurface render entry, and UIA polling",
                excludes = "physical device and display scan-out",
                presentMon = false,
                gpuPresentAttribution = false,
                hardwareInputClaimed = false,
                win32SendInputUsed = true
            },
            target = new
            {
                processId,
                processName = process.ProcessName,
                executable = TryGetProcessPath(process),
                windowHandle = window.ToInt64(),
                windowBounds = capture.Window,
                timelineBounds = new RectangleEvidence(
                    checked((int)Math.Round(timelineBounds.Left)),
                    checked((int)Math.Round(timelineBounds.Top)),
                    checked((int)Math.Round(timelineBounds.Width)),
                    checked((int)Math.Round(timelineBounds.Height))),
                initialState
            },
            display = DisplayModeController.Current(),
            input = new
            {
                requestedTrials = inputTrials,
                completedTrials = latencies.Count,
                timeoutTrials = timeouts,
                latencyMilliseconds = Distribution.From(latencies),
                trials
            }
        };
        Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
        var temporary = outputPath + ".tmp-" + Guid.NewGuid().ToString("N");
        await File.WriteAllTextAsync(
            temporary,
            JsonSerializer.Serialize(result, JsonOptions));
        File.Move(temporary, outputPath);
        Console.WriteLine(JsonSerializer.Serialize(new
        {
            output = outputPath,
            status = result.status,
            latency = result.input.latencyMilliseconds
        }, JsonOptions));
        return result.status == "passed" ? 0 : 3;
    }

    private static TimelineAutomationState ReadTimelineAutomationState(
        AutomationElement timeline)
    {
        var helpText = timeline.Current.HelpText;
        return new TimelineAutomationState(
            DoubleField(helpText, "CurrentBeat"),
            Int32Field(helpText, "InputToRenderSamples"),
            DoubleField(helpText, "InputToRenderMsP50"),
            DoubleField(helpText, "InputToRenderMsP95"),
            DoubleField(helpText, "InputToRenderMsP99"));
    }

    private static string Field(string text, string name)
    {
        var marker = name + "=";
        var start = text.IndexOf(marker, StringComparison.Ordinal);
        if (start < 0)
            throw new InvalidDataException($"Timeline UIA field is missing: {name}");
        start += marker.Length;
        var end = text.IndexOf(';', start);
        return (end < 0 ? text[start..] : text[start..end]).Trim();
    }

    private static int Int32Field(string text, string name) =>
        int.Parse(Field(text, name), NumberStyles.Integer, CultureInfo.InvariantCulture);

    private static double DoubleField(string text, string name) =>
        double.Parse(Field(text, name), NumberStyles.Float, CultureInfo.InvariantCulture);

    private static async Task<IntPtr> WaitForMainWindowAsync(
        Process process,
        TimeSpan timeout)
    {
        var deadline = Stopwatch.StartNew();
        while (deadline.Elapsed < timeout)
        {
            process.Refresh();
            if (process.HasExited)
                throw new InvalidOperationException(
                    $"Target process exited before probing: {process.ExitCode}");
            if (process.MainWindowHandle != IntPtr.Zero)
                return process.MainWindowHandle;
            await Task.Delay(100);
        }
        throw new TimeoutException("Target process did not expose a main window.");
    }

    private static ProcessSnapshot SnapshotProcess(Process process)
    {
        process.Refresh();
        return new ProcessSnapshot(
            process.TotalProcessorTime,
            process.WorkingSet64,
            process.PrivateMemorySize64,
            process.Threads.Count,
            DateTimeOffset.UtcNow);
    }

    private static string? TryGetProcessPath(Process process)
    {
        try
        {
            return process.MainModule?.FileName;
        }
        catch
        {
            return null;
        }
    }

    private static Guid DeterministicNoteId(int index)
    {
        Span<byte> bytes = stackalloc byte[16];
        BitConverter.TryWriteBytes(bytes, index);
        bytes[4] = 0x50;
        bytes[5] = 0x45;
        bytes[6] = 0x52;
        bytes[7] = 0x46;
        bytes[8] = 0x31;
        bytes[9] = 0x30;
        bytes[10] = 0x30;
        bytes[11] = 0x4B;
        bytes[12] = 0x4E;
        bytes[13] = 0x4F;
        bytes[14] = 0x54;
        bytes[15] = 0x45;
        return new Guid(bytes);
    }

    private static async Task<string> HashFileAsync(string path)
    {
        await using var stream = File.OpenRead(path);
        return Convert.ToHexString(await SHA256.HashDataAsync(stream));
    }

    private static int WriteJson(object value)
    {
        Console.WriteLine(JsonSerializer.Serialize(value, JsonOptions));
        return 0;
    }

    private static void PrintUsage()
    {
        Console.WriteLine(
            "WindowsFrameProbe fixture --source <mc> --destination <mc> [--note-count 100000]\n" +
            "WindowsFrameProbe display-list\n" +
            "WindowsFrameProbe display-set --width <px> --height <px> --refresh <hz>\n" +
            "WindowsFrameProbe probe --process-id <pid> --output <json> " +
            "[--composition-frames 600] [--input-trials 50]\n" +
            "WindowsFrameProbe uia-input-probe --process-id <pid> --output <json> " +
            "[--input-trials 50]");
    }

    private sealed class VisiblePixelCapture : IDisposable
    {
        private const int CaptureWidth = 320;
        private const int CaptureHeight = 240;
        private const int SwRestore = 9;
        private const uint SwpNoZOrder = 0x0004;
        private const uint SwpNoActivate = 0x0010;
        private const uint Srccopy = 0x00CC0020;
        private const int DibRgbColors = 0;
        private const uint InputMouse = 0;
        private const uint MouseeventfLeftdown = 0x0002;
        private const uint MouseeventfLeftup = 0x0004;
        private const uint MouseeventfWheel = 0x0800;
        private const int ForegroundRetries = 30;

        private readonly IntPtr _window;
        private readonly IntPtr _screenDc;
        private readonly IntPtr _memoryDc;
        private readonly IntPtr _bitmap;
        private readonly IntPtr _previousBitmap;
        private readonly IntPtr _bits;
        private readonly byte[] _pixels = new byte[CaptureWidth * CaptureHeight * 4];
        private bool _disposed;

        public VisiblePixelCapture(IntPtr window, int width, int height)
        {
            _window = window;
            Native.ShowWindow(_window, SwRestore);
            if (!Native.SetWindowPos(
                    _window,
                    IntPtr.Zero,
                    290,
                    164,
                    width,
                    height,
                    SwpNoZOrder | SwpNoActivate))
                throw new InvalidOperationException("SetWindowPos failed.");
            Thread.Sleep(500);
            if (!Native.GetWindowRect(_window, out var windowRect))
                throw new InvalidOperationException("GetWindowRect failed.");
            Window = new RectangleEvidence(
                windowRect.Left,
                windowRect.Top,
                windowRect.Right - windowRect.Left,
                windowRect.Bottom - windowRect.Top);
            Region = new RectangleEvidence(
                windowRect.Left + (int)Math.Round(Window.Width * 0.20),
                windowRect.Top + (int)Math.Round(Window.Height * 0.35),
                CaptureWidth,
                CaptureHeight);

            _screenDc = Native.GetDC(IntPtr.Zero);
            if (_screenDc == IntPtr.Zero)
                throw new InvalidOperationException("GetDC failed.");
            _memoryDc = Native.CreateCompatibleDC(_screenDc);
            if (_memoryDc == IntPtr.Zero)
                throw new InvalidOperationException("CreateCompatibleDC failed.");
            var bitmapInfo = new Native.BitmapInfo
            {
                Header = new Native.BitmapInfoHeader
                {
                    Size = (uint)Marshal.SizeOf<Native.BitmapInfoHeader>(),
                    Width = CaptureWidth,
                    Height = -CaptureHeight,
                    Planes = 1,
                    BitCount = 32,
                    Compression = 0
                }
            };
            _bitmap = Native.CreateDIBSection(
                _memoryDc,
                ref bitmapInfo,
                DibRgbColors,
                out _bits,
                IntPtr.Zero,
                0);
            if (_bitmap == IntPtr.Zero || _bits == IntPtr.Zero)
                throw new InvalidOperationException("CreateDIBSection failed.");
            _previousBitmap = Native.SelectObject(_memoryDc, _bitmap);
        }

        public RectangleEvidence Window { get; }
        public RectangleEvidence Region { get; }

        public void Activate()
        {
            Native.ShowWindow(_window, SwRestore);
            for (var attempt = 0; attempt < ForegroundRetries; attempt++)
            {
                Native.BringWindowToTop(_window);
                Native.SetForegroundWindow(_window);
                if (Native.GetForegroundWindow() == _window)
                    return;
                if (attempt == 3)
                    SendAltUnlock();
                Thread.Sleep(100);
            }
            throw new InvalidOperationException("Could not foreground the target window.");
        }

        public static Distribution MeasureDwmFlushBaseline(int frames)
        {
            var timestamps = new List<long>(frames);
            for (var index = 0; index < frames; index++)
            {
                Flush();
                timestamps.Add(Stopwatch.GetTimestamp());
            }
            return ToIntervals(timestamps);
        }

        public void FocusTimeline()
        {
            var x = Window.X + (int)Math.Round(Window.Width * 0.38);
            var y = Window.Y + (int)Math.Round(Window.Height * 0.70);
            FocusPoint(x, y);
        }

        public void FocusPoint(int x, int y)
        {
            Activate();
            if (!Native.SetCursorPos(x, y))
                throw new InvalidOperationException("SetCursorPos failed.");
            SendMouseButton();
            Thread.Sleep(150);
        }

        public void PreRollForward(int steps)
        {
            for (var index = 0; index < steps; index++)
            {
                SendWheel(-120);
                Flush();
            }
        }

        public void SendWheelStep(int delta) => SendWheel(delta);

        public void WarmUp(int compositionFrames)
        {
            for (var index = 0; index < compositionFrames; index++)
            {
                Flush();
                _ = CaptureHash();
            }
        }

        public CadenceResult MeasureInputDrivenCadence(int compositionFrames)
        {
            var compositionTimestamps = new List<long>(compositionFrames);
            var changedTimestamps = new List<long>(compositionFrames);
            var previousHash = CaptureHash();
            for (var index = 0; index < compositionFrames; index++)
            {
                SendWheel(index % 2 == 0 ? -120 : 120);
                Flush();
                var timestamp = Stopwatch.GetTimestamp();
                var hash = CaptureHash();
                compositionTimestamps.Add(timestamp);
                if (hash == previousHash)
                    continue;
                previousHash = hash;
                changedTimestamps.Add(timestamp);
            }

            return new CadenceResult(
                compositionFrames,
                changedTimestamps.Count,
                compositionFrames - changedTimestamps.Count,
                ToIntervals(compositionTimestamps),
                ToIntervals(changedTimestamps));
        }

        public InputLatencyResult MeasureInputToVisible(int requestedTrials)
        {
            var latencies = new List<double>(requestedTrials);
            var timeouts = 0;
            for (var trial = 0; trial < requestedTrials; trial++)
            {
                Flush();
                var baseline = CaptureHash();
                var sentAt = Stopwatch.GetTimestamp();
                SendWheel(trial % 2 == 0 ? -120 : 120);
                var changed = false;
                for (var frame = 0; frame < 60; frame++)
                {
                    Flush();
                    var observedAt = Stopwatch.GetTimestamp();
                    if (CaptureHash() == baseline)
                        continue;
                    latencies.Add(
                        (observedAt - sentAt) * 1000d / Stopwatch.Frequency);
                    changed = true;
                    break;
                }
                if (!changed)
                    timeouts++;
                WarmUp(2);
            }

            return new InputLatencyResult(
                requestedTrials,
                latencies.Count,
                timeouts,
                Distribution.From(latencies));
        }

        private ulong CaptureHash()
        {
            if (!Native.BitBlt(
                    _memoryDc,
                    0,
                    0,
                    CaptureWidth,
                    CaptureHeight,
                    _screenDc,
                    Region.X,
                    Region.Y,
                    Srccopy))
                throw new InvalidOperationException("BitBlt failed.");
            Marshal.Copy(_bits, _pixels, 0, _pixels.Length);
            var hash = 14695981039346656037UL;
            for (var index = 0; index < _pixels.Length; index += 16)
            {
                hash ^= _pixels[index];
                hash *= 1099511628211UL;
                hash ^= _pixels[index + 1];
                hash *= 1099511628211UL;
                hash ^= _pixels[index + 2];
                hash *= 1099511628211UL;
            }
            return hash;
        }

        private static Distribution ToIntervals(List<long> timestamps)
        {
            if (timestamps.Count < 2)
                return Distribution.Empty;
            var values = new double[timestamps.Count - 1];
            for (var index = 1; index < timestamps.Count; index++)
            {
                values[index - 1] =
                    (timestamps[index] - timestamps[index - 1]) *
                    1000d / Stopwatch.Frequency;
            }
            return Distribution.From(values);
        }

        private static void Flush()
        {
            var result = Native.DwmFlush();
            if (result != 0)
                Marshal.ThrowExceptionForHR(result);
        }

        private static void SendMouseButton()
        {
            var inputs = new[]
            {
                Native.Input.Mouse(MouseeventfLeftdown, 0),
                Native.Input.Mouse(MouseeventfLeftup, 0)
            };
            var sent = Native.SendInput(
                (uint)inputs.Length,
                inputs,
                Marshal.SizeOf<Native.Input>());
            if (sent != inputs.Length)
                throw new InvalidOperationException("SendInput click failed.");
        }

        private static void SendWheel(int delta)
        {
            var input = new[] { Native.Input.Mouse(MouseeventfWheel, delta) };
            var sent = Native.SendInput(
                1,
                input,
                Marshal.SizeOf<Native.Input>());
            if (sent != 1)
                throw new InvalidOperationException("SendInput wheel failed.");
        }

        private static void SendAltUnlock()
        {
            const ushort alt = 0x12;
            const uint inputKeyboard = 1;
            const uint keyup = 0x0002;
            var inputs = new[]
            {
                Native.Input.Keyboard(inputKeyboard, alt, 0),
                Native.Input.Keyboard(inputKeyboard, alt, keyup)
            };
            var sent = Native.SendInput(
                (uint)inputs.Length,
                inputs,
                Marshal.SizeOf<Native.Input>());
            if (sent != inputs.Length)
                throw new InvalidOperationException("SendInput foreground unlock failed.");
        }

        public void Dispose()
        {
            if (_disposed)
                return;
            _disposed = true;
            if (_memoryDc != IntPtr.Zero && _previousBitmap != IntPtr.Zero)
                Native.SelectObject(_memoryDc, _previousBitmap);
            if (_bitmap != IntPtr.Zero)
                Native.DeleteObject(_bitmap);
            if (_memoryDc != IntPtr.Zero)
                Native.DeleteDC(_memoryDc);
            if (_screenDc != IntPtr.Zero)
                Native.ReleaseDC(IntPtr.Zero, _screenDc);
        }
    }

    private sealed class CommandOptions
    {
        private readonly Dictionary<string, string> _values;

        private CommandOptions(Dictionary<string, string> values)
        {
            _values = values;
        }

        public static CommandOptions Parse(string[] args)
        {
            var values = new Dictionary<string, string>(StringComparer.Ordinal);
            for (var index = 0; index < args.Length; index += 2)
            {
                var key = args[index];
                if (!key.StartsWith("--", StringComparison.Ordinal) ||
                    index + 1 >= args.Length)
                    throw new ArgumentException($"Expected --name value at argument {index + 1}.");
                if (!values.TryAdd(key[2..], args[index + 1]))
                    throw new ArgumentException($"Duplicate option: {key}");
            }
            return new CommandOptions(values);
        }

        public string Required(string name) =>
            _values.TryGetValue(name, out var value) &&
            !string.IsNullOrWhiteSpace(value)
                ? value
                : throw new ArgumentException($"Missing --{name}.");

        public int Int32(string name, int defaultValue, int minimum, int maximum)
        {
            if (!_values.TryGetValue(name, out var text))
                return defaultValue;
            if (!int.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out var value) ||
                value < minimum ||
                value > maximum)
                throw new ArgumentOutOfRangeException(
                    name,
                    $"--{name} must be between {minimum} and {maximum}.");
            return value;
        }
    }

    private static class DisplayModeController
    {
        private const int EnumCurrentSettings = -1;
        private const uint CdsTest = 0x00000002;
        private const int DispChangeSuccessful = 0;

        public static object Describe()
        {
            var current = Current();
            return new
            {
                current,
                modes = Enumerate()
                    .Where(mode =>
                        mode.Width == current.Width &&
                        mode.Height == current.Height)
                    .Select(mode => mode.Value)
                    .Distinct()
                    .OrderBy(mode => mode.RefreshHz)
                    .ToArray()
            };
        }

        public static DisplayMode Current()
        {
            var mode = Native.DevMode.Create();
            if (!Native.EnumDisplaySettings(null, EnumCurrentSettings, ref mode))
                throw new InvalidOperationException("EnumDisplaySettings(current) failed.");
            return DisplayMode.From(mode);
        }

        public static object Set(int width, int height, int refresh)
        {
            var before = Current();
            var desired = Enumerate()
                .FirstOrDefault(mode =>
                    mode.Width == width &&
                    mode.Height == height &&
                    mode.RefreshHz == refresh)
                ?? throw new InvalidOperationException(
                    $"Display mode is unavailable: {width}x{height}@{refresh}");
            var native = desired.Native;
            var test = Native.ChangeDisplaySettings(ref native, CdsTest);
            if (test != DispChangeSuccessful)
                throw new InvalidOperationException(
                    $"ChangeDisplaySettings test failed: {test}");
            var apply = Native.ChangeDisplaySettings(ref native, 0);
            if (apply != DispChangeSuccessful)
                throw new InvalidOperationException(
                    $"ChangeDisplaySettings apply failed: {apply}");
            Thread.Sleep(1_000);
            var after = Current();
            if (after.Width != width ||
                after.Height != height ||
                after.RefreshHz != refresh)
                throw new InvalidOperationException(
                    $"Applied display mode differs: {after.Width}x{after.Height}@{after.RefreshHz}");
            return new
            {
                status = "changed",
                before,
                requested = new { width, height, refreshHz = refresh },
                after
            };
        }

        private static IEnumerable<DisplayModeNative> Enumerate()
        {
            for (var index = 0; ; index++)
            {
                var mode = Native.DevMode.Create();
                if (!Native.EnumDisplaySettings(null, index, ref mode))
                    yield break;
                if (mode.PelsWidth <= 0 ||
                    mode.PelsHeight <= 0 ||
                    mode.DisplayFrequency <= 0)
                    continue;
                yield return new DisplayModeNative(DisplayMode.From(mode), mode);
            }
        }

        private sealed record DisplayModeNative(DisplayMode Value, Native.DevMode Native)
        {
            public int Width => Value.Width;
            public int Height => Value.Height;
            public int RefreshHz => Value.RefreshHz;

            public static implicit operator DisplayMode(DisplayModeNative value) => value.Value;
        }
    }

    private static class Native
    {
        [DllImport("dwmapi.dll")]
        public static extern int DwmFlush();

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetWindowRect(IntPtr window, out Rect rectangle);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ShowWindow(IntPtr window, int command);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetWindowPos(
            IntPtr window,
            IntPtr insertAfter,
            int x,
            int y,
            int width,
            int height,
            uint flags);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr window);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool BringWindowToTop(IntPtr window);

        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetCursorPos(int x, int y);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetProcessDpiAwarenessContext(IntPtr value);

        [DllImport("user32.dll")]
        public static extern uint SendInput(
            uint inputCount,
            [In] Input[] inputs,
            int inputSize);

        [DllImport("user32.dll")]
        public static extern IntPtr GetDC(IntPtr window);

        [DllImport("user32.dll")]
        public static extern int ReleaseDC(IntPtr window, IntPtr dc);

        [DllImport("gdi32.dll")]
        public static extern IntPtr CreateCompatibleDC(IntPtr dc);

        [DllImport("gdi32.dll")]
        public static extern IntPtr SelectObject(IntPtr dc, IntPtr value);

        [DllImport("gdi32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool DeleteObject(IntPtr value);

        [DllImport("gdi32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool DeleteDC(IntPtr dc);

        [DllImport("gdi32.dll")]
        public static extern IntPtr CreateDIBSection(
            IntPtr dc,
            ref BitmapInfo bitmapInfo,
            int usage,
            out IntPtr bits,
            IntPtr section,
            uint offset);

        [DllImport("gdi32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool BitBlt(
            IntPtr destination,
            int destinationX,
            int destinationY,
            int destinationWidth,
            int destinationHeight,
            IntPtr source,
            int sourceX,
            int sourceY,
            uint operation);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool EnumDisplaySettings(
            string? deviceName,
            int modeNumber,
            ref DevMode mode);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int ChangeDisplaySettings(ref DevMode mode, uint flags);

        [StructLayout(LayoutKind.Sequential)]
        public struct Rect
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BitmapInfoHeader
        {
            public uint Size;
            public int Width;
            public int Height;
            public ushort Planes;
            public ushort BitCount;
            public uint Compression;
            public uint SizeImage;
            public int XPelsPerMeter;
            public int YPelsPerMeter;
            public uint ClrUsed;
            public uint ClrImportant;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BitmapInfo
        {
            public BitmapInfoHeader Header;
            public uint Color0;
            public uint Color1;
            public uint Color2;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct Input
        {
            public uint Type;
            public InputUnion Union;

            public static Input Mouse(uint flags, int data) => new()
            {
                Type = 0,
                Union = new InputUnion
                {
                    Mouse = new MouseInput
                    {
                        MouseData = unchecked((uint)data),
                        Flags = flags
                    }
                }
            };

            public static Input Keyboard(uint type, ushort key, uint flags) => new()
            {
                Type = type,
                Union = new InputUnion
                {
                    Keyboard = new KeyboardInput
                    {
                        VirtualKey = key,
                        Flags = flags
                    }
                }
            };
        }

        [StructLayout(LayoutKind.Explicit)]
        public struct InputUnion
        {
            [FieldOffset(0)]
            public MouseInput Mouse;

            [FieldOffset(0)]
            public KeyboardInput Keyboard;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct MouseInput
        {
            public int X;
            public int Y;
            public uint MouseData;
            public uint Flags;
            public uint Time;
            public IntPtr ExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KeyboardInput
        {
            public ushort VirtualKey;
            public ushort Scan;
            public uint Flags;
            public uint Time;
            public IntPtr ExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct DevMode
        {
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string DeviceName;
            public ushort SpecVersion;
            public ushort DriverVersion;
            public ushort Size;
            public ushort DriverExtra;
            public uint Fields;
            public int PositionX;
            public int PositionY;
            public uint DisplayOrientation;
            public uint DisplayFixedOutput;
            public short Color;
            public short Duplex;
            public short YResolution;
            public short TTOption;
            public short Collate;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string FormName;
            public ushort LogPixels;
            public uint BitsPerPel;
            public uint PelsWidth;
            public uint PelsHeight;
            public uint DisplayFlags;
            public uint DisplayFrequency;
            public uint ICMMethod;
            public uint ICMIntent;
            public uint MediaType;
            public uint DitherType;
            public uint Reserved1;
            public uint Reserved2;
            public uint PanningWidth;
            public uint PanningHeight;

            public static DevMode Create() => new()
            {
                DeviceName = string.Empty,
                FormName = string.Empty,
                Size = (ushort)Marshal.SizeOf<DevMode>()
            };
        }
    }

    private sealed record ProcessSnapshot(
        TimeSpan TotalProcessorTime,
        long WorkingSetBytes,
        long PrivateBytes,
        int ThreadCount,
        DateTimeOffset ObservedUtc);

    private sealed record TimelineAutomationState(
        double CurrentBeat,
        int InputToRenderSamples,
        double InputToRenderP50,
        double InputToRenderP95,
        double InputToRenderP99);

    private sealed record RectangleEvidence(int X, int Y, int Width, int Height);

    private sealed record DisplayMode(int Width, int Height, int RefreshHz, int BitsPerPixel)
    {
        public static DisplayMode From(Native.DevMode mode) => new(
            checked((int)mode.PelsWidth),
            checked((int)mode.PelsHeight),
            checked((int)mode.DisplayFrequency),
            checked((int)mode.BitsPerPel));
    }

    private sealed record CadenceResult(
        int CompositionFrames,
        int VisibleChangedFrames,
        int UnchangedCompositionFrames,
        Distribution CompositionIntervals,
        Distribution VisibleChangeIntervals);

    private sealed record InputLatencyResult(
        int RequestedTrials,
        int CompletedTrials,
        int TimeoutTrials,
        Distribution LatencyMilliseconds);

    private sealed record Distribution(
        int Samples,
        double P50,
        double P95,
        double P99,
        double Maximum,
        double Minimum,
        double Mean)
    {
        public static Distribution Empty => new(0, 0, 0, 0, 0, 0, 0);

        public static Distribution From(IEnumerable<double> source)
        {
            var values = source.OrderBy(value => value).ToArray();
            if (values.Length == 0)
                return Empty;
            return new Distribution(
                values.Length,
                Percentile(values, 0.50),
                Percentile(values, 0.95),
                Percentile(values, 0.99),
                values[^1],
                values[0],
                values.Average());
        }

        private static double Percentile(double[] sorted, double percentile)
        {
            if (sorted.Length == 1)
                return sorted[0];
            var position = (sorted.Length - 1) * percentile;
            var lower = (int)Math.Floor(position);
            var upper = (int)Math.Ceiling(position);
            if (lower == upper)
                return sorted[lower];
            var fraction = position - lower;
            return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction;
        }
    }
}
