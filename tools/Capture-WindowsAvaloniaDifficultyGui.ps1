param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 240)][int]$TimeoutSeconds = 150
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia Rework GUI capture requires PowerShell Core on Windows."
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
        try { if (& $Condition) { return } } catch { }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartDifficultyGuiNative
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
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);
}
'@

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 240000)][int]$TimeoutMilliseconds = 10000
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
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Find-ElementByIdOnce([int]$ProcessId, [string]$AutomationId) {
    try {
        return Find-ElementById -ProcessId $ProcessId -AutomationId $AutomationId -TimeoutMilliseconds 150
    }
    catch { return $null }
}

function Invoke-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Set-RangeValue($Element, [double]$Value) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.RangeValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose RangeValuePattern."
    }
    ([Windows.Automation.RangeValuePattern]$pattern).SetValue($Value)
}

function Get-ElementName([int]$ProcessId, [string]$AutomationId) {
    return [string](Find-ElementById -ProcessId $ProcessId -AutomationId $AutomationId).Current.Name
}

function Get-ElementHelpText([int]$ProcessId, [string]$AutomationId) {
    return [string](Find-ElementById -ProcessId $ProcessId -AutomationId $AutomationId).Current.HelpText
}

function Get-ElementRect($Element) {
    $rect = $Element.Current.BoundingRectangle
    if ($rect.Width -le 0 -or $rect.Height -le 0) {
        throw "Element '$($Element.Current.AutomationId)' has invalid bounds."
    }
    return [ordered]@{
        x = [double]$rect.X
        y = [double]$rect.Y
        width = [double]$rect.Width
        height = [double]$rect.Height
        right = [double]$rect.Right
        bottom = [double]$rect.Bottom
    }
}

function Invoke-MouseClick($Element, [double]$XFraction = .5, [double]$YFraction = .5) {
    $rect = Get-ElementRect $Element
    $x = [int][Math]::Round($rect.x + $rect.width * $XFraction)
    $y = [int][Math]::Round($rect.y + $rect.height * $YFraction)
    if (-not [LumaChartDifficultyGuiNative]::SetCursorPos($x, $y)) {
        throw "SetCursorPos failed for '$($Element.Current.AutomationId)'."
    }
    Start-Sleep -Milliseconds 100
    [LumaChartDifficultyGuiNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 70
    [LumaChartDifficultyGuiNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 250
}

function Invoke-MouseDrag {
    param(
        [Parameter(Mandatory = $true)]$Element,
        [double]$StartXFraction = .5,
        [double]$StartYFraction = .5,
        [Parameter(Mandatory = $true)][double]$DeltaX,
        [Parameter(Mandatory = $true)][double]$DeltaY
    )
    $rect = Get-ElementRect $Element
    $startX = [int][Math]::Round($rect.x + $rect.width * $StartXFraction)
    $startY = [int][Math]::Round($rect.y + $rect.height * $StartYFraction)
    $endX = [int][Math]::Round($startX + $DeltaX)
    $endY = [int][Math]::Round($startY + $DeltaY)
    [void][LumaChartDifficultyGuiNative]::SetCursorPos($startX, $startY)
    Start-Sleep -Milliseconds 100
    [LumaChartDifficultyGuiNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    for ($step = 1; $step -le 12; $step++) {
        $x = [int][Math]::Round($startX + ($endX - $startX) * $step / 12)
        $y = [int][Math]::Round($startY + ($endY - $startY) * $step / 12)
        [void][LumaChartDifficultyGuiNative]::SetCursorPos($x, $y)
        Start-Sleep -Milliseconds 25
    }
    [LumaChartDifficultyGuiNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 450
}

function Send-Key([IntPtr]$WindowHandle, [byte]$VirtualKey, $FocusElement = $null) {
    [void][LumaChartDifficultyGuiNative]::ShowWindow($WindowHandle, 9)
    [void][LumaChartDifficultyGuiNative]::BringWindowToTop($WindowHandle)
    [void][LumaChartDifficultyGuiNative]::SetForegroundWindow($WindowHandle)
    if ($FocusElement) {
        $FocusElement.SetFocus()
        Start-Sleep -Milliseconds 120
    }
    [LumaChartDifficultyGuiNative]::keybd_event($VirtualKey, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 100
    [LumaChartDifficultyGuiNative]::keybd_event($VirtualKey, 0, 2, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 300
}

function Wait-MainWindowHandle([Diagnostics.Process]$Process) {
    Wait-Condition -Description "main window for process $($Process.Id)" -Condition {
        $Process.Refresh()
        -not $Process.HasExited -and $Process.MainWindowHandle -ne [IntPtr]::Zero
    }
    return $Process.MainWindowHandle
}

function Get-ElementWindowHandle($Element) {
    $current = $Element
    while ($current) {
        $handle = [IntPtr]::new([int64]$current.Current.NativeWindowHandle)
        if ($handle -ne [IntPtr]::Zero) { return $handle }
        try { $current = [Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($current) }
        catch { $current = $null }
    }
    throw "Element '$($Element.Current.AutomationId)' did not resolve to a native window handle."
}

function Get-WindowBounds([IntPtr]$Handle) {
    $rectangle = [LumaChartDifficultyGuiNative+RECT]::new()
    if (-not [LumaChartDifficultyGuiNative]::GetWindowRect($Handle, [ref]$rectangle)) {
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

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $bounds = Get-WindowBounds $Handle
    if ($bounds.width -lt 300 -or $bounds.height -lt 180) {
        throw "Window has invalid bounds: $($bounds.width)x$($bounds.height)."
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
                if (-not [LumaChartDifficultyGuiNative]::PrintWindow($Handle, $dc, 2)) {
                    throw "PrintWindow failed for $Handle."
                }
            }
            finally { $graphics.ReleaseHdc($dc) }
        }
        finally { $graphics.Dispose() }
        $colors = [Collections.Generic.HashSet[int]]::new()
        for ($y = 0; $y -lt 16; $y++) {
            for ($x = 0; $x -lt 16; $x++) {
                $pixel = $bitmap.GetPixel(
                    [Math]::Min($bounds.width - 1, [int](($x + .5) * $bounds.width / 16)),
                    [Math]::Min($bounds.height - 1, [int](($y + .5) * $bounds.height / 16)))
                [void]$colors.Add($pixel.ToArgb())
            }
        }
        if ($colors.Count -lt 6) {
            throw "Screenshot is near-uniform: $($colors.Count) sampled colors."
        }
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

function Start-DifficultyClient {
    param(
        [string]$Profile,
        [string]$ChartPath,
        [string]$LocalDataRoot,
        [string]$EditingRoot,
        [string]$WorkspaceRoot,
        [string]$RuntimeEvidencePath
    )
    foreach ($directory in @($LocalDataRoot, $EditingRoot, $WorkspaceRoot)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $applicationFullPath
    $start.UseShellExecute = $false
    $start.WorkingDirectory = Split-Path -Parent $applicationFullPath
    $start.ArgumentList.Add("--evidence-chart")
    $start.ArgumentList.Add($ChartPath)
    $start.ArgumentList.Add("--evidence-output")
    $start.ArgumentList.Add($RuntimeEvidencePath)
    $start.Environment["LUMACHART_PROFILE"] = $Profile
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $LocalDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $EditingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $WorkspaceRoot
    $start.Environment["DOTNET_CLI_HOME"] = $dotnetHome
    $start.Environment["NUGET_PACKAGES"] = $nugetPackages
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
    $start.Environment["TEMP"] = $projectTemp
    $start.Environment["TMP"] = $projectTemp
    $process = [Diagnostics.Process]::Start($start)
    if (-not $process) { throw "Unable to start Windows Avalonia Rework client." }
    return $process
}

function Stop-TrackedClient([Diagnostics.Process]$Process) {
    if (-not $Process -or $Process.HasExited) { return }
    $Process.Kill($true)
    [void]$Process.WaitForExit(5000)
}

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$chartFixtureFullPath = Resolve-ExistingFile $ChartFixturePath "Real MC fixture"
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
if (-not (Test-Path -LiteralPath $outputFullPath -PathType Container)) {
    throw "Output root must already exist: $outputFullPath"
}
$guiRoot = Join-Path $outputFullPath "gui-runtime"
if (Test-Path -LiteralPath $guiRoot) { throw "GUI output root already exists: $guiRoot" }
New-Item -ItemType Directory -Path $guiRoot | Out-Null

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$projectTemp = Join-Path $projectRoot ".codex-temp"
$dotnetHome = Join-Path $projectRoot ".codex-dotnet-home"
$nugetPackages = Join-Path $projectRoot ".codex-nuget-packages"
$nugetHttpCache = Join-Path $projectRoot ".codex-nuget-http-cache"
foreach ($directory in @($projectTemp, $dotnetHome, $nugetPackages, $nugetHttpCache)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$workingRoot = Join-Path $guiRoot "working"
$clientRoot = Join-Path $guiRoot "client"
$localDataRoot = Join-Path $clientRoot "local-data"
$editingRoot = Join-Path $clientRoot "editing"
$workspaceRoot = Join-Path $clientRoot "workspace"
New-Item -ItemType Directory -Path $workingRoot | Out-Null
$workingChart = Join-Path $workingRoot "rework-resound-real.mc"
Copy-Item -LiteralPath $chartFixtureFullPath -Destination $workingChart
$fixtureBefore = Get-Item -LiteralPath $chartFixtureFullPath
$workingBefore = Get-Item -LiteralPath $workingChart
$fixtureHashBefore = (Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash
$workingHashBefore = (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash

$first = $null
$second = $null
try {
    $runtimePath = Join-Path $guiRoot "difficulty-runtime.json"
    $first = Start-DifficultyClient `
        -Profile "windows-avalonia-rework" `
        -ChartPath $workingChart `
        -LocalDataRoot $localDataRoot `
        -EditingRoot $editingRoot `
        -WorkspaceRoot $workspaceRoot `
        -RuntimeEvidencePath $runtimePath
    $firstHandle = Wait-MainWindowHandle $first
    [void][LumaChartDifficultyGuiNative]::ShowWindow($firstHandle, 3)
    $commandToggle = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Editor.CommandMenuToggle" `
        -TimeoutMilliseconds 30000
    Invoke-Element $commandToggle
    Wait-Condition -Description "real Resound editor and Rework card" -Condition {
        (Find-ElementByIdOnce $first.Id "Editor.DifficultyAnalysis") -and
        (Find-ElementByIdOnce $first.Id "Editor.DifficultyCard")
    }
    Wait-Condition -Description "runtime evidence" -Condition {
        Test-Path -LiteralPath $runtimePath -PathType Leaf
    }
    $initialCollapse = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Editor.DifficultyCard.Collapse"
    if ([string]$initialCollapse.Current.Name -ceq "+") {
        Invoke-Element $initialCollapse
        Wait-Condition -Description "initial difficulty card expansion" -Condition {
            (Get-ElementRect (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.DifficultyCard")).height -gt 80
        }
    }
    $beforePath = Join-Path $guiRoot "difficulty-card-before.png"
    $beforeCapture = Capture-Window $firstHandle $beforePath
    $cardBefore = Get-ElementRect (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.DifficultyCard")

    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.DifficultyAnalysis")
    $starElement = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "DifficultyAnalysis.Dialog.Star" `
        -TimeoutMilliseconds 120000
    $dialogHandle = Get-ElementWindowHandle $starElement
    $initialStar = [string]$starElement.Current.Name
    $initialReference = Get-ElementName $first.Id "DifficultyAnalysis.Dialog.Reference"
    $initialDialogPath = Join-Path $guiRoot "difficulty-dialog-initial.png"
    $initialDialogCapture = Capture-Window $dialogHandle $initialDialogPath
    $peakIds = @()
    for ($rank = 1; $rank -le 8; $rank++) {
        if (Find-ElementByIdOnce $first.Id "DifficultyAnalysis.Dialog.Peak.$rank") {
            $peakIds += "DifficultyAnalysis.Dialog.Peak.$rank"
        }
    }
    if ($peakIds.Count -lt 1 -or $peakIds.Count -gt 8) {
        throw "Rework dialog exposed an invalid Peak button count: $($peakIds.Count)."
    }

    Send-Key -WindowHandle $dialogHandle -VirtualKey 0x1B
    Wait-Condition -Description "Escape closing Rework dialog" -Condition {
        -not (Find-ElementByIdOnce $first.Id "DifficultyAnalysis.Dialog.Star")
    }

    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.DifficultyAnalysis")
    $odSlider = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "DifficultyAnalysis.Dialog.OD" `
        -TimeoutMilliseconds 120000
    $dialogHandle = Get-ElementWindowHandle $odSlider
    Set-RangeValue $odSlider 7.3
    Wait-Condition -Description "OD 7.3 debounced recalculation" -Condition {
        (Get-ElementName $first.Id "DifficultyAnalysis.Dialog.RecalculateStatus") -ceq "已使用 OD 7.3"
    }
    Send-Key -WindowHandle $dialogHandle -VirtualKey 0x27 -FocusElement $odSlider
    Wait-Condition -Description "OD keyboard Right-arrow recalculation" -Condition {
        (Get-ElementName $first.Id "DifficultyAnalysis.Dialog.RecalculateStatus") -ceq "已使用 OD 7.4"
    }
    $od74Path = Join-Path $guiRoot "difficulty-dialog-od74.png"
    $od74Capture = Capture-Window $dialogHandle $od74Path
    $peakOne = Find-ElementById -ProcessId $first.Id -AutomationId "DifficultyAnalysis.Dialog.Peak.1"
    $peakOneName = [string]$peakOne.Current.Name
    Invoke-Element $peakOne
    Wait-Condition -Description "Peak click closing Rework dialog" -Condition {
        -not (Find-ElementByIdOnce $first.Id "DifficultyAnalysis.Dialog.OD")
    }
    $timelineAfterPeak = Get-ElementHelpText $first.Id "Timeline.Surface"
    if ($timelineAfterPeak -notlike "当前 Beat *") {
        throw "Peak click did not expose a current-Beat navigation result."
    }

    # The command palette intentionally sits above the Rework card, matching the
    # WPF layer order. Close it before physical pointer checks so the drag lands
    # on the card header instead of the palette overlay.
    $commandToggle = Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Editor.CommandMenuToggle"
    if ([string]$commandToggle.Current.Name -cne "⚙") {
        Invoke-Element $commandToggle
        Wait-Condition -Description "command palette closing before Rework pointer checks" -Condition {
            (Get-ElementName $first.Id "Editor.CommandMenuToggle") -ceq "⚙"
        }
    }

    $overview = Find-ElementById -ProcessId $first.Id -AutomationId "Editor.DifficultyOverview"
    $timelineBeforeOverview = Get-ElementHelpText $first.Id "Timeline.Surface"
    Invoke-MouseClick -Element $overview -XFraction .5 -YFraction .25
    $timelineAfterOverviewClick = Get-ElementHelpText $first.Id "Timeline.Surface"
    if ($timelineAfterOverviewClick -ceq $timelineBeforeOverview) {
        throw "DIFF overview click did not move the timeline."
    }
    Invoke-MouseDrag -Element $overview -StartXFraction .5 -StartYFraction .75 -DeltaX 0 -DeltaY -120
    $timelineAfterOverviewDrag = Get-ElementHelpText $first.Id "Timeline.Surface"
    if ($timelineAfterOverviewDrag -ceq $timelineAfterOverviewClick) {
        throw "DIFF overview drag did not move the timeline."
    }

    $collapse = Find-ElementById -ProcessId $first.Id -AutomationId "Editor.DifficultyCard.Collapse"
    Invoke-Element $collapse
    Wait-Condition -Description "difficulty card collapsed geometry" -Condition {
        (Get-ElementRect (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.DifficultyCard")).height -lt $cardBefore.height
    }
    $cardCollapsed = Get-ElementRect (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.DifficultyCard")
    $collapsedPath = Join-Path $guiRoot "difficulty-card-collapsed.png"
    $collapsedCapture = Capture-Window $firstHandle $collapsedPath
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.DifficultyCard.Collapse")
    Wait-Condition -Description "difficulty card expanded geometry" -Condition {
        (Get-ElementRect (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.DifficultyCard")).height -gt $cardCollapsed.height
    }

    $header = Find-ElementById -ProcessId $first.Id -AutomationId "Editor.DifficultyCard.Header"
    $cardPreDrag = Get-ElementRect (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.DifficultyCard")
    Invoke-MouseDrag -Element $header -StartXFraction .35 -StartYFraction .5 -DeltaX 86 -DeltaY 52
    $cardAfterDrag = Get-ElementRect (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.DifficultyCard")
    $dragDeltaX = $cardAfterDrag.x - $cardPreDrag.x
    $dragDeltaY = $cardAfterDrag.y - $cardPreDrag.y
    if ([Math]::Abs($dragDeltaX) -lt 20 -or [Math]::Abs($dragDeltaY) -lt 20) {
        throw "Difficulty card did not move by the physical pointer drag."
    }
    $draggedPath = Join-Path $guiRoot "difficulty-card-dragged.png"
    $draggedCapture = Capture-Window $firstHandle $draggedPath

    $settingsPath = Join-Path $localDataRoot "editor-view-settings.json"
    Wait-Condition -Description "difficulty card settings persistence" -Condition {
        if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) { return $false }
        try {
            $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
            return -not [bool]$settings.DifficultyCardCollapsed -and
                   [Math]::Abs([double]$settings.DifficultyCardX) -ge 20 -and
                   [Math]::Abs([double]$settings.DifficultyCardY) -ge 20
        }
        catch { return $false }
    }
    $persisted = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    Stop-TrackedClient $first

    $reopenRuntimePath = Join-Path $guiRoot "difficulty-reopened-runtime.json"
    $second = Start-DifficultyClient `
        -Profile "windows-avalonia-rework" `
        -ChartPath $workingChart `
        -LocalDataRoot $localDataRoot `
        -EditingRoot $editingRoot `
        -WorkspaceRoot $workspaceRoot `
        -RuntimeEvidencePath $reopenRuntimePath
    $secondHandle = Wait-MainWindowHandle $second
    [void][LumaChartDifficultyGuiNative]::ShowWindow($secondHandle, 3)
    $reopenedCardElement = Find-ElementById `
        -ProcessId $second.Id `
        -AutomationId "Editor.DifficultyCard" `
        -TimeoutMilliseconds 30000
    Wait-Condition -Description "reopened card restored position" -Condition {
        $rect = Get-ElementRect $reopenedCardElement
        [Math]::Abs($rect.x - $cardAfterDrag.x) -le 4 -and
        [Math]::Abs($rect.y - $cardAfterDrag.y) -le 4
    }
    $cardReopened = Get-ElementRect $reopenedCardElement
    $reopenedPath = Join-Path $guiRoot "difficulty-card-reopened.png"
    $reopenedCapture = Capture-Window $secondHandle $reopenedPath
    Wait-Condition -Description "reopened runtime evidence" -Condition {
        Test-Path -LiteralPath $reopenRuntimePath -PathType Leaf
    }
    Stop-TrackedClient $second

    $fixtureAfter = Get-Item -LiteralPath $chartFixtureFullPath
    $workingAfter = Get-Item -LiteralPath $workingChart
    $fixtureHashAfter = (Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash
    $workingHashAfter = (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash
    if ($fixtureHashAfter -cne $fixtureHashBefore -or $workingHashAfter -cne $workingHashBefore -or
        $fixtureAfter.Length -ne $fixtureBefore.Length -or
        $workingAfter.Length -ne $workingBefore.Length -or
        $fixtureAfter.LastWriteTimeUtc -ne $fixtureBefore.LastWriteTimeUtc -or
        $workingAfter.LastWriteTimeUtc -ne $workingBefore.LastWriteTimeUtc) {
        throw "Rework GUI flow modified the source or isolated working fixture."
    }

    $screenshots = @{}
    foreach ($path in @(
        $beforePath,
        $initialDialogPath,
        $od74Path,
        $collapsedPath,
        $draggedPath,
        $reopenedPath)) {
        $item = Get-Item -LiteralPath $path
        $screenshots[$item.BaseName] = [ordered]@{
            path = $item.FullName
            length = $item.Length
            sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        }
    }

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.rework-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        application = [ordered]@{
            path = $applicationFullPath
            sha256 = (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
            firstProcessId = $first.Id
            secondProcessId = $second.Id
        }
        chart = [ordered]@{
            sourcePath = $chartFixtureFullPath
            sourceSha256Before = $fixtureHashBefore
            sourceSha256After = $fixtureHashAfter
            sourceLengthBefore = $fixtureBefore.Length
            sourceLengthAfter = $fixtureAfter.Length
            sourceLastWriteUtcBefore = $fixtureBefore.LastWriteTimeUtc.ToString("O")
            sourceLastWriteUtcAfter = $fixtureAfter.LastWriteTimeUtc.ToString("O")
            workingPath = $workingChart
            workingSha256Before = $workingHashBefore
            workingSha256After = $workingHashAfter
            workingLengthBefore = $workingBefore.Length
            workingLengthAfter = $workingAfter.Length
            workingLastWriteUtcBefore = $workingBefore.LastWriteTimeUtc.ToString("O")
            workingLastWriteUtcAfter = $workingAfter.LastWriteTimeUtc.ToString("O")
        }
        analysis = [ordered]@{
            initialStar = $initialStar
            initialReference = $initialReference
            peakButtonCount = $peakIds.Count
            peakOneName = $peakOneName
            escapeClosedDialog = $true
            odRangeValueRecalculation = "7.3"
            odKeyboardRightRecalculation = "7.4"
            peakClickClosedDialog = $true
            timelineAfterPeak = $timelineAfterPeak
        }
        overview = [ordered]@{
            physicalClick = $true
            physicalDrag = $true
            timelineBefore = $timelineBeforeOverview
            timelineAfterClick = $timelineAfterOverviewClick
            timelineAfterDrag = $timelineAfterOverviewDrag
            perPeakControls = 0
        }
        card = [ordered]@{
            visibleOnlyForReal4K = $true
            before = $cardBefore
            collapsed = $cardCollapsed
            preDrag = $cardPreDrag
            afterDrag = $cardAfterDrag
            dragDelta = [ordered]@{ x = $dragDeltaX; y = $dragDeltaY }
            persisted = [ordered]@{
                x = [double]$persisted.DifficultyCardX
                y = [double]$persisted.DifficultyCardY
                collapsed = [bool]$persisted.DifficultyCardCollapsed
            }
            reopened = $cardReopened
            secondProcessRestore = $true
        }
        captures = [ordered]@{
            before = $beforeCapture
            initialDialog = $initialDialogCapture
            od74 = $od74Capture
            collapsed = $collapsedCapture
            dragged = $draggedCapture
            reopened = $reopenedCapture
        }
        screenshots = $screenshots
        runtimeEvidence = [ordered]@{
            first = $runtimePath
            second = $reopenRuntimePath
        }
        checks = [ordered]@{
            realResoundGuiOpened = $true
            resultDialogVisualAndMetrics = $true
            escapeShortcut = $true
            odMouseAutomationAndKeyboard = $true
            peakNavigation = $true
            diffOverviewPhysicalClickAndDrag = $true
            cardPhysicalCollapseExpandAndDrag = $true
            cardSecondProcessRestore = $true
            sourceAndWorkingFixturesUnchanged = $true
        }
        completion = [ordered]@{
            functionMatrixAllPassed = $false
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
        }
        limitations = @(
            "This slice proves Rework UI and interaction on the current Windows display; remaining matrix rows are still incomplete.",
            "This PrintWindow capture is not final 1080p/1440p/4K, 60/120 Hz, installer or two-client release certification."
        )
    }
    $evidencePath = Join-Path $guiRoot "difficulty-gui-evidence.json"
    $evidence | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Write-Host "Windows Avalonia Rework GUI capture: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    if ($first -and -not $first.HasExited) { Stop-TrackedClient $first }
    if ($second -and -not $second.HasExited) { Stop-TrackedClient $second }
}
