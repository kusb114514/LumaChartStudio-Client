param(
    [Parameter(Mandatory = $true)][string]$ApplicationPath,
    [Parameter(Mandatory = $true)][string]$ServerPath,
    [Parameter(Mandatory = $true)][string]$ChartPath,
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [switch]$AutomationPreflight,
    [ValidateRange(10, 90)][int]$TimeoutSeconds = 35,
    [switch]$AllowForegroundAutomation
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia update GUI capture requires PowerShell Core on Windows."
}
if (-not $AllowForegroundAutomation) {
    throw (
        "Foreground GUI automation is disabled. Pass " +
        "-AllowForegroundAutomation only after the user explicitly confirms " +
        "that the desktop is available.")
}
$modeLabel = if ($AutomationPreflight) { "预演" } else { "验收" }
$script:physicalBehaviorActionCount = 0
$script:physicalSetupClickCount = 0
$script:automationScrollSetupCount = 0

function Resolve-NewDirectory([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Output root already exists: $full" }
    New-Item -ItemType Directory -Force -Path $full | Out-Null
    return $full
}

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 90000)][int]$TimeoutMilliseconds
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children,
                $processCondition)
            foreach ($root in $roots) {
                if ([string]::Equals(
                        [string]$root.Current.AutomationId,
                        $AutomationId,
                        [StringComparison]::Ordinal)) { return $root }
                $candidate = $root.FindFirst(
                    [Windows.Automation.TreeScope]::Descendants,
                    $idCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Wait-ElementVisibility {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][bool]$Visible,
        [ValidateRange(100, 90000)][int]$TimeoutMilliseconds
    )
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $element = Find-ElementById `
                -ProcessId $ProcessId `
                -AutomationId $AutomationId `
                -TimeoutMilliseconds 250
            if ((-not [bool]$element.Current.IsOffscreen) -eq $Visible) { return $element }
        }
        catch {
            if (-not $Visible) { return $null }
        }
        Start-Sleep -Milliseconds 75
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out waiting for '$AutomationId' visible=$Visible."
}

function Observe-Element($Element) {
    $bounds = $Element.Current.BoundingRectangle
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        controlType = [string]$Element.Current.ControlType.ProgrammaticName
        isEnabled = [bool]$Element.Current.IsEnabled
        isOffscreen = [bool]$Element.Current.IsOffscreen
        nativeWindowHandle = [long]$Element.Current.NativeWindowHandle
        bounds = [ordered]@{
            left = [double]$bounds.Left
            top = [double]$bounds.Top
            width = [double]$bounds.Width
            height = [double]$bounds.Height
        }
    }
}

function Invoke-ElementDiagnostic($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' has no InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        mechanism = "UIAutomation.InvokePattern"
        utc = [DateTimeOffset]::UtcNow.ToString("O")
        physicalInput = $false
    }
}

function Select-ElementDiagnostic($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' has no SelectionItemPattern."
    }
    ([Windows.Automation.SelectionItemPattern]$pattern).Select()
    Start-Sleep -Milliseconds 250
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        mechanism = "UIAutomation.SelectionItemPattern"
        utc = [DateTimeOffset]::UtcNow.ToString("O")
        physicalInput = $false
    }
}

function Bring-ElementIntoViewSetup($Element) {
    $pattern = $null
    $scrolled = $false
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.ScrollItemPattern]::Pattern,
            [ref]$pattern)) {
        ([Windows.Automation.ScrollItemPattern]$pattern).ScrollIntoView()
        $script:automationScrollSetupCount++
        $scrolled = $true
        Start-Sleep -Milliseconds 250
    }
    if ($Element.Current.IsOffscreen) {
        throw "Element '$($Element.Current.AutomationId)' remained offscreen."
    }
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        mechanism = if ($scrolled) {
            "UIAutomation.ScrollItemPattern setup only"
        } else {
            "already visible; no scroll setup"
        }
        automationSetupUsed = $scrolled
        physicalInput = $false
    }
}

function Click-ElementPhysical($Element, [IntPtr]$WindowHandle) {
    $bounds = $Element.Current.BoundingRectangle
    if (-not $Element.Current.IsEnabled -or
        $bounds.Width -le 1 -or
        $bounds.Height -le 1 -or
        $Element.Current.IsOffscreen) {
        throw "Element '$($Element.Current.AutomationId)' has no enabled physical click target."
    }
    if (-not [LumaChartAppUpdateNative]::TryActivateWindow($WindowHandle)) {
        throw "Unable to activate window $WindowHandle before physical click."
    }
    $x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    if (-not [LumaChartAppUpdateNative]::SetCursorPos($x, $y)) {
        throw "SetCursorPos failed for '$($Element.Current.AutomationId)'."
    }
    Start-Sleep -Milliseconds 75
    $actual = [LumaChartAppUpdateNative+POINT]::new()
    if (-not [LumaChartAppUpdateNative]::GetCursorPos([ref]$actual) -or
        [Math]::Abs($actual.X - $x) -gt 2 -or
        [Math]::Abs($actual.Y - $y) -gt 2) {
        throw "Physical cursor did not reach '$($Element.Current.AutomationId)' " +
              "at ($x,$y); actual=($($actual.X),$($actual.Y))."
    }
    if ([LumaChartAppUpdateNative]::GetForegroundWindow() -ne $WindowHandle) {
        throw "Window $WindowHandle lost foreground before physical click."
    }
    if (-not [LumaChartAppUpdateNative]::IsWindowAtPoint(
            $WindowHandle,
            $x,
            $y)) {
        throw "Element '$($Element.Current.AutomationId)' is obscured at ($x,$y)."
    }
    [LumaChartAppUpdateNative]::mouse_event(
        0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 45
    [LumaChartAppUpdateNative]::mouse_event(
        0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 260
    $script:physicalBehaviorActionCount++
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        mechanism = "Win32 physical mouse click"
        utc = [DateTimeOffset]::UtcNow.ToString("O")
        physicalInput = $true
        point = [ordered]@{ x = $x; y = $y }
    }
}

function Invoke-PhysicalWindowActivationPreflight([IntPtr]$WindowHandle) {
    $rectangle = [LumaChartAppUpdateNative+RECT]::new()
    if (-not [LumaChartAppUpdateNative]::GetWindowRect(
            $WindowHandle,
            [ref]$rectangle)) {
        throw "Unable to read the window before physical activation preflight."
    }
    $width = $rectangle.Right - $rectangle.Left
    $scale = [Math]::Clamp($width / 1320.0, 0.75, 3.0)
    $x = $rectangle.Left + [int][Math]::Round(90 * $scale)
    $y = $rectangle.Top + [int][Math]::Round(19 * $scale)
    $notTopmost = [IntPtr](-2)
    $noMoveNoSizeShow = [uint32](0x0001 -bor 0x0002 -bor 0x0040)
    if (-not [LumaChartAppUpdateNative]::SetWindowPos(
            $WindowHandle,
            $notTopmost,
            0,
            0,
            0,
            0,
            $noMoveNoSizeShow)) {
        throw "Unable to clear topmost state before activation preflight."
    }
    try {
        [void][LumaChartAppUpdateNative]::BringWindowToTop($WindowHandle)
        if (-not [LumaChartAppUpdateNative]::SetCursorPos($x, $y)) {
            throw "SetCursorPos failed for physical activation preflight."
        }
        Start-Sleep -Milliseconds 75
        $actual = [LumaChartAppUpdateNative+POINT]::new()
        if (-not [LumaChartAppUpdateNative]::GetCursorPos([ref]$actual) -or
            [Math]::Abs($actual.X - $x) -gt 2 -or
            [Math]::Abs($actual.Y - $y) -gt 2 -or
            -not [LumaChartAppUpdateNative]::IsWindowAtPoint(
                $WindowHandle,
                $x,
                $y)) {
            throw "Physical activation preflight did not reach the title bar."
        }
        [LumaChartAppUpdateNative]::mouse_event(
            0x0002, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 45
        [LumaChartAppUpdateNative]::mouse_event(
            0x0004, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 420
        if (-not [LumaChartAppUpdateNative]::TryActivateWindow($WindowHandle)) {
            throw "Physical activation preflight did not activate the window."
        }
        $script:physicalSetupClickCount++
    }
    finally {
        [void][LumaChartAppUpdateNative]::SetWindowPos(
            $WindowHandle,
            $notTopmost,
            0,
            0,
            0,
            0,
            $noMoveNoSizeShow)
    }
    return [ordered]@{
        mechanism = "recorded physical title-bar activation click"
        utc = [DateTimeOffset]::UtcNow.ToString("O")
        physicalInput = $true
        behaviorAction = $false
        point = [ordered]@{ x = $x; y = $y }
    }
}

function Invoke-ElementAction($Element, [IntPtr]$WindowHandle) {
    if ($AutomationPreflight) {
        return Invoke-ElementDiagnostic $Element
    }
    return Click-ElementPhysical $Element $WindowHandle
}

function Select-ElementAction($Element, [IntPtr]$WindowHandle) {
    if ($AutomationPreflight) {
        return Select-ElementDiagnostic $Element
    }
    return Click-ElementPhysical $Element $WindowHandle
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartAppUpdateNative+RECT]::new()
    if (-not [LumaChartAppUpdateNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 800 -or $height -lt 500) {
        throw "Avalonia main window has invalid bounds: ${width}x${height}."
    }
    $bitmap = [Drawing.Bitmap]::new(
        $width,
        $height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $deviceContext = $graphics.GetHdc()
            try {
                if (-not [LumaChartAppUpdateNative]::PrintWindow(
                        $Handle,
                        $deviceContext,
                        2)) {
                    throw "PrintWindow failed for the Avalonia main window."
                }
            }
            finally { $graphics.ReleaseHdc($deviceContext) }
        }
        finally { $graphics.Dispose() }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $bitmap.Dispose() }
    return [ordered]@{
        path = $Path
        width = $width
        height = $height
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

function Wait-ReadyFile([string]$Path, [Diagnostics.Process]$Process) {
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        if ($Process.HasExited) {
            throw "Loopback GUI server exited before publishing readiness."
        }
        if (Test-Path -LiteralPath $Path) {
            try { return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json }
            catch { }
        }
        Start-Sleep -Milliseconds 75
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Loopback GUI server readiness timed out."
}

function Start-LoopbackServer {
    param(
        [string]$ReadyPath,
        [string]$StatePath,
        [string]$Latest,
        [string]$Minimum,
        [string]$Notice,
        [string]$Download
    )
    $start = [Diagnostics.ProcessStartInfo]::new($script:serverFullPath)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $serverTemp = Join-Path (Split-Path -Parent $ReadyPath) "server-temp"
    New-Item -ItemType Directory -Force -Path $serverTemp | Out-Null
    $start.Environment["TEMP"] = $serverTemp
    $start.Environment["TMP"] = $serverTemp
    foreach ($argument in @(
            "--ready-file", $ReadyPath,
            "--state-file", $StatePath,
            "--app-about-content", "Windows Avalonia 更新 GUI 隔离$script:modeLabel。",
            "--app-latest-version", $Latest,
            "--app-minimum-login-version", $Minimum,
            "--app-update-notice", $Notice,
            "--app-download-url", $Download)) {
        [void]$start.ArgumentList.Add($argument)
    }
    return [Diagnostics.Process]::Start($start)
}

function Start-IsolatedApplication {
    param(
        [string]$Endpoint,
        [string]$ScenarioRoot,
        [string]$Profile,
        [string[]]$Arguments = @()
    )
    $workspace = Join-Path $ScenarioRoot "workspace"
    $localData = Join-Path $ScenarioRoot "local-data"
    $editing = Join-Path $ScenarioRoot "editing"
    $clientTemp = Join-Path $ScenarioRoot "client-temp"
    New-Item -ItemType Directory -Force -Path `
        $workspace,$localData,$editing,$clientTemp | Out-Null
    $start = [Diagnostics.ProcessStartInfo]::new($script:applicationFullPath)
    $start.UseShellExecute = $false
    $start.Environment["LUMACHART_SERVER_URL"] = $Endpoint
    $start.Environment["LUMACHART_PROFILE"] = $Profile
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localData
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
    $start.Environment["TEMP"] = $clientTemp
    $start.Environment["TMP"] = $clientTemp
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    return [Diagnostics.Process]::Start($start)
}

function Wait-MainWindow([Diagnostics.Process]$Process) {
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($Process.MainWindowHandle -eq [IntPtr]::Zero -and
           [DateTime]::UtcNow -lt $deadline) {
        if ($Process.HasExited) { throw "Avalonia exited before opening its main window." }
        $Process.Refresh()
        Start-Sleep -Milliseconds 100
    }
    if ($Process.MainWindowHandle -eq [IntPtr]::Zero) {
        throw "Avalonia main window was unavailable."
    }
    return [IntPtr]$Process.MainWindowHandle
}

function Stop-OwnedProcess([Diagnostics.Process]$Process) {
    if ($null -eq $Process) { return }
    try {
        if (-not $Process.HasExited) {
            $Process.Kill($true)
            [void]$Process.WaitForExit(5000)
        }
    }
    catch { }
    finally { $Process.Dispose() }
}

$applicationFullPath = [IO.Path]::GetFullPath($ApplicationPath)
$serverFullPath = [IO.Path]::GetFullPath($ServerPath)
$chartFullPath = [IO.Path]::GetFullPath($ChartPath)
$projectRoot = Split-Path -Parent $PSScriptRoot
$installerFullPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$predecessorVerificationPath = Join-Path $projectRoot (
    "artifacts\windows-avalonia-window-move-snap-slice-20260727-r1\" +
    "verification-evidence.json")
if (-not (Test-Path -LiteralPath $applicationFullPath -PathType Leaf)) {
    throw "Avalonia executable not found: $applicationFullPath"
}
if (-not (Test-Path -LiteralPath $serverFullPath -PathType Leaf)) {
    throw "Loopback GUI server executable not found: $serverFullPath"
}
if (-not (Test-Path -LiteralPath $chartFullPath -PathType Leaf)) {
    throw "Real chart fixture not found: $chartFullPath"
}
if (-not (Test-Path -LiteralPath $installerFullPath -PathType Leaf)) {
    throw "Frozen WPF installer not found: $installerFullPath"
}
if (-not (Test-Path -LiteralPath $predecessorVerificationPath -PathType Leaf)) {
    throw "Window-move/Snap predecessor evidence not found: $predecessorVerificationPath"
}
$chartHashBefore = (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
$installerHashBefore = (
    Get-FileHash -LiteralPath $installerFullPath -Algorithm SHA256).Hash
$predecessorHash = (
    Get-FileHash -LiteralPath $predecessorVerificationPath -Algorithm SHA256).Hash
$outputFullRoot = Resolve-NewDirectory $OutputRoot

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Threading;
public static class LumaChartAppUpdateNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT
    {
        public int X;
        public int Y;
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(
        IntPtr window,
        IntPtr deviceContext,
        uint flags);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr window);

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
    public static extern bool ShowWindowAsync(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern void SwitchToThisWindow(IntPtr window, bool altTab);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(
        IntPtr window,
        out uint processId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(
        uint firstThread,
        uint secondThread,
        bool attach);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT point);

    [DllImport("user32.dll")]
    public static extern IntPtr WindowFromPoint(POINT point);

    [DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr window, uint flags);

    [DllImport("user32.dll")]
    public static extern void mouse_event(
        uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

    public static bool TryActivateWindow(IntPtr window)
    {
        if (window == IntPtr.Zero) return false;
        for (var attempt = 0; attempt < 4; attempt++)
        {
            if (GetForegroundWindow() == window) return true;
            var foreground = GetForegroundWindow();
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
                    attachedForeground = AttachThreadInput(
                        currentThread,
                        foregroundThread,
                        true);
                if (targetThread != 0 &&
                    targetThread != currentThread &&
                    targetThread != foregroundThread)
                {
                    attachedTarget = AttachThreadInput(
                        currentThread,
                        targetThread,
                        true);
                }
                ShowWindowAsync(window, 5);
                BringWindowToTop(window);
                SetForegroundWindow(window);
                SwitchToThisWindow(window, true);
            }
            finally
            {
                if (attachedTarget)
                    AttachThreadInput(currentThread, targetThread, false);
                if (attachedForeground)
                    AttachThreadInput(currentThread, foregroundThread, false);
            }
            Thread.Sleep(75);
        }
        return GetForegroundWindow() == window;
    }

    public static bool IsWindowAtPoint(IntPtr window, int x, int y)
    {
        const uint root = 2;
        var hit = WindowFromPoint(new POINT { X = x, Y = y });
        if (hit == IntPtr.Zero) return false;
        var hitRoot = GetAncestor(hit, root);
        var expectedRoot = GetAncestor(window, root);
        if (hitRoot == expectedRoot) return true;
        GetWindowThreadProcessId(hitRoot, out var hitProcessId);
        GetWindowThreadProcessId(expectedRoot, out var expectedProcessId);
        return hitProcessId != 0 && hitProcessId == expectedProcessId;
    }
}
'@

$script:modeLabel = $modeLabel
$scenarioResults = [Collections.Generic.List[object]]::new()
$scenarios = @(
    [ordered]@{
        id = "available"
        latest = "1.2.0"
        minimum = "1.0.0"
        notice = "Windows Avalonia 发现新版本 GUI $modeLabel。"
        download = "https://example.invalid/avalonia-update"
        title = "发现新版本"
        version = "当前 1.1.0  →  最新 1.2.0"
        later = "关闭"
        downloadEnabled = $true
        blocksLogin = $false
    },
    [ordered]@{
        id = "required"
        latest = "2.0.0"
        minimum = "1.1.1"
        notice = "Windows Avalonia 最低版本登录门禁 GUI $modeLabel。"
        download = ""
        title = "必须更新后才能登录"
        version = "当前 1.1.0  →  最新 2.0.0"
        later = "离线使用"
        downloadEnabled = $false
        blocksLogin = $true
    })

try {
    foreach ($scenario in $scenarios) {
        $scenarioRoot = Join-Path $outputFullRoot $scenario.id
        New-Item -ItemType Directory -Force -Path $scenarioRoot | Out-Null
        $readyPath = Join-Path $scenarioRoot "server-ready.json"
        $statePath = Join-Path $scenarioRoot "server-state.json"
        $server = $null
        $application = $null
        try {
            $server = Start-LoopbackServer `
                -ReadyPath $readyPath `
                -StatePath $statePath `
                -Latest $scenario.latest `
                -Minimum $scenario.minimum `
                -Notice $scenario.notice `
                -Download $scenario.download
            $ready = Wait-ReadyFile $readyPath $server
            $application = Start-IsolatedApplication `
                -Endpoint ([string]$ready.endpoint) `
                -ScenarioRoot $scenarioRoot `
                -Profile "app-update-$(
                    if ($AutomationPreflight) { 'preflight' } else { 'formal' }
                )-$($scenario.id)"
            $handle = Wait-MainWindow $application
            $activationSetup = if ($AutomationPreflight) {
                [ordered]@{
                    mechanism = "not used in diagnostic automation preflight"
                    physicalInput = $false
                    behaviorAction = $false
                }
            }
            else {
                Invoke-PhysicalWindowActivationPreflight $handle
            }

            $layer = Wait-ElementVisibility `
                -ProcessId $application.Id `
                -AutomationId "Update.Layer" `
                -Visible $true `
                -TimeoutMilliseconds ($TimeoutSeconds * 1000)
            $title = Find-ElementById $application.Id "Update.Title" 3000
            $version = Find-ElementById $application.Id "Update.Version" 3000
            $notice = Find-ElementById $application.Id "Update.Notice" 3000
            $later = Find-ElementById $application.Id "Update.Later" 3000
            $download = Find-ElementById $application.Id "Update.Download" 3000
            $observed = [ordered]@{
                layer = Observe-Element $layer
                title = Observe-Element $title
                version = Observe-Element $version
                notice = Observe-Element $notice
                later = Observe-Element $later
                download = Observe-Element $download
            }
            if ($observed.layer.nativeWindowHandle -ne 0) {
                throw "Update prompt unexpectedly opened a separate native window."
            }
            if ($observed.title.name -ne $scenario.title -or
                $observed.version.name -ne $scenario.version -or
                $observed.notice.name -ne $scenario.notice -or
                $observed.later.name -ne $scenario.later -or
                $observed.download.isEnabled -ne $scenario.downloadEnabled) {
                throw "Update prompt content did not match scenario '$($scenario.id)'."
            }
            $helpText = [string]$layer.GetCurrentPropertyValue(
                [Windows.Automation.AutomationElement]::HelpTextProperty)
            if ($helpText -notmatch "BlocksLogin=$($scenario.blocksLogin)" -or
                $helpText -notmatch "DownloadEnabled=$($scenario.downloadEnabled)") {
                throw "Update prompt policy metadata did not match scenario '$($scenario.id)': $helpText"
            }
            $promptScreenshot = Capture-Window `
                -Handle $handle `
                -Path (Join-Path $scenarioRoot "update-prompt.png")
            $dismiss = Invoke-ElementAction $later $handle
            [void](Wait-ElementVisibility `
                -ProcessId $application.Id `
                -AutomationId "Update.Layer" `
                -Visible $false `
                -TimeoutMilliseconds 5000)

            if ($scenario.blocksLogin) {
                $libraryRefresh = Wait-ElementVisibility `
                    -ProcessId $application.Id `
                    -AutomationId "Library.Refresh" `
                    -Visible $true `
                    -TimeoutMilliseconds 5000
                $after = [ordered]@{
                    libraryRefresh = Observe-Element $libraryRefresh
                    accountLayerVisible = $false
                }
                try {
                    $account = Find-ElementById $application.Id "OnlineAccount.Layer" 300
                    $after.accountLayerVisible = -not [bool]$account.Current.IsOffscreen
                }
                catch { }
                if ($after.accountLayerVisible) {
                    throw "Minimum-version scenario exposed the login surface after offline selection."
                }
            }
            else {
                $account = Wait-ElementVisibility `
                    -ProcessId $application.Id `
                    -AutomationId "OnlineAccount.Layer" `
                    -Visible $true `
                    -TimeoutMilliseconds 8000
                $offline = Find-ElementById $application.Id "OnlineAccount.ContinueOffline" 3000
                $after = [ordered]@{
                    account = Observe-Element $account
                    offline = Observe-Element $offline
                    offlineDismiss = Invoke-ElementAction $offline $handle
                }
                [void](Wait-ElementVisibility `
                    -ProcessId $application.Id `
                    -AutomationId "OnlineAccount.Layer" `
                    -Visible $false `
                    -TimeoutMilliseconds 5000)
            }

            $afterScreenshot = Capture-Window `
                -Handle $handle `
                -Path (Join-Path $scenarioRoot "after-offline.png")
            $serverState = Invoke-RestMethod `
                -Method Get `
                -Uri ([Uri]::new([Uri][string]$ready.endpoint, "harness/state"))
            $configurationRequestCount = @(
                $serverState.requests |
                    Where-Object { [string]$_ -like "GET /api/app-config*" }
            ).Count
            $loginRequestCount = @(
                $serverState.requests |
                    Where-Object { [string]$_ -like "* /api/auth/login*" }
            ).Count
            if ($configurationRequestCount -lt 1 -or $loginRequestCount -ne 0) {
                throw "Scenario '$($scenario.id)' request routing differed: " +
                      "appConfig=$configurationRequestCount; login=$loginRequestCount."
            }
            $scenarioResults.Add([ordered]@{
                id = $scenario.id
                expected = $scenario
                observed = $observed
                policyHelpText = $helpText
                dismiss = $dismiss
                after = $after
                promptScreenshot = $promptScreenshot
                afterScreenshot = $afterScreenshot
                appConfiguration = $serverState.appConfiguration
                appConfigurationRequestCount = $configurationRequestCount
                loginRequestCount = $loginRequestCount
                activationSetup = $activationSetup
                applicationPid = $application.Id
                serverPid = $server.Id
            })
        }
        finally {
            Stop-OwnedProcess $application
            Stop-OwnedProcess $server
        }
    }

    $settingsRoot = Join-Path $outputFullRoot "settings-about-current"
    New-Item -ItemType Directory -Force -Path $settingsRoot | Out-Null
    $settingsReadyPath = Join-Path $settingsRoot "server-ready.json"
    $settingsStatePath = Join-Path $settingsRoot "server-state.json"
    $settingsServer = $null
    $settingsApplication = $null
    try {
        $settingsServer = Start-LoopbackServer `
            -ReadyPath $settingsReadyPath `
            -StatePath $settingsStatePath `
            -Latest "1.1.0" `
            -Minimum "1.1.0" `
            -Notice "当前版本无需更新。" `
            -Download "https://example.invalid/current"
        $settingsReady = Wait-ReadyFile $settingsReadyPath $settingsServer
        $settingsApplication = Start-IsolatedApplication `
            -Endpoint ([string]$settingsReady.endpoint) `
            -ScenarioRoot $settingsRoot `
            -Profile "app-update-$(
                if ($AutomationPreflight) { 'preflight' } else { 'formal' }
            )-settings" `
            -Arguments @("--evidence-chart", $chartFullPath)
        $settingsHandle = Wait-MainWindow $settingsApplication
        [void](Wait-ElementVisibility `
            -ProcessId $settingsApplication.Id `
            -AutomationId "Timeline.Surface" `
            -Visible $true `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000))
        $settingsActivationSetup = if ($AutomationPreflight) {
            [ordered]@{
                mechanism = "not used in diagnostic automation preflight"
                physicalInput = $false
                behaviorAction = $false
            }
        }
        else {
            Invoke-PhysicalWindowActivationPreflight $settingsHandle
        }
        $settingsTab = Find-ElementById `
            $settingsApplication.Id `
            "Inspector.SettingsTab" `
            5000
        $settingsTabSelection = Select-ElementAction $settingsTab $settingsHandle
        $settingsAbout = Find-ElementById `
            $settingsApplication.Id `
            "Settings.About" `
            5000
        $aboutScrollSetup = Bring-ElementIntoViewSetup $settingsAbout
        $settingsVersion = Find-ElementById `
            $settingsApplication.Id `
            "Settings.Version" `
            3000
        $settingsCheck = Find-ElementById `
            $settingsApplication.Id `
            "Settings.CheckForUpdates" `
            3000
        if ($settingsVersion.Current.Name -ne
            "当前版本 1.1.0 · 最新 1.1.0") {
            throw "Settings version text did not consume the current app configuration."
        }
        $settingsScreenshot = Capture-Window `
            -Handle $settingsHandle `
            -Path (Join-Path $settingsRoot "settings-application-information.png")

        $aboutOpen = Invoke-ElementAction $settingsAbout $settingsHandle
        $aboutLayer = Wait-ElementVisibility `
            -ProcessId $settingsApplication.Id `
            -AutomationId "About.Layer" `
            -Visible $true `
            -TimeoutMilliseconds 5000
        $aboutVersion = Find-ElementById `
            $settingsApplication.Id `
            "About.Version" `
            3000
        $aboutContent = Find-ElementById `
            $settingsApplication.Id `
            "About.Content" `
            3000
        $aboutClose = Find-ElementById `
            $settingsApplication.Id `
            "About.Close" `
            3000
        if ($aboutVersion.Current.Name -ne "版本 1.1.0" -or
            $aboutContent.Current.Name -ne
                "Windows Avalonia 更新 GUI 隔离$modeLabel。") {
            throw "About content/version did not consume the public app configuration."
        }
        $aboutLayerObservation = Observe-Element $aboutLayer
        $aboutVersionObservation = Observe-Element $aboutVersion
        $aboutContentObservation = Observe-Element $aboutContent
        $aboutScreenshot = Capture-Window `
            -Handle $settingsHandle `
            -Path (Join-Path $settingsRoot "about.png")
        $aboutDismiss = Invoke-ElementAction $aboutClose $settingsHandle
        [void](Wait-ElementVisibility `
            -ProcessId $settingsApplication.Id `
            -AutomationId "About.Layer" `
            -Visible $false `
            -TimeoutMilliseconds 5000)

        $checkScrollSetup = Bring-ElementIntoViewSetup $settingsCheck
        $checkAction = Invoke-ElementAction $settingsCheck $settingsHandle
        $currentLayer = Wait-ElementVisibility `
            -ProcessId $settingsApplication.Id `
            -AutomationId "Update.Layer" `
            -Visible $true `
            -TimeoutMilliseconds 8000
        $currentTitle = Find-ElementById `
            $settingsApplication.Id `
            "Update.Title" `
            3000
        $currentVersion = Find-ElementById `
            $settingsApplication.Id `
            "Update.Version" `
            3000
        $currentNotice = Find-ElementById `
            $settingsApplication.Id `
            "Update.Notice" `
            3000
        $currentLater = Find-ElementById `
            $settingsApplication.Id `
            "Update.Later" `
            3000
        if ($currentTitle.Current.Name -ne "已经是最新版本" -or
            $currentVersion.Current.Name -ne "当前 1.1.0  →  最新 1.1.0" -or
            $currentNotice.Current.Name -ne "当前客户端已经是最新版本。" -or
            $currentLater.Current.Name -ne "关闭") {
            throw "Settings check-update current-version presentation differed from WPF 1.1.0."
        }
        $currentLayerObservation = Observe-Element $currentLayer
        $currentTitleObservation = Observe-Element $currentTitle
        $currentVersionObservation = Observe-Element $currentVersion
        $currentNoticeObservation = Observe-Element $currentNotice
        $currentScreenshot = Capture-Window `
            -Handle $settingsHandle `
            -Path (Join-Path $settingsRoot "already-current.png")
        $currentDismiss = Invoke-ElementAction $currentLater $settingsHandle
        [void](Wait-ElementVisibility `
            -ProcessId $settingsApplication.Id `
            -AutomationId "Update.Layer" `
            -Visible $false `
            -TimeoutMilliseconds 5000)
        $settingsServerState = Invoke-RestMethod `
            -Method Get `
            -Uri ([Uri]::new(
                [Uri][string]$settingsReady.endpoint,
                "harness/state"))
        $settingsConfigurationRequestCount = @(
            $settingsServerState.requests |
                Where-Object { [string]$_ -like "GET /api/app-config*" }
        ).Count
        $settingsLoginRequestCount = @(
            $settingsServerState.requests |
                Where-Object { [string]$_ -like "* /api/auth/login*" }
        ).Count
        if ($settingsConfigurationRequestCount -lt 2 -or
            $settingsLoginRequestCount -ne 0) {
            throw "Settings update routing differed: appConfig=$(
                $settingsConfigurationRequestCount); login=$settingsLoginRequestCount."
        }
        $settingsScenario = [ordered]@{
            chartPath = $chartFullPath
            chartSha256Before = $chartHashBefore
            activationSetup = $settingsActivationSetup
            settingsTabSelection = $settingsTabSelection
            settingsVersion = Observe-Element $settingsVersion
            aboutScrollSetup = $aboutScrollSetup
            aboutOpen = $aboutOpen
            aboutLayer = $aboutLayerObservation
            aboutVersion = $aboutVersionObservation
            aboutContent = $aboutContentObservation
            aboutDismiss = $aboutDismiss
            checkScrollSetup = $checkScrollSetup
            checkAction = $checkAction
            currentLayer = $currentLayerObservation
            currentTitle = $currentTitleObservation
            currentVersion = $currentVersionObservation
            currentNotice = $currentNoticeObservation
            currentDismiss = $currentDismiss
            settingsScreenshot = $settingsScreenshot
            aboutScreenshot = $aboutScreenshot
            currentScreenshot = $currentScreenshot
            appConfigurationRequestCount = $settingsConfigurationRequestCount
            loginRequestCount = $settingsLoginRequestCount
            applicationPid = $settingsApplication.Id
            serverPid = $settingsServer.Id
        }
    }
    finally {
        Stop-OwnedProcess $settingsApplication
        Stop-OwnedProcess $settingsServer
    }
    $chartHashAfter = (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
    if ($chartHashAfter -ne $chartHashBefore) {
        throw "Real chart fixture changed during update/settings GUI $modeLabel."
    }
    $settingsScenario.chartSha256After = $chartHashAfter
    $installerHashAfter = (
        Get-FileHash -LiteralPath $installerFullPath -Algorithm SHA256).Hash
    if ($installerHashAfter -ne $installerHashBefore) {
        throw "Frozen WPF installer changed during update/settings GUI $modeLabel."
    }
    if (-not $AutomationPreflight -and
        ($script:physicalBehaviorActionCount -ne 8 -or
         $script:physicalSetupClickCount -ne 3)) {
        throw "Formal input count differs: behavior=$(
            $script:physicalBehaviorActionCount), setup=$(
            $script:physicalSetupClickCount)."
    }

    $evidence = [ordered]@{
        schema = if ($AutomationPreflight) {
            "windows-avalonia-app-update-gui-preflight-v3"
        } else {
            "lumachart.windows.avalonia.app-update-gui-evidence.v1"
        }
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = if ($AutomationPreflight) {
            "diagnostic-preflight-not-formal"
        } else {
            "passed-migration-incomplete"
        }
        windowsAvaloniaOnly = $true
        productionServerMutationPerformed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        formalPhysicalInput = -not [bool]$AutomationPreflight
        input = [ordered]@{
            physicalMouseInputUsed = -not [bool]$AutomationPreflight
            physicalBehaviorActionCount =
                [long]$script:physicalBehaviorActionCount
            physicalSetupActivationClickCount =
                [long]$script:physicalSetupClickCount
            automationScrollSetupCount =
                [long]$script:automationScrollSetupCount
            keyboardInputUsed = $false
            uncommittedImeCompositionRequired = $false
            hardwareInputClaimed = $false
            externalDownloadLinkClicked = $false
            browserOpened = $false
            diagnosticActionMechanism = if ($AutomationPreflight) {
                "UIAutomation Invoke/Selection patterns"
            } else {
                $null
            }
            formalActionMechanism = if ($AutomationPreflight) {
                $null
            } else {
                "Win32 physical mouse clicks; UI Automation observation/scroll setup only"
            }
        }
        applicationPath = $applicationFullPath
        applicationSha256 = (
            Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
        serverPath = $serverFullPath
        serverSha256 = (
            Get-FileHash -LiteralPath $serverFullPath -Algorithm SHA256).Hash
        scenarios = $scenarioResults
        settingsAboutAndCurrent = $settingsScenario
        source = [ordered]@{
            path = $chartFullPath
            sha256Before = $chartHashBefore
            sha256After = $chartHashAfter
            unchanged = $chartHashBefore -ceq $chartHashAfter
        }
        frozenInstaller = [ordered]@{
            path = $installerFullPath
            sha256Before = $installerHashBefore
            sha256After = $installerHashAfter
            unchanged = $installerHashBefore -ceq $installerHashAfter
        }
        predecessor = [ordered]@{
            path = $predecessorVerificationPath
            sha256 = $predecessorHash
        }
        completion = [ordered]@{
            appUpdatePresentationAndMinimumLoginGateSlicePassed =
                -not [bool]$AutomationPreflight
            actualDownloadInstallUpgradeRollbackRestartTested = $false
            windowsAvaloniaOneToOneComplete = $false
            userReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
        }
    }
    $evidencePath = Join-Path $outputFullRoot "gui-evidence.json"
    $evidence | ConvertTo-Json -Depth 20 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Write-Output "Windows Avalonia app-update GUI $modeLabel passed."
    Write-Output "Evidence: $evidencePath"
}
catch {
    $failurePath = Join-Path $outputFullRoot "gui-failure.txt"
    $_ | Out-String | Set-Content -LiteralPath $failurePath -Encoding utf8
    throw
}
