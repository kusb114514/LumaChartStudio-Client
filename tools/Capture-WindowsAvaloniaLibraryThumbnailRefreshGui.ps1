param(
    [string]$ApplicationPath = (
        Join-Path $PSScriptRoot `
            "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$CoverFixturePath = "D:\osu!\Songs\Resound\0\Resound - Nhato.jpg",
    [string]$ChartDestinationFileName = "chart.mc",
    [string]$CoverDestinationFileName = "Resound - Nhato.jpg",
    [string]$ExpectedDisplayTitle = "Resound",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 120)][int]$TimeoutSeconds = 60,
    [switch]$AllowForegroundAutomation
)

$ErrorActionPreference = "Stop"
if (-not $AllowForegroundAutomation) {
    throw "Pass -AllowForegroundAutomation only after the user gives current-turn desktop consent."
}
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia library thumbnail GUI capture requires PowerShell Core on Windows."
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartLibraryThumbnailNative
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
    public struct POINT
    {
        public int X;
        public int Y;
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool ScreenToClient(IntPtr window, ref POINT point);

    [DllImport("user32.dll")]
    public static extern IntPtr WindowFromPoint(POINT point);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(
        IntPtr window,
        uint message,
        IntPtr wParam,
        IntPtr lParam);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    private static extern IntPtr GetWindowLongPtr64(IntPtr window, int index);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
    private static extern int GetWindowLong32(IntPtr window, int index);

    public static bool IsTopmost(IntPtr window)
    {
        const int GWL_EXSTYLE = -20;
        const long WS_EX_TOPMOST = 0x00000008L;
        var value = IntPtr.Size == 8
            ? GetWindowLongPtr64(window, GWL_EXSTYLE).ToInt64()
            : GetWindowLong32(window, GWL_EXSTYLE);
        return (value & WS_EX_TOPMOST) != 0;
    }
}
'@

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Resolve-ExistingFile([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "$Label not found: $full"
    return $full
}

function Resolve-NewDirectory([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Output already exists: $full" }
    [IO.Directory]::CreateDirectory($full) | Out-Null
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

function Get-Fingerprint([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        bytes = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        lastWriteUtcTicks = [long]$item.LastWriteTimeUtc.Ticks
    }
}

function Find-VisibleElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 120000)][int]$TimeoutMilliseconds = 10000,
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
                $matches = $root.FindAll(
                    [Windows.Automation.TreeScope]::Descendants,
                    $idCondition)
                foreach ($match in $matches) {
                    $bounds = $match.Current.BoundingRectangle
                    if (-not $match.Current.IsOffscreen -and
                        $bounds.Width -gt 0 -and
                        $bounds.Height -gt 0) {
                        return $match
                    }
                }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    if ($Optional) { return $null }
    throw "Timed out finding visible UI Automation id '$AutomationId' for process $ProcessId."
}

function Observe-Element(
    [Windows.Automation.AutomationElement]$Element) {
    $bounds = $Element.Current.BoundingRectangle
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        helpText = [string]$Element.Current.HelpText
        controlType = [string]$Element.Current.ControlType.ProgrammaticName
        isEnabled = [bool]$Element.Current.IsEnabled
        isOffscreen = [bool]$Element.Current.IsOffscreen
        bounds = [ordered]@{
            left = [double]$bounds.Left
            top = [double]$bounds.Top
            width = [double]$bounds.Width
            height = [double]$bounds.Height
        }
    }
}

function Invoke-Element {
    param(
        [Parameter(Mandatory = $true)]
        [Windows.Automation.AutomationElement]$Element,
        [Parameter(Mandatory = $true)][IntPtr]$WindowHandle
    )
    Assert (-not $Element.Current.IsOffscreen) (
        "Element '$($Element.Current.AutomationId)' is offscreen.")
    Assert ([bool]$Element.Current.IsEnabled) (
        "Element '$($Element.Current.AutomationId)' is disabled.")
    $bounds = $Element.Current.BoundingRectangle
    $inputKind = $null
    try {
        $pattern = $Element.GetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern)
        if ($null -eq $pattern) {
            throw "InvokePattern provider returned null."
        }
        $pattern.Invoke()
        $inputKind = "UI Automation InvokePattern"
    }
    catch {
        $screenPoint =
            [LumaChartLibraryThumbnailNative+POINT]::new()
        $screenPoint.X =
            [int][Math]::Round($bounds.Left + $bounds.Width / 2)
        $screenPoint.Y =
            [int][Math]::Round($bounds.Top + $bounds.Height / 2)
        $targetWindow =
            [LumaChartLibraryThumbnailNative]::WindowFromPoint(
                $screenPoint)
        Assert ($targetWindow -ne [IntPtr]::Zero) (
            "WindowFromPoint failed for '$($Element.Current.AutomationId)'.")
        $clientPoint = $screenPoint
        Assert (
            [LumaChartLibraryThumbnailNative]::ScreenToClient(
                $targetWindow,
                [ref]$clientPoint)) (
            "ScreenToClient failed for '$($Element.Current.AutomationId)'.")
        $packed = (($clientPoint.Y -band 0xffff) -shl 16) -bor
            ($clientPoint.X -band 0xffff)
        Assert (
            [LumaChartLibraryThumbnailNative]::PostMessage(
                $targetWindow,
                0x0201,
                [IntPtr]1,
                [IntPtr]$packed)) (
            "WM_LBUTTONDOWN failed for '$($Element.Current.AutomationId)'.")
        Start-Sleep -Milliseconds 45
        Assert (
            [LumaChartLibraryThumbnailNative]::PostMessage(
                $targetWindow,
                0x0202,
                [IntPtr]::Zero,
                [IntPtr]$packed)) (
            "WM_LBUTTONUP failed for '$($Element.Current.AutomationId)'.")
        $inputKind =
            "Win32 WM_LBUTTONDOWN/UP posted to live UIA element HWND"
    }
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
        y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
        input = $inputKind
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Capture-PhysicalWindow([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartLibraryThumbnailNative+RECT]::new()
    Assert (
        [LumaChartLibraryThumbnailNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) "GetWindowRect failed."
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    Assert ($width -ge 800 -and $height -ge 500) (
        "Invalid window bounds ${width}x${height}.")
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
                [Drawing.Size]::new($width, $height),
                [Drawing.CopyPixelOperation]::SourceCopy)
        }
        finally { $graphics.Dispose() }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            path = [IO.Path]::GetFullPath($Path)
            bytes = [long](Get-Item -LiteralPath $Path).Length
            width = $width
            height = $height
            sha256 =
                (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
            captureKind = "physical desktop window"
        }
    }
    finally { $bitmap.Dispose() }
}

function Close-WindowWithUia([int]$ProcessId) {
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $window = [Windows.Automation.AutomationElement]::RootElement.FindFirst(
        [Windows.Automation.TreeScope]::Children,
        $processCondition)
    Assert ($null -ne $window) "Application UI Automation root was not found."
    $pattern = $null
    Assert (
        $window.TryGetCurrentPattern(
            [Windows.Automation.WindowPattern]::Pattern,
            [ref]$pattern)) "Application window does not expose WindowPattern."
    ([Windows.Automation.WindowPattern]$pattern).Close()
}

$application = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$chartFixture = Resolve-ExistingFile $ChartFixturePath "real chart fixture"
$coverFixture = Resolve-ExistingFile $CoverFixturePath "real cover fixture"
$chartDestinationLeaf = [IO.Path]::GetFileName($ChartDestinationFileName)
$coverDestinationLeaf = [IO.Path]::GetFileName($CoverDestinationFileName)
Assert (
    $chartDestinationLeaf -ceq $ChartDestinationFileName -and
    @(".mc", ".osu").Contains(
        [IO.Path]::GetExtension($chartDestinationLeaf).ToLowerInvariant())) (
    "ChartDestinationFileName must be a leaf .mc or .osu file name.")
Assert (
    $coverDestinationLeaf -ceq $CoverDestinationFileName -and
    -not [string]::IsNullOrWhiteSpace($coverDestinationLeaf)) (
    "CoverDestinationFileName must be a non-empty leaf file name.")
Assert (-not [string]::IsNullOrWhiteSpace($ExpectedDisplayTitle)) (
    "ExpectedDisplayTitle must not be empty.")
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$output = [IO.Path]::GetFullPath($OutputRoot)
$projectBoundary = $projectRoot.TrimEnd('\') + '\'
Assert (
    $output.StartsWith(
        $projectBoundary,
        [StringComparison]::OrdinalIgnoreCase)) (
    "Output must stay below the project root: $output")
$output = Resolve-NewDirectory $output

$localData = Join-Path $output "local-data"
$editing = Join-Path $output "editing"
$workspace = Join-Path $output "workspace"
$songFolder = Join-Path $workspace "CoverSong"
foreach ($directory in @($localData, $editing, $workspace, $songFolder)) {
    [IO.Directory]::CreateDirectory($directory) | Out-Null
}
$chart = Join-Path $songFolder $chartDestinationLeaf
$cover = Join-Path $songFolder $coverDestinationLeaf
Copy-Item -LiteralPath $chartFixture -Destination $chart
Copy-Item -LiteralPath $coverFixture -Destination $cover

$installer = Resolve-ExistingFile (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe") "frozen installer"
$chartFixtureBefore = Get-Fingerprint $chartFixture
$coverFixtureBefore = Get-Fingerprint $coverFixture
$installerBefore = Get-Fingerprint $installer
$isolatedChartBefore = Get-Fingerprint $chart
$isolatedCoverBefore = Get-Fingerprint $cover
$runtimeEvidencePath = Join-Path $output "runtime-evidence.json"
$evidencePath = Join-Path $output "evidence.json"
$screenshots = [Collections.Generic.List[object]]::new()
$actions = [Collections.Generic.List[object]]::new()
$process = $null
try {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $application
    $start.WorkingDirectory = Split-Path -Parent $application
    $start.UseShellExecute = $false
    foreach ($argument in @(
            "--evidence-chart", $chart,
            "--evidence-focus-library-deletion",
            "--evidence-output", $runtimeEvidencePath,
            "--evidence-interaction-delay-ms", "1200")) {
        $start.ArgumentList.Add($argument)
    }
    $start.Environment["LUMACHART_PROFILE"] =
        "windows-avalonia-library-thumbnail-refresh"
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localData
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
    $start.Environment["DOTNET_CLI_HOME"] =
        Join-Path $projectRoot ".codex-dotnet-home"
    $start.Environment["NUGET_PACKAGES"] =
        Join-Path $projectRoot ".codex-nuget-packages"
    $start.Environment["NUGET_HTTP_CACHE_PATH"] =
        Join-Path $projectRoot ".codex-nuget-http-cache"
    $captureTemp = Join-Path $output "temp"
    [IO.Directory]::CreateDirectory($captureTemp) | Out-Null
    $start.Environment["TEMP"] = $captureTemp
    $start.Environment["TMP"] = $captureTemp
    $process = [Diagnostics.Process]::Start($start)
    Assert ($null -ne $process) "Failed to start Windows Avalonia client."

    Wait-Condition -Description "Avalonia main window" -Condition {
        $process.Refresh()
        -not $process.HasExited -and
            $process.MainWindowHandle -ne [IntPtr]::Zero
    }
    $handle = $process.MainWindowHandle
    [void][LumaChartLibraryThumbnailNative]::ShowWindow($handle, 3)
    [void][LumaChartLibraryThumbnailNative]::SetForegroundWindow($handle)
    Wait-Condition -Description "runtime evidence" -Condition {
        Test-Path -LiteralPath $runtimeEvidencePath -PathType Leaf
    }
    $topmostAtStart =
        [LumaChartLibraryThumbnailNative]::IsTopmost($handle)

    $firstImage = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.FolderThumbnailImage"
    $firstPlaceholder = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.FolderThumbnailPlaceholder" `
        -TimeoutMilliseconds 600 `
        -Optional
    $firstImageObservation = Observe-Element $firstImage
    Assert ($null -eq $firstPlaceholder) (
        "Placeholder stayed visible while the real cover was visible.")
    Assert (
        [string]$firstImageObservation.name -ceq
            "封面 · $ExpectedDisplayTitle") (
        "Initial real-cover automation name drifted.")
    [void]$screenshots.Add((Capture-PhysicalWindow `
        $handle `
        (Join-Path $output "cover-valid.png")))

    [IO.File]::WriteAllBytes(
        $cover,
        [byte[]](0x4C, 0x55, 0x4D, 0x41, 0x2D, 0x42, 0x41, 0x44))
    [IO.File]::SetLastWriteTimeUtc(
        $cover,
        [DateTime]::UtcNow.AddMinutes(1))
    $corruptCover = Get-Fingerprint $cover
    $refresh = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.Refresh"
    [void]$actions.Add((Invoke-Element `
        -Element $refresh `
        -WindowHandle $handle))
    $fallback = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.FolderThumbnailPlaceholder"
    $visibleImageDuringFallback = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.FolderThumbnailImage" `
        -TimeoutMilliseconds 600 `
        -Optional
    $fallbackObservation = Observe-Element $fallback
    Assert ($null -eq $visibleImageDuringFallback) (
        "Real-cover Image stayed visible after the source became corrupt.")
    Assert (
        [string]$fallbackObservation.name -ceq "无封面占位图") (
        "Corrupt-cover placeholder automation name drifted.")
    [void]$screenshots.Add((Capture-PhysicalWindow `
        $handle `
        (Join-Path $output "cover-corrupt-fallback.png")))

    Copy-Item -LiteralPath $coverFixture -Destination $cover -Force
    [IO.File]::SetLastWriteTimeUtc(
        $cover,
        [DateTime]::UtcNow.AddMinutes(2))
    $restoredCover = Get-Fingerprint $cover
    $refresh = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.Refresh"
    [void]$actions.Add((Invoke-Element `
        -Element $refresh `
        -WindowHandle $handle))
    $restoredImage = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.FolderThumbnailImage"
    $restoredPlaceholder = Find-VisibleElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.FolderThumbnailPlaceholder" `
        -TimeoutMilliseconds 600 `
        -Optional
    $restoredObservation = Observe-Element $restoredImage
    Assert ($null -eq $restoredPlaceholder) (
        "Placeholder stayed visible after the real cover was restored.")
    Assert (
        [string]$restoredObservation.name -ceq
            "封面 · $ExpectedDisplayTitle") (
        "Restored real-cover automation name drifted.")
    [void]$screenshots.Add((Capture-PhysicalWindow `
        $handle `
        (Join-Path $output "cover-restored.png")))

    $topmostBeforeClose =
        [LumaChartLibraryThumbnailNative]::IsTopmost($handle)
    Close-WindowWithUia -ProcessId $process.Id
    Assert ($process.WaitForExit(10000)) (
        "Avalonia client did not exit after UIA WindowPattern.Close.")
    $processExitCode = $process.ExitCode
    Assert ($processExitCode -eq 0) (
        "Avalonia client exited with code $processExitCode.")

    $chartFixtureAfter = Get-Fingerprint $chartFixture
    $coverFixtureAfter = Get-Fingerprint $coverFixture
    $installerAfter = Get-Fingerprint $installer
    $isolatedChartAfter = Get-Fingerprint $chart
    $isolatedCoverAfter = Get-Fingerprint $cover
    Assert (
        $chartFixtureAfter.sha256 -ceq $chartFixtureBefore.sha256 -and
        $coverFixtureAfter.sha256 -ceq $coverFixtureBefore.sha256 -and
        $installerAfter.sha256 -ceq $installerBefore.sha256) (
        "A frozen source fixture or installer changed.")
    Assert (
        $isolatedChartAfter.sha256 -ceq $isolatedChartBefore.sha256 -and
        $isolatedCoverAfter.sha256 -ceq $isolatedCoverBefore.sha256) (
        "The isolated chart or restored cover did not return to its source hash.")
    Assert (
        $corruptCover.sha256 -cne $isolatedCoverBefore.sha256 -and
        $restoredCover.sha256 -ceq $isolatedCoverBefore.sha256) (
        "The corrupt/restore cover fingerprint chain drifted.")
    Assert (-not $topmostAtStart -and -not $topmostBeforeClose) (
        "Persistent topmost was observed.")

    $evidence = [ordered]@{
        schema =
            "lumachart.windows.avalonia.library-thumbnail-refresh-gui.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        platform = "Windows Avalonia only"
        process = [ordered]@{
            id = $process.Id
            exitCode = $processExitCode
            applicationPath = $application
            topmostAtStart = $topmostAtStart
            topmostBeforeClose = $topmostBeforeClose
        }
        inputs = [ordered]@{
            currentTurnDesktopConsent = $true
            minimumIdleMilliseconds = 3000
            initialIdleMilliseconds =
                $script:WindowsAvaloniaForegroundAutomationIdleMilliseconds
            uiaInvokeUsed =
                @($actions | Where-Object {
                    $_.input -ceq "UI Automation InvokePattern"
                }).Count -gt 0
            postedTargetPointerMessagesUsed =
                @($actions | Where-Object {
                    $_.input -clike "Win32 WM_LBUTTONDOWN/UP*"
                }).Count -gt 0
            uiaWindowCloseUsed = $true
            win32MouseInputInjectionUsed = $false
            win32KeyboardInputInjectionUsed = $false
            hardwareMouseInputClaimed = $false
            hardwareKeyboardInputClaimed = $false
            enterKeySent = $false
            persistentTopmostUsed = $false
            actions = @($actions)
        }
        thumbnail = [ordered]@{
            coverPath = $cover
            initial = $firstImageObservation
            corruptFallback = $fallbackObservation
            restored = $restoredObservation
            validToCorruptToValid = $true
            refreshInvokeCount = $actions.Count
            sourceFingerprint = $coverFixtureBefore
            isolatedInitialFingerprint = $isolatedCoverBefore
            corruptFingerprint = $corruptCover
            restoredFingerprint = $restoredCover
            isolatedFinalFingerprint = $isolatedCoverAfter
        }
        screenshots = @($screenshots)
        immutable = [ordered]@{
            realMcBefore = $chartFixtureBefore
            realMcAfter = $chartFixtureAfter
            realCoverBefore = $coverFixtureBefore
            realCoverAfter = $coverFixtureAfter
            frozenInstallerBefore = $installerBefore
            frozenInstallerAfter = $installerAfter
            isolatedChartBefore = $isolatedChartBefore
            isolatedChartAfter = $isolatedChartAfter
        }
        boundaries = [ordered]@{
            productionServerDeployed = $false
            mobileProjectsTouched = $false
            protectionOrAotUsed = $false
            releaseInstallerOverwritten = $false
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
        }
    }
    $evidence | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    $evidence | ConvertTo-Json -Depth 12
}
finally {
    if ($process -and -not $process.HasExited) {
        try { Close-WindowWithUia -ProcessId $process.Id } catch { }
        if (-not $process.WaitForExit(3000)) {
            throw "Avalonia test client stayed open after the directed UIA close."
        }
    }
    if ($process) { $process.Dispose() }
}
