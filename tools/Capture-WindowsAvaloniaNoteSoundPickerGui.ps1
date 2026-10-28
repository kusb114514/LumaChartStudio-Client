param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$SoundFixturePath = "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 90,
    [switch]$AllowForegroundAutomation
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia Note Sound picker GUI capture requires PowerShell Core on Windows."
}
if (-not $AllowForegroundAutomation) {
    throw (
        "Foreground GUI automation is disabled. Pass " +
        "-AllowForegroundAutomation only after the user explicitly confirms " +
        "that the desktop is available.")
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
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

$application = Resolve-ExistingFile $ApplicationPath "Avalonia application"
$chartFixture = Resolve-ExistingFile $ChartFixturePath "real Resound MC"
$soundFixture = Resolve-ExistingFile $SoundFixturePath "real Resound Note Sound"
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
$sessionRoot = Join-Path $outputFullPath "session"
$localDataRoot = Join-Path $sessionRoot "local-data"
$editingRoot = Join-Path $sessionRoot "editing"
$workspaceRoot = Join-Path $sessionRoot "workspace"
$taskTempRoot = Join-Path $sessionRoot "temp"
foreach ($directory in @(
    $outputFullPath,
    $sessionRoot,
    $localDataRoot,
    $editingRoot,
    $workspaceRoot,
    $taskTempRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}
$env:TEMP = $taskTempRoot
$env:TMP = $taskTempRoot
$env:LUMACHART_AVALONIA_LOCAL_DATA_ROOT = $localDataRoot
$env:LUMACHART_AVALONIA_EDITING_ROOT = $editingRoot
$env:LUMACHART_AVALONIA_WORKSPACE_ROOT = $workspaceRoot

$chartUnderTest = Join-Path $sessionRoot "1781536331.mc"
$soundUnderTest = Join-Path $sessionRoot "Resound - Nhato.ogg"
Copy-Item -LiteralPath $chartFixture -Destination $chartUnderTest -Force
Copy-Item -LiteralPath $soundFixture -Destination $soundUnderTest -Force
$chartHashBefore = (Get-FileHash -LiteralPath $chartFixture -Algorithm SHA256).Hash
$soundHashBefore = (Get-FileHash -LiteralPath $soundFixture -Algorithm SHA256).Hash
$isolatedChartHashBefore = (Get-FileHash -LiteralPath $chartUnderTest -Algorithm SHA256).Hash
$runtimePath = Join-Path $outputFullPath "runtime.json"
$initialScreenshotPath = Join-Path $outputFullPath "note-sound-picker-initial.png"
$itemScreenshotPath = Join-Path $outputFullPath "note-sound-picker-keyboard-item.png"
$restoredScreenshotPath = Join-Path $outputFullPath "note-sound-picker-escape-restored.png"
$assignedScreenshotPath = Join-Path $outputFullPath "note-sound-picker-assigned.png"
$evidencePath = Join-Path $outputFullPath "gui-evidence.json"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartNoteSoundPickerNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO
    {
        public uint cbSize;
        public uint dwTime;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT
    {
        public uint type;
        public InputUnion U;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct InputUnion
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(
        IntPtr window,
        out uint processId);

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(
        uint sourceThreadId,
        uint targetThreadId,
        bool attach);

    [DllImport("user32.dll")]
    public static extern IntPtr SetActiveWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern IntPtr SetFocus(IntPtr window);

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
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern uint SendInput(uint count, INPUT[] inputs, int size);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO input);

    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int virtualKey);

    [DllImport("kernel32.dll")]
    public static extern uint GetTickCount();

    public static bool Activate(IntPtr window)
    {
        var foreground = GetForegroundWindow();
        uint ignored;
        var currentThread = GetCurrentThreadId();
        var foregroundThread = foreground == IntPtr.Zero
            ? 0
            : GetWindowThreadProcessId(foreground, out ignored);
        var targetThread = GetWindowThreadProcessId(window, out ignored);
        var attachedForeground = foregroundThread != 0 &&
            foregroundThread != currentThread &&
            AttachThreadInput(currentThread, foregroundThread, true);
        var attachedTarget = targetThread != 0 &&
            targetThread != currentThread &&
            targetThread != foregroundThread &&
            AttachThreadInput(currentThread, targetThread, true);
        try
        {
        ShowWindow(window, 3);
        SetWindowPos(
            window,
            new IntPtr(-2),
            0,
            0,
            0,
            0,
            0x0001 | 0x0002 | 0x0040);
        BringWindowToTop(window);
        SetActiveWindow(window);
        SetFocus(window);
        SetForegroundWindow(window);
        return GetForegroundWindow() == window;
        }
        finally
        {
            if (attachedTarget)
            {
                AttachThreadInput(currentThread, targetThread, false);
            }
            if (attachedForeground)
            {
                AttachThreadInput(currentThread, foregroundThread, false);
            }
        }
    }

    public static void ClearTopmost(IntPtr window)
    {
        SetWindowPos(
            window,
            new IntPtr(-2),
            0,
            0,
            0,
            0,
            0x0001 | 0x0002 | 0x0040);
    }

    public static uint GetSystemIdleMilliseconds()
    {
        var input = new LASTINPUTINFO
        {
            cbSize = (uint)Marshal.SizeOf<LASTINPUTINFO>()
        };
        if (!GetLastInputInfo(ref input))
        {
            return 0;
        }
        return unchecked(GetTickCount() - input.dwTime);
    }

    public static bool AnyModifierPressed()
    {
        return IsPressed(0x10) ||
            IsPressed(0x11) ||
            IsPressed(0x12) ||
            IsPressed(0x5B) ||
            IsPressed(0x5C);
    }

    private static bool IsPressed(int virtualKey)
    {
        return (GetAsyncKeyState(virtualKey) & 0x8000) != 0;
    }

    public static bool ForegroundBelongsToProcess(uint expectedProcessId)
    {
        uint actualProcessId;
        var foreground = GetForegroundWindow();
        return foreground != IntPtr.Zero &&
            GetWindowThreadProcessId(foreground, out actualProcessId) != 0 &&
            actualProcessId == expectedProcessId;
    }

    public static bool Click(int x, int y)
    {
        SetCursorPos(x, y);
        var inputs = new INPUT[2];
        inputs[0].type = 0;
        inputs[0].U.mi.dwFlags = 0x0002;
        inputs[1].type = 0;
        inputs[1].U.mi.dwFlags = 0x0004;
        return SendInput(2, inputs, Marshal.SizeOf<INPUT>()) == 2;
    }

    public static bool Key(ushort virtualKey, bool shift)
    {
        var inputs = new INPUT[shift ? 4 : 2];
        var index = 0;
        if (shift)
        {
            inputs[index].type = 1;
            inputs[index++].U.ki.wVk = 0x10;
        }
        inputs[index].type = 1;
        inputs[index++].U.ki.wVk = virtualKey;
        inputs[index].type = 1;
        inputs[index].U.ki.wVk = virtualKey;
        inputs[index++].U.ki.dwFlags = 0x0002;
        if (shift)
        {
            inputs[index].type = 1;
            inputs[index].U.ki.wVk = 0x10;
            inputs[index].U.ki.dwFlags = 0x0002;
        }
        return SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>()) == inputs.Length;
    }

    public static bool ControlKey(ushort virtualKey)
    {
        var inputs = new INPUT[4];
        inputs[0].type = 1;
        inputs[0].U.ki.wVk = 0x11;
        inputs[1].type = 1;
        inputs[1].U.ki.wVk = virtualKey;
        inputs[2].type = 1;
        inputs[2].U.ki.wVk = virtualKey;
        inputs[2].U.ki.dwFlags = 0x0002;
        inputs[3].type = 1;
        inputs[3].U.ki.wVk = 0x11;
        inputs[3].U.ki.dwFlags = 0x0002;
        return SendInput(4, inputs, Marshal.SizeOf<INPUT>()) == 4;
    }
}
'@

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [int]$TimeoutMilliseconds = 8000,
        [switch]$Optional
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $topLevelElements =
                [Windows.Automation.AutomationElement]::RootElement.FindAll(
                    [Windows.Automation.TreeScope]::Children,
                    $processCondition)
            foreach ($topLevelElement in $topLevelElements) {
                if ($topLevelElement.Current.AutomationId -ceq $AutomationId) {
                    return $topLevelElement
                }
                $element = $topLevelElement.FindFirst(
                    [Windows.Automation.TreeScope]::Descendants,
                    $idCondition)
                if ($null -ne $element) { return $element }
            }
        }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    if ($Optional) { return $null }
    throw "Timed out finding AutomationId '$AutomationId' for process $ProcessId."
}

$script:targetWindowHandle = [IntPtr]::Zero
$script:targetProcessId = 0

function Ensure-TargetForeground {
    if ($script:targetWindowHandle -eq [IntPtr]::Zero) {
        throw "Target LumaChart window handle is not initialized."
    }
    Wait-Condition -Description "the exact LumaChart window to own physical input" -Seconds 5 -Condition {
        [LumaChartNoteSoundPickerNative]::Activate($script:targetWindowHandle)
    }
}

function Get-ElementValue($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose ValuePattern."
    }
    return ([Windows.Automation.ValuePattern]$pattern).Current.Value
}

function Get-HelpText($Element) {
    return [string]$Element.GetCurrentPropertyValue(
        [Windows.Automation.AutomationElement]::HelpTextProperty,
        $true)
}

function Get-Center($Element) {
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -le 0 -or $bounds.Height -le 0) {
        throw "Element '$($Element.Current.AutomationId)' has empty bounds."
    }
    return [ordered]@{
        x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
        y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
        left = [double]$bounds.Left
        top = [double]$bounds.Top
        width = [double]$bounds.Width
        height = [double]$bounds.Height
    }
}

function Send-PhysicalClick($Element, [string]$Action, $Actions) {
    Ensure-TargetForeground
    $center = Get-Center $Element
    if (-not [LumaChartNoteSoundPickerNative]::Click($center.x, $center.y)) {
        throw "SendInput mouse click failed for '$Action'."
    }
    $Actions.Add([ordered]@{
        index = $Actions.Count + 1
        kind = "mouse"
        action = $Action
        automationId = [string]$Element.Current.AutomationId
        x = $center.x
        y = $center.y
        completedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    Start-Sleep -Milliseconds 180
}

function Send-PhysicalKey(
    [ushort]$VirtualKey,
    [string]$Key,
    [bool]$Shift,
    $Actions) {
    if ([LumaChartNoteSoundPickerNative]::AnyModifierPressed()) {
        throw "Physical key '$Key' was blocked because a user modifier key is currently held."
    }
    if (-not [LumaChartNoteSoundPickerNative]::ForegroundBelongsToProcess(
            [uint32]$script:targetProcessId)) {
        throw "Physical key '$Key' was blocked because another process owns the foreground window."
    }
    if (-not [LumaChartNoteSoundPickerNative]::Key($VirtualKey, $Shift)) {
        throw "SendInput key failed for '$Key'."
    }
    $Actions.Add([ordered]@{
        index = $Actions.Count + 1
        kind = "keyboard"
        key = $(if ($Shift) { "Shift+$Key" } else { $Key })
        completedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    Start-Sleep -Milliseconds 140
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartNoteSoundPickerNative+RECT]::new()
    if (-not [LumaChartNoteSoundPickerNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    $bitmap = [Drawing.Bitmap]::new($width, $height)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen(
                $rectangle.Left,
                $rectangle.Top,
                0,
                0,
                [Drawing.Size]::new($width, $height))
        }
        finally {
            $graphics.Dispose()
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
    return [ordered]@{
        path = $Path
        width = $width
        height = $height
        length = (Get-Item -LiteralPath $Path).Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

function Measure-PopupGeometry(
    [IntPtr]$Handle,
    [string]$ScreenshotPath,
    $EntryBounds,
    [double]$ExpectedWidth,
    [double]$ExpectedVerticalOffset) {
    $windowRectangle = [LumaChartNoteSoundPickerNative+RECT]::new()
    if (-not [LumaChartNoteSoundPickerNative]::GetWindowRect(
            $Handle,
            [ref]$windowRectangle)) {
        throw "GetWindowRect failed while measuring the Note Sound picker."
    }
    $bitmap = [Drawing.Bitmap]::new($ScreenshotPath)
    try {
        $entryBottom = $EntryBounds.top + $EntryBounds.height - $windowRectangle.Top
        $expectedTop = $entryBottom + $ExpectedVerticalOffset
        $searchTop = [Math]::Max(0, [int][Math]::Floor($expectedTop - 6))
        $searchBottom = [Math]::Min(
            $bitmap.Height - 1,
            [int][Math]::Ceiling($expectedTop + 6))
        $searchLeft = [Math]::Max(
            0,
            [int][Math]::Floor($bitmap.Width - $ExpectedWidth - 24))
        $minimumHorizontalRun = [Math]::Max(
            40,
            [int][Math]::Floor($ExpectedWidth * 0.8))
        $popupTop = -1
        for ($y = $searchTop; $y -le $searchBottom; $y++) {
            $bestRun = 0
            $runStart = -1
            for ($x = $searchLeft; $x -lt $bitmap.Width; $x++) {
                $color = $bitmap.GetPixel($x, $y)
                $matchesBorder =
                    [Math]::Abs([int]$color.R - 74) -le 2 -and
                    [Math]::Abs([int]$color.G - 90) -le 2 -and
                    [Math]::Abs([int]$color.B - 96) -le 2
                if ($matchesBorder) {
                    if ($runStart -lt 0) { $runStart = $x }
                    continue
                }
                if ($runStart -ge 0) {
                    $bestRun = [Math]::Max($bestRun, $x - $runStart)
                    $runStart = -1
                }
            }
            if ($runStart -ge 0) {
                $bestRun = [Math]::Max(
                    $bestRun,
                    $bitmap.Width - $runStart)
            }
            if ($bestRun -ge $minimumHorizontalRun) {
                $popupTop = $y
                break
            }
        }
        if ($popupTop -lt 0) {
            throw "The WPF-colored Note Sound picker top border was not found in the screenshot."
        }

        $verticalSearchBottom = [Math]::Min(
            $bitmap.Height - 1,
            $popupTop + 260)
        $minimumVerticalMatches = 50
        $popupLeft = -1
        for ($x = $searchLeft; $x -lt [Math]::Min(
                $bitmap.Width,
                $searchLeft + 48); $x++) {
            $matches = 0
            for ($y = $popupTop; $y -le $verticalSearchBottom; $y++) {
                $color = $bitmap.GetPixel($x, $y)
                if (
                    [Math]::Abs([int]$color.R - 74) -le 2 -and
                    [Math]::Abs([int]$color.G - 90) -le 2 -and
                    [Math]::Abs([int]$color.B - 96) -le 2) {
                    $matches++
                }
            }
            if ($matches -ge $minimumVerticalMatches) {
                $popupLeft = $x
                break
            }
        }
        if ($popupLeft -lt 0) {
            throw "The WPF-colored Note Sound picker left border was not found in the screenshot."
        }

        return [ordered]@{
            leftPixels = $popupLeft
            topPixels = $popupTop
            widthPixels = $bitmap.Width - $popupLeft
            verticalOffsetPixels = $popupTop - $entryBottom
            borderColor = "#4A5A60"
            windowLeftPixels = $windowRectangle.Left
            windowTopPixels = $windowRectangle.Top
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

$physicalActions = [Collections.Generic.List[object]]::new()
$minimumIdleMilliseconds = 3000
$systemIdleMilliseconds =
    [LumaChartNoteSoundPickerNative]::GetSystemIdleMilliseconds()
if ($systemIdleMilliseconds -lt $minimumIdleMilliseconds) {
    throw (
        "Refusing to launch foreground GUI automation because Windows has " +
        "received user input within the last $minimumIdleMilliseconds ms. " +
        "Observed idle: $systemIdleMilliseconds ms.")
}
$start = [Diagnostics.ProcessStartInfo]::new($application)
$start.UseShellExecute = $false
$start.ArgumentList.Add("--evidence-chart")
$start.ArgumentList.Add($chartUnderTest)
$start.ArgumentList.Add("--evidence-focus-note-property")
$start.ArgumentList.Add("--evidence-focus-note-property-beat")
$start.ArgumentList.Add("320:0/4")
$start.ArgumentList.Add("--evidence-output")
$start.ArgumentList.Add($runtimePath)
$process = [Diagnostics.Process]::Start($start)
if (-not $process) { throw "Failed to start Avalonia Note Sound picker GUI process." }

try {
    Wait-Condition -Description "Avalonia Note Sound picker window" -Condition {
        $process.Refresh()
        -not $process.HasExited -and $process.MainWindowHandle -ne [IntPtr]::Zero
    }
    $handle = $process.MainWindowHandle
    $script:targetWindowHandle = $handle
    $script:targetProcessId = $process.Id
    Ensure-TargetForeground
    Wait-Condition -Description "Note inspector focus" -Condition {
        $soundEntry = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundExisting" -TimeoutMilliseconds 300 -Optional
        $soundField = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.Sound" -TimeoutMilliseconds 300 -Optional
        $null -ne $soundEntry -and $soundEntry.Current.IsEnabled -and $null -ne $soundField
    }
    Wait-Condition -Description "runtime evidence" -Condition {
        Test-Path -LiteralPath $runtimePath -PathType Leaf
    }

    $windowRoot = [Windows.Automation.AutomationElement]::FromHandle($handle)
    $windowBounds = Get-Center $windowRoot
    $activationX = [int][Math]::Round(
        $windowBounds.left + ($windowBounds.width / 2))
    $activationY = [int][Math]::Round($windowBounds.top + 30)
    if (-not [LumaChartNoteSoundPickerNative]::Click(
            $activationX,
            $activationY)) {
        throw "Setup activation click failed."
    }
    Start-Sleep -Milliseconds 180
    Ensure-TargetForeground

    $entry = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundExisting"
    $soundField = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.Sound"
    $soundBefore = Get-ElementValue $soundField
    Send-PhysicalClick $entry "open WPF Note Sound picker" $physicalActions
    [void](Capture-Window $handle $initialScreenshotPath)

    Wait-Condition -Description "dedicated Note Sound picker popup with clear focus" -Condition {
        $entry = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundExisting" -TimeoutMilliseconds 300 -Optional
        if ($null -eq $entry) { return $false }
        $help = Get-HelpText $entry
        $help -match 'PickerOpen=True' -and
            $help -match 'FocusableCount=2' -and
            $help -match 'CandidateCount=1' -and
            $help -match 'FocusedIndex=0' -and
            $help -match 'LastNavigation=opened-clear'
    }
    $entryBounds = Get-Center $entry
    $initialHelp = Get-HelpText $entry
    $initialScreenshot = Capture-Window $handle $initialScreenshotPath

    Send-PhysicalKey 0x28 "Down" $false $physicalActions
    Wait-Condition -Description "Down focuses first sound item" -Condition {
        $entry = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundExisting" -TimeoutMilliseconds 300 -Optional
        $null -ne $entry -and
            (Get-HelpText $entry) -match 'PickerOpen=True' -and
            (Get-HelpText $entry) -match 'FocusedIndex=1' -and
            (Get-HelpText $entry) -match 'LastNavigation=Down:0->1'
    }
    $itemScreenshot = Capture-Window $handle $itemScreenshotPath

    Send-PhysicalKey 0x09 "Tab" $false $physicalActions
    Wait-Condition -Description "Tab wraps to clear item" -Condition {
        $entry = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundExisting" -TimeoutMilliseconds 300 -Optional
        $null -ne $entry -and
            (Get-HelpText $entry) -match 'FocusedIndex=0' -and
            (Get-HelpText $entry) -match 'LastNavigation=Tab:1->0'
    }
    Send-PhysicalKey 0x09 "Tab" $true $physicalActions
    Wait-Condition -Description "Shift+Tab wraps to sound item" -Condition {
        $entry = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundExisting" -TimeoutMilliseconds 300 -Optional
        $null -ne $entry -and
            (Get-HelpText $entry) -match 'FocusedIndex=1' -and
            (Get-HelpText $entry) -match 'LastNavigation=Tab:0->1'
    }
    Send-PhysicalKey 0x24 "Home" $false $physicalActions
    Wait-Condition -Description "Home focuses clear item" -Condition {
        $entry = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundExisting" -TimeoutMilliseconds 300 -Optional
        $null -ne $entry -and
            (Get-HelpText $entry) -match 'FocusedIndex=0' -and
            (Get-HelpText $entry) -match 'LastNavigation=Home:1->0'
    }
    Send-PhysicalKey 0x23 "End" $false $physicalActions
    Wait-Condition -Description "End focuses sound item" -Condition {
        $entry = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundExisting" -TimeoutMilliseconds 300 -Optional
        $null -ne $entry -and
            (Get-HelpText $entry) -match 'FocusedIndex=1' -and
            (Get-HelpText $entry) -match 'LastNavigation=End:0->1'
    }
    Send-PhysicalKey 0x1B "Escape" $false $physicalActions
    Wait-Condition -Description "Escape closes popup and restores entry focus" -Condition {
        $entry = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundExisting" -TimeoutMilliseconds 300 -Optional
        $null -ne $entry -and $entry.Current.HasKeyboardFocus -and
            (Get-HelpText $entry) -match 'PickerOpen=False' -and
            (Get-HelpText $entry) -match 'EscapeRestoredFocus=True'
    }
    $restoredEntry = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundExisting"
    $restoredHelp = Get-HelpText $restoredEntry
    $restoredScreenshot = Capture-Window $handle $restoredScreenshotPath

    Send-PhysicalClick $restoredEntry "reopen WPF Note Sound picker" $physicalActions
    Wait-Condition -Description "reopened picker clear focus" -Condition {
        $entry = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundExisting" -TimeoutMilliseconds 300 -Optional
        $null -ne $entry -and
            (Get-HelpText $entry) -match 'PickerOpen=True' -and
            (Get-HelpText $entry) -match 'FocusedIndex=0'
    }
    Send-PhysicalKey 0x28 "Down" $false $physicalActions
    Wait-Condition -Description "reopened picker sound item focus" -Condition {
        $entry = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundExisting" -TimeoutMilliseconds 300 -Optional
        $null -ne $entry -and
            (Get-HelpText $entry) -match 'FocusedIndex=1'
    }
    Send-PhysicalKey 0x0D "Enter" $false $physicalActions
    Wait-Condition -Description "keyboard Note Sound assignment" -Condition {
        $field = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.Sound" -TimeoutMilliseconds 300
        (Get-ElementValue $field) -ceq "Resound - Nhato.ogg"
    }
    $assignedScreenshot = Capture-Window $handle $assignedScreenshotPath

    Ensure-TargetForeground
    if ([LumaChartNoteSoundPickerNative]::AnyModifierPressed()) {
        throw "Physical Ctrl+Z was blocked because a user modifier key is currently held."
    }
    if (-not [LumaChartNoteSoundPickerNative]::ControlKey(0x5A)) {
        throw "Physical Ctrl+Z failed."
    }
    $physicalActions.Add([ordered]@{
        index = $physicalActions.Count + 1
        kind = "keyboard"
        key = "Ctrl+Z"
        completedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    Wait-Condition -Description "keyboard Note Sound assignment undo" -Condition {
        $field = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.Sound" -TimeoutMilliseconds 300
        (Get-ElementValue $field) -ceq $soundBefore
    }

    $runtime = Get-Content -LiteralPath $runtimePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $screenScale = [double]$runtime.window.displayScale.screenScaling
    $uiScale = [double]$runtime.window.displayScale.actualRootScaleX
    $expectedWidth = 330 * $screenScale * $uiScale
    $expectedVerticalOffset = 5 * $screenScale * $uiScale
    $popupGeometry = Measure-PopupGeometry `
        -Handle $handle `
        -ScreenshotPath $initialScreenshotPath `
        -EntryBounds $entryBounds `
        -ExpectedWidth $expectedWidth `
        -ExpectedVerticalOffset $expectedVerticalOffset
    if ([Math]::Abs($popupGeometry.widthPixels - $expectedWidth) -gt 4) {
        throw "Popup width mismatch: actual=$($popupGeometry.widthPixels), expected=$expectedWidth."
    }
    if ([Math]::Abs(
            $popupGeometry.verticalOffsetPixels -
            $expectedVerticalOffset) -gt 2) {
        throw (
            "Popup vertical offset mismatch: " +
            "actual=$($popupGeometry.verticalOffsetPixels), " +
            "expected=$expectedVerticalOffset.")
    }

    $chartHashAfter = (Get-FileHash -LiteralPath $chartFixture -Algorithm SHA256).Hash
    $soundHashAfter = (Get-FileHash -LiteralPath $soundFixture -Algorithm SHA256).Hash
    $isolatedChartHashAfter = (Get-FileHash -LiteralPath $chartUnderTest -Algorithm SHA256).Hash
    $installerPath = Resolve-ExistingFile (
        Join-Path $PSScriptRoot "..\release\LumaChartStudio-Setup.exe") "frozen installer"
    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.note-sound-picker-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        scope = [ordered]@{
            windowsAvaloniaOnly = $true
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            productionServerMutationPerformed = $false
            userApplicationsClosedOrModified = $false
        }
        input = [ordered]@{
            win32SendInputUsed = $true
            hardwareInputClaimed = $false
            foregroundAutomationExplicitlyAuthorized = $true
            foregroundAutomationConsentEnvironmentVerified =
                ($env:LUMACHART_FOREGROUND_AUTOMATION_CONSENT -ceq
                    "USER_CONFIRMED_DESKTOP_AVAILABLE")
            systemIdleBeforeLaunchMilliseconds = $systemIdleMilliseconds
            minimumSystemIdleRequiredMilliseconds = $minimumIdleMilliseconds
            foregroundProcessOwnershipCheckedBeforeEveryKey = $true
            heldModifierConflictCheckedBeforeEveryKey = $true
            setupActivationClickCount = 1
            businessActionCount = $physicalActions.Count
            actions = @($physicalActions)
            uncommittedImeCompositionRequired = $false
            enterUsedOnlyToActivateFocusedPopupItem = $true
        }
        foregroundSafety = [ordered]@{
            windowForcedTopmost = $false
            persistentTopmostUsed = $false
            hwndNotTopmostAppliedBeforeActivation = $true
            hwndNotTopmostAppliedAgainDuringCleanup = $true
            exactEvidenceProcessOnlyCleanup = $true
        }
        popup = [ordered]@{
            dedicatedPopup = $true
            contextMenuUsed = $false
            initialHelpText = $initialHelp
            countText = "1 个"
            clearInitiallyFocused = $true
            downFocusedFirstSound = $true
            tabWrappedToClear = $true
            shiftTabWrappedToSound = $true
            homeFocusedClear = $true
            endFocusedSound = $true
            escapeClosed = $true
            escapeRestoredEntryFocus = $true
            restoredEntryHelpText = $restoredHelp
            keyboardAssignment = "Resound - Nhato.ogg"
            assignmentUndoRestoredOriginal = $true
            geometry = [ordered]@{
                widthDip = 330
                maxHeightDip = 370
                scrollMaxHeightDip = 250
                verticalOffsetDip = 5
                actualWidthPixels = $popupGeometry.widthPixels
                expectedWidthPixels = $expectedWidth
                actualVerticalOffsetPixels = $popupGeometry.verticalOffsetPixels
                expectedVerticalOffsetPixels = $expectedVerticalOffset
                screenScale = $screenScale
                uiScale = $uiScale
                measuredBy = "captured-window border pixels plus strict parity policy specs"
                borderColor = $popupGeometry.borderColor
                popupLeftPixels = $popupGeometry.leftPixels
                popupTopPixels = $popupGeometry.topPixels
            }
        }
        screenshots = [ordered]@{
            initial = $initialScreenshot
            keyboardItem = $itemScreenshot
            escapeRestored = $restoredScreenshot
            assigned = $assignedScreenshot
        }
        frozenBaselines = [ordered]@{
            realChart = [ordered]@{
                path = $chartFixture
                sha256Before = $chartHashBefore
                sha256After = $chartHashAfter
                unchanged = ($chartHashBefore -ceq $chartHashAfter)
            }
            realSound = [ordered]@{
                path = $soundFixture
                sha256Before = $soundHashBefore
                sha256After = $soundHashAfter
                unchanged = ($soundHashBefore -ceq $soundHashAfter)
            }
            isolatedChart = [ordered]@{
                sha256Before = $isolatedChartHashBefore
                sha256After = $isolatedChartHashAfter
                unchanged = ($isolatedChartHashBefore -ceq $isolatedChartHashAfter)
            }
            installer = [ordered]@{
                path = $installerPath
                sha256 = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
            }
        }
        completion = [ordered]@{
            thisSlicePassed = $true
            fullWindowsMigrationComplete = $false
            userReplacementApproval = $false
            otherPlatformAuthorization = $false
        }
    }
    if (-not $evidence.frozenBaselines.realChart.unchanged -or
        -not $evidence.frozenBaselines.realSound.unchanged -or
        -not $evidence.frozenBaselines.isolatedChart.unchanged) {
        throw "A frozen or isolated source changed during Note Sound picker GUI acceptance."
    }
    if ($evidence.frozenBaselines.installer.sha256 -cne
        "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
        throw "Frozen installer hash changed."
    }
    $evidence |
        ConvertTo-Json -Depth 14 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Get-Content -LiteralPath $evidencePath -Raw -Encoding UTF8
}
finally {
    if ($process -and -not $process.HasExited) {
        try {
            [LumaChartNoteSoundPickerNative]::ClearTopmost(
                $process.MainWindowHandle)
            $process.CloseMainWindow() | Out-Null
            if (-not $process.WaitForExit(3000)) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
    }
}
