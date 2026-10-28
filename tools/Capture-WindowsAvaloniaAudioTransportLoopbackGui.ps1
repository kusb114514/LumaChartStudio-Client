param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ProbeAssemblyPath = (Join-Path $PSScriptRoot "WindowsAudioLoopbackProbe\bin\Release\net8.0-windows\WindowsAudioLoopbackProbe.dll"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$AudioFixturePath = "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [switch]$MultiTempoOffsetOnly,
    [switch]$ExpandBothAudioPanels,
    [switch]$LeavePreservePitchDisabled,
    [switch]$PlaybackContinuityOnly,
    [switch]$MoveMouseDuringPlayback,
    [ValidateRange(3, 170)][int]$PlaybackContinuitySeconds = 3,
    [switch]$EnableKeySounds,
    [ValidateRange(0, 1)][double]$KeySoundVolume = 0.7,
    [ValidateSet("Snare", "HandDrum", "HandDrum2")][string]$KeySoundPreset = "Snare",
    [switch]$FormalMigrationAuthority,
    [ValidateRange(30, 300)][int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia audio-transport loopback capture requires PowerShell Core on Windows."
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
        [int]$PollMilliseconds = 50
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

function Get-FileFingerprint([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        bytes = $item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        lastWriteUtcTicks = $item.LastWriteTimeUtc.Ticks
    }
}

function Assert-FingerprintUnchanged($Before, [string]$Label) {
    $after = Get-FileFingerprint $Before.path
    if ($after.bytes -ne $Before.bytes -or
        $after.sha256 -cne $Before.sha256 -or
        $after.lastWriteUtcTicks -ne $Before.lastWriteUtcTicks) {
        throw "$Label changed during audio-transport verification."
    }
    return $after
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartAudioTransportLoopbackNative
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

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(
        uint flags,
        uint dx,
        uint dy,
        uint data,
        UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(
        byte virtualKey,
        byte scanCode,
        uint flags,
        UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr value);
}
'@
[LumaChartAudioTransportLoopbackNative]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 180000)][int]$TimeoutMilliseconds = 10000,
        [switch]$Optional
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
        Start-Sleep -Milliseconds 50
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    if ($Optional) { return $null }
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Get-ElementState($Element) {
    $bounds = $Element.Current.BoundingRectangle
    return [ordered]@{
        capturedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        helpText = [string]$Element.Current.HelpText
        isEnabled = [bool]$Element.Current.IsEnabled
        isOffscreen = [bool]$Element.Current.IsOffscreen
        bounds = [ordered]@{
            left = $bounds.Left
            top = $bounds.Top
            width = $bounds.Width
            height = $bounds.Height
        }
    }
}

function Bring-ElementIntoView($Element) {
    if (-not $Element.Current.IsOffscreen) { return }
    $patternObject = $null
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.ScrollItemPattern]::Pattern,
            [ref]$patternObject)) {
        ([Windows.Automation.ScrollItemPattern]$patternObject).ScrollIntoView()
    }
    try {
        $Element.SetFocus()
    }
    catch [System.InvalidOperationException] { }
}

function Get-DiagnosticValue([string]$Text, [string]$Name) {
    $match = [regex]::Match(
        $Text,
        "(?i)(?:^|;\s*)$([regex]::Escape($Name))=([^;]*)")
    if (-not $match.Success) {
        throw "Diagnostic '$Name' missing from '$Text'."
    }
    return $match.Groups[1].Value.Trim()
}

function Get-DiagnosticDouble([string]$Text, [string]$Name) {
    return [double]::Parse(
        (Get-DiagnosticValue $Text $Name),
        [Globalization.CultureInfo]::InvariantCulture)
}

function Get-AudioState([int]$ProcessId) {
    return Get-ElementState (
        Find-ElementById -ProcessId $ProcessId -AutomationId "Editor.QuickPlayPause")
}

function Invoke-Element($Element) {
    if (-not $Element.Current.IsEnabled -or $Element.Current.IsOffscreen) {
        throw "Element '$($Element.Current.AutomationId)' is not invokable."
    }
    $patternObject = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$patternObject)) {
        throw "Element '$($Element.Current.AutomationId)' lacks InvokePattern."
    }
    $occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    ([Windows.Automation.InvokePattern]$patternObject).Invoke()
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        pattern = "InvokePattern"
        occurredUtc = $occurredUtc
    }
}

function Select-Element($Element) {
    $patternObject = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$patternObject)) {
        throw "Element '$($Element.Current.AutomationId)' lacks SelectionItemPattern."
    }
    ([Windows.Automation.SelectionItemPattern]$patternObject).Select()
}

function Set-RangeValue($Element, [double]$Value) {
    if (-not $Element.Current.IsEnabled) {
        throw "Element '$($Element.Current.AutomationId)' is disabled."
    }
    $patternObject = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.RangeValuePattern]::Pattern,
            [ref]$patternObject)) {
        throw "Element '$($Element.Current.AutomationId)' lacks RangeValuePattern."
    }
    $range = [Windows.Automation.RangeValuePattern]$patternObject
    $clamped = [Math]::Clamp($Value, $range.Current.Minimum, $range.Current.Maximum)
    $Element.SetFocus()
    $occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    $range.SetValue($clamped)
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        pattern = "RangeValuePattern"
        requestedValue = $Value
        appliedValue = $clamped
        occurredUtc = $occurredUtc
    }
}

function Set-ToggleOn($Element) {
    $patternObject = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.TogglePattern]::Pattern,
            [ref]$patternObject)) {
        throw "Element '$($Element.Current.AutomationId)' lacks TogglePattern."
    }
    $toggle = [Windows.Automation.TogglePattern]$patternObject
    $occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    if ($toggle.Current.ToggleState -ne [Windows.Automation.ToggleState]::On) {
        $toggle.Toggle()
    }
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        pattern = "TogglePattern"
        requestedState = "On"
        occurredUtc = $occurredUtc
    }
}

function Invoke-MouseWheel($Element, [int]$Detents, [IntPtr]$WindowHandle) {
    if ($Detents -eq 0) { return }
    [void][LumaChartAudioTransportLoopbackNative]::SetForegroundWindow($WindowHandle)
    $rect = $Element.Current.BoundingRectangle
    if ($rect.Width -le 1 -or $rect.Height -le 1) {
        throw "Element '$($Element.Current.AutomationId)' has invalid wheel bounds."
    }
    # Avalonia UIA may expose DIPs for this custom control while SetCursorPos
    # always consumes physical pixels. A 70% horizontal target stays inside
    # the actual four-lane surface under either interpretation and avoids the
    # docked waveform/analysis overlays at the left side of the timeline.
    $x = [int][Math]::Round($rect.Left + $rect.Width * .70)
    $y = [int][Math]::Round($rect.Top + $rect.Height * .5)
    if (-not [LumaChartAudioTransportLoopbackNative]::SetCursorPos($x, $y)) {
        throw "SetCursorPos failed for timeline wheel input."
    }
    try { $Element.SetFocus() } catch { }
    Start-Sleep -Milliseconds 100
    $delta = if ($Detents -gt 0) { [int32]120 } else { [int32]-120 }
    $mouseData = [BitConverter]::ToUInt32([BitConverter]::GetBytes($delta), 0)
    $occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    for ($index = 0; $index -lt [Math]::Abs($Detents); $index++) {
        [LumaChartAudioTransportLoopbackNative]::mouse_event(
            0x0800,
            0,
            0,
            $mouseData,
            [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 30
    }
    Start-Sleep -Milliseconds 200
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        input = "Win32 mouse wheel"
        detents = $Detents
        occurredUtc = $occurredUtc
        point = [ordered]@{ x = $x; y = $y }
    }
}

function Invoke-HomeShortcut($Element, [IntPtr]$WindowHandle) {
    [void][LumaChartAudioTransportLoopbackNative]::SetForegroundWindow($WindowHandle)
    try { $Element.SetFocus() } catch [System.InvalidOperationException] { }
    Start-Sleep -Milliseconds 100
    [LumaChartAudioTransportLoopbackNative]::keybd_event(
        [byte]0x24,
        [byte]0,
        [uint32]0,
        [UIntPtr]::Zero)
    [LumaChartAudioTransportLoopbackNative]::keybd_event(
        [byte]0x24,
        [byte]0,
        [uint32]2,
        [UIntPtr]::Zero)
    return [ordered]@{
        input = "Win32 keybd_event"
        key = "Home"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartAudioTransportLoopbackNative+RECT]::new()
    if (-not [LumaChartAudioTransportLoopbackNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 800 -or $height -lt 500) {
        throw "Window has invalid capture bounds ${width}x${height}."
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
                if (-not [LumaChartAudioTransportLoopbackNative]::PrintWindow(
                        $Handle,
                        $deviceContext,
                        2)) {
                    throw "PrintWindow failed for $Handle."
                }
            }
            finally {
                $graphics.ReleaseHdc($deviceContext)
            }
        }
        finally {
            $graphics.Dispose()
        }
        $uniqueColors = [Collections.Generic.HashSet[int]]::new()
        for ($sampleY = 0; $sampleY -lt 16; $sampleY++) {
            for ($sampleX = 0; $sampleX -lt 16; $sampleX++) {
                $pixel = $bitmap.GetPixel(
                    [Math]::Min($width - 1, [int](($sampleX + .5) * $width / 16)),
                    [Math]::Min($height - 1, [int](($sampleY + .5) * $height / 16)))
                [void]$uniqueColors.Add($pixel.ToArgb())
            }
        }
        if ($uniqueColors.Count -lt 8) {
            throw "Screenshot is near-uniform: $($uniqueColors.Count) sampled colors."
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            path = [IO.Path]::GetFullPath($Path)
            width = $width
            height = $height
            sampledUniqueColors = $uniqueColors.Count
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

function Stop-TrackedProcess([Diagnostics.Process]$Process) {
    if (-not $Process -or $Process.HasExited) { return }
    $Process.Kill($true)
    [void]$Process.WaitForExit(5000)
}

$application = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$probeAssembly = Resolve-ExistingFile $ProbeAssemblyPath "loopback probe assembly"
$chartFixture = Resolve-ExistingFile $ChartFixturePath "real MC fixture"
$audioFixture = Resolve-ExistingFile $AudioFixturePath "real audio fixture"
$output = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $output) {
    throw "Output root already exists: $output"
}
New-Item -ItemType Directory -Path $output | Out-Null

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$projectTemp = Join-Path $projectRoot ".codex-temp"
$dotnetHome = Join-Path $projectRoot ".codex-dotnet-home"
$nugetPackages = Join-Path $projectRoot ".codex-nuget-packages"
$nugetHttpCache = Join-Path $projectRoot ".codex-nuget-http-cache"
foreach ($directory in @($projectTemp, $dotnetHome, $nugetPackages, $nugetHttpCache)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}
$env:DOTNET_CLI_HOME = $dotnetHome
$env:NUGET_PACKAGES = $nugetPackages
$env:NUGET_HTTP_CACHE_PATH = $nugetHttpCache
$env:TEMP = $projectTemp
$env:TMP = $projectTemp

$clientRoot = Join-Path $output "client"
$workingRoot = Join-Path $clientRoot "working"
$localDataRoot = Join-Path $clientRoot "local-data"
$editingRoot = Join-Path $clientRoot "editing"
$workspaceRoot = Join-Path $clientRoot "workspace"
foreach ($directory in @($workingRoot, $localDataRoot, $editingRoot, $workspaceRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$chartJson = Get-Content -LiteralPath $chartFixture -Raw | ConvertFrom-Json
$referencedAudio = [string]$chartJson.meta.song.file
if ([IO.Path]::GetFileName($audioFixture) -cne $referencedAudio) {
    throw "Audio fixture does not match the real MC reference '$referencedAudio'."
}
$workingChartName = if ($MultiTempoOffsetOnly) {
    "audio-transport-multi-tempo-offset.mc"
}
else {
    "audio-transport-resound.mc"
}
$workingChart = Join-Path $workingRoot $workingChartName
$workingAudio = Join-Path $workingRoot $referencedAudio
if ($MultiTempoOffsetOnly) {
    $chartJson.meta.song.bpm = 120.0
    $chartJson.time = @(
        [ordered]@{
            beat = @(0, 0, 1)
            bpm = 120.0
            delay = -320.0
        },
        [ordered]@{
            beat = @(2, 0, 1)
            bpm = 60.0
        },
        [ordered]@{
            beat = @(4, 0, 1)
            bpm = 240.0
        })
    $chartJson | ConvertTo-Json -Depth 100 -Compress |
        Set-Content -LiteralPath $workingChart -Encoding utf8NoBOM
}
else {
    Copy-Item -LiteralPath $chartFixture -Destination $workingChart
}
Copy-Item -LiteralPath $audioFixture -Destination $workingAudio

[ordered]@{
    SchemaVersion = 1
    EnableKeySounds = [bool]$EnableKeySounds
    Volume = $KeySoundVolume
    Preset = $KeySoundPreset
    CustomFilePath = $null
    PlayLongNoteEndSound = $false
    GlobalOffset = 0
    PerChartOffsets = @{}
} | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $localDataRoot "key-sound-settings.json") -Encoding utf8NoBOM

if ($ExpandBothAudioPanels) {
    [ordered]@{
        SchemaVersion = 1
        Waveform = [ordered]@{
            X = 4000
            Y = 0
            Width = 92
            Collapsed = $false
            Docked = $true
            Mode = "Side"
        }
        Spectrogram = [ordered]@{
            X = 4000
            Y = 0
            Width = 132
            Collapsed = $false
            Docked = $true
            Mode = "Side"
        }
    } | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $localDataRoot "audio-panel-settings.json") `
            -Encoding utf8NoBOM
}

$fixtureChartBefore = Get-FileFingerprint $chartFixture
$fixtureAudioBefore = Get-FileFingerprint $audioFixture
$workingChartBefore = Get-FileFingerprint $workingChart
$workingAudioBefore = Get-FileFingerprint $workingAudio
$installerBefore = Get-FileFingerprint (Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")

$runtimePath = Join-Path $output "runtime-evidence.json"
$probeReadyPath = Join-Path $output "loopback-ready.json"
$probeOutputPath = Join-Path $output "loopback-probe.json"
$probeWavePath = Join-Path $output "audio-transport-loopback.wav"
$playbackMarkerPath = Join-Path $output "playback-marker.json"
$interactionProgressPath = Join-Path $output "interaction-progress.json"
$process = $null
$probe = $null

try {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $application
    $start.UseShellExecute = $false
    $start.WorkingDirectory = Split-Path -Parent $application
    foreach ($argument in @(
            "--evidence-chart", $workingChart,
            "--evidence-focus-audio-transport",
            "--evidence-output", $runtimePath)) {
        $start.ArgumentList.Add($argument)
    }
    $start.Environment["LUMACHART_PROFILE"] = "windows-avalonia-audio-transport-loopback"
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceRoot
    $start.Environment["DOTNET_CLI_HOME"] = $dotnetHome
    $start.Environment["NUGET_PACKAGES"] = $nugetPackages
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
    $start.Environment["TEMP"] = $projectTemp
    $start.Environment["TMP"] = $projectTemp
    $process = [Diagnostics.Process]::Start($start)
    if (-not $process) {
        throw "Failed to start Windows Avalonia client."
    }

    Wait-Condition -Description "Avalonia main window" -Condition {
        $process.Refresh()
        -not $process.HasExited -and $process.MainWindowHandle -ne [IntPtr]::Zero
    }
    $handle = $process.MainWindowHandle
    [void][LumaChartAudioTransportLoopbackNative]::ShowWindow($handle, 3)
    [void][LumaChartAudioTransportLoopbackNative]::SetForegroundWindow($handle)
    $playPause = Find-ElementById -ProcessId $process.Id `
        -AutomationId "Editor.QuickPlayPause" -TimeoutMilliseconds 45000
    $timeline = Find-ElementById -ProcessId $process.Id `
        -AutomationId "Timeline.Surface" -TimeoutMilliseconds 45000
    $setupActions = @()
    if (-not $LeavePreservePitchDisabled) {
        $settingsTab = Find-ElementById -ProcessId $process.Id `
            -AutomationId "Inspector.SettingsTab" -TimeoutMilliseconds 45000
        Select-Element $settingsTab
        $preservePitch = Find-ElementById -ProcessId $process.Id `
            -AutomationId "Audio.PreservePitch" -TimeoutMilliseconds 45000
        $setupActions += Set-ToggleOn $preservePitch
    }
    $runtimeInspectorTab = Find-ElementById -ProcessId $process.Id `
        -AutomationId $(if ($EnableKeySounds) {
            "Inspector.SettingsTab"
        } else {
            "Inspector.NoteTab"
        }) -TimeoutMilliseconds 45000
    Select-Element $runtimeInspectorTab
    Wait-Condition -Description "loaded real audio" -Seconds 45 -Condition {
        $state = Get-AudioState $process.Id
        $source = Get-DiagnosticValue $state.helpText "SourcePath"
        (Get-DiagnosticValue $state.helpText "IsLoaded") -ceq "True" -and
        [IO.Path]::GetFileName($source) -ceq $referencedAudio -and
        (Test-Path -LiteralPath $source -PathType Leaf) -and
        (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ceq
            $fixtureAudioBefore.sha256
    }
    Wait-Condition -Description "runtime evidence" -Condition {
        Test-Path -LiteralPath $runtimePath -PathType Leaf
    }
    Wait-Condition -Description "initial 1.0x transport state" -Seconds 20 -Condition {
        $state = Get-AudioState $process.Id
        [Math]::Abs((Get-DiagnosticDouble $state.helpText "PlaybackRate") - 1) -le .001 -and
        (Get-DiagnosticValue $state.helpText "PreservePitch") -ceq
            $(if ($LeavePreservePitchDisabled) { "False" } else { "True" })
    }
    if ($PlaybackContinuityOnly) {
        $homeAction = Invoke-HomeShortcut $timeline $handle
        $setupActions += $homeAction
        Wait-Condition -Description "continuity playback reset to chart start" -Seconds 20 -Condition {
            $timelineState = Get-ElementState (
                Find-ElementById -ProcessId $process.Id `
                    -AutomationId "Timeline.Surface")
            $audioState = Get-AudioState $process.Id
            [Math]::Abs(
                (Get-DiagnosticDouble $timelineState.helpText "CurrentBeat")) -le .001 -and
            (Get-DiagnosticDouble $audioState.helpText "PositionMs") -le 100 -and
            (Get-DiagnosticValue $audioState.helpText "PendingSeek") -ceq "False"
        }
    }
    if ($ExpandBothAudioPanels) {
        try {
            Wait-Condition -Description "waveform and spectrogram retained scenes" `
                -Seconds ([Math]::Min(120, $TimeoutSeconds)) -Condition {
                $state = Get-AudioState $process.Id
                (Get-DiagnosticValue $state.helpText "WaveSceneReady") -ceq "True" -and
                (Get-DiagnosticValue $state.helpText "SpecSceneReady") -ceq "True" -and
                (Get-DiagnosticDouble $state.helpText "WaveSceneBuilds") -ge 1 -and
                (Get-DiagnosticDouble $state.helpText "SpecSceneBuilds") -ge 1
            }
        }
        catch {
            $sceneFailureState = Get-AudioState $process.Id
            $sceneFailureState | ConvertTo-Json -Depth 8 |
                Set-Content -LiteralPath (
                    Join-Path $output "visualization-scene-timeout.json") `
                    -Encoding utf8NoBOM
            throw (
                "Timed out waiting for retained visualization scenes. " +
                $sceneFailureState.helpText)
        }
    }
    $initialState = Get-AudioState $process.Id
    $readyCaptureName = if ($MultiTempoOffsetOnly) {
        "multi-tempo-offset-ready.png"
    }
    else {
        "audio-transport-ready.png"
    }
    $beforeCapture = Capture-Window $handle (Join-Path $output $readyCaptureName)
    $quickValueButtonStates = [ordered]@{}
    foreach ($automationId in @(
            "Editor.QuickValues.Snap.Up",
            "Editor.QuickValues.Snap.Preset",
            "Editor.QuickValues.Snap.Down",
            "Editor.QuickValues.Grid.Up",
            "Editor.QuickValues.Grid.Preset",
            "Editor.QuickValues.Grid.Down",
            "Editor.QuickValues.Rate.Up",
            "Editor.QuickValues.Rate.Preset",
            "Editor.QuickValues.Rate.Down")) {
        $quickValueButtonStates[$automationId] = Get-ElementState (
            Find-ElementById -ProcessId $process.Id `
                -AutomationId $automationId -TimeoutMilliseconds 20000)
    }
    $quickValueCenters = @(
        foreach ($state in $quickValueButtonStates.Values) {
            [double]$state.bounds.left + [double]$state.bounds.width / 2
        })
    $quickValueWidths = @(
        $quickValueButtonStates.Values |
            ForEach-Object { [double]$_.bounds.width })
    $quickValuesAlignment = [ordered]@{
        buttons = $quickValueButtonStates
        centerSpreadDip =
            ($quickValueCenters | Measure-Object -Maximum).Maximum -
            ($quickValueCenters | Measure-Object -Minimum).Minimum
        minimumButtonWidthDip =
            ($quickValueWidths | Measure-Object -Minimum).Minimum
        allNineButtonsShareOneColumnCenter = $false
    }
    $quickValuesAlignment.allNineButtonsShareOneColumnCenter =
        [double]$quickValuesAlignment.centerSpreadDip -le 1.5 -and
        [double]$quickValuesAlignment.minimumButtonWidthDip -ge 90
    if (-not $quickValuesAlignment.allNineButtonsShareOneColumnCenter) {
        throw (
            "Quick Values controls are not centered across the full column: " +
            "centerSpreadDip=$($quickValuesAlignment.centerSpreadDip); " +
            "minimumButtonWidthDip=$($quickValuesAlignment.minimumButtonWidthDip).")
    }

    if ($MultiTempoOffsetOnly) {
        $actions = [Collections.Generic.List[object]]::new()
        $noteTab = Find-ElementById -ProcessId $process.Id `
            -AutomationId "Inspector.NoteTab" -TimeoutMilliseconds 20000
        Select-Element $noteTab
        Start-Sleep -Milliseconds 750
        $homeAction = Invoke-HomeShortcut $timeline $handle
        $actions.Add($homeAction)
        Wait-Condition -Description "multi-tempo Home shortcut" -Seconds 20 -Condition {
            $timelineState = Get-ElementState (
                Find-ElementById -ProcessId $process.Id `
                    -AutomationId "Timeline.Surface")
            [Math]::Abs(
                (Get-DiagnosticDouble $timelineState.helpText "CurrentBeat")) -le .001
        }
        Start-Sleep -Milliseconds 500
        $stableHomeTimeline = Get-ElementState (
            Find-ElementById -ProcessId $process.Id `
                -AutomationId "Timeline.Surface")
        if ([Math]::Abs(
                (Get-DiagnosticDouble $stableHomeTimeline.helpText "CurrentBeat")) -gt .001) {
            throw "Home shortcut did not hold the timeline at Beat zero."
        }

        function Wait-MultiTempoSeek(
            [double]$ExpectedBeat,
            [double]$ExpectedPositionMilliseconds,
            [string]$Description) {
            try {
                Wait-Condition -Description $Description -Seconds 20 -Condition {
                    $timelineState = Get-ElementState (
                        Find-ElementById -ProcessId $process.Id `
                            -AutomationId "Timeline.Surface")
                    $audioState = Get-AudioState $process.Id
                    [Math]::Abs(
                        (Get-DiagnosticDouble $timelineState.helpText "CurrentBeat") -
                        $ExpectedBeat) -le .02 -and
                    [Math]::Abs(
                        (Get-DiagnosticDouble $audioState.helpText "PositionMs") -
                        $ExpectedPositionMilliseconds) -le 80 -and
                    (Get-DiagnosticValue $audioState.helpText "PendingSeek") -ceq "False"
                }
            }
            catch {
                $failureName = ($Description -replace "[^A-Za-z0-9]+", "-").Trim("-")
                [ordered]@{
                    description = $Description
                    expectedBeat = $ExpectedBeat
                    expectedPositionMilliseconds = $ExpectedPositionMilliseconds
                    timeline = Get-ElementState (
                        Find-ElementById -ProcessId $process.Id `
                            -AutomationId "Timeline.Surface")
                    audio = Get-AudioState $process.Id
                } | ConvertTo-Json -Depth 10 |
                    Set-Content -LiteralPath (
                        Join-Path $output "seek-failure-$failureName.json") `
                        -Encoding utf8NoBOM
                throw
            }
            return [ordered]@{
                expectedBeat = $ExpectedBeat
                expectedPositionMilliseconds = $ExpectedPositionMilliseconds
                timeline = Get-ElementState (
                    Find-ElementById -ProcessId $process.Id `
                        -AutomationId "Timeline.Surface")
                audio = Get-AudioState $process.Id
            }
        }

        $seekActions = [Collections.Generic.List[object]]::new()
        $seekActions.Add((Invoke-MouseWheel $timeline -8 $handle))
        $beat2 = Wait-MultiTempoSeek 2 1320 "seek to first BPM boundary"
        $seekActions.Add((Invoke-MouseWheel $timeline -8 $handle))
        $beat4 = Wait-MultiTempoSeek 4 3320 "seek to second BPM boundary"
        $beat4Capture = Capture-Window $handle (
            Join-Path $output "multi-tempo-second-boundary.png")
        $seekActions.Add((Invoke-MouseWheel $timeline -8 $handle))
        $beat6 = Wait-MultiTempoSeek 6 3820 "seek through fast BPM segment"
        $seekActions.Add((Invoke-MouseWheel $timeline 16 $handle))
        $backwardBeat2 = Wait-MultiTempoSeek 2 1320 "backward seek across BPM segments"
        $seekActions.Add((Invoke-MouseWheel $timeline 8 $handle))
        $offsetBeat0 = Wait-MultiTempoSeek 0 320 "negative delay offset at beat zero"
        $offsetCapture = Capture-Window $handle (
            Join-Path $output "multi-tempo-negative-delay-offset.png")
        $seekActions.Add((Invoke-MouseWheel $timeline -8 $handle))
        $playStart = Wait-MultiTempoSeek 2 1320 "return to first BPM boundary"
        foreach ($seekAction in $seekActions) {
            $actions.Add($seekAction)
        }

        $probeStart = [Diagnostics.ProcessStartInfo]::new()
        $probeStart.FileName = "dotnet"
        $probeStart.UseShellExecute = $false
        $probeStart.WorkingDirectory = Split-Path -Parent $probeAssembly
        $probeStart.RedirectStandardOutput = $true
        $probeStart.RedirectStandardError = $true
        foreach ($argument in @(
                $probeAssembly,
                "--output", $probeOutputPath,
                "--wav", $probeWavePath,
                "--ready", $probeReadyPath,
                "--duration-ms", "5500",
                "--process-id", $process.Id.ToString(
                    [Globalization.CultureInfo]::InvariantCulture))) {
            $probeStart.ArgumentList.Add($argument)
        }
        $probeStart.Environment["DOTNET_CLI_HOME"] = $dotnetHome
        $probeStart.Environment["NUGET_PACKAGES"] = $nugetPackages
        $probeStart.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
        $probeStart.Environment["TEMP"] = $projectTemp
        $probeStart.Environment["TMP"] = $projectTemp
        $probe = [Diagnostics.Process]::Start($probeStart)
        if (-not $probe) {
            throw "Failed to start Windows process-tree loopback probe."
        }
        Wait-Condition -Description "multi-tempo loopback probe ready" -Seconds 20 -Condition {
            Test-Path -LiteralPath $probeReadyPath -PathType Leaf
        }
        $probeReady = Get-Content -LiteralPath $probeReadyPath -Raw |
            ConvertFrom-Json -DateKind String
        if ([string]$probeReady.captureScope -cne "process-tree" -or
            [int]$probeReady.targetProcessId -ne $process.Id) {
            throw "Loopback probe did not bind to the Avalonia process tree."
        }
        Start-Sleep -Milliseconds 500

        $playingStartState = Get-AudioState $process.Id
        $playAction = Invoke-Element $playPause
        $actions.Add($playAction)
        Wait-Condition -Description "multi-tempo playback" -Condition {
            (Get-DiagnosticValue (
                Get-AudioState $process.Id).helpText "State") -ceq "Playing"
        }
        Start-Sleep -Milliseconds 2700
        $playingCapture = Capture-Window $handle (
            Join-Path $output "multi-tempo-playing-across-boundaries.png")
        $beforePauseState = Get-AudioState $process.Id
        $pauseAction = Invoke-Element $playPause
        $actions.Add($pauseAction)
        Wait-Condition -Description "multi-tempo pause" -Condition {
            (Get-DiagnosticValue (
                Get-AudioState $process.Id).helpText "State") -ceq "Paused"
        }
        $pausedState = Get-AudioState $process.Id
        $pausedTimeline = Get-ElementState (
            Find-ElementById -ProcessId $process.Id `
                -AutomationId "Timeline.Surface")
        $pausedCapture = Capture-Window $handle (
            Join-Path $output "multi-tempo-paused-after-boundaries.png")

        if (-not $probe.WaitForExit(20000)) {
            throw "Multi-tempo loopback probe did not exit after its capture window."
        }
        $probeStandardOutput = $probe.StandardOutput.ReadToEnd()
        $probeStandardError = $probe.StandardError.ReadToEnd()
        if ($probe.ExitCode -ne 0) {
            throw "Loopback probe failed with exit code $($probe.ExitCode): " +
                "$probeStandardError $probeStandardOutput"
        }
        $probeEvidence = Get-Content -LiteralPath $probeOutputPath -Raw |
            ConvertFrom-Json -DateKind String
        if ($probeEvidence.status -cne "captured" -or
            $probeEvidence.captureScope -cne "process-tree" -or
            [int]$probeEvidence.targetProcessId -ne $process.Id -or
            [long]$probeEvidence.capture.bytes -le 0 -or
            [double]$probeEvidence.analysis.peak -lt .01 -or
            [double]$probeEvidence.analysis.rms -lt .001 -or
            @($probeEvidence.analysis.pulses).Count -lt 1) {
            throw "Multi-tempo loopback did not prove audible process render output."
        }

        $startPosition = Get-DiagnosticDouble $playingStartState.helpText "PositionMs"
        $endPosition = Get-DiagnosticDouble $beforePauseState.helpText "PositionMs"
        $pausedPosition = Get-DiagnosticDouble $pausedState.helpText "PositionMs"
        $pausedBeat = Get-DiagnosticDouble $pausedTimeline.helpText "CurrentBeat"
        $expectedPausedBeat = if ($pausedPosition -lt 3320) {
            2 + (($pausedPosition - 1320) / 1000)
        }
        else {
            4 + (($pausedPosition - 3320) / 250)
        }
        $playWallStart = [DateTimeOffset]::Parse([string]$playAction.occurredUtc)
        $playWallEnd = [DateTimeOffset]::Parse([string]$pauseAction.occurredUtc)
        $playWallMilliseconds = ($playWallEnd - $playWallStart).TotalMilliseconds
        $effectiveRate = ($endPosition - $startPosition) /
            [Math]::Max(1, $playWallMilliseconds)
        if ([Math]::Abs($pausedBeat - $expectedPausedBeat) -gt .18) {
            throw "Multi-tempo playhead mismatch: actual $pausedBeat, expected $expectedPausedBeat."
        }
        if ($effectiveRate -lt .75 -or $effectiveRate -gt 1.25) {
            throw "Multi-tempo audio clock ratio was $effectiveRate."
        }

        $fixtureChartAfter = Assert-FingerprintUnchanged $fixtureChartBefore "real MC fixture"
        $fixtureAudioAfter = Assert-FingerprintUnchanged $fixtureAudioBefore "real OGG fixture"
        $workingChartAfter = Assert-FingerprintUnchanged $workingChartBefore "isolated multi-tempo MC"
        $workingAudioAfter = Assert-FingerprintUnchanged $workingAudioBefore "isolated OGG copy"
        $installerAfter = Assert-FingerprintUnchanged $installerBefore "frozen WPF installer"
        $screenshots = [ordered]@{}
        foreach ($path in Get-ChildItem -LiteralPath $output -File -Filter "*.png" |
                 Sort-Object Name) {
            $screenshots[$path.BaseName] = [ordered]@{
                path = $path.FullName
                bytes = $path.Length
                sha256 = (Get-FileHash -LiteralPath $path.FullName -Algorithm SHA256).Hash
            }
        }
        $evidence = [ordered]@{
            schema = "lumachart.windows.avalonia.multi-tempo-offset-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed"
            formalMigrationAuthority = [bool]$FormalMigrationAuthority
            completion = $false
            migrationComplete = $false
            windowsAvaloniaOnly = $true
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            productionServerMutationPerformed = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            physicalMouseInputUsed = $false
            win32MouseWheelInjected = $true
            uiAutomationPatternsUsed = @(
                "InvokePattern",
                "SelectionItemPattern",
                "TogglePattern")
            paths = [ordered]@{
                outputRoot = $output
                application = $application
                probeAssembly = $probeAssembly
                temp = $projectTemp
                dotnetHome = $dotnetHome
                nugetPackages = $nugetPackages
                nugetHttpCache = $nugetHttpCache
            }
            fixture = [ordered]@{
                chartBefore = $fixtureChartBefore
                chartAfter = $fixtureChartAfter
                audioBefore = $fixtureAudioBefore
                audioAfter = $fixtureAudioAfter
                isolatedChartBefore = $workingChartBefore
                isolatedChartAfter = $workingChartAfter
                isolatedAudioBefore = $workingAudioBefore
                isolatedAudioAfter = $workingAudioAfter
                releasedInstallerBefore = $installerBefore
                releasedInstallerAfter = $installerAfter
            }
            timing = [ordered]@{
                points = @(
                    [ordered]@{ beat = "0:0/1"; bpm = 120.0; delay = -320.0 },
                    [ordered]@{ beat = "2:0/1"; bpm = 60.0; delay = 0.0 },
                    [ordered]@{ beat = "4:0/1"; bpm = 240.0; delay = 0.0 })
                expectedMilliseconds = [ordered]@{
                    beat0 = 320.0
                    beat2 = 1320.0
                    beat4 = 3320.0
                    beat6 = 3820.0
                }
                forwardBeat2 = $beat2
                forwardBeat4 = $beat4
                forwardBeat6 = $beat6
                backwardBeat2 = $backwardBeat2
                negativeDelayBeat0 = $offsetBeat0
                playStart = $playStart
                pausedPositionMilliseconds = $pausedPosition
                pausedBeat = $pausedBeat
                expectedPausedBeat = $expectedPausedBeat
                pausedBeatError = $pausedBeat - $expectedPausedBeat
            }
            transport = [ordered]@{
                playAction = $playAction
                pauseAction = $pauseAction
                start = $playingStartState
                beforePause = $beforePauseState
                paused = $pausedState
                wallMilliseconds = $playWallMilliseconds
                positionDeltaMilliseconds = $endPosition - $startPosition
                effectiveRate = $effectiveRate
            }
            loopback = [ordered]@{
                ready = $probeReady
                probe = $probeEvidence
                capturedAvaloniaProcessTree = $true
                capturedPhysicalTransducer = $false
            }
            setupActions = $setupActions
            actions = $actions.ToArray()
            captures = [ordered]@{
                ready = $beforeCapture
                beat4 = $beat4Capture
                offset = $offsetCapture
                playing = $playingCapture
                paused = $pausedCapture
            }
            screenshots = $screenshots
        }
        $evidencePath = Join-Path $output "evidence.json"
        $evidence | ConvertTo-Json -Depth 30 |
            Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
        Write-Host "Windows Avalonia multi-tempo/offset/device GUI capture: passed"
        Write-Host "Evidence: $evidencePath"
        return
    }

    $probeStart = [Diagnostics.ProcessStartInfo]::new()
    $probeStart.FileName = "dotnet"
    $probeStart.UseShellExecute = $false
    $probeStart.WorkingDirectory = Split-Path -Parent $probeAssembly
    $probeStart.RedirectStandardOutput = $true
    $probeStart.RedirectStandardError = $true
    $continuityPlaybackMilliseconds = $PlaybackContinuitySeconds * 1000
    $continuityReferenceMilliseconds = [Math]::Max(
        2000,
        $continuityPlaybackMilliseconds - 1000)
    $probeDurationMilliseconds = if ($PlaybackContinuityOnly) {
        $continuityPlaybackMilliseconds + 5000
    }
    else {
        14000
    }
    $probeArguments = [Collections.Generic.List[string]]::new()
    foreach ($argument in @(
            $probeAssembly,
            "--output", $probeOutputPath,
            "--wav", $probeWavePath,
            "--ready", $probeReadyPath,
            "--duration-ms", $probeDurationMilliseconds.ToString(
                [Globalization.CultureInfo]::InvariantCulture),
            "--process-id", $process.Id.ToString([Globalization.CultureInfo]::InvariantCulture))) {
        $probeArguments.Add($argument)
    }
    if ($PlaybackContinuityOnly) {
        $probeArguments.Add("--continuity-reference-audio")
        $probeArguments.Add($workingAudio)
        $probeArguments.Add("--playback-marker")
        $probeArguments.Add($playbackMarkerPath)
    }
    foreach ($argument in $probeArguments) {
        $probeStart.ArgumentList.Add($argument)
    }
    $probeStart.Environment["DOTNET_CLI_HOME"] = $dotnetHome
    $probeStart.Environment["NUGET_PACKAGES"] = $nugetPackages
    $probeStart.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
    $probeStart.Environment["TEMP"] = $projectTemp
    $probeStart.Environment["TMP"] = $projectTemp
    $probe = [Diagnostics.Process]::Start($probeStart)
    if (-not $probe) {
        throw "Failed to start Windows process-tree loopback probe."
    }
    Wait-Condition -Description "loopback probe ready" -Seconds 20 -Condition {
        Test-Path -LiteralPath $probeReadyPath -PathType Leaf
    }
    $probeReady = Get-Content -LiteralPath $probeReadyPath -Raw |
        ConvertFrom-Json -DateKind String
    if ([string]$probeReady.captureScope -cne "process-tree" -or
        [int]$probeReady.targetProcessId -ne $process.Id) {
        throw "Loopback probe did not bind to the Avalonia process tree."
    }
    Start-Sleep -Milliseconds 600

    $actions = [Collections.Generic.List[object]]::new()
    $continuitySamples = [Collections.Generic.List[object]]::new()
    $firstStartState = Get-AudioState $process.Id
    $continuityClock = [Diagnostics.Stopwatch]::StartNew()
    $firstPlay = Invoke-Element $playPause
    $actions.Add($firstPlay)
    if ($PlaybackContinuityOnly) {
        [ordered]@{
            playbackStartedUtc = $firstPlay.occurredUtc
            requestedPlaybackMilliseconds = $continuityReferenceMilliseconds
            sourcePositionMilliseconds =
                Get-DiagnosticDouble $firstStartState.helpText "PositionMs"
        } | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath $playbackMarkerPath -Encoding utf8NoBOM
    }
    Wait-Condition -Description "first 1.0x playback" -Condition {
        (Get-DiagnosticValue (Get-AudioState $process.Id).helpText "State") -ceq "Playing"
    }
    # The first SoundTouch/WASAPI start pays the one-time decoder/device warm-up.
    # Measure the steady transport clock after that cold-start interval.
    Start-Sleep -Milliseconds 1000
    $firstPlayingState = Get-AudioState $process.Id
    if ($PlaybackContinuityOnly) {
        $lastAdvancedPosition = Get-DiagnosticDouble $firstPlayingState.helpText "PositionMs"
        $lastAdvanceWallMilliseconds = $continuityClock.Elapsed.TotalMilliseconds
        $mouseMoveCount = 0
        $timelineMoveRectangle = $timeline.Current.BoundingRectangle
        $continuitySamples.Add([ordered]@{
            wallMilliseconds = $continuityClock.Elapsed.TotalMilliseconds
            state = Get-DiagnosticValue $firstPlayingState.helpText "State"
            positionMilliseconds = $lastAdvancedPosition
            unexpectedOutputStops =
                Get-DiagnosticDouble $firstPlayingState.helpText "UnexpectedOutputStops"
            transientMusicZeros =
                Get-DiagnosticDouble $firstPlayingState.helpText "TransientMusicZeros"
            waveSceneBuilds =
                Get-DiagnosticDouble $firstPlayingState.helpText "WaveSceneBuilds"
            specSceneBuilds =
                Get-DiagnosticDouble $firstPlayingState.helpText "SpecSceneBuilds"
            specBitmapUiMaximumMilliseconds =
                Get-DiagnosticDouble $firstPlayingState.helpText "SpecBitmapUiMaxMs"
            pendingSeek =
                Get-DiagnosticValue $firstPlayingState.helpText "PendingSeek"
        })
        while ($continuityClock.Elapsed.TotalMilliseconds -lt $continuityPlaybackMilliseconds) {
            if ($MoveMouseDuringPlayback) {
                $movePhase = $mouseMoveCount % 2
                $moveX = [int][Math]::Round(
                    $timelineMoveRectangle.Left +
                    $timelineMoveRectangle.Width * $(if ($movePhase -eq 0) { .56 } else { .72 }))
                $moveY = [int][Math]::Round(
                    $timelineMoveRectangle.Top +
                    $timelineMoveRectangle.Height * $(if ($movePhase -eq 0) { .42 } else { .63 }))
                if (-not [LumaChartAudioTransportLoopbackNative]::SetCursorPos(
                        $moveX,
                        $moveY)) {
                    throw "SetCursorPos failed during playback mouse-move regression."
                }
                $mouseMoveCount++
                Start-Sleep -Milliseconds 80
            }
            else {
                Start-Sleep -Milliseconds 200
            }
            $sample = Get-AudioState $process.Id
            $sampleWallMilliseconds = $continuityClock.Elapsed.TotalMilliseconds
            $sampleState = Get-DiagnosticValue $sample.helpText "State"
            $samplePosition = Get-DiagnosticDouble $sample.helpText "PositionMs"
            $sampleUnexpectedStops =
                Get-DiagnosticDouble $sample.helpText "UnexpectedOutputStops"
            $sampleTransientZeros =
                Get-DiagnosticDouble $sample.helpText "TransientMusicZeros"
            $samplePendingSeek =
                Get-DiagnosticValue $sample.helpText "PendingSeek"
            if ($samplePosition -gt $lastAdvancedPosition + 1) {
                $lastAdvancedPosition = $samplePosition
                $lastAdvanceWallMilliseconds = $sampleWallMilliseconds
            }
            $continuitySamples.Add([ordered]@{
                wallMilliseconds = $sampleWallMilliseconds
                state = $sampleState
                positionMilliseconds = $samplePosition
                unexpectedOutputStops = $sampleUnexpectedStops
                transientMusicZeros = $sampleTransientZeros
                waveSceneBuilds =
                    Get-DiagnosticDouble $sample.helpText "WaveSceneBuilds"
                specSceneBuilds =
                    Get-DiagnosticDouble $sample.helpText "SpecSceneBuilds"
                specBitmapUiMaximumMilliseconds =
                    Get-DiagnosticDouble $sample.helpText "SpecBitmapUiMaxMs"
                pendingSeek = $samplePendingSeek
            })
            if ($sampleState -cne "Playing" -or
                $sampleUnexpectedStops -ne 0 -or
                $sampleTransientZeros -ne 0 -or
                $samplePendingSeek -cne "False") {
                throw (
                    "Playback continuity state changed at ${sampleWallMilliseconds}ms: " +
                    "state=$sampleState; unexpectedStops=$sampleUnexpectedStops; " +
                    "transientZeros=$sampleTransientZeros; pendingSeek=$samplePendingSeek.")
            }
            if ($sampleWallMilliseconds - $lastAdvanceWallMilliseconds -gt 750) {
                throw (
                    "Playback position stopped advancing for more than 750 ms at " +
                    "${sampleWallMilliseconds}ms.")
            }
        }
    }
    else {
        Start-Sleep -Milliseconds 1300
    }
    $firstBeforePauseState = Get-AudioState $process.Id
    $firstPause = Invoke-Element $playPause
    $actions.Add($firstPause)
    Wait-Condition -Description "first pause" -Condition {
        (Get-DiagnosticValue (Get-AudioState $process.Id).helpText "State") -ceq "Paused"
    }
    $firstPausedState = Get-AudioState $process.Id
    $keySoundAfterPauseElement = Find-ElementById -ProcessId $process.Id `
        -AutomationId "KeySound.RuntimeStatus" -TimeoutMilliseconds 20000 `
        -Optional
    $keySoundAfterPauseState = if ($keySoundAfterPauseElement) {
        Get-ElementState $keySoundAfterPauseElement
    }
    else { $null }
    if ($keySoundAfterPauseState) {
        $keySoundAfterPauseState | ConvertTo-Json -Depth 8 |
            Set-Content -LiteralPath (Join-Path $output "key-sound-after-pause.json") `
                -Encoding utf8NoBOM
    }
    $pausedPositionStart = Get-DiagnosticDouble $firstPausedState.helpText "PositionMs"
    Start-Sleep -Milliseconds 700
    $pauseStableState = Get-AudioState $process.Id
    $pausedPositionEnd = Get-DiagnosticDouble $pauseStableState.helpText "PositionMs"
    $pauseDrift = [Math]::Abs($pausedPositionEnd - $pausedPositionStart)
    if ($pauseDrift -gt 120) {
        throw "Paused audio clock drifted $pauseDrift ms."
    }
    $pausedCapture = Capture-Window $handle (Join-Path $output "audio-transport-paused.png")

    if ($PlaybackContinuityOnly) {
        $probeExitTimeoutMilliseconds = [Math]::Min(
            300000,
            $probeDurationMilliseconds + 120000)
        if (-not $probe.WaitForExit($probeExitTimeoutMilliseconds)) {
            throw "Loopback probe did not exit after its capture window."
        }
        $probeStandardOutput = $probe.StandardOutput.ReadToEnd()
        $probeStandardError = $probe.StandardError.ReadToEnd()
        if ($probe.ExitCode -ne 0) {
            throw "Loopback probe failed with exit code $($probe.ExitCode): $probeStandardError $probeStandardOutput"
        }
        Wait-Condition -Description "loopback probe output" -Condition {
            Test-Path -LiteralPath $probeOutputPath -PathType Leaf
        }
        $probeEvidence = Get-Content -LiteralPath $probeOutputPath -Raw |
            ConvertFrom-Json -DateKind String
        $pulses = @($probeEvidence.analysis.pulses | Sort-Object startMilliseconds)
        $mainPulse = $pulses |
            Sort-Object durationMilliseconds -Descending |
            Select-Object -First 1
        $endpointWarmupGapMilliseconds = if ($pulses.Count -eq 2) {
            [double]$pulses[1].startMilliseconds -
            ([double]$pulses[0].startMilliseconds +
                [double]$pulses[0].durationMilliseconds)
        }
        else { 0 }
        $acceptedEndpointWarmup = $pulses.Count -ge 1
        $finalAudioState = Get-AudioState $process.Id
        $unexpectedStops = Get-DiagnosticDouble $finalAudioState.helpText "UnexpectedOutputStops"
        $transientZeros = Get-DiagnosticDouble $finalAudioState.helpText "TransientMusicZeros"
        $continuityReference = $probeEvidence.analysis.continuityReference
        $unexpectedReferenceGaps = if ($continuityReference) {
            [int]$continuityReference.unexpectedSilentGapCount
        }
        else { -1 }
        $referenceComparedMilliseconds = if ($continuityReference) {
            [double]$continuityReference.comparedDurationMilliseconds
        }
        else { 0 }
        $alignmentCorrelation = if ($continuityReference) {
            [double]$continuityReference.alignmentCorrelation
        }
        else { 0 }
        $nonPlayingSamples = @(
            $continuitySamples |
                Where-Object { [string]$_.state -cne "Playing" })
        $sampledUnexpectedStops = @(
            $continuitySamples |
                Where-Object { [double]$_.unexpectedOutputStops -ne 0 })
        $sampledTransientZeros = @(
            $continuitySamples |
                Where-Object { [double]$_.transientMusicZeros -ne 0 })
        $positionAdvanceMilliseconds =
            (Get-DiagnosticDouble $firstBeforePauseState.helpText "PositionMs") -
            (Get-DiagnosticDouble $firstStartState.helpText "PositionMs")
        $waveSceneReady =
            (Get-DiagnosticValue $firstBeforePauseState.helpText "WaveSceneReady") -ceq "True"
        $specSceneReady =
            (Get-DiagnosticValue $firstBeforePauseState.helpText "SpecSceneReady") -ceq "True"
        $waveSceneBuilds =
            Get-DiagnosticDouble $firstBeforePauseState.helpText "WaveSceneBuilds"
        $specSceneBuilds =
            Get-DiagnosticDouble $firstBeforePauseState.helpText "SpecSceneBuilds"
        $specBitmapUiMaximumMilliseconds =
            Get-DiagnosticDouble $firstBeforePauseState.helpText "SpecBitmapUiMaxMs"
        $keySoundSharedAccepted = if ($keySoundAfterPauseState) {
            Get-DiagnosticDouble $keySoundAfterPauseState.helpText "SharedAccepted"
        }
        else { 0 }
        $keySoundStandaloneAccepted = if ($keySoundAfterPauseState) {
            Get-DiagnosticDouble $keySoundAfterPauseState.helpText "StandaloneAccepted"
        }
        else { 0 }
        if ($EnableKeySounds -and -not $keySoundAfterPauseState) {
            throw "Key sound runtime diagnostics were unavailable during playback verification."
        }
        if ($EnableKeySounds -and (
                $keySoundSharedAccepted -le 0 -or
                $keySoundStandaloneAccepted -ne 0)) {
            throw (
                "Key sounds did not stay on the shared music output: " +
                "sharedAccepted=$keySoundSharedAccepted; " +
                "standaloneAccepted=$keySoundStandaloneAccepted.")
        }
        if ($probeEvidence.status -cne "captured" -or
            $probeEvidence.captureScope -cne "process-tree" -or
            [int]$probeEvidence.targetProcessId -ne $process.Id -or
            -not $acceptedEndpointWarmup -or
            -not $continuityReference -or
            $unexpectedReferenceGaps -ne 0 -or
            $referenceComparedMilliseconds -lt $continuityReferenceMilliseconds - 30 -or
            $alignmentCorrelation -lt .15 -or
            $nonPlayingSamples.Count -ne 0 -or
            $sampledUnexpectedStops.Count -ne 0 -or
            $sampledTransientZeros.Count -ne 0 -or
            $positionAdvanceMilliseconds -lt $continuityPlaybackMilliseconds * .96 -or
            $positionAdvanceMilliseconds -gt $continuityPlaybackMilliseconds * 1.05 -or
            ($MoveMouseDuringPlayback -and $mouseMoveCount -lt 10) -or
            ($ExpandBothAudioPanels -and (
                -not $waveSceneReady -or
                -not $specSceneReady -or
                $waveSceneBuilds -lt 2 -or
                $specSceneBuilds -lt 2 -or
                $specBitmapUiMaximumMilliseconds -gt 50)) -or
            -not $mainPulse -or
            [double]$probeEvidence.analysis.peak -lt .01 -or
            [double]$probeEvidence.analysis.rms -lt .001 -or
            $unexpectedStops -ne 0 -or
            $transientZeros -ne 0) {
            throw (
                "Playback continuity was not proven: pulses=$($pulses.Count); " +
                "referenceGaps=$unexpectedReferenceGaps; " +
                "referenceComparedMs=$referenceComparedMilliseconds; " +
                "alignment=$alignmentCorrelation; " +
                "positionAdvanceMs=$positionAdvanceMilliseconds; " +
                "waveBuilds=$waveSceneBuilds; specBuilds=$specSceneBuilds; " +
                "specBitmapUiMaxMs=$specBitmapUiMaximumMilliseconds; " +
                "warmupGap=$endpointWarmupGapMilliseconds; " +
                "unexpectedStops=$unexpectedStops; transientZeros=$transientZeros.")
        }

        $fixtureChartAfter = Assert-FingerprintUnchanged $fixtureChartBefore "real MC fixture"
        $fixtureAudioAfter = Assert-FingerprintUnchanged $fixtureAudioBefore "real audio fixture"
        $workingChartAfter = Assert-FingerprintUnchanged $workingChartBefore "isolated MC copy"
        $workingAudioAfter = Assert-FingerprintUnchanged $workingAudioBefore "isolated audio copy"
        $installerAfter = Assert-FingerprintUnchanged $installerBefore "frozen WPF installer"
        $screenshots = [ordered]@{}
        foreach ($path in Get-ChildItem -LiteralPath $output -File -Filter "*.png" | Sort-Object Name) {
            $screenshots[$path.BaseName] = [ordered]@{
                path = $path.FullName
                bytes = $path.Length
                sha256 = (Get-FileHash -LiteralPath $path.FullName -Algorithm SHA256).Hash
            }
        }
        $evidence = [ordered]@{
            schema = "lumachart.windows.avalonia.audio-playback-continuity-gui-evidence.v2"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed"
            formalMigrationAuthority = [bool]$FormalMigrationAuthority
            completion = $false
            migrationComplete = $false
            windowsAvaloniaOnly = $true
            application = Get-FileFingerprint $application
            fixture = [ordered]@{
                chartBefore = $fixtureChartBefore
                chartAfter = $fixtureChartAfter
                audioBefore = $fixtureAudioBefore
                audioAfter = $fixtureAudioAfter
                isolatedChartBefore = $workingChartBefore
                isolatedChartAfter = $workingChartAfter
                isolatedAudioBefore = $workingAudioBefore
                isolatedAudioAfter = $workingAudioAfter
                frozenWpfInstallerBefore = $installerBefore
                frozenWpfInstallerAfter = $installerAfter
            }
            transport = [ordered]@{
                preservePitch = -not $LeavePreservePitchDisabled
                initial = $initialState
                playing = $firstPlayingState
                beforePause = $firstBeforePauseState
                paused = $firstPausedState
                stable = $pauseStableState
                final = $finalAudioState
                unexpectedOutputStops = $unexpectedStops
                transientMusicZeros = $transientZeros
                pauseDriftMilliseconds = $pauseDrift
                requestedPlaybackMilliseconds = $continuityPlaybackMilliseconds
                positionAdvanceMilliseconds = $positionAdvanceMilliseconds
                samples = $continuitySamples.ToArray()
                physicalMouseMoveRegression = [ordered]@{
                    enabled = [bool]$MoveMouseDuringPlayback
                    moveCount = $mouseMoveCount
                    pendingSeekSamples = @(
                        $continuitySamples |
                            Where-Object { [string]$_.pendingSeek -cne "False" }).Count
                }
            }
            visualization = [ordered]@{
                bothSidePanelsExpanded = [bool]$ExpandBothAudioPanels
                waveformSceneReady = $waveSceneReady
                waveformCompletedSceneBuilds = $waveSceneBuilds
                spectrogramSceneReady = $specSceneReady
                spectrogramCompletedSceneBuilds = $specSceneBuilds
                spectrogramBitmapUiMaximumMilliseconds =
                    $specBitmapUiMaximumMilliseconds
                readyScreenshot = $screenshots["audio-transport-ready"]
                pausedScreenshot = $screenshots["audio-transport-paused"]
            }
            quickValuesAlignment = $quickValuesAlignment
            keySound = [ordered]@{
                enabled = [bool]$EnableKeySounds
                preset = $KeySoundPreset
                volume = $KeySoundVolume
                afterPause = $keySoundAfterPauseState
                sharedAccepted = $keySoundSharedAccepted
                standaloneAccepted = $keySoundStandaloneAccepted
            }
            loopback = [ordered]@{
                probe = $probeEvidence
                pulseCount = $pulses.Count
                endpointWarmupObserved = $pulses.Count -eq 2
                endpointWarmupGapMilliseconds = $endpointWarmupGapMilliseconds
                continuousMainPulseDurationMilliseconds = [double]$mainPulse.durationMilliseconds
                referenceContinuity = $continuityReference
                waveSha256 = (Get-FileHash -LiteralPath $probeWavePath -Algorithm SHA256).Hash
            }
        }
        $evidencePath = Join-Path $output "continuity-evidence.json"
        $evidence | ConvertTo-Json -Depth 30 |
            Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
        Write-Host "Windows Avalonia playback continuity GUI capture: passed"
        Write-Host "Evidence: $evidencePath"
        return
    }

    $timelineBeforeSeek = Get-ElementState $timeline
    $beatBeforeSeek = Get-DiagnosticDouble $timelineBeforeSeek.helpText "CurrentBeat"
    $positionBeforeSeek = Get-DiagnosticDouble $pauseStableState.helpText "PositionMs"
    $firstSeek = Invoke-MouseWheel $timeline -8 $handle
    $actions.Add($firstSeek)
    Start-Sleep -Milliseconds 1000
    $firstSeekObservation = [ordered]@{
        beforeTimeline = $timelineBeforeSeek
        beforeAudio = $pauseStableState
        afterTimeline = Get-ElementState (
            Find-ElementById -ProcessId $process.Id -AutomationId "Timeline.Surface")
        afterAudio = Get-AudioState $process.Id
        wheelAction = $firstSeek
    }
    $firstSeekObservation | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath (Join-Path $output "first-seek-observation.json") `
            -Encoding utf8NoBOM
    Wait-Condition -Description "paused timeline wheel seek" -Seconds 20 -Condition {
        $timelineState = Get-ElementState (
            Find-ElementById -ProcessId $process.Id -AutomationId "Timeline.Surface")
        $state = Get-AudioState $process.Id
        (Get-DiagnosticDouble $timelineState.helpText "CurrentBeat") -ge $beatBeforeSeek + 1.8 -and
        (Get-DiagnosticDouble $state.helpText "PositionMs") -ge $positionBeforeSeek + 500 -and
        (Get-DiagnosticValue $state.helpText "State") -ceq "Paused" -and
        (Get-DiagnosticValue $state.helpText "PendingSeek") -ceq "False"
    }
    $firstSeekedState = Get-AudioState $process.Id
    $timelineAfterFirstSeek = Get-ElementState $timeline

    $rateDown = Find-ElementById -ProcessId $process.Id `
        -AutomationId "Editor.QuickValues.Rate.Down" -TimeoutMilliseconds 10000
    for ($index = 0; $index -lt 5; $index++) {
        $rateAction = Invoke-Element $rateDown
        $rateAction["sequence"] = $index + 1
        $actions.Add($rateAction)
        Start-Sleep -Milliseconds 120
    }
    Wait-Condition -Description "0.5x playback rate" -Seconds 20 -Condition {
        $state = Get-AudioState $process.Id
        [Math]::Abs((Get-DiagnosticDouble $state.helpText "PlaybackRate") - .5) -le .001 -and
        (Get-DiagnosticValue $state.helpText "PreservePitch") -ceq
            $(if ($LeavePreservePitchDisabled) { "False" } else { "True" })
    }
    $secondStartState = Get-AudioState $process.Id
    $secondPlay = Invoke-Element $playPause
    $actions.Add($secondPlay)
    Wait-Condition -Description "second 0.5x playback" -Condition {
        (Get-DiagnosticValue (Get-AudioState $process.Id).helpText "State") -ceq "Playing"
    }
    Start-Sleep -Milliseconds 400
    $secondPlayingState = Get-AudioState $process.Id
    Start-Sleep -Milliseconds 1800
    $secondBeforePauseState = Get-AudioState $process.Id
    $halfRateCapture = Capture-Window $handle (Join-Path $output "audio-transport-half-rate-playing.png")
    $secondPause = Invoke-Element $playPause
    $actions.Add($secondPause)
    Wait-Condition -Description "second pause" -Condition {
        (Get-DiagnosticValue (Get-AudioState $process.Id).helpText "State") -ceq "Paused"
    }
    $secondPausedState = Get-AudioState $process.Id
    Start-Sleep -Milliseconds 650

    $timelineBeforeSecondSeek = Get-ElementState $timeline
    $beatBeforeSecondSeek = Get-DiagnosticDouble $timelineBeforeSecondSeek.helpText "CurrentBeat"
    $positionBeforeSecondSeek = Get-DiagnosticDouble $secondPausedState.helpText "PositionMs"
    $thirdSeek = Invoke-MouseWheel $timeline -8 $handle
    $actions.Add($thirdSeek)
    Wait-Condition -Description "second paused timeline wheel seek" -Seconds 20 -Condition {
        $timelineState = Get-ElementState (
            Find-ElementById -ProcessId $process.Id -AutomationId "Timeline.Surface")
        $state = Get-AudioState $process.Id
        (Get-DiagnosticDouble $timelineState.helpText "CurrentBeat") -ge $beatBeforeSecondSeek + 1.8 -and
        (Get-DiagnosticDouble $state.helpText "PositionMs") -ge $positionBeforeSecondSeek + 500 -and
        (Get-DiagnosticValue $state.helpText "State") -ceq "Paused" -and
        (Get-DiagnosticValue $state.helpText "PendingSeek") -ceq "False"
    }
    $thirdStartState = Get-AudioState $process.Id
    $timelineAfterSecondSeek = Get-ElementState $timeline
    $thirdPlay = Invoke-Element $playPause
    $actions.Add($thirdPlay)
    Wait-Condition -Description "third 0.5x playback" -Condition {
        (Get-DiagnosticValue (Get-AudioState $process.Id).helpText "State") -ceq "Playing"
    }
    Start-Sleep -Milliseconds 1300
    $thirdBeforeStopState = Get-AudioState $process.Id
    $commandMenuToggle = Find-ElementById -ProcessId $process.Id `
        -AutomationId "Editor.CommandMenuToggle" -TimeoutMilliseconds 10000
    $openCommandMenu = Invoke-Element $commandMenuToggle
    $openCommandMenu["purpose"] = "Open the visible WPF-parity command menu for Stop."
    $actions.Add($openCommandMenu)
    $stop = Find-ElementById -ProcessId $process.Id `
        -AutomationId "Editor.Command.Stop" -TimeoutMilliseconds 10000
    $stopAction = Invoke-Element $stop
    $actions.Add($stopAction)
    Wait-Condition -Description "stopped audio reset" -Seconds 20 -Condition {
        $state = Get-AudioState $process.Id
        $timelineState = Get-ElementState (
            Find-ElementById -ProcessId $process.Id -AutomationId "Timeline.Surface")
        (Get-DiagnosticValue $state.helpText "State") -ceq "Stopped" -and
        [Math]::Abs((Get-DiagnosticDouble $state.helpText "PositionMs")) -le 100 -and
        [Math]::Abs((Get-DiagnosticDouble $timelineState.helpText "CurrentBeat")) -le .001
    }
    $stoppedState = Get-AudioState $process.Id
    $stoppedTimelineState = Get-ElementState $timeline
    $closeCommandMenu = Invoke-Element $commandMenuToggle
    $closeCommandMenu["purpose"] = "Restore the editor after the visible Stop command."
    $actions.Add($closeCommandMenu)
    Start-Sleep -Milliseconds 700

    if (-not $probe.WaitForExit(20000)) {
        throw "Loopback probe did not exit after its capture window."
    }
    $probeStandardOutput = $probe.StandardOutput.ReadToEnd()
    $probeStandardError = $probe.StandardError.ReadToEnd()
    if ($probe.ExitCode -ne 0) {
        throw "Loopback probe failed with exit code $($probe.ExitCode): $probeStandardError $probeStandardOutput"
    }
    Wait-Condition -Description "loopback probe output" -Condition {
        Test-Path -LiteralPath $probeOutputPath -PathType Leaf
    }
    $probeEvidence = Get-Content -LiteralPath $probeOutputPath -Raw |
        ConvertFrom-Json -DateKind String
    if ($probeEvidence.status -cne "captured" -or
        $probeEvidence.captureScope -cne "process-tree" -or
        [int]$probeEvidence.targetProcessId -ne $process.Id -or
        [long]$probeEvidence.capture.bytes -le 0 -or
        -not [bool]$probeEvidence.capture.timelineIncludesInsertedSilence) {
        throw "WASAPI loopback did not capture the Avalonia process render stream."
    }
    $pulses = @($probeEvidence.analysis.pulses | Sort-Object startMilliseconds)
    if ($pulses.Count -lt 3 -or
        [double]$probeEvidence.analysis.peak -lt .01 -or
        [double]$probeEvidence.analysis.rms -lt .001) {
        throw "Loopback waveform did not prove three audible music intervals: $($probeEvidence.analysis | ConvertTo-Json -Compress -Depth 8)"
    }

    $captureStart = [DateTimeOffset]::Parse([string]$probeReady.startedUtc)
    $playActions = @($firstPlay, $secondPlay, $thirdPlay)
    $alignment = @()
    $pulseIndex = 0
    foreach ($action in $playActions) {
        $actionTime = [DateTimeOffset]::Parse([string]$action.occurredUtc)
        $actionFromCaptureStart = ($actionTime - $captureStart).TotalMilliseconds
        while ($pulseIndex -lt $pulses.Count -and
               [double]$pulses[$pulseIndex].startMilliseconds -lt $actionFromCaptureStart - 150) {
            $pulseIndex++
        }
        if ($pulseIndex -ge $pulses.Count) {
            throw "No loopback pulse remained for play action at $actionFromCaptureStart ms."
        }
        $pulse = $pulses[$pulseIndex]
        $delta = [double]$pulse.startMilliseconds - $actionFromCaptureStart
        if ($delta -lt -150 -or $delta -gt 650) {
            throw "Loopback pulse was not aligned with play action: $delta ms."
        }
        $alignment += [ordered]@{
            actionOccurredUtc = [string]$action.occurredUtc
            actionFromCaptureStartMilliseconds = $actionFromCaptureStart
            pulseStartMilliseconds = [double]$pulse.startMilliseconds
            pulseDurationMilliseconds = [double]$pulse.durationMilliseconds
            pulsePeak = [double]$pulse.peak
            startDeltaMilliseconds = $delta
        }
        $pulseIndex++
    }

    $firstStartPosition = Get-DiagnosticDouble $firstPlayingState.helpText "PositionMs"
    $firstEndPosition = Get-DiagnosticDouble $firstBeforePauseState.helpText "PositionMs"
    $firstWallMilliseconds = (
        [DateTimeOffset]::Parse(
            (Get-DiagnosticValue $firstBeforePauseState.helpText "PositionObservedUtc")) -
        [DateTimeOffset]::Parse(
            (Get-DiagnosticValue $firstPlayingState.helpText "PositionObservedUtc"))).TotalMilliseconds
    $firstPositionDelta = $firstEndPosition - $firstStartPosition
    $firstEffectiveRate = $firstPositionDelta / $firstWallMilliseconds

    $secondStartPosition = Get-DiagnosticDouble $secondPlayingState.helpText "PositionMs"
    $secondEndPosition = Get-DiagnosticDouble $secondBeforePauseState.helpText "PositionMs"
    $secondWallMilliseconds = (
        [DateTimeOffset]::Parse(
            (Get-DiagnosticValue $secondBeforePauseState.helpText "PositionObservedUtc")) -
        [DateTimeOffset]::Parse(
            (Get-DiagnosticValue $secondPlayingState.helpText "PositionObservedUtc"))).TotalMilliseconds
    $secondPositionDelta = $secondEndPosition - $secondStartPosition
    $secondEffectiveRate = $secondPositionDelta / $secondWallMilliseconds
    [ordered]@{
        first = [ordered]@{
            start = $firstPlayingState
            end = $firstBeforePauseState
            wallMilliseconds = $firstWallMilliseconds
            positionDeltaMilliseconds = $firstPositionDelta
            effectiveRate = $firstEffectiveRate
        }
        second = [ordered]@{
            start = $secondPlayingState
            end = $secondBeforePauseState
            wallMilliseconds = $secondWallMilliseconds
            positionDeltaMilliseconds = $secondPositionDelta
            effectiveRate = $secondEffectiveRate
        }
    } | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath (Join-Path $output "clock-measurements.json") `
            -Encoding utf8NoBOM
    if ($firstEffectiveRate -lt .78 -or $firstEffectiveRate -gt 1.22) {
        throw "1.0x position clock ratio was $firstEffectiveRate."
    }
    if ($secondEffectiveRate -lt .35 -or $secondEffectiveRate -gt .65) {
        throw "0.5x position clock ratio was $secondEffectiveRate."
    }
    $firstSeekPositionAfter = Get-DiagnosticDouble $firstSeekedState.helpText "PositionMs"
    $firstSeekBeatAfter = Get-DiagnosticDouble $timelineAfterFirstSeek.helpText "CurrentBeat"
    $secondSeekPositionAfter = Get-DiagnosticDouble $thirdStartState.helpText "PositionMs"
    $secondSeekBeatAfter = Get-DiagnosticDouble $timelineAfterSecondSeek.helpText "CurrentBeat"

    $afterCapture = Capture-Window $handle (Join-Path $output "audio-transport-stopped.png")
    $fixtureChartAfter = Assert-FingerprintUnchanged $fixtureChartBefore "real MC fixture"
    $fixtureAudioAfter = Assert-FingerprintUnchanged $fixtureAudioBefore "real OGG fixture"
    $workingChartAfter = Assert-FingerprintUnchanged $workingChartBefore "isolated MC copy"
    $workingAudioAfter = Assert-FingerprintUnchanged $workingAudioBefore "isolated OGG copy"
    $installerAfter = Assert-FingerprintUnchanged $installerBefore "frozen WPF installer"

    $screenshots = [ordered]@{}
    foreach ($path in Get-ChildItem -LiteralPath $output -File -Filter "*.png" | Sort-Object Name) {
        $screenshots[$path.BaseName] = [ordered]@{
            path = $path.FullName
            bytes = $path.Length
            sha256 = (Get-FileHash -LiteralPath $path.FullName -Algorithm SHA256).Hash
        }
    }

    [ordered]@{
        schema = "lumachart.windows.avalonia.audio-transport-loopback-interaction-progress.v1"
        captureStartedUtc = [string]$probeReady.startedUtc
        setupActions = $setupActions
        actions = $actions.ToArray()
        initialState = $initialState
        stoppedState = $stoppedState
    } | ConvertTo-Json -Depth 20 |
        Set-Content -LiteralPath $interactionProgressPath -Encoding utf8NoBOM

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.audio-transport-loopback-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        formalMigrationAuthority = [bool]$FormalMigrationAuthority
        completion = $false
        migrationComplete = $false
        windowsAvaloniaOnly = $true
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        physicalMouseInputUsed = $false
        win32MouseWheelInjected = $true
        uiAutomationPatternsUsed = @("InvokePattern", "SelectionItemPattern", "TogglePattern")
        paths = [ordered]@{
            outputRoot = $output
            application = $application
            probeAssembly = $probeAssembly
            temp = $projectTemp
            dotnetHome = $dotnetHome
            nugetPackages = $nugetPackages
            nugetHttpCache = $nugetHttpCache
        }
        hashes = [ordered]@{
            application = (Get-FileHash -LiteralPath $application -Algorithm SHA256).Hash
            probeAssembly = (Get-FileHash -LiteralPath $probeAssembly -Algorithm SHA256).Hash
            loopbackWave = (Get-FileHash -LiteralPath $probeWavePath -Algorithm SHA256).Hash
            loopbackProbe = (Get-FileHash -LiteralPath $probeOutputPath -Algorithm SHA256).Hash
            interactionProgress = (Get-FileHash -LiteralPath $interactionProgressPath -Algorithm SHA256).Hash
        }
        fixture = [ordered]@{
            chartBefore = $fixtureChartBefore
            chartAfter = $fixtureChartAfter
            audioBefore = $fixtureAudioBefore
            audioAfter = $fixtureAudioAfter
            isolatedChartBefore = $workingChartBefore
            isolatedChartAfter = $workingChartAfter
            isolatedAudioBefore = $workingAudioBefore
            isolatedAudioAfter = $workingAudioAfter
            releasedInstallerBefore = $installerBefore
            releasedInstallerAfter = $installerAfter
        }
        ui = [ordered]@{
            initial = $initialState
            firstPlaying = $firstPlayingState
            firstPaused = $firstPausedState
            pauseStable = $pauseStableState
            secondPlaying = $secondPlayingState
            stopped = $stoppedState
            beforeCapture = $beforeCapture
            pausedCapture = $pausedCapture
            halfRateCapture = $halfRateCapture
            stoppedCapture = $afterCapture
        }
        transport = [ordered]@{
            firstSegment = [ordered]@{
                configuredRate = 1.0
                startPositionMilliseconds = $firstStartPosition
                endPositionMilliseconds = $firstEndPosition
                wallMilliseconds = $firstWallMilliseconds
                positionDeltaMilliseconds = $firstPositionDelta
                effectiveRate = $firstEffectiveRate
            }
            pause = [ordered]@{
                startPositionMilliseconds = $pausedPositionStart
                endPositionMilliseconds = $pausedPositionEnd
                driftMilliseconds = $pauseDrift
                observedWallMilliseconds = 700
            }
            secondSegment = [ordered]@{
                configuredRate = .5
                preservePitch = -not $LeavePreservePitchDisabled
                startPositionMilliseconds = $secondStartPosition
                endPositionMilliseconds = $secondEndPosition
                wallMilliseconds = $secondWallMilliseconds
                positionDeltaMilliseconds = $secondPositionDelta
                effectiveRate = $secondEffectiveRate
            }
            firstPausedSeek = [ordered]@{
                beforeBeat = $beatBeforeSeek
                afterBeat = $firstSeekBeatAfter
                beforePositionMilliseconds = $positionBeforeSeek
                afterPositionMilliseconds = $firstSeekPositionAfter
                positionDeltaMilliseconds = $firstSeekPositionAfter - $positionBeforeSeek
                wheelDetents = -8
            }
            secondPausedSeek = [ordered]@{
                beforeBeat = $beatBeforeSecondSeek
                afterBeat = $secondSeekBeatAfter
                beforePositionMilliseconds = $positionBeforeSecondSeek
                afterPositionMilliseconds = $secondSeekPositionAfter
                positionDeltaMilliseconds = $secondSeekPositionAfter - $positionBeforeSecondSeek
                wheelDetents = -8
            }
            stoppedPositionMilliseconds = Get-DiagnosticDouble $stoppedState.helpText "PositionMs"
            stoppedBeat = Get-DiagnosticDouble $stoppedTimelineState.helpText "CurrentBeat"
        }
        setupActions = $setupActions
        actions = $actions.ToArray()
        loopback = [ordered]@{
            ready = $probeReady
            probe = $probeEvidence
            playPulseAlignment = $alignment
            capturedAvaloniaProcessTree = $true
            capturedPhysicalTransducer = $false
        }
        screenshots = $screenshots
    }
    $evidencePath = Join-Path $output "evidence.json"
    $evidence | ConvertTo-Json -Depth 30 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Write-Host "Windows Avalonia audio transport WASAPI loopback GUI capture: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    Stop-TrackedProcess $probe
    Stop-TrackedProcess $process
}
