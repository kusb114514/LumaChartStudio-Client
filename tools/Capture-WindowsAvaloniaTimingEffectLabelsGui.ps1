param(
    [string]$ApplicationPath = (
        Join-Path $PSScriptRoot `
            "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [switch]$AllowForegroundAutomation,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if (-not $AllowForegroundAutomation) {
    throw "Pass -AllowForegroundAutomation after the user explicitly releases the desktop."
}
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Timing Effect label GUI capture requires PowerShell Core on Windows."
}

function Resolve-ExistingFile([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "$Label not found: $full"
    }
    return $full
}

function Wait-Condition(
    [scriptblock]$Condition,
    [string]$Description,
    [int]$Seconds = $TimeoutSeconds) {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try {
            if (& $Condition) { return }
        }
        catch { }
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

public static class LumaChartTimingEffectLabelNative
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
    public static extern bool ShowWindowAsync(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern void SwitchToThisWindow(IntPtr window, bool altTab);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(
        uint firstThread,
        uint secondThread,
        bool attach);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    private static extern IntPtr GetWindowLongPtr64(IntPtr window, int index);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
    private static extern int GetWindowLong32(IntPtr window, int index);

    public static long GetExtendedStyle(IntPtr window)
    {
        const int GWL_EXSTYLE = -20;
        return IntPtr.Size == 8
            ? GetWindowLongPtr64(window, GWL_EXSTYLE).ToInt64()
            : GetWindowLong32(window, GWL_EXSTYLE);
    }

    public static bool TryActivateWindow(IntPtr window)
    {
        if (window == IntPtr.Zero)
            return false;
        for (var attempt = 0; attempt < 4; attempt++)
        {
            if (GetForegroundWindow() == window)
                return true;
            var foreground = GetForegroundWindow();
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
                    attachedForeground = AttachThreadInput(
                        currentThread,
                        foregroundThread,
                        true);
                if (targetThread != 0 &&
                    targetThread != currentThread &&
                    targetThread != foregroundThread)
                    attachedTarget = AttachThreadInput(
                        currentThread,
                        targetThread,
                        true);
                ShowWindowAsync(window, 5);
                BringWindowToTop(window);
                SetForegroundWindow(window);
                SwitchToThisWindow(window, true);
            }
            finally
            {
                if (attachedTarget)
                    AttachThreadInput(currentThread, targetThread, false);
                if (attachedForeground)
                    AttachThreadInput(currentThread, foregroundThread, false);
            }
            System.Threading.Thread.Sleep(75);
        }
        return GetForegroundWindow() == window;
    }
}
'@

function Find-ElementById(
    [int]$ProcessId,
    [string]$AutomationId,
    [int]$Milliseconds = 10000,
    [switch]$Optional) {
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($Milliseconds)
    do {
        $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
            [Windows.Automation.TreeScope]::Children,
            $processCondition)
        foreach ($root in $roots) {
            if ($root.Current.AutomationId -ceq $AutomationId) {
                return $root
            }
            $element = $root.FindFirst(
                [Windows.Automation.TreeScope]::Descendants,
                $idCondition)
            if ($null -ne $element) { return $element }
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    if ($Optional) { return $null }
    throw "UI Automation element not found: $AutomationId"
}

function Find-VisibleElementByName(
    [int]$ProcessId,
    [string]$Name,
    $ControlType = [Windows.Automation.ControlType]::Text,
    [int]$Milliseconds = 10000) {
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $nameCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty,
        $Name)
    $controlTypeCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ControlTypeProperty,
        $ControlType)
    $elementCondition = [Windows.Automation.AndCondition]::new(
        $nameCondition,
        $controlTypeCondition)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($Milliseconds)
    do {
        $matches = [Collections.Generic.List[object]]::new()
        $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
            [Windows.Automation.TreeScope]::Children,
            $processCondition)
        foreach ($root in $roots) {
            $elements = $root.FindAll(
                [Windows.Automation.TreeScope]::Descendants,
                $elementCondition)
            foreach ($element in $elements) {
                if (-not $element.Current.IsOffscreen -and
                    $element.Current.BoundingRectangle.Width -gt 0 -and
                    $element.Current.BoundingRectangle.Height -gt 0) {
                    $matches.Add($element)
                }
            }
        }
        if ($matches.Count -eq 1) { return $matches[0] }
        if ($matches.Count -gt 1) {
            throw (
                "Expected one visible $($ControlType.ProgrammaticName) element " +
                "named '$Name', found $($matches.Count).")
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw (
        "Visible $($ControlType.ProgrammaticName) UI Automation element not " +
        "found by name: $Name")
}

function Get-SelectedItemName($ComboBox) {
    $pattern = $null
    if ($ComboBox.TryGetCurrentPattern(
            [Windows.Automation.SelectionPattern]::Pattern,
            [ref]$pattern)) {
        $selection = @(
            ([Windows.Automation.SelectionPattern]$pattern).Current.GetSelection())
        if ($selection.Count -eq 1) {
            return [string]$selection[0].Current.Name
        }
    }
    $pattern = $null
    if ($ComboBox.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$pattern)) {
        return [string](
            [Windows.Automation.ValuePattern]$pattern).Current.Value
    }
    throw "Timing Effect ComboBox does not expose one selected display label."
}

function Expand-ComboBox($ComboBox) {
    $pattern = $null
    if (-not $ComboBox.TryGetCurrentPattern(
            [Windows.Automation.ExpandCollapsePattern]::Pattern,
            [ref]$pattern)) {
        throw "Timing Effect ComboBox does not expose ExpandCollapsePattern."
    }
    ([Windows.Automation.ExpandCollapsePattern]$pattern).Expand()
}

function Collapse-ComboBox($ComboBox) {
    $pattern = $null
    if (-not $ComboBox.TryGetCurrentPattern(
            [Windows.Automation.ExpandCollapsePattern]::Pattern,
            [ref]$pattern)) {
        throw "Timing Effect ComboBox does not expose ExpandCollapsePattern."
    }
    ([Windows.Automation.ExpandCollapsePattern]$pattern).Collapse()
}

function Get-VisibleListItems([int]$ProcessId) {
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $listItemCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ControlTypeProperty,
        [Windows.Automation.ControlType]::ListItem)
    $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
        [Windows.Automation.TreeScope]::Children,
        $processCondition)
    return @(
        $roots | ForEach-Object {
            $_.FindAll(
                [Windows.Automation.TreeScope]::Descendants,
                $listItemCondition)
        } | ForEach-Object { $_ } | Where-Object {
            -not $_.Current.IsOffscreen -and
            $_.Current.BoundingRectangle.Width -gt 0 -and
            $_.Current.BoundingRectangle.Height -gt 0
        })
}

function Select-EffectItem([int]$ProcessId, [string]$Name) {
    $target = @(Get-VisibleListItems $ProcessId | Where-Object {
        $_.Current.Name -ceq $Name
    })
    if ($target.Count -ne 1) {
        throw "Expected one visible Timing Effect '$Name', found $($target.Count)."
    }
    $pattern = $null
    if (-not $target[0].TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$pattern)) {
        throw "Timing Effect '$Name' does not expose SelectionItemPattern."
    }
    ([Windows.Automation.SelectionItemPattern]$pattern).Select()
}

function Select-Element($Element, [string]$Label) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$pattern)) {
        throw "$Label does not expose SelectionItemPattern."
    }
    ([Windows.Automation.SelectionItemPattern]$pattern).Select()
}

function Scroll-ElementIntoView($Element, [string]$Label) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.ScrollItemPattern]::Pattern,
            [ref]$pattern)) {
        throw "$Label does not expose ScrollItemPattern."
    }
    ([Windows.Automation.ScrollItemPattern]$pattern).ScrollIntoView()
}

function Capture-WindowScreen([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartTimingEffectLabelNative+RECT]::new()
    if (-not [LumaChartTimingEffectLabelNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) {
        throw "GetWindowRect failed."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 640 -or $height -lt 480) {
        throw "Unexpected evidence window size: ${width}x${height}."
    }
    $bitmap = [Drawing.Bitmap]::new($width, $height)
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
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        bytes = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        width = $width
        height = $height
        capture = "display screen region including Avalonia PopupRoot"
    }
}

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
$projectBoundary = $projectRoot.TrimEnd('\') + '\'
if (-not $outputFullPath.StartsWith(
        $projectBoundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Output root must stay below the project root: $outputFullPath"
}
if ([IO.Directory]::Exists($outputFullPath) -or [IO.File]::Exists($outputFullPath)) {
    throw "Output root already exists: $outputFullPath"
}

$application = Resolve-ExistingFile $ApplicationPath "Avalonia application"
$fixture = Resolve-ExistingFile $ChartFixturePath "real MC fixture"
$fixtureBefore = Get-FileHash -LiteralPath $fixture -Algorithm SHA256
$installer = Resolve-ExistingFile (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe") "frozen installer"
$installerBefore = Get-FileHash -LiteralPath $installer -Algorithm SHA256
$sessionRoot = Join-Path (
    Join-Path $projectRoot ".codex-temp") (
        "timing-effect-label-gui-" + [Guid]::NewGuid().ToString("N"))
$chartRoot = Join-Path $sessionRoot "chart"
$localDataRoot = Join-Path $sessionRoot "local-data"
$editingRoot = Join-Path $sessionRoot "editing"
$workspaceRoot = Join-Path $sessionRoot "workspace"
$tempRoot = Join-Path $sessionRoot "temp"
[void][IO.Directory]::CreateDirectory($outputFullPath)
foreach ($directory in @(
        $chartRoot,
        $localDataRoot,
        $editingRoot,
        $workspaceRoot,
        $tempRoot)) {
    [void][IO.Directory]::CreateDirectory($directory)
}
$chartCopy = Join-Path $chartRoot "timing-effect-labels.mc"
Copy-Item -LiteralPath $fixture -Destination $chartCopy
$chartCopyBefore = Get-FileHash -LiteralPath $chartCopy -Algorithm SHA256

$runtimePath = Join-Path $outputFullPath "runtime.json"
$defaultPath = Join-Path $outputFullPath "01-none-selected.png"
$expandedPath = Join-Path $outputFullPath "02-effect-options-expanded.png"
$customPath = Join-Path $outputFullPath "03-custom-selected.png"
$restoredPath = Join-Path $outputFullPath "04-none-restored.png"
$keyCountSelectedPath = Join-Path $outputFullPath "05-key-count-selected.png"
$keyCountExpandedPath = Join-Path $outputFullPath "06-key-count-options-expanded.png"
$metadataFooterPath = Join-Path $outputFullPath "07-metadata-footer.png"
$evidencePath = Join-Path $outputFullPath "evidence.json"
$expectedLabels = @("无", "Scroll", "Jump", "HS", "Sign", "自定义字段")
$expectedKeyCountLabels = @(
    "4 Keys",
    "5 Keys",
    "6 Keys",
    "7 Keys",
    "8 Keys",
    "9 Keys",
    "10 Keys")
$actions = [Collections.Generic.List[object]]::new()
$process = $null

try {
    $start = [Diagnostics.ProcessStartInfo]::new($application)
    $start.UseShellExecute = $false
    foreach ($argument in @(
            "--evidence-chart",
            $chartCopy,
            "--evidence-focus-timing",
            "--evidence-output",
            $runtimePath)) {
        $start.ArgumentList.Add($argument)
    }
    $start.Environment["LUMACHART_PROFILE"] = "timing-effect-label-gui"
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceRoot
    $start.Environment["DOTNET_CLI_HOME"] =
        Join-Path $projectRoot ".codex-dotnet-home"
    $start.Environment["NUGET_PACKAGES"] =
        Join-Path $projectRoot ".codex-nuget-packages"
    $start.Environment["NUGET_HTTP_CACHE_PATH"] =
        Join-Path $projectRoot ".codex-nuget-http-cache"
    $start.Environment["TEMP"] = $tempRoot
    $start.Environment["TMP"] = $tempRoot
    $process = [Diagnostics.Process]::Start($start)
    if ($null -eq $process) {
        throw "Failed to start Windows Avalonia timing label client."
    }

    Wait-Condition {
        $process.Refresh()
        -not $process.HasExited -and
        $process.MainWindowHandle -ne [IntPtr]::Zero
    } "Avalonia timing label window"
    $handle = $process.MainWindowHandle
    if (-not [LumaChartTimingEffectLabelNative]::TryActivateWindow($handle)) {
        throw "Could not activate the timing label evidence window."
    }
    $topmost = (
        [LumaChartTimingEffectLabelNative]::GetExtendedStyle($handle) -band 0x8) -ne 0
    if ($topmost) {
        throw "Timing label evidence window unexpectedly started topmost."
    }

    $combo = Find-ElementById $process.Id "Inspector.Timing.Effect"
    Wait-Condition {
        (Get-SelectedItemName $combo) -ceq "无"
    } "WPF 无 Timing Effect selection"
    $defaultCapture = Capture-WindowScreen $handle $defaultPath

    Expand-ComboBox $combo
    $actions.Add([ordered]@{
        index = 1
        automationId = "Inspector.Timing.Effect"
        input = "UI Automation ExpandCollapsePattern.Expand"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    Wait-Condition {
        $visibleNames = @(Get-VisibleListItems $process.Id |
            ForEach-Object { [string]$_.Current.Name })
        @($expectedLabels | Where-Object { $_ -notin $visibleNames }).Count -eq 0
    } "all six WPF Timing Effect labels"
    $visibleLabels = @(Get-VisibleListItems $process.Id |
        ForEach-Object { [string]$_.Current.Name } |
        Where-Object { $_ -in $expectedLabels })
    $expandedCapture = Capture-WindowScreen $handle $expandedPath

    Select-EffectItem $process.Id "自定义字段"
    $actions.Add([ordered]@{
        index = 2
        automationId = "Inspector.Timing.Effect/自定义字段"
        input = "UI Automation SelectionItemPattern.Select"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    Collapse-ComboBox $combo
    $actions.Add([ordered]@{
        index = 3
        automationId = "Inspector.Timing.Effect"
        input = "UI Automation ExpandCollapsePattern.Collapse"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    Wait-Condition {
        (Get-SelectedItemName $combo) -ceq "自定义字段" -and
        $null -ne (Find-ElementById `
            $process.Id `
            "Inspector.Timing.CustomField" `
            -Milliseconds 300 `
            -Optional)
    } "自定义字段 selection and field"
    $customField = Find-ElementById $process.Id "Inspector.Timing.CustomField"
    if ($customField.Current.IsOffscreen -or
        $customField.Current.BoundingRectangle.Width -le 0 -or
        $customField.Current.BoundingRectangle.Height -le 0) {
        throw "自定义字段 input is not visibly materialized."
    }
    $customCapture = Capture-WindowScreen $handle $customPath

    Expand-ComboBox $combo
    $actions.Add([ordered]@{
        index = 4
        automationId = "Inspector.Timing.Effect"
        input = "UI Automation ExpandCollapsePattern.Expand"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    Wait-Condition {
        @(Get-VisibleListItems $process.Id | Where-Object {
            $_.Current.Name -ceq "无"
        }).Count -eq 1
    } "WPF 无 option after reopening"
    Select-EffectItem $process.Id "无"
    $actions.Add([ordered]@{
        index = 5
        automationId = "Inspector.Timing.Effect/无"
        input = "UI Automation SelectionItemPattern.Select"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    Collapse-ComboBox $combo
    $actions.Add([ordered]@{
        index = 6
        automationId = "Inspector.Timing.Effect"
        input = "UI Automation ExpandCollapsePattern.Collapse"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    Wait-Condition {
        (Get-SelectedItemName $combo) -ceq "无"
    } "restored WPF 无 selection"
    Start-Sleep -Milliseconds 250
    $restoredField = Find-ElementById `
        $process.Id `
        "Inspector.Timing.CustomField" `
        -Milliseconds 300 `
        -Optional
    if ($null -ne $restoredField -and
        -not $restoredField.Current.IsOffscreen -and
        $restoredField.Current.BoundingRectangle.Width -gt 0 -and
        $restoredField.Current.BoundingRectangle.Height -gt 0) {
        throw "Custom field remained visible after selecting 无."
    }
    $restoredCapture = Capture-WindowScreen $handle $restoredPath

    $metadataTab = Find-ElementById $process.Id "Inspector.MetadataTab"
    Select-Element $metadataTab "Metadata tab"
    $actions.Add([ordered]@{
        index = 7
        automationId = "Inspector.MetadataTab"
        input = "UI Automation SelectionItemPattern.Select"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    $keyCountCombo = Find-ElementById $process.Id "Metadata.KeyCount"
    Wait-Condition {
        (Get-SelectedItemName $keyCountCombo) -ceq "4 Keys"
    } "WPF 4 Keys Metadata selection"
    $metadataTitle = Find-VisibleElementByName $process.Id "谱面信息"
    $metadataSubtitle =
        Find-VisibleElementByName $process.Id "Malody Key / osu!mania 元数据"
    $metadataTitleAscii =
        Find-VisibleElementByName $process.Id "歌曲名（ASCII 英文字符）"
    $metadataArtistAscii =
        Find-VisibleElementByName $process.Id "艺术家（ASCII 英文字符）"
    $metadataKeyCountLabel =
        Find-VisibleElementByName $process.Id "轨道数"
    $keyCountSelectedCapture =
        Capture-WindowScreen $handle $keyCountSelectedPath

    Expand-ComboBox $keyCountCombo
    $actions.Add([ordered]@{
        index = 8
        automationId = "Metadata.KeyCount"
        input = "UI Automation ExpandCollapsePattern.Expand"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    Wait-Condition {
        $visibleNames = @(Get-VisibleListItems $process.Id |
            ForEach-Object { [string]$_.Current.Name })
        @($expectedKeyCountLabels |
            Where-Object { $_ -notin $visibleNames }).Count -eq 0
    } "all seven WPF Metadata KeyCount labels"
    $visibleKeyCountLabels = @(Get-VisibleListItems $process.Id |
        ForEach-Object { [string]$_.Current.Name } |
        Where-Object { $_ -in $expectedKeyCountLabels })
    $keyCountExpandedCapture =
        Capture-WindowScreen $handle $keyCountExpandedPath
    Collapse-ComboBox $keyCountCombo
    $actions.Add([ordered]@{
        index = 9
        automationId = "Metadata.KeyCount"
        input = "UI Automation ExpandCollapsePattern.Collapse"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    Wait-Condition {
        (Get-SelectedItemName $keyCountCombo) -ceq "4 Keys"
    } "restored WPF 4 Keys Metadata selection"

    $metadataApply = Find-ElementById $process.Id "Metadata.Apply"
    $metadataStatsNotes = Find-ElementById $process.Id "Metadata.Stats.Notes"
    $metadataStatsHolds = Find-ElementById $process.Id "Metadata.Stats.Holds"
    $metadataStatsTiming = Find-ElementById $process.Id "Metadata.Stats.Timing"
    $metadataStatsNotesLabel =
        Find-ElementById $process.Id "Metadata.Stats.Notes.Label"
    $metadataStatsHoldsLabel =
        Find-ElementById $process.Id "Metadata.Stats.Holds.Label"
    $metadataStatsTimingLabel =
        Find-ElementById $process.Id "Metadata.Stats.Timing.Label"
    Scroll-ElementIntoView $metadataStatsTimingLabel "Metadata Timing stats label"
    $actions.Add([ordered]@{
        index = 10
        automationId = "Metadata.Stats.Timing.Label"
        input = "UI Automation ScrollItemPattern.ScrollIntoView"
        occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    Start-Sleep -Milliseconds 500
    $metadataFooterCapture =
        Capture-WindowScreen $handle $metadataFooterPath
    Wait-Condition {
        -not $metadataApply.Current.IsOffscreen -and
        $metadataApply.Current.BoundingRectangle.Width -gt 0 -and
        $metadataApply.Current.BoundingRectangle.Height -gt 0 -and
        $metadataApply.Current.Name -ceq "应用谱面信息" -and
        -not $metadataStatsNotes.Current.IsOffscreen -and
        -not $metadataStatsHolds.Current.IsOffscreen -and
        -not $metadataStatsTiming.Current.IsOffscreen -and
        -not $metadataStatsNotesLabel.Current.IsOffscreen -and
        -not $metadataStatsHoldsLabel.Current.IsOffscreen -and
        -not $metadataStatsTimingLabel.Current.IsOffscreen -and
        $metadataStatsNotes.Current.Name -ceq "2753" -and
        $metadataStatsHolds.Current.Name -ceq "771" -and
        $metadataStatsTiming.Current.Name -ceq "1" -and
        $metadataStatsNotesLabel.Current.Name -ceq "Notes" -and
        $metadataStatsHoldsLabel.Current.Name -ceq "Holds" -and
        $metadataStatsTimingLabel.Current.Name -ceq "Timing"
    } "WPF Metadata apply copy and live stats in visible footer"

    $chartCopyAfter = Get-FileHash -LiteralPath $chartCopy -Algorithm SHA256
    $fixtureAfter = Get-FileHash -LiteralPath $fixture -Algorithm SHA256
    $installerAfter = Get-FileHash -LiteralPath $installer -Algorithm SHA256
    if ($chartCopyAfter.Hash -cne $chartCopyBefore.Hash -or
        $fixtureAfter.Hash -cne $fixtureBefore.Hash -or
        $installerAfter.Hash -cne $installerBefore.Hash) {
        throw "Timing Effect label GUI changed an immutable input."
    }
    $runtime = Get-Content -LiteralPath $runtimePath -Raw -Encoding UTF8 |
        ConvertFrom-Json -Depth 100

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.inspector-option-labels-gui.v3"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        platform = "Windows Avalonia"
        buildMode = "ordinary .NET Release"
        wpfReference = [ordered]@{
            timingEffect = [ordered]@{
                xamlPath = "LumaChart.App\MainWindow.xaml"
                line = 970
                values = @("None", "Scroll", "Jump", "HS", "Sign", "Custom")
                labels = $expectedLabels
            }
            metadataKeyCount = [ordered]@{
                xamlPath = "LumaChart.App\MainWindow.xaml"
                lines = @(898, 899, 900, 901, 902)
                fieldLabel = "轨道数"
                values = @(4, 5, 6, 7, 8, 9, 10)
                labels = $expectedKeyCountLabels
            }
            metadataCopy = [ordered]@{
                xamlPath = "LumaChart.App\MainWindow.xaml"
                titleLine = 872
                subtitleLine = 873
                fieldLines = @(875, 881, 898)
                applyLine = 936
                statsLines = @(937, 938, 939, 940, 941, 942, 943)
                title = "谱面信息"
                titleFontSize = 25
                subtitle = "Malody Key / osu!mania 元数据"
                titleAsciiLabel = "歌曲名（ASCII 英文字符）"
                artistAsciiLabel = "艺术家（ASCII 英文字符）"
                keyCountLabel = "轨道数"
                applyLabel = "应用谱面信息"
                statLabels = @("Notes", "Holds", "Timing")
                statValueFontSize = 20
            }
        }
        gui = [ordered]@{
            timingEffect = [ordered]@{
                initialSelectedLabel = "无"
                expandedLabels = $visibleLabels
                customSelectedLabel = "自定义字段"
                customFieldVisible = $true
                restoredSelectedLabel = "无"
                customFieldHiddenAfterRestore = $true
            }
            metadataKeyCount = [ordered]@{
                fieldLabel = "轨道数"
                initialSelectedLabel = "4 Keys"
                expandedLabels = $visibleKeyCountLabels
                restoredSelectedLabel = "4 Keys"
                selectionChanged = $false
            }
            metadataCopy = [ordered]@{
                title = [string]$metadataTitle.Current.Name
                subtitle = [string]$metadataSubtitle.Current.Name
                titleAsciiLabel = [string]$metadataTitleAscii.Current.Name
                artistAsciiLabel = [string]$metadataArtistAscii.Current.Name
                keyCountLabel = [string]$metadataKeyCountLabel.Current.Name
                applyLabel = [string]$metadataApply.Current.Name
                applyVisibleAfterScroll = $true
                stats = [ordered]@{
                    notes = 2753
                    holds = 771
                    timing = 1
                    notesValueName = [string]$metadataStatsNotes.Current.Name
                    holdsValueName = [string]$metadataStatsHolds.Current.Name
                    timingValueName = [string]$metadataStatsTiming.Current.Name
                    notesLabelName = [string]$metadataStatsNotesLabel.Current.Name
                    holdsLabelName = [string]$metadataStatsHoldsLabel.Current.Name
                    timingLabelName = [string]$metadataStatsTimingLabel.Current.Name
                    allVisibleAfterScroll = $true
                }
            }
            actionCount = $actions.Count
            actions = $actions
            persistentTopmostUsed = $false
            enterKeySent = $false
            inputInjectionUsed = $false
        }
        runtime = [ordered]@{
            schema = [string]$runtime.schema
            chartNoteCount = [int]$runtime.chart.structure.noteCount
            chartTimingCount = [int]$runtime.chart.structure.timingCount
            perNoteAvaloniaControls =
                [int]$runtime.timeline.perNoteAvaloniaControlCount
        }
        immutable = [ordered]@{
            sourceMc = [ordered]@{
                path = $fixture
                sha256Before = $fixtureBefore.Hash
                sha256After = $fixtureAfter.Hash
                unchanged = $true
            }
            copiedMc = [ordered]@{
                path = $chartCopy
                sha256Before = $chartCopyBefore.Hash
                sha256After = $chartCopyAfter.Hash
                unchanged = $true
            }
            installer = [ordered]@{
                path = $installer
                sha256Before = $installerBefore.Hash
                sha256After = $installerAfter.Hash
                unchanged = $true
            }
        }
        screenshots = [ordered]@{
            noneSelected = $defaultCapture
            optionsExpanded = $expandedCapture
            customSelected = $customCapture
            noneRestored = $restoredCapture
            keyCountSelected = $keyCountSelectedCapture
            keyCountOptionsExpanded = $keyCountExpandedCapture
            metadataFooter = $metadataFooterCapture
        }
        scope = [ordered]@{
            productionServerDeployed = $false
            mobileProjectsTouched = $false
            protectionObfuscationVirtualizationOrAotUsed = $false
            releaseInstallerOverwritten = $false
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
        }
    }
    $evidence | ConvertTo-Json -Depth 20 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Write-Output $evidencePath
}
finally {
    if ($null -ne $process -and -not $process.HasExited) {
        if (-not $process.CloseMainWindow() -or -not $process.WaitForExit(5000)) {
            $process.Kill($true)
            [void]$process.WaitForExit(5000)
        }
    }
    if ([IO.Directory]::Exists($sessionRoot)) {
        $tempBoundary = [IO.Path]::GetFullPath(
            (Join-Path $projectRoot ".codex-temp")).TrimEnd('\') + '\'
        $sessionFullPath = [IO.Path]::GetFullPath($sessionRoot).TrimEnd('\')
        if (-not $sessionFullPath.StartsWith(
                $tempBoundary,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Unsafe GUI session cleanup target: $sessionFullPath"
        }
        [IO.Directory]::Delete($sessionFullPath, $true)
    }
}
