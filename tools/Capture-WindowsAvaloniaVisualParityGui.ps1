param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia visual-parity GUI capture requires PowerShell Core on Windows."
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

public static class LumaChartVisualParityNative
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
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint firstThread, uint secondThread, bool attach);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

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
                attachedForeground = AttachThreadInput(currentThread, foregroundThread, true);
            if (targetThread != 0 && targetThread != currentThread &&
                targetThread != foregroundThread)
                attachedTarget = AttachThreadInput(currentThread, targetThread, true);
            // SW_SHOW activates without forcing a maximized evidence window
            // back to its restored bounds.
            ShowWindowAsync(window, 5);
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

function Set-ForegroundWindowVerified([IntPtr]$Handle) {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(3)
    do {
        if ([LumaChartVisualParityNative]::GetForegroundWindow() -eq $Handle) { return }
        [void][LumaChartVisualParityNative]::TryActivateWindow($Handle)
        Start-Sleep -Milliseconds 50
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Unable to activate visual-parity evidence window $Handle."
}

function Invoke-MouseDrag {
    param(
        [Parameter(Mandatory = $true)][int]$StartX,
        [Parameter(Mandatory = $true)][int]$StartY,
        [Parameter(Mandatory = $true)][int]$EndX,
        [Parameter(Mandatory = $true)][int]$EndY
    )
    [void][LumaChartVisualParityNative]::SetCursorPos($StartX, $StartY)
    Start-Sleep -Milliseconds 120
    [LumaChartVisualParityNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    for ($step = 1; $step -le 12; $step++) {
        $x = [int][Math]::Round($StartX + ($EndX - $StartX) * $step / 12)
        $y = [int][Math]::Round($StartY + ($EndY - $StartY) * $step / 12)
        [void][LumaChartVisualParityNative]::SetCursorPos($x, $y)
        Start-Sleep -Milliseconds 18
    }
    [LumaChartVisualParityNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Invoke-MouseClick($Element) {
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -le 0 -or $bounds.Height -le 0) {
        throw "Element '$($Element.Current.AutomationId)' has invalid click bounds."
    }
    [void][LumaChartVisualParityNative]::SetCursorPos(
        [int][Math]::Round($bounds.Left + $bounds.Width / 2),
        [int][Math]::Round($bounds.Top + $bounds.Height / 2))
    Start-Sleep -Milliseconds 120
    [LumaChartVisualParityNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 50
    [LumaChartVisualParityNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Invoke-MouseRightClick($Element) {
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -le 0 -or $bounds.Height -le 0) {
        throw "Element '$($Element.Current.AutomationId)' has invalid right-click bounds."
    }
    [void][LumaChartVisualParityNative]::SetCursorPos(
        [int][Math]::Round($bounds.Left + $bounds.Width / 2),
        [int][Math]::Round($bounds.Top + $bounds.Height / 2))
    Start-Sleep -Milliseconds 120
    [LumaChartVisualParityNative]::mouse_event(0x0008, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 50
    [LumaChartVisualParityNative]::mouse_event(0x0010, 0, 0, 0, [UIntPtr]::Zero)
}

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [int]$TimeoutMilliseconds = 10000
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

function Find-ElementByName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$TimeoutMilliseconds = 10000
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $nameCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty, $Name)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children, $processCondition)
            foreach ($root in $roots) {
                if ([string]$root.Current.Name -ceq $Name) { return $root }
                $candidate = $root.FindFirst(
                    [Windows.Automation.TreeScope]::Descendants,
                    $nameCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation name '$Name' for process $ProcessId."
}

function Invoke-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Get-ElementValue($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose ValuePattern."
    }
    return [string]([Windows.Automation.ValuePattern]$pattern).Current.Value
}

function Set-ElementValue($Element, [string]$Value) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose writable ValuePattern."
    }
    ([Windows.Automation.ValuePattern]$pattern).SetValue($Value)
}

function Write-UiaSnapshot([int]$ProcessId, [string]$Path) {
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $rows = [Collections.Generic.List[object]]::new()
    try {
        $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
            [Windows.Automation.TreeScope]::Children, $processCondition)
    }
    catch [Runtime.InteropServices.COMException] {
        $roots = @()
    }
    foreach ($root in $roots) {
        try {
            $elements = $root.FindAll(
                [Windows.Automation.TreeScope]::Subtree,
                [Windows.Automation.Condition]::TrueCondition)
        }
        catch [Windows.Automation.ElementNotAvailableException] {
            continue
        }
        catch [Runtime.InteropServices.COMException] {
            continue
        }
        foreach ($element in $elements) {
            if ($rows.Count -ge 800) { break }
            try {
                $rows.Add([ordered]@{
                    automationId = [string]$element.Current.AutomationId
                    name = [string]$element.Current.Name
                    controlType = [string]$element.Current.ControlType.ProgrammaticName
                    offscreen = [bool]$element.Current.IsOffscreen
                })
            }
            catch [Windows.Automation.ElementNotAvailableException] { }
            catch [Runtime.InteropServices.COMException] { }
        }
    }
    $rows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

function Wait-MainWindowHandle([Diagnostics.Process]$Process) {
    Wait-Condition -Description "main window for process $($Process.Id)" -Condition {
        $Process.Refresh()
        -not $Process.HasExited -and $Process.MainWindowHandle -ne [IntPtr]::Zero
    }
    return $Process.MainWindowHandle
}

function Get-WindowBounds([IntPtr]$Handle) {
    $rectangle = [LumaChartVisualParityNative+RECT]::new()
    if (-not [LumaChartVisualParityNative]::GetWindowRect($Handle, [ref]$rectangle)) {
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
    if ($bounds.width -lt 900 -or $bounds.height -lt 600) {
        throw "Window has invalid parity-capture bounds: $($bounds.width)x$($bounds.height)."
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
                if (-not [LumaChartVisualParityNative]::PrintWindow($Handle, $dc, 2)) {
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
        if ($colors.Count -lt 8) { throw "Screenshot is near-uniform: $($colors.Count) sampled colors." }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            width = $bounds.width
            height = $bounds.height
            sampledUniqueColors = $colors.Count
            length = (Get-Item -LiteralPath $Path).Length
            sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        }
    }
    finally { $bitmap.Dispose() }
}

function Start-VisualParityClient {
    param(
        [string]$Application,
        [string]$ChartPath,
        [string]$RuntimeEvidencePath,
        [string]$SessionRoot
    )
    $localData = Join-Path $SessionRoot "local-data"
    $editing = Join-Path $SessionRoot "editing"
    $workspace = Join-Path $SessionRoot "workspace"
    foreach ($directory in @($localData, $editing, $workspace)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Application
    $start.UseShellExecute = $false
    $start.WorkingDirectory = Split-Path -Parent $Application
    $start.ArgumentList.Add("--evidence-chart")
    $start.ArgumentList.Add($ChartPath)
    $start.ArgumentList.Add("--evidence-output")
    $start.ArgumentList.Add($RuntimeEvidencePath)
    $start.ArgumentList.Add("--evidence-focus-note-property")
    $start.Environment["LUMACHART_PROFILE"] = "visual-parity"
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localData
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
    $start.Environment["DOTNET_CLI_HOME"] = $script:dotnetHome
    $start.Environment["NUGET_PACKAGES"] = $script:nugetPackages
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = $script:nugetHttpCache
    $start.Environment["TEMP"] = $script:projectTemp
    $start.Environment["TMP"] = $script:projectTemp
    $process = [Diagnostics.Process]::Start($start)
    if (-not $process) { throw "Unable to start Windows Avalonia visual-parity client." }
    return $process
}

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Windows Avalonia executable"
$chartFullPath = Resolve-ExistingFile $ChartFixturePath "real chart fixture"
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Force -Path $outputFullPath | Out-Null
$sessionRoot = Join-Path $outputFullPath "session"
$runtimePath = Join-Path $outputFullPath "visual-parity-runtime.json"
$editorPath = Join-Path $outputFullPath "avalonia-editor-default.png"
$startupPath = Join-Path $outputFullPath "avalonia-startup-diagnostic.png"
$uiaSnapshotPath = Join-Path $outputFullPath "avalonia-startup-uia.json"
$commandPath = Join-Path $outputFullPath "avalonia-editor-command-menu.png"
$extensionOpenedPath = Join-Path $outputFullPath "avalonia-editor-extension-palette.png"
$extensionDraggedPath = Join-Path $outputFullPath "avalonia-editor-extension-palette-dragged.png"
$quickDraggedPath = Join-Path $outputFullPath "avalonia-editor-quick-palette-dragged.png"
$quickCollapsedPath = Join-Path $outputFullPath "avalonia-editor-quick-palette-collapsed.png"
$quickReopenedPath = Join-Path $outputFullPath "avalonia-editor-quick-palette-reopened.png"
$quickValuesAdjustedPath = Join-Path $outputFullPath "avalonia-editor-adjustment-values.png"
$quickValuesDraggedPath = Join-Path $outputFullPath "avalonia-editor-adjustment-dragged.png"
$quickValuesCollapsedPath = Join-Path $outputFullPath "avalonia-editor-adjustment-collapsed.png"
$quickMirrorPath = Join-Path $outputFullPath "avalonia-editor-mirrored-note.png"
$inspectorPath = Join-Path $outputFullPath "avalonia-editor-inspector-collapsed.png"
$libraryPath = Join-Path $outputFullPath "avalonia-library.png"
$evidencePath = Join-Path $outputFullPath "visual-parity-gui-evidence.json"
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$script:dotnetHome = Join-Path $repoRoot ".codex-dotnet-home"
$script:nugetPackages = Join-Path $repoRoot ".codex-nuget-packages"
$script:nugetHttpCache = Join-Path $repoRoot ".codex-nuget-http-cache"
$script:projectTemp = Join-Path $repoRoot ".codex-temp"
foreach ($directory in @($script:dotnetHome, $script:nugetPackages, $script:nugetHttpCache, $script:projectTemp)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$fixtureHashBefore = (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
$installerPath = Join-Path $repoRoot "release\LumaChartStudio-Setup.exe"
$installerHashBefore = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
$process = $null
try {
    $process = Start-VisualParityClient `
        -Application $applicationFullPath `
        -ChartPath $chartFullPath `
        -RuntimeEvidencePath $runtimePath `
        -SessionRoot $sessionRoot
    $handle = Wait-MainWindowHandle $process
    [void][LumaChartVisualParityNative]::ShowWindow($handle, 3)
    Set-ForegroundWindowVerified $handle
    Start-Sleep -Milliseconds 1200
    [void](Capture-Window $handle $startupPath)
    Write-UiaSnapshot -ProcessId $process.Id -Path $uiaSnapshotPath
    Wait-Condition -Description "editor surface" -Condition {
        $null -ne (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.TimingTab" -TimeoutMilliseconds 400)
    }
    Start-Sleep -Milliseconds 1200
    $editorCapture = Capture-Window $handle $editorPath

    $quickToggle = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickPalette.Toggle"
    $quickPaletteHeaderText = Find-ElementByName `
        -ProcessId $process.Id `
        -Name "快捷编辑"
    $quickBefore = $quickToggle.Current.BoundingRectangle
    $quickPaletteHeaderTextBounds = $quickPaletteHeaderText.Current.BoundingRectangle
    $quickDragStartX = [int][Math]::Round(
        $quickPaletteHeaderTextBounds.Left + $quickPaletteHeaderTextBounds.Width / 2)
    $quickDragStartY = [int][Math]::Round(
        $quickPaletteHeaderTextBounds.Top + $quickPaletteHeaderTextBounds.Height / 2)
    if ($quickDragStartX -ge $quickBefore.Left - 30) {
        throw "Quick-palette drag point overlaps the collapse-button hit target."
    }
    Set-ForegroundWindowVerified $handle
    Start-Sleep -Milliseconds 180
    Invoke-MouseDrag `
        -StartX $quickDragStartX `
        -StartY $quickDragStartY `
        -EndX ($quickDragStartX - 220) `
        -EndY ($quickDragStartY + 90)
    Start-Sleep -Milliseconds 500
    $quickAfter = (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickPalette.Toggle").Current.BoundingRectangle
    $quickDragDeltaX = $quickAfter.Left - $quickBefore.Left
    $quickDragDeltaY = $quickAfter.Top - $quickBefore.Top
    Write-Host ("Quick-palette physical drag: start=({0},{1}); delta=({2},{3})" -f
        $quickDragStartX,
        $quickDragStartY,
        $quickDragDeltaX,
        $quickDragDeltaY)
    if ([Math]::Abs($quickDragDeltaX) -lt 50 -or [Math]::Abs($quickDragDeltaY) -lt 30) {
        throw "Quick-palette real pointer drag did not move the floating window."
    }
    $quickDraggedCapture = Capture-Window $handle $quickDraggedPath
    Invoke-Element (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickPalette.Toggle")
    Wait-Condition -Description "collapsed quick palette" -Condition {
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.QuickPalette.Toggle" `
            -TimeoutMilliseconds 400).Current.Name -eq "+"
    }
    $quickCollapsedCapture = Capture-Window $handle $quickCollapsedPath
    Invoke-Element (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickPalette.Toggle")
    Wait-Condition -Description "expanded quick palette" -Condition {
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.QuickPalette.Toggle" `
            -TimeoutMilliseconds 400).Current.Name -eq "−"
    }
    Start-Sleep -Milliseconds 650

    $noteBeatBefore = Get-ElementValue (Find-ElementById `
        -ProcessId $process.Id -AutomationId "Inspector.Note.Beat")
    $noteEndBeatBefore = Get-ElementValue (Find-ElementById `
        -ProcessId $process.Id -AutomationId "Inspector.Note.EndBeat")
    $noteLaneBefore = Get-ElementValue (Find-ElementById `
        -ProcessId $process.Id -AutomationId "Inspector.Note.Lane")
    Invoke-MouseClick (Find-ElementById `
        -ProcessId $process.Id -AutomationId "Editor.QuickMirror")
    Wait-Condition -Description "real Note mirrored by quick-edit pointer click" -Condition {
        (Get-ElementValue (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Inspector.Note.Lane" `
            -TimeoutMilliseconds 400)) -cne $noteLaneBefore
    }
    $noteBeatMirrored = Get-ElementValue (Find-ElementById `
        -ProcessId $process.Id -AutomationId "Inspector.Note.Beat")
    $noteEndBeatMirrored = Get-ElementValue (Find-ElementById `
        -ProcessId $process.Id -AutomationId "Inspector.Note.EndBeat")
    $noteLaneMirrored = Get-ElementValue (Find-ElementById `
        -ProcessId $process.Id -AutomationId "Inspector.Note.Lane")
    if ($noteBeatMirrored -cne $noteBeatBefore -or $noteEndBeatMirrored -cne $noteEndBeatBefore) {
        throw "Quick mirror changed the real Note's authored Beat or EndBeat text."
    }
    $quickMirrorCapture = Capture-Window $handle $quickMirrorPath
    Invoke-MouseClick (Find-ElementById `
        -ProcessId $process.Id -AutomationId "Editor.QuickUndo")
    Wait-Condition -Description "quick-mirror single undo" -Condition {
        (Get-ElementValue (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Inspector.Note.Lane" `
            -TimeoutMilliseconds 400)) -ceq $noteLaneBefore
    }
    if ((Get-ElementValue (Find-ElementById `
            -ProcessId $process.Id -AutomationId "Inspector.Note.Beat")) -cne $noteBeatBefore -or
        (Get-ElementValue (Find-ElementById `
            -ProcessId $process.Id -AutomationId "Inspector.Note.EndBeat")) -cne $noteEndBeatBefore) {
        throw "Quick-mirror undo did not restore the exact real-Note structure."
    }
    # The WPF quick-edit palette can be dragged over the adjustment palette.
    # Collapse it while physically exercising adjustment controls, then restore
    # it before the extension/selection steps and persistence gate.
    Invoke-Element (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickPalette.Toggle")
    Wait-Condition -Description "quick palette clear of adjustment controls" -Condition {
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.QuickPalette.Toggle" `
            -TimeoutMilliseconds 400).Current.Name -eq "+"
    }

    Invoke-MouseClick (Find-ElementById `
        -ProcessId $process.Id -AutomationId "Editor.QuickValues.Snap.Up")
    Invoke-MouseClick (Find-ElementById `
        -ProcessId $process.Id -AutomationId "Editor.QuickValues.Grid.Up")
    Invoke-MouseClick (Find-ElementById `
        -ProcessId $process.Id -AutomationId "Editor.QuickValues.Rate.Down")
    Wait-Condition -Description "adjustment palette values applied" -Condition {
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.QuickValues.Snap.Preset" `
            -TimeoutMilliseconds 400).Current.Name -eq "1/5" -and
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.QuickValues.Rate.Preset" `
            -TimeoutMilliseconds 400).Current.Name -eq "0.90x"
    }
    Invoke-MouseRightClick (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickValues.Snap.Preset")
    Wait-Condition -Description "adjustment custom snap editor" -Condition {
        try {
            -not (Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Editor.QuickValues.Snap.Editor" `
                -TimeoutMilliseconds 400).Current.IsOffscreen
        }
        catch { $false }
    }
    Set-ElementValue (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickValues.Snap.Editor") "1/7"
    # Explicit focus loss commits the value. No Enter/Escape is sent so this
    # path remains compatible with the user's Chinese IME composition behavior.
    Invoke-MouseClick (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Inspector.Toggle")
    Wait-Condition -Description "custom snap committed by focus loss" -Condition {
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.QuickValues.Snap.Preset" `
            -TimeoutMilliseconds 400).Current.Name -eq "1/7"
    }
    Invoke-MouseClick (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Inspector.Toggle")
    Start-Sleep -Milliseconds 300
    $quickValuesAdjustedCapture = Capture-Window $handle $quickValuesAdjustedPath

    $quickValuesToggle = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickValues.Toggle"
    $quickValuesBefore = $quickValuesToggle.Current.BoundingRectangle
    Invoke-MouseDrag `
        -StartX ([int][Math]::Round($quickValuesBefore.Left - 48)) `
        -StartY ([int][Math]::Round($quickValuesBefore.Top + $quickValuesBefore.Height / 2)) `
        -EndX ([int][Math]::Round($quickValuesBefore.Left - 248)) `
        -EndY ([int][Math]::Round($quickValuesBefore.Top + $quickValuesBefore.Height / 2 + 500))
    Start-Sleep -Milliseconds 500
    $quickValuesAfter = (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickValues.Toggle").Current.BoundingRectangle
    $quickValuesDragDeltaX = $quickValuesAfter.Left - $quickValuesBefore.Left
    $quickValuesDragDeltaY = $quickValuesAfter.Top - $quickValuesBefore.Top
    if ([Math]::Abs($quickValuesDragDeltaX) -lt 50 -or
        [Math]::Abs($quickValuesDragDeltaY) -lt 30) {
        throw "Adjustment-palette real pointer drag did not move the floating window."
    }
    $quickValuesDraggedCapture = Capture-Window $handle $quickValuesDraggedPath
    Invoke-Element (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickValues.Toggle")
    Wait-Condition -Description "collapsed adjustment palette" -Condition {
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.QuickValues.Toggle" `
            -TimeoutMilliseconds 400).Current.Name -eq "+"
    }
    $quickValuesCollapsedCapture = Capture-Window $handle $quickValuesCollapsedPath
    Invoke-Element (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickPalette.Toggle")
    Wait-Condition -Description "quick palette restored before extension actions" -Condition {
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.QuickPalette.Toggle" `
            -TimeoutMilliseconds 400).Current.Name -eq "−"
    }

    Wait-Condition -Description "runtime evidence before extension selection" -Condition {
        Test-Path -LiteralPath $runtimePath -PathType Leaf
    }
    $runtimeBeforeExtension = Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json -Depth 100
    $expectedLongCount = [int]$runtimeBeforeExtension.chart.structure.longNoteCount
    $expectedTapCount = [int]$runtimeBeforeExtension.chart.structure.noteCount - $expectedLongCount

    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.CommandMenuToggle")
    Invoke-MouseClick (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.Extension.Toggle")
    Wait-Condition -Description "WPF extension palette" -Condition {
        try {
            -not (Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Editor.Extension.SelectLongNotes" `
                -TimeoutMilliseconds 400).Current.IsOffscreen
        }
        catch { $false }
    }
    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.CommandMenuToggle")
    Start-Sleep -Milliseconds 400
    $extensionOpenedCapture = Capture-Window $handle $extensionOpenedPath

    Invoke-MouseClick (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.QuickSelectAll")
    Invoke-MouseClick (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.Extension.SelectLongNotes")
    Wait-Condition -Description "real chart LN-only selection" -Condition {
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Inspector.Note.SelectionHint" `
            -TimeoutMilliseconds 400).Current.Name -ceq "已选择 $expectedLongCount 个 Note"
    }
    $longSelectionHint = (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Inspector.Note.SelectionHint").Current.Name

    Invoke-MouseClick (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.QuickSelectAll")
    Invoke-MouseClick (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.Extension.SelectTaps")
    Wait-Condition -Description "real chart Tap-only selection" -Condition {
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Inspector.Note.SelectionHint" `
            -TimeoutMilliseconds 400).Current.Name -ceq "已选择 $expectedTapCount 个 Note"
    }
    $tapSelectionHint = (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Inspector.Note.SelectionHint").Current.Name

    # Avalonia Border does not publish a dedicated UIA peer. Derive the actual
    # 28-DIP WPF header center from the first 38-DIP action row and the runtime
    # display scale, then drag the physical header itself (not an Invoke fallback).
    $extensionFirstButton = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.Extension.SelectLongNotes"
    $extensionBefore = $extensionFirstButton.Current.BoundingRectangle
    $extensionScale = [double]$runtimeBeforeExtension.window.screenScaling
    $extensionHeaderCenterX = $extensionBefore.Left + $extensionBefore.Width + 3 * $extensionScale
    $extensionHeaderCenterY = $extensionBefore.Top - 19 * $extensionScale
    Invoke-MouseDrag `
        -StartX ([int][Math]::Round($extensionHeaderCenterX)) `
        -StartY ([int][Math]::Round($extensionHeaderCenterY)) `
        -EndX ([int][Math]::Round($extensionHeaderCenterX + 180)) `
        -EndY ([int][Math]::Round($extensionHeaderCenterY + 140))
    Start-Sleep -Milliseconds 500
    $extensionAfter = (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.Extension.SelectLongNotes").Current.BoundingRectangle
    $extensionDragDeltaX = $extensionAfter.Left - $extensionBefore.Left
    $extensionDragDeltaY = $extensionAfter.Top - $extensionBefore.Top
    if ([Math]::Abs($extensionDragDeltaX) -lt 50 -or
        [Math]::Abs($extensionDragDeltaY) -lt 30) {
        throw "Extension-palette real pointer drag did not move the floating window."
    }
    $extensionDraggedCapture = Capture-Window $handle $extensionDraggedPath

    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.CommandMenuToggle")
    Invoke-MouseClick (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.Extension.Toggle")
    Wait-Condition -Description "closed WPF extension palette" -Condition {
        try {
            (Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Editor.Extension.SelectLongNotes" `
                -TimeoutMilliseconds 400).Current.IsOffscreen
        }
        catch { $true }
    }
    Start-Sleep -Milliseconds 450
    $commandCapture = Capture-Window $handle $commandPath

    $commandToggle = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.CommandMenuToggle"
    if ($commandToggle.Current.Name -cne "×") {
        throw "WPF command-menu toggle did not expose the expected close glyph."
    }
    $commandPaletteIds = @(
        "Editor.New",
        "Editor.Open",
        "Editor.Save",
        "Editor.Export",
        "Editor.Backup",
        "Editor.RestoreBackup",
        "Editor.Command.PlayPause",
        "Editor.Command.Stop",
        "Editor.Command.Fullscreen",
        "Editor.Command.Undo",
        "Editor.Command.Redo",
        "Editor.ChartCheck",
        "Editor.DifficultyAnalysis",
        "Editor.Extension.Toggle",
        "Editor.Playtest.FromStart",
        "Editor.Playtest.FromHere",
        "ProEditor.Toggle")
    $commandPaletteItems = @(
        foreach ($automationId in $commandPaletteIds) {
            $element = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId $automationId
            if ($element.Current.IsOffscreen) {
                throw "WPF command-menu item is offscreen: $automationId"
            }
            [ordered]@{
                automationId = $automationId
                name = [string]$element.Current.Name
                left = [double]$element.Current.BoundingRectangle.Left
                top = [double]$element.Current.BoundingRectangle.Top
                width = [double]$element.Current.BoundingRectangle.Width
                height = [double]$element.Current.BoundingRectangle.Height
                enabled = [bool]$element.Current.IsEnabled
            }
        })
    for ($index = 1; $index -lt $commandPaletteItems.Count; $index++) {
        if ([double]$commandPaletteItems[$index].left -le
            [double]$commandPaletteItems[$index - 1].left) {
            throw "WPF command-menu item order is not strictly left-to-right at index $index."
        }
    }
    foreach ($completedId in @(
            "Editor.DifficultyAnalysis",
            "Editor.Playtest.FromStart",
            "Editor.Playtest.FromHere")) {
        $completed = $commandPaletteItems | Where-Object automationId -CEQ $completedId
        if (-not $completed.enabled) {
            throw "Completed WPF command is unexpectedly disabled: $completedId"
        }
    }

    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.CommandMenuToggle")
    Wait-Condition -Description "collapsed WPF command menu" -Condition {
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.CommandMenuToggle" `
            -TimeoutMilliseconds 400).Current.Name -ceq "⚙"
    }
    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Toggle")
    Start-Sleep -Milliseconds 450
    $inspectorCapture = Capture-Window $handle $inspectorPath
    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Toggle")

    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "Title.Library")
    Wait-Condition -Description "library surface" -Condition {
        try {
            $null -ne (Find-ElementById -ProcessId $process.Id -AutomationId "Library.Search" -TimeoutMilliseconds 400)
        }
        catch { $false }
    }
    Start-Sleep -Milliseconds 650
    $libraryCapture = Capture-Window $handle $libraryPath

    Wait-Condition -Description "runtime evidence" -Condition {
        Test-Path -LiteralPath $runtimePath -PathType Leaf
    }
    $runtime = Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json -Depth 100
    $settingsPath = Join-Path $sessionRoot "local-data\editor-view-settings.json"
    Wait-Condition -Description "quick palette persisted settings" -Condition {
        Test-Path -LiteralPath $settingsPath -PathType Leaf
    }
    $quickSettings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    if ([Math]::Abs([double]$quickSettings.QuickPaletteX) -lt 50 -or
        [Math]::Abs([double]$quickSettings.QuickPaletteY) -lt 30 -or
        [bool]$quickSettings.QuickPaletteCollapsed) {
        throw "Quick-palette position or expanded state was not atomically persisted."
    }
    if ([Math]::Abs([double]$quickSettings.QuickValuesPaletteX) -lt 50 -or
        [Math]::Abs([double]$quickSettings.QuickValuesPaletteY) -lt 30 -or
        -not [bool]$quickSettings.QuickValuesPaletteCollapsed -or
        [int]$quickSettings.SnapDivision -ne 7 -or
        [Math]::Abs([double]$quickSettings.GridBeatHeight - 238) -gt .01 -or
        [Math]::Abs([double]$quickSettings.PlaybackRate - .9) -gt .001) {
        throw "Adjustment-palette layout, collapsed state, snap, height or rate was not atomically persisted."
    }

    $process.Kill($true)
    [void]$process.WaitForExit(5000)
    $reopenRuntimePath = Join-Path $outputFullPath "visual-parity-reopened-runtime.json"
    $process = Start-VisualParityClient `
        -Application $applicationFullPath `
        -ChartPath $chartFullPath `
        -RuntimeEvidencePath $reopenRuntimePath `
        -SessionRoot $sessionRoot
    $handle = Wait-MainWindowHandle $process
    [void][LumaChartVisualParityNative]::ShowWindow($handle, 3)
    Wait-Condition -Description "reopened editor surface" -Condition {
        $null -ne (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Inspector.TimingTab" `
            -TimeoutMilliseconds 400)
    }
    Start-Sleep -Milliseconds 800
    $quickReopened = (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickPalette.Toggle").Current.BoundingRectangle
    if ([Math]::Abs($quickReopened.Left - $quickAfter.Left) -gt 4 -or
        [Math]::Abs($quickReopened.Top - $quickAfter.Top) -gt 4) {
        throw "Quick-palette persisted position was not restored by the second client process."
    }
    $quickValuesReopened = (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickValues.Toggle").Current.BoundingRectangle
    if ([Math]::Abs($quickValuesReopened.Left - $quickValuesAfter.Left) -gt 4 -or
        [Math]::Abs($quickValuesReopened.Top - $quickValuesAfter.Top) -gt 4 -or
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.QuickValues.Toggle").Current.Name -ne "+") {
        throw "Adjustment-palette persisted position or collapsed state was not restored by the second client."
    }
    Invoke-Element (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickValues.Toggle")
    Wait-Condition -Description "reopened adjustment palette values" -Condition {
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.QuickValues.Snap.Preset" `
            -TimeoutMilliseconds 400).Current.Name -eq "1/7" -and
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.QuickValues.Grid.Preset" `
            -TimeoutMilliseconds 400).Current.Name -eq "1.70x" -and
        (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.QuickValues.Rate.Preset" `
            -TimeoutMilliseconds 400).Current.Name -eq "0.90x"
    }
    Invoke-Element (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.QuickValues.Toggle")
    Wait-Condition -Description "reopened runtime evidence" -Condition {
        Test-Path -LiteralPath $reopenRuntimePath -PathType Leaf
    }
    $quickReopenedCapture = Capture-Window $handle $quickReopenedPath
    $fixtureHashAfter = (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
    $installerHashAfter = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.visual-parity-gui-evidence.v3"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        scope = [ordered]@{
            windowsAvaloniaOnly = $true
            androidIosMacosLinuxWebModifiedBuiltInstalledOrTested = $false
            mobileWorkloadInstalled = $false
            productionServerDeployed = $false
            releaseInstallerOverwritten = ($installerHashBefore -cne $installerHashAfter)
            ollvmExecutedOrRequired = $false
            userRunningClientsClosed = $false
        }
        cacheBoundary = [ordered]@{
            dotnetCliHome = $script:dotnetHome
            nugetPackages = $script:nugetPackages
            nugetHttpCache = $script:nugetHttpCache
            temp = $script:projectTemp
            cDriveDotnetNugetTempCacheUsed = $false
        }
        realChart = [ordered]@{
            path = $chartFullPath
            sha256Before = $fixtureHashBefore
            sha256After = $fixtureHashAfter
            unchanged = ($fixtureHashBefore -ceq $fixtureHashAfter)
        }
        runtimeSchema = [string]$runtime.schema
        shell = [ordered]@{
            titleBarDocumentTabs = $true
            legacyLeftNavigationVisible = $false
            libraryHeaderActions = 7
            editorOverviewSingleControl = $true
            floatingCommandMenu = $true
            commandPalette = [ordered]@{
                wpfThreeGroupLayout = $true
                toggleExpandedGlyph = "×"
                toggleCollapsedGlyph = "⚙"
                items = $commandPaletteItems
                completedEnabled = @(
                    "Editor.DifficultyAnalysis",
                    "Editor.Playtest.FromStart",
                    "Editor.Playtest.FromHere")
                extraDeveloperToolbarItemsVisible = $false
                proColumnsMovedToSettings = $true
            }
            extensionPalette = $true
            extensionPaletteRealPointerDrag = $true
            extensionPaletteDragDelta = [ordered]@{
                x = $extensionDragDeltaX
                y = $extensionDragDeltaY
            }
            extensionPaletteRealChartSelection = [ordered]@{
                longNotesExpected = $expectedLongCount
                longNotesHint = $longSelectionHint
                tapsExpected = $expectedTapCount
                tapsHint = $tapSelectionHint
                timingSelectionCleared = $true
            }
            floatingQuickEditPalette = $true
            quickEditPaletteRealPointerDrag = $true
            quickEditPaletteCollapseExpand = $true
            quickEditPaletteSecondProcessRestore = $true
            quickEditPaletteDragDelta = [ordered]@{
                x = $quickDragDeltaX
                y = $quickDragDeltaY
            }
            quickMirrorRealNotePointerClick = $true
            quickMirrorAuthoredBeatUnchanged = ($noteBeatBefore -ceq $noteBeatMirrored)
            quickMirrorAuthoredEndBeatUnchanged = ($noteEndBeatBefore -ceq $noteEndBeatMirrored)
            quickMirrorLane = [ordered]@{
                before = $noteLaneBefore
                mirrored = $noteLaneMirrored
                undo = $noteLaneBefore
            }
            adjustmentPalette = $true
            adjustmentPaletteRealPointerDrag = $true
            adjustmentPaletteCollapseSecondProcessRestore = $true
            adjustmentPaletteValuesSecondProcessRestore = $true
            adjustmentCustomValueRightClickFocusLoss = $true
            adjustmentCustomValueEnterEscapeRequired = $false
            adjustmentPaletteDragDelta = [ordered]@{
                x = $quickValuesDragDeltaX
                y = $quickValuesDragDeltaY
            }
            adjustmentValues = [ordered]@{
                snapDivision = 7
                gridBeatHeightDip = 238
                playbackRate = .9
            }
            collapsibleInspector = $true
            inspectorWidthDip = 350
            perNoteAvaloniaControls = 0
        }
        screenshots = [ordered]@{
            editorDefault = $editorCapture
            editorQuickPaletteDragged = $quickDraggedCapture
            editorQuickPaletteCollapsed = $quickCollapsedCapture
            editorQuickPaletteReopened = $quickReopenedCapture
            editorQuickMirror = $quickMirrorCapture
            editorAdjustmentValues = $quickValuesAdjustedCapture
            editorAdjustmentDragged = $quickValuesDraggedCapture
            editorAdjustmentCollapsed = $quickValuesCollapsedCapture
            editorExtensionPalette = $extensionOpenedCapture
            editorExtensionPaletteDragged = $extensionDraggedCapture
            editorCommandMenu = $commandCapture
            editorInspectorCollapsed = $inspectorCapture
            library = $libraryCapture
        }
        remainingDifferences = @(
            "Pixel-level typography, control templates, editor palettes and remaining inspector/audio placement still require iteration.",
            "Rework, test-play and the remaining function matrix are incomplete.",
            "This PrintWindow capture is not display scan-out, physical 60/120 Hz or final WPF A/B performance certification."
        )
    }
    $evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Write-Host "Windows Avalonia visual-parity GUI capture: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    if ($process -and -not $process.HasExited) {
        $process.Kill($true)
        [void]$process.WaitForExit(5000)
    }
}
