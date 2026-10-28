param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ProbeAssemblyPath = (Join-Path $PSScriptRoot "WindowsAudioLoopbackProbe\bin\Release\net8.0-windows\WindowsAudioLoopbackProbe.dll"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$AudioFixturePath = "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [switch]$FormalMigrationAuthority,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia Key-sound loopback GUI capture requires PowerShell Core on Windows."
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
    if ($after.bytes -ne $Before.bytes -or $after.sha256 -cne $Before.sha256 -or
        $after.lastWriteUtcTicks -ne $Before.lastWriteUtcTicks) {
        throw "$Label changed during Key-sound loopback verification."
    }
    return $after
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartKeySoundLoopbackNative
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
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr value);
}
'@

# Keep PrintWindow and UI Automation in a per-monitor-aware process at
# Windows 125%/150%+ scaling. UI Automation is used only to locate and
# inspect the button; the actual preview command is triggered by a physical
# Win32 pointer click so the GUI input path is exercised.
[LumaChartKeySoundLoopbackNative]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 180000)][int]$TimeoutMilliseconds = 10000,
        [switch]$Optional
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
    if ($Optional) { return $null }
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Get-ElementState($Element) {
    $bounds = $Element.Current.BoundingRectangle
    return [ordered]@{
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

function Get-DiagnosticInt64([string]$Text, [string]$Name) {
    $match = [regex]::Match($Text, "(?i)(?:^|;\s*)$([regex]::Escape($Name))=(-?\d+)")
    if (-not $match.Success) { throw "Diagnostic '$Name' missing from '$Text'." }
    return [int64]::Parse($match.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
}

function Invoke-ElementPhysical($Element) {
    if (-not $Element.Current.IsEnabled -or $Element.Current.IsOffscreen) {
        throw "Element '$($Element.Current.AutomationId)' is not invokable."
    }
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -lt 2 -or $bounds.Height -lt 2) {
        throw "Element '$($Element.Current.AutomationId)' has invalid physical bounds."
    }
    $clickX = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $clickY = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    if (-not [LumaChartKeySoundLoopbackNative]::SetCursorPos($clickX, $clickY)) {
        throw "SetCursorPos failed for '$($Element.Current.AutomationId)'."
    }
    Start-Sleep -Milliseconds 75
    $occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    [LumaChartKeySoundLoopbackNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 35
    [LumaChartKeySoundLoopbackNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        input = "physical-win32-left-click"
        x = $clickX
        y = $clickY
        occurredUtc = $occurredUtc
    }
}

function Get-WindowBounds([IntPtr]$Handle) {
    $rectangle = [LumaChartKeySoundLoopbackNative+RECT]::new()
    if (-not [LumaChartKeySoundLoopbackNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    return [ordered]@{
        left = $rectangle.Left
        top = $rectangle.Top
        width = $rectangle.Right - $rectangle.Left
        height = $rectangle.Bottom - $rectangle.Top
    }
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $bounds = Get-WindowBounds $Handle
    if ($bounds.width -lt 800 -or $bounds.height -lt 500) {
        throw "Window has invalid capture bounds $($bounds.width)x$($bounds.height)."
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
                if (-not [LumaChartKeySoundLoopbackNative]::PrintWindow($Handle, $dc, 2)) {
                    throw "PrintWindow failed for $Handle."
                }
            }
            finally { $graphics.ReleaseHdc($dc) }
        }
        finally { $graphics.Dispose() }
        $colors = [Collections.Generic.HashSet[int]]::new()
        for ($sampleY = 0; $sampleY -lt 16; $sampleY++) {
            for ($sampleX = 0; $sampleX -lt 16; $sampleX++) {
                $pixel = $bitmap.GetPixel(
                    [Math]::Min($bounds.width - 1, [int](($sampleX + .5) * $bounds.width / 16)),
                    [Math]::Min($bounds.height - 1, [int](($sampleY + .5) * $bounds.height / 16)))
                [void]$colors.Add($pixel.ToArgb())
            }
        }
        if ($colors.Count -lt 8) { throw "Screenshot is near-uniform: $($colors.Count) sampled colors." }
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
if (Test-Path -LiteralPath $output) { throw "Output root already exists: $output" }
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
$workingChart = Join-Path $workingRoot "key-sound-loopback-resound.mc"
$workingAudio = Join-Path $workingRoot $referencedAudio
Copy-Item -LiteralPath $chartFixture -Destination $workingChart
Copy-Item -LiteralPath $audioFixture -Destination $workingAudio
$fixtureChartBefore = Get-FileFingerprint $chartFixture
$fixtureAudioBefore = Get-FileFingerprint $audioFixture
$workingChartBefore = Get-FileFingerprint $workingChart
$workingAudioBefore = Get-FileFingerprint $workingAudio
$installerBefore = Get-FileFingerprint (Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")

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

$runtimePath = Join-Path $output "runtime-evidence.json"
$probeReadyPath = Join-Path $output "loopback-ready.json"
$probeOutputPath = Join-Path $output "loopback-probe.json"
$probeWavePath = Join-Path $output "key-sound-loopback.wav"
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
            "--evidence-focus-key-sound",
            "--evidence-output", $runtimePath)) {
        $start.ArgumentList.Add($argument)
    }
    $start.Environment["LUMACHART_PROFILE"] = "windows-avalonia-key-sound-loopback"
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceRoot
    $start.Environment["DOTNET_CLI_HOME"] = $dotnetHome
    $start.Environment["NUGET_PACKAGES"] = $nugetPackages
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
    $start.Environment["TEMP"] = $projectTemp
    $start.Environment["TMP"] = $projectTemp
    $process = [Diagnostics.Process]::Start($start)
    if (-not $process) { throw "Failed to start Windows Avalonia client." }

    Wait-Condition -Description "Avalonia main window" -Condition {
        $process.Refresh()
        -not $process.HasExited -and $process.MainWindowHandle -ne [IntPtr]::Zero
    }
    $handle = $process.MainWindowHandle
    [void][LumaChartKeySoundLoopbackNative]::ShowWindow($handle, 3)
    [void][LumaChartKeySoundLoopbackNative]::SetForegroundWindow($handle)
    Wait-Condition -Description "visible Key-sound preview button" -Seconds 45 -Condition {
        $candidate = Find-ElementById -ProcessId $process.Id -AutomationId "KeySound.Preview" -TimeoutMilliseconds 300 -Optional
        $candidate -and -not $candidate.Current.IsOffscreen -and $candidate.Current.IsEnabled
    }
    Wait-Condition -Description "Key-sound runtime status" -Condition {
        $null -ne (Find-ElementById -ProcessId $process.Id -AutomationId "KeySound.RuntimeStatus" -TimeoutMilliseconds 300 -Optional)
    }
    Wait-Condition -Description "runtime evidence" -Condition { Test-Path -LiteralPath $runtimePath -PathType Leaf }
    Start-Sleep -Milliseconds 400
    $preview = Find-ElementById -ProcessId $process.Id -AutomationId "KeySound.Preview"
    $runtimeStatus = Find-ElementById -ProcessId $process.Id -AutomationId "KeySound.RuntimeStatus"
    $initialPreviewState = Get-ElementState $preview
    $initialRuntimeState = Get-ElementState $runtimeStatus
    $initialAccepted = Get-DiagnosticInt64 $initialRuntimeState.helpText "PreviewAccepted"
    $initialRejected = Get-DiagnosticInt64 $initialRuntimeState.helpText "PreviewRejected"
    $beforeCapture = Capture-Window $handle (Join-Path $output "key-sound-before-loopback.png")

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
            "--duration-ms", "5200",
            "--process-id", ([string]$process.Id))) {
        $probeStart.ArgumentList.Add($argument)
    }
    $probeStart.Environment["DOTNET_CLI_HOME"] = $dotnetHome
    $probeStart.Environment["NUGET_PACKAGES"] = $nugetPackages
    $probeStart.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
    $probeStart.Environment["TEMP"] = $projectTemp
    $probeStart.Environment["TMP"] = $projectTemp
    $probe = [Diagnostics.Process]::Start($probeStart)
    if (-not $probe) { throw "Failed to start Windows loopback probe." }
    Wait-Condition -Description "loopback probe ready" -Seconds 20 -Condition {
        Test-Path -LiteralPath $probeReadyPath -PathType Leaf
    }
    $probeReady = Get-Content -LiteralPath $probeReadyPath -Raw |
        ConvertFrom-Json -DateKind String
    Start-Sleep -Milliseconds 450

    $actions = @()
    for ($index = 1; $index -le 3; $index++) {
        [void][LumaChartKeySoundLoopbackNative]::SetForegroundWindow($handle)
        $action = Invoke-ElementPhysical $preview
        Wait-Condition -Description "Key-sound preview acceptance $index" -Seconds 15 -Condition {
            $state = Get-ElementState (Find-ElementById -ProcessId $process.Id -AutomationId "KeySound.RuntimeStatus" -TimeoutMilliseconds 500)
            (Get-DiagnosticInt64 $state.helpText "PreviewAccepted") -ge $initialAccepted + $index
        }
        $acceptedState = Get-ElementState (Find-ElementById -ProcessId $process.Id -AutomationId "KeySound.RuntimeStatus")
        $action["acceptedUtc"] = [DateTimeOffset]::UtcNow.ToString("O")
        $action["previewAccepted"] = Get-DiagnosticInt64 $acceptedState.helpText "PreviewAccepted"
        $action["previewRejected"] = Get-DiagnosticInt64 $acceptedState.helpText "PreviewRejected"
        $actions += $action
        [ordered]@{
            schema = "lumachart.windows.avalonia.key-sound-loopback-interaction-progress.v1"
            captureStartedUtc = [string]$probeReady.startedUtc
            actions = $actions
            latestRuntime = $acceptedState
        } | ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath $interactionProgressPath -Encoding utf8NoBOM
        Start-Sleep -Milliseconds 650
    }

    if (-not $probe.WaitForExit(15000)) { throw "Loopback probe did not exit after its capture window." }
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
    $finalRuntimeState = Get-ElementState (Find-ElementById -ProcessId $process.Id -AutomationId "KeySound.RuntimeStatus")
    $finalAccepted = Get-DiagnosticInt64 $finalRuntimeState.helpText "PreviewAccepted"
    $finalRejected = Get-DiagnosticInt64 $finalRuntimeState.helpText "PreviewRejected"
    if ($finalAccepted -ne $initialAccepted + 3 -or $finalRejected -ne $initialRejected) {
        throw "Preview counters did not prove exactly three accepted and zero rejected invokes."
    }
    if ($probeEvidence.status -cne "captured" -or $probeEvidence.capture.bytes -le 0 -or
        -not [bool]$probeEvidence.capture.timelineIncludesInsertedSilence) {
        throw "WASAPI loopback did not capture a real render stream."
    }
    if ($probeEvidence.analysis.detectedPulseCount -lt 3 -or
        $probeEvidence.analysis.peak -lt .005 -or
        $probeEvidence.analysis.signalToNoiseDb -lt 20 -or
        $probeEvidence.analysis.bestSnareReferenceCorrelation -lt .12) {
        throw "Loopback waveform did not prove three audible Snare pulses: $($probeEvidence.analysis | ConvertTo-Json -Compress -Depth 8)"
    }

    $captureStart = [DateTimeOffset]::Parse([string]$probeReady.startedUtc)
    $pulses = @($probeEvidence.analysis.pulses | Sort-Object startMilliseconds)
    $alignment = @()
    for ($index = 0; $index -lt 3; $index++) {
        $actionTime = [DateTimeOffset]::Parse([string]$actions[$index].occurredUtc)
        $actionFromCaptureStart = ($actionTime - $captureStart).TotalMilliseconds
        $delta = [double]$pulses[$index].startMilliseconds - $actionFromCaptureStart
        if ($delta -lt -120 -or $delta -gt 500) {
            throw "Loopback pulse $index was not time-aligned with its preview InvokePattern action: $delta ms."
        }
        $alignment += [ordered]@{
            index = $index + 1
            actionFromCaptureStartMilliseconds = $actionFromCaptureStart
            pulseStartMilliseconds = [double]$pulses[$index].startMilliseconds
            pulsePeakMilliseconds = [double]$pulses[$index].peakMilliseconds
            startDeltaMilliseconds = $delta
        }
    }
    $afterCapture = Capture-Window $handle (Join-Path $output "key-sound-after-loopback.png")

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
    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.key-sound-loopback-gui-evidence.v1"
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
        physicalMouseInputUsed = $true
        uiAutomationInvokeUsed = $false
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
            initialPreview = $initialPreviewState
            initialRuntime = $initialRuntimeState
            finalRuntime = $finalRuntimeState
            beforeCapture = $beforeCapture
            afterCapture = $afterCapture
            exactlyThreePreviewAccepts = $true
            previewRejectCountUnchanged = $true
        }
        actions = $actions
        loopback = [ordered]@{
            ready = $probeReady
            probe = $probeEvidence
            alignment = $alignment
            capturedRenderMix = $true
            capturedPhysicalTransducer = $false
        }
        screenshots = $screenshots
    }
    $evidencePath = Join-Path $output "evidence.json"
    $evidence | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Write-Host "Windows Avalonia Key-sound WASAPI loopback GUI capture: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    Stop-TrackedProcess $probe
    Stop-TrackedProcess $process
}
