param(
    [Parameter(Mandatory = $true)][string]$AvaloniaApplicationPath,
    [Parameter(Mandatory = $true)][string]$WpfApplicationPath,
    [Parameter(Mandatory = $true)][string]$ChartPath,
    [Parameter(Mandatory = $true)][string]$FrameProbePath,
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [Parameter(Mandatory = $true)][string]$WorkingRoot,
    [ValidateSet(60, 165)][int]$ExpectedRefreshHz,
    [switch]$AllowForegroundAutomation
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows performance GUI capture requires PowerShell Core on Windows."
}
if (-not $AllowForegroundAutomation) {
    throw "Pass -AllowForegroundAutomation only after explicit desktop consent."
}

function Resolve-File([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "$Label not found: $full"
    }
    return $full
}

function New-EmptyDirectory([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) {
        if (@(Get-ChildItem -LiteralPath $full -Force).Count -ne 0) {
            throw "$Label must be empty: $full"
        }
    }
    else {
        New-Item -ItemType Directory -Path $full | Out-Null
    }
    return $full
}

$avaloniaApplicationPath = Resolve-File $AvaloniaApplicationPath "Avalonia application"
$wpfApplicationPath = Resolve-File $WpfApplicationPath "WPF application"
$chartPath = Resolve-File $ChartPath "100k chart"
$frameProbePath = Resolve-File $FrameProbePath "frame probe"
$outputRoot = New-EmptyDirectory $OutputRoot "Output root"
$workingRoot = New-EmptyDirectory $WorkingRoot "Working root"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LumaChartPerformanceGuiNative
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
    public static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr window);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
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
}
'@

function Wait-MainWindow([Diagnostics.Process]$Process) {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(75)
    do {
        Start-Sleep -Milliseconds 200
        $Process.Refresh()
        if ($Process.HasExited) {
            throw "$($Process.ProcessName) exited before exposing the editor."
        }
        if ($Process.MainWindowHandle -ne [IntPtr]::Zero -and
            $Process.MainWindowTitle -match "Performance 100,000") {
            return
        }
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for the 100k editor."
}

function Stop-TestProcess([Diagnostics.Process]$Process) {
    if ($null -eq $Process -or $Process.HasExited) { return }
    [void]$Process.CloseMainWindow()
    if (-not $Process.WaitForExit(5000)) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    }
}

function Set-ForegroundVerified([IntPtr]$Handle) {
    [void][LumaChartPerformanceGuiNative]::ShowWindowAsync($Handle, 9)
    for ($attempt = 0; $attempt -lt 12; $attempt++) {
        [void][LumaChartPerformanceGuiNative]::BringWindowToTop($Handle)
        [void][LumaChartPerformanceGuiNative]::SetForegroundWindow($Handle)
        if ([LumaChartPerformanceGuiNative]::GetForegroundWindow() -eq $Handle) { return }
        Start-Sleep -Milliseconds 100
    }
    throw "Could not foreground performance window $Handle."
}

function Set-StandardWindow([IntPtr]$Handle) {
    if (-not [LumaChartPerformanceGuiNative]::SetWindowPos(
            $Handle, [IntPtr]::Zero, 290, 164, 1980, 1200, 0x0040)) {
        throw "SetWindowPos failed."
    }
    Start-Sleep -Milliseconds 300
}

function Find-ByAutomationId(
    [Windows.Automation.AutomationElement]$Root,
    [string]$AutomationId) {
    $condition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    return $Root.FindFirst(
        [Windows.Automation.TreeScope]::Descendants,
        $condition)
}

function Find-ByName(
    [Windows.Automation.AutomationElement]$Root,
    [string]$Name) {
    $condition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty,
        $Name)
    return $Root.FindFirst(
        [Windows.Automation.TreeScope]::Descendants,
        $condition)
}

function Invoke-Element([Windows.Automation.AutomationElement]$Element, [string]$Label) {
    if ($null -eq $Element) { throw "$Label was not found." }
    $pattern = $Element.GetCurrentPattern(
        [Windows.Automation.InvokePattern]::Pattern)
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    Set-ForegroundVerified $Handle
    Start-Sleep -Milliseconds 250
    $rectangle = New-Object LumaChartPerformanceGuiNative+RECT
    if (-not [LumaChartPerformanceGuiNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) {
        throw "GetWindowRect failed."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 900 -or $height -lt 600) {
        throw "Performance screenshot bounds are invalid."
    }
    $bitmap = [Drawing.Bitmap]::new(
        $width,
        $height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen(
                $rectangle.Left,
                $rectangle.Top,
                0,
                0,
                [Drawing.Size]::new($width, $height))
        }
        finally {
            $graphics.Dispose()
        }
        $colors = [Collections.Generic.HashSet[int]]::new()
        for ($y = 0; $y -lt 16; $y++) {
            for ($x = 0; $x -lt 16; $x++) {
                $sampleX = [Math]::Min(
                    $width - 1,
                    [int](($x + .5) * $width / 16))
                $sampleY = [Math]::Min(
                    $height - 1,
                    [int](($y + .5) * $height / 16))
                [void]$colors.Add($bitmap.GetPixel($sampleX, $sampleY).ToArgb())
            }
        }
        if ($colors.Count -lt 12) { throw "Performance screenshot is near-uniform." }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            path = $Path
            width = $width
            height = $height
            sampledUniqueColors = $colors.Count
            length = (Get-Item -LiteralPath $Path).Length
            sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

function Read-PlaybackSamples(
    [Windows.Automation.AutomationElement]$Element,
    [int]$Count = 12) {
    $samples = @()
    for ($index = 0; $index -lt $Count; $index++) {
        Start-Sleep -Milliseconds 550
        $samples += [ordered]@{
            utc = [DateTimeOffset]::UtcNow.ToString("O")
            name = $Element.Current.Name
            helpText = $Element.Current.HelpText
        }
    }
    return $samples
}

function Get-Percentile([double[]]$Ordered, [double]$Percentile) {
    if ($Ordered.Count -eq 0) { return 0.0 }
    $position = $Percentile * ($Ordered.Count - 1)
    $lower = [Math]::Floor($position)
    $upper = [Math]::Ceiling($position)
    if ($lower -eq $upper) { return [double]$Ordered[$lower] }
    $fraction = $position - $lower
    return [double](
        $Ordered[$lower] +
        ($Ordered[$upper] - $Ordered[$lower]) * $fraction)
}

function Get-Distribution([double[]]$Values) {
    $ordered = @($Values | Sort-Object)
    if ($ordered.Count -eq 0) {
        return [ordered]@{
            samples = 0
            p50 = 0.0
            p95 = 0.0
            p99 = 0.0
            minimum = 0.0
            maximum = 0.0
            mean = 0.0
        }
    }
    return [ordered]@{
        samples = $ordered.Count
        p50 = Get-Percentile $ordered 0.50
        p95 = Get-Percentile $ordered 0.95
        p99 = Get-Percentile $ordered 0.99
        minimum = [double]$ordered[0]
        maximum = [double]$ordered[-1]
        mean = [double](($ordered | Measure-Object -Average).Average)
    }
}

function Get-PlaybackSummary([object[]]$Samples) {
    $frames = @()
    $callbacks = @()
    $peakRenderSamples = -1
    $peakRenderHelpText = $null
    foreach ($sample in $Samples) {
        if ($sample.name -match
            "画面:\s*(?<frames>\d+)\s*·\s*(?:更新回调|合成回调):\s*(?<callbacks>\d+)") {
            $frame = [int]$Matches.frames
            $callback = [int]$Matches.callbacks
            if ($frame -gt 0 -and $callback -gt 0) {
                $frames += $frame
                $callbacks += $callback
            }
        }
        if ($sample.helpText -match "RenderSamples=(?<renderSamples>\d+)") {
            $renderSamples = [int]$Matches.renderSamples
            if ($renderSamples -gt $peakRenderSamples) {
                $peakRenderSamples = $renderSamples
                $peakRenderHelpText = $sample.helpText
            }
        }
    }
    return [ordered]@{
        frameRate = Get-Distribution $frames
        callbackRate = Get-Distribution $callbacks
        peakRenderSamples = [Math]::Max(0, $peakRenderSamples)
        peakRenderHelpText = $peakRenderHelpText
    }
}

function Invoke-VisibleProbe(
    [Diagnostics.Process]$Process,
    [string]$Path) {
    $probeConsole = & $frameProbePath probe `
        --process-id $Process.Id `
        --output $Path `
        --composition-frames 180 `
        --input-trials 12
    $probeExitCode = $LASTEXITCODE
    if ($probeExitCode -ne 0) {
        throw (
            "Visible frame probe failed with exit code $probeExitCode. " +
            ($probeConsole -join [Environment]::NewLine))
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Invoke-UiaInputToRenderProbe(
    [Diagnostics.Process]$Process,
    [string]$Path) {
    $probeConsole = & $frameProbePath uia-input-probe `
        --process-id $Process.Id `
        --output $Path `
        --input-trials 12
    $probeExitCode = $LASTEXITCODE
    if ($probeExitCode -ne 0) {
        throw (
            "UIA input-to-render probe failed with exit code $probeExitCode. " +
            ($probeConsole -join [Environment]::NewLine))
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

$display = (& $frameProbePath display-list | ConvertFrom-Json).current
if ($display.Width -ne 2560 -or
    $display.Height -ne 1600 -or
    $display.RefreshHz -ne $ExpectedRefreshHz) {
    throw (
        "Unexpected display mode: " +
        "$($display.Width)x$($display.Height)@$($display.RefreshHz).")
}

$avalonia = $null
$wpf = $null
$avaloniaProcess = $null
$wpfProcess = $null
try {
    $avaloniaRoot = Join-Path $workingRoot "avalonia"
    New-Item -ItemType Directory -Path $avaloniaRoot | Out-Null
    $env:LUMACHART_AVALONIA_LOCAL_DATA_ROOT = Join-Path $avaloniaRoot "local-data"
    $env:LUMACHART_AVALONIA_EDITING_ROOT = Join-Path $avaloniaRoot "editing"
    $env:LUMACHART_AVALONIA_WORKSPACE_ROOT = Join-Path $avaloniaRoot "workspace"
    $avaloniaInfo = [Diagnostics.ProcessStartInfo]::new($avaloniaApplicationPath)
    $avaloniaInfo.UseShellExecute = $false
    [void]$avaloniaInfo.ArgumentList.Add($chartPath)
    $avaloniaProcess = [Diagnostics.Process]::Start($avaloniaInfo)
    Wait-MainWindow $avaloniaProcess
    Set-StandardWindow $avaloniaProcess.MainWindowHandle
    Start-Sleep -Seconds 5
    $avaloniaRootElement =
        [Windows.Automation.AutomationElement]::FromHandle(
            $avaloniaProcess.MainWindowHandle)
    $avaloniaOffline = Find-ByAutomationId `
        $avaloniaRootElement `
        "OnlineAccount.ContinueOffline"
    if ($null -ne $avaloniaOffline) {
        Invoke-Element $avaloniaOffline "Avalonia offline button"
        Start-Sleep -Seconds 2
        $avaloniaRootElement =
            [Windows.Automation.AutomationElement]::FromHandle(
                $avaloniaProcess.MainWindowHandle)
    }
    $avaloniaPlay = Find-ByAutomationId $avaloniaRootElement "Editor.QuickPlayPause"
    $avaloniaFps = Find-ByAutomationId $avaloniaRootElement "Editor.FrameRateStatus"
    $avaloniaCount = Find-ByName $avaloniaRootElement "100,000"
    if ($null -eq $avaloniaFps -or $null -eq $avaloniaCount) {
        throw "Avalonia 100k/FPS UI Automation evidence is missing."
    }
    Invoke-Element $avaloniaPlay "Avalonia play button"
    $avaloniaSamples = Read-PlaybackSamples $avaloniaFps
    $avaloniaScreenshot = Capture-Window `
        $avaloniaProcess.MainWindowHandle `
        (Join-Path $outputRoot "avalonia-playback.png")
    Invoke-Element $avaloniaPlay "Avalonia pause button"
    Start-Sleep -Milliseconds 400
    $avaloniaProbePath =
        Join-Path $outputRoot "avalonia-uia-input-to-render-probe.json"
    $avaloniaInputToRenderProbe =
        Invoke-UiaInputToRenderProbe $avaloniaProcess $avaloniaProbePath
    $avalonia = [ordered]@{
        processId = $avaloniaProcess.Id
        executable = $avaloniaApplicationPath
        executableSha256 =
            (Get-FileHash -LiteralPath $avaloniaApplicationPath -Algorithm SHA256).Hash
        title = $avaloniaProcess.MainWindowTitle
        noteCountAutomationName = $avaloniaCount.Current.Name
        playbackSamples = $avaloniaSamples
        playbackSummary = Get-PlaybackSummary $avaloniaSamples
        screenshot = $avaloniaScreenshot
        inputToRenderProbePath = $avaloniaProbePath
        inputToRenderProbe = $avaloniaInputToRenderProbe
    }
    Stop-TestProcess $avaloniaProcess
    $avaloniaProcess = $null

    $wpfRoot = Join-Path $workingRoot "wpf"
    New-Item -ItemType Directory -Path $wpfRoot | Out-Null
    $env:LUMACHART_LOCAL_DATA_ROOT = Join-Path $wpfRoot "local-data"
    $wpfInfo = [Diagnostics.ProcessStartInfo]::new($wpfApplicationPath)
    $wpfInfo.UseShellExecute = $false
    [void]$wpfInfo.ArgumentList.Add($chartPath)
    $wpfProcess = [Diagnostics.Process]::Start($wpfInfo)
    Wait-MainWindow $wpfProcess
    Set-StandardWindow $wpfProcess.MainWindowHandle
    Start-Sleep -Seconds 3
    $wpfRootElement =
        [Windows.Automation.AutomationElement]::FromHandle(
            $wpfProcess.MainWindowHandle)
    $offline = Find-ByName $wpfRootElement "不登录，离线使用 →"
    if ($null -ne $offline) {
        Invoke-Element $offline "WPF offline button"
        Start-Sleep -Seconds 3
    }
    $wpfFps = Find-ByAutomationId $wpfRootElement "EditorFpsText"
    $wpfCount = Find-ByAutomationId $wpfRootElement "MiniNoteCount"
    if ($null -eq $wpfFps -or $null -eq $wpfCount -or
        $wpfCount.Current.Name -ne "100000") {
        throw "WPF 100k/FPS UI Automation evidence is missing."
    }
    Set-ForegroundVerified $wpfProcess.MainWindowHandle
    [Windows.Forms.SendKeys]::SendWait(" ")
    $wpfSamples = Read-PlaybackSamples $wpfFps
    $wpfScreenshot = Capture-Window `
        $wpfProcess.MainWindowHandle `
        (Join-Path $outputRoot "wpf-playback.png")
    Set-ForegroundVerified $wpfProcess.MainWindowHandle
    [Windows.Forms.SendKeys]::SendWait(" ")
    Start-Sleep -Milliseconds 400
    $wpfProbePath = Join-Path $outputRoot "wpf-visible-probe.json"
    $wpfVisibleProbe = Invoke-VisibleProbe $wpfProcess $wpfProbePath
    $wpf = [ordered]@{
        processId = $wpfProcess.Id
        executable = $wpfApplicationPath
        executableSha256 =
            (Get-FileHash -LiteralPath $wpfApplicationPath -Algorithm SHA256).Hash
        title = $wpfProcess.MainWindowTitle
        noteCountAutomationName = $wpfCount.Current.Name
        playbackSamples = $wpfSamples
        playbackSummary = Get-PlaybackSummary $wpfSamples
        screenshot = $wpfScreenshot
        visibleProbePath = $wpfProbePath
        visibleProbe = $wpfVisibleProbe
    }
}
finally {
    if ($null -ne $avaloniaProcess) { Stop-TestProcess $avaloniaProcess }
    if ($null -ne $wpfProcess) { Stop-TestProcess $wpfProcess }
}

$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.performance-gui.v2"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    platformScope = "Windows-only"
    display = $display
    chart = [ordered]@{
        path = $chartPath
        length = (Get-Item -LiteralPath $chartPath).Length
        sha256 = (Get-FileHash -LiteralPath $chartPath -Algorithm SHA256).Hash
    }
    semantics = [ordered]@{
        playbackFps = "client UI frame counter while real audio drives the real 100k editor"
        avaloniaFrameDistribution =
            "TimelineSurface.Render entry intervals; CPU render duration; not GPU present-to-present ETW"
        avaloniaInputProbe =
            "external QPC before Win32 SendInput to first UIA observation of changed beat plus TimelineSurface render sample"
        wpfVisibleProbe =
            "DwmFlush plus desktop BitBlt A/B interaction probe; not PresentMon or hardware-device latency"
        hardwareInputClaimed = $false
        win32SendInputUsed = $true
    }
    avalonia = $avalonia
    wpf = $wpf
}
$evidencePath = Join-Path $outputRoot "capture-evidence.json"
$evidence | ConvertTo-Json -Depth 12 |
    Set-Content -LiteralPath $evidencePath -Encoding utf8
Write-Output $evidencePath
