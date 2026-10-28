param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia settings/cache GUI capture requires PowerShell Core on Windows."
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

public static class LumaChartSettingsCacheGuiNative
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
    public static extern void keybd_event(
        byte virtualKey,
        byte scanCode,
        uint flags,
        UIntPtr extraInfo);
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

function Find-ElementByName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [ValidateRange(100, 180000)][int]$TimeoutMilliseconds = 10000
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $nameCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty, $Name)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children, $processCondition)
            foreach ($root in $roots) {
                if ([string]$root.Current.Name -ceq $Name) { return $root }
                $candidate = $root.FindFirst([Windows.Automation.TreeScope]::Descendants, $nameCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation name '$Name' for process $ProcessId."
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
    $expand = $null
    if ($Combo.TryGetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$expand)) {
        ([Windows.Automation.ExpandCollapsePattern]$expand).Expand()
        Start-Sleep -Milliseconds 150
        $selectedCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.SelectionItemPattern]::IsSelectedProperty, $true)
        $item = $Combo.FindFirst([Windows.Automation.TreeScope]::Descendants, $selectedCondition)
        ([Windows.Automation.ExpandCollapsePattern]$expand).Collapse()
        if ($item) { return [string]$item.Current.Name }
    }
    return [string]$Combo.Current.Name
}

function Scroll-ElementIntoView($Element) {
    $pattern = $null
    if ($Element.TryGetCurrentPattern([Windows.Automation.ScrollItemPattern]::Pattern, [ref]$pattern)) {
        ([Windows.Automation.ScrollItemPattern]$pattern).ScrollIntoView()
    }
    try { $Element.SetFocus() } catch { }
    Start-Sleep -Milliseconds 250
}

function Get-RangeValue($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.RangeValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose RangeValuePattern."
    }
    return ([Windows.Automation.RangeValuePattern]$pattern).Current.Value
}

function Set-RangeValue($Element, [double]$Value) {
    Scroll-ElementIntoView $Element
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.RangeValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose RangeValuePattern."
    }
    ([Windows.Automation.RangeValuePattern]$pattern).SetValue($Value)
    Wait-Condition -Description "range value '$Value' for '$($Element.Current.AutomationId)'" -Seconds 10 -Condition {
        [Math]::Abs((Get-RangeValue $Element) - $Value) -lt .001
    }
}

function Set-ToggleValue($Element, [bool]$Checked) {
    Scroll-ElementIntoView $Element
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.TogglePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose TogglePattern."
    }
    $toggle = [Windows.Automation.TogglePattern]$pattern
    $wanted = if ($Checked) {
        [Windows.Automation.ToggleState]::On
    } else {
        [Windows.Automation.ToggleState]::Off
    }
    if ($toggle.Current.ToggleState -ne $wanted) { $toggle.Toggle() }
    Wait-Condition -Description "toggle '$Checked' for '$($Element.Current.AutomationId)'" -Seconds 10 -Condition {
        $current = $null
        $Element.TryGetCurrentPattern([Windows.Automation.TogglePattern]::Pattern, [ref]$current) -and
            ([Windows.Automation.TogglePattern]$current).Current.ToggleState -eq $wanted
    }
}

function Get-ToggleValue($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.TogglePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose TogglePattern."
    }
    return ([Windows.Automation.TogglePattern]$pattern).Current.ToggleState -eq
        [Windows.Automation.ToggleState]::On
}

function Get-DescendantText($Element) {
    $condition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ControlTypeProperty,
        [Windows.Automation.ControlType]::Text)
    $items = $Element.FindAll([Windows.Automation.TreeScope]::Descendants, $condition)
    $names = for ($index = 0; $index -lt $items.Count; $index++) {
        [string]$items.Item($index).Current.Name
    }
    return ($names -join " | ")
}

function Wait-MainWindowHandle([Diagnostics.Process]$Process) {
    Wait-Condition -Description "main window for process $($Process.Id)" -Condition {
        $Process.Refresh()
        -not $Process.HasExited -and $Process.MainWindowHandle -ne [IntPtr]::Zero
    }
    return $Process.MainWindowHandle
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartSettingsCacheGuiNative+RECT]::new()
    if (-not [LumaChartSettingsCacheGuiNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 300 -or $height -lt 180) { throw "Window has invalid bounds: ${width}x${height}." }
    $bitmap = [Drawing.Bitmap]::new($width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $dc = $graphics.GetHdc()
            try {
                if (-not [LumaChartSettingsCacheGuiNative]::PrintWindow($Handle, $dc, 2)) {
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
                    [Math]::Min($width - 1, [int](($x + .5) * $width / 16)),
                    [Math]::Min($height - 1, [int](($y + .5) * $height / 16)))
                [void]$colors.Add($pixel.ToArgb())
            }
        }
        if ($colors.Count -lt 6) { throw "Screenshot is near-uniform: $($colors.Count) sampled colors." }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{ width = $width; height = $height; sampledUniqueColors = $colors.Count }
    }
    finally { $bitmap.Dispose() }
}

function Get-ElementWindowHandle($Element) {
    $handle = [IntPtr]::new([int64]$Element.Current.NativeWindowHandle)
    if ($handle -eq [IntPtr]::Zero) {
        throw "Element '$($Element.Current.AutomationId)' did not expose a native window handle."
    }
    return $handle
}

function Start-SettingsClient(
    [string]$Profile,
    [string]$ChartPath,
    [string]$LocalDataRoot,
    [string]$EditingRoot,
    [string]$WorkspaceRoot,
    [string]$RuntimeEvidencePath = "") {
    foreach ($directory in @($LocalDataRoot, $EditingRoot, $WorkspaceRoot)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $applicationFullPath
    $start.UseShellExecute = $false
    $start.WorkingDirectory = Split-Path -Parent $applicationFullPath
    $start.ArgumentList.Add("--evidence-chart")
    $start.ArgumentList.Add($ChartPath)
    $start.ArgumentList.Add("--evidence-focus-settings-cache")
    if (-not [string]::IsNullOrWhiteSpace($RuntimeEvidencePath)) {
        $start.ArgumentList.Add("--evidence-output")
        $start.ArgumentList.Add($RuntimeEvidencePath)
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
    if (-not $process) { throw "Unable to start Windows Avalonia settings/cache client." }
    return $process
}

function Stop-TrackedClient([Diagnostics.Process]$Process) {
    if (-not $Process -or $Process.HasExited) { return }
    # This is an isolated evidence process. Restore intentionally leaves the tab
    # dirty, so a normal close would wait for a user choice in the unsaved dialog.
    $Process.Kill($true)
    [void]$Process.WaitForExit(5000)
}

function Submit-NativeBackupPicker([int]$ProcessId, [string]$Path) {
    $title = "选择 LumaChart 谱面备份"
    $dialog = Find-ElementByName -ProcessId $ProcessId -Name $title -TimeoutMilliseconds 20000
    $edit = $null
    foreach ($id in @("1148", "1001")) {
        $condition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty, $id)
        $candidates = $dialog.FindAll([Windows.Automation.TreeScope]::Descendants, $condition)
        for ($index = 0; $index -lt $candidates.Count; $index++) {
            $candidate = $candidates.Item($index)
            $valuePattern = $null
            if ($candidate.Current.IsEnabled -and
                $candidate.Current.ControlType -eq [Windows.Automation.ControlType]::Edit -and
                $candidate.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$valuePattern)) {
                $edit = $candidate
                break
            }
        }
        if ($edit) { break }
    }
    if (-not $edit) { throw "Native backup picker did not expose filename edit 1148 or 1001." }
    $value = $null
    [void]$edit.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$value)
    ([Windows.Automation.ValuePattern]$value).SetValue($Path)
    Start-Sleep -Milliseconds 300

    $openCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty, "1")
    $buttons = $dialog.FindAll([Windows.Automation.TreeScope]::Descendants, $openCondition)
    $open = $null
    for ($index = 0; $index -lt $buttons.Count; $index++) {
        $candidate = $buttons.Item($index)
        if ($candidate.Current.IsEnabled -and
            $candidate.Current.ControlType -eq [Windows.Automation.ControlType]::Button) {
            $open = $candidate
            break
        }
    }
    if (-not $open) { throw "Native backup picker did not expose the Open button." }
    $openName = [string]$open.Current.Name
    Invoke-Element $open
    return [ordered]@{
        title = $title
        fileNameAutomationId = [string]$edit.Current.AutomationId
        submittedPath = $Path
        openButton = $openName
        submission = "ValuePattern + explicit Open InvokePattern; no synthetic Enter/Escape"
    }
}

function Get-ChartFingerprint($Document) {
    $snapshot = $Document.Clone()
    $snapshot.FilePath = $null
    foreach ($note in $snapshot.Notes) { $note.OnlineCreatorUserId = 0 }
    foreach ($timing in $snapshot.Timing) { $timing.OnlineCreatorUserId = 0 }
    $canonical = [LumaChart.Core.IO.MalodyMcSerializer]::Serialize($snapshot)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($canonical)
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
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
$workingChart = Join-Path $workingRoot "settings-cache-real.mc"
Get-ChildItem -LiteralPath (Split-Path -Parent $chartFixtureFullPath) -File |
    Where-Object {
        -not [IO.Path]::GetFullPath($_.FullName).Equals(
            $chartFixtureFullPath,
            [StringComparison]::OrdinalIgnoreCase)
    } |
    Copy-Item -Destination $workingRoot
Copy-Item -LiteralPath $chartFixtureFullPath -Destination $workingChart
$fixtureHashBefore = (Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash
$workingHashBefore = (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash
$wpfViewSettingsPath = Join-Path (
    [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) (
    "LumaChart Studio\view-settings.json")
$wpfViewSettingsExistsBefore = Test-Path -LiteralPath $wpfViewSettingsPath -PathType Leaf
$wpfViewSettingsHashBefore = if ($wpfViewSettingsExistsBefore) {
    (Get-FileHash -LiteralPath $wpfViewSettingsPath -Algorithm SHA256).Hash
} else { $null }

$first = $null
$second = $null
try {
    $first = Start-SettingsClient `
        -Profile "windows-avalonia-settings-cache-first" `
        -ChartPath $workingChart `
        -LocalDataRoot $localDataRoot `
        -EditingRoot $editingRoot `
        -WorkspaceRoot $workspaceRoot
    $firstHandle = Wait-MainWindowHandle $first
    [void][LumaChartSettingsCacheGuiNative]::ShowWindow($firstHandle, 3)
    Select-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Inspector.SettingsTab" -TimeoutMilliseconds 30000)

    $desired = [ordered]@{
        GridLaneWidth = 104.0
        GridBeatHeight = 260.0
        MainEditorHorizontalOffset = -180.0
        NoteWidth = 72.0
        NoteHeight = 38.0
        NoteOpacityPercent = 80.0
        JudgementLinePositionPercent = 73.0
        JudgementLineThickness = 2.5
        JudgementLineOpacityPercent = 70.0
        AutoBackupMinutes = 7.0
        FrameRateLimit = 1000
        MusicVolumePercent = 37.0
        PreservePitch = $true
    }
    foreach ($entry in @(
        @("Settings.GridLaneWidth", $desired.GridLaneWidth),
        @("Settings.MainEditorHorizontalOffset", $desired.MainEditorHorizontalOffset),
        @("Settings.GridBeatHeight", $desired.GridBeatHeight),
        @("Settings.NoteWidth", $desired.NoteWidth),
        @("Settings.NoteHeight", $desired.NoteHeight),
        @("Settings.NoteOpacity", $desired.NoteOpacityPercent),
        @("Settings.JudgementLinePosition", $desired.JudgementLinePositionPercent),
        @("Settings.JudgementLineThickness", $desired.JudgementLineThickness),
        @("Settings.JudgementLineOpacity", $desired.JudgementLineOpacityPercent))) {
        Set-RangeValue `
            (Find-ElementById -ProcessId $first.Id -AutomationId $entry[0] -TimeoutMilliseconds 15000) `
            ([double]$entry[1])
    }
    $autoBackup = Find-ElementById -ProcessId $first.Id -AutomationId "Settings.AutoBackupEnabled"
    Set-ToggleValue $autoBackup $true
    Set-RangeValue `
        (Find-ElementById -ProcessId $first.Id -AutomationId "Settings.AutoBackupMinutes") `
        $desired.AutoBackupMinutes
    $frameRateBox = Find-ElementById -ProcessId $first.Id -AutomationId "FrameRateLimitBox"
    Select-ComboItem $frameRateBox "$($desired.FrameRateLimit) FPS"
    $musicVolume = Find-ElementById -ProcessId $first.Id -AutomationId "Audio.Volume"
    Set-RangeValue $musicVolume $desired.MusicVolumePercent
    $preservePitch = Find-ElementById -ProcessId $first.Id -AutomationId "Audio.PreservePitch"
    Set-ToggleValue $preservePitch $desired.PreservePitch

    $settingsPath = Join-Path $localDataRoot "editor-view-settings.json"
    Wait-Condition -Description "atomically persisted editor settings" -Condition {
        if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) { return $false }
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        [Math]::Abs($settings.GridLaneWidth - $desired.GridLaneWidth) -lt .001 -and
            [Math]::Abs($settings.GridBeatHeight - $desired.GridBeatHeight) -lt .001 -and
            [Math]::Abs($settings.MainEditorHorizontalOffset - $desired.MainEditorHorizontalOffset) -lt .001 -and
            [Math]::Abs($settings.NoteWidth - $desired.NoteWidth) -lt .001 -and
            [Math]::Abs($settings.NoteHeight - $desired.NoteHeight) -lt .001 -and
            [Math]::Abs($settings.NoteOpacity - ($desired.NoteOpacityPercent / 100)) -lt .001 -and
            [Math]::Abs($settings.JudgementLinePosition - ($desired.JudgementLinePositionPercent / 100)) -lt .001 -and
            [Math]::Abs($settings.JudgementLineThickness - $desired.JudgementLineThickness) -lt .001 -and
            [Math]::Abs($settings.JudgementLineOpacity - ($desired.JudgementLineOpacityPercent / 100)) -lt .001 -and
            $settings.AutoBackupEnabled -and
            $settings.AutoBackupMinutes -eq [int]$desired.AutoBackupMinutes -and
            $settings.FrameRateLimit -eq [int]$desired.FrameRateLimit -and
            [Math]::Abs($settings.MusicVolume - ($desired.MusicVolumePercent / 100)) -lt .001 -and
            [bool]$settings.PreservePitch -eq [bool]$desired.PreservePitch
    }
    $persistedSettings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    if (@(Get-ChildItem -LiteralPath $localDataRoot -Filter ".editor-view-settings.json.*.tmp" -Force).Count -ne 0) {
        throw "Atomic editor settings left a temporary file behind."
    }

    $topAnchor = Find-ElementById -ProcessId $first.Id -AutomationId "Settings.EditorViewSection"
    Scroll-ElementIntoView $topAnchor
    $timelineSurface = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Timeline.Surface"
    try { $timelineSurface.SetFocus() } catch { }
    [void][LumaChartSettingsCacheGuiNative]::SetForegroundWindow($firstHandle)
    Start-Sleep -Milliseconds 180
    [LumaChartSettingsCacheGuiNative]::keybd_event(0x24, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [LumaChartSettingsCacheGuiNative]::keybd_event(0x24, 0, 2, [UIntPtr]::Zero)
    Wait-Condition -Description "physical Home shortcut seeks the editor to beat zero" `
        -Seconds 10 -Condition {
            [string](Find-ElementById `
                -ProcessId $first.Id `
                -AutomationId "Timeline.Surface" `
                -TimeoutMilliseconds 1000).Current.HelpText -like
                "*CurrentBeat=0;*"
        }
    $playButton = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Editor.QuickPlayPause"
    Wait-Condition -Description "real chart audio loaded for playback command" -Seconds 30 -Condition {
        $playButton = Find-ElementById `
            -ProcessId $first.Id `
            -AutomationId "Editor.QuickPlayPause" `
            -TimeoutMilliseconds 1000
        $playButton.Current.IsEnabled -and
            [string]$playButton.Current.HelpText -like "*IsLoaded=True*"
    }
    $playbackStarted = $false
    for ($playbackAttempt = 1;
         $playbackAttempt -le 3 -and -not $playbackStarted;
         $playbackAttempt++) {
        $playButton = Find-ElementById `
            -ProcessId $first.Id `
            -AutomationId "Editor.QuickPlayPause" `
            -TimeoutMilliseconds 3000
        Invoke-Element $playButton
        $playbackDeadline = [DateTimeOffset]::UtcNow.AddSeconds(4)
        do {
            Start-Sleep -Milliseconds 150
            $playButton = Find-ElementById `
                -ProcessId $first.Id `
                -AutomationId "Editor.QuickPlayPause" `
                -TimeoutMilliseconds 1000
            if ([string]$playButton.Current.HelpText -like "*IsPlaying=True*") {
                $playbackStarted = $true
                break
            }
        } while ([DateTimeOffset]::UtcNow -lt $playbackDeadline)
    }
    if (-not $playbackStarted) {
        throw "Real chart playback did not enter IsPlaying=True after three explicit attempts."
    }
    Wait-Condition -Description "1000 FPS independent editor clock" -Seconds 20 -Condition {
        $frame = Find-ElementById `
            -ProcessId $first.Id `
            -AutomationId "Editor.FrameRateStatus" `
            -TimeoutMilliseconds 1000
        [string]$frame.Current.Name -match "^时钟采样: [1-9][0-9]* · 画面更新: [1-9][0-9]*$" -and
            [string]$frame.Current.HelpText -like
                "FrameRateLimit=1000; HighRateClock=True; FrameDriver=DispatcherTimer; AudioClockIndependent=true;*"
    }
    $editorFrameRateName = [string](Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Editor.FrameRateStatus").Current.Name
    $editorFrameRateHelp = [string](Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Editor.FrameRateStatus").Current.HelpText
    Scroll-ElementIntoView $frameRateBox
    $settingsTopScreenshot = Join-Path $guiRoot "settings-editor-view-adjusted.png"
    $settingsTopCapture = Capture-Window $firstHandle $settingsTopScreenshot
    $playButton = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Editor.QuickPlayPause" `
        -TimeoutMilliseconds 3000
    Invoke-Element $playButton
    Scroll-ElementIntoView $musicVolume
    $settingsAudioScreenshot = Join-Path $guiRoot "settings-audio-adjusted.png"
    $settingsAudioCapture = Capture-Window $firstHandle $settingsAudioScreenshot

    $documentCacheRoot = Join-Path $editingRoot "desktop-workspace\documents"
    Wait-Condition -Description "opened chart document cache" -Condition {
        (Test-Path -LiteralPath $documentCacheRoot -PathType Container) -and
            @(Get-ChildItem -LiteralPath $documentCacheRoot -Directory).Count -ge 1
    }
    $protectedCache = (Get-ChildItem -LiteralPath $documentCacheRoot -Directory | Select-Object -First 1).FullName
    $protectedWorking = Join-Path $protectedCache "working.mc"
    if (-not (Test-Path -LiteralPath $protectedWorking -PathType Leaf)) {
        throw "The open tab cache does not contain working.mc: $protectedCache"
    }
    $orphanCache = Join-Path $documentCacheRoot "orphan-settings-cache"
    New-Item -ItemType Directory -Path $orphanCache | Out-Null
    Set-Content -LiteralPath (Join-Path $orphanCache "orphan.bin") -Value "orphan" -NoNewline
    $resourceCache = Join-Path $localDataRoot "room-resource-cache"
    $resourceRoom = Join-Path $resourceCache "room-42"
    $resourceFile = Join-Path $resourceRoom "resource.bin"
    New-Item -ItemType Directory -Path $resourceRoom -Force | Out-Null
    Set-Content -LiteralPath $resourceFile -Value "resource" -NoNewline

    $backupButton = Find-ElementById -ProcessId $first.Id -AutomationId "Settings.BackupNow"
    Scroll-ElementIntoView $backupButton
    Invoke-Element $backupButton
    $backupDialog = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Settings.ActionDialog" `
        -TimeoutMilliseconds 20000
    $backupDialogButton = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Settings.ActionDialog.Primary" `
        -TimeoutMilliseconds 20000
    $backupDialogMessage = [string](Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Settings.ActionDialog.Message").Current.Name
    $backupDialogScreenshot = Join-Path $guiRoot "settings-backup-complete-dialog.png"
    $backupDialogCapture = Capture-Window (Get-ElementWindowHandle $backupDialog) $backupDialogScreenshot
    Invoke-Element $backupDialogButton

    $backupRoot = Join-Path $localDataRoot "Backups"
    Wait-Condition -Description "real MC backup archive" -Condition {
        @(Get-ChildItem -LiteralPath $backupRoot -Recurse -File -Filter "*.mcbackup").Count -eq 1
    }
    $backupPath = (Get-ChildItem -LiteralPath $backupRoot -Recurse -File -Filter "*.mcbackup" | Select-Object -First 1).FullName
    if ($backupDialogMessage -cne $backupPath) {
        throw "Backup completion dialog did not expose the generated absolute backup path."
    }

    $restoreButton = Find-ElementById -ProcessId $first.Id -AutomationId "Settings.RestoreBackup"
    Scroll-ElementIntoView $restoreButton
    Invoke-Element $restoreButton
    $nativePicker = Submit-NativeBackupPicker -ProcessId $first.Id -Path $backupPath
    $restoreDialog = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Settings.ActionDialog" `
        -TimeoutMilliseconds 20000
    $restoreDialogButton = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Settings.ActionDialog.Primary" `
        -TimeoutMilliseconds 20000
    $restoreDialogMessage = [string](Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Settings.ActionDialog.Message").Current.Name
    $restoreDialogScreenshot = Join-Path $guiRoot "settings-restore-confirmation-dialog.png"
    $restoreDialogCapture = Capture-Window (Get-ElementWindowHandle $restoreDialog) $restoreDialogScreenshot
    Invoke-Element $restoreDialogButton
    Wait-Condition -Description "restored backup dirty editor tab" -Condition {
        [string](Find-ElementById `
            -ProcessId $first.Id `
            -AutomationId "Settings.BackupCacheStatus" `
            -TimeoutMilliseconds 1000).Current.Name -like "已恢复备份：*"
    }
    $chartTab = Find-ElementById -ProcessId $first.Id -AutomationId "Editor.ChartTab"
    Wait-Condition -Description "unsaved marker after backup restore" -Seconds 10 -Condition {
        [string]$chartTab.Current.HelpText -like "*未保存：是*"
    }
    $dirtyTabText = Get-DescendantText $chartTab
    $dirtyTabHelpText = [string]$chartTab.Current.HelpText
    $restoreStatus = [string](Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Settings.BackupCacheStatus").Current.Name

    Set-ToggleValue `
        (Find-ElementById -ProcessId $first.Id -AutomationId "Settings.Cache.UnopenedEditing") `
        $true
    Set-ToggleValue `
        (Find-ElementById -ProcessId $first.Id -AutomationId "Settings.Cache.OnlineResources") `
        $true
    Set-ToggleValue `
        (Find-ElementById -ProcessId $first.Id -AutomationId "Settings.Cache.Backups") `
        $false
    $cleanButton = Find-ElementById -ProcessId $first.Id -AutomationId "Settings.Cache.CleanSelected"
    Scroll-ElementIntoView (Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Settings.BackupCacheSection")
    Invoke-Element $cleanButton
    $cleanupDialogMessage = [string](Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Settings.ActionDialog.Message" `
        -TimeoutMilliseconds 15000).Current.Name
    Invoke-Element (Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Settings.ActionDialog.Primary")
    Wait-Condition -Description "safe cache cleanup" -Condition {
        [string](Find-ElementById `
            -ProcessId $first.Id `
            -AutomationId "Settings.BackupCacheStatus" `
            -TimeoutMilliseconds 1000).Current.Name -like "已清理 *"
    }
    $cleanupStatus = [string](Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Settings.BackupCacheStatus").Current.Name
    if (Test-Path -LiteralPath $orphanCache) { throw "Unopened editing cache was not deleted." }
    if ((Test-Path -LiteralPath $resourceFile) -or (Test-Path -LiteralPath $resourceRoom)) {
        throw "Offline online-resource cache contents were not deleted."
    }
    if (-not (Test-Path -LiteralPath $protectedWorking -PathType Leaf)) {
        throw "Cache cleanup deleted the open tab working copy."
    }
    if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
        throw "Unselected backup cache was deleted."
    }
    Scroll-ElementIntoView $cleanButton
    $cleanupScreenshot = Join-Path $guiRoot "settings-cache-cleaned.png"
    $cleanupCapture = Capture-Window $firstHandle $cleanupScreenshot
    Stop-TrackedClient $first

    $runtimeEvidencePath = Join-Path $guiRoot "settings-cache-runtime-evidence.json"
    $second = Start-SettingsClient `
        -Profile "windows-avalonia-settings-cache-reopen" `
        -ChartPath $workingChart `
        -LocalDataRoot $localDataRoot `
        -EditingRoot $editingRoot `
        -WorkspaceRoot $workspaceRoot `
        -RuntimeEvidencePath $runtimeEvidencePath
    $secondHandle = Wait-MainWindowHandle $second
    [void][LumaChartSettingsCacheGuiNative]::ShowWindow($secondHandle, 3)
    Select-Element (Find-ElementById -ProcessId $second.Id -AutomationId "Inspector.SettingsTab" -TimeoutMilliseconds 30000)
    Wait-Condition -Description "second-process runtime evidence" -Condition {
        if (-not (Test-Path -LiteralPath $runtimeEvidencePath -PathType Leaf)) { return $false }
        try {
            $runtime = Get-Content -LiteralPath $runtimeEvidencePath -Raw | ConvertFrom-Json
            return $runtime.Schema -ceq "lumachart.windows.avalonia.gui-evidence.v14" -and
                   $runtime.Settings.TimelineMatchesPersistedView -and
                   $runtime.Timeline.Performance.RenderMilliseconds.Samples -ge 240
        }
        catch { return $false }
    }
    $runtime = Get-Content -LiteralPath $runtimeEvidencePath -Raw | ConvertFrom-Json
    if ([Math]::Abs($runtime.Settings.GridLaneWidth - $desired.GridLaneWidth) -ge .001 -or
        [Math]::Abs($runtime.Settings.GridBeatHeight - $desired.GridBeatHeight) -ge .001 -or
        [Math]::Abs($runtime.Settings.MainEditorHorizontalOffset - $desired.MainEditorHorizontalOffset) -ge .001 -or
        [Math]::Abs($runtime.Settings.NoteWidth - $desired.NoteWidth) -ge .001 -or
        [Math]::Abs($runtime.Settings.NoteHeight - $desired.NoteHeight) -ge .001 -or
        [Math]::Abs($runtime.Settings.NoteOpacity - ($desired.NoteOpacityPercent / 100)) -ge .001 -or
        [Math]::Abs($runtime.Settings.JudgementLinePosition - ($desired.JudgementLinePositionPercent / 100)) -ge .001 -or
        [Math]::Abs($runtime.Settings.JudgementLineThickness - $desired.JudgementLineThickness) -ge .001 -or
        [Math]::Abs($runtime.Settings.JudgementLineOpacity - ($desired.JudgementLineOpacityPercent / 100)) -ge .001 -or
        -not $runtime.Settings.AutoBackupEnabled -or
        $runtime.Settings.AutoBackupMinutes -ne [int]$desired.AutoBackupMinutes -or
        [Math]::Abs($runtime.Audio.Volume - ($desired.MusicVolumePercent / 100)) -ge .001 -or
        [bool]$runtime.Audio.PreservePitch -ne [bool]$desired.PreservePitch) {
        throw "Second-process runtime settings differ from the first-process GUI changes."
    }
    $reopenedFrameRateBox = Find-ElementById `
        -ProcessId $second.Id `
        -AutomationId "FrameRateLimitBox" `
        -TimeoutMilliseconds 15000
    $reopenedFrameRateSelection = Get-SelectedComboItem $reopenedFrameRateBox
    if ($runtime.Settings.FrameRateLimit -ne [int]$desired.FrameRateLimit -or
        $reopenedFrameRateSelection -cne "$($desired.FrameRateLimit) FPS") {
        throw "Second-process frame-rate limit did not persist: runtime=" +
            "$($runtime.Settings.FrameRateLimit), UI='$reopenedFrameRateSelection'."
    }
    if (-not $runtime.Settings.SettingsIsolatedFromWpf -or
        -not $runtime.Settings.SettingsFileExists -or
        -not $runtime.Settings.TimelineMatchesPersistedView -or
        $runtime.Settings.BackupFileCount -lt 1 -or
        -not $runtime.Timeline.SingleCustomControl -or
        $runtime.Timeline.PerNoteAvaloniaControlCount -ne 0 -or
        -not $runtime.Timeline.VisibleAreaClipping) {
        throw "Runtime evidence did not prove settings isolation, backup retention and single-surface rendering."
    }
    foreach ($entry in @(
        @("Settings.GridLaneWidth", $desired.GridLaneWidth),
        @("Settings.MainEditorHorizontalOffset", $desired.MainEditorHorizontalOffset),
        @("Settings.GridBeatHeight", $desired.GridBeatHeight),
        @("Settings.NoteWidth", $desired.NoteWidth),
        @("Settings.NoteHeight", $desired.NoteHeight),
        @("Settings.NoteOpacity", $desired.NoteOpacityPercent),
        @("Settings.JudgementLinePosition", $desired.JudgementLinePositionPercent),
        @("Settings.JudgementLineThickness", $desired.JudgementLineThickness),
        @("Settings.JudgementLineOpacity", $desired.JudgementLineOpacityPercent),
        @("Settings.AutoBackupMinutes", $desired.AutoBackupMinutes))) {
        $actual = Get-RangeValue (Find-ElementById `
            -ProcessId $second.Id `
            -AutomationId $entry[0] `
            -TimeoutMilliseconds 15000)
        if ([Math]::Abs($actual - [double]$entry[1]) -ge .001) {
            throw "Second-process UI value '$($entry[0])' was '$actual', expected '$($entry[1])'."
        }
    }
    $reopenedMusicVolume = Find-ElementById `
        -ProcessId $second.Id `
        -AutomationId "Audio.Volume" `
        -TimeoutMilliseconds 15000
    $reopenedPreservePitch = Find-ElementById `
        -ProcessId $second.Id `
        -AutomationId "Audio.PreservePitch" `
        -TimeoutMilliseconds 15000
    $reopenedMusicVolumeValue = [double](Get-RangeValue $reopenedMusicVolume)
    $reopenedPreservePitchValue = [bool](Get-ToggleValue $reopenedPreservePitch)
    if ([Math]::Abs($reopenedMusicVolumeValue - $desired.MusicVolumePercent) -ge .001 -or
        $reopenedPreservePitchValue -ne [bool]$desired.PreservePitch) {
        throw "Second-process audio UI did not restore music volume/preserve-pitch."
    }
    $reopenAnchor = $reopenedFrameRateBox
    Scroll-ElementIntoView $reopenAnchor
    $reopenScreenshot = Join-Path $guiRoot "settings-reopened.png"
    $reopenCapture = Capture-Window $secondHandle $reopenScreenshot
    Stop-TrackedClient $second

    $coreAssembly = Join-Path $projectRoot "LumaChart.Core\bin\Release\net8.0\LumaChart.Core.dll"
    $applicationAssembly = Join-Path $projectRoot "LumaChart.Application\bin\Release\net8.0\LumaChart.Application.dll"
    [void][Reflection.Assembly]::LoadFrom($coreAssembly)
    [void][Reflection.Assembly]::LoadFrom($applicationAssembly)
    $sourceDocument = [LumaChart.Core.IO.MalodyMcSerializer]::Load($workingChart)
    $backupArchive = [LumaChart.Application.Workspaces.ChartBackupArchiveService]::LoadBackup($backupPath)
    $sourceFingerprint = Get-ChartFingerprint $sourceDocument
    $backupFingerprint = Get-ChartFingerprint $backupArchive.Document
    if ($sourceFingerprint -cne $backupFingerprint) {
        throw "Backup restore structure differs from the real MC source."
    }
    $rawBackup = Get-Content -LiteralPath $backupPath -Raw
    if ($rawBackup -cnotmatch '"_luma_backup"' -or
        $backupArchive.Document.UnknownRoot.ContainsKey("_luma_backup")) {
        throw "Backup marker was not private to the archive envelope."
    }

    $fixtureHashAfter = (Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash
    $workingHashAfter = (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash
    if ($fixtureHashAfter -cne $fixtureHashBefore -or $workingHashAfter -cne $workingHashBefore) {
        throw "The immutable fixture or isolated source copy changed during settings/cache acceptance."
    }
    $wpfViewSettingsExistsAfter = Test-Path -LiteralPath $wpfViewSettingsPath -PathType Leaf
    $wpfViewSettingsHashAfter = if ($wpfViewSettingsExistsAfter) {
        (Get-FileHash -LiteralPath $wpfViewSettingsPath -Algorithm SHA256).Hash
    } else { $null }
    if ($wpfViewSettingsExistsAfter -ne $wpfViewSettingsExistsBefore -or
        $wpfViewSettingsHashAfter -cne $wpfViewSettingsHashBefore) {
        throw "Avalonia settings acceptance changed WPF view-settings.json."
    }

    $screenshots = @{}
    foreach ($path in @(
        $settingsTopScreenshot,
        $settingsAudioScreenshot,
        $backupDialogScreenshot,
        $restoreDialogScreenshot,
        $cleanupScreenshot,
        $reopenScreenshot)) {
        $item = Get-Item -LiteralPath $path
        $screenshots[$item.BaseName] = [ordered]@{
            path = $item.FullName
            length = $item.Length
            sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        }
    }
    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.settings-cache-gui-evidence.v2"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("o")
        status = "passed-migration-incomplete"
        windowsAvaloniaOnly = $true
        productionServerMutationPerformed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        ollvmExecutedOrRequired = $false
        chineseImeGlobalEnterEscapeHandlerAdded = $false
        textInputMethod =
            "UIAutomation patterns, explicit buttons and one physical non-text Home key; no synthetic global Enter/Escape"
        physicalNonTextHomeKeyUsed = $true
        fixture = [ordered]@{
            path = $chartFixtureFullPath
            sha256Before = $fixtureHashBefore
            sha256After = $fixtureHashAfter
            unchanged = $true
            isolatedSourcePath = $workingChart
            isolatedSourceSha256Before = $workingHashBefore
            isolatedSourceSha256After = $workingHashAfter
            isolatedSourceUnchanged = $true
        }
        editorView = [ordered]@{
            desired = $desired
            persistedPath = $settingsPath
            persistedSha256 = (Get-FileHash -LiteralPath $settingsPath -Algorithm SHA256).Hash
            atomicTemporaryFileCount = 0
            runtimeMatchesPersisted = [bool]$runtime.Settings.TimelineMatchesPersistedView
            secondProcessUiMatches = $true
            singleTimelineSurface = [bool]$runtime.Timeline.SingleCustomControl
            perNoteAvaloniaControlCount = [int]$runtime.Timeline.PerNoteAvaloniaControlCount
            visibleAreaClipping = [bool]$runtime.Timeline.VisibleAreaClipping
            frameRate = [ordered]@{
                selected = [int]$desired.FrameRateLimit
                firstProcessStatus = $editorFrameRateName
                firstProcessHelpText = $editorFrameRateHelp
                secondProcessSelection = $reopenedFrameRateSelection
                persistedAcrossRestart = $true
                independentHighRateClockObserved = $true
                audioClockIndependent = $true
            }
            audio = [ordered]@{
                desiredMusicVolumePercent = [double]$desired.MusicVolumePercent
                desiredPreservePitch = [bool]$desired.PreservePitch
                persistedMusicVolume = [double]$persistedSettings.MusicVolume
                persistedPreservePitch = [bool]$persistedSettings.PreservePitch
                secondProcessRuntimeMusicVolume = [double]$runtime.Audio.Volume
                secondProcessRuntimePreservePitch = [bool]$runtime.Audio.PreservePitch
                secondProcessUiMusicVolumePercent = $reopenedMusicVolumeValue
                secondProcessUiPreservePitch = $reopenedPreservePitchValue
                persistedAcrossRestart = $true
            }
        }
        wpfIsolation = [ordered]@{
            path = $wpfViewSettingsPath
            existedBefore = $wpfViewSettingsExistsBefore
            existedAfter = $wpfViewSettingsExistsAfter
            sha256Before = $wpfViewSettingsHashBefore
            sha256After = $wpfViewSettingsHashAfter
            unchanged = $true
        }
        backupRestore = [ordered]@{
            backupPath = $backupPath
            backupSha256 = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash
            backupDialogMessage = $backupDialogMessage
            nativePicker = $nativePicker
            restoreConfirmationMessage = $restoreDialogMessage
            restoreStatus = $restoreStatus
            restoredTabText = $dirtyTabText
            restoredTabHelpText = $dirtyTabHelpText
            restoredTabMarkedUnsaved = $dirtyTabHelpText -like "*未保存：是*"
            privateMarkerPresentInArchive = $true
            privateMarkerRemovedOnLoad = $true
            sourceStructureFingerprint = $sourceFingerprint
            restoredStructureFingerprint = $backupFingerprint
            structuredMatch = $true
        }
        cacheCleanup = [ordered]@{
            confirmationMessage = $cleanupDialogMessage
            status = $cleanupStatus
            protectedOpenTabCache = $protectedCache
            protectedOpenTabWorkingCopyExists = $true
            orphanEditingCache = $orphanCache
            orphanEditingCacheDeleted = $true
            onlineResourceCache = $resourceCache
            onlineResourceCacheRootRetained = Test-Path -LiteralPath $resourceCache -PathType Container
            onlineResourceCacheContentsDeleted = $true
            unselectedBackupRetained = $true
        }
        runtimeEvidence = [ordered]@{
            path = $runtimeEvidencePath
            sha256 = (Get-FileHash -LiteralPath $runtimeEvidencePath -Algorithm SHA256).Hash
            schema = [string]$runtime.Schema
            settings = $runtime.Settings
            timeline = [ordered]@{
                sessionIsDirty = [bool]$runtime.Timeline.SessionIsDirty
                singleCustomControl = [bool]$runtime.Timeline.SingleCustomControl
                perNoteAvaloniaControlCount = [int]$runtime.Timeline.PerNoteAvaloniaControlCount
                visibleAreaClipping = [bool]$runtime.Timeline.VisibleAreaClipping
                renderMilliseconds = $runtime.Timeline.Performance.RenderMilliseconds
                frameIntervalMilliseconds = $runtime.Timeline.Performance.FrameIntervalMilliseconds
                inputToRenderMilliseconds = $runtime.Timeline.Performance.InputToRenderMilliseconds
            }
        }
        captures = [ordered]@{
            editorViewAdjusted = $settingsTopCapture
            backupCompleteDialog = $backupDialogCapture
            restoreConfirmationDialog = $restoreDialogCapture
            cacheCleaned = $cleanupCapture
            reopened = $reopenCapture
        }
        screenshots = $screenshots
        completion = [ordered]@{
            functionMatrixAllPassed = $false
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
        }
        remainingDifferences = @(
            "Shortcut mapping/editor and the remaining WPF keyboard/mouse operation parity are the immediate next Windows Avalonia slice.",
            "Pixel-level WPF visual parity, Rework/test-play/conversion and the rest of the matrix remain incomplete.",
            "Final two-client online, physical 1080p/1440p/4K DPI and 60/120 Hz, file-format, ClientSecurity and installer gates remain incomplete."
        )
    }
    $evidencePath = Join-Path $outputFullPath "settings-cache-gui-evidence.json"
    $evidence | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    Write-Host "Windows Avalonia settings/cache GUI acceptance: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    Stop-TrackedClient $second
    Stop-TrackedClient $first
}
