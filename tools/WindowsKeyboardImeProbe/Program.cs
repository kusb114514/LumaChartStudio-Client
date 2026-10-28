using System.Runtime.InteropServices;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace WindowsKeyboardImeProbe;

internal static partial class Program
{
    private const uint InputKeyboard = 1;
    private const uint InputMouse = 0;
    private const uint KeyEventKeyUp = 0x0002;
    private const uint MouseEventMove = 0x0001;
    private const uint MouseEventLeftDown = 0x0002;
    private const uint MouseEventLeftUp = 0x0004;
    private const uint MouseEventVirtualDesk = 0x4000;
    private const uint MouseEventAbsolute = 0x8000;
    private const int ShowWindowRestore = 9;
    private const uint SetWindowPositionNoSize = 0x0001;
    private const uint SetWindowPositionNoMove = 0x0002;
    private const uint SetWindowPositionShowWindow = 0x0040;
    private static readonly IntPtr WindowInsertAfterNotTopmost = new(-2);
    private const uint WmInputLanguageChangeRequest = 0x0050;
    private const uint KlfActivate = 0x00000001;
    private const ushort VirtualKeySpace = 0x20;
    private const ushort VirtualKeyEscape = 0x1B;
    private const ushort VirtualKeyAlt = 0x12;
    private const ushort SimplifiedChineseLanguageId = 0x0804;
    private const int SystemMetricVirtualScreenX = 76;
    private const int SystemMetricVirtualScreenY = 77;
    private const int SystemMetricVirtualScreenWidth = 78;
    private const int SystemMetricVirtualScreenHeight = 79;
    private const uint GetAncestorRoot = 2;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    public static int Main(string[] args)
    {
        try
        {
            _ = SetProcessDpiAwarenessContext(new IntPtr(-4));
            var options = ParseOptions(args);
            var result = options.Action switch
            {
                "activate" => ActivateSimplifiedChinese(options),
                "click" => ClickTarget(options),
                "ascii" => SendAscii(options),
                "key" => SendNamedKey(options),
                _ => throw new ArgumentException(
                    "Action must be activate, click, ascii, or key.")
            };
            Console.WriteLine(JsonSerializer.Serialize(result, JsonOptions));
            return 0;
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine(exception);
            return 1;
        }
    }

    private static ProbeOptions ParseOptions(string[] args)
    {
        if (args.Length == 0)
            throw new ArgumentException(
                "Usage: <activate|click|ascii|key> --process-id <id> " +
                "[--window-handle <handle>] [--x <screen-x> --y <screen-y>] " +
                "[--text <letters>] [--name <Space|Escape>].");

        var action = args[0].ToLowerInvariant();
        int? processId = null;
        long? windowHandle = null;
        string? text = null;
        string? name = null;
        int? x = null;
        int? y = null;

        for (var index = 1; index < args.Length; index++)
        {
            var option = args[index];
            if (index + 1 >= args.Length)
                throw new ArgumentException($"Missing value for {option}.");
            var value = args[++index];
            switch (option)
            {
                case "--process-id":
                    processId = int.Parse(value);
                    break;
                case "--window-handle":
                    windowHandle = long.Parse(value);
                    break;
                case "--text":
                    text = value;
                    break;
                case "--name":
                    name = value;
                    break;
                case "--x":
                    x = int.Parse(value);
                    break;
                case "--y":
                    y = int.Parse(value);
                    break;
                default:
                    throw new ArgumentException($"Unknown option: {option}");
            }
        }

        return new ProbeOptions(
            action,
            processId ?? throw new ArgumentException("--process-id is required."),
            windowHandle,
            text,
            name,
            x,
            y);
    }

    private static object ActivateSimplifiedChinese(ProbeOptions options)
    {
        var window = new IntPtr(
            options.WindowHandle ??
            throw new ArgumentException("--window-handle is required for activate."));
        var threadId = GetWindowThreadProcessId(window, out var actualProcessId);
        if (threadId == 0 || actualProcessId != options.ProcessId)
        {
            throw new InvalidOperationException(
                $"Target window belongs to process {actualProcessId}, " +
                $"expected {options.ProcessId}; thread={threadId}.");
        }

        var requestedLayout = LoadKeyboardLayout("00000804", KlfActivate);
        if (requestedLayout == IntPtr.Zero)
            throw new InvalidOperationException("LoadKeyboardLayout(00000804) failed.");
        if (!PostMessage(
                window,
                WmInputLanguageChangeRequest,
                IntPtr.Zero,
                requestedLayout))
        {
            throw new InvalidOperationException(
                "WM_INPUTLANGCHANGEREQUEST failed for the target window.");
        }

        var deadline = DateTimeOffset.UtcNow.AddSeconds(10);
        IntPtr activeLayout;
        do
        {
            activeLayout = GetKeyboardLayout(threadId);
            if ((activeLayout.ToInt64() & 0xffff) == SimplifiedChineseLanguageId)
                break;
            Thread.Sleep(50);
        } while (DateTimeOffset.UtcNow < deadline);

        if ((activeLayout.ToInt64() & 0xffff) != SimplifiedChineseLanguageId)
        {
            throw new InvalidOperationException(
                $"Target thread did not activate zh-CN; active layout " +
                $"{FormatHandle(activeLayout)}.");
        }

        return new
        {
            schema = "lumachart.windows.keyboard-ime-probe.v1",
            action = options.Action,
            targetProcessId = options.ProcessId,
            targetThreadId = threadId,
            requestedKeyboardLayout = FormatHandle(requestedLayout),
            activeKeyboardLayout = FormatHandle(activeLayout),
            activeLanguageId = "0x0804",
            occurredUtc = DateTimeOffset.UtcNow
        };
    }

    private static object SendAscii(ProbeOptions options)
    {
        var text = options.Text ??
                   throw new ArgumentException("--text is required for ascii.");
        if (!AsciiLetters().IsMatch(text))
            throw new ArgumentException("ASCII input must contain only A-Z letters.");

        var foreground = EnsureForegroundProcess(options);
        foreach (var character in text.ToUpperInvariant())
            SendVirtualKey(character);

        return new
        {
            schema = "lumachart.windows.keyboard-ime-probe.v1",
            action = options.Action,
            targetProcessId = options.ProcessId,
            foregroundWindow = FormatHandle(foreground),
            text = text.ToLowerInvariant(),
            injectedKeyCount = text.Length,
            injection = "Win32 SendInput virtual-key down/up",
            occurredUtc = DateTimeOffset.UtcNow
        };
    }

    private static object ClickTarget(ProbeOptions options)
    {
        var window = new IntPtr(
            options.WindowHandle ??
            throw new ArgumentException("--window-handle is required for click."));
        var x = options.X ?? throw new ArgumentException("--x is required for click.");
        var y = options.Y ?? throw new ArgumentException("--y is required for click.");
        var windowThread = GetWindowThreadProcessId(window, out var windowProcessId);
        if (windowThread == 0 || windowProcessId != options.ProcessId)
        {
            throw new InvalidOperationException(
                $"Click window {FormatHandle(window)} belongs to process " +
                $"{windowProcessId}, expected {options.ProcessId}; thread={windowThread}.");
        }
        if (!GetWindowRect(window, out var windowRect) ||
            x < windowRect.Left ||
            x >= windowRect.Right ||
            y < windowRect.Top ||
            y >= windowRect.Bottom)
        {
            throw new InvalidOperationException(
                $"Click point ({x},{y}) is outside target window " +
                $"[{windowRect.Left},{windowRect.Top},{windowRect.Right},{windowRect.Bottom}).");
        }

        SendVirtualKey(VirtualKeyAlt);
        var activationForeground = EnsureForegroundProcess(options);
        _ = ShowWindowAsync(window, ShowWindowRestore);
        var forcedNonTopmost = ForceWindowNonTopmost(window);
        Thread.Sleep(75);
        var hitWindow = WindowFromPoint(new Point { X = x, Y = y });
        var hitRoot = GetAncestor(hitWindow, GetAncestorRoot);
        _ = GetWindowThreadProcessId(hitRoot, out var hitProcessId);
        if (hitRoot == IntPtr.Zero || hitProcessId != options.ProcessId)
        {
            throw new InvalidOperationException(
                $"Click point ({x},{y}) resolves to {FormatHandle(hitRoot)} " +
                $"in process {hitProcessId}, expected {options.ProcessId}.");
        }

        SendMouseClick(x, y);
        if (!TryWaitForForegroundProcess(
                options.ProcessId,
                out var foreground))
        {
            throw new InvalidOperationException(
                $"Injected click at ({x},{y}) did not foreground process " +
                $"{options.ProcessId}; current={FormatHandle(GetForegroundWindow())}.");
        }

        return new
        {
            schema = "lumachart.windows.keyboard-ime-probe.v1",
            action = options.Action,
            targetProcessId = options.ProcessId,
            foregroundWindow = FormatHandle(foreground),
            activationForegroundWindow = FormatHandle(activationForeground),
            x,
            y,
            targetPromotedTopmost = false,
            targetForcedNonTopmost = forcedNonTopmost,
            injectedMouseButtonCount = 1,
            foregroundUnlockAltInjected = true,
            foregroundUnlockInjectedKeyCount = 1,
            injection = "Win32 SendInput absolute mouse move and left-button down/up",
            hardwareMouseInputClaimed = false,
            occurredUtc = DateTimeOffset.UtcNow
        };
    }

    private static object SendNamedKey(ProbeOptions options)
    {
        var name = options.Name ??
                   throw new ArgumentException("--name is required for key.");
        var virtualKey = name switch
        {
            "Space" => VirtualKeySpace,
            "Escape" => VirtualKeyEscape,
            _ => throw new ArgumentException("Named key must be Space or Escape.")
        };
        var foreground = EnsureForegroundProcess(options);
        SendVirtualKey(virtualKey);

        return new
        {
            schema = "lumachart.windows.keyboard-ime-probe.v1",
            action = options.Action,
            targetProcessId = options.ProcessId,
            foregroundWindow = FormatHandle(foreground),
            key = name,
            injectedKeyCount = 1,
            injection = "Win32 SendInput virtual-key down/up",
            enterKeySent = false,
            occurredUtc = DateTimeOffset.UtcNow
        };
    }

    private static IntPtr EnsureForegroundProcess(ProbeOptions options)
    {
        if (options.WindowHandle is { } requestedWindowHandle)
        {
            var requestedWindow = new IntPtr(requestedWindowHandle);
            var requestedThread = GetWindowThreadProcessId(
                requestedWindow,
                out var requestedProcessId);
            if (requestedThread == 0 || requestedProcessId != options.ProcessId)
            {
                throw new InvalidOperationException(
                    $"Requested foreground window {FormatHandle(requestedWindow)} " +
                    $"belongs to process {requestedProcessId}, expected " +
                    $"{options.ProcessId}; thread={requestedThread}.");
            }

            var existingForeground = GetForegroundWindow();
            _ = GetWindowThreadProcessId(existingForeground, out var existingProcessId);
            if (existingForeground != IntPtr.Zero &&
                existingProcessId == options.ProcessId)
            {
                _ = ForceWindowNonTopmost(requestedWindow);
                return existingForeground;
            }

            _ = ShowWindowAsync(requestedWindow, ShowWindowRestore);
            var forcedNonTopmost = ForceWindowNonTopmost(requestedWindow);
            _ = BringWindowToTop(requestedWindow);
            var directActivation = SetForegroundWindow(requestedWindow);
            if (!TryWaitForForegroundProcess(
                    options.ProcessId,
                    out var activatedForeground))
            {
                _ = SetForegroundWindow(requestedWindow);
                _ = SetActiveWindow(requestedWindow);
                _ = SetFocus(requestedWindow);
                if (TryWaitForForegroundProcess(
                        options.ProcessId,
                        out activatedForeground))
                {
                    return activatedForeground;
                }

                var probeThread = GetCurrentThreadId();
                var foregroundBeforeAttach = GetForegroundWindow();
                var foregroundThread = GetWindowThreadProcessId(
                    foregroundBeforeAttach,
                    out var foregroundProcessId);
                var attachedToForeground = foregroundThread != 0 &&
                                           foregroundThread != probeThread &&
                                           AttachThreadInput(
                                               probeThread,
                                               foregroundThread,
                                               true);
                var attachedToTarget = requestedThread != probeThread &&
                                       requestedThread != foregroundThread &&
                                       AttachThreadInput(
                                           probeThread,
                                           requestedThread,
                                           true);
                try
                {
                    _ = BringWindowToTop(requestedWindow);
                    _ = SetActiveWindow(requestedWindow);
                    _ = SetFocus(requestedWindow);
                    _ = SetForegroundWindow(requestedWindow);
                }
                finally
                {
                    if (attachedToTarget)
                        _ = AttachThreadInput(probeThread, requestedThread, false);
                    if (attachedToForeground)
                        _ = AttachThreadInput(probeThread, foregroundThread, false);
                }

                if (!TryWaitForForegroundProcess(
                        options.ProcessId,
                        out activatedForeground))
                {
                    throw new InvalidOperationException(
                        $"Could not activate {FormatHandle(requestedWindow)} for process " +
                        $"{options.ProcessId}; direct={directActivation}; " +
                        $"previousForeground={FormatHandle(foregroundBeforeAttach)}; " +
                        $"previousProcess={foregroundProcessId}; " +
                        $"forcedNonTopmost={forcedNonTopmost}; " +
                        $"attachedForeground={attachedToForeground}; " +
                        $"attachedTarget={attachedToTarget}; " +
                        $"currentForeground={FormatHandle(GetForegroundWindow())}.");
                }
            }

            return activatedForeground;
        }

        var foreground = GetForegroundWindow();
        var threadId = GetWindowThreadProcessId(foreground, out var processId);
        if (foreground == IntPtr.Zero ||
            threadId == 0 ||
            processId != options.ProcessId)
        {
            throw new InvalidOperationException(
                $"Foreground window {FormatHandle(foreground)} belongs to process " +
                $"{processId}, expected {options.ProcessId}; thread={threadId}.");
        }

        return foreground;
    }

    private static bool ForceWindowNonTopmost(IntPtr window)
    {
        var result = SetWindowPos(
            window,
            WindowInsertAfterNotTopmost,
            0,
            0,
            0,
            0,
            SetWindowPositionNoSize |
            SetWindowPositionNoMove |
            SetWindowPositionShowWindow);
        if (!result)
        {
            throw new InvalidOperationException(
                $"Could not clear the topmost state of {FormatHandle(window)}; " +
                $"Win32={Marshal.GetLastWin32Error()}.");
        }

        return true;
    }

    private static bool TryWaitForForegroundProcess(
        int expectedProcessId,
        out IntPtr foreground)
    {
        for (var attempt = 0; attempt < 12; attempt++)
        {
            foreground = GetForegroundWindow();
            var threadId = GetWindowThreadProcessId(foreground, out var processId);
            if (foreground != IntPtr.Zero &&
                threadId != 0 &&
                processId == expectedProcessId)
            {
                return true;
            }

            Thread.Sleep(50);
        }

        foreground = GetForegroundWindow();
        return false;
    }

    private static void SendVirtualKey(ushort virtualKey)
    {
        var inputs = new[]
        {
            new Input
            {
                Type = InputKeyboard,
                Data = new InputUnion
                {
                    Keyboard = new KeyboardInput
                    {
                        VirtualKey = virtualKey
                    }
                }
            },
            new Input
            {
                Type = InputKeyboard,
                Data = new InputUnion
                {
                    Keyboard = new KeyboardInput
                    {
                        VirtualKey = virtualKey,
                        Flags = KeyEventKeyUp
                    }
                }
            }
        };
        var sent = SendInput(
            (uint)inputs.Length,
            inputs,
            Marshal.SizeOf<Input>());
        if (sent != inputs.Length)
        {
            throw new InvalidOperationException(
                $"SendInput sent {sent}/{inputs.Length} events; " +
                $"Win32={Marshal.GetLastWin32Error()}.");
        }

        Thread.Sleep(45);
    }

    private static void SendMouseClick(int x, int y)
    {
        var virtualLeft = GetSystemMetrics(SystemMetricVirtualScreenX);
        var virtualTop = GetSystemMetrics(SystemMetricVirtualScreenY);
        var virtualWidth = GetSystemMetrics(SystemMetricVirtualScreenWidth);
        var virtualHeight = GetSystemMetrics(SystemMetricVirtualScreenHeight);
        if (virtualWidth <= 1 || virtualHeight <= 1)
            throw new InvalidOperationException("Windows virtual screen metrics are invalid.");
        var absoluteX = (int)Math.Round(
            (x - virtualLeft) * 65535d / (virtualWidth - 1),
            MidpointRounding.AwayFromZero);
        var absoluteY = (int)Math.Round(
            (y - virtualTop) * 65535d / (virtualHeight - 1),
            MidpointRounding.AwayFromZero);
        var inputs = new[]
        {
            new Input
            {
                Type = InputMouse,
                Data = new InputUnion
                {
                    Mouse = new MouseInput
                    {
                        X = absoluteX,
                        Y = absoluteY,
                        Flags = MouseEventMove |
                                MouseEventVirtualDesk |
                                MouseEventAbsolute
                    }
                }
            },
            new Input
            {
                Type = InputMouse,
                Data = new InputUnion
                {
                    Mouse = new MouseInput
                    {
                        Flags = MouseEventLeftDown
                    }
                }
            },
            new Input
            {
                Type = InputMouse,
                Data = new InputUnion
                {
                    Mouse = new MouseInput
                    {
                        Flags = MouseEventLeftUp
                    }
                }
            }
        };
        var sent = SendInput(
            (uint)inputs.Length,
            inputs,
            Marshal.SizeOf<Input>());
        if (sent != inputs.Length)
        {
            throw new InvalidOperationException(
                $"SendInput sent {sent}/{inputs.Length} mouse events; " +
                $"Win32={Marshal.GetLastWin32Error()}.");
        }

        Thread.Sleep(150);
    }

    private static string FormatHandle(IntPtr value) =>
        $"0x{value.ToInt64():X}";

    [GeneratedRegex("^[A-Za-z]+$", RegexOptions.CultureInvariant)]
    private static partial Regex AsciiLetters();

    private sealed record ProbeOptions(
        string Action,
        int ProcessId,
        long? WindowHandle,
        string? Text,
        string? Name,
        int? X,
        int? Y);

    [StructLayout(LayoutKind.Sequential)]
    private struct Input
    {
        public uint Type;
        public InputUnion Data;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)]
        public KeyboardInput Keyboard;

        [FieldOffset(0)]
        public MouseInput Mouse;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KeyboardInput
    {
        public ushort VirtualKey;
        public ushort ScanCode;
        public uint Flags;
        public uint Time;
        public UIntPtr ExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MouseInput
    {
        public int X;
        public int Y;
        public uint MouseData;
        public uint Flags;
        public uint Time;
        public UIntPtr ExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Point
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Rectangle
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(
        uint inputCount,
        Input[] inputs,
        int inputSize);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetProcessDpiAwarenessContext(IntPtr context);

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int index);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetWindowRect(IntPtr window, out Rectangle rectangle);

    [DllImport("user32.dll")]
    private static extern IntPtr WindowFromPoint(Point point);

    [DllImport("user32.dll")]
    private static extern IntPtr GetAncestor(IntPtr window, uint flags);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool ShowWindowAsync(IntPtr window, int command);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetWindowPos(
        IntPtr window,
        IntPtr insertAfter,
        int x,
        int y,
        int width,
        int height,
        uint flags);

    [DllImport("user32.dll")]
    private static extern IntPtr SetActiveWindow(IntPtr window);

    [DllImport("user32.dll")]
    private static extern IntPtr SetFocus(IntPtr window);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool AttachThreadInput(
        uint attachThreadId,
        uint attachToThreadId,
        [MarshalAs(UnmanagedType.Bool)] bool attach);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(
        IntPtr window,
        out uint processId);

    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    private static extern IntPtr GetKeyboardLayout(uint threadId);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr LoadKeyboardLayout(
        string keyboardLayoutId,
        uint flags);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool PostMessage(
        IntPtr window,
        uint message,
        IntPtr wParam,
        IntPtr lParam);
}
