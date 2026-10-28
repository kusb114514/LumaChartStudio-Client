param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia shortcut GUI capture requires PowerShell Core on Windows."
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
        [int]$Seconds = $TimeoutSeconds
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try { if (& $Condition) { return } } catch { }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartShortcutGuiNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

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
    public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint firstThread, uint secondThread, bool attach);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);

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
        try
        {
            if (foregroundThread != 0 && foregroundThread != currentThread)
                attachedForeground = AttachThreadInput(currentThread, foregroundThread, true);
            if (targetThread != 0 && targetThread != currentThread && targetThread != foregroundThread)
                attachedTarget = AttachThreadInput(currentThread, targetThread, true);
            ShowWindowAsync(window, 9);
            BringWindowToTop(window);
            SetForegroundWindow(window);
            return GetForegroundWindow() == window;
        }
        finally
        {
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
                $candidate = $root.FindFirst([Windows.Automation.TreeScope]::Descendants, $idCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Invoke-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Select-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose SelectionItemPattern."
    }
    ([Windows.Automation.SelectionItemPattern]$pattern).Select()
}

function Scroll-ElementIntoView($Element) {
    $pattern = $null
    if ($Element.TryGetCurrentPattern([Windows.Automation.ScrollItemPattern]::Pattern, [ref]$pattern)) {
        ([Windows.Automation.ScrollItemPattern]$pattern).ScrollIntoView()
    }
    try { $Element.SetFocus() } catch { }
    Start-Sleep -Milliseconds 250
}

function Wait-MainWindowHandle([Diagnostics.Process]$Process) {
    Wait-Condition -Description "main window for process $($Process.Id)" -Condition {
        $Process.Refresh()
        -not $Process.HasExited -and $Process.MainWindowHandle -ne [IntPtr]::Zero
    }
    return $Process.MainWindowHandle
}

function Get-WindowBounds([IntPtr]$Handle) {
    $rectangle = [LumaChartShortcutGuiNative+RECT]::new()
    if (-not [LumaChartShortcutGuiNative]::GetWindowRect($Handle, [ref]$rectangle)) {
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
                if (-not [LumaChartShortcutGuiNative]::PrintWindow($Handle, $dc, 2)) {
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
        if ($colors.Count -lt 6) {
            throw "Screenshot is near-uniform: $($colors.Count) sampled colors."
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            width = $bounds.width
            height = $bounds.height
            sampledUniqueColors = $colors.Count
        }
    }
    finally { $bitmap.Dispose() }
}

function Get-ElementWindowHandle($Element) {
    $current = $Element
    while ($current) {
        $handle = [IntPtr]::new([int64]$current.Current.NativeWindowHandle)
        if ($handle -ne [IntPtr]::Zero) { return $handle }
        try { $current = [Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($current) }
        catch { $current = $null }
    }
    throw "Element '$($Element.Current.AutomationId)' did not resolve to a native window handle."
}

function Set-ForegroundWindowVerified([IntPtr]$Handle) {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(3)
    do {
        if ([LumaChartShortcutGuiNative]::GetForegroundWindow() -eq $Handle) { return }
        [void][LumaChartShortcutGuiNative]::TryActivateWindow($Handle)
        Start-Sleep -Milliseconds 50
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    $bounds = Get-WindowBounds $Handle
    $x = [int][Math]::Round($bounds.left + $bounds.width / 2)
    $y = [int][Math]::Round($bounds.top + [Math]::Min(20, $bounds.height / 4))
    if ([LumaChartShortcutGuiNative]::SetCursorPos($x, $y)) {
        Start-Sleep -Milliseconds 80
        [LumaChartShortcutGuiNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 60
        [LumaChartShortcutGuiNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 120
        if ([LumaChartShortcutGuiNative]::GetForegroundWindow() -eq $Handle) { return }
    }
    throw "Unable to activate evidence window $Handle before physical keyboard input."
}

function Send-PhysicalShortcut {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$WindowHandle,
        [Parameter(Mandatory = $true)][byte]$VirtualKey,
        [byte]$ScanCode = 0,
        [byte[]]$Modifiers = @(),
        [switch]$ExtendedKey,
        $FocusElement = $null
    )
    Set-ForegroundWindowVerified $WindowHandle
    if ($FocusElement) {
        $FocusElement.SetFocus()
        Start-Sleep -Milliseconds 80
    }
    foreach ($modifier in $Modifiers) {
        [LumaChartShortcutGuiNative]::keybd_event($modifier, 0, 0, [UIntPtr]::Zero)
    }
    $keyDownFlags = if ($ExtendedKey) { [uint32]1 } else { [uint32]0 }
    $keyUpFlags = if ($ExtendedKey) { [uint32]3 } else { [uint32]2 }
    [LumaChartShortcutGuiNative]::keybd_event($VirtualKey, $ScanCode, $keyDownFlags, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 120
    [LumaChartShortcutGuiNative]::keybd_event($VirtualKey, $ScanCode, $keyUpFlags, [UIntPtr]::Zero)
    for ($index = $Modifiers.Count - 1; $index -ge 0; $index--) {
        [LumaChartShortcutGuiNative]::keybd_event($Modifiers[$index], 0, 2, [UIntPtr]::Zero)
    }
    Start-Sleep -Milliseconds 220
}

function Get-RangeValue($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.RangeValuePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose RangeValuePattern."
    }
    return [double]([Windows.Automation.RangeValuePattern]$pattern).Current.Value
}

function Invoke-SpacePanDrag {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$WindowHandle,
        [Parameter(Mandatory = $true)]$TimelineElement,
        [ValidateRange(20, 500)][int]$HorizontalPixels = 180
    )
    Set-ForegroundWindowVerified $WindowHandle
    $TimelineElement.SetFocus()
    $rect = $TimelineElement.Current.BoundingRectangle
    if ($rect.Width -le 300 -or $rect.Height -le 300) {
        throw "Timeline has invalid bounds for Space-pan: $rect"
    }
    $startX = [int][Math]::Round($rect.X + $rect.Width * .44)
    $startY = [int][Math]::Round($rect.Y + $rect.Height * .48)
    $endX = [int][Math]::Min($rect.Right - 40, $startX + $HorizontalPixels)
    if (-not [LumaChartShortcutGuiNative]::SetCursorPos($startX, $startY)) {
        throw "Unable to position the pointer over the Timeline for Space-pan."
    }
    Start-Sleep -Milliseconds 120

    $spaceReleased = $false
    $mouseReleased = $false
    try {
        # Send a second key-down before key-up to model Windows repeat while
        # Space owns the pan gesture. Product code must suppress playback.
        [LumaChartShortcutGuiNative]::keybd_event(0x20, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 80
        [LumaChartShortcutGuiNative]::keybd_event(0x20, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 80
        [LumaChartShortcutGuiNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
        for ($step = 1; $step -le 8; $step++) {
            $x = [int][Math]::Round($startX + ($endX - $startX) * $step / 8)
            [void][LumaChartShortcutGuiNative]::SetCursorPos($x, $startY)
            Start-Sleep -Milliseconds 35
        }
        [LumaChartShortcutGuiNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
        $mouseReleased = $true
        Start-Sleep -Milliseconds 100
        [LumaChartShortcutGuiNative]::keybd_event(0x20, 0, 2, [UIntPtr]::Zero)
        $spaceReleased = $true
        Start-Sleep -Milliseconds 500
    }
    finally {
        if (-not $mouseReleased) {
            [LumaChartShortcutGuiNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
        }
        if (-not $spaceReleased) {
            [LumaChartShortcutGuiNative]::keybd_event(0x20, 0, 2, [UIntPtr]::Zero)
        }
    }
    return [ordered]@{
        startX = $startX
        startY = $startY
        endX = $endX
        endY = $startY
        repeatedSpaceKeyDownCount = 2
    }
}

function Start-ShortcutClient {
    param(
        [string]$Profile,
        [string]$ChartPath,
        [string]$LocalDataRoot,
        [string]$EditingRoot,
        [string]$WorkspaceRoot,
        [string]$RuntimeEvidencePath,
        [string]$InteractionEvidencePath = ""
    )
    foreach ($directory in @($LocalDataRoot, $EditingRoot, $WorkspaceRoot)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $applicationFullPath
    $start.UseShellExecute = $false
    $start.WorkingDirectory = Split-Path -Parent $applicationFullPath
    $start.ArgumentList.Add("--evidence-chart")
    $start.ArgumentList.Add($ChartPath)
    $start.ArgumentList.Add("--evidence-output")
    $start.ArgumentList.Add($RuntimeEvidencePath)
    if (-not [string]::IsNullOrWhiteSpace($InteractionEvidencePath)) {
        $start.ArgumentList.Add("--evidence-interaction-output")
        $start.ArgumentList.Add($InteractionEvidencePath)
        $start.ArgumentList.Add("--evidence-interaction-delay-ms")
        # Leave enough headroom for the full physical shortcut/IME-safe input
        # batch to enter fullscreen before the one-shot interaction snapshot.
        $start.ArgumentList.Add("90000")
    }
    $start.Environment["LUMACHART_PROFILE"] = $Profile
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $LocalDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $EditingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $WorkspaceRoot
    $start.Environment["DOTNET_CLI_HOME"] = $dotnetHome
    $start.Environment["NUGET_PACKAGES"] = $nugetPackages
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
    $start.Environment["TEMP"] = $projectTemp
    $start.Environment["TMP"] = $projectTemp
    $process = [Diagnostics.Process]::Start($start)
    if (-not $process) { throw "Unable to start Windows Avalonia shortcut client." }
    return $process
}

function Stop-TrackedClient([Diagnostics.Process]$Process) {
    if (-not $Process -or $Process.HasExited) { return }
    $Process.Kill($true)
    [void]$Process.WaitForExit(5000)
}

function Get-ElementName([int]$ProcessId, [string]$AutomationId) {
    return [string](Find-ElementById -ProcessId $ProcessId -AutomationId $AutomationId).Current.Name
}

function Get-ElementHelpText([int]$ProcessId, [string]$AutomationId) {
    return [string](Find-ElementById -ProcessId $ProcessId -AutomationId $AutomationId).Current.HelpText
}

function Get-InspectorNoteCount([int]$ProcessId) {
    $text = Get-ElementName $ProcessId "Editor.InspectorSummary"
    if ($text -notmatch 'Note\s+([0-9,，]+)\s+·\s+LN') { return -1 }
    return [int](($Matches[1] -replace '[,，]', ''))
}

function Get-InspectorSelectedNoteCount([int]$ProcessId) {
    $text = Get-ElementName $ProcessId "Editor.InspectorSummary"
    if ($text -notmatch '选择\s+([0-9,，]+)\s+Note') { return -1 }
    return [int](($Matches[1] -replace '[,，]', ''))
}

function Get-TimelineSelectedNoteCount([int]$ProcessId) {
    $text = Get-ElementHelpText $ProcessId "Timeline.Surface"
    if ($text -notmatch 'SelectedNoteCount=([0-9]+)') { return -1 }
    return [int]$Matches[1]
}

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$chartFixtureFullPath = Resolve-ExistingFile $ChartFixturePath "Real MC fixture"
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
if (-not (Test-Path -LiteralPath $outputFullPath -PathType Container)) {
    throw "Output root must already exist: $outputFullPath"
}
$guiRoot = Join-Path $outputFullPath "gui-runtime"
if (Test-Path -LiteralPath $guiRoot) { throw "GUI output root already exists: $guiRoot" }
New-Item -ItemType Directory -Path $guiRoot | Out-Null

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$projectTemp = Join-Path $projectRoot ".codex-temp"
$dotnetHome = Join-Path $projectRoot ".codex-dotnet-home"
$nugetPackages = Join-Path $projectRoot ".codex-nuget-packages"
$nugetHttpCache = Join-Path $projectRoot ".codex-nuget-http-cache"
foreach ($directory in @($projectTemp, $dotnetHome, $nugetPackages, $nugetHttpCache)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$workingRoot = Join-Path $guiRoot "working"
$clientRoot = Join-Path $guiRoot "client"
$localDataRoot = Join-Path $clientRoot "local-data"
$editingRoot = Join-Path $clientRoot "editing"
$workspaceRoot = Join-Path $clientRoot "workspace"
New-Item -ItemType Directory -Path $workingRoot | Out-Null
$workingChart = Join-Path $workingRoot "shortcuts-real.mc"
Copy-Item -LiteralPath $chartFixtureFullPath -Destination $workingChart
$fixtureDocument = Get-Content -LiteralPath $chartFixtureFullPath -Raw | ConvertFrom-Json
$audioFileName = [IO.Path]::GetFileName([string]$fixtureDocument.meta.song.file)
if ([string]::IsNullOrWhiteSpace($audioFileName)) {
    throw "The real MC fixture does not declare a song file."
}
$audioFixturePath = Resolve-ExistingFile `
    (Join-Path ([IO.Path]::GetDirectoryName($chartFixtureFullPath)) $audioFileName) `
    "Real MC audio fixture"
$workingAudio = Join-Path $workingRoot $audioFileName
Copy-Item -LiteralPath $audioFixturePath -Destination $workingAudio
$fixtureHashBefore = (Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash
$workingHashBefore = (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash
$audioFixtureHashBefore = (Get-FileHash -LiteralPath $audioFixturePath -Algorithm SHA256).Hash
$workingAudioHashBefore = (Get-FileHash -LiteralPath $workingAudio -Algorithm SHA256).Hash
$wpfShortcutPath = Join-Path (
    [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) (
    "LumaChart Studio\shortcuts.json")
$wpfShortcutExistsBefore = Test-Path -LiteralPath $wpfShortcutPath -PathType Leaf
$wpfShortcutHashBefore = if ($wpfShortcutExistsBefore) {
    (Get-FileHash -LiteralPath $wpfShortcutPath -Algorithm SHA256).Hash
} else { $null }

$first = $null
$second = $null
try {
    $primaryRuntimePath = Join-Path $guiRoot "shortcuts-primary-runtime.json"
    $interactionRuntimePath = Join-Path $guiRoot "shortcuts-interaction-runtime.json"
    $first = Start-ShortcutClient `
        -Profile "windows-avalonia-shortcuts" `
        -ChartPath $workingChart `
        -LocalDataRoot $localDataRoot `
        -EditingRoot $editingRoot `
        -WorkspaceRoot $workspaceRoot `
        -RuntimeEvidencePath $primaryRuntimePath `
        -InteractionEvidencePath $interactionRuntimePath
    $firstHandle = Wait-MainWindowHandle $first
    [void][LumaChartShortcutGuiNative]::ShowWindow($firstHandle, 3)
    Wait-Condition -Description "primary shortcut runtime evidence" -Condition {
        if (-not (Test-Path -LiteralPath $primaryRuntimePath -PathType Leaf)) { return $false }
        try {
            $runtime = Get-Content -LiteralPath $primaryRuntimePath -Raw | ConvertFrom-Json
            return $runtime.schema -ceq "lumachart.windows.avalonia.gui-evidence.v14" -and
                   $runtime.shortcuts.catalogCount -eq 31 -and
                   $runtime.timeline.performance.renderMilliseconds.samples -ge 240
        }
        catch { return $false }
    }
    $primaryRuntime = Get-Content -LiteralPath $primaryRuntimePath -Raw | ConvertFrom-Json
    $initialNoteCount = [int]$primaryRuntime.chart.structure.noteCount
    $initialStructureSha256 = [string]$primaryRuntime.chart.structure.sha256
    $initialSelectedCount = [int]$primaryRuntime.timeline.selectedNoteCount
    $windowBoundsBeforeFullscreen = Get-WindowBounds $firstHandle

    Select-Element (Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Inspector.SettingsTab" `
        -TimeoutMilliseconds 30000)
    Start-Sleep -Milliseconds 300
    $toolSelectButton = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Shortcut_ToolSelect" `
        -TimeoutMilliseconds 30000
    Scroll-ElementIntoView $toolSelectButton
    $settingsBeforeScreenshot = Join-Path $guiRoot "shortcuts-before.png"
    $settingsBeforeCapture = Capture-Window $firstHandle $settingsBeforeScreenshot
    if ([string]$toolSelectButton.Current.HelpText -cne "Q") {
        throw "ToolSelect did not start at the WPF default Q binding."
    }

    $toolTapButton = Find-ElementById -ProcessId $first.Id -AutomationId "Shortcut_ToolTap"
    Invoke-Element $toolTapButton
    Wait-Condition -Description "ToolTap shortcut capture" -Seconds 10 -Condition {
        (Get-ElementName $first.Id "Settings.Shortcuts.Status") -like "正在录入*"
    }
    $toolTapButton.SetFocus()
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x51 -FocusElement $toolTapButton
    $captureStatusAfterQ = Get-ElementName $first.Id "Settings.Shortcuts.Status"
    if ($captureStatusAfterQ -like "中文输入法按键尚未解析*") {
        throw $captureStatusAfterQ
    }
    $conflictMessageElement = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Settings.ActionDialog.Message" `
        -TimeoutMilliseconds 15000
    $conflictMessage = [string]$conflictMessageElement.Current.Name
    if ($conflictMessage -notlike "*Q 已用于*选择工具*" -or
        $conflictMessage -notlike "*清除原绑定*" ) {
        throw "Shortcut conflict dialog did not identify the WPF Q binding: $conflictMessage"
    }
    $conflictScreenshot = Join-Path $guiRoot "shortcuts-conflict.png"
    $conflictCapture = Capture-Window (Get-ElementWindowHandle $conflictMessageElement) $conflictScreenshot
    Invoke-Element (Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Settings.ActionDialog.Primary")
    Wait-Condition -Description "Q conflict replacement" -Seconds 10 -Condition {
        (Get-ElementHelpText $first.Id "Shortcut_ToolSelect") -ceq "未设置" -and
        (Get-ElementHelpText $first.Id "Shortcut_ToolTap") -ceq "Q"
    }
    # Avalonia's modal native window can temporarily become Process.MainWindowHandle.
    # Refresh the handle after it closes so later capture/input targets the editor.
    $firstHandle = Wait-MainWindowHandle $first

    $toolHoldButton = Find-ElementById -ProcessId $first.Id -AutomationId "Shortcut_ToolHold"
    Invoke-Element $toolHoldButton
    $toolHoldButton.SetFocus()
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x08 -FocusElement $toolHoldButton
    Wait-Condition -Description "Backspace shortcut clearing" -Seconds 10 -Condition {
        (Get-ElementHelpText $first.Id "Shortcut_ToolHold") -ceq "未设置"
    }

    $toolEraseButton = Find-ElementById -ProcessId $first.Id -AutomationId "Shortcut_ToolErase"
    Invoke-Element $toolEraseButton
    $toolEraseButton.SetFocus()
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x75 -FocusElement $toolEraseButton
    Wait-Condition -Description "F6 shortcut assignment" -Seconds 10 -Condition {
        (Get-ElementHelpText $first.Id "Shortcut_ToolErase") -ceq "F6"
    }

    $shortcutPath = Join-Path $localDataRoot "shortcuts.json"
    Wait-Condition -Description "atomic shortcut persistence" -Seconds 15 -Condition {
        if (-not (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) { return $false }
        try {
            $persisted = Get-Content -LiteralPath $shortcutPath -Raw | ConvertFrom-Json
            return $persisted.bindings.ToolSelect -ceq "" -and
                   $persisted.bindings.ToolTap -ceq "Q" -and
                   $persisted.bindings.ToolHold -ceq "" -and
                   $persisted.bindings.ToolErase -ceq "F6"
        }
        catch { return $false }
    }
    if ((Get-ChildItem -LiteralPath $localDataRoot -Filter ".shortcuts.json.*.tmp").Count -ne 0) {
        throw "Atomic shortcut GUI persistence left a temporary file."
    }
    Scroll-ElementIntoView (Find-ElementById -ProcessId $first.Id -AutomationId "Shortcut_Group9")
    $settingsLowerScreenshot = Join-Path $guiRoot "shortcuts-lower.png"
    $settingsLowerCapture = Capture-Window $firstHandle $settingsLowerScreenshot

    Select-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Inspector.NoteTab")
    $editorShortcutFocus = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Editor.QuickTool.Select"
    $editorShortcutFocus.SetFocus()
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x75 -FocusElement $editorShortcutFocus
    Wait-Condition -Description "F6 erase-tool routing" -Seconds 10 -Condition {
        (Get-ElementHelpText $first.Id "Editor.QuickTool.Erase") -ceq "当前编辑工具"
    }
    Select-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Inspector.MetadataTab")
    $metadataTitle = Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.Title"
    $metadataTitle.SetFocus()
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x51 -FocusElement $metadataTitle
    if ((Get-ElementHelpText $first.Id "Editor.QuickTool.Erase") -cne "当前编辑工具") {
        throw "Q changed the editor tool while a metadata TextBox owned keyboard focus."
    }

    Select-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Inspector.NoteTab")
    $editorShortcutFocus.SetFocus()
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x51 -FocusElement $editorShortcutFocus
    Wait-Condition -Description "custom Q Tap-tool routing" -Seconds 10 -Condition {
        (Get-ElementHelpText $first.Id "Editor.QuickTool.Tap") -ceq "当前编辑工具"
    }
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x37 -FocusElement $editorShortcutFocus
    Wait-Condition -Description "D7 placement-group routing" -Seconds 10 -Condition {
        (Get-ElementName $first.Id "Editor.Status") -like "*Group 7*"
    }

    if ($initialSelectedCount -gt 0) {
        Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x26 -FocusElement $editorShortcutFocus
        Wait-Condition -Description "Up selection nudge" -Seconds 10 -Condition {
            (Get-ElementName $first.Id "Editor.Status") -like "*向前移动*Note*"
        }
        Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x5A -Modifiers @(0x11) -FocusElement $editorShortcutFocus
    }
    else {
        $beatBefore = [double]$primaryRuntime.timeline.currentBeat
        Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x26 -FocusElement $editorShortcutFocus
        Wait-Condition -Description "Up red-line step" -Seconds 10 -Condition {
            $summary = Get-ElementName $first.Id "Editor.InspectorSummary"
            return $summary -match ('红线\s+' + [Regex]::Escape((($beatBefore + .25).ToString("F3"))))
        }
    }
    Send-PhysicalShortcut `
        -WindowHandle $firstHandle `
        -VirtualKey 0x24 `
        -ScanCode 0x47 `
        -ExtendedKey `
        -FocusElement $editorShortcutFocus
    Wait-Condition -Description "Home red-line routing" -Seconds 10 -Condition {
        (Get-ElementHelpText $first.Id "Timeline.Surface") -match
            '(?:CurrentBeat=|当前 Beat )0(?:;|$)'
    }

    $editorShortcutFocus.SetFocus()
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x41 -Modifiers @(0x11) -FocusElement $editorShortcutFocus
    Wait-Condition -Description "Ctrl+A visible Note selection" -Seconds 10 -Condition {
        (Get-TimelineSelectedNoteCount $first.Id) -eq $initialNoteCount
    }
    $selectAllInspector = Get-ElementHelpText $first.Id "Timeline.Surface"
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x58 -Modifiers @(0x11) -FocusElement $editorShortcutFocus
    Wait-Condition -Description "Ctrl+X Note cut" -Seconds 30 -Condition {
        $status = Get-ElementName $first.Id "Editor.Status"
        return $status -like
                ("*已剪切 {0:N0} 个 Note、0 个 Effect*" -f $initialNoteCount) -or
            ((Get-TimelineSelectedNoteCount $first.Id) -eq 0 -and
             -not (Find-ElementById `
                 -ProcessId $first.Id `
                 -AutomationId "Editor.QuickCut").Current.IsEnabled)
    }
    $cutInspector = Get-ElementName $first.Id "Editor.Status"
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x5A -Modifiers @(0x11) -FocusElement $editorShortcutFocus
    Wait-Condition -Description "Ctrl+Z cut undo" -Seconds 10 -Condition {
        (Get-ElementName $first.Id "Editor.Status") -ceq "已撤销"
    }
    $undoInspector = Get-ElementName $first.Id "Editor.Status"

    # ProEditor Space-pan owns Space until key-up. A repeated key-down and the
    # completed drag must not leak into the configurable playback shortcut.
    $timelineSurface = Find-ElementById -ProcessId $first.Id -AutomationId "Timeline.Surface"
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x50 -FocusElement $timelineSurface
    $proPanSlider = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "ProEditor.HorizontalPan" `
        -TimeoutMilliseconds 15000
    Wait-Condition -Description "ProEditor horizontal pan availability" -Seconds 10 -Condition {
        $proPanSlider.Current.IsEnabled
    }
    $panBefore = Get-RangeValue $proPanSlider
    $playNameBeforePan = Get-ElementName $first.Id "Editor.QuickPlayPause"
    Wait-Condition -Description "real MC audio playback availability" -Seconds 20 -Condition {
        (Find-ElementById `
            -ProcessId $first.Id `
            -AutomationId "Editor.QuickPlayPause").Current.IsEnabled
    }
    $spacePanInput = Invoke-SpacePanDrag `
        -WindowHandle $firstHandle `
        -TimelineElement $timelineSurface
    $panAfter = Get-RangeValue $proPanSlider
    $playNameAfterPan = Get-ElementName $first.Id "Editor.QuickPlayPause"
    if ([Math]::Abs($panAfter - $panBefore) -lt 20) {
        throw "Repeated-Space physical drag did not move the ProEditor workspace: $panBefore -> $panAfter"
    }
    if ($playNameAfterPan -cne $playNameBeforePan -or $playNameAfterPan -match "暂停") {
        throw "Completed Space-pan leaked into playback: '$playNameBeforePan' -> '$playNameAfterPan'"
    }
    $spacePanScreenshot = Join-Path $guiRoot "shortcuts-space-pan.png"
    $spacePanCapture = Capture-Window $firstHandle $spacePanScreenshot

    # An unused press over the same ProEditor surface must still preserve the
    # WPF Space playback shortcut on key-up.
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x20 -FocusElement $timelineSurface
    Wait-Condition -Description "unused Space-pan press starts playback" -Seconds 10 -Condition {
        (Get-ElementName $first.Id "Editor.QuickPlayPause") -match "暂停"
    }
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x20 -FocusElement $timelineSurface
    Wait-Condition -Description "second unused Space-pan press pauses playback" -Seconds 10 -Condition {
        (Get-ElementName $first.Id "Editor.QuickPlayPause") -match "播放"
    }

    # Capture and route one OEM key and one numpad key through the real
    # settings UI. VK_ADD is intentionally independent of NumLock state.
    Select-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Inspector.SettingsTab")
    $toolHoldButton = Find-ElementById -ProcessId $first.Id -AutomationId "Shortcut_ToolHold"
    Scroll-ElementIntoView $toolHoldButton
    Invoke-Element $toolHoldButton
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0xBA -FocusElement $toolHoldButton
    Wait-Condition -Description "OEM semicolon shortcut capture" -Seconds 10 -Condition {
        (Get-ElementHelpText $first.Id "Shortcut_ToolHold") -ceq "OemSemicolon"
    }
    $toolEraseButton = Find-ElementById -ProcessId $first.Id -AutomationId "Shortcut_ToolErase"
    Invoke-Element $toolEraseButton
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x6B -FocusElement $toolEraseButton
    Wait-Condition -Description "numpad Add shortcut capture" -Seconds 10 -Condition {
        (Get-ElementHelpText $first.Id "Shortcut_ToolErase") -ceq "Add"
    }
    Wait-Condition -Description "OEM and numpad atomic persistence" -Seconds 15 -Condition {
        try {
            $persisted = Get-Content -LiteralPath $shortcutPath -Raw | ConvertFrom-Json
            return $persisted.bindings.ToolHold -ceq "OemSemicolon" -and
                   $persisted.bindings.ToolErase -ceq "Add"
        }
        catch { return $false }
    }
    $edgeSettingsScreenshot = Join-Path $guiRoot "shortcuts-oem-numpad.png"
    $edgeSettingsCapture = Capture-Window $firstHandle $edgeSettingsScreenshot

    Select-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Inspector.NoteTab")
    $editorShortcutFocus.SetFocus()
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0xBA -FocusElement $editorShortcutFocus
    Wait-Condition -Description "OEM semicolon Hold-tool routing" -Seconds 10 -Condition {
        (Get-ElementHelpText $first.Id "Editor.QuickTool.Hold") -ceq "当前编辑工具"
    }
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x6B -FocusElement $editorShortcutFocus
    Wait-Condition -Description "numpad Add Erase-tool routing" -Seconds 10 -Condition {
        (Get-ElementHelpText $first.Id "Editor.QuickTool.Erase") -ceq "当前编辑工具"
    }
    # Leave the established Q binding and current-tool runtime invariant intact.
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x51 -FocusElement $editorShortcutFocus
    Wait-Condition -Description "custom Q Tap-tool routing after edge keys" -Seconds 10 -Condition {
        (Get-ElementHelpText $first.Id "Editor.QuickTool.Tap") -ceq "当前编辑工具"
    }

    [void][LumaChartShortcutGuiNative]::ShowWindowAsync($firstHandle, 3)
    Start-Sleep -Milliseconds 350
    Send-PhysicalShortcut -WindowHandle $firstHandle -VirtualKey 0x7A -FocusElement $editorShortcutFocus
    Wait-Condition -Description "F11 fullscreen interaction runtime" -Condition {
        if (-not (Test-Path -LiteralPath $interactionRuntimePath -PathType Leaf)) { return $false }
        try {
            $runtime = Get-Content -LiteralPath $interactionRuntimePath -Raw | ConvertFrom-Json
            return $runtime.schema -ceq "lumachart.windows.avalonia.gui-evidence.v14" -and
                   $runtime.window.windowState -ceq "FullScreen"
        }
        catch { return $false }
    }
    $interactionRuntime = Get-Content -LiteralPath $interactionRuntimePath -Raw | ConvertFrom-Json
    if ($interactionRuntime.shortcuts.bindings.ToolSelect -cne "" -or
        $interactionRuntime.shortcuts.bindings.ToolTap -cne "Q" -or
        $interactionRuntime.shortcuts.bindings.ToolHold -cne "OemSemicolon" -or
        $interactionRuntime.shortcuts.bindings.ToolErase -cne "Add" -or
        -not $interactionRuntime.shortcuts.settingsIsolatedFromWpf -or
        -not $interactionRuntime.shortcuts.allCatalogActionsRoutable -or
        $interactionRuntime.shortcuts.duplicateGestureCount -ne 0) {
        throw "Interaction runtime did not prove the customized conflict-free shortcut state."
    }
    if ($interactionRuntime.timeline.currentTool -cne "Tap" -or
        $interactionRuntime.timeline.activePlacementGroup -ne 7 -or
        [double]$interactionRuntime.timeline.currentBeat -le 0 -or
        [double]$interactionRuntime.timeline.currentBeat -ge 4 -or
        $interactionRuntime.audio.state -cne "Paused" -or
        -not $interactionRuntime.audio.sourceExists -or
        [double]$interactionRuntime.audio.positionMilliseconds -le 0 -or
        $interactionRuntime.chart.structure.sha256 -cne $initialStructureSha256) {
        throw "Tool, group, real-audio playback/pause, Cut/Undo or structural runtime state did not match the shortcut actions."
    }
    $fullscreenScreenshot = Join-Path $guiRoot "shortcuts-fullscreen.png"
    $fullscreenCapture = Capture-Window $firstHandle $fullscreenScreenshot
    $fullscreenBounds = Get-WindowBounds $firstHandle
    $titleChrome = Find-ElementById -ProcessId $first.Id -AutomationId "Title.Chrome"
    $hiddenTitleRectangle = $titleChrome.Current.BoundingRectangle
    if (-not $titleChrome.Current.IsOffscreen -and
        $hiddenTitleRectangle.Bottom -gt ($fullscreenBounds.top + 2)) {
        throw "F11 did not hide the WPF-style custom title bar."
    }
    $revealX = [int][Math]::Round(($fullscreenBounds.left + $fullscreenBounds.right) / 2)
    $revealY = [int]$fullscreenBounds.top
    $pointerResetY = [int][Math]::Min(
        $fullscreenBounds.bottom - 1,
        $fullscreenBounds.top + 160)
    if (-not [LumaChartShortcutGuiNative]::SetCursorPos(
            $revealX,
            $pointerResetY)) {
        throw "Could not move the real pointer away from the fullscreen reveal hot zone."
    }
    Start-Sleep -Milliseconds 120
    if (-not [LumaChartShortcutGuiNative]::SetCursorPos($revealX, $revealY)) {
        throw "Could not move the real pointer to the physical top-edge reveal hot zone."
    }
    Wait-Condition -Description "fullscreen top-edge title-bar reveal" -Seconds 10 -Condition {
        try {
            $candidate = Find-ElementById -ProcessId $first.Id -AutomationId "Title.Chrome"
            $rectangle = $candidate.Current.BoundingRectangle
            return -not $candidate.Current.IsOffscreen -and
                   $rectangle.Top -ge ($fullscreenBounds.top - 2) -and
                   $rectangle.Bottom -ge ($fullscreenBounds.top + 35)
        }
        catch { return $false }
    }
    $revealedTitleRectangle = (Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Title.Chrome").Current.BoundingRectangle
    $fullscreenRevealedScreenshot = Join-Path $guiRoot "shortcuts-fullscreen-title-revealed.png"
    $fullscreenRevealedCapture = Capture-Window $firstHandle $fullscreenRevealedScreenshot
    [void][LumaChartShortcutGuiNative]::SetCursorPos(
        $revealX,
        [int][Math]::Round(($fullscreenBounds.top + $fullscreenBounds.bottom) / 2))
    Wait-Condition -Description "fullscreen title-bar auto-hide after pointer leaves" -Seconds 10 -Condition {
        try {
            $candidate = Find-ElementById -ProcessId $first.Id -AutomationId "Title.Chrome"
            $rectangle = $candidate.Current.BoundingRectangle
            return $candidate.Current.IsOffscreen -or
                   $rectangle.Bottom -le ($fullscreenBounds.top + 2)
        }
        catch { return $false }
    }
    $hiddenAgainTitleRectangle = (Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Title.Chrome").Current.BoundingRectangle
    # Close the first process while Borderless is the user's active preference.
    # The second process must restore FullScreen before any new F11 input.
    Stop-TrackedClient $first

    $reopenRuntimePath = Join-Path $guiRoot "shortcuts-reopen-runtime.json"
    $second = Start-ShortcutClient `
        -Profile "windows-avalonia-shortcuts-reopen" `
        -ChartPath $workingChart `
        -LocalDataRoot $localDataRoot `
        -EditingRoot $editingRoot `
        -WorkspaceRoot $workspaceRoot `
        -RuntimeEvidencePath $reopenRuntimePath
    $secondHandle = Wait-MainWindowHandle $second
    Wait-Condition -Description "reopened shortcut runtime evidence" -Condition {
        if (-not (Test-Path -LiteralPath $reopenRuntimePath -PathType Leaf)) { return $false }
        try {
            $runtime = Get-Content -LiteralPath $reopenRuntimePath -Raw | ConvertFrom-Json
            return $runtime.schema -ceq "lumachart.windows.avalonia.gui-evidence.v14" -and
                   $runtime.shortcuts.bindings.ToolTap -ceq "Q" -and
                   $runtime.shortcuts.bindings.ToolHold -ceq "OemSemicolon" -and
                   $runtime.shortcuts.bindings.ToolErase -ceq "Add" -and
                   $runtime.window.windowState -ceq "FullScreen"
        }
        catch { return $false }
    }
    $reopenRuntime = Get-Content -LiteralPath $reopenRuntimePath -Raw | ConvertFrom-Json
    $reopenFullscreenScreenshot = Join-Path $guiRoot "shortcuts-reopened-fullscreen.png"
    $reopenFullscreenCapture = Capture-Window $secondHandle $reopenFullscreenScreenshot
    $reopenFullscreenFocus = Find-ElementById `
        -ProcessId $second.Id `
        -AutomationId "Editor.QuickTool.Select" `
        -TimeoutMilliseconds 15000
    Send-PhysicalShortcut `
        -WindowHandle $secondHandle `
        -VirtualKey 0x7A `
        -FocusElement $reopenFullscreenFocus
    Wait-Condition -Description "reopened fullscreen exits through F11" -Seconds 10 -Condition {
        try {
            $candidate = Find-ElementById -ProcessId $second.Id -AutomationId "Title.Chrome"
            $rectangle = $candidate.Current.BoundingRectangle
            return -not $candidate.Current.IsOffscreen -and $rectangle.Height -ge 35
        }
        catch { return $false }
    }
    $windowBoundsAfterFullscreenExit = Get-WindowBounds $secondHandle
    [void][LumaChartShortcutGuiNative]::ShowWindow($secondHandle, 3)
    Start-Sleep -Milliseconds 350
    Select-Element (Find-ElementById -ProcessId $second.Id -AutomationId "Inspector.SettingsTab")
    $reopenToolSelect = Find-ElementById -ProcessId $second.Id -AutomationId "Shortcut_ToolSelect"
    Scroll-ElementIntoView $reopenToolSelect
    $reopenValues = [ordered]@{
        ToolSelect = Get-ElementHelpText $second.Id "Shortcut_ToolSelect"
        ToolTap = Get-ElementHelpText $second.Id "Shortcut_ToolTap"
        ToolHold = Get-ElementHelpText $second.Id "Shortcut_ToolHold"
        ToolErase = Get-ElementHelpText $second.Id "Shortcut_ToolErase"
    }
    if ($reopenValues.ToolSelect -cne "未设置" -or
        $reopenValues.ToolTap -cne "Q" -or
        $reopenValues.ToolHold -cne "OemSemicolon" -or
        $reopenValues.ToolErase -cne "Add") {
        throw "Second-process shortcut UI did not restore the customized bindings."
    }
    $reopenUpperScreenshot = Join-Path $guiRoot "shortcuts-reopened-upper.png"
    $reopenUpperCapture = Capture-Window $secondHandle $reopenUpperScreenshot
    Scroll-ElementIntoView (Find-ElementById -ProcessId $second.Id -AutomationId "Shortcut_Group9")
    $reopenLowerScreenshot = Join-Path $guiRoot "shortcuts-reopened-lower.png"
    $reopenLowerCapture = Capture-Window $secondHandle $reopenLowerScreenshot
    Stop-TrackedClient $second
    $fixtureHashAfter = (Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash
    $workingHashAfter = (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash
    $audioFixtureHashAfter = (Get-FileHash -LiteralPath $audioFixturePath -Algorithm SHA256).Hash
    $workingAudioHashAfter = (Get-FileHash -LiteralPath $workingAudio -Algorithm SHA256).Hash
    if ($fixtureHashAfter -cne $fixtureHashBefore -or $workingHashAfter -cne $workingHashBefore) {
        throw "The immutable fixture or isolated source copy changed during shortcut acceptance."
    }
    if ($audioFixtureHashAfter -cne $audioFixtureHashBefore -or
        $workingAudioHashAfter -cne $workingAudioHashBefore -or
        $workingAudioHashAfter -cne $audioFixtureHashAfter) {
        throw "The immutable audio fixture or isolated audio copy changed during shortcut acceptance."
    }
    $wpfShortcutExistsAfter = Test-Path -LiteralPath $wpfShortcutPath -PathType Leaf
    $wpfShortcutHashAfter = if ($wpfShortcutExistsAfter) {
        (Get-FileHash -LiteralPath $wpfShortcutPath -Algorithm SHA256).Hash
    } else { $null }
    if ($wpfShortcutExistsAfter -ne $wpfShortcutExistsBefore -or
        $wpfShortcutHashAfter -cne $wpfShortcutHashBefore) {
        throw "Avalonia shortcut GUI acceptance changed the WPF shortcuts.json file."
    }

    $screenshots = @{}
    foreach ($path in @(
        $settingsBeforeScreenshot,
        $conflictScreenshot,
        $settingsLowerScreenshot,
        $spacePanScreenshot,
        $edgeSettingsScreenshot,
        $fullscreenScreenshot,
        $fullscreenRevealedScreenshot,
        $reopenFullscreenScreenshot,
        $reopenUpperScreenshot,
        $reopenLowerScreenshot)) {
        $item = Get-Item -LiteralPath $path
        $screenshots[$item.BaseName] = [ordered]@{
            path = $item.FullName
            length = $item.Length
            sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        }
    }
    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.shortcuts-gui-evidence.v2"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("o")
        status = "passed-migration-incomplete"
        windowsAvaloniaOnly = $true
        productionServerMutationPerformed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        ollvmExecutedOrRequired = $false
        chineseImeGlobalEnterEscapeHandlerAdded = $false
        keyboardInput = "Win32 keybd_event virtual-key injection; not a hardware-keyboard claim; no Enter/Escape or clipboard injection"
        hardwareKeyboardInputClaimed = $false
        numpadInput = "VK_ADD (0x6B); independent of NumLock state"
        fixture = [ordered]@{
            path = $chartFixtureFullPath
            sha256Before = $fixtureHashBefore
            sha256After = $fixtureHashAfter
            unchanged = $true
            isolatedSourcePath = $workingChart
            isolatedSourceSha256Before = $workingHashBefore
            isolatedSourceSha256After = $workingHashAfter
            isolatedSourceUnchanged = $true
            audioPath = $audioFixturePath
            audioSha256Before = $audioFixtureHashBefore
            audioSha256After = $audioFixtureHashAfter
            audioUnchanged = $true
            isolatedAudioPath = $workingAudio
            isolatedAudioSha256Before = $workingAudioHashBefore
            isolatedAudioSha256After = $workingAudioHashAfter
            isolatedAudioUnchanged = $true
            initialNoteCount = $initialNoteCount
            initialStructureSha256 = $initialStructureSha256
            interactionStructureSha256 = [string]$interactionRuntime.chart.structure.sha256
            cutUndoStructureMatch = $true
        }
        settingsUi = [ordered]@{
            initialToolSelect = "Q"
            conflictMessage = $conflictMessage
            conflictReplacementAccepted = $true
            ToolSelect = ""
            ToolTap = "Q"
            ToolHold = "OemSemicolon"
            ToolErase = "Add"
            backspaceClearedToolHold = $true
            oemSemicolonCapturedAfterClear = $true
            numpadAddCapturedAfterF6 = $true
            persistencePath = $shortcutPath
            persistenceSha256 = (Get-FileHash -LiteralPath $shortcutPath -Algorithm SHA256).Hash
            atomicTemporaryFileCount = 0
            secondProcessValues = $reopenValues
            secondProcessUiMatches = $true
        }
        operationRouting = [ordered]@{
            textBoxQSuppressed = $true
            customQSelectedTapTool = $true
            customF6SelectedEraseTool = $true
            customOemSemicolonSelectedHoldTool = $true
            customNumpadAddSelectedEraseTool = $true
            group7SelectedByD7 = $true
            stepForwardVerified = $true
            homeReturnedBeatToZero = $true
            selectAllSelectedNoteCount = $initialNoteCount
            selectAllInspector = $selectAllInspector
            cutReducedNoteCountToZero = $true
            cutInspector = $cutInspector
            undoRestoredNoteCount = $initialNoteCount
            undoInspector = $undoInspector
            fullscreenEnteredWithF11 = $true
            fullscreenExitedWithF11 = $true
            fullscreenPersistedAcrossRestart = $true
            firstProcessClosedWhileFullscreen = $true
            secondProcessInitialWindowState = [string]$reopenRuntime.window.windowState
            windowBoundsBeforeFullscreen = $windowBoundsBeforeFullscreen
            fullscreenBounds = $fullscreenBounds
            fullscreenTitleBar = [ordered]@{
                contract = "wpf-1.1.0-titlebar-r1"
                initiallyHidden = $true
                revealUsedPhysicalTopEdgePointer = $true
                revealPoint = [ordered]@{ x = $revealX; y = $revealY }
                hiddenRectangle = [ordered]@{
                    left = $hiddenTitleRectangle.Left
                    top = $hiddenTitleRectangle.Top
                    right = $hiddenTitleRectangle.Right
                    bottom = $hiddenTitleRectangle.Bottom
                }
                revealedRectangle = [ordered]@{
                    left = $revealedTitleRectangle.Left
                    top = $revealedTitleRectangle.Top
                    right = $revealedTitleRectangle.Right
                    bottom = $revealedTitleRectangle.Bottom
                }
                hiddenAgainRectangle = [ordered]@{
                    left = $hiddenAgainTitleRectangle.Left
                    top = $hiddenAgainTitleRectangle.Top
                    right = $hiddenAgainTitleRectangle.Right
                    bottom = $hiddenAgainTitleRectangle.Bottom
                }
                autoHideDelayMilliseconds = 480
            }
            windowBoundsAfterFullscreenExit = $windowBoundsAfterFullscreenExit
        }
        spacePan = [ordered]@{
            proEditorEnabled = $true
            panBefore = $panBefore
            panAfter = $panAfter
            panDelta = $panAfter - $panBefore
            repeatedSpaceKeyDownCount = $spacePanInput.repeatedSpaceKeyDownCount
            completedPanDidNotTogglePlayback = $playNameAfterPan -ceq $playNameBeforePan
            unusedSpacePressStartedPlayback = $true
            secondUnusedSpacePressPausedPlayback = $true
            input = $spacePanInput
        }
        wpfIsolation = [ordered]@{
            path = $wpfShortcutPath
            existedBefore = $wpfShortcutExistsBefore
            existedAfter = $wpfShortcutExistsAfter
            sha256Before = $wpfShortcutHashBefore
            sha256After = $wpfShortcutHashAfter
            unchanged = $true
        }
        runtimeEvidence = [ordered]@{
            primaryPath = $primaryRuntimePath
            primarySha256 = (Get-FileHash -LiteralPath $primaryRuntimePath -Algorithm SHA256).Hash
            interactionPath = $interactionRuntimePath
            interactionSha256 = (Get-FileHash -LiteralPath $interactionRuntimePath -Algorithm SHA256).Hash
            reopenPath = $reopenRuntimePath
            reopenSha256 = (Get-FileHash -LiteralPath $reopenRuntimePath -Algorithm SHA256).Hash
            schema = [string]$interactionRuntime.schema
            interactionShortcuts = $interactionRuntime.shortcuts
            interactionTimeline = [ordered]@{
                currentTool = [string]$interactionRuntime.timeline.currentTool
                activePlacementGroup = [int]$interactionRuntime.timeline.activePlacementGroup
                currentBeat = [double]$interactionRuntime.timeline.currentBeat
                selectedNoteCount = [int]$interactionRuntime.timeline.selectedNoteCount
                renderMilliseconds = $interactionRuntime.timeline.performance.renderMilliseconds
                frameIntervalMilliseconds = $interactionRuntime.timeline.performance.frameIntervalMilliseconds
                inputToRenderMilliseconds = $interactionRuntime.timeline.performance.inputToRenderMilliseconds
            }
            interactionAudio = [ordered]@{
                state = [string]$interactionRuntime.audio.state
                sourcePath = [string]$interactionRuntime.audio.sourcePath
                sourceExists = [bool]$interactionRuntime.audio.sourceExists
                positionMilliseconds = [double]$interactionRuntime.audio.positionMilliseconds
                durationMilliseconds = [double]$interactionRuntime.audio.durationMilliseconds
                status = [string]$interactionRuntime.audio.status
            }
            reopenShortcuts = $reopenRuntime.shortcuts
        }
        captures = [ordered]@{
            before = $settingsBeforeCapture
            conflict = $conflictCapture
            lower = $settingsLowerCapture
            spacePan = $spacePanCapture
            oemNumpad = $edgeSettingsCapture
            fullscreen = $fullscreenCapture
            fullscreenTitleRevealed = $fullscreenRevealedCapture
            reopenedFullscreen = $reopenFullscreenCapture
            reopenedUpper = $reopenUpperCapture
            reopenedLower = $reopenLowerCapture
        }
        screenshots = $screenshots
        completion = [ordered]@{
            functionMatrixAllPassed = $false
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
        }
        remainingDifferences = @(
            "OEM semicolon, numpad Add and repeated-Space ProEditor panning are covered; other OEM/numpad keys and keyboard models still require expansion.",
            "Pixel-level WPF visual parity and remaining mouse/keyboard/focus workflows still require slice-by-slice acceptance.",
            "Rework/test-play/conversion and remaining library/editor/community/online matrix items are incomplete.",
            "Final two-client online, physical 1080p/1440p/4K DPI and 60/120 Hz, file-format, ClientSecurity and installer gates remain incomplete."
        )
    }
    $evidencePath = Join-Path $outputFullPath "shortcuts-gui-evidence.json"
    $evidence | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    Write-Host "Windows Avalonia shortcut GUI acceptance: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    Stop-TrackedClient $second
    Stop-TrackedClient $first
}
