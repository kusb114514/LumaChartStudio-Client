param(
    [Parameter(Mandatory = $true)][string]$ApplicationPath,
    [Parameter(Mandatory = $true)][string]$ServerAssemblyPath,
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [switch]$RoomPasswordScenario,
    [switch]$OwnerAdminScenario,
    [switch]$OwnerAdminAutomationPreflight,
    [ValidateRange(15, 90)][int]$TimeoutSeconds = 45,
    [switch]$AllowForegroundAutomation
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia online-surface GUI capture requires PowerShell Core on Windows."
}
if (-not $AllowForegroundAutomation) {
    throw (
        "Foreground GUI automation is disabled. Pass " +
        "-AllowForegroundAutomation only after the user explicitly confirms " +
        "that the desktop is available.")
}
if ($RoomPasswordScenario -and $OwnerAdminScenario) {
    throw "RoomPasswordScenario and OwnerAdminScenario are mutually exclusive."
}
if ($OwnerAdminAutomationPreflight -and -not $OwnerAdminScenario) {
    throw "OwnerAdminAutomationPreflight requires OwnerAdminScenario."
}

function Resolve-NewDirectory([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Output already exists: $full" }
    New-Item -ItemType Directory -Force -Path $full | Out-Null
    return $full
}

function Wait-File([string]$Path, [string]$Description, [int]$Seconds) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while (-not (Test-Path -LiteralPath $Path -PathType Leaf) -and
           [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 100
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Timed out waiting for $Description."
    }
}

$applicationFullPath = [IO.Path]::GetFullPath($ApplicationPath)
$serverFullPath = [IO.Path]::GetFullPath($ServerAssemblyPath)
if (-not (Test-Path -LiteralPath $applicationFullPath -PathType Leaf)) {
    throw "Avalonia executable not found: $applicationFullPath"
}
if (-not (Test-Path -LiteralPath $serverFullPath -PathType Leaf)) {
    throw "Loopback GUI server assembly not found: $serverFullPath"
}
$outputFullPath = Resolve-NewDirectory $OutputRoot
$readyPath = Join-Path $outputFullPath "server-ready.json"
$statePath = Join-Path $outputFullPath "server-state.json"
$profileScreenshotPath = Join-Path $outputFullPath "community-profile.png"
$roomsScreenshotPath = Join-Path $outputFullPath "community-rooms.png"
$roomPasswordScreenshotPath = Join-Path $outputFullPath "room-password.png"
$roomPasswordErrorScreenshotPath = Join-Path $outputFullPath "room-password-error.png"
$roomPasswordCancelledScreenshotPath =
    Join-Path $outputFullPath "room-password-cancelled.png"
$adminConfigurationScreenshotPath =
    Join-Path $outputFullPath "admin-configuration-loaded.png"
$adminConfigurationSavedScreenshotPath =
    Join-Path $outputFullPath "admin-configuration-saved.png"
$adminUserScreenshotPath = Join-Path $outputFullPath "admin-user-loaded.png"
$adminUserSavedScreenshotPath = Join-Path $outputFullPath "admin-user-saved.png"
$adminAvatarFixturePath = Join-Path $outputFullPath "admin-avatar-fixture.png"
$evidencePath = Join-Path $outputFullPath "online-surface-gui-evidence.json"
$localData = Join-Path $outputFullPath "local-data"
$editing = Join-Path $outputFullPath "editing"
$workspace = Join-Path $outputFullPath "workspace"
$clientTemp = Join-Path $outputFullPath "temp"
foreach ($directory in @($localData, $editing, $workspace, $clientTemp)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Security.Cryptography.ProtectedData
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Threading;
public static class LumaChartOnlineSurfaceCaptureNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr window, IntPtr deviceContext, uint flags);

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

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [int]$TimeoutMilliseconds = 3000
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
                        [StringComparison]::Ordinal)) {
                    return $root
                }
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

function Find-ElementByName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]
        [Windows.Automation.ControlType]$ControlType,
        [int]$TimeoutMilliseconds = 3000
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $nameCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty,
        $Name)
    $typeCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ControlTypeProperty,
        $ControlType)
    $condition = [Windows.Automation.AndCondition]::new(
        $nameCondition,
        $typeCondition)
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children,
                $processCondition)
            foreach ($root in $roots) {
                if ([string]$root.Current.Name -ceq $Name -and
                    $root.Current.ControlType -eq $ControlType) {
                    return $root
                }
                $candidate = $root.FindFirst(
                    [Windows.Automation.TreeScope]::Descendants,
                    $condition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation name '$Name' for process $ProcessId."
}

function Wait-ElementNameLike {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [int]$TimeoutMilliseconds = 10000
    )
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $element = Find-ElementById `
                -ProcessId $ProcessId `
                -AutomationId $AutomationId `
                -TimeoutMilliseconds 1000
            if ([string]$element.Current.Name -like $Pattern) {
                return $element
            }
        }
        catch { }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out waiting for '$AutomationId' name to match '$Pattern'."
}

function Bring-ElementIntoView($Element) {
    $provider = $null
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.ScrollItemPattern]::Pattern,
            [ref]$provider)) {
        $provider.ScrollIntoView()
        Start-Sleep -Milliseconds 220
    }
    if ($Element.Current.IsOffscreen) {
        throw "Element '$($Element.Current.AutomationId)' remained offscreen."
    }
}

function Observe-Element($Element) {
    $bounds = $Element.Current.BoundingRectangle
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        controlType = [string]$Element.Current.ControlType.ProgrammaticName
        helpText = [string]$Element.Current.HelpText
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

function Set-AutomationValue($Element, [string]$Value) {
    $provider = $Element.GetCurrentPattern(
        [Windows.Automation.ValuePattern]::Pattern)
    if (-not $provider) {
        throw "Element '$($Element.Current.AutomationId)' has no ValuePattern."
    }
    $provider.SetValue($Value)
    Start-Sleep -Milliseconds 120
}

function Click-ElementPhysical($Element, [IntPtr]$WindowHandle) {
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -le 1 -or $bounds.Height -le 1 -or $Element.Current.IsOffscreen) {
        throw "Element '$($Element.Current.AutomationId)' has no physical click target."
    }
    if (-not [LumaChartOnlineSurfaceCaptureNative]::TryActivateWindow(
            $WindowHandle)) {
        throw "Unable to activate window $WindowHandle before physical click."
    }
    $x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    if (-not [LumaChartOnlineSurfaceCaptureNative]::SetCursorPos($x, $y)) {
        throw "SetCursorPos failed for '$($Element.Current.AutomationId)'."
    }
    Start-Sleep -Milliseconds 75
    $actual = [LumaChartOnlineSurfaceCaptureNative+POINT]::new()
    if (-not [LumaChartOnlineSurfaceCaptureNative]::GetCursorPos([ref]$actual) -or
        [Math]::Abs($actual.X - $x) -gt 2 -or
        [Math]::Abs($actual.Y - $y) -gt 2) {
        throw "Physical cursor did not reach '$($Element.Current.AutomationId)' " +
              "at ($x,$y); actual=($($actual.X),$($actual.Y))."
    }
    if ([LumaChartOnlineSurfaceCaptureNative]::GetForegroundWindow() -ne
        $WindowHandle) {
        throw "Window $WindowHandle lost foreground before physical click."
    }
    if (-not [LumaChartOnlineSurfaceCaptureNative]::IsWindowAtPoint(
            $WindowHandle,
            $x,
            $y)) {
        throw "Element '$($Element.Current.AutomationId)' is obscured at " +
              "($x,$y)."
    }
    [LumaChartOnlineSurfaceCaptureNative]::mouse_event(
        0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 45
    [LumaChartOnlineSurfaceCaptureNative]::mouse_event(
        0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 220
}

function Invoke-PhysicalWindowActivationPreflight([IntPtr]$WindowHandle) {
    $rectangle = [LumaChartOnlineSurfaceCaptureNative+RECT]::new()
    if (-not [LumaChartOnlineSurfaceCaptureNative]::GetWindowRect(
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
    if (-not [LumaChartOnlineSurfaceCaptureNative]::SetWindowPos(
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
        [void][LumaChartOnlineSurfaceCaptureNative]::BringWindowToTop(
            $WindowHandle)
        if (-not [LumaChartOnlineSurfaceCaptureNative]::SetCursorPos($x, $y)) {
            throw "SetCursorPos failed for physical activation preflight."
        }
        Start-Sleep -Milliseconds 75
        $actual = [LumaChartOnlineSurfaceCaptureNative+POINT]::new()
        if (-not [LumaChartOnlineSurfaceCaptureNative]::GetCursorPos(
                [ref]$actual) -or
            [Math]::Abs($actual.X - $x) -gt 2 -or
            [Math]::Abs($actual.Y - $y) -gt 2 -or
            -not [LumaChartOnlineSurfaceCaptureNative]::IsWindowAtPoint(
                $WindowHandle,
                $x,
                $y)) {
            throw "Physical activation preflight did not reach the title bar."
        }
        [LumaChartOnlineSurfaceCaptureNative]::mouse_event(
            0x0002, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 45
        [LumaChartOnlineSurfaceCaptureNative]::mouse_event(
            0x0004, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 420
        if (-not [LumaChartOnlineSurfaceCaptureNative]::TryActivateWindow(
                $WindowHandle)) {
            throw "Physical activation preflight did not activate the window."
        }
    }
    finally {
        [void][LumaChartOnlineSurfaceCaptureNative]::SetWindowPos(
            $WindowHandle,
            $notTopmost,
            0,
            0,
            0,
            0,
            $noMoveNoSizeShow)
    }
}

function Invoke-ElementAutomation($Element) {
    $provider = $null
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$provider)) {
        $provider.Invoke()
    }
    elseif ($Element.TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$provider)) {
        $provider.Select()
    }
    elseif ($Element.TryGetCurrentPattern(
            [Windows.Automation.ExpandCollapsePattern]::Pattern,
            [ref]$provider)) {
        if ($provider.Current.ExpandCollapseState -eq
            [Windows.Automation.ExpandCollapseState]::Collapsed) {
            $provider.Expand()
        }
        else {
            $provider.Collapse()
        }
    }
    else {
        throw "Element '$($Element.Current.AutomationId)' has no action pattern."
    }
    Start-Sleep -Milliseconds 220
}

function Invoke-OwnerAdminAction(
    $Element,
    [IntPtr]$WindowHandle,
    [bool]$AutomationPreflight) {
    if ($AutomationPreflight) {
        Invoke-ElementAutomation $Element
    }
    else {
        Click-ElementPhysical $Element $WindowHandle
    }
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartOnlineSurfaceCaptureNative+RECT]::new()
    if (-not [LumaChartOnlineSurfaceCaptureNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 800 -or $height -lt 600) {
        throw "Main window has invalid bounds: ${width}x${height}."
    }
    $bitmap = [Drawing.Bitmap]::new(
        $width,
        $height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $dc = $graphics.GetHdc()
            try {
                if (-not [LumaChartOnlineSurfaceCaptureNative]::PrintWindow(
                        $Handle,
                        $dc,
                        2)) {
                    throw "PrintWindow failed for the Avalonia main window."
                }
            }
            finally { $graphics.ReleaseHdc($dc) }
        }
        finally { $graphics.Dispose() }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{ width = $width; height = $height }
    }
    finally { $bitmap.Dispose() }
}

function New-AvatarFixture([string]$Path) {
    $bitmap = [Drawing.Bitmap]::new(96, 96)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([Drawing.Color]::FromArgb(24, 29, 32))
            $accent = [Drawing.SolidBrush]::new(
                [Drawing.Color]::FromArgb(91, 192, 190))
            $light = [Drawing.SolidBrush]::new(
                [Drawing.Color]::FromArgb(214, 218, 220))
            try {
                $graphics.FillEllipse($accent, 18, 18, 60, 60)
                $graphics.FillRectangle($light, 40, 24, 16, 48)
                $graphics.FillRectangle($light, 24, 40, 48, 16)
            }
            finally {
                $accent.Dispose()
                $light.Dispose()
            }
        }
        finally { $graphics.Dispose() }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $bitmap.Dispose() }
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
}

function Submit-NativeAvatarPicker {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][IntPtr]$MainWindowHandle,
        [Parameter(Mandatory = $true)][bool]$AutomationPreflight
    )
    $title = "选择用户头像图片"
    $dialog = Find-ElementByName `
        -ProcessId $ProcessId `
        -Name $title `
        -ControlType ([Windows.Automation.ControlType]::Window) `
        -TimeoutMilliseconds 15000
    $dialogHandle = [IntPtr]$dialog.Current.NativeWindowHandle
    if ($dialogHandle -eq [IntPtr]::Zero) {
        throw "Native avatar picker has no window handle."
    }
    $edit = $null
    foreach ($id in @("1148", "1001")) {
        $condition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty,
            $id)
        $candidates = $dialog.FindAll(
            [Windows.Automation.TreeScope]::Descendants,
            $condition)
        for ($index = 0; $index -lt $candidates.Count; $index++) {
            $candidate = $candidates.Item($index)
            $valueProvider = $null
            if ($candidate.Current.IsEnabled -and
                $candidate.Current.ControlType -eq
                    [Windows.Automation.ControlType]::Edit -and
                $candidate.TryGetCurrentPattern(
                    [Windows.Automation.ValuePattern]::Pattern,
                    [ref]$valueProvider)) {
                $edit = $candidate
                break
            }
        }
        if ($edit) { break }
    }
    if (-not $edit) {
        throw "Native avatar picker did not expose filename edit 1148 or 1001."
    }
    Set-AutomationValue $edit $Path
    $valueProvider = $null
    if (-not $edit.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$valueProvider) -or
        ([Windows.Automation.ValuePattern]$valueProvider).Current.Value -cne
            $Path) {
        throw "Native avatar picker did not retain the exact fixture path."
    }
    $openCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        "1")
    $buttons = $dialog.FindAll(
        [Windows.Automation.TreeScope]::Descendants,
        $openCondition)
    $open = $null
    for ($index = 0; $index -lt $buttons.Count; $index++) {
        $candidate = $buttons.Item($index)
        if ($candidate.Current.IsEnabled -and
            $candidate.Current.ControlType -eq
                [Windows.Automation.ControlType]::Button) {
            $open = $candidate
            break
        }
    }
    if (-not $open) {
        throw "Native avatar picker did not expose its Open button."
    }
    $fileNameAutomationId = [string]$edit.Current.AutomationId
    $openObservation = Observe-Element $open
    if ($AutomationPreflight) {
        Invoke-ElementAutomation $open
    }
    else {
        Click-ElementPhysical $open $dialogHandle
    }
    return [ordered]@{
        title = $title
        nativeWindowHandle = [long]$dialogHandle
        fileNameAutomationId = $fileNameAutomationId
        submittedPath = $Path
        openButton = $openObservation
        submission = if ($AutomationPreflight) {
            "diagnostic ValuePattern + InvokePattern; not formal physical evidence"
        } else {
            "ValuePattern exact path + physical native Open button click"
        }
        mainWindowHandle = [long]$MainWindowHandle
    }
}

function Write-SessionToken([string]$Root, [string]$Token) {
    $plain = [Text.Encoding]::UTF8.GetBytes($Token)
    try {
        $protected = [Security.Cryptography.ProtectedData]::Protect(
            $plain,
            $null,
            [Security.Cryptography.DataProtectionScope]::CurrentUser)
        [IO.File]::WriteAllBytes(
            (Join-Path $Root "online-session.bin"),
            $protected)
    }
    finally { [Array]::Clear($plain, 0, $plain.Length) }
}

$serverStart = [Diagnostics.ProcessStartInfo]::new("dotnet")
$serverStart.UseShellExecute = $false
$serverStart.ArgumentList.Add($serverFullPath)
$serverStart.ArgumentList.Add("--ready-file")
$serverStart.ArgumentList.Add($readyPath)
$serverStart.ArgumentList.Add("--state-file")
$serverStart.ArgumentList.Add($statePath)
$serverStart.Environment["TEMP"] = $clientTemp
$serverStart.Environment["TMP"] = $clientTemp
$server = [Diagnostics.Process]::Start($serverStart)
$client = $null
try {
    Wait-File $readyPath "loopback server ready file" 30
    $ready = Get-Content -Raw -LiteralPath $readyPath | ConvertFrom-Json
    $endpoint = [string]$ready.endpoint
    if (-not $endpoint.StartsWith(
            "http://127.0.0.1:",
            [StringComparison]::Ordinal)) {
        throw "Loopback server published a non-loopback endpoint: $endpoint"
    }
    if ($RoomPasswordScenario) {
        $ownerHeaders = @{
            Authorization = "Bearer $([string]$ready.ownerToken)"
        }
        $roomCreate = Invoke-RestMethod `
            -Method Post `
            -Uri ($endpoint + "api/rooms") `
            -Headers $ownerHeaders `
            -ContentType "application/json" `
            -Body (@{
                name = "Avalonia 密码房"
                isPrivate = $true
                password = "mima"
                isHidden = $false
            } | ConvertTo-Json -Compress)
        $roomId = [string]$roomCreate.room.id
        if ([string]::IsNullOrWhiteSpace($roomId)) {
            $roomId = [string]$ready.roomId
        }
        Invoke-RestMethod `
            -Method Put `
            -Uri ($endpoint + "api/rooms/$roomId/chart") `
            -Headers $ownerHeaders `
            -ContentType "application/json" `
            -Body (@{
                keyCount = 4
                notes = @()
                timing = @()
            } | ConvertTo-Json -Depth 5 -Compress) | Out-Null
        Invoke-RestMethod `
            -Method Post `
            -Uri ($endpoint + "api/rooms/$roomId/resources/commit") `
            -Headers $ownerHeaders `
            -ContentType "application/json" `
            -Body (@{ entries = @() } | ConvertTo-Json -Compress) | Out-Null
        Write-SessionToken $localData ([string]$ready.memberToken)
    }
    else {
        Write-SessionToken $localData ([string]$ready.ownerToken)
    }

    $start = [Diagnostics.ProcessStartInfo]::new($applicationFullPath)
    $start.UseShellExecute = $false
    $start.Environment["LUMACHART_SERVER_URL"] = $endpoint
    $start.Environment["LUMACHART_PROFILE"] = "windows-avalonia-overlay-owner"
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localData
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
    $start.Environment["TEMP"] = $clientTemp
    $start.Environment["TMP"] = $clientTemp
    $client = [Diagnostics.Process]::Start($start)

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($client.MainWindowHandle -eq [IntPtr]::Zero -and
           [DateTime]::UtcNow -lt $deadline) {
        if ($client.HasExited) { throw "Avalonia exited before opening its main window." }
        $client.Refresh()
        Start-Sleep -Milliseconds 100
    }
    if ($client.MainWindowHandle -eq [IntPtr]::Zero) {
        throw "Avalonia main window was unavailable."
    }
    $handle = [IntPtr]$client.MainWindowHandle

    $account = Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "OnlineAccount.Navigation" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $identityDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $expectedIdentity = if ($RoomPasswordScenario) { "*成员*" } else { "*房主*" }
    while ([string]$account.Current.Name -notlike $expectedIdentity -and
           [DateTime]::UtcNow -lt $identityDeadline) {
        Start-Sleep -Milliseconds 150
        $account = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineAccount.Navigation" `
            -TimeoutMilliseconds 2000
    }
    if ([string]$account.Current.Name -notlike $expectedIdentity) {
        throw "The isolated DPAPI online session did not restore."
    }
    $ownerAdminPhysicalSetupClickCount = 0
    if ($OwnerAdminScenario -and -not $OwnerAdminAutomationPreflight) {
        Invoke-PhysicalWindowActivationPreflight $handle
        $ownerAdminPhysicalSetupClickCount = 1
    }
    if ($OwnerAdminScenario) {
        Invoke-OwnerAdminAction `
            $account `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)
    }
    else {
        Click-ElementPhysical $account $handle
    }

    $community = Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "OnlineCommunity.Dialog" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    if ([IntPtr]$community.Current.NativeWindowHandle -ne [IntPtr]::Zero) {
        throw "Community surface unexpectedly opened a separate native window."
    }
    $surfaceLayer = Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "Online.SurfaceLayer" `
        -TimeoutMilliseconds 3000
    $communityLayer = Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "OnlineCommunity.Layer" `
        -TimeoutMilliseconds 3000
    $profileStatus = Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "OnlineCommunity.Profile.Status" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $accountObservation = Observe-Element $account
    $surfaceObservation = Observe-Element $surfaceLayer
    $communityLayerObservation = Observe-Element $communityLayer
    $communityObservation = Observe-Element $community
    $profileStatusObservation = Observe-Element $profileStatus

    if ($OwnerAdminScenario) {
        $adminNavigation = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Navigation.Admin" `
            -TimeoutMilliseconds 5000
        Invoke-OwnerAdminAction `
            $adminNavigation `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)
        $configurationStatus = Wait-ElementNameLike `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.Configuration.Status" `
            -Pattern "*已载入*" `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $configurationLoadedObservation = Observe-Element $configurationStatus
        $configurationScreenshot = Capture-Window `
            $handle `
            $adminConfigurationScreenshotPath

        $about = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.Configuration.About"
        $latestVersion = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.Configuration.LatestVersion"
        $minimumVersion = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.Configuration.MinimumVersion"
        $updateNotice = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.Configuration.UpdateNotice"
        $downloadUrl = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.Configuration.DownloadUrl"
        Set-AutomationValue $about "Windows Avalonia owner 管理 GUI 已通过隔离验收。"
        Set-AutomationValue $latestVersion "1.1.0-admin-gui"
        Set-AutomationValue $minimumVersion "1.1.0"
        Set-AutomationValue $updateNotice "隔离 loopback：内容后台保存已验收。"
        Set-AutomationValue $downloadUrl "https://example.invalid/avalonia-admin-gui"
        $configurationSave = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.Configuration.Save"
        Bring-ElementIntoView $configurationSave
        Invoke-OwnerAdminAction `
            $configurationSave `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)
        $configurationSavedStatus = Wait-ElementNameLike `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.Configuration.Status" `
            -Pattern "*已保存*" `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $configurationSavedObservation = Observe-Element $configurationSavedStatus
        $configurationSavedScreenshot = Capture-Window `
            $handle `
            $adminConfigurationSavedScreenshotPath

        $friendsNavigation = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Navigation.Friends"
        Invoke-OwnerAdminAction `
            $friendsNavigation `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)
        $directoryStatus = Wait-ElementNameLike `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Directory.Status" `
            -Pattern "*1 名玩家*" `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $memberOpen = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Player.4202.Open" `
            -TimeoutMilliseconds 5000
        Bring-ElementIntoView $memberOpen
        Invoke-OwnerAdminAction `
            $memberOpen `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)
        $manageUser = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Player.Admin" `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        Bring-ElementIntoView $manageUser
        Invoke-OwnerAdminAction `
            $manageUser `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)
        $adminUserStatus = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.Status" `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $adminUserLoadedObservation = Observe-Element $adminUserStatus
        $adminUserScreenshot = Capture-Window $handle $adminUserScreenshotPath

        $adminAvatarFixture = New-AvatarFixture $adminAvatarFixturePath
        $uploadAvatar = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.AvatarUpload"
        Bring-ElementIntoView $uploadAvatar
        Invoke-OwnerAdminAction `
            $uploadAvatar `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)
        $nativeAvatarPicker = Submit-NativeAvatarPicker `
            -ProcessId $client.Id `
            -Path $adminAvatarFixturePath `
            -MainWindowHandle $handle `
            -AutomationPreflight ([bool]$OwnerAdminAutomationPreflight)
        $avatarUploadStatus = Wait-ElementNameLike `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.Status" `
            -Pattern "*头像已更新*" `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $avatarUploadObservation = Observe-Element $avatarUploadStatus

        $resetAvatar = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.AvatarReset"
        Bring-ElementIntoView $resetAvatar
        Invoke-OwnerAdminAction `
            $resetAvatar `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)
        $avatarResetStatus = Wait-ElementNameLike `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.Status" `
            -Pattern "*默认*" `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $avatarResetObservation = Observe-Element $avatarResetStatus

        $displayName = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.DisplayName"
        $bio = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.Bio"
        $tagName = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.TagName"
        $tagColor = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.TagColor"
        Set-AutomationValue $displayName "Avalonia 成员（管理员验收）"
        Set-AutomationValue $bio "Windows Avalonia owner 用户资料与标签 GUI 验收。"
        Set-AutomationValue $tagName "管理员验收"
        Set-AutomationValue $tagColor "#5BC0BE"
        $addTag = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.TagAdd"
        Bring-ElementIntoView $addTag
        Invoke-OwnerAdminAction `
            $addTag `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)
        $tagDraftStatus = Wait-ElementNameLike `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.Status" `
            -Pattern "*标签草稿已更新*" `
            -TimeoutMilliseconds 5000
        $tagDraftObservation = Observe-Element $tagDraftStatus

        $nameColor = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.NameColor"
        Bring-ElementIntoView $nameColor
        Invoke-OwnerAdminAction `
            $nameColor `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)
        $nameColorItem = Find-ElementByName `
            -ProcessId $client.Id `
            -Name "管理员验收" `
            -ControlType ([Windows.Automation.ControlType]::ListItem) `
            -TimeoutMilliseconds 5000
        Invoke-OwnerAdminAction `
            $nameColorItem `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)

        $saveUser = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.Save"
        Bring-ElementIntoView $saveUser
        Invoke-OwnerAdminAction `
            $saveUser `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)
        $profileSavedStatus = Wait-ElementNameLike `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.Status" `
            -Pattern "*资料与标签已保存*" `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $profileSavedObservation = Observe-Element $profileSavedStatus

        $customLabel = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.CustomLabel"
        Set-AutomationValue $customLabel "Avalonia owner GUI 验收"
        $saveLabel = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.CustomLabelSave"
        Bring-ElementIntoView $saveLabel
        Invoke-OwnerAdminAction `
            $saveLabel `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)
        $labelSavedStatus = Wait-ElementNameLike `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Admin.User.Status" `
            -Pattern "*自定义标记已保存*" `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        Bring-ElementIntoView $labelSavedStatus
        $adminUserSavedObservation = Observe-Element $labelSavedStatus
        $adminUserSavedScreenshot = Capture-Window `
            $handle `
            $adminUserSavedScreenshotPath

        $close = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Header.Close" `
            -TimeoutMilliseconds 5000
        Invoke-OwnerAdminAction `
            $close `
            $handle `
            ([bool]$OwnerAdminAutomationPreflight)
        $closeDeadline = [DateTime]::UtcNow.AddSeconds(5)
        do {
            Start-Sleep -Milliseconds 100
            $surfaceHidden = $surfaceLayer.Current.IsOffscreen
        } while (-not $surfaceHidden -and [DateTime]::UtcNow -lt $closeDeadline)
        if (-not $surfaceHidden) {
            throw "Physical header close did not return from the hosted community layer."
        }

        $serverState = Invoke-RestMethod -Uri ($endpoint + "harness/state")
        $member = @($serverState.adminUsers) |
            Where-Object { [long]$_.id -eq 4202 } |
            Select-Object -First 1
        if (-not $member) { throw "Admin member state was not recorded." }
        if ([int]$serverState.adminConfigurationUpdateCount -ne 1 -or
            [int]$serverState.adminUserReadCount -ne 1 -or
            [int]$serverState.adminUserUpdateCount -ne 1 -or
            [int]$serverState.adminUserLabelUpdateCount -ne 1 -or
            [int]$serverState.adminUserAvatarResetCount -ne 1 -or
            [int]$serverState.adminUserAvatarUploadCount -ne 1 -or
            [long]$serverState.adminUserAvatarUploadBytes -ne
                [long]$adminAvatarFixture.length) {
            throw "Owner admin request counts did not match the physical GUI actions."
        }
        if ([string]$serverState.appConfiguration.aboutContent -ne
                "Windows Avalonia owner 管理 GUI 已通过隔离验收。" -or
            [string]$serverState.appConfiguration.latestVersion -ne
                "1.1.0-admin-gui" -or
            [string]$serverState.appConfiguration.downloadUrl -ne
                "https://example.invalid/avalonia-admin-gui") {
            throw "Owner admin application configuration was not stored exactly."
        }
        $nameColorTag = @($member.tags) |
            Where-Object {
                [string]$_.name -eq "管理员验收" -and
                [string]$_.color -eq "#5BC0BE" -and
                [bool]$_.isNameColor
            } |
            Select-Object -First 1
        if ([string]$member.displayName -ne "Avalonia 成员（管理员验收）" -or
            [string]$member.bio -ne
                "Windows Avalonia owner 用户资料与标签 GUI 验收。" -or
            [string]$member.customLabel -ne "Avalonia owner GUI 验收" -or
            -not $nameColorTag) {
            throw "Owner admin user profile was not stored exactly."
        }

        $evidence = [ordered]@{
            schema = "lumachart.windows.avalonia.owner-admin-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = if ($OwnerAdminAutomationPreflight) {
                "diagnostic-preflight-not-formal"
            } else {
                "passed"
            }
            applicationPath = $applicationFullPath
            applicationSha256 = (
                Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
            applicationAssemblySha256 = (
                Get-FileHash -LiteralPath (
                    [IO.Path]::ChangeExtension($applicationFullPath, ".dll")
                ) -Algorithm SHA256).Hash
            loopbackEndpoint = $endpoint
            sessionRestored = $true
            ownerRoleObserved = $true
            diagnosticOnly = [bool]$OwnerAdminAutomationPreflight
            mouseInputUsed = -not [bool]$OwnerAdminAutomationPreflight
            automationInvokePatternUsed = [bool]$OwnerAdminAutomationPreflight
            automationValuePatternUsed = $true
            keyboardInputUsed = $false
            physicalActionCount = if ($OwnerAdminAutomationPreflight) { 0 } else { 15 }
            physicalSetupClickCount = $ownerAdminPhysicalSetupClickCount
            hostedInMainWindow = $true
            separateNativeWindowCreated = $false
            processId = [int]$client.Id
            mainWindowHandle = [long]$handle
            accountNavigation = $accountObservation
            onlineSurfaceLayerBeforeClose = $surfaceObservation
            communityLayerBeforeClose = $communityLayerObservation
            community = $communityObservation
            applicationConfiguration = [ordered]@{
                loadedStatus = $configurationLoadedObservation
                savedStatus = $configurationSavedObservation
                loadedScreenshotPath = $adminConfigurationScreenshotPath
                loadedScreenshotSha256 = (
                    Get-FileHash -LiteralPath $adminConfigurationScreenshotPath `
                        -Algorithm SHA256).Hash
                loadedScreenshot = $configurationScreenshot
                savedScreenshotPath = $adminConfigurationSavedScreenshotPath
                savedScreenshotSha256 = (
                    Get-FileHash -LiteralPath $adminConfigurationSavedScreenshotPath `
                        -Algorithm SHA256).Hash
                savedScreenshot = $configurationSavedScreenshot
            }
            userAdministration = [ordered]@{
                loadedStatus = $adminUserLoadedObservation
                avatarFixture = $adminAvatarFixture
                nativeAvatarPicker = $nativeAvatarPicker
                avatarUploadStatus = $avatarUploadObservation
                avatarResetStatus = $avatarResetObservation
                tagDraftStatus = $tagDraftObservation
                profileSavedStatus = $profileSavedObservation
                savedStatus = $adminUserSavedObservation
                loadedScreenshotPath = $adminUserScreenshotPath
                loadedScreenshotSha256 = (
                    Get-FileHash -LiteralPath $adminUserScreenshotPath `
                        -Algorithm SHA256).Hash
                loadedScreenshot = $adminUserScreenshot
                savedScreenshotPath = $adminUserSavedScreenshotPath
                savedScreenshotSha256 = (
                    Get-FileHash -LiteralPath $adminUserSavedScreenshotPath `
                        -Algorithm SHA256).Hash
                savedScreenshot = $adminUserSavedScreenshot
                avatarUploadPending = $false
            }
            close = [ordered]@{
                invokedPhysically = -not [bool]$OwnerAdminAutomationPreflight
                surfaceHidden = $surfaceHidden
            }
            server = $serverState
            migrationComplete = $false
            windowsParityComplete = $false
        }
        $evidence | ConvertTo-Json -Depth 14 |
            Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
        $evidence | ConvertTo-Json -Depth 14
        return
    }

    $profileScreenshot = Capture-Window $handle $profileScreenshotPath

    $roomsNavigation = Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "OnlineCommunity.Navigation.Rooms" `
        -TimeoutMilliseconds 5000
    Click-ElementPhysical $roomsNavigation $handle
    $roomsStatus = Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "OnlineRooms.Directory.Status" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $roomName = Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "OnlineRooms.Create.Name" `
        -TimeoutMilliseconds 5000
    $roomsStatusObservation = Observe-Element $roomsStatus
    $roomNameObservation = Observe-Element $roomName
    $roomsScreenshot = Capture-Window $handle $roomsScreenshotPath

    $roomPasswordEvidence = $null
    if ($RoomPasswordScenario) {
        $roomWatch = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineRooms.Room.$([long]$ready.roomNumber).Watch" `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $roomJoin = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineRooms.Room.$([long]$ready.roomNumber).Join" `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $roomWatchObservation = Observe-Element $roomWatch
        $roomJoinObservation = Observe-Element $roomJoin
        Click-ElementPhysical $roomWatch $handle
        $passwordLayer = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineRooms.Join.PasswordLayer" `
            -TimeoutMilliseconds 5000
        $passwordCard = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineRooms.Join.PasswordCard" `
            -TimeoutMilliseconds 5000
        $passwordBox = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineRooms.Join.Password" `
            -TimeoutMilliseconds 5000
        $passwordStatus = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineRooms.Join.Status" `
            -TimeoutMilliseconds 5000
        $passwordSubmit = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineRooms.Join.Submit" `
            -TimeoutMilliseconds 5000
        $passwordCancel = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineRooms.Join.Cancel" `
            -TimeoutMilliseconds 5000
        $directoryList = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineRooms.Directory.List" `
            -TimeoutMilliseconds 5000
        if ($passwordLayer.Current.IsOffscreen) {
            throw "Room password layer did not become visible."
        }
        if ([IntPtr]$passwordLayer.Current.NativeWindowHandle -ne [IntPtr]::Zero) {
            throw "Room password layer unexpectedly created a native window."
        }
        if ($directoryList.Current.IsOffscreen) {
            throw "Opening the room password layer removed the room directory."
        }
        $passwordLayerObservation = Observe-Element $passwordLayer
        $passwordCardObservation = Observe-Element $passwordCard
        $viewerPromptObservation = Observe-Element $passwordLayer
        Click-ElementPhysical $passwordCancel $handle
        if (-not $passwordLayer.Current.IsOffscreen) {
            throw "Physical cancel did not close the viewer password layer."
        }
        if ($directoryList.Current.IsOffscreen) {
            throw "Canceling the viewer password layer did not restore the room directory."
        }

        Click-ElementPhysical $roomJoin $handle
        if ($passwordLayer.Current.IsOffscreen) {
            throw "Editor join did not reopen the room password layer."
        }
        $editorPromptObservation = Observe-Element $passwordLayer
        if ([string]$viewerPromptObservation.helpText -notlike "MemberRole=viewer;*" -or
            [string]$editorPromptObservation.helpText -notlike "MemberRole=editor;*") {
            throw "Room password layer did not preserve the distinct viewer/editor action."
        }
        $roomPasswordScreenshot = Capture-Window $handle $roomPasswordScreenshotPath

        Set-AutomationValue $passwordBox "wrong"
        $passwordValueProvider = $passwordBox.GetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern)
        if ([string]$passwordValueProvider.Current.Value -ne "") {
            throw "Room password clear text was exposed through UI Automation."
        }
        Click-ElementPhysical $passwordSubmit $handle
        $passwordErrorDeadline = [DateTime]::UtcNow.AddSeconds(10)
        do {
            Start-Sleep -Milliseconds 100
            $passwordStatus = Find-ElementById `
                -ProcessId $client.Id `
                -AutomationId "OnlineRooms.Join.Status" `
                -TimeoutMilliseconds 1000
            $passwordError = [string]$passwordStatus.Current.Name
        } while ($passwordError -notlike "*密码错误*" -and
                 [DateTime]::UtcNow -lt $passwordErrorDeadline)
        if ($passwordError -notlike "*密码错误*") {
            throw "Wrong room password did not keep the layer open with an error."
        }
        if ($passwordLayer.Current.IsOffscreen) {
            throw "Wrong room password closed the room password layer."
        }
        $roomPasswordErrorScreenshot =
            Capture-Window $handle $roomPasswordErrorScreenshotPath

        $serverAfterWrongPassword =
            Invoke-RestMethod -Uri ($endpoint + "harness/state")
        if ([int]$serverAfterWrongPassword.memberNormalJoinRequestCount -ne 1 -or
            [int]$serverAfterWrongPassword.memberJoinPasswordSubmissionCount -ne 1) {
            throw "Wrong password action did not produce exactly one password join request."
        }
        if (@($serverAfterWrongPassword.activeMemberIds) -contains 4202) {
            throw "Wrong password unexpectedly joined the member."
        }
        Click-ElementPhysical $passwordCancel $handle
        if (-not $passwordLayer.Current.IsOffscreen) {
            throw "Physical cancel did not close the error password layer."
        }
        if ($directoryList.Current.IsOffscreen) {
            throw "Canceling the error password layer did not restore the room directory."
        }
        $roomPasswordCancelledScreenshot =
            Capture-Window $handle $roomPasswordCancelledScreenshotPath
        $close = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Header.Close" `
            -TimeoutMilliseconds 5000
        Click-ElementPhysical $close $handle
        $closeDeadline = [DateTime]::UtcNow.AddSeconds(5)
        do {
            Start-Sleep -Milliseconds 100
            $surfaceHidden = $surfaceLayer.Current.IsOffscreen
        } while (-not $surfaceHidden -and [DateTime]::UtcNow -lt $closeDeadline)
        if (-not $surfaceHidden) {
            throw "Physical header close did not return from the room password scenario."
        }
        $roomPasswordEvidence = [ordered]@{
            roomNumber = [long]$ready.roomNumber
            editorAction = $roomJoinObservation
            viewerAction = $roomWatchObservation
            layer = $passwordLayerObservation
            card = $passwordCardObservation
            viewerPrompt = $viewerPromptObservation
            editorPrompt = $editorPromptObservation
            directoryPreservedUnderLayer = $true
            separateNativeWindowCreated = $false
            clearTextExposedThroughUia = $false
            wrongPasswordError = $passwordError
            wrongPasswordKeptLayerOpen = $true
            wrongPasswordJoinRequestCount =
                [int]$serverAfterWrongPassword.memberNormalJoinRequestCount
            wrongPasswordSubmissionCount =
                [int]$serverAfterWrongPassword.memberJoinPasswordSubmissionCount
            wrongPasswordJoinedMember = $false
            viewerCancelRestoredDirectory = $true
            editorErrorCancelRestoredDirectory = $true
            overlayScreenshotPath = $roomPasswordScreenshotPath
            overlayScreenshotSha256 = (
                Get-FileHash -LiteralPath $roomPasswordScreenshotPath -Algorithm SHA256).Hash
            errorScreenshotPath = $roomPasswordErrorScreenshotPath
            errorScreenshotSha256 = (
                Get-FileHash -LiteralPath $roomPasswordErrorScreenshotPath -Algorithm SHA256).Hash
            cancelledScreenshotPath = $roomPasswordCancelledScreenshotPath
            cancelledScreenshotSha256 = (
                Get-FileHash -LiteralPath $roomPasswordCancelledScreenshotPath -Algorithm SHA256).Hash
        }
    }
    else {
        $close = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Header.Close" `
            -TimeoutMilliseconds 5000
        Click-ElementPhysical $close $handle
        $closeDeadline = [DateTime]::UtcNow.AddSeconds(5)
        do {
            Start-Sleep -Milliseconds 100
            $surfaceHidden = $surfaceLayer.Current.IsOffscreen
        } while (-not $surfaceHidden -and [DateTime]::UtcNow -lt $closeDeadline)
        if (-not $surfaceHidden) {
            throw "Physical header close did not return from the hosted community layer."
        }
    }

    $serverState = Invoke-RestMethod -Uri ($endpoint + "harness/state")
    $evidence = [ordered]@{
        schema = if ($RoomPasswordScenario) {
            "lumachart.windows.avalonia.room-password-gui-evidence.v1"
        } else {
            "lumachart.windows.avalonia.online-surface-gui-evidence.v1"
        }
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        applicationPath = $applicationFullPath
        applicationSha256 = (
            Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
        applicationAssemblySha256 = (
            Get-FileHash -LiteralPath (
                [IO.Path]::ChangeExtension($applicationFullPath, ".dll")
            ) -Algorithm SHA256).Hash
        loopbackEndpoint = $endpoint
        sessionRestored = $true
        mouseInputUsed = $true
        keyboardInputUsed = $false
        physicalActionCount = if ($RoomPasswordScenario) { 8 } else { 3 }
        hostedInMainWindow = $true
        separateNativeWindowCreated = $false
        mainWindowHandle = [long]$handle
        accountNavigation = $accountObservation
        onlineSurfaceLayerBeforeClose = $surfaceObservation
        communityLayerBeforeClose = $communityLayerObservation
        community = $communityObservation
        profile = [ordered]@{
            status = $profileStatusObservation
            screenshotPath = $profileScreenshotPath
            screenshotSha256 = (
                Get-FileHash -LiteralPath $profileScreenshotPath -Algorithm SHA256).Hash
            screenshot = $profileScreenshot
        }
        rooms = [ordered]@{
            status = $roomsStatusObservation
            createName = $roomNameObservation
            screenshotPath = $roomsScreenshotPath
            screenshotSha256 = (
                Get-FileHash -LiteralPath $roomsScreenshotPath -Algorithm SHA256).Hash
            screenshot = $roomsScreenshot
        }
        roomPassword = $roomPasswordEvidence
        close = [ordered]@{
            invokedPhysically = $true
            surfaceHidden = $surfaceHidden
        }
        server = $serverState
    }
    $evidence | ConvertTo-Json -Depth 14 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    $evidence | ConvertTo-Json -Depth 14
}
finally {
    if ($client) {
        try {
            if (-not $client.HasExited) {
                $client.CloseMainWindow() | Out-Null
                if (-not $client.WaitForExit(5000)) {
                    $client.Kill($true)
                    $client.WaitForExit(5000) | Out-Null
                }
            }
        }
        catch { }
        $client.Dispose()
    }
    if ($server) {
        try {
            if (-not $server.HasExited) {
                $server.Kill($true)
                $server.WaitForExit(5000) | Out-Null
            }
        }
        catch { }
        $server.Dispose()
    }
}
