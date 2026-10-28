param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$AudioFixturePath = "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(60, 300)][int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia BPM responsiveness GUI capture requires PowerShell Core on Windows."
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
        [int]$Seconds = $TimeoutSeconds
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try {
            if (& $Condition) { return }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartBpmResponsivenessGuiNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr window, IntPtr deviceContext, uint flags);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr window, int command);
}
'@

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 300000)][int]$TimeoutMilliseconds = 10000
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
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
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

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartBpmResponsivenessGuiNative+RECT]::new()
    if (-not [LumaChartBpmResponsivenessGuiNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 300 -or $height -lt 180) {
        throw "Window has invalid bounds: ${width}x${height}."
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
                if (-not [LumaChartBpmResponsivenessGuiNative]::PrintWindow(
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
        $colors = [Collections.Generic.HashSet[int]]::new()
        for ($y = 0; $y -lt 16; $y++) {
            for ($x = 0; $x -lt 16; $x++) {
                $pixel = $bitmap.GetPixel(
                    [Math]::Min($width - 1, [int](($x + .5) * $width / 16)),
                    [Math]::Min($height - 1, [int](($y + .5) * $height / 16)))
                [void]$colors.Add($pixel.ToArgb())
            }
        }
        if ($colors.Count -lt 6) {
            throw "Screenshot is near-uniform: $($colors.Count) sampled colors."
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            width = $width
            height = $height
            sampledUniqueColors = $colors.Count
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

function Stop-TrackedClient([Diagnostics.Process]$Process) {
    if (-not $Process -or $Process.HasExited) { return }
    [void]$Process.CloseMainWindow()
    if (-not $Process.WaitForExit(10000)) {
        $Process.Kill($true)
        [void]$Process.WaitForExit(5000)
    }
}

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$chartFixtureFullPath = Resolve-ExistingFile $ChartFixturePath "Real MC fixture"
$audioFixtureFullPath = Resolve-ExistingFile $AudioFixturePath "Real OGG fixture"
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
if (-not (Test-Path -LiteralPath $outputFullPath -PathType Container)) {
    throw "Output root must already exist: $outputFullPath"
}
$guiRoot = Join-Path $outputFullPath "gui-runtime"
if (Test-Path -LiteralPath $guiRoot) {
    throw "GUI output root already exists: $guiRoot"
}
New-Item -ItemType Directory -Path $guiRoot | Out-Null

$workingRoot = Join-Path $guiRoot "working"
$clientRoot = Join-Path $guiRoot "client"
$localData = Join-Path $clientRoot "local-data"
$editing = Join-Path $clientRoot "editing"
$workspace = Join-Path $clientRoot "workspace"
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$projectTemp = Join-Path $projectRoot ".codex-temp"
foreach ($directory in @(
        $workingRoot,
        $localData,
        $editing,
        $workspace,
        $projectTemp)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$workingChart = Join-Path $workingRoot (Split-Path -Leaf $chartFixtureFullPath)
$workingAudio = Join-Path $workingRoot (Split-Path -Leaf $audioFixtureFullPath)
Copy-Item -LiteralPath $chartFixtureFullPath -Destination $workingChart
Copy-Item -LiteralPath $audioFixtureFullPath -Destination $workingAudio
$fixtureHashesBefore = [ordered]@{
    chart = (Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash
    audio = (Get-FileHash -LiteralPath $audioFixtureFullPath -Algorithm SHA256).Hash
}
$workingChartHashBefore =
    (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash

$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = $applicationFullPath
$start.UseShellExecute = $false
$start.WorkingDirectory = Split-Path -Parent $applicationFullPath
$start.ArgumentList.Add("--evidence-chart")
$start.ArgumentList.Add($workingChart)
$start.Environment["LUMACHART_PROFILE"] =
    "windows-avalonia-bpm-responsiveness-r1"
$start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localData
$start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
$start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
$start.Environment["TEMP"] = $projectTemp
$start.Environment["TMP"] = $projectTemp
$client = [Diagnostics.Process]::Start($start)
if (-not $client) {
    throw "Unable to start Windows Avalonia BPM responsiveness client."
}

try {
    Wait-Condition -Description "main window" -Condition {
        $client.Refresh()
        -not $client.HasExited -and
            $client.MainWindowHandle -ne [IntPtr]::Zero
    }
    $mainHandle = $client.MainWindowHandle
    [void][LumaChartBpmResponsivenessGuiNative]::ShowWindow($mainHandle, 3)
    Select-Element (Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "Inspector.MetadataTab" `
        -TimeoutMilliseconds 30000)
    Start-Sleep -Milliseconds 400

    $analysisButton = Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "Metadata.AnalyzeSingleTempo"
    $startTimer = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Element $analysisButton
    $script:activeCancelButton = $null
    Wait-Condition -Description "responsive enabled BPM cancel action" -Seconds 15 -Condition {
        $candidate = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "Metadata.AnalyzeSingleTempo" `
            -TimeoutMilliseconds 1000
        if ($candidate.Current.IsEnabled -and
            [string]$candidate.Current.Name -ceq "取消 BPM 分析") {
            $script:activeCancelButton = $candidate
            return $true
        }
        return $false
    }
    $cancelActionVisibleMilliseconds = $startTimer.ElapsedMilliseconds
    $activeScreenshotPath = Join-Path $guiRoot "bpm-analysis-cancel-action.png"
    $activeCapture = Capture-Window $mainHandle $activeScreenshotPath

    $cancelTimer = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Element $script:activeCancelButton
    $script:activeCancelButton = $null
    $script:canceledStatus = $null
    Wait-Condition -Description "BPM cancellation completion" -Seconds 30 -Condition {
        $status = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "Metadata.AudioAnalysisStatus" `
            -TimeoutMilliseconds 1000
        if ([string]$status.Current.Name -like "*BPM 分析已取消*") {
            $script:canceledStatus = $status
            return $true
        }
        return $false
    }
    $cancelCompletedMilliseconds = $cancelTimer.ElapsedMilliseconds

    Wait-Condition -Description "BPM action reset" -Seconds 30 -Condition {
        $candidate = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "Metadata.AnalyzeSingleTempo" `
            -TimeoutMilliseconds 1000
        $candidate.Current.IsEnabled -and
            [string]$candidate.Current.Name -ceq "检测 BPM 与 Offset"
    }

    $completionTimer = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Element (Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "Metadata.AnalyzeSingleTempo")
    $resultDialog = Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "Tempo.SingleResultDialog" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $analysisCompletedMilliseconds = $completionTimer.ElapsedMilliseconds
    $resultText = [string](Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "Tempo.SingleResult").Current.Name
    $resultHandle = [IntPtr]$resultDialog.Current.NativeWindowHandle
    $resultScreenshotPath = Join-Path $guiRoot "bpm-analysis-result.png"
    $resultCapture = Capture-Window $resultHandle $resultScreenshotPath
    Invoke-Element (Find-ElementById `
        -ProcessId $client.Id `
        -AutomationId "Tempo.SingleCancel")

    if ((Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash -cne
            $fixtureHashesBefore.chart -or
        (Get-FileHash -LiteralPath $audioFixtureFullPath -Algorithm SHA256).Hash -cne
            $fixtureHashesBefore.audio) {
        throw "A real BPM fixture changed during focused GUI verification."
    }
    if ((Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash -cne
            $workingChartHashBefore) {
        throw "Cancel-only BPM GUI verification changed the isolated chart."
    }

    $screenshots = [ordered]@{}
    foreach ($path in @($activeScreenshotPath, $resultScreenshotPath)) {
        $item = Get-Item -LiteralPath $path
        $screenshots[$item.BaseName] = [ordered]@{
            path = $item.FullName
            length = $item.Length
            sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        }
    }
    $evidence = [ordered]@{
        schema =
            "lumachart.windows.avalonia.bpm-responsiveness-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("o")
        status = "passed-migration-incomplete"
        windowsAvaloniaOnly = $true
        foregroundAutomationConsent = $true
        foregroundAutomationIdleMilliseconds =
            $script:WindowsAvaloniaForegroundAutomationIdleMilliseconds
        reservedDesktopConsentUsed =
            $script:WindowsAvaloniaForegroundAutomationReservedDesktopConsentUsed
        activeCancelAction = [ordered]@{
            name = "取消 BPM 分析"
            enabled = $true
            visibleWithinMilliseconds = $cancelActionVisibleMilliseconds
            screenshot = $activeCapture
        }
        cancellation = [ordered]@{
            completedWithinMilliseconds = $cancelCompletedMilliseconds
            status = [string]$script:canceledStatus.Current.Name
            chartUnchanged = $true
        }
        restartedAnalysis = [ordered]@{
            completedWithinMilliseconds = $analysisCompletedMilliseconds
            result = $resultText
            dialogScreenshot = $resultCapture
            resultCanceledWithoutApply = $true
        }
        fixtures = [ordered]@{
            chart = [ordered]@{
                path = $chartFixtureFullPath
                sha256 = $fixtureHashesBefore.chart
                unchanged = $true
            }
            audio = [ordered]@{
                path = $audioFixtureFullPath
                sha256 = $fixtureHashesBefore.audio
                unchanged = $true
            }
        }
        screenshots = $screenshots
        completion = $false
        migrationComplete = $false
        windowsAvaloniaCanReplaceWpf = $false
        userManualReplacementApprovalReceived = $false
        nextPlatformAuthorized = $false
    }
    $evidencePath = Join-Path $outputFullPath "bpm-responsiveness-gui-evidence.json"
    $evidence | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath $evidencePath -Encoding UTF8
    $evidence
}
finally {
    Stop-TrackedClient $client
}
