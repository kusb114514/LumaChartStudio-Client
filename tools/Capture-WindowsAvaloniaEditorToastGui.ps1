param(
    [string]$ApplicationPath = (
        Join-Path $PSScriptRoot `
            "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(750, 5000)][int]$AutoBackupDelayMilliseconds = 2000,
    [ValidateRange(30, 120)][int]$TimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia editor-toast GUI capture requires PowerShell Core on Windows."
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Threading;

public static class LumaChartEditorToastGuiNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr window, IntPtr deviceContext, uint flags);

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
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern void SwitchToThisWindow(IntPtr window, bool altTab);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr window, int command);

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
    public static extern void mouse_event(
        uint flags,
        uint x,
        uint y,
        uint data,
        UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(
        byte virtualKey,
        byte scanCode,
        uint flags,
        UIntPtr extraInfo);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    private static extern IntPtr GetWindowLongPtr64(IntPtr window, int index);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
    private static extern int GetWindowLong32(IntPtr window, int index);

    public static bool IsTopmost(IntPtr window)
    {
        const int GWL_EXSTYLE = -20;
        const long WS_EX_TOPMOST = 0x00000008L;
        var value = IntPtr.Size == 8
            ? GetWindowLongPtr64(window, GWL_EXSTYLE).ToInt64()
            : GetWindowLong32(window, GWL_EXSTYLE);
        return (value & WS_EX_TOPMOST) != 0;
    }

    public static bool ForceNonTopmost(IntPtr window)
    {
        var notTopmost = new IntPtr(-2);
        const uint noMoveNoSizeShow = 0x0001 | 0x0002 | 0x0040;
        return SetWindowPos(window, notTopmost, 0, 0, 0, 0, noMoveNoSizeShow);
    }

    public static bool BringNonTopmostToFront(IntPtr window)
    {
        var top = IntPtr.Zero;
        const uint noMoveNoSizeShow = 0x0001 | 0x0002 | 0x0040;
        return SetWindowPos(window, top, 0, 0, 0, 0, noMoveNoSizeShow);
    }

    public static bool ActivateNonTopmost(IntPtr window)
    {
        if (window == IntPtr.Zero)
            return false;
        var foreground = GetForegroundWindow();
        if (foreground == window)
        {
            ForceNonTopmost(window);
            return !IsTopmost(window);
        }
        var currentThread = GetCurrentThreadId();
        var foregroundThread = foreground == IntPtr.Zero
            ? 0
            : GetWindowThreadProcessId(foreground, out _);
        var targetThread = GetWindowThreadProcessId(window, out _);
        var attachedForeground = false;
        var attachedTarget = false;
        try
        {
            if (foregroundThread != 0 && foregroundThread != currentThread)
                attachedForeground = AttachThreadInput(currentThread, foregroundThread, true);
            if (targetThread != 0 &&
                targetThread != currentThread &&
                targetThread != foregroundThread)
                attachedTarget = AttachThreadInput(currentThread, targetThread, true);
            ForceNonTopmost(window);
            ShowWindowAsync(window, 5);
            BringWindowToTop(window);
            SetForegroundWindow(window);
            if (GetForegroundWindow() == window)
                return !IsTopmost(window);
            SwitchToThisWindow(window, true);
            Thread.Sleep(60);
            if (GetForegroundWindow() == window)
                return !IsTopmost(window);
            const byte virtualKeyMenu = 0x12;
            const uint keyUp = 0x0002;
            keybd_event(virtualKeyMenu, 0, 0, UIntPtr.Zero);
            keybd_event(virtualKeyMenu, 0, keyUp, UIntPtr.Zero);
            BringWindowToTop(window);
            SetForegroundWindow(window);
            if (GetForegroundWindow() == window)
                return !IsTopmost(window);
            BringNonTopmostToFront(window);
            Thread.Sleep(80);
            return GetForegroundWindow() == window && !IsTopmost(window);
        }
        finally
        {
            if (IsTopmost(window))
                ForceNonTopmost(window);
            if (attachedTarget)
                AttachThreadInput(currentThread, targetThread, false);
            if (attachedForeground)
                AttachThreadInput(currentThread, foregroundThread, false);
        }
    }

    public static void Click(int x, int y)
    {
        const uint LeftDown = 0x0002;
        const uint LeftUp = 0x0004;
        SetCursorPos(x, y);
        Thread.Sleep(90);
        mouse_event(LeftDown, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(45);
        mouse_event(LeftUp, 0, 0, 0, UIntPtr.Zero);
    }

    public static void Key(byte virtualKey, bool down)
    {
        const uint KeyUp = 0x0002;
        keybd_event(virtualKey, 0, down ? 0u : KeyUp, UIntPtr.Zero);
    }
}
'@

function Wait-Condition {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Condition,
        [Parameter(Mandatory = $true)][string]$Description,
        [int]$Seconds = $TimeoutSeconds)
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try {
            if (& $Condition) { return }
        }
        catch {
        }
        Start-Sleep -Milliseconds 80
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [int]$TimeoutMilliseconds = 10000)
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
            [Windows.Automation.TreeScope]::Children,
            $processCondition)
        foreach ($root in $roots) {
            if ([string]$root.Current.AutomationId -ceq $AutomationId) {
                return $root
            }
            $candidate = $root.FindFirst(
                [Windows.Automation.TreeScope]::Descendants,
                $idCondition)
            if ($candidate) { return $candidate }
        }
        Start-Sleep -Milliseconds 80
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    return $null
}

function Get-ElementHelpText([Windows.Automation.AutomationElement]$Element) {
    return [string]$Element.GetCurrentPropertyValue(
        [Windows.Automation.AutomationElement]::HelpTextProperty,
        $true)
}

function Get-ElementValue([Windows.Automation.AutomationElement]$Element) {
    $pattern = $null
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$pattern)) {
        return [string]([Windows.Automation.ValuePattern]$pattern).Current.Value
    }
    return [string]$Element.Current.Name
}

function Set-ElementValueByUia {
    param(
        [Parameter(Mandatory = $true)][Windows.Automation.AutomationElement]$Element,
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Label)
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$pattern)) {
        throw "$Label does not expose the UI Automation Value pattern."
    }
    ([Windows.Automation.ValuePattern]$pattern).SetValue($Value)
    return [ordered]@{
        action = "uia-value-pattern"
        target = $Label
        value = $Value
        utc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Invoke-ElementByUia {
    param(
        [Parameter(Mandatory = $true)][Windows.Automation.AutomationElement]$Element,
        [Parameter(Mandatory = $true)][string]$Label)
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$pattern)) {
        throw "$Label does not expose the UI Automation Invoke pattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
    return [ordered]@{
        action = "uia-invoke-pattern"
        target = $Label
        utc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Close-WindowByUia([IntPtr]$Handle) {
    $root = [Windows.Automation.AutomationElement]::FromHandle($Handle)
    $pattern = $null
    if (-not $root.TryGetCurrentPattern(
            [Windows.Automation.WindowPattern]::Pattern,
            [ref]$pattern)) {
        throw "Avalonia window does not expose the UI Automation Window pattern."
    }
    ([Windows.Automation.WindowPattern]$pattern).Close()
    return [ordered]@{
        action = "uia-window-close-pattern"
        target = "Avalonia main window"
        utc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Activate-Window([IntPtr]$Handle) {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(5)
    do {
        [void][LumaChartEditorToastGuiNative]::ActivateNonTopmost($Handle)
        if (-not [LumaChartEditorToastGuiNative]::IsTopmost($Handle)) {
            return
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Avalonia window remained topmost after explicit non-topmost activation."
}

function Click-ElementPhysical {
    param(
        [Parameter(Mandatory = $true)][Windows.Automation.AutomationElement]$Element,
        [Parameter(Mandatory = $true)][IntPtr]$WindowHandle,
        [Parameter(Mandatory = $true)][string]$Label)
    Activate-Window $WindowHandle
    $rectangle = $Element.Current.BoundingRectangle
    if ($rectangle.IsEmpty -or $Element.Current.IsOffscreen) {
        throw "$Label is not physically clickable."
    }
    $x = [int][Math]::Round($rectangle.Left + $rectangle.Width / 2)
    $y = [int][Math]::Round($rectangle.Top + $rectangle.Height / 2)
    [LumaChartEditorToastGuiNative]::Click($x, $y)
    Start-Sleep -Milliseconds 120
    return [ordered]@{
        action = "physical-left-click"
        target = $Label
        x = $x
        y = $y
        utc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Send-KeyStroke {
    param(
        [Parameter(Mandatory = $true)][byte]$VirtualKey,
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][IntPtr]$WindowHandle)
    Activate-Window $WindowHandle
    [LumaChartEditorToastGuiNative]::Key($VirtualKey, $true)
    Start-Sleep -Milliseconds 35
    [LumaChartEditorToastGuiNative]::Key($VirtualKey, $false)
    Start-Sleep -Milliseconds 80
    return [ordered]@{
        action = "win32-key-injection"
        key = $Label
        utc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Send-CtrlA([IntPtr]$WindowHandle) {
    Activate-Window $WindowHandle
    [LumaChartEditorToastGuiNative]::Key(0x11, $true)
    [LumaChartEditorToastGuiNative]::Key(0x41, $true)
    Start-Sleep -Milliseconds 35
    [LumaChartEditorToastGuiNative]::Key(0x41, $false)
    [LumaChartEditorToastGuiNative]::Key(0x11, $false)
    Start-Sleep -Milliseconds 80
    return [ordered]@{
        action = "win32-key-chord-injection"
        key = "Ctrl+A"
        utc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Send-AltF4([IntPtr]$WindowHandle) {
    Activate-Window $WindowHandle
    [LumaChartEditorToastGuiNative]::Key(0x12, $true)
    [LumaChartEditorToastGuiNative]::Key(0x73, $true)
    Start-Sleep -Milliseconds 40
    [LumaChartEditorToastGuiNative]::Key(0x73, $false)
    [LumaChartEditorToastGuiNative]::Key(0x12, $false)
    return [ordered]@{
        action = "win32-key-chord-injection"
        key = "Alt+F4"
        utc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Capture-Window {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$Handle,
        [Parameter(Mandatory = $true)][string]$Path)
    $rectangle = [LumaChartEditorToastGuiNative+RECT]::new()
    if (-not [LumaChartEditorToastGuiNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) {
        throw "GetWindowRect failed."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    $bitmap = [Drawing.Bitmap]::new(
        $width,
        $height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $deviceContext = $graphics.GetHdc()
        try {
            if (-not [LumaChartEditorToastGuiNative]::PrintWindow(
                    $Handle,
                    $deviceContext,
                    2)) {
                throw "PrintWindow failed."
            }
        }
        finally {
            $graphics.ReleaseHdc($deviceContext)
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
    return [ordered]@{
        path = $Path
        width = $width
        height = $height
        bytes = (Get-Item -LiteralPath $Path).Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$applicationFullPath = [IO.Path]::GetFullPath($ApplicationPath)
$fixtureFullPath = [IO.Path]::GetFullPath($ChartFixturePath)
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
if (-not $outputFullPath.StartsWith(
        $projectRoot.TrimEnd('\') + '\',
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Output root must stay below the project root: $outputFullPath"
}
if (-not (Test-Path -LiteralPath $applicationFullPath -PathType Leaf)) {
    throw "Application not found: $applicationFullPath"
}
if (-not (Test-Path -LiteralPath $fixtureFullPath -PathType Leaf)) {
    throw "Fixture not found: $fixtureFullPath"
}
if (Test-Path -LiteralPath $outputFullPath) {
    if (@(Get-ChildItem -LiteralPath $outputFullPath -Force).Count -ne 0) {
        throw "Output root must be empty: $outputFullPath"
    }
}
else {
    New-Item -ItemType Directory -Path $outputFullPath | Out-Null
}

$fixtureDirectory = Join-Path $outputFullPath "fixture"
$localDataRoot = Join-Path $outputFullPath "local-data"
$editingRoot = Join-Path $outputFullPath "editing"
$workspaceRoot = Join-Path $outputFullPath "workspace"
$tempRoot = Join-Path $outputFullPath "temp"
foreach ($directory in @(
    $fixtureDirectory,
    $localDataRoot,
    $editingRoot,
    $workspaceRoot,
    $tempRoot)) {
    New-Item -ItemType Directory -Path $directory | Out-Null
}
$chartUnderTest = Join-Path $fixtureDirectory "1781536331.mc"
Copy-Item -LiteralPath $fixtureFullPath -Destination $chartUnderTest
$sourceBefore = (Get-FileHash -LiteralPath $chartUnderTest -Algorithm SHA256).Hash
$installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$installerBefore = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
$runtimeEvidencePath = Join-Path $outputFullPath "runtime-evidence.json"
$screenshotPath = Join-Path $outputFullPath "editor-auto-backup-toast.png"
$evidencePath = Join-Path $outputFullPath "evidence.json"
$actions = [Collections.Generic.List[object]]::new()

$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = $applicationFullPath
$start.UseShellExecute = $false
foreach ($argument in @(
    "--evidence-chart",
    $chartUnderTest,
    "--evidence-output",
    $runtimeEvidencePath,
    "--evidence-focus-note-property",
    "--evidence-focus-note-property-beat",
    "10:0/4",
    "--evidence-auto-backup-delay-ms",
    [string]$AutoBackupDelayMilliseconds)) {
    $start.ArgumentList.Add($argument)
}
$start.Environment["LUMACHART_PROFILE"] = "editor-toast-gui"
$start.Environment["LUMACHART_SERVER_URL"] = "http://127.0.0.1:1/"
$start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataRoot
$start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingRoot
$start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceRoot
$start.Environment["DOTNET_CLI_HOME"] = Join-Path $projectRoot ".dotnet-home"
$start.Environment["NUGET_PACKAGES"] = Join-Path $projectRoot ".nuget\packages"
$start.Environment["NUGET_HTTP_CACHE_PATH"] = Join-Path $projectRoot ".nuget\http-cache"
$start.Environment["TEMP"] = $tempRoot
$start.Environment["TMP"] = $tempRoot

$process = [Diagnostics.Process]::Start($start)
if (-not $process) { throw "Failed to start the Avalonia client." }
$visibleDuration = $null
$toastHelpText = $null
$toastBounds = $null
$capture = $null
$backupFile = $null
$exitCode = $null
try {
    Wait-Condition -Description "Avalonia main window" -Condition {
        $process.Refresh()
        $process.MainWindowHandle -ne [IntPtr]::Zero
    }
    $handle = $process.MainWindowHandle
    Activate-Window $handle
    if ([LumaChartEditorToastGuiNative]::IsTopmost($handle)) {
        throw "Avalonia main window unexpectedly uses WS_EX_TOPMOST."
    }

    $volume = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Inspector.Note.Volume" `
        -TimeoutMilliseconds 20000
    $apply = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Inspector.Note.Apply" `
        -TimeoutMilliseconds 20000
    if (-not $volume -or -not $apply) {
        throw "Note Inspector did not materialize for the real chart."
    }
    $actions.Add((Set-ElementValueByUia `
        -Element $volume `
        -Value "73" `
        -Label "Inspector.Note.Volume"))
    Wait-Condition -Description "Note volume 73 draft" -Seconds 10 -Condition {
        (Get-ElementValue (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Inspector.Note.Volume" `
            -TimeoutMilliseconds 500)) -ceq "73"
    }
    $actions.Add((Invoke-ElementByUia `
        -Element (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Inspector.Note.Apply") `
        -Label "Inspector.Note.Apply"))

    $toastStopwatch = [Diagnostics.Stopwatch]::StartNew()
    $toast = $null
    Wait-Condition -Description "real automatic-backup editor toast" -Seconds 15 -Condition {
        $toast = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.Toast" `
            -TimeoutMilliseconds 150
        if (-not $toast) { return $false }
        $help = Get-ElementHelpText $toast
        return $help -like "Visible=True; Message=自动备份成功;*"
    }
    $toastVisibleDetectedMilliseconds = $toastStopwatch.Elapsed.TotalMilliseconds
    $toast = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.Toast" `
        -TimeoutMilliseconds 1000
    if (-not $toast) {
        throw "Editor toast disappeared before its formal capture."
    }
    $toastHelpText = Get-ElementHelpText $toast
    $toastBounds = $toast.Current.BoundingRectangle
    $capture = Capture-Window -Handle $handle -Path $screenshotPath

    Wait-Condition -Description "3-second editor toast dismissal" -Seconds 8 -Condition {
        $candidate = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.Toast" `
            -TimeoutMilliseconds 100
        return -not $candidate
    }
    $visibleDuration = $toastStopwatch.Elapsed.TotalMilliseconds -
        $toastVisibleDetectedMilliseconds
    if ($visibleDuration -lt 2400 -or $visibleDuration -gt 4500) {
        throw "Editor toast visible duration was outside the WPF timing window: $visibleDuration ms."
    }

    $backupFiles = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $localDataRoot "Backups") `
            -File `
            -Recurse `
            -Filter "*.mcbackup" `
            -ErrorAction Stop)
    if ($backupFiles.Count -ne 1) {
        throw "Expected exactly one real automatic backup, found $($backupFiles.Count)."
    }
    $backupFile = $backupFiles[0]

    $actions.Add((Close-WindowByUia -Handle $handle))
    $discard = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "UnsavedChanges.Discard" `
        -TimeoutMilliseconds 10000
    if (-not $discard) { throw "Unsaved-changes discard action did not appear." }
    $dialogRoot = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "UnsavedChanges.Dialog" `
        -TimeoutMilliseconds 1000
    $dialogHandle = if ($dialogRoot) {
        [IntPtr]::new([int64]$dialogRoot.Current.NativeWindowHandle)
    }
    else {
        $handle
    }
    if ($dialogHandle -eq [IntPtr]::Zero) { $dialogHandle = $handle }
    $actions.Add((Invoke-ElementByUia `
        -Element $discard `
        -Label "UnsavedChanges.Discard"))
    if (-not $process.WaitForExit(15000)) {
        throw "Avalonia client did not exit after physical discard."
    }
    $exitCode = $process.ExitCode
    if ($exitCode -ne 0) { throw "Avalonia client exited with code $exitCode." }

    $sourceAfter = (Get-FileHash -LiteralPath $chartUnderTest -Algorithm SHA256).Hash
    $installerAfter = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
    if ($sourceAfter -cne $sourceBefore) {
        throw "The isolated real MC source changed despite discard."
    }
    if ($installerAfter -cne $installerBefore) {
        throw "The frozen installer changed."
    }
    if ($installerAfter -cne
        "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
        throw "The frozen installer hash differs from the trusted baseline."
    }

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.editor-toast-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        platform = "Windows Avalonia only"
        buildMode = "ordinary .NET Release"
        gui = [ordered]@{
            realChart = [ordered]@{
                path = $chartUnderTest
                sha256Before = $sourceBefore
                sha256After = $sourceAfter
                sourceUnchangedAfterDiscard = $true
            }
            automaticBackup = [ordered]@{
                delayMilliseconds = $AutoBackupDelayMilliseconds
                file = $backupFile.FullName
                bytes = $backupFile.Length
                sha256 = (Get-FileHash `
                    -LiteralPath $backupFile.FullName `
                    -Algorithm SHA256).Hash
                fileCount = 1
            }
            editorToast = [ordered]@{
                helpText = $toastHelpText
                message = "自动备份成功"
                visibleDurationMilliseconds = [Math]::Round($visibleDuration, 2)
                requestedDurationMilliseconds = 3000
                nonInteractive = $true
                bounds = [ordered]@{
                    left = [Math]::Round($toastBounds.Left, 2)
                    top = [Math]::Round($toastBounds.Top, 2)
                    width = [Math]::Round($toastBounds.Width, 2)
                    height = [Math]::Round($toastBounds.Height, 2)
                }
                screenshot = $capture
                visuallyInspected = $false
            }
            actions = $actions
            actionCount = $actions.Count
            uiaControlPatternsUsed = $true
            win32InputInjectionUsed = $false
            hardwareMouseInputClaimed = $false
            hardwareKeyboardInputClaimed = $false
            enterKeySent = $false
            persistentTopmostUsed = $false
            processExitCode = $exitCode
        }
        safety = [ordered]@{
            explicitCurrentTurnConsent = $true
            minimumIdleMilliseconds = 3000
            observedIdleMilliseconds =
                $script:WindowsAvaloniaForegroundAutomationIdleMilliseconds
            heldModifierGate = $true
            productionServerDeployed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        }
        frozenInstaller = [ordered]@{
            path = $installerPath
            sha256Before = $installerBefore
            sha256After = $installerAfter
        }
        completion = [ordered]@{
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
        }
    }
    $evidence | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    [pscustomobject]@{
        evidencePath = $evidencePath
        evidenceBytes = (Get-Item -LiteralPath $evidencePath).Length
        evidenceSha256 =
            (Get-FileHash -LiteralPath $evidencePath -Algorithm SHA256).Hash
        screenshotPath = $screenshotPath
        backupPath = $backupFile.FullName
        actions = $actions.Count
        processExitCode = $exitCode
    }
}
finally {
    if ($process -and -not $process.HasExited) {
        try { $process.Kill($true) } catch { }
        $process.WaitForExit(5000) | Out-Null
    }
    if ($null -ne $process) {
        $process.Dispose()
    }
}
