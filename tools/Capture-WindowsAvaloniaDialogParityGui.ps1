param(
    [Parameter(Mandatory = $true)][string]$ApplicationPath,
    [Parameter(Mandatory = $true)][string]$ChartPath,
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(15, 120)][int]$TimeoutSeconds = 45
)

if ($PSVersionTable.PSEdition -ne "Core") {
    throw "Windows Avalonia dialog GUI capture requires PowerShell Core."
}
if (-not $IsWindows) {
    throw "Windows Avalonia dialog GUI capture is Windows-only."
}

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$artifactBoundary =
    [IO.Path]::GetFullPath((Join-Path $projectRoot "artifacts")).TrimEnd('\') + '\'
$applicationFullPath = [IO.Path]::GetFullPath($ApplicationPath)
$chartFullPath = [IO.Path]::GetFullPath($ChartPath)
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot).TrimEnd('\')

if (-not $outputFullPath.StartsWith(
        $artifactBoundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Dialog GUI output must stay under $artifactBoundary"
}
if (Test-Path -LiteralPath $outputFullPath) {
    throw "Dialog GUI output must start empty: $outputFullPath"
}
if (-not (Test-Path -LiteralPath $applicationFullPath -PathType Leaf)) {
    throw "Avalonia executable does not exist: $applicationFullPath"
}
if (-not (Test-Path -LiteralPath $chartFullPath -PathType Leaf) -or
    [IO.Path]::GetExtension($chartFullPath) -cne ".mc") {
    throw "Dialog GUI capture requires a real MC fixture: $chartFullPath"
}

$sessionRoot = Join-Path $outputFullPath "session"
$sourceRoot = Join-Path $sessionRoot "source"
$workspaceRoot = Join-Path $sessionRoot "workspace"
$localDataRoot = Join-Path $sessionRoot "local-data"
$editingRoot = Join-Path $sessionRoot "editing"
$screenshotsRoot = Join-Path $outputFullPath "screenshots"
foreach ($path in @(
        $sourceRoot,
        $workspaceRoot,
        $localDataRoot,
        $editingRoot,
        $screenshotsRoot)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

$isolatedChartPath = Join-Path $sourceRoot "dialog-parity-fixture.mc"
Copy-Item -LiteralPath $chartFullPath -Destination $isolatedChartPath
$sourceHashBefore =
    (Get-FileHash -LiteralPath $isolatedChartPath -Algorithm SHA256).Hash
$runtimeEvidencePath = Join-Path $outputFullPath "runtime-evidence.json"
$dirtyScreenshotPath = Join-Path $screenshotsRoot "01-dirty-editor.png"
$dialogScreenshotPath = Join-Path $screenshotsRoot "02-unsaved-dialog.png"
$hoverScreenshotPath = Join-Path $screenshotsRoot "03-unsaved-discard-hover.png"
$cancelledScreenshotPath = Join-Path $screenshotsRoot "04-cancelled-close.png"
$finalScreenshotPath = Join-Path $screenshotsRoot "05-discarded-tab.png"
$evidencePath = Join-Path $outputFullPath "evidence.json"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LumaChartDialogCaptureNative
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
    public static extern bool IsWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(
        IntPtr window,
        out uint processId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(
        uint firstThread,
        uint secondThread,
        bool attach);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT point);

    [DllImport("user32.dll")]
    public static extern IntPtr WindowFromPoint(POINT point);

    [DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr window, uint flags);

    [DllImport("user32.dll")]
    public static extern void mouse_event(
        uint flags,
        uint dx,
        uint dy,
        uint data,
        UIntPtr extraInfo);

    public const uint MouseLeftDown = 0x0002;
    public const uint MouseLeftUp = 0x0004;
    public const uint RootAncestor = 2;

    public static bool TryActivateWindow(IntPtr window)
    {
        if (window == IntPtr.Zero)
            return false;
        var foreground = GetForegroundWindow();
        if (foreground == window)
            return true;

        var currentThread = GetCurrentThreadId();
        var foregroundThread = foreground == IntPtr.Zero
            ? 0
            : GetWindowThreadProcessId(foreground, out _);
        var targetThread = GetWindowThreadProcessId(window, out _);
        var attachedForeground = false;
        var attachedTarget = false;
        try
        {
            if (foregroundThread != 0 && foregroundThread != currentThread)
                attachedForeground =
                    AttachThreadInput(currentThread, foregroundThread, true);
            if (targetThread != 0 &&
                targetThread != currentThread &&
                targetThread != foregroundThread)
                attachedTarget =
                    AttachThreadInput(currentThread, targetThread, true);
            ShowWindowAsync(window, 9);
            BringWindowToTop(window);
            SetForegroundWindow(window);
            return GetForegroundWindow() == window;
        }
        finally
        {
            if (attachedTarget)
                AttachThreadInput(currentThread, targetThread, false);
            if (attachedForeground)
                AttachThreadInput(currentThread, foregroundThread, false);
        }
    }
}
'@

function Wait-Condition {
    param(
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][scriptblock]$Condition,
        [int]$Seconds = $TimeoutSeconds
    )

    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt $Seconds) {
        try {
            if (& $Condition) {
                $timer.Stop()
                return
            }
        }
        catch [System.Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 100
    }
    throw "Timed out waiting for $Description."
}

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [int]$Seconds = $TimeoutSeconds
    )

    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt $Seconds) {
        $condition = [System.Windows.Automation.AndCondition]::new(
            [System.Windows.Automation.PropertyCondition]::new(
                [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
                $ProcessId),
            [System.Windows.Automation.PropertyCondition]::new(
                [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
                $AutomationId))
        try {
            $result =
                [System.Windows.Automation.AutomationElement]::RootElement.FindFirst(
                    [System.Windows.Automation.TreeScope]::Descendants,
                    $condition)
            if ($null -ne $result -and
                -not [bool]$result.Current.IsOffscreen -and
                [bool]$result.Current.IsEnabled) {
                $timer.Stop()
                return $result
            }
        }
        catch [System.Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 100
    }
    throw "Timed out waiting for AutomationId $AutomationId."
}

function Invoke-Element {
    param([Parameter(Mandatory = $true)]$Element)

    $pattern = $Element.GetCurrentPattern(
        [System.Windows.Automation.InvokePattern]::Pattern)
    $pattern.Invoke()
}

function Select-Element {
    param([Parameter(Mandatory = $true)]$Element)

    $pattern = $Element.GetCurrentPattern(
        [System.Windows.Automation.SelectionItemPattern]::Pattern)
    $pattern.Select()
}

function Set-ElementValue {
    param(
        [Parameter(Mandatory = $true)]$Element,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $pattern = $Element.GetCurrentPattern(
        [System.Windows.Automation.ValuePattern]::Pattern)
    $pattern.SetValue($Value)
}

function Set-ForegroundVerified {
    param([Parameter(Mandatory = $true)][IntPtr]$WindowHandle)

    if ($WindowHandle -eq [IntPtr]::Zero) {
        throw "Cannot foreground a zero HWND."
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        if ([LumaChartDialogCaptureNative]::GetForegroundWindow() -eq $WindowHandle) {
            return
        }
        [void][LumaChartDialogCaptureNative]::TryActivateWindow($WindowHandle)
        Start-Sleep -Milliseconds 40
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out waiting for foreground HWND $WindowHandle; foreground is " +
        [LumaChartDialogCaptureNative]::GetForegroundWindow() + "."
}

function Move-PointerVerified {
    param(
        [Parameter(Mandatory = $true)]$Element,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.IsEmpty -or $bounds.Width -le 1 -or $bounds.Height -le 1) {
        throw "Pointer target has invalid bounds."
    }
    $x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    if (-not [LumaChartDialogCaptureNative]::SetCursorPos($x, $y)) {
        throw "Could not position the real pointer."
    }
    Start-Sleep -Milliseconds 120
    $point = [LumaChartDialogCaptureNative+POINT]::new()
    if (-not [LumaChartDialogCaptureNative]::GetCursorPos([ref]$point) -or
        $point.X -ne $x -or $point.Y -ne $y) {
        throw "The real pointer did not remain at the requested target."
    }
    $hit = [LumaChartDialogCaptureNative]::WindowFromPoint($point)
    $hitRoot = [LumaChartDialogCaptureNative]::GetAncestor(
        $hit,
        [LumaChartDialogCaptureNative]::RootAncestor)
    if ($hitRoot -ne $RootWindowHandle) {
        throw "The physical pointer target is not inside the intended window."
    }
    return [ordered]@{
        x = $x
        y = $y
        targetBounds = [ordered]@{
            left = [double]$bounds.Left
            top = [double]$bounds.Top
            width = [double]$bounds.Width
            height = [double]$bounds.Height
        }
        hitRootWindowHandle = [long]$hitRoot
    }
}

function Click-ElementPhysically {
    param(
        [Parameter(Mandatory = $true)]$Element,
        [Parameter(Mandatory = $true)][IntPtr]$RootWindowHandle
    )

    Set-ForegroundVerified -WindowHandle $RootWindowHandle
    $pointer = Move-PointerVerified `
        -Element $Element `
        -RootWindowHandle $RootWindowHandle
    [LumaChartDialogCaptureNative]::mouse_event(
        [LumaChartDialogCaptureNative]::MouseLeftDown,
        0,
        0,
        0,
        [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 45
    [LumaChartDialogCaptureNative]::mouse_event(
        [LumaChartDialogCaptureNative]::MouseLeftUp,
        0,
        0,
        0,
        [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 180
    return $pointer
}

function Capture-Window {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$WindowHandle,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $rectangle = [LumaChartDialogCaptureNative+RECT]::new()
    if (-not [LumaChartDialogCaptureNative]::GetWindowRect(
            $WindowHandle,
            [ref]$rectangle)) {
        throw "Could not read the capture-window bounds."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -le 1 -or $height -le 1) {
        throw "Capture-window bounds are invalid."
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
                [Drawing.Size]::new($width, $height),
                [Drawing.CopyPixelOperation]::SourceCopy)
        }
        finally {
            $graphics.Dispose()
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
    return [ordered]@{
        path = $Path
        width = $width
        height = $height
        length = (Get-Item -LiteralPath $Path).Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

$process = $null
$evidence = [ordered]@{
    schemaVersion = 1
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "running"
    scope = "Windows Avalonia WPF 1.1.0 shared modal dialog chrome"
    contract = "wpf-1.1.0-dialog-r1"
    input = [ordered]@{
        application = $applicationFullPath
        sourceChart = $chartFullPath
        isolatedChart = $isolatedChartPath
        isolatedChartSha256Before = $sourceHashBefore
    }
    actions = [Collections.Generic.List[object]]::new()
    screenshots = [Collections.Generic.List[object]]::new()
}

try {
    $start = [Diagnostics.ProcessStartInfo]::new($applicationFullPath)
    $start.UseShellExecute = $false
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceRoot
    foreach ($argument in @(
            "--evidence-chart",
            $isolatedChartPath,
            "--evidence-output",
            $runtimeEvidencePath)) {
        $start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::Start($start)
    if ($null -eq $process) {
        throw "Could not start the Windows Avalonia process."
    }

    Wait-Condition -Description "Avalonia main window" -Condition {
        $process.Refresh()
        -not $process.HasExited -and $process.MainWindowHandle -ne [IntPtr]::Zero
    }
    $mainWindowHandle = $process.MainWindowHandle
    Set-ForegroundVerified -WindowHandle $mainWindowHandle

    $metadataTab = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Inspector.MetadataTab"
    Select-Element -Element $metadataTab
    $titleBox = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Metadata.Title"
    $titleValue = $titleBox.GetCurrentPattern(
        [System.Windows.Automation.ValuePattern]::Pattern).Current.Value
    Set-ElementValue -Element $titleBox -Value ($titleValue + " Dialog")
    Invoke-Element -Element (
        Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Metadata.Apply")
    $chartTab = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.ChartTab"
    Wait-Condition -Description "dirty chart tab" -Condition {
        $chartTab = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.ChartTab" `
            -Seconds 3
        [string]$chartTab.Current.HelpText -like "*未保存：是*"
    }
    $evidence.actions.Add([ordered]@{
        action = "set metadata title and apply"
        method = "UIA ValuePattern + InvokePattern"
        dirtyTabHelpText = [string]$chartTab.Current.HelpText
    })
    $evidence.screenshots.Add(
        (Capture-Window -WindowHandle $mainWindowHandle -Path $dirtyScreenshotPath))

    $closeTab = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.ChartTab.Close"
    $closeTabClick = Click-ElementPhysically `
        -Element $closeTab `
        -RootWindowHandle $mainWindowHandle
    $dialog = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "UnsavedChanges.Dialog"
    $dialogWindowHandle = [IntPtr]$dialog.Current.NativeWindowHandle
    if ($dialogWindowHandle -eq [IntPtr]::Zero) {
        throw "Unsaved dialog did not expose a native owner-modal HWND."
    }
    Set-ForegroundVerified -WindowHandle $dialogWindowHandle
    $cancel = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "UnsavedChanges.Cancel"
    $discard = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "UnsavedChanges.Discard"
    $save = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "UnsavedChanges.Save"
    $dialogContractObservation = [ordered]@{
        windowName = [string]$dialog.Current.Name
        windowHelpText = [string]$dialog.Current.HelpText
        cancelName = [string]$cancel.Current.Name
        cancelHelpText = [string]$cancel.Current.HelpText
        discardName = [string]$discard.Current.Name
        discardHelpText = [string]$discard.Current.HelpText
        saveName = [string]$save.Current.Name
        saveHelpText = [string]$save.Current.HelpText
    }
    if ($dialogContractObservation.windowName -cne "未保存的更改" -or
        $dialogContractObservation.windowHelpText -notlike "*wpf-1.1.0-dialog-r1*" -or
        $dialogContractObservation.cancelName -cne "取消" -or
        $dialogContractObservation.discardName -cne "放弃更改" -or
        $dialogContractObservation.discardHelpText -notlike "*视觉标签=否*" -or
        $dialogContractObservation.saveName -cne "是") {
        throw ("Unsaved dialog did not expose the exact visual/UIA compatibility contract: " +
            ($dialogContractObservation | ConvertTo-Json -Compress))
    }
    $evidence.screenshots.Add(
        (Capture-Window -WindowHandle $dialogWindowHandle -Path $dialogScreenshotPath))
    $discardHover = Move-PointerVerified `
        -Element $discard `
        -RootWindowHandle $dialogWindowHandle
    Start-Sleep -Milliseconds 220
    $evidence.screenshots.Add(
        (Capture-Window -WindowHandle $dialogWindowHandle -Path $hoverScreenshotPath))
    if ($evidence.screenshots[1].sha256 -ceq $evidence.screenshots[2].sha256) {
        throw "Physical discard hover did not change the dialog screenshot."
    }
    $cancelClick = Click-ElementPhysically `
        -Element $cancel `
        -RootWindowHandle $dialogWindowHandle
    Wait-Condition -Description "cancelled unsaved dialog closes" -Condition {
        -not [LumaChartDialogCaptureNative]::IsWindow($dialogWindowHandle)
    }
    Set-ForegroundVerified -WindowHandle $mainWindowHandle
    $evidence.screenshots.Add(
        (Capture-Window -WindowHandle $mainWindowHandle -Path $cancelledScreenshotPath))
    $tabAfterCancel = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.ChartTab"
    if ([string]$tabAfterCancel.Current.HelpText -notlike "*未保存：是*") {
        throw "Physical Cancel did not preserve the dirty editor tab."
    }

    $closeTabSecond = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.ChartTab.Close"
    $closeTabSecondClick = Click-ElementPhysically `
        -Element $closeTabSecond `
        -RootWindowHandle $mainWindowHandle
    $dialogSecond = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "UnsavedChanges.Dialog"
    $dialogSecondWindowHandle = [IntPtr]$dialogSecond.Current.NativeWindowHandle
    $discardSecond = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "UnsavedChanges.Discard"
    $discardClick = Click-ElementPhysically `
        -Element $discardSecond `
        -RootWindowHandle $dialogSecondWindowHandle
    Wait-Condition -Description "dirty tab discarded" -Condition {
        $condition = [System.Windows.Automation.AndCondition]::new(
            [System.Windows.Automation.PropertyCondition]::new(
                [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
                $process.Id),
            [System.Windows.Automation.PropertyCondition]::new(
                [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
                "Editor.ChartTab"))
        $null -eq [System.Windows.Automation.AutomationElement]::RootElement.FindFirst(
            [System.Windows.Automation.TreeScope]::Descendants,
            $condition)
    }
    Set-ForegroundVerified -WindowHandle $mainWindowHandle
    $evidence.screenshots.Add(
        (Capture-Window -WindowHandle $mainWindowHandle -Path $finalScreenshotPath))

    Wait-Condition -Description "runtime GUI evidence" -Seconds 30 -Condition {
        Test-Path -LiteralPath $runtimeEvidencePath -PathType Leaf
    }
    $runtime = Get-Content -LiteralPath $runtimeEvidencePath -Raw |
        ConvertFrom-Json
    if ([string]$runtime.schema -cne
            "lumachart.windows.avalonia.gui-evidence.v14" -or
        [string]$runtime.platformScope -cne "Windows-only" -or
        [string]$runtime.chart.sourceSha256 -cne $sourceHashBefore -or
        [int]$runtime.chart.structure.noteCount -ne 2753 -or
        [int]$runtime.chart.structure.longNoteCount -ne 771) {
        throw "Product v14 runtime evidence did not prove the real Windows MC workload."
    }

    $evidence.actions.Add([ordered]@{
        action = "open unsaved dialog"
        method = "foreground physical click"
        pointer = $closeTabClick
        nativeWindowHandle = [long]$dialogWindowHandle
        windowName = $dialogContractObservation.windowName
        contractHelpText = $dialogContractObservation.windowHelpText
    })
    $evidence.actions.Add([ordered]@{
        action = "hover and cancel"
        method = "foreground physical pointer and click"
        hover = $discardHover
        cancel = $cancelClick
        dirtyTabPreserved = $true
    })
    $evidence.actions.Add([ordered]@{
        action = "reopen and discard"
        method = "foreground physical clicks"
        reopen = $closeTabSecondClick
        discard = $discardClick
        dirtyTabRemoved = $true
    })
    $sourceHashAfter =
        (Get-FileHash -LiteralPath $isolatedChartPath -Algorithm SHA256).Hash
    if ($sourceHashAfter -cne $sourceHashBefore) {
        throw "Discard GUI changed the isolated real MC source."
    }
    $evidence.input.isolatedChartSha256After = $sourceHashAfter
    $evidence.input.sourceUnchanged = $true
    $evidence.runtimeEvidence = [ordered]@{
        path = $runtimeEvidencePath
        schema = [string]$runtime.schema
        platformScope = [string]$runtime.platformScope
        noteCount = [int]$runtime.chart.structure.noteCount
        longNoteCount = [int]$runtime.chart.structure.longNoteCount
        length = (Get-Item -LiteralPath $runtimeEvidencePath).Length
        sha256 =
            (Get-FileHash -LiteralPath $runtimeEvidencePath -Algorithm SHA256).Hash
    }
    $evidence.status = "passed"
}
catch {
    $evidence.status = "failed"
    $evidence.failure = $_.Exception.ToString()
    throw
}
finally {
    $evidence.generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    $evidence | ConvertTo-Json -Depth 20 |
        Set-Content -LiteralPath $evidencePath -Encoding UTF8
    if ($null -ne $process) {
        try {
            $process.Refresh()
            if (-not $process.HasExited) {
                [void]$process.CloseMainWindow()
                if (-not $process.WaitForExit(10000)) {
                    Stop-Process -Id $process.Id -Force
                    [void]$process.WaitForExit(5000)
                }
            }
        }
        catch { }
        $process.Dispose()
    }
}

Write-Output "Windows Avalonia dialog GUI capture: $($evidence.status)"
Write-Output "Evidence: $evidencePath"
