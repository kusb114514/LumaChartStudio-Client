param(
    [string]$ApplicationPath = (
        Join-Path $PSScriptRoot `
            "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$MultiDifficultyFixtureDirectory =
        "D:\osu!\Songs\_temp_1752534919",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 120)][int]$TimeoutSeconds = 60,
    [switch]$AllowForegroundAutomation
)

$ErrorActionPreference = "Stop"
if (-not $AllowForegroundAutomation) {
    throw "Pass -AllowForegroundAutomation only after the user gives current-turn desktop consent."
}
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia library launcher GUI capture requires PowerShell Core on Windows."
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartLibraryLauncherNative
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
    public static extern bool PrintWindow(
        IntPtr window,
        IntPtr deviceContext,
        uint flags);

    [DllImport("user32.dll")]
    public static extern bool IsWindowEnabled(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr window, int command);

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
            System.Threading.Thread.Sleep(75);
        }
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

function Get-Fingerprint([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        bytes = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        lastWriteUtcTicks = [long]$item.LastWriteTimeUtc.Ticks
    }
}

function Get-McSummary([string]$Path) {
    $document = Get-Content -LiteralPath $Path -Raw |
        ConvertFrom-Json -Depth 100
    return [ordered]@{
        path = [IO.Path]::GetFullPath($Path)
        title = [string]$document.meta.song.title
        version = [string]$document.meta.version
        column = [int]$document.meta.mode_ext.column
        playableNoteCount = @(
            $document.note |
                Where-Object { $null -eq $_.type -or [int]$_.type -ne 1 }).Count
        timingCount = @($document.time).Count
    }
}

function Find-VisibleElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 120000)][int]$TimeoutMilliseconds = 10000
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
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children,
                $processCondition)
            foreach ($root in $roots) {
                $matches = $root.FindAll(
                    [Windows.Automation.TreeScope]::Descendants,
                    $idCondition)
                foreach ($match in $matches) {
                    $bounds = $match.Current.BoundingRectangle
                    if (-not $match.Current.IsOffscreen -and
                        $bounds.Width -gt 0 -and
                        $bounds.Height -gt 0) {
                        return $match
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

function Find-VisibleProcessWindowByName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $nameCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty,
        $Name)
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children,
                $processCondition)
            $bestMatch = $null
            $bestScore = [int]::MinValue
            foreach ($root in $roots) {
                $candidates =
                    [System.Collections.Generic.List[
                        Windows.Automation.AutomationElement]]::new()
                if ([string]$root.Current.Name -ceq $Name) {
                    $candidates.Add($root)
                }
                $descendants = $root.FindAll(
                    [Windows.Automation.TreeScope]::Descendants,
                    $nameCondition)
                foreach ($descendant in $descendants) {
                    $candidates.Add($descendant)
                }
                foreach ($candidate in $candidates) {
                    $bounds = $candidate.Current.BoundingRectangle
                    $nativeHandle = [long]$candidate.Current.NativeWindowHandle
                    if ($candidate.Current.IsOffscreen -or
                        $bounds.Width -le 0 -or
                        $bounds.Height -le 0 -or
                        $nativeHandle -eq 0) {
                        continue
                    }
                    $score = 0
                    if ($candidate.Current.ControlType -eq
                        [Windows.Automation.ControlType]::Window) {
                        $score += 100
                    }
                    if ([string]$candidate.Current.ClassName -ceq "#32770") {
                        $score += 50
                    }
                    if ($candidate -eq $root) {
                        $score += 10
                    }
                    if ($score -gt $bestScore) {
                        $bestMatch = $candidate
                        $bestScore = $score
                    }
                }
            }
            if ($null -ne $bestMatch) {
                return $bestMatch
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding process window '$Name' for process $ProcessId."
}

function Find-FolderDialogConfirmButton {
    param(
        [Parameter(Mandatory = $true)]
        [Windows.Automation.AutomationElement]$Dialog
    )
    $buttonCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ControlTypeProperty,
        [Windows.Automation.ControlType]::Button)
    $buttons = $Dialog.FindAll(
        [Windows.Automation.TreeScope]::Descendants,
        $buttonCondition)
    $preferredNames = @(
        "选择文件夹",
        "选择此文件夹",
        "选择",
        "确定",
        "Select Folder",
        "Select"
    )
    foreach ($preferredName in $preferredNames) {
        foreach ($button in $buttons) {
            if ([string]$button.Current.Name -ceq $preferredName -and
                [bool]$button.Current.IsEnabled -and
                -not $button.Current.IsOffscreen) {
                return $button
            }
        }
    }
    $names = @($buttons | ForEach-Object { [string]$_.Current.Name }) -join " | "
    throw "Folder picker confirm button was not found. Buttons: $names"
}

function Find-FolderDialogCancelButton {
    param(
        [Parameter(Mandatory = $true)]
        [Windows.Automation.AutomationElement]$Dialog
    )
    $buttonCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ControlTypeProperty,
        [Windows.Automation.ControlType]::Button)
    $buttons = $Dialog.FindAll(
        [Windows.Automation.TreeScope]::Descendants,
        $buttonCondition)
    foreach ($preferredName in @("取消", "Cancel")) {
        foreach ($button in $buttons) {
            if ([string]$button.Current.Name -ceq $preferredName -and
                [bool]$button.Current.IsEnabled -and
                -not $button.Current.IsOffscreen) {
                return $button
            }
        }
    }
    $names = @($buttons | ForEach-Object { [string]$_.Current.Name }) -join " | "
    throw "Folder picker cancel button was not found. Buttons: $names"
}

function Find-VisibleDescendantByName {
    param(
        [Parameter(Mandatory = $true)]
        [Windows.Automation.AutomationElement]$Root,
        [Parameter(Mandatory = $true)][string]$Name,
        [Windows.Automation.ControlType]$ControlType = $null
    )
    $normalizedName = $Name.Replace("`r`n", "`n")
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        try {
            $matches = $Root.FindAll(
                [Windows.Automation.TreeScope]::Descendants,
                [Windows.Automation.Condition]::TrueCondition)
            foreach ($match in $matches) {
                $bounds = $match.Current.BoundingRectangle
                $candidateName =
                    ([string]$match.Current.Name).Replace("`r`n", "`n")
                if ($candidateName -ceq $normalizedName -and
                    ($null -eq $ControlType -or
                        $match.Current.ControlType -eq $ControlType) -and
                    -not $match.Current.IsOffscreen -and
                    $bounds.Width -gt 0 -and
                    $bounds.Height -gt 0) {
                    return $match
                }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding visible descendant '$Name'."
}

function Find-VisibleDescendantByNamePrefix {
    param(
        [Parameter(Mandatory = $true)]$Root,
        [Parameter(Mandatory = $true)][string]$Prefix
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        try {
            $elements = $Root.FindAll(
                [Windows.Automation.TreeScope]::Descendants,
                [Windows.Automation.Condition]::TrueCondition)
            foreach ($element in $elements) {
                $name = [string]$element.Current.Name
                if (-not $element.Current.IsOffscreen -and
                    $name.StartsWith(
                        $Prefix,
                        [StringComparison]::Ordinal)) {
                    return $element
                }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Visible descendant starting with '$Prefix' was not found."
}

function Get-VisibleElementCountById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $count = 0
    $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
        [Windows.Automation.TreeScope]::Children,
        $processCondition)
    foreach ($root in $roots) {
        foreach ($element in $root.FindAll(
                [Windows.Automation.TreeScope]::Descendants,
                $idCondition)) {
            if (-not $element.Current.IsOffscreen) { $count++ }
        }
    }
    return $count
}

function Find-MessageBoxConfirmButton {
    param(
        [Parameter(Mandatory = $true)]
        [Windows.Automation.AutomationElement]$Dialog
    )
    foreach ($name in @("确定", "OK")) {
        try {
            return Find-VisibleDescendantByName `
                -Root $Dialog `
                -Name $name `
                -ControlType ([Windows.Automation.ControlType]::Button)
        }
        catch { }
    }
    throw "Native MessageBox confirmation button was not found."
}

function Observe-Element(
    [Windows.Automation.AutomationElement]$Element) {
    $bounds = $Element.Current.BoundingRectangle
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        className = [string]$Element.Current.ClassName
        controlType = [string]$Element.Current.ControlType.ProgrammaticName
        nativeWindowHandle = [long]$Element.Current.NativeWindowHandle
        isEnabled = [bool]$Element.Current.IsEnabled
        isOffscreen = [bool]$Element.Current.IsOffscreen
        bounds = [ordered]@{
            left = [double]$bounds.Left
            top = [double]$bounds.Top
            width = [double]$bounds.Width
            height = [double]$bounds.Height
        }
    }
}

function Invoke-UiaElement {
    param(
        [Parameter(Mandatory = $true)]
        [Windows.Automation.AutomationElement]$Element
    )
    Assert ([bool]$Element.Current.IsEnabled) (
        "Element '$($Element.Current.AutomationId)' is disabled.")
    Assert (-not $Element.Current.IsOffscreen) (
        "Element '$($Element.Current.AutomationId)' is offscreen.")
    $automationId = [string]$Element.Current.AutomationId
    $name = [string]$Element.Current.Name
    $pattern = $Element.GetCurrentPattern(
        [Windows.Automation.InvokePattern]::Pattern)
    Assert ($null -ne $pattern) (
        "Element '$($Element.Current.AutomationId)' has no InvokePattern.")
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
    return [ordered]@{
        automationId = $automationId
        name = $name
        input = "UI Automation InvokePattern"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Get-UiaValue {
    param(
        [Parameter(Mandatory = $true)]
        [Windows.Automation.AutomationElement]$Element
    )
    $pattern = $Element.GetCurrentPattern(
        [Windows.Automation.ValuePattern]::Pattern)
    Assert ($null -ne $pattern) (
        "Element '$($Element.Current.AutomationId)' has no ValuePattern.")
    return [string]([Windows.Automation.ValuePattern]$pattern).Current.Value
}

function Set-UiaValue {
    param(
        [Parameter(Mandatory = $true)]
        [Windows.Automation.AutomationElement]$Element,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value
    )
    Assert ([bool]$Element.Current.IsEnabled) (
        "Element '$($Element.Current.AutomationId)' is disabled.")
    Assert (-not $Element.Current.IsOffscreen) (
        "Element '$($Element.Current.AutomationId)' is offscreen.")
    $automationId = [string]$Element.Current.AutomationId
    $name = [string]$Element.Current.Name
    $pattern = $Element.GetCurrentPattern(
        [Windows.Automation.ValuePattern]::Pattern)
    Assert ($null -ne $pattern) (
        "Element '$automationId' has no ValuePattern.")
    Assert (
        -not ([Windows.Automation.ValuePattern]$pattern).Current.IsReadOnly) (
        "Element '$automationId' ValuePattern is read-only.")
    ([Windows.Automation.ValuePattern]$pattern).SetValue($Value)
    Wait-Condition -Description "$automationId value '$Value'" -Condition {
        (Get-UiaValue $Element) -ceq $Value
    }
    return [ordered]@{
        automationId = $automationId
        name = $name
        value = $Value
        input = "UI Automation ValuePattern.SetValue"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Prepare-NonTopmostWindow {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$WindowHandle,
        [Parameter(Mandatory = $true)][string]$ScenarioName
    )
    $rectangle = [LumaChartLibraryLauncherNative+RECT]::new()
    Assert (
        [LumaChartLibraryLauncherNative]::GetWindowRect(
            $WindowHandle,
            [ref]$rectangle)) (
        "Unable to read '$ScenarioName' window before activation.")
    $notTopmost = [IntPtr](-2)
    $noMoveNoSizeShow = [uint32](0x0001 -bor 0x0002 -bor 0x0040)
    Assert (
        [LumaChartLibraryLauncherNative]::SetWindowPos(
            $WindowHandle,
            $notTopmost,
            0,
            0,
            0,
            0,
            $noMoveNoSizeShow)) (
        "Unable to clear topmost state for '$ScenarioName'.")
    [void][LumaChartLibraryLauncherNative]::BringWindowToTop($WindowHandle)
    [void][LumaChartLibraryLauncherNative]::SetForegroundWindow($WindowHandle)
    Start-Sleep -Milliseconds 250
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($WindowHandle)) (
        "'$ScenarioName' became topmost during activation.")
    return [ordered]@{
        scenario = $ScenarioName
        input = "non-topmost show/foreground setup without input injection"
        behaviorAction = $false
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Capture-PhysicalWindow([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartLibraryLauncherNative+RECT]::new()
    Assert (
        [LumaChartLibraryLauncherNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) "GetWindowRect failed."
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    Assert ($width -gt 0 -and $height -gt 0) "Window rectangle is empty."
    $bitmap = [Drawing.Bitmap]::new(
        $width,
        $height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $deviceContext = $graphics.GetHdc()
            try {
                Assert (
                    [LumaChartLibraryLauncherNative]::PrintWindow(
                        $Handle,
                        $deviceContext,
                        2)) "PrintWindow(PW_RENDERFULLCONTENT) failed."
            }
            finally {
                $graphics.ReleaseHdc($deviceContext)
            }
        }
        finally {
            $graphics.Dispose()
        }
        $colors = [Collections.Generic.HashSet[int]]::new()
        $luminance = [Collections.Generic.List[double]]::new()
        for ($sampleY = 0; $sampleY -lt 16; $sampleY++) {
            $pixelY = [Math]::Min(
                $height - 1,
                [int](($sampleY + 0.5) * $height / 16))
            for ($sampleX = 0; $sampleX -lt 16; $sampleX++) {
                $pixelX = [Math]::Min(
                    $width - 1,
                    [int](($sampleX + 0.5) * $width / 16))
                $pixel = $bitmap.GetPixel($pixelX, $pixelY)
                [void]$colors.Add($pixel.ToArgb())
                $luminance.Add(
                    0.2126 * $pixel.R +
                    0.7152 * $pixel.G +
                    0.0722 * $pixel.B)
            }
        }
        $mean = ($luminance | Measure-Object -Average).Average
        $variance = ($luminance | ForEach-Object {
            $difference = $_ - $mean
            $difference * $difference
        } | Measure-Object -Average).Average
        $standardDeviation = [Math]::Sqrt([double]$variance)
        Assert (
            $colors.Count -ge 8 -and
            $standardDeviation -ge 1.0) (
            "Target-window capture is near-uniform: " +
            "colors=$($colors.Count); stdDev=$standardDeviation.")
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
    $fingerprint = Get-Fingerprint $Path
    $fingerprint["captureMethod"] = "Win32 PrintWindow(PW_RENDERFULLCONTENT)"
    $fingerprint["width"] = $width
    $fingerprint["height"] = $height
    $fingerprint["sampledUniqueColors"] = $colors.Count
    $fingerprint["sampledLuminanceStdDev"] = $standardDeviation
    return $fingerprint
}

function Start-LauncherScenario {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ScenarioRoot,
        [Parameter(Mandatory = $true)][string]$PickerStartDirectory,
        [string]$LocalDataRoot = "",
        [string]$EditingRoot = "",
        [switch]$OmitWorkspaceOverride,
        [switch]$UsePersistedWorkspaceEvidence,
        [string]$ExpectedElementAutomationId = "Library.EmptyTitle"
    )
    $localData = if ([string]::IsNullOrWhiteSpace($LocalDataRoot)) {
        Join-Path $ScenarioRoot "local-data"
    }
    else {
        [IO.Path]::GetFullPath($LocalDataRoot)
    }
    $editing = if ([string]::IsNullOrWhiteSpace($EditingRoot)) {
        Join-Path $ScenarioRoot "editing"
    }
    else {
        [IO.Path]::GetFullPath($EditingRoot)
    }
    $workspace = Join-Path $ScenarioRoot "initial-workspace"
    $temp = Join-Path $ScenarioRoot "temp"
    foreach ($directory in @($localData, $editing, $workspace, $temp)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $application
    $start.WorkingDirectory = Split-Path -Parent $application
    $start.UseShellExecute = $false
    foreach ($argument in @(
            "--evidence-focus-library-launcher",
            "--evidence-file-picker-start-directory",
            $PickerStartDirectory)) {
        $start.ArgumentList.Add($argument)
    }
    if ($UsePersistedWorkspaceEvidence) {
        $start.ArgumentList.Add(
            "--evidence-use-persisted-workspace-root")
    }
    $start.Environment["LUMACHART_PROFILE"] =
        "windows-avalonia-library-launcher-$Name-$([Guid]::NewGuid().ToString('N'))"
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localData
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
    if (-not $OmitWorkspaceOverride) {
        $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
    }
    $start.Environment["DOTNET_CLI_HOME"] =
        Join-Path $projectRoot ".codex-dotnet-home"
    $start.Environment["NUGET_PACKAGES"] =
        Join-Path $projectRoot ".codex-nuget-packages"
    $start.Environment["NUGET_HTTP_CACHE_PATH"] =
        Join-Path $projectRoot ".codex-nuget-http-cache"
    $start.Environment["TEMP"] = $temp
    $start.Environment["TMP"] = $temp
    $process = [Diagnostics.Process]::Start($start)
    Assert ($null -ne $process) "Failed to start launcher scenario '$Name'."
    Wait-Condition -Description "$Name main window" -Condition {
        $process.Refresh()
        -not $process.HasExited -and
            $process.MainWindowHandle -ne [IntPtr]::Zero
    }
    $handle = $process.MainWindowHandle
    [void][LumaChartLibraryLauncherNative]::ShowWindow($handle, 3)
    $script:setupActions.Add(
        (Prepare-NonTopmostWindow $handle $Name))
    $readyElement = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId $ExpectedElementAutomationId
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($handle)) (
        "$Name main window is unexpectedly topmost.")
    return [ordered]@{
        name = $Name
        process = $process
        handle = $handle
        localData = $localData
        editing = $editing
        initialWorkspace = $workspace
        readyElement = $readyElement
        topmostAtStart = $false
    }
}

function Stop-LauncherScenario([Collections.IDictionary]$Scenario) {
    $process = $Scenario.process
    if ($null -eq $process) { return 0 }
    $process.Refresh()
    if (-not $process.HasExited) {
        [void]$process.CloseMainWindow()
        if (-not $process.WaitForExit(10000)) {
            Stop-Process -Id $process.Id -Force
            [void]$process.WaitForExit(10000)
        }
    }
    return [int]$process.ExitCode
}

function Invoke-ProjectDirectoryValidationScenario {
    param(
        [Parameter(Mandatory = $true)][string]$ScenarioName,
        [Parameter(Mandatory = $true)][string]$ScenarioRoot,
        [Parameter(Mandatory = $true)][string]$TargetDirectory,
        [Parameter(Mandatory = $true)][string]$ExpectedMessage,
        [Parameter(Mandatory = $true)][string]$ExpectedStatus,
        [Parameter(Mandatory = $true)][int]$ExpectedChartCount,
        [Parameter(Mandatory = $true)][string]$ScreenshotFileName
    )
    $scenario = $null
    try {
        $scenario = Start-LauncherScenario `
            -Name $ScenarioName `
            -ScenarioRoot $ScenarioRoot `
            -PickerStartDirectory $TargetDirectory
        $process = $scenario.process
        $handle = [IntPtr]$scenario.handle
        $openButton = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Library.OpenProject"
        $openButtonObservation = Observe-Element $openButton
        $actions.Add((Invoke-UiaElement $openButton))
        $picker = Find-VisibleProcessWindowByName `
            -ProcessId $process.Id `
            -Name "选择具体谱面目录"
        $pickerHandle = [IntPtr]$picker.Current.NativeWindowHandle
        Assert ($pickerHandle -ne [IntPtr]::Zero) (
            "$ScenarioName folder picker has no HWND.")
        Assert (
            -not [LumaChartLibraryLauncherNative]::IsWindowEnabled($handle)) (
            "$ScenarioName folder picker did not disable its owner.")
        Assert (
            -not [LumaChartLibraryLauncherNative]::IsTopmost($handle) -and
            -not [LumaChartLibraryLauncherNative]::IsTopmost($pickerHandle)) (
            "$ScenarioName owner or folder picker is unexpectedly topmost.")
        $pickerConfirm = Find-FolderDialogConfirmButton $picker
        $pickerObservation = Observe-Element $picker
        $pickerConfirmObservation = Observe-Element $pickerConfirm
        $actions.Add((Invoke-UiaElement $pickerConfirm))

        $notice = Find-VisibleProcessWindowByName `
            -ProcessId $process.Id `
            -Name "打开项目"
        $noticeHandle = [IntPtr]$notice.Current.NativeWindowHandle
        Assert ($noticeHandle -ne [IntPtr]::Zero) (
            "$ScenarioName notice has no HWND.")
        Assert (
            -not [LumaChartLibraryLauncherNative]::IsWindowEnabled($handle)) (
            "$ScenarioName notice did not disable its owner.")
        Assert (
            -not [LumaChartLibraryLauncherNative]::IsTopmost($handle) -and
            -not [LumaChartLibraryLauncherNative]::IsTopmost($noticeHandle)) (
            "$ScenarioName owner or notice is unexpectedly topmost.")
        $noticeMessage = Find-VisibleDescendantByName `
            -Root $notice `
            -Name $ExpectedMessage
        $noticeConfirm = Find-MessageBoxConfirmButton $notice
        $noticeObservation = Observe-Element $notice
        $noticeMessageObservation = Observe-Element $noticeMessage
        $noticeConfirmObservation = Observe-Element $noticeConfirm
        $noticeScreenshot = Capture-PhysicalWindow `
            $noticeHandle `
            (Join-Path $screenshots $ScreenshotFileName)
        $actions.Add((Invoke-UiaElement $noticeConfirm))
        Wait-Condition -Description "$ScenarioName owner re-enabled" -Condition {
            [LumaChartLibraryLauncherNative]::IsWindowEnabled($handle)
        }
        $status = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Library.Status"
        Wait-Condition -Description "$ScenarioName failure status" -Condition {
            [string]$status.Current.Name -ceq $ExpectedStatus
        }
        $openButtonAfter = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "Library.OpenProject"
        Assert ([bool]$openButtonAfter.Current.IsEnabled) (
            "$ScenarioName launcher did not recover after notice close.")

        $scenarioResults.Add([ordered]@{
            scenario = $ScenarioName
            launcher = $openButtonObservation
            picker = [ordered]@{
                window = $pickerObservation
                confirm = $pickerConfirmObservation
                ownerDisabled = $true
                selectedDirectory = $TargetDirectory
            }
            notice = [ordered]@{
                window = $noticeObservation
                message = $noticeMessageObservation
                confirm = $noticeConfirmObservation
                ownerDisabled = $true
                ownerEnabledAfterClose = $true
                expectedChartCount = $ExpectedChartCount
            }
            result = [ordered]@{
                status = Observe-Element $status
                launcherRecovered = Observe-Element $openButtonAfter
                noEditorOpened = @(
                    try {
                        Find-VisibleElementById `
                            -ProcessId $process.Id `
                            -AutomationId "Timeline.Surface" `
                            -TimeoutMilliseconds 250
                    }
                    catch { }
                ).Count -eq 0
            }
            screenshots = @($noticeScreenshot)
            topmostAtEnd =
                [LumaChartLibraryLauncherNative]::IsTopmost($handle)
        })
        $exitCode = Stop-LauncherScenario $scenario
        Assert ($exitCode -eq 0) (
            "$ScenarioName exited with $exitCode.")
        $scenario = $null
    }
    finally {
        if ($null -ne $scenario) {
            try { [void](Stop-LauncherScenario $scenario) } catch { }
        }
    }
}

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$application = Resolve-ExistingFile $ApplicationPath "Windows Avalonia application"
$chartFixture = Resolve-ExistingFile $ChartFixturePath "real MC fixture"
$multiDifficultyFixture = [IO.Path]::GetFullPath(
    $MultiDifficultyFixtureDirectory)
Assert (
    [IO.Directory]::Exists($multiDifficultyFixture)) (
    "Real multi-difficulty fixture directory is missing: " +
    $multiDifficultyFixture)
$multiDifficultySourceCharts = @(
    Get-ChildItem -LiteralPath $multiDifficultyFixture -File |
        Where-Object {
            [string]$_.Extension -ceq ".mc"
        } |
        Sort-Object Name)
Assert (
    $multiDifficultySourceCharts.Count -eq 2) (
    "Expected exactly two real MC difficulties in " +
    "$multiDifficultyFixture; actual=$($multiDifficultySourceCharts.Count).")
$multiDifficultySourceBefore = @(
    $multiDifficultySourceCharts |
        ForEach-Object { Get-Fingerprint $_.FullName })
$output = Resolve-NewDirectory $OutputRoot
$scratch = Join-Path $output "scratch"
$screenshots = Join-Path $output "screenshots"
[IO.Directory]::CreateDirectory($scratch) | Out-Null
[IO.Directory]::CreateDirectory($screenshots) | Out-Null
$fixtureBefore = Get-Fingerprint $chartFixture
$installer = Resolve-ExistingFile (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe") "frozen installer"
$installerBefore = Get-Fingerprint $installer
$actions = [Collections.Generic.List[object]]::new()
$script:setupActions = [Collections.Generic.List[object]]::new()
$scenarioResults = [Collections.Generic.List[object]]::new()
$activeScenario = $null
$permissionAclBefore = $null
$permissionAclApplied = $false
$permissionTarget = $null

try {
    $createRoot = Join-Path $scratch "create"
    [IO.Directory]::CreateDirectory($createRoot) | Out-Null
    $activeScenario = Start-LauncherScenario `
        -Name "create" `
        -ScenarioRoot $createRoot `
        -PickerStartDirectory (Join-Path $createRoot "initial-workspace")
    $createProcess = $activeScenario.process
    $createHandle = [IntPtr]$activeScenario.handle
    $createButton = Find-VisibleElementById `
        -ProcessId $createProcess.Id `
        -AutomationId "Library.CreateProject"
    $createButtonObservation = Observe-Element $createButton
    $emptyScreenshot = Capture-PhysicalWindow `
        $createHandle `
        (Join-Path $screenshots "01-empty-library-launcher.png")
    $actions.Add((Invoke-UiaElement $createButton))
    $timeline = Find-VisibleElementById `
        -ProcessId $createProcess.Id `
        -AutomationId "Timeline.Surface"
    $createStatus = Find-VisibleElementById `
        -ProcessId $createProcess.Id `
        -AutomationId "Editor.Status"
    Wait-Condition -Description "created MC source" -Condition {
        @(Get-ChildItem `
            -LiteralPath $activeScenario.initialWorkspace `
            -Recurse `
            -File `
            -Filter *.mc).Count -eq 1
    }
    $createdSource = @(
        Get-ChildItem `
            -LiteralPath $activeScenario.initialWorkspace `
            -Recurse `
            -File `
            -Filter *.mc)[0]
    $createdScreenshot = Capture-PhysicalWindow `
        $createHandle `
        (Join-Path $screenshots "02-create-project-editor.png")
    $scenarioResults.Add([ordered]@{
        scenario = "create-project"
        launcher = $createButtonObservation
        result = [ordered]@{
            timeline = Observe-Element $timeline
            status = Observe-Element $createStatus
            createdSource = Get-Fingerprint $createdSource.FullName
            sourceInsideInitialWorkspace =
                $createdSource.FullName.StartsWith(
                    $activeScenario.initialWorkspace + [IO.Path]::DirectorySeparatorChar,
                    [StringComparison]::OrdinalIgnoreCase)
        }
        screenshots = @($emptyScreenshot, $createdScreenshot)
        topmostAtEnd =
            [LumaChartLibraryLauncherNative]::IsTopmost($createHandle)
    })
    $createExitCode = Stop-LauncherScenario $activeScenario
    Assert ($createExitCode -eq 0) "Create scenario exited with $createExitCode."
    $activeScenario = $null

    $openRoot = Join-Path $scratch "open"
    $openTarget = Join-Path $openRoot "SelectedSong"
    [IO.Directory]::CreateDirectory($openTarget) | Out-Null
    $isolatedChart = Join-Path $openTarget "real-resound.mc"
    Copy-Item -LiteralPath $chartFixture -Destination $isolatedChart
    $isolatedChartBefore = Get-Fingerprint $isolatedChart
    $activeScenario = Start-LauncherScenario `
        -Name "open" `
        -ScenarioRoot $openRoot `
        -PickerStartDirectory $openTarget
    $openProcess = $activeScenario.process
    $openHandle = [IntPtr]$activeScenario.handle
    $openButton = Find-VisibleElementById `
        -ProcessId $openProcess.Id `
        -AutomationId "Library.OpenProject"
    $openButtonObservation = Observe-Element $openButton
    $actions.Add((Invoke-UiaElement $openButton))
    $openDialog = Find-VisibleProcessWindowByName `
        -ProcessId $openProcess.Id `
        -Name "选择具体谱面目录"
    $openDialogHandle = [IntPtr]$openDialog.Current.NativeWindowHandle
    Assert ($openDialogHandle -ne [IntPtr]::Zero) "Open-project folder dialog has no HWND."
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsWindowEnabled($openHandle)) (
        "Open-project folder dialog did not disable its owner.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($openHandle) -and
        -not [LumaChartLibraryLauncherNative]::IsTopmost($openDialogHandle)) (
        "Open-project owner or folder dialog is unexpectedly topmost.")
    $openDialogScreenshot = Capture-PhysicalWindow `
        $openDialogHandle `
        (Join-Path $screenshots "03-open-project-native-folder-picker.png")
    $openConfirm = Find-FolderDialogConfirmButton $openDialog
    $openDialogObservation = Observe-Element $openDialog
    $openConfirmObservation = Observe-Element $openConfirm
    $actions.Add((Invoke-UiaElement $openConfirm))
    $openTimeline = Find-VisibleElementById `
        -ProcessId $openProcess.Id `
        -AutomationId "Timeline.Surface"
    $openTab = Find-VisibleElementById `
        -ProcessId $openProcess.Id `
        -AutomationId "Editor.ChartTab"
    $openStatus = Find-VisibleElementById `
        -ProcessId $openProcess.Id `
        -AutomationId "Editor.Status"
    $openEditorScreenshot = Capture-PhysicalWindow `
        $openHandle `
        (Join-Path $screenshots "04-open-project-editor.png")
    $isolatedChartAfter = Get-Fingerprint $isolatedChart
    Assert (
        $isolatedChartAfter.sha256 -ceq $isolatedChartBefore.sha256 -and
        $isolatedChartAfter.bytes -eq $isolatedChartBefore.bytes) (
        "Open-project scenario modified the selected real MC.")
    $scenarioResults.Add([ordered]@{
        scenario = "open-project"
        launcher = $openButtonObservation
        picker = [ordered]@{
            window = $openDialogObservation
            confirm = $openConfirmObservation
            ownerDisabled = $true
            selectedDirectory = $openTarget
        }
        result = [ordered]@{
            timeline = Observe-Element $openTimeline
            tab = Observe-Element $openTab
            status = Observe-Element $openStatus
            selectedChartBefore = $isolatedChartBefore
            selectedChartAfter = $isolatedChartAfter
        }
        screenshots = @($openDialogScreenshot, $openEditorScreenshot)
        topmostAtEnd =
            [LumaChartLibraryLauncherNative]::IsTopmost($openHandle)
    })
    $openExitCode = Stop-LauncherScenario $activeScenario
    Assert ($openExitCode -eq 0) "Open scenario exited with $openExitCode."
    $activeScenario = $null

    $workspaceRoot = Join-Path $scratch "workspace"
    $workspaceTarget = Join-Path $workspaceRoot "Custom Workspace 中文"
    [IO.Directory]::CreateDirectory($workspaceTarget) | Out-Null
    $activeScenario = Start-LauncherScenario `
        -Name "workspace" `
        -ScenarioRoot $workspaceRoot `
        -PickerStartDirectory $workspaceTarget
    $workspaceProcess = $activeScenario.process
    $workspaceHandle = [IntPtr]$activeScenario.handle
    $chooseButton = Find-VisibleElementById `
        -ProcessId $workspaceProcess.Id `
        -AutomationId "Library.EmptyChooseWorkspace"
    $chooseButtonObservation = Observe-Element $chooseButton
    $actions.Add((Invoke-UiaElement $chooseButton))
    $workspaceDialog = Find-VisibleProcessWindowByName `
        -ProcessId $workspaceProcess.Id `
        -Name "选择 LumaChart 工作目录或 Malody chart 目录"
    $workspaceDialogHandle = [IntPtr]$workspaceDialog.Current.NativeWindowHandle
    Assert ($workspaceDialogHandle -ne [IntPtr]::Zero) "Workspace folder dialog has no HWND."
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsWindowEnabled($workspaceHandle)) (
        "Workspace folder dialog did not disable its owner.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($workspaceHandle) -and
        -not [LumaChartLibraryLauncherNative]::IsTopmost($workspaceDialogHandle)) (
        "Workspace owner or folder dialog is unexpectedly topmost.")
    $workspaceDialogScreenshot = Capture-PhysicalWindow `
        $workspaceDialogHandle `
        (Join-Path $screenshots "05-choose-workspace-native-folder-picker.png")
    $workspaceConfirm = Find-FolderDialogConfirmButton $workspaceDialog
    $workspaceDialogObservation = Observe-Element $workspaceDialog
    $workspaceConfirmObservation = Observe-Element $workspaceConfirm
    $actions.Add((Invoke-UiaElement $workspaceConfirm))
    $workspacePath = Find-VisibleElementById `
        -ProcessId $workspaceProcess.Id `
        -AutomationId "Library.WorkspacePath"
    Wait-Condition -Description "custom workspace path UI" -Condition {
        [string]$workspacePath.Current.Name -ceq "工作目录  $workspaceTarget"
    }
    $workspaceEmptyTitle = Find-VisibleElementById `
        -ProcessId $workspaceProcess.Id `
        -AutomationId "Library.EmptyTitle"
    $workspaceScreenshot = Capture-PhysicalWindow `
        $workspaceHandle `
        (Join-Path $screenshots "06-custom-workspace-selected.png")
    $scenarioResults.Add([ordered]@{
        scenario = "choose-custom-workspace"
        launcher = $chooseButtonObservation
        picker = [ordered]@{
            window = $workspaceDialogObservation
            confirm = $workspaceConfirmObservation
            ownerDisabled = $true
            selectedDirectory = $workspaceTarget
        }
        result = [ordered]@{
            workspacePath = Observe-Element $workspacePath
            emptyTitle = Observe-Element $workspaceEmptyTitle
            selectedDirectoryExists =
                (Test-Path -LiteralPath $workspaceTarget -PathType Container)
        }
        screenshots = @($workspaceDialogScreenshot, $workspaceScreenshot)
        topmostAtEnd =
            [LumaChartLibraryLauncherNative]::IsTopmost($workspaceHandle)
    })
    $workspaceExitCode = Stop-LauncherScenario $activeScenario
    Assert ($workspaceExitCode -eq 0) "Workspace scenario exited with $workspaceExitCode."
    $activeScenario = $null

    $emptyValidationRoot = Join-Path $scratch "empty-validation"
    $emptyValidationTarget =
        Join-Path $emptyValidationRoot "Empty Project 中文"
    [IO.Directory]::CreateDirectory($emptyValidationTarget) | Out-Null
    Invoke-ProjectDirectoryValidationScenario `
        -ScenarioName "empty-project-notice" `
        -ScenarioRoot $emptyValidationRoot `
        -TargetDirectory $emptyValidationTarget `
        -ExpectedMessage (
            "这个目录中没有可直接打开的 .mc 或 .osu 谱面。`n`n" +
            "请选择具体的歌曲 / 谱面目录。") `
        -ExpectedStatus (
            "打开项目失败：所选项目目录中没有直接包含的 .mc 或 .osu 谱面。") `
        -ExpectedChartCount 0 `
        -ScreenshotFileName "07-empty-project-native-notice.png"

    $crowdedValidationRoot = Join-Path $scratch "crowded-validation"
    $crowdedValidationTarget =
        Join-Path $crowdedValidationRoot "Crowded Project 129"
    [IO.Directory]::CreateDirectory($crowdedValidationTarget) | Out-Null
    for ($index = 0; $index -lt 129; $index++) {
        [IO.File]::WriteAllText(
            (Join-Path $crowdedValidationTarget (
                "chart-{0:D3}.mc" -f $index)),
            "{}")
    }
    Invoke-ProjectDirectoryValidationScenario `
        -ScenarioName "too-many-project-notice" `
        -ScenarioRoot $crowdedValidationRoot `
        -TargetDirectory $crowdedValidationTarget `
        -ExpectedMessage (
            "这个目录直属包含 129 张谱面，像是曲库根目录。`n`n" +
            "请改选更具体的歌曲目录（最多 128 张）。") `
        -ExpectedStatus (
            "打开项目失败：项目目录直接包含 129 张谱面，超过 128 张安全上限。") `
        -ExpectedChartCount 129 `
        -ScreenshotFileName "08-too-many-project-native-notice.png"

    $cancelRoot = Join-Path $scratch "cancel-open-project"
    $cancelTarget = Join-Path $cancelRoot "Cancel Target 中文"
    [IO.Directory]::CreateDirectory($cancelTarget) | Out-Null
    $activeScenario = Start-LauncherScenario `
        -Name "cancel-open-project" `
        -ScenarioRoot $cancelRoot `
        -PickerStartDirectory $cancelTarget
    $cancelProcess = $activeScenario.process
    $cancelHandle = [IntPtr]$activeScenario.handle
    $cancelStatusBefore = Find-VisibleElementById `
        -ProcessId $cancelProcess.Id `
        -AutomationId "Library.Status"
    $cancelStatusNameBefore = [string]$cancelStatusBefore.Current.Name
    $cancelWorkspaceBefore = Find-VisibleElementById `
        -ProcessId $cancelProcess.Id `
        -AutomationId "Library.WorkspacePath"
    $cancelWorkspaceNameBefore = [string]$cancelWorkspaceBefore.Current.Name
    $cancelOpenButton = Find-VisibleElementById `
        -ProcessId $cancelProcess.Id `
        -AutomationId "Library.OpenProject"
    $cancelOpenObservation = Observe-Element $cancelOpenButton
    $actions.Add((Invoke-UiaElement $cancelOpenButton))
    $cancelDialog = Find-VisibleProcessWindowByName `
        -ProcessId $cancelProcess.Id `
        -Name "选择具体谱面目录"
    $cancelDialogHandle = [IntPtr]$cancelDialog.Current.NativeWindowHandle
    Assert ($cancelDialogHandle -ne [IntPtr]::Zero) (
        "Cancel folder picker has no HWND.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsWindowEnabled($cancelHandle)) (
        "Cancel folder picker did not disable its owner.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($cancelHandle) -and
        -not [LumaChartLibraryLauncherNative]::IsTopmost($cancelDialogHandle)) (
        "Cancel owner or folder picker is unexpectedly topmost.")
    $cancelDialogScreenshot = Capture-PhysicalWindow `
        $cancelDialogHandle `
        (Join-Path $screenshots "09-open-project-native-folder-picker-cancel.png")
    $cancelButton = Find-FolderDialogCancelButton $cancelDialog
    $cancelDialogObservation = Observe-Element $cancelDialog
    $cancelButtonObservation = Observe-Element $cancelButton
    $actions.Add((Invoke-UiaElement $cancelButton))
    Wait-Condition -Description "cancelled picker owner re-enabled" -Condition {
        [LumaChartLibraryLauncherNative]::IsWindowEnabled($cancelHandle)
    }
    $cancelStatusAfter = Find-VisibleElementById `
        -ProcessId $cancelProcess.Id `
        -AutomationId "Library.Status"
    $cancelWorkspaceAfter = Find-VisibleElementById `
        -ProcessId $cancelProcess.Id `
        -AutomationId "Library.WorkspacePath"
    $cancelOpenAfter = Find-VisibleElementById `
        -ProcessId $cancelProcess.Id `
        -AutomationId "Library.OpenProject"
    Wait-Condition -Description "cancelled picker state unchanged" -Condition {
        [string]$cancelStatusAfter.Current.Name -ceq $cancelStatusNameBefore -and
        [string]$cancelWorkspaceAfter.Current.Name -ceq $cancelWorkspaceNameBefore -and
        [bool]$cancelOpenAfter.Current.IsEnabled
    }
    $cancelRecoveredScreenshot = Capture-PhysicalWindow `
        $cancelHandle `
        (Join-Path $screenshots "10-open-project-cancel-recovered.png")
    $scenarioResults.Add([ordered]@{
        scenario = "open-project-picker-cancel"
        launcher = $cancelOpenObservation
        picker = [ordered]@{
            window = $cancelDialogObservation
            cancel = $cancelButtonObservation
            ownerDisabled = $true
            suggestedDirectory = $cancelTarget
        }
        result = [ordered]@{
            statusBefore = $cancelStatusNameBefore
            statusAfter = Observe-Element $cancelStatusAfter
            workspaceBefore = $cancelWorkspaceNameBefore
            workspaceAfter = Observe-Element $cancelWorkspaceAfter
            ownerEnabledAfterCancel = $true
            launcherRecovered = Observe-Element $cancelOpenAfter
            noEditorOpened = @(
                try {
                    Find-VisibleElementById `
                        -ProcessId $cancelProcess.Id `
                        -AutomationId "Timeline.Surface" `
                        -TimeoutMilliseconds 250
                }
                catch { }
            ).Count -eq 0
        }
        screenshots = @($cancelDialogScreenshot, $cancelRecoveredScreenshot)
        topmostAtEnd =
            [LumaChartLibraryLauncherNative]::IsTopmost($cancelHandle)
    })
    $cancelExitCode = Stop-LauncherScenario $activeScenario
    Assert ($cancelExitCode -eq 0) (
        "Cancel scenario exited with $cancelExitCode.")
    $activeScenario = $null

    $lifecycleRoot = Join-Path $scratch "workspace-lifecycle"
    $lifecycleTarget =
        Join-Path $lifecycleRoot "Persisted Workspace 中文"
    [IO.Directory]::CreateDirectory($lifecycleTarget) | Out-Null
    $activeScenario = Start-LauncherScenario `
        -Name "workspace-search-clear" `
        -ScenarioRoot $lifecycleRoot `
        -PickerStartDirectory $lifecycleTarget
    $lifecycleProcess = $activeScenario.process
    $lifecycleHandle = [IntPtr]$activeScenario.handle
    $lifecycleLocalData = [string]$activeScenario.localData
    $lifecycleEditing = [string]$activeScenario.editing
    $lifecycleSearch = Find-VisibleElementById `
        -ProcessId $lifecycleProcess.Id `
        -AutomationId "Library.Search"
    $lifecycleSearchInitial = Get-UiaValue $lifecycleSearch
    Assert ($lifecycleSearchInitial -ceq "") (
        "Workspace lifecycle search did not start empty.")
    $actions.Add((Set-UiaValue $lifecycleSearch "Resound"))
    $lifecycleSearchPrefilled = Get-UiaValue $lifecycleSearch
    $lifecycleStatusPrefilled = Find-VisibleElementById `
        -ProcessId $lifecycleProcess.Id `
        -AutomationId "Library.Status"
    $lifecycleStatusPrefilledObservation =
        Observe-Element $lifecycleStatusPrefilled
    $lifecyclePrefilledScreenshot = Capture-PhysicalWindow `
        $lifecycleHandle `
        (Join-Path $screenshots "11-workspace-search-prefilled.png")
    $lifecycleChoose = Find-VisibleElementById `
        -ProcessId $lifecycleProcess.Id `
        -AutomationId "Library.ChooseWorkspace"
    $lifecycleChooseObservation = Observe-Element $lifecycleChoose
    $actions.Add((Invoke-UiaElement $lifecycleChoose))
    $lifecycleDialog = Find-VisibleProcessWindowByName `
        -ProcessId $lifecycleProcess.Id `
        -Name "选择 LumaChart 工作目录或 Malody chart 目录"
    $lifecycleDialogHandle =
        [IntPtr]$lifecycleDialog.Current.NativeWindowHandle
    Assert ($lifecycleDialogHandle -ne [IntPtr]::Zero) (
        "Workspace lifecycle folder picker has no HWND.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsWindowEnabled(
            $lifecycleHandle)) (
        "Workspace lifecycle folder picker did not disable its owner.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($lifecycleHandle) -and
        -not [LumaChartLibraryLauncherNative]::IsTopmost(
            $lifecycleDialogHandle)) (
        "Workspace lifecycle owner or folder picker is unexpectedly topmost.")
    $lifecycleDialogScreenshot = Capture-PhysicalWindow `
        $lifecycleDialogHandle `
        (Join-Path $screenshots "12-workspace-lifecycle-native-folder-picker.png")
    $lifecycleConfirm = Find-FolderDialogConfirmButton $lifecycleDialog
    $lifecycleDialogObservation = Observe-Element $lifecycleDialog
    $lifecycleConfirmObservation = Observe-Element $lifecycleConfirm
    $actions.Add((Invoke-UiaElement $lifecycleConfirm))
    Wait-Condition -Description "workspace lifecycle owner re-enabled" -Condition {
        [LumaChartLibraryLauncherNative]::IsWindowEnabled($lifecycleHandle)
    }
    $lifecycleWorkspace = Find-VisibleElementById `
        -ProcessId $lifecycleProcess.Id `
        -AutomationId "Library.WorkspacePath"
    Wait-Condition -Description "workspace lifecycle selected path" -Condition {
        [string]$lifecycleWorkspace.Current.Name -ceq
            "工作目录  $lifecycleTarget"
    }
    Wait-Condition -Description "workspace lifecycle search clear" -Condition {
        (Get-UiaValue $lifecycleSearch) -ceq ""
    }
    $lifecycleEmpty = Find-VisibleElementById `
        -ProcessId $lifecycleProcess.Id `
        -AutomationId "Library.EmptyTitle"
    $workspaceSettingsPath =
        Join-Path $lifecycleLocalData "workspace.json"
    Wait-Condition -Description "workspace lifecycle settings file" -Condition {
        Test-Path -LiteralPath $workspaceSettingsPath -PathType Leaf
    }
    $workspaceSettingsBeforeRestart =
        Get-Fingerprint $workspaceSettingsPath
    $workspaceSettingsJson =
        Get-Content -LiteralPath $workspaceSettingsPath -Raw -Encoding UTF8 |
            ConvertFrom-Json
    Assert (
        [string]$workspaceSettingsJson.WorkspaceRoot -ceq $lifecycleTarget) (
        "Workspace lifecycle settings did not persist the selected root.")
    $lifecycleClearedScreenshot = Capture-PhysicalWindow `
        $lifecycleHandle `
        (Join-Path $screenshots "13-workspace-search-cleared.png")
    $scenarioResults.Add([ordered]@{
        scenario = "workspace-search-clear"
        search = [ordered]@{
            element = Observe-Element $lifecycleSearch
            initialValue = $lifecycleSearchInitial
            prefilledValue = $lifecycleSearchPrefilled
            statusAfterPrefill = $lifecycleStatusPrefilledObservation
            valueAfterSwitch = Get-UiaValue $lifecycleSearch
        }
        launcher = $lifecycleChooseObservation
        picker = [ordered]@{
            window = $lifecycleDialogObservation
            confirm = $lifecycleConfirmObservation
            ownerDisabled = $true
            selectedDirectory = $lifecycleTarget
        }
        result = [ordered]@{
            workspacePath = Observe-Element $lifecycleWorkspace
            emptyTitle = Observe-Element $lifecycleEmpty
            ownerEnabledAfterSelection = $true
            settings = $workspaceSettingsBeforeRestart
            persistedWorkspaceRoot =
                [string]$workspaceSettingsJson.WorkspaceRoot
        }
        screenshots = @(
            $lifecyclePrefilledScreenshot,
            $lifecycleDialogScreenshot,
            $lifecycleClearedScreenshot)
        topmostAtEnd =
            [LumaChartLibraryLauncherNative]::IsTopmost($lifecycleHandle)
    })
    $lifecycleExitCode = Stop-LauncherScenario $activeScenario
    Assert ($lifecycleExitCode -eq 0) (
        "Workspace lifecycle scenario exited with $lifecycleExitCode.")
    $activeScenario = $null

    $restartRoot = Join-Path $lifecycleRoot "restart"
    $activeScenario = Start-LauncherScenario `
        -Name "workspace-restart" `
        -ScenarioRoot $restartRoot `
        -PickerStartDirectory $lifecycleTarget `
        -LocalDataRoot $lifecycleLocalData `
        -EditingRoot $lifecycleEditing `
        -OmitWorkspaceOverride `
        -UsePersistedWorkspaceEvidence
    $restartProcess = $activeScenario.process
    $restartHandle = [IntPtr]$activeScenario.handle
    $restartWorkspace = Find-VisibleElementById `
        -ProcessId $restartProcess.Id `
        -AutomationId "Library.WorkspacePath"
    Wait-Condition -Description "persisted workspace after restart" -Condition {
        [string]$restartWorkspace.Current.Name -ceq
            "工作目录  $lifecycleTarget"
    }
    $restartSearch = Find-VisibleElementById `
        -ProcessId $restartProcess.Id `
        -AutomationId "Library.Search"
    Assert ((Get-UiaValue $restartSearch) -ceq "") (
        "Workspace search was not empty after restart.")
    $restartEmpty = Find-VisibleElementById `
        -ProcessId $restartProcess.Id `
        -AutomationId "Library.EmptyTitle"
    $workspaceSettingsAfterRestart =
        Get-Fingerprint $workspaceSettingsPath
    Assert (
        $workspaceSettingsAfterRestart.bytes -eq
            $workspaceSettingsBeforeRestart.bytes -and
        $workspaceSettingsAfterRestart.sha256 -ceq
            $workspaceSettingsBeforeRestart.sha256) (
        "Workspace settings content changed across restart.")
    $restartScreenshot = Capture-PhysicalWindow `
        $restartHandle `
        (Join-Path $screenshots "14-workspace-persisted-after-restart.png")
    $scenarioResults.Add([ordered]@{
        scenario = "workspace-persisted-after-restart"
        result = [ordered]@{
            workspacePath = Observe-Element $restartWorkspace
            search = [ordered]@{
                element = Observe-Element $restartSearch
                value = Get-UiaValue $restartSearch
            }
            emptyTitle = Observe-Element $restartEmpty
            settingsBeforeRestart = $workspaceSettingsBeforeRestart
            settingsAfterRestart = $workspaceSettingsAfterRestart
            workspaceOverrideOmitted = $true
        }
        screenshots = @($restartScreenshot)
        topmostAtEnd =
            [LumaChartLibraryLauncherNative]::IsTopmost($restartHandle)
    })
    $restartExitCode = Stop-LauncherScenario $activeScenario
    Assert ($restartExitCode -eq 0) (
        "Workspace restart scenario exited with $restartExitCode.")
    $activeScenario = $null

    $longRoot = Join-Path $scratch "long-path-open"
    $longTarget = $longRoot
    while ($longTarget.Length -lt 330) {
        $longTarget = Join-Path $longTarget (
            "Long Segment 中文 {0:D3}" -f $longTarget.Length)
    }
    [IO.Directory]::CreateDirectory($longTarget) | Out-Null
    $longChart = Join-Path $longTarget "long-path-real-resound.mc"
    Copy-Item -LiteralPath $chartFixture -Destination $longChart
    $longChartBefore = Get-Fingerprint $longChart
    $activeScenario = Start-LauncherScenario `
        -Name "long-path-open" `
        -ScenarioRoot $longRoot `
        -PickerStartDirectory $longTarget
    $longProcess = $activeScenario.process
    $longHandle = [IntPtr]$activeScenario.handle
    $longOpenButton = Find-VisibleElementById `
        -ProcessId $longProcess.Id `
        -AutomationId "Library.OpenProject"
    $longOpenButtonObservation = Observe-Element $longOpenButton
    $actions.Add((Invoke-UiaElement $longOpenButton))
    $longPicker = Find-VisibleProcessWindowByName `
        -ProcessId $longProcess.Id `
        -Name "选择具体谱面目录"
    $longPickerHandle = [IntPtr]$longPicker.Current.NativeWindowHandle
    Assert ($longPickerHandle -ne [IntPtr]::Zero) (
        "Long-path folder picker has no HWND.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsWindowEnabled($longHandle)) (
        "Long-path folder picker did not disable its owner.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($longHandle) -and
        -not [LumaChartLibraryLauncherNative]::IsTopmost($longPickerHandle)) (
        "Long-path owner or folder picker is unexpectedly topmost.")
    $longPickerScreenshot = Capture-PhysicalWindow `
        $longPickerHandle `
        (Join-Path $screenshots "15-long-path-native-folder-picker.png")
    $longConfirm = Find-FolderDialogConfirmButton $longPicker
    $longPickerObservation = Observe-Element $longPicker
    $longConfirmObservation = Observe-Element $longConfirm
    $actions.Add((Invoke-UiaElement $longConfirm))
    $longTimeline = Find-VisibleElementById `
        -ProcessId $longProcess.Id `
        -AutomationId "Timeline.Surface"
    $longTab = Find-VisibleElementById `
        -ProcessId $longProcess.Id `
        -AutomationId "Editor.ChartTab"
    $longStatus = Find-VisibleElementById `
        -ProcessId $longProcess.Id `
        -AutomationId "Editor.Status"
    $longEditorScreenshot = Capture-PhysicalWindow `
        $longHandle `
        (Join-Path $screenshots "16-long-path-editor.png")
    $longChartAfter = Get-Fingerprint $longChart
    Assert (
        $longTarget.Length -ge 330 -and
        $longChartAfter.sha256 -ceq $longChartBefore.sha256 -and
        $longChartAfter.bytes -eq $longChartBefore.bytes) (
        "Long-path scenario did not preserve its selected real MC.")
    $scenarioResults.Add([ordered]@{
        scenario = "open-project-long-unicode-path"
        launcher = $longOpenButtonObservation
        picker = [ordered]@{
            window = $longPickerObservation
            confirm = $longConfirmObservation
            ownerDisabled = $true
            selectedDirectory = $longTarget
            selectedDirectoryLength = $longTarget.Length
        }
        result = [ordered]@{
            timeline = Observe-Element $longTimeline
            tab = Observe-Element $longTab
            status = Observe-Element $longStatus
            selectedChartBefore = $longChartBefore
            selectedChartAfter = $longChartAfter
        }
        screenshots = @($longPickerScreenshot, $longEditorScreenshot)
        topmostAtEnd =
            [LumaChartLibraryLauncherNative]::IsTopmost($longHandle)
    })
    $longExitCode = Stop-LauncherScenario $activeScenario
    Assert ($longExitCode -eq 0) (
        "Long-path scenario exited with $longExitCode.")
    $activeScenario = $null

    $partialRoot = Join-Path $scratch "partial-batch"
    $partialTarget = Join-Path $partialRoot "Partial Batch 中文"
    [IO.Directory]::CreateDirectory($partialTarget) | Out-Null
    $partialValidChart = Join-Path $partialTarget "00-valid-resound.mc"
    $partialInvalidChart = Join-Path $partialTarget "01-invalid.mc"
    Copy-Item -LiteralPath $chartFixture -Destination $partialValidChart
    [IO.File]::WriteAllText(
        $partialInvalidChart,
        '{"meta":{"title":"broken"},"note":[')
    $partialValidBefore = Get-Fingerprint $partialValidChart
    $partialInvalidBefore = Get-Fingerprint $partialInvalidChart
    $activeScenario = Start-LauncherScenario `
        -Name "partial-batch" `
        -ScenarioRoot $partialRoot `
        -PickerStartDirectory $partialTarget
    $partialProcess = $activeScenario.process
    $partialHandle = [IntPtr]$activeScenario.handle
    $partialOpenButton = Find-VisibleElementById `
        -ProcessId $partialProcess.Id `
        -AutomationId "Library.OpenProject"
    $partialOpenButtonObservation = Observe-Element $partialOpenButton
    $actions.Add((Invoke-UiaElement $partialOpenButton))
    $partialPicker = Find-VisibleProcessWindowByName `
        -ProcessId $partialProcess.Id `
        -Name "选择具体谱面目录"
    $partialPickerHandle = [IntPtr]$partialPicker.Current.NativeWindowHandle
    Assert ($partialPickerHandle -ne [IntPtr]::Zero) (
        "Partial-batch folder picker has no HWND.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsWindowEnabled($partialHandle)) (
        "Partial-batch folder picker did not disable its owner.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($partialHandle) -and
        -not [LumaChartLibraryLauncherNative]::IsTopmost($partialPickerHandle)) (
        "Partial-batch owner or folder picker is unexpectedly topmost.")
    $partialPickerScreenshot = Capture-PhysicalWindow `
        $partialPickerHandle `
        (Join-Path $screenshots "17-partial-batch-native-folder-picker.png")
    $partialConfirm = Find-FolderDialogConfirmButton $partialPicker
    $partialPickerObservation = Observe-Element $partialPicker
    $partialConfirmObservation = Observe-Element $partialConfirm
    $actions.Add((Invoke-UiaElement $partialConfirm))
    $partialNotice = Find-VisibleProcessWindowByName `
        -ProcessId $partialProcess.Id `
        -Name "LumaChart Studio"
    $partialNoticeHandle = [IntPtr]$partialNotice.Current.NativeWindowHandle
    Assert ($partialNoticeHandle -ne [IntPtr]::Zero) (
        "Partial-batch error notice has no HWND.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsWindowEnabled($partialHandle)) (
        "Partial-batch error notice did not disable its owner.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($partialHandle) -and
        -not [LumaChartLibraryLauncherNative]::IsTopmost($partialNoticeHandle)) (
        "Partial-batch owner or error notice is unexpectedly topmost.")
    $partialNoticeMessage = Find-VisibleDescendantByNamePrefix `
        -Root $partialNotice `
        -Prefix "无法打开谱面`n`n"
    $partialNoticeConfirm = Find-MessageBoxConfirmButton $partialNotice
    $partialNoticeObservation = Observe-Element $partialNotice
    $partialNoticeMessageObservation = Observe-Element $partialNoticeMessage
    $partialNoticeConfirmObservation = Observe-Element $partialNoticeConfirm
    $partialNoticeScreenshot = Capture-PhysicalWindow `
        $partialNoticeHandle `
        (Join-Path $screenshots "18-partial-batch-invalid-chart-notice.png")
    $actions.Add((Invoke-UiaElement $partialNoticeConfirm))
    Wait-Condition -Description "partial-batch owner re-enabled" -Condition {
        [LumaChartLibraryLauncherNative]::IsWindowEnabled($partialHandle)
    }
    $partialTimeline = Find-VisibleElementById `
        -ProcessId $partialProcess.Id `
        -AutomationId "Timeline.Surface"
    $partialTab = Find-VisibleElementById `
        -ProcessId $partialProcess.Id `
        -AutomationId "Editor.ChartTab"
    $partialStatus = Find-VisibleElementById `
        -ProcessId $partialProcess.Id `
        -AutomationId "Editor.Status"
    $expectedPartialStatus =
        "已打开项目：$([IO.Path]::GetFileName($partialTarget)) · 2 张谱面标签"
    Wait-Condition -Description "partial-batch WPF completion status" -Condition {
        [string]$partialStatus.Current.Name -ceq $expectedPartialStatus
    }
    $partialTabCount = Get-VisibleElementCountById `
        -ProcessId $partialProcess.Id `
        -AutomationId "Editor.ChartTab"
    Assert ($partialTabCount -eq 1) (
        "Partial-batch scenario should retain exactly one valid editor tab.")
    $partialRecoveredScreenshot = Capture-PhysicalWindow `
        $partialHandle `
        (Join-Path $screenshots "19-partial-batch-valid-tab-retained.png")
    $partialValidAfter = Get-Fingerprint $partialValidChart
    $partialInvalidAfter = Get-Fingerprint $partialInvalidChart
    Assert (
        $partialValidAfter.sha256 -ceq $partialValidBefore.sha256 -and
        $partialInvalidAfter.sha256 -ceq $partialInvalidBefore.sha256) (
        "Partial-batch scenario modified an input chart.")
    $scenarioResults.Add([ordered]@{
        scenario = "open-project-partial-batch-failure"
        launcher = $partialOpenButtonObservation
        picker = [ordered]@{
            window = $partialPickerObservation
            confirm = $partialConfirmObservation
            ownerDisabled = $true
            selectedDirectory = $partialTarget
        }
        notice = [ordered]@{
            window = $partialNoticeObservation
            message = $partialNoticeMessageObservation
            confirm = $partialNoticeConfirmObservation
            ownerDisabled = $true
            ownerEnabledAfterClose = $true
        }
        result = [ordered]@{
            timeline = Observe-Element $partialTimeline
            tab = Observe-Element $partialTab
            visibleTabCount = $partialTabCount
            status = Observe-Element $partialStatus
            validChartBefore = $partialValidBefore
            validChartAfter = $partialValidAfter
            invalidChartBefore = $partialInvalidBefore
            invalidChartAfter = $partialInvalidAfter
        }
        screenshots = @(
            $partialPickerScreenshot,
            $partialNoticeScreenshot,
            $partialRecoveredScreenshot)
        topmostAtEnd =
            [LumaChartLibraryLauncherNative]::IsTopmost($partialHandle)
    })
    $partialExitCode = Stop-LauncherScenario $activeScenario
    Assert ($partialExitCode -eq 0) (
        "Partial-batch scenario exited with $partialExitCode.")
    $activeScenario = $null

    $permissionRoot = Join-Path $scratch "permission-denied"
    $permissionTarget = Join-Path $permissionRoot "Denied Project 中文"
    [IO.Directory]::CreateDirectory($permissionTarget) | Out-Null
    $permissionChart = Join-Path $permissionTarget "real-resound.mc"
    Copy-Item -LiteralPath $chartFixture -Destination $permissionChart
    $permissionChartBefore = Get-Fingerprint $permissionChart
    $permissionAclBefore = Get-Acl -LiteralPath $permissionTarget
    $activeScenario = Start-LauncherScenario `
        -Name "permission-denied" `
        -ScenarioRoot $permissionRoot `
        -PickerStartDirectory $permissionTarget
    $permissionProcess = $activeScenario.process
    $permissionHandle = [IntPtr]$activeScenario.handle
    $permissionOpenButton = Find-VisibleElementById `
        -ProcessId $permissionProcess.Id `
        -AutomationId "Library.OpenProject"
    $permissionOpenButtonObservation = Observe-Element $permissionOpenButton
    $actions.Add((Invoke-UiaElement $permissionOpenButton))
    $permissionPicker = Find-VisibleProcessWindowByName `
        -ProcessId $permissionProcess.Id `
        -Name "选择具体谱面目录"
    $permissionPickerHandle =
        [IntPtr]$permissionPicker.Current.NativeWindowHandle
    Assert ($permissionPickerHandle -ne [IntPtr]::Zero) (
        "Permission-denied folder picker has no HWND.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsWindowEnabled(
            $permissionHandle)) (
        "Permission-denied folder picker did not disable its owner.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($permissionHandle) -and
        -not [LumaChartLibraryLauncherNative]::IsTopmost(
            $permissionPickerHandle)) (
        "Permission-denied owner or folder picker is unexpectedly topmost.")
    $permissionConfirm = Find-FolderDialogConfirmButton $permissionPicker
    $permissionPickerObservation = Observe-Element $permissionPicker
    $permissionConfirmObservation = Observe-Element $permissionConfirm
    $permissionPickerScreenshot = Capture-PhysicalWindow `
        $permissionPickerHandle `
        (Join-Path $screenshots "20-permission-denied-native-folder-picker.png")

    $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $permissionAcl = Get-Acl -LiteralPath $permissionTarget
    $permissionRule =
        [Security.AccessControl.FileSystemAccessRule]::new(
            $currentSid,
            [Security.AccessControl.FileSystemRights]::ReadAndExecute,
            [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
            [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Deny)
    [void]$permissionAcl.AddAccessRule($permissionRule)
    Set-Acl -LiteralPath $permissionTarget -AclObject $permissionAcl
    $permissionAclApplied = $true
    $permissionEnumerationException = $null
    try {
        $enumerator =
            [IO.Directory]::EnumerateFiles($permissionTarget).GetEnumerator()
        try {
            [void]$enumerator.MoveNext()
        }
        finally {
            if ($enumerator -is [IDisposable]) {
                $enumerator.Dispose()
            }
        }
    }
    catch {
        $permissionEnumerationException = $_.Exception
        while ($null -ne $permissionEnumerationException.InnerException) {
            $permissionEnumerationException =
                $permissionEnumerationException.InnerException
        }
    }
    Assert (
        $permissionEnumerationException -is [UnauthorizedAccessException]) (
        "The isolated permission target did not reject enumeration.")
    $permissionEnumerationObservation = [ordered]@{
        directoryExists = [IO.Directory]::Exists($permissionTarget)
        exceptionType = $permissionEnumerationException.GetType().FullName
        exceptionMessage = $permissionEnumerationException.Message
        currentUserSid = $currentSid.Value
        deniedRights = "ReadAndExecute"
    }
    $actions.Add((Invoke-UiaElement $permissionConfirm))
    $permissionNotice = Find-VisibleProcessWindowByName `
        -ProcessId $permissionProcess.Id `
        -Name "LumaChart Studio"
    $permissionNoticeHandle =
        [IntPtr]$permissionNotice.Current.NativeWindowHandle
    Assert ($permissionNoticeHandle -ne [IntPtr]::Zero) (
        "Permission-denied error notice has no HWND.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsWindowEnabled(
            $permissionHandle)) (
        "Permission-denied error notice did not disable its owner.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($permissionHandle) -and
        -not [LumaChartLibraryLauncherNative]::IsTopmost(
            $permissionNoticeHandle)) (
        "Permission-denied owner or error notice is unexpectedly topmost.")
    $permissionNoticeMessage = Find-VisibleDescendantByNamePrefix `
        -Root $permissionNotice `
        -Prefix "无法打开项目目录`n`n"
    $permissionNoticeConfirm =
        Find-MessageBoxConfirmButton $permissionNotice
    $permissionNoticeObservation = Observe-Element $permissionNotice
    $permissionNoticeMessageObservation =
        Observe-Element $permissionNoticeMessage
    $permissionNoticeConfirmObservation =
        Observe-Element $permissionNoticeConfirm
    $permissionNoticeScreenshot = Capture-PhysicalWindow `
        $permissionNoticeHandle `
        (Join-Path $screenshots "21-permission-denied-native-error.png")
    Set-Acl -LiteralPath $permissionTarget -AclObject $permissionAclBefore
    $permissionAclApplied = $false
    $actions.Add((Invoke-UiaElement $permissionNoticeConfirm))
    Wait-Condition -Description "permission-denied owner re-enabled" -Condition {
        [LumaChartLibraryLauncherNative]::IsWindowEnabled($permissionHandle)
    }
    $permissionStatus = Find-VisibleElementById `
        -ProcessId $permissionProcess.Id `
        -AutomationId "Library.Status"
    Wait-Condition -Description "permission-denied status" -Condition {
        [string]$permissionStatus.Current.Name -like "打开项目失败：*"
    }
    $permissionChartAfter = Get-Fingerprint $permissionChart
    Assert (
        $permissionChartAfter.sha256 -ceq $permissionChartBefore.sha256 -and
        $permissionChartAfter.bytes -eq $permissionChartBefore.bytes) (
        "Permission-denied scenario modified its isolated real MC.")
    $scenarioResults.Add([ordered]@{
        scenario = "open-project-permission-denied"
        launcher = $permissionOpenButtonObservation
        picker = [ordered]@{
            window = $permissionPickerObservation
            confirm = $permissionConfirmObservation
            ownerDisabled = $true
            selectedDirectory = $permissionTarget
        }
        aclProbe = $permissionEnumerationObservation
        notice = [ordered]@{
            window = $permissionNoticeObservation
            message = $permissionNoticeMessageObservation
            confirm = $permissionNoticeConfirmObservation
            ownerDisabled = $true
            ownerEnabledAfterClose = $true
        }
        result = [ordered]@{
            status = Observe-Element $permissionStatus
            noEditorOpened = @(
                try {
                    Find-VisibleElementById `
                        -ProcessId $permissionProcess.Id `
                        -AutomationId "Timeline.Surface" `
                        -TimeoutMilliseconds 250
                }
                catch { }
            ).Count -eq 0
            selectedChartBefore = $permissionChartBefore
            selectedChartAfter = $permissionChartAfter
        }
        screenshots = @(
            $permissionPickerScreenshot,
            $permissionNoticeScreenshot)
        topmostAtEnd =
            [LumaChartLibraryLauncherNative]::IsTopmost($permissionHandle)
    })
    $permissionExitCode = Stop-LauncherScenario $activeScenario
    Assert ($permissionExitCode -eq 0) (
        "Permission-denied scenario exited with $permissionExitCode.")
    $activeScenario = $null

    $brokenRoot = Join-Path $scratch "broken-link"
    $brokenTarget = Join-Path $brokenRoot "Broken Link 中文"
    [IO.Directory]::CreateDirectory($brokenTarget) | Out-Null
    $brokenMissingTarget = Join-Path $brokenTarget "missing-target.mc"
    $brokenLink = Join-Path $brokenTarget "broken-link.mc"
    [void][IO.File]::CreateSymbolicLink(
        $brokenLink,
        $brokenMissingTarget)
    $brokenLinkItem = Get-Item -LiteralPath $brokenLink -Force
    $brokenLinkObservation = [ordered]@{
        path = $brokenLinkItem.FullName
        linkType = [string]$brokenLinkItem.LinkType
        target = [string]$brokenLinkItem.Target
        targetExists = [IO.File]::Exists($brokenMissingTarget)
        enumeratedAsProjectChart = @(
            [IO.Directory]::EnumerateFiles($brokenTarget) |
                Where-Object {
                    [IO.Path]::GetExtension($_).Equals(
                        ".mc",
                        [StringComparison]::OrdinalIgnoreCase)
                }).Count -eq 1
    }
    $activeScenario = Start-LauncherScenario `
        -Name "broken-link" `
        -ScenarioRoot $brokenRoot `
        -PickerStartDirectory $brokenTarget
    $brokenProcess = $activeScenario.process
    $brokenHandle = [IntPtr]$activeScenario.handle
    $brokenOpenButton = Find-VisibleElementById `
        -ProcessId $brokenProcess.Id `
        -AutomationId "Library.OpenProject"
    $brokenOpenButtonObservation = Observe-Element $brokenOpenButton
    $actions.Add((Invoke-UiaElement $brokenOpenButton))
    $brokenPicker = Find-VisibleProcessWindowByName `
        -ProcessId $brokenProcess.Id `
        -Name "选择具体谱面目录"
    $brokenPickerHandle = [IntPtr]$brokenPicker.Current.NativeWindowHandle
    Assert ($brokenPickerHandle -ne [IntPtr]::Zero) (
        "Broken-link folder picker has no HWND.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsWindowEnabled($brokenHandle)) (
        "Broken-link folder picker did not disable its owner.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($brokenHandle) -and
        -not [LumaChartLibraryLauncherNative]::IsTopmost(
            $brokenPickerHandle)) (
        "Broken-link owner or folder picker is unexpectedly topmost.")
    $brokenConfirm = Find-FolderDialogConfirmButton $brokenPicker
    $brokenPickerObservation = Observe-Element $brokenPicker
    $brokenConfirmObservation = Observe-Element $brokenConfirm
    $brokenPickerScreenshot = Capture-PhysicalWindow `
        $brokenPickerHandle `
        (Join-Path $screenshots "22-broken-link-native-folder-picker.png")
    $actions.Add((Invoke-UiaElement $brokenConfirm))
    $brokenNotice = Find-VisibleProcessWindowByName `
        -ProcessId $brokenProcess.Id `
        -Name "LumaChart Studio"
    $brokenNoticeHandle = [IntPtr]$brokenNotice.Current.NativeWindowHandle
    Assert ($brokenNoticeHandle -ne [IntPtr]::Zero) (
        "Broken-link error notice has no HWND.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsWindowEnabled($brokenHandle)) (
        "Broken-link error notice did not disable its owner.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($brokenHandle) -and
        -not [LumaChartLibraryLauncherNative]::IsTopmost($brokenNoticeHandle)) (
        "Broken-link owner or error notice is unexpectedly topmost.")
    $brokenNoticeMessage = Find-VisibleDescendantByNamePrefix `
        -Root $brokenNotice `
        -Prefix "无法打开谱面`n`n"
    $brokenNoticeConfirm = Find-MessageBoxConfirmButton $brokenNotice
    $brokenNoticeObservation = Observe-Element $brokenNotice
    $brokenNoticeMessageObservation = Observe-Element $brokenNoticeMessage
    $brokenNoticeConfirmObservation = Observe-Element $brokenNoticeConfirm
    $brokenNoticeScreenshot = Capture-PhysicalWindow `
        $brokenNoticeHandle `
        (Join-Path $screenshots "23-broken-link-native-error.png")
    $actions.Add((Invoke-UiaElement $brokenNoticeConfirm))
    Wait-Condition -Description "broken-link owner re-enabled" -Condition {
        [LumaChartLibraryLauncherNative]::IsWindowEnabled($brokenHandle)
    }
    $brokenStatus = Find-VisibleElementById `
        -ProcessId $brokenProcess.Id `
        -AutomationId "Library.Status"
    Wait-Condition -Description "broken-link WPF completion status" -Condition {
        [string]$brokenStatus.Current.Name -ceq
            "已打开项目：Broken Link 中文"
    }
    $brokenRecoveredScreenshot = Capture-PhysicalWindow `
        $brokenHandle `
        (Join-Path $screenshots "24-broken-link-recovered-library.png")
    Assert (
        -not [IO.File]::Exists($brokenMissingTarget) -and
        [IO.File]::Exists($brokenLink)) (
        "Broken-link fixture drifted during the scenario.")
    $scenarioResults.Add([ordered]@{
        scenario = "open-project-broken-link"
        launcher = $brokenOpenButtonObservation
        picker = [ordered]@{
            window = $brokenPickerObservation
            confirm = $brokenConfirmObservation
            ownerDisabled = $true
            selectedDirectory = $brokenTarget
        }
        link = $brokenLinkObservation
        notice = [ordered]@{
            window = $brokenNoticeObservation
            message = $brokenNoticeMessageObservation
            confirm = $brokenNoticeConfirmObservation
            ownerDisabled = $true
            ownerEnabledAfterClose = $true
        }
        result = [ordered]@{
            status = Observe-Element $brokenStatus
            noEditorOpened = @(
                try {
                    Find-VisibleElementById `
                        -ProcessId $brokenProcess.Id `
                        -AutomationId "Timeline.Surface" `
                        -TimeoutMilliseconds 250
                }
                catch { }
            ).Count -eq 0
        }
        screenshots = @(
            $brokenPickerScreenshot,
            $brokenNoticeScreenshot,
            $brokenRecoveredScreenshot)
        topmostAtEnd =
            [LumaChartLibraryLauncherNative]::IsTopmost($brokenHandle)
    })
    $brokenExitCode = Stop-LauncherScenario $activeScenario
    Assert ($brokenExitCode -eq 0) (
        "Broken-link scenario exited with $brokenExitCode.")
    $activeScenario = $null

    $multiRoot = Join-Path $scratch "multi-difficulty"
    $multiTarget = Join-Path $multiRoot "Real Multi 中文"
    [IO.Directory]::CreateDirectory($multiTarget) | Out-Null
    $multiCopiedCharts = @(
        $multiDifficultySourceCharts |
            ForEach-Object {
                $destination = Join-Path $multiTarget $_.Name
                Copy-Item -LiteralPath $_.FullName -Destination $destination
                Get-Item -LiteralPath $destination
            })
    $multiCopiedBefore = @(
        $multiCopiedCharts |
            ForEach-Object { Get-Fingerprint $_.FullName })
    $multiSummaries = @(
        $multiCopiedCharts |
            ForEach-Object { Get-McSummary $_.FullName })
    Assert (
        $multiSummaries.Count -eq 2 -and
        [string]$multiSummaries[0].title -ceq
            [string]$multiSummaries[1].title -and
        [string]$multiSummaries[0].version -cne
            [string]$multiSummaries[1].version -and
        @($multiSummaries | Where-Object {
            [int]$_.column -ne 4 -or [int]$_.playableNoteCount -le 0
        }).Count -eq 0) (
        "Real multi-difficulty fixture does not contain two distinct 4K charts.")
    $activeScenario = Start-LauncherScenario `
        -Name "multi-difficulty" `
        -ScenarioRoot $multiRoot `
        -PickerStartDirectory $multiTarget
    $multiProcess = $activeScenario.process
    $multiHandle = [IntPtr]$activeScenario.handle
    $multiOpenButton = Find-VisibleElementById `
        -ProcessId $multiProcess.Id `
        -AutomationId "Library.OpenProject"
    $multiOpenButtonObservation = Observe-Element $multiOpenButton
    $actions.Add((Invoke-UiaElement $multiOpenButton))
    $multiPicker = Find-VisibleProcessWindowByName `
        -ProcessId $multiProcess.Id `
        -Name "选择具体谱面目录"
    $multiPickerHandle = [IntPtr]$multiPicker.Current.NativeWindowHandle
    Assert ($multiPickerHandle -ne [IntPtr]::Zero) (
        "Multi-difficulty folder picker has no HWND.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsWindowEnabled($multiHandle)) (
        "Multi-difficulty folder picker did not disable its owner.")
    Assert (
        -not [LumaChartLibraryLauncherNative]::IsTopmost($multiHandle) -and
        -not [LumaChartLibraryLauncherNative]::IsTopmost($multiPickerHandle)) (
        "Multi-difficulty owner or folder picker is unexpectedly topmost.")
    $multiConfirm = Find-FolderDialogConfirmButton $multiPicker
    $multiPickerObservation = Observe-Element $multiPicker
    $multiConfirmObservation = Observe-Element $multiConfirm
    $multiPickerScreenshot = Capture-PhysicalWindow `
        $multiPickerHandle `
        (Join-Path $screenshots "25-multi-difficulty-native-folder-picker.png")
    $actions.Add((Invoke-UiaElement $multiConfirm))
    $multiTimeline = Find-VisibleElementById `
        -ProcessId $multiProcess.Id `
        -AutomationId "Timeline.Surface"
    $multiStatus = Find-VisibleElementById `
        -ProcessId $multiProcess.Id `
        -AutomationId "Editor.Status"
    Wait-Condition -Description "multi-difficulty WPF completion status" -Condition {
        [string]$multiStatus.Current.Name -ceq
            "已打开项目：Real Multi 中文 · 2 张谱面标签"
    }
    $multiTabCount = Get-VisibleElementCountById `
        -ProcessId $multiProcess.Id `
        -AutomationId "Editor.ChartTab"
    Assert ($multiTabCount -eq 2) (
        "Multi-difficulty scenario should expose exactly two editor tabs.")
    $multiEditorScreenshot = Capture-PhysicalWindow `
        $multiHandle `
        (Join-Path $screenshots "26-multi-difficulty-two-tabs.png")
    $multiCopiedAfter = @(
        $multiCopiedCharts |
            ForEach-Object { Get-Fingerprint $_.FullName })
    for ($index = 0; $index -lt $multiCopiedBefore.Count; $index++) {
        Assert (
            [string]$multiCopiedAfter[$index].sha256 -ceq
                [string]$multiCopiedBefore[$index].sha256 -and
            [long]$multiCopiedAfter[$index].bytes -eq
                [long]$multiCopiedBefore[$index].bytes) (
            "Multi-difficulty scenario modified copied chart $index.")
    }
    $scenarioResults.Add([ordered]@{
        scenario = "open-project-real-multi-difficulty"
        launcher = $multiOpenButtonObservation
        picker = [ordered]@{
            window = $multiPickerObservation
            confirm = $multiConfirmObservation
            ownerDisabled = $true
            selectedDirectory = $multiTarget
        }
        result = [ordered]@{
            timeline = Observe-Element $multiTimeline
            visibleTabCount = $multiTabCount
            status = Observe-Element $multiStatus
            summaries = $multiSummaries
            copiedChartsBefore = $multiCopiedBefore
            copiedChartsAfter = $multiCopiedAfter
        }
        screenshots = @(
            $multiPickerScreenshot,
            $multiEditorScreenshot)
        topmostAtEnd =
            [LumaChartLibraryLauncherNative]::IsTopmost($multiHandle)
    })
    $multiExitCode = Stop-LauncherScenario $activeScenario
    Assert ($multiExitCode -eq 0) (
        "Multi-difficulty scenario exited with $multiExitCode.")
    $activeScenario = $null

    $fixtureAfter = Get-Fingerprint $chartFixture
    $multiDifficultySourceAfter = @(
        $multiDifficultySourceCharts |
            ForEach-Object { Get-Fingerprint $_.FullName })
    $installerAfter = Get-Fingerprint $installer
    Assert (
        $fixtureAfter.sha256 -ceq $fixtureBefore.sha256 -and
        $fixtureAfter.bytes -eq $fixtureBefore.bytes) "Real MC fixture changed."
    Assert (
        $installerAfter.sha256 -ceq $installerBefore.sha256 -and
        $installerAfter.bytes -eq $installerBefore.bytes) "Frozen installer changed."
    for (
        $index = 0;
        $index -lt $multiDifficultySourceBefore.Count;
        $index++) {
        Assert (
            [string]$multiDifficultySourceAfter[$index].sha256 -ceq
                [string]$multiDifficultySourceBefore[$index].sha256 -and
            [long]$multiDifficultySourceAfter[$index].bytes -eq
                [long]$multiDifficultySourceBefore[$index].bytes) (
            "Real multi-difficulty source chart $index changed.")
    }
    Assert (
        @($scenarioResults | Where-Object { [bool]$_.topmostAtEnd }).Count -eq 0) (
        "A launcher scenario ended topmost.")
    $invokeActionCount = @(
        $actions |
            Where-Object {
                [string]$_.input -ceq "UI Automation InvokePattern"
            }).Count
    $valueActionCount = @(
        $actions |
            Where-Object {
                [string]$_.input -ceq
                    "UI Automation ValuePattern.SetValue"
            }).Count
    Assert (
        $actions.Count -eq 29 -and
        $invokeActionCount -eq 28 -and
        $valueActionCount -eq 1) (
        "Expected exactly twenty-eight InvokePattern actions and one ValuePattern action.")

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.library-launcher-gui.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        platform = "Windows Avalonia"
        buildMode = "ordinary .NET Release"
        applicationPath = $application
        scenarios = $scenarioResults
        actions = $actions
        setupActions = $script:setupActions
        immutable = [ordered]@{
            realMcBefore = $fixtureBefore
            realMcAfter = $fixtureAfter
            multiDifficultySourceBefore = $multiDifficultySourceBefore
            multiDifficultySourceAfter = $multiDifficultySourceAfter
            frozenInstallerBefore = $installerBefore
            frozenInstallerAfter = $installerAfter
        }
        safety = [ordered]@{
            userForegroundConsent = $true
            physicalWindowsMouseUsed = $false
            uiAutomationInvokePatternUsed = $true
            uiAutomationBusinessInvokeCount = $invokeActionCount
            uiAutomationValuePatternUsed = $true
            uiAutomationValueSetCount = $valueActionCount
            programmaticTextValueSet = $true
            inputInjectionUsed = $false
            setupActionCount = $script:setupActions.Count
            enterKeySent = $false
            textInputInjected = $false
            persistentTopmostUsed = $false
            userClientStopped = $false
            hardwareControlServiceStopped = $false
            productionServerDeployed = $false
            mobileProjectsTouched = $false
            protectionOrAotUsed = $false
            releaseInstallerOverwritten = $false
        }
    }
    $evidencePath = Join-Path $output "evidence.json"
    $evidence | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8
    Write-Output $evidencePath
}
finally {
    if ($permissionAclApplied -and
        $null -ne $permissionAclBefore -and
        -not [string]::IsNullOrWhiteSpace($permissionTarget) -and
        [IO.Directory]::Exists($permissionTarget)) {
        try {
            Set-Acl `
                -LiteralPath $permissionTarget `
                -AclObject $permissionAclBefore
        }
        catch { }
    }
    if ($null -ne $activeScenario) {
        try { [void](Stop-LauncherScenario $activeScenario) } catch { }
    }
}
