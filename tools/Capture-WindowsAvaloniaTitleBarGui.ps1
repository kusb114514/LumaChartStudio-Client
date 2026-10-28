param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [switch]$ResizeOnly,
    [switch]$CaptionOnly,
    [switch]$WindowMoveOnly,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 120,
    [switch]$AllowForegroundAutomation
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia title-bar GUI capture requires PowerShell Core on Windows."
}
if (-not $AllowForegroundAutomation) {
    throw (
        "Foreground GUI automation is disabled. Pass " +
        "-AllowForegroundAutomation only after the user explicitly confirms " +
        "that the desktop is available.")
}
if (@(@($ResizeOnly, $CaptionOnly, $WindowMoveOnly) |
        Where-Object { $_ }).Count -gt 1) {
    throw "ResizeOnly, CaptionOnly and WindowMoveOnly are mutually exclusive."
}

function Resolve-ExistingFile([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "$Label not found: $full"
    }
    return $full
}

function Wait-Condition {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Condition,
        [Parameter(Mandatory = $true)][string]$Description,
        [int]$Seconds = $TimeoutSeconds
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try {
            if (& $Condition) { return }
        }
        catch { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Threading;

public static class LumaChartTitleBarGuiNative
{
    public static int ForegroundActivationAltPulseCount { get; private set; }
    public static int ForegroundActivationMouseClickCount { get; private set; }
    public static int ForegroundActivationHitTestFallbackCount { get; private set; }
    public static bool ForegroundActivationTopmostFallbackActive { get; private set; }
    public static long LastActivationHitHandle { get; private set; }
    public static long LastActivationHitRootHandle { get; private set; }
    public static long LastActivationExpectedRootHandle { get; private set; }
    public static int LastActivationPointX { get; private set; }
    public static int LastActivationPointY { get; private set; }
    public static string LastActivationPhase { get; private set; } = "not-started";

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT
    {
        public uint Type;
        public MOUSEINPUT Mouse;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT
    {
        public int X;
        public int Y;
        public uint MouseData;
        public uint Flags;
        public uint Time;
        public UIntPtr ExtraInfo;
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr window, IntPtr deviceContext, uint flags);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool IsZoomed(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern void SwitchToThisWindow(IntPtr window, bool altTab);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(
        IntPtr window,
        IntPtr insertAfter,
        int x,
        int y,
        int width,
        int height,
        uint flags);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint firstThread, uint secondThread, bool attach);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT point);

    [DllImport("user32.dll")]
    public static extern IntPtr WindowFromPoint(POINT point);

    [DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr window, uint flags);

    [DllImport("user32.dll")]
    public static extern void keybd_event(
        byte virtualKey,
        byte scanCode,
        uint flags,
        UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int index);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint count, INPUT[] inputs, int size);

    public const uint MouseLeftDown = 0x0002;
    public const uint MouseLeftUp = 0x0004;
    public const uint MouseMove = 0x0001;
    public const uint MouseAbsolute = 0x8000;
    public const uint MouseVirtualDesk = 0x4000;

    public static bool SendAbsoluteMouseMove(int x, int y)
    {
        var left = GetSystemMetrics(76);
        var top = GetSystemMetrics(77);
        var width = GetSystemMetrics(78);
        var height = GetSystemMetrics(79);
        if (width <= 1 || height <= 1) return false;
        var absoluteX = (int)Math.Round((x - left) * 65535.0 / (width - 1));
        var absoluteY = (int)Math.Round((y - top) * 65535.0 / (height - 1));
        absoluteX = Math.Max(0, Math.Min(65535, absoluteX));
        absoluteY = Math.Max(0, Math.Min(65535, absoluteY));
        var input = new INPUT
        {
            Type = 0,
            Mouse = new MOUSEINPUT
            {
                X = absoluteX,
                Y = absoluteY,
                Flags = MouseMove | MouseAbsolute | MouseVirtualDesk
            }
        };
        return SendInput(1, new[] { input }, Marshal.SizeOf<INPUT>()) == 1;
    }

    public static bool SendMouseButton(uint flags)
    {
        var input = new INPUT
        {
            Type = 0,
            Mouse = new MOUSEINPUT { Flags = flags }
        };
        return SendInput(1, new[] { input }, Marshal.SizeOf<INPUT>()) == 1;
    }

    public static bool SendTitleBarActivationClick(IntPtr window)
    {
        LastActivationPhase = "get-window-rect";
        if (!GetWindowRect(window, out var rectangle))
            return false;
        var scale = Math.Max(.75, Math.Min(3, (rectangle.Right - rectangle.Left) / 1320.0));
        var x = rectangle.Left + (int)Math.Round(90 * scale);
        var y = rectangle.Top + (int)Math.Round(19 * scale);
        LastActivationPointX = x;
        LastActivationPointY = y;
        var notTopmost = new IntPtr(-2);
        const uint noMoveNoSizeShow = 0x0001 | 0x0002 | 0x0040;
        LastActivationPhase = "clear-topmost";
        if (!SetWindowPos(window, notTopmost, 0, 0, 0, 0, noMoveNoSizeShow))
            return false;
        try
        {
            BringWindowToTop(window);
            LastActivationPhase = "move-pointer";
            if (!SendAbsoluteMouseMove(x, y))
                return false;
            Thread.Sleep(80);
            var point = new POINT { X = x, Y = y };
            var hit = WindowFromPoint(point);
            const uint root = 2;
            var hitRoot = hit == IntPtr.Zero ? IntPtr.Zero : GetAncestor(hit, root);
            var expectedRoot = GetAncestor(window, root);
            LastActivationHitHandle = hit.ToInt64();
            LastActivationHitRootHandle = hitRoot.ToInt64();
            LastActivationExpectedRootHandle = expectedRoot.ToInt64();
            LastActivationPhase = "hit-test";
            if (hitRoot == IntPtr.Zero || hitRoot != expectedRoot)
                return false;
            LastActivationPhase = "mouse-down";
            if (!SendMouseButton(MouseLeftDown))
                return false;
            Thread.Sleep(45);
            LastActivationPhase = "mouse-up";
            if (!SendMouseButton(MouseLeftUp))
                return false;
            ForegroundActivationMouseClickCount++;
            Thread.Sleep(120);
            if (GetForegroundWindow() != window)
                return false;
            LastActivationPhase = "complete";
            return true;
        }
        finally
        {
            SetWindowPos(window, notTopmost, 0, 0, 0, 0, noMoveNoSizeShow);
        }
    }

    public static bool IsWindowAtCursor(IntPtr window)
    {
        if (window == IntPtr.Zero || !GetCursorPos(out var point))
            return false;
        const uint root = 2;
        var hit = WindowFromPoint(point);
        var hitRoot = hit == IntPtr.Zero ? IntPtr.Zero : GetAncestor(hit, root);
        var expectedRoot = GetAncestor(window, root);
        var matched = hitRoot != IntPtr.Zero && hitRoot == expectedRoot;
        if (matched)
            ForegroundActivationHitTestFallbackCount++;
        return matched;
    }

    public static bool TryActivateWindow(IntPtr window)
    {
        if (window == IntPtr.Zero)
            return false;
        var foreground = GetForegroundWindow();
        if (foreground == window)
            return true;
        var currentThread = GetCurrentThreadId();
        var foregroundThread = foreground == IntPtr.Zero
            ? 0
            : GetWindowThreadProcessId(foreground, out _);
        var targetThread = GetWindowThreadProcessId(window, out _);
        var attachedForeground = false;
        var attachedTarget = false;
        var notTopmost = new IntPtr(-2);
        const uint noMoveNoSizeShow = 0x0001 | 0x0002 | 0x0040;
        try
        {
            if (foregroundThread != 0 && foregroundThread != currentThread)
                attachedForeground = AttachThreadInput(currentThread, foregroundThread, true);
            if (targetThread != 0 && targetThread != currentThread &&
                targetThread != foregroundThread)
                attachedTarget = AttachThreadInput(currentThread, targetThread, true);
            ShowWindowAsync(window, 5);
            BringWindowToTop(window);
            SetForegroundWindow(window);
            if (GetForegroundWindow() == window)
                return true;
            SetWindowPos(window, notTopmost, 0, 0, 0, 0, noMoveNoSizeShow);
            BringWindowToTop(window);
            SetForegroundWindow(window);
            if (GetForegroundWindow() == window)
                return true;
            SwitchToThisWindow(window, true);
            Thread.Sleep(60);
            if (GetForegroundWindow() == window)
                return true;
            const byte virtualKeyMenu = 0x12;
            const uint keyUp = 0x0002;
            keybd_event(virtualKeyMenu, 0, 0, UIntPtr.Zero);
            keybd_event(virtualKeyMenu, 0, keyUp, UIntPtr.Zero);
            ForegroundActivationAltPulseCount++;
            BringWindowToTop(window);
            SetForegroundWindow(window);
            return GetForegroundWindow() == window;
        }
        finally
        {
            SetWindowPos(window, notTopmost, 0, 0, 0, 0, noMoveNoSizeShow);
            if (attachedTarget)
                AttachThreadInput(currentThread, targetThread, false);
            if (attachedForeground)
                AttachThreadInput(currentThread, foregroundThread, false);
        }
    }
}
'@

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 180000)][int]$TimeoutMilliseconds = 10000
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children, $processCondition)
            foreach ($root in $roots) {
                if ([string]$root.Current.AutomationId -ceq $AutomationId) { return $root }
                $candidate = $root.FindFirst(
                    [Windows.Automation.TreeScope]::Descendants,
                    $idCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Find-VisibleElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 180000)][int]$TimeoutMilliseconds = 10000
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children, $processCondition)
            foreach ($root in $roots) {
                $candidates = [Collections.Generic.List[object]]::new()
                if ([string]$root.Current.AutomationId -ceq $AutomationId) {
                    $candidates.Add($root)
                }
                foreach ($candidate in $root.FindAll(
                        [Windows.Automation.TreeScope]::Descendants, $idCondition)) {
                    $candidates.Add($candidate)
                }
                foreach ($candidate in $candidates) {
                    $bounds = $candidate.Current.BoundingRectangle
                    if (-not $candidate.Current.IsOffscreen -and
                        [double]::IsFinite($bounds.Left) -and
                        [double]::IsFinite($bounds.Top) -and
                        [double]::IsFinite($bounds.Width) -and
                        [double]::IsFinite($bounds.Height) -and
                        $bounds.Width -gt 1 -and
                        $bounds.Height -gt 1) {
                        return $candidate
                    }
                }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding visible UI Automation id '$AutomationId' for process $ProcessId."
}

function Find-ElementByName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [ValidateRange(100, 180000)][int]$TimeoutMilliseconds = 10000
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $nameCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty, $Name)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children, $processCondition)
            foreach ($root in $roots) {
                $candidate = $root.FindFirst(
                    [Windows.Automation.TreeScope]::Descendants,
                    $nameCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation name '$Name' for process $ProcessId."
}

function Get-WindowBounds([IntPtr]$Handle) {
    $rectangle = [LumaChartTitleBarGuiNative+RECT]::new()
    if (-not [LumaChartTitleBarGuiNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    return [ordered]@{
        left = $rectangle.Left
        top = $rectangle.Top
        right = $rectangle.Right
        bottom = $rectangle.Bottom
        width = $rectangle.Right - $rectangle.Left
        height = $rectangle.Bottom - $rectangle.Top
    }
}

function Convert-Rectangle($Rectangle) {
    return [ordered]@{
        left = [double]$Rectangle.Left
        top = [double]$Rectangle.Top
        right = [double]$Rectangle.Right
        bottom = [double]$Rectangle.Bottom
        width = [double]$Rectangle.Width
        height = [double]$Rectangle.Height
    }
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $bounds = Get-WindowBounds $Handle
    if ($bounds.width -lt 300 -or $bounds.height -lt 180) {
        throw "Window has invalid bounds: $($bounds.width)x$($bounds.height)."
    }
    $bitmap = [Drawing.Bitmap]::new(
        $bounds.width,
        $bounds.height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $dc = $graphics.GetHdc()
            try {
                if (-not [LumaChartTitleBarGuiNative]::PrintWindow($Handle, $dc, 2)) {
                    throw "PrintWindow failed for $Handle."
                }
            }
            finally { $graphics.ReleaseHdc($dc) }
        }
        finally { $graphics.Dispose() }
        $colors = [Collections.Generic.HashSet[int]]::new()
        for ($y = 0; $y -lt 16; $y++) {
            for ($x = 0; $x -lt 16; $x++) {
                $pixel = $bitmap.GetPixel(
                    [Math]::Min($bounds.width - 1, [int](($x + .5) * $bounds.width / 16)),
                    [Math]::Min($bounds.height - 1, [int](($y + .5) * $bounds.height / 16)))
                [void]$colors.Add($pixel.ToArgb())
            }
        }
        if ($colors.Count -lt 8) {
            throw "Screenshot is near-uniform: $($colors.Count) sampled colors."
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            width = $bounds.width
            height = $bounds.height
            sampledUniqueColors = $colors.Count
            length = (Get-Item -LiteralPath $Path).Length
            sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        }
    }
    finally { $bitmap.Dispose() }
}

function Set-ForegroundWindowVerified([IntPtr]$Handle) {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(3)
    do {
        if ([LumaChartTitleBarGuiNative]::GetForegroundWindow() -eq $Handle) { return }
        [void][LumaChartTitleBarGuiNative]::TryActivateWindow($Handle)
        Start-Sleep -Milliseconds 50
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    if ([LumaChartTitleBarGuiNative]::SendTitleBarActivationClick($Handle)) {
        Start-Sleep -Milliseconds 220
        if ([LumaChartTitleBarGuiNative]::GetForegroundWindow() -eq $Handle) {
            return
        }
    }
    throw "Unable to activate title-bar evidence window $Handle. " +
          "Activation point=($([LumaChartTitleBarGuiNative]::LastActivationPointX)," +
          "$([LumaChartTitleBarGuiNative]::LastActivationPointY)); " +
          "hit=$([LumaChartTitleBarGuiNative]::LastActivationHitHandle); " +
          "hitRoot=$([LumaChartTitleBarGuiNative]::LastActivationHitRootHandle); " +
          "expectedRoot=$([LumaChartTitleBarGuiNative]::LastActivationExpectedRootHandle); " +
          "phase=$([LumaChartTitleBarGuiNative]::LastActivationPhase)."
}

function Set-PhysicalCursorPosition([int]$X, [int]$Y, [string]$Label) {
    if (-not [LumaChartTitleBarGuiNative]::SendAbsoluteMouseMove($X, $Y)) {
        throw "SendInput absolute move failed for $Label at ($X,$Y)."
    }
    Start-Sleep -Milliseconds 35
    $actual = [LumaChartTitleBarGuiNative+POINT]::new()
    if (-not [LumaChartTitleBarGuiNative]::GetCursorPos([ref]$actual) -or
        [Math]::Abs($actual.X - $X) -gt 2 -or
        [Math]::Abs($actual.Y - $Y) -gt 2) {
        throw "Physical cursor did not reach $Label at ($X,$Y); " +
              "actual=($($actual.X),$($actual.Y))."
    }
}

function Invoke-PhysicalDrag(
    [int]$StartX,
    [int]$StartY,
    [int]$EndX,
    [int]$EndY,
    [IntPtr]$ForegroundWindow,
    [string]$Label,
    [ValidateRange(0, 3000)][int]$HoldBeforeReleaseMilliseconds = 0) {
    Set-ForegroundWindowVerified $ForegroundWindow
    Set-PhysicalCursorPosition $StartX $StartY "$Label-start"
    Start-Sleep -Milliseconds 140
    $pressed = $false
    try {
        if (-not [LumaChartTitleBarGuiNative]::SendMouseButton(
                [LumaChartTitleBarGuiNative]::MouseLeftDown)) {
            throw "SendInput failed for $Label left-button down."
        }
        $pressed = $true
        Start-Sleep -Milliseconds 90
        for ($step = 1; $step -le 12; $step++) {
            $x = [int][Math]::Round(
                $StartX + ($EndX - $StartX) * $step / 12.0)
            $y = [int][Math]::Round(
                $StartY + ($EndY - $StartY) * $step / 12.0)
            Set-PhysicalCursorPosition $x $y "$Label-step-$step"
            Start-Sleep -Milliseconds 20
        }
        if ($HoldBeforeReleaseMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $HoldBeforeReleaseMilliseconds
        }
    }
    finally {
        if ($pressed) {
            if (-not [LumaChartTitleBarGuiNative]::SendMouseButton(
                    [LumaChartTitleBarGuiNative]::MouseLeftUp)) {
                throw "SendInput failed for $Label left-button up."
            }
        }
    }
    Start-Sleep -Milliseconds 320
}

function Invoke-PhysicalElementClick($Element, [IntPtr]$ForegroundWindow, [string]$Label) {
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -le 2 -or $bounds.Height -le 2) {
        throw "Element '$Label' has invalid physical bounds."
    }
    $x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    Set-ForegroundWindowVerified $ForegroundWindow
    Set-PhysicalCursorPosition $x $y "$Label-click"
    Start-Sleep -Milliseconds 120
    if ([LumaChartTitleBarGuiNative]::GetForegroundWindow() -ne $ForegroundWindow) {
        throw "Evidence window lost foreground before '$Label' click."
    }
    if (-not [LumaChartTitleBarGuiNative]::IsWindowAtCursor($ForegroundWindow)) {
        throw "Element '$Label' is obscured at its physical click point ($x,$y)."
    }
    if (-not [LumaChartTitleBarGuiNative]::SendMouseButton(
            [LumaChartTitleBarGuiNative]::MouseLeftDown)) {
        throw "SendInput failed for '$Label' left-button down."
    }
    Start-Sleep -Milliseconds 65
    if (-not [LumaChartTitleBarGuiNative]::SendMouseButton(
            [LumaChartTitleBarGuiNative]::MouseLeftUp)) {
        throw "SendInput failed for '$Label' left-button up."
    }
    Start-Sleep -Milliseconds 180
    return [ordered]@{ x = $x; y = $y }
}

function Invoke-PhysicalDoubleClickAtPoint(
    [int]$X,
    [int]$Y,
    [IntPtr]$ForegroundWindow,
    [string]$Label) {
    Set-ForegroundWindowVerified $ForegroundWindow
    Set-PhysicalCursorPosition $X $Y "$Label-double-click"
    Start-Sleep -Milliseconds 120
    foreach ($click in 1..2) {
        if (-not [LumaChartTitleBarGuiNative]::SendMouseButton(
                [LumaChartTitleBarGuiNative]::MouseLeftDown)) {
            throw "SendInput failed for '$Label' click $click left-button down."
        }
        Start-Sleep -Milliseconds 45
        if (-not [LumaChartTitleBarGuiNative]::SendMouseButton(
                [LumaChartTitleBarGuiNative]::MouseLeftUp)) {
            throw "SendInput failed for '$Label' click $click left-button up."
        }
        if ($click -eq 1) { Start-Sleep -Milliseconds 80 }
    }
    Start-Sleep -Milliseconds 260
    return [ordered]@{ x = $X; y = $Y }
}

function Assert-BoundsNear(
    $Actual,
    $Expected,
    [double]$Tolerance,
    [string]$Label) {
    foreach ($name in @("left", "top", "width", "height")) {
        if ([Math]::Abs(
                [double]$Actual.$name - [double]$Expected.$name) -gt $Tolerance) {
            throw "$Label bounds differ at ${name}: actual=$($Actual.$name), " +
                  "expected=$($Expected.$name), tolerance=$Tolerance."
        }
    }
}

function Get-TitleBarPhysicalDragPoint($Rectangle, [double]$Scale) {
    if (-not [double]::IsFinite($Scale) -or $Scale -le 0) {
        throw "A valid Windows scale is required for the title-bar drag point."
    }
    return [ordered]@{
        x = [int][Math]::Round($Rectangle.Left + 90 * $Scale)
        y = [int][Math]::Round($Rectangle.Top + $Rectangle.Height / 2)
    }
}

function Invoke-ResizeChecked(
    [string]$Name,
    [int]$StartX,
    [int]$StartY,
    [int]$EndX,
    [int]$EndY,
    [IntPtr]$Handle,
    [scriptblock]$Accept,
    [Collections.Generic.List[object]]$Actions) {
    $before = Get-WindowBounds $Handle
    Invoke-PhysicalDrag $StartX $StartY $EndX $EndY $Handle $Name
    $after = Get-WindowBounds $Handle
    if (-not (& $Accept $before $after)) {
        throw "Physical resize '$Name' did not produce the expected bounds: " +
              "before=$($before | ConvertTo-Json -Compress), " +
              "after=$($after | ConvertTo-Json -Compress)."
    }
    $Actions.Add([ordered]@{
        name = $Name
        input = "Win32 SendInput physical mouse drag"
        start = [ordered]@{ x = $StartX; y = $StartY }
        end = [ordered]@{ x = $EndX; y = $EndY }
        before = $before
        after = $after
    })
    return $after
}

function Invoke-UiaElement($Element) {
    $pattern = $Element.GetCurrentPattern(
        [Windows.Automation.InvokePattern]::Pattern)
    if ($null -eq $pattern) {
        throw "UI Automation element '$([string]$Element.Current.AutomationId)' " +
              "does not expose InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
    Start-Sleep -Milliseconds 250
}

function Get-TitleBarAnimationY($TitleElement) {
    $helpText = [string]$TitleElement.Current.HelpText
    $match = [Text.RegularExpressions.Regex]::Match(
        $helpText,
        '(?:^|;)\s*CurrentY=(-?\d+(?:\.\d+)?)(?:;|$)')
    if (-not $match.Success) {
        throw "Title.Chrome HelpText does not expose CurrentY: $helpText"
    }
    return [double]::Parse(
        $match.Groups[1].Value,
        [Globalization.CultureInfo]::InvariantCulture)
}

function Get-TitleBarSnapDiagnostics($TitleElement) {
    $helpText = [string]$TitleElement.Current.HelpText
    $match = [Text.RegularExpressions.Regex]::Match(
        $helpText,
        '(?:^|;)\s*SnapScheduled=(\d+);\s*' +
        'SnapApplied=(\d+);\s*' +
        'SnapNoTarget=(\d+);\s*' +
        'LastSnapOutcome=([^;]+);\s*' +
        'LastSnapPointer=([^;]+)(?:;|$)')
    if (-not $match.Success) {
        throw "Title.Chrome HelpText does not expose window Snap diagnostics: $helpText"
    }
    return [ordered]@{
        scheduled = [int]$match.Groups[1].Value
        applied = [int]$match.Groups[2].Value
        noTarget = [int]$match.Groups[3].Value
        lastOutcome = $match.Groups[4].Value.Trim()
        lastPointer = $match.Groups[5].Value.Trim()
        raw = $helpText
    }
}

function Wait-TitleBarSnapDiagnostics {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][int]$ExpectedScheduled,
        [Parameter(Mandatory = $true)][int]$ExpectedApplied,
        [Parameter(Mandatory = $true)][int]$ExpectedNoTarget,
        [Parameter(Mandatory = $true)][string]$ExpectedOutcome,
        [Parameter(Mandatory = $true)][string]$Description
    )
    $script:observedTitleBarSnapDiagnostics = $null
    Wait-Condition -Description $Description -Condition {
        try {
            $candidate = Find-VisibleElementById `
                -ProcessId $ProcessId `
                -AutomationId "Title.Chrome" `
                -TimeoutMilliseconds 500
            $diagnostics = Get-TitleBarSnapDiagnostics $candidate
            if ($diagnostics.scheduled -eq $ExpectedScheduled -and
                $diagnostics.applied -eq $ExpectedApplied -and
                $diagnostics.noTarget -eq $ExpectedNoTarget -and
                $diagnostics.lastOutcome -ceq $ExpectedOutcome) {
                $script:observedTitleBarSnapDiagnostics = $diagnostics
                return $true
            }
        }
        catch { }
        return $false
    }
    $result = $script:observedTitleBarSnapDiagnostics
    $script:observedTitleBarSnapDiagnostics = $null
    return $result
}

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$chartFullPath = Resolve-ExistingFile $ChartFixturePath "Real MC fixture"
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
if (-not (Test-Path -LiteralPath $outputFullPath -PathType Container)) {
    throw "Output root must already exist: $outputFullPath"
}
if ((Get-ChildItem -LiteralPath $outputFullPath -Force | Measure-Object).Count -ne 0) {
    throw "Output root must be empty: $outputFullPath"
}

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$predecessorGuiEvidencePath = Resolve-ExistingFile `
    (Join-Path $projectRoot `
        "artifacts\windows-avalonia-titlebar-slice-20260727-r2\titlebar-gui\titlebar-gui-evidence.json") `
    "r2 physical title-bar authority"
$predecessorGuiEvidenceHash =
    (Get-FileHash -LiteralPath $predecessorGuiEvidencePath -Algorithm SHA256).Hash
if ($predecessorGuiEvidenceHash -cne
    "95ACA55697D840D500B446A45C2CAF3EDCE00EA96E2E1F7D4E420F5FA21689F4") {
    throw "The r2 physical title-bar authority hash changed."
}
$dotnetHome = Join-Path $projectRoot ".dotnet-home"
$nugetPackages = Join-Path $projectRoot ".nuget\packages"
$nugetHttpCache = Join-Path $projectRoot ".nuget\http-cache"
$projectTemp = Join-Path $outputFullPath "temp"
$sessionRoot = Join-Path $outputFullPath "session"
$localDataRoot = Join-Path $sessionRoot "local-data"
$editingRoot = Join-Path $sessionRoot "editing"
$workspaceRoot = Join-Path $sessionRoot "workspace"
foreach ($directory in @(
        $dotnetHome,
        $nugetPackages,
        $nugetHttpCache,
        $projectTemp,
        $localDataRoot,
        $editingRoot,
        $workspaceRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$runtimePath = Join-Path $outputFullPath "titlebar-runtime.json"
$windowedPath = Join-Path $outputFullPath "titlebar-windowed.png"
$rightResizePath = Join-Path $outputFullPath "window-resize-right-edge.png"
$minimumResizePath = Join-Path $outputFullPath "window-resize-minimum.png"
$resizeRestoredPath = Join-Path $outputFullPath "window-resize-restored.png"
$captionButtonMaximizedPath =
    Join-Path $outputFullPath "caption-button-maximized.png"
$captionButtonRestoredPath =
    Join-Path $outputFullPath "caption-button-restored.png"
$captionDoubleMaximizedPath =
    Join-Path $outputFullPath "caption-double-click-maximized.png"
$captionDoubleRestoredPath =
    Join-Path $outputFullPath "caption-double-click-restored.png"
$captionDraggedPath = Join-Path $outputFullPath "caption-window-dragged.png"
$captionDragRestoredPath =
    Join-Path $outputFullPath "caption-window-drag-restored.png"
$moveMaximizedPath = Join-Path $outputFullPath "window-move-maximized.png"
$moveRestoredFromMaximizedPath =
    Join-Path $outputFullPath "window-move-restored-from-maximized.png"
$moveSnappedTopPath = Join-Path $outputFullPath "window-move-snapped-top.png"
$moveRestoredFromTopPath =
    Join-Path $outputFullPath "window-move-restored-from-top.png"
$moveSnappedLeftPath = Join-Path $outputFullPath "window-move-snapped-left.png"
$moveUnsnappedLeftPath = Join-Path $outputFullPath "window-move-unsnapped-left.png"
$moveSnappedRightPath = Join-Path $outputFullPath "window-move-snapped-right.png"
$moveUnsnappedRightPath = Join-Path $outputFullPath "window-move-unsnapped-right.png"
$maximizedPath = Join-Path $outputFullPath "titlebar-maximized.png"
$fullscreenHiddenPath = Join-Path $outputFullPath "titlebar-fullscreen-hidden.png"
$fullscreenRevealedPath = Join-Path $outputFullPath "titlebar-fullscreen-revealed.png"
$restoredPath = Join-Path $outputFullPath "titlebar-restored.png"
$evidencePath = Join-Path $outputFullPath "titlebar-gui-evidence.json"
$fixtureHashBefore = (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
$installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$installerHashBefore = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
$process = $null

try {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $applicationFullPath
    $start.UseShellExecute = $false
    $start.WorkingDirectory = Split-Path -Parent $applicationFullPath
    $start.ArgumentList.Add("--evidence-chart")
    $start.ArgumentList.Add($chartFullPath)
    $start.ArgumentList.Add("--evidence-output")
    $start.ArgumentList.Add($runtimePath)
    $start.ArgumentList.Add("--evidence-focus-note-property")
    $start.ArgumentList.Add("--evidence-focus-titlebar-animation")
    $start.Environment["LUMACHART_PROFILE"] = "titlebar-parity"
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceRoot
    $start.Environment["DOTNET_CLI_HOME"] = $dotnetHome
    $start.Environment["NUGET_PACKAGES"] = $nugetPackages
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
    $start.Environment["TEMP"] = $projectTemp
    $start.Environment["TMP"] = $projectTemp
    $process = [Diagnostics.Process]::Start($start)
    if (-not $process) { throw "Unable to start Windows Avalonia title-bar client." }

    Wait-Condition -Description "title-bar main window" -Condition {
        $process.Refresh()
        -not $process.HasExited -and $process.MainWindowHandle -ne [IntPtr]::Zero
    }
    $handle = $process.MainWindowHandle
    $startupFocusElement = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Timeline.Surface"
    $startupFocusElement.SetFocus()
    Start-Sleep -Milliseconds 160
    $process.Refresh()
    if ($process.HasExited -or $process.MainWindowHandle -eq [IntPtr]::Zero) {
        throw "Windows Avalonia title-bar client lost its main window during startup focus setup."
    }
    $handle = $process.MainWindowHandle
    Set-ForegroundWindowVerified $handle
    $title = Find-ElementById -ProcessId $process.Id -AutomationId "Title.Chrome"
    $formatBadge = Find-ElementByName -ProcessId $process.Id -Name "MALODY"
    $chartTab = Find-ElementById -ProcessId $process.Id -AutomationId "Editor.ChartTab"
    $maximizeButton = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Title.MaximizeRestore"

    $windowedBounds = Get-WindowBounds $handle
    $windowedTitleRectangle = $title.Current.BoundingRectangle
    $windowScaleX = [double]$windowedBounds.width / 1320
    $windowScaleY = [double]$windowedBounds.height / 800
    if ([Math]::Abs($windowScaleX - $windowScaleY) -gt .03 -or
        $windowScaleX -lt .75 -or $windowScaleX -gt 3) {
        throw "Windowed bounds did not expose a stable Windows DPI scale: " +
              "$($windowedBounds | ConvertTo-Json -Compress)."
    }
    if ([Math]::Abs($windowedTitleRectangle.Height / $windowScaleY - 38) -gt 1.25) {
        throw "Windowed title bar is not 38 DIP at the active Windows scale: " +
              "$(Convert-Rectangle $windowedTitleRectangle | ConvertTo-Json -Compress)."
    }
    $titleContract = [string]$title.Current.HelpText
    if ($titleContract -notlike "Contract=wpf-1.1.0-titlebar-r1*" -or
        $titleContract -notlike "*Reveal=145; Hide=125; Easing=CubicOut/CubicIn*") {
        throw "Title-bar UIA contract is missing or stale."
    }
    $script:stableCloseTab = $null
    $script:stableCloseTabPhysicalWidth = 0.0
    Wait-Condition -Description "stable visible 25 DIP document-tab close button" -Condition {
        $candidate = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.ChartTab.Close" `
            -TimeoutMilliseconds 500
        $physicalWidth = [double]$candidate.Current.BoundingRectangle.Width
        if ([double]::IsFinite($physicalWidth) -and
            [Math]::Abs($physicalWidth / $windowScaleX - 25) -le 1.25) {
            $script:stableCloseTab = $candidate
            $script:stableCloseTabPhysicalWidth = $physicalWidth
            return $true
        }
        return $false
    }
    $closeTab = $script:stableCloseTab
    $tabClosePhysicalWidth = $script:stableCloseTabPhysicalWidth
    $script:stableCloseTab = $null
    $script:stableCloseTabPhysicalWidth = 0.0
    if ([string]$formatBadge.Current.Name -cne "MALODY" -or
        [string]$chartTab.Current.Name -notlike "谱面标签 Resound*") {
        throw "WPF-style format badge or document-tab name was not materialized."
    }
    $formatBadgeName = [string]$formatBadge.Current.Name
    $chartTabName = [string]$chartTab.Current.Name
    $windowedCapture = Capture-Window $handle $windowedPath

    if ($CaptionOnly) {
        $captionActions = [Collections.Generic.List[object]]::new()
        $initialCaptionBounds = Get-WindowBounds $handle
        $saveStateBeforeElement = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.SaveState"
        $saveStateBeforeCaptionActions =
            [string]$saveStateBeforeElement.Current.Name
        if ($saveStateBeforeCaptionActions -cne "· 已保存") {
            throw "Chart session was dirty before caption actions: " +
                  "'$saveStateBeforeCaptionActions'."
        }

        $timeline = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Timeline.Surface"
        $timeline.SetFocus()
        Wait-Condition -Description "timeline focus before caption actions" -Condition {
            [bool]$timeline.Current.HasKeyboardFocus
        }

        $minimize = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Minimize"
        $minimizePoint =
            Invoke-PhysicalElementClick $minimize $handle "caption-minimize"
        Wait-Condition -Description "physical caption minimize" -Condition {
            [LumaChartTitleBarGuiNative]::IsIconic($handle)
        }
        $captionActions.Add([ordered]@{
            name = "caption-minimize"
            input = "Win32 SendInput physical mouse click"
            point = $minimizePoint
            before = $initialCaptionBounds
            isIconicAfter = $true
        })

        [void][LumaChartTitleBarGuiNative]::ShowWindowAsync($handle, 9)
        Wait-Condition -Description "native restore after minimize" -Condition {
            -not [LumaChartTitleBarGuiNative]::IsIconic($handle)
        }
        Set-ForegroundWindowVerified $handle
        $restoredAfterMinimizeBounds = Get-WindowBounds $handle
        Assert-BoundsNear `
            $restoredAfterMinimizeBounds `
            $initialCaptionBounds `
            10 `
            "native restore after physical minimize"

        $maximize = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.MaximizeRestore"
        $maximizePoint =
            Invoke-PhysicalElementClick $maximize $handle "caption-maximize"
        Wait-Condition -Description "physical caption maximize" -Condition {
            [LumaChartTitleBarGuiNative]::IsZoomed($handle)
        }
        $captionButtonMaximizedBounds = Get-WindowBounds $handle
        if ($captionButtonMaximizedBounds.width -le
                $initialCaptionBounds.width + 200 -or
            $captionButtonMaximizedBounds.height -le
                $initialCaptionBounds.height + 200) {
            throw "Physical maximize did not expand to the Windows work area."
        }
        $captionActions.Add([ordered]@{
            name = "caption-maximize"
            input = "Win32 SendInput physical mouse click"
            point = $maximizePoint
            before = $restoredAfterMinimizeBounds
            after = $captionButtonMaximizedBounds
            isZoomedAfter = $true
        })
        $captionButtonMaximizedCapture =
            Capture-Window $handle $captionButtonMaximizedPath

        $restore = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.MaximizeRestore"
        $restorePoint =
            Invoke-PhysicalElementClick $restore $handle "caption-restore"
        Wait-Condition -Description "physical caption restore" -Condition {
            -not [LumaChartTitleBarGuiNative]::IsZoomed($handle)
        }
        $captionButtonRestoredBounds = Get-WindowBounds $handle
        Assert-BoundsNear `
            $captionButtonRestoredBounds `
            $initialCaptionBounds `
            10 `
            "physical caption restore"
        $captionActions.Add([ordered]@{
            name = "caption-restore"
            input = "Win32 SendInput physical mouse click"
            point = $restorePoint
            before = $captionButtonMaximizedBounds
            after = $captionButtonRestoredBounds
            isZoomedAfter = $false
        })
        $captionButtonRestoredCapture =
            Capture-Window $handle $captionButtonRestoredPath

        $title = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Chrome"
        $normalTitleRectangle = $title.Current.BoundingRectangle
        $normalBlankPoint =
            Get-TitleBarPhysicalDragPoint $normalTitleRectangle $windowScaleX
        $normalBlankX = $normalBlankPoint.x
        $normalBlankY = $normalBlankPoint.y
        $doubleMaximizePoint = Invoke-PhysicalDoubleClickAtPoint `
            $normalBlankX `
            $normalBlankY `
            $handle `
            "titlebar-double-click-maximize"
        Wait-Condition -Description "physical title-bar double-click maximize" -Condition {
            [LumaChartTitleBarGuiNative]::IsZoomed($handle)
        }
        $captionDoubleMaximizedBounds = Get-WindowBounds $handle
        $captionActions.Add([ordered]@{
            name = "titlebar-double-click-maximize"
            input = "Win32 SendInput physical mouse double-click"
            point = $doubleMaximizePoint
            before = $captionButtonRestoredBounds
            after = $captionDoubleMaximizedBounds
            isZoomedAfter = $true
        })
        $captionDoubleMaximizedCapture =
            Capture-Window $handle $captionDoubleMaximizedPath

        $title = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Chrome"
        $maximizedTitleRectangle = $title.Current.BoundingRectangle
        $maximizedBlankPoint =
            Get-TitleBarPhysicalDragPoint $maximizedTitleRectangle $windowScaleX
        $maximizedBlankX = $maximizedBlankPoint.x
        $maximizedBlankY = $maximizedBlankPoint.y
        $doubleRestorePoint = Invoke-PhysicalDoubleClickAtPoint `
            $maximizedBlankX `
            $maximizedBlankY `
            $handle `
            "titlebar-double-click-restore"
        Wait-Condition -Description "physical title-bar double-click restore" -Condition {
            -not [LumaChartTitleBarGuiNative]::IsZoomed($handle)
        }
        $captionDoubleRestoredBounds = Get-WindowBounds $handle
        Assert-BoundsNear `
            $captionDoubleRestoredBounds `
            $initialCaptionBounds `
            10 `
            "physical title-bar double-click restore"
        $captionActions.Add([ordered]@{
            name = "titlebar-double-click-restore"
            input = "Win32 SendInput physical mouse double-click"
            point = $doubleRestorePoint
            before = $captionDoubleMaximizedBounds
            after = $captionDoubleRestoredBounds
            isZoomedAfter = $false
        })
        $captionDoubleRestoredCapture =
            Capture-Window $handle $captionDoubleRestoredPath

        $timeline = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Timeline.Surface"
        $timeline.SetFocus()
        Wait-Condition -Description "timeline focus before native window drag" -Condition {
            [bool]$timeline.Current.HasKeyboardFocus
        }
        $timelineFocusedBeforeWindowDrag =
            [bool]$timeline.Current.HasKeyboardFocus

        $title = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Chrome"
        $dragTitleRectangle = $title.Current.BoundingRectangle
        $dragStartPoint =
            Get-TitleBarPhysicalDragPoint $dragTitleRectangle $windowScaleX
        $dragStartX = $dragStartPoint.x
        $dragStartY = $dragStartPoint.y
        $dragDeltaX = [int][Math]::Round(120 * $windowScaleX)
        $dragDeltaY = [int][Math]::Round(80 * $windowScaleY)
        Invoke-PhysicalDrag `
            $dragStartX `
            $dragStartY `
            ($dragStartX + $dragDeltaX) `
            ($dragStartY + $dragDeltaY) `
            $handle `
            "titlebar-window-drag"
        $captionDraggedBounds = Get-WindowBounds $handle
        if ([Math]::Abs(
                $captionDraggedBounds.left -
                $initialCaptionBounds.left -
                $dragDeltaX) -gt 12 -or
            [Math]::Abs(
                $captionDraggedBounds.top -
                $initialCaptionBounds.top -
                $dragDeltaY) -gt 12 -or
            $captionDraggedBounds.width -ne $initialCaptionBounds.width -or
            $captionDraggedBounds.height -ne $initialCaptionBounds.height) {
            throw "Physical title-bar drag did not move the normal window exactly."
        }
        $captionActions.Add([ordered]@{
            name = "titlebar-window-drag"
            input = "Win32 SendInput physical mouse drag"
            start = [ordered]@{ x = $dragStartX; y = $dragStartY }
            end = [ordered]@{
                x = $dragStartX + $dragDeltaX
                y = $dragStartY + $dragDeltaY
            }
            before = $captionDoubleRestoredBounds
            after = $captionDraggedBounds
        })
        $captionDraggedCapture = Capture-Window $handle $captionDraggedPath

        $actualDragX =
            [int]$captionDraggedBounds.left - [int]$initialCaptionBounds.left
        $actualDragY =
            [int]$captionDraggedBounds.top - [int]$initialCaptionBounds.top
        Invoke-PhysicalDrag `
            ($dragStartX + $actualDragX) `
            ($dragStartY + $actualDragY) `
            $dragStartX `
            $dragStartY `
            $handle `
            "titlebar-window-drag-restore"
        $captionDragRestoredBounds = Get-WindowBounds $handle
        Assert-BoundsNear `
            $captionDragRestoredBounds `
            $initialCaptionBounds `
            10 `
            "physical title-bar drag restore"
        $captionActions.Add([ordered]@{
            name = "titlebar-window-drag-restore"
            input = "Win32 SendInput physical mouse drag"
            start = [ordered]@{
                x = $dragStartX + $actualDragX
                y = $dragStartY + $actualDragY
            }
            end = [ordered]@{ x = $dragStartX; y = $dragStartY }
            before = $captionDraggedBounds
            after = $captionDragRestoredBounds
        })

        $timeline = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Timeline.Surface"
        $timelineFocusedAfterWindowDrag =
            [bool]$timeline.Current.HasKeyboardFocus
        if (-not $timelineFocusedAfterWindowDrag) {
            throw "Timeline focus was lost during native title-bar move drag."
        }
        $saveStateAfterElement = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.SaveState"
        $saveStateAfterCaptionActions =
            [string]$saveStateAfterElement.Current.Name
        if ($saveStateAfterCaptionActions -cne "· 已保存") {
            throw "Caption actions mutated the chart session: " +
                  "'$saveStateAfterCaptionActions'."
        }
        $captionDragRestoredCapture =
            Capture-Window $handle $captionDragRestoredPath

        $close = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Close"
        $closePoint = Invoke-PhysicalElementClick $close $handle "caption-close"
        $captionActions.Add([ordered]@{
            name = "caption-close"
            input = "Win32 SendInput physical mouse click"
            point = $closePoint
            before = $captionDragRestoredBounds
        })
        Wait-Condition -Description "physical clean caption close" -Condition {
            $process.Refresh()
            $process.HasExited
        }
        if ($captionActions.Count -ne 8) {
            throw "Expected exactly 8 physical caption actions, got " +
                  "$($captionActions.Count)."
        }

        $fixtureHashAfter =
            (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
        $installerHashAfter =
            (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
        if ($fixtureHashAfter -cne $fixtureHashBefore) {
            throw "Real MC fixture changed during caption GUI acceptance."
        }
        if ($installerHashAfter -cne $installerHashBefore) {
            throw "Frozen WPF installer changed during caption GUI acceptance."
        }

        $predecessorVerificationPath = Resolve-ExistingFile `
            (Join-Path $projectRoot (
                "artifacts\windows-avalonia-window-resize-slice-20260727-r1\" +
                "verification-evidence.json")) `
            "window-resize r1 formal authority"
        $predecessorVerificationHash =
            (Get-FileHash -LiteralPath $predecessorVerificationPath `
                -Algorithm SHA256).Hash
        if ($predecessorVerificationHash -cne
            "0050566EBC54E0FF74BA1FBF3EC72B111BE451C21C2CD8743AE426D33DC3AD1C") {
            throw "The window-resize r1 formal authority hash changed."
        }

        $screenshots = [ordered]@{}
        foreach ($path in @(
                $windowedPath,
                $captionButtonMaximizedPath,
                $captionButtonRestoredPath,
                $captionDoubleMaximizedPath,
                $captionDoubleRestoredPath,
                $captionDraggedPath,
                $captionDragRestoredPath)) {
            $item = Get-Item -LiteralPath $path
            $screenshots[$item.BaseName] = [ordered]@{
                path = $item.FullName
                length = $item.Length
                sha256 =
                    (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
            }
        }
        $evidence = [ordered]@{
            schema =
                "lumachart.windows.avalonia.caption-lifecycle-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed-migration-incomplete"
            windowsAvaloniaOnly = $true
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            productionServerMutationPerformed = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            contract = "wpf-1.1.0-titlebar-r1"
            processId = $process.Id
            predecessor = [ordered]@{
                path = $predecessorVerificationPath
                sha256 = $predecessorVerificationHash
            }
            currentSliceInput = [ordered]@{
                physicalMouseInputUsed = $true
                physicalActionCount = $captionActions.Count
                physicalClickCount = 4
                physicalDoubleClickCount = 2
                physicalDragCount = 2
                nativeRestoreAfterMinimizeUsedAsSetup = $true
                keyboardInjectionUsed =
                    [LumaChartTitleBarGuiNative]::ForegroundActivationAltPulseCount -gt 0
                foregroundActivationAltPulseCount =
                    [LumaChartTitleBarGuiNative]::ForegroundActivationAltPulseCount
                foregroundActivationMouseClickCount =
                    [LumaChartTitleBarGuiNative]::ForegroundActivationMouseClickCount
                hardwareInputClaimed = $false
            }
            chrome = [ordered]@{
                titleBarHeight = 38
                captionButtonWidth = 46
                windowScale = $windowScaleX
                formatBadge = $formatBadgeName
                documentTab = $chartTabName
            }
            captionLifecycle = [ordered]@{
                initialBounds = $initialCaptionBounds
                physicalMinimizePassed = $true
                nativeRestoreAfterMinimizeBounds = $restoredAfterMinimizeBounds
                captionButtonMaximizedBounds = $captionButtonMaximizedBounds
                captionButtonRestoredBounds = $captionButtonRestoredBounds
                doubleClickMaximizedBounds = $captionDoubleMaximizedBounds
                doubleClickRestoredBounds = $captionDoubleRestoredBounds
                draggedBounds = $captionDraggedBounds
                dragRestoredBounds = $captionDragRestoredBounds
                physicalCloseExitedProcess = $true
                saveStateBefore = $saveStateBeforeCaptionActions
                saveStateAfter = $saveStateAfterCaptionActions
                sessionCleanBeforeAndAfter = $true
                timelineFocusedBeforeWindowDrag =
                    $timelineFocusedBeforeWindowDrag
                timelineFocusedAfterWindowDrag =
                    $timelineFocusedAfterWindowDrag
                actions = $captionActions
                passed = $true
            }
            source = [ordered]@{
                path = $chartFullPath
                sha256Before = $fixtureHashBefore
                sha256After = $fixtureHashAfter
                unchanged = $true
            }
            frozenInstaller = [ordered]@{
                path = $installerPath
                sha256Before = $installerHashBefore
                sha256After = $installerHashAfter
                unchanged = $true
            }
            captures = [ordered]@{
                windowed = $windowedCapture
                captionButtonMaximized = $captionButtonMaximizedCapture
                captionButtonRestored = $captionButtonRestoredCapture
                doubleClickMaximized = $captionDoubleMaximizedCapture
                doubleClickRestored = $captionDoubleRestoredCapture
                dragged = $captionDraggedCapture
                dragRestored = $captionDragRestoredCapture
            }
            screenshots = $screenshots
            completion = [ordered]@{
                captionLifecycleSlicePassed = $true
                windowsAvaloniaOneToOneComplete = $false
                userReplacementApprovalReceived = $false
                nextPlatformAuthorized = $false
            }
            remainingDifferences = @(
                "Maximized drag-restore, Windows Snap, multi-screen and all DPI combinations remain open.",
                "Remaining focus/IME, online, format, ClientSecurity, installer and physical performance gates remain open.")
        }
        $evidence | ConvertTo-Json -Depth 18 |
            Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
        Write-Host "Windows Avalonia caption lifecycle GUI capture: passed"
        Write-Host "Evidence: $evidencePath"
        return
    }

    if ($WindowMoveOnly) {
        if (-not [LumaChartTitleBarGuiNative]::SendTitleBarActivationClick(
                $handle)) {
            throw "Physical title-bar activation preflight click failed."
        }
        $windowMoveActivationPreflightClicks = 1
        Start-Sleep -Milliseconds 420
        Set-ForegroundWindowVerified $handle

        $moveActions = [Collections.Generic.List[object]]::new()
        $initialMoveBounds = Get-WindowBounds $handle
        $saveStateBeforeElement = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.SaveState"
        $saveStateBeforeMoveActions =
            [string]$saveStateBeforeElement.Current.Name
        if ($saveStateBeforeMoveActions -cne "· 已保存") {
            throw "Chart session was dirty before native move/Snap actions: " +
                  "'$saveStateBeforeMoveActions'."
        }

        $timeline = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Timeline.Surface"
        $timeline.SetFocus()
        Wait-Condition -Description "timeline focus before native move/Snap actions" -Condition {
            [bool]$timeline.Current.HasKeyboardFocus
        }
        $timelineFocusedBeforeMoveActions =
            [bool]$timeline.Current.HasKeyboardFocus
        $title = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Chrome"
        $snapDiagnosticsBaseline = Get-TitleBarSnapDiagnostics $title

        $maximize = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.MaximizeRestore"
        $maximizePoint =
            Invoke-PhysicalElementClick $maximize $handle "window-move-maximize"
        Wait-Condition -Description "maximize before drag-restore" -Condition {
            [LumaChartTitleBarGuiNative]::IsZoomed($handle)
        }
        $moveMaximizedBounds = Get-WindowBounds $handle
        $moveActions.Add([ordered]@{
            name = "caption-maximize-before-drag"
            input = "Win32 SendInput physical mouse click"
            point = $maximizePoint
            before = $initialMoveBounds
            after = $moveMaximizedBounds
            isZoomedAfter = $true
        })
        $moveMaximizedCapture = Capture-Window $handle $moveMaximizedPath

        $title = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Chrome"
        $maxTitleRectangle = $title.Current.BoundingRectangle
        $maxDragStartPoint =
            Get-TitleBarPhysicalDragPoint $maxTitleRectangle $windowScaleX
        $maxDragStartX = $maxDragStartPoint.x
        $maxDragStartY = $maxDragStartPoint.y
        $maxDragEndX = [int][Math]::Round($moveMaximizedBounds.width * .57)
        $maxDragEndY = [int][Math]::Round(210 * $windowScaleY)
        Invoke-PhysicalDrag `
            $maxDragStartX `
            $maxDragStartY `
            $maxDragEndX `
            $maxDragEndY `
            $handle `
            "maximized-titlebar-drag-restore"
        Wait-Condition -Description "maximized title-bar drag restore" -Condition {
            -not [LumaChartTitleBarGuiNative]::IsZoomed($handle)
        }
        $snapAfterMaximizedRestore = Wait-TitleBarSnapDiagnostics `
            -ProcessId $process.Id `
            -ExpectedScheduled ($snapDiagnosticsBaseline.scheduled + 1) `
            -ExpectedApplied ($snapDiagnosticsBaseline.applied + 1) `
            -ExpectedNoTarget ($snapDiagnosticsBaseline.noTarget + 1) `
            -ExpectedOutcome "None" `
            -Description "Snap diagnostics after maximized title-bar drag restore"
        $restoredFromMaximizedBounds = Get-WindowBounds $handle
        if ([Math]::Abs(
                $restoredFromMaximizedBounds.width -
                $initialMoveBounds.width) -gt 12 -or
            [Math]::Abs(
                $restoredFromMaximizedBounds.height -
                $initialMoveBounds.height) -gt 12 -or
            $restoredFromMaximizedBounds.top -le 0) {
            throw "Maximized title-bar drag did not restore the WPF normal size."
        }
        $moveActions.Add([ordered]@{
            name = "maximized-titlebar-drag-restore"
            input = "Win32 SendInput physical mouse drag"
            start = [ordered]@{ x = $maxDragStartX; y = $maxDragStartY }
            end = [ordered]@{ x = $maxDragEndX; y = $maxDragEndY }
            before = $moveMaximizedBounds
            after = $restoredFromMaximizedBounds
            isZoomedAfter = $false
            snapDiagnostics = $snapAfterMaximizedRestore
        })
        $moveRestoredFromMaximizedCapture =
            Capture-Window $handle $moveRestoredFromMaximizedPath

        $title = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Chrome"
        $topSnapTitleRectangle = $title.Current.BoundingRectangle
        $topSnapStartPoint =
            Get-TitleBarPhysicalDragPoint $topSnapTitleRectangle $windowScaleX
        $topSnapStartX = $topSnapStartPoint.x
        $topSnapStartY = $topSnapStartPoint.y
        $topSnapEndX = [int][Math]::Round($moveMaximizedBounds.width * .5)
        $topSnapEndY = [int]$moveMaximizedBounds.top
        Invoke-PhysicalDrag `
            $topSnapStartX `
            $topSnapStartY `
            $topSnapEndX `
            $topSnapEndY `
            $handle `
            "titlebar-snap-top-maximize" `
            850
        Wait-Condition -Description "physical Windows top Snap maximize" -Condition {
            [LumaChartTitleBarGuiNative]::IsZoomed($handle)
        }
        $snapAfterTopMaximize = Wait-TitleBarSnapDiagnostics `
            -ProcessId $process.Id `
            -ExpectedScheduled ($snapDiagnosticsBaseline.scheduled + 2) `
            -ExpectedApplied ($snapDiagnosticsBaseline.applied + 2) `
            -ExpectedNoTarget ($snapDiagnosticsBaseline.noTarget + 1) `
            -ExpectedOutcome "Maximize" `
            -Description "Snap diagnostics after physical top-edge maximize"
        $topSnappedBounds = Get-WindowBounds $handle
        Assert-BoundsNear `
            $topSnappedBounds `
            $moveMaximizedBounds `
            4 `
            "physical top-edge maximize"
        $moveActions.Add([ordered]@{
            name = "titlebar-snap-top-maximize"
            input = "Win32 SendInput physical mouse drag"
            start = [ordered]@{ x = $topSnapStartX; y = $topSnapStartY }
            end = [ordered]@{ x = $topSnapEndX; y = $topSnapEndY }
            before = $restoredFromMaximizedBounds
            after = $topSnappedBounds
            isZoomedAfter = $true
            snapDiagnostics = $snapAfterTopMaximize
        })
        $moveSnappedTopCapture =
            Capture-Window $handle $moveSnappedTopPath

        $title = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Chrome"
        $topRestoreTitleRectangle = $title.Current.BoundingRectangle
        $topRestoreStartPoint =
            Get-TitleBarPhysicalDragPoint $topRestoreTitleRectangle $windowScaleX
        $topRestoreStartX = $topRestoreStartPoint.x
        $topRestoreStartY = $topRestoreStartPoint.y
        $topRestoreEndX = [int][Math]::Round($moveMaximizedBounds.width * .57)
        $topRestoreEndY = [int][Math]::Round(210 * $windowScaleY)
        Invoke-PhysicalDrag `
            $topRestoreStartX `
            $topRestoreStartY `
            $topRestoreEndX `
            $topRestoreEndY `
            $handle `
            "top-snapped-titlebar-drag-restore"
        Wait-Condition -Description "top-snapped title-bar drag restore" -Condition {
            -not [LumaChartTitleBarGuiNative]::IsZoomed($handle)
        }
        $snapAfterTopRestore = Wait-TitleBarSnapDiagnostics `
            -ProcessId $process.Id `
            -ExpectedScheduled ($snapDiagnosticsBaseline.scheduled + 3) `
            -ExpectedApplied ($snapDiagnosticsBaseline.applied + 3) `
            -ExpectedNoTarget ($snapDiagnosticsBaseline.noTarget + 2) `
            -ExpectedOutcome "None" `
            -Description "Snap diagnostics after top-snapped drag restore"
        $restoredFromTopBounds = Get-WindowBounds $handle
        if ([Math]::Abs(
                $restoredFromTopBounds.width -
                $initialMoveBounds.width) -gt 12 -or
            [Math]::Abs(
                $restoredFromTopBounds.height -
                $initialMoveBounds.height) -gt 12 -or
            $restoredFromTopBounds.top -le 0) {
            throw "Top-snapped title-bar drag did not restore the WPF normal size."
        }
        $moveActions.Add([ordered]@{
            name = "top-snapped-titlebar-drag-restore"
            input = "Win32 SendInput physical mouse drag"
            start = [ordered]@{ x = $topRestoreStartX; y = $topRestoreStartY }
            end = [ordered]@{ x = $topRestoreEndX; y = $topRestoreEndY }
            before = $topSnappedBounds
            after = $restoredFromTopBounds
            isZoomedAfter = $false
            snapDiagnostics = $snapAfterTopRestore
        })
        $moveRestoredFromTopCapture =
            Capture-Window $handle $moveRestoredFromTopPath

        $title = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Chrome"
        $normalTitleRectangle = $title.Current.BoundingRectangle
        $leftSnapStartPoint =
            Get-TitleBarPhysicalDragPoint $normalTitleRectangle $windowScaleX
        $leftSnapStartX = $leftSnapStartPoint.x
        $leftSnapStartY = $leftSnapStartPoint.y
        $leftSnapEndX = 0
        $leftSnapEndY = [int][Math]::Round(160 * $windowScaleY)
        $expectedSnapWidth = [int][Math]::Min(
            $moveMaximizedBounds.width,
            [Math]::Max(
                [Math]::Ceiling($moveMaximizedBounds.width / 2.0),
                [Math]::Round(1080 * $windowScaleX)))
        $expectedLeftSnapBounds = [ordered]@{
            left = $moveMaximizedBounds.left
            top = $moveMaximizedBounds.top
            right = $moveMaximizedBounds.left + $expectedSnapWidth
            bottom = $moveMaximizedBounds.bottom
            width = $expectedSnapWidth
            height = $moveMaximizedBounds.height
        }
        $expectedRightSnapBounds = [ordered]@{
            left = $moveMaximizedBounds.right - $expectedSnapWidth
            top = $moveMaximizedBounds.top
            right = $moveMaximizedBounds.right
            bottom = $moveMaximizedBounds.bottom
            width = $expectedSnapWidth
            height = $moveMaximizedBounds.height
        }
        Invoke-PhysicalDrag `
            $leftSnapStartX `
            $leftSnapStartY `
            $leftSnapEndX `
            $leftSnapEndY `
            $handle `
            "titlebar-snap-left" `
            850
        Wait-Condition -Description "physical Windows left Snap" -Condition {
            $bounds = Get-WindowBounds $handle
            $bounds.left -le 2 -and
            $bounds.top -le 2 -and
            $bounds.width -lt $moveMaximizedBounds.width -and
            $bounds.height -ge $moveMaximizedBounds.height - 4
        }
        $snapAfterLeft = Wait-TitleBarSnapDiagnostics `
            -ProcessId $process.Id `
            -ExpectedScheduled ($snapDiagnosticsBaseline.scheduled + 4) `
            -ExpectedApplied ($snapDiagnosticsBaseline.applied + 4) `
            -ExpectedNoTarget ($snapDiagnosticsBaseline.noTarget + 2) `
            -ExpectedOutcome "Left" `
            -Description "Snap diagnostics after physical left Snap"
        $snappedLeftBounds = Get-WindowBounds $handle
        Assert-BoundsNear `
            $snappedLeftBounds `
            $expectedLeftSnapBounds `
            4 `
            "physical left Snap placement"
        if ([LumaChartTitleBarGuiNative]::IsZoomed($handle)) {
            throw "Left Snap incorrectly reported a maximized window."
        }
        $moveActions.Add([ordered]@{
            name = "titlebar-snap-left"
            input = "Win32 SendInput physical mouse drag"
            start = [ordered]@{ x = $leftSnapStartX; y = $leftSnapStartY }
            end = [ordered]@{ x = $leftSnapEndX; y = $leftSnapEndY }
            before = $restoredFromTopBounds
            after = $snappedLeftBounds
            isZoomedAfter = $false
            snapDiagnostics = $snapAfterLeft
        })
        $moveSnappedLeftCapture =
            Capture-Window $handle $moveSnappedLeftPath

        $title = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Chrome"
        $leftTitleRectangle = $title.Current.BoundingRectangle
        $leftUnSnapStartPoint =
            Get-TitleBarPhysicalDragPoint $leftTitleRectangle $windowScaleX
        $leftUnSnapStartX = $leftUnSnapStartPoint.x
        $leftUnSnapStartY = $leftUnSnapStartPoint.y
        $leftUnSnapEndX = [int][Math]::Round($moveMaximizedBounds.width * .5)
        $leftUnSnapEndY = [int][Math]::Round(170 * $windowScaleY)
        Invoke-PhysicalDrag `
            $leftUnSnapStartX `
            $leftUnSnapStartY `
            $leftUnSnapEndX `
            $leftUnSnapEndY `
            $handle `
            "titlebar-unsnap-left"
        $snapAfterLeftRestore = Wait-TitleBarSnapDiagnostics `
            -ProcessId $process.Id `
            -ExpectedScheduled ($snapDiagnosticsBaseline.scheduled + 5) `
            -ExpectedApplied ($snapDiagnosticsBaseline.applied + 5) `
            -ExpectedNoTarget ($snapDiagnosticsBaseline.noTarget + 3) `
            -ExpectedOutcome "None" `
            -Description "Snap diagnostics after dragging away from left Snap"
        Wait-Condition `
            -Description "normal bounds after dragging away from left Snap" `
            -Condition {
                $bounds = Get-WindowBounds $handle
                [Math]::Abs(
                    $bounds.width - $initialMoveBounds.width) -le 12 -and
                [Math]::Abs(
                    $bounds.height - $initialMoveBounds.height) -le 12 -and
                $bounds.left -gt 2
            }
        $unsnappedLeftBounds = Get-WindowBounds $handle
        if ([Math]::Abs(
                $unsnappedLeftBounds.width -
                $initialMoveBounds.width) -gt 12 -or
            [Math]::Abs(
                $unsnappedLeftBounds.height -
                $initialMoveBounds.height) -gt 12 -or
            $unsnappedLeftBounds.left -le 2) {
            throw "Dragging away from the left Snap zone did not restore normal size."
        }
        $moveActions.Add([ordered]@{
            name = "titlebar-unsnap-left"
            input = "Win32 SendInput physical mouse drag"
            start = [ordered]@{ x = $leftUnSnapStartX; y = $leftUnSnapStartY }
            end = [ordered]@{ x = $leftUnSnapEndX; y = $leftUnSnapEndY }
            before = $snappedLeftBounds
            after = $unsnappedLeftBounds
            snapDiagnostics = $snapAfterLeftRestore
        })
        $moveUnsnappedLeftCapture =
            Capture-Window $handle $moveUnsnappedLeftPath

        $title = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Chrome"
        $rightTitleRectangle = $title.Current.BoundingRectangle
        $rightSnapStartPoint =
            Get-TitleBarPhysicalDragPoint $rightTitleRectangle $windowScaleX
        $rightSnapStartX = $rightSnapStartPoint.x
        $rightSnapStartY = $rightSnapStartPoint.y
        $rightSnapEndX = [int]$moveMaximizedBounds.right - 1
        $rightSnapEndY = [int][Math]::Round(160 * $windowScaleY)
        Invoke-PhysicalDrag `
            $rightSnapStartX `
            $rightSnapStartY `
            $rightSnapEndX `
            $rightSnapEndY `
            $handle `
            "titlebar-snap-right" `
            850
        Wait-Condition -Description "physical Windows right Snap" -Condition {
            $bounds = Get-WindowBounds $handle
            [Math]::Abs($bounds.right - $moveMaximizedBounds.right) -le 2 -and
            $bounds.top -le 2 -and
            $bounds.width -lt $moveMaximizedBounds.width -and
            $bounds.height -ge $moveMaximizedBounds.height - 4
        }
        $snapAfterRight = Wait-TitleBarSnapDiagnostics `
            -ProcessId $process.Id `
            -ExpectedScheduled ($snapDiagnosticsBaseline.scheduled + 6) `
            -ExpectedApplied ($snapDiagnosticsBaseline.applied + 6) `
            -ExpectedNoTarget ($snapDiagnosticsBaseline.noTarget + 3) `
            -ExpectedOutcome "Right" `
            -Description "Snap diagnostics after physical right Snap"
        $snappedRightBounds = Get-WindowBounds $handle
        Assert-BoundsNear `
            $snappedRightBounds `
            $expectedRightSnapBounds `
            4 `
            "physical right Snap placement"
        if ([LumaChartTitleBarGuiNative]::IsZoomed($handle)) {
            throw "Right Snap incorrectly reported a maximized window."
        }
        $moveActions.Add([ordered]@{
            name = "titlebar-snap-right"
            input = "Win32 SendInput physical mouse drag"
            start = [ordered]@{ x = $rightSnapStartX; y = $rightSnapStartY }
            end = [ordered]@{ x = $rightSnapEndX; y = $rightSnapEndY }
            before = $unsnappedLeftBounds
            after = $snappedRightBounds
            isZoomedAfter = $false
            snapDiagnostics = $snapAfterRight
        })
        $moveSnappedRightCapture =
            Capture-Window $handle $moveSnappedRightPath

        $title = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Chrome"
        $rightSnappedTitleRectangle = $title.Current.BoundingRectangle
        $rightUnSnapStartPoint =
            Get-TitleBarPhysicalDragPoint `
                $rightSnappedTitleRectangle `
                $windowScaleX
        $rightUnSnapStartX = $rightUnSnapStartPoint.x
        $rightUnSnapStartY = $rightUnSnapStartPoint.y
        # Keep the 1980 px restored window fully reachable so the final
        # physical caption-close action cannot be clamped to the desktop edge.
        $rightUnSnapEndX = [int][Math]::Round($moveMaximizedBounds.width * .28)
        $rightUnSnapEndY = [int][Math]::Round(170 * $windowScaleY)
        Invoke-PhysicalDrag `
            $rightUnSnapStartX `
            $rightUnSnapStartY `
            $rightUnSnapEndX `
            $rightUnSnapEndY `
            $handle `
            "titlebar-unsnap-right"
        $snapAfterRightRestore = Wait-TitleBarSnapDiagnostics `
            -ProcessId $process.Id `
            -ExpectedScheduled ($snapDiagnosticsBaseline.scheduled + 7) `
            -ExpectedApplied ($snapDiagnosticsBaseline.applied + 7) `
            -ExpectedNoTarget ($snapDiagnosticsBaseline.noTarget + 4) `
            -ExpectedOutcome "None" `
            -Description "Snap diagnostics after dragging away from right Snap"
        Wait-Condition `
            -Description "normal bounds after dragging away from right Snap" `
            -Condition {
                $bounds = Get-WindowBounds $handle
                [Math]::Abs(
                    $bounds.width - $initialMoveBounds.width) -le 12 -and
                [Math]::Abs(
                    $bounds.height - $initialMoveBounds.height) -le 12 -and
                [Math]::Abs(
                    $bounds.right - $moveMaximizedBounds.right) -gt 2
            }
        $unsnappedRightBounds = Get-WindowBounds $handle
        if ([Math]::Abs(
                $unsnappedRightBounds.width -
                $initialMoveBounds.width) -gt 12 -or
            [Math]::Abs(
                $unsnappedRightBounds.height -
                $initialMoveBounds.height) -gt 12 -or
            [Math]::Abs(
                $unsnappedRightBounds.right -
                $moveMaximizedBounds.right) -le 2) {
            throw "Dragging away from the right Snap zone did not restore normal size."
        }
        $moveActions.Add([ordered]@{
            name = "titlebar-unsnap-right"
            input = "Win32 SendInput physical mouse drag"
            start = [ordered]@{ x = $rightUnSnapStartX; y = $rightUnSnapStartY }
            end = [ordered]@{ x = $rightUnSnapEndX; y = $rightUnSnapEndY }
            before = $snappedRightBounds
            after = $unsnappedRightBounds
            snapDiagnostics = $snapAfterRightRestore
        })
        $moveUnsnappedRightCapture =
            Capture-Window $handle $moveUnsnappedRightPath

        $timeline = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Timeline.Surface"
        $timelineFocusedAfterMoveActions =
            [bool]$timeline.Current.HasKeyboardFocus
        if (-not $timelineFocusedAfterMoveActions) {
            throw "Timeline focus was lost during native maximize/Snap move actions."
        }
        $saveStateAfterElement = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.SaveState"
        $saveStateAfterMoveActions =
            [string]$saveStateAfterElement.Current.Name
        if ($saveStateAfterMoveActions -cne "· 已保存") {
            throw "Native maximize/Snap actions mutated the chart session: " +
                  "'$saveStateAfterMoveActions'."
        }

        $close = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.Close"
        $closePoint =
            Invoke-PhysicalElementClick $close $handle "window-move-close"
        $moveActions.Add([ordered]@{
            name = "caption-close-after-window-move"
            input = "Win32 SendInput physical mouse click"
            point = $closePoint
            before = $unsnappedRightBounds
        })
        Wait-Condition -Description "physical close after native move/Snap" -Condition {
            $process.Refresh()
            $process.HasExited
        }
        if ($moveActions.Count -ne 9) {
            throw "Expected exactly 9 physical move/Snap actions, got " +
                   "$($moveActions.Count)."
        }

        $fixtureHashAfter =
            (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
        $installerHashAfter =
            (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
        if ($fixtureHashAfter -cne $fixtureHashBefore) {
            throw "Real MC fixture changed during native move/Snap GUI acceptance."
        }
        if ($installerHashAfter -cne $installerHashBefore) {
            throw "Frozen WPF installer changed during native move/Snap GUI acceptance."
        }

        $predecessorVerificationPath = Resolve-ExistingFile `
            (Join-Path $projectRoot (
                "artifacts\windows-avalonia-caption-lifecycle-slice-20260727-r1\" +
                "verification-evidence.json")) `
            "caption-lifecycle r1 formal authority"
        $predecessorVerificationHash =
            (Get-FileHash -LiteralPath $predecessorVerificationPath `
                -Algorithm SHA256).Hash
        if ($predecessorVerificationHash -cne
            "7346AB9BCC610957718556F3AB2320B154B0361DBA5A6CAA918BC175B442E878") {
            throw "The caption-lifecycle r1 formal authority hash changed."
        }

        $screenshots = [ordered]@{}
        foreach ($path in @(
                $windowedPath,
                $moveMaximizedPath,
                $moveRestoredFromMaximizedPath,
                $moveSnappedTopPath,
                $moveRestoredFromTopPath,
                $moveSnappedLeftPath,
                $moveUnsnappedLeftPath,
                $moveSnappedRightPath,
                $moveUnsnappedRightPath)) {
            $item = Get-Item -LiteralPath $path
            $screenshots[$item.BaseName] = [ordered]@{
                path = $item.FullName
                length = $item.Length
                sha256 =
                    (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
            }
        }
        $evidence = [ordered]@{
            schema = "lumachart.windows.avalonia.window-move-snap-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed-migration-incomplete"
            windowsAvaloniaOnly = $true
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            productionServerMutationPerformed = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            contract = "wpf-1.1.0-titlebar-r1"
            processId = $process.Id
            predecessor = [ordered]@{
                path = $predecessorVerificationPath
                sha256 = $predecessorVerificationHash
            }
            currentSliceInput = [ordered]@{
                physicalMouseInputUsed = $true
                physicalActionCount = $moveActions.Count
                physicalClickCount = 2
                physicalDragCount = 7
                physicalSetupClickCount =
                    $windowMoveActivationPreflightClicks
                keyboardInjectionUsed =
                    [LumaChartTitleBarGuiNative]::ForegroundActivationAltPulseCount -gt 0
                foregroundActivationAltPulseCount =
                    [LumaChartTitleBarGuiNative]::ForegroundActivationAltPulseCount
                foregroundActivationMouseClickCount =
                    [LumaChartTitleBarGuiNative]::ForegroundActivationMouseClickCount
                foregroundActivationHitTestFallbackCount =
                    [LumaChartTitleBarGuiNative]::ForegroundActivationHitTestFallbackCount
                foregroundActivationTopmostFallbackUsed =
                    [LumaChartTitleBarGuiNative]::ForegroundActivationTopmostFallbackActive
                hardwareInputClaimed = $false
            }
            environment = [ordered]@{
                activeWindowsScale = $windowScaleX
                screenCount = 1
                primaryScreenBounds = $moveMaximizedBounds
                multiScreenTested = $false
                perMonitorDpiTransitionTested = $false
            }
            chrome = [ordered]@{
                titleBarHeight = 38
                captionButtonWidth = 46
                formatBadge = $formatBadgeName
                documentTab = $chartTabName
            }
            windowMoveAndSnap = [ordered]@{
                initialBounds = $initialMoveBounds
                maximizedBounds = $moveMaximizedBounds
                restoredFromMaximizedBounds = $restoredFromMaximizedBounds
                topSnappedBounds = $topSnappedBounds
                restoredFromTopBounds = $restoredFromTopBounds
                snappedLeftBounds = $snappedLeftBounds
                unsnappedLeftBounds = $unsnappedLeftBounds
                snappedRightBounds = $snappedRightBounds
                unsnappedRightBounds = $unsnappedRightBounds
                maximizeDragRestorePassed = $true
                topSnapAndRestorePassed = $true
                leftSnapAndRestorePassed = $true
                rightSnapAndRestorePassed = $true
                saveStateBefore = $saveStateBeforeMoveActions
                saveStateAfter = $saveStateAfterMoveActions
                sessionCleanBeforeAndAfter = $true
                timelineFocusedBefore = $timelineFocusedBeforeMoveActions
                timelineFocusedAfter = $timelineFocusedAfterMoveActions
                physicalCloseExitedProcess = $true
                snapDiagnosticsBaseline = $snapDiagnosticsBaseline
                snapDiagnosticsFinal = $snapAfterRightRestore
                expectedLeftSnapBounds = $expectedLeftSnapBounds
                expectedRightSnapBounds = $expectedRightSnapBounds
                actions = $moveActions
                passed = $true
            }
            source = [ordered]@{
                path = $chartFullPath
                sha256Before = $fixtureHashBefore
                sha256After = $fixtureHashAfter
                unchanged = $true
            }
            frozenInstaller = [ordered]@{
                path = $installerPath
                sha256Before = $installerHashBefore
                sha256After = $installerHashAfter
                unchanged = $true
            }
            captures = [ordered]@{
                windowed = $windowedCapture
                maximized = $moveMaximizedCapture
                restoredFromMaximized = $moveRestoredFromMaximizedCapture
                snappedTop = $moveSnappedTopCapture
                restoredFromTop = $moveRestoredFromTopCapture
                snappedLeft = $moveSnappedLeftCapture
                unsnappedLeft = $moveUnsnappedLeftCapture
                snappedRight = $moveSnappedRightCapture
                unsnappedRight = $moveUnsnappedRightCapture
            }
            screenshots = $screenshots
            completion = [ordered]@{
                windowMoveSnapSlicePassed = $true
                windowsAvaloniaOneToOneComplete = $false
                userReplacementApprovalReceived = $false
                nextPlatformAuthorized = $false
            }
            remainingDifferences = @(
                "Only one physical screen was attached; multi-screen and Per-Monitor DPI transitions remain open.",
                "Native Windows 11 Snap Layout hover UI and keyboard-only Snap remain separate acceptance items.",
                "Remaining focus/IME, online, format, ClientSecurity, installer and physical performance gates remain open.")
        }
        $evidence | ConvertTo-Json -Depth 18 |
            Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
        Write-Host "Windows Avalonia maximize-drag/Snap GUI capture: passed"
        Write-Host "Evidence: $evidencePath"
        return
    }

    $timeline = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Timeline.Surface"
    $windowCloseButton = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Title.Close"
    $saveStateBeforeElement = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Title.SaveState"
    $saveStateBeforeResize = [string]$saveStateBeforeElement.Current.Name
    if ($saveStateBeforeResize -cne "· 已保存") {
        throw "Chart session was dirty before physical window resize: '$saveStateBeforeResize'."
    }
    $resizeActions = [Collections.Generic.List[object]]::new()
    $timeline.SetFocus()
    Wait-Condition -Description "timeline UIA focus before physical window resize" -Condition {
        [bool]$timeline.Current.HasKeyboardFocus
    }
    $timelineFocusedBeforeResize = [bool]$timeline.Current.HasKeyboardFocus
    if (-not $timelineFocusedBeforeResize) {
        throw "Timeline did not retain keyboard focus before physical window resize."
    }

    $initialResizeBounds = Get-WindowBounds $handle
    $deltaX = [int][Math]::Round(120 * $windowScaleX)
    $deltaY = [int][Math]::Round(80 * $windowScaleY)
    $boundsTolerance = 10
    $middleX = [int][Math]::Round(
        ($initialResizeBounds.left + $initialResizeBounds.right) / 2)
    $middleY = [int][Math]::Round(
        ($initialResizeBounds.top + $initialResizeBounds.bottom) / 2)

    $rightResizeBounds = Invoke-ResizeChecked `
        -Name "right-edge-inward" `
        -StartX ([int]$initialResizeBounds.right - 2) `
        -StartY $middleY `
        -EndX ([int]$initialResizeBounds.right - 2 - $deltaX) `
        -EndY $middleY `
        -Handle $handle `
        -Actions $resizeActions `
        -Accept {
            param($before, $after)
            $after.width -lt $before.width - $deltaX * .55 -and
            [Math]::Abs($after.left - $before.left) -le $boundsTolerance
        }
    $rightResizeCapture = Capture-Window $handle $rightResizePath
    [void](Invoke-ResizeChecked `
        -Name "right-edge-restore" `
        -StartX ([int]$rightResizeBounds.right - 2) `
        -StartY $middleY `
        -EndX ([int]$initialResizeBounds.right - 2) `
        -EndY $middleY `
        -Handle $handle `
        -Actions $resizeActions `
        -Accept {
            param($before, $after)
            try {
                Assert-BoundsNear $after $initialResizeBounds $boundsTolerance `
                    "right-edge restore"
                return $true
            }
            catch { return $false }
        })

    $bottomResizeBounds = Invoke-ResizeChecked `
        -Name "bottom-edge-inward" `
        -StartX $middleX `
        -StartY ([int]$initialResizeBounds.bottom - 2) `
        -EndX $middleX `
        -EndY ([int]$initialResizeBounds.bottom - 2 - $deltaY) `
        -Handle $handle `
        -Actions $resizeActions `
        -Accept {
            param($before, $after)
            $after.height -lt $before.height - $deltaY * .55 -and
            [Math]::Abs($after.top - $before.top) -le $boundsTolerance
        }
    [void](Invoke-ResizeChecked `
        -Name "bottom-edge-restore" `
        -StartX $middleX `
        -StartY ([int]$bottomResizeBounds.bottom - 2) `
        -EndX $middleX `
        -EndY ([int]$initialResizeBounds.bottom - 2) `
        -Handle $handle `
        -Actions $resizeActions `
        -Accept {
            param($before, $after)
            try {
                Assert-BoundsNear $after $initialResizeBounds $boundsTolerance `
                    "bottom-edge restore"
                return $true
            }
            catch { return $false }
        })

    $leftResizeBounds = Invoke-ResizeChecked `
        -Name "left-edge-inward" `
        -StartX ([int]$initialResizeBounds.left + 1) `
        -StartY $middleY `
        -EndX ([int]$initialResizeBounds.left + 1 + $deltaX) `
        -EndY $middleY `
        -Handle $handle `
        -Actions $resizeActions `
        -Accept {
            param($before, $after)
            $after.left -gt $before.left + $deltaX * .55 -and
            $after.width -lt $before.width - $deltaX * .55
        }
    [void](Invoke-ResizeChecked `
        -Name "left-edge-restore" `
        -StartX ([int]$leftResizeBounds.left + 1) `
        -StartY $middleY `
        -EndX ([int]$initialResizeBounds.left + 1) `
        -EndY $middleY `
        -Handle $handle `
        -Actions $resizeActions `
        -Accept {
            param($before, $after)
            try {
                Assert-BoundsNear $after $initialResizeBounds $boundsTolerance `
                    "left-edge restore"
                return $true
            }
            catch { return $false }
        })

    $topResizeBounds = Invoke-ResizeChecked `
        -Name "top-edge-inward" `
        -StartX $middleX `
        -StartY ([int]$initialResizeBounds.top + 1) `
        -EndX $middleX `
        -EndY ([int]$initialResizeBounds.top + 1 + $deltaY) `
        -Handle $handle `
        -Actions $resizeActions `
        -Accept {
            param($before, $after)
            $after.top -gt $before.top + $deltaY * .55 -and
            $after.height -lt $before.height - $deltaY * .55
        }
    [void](Invoke-ResizeChecked `
        -Name "top-edge-restore" `
        -StartX $middleX `
        -StartY ([int]$topResizeBounds.top + 1) `
        -EndX $middleX `
        -EndY ([int]$initialResizeBounds.top + 1) `
        -Handle $handle `
        -Actions $resizeActions `
        -Accept {
            param($before, $after)
            try {
                Assert-BoundsNear $after $initialResizeBounds $boundsTolerance `
                    "top-edge restore"
                return $true
            }
            catch { return $false }
        })

    $cornerCases = @(
        [ordered]@{
            name = "top-left"
            startX = [int]$initialResizeBounds.left + 1
            startY = [int]$initialResizeBounds.top + 1
            endX = [int]$initialResizeBounds.left + 1 + $deltaX
            endY = [int]$initialResizeBounds.top + 1 + $deltaY
            restoreX = [int]$initialResizeBounds.left + 1
            restoreY = [int]$initialResizeBounds.top + 1
            leftMoves = $true
            topMoves = $true
        },
        [ordered]@{
            name = "top-right"
            startX = [int]$initialResizeBounds.right - 2
            startY = [int]$initialResizeBounds.top + 1
            endX = [int]$initialResizeBounds.right - 2 - $deltaX
            endY = [int]$initialResizeBounds.top + 1 + $deltaY
            restoreX = [int]$initialResizeBounds.right - 2
            restoreY = [int]$initialResizeBounds.top + 1
            leftMoves = $false
            topMoves = $true
        },
        [ordered]@{
            name = "bottom-left"
            startX = [int]$initialResizeBounds.left + 1
            startY = [int]$initialResizeBounds.bottom - 2
            endX = [int]$initialResizeBounds.left + 1 + $deltaX
            endY = [int]$initialResizeBounds.bottom - 2 - $deltaY
            restoreX = [int]$initialResizeBounds.left + 1
            restoreY = [int]$initialResizeBounds.bottom - 2
            leftMoves = $true
            topMoves = $false
        },
        [ordered]@{
            name = "bottom-right"
            startX = [int]$initialResizeBounds.right - 2
            startY = [int]$initialResizeBounds.bottom - 2
            endX = [int]$initialResizeBounds.right - 2 - $deltaX
            endY = [int]$initialResizeBounds.bottom - 2 - $deltaY
            restoreX = [int]$initialResizeBounds.right - 2
            restoreY = [int]$initialResizeBounds.bottom - 2
            leftMoves = $false
            topMoves = $false
        })
    foreach ($corner in $cornerCases) {
        $leftMoves = [bool]$corner.leftMoves
        $topMoves = [bool]$corner.topMoves
        $cornerBounds = Invoke-ResizeChecked `
            -Name "$($corner.name)-corner-inward" `
            -StartX ([int]$corner.startX) `
            -StartY ([int]$corner.startY) `
            -EndX ([int]$corner.endX) `
            -EndY ([int]$corner.endY) `
            -Handle $handle `
            -Actions $resizeActions `
            -Accept {
                param($before, $after)
                $horizontal = $after.width -lt $before.width - $deltaX * .55
                $vertical = $after.height -lt $before.height - $deltaY * .55
                $left = if ($leftMoves) {
                    $after.left -gt $before.left + $deltaX * .55
                } else {
                    [Math]::Abs($after.left - $before.left) -le $boundsTolerance
                }
                $top = if ($topMoves) {
                    $after.top -gt $before.top + $deltaY * .55
                } else {
                    [Math]::Abs($after.top - $before.top) -le $boundsTolerance
                }
                $horizontal -and $vertical -and $left -and $top
            }
        $cornerRestoreStartX = if ($leftMoves) {
            [int]$cornerBounds.left + 1
        } else {
            [int]$cornerBounds.right - 2
        }
        $cornerRestoreStartY = if ($topMoves) {
            [int]$cornerBounds.top + 1
        } else {
            [int]$cornerBounds.bottom - 2
        }
        [void](Invoke-ResizeChecked `
            -Name "$($corner.name)-corner-restore" `
            -StartX $cornerRestoreStartX `
            -StartY $cornerRestoreStartY `
            -EndX ([int]$corner.restoreX) `
            -EndY ([int]$corner.restoreY) `
            -Handle $handle `
            -Actions $resizeActions `
            -Accept {
                param($before, $after)
                try {
                    Assert-BoundsNear $after $initialResizeBounds $boundsTolerance `
                        "$($corner.name) corner restore"
                    return $true
                }
                catch { return $false }
            })
    }

    $expectedMinimumWidth = [int][Math]::Round(1080 * $windowScaleX)
    $expectedMinimumHeight = [int][Math]::Round(680 * $windowScaleY)
    $minimumWidthBounds = Invoke-ResizeChecked `
        -Name "right-edge-minimum-clamp" `
        -StartX ([int]$initialResizeBounds.right - 2) `
        -StartY $middleY `
        -EndX ([int]$initialResizeBounds.left + $expectedMinimumWidth - 240) `
        -EndY $middleY `
        -Handle $handle `
        -Actions $resizeActions `
        -Accept {
            param($before, $after)
            [Math]::Abs($after.width - $expectedMinimumWidth) -le 14 -and
            [Math]::Abs($after.left - $before.left) -le $boundsTolerance
        }
    $minimumMiddleX = [int][Math]::Round(
        ($minimumWidthBounds.left + $minimumWidthBounds.right) / 2)
    $minimumResizeBounds = Invoke-ResizeChecked `
        -Name "bottom-edge-minimum-clamp" `
        -StartX $minimumMiddleX `
        -StartY ([int]$minimumWidthBounds.bottom - 2) `
        -EndX $minimumMiddleX `
        -EndY ([int]$minimumWidthBounds.top + $expectedMinimumHeight - 180) `
        -Handle $handle `
        -Actions $resizeActions `
        -Accept {
            param($before, $after)
            [Math]::Abs($after.height - $expectedMinimumHeight) -le 14 -and
            [Math]::Abs($after.top - $before.top) -le $boundsTolerance
        }
    $windowCloseButton = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Title.Close"
    $minimumCloseBounds = $windowCloseButton.Current.BoundingRectangle
    if ($minimumCloseBounds.Right -gt $minimumResizeBounds.right + 2 -or
        $minimumCloseBounds.Left -lt $minimumResizeBounds.left - 2 -or
        $minimumCloseBounds.Top -lt $minimumResizeBounds.top - 2 -or
        $minimumCloseBounds.Bottom -gt $minimumResizeBounds.bottom + 2 -or
        $windowCloseButton.Current.IsOffscreen) {
        throw "Caption close button was clipped at the native minimum size."
    }
    $minimumResizeCapture = Capture-Window $handle $minimumResizePath

    $resizeRestoredBounds = Invoke-ResizeChecked `
        -Name "bottom-right-corner-restore-from-minimum" `
        -StartX ([int]$minimumResizeBounds.right - 2) `
        -StartY ([int]$minimumResizeBounds.bottom - 2) `
        -EndX ([int]$initialResizeBounds.right - 2) `
        -EndY ([int]$initialResizeBounds.bottom - 2) `
        -Handle $handle `
        -Actions $resizeActions `
        -Accept {
            param($before, $after)
            try {
                Assert-BoundsNear $after $initialResizeBounds $boundsTolerance `
                    "restore from minimum"
                return $true
            }
            catch { return $false }
        }
    $timeline = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Timeline.Surface"
    $timelineFocusedAfterResize = [bool]$timeline.Current.HasKeyboardFocus
    if (-not $timelineFocusedAfterResize) {
        throw "Timeline keyboard focus was lost after physical window resize."
    }
    $saveStateAfterElement = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Title.SaveState"
    $saveStateAfterResize = [string]$saveStateAfterElement.Current.Name
    if ($saveStateAfterResize -cne "· 已保存") {
        throw "Physical window resize mutated the chart session: '$saveStateAfterResize'."
    }
    $resizeRestoredCapture = Capture-Window $handle $resizeRestoredPath

    if ($ResizeOnly) {
        $fixtureHashAfter =
            (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
        $installerHashAfter =
            (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
        if ($fixtureHashAfter -cne $fixtureHashBefore) {
            throw "Real MC fixture changed during window-resize GUI acceptance."
        }
        if ($installerHashAfter -cne $installerHashBefore) {
            throw "Frozen WPF installer changed during window-resize GUI acceptance."
        }
        if ($resizeActions.Count -ne 19) {
            throw "Expected exactly 19 physical resize actions, got $($resizeActions.Count)."
        }

        $screenshots = [ordered]@{}
        foreach ($path in @(
                $windowedPath,
                $rightResizePath,
                $minimumResizePath,
                $resizeRestoredPath)) {
            $item = Get-Item -LiteralPath $path
            $screenshots[$item.BaseName] = [ordered]@{
                path = $item.FullName
                length = $item.Length
                sha256 =
                    (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
            }
        }
        $evidence = [ordered]@{
            schema =
                "lumachart.windows.avalonia.window-resize-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed-migration-incomplete"
            windowsAvaloniaOnly = $true
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            productionServerMutationPerformed = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            contract = "wpf-1.1.0-titlebar-r1"
            processId = $process.Id
            predecessorPhysicalAuthority = [ordered]@{
                path = $predecessorGuiEvidencePath
                sha256 = $predecessorGuiEvidenceHash
                titleBarDoubleClickMaximized = $true
                f11EnterAndExit = $true
            }
            currentSliceInput = [ordered]@{
                physicalMouseInputUsed = $true
                input = "Win32 SendInput physical mouse drag"
                physicalWindowResizeActionCount = $resizeActions.Count
                timelineFocusSetup = "UI Automation SetFocus"
                keyboardInjectionUsed =
                    [LumaChartTitleBarGuiNative]::ForegroundActivationAltPulseCount -gt 0
                foregroundActivationAltPulseCount =
                    [LumaChartTitleBarGuiNative]::ForegroundActivationAltPulseCount
                foregroundActivationMouseClickCount =
                    [LumaChartTitleBarGuiNative]::ForegroundActivationMouseClickCount
                hardwareInputClaimed = $false
            }
            chrome = [ordered]@{
                titleBarHeight = 38
                captionButtonWidth = 46
                resizeBorderThickness = 6
                minimumWindowWidth = 1080
                minimumWindowHeight = 680
                activeWindowsScale = $windowScaleX
                formatBadge = $formatBadgeName
                documentTab = $chartTabName
                tabCloseWidth = $tabClosePhysicalWidth
            }
            windowResize = [ordered]@{
                nativeBorderlessCanResize = $true
                physicalMouseInputUsed = $true
                testedEdges = @("left", "top", "right", "bottom")
                testedCorners = @(
                    "top-left",
                    "top-right",
                    "bottom-left",
                    "bottom-right")
                initialBounds = $initialResizeBounds
                representativeRightEdgeBounds = $rightResizeBounds
                minimumBounds = $minimumResizeBounds
                restoredBounds = $resizeRestoredBounds
                activeWindowsScale = $windowScaleX
                expectedMinimumWidth = $expectedMinimumWidth
                expectedMinimumHeight = $expectedMinimumHeight
                minimumCaptionCloseBounds =
                    Convert-Rectangle $minimumCloseBounds
                minimumCaptionCloseVisible = $true
                timelineFocusedBeforeResize = $timelineFocusedBeforeResize
                timelineFocusedAfterResize = $timelineFocusedAfterResize
                saveStateBeforeResize = $saveStateBeforeResize
                saveStateAfterResize = $saveStateAfterResize
                sessionCleanBeforeResize = $saveStateBeforeResize -ceq "· 已保存"
                sessionCleanAfterResize = $saveStateAfterResize -ceq "· 已保存"
                actions = $resizeActions
                passed = $true
            }
            source = [ordered]@{
                path = $chartFullPath
                sha256Before = $fixtureHashBefore
                sha256After = $fixtureHashAfter
                unchanged = $true
            }
            frozenInstaller = [ordered]@{
                path = $installerPath
                sha256Before = $installerHashBefore
                sha256After = $installerHashAfter
                unchanged = $true
            }
            captures = [ordered]@{
                windowed = $windowedCapture
                rightEdgeResize = $rightResizeCapture
                minimumResize = $minimumResizeCapture
                resizeRestored = $resizeRestoredCapture
            }
            screenshots = $screenshots
            completion = [ordered]@{
                windowResizeSlicePassed = $true
                windowsAvaloniaOneToOneComplete = $false
                userReplacementApprovalReceived = $false
                nextPlatformAuthorized = $false
            }
            remainingDifferences = @(
                "Multi-screen and all Windows DPI/UI-scale resize combinations remain open.",
                "Remaining UI/focus/IME, online, format, ClientSecurity, installer and physical display/performance gates remain open.")
        }
        $evidence | ConvertTo-Json -Depth 18 |
            Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
        Write-Host "Windows Avalonia borderless window-resize GUI capture: passed"
        Write-Host "Evidence: $evidencePath"
        return
    }

    Invoke-UiaElement $maximizeButton
    Wait-Condition -Description "UIA maximize for animation acceptance" -Seconds 10 -Condition {
        $candidate = Get-WindowBounds $handle
        return $candidate.width -gt ($windowedBounds.width + 200) -and
               $candidate.height -gt ($windowedBounds.height + 100)
    }
    $maximizedBounds = Get-WindowBounds $handle
    $maximizedCapture = Capture-Window $handle $maximizedPath

    [void][LumaChartTitleBarGuiNative]::SetCursorPos(
        [int][Math]::Round(($maximizedBounds.left + $maximizedBounds.right) / 2),
        [int][Math]::Round(($maximizedBounds.top + $maximizedBounds.bottom) / 2))
    $commandMenuToggle = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.CommandMenuToggle"
    Invoke-UiaElement $commandMenuToggle
    $fullscreenButton = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.Command.Fullscreen"
    Invoke-UiaElement $fullscreenButton
    Invoke-UiaElement $commandMenuToggle
    Wait-Condition -Description "UIA fullscreen title-bar hide" -Seconds 10 -Condition {
        try {
            $candidate = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Title.Chrome" `
                -TimeoutMilliseconds 400
            $rectangle = $candidate.Current.BoundingRectangle
            return $candidate.Current.IsOffscreen -or
                   $rectangle.Bottom -le ((Get-WindowBounds $handle).top + 2)
        }
        catch { return $false }
    }
    $fullscreenBounds = Get-WindowBounds $handle
    $hiddenTitle = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Title.Chrome"
    $hiddenTitleRectangle = $hiddenTitle.Current.BoundingRectangle
    $hiddenTitleY = Get-TitleBarAnimationY $hiddenTitle
    if ([Math]::Abs($hiddenTitleY + 38) -gt .5) {
        throw "Initial fullscreen title-bar transform is not -38 DIP: $hiddenTitleY."
    }
    $fullscreenHiddenCapture = Capture-Window $handle $fullscreenHiddenPath

    $revealX = [int][Math]::Round(
        ($fullscreenBounds.left + $fullscreenBounds.right) / 2)
    $revealY = [int]$fullscreenBounds.top
    if (-not [LumaChartTitleBarGuiNative]::SetCursorPos($revealX, $revealY)) {
        throw "Could not move pointer to fullscreen physical top edge."
    }
    $revealWatch = [Diagnostics.Stopwatch]::StartNew()
    $revealSamples = @()
    $revealDeadline = [DateTimeOffset]::UtcNow.AddSeconds(10)
    do {
        try {
            $candidate = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Title.Chrome" `
                -TimeoutMilliseconds 400
            $rectangle = $candidate.Current.BoundingRectangle
            $candidateY = Get-TitleBarAnimationY $candidate
            $revealSamples += [ordered]@{
                elapsedMilliseconds = [Math]::Round(
                    $revealWatch.Elapsed.TotalMilliseconds,
                    2)
                currentY = [Math]::Round($candidateY, 3)
                top = [Math]::Round([double]$rectangle.Top, 2)
                bottom = [Math]::Round([double]$rectangle.Bottom, 2)
                offscreen = [bool]$candidate.Current.IsOffscreen
            }
            if ($candidateY -ge -.1 -and
                -not $candidate.Current.IsOffscreen -and
                $rectangle.Top -ge ($fullscreenBounds.top - 2) -and
                $rectangle.Bottom -ge ($fullscreenBounds.top + 35)) {
                break
            }
        }
        catch { }
        Start-Sleep -Milliseconds 8
    } while ([DateTimeOffset]::UtcNow -lt $revealDeadline)
    $revealWatch.Stop()
    if ($revealSamples.Count -eq 0 -or
        $revealSamples[-1].currentY -lt -.1 -or
        $revealSamples[-1].top -lt ($fullscreenBounds.top - 2) -or
        $revealSamples[-1].bottom -lt ($fullscreenBounds.top + 35)) {
        throw "Timed out waiting for physical top-edge title-bar reveal."
    }
    $revealIntermediate = @(
        $revealSamples | Where-Object {
            $_.currentY -gt -36 -and $_.currentY -lt -2
        }
    )
    if ($revealIntermediate.Count -eq 0) {
        throw "Fullscreen title-bar reveal did not expose an intermediate animation frame: " +
              ($revealSamples | ConvertTo-Json -Compress -Depth 4)
    }
    $revealedTitleRectangle = (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Title.Chrome").Current.BoundingRectangle
    $fullscreenRevealedCapture = Capture-Window $handle $fullscreenRevealedPath

    $hideWatch = [Diagnostics.Stopwatch]::StartNew()
    [void][LumaChartTitleBarGuiNative]::SetCursorPos(
        $revealX,
        [int][Math]::Round(($fullscreenBounds.top + $fullscreenBounds.bottom) / 2))
    $hideSamples = @()
    $hideAnimationStartedMilliseconds = $null
    $hideDeadline = [DateTimeOffset]::UtcNow.AddSeconds(10)
    do {
        try {
            $candidate = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Title.Chrome" `
                -TimeoutMilliseconds 400
            $rectangle = $candidate.Current.BoundingRectangle
            $candidateY = Get-TitleBarAnimationY $candidate
            $elapsed = $hideWatch.Elapsed.TotalMilliseconds
            $hideSamples += [ordered]@{
                elapsedMilliseconds = [Math]::Round($elapsed, 2)
                currentY = [Math]::Round($candidateY, 3)
                top = [Math]::Round([double]$rectangle.Top, 2)
                bottom = [Math]::Round([double]$rectangle.Bottom, 2)
                offscreen = [bool]$candidate.Current.IsOffscreen
            }
            if ($null -eq $hideAnimationStartedMilliseconds -and
                $candidateY -lt -.001) {
                $hideAnimationStartedMilliseconds = $elapsed
            }
            if ($candidateY -le -37.5) {
                break
            }
        }
        catch { }
        Start-Sleep -Milliseconds 8
    } while ([DateTimeOffset]::UtcNow -lt $hideDeadline)
    $hideWatch.Stop()
    if ($hideSamples.Count -eq 0 -or
        $hideSamples[-1].currentY -gt -37.5) {
        throw "Timed out waiting for 480 ms fullscreen title-bar auto-hide."
    }
    $hideIntermediate = @(
        $hideSamples | Where-Object {
            $_.currentY -lt -2 -and $_.currentY -gt -36
        }
    )
    if ($hideIntermediate.Count -eq 0 -or
        $null -eq $hideAnimationStartedMilliseconds) {
        throw "Fullscreen title-bar hide did not expose an intermediate animation frame: " +
              ($hideSamples | ConvertTo-Json -Compress -Depth 4)
    }
    Wait-Condition -Description "fullscreen title-bar compositor hide completion" -Seconds 5 -Condition {
        try {
            $candidate = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Title.Chrome" `
                -TimeoutMilliseconds 400
            $rectangle = $candidate.Current.BoundingRectangle
            return $candidate.Current.IsOffscreen -or
                   $rectangle.Bottom -le ($fullscreenBounds.top + 2)
        }
        catch { return $false }
    }
    $hiddenAgainTitleRectangle = (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Title.Chrome").Current.BoundingRectangle
    Invoke-UiaElement $commandMenuToggle
    $fullscreenButton = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.Command.Fullscreen"
    Invoke-UiaElement $fullscreenButton
    Invoke-UiaElement $commandMenuToggle
    Wait-Condition -Description "UIA restore maximized title bar" -Seconds 10 -Condition {
        try {
            $candidate = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Title.Chrome" `
                -TimeoutMilliseconds 400
            $rectangle = $candidate.Current.BoundingRectangle
            return -not $candidate.Current.IsOffscreen -and
                   [Math]::Abs($rectangle.Height / $windowScaleY - 38) -le 1.25
        }
        catch { return $false }
    }
    $restoredBounds = Get-WindowBounds $handle
    $restoredCapture = Capture-Window $handle $restoredPath
    if ([Math]::Abs($restoredBounds.width - $maximizedBounds.width) -gt 4 -or
        [Math]::Abs($restoredBounds.height - $maximizedBounds.height) -gt 4) {
        throw "Fullscreen command did not restore the pre-fullscreen maximized bounds."
    }

    $fixtureHashAfter = (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
    $installerHashAfter = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
    if ($fixtureHashAfter -cne $fixtureHashBefore) {
        throw "Real MC fixture changed during title-bar GUI acceptance."
    }
    if ($installerHashAfter -cne $installerHashBefore) {
        throw "Frozen WPF installer changed during title-bar GUI acceptance."
    }

    $screenshots = [ordered]@{}
    foreach ($path in @(
            $windowedPath,
            $rightResizePath,
            $minimumResizePath,
            $resizeRestoredPath,
            $maximizedPath,
            $fullscreenHiddenPath,
            $fullscreenRevealedPath,
            $restoredPath)) {
        $item = Get-Item -LiteralPath $path
        $screenshots[$item.BaseName] = [ordered]@{
            path = $item.FullName
            length = $item.Length
            sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        }
    }

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.window-resize-titlebar-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        platform = "Windows Avalonia only"
        buildMode = "ordinary .NET Release"
        windowsAvaloniaOnly = $true
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        contract = "wpf-1.1.0-titlebar-r1"
        processId = $process.Id
        predecessorPhysicalAuthority = [ordered]@{
            path = $predecessorGuiEvidencePath
            sha256 = $predecessorGuiEvidenceHash
            titleBarDoubleClickMaximized = $true
            f11EnterAndExit = $true
        }
        currentSliceInput = [ordered]@{
            maximize = "UI Automation InvokePattern"
            fullscreenEnterAndExit = "UI Automation InvokePattern"
            physicalTopEdgeReveal = [ordered]@{ x = $revealX; y = $revealY }
            win32PointerPositioningUsed = $true
            mouseButtonInjectionUsed = $true
            keyboardInjectionUsed =
                [LumaChartTitleBarGuiNative]::ForegroundActivationAltPulseCount -gt 0
            foregroundActivationAltPulseCount =
                [LumaChartTitleBarGuiNative]::ForegroundActivationAltPulseCount
            foregroundActivationMouseClickCount =
                [LumaChartTitleBarGuiNative]::ForegroundActivationMouseClickCount
            hardwareInputClaimed = $false
            physicalWindowResizeActionCount = $resizeActions.Count
        }
        chrome = [ordered]@{
            titleBarHeight = 38
            captionButtonWidth = 46
            resizeBorderThickness = 6
            activeWindowsScale = $windowScaleX
            formatBadge = $formatBadgeName
            documentTab = $chartTabName
            tabCloseWidth = $tabClosePhysicalWidth
            windowedBounds = $windowedBounds
            maximizedBounds = $maximizedBounds
            fullscreenBounds = $fullscreenBounds
            restoredBounds = $restoredBounds
        }
        windowResize = [ordered]@{
            nativeBorderlessCanResize = $true
            physicalMouseInputUsed = $true
            testedEdges = @("left", "top", "right", "bottom")
            testedCorners = @(
                "top-left",
                "top-right",
                "bottom-left",
                "bottom-right")
            initialBounds = $initialResizeBounds
            representativeRightEdgeBounds = $rightResizeBounds
            minimumBounds = $minimumResizeBounds
            restoredBounds = $resizeRestoredBounds
            activeWindowsScale = $windowScaleX
            expectedMinimumWidth = $expectedMinimumWidth
            expectedMinimumHeight = $expectedMinimumHeight
            minimumCaptionCloseBounds =
                Convert-Rectangle $minimumCloseBounds
            minimumCaptionCloseVisible = $true
            timelineFocusedBeforeResize = $timelineFocusedBeforeResize
            timelineFocusedAfterResize = $timelineFocusedAfterResize
            actions = $resizeActions
            passed = $true
        }
        fullscreenTitleBar = [ordered]@{
            initiallyHidden = $true
            physicalTopEdgeRevealed = $true
            autoHiddenAfterPointerLeave = $true
            autoHideDelayMilliseconds = 480
            revealDurationMilliseconds = 145
            revealEasing = "CubicEaseOut"
            revealObservedElapsedMilliseconds =
                [Math]::Round($revealWatch.Elapsed.TotalMilliseconds, 2)
            revealIntermediateFrameObserved = $true
            revealSamples = $revealSamples
            hideDurationMilliseconds = 125
            hideEasing = "CubicEaseIn"
            hideObservedTotalMilliseconds =
                [Math]::Round($hideWatch.Elapsed.TotalMilliseconds, 2)
            hideObservedAnimationStartMilliseconds =
                [Math]::Round([double]$hideAnimationStartedMilliseconds, 2)
            hideObservedAnimationMilliseconds =
                [Math]::Round(
                    $hideWatch.Elapsed.TotalMilliseconds -
                    [double]$hideAnimationStartedMilliseconds,
                    2)
            hideIntermediateFrameObserved = $true
            hideSamples = $hideSamples
            hiddenRectangle = Convert-Rectangle $hiddenTitleRectangle
            revealedRectangle = Convert-Rectangle $revealedTitleRectangle
            hiddenAgainRectangle = Convert-Rectangle $hiddenAgainTitleRectangle
        }
        source = [ordered]@{
            path = $chartFullPath
            sha256Before = $fixtureHashBefore
            sha256After = $fixtureHashAfter
            unchanged = $true
        }
        frozenInstaller = [ordered]@{
            path = $installerPath
            sha256Before = $installerHashBefore
            sha256After = $installerHashAfter
            unchanged = $true
        }
        captures = [ordered]@{
            windowed = $windowedCapture
            rightEdgeResize = $rightResizeCapture
            minimumResize = $minimumResizeCapture
            resizeRestored = $resizeRestoredCapture
            maximized = $maximizedCapture
            fullscreenHidden = $fullscreenHiddenCapture
            fullscreenRevealed = $fullscreenRevealedCapture
            restored = $restoredCapture
        }
        screenshots = $screenshots
        completion = [ordered]@{
            titleBarSlicePassed = $true
            windowResizeSlicePassed = $true
            windowsAvaloniaOneToOneComplete = $false
            userReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
        }
        remainingDifferences = @(
            "Global modal/popup, danger-menu physical hover, typography and full same-machine WPF screenshot-diff certification remain open.",
            "Remaining focus/IME, online failure, format, ClientSecurity, installer and physical display/performance gates remain open."
        )
    }
    $evidence | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Write-Host "Windows Avalonia title-bar GUI capture: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    if ($process -and -not $process.HasExited) {
        $process.Kill($true)
        [void]$process.WaitForExit(5000)
    }
}
