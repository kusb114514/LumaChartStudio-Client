param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [switch]$FormalMigrationAuthority,
    [switch]$ActualImeComposition,
    [switch]$ImeCandidateEdges,
    [switch]$ImeCandidateEdgesOnly,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia library-shell GUI capture requires PowerShell Core on Windows."
}
if ($ImeCandidateEdges -and -not $ActualImeComposition) {
    throw "-ImeCandidateEdges requires -ActualImeComposition."
}
if ($ImeCandidateEdgesOnly -and -not $ImeCandidateEdges) {
    throw "-ImeCandidateEdgesOnly requires -ImeCandidateEdges."
}

function Resolve-ExistingFile([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "$Label not found: $full" }
    return $full
}

function Wait-Condition {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Condition,
        [Parameter(Mandatory = $true)][string]$Description,
        [int]$Seconds = $TimeoutSeconds,
        [int]$PollMilliseconds = 75
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try { if (& $Condition) { return } } catch { }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

function Get-Fingerprint([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        bytes = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        lastWriteUtcTicks = [long]$item.LastWriteTimeUtc.Ticks
    }
}

function Assert-Unchanged($Before, [string]$Label) {
    $after = Get-Fingerprint $Before.path
    if ($after.bytes -ne $Before.bytes -or $after.sha256 -cne $Before.sha256 -or
        $after.lastWriteUtcTicks -ne $Before.lastWriteUtcTicks) {
        throw "$Label changed during library-shell verification."
    }
    return $after
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartLibraryShellNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }

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

    [StructLayout(LayoutKind.Sequential)]
    public struct HARDWAREINPUT
    {
        public uint uMsg;
        public ushort wParamL;
        public ushort wParamH;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct INPUTUNION
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT
    {
        public uint type;
        public INPUTUNION U;
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr window, IntPtr deviceContext, uint flags);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT point);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr LoadKeyboardLayout(string keyboardLayoutId, uint flags);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("user32.dll")]
    public static extern IntPtr GetKeyboardLayout(uint threadId);

    [DllImport("imm32.dll")]
    private static extern IntPtr ImmGetContext(IntPtr window);

    [DllImport("imm32.dll")]
    private static extern bool ImmSetOpenStatus(IntPtr inputContext, bool open);

    [DllImport("imm32.dll")]
    private static extern bool ImmReleaseContext(IntPtr window, IntPtr inputContext);

    [DllImport("user32.dll")]
    public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr value);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint inputCount, INPUT[] inputs, int inputSize);

    [DllImport("kernel32.dll", EntryPoint = "SetLastError")]
    private static extern void ClearLastError(uint errorCode);

    public static int LastSendInputError { get; private set; }

    public static uint SendUnicodeText(string text)
    {
        if (text == null) throw new ArgumentNullException(nameof(text));
        const uint INPUT_KEYBOARD = 1;
        const uint KEYEVENTF_KEYUP = 0x0002;
        const uint KEYEVENTF_UNICODE = 0x0004;
        var inputs = new INPUT[text.Length * 2];
        var index = 0;
        foreach (var character in text)
        {
            inputs[index++] = new INPUT
            {
                type = INPUT_KEYBOARD,
                U = new INPUTUNION
                {
                    ki = new KEYBDINPUT
                    {
                        wScan = character,
                        dwFlags = KEYEVENTF_UNICODE,
                        dwExtraInfo = UIntPtr.Zero
                    }
                }
            };
            inputs[index++] = new INPUT
            {
                type = INPUT_KEYBOARD,
                U = new INPUTUNION
                {
                    ki = new KEYBDINPUT
                    {
                        wScan = character,
                        dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP,
                        dwExtraInfo = UIntPtr.Zero
                    }
                }
            };
        }
        ClearLastError(0);
        var sent = SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>());
        LastSendInputError = Marshal.GetLastWin32Error();
        return sent;
    }

    public static void SendVirtualKey(byte virtualKey)
    {
        const uint KEYEVENTF_KEYUP = 0x0002;
        keybd_event(virtualKey, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(35);
        keybd_event(virtualKey, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        System.Threading.Thread.Sleep(45);
    }

    public static bool EnsureImeOpen(IntPtr window)
    {
        var context = ImmGetContext(window);
        if (context == IntPtr.Zero)
            return false;
        try
        {
            return ImmSetOpenStatus(context, true);
        }
        finally
        {
            ImmReleaseContext(window, context);
        }
    }
}
'@

[LumaChartLibraryShellNative]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 180000)][int]$TimeoutMilliseconds = 10000,
        [switch]$Optional
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
                $candidate = $root.FindFirst([Windows.Automation.TreeScope]::Descendants, $idCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    if ($Optional) { return $null }
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Get-ElementState($Element) {
    $bounds = $Element.Current.BoundingRectangle
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        helpText = [string]$Element.Current.HelpText
        isEnabled = [bool]$Element.Current.IsEnabled
        isOffscreen = [bool]$Element.Current.IsOffscreen
        hasKeyboardFocus = [bool]$Element.Current.HasKeyboardFocus
        bounds = [ordered]@{
            left = $bounds.Left
            top = $bounds.Top
            width = $bounds.Width
            height = $bounds.Height
        }
    }
}

function Get-OptionalElementState($Element, [string]$AutomationId) {
    if (-not $Element) {
        return [ordered]@{
            automationId = $AutomationId
            presentInUiaTree = $false
            isOffscreen = $true
        }
    }
    $state = Get-ElementState $Element
    $state["presentInUiaTree"] = $true
    return $state
}

function Get-ElementValue($Element) {
    $pattern = $Element.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern)
    return [string]$pattern.Current.Value
}

function Click-Element($Element) {
    if (-not $Element.Current.IsEnabled -or $Element.Current.IsOffscreen) {
        throw "Element '$($Element.Current.AutomationId)' is not physically clickable."
    }
    $bounds = $Element.Current.BoundingRectangle
    $x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    if (-not [LumaChartLibraryShellNative]::SetCursorPos($x, $y)) {
        throw "SetCursorPos failed for '$($Element.Current.AutomationId)'."
    }
    Start-Sleep -Milliseconds 90
    [LumaChartLibraryShellNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 45
    [LumaChartLibraryShellNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        x = $x
        y = $y
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Send-CtrlF {
    [LumaChartLibraryShellNative]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero)
    [LumaChartLibraryShellNative]::keybd_event(0x46, 0, 0, [UIntPtr]::Zero)
    [LumaChartLibraryShellNative]::keybd_event(0x46, 0, 2, [UIntPtr]::Zero)
    [LumaChartLibraryShellNative]::keybd_event(0x11, 0, 2, [UIntPtr]::Zero)
    return [ordered]@{
        gesture = "Ctrl+F"
        input = "Win32 keybd_event physical virtual keys"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Send-CtrlAAndBackspace {
    [LumaChartLibraryShellNative]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero)
    [LumaChartLibraryShellNative]::SendVirtualKey(0x41)
    [LumaChartLibraryShellNative]::keybd_event(0x11, 0, 2, [UIntPtr]::Zero)
    [LumaChartLibraryShellNative]::SendVirtualKey(0x08)
    return [ordered]@{
        gesture = "Ctrl+A, Backspace"
        input = "Win32 keybd_event physical virtual keys"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Activate-MicrosoftPinyin([IntPtr]$Handle) {
    $keyboardLayout = [LumaChartLibraryShellNative]::LoadKeyboardLayout("00000804", 1)
    if ($keyboardLayout -eq [IntPtr]::Zero) {
        throw "LoadKeyboardLayout failed for zh-CN 00000804."
    }
    if (-not [LumaChartLibraryShellNative]::PostMessage(
            $Handle, 0x0050, [IntPtr]::Zero, $keyboardLayout)) {
        throw "WM_INPUTLANGCHANGEREQUEST failed for the Avalonia window."
    }
    [uint32]$targetProcessId = 0
    $threadId = [LumaChartLibraryShellNative]::GetWindowThreadProcessId(
        $Handle, [ref]$targetProcessId)
    Wait-Condition -Description "zh-CN keyboard layout on Avalonia UI thread" -Condition {
        $active = [LumaChartLibraryShellNative]::GetKeyboardLayout($threadId).ToInt64()
        ($active -band 0xffff) -eq 0x0804
    }
    $activeLayout = [LumaChartLibraryShellNative]::GetKeyboardLayout($threadId)
    $imeOpenRequested =
        [LumaChartLibraryShellNative]::EnsureImeOpen($Handle)
    $profiles = @()
    $languageList = Get-WinUserLanguageList -ErrorAction Stop
    foreach ($language in $languageList) {
        if ($language.LanguageTag -ceq "zh-Hans-CN") {
            $profiles += @($language.InputMethodTips)
        }
    }
    $microsoftPinyinTip =
        "0804:{6573078D-A793-4CD9-A6E6-0FFB01F35262}{CE7B668C-8260-4496-AEE0-5305D3FB8E0E}"
    if ($profiles -notcontains $microsoftPinyinTip) {
        throw "The configured zh-CN input profile is not Microsoft Pinyin."
    }
    return [ordered]@{
        requestedKeyboardLayout = ("0x{0:X}" -f $keyboardLayout.ToInt64())
        activeKeyboardLayout = ("0x{0:X}" -f $activeLayout.ToInt64())
        activeLanguageId = "0x0804"
        targetThreadId = [long]$threadId
        targetProcessId = [long]$targetProcessId
        configuredInputMethodTip = $microsoftPinyinTip
        inputMethod = "Microsoft Pinyin"
        imeOpenRequested = $imeOpenRequested
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Send-PhysicalAsciiText([string]$Text) {
    if ($Text -notmatch '^[A-Za-z]+$') {
        throw "Physical IME source text must contain only ASCII letters."
    }
    foreach ($character in $Text.ToUpperInvariant().ToCharArray()) {
        [LumaChartLibraryShellNative]::SendVirtualKey([byte][char]$character)
    }
    return [ordered]@{
        input = "Win32 keybd_event physical virtual keys"
        text = $Text.ToLowerInvariant()
        physicalKeyCount = $Text.Length
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Send-SpaceCandidateCommit {
    [LumaChartLibraryShellNative]::SendVirtualKey(0x20)
    return [ordered]@{
        gesture = "Space"
        input = "Win32 keybd_event physical virtual key"
        purpose = "commit first Microsoft Pinyin candidate"
        enterKeySent = $false
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Send-ImeCandidatePageDown {
    [LumaChartLibraryShellNative]::SendVirtualKey(0x22)
    return [ordered]@{
        gesture = "PageDown"
        input = "Win32 keybd_event physical virtual key"
        purpose = "page Microsoft Pinyin candidates without committing text"
        enterKeySent = $false
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Send-ImeCompositionEscape {
    [LumaChartLibraryShellNative]::SendVirtualKey(0x1B)
    return [ordered]@{
        gesture = "Escape"
        input = "Win32 keybd_event physical virtual key"
        purpose = "cancel Microsoft Pinyin composition without leaving the text host"
        enterKeySent = $false
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Send-ImeChineseModeToggle {
    [LumaChartLibraryShellNative]::SendVirtualKey(0x10)
    return [ordered]@{
        gesture = "Shift"
        input = "Win32 keybd_event physical virtual key"
        purpose = "switch configured Microsoft Pinyin from Latin mode to Chinese mode"
        enterKeySent = $false
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Send-ImeActivationHotkey {
    [LumaChartLibraryShellNative]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero)
    [LumaChartLibraryShellNative]::SendVirtualKey(0x20)
    [LumaChartLibraryShellNative]::keybd_event(0x11, 0, 2, [UIntPtr]::Zero)
    return [ordered]@{
        gesture = "Ctrl+Space"
        input = "Win32 keybd_event physical virtual keys"
        purpose = "activate the configured Microsoft Pinyin text service"
        enterKeySent = $false
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Send-AltF4 {
    [LumaChartLibraryShellNative]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
    [LumaChartLibraryShellNative]::SendVirtualKey(0x73)
    [LumaChartLibraryShellNative]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    return [ordered]@{
        gesture = "Alt+F4"
        input = "Win32 keybd_event physical virtual keys"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Capture-PhysicalScreenWindow([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartLibraryShellNative+RECT]::new()
    if (-not [LumaChartLibraryShellNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 800 -or $height -lt 500) {
        throw "Invalid physical screen capture bounds $($width)x$height."
    }
    $bitmap = [Drawing.Bitmap]::new(
        $width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen(
                $rectangle.Left, $rectangle.Top, 0, 0,
                [Drawing.Size]::new($width, $height),
                [Drawing.CopyPixelOperation]::SourceCopy)
        }
        finally { $graphics.Dispose() }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            path = [IO.Path]::GetFullPath($Path)
            captureKind = "physical desktop screen including IME candidate overlay"
            width = $width
            height = $height
            sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        }
    }
    finally { $bitmap.Dispose() }
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartLibraryShellNative+RECT]::new()
    if (-not [LumaChartLibraryShellNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 800 -or $height -lt 500) { throw "Invalid window bounds $($width)x$height." }
    $bitmap = [Drawing.Bitmap]::new(
        $width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $dc = $graphics.GetHdc()
            try {
                if (-not [LumaChartLibraryShellNative]::PrintWindow($Handle, $dc, 2)) {
                    throw "PrintWindow failed."
                }
            }
            finally { $graphics.ReleaseHdc($dc) }
        }
        finally { $graphics.Dispose() }
        $colors = [Collections.Generic.HashSet[int]]::new()
        for ($sampleY = 0; $sampleY -lt 16; $sampleY++) {
            for ($sampleX = 0; $sampleX -lt 16; $sampleX++) {
                $pixel = $bitmap.GetPixel(
                    [Math]::Min($width - 1, [int](($sampleX + .5) * $width / 16)),
                    [Math]::Min($height - 1, [int](($sampleY + .5) * $height / 16)))
                [void]$colors.Add($pixel.ToArgb())
            }
        }
        if ($colors.Count -lt 8) { throw "Screenshot is near-uniform: $($colors.Count) colors." }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            path = [IO.Path]::GetFullPath($Path)
            width = $width
            height = $height
            sampledUniqueColors = $colors.Count
            sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        }
    }
    finally { $bitmap.Dispose() }
}

function Stop-TrackedProcess([Diagnostics.Process]$Process) {
    if (-not $Process -or $Process.HasExited) { return }
    $Process.Kill($true)
    [void]$Process.WaitForExit(5000)
}

$application = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$chart = Resolve-ExistingFile $ChartFixturePath "real MC fixture"
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$output = [IO.Path]::GetFullPath($OutputRoot)
$projectBoundary = $projectRoot.TrimEnd('\') + '\'
if (-not $output.StartsWith($projectBoundary, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Output must stay below the project root: $projectBoundary"
}
if (Test-Path -LiteralPath $output) { throw "Output root already exists: $output" }
New-Item -ItemType Directory -Path $output | Out-Null

$localData = Join-Path $output "local-data"
$editing = Join-Path $output "editing"
$workspace = Join-Path $output "workspace"
foreach ($directory in @($localData, $editing, $workspace)) {
    New-Item -ItemType Directory -Path $directory | Out-Null
}
$runtimePath = Join-Path $output "runtime-evidence.json"
$sourceBefore = Get-Fingerprint $chart
$installer = Resolve-ExistingFile (Join-Path $projectRoot "release\LumaChartStudio-Setup.exe") "frozen installer"
$installerBefore = Get-Fingerprint $installer
$process = $null
try {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $application
    $start.WorkingDirectory = Split-Path -Parent $application
    $start.UseShellExecute = $false
    foreach ($argument in @(
            "--evidence-chart", $chart,
            "--evidence-output", $runtimePath,
            "--evidence-interaction-delay-ms", "1800")) {
        $start.ArgumentList.Add($argument)
    }
    $start.Environment["LUMACHART_PROFILE"] = "windows-avalonia-library-shell"
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localData
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
    $start.Environment["DOTNET_CLI_HOME"] = Join-Path $projectRoot ".codex-dotnet-home"
    $start.Environment["NUGET_PACKAGES"] = Join-Path $projectRoot ".codex-nuget-packages"
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = Join-Path $projectRoot ".codex-nuget-http-cache"
    $captureTemp = Join-Path $output "temp"
    New-Item -ItemType Directory -Path $captureTemp | Out-Null
    $start.Environment["TEMP"] = $captureTemp
    $start.Environment["TMP"] = $captureTemp
    $process = [Diagnostics.Process]::Start($start)
    if (-not $process) { throw "Failed to start Windows Avalonia client." }

    Wait-Condition -Description "Avalonia main window" -Condition {
        $process.Refresh()
        -not $process.HasExited -and $process.MainWindowHandle -ne [IntPtr]::Zero
    }
    $handle = $process.MainWindowHandle
    [void][LumaChartLibraryShellNative]::ShowWindow($handle, 3)
    [void][LumaChartLibraryShellNative]::SetForegroundWindow($handle)
    Wait-Condition -Description "runtime evidence" -Condition {
        Test-Path -LiteralPath $runtimePath -PathType Leaf
    }
    $titleLibrary = Find-ElementById -ProcessId $process.Id -AutomationId "Title.Library"
    $chartTab = Find-ElementById -ProcessId $process.Id -AutomationId "Editor.ChartTab"
    $timeline = Find-ElementById -ProcessId $process.Id -AutomationId "Timeline.Surface"
    $titleSave = Find-ElementById -ProcessId $process.Id -AutomationId "Title.SaveState"
    $initial = [ordered]@{
        windowTitle = $process.MainWindowTitle
        timeline = Get-OptionalElementState $timeline "Timeline.Surface"
        saveState = Get-OptionalElementState $titleSave "Title.SaveState"
        chartTab = Get-ElementState $chartTab
    }
    if ($initial.timeline.isOffscreen -or $initial.saveState.isOffscreen) {
        throw "Editor was not visible before navigating to the library."
    }

    $libraryClick = Click-Element $titleLibrary
    Wait-Condition -Description "library search after physical title click" -Condition {
        $candidate = Find-ElementById -ProcessId $process.Id -AutomationId "Library.Search" -TimeoutMilliseconds 300 -Optional
        $candidate -and -not $candidate.Current.IsOffscreen
    }
    $search = Find-ElementById -ProcessId $process.Id -AutomationId "Library.Search"
    $refresh = Find-ElementById -ProcessId $process.Id -AutomationId "Library.Refresh"
    $timeline = Find-ElementById -ProcessId $process.Id -AutomationId "Timeline.Surface" -TimeoutMilliseconds 300 -Optional
    $titleSave = Find-ElementById -ProcessId $process.Id -AutomationId "Title.SaveState" -TimeoutMilliseconds 300 -Optional
    $process.Refresh()
    $libraryBeforeInput = [ordered]@{
        windowTitle = $process.MainWindowTitle
        search = Get-ElementState $search
        timeline = Get-OptionalElementState $timeline "Timeline.Surface"
        saveState = Get-OptionalElementState $titleSave "Title.SaveState"
        chartTab = Get-ElementState $chartTab
    }
    if ($libraryBeforeInput.windowTitle -cne "曲库 — LumaChart Studio" -or
        $libraryBeforeInput.search.isOffscreen -or -not $libraryBeforeInput.timeline.isOffscreen -or
        -not $libraryBeforeInput.saveState.isOffscreen -or $libraryBeforeInput.chartTab.isOffscreen) {
        throw "Library surface did not match WPF visibility/title state after navigation."
    }

    [void][LumaChartLibraryShellNative]::SetForegroundWindow($handle)
    $ctrlF = Send-CtrlF
    Wait-Condition -Description "Ctrl+F search focus" -Condition {
        $focused = [Windows.Automation.AutomationElement]::FocusedElement
        $focused -and [string]$focused.Current.AutomationId -ceq "Library.Search"
    }
    $inputText = if ($ActualImeComposition) { "中文" } else { "中文搜索" }
    $inputActions = @()
    $postEditorInputActions = @()
    $imeScreenshots = @()
    $imeEvidence = $null
    $imeCandidateEdgeEvidence = $null
    $libraryCandidatePageScreenshot = $null
    if ($ActualImeComposition) {
        $imeActivation = Activate-MicrosoftPinyin $handle
        $physicalPinyin = Send-PhysicalAsciiText "zhongwen"
        Start-Sleep -Milliseconds 500
        $searchValueBeforeCandidateCommit = Get-ElementValue $search
        if ($searchValueBeforeCandidateCommit -cne "") {
            throw "Microsoft Pinyin source letters committed before candidate selection: '$searchValueBeforeCandidateCommit'."
        }
        $libraryCandidateScreenshot = Capture-PhysicalScreenWindow $handle (
            Join-Path $output "library-microsoft-pinyin-composition.png")
        if ($ImeCandidateEdges) {
            $candidateScreenshotHashBeforePage =
                (Get-FileHash -LiteralPath $libraryCandidateScreenshot['path'] -Algorithm SHA256).Hash
            $libraryCandidatePageDown = Send-ImeCandidatePageDown
            Start-Sleep -Milliseconds 350
            $searchValueAfterCandidatePage = Get-ElementValue $search
            if ($searchValueAfterCandidatePage -cne "") {
                throw (
                    "Microsoft Pinyin candidate paging committed text: " +
                    "'$searchValueAfterCandidatePage'.")
            }
            $libraryCandidatePageScreenshot = Capture-PhysicalScreenWindow $handle (
                Join-Path $output "library-microsoft-pinyin-candidate-page.png")
            $candidateScreenshotHashAfterPage =
                (Get-FileHash -LiteralPath $libraryCandidatePageScreenshot['path'] -Algorithm SHA256).Hash
            if ($candidateScreenshotHashAfterPage -ceq $candidateScreenshotHashBeforePage) {
                throw "Microsoft Pinyin candidate page did not visibly change after PageDown."
            }
            $libraryCompositionCancel = Send-ImeCompositionEscape
            Wait-Condition -Description "Microsoft Pinyin composition cancellation" -Condition {
                (Get-ElementValue $search) -ceq "" -and
                $search.Current.HasKeyboardFocus
            }
            $physicalPinyinAfterCancel = Send-PhysicalAsciiText "zhongwen"
            Start-Sleep -Milliseconds 350
            if ((Get-ElementValue $search) -cne "") {
                throw "Microsoft Pinyin re-entry committed before candidate selection."
            }
            $imeCandidateEdgeEvidence = [ordered]@{
                candidatePageGesture = "PageDown"
                committedValueAfterCandidatePage = $searchValueAfterCandidatePage
                candidatePageChangedPhysicalPixels =
                    $candidateScreenshotHashAfterPage -cne
                    $candidateScreenshotHashBeforePage
                candidateScreenshotSha256BeforePage =
                    $candidateScreenshotHashBeforePage
                candidateScreenshotSha256AfterPage =
                    $candidateScreenshotHashAfterPage
                cancelGesture = "Escape"
                committedValueAfterCancel = Get-ElementValue $search
                textHostFocusRetainedAfterCancel =
                    [bool]$search.Current.HasKeyboardFocus
                reenteredPinyin = "zhongwen"
                committedValueBeforeSecondCandidateSelection =
                    Get-ElementValue $search
                enterKeySent = $false
            }
        }
        $libraryCandidateCommit = Send-SpaceCandidateCommit
        $inputActions = if ($ImeCandidateEdges) {
            @(
                $imeActivation,
                $physicalPinyin,
                $libraryCandidatePageDown,
                $libraryCompositionCancel,
                $physicalPinyinAfterCancel,
                $libraryCandidateCommit)
        }
        else {
            @($imeActivation, $physicalPinyin, $libraryCandidateCommit)
        }
        $imeScreenshots += $libraryCandidateScreenshot
        if ($libraryCandidatePageScreenshot) {
            $imeScreenshots += $libraryCandidatePageScreenshot
        }
    }
    else {
        $sent = [int][LumaChartLibraryShellNative]::SendUnicodeText($inputText)
        if ($sent -ne $inputText.Length * 2) {
            throw "Unicode SendInput emitted $sent/$($inputText.Length * 2) events; error=$([LumaChartLibraryShellNative]::LastSendInputError)."
        }
        $inputActions = @([ordered]@{
            input = "Win32 SendInput KEYEVENTF_UNICODE"
            text = $inputText
            sentEvents = $sent
            expectedEvents = $inputText.Length * 2
            enterKeySent = $false
            occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
        })
    }
    Wait-Condition -Description "Chinese search value without Enter" -Condition {
        (Get-ElementValue (Find-ElementById -ProcessId $process.Id -AutomationId "Library.Search" -TimeoutMilliseconds 300)) -ceq $inputText
    }
    $refreshClick = Click-Element $refresh
    Wait-Condition -Description "library retained after refresh state updates" -Condition {
        $process.Refresh()
        $searchNow = Find-ElementById -ProcessId $process.Id -AutomationId "Library.Search" -TimeoutMilliseconds 300 -Optional
        $timelineNow = Find-ElementById -ProcessId $process.Id -AutomationId "Timeline.Surface" -TimeoutMilliseconds 300 -Optional
        $searchNow -and -not $searchNow.Current.IsOffscreen -and
        (-not $timelineNow -or $timelineNow.Current.IsOffscreen) -and
        $process.MainWindowTitle -ceq "曲库 — LumaChart Studio"
    }
    Start-Sleep -Milliseconds 500
    $search = Find-ElementById -ProcessId $process.Id -AutomationId "Library.Search"
    $libraryAfterRefresh = [ordered]@{
        windowTitle = $process.MainWindowTitle
        search = Get-ElementState $search
        searchValue = Get-ElementValue $search
        timeline = Get-OptionalElementState `
            (Find-ElementById -ProcessId $process.Id -AutomationId "Timeline.Surface" -TimeoutMilliseconds 300 -Optional) `
            "Timeline.Surface"
        saveState = Get-OptionalElementState `
            (Find-ElementById -ProcessId $process.Id -AutomationId "Title.SaveState" -TimeoutMilliseconds 300 -Optional) `
            "Title.SaveState"
        chartTab = Get-ElementState (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.ChartTab")
    }
    if ($libraryAfterRefresh.searchValue -cne $inputText -or
        -not $libraryAfterRefresh.timeline.isOffscreen -or
        -not $libraryAfterRefresh.saveState.isOffscreen) {
        throw "Library did not preserve the Chinese query or hidden editor/save state after refresh."
    }
    $libraryScreenshot = Capture-Window $handle (Join-Path $output "library-active-tab-chinese-search.png")

    $tabClick = Click-Element (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.ChartTab")
    Wait-Condition -Description "editor after physical tab click" -Condition {
        $timelineNow = Find-ElementById -ProcessId $process.Id -AutomationId "Timeline.Surface" -TimeoutMilliseconds 300 -Optional
        $saveNow = Find-ElementById -ProcessId $process.Id -AutomationId "Title.SaveState" -TimeoutMilliseconds 300 -Optional
        $timelineNow -and -not $timelineNow.Current.IsOffscreen -and
        $timelineNow.Current.HasKeyboardFocus -and
        $saveNow -and -not $saveNow.Current.IsOffscreen
    }
    Start-Sleep -Milliseconds 350
    $process.Refresh()
    $editorAfterReturn = [ordered]@{
        windowTitle = $process.MainWindowTitle
        timeline = Get-ElementState (Find-ElementById -ProcessId $process.Id -AutomationId "Timeline.Surface")
        saveState = Get-ElementState (Find-ElementById -ProcessId $process.Id -AutomationId "Title.SaveState")
        librarySearch = Get-OptionalElementState `
            (Find-ElementById -ProcessId $process.Id -AutomationId "Library.Search" -TimeoutMilliseconds 300 -Optional) `
            "Library.Search"
    }
    if ($editorAfterReturn.timeline.isOffscreen -or -not $editorAfterReturn.timeline.hasKeyboardFocus -or
        $editorAfterReturn.saveState.isOffscreen -or
        -not $editorAfterReturn.librarySearch.isOffscreen -or
        $editorAfterReturn.windowTitle -notlike "*— LumaChart Studio") {
        throw "Editor surface did not restore after the physical chart-tab click."
    }
    $metadataImeState = $null
    if ($ActualImeComposition -and -not $ImeCandidateEdgesOnly) {
        $metadataTabClick = Click-Element (
            Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.MetadataTab")
        Wait-Condition -Description "Metadata inspector content" -Condition {
            $candidate = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Metadata.TitleOriginal" `
                -TimeoutMilliseconds 300 `
                -Optional
            $candidate -and -not $candidate.Current.IsOffscreen
        }
        $metadataTitleOriginal = Find-ElementById -ProcessId $process.Id -AutomationId "Metadata.TitleOriginal"
        $metadataFocusClick = Click-Element $metadataTitleOriginal
        Wait-Condition -Description "Metadata title-original focus" -Condition {
            $focused = [Windows.Automation.AutomationElement]::FocusedElement
            $focused -and [string]$focused.Current.AutomationId -ceq "Metadata.TitleOriginal"
        }
        $metadataClear = Send-CtrlAAndBackspace
        Wait-Condition -Description "cleared Metadata title-original" -Condition {
            (Get-ElementValue $metadataTitleOriginal) -ceq ""
        }
        $metadataPinyin = Send-PhysicalAsciiText "shurufa"
        Start-Sleep -Milliseconds 500
        $metadataValueBeforeCandidateCommit = Get-ElementValue $metadataTitleOriginal
        if ($metadataValueBeforeCandidateCommit -cne "") {
            throw "Metadata Microsoft Pinyin source letters committed before candidate selection: '$metadataValueBeforeCandidateCommit'."
        }
        $metadataCandidateScreenshot = Capture-PhysicalScreenWindow $handle (
            Join-Path $output "metadata-microsoft-pinyin-composition.png")
        $metadataCandidateCommit = Send-SpaceCandidateCommit
        Wait-Condition -Description "Microsoft Pinyin metadata candidate commit" -Condition {
            (Get-ElementValue $metadataTitleOriginal) -ceq "输入法"
        }
        $metadataArtistOriginal = Find-ElementById -ProcessId $process.Id -AutomationId "Metadata.ArtistOriginal"
        $metadataFocusLossClick = Click-Element $metadataArtistOriginal
        Wait-Condition -Description "Metadata Chinese value after physical focus loss" -Condition {
            (Get-ElementValue $metadataTitleOriginal) -ceq "输入法" -and
            -not $metadataTitleOriginal.Current.HasKeyboardFocus
        }
        $imeScreenshots += $metadataCandidateScreenshot
        $postEditorInputActions += @(
            $metadataTabClick,
            $metadataFocusClick,
            $metadataClear,
            $metadataPinyin,
            $metadataCandidateCommit,
            $metadataFocusLossClick)
        $metadataImeState = [ordered]@{
            automationId = "Metadata.TitleOriginal"
            pinyin = "shurufa"
            committedValueBeforeCandidateSelection = $metadataValueBeforeCandidateCommit
            candidateCommitGesture = "Space"
            committedValueAfterCandidateSelection = Get-ElementValue $metadataTitleOriginal
            explicitPhysicalFocusLoss = "physical click Metadata.ArtistOriginal"
            valueSurvivedFocusLoss = (Get-ElementValue $metadataTitleOriginal) -ceq "输入法"
        }
    }
    $editorScreenshot = Capture-Window $handle (Join-Path $output "editor-returned-from-library.png")
    $noteImeState = $null
    $accountImeState = $null
    $noteCandidateScreenshot = $null
    $noteCommittedScreenshot = $null
    $accountCandidateScreenshot = $null
    $accountCommittedScreenshot = $null

    if ($ActualImeComposition -and -not $ImeCandidateEdgesOnly) {
        $noteTabClick = Click-Element (
            Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.NoteTab")
        Wait-Condition -Description "Note inspector sound field" -Condition {
            $candidate = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Inspector.Note.Sound" `
                -TimeoutMilliseconds 300 `
                -Optional
            $candidate -and -not $candidate.Current.IsOffscreen -and $candidate.Current.IsEnabled
        }
        $noteSound = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.Sound"
        $noteFocusClick = Click-Element $noteSound
        $noteClear = Send-CtrlAAndBackspace
        Wait-Condition -Description "cleared Note sound field" -Condition {
            (Get-ElementValue $noteSound) -ceq ""
        }
        $notePinyin = Send-PhysicalAsciiText "yinpin"
        Start-Sleep -Milliseconds 500
        $noteValueBeforeCandidateCommit = Get-ElementValue $noteSound
        if ($noteValueBeforeCandidateCommit -cne "") {
            throw "Note Microsoft Pinyin source letters committed before candidate selection: '$noteValueBeforeCandidateCommit'."
        }
        $noteCandidateScreenshot = Capture-PhysicalScreenWindow $handle (
            Join-Path $output "note-microsoft-pinyin-composition.png")
        $noteCandidateCommit = Send-SpaceCandidateCommit
        Wait-Condition -Description "Microsoft Pinyin Note candidate commit" -Condition {
            (Get-ElementValue $noteSound) -ceq "音频"
        }
        $noteGroup = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.Group"
        $noteFocusLossClick = Click-Element $noteGroup
        Wait-Condition -Description "Note Chinese value after physical focus loss" -Condition {
            (Get-ElementValue $noteSound) -ceq "音频" -and
            -not $noteSound.Current.HasKeyboardFocus
        }
        $noteCommittedScreenshot = Capture-Window $handle (
            Join-Path $output "note-microsoft-pinyin-committed.png")
        $postEditorInputActions += @(
            $noteTabClick,
            $noteFocusClick,
            $noteClear,
            $notePinyin,
            $noteCandidateCommit,
            $noteFocusLossClick)
        $noteImeState = [ordered]@{
            automationId = "Inspector.Note.Sound"
            pinyin = "yinpin"
            committedValueBeforeCandidateSelection = $noteValueBeforeCandidateCommit
            candidateCommitGesture = "Space"
            committedValueAfterCandidateSelection = Get-ElementValue $noteSound
            explicitPhysicalFocusLoss = "physical click Inspector.Note.Group"
            valueSurvivedFocusLoss = (Get-ElementValue $noteSound) -ceq "音频"
            mutationApplied = $false
        }

        $accountNavigationClick = Click-Element (
            Find-ElementById -ProcessId $process.Id -AutomationId "OnlineAccount.Navigation")
        Wait-Condition -Description "account login dialog" -Condition {
            $candidate = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "OnlineAccount.Dialog" `
                -TimeoutMilliseconds 300 `
                -Optional
            $candidate -and -not $candidate.Current.IsOffscreen
        }
        $accountDialog = Find-ElementById -ProcessId $process.Id -AutomationId "OnlineAccount.Dialog"
        $accountDialogNativeHandle =
            [IntPtr]$accountDialog.Current.NativeWindowHandle
        $accountHostedInMainWindow =
            $accountDialogNativeHandle -eq [IntPtr]::Zero
        $accountHandle = if ($accountHostedInMainWindow) {
            $handle
        }
        else {
            $accountDialogNativeHandle
        }
        [void][LumaChartLibraryShellNative]::SetForegroundWindow($accountHandle)
        $accountRegisterClick = Click-Element (
            Find-ElementById -ProcessId $process.Id -AutomationId "OnlineAccount.Login.Register")
        Wait-Condition -Description "account registration display-name field" -Condition {
            $candidate = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "OnlineAccount.Workflow.DisplayName" `
                -TimeoutMilliseconds 300 `
                -Optional
            $candidate -and -not $candidate.Current.IsOffscreen
        }
        $accountDisplayName = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "OnlineAccount.Workflow.DisplayName"
        $accountFocusClick = Click-Element $accountDisplayName
        $accountClear = Send-CtrlAAndBackspace
        Wait-Condition -Description "cleared account display name" -Condition {
            (Get-ElementValue $accountDisplayName) -ceq ""
        }
        $accountImeActivation = Activate-MicrosoftPinyin $accountHandle
        $accountPinyin = Send-PhysicalAsciiText "yonghu"
        Start-Sleep -Milliseconds 500
        $accountValueBeforeCandidateCommit = Get-ElementValue $accountDisplayName
        $accountImeModeRecoveryActions = @()
        if ($accountValueBeforeCandidateCommit -ceq "yonghu") {
            $accountLatinClear = Send-CtrlAAndBackspace
            $accountChineseModeToggle = Send-ImeChineseModeToggle
            $accountPinyinAfterModeToggle = Send-PhysicalAsciiText "yonghu"
            Start-Sleep -Milliseconds 500
            $accountValueBeforeCandidateCommit =
                Get-ElementValue $accountDisplayName
            $accountImeModeRecoveryActions = @(
                $accountLatinClear,
                $accountChineseModeToggle,
                $accountPinyinAfterModeToggle)
        }
        if ($accountValueBeforeCandidateCommit -ceq "yonghu") {
            $accountLatinClearAfterShift = Send-CtrlAAndBackspace
            $accountImeActivationHotkey = Send-ImeActivationHotkey
            $accountPinyinAfterActivationHotkey =
                Send-PhysicalAsciiText "yonghu"
            Start-Sleep -Milliseconds 500
            $accountValueBeforeCandidateCommit =
                Get-ElementValue $accountDisplayName
            $accountImeModeRecoveryActions += @(
                $accountLatinClearAfterShift,
                $accountImeActivationHotkey,
                $accountPinyinAfterActivationHotkey)
        }
        if ($accountValueBeforeCandidateCommit -cne "") {
            throw "Account Microsoft Pinyin source letters committed before candidate selection: '$accountValueBeforeCandidateCommit'."
        }
        $accountCandidateScreenshot = Capture-PhysicalScreenWindow $accountHandle (
            Join-Path $output "account-microsoft-pinyin-composition.png")
        $accountCandidateCommit = Send-SpaceCandidateCommit
        Wait-Condition -Description "Microsoft Pinyin account candidate commit" -Condition {
            (Get-ElementValue $accountDisplayName) -ceq "用户"
        }
        $accountEmail = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "OnlineAccount.Workflow.Email"
        $accountFocusLossClick = Click-Element $accountEmail
        Wait-Condition -Description "account Chinese display name after physical focus loss" -Condition {
            (Get-ElementValue $accountDisplayName) -ceq "用户" -and
            -not $accountDisplayName.Current.HasKeyboardFocus
        }
        $accountCommittedScreenshot = Capture-Window $accountHandle (
            Join-Path $output "account-microsoft-pinyin-committed.png")
        $accountClose = if ($accountHostedInMainWindow) {
            Click-Element (
                Find-ElementById `
                    -ProcessId $process.Id `
                    -AutomationId "OnlineAccount.Workflow.Cancel")
        }
        else {
            Send-AltF4
        }
        Wait-Condition -Description "account dialog close" -Condition {
            -not (Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "OnlineAccount.Dialog" `
                -TimeoutMilliseconds 300 `
                -Optional)
        }
        $postEditorInputActions += @(
            $accountNavigationClick,
            $accountRegisterClick,
            $accountFocusClick,
            $accountClear,
            $accountImeActivation,
            $accountPinyin,
            $accountImeModeRecoveryActions,
            $accountCandidateCommit,
            $accountFocusLossClick,
            $accountClose)
        $accountImeState = [ordered]@{
            automationId = "OnlineAccount.Workflow.DisplayName"
            pinyin = "yonghu"
            latinModeRecoveryUsed =
                @($accountImeModeRecoveryActions).Count -ne 0
            committedValueBeforeCandidateSelection = $accountValueBeforeCandidateCommit
            candidateCommitGesture = "Space"
            committedValueAfterCandidateSelection = "用户"
            explicitPhysicalFocusLoss = "physical click OnlineAccount.Workflow.Email"
            valueSurvivedFocusLoss = $true
            submitActionInvoked = $false
            hostedInMainWindow = $accountHostedInMainWindow
            nativeWindowHandle =
                ("0x{0:X}" -f $accountDialogNativeHandle.ToInt64())
            dialogClosedPhysically = $true
        }
    }

    if ($ActualImeComposition) {
        $imeEvidence = [ordered]@{
            inputMethod = "Microsoft Pinyin"
            keyboardLayout = $imeActivation
            librarySearch = [ordered]@{
                automationId = "Library.Search"
                pinyin = "zhongwen"
                committedValueBeforeCandidateSelection = $searchValueBeforeCandidateCommit
                candidateCommitGesture = "Space"
                committedValueAfterCandidateSelection = $libraryAfterRefresh.searchValue
                explicitPhysicalFocusLoss = "physical click Library.Refresh"
                valueSurvivedFocusLoss = $libraryAfterRefresh.searchValue -ceq $inputText
            }
            metadata = $metadataImeState
            note = $noteImeState
            account = $accountImeState
            candidateEdges = $imeCandidateEdgeEvidence
            enterKeySent = $false
            physicalPinyinKeyEventsUsed = $true
            candidateOverlayCapturedFromPhysicalDesktop = $true
            actualImeCompositionValidated = $true
        }
    }

    $actualImeScreenshots = if ($ActualImeComposition) {
        @($libraryCandidateScreenshot)
        if ($libraryCandidatePageScreenshot) {
            @($libraryCandidatePageScreenshot)
        }
        @(
            $libraryScreenshot,
            $metadataCandidateScreenshot,
            $editorScreenshot,
            $noteCandidateScreenshot,
            $noteCommittedScreenshot,
            $accountCandidateScreenshot,
            $accountCommittedScreenshot) |
            Where-Object { $_ }
    }
    else {
        @()
    }
    $sourceAfter = Assert-Unchanged $sourceBefore "real MC fixture"
    $installerAfter = Assert-Unchanged $installerBefore "frozen installer"
    $runtime = Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json
    $evidence = [ordered]@{
        schema = if ($ActualImeComposition) {
            if ($ImeCandidateEdgesOnly) {
                "lumachart.windows.avalonia.ime-candidate-edges-gui-evidence.v1"
            }
            else {
                "lumachart.windows.avalonia.ime-composition-gui-evidence.v2"
            }
        }
        else {
            "lumachart.windows.avalonia.library-shell-gui-evidence.v1"
        }
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        formalMigrationAuthority = [bool]$FormalMigrationAuthority
        completion = [ordered]@{
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
        }
        buildBoundary = [ordered]@{
            platform = "Windows Avalonia only"
            configuration = "Release"
            ollvm = $false
            obfuscation = $false
            packing = $false
            codeVirtualization = $false
            aot = $false
        }
        processId = $process.Id
        source = [ordered]@{ before = $sourceBefore; after = $sourceAfter; unchanged = $true }
        frozenInstaller = [ordered]@{ before = $installerBefore; after = $installerAfter; unchanged = $true }
        runtimeEvidence = [ordered]@{
            path = $runtimePath
            sha256 = (Get-FileHash -LiteralPath $runtimePath -Algorithm SHA256).Hash
            status = [string]$runtime.status
        }
        initialEditor = $initial
        actions =
            @($libraryClick, $ctrlF) +
            @($inputActions) +
            @($refreshClick, $tabClick) +
            @($postEditorInputActions)
        libraryBeforeInput = $libraryBeforeInput
        libraryAfterRefresh = $libraryAfterRefresh
        editorAfterReturn = $editorAfterReturn
        inputBoundary = if ($ActualImeComposition) {
            [ordered]@{
                chineseTextWithoutEnterValidated = $true
                physicalCtrlFFocusValidated = $true
                explicitPhysicalFocusLossValidated = $true
                actualImeCompositionValidated = $true
                actualIme = $imeEvidence
                note = "This slice activates the configured Microsoft Pinyin profile on the Avalonia UI thread, sends physical pinyin keys, captures the candidate overlay before selection, commits the first candidate with Space, and proves Library, Metadata, Note and account-registration display-name values survive physical focus loss without Enter."
            }
        }
        else {
            [ordered]@{
                chineseTextWithoutEnterValidated = $true
                physicalCtrlFFocusValidated = $true
                explicitPhysicalFocusLossValidated = $true
                actualImeCompositionValidated = $false
                note = "This slice validates physical Ctrl+F plus Win32 Unicode Chinese input without Enter and physical focus loss. It does not claim a real IME composition-session gate."
            }
        }
        screenshots = if ($ActualImeComposition) {
            @($actualImeScreenshots)
        }
        else {
            @($libraryScreenshot, $editorScreenshot)
        }
    }
    $evidencePath = Join-Path $output "evidence.json"
    $evidence | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    [pscustomobject]@{
        evidencePath = $evidencePath
        evidenceBytes = (Get-Item -LiteralPath $evidencePath).Length
        evidenceSha256 = (Get-FileHash -LiteralPath $evidencePath -Algorithm SHA256).Hash
        status = "passed"
        physicalActionCount = @($evidence.actions).Count
        screenshotCount = @($evidence.screenshots).Count
    }
}
finally {
    Stop-TrackedProcess $process
}
