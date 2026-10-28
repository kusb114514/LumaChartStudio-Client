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
    throw "Windows Avalonia settings/anchor GUI capture requires PowerShell Core on Windows."
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

public static class LumaChartSettingsAnchorGuiNative
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

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    public static extern IntPtr GetWindowLongPtr(IntPtr window, int index);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

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
        Thread.Sleep(120);
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
        Thread.Sleep(80);
        mouse_event(leftDown, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(40);
        mouse_event(leftUp, 0, 0, 0, UIntPtr.Zero);
    }

    public static void PressTab()
    {
        const byte tab = 0x09;
        const uint keyUp = 0x0002;
        keybd_event(tab, 0, 0, UIntPtr.Zero);
        Thread.Sleep(24);
        keybd_event(tab, 0, keyUp, UIntPtr.Zero);
    }

    public static void PressShiftTab()
    {
        const byte shift = 0x10;
        const byte tab = 0x09;
        const uint keyUp = 0x0002;
        keybd_event(shift, 0, 0, UIntPtr.Zero);
        Thread.Sleep(18);
        keybd_event(tab, 0, 0, UIntPtr.Zero);
        Thread.Sleep(24);
        keybd_event(tab, 0, keyUp, UIntPtr.Zero);
        keybd_event(shift, 0, keyUp, UIntPtr.Zero);
    }

    public static void PressAltF4()
    {
        const byte menu = 0x12;
        const byte f4 = 0x73;
        const uint keyUp = 0x0002;
        keybd_event(menu, 0, 0, UIntPtr.Zero);
        Thread.Sleep(30);
        keybd_event(f4, 0, 0, UIntPtr.Zero);
        Thread.Sleep(45);
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
        Start-Sleep -Milliseconds 60
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Get-WindowBounds([IntPtr]$Handle) {
    $rectangle = [LumaChartSettingsAnchorGuiNative+RECT]::new()
    if (-not [LumaChartSettingsAnchorGuiNative]::GetWindowRect(
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
        if ([LumaChartSettingsAnchorGuiNative]::GetForegroundWindow() -eq $Handle) {
            return
        }
        [void][LumaChartSettingsAnchorGuiNative]::ActivateNonTopmost($Handle)
        Start-Sleep -Milliseconds 60
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Unable to activate non-topmost settings evidence window $Handle."
}

function Scroll-ElementIntoView(
    [Windows.Automation.AutomationElement]$Element) {
    $patternObject = $null
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.ScrollItemPattern]::Pattern,
            [ref]$patternObject)) {
        ([Windows.Automation.ScrollItemPattern]$patternObject).ScrollIntoView()
        Start-Sleep -Milliseconds 120
    }
}

function Get-VisibleElementById(
    [int]$ProcessId,
    [string]$AutomationId) {
    $element = Find-ElementById `
        -ProcessId $ProcessId `
        -AutomationId $AutomationId
    Scroll-ElementIntoView $element
    return Find-ElementById `
        -ProcessId $ProcessId `
        -AutomationId $AutomationId `
        -Visible
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
    [LumaChartSettingsAnchorGuiNative]::Click($x, $y)
    return [ordered]@{ x = $x; y = $y }
}

function Set-EditableElementValue(
    [Windows.Automation.AutomationElement]$Element,
    [string]$Value) {
    $patternObject = $null
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$patternObject)) {
        ([Windows.Automation.ValuePattern]$patternObject).SetValue($Value)
        return [string]$Element.Current.AutomationId
    }
    $descendants = $Element.FindAll(
        [Windows.Automation.TreeScope]::Descendants,
        [Windows.Automation.Condition]::TrueCondition)
    foreach ($candidate in $descendants) {
        $candidatePattern = $null
        if ($candidate.TryGetCurrentPattern(
                [Windows.Automation.ValuePattern]::Pattern,
                [ref]$candidatePattern)) {
            ([Windows.Automation.ValuePattern]$candidatePattern).SetValue($Value)
            return [string]$candidate.Current.AutomationId
        }
    }
    throw "Editable control '$($Element.Current.AutomationId)' lacks ValuePattern."
}

function Capture-ScreenWindow([IntPtr]$Handle, [string]$Path) {
    $bounds = Get-WindowBounds $Handle
    if ($bounds.width -lt 900 -or $bounds.height -lt 600) {
        throw "Window has invalid settings/anchor capture bounds."
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
            throw "Settings/anchor screenshot is near-uniform."
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

function Resolve-FocusedAutomationId(
    [int]$ProcessId,
    [string[]]$ExpectedIds) {
    $focused = [Windows.Automation.AutomationElement]::FocusedElement
    $rawId = [string]$focused.Current.AutomationId
    $candidate = $focused
    for ($depth = 0; $depth -lt 8 -and $candidate; $depth++) {
        if ($candidate.Current.ProcessId -ne $ProcessId) { break }
        $candidateId = [string]$candidate.Current.AutomationId
        if ($ExpectedIds -contains $candidateId) {
            return [ordered]@{
                rawAutomationId = $rawId
                resolvedAutomationId = $candidateId
                ancestorDepth = $depth
                name = [string]$focused.Current.Name
            }
        }
        $candidate =
            [Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($candidate)
    }
    return [ordered]@{
        rawAutomationId = $rawId
        resolvedAutomationId = $rawId
        ancestorDepth = -1
        name = [string]$focused.Current.Name
    }
}

function Assert-AnchorState(
    [int]$ProcessId,
    [string]$ActiveId,
    [string]$ActiveMode,
    [string]$DisplayName) {
    $anchorModes = [ordered]@{
        "Settings.AnchorLine" = "GridLine"
        "Settings.AnchorLineAbove" = "LineAbove"
        "Settings.AnchorCell" = "CellCenter"
        "Settings.AnchorCellBottom" = "CellBottom"
    }
    $buttonStates = [ordered]@{}
    foreach ($entry in $anchorModes.GetEnumerator()) {
        $button = Find-ElementById `
            -ProcessId $ProcessId `
            -AutomationId $entry.Key
        $help = [string]$button.Current.HelpText
        $expectedActive = $entry.Key -ceq $ActiveId
        $expected =
            "NoteAnchor=$($entry.Value); Active=$expectedActive"
        if ($help -cne $expected) {
            throw (
                "Anchor state mismatch for $($entry.Key): " +
                "expected '$expected', got '$help'.")
        }
        $buttonStates[$entry.Key] = $help
    }
    $timeline = Find-ElementById `
        -ProcessId $ProcessId `
        -AutomationId "Timeline.Surface"
    $timelineHelp = [string]$timeline.Current.HelpText
    if ($timelineHelp -notlike "*Note 对齐 $DisplayName") {
        throw "Timeline did not expose active Note anchor '$DisplayName'."
    }
    if ([string]$anchorModes[$ActiveId] -cne $ActiveMode) {
        throw "Anchor evidence mapping drifted for $ActiveId."
    }
    return [ordered]@{
        activeAutomationId = $ActiveId
        activeMode = $ActiveMode
        displayName = $DisplayName
        buttonHelpText = $buttonStates
        timelineHelpText = $timelineHelp
    }
}

function Start-SettingsClient(
    [string]$RuntimePath,
    [string]$Profile,
    [string]$ApplicationFullPath,
    [string]$ChartUnderTest,
    [string]$LocalDataRoot,
    [string]$EditingRoot,
    [string]$WorkspaceRoot,
    [string]$DotnetHome,
    [string]$NugetPackages,
    [string]$NugetHttpCache,
    [string]$ProjectTemp) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $ApplicationFullPath
    $start.UseShellExecute = $false
    $start.WorkingDirectory = Split-Path -Parent $ApplicationFullPath
    $start.ArgumentList.Add("--evidence-chart")
    $start.ArgumentList.Add($ChartUnderTest)
    $start.ArgumentList.Add("--evidence-output")
    $start.ArgumentList.Add($RuntimePath)
    $start.ArgumentList.Add("--evidence-focus-settings-cache")
    $start.Environment["LUMACHART_PROFILE"] = $Profile
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $LocalDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $EditingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $WorkspaceRoot
    $start.Environment["DOTNET_CLI_HOME"] = $DotnetHome
    $start.Environment["NUGET_PACKAGES"] = $NugetPackages
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = $NugetHttpCache
    $start.Environment["TEMP"] = $ProjectTemp
    $start.Environment["TMP"] = $ProjectTemp
    $client = [Diagnostics.Process]::Start($start)
    if (-not $client) {
        throw "Unable to start Windows Avalonia settings/anchor client."
    }
    return $client
}

function Stop-SettingsClientPhysically(
    [Diagnostics.Process]$Client,
    [IntPtr]$Handle) {
    Set-ForegroundWindowVerified $Handle
    [LumaChartSettingsAnchorGuiNative]::PressAltF4()
    Wait-Condition -Description "settings client exit" -Condition {
        $Client.Refresh()
        $Client.HasExited
    }
    if ($Client.ExitCode -ne 0) {
        throw "Settings client exited with code $($Client.ExitCode)."
    }
}

$expectedFocusOrder = @(
    "Settings.Snap",
    "Settings.AnchorLine",
    "Settings.AnchorLineAbove",
    "Settings.AnchorCell",
    "Settings.AnchorCellBottom",
    "Settings.GridLaneWidth",
    "Settings.MainEditorHorizontalOffset",
    "Settings.GridBeatHeight",
    "Settings.NoteWidth",
    "Settings.NoteHeight",
    "Settings.NoteOpacity",
    "Settings.JudgementLinePosition",
    "Settings.JudgementLineThickness",
    "Settings.JudgementLineOpacity",
    "Settings.ProEditorColumns",
    "Settings.UiScale",
    "Settings.FontScale",
    "FrameRateLimitBox",
    "Settings.ResetEditorView",
    "Settings.ResetFloatingLayout",
    "Settings.AutoBackupEnabled",
    "Settings.AutoBackupMinutes",
    "Settings.BackupNow",
    "Settings.RestoreBackup",
    "Settings.OpenBackupFolder",
    "Settings.Cache.Backups",
    "Settings.Cache.UnopenedEditing",
    "Settings.Cache.OnlineResources",
    "Settings.Cache.CleanSelected",
    "Settings.Shortcuts.Reset",
    "Shortcut_New",
    "Shortcut_Open",
    "Shortcut_Save",
    "Shortcut_SaveAs",
    "Shortcut_Undo",
    "Shortcut_Redo",
    "Shortcut_Cut",
    "Shortcut_Copy",
    "Shortcut_Paste",
    "Shortcut_SelectAll",
    "Shortcut_ToolSelect",
    "Shortcut_ToolTap",
    "Shortcut_ToolHold",
    "Shortcut_ToolErase",
    "Shortcut_PlayPause",
    "Shortcut_Delete",
    "Shortcut_StepForward",
    "Shortcut_StepBack",
    "Shortcut_GoHome",
    "Shortcut_TogglePro",
    "Shortcut_ToggleFullscreen",
    "Shortcut_Group0",
    "Shortcut_Group1",
    "Shortcut_Group2",
    "Shortcut_Group3",
    "Shortcut_Group4",
    "Shortcut_Group5",
    "Shortcut_Group6",
    "Shortcut_Group7",
    "Shortcut_Group8",
    "Shortcut_Group9",
    "Audio.Volume",
    "KeySound.Enabled",
    "KeySound.Preset",
    "KeySound.CustomFile",
    "KeySound.Preview",
    "KeySound.Volume",
    "KeySound.LongNoteEnd",
    "KeySound.GlobalOffset",
    "KeySound.ChartOffset",
    "Audio.PreservePitch",
    "Settings.About",
    "Settings.Bilibili",
    "Settings.Sponsor",
    "Settings.CheckForUpdates"
)
if ($expectedFocusOrder.Count -ne 75) {
    throw "Expected settings focus order must contain exactly 75 controls."
}

$anchorCases = @(
    [ordered]@{
        id = "Settings.AnchorLine"
        mode = "GridLine"
        display = "穿线居中"
        screenshot = "anchor-grid-line.png"
    },
    [ordered]@{
        id = "Settings.AnchorLineAbove"
        mode = "LineAbove"
        display = "贴在线上"
        screenshot = "anchor-line-above.png"
    },
    [ordered]@{
        id = "Settings.AnchorCell"
        mode = "CellCenter"
        display = "格内居中"
        screenshot = "anchor-cell-center.png"
    },
    [ordered]@{
        id = "Settings.AnchorCellBottom"
        mode = "CellBottom"
        display = "格内靠下"
        screenshot = "anchor-cell-bottom.png"
    }
)

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
$settingsPath = Join-Path $localDataRoot "editor-view-settings.json"
$fixtureHashBefore =
    (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
$chartHashBefore =
    (Get-FileHash -LiteralPath $chartUnderTest -Algorithm SHA256).Hash
$installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$installerHashBefore =
    (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
$evidencePath = Join-Path $outputFullPath "settings-anchor-gui-evidence.json"
$firstRuntimePath = Join-Path $outputFullPath "settings-anchor-runtime-first.json"
$secondRuntimePath = Join-Path $outputFullPath "settings-anchor-runtime-reopen.json"
$focusStartPath = Join-Path $outputFullPath "settings-focus-start.png"
$focusMiddlePath = Join-Path $outputFullPath "settings-focus-middle.png"
$focusEndPath = Join-Path $outputFullPath "settings-focus-end.png"
$reverseFocusMiddlePath =
    Join-Path $outputFullPath "settings-focus-reverse-middle.png"
$firstClient = $null
$secondClient = $null

try {
    $firstClient = Start-SettingsClient `
        -RuntimePath $firstRuntimePath `
        -Profile "settings-anchor-parity" `
        -ApplicationFullPath $applicationFullPath `
        -ChartUnderTest $chartUnderTest `
        -LocalDataRoot $localDataRoot `
        -EditingRoot $editingRoot `
        -WorkspaceRoot $workspaceRoot `
        -DotnetHome $dotnetHome `
        -NugetPackages $nugetPackages `
        -NugetHttpCache $nugetHttpCache `
        -ProjectTemp $projectTemp
    Wait-Condition -Description "first settings/anchor main window" -Condition {
        $firstClient.Refresh()
        -not $firstClient.HasExited -and
        $firstClient.MainWindowHandle -ne [IntPtr]::Zero
    }
    $firstHandle = $firstClient.MainWindowHandle
    $snap = Get-VisibleElementById $firstClient.Id "Settings.Snap"
    Set-ForegroundWindowVerified $firstHandle
    if ([LumaChartSettingsAnchorGuiNative]::IsTopmostStyleSet($firstHandle)) {
        throw "Settings/anchor client started with a persistent topmost style."
    }

    Set-ForegroundWindowVerified $firstHandle
    $snap.SetFocus()
    Wait-Condition -Description "editable Snap keyboard focus" -Condition {
        $observed =
            Resolve-FocusedAutomationId $firstClient.Id $expectedFocusOrder
        [string]$observed.resolvedAutomationId -ceq "Settings.Snap"
    }
    $valueTargetId = Set-EditableElementValue $snap "1/17"
    Wait-Condition -Description "custom 1/17 snap debounce committed without Enter" -Condition {
        $current = Find-ElementById `
            -ProcessId $firstClient.Id `
            -AutomationId "Settings.Snap" `
            -TimeoutMilliseconds 300
        [string]$current.Current.HelpText -ceq
            "SnapDivision=17; Range=1-1920; Editable=True"
    }

    $anchorRecords = [Collections.Generic.List[object]]::new()
    foreach ($anchorCase in $anchorCases) {
        $button = Get-VisibleElementById $firstClient.Id $anchorCase.id
        $click = Invoke-PhysicalElementClick `
            $button `
            $firstHandle `
            $anchorCase.display
        Wait-Condition -Description "$($anchorCase.mode) anchor activation" -Condition {
            try {
                $candidate = Find-ElementById `
                    -ProcessId $firstClient.Id `
                    -AutomationId $anchorCase.id `
                    -TimeoutMilliseconds 300
                [string]$candidate.Current.HelpText -ceq
                    "NoteAnchor=$($anchorCase.mode); Active=True"
            }
            catch {
                return $false
            }
        }
        $state = Assert-AnchorState `
            -ProcessId $firstClient.Id `
            -ActiveId $anchorCase.id `
            -ActiveMode $anchorCase.mode `
            -DisplayName $anchorCase.display
        $screenshotPath =
            Join-Path $outputFullPath $anchorCase.screenshot
        $state["click"] = $click
        $state["screenshot"] =
            Capture-ScreenWindow $firstHandle $screenshotPath
        $anchorRecords.Add($state)
    }

    Wait-Condition -Description "editor-view settings persistence" -Seconds 10 -Condition {
        if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
            return $false
        }
        try {
            $persisted =
                Get-Content -LiteralPath $settingsPath -Raw |
                ConvertFrom-Json
            return [int]$persisted.SnapDivision -eq 17 -and
                   [int]$persisted.NoteAnchor -eq 3
        }
        catch {
            return $false
        }
    }
    $settingsBeforeFocus =
        Get-Content -LiteralPath $settingsPath -Raw |
        ConvertFrom-Json

    $snap = Get-VisibleElementById $firstClient.Id "Settings.Snap"
    $snap.SetFocus()
    Set-ForegroundWindowVerified $firstHandle
    Wait-Condition -Description "settings focus route start" -Condition {
        $observed =
            Resolve-FocusedAutomationId $firstClient.Id $expectedFocusOrder
        [string]$observed.resolvedAutomationId -ceq "Settings.Snap"
    }

    $focusRecords = [Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $expectedFocusOrder.Count; $index++) {
        if ($index -gt 0) {
            [LumaChartSettingsAnchorGuiNative]::PressTab()
            Start-Sleep -Milliseconds 35
        }
        $expectedId = $expectedFocusOrder[$index]
        $observed =
            Resolve-FocusedAutomationId $firstClient.Id $expectedFocusOrder
        if ([string]$observed.resolvedAutomationId -cne $expectedId) {
            throw (
                "Settings focus mismatch at index ${index}: expected " +
                "'$expectedId', got " +
                "'$($observed.resolvedAutomationId)' " +
                "(raw '$($observed.rawAutomationId)').")
        }
        $focusRecords.Add([ordered]@{
            index = $index
            expectedAutomationId = $expectedId
            rawAutomationId = $observed.rawAutomationId
            resolvedAutomationId = $observed.resolvedAutomationId
            ancestorDepth = $observed.ancestorDepth
            name = $observed.name
        })
        if ($index -eq 0) {
            Start-Sleep -Milliseconds 300
            $focusStartCapture =
                Capture-ScreenWindow $firstHandle $focusStartPath
        }
        elseif ($index -eq 37) {
            Start-Sleep -Milliseconds 300
            $focusMiddleCapture =
                Capture-ScreenWindow $firstHandle $focusMiddlePath
        }
        elseif ($index -eq 74) {
            Start-Sleep -Milliseconds 300
            $focusEndCapture =
                Capture-ScreenWindow $firstHandle $focusEndPath
        }
    }
    $reverseFocusRecords = [Collections.Generic.List[object]]::new()
    for ($reverseIndex = $expectedFocusOrder.Count - 1;
         $reverseIndex -ge 0;
         $reverseIndex--) {
        if ($reverseIndex -lt $expectedFocusOrder.Count - 1) {
            [LumaChartSettingsAnchorGuiNative]::PressShiftTab()
            Start-Sleep -Milliseconds 35
        }
        $expectedId = $expectedFocusOrder[$reverseIndex]
        $observed =
            Resolve-FocusedAutomationId $firstClient.Id $expectedFocusOrder
        if ([string]$observed.resolvedAutomationId -cne $expectedId) {
            throw (
                "Settings reverse focus mismatch at index ${reverseIndex}: " +
                "expected '$expectedId', got " +
                "'$($observed.resolvedAutomationId)' " +
                "(raw '$($observed.rawAutomationId)').")
        }
        $reverseFocusRecords.Add([ordered]@{
            traversalIndex =
                $expectedFocusOrder.Count - 1 - $reverseIndex
            expectedForwardIndex = $reverseIndex
            expectedAutomationId = $expectedId
            rawAutomationId = $observed.rawAutomationId
            resolvedAutomationId = $observed.resolvedAutomationId
            ancestorDepth = $observed.ancestorDepth
            name = $observed.name
        })
        if ($reverseIndex -eq 37) {
            Start-Sleep -Milliseconds 300
            $reverseFocusMiddleCapture =
                Capture-ScreenWindow $firstHandle $reverseFocusMiddlePath
        }
    }
    if ([LumaChartSettingsAnchorGuiNative]::IsTopmostStyleSet($firstHandle)) {
        throw "Physical focus traversal gained a persistent topmost style."
    }

    Stop-SettingsClientPhysically $firstClient $firstHandle
    $firstClient = $null

    $secondClient = Start-SettingsClient `
        -RuntimePath $secondRuntimePath `
        -Profile "settings-anchor-parity-reopen" `
        -ApplicationFullPath $applicationFullPath `
        -ChartUnderTest $chartUnderTest `
        -LocalDataRoot $localDataRoot `
        -EditingRoot $editingRoot `
        -WorkspaceRoot $workspaceRoot `
        -DotnetHome $dotnetHome `
        -NugetPackages $nugetPackages `
        -NugetHttpCache $nugetHttpCache `
        -ProjectTemp $projectTemp
    Wait-Condition -Description "reopened settings/anchor main window" -Condition {
        $secondClient.Refresh()
        -not $secondClient.HasExited -and
        $secondClient.MainWindowHandle -ne [IntPtr]::Zero
    }
    $secondHandle = $secondClient.MainWindowHandle
    $reopenedSnap = Get-VisibleElementById $secondClient.Id "Settings.Snap"
    $reopenedSnapHelp = [string]$reopenedSnap.Current.HelpText
    if ($reopenedSnapHelp -cne
        "SnapDivision=17; Range=1-1920; Editable=True") {
        throw "Reopened custom Snap division was not 17."
    }
    $reopenedAnchor = Assert-AnchorState `
        -ProcessId $secondClient.Id `
        -ActiveId "Settings.AnchorCellBottom" `
        -ActiveMode "CellBottom" `
        -DisplayName "格内靠下"
    if ([LumaChartSettingsAnchorGuiNative]::IsTopmostStyleSet($secondHandle)) {
        throw "Reopened settings client gained a persistent topmost style."
    }
    Stop-SettingsClientPhysically $secondClient $secondHandle
    $secondClient = $null

    $settingsAfterReopen =
        Get-Content -LiteralPath $settingsPath -Raw |
        ConvertFrom-Json
    $fixtureHashAfter =
        (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
    $chartHashAfter =
        (Get-FileHash -LiteralPath $chartUnderTest -Algorithm SHA256).Hash
    $installerHashAfter =
        (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
    if ($fixtureHashAfter -cne $fixtureHashBefore) {
        throw "Real MC fixture changed during settings/anchor GUI acceptance."
    }
    if ($chartHashAfter -cne $chartHashBefore) {
        throw "Settings/anchor GUI acceptance mutated the isolated chart."
    }
    if ($installerHashAfter -cne $installerHashBefore) {
        throw "Frozen WPF installer changed during settings/anchor GUI acceptance."
    }

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.settings-anchor-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        platform = "Windows Avalonia only"
        buildMode = "ordinary .NET Release"
        windowsAvaloniaOnly = $true
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        customSnap = [ordered]@{
            requestedText = "1/17"
            committedWithoutEnter = $true
            commitTrigger = "editable ComboBox TextChanged debounce"
            valuePatternTargetAutomationId = $valueTargetId
            physicalFocusTransitionAfterCommit = $anchorRecords[0].click
            settingsPath = $settingsPath
            persistedSnapDivisionBeforeReopen =
                [int]$settingsBeforeFocus.SnapDivision
            persistedSnapDivisionAfterReopen =
                [int]$settingsAfterReopen.SnapDivision
            reopenedHelpText = $reopenedSnapHelp
        }
        noteAnchors = [ordered]@{
            physicalClickCount = $anchorRecords.Count
            uniqueTimelineSurface = $true
            notePerAvaloniaControl = $false
            cases = @($anchorRecords)
            persistedFinalModeValue =
                [int]$settingsAfterReopen.NoteAnchor
            reopenedFinalState = $reopenedAnchor
        }
        settingsFocus = [ordered]@{
            physicalTabKeyCount = 74
            physicalShiftTabKeyCount = 74
            expectedControlCount = $expectedFocusOrder.Count
            exactOrderPassed = $true
            exactForwardOrderPassed = $true
            exactReverseOrderPassed = $true
            startCapture = $focusStartCapture
            middleCapture = $focusMiddleCapture
            endCapture = $focusEndCapture
            reverseMiddleCapture = $reverseFocusMiddleCapture
            records = @($focusRecords)
            forwardRecords = @($focusRecords)
            reverseRecords = @($reverseFocusRecords)
        }
        nonTopmost = [ordered]@{
            firstClient = $true
            duringPhysicalFocusTraversal = $true
            reopenedClient = $true
        }
        chart = [ordered]@{
            sourceFixture = $fixtureFullPath
            sourceFixtureSha256Before = $fixtureHashBefore
            sourceFixtureSha256After = $fixtureHashAfter
            isolatedChart = $chartUnderTest
            isolatedChartSha256Before = $chartHashBefore
            isolatedChartSha256After = $chartHashAfter
        }
        installer = [ordered]@{
            path = $installerPath
            sha256Before = $installerHashBefore
            sha256After = $installerHashAfter
        }
        migrationComplete = $false
        remainingDifferences = @(
            "The complete Windows parity matrix remains open.",
            "Real osu in-place save still requires physical GUI acceptance.",
            "Performance, installer/security and remaining online gates still require formal closure.",
            "User replacement approval has not been granted.")
    }
    $evidence |
        ConvertTo-Json -Depth 18 |
        Set-Content -LiteralPath $evidencePath -Encoding UTF8
    Write-Host "Windows Avalonia settings/anchor GUI acceptance: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    foreach ($client in @($firstClient, $secondClient)) {
        if ($client -and -not $client.HasExited) {
            try {
                [LumaChartSettingsAnchorGuiNative]::ForceNonTopmost(
                    $client.MainWindowHandle) | Out-Null
            }
            catch { }
            try {
                $client.CloseMainWindow() | Out-Null
                if (-not $client.WaitForExit(5000)) {
                    $client.Kill($true)
                    $client.WaitForExit()
                }
            }
            catch { }
        }
    }
}
