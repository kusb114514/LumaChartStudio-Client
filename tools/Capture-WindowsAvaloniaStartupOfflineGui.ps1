param(
    [Parameter(Mandatory = $true)][string]$ApplicationPath,
    [Parameter(Mandatory = $true)][string]$StartupScreenshotPath,
    [Parameter(Mandatory = $true)][string]$OfflineScreenshotPath,
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
    [Parameter(Mandatory = $true)][string]$LocalDataRoot,
    [Parameter(Mandatory = $true)][string]$EditingRoot,
    [ValidateRange(10, 90)][int]$TimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia startup/offline GUI capture requires PowerShell Core on Windows."
}

function Resolve-NewOutput([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Output already exists: $full" }
    New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($full)) | Out-Null
    return $full
}

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 90000)][int]$TimeoutMilliseconds
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children,
                $processCondition)
            foreach ($root in $roots) {
                if ([string]::Equals(
                        [string]$root.Current.AutomationId,
                        $AutomationId,
                        [StringComparison]::Ordinal)) { return $root }
                $candidate = $root.FindFirst(
                    [Windows.Automation.TreeScope]::Descendants,
                    $idCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Try-FindElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId
    )
    try {
        return Find-ElementById `
            -ProcessId $ProcessId `
            -AutomationId $AutomationId `
            -TimeoutMilliseconds 300
    }
    catch { return $null }
}

function Observe-Element($Element) {
    $bounds = $Element.Current.BoundingRectangle
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        controlType = [string]$Element.Current.ControlType.ProgrammaticName
        isEnabled = [bool]$Element.Current.IsEnabled
        isOffscreen = [bool]$Element.Current.IsOffscreen
        nativeWindowHandle = [long]$Element.Current.NativeWindowHandle
        bounds = [ordered]@{
            left = [double]$bounds.Left
            top = [double]$bounds.Top
            width = [double]$bounds.Width
            height = [double]$bounds.Height
        }
    }
}

function Click-ElementPhysical($Element, [IntPtr]$WindowHandle) {
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -le 1 -or $bounds.Height -le 1 -or
        $Element.Current.IsOffscreen -or -not $Element.Current.IsEnabled) {
        throw "Element '$($Element.Current.AutomationId)' has no physical click target."
    }
    [void][LumaChartStartupOfflineNative]::SetForegroundWindow($WindowHandle)
    Start-Sleep -Milliseconds 120
    $x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    if (-not [LumaChartStartupOfflineNative]::SetCursorPos($x, $y)) {
        throw "SetCursorPos failed for '$($Element.Current.AutomationId)'."
    }
    [LumaChartStartupOfflineNative]::mouse_event(
        0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 45
    [LumaChartStartupOfflineNative]::mouse_event(
        0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 220
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        x = $x
        y = $y
        utc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartStartupOfflineNative+RECT]::new()
    if (-not [LumaChartStartupOfflineNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 800 -or $height -lt 500) {
        throw "Avalonia main window has invalid bounds: ${width}x${height}."
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
                if (-not [LumaChartStartupOfflineNative]::PrintWindow(
                        $Handle,
                        $deviceContext,
                        2)) {
                    throw "PrintWindow failed for the Avalonia main window."
                }
            }
            finally { $graphics.ReleaseHdc($deviceContext) }
        }
        finally { $graphics.Dispose() }

        $colors = [Collections.Generic.HashSet[int]]::new()
        $luminance = [Collections.Generic.List[double]]::new()
        for ($sampleY = 0; $sampleY -lt 16; $sampleY++) {
            $pixelY = [Math]::Min(
                $height - 1,
                [int](($sampleY + .5) * $height / 16))
            for ($sampleX = 0; $sampleX -lt 16; $sampleX++) {
                $pixelX = [Math]::Min(
                    $width - 1,
                    [int](($sampleX + .5) * $width / 16))
                $pixel = $bitmap.GetPixel($pixelX, $pixelY)
                [void]$colors.Add($pixel.ToArgb())
                $luminance.Add(
                    .2126 * $pixel.R +
                    .7152 * $pixel.G +
                    .0722 * $pixel.B)
            }
        }
        $mean = ($luminance | Measure-Object -Average).Average
        $variance = ($luminance | ForEach-Object {
            $difference = $_ - $mean
            $difference * $difference
        } | Measure-Object -Average).Average
        $stdDev = [Math]::Sqrt([double]$variance)
        if ($colors.Count -lt 8 -or $stdDev -lt 1.0) {
            throw "Screenshot is near-uniform: colors=$($colors.Count); stdDev=$stdDev."
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            width = $width
            height = $height
            sampledUniqueColors = $colors.Count
            sampledLuminanceStdDev = $stdDev
        }
    }
    finally { $bitmap.Dispose() }
}

$applicationFullPath = [IO.Path]::GetFullPath($ApplicationPath)
if (-not (Test-Path -LiteralPath $applicationFullPath -PathType Leaf)) {
    throw "Avalonia executable not found: $applicationFullPath"
}
$startupScreenshotFullPath = Resolve-NewOutput $StartupScreenshotPath
$offlineScreenshotFullPath = Resolve-NewOutput $OfflineScreenshotPath
$evidenceFullPath = Resolve-NewOutput $EvidencePath
$workspaceFullPath = [IO.Path]::GetFullPath($WorkspaceRoot)
$localDataFullPath = [IO.Path]::GetFullPath($LocalDataRoot)
$editingFullPath = [IO.Path]::GetFullPath($EditingRoot)
foreach ($directory in @(
        $workspaceFullPath,
        $localDataFullPath,
        $editingFullPath)) {
    if (Test-Path -LiteralPath $directory) {
        if ((Get-ChildItem -LiteralPath $directory -Force | Select-Object -First 1)) {
            throw "Isolated GUI root is not empty: $directory"
        }
    }
    else {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LumaChartStartupOfflineNative
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
    public static extern bool GetWindowRect(
        IntPtr window,
        out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern uint GetDpiForWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(
        IntPtr window,
        IntPtr deviceContext,
        uint flags);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(
        IntPtr window,
        int command);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(
        uint flags,
        uint dx,
        uint dy,
        uint data,
        UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(
        IntPtr window,
        out uint processId);
}
'@

# Keep the controller out of both rendered screenshots.
$foreground = [LumaChartStartupOfflineNative]::GetForegroundWindow()
$controllerMinimized = $false
if ($foreground -ne [IntPtr]::Zero) {
    [uint32]$foregroundProcessId = 0
    [void][LumaChartStartupOfflineNative]::GetWindowThreadProcessId(
        $foreground,
        [ref]$foregroundProcessId)
    try {
        $foregroundProcess = Get-Process `
            -Id $foregroundProcessId `
            -ErrorAction Stop
        if ($foregroundProcess.ProcessName -match "Codex") {
            $controllerMinimized = [LumaChartStartupOfflineNative]::ShowWindowAsync(
                $foreground,
                6)
        }
    }
    catch { }
}

$isolatedEndpoint = "http://127.0.0.1:1/"
$start = [Diagnostics.ProcessStartInfo]::new($applicationFullPath)
$start.UseShellExecute = $false
$start.Environment["LUMACHART_SERVER_URL"] = $isolatedEndpoint
$start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataFullPath
$start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingFullPath
$start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceFullPath
$process = [Diagnostics.Process]::Start($start)
try {
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($process.MainWindowHandle -eq [IntPtr]::Zero -and
           [DateTime]::UtcNow -lt $deadline) {
        if ($process.HasExited) {
            throw "Avalonia exited before opening its main window."
        }
        $process.Refresh()
        Start-Sleep -Milliseconds 100
    }
    if ($process.MainWindowHandle -eq [IntPtr]::Zero) {
        throw "Avalonia main window was unavailable."
    }
    $mainWindowHandle = [IntPtr]$process.MainWindowHandle
    $windowDpi = [double][LumaChartStartupOfflineNative]::GetDpiForWindow(
        $mainWindowHandle)
    $windowScale = $windowDpi / 96.0

    $startupLayer = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Layer" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $dialog = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Dialog" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $offlineButton = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.ContinueOffline" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $accountNavigation = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Navigation" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $loginAvatar = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Login.DefaultAvatar" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $titleAvatar = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Title.DefaultAvatar" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)

    $startupLayerObservation = Observe-Element $startupLayer
    $dialogObservation = Observe-Element $dialog
    $offlineButtonObservation = Observe-Element $offlineButton
    $accountNavigationObservation = Observe-Element $accountNavigation
    $loginAvatarObservation = Observe-Element $loginAvatar
    $titleAvatarObservation = Observe-Element $titleAvatar
    if ($startupLayerObservation.isOffscreen -or
        $dialogObservation.isOffscreen -or
        $offlineButtonObservation.isOffscreen -or
        $loginAvatarObservation.isOffscreen -or
        $titleAvatarObservation.isOffscreen) {
        throw "The automatic startup account surface was not physically visible."
    }
    if ($dialogObservation.nativeWindowHandle -ne 0) {
        throw "Startup account surface unexpectedly opened a separate native window."
    }
    if ([string]$loginAvatarObservation.name -cne "默认用户头像" -or
        [string]$titleAvatarObservation.name -cne "默认用户头像" -or
        [Math]::Abs(
            [double]$loginAvatarObservation.bounds.width -
            (126.0 * $windowScale)) -gt 2.5 -or
        [Math]::Abs(
            [double]$loginAvatarObservation.bounds.height -
            (126.0 * $windowScale)) -gt 2.5 -or
        [Math]::Abs(
            [double]$titleAvatarObservation.bounds.width -
            (24.0 * $windowScale)) -gt 2.5 -or
        [Math]::Abs(
            [double]$titleAvatarObservation.bounds.height -
            (24.0 * $windowScale)) -gt 2.5) {
        throw "Default-avatar physical geometry differs from WPF 126/24 DIP."
    }

    $startupCapture = Capture-Window `
        $mainWindowHandle `
        $startupScreenshotFullPath
    $offlineClick = Click-ElementPhysical $offlineButton $mainWindowHandle

    $librarySearch = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.Search" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $libraryObservation = Observe-Element $librarySearch
    if ($libraryObservation.isOffscreen) {
        throw "Library search remained offscreen after choosing offline mode."
    }

    $hiddenDeadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        $remainingLayer = Try-FindElementById `
            -ProcessId $process.Id `
            -AutomationId "OnlineAccount.Layer"
        if ($null -eq $remainingLayer -or $remainingLayer.Current.IsOffscreen) {
            break
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $hiddenDeadline)
    if ($null -ne $remainingLayer -and -not $remainingLayer.Current.IsOffscreen) {
        throw "Startup account layer remained visible after the physical offline click."
    }

    $offlineCapture = Capture-Window `
        $mainWindowHandle `
        $offlineScreenshotFullPath
    $tokenPath = Join-Path $localDataFullPath "online-session.bin"
    if (Test-Path -LiteralPath $tokenPath) {
        throw "Offline startup unexpectedly created a session token."
    }

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.startup-offline-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        applicationPath = $applicationFullPath
        applicationSha256 = (Get-FileHash `
            -LiteralPath $applicationFullPath `
            -Algorithm SHA256).Hash
        applicationAssemblySha256 = (Get-FileHash `
            -LiteralPath ([IO.Path]::ChangeExtension(
                $applicationFullPath,
                ".dll")) `
            -Algorithm SHA256).Hash
        processId = $process.Id
        mainWindowHandle = [long]$mainWindowHandle
        controllerMinimized = $controllerMinimized
        endpoint = $isolatedEndpoint
        endpointIsLoopback = $true
        productionEndpointContacted = $false
        hostedInMainWindow = $true
        separateNativeWindowCreated = $false
        navigationClickCount = 0
        offlineClickCount = 1
        mouseInputUsed = $true
        keyboardInputUsed = $false
        startup = [ordered]@{
            automaticSurfaceObserved = $true
            layer = $startupLayerObservation
            dialog = $dialogObservation
            offlineButton = $offlineButtonObservation
            accountNavigation = $accountNavigationObservation
            windowDpi = $windowDpi
            windowScale = $windowScale
            loginAvatar = $loginAvatarObservation
            titleAvatar = $titleAvatarObservation
            loginAvatarDipSize = 126
            titleAvatarDipSize = 24
            screenshotPath = $startupScreenshotFullPath
            screenshotSha256 = (Get-FileHash `
                -LiteralPath $startupScreenshotFullPath `
                -Algorithm SHA256).Hash
            screenshot = $startupCapture
        }
        offlineAction = [ordered]@{
            physicalClick = $offlineClick
            layerHidden = $true
            library = $libraryObservation
            sessionTokenExists = $false
            screenshotPath = $offlineScreenshotFullPath
            screenshotSha256 = (Get-FileHash `
                -LiteralPath $offlineScreenshotFullPath `
                -Algorithm SHA256).Hash
            screenshot = $offlineCapture
        }
        isolation = [ordered]@{
            workspaceRoot = $workspaceFullPath
            localDataRoot = $localDataFullPath
            editingRoot = $editingFullPath
            ordinaryReleaseOnly = $true
            ollvmUsed = $false
            obfuscationUsed = $false
            codeVirtualizationUsed = $false
            aotUsed = $false
            mobilePlatformTouched = $false
        }
    }
    $evidence | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath $evidenceFullPath -Encoding utf8NoBOM
    $evidence | ConvertTo-Json -Depth 12
}
finally {
    Start-Sleep -Milliseconds 250
    if (-not $process.HasExited) {
        $process.CloseMainWindow() | Out-Null
        if (-not $process.WaitForExit(5000)) {
            $process.Kill($true)
            $process.WaitForExit(5000) | Out-Null
        }
    }
    $process.Dispose()
}
