param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$AudioFixturePath = "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 240)][int]$TimeoutSeconds = 150
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia Playtest GUI capture requires PowerShell Core on Windows."
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
        try { if (& $Condition) { return } } catch { }
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

public static class LumaChartPlaytestGuiNative
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
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);
}
'@

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 240000)][int]$TimeoutMilliseconds = 10000
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

function Find-ElementByIdOnce([int]$ProcessId, [string]$AutomationId) {
    try {
        return Find-ElementById -ProcessId $ProcessId -AutomationId $AutomationId -TimeoutMilliseconds 150
    }
    catch { return $null }
}

function Invoke-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Toggle-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.TogglePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose TogglePattern."
    }
    ([Windows.Automation.TogglePattern]$pattern).Toggle()
}

function Get-ToggleState($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.TogglePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose TogglePattern."
    }
    return ([Windows.Automation.TogglePattern]$pattern).Current.ToggleState.ToString()
}

function Set-RangeValue($Element, [double]$Value) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.RangeValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose RangeValuePattern."
    }
    ([Windows.Automation.RangeValuePattern]$pattern).SetValue($Value)
}

function Get-RangeValue($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.RangeValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose RangeValuePattern."
    }
    return [double]([Windows.Automation.RangeValuePattern]$pattern).Current.Value
}

function Select-ComboItem($Combo, [string]$Name) {
    $expand = $null
    if ($Combo.TryGetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$expand)) {
        ([Windows.Automation.ExpandCollapsePattern]$expand).Expand()
        Start-Sleep -Milliseconds 150
    }
    $nameCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty, $Name)
    $item = $Combo.FindFirst([Windows.Automation.TreeScope]::Descendants, $nameCondition)
    if (-not $item) { throw "Combo item '$Name' was not found." }
    $selection = $null
    if (-not $item.TryGetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern, [ref]$selection)) {
        throw "Combo item '$Name' does not expose SelectionItemPattern."
    }
    ([Windows.Automation.SelectionItemPattern]$selection).Select()
    if ($expand) { ([Windows.Automation.ExpandCollapsePattern]$expand).Collapse() }
    Start-Sleep -Milliseconds 250
}

function Get-SelectedComboItem($Combo) {
    $selectionPattern = $null
    if ($Combo.TryGetCurrentPattern([Windows.Automation.SelectionPattern]::Pattern, [ref]$selectionPattern)) {
        $selection = ([Windows.Automation.SelectionPattern]$selectionPattern).Current.GetSelection()
        if ($selection.Count -gt 0) { return [string]$selection[0].Current.Name }
    }
    $selectedCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.SelectionItemPattern]::IsSelectedProperty, $true)
    $item = $Combo.FindFirst([Windows.Automation.TreeScope]::Descendants, $selectedCondition)
    if ($item) { return [string]$item.Current.Name }
    return [string]$Combo.Current.Name
}

function Get-ElementName([int]$ProcessId, [string]$AutomationId) {
    return [string](Find-ElementById -ProcessId $ProcessId -AutomationId $AutomationId).Current.Name
}

function Get-ElementHelpText([int]$ProcessId, [string]$AutomationId) {
    return [string](Find-ElementById -ProcessId $ProcessId -AutomationId $AutomationId).Current.HelpText
}

function Get-DiagnosticValue([string]$Text, [string]$Name) {
    $match = [regex]::Match($Text, "(?:^|;\s*)" + [regex]::Escape($Name) + "=([^;]*)")
    if (-not $match.Success) { throw "Diagnostic '$Name' was absent: $Text" }
    return $match.Groups[1].Value.Trim()
}

function Get-DiagnosticDouble([string]$Text, [string]$Name) {
    $value = Get-DiagnosticValue $Text $Name
    return [double]::Parse($value, [Globalization.CultureInfo]::InvariantCulture)
}

function Get-DiagnosticInt64([string]$Text, [string]$Name) {
    $value = Get-DiagnosticValue $Text $Name
    return [int64]::Parse($value, [Globalization.CultureInfo]::InvariantCulture)
}

function Get-DiagnosticBool([string]$Text, [string]$Name) {
    $value = Get-DiagnosticValue $Text $Name
    return [bool]::Parse($value)
}

function Get-ElementRect($Element) {
    $rect = $Element.Current.BoundingRectangle
    if ($rect.Width -le 0 -or $rect.Height -le 0) {
        throw "Element '$($Element.Current.AutomationId)' has invalid bounds."
    }
    return [ordered]@{
        x = [double]$rect.X
        y = [double]$rect.Y
        width = [double]$rect.Width
        height = [double]$rect.Height
        right = [double]$rect.Right
        bottom = [double]$rect.Bottom
    }
}

function Invoke-MouseClick($Element, [double]$XFraction = .5, [double]$YFraction = .5) {
    $rect = Get-ElementRect $Element
    $x = [int][Math]::Round($rect.x + $rect.width * $XFraction)
    $y = [int][Math]::Round($rect.y + $rect.height * $YFraction)
    if (-not [LumaChartPlaytestGuiNative]::SetCursorPos($x, $y)) {
        throw "SetCursorPos failed for '$($Element.Current.AutomationId)'."
    }
    Start-Sleep -Milliseconds 80
    [LumaChartPlaytestGuiNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [LumaChartPlaytestGuiNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 250
}

function Invoke-MouseWheel($Element, [int]$Detents) {
    if ($Detents -eq 0) { return }
    $rect = Get-ElementRect $Element
    $x = [int][Math]::Round($rect.x + $rect.width * .5)
    $y = [int][Math]::Round($rect.y + $rect.height * .5)
    [void][LumaChartPlaytestGuiNative]::SetCursorPos($x, $y)
    Start-Sleep -Milliseconds 100
    $delta = if ($Detents -gt 0) { [int32]120 } else { [int32]-120 }
    $data = [BitConverter]::ToUInt32([BitConverter]::GetBytes($delta), 0)
    for ($index = 0; $index -lt [Math]::Abs($Detents); $index++) {
        [LumaChartPlaytestGuiNative]::mouse_event(0x0800, 0, 0, $data, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 12
    }
    Start-Sleep -Milliseconds 250
}

function Send-Key(
    [IntPtr]$WindowHandle,
    [byte]$VirtualKey,
    $FocusElement = $null,
    [int]$HoldMilliseconds = 45,
    [int]$PostMilliseconds = 180,
    [switch]$SkipActivation) {
    if (-not $SkipActivation) {
        [void][LumaChartPlaytestGuiNative]::ShowWindow($WindowHandle, 9)
        [void][LumaChartPlaytestGuiNative]::BringWindowToTop($WindowHandle)
        [void][LumaChartPlaytestGuiNative]::SetForegroundWindow($WindowHandle)
    }
    if ($FocusElement) {
        $FocusElement.SetFocus()
        Start-Sleep -Milliseconds 100
    }
    [LumaChartPlaytestGuiNative]::keybd_event($VirtualKey, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds $HoldMilliseconds
    [LumaChartPlaytestGuiNative]::keybd_event($VirtualKey, 0, 2, [UIntPtr]::Zero)
    if ($PostMilliseconds -gt 0) { Start-Sleep -Milliseconds $PostMilliseconds }
}

function Wait-MainWindowHandle([Diagnostics.Process]$Process) {
    Wait-Condition -Description "main window for process $($Process.Id)" -Condition {
        $Process.Refresh()
        -not $Process.HasExited -and $Process.MainWindowHandle -ne [IntPtr]::Zero
    }
    return $Process.MainWindowHandle
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

function Get-WindowBounds([IntPtr]$Handle) {
    $rectangle = [LumaChartPlaytestGuiNative+RECT]::new()
    if (-not [LumaChartPlaytestGuiNative]::GetWindowRect($Handle, [ref]$rectangle)) {
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
                if (-not [LumaChartPlaytestGuiNative]::PrintWindow($Handle, $dc, 2)) {
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
            path = [IO.Path]::GetFullPath($Path)
            width = $bounds.width
            height = $bounds.height
            sampledUniqueColors = $colors.Count
        }
    }
    finally { $bitmap.Dispose() }
}

function Get-FileFingerprint([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = [IO.Path]::GetFullPath($Path)
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        length = $item.Length
        lastWriteUtcTicks = $item.LastWriteTimeUtc.Ticks
    }
}

function Assert-FingerprintUnchanged($Before, [string]$Label) {
    $after = Get-FileFingerprint $Before.path
    if ($after.sha256 -cne $Before.sha256 -or $after.length -ne $Before.length -or
        $after.lastWriteUtcTicks -ne $Before.lastWriteUtcTicks) {
        throw "$Label changed during Playtest GUI verification."
    }
    return $after
}

function Start-PlaytestClient {
    param(
        [string]$Profile,
        [string]$ChartPath,
        [string]$LocalDataRoot,
        [string]$EditingRoot,
        [string]$WorkspaceRoot,
        [string]$RuntimeEvidencePath
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
    $start.Environment["LUMACHART_PROFILE"] = $Profile
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $LocalDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $EditingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $WorkspaceRoot
    $start.Environment["LUMACHART_AVALONIA_LIVE_AUTOMATION_DIAGNOSTICS"] = "1"
    $start.Environment["DOTNET_CLI_HOME"] = $dotnetHome
    $start.Environment["NUGET_PACKAGES"] = $nugetPackages
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
    $start.Environment["TEMP"] = $projectTemp
    $start.Environment["TMP"] = $projectTemp
    $process = [Diagnostics.Process]::Start($start)
    if (-not $process) { throw "Unable to start Windows Avalonia Playtest client." }
    return $process
}

function Stop-TrackedClient([Diagnostics.Process]$Process) {
    if (-not $Process -or $Process.HasExited) { return }
    $Process.Kill($true)
    [void]$Process.WaitForExit(5000)
}

function Open-CommandMenu([int]$ProcessId) {
    $fromStart = Find-ElementByIdOnce $ProcessId "Editor.Playtest.FromStart"
    if ($fromStart -and -not $fromStart.Current.IsOffscreen) { return }
    Invoke-Element (Find-ElementById -ProcessId $ProcessId -AutomationId "Editor.CommandMenuToggle" -TimeoutMilliseconds 30000)
    Wait-Condition -Description "Playtest command buttons" -Condition {
        (Find-ElementByIdOnce $ProcessId "Editor.Playtest.FromStart") -and
        (Find-ElementByIdOnce $ProcessId "Editor.Playtest.FromHere")
    }
}

function Wait-PlaytestDialog([int]$ProcessId) {
    $dialog = Find-ElementById -ProcessId $ProcessId -AutomationId "Playtest.Dialog" -TimeoutMilliseconds 30000
    $handle = Get-ElementWindowHandle $dialog
    try {
        Wait-Condition -Description "Playtest audio and diagnostics" -Seconds 45 -Condition {
            $help = Get-ElementHelpText $ProcessId "Playtest.Dialog"
            (Get-DiagnosticInt64 $help "runtimeNotes") -eq 2753 -and
                (Get-DiagnosticBool $help "audioLoaded") -and
                (Get-DiagnosticBool $help "keySoundWarmUpCompleted") -and
                (Get-DiagnosticInt64 $help "frameRateLimit") -eq 1000 -and
                (Get-DiagnosticBool $help "highRateClock") -and
                (Get-DiagnosticBool $help "highRateClockRunning") -and
                (Get-DiagnosticValue $help "highRateClockError") -ceq "none" -and
                (Get-DiagnosticInt64 $help "highRateClockTicks") -ge 20
        }
    }
    catch {
        $failedHelp = Get-ElementHelpText $ProcessId "Playtest.Dialog"
        throw "Playtest audio and diagnostics did not become ready. Diagnostics='$failedHelp'"
    }
    $readyHelp = Get-ElementHelpText $ProcessId "Playtest.Dialog"
    if (-not (Get-DiagnosticBool $readyHelp "keySoundWarmUpSucceeded")) {
        throw "Playtest Key-sound route did not become ready: $readyHelp"
    }
    if ((Get-DiagnosticValue $readyHelp "manualKeySoundOutput") -cne "SharedMusic" -or
        [Math]::Abs(
            (Get-DiagnosticDouble $readyHelp "manualKeySoundConfiguredLatencyMilliseconds") - 40) -gt .001) {
        throw "Music-backed manual Key-sound route is not the shared 40 ms output: $readyHelp"
    }
    if (Get-DiagnosticBool $readyHelp "keySoundIsWarm") {
        throw "Music-backed Playtest unexpectedly created a standalone Key-sound output: $readyHelp"
    }
    return [ordered]@{ element = $dialog; handle = $handle }
}

function Read-PlaytestSettingsUi([int]$ProcessId) {
    $style = Find-ElementById -ProcessId $ProcessId -AutomationId "Playtest.NoteStyle"
    return [ordered]@{
        autoPlay = Get-ToggleState (Find-ElementById -ProcessId $ProcessId -AutomationId "Playtest.AutoPlay")
        style = Get-SelectedComboItem $style
        noteWidth = Get-RangeValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Playtest.NoteWidth")
        noteHeight = Get-RangeValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Playtest.NoteHeight")
        fieldWidth = Get-RangeValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Playtest.FieldWidth")
        scrollSpeed = Get-RangeValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Playtest.ScrollSpeed")
        judgementLine = Get-RangeValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Playtest.JudgementLine")
        bestWindow = Get-RangeValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Playtest.BestWindow")
        greatWindow = Get-RangeValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Playtest.GreatWindow")
        goodWindow = Get-RangeValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Playtest.GoodWindow")
        missWindow = Get-RangeValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Playtest.MissWindow")
        bindings = @(1..4 | ForEach-Object { Get-ElementName $ProcessId "Playtest.Binding.$_" })
    }
}

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$chartFixtureFullPath = Resolve-ExistingFile $ChartFixturePath "Real MC fixture"
$audioFixtureFullPath = Resolve-ExistingFile $AudioFixturePath "Real chart audio fixture"
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
New-Item -ItemType Directory -Path $localDataRoot -Force | Out-Null
$chartJson = Get-Content -Raw -LiteralPath $chartFixtureFullPath | ConvertFrom-Json
$referencedAudio = [string]$chartJson.meta.song.file
if ([IO.Path]::GetFileName($audioFixtureFullPath) -cne $referencedAudio) {
    throw "Audio fixture '$audioFixtureFullPath' does not match MC reference '$referencedAudio'."
}
$workingChart = Join-Path $workingRoot "playtest-resound-real.mc"
$workingAudio = Join-Path $workingRoot $referencedAudio
Copy-Item -LiteralPath $chartFixtureFullPath -Destination $workingChart
Copy-Item -LiteralPath $audioFixtureFullPath -Destination $workingAudio

$fixtureChartBefore = Get-FileFingerprint $chartFixtureFullPath
$fixtureAudioBefore = Get-FileFingerprint $audioFixtureFullPath
$workingChartBefore = Get-FileFingerprint $workingChart
$workingAudioBefore = Get-FileFingerprint $workingAudio

$keySoundSettingsPath = Join-Path $localDataRoot "key-sound-settings.json"
[ordered]@{
    SchemaVersion = 1
    EnableKeySounds = $true
    Volume = .7
    Preset = "Snare"
    CustomFilePath = $null
    PlayLongNoteEndSound = $false
    GlobalOffset = 0
    PerChartOffsets = @{}
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $keySoundSettingsPath -Encoding utf8NoBOM
$editorViewSettingsPath = Join-Path $localDataRoot "editor-view-settings.json"
[ordered]@{
    SchemaVersion = 1
    FrameRateLimit = 1000
} | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $editorViewSettingsPath -Encoding utf8NoBOM

$first = $null
$second = $null
try {
    $runtimePath = Join-Path $guiRoot "playtest-runtime.json"
    $first = Start-PlaytestClient `
        -Profile "windows-avalonia-playtest" `
        -ChartPath $workingChart `
        -LocalDataRoot $localDataRoot `
        -EditingRoot $editingRoot `
        -WorkspaceRoot $workspaceRoot `
        -RuntimeEvidencePath $runtimePath
    $firstHandle = Wait-MainWindowHandle $first
    [void][LumaChartPlaytestGuiNative]::ShowWindow($firstHandle, 3)
    Wait-Condition -Description "first runtime evidence" -Condition {
        Test-Path -LiteralPath $runtimePath -PathType Leaf
    }
    Open-CommandMenu $first.Id
    $fromStart = Find-ElementById -ProcessId $first.Id -AutomationId "Editor.Playtest.FromStart"
    $fromHere = Find-ElementById -ProcessId $first.Id -AutomationId "Editor.Playtest.FromHere"
    if (-not $fromStart.Current.IsEnabled -or -not $fromHere.Current.IsEnabled) {
        throw "One or both Playtest entry points are disabled for the real Resound chart."
    }
    $entryCapture = Capture-Window $firstHandle (Join-Path $guiRoot "playtest-entrypoints.png")

    [void][LumaChartPlaytestGuiNative]::BringWindowToTop($firstHandle)
    [void][LumaChartPlaytestGuiNative]::SetForegroundWindow($firstHandle)
    Start-Sleep -Milliseconds 250
    Invoke-MouseClick $fromStart
    $initialDialog = Wait-PlaytestDialog $first.Id
    $initialHelp = Get-ElementHelpText $first.Id "Playtest.Dialog"
    if ([Math]::Abs((Get-DiagnosticDouble $initialHelp "startMilliseconds")) -gt .001) {
        throw "From-start Playtest did not start at 0 ms."
    }
    if ((Get-DiagnosticInt64 $initialHelp "perNoteControls") -ne 0 -or
        -not (Get-DiagnosticBool $initialHelp "singleCustomControl") -or
        -not (Get-DiagnosticBool $initialHelp "clipped")) {
        throw "Playtest dialog violated the single-control/culling contract."
    }
    $initialPauseName = Get-ElementName $first.Id "Playtest.Pause"
    if ($initialPauseName -notmatch "开始") {
        throw "Playtest did not open in the WPF waiting state. PauseName='$initialPauseName'; Diagnostics='$initialHelp'"
    }
    $initialCapture = Capture-Window $initialDialog.handle (Join-Path $guiRoot "playtest-initial.png")

    Send-Key $initialDialog.handle 0x0D
    Wait-Condition -Description "Enter starts Playtest" -Condition {
        (Get-ElementName $first.Id "Playtest.Pause") -match "暂停" -and
        (Get-DiagnosticBool (Get-ElementHelpText $first.Id "Playtest.Dialog") "playing")
    }
    Wait-Condition -Description "real Resound AutoPlay judgement and Key-sound output" -Seconds 20 -Condition {
        $help = Get-ElementHelpText $first.Id "Playtest.Dialog"
        (Get-DiagnosticInt64 $help "combo") -ge 1 -and
        (Get-DiagnosticInt64 $help "judged") -ge 1 -and
        (Get-DiagnosticInt64 $help "keySoundAccepted") -ge 1
    }
    Wait-Condition -Description "1000 FPS Playtest independent clock HUD" -Seconds 10 -Condition {
        $fps = Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.Fps"
        [string]$fps.Current.Name -match "^时钟采样 [1-9][0-9]* · 画面更新 [1-9][0-9]*$" -and
            [string]$fps.Current.HelpText -like "FrameRateLimit=1000; HighRateClock=True; AudioClockIndependent=true"
    }
    $frameRateHudName = Get-ElementName $first.Id "Playtest.Fps"
    $frameRateHudHelp = Get-ElementHelpText $first.Id "Playtest.Fps"
    $autoHelp = Get-ElementHelpText $first.Id "Playtest.Dialog"
    $autoCapture = Capture-Window $initialDialog.handle (Join-Path $guiRoot "playtest-autoplay.png")
    Send-Key $initialDialog.handle 0x0D
    Wait-Condition -Description "second Enter pauses Playtest" -Condition {
        -not (Get-DiagnosticBool (Get-ElementHelpText $first.Id "Playtest.Dialog") "playing") -and
        (Get-ElementName $first.Id "Playtest.Pause") -match "继续"
    }

    $autoPlay = Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.AutoPlay"
    Toggle-Element $autoPlay
    Wait-Condition -Description "AutoPlay disabled" -Condition {
        (Get-ToggleState $autoPlay) -eq "Off" -and
        -not (Get-DiagnosticBool (Get-ElementHelpText $first.Id "Playtest.Dialog") "autoPlay")
    }
    $style = Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.NoteStyle"
    Select-ComboItem $style "球"
    Set-RangeValue (Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.NoteWidth") 73
    Set-RangeValue (Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.NoteHeight") 41
    Set-RangeValue (Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.FieldWidth") 777
    Set-RangeValue (Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.ScrollSpeed") 913
    Set-RangeValue (Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.JudgementLine") 79
    Set-RangeValue (Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.BestWindow") 31
    Set-RangeValue (Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.GreatWindow") 63
    Set-RangeValue (Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.GoodWindow") 107
    Set-RangeValue (Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.MissWindow") 181
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.Binding.1")
    Start-Sleep -Milliseconds 150
    Send-Key $initialDialog.handle 0x4B
    Wait-Condition -Description "K binding conflict swaps lane 1 and lane 4" -Condition {
        (Get-ElementName $first.Id "Playtest.Binding.1") -match "K" -and
        (Get-ElementName $first.Id "Playtest.Binding.4") -match "D"
    }
    Start-Sleep -Milliseconds 500
    $configuredUi = Read-PlaytestSettingsUi $first.Id
    $configuredUi.style = Get-DiagnosticValue `
        (Get-ElementHelpText $first.Id "Playtest.Dialog") "noteStyle"
    $configuredCapture = Capture-Window $initialDialog.handle (Join-Path $guiRoot "playtest-configured.png")

    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.Restart")
    Wait-Condition -Description "restart returns to waiting state" -Condition {
        $help = Get-ElementHelpText $first.Id "Playtest.Dialog"
        -not (Get-DiagnosticBool $help "playing") -and
        -not (Get-DiagnosticBool $help "preparing") -and
        (Get-DiagnosticInt64 $help "combo") -eq 0 -and
        (Get-ElementName $first.Id "Playtest.Pause") -match "开始"
    }
    $firstNote = $chartJson.note | Where-Object { $_.column -ne $null } | Select-Object -First 1
    $firstTiming = @($chartJson.time)[0]
    $beat = [double]$firstNote.beat[0] + [double]$firstNote.beat[1] / [double]$firstNote.beat[2]
    $firstNoteMilliseconds = $beat * 60000 / [double]$firstTiming.bpm - [double]$firstTiming.delay
    Send-Key $initialDialog.handle 0x1B
    Wait-Condition -Description "Esc closes from-start Playtest" -Condition {
        -not (Find-ElementByIdOnce $first.Id "Playtest.Dialog")
    }
    $settingsPath = Join-Path $localDataRoot "playtest-settings.json"
    Wait-Condition -Description "Playtest settings persistence" -Condition {
        Test-Path -LiteralPath $settingsPath -PathType Leaf
    }
    $persistedSettings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
    if ($persistedSettings.SchemaVersion -ne 1 -or $persistedSettings.AutoPlay -ne $false -or
        $persistedSettings.NoteStyle -cne "Circle" -or $persistedSettings.NoteWidth -ne .73 -or
        $persistedSettings.NoteHeight -ne 41 -or $persistedSettings.PlayfieldWidth -ne 777 -or
        $persistedSettings.ScrollSpeed -ne 913 -or $persistedSettings.JudgementLinePosition -ne .79 -or
        $persistedSettings.BestWindowMilliseconds -ne 31 -or
        $persistedSettings.GreatWindowMilliseconds -ne 63 -or
        $persistedSettings.GoodWindowMilliseconds -ne 107 -or
        $persistedSettings.MissWindowMilliseconds -ne 181) {
        throw "Persisted Playtest settings differ from the GUI changes."
    }

    [void][LumaChartPlaytestGuiNative]::BringWindowToTop($firstHandle)
    [void][LumaChartPlaytestGuiNative]::SetForegroundWindow($firstHandle)
    Send-Key $firstHandle 0x24 -HoldMilliseconds 15 -PostMilliseconds 80 -SkipActivation
    # The Windows editor now follows the WPF wheel direction: positive moves
    # forward from Home to the first playable note.
    Invoke-MouseWheel (Find-ElementById -ProcessId $first.Id -AutomationId "Timeline.Surface") 40
    Open-CommandMenu $first.Id
    [void][LumaChartPlaytestGuiNative]::BringWindowToTop($firstHandle)
    [void][LumaChartPlaytestGuiNative]::SetForegroundWindow($firstHandle)
    Start-Sleep -Milliseconds 250
    Invoke-MouseClick (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.Playtest.FromHere")
    $fromHereDialog = Wait-PlaytestDialog $first.Id
    $fromHereHelp = Get-ElementHelpText $first.Id "Playtest.Dialog"
    $fromHereStart = Get-DiagnosticDouble $fromHereHelp "startMilliseconds"
    if ([Math]::Abs($fromHereStart - $firstNoteMilliseconds) -gt 2) {
        throw "From-here Playtest did not start on the first real Note: $fromHereStart vs $firstNoteMilliseconds ms."
    }
    if (Get-DiagnosticBool $fromHereHelp "autoPlay") {
        throw "From-here Playtest unexpectedly reopened with AutoPlay enabled."
    }
    $fromHereCapture = Capture-Window $fromHereDialog.handle (Join-Path $guiRoot "playtest-from-here.png")
    $manualAcceptedBefore = Get-DiagnosticInt64 $fromHereHelp "manualKeySoundAccepted"
    $manualRejectedBefore = Get-DiagnosticInt64 $fromHereHelp "manualKeySoundRejected"
    $keyDownBefore = Get-DiagnosticInt64 $fromHereHelp "keyDownCount"
    $laneAttemptBefore = Get-DiagnosticInt64 $fromHereHelp "lanePressAttemptCount"
    $laneJudgementBefore = Get-DiagnosticInt64 $fromHereHelp "laneJudgementEventCount"
    $manualJudgementBefore = Get-DiagnosticInt64 $fromHereHelp "manualHitJudgementCount"
    [void][LumaChartPlaytestGuiNative]::BringWindowToTop($fromHereDialog.handle)
    [void][LumaChartPlaytestGuiNative]::SetForegroundWindow($fromHereDialog.handle)
    Start-Sleep -Milliseconds 100
    $manualStartWall = [Diagnostics.Stopwatch]::StartNew()
    Send-Key $fromHereDialog.handle 0x0D -HoldMilliseconds 15 -PostMilliseconds 0 -SkipActivation
    Send-Key $fromHereDialog.handle 0x4B -HoldMilliseconds 12 -PostMilliseconds 0 -SkipActivation
    $manualPulseCount = 1
    $manualKeyWallMilliseconds = $manualStartWall.Elapsed.TotalMilliseconds
    try {
        Wait-Condition -Description "physical K manual judgement" -Condition {
            $help = Get-ElementHelpText $first.Id "Playtest.Dialog"
            (Get-DiagnosticInt64 $help "manualHitJudgementCount") -gt $manualJudgementBefore
        }
    }
    catch {
        $failureHelp = Get-ElementHelpText $first.Id "Playtest.Dialog"
        throw "Physical K did not produce a manual judgement. Diagnostics: $failureHelp"
    }
    $manualHelp = Get-ElementHelpText $first.Id "Playtest.Dialog"
    if ((Get-DiagnosticInt64 $manualHelp "keyDownCount") -le $keyDownBefore -or
        (Get-DiagnosticInt64 $manualHelp "lanePressAttemptCount") -le $laneAttemptBefore -or
        (Get-DiagnosticInt64 $manualHelp "laneJudgementEventCount") -le $laneJudgementBefore -or
        (Get-DiagnosticValue $manualHelp "lastResolvedKey") -cne "K") {
        throw "Physical K input diagnostics did not prove resolved lane routing: $manualHelp"
    }
    if (Get-DiagnosticBool $manualHelp "autoPlay") {
        throw "Physical manual input unexpectedly re-enabled AutoPlay."
    }
    $manualGrade = Get-DiagnosticValue $manualHelp "lastManualHitGrade"
    if ($manualGrade -notin @("Best", "Great", "Good")) {
        throw "Physical K input did not produce BEST/GREAT/GOOD: $manualHelp"
    }
    $manualOffsetMilliseconds = Get-DiagnosticDouble $manualHelp "lastManualHitOffsetMilliseconds"
    if ([Math]::Abs($manualOffsetMilliseconds) -ge 107) {
        throw "Physical K manual judgement exceeded the configured GOOD window: $manualHelp"
    }
    $manualOffset = Get-ElementName $first.Id "Playtest.Offset"
    if ($manualOffset -notmatch "BEST|GREAT|GOOD") {
        throw "Physical K diagnostics passed but the visible offset label did not: $manualOffset"
    }
    $manualKeyTimestamp = $firstNoteMilliseconds + $manualOffsetMilliseconds
    try {
        Wait-Condition -Description "manual Key-sound submission" -Condition {
            $help = Get-ElementHelpText $first.Id "Playtest.Dialog"
            (Get-DiagnosticInt64 $help "manualKeySoundAccepted") -gt $manualAcceptedBefore
        }
    }
    catch {
        $failureHelp = Get-ElementHelpText $first.Id "Playtest.Dialog"
        $rejected = Get-DiagnosticInt64 $failureHelp "manualKeySoundRejected"
        throw "Manual judgement succeeded but shared Key-sound submission failed (rejected before=$manualRejectedBefore, after=$rejected). Diagnostics: $failureHelp"
    }
    $manualHelp = Get-ElementHelpText $first.Id "Playtest.Dialog"
    if ((Get-DiagnosticValue $manualHelp "manualKeySoundOutput") -cne "SharedMusic") {
        throw "Physical manual hit did not remain on the shared music output: $manualHelp"
    }
    $manualCapture = Capture-Window $fromHereDialog.handle (Join-Path $guiRoot "playtest-manual.png")

    Send-Key $fromHereDialog.handle 0x0D
    Wait-Condition -Description "manual Playtest pause" -Condition {
        -not (Get-DiagnosticBool (Get-ElementHelpText $first.Id "Playtest.Dialog") "playing")
    }
    if (Get-DiagnosticBool (Get-ElementHelpText $first.Id "Playtest.Dialog") "autoPlay") {
        throw "Pause shortcut unexpectedly re-enabled AutoPlay."
    }
    $normalBounds = Get-WindowBounds $fromHereDialog.handle
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.Maximize")
    Wait-Condition -Description "Playtest maximize" -Condition {
        (Get-WindowBounds $fromHereDialog.handle).width -gt $normalBounds.width + 100
    }
    $maximizedBounds = Get-WindowBounds $fromHereDialog.handle
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Playtest.Maximize")
    Wait-Condition -Description "Playtest restore" -Condition {
        (Get-WindowBounds $fromHereDialog.handle).width -lt $maximizedBounds.width - 100
    }
    $restoredBounds = Get-WindowBounds $fromHereDialog.handle
    Send-Key $fromHereDialog.handle 0x20
    Wait-Condition -Description "Space starts Playtest without maximizing" -Condition {
        (Get-DiagnosticBool (Get-ElementHelpText $first.Id "Playtest.Dialog") "playing") -and
        (Get-ElementName $first.Id "Playtest.Pause") -match "暂停"
    }
    $spacePlayingBounds = Get-WindowBounds $fromHereDialog.handle
    if ([Math]::Abs($spacePlayingBounds.width - $restoredBounds.width) -gt 2 -or
        [Math]::Abs($spacePlayingBounds.height - $restoredBounds.height) -gt 2) {
        throw "Space transport unexpectedly changed the Playtest window bounds."
    }
    Send-Key $fromHereDialog.handle 0x20
    Wait-Condition -Description "Space pauses Playtest without maximizing" -Condition {
        -not (Get-DiagnosticBool (Get-ElementHelpText $first.Id "Playtest.Dialog") "playing") -and
        (Get-ElementName $first.Id "Playtest.Pause") -match "继续"
    }
    $spacePausedBounds = Get-WindowBounds $fromHereDialog.handle
    if ([Math]::Abs($spacePausedBounds.width - $restoredBounds.width) -gt 2 -or
        [Math]::Abs($spacePausedBounds.height - $restoredBounds.height) -gt 2) {
        throw "Second Space transport unexpectedly changed the Playtest window bounds."
    }
    if (Get-DiagnosticBool (Get-ElementHelpText $first.Id "Playtest.Dialog") "autoPlay") {
        throw "Maximize/restore unexpectedly re-enabled AutoPlay."
    }

    Send-Key $fromHereDialog.handle 0x1B
    Wait-Condition -Description "Esc closes from-here Playtest" -Condition {
        -not (Find-ElementByIdOnce $first.Id "Playtest.Dialog")
    }
    $afterManualSettings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
    if ($afterManualSettings.AutoPlay -ne $false) {
        throw "Closing the from-here Playtest persisted AutoPlay=true unexpectedly."
    }

    $cacheWorkingFiles = @(Get-ChildItem -LiteralPath $editingRoot -Recurse -File -Filter "working.mc")
    if ($cacheWorkingFiles.Count -lt 1 -or $cacheWorkingFiles[0].Length -le 0) {
        throw "Playtest did not leave a valid editor working-cache copy."
    }
    Stop-TrackedClient $first
    $first = $null

    $reopenRuntimePath = Join-Path $guiRoot "playtest-reopened-runtime.json"
    $second = Start-PlaytestClient `
        -Profile "windows-avalonia-playtest-reopened" `
        -ChartPath $workingChart `
        -LocalDataRoot $localDataRoot `
        -EditingRoot $editingRoot `
        -WorkspaceRoot $workspaceRoot `
        -RuntimeEvidencePath $reopenRuntimePath
    $secondHandle = Wait-MainWindowHandle $second
    [void][LumaChartPlaytestGuiNative]::ShowWindow($secondHandle, 3)
    Wait-Condition -Description "second runtime evidence" -Condition {
        Test-Path -LiteralPath $reopenRuntimePath -PathType Leaf
    }
    Open-CommandMenu $second.Id
    Invoke-Element (Find-ElementById -ProcessId $second.Id -AutomationId "Editor.Playtest.FromStart")
    $reopenedDialog = Wait-PlaytestDialog $second.Id
    $reopenedHelp = Get-ElementHelpText $second.Id "Playtest.Dialog"
    if ((Get-DiagnosticInt64 $reopenedHelp "frameRateLimit") -ne 1000 -or
        -not (Get-DiagnosticBool $reopenedHelp "highRateClock") -or
        (Get-DiagnosticInt64 $reopenedHelp "highRateClockTicks") -lt 20) {
        throw "Reopened Playtest did not retain the 1000 FPS independent clock: $reopenedHelp"
    }
    $reopenedUi = Read-PlaytestSettingsUi $second.Id
    $reopenedUi.style = Get-DiagnosticValue $reopenedHelp "noteStyle"
    if ($reopenedUi.autoPlay -ne "Off" -or $reopenedUi.style -cne "Circle" -or
        $reopenedUi.noteWidth -ne 73 -or $reopenedUi.noteHeight -ne 41 -or
        $reopenedUi.fieldWidth -ne 777 -or $reopenedUi.scrollSpeed -ne 913 -or
        $reopenedUi.judgementLine -ne 79 -or $reopenedUi.bestWindow -ne 31 -or
        $reopenedUi.greatWindow -ne 63 -or $reopenedUi.goodWindow -ne 107 -or
        $reopenedUi.missWindow -ne 181 -or
        $reopenedUi.bindings[0] -notmatch "K" -or $reopenedUi.bindings[3] -notmatch "D") {
        throw "Second process did not recover the Playtest GUI settings and swapped bindings: " +
            ($reopenedUi | ConvertTo-Json -Depth 5 -Compress)
    }
    $reopenedCapture = Capture-Window $reopenedDialog.handle (Join-Path $guiRoot "playtest-reopened.png")
    Send-Key $reopenedDialog.handle 0x1B
    Wait-Condition -Description "Esc closes reopened Playtest" -Condition {
        -not (Find-ElementByIdOnce $second.Id "Playtest.Dialog")
    }

    $fixtureChartAfter = Assert-FingerprintUnchanged $fixtureChartBefore "Real source MC"
    $fixtureAudioAfter = Assert-FingerprintUnchanged $fixtureAudioBefore "Real source audio"
    $workingChartAfter = Assert-FingerprintUnchanged $workingChartBefore "Isolated MC"
    $workingAudioAfter = Assert-FingerprintUnchanged $workingAudioBefore "Isolated audio"

    $screenshots = @{}
    foreach ($file in Get-ChildItem -LiteralPath $guiRoot -File -Filter "*.png") {
        $screenshots[$file.BaseName] = [ordered]@{
            path = $file.FullName
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            bytes = $file.Length
        }
    }
    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.playtest-gui-evidence.v1"
        generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        platformScope = "Windows-only"
        applicationPath = $applicationFullPath
        applicationSha256 = (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
        fixture = [ordered]@{
            chartBefore = $fixtureChartBefore
            chartAfter = $fixtureChartAfter
            audioBefore = $fixtureAudioBefore
            audioAfter = $fixtureAudioAfter
            isolatedChartBefore = $workingChartBefore
            isolatedChartAfter = $workingChartAfter
            isolatedAudioBefore = $workingAudioBefore
            isolatedAudioAfter = $workingAudioAfter
        }
        entryPoints = [ordered]@{
            fromStartEnabled = $true
            fromHereEnabled = $true
            fromStartMilliseconds = Get-DiagnosticDouble $initialHelp "startMilliseconds"
            fromHereMilliseconds = $fromHereStart
        }
        frameRate = [ordered]@{
            selected = 1000
            presetPersistedPath = $editorViewSettingsPath
            highRateClock = $true
            audioClockIndependent = $true
            firstDialogHud = $frameRateHudName
            firstDialogHudHelpText = $frameRateHudHelp
            firstDialogClockTicks = Get-DiagnosticInt64 $autoHelp "highRateClockTicks"
            reopenedClockTicks = Get-DiagnosticInt64 $reopenedHelp "highRateClockTicks"
            persistedAcrossRestart = $true
        }
        initial = [ordered]@{
            waitingName = "开始"
            runtimeNotes = Get-DiagnosticInt64 $initialHelp "runtimeNotes"
            keyCount = Get-DiagnosticInt64 $initialHelp "keyCount"
            audioLoaded = Get-DiagnosticBool $initialHelp "audioLoaded"
            keySoundWarmUpCompleted = Get-DiagnosticBool $initialHelp "keySoundWarmUpCompleted"
            keySoundWarmUpSucceeded = Get-DiagnosticBool $initialHelp "keySoundWarmUpSucceeded"
            keySoundIsWarm = Get-DiagnosticBool $initialHelp "keySoundIsWarm"
            perNoteControls = Get-DiagnosticInt64 $initialHelp "perNoteControls"
            singleCustomControl = Get-DiagnosticBool $initialHelp "singleCustomControl"
            clipped = Get-DiagnosticBool $initialHelp "clipped"
            workingCopy = Get-DiagnosticValue $initialHelp "workingCopy"
        }
        keyboard = [ordered]@{
            enterStartedAndPaused = $true
            escapeClosedThreeDialogs = $true
            physicalManualKey = "K"
            physicalManualKeyWallMilliseconds = $manualKeyWallMilliseconds
            physicalManualKeyTimestampMilliseconds = $manualKeyTimestamp
            physicalManualPulseCount = $manualPulseCount
            firstNoteMilliseconds = $firstNoteMilliseconds
            manualOffsetText = $manualOffset
            conflictSwap = @("K", "F", "J", "D")
        }
        autoPlay = [ordered]@{
            combo = Get-DiagnosticInt64 $autoHelp "combo"
            judged = Get-DiagnosticInt64 $autoHelp "judged"
            accuracy = Get-DiagnosticDouble $autoHelp "accuracy"
            keySoundAccepted = Get-DiagnosticInt64 $autoHelp "keySoundAccepted"
            keySoundRejected = Get-DiagnosticInt64 $autoHelp "keySoundRejected"
            autoKeySoundAccepted = Get-DiagnosticInt64 $autoHelp "autoKeySoundAccepted"
            autoKeySoundRejected = Get-DiagnosticInt64 $autoHelp "autoKeySoundRejected"
        }
        manual = [ordered]@{
            combo = Get-DiagnosticInt64 $manualHelp "combo"
            judged = Get-DiagnosticInt64 $manualHelp "judged"
            accuracy = Get-DiagnosticDouble $manualHelp "accuracy"
            grade = Get-DiagnosticValue $manualHelp "lastManualHitGrade"
            offsetMilliseconds = Get-DiagnosticDouble $manualHelp "lastManualHitOffsetMilliseconds"
            resolvedKey = Get-DiagnosticValue $manualHelp "lastResolvedKey"
            keyDownCount = Get-DiagnosticInt64 $manualHelp "keyDownCount"
            lanePressAttemptCount = Get-DiagnosticInt64 $manualHelp "lanePressAttemptCount"
            laneJudgementEventCount = Get-DiagnosticInt64 $manualHelp "laneJudgementEventCount"
            manualHitJudgementCount = Get-DiagnosticInt64 $manualHelp "manualHitJudgementCount"
            keySoundAccepted = Get-DiagnosticInt64 $manualHelp "keySoundAccepted"
            keySoundRejected = Get-DiagnosticInt64 $manualHelp "keySoundRejected"
            manualKeySoundAccepted = Get-DiagnosticInt64 $manualHelp "manualKeySoundAccepted"
            manualKeySoundRejected = Get-DiagnosticInt64 $manualHelp "manualKeySoundRejected"
            keySoundIsWarm = Get-DiagnosticBool $manualHelp "keySoundIsWarm"
            keySoundLastError = Get-DiagnosticValue $manualHelp "keySoundLastError"
            output = Get-DiagnosticValue $manualHelp "manualKeySoundOutput"
            configuredOutputLatencyMilliseconds =
                Get-DiagnosticDouble $manualHelp "manualKeySoundConfiguredLatencyMilliseconds"
            measuredOutputLatencyMilliseconds =
                Get-DiagnosticDouble $manualHelp "audioOutputLatencyMilliseconds"
        }
        settings = [ordered]@{
            configured = $configuredUi
            reopened = $reopenedUi
            persistedPath = $settingsPath
            persistedSha256 = (Get-FileHash -LiteralPath $settingsPath -Algorithm SHA256).Hash
            secondProcessRecovered = $true
        }
        window = [ordered]@{
            normal = $normalBounds
            maximized = $maximizedBounds
            restored = $restoredBounds
        }
        cache = [ordered]@{
            workingFiles = @($cacheWorkingFiles | ForEach-Object {
                [ordered]@{ path = $_.FullName; bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
            })
        }
        captures = [ordered]@{
            entryPoints = $entryCapture
            initial = $initialCapture
            autoPlay = $autoCapture
            configured = $configuredCapture
            manual = $manualCapture
            fromHere = $fromHereCapture
            reopened = $reopenedCapture
        }
        screenshots = $screenshots
        runtimeEvidence = [ordered]@{
            first = $runtimePath
            second = $reopenRuntimePath
        }
        limitations = @(
            "Key-sound evidence proves the real output service accepted overlay submissions; it is not loopback/audible certification.",
            "This single-monitor PrintWindow run is not the final 1080p/1440p/4K, multi-DPI, 60/120 Hz or WPF A/B certification."
        )
    }
    $evidencePath = Join-Path $guiRoot "playtest-gui-evidence.json"
    $evidence | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Write-Host "Windows Avalonia Playtest GUI capture: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    Stop-TrackedClient $first
    Stop-TrackedClient $second
}
