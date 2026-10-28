param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 120,
    [switch]$AllowForegroundAutomation
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia close-layer GUI capture requires PowerShell Core on Windows."
}
if (-not $AllowForegroundAutomation) {
    throw (
        "Foreground GUI automation is disabled. Pass " +
        "-AllowForegroundAutomation only after the user explicitly confirms " +
        "that the desktop is available.")
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
        catch { }
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
using System.Threading;

public static class LumaChartCloseLayerGuiNative
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

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    public static extern IntPtr GetWindowLongPtr(IntPtr window, int index);

    [DllImport("user32.dll")]
    public static extern IntPtr GetWindow(IntPtr window, uint command);

    [DllImport("user32.dll")]
    public static extern IntPtr GetLastActivePopup(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool IsWindowEnabled(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool IsZoomed(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(
        uint flags,
        uint x,
        uint y,
        uint data,
        UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(
        byte virtualKey,
        byte scan,
        uint flags,
        UIntPtr extraInfo);

    public static bool ForceNonTopmost(IntPtr window)
    {
        var notTopmost = new IntPtr(-2);
        const uint noMoveNoSizeShow = 0x0001 | 0x0002 | 0x0040;
        return SetWindowPos(window, notTopmost, 0, 0, 0, 0, noMoveNoSizeShow);
    }

    public static bool ActivateNonTopmost(IntPtr window)
    {
        if (window == IntPtr.Zero)
            return false;
        ForceNonTopmost(window);
        ShowWindowAsync(window, 5);
        BringWindowToTop(window);
        SetForegroundWindow(window);
        Thread.Sleep(140);
        ForceNonTopmost(window);
        return GetForegroundWindow() == window;
    }

    public static bool IsTopmostStyleSet(IntPtr window)
    {
        const int extendedStyle = -20;
        const long topmostStyle = 0x00000008;
        return (GetWindowLongPtr(window, extendedStyle).ToInt64() & topmostStyle) != 0;
    }

    public static void Click(int x, int y)
    {
        const uint leftDown = 0x0002;
        const uint leftUp = 0x0004;
        SetCursorPos(x, y);
        Thread.Sleep(90);
        mouse_event(leftDown, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(45);
        mouse_event(leftUp, 0, 0, 0, UIntPtr.Zero);
    }

    public static void PressF11()
    {
        const byte f11 = 0x7A;
        const uint keyUp = 0x0002;
        keybd_event(f11, 0, 0, UIntPtr.Zero);
        Thread.Sleep(50);
        keybd_event(f11, 0, keyUp, UIntPtr.Zero);
    }

    public static void PressAltF4()
    {
        const byte menu = 0x12;
        const byte f4 = 0x73;
        const uint keyUp = 0x0002;
        keybd_event(menu, 0, 0, UIntPtr.Zero);
        Thread.Sleep(35);
        keybd_event(f4, 0, 0, UIntPtr.Zero);
        Thread.Sleep(50);
        keybd_event(f4, 0, keyUp, UIntPtr.Zero);
        keybd_event(menu, 0, keyUp, UIntPtr.Zero);
    }
}
'@

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 180000)][int]$TimeoutMilliseconds = 10000,
        [switch]$Visible
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
                $candidates = [Collections.Generic.List[object]]::new()
                if ([string]$root.Current.AutomationId -ceq $AutomationId) {
                    $candidates.Add($root)
                }
                foreach ($candidate in $root.FindAll(
                        [Windows.Automation.TreeScope]::Descendants,
                        $idCondition)) {
                    $candidates.Add($candidate)
                }
                foreach ($candidate in $candidates) {
                    if (-not $Visible) { return $candidate }
                    $bounds = $candidate.Current.BoundingRectangle
                    if (-not $candidate.Current.IsOffscreen -and
                        [double]::IsFinite($bounds.Left) -and
                        [double]::IsFinite($bounds.Top) -and
                        $bounds.Width -gt 1 -and
                        $bounds.Height -gt 1) {
                        return $candidate
                    }
                }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Test-ElementAbsent {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId
    )
    try {
        [void](Find-ElementById `
            -ProcessId $ProcessId `
            -AutomationId $AutomationId `
            -TimeoutMilliseconds 200)
        return $false
    }
    catch {
        return $true
    }
}

function Get-WindowBounds([IntPtr]$Handle) {
    $rectangle = [LumaChartCloseLayerGuiNative+RECT]::new()
    if (-not [LumaChartCloseLayerGuiNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) {
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

function Set-ForegroundWindowVerified([IntPtr]$Handle) {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(4)
    do {
        if ([LumaChartCloseLayerGuiNative]::GetForegroundWindow() -eq $Handle) {
            return
        }
        [void][LumaChartCloseLayerGuiNative]::ActivateNonTopmost($Handle)
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Unable to activate non-topmost evidence window $Handle."
}

function Invoke-PhysicalElementClick(
    [Windows.Automation.AutomationElement]$Element,
    [IntPtr]$RootHandle,
    [string]$Label) {
    $bounds = $Element.Current.BoundingRectangle
    if ($Element.Current.IsOffscreen -or
        -not [double]::IsFinite($bounds.Left) -or
        -not [double]::IsFinite($bounds.Top) -or
        $bounds.Width -le 1 -or
        $bounds.Height -le 1) {
        throw "$Label is not physically clickable."
    }
    Set-ForegroundWindowVerified $RootHandle
    $x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    [LumaChartCloseLayerGuiNative]::Click($x, $y)
    return [ordered]@{ x = $x; y = $y }
}

function Set-ElementValue(
    [Windows.Automation.AutomationElement]$Element,
    [string]$Value) {
    $patternObject = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$patternObject)) {
        throw (
            "Element '$($Element.Current.AutomationId)' does not expose " +
            "ValuePattern.")
    }
    $pattern = [Windows.Automation.ValuePattern]$patternObject
    $pattern.SetValue($Value)
}

function Capture-ScreenWindow([IntPtr]$Handle, [string]$Path) {
    $bounds = Get-WindowBounds $Handle
    if ($bounds.width -lt 900 -or $bounds.height -lt 600) {
        throw "Window has invalid close-layer capture bounds."
    }
    $bitmap = [Drawing.Bitmap]::new(
        $bounds.width,
        $bounds.height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen(
                $bounds.left,
                $bounds.top,
                0,
                0,
                [Drawing.Size]::new($bounds.width, $bounds.height))
        }
        finally {
            $graphics.Dispose()
        }
        $colors = [Collections.Generic.HashSet[int]]::new()
        for ($y = 0; $y -lt 16; $y++) {
            for ($x = 0; $x -lt 16; $x++) {
                $sampleX = [Math]::Min(
                    $bounds.width - 1,
                    [int](($x + .5) * $bounds.width / 16))
                $sampleY = [Math]::Min(
                    $bounds.height - 1,
                    [int](($y + .5) * $bounds.height / 16))
                [void]$colors.Add($bitmap.GetPixel($sampleX, $sampleY).ToArgb())
            }
        }
        if ($colors.Count -lt 8) {
            throw "Close-layer screenshot is near-uniform."
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            width = $bounds.width
            height = $bounds.height
            sampledUniqueColors = $colors.Count
            length = (Get-Item -LiteralPath $Path).Length
            sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

function Get-DialogState(
    [int]$ProcessId,
    [IntPtr]$MainHandle,
    [string]$ScreenshotPath) {
    $dialog = Find-ElementById `
        -ProcessId $ProcessId `
        -AutomationId "UnsavedChanges.Dialog" `
        -Visible
    $dialogHandle = [IntPtr]::new([long]$dialog.Current.NativeWindowHandle)
    if ($dialogHandle -eq [IntPtr]::Zero) {
        throw "Unsaved-changes dialog does not expose a native window handle."
    }
    $owner = [LumaChartCloseLayerGuiNative]::GetWindow($dialogHandle, 4)
    $foreground = [LumaChartCloseLayerGuiNative]::GetForegroundWindow()
    $lastActivePopup =
        [LumaChartCloseLayerGuiNative]::GetLastActivePopup($MainHandle)
    $state = [ordered]@{
        dialogHandle = $dialogHandle.ToInt64()
        ownerHandle = $owner.ToInt64()
        foregroundHandle = $foreground.ToInt64()
        lastActivePopupHandle = $lastActivePopup.ToInt64()
        mainEnabled =
            [LumaChartCloseLayerGuiNative]::IsWindowEnabled($MainHandle)
        mainTopmostStyle =
            [LumaChartCloseLayerGuiNative]::IsTopmostStyleSet($MainHandle)
        dialogTopmostStyle =
            [LumaChartCloseLayerGuiNative]::IsTopmostStyleSet($dialogHandle)
        mainIsZoomed =
            [LumaChartCloseLayerGuiNative]::IsZoomed($MainHandle)
        mainBounds = Get-WindowBounds $MainHandle
        dialogBounds = Get-WindowBounds $dialogHandle
        dialogName = [string]$dialog.Current.Name
        dialogHelpText = [string]$dialog.Current.HelpText
    }
    if ($owner -ne $MainHandle) {
        throw "Unsaved-changes dialog native owner is not the main window."
    }
    if ($foreground -ne $dialogHandle) {
        throw "Unsaved-changes dialog is not the foreground window."
    }
    if ($lastActivePopup -ne $dialogHandle) {
        throw "Unsaved-changes dialog is not the main window's active popup."
    }
    if ($state.mainEnabled) {
        throw "Main window remained enabled while the modal dialog was open."
    }
    if ($state.mainTopmostStyle -or $state.dialogTopmostStyle) {
        throw "Main window or modal dialog retained a persistent topmost style."
    }
    if (-not $state.mainIsZoomed) {
        throw "Fullscreen close preflight did not restore the maximized owner."
    }
    if ($state.dialogName -cne "未保存的更改" -or
        $state.dialogHelpText -notlike "*wpf-1.1.0-dialog-r1*") {
        throw "Unsaved-changes dialog UIA contract is stale."
    }
    $state.screenshot = Capture-ScreenWindow $MainHandle $ScreenshotPath
    return [ordered]@{
        state = $state
        element = $dialog
        handle = $dialogHandle
    }
}

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$fixtureFullPath = Resolve-ExistingFile $ChartFixturePath "Real MC fixture"
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
if (-not (Test-Path -LiteralPath $outputFullPath -PathType Container)) {
    throw "Output root must already exist: $outputFullPath"
}
if ((Get-ChildItem -LiteralPath $outputFullPath -Force | Measure-Object).Count -ne 0) {
    throw "Output root must be empty: $outputFullPath"
}

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$dotnetHome = Join-Path $projectRoot ".dotnet-home"
$nugetPackages = Join-Path $projectRoot ".nuget\packages"
$nugetHttpCache = Join-Path $projectRoot ".nuget\http-cache"
$projectTemp = Join-Path $outputFullPath "temp"
$sessionRoot = Join-Path $outputFullPath "session"
$localDataRoot = Join-Path $sessionRoot "local-data"
$editingRoot = Join-Path $sessionRoot "editing"
$workspaceRoot = Join-Path $sessionRoot "workspace"
$fixtureRoot = Join-Path $outputFullPath "fixture"
foreach ($directory in @(
        $dotnetHome,
        $nugetPackages,
        $nugetHttpCache,
        $projectTemp,
        $localDataRoot,
        $editingRoot,
        $workspaceRoot,
        $fixtureRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$chartUnderTest = Join-Path $fixtureRoot (Split-Path -Leaf $fixtureFullPath)
Copy-Item -LiteralPath $fixtureFullPath -Destination $chartUnderTest
$fixtureHashBefore =
    (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
$chartHashBefore =
    (Get-FileHash -LiteralPath $chartUnderTest -Algorithm SHA256).Hash
$installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$installerHashBefore =
    (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
$runtimePath = Join-Path $outputFullPath "close-layer-runtime.json"
$cancelScreenshotPath =
    Join-Path $outputFullPath "fullscreen-close-cancel-dialog.png"
$discardScreenshotPath =
    Join-Path $outputFullPath "fullscreen-close-discard-dialog.png"
$evidencePath = Join-Path $outputFullPath "close-layer-gui-evidence.json"
$process = $null

try {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $applicationFullPath
    $start.UseShellExecute = $false
    $start.WorkingDirectory = Split-Path -Parent $applicationFullPath
    $start.ArgumentList.Add("--evidence-chart")
    $start.ArgumentList.Add($chartUnderTest)
    $start.ArgumentList.Add("--evidence-output")
    $start.ArgumentList.Add($runtimePath)
    $start.ArgumentList.Add("--evidence-focus-note-property")
    $start.Environment["LUMACHART_PROFILE"] = "close-layer-parity"
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
        throw "Unable to start Windows Avalonia close-layer client."
    }

    Wait-Condition -Description "close-layer main window" -Condition {
        $process.Refresh()
        -not $process.HasExited -and
        $process.MainWindowHandle -ne [IntPtr]::Zero
    }
    $mainHandle = $process.MainWindowHandle
    $timeline = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Timeline.Surface" `
        -Visible
    $timeline.SetFocus()
    Set-ForegroundWindowVerified $mainHandle
    if ([LumaChartCloseLayerGuiNative]::IsTopmostStyleSet($mainHandle)) {
        throw "Main window started with a persistent topmost style."
    }

    $volume = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Inspector.Note.Volume" `
        -Visible
    Set-ElementValue $volume "73"
    $apply = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Inspector.Note.Apply" `
        -Visible
    $applyClick =
        Invoke-PhysicalElementClick $apply $mainHandle "Note property Apply"
    Wait-Condition -Description "dirty chart after physical Note Apply" -Condition {
        $saveState = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Title.SaveState" `
            -TimeoutMilliseconds 300
        [string]$saveState.Current.Name -ceq "· 未保存"
    }

    $maximize = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Title.MaximizeRestore" `
        -Visible
    $maximizeClick =
        Invoke-PhysicalElementClick $maximize $mainHandle "Maximize"
    Wait-Condition -Description "maximized main window" -Condition {
        [LumaChartCloseLayerGuiNative]::IsZoomed($mainHandle)
    }
    if ([LumaChartCloseLayerGuiNative]::IsTopmostStyleSet($mainHandle)) {
        throw "Maximized main window gained a persistent topmost style."
    }

    Set-ForegroundWindowVerified $mainHandle
    [LumaChartCloseLayerGuiNative]::PressF11()
    Wait-Condition -Description "physical F11 fullscreen" -Condition {
        try {
            $title = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Title.Chrome" `
                -TimeoutMilliseconds 300
            $bounds = $title.Current.BoundingRectangle
            $window = Get-WindowBounds $mainHandle
            $title.Current.IsOffscreen -or
                $bounds.Bottom -le ($window.top + 2)
        }
        catch {
            return $false
        }
    }
    $fullscreenBoundsBeforeCancel = Get-WindowBounds $mainHandle
    if ([LumaChartCloseLayerGuiNative]::IsTopmostStyleSet($mainHandle)) {
        throw "Fullscreen main window gained a persistent topmost style."
    }

    Set-ForegroundWindowVerified $mainHandle
    [LumaChartCloseLayerGuiNative]::PressAltF4()
    Wait-Condition -Description "first unsaved-changes dialog" -Condition {
        try {
            [void](Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "UnsavedChanges.Dialog" `
                -TimeoutMilliseconds 300 `
                -Visible)
            return $true
        }
        catch {
            return $false
        }
    }
    $cancelDialog = Get-DialogState `
        -ProcessId $process.Id `
        -MainHandle $mainHandle `
        -ScreenshotPath $cancelScreenshotPath
    $cancelButton = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "UnsavedChanges.Cancel" `
        -Visible
    $cancelClick = Invoke-PhysicalElementClick `
        $cancelButton `
        $cancelDialog.handle `
        "Unsaved changes Cancel"
    Wait-Condition -Description "cancel dialog closed" -Condition {
        Test-ElementAbsent `
            -ProcessId $process.Id `
            -AutomationId "UnsavedChanges.Dialog"
    }
    Wait-Condition -Description "fullscreen restored after cancel" -Condition {
        try {
            $title = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Title.Chrome" `
                -TimeoutMilliseconds 300
            $bounds = $title.Current.BoundingRectangle
            $window = Get-WindowBounds $mainHandle
            $title.Current.IsOffscreen -or
                $bounds.Bottom -le ($window.top + 2)
        }
        catch {
            return $false
        }
    }
    $fullscreenBoundsAfterCancel = Get-WindowBounds $mainHandle
    if ([LumaChartCloseLayerGuiNative]::IsTopmostStyleSet($mainHandle)) {
        throw "Canceled close restored fullscreen with a persistent topmost style."
    }
    if ([LumaChartCloseLayerGuiNative]::GetForegroundWindow() -ne $mainHandle) {
        throw "Canceled close did not return foreground ownership to the editor."
    }

    Set-ForegroundWindowVerified $mainHandle
    [LumaChartCloseLayerGuiNative]::PressAltF4()
    Wait-Condition -Description "second unsaved-changes dialog" -Condition {
        try {
            [void](Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "UnsavedChanges.Dialog" `
                -TimeoutMilliseconds 300 `
                -Visible)
            return $true
        }
        catch {
            return $false
        }
    }
    $discardDialog = Get-DialogState `
        -ProcessId $process.Id `
        -MainHandle $mainHandle `
        -ScreenshotPath $discardScreenshotPath
    $discardButton = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "UnsavedChanges.Discard" `
        -Visible
    $discardClick = Invoke-PhysicalElementClick `
        $discardButton `
        $discardDialog.handle `
        "Unsaved changes Discard"
    Wait-Condition -Description "process exit after discard" -Condition {
        $process.Refresh()
        $process.HasExited
    }

    $fixtureHashAfter =
        (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
    $chartHashAfter =
        (Get-FileHash -LiteralPath $chartUnderTest -Algorithm SHA256).Hash
    $installerHashAfter =
        (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
    if ($fixtureHashAfter -cne $fixtureHashBefore) {
        throw "Real MC fixture changed during close-layer GUI acceptance."
    }
    if ($chartHashAfter -cne $chartHashBefore) {
        throw "Discard close mutated the isolated chart."
    }
    if ($installerHashAfter -cne $installerHashBefore) {
        throw "Frozen WPF installer changed during close-layer GUI acceptance."
    }

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.close-layer-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        platform = "Windows Avalonia only"
        buildMode = "ordinary .NET Release"
        windowsAvaloniaOnly = $true
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        physicalInput = [ordered]@{
            noteApply = $applyClick
            maximize = $maximizeClick
            fullscreenEnter = "Win32 F11 key down/up"
            firstClose = "Win32 Alt+F4 key down/up"
            cancel = $cancelClick
            secondClose = "Win32 Alt+F4 key down/up"
            discard = $discardClick
            mouseButtonActionCount = 4
            keyboardActionCount = 3
            uiAutomationInvokePatternUsedForBusinessActions = $false
            hardwareInputClaimed = $false
        }
        zOrder = [ordered]@{
            mainTopmostBeforeFullscreen = $false
            mainTopmostDuringFullscreen = $false
            cancelDialog = $cancelDialog.state
            mainTopmostAfterCanceledClose = $false
            discardDialog = $discardDialog.state
            ownerModalWithoutPersistentTopmost = $true
        }
        fullscreenClosePreflight = [ordered]@{
            enteredFromMaximized = $true
            firstDialogOwnerRestoredMaximized = $true
            cancelRestoredFullscreen = $true
            secondDialogOwnerRestoredMaximized = $true
            fullscreenBoundsBeforeCancel = $fullscreenBoundsBeforeCancel
            fullscreenBoundsAfterCancel = $fullscreenBoundsAfterCancel
        }
        chart = [ordered]@{
            sourceFixture = $fixtureFullPath
            sourceFixtureSha256Before = $fixtureHashBefore
            sourceFixtureSha256After = $fixtureHashAfter
            isolatedChart = $chartUnderTest
            isolatedChartSha256Before = $chartHashBefore
            isolatedChartSha256After = $chartHashAfter
            dirtyMutation = "selected Note volume -> 73"
            discardLeftSourceUnchanged = $true
        }
        installer = [ordered]@{
            path = $installerPath
            sha256Before = $installerHashBefore
            sha256After = $installerHashAfter
        }
        screenshots = [ordered]@{
            cancel = $cancelDialog.state.screenshot
            discard = $discardDialog.state.screenshot
        }
        process = [ordered]@{
            id = $process.Id
            exitedAfterDiscard = $process.HasExited
            exitCode = $process.ExitCode
        }
        migrationComplete = $false
        remainingDifferences = @(
            "The complete Windows parity matrix remains open.",
            "Settings focus, Note-anchor and real osu GUI slices still require physical acceptance.",
            "Performance, installer/security and remaining online gates still require formal closure.",
            "User replacement approval has not been granted.")
    }
    $evidence |
        ConvertTo-Json -Depth 16 |
        Set-Content -LiteralPath $evidencePath -Encoding UTF8
    Write-Host "Windows Avalonia close-layer GUI acceptance: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    if ($process -and -not $process.HasExited) {
        try {
            [LumaChartCloseLayerGuiNative]::ForceNonTopmost(
                $process.MainWindowHandle) | Out-Null
        }
        catch { }
        try {
            $process.CloseMainWindow() | Out-Null
            if (-not $process.WaitForExit(5000)) {
                $process.Kill($true)
                $process.WaitForExit()
            }
        }
        catch { }
    }
}
