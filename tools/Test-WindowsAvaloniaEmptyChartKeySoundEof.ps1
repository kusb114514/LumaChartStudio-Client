param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ProbeAssemblyPath = (Join-Path $PSScriptRoot "WindowsAudioLoopbackProbe\bin\Release\net8.0-windows\WindowsAudioLoopbackProbe.dll"),
    [string]$ChartFixturePath = (Join-Path $PSScriptRoot "..\TestFixtures\malody-noteref-test.mc"),
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(5, 30)][int]$CaptureSeconds = 10
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "The empty-chart Key sound regression requires PowerShell Core on Windows."
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
        [int]$Seconds = 45
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 50
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

function Find-ElementById([int]$ProcessId, [string]$AutomationId) {
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(45)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children,
                $processCondition)
            foreach ($root in $roots) {
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
    throw "Timed out waiting for UI Automation id '$AutomationId'."
}

function Invoke-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' lacks InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Select-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' lacks SelectionItemPattern."
    }
    ([Windows.Automation.SelectionItemPattern]$pattern).Select()
}

function Get-DiagnosticValue([string]$Text, [string]$Name) {
    $match = [regex]::Match(
        $Text,
        "(?i)(?:^|;\s*)$([regex]::Escape($Name))=([^;]*)")
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value.Trim()
}

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartEmptyKeySoundNative
{
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);
}
'@

$application = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$probeAssembly = Resolve-ExistingFile $ProbeAssemblyPath "loopback probe assembly"
$chartFixture = Resolve-ExistingFile $ChartFixturePath "empty-chart fixture"
$output = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $output) {
    throw "Output root already exists: $output"
}

$clientRoot = Join-Path $output "client"
$workingRoot = Join-Path $clientRoot "working"
$localDataRoot = Join-Path $clientRoot "local-data"
$editingRoot = Join-Path $clientRoot "editing"
$workspaceRoot = Join-Path $clientRoot "workspace"
foreach ($directory in @($output, $workingRoot, $localDataRoot, $editingRoot, $workspaceRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$workingChart = Join-Path $workingRoot "empty-key-sound.mc"
Copy-Item -LiteralPath $chartFixture -Destination $workingChart
[ordered]@{
    SchemaVersion = 1
    EnableKeySounds = $true
    Volume = 1.0
    Preset = "Snare"
    CustomFilePath = $null
    PlayLongNoteEndSound = $false
    GlobalOffset = 0
    PerChartOffsets = @{}
} | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $localDataRoot "key-sound-settings.json") -Encoding utf8NoBOM
[ordered]@{
    SchemaVersion = 1
    GridLaneWidth = 84
    GridBeatHeight = 220
    MainEditorHorizontalOffset = 0
    NoteWidth = 66
    NoteHeight = 32
    NoteOpacity = 1
    JudgementLinePosition = 0.79
    JudgementLineThickness = 1.5
    JudgementLineOpacity = 0.85
    AutoBackupEnabled = $true
    AutoBackupMinutes = 5
    QuickPaletteX = 46
    QuickPaletteY = 0
    QuickPaletteCollapsed = $false
    QuickValuesPaletteX = 290
    QuickValuesPaletteY = 308
    QuickValuesPaletteCollapsed = $false
    SnapDivision = 4
    PlaybackRate = 1
    DifficultyCardX = 0
    DifficultyCardY = 0
    DifficultyCardCollapsed = $false
    FrameRateLimit = 240
    NoteAnchor = 3
    MusicVolume = 0.8
    PreservePitch = $false
    FullscreenMode = 0
    BarLineThickness = 1.55
    SubdivisionLineThickness = 0.8
} | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $localDataRoot "editor-view-settings.json") -Encoding utf8NoBOM

$runtimePath = Join-Path $output "runtime.json"
$probePath = Join-Path $output "probe.json"
$wavePath = Join-Path $output "capture.wav"
$readyPath = Join-Path $output "ready.json"
$summaryPath = Join-Path $output "summary.json"
$applicationProcess = $null
$probeProcess = $null

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
    $profile = "windows-avalonia-empty-key-sound-eof-$([Guid]::NewGuid().ToString('N'))"
    $start.Environment["LUMACHART_PROFILE"] = $profile
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceRoot
    $applicationProcess = [Diagnostics.Process]::Start($start)
    if (-not $applicationProcess) { throw "Failed to start Windows Avalonia client." }

    Wait-Condition -Description "Avalonia main window" -Condition {
        $applicationProcess.Refresh()
        -not $applicationProcess.HasExited -and
            $applicationProcess.MainWindowHandle -ne [IntPtr]::Zero
    }
    [void][LumaChartEmptyKeySoundNative]::ShowWindow(
        $applicationProcess.MainWindowHandle,
        3)
    [void][LumaChartEmptyKeySoundNative]::SetForegroundWindow(
        $applicationProcess.MainWindowHandle)
    Start-Sleep -Milliseconds 500
    $playPause = Find-ElementById $applicationProcess.Id "Editor.QuickPlayPause"
    Wait-Condition -Description "active empty chart" -Condition {
        $helpText = [string]$playPause.Current.HelpText
        $activeTabId = Get-DiagnosticValue $helpText "ActiveTabId"
        $durationText = Get-DiagnosticValue $helpText "DurationMs"
        $positionText = Get-DiagnosticValue $helpText "PositionMs"
        $silentPlaying = Get-DiagnosticValue $helpText "SilentPlaying"
        $duration = 0.0
        $position = [double]::PositiveInfinity
        -not [string]::IsNullOrWhiteSpace($activeTabId) -and
            [double]::TryParse(
                $durationText,
                [Globalization.NumberStyles]::Float,
                [Globalization.CultureInfo]::InvariantCulture,
                [ref]$duration) -and
            $duration -gt 0 -and
            [double]::TryParse(
                $positionText,
                [Globalization.NumberStyles]::Float,
                [Globalization.CultureInfo]::InvariantCulture,
                [ref]$position) -and
            $position -le 2 -and
            $silentPlaying -ceq "False"
    }
    $settingsTab = Find-ElementById $applicationProcess.Id "Inspector.SettingsTab"
    Select-Element $settingsTab
    $keySoundStatus = Find-ElementById $applicationProcess.Id "KeySound.RuntimeStatus"
    Wait-Condition -Description "Key sound plan readiness" -Condition {
        $helpText = [string]$keySoundStatus.Current.HelpText
        (Get-DiagnosticValue $helpText "Enabled") -ceq "True" -and
            (Get-DiagnosticValue $helpText "HasPlan") -ceq "True" -and
            (Get-DiagnosticValue $helpText "Preparing") -ceq "False"
    }
    $preview = Find-ElementById $applicationProcess.Id "KeySound.Preview"
    $beforeTransport = [string]$playPause.Current.HelpText
    $beforeKeySound = [string]$keySoundStatus.Current.HelpText

    $probeStart = [Diagnostics.ProcessStartInfo]::new()
    $probeStart.FileName = "dotnet"
    $probeStart.UseShellExecute = $false
    $probeStart.WorkingDirectory = Split-Path -Parent $probeAssembly
    foreach ($argument in @(
            $probeAssembly,
            "--output", $probePath,
            "--wav", $wavePath,
            "--ready", $readyPath,
            "--duration-ms", [string]($CaptureSeconds * 1000),
            "--process-id", [string]$applicationProcess.Id)) {
        $probeStart.ArgumentList.Add($argument)
    }
    $probeProcess = [Diagnostics.Process]::Start($probeStart)
    if (-not $probeProcess) { throw "Failed to start process loopback probe." }
    Wait-Condition -Description "loopback probe readiness" -Seconds 20 -Condition {
        $probeProcess.Refresh()
        (Test-Path -LiteralPath $readyPath) -or $probeProcess.HasExited
    }
    if (-not (Test-Path -LiteralPath $readyPath)) {
        throw "Loopback probe exited before becoming ready."
    }

    Start-Sleep -Milliseconds 400
    Invoke-Element $preview
    Start-Sleep -Milliseconds 2000
    Invoke-Element $preview
    if (-not $probeProcess.WaitForExit(($CaptureSeconds + 15) * 1000)) {
        throw "Loopback probe did not finish."
    }
    if ($probeProcess.ExitCode -ne 0) {
        throw "Loopback probe failed with exit code $($probeProcess.ExitCode)."
    }

    $evidence = Get-Content -LiteralPath $probePath -Raw | ConvertFrom-Json
    $afterTransport = [string]$playPause.Current.HelpText
    $afterKeySound = [string]$keySoundStatus.Current.HelpText
    $pulses = @($evidence.analysis.pulses)
    $lastPulseEnd = if ($pulses.Count -gt 0) {
        [double]$pulses[-1].startMilliseconds + [double]$pulses[-1].durationMilliseconds
    }
    else { 0 }
    $silentTailMilliseconds = [double]$evidence.analysis.durationMilliseconds - $lastPulseEnd
    $previewAcceptedText = Get-DiagnosticValue $afterKeySound "PreviewAccepted"
    $previewAccepted = 0L
    [void][long]::TryParse($previewAcceptedText, [ref]$previewAccepted)
    $accepted = $pulses.Count -eq 2 -and
        @($pulses | Where-Object { [double]$_.durationMilliseconds -gt 350 }).Count -eq 0 -and
        $silentTailMilliseconds -ge 5000 -and
        $previewAccepted -ge 2
    $summary = [ordered]@{
        schema = "lumachart.windows.empty-chart-key-sound-eof.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        accepted = $accepted
        applicationPath = $application
        chartPath = $workingChart
        keySoundVolume = 1.0
        beforeTransport = $beforeTransport
        afterTransport = $afterTransport
        beforeKeySound = $beforeKeySound
        afterKeySound = $afterKeySound
        previewAccepted = $previewAccepted
        detectedPulseCount = $pulses.Count
        pulses = $pulses
        silentTailMilliseconds = $silentTailMilliseconds
        peak = $evidence.analysis.peak
        rms = $evidence.analysis.rms
        wavePath = $wavePath
        probePath = $probePath
    }
    $summary | ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath $summaryPath -Encoding utf8NoBOM
    if (-not $accepted) {
        throw "Empty-chart Key sound EOF regression failed. See $summaryPath"
    }
    $summary | ConvertTo-Json -Depth 10
}
finally {
    if ($probeProcess -and -not $probeProcess.HasExited) {
        try { $probeProcess.Kill($true) } catch { }
    }
    if ($applicationProcess -and -not $applicationProcess.HasExited) {
        try { $applicationProcess.Kill($true) } catch { }
    }
}
