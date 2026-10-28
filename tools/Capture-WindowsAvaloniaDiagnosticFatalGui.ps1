param(
    [string]$ApplicationPath = (
        Join-Path $PSScriptRoot `
            "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(15, 120)][int]$TimeoutSeconds = 45,
    [switch]$AllowForegroundAutomation
)

$ErrorActionPreference = "Stop"
if (-not $AllowForegroundAutomation) {
    throw "Pass -AllowForegroundAutomation only after the user gives current-turn desktop consent."
}
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia diagnostic GUI capture requires PowerShell Core on Windows."
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class LumaChartDiagnosticFatalNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    private delegate bool EnumWindowsCallback(IntPtr window, IntPtr parameter);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(
        EnumWindowsCallback callback,
        IntPtr parameter);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(
        IntPtr window,
        out uint processId);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(
        IntPtr window,
        StringBuilder className,
        int maximumCount);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern IntPtr GetWindow(IntPtr window, uint command);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr window);

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
    public static extern IntPtr GetLastActivePopup(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(
        IntPtr window,
        uint message,
        IntPtr parameter,
        IntPtr data);

    [DllImport("user32.dll")]
    public static extern bool IsWindowEnabled(IntPtr window);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr window);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    private static extern IntPtr GetWindowLongPtr64(IntPtr window, int index);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
    private static extern int GetWindowLong32(IntPtr window, int index);

    public static IntPtr[] VisibleWindowsForProcess(uint requestedProcessId)
    {
        var windows = new List<IntPtr>();
        EnumWindows((window, _) =>
        {
            uint processId;
            GetWindowThreadProcessId(window, out processId);
            if (processId == requestedProcessId && IsWindowVisible(window))
                windows.Add(window);
            return true;
        }, IntPtr.Zero);
        return windows.ToArray();
    }

    public static string ClassName(IntPtr window)
    {
        var text = new StringBuilder(256);
        return GetClassName(window, text, text.Capacity) > 0
            ? text.ToString()
            : string.Empty;
    }

    public static bool IsTopmostStyleSet(IntPtr window)
    {
        const int extendedStyle = -20;
        const long topmostStyle = 0x00000008L;
        var value = IntPtr.Size == 8
            ? GetWindowLongPtr64(window, extendedStyle).ToInt64()
            : GetWindowLong32(window, extendedStyle);
        return (value & topmostStyle) != 0;
    }

    public static bool ActivateNonTopmost(IntPtr window)
    {
        if (window == IntPtr.Zero)
            return false;
        var notTopmost = new IntPtr(-2);
        const uint noMoveNoSizeShow = 0x0001 | 0x0002 | 0x0040;
        SetWindowPos(window, notTopmost, 0, 0, 0, 0, noMoveNoSizeShow);
        ShowWindowAsync(window, 5);
        BringWindowToTop(window);
        SetForegroundWindow(window);
        Thread.Sleep(180);
        SetWindowPos(window, notTopmost, 0, 0, 0, 0, noMoveNoSizeShow);
        return GetForegroundWindow() == window;
    }
}
'@

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Resolve-ExistingFile([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "$Label not found: $full"
    return $full
}

function Resolve-NewDirectory([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Output already exists: $full" }
    [IO.Directory]::CreateDirectory($full) | Out-Null
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

function Get-WindowBounds([IntPtr]$Handle) {
    $rectangle = [LumaChartDiagnosticFatalNative+RECT]::new()
    Assert (
        [LumaChartDiagnosticFatalNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) "GetWindowRect failed for $Handle."
    return [ordered]@{
        left = $rectangle.Left
        top = $rectangle.Top
        right = $rectangle.Right
        bottom = $rectangle.Bottom
        width = $rectangle.Right - $rectangle.Left
        height = $rectangle.Bottom - $rectangle.Top
    }
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $bounds = Get-WindowBounds $Handle
    Assert ($bounds.width -ge 800 -and $bounds.height -ge 500) (
        "Invalid owner bounds $($bounds.width)x$($bounds.height).")
    $bitmap = [Drawing.Bitmap]::new(
        $bounds.width,
        $bounds.height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen(
                $bounds.left,
                $bounds.top,
                0,
                0,
                [Drawing.Size]::new($bounds.width, $bounds.height),
                [Drawing.CopyPixelOperation]::SourceCopy)
        }
        finally { $graphics.Dispose() }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        $item = Get-Item -LiteralPath $Path
        return [ordered]@{
            path = $item.FullName
            bytes = [long]$item.Length
            width = $bounds.width
            height = $bounds.height
            sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
            captureKind = "physical owner window including native fatal dialog"
        }
    }
    finally { $bitmap.Dispose() }
}

function Get-ElementText([Windows.Automation.AutomationElement]$Element) {
    $parts = [Collections.Generic.List[string]]::new()
    $all = $Element.FindAll(
        [Windows.Automation.TreeScope]::Subtree,
        [Windows.Automation.Condition]::TrueCondition)
    foreach ($item in $all) {
        $name = [string]$item.Current.Name
        if (-not [string]::IsNullOrWhiteSpace($name) -and -not $parts.Contains($name)) {
            $parts.Add($name)
        }
    }
    return ($parts -join "`n")
}

function Close-NativeDialog([IntPtr]$DialogHandle) {
    Assert (
        [LumaChartDiagnosticFatalNative]::PostMessage(
            $DialogHandle,
            0x0010,
            [IntPtr]::Zero,
            [IntPtr]::Zero)) (
        "Unable to close the native fatal dialog with WM_CLOSE.")
    return [ordered]@{
        name = "WM_CLOSE"
        automationId = ""
        input = "Win32 WM_CLOSE posted to verified owned native dialog"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

$application = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$output = Resolve-NewDirectory $OutputRoot
$localData = Join-Path $output "isolated-local-data"
$editing = Join-Path $output "isolated-editing"
$workspace = Join-Path $output "isolated-workspace"
$temp = Join-Path $output "temp"
[IO.Directory]::CreateDirectory($localData) | Out-Null
[IO.Directory]::CreateDirectory($editing) | Out-Null
[IO.Directory]::CreateDirectory($workspace) | Out-Null
[IO.Directory]::CreateDirectory($temp) | Out-Null

$savedEnvironment = [ordered]@{}
$environmentNames = @(
    "DOTNET_CLI_HOME",
    "NUGET_PACKAGES",
    "NUGET_HTTP_CACHE_PATH",
    "TEMP",
    "TMP",
    "LUMACHART_AVALONIA_LOCAL_DATA_ROOT",
    "LUMACHART_AVALONIA_EDITING_ROOT",
    "LUMACHART_AVALONIA_WORKSPACE_ROOT",
    "LUMACHART_AVALONIA_ENABLE_CONTROLLED_FATAL"
)
foreach ($name in $environmentNames) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
}

$process = $null
$dialogHandle = [IntPtr]::Zero
$ownerHandle = [IntPtr]::Zero
try {
    $env:DOTNET_CLI_HOME = "D:\Project\LumaChartStudio\.codex-dotnet-home"
    $env:NUGET_PACKAGES = "D:\Project\LumaChartStudio\.codex-nuget-packages"
    $env:NUGET_HTTP_CACHE_PATH = "D:\Project\LumaChartStudio\.codex-nuget-http-cache"
    $env:TEMP = $temp
    $env:TMP = $temp
    $env:LUMACHART_AVALONIA_LOCAL_DATA_ROOT = $localData
    $env:LUMACHART_AVALONIA_EDITING_ROOT = $editing
    $env:LUMACHART_AVALONIA_WORKSPACE_ROOT = $workspace
    $env:LUMACHART_AVALONIA_ENABLE_CONTROLLED_FATAL = "1"

    $process = Start-Process `
        -FilePath $application `
        -ArgumentList @("--evidence-controlled-fatal") `
        -PassThru
    Wait-Condition -Description "native fatal dialog" -Condition {
        $candidate = @(
            [LumaChartDiagnosticFatalNative]::VisibleWindowsForProcess(
                [uint32]$process.Id) |
            Where-Object {
                [LumaChartDiagnosticFatalNative]::ClassName($_) -ceq "#32770"
            }
        ) | Select-Object -First 1
        if ($candidate) {
            $script:dialogHandle = [IntPtr]$candidate
            $script:ownerHandle = [LumaChartDiagnosticFatalNative]::GetWindow(
                $script:dialogHandle,
                4)
            return $script:ownerHandle -ne [IntPtr]::Zero
        }
        return $false
    }

    $root = [Windows.Automation.AutomationElement]::FromHandle($dialogHandle)
    Assert ($null -ne $root) "UI Automation could not open the native fatal dialog."
    $dialogClassName =
        [LumaChartDiagnosticFatalNative]::ClassName($dialogHandle)
    Assert ($dialogClassName -ceq "#32770") (
        "Fatal dialog class drifted: $dialogClassName")
    $dialogText = Get-ElementText $root
    Assert ($dialogText.Contains("LumaChart Studio - 运行错误")) (
        "Fatal dialog caption is missing.")
    Assert ($dialogText.Contains("已安全停止")) (
        "Fatal dialog user notice is missing.")
    Assert ($dialogText.Contains($localData)) (
        "Fatal dialog does not expose the isolated diagnostic path.")
    Assert (-not $dialogText.Contains("diagnostic-secret-token")) (
        "Fatal dialog exposed the controlled token.")
    Assert (-not $dialogText.Contains("diagnostic-room-password")) (
        "Fatal dialog exposed the controlled room password.")

    $activationAttempted = $false
    if ([LumaChartDiagnosticFatalNative]::GetForegroundWindow() -ne $dialogHandle) {
        $activationAttempted = $true
        [void][LumaChartDiagnosticFatalNative]::ActivateNonTopmost($dialogHandle)
    }
    $dialogForeground =
        [LumaChartDiagnosticFatalNative]::GetForegroundWindow() -eq $dialogHandle

    $ownerTopmost =
        [LumaChartDiagnosticFatalNative]::IsTopmostStyleSet($ownerHandle)
    $dialogTopmost =
        [LumaChartDiagnosticFatalNative]::IsTopmostStyleSet($dialogHandle)
    Assert (-not $ownerTopmost) "Fatal owner retained a persistent topmost style."
    Assert (-not $dialogTopmost) "Fatal dialog uses a persistent topmost style."
    Assert (-not [LumaChartDiagnosticFatalNative]::IsWindowEnabled($ownerHandle)) (
        "Fatal owner was not disabled by native owner modality.")
    Assert (
        [LumaChartDiagnosticFatalNative]::GetLastActivePopup($ownerHandle) -eq
        $dialogHandle) (
        "Fatal dialog is not the owner's last-active popup.")

    $dialogBounds = Get-WindowBounds $dialogHandle
    Start-Sleep -Milliseconds 250
    $screenshot = Capture-Window `
        $ownerHandle `
        (Join-Path $output "fatal-diagnostic-dialog.png")
    $action = Close-NativeDialog $dialogHandle

    Wait-Condition -Description "controlled-fatal process exit" -Condition {
        $process.Refresh()
        return $process.HasExited
    }
    $process.Refresh()
    Assert ($process.ExitCode -eq 1) (
        "Expected controlled-fatal exit code 1, found $($process.ExitCode).")

    $logs = @(
        Get-ChildItem -LiteralPath (Join-Path $localData "Logs") `
            -File `
            -Filter "diagnostic-*.jsonl" |
        Sort-Object FullName
    )
    Assert ($logs.Count -ge 1) "No diagnostic JSONL file was written."
    Assert ($logs.Count -le 8) "Diagnostic log retention exceeded 8 files."
    $records = [Collections.Generic.List[object]]::new()
    $combinedText = [Text.StringBuilder]::new()
    foreach ($log in $logs) {
        Assert ($log.Length -le 1048576) (
            "Diagnostic log exceeded 1 MiB: $($log.FullName)")
        foreach ($line in Get-Content -LiteralPath $log.FullName) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            [void]$combinedText.AppendLine($line)
            $records.Add(($line | ConvertFrom-Json))
        }
    }
    $allText = $combinedText.ToString()
    Assert (-not $allText.Contains("diagnostic-secret-token")) (
        "Diagnostic JSONL exposed the controlled token.")
    Assert (-not $allText.Contains("diagnostic-room-password")) (
        "Diagnostic JSONL exposed the controlled room password.")
    Assert ($allText.Contains("[REDACTED]")) (
        "Diagnostic JSONL did not record redaction markers.")
    $events = @($records | ForEach-Object { [string]$_.Event })
    Assert ($events -contains "application-starting") (
        "Diagnostic JSONL is missing application-starting.")
    Assert ($events -contains "application-fatal-exception") (
        "Diagnostic JSONL is missing application-fatal-exception.")
    $fatal = @(
        $records |
        Where-Object { [string]$_.Event -ceq "application-fatal-exception" }
    )
    Assert ($fatal.Count -eq 1) (
        "Expected exactly one application-fatal-exception record.")

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.diagnostic-fatal-gui.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        application = [ordered]@{
            path = $application
            sha256 = (Get-FileHash -LiteralPath $application -Algorithm SHA256).Hash
            processId = $process.Id
            exitCode = $process.ExitCode
        }
        consent = [ordered]@{
            explicitCurrentTurnConsent = $true
            idleMillisecondsBeforeStart =
                $script:WindowsAvaloniaForegroundAutomationIdleMilliseconds
            heldModifiers = 0
        }
        dialog = [ordered]@{
            handle = $dialogHandle.ToInt64()
            ownerHandle = $ownerHandle.ToInt64()
            className = $dialogClassName
            ownerDisabled = $true
            lastActivePopup = $true
            foreground = $dialogForeground
            activationAttempted = $activationAttempted
            ownerTopmostStyle = $ownerTopmost
            dialogTopmostStyle = $dialogTopmost
            text = $dialogText
            bounds = $dialogBounds
        }
        diagnostic = [ordered]@{
            root = [IO.Path]::GetFullPath((Join-Path $localData "Logs"))
            fileCount = $logs.Count
            files = @($logs | ForEach-Object {
                [ordered]@{
                    path = $_.FullName
                    bytes = [long]$_.Length
                    sha256 =
                        (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
                }
            })
            recordCount = $records.Count
            events = $events
            fatalRecordCount = $fatal.Count
            controlledTokenAbsent = $true
            controlledRoomPasswordAbsent = $true
            redactionMarkerPresent = $true
            maximumFiles = 8
            maximumFileBytes = 1048576
        }
        screenshot = $screenshot
        action = $action
        inputSafety = [ordered]@{
            hardwareInputClaimed = $false
            win32InputInjectionUsed = $false
            enterSent = $false
            persistentTopmostUsed = $false
            uiAutomationInvokeUsed = $false
            targetedWindowCloseMessageUsed = $true
        }
        status = "passed"
    }
    $evidencePath = Join-Path $output "gui-evidence.json"
    [IO.File]::WriteAllText(
        $evidencePath,
        ($evidence | ConvertTo-Json -Depth 16),
        [Text.UTF8Encoding]::new($false))
    $result = Get-Item -LiteralPath $evidencePath
    [ordered]@{
        status = "passed"
        evidencePath = $result.FullName
        bytes = [long]$result.Length
        sha256 =
            (Get-FileHash -LiteralPath $result.FullName -Algorithm SHA256).Hash
        screenshot = $screenshot
        exitCode = $process.ExitCode
        recordCount = $records.Count
    } | ConvertTo-Json -Depth 8
}
finally {
    if ($process) {
        try {
            $process.Refresh()
            if (-not $process.HasExited) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }
        }
        catch { }
    }
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable(
            $name,
            [string]$savedEnvironment[$name])
    }
}
