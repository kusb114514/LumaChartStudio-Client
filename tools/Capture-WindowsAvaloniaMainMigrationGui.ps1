param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$Mp3FixturePath = "D:\osu!\Songs\1005389 Minori Chihara - Michishirube\audio.mp3",
    [string]$FlacFixturePath = "D:\Documents\Image-Line\Downloads\FL Studio Mobile Factory Data\Loop Samples\Sliced Drums\LoopMasters AS House Loop.flac",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(60, 300)][int]$TimeoutSeconds = 210
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia main-migration GUI capture requires PowerShell Core on Windows."
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
        [int]$Seconds = $TimeoutSeconds,
        [int]$PollMilliseconds = 75
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try {
            if (& $Condition) { return }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartMainMigrationGuiNative
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
    public struct MONITORINFO
    {
        public int Size;
        public RECT Monitor;
        public RECT Work;
        public uint Flags;
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
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern bool IsWindowEnabled(IntPtr window);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    public static extern IntPtr GetWindowLongPtr(IntPtr window, int index);

    [DllImport("user32.dll")]
    public static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);

    [DllImport("user32.dll")]
    public static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
}
'@

function Convert-NativeHandle($Element) {
    $value = [int64]$Element.Current.NativeWindowHandle
    if ($value -lt 0) { $value += 0x100000000L }
    return [IntPtr]::new($value)
}

function Get-ProcessRoots([int]$ProcessId) {
    $condition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    return [Windows.Automation.AutomationElement]::RootElement.FindAll(
        [Windows.Automation.TreeScope]::Children,
        $condition)
}

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 300000)][int]$TimeoutMilliseconds = 10000
    )
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = Get-ProcessRoots $ProcessId
            foreach ($root in $roots) {
                if ([string]$root.Current.AutomationId -ceq $AutomationId) {
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
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Try-FindElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(50, 300000)][int]$TimeoutMilliseconds = 250
    )
    try {
        return Find-ElementById `
            -ProcessId $ProcessId `
            -AutomationId $AutomationId `
            -TimeoutMilliseconds $TimeoutMilliseconds
    }
    catch { return $null }
}

function Find-ElementByName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [ValidateRange(100, 300000)][int]$TimeoutMilliseconds = 10000
    )
    $nameCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty,
        $Name)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = Get-ProcessRoots $ProcessId
            foreach ($root in $roots) {
                if ([string]$root.Current.Name -ceq $Name) { return $root }
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

function Get-ElementValue($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose ValuePattern."
    }
    return ([Windows.Automation.ValuePattern]$pattern).Current.Value
}

function Set-ElementValue($Element, [string]$Value) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose ValuePattern."
    }
    ([Windows.Automation.ValuePattern]$pattern).SetValue($Value)
}

function Invoke-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Select-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose SelectionItemPattern."
    }
    ([Windows.Automation.SelectionItemPattern]$pattern).Select()
}

function Invoke-PhysicalClick {
    param(
        [Parameter(Mandatory = $true)]$Element,
        [Parameter(Mandatory = $true)][Diagnostics.Process]$Process
    )
    $rectangle = $Element.Current.BoundingRectangle
    if ($rectangle.IsEmpty -or
        $rectangle.Width -le 2 -or
        $rectangle.Height -le 2) {
        throw "Element '$($Element.Current.AutomationId)' has invalid bounds."
    }
    $Process.Refresh()
    $handle = $Process.MainWindowHandle
    if ($handle -ne [IntPtr]::Zero) {
        [void][LumaChartMainMigrationGuiNative]::BringWindowToTop($handle)
        [void][LumaChartMainMigrationGuiNative]::SetForegroundWindow($handle)
    }
    $x = [int][Math]::Round($rectangle.Left + $rectangle.Width / 2)
    $y = [int][Math]::Round($rectangle.Top + $rectangle.Height / 2)
    if (-not [LumaChartMainMigrationGuiNative]::SetCursorPos($x, $y)) {
        throw "SetCursorPos failed for '$($Element.Current.AutomationId)'."
    }
    Start-Sleep -Milliseconds 80
    [LumaChartMainMigrationGuiNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    [LumaChartMainMigrationGuiNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    $script:physicalActionCount++
    Start-Sleep -Milliseconds 100
}

function Send-PhysicalKey {
    param(
        [Parameter(Mandatory = $true)][Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][byte]$VirtualKey
    )
    $Process.Refresh()
    if ($Process.MainWindowHandle -eq [IntPtr]::Zero) {
        throw "Process $($Process.Id) has no foregroundable main window."
    }
    [void][LumaChartMainMigrationGuiNative]::BringWindowToTop($Process.MainWindowHandle)
    [void][LumaChartMainMigrationGuiNative]::SetForegroundWindow($Process.MainWindowHandle)
    Start-Sleep -Milliseconds 120
    [LumaChartMainMigrationGuiNative]::keybd_event(
        $VirtualKey, 0, 0, [UIntPtr]::Zero)
    [LumaChartMainMigrationGuiNative]::keybd_event(
        $VirtualKey, 0, 0x0002, [UIntPtr]::Zero)
    $script:physicalActionCount++
    Start-Sleep -Milliseconds 150
}

function Wait-MainWindowHandle([Diagnostics.Process]$Process) {
    Wait-Condition -Description "main window for process $($Process.Id)" -Condition {
        $Process.Refresh()
        -not $Process.HasExited -and
        $Process.MainWindowHandle -ne [IntPtr]::Zero
    }
    return $Process.MainWindowHandle
}

function Get-WindowBounds([IntPtr]$Handle) {
    $rectangle = [LumaChartMainMigrationGuiNative+RECT]::new()
    if (-not [LumaChartMainMigrationGuiNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    return [ordered]@{
        left = $rectangle.Left
        top = $rectangle.Top
        width = $rectangle.Right - $rectangle.Left
        height = $rectangle.Bottom - $rectangle.Top
    }
}

function Get-MonitorBounds([IntPtr]$Handle) {
    $monitor = [LumaChartMainMigrationGuiNative]::MonitorFromWindow($Handle, 2)
    if ($monitor -eq [IntPtr]::Zero) { throw "MonitorFromWindow failed." }
    $info = [LumaChartMainMigrationGuiNative+MONITORINFO]::new()
    $info.Size = [Runtime.InteropServices.Marshal]::SizeOf($info)
    if (-not [LumaChartMainMigrationGuiNative]::GetMonitorInfo(
            $monitor,
            [ref]$info)) {
        throw "GetMonitorInfo failed."
    }
    return [ordered]@{
        left = $info.Monitor.Left
        top = $info.Monitor.Top
        width = $info.Monitor.Right - $info.Monitor.Left
        height = $info.Monitor.Bottom - $info.Monitor.Top
    }
}

function Assert-FullscreenBounds($Actual, $Expected, [string]$Label) {
    foreach ($field in @("left", "top", "width", "height")) {
        if ([Math]::Abs([int]$Actual[$field] - [int]$Expected[$field]) -gt 2) {
            throw "$Label does not cover its monitor: actual=$($Actual | ConvertTo-Json -Compress), expected=$($Expected | ConvertTo-Json -Compress)."
        }
    }
}

function Get-WindowTopmost([IntPtr]$Handle) {
    $style = [LumaChartMainMigrationGuiNative]::GetWindowLongPtr(
        $Handle,
        -20).ToInt64()
    return ($style -band 0x8) -ne 0
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $bounds = Get-WindowBounds $Handle
    if ($bounds.width -lt 240 -or $bounds.height -lt 140) {
        throw "Window has invalid capture bounds: $($bounds.width)x$($bounds.height)."
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
                if (-not [LumaChartMainMigrationGuiNative]::PrintWindow(
                        $Handle,
                        $dc,
                        2)) {
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
                    [Math]::Min(
                        $bounds.width - 1,
                        [int](($x + .5) * $bounds.width / 16)),
                    [Math]::Min(
                        $bounds.height - 1,
                        [int](($y + .5) * $bounds.height / 16)))
                [void]$colors.Add($pixel.ToArgb())
            }
        }
        if ($colors.Count -lt 5) {
            throw "Screenshot is near-uniform: $($colors.Count) sampled colors."
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            path = $Path
            width = $bounds.width
            height = $bounds.height
            sampledUniqueColors = $colors.Count
        }
    }
    finally { $bitmap.Dispose() }
}

function Start-Client {
    param(
        [Parameter(Mandatory = $true)][string]$Profile,
        [Parameter(Mandatory = $true)][string]$ClientRoot,
        [string]$ChartPath = "",
        [string[]]$AdditionalArguments = @()
    )
    $localData = Join-Path $ClientRoot "local-data"
    $editing = Join-Path $ClientRoot "editing"
    $workspace = Join-Path $ClientRoot "workspace"
    foreach ($directory in @($localData, $editing, $workspace)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $applicationFullPath
    $start.UseShellExecute = $false
    $start.WorkingDirectory = Split-Path -Parent $applicationFullPath
    if (-not [string]::IsNullOrWhiteSpace($ChartPath)) {
        $start.ArgumentList.Add("--evidence-chart")
        $start.ArgumentList.Add($ChartPath)
    }
    foreach ($argument in $AdditionalArguments) {
        $start.ArgumentList.Add($argument)
    }
    $start.Environment["LUMACHART_PROFILE"] = $Profile
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localData
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
    $start.Environment["LUMACHART_ONLINE_ENDPOINT"] = "http://127.0.0.1:1"
    $start.Environment["DOTNET_CLI_HOME"] = $dotnetHome
    $start.Environment["NUGET_PACKAGES"] = $nugetPackages
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
    $start.Environment["TEMP"] = $projectTemp
    $start.Environment["TMP"] = $projectTemp
    $process = [Diagnostics.Process]::Start($start)
    if (-not $process) { throw "Unable to start Windows Avalonia client." }
    return $process
}

function Stop-TrackedClient([Diagnostics.Process]$Process) {
    if (-not $Process -or $Process.HasExited) { return }
    [void]$Process.CloseMainWindow()
    if (-not $Process.WaitForExit(10000)) {
        $Process.Kill($true)
        [void]$Process.WaitForExit(5000)
    }
}

function Submit-NativeOpenPicker {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $dialog = Find-ElementByName `
        -ProcessId $ProcessId `
        -Name $Title `
        -TimeoutMilliseconds 15000
    $handle = Convert-NativeHandle $dialog
    if ($handle -eq [IntPtr]::Zero) {
        throw "Native Open picker '$Title' has no window handle."
    }
    $edit = $null
    $hostCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        "FileNameControlHost")
    $fileNameHost = $dialog.FindFirst(
        [Windows.Automation.TreeScope]::Descendants,
        $hostCondition)
    if ($fileNameHost) {
        $legacyEditCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty,
            "1001")
        $edit = $fileNameHost.FindFirst(
            [Windows.Automation.TreeScope]::Descendants,
            $legacyEditCondition)
    }
    if (-not $edit) {
        $modernEditCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty,
            "1148")
        $matches = $dialog.FindAll(
            [Windows.Automation.TreeScope]::Descendants,
            $modernEditCondition)
        for ($index = 0; $index -lt $matches.Count; $index++) {
            $candidate = $matches.Item($index)
            $pattern = $null
            if ($candidate.Current.IsEnabled -and
                $candidate.Current.ControlType -eq
                    [Windows.Automation.ControlType]::Edit -and
                $candidate.TryGetCurrentPattern(
                    [Windows.Automation.ValuePattern]::Pattern,
                    [ref]$pattern)) {
                $edit = $candidate
                break
            }
        }
    }
    if (-not $edit) {
        throw "Native Open picker '$Title' did not expose an editable filename child."
    }
    Set-ElementValue $edit $Path
    $button = $null
    foreach ($id in @("1", "CommandButton_1")) {
        $condition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty,
            $id)
        $candidate = $dialog.FindFirst(
            [Windows.Automation.TreeScope]::Descendants,
            $condition)
        if ($candidate) {
            $button = $candidate
            break
        }
    }
    if (-not $button) {
        throw "Native Open picker '$Title' did not expose its Open button."
    }
    Invoke-Element $button
    return [ordered]@{
        title = $Title
        nativeWindowHandle = $handle.ToInt64()
        fileNameAutomationId = [string]$edit.Current.AutomationId
        submittedPath = $Path
        submission = "ValuePattern + explicit native Open button"
    }
}

function Find-ChartTabByPath {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$ChartPath,
        [int]$Seconds = 30
    )
    $full = [IO.Path]::GetFullPath($ChartPath)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        "Editor.ChartTab")
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try {
            $roots = Get-ProcessRoots $ProcessId
            foreach ($root in $roots) {
                $matches = $root.FindAll(
                    [Windows.Automation.TreeScope]::Descendants,
                    $idCondition)
                for ($index = 0; $index -lt $matches.Count; $index++) {
                    $candidate = $matches.Item($index)
                    $help = [string]$candidate.Current.HelpText
                    $bounds = $candidate.Current.BoundingRectangle
                    if ($help.StartsWith(
                            $full,
                            [StringComparison]::OrdinalIgnoreCase) -and
                        -not $bounds.IsEmpty -and
                        $bounds.Width -gt 2 -and
                        $bounds.Height -gt 2) {
                        return $candidate
                    }
                }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding chart tab for '$full'."
}

function Invoke-ChartTabByPath {
    param(
        [Parameter(Mandatory = $true)][Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][string]$ChartPath,
        [int]$Seconds = 30
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try {
            $candidate = Find-ChartTabByPath `
                -ProcessId $Process.Id `
                -ChartPath $ChartPath `
                -Seconds 3
            Invoke-PhysicalClick -Element $candidate -Process $Process
            return
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        catch {
            if (-not $_.Exception.Message.Contains(
                    "has invalid bounds",
                    [StringComparison]::Ordinal) -and
                -not $_.Exception.Message.Contains(
                    "Timed out finding chart tab",
                    [StringComparison]::Ordinal)) {
                throw
            }
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out physically activating chart tab '$ChartPath'."
}

function Get-TextDescendants($Element) {
    $textCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ControlTypeProperty,
        [Windows.Automation.ControlType]::Text)
    $texts = $Element.FindAll(
        [Windows.Automation.TreeScope]::Descendants,
        $textCondition)
    return @(
        for ($index = 0; $index -lt $texts.Count; $index++) {
            $name = [string]$texts.Item($index).Current.Name
            if (-not [string]::IsNullOrWhiteSpace($name)) { $name }
        }
    )
}

function Wait-AudioOperationComplete {
    param(
        [Parameter(Mandatory = $true)][Diagnostics.Process]$Process,
        [int]$Seconds = $TimeoutSeconds
    )
    $script:audioCompletionStatus = ""
    Wait-Condition -Description "audio import and automatic BPM boundary" -Seconds $Seconds -Condition {
        $single = Try-FindElementById `
            -ProcessId $Process.Id `
            -AutomationId "Tempo.SingleResultDialog" `
            -TimeoutMilliseconds 120
        if ($single) {
            Invoke-PhysicalClick `
                -Element (Find-ElementById `
                    -ProcessId $Process.Id `
                    -AutomationId "Tempo.SingleCancel") `
                -Process $Process
            return $false
        }
        $select = Try-FindElementById `
            -ProcessId $Process.Id `
            -AutomationId "Metadata.AudioSelect" `
            -TimeoutMilliseconds 120
        $status = Try-FindElementById `
            -ProcessId $Process.Id `
            -AutomationId "Metadata.AudioAnalysisStatus" `
            -TimeoutMilliseconds 120
        if ($select -and $select.Current.IsEnabled -and $status) {
            $name = [string]$status.Current.Name
            if ($name -notlike "正在*") {
                $script:audioCompletionStatus = $name
                return $true
            }
        }
        return $false
    }
    $result = $script:audioCompletionStatus
    $script:audioCompletionStatus = ""
    return $result
}

function Find-WorkingChart([string]$EditingRoot) {
    $matches = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $EditingRoot "desktop-workspace\documents") `
            -Recurse `
            -File `
            -ErrorAction Stop |
        Where-Object { $_.Name -like "working.*" }
    )
    if ($matches.Count -ne 1) {
        throw "Expected one working chart beneath '$EditingRoot'; found $($matches.Count)."
    }
    return $matches[0].FullName
}

function Find-FileRecursively([string]$Root, [string]$Name) {
    $matches = @(
        Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $Name -ErrorAction Stop
    )
    if ($matches.Count -ne 1) {
        throw "Expected one '$Name' beneath '$Root'; found $($matches.Count)."
    }
    return $matches[0].FullName
}

function Read-Prefix([string]$Path, [int]$Count = 4) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $buffer = New-Object byte[] $Count
        $read = $stream.Read($buffer, 0, $Count)
        if ($read -ne $Count) { throw "File is shorter than $Count bytes: $Path" }
        return [Convert]::ToHexString($buffer)
    }
    finally { $stream.Dispose() }
}

function New-GeneratedAudioFixtures([string]$Root) {
    $applicationDirectory = Split-Path -Parent $applicationFullPath
    [Reflection.Assembly]::LoadFrom(
        (Join-Path $applicationDirectory "NAudio.Core.dll")) | Out-Null
    [Reflection.Assembly]::LoadFrom(
        (Join-Path $applicationDirectory "NAudio.Wasapi.dll")) | Out-Null
    $wav = Join-Path $Root "format-wav.wav"
    $format = [NAudio.Wave.WaveFormat]::new(44100, 16, 2)
    $writer = [NAudio.Wave.WaveFileWriter]::new($wav, $format)
    try {
        $sampleFrames = 44100 * 9
        $samples = New-Object "System.Int16[]" ($sampleFrames * 2)
        for ($index = 0; $index -lt $sampleFrames; $index++) {
            $value = [int16][Math]::Round(
                [Math]::Sin(2 * [Math]::PI * 440 * $index / 44100) * 9000)
            $samples[$index * 2] = $value
            $samples[$index * 2 + 1] = $value
        }
        $writer.WriteSamples($samples, 0, $samples.Length)
    }
    finally { $writer.Dispose() }

    [NAudio.MediaFoundation.MediaFoundationApi]::Startup()
    try {
        $m4a = Join-Path $Root "format-m4a.m4a"
        $reader = [NAudio.Wave.WaveFileReader]::new($wav)
        try {
            [NAudio.Wave.MediaFoundationEncoder]::EncodeToAac(
                $reader,
                $m4a,
                128000)
        }
        finally { $reader.Dispose() }

        $aac = Join-Path $Root "format-aac.aac"
        $reader = [NAudio.Wave.WaveFileReader]::new($wav)
        try {
            $types = [NAudio.Wave.MediaFoundationEncoder]::GetOutputMediaTypes(
                [NAudio.MediaFoundation.AudioSubtypes]::MFAudioFormat_AAC)
            $mediaType = $types |
                Where-Object {
                    $_.SampleRate -eq 44100 -and
                    $_.ChannelCount -eq 2
                } |
                Sort-Object AverageBytesPerSecond |
                Select-Object -Last 1
            if (-not $mediaType) { throw "Windows Media Foundation exposes no stereo AAC encoder." }
            $encoder = [NAudio.Wave.MediaFoundationEncoder]::new($mediaType)
            try {
                $stream = [IO.File]::Create($aac)
                try {
                    $encoder.Encode(
                        $stream,
                        $reader,
                        [NAudio.MediaFoundation.TranscodeContainerTypes]::MFTranscodeContainerType_ADTS)
                }
                finally { $stream.Dispose() }
            }
            finally { $encoder.Dispose() }
        }
        finally { $reader.Dispose() }
    }
    finally {
        [NAudio.MediaFoundation.MediaFoundationApi]::Shutdown()
    }

    return [ordered]@{ wav = $wav; m4a = $m4a; aac = $aac }
}

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$chartFixtureFullPath = Resolve-ExistingFile $ChartFixturePath "Real MC fixture"
$mp3FixtureFullPath = Resolve-ExistingFile $Mp3FixturePath "Real MP3 fixture"
$flacFixtureFullPath = Resolve-ExistingFile $FlacFixturePath "Real FLAC fixture"
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
if (-not (Test-Path -LiteralPath $outputFullPath -PathType Container)) {
    throw "Output root must already exist: $outputFullPath"
}
$guiRoot = Join-Path $outputFullPath "main-migration-gui"
if (Test-Path -LiteralPath $guiRoot) {
    throw "GUI output root already exists: $guiRoot"
}

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$projectTemp = Join-Path $projectRoot ".codex-temp"
$dotnetHome = Join-Path $projectRoot ".codex-dotnet-home"
$nugetPackages = Join-Path $projectRoot ".codex-nuget-packages"
$nugetHttpCache = Join-Path $projectRoot ".codex-nuget-http-cache"
$fixturesRoot = Join-Path $guiRoot "fixtures"
$chartsRoot = Join-Path $guiRoot "charts"
$clientsRoot = Join-Path $guiRoot "clients"
$screenshotsRoot = Join-Path $guiRoot "screenshots"
foreach ($directory in @(
        $guiRoot,
        $fixturesRoot,
        $chartsRoot,
        $clientsRoot,
        $screenshotsRoot,
        $projectTemp,
        $dotnetHome,
        $nugetPackages,
        $nugetHttpCache)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$generated = New-GeneratedAudioFixtures $fixturesRoot
$formatMp3 = Join-Path $fixturesRoot "format-mp3.mp3"
$formatFlac = Join-Path $fixturesRoot "format-flac.flac"
Copy-Item -LiteralPath $mp3FixtureFullPath -Destination $formatMp3
Copy-Item -LiteralPath $flacFixtureFullPath -Destination $formatFlac
$brokenM4a = Join-Path $fixturesRoot "broken-codec.m4a"
[IO.File]::WriteAllBytes(
    $brokenM4a,
    [byte[]](0x62, 0x72, 0x6F, 0x6B, 0x65, 0x6E, 0x00, 0xFF))

$formatInputs = [ordered]@{
    mp3 = $formatMp3
    wav = $generated.wav
    flac = $formatFlac
    m4a = $generated.m4a
    aac = $generated.aac
}
$fixtureHashesBefore = [ordered]@{
    chart = (Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash
    sourceMp3 = (Get-FileHash -LiteralPath $mp3FixtureFullPath -Algorithm SHA256).Hash
    sourceFlac = (Get-FileHash -LiteralPath $flacFixtureFullPath -Algorithm SHA256).Hash
}
foreach ($key in @($formatInputs.Keys)) {
    $fixtureHashesBefore["generated_$key"] =
        (Get-FileHash -LiteralPath $formatInputs[$key] -Algorithm SHA256).Hash
}

$formatChart = Join-Path $chartsRoot "format-matrix.mc"
$secondChart = Join-Path $chartsRoot "tab-change-second.mc"
$revokeChart = Join-Path $chartsRoot "permission-revoke.mc"
$persistChart = Join-Path $chartsRoot "persist-failure.mc"
$fullscreenChart = Join-Path $chartsRoot "fullscreen-playtest.mc"
foreach ($path in @(
        $formatChart,
        $secondChart,
        $revokeChart,
        $persistChart,
        $fullscreenChart)) {
    Copy-Item -LiteralPath $chartFixtureFullPath -Destination $path
}

$script:physicalActionCount = 0
$tracked = [Collections.Generic.List[Diagnostics.Process]]::new()
$lockStream = $null
$captures = [ordered]@{}
$formatResults = [ordered]@{}
$pickerRecords = [Collections.Generic.List[object]]::new()
$audioClient = $null
$tabClient = $null
$revokeClient = $null
$recoveryClient = $null
$persistClient = $null
$fullscreenClient = $null

try {
    # Valid MP3/WAV/FLAC/M4A/AAC conversion and codec failure.
    $audioClientRoot = Join-Path $clientsRoot "audio"
    $audioClient = Start-Client `
        -Profile "main-migration-audio" `
        -ClientRoot $audioClientRoot `
        -ChartPath $formatChart
    $tracked.Add($audioClient)
    $audioMain = Wait-MainWindowHandle $audioClient
    [void][LumaChartMainMigrationGuiNative]::ShowWindow($audioMain, 3)
    Select-Element (Find-ElementById `
        -ProcessId $audioClient.Id `
        -AutomationId "Inspector.MetadataTab" `
        -TimeoutMilliseconds 30000)

    foreach ($formatName in @("mp3", "wav", "flac", "m4a", "aac")) {
        $inputPath = [string]$formatInputs[$formatName]
        $expectedReference = "format-$formatName.ogg"
        Invoke-PhysicalClick `
            -Element (Find-ElementById `
                -ProcessId $audioClient.Id `
                -AutomationId "Metadata.AudioSelect") `
            -Process $audioClient
        $pickerRecords.Add((Submit-NativeOpenPicker `
            -ProcessId $audioClient.Id `
            -Title "选择音乐" `
            -Path $inputPath))
        [void](Find-ElementById `
            -ProcessId $audioClient.Id `
            -AutomationId "AudioImport.ModeDialog" `
            -TimeoutMilliseconds 15000)
        Invoke-PhysicalClick `
            -Element (Find-ElementById `
                -ProcessId $audioClient.Id `
                -AutomationId "AudioImport.ConvertToOgg") `
            -Process $audioClient
        Wait-Condition -Description "$formatName converted audio reference" -Seconds 180 -Condition {
            $value = Get-ElementValue (Find-ElementById `
                -ProcessId $audioClient.Id `
                -AutomationId "Metadata.AudioFile" `
                -TimeoutMilliseconds 500)
            $value -ceq $expectedReference
        }
        $status = Wait-AudioOperationComplete -Process $audioClient -Seconds 200
        $convertedPath = Find-FileRecursively `
            -Root (Join-Path $audioClientRoot "editing") `
            -Name $expectedReference
        $prefix = Read-Prefix $convertedPath
        if ($prefix -cne "4F676753") {
            throw "$formatName conversion did not produce an Ogg stream: $prefix."
        }
        $scratchCount = @(
            Get-ChildItem `
                -LiteralPath (Join-Path $audioClientRoot "editing") `
                -Recurse `
                -File `
                -Filter ".luma-audio-import-*" `
                -ErrorAction SilentlyContinue
        ).Count
        if ($scratchCount -ne 0) {
            throw "$formatName conversion left $scratchCount audio scratch files."
        }
        $formatResults[$formatName] = [ordered]@{
            sourcePath = $inputPath
            sourceLength = (Get-Item -LiteralPath $inputPath).Length
            sourceSha256 = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash
            finalReference = $expectedReference
            convertedPath = $convertedPath
            convertedLength = (Get-Item -LiteralPath $convertedPath).Length
            convertedSha256 = (Get-FileHash -LiteralPath $convertedPath -Algorithm SHA256).Hash
            convertedPrefix = $prefix
            automaticTempoBoundary = $status
            scratchCount = 0
        }
    }

    $captures.audioFormatMatrix = Capture-Window `
        $audioMain `
        (Join-Path $screenshotsRoot "audio-format-matrix.png")

    $referenceBeforeFailure = Get-ElementValue (Find-ElementById `
        -ProcessId $audioClient.Id `
        -AutomationId "Metadata.AudioFile")
    Invoke-PhysicalClick `
        -Element (Find-ElementById `
            -ProcessId $audioClient.Id `
            -AutomationId "Metadata.AudioSelect") `
        -Process $audioClient
    $pickerRecords.Add((Submit-NativeOpenPicker `
        -ProcessId $audioClient.Id `
        -Title "选择音乐" `
        -Path $brokenM4a))
    Invoke-PhysicalClick `
        -Element (Find-ElementById `
            -ProcessId $audioClient.Id `
            -AutomationId "AudioImport.ConvertToOgg" `
            -TimeoutMilliseconds 15000) `
        -Process $audioClient
    Wait-Condition -Description "damaged codec failure status" -Seconds 60 -Condition {
        $status = Find-ElementById `
            -ProcessId $audioClient.Id `
            -AutomationId "Metadata.AudioAnalysisStatus" `
            -TimeoutMilliseconds 500
        ([string]$status.Current.Name).StartsWith(
            "无法导入音频：",
            [StringComparison]::Ordinal)
    }
    $codecFailureStatus = [string](Find-ElementById `
        -ProcessId $audioClient.Id `
        -AutomationId "Metadata.AudioAnalysisStatus").Current.Name
    $referenceAfterFailure = Get-ElementValue (Find-ElementById `
        -ProcessId $audioClient.Id `
        -AutomationId "Metadata.AudioFile")
    if ($referenceAfterFailure -cne $referenceBeforeFailure) {
        throw "Damaged codec changed the current audio reference."
    }
    if (Get-ChildItem `
            -LiteralPath (Join-Path $audioClientRoot "editing") `
            -Recurse `
            -File `
            -Filter "broken-codec*.ogg" `
            -ErrorAction SilentlyContinue) {
        throw "Damaged codec left an imported OGG."
    }
    $captures.codecFailure = Capture-Window `
        $audioMain `
        (Join-Path $screenshotsRoot "audio-codec-failure.png")
    Stop-TrackedClient $audioClient
    $tracked.Remove($audioClient) | Out-Null
    $audioClient = $null

    # A tab switch while a real MP3 is still transcoding must cancel the
    # transaction and remove its created asset. Both real MC copies are opened
    # at evidence startup because Editor.Open is not materialized in this
    # production editor layout.
    $tabClientRoot = Join-Path $clientsRoot "tab-change"
    $tabClient = Start-Client `
        -Profile "main-migration-tab-change" `
        -ClientRoot $tabClientRoot `
        -ChartPath $formatChart `
        -AdditionalArguments @(
            "--evidence-second-chart",
            $secondChart,
            "--evidence-audio-pre-commit-delay-ms",
            "4000")
    $tracked.Add($tabClient)
    $tabMain = Wait-MainWindowHandle $tabClient
    [void][LumaChartMainMigrationGuiNative]::ShowWindow($tabMain, 3)
    Invoke-ChartTabByPath -Process $tabClient -ChartPath $secondChart
    Select-Element (Find-ElementById `
        -ProcessId $tabClient.Id `
        -AutomationId "Inspector.MetadataTab")
    $tabReferenceBefore = Get-ElementValue (Find-ElementById `
        -ProcessId $tabClient.Id `
        -AutomationId "Metadata.AudioFile")
    $tabChangeInput = Join-Path $fixturesRoot "tab-change-real.mp3"
    Copy-Item -LiteralPath $mp3FixtureFullPath -Destination $tabChangeInput
    Invoke-PhysicalClick `
        -Element (Find-ElementById `
            -ProcessId $tabClient.Id `
            -AutomationId "Metadata.AudioSelect") `
        -Process $tabClient
    $pickerRecords.Add((Submit-NativeOpenPicker `
        -ProcessId $tabClient.Id `
        -Title "选择音乐" `
        -Path $tabChangeInput))
    Invoke-PhysicalClick `
        -Element (Find-ElementById `
            -ProcessId $tabClient.Id `
            -AutomationId "AudioImport.ConvertToOgg" `
            -TimeoutMilliseconds 15000) `
        -Process $tabClient
    Invoke-ChartTabByPath -Process $tabClient -ChartPath $formatChart
    Wait-Condition -Description "tab-change import cancellation" -Seconds 180 -Condition {
        $select = Try-FindElementById `
            -ProcessId $tabClient.Id `
            -AutomationId "Metadata.AudioSelect" `
            -TimeoutMilliseconds 200
        $select -and $select.Current.IsEnabled
    }
    Invoke-ChartTabByPath -Process $tabClient -ChartPath $secondChart
    Select-Element (Find-ElementById `
        -ProcessId $tabClient.Id `
        -AutomationId "Inspector.MetadataTab")
    $tabReferenceAfter = Get-ElementValue (Find-ElementById `
        -ProcessId $tabClient.Id `
        -AutomationId "Metadata.AudioFile")
    if ($tabReferenceAfter -cne $tabReferenceBefore) {
        throw "Tab-change cancellation changed the second chart audio reference."
    }
    if (Get-ChildItem `
            -LiteralPath (Join-Path $tabClientRoot "editing") `
            -Recurse `
            -File `
            -Filter "tab-change-real*.ogg" `
            -ErrorAction SilentlyContinue) {
        throw "Tab-change cancellation left an imported OGG."
    }
    $tabChangeStatus = [string](Find-ElementById `
        -ProcessId $tabClient.Id `
        -AutomationId "Metadata.AudioAnalysisStatus").Current.Name
    $captures.tabChange = Capture-Window `
        $tabMain `
        (Join-Path $screenshotsRoot "audio-tab-change-canceled.png")
    Stop-TrackedClient $tabClient
    $tracked.Remove($tabClient) | Out-Null
    $tabClient = $null

    # Evidence-scoped late permission revocation exercises the same session
    # permission that the online coordinator updates, without entering a room.
    $revokeClientRoot = Join-Path $clientsRoot "permission-revoke"
    $revokeClient = Start-Client `
        -Profile "main-migration-permission-revoke" `
        -ClientRoot $revokeClientRoot `
        -ChartPath $revokeChart `
        -AdditionalArguments @(
            "--evidence-audio-permission-revoke-delay-ms",
            "100")
    $tracked.Add($revokeClient)
    $revokeMain = Wait-MainWindowHandle $revokeClient
    [void][LumaChartMainMigrationGuiNative]::ShowWindow($revokeMain, 3)
    Select-Element (Find-ElementById `
        -ProcessId $revokeClient.Id `
        -AutomationId "Inspector.MetadataTab" `
        -TimeoutMilliseconds 30000)
    $revokeReferenceBefore = Get-ElementValue (Find-ElementById `
        -ProcessId $revokeClient.Id `
        -AutomationId "Metadata.AudioFile")
    $revokeInput = Join-Path $fixturesRoot "permission-revoke-real.mp3"
    Copy-Item -LiteralPath $mp3FixtureFullPath -Destination $revokeInput
    Invoke-PhysicalClick `
        -Element (Find-ElementById `
            -ProcessId $revokeClient.Id `
            -AutomationId "Metadata.AudioSelect") `
        -Process $revokeClient
    $pickerRecords.Add((Submit-NativeOpenPicker `
        -ProcessId $revokeClient.Id `
        -Title "选择音乐" `
        -Path $revokeInput))
    Invoke-PhysicalClick `
        -Element (Find-ElementById `
            -ProcessId $revokeClient.Id `
            -AutomationId "AudioImport.ConvertToOgg" `
            -TimeoutMilliseconds 15000) `
        -Process $revokeClient
    Wait-Condition -Description "late audio permission denial" -Seconds 180 -Condition {
        $status = Try-FindElementById `
            -ProcessId $revokeClient.Id `
            -AutomationId "Metadata.AudioAnalysisStatus" `
            -TimeoutMilliseconds 250
        $status -and
        ([string]$status.Current.Name).Contains(
            "权限",
            [StringComparison]::Ordinal)
    }
    $revokeStatus = [string](Find-ElementById `
        -ProcessId $revokeClient.Id `
        -AutomationId "Metadata.AudioAnalysisStatus").Current.Name
    $revokeReferenceAfter = Get-ElementValue (Find-ElementById `
        -ProcessId $revokeClient.Id `
        -AutomationId "Metadata.AudioFile")
    if ($revokeReferenceAfter -cne $revokeReferenceBefore) {
        throw "Late permission revocation changed the audio reference."
    }
    if (Get-ChildItem `
            -LiteralPath (Join-Path $revokeClientRoot "editing") `
            -Recurse `
            -File `
            -Filter "permission-revoke-real*.ogg" `
            -ErrorAction SilentlyContinue) {
        throw "Late permission revocation left an imported OGG."
    }
    $captures.permissionRevoked = Capture-Window `
        $revokeMain `
        (Join-Path $screenshotsRoot "audio-permission-revoked.png")
    Stop-TrackedClient $revokeClient
    $tracked.Remove($revokeClient) | Out-Null
    $revokeClient = $null

    # Corrupt manifest recovery must be owner-modal, bounded, non-topmost, and
    # explicit about not overwriting readable sources.
    $recoveryClientRoot = Join-Path $clientsRoot "recovery-warning"
    $recoveryEditing = Join-Path $recoveryClientRoot "editing\desktop-workspace"
    New-Item -ItemType Directory -Force -Path $recoveryEditing | Out-Null
    $recoveryManifest = Join-Path $recoveryEditing "workspace.json"
    [IO.File]::WriteAllBytes(
        $recoveryManifest,
        [Text.Encoding]::UTF8.GetBytes("{ invalid workspace manifest"))
    $recoveryClient = Start-Client `
        -Profile "main-migration-recovery-warning" `
        -ClientRoot $recoveryClientRoot `
        -AdditionalArguments @("--evidence-focus-library-launcher")
    $tracked.Add($recoveryClient)
    $recoveryDialog = Find-ElementByName `
        -ProcessId $recoveryClient.Id `
        -Name "工作区恢复提示" `
        -TimeoutMilliseconds 30000
    $recoveryHandle = Convert-NativeHandle $recoveryDialog
    if ($recoveryHandle -eq [IntPtr]::Zero) {
        throw "Workspace recovery warning has no native handle."
    }
    $recoveryText = (Get-TextDescendants $recoveryDialog) -join "`n"
    foreach ($expected in @(
            "工作区已尽可能恢复",
            "Workspace manifest was ignored",
            "不会用这些缓存静默覆盖可读取的源谱面",
            "另存为")) {
        if (-not $recoveryText.Contains($expected, [StringComparison]::Ordinal)) {
            throw "Workspace recovery warning is missing '$expected'."
        }
    }
    if (Get-WindowTopmost $recoveryHandle) {
        throw "Workspace recovery warning unexpectedly uses the topmost style."
    }
    $captures.recoveryWarning = Capture-Window `
        $recoveryHandle `
        (Join-Path $screenshotsRoot "workspace-recovery-warning.png")
    $ok = $null
    foreach ($id in @("1", "2")) {
        $condition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty,
            $id)
        $candidate = $recoveryDialog.FindFirst(
            [Windows.Automation.TreeScope]::Descendants,
            $condition)
        if ($candidate) {
            $ok = $candidate
            break
        }
    }
    if (-not $ok) {
        $buttonCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::ControlTypeProperty,
            [Windows.Automation.ControlType]::Button)
        $ok = $recoveryDialog.FindFirst(
            [Windows.Automation.TreeScope]::Descendants,
            $buttonCondition)
    }
    if (-not $ok) { throw "Workspace recovery warning has no acknowledgement button." }
    Invoke-Element $ok
    Wait-Condition -Description "workspace recovery warning dismissal" -Seconds 15 -Condition {
        try {
            $roots = Get-ProcessRoots $recoveryClient.Id
            -not ($roots | Where-Object {
                [string]$_.Current.Name -ceq "工作区恢复提示"
            })
        }
        catch { $false }
    }
    Stop-TrackedClient $recoveryClient
    $tracked.Remove($recoveryClient) | Out-Null
    $recoveryClient = $null

    # A locked working cache makes PersistAsync fail. Playtest must remain
    # closed and present an owner-modal error without touching the source.
    $persistClientRoot = Join-Path $clientsRoot "persist-failure"
    $persistClient = Start-Client `
        -Profile "main-migration-persist-failure" `
        -ClientRoot $persistClientRoot `
        -ChartPath $persistChart
    $tracked.Add($persistClient)
    $persistMain = Wait-MainWindowHandle $persistClient
    [void][LumaChartMainMigrationGuiNative]::ShowWindow($persistMain, 3)
    Invoke-PhysicalClick `
        -Element (Find-ElementById `
            -ProcessId $persistClient.Id `
            -AutomationId "Editor.CommandMenuToggle" `
            -TimeoutMilliseconds 30000) `
        -Process $persistClient
    [void](Find-ElementById `
        -ProcessId $persistClient.Id `
        -AutomationId "Editor.Playtest.FromStart" `
        -TimeoutMilliseconds 30000)
    $workingChart = Find-WorkingChart (Join-Path $persistClientRoot "editing")
    $workingHashBeforeLock =
        (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash
    $lockStream = [IO.File]::Open(
        $workingChart,
        [IO.FileMode]::Open,
        [IO.FileAccess]::ReadWrite,
        [IO.FileShare]::None)
    Invoke-PhysicalClick `
        -Element (Find-ElementById `
            -ProcessId $persistClient.Id `
            -AutomationId "Editor.Playtest.FromStart") `
        -Process $persistClient
    $persistDialog = Find-ElementById `
        -ProcessId $persistClient.Id `
        -AutomationId "Settings.ActionDialog" `
        -TimeoutMilliseconds 30000
    $persistDialogHandle = Convert-NativeHandle $persistDialog
    $persistMessage = [string](Find-ElementById `
        -ProcessId $persistClient.Id `
        -AutomationId "Settings.ActionDialog.Message").Current.Name
    if (-not $persistMessage.Contains(
            "工作区缓存写入失败",
            [StringComparison]::Ordinal)) {
        throw "Playtest persistence failure did not expose the cache-write error."
    }
    if (Try-FindElementById `
            -ProcessId $persistClient.Id `
            -AutomationId "Playtest.Dialog" `
            -TimeoutMilliseconds 250) {
        throw "Playtest opened despite a failed working-cache persistence."
    }
    if (Get-WindowTopmost $persistDialogHandle) {
        throw "Playtest persistence error unexpectedly uses the topmost style."
    }
    $captures.persistFailure = Capture-Window `
        $persistDialogHandle `
        (Join-Path $screenshotsRoot "workspace-persist-failure.png")
    Invoke-PhysicalClick `
        -Element (Find-ElementById `
            -ProcessId $persistClient.Id `
            -AutomationId "Settings.ActionDialog.Primary") `
        -Process $persistClient
    $lockStream.Dispose()
    $lockStream = $null
    $workingHashAfterFailure =
        (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash
    if ($workingHashAfterFailure -cne $workingHashBeforeLock) {
        throw "Failed persistence changed the locked working chart."
    }
    Stop-TrackedClient $persistClient
    $tracked.Remove($persistClient) | Out-Null
    $persistClient = $null

    # Main-window F11 is the sole fullscreen command. A Playtest opened from
    # that state must inherit the same monitor-covering bounds.
    $fullscreenClientRoot = Join-Path $clientsRoot "fullscreen"
    $fullscreenClient = Start-Client `
        -Profile "main-migration-fullscreen" `
        -ClientRoot $fullscreenClientRoot `
        -ChartPath $fullscreenChart
    $tracked.Add($fullscreenClient)
    $fullscreenMain = Wait-MainWindowHandle $fullscreenClient
    [void][LumaChartMainMigrationGuiNative]::ShowWindow($fullscreenMain, 9)
    $monitorBounds = Get-MonitorBounds $fullscreenMain
    Send-PhysicalKey -Process $fullscreenClient -VirtualKey 0x7A
    Wait-Condition -Description "main-window F11 fullscreen" -Seconds 20 -Condition {
        try {
            $actual = Get-WindowBounds $fullscreenMain
            [Math]::Abs($actual.left - $monitorBounds.left) -le 2 -and
            [Math]::Abs($actual.top - $monitorBounds.top) -le 2 -and
            [Math]::Abs($actual.width - $monitorBounds.width) -le 2 -and
            [Math]::Abs($actual.height - $monitorBounds.height) -le 2
        }
        catch { $false }
    }
    $mainFullscreenBounds = Get-WindowBounds $fullscreenMain
    Assert-FullscreenBounds $mainFullscreenBounds $monitorBounds "Main window"
    Invoke-PhysicalClick `
        -Element (Find-ElementById `
            -ProcessId $fullscreenClient.Id `
            -AutomationId "Editor.CommandMenuToggle") `
        -Process $fullscreenClient
    Invoke-PhysicalClick `
        -Element (Find-ElementById `
            -ProcessId $fullscreenClient.Id `
            -AutomationId "Editor.Playtest.FromStart") `
        -Process $fullscreenClient
    $playtest = Find-ElementById `
        -ProcessId $fullscreenClient.Id `
        -AutomationId "Playtest.Dialog" `
        -TimeoutMilliseconds 30000
    $playtestHandle = Convert-NativeHandle $playtest
    Wait-Condition -Description "Playtest inherited fullscreen" -Seconds 20 -Condition {
        try {
            $actual = Get-WindowBounds $playtestHandle
            [Math]::Abs($actual.left - $monitorBounds.left) -le 2 -and
            [Math]::Abs($actual.top - $monitorBounds.top) -le 2 -and
            [Math]::Abs($actual.width - $monitorBounds.width) -le 2 -and
            [Math]::Abs($actual.height - $monitorBounds.height) -le 2
        }
        catch { $false }
    }
    $playtestFullscreenBounds = Get-WindowBounds $playtestHandle
    Assert-FullscreenBounds `
        $playtestFullscreenBounds `
        $monitorBounds `
        "Playtest window"
    if (Get-WindowTopmost $playtestHandle) {
        throw "Inherited-fullscreen Playtest unexpectedly uses the topmost style."
    }
    $captures.playtestFullscreen = Capture-Window `
        $playtestHandle `
        (Join-Path $screenshotsRoot "playtest-fullscreen-inherited.png")
    Invoke-PhysicalClick `
        -Element (Find-ElementById `
            -ProcessId $fullscreenClient.Id `
            -AutomationId "Playtest.Close") `
        -Process $fullscreenClient
    Wait-Condition -Description "Playtest close" -Seconds 20 -Condition {
        -not (Try-FindElementById `
            -ProcessId $fullscreenClient.Id `
            -AutomationId "Playtest.Dialog" `
            -TimeoutMilliseconds 150)
    }
    Stop-TrackedClient $fullscreenClient
    $tracked.Remove($fullscreenClient) | Out-Null
    $fullscreenClient = $null

    $fixtureHashesAfter = [ordered]@{
        chart = (Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash
        sourceMp3 = (Get-FileHash -LiteralPath $mp3FixtureFullPath -Algorithm SHA256).Hash
        sourceFlac = (Get-FileHash -LiteralPath $flacFixtureFullPath -Algorithm SHA256).Hash
    }
    foreach ($key in @($formatInputs.Keys)) {
        $fixtureHashesAfter["generated_$key"] =
            (Get-FileHash -LiteralPath $formatInputs[$key] -Algorithm SHA256).Hash
    }
    foreach ($key in @($fixtureHashesBefore.Keys)) {
        if ([string]$fixtureHashesBefore[$key] -cne
            [string]$fixtureHashesAfter[$key]) {
            throw "Immutable GUI fixture '$key' changed."
        }
    }

    $audioScratchResidue = @(
        Get-ChildItem `
            -LiteralPath $guiRoot `
            -Recurse `
            -File `
            -Filter ".luma-audio-import-*" `
            -ErrorAction SilentlyContinue
    )
    if ($audioScratchResidue.Count -ne 0) {
        throw "GUI batch left $($audioScratchResidue.Count) audio scratch files."
    }

    $screenshotRecords = [ordered]@{}
    foreach ($file in Get-ChildItem -LiteralPath $screenshotsRoot -File -Filter "*.png" |
             Sort-Object Name) {
        $screenshotRecords[$file.BaseName] = [ordered]@{
            path = $file.FullName
            length = $file.Length
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        }
    }

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.main-migration-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("o")
        status = "passed"
        windowsAvaloniaOnly = $true
        explicitForegroundConsentReceivedInCurrentConversation = $true
        foregroundAutomationIdleMilliseconds =
            $script:WindowsAvaloniaForegroundAutomationIdleMilliseconds
        reservedDesktopConsentUsed =
            $script:WindowsAvaloniaForegroundAutomationReservedDesktopConsentUsed
        physicalWin32ActionCount = $script:physicalActionCount
        persistentTopmostUsed = $false
        productionServerMutationPerformed = $false
        socialRelationshipNormalChainRepeated = $false
        keySoundSliceRepeated = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        fixtures = [ordered]@{
            before = $fixtureHashesBefore
            after = $fixtureHashesAfter
            unchanged = $true
        }
        audioFormats = $formatResults
        codecFailure = [ordered]@{
            sourcePath = $brokenM4a
            sourceSha256 =
                (Get-FileHash -LiteralPath $brokenM4a -Algorithm SHA256).Hash
            status = $codecFailureStatus
            referenceBefore = $referenceBeforeFailure
            referenceAfter = $referenceAfterFailure
            metadataUnchanged = $true
            importedOggCount = 0
            scratchCount = 0
        }
        tabChange = [ordered]@{
            sourcePath = $tabChangeInput
            sourceSha256 =
                (Get-FileHash -LiteralPath $tabChangeInput -Algorithm SHA256).Hash
            status = $tabChangeStatus
            referenceBefore = $tabReferenceBefore
            referenceAfter = $tabReferenceAfter
            metadataUnchanged = $true
            importedOggCount = 0
        }
        permissionRevocation = [ordered]@{
            seam = "evidence-chart-scoped EditorSession.CanEditMetadata revocation"
            delayMilliseconds = 100
            status = $revokeStatus
            referenceBefore = $revokeReferenceBefore
            referenceAfter = $revokeReferenceAfter
            metadataUnchanged = $true
            importedOggCount = 0
        }
        recoveryWarning = [ordered]@{
            title = "工作区恢复提示"
            message = $recoveryText
            corruptManifestPath = $recoveryManifest
            wsExTopmost = $false
            acknowledged = $true
        }
        persistFailure = [ordered]@{
            boundary = "Playtest startup"
            lockedWorkingPath = $workingChart
            message = $persistMessage
            workingSha256Before = $workingHashBeforeLock
            workingSha256After = $workingHashAfterFailure
            workingUnchanged = $true
            playtestOpened = $false
            wsExTopmost = $false
        }
        fullscreenInheritance = [ordered]@{
            physicalKey = "F11"
            monitor = $monitorBounds
            mainWindow = $mainFullscreenBounds
            playtest = $playtestFullscreenBounds
            inherited = $true
            playtestWsExTopmost = $false
            playtestInnerF11Used = $false
        }
        pickerSubmissions = @($pickerRecords)
        captures = $captures
        screenshots = $screenshotRecords
        audioScratchResidueCount = 0
    }
    $evidencePath = Join-Path $guiRoot "main-migration-gui-evidence.json"
    [IO.File]::WriteAllText(
        $evidencePath,
        ($evidence | ConvertTo-Json -Depth 14),
        [Text.UTF8Encoding]::new($false))
    Write-Host "Windows Avalonia main-migration GUI acceptance: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    if ($lockStream) { $lockStream.Dispose() }
    foreach ($process in @($tracked)) {
        Stop-TrackedClient $process
    }
}
