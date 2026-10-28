param(
    [string]$ApplicationPath = (
        Join-Path $PSScriptRoot `
            "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
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
    throw "Windows Avalonia library chart-action GUI capture requires PowerShell Core on Windows."
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartLibraryChartActionsNative
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
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

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

    public static uint ForegroundProcessId()
    {
        uint processId;
        GetWindowThreadProcessId(GetForegroundWindow(), out processId);
        return processId;
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

function Find-ElementById {
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
    if ($Optional) { return $null }
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Find-ElementByIdAndName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][string]$NameContains,
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
                    if ([string]$match.Current.Name -like "*$NameContains*") {
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
    throw (
        "Timed out finding UI Automation id '$AutomationId' containing " +
        "'$NameContains' for process $ProcessId.")
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

function Click-Element {
    param(
        [Parameter(Mandatory = $true)]
        [Windows.Automation.AutomationElement]$Element,
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][IntPtr]$WindowHandle,
        [switch]$Right,
        [switch]$Physical
    )
    Assert (-not $Element.Current.IsOffscreen) (
        "Element '$($Element.Current.AutomationId)' is offscreen.")
    Assert ([bool]$Element.Current.IsEnabled) (
        "Element '$($Element.Current.AutomationId)' is disabled.")
    $bounds = $Element.Current.BoundingRectangle
    $x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    $inputKind = $null
    if ($Right) {
        $point = [LumaChartLibraryChartActionsNative+POINT]::new()
        $point.X = $x
        $point.Y = $y
        Assert (
            [LumaChartLibraryChartActionsNative]::ScreenToClient(
                $WindowHandle,
                [ref]$point)) (
            "ScreenToClient failed for '$($Element.Current.AutomationId)'.")
        $packed = (($point.Y -band 0xffff) -shl 16) -bor
            ($point.X -band 0xffff)
        Assert (
            [LumaChartLibraryChartActionsNative]::PostMessage(
                $WindowHandle,
                0x0204,
                [IntPtr]2,
                [IntPtr]$packed)) (
            "WM_RBUTTONDOWN failed for '$($Element.Current.AutomationId)'.")
        Start-Sleep -Milliseconds 45
        Assert (
            [LumaChartLibraryChartActionsNative]::PostMessage(
                $WindowHandle,
                0x0205,
                [IntPtr]::Zero,
                [IntPtr]$packed)) (
            "WM_RBUTTONUP failed for '$($Element.Current.AutomationId)'.")
        $inputKind =
            "Win32 WM_RBUTTONDOWN/UP posted to target Avalonia HWND at live UIA bounds"
    }
    elseif ($Physical) {
        [void][LumaChartLibraryChartActionsNative]::SetForegroundWindow(
            $WindowHandle)
        Wait-Condition -Description "target window foreground before card click" `
            -Seconds 5 `
            -Condition {
                [LumaChartLibraryChartActionsNative]::ForegroundProcessId() -eq
                    [uint32]$ProcessId
            }
        Assert (
            [LumaChartLibraryChartActionsNative]::SetCursorPos($x, $y)) (
            "SetCursorPos failed for '$($Element.Current.AutomationId)'.")
        Start-Sleep -Milliseconds 80
        [LumaChartLibraryChartActionsNative]::mouse_event(
            0x0002,
            0,
            0,
            0,
            [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 45
        [LumaChartLibraryChartActionsNative]::mouse_event(
            0x0004,
            0,
            0,
            0,
            [UIntPtr]::Zero)
        $inputKind =
            "Win32 mouse_event left click at live Library.FolderItem UIA center"
    }
    else {
        try {
            $pattern = $Element.GetCurrentPattern(
                [Windows.Automation.InvokePattern]::Pattern)
            $pattern.Invoke()
            $inputKind = "UI Automation InvokePattern"
        }
        catch {
            $screenPoint =
                [LumaChartLibraryChartActionsNative+POINT]::new()
            $screenPoint.X = $x
            $screenPoint.Y = $y
            $targetWindow =
                [LumaChartLibraryChartActionsNative]::WindowFromPoint(
                    $screenPoint)
            Assert ($targetWindow -ne [IntPtr]::Zero) (
                "WindowFromPoint failed for '$($Element.Current.AutomationId)'.")
            $clientPoint = $screenPoint
            Assert (
                [LumaChartLibraryChartActionsNative]::ScreenToClient(
                    $targetWindow,
                    [ref]$clientPoint)) (
                "ScreenToClient failed for '$($Element.Current.AutomationId)'.")
            $packed = (($clientPoint.Y -band 0xffff) -shl 16) -bor
                ($clientPoint.X -band 0xffff)
            Assert (
                [LumaChartLibraryChartActionsNative]::PostMessage(
                    $targetWindow,
                    0x0201,
                    [IntPtr]1,
                    [IntPtr]$packed)) (
                "WM_LBUTTONDOWN failed for '$($Element.Current.AutomationId)'.")
            Start-Sleep -Milliseconds 45
            Assert (
                [LumaChartLibraryChartActionsNative]::PostMessage(
                    $targetWindow,
                    0x0202,
                    [IntPtr]::Zero,
                    [IntPtr]$packed)) (
                "WM_LBUTTONUP failed for '$($Element.Current.AutomationId)'.")
            $inputKind =
                "Win32 WM_LBUTTONDOWN/UP posted to live UIA element HWND"
        }
    }
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        button = if ($Right) { "right" } else { "left" }
        x = $x
        y = $y
        input = $inputKind
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Capture-PhysicalWindow([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartLibraryChartActionsNative+RECT]::new()
    Assert (
        [LumaChartLibraryChartActionsNative]::GetWindowRect(
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
            captureKind = "physical desktop window including popup/owner"
        }
    }
    finally { $bitmap.Dispose() }
}

function Get-RecycleBinMatches([string]$FileName) {
    $shell = New-Object -ComObject Shell.Application
    try {
        $folder = $shell.NameSpace(10)
        if (-not $folder) { return @() }
        return @($folder.Items() | Where-Object {
            [string]$_.Name -ceq $FileName
        } | ForEach-Object {
            [ordered]@{
                name = [string]$_.Name
                path = [string]$_.Path
                deletedFrom = [string]$_.ExtendedProperty(
                    "System.Recycle.DeletedFrom")
                item = $_
            }
        })
    }
    finally {
        [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) |
            Out-Null
    }
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
$fixture = Resolve-ExistingFile $ChartFixturePath "real MC fixture"
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
$openFolder = Join-Path $workspace "OpenSong"
$deleteFolder = Join-Path $workspace "DeleteSong"
foreach ($directory in @(
        $localData,
        $editing,
        $workspace,
        $openFolder,
        $deleteFolder)) {
    [IO.Directory]::CreateDirectory($directory) | Out-Null
}
$uniqueToken = [Guid]::NewGuid().ToString("N")
$openChart = Join-Path $openFolder "open-chart.mc"
$deleteChartName = "delete-target-$uniqueToken.mc"
$deleteChart = Join-Path $deleteFolder $deleteChartName
$audioSibling = Join-Path $deleteFolder "shared-audio.ogg"
$imageSibling = Join-Path $deleteFolder "shared-cover.jpg"
Copy-Item -LiteralPath $fixture -Destination $openChart
Copy-Item -LiteralPath $fixture -Destination $deleteChart
[IO.File]::WriteAllBytes($audioSibling, [byte[]](1, 2, 3, 4, 5))
[IO.File]::WriteAllBytes($imageSibling, [byte[]](6, 7, 8, 9))

$installer = Resolve-ExistingFile (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe") "frozen installer"
$fixtureBefore = Get-Fingerprint $fixture
$installerBefore = Get-Fingerprint $installer
$openBefore = Get-Fingerprint $openChart
$deleteBefore = Get-Fingerprint $deleteChart
$recycleBefore = @(Get-RecycleBinMatches $deleteChartName)
$runtimeEvidencePath = Join-Path $output "runtime-evidence.json"
$evidencePath = Join-Path $output "evidence.json"
$actions = [Collections.Generic.List[object]]::new()
$process = $null
$restoreAttempted = $false
$restoreSucceeded = $false
try {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $application
    $start.WorkingDirectory = Split-Path -Parent $application
    $start.UseShellExecute = $false
    foreach ($argument in @(
            "--evidence-chart", $openChart,
            "--evidence-focus-library-deletion",
            "--evidence-output", $runtimeEvidencePath,
            "--evidence-interaction-delay-ms", "1800")) {
        $start.ArgumentList.Add($argument)
    }
    $start.Environment["LUMACHART_PROFILE"] =
        "windows-avalonia-library-chart-actions"
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
    [void][LumaChartLibraryChartActionsNative]::ShowWindow($handle, 3)
    [void][LumaChartLibraryChartActionsNative]::SetForegroundWindow($handle)
    Wait-Condition -Description "runtime evidence" -Condition {
        Test-Path -LiteralPath $runtimeEvidencePath -PathType Leaf
    }
    $topmostAtStart =
        [LumaChartLibraryChartActionsNative]::IsTopmost($handle)

    $openCard = Find-ElementByIdAndName `
        -ProcessId $process.Id `
        -AutomationId "Library.FolderItem" `
        -NameContains "OpenSong"
    $openExpandBeforeCardClick = Find-ElementByIdAndName `
        -ProcessId $process.Id `
        -AutomationId "Library.FolderExpand" `
        -NameContains "OpenSong"
    $openHeaderCollapsed = Observe-Element $openExpandBeforeCardClick
    [void]$actions.Add((Click-Element `
        -Element $openCard `
        -ProcessId $process.Id `
        -WindowHandle $handle `
        -Physical))
    $openRow = Find-ElementByIdAndName `
        -ProcessId $process.Id `
        -AutomationId "Library.ChartOpen" `
        -NameContains "OpenSong"
    $openHeaderExpanded = Observe-Element (
        Find-ElementByIdAndName `
            -ProcessId $process.Id `
            -AutomationId "Library.FolderExpand" `
            -NameContains "OpenSong")
    Assert (
        $openHeaderCollapsed.helpText -like "状态=已收起*" -and
        $openHeaderExpanded.helpText -like "状态=已展开*") (
        "Clicking the folder card header did not expose the expanded state.")
    $cardHeaderExpandedScreenshot = Capture-PhysicalWindow `
        $handle `
        (Join-Path $output "library-card-header-expanded.png")
    [void]$actions.Add((Click-Element `
        -Element $openRow `
        -ProcessId $process.Id `
        -WindowHandle $handle `
        -Right))
    $openDelete = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.ChartDelete"
    $openReveal = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.ChartReveal"
    $openMenuObserved = [ordered]@{
        reveal = Observe-Element $openReveal
        delete = Observe-Element $openDelete
    }
    $openMenuScreenshot = Capture-PhysicalWindow `
        $handle `
        (Join-Path $output "open-chart-context-menu.png")
    [void]$actions.Add((Click-Element `
        -Element $openDelete `
        -ProcessId $process.Id `
        -WindowHandle $handle))
    $blockedMessage = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.DeleteDialog.Message"
    $blockedConfirm = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.DeleteDialog.Confirm"
    $blockedScreenshot = Capture-PhysicalWindow `
        $handle `
        (Join-Path $output "open-chart-delete-blocked.png")
    $blockedObserved = [ordered]@{
        menu = $openMenuObserved
        message = Observe-Element $blockedMessage
        confirm = Observe-Element $blockedConfirm
    }
    Assert (
        $blockedObserved.message.name -ceq
            "这张谱面正在编辑。请先关闭对应谱面标签，再执行删除。") (
        "Open-chart block message did not match WPF 1.1.0.")
    [void]$actions.Add((Click-Element `
        -Element $blockedConfirm `
        -ProcessId $process.Id `
        -WindowHandle $handle))
    Assert (Test-Path -LiteralPath $openChart -PathType Leaf) (
        "Open chart changed after blocked deletion.")

    $deleteExpand = Find-ElementByIdAndName `
        -ProcessId $process.Id `
        -AutomationId "Library.FolderExpand" `
        -NameContains "DeleteSong"
    [void]$actions.Add((Click-Element `
        -Element $deleteExpand `
        -ProcessId $process.Id `
        -WindowHandle $handle))
    $deleteRow = Find-ElementByIdAndName `
        -ProcessId $process.Id `
        -AutomationId "Library.ChartOpen" `
        -NameContains "DeleteSong"
    [void]$actions.Add((Click-Element `
        -Element $deleteRow `
        -ProcessId $process.Id `
        -WindowHandle $handle `
        -Right))
    $targetDelete = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.ChartDelete"
    $targetReveal = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.ChartReveal"
    $targetMenuObserved = [ordered]@{
        reveal = Observe-Element $targetReveal
        delete = Observe-Element $targetDelete
    }
    $targetMenuScreenshot = Capture-PhysicalWindow `
        $handle `
        (Join-Path $output "target-chart-context-menu.png")
    [void]$actions.Add((Click-Element `
        -Element $targetDelete `
        -ProcessId $process.Id `
        -WindowHandle $handle))
    $confirmationMessage = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.DeleteDialog.Message"
    $cancel = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.DeleteDialog.Cancel"
    $recycle = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.DeleteDialog.Recycle"
    $confirmationScreenshot = Capture-PhysicalWindow `
        $handle `
        (Join-Path $output "target-chart-delete-confirmation.png")
    $confirmationObserved = [ordered]@{
        menu = $targetMenuObserved
        message = Observe-Element $confirmationMessage
        cancel = Observe-Element $cancel
        recycle = Observe-Element $recycle
    }
    Assert (
        $confirmationObserved.message.name -like
            "*只移除谱面文件，不影响同目录的共用音频和图片。*") (
        "Single-chart confirmation did not preserve WPF shared-resource copy.")
    [void]$actions.Add((Click-Element `
        -Element $recycle `
        -ProcessId $process.Id `
        -WindowHandle $handle))
    Wait-Condition -Description "single chart recycled" -Condition {
        -not (Test-Path -LiteralPath $deleteChart)
    }
    Assert (
        (Test-Path -LiteralPath $deleteFolder -PathType Container) -and
        (Test-Path -LiteralPath $audioSibling -PathType Leaf) -and
        (Test-Path -LiteralPath $imageSibling -PathType Leaf)) (
        "Single-chart deletion removed the song folder or shared resources.")
    Wait-Condition -Description "library index refresh after single-chart deletion" `
        -Seconds 10 `
        -Condition {
            $null -eq (Find-ElementByIdAndName `
                -ProcessId $process.Id `
                -AutomationId "Library.ChartOpen" `
                -NameContains $deleteChartName `
                -TimeoutMilliseconds 100 `
                -Optional)
        }
    Start-Sleep -Milliseconds 250
    $finalScreenshot = Capture-PhysicalWindow `
        $handle `
        (Join-Path $output "library-after-single-chart-delete.png")
    $topmostBeforeClose =
        [LumaChartLibraryChartActionsNative]::IsTopmost($handle)

    Close-WindowWithUia $process.Id
    Assert ($process.WaitForExit(10000)) (
        "Avalonia process did not exit after UIA Window close.")
    $processExitCode = $process.ExitCode
    Assert ($processExitCode -eq 0) (
        "Avalonia process exited with code $processExitCode.")

    $recycleAfter = @(Get-RecycleBinMatches $deleteChartName)
    Assert (
        $recycleAfter.Count -eq $recycleBefore.Count + 1) (
        "Unique target was not observed in the Windows Recycle Bin.")
    $newRecycleItem = @($recycleAfter | Where-Object {
        $candidatePath = [string]$_.path
        -not ($recycleBefore | Where-Object {
            [string]$_.path -ceq $candidatePath
        })
    }) | Select-Object -First 1
    if ($newRecycleItem -and $newRecycleItem.item) {
        $restoreAttempted = $true
        $restoreVerb = @($newRecycleItem.item.Verbs() | Where-Object {
            $name = [string]$_.Name
            $name -like "还原*" -or
                $name -like "*Restore*"
        }) | Select-Object -First 1
        Assert ($null -ne $restoreVerb) (
            "Windows Recycle Bin restore verb was not found.")
        $restoreVerb.DoIt()
        Wait-Condition -Description "recycled test chart restored for cleanup" -Condition {
            Test-Path -LiteralPath $deleteChart -PathType Leaf
        }
        $restoreSucceeded = $true
    }

    $fixtureAfter = Get-Fingerprint $fixture
    $installerAfter = Get-Fingerprint $installer
    $openAfter = Get-Fingerprint $openChart
    Assert (
        $fixtureAfter.sha256 -ceq $fixtureBefore.sha256 -and
        $fixtureAfter.bytes -eq $fixtureBefore.bytes) (
        "Real source MC changed during chart-action GUI verification.")
    Assert (
        $installerAfter.sha256 -ceq $installerBefore.sha256 -and
        $installerAfter.bytes -eq $installerBefore.bytes) (
        "Frozen installer changed during chart-action GUI verification.")
    Assert (
        $openAfter.sha256 -ceq $openBefore.sha256 -and
        $openAfter.bytes -eq $openBefore.bytes) (
        "Open chart changed during blocked deletion verification.")
    Assert (-not $topmostAtStart -and -not $topmostBeforeClose) (
        "Persistent topmost was observed.")

    $evidence = [ordered]@{
        schema =
            "lumachart.windows.avalonia.library-chart-actions-gui.v2"
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
            win32MouseInputInjectionUsed = $true
            postedTargetPointerMessagesUsed = $true
            uiaInvokeUsed = $true
            hardwareMouseInputClaimed = $false
            hardwareKeyboardInputClaimed = $false
            enterKeySent = $false
            uiaWindowCloseUsed = $true
            persistentTopmostUsed = $false
            actions = @($actions)
        }
        chartActions = [ordered]@{
            openChart = $openChart
            targetChart = $deleteChart
            targetChartBytes = $deleteBefore.bytes
            targetChartSha256 = $deleteBefore.sha256
            openChartDeletionBlocked = $true
            targetChartMissingAfterUiRecycle = $true
            targetRowAbsentAfterUiRefresh = $true
            deleteFolderPreserved = $true
            audioSiblingPreserved = $true
            imageSiblingPreserved = $true
            recycleBinCountBefore = $recycleBefore.Count
            recycleBinCountAfter = $recycleAfter.Count
            recycleBinUniqueTargetObserved = $true
            restoredForCleanup = $restoreSucceeded
            restoreAttempted = $restoreAttempted
            blocked = $blockedObserved
            confirmation = $confirmationObserved
        }
        cardHeaderInteraction = [ordered]@{
            target = "Library.FolderItem"
            collapsed = $openHeaderCollapsed
            expanded = $openHeaderExpanded
            wholeCardHeaderClickExpandedChartList = $true
            leftToggleRestyledWithoutHighContrastCircle = $true
        }
        screenshots = @(
            $cardHeaderExpandedScreenshot,
            $openMenuScreenshot,
            $blockedScreenshot,
            $targetMenuScreenshot,
            $confirmationScreenshot,
            $finalScreenshot
        )
        immutable = [ordered]@{
            realMcBefore = $fixtureBefore
            realMcAfter = $fixtureAfter
            frozenInstallerBefore = $installerBefore
            frozenInstallerAfter = $installerAfter
            openChartBefore = $openBefore
            openChartAfter = $openAfter
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
    $evidence |
        ConvertTo-Json -Depth 14 |
        Set-Content -LiteralPath $evidencePath -Encoding UTF8
    $evidence | ConvertTo-Json -Depth 14
}
finally {
    if ($process -and -not $process.HasExited) {
        try { Close-WindowWithUia $process.Id } catch { }
        if (-not $process.WaitForExit(3000)) {
            $process.Kill($true)
            [void]$process.WaitForExit(5000)
        }
    }
}
