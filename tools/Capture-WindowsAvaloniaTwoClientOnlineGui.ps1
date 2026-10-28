param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ServerAssemblyPath = (Join-Path $PSScriptRoot "WindowsAvaloniaOnlineGuiServer\bin\Release\net8.0\WindowsAvaloniaOnlineGuiServer.dll"),
    [string]$ProbeAssemblyPath = (Join-Path $PSScriptRoot "WindowsAudioLoopbackProbe\bin\Release\net8.0-windows\WindowsAudioLoopbackProbe.dll"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [switch]$HiddenInvitationOnly,
    [switch]$HiddenObserverOnly,
    [switch]$ResilienceOnly,
    [switch]$ServerRestartOnly,
    [switch]$ClientRestartOnly,
    [switch]$LeaseRecoveryOnly,
    [switch]$ResourceResilienceOnly,
    [switch]$ResourceRevisionOnly,
    [switch]$LateResponseOnly,
    [switch]$LifecycleOnly,
    [switch]$ApplicationCloseRetentionOnly,
    [switch]$MultiLockOnly,
    [switch]$PermissionChangeOnly,
    [switch]$RolePresentationOnly,
    [switch]$PermissionActionOnly,
    [switch]$PermissionVariableTempoOnly,
    [switch]$MetadataPreviewRaceOnly,
    [switch]$CreatorMarkerOnly,
    [switch]$RoomChatPanelOnly,
    [switch]$KeySoundLoopbackOnly,
    [switch]$AutomationDiagnostic,
    [switch]$FormalMigrationAuthority,
    [ValidateRange(60, 300)][int]$TimeoutSeconds = 150
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia two-client GUI capture requires PowerShell Core on Windows."
}
if (([int][bool]$HiddenInvitationOnly + [int][bool]$HiddenObserverOnly +
        [int][bool]$ResilienceOnly + [int][bool]$ResourceResilienceOnly +
        [int][bool]$ResourceRevisionOnly +
        [int][bool]$ServerRestartOnly +
        [int][bool]$ClientRestartOnly +
        [int][bool]$LeaseRecoveryOnly +
        [int][bool]$LateResponseOnly + [int][bool]$LifecycleOnly +
        [int][bool]$ApplicationCloseRetentionOnly +
        [int][bool]$MultiLockOnly + [int][bool]$PermissionChangeOnly +
        [int][bool]$RolePresentationOnly +
        [int][bool]$PermissionActionOnly +
        [int][bool]$PermissionVariableTempoOnly +
        [int][bool]$MetadataPreviewRaceOnly +
        [int][bool]$CreatorMarkerOnly +
        [int][bool]$RoomChatPanelOnly +
        [int][bool]$KeySoundLoopbackOnly) -gt 1) {
    throw "Choose only one focused two-client GUI mode."
}
if (($ResilienceOnly -or $ResourceRevisionOnly -or
        $ServerRestartOnly -or $ClientRestartOnly -or $LeaseRecoveryOnly -or
        $LateResponseOnly -or
        $LifecycleOnly -or $ApplicationCloseRetentionOnly -or $MultiLockOnly -or
        $PermissionChangeOnly -or $PermissionActionOnly -or
        $PermissionVariableTempoOnly -or $MetadataPreviewRaceOnly -or
        $CreatorMarkerOnly) -and
    $AutomationDiagnostic) {
    throw "ResilienceOnly, ResourceRevisionOnly, ServerRestartOnly, ClientRestartOnly, LeaseRecoveryOnly, LateResponseOnly, LifecycleOnly, ApplicationCloseRetentionOnly, MultiLockOnly, PermissionChangeOnly, PermissionActionOnly, PermissionVariableTempoOnly, MetadataPreviewRaceOnly and CreatorMarkerOnly are formal physical-input gates and cannot use AutomationDiagnostic."
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
        [int]$PollMilliseconds = 100
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try { if (& $Condition) { return } } catch { }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

function Wait-File([string]$Path, [string]$Description, [int]$Seconds = $TimeoutSeconds) {
    Wait-Condition -Description $Description -Seconds $Seconds -Condition {
        (Test-Path -LiteralPath $Path -PathType Leaf) -and (Get-Item -LiteralPath $Path).Length -gt 0
    }
}

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$serverAssemblyFullPath = Resolve-ExistingFile $ServerAssemblyPath "Loopback GUI server"
$probeAssemblyFullPath = if ($KeySoundLoopbackOnly) {
    Resolve-ExistingFile $ProbeAssemblyPath "WASAPI loopback probe"
} else { $null }
$fixtureFullPath = Resolve-ExistingFile $ChartFixturePath "Real MC fixture"
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $outputFullPath) { throw "Output root already exists: $outputFullPath" }
New-Item -ItemType Directory -Path $outputFullPath | Out-Null

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$projectTemp = Join-Path $projectRoot ".codex-temp"
$dotnetHome = Join-Path $projectRoot ".codex-dotnet-home"
$nugetPackages = Join-Path $projectRoot ".codex-nuget-packages"
$nugetHttpCache = Join-Path $projectRoot ".codex-nuget-http-cache"
$loopbackSoundName = "LumaChart-room-note-key-sound.wav"
$loopbackSoundSha256 =
    "C0D0F473C26A4FC626C8BE503333DDAC124C2CB5D06D7191A0A5015563B81381"
foreach ($directory in @($projectTemp, $dotnetHome, $nugetPackages, $nugetHttpCache)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}
$env:DOTNET_CLI_HOME = $dotnetHome
$env:NUGET_PACKAGES = $nugetPackages
$env:NUGET_HTTP_CACHE_PATH = $nugetHttpCache
$env:TEMP = $projectTemp
$env:TMP = $projectTemp

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Security.Cryptography.ProtectedData
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartTwoClientGuiNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT { public uint Type; public MOUSEINPUT Mouse; }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT
    {
        public int X;
        public int Y;
        public uint MouseData;
        public uint Flags;
        public uint Time;
        public UIntPtr ExtraInfo;
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern uint GetDpiForWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr window, IntPtr deviceContext, uint flags);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT point);

    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int index);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint count, INPUT[] inputs, int size);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

    public const uint MouseLeftDown = 0x0002;
    public const uint MouseLeftUp = 0x0004;
    public const uint MouseWheel = 0x0800;
    public const uint MouseMove = 0x0001;
    public const uint MouseAbsolute = 0x8000;
    public const uint MouseVirtualDesk = 0x4000;

    public static bool SendAbsoluteMouseMove(int x, int y)
    {
        var left = GetSystemMetrics(76);
        var top = GetSystemMetrics(77);
        var width = GetSystemMetrics(78);
        var height = GetSystemMetrics(79);
        if (width <= 1 || height <= 1) return false;
        var absoluteX = (int)Math.Round((x - left) * 65535.0 / (width - 1));
        var absoluteY = (int)Math.Round((y - top) * 65535.0 / (height - 1));
        absoluteX = Math.Max(0, Math.Min(65535, absoluteX));
        absoluteY = Math.Max(0, Math.Min(65535, absoluteY));
        var input = new INPUT
        {
            Type = 0,
            Mouse = new MOUSEINPUT
            {
                X = absoluteX,
                Y = absoluteY,
                Flags = MouseMove | MouseAbsolute | MouseVirtualDesk
            }
        };
        return SendInput(1, new[] { input }, Marshal.SizeOf<INPUT>()) == 1;
    }

    public static bool SendMouseButton(uint flags)
    {
        var input = new INPUT
        {
            Type = 0,
            Mouse = new MOUSEINPUT { Flags = flags }
        };
        return SendInput(1, new[] { input }, Marshal.SizeOf<INPUT>()) == 1;
    }

    public static bool SendMouseWheel(int delta)
    {
        var input = new INPUT
        {
            Type = 0,
            Mouse = new MOUSEINPUT
            {
                MouseData = unchecked((uint)delta),
                Flags = MouseWheel
            }
        };
        return SendInput(1, new[] { input }, Marshal.SizeOf<INPUT>()) == 1;
    }
}
'@

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 300000)][int]$TimeoutMilliseconds = 10000
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

function Find-VisibleElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 300000)][int]$TimeoutMilliseconds = 5000
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
                $candidates = [Collections.Generic.List[object]]::new()
                if ([string]$root.Current.AutomationId -ceq $AutomationId) {
                    $candidates.Add($root)
                }
                foreach ($candidate in $root.FindAll(
                        [Windows.Automation.TreeScope]::Descendants, $idCondition)) {
                    $candidates.Add($candidate)
                }
                foreach ($candidate in $candidates) {
                    $bounds = $candidate.Current.BoundingRectangle
                    if (-not $candidate.Current.IsOffscreen -and
                        [double]::IsFinite($bounds.Left) -and
                        [double]::IsFinite($bounds.Top) -and
                        [double]::IsFinite($bounds.Width) -and
                        [double]::IsFinite($bounds.Height) -and
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
    throw "Timed out finding visible UI Automation id '$AutomationId' for process $ProcessId."
}

function Find-ElementByIdAndNameLike {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][string]$Like,
        [ValidateRange(100, 300000)][int]$TimeoutMilliseconds = 10000
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
                if ([string]$root.Current.AutomationId -ceq $AutomationId -and
                    [string]$root.Current.Name -like $Like) { return $root }
                $candidates = $root.FindAll(
                    [Windows.Automation.TreeScope]::Descendants, $idCondition)
                foreach ($candidate in $candidates) {
                    if ([string]$candidate.Current.Name -like $Like) { return $candidate }
                }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' with name '$Like' for process $ProcessId."
}

function Find-ElementsById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId)
    $results = [Collections.Generic.List[object]]::new()
    $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
        [Windows.Automation.TreeScope]::Children, $processCondition)
    foreach ($root in $roots) {
        if ([string]$root.Current.AutomationId -ceq $AutomationId) { $results.Add($root) }
        foreach ($candidate in $root.FindAll([Windows.Automation.TreeScope]::Descendants, $idCondition)) {
            $results.Add($candidate)
        }
    }
    return $results.ToArray()
}

function Find-ElementByIdPrefix {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Prefix,
        [string]$Suffix = "",
        [ValidateRange(100, 300000)][int]$TimeoutMilliseconds = 10000
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children, $processCondition)
            foreach ($root in $roots) {
                $all = $root.FindAll(
                    [Windows.Automation.TreeScope]::Descendants,
                    [Windows.Automation.Condition]::TrueCondition)
                foreach ($candidate in $all) {
                    $id = [string]$candidate.Current.AutomationId
                    if ($id.StartsWith($Prefix, [StringComparison]::Ordinal) -and
                        $id.EndsWith($Suffix, [StringComparison]::Ordinal)) { return $candidate }
                }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id prefix '$Prefix' suffix '$Suffix'."
}

function Find-ElementByName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [ValidateRange(100, 300000)][int]$TimeoutMilliseconds = 10000
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
                $candidate = $root.FindFirst([Windows.Automation.TreeScope]::Descendants, $nameCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation name '$Name' for process $ProcessId."
}

function Observe-Element($Element) {
    $bounds = $Element.Current.BoundingRectangle
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        controlType = [string]$Element.Current.ControlType.ProgrammaticName
        helpText = [string]$Element.Current.HelpText
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

function Find-UiAutomationSecretExposure(
    [int]$ProcessId,
    [Parameter(Mandatory = $true)][string]$Secret) {
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $matches = [Collections.Generic.List[string]]::new()
    $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
        [Windows.Automation.TreeScope]::Children, $processCondition)
    foreach ($root in $roots) {
        $elements = @($root) + @($root.FindAll(
            [Windows.Automation.TreeScope]::Descendants,
            [Windows.Automation.Condition]::TrueCondition))
        foreach ($element in $elements) {
            foreach ($value in @(
                    [string]$element.Current.Name,
                    [string]$element.Current.HelpText)) {
                if (-not [string]::IsNullOrEmpty($value) -and
                    $value.Contains($Secret, [StringComparison]::Ordinal)) {
                    $matches.Add("$([string]$element.Current.AutomationId):$value")
                }
            }
        }
    }
    return $matches.ToArray()
}

function Invoke-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Invoke-DiagnosticElement($Element) {
    $pattern = $null
    if ($Element.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        ([Windows.Automation.InvokePattern]$pattern).Invoke()
        return
    }
    if ($Element.TryGetCurrentPattern([Windows.Automation.TogglePattern]::Pattern, [ref]$pattern)) {
        ([Windows.Automation.TogglePattern]$pattern).Toggle()
        return
    }
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.ExpandCollapsePattern]::Pattern,
            [ref]$pattern)) {
        $expand =
            ([Windows.Automation.ExpandCollapsePattern]$pattern)
        if ($expand.Current.ExpandCollapseState -eq
            [Windows.Automation.ExpandCollapseState]::Collapsed) {
            $expand.Expand()
        } else {
            $expand.Collapse()
        }
        return
    }
    if ($Element.TryGetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pattern)) {
        ([Windows.Automation.SelectionItemPattern]$pattern).Select()
        return
    }
    throw "Element '$($Element.Current.AutomationId)' exposes no diagnostic Invoke/Toggle/SelectionItem pattern."
}

function Get-ElementToggleState($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.TogglePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' exposes no TogglePattern."
    }
    return ([Windows.Automation.TogglePattern]$pattern).Current.ToggleState
}

function Get-ElementSelectedItem($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.SelectionPattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' exposes no SelectionPattern."
    }
    $selection =
        ([Windows.Automation.SelectionPattern]$pattern).Current.GetSelection()
    if (@($selection).Count -ne 1) {
        throw "Element '$($Element.Current.AutomationId)' does not have exactly one selected item."
    }
    return $selection[0]
}

function Set-ElementValue($Element, [string]$Value) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose ValuePattern."
    }
    ([Windows.Automation.ValuePattern]$pattern).SetValue($Value)
}

function Get-ElementValue($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose ValuePattern."
    }
    return [string]([Windows.Automation.ValuePattern]$pattern).Current.Value
}

function Get-ElementRangeValue($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.RangeValuePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose RangeValuePattern."
    }
    $range = [Windows.Automation.RangeValuePattern]$pattern
    return [ordered]@{
        value = [double]$range.Current.Value
        minimum = [double]$range.Current.Minimum
        maximum = [double]$range.Current.Maximum
        smallChange = [double]$range.Current.SmallChange
        largeChange = [double]$range.Current.LargeChange
        isReadOnly = [bool]$range.Current.IsReadOnly
    }
}

function Set-ElementRangeValue($Element, [double]$Value) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.RangeValuePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose RangeValuePattern."
    }
    $range = [Windows.Automation.RangeValuePattern]$pattern
    if ($range.Current.IsReadOnly) {
        throw "Element '$($Element.Current.AutomationId)' exposes a read-only RangeValuePattern."
    }
    $bounded = [Math]::Clamp(
        $Value,
        [double]$range.Current.Minimum,
        [double]$range.Current.Maximum)
    try { $Element.SetFocus() } catch { }
    $range.SetValue($bounded)
    return $bounded
}

function Get-DiagnosticInt64([string]$Text, [string]$Name) {
    $match = [regex]::Match(
        $Text,
        "(?i)(?:^|;\s*)$([regex]::Escape($Name))=(-?\d+)")
    if (-not $match.Success) {
        throw "Diagnostic '$Name' is missing from '$Text'."
    }
    return [int64]::Parse(
        $match.Groups[1].Value,
        [Globalization.CultureInfo]::InvariantCulture)
}

function Get-DiagnosticBoolean([string]$Text, [string]$Name) {
    $match = [regex]::Match(
        $Text,
        "(?i)(?:^|;\s*)$([regex]::Escape($Name))=(true|false)")
    if (-not $match.Success) {
        throw "Diagnostic '$Name' is missing from '$Text'."
    }
    return [bool]::Parse($match.Groups[1].Value)
}

function Get-KeySoundRuntimeDiagnostics([int]$ProcessId) {
    $element = Find-ElementById -ProcessId $ProcessId `
        -AutomationId "KeySound.RuntimeStatus" -TimeoutMilliseconds 10000
    $helpText = [string]$element.Current.HelpText
    return [ordered]@{
        element = Observe-Element $element
        preparing = Get-DiagnosticBoolean $helpText "Preparing"
        hasPlan = Get-DiagnosticBoolean $helpText "HasPlan"
        enabled = Get-DiagnosticBoolean $helpText "Enabled"
        planEvents = Get-DiagnosticInt64 $helpText "PlanEvents"
        planPreloads = Get-DiagnosticInt64 $helpText "PlanPreloads"
        planFailures = Get-DiagnosticInt64 $helpText "PlanFailures"
        preloadAccepted = Get-DiagnosticInt64 $helpText "PreloadAccepted"
        preloadRejected = Get-DiagnosticInt64 $helpText "PreloadRejected"
        previewAccepted = Get-DiagnosticInt64 $helpText "PreviewAccepted"
        previewRejected = Get-DiagnosticInt64 $helpText "PreviewRejected"
        triggersDue = Get-DiagnosticInt64 $helpText "TriggersDue"
        triggersAccepted = Get-DiagnosticInt64 $helpText "TriggersAccepted"
        triggersRejected = Get-DiagnosticInt64 $helpText "TriggersRejected"
        sharedAccepted = Get-DiagnosticInt64 $helpText "SharedAccepted"
        sharedRejected = Get-DiagnosticInt64 $helpText "SharedRejected"
        standaloneAccepted = Get-DiagnosticInt64 $helpText "StandaloneAccepted"
        standaloneRejected = Get-DiagnosticInt64 $helpText "StandaloneRejected"
    }
}

function Show-ElementInScrollViewport(
    $Element,
    [ValidateRange(0, 100)][double]$FallbackVerticalPercent = 100) {
    $automationId = [string]$Element.Current.AutomationId
    $processId = [int]$Element.Current.ProcessId
    $scrolled = $false
    $scrollItemPattern = $null
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.ScrollItemPattern]::Pattern,
            [ref]$scrollItemPattern)) {
        ([Windows.Automation.ScrollItemPattern]$scrollItemPattern).ScrollIntoView()
        $scrolled = $true
    }
    $walker = [Windows.Automation.TreeWalker]::ControlViewWalker
    $ancestor = $Element
    for ($depth = 0; $depth -lt 12 -and $ancestor; $depth++) {
        $scrollPattern = $null
        if ($ancestor.TryGetCurrentPattern(
                [Windows.Automation.ScrollPattern]::Pattern,
                [ref]$scrollPattern)) {
            $scroll = [Windows.Automation.ScrollPattern]$scrollPattern
            if ($scroll.Current.VerticallyScrollable) {
                $horizontal = if ($scroll.Current.HorizontallyScrollable) {
                    $scroll.Current.HorizontalScrollPercent
                } else {
                    [Windows.Automation.ScrollPattern]::NoScroll
                }
                $scroll.SetScrollPercent($horizontal, $FallbackVerticalPercent)
                $scrolled = $true
                break
            }
        }
        $ancestor = $walker.GetParent($ancestor)
    }
    if (-not $scrolled) {
        throw "Element '$automationId' exposes neither ScrollItemPattern nor a scrollable ancestor."
    }
    Start-Sleep -Milliseconds 500
    return Find-ElementById -ProcessId $processId `
        -AutomationId $automationId -TimeoutMilliseconds 5000
}

function Get-TimelineLiveState([int]$ProcessId) {
    $surface = Find-ElementById -ProcessId $ProcessId `
        -AutomationId "Timeline.Surface" -TimeoutMilliseconds 10000
    $helpText = [string]$surface.Current.HelpText
    $values = @{}
    foreach ($part in $helpText.Split(';', [StringSplitOptions]::RemoveEmptyEntries)) {
        $pair = $part.Trim().Split('=', 2, [StringSplitOptions]::TrimEntries)
        if ($pair.Count -eq 2) { $values[$pair[0]] = $pair[1] }
    }
    foreach ($required in @(
            'CurrentBeat', 'PixelsPerBeat', 'SnapDivision',
            'SelectedNoteCount', 'SelectedTimingCount',
            'OwnerProtectedRegionCount', 'SelectedNoteId',
            'SelectedNoteLane', 'SelectedNoteBeat', 'OnlineCreatorCount',
            'OnlineCreatorAvatarCount', 'CreatorAttributedNoteCount',
            'CreatorAttributedTimingCount', 'LastCreatorHoverUserId',
            'CreatorHoverTooltip', 'CreatorMarkersPlaybackSuppressed',
            'RoomSyncWorkStatus', 'RoomSyncFeedStatus', 'RoomSyncRevision',
            'RoomSyncPendingOperationId', 'RoomSyncConsecutiveWorkFailures',
            'RoomSyncConsecutiveFeedFailures')) {
        if (-not $values.ContainsKey($required)) {
            throw "Timeline UIA help text did not expose '$required': $helpText"
        }
    }
    $currentBeat = 0.0
    $pixelsPerBeat = 0.0
    $snapDivision = 0
    $selectedLane = -1
    $selectedNoteCount = -1
    $selectedTimingCount = -1
    $ownerProtectedRegionCount = -1
    $onlineCreatorCount = -1
    $onlineCreatorAvatarCount = -1
    $creatorAttributedNoteCount = -1
    $creatorAttributedTimingCount = -1
    $lastCreatorHoverUserId = -1L
    $creatorMarkersPlaybackSuppressed = $false
    $roomSyncRevision = -1L
    $roomSyncConsecutiveWorkFailures = -1
    $roomSyncConsecutiveFeedFailures = -1
    if (-not [double]::TryParse(
            [string]$values.CurrentBeat,
            [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$currentBeat) -or
        -not [double]::TryParse(
            [string]$values.PixelsPerBeat,
            [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$pixelsPerBeat) -or
        -not [int]::TryParse(
            [string]$values.SnapDivision,
            [Globalization.NumberStyles]::Integer,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$snapDivision) -or
        -not [int]::TryParse(
            [string]$values.SelectedNoteLane,
            [Globalization.NumberStyles]::Integer,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$selectedLane) -or
        -not [int]::TryParse(
            [string]$values.SelectedNoteCount,
            [Globalization.NumberStyles]::Integer,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$selectedNoteCount) -or
        -not [int]::TryParse(
            [string]$values.SelectedTimingCount,
            [Globalization.NumberStyles]::Integer,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$selectedTimingCount) -or
        -not [int]::TryParse(
            [string]$values.OwnerProtectedRegionCount,
            [Globalization.NumberStyles]::Integer,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$ownerProtectedRegionCount) -or
        -not [int]::TryParse(
            [string]$values.OnlineCreatorCount,
            [Globalization.NumberStyles]::Integer,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$onlineCreatorCount) -or
        -not [int]::TryParse(
            [string]$values.OnlineCreatorAvatarCount,
            [Globalization.NumberStyles]::Integer,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$onlineCreatorAvatarCount) -or
        -not [int]::TryParse(
            [string]$values.CreatorAttributedNoteCount,
            [Globalization.NumberStyles]::Integer,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$creatorAttributedNoteCount) -or
        -not [int]::TryParse(
            [string]$values.CreatorAttributedTimingCount,
            [Globalization.NumberStyles]::Integer,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$creatorAttributedTimingCount) -or
        -not [long]::TryParse(
            [string]$values.LastCreatorHoverUserId,
            [Globalization.NumberStyles]::Integer,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$lastCreatorHoverUserId) -or
        -not [bool]::TryParse(
            [string]$values.CreatorMarkersPlaybackSuppressed,
            [ref]$creatorMarkersPlaybackSuppressed) -or
        -not [long]::TryParse(
            [string]$values.RoomSyncRevision,
            [Globalization.NumberStyles]::Integer,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$roomSyncRevision) -or
        -not [int]::TryParse(
            [string]$values.RoomSyncConsecutiveWorkFailures,
            [Globalization.NumberStyles]::Integer,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$roomSyncConsecutiveWorkFailures) -or
        -not [int]::TryParse(
            [string]$values.RoomSyncConsecutiveFeedFailures,
            [Globalization.NumberStyles]::Integer,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$roomSyncConsecutiveFeedFailures) -or
        -not [double]::IsFinite($currentBeat) -or
        -not [double]::IsFinite($pixelsPerBeat) -or $pixelsPerBeat -le 0 -or
        $snapDivision -lt 1 -or
        $selectedNoteCount -lt 0 -or $selectedTimingCount -lt 0 -or
        $ownerProtectedRegionCount -lt 0 -or $onlineCreatorCount -lt 0 -or
        $onlineCreatorAvatarCount -lt 0 -or $creatorAttributedNoteCount -lt 0 -or
        $creatorAttributedTimingCount -lt 0 -or $lastCreatorHoverUserId -lt 0 -or
        $roomSyncConsecutiveWorkFailures -lt 0 -or
        $roomSyncConsecutiveFeedFailures -lt 0) {
        throw "Timeline UIA help text contained invalid live geometry: $helpText"
    }
    return [ordered]@{
        currentBeat = $currentBeat
        pixelsPerBeat = $pixelsPerBeat
        snapDivision = $snapDivision
        selectedNoteCount = $selectedNoteCount
        selectedTimingCount = $selectedTimingCount
        ownerProtectedRegionCount = $ownerProtectedRegionCount
        onlineCreatorCount = $onlineCreatorCount
        onlineCreatorAvatarCount = $onlineCreatorAvatarCount
        creatorAttributedNoteCount = $creatorAttributedNoteCount
        creatorAttributedTimingCount = $creatorAttributedTimingCount
        lastCreatorHoverUserId = $lastCreatorHoverUserId
        creatorHoverTooltip = [string]$values.CreatorHoverTooltip
        creatorMarkersPlaybackSuppressed = $creatorMarkersPlaybackSuppressed
        roomSyncWorkStatus = [string]$values.RoomSyncWorkStatus
        roomSyncFeedStatus = [string]$values.RoomSyncFeedStatus
        roomSyncRevision = $roomSyncRevision
        roomSyncPendingOperationId = [string]$values.RoomSyncPendingOperationId
        roomSyncConsecutiveWorkFailures = $roomSyncConsecutiveWorkFailures
        roomSyncConsecutiveFeedFailures = $roomSyncConsecutiveFeedFailures
        selectedNoteId = [string]$values.SelectedNoteId
        selectedNoteLane = $selectedLane
        selectedNoteBeat = [string]$values.SelectedNoteBeat
        helpText = $helpText
    }
}

function Wait-ElementValue(
    [int]$ProcessId,
    [string]$AutomationId,
    [AllowEmptyString()][string]$ExpectedValue,
    [int]$Seconds = 30) {
    $script:waitValueElementResult = $null
    Wait-Condition -Description "'$AutomationId' value '$ExpectedValue'" -Seconds $Seconds -Condition {
        $candidate = Find-ElementById -ProcessId $ProcessId -AutomationId $AutomationId -TimeoutMilliseconds 1000
        if ((Get-ElementValue $candidate) -ceq $ExpectedValue) {
            $script:waitValueElementResult = $candidate
            return $true
        }
        return $false
    }
    $result = $script:waitValueElementResult
    $script:waitValueElementResult = $null
    return $result
}

function Wait-ElementName([int]$ProcessId, [string]$AutomationId, [string]$Like, [int]$Seconds = 30) {
    $result = $null
    Wait-Condition -Description "'$AutomationId' name '$Like'" -Seconds $Seconds -Condition {
        $candidate = Find-ElementById -ProcessId $ProcessId -AutomationId $AutomationId -TimeoutMilliseconds 1000
        if ([string]$candidate.Current.Name -like $Like) { $script:waitElementResult = $candidate; return $true }
        return $false
    }
    $result = $script:waitElementResult
    $script:waitElementResult = $null
    return $result
}

function Wait-EditorSavedState([int]$ProcessId, [int]$Seconds = 30) {
    $script:waitSavedTitleResult = $null
    Wait-Condition -Description "saved title state for process $ProcessId" -Seconds $Seconds -Condition {
        $candidate = Find-ElementByName -ProcessId $ProcessId -Name "· 已保存" -TimeoutMilliseconds 1000
        if ($candidate.Current.IsEnabled -and -not $candidate.Current.IsOffscreen) {
            $script:waitSavedTitleResult = $candidate
            return $true
        }
        return $false
    }
    $result = $script:waitSavedTitleResult
    $script:waitSavedTitleResult = $null
    return $result
}

function Wait-AuthenticatedAccountButton([int]$ProcessId, [string]$IdentityFragment, [int]$Seconds = 30) {
    $script:waitAccountButtonResult = $null
    Wait-Condition -Description "authenticated account button containing '$IdentityFragment'" -Seconds $Seconds -Condition {
        $candidate = Find-ElementById -ProcessId $ProcessId -AutomationId "OnlineAccount.Navigation" -TimeoutMilliseconds 1000
        $name = [string]$candidate.Current.Name
        if ($name -like "*$IdentityFragment*") {
            $script:waitAccountButtonResult = $candidate
            return $true
        }
        return $false
    }
    $result = $script:waitAccountButtonResult
    $script:waitAccountButtonResult = $null
    return $result
}

function Wait-MainWindowHandle([Diagnostics.Process]$Process) {
    $script:waitMainWindowHandleResult = 0L
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $Process.Id)
    Wait-Condition -Description "main window for process $($Process.Id)" -Condition {
        $Process.Refresh()
        if ($Process.HasExited) { return $false }
        $windows = [Windows.Automation.AutomationElement]::RootElement.FindAll(
            [Windows.Automation.TreeScope]::Children,
            $processCondition)
        $bestHandle = 0L
        $bestArea = 0L
        foreach ($window in $windows) {
            $handle = [long]$window.Current.NativeWindowHandle
            if ($handle -eq 0) { continue }
            $rectangle = [LumaChartTwoClientGuiNative+RECT]::new()
            if (-not [LumaChartTwoClientGuiNative]::GetWindowRect(
                    [IntPtr]$handle,
                    [ref]$rectangle)) {
                continue
            }
            $width = $rectangle.Right - $rectangle.Left
            $height = $rectangle.Bottom - $rectangle.Top
            $area = [long]$width * [long]$height
            if ($width -ge 500 -and $height -ge 400 -and $area -gt $bestArea) {
                $bestHandle = $handle
                $bestArea = $area
            }
        }
        if ($bestHandle -ne 0) {
            $script:waitMainWindowHandleResult = $bestHandle
            return $true
        }
        return $false
    }
    $result = [IntPtr]$script:waitMainWindowHandleResult
    $script:waitMainWindowHandleResult = 0L
    return $result
}

function Get-TopLevelWindowHandleForElement(
    [Windows.Automation.AutomationElement]$Element) {
    $current = $Element
    $lastHandle = 0L
    while ($null -ne $current) {
        try {
            $handle = [long]$current.Current.NativeWindowHandle
            if ($handle -ne 0) { $lastHandle = $handle }
            $parent =
                [Windows.Automation.TreeWalker]::RawViewWalker.GetParent($current)
            if ($null -eq $parent -or
                $parent -eq [Windows.Automation.AutomationElement]::RootElement) {
                break
            }
            $current = $parent
        }
        catch {
            break
        }
    }
    if ($lastHandle -eq 0) {
        throw "The UIA element has no native top-level window ancestor."
    }
    return [IntPtr]$lastHandle
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartTwoClientGuiNative+RECT]::new()
    if (-not [LumaChartTwoClientGuiNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    # Main windows are much larger, but the shared WPF 1.1.0-compatible choice
    # dialogs intentionally size to their short copy. Keep a real-window floor
    # without rejecting those owner-modal dialogs.
    if ($width -lt 320 -or $height -lt 180) { throw "Window has invalid bounds: ${width}x${height}." }
    $bitmap = [Drawing.Bitmap]::new($width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $dc = $graphics.GetHdc()
            try {
                if (-not [LumaChartTwoClientGuiNative]::PrintWindow($Handle, $dc, 2)) {
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
                    [Math]::Min($width - 1, [int](($x + .5) * $width / 16)),
                    [Math]::Min($height - 1, [int](($y + .5) * $height / 16)))
                [void]$colors.Add($pixel.ToArgb())
            }
        }
        $minimumSampledColors = if ($AutomationDiagnostic) { 4 } else { 8 }
        if ($colors.Count -lt $minimumSampledColors) {
            throw "Screenshot is near-uniform: $($colors.Count) sampled colors."
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{ width = $width; height = $height; sampledUniqueColors = $colors.Count }
    }
    finally { $bitmap.Dispose() }
}

function Set-PhysicalCursorPosition([int]$X, [int]$Y, [string]$Phase) {
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        if ([LumaChartTwoClientGuiNative]::SetCursorPos($X, $Y)) { return }
        Start-Sleep -Milliseconds (80 * $attempt)
    }
    if ([LumaChartTwoClientGuiNative]::SendAbsoluteMouseMove($X, $Y)) {
        Start-Sleep -Milliseconds 180
        $actual = [LumaChartTwoClientGuiNative+POINT]::new()
        if ([LumaChartTwoClientGuiNative]::GetCursorPos([ref]$actual) -and
            [Math]::Abs($actual.X - $X) -le 2 -and
            [Math]::Abs($actual.Y - $Y) -le 2) {
            return
        }
    }
    $nativeError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    throw "Physical cursor positioning failed during $Phase at ($X,$Y) after SetCursorPos and " +
        "absolute mouse_event fallback; Win32=$nativeError."
}

function Invoke-PhysicalClick([int]$X, [int]$Y, [IntPtr]$ForegroundWindow) {
    [void][LumaChartTwoClientGuiNative]::SetForegroundWindow($ForegroundWindow)
    Start-Sleep -Milliseconds 150
    Set-PhysicalCursorPosition $X $Y "click"
    # SetCursorPos queues a pointer-move message. Let Avalonia consume that move
    # before pressing, otherwise a delayed move can become an unintended drag.
    Start-Sleep -Milliseconds 120
    if (-not [LumaChartTwoClientGuiNative]::SendMouseButton(
            [LumaChartTwoClientGuiNative]::MouseLeftDown)) {
        throw "SendInput failed for physical left-button down."
    }
    Start-Sleep -Milliseconds 70
    if (-not [LumaChartTwoClientGuiNative]::SendMouseButton(
            [LumaChartTwoClientGuiNative]::MouseLeftUp)) {
        throw "SendInput failed for physical left-button up."
    }
}

function Move-PhysicalPointer(
    [int]$X,
    [int]$Y,
    [IntPtr]$ForegroundWindow,
    [int]$SettleMilliseconds = 900) {
    [void][LumaChartTwoClientGuiNative]::SetForegroundWindow($ForegroundWindow)
    Start-Sleep -Milliseconds 180
    Set-PhysicalCursorPosition $X $Y "hover"
    Start-Sleep -Milliseconds $SettleMilliseconds
}

function Invoke-PhysicalElementClick($Element, [IntPtr]$ForegroundWindow) {
    if ($AutomationDiagnostic -or $RolePresentationOnly -or $KeySoundLoopbackOnly) {
        Invoke-DiagnosticElement $Element
        Start-Sleep -Milliseconds 250
        return
    }
    $automationId = [string]$Element.Current.AutomationId
    $automationName = [string]$Element.Current.Name
    $automationHelpText = [string]$Element.Current.HelpText
    $processId = [int]$Element.Current.ProcessId
    $originalBounds = $Element.Current.BoundingRectangle
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        if (-not [string]::IsNullOrWhiteSpace($automationId) -and $processId -gt 0) {
            $candidates = @(
                Find-ElementsById -ProcessId $processId -AutomationId $automationId |
                    Where-Object {
                        try {
                            $candidateBounds = $_.Current.BoundingRectangle
                            -not $_.Current.IsOffscreen -and
                            [double]::IsFinite($candidateBounds.Left) -and
                            [double]::IsFinite($candidateBounds.Top) -and
                            [double]::IsFinite($candidateBounds.Width) -and
                            [double]::IsFinite($candidateBounds.Height) -and
                            $candidateBounds.Width -gt 1 -and
                            $candidateBounds.Height -gt 1
                        }
                        catch {
                            $false
                        }
                    })
            $identityMatches = @($candidates | Where-Object {
                    [string]$_.Current.Name -ceq $automationName -and
                    [string]$_.Current.HelpText -ceq $automationHelpText
                })
            if ($identityMatches.Count -eq 0) {
                $identityMatches = @($candidates | Where-Object {
                        [string]$_.Current.Name -ceq $automationName
                    })
            }
            if ($identityMatches.Count -gt 0) {
                $Element = @($identityMatches | Sort-Object {
                        $bounds = $_.Current.BoundingRectangle
                        [Math]::Abs($bounds.Left - $originalBounds.Left) +
                            [Math]::Abs($bounds.Top - $originalBounds.Top)
                    })[0]
            }
            elseif ($candidates.Count -eq 1) {
                $Element = $candidates[0]
            }
            else {
                Start-Sleep -Milliseconds (100 * $attempt)
                continue
            }
        }
        try { $Element.SetFocus() } catch { }
        Start-Sleep -Milliseconds 90
        try {
            $bounds = $Element.Current.BoundingRectangle
            if ([double]::IsFinite($bounds.Left) -and
                [double]::IsFinite($bounds.Top) -and
                [double]::IsFinite($bounds.Width) -and
                [double]::IsFinite($bounds.Height) -and
                $bounds.Width -gt 1 -and
                $bounds.Height -gt 1) {
                Invoke-PhysicalClick `
                    ([int][Math]::Round($bounds.Left + $bounds.Width / 2)) `
                    ([int][Math]::Round($bounds.Top + $bounds.Height / 2)) `
                    $ForegroundWindow
                return
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 100
    }
    throw "Element '$automationId' was recycled by live room refresh before a stable " +
        "physical-click rectangle could be acquired after five attempts."
}

function Wait-RoomResourceConfirmation(
    [int]$ProcessId,
    [int]$Seconds = 30) {
    Wait-Condition -Description "room resource confirmation is ready" `
        -Seconds $Seconds -Condition {
            try {
                $candidate = Find-ElementById -ProcessId $ProcessId `
                    -AutomationId "OnlineRooms.Active.OpenChart" `
                    -TimeoutMilliseconds 500
                $name = [string]$candidate.Current.Name
                return $candidate.Current.IsEnabled -and
                    ($name -like "*下载并进入*" -or
                     $name -like "*复用并进入*" -or
                     $name -like "*打开谱面*")
            }
            catch { return $false }
        }
    return Find-ElementById -ProcessId $ProcessId `
        -AutomationId "OnlineRooms.Active.OpenChart" `
        -TimeoutMilliseconds 5000
}

function Add-ElementToSelection($Element) {
    $current = $Element
    for ($depth = 0; $depth -lt 8 -and $null -ne $current; $depth++) {
        $patternObject = $null
        if ($current.TryGetCurrentPattern(
                [Windows.Automation.SelectionItemPattern]::Pattern,
                [ref]$patternObject)) {
            ([Windows.Automation.SelectionItemPattern]$patternObject).AddToSelection()
            Start-Sleep -Milliseconds 250
            return
        }
        $current = [Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($current)
    }
    throw "The requested Timing row exposed no SelectionItemPattern."
}

function Invoke-PhysicalElementWheel(
    $Element,
    [int]$Notches,
    [IntPtr]$ForegroundWindow) {
    if ($Notches -eq 0) { return }
    [void][LumaChartTwoClientGuiNative]::SetForegroundWindow($ForegroundWindow)
    Start-Sleep -Milliseconds 180
    try { $Element.SetFocus() } catch { }
    $bounds = $Element.Current.BoundingRectangle
    if (-not [double]::IsFinite($bounds.Left) -or
        -not [double]::IsFinite($bounds.Top) -or
        -not [double]::IsFinite($bounds.Width) -or
        -not [double]::IsFinite($bounds.Height) -or
        $bounds.Width -le 1 -or
        $bounds.Height -le 1) {
        throw "Cannot physically wheel an element with invalid bounds."
    }
    $x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    Set-PhysicalCursorPosition $x $y "wheel"
    Start-Sleep -Milliseconds 120
    $direction = [Math]::Sign($Notches)
    for ($index = 0; $index -lt [Math]::Abs($Notches); $index++) {
        if (-not [LumaChartTwoClientGuiNative]::SendMouseWheel(120 * $direction)) {
            throw "SendInput failed for physical mouse-wheel input."
        }
        Start-Sleep -Milliseconds 90
    }
}

function Invoke-PhysicalDrag([int]$StartX, [int]$StartY, [int]$EndX, [int]$EndY, [IntPtr]$ForegroundWindow) {
    [void][LumaChartTwoClientGuiNative]::SetForegroundWindow($ForegroundWindow)
    Start-Sleep -Milliseconds 180
    Set-PhysicalCursorPosition $StartX $StartY "drag-start"
    Start-Sleep -Milliseconds 150
    if (-not [LumaChartTwoClientGuiNative]::SendMouseButton(
            [LumaChartTwoClientGuiNative]::MouseLeftDown)) {
        throw "SendInput failed for physical drag left-button down."
    }
    Start-Sleep -Milliseconds 100
    for ($step = 1; $step -le 12; $step++) {
        $x = [int][Math]::Round($StartX + ($EndX - $StartX) * $step / 12.0)
        $y = [int][Math]::Round($StartY + ($EndY - $StartY) * $step / 12.0)
        Set-PhysicalCursorPosition $x $y "drag-step-$step"
        Start-Sleep -Milliseconds 18
    }
    Start-Sleep -Milliseconds 100
    if (-not [LumaChartTwoClientGuiNative]::SendMouseButton(
            [LumaChartTwoClientGuiNative]::MouseLeftUp)) {
        throw "SendInput failed for physical drag left-button up."
    }
}

function Protect-SessionToken([string]$LocalDataRoot, [string]$Token) {
    New-Item -ItemType Directory -Force -Path $LocalDataRoot | Out-Null
    $plain = [Text.Encoding]::UTF8.GetBytes($Token)
    try {
        $protected = [Security.Cryptography.ProtectedData]::Protect(
            $plain, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        [IO.File]::WriteAllBytes((Join-Path $LocalDataRoot "online-session.bin"), $protected)
    }
    finally { [Array]::Clear($plain, 0, $plain.Length) }
}

function New-SilentPcmWave([string]$Path) {
    $sampleRate = 44100
    $channels = 2
    $bitsPerSample = 16
    $frameCount = [int]($sampleRate / 5)
    $blockAlign = [int]($channels * ($bitsPerSample / 8))
    $dataBytes = [int]($frameCount * $blockAlign)
    $stream = [IO.File]::Open(
        $Path,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None)
    try {
        $writer = [IO.BinaryWriter]::new($stream, [Text.Encoding]::ASCII, $true)
        try {
            $writer.Write([Text.Encoding]::ASCII.GetBytes("RIFF"))
            $writer.Write([int](36 + $dataBytes))
            $writer.Write([Text.Encoding]::ASCII.GetBytes("WAVE"))
            $writer.Write([Text.Encoding]::ASCII.GetBytes("fmt "))
            $writer.Write([int]16)
            $writer.Write([int16]1)
            $writer.Write([int16]$channels)
            $writer.Write([int]$sampleRate)
            $writer.Write([int]($sampleRate * $blockAlign))
            $writer.Write([int16]$blockAlign)
            $writer.Write([int16]$bitsPerSample)
            $writer.Write([Text.Encoding]::ASCII.GetBytes("data"))
            $writer.Write([int]$dataBytes)
            $writer.Write([byte[]]::new($dataBytes))
            $writer.Flush()
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function New-KeySoundLoopbackFixtureWave([string]$Path) {
    $sampleRate = 44100
    $channels = 2
    $bitsPerSample = 16
    $frameCount = [int][Math]::Round($sampleRate * .34)
    $blockAlign = [int]($channels * ($bitsPerSample / 8))
    $dataBytes = [int]($frameCount * $blockAlign)
    $stream = [IO.File]::Open(
        $Path,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None)
    try {
        $writer = [IO.BinaryWriter]::new($stream, [Text.Encoding]::ASCII, $true)
        try {
            $writer.Write([Text.Encoding]::ASCII.GetBytes("RIFF"))
            $writer.Write([int](36 + $dataBytes))
            $writer.Write([Text.Encoding]::ASCII.GetBytes("WAVE"))
            $writer.Write([Text.Encoding]::ASCII.GetBytes("fmt "))
            $writer.Write([int]16)
            $writer.Write([int16]1)
            $writer.Write([int16]$channels)
            $writer.Write([int]$sampleRate)
            $writer.Write([int]($sampleRate * $blockAlign))
            $writer.Write([int16]$blockAlign)
            $writer.Write([int16]$bitsPerSample)
            $writer.Write([Text.Encoding]::ASCII.GetBytes("data"))
            $writer.Write([int]$dataBytes)

            $phase = 0.0
            for ($frame = 0; $frame -lt $frameCount; $frame++) {
                $time = [double]$frame / $sampleRate
                $progress = [double]$frame / [Math]::Max(1, $frameCount - 1)
                $frequency = 620.0 + 2380.0 * $progress
                $phase += 2.0 * [Math]::PI * $frequency / $sampleRate
                $fadeIn = [Math]::Min(1.0, $time / .004)
                $fadeOut = [Math]::Min(1.0, (.34 - $time) / .03)
                $envelope = $fadeIn * [Math]::Max(0.0, $fadeOut) *
                    [Math]::Exp(-3.1 * $progress)
                $signature =
                    .68 * [Math]::Sin($phase) +
                    .21 * [Math]::Sin(2.03 * $phase + .37) +
                    .11 * [Math]::Sin(2.0 * [Math]::PI * 173.0 * $time)
                $sample = [Math]::Clamp(.82 * $envelope * $signature, -.98, .98)
                $pcm = [int16][Math]::Round(
                    $sample * [int16]::MaxValue,
                    [MidpointRounding]::AwayFromZero)
                $writer.Write($pcm)
                $writer.Write($pcm)
            }
            $writer.Flush()
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Add-KeySoundLoopbackResourceReference(
    [string]$ChartPath,
    [string]$SoundName) {
    $document = Get-Content -Raw -LiteralPath $ChartPath |
        ConvertFrom-Json -Depth 100
    $seed = @(
        $document.note |
            Where-Object {
                $null -ne $_.column -and
                ($null -eq $_.type -or [int]$_.type -ne 1)
            } |
            Select-Object -First 1)[0]
    if (-not $seed) {
        throw "The real MC copy has no playable Note available for the room resource seed."
    }
    if ($seed.PSObject.Properties.Name -contains "sound") {
        $seed.sound = $SoundName
    }
    else {
        $seed | Add-Member -NotePropertyName "sound" -NotePropertyValue $SoundName
    }
    $json = $document | ConvertTo-Json -Depth 100 -Compress
    [IO.File]::WriteAllText(
        $ChartPath,
        $json,
        [Text.UTF8Encoding]::new($false))
}

function Select-PhysicalTapToolAtSnap24(
    [object]$Client,
    [IntPtr]$WindowHandle,
    [object]$Actions,
    [string]$Label) {
    $valuesToggle = Find-ElementById -ProcessId $Client.Process.Id `
        -AutomationId "Editor.QuickValues.Toggle" -TimeoutMilliseconds 10000
    if ([string]$valuesToggle.Current.Name -ceq "+") {
        Invoke-PhysicalElementClick $valuesToggle $WindowHandle
        $Actions.Add("$Label-expand-Editor.QuickValues.Toggle")
        Wait-Condition -Description "$Label quick values expanded" `
            -Seconds 10 -Condition {
            [string](Find-ElementById -ProcessId $Client.Process.Id `
                -AutomationId "Editor.QuickValues.Toggle" `
                -TimeoutMilliseconds 1000).Current.Name -ceq "−"
        }
    }
    $preset = Find-ElementById -ProcessId $Client.Process.Id `
        -AutomationId "Editor.QuickValues.Snap.Preset" -TimeoutMilliseconds 10000
    Invoke-PhysicalElementClick $preset $WindowHandle
    $Actions.Add("$Label-open-snap-preset")
    $snap24 = Find-ElementByName -ProcessId $Client.Process.Id `
        -Name "1/24" -TimeoutMilliseconds 10000
    $snapBounds = $snap24.Current.BoundingRectangle
    Invoke-PhysicalClick `
        ([int][Math]::Round($snapBounds.Left + $snapBounds.Width / 2)) `
        ([int][Math]::Round($snapBounds.Top + $snapBounds.Height / 2)) `
        $WindowHandle
    $Actions.Add("$Label-select-exact-snap-1-24")
    Wait-Condition -Description "$Label exact snap division 24" `
        -Seconds 10 -PollMilliseconds 50 -Condition {
        [int](Get-TimelineLiveState $Client.Process.Id).snapDivision -eq 24
    }

    $paletteToggle = Find-ElementById -ProcessId $Client.Process.Id `
        -AutomationId "Editor.QuickPalette.Toggle" -TimeoutMilliseconds 10000
    if ([string]$paletteToggle.Current.Name -ceq "+") {
        Invoke-PhysicalElementClick $paletteToggle $WindowHandle
        $Actions.Add("$Label-expand-Editor.QuickPalette.Toggle")
        Wait-Condition -Description "$Label quick palette expanded" `
            -Seconds 10 -Condition {
            [string](Find-ElementById -ProcessId $Client.Process.Id `
                -AutomationId "Editor.QuickPalette.Toggle" `
                -TimeoutMilliseconds 1000).Current.Name -ceq "−"
        }
    }
    $tapTool = Find-ElementById -ProcessId $Client.Process.Id `
        -AutomationId "Editor.QuickTool.Tap" -TimeoutMilliseconds 10000
    Invoke-PhysicalElementClick $tapTool $WindowHandle
    $Actions.Add("$Label-select-tap-tool")
    foreach ($toggleId in @(
            "Editor.QuickPalette.Toggle",
            "Editor.QuickValues.Toggle")) {
        $toggle = Find-ElementById -ProcessId $Client.Process.Id `
            -AutomationId $toggleId -TimeoutMilliseconds 10000
        if ([string]$toggle.Current.Name -ceq "−") {
            Invoke-PhysicalElementClick $toggle $WindowHandle
            $Actions.Add("$Label-collapse-$toggleId")
            Wait-Condition -Description "$Label $toggleId collapsed" `
                -Seconds 10 -Condition {
                [string](Find-ElementById -ProcessId $Client.Process.Id `
                    -AutomationId $toggleId -TimeoutMilliseconds 1000).Current.Name -ceq "+"
            }
        }
    }
}

function Start-Client {
    param(
        [string]$Name,
        [string]$Token,
        [string]$Profile,
        [string]$Endpoint,
        [bool]$FollowRoomEvidence,
        [bool]$ReuseExistingRoots = $false,
        [ValidateRange(1, 99)][int]$Generation = 1,
        [string]$EvidenceChartPath = "",
        [bool]$RestoreWorkspaceOnly = $false
    )
    $root = Join-Path $outputFullPath "clients\$Name"
    $localData = Join-Path $root "local-data"
    $editing = Join-Path $root "editing"
    $workspace = Join-Path $root "workspace"
    $inputRoot = Join-Path $root "input"
    $clientTemp = Join-Path $root "temp"
    if ($ReuseExistingRoots) {
        foreach ($directory in @($localData, $editing, $workspace, $inputRoot, $clientTemp)) {
            if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
                throw "Restart client root is missing: $directory"
            }
        }
    }
    else {
        foreach ($directory in @($localData, $editing, $workspace, $inputRoot, $clientTemp)) {
            New-Item -ItemType Directory -Force -Path $directory | Out-Null
        }
        Get-ChildItem -LiteralPath (Split-Path -Parent $fixtureFullPath) -File | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $inputRoot $_.Name)
        }
    }
    $chart = Join-Path $inputRoot (Split-Path -Leaf $fixtureFullPath)
    if (-not $ReuseExistingRoots) { Protect-SessionToken $localData $Token }
    if ($KeySoundLoopbackOnly -and -not $ReuseExistingRoots) {
        $loopbackSoundPath = Join-Path $inputRoot $loopbackSoundName
        New-KeySoundLoopbackFixtureWave $loopbackSoundPath
        if ((Get-FileHash -LiteralPath $loopbackSoundPath -Algorithm SHA256).Hash -cne
                $loopbackSoundSha256) {
            throw "Deterministic room Note Sound fixture hash mismatch."
        }
        Add-KeySoundLoopbackResourceReference $chart $loopbackSoundName
        $silentCustomPath = Join-Path $localData "key-sound-silent.wav"
        New-SilentPcmWave $silentCustomPath
        [ordered]@{
            SchemaVersion = 1
            EnableKeySounds = $true
            Volume = .7
            Preset = "Custom"
            CustomFilePath = $silentCustomPath
            PlayLongNoteEndSound = $false
            GlobalOffset = 0
            PerChartOffsets = @{}
        } | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath (Join-Path $localData "key-sound-settings.json") `
                -Encoding utf8NoBOM
    }
    $launchChart = if ([string]::IsNullOrWhiteSpace($EvidenceChartPath)) {
        $chart
    }
    else {
        Resolve-ExistingFile $EvidenceChartPath "Restart evidence chart"
    }
    $runtime = Join-Path $root $(if ($Generation -eq 1) {
            "startup-runtime.json"
        } else { "startup-runtime-generation-$Generation.json" })
    $roomRuntime = Join-Path $root $(if ($Generation -eq 1) {
            "room-runtime.json"
        } else { "room-runtime-generation-$Generation.json" })
    $start = [Diagnostics.ProcessStartInfo]::new($applicationFullPath)
    $start.UseShellExecute = $false
    $start.Environment["LUMACHART_SERVER_URL"] = $Endpoint
    $start.Environment["LUMACHART_PROFILE"] = $Profile
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localData
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
    $start.Environment["TEMP"] = $clientTemp
    $start.Environment["TMP"] = $clientTemp
    if ($RestoreWorkspaceOnly -and $FollowRoomEvidence) {
        throw "A workspace-only restart cannot request room-tab interaction evidence."
    }
    if (-not $RestoreWorkspaceOnly) {
        foreach ($argument in @(
                "--evidence-chart",
                $launchChart,
                "--evidence-output",
                $runtime,
                "--evidence-focus-note-property")) {
            $start.ArgumentList.Add($argument)
        }
    }
    if ($FollowRoomEvidence) {
        foreach ($argument in @(
                "--evidence-interaction-output", $roomRuntime,
                "--evidence-interaction-delay-ms", "60000",
                "--evidence-follow-active-tab")) { $start.ArgumentList.Add($argument) }
    }
    $process = [Diagnostics.Process]::Start($start)
    return [pscustomobject]@{
        Name = $Name
        Token = $Token
        Profile = $Profile
        Root = $root
        LocalData = $localData
        Editing = $editing
        Workspace = $workspace
        InputChart = $chart
        EvidenceChart = $launchChart
        Runtime = $runtime
        RoomRuntime = $roomRuntime
        Process = $process
    }
}

function Get-HarnessState([string]$Endpoint) {
    return Invoke-RestMethod -Uri ($Endpoint + "harness/state") -Method Get -TimeoutSec 15
}

function Set-HarnessFaults([string]$Endpoint, [hashtable]$Plan) {
    return Invoke-RestMethod -Uri ($Endpoint + "harness/faults") -Method Post `
        -ContentType "application/json" -Body ($Plan | ConvertTo-Json) -TimeoutSec 15
}

function Set-HarnessNetworkBlackout(
    [string]$Endpoint,
    [long]$UserId,
    [bool]$Enabled) {
    return Invoke-RestMethod -Uri ($Endpoint + "harness/network-blackout") -Method Post `
        -ContentType "application/json" `
        -Body (@{ userId = $UserId; enabled = $Enabled } | ConvertTo-Json) `
        -TimeoutSec 15
}

function Advance-HarnessLeaseClock([string]$Endpoint, [double]$Seconds) {
    return Invoke-RestMethod -Uri ($Endpoint + "harness/lease/advance") -Method Post `
        -ContentType "application/json" `
        -Body (@{ seconds = $Seconds } | ConvertTo-Json) `
        -TimeoutSec 15
}

function Invoke-HarnessLeaseCleanup([string]$Endpoint) {
    return Invoke-RestMethod -Uri ($Endpoint + "harness/lease/cleanup") -Method Post `
        -TimeoutSec 15
}

function Wait-HarnessState([string]$Endpoint, [scriptblock]$Predicate, [string]$Description, [int]$Seconds = $TimeoutSeconds) {
    $script:lastHarnessState = $null
    Wait-Condition -Description $Description -Seconds $Seconds -PollMilliseconds 150 -Condition {
        $state = Get-HarnessState $Endpoint
        $script:lastHarnessState = $state
        return [bool](& $Predicate $state)
    }
    return $script:lastHarnessState
}

function Get-ChartSnapshot(
    [string]$Endpoint,
    [string]$Token,
    [string]$RoomId = "a1a11111-2222-4333-8444-555555555555") {
    $headers = @{ Authorization = "Bearer $Token" }
    $escapedRoomId = [Uri]::EscapeDataString($RoomId)
    return Invoke-RestMethod -Uri ($Endpoint + "api/rooms/$escapedRoomId/chart") `
        -Method Get -Headers $headers -TimeoutSec 30
}

function Get-OnlineNoteIdentityJson($Note) {
    if (-not $Note) { return $null }
    return ([ordered]@{
        id = [string]$Note.id
        lane = [int]$Note.lane
        beat = $Note.beat
        endBeat = $Note.endBeat
        sound = $Note.sound
        volume = [int]$Note.volume
        group = [int]$Note.group
        isDraft = [bool]$Note.isDraft
        draftColumn = [int]$Note.draftColumn
        unknownJson = $Note.unknownJson
        creatorUserId = $Note.creatorUserId
    } | ConvertTo-Json -Depth 8 -Compress)
}

function Get-OnlineNoteNonSoundIdentityJson($Note) {
    if (-not $Note) { return $null }
    return ([ordered]@{
        id = [string]$Note.id
        lane = [int]$Note.lane
        beat = $Note.beat
        endBeat = $Note.endBeat
        volume = [int]$Note.volume
        group = [int]$Note.group
        isDraft = [bool]$Note.isDraft
        draftColumn = [int]$Note.draftColumn
        unknownJson = $Note.unknownJson
        creatorUserId = $Note.creatorUserId
    } | ConvertTo-Json -Depth 8 -Compress)
}

function Test-ExactOnlineBeat($Left, $Right) {
    return $null -ne $Left -and
        $null -ne $Right -and
        [int]$Left.bar -eq [int]$Right.bar -and
        [int]$Left.numerator -eq [int]$Right.numerator -and
        [int]$Left.denominator -eq [int]$Right.denominator
}

function Get-LockedGridSeekPlan(
    [double]$CurrentBeat,
    [int]$Division,
    [double]$LockStart,
    [double]$LockEnd,
    [int]$MaximumWheelNotches = 120) {
    if (-not [double]::IsFinite($CurrentBeat) -or
        -not [double]::IsFinite($LockStart) -or
        -not [double]::IsFinite($LockEnd) -or
        $Division -lt 1 -or
        $LockEnd -le $LockStart) {
        throw "Cannot plan a locked grid seek from invalid bounds or division."
    }

    $notchCandidates = [Collections.Generic.List[int]]::new()
    $notchCandidates.Add(0)
    for ($distance = 1; $distance -le $MaximumWheelNotches; $distance++) {
        $notchCandidates.Add(-$distance)
        $notchCandidates.Add($distance)
    }

    foreach ($notches in $notchCandidates) {
        # Timeline wheel navigation subtracts one subdivision for each positive
        # notch. Add Timing and mixed paste then use BeatPosition.Snap, whose
        # midpoint contract is AwayFromZero.
        $candidateCurrent =
            $CurrentBeat - ([double]$notches / [double]$Division)
        $snappedUnits = [long][Math]::Round(
            $candidateCurrent * [double]$Division,
            [MidpointRounding]::AwayFromZero)
        $snappedBeat = [double]$snappedUnits / [double]$Division
        if ($snappedBeat -ge $LockStart -and $snappedBeat -lt $LockEnd) {
            $bar = [long][Math]::Floor($snappedBeat)
            $numerator = $snappedUnits - ($bar * [long]$Division)
            return [pscustomobject][ordered]@{
                wheelNotches = [int]$notches
                expectedCurrentBeat = [double]$candidateCurrent
                snappedBeatValue = [double]$snappedBeat
                snappedBeatText = "$bar`:$numerator/$Division"
                snappedUnits = [long]$snappedUnits
                division = [int]$Division
            }
        }
    }

    throw "No physically reachable snapped grid point existed inside the owner lock."
}

function Get-ExactGridSeekPlan(
    [double]$CurrentBeat,
    [int]$Division,
    [double]$TargetBeat,
    [int]$MaximumWheelNotches = 120) {
    if (-not [double]::IsFinite($CurrentBeat) -or
        -not [double]::IsFinite($TargetBeat) -or
        $Division -lt 1) {
        throw "Cannot plan an exact grid seek from invalid beat or division."
    }

    $targetUnits = [long][Math]::Round(
        $TargetBeat * [double]$Division,
        [MidpointRounding]::AwayFromZero)
    $targetGridBeat = [double]$targetUnits / [double]$Division
    if ([Math]::Abs($targetGridBeat - $TargetBeat) -ge .0000001) {
        throw "The requested exact grid seek target is not on the active subdivision."
    }

    $notchCandidates = [Collections.Generic.List[int]]::new()
    $notchCandidates.Add(0)
    for ($distance = 1; $distance -le $MaximumWheelNotches; $distance++) {
        $notchCandidates.Add(-$distance)
        $notchCandidates.Add($distance)
    }
    foreach ($notches in $notchCandidates) {
        $candidateCurrent =
            $CurrentBeat - ([double]$notches / [double]$Division)
        $snappedUnits = [long][Math]::Round(
            $candidateCurrent * [double]$Division,
            [MidpointRounding]::AwayFromZero)
        if ($snappedUnits -ne $targetUnits) { continue }

        $bar = [long][Math]::Floor($targetGridBeat)
        $numerator = $targetUnits - ($bar * [long]$Division)
        return [pscustomobject][ordered]@{
            wheelNotches = [int]$notches
            expectedCurrentBeat = [double]$candidateCurrent
            snappedBeatValue = [double]$targetGridBeat
            snappedBeatText = "$bar`:$numerator/$Division"
            snappedUnits = [long]$targetUnits
            division = [int]$Division
        }
    }

    throw "No physically reachable wheel sequence existed for the exact grid target."
}

function Open-Community([pscustomobject]$Client) {
    Invoke-Element (Find-ElementById -ProcessId $Client.Process.Id -AutomationId "OnlineAccount.Navigation" -TimeoutMilliseconds 30000)
    return Find-ElementById -ProcessId $Client.Process.Id -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 30000
}

function Close-Community([pscustomobject]$Client) {
    Invoke-Element (Find-ElementById -ProcessId $Client.Process.Id -AutomationId "OnlineCommunity.Navigation.Close" -TimeoutMilliseconds 10000)
    Wait-Condition -Description "$($Client.Name) community dialog close" -Seconds 15 -Condition {
        try {
            [void](Find-ElementById -ProcessId $Client.Process.Id -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 300)
            return $false
        }
        catch { return $true }
    }
}

function Invoke-EditorSave([pscustomobject]$Client) {
    $toggle = Find-ElementById -ProcessId $Client.Process.Id `
        -AutomationId "Editor.CommandMenuToggle" -TimeoutMilliseconds 10000
    Invoke-Element $toggle
    $save = Find-ElementById -ProcessId $Client.Process.Id `
        -AutomationId "Editor.Save" -TimeoutMilliseconds 10000
    Invoke-Element $save
    Invoke-Element (Find-ElementById -ProcessId $Client.Process.Id `
        -AutomationId "Editor.CommandMenuToggle" -TimeoutMilliseconds 10000)
}

function Get-TimelinePoint(
    $Runtime,
    [int]$Lane,
    [double]$BeatOffset,
    [int]$ProcessId,
    [double]$PixelsPerBeat = 0) {
    $scale = [double]$Runtime.window.screenScaling
    $geometry = $Runtime.timeline.proEditor.geometry
    $timelineGeometry = $Runtime.timeline.geometry
    if ($null -eq $geometry.officialTrackLeftWindowDip -or
        $null -eq $timelineGeometry.judgmentLineYWindowDip) {
        throw "GUI runtime evidence did not expose timeline window geometry."
    }
    $x = [int][Math]::Round(
        [double]$Runtime.window.positionXPixels +
        ([double]$geometry.officialTrackLeftWindowDip + ([double]$geometry.laneWidthDip * ($Lane + .5))) * $scale)
    $judgmentY = [double]$Runtime.window.positionYPixels +
        [double]$timelineGeometry.judgmentLineYWindowDip * $scale
    $effectivePixelsPerBeat = if ($PixelsPerBeat -gt 0) {
        $PixelsPerBeat
    } else {
        [double]$Runtime.timeline.pixelsPerBeat
    }
    $y = [int][Math]::Round($judgmentY - $BeatOffset * $effectivePixelsPerBeat * $scale)
    return [ordered]@{
        x = $x
        y = $y
        judgmentY = [int][Math]::Round($judgmentY)
        scale = $scale
        pixelsPerBeat = $effectivePixelsPerBeat
        timelineGeometry = $timelineGeometry
    }
}

function Find-FreeTimelineTapPlacement(
    [object[]]$Notes,
    [double]$CurrentBeat,
    [int[]]$PreferredLanes,
    [double[]]$Offsets,
    [double]$MinimumClearanceBeats = .30) {
    foreach ($offset in $Offsets) {
        $candidateBeat = $CurrentBeat + $offset
        foreach ($lane in $PreferredLanes) {
            $occupied = $false
            foreach ($note in $Notes) {
                if ([int]$note.lane -ne $lane) { continue }
                $startBeat = [double]$note.beat.bar +
                    [double]$note.beat.numerator / [double]$note.beat.denominator
                $endBeat = $startBeat
                if ($null -ne $note.endBeat) {
                    $endBeat = [double]$note.endBeat.bar +
                        [double]$note.endBeat.numerator / [double]$note.endBeat.denominator
                }
                if ($candidateBeat -ge $startBeat - $MinimumClearanceBeats -and
                    $candidateBeat -le $endBeat + $MinimumClearanceBeats) {
                    $occupied = $true
                    break
                }
            }
            if (-not $occupied) {
                return [ordered]@{
                    lane = $lane
                    offset = $offset
                    candidateBeat = $candidateBeat
                    minimumClearanceBeats = $MinimumClearanceBeats
                }
            }
        }
    }
    throw "No visible free Tap placement existed outside existing Note/LN hit regions."
}

$readyPath = Join-Path $outputFullPath "server-ready.json"
$statePath = Join-Path $outputFullPath "server-state.json"
$checkpointPath = Join-Path $outputFullPath "server-restart-checkpoint.json"
$serverLogPath = Join-Path $outputFullPath "server.log"
$serverStart = [Diagnostics.ProcessStartInfo]::new("dotnet")
$serverStart.UseShellExecute = $false
$serverStart.RedirectStandardOutput = $true
$serverStart.RedirectStandardError = $true
$serverStart.ArgumentList.Add($serverAssemblyFullPath)
$serverStart.ArgumentList.Add("--ready-file")
$serverStart.ArgumentList.Add($readyPath)
$serverStart.ArgumentList.Add("--state-file")
$serverStart.ArgumentList.Add($statePath)
if ($ServerRestartOnly) {
    $serverStart.ArgumentList.Add("--checkpoint-file")
    $serverStart.ArgumentList.Add($checkpointPath)
    $serverStart.ArgumentList.Add("--process-generation")
    $serverStart.ArgumentList.Add("1")
}
$server = [Diagnostics.Process]::Start($serverStart)
$serverFirstProcessId = $server.Id
$serverFirstLogPath = Join-Path $outputFullPath "server-generation-1.log"
$serverSecondLogPath = Join-Path $outputFullPath "server-generation-2.log"
$probe = $null
$owner = $null
$member = $null
$captures = [ordered]@{}
$observations = [ordered]@{}
$exactBeatEvidence = $null
$memberPlacementEvidence = $null
$localRetentionEvidence = $null
$frozenNoteSoundEvidence = $null
$ownerLocalLive = $null
$ownerLocalPlacement = $null
$ownerLocalPoint = $null
$memberLocalLive = $null
$memberLocalPlacement = $null
$memberLocalPoint = $null
    $observerReadOnlyEvidence = $null
    $permissionChangeEvidence = $null
    $permissionActionEvidence = $null
    $metadataPreviewRaceEvidence = $null
    $resilienceEvidence = $null
    $resourceResilienceEvidence = $null
    $resourceRevisionEvidence = $null

try {
    Wait-File $readyPath "loopback server ready file" 30
    $ready = Get-Content -Raw -LiteralPath $readyPath | ConvertFrom-Json
    $endpoint = [string]$ready.endpoint
    if (-not $endpoint.StartsWith("http://127.0.0.1:", [StringComparison]::Ordinal)) {
        throw "Loopback server published a non-loopback endpoint: $endpoint"
    }

    $owner = Start-Client -Name "owner-a" -Token ([string]$ready.ownerToken) `
        -Profile "windows-avalonia-online-owner" -Endpoint $endpoint -FollowRoomEvidence $false
    $member = Start-Client -Name "member-b" -Token ([string]$ready.memberToken) `
        -Profile "windows-avalonia-online-member" -Endpoint $endpoint -FollowRoomEvidence $true
    $ownerHandle = [IntPtr](Wait-MainWindowHandle $owner.Process)
    $memberHandle = [IntPtr](Wait-MainWindowHandle $member.Process)
    Write-Host "Owner main HWND: $([long]$ownerHandle)"
    Write-Host "Member main HWND: $([long]$memberHandle)"
    if ([long]$ownerHandle -eq 0 -or [long]$memberHandle -eq 0) {
        throw "UIA main-window handle resolution returned zero."
    }
    Wait-File $owner.Runtime "owner startup GUI runtime evidence" 45
    Wait-File $member.Runtime "member startup GUI runtime evidence" 45
    $ownerAccountButton = Wait-AuthenticatedAccountButton $owner.Process.Id "房主" 30
    $memberAccountButton = Wait-AuthenticatedAccountButton $member.Process.Id "成员" 30
    Write-Output ("Owner account UIA name: " + [string]$ownerAccountButton.Current.Name)
    Write-Output ("Member account UIA name: " + [string]$memberAccountButton.Current.Name)
    if ([string]$ownerAccountButton.Current.Name -notlike "*房主*" -or
        [string]$memberAccountButton.Current.Name -notlike "*成员*") {
        throw "The two isolated DPAPI sessions did not restore the expected owner/member identities."
    }
    $ownerRuntime = Get-Content -Raw -LiteralPath $owner.Runtime | ConvertFrom-Json

    if ($HiddenInvitationOnly -or $HiddenObserverOnly -or $PermissionChangeOnly -or
        $RolePresentationOnly -or
        $PermissionActionOnly -or $PermissionVariableTempoOnly -or
        $MetadataPreviewRaceOnly -or $KeySoundLoopbackOnly) {
        $observerInvitation = [bool]$HiddenObserverOnly
        $invitationAction = if ($observerInvitation) { "watch" } else { "join" }
        $invitationRole = if ($observerInvitation) { "viewer" } else { "editor" }
        $invitationActionId = if ($observerInvitation) {
            "OnlineInvitation.Toast.Watch"
        } else {
            "OnlineInvitation.Toast.Join"
        }
        $roomDisplayName = if ($PermissionVariableTempoOnly) {
            "Windows Avalonia 多段 BPM 权限提示验收房"
        } elseif ($KeySoundLoopbackOnly) {
            "Windows Avalonia 联机 Key 音回环验收房"
        } elseif ($MetadataPreviewRaceOnly) {
            "Windows Avalonia Metadata 草稿合并验收房"
        } elseif ($PermissionActionOnly) {
            "Windows Avalonia 编辑权限提示验收房"
        } elseif ($RolePresentationOnly) {
            "Windows Avalonia 角色显示标签验收房"
        } elseif ($PermissionChangeOnly) {
            "Windows Avalonia 角色恢复验收房"
        } elseif ($observerInvitation) {
            "Windows Avalonia 隐藏密码观察房"
        } else {
            "Windows Avalonia 隐藏密码邀请房"
        }
        $testPassword = "InviteOnly-7426"
        $physicalActions = [Collections.Generic.List[string]]::new()

        Invoke-Element $ownerAccountButton
        $ownerCommunity = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 30000
        $ownerRoomsNavigation = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineCommunity.Navigation.Rooms" -TimeoutMilliseconds 15000
        Invoke-Element $ownerRoomsNavigation

        $createName = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Create.Name" -TimeoutMilliseconds 30000
        $privateRoom = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Create.Private"
        $hiddenRoom = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Create.Hidden"
        $roomPassword = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Create.Password"
        Set-ElementValue $createName $roomDisplayName
        Invoke-PhysicalElementClick $privateRoom $ownerHandle
        $physicalActions.Add("owner-enable-private-room")
        $privateRoomEnabled = $false
        for ($privateRoomAttempt = 1; $privateRoomAttempt -le 3; $privateRoomAttempt++) {
            try {
                Wait-Condition -Description "private room password field enabled" `
                    -Seconds 4 -Condition {
                    (Find-ElementById -ProcessId $owner.Process.Id `
                        -AutomationId "OnlineRooms.Create.Password" `
                        -TimeoutMilliseconds 1000).Current.IsEnabled
                }
                $privateRoomEnabled = $true
                break
            }
            catch {
                if ($privateRoomAttempt -ge 3) { throw }
                $privateRoom = Find-ElementById -ProcessId $owner.Process.Id `
                    -AutomationId "OnlineRooms.Create.Private" `
                    -TimeoutMilliseconds 3000
                Invoke-PhysicalElementClick $privateRoom $ownerHandle
                $physicalActions.Add(
                    "owner-retry-enable-private-room-$($privateRoomAttempt + 1)")
            }
        }
        if (-not $privateRoomEnabled) {
            throw "Private room password field did not become enabled."
        }
        Set-ElementValue $roomPassword $testPassword
        Invoke-PhysicalElementClick $hiddenRoom $ownerHandle
        $physicalActions.Add("owner-hide-room-from-directory")
        $hiddenRoomEnabled = $false
        for ($hiddenRoomAttempt = 1; $hiddenRoomAttempt -le 3; $hiddenRoomAttempt++) {
            try {
                Wait-Condition -Description "hidden room toggle enabled" `
                    -Seconds 4 -Condition {
                    $candidate = Find-ElementById -ProcessId $owner.Process.Id `
                        -AutomationId "OnlineRooms.Create.Hidden" `
                        -TimeoutMilliseconds 1000
                    (Get-ElementToggleState $candidate) -eq
                        [Windows.Automation.ToggleState]::On
                }
                $hiddenRoomEnabled = $true
                break
            }
            catch {
                if ($hiddenRoomAttempt -ge 3) { throw }
                $hiddenRoom = Find-ElementById -ProcessId $owner.Process.Id `
                    -AutomationId "OnlineRooms.Create.Hidden" `
                    -TimeoutMilliseconds 3000
                Invoke-PhysicalElementClick $hiddenRoom $ownerHandle
                $physicalActions.Add(
                    "owner-retry-hide-room-$($hiddenRoomAttempt + 1)")
            }
        }
        if (-not $hiddenRoomEnabled) {
            throw "Hidden room toggle did not become enabled."
        }

        $ownerCreatePath = Join-Path $outputFullPath "owner-hidden-private-room-create.png"
        $captures.ownerHiddenPrivateRoomCreate = Capture-Window `
            $ownerHandle $ownerCreatePath
        $createSubmit = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Create.Submit"
        Invoke-PhysicalElementClick $createSubmit $ownerHandle
        $physicalActions.Add("owner-prepare-hidden-private-room-resources")
        [void](Wait-ElementName -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Create.Submit" `
            -Like "*创建并上传*" -Seconds 30)
        $createSubmit = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Create.Submit"
        Invoke-PhysicalElementClick $createSubmit $ownerHandle
        $physicalActions.Add("owner-confirm-create-hidden-private-room")
        $afterCreate = Wait-HarnessState $endpoint {
            param($state)
            [bool]$state.roomCreated -and [bool]$state.room.isPrivate -and
            [bool]$state.room.isHidden -and [bool]$state.room.resourcesReady -and
            [int]$state.resourceEntryCount -ge 3 -and [long]$state.revision -ge 1 -and
            @($state.activeMemberIds) -contains 4101 -and
            -not (@($state.activeMemberIds) -contains 4202)
        } "hidden private room resource upload and owner binding"
        $captures.ownerEditorBound = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-hidden-room-editor-bound.png")

        $ownerAccountButton = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineAccount.Navigation" -TimeoutMilliseconds 20000
        Invoke-Element $ownerAccountButton
        $ownerCommunity = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 30000
        $ownerRoomsNavigation = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineCommunity.Navigation.Rooms" -TimeoutMilliseconds 15000
        Invoke-Element $ownerRoomsNavigation
        $inviteFriend = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Active.InviteFriend" -TimeoutMilliseconds 20000
        Invoke-PhysicalElementClick $inviteFriend $ownerHandle
        $physicalActions.Add("owner-open-friend-invites")
        $friendInviteButton = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Friend.4202.Invite" -TimeoutMilliseconds 20000
        $friendStatus = Wait-ElementName -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Friends.Status" -Like "*1 名好友*" -Seconds 20
        $observations.ownerFriendInviteButton = Observe-Element $friendInviteButton
        $observations.ownerFriendStatusBefore = Observe-Element $friendStatus
        $captures.ownerFriendInvite = Capture-Window `
            $ownerHandle `
            (Join-Path $outputFullPath "owner-friend-invite-list.png")
        Invoke-PhysicalElementClick $friendInviteButton $ownerHandle
        $physicalActions.Add("owner-send-room-invitation")
        $afterInvite = Wait-HarnessState $endpoint {
            param($state)
            [int]$state.invitationCreateCount -eq 1 -and
            [int]$state.pendingInvitationCount -eq 1
        } "hidden room invitation creation"
        $friendStatusAfter = Wait-ElementName -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Friends.Status" -Like "*已邀请*" -Seconds 20
        $observations.ownerFriendStatusAfter = Observe-Element $friendStatusAfter
        $captures.ownerInvitationSent = Capture-Window `
            $ownerHandle `
            (Join-Path $outputFullPath "owner-hidden-room-invitation-sent.png")

        $script:memberInvitationAction = $null
        Wait-Condition -Description "member main-window invitation toast" -Seconds 30 -Condition {
            $candidate = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId $invitationActionId -TimeoutMilliseconds 1000
            if ($candidate.Current.IsEnabled -and -not $candidate.Current.IsOffscreen) {
                $script:memberInvitationAction = $candidate
                return $true
            }
            return $false
        }
        $memberInvitationAction = $script:memberInvitationAction
        $script:memberInvitationAction = $null
        $memberInvitationCancel = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineInvitation.Toast.Cancel"
        $memberInvitationWatch = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineInvitation.Toast.Watch"
        $memberInvitationJoin = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineInvitation.Toast.Join"
        $memberInvitationToast = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineInvitation.Toast"
        $memberTitleChrome = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Title.Chrome"
        $memberInvitationTitle = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineInvitation.Toast.Title"
        $memberInvitationDetail = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineInvitation.Toast.Detail"
        $observations.memberInvitationJoin = Observe-Element $memberInvitationJoin
        $observations.memberInvitationCancel = Observe-Element $memberInvitationCancel
        $observations.memberInvitationWatch = Observe-Element $memberInvitationWatch
        $observations.memberInvitationToast = Observe-Element $memberInvitationToast
        $observations.memberInvitationTitle = Observe-Element $memberInvitationTitle
        $observations.memberInvitationDetail = Observe-Element $memberInvitationDetail
        $memberDpi = [double][LumaChartTwoClientGuiNative]::GetDpiForWindow($memberHandle)
        if ($memberDpi -lt 96) {
            throw "Member window DPI is invalid: $memberDpi"
        }
        $memberScale = $memberDpi / 96.0
        $toastBounds = $memberInvitationToast.Current.BoundingRectangle
        $chromeBounds = $memberTitleChrome.Current.BoundingRectangle
        $cancelBounds = $memberInvitationCancel.Current.BoundingRectangle
        $watchBounds = $memberInvitationWatch.Current.BoundingRectangle
        $joinBounds = $memberInvitationJoin.Current.BoundingRectangle
        $expectedToastWidth = 360.0 * $memberScale
        $expectedTopOffset = 50.0 * $memberScale
        $expectedRightInset = 14.0 * $memberScale
        $expectedButtonHeight = 34.0 * $memberScale
        $expectedButtonGap = 8.0 * $memberScale
        $actualTopOffset = $toastBounds.Top - $chromeBounds.Top
        $actualRightInset = $chromeBounds.Right - $toastBounds.Right
        $cancelWatchGap = $watchBounds.Left - $cancelBounds.Right
        $watchJoinGap = $joinBounds.Left - $watchBounds.Right
        if ([Math]::Abs($toastBounds.Width - $expectedToastWidth) -gt 2.5 -or
            [Math]::Abs($actualTopOffset - $expectedTopOffset) -gt 3.5 -or
            [Math]::Abs($actualRightInset - $expectedRightInset) -gt 3.5 -or
            [Math]::Abs($cancelBounds.Height - $expectedButtonHeight) -gt 2.5 -or
            [Math]::Abs($watchBounds.Height - $expectedButtonHeight) -gt 2.5 -or
            [Math]::Abs($joinBounds.Height - $expectedButtonHeight) -gt 2.5 -or
            [Math]::Abs($cancelWatchGap - $expectedButtonGap) -gt 2.5 -or
            [Math]::Abs($watchJoinGap - $expectedButtonGap) -gt 2.5 -or
            [Math]::Abs($cancelBounds.Width - $joinBounds.Width) -gt 2.5 -or
            [Math]::Abs(
                ($cancelBounds.Width - $watchBounds.Width) -
                (4.0 * $memberScale)) -gt 2.5) {
            throw ("Invitation toast does not match WPF 360/top50/right14/buttons34/gap8 geometry: " +
                "dpi=$memberDpi; width=$($toastBounds.Width)/$expectedToastWidth; " +
                "top=$actualTopOffset/$expectedTopOffset; right=$actualRightInset/$expectedRightInset; " +
                "heights=$($cancelBounds.Height),$($watchBounds.Height),$($joinBounds.Height)/$expectedButtonHeight; " +
                "gaps=$cancelWatchGap,$watchJoinGap/$expectedButtonGap; " +
                "widths=$($cancelBounds.Width),$($watchBounds.Width),$($joinBounds.Width).")
        }
        $invitationGeometry = [ordered]@{
            dpi = $memberDpi
            scale = $memberScale
            contract = [string]$memberInvitationToast.Current.HelpText
            toast = [ordered]@{
                width = [double]$toastBounds.Width
                expectedWidth = $expectedToastWidth
                topOffset = $actualTopOffset
                expectedTopOffset = $expectedTopOffset
                rightInset = $actualRightInset
                expectedRightInset = $expectedRightInset
            }
            buttons = [ordered]@{
                cancelHeight = [double]$cancelBounds.Height
                watchHeight = [double]$watchBounds.Height
                joinHeight = [double]$joinBounds.Height
                expectedHeight = $expectedButtonHeight
                cancelWatchGap = $cancelWatchGap
                watchJoinGap = $watchJoinGap
                expectedGap = $expectedButtonGap
                wpfColumnMarginsPassed =
                    [Math]::Abs($cancelBounds.Width - $joinBounds.Width) -le 2.5 -and
                    [Math]::Abs(
                        ($cancelBounds.Width - $watchBounds.Width) -
                        (4.0 * $memberScale)) -le 2.5
            }
            passed = $true
        }
        $memberUiSecretExposure = @(Find-UiAutomationSecretExposure `
            -ProcessId $member.Process.Id -Secret $testPassword)
        if ($memberUiSecretExposure.Count -ne 0) {
            throw "Hidden room password leaked into member UI Automation."
        }
        $captures.memberInvitationToast = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-main-window-invitation-toast.png")

        $memberInvitationAction = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId $invitationActionId -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberInvitationAction $memberHandle
        $physicalActions.Add("member-$invitationAction-invitation-from-main-window-toast")
        $afterMembership = Wait-HarnessState $endpoint {
            param($state)
            $memberState = @($state.members | Where-Object { [long]$_.userId -eq 4202 })[0]
            @($state.activeMemberIds) -contains 4202 -and
            [int]$state.invitationJoinCount -eq 1 -and
            @($state.invitationResponseActions) -contains $invitationAction -and
            [int]$state.pendingInvitationCount -eq 0 -and
            [int]$state.memberNormalJoinRequestCount -eq 0 -and
            [int]$state.memberJoinPasswordSubmissionCount -eq 0 -and
            [string]$memberState.memberRole -ceq $invitationRole
        } "member invitation password-bypass $invitationAction membership"
        $memberResourceConfirmation = Wait-RoomResourceConfirmation `
            -ProcessId $member.Process.Id -Seconds 30
        Invoke-PhysicalElementClick $memberResourceConfirmation $memberHandle
        $physicalActions.Add("member-confirm-invitation-room-resources")
        $afterAccept = Wait-HarnessState $endpoint {
            param($state)
            $memberState = @($state.members | Where-Object { [long]$_.userId -eq 4202 })[0]
            @($state.activeMemberIds) -contains 4202 -and
            [int]$state.invitationJoinCount -eq 1 -and
            [int]$state.downloadedBlobCount -ge 3 -and
            [string]$memberState.memberRole -ceq $invitationRole
        } "member invitation room resource materialization"
        Wait-Condition -Description "member invitation toast dismissed" -Seconds 20 -Condition {
            try {
                $candidate = Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "OnlineInvitation.Toast.Join" -TimeoutMilliseconds 300
                return $candidate.Current.IsOffscreen -or -not $candidate.Current.IsEnabled
            }
            catch { return $true }
        }
        $afterInvitationCaptureName = if ($observerInvitation) {
            "member-viewer-after-hidden-invitation.png"
        } else {
            "member-editor-after-hidden-invitation.png"
        }
        $captures.memberAfterInvitation = Capture-Window $memberHandle `
            (Join-Path $outputFullPath $afterInvitationCaptureName)
        $ownerLatency = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.ChartTab.LiveLatency" -TimeoutMilliseconds 15000
        $memberLatency = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab.LiveLatency" -TimeoutMilliseconds 15000
        $ownerLiveBadge = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.ChartTab.LiveBadge" -TimeoutMilliseconds 15000
        $memberLiveBadge = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab.LiveBadge" -TimeoutMilliseconds 15000
        $observations.ownerLiveLatencyInitial = Observe-Element $ownerLatency
        $observations.memberLiveLatencyInitial = Observe-Element $memberLatency
        $latencyDeadline = [DateTimeOffset]::UtcNow.AddSeconds(25)
        $ownerLatencyName = [string]$ownerLiveBadge.Current.Name
        $memberLatencyName = [string]$memberLiveBadge.Current.Name
        do {
            Start-Sleep -Milliseconds 300
            $ownerLiveBadge = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "Editor.ChartTab.LiveBadge" -TimeoutMilliseconds 2000
            $memberLiveBadge = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.ChartTab.LiveBadge" -TimeoutMilliseconds 2000
            $ownerLatencyName = [string]$ownerLiveBadge.Current.Name
            $memberLatencyName = [string]$memberLiveBadge.Current.Name
            if ($ownerLatencyName -match '\d{1,5} ms$' -and
                $memberLatencyName -match '\d{1,5} ms$') {
                break
            }
        } while ([DateTimeOffset]::UtcNow -lt $latencyDeadline)
        if ($ownerLatencyName -notmatch '\d{1,5} ms$' -or
            $memberLatencyName -notmatch '\d{1,5} ms$') {
            throw "Timed out waiting for invitation-room latency labels; " +
                  "owner='$ownerLatencyName'; member='$memberLatencyName'."
        }
        $ownerLatency = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.ChartTab.LiveLatency" -TimeoutMilliseconds 5000
        $memberLatency = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab.LiveLatency" -TimeoutMilliseconds 5000
        $ownerLiveBadge = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.ChartTab.LiveBadge" -TimeoutMilliseconds 5000
        $memberLiveBadge = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab.LiveBadge" -TimeoutMilliseconds 5000
        $observations.ownerLiveLatencyMeasured = Observe-Element $ownerLatency
        $observations.memberLiveLatencyMeasured = Observe-Element $memberLatency
        $observations.ownerLiveBadgeLatency = Observe-Element $ownerLiveBadge
        $observations.memberLiveBadgeLatency = Observe-Element $memberLiveBadge
        if ([string]$observations.ownerLiveBadgeLatency.helpText -notlike
                "*与联机服务器最近一次请求的往返延迟*" -or
            [string]$observations.memberLiveBadgeLatency.helpText -notlike
                "*与联机服务器最近一次请求的往返延迟*") {
            throw "Invitation-room live badge does not expose the WPF latency description."
        }
        $captures.ownerOnlineLatency = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-online-latency.png")
        $captures.memberOnlineLatency = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-online-latency.png")

        if ($RolePresentationOnly) {
            $ownerFriendsBack = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Friends.Back" -TimeoutMilliseconds 15000
            Invoke-PhysicalElementClick $ownerFriendsBack $ownerHandle
            $physicalActions.Add("owner-return-to-active-room-for-role-copy")
            $ownerRefresh = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Active.Refresh" -TimeoutMilliseconds 15000
            Invoke-PhysicalElementClick $ownerRefresh $ownerHandle
            $physicalActions.Add("owner-refresh-member-role-copy")
            [void](Wait-ElementName -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Active.Status" -Like "*2 名成员*身份 房主*" `
                -Seconds 30)

            $ownerState = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.4101.State" -TimeoutMilliseconds 15000
            $memberState = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.4202.State" -TimeoutMilliseconds 15000
            if ([string]$ownerState.Current.Name -cne "房主" -or
                [string]$memberState.Current.Name -cne "编辑者") {
                throw "Visible room member roles did not match WPF Chinese labels."
            }
            $observations.rolePresentationOwnerState = Observe-Element $ownerState
            $observations.rolePresentationMemberState = Observe-Element $memberState
            $captures.rolePresentationMembers = Capture-Window $ownerHandle `
                (Join-Path $outputFullPath "owner-role-presentation-members.png")

            $manage = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.4202.Manage" -TimeoutMilliseconds 15000
            Invoke-PhysicalElementClick $manage $ownerHandle
            $physicalActions.Add("owner-open-role-presentation-management")
            $role = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Role" -TimeoutMilliseconds 15000
            $metadata = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Metadata" -TimeoutMilliseconds 15000
            $timing = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Timing" -TimeoutMilliseconds 15000
            $notes = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Notes" -TimeoutMilliseconds 15000
            $save = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Save" -TimeoutMilliseconds 15000
            $kick = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Kick" -TimeoutMilliseconds 15000
            $ban = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Ban" -TimeoutMilliseconds 15000
            $heading = Find-ElementByName -ProcessId $owner.Process.Id `
                -Name "房间编辑权限 · 由房主持久分配" -TimeoutMilliseconds 15000
            if ([string]$role.Current.Name -cne "编辑者" -or
                [string]$metadata.Current.Name -cne "允许编辑谱面信息" -or
                [string]$timing.Current.Name -cne
                    "允许编辑 Effect（Timing Edit 全部功能）" -or
                [string]$notes.Current.Name -cne "允许编辑 Note" -or
                [string]$save.Current.Name -cne "保存房间权限" -or
                [string]$kick.Current.Name -cne "踢出" -or
                [string]$ban.Current.Name -cne "暂时封禁 30 分钟") {
                throw "Member-management visible copy did not match WPF 1.1.0."
            }
            $observations.rolePresentationHeading = Observe-Element $heading
            $observations.rolePresentationRole = Observe-Element $role
            $observations.rolePresentationSelectedEditor =
                Observe-Element $role
            $observations.rolePresentationMetadata = Observe-Element $metadata
            $observations.rolePresentationTiming = Observe-Element $timing
            $observations.rolePresentationNotes = Observe-Element $notes
            $observations.rolePresentationSave = Observe-Element $save
            $observations.rolePresentationKick = Observe-Element $kick
            $observations.rolePresentationBan = Observe-Element $ban
            $captures.rolePresentationManagement = Capture-Window $ownerHandle `
                (Join-Path $outputFullPath "owner-role-presentation-management.png")

            Invoke-PhysicalElementClick $role $ownerHandle
            $physicalActions.Add("owner-open-role-presentation-selector")
            $editorRoleItem = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Role.editor" `
                -TimeoutMilliseconds 10000
            $viewerRoleItem = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Role.viewer" `
                -TimeoutMilliseconds 10000
            if ([string]$editorRoleItem.Current.Name -cne "编辑者" -or
                [string]$viewerRoleItem.Current.Name -cne "观察者") {
                throw "Role option AutomationIds did not expose Chinese UIA names."
            }
            $observations.rolePresentationEditorOption =
                Observe-Element $editorRoleItem
            $observations.rolePresentationViewerOption =
                Observe-Element $viewerRoleItem
            Invoke-PhysicalElementClick $viewerRoleItem $ownerHandle
            $physicalActions.Add("owner-stage-visible-viewer-role")
            Wait-Condition -Description "staged viewer role and disabled permissions" `
                -Seconds 10 -Condition {
                $currentRole = Find-ElementById -ProcessId $owner.Process.Id `
                    -AutomationId "OnlineRooms.Member.Role" -TimeoutMilliseconds 1000
                $currentMetadata = Find-ElementById -ProcessId $owner.Process.Id `
                    -AutomationId "OnlineRooms.Member.Metadata" -TimeoutMilliseconds 1000
                [string]$currentRole.Current.Name -ceq "观察者" -and
                    -not $currentMetadata.Current.IsEnabled
            }
            $role = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Role" -TimeoutMilliseconds 5000
            $metadata = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Metadata" -TimeoutMilliseconds 5000
            $timing = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Timing" -TimeoutMilliseconds 5000
            $notes = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Notes" -TimeoutMilliseconds 5000
            if ($metadata.Current.IsEnabled -or $timing.Current.IsEnabled -or
                $notes.Current.IsEnabled) {
                throw "Staged viewer role did not disable granular permission controls."
            }
            $observations.rolePresentationSelectedViewer =
                Observe-Element $role
            $captures.rolePresentationViewer = Capture-Window $ownerHandle `
                (Join-Path $outputFullPath "owner-role-presentation-viewer.png")

            $roleState = Get-HarnessState $endpoint
            $roleMember = @($roleState.members | Where-Object {
                [long]$_.userId -eq 4202
            })[0]
            if ([string]$roleMember.memberRole -cne "editor" -or
                [int]$roleState.acceptedOperationCount -ne 0 -or
                [int]$roleState.chart.noteCount -ne 2753) {
                throw "Visible role staging changed the protocol role or chart."
            }
            $screenshots = [ordered]@{}
            foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
                $screenshots[$file.BaseName] = [ordered]@{
                    path = $file.FullName
                    length = $file.Length
                    sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
                }
            }
            $evidence = [ordered]@{
                schema =
                    "lumachart.windows.avalonia.online-role-presentation-gui-evidence.v1"
                generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
                status = "passed"
                windowsAvaloniaOnly = $true
                productionServerMutationPerformed = $false
                mobileProjectsBuiltModifiedInstalledOrTested = $false
                pureDotnetRelease = $true
                ollvmObfuscationPackingVirtualizationOrAotUsed = $false
                physicalMouseInputUsed = $false
                uiAutomationInvokeToggleSelectionItemUsed = $true
                enterKeyUsed = $false
                foregroundIdleGateMilliseconds =
                    $script:WindowsAvaloniaForegroundAutomationIdleMilliseconds
                protocol = [ordered]@{
                    ownerRole = [string]$roleState.members[0].memberRole
                    memberRole = [string]$roleMember.memberRole
                    acceptedOperationCount = [int]$roleState.acceptedOperationCount
                    noteCount = [int]$roleState.chart.noteCount
                    revision = [long]$roleState.revision
                }
                visible = [ordered]@{
                    ownerState = [string]$ownerState.Current.Name
                    memberState = [string]$memberState.Current.Name
                    selectedEditor = [string]$observations.rolePresentationSelectedEditor.name
                    editorOption = [string]$observations.rolePresentationEditorOption.name
                    viewerOption = [string]$observations.rolePresentationViewerOption.name
                    selectedViewer = [string]$observations.rolePresentationSelectedViewer.name
                    permissionHeading = [string]$heading.Current.Name
                    metadata = [string]$metadata.Current.Name
                    timing = [string]$timing.Current.Name
                    notes = [string]$notes.Current.Name
                    save = [string]$save.Current.Name
                    kick = [string]$kick.Current.Name
                    ban = [string]$ban.Current.Name
                    viewerPermissionsDisabled = $true
                }
                actions = $physicalActions.ToArray()
                controls = $observations
                screenshots = $screenshots
                hashes = [ordered]@{
                    fixture = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
                    application =
                        (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
                }
            }
            $evidencePath = Join-Path $outputFullPath "evidence.json"
            $evidence | ConvertTo-Json -Depth 60 |
                Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
            Write-Output "Windows Avalonia online role presentation GUI capture: passed"
            Write-Output "Evidence: $evidencePath"
            return
        }

        if ($observerInvitation) {
            $memberStartupRuntime = Get-Content -Raw -LiteralPath $member.Runtime | ConvertFrom-Json
            $observerStateBefore = Get-HarnessState $endpoint
            $observerOperationCountBefore = [int]$observerStateBefore.acceptedOperationCount
            $observerChartBefore = Get-ChartSnapshot $endpoint $member.Token
            $observerChartBeforeJson = $observerChartBefore | ConvertTo-Json -Depth 40 -Compress
            $observerLiveBefore = Get-TimelineLiveState $member.Process.Id
            if ([string]::IsNullOrWhiteSpace([string]$observerLiveBefore.selectedNoteId)) {
                throw "Observer GUI did not retain a selected real Note for the read-only drag gate."
            }

            $observerChartTab = Find-ElementByIdAndNameLike -ProcessId $member.Process.Id `
                -AutomationId "Editor.ChartTab" -Like "*观看*" -TimeoutMilliseconds 20000
            $observerSelectTool = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.QuickTool.Select" -TimeoutMilliseconds 10000
            $observerTapTool = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.QuickTool.Tap" -TimeoutMilliseconds 10000
            $observerHoldTool = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.QuickTool.Hold" -TimeoutMilliseconds 10000
            $observerEraseTool = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.QuickTool.Erase" -TimeoutMilliseconds 10000
            if (-not $observerSelectTool.Current.IsEnabled -or
                $observerTapTool.Current.IsEnabled -or
                $observerHoldTool.Current.IsEnabled -or
                $observerEraseTool.Current.IsEnabled) {
                throw "Observer timeline tools were not fail-closed to Select-only."
            }
            $observations.observerChartTab = Observe-Element $observerChartTab
            $observations.observerSelectTool = Observe-Element $observerSelectTool
            $observations.observerTapTool = Observe-Element $observerTapTool
            $observations.observerHoldTool = Observe-Element $observerHoldTool
            $observations.observerEraseTool = Observe-Element $observerEraseTool
            $captures.memberObserverOverview = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-observer-readonly-overview.png")

            if (-not $AutomationDiagnostic) {
                $observerReadyStatus = Wait-ElementName -ProcessId $member.Process.Id `
                    -AutomationId "Editor.Status" -Like "*房间谱面已同步*" -Seconds 30
                $observations.observerReadyStatus = Observe-Element $observerReadyStatus
                Invoke-PhysicalElementClick $observerTapTool $memberHandle
                $physicalActions.Add("observer-physically-attempt-disabled-tap-tool")

                # MC/MCZ files do not persist the room's runtime Note GUIDs. Pick
                # a structural target from the authoritative snapshot and match
                # it in the materialized document by lane + exact rational Beat.
                $observerTargetNote = @($observerChartBefore.notes |
                    Where-Object { $null -eq $_.endBeat } |
                    Sort-Object {
                        [double]$_.beat.bar +
                        [double]$_.beat.numerator / [double]$_.beat.denominator
                    } |
                    Select-Object -First 1)[0]
                if ($null -eq $observerTargetNote) {
                    throw "Authoritative room chart did not expose a Tap Note for the observer drag gate."
                }
                $observerTargetBeat = [double]$observerTargetNote.beat.bar +
                    [double]$observerTargetNote.beat.numerator /
                    [double]$observerTargetNote.beat.denominator
                $observerMaximumBeat = 4.0
                foreach ($note in @($observerChartBefore.notes)) {
                    $head = [double]$note.beat.bar +
                        [double]$note.beat.numerator / [double]$note.beat.denominator
                    $observerMaximumBeat = [Math]::Max($observerMaximumBeat, $head)
                    if ($null -ne $note.endBeat) {
                        $tail = [double]$note.endBeat.bar +
                            [double]$note.endBeat.numerator / [double]$note.endBeat.denominator
                        $observerMaximumBeat = [Math]::Max($observerMaximumBeat, $tail)
                    }
                }
                # EditorOverviewSurface adds one Beat after the furthest Note to
                # its cached range. Seek with the same mapping so a selection
                # retained from the source tab cannot remain far offscreen when
                # the newly materialized room tab starts at Beat zero.
                $observerMaximumBeat += 1.0
                $observerOverview = Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "Editor.Overview" -TimeoutMilliseconds 10000
                $observerOverviewBounds = $observerOverview.Current.BoundingRectangle
                if ($observerOverviewBounds.Width -le 1 -or $observerOverviewBounds.Height -le 1) {
                    throw "Observer density overview did not expose usable physical bounds."
                }
                $observerSeekX = [int][Math]::Round(
                    $observerOverviewBounds.Left + $observerOverviewBounds.Width / 2)
                $observerSeekY = [int][Math]::Round(
                    $observerOverviewBounds.Bottom -
                    [Math]::Clamp($observerTargetBeat / $observerMaximumBeat, 0.0, 1.0) *
                    $observerOverviewBounds.Height)
                Invoke-PhysicalClick $observerSeekX $observerSeekY $memberHandle
                $physicalActions.Add("observer-physically-seek-selected-note-via-overview")
                Start-Sleep -Milliseconds 800
                $observerAfterOverviewSeek = Get-TimelineLiveState $member.Process.Id
                if ([Math]::Abs(
                        [double]$observerAfterOverviewSeek.currentBeat - $observerTargetBeat) -ge 1.0) {
                    throw ("Observer overview seek missed: targetBeat={0:R}; actualBeat={1:R}; " +
                        "click=({2},{3}); bounds=({4:R},{5:R},{6:R},{7:R}); maxBeat={8:R}; scale={9:R}") -f `
                        $observerTargetBeat,
                        [double]$observerAfterOverviewSeek.currentBeat,
                        $observerSeekX,
                        $observerSeekY,
                        $observerOverviewBounds.Left,
                        $observerOverviewBounds.Top,
                        $observerOverviewBounds.Width,
                        $observerOverviewBounds.Height,
                        $observerMaximumBeat,
                        [double]$memberStartupRuntime.window.screenScaling
                }
                $observerDragLive = $observerAfterOverviewSeek
                $observerTargetOffset = $observerTargetBeat -
                    [double]$observerDragLive.currentBeat
                $observerNotePoint = Get-TimelinePoint `
                    $memberStartupRuntime ([int]$observerTargetNote.lane) $observerTargetOffset `
                    $member.Process.Id ([double]$observerDragLive.pixelsPerBeat)
                $observerNotePoint.targetBeat = $observerTargetBeat
                $observerNotePoint.currentBeat = [double]$observerDragLive.currentBeat
                $captures.memberObserverTargetVisible = Capture-Window $memberHandle `
                    (Join-Path $outputFullPath "member-observer-target-note-visible.png")
                Invoke-PhysicalClick $observerNotePoint.x $observerNotePoint.y $memberHandle
                $physicalActions.Add("observer-physically-select-readonly-note")
                Start-Sleep -Milliseconds 200
                $observerLiveBefore = Get-TimelineLiveState $member.Process.Id
                $observerClickStatus = Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "Editor.Status" -TimeoutMilliseconds 3000
                $observations.observerClickStatus = Observe-Element $observerClickStatus
                $observerPermissionNotice = Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "OnlineRoom.PermissionNotice" -TimeoutMilliseconds 10000
                $observerPermissionTitle = Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "OnlineRoom.PermissionNotice.Title" -TimeoutMilliseconds 10000
                $observerPermissionMessage = Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "OnlineRoom.PermissionNotice.Message" -TimeoutMilliseconds 10000
                $observerPermissionDismiss = Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "OnlineRoom.PermissionNotice.Dismiss" -TimeoutMilliseconds 10000
                if ([string]$observerPermissionTitle.Current.Name -cne "没有编辑权限" -or
                    [string]$observerPermissionMessage.Current.Name -cne
                        "无编辑 Note 的权限，请向房主索要。" -or
                    [string]$observerPermissionDismiss.Current.Name -cne "知道了" -or
                    -not $observerPermissionDismiss.Current.IsEnabled) {
                    throw "Observer permission notice did not match the WPF 1.1.0 copy."
                }
                $observations.observerPermissionNotice =
                    Observe-Element $observerPermissionNotice
                $observations.observerPermissionTitle =
                    Observe-Element $observerPermissionTitle
                $observations.observerPermissionMessage =
                    Observe-Element $observerPermissionMessage
                $observations.observerPermissionDismiss =
                    Observe-Element $observerPermissionDismiss
                $captures.memberObserverPermissionNotice = Capture-Window $memberHandle `
                    (Join-Path $outputFullPath "member-observer-permission-notice.png")
                Invoke-PhysicalElementClick $observerPermissionDismiss $memberHandle
                $physicalActions.Add("observer-physically-dismiss-permission-notice")
                Invoke-PhysicalDrag `
                    $observerNotePoint.x $observerNotePoint.y `
                    $observerNotePoint.x ($observerNotePoint.y - 55) $memberHandle
                $physicalActions.Add("observer-physically-attempt-selected-note-drag")
                $observerDragPermissionDismiss = Find-ElementById `
                    -ProcessId $member.Process.Id `
                    -AutomationId "OnlineRoom.PermissionNotice.Dismiss" `
                    -TimeoutMilliseconds 15000
                $observerDragStatus = Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "Editor.Status" -TimeoutMilliseconds 3000
                $observations.observerDragDeniedStatus =
                    Observe-Element $observerDragStatus
                $observerLiveBefore = Get-TimelineLiveState $member.Process.Id
                $observerExpectedBeatText = "{0}:{1}/{2}" -f `
                    [int]$observerTargetNote.beat.bar,
                    [int]$observerTargetNote.beat.numerator,
                    [int]$observerTargetNote.beat.denominator
                if ([int]$observerLiveBefore.selectedNoteLane -ne [int]$observerTargetNote.lane -or
                    [string]$observerLiveBefore.selectedNoteBeat -cne $observerExpectedBeatText) {
                    throw "Observer physical drag did not hit the structural target Note."
                }
                Invoke-PhysicalElementClick $observerDragPermissionDismiss $memberHandle
                $physicalActions.Add("observer-physically-dismiss-drag-permission-notice")
            }

            $observerMetadataTab = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Inspector.MetadataTab" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $observerMetadataTab $memberHandle
            $physicalActions.Add("observer-open-metadata-inspector")
            $observerMetadataTitle = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Title" -TimeoutMilliseconds 10000
            $observerMetadataApply = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Apply" -TimeoutMilliseconds 10000
            $observerMetadataStatus = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Status" -TimeoutMilliseconds 10000
            if ($observerMetadataTitle.Current.IsEnabled -or $observerMetadataApply.Current.IsEnabled) {
                throw "Observer metadata controls were editable."
            }
            if (-not $AutomationDiagnostic) {
                Invoke-PhysicalElementClick $observerMetadataApply $memberHandle
                $physicalActions.Add("observer-physically-attempt-disabled-metadata-apply")
            }
            $observations.observerMetadataTitle = Observe-Element $observerMetadataTitle
            $observations.observerMetadataApply = Observe-Element $observerMetadataApply
            $observations.observerMetadataStatus = Observe-Element $observerMetadataStatus
            $captures.memberObserverMetadata = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-observer-metadata-readonly.png")

            $observerTimingTab = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Inspector.TimingTab" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $observerTimingTab $memberHandle
            $physicalActions.Add("observer-open-timing-inspector")
            $observerTimingBeat = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Inspector.Timing.Beat" -TimeoutMilliseconds 10000
            $observerTimingAdd = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Inspector.Timing.Add" -TimeoutMilliseconds 10000
            $observerTimingPermission = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Inspector.Timing.Permission" -TimeoutMilliseconds 10000
            if ($observerTimingBeat.Current.IsEnabled -or $observerTimingAdd.Current.IsEnabled) {
                throw "Observer Timing controls were editable."
            }
            if (-not $AutomationDiagnostic) {
                Invoke-PhysicalElementClick $observerTimingAdd $memberHandle
                $physicalActions.Add("observer-physically-attempt-disabled-timing-add")
            }
            $observations.observerTimingBeat = Observe-Element $observerTimingBeat
            $observations.observerTimingAdd = Observe-Element $observerTimingAdd
            $observations.observerTimingPermission = Observe-Element $observerTimingPermission
            $captures.memberObserverTiming = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-observer-timing-readonly.png")

            $observerNoteTab = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Inspector.NoteTab" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $observerNoteTab $memberHandle
            $physicalActions.Add("observer-open-note-inspector")
            $observerNoteBeat = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Inspector.Note.Beat" -TimeoutMilliseconds 10000
            $observerNoteApply = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Inspector.Note.Apply" -TimeoutMilliseconds 10000
            $observerNoteDelete = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Inspector.Note.Delete" -TimeoutMilliseconds 10000
            if ($observerNoteBeat.Current.IsEnabled -or
                $observerNoteApply.Current.IsEnabled -or
                $observerNoteDelete.Current.IsEnabled) {
                throw "Observer Note controls were editable."
            }
            if (-not $AutomationDiagnostic) {
                Invoke-PhysicalElementClick $observerNoteApply $memberHandle
                $physicalActions.Add("observer-physically-attempt-disabled-note-apply")
            }
            $observations.observerNoteBeat = Observe-Element $observerNoteBeat
            $observations.observerNoteApply = Observe-Element $observerNoteApply
            $observations.observerNoteDelete = Observe-Element $observerNoteDelete
            $captures.memberObserverNote = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-observer-note-readonly.png")

            Start-Sleep -Milliseconds 2200
            $observerStateAfter = Get-HarnessState $endpoint
            $observerChartAfter = Get-ChartSnapshot $endpoint $member.Token
            $observerChartAfterJson = $observerChartAfter | ConvertTo-Json -Depth 40 -Compress
            $observerLiveAfter = Get-TimelineLiveState $member.Process.Id
            $observerReadOnlyEvidence = [ordered]@{
                memberRole = $invitationRole
                automationDiagnostic = [bool]$AutomationDiagnostic
                physicalDragAttempted = -not [bool]$AutomationDiagnostic
                operationCountBefore = $observerOperationCountBefore
                operationCountAfter = [int]$observerStateAfter.acceptedOperationCount
                serverChartEqualBeforeAfter = $observerChartBeforeJson -ceq $observerChartAfterJson
                selectedNoteIdBefore = [string]$observerLiveBefore.selectedNoteId
                selectedNoteIdAfter = [string]$observerLiveAfter.selectedNoteId
                selectedNoteBeatBefore = [string]$observerLiveBefore.selectedNoteBeat
                selectedNoteBeatAfter = [string]$observerLiveAfter.selectedNoteBeat
                selectToolEnabled = [bool]$observerSelectTool.Current.IsEnabled
                tapToolEnabled = [bool]$observerTapTool.Current.IsEnabled
                holdToolEnabled = [bool]$observerHoldTool.Current.IsEnabled
                eraseToolEnabled = [bool]$observerEraseTool.Current.IsEnabled
                metadataControlsDisabled = -not $observerMetadataTitle.Current.IsEnabled -and
                    -not $observerMetadataApply.Current.IsEnabled
                timingControlsDisabled = -not $observerTimingBeat.Current.IsEnabled -and
                    -not $observerTimingAdd.Current.IsEnabled
                noteControlsDisabled = -not $observerNoteBeat.Current.IsEnabled -and
                    -not $observerNoteApply.Current.IsEnabled -and
                    -not $observerNoteDelete.Current.IsEnabled
            }
            $observerReadOnlyEvidence.passed =
                $observerReadOnlyEvidence.operationCountBefore -eq $observerReadOnlyEvidence.operationCountAfter -and
                $observerReadOnlyEvidence.serverChartEqualBeforeAfter -and
                $observerReadOnlyEvidence.selectedNoteIdBefore -ceq $observerReadOnlyEvidence.selectedNoteIdAfter -and
                $observerReadOnlyEvidence.selectedNoteBeatBefore -ceq $observerReadOnlyEvidence.selectedNoteBeatAfter -and
                $observerReadOnlyEvidence.selectToolEnabled -and
                -not $observerReadOnlyEvidence.tapToolEnabled -and
                -not $observerReadOnlyEvidence.holdToolEnabled -and
                -not $observerReadOnlyEvidence.eraseToolEnabled -and
                $observerReadOnlyEvidence.metadataControlsDisabled -and
                $observerReadOnlyEvidence.timingControlsDisabled -and
                $observerReadOnlyEvidence.noteControlsDisabled
            if (-not $observerReadOnlyEvidence.passed) {
                throw "Observer physical read-only gate changed the chart or left an editing control enabled."
            }
        }

        $ownerFriendsBack = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Friends.Back" -TimeoutMilliseconds 15000
        Invoke-PhysicalElementClick $ownerFriendsBack $ownerHandle
        $physicalActions.Add("owner-return-to-active-room")
        $ownerChatText = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Active.ChatText" -TimeoutMilliseconds 20000
        Set-ElementValue $ownerChatText "隐藏密码房邀请已验证"
        $ownerChatSend = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Active.ChatSend"
        Invoke-PhysicalElementClick $ownerChatSend $ownerHandle
        $physicalActions.Add("owner-send-post-invite-chat")
        [void](Wait-HarnessState $endpoint {
            param($state)
            [int]$state.chatCount -eq 1
        } "post-invitation owner chat")
        $ownerRefresh = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Active.Refresh"
        Invoke-PhysicalElementClick $ownerRefresh $ownerHandle
        $physicalActions.Add("owner-refresh-members")
        $ownerRoomStatus = Wait-ElementName -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Active.Status" -Like "*2 名成员*" -Seconds 20
        $observations.ownerRoomStatus = Observe-Element $ownerRoomStatus
        $captures.ownerMembersAfterInvite = Capture-Window `
            $ownerHandle `
            (Join-Path $outputFullPath "owner-members-after-hidden-invite.png")

        $memberAccountButton = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineAccount.Navigation" -TimeoutMilliseconds 20000
        Invoke-Element $memberAccountButton
        $memberCommunity = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 30000
        $memberUnreadRoomNavigation = Find-ElementByIdAndNameLike `
            -ProcessId $member.Process.Id `
            -AutomationId "OnlineCommunity.Navigation.Rooms" `
            -Like "*1 条未读*" `
            -TimeoutMilliseconds 30000
        $observations.memberUnreadRoomNavigation = Observe-Element $memberUnreadRoomNavigation
        $captures.memberUnreadRedDot = Capture-Window `
            $memberHandle `
            (Join-Path $outputFullPath "member-room-unread-red-dot.png")
        Invoke-PhysicalElementClick $memberUnreadRoomNavigation `
            $memberHandle
        $physicalActions.Add("member-open-room-from-unread-red-dot")
        $memberRoomStatusPattern = if ($observerInvitation) {
            "*2 名成员*身份 观察者*权限 M:只读 T:只读 N:只读*"
        } else {
            "*2 名成员*身份 编辑者*"
        }
        $memberRoomStatus = Wait-ElementName -ProcessId $member.Process.Id `
            -AutomationId "OnlineRooms.Active.Status" -Like $memberRoomStatusPattern -Seconds 30
        $memberRoomMembers = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineRooms.Active.Members" -TimeoutMilliseconds 20000
        $memberRoomChat = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineRooms.Active.Chat" -TimeoutMilliseconds 20000
        $observations.memberRoomStatus = Observe-Element $memberRoomStatus
        $observations.memberRoomMembers = Observe-Element $memberRoomMembers
        $observations.memberRoomChat = Observe-Element $memberRoomChat
        if ($observerInvitation) {
            $memberChatText = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRooms.Active.ChatText" -TimeoutMilliseconds 10000
            $memberChatSend = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRooms.Active.ChatSend" -TimeoutMilliseconds 10000
            Set-ElementValue $memberChatText "观察者聊天正常，编辑保持只读"
            Invoke-PhysicalElementClick $memberChatSend `
                $memberHandle
            $physicalActions.Add("observer-send-chat-with-explicit-button")
            [void](Wait-HarnessState $endpoint {
                param($state)
                [int]$state.chatCount -eq 2
            } "observer chat without chart edit permission")
            $observations.observerChatSend = Observe-Element $memberChatSend
        }
        $captures.memberRoomMembersAndChat = Capture-Window `
            $memberHandle `
            (Join-Path $outputFullPath "member-room-members-and-chat.png")

        Wait-File $member.RoomRuntime "invited member room-tab GUI runtime evidence" 100
        $memberRoomRuntime = Get-Content -Raw -LiteralPath $member.RoomRuntime | ConvertFrom-Json
        $memberRoomChartPath = [string]$memberRoomRuntime.chart.sourcePath
        if (-not $memberRoomChartPath.StartsWith($member.LocalData, [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $memberRoomChartPath -PathType Leaf)) {
            throw "Invitation $invitationAction did not materialize the real MC chart inside the isolated member root."
        }

        if ($KeySoundLoopbackOnly) {
            $frozenSoundName = $loopbackSoundName
            $frozenSourcePath = Join-Path `
                (Split-Path -Parent $owner.InputChart) $frozenSoundName
            if (-not (Test-Path -LiteralPath $frozenSourcePath -PathType Leaf)) {
                throw "The deterministic room Note Sound fixture is missing: $frozenSourcePath"
            }
            $installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
            $fixtureBefore = [ordered]@{
                length = (Get-Item -LiteralPath $fixtureFullPath).Length
                sha256 = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
            }
            $soundBefore = [ordered]@{
                length = (Get-Item -LiteralPath $frozenSourcePath).Length
                sha256 = (Get-FileHash -LiteralPath $frozenSourcePath -Algorithm SHA256).Hash
            }
            $installerBefore = [ordered]@{
                length = (Get-Item -LiteralPath $installerPath).Length
                sha256 = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
            }

            $selected = @($ownerRuntime.timeline.selectedNotes)[0]
            if (-not $selected) {
                throw "Owner startup evidence did not expose the real selected Note."
            }
            $selectedId = [string]$selected.noteId
            $beforeSoundSnapshot = Get-ChartSnapshot $endpoint $owner.Token
            $targetBefore = @(
                $beforeSoundSnapshot.notes |
                    Where-Object { [string]$_.id -eq $selectedId })[0]
            if (-not $targetBefore) {
                throw "Selected Note $selectedId was absent from the room authority."
            }
            $operationCountBefore = [int](Get-HarnessState $endpoint).acceptedOperationCount
            Close-Community $owner
            $physicalActions.Add("uia-owner-close-community-before-key-sound-assignment")
            $ownerSoundButton = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "Inspector.Note.SoundExisting" -TimeoutMilliseconds 15000
            Invoke-Element $ownerSoundButton
            $ownerSoundItem = Find-ElementByName -ProcessId $owner.Process.Id `
                -Name $frozenSoundName -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerSoundItem $ownerHandle
            $physicalActions.Add("uia-owner-assign-frozen-room-note-sound")
            Wait-Condition -Description "owner frozen room Note Sound operation" `
                -Seconds 30 -Condition {
                $snapshot = Get-ChartSnapshot $endpoint $owner.Token
                $note = @(
                    $snapshot.notes |
                        Where-Object { [string]$_.id -eq $selectedId })[0]
                $note -and [string]$note.sound -ceq $frozenSoundName
            }

            $materializedSoundPath = Join-Path `
                (Split-Path -Parent $memberRoomChartPath) $frozenSoundName
            Wait-File $materializedSoundPath "member materialized frozen Note Sound" 30
            $materializedHash =
                (Get-FileHash -LiteralPath $materializedSoundPath -Algorithm SHA256).Hash
            if ($materializedHash -cne $soundBefore.sha256) {
                throw "Member frozen Note Sound materialization changed the OGG bytes."
            }

            Close-Community $member
            $physicalActions.Add("uia-member-close-community-before-key-sound-playback")
            $memberSettingsTab = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Inspector.SettingsTab" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $memberSettingsTab $memberHandle
            $physicalActions.Add("uia-member-open-settings-key-sound-panel")
            $memberKeySoundPanel = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "KeySound.Panel" -TimeoutMilliseconds 10000
            $memberKeySoundPanel = Show-ElementInScrollViewport `
                $memberKeySoundPanel 100
            $observations.memberKeySoundPanel = Observe-Element $memberKeySoundPanel

            $script:keySoundReadyDiagnostics = $null
            Wait-Condition -Description "member frozen Note Sound preload plan" `
                -Seconds 45 -PollMilliseconds 150 -Condition {
                $diagnostics = Get-KeySoundRuntimeDiagnostics $member.Process.Id
                if (-not $diagnostics.preparing -and
                    $diagnostics.hasPlan -and
                    $diagnostics.enabled -and
                    $diagnostics.planEvents -ge 1 -and
                    # The isolated global custom sample is silent. A second
                    # preload proves the remotely assigned room sample has
                    # reached the member plan before playback starts.
                    $diagnostics.planPreloads -ge 2 -and
                    $diagnostics.preloadAccepted -ge 2 -and
                    $diagnostics.preloadRejected -eq 0 -and
                    $diagnostics.planFailures -eq 0) {
                    $script:keySoundReadyDiagnostics = $diagnostics
                    return $true
                }
                return $false
            }
            $keySoundReadyDiagnostics = $script:keySoundReadyDiagnostics
            $script:keySoundReadyDiagnostics = $null

            $memberAudioVolume = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Audio.Volume" -TimeoutMilliseconds 10000
            $audioVolumeBefore = Get-ElementRangeValue $memberAudioVolume
            [void](Set-ElementRangeValue $memberAudioVolume 0)
            Wait-Condition -Description "member music volume zero" -Seconds 10 -Condition {
                [Math]::Abs(
                    [double](Get-ElementRangeValue (
                        Find-ElementById -ProcessId $member.Process.Id `
                            -AutomationId "Audio.Volume" `
                            -TimeoutMilliseconds 1000)).value) -le .001
            }
            $audioVolumeAfter = Get-ElementRangeValue (
                Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "Audio.Volume")

            $memberSnapPreset = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.QuickValues.Snap.Preset" `
                -TimeoutMilliseconds 10000
            Invoke-Element $memberSnapPreset
            $memberSnap24 = Find-ElementByName -ProcessId $member.Process.Id `
                -Name "1/24" -TimeoutMilliseconds 10000
            $memberSnap24Bounds = $memberSnap24.Current.BoundingRectangle
            Invoke-PhysicalClick `
                ([int][Math]::Round(
                    $memberSnap24Bounds.Left + $memberSnap24Bounds.Width / 2)) `
                ([int][Math]::Round(
                    $memberSnap24Bounds.Top + $memberSnap24Bounds.Height / 2)) `
                $memberHandle
            $physicalActions.Add("member-physical-click-snap-division-24")
            Wait-Condition -Description "member live snap division 24" `
                -Seconds 10 -PollMilliseconds 50 -Condition {
                [int](Get-TimelineLiveState $member.Process.Id).snapDivision -eq 24
            }
            $timelineBeforeWheel = Get-TimelineLiveState $member.Process.Id
            $wheelSnapDivision = [int]$timelineBeforeWheel.snapDivision
            $beforeWheelBeat = [double]$timelineBeforeWheel.currentBeat
            $wheelBeatDelta = [double](1.0 / [double]$wheelSnapDivision)
            $memberTimeline = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Timeline.Surface" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementWheel $memberTimeline 1 $memberHandle
            $physicalActions.Add(
                "member-physical-wheel-red-line-one-1-24-division-before-target")
            Wait-Condition -Description "member red line before frozen Note Sound target" `
                -Seconds 10 -PollMilliseconds 50 -Condition {
                $live = Get-TimelineLiveState $member.Process.Id
                if ([double]$live.currentBeat -lt
                        $beforeWheelBeat -
                            $wheelBeatDelta + .05 -and
                    [double]$live.currentBeat -lt
                        $beforeWheelBeat) {
                    return $true
                }
                return $false
            }
            $timelineAfterWheel = Get-TimelineLiveState $member.Process.Id
            $afterWheelBeat = [double]$timelineAfterWheel.currentBeat
            $expectedWheelBeat = [double]($beforeWheelBeat - $wheelBeatDelta)
            $wheelBeatError = [double][Math]::Abs(
                $afterWheelBeat - $expectedWheelBeat)
            if ($wheelBeatError -gt 0.0000001) {
                throw (
                    "Physical wheel did not preserve exact current-division " +
                    "red-line movement: before=$beforeWheelBeat; " +
                    "after=$afterWheelBeat; expected=$expectedWheelBeat; " +
                    "error=$wheelBeatError; snap=$wheelSnapDivision.")
            }

            $runtimeBeforePlay = Get-KeySoundRuntimeDiagnostics $member.Process.Id
            if (-not $runtimeBeforePlay.enabled -or
                $runtimeBeforePlay.planPreloads -lt 2 -or
                $runtimeBeforePlay.preloadAccepted -lt 2) {
                throw "Member Key-sound plan stopped being ready before playback."
            }
            $captures.memberKeySoundBeforePlayback = Capture-Window `
                $memberHandle `
                (Join-Path $outputFullPath "member-key-sound-before-playback.png")

            $probeReadyPath = Join-Path $outputFullPath "key-sound-loopback-ready.json"
            $probeOutputPath = Join-Path $outputFullPath "key-sound-loopback-probe.json"
            $probeWavePath = Join-Path $outputFullPath "key-sound-loopback.wav"
            $probeLogPath = Join-Path $outputFullPath "key-sound-loopback-probe.log"
            $probeStart = [Diagnostics.ProcessStartInfo]::new("dotnet")
            $probeStart.UseShellExecute = $false
            $probeStart.RedirectStandardOutput = $true
            $probeStart.RedirectStandardError = $true
            $probeStart.WorkingDirectory = Split-Path -Parent $probeAssemblyFullPath
            foreach ($argument in @(
                    $probeAssemblyFullPath,
                    "--output", $probeOutputPath,
                    "--wav", $probeWavePath,
                    "--ready", $probeReadyPath,
                    "--duration-ms", "4200",
                    "--process-id", ([string]$member.Process.Id),
                    "--reference-audio", $materializedSoundPath)) {
                $probeStart.ArgumentList.Add($argument)
            }
            $probe = [Diagnostics.Process]::Start($probeStart)
            Wait-File $probeReadyPath "WASAPI loopback probe ready" 20
            $probeReady = Get-Content -Raw -LiteralPath $probeReadyPath |
                ConvertFrom-Json -DateKind String
            Start-Sleep -Milliseconds 500

            $memberPlay = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.QuickPlayPause" -TimeoutMilliseconds 10000
            $playInvokedUtc = [DateTimeOffset]::UtcNow
            Invoke-Element $memberPlay
            $physicalActions.Add("uia-member-play-real-room-chart")
            Start-Sleep -Milliseconds 2200
            Invoke-Element (
                Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "Editor.QuickPlayPause" `
                    -TimeoutMilliseconds 5000)
            $physicalActions.Add("uia-member-pause-after-room-key-sound-trigger")
            $captures.memberKeySoundAfterTrigger = Capture-Window `
                $memberHandle `
                (Join-Path $outputFullPath "member-key-sound-after-trigger.png")

            if (-not $probe.WaitForExit(15000)) {
                throw "WASAPI loopback probe did not exit after its capture window."
            }
            $probeStandardOutput = $probe.StandardOutput.ReadToEnd()
            $probeStandardError = $probe.StandardError.ReadToEnd()
            ($probeStandardOutput + $probeStandardError) |
                Set-Content -LiteralPath $probeLogPath -Encoding utf8NoBOM
            if ($probe.ExitCode -ne 0) {
                throw "WASAPI loopback probe exited $($probe.ExitCode): $probeStandardError"
            }
            $probe.Dispose()
            $probe = $null
            Wait-File $probeOutputPath "WASAPI loopback probe output" 5
            Wait-File $probeWavePath "WASAPI loopback wave" 5

            # Runtime counters are intentionally not pushed through UIA for every
            # dense-chart trigger. Refresh the diagnostic snapshot only after the
            # loopback capture is closed, so this preview cannot contaminate the
            # authoritative room-OGG waveform.
            $memberPreview = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "KeySound.Preview" -TimeoutMilliseconds 10000
            Invoke-Element $memberPreview
            $physicalActions.Add(
                "uia-member-preview-after-loopback-only-to-refresh-runtime-diagnostics")
            Wait-Condition -Description "post-capture Key Sound runtime diagnostic refresh" `
                -Seconds 10 -PollMilliseconds 50 -Condition {
                $diagnostics = Get-KeySoundRuntimeDiagnostics $member.Process.Id
                if ($diagnostics.previewAccepted -gt
                        $runtimeBeforePlay.previewAccepted -and
                    $diagnostics.triggersAccepted -gt
                        $runtimeBeforePlay.triggersAccepted -and
                    $diagnostics.sharedAccepted -gt
                        $runtimeBeforePlay.sharedAccepted) {
                    return $true
                }
                return $false
            }
            $triggerAcceptedUtc = [DateTimeOffset]::UtcNow
            $runtimeAfterTrigger =
                Get-KeySoundRuntimeDiagnostics $member.Process.Id
            if ($runtimeAfterTrigger.previewAccepted -ne
                    $runtimeBeforePlay.previewAccepted + 1 -or
                $runtimeAfterTrigger.previewRejected -ne
                    $runtimeBeforePlay.previewRejected -or
                $runtimeAfterTrigger.triggersRejected -ne
                    $runtimeBeforePlay.triggersRejected -or
                $runtimeAfterTrigger.sharedRejected -ne
                    $runtimeBeforePlay.sharedRejected -or
                $runtimeAfterTrigger.standaloneAccepted -ne
                    $runtimeBeforePlay.standaloneAccepted -or
                $runtimeAfterTrigger.standaloneRejected -ne
                    $runtimeBeforePlay.standaloneRejected) {
                throw "Room Note Sound used a rejected or standalone output path."
            }

            $probeEvidence = Get-Content -Raw -LiteralPath $probeOutputPath |
                ConvertFrom-Json -DateKind String
            if ($probeEvidence.status -cne "captured" -or
                $probeEvidence.capture.bytes -le 0 -or
                -not [bool]$probeEvidence.capture.timelineIncludesInsertedSilence) {
                throw "WASAPI loopback did not capture a real render stream."
            }
            if ($probeEvidence.analysis.detectedPulseCount -lt 1 -or
                $probeEvidence.analysis.peak -lt .005 -or
                $probeEvidence.analysis.signalToNoiseDb -lt 20 -or
                $probeEvidence.analysis.configuredReferenceFrameCount -lt 1000 -or
                    $probeEvidence.analysis.bestConfiguredReferenceCorrelation -lt .12 -or
                    $probeEvidence.analysis.bestConfiguredReferenceSpectralSimilarity -lt .24) {
                throw "Loopback waveform did not prove the materialized room Note Sound: " +
                    ($probeEvidence.analysis | ConvertTo-Json -Compress -Depth 8)
            }
            $captureStartedUtc =
                [DateTimeOffset]::Parse([string]$probeReady.startedUtc)
            $strongestPulse = $probeEvidence.analysis.strongestPulse
            $strongestPulseUtc = $captureStartedUtc.AddMilliseconds(
                [double]$strongestPulse.startMilliseconds)
            $pulseFromPlayMilliseconds =
                ($strongestPulseUtc - $playInvokedUtc).TotalMilliseconds
            if ($pulseFromPlayMilliseconds -lt -120 -or
                    $pulseFromPlayMilliseconds -gt 1600) {
                throw "The room-sample-correlated render pulse was not aligned with playback: " +
                    "$pulseFromPlayMilliseconds ms."
            }

            $afterSoundSnapshot = Get-ChartSnapshot $endpoint $member.Token
            $targetAfter = @(
                $afterSoundSnapshot.notes |
                    Where-Object { [string]$_.id -eq $selectedId })[0]
            $finalState = Get-HarnessState $endpoint
            if (-not $targetAfter -or
                [string]$targetAfter.sound -cne $frozenSoundName -or
                [int]$finalState.acceptedOperationCount -ne
                    $operationCountBefore + 1 -or
                [int]$finalState.resourceCommitCount -ne
                    [int]$afterCreate.resourceCommitCount -or
                [int]$finalState.uploadedBlobCount -ne
                    [int]$afterCreate.uploadedBlobCount) {
                throw "Frozen Note Sound playback changed resources or submitted unexpected operations."
            }
            foreach ($propertyName in @(
                    "lane", "volume", "group", "isDraft", "draftColumn",
                    "creatorUserId")) {
                if ([string]$targetAfter.$propertyName -cne
                    [string]$targetBefore.$propertyName) {
                    throw "Frozen Note Sound assignment changed Note.$propertyName."
                }
            }
            if (($targetAfter.beat | ConvertTo-Json -Compress) -cne
                    ($targetBefore.beat | ConvertTo-Json -Compress) -or
                ($targetAfter.endBeat | ConvertTo-Json -Compress) -cne
                    ($targetBefore.endBeat | ConvertTo-Json -Compress) -or
                [string]$targetAfter.unknownJson -cne
                    [string]$targetBefore.unknownJson) {
                throw "Frozen Note Sound assignment changed rational Beat or extension data."
            }

            $fixtureAfter = [ordered]@{
                length = (Get-Item -LiteralPath $fixtureFullPath).Length
                sha256 = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
            }
            $soundAfter = [ordered]@{
                length = (Get-Item -LiteralPath $frozenSourcePath).Length
                sha256 = (Get-FileHash -LiteralPath $frozenSourcePath -Algorithm SHA256).Hash
            }
            $installerAfter = [ordered]@{
                length = (Get-Item -LiteralPath $installerPath).Length
                sha256 = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
            }
            if (($fixtureBefore | ConvertTo-Json -Compress) -cne
                    ($fixtureAfter | ConvertTo-Json -Compress) -or
                ($soundBefore | ConvertTo-Json -Compress) -cne
                    ($soundAfter | ConvertTo-Json -Compress) -or
                ($installerBefore | ConvertTo-Json -Compress) -cne
                    ($installerAfter | ConvertTo-Json -Compress)) {
                throw "Frozen fixtures or released WPF installer changed during playback verification."
            }

            $screenshots = [ordered]@{}
            foreach ($file in Get-ChildItem -LiteralPath $outputFullPath `
                    -File -Filter *.png | Sort-Object Name) {
                $screenshots[$file.BaseName] = [ordered]@{
                    path = $file.FullName
                    length = $file.Length
                    sha256 = (
                        Get-FileHash -LiteralPath $file.FullName `
                            -Algorithm SHA256).Hash
                }
            }
            $evidence = [ordered]@{
                schema =
                    "lumachart.windows.avalonia.online-room-note-sound-loopback-gui-evidence.v2"
                generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
                status = if ($FormalMigrationAuthority) {
                    "passed-migration-incomplete"
                } else { "preflight-passed-nonformal" }
                formalMigrationAuthority = [bool]$FormalMigrationAuthority
                completion = $false
                migrationComplete = $false
                windowsAvaloniaOnly = $true
                productionServerMutationPerformed = $false
                mobileProjectsBuiltModifiedInstalledOrTested = $false
                pureDotnetRelease = $true
                ollvmObfuscationPackingVirtualizationOrAotUsed = $false
                physicalMouseInputUsed = $true
                uiAutomationInvokeToggleSelectionAndRangeValueUsed = $true
                enterKeyUsed = $false
                endpoint = $endpoint
                paths = [ordered]@{
                    projectRoot = $projectRoot
                    outputRoot = $outputFullPath
                    application = $applicationFullPath
                    serverAssembly = $serverAssemblyFullPath
                    probeAssembly = $probeAssemblyFullPath
                    fixture = $fixtureFullPath
                    frozenSoundSource = $frozenSourcePath
                    memberMaterializedChart = $memberRoomChartPath
                    memberMaterializedSound = $materializedSoundPath
                    probeWave = $probeWavePath
                    temp = $projectTemp
                    dotnetHome = $dotnetHome
                    nugetPackages = $nugetPackages
                    nugetHttpCache = $nugetHttpCache
                }
                hashes = [ordered]@{
                    fixtureBefore = $fixtureBefore
                    fixtureAfter = $fixtureAfter
                    frozenSoundBefore = $soundBefore
                    frozenSoundAfter = $soundAfter
                    memberMaterializedSoundSha256 = $materializedHash
                    releasedInstallerBefore = $installerBefore
                    releasedInstallerAfter = $installerAfter
                    probeWaveSha256 = (
                        Get-FileHash -LiteralPath $probeWavePath `
                            -Algorithm SHA256).Hash
                }
                processIds = [ordered]@{
                    server = $server.Id
                    owner = $owner.Process.Id
                    member = $member.Process.Id
                }
                room = [ordered]@{
                    private = [bool]$finalState.room.isPrivate
                    hidden = [bool]$finalState.room.isHidden
                    invitationAction = $invitationAction
                    resourcesReady = [bool]$finalState.room.resourcesReady
                    resourceEntryCount = [int]$finalState.resourceEntryCount
                    acceptedOperationCountBefore = $operationCountBefore
                    acceptedOperationCountAfter =
                        [int]$finalState.acceptedOperationCount
                    finalServerState = $finalState
                }
                noteSound = [ordered]@{
                    noteId = $selectedId
                    lane = [int]$targetAfter.lane
                    beat = $targetAfter.beat
                    sound = $frozenSoundName
                    sourceSha256 = $soundBefore.sha256
                    materializedSha256 = $materializedHash
                    targetBefore = $targetBefore
                    targetAfter = $targetAfter
                    nonSoundFieldsPreserved = $true
                }
                audio = [ordered]@{
                    musicVolumeBefore = $audioVolumeBefore
                    musicVolumeAfter = $audioVolumeAfter
                    timelineBeforePhysicalWheel = $timelineBeforeWheel
                    timelineAfterPhysicalWheel = $timelineAfterWheel
                    wheelSnapDivision = $wheelSnapDivision
                    wheelBeatDelta = $wheelBeatDelta
                    targetBeat = $targetBefore.beat
                    redLineStartedBeforeTarget = $true
                    keySoundVolume = .7
                    songMutedWhileOverlayRemainedAudible = $true
                }
                runtime = [ordered]@{
                    readyAfterRemoteAssignment = $keySoundReadyDiagnostics
                    beforePlay = $runtimeBeforePlay
                    afterTrigger = $runtimeAfterTrigger
                    acceptedUtc = $triggerAcceptedUtc.ToString("O")
                    triggerAcceptedDelta =
                        $runtimeAfterTrigger.triggersAccepted -
                        $runtimeBeforePlay.triggersAccepted
                    sharedAcceptedDelta =
                        $runtimeAfterTrigger.sharedAccepted -
                        $runtimeBeforePlay.sharedAccepted
                    standaloneAcceptedDelta =
                        $runtimeAfterTrigger.standaloneAccepted -
                        $runtimeBeforePlay.standaloneAccepted
                    diagnosticRefreshPreviewAcceptedDelta =
                        $runtimeAfterTrigger.previewAccepted -
                        $runtimeBeforePlay.previewAccepted
                    diagnosticRefreshOccurredAfterLoopbackClosed = $true
                }
                loopback = [ordered]@{
                    ready = $probeReady
                    probe = $probeEvidence
                    playbackInvokedUtc = $playInvokedUtc.ToString("O")
                    strongestPulseUtc = $strongestPulseUtc.ToString("O")
                    strongestPulseFromPlaybackMilliseconds =
                        $pulseFromPlayMilliseconds
                    configuredReferenceIsMaterializedRoomNoteSound = $true
                    minimumConfiguredReferenceCorrelation = .12
                    minimumConfiguredReferenceSpectralSimilarity = .24
                    capturedRenderMix = $true
                    arbitrarySystemAudioRejectedByReferenceCorrelation = $true
                }
                actions = $physicalActions.ToArray()
                controls = $observations
                captures = $captures
                screenshots = $screenshots
            }
            $evidencePath = Join-Path $outputFullPath "evidence.json"
            $evidence | ConvertTo-Json -Depth 70 |
                Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
            Write-Output (
                "Windows Avalonia online room Note Sound loopback GUI capture: " +
                $evidence.status)
            Write-Output "Evidence: $evidencePath"
            return
        }

        if ($MetadataPreviewRaceOnly) {
            $raceStateBefore = Get-HarnessState $endpoint
            $raceMemberBefore = @($raceStateBefore.members |
                Where-Object { [long]$_.userId -eq 4202 })[0]
            if ([string]$raceMemberBefore.memberRole -cne "editor" -or
                [bool]$raceMemberBefore.canEditMetadata -or
                [bool]$raceMemberBefore.canEditTiming -or
                -not [bool]$raceMemberBefore.canEditNotes) {
                throw "Metadata race member did not start with editor M:false/T:false/N:true access."
            }
            $raceOperationCountBefore = [int]$raceStateBefore.acceptedOperationCount
            $raceSnapshotBefore = Get-ChartSnapshot $endpoint $member.Token
            $raceStructureBeforeJson = [ordered]@{
                keyCount = [int]$raceSnapshotBefore.keyCount
                notes = @($raceSnapshotBefore.notes)
                timing = @($raceSnapshotBefore.timing)
                locks = @($raceSnapshotBefore.locks)
            } | ConvertTo-Json -Depth 40 -Compress
            $baselineTitle = [string]$raceSnapshotBefore.metadata.title
            $baselineArtist = [string]$raceSnapshotBefore.metadata.artist
            $baselinePreviewTime = [int]$raceSnapshotBefore.metadata.previewTime

            $ownerManageMember = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.4202.Manage" -TimeoutMilliseconds 20000
            Invoke-PhysicalElementClick $ownerManageMember $ownerHandle
            $physicalActions.Add("owner-open-member-access-for-metadata-race")
            $ownerMetadataPermission = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Metadata" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerMetadataPermission $ownerHandle
            $physicalActions.Add("owner-enable-member-metadata-for-race")
            $ownerSaveAccess = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Save" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerSaveAccess $ownerHandle
            $physicalActions.Add("owner-save-member-metadata-grant")
            [void](Wait-HarnessState $endpoint {
                param($state)
                $candidate = @($state.members |
                    Where-Object { [long]$_.userId -eq 4202 })[0]
                $candidate -and [string]$candidate.memberRole -ceq "editor" -and
                    [bool]$candidate.canEditMetadata -and
                    -not [bool]$candidate.canEditTiming -and
                    [bool]$candidate.canEditNotes
            } "member Metadata permission grant")

            $grantTitle = Wait-ElementName -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Title" `
                -Like "房间权限已更新" -Seconds 30
            $grantMessage = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Message" -TimeoutMilliseconds 10000
            $grantDismiss = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Dismiss" -TimeoutMilliseconds 10000
            $expectedMetadataGrantMessage =
                "谱面信息：允许编辑`nEffect / Timing Edit：不可编辑`nNote：允许编辑"
            if ([string]$grantMessage.Current.Name -cne $expectedMetadataGrantMessage) {
                throw "Metadata permission-grant notice did not match WPF 1.1.0."
            }
            $grantMessageText = [string]$grantMessage.Current.Name
            $captures.memberMetadataPermissionGranted = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-metadata-permission-granted.png")
            Invoke-PhysicalElementClick $grantDismiss $memberHandle
            $physicalActions.Add("member-dismiss-metadata-permission-grant")

            $memberCommunityClose = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineCommunity.Navigation.Close" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $memberCommunityClose $memberHandle
            $physicalActions.Add("member-return-to-editor-for-metadata-race")
            $ownerCommunityClose = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineCommunity.Navigation.Close" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerCommunityClose $ownerHandle
            $physicalActions.Add("owner-return-to-editor-for-metadata-race")
            Wait-Condition -Description "both community dialogs close for metadata race" `
                -Seconds 15 -Condition {
                $memberClosed = $false
                $ownerClosed = $false
                try {
                    [void](Find-ElementById -ProcessId $member.Process.Id `
                        -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 250)
                }
                catch { $memberClosed = $true }
                try {
                    [void](Find-ElementById -ProcessId $owner.Process.Id `
                        -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 250)
                }
                catch { $ownerClosed = $true }
                $memberClosed -and $ownerClosed
            }

            $memberMetadataTab = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Inspector.MetadataTab" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $memberMetadataTab $memberHandle
            $physicalActions.Add("member-open-metadata-for-dirty-draft")
            $memberTitle = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Title" -TimeoutMilliseconds 10000
            $memberArtist = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Artist" -TimeoutMilliseconds 10000
            $memberPreviewTime = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Metadata.PreviewTime" -TimeoutMilliseconds 10000
            $memberPreviewHere = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Metadata.PreviewHere" -TimeoutMilliseconds 10000
            $memberMetadataApply = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Apply" -TimeoutMilliseconds 10000
            if (-not $memberTitle.Current.IsEnabled -or
                -not $memberPreviewHere.Current.IsEnabled -or
                -not $memberMetadataApply.Current.IsEnabled) {
                throw "Member Metadata controls stayed disabled after permission grant."
            }
            $localPendingTitle = "Member Pending Title 7426"
            Set-ElementValue $memberTitle $localPendingTitle
            [void](Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Title" -ExpectedValue $localPendingTitle -Seconds 10)

            $ownerMetadataTab = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "Inspector.MetadataTab" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerMetadataTab $ownerHandle
            $physicalActions.Add("owner-open-metadata-for-remote-authority")
            $ownerArtist = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "Metadata.Artist" -TimeoutMilliseconds 10000
            $ownerRemoteArtist = "Owner Remote Artist 7426"
            Set-ElementValue $ownerArtist $ownerRemoteArtist
            $ownerMetadataApply = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "Metadata.Apply" -TimeoutMilliseconds 10000
            $ownerMetadataApply = Show-ElementInScrollViewport $ownerMetadataApply
            Invoke-PhysicalElementClick $ownerMetadataApply $ownerHandle
            $physicalActions.Add("owner-apply-remote-artist-over-member-draft")
            [void](Wait-HarnessState $endpoint {
                param($state)
                [int]$state.acceptedOperationCount -eq ($raceOperationCountBefore + 1) -and
                    [long]$state.revision -eq ([long]$raceSnapshotBefore.revision + 1)
            } "owner authoritative Metadata operation")
            $script:raceOwnerSnapshot = $null
            Wait-Condition -Description "owner remote Artist authority" -Seconds 30 -Condition {
                $candidate = Get-ChartSnapshot $endpoint $member.Token
                if ([string]$candidate.metadata.artist -ceq $ownerRemoteArtist) {
                    $script:raceOwnerSnapshot = $candidate
                    return $true
                }
                return $false
            }
            $ownerAuthoritySnapshot = $script:raceOwnerSnapshot
            $script:raceOwnerSnapshot = $null
            if ([string]$ownerAuthoritySnapshot.metadata.title -cne $baselineTitle -or
                [int]$ownerAuthoritySnapshot.metadata.previewTime -ne $baselinePreviewTime) {
                [ordered]@{
                    baseline = $raceSnapshotBefore
                    ownerRemote = $ownerAuthoritySnapshot
                } | ConvertTo-Json -Depth 40 |
                    Set-Content -LiteralPath (Join-Path $outputFullPath `
                        "owner-metadata-snapshot-diagnostic.json") `
                        -Encoding utf8NoBOM
                throw "Owner remote Artist edit changed Title or PreviewTime unexpectedly."
            }

            $memberTitle = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Title" -ExpectedValue $localPendingTitle -Seconds 30
            $memberArtist = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Artist" -ExpectedValue $ownerRemoteArtist -Seconds 30
            $memberPreviewTime = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.PreviewTime" `
                -ExpectedValue ([string]$baselinePreviewTime) -Seconds 30
            $memberMetadataStatus = Wait-ElementName -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Status" `
                -Like "远端谱面信息已同步；未应用的本地输入已保留" -Seconds 30
            if ([string]$memberMetadataStatus.Current.Name -cne
                "远端谱面信息已同步；未应用的本地输入已保留") {
                throw "Member dirty-draft merge status did not exactly match WPF 1.1.0."
            }
            $dirtyMergeStatusText = [string]$memberMetadataStatus.Current.Name
            $titlePreservedAfterRemoteArtist =
                (Get-ElementValue $memberTitle) -ceq $localPendingTitle
            $observations.memberMetadataDirtyMergeStatus =
                Observe-Element $memberMetadataStatus
            $captures.memberMetadataDirtyMerge = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-metadata-dirty-draft-merged.png")

            $memberPreviewHere = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Metadata.PreviewHere" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $memberPreviewHere $memberHandle
            $physicalActions.Add("member-set-preview-here-while-title-dirty")
            [void](Wait-HarnessState $endpoint {
                param($state)
                [int]$state.acceptedOperationCount -eq ($raceOperationCountBefore + 2) -and
                    [long]$state.revision -eq ([long]$raceSnapshotBefore.revision + 2)
            } "member Preview Here operation")
            $script:racePreviewSnapshot = $null
            Wait-Condition -Description "member Preview Here authority" -Seconds 30 -Condition {
                $candidate = Get-ChartSnapshot $endpoint $member.Token
                if ([int]$candidate.metadata.previewTime -ne $baselinePreviewTime) {
                    $script:racePreviewSnapshot = $candidate
                    return $true
                }
                return $false
            }
            $previewAuthoritySnapshot = $script:racePreviewSnapshot
            $script:racePreviewSnapshot = $null
            $chosenPreviewTime = [int]$previewAuthoritySnapshot.metadata.previewTime
            if ([string]$previewAuthoritySnapshot.metadata.title -cne $baselineTitle -or
                [string]$previewAuthoritySnapshot.metadata.artist -cne $ownerRemoteArtist) {
                throw "Preview Here overwrote the pending Title or owner Artist authority."
            }
            $memberTitle = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Title" -ExpectedValue $localPendingTitle -Seconds 30
            $memberArtist = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Artist" -ExpectedValue $ownerRemoteArtist -Seconds 30
            $memberPreviewTime = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.PreviewTime" `
                -ExpectedValue ([string]$chosenPreviewTime) -Seconds 30
            $captures.memberPreviewHerePreservesDraft = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-preview-here-preserves-draft.png")

            $ownerAccountButton = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineAccount.Navigation" -TimeoutMilliseconds 20000
            Invoke-Element $ownerAccountButton
            $ownerCommunity = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 30000
            $ownerRoomsNavigation = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineCommunity.Navigation.Rooms" -TimeoutMilliseconds 15000
            Invoke-Element $ownerRoomsNavigation
            $ownerManageMember = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.4202.Manage" -TimeoutMilliseconds 20000
            Invoke-PhysicalElementClick $ownerManageMember $ownerHandle
            $physicalActions.Add("owner-reopen-member-access-to-revoke-metadata")
            $ownerMetadataPermission = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Metadata" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerMetadataPermission $ownerHandle
            $physicalActions.Add("owner-revoke-member-metadata-with-dirty-draft")
            $ownerSaveAccess = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Save" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerSaveAccess $ownerHandle
            $physicalActions.Add("owner-save-member-metadata-revocation")
            [void](Wait-HarnessState $endpoint {
                param($state)
                $candidate = @($state.members |
                    Where-Object { [long]$_.userId -eq 4202 })[0]
                $candidate -and [string]$candidate.memberRole -ceq "editor" -and
                    -not [bool]$candidate.canEditMetadata -and
                    -not [bool]$candidate.canEditTiming -and
                    [bool]$candidate.canEditNotes
            } "member Metadata permission revocation")

            $revokeTitle = Wait-ElementName -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Title" `
                -Like "房间权限已更新" -Seconds 30
            $revokeMessage = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Message" -TimeoutMilliseconds 10000
            $revokeDismiss = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Dismiss" -TimeoutMilliseconds 10000
            $expectedMetadataRevokeMessage =
                "谱面信息：不可编辑`nEffect / Timing Edit：不可编辑`nNote：允许编辑"
            if ([string]$revokeMessage.Current.Name -cne $expectedMetadataRevokeMessage) {
                throw "Metadata permission-revocation notice did not match WPF 1.1.0."
            }
            $revokeMessageText = [string]$revokeMessage.Current.Name
            $captures.memberMetadataPermissionRevoked = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-metadata-permission-revoked.png")
            Invoke-PhysicalElementClick $revokeDismiss $memberHandle
            $physicalActions.Add("member-dismiss-metadata-permission-revocation")

            $memberTitle = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Title" -ExpectedValue $localPendingTitle -Seconds 20
            $memberArtist = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Artist" -ExpectedValue $ownerRemoteArtist -Seconds 20
            $memberPreviewTime = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.PreviewTime" `
                -ExpectedValue ([string]$chosenPreviewTime) -Seconds 20
            $memberPreviewHere = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Metadata.PreviewHere" -TimeoutMilliseconds 10000
            $memberMetadataApply = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Apply" -TimeoutMilliseconds 10000
            if ($memberTitle.Current.IsEnabled -or
                $memberPreviewHere.Current.IsEnabled -or
                $memberMetadataApply.Current.IsEnabled) {
                throw "Metadata controls did not disable immediately after permission revocation."
            }
            $deniedSnapshotBefore = Get-ChartSnapshot $endpoint $member.Token
            $deniedSnapshotBeforeJson =
                $deniedSnapshotBefore | ConvertTo-Json -Depth 40 -Compress
            Invoke-PhysicalElementClick $memberPreviewHere $memberHandle
            $physicalActions.Add("member-physically-attempt-disabled-preview-here")
            $memberMetadataApply = Show-ElementInScrollViewport $memberMetadataApply
            Invoke-PhysicalElementClick $memberMetadataApply $memberHandle
            $physicalActions.Add("member-physically-attempt-disabled-metadata-apply")
            Start-Sleep -Milliseconds 1500
            $deniedStateAfter = Get-HarnessState $endpoint
            $deniedSnapshotAfter = Get-ChartSnapshot $endpoint $member.Token
            $deniedSnapshotAfterJson =
                $deniedSnapshotAfter | ConvertTo-Json -Depth 40 -Compress
            if ([int]$deniedStateAfter.acceptedOperationCount -ne
                    ($raceOperationCountBefore + 2) -or
                $deniedSnapshotBeforeJson -cne $deniedSnapshotAfterJson) {
                throw "Disabled Metadata controls submitted or changed the room chart."
            }
            $observations.memberMetadataTitleDisabled = Observe-Element $memberTitle
            $observations.memberPreviewHereDisabled = Observe-Element $memberPreviewHere
            $observations.memberMetadataApplyDisabled = Observe-Element $memberMetadataApply
            $captures.memberMetadataDraftDisabled = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-metadata-draft-disabled-after-revoke.png")

            $ownerManageMember = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.4202.Manage" -TimeoutMilliseconds 20000
            Invoke-PhysicalElementClick $ownerManageMember $ownerHandle
            $physicalActions.Add("owner-reopen-member-access-to-restore-metadata")
            $ownerMetadataPermission = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Metadata" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerMetadataPermission $ownerHandle
            $physicalActions.Add("owner-restore-member-metadata-with-dirty-draft")
            $ownerSaveAccess = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Save" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerSaveAccess $ownerHandle
            $physicalActions.Add("owner-save-member-metadata-restoration")
            [void](Wait-HarnessState $endpoint {
                param($state)
                $candidate = @($state.members |
                    Where-Object { [long]$_.userId -eq 4202 })[0]
                $candidate -and [string]$candidate.memberRole -ceq "editor" -and
                    [bool]$candidate.canEditMetadata -and
                    -not [bool]$candidate.canEditTiming -and
                    [bool]$candidate.canEditNotes
            } "member Metadata permission restoration")

            $restoreTitle = Wait-ElementName -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Title" `
                -Like "房间权限已更新" -Seconds 30
            $restoreMessage = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Message" -TimeoutMilliseconds 10000
            $restoreDismiss = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Dismiss" -TimeoutMilliseconds 10000
            if ([string]$restoreMessage.Current.Name -cne $expectedMetadataGrantMessage) {
                throw "Metadata permission-restoration notice did not match WPF 1.1.0."
            }
            $restoreMessageText = [string]$restoreMessage.Current.Name
            $captures.memberMetadataPermissionRestored = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-metadata-permission-restored.png")
            Invoke-PhysicalElementClick $restoreDismiss $memberHandle
            $physicalActions.Add("member-dismiss-metadata-permission-restoration")

            $memberTitle = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Title" -ExpectedValue $localPendingTitle -Seconds 20
            $memberArtist = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Artist" -ExpectedValue $ownerRemoteArtist -Seconds 20
            $memberPreviewTime = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.PreviewTime" `
                -ExpectedValue ([string]$chosenPreviewTime) -Seconds 20
            $memberMetadataApply = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Apply" -TimeoutMilliseconds 10000
            if (-not $memberTitle.Current.IsEnabled -or
                -not $memberMetadataApply.Current.IsEnabled) {
                throw "Metadata controls did not re-enable after permission restoration."
            }
            $memberMetadataApply = Show-ElementInScrollViewport $memberMetadataApply
            Invoke-PhysicalElementClick $memberMetadataApply $memberHandle
            $physicalActions.Add("member-apply-preserved-title-after-metadata-restore")
            $raceFinalState = Wait-HarnessState $endpoint {
                param($state)
                [int]$state.acceptedOperationCount -eq ($raceOperationCountBefore + 3) -and
                    [long]$state.revision -eq ([long]$raceSnapshotBefore.revision + 3)
            } "member preserved Metadata draft operation"
            $script:raceFinalSnapshot = $null
            Wait-Condition -Description "final merged Metadata authority" -Seconds 30 -Condition {
                $candidate = Get-ChartSnapshot $endpoint $member.Token
                if ([string]$candidate.metadata.title -ceq $localPendingTitle -and
                    [string]$candidate.metadata.artist -ceq $ownerRemoteArtist -and
                    [int]$candidate.metadata.previewTime -eq $chosenPreviewTime) {
                    $script:raceFinalSnapshot = $candidate
                    return $true
                }
                return $false
            }
            $finalAuthoritySnapshot = $script:raceFinalSnapshot
            $script:raceFinalSnapshot = $null

            $metadataOtherFieldsEqual = $true
            foreach ($field in @(
                    "titleOriginal", "artistOriginal", "creator", "version",
                    "audioFile", "coverFile", "backgroundFile",
                    "overallDifficulty", "hpDrainRate", "bpm")) {
                if (($raceSnapshotBefore.metadata.$field |
                        ConvertTo-Json -Compress) -cne
                    ($finalAuthoritySnapshot.metadata.$field |
                        ConvertTo-Json -Compress)) {
                    $metadataOtherFieldsEqual = $false
                    break
                }
            }
            $raceStructureAfterJson = [ordered]@{
                keyCount = [int]$finalAuthoritySnapshot.keyCount
                notes = @($finalAuthoritySnapshot.notes)
                timing = @($finalAuthoritySnapshot.timing)
                locks = @($finalAuthoritySnapshot.locks)
            } | ConvertTo-Json -Depth 40 -Compress

            $ownerCommunityClose = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineCommunity.Navigation.Close" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerCommunityClose $ownerHandle
            $physicalActions.Add("owner-return-to-editor-for-final-metadata-convergence")
            $ownerMetadataTab = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "Inspector.MetadataTab" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerMetadataTab $ownerHandle
            $physicalActions.Add("owner-open-final-metadata-convergence")
            $ownerTitle = Wait-ElementValue -ProcessId $owner.Process.Id `
                -AutomationId "Metadata.Title" -ExpectedValue $localPendingTitle -Seconds 30
            $ownerArtist = Wait-ElementValue -ProcessId $owner.Process.Id `
                -AutomationId "Metadata.Artist" -ExpectedValue $ownerRemoteArtist -Seconds 30
            $ownerPreviewTime = Wait-ElementValue -ProcessId $owner.Process.Id `
                -AutomationId "Metadata.PreviewTime" `
                -ExpectedValue ([string]$chosenPreviewTime) -Seconds 30
            $memberTitle = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Title" -ExpectedValue $localPendingTitle -Seconds 30
            $memberArtist = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.Artist" -ExpectedValue $ownerRemoteArtist -Seconds 30
            $memberPreviewTime = Wait-ElementValue -ProcessId $member.Process.Id `
                -AutomationId "Metadata.PreviewTime" `
                -ExpectedValue ([string]$chosenPreviewTime) -Seconds 30
            $raceFinalRevision = [int]$raceFinalState.revision
            $ownerFinalStatus = Wait-ElementName -ProcessId $owner.Process.Id `
                -AutomationId "Editor.Status" `
                -Like "*revision $raceFinalRevision*" -Seconds 30
            $memberFinalStatus = Wait-ElementName -ProcessId $member.Process.Id `
                -AutomationId "Editor.Status" `
                -Like "*revision $raceFinalRevision*" -Seconds 30
            $ownerTitle = Show-ElementInScrollViewport $ownerTitle 0
            $memberTitle = Show-ElementInScrollViewport $memberTitle 0
            $captures.ownerMetadataFinalConvergence = Capture-Window $ownerHandle `
                (Join-Path $outputFullPath "owner-metadata-final-convergence.png")
            $captures.memberMetadataFinalConvergence = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-metadata-final-convergence.png")

            $acceptedMetadataOperations = @($raceFinalState.acceptedOperations |
                Select-Object -Last 3)
            $metadataPreviewRaceEvidence = [ordered]@{
                initialRole = [string]$raceMemberBefore.memberRole
                initialCanEditMetadata = [bool]$raceMemberBefore.canEditMetadata
                grantMessage = $grantMessageText
                localPendingTitle = $localPendingTitle
                baselineTitle = $baselineTitle
                baselineArtist = $baselineArtist
                baselinePreviewTime = $baselinePreviewTime
                ownerRemoteArtist = $ownerRemoteArtist
                dirtyMergeStatus = $dirtyMergeStatusText
                titlePreservedAfterRemoteArtist = $titlePreservedAfterRemoteArtist
                chosenPreviewTime = $chosenPreviewTime
                previewChanged = $chosenPreviewTime -ne $baselinePreviewTime
                titlePreservedAfterPreviewHere =
                    [string]$previewAuthoritySnapshot.metadata.title -ceq $baselineTitle
                artistPreservedAfterPreviewHere =
                    [string]$previewAuthoritySnapshot.metadata.artist -ceq $ownerRemoteArtist
                revokeMessage = $revokeMessageText
                disabledAttemptOperationCountBefore = $raceOperationCountBefore + 2
                disabledAttemptOperationCountAfter =
                    [int]$deniedStateAfter.acceptedOperationCount
                disabledAttemptChartEqual = $deniedSnapshotBeforeJson -ceq
                    $deniedSnapshotAfterJson
                restoreMessage = $restoreMessageText
                acceptedOperationCountBefore = $raceOperationCountBefore
                acceptedOperationCountAfter =
                    [int]$raceFinalState.acceptedOperationCount
                revisionBefore = [long]$raceSnapshotBefore.revision
                revisionAfter = [long]$finalAuthoritySnapshot.revision
                acceptedMetadataOperations = $acceptedMetadataOperations
                finalTitle = [string]$finalAuthoritySnapshot.metadata.title
                finalArtist = [string]$finalAuthoritySnapshot.metadata.artist
                finalPreviewTime = [int]$finalAuthoritySnapshot.metadata.previewTime
                otherMetadataFieldsEqual = $metadataOtherFieldsEqual
                notesTimingLocksAndKeyCountEqual =
                    $raceStructureBeforeJson -ceq $raceStructureAfterJson
                ownerFinalStatus = [string]$ownerFinalStatus.Current.Name
                memberFinalStatus = [string]$memberFinalStatus.Current.Name
                ownerMemberUiConverged =
                    (Get-ElementValue $ownerTitle) -ceq $localPendingTitle -and
                    (Get-ElementValue $ownerArtist) -ceq $ownerRemoteArtist -and
                    (Get-ElementValue $ownerPreviewTime) -ceq
                        ([string]$chosenPreviewTime) -and
                    (Get-ElementValue $memberTitle) -ceq $localPendingTitle -and
                    (Get-ElementValue $memberArtist) -ceq $ownerRemoteArtist -and
                    (Get-ElementValue $memberPreviewTime) -ceq
                        ([string]$chosenPreviewTime)
            }
            $metadataPreviewRaceEvidence["passed"] =
                $metadataPreviewRaceEvidence.initialRole -ceq "editor" -and
                -not $metadataPreviewRaceEvidence.initialCanEditMetadata -and
                $metadataPreviewRaceEvidence.grantMessage -ceq
                    $expectedMetadataGrantMessage -and
                $metadataPreviewRaceEvidence.dirtyMergeStatus -ceq
                    "远端谱面信息已同步；未应用的本地输入已保留" -and
                $metadataPreviewRaceEvidence.previewChanged -and
                $metadataPreviewRaceEvidence.titlePreservedAfterPreviewHere -and
                $metadataPreviewRaceEvidence.artistPreservedAfterPreviewHere -and
                $metadataPreviewRaceEvidence.revokeMessage -ceq
                    $expectedMetadataRevokeMessage -and
                $metadataPreviewRaceEvidence.disabledAttemptOperationCountBefore -eq
                    $metadataPreviewRaceEvidence.disabledAttemptOperationCountAfter -and
                $metadataPreviewRaceEvidence.disabledAttemptChartEqual -and
                $metadataPreviewRaceEvidence.restoreMessage -ceq
                    $expectedMetadataGrantMessage -and
                $metadataPreviewRaceEvidence.acceptedOperationCountAfter -eq
                    $metadataPreviewRaceEvidence.acceptedOperationCountBefore + 3 -and
                $metadataPreviewRaceEvidence.revisionAfter -eq
                    $metadataPreviewRaceEvidence.revisionBefore + 3 -and
                @($metadataPreviewRaceEvidence.acceptedMetadataOperations).Count -eq 3 -and
                [long]$metadataPreviewRaceEvidence.acceptedMetadataOperations[0].actorUserId -eq 4101 -and
                [long]$metadataPreviewRaceEvidence.acceptedMetadataOperations[1].actorUserId -eq 4202 -and
                [long]$metadataPreviewRaceEvidence.acceptedMetadataOperations[2].actorUserId -eq 4202 -and
                $metadataPreviewRaceEvidence.finalTitle -ceq $localPendingTitle -and
                $metadataPreviewRaceEvidence.finalArtist -ceq $ownerRemoteArtist -and
                $metadataPreviewRaceEvidence.finalPreviewTime -eq $chosenPreviewTime -and
                $metadataPreviewRaceEvidence.otherMetadataFieldsEqual -and
                $metadataPreviewRaceEvidence.notesTimingLocksAndKeyCountEqual -and
                $metadataPreviewRaceEvidence.ownerFinalStatus -like
                    "*revision $raceFinalRevision*" -and
                $metadataPreviewRaceEvidence.memberFinalStatus -like
                    "*revision $raceFinalRevision*" -and
                $metadataPreviewRaceEvidence.ownerMemberUiConverged
            if (-not $metadataPreviewRaceEvidence.passed) {
                $metadataPreviewRaceEvidence | ConvertTo-Json -Depth 20 |
                    Set-Content -LiteralPath (Join-Path $outputFullPath `
                        "metadata-preview-race-gate-diagnostic.json") `
                        -Encoding utf8NoBOM
                throw "Metadata/Preview dirty-draft race evidence gates were incomplete."
            }
        }

        if ($PermissionActionOnly -or $PermissionVariableTempoOnly) {
            $variablePermissionAction = [bool]$PermissionVariableTempoOnly
            $memberCommunityClose = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineCommunity.Navigation.Close" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $memberCommunityClose $memberHandle
            Wait-Condition -Description "member community closes before permission-action test" `
                -Seconds 15 -Condition {
                try {
                    [void](Find-ElementById -ProcessId $member.Process.Id `
                        -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 300)
                    return $false
                }
                catch { return $true }
            }
            $physicalActions.Add("member-return-to-editor-before-permission-action")

            $actionStateBefore = Get-HarnessState $endpoint
            $actionMemberBefore = @($actionStateBefore.members |
                Where-Object { [long]$_.userId -eq 4202 })[0]
            if ([string]$actionMemberBefore.memberRole -cne "editor" -or
                [bool]$actionMemberBefore.canEditMetadata -or
                [bool]$actionMemberBefore.canEditTiming -or
                -not [bool]$actionMemberBefore.canEditNotes) {
                throw "Permission-action member did not start with editor M:false/T:false/N:true access."
            }
            $actionOperationCountBefore = [int]$actionStateBefore.acceptedOperationCount
            $actionChartBefore = Get-ChartSnapshot $endpoint $member.Token
            $actionChartBeforeJson = $actionChartBefore | ConvertTo-Json -Depth 40 -Compress

            $ownerManageMember = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.4202.Manage" -TimeoutMilliseconds 20000
            Invoke-PhysicalElementClick $ownerManageMember $ownerHandle
            $physicalActions.Add("owner-open-member-access-for-analysis")
            $ownerMetadataPermission = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Metadata" -TimeoutMilliseconds 10000
            $ownerTimingPermission = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Timing" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerMetadataPermission $ownerHandle
            $physicalActions.Add("owner-enable-member-metadata-permission")
            Invoke-PhysicalElementClick $ownerTimingPermission $ownerHandle
            $physicalActions.Add("owner-enable-member-timing-permission")
            $ownerSaveAccess = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Save" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerSaveAccess $ownerHandle
            $physicalActions.Add("owner-save-member-analysis-permissions")
            $analysisAllowedState = Wait-HarnessState $endpoint {
                param($state)
                $candidate = @($state.members | Where-Object { [long]$_.userId -eq 4202 })[0]
                $candidate -and [string]$candidate.memberRole -ceq "editor" -and
                    [bool]$candidate.canEditMetadata -and
                    [bool]$candidate.canEditTiming -and
                    [bool]$candidate.canEditNotes
            } "member Metadata and Timing permission grant"

            $grantTitle = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Title" -TimeoutMilliseconds 30000
            $grantMessage = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Message" -TimeoutMilliseconds 10000
            $grantDismiss = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Dismiss" -TimeoutMilliseconds 10000
            if ([string]$grantTitle.Current.Name -cne "房间权限已更新" -or
                [string]$grantMessage.Current.Name -cne
                    "谱面信息：允许编辑`nEffect / Timing Edit：允许编辑`nNote：允许编辑") {
                throw "Analysis permission-grant notice did not match WPF 1.1.0."
            }
            Invoke-PhysicalElementClick $grantDismiss $memberHandle
            $physicalActions.Add("member-dismiss-analysis-permission-grant")

            $memberMetadataTab = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Inspector.MetadataTab" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $memberMetadataTab $memberHandle
            $physicalActions.Add("member-open-metadata-for-tempo-analysis")
            $analysisButtonId = if ($variablePermissionAction) {
                "Metadata.AnalyzeVariableTempo"
            } else {
                "Metadata.AnalyzeSingleTempo"
            }
            $memberAnalyzeTempo = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId $analysisButtonId -TimeoutMilliseconds 10000
            if (-not $memberAnalyzeTempo.Current.IsEnabled) {
                throw "$(if ($variablePermissionAction) { 'Variable' } else { 'Single' }) BPM analysis remained disabled after Metadata and Timing permission grant."
            }
            $captures.memberAnalysisReady = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-tempo-analysis-ready.png")
            Invoke-PhysicalElementClick $memberAnalyzeTempo $memberHandle
            $physicalActions.Add($(if ($variablePermissionAction) {
                "member-start-variable-tempo-analysis"
            } else {
                "member-start-single-tempo-analysis"
            }))

            $resultDialogId = if ($variablePermissionAction) {
                "Tempo.VariableResultDialog"
            } else {
                "Tempo.SingleResultDialog"
            }
            $resultMessageId = if ($variablePermissionAction) {
                "Tempo.VariablePreview"
            } else {
                "Tempo.SingleResult"
            }
            $resultDialog = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId $resultDialogId -TimeoutMilliseconds 180000
            $resultMessage = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId $resultMessageId -TimeoutMilliseconds 10000
            $resultHandle = [IntPtr]$resultDialog.Current.NativeWindowHandle
            if ($resultHandle -eq [IntPtr]::Zero) {
                throw "$(if ($variablePermissionAction) { 'Variable' } else { 'Single' }) BPM result dialog did not expose a native window handle."
            }
            $analysisResultText = [string]$resultMessage.Current.Name
            $resultCaptureKey = if ($variablePermissionAction) {
                "memberVariableTempoResultBeforeRevoke"
            } else {
                "memberSingleTempoResultBeforeRevoke"
            }
            $resultCaptureFile = if ($variablePermissionAction) {
                "member-variable-tempo-result-before-permission-revoke.png"
            } else {
                "member-single-tempo-result-before-permission-revoke.png"
            }
            $captures[$resultCaptureKey] = Capture-Window `
                $resultHandle `
                (Join-Path $outputFullPath $resultCaptureFile)

            $ownerManageMember = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.4202.Manage" -TimeoutMilliseconds 20000
            Invoke-PhysicalElementClick $ownerManageMember $ownerHandle
            $physicalActions.Add("owner-reopen-member-access-during-analysis-result")
            $ownerTimingPermission = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Timing" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerTimingPermission $ownerHandle
            $physicalActions.Add("owner-revoke-member-timing-during-analysis-result")
            $ownerSaveAccess = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Save" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerSaveAccess $ownerHandle
            $physicalActions.Add("owner-save-member-timing-revocation")
            $timingDeniedState = Wait-HarnessState $endpoint {
                param($state)
                $candidate = @($state.members | Where-Object { [long]$_.userId -eq 4202 })[0]
                $candidate -and [string]$candidate.memberRole -ceq "editor" -and
                    [bool]$candidate.canEditMetadata -and
                    -not [bool]$candidate.canEditTiming -and
                    [bool]$candidate.canEditNotes
            } "member Timing permission revocation during analysis result"

            $permissionUpdateTitle = Wait-ElementName -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Title" `
                -Like "房间权限已更新" -Seconds 30
            $permissionUpdateMessage = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Message" -TimeoutMilliseconds 10000
            if ([string]$permissionUpdateMessage.Current.Name -cne
                "谱面信息：允许编辑`nEffect / Timing Edit：不可编辑`nNote：允许编辑") {
                throw "Timing revocation notice during analysis did not match WPF 1.1.0."
            }
            $permissionUpdateMessageText = [string]$permissionUpdateMessage.Current.Name

            $resultApplyId = if ($variablePermissionAction) {
                "Tempo.VariableApply"
            } else {
                "Tempo.SingleApply"
            }
            $resultApply = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId $resultApplyId -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $resultApply $resultHandle
            $physicalActions.Add($(if ($variablePermissionAction) {
                "member-confirm-variable-tempo-after-timing-revocation"
            } else {
                "member-confirm-single-tempo-after-timing-revocation"
            }))

            $lateDeniedTitle = Wait-ElementName -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Title" `
                -Like "没有 Effect 权限" -Seconds 30
            $lateDeniedMessage = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Message" -TimeoutMilliseconds 10000
            $lateDeniedDismiss = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Dismiss" -TimeoutMilliseconds 10000
            $expectedLateDeniedMessage = if ($variablePermissionAction) {
                "分析期间 Timing 权限已失效，预测结果未写入。"
            } else {
                "分析期间 Timing 权限已失效，检测结果未写入。"
            }
            if ([string]$lateDeniedMessage.Current.Name -cne
                $expectedLateDeniedMessage) {
                throw "Late $(if ($variablePermissionAction) { 'variable' } else { 'single' })-tempo permission notice did not match WPF 1.1.0."
            }
            $lateDeniedTitleText = [string]$lateDeniedTitle.Current.Name
            $lateDeniedMessageText = [string]$lateDeniedMessage.Current.Name
            $lateDeniedCaptureFile = if ($variablePermissionAction) {
                "member-late-variable-tempo-permission-denied.png"
            } else {
                "member-late-tempo-permission-denied.png"
            }
            $captures.memberLateTempoPermissionDenied = Capture-Window $memberHandle `
                (Join-Path $outputFullPath $lateDeniedCaptureFile)
            Invoke-PhysicalElementClick $lateDeniedDismiss $memberHandle
            $physicalActions.Add("member-dismiss-late-tempo-permission-denied")

            $actionStateAfter = Get-HarnessState $endpoint
            $actionChartAfter = Get-ChartSnapshot $endpoint $member.Token
            $actionChartAfterJson = $actionChartAfter | ConvertTo-Json -Depth 40 -Compress
            $permissionActionEvidence = [ordered]@{
                analysisKind = if ($variablePermissionAction) { "variable" } else { "single" }
                initialRole = [string]$actionMemberBefore.memberRole
                analysisPermissionGrantMessage =
                    "谱面信息：允许编辑`nEffect / Timing Edit：允许编辑`nNote：允许编辑"
                analysisResult = $analysisResultText
                timingRevocationMessage = $permissionUpdateMessageText
                lateDeniedTitle = $lateDeniedTitleText
                lateDeniedMessage = $lateDeniedMessageText
                finalRole = [string](@($actionStateAfter.members |
                    Where-Object { [long]$_.userId -eq 4202 })[0]).memberRole
                finalCanEditMetadata = [bool](@($actionStateAfter.members |
                    Where-Object { [long]$_.userId -eq 4202 })[0]).canEditMetadata
                finalCanEditTiming = [bool](@($actionStateAfter.members |
                    Where-Object { [long]$_.userId -eq 4202 })[0]).canEditTiming
                finalCanEditNotes = [bool](@($actionStateAfter.members |
                    Where-Object { [long]$_.userId -eq 4202 })[0]).canEditNotes
                acceptedOperationCountBefore = $actionOperationCountBefore
                acceptedOperationCountAfter = [int]$actionStateAfter.acceptedOperationCount
                serverChartEqualBeforeAfter = $actionChartBeforeJson -ceq $actionChartAfterJson
            }
            $permissionActionEvidence.passed =
                $permissionActionEvidence.initialRole -ceq "editor" -and
                $permissionActionEvidence.analysisKind -ceq
                    $(if ($variablePermissionAction) { "variable" } else { "single" }) -and
                $permissionActionEvidence.analysisResult -like "*BPM*" -and
                $permissionActionEvidence.timingRevocationMessage -ceq
                    "谱面信息：允许编辑`nEffect / Timing Edit：不可编辑`nNote：允许编辑" -and
                $permissionActionEvidence.lateDeniedTitle -ceq "没有 Effect 权限" -and
                $permissionActionEvidence.lateDeniedMessage -ceq
                    $expectedLateDeniedMessage -and
                $permissionActionEvidence.finalRole -ceq "editor" -and
                $permissionActionEvidence.finalCanEditMetadata -and
                -not $permissionActionEvidence.finalCanEditTiming -and
                $permissionActionEvidence.finalCanEditNotes -and
                $permissionActionEvidence.acceptedOperationCountBefore -eq
                    $permissionActionEvidence.acceptedOperationCountAfter -and
                $permissionActionEvidence.serverChartEqualBeforeAfter
            if (-not $permissionActionEvidence.passed) {
                throw "Editor permission-action evidence gates were incomplete."
            }
        }

        if ($PermissionChangeOnly) {
            $memberCommunityClose = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineCommunity.Navigation.Close" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $memberCommunityClose $memberHandle
            Wait-Condition -Description "member community closes before access changes" `
                -Seconds 15 -Condition {
                try {
                    [void](Find-ElementById -ProcessId $member.Process.Id `
                        -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 300)
                    return $false
                }
                catch { return $true }
            }
            $physicalActions.Add("member-return-to-editor-before-access-changes")
            $initialAccessNoticeSuppressed = $false
            try {
                [void](Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "OnlineRoom.PermissionNotice" -TimeoutMilliseconds 800)
            }
            catch {
                $initialAccessNoticeSuppressed = $true
            }
            if (-not $initialAccessNoticeSuppressed) {
                throw "Initial room binding incorrectly displayed an access-change notice."
            }

            $accessStateBefore = Get-HarnessState $endpoint
            $accessMemberBefore = @($accessStateBefore.members |
                Where-Object { [long]$_.userId -eq 4202 })[0]
            if ([string]$accessMemberBefore.memberRole -cne "editor" -or
                [bool]$accessMemberBefore.canEditMetadata -or
                [bool]$accessMemberBefore.canEditTiming -or
                -not [bool]$accessMemberBefore.canEditNotes) {
                throw "Invited member did not start with the server's editor default M:false/T:false/N:true access."
            }
            $accessOperationCountBefore = [int]$accessStateBefore.acceptedOperationCount
            $accessChartBefore = Get-ChartSnapshot $endpoint $member.Token
            $accessChartBeforeJson = $accessChartBefore | ConvertTo-Json -Depth 40 -Compress

            $ownerManageMember = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.4202.Manage" -TimeoutMilliseconds 20000
            Invoke-PhysicalElementClick $ownerManageMember $ownerHandle
            $physicalActions.Add("owner-open-member-access-management")
            $ownerNotesPermission = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Notes" -TimeoutMilliseconds 10000
            $captures.ownerMemberAccessBefore = Capture-Window $ownerHandle `
                (Join-Path $outputFullPath "owner-member-access-before.png")
            Invoke-PhysicalElementClick $ownerNotesPermission $ownerHandle
            $physicalActions.Add("owner-disable-member-note-permission")
            $ownerSaveAccess = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Save" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerSaveAccess $ownerHandle
            $physicalActions.Add("owner-save-member-note-permission")
            $notesDeniedState = Wait-HarnessState $endpoint {
                param($state)
                $candidate = @($state.members | Where-Object { [long]$_.userId -eq 4202 })[0]
                $candidate -and [string]$candidate.memberRole -ceq "editor" -and
                    -not [bool]$candidate.canEditMetadata -and
                    -not [bool]$candidate.canEditTiming -and
                    -not [bool]$candidate.canEditNotes
            } "member Note permission update"

            $permissionUpdateTitle = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Title" -TimeoutMilliseconds 30000
            $permissionUpdateMessage = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Message" -TimeoutMilliseconds 10000
            $permissionUpdateDismiss = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Dismiss" -TimeoutMilliseconds 10000
            if ([string]$permissionUpdateTitle.Current.Name -cne "房间权限已更新" -or
                [string]$permissionUpdateMessage.Current.Name -cne
                    "谱面信息：不可编辑`nEffect / Timing Edit：不可编辑`nNote：不可编辑") {
                throw "Dynamic Note permission notice did not match WPF 1.1.0."
            }
            $permissionUpdateTitleText = [string]$permissionUpdateTitle.Current.Name
            $permissionUpdateMessageText = [string]$permissionUpdateMessage.Current.Name
            $memberTapAfterNoteDenied = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.QuickTool.Tap" -TimeoutMilliseconds 10000
            if ($memberTapAfterNoteDenied.Current.IsEnabled) {
                throw "Member Tap tool remained enabled after Note permission was removed."
            }
            $noteToolDisabledAfterPermissionUpdate =
                -not [bool]$memberTapAfterNoteDenied.Current.IsEnabled
            $captures.memberNotePermissionUpdated = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-note-permission-updated.png")
            Invoke-PhysicalElementClick $permissionUpdateDismiss $memberHandle
            $physicalActions.Add("member-dismiss-note-permission-update")

            $ownerManageMember = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.4202.Manage" -TimeoutMilliseconds 20000
            Invoke-PhysicalElementClick $ownerManageMember $ownerHandle
            $physicalActions.Add("owner-reopen-member-access-management")
            $ownerRole = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Role" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerRole $ownerHandle
            $physicalActions.Add("owner-open-member-role-selector")
            $viewerRoleItem = Find-ElementByName -ProcessId $owner.Process.Id `
                -Name "观察者" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $viewerRoleItem $ownerHandle
            $physicalActions.Add("owner-select-viewer-role")
            $ownerSaveAccess = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Save" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerSaveAccess $ownerHandle
            $physicalActions.Add("owner-save-viewer-role")
            $viewerState = Wait-HarnessState $endpoint {
                param($state)
                $candidate = @($state.members | Where-Object { [long]$_.userId -eq 4202 })[0]
                $candidate -and [string]$candidate.memberRole -ceq "viewer" -and
                    -not [bool]$candidate.canEditMetadata -and
                    -not [bool]$candidate.canEditTiming -and
                    -not [bool]$candidate.canEditNotes
            } "member viewer role update"

            $roleUpdateTitle = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Title" -TimeoutMilliseconds 30000
            $roleUpdateMessage = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Message" -TimeoutMilliseconds 10000
            $roleUpdateDismiss = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Dismiss" -TimeoutMilliseconds 10000
            if ([string]$roleUpdateTitle.Current.Name -cne "房间身份已修改" -or
                [string]$roleUpdateMessage.Current.Name -cne
                    "你的身份已被修改为观察者。`n`n观察者只能浏览、播放与选择，不能修改谱面。") {
                throw "Dynamic viewer-role notice did not match WPF 1.1.0."
            }
            $roleUpdateTitleText = [string]$roleUpdateTitle.Current.Name
            $roleUpdateMessageText = [string]$roleUpdateMessage.Current.Name
            $memberSelectAfterViewer = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.QuickTool.Select" -TimeoutMilliseconds 10000
            $memberTapAfterViewer = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.QuickTool.Tap" -TimeoutMilliseconds 10000
            if (-not $memberSelectAfterViewer.Current.IsEnabled -or
                $memberTapAfterViewer.Current.IsEnabled) {
                throw "Viewer tool availability did not match WPF read-only behavior."
            }
            $selectToolEnabledAsViewer =
                [bool]$memberSelectAfterViewer.Current.IsEnabled
            $tapToolDisabledAsViewer =
                -not [bool]$memberTapAfterViewer.Current.IsEnabled
            $captures.memberRoleChangedToViewer = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-role-changed-to-viewer.png")
            Invoke-PhysicalElementClick $roleUpdateDismiss $memberHandle
            $physicalActions.Add("member-dismiss-viewer-role-update")

            $viewerAccessState = Get-HarnessState $endpoint
            $viewerChart = Get-ChartSnapshot $endpoint $member.Token
            $viewerChartJson = $viewerChart | ConvertTo-Json -Depth 40 -Compress
            if ([int]$viewerAccessState.acceptedOperationCount -ne $accessOperationCountBefore -or
                $viewerChartJson -cne $accessChartBeforeJson) {
                throw "Removing permissions or switching to viewer mutated the chart."
            }

            $ownerManageMember = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.4202.Manage" -TimeoutMilliseconds 20000
            Invoke-PhysicalElementClick $ownerManageMember $ownerHandle
            $physicalActions.Add("owner-reopen-viewer-access-management")
            $ownerRole = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Role" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerRole $ownerHandle
            $physicalActions.Add("owner-open-viewer-role-selector")
            $editorRoleItem = Find-ElementByName -ProcessId $owner.Process.Id `
                -Name "编辑者" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $editorRoleItem $ownerHandle
            $physicalActions.Add("owner-select-editor-role")
            foreach ($permissionToggle in @(
                    [ordered]@{
                        id = "OnlineRooms.Member.Metadata"
                        action = "owner-enable-editor-metadata-permission"
                    },
                    [ordered]@{
                        id = "OnlineRooms.Member.Timing"
                        action = "owner-enable-editor-timing-permission"
                    },
                    [ordered]@{
                        id = "OnlineRooms.Member.Notes"
                        action = "owner-enable-editor-note-permission"
                    })) {
                $toggle = Find-ElementById -ProcessId $owner.Process.Id `
                    -AutomationId ([string]$permissionToggle.id) -TimeoutMilliseconds 10000
                Invoke-PhysicalElementClick $toggle $ownerHandle
                $physicalActions.Add([string]$permissionToggle.action)
            }
            $captures.ownerMemberAccessRestored = Capture-Window $ownerHandle `
                (Join-Path $outputFullPath "owner-member-access-restored.png")
            $ownerSaveAccess = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Save" -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerSaveAccess $ownerHandle
            $physicalActions.Add("owner-save-editor-role-and-all-permissions")
            $restoredEditorState = Wait-HarnessState $endpoint {
                param($state)
                $candidate = @($state.members |
                    Where-Object { [long]$_.userId -eq 4202 })[0]
                $candidate -and [string]$candidate.memberRole -ceq "editor" -and
                    [bool]$candidate.canEditMetadata -and
                    [bool]$candidate.canEditTiming -and
                    [bool]$candidate.canEditNotes
            } "member viewer-to-editor role and permission restore"

            $restoredRoleTitle = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Title" -TimeoutMilliseconds 30000
            $restoredRoleMessage = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Message" -TimeoutMilliseconds 10000
            $restoredRoleDismiss = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Dismiss" -TimeoutMilliseconds 10000
            $expectedRestoredRoleMessage =
                "你的身份已被修改为编辑者。`n`n" +
                "谱面信息：允许编辑`n" +
                "Effect / Timing Edit：允许编辑`n" +
                "Note：允许编辑"
            if ([string]$restoredRoleTitle.Current.Name -cne "房间身份已修改" -or
                [string]$restoredRoleMessage.Current.Name -cne $expectedRestoredRoleMessage) {
                throw "Dynamic editor-role restore notice did not match WPF 1.1.0."
            }
            $restoredRoleTitleText = [string]$restoredRoleTitle.Current.Name
            $restoredRoleMessageText = [string]$restoredRoleMessage.Current.Name
            $memberSelectAfterRestore = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.QuickTool.Select" -TimeoutMilliseconds 10000
            $memberTapAfterRestore = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.QuickTool.Tap" -TimeoutMilliseconds 10000
            $memberHoldAfterRestore = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.QuickTool.Hold" -TimeoutMilliseconds 10000
            $memberEraseAfterRestore = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.QuickTool.Erase" -TimeoutMilliseconds 10000
            if (-not $memberSelectAfterRestore.Current.IsEnabled -or
                -not $memberTapAfterRestore.Current.IsEnabled -or
                -not $memberHoldAfterRestore.Current.IsEnabled -or
                -not $memberEraseAfterRestore.Current.IsEnabled) {
                throw "Editor tools did not become enabled after viewer-to-editor restore."
            }
            $selectToolEnabledAsEditor = [bool]$memberSelectAfterRestore.Current.IsEnabled
            $tapToolEnabledAsEditor = [bool]$memberTapAfterRestore.Current.IsEnabled
            $holdToolEnabledAsEditor = [bool]$memberHoldAfterRestore.Current.IsEnabled
            $eraseToolEnabledAsEditor = [bool]$memberEraseAfterRestore.Current.IsEnabled
            $captures.memberRoleChangedToEditor = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-role-changed-to-editor.png")
            Invoke-PhysicalElementClick $restoredRoleDismiss $memberHandle
            $physicalActions.Add("member-dismiss-editor-role-restore")

            $chartBeforeRestoredEdit = Get-ChartSnapshot $endpoint $member.Token
            $knownRestoredNoteIds = @{}
            foreach ($note in @($chartBeforeRestoredEdit.notes)) {
                $knownRestoredNoteIds[[string]$note.id] = $true
            }
            $ownerLiveBeforeRestoredEdit = Get-TimelineLiveState $owner.Process.Id
            $memberLiveBeforeRestoredEdit = Get-TimelineLiveState $member.Process.Id
            $restoredPlacement = Find-FreeTimelineTapPlacement `
                -Notes @($chartBeforeRestoredEdit.notes) `
                -CurrentBeat ([double]$memberLiveBeforeRestoredEdit.currentBeat) `
                -PreferredLanes @(0, 1, 2, 3) `
                -Offsets @(.5, .75, 1, 1.25, 1.5, -.5, -.75, -1) `
                -MinimumClearanceBeats .24
            Invoke-PhysicalElementClick $memberTapAfterRestore $memberHandle
            $physicalActions.Add("member-select-tap-after-editor-restore")
            $restoredPlacementPoint = Get-TimelinePoint `
                $memberRoomRuntime `
                ([int]$restoredPlacement.lane) `
                ([double]$restoredPlacement.offset) `
                $member.Process.Id `
                ([double]$memberLiveBeforeRestoredEdit.pixelsPerBeat)
            Invoke-PhysicalClick `
                ([int]$restoredPlacementPoint.x) `
                ([int]$restoredPlacementPoint.y) `
                $memberHandle
            $physicalActions.Add("member-place-tap-after-editor-restore")

            $restoredEditState = Wait-HarnessState $endpoint {
                param($state)
                [int]$state.acceptedOperationCount -eq $accessOperationCountBefore + 1
            } "restored editor submits exactly one Note operation"
            $chartAfterRestoredEdit = Get-ChartSnapshot $endpoint $member.Token
            $restoredNewNotes = @($chartAfterRestoredEdit.notes | Where-Object {
                    -not $knownRestoredNoteIds.ContainsKey([string]$_.id)
                })
            if ($restoredNewNotes.Count -ne 1 -or
                [long]$restoredNewNotes[0].creatorUserId -ne 4202) {
                throw "Restored editor did not create exactly one attributed Note."
            }
            $chartBeforeOther = [ordered]@{}
            foreach ($property in $chartBeforeRestoredEdit.PSObject.Properties) {
                if ($property.Name -cne "notes" -and
                    $property.Name -cne "noteCount" -and
                    $property.Name -cne "revision") {
                    $chartBeforeOther[$property.Name] = $property.Value
                }
            }
            $chartAfterOther = [ordered]@{}
            foreach ($property in $chartAfterRestoredEdit.PSObject.Properties) {
                if ($property.Name -cne "notes" -and
                    $property.Name -cne "noteCount" -and
                    $property.Name -cne "revision") {
                    $chartAfterOther[$property.Name] = $property.Value
                }
            }
            $existingNotesAfterRestoredEdit = @($chartAfterRestoredEdit.notes |
                Where-Object { $knownRestoredNoteIds.ContainsKey([string]$_.id) })
            $restoredExistingNotesEqual =
                $existingNotesAfterRestoredEdit.Count -eq
                    @($chartBeforeRestoredEdit.notes).Count
            $restoredNoteMismatches = [Collections.Generic.List[object]]::new()
            if ($restoredExistingNotesEqual) {
                $existingNotesById = @{}
                foreach ($note in $existingNotesAfterRestoredEdit) {
                    $existingNotesById[[string]$note.id] = $note
                }
                foreach ($note in @($chartBeforeRestoredEdit.notes)) {
                    $noteId = [string]$note.id
                    $beforeIdentity = Get-OnlineNoteIdentityJson $note
                    $afterIdentity = if ($existingNotesById.ContainsKey($noteId)) {
                        Get-OnlineNoteIdentityJson $existingNotesById[$noteId]
                    } else {
                        $null
                    }
                    if ($beforeIdentity -cne $afterIdentity) {
                        if ($restoredNoteMismatches.Count -lt 10) {
                            $restoredNoteMismatches.Add([ordered]@{
                                id = $noteId
                                before = $beforeIdentity
                                after = $afterIdentity
                            })
                        }
                        $restoredExistingNotesEqual = $false
                    }
                }
            }
            $chartBeforeOtherJson =
                $chartBeforeOther | ConvertTo-Json -Depth 40 -Compress
            $chartAfterOtherJson =
                $chartAfterOther | ConvertTo-Json -Depth 40 -Compress
            $restoredEditOnlyAddedOneNote =
                $restoredExistingNotesEqual -and
                ($chartBeforeOtherJson -ceq $chartAfterOtherJson) -and
                @($chartAfterRestoredEdit.notes).Count -eq
                    @($chartBeforeRestoredEdit.notes).Count + 1 -and
                [int]$chartAfterRestoredEdit.revision -eq
                    [int]$chartBeforeRestoredEdit.revision + 1
            if (-not $restoredEditOnlyAddedOneNote) {
                $comparisonDiagnostic = [ordered]@{
                    schema =
                        "lumachart.windows.avalonia.role-restore-chart-comparison-diagnostic.v1"
                    beforeNoteCount = @($chartBeforeRestoredEdit.notes).Count
                    afterNoteCount = @($chartAfterRestoredEdit.notes).Count
                    beforeRevision = [int]$chartBeforeRestoredEdit.revision
                    afterRevision = [int]$chartAfterRestoredEdit.revision
                    knownNoteCount = $knownRestoredNoteIds.Count
                    existingNoteCountAfter = $existingNotesAfterRestoredEdit.Count
                    newNoteCount = $restoredNewNotes.Count
                    existingNotesEqualById = $restoredExistingNotesEqual
                    otherFieldsEqual = $chartBeforeOtherJson -ceq $chartAfterOtherJson
                    beforeOther = $chartBeforeOtherJson
                    afterOther = $chartAfterOtherJson
                    mismatches = $restoredNoteMismatches.ToArray()
                }
                $comparisonDiagnostic | ConvertTo-Json -Depth 20 |
                    Set-Content -LiteralPath (Join-Path $outputFullPath `
                        "role-restore-chart-comparison-diagnostic.json") `
                        -Encoding utf8NoBOM
                throw "Restored editor operation changed content beyond one new Note; " +
                    "existingEqual=$restoredExistingNotesEqual; " +
                    "otherEqual=$($chartBeforeOtherJson -ceq $chartAfterOtherJson); " +
                    "mismatches=$($restoredNoteMismatches.Count)."
            }

            $targetRevision = [int]$restoredEditState.revision
            [void](Wait-ElementName -ProcessId $owner.Process.Id `
                -AutomationId "Editor.Status" -Like "*revision $targetRevision*" -Seconds 30)
            [void](Wait-ElementName -ProcessId $member.Process.Id `
                -AutomationId "Editor.Status" -Like "*revision $targetRevision*" -Seconds 30)
            $script:ownerRestoredLiveResult = $null
            $script:memberRestoredLiveResult = $null
            Wait-Condition -Description "restored editor Note converges to both timelines" `
                -Seconds 30 -Condition {
                $ownerLive = Get-TimelineLiveState $owner.Process.Id
                $memberLive = Get-TimelineLiveState $member.Process.Id
                if ([int]$ownerLive.creatorAttributedNoteCount -eq
                        [int]$ownerLiveBeforeRestoredEdit.creatorAttributedNoteCount + 1 -and
                    [int]$memberLive.creatorAttributedNoteCount -eq
                        [int]$memberLiveBeforeRestoredEdit.creatorAttributedNoteCount + 1) {
                    $script:ownerRestoredLiveResult = $ownerLive
                    $script:memberRestoredLiveResult = $memberLive
                    return $true
                }
                return $false
            }
            $ownerLiveAfterRestoredEdit = $script:ownerRestoredLiveResult
            $memberLiveAfterRestoredEdit = $script:memberRestoredLiveResult
            $script:ownerRestoredLiveResult = $null
            $script:memberRestoredLiveResult = $null
            $captures.memberEditorAfterRestore = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-editor-after-role-restore.png")
            $captures.ownerSeesRestoredMemberEdit = Capture-Window $ownerHandle `
                (Join-Path $outputFullPath "owner-sees-restored-member-edit.png")

            $accessStateAfter = Get-HarnessState $endpoint
            $permissionChangeEvidence = [ordered]@{
                initialBindingNoticeSuppressed = $initialAccessNoticeSuppressed
                initialRole = [string]$accessMemberBefore.memberRole
                permissionUpdateTitle = $permissionUpdateTitleText
                permissionUpdateMessage = $permissionUpdateMessageText
                noteToolDisabledAfterPermissionUpdate =
                    $noteToolDisabledAfterPermissionUpdate
                roleUpdateTitle = $roleUpdateTitleText
                roleUpdateMessage = $roleUpdateMessageText
                finalRole = [string](@($accessStateAfter.members |
                    Where-Object { [long]$_.userId -eq 4202 })[0]).memberRole
                selectToolEnabledAsViewer = $selectToolEnabledAsViewer
                tapToolDisabledAsViewer = $tapToolDisabledAsViewer
                viewerOperationCount = [int]$viewerAccessState.acceptedOperationCount
                viewerChartEqualToInitial = $viewerChartJson -ceq $accessChartBeforeJson
                restoredRoleTitle = $restoredRoleTitleText
                restoredRoleMessage = $restoredRoleMessageText
                restoredCanEditMetadata = [bool](@($restoredEditorState.members |
                    Where-Object { [long]$_.userId -eq 4202 })[0]).canEditMetadata
                restoredCanEditTiming = [bool](@($restoredEditorState.members |
                    Where-Object { [long]$_.userId -eq 4202 })[0]).canEditTiming
                restoredCanEditNotes = [bool](@($restoredEditorState.members |
                    Where-Object { [long]$_.userId -eq 4202 })[0]).canEditNotes
                selectToolEnabledAsEditor = $selectToolEnabledAsEditor
                tapToolEnabledAsEditor = $tapToolEnabledAsEditor
                holdToolEnabledAsEditor = $holdToolEnabledAsEditor
                eraseToolEnabledAsEditor = $eraseToolEnabledAsEditor
                restoredEditRevision = $targetRevision
                restoredEditBaseRevision = [int]$chartBeforeRestoredEdit.revision
                restoredEditNoteId = [string]$restoredNewNotes[0].id
                restoredEditNoteLane = [int]$restoredNewNotes[0].lane
                restoredEditNoteBeat = $restoredNewNotes[0].beat
                restoredEditCreatorUserId = [long]$restoredNewNotes[0].creatorUserId
                restoredEditOnlyAddedOneNote = $restoredEditOnlyAddedOneNote
                ownerCreatorAttributedNoteCountAfter =
                    [int]$ownerLiveAfterRestoredEdit.creatorAttributedNoteCount
                memberCreatorAttributedNoteCountAfter =
                    [int]$memberLiveAfterRestoredEdit.creatorAttributedNoteCount
                acceptedOperationCountBefore = $accessOperationCountBefore
                acceptedOperationCountAfter = [int]$accessStateAfter.acceptedOperationCount
                serverChartEqualBeforeViewer = $viewerChartJson -ceq $accessChartBeforeJson
            }
            $permissionChangeEvidence.passed =
                $permissionChangeEvidence.initialBindingNoticeSuppressed -and
                $permissionChangeEvidence.permissionUpdateTitle -ceq "房间权限已更新" -and
                $permissionChangeEvidence.permissionUpdateMessage -ceq
                    "谱面信息：不可编辑`nEffect / Timing Edit：不可编辑`nNote：不可编辑" -and
                $permissionChangeEvidence.noteToolDisabledAfterPermissionUpdate -and
                $permissionChangeEvidence.roleUpdateTitle -ceq "房间身份已修改" -and
                $permissionChangeEvidence.roleUpdateMessage -ceq
                    "你的身份已被修改为观察者。`n`n观察者只能浏览、播放与选择，不能修改谱面。" -and
                $permissionChangeEvidence.finalRole -ceq "editor" -and
                $permissionChangeEvidence.selectToolEnabledAsViewer -and
                $permissionChangeEvidence.tapToolDisabledAsViewer -and
                $permissionChangeEvidence.viewerOperationCount -eq
                    $permissionChangeEvidence.acceptedOperationCountBefore -and
                $permissionChangeEvidence.serverChartEqualBeforeViewer -and
                $permissionChangeEvidence.restoredRoleTitle -ceq "房间身份已修改" -and
                $permissionChangeEvidence.restoredRoleMessage -ceq
                    $expectedRestoredRoleMessage -and
                $permissionChangeEvidence.restoredCanEditMetadata -and
                $permissionChangeEvidence.restoredCanEditTiming -and
                $permissionChangeEvidence.restoredCanEditNotes -and
                $permissionChangeEvidence.selectToolEnabledAsEditor -and
                $permissionChangeEvidence.tapToolEnabledAsEditor -and
                $permissionChangeEvidence.holdToolEnabledAsEditor -and
                $permissionChangeEvidence.eraseToolEnabledAsEditor -and
                $permissionChangeEvidence.restoredEditCreatorUserId -eq 4202 -and
                $permissionChangeEvidence.restoredEditOnlyAddedOneNote -and
                $permissionChangeEvidence.restoredEditRevision -eq
                    $permissionChangeEvidence.restoredEditBaseRevision + 1 -and
                $permissionChangeEvidence.acceptedOperationCountAfter -eq
                    $permissionChangeEvidence.acceptedOperationCountBefore + 1
            if (-not $permissionChangeEvidence.passed) {
                $permissionChangeEvidence | ConvertTo-Json -Depth 20 |
                    Set-Content -LiteralPath (Join-Path $outputFullPath `
                        "permission-change-gate-diagnostic.json") `
                        -Encoding utf8NoBOM
                throw "Dynamic member access-change evidence gates were incomplete."
            }
        }

        $finalState = Get-HarnessState $endpoint
        $finalMemberState = @($finalState.members | Where-Object { [long]$_.userId -eq 4202 })[0]
        $screenshots = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
            $screenshots[$file.BaseName] = [ordered]@{
                path = $file.FullName
                length = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        if ($screenshots.Count -lt 8 -or [int]$finalState.memberNormalJoinRequestCount -ne 0 -or
            [int]$finalState.memberJoinPasswordSubmissionCount -ne 0 -or
            @($finalState.invitationResponseActions) -notcontains $invitationAction) {
            throw "Hidden invitation final evidence gates were incomplete."
        }
        if ($observerInvitation -and
            ([string]$finalMemberState.memberRole -cne "viewer" -or
             -not [bool]$observerReadOnlyEvidence.passed -or
             [int]$finalState.chatCount -ne 2)) {
            throw "Hidden observer final role, read-only, or chat gates were incomplete."
        }
        if ($PermissionChangeOnly -and
            ($null -eq $permissionChangeEvidence -or
             -not [bool]$permissionChangeEvidence.passed)) {
            throw "Dynamic room permission-change final gates were incomplete."
        }
        if (($PermissionActionOnly -or $PermissionVariableTempoOnly) -and
            ($null -eq $permissionActionEvidence -or
             -not [bool]$permissionActionEvidence.passed)) {
            throw "Editor permission-action final gates were incomplete."
        }
        if ($MetadataPreviewRaceOnly -and
            ($null -eq $metadataPreviewRaceEvidence -or
             -not [bool]$metadataPreviewRaceEvidence.passed)) {
            throw "Metadata/Preview dirty-draft race final gates were incomplete."
        }

        $evidence = [ordered]@{
            schema = if ($PermissionVariableTempoOnly) {
                "lumachart.windows.avalonia.variable-tempo-permission-action-gui-evidence.v1"
            } elseif ($MetadataPreviewRaceOnly) {
                "lumachart.windows.avalonia.metadata-preview-race-gui-evidence.v1"
            } elseif ($PermissionActionOnly) {
                "lumachart.windows.avalonia.editor-permission-action-gui-evidence.v1"
            } elseif ($PermissionChangeOnly) {
                "lumachart.windows.avalonia.room-role-restore-gui-evidence.v1"
            } elseif ($observerInvitation) {
                "lumachart.windows.avalonia.hidden-private-observer-gui-evidence.v1"
            } else {
                "lumachart.windows.avalonia.hidden-private-invitation-gui-evidence.v1"
            }
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed"
            windowsAvaloniaOnly = $true
            productionServerMutationPerformed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            physicalMouseInputUsed = -not [bool]$AutomationDiagnostic
            automationDiagnosticNonFormal = [bool]$AutomationDiagnostic
            explicitButtonsUsedForChineseImeSafeSubmission = $true
            endpoint = $endpoint
            paths = [ordered]@{
                projectRoot = $projectRoot
                outputRoot = $outputFullPath
                application = $applicationFullPath
                serverAssembly = $serverAssemblyFullPath
                fixture = $fixtureFullPath
                memberMaterializedChart = $memberRoomChartPath
                temp = $projectTemp
                dotnetHome = $dotnetHome
                nugetPackages = $nugetPackages
                nugetHttpCache = $nugetHttpCache
            }
            hashes = [ordered]@{
                application = (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
                applicationAssembly = (Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($applicationFullPath, ".dll")) -Algorithm SHA256).Hash
                serverAssembly = (Get-FileHash -LiteralPath $serverAssemblyFullPath -Algorithm SHA256).Hash
                fixture = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
                memberMaterializedChart = (Get-FileHash -LiteralPath $memberRoomChartPath -Algorithm SHA256).Hash
            }
            processIds = [ordered]@{
                server = $server.Id
                owner = $owner.Process.Id
                member = $member.Process.Id
            }
            invitation = [ordered]@{
                roomPrivate = [bool]$finalState.room.isPrivate
                roomHidden = [bool]$finalState.room.isHidden
                action = $invitationAction
                expectedMemberRole = $invitationRole
                createCount = [int]$finalState.invitationCreateCount
                fetchCount = [int]$finalState.invitationFetchCount
                joinCount = [int]$finalState.invitationJoinCount
                responseActions = @($finalState.invitationResponseActions)
                pendingCount = [int]$finalState.pendingInvitationCount
                memberNormalJoinRequestCount = [int]$finalState.memberNormalJoinRequestCount
                memberJoinPasswordSubmissionCount = [int]$finalState.memberJoinPasswordSubmissionCount
                passwordBypassPassed = [int]$finalState.memberNormalJoinRequestCount -eq 0 -and
                    [int]$finalState.memberJoinPasswordSubmissionCount -eq 0
                memberUiAutomationSecretExposure = $memberUiSecretExposure
                passwordAbsentFromMemberUiAutomation = $memberUiSecretExposure.Count -eq 0
                wpfToastGeometry = $invitationGeometry
            }
            room = [ordered]@{
                finalServerState = $finalState
                memberRoomRuntime = $memberRoomRuntime
                memberMaterializedChartExists = Test-Path -LiteralPath $memberRoomChartPath -PathType Leaf
                memberRole = [string]$finalMemberState.memberRole
                memberEditorRole = if ($observerInvitation) { $null } else { [string]$finalMemberState.memberRole }
                activeMemberIds = @($finalState.activeMemberIds)
                chatCount = [int]$finalState.chatCount
                unreadRedDotAutomationName = [string]$observations.memberUnreadRoomNavigation.name
            }
            physicalActions = $physicalActions.ToArray()
            controls = $observations
            observerReadOnly = $observerReadOnlyEvidence
            permissionChanges = $permissionChangeEvidence
            permissionActions = $permissionActionEvidence
            metadataPreviewRace = $metadataPreviewRaceEvidence
            captures = $captures
            screenshots = $screenshots
        }
        $evidenceJson = $evidence | ConvertTo-Json -Depth 60
        if ($evidenceJson.Contains($testPassword, [StringComparison]::Ordinal)) {
            throw "Hidden room password leaked into formal evidence JSON."
        }
        if ($AutomationDiagnostic) {
            $evidence["status"] = "diagnostic-passed-nonformal"
        }
        $evidencePath = Join-Path $outputFullPath $(if ($AutomationDiagnostic) {
            "diagnostic-evidence.json"
        } else {
            "evidence.json"
        })
        $evidenceJson | Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
        Write-Output $(if ($PermissionVariableTempoOnly) {
            "Windows Avalonia variable-tempo permission-action GUI capture: passed"
        } elseif ($MetadataPreviewRaceOnly) {
            "Windows Avalonia Metadata/Preview dirty-draft race GUI capture: passed"
        } elseif ($PermissionActionOnly) {
            "Windows Avalonia editor permission-action GUI capture: passed"
        } elseif ($PermissionChangeOnly) {
            "Windows Avalonia viewer-to-editor role restore GUI capture: passed"
        } else {
            "Windows Avalonia hidden private $invitationRole invitation GUI capture: passed"
        })
        Write-Output "Evidence: $evidencePath"
        return
    }

    $ownerCommunity = Open-Community $owner
    Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineCommunity.Navigation.Rooms")
    $createName = Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineRooms.Create.Name" -TimeoutMilliseconds 30000
    $lockExisting = Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineRooms.Create.LockExistingNotes"
    $observations.ownerCreateLockExistingNotes = Observe-Element $lockExisting
    $ownerLobbyPath = Join-Path $outputFullPath "owner-room-create.png"
    $captures.ownerRoomCreate = Capture-Window $ownerHandle $ownerLobbyPath
    Set-ElementValue $createName "Windows Avalonia 双客户端真实 MC 房间"
    Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineRooms.Create.Submit")
    [void](Wait-ElementName -ProcessId $owner.Process.Id `
        -AutomationId "OnlineRooms.Create.Submit" `
        -Like "*创建并上传*" -Seconds 30)
    Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id `
        -AutomationId "OnlineRooms.Create.Submit")
    $afterCreate = Wait-HarnessState $endpoint {
        param($state)
        [bool]$state.roomCreated -and [bool]$state.room.resourcesReady -and
        [int]$state.resourceEntryCount -ge 3 -and [long]$state.revision -ge 1
    } "owner room resource upload and chart initialization"
    $ownerEditorPath = Join-Path $outputFullPath "owner-editor-bound.png"
    $captures.ownerEditor = Capture-Window $ownerHandle $ownerEditorPath

    if ($ResourceResilienceOnly) {
        [void](Set-HarnessFaults $endpoint @{
                failNextChartDeltaRequests = 0
                disconnectNextSseConnections = 0
                dropNextChartOperationResponsesAfterCommit = 0
                delayNextChartOperationResponseMilliseconds = 0
                delayNextResourceDownloadMilliseconds = 0
                disconnectNextResourceDownloads = 1
                corruptNextResourceDownloads = 1
            })
    }
    elseif ($ResourceRevisionOnly) {
        [void](Set-HarnessFaults $endpoint @{
                failNextChartDeltaRequests = 0
                malformedNextChartDeltaResponses = 0
                disconnectNextSseConnections = 0
                dropNextChartOperationResponsesAfterCommit = 0
                delayNextChartOperationResponseMilliseconds = 0
                delayNextResourceDownloadMilliseconds = 30000
                disconnectNextResourceDownloads = 0
                corruptNextResourceDownloads = 0
            })
    }
    elseif ($ResilienceOnly) {
        [void](Set-HarnessFaults $endpoint @{
                failNextChartDeltaRequests = 0
                disconnectNextSseConnections = 2
                dropNextChartOperationResponsesAfterCommit = 0
                delayNextChartOperationResponseMilliseconds = 0
            })
    }

    $memberCommunity = Open-Community $member
    Invoke-Element (Find-ElementById -ProcessId $member.Process.Id -AutomationId "OnlineCommunity.Navigation.Rooms")
    $memberRoomJoin = Find-ElementById -ProcessId $member.Process.Id `
        -AutomationId "OnlineRooms.Room.7654321.Join" -TimeoutMilliseconds 30000
    if ($ResourceRevisionOnly) {
        $resourceRevisionActions = [Collections.Generic.List[string]]::new()
        $memberCommunityHandle = [IntPtr]$memberCommunity.Current.NativeWindowHandle
        if ($memberCommunityHandle -eq [IntPtr]::Zero) {
            $memberCommunityHandle = $memberHandle
        }
        Invoke-PhysicalElementClick $memberRoomJoin $memberCommunityHandle
        $resourceRevisionActions.Add("member-click-room-join")
        $memberJoinSubmit = $null
        $memberJoinedDirectly = $false
        $joinPathDeadline = [DateTimeOffset]::UtcNow.AddSeconds(10)
        while ([DateTimeOffset]::UtcNow -lt $joinPathDeadline) {
            try {
                $memberJoinSubmit = Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "OnlineRooms.Join.Submit" -TimeoutMilliseconds 300
                break
            }
            catch {
                $joinPathState = Get-HarnessState $endpoint
                if (@($joinPathState.activeMemberIds) -contains 4202) {
                    $memberJoinedDirectly = $true
                    break
                }
            }
            Start-Sleep -Milliseconds 100
        }
        if ($memberJoinSubmit) {
            Invoke-PhysicalElementClick $memberJoinSubmit $memberCommunityHandle
            $resourceRevisionActions.Add("member-submit-room-join")
        }
        elseif (-not $memberJoinedDirectly) {
            throw "Member revision-window join exposed neither confirmation nor direct membership."
        }
        [void](Wait-HarnessState $endpoint {
                param($state)
                @($state.activeMemberIds) -contains 4202
            } "member joined before delayed resource transfer" 20)
        $memberResourceConfirmation = Wait-RoomResourceConfirmation `
            -ProcessId $member.Process.Id -Seconds 30
        Invoke-PhysicalElementClick $memberResourceConfirmation $memberCommunityHandle
        $resourceRevisionActions.Add("member-confirm-delayed-resource-download")

        $delayStarted = Wait-HarnessState $endpoint {
            param($state)
            $attempts = @($state.faults.resourceDownloadAttempts)
            [long]$state.revision -eq 1 -and
                [int]$state.faults.injectedDelayedResourceDownloadCount -eq 1 -and
                [int]$state.faults.pendingDelayedResourceDownloadMilliseconds -eq 0 -and
                $attempts.Count -ge 1 -and
                [int]$attempts[0].responseDelayMilliseconds -eq 30000
        } "delayed member resource response window" 20
        $delayedAttempt = @($delayStarted.faults.resourceDownloadAttempts)[0]
        $captures.memberResourceRevisionDelay = Capture-Window $memberCommunityHandle `
            (Join-Path $outputFullPath "member-resource-download-revision-delay.png")

        try { Close-Community $owner } catch { }
        $beforeOwnerPlacement = Get-ChartSnapshot $endpoint $owner.Token
        $ownerLiveForRevision = Get-TimelineLiveState $owner.Process.Id
        $ownerPlacement = Find-FreeTimelineTapPlacement `
            -Notes @($beforeOwnerPlacement.notes) `
            -CurrentBeat ([double]$ownerLiveForRevision.currentBeat) `
            -PreferredLanes @(3, 2, 1, 0) `
            -Offsets @(.5, .75, 1.0, 1.25, 1.5) `
            -MinimumClearanceBeats .20
        $ownerTapTool = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.QuickTool.Tap" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerTapTool $ownerHandle
        $resourceRevisionActions.Add("owner-select-tap-during-resource-download")
        $ownerPlacementPoint = Get-TimelinePoint `
            $ownerRuntime `
            ([int]$ownerPlacement.lane) `
            ([double]$ownerPlacement.offset) `
            $owner.Process.Id `
            ([double]$ownerLiveForRevision.pixelsPerBeat)
        Invoke-PhysicalClick $ownerPlacementPoint.x $ownerPlacementPoint.y $ownerHandle
        $resourceRevisionActions.Add("owner-place-note-during-resource-download")

        $afterOwnerRevision = Wait-HarnessState $endpoint {
            param($state)
            [long]$state.revision -eq 2 -and
                @($state.acceptedOperations | Where-Object {
                        [long]$_.actorUserId -eq 4101 -and [long]$_.revision -eq 2
                    }).Count -eq 1
        } "owner revision committed while member resource response remained delayed" 20
        $ownerAcceptedOperation = @(
            $afterOwnerRevision.acceptedOperations |
                Where-Object {
                    [long]$_.actorUserId -eq 4101 -and [long]$_.revision -eq 2
                })[0]
        $newOwnerNotes = @($ownerAcceptedOperation.upsertNotes)
        if ($newOwnerNotes.Count -ne 1 -or
            [int]$ownerAcceptedOperation.upsertNoteCount -ne 1) {
            throw "The delayed-resource owner edit did not create exactly one authoritative Note."
        }
        $ownerPlacedNote = $newOwnerNotes[0]
        $delayDeadline = ([DateTimeOffset]$delayedAttempt.receivedAt).AddMilliseconds(
            [int]$delayedAttempt.responseDelayMilliseconds)
        if ([DateTimeOffset]::UtcNow -ge $delayDeadline) {
            throw "The owner edit completed only after the injected resource delay window expired."
        }
        $captures.ownerRevisionDuringResourceDownload = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-revision-during-member-resource-download.png")

        $memberEditorTab = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab" -TimeoutMilliseconds 45000
        Wait-Condition -Description "member coordinator starts from latest post-download revision" `
            -Seconds 45 -Condition {
                try {
                    $live = Get-TimelineLiveState $member.Process.Id
                    return [long]$live.roomSyncRevision -eq 2 -and
                        [string]$live.roomSyncPendingOperationId -eq "none"
                }
                catch { return $false }
            }
        $memberLiveAfterRevision = Get-TimelineLiveState $member.Process.Id
        Wait-File $member.RoomRuntime "post-download revision member runtime evidence" 100
        $memberRoomRuntime =
            Get-Content -Raw -LiteralPath $member.RoomRuntime | ConvertFrom-Json
        if ([int]$memberRoomRuntime.chart.structure.noteCount -ne 2754) {
            throw "Member materialized chart did not include the owner Note committed during resource download."
        }

        try { Close-Community $member } catch { }
        $memberLiveAfterRevision = Get-TimelineLiveState $member.Process.Id
        $ownerPlacedBeatValue =
            [double]$ownerPlacedNote.beat.bar +
            [double]$ownerPlacedNote.beat.numerator /
            [double]$ownerPlacedNote.beat.denominator
        $memberCellBottomAnchorBeatOffset = [Math]::Min(
            .42 / [Math]::Max(1, [int]$memberLiveAfterRevision.snapDivision),
            (([double]$memberRoomRuntime.settings.noteHeight / 2) + 3) /
                [Math]::Max(1, [double]$memberLiveAfterRevision.pixelsPerBeat))
        $memberPlacedOffset =
            $ownerPlacedBeatValue +
            $memberCellBottomAnchorBeatOffset -
            [double]$memberLiveAfterRevision.currentBeat
        $memberPlacedPoint = Get-TimelinePoint `
            $memberRoomRuntime `
            ([int]$ownerPlacedNote.lane) `
            $memberPlacedOffset `
            $member.Process.Id `
            ([double]$memberLiveAfterRevision.pixelsPerBeat)
        $memberPlacedPoint.storedBeatValue = $ownerPlacedBeatValue
        $memberPlacedPoint.noteAnchor = "CellBottom"
        $memberPlacedPoint.noteAnchorBeatOffset = $memberCellBottomAnchorBeatOffset
        $memberSelectTool = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickTool.Select" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberSelectTool $memberHandle
        $resourceRevisionActions.Add("member-select-tool-after-resource-download")
        Invoke-PhysicalClick $memberPlacedPoint.x $memberPlacedPoint.y $memberHandle
        $resourceRevisionActions.Add("member-select-owner-note-from-latest-revision")
        Wait-Condition -Description "member physically selects post-download owner Note" `
            -Seconds 15 -Condition {
                try {
                    $live = Get-TimelineLiveState $member.Process.Id
                    return [string]$live.selectedNoteId -ceq [string]$ownerPlacedNote.id -and
                        [long]$live.roomSyncRevision -eq 2
                }
                catch { return $false }
            }
        $memberSelectedLive = Get-TimelineLiveState $member.Process.Id
        $captures.memberLatestRevisionSelected = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-latest-revision-note-selected.png")
        $finalResourceRevisionState = Get-HarnessState $endpoint
        $finalMemberSnapshot = Get-ChartSnapshot $endpoint $member.Token
        $memberServerNote = @(
            $finalMemberSnapshot.notes |
                Where-Object { [string]$_.id -ceq [string]$ownerPlacedNote.id })[0]
        if (-not $memberServerNote) {
            throw "Member authority snapshot omitted the owner Note created during resource download."
        }
        $remainingPartFiles = @(
            Get-ChildItem -LiteralPath $member.LocalData -Recurse -File -Force `
                -Filter "*.part" -ErrorAction SilentlyContinue
        )
        if ($remainingPartFiles.Count -ne 0) {
            throw "Revision-window resource materialization left .part files."
        }

        $screenshots = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
            $screenshots[$file.BaseName] = [ordered]@{
                path = $file.FullName
                length = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        $resourceRevisionEvidence = [ordered]@{
            schema =
                "lumachart.windows.avalonia.two-client-resource-revision-window-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed"
            formalMigrationAuthority = $true
            completion = $false
            migrationComplete = $false
            windowsAvaloniaOnly = $true
            productionServerMutationPerformed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            resourceRevisionOnly = $true
            physicalMouseInputUsed = $true
            endpoint = $endpoint
            processIds = [ordered]@{
                server = $server.Id
                owner = $owner.Process.Id
                member = $member.Process.Id
            }
            delayedResourceAttempt = $delayedAttempt
            baselineRevision = [long]$beforeOwnerPlacement.revision
            ownerCommittedRevision = [long]$afterOwnerRevision.revision
            ownerPlacedNote = $ownerPlacedNote
            memberInitialRoomSyncRevision = [long]$memberLiveAfterRevision.roomSyncRevision
            memberSelectedNoteId = [string]$memberSelectedLive.selectedNoteId
            memberRuntimeNoteCount = [int]$memberRoomRuntime.chart.structure.noteCount
            finalRevision = [long]$finalResourceRevisionState.revision
            finalServerNote = $memberServerNote
            noPartFiles = $remainingPartFiles.Count -eq 0
            physicalActions = $resourceRevisionActions.ToArray()
            hashes = [ordered]@{
                application =
                    (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
                serverAssembly =
                    (Get-FileHash -LiteralPath $serverAssemblyFullPath -Algorithm SHA256).Hash
                fixture =
                    (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
            }
            screenshots = $screenshots
            finalServerState = $finalResourceRevisionState
        }
        $resourceRevisionPath = Join-Path $outputFullPath "evidence.json"
        $resourceRevisionEvidence | ConvertTo-Json -Depth 60 |
            Set-Content -LiteralPath $resourceRevisionPath -Encoding utf8NoBOM
        Write-Output "Windows Avalonia resource-download revision GUI capture: passed"
        Write-Output "Evidence: $resourceRevisionPath"
        return
    }
    if ($ResourceResilienceOnly) {
        $resourcePhysicalActions = [Collections.Generic.List[string]]::new()
        $memberCommunityHandle = [IntPtr]$memberCommunity.Current.NativeWindowHandle
        if ($memberCommunityHandle -eq [IntPtr]::Zero) {
            $memberCommunityHandle = $memberHandle
        }
        Invoke-PhysicalElementClick $memberRoomJoin $memberCommunityHandle
        $resourcePhysicalActions.Add("member-click-room-join")
        $memberJoinSubmit = $null
        $memberJoinedDirectly = $false
        $joinPathDeadline = [DateTimeOffset]::UtcNow.AddSeconds(10)
        while ([DateTimeOffset]::UtcNow -lt $joinPathDeadline) {
            try {
                $memberJoinSubmit = Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "OnlineRooms.Join.Submit" -TimeoutMilliseconds 300
                break
            }
            catch {
                $joinPathState = Get-HarnessState $endpoint
                if (@($joinPathState.activeMemberIds) -contains 4202 -or
                    @($joinPathState.faults.resourceDownloadAttempts).Count -gt 0) {
                    $memberJoinedDirectly = $true
                    break
                }
            }
            Start-Sleep -Milliseconds 100
        }
        if ($memberJoinSubmit) {
            Invoke-PhysicalElementClick $memberJoinSubmit $memberCommunityHandle
            $resourcePhysicalActions.Add("member-submit-room-join")
        }
        elseif (-not $memberJoinedDirectly) {
            throw "Member join neither exposed a confirmation action nor started a direct public-room join."
        }
        [void](Wait-HarnessState $endpoint {
                param($state)
                @($state.activeMemberIds) -contains 4202
            } "member joined before explicit resource transfer" 20)
        $memberResourceConfirmation = Wait-RoomResourceConfirmation `
            -ProcessId $member.Process.Id -Seconds 30
        Invoke-PhysicalElementClick $memberResourceConfirmation $memberCommunityHandle
        $resourcePhysicalActions.Add("member-confirm-room-resource-download")

        $afterDisconnect = Wait-HarnessState $endpoint {
            param($state)
            @($state.activeMemberIds) -contains 4202 -and
            [int]$state.faults.injectedDisconnectedResourceDownloadCount -eq 1 -and
            [int]$state.faults.pendingDisconnectedResourceDownloads -eq 0 -and
            [int]$state.faults.pendingCorruptedResourceDownloads -eq 1
        } "member resource response interrupted after joining"
        $disconnectStatus = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineRooms.Active.Status" -TimeoutMilliseconds 30000
        Wait-Condition -Description "visible resource interruption failure status" -Seconds 20 -Condition {
            [string]$disconnectStatus.Current.Name -like "*失败*" -or
            [string]$disconnectStatus.Current.Name -like "*未打开*" -or
            [string]$disconnectStatus.Current.Name -like "*中断*"
        }
        Write-Output ("Resource disconnect UI status: " + [string]$disconnectStatus.Current.Name)
        $observations.memberResourceDisconnectStatus = Observe-Element $disconnectStatus
        $captures.memberResourceDisconnect = Capture-Window $memberCommunityHandle `
            (Join-Path $outputFullPath "member-resource-download-interrupted.png")
        $memberResourceCacheRoot = Join-Path $member.LocalData "room-resource-cache"
        $publishedAfterDisconnect = if (Test-Path -LiteralPath $memberResourceCacheRoot) {
            @(Get-ChildItem -LiteralPath $memberResourceCacheRoot -File -Force)
        } else { @() }
        if ($publishedAfterDisconnect.Count -ne 0) {
            throw "Interrupted resource download published a cache blob."
        }

        $firstRetry = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineRooms.Active.OpenChart" -TimeoutMilliseconds 15000
        Invoke-PhysicalElementClick $firstRetry $memberCommunityHandle
        $resourcePhysicalActions.Add("member-retry-after-resource-disconnect")
        $afterHashFailure = Wait-HarnessState $endpoint {
            param($state)
            [int]$state.faults.injectedCorruptedResourceDownloadCount -eq 1 -and
            [int]$state.faults.pendingCorruptedResourceDownloads -eq 0
        } "same-length corrupt resource response rejection"
        $hashFailureStatus = Wait-ElementName -ProcessId $member.Process.Id `
            -AutomationId "OnlineRooms.Active.Status" -Like "*SHA-256*" -Seconds 30
        $observations.memberResourceHashFailureStatus = Observe-Element $hashFailureStatus
        $captures.memberResourceHashFailure = Capture-Window $memberCommunityHandle `
            (Join-Path $outputFullPath "member-resource-sha256-rejected.png")
        $publishedAfterHashFailure = if (Test-Path -LiteralPath $memberResourceCacheRoot) {
            @(Get-ChildItem -LiteralPath $memberResourceCacheRoot -File -Force)
        } else { @() }
        if ($publishedAfterHashFailure.Count -ne 0) {
            throw "Corrupt same-length resource response replaced or published a cache blob."
        }

        $secondRetry = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineRooms.Active.OpenChart" -TimeoutMilliseconds 15000
        Invoke-PhysicalElementClick $secondRetry $memberCommunityHandle
        $resourcePhysicalActions.Add("member-retry-after-resource-hash-failure")
        $afterNetworkRecovery = Wait-HarnessState $endpoint {
            param($state)
            $uniqueResourceHashes = @($state.resourceEntries | Group-Object -Property sha256).Count
            @($state.activeMemberIds) -contains 4202 -and
            [int]$state.faults.pendingDisconnectedResourceDownloads -eq 0 -and
            [int]$state.faults.pendingCorruptedResourceDownloads -eq 0 -and
            @($state.faults.resourceDownloadAttempts).Count -ge ($uniqueResourceHashes + 2) -and
            [int]$state.sseConnectionCount -ge 2
        } "member resource recovery and editor binding"
        $networkRecoveredTab = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab" -TimeoutMilliseconds 45000
        $observations.memberResourceNetworkRecoveredStatus = Observe-Element $networkRecoveredTab
        $captures.memberResourceNetworkRecovered = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-resource-network-recovered.png")

        $resourceEntries = @($afterNetworkRecovery.resourceEntries)
        $uniqueResourceEntries = @($resourceEntries | Group-Object -Property sha256 | ForEach-Object {
                $_.Group[0]
            })
        if ($uniqueResourceEntries.Count -eq 0) {
            throw "The server evidence exposed no committed resource entries."
        }
        $cacheHashesBeforeTamper = [ordered]@{}
        foreach ($entry in $uniqueResourceEntries) {
            $cachePath = Join-Path $memberResourceCacheRoot ([string]$entry.sha256).ToLowerInvariant()
            if (-not (Test-Path -LiteralPath $cachePath -PathType Leaf)) {
                throw "Recovered member cache is missing $($entry.path)."
            }
            $actualHash = (Get-FileHash -LiteralPath $cachePath -Algorithm SHA256).Hash
            if ($actualHash -cne ([string]$entry.sha256).ToUpperInvariant()) {
                throw "Recovered member cache hash mismatch for $($entry.path)."
            }
            $cacheHashesBeforeTamper[[string]$entry.path] = $actualHash
        }

        $tamperEntry = @($resourceEntries | Where-Object {
                [string]$_.path -ceq "working.mc"
            })[0]
        if (-not $tamperEntry) { $tamperEntry = $uniqueResourceEntries[0] }
        $tamperCachePath = Join-Path $memberResourceCacheRoot `
            ([string]$tamperEntry.sha256).ToLowerInvariant()
        $tamperBytes = [IO.File]::ReadAllBytes($tamperCachePath)
        if ($tamperBytes.Length -eq 0) { throw "Cannot tamper an empty resource cache fixture." }
        $tamperIndex = [int][Math]::Floor($tamperBytes.Length / 2)
        $tamperBytes[$tamperIndex] = $tamperBytes[$tamperIndex] -bxor 0x3c
        [IO.File]::WriteAllBytes($tamperCachePath, $tamperBytes)
        $tamperedCacheHash = (Get-FileHash -LiteralPath $tamperCachePath -Algorithm SHA256).Hash
        if ($tamperedCacheHash -ceq ([string]$tamperEntry.sha256).ToUpperInvariant()) {
            throw "Same-length local cache tamper did not change SHA-256."
        }

        $memberCommunity = Open-Community $member
        $memberCommunityHandle = [IntPtr]$memberCommunity.Current.NativeWindowHandle
        if ($memberCommunityHandle -eq [IntPtr]::Zero) {
            $memberCommunityHandle = $memberHandle
        }
        Invoke-Element (Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineCommunity.Navigation.Rooms" -TimeoutMilliseconds 15000)
        $cacheRepairButton = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineRooms.Active.OpenChart" -TimeoutMilliseconds 30000
        $captures.memberResourceCacheTampered = Capture-Window $memberCommunityHandle `
            (Join-Path $outputFullPath "member-resource-cache-tamper-retry.png")
        $attemptsBeforeCacheRepair = @($afterNetworkRecovery.faults.resourceDownloadAttempts).Count
        Invoke-PhysicalElementClick $cacheRepairButton $memberCommunityHandle
        $resourcePhysicalActions.Add("member-open-chart-after-same-length-cache-tamper")
        $afterCacheRepairRequest = Wait-HarnessState $endpoint {
            param($state)
            $attempts = @($state.faults.resourceDownloadAttempts)
            if ($attempts.Count -ne ($attemptsBeforeCacheRepair + 1)) { return $false }
            $last = $attempts[-1]
            return [string]$last.sha256 -ceq [string]$tamperEntry.sha256 -and
                -not [bool]$last.responseDisconnected -and
                -not [bool]$last.responseCorrupted
        } "automatic same-length cache repair request"
        Wait-Condition -Description "same-length member cache hash restoration" -Seconds 30 -Condition {
            (Test-Path -LiteralPath $tamperCachePath -PathType Leaf) -and
            (Get-FileHash -LiteralPath $tamperCachePath -Algorithm SHA256).Hash -ceq
                ([string]$tamperEntry.sha256).ToUpperInvariant()
        }
        $cacheRepairTab = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab" -TimeoutMilliseconds 45000
        $observations.memberResourceCacheRepairStatus = Observe-Element $cacheRepairTab
        Start-Sleep -Seconds 3
        $captures.memberResourceCacheRepaired = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-resource-cache-repaired.png")
        $finalResourceState = Get-HarnessState $endpoint
        $remainingPartFiles = @(
            Get-ChildItem -LiteralPath $member.LocalData -File -Recurse -Force `
                -Filter "*.part" -ErrorAction SilentlyContinue
        )
        if ($remainingPartFiles.Count -ne 0) {
            throw "Resource recovery left .part files in the isolated member data root."
        }
        Wait-File $member.RoomRuntime "resource-recovered member room runtime evidence" 100
        $memberRoomRuntime = Get-Content -Raw -LiteralPath $member.RoomRuntime | ConvertFrom-Json
        $memberRoomChartPath = [string]$memberRoomRuntime.chart.sourcePath
        if (-not $memberRoomChartPath.StartsWith($member.LocalData, [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $memberRoomChartPath -PathType Leaf)) {
            throw "Resource recovery did not leave a real member MC tab under its isolated data root."
        }
        $memberMaterializedRoot = Join-Path $member.LocalData "online-room-documents"
        $latestMaterializedDirectory = Get-ChildItem -LiteralPath $memberMaterializedRoot `
            -Directory -Force | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        if (-not $latestMaterializedDirectory) {
            throw "Resource recovery did not leave a materialized room document directory."
        }
        $latestMaterializedHashes = [ordered]@{}
        foreach ($entry in $resourceEntries) {
            $materializedPath = Join-Path $latestMaterializedDirectory.FullName `
                ([string]$entry.path).Replace('/', [IO.Path]::DirectorySeparatorChar)
            if (-not (Test-Path -LiteralPath $materializedPath -PathType Leaf)) {
                throw "Latest room materialization is missing $($entry.path)."
            }
            $actualHash = (Get-FileHash -LiteralPath $materializedPath -Algorithm SHA256).Hash
            if ($actualHash -cne ([string]$entry.sha256).ToUpperInvariant()) {
                throw "Latest room materialization hash mismatch for $($entry.path)."
            }
            $latestMaterializedHashes[[string]$entry.path] = $actualHash
        }

        $resourceResilienceEvidence = [ordered]@{
            passed =
                [int]$finalResourceState.faults.injectedDisconnectedResourceDownloadCount -eq 1 -and
                [int]$finalResourceState.faults.injectedCorruptedResourceDownloadCount -eq 1 -and
                [int]$finalResourceState.faults.pendingDisconnectedResourceDownloads -eq 0 -and
                [int]$finalResourceState.faults.pendingCorruptedResourceDownloads -eq 0 -and
                $publishedAfterDisconnect.Count -eq 0 -and
                $publishedAfterHashFailure.Count -eq 0 -and
                $remainingPartFiles.Count -eq 0
            disconnect = [ordered]@{
                state = $afterDisconnect.faults
                visibleStatus = $observations.memberResourceDisconnectStatus
                publishedCacheFiles = $publishedAfterDisconnect.Count
            }
            corruptResponse = [ordered]@{
                state = $afterHashFailure.faults
                visibleStatus = $observations.memberResourceHashFailureStatus
                publishedCacheFiles = $publishedAfterHashFailure.Count
            }
            networkRecovery = [ordered]@{
                state = $afterNetworkRecovery.faults
                visibleStatus = $observations.memberResourceNetworkRecoveredStatus
                cacheHashes = $cacheHashesBeforeTamper
            }
            sameLengthCacheTamper = [ordered]@{
                path = $tamperCachePath
                expectedSha256 = ([string]$tamperEntry.sha256).ToUpperInvariant()
                tamperedSha256 = $tamperedCacheHash
                length = $tamperBytes.LongLength
                repairRequestState = $afterCacheRepairRequest.faults
                repairedSha256 = (Get-FileHash -LiteralPath $tamperCachePath -Algorithm SHA256).Hash
                visibleStatus = $observations.memberResourceCacheRepairStatus
            }
            noPartFiles = $remainingPartFiles.Count -eq 0
            materializedChartPath = $memberRoomChartPath
            materializedChartExists = Test-Path -LiteralPath $memberRoomChartPath -PathType Leaf
            latestMaterializedDirectory = $latestMaterializedDirectory.FullName
            latestMaterializedHashes = $latestMaterializedHashes
            physicalActions = $resourcePhysicalActions.ToArray()
        }
        if (-not $resourceResilienceEvidence.passed) {
            throw "Resource interruption/corruption/cache-repair GUI evidence was incomplete."
        }

        $screenshots = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
            $screenshots[$file.BaseName] = [ordered]@{
                path = $file.FullName
                length = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        $resourceEvidence = [ordered]@{
            schema = "lumachart.windows.avalonia.two-client-resource-resilience-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = $(if ($AutomationDiagnostic) { "diagnostic-passed-nonformal" } else { "passed" })
            formalMigrationAuthority = -not [bool]$AutomationDiagnostic
            completion = $false
            migrationComplete = $false
            windowsAvaloniaOnly = $true
            productionServerMutationPerformed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            resourceResilienceOnly = $true
            mouseInputUsed = -not [bool]$AutomationDiagnostic
            physicalMouseInputUsed = -not [bool]$AutomationDiagnostic
            automationDiagnosticNonFormal = [bool]$AutomationDiagnostic
            endpoint = $endpoint
            processIds = [ordered]@{
                server = $server.Id
                owner = $owner.Process.Id
                member = $member.Process.Id
            }
            paths = [ordered]@{
                projectRoot = $projectRoot
                outputRoot = $outputFullPath
                application = $applicationFullPath
                serverAssembly = $serverAssemblyFullPath
                fixture = $fixtureFullPath
                memberLocalData = $member.LocalData
                memberResourceCache = $memberResourceCacheRoot
            }
            hashes = [ordered]@{
                application = (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
                applicationAssembly = (Get-FileHash `
                    -LiteralPath ([IO.Path]::ChangeExtension($applicationFullPath, ".dll")) `
                    -Algorithm SHA256).Hash
                serverAssembly = (Get-FileHash -LiteralPath $serverAssemblyFullPath -Algorithm SHA256).Hash
                fixture = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
            }
            recovery = $resourceResilienceEvidence
            finalServerState = $finalResourceState
            controls = $observations
            captures = $captures
            screenshots = $screenshots
        }
        $resourceEvidencePath = Join-Path $outputFullPath $(if ($AutomationDiagnostic) {
                "diagnostic-evidence.json"
            } else { "evidence.json" })
        $resourceEvidence | ConvertTo-Json -Depth 60 | Set-Content `
            -LiteralPath $resourceEvidencePath -Encoding utf8NoBOM
        Write-Output "Windows Avalonia two-client resource resilience GUI capture: passed"
        Write-Output "Evidence: $resourceEvidencePath"
        return
    }
    Invoke-Element $memberRoomJoin
    if ($CreatorMarkerOnly -or $ServerRestartOnly -or $ClientRestartOnly -or
        $LeaseRecoveryOnly -or
        $ApplicationCloseRetentionOnly -or $MultiLockOnly -or $ResilienceOnly) {
        try {
            $memberJoinSubmit = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRooms.Join.Submit" -TimeoutMilliseconds 2500
            Invoke-PhysicalElementClick $memberJoinSubmit `
                ([IntPtr]$memberCommunity.Current.NativeWindowHandle)
        }
        catch {
            # A public room may bind the editor immediately from the room-row
            # action. Accept that WPF-compatible route only after the loopback
            # authority confirms the membership.
            [void](Wait-HarnessState $endpoint {
                    param($state)
                    @($state.activeMemberIds) -contains 4202
                } "direct public-room join" 10)
        }
    }
    # The default harness room is public. Its row action establishes membership
    # directly; password-room scenarios alone expose OnlineRooms.Join.Submit.
    [void](Wait-HarnessState $endpoint {
            param($state)
            @($state.activeMemberIds) -contains 4202
        } "member joined before room resource confirmation" 20)
    $memberCommunityHandle = [IntPtr]$memberCommunity.Current.NativeWindowHandle
    if ($memberCommunityHandle -eq [IntPtr]::Zero) {
        $memberCommunityHandle = $memberHandle
    }
    $memberResourceConfirmation = Wait-RoomResourceConfirmation `
        -ProcessId $member.Process.Id -Seconds 30
    $memberResourceOpenStarted = $false
    $memberResourceApplicationCloseFallbackUsed = $false
    $memberResourcePhysicalAttemptCount = 0
    for ($resourceOpenAttempt = 1;
         $resourceOpenAttempt -le 3 -and -not $memberResourceOpenStarted;
         $resourceOpenAttempt++) {
        $memberResourcePhysicalAttemptCount++
        Invoke-PhysicalElementClick $memberResourceConfirmation `
            $memberCommunityHandle
        $resourceOpenDeadline = [DateTimeOffset]::UtcNow.AddSeconds(6)
        do {
            Start-Sleep -Milliseconds 200
            $resourceOpenState = Get-HarnessState $endpoint
            if ([int]$resourceOpenState.downloadedBlobCount -gt 0 -or
                [int]$resourceOpenState.sseConnectionCount -ge 2) {
                $memberResourceOpenStarted = $true
                break
            }
            try {
                $stillReady = Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "OnlineRooms.Active.OpenChart" `
                    -TimeoutMilliseconds 250
                if (-not $stillReady.Current.IsEnabled -or
                    [string]$stillReady.Current.Name -notlike "*进入*") {
                    $memberResourceOpenStarted = $true
                    break
                }
            }
            catch {
                # The community window closes as soon as the room editor takes
                # focus, before the loopback server necessarily records the first
                # resource request.
                $memberResourceOpenStarted = $true
                break
            }
        } while ([DateTimeOffset]::UtcNow -lt $resourceOpenDeadline)
        if (-not $memberResourceOpenStarted) {
            $memberResourceConfirmation = Wait-RoomResourceConfirmation `
                -ProcessId $member.Process.Id -Seconds 10
        }
    }
    if (-not $memberResourceOpenStarted -and $ApplicationCloseRetentionOnly) {
        # Resource-entry pointer activation is covered by dedicated online GUI
        # slices. Do not let a transient foreground hit-test miss prevent this
        # focused application-close/retention slice from reaching its target.
        $memberResourceConfirmation = Wait-RoomResourceConfirmation `
            -ProcessId $member.Process.Id -Seconds 10
        $downloadedBeforeFallback =
            [int](Get-HarnessState $endpoint).downloadedBlobCount
        Invoke-Element $memberResourceConfirmation
        $memberResourceApplicationCloseFallbackUsed = $true
        Wait-Condition -Description "member resource action after UIA fallback" `
            -Seconds 20 -Condition {
                $state = Get-HarnessState $endpoint
                if ([int]$state.downloadedBlobCount -gt $downloadedBeforeFallback) {
                    return $true
                }
                try {
                    $stillReady = Find-ElementById -ProcessId $member.Process.Id `
                        -AutomationId "OnlineRooms.Active.OpenChart" `
                        -TimeoutMilliseconds 250
                    return -not $stillReady.Current.IsEnabled -or
                        [string]$stillReady.Current.Name -notlike "*进入*"
                }
                catch { return $true }
            }
        $memberResourceOpenStarted = $true
    }
    if (-not $memberResourceOpenStarted) {
        throw "The member resource action remained ready after three physical clicks."
    }
    $memberReconnectStatus = $null
    if ($ResilienceOnly) {
        try {
            $memberReconnectStatus = Wait-ElementName -ProcessId $member.Process.Id `
                -AutomationId "Editor.Status" -Like "*重连*" -Seconds 3
            $observations.memberSseReconnectStatus = [ordered]@{
                observed = $true
                control = Observe-Element $memberReconnectStatus
            }
            $captures.memberSseReconnect = Capture-Window $memberHandle `
                (Join-Path $outputFullPath "member-sse-reconnecting.png")
        }
        catch {
            # The two injected disconnects can recover between the public-room
            # join action and UIA discovery. Server connection history and the
            # final synchronized revision remain the functional authority; a
            # transient presentation label is informative, not a main-flow gate.
            $memberStableStatus = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.Status" -TimeoutMilliseconds 5000
            $observations.memberSseReconnectStatus = [ordered]@{
                observed = $false
                control = Observe-Element $memberStableStatus
            }
        }
    }
    $afterJoin = Wait-HarnessState $endpoint {
        param($state)
        @($state.activeMemberIds) -contains 4202 -and [int]$state.downloadedBlobCount -ge 3 -and
        [int]$state.sseConnectionCount -ge $(if ($ResilienceOnly) { 4 } else { 2 })
    } "member resource download, editor binding and two SSE clients"
    $memberEditorPath = Join-Path $outputFullPath "member-editor-bound.png"
    $captures.memberEditor = Capture-Window $memberHandle $memberEditorPath
    if ($RoomChatPanelOnly) {
        $roomChatPhysicalActions = [Collections.Generic.List[string]]::new()
        $fixtureHashBefore =
            (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
        $ownerPanel = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "RoomCollaboration.Panel" -TimeoutMilliseconds 15000
        $memberPanel = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "RoomCollaboration.Panel" -TimeoutMilliseconds 15000
        $ownerPanelBefore = Observe-Element $ownerPanel
        $memberPanelBefore = Observe-Element $memberPanel
        $ownerMemberCount = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "RoomCollaboration.MemberCount" -TimeoutMilliseconds 10000
        $memberMemberCount = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "RoomCollaboration.MemberCount" -TimeoutMilliseconds 10000
        Wait-Condition -Description "both floating room panels show both members" `
            -Seconds 20 -Condition {
                [string]$ownerMemberCount.Current.Name -match '^2 / \d+$' -and
                [string]$memberMemberCount.Current.Name -match '^2 / \d+$'
            }

        $ownerToggle = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "RoomCollaboration.Toggle" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerToggle $ownerHandle
        $roomChatPhysicalActions.Add("owner-collapse-floating-room-chat")
        Wait-Condition -Description "owner floating room chat collapsed" `
            -Seconds 10 -Condition {
                [string]$ownerToggle.Current.Name -ceq "+"
            }

        $memberChatInput = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "RoomCollaboration.ChatInput" -TimeoutMilliseconds 10000
        $memberChatSend = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "RoomCollaboration.Send" -TimeoutMilliseconds 10000
        Set-ElementValue $memberChatInput "房间悬浮聊天与未读红点验证"
        Invoke-PhysicalElementClick $memberChatSend $memberHandle
        $roomChatPhysicalActions.Add("member-send-floating-room-chat")
        $chatState = Wait-HarnessState $endpoint {
            param($state)
            [int]$state.chatCount -ge 1
        } "floating room chat message"

        $ownerUnreadDot = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "RoomCollaboration.UnreadDot" -TimeoutMilliseconds 15000
        if ($ownerUnreadDot.Current.IsOffscreen) {
            throw "The collapsed owner room panel did not expose its unread red dot."
        }
        $ownerUnreadObservation = Observe-Element $ownerUnreadDot
        $captures.ownerCollapsedUnread = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-room-chat-collapsed-unread.png")

        $ownerToggle = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "RoomCollaboration.Toggle" -TimeoutMilliseconds 5000
        Invoke-PhysicalElementClick $ownerToggle $ownerHandle
        $roomChatPhysicalActions.Add("owner-expand-floating-room-chat")
        Wait-Condition -Description "owner floating room chat expanded and unread cleared" `
            -Seconds 15 -Condition {
                if ([string]$ownerToggle.Current.Name -cne "−") { return $false }
                try {
                    $dot = Find-ElementById -ProcessId $owner.Process.Id `
                        -AutomationId "RoomCollaboration.UnreadDot" `
                        -TimeoutMilliseconds 250
                    return [bool]$dot.Current.IsOffscreen
                }
                catch { return $true }
            }
        $ownerChat = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "RoomCollaboration.Chat" -TimeoutMilliseconds 10000
        $ownerMembers = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "RoomCollaboration.Members" -TimeoutMilliseconds 10000
        $captures.ownerExpandedChat = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-room-chat-expanded.png")

        $ownerHeader = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "RoomCollaboration.Header" -TimeoutMilliseconds 10000
        $headerBounds = $ownerHeader.Current.BoundingRectangle
        $dragStartX = [int][Math]::Round($headerBounds.Left + $headerBounds.Width * .42)
        $dragStartY = [int][Math]::Round($headerBounds.Top + $headerBounds.Height * .50)
        Invoke-PhysicalDrag `
            $dragStartX `
            $dragStartY `
            ($dragStartX - 130) `
            ($dragStartY - 90) `
            $ownerHandle
        $roomChatPhysicalActions.Add("owner-drag-floating-room-chat-up-left")
        Wait-Condition -Description "floating room chat moved after header drag" `
            -Seconds 10 -Condition {
                $moved = Find-ElementById -ProcessId $owner.Process.Id `
                    -AutomationId "RoomCollaboration.Panel" `
                    -TimeoutMilliseconds 500
                $bounds = $moved.Current.BoundingRectangle
                [Math]::Abs($bounds.Left - [double]$ownerPanelBefore.bounds.left) -ge 40 -or
                    [Math]::Abs($bounds.Top - [double]$ownerPanelBefore.bounds.top) -ge 40
            }
        $ownerPanelAfterDrag = Observe-Element (
            Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "RoomCollaboration.Panel" -TimeoutMilliseconds 5000)
        $captures.ownerDraggedChat = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-room-chat-dragged.png")

        $fixtureHashAfter =
            (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
        $finalRoomChatState = Get-HarnessState $endpoint
        $screenshots = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
            $screenshots[$file.BaseName] = [ordered]@{
                path = $file.FullName
                length = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        $roomChatPassed =
            [int]$finalRoomChatState.chatCount -ge 1 -and
            -not [bool]$ownerPanelBefore.isOffscreen -and
            -not [bool]$memberPanelBefore.isOffscreen -and
            -not [bool]$ownerUnreadObservation.isOffscreen -and
            [string]$ownerMemberCount.Current.Name -match '^2 / \d+$' -and
            [string]$memberMemberCount.Current.Name -match '^2 / \d+$' -and
            ([Math]::Abs(
                    [double]$ownerPanelAfterDrag.bounds.left -
                    [double]$ownerPanelBefore.bounds.left) -ge 40 -or
             [Math]::Abs(
                    [double]$ownerPanelAfterDrag.bounds.top -
                    [double]$ownerPanelBefore.bounds.top) -ge 40) -and
            $screenshots.Count -ge 4 -and
            $fixtureHashBefore -ceq $fixtureHashAfter
        if (-not $roomChatPassed) {
            throw "Floating room members/chat, unread-dot or drag gates were incomplete."
        }

        $roomChatEvidence = [ordered]@{
            schema =
                "lumachart.windows.avalonia.two-client-floating-room-chat-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed"
            formalMigrationAuthority = $false
            completion = $false
            migrationComplete = $false
            windowsAvaloniaOnly = $true
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
            productionServerMutationPerformed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            roomChatPanelOnly = $true
            physicalMouseInputUsed = $true
            endpoint = $endpoint
            processIds = [ordered]@{
                server = $server.Id
                owner = $owner.Process.Id
                member = $member.Process.Id
            }
            hashes = [ordered]@{
                application =
                    (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
                applicationAssembly =
                    (Get-FileHash `
                        -LiteralPath ([IO.Path]::ChangeExtension($applicationFullPath, ".dll")) `
                        -Algorithm SHA256).Hash
                serverAssembly =
                    (Get-FileHash -LiteralPath $serverAssemblyFullPath -Algorithm SHA256).Hash
                fixtureBefore = $fixtureHashBefore
                fixtureAfter = $fixtureHashAfter
            }
            roomPanels = [ordered]@{
                ownerBefore = $ownerPanelBefore
                memberBefore = $memberPanelBefore
                ownerMemberCount = Observe-Element $ownerMemberCount
                memberMemberCount = Observe-Element $memberMemberCount
                ownerUnreadDot = $ownerUnreadObservation
                ownerChat = Observe-Element $ownerChat
                ownerMembers = Observe-Element $ownerMembers
                ownerAfterDrag = $ownerPanelAfterDrag
            }
            chat = [ordered]@{
                submittedText = "房间悬浮聊天与未读红点验证"
                countAfterSubmit = [int]$chatState.chatCount
                countFinal = [int]$finalRoomChatState.chatCount
                unreadClearedOnExpand = $true
            }
            physicalActions = $roomChatPhysicalActions.ToArray()
            captures = $captures
            screenshots = $screenshots
            finalServerState = $finalRoomChatState
            passed = $roomChatPassed
        }
        $roomChatEvidencePath = Join-Path $outputFullPath "evidence.json"
        $roomChatEvidence | ConvertTo-Json -Depth 60 |
            Set-Content -LiteralPath $roomChatEvidencePath -Encoding utf8NoBOM
        Write-Output "Windows Avalonia two-client floating room chat GUI capture: passed"
        Write-Output "Evidence: $roomChatEvidencePath"
        return
    }
    if (-not $CreatorMarkerOnly -and -not $ServerRestartOnly) {
        $ownerLatency = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.ChartTab.LiveLatency" -TimeoutMilliseconds 15000
        $memberLatency = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab.LiveLatency" -TimeoutMilliseconds 15000
        $ownerLiveBadge = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.ChartTab.LiveBadge" -TimeoutMilliseconds 15000
        $memberLiveBadge = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab.LiveBadge" -TimeoutMilliseconds 15000
        $observations.ownerLiveLatencyInitial = Observe-Element $ownerLatency
        $observations.memberLiveLatencyInitial = Observe-Element $memberLatency
        Wait-Condition -Description "both WPF-compatible online latency labels" `
            -Seconds 25 -Condition {
                # RebuildTabs replaces these visual instances whenever latency
                # presentation changes. Re-resolve each poll instead of retaining
                # stale UIA elements that can never satisfy the gate.
                [string](Find-ElementById -ProcessId $owner.Process.Id `
                    -AutomationId "Editor.ChartTab.LiveBadge" `
                    -TimeoutMilliseconds 1000).Current.Name -match '\d{1,5} ms$' -and
                [string](Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "Editor.ChartTab.LiveBadge" `
                    -TimeoutMilliseconds 1000).Current.Name -match '\d{1,5} ms$'
            }
        $ownerLatency = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.ChartTab.LiveLatency" -TimeoutMilliseconds 5000
        $memberLatency = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab.LiveLatency" -TimeoutMilliseconds 5000
        $ownerLiveBadge = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.ChartTab.LiveBadge" -TimeoutMilliseconds 5000
        $memberLiveBadge = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab.LiveBadge" -TimeoutMilliseconds 5000
        $observations.ownerLiveLatencyMeasured = Observe-Element $ownerLatency
        $observations.memberLiveLatencyMeasured = Observe-Element $memberLatency
        $observations.ownerLiveBadgeLatency = Observe-Element $ownerLiveBadge
        $observations.memberLiveBadgeLatency = Observe-Element $memberLiveBadge
        if ([string]$observations.ownerLiveBadgeLatency.helpText -notlike
                "*与联机服务器最近一次请求的往返延迟*" -or
            [string]$observations.memberLiveBadgeLatency.helpText -notlike
                "*与联机服务器最近一次请求的往返延迟*") {
            throw "Online live badge does not expose the WPF round-trip latency description."
        }
        $captures.ownerOnlineLatency = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-online-latency.png")
        $captures.memberOnlineLatency = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-online-latency.png")
    }

    if ($ServerRestartOnly) {
        $restartPhysicalActions = [Collections.Generic.List[string]]::new()
        $ownerStatus = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        $memberStatus = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        Wait-Condition -Description "both clients synchronized before process restart" `
            -Seconds 30 -Condition {
            [string]$ownerStatus.Current.Name -like "*已同步*" -and
            [string]$memberStatus.Current.Name -like "*已同步*"
        }
        Wait-File $member.RoomRuntime "member room-tab GUI runtime evidence" 95
        $memberRoomRuntime =
            Get-Content -Raw -LiteralPath $member.RoomRuntime | ConvertFrom-Json
        $memberRoomChartPath = [string]$memberRoomRuntime.chart.sourcePath
        if (-not $memberRoomChartPath.StartsWith(
                $member.LocalData,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Member restart evidence did not use the materialized room MC."
        }
        $roomId = [string]$afterJoin.room.id
        $baselineSnapshot = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $baselineIds = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase)
        foreach ($note in @($baselineSnapshot.notes)) {
            [void]$baselineIds.Add([string]$note.id)
        }
        $baselineNoteCount = @($baselineSnapshot.notes).Count
        $preRestartState = Get-HarnessState $endpoint
        if ($baselineNoteCount -ne 2753 -or
            [long]$preRestartState.revision -ne 1 -or
            -not (Test-Path -LiteralPath $checkpointPath -PathType Leaf)) {
            throw "The real 2,753-Note room baseline/checkpoint was not ready before restart."
        }
        $checkpointBeforeRestart = Get-Item -LiteralPath $checkpointPath
        $checkpointHashBeforeRestart =
            (Get-FileHash -LiteralPath $checkpointPath -Algorithm SHA256).Hash
        $fixtureHashBefore =
            (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
        $ownerChartHashBefore =
            (Get-FileHash -LiteralPath $owner.InputChart -Algorithm SHA256).Hash
        $memberChartHashBefore =
            (Get-FileHash -LiteralPath $memberRoomChartPath -Algorithm SHA256).Hash

        foreach ($clientPlan in @(
                [pscustomobject]@{
                    Client = $owner
                    Handle = $ownerHandle
                    Label = "owner"
                },
                [pscustomobject]@{
                    Client = $member
                    Handle = $memberHandle
                    Label = "member"
                })) {
            try { Close-Community $clientPlan.Client } catch { }
            $preset = Find-ElementById `
                -ProcessId $clientPlan.Client.Process.Id `
                -AutomationId "Editor.QuickValues.Snap.Preset" `
                -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $preset $clientPlan.Handle
            $restartPhysicalActions.Add(
                "$($clientPlan.Label)-open-snap-preset")
            $snap24 = Find-ElementByName `
                -ProcessId $clientPlan.Client.Process.Id `
                -Name "1/24" `
                -TimeoutMilliseconds 10000
            $snapBounds = $snap24.Current.BoundingRectangle
            Invoke-PhysicalClick `
                ([int][Math]::Round($snapBounds.Left + $snapBounds.Width / 2)) `
                ([int][Math]::Round($snapBounds.Top + $snapBounds.Height / 2)) `
                $clientPlan.Handle
            $restartPhysicalActions.Add(
                "$($clientPlan.Label)-select-exact-snap-1-24")
            Wait-Condition `
                -Description "$($clientPlan.Label) exact snap division 24" `
                -Seconds 10 `
                -PollMilliseconds 50 `
                -Condition {
                [int](Get-TimelineLiveState `
                    $clientPlan.Client.Process.Id).snapDivision -eq 24
            }
            $tapTool = Find-ElementById `
                -ProcessId $clientPlan.Client.Process.Id `
                -AutomationId "Editor.QuickTool.Tap" `
                -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $tapTool $clientPlan.Handle
            $restartPhysicalActions.Add(
                "$($clientPlan.Label)-select-tap-before-outage-placement")
            foreach ($toggleId in @(
                    "Editor.QuickPalette.Toggle",
                    "Editor.QuickValues.Toggle")) {
                $toggle = Find-ElementById `
                    -ProcessId $clientPlan.Client.Process.Id `
                    -AutomationId $toggleId `
                    -TimeoutMilliseconds 10000
                if ([string]$toggle.Current.Name -ceq "−") {
                    Invoke-PhysicalElementClick $toggle $clientPlan.Handle
                    $restartPhysicalActions.Add(
                        "$($clientPlan.Label)-collapse-$toggleId")
                    Wait-Condition `
                        -Description "$($clientPlan.Label) $toggleId collapsed" `
                        -Seconds 10 `
                        -Condition {
                        [string](Find-ElementById `
                            -ProcessId $clientPlan.Client.Process.Id `
                            -AutomationId $toggleId `
                            -TimeoutMilliseconds 1000).Current.Name -ceq "+"
                    }
                }
            }
        }

        $serverStoppedAt = [DateTimeOffset]::UtcNow
        $server.Kill($true)
        if (-not $server.WaitForExit(10000)) {
            throw "The first loopback Server process did not stop."
        }
        $serverFirstExitCode = $server.ExitCode
        $firstStdout = $server.StandardOutput.ReadToEnd()
        $firstStderr = $server.StandardError.ReadToEnd()
        ($firstStdout + $firstStderr) |
            Set-Content -LiteralPath $serverFirstLogPath -Encoding utf8NoBOM
        $server.Dispose()
        $server = $null

        $memberLiveBeforePlacement = Get-TimelineLiveState $member.Process.Id
        $memberPlacement = Find-FreeTimelineTapPlacement `
            -Notes @($baselineSnapshot.notes) `
            -CurrentBeat ([double]$memberLiveBeforePlacement.currentBeat) `
            -PreferredLanes @(0, 1) `
            -Offsets @(
                (25.0 / 24.0),
                (29.0 / 24.0),
                (31.0 / 24.0),
                (35.0 / 24.0),
                (37.0 / 24.0),
                (41.0 / 24.0)) `
            -MinimumClearanceBeats .18
        $memberPoint = Get-TimelinePoint `
            $memberRoomRuntime `
            ([int]$memberPlacement.lane) `
            ([double]$memberPlacement.offset) `
            $member.Process.Id `
            ([double]$memberLiveBeforePlacement.pixelsPerBeat)
        Invoke-PhysicalClick $memberPoint.x $memberPoint.y $memberHandle
        $restartPhysicalActions.Add("member-place-exact-1-24-note-offline")
        $script:memberOfflineLive = $null
        Wait-Condition -Description "member offline Note and stable pending OperationId" `
            -Seconds 45 -PollMilliseconds 100 -Condition {
            $live = Get-TimelineLiveState $member.Process.Id
            if ([int]$live.selectedNoteCount -eq 1 -and
                -not $baselineIds.Contains([string]$live.selectedNoteId) -and
                [string]$live.selectedNoteBeat -match '/24$' -and
                [string]$live.roomSyncPendingOperationId -ne "none" -and
                [int]$live.roomSyncConsecutiveWorkFailures -ge 1 -and
                [string]$live.roomSyncWorkStatus -eq "BackingOff") {
                $script:memberOfflineLive = $live
                return $true
            }
            return $false
        }
        $memberOfflineLive = $script:memberOfflineLive
        $memberPendingOperationText =
            [Convert]::ToString(
                $memberOfflineLive["roomSyncPendingOperationId"],
                [Globalization.CultureInfo]::InvariantCulture)
        $memberOfflineOperationId = [Guid]::Empty
        if (-not [Guid]::TryParse(
                $memberPendingOperationText,
                [ref]$memberOfflineOperationId) -or
            $memberOfflineOperationId -eq [Guid]::Empty) {
            throw "Member pending OperationId was not a non-empty GUID: " +
                "'$memberPendingOperationText'."
        }

        $ownerLiveBeforePlacement = Get-TimelineLiveState $owner.Process.Id
        $ownerPlacement = Find-FreeTimelineTapPlacement `
            -Notes @($baselineSnapshot.notes) `
            -CurrentBeat ([double]$ownerLiveBeforePlacement.currentBeat) `
            -PreferredLanes @(3, 2) `
            -Offsets @(
                (31.0 / 24.0),
                (35.0 / 24.0),
                (37.0 / 24.0),
                (41.0 / 24.0),
                (43.0 / 24.0),
                (47.0 / 24.0)) `
            -MinimumClearanceBeats .18
        $ownerPoint = Get-TimelinePoint `
            $ownerRuntime `
            ([int]$ownerPlacement.lane) `
            ([double]$ownerPlacement.offset) `
            $owner.Process.Id `
            ([double]$ownerLiveBeforePlacement.pixelsPerBeat)
        Invoke-PhysicalClick $ownerPoint.x $ownerPoint.y $ownerHandle
        $restartPhysicalActions.Add("owner-place-exact-1-24-note-offline")
        $script:ownerOfflineLive = $null
        Wait-Condition -Description "owner offline Note and stable pending OperationId" `
            -Seconds 45 -PollMilliseconds 100 -Condition {
            $live = Get-TimelineLiveState $owner.Process.Id
            if ([int]$live.selectedNoteCount -eq 1 -and
                -not $baselineIds.Contains([string]$live.selectedNoteId) -and
                [string]$live.selectedNoteBeat -match '/24$' -and
                [string]$live.roomSyncPendingOperationId -ne "none" -and
                [int]$live.roomSyncConsecutiveWorkFailures -ge 1 -and
                [string]$live.roomSyncWorkStatus -eq "BackingOff") {
                $script:ownerOfflineLive = $live
                return $true
            }
            return $false
        }
        $ownerOfflineLive = $script:ownerOfflineLive
        $ownerPendingOperationText =
            [Convert]::ToString(
                $ownerOfflineLive["roomSyncPendingOperationId"],
                [Globalization.CultureInfo]::InvariantCulture)
        $ownerOfflineOperationId = [Guid]::Empty
        if (-not [Guid]::TryParse(
                $ownerPendingOperationText,
                [ref]$ownerOfflineOperationId) -or
            $ownerOfflineOperationId -eq [Guid]::Empty) {
            throw "Owner pending OperationId was not a non-empty GUID: " +
                "'$ownerPendingOperationText'."
        }
        if ($ownerOfflineOperationId -eq $memberOfflineOperationId) {
            throw "Two clients generated the same pending OperationId."
        }
        $captures.memberServerOutageLocalEdit = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-server-outage-local-edit.png")
        $captures.ownerServerOutageLocalEdit = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-server-outage-local-edit.png")

        $secondReadyPath = Join-Path $outputFullPath "server-ready-generation-2.json"
        $secondStatePath = Join-Path $outputFullPath "server-state-generation-2.json"
        $secondStart = [Diagnostics.ProcessStartInfo]::new("dotnet")
        $secondStart.UseShellExecute = $false
        $secondStart.RedirectStandardOutput = $true
        $secondStart.RedirectStandardError = $true
        foreach ($argument in @(
                $serverAssemblyFullPath,
                "--ready-file", $secondReadyPath,
                "--state-file", $secondStatePath,
                "--checkpoint-file", $checkpointPath,
                "--listen-url", $endpoint.TrimEnd('/'),
                "--process-generation", "2")) {
            $secondStart.ArgumentList.Add($argument)
        }
        $server = [Diagnostics.Process]::Start($secondStart)
        $serverSecondProcessId = $server.Id
        Wait-File $secondReadyPath "second loopback Server ready file" 30
        $secondReady =
            Get-Content -Raw -LiteralPath $secondReadyPath | ConvertFrom-Json
        $serverReadyAt = [DateTimeOffset]::UtcNow
        if ([string]$secondReady.endpoint -cne $endpoint -or
            [int]$secondReady.processGeneration -ne 2 -or
            -not [bool]$secondReady.restoredFromCheckpoint -or
            $serverFirstProcessId -eq $serverSecondProcessId) {
            throw "The fresh Server process did not restore the same loopback authority."
        }

        $script:recoveredState = $null
        Wait-Condition -Description "both live clients converge after Server restart" `
            -Seconds 75 -PollMilliseconds 150 -Condition {
            try {
                $state = Get-HarnessState $endpoint
                $acceptedIds = @($state.acceptedOperations |
                    ForEach-Object { [string]$_.operationId })
                $ownerLive = Get-TimelineLiveState $owner.Process.Id
                $memberLive = Get-TimelineLiveState $member.Process.Id
                if ($acceptedIds -contains $ownerOfflineOperationId.ToString("D") -and
                    $acceptedIds -contains $memberOfflineOperationId.ToString("D") -and
                    [string]$ownerLive.roomSyncPendingOperationId -eq "none" -and
                    [string]$memberLive.roomSyncPendingOperationId -eq "none" -and
                    [string]$ownerLive.roomSyncWorkStatus -eq "Idle" -and
                    [string]$memberLive.roomSyncWorkStatus -eq "Idle" -and
                    [string]$ownerLive.roomSyncFeedStatus -eq "Connected" -and
                    [string]$memberLive.roomSyncFeedStatus -eq "Connected" -and
                    [long]$ownerLive.roomSyncRevision -eq [long]$state.revision -and
                    [long]$memberLive.roomSyncRevision -eq [long]$state.revision) {
                    $script:recoveredState = $state
                    return $true
                }
            }
            catch { }
            return $false
        }
        $recoveredState = $script:recoveredState
        $recoveredSnapshot = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $ownerRecoveredNote = @($recoveredSnapshot.notes | Where-Object {
                [string]$_.id -ceq [string]$ownerOfflineLive.selectedNoteId
            })[0]
        $memberRecoveredNote = @($recoveredSnapshot.notes | Where-Object {
                [string]$_.id -ceq [string]$memberOfflineLive.selectedNoteId
            })[0]
        if (-not $ownerRecoveredNote -or -not $memberRecoveredNote -or
            @($recoveredSnapshot.notes).Count -ne $baselineNoteCount + 2) {
            throw "The restarted Server did not retain both offline Notes."
        }
        $ownerRecoveredBeat = "{0}:{1}/{2}" -f
            [int]$ownerRecoveredNote.beat.bar,
            [int]$ownerRecoveredNote.beat.numerator,
            [int]$ownerRecoveredNote.beat.denominator
        $memberRecoveredBeat = "{0}:{1}/{2}" -f
            [int]$memberRecoveredNote.beat.bar,
            [int]$memberRecoveredNote.beat.numerator,
            [int]$memberRecoveredNote.beat.denominator
        if ($ownerRecoveredBeat -cne [string]$ownerOfflineLive.selectedNoteBeat -or
            $memberRecoveredBeat -cne [string]$memberOfflineLive.selectedNoteBeat -or
            [int]$ownerRecoveredNote.beat.denominator -ne 24 -or
            [int]$memberRecoveredNote.beat.denominator -ne 24) {
            throw "Server restart changed an authored exact 1/24 Beat."
        }

        $ownerOperationAttempts = @(
            $recoveredState.faults.chartOperationAttempts | Where-Object {
                [string]$_.operationId -ceq $ownerOfflineOperationId.ToString("D")
            })
        $memberOperationAttempts = @(
            $recoveredState.faults.chartOperationAttempts | Where-Object {
                [string]$_.operationId -ceq $memberOfflineOperationId.ToString("D")
            })
        $ownerAccepted = @($recoveredState.acceptedOperations | Where-Object {
                [string]$_.operationId -ceq $ownerOfflineOperationId.ToString("D")
            })
        $memberAccepted = @($recoveredState.acceptedOperations | Where-Object {
                [string]$_.operationId -ceq $memberOfflineOperationId.ToString("D")
            })
        if ($ownerOperationAttempts.Count -ne 1 -or
            $memberOperationAttempts.Count -ne 1 -or
            $ownerAccepted.Count -ne 1 -or
            $memberAccepted.Count -ne 1) {
            throw "Restart recovery did not commit each stable pending OperationId exactly once."
        }

        $ownerPaletteToggle = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.QuickPalette.Toggle"
        if ([string]$ownerPaletteToggle.Current.Name -ceq "+") {
            Invoke-PhysicalElementClick $ownerPaletteToggle $ownerHandle
            $restartPhysicalActions.Add("owner-expand-quick-tools-after-restart")
        }
        $ownerSelect = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.QuickTool.Select" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerSelect $ownerHandle
        $restartPhysicalActions.Add("owner-select-tool-after-server-restart")
        $ownerPaletteToggle = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.QuickPalette.Toggle"
        if ([string]$ownerPaletteToggle.Current.Name -ceq "−") {
            Invoke-PhysicalElementClick $ownerPaletteToggle $ownerHandle
            $restartPhysicalActions.Add("owner-collapse-quick-tools-after-select")
        }
        $ownerLiveAfterRecovery = Get-TimelineLiveState $owner.Process.Id
        $memberRecoveredValue =
            [double]$memberRecoveredNote.beat.bar +
            [double]$memberRecoveredNote.beat.numerator /
                [double]$memberRecoveredNote.beat.denominator
        $memberRemotePointOnOwner = Get-TimelinePoint `
            $ownerRuntime `
            ([int]$memberRecoveredNote.lane) `
            ($memberRecoveredValue - [double]$ownerLiveAfterRecovery.currentBeat) `
            $owner.Process.Id `
            ([double]$ownerLiveAfterRecovery.pixelsPerBeat)
        Invoke-PhysicalClick `
            $memberRemotePointOnOwner.x `
            $memberRemotePointOnOwner.y `
            $ownerHandle
        $restartPhysicalActions.Add("owner-select-member-offline-note-after-restart")
        Wait-Condition -Description "owner local model contains member offline Note" `
            -Seconds 15 -PollMilliseconds 50 -Condition {
            [string](Get-TimelineLiveState $owner.Process.Id).selectedNoteId -ceq
                [string]$memberRecoveredNote.id
        }

        $memberPaletteToggle = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickPalette.Toggle"
        if ([string]$memberPaletteToggle.Current.Name -ceq "+") {
            Invoke-PhysicalElementClick $memberPaletteToggle $memberHandle
            $restartPhysicalActions.Add("member-expand-quick-tools-after-restart")
        }
        $memberSelect = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickTool.Select" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberSelect $memberHandle
        $restartPhysicalActions.Add("member-select-tool-after-server-restart")
        $memberPaletteToggle = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickPalette.Toggle"
        if ([string]$memberPaletteToggle.Current.Name -ceq "−") {
            Invoke-PhysicalElementClick $memberPaletteToggle $memberHandle
            $restartPhysicalActions.Add("member-collapse-quick-tools-after-select")
        }
        $memberLiveAfterRecovery = Get-TimelineLiveState $member.Process.Id
        $ownerRecoveredValue =
            [double]$ownerRecoveredNote.beat.bar +
            [double]$ownerRecoveredNote.beat.numerator /
                [double]$ownerRecoveredNote.beat.denominator
        $ownerRemotePointOnMember = Get-TimelinePoint `
            $memberRoomRuntime `
            ([int]$ownerRecoveredNote.lane) `
            ($ownerRecoveredValue - [double]$memberLiveAfterRecovery.currentBeat) `
            $member.Process.Id `
            ([double]$memberLiveAfterRecovery.pixelsPerBeat)
        Invoke-PhysicalClick `
            $ownerRemotePointOnMember.x `
            $ownerRemotePointOnMember.y `
            $memberHandle
        $restartPhysicalActions.Add("member-select-owner-offline-note-after-restart")
        Wait-Condition -Description "member local model contains owner offline Note" `
            -Seconds 15 -PollMilliseconds 50 -Condition {
            [string](Get-TimelineLiveState $member.Process.Id).selectedNoteId -ceq
                [string]$ownerRecoveredNote.id
        }
        $captures.ownerServerRestartRecovered = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-server-restart-recovered.png")
        $captures.memberServerRestartRecovered = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-server-restart-recovered.png")

        Invoke-EditorSave $owner
        Invoke-EditorSave $member
        [void](Wait-EditorSavedState $owner.Process.Id 30)
        [void](Wait-EditorSavedState $member.Process.Id 30)
        $ownerSavedDocument =
            Get-Content -Raw -LiteralPath $owner.InputChart | ConvertFrom-Json
        $memberSavedDocument =
            Get-Content -Raw -LiteralPath $memberRoomChartPath | ConvertFrom-Json
        $ownerPlayableNotes = @($ownerSavedDocument.note | Where-Object {
                $null -ne $_.column
            })
        $memberPlayableNotes = @($memberSavedDocument.note | Where-Object {
                $null -ne $_.column
            })
        $ownerContainsBoth = @(
            $ownerPlayableNotes | Where-Object {
                ([int]$_.column -eq [int]$ownerRecoveredNote.lane -and
                    [int]$_.beat[0] -eq [int]$ownerRecoveredNote.beat.bar -and
                    [int]$_.beat[1] -eq [int]$ownerRecoveredNote.beat.numerator -and
                    [int]$_.beat[2] -eq [int]$ownerRecoveredNote.beat.denominator) -or
                ([int]$_.column -eq [int]$memberRecoveredNote.lane -and
                    [int]$_.beat[0] -eq [int]$memberRecoveredNote.beat.bar -and
                    [int]$_.beat[1] -eq [int]$memberRecoveredNote.beat.numerator -and
                    [int]$_.beat[2] -eq [int]$memberRecoveredNote.beat.denominator)
            }).Count -eq 2
        $memberContainsBoth = @(
            $memberPlayableNotes | Where-Object {
                ([int]$_.column -eq [int]$ownerRecoveredNote.lane -and
                    [int]$_.beat[0] -eq [int]$ownerRecoveredNote.beat.bar -and
                    [int]$_.beat[1] -eq [int]$ownerRecoveredNote.beat.numerator -and
                    [int]$_.beat[2] -eq [int]$ownerRecoveredNote.beat.denominator) -or
                ([int]$_.column -eq [int]$memberRecoveredNote.lane -and
                    [int]$_.beat[0] -eq [int]$memberRecoveredNote.beat.bar -and
                    [int]$_.beat[1] -eq [int]$memberRecoveredNote.beat.numerator -and
                    [int]$_.beat[2] -eq [int]$memberRecoveredNote.beat.denominator)
            }).Count -eq 2
        if ($ownerPlayableNotes.Count -ne $baselineNoteCount + 2 -or
            $memberPlayableNotes.Count -ne $baselineNoteCount + 2 -or
            -not $ownerContainsBoth -or -not $memberContainsBoth) {
            throw "Saved owner/member MC files did not structurally retain both exact offline Notes."
        }

        $fixtureHashAfter =
            (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
        if ($fixtureHashBefore -cne $fixtureHashAfter) {
            throw "The frozen real MC changed during Server restart recovery."
        }
        $screenshots = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
            $screenshots[$file.BaseName] = [ordered]@{
                path = $file.FullName
                length = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        $restartEvidence = [ordered]@{
            schema = "lumachart.windows.avalonia.two-client-server-restart-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = if ($FormalMigrationAuthority) {
                "passed-migration-incomplete"
            } else {
                "preflight-passed-nonformal"
            }
            formalMigrationAuthority = [bool]$FormalMigrationAuthority
            completion = $false
            migrationComplete = $false
            windowsAvaloniaOnly = $true
            productionServerMutationPerformed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            serverRestartOnly = $true
            physicalMouseInputUsed = $true
            enterKeyUsed = $false
            endpoint = $endpoint
            processRestart = [ordered]@{
                firstProcessId = $serverFirstProcessId
                firstExitCode = $serverFirstExitCode
                secondProcessId = $serverSecondProcessId
                distinctProcessIds = $serverFirstProcessId -ne $serverSecondProcessId
                sameEndpoint = [string]$secondReady.endpoint -ceq $endpoint
                stoppedUtc = $serverStoppedAt.ToString("O")
                readyUtc = $serverReadyAt.ToString("O")
                downtimeMilliseconds =
                    [Math]::Round(($serverReadyAt - $serverStoppedAt).TotalMilliseconds, 3)
                restoredFromCheckpoint = [bool]$secondReady.restoredFromCheckpoint
                processGeneration = [int]$secondReady.processGeneration
                checkpointLengthBeforeRestart = [long]$checkpointBeforeRestart.Length
                checkpointSha256BeforeRestart = $checkpointHashBeforeRestart
            }
            paths = [ordered]@{
                projectRoot = $projectRoot
                outputRoot = $outputFullPath
                application = $applicationFullPath
                serverAssembly = $serverAssemblyFullPath
                fixture = $fixtureFullPath
                ownerSavedChart = $owner.InputChart
                memberSavedChart = $memberRoomChartPath
                checkpoint = $checkpointPath
                temp = $projectTemp
                dotnetHome = $dotnetHome
                nugetPackages = $nugetPackages
                nugetHttpCache = $nugetHttpCache
            }
            hashes = [ordered]@{
                application =
                    (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
                applicationAssembly =
                    (Get-FileHash `
                        -LiteralPath ([IO.Path]::ChangeExtension($applicationFullPath, ".dll")) `
                        -Algorithm SHA256).Hash
                serverAssembly =
                    (Get-FileHash -LiteralPath $serverAssemblyFullPath -Algorithm SHA256).Hash
                fixtureBefore = $fixtureHashBefore
                fixtureAfter = $fixtureHashAfter
                ownerChartBefore = $ownerChartHashBefore
                ownerChartAfter =
                    (Get-FileHash -LiteralPath $owner.InputChart -Algorithm SHA256).Hash
                memberChartBefore = $memberChartHashBefore
                memberChartAfter =
                    (Get-FileHash -LiteralPath $memberRoomChartPath -Algorithm SHA256).Hash
            }
            baseline = [ordered]@{
                noteCount = $baselineNoteCount
                revision = [long]$preRestartState.revision
                serverState = $preRestartState
            }
            offlineEdits = [ordered]@{
                member = [ordered]@{
                    noteId = [string]$memberOfflineLive.selectedNoteId
                    beat = [string]$memberOfflineLive.selectedNoteBeat
                    lane = [int]$memberOfflineLive.selectedNoteLane
                    pendingOperationId = $memberOfflineOperationId.ToString("D")
                    workFailuresBeforeRestart =
                        [int]$memberOfflineLive.roomSyncConsecutiveWorkFailures
                    workStatusBeforeRestart =
                        [string]$memberOfflineLive.roomSyncWorkStatus
                }
                owner = [ordered]@{
                    noteId = [string]$ownerOfflineLive.selectedNoteId
                    beat = [string]$ownerOfflineLive.selectedNoteBeat
                    lane = [int]$ownerOfflineLive.selectedNoteLane
                    pendingOperationId = $ownerOfflineOperationId.ToString("D")
                    workFailuresBeforeRestart =
                        [int]$ownerOfflineLive.roomSyncConsecutiveWorkFailures
                    workStatusBeforeRestart =
                        [string]$ownerOfflineLive.roomSyncWorkStatus
                }
                exactDenominator = 24
                distinctOperationIds =
                    $ownerOfflineOperationId -ne $memberOfflineOperationId
            }
            recovery = [ordered]@{
                revision = [long]$recoveredState.revision
                noteCount = @($recoveredSnapshot.notes).Count
                ownerRecoveredBeat = $ownerRecoveredBeat
                memberRecoveredBeat = $memberRecoveredBeat
                ownerOperationAttempts = $ownerOperationAttempts
                memberOperationAttempts = $memberOperationAttempts
                ownerAcceptedCount = $ownerAccepted.Count
                memberAcceptedCount = $memberAccepted.Count
                exactlyOnce = $ownerAccepted.Count -eq 1 -and
                    $memberAccepted.Count -eq 1
                ownerSelectedMemberRemoteNote = $true
                memberSelectedOwnerRemoteNote = $true
                finalServerState = $recoveredState
            }
            savedCompatibility = [ordered]@{
                ownerPlayableNoteCount = $ownerPlayableNotes.Count
                memberPlayableNoteCount = $memberPlayableNotes.Count
                ownerContainsBothExactNotes = [bool]$ownerContainsBoth
                memberContainsBothExactNotes = [bool]$memberContainsBoth
            }
            physicalActions = $restartPhysicalActions.ToArray()
            captures = $captures
            screenshots = $screenshots
            passed = $true
        }
        $restartEvidencePath = Join-Path $outputFullPath "evidence.json"
        $restartEvidence | ConvertTo-Json -Depth 70 |
            Set-Content -LiteralPath $restartEvidencePath -Encoding utf8NoBOM
        Write-Output "Windows Avalonia live two-client Server restart GUI capture: passed"
        Write-Output "Evidence: $restartEvidencePath"
        return
    }

    if ($LeaseRecoveryOnly) {
        $leaseActions = [Collections.Generic.List[string]]::new()
        try { Close-Community $owner } catch { }
        try { Close-Community $member } catch { }
        $roomId = [string]$afterJoin.room.id
        $baselineSnapshot = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $baselineNoteCount = @($baselineSnapshot.notes).Count
        if ($baselineNoteCount -ne 2753) {
            throw "Lease recovery evidence did not begin with the real 2,753-Note room."
        }
        $baselineIds = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase)
        foreach ($note in @($baselineSnapshot.notes)) {
            [void]$baselineIds.Add([string]$note.id)
        }
        $memberRuntime =
            Get-Content -Raw -LiteralPath $member.Runtime | ConvertFrom-Json
        $ownerRuntime =
            Get-Content -Raw -LiteralPath $owner.Runtime | ConvertFrom-Json
        $fixtureHashBefore =
            (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
        $installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
        $installerHashBefore =
            (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
        $initialLeaseState = Get-HarnessState $endpoint
        $captures.leaseInitialOwner = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "lease-initial-owner.png")
        $captures.leaseInitialMember = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "lease-initial-member.png")

        Select-PhysicalTapToolAtSnap24 `
            $member $memberHandle $leaseActions "member-long-offline"
        [void](Set-HarnessNetworkBlackout $endpoint 4202 $true)
        $memberBlackoutStartedAt = [DateTimeOffset]::UtcNow
        $script:memberBlackoutState = $null
        Wait-Condition -Description "member transport abort and disconnected latency" `
            -Seconds 35 -PollMilliseconds 200 -Condition {
            $state = Get-HarnessState $endpoint
            $latency = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.ChartTab.LiveLatency" `
                -TimeoutMilliseconds 1000
            if ([int]$state.lease.transportAbortCount -ge 2 -and
                [string]$latency.Current.Name -ceq "-- ms") {
                $script:memberBlackoutState = $state
                return $true
            }
            return $false
        }
        $memberBlackoutState = $script:memberBlackoutState
        $memberLiveBeforePlacement = Get-TimelineLiveState $member.Process.Id
        $memberPlacement = Find-FreeTimelineTapPlacement `
            -Notes @($baselineSnapshot.notes) `
            -CurrentBeat ([double]$memberLiveBeforePlacement.currentBeat) `
            -PreferredLanes @(0, 1) `
            -Offsets @(
                (25.0 / 24.0),
                (29.0 / 24.0),
                (31.0 / 24.0),
                (35.0 / 24.0),
                (37.0 / 24.0)) `
            -MinimumClearanceBeats .18
        $memberPoint = Get-TimelinePoint `
            $memberRuntime `
            ([int]$memberPlacement.lane) `
            ([double]$memberPlacement.offset) `
            $member.Process.Id `
            ([double]$memberLiveBeforePlacement.pixelsPerBeat)
        Invoke-PhysicalClick $memberPoint.x $memberPoint.y $memberHandle
        $leaseActions.Add("member-place-exact-1-24-note-during-transport-blackout")
        $script:memberOfflineLive = $null
        Wait-Condition -Description "member offline Note and stable pending operation" `
            -Seconds 25 -PollMilliseconds 100 -Condition {
            $live = Get-TimelineLiveState $member.Process.Id
            if ([int]$live.selectedNoteCount -eq 1 -and
                -not $baselineIds.Contains([string]$live.selectedNoteId) -and
                [string]$live.selectedNoteBeat -match '/24$' -and
                [string]$live.roomSyncPendingOperationId -ne "none" -and
                [int]$live.roomSyncConsecutiveWorkFailures -ge 1) {
                $script:memberOfflineLive = $live
                return $true
            }
            return $false
        }
        $memberOfflineLive = $script:memberOfflineLive
        $memberPendingOperationId =
            [string]$memberOfflineLive.roomSyncPendingOperationId
        $serverDuringMemberBlackout = Get-HarnessState $endpoint
        if (@($serverDuringMemberBlackout.acceptedOperations | Where-Object {
                    [string]$_.operationId -ceq $memberPendingOperationId
                }).Count -ne 0) {
            throw "The blacked-out member operation reached the Server before recovery."
        }
        $captures.memberLongOfflinePending = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-long-offline-pending.png")

        [void](Advance-HarnessLeaseClock $endpoint 46)
        $ownerAccount = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineAccount.Navigation" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerAccount $ownerHandle
        $leaseActions.Add("owner-open-community-to-observe-member")
        $ownerCommunity = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 30000
        $ownerCommunityHandle =
            Get-TopLevelWindowHandleForElement $ownerCommunity
        $ownerRooms = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineCommunity.Navigation.Rooms" `
            -TimeoutMilliseconds 15000
        Invoke-PhysicalElementClick $ownerRooms $ownerCommunityHandle
        $leaseActions.Add("owner-open-active-room-member-list")
        $memberOfflineState = Wait-ElementName -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Member.4202.State" `
            -Like "*离线*" -Seconds 30
        $memberOfflineServerState = Wait-HarnessState $endpoint {
            param($state)
            $memberState = @($state.members | Where-Object {
                    [long]$_.userId -eq 4202
                })[0]
            [bool]$state.roomCreated -and
            @($state.activeMemberIds) -contains 4202 -and
            -not [bool]$memberState.isOnline
        } "45-second member offline display without lease removal" 30
        $captures.ownerSeesMemberOffline = Capture-Window $ownerCommunityHandle `
            (Join-Path $outputFullPath "owner-sees-member-offline-after-45s.png")

        $memberLease = @($memberOfflineServerState.lease.members | Where-Object {
                [long]$_.userId -eq 4202
            })[0]
        $memberAdvanceToNearExpiry = [Math]::Max(
            0,
            885.0 - [double]$memberLease.lastSeenAgeSeconds)
        if ($memberAdvanceToNearExpiry -gt 0) {
            [void](Advance-HarnessLeaseClock $endpoint $memberAdvanceToNearExpiry)
        }
        [void](Invoke-HarnessLeaseCleanup $endpoint)
        $memberNearExpiryState = Get-HarnessState $endpoint
        $memberNearExpiry = @($memberNearExpiryState.lease.members | Where-Object {
                [long]$_.userId -eq 4202
            })[0]
        if (-not [bool]$memberNearExpiryState.roomCreated -or
            @($memberNearExpiryState.activeMemberIds) -notcontains 4202 -or
            [double]$memberNearExpiry.lastSeenAgeSeconds -lt 875 -or
            [double]$memberNearExpiry.lastSeenAgeSeconds -ge 900) {
            throw "The member did not remain active and offline inside the fifteen-minute grace."
        }
        $captures.ownerSeesMemberRetainedNearLease = Capture-Window `
            $ownerCommunityHandle `
            (Join-Path $outputFullPath "owner-sees-member-retained-near-15m.png")
        $ownerCommunityClose = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineCommunity.Navigation.Close" `
            -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerCommunityClose $ownerCommunityHandle
        $leaseActions.Add("owner-close-community-before-member-recovery")

        [void](Set-HarnessNetworkBlackout $endpoint 4202 $false)
        $memberBlackoutEndedAt = [DateTimeOffset]::UtcNow
        $script:memberRecoveredState = $null
        Wait-Condition -Description "member lease renewal and exactly-once pending recovery" `
            -Seconds 60 -PollMilliseconds 200 -Condition {
            $state = Get-HarnessState $endpoint
            $leaseMember = @($state.lease.members | Where-Object {
                    [long]$_.userId -eq 4202
                })[0]
            $accepted = @($state.acceptedOperations | Where-Object {
                    [string]$_.operationId -ceq $memberPendingOperationId
                })
            $attempts = @($state.faults.chartOperationAttempts | Where-Object {
                    [string]$_.operationId -ceq $memberPendingOperationId
                })
            $live = Get-TimelineLiveState $member.Process.Id
            $latency = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "Editor.ChartTab.LiveLatency" `
                -TimeoutMilliseconds 1000
            if ([bool]$state.roomCreated -and
                [bool]$leaseMember.active -and [bool]$leaseMember.online -and
                $accepted.Count -eq 1 -and $attempts.Count -eq 1 -and
                [string]$live.roomSyncPendingOperationId -eq "none" -and
                [string]$live.roomSyncWorkStatus -eq "Idle" -and
                [string]$latency.Current.Name -match '^\d{1,5} ms$') {
                $script:memberRecoveredState = $state
                return $true
            }
            return $false
        }
        $memberRecoveredState = $script:memberRecoveredState
        $memberRecoveredSnapshot =
            Get-ChartSnapshot $endpoint $owner.Token $roomId
        $memberRecoveredNote = @($memberRecoveredSnapshot.notes | Where-Object {
                [string]$_.id -ceq [string]$memberOfflineLive.selectedNoteId
            })[0]
        if (-not $memberRecoveredNote -or
            @($memberRecoveredSnapshot.notes).Count -ne $baselineNoteCount + 1 -or
            [int]$memberRecoveredNote.beat.denominator -ne 24) {
            throw "The member long-offline Note did not recover with its exact rational Beat."
        }
        $captures.memberRecoveredBeforeLeaseExpiry = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-recovered-before-15m-expiry.png")

        Select-PhysicalTapToolAtSnap24 `
            $owner $ownerHandle $leaseActions "owner-lease-expiry"
        [void](Set-HarnessNetworkBlackout $endpoint 4101 $true)
        $ownerBlackoutStartedAt = [DateTimeOffset]::UtcNow
        $ownerAbortBaseline = [int]$memberRecoveredState.lease.transportAbortCount
        Wait-HarnessState $endpoint {
            param($state)
            [int]$state.lease.transportAbortCount -ge $ownerAbortBaseline + 2
        } "owner transport abort" 35 | Out-Null
        # A long reconnect/backoff interval can rebuild the editor command surface.
        # Re-assert the physical Tap tool immediately before placing the offline
        # operation so the lease test cannot accidentally inherit Select mode.
        Select-PhysicalTapToolAtSnap24 `
            $owner $ownerHandle $leaseActions "owner-lease-expiry-after-abort"
        $ownerLiveBeforePlacement = Get-TimelineLiveState $owner.Process.Id
        # The real Resound fixture has a deterministic empty lane-0 cell at
        # current + 6/24 here. Keeping the point near the judgment line avoids
        # the floating Adjust/Quick Edit panels that cover the upper right
        # lanes, while retaining an unreduced exact /24 Beat.
        $ownerPlacement = [ordered]@{
            lane = 0
            offset = 6.0 / 24.0
            candidateBeat =
                [double]$ownerLiveBeforePlacement.currentBeat + (6.0 / 24.0)
            minimumClearanceBeats = .18
            deterministicFixtureCell = $true
        }
        $ownerPoint = Get-TimelinePoint `
            $ownerRuntime `
            ([int]$ownerPlacement.lane) `
            ([double]$ownerPlacement.offset) `
            $owner.Process.Id `
            ([double]$ownerLiveBeforePlacement.pixelsPerBeat)
        $ownerLocalLive = $ownerLiveBeforePlacement
        $ownerLocalPlacement = $ownerPlacement
        $ownerLocalPoint = $ownerPoint
        Invoke-PhysicalClick $ownerPoint.x $ownerPoint.y $ownerHandle
        $leaseActions.Add("owner-place-exact-1-24-note-during-transport-blackout")
        $script:ownerOfflineLive = $null
        Wait-Condition -Description "owner offline Note and stable pending operation" `
            -Seconds 25 -PollMilliseconds 100 -Condition {
            $live = Get-TimelineLiveState $owner.Process.Id
            if ([int]$live.selectedNoteCount -eq 1 -and
                -not $baselineIds.Contains([string]$live.selectedNoteId) -and
                [string]$live.selectedNoteId -cne
                    [string]$memberRecoveredNote.id -and
                [string]$live.selectedNoteBeat -match '/24$' -and
                [string]$live.roomSyncPendingOperationId -ne "none" -and
                [int]$live.roomSyncConsecutiveWorkFailures -ge 1) {
                $script:ownerOfflineLive = $live
                return $true
            }
            return $false
        }
        $ownerOfflineLive = $script:ownerOfflineLive
        $ownerPendingOperationId =
            [string]$ownerOfflineLive.roomSyncPendingOperationId
        $captures.ownerLeaseExpiryPending = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-lease-expiry-pending.png")

        $memberAccount = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineAccount.Navigation" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberAccount $memberHandle
        $leaseActions.Add("member-open-community-to-observe-owner")
        $memberCommunity = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 30000
        $memberCommunityHandle =
            Get-TopLevelWindowHandleForElement $memberCommunity
        $memberRooms = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineCommunity.Navigation.Rooms" `
            -TimeoutMilliseconds 15000
        Invoke-PhysicalElementClick $memberRooms $memberCommunityHandle
        $leaseActions.Add("member-open-active-room-owner-list")

        $ownerLeaseState = Get-HarnessState $endpoint
        $ownerAge = [double]$ownerLeaseState.lease.ownerHeartbeatAgeSeconds
        $ownerAdvanceToNearExpiry = [Math]::Max(0, 885.0 - $ownerAge)
        if ($ownerAdvanceToNearExpiry -gt 0) {
            [void](Advance-HarnessLeaseClock $endpoint $ownerAdvanceToNearExpiry)
        }
        $ownerOfflineState = Wait-ElementName -ProcessId $member.Process.Id `
            -AutomationId "OnlineRooms.Member.4101.State" `
            -Like "*离线*" -Seconds 30
        $script:ownerNearExpiryState = $null
        Wait-Condition -Description "owner remains in room immediately before lease expiry" `
            -Seconds 30 -PollMilliseconds 200 -Condition {
            $state = Get-HarnessState $endpoint
            $ownerMember = @($state.lease.members | Where-Object {
                    [long]$_.userId -eq 4101
                })[0]
            if ([bool]$state.roomCreated -and
                @($state.activeMemberIds) -contains 4101 -and
                -not [bool]$ownerMember.online -and
                [double]$state.lease.ownerHeartbeatAgeSeconds -ge 875 -and
                [double]$state.lease.ownerHeartbeatAgeSeconds -lt 900) {
                $script:ownerNearExpiryState = $state
                return $true
            }
            return $false
        }
        $ownerNearExpiryState = $script:ownerNearExpiryState
        $captures.memberSeesOwnerNearLeaseExpiry = Capture-Window `
            $memberCommunityHandle `
            (Join-Path $outputFullPath "member-sees-owner-near-15m-expiry.png")

        $memberCommunityClose = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineCommunity.Navigation.Close" `
            -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberCommunityClose $memberCommunityHandle
        $leaseActions.Add("member-close-community-before-owner-expiry")
        $ownerExpireAdvance = [Math]::Max(
            20.0,
            905.0 - [double]$ownerNearExpiryState.lease.ownerHeartbeatAgeSeconds)
        [void](Advance-HarnessLeaseClock $endpoint $ownerExpireAdvance)
        $leaseClosure = Invoke-HarnessLeaseCleanup $endpoint
        if ([bool]$leaseClosure.roomCreated -or
            [int]$leaseClosure.cleanupCount -lt 1) {
            throw "The absent owner did not close the room after the fifteen-minute lease."
        }
        [void](Set-HarnessNetworkBlackout $endpoint 4101 $false)
        $ownerBlackoutEndedAt = [DateTimeOffset]::UtcNow
        $script:postLeaseState = $null
        Wait-Condition -Description "both clients detach to retained local tabs after owner expiry" `
            -Seconds 45 -PollMilliseconds 250 -Condition {
            $state = Get-HarnessState $endpoint
            $ownerRetained = @(
                Find-ElementsById -ProcessId $owner.Process.Id `
                    -AutomationId "Editor.ChartTab.RetainedBadge")
            $memberRetained = @(
                Find-ElementsById -ProcessId $member.Process.Id `
                    -AutomationId "Editor.ChartTab.RetainedBadge")
            $ownerLive = @(
                Find-ElementsById -ProcessId $owner.Process.Id `
                    -AutomationId "Editor.ChartTab.LiveBadge")
            $memberLive = @(
                Find-ElementsById -ProcessId $member.Process.Id `
                    -AutomationId "Editor.ChartTab.LiveBadge")
            if (-not [bool]$state.roomCreated -and
                $ownerRetained.Count -eq 1 -and
                $memberRetained.Count -eq 1 -and
                $ownerLive.Count -eq 0 -and
                $memberLive.Count -eq 0) {
                $script:postLeaseState = $state
                return $true
            }
            return $false
        }
        $postLeaseState = $script:postLeaseState
        if (@($postLeaseState.acceptedOperations | Where-Object {
                    [string]$_.operationId -ceq $ownerPendingOperationId
                }).Count -ne 0 -or
            [int]$postLeaseState.acceptedOperationCount -ne
                [int]$memberRecoveredState.acceptedOperationCount) {
            throw "The owner operation crossed the expired room lease."
        }
        $captures.ownerRetainedAfterLeaseExpiry = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-retained-after-lease-expiry.png")
        $captures.memberRetainedAfterLeaseExpiry = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-retained-after-lease-expiry.png")

        $ownerRetainedLive = Get-TimelineLiveState $owner.Process.Id
        if ([string]$ownerRetainedLive.selectedNoteId -cne
                [string]$ownerOfflineLive.selectedNoteId -or
            [string]$ownerRetainedLive.selectedNoteBeat -cne
                [string]$ownerOfflineLive.selectedNoteBeat) {
            throw "The owner retained tab lost its local pending Note at lease closure."
        }
        Invoke-EditorSave $owner
        [void](Wait-EditorSavedState $owner.Process.Id 30)
        $leaseActions.Add("owner-save-retained-local-branch-after-lease-expiry")
        $captures.ownerSavedRetainedAfterLeaseExpiry = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-saved-retained-after-lease-expiry.png")

        $ownerWorkspacePath =
            Join-Path $owner.Editing "desktop-workspace\workspace.json"
        $ownerWorkspace =
            Get-Content -Raw -LiteralPath $ownerWorkspacePath | ConvertFrom-Json
        $ownerActiveTab = @($ownerWorkspace.Tabs | Where-Object {
                [string]$_.Id -ceq [string]$ownerWorkspace.ActiveTabId
            })[0]
        $ownerRetainedPath = [string]$ownerActiveTab.SourcePath
        $ownerSavedDocument =
            Get-Content -Raw -LiteralPath $ownerRetainedPath | ConvertFrom-Json
        $ownerBeatMatch = [regex]::Match(
            [string]$ownerOfflineLive.selectedNoteBeat,
            '^(-?\d+):(\d+)/(\d+)$')
        if (-not $ownerBeatMatch.Success) {
            throw "The owner retained exact Beat was not parseable."
        }
        $ownerSavedNoteMatches = @($ownerSavedDocument.note | Where-Object {
                $null -ne $_.column -and
                [int]$_.column -eq [int]$ownerOfflineLive.selectedNoteLane -and
                [int]$_.beat[0] -eq [int]$ownerBeatMatch.Groups[1].Value -and
                [int]$_.beat[1] -eq [int]$ownerBeatMatch.Groups[2].Value -and
                [int]$_.beat[2] -eq [int]$ownerBeatMatch.Groups[3].Value
            })
        if ($ownerSavedNoteMatches.Count -ne 1 -or
            @($ownerSavedDocument.note | Where-Object {
                    $null -ne $_.column
                }).Count -ne $baselineNoteCount + 2) {
            throw "The saved retained MC did not preserve both the recovered member Note and local owner Note."
        }

        $fixtureHashAfter =
            (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
        $installerHashAfter =
            (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
        if ($fixtureHashBefore -cne $fixtureHashAfter -or
            $installerHashBefore -cne $installerHashAfter) {
            throw "The frozen real MC or released WPF installer changed during lease recovery."
        }
        $screenshots = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
            $screenshots[$file.BaseName] = [ordered]@{
                path = $file.FullName
                length = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        $finalLeaseState = Get-HarnessState $endpoint
        $leaseEvidence = [ordered]@{
            schema = "lumachart.windows.avalonia.two-client-room-lease-recovery-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = if ($FormalMigrationAuthority) {
                "passed-migration-incomplete"
            } else {
                "preflight-passed-nonformal"
            }
            formalMigrationAuthority = [bool]$FormalMigrationAuthority
            completion = $false
            migrationComplete = $false
            windowsAvaloniaOnly = $true
            productionServerMutationPerformed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            leaseRecoveryOnly = $true
            physicalMouseInputUsed = $true
            enterKeyUsed = $false
            endpoint = $endpoint
            leasePolicy = [ordered]@{
                presenceRefreshSeconds = 15
                onlineDisplaySeconds = 45
                memberAbsenceGraceSeconds = 900
                ownerClosureGraceSeconds = 900
                obsoleteNinetySecondLeaseRestored = $false
                virtualClockUsedForLongBoundary = $true
                forcedTcpAbortUsed = $true
                physicalNetworkAdapterDisabled = $false
            }
            memberRecovery = [ordered]@{
                blackoutStartedUtc = $memberBlackoutStartedAt.ToString("O")
                blackoutEndedUtc = $memberBlackoutEndedAt.ToString("O")
                pendingOperationId = $memberPendingOperationId
                noteId = [string]$memberOfflineLive.selectedNoteId
                lane = [int]$memberOfflineLive.selectedNoteLane
                beat = [string]$memberOfflineLive.selectedNoteBeat
                offlineDisplay = Observe-Element $memberOfflineState
                nearExpiryAgeSeconds =
                    [double]$memberNearExpiry.lastSeenAgeSeconds
                remainedActiveInsideGrace =
                    @($memberNearExpiryState.activeMemberIds) -contains 4202
                acceptedOperationCount = @(
                    $memberRecoveredState.acceptedOperations | Where-Object {
                        [string]$_.operationId -ceq $memberPendingOperationId
                    }).Count
                operationAttemptCount = @(
                    $memberRecoveredState.faults.chartOperationAttempts |
                        Where-Object {
                            [string]$_.operationId -ceq $memberPendingOperationId
                        }).Count
                exactDenominator = [int]$memberRecoveredNote.beat.denominator
            }
            ownerExpiry = [ordered]@{
                blackoutStartedUtc = $ownerBlackoutStartedAt.ToString("O")
                blackoutEndedUtc = $ownerBlackoutEndedAt.ToString("O")
                pendingOperationId = $ownerPendingOperationId
                noteId = [string]$ownerOfflineLive.selectedNoteId
                lane = [int]$ownerOfflineLive.selectedNoteLane
                beat = [string]$ownerOfflineLive.selectedNoteBeat
                offlineDisplay = Observe-Element $ownerOfflineState
                nearExpiryAgeSeconds =
                    [double]$ownerNearExpiryState.lease.ownerHeartbeatAgeSeconds
                roomActiveInsideGrace = [bool]$ownerNearExpiryState.roomCreated
                roomClosedAfterGrace = -not [bool]$postLeaseState.roomCreated
                cleanupCount = [int]$postLeaseState.lease.cleanupCount
                pendingOperationAcceptedCount = @(
                    $postLeaseState.acceptedOperations | Where-Object {
                        [string]$_.operationId -ceq $ownerPendingOperationId
                    }).Count
                ownerRetainedBadgeCount = @(
                    Find-ElementsById -ProcessId $owner.Process.Id `
                        -AutomationId "Editor.ChartTab.RetainedBadge").Count
                memberRetainedBadgeCount = @(
                    Find-ElementsById -ProcessId $member.Process.Id `
                        -AutomationId "Editor.ChartTab.RetainedBadge").Count
                savedRetainedPath = $ownerRetainedPath
                savedPlayableNoteCount = @($ownerSavedDocument.note | Where-Object {
                        $null -ne $_.column
                    }).Count
                savedContainsLocalOwnerNote = $ownerSavedNoteMatches.Count -eq 1
            }
            transport = [ordered]@{
                totalAbortedRequests = [int]$finalLeaseState.lease.transportAbortCount
                abortsByUser = $finalLeaseState.lease.transportAbortCounts
            }
            actions = $leaseActions.ToArray()
            screenshots = $screenshots
            finalServerState = $finalLeaseState
            hashes = [ordered]@{
                application =
                    (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
                serverAssembly =
                    (Get-FileHash -LiteralPath $serverAssemblyFullPath -Algorithm SHA256).Hash
                fixtureBefore = $fixtureHashBefore
                fixtureAfter = $fixtureHashAfter
                releasedInstallerBefore = $installerHashBefore
                releasedInstallerAfter = $installerHashAfter
                retainedMc =
                    (Get-FileHash -LiteralPath $ownerRetainedPath -Algorithm SHA256).Hash
            }
        }
        $leaseEvidencePath = Join-Path $outputFullPath "evidence.json"
        $leaseEvidence | ConvertTo-Json -Depth 80 |
            Set-Content -LiteralPath $leaseEvidencePath -Encoding utf8NoBOM
        Write-Output "Windows Avalonia two-client room lease recovery GUI capture: passed"
        Write-Output "Evidence: $leaseEvidencePath"
        return
    }

    if ($ClientRestartOnly) {
        $clientRestartActions = [Collections.Generic.List[string]]::new()
        try { Close-Community $owner } catch { }
        try { Close-Community $member } catch { }
        $ownerStatus = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        $memberStatus = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        Wait-Condition -Description "both clients synchronized before client restart" `
            -Seconds 30 -Condition {
            [string]$ownerStatus.Current.Name -like "*已同步*" -and
            [string]$memberStatus.Current.Name -like "*已同步*"
        }
        Wait-File $member.RoomRuntime "member room-tab GUI runtime evidence" 95
        $memberRoomRuntime =
            Get-Content -Raw -LiteralPath $member.RoomRuntime | ConvertFrom-Json
        $memberRoomChartPath = [string]$memberRoomRuntime.chart.sourcePath
        if (-not $memberRoomChartPath.StartsWith(
                $member.LocalData,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Client restart evidence did not use the materialized room MC."
        }
        $roomId = [string]$afterJoin.room.id
        $baselineSnapshot = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $baselineIds = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase)
        foreach ($note in @($baselineSnapshot.notes)) {
            [void]$baselineIds.Add([string]$note.id)
        }
        $baselineNoteCount = @($baselineSnapshot.notes).Count
        if ($baselineNoteCount -ne 2753) {
            throw "Client restart evidence did not begin with the real 2,753-Note room."
        }
        $fixtureHashBefore =
            (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
        $materializedHashBefore =
            (Get-FileHash -LiteralPath $memberRoomChartPath -Algorithm SHA256).Hash
        $captures.memberBeforeClientRestart = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-before-client-restart.png")

        Select-PhysicalTapToolAtSnap24 `
            $member $memberHandle $clientRestartActions "member-before-client-restart"
        [void](Set-HarnessFaults $endpoint @{
                failNextChartDeltaRequests = 0
                malformedNextChartDeltaResponses = 0
                disconnectNextSseConnections = 0
                dropNextChartOperationResponsesAfterCommit = 1
                delayNextChartOperationResponseMilliseconds = 10000
                disconnectNextResourceDownloads = 0
                corruptNextResourceDownloads = 0
            })
        $memberLiveBeforeCommit = Get-TimelineLiveState $member.Process.Id
        $committedPlacement = Find-FreeTimelineTapPlacement `
            -Notes @($baselineSnapshot.notes) `
            -CurrentBeat ([double]$memberLiveBeforeCommit.currentBeat) `
            -PreferredLanes @(0, 1) `
            -Offsets @(
                (25.0 / 24.0),
                (29.0 / 24.0),
                (31.0 / 24.0),
                (35.0 / 24.0),
                (37.0 / 24.0),
                (41.0 / 24.0)) `
            -MinimumClearanceBeats .18
        $committedPoint = Get-TimelinePoint `
            $memberRoomRuntime `
            ([int]$committedPlacement.lane) `
            ([double]$committedPlacement.offset) `
            $member.Process.Id `
            ([double]$memberLiveBeforeCommit.pixelsPerBeat)
        Invoke-PhysicalClick $committedPoint.x $committedPoint.y $memberHandle
        $clientRestartActions.Add("member-place-exact-1-24-note-before-abrupt-exit")
        $script:committedLive = $null
        Wait-Condition -Description "member pre-exit Note selected" `
            -Seconds 20 -PollMilliseconds 50 -Condition {
            $live = Get-TimelineLiveState $member.Process.Id
            if ([int]$live.selectedNoteCount -eq 1 -and
                -not $baselineIds.Contains([string]$live.selectedNoteId) -and
                [string]$live.selectedNoteBeat -match '/24$') {
                $script:committedLive = $live
                return $true
            }
            return $false
        }
        $committedLive = $script:committedLive
        $script:preKillState = $null
        $script:preKillAttempt = $null
        Wait-Condition -Description "server commit held behind delayed dropped response" `
            -Seconds 20 -PollMilliseconds 50 -Condition {
            $state = Get-HarnessState $endpoint
            $attempt = @($state.faults.chartOperationAttempts | Where-Object {
                    [bool]$_.responseDropped -and
                    [int]$_.responseDelayMilliseconds -eq 10000
                } | Select-Object -Last 1)[0]
            if ($attempt -and
                [int]$state.faults.injectedDroppedChartOperationResponseCount -eq 1 -and
                [int]$state.faults.injectedDelayedChartOperationResponseCount -eq 1 -and
                @($state.acceptedOperations | Where-Object {
                        [string]$_.operationId -ceq [string]$attempt.operationId
                    }).Count -eq 1 -and
                @($state.faults.chartOperationResponseCompletions | Where-Object {
                        [string]$_.operationId -ceq [string]$attempt.operationId
                    }).Count -eq 0) {
                $script:preKillState = $state
                $script:preKillAttempt = $attempt
                return $true
            }
            return $false
        }
        $preKillState = $script:preKillState
        $preKillAttempt = $script:preKillAttempt
        $committedOperationId = [string]$preKillAttempt.operationId
        $serverCommittedSnapshot = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $serverCommittedNote = @($serverCommittedSnapshot.notes | Where-Object {
                [string]$_.id -ceq [string]$committedLive.selectedNoteId
            })[0]
        if (-not $serverCommittedNote -or
            @($serverCommittedSnapshot.notes).Count -ne $baselineNoteCount + 1) {
            throw "The server did not commit exactly one pre-exit Note."
        }
        $committedServerBeat = "{0}:{1}/{2}" -f
            [int]$serverCommittedNote.beat.bar,
            [int]$serverCommittedNote.beat.numerator,
            [int]$serverCommittedNote.beat.denominator
        if ($committedServerBeat -cne [string]$committedLive.selectedNoteBeat -or
            [int]$serverCommittedNote.beat.denominator -ne 24) {
            throw "The pre-exit server commit changed the exact 1/24 Beat."
        }
        $captures.memberCommitPendingAtAbruptExit = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-commit-pending-at-abrupt-exit.png")

        $firstMemberProcessId = $member.Process.Id
        $abruptExitAt = [DateTimeOffset]::UtcNow
        $member.Process.Kill($true)
        if (-not $member.Process.WaitForExit(10000)) {
            throw "The isolated first member process did not stop."
        }
        $firstMemberExitCode = $member.Process.ExitCode
        $member.Process.Dispose()

        $member = Start-Client -Name "member-b" -Token ([string]$ready.memberToken) `
            -Profile "windows-avalonia-online-member" -Endpoint $endpoint `
            -FollowRoomEvidence $false -ReuseExistingRoots $true -Generation 2 `
            -EvidenceChartPath $memberRoomChartPath
        $replacementMemberProcessId = $member.Process.Id
        if ($replacementMemberProcessId -eq $firstMemberProcessId) {
            throw "The replacement member did not receive a distinct process ID."
        }
        $memberHandle = [IntPtr](Wait-MainWindowHandle $member.Process)
        Wait-File $member.Runtime "replacement member startup runtime evidence" 45
        $replacementAccount =
            Wait-AuthenticatedAccountButton $member.Process.Id "成员" 30
        if ([string]$replacementAccount.Current.Name -notlike "*成员*") {
            throw "The replacement process did not restore the isolated DPAPI account."
        }
        $replacementRuntime =
            Get-Content -Raw -LiteralPath $member.Runtime | ConvertFrom-Json
        $retainedBadge = Wait-ElementName -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab.RetainedBadge" -Like "房间留存" -Seconds 20
        $tabsBeforeRejoin =
            @(Find-ElementsById -ProcessId $member.Process.Id -AutomationId "Editor.ChartTab")
        $retainedBadgesBeforeRejoin =
            @(Find-ElementsById -ProcessId $member.Process.Id `
                -AutomationId "Editor.ChartTab.RetainedBadge")
        $liveBadgesBeforeRejoin =
            @(Find-ElementsById -ProcessId $member.Process.Id `
                -AutomationId "Editor.ChartTab.LiveBadge")
        if ($tabsBeforeRejoin.Count -ne 2 -or
            $retainedBadgesBeforeRejoin.Count -ne 1 -or
            $liveBadgesBeforeRejoin.Count -ne 0) {
            throw "The replacement process did not restore one offline retained room tab beside the original local tab."
        }
        $replacementLiveBeforeLocalEdit = Get-TimelineLiveState $member.Process.Id
        if ([string]$replacementLiveBeforeLocalEdit.roomSyncPendingOperationId -ne "none") {
            throw "The replacement retained tab incorrectly restored an in-memory pending write."
        }
        $captures.memberRestartedRetainedLocal = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-restarted-retained-local.png")

        Select-PhysicalTapToolAtSnap24 `
            $member $memberHandle $clientRestartActions "member-retained-after-restart"
        $serverIdsAfterRestart = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase)
        foreach ($note in @($serverCommittedSnapshot.notes)) {
            [void]$serverIdsAfterRestart.Add([string]$note.id)
        }
        $replacementLiveForPlacement = Get-TimelineLiveState $member.Process.Id
        $retainedLocalTarget = $replacementRuntime.timeline.freeTapTarget
        if ($null -eq $retainedLocalTarget -or
            [int]$retainedLocalTarget.beat.denominator -ne 24) {
            throw "Replacement runtime did not expose a safe exact 1/24 Tap target."
        }
        $retainedLocalPlacement = [ordered]@{
            lane = [int]$retainedLocalTarget.lane
            candidateBeat = [double]$retainedLocalTarget.beat.value
            offset =
                [double]$retainedLocalTarget.beat.value -
                [double]$replacementLiveForPlacement.currentBeat
            source = "runtime-free-tap-target"
        }
        $retainedLocalPoint = Get-TimelinePoint `
            $replacementRuntime `
            ([int]$retainedLocalPlacement.lane) `
            ([double]$retainedLocalPlacement.offset) `
            $member.Process.Id `
            ([double]$replacementLiveForPlacement.pixelsPerBeat)
        Invoke-PhysicalClick `
            $retainedLocalPoint.x $retainedLocalPoint.y $memberHandle
        $clientRestartActions.Add("member-edit-restored-retained-tab-locally")
        $script:retainedLocalLive = $null
        Wait-Condition -Description "replacement retained local Note selected" `
            -Seconds 20 -PollMilliseconds 50 -Condition {
            $live = Get-TimelineLiveState $member.Process.Id
            if ([int]$live.selectedNoteCount -eq 1 -and
                -not $serverIdsAfterRestart.Contains([string]$live.selectedNoteId) -and
                [string]$live.selectedNoteBeat -match '/24$') {
                $script:retainedLocalLive = $live
                return $true
            }
            return $false
        }
        $retainedLocalLive = $script:retainedLocalLive
        $captures.memberRestartedRetainedEdited = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-restarted-retained-edited.png")

        Wait-HarnessState $endpoint {
            param($state)
            @($state.faults.chartOperationAttempts | Where-Object {
                    [string]$_.operationId -ceq $committedOperationId
                }).Count -eq 1 -and
            @($state.acceptedOperations | Where-Object {
                    [string]$_.operationId -ceq $committedOperationId
                }).Count -eq 1 -and
            @($state.faults.chartOperationResponseCompletions | Where-Object {
                    [string]$_.operationId -ceq $committedOperationId -and
                    [bool]$_.dropped
                }).Count -eq 1
        } "dropped response completed without a replacement-process retry" 30 | Out-Null

        $replacementCommunity = Open-Community $member
        $replacementCommunityHandle =
            [IntPtr]$replacementCommunity.Current.NativeWindowHandle
        $replacementRooms = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineCommunity.Navigation.Rooms" -TimeoutMilliseconds 15000
        Invoke-PhysicalElementClick $replacementRooms $replacementCommunityHandle
        $clientRestartActions.Add("replacement-open-rooms")
        $replacementJoin = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineRooms.Room.7654321.Join" -TimeoutMilliseconds 30000
        Invoke-PhysicalElementClick $replacementJoin $replacementCommunityHandle
        $clientRestartActions.Add("replacement-rejoin-public-room")
        try {
            $replacementJoinSubmit = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRooms.Join.Submit" -TimeoutMilliseconds 2500
            Invoke-PhysicalElementClick `
                $replacementJoinSubmit $replacementCommunityHandle
            $clientRestartActions.Add("replacement-confirm-public-room-rejoin")
        }
        catch {
            [void](Wait-HarnessState $endpoint {
                    param($state)
                    @($state.activeMemberIds) -contains 4202
                } "replacement direct public-room rejoin" 10)
        }
        $script:rejoinedState = $null
        Wait-Condition -Description "replacement room binding and snapshot recovery" `
            -Seconds 45 -PollMilliseconds 150 -Condition {
            try {
                $state = Get-HarnessState $endpoint
                $live = Get-TimelineLiveState $member.Process.Id
                if ([string]$live.roomSyncPendingOperationId -eq "none" -and
                    [string]$live.roomSyncWorkStatus -eq "Idle" -and
                    [string]$live.roomSyncFeedStatus -eq "Connected" -and
                    [long]$live.roomSyncRevision -eq [long]$state.revision) {
                    $script:rejoinedState = $state
                    return $true
                }
            }
            catch { }
            return $false
        }
        $rejoinedState = $script:rejoinedState
        try { Close-Community $member } catch { }
        $retainedBadgesAfterRejoin =
            @(Find-ElementsById -ProcessId $member.Process.Id `
                -AutomationId "Editor.ChartTab.RetainedBadge")
        $liveBadgesAfterRejoin =
            @(Find-ElementsById -ProcessId $member.Process.Id `
                -AutomationId "Editor.ChartTab.LiveBadge")
        $tabsAfterRejoin =
            @(Find-ElementsById -ProcessId $member.Process.Id `
                -AutomationId "Editor.ChartTab")
        if ($retainedBadgesAfterRejoin.Count -ne 1 -or
            $liveBadgesAfterRejoin.Count -ne 1 -or
            $tabsAfterRejoin.Count -ne 3) {
            throw "Rejoining did not preserve one retained tab beside one live tab."
        }

        $workspaceManifestPath =
            Join-Path $member.Editing "desktop-workspace\workspace.json"
        $script:replacementWorkspaceManifest = $null
        Wait-Condition -Description "replacement two-tab workspace manifest" `
            -Seconds 20 -Condition {
            if (-not (Test-Path -LiteralPath $workspaceManifestPath -PathType Leaf)) {
                return $false
            }
            $manifest =
                Get-Content -Raw -LiteralPath $workspaceManifestPath | ConvertFrom-Json
            if (@($manifest.Tabs).Count -eq 3) {
                $script:replacementWorkspaceManifest = $manifest
                return $true
            }
            return $false
        }
        $replacementWorkspaceManifest = $script:replacementWorkspaceManifest
        $activeWorkspaceTab = @($replacementWorkspaceManifest.Tabs | Where-Object {
                [string]$_.Id -ceq [string]$replacementWorkspaceManifest.ActiveTabId
            })[0]
        $liveMaterializedSource = [string]$activeWorkspaceTab.SourcePath
        $roomDocumentRoot = Join-Path $member.LocalData "online-room-documents"
        $preservedRetainedSource = @(
            $replacementWorkspaceManifest.Tabs | Where-Object {
                [string]$_.Id -cne [string]$replacementWorkspaceManifest.ActiveTabId -and
                [string]$_.SourcePath -ne [string]$member.InputChart -and
                [string]$_.SourcePath.StartsWith(
                    $roomDocumentRoot,
                    [StringComparison]::OrdinalIgnoreCase)
            } | ForEach-Object { [string]$_.SourcePath })[0]
        if ([string]::IsNullOrWhiteSpace($preservedRetainedSource) -or
            [string]::IsNullOrWhiteSpace($liveMaterializedSource) -or
            [IO.Path]::GetFullPath($preservedRetainedSource) -ceq
                [IO.Path]::GetFullPath($liveMaterializedSource) -or
            -not (Test-Path -LiteralPath $preservedRetainedSource -PathType Leaf)) {
            throw "The retained branch was not atomically saved before live rebind."
        }
        $captures.memberRejoinedWithRetainedAndLive = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-rejoined-with-retained-and-live.png")

        $paletteToggle = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickPalette.Toggle" -TimeoutMilliseconds 10000
        if ([string]$paletteToggle.Current.Name -ceq "+") {
            Invoke-PhysicalElementClick $paletteToggle $memberHandle
            $clientRestartActions.Add("replacement-expand-tools-for-selection")
        }
        $selectTool = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickTool.Select" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $selectTool $memberHandle
        $clientRestartActions.Add("replacement-select-tool-after-rejoin")
        $paletteToggle = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickPalette.Toggle" -TimeoutMilliseconds 10000
        if ([string]$paletteToggle.Current.Name -ceq "−") {
            Invoke-PhysicalElementClick $paletteToggle $memberHandle
            $clientRestartActions.Add("replacement-collapse-tools-before-server-note-selection")
        }
        $committedBeatValue =
            [double]$serverCommittedNote.beat.bar +
            [double]$serverCommittedNote.beat.numerator /
                [double]$serverCommittedNote.beat.denominator
        $maximumServerBeat = 4.0
        foreach ($note in @($serverCommittedSnapshot.notes)) {
            $head = [double]$note.beat.bar +
                [double]$note.beat.numerator / [double]$note.beat.denominator
            $maximumServerBeat = [Math]::Max($maximumServerBeat, $head)
            if ($null -ne $note.endBeat) {
                $tail = [double]$note.endBeat.bar +
                    [double]$note.endBeat.numerator / [double]$note.endBeat.denominator
                $maximumServerBeat = [Math]::Max($maximumServerBeat, $tail)
            }
        }
        $maximumServerBeat += 1.0
        $overview = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.Overview" -TimeoutMilliseconds 10000
        $overviewBounds = $overview.Current.BoundingRectangle
        if ($overviewBounds.Width -le 1 -or $overviewBounds.Height -le 1) {
            throw "Replacement density overview did not expose usable bounds."
        }
        $overviewSeekX = [int][Math]::Round(
            $overviewBounds.Left + $overviewBounds.Width / 2)
        $overviewSeekY = [int][Math]::Round(
            $overviewBounds.Bottom -
            [Math]::Clamp($committedBeatValue / $maximumServerBeat, 0.0, 1.0) *
                $overviewBounds.Height)
        Invoke-PhysicalClick $overviewSeekX $overviewSeekY $memberHandle
        $clientRestartActions.Add("replacement-seek-pre-exit-note-via-overview")
        Start-Sleep -Milliseconds 800
        $replacementLiveAfterRejoin = Get-TimelineLiveState $member.Process.Id
        if ([Math]::Abs(
                [double]$replacementLiveAfterRejoin.currentBeat -
                $committedBeatValue) -ge 1.0) {
            throw "Replacement overview seek did not expose the pre-exit committed Note."
        }
        $committedPointAfterRejoin = Get-TimelinePoint `
            $replacementRuntime `
            ([int]$serverCommittedNote.lane) `
            ($committedBeatValue - [double]$replacementLiveAfterRejoin.currentBeat) `
            $member.Process.Id `
            ([double]$replacementLiveAfterRejoin.pixelsPerBeat)
        Invoke-PhysicalClick `
            $committedPointAfterRejoin.x `
            $committedPointAfterRejoin.y `
            $memberHandle
        $clientRestartActions.Add("replacement-select-pre-exit-server-note")
        Wait-Condition -Description "replacement selected pre-exit committed Note" `
            -Seconds 20 -PollMilliseconds 50 -Condition {
            [string](Get-TimelineLiveState $member.Process.Id).selectedNoteId -ceq
                [string]$serverCommittedNote.id
        }
        $captures.memberRecoveredServerNote = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-recovered-server-note.png")

        Invoke-EditorSave $member
        [void](Wait-EditorSavedState $member.Process.Id 30)
        $retainedTabButton = @(
            Find-ElementsById -ProcessId $member.Process.Id `
                -AutomationId "Editor.ChartTab" | Where-Object {
                [string]$_.Current.Name -like "*房间留存*"
            })[0]
        $liveTabButton = @(
            Find-ElementsById -ProcessId $member.Process.Id `
                -AutomationId "Editor.ChartTab" | Where-Object {
                [string]$_.Current.Name -like "*联机*"
            })[0]
        if (-not $retainedTabButton -or -not $liveTabButton) {
            throw "The retained/live tab buttons were not independently addressable."
        }
        Invoke-PhysicalElementClick $retainedTabButton $memberHandle
        $clientRestartActions.Add("replacement-activate-retained-branch-for-save")
        Start-Sleep -Milliseconds 500
        Invoke-EditorSave $member
        [void](Wait-EditorSavedState $member.Process.Id 30)
        $captures.memberSavedRetainedBranch = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-saved-retained-branch.png")
        $liveTabButton = @(
            Find-ElementsById -ProcessId $member.Process.Id `
                -AutomationId "Editor.ChartTab" | Where-Object {
                [string]$_.Current.Name -like "*联机*"
            })[0]
        if (-not $liveTabButton) {
            throw "The live tab button disappeared after saving the retained branch."
        }
        Invoke-PhysicalElementClick $liveTabButton $memberHandle
        $clientRestartActions.Add("replacement-reactivate-live-branch")
        Start-Sleep -Milliseconds 500
        $retainedDocument =
            Get-Content -Raw -LiteralPath $preservedRetainedSource | ConvertFrom-Json
        $liveDocument =
            Get-Content -Raw -LiteralPath $liveMaterializedSource | ConvertFrom-Json
        $retainedPlayableNotes = @($retainedDocument.note | Where-Object {
                $null -ne $_.column
            })
        $livePlayableNotes = @($liveDocument.note | Where-Object {
                $null -ne $_.column
            })
        $localBeatMatch =
            [regex]::Match([string]$retainedLocalLive.selectedNoteBeat, '^(-?\d+):(\d+)/(\d+)$')
        if (-not $localBeatMatch.Success) {
            throw "The retained local Note did not expose a parseable exact Beat."
        }
        $localBar = [int]$localBeatMatch.Groups[1].Value
        $localNumerator = [int]$localBeatMatch.Groups[2].Value
        $localDenominator = [int]$localBeatMatch.Groups[3].Value
        $retainedHasLocal = @($retainedPlayableNotes | Where-Object {
                [int]$_.column -eq [int]$retainedLocalLive.selectedNoteLane -and
                [int]$_.beat[0] -eq $localBar -and
                [int]$_.beat[1] -eq $localNumerator -and
                [int]$_.beat[2] -eq $localDenominator
            }).Count -eq 1
        $retainedHasServer = @($retainedPlayableNotes | Where-Object {
                [int]$_.column -eq [int]$serverCommittedNote.lane -and
                [int]$_.beat[0] -eq [int]$serverCommittedNote.beat.bar -and
                [int]$_.beat[1] -eq [int]$serverCommittedNote.beat.numerator -and
                [int]$_.beat[2] -eq [int]$serverCommittedNote.beat.denominator
            }).Count -gt 0
        $liveHasServer = @($livePlayableNotes | Where-Object {
                [int]$_.column -eq [int]$serverCommittedNote.lane -and
                [int]$_.beat[0] -eq [int]$serverCommittedNote.beat.bar -and
                [int]$_.beat[1] -eq [int]$serverCommittedNote.beat.numerator -and
                [int]$_.beat[2] -eq [int]$serverCommittedNote.beat.denominator
            }).Count -eq 1
        $liveHasLocal = @($livePlayableNotes | Where-Object {
                [int]$_.column -eq [int]$retainedLocalLive.selectedNoteLane -and
                [int]$_.beat[0] -eq $localBar -and
                [int]$_.beat[1] -eq $localNumerator -and
                [int]$_.beat[2] -eq $localDenominator
            }).Count -gt 0
        if ($retainedPlayableNotes.Count -ne $baselineNoteCount + 1 -or
            $livePlayableNotes.Count -ne $baselineNoteCount + 1 -or
            -not $retainedHasLocal -or $retainedHasServer -or
            -not $liveHasServer -or $liveHasLocal) {
            throw "Retained and live MC branches were not structurally independent after rejoin."
        }

        $stateBeforeGracefulClose = Get-HarnessState $endpoint
        $operationAttempts = @(
            $stateBeforeGracefulClose.faults.chartOperationAttempts | Where-Object {
                [string]$_.operationId -ceq $committedOperationId
            })
        $acceptedOperations = @(
            $stateBeforeGracefulClose.acceptedOperations | Where-Object {
                [string]$_.operationId -ceq $committedOperationId
            })
        if ($operationAttempts.Count -ne 1 -or
            $acceptedOperations.Count -ne 1 -or
            @($stateBeforeGracefulClose.activeMemberIds) -notcontains 4202) {
            throw "Client restart exactly-once or active-membership gates failed."
        }
        $titleClose = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Title.Close" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $titleClose $memberHandle
        $clientRestartActions.Add("replacement-normal-window-close")
        if (-not $member.Process.WaitForExit(20000)) {
            throw "The replacement member did not complete normal shutdown."
        }
        $replacementExitCode = $member.Process.ExitCode
        $stateAfterGracefulClose = Wait-HarnessState $endpoint {
            param($state)
            @($state.activeMemberIds) -notcontains 4202
        } "normal client shutdown leaves the room" 20
        $gracefulCloseAt = [DateTimeOffset]::UtcNow

        $fixtureHashAfter =
            (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
        if ($fixtureHashBefore -cne $fixtureHashAfter) {
            throw "The frozen real MC changed during client restart recovery."
        }
        $screenshots = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
            $screenshots[$file.BaseName] = [ordered]@{
                path = $file.FullName
                length = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        $clientRestartEvidence = [ordered]@{
            schema = "lumachart.windows.avalonia.two-client-client-restart-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = if ($FormalMigrationAuthority) {
                "passed-migration-incomplete"
            } else {
                "preflight-passed-nonformal"
            }
            formalMigrationAuthority = [bool]$FormalMigrationAuthority
            completion = $false
            migrationComplete = $false
            windowsAvaloniaOnly = $true
            productionServerMutationPerformed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            clientRestartOnly = $true
            physicalMouseInputUsed = $true
            enterKeyUsed = $false
            endpoint = $endpoint
            processRestart = [ordered]@{
                firstMemberProcessId = $firstMemberProcessId
                firstMemberExitCode = $firstMemberExitCode
                replacementMemberProcessId = $replacementMemberProcessId
                distinctProcessIds =
                    $firstMemberProcessId -ne $replacementMemberProcessId
                abruptExitUtc = $abruptExitAt.ToString("O")
                tokenRestoredWithoutReseeding = $true
                retainedBadge = Observe-Element $retainedBadge
                totalTabCountBeforeRejoin = $tabsBeforeRejoin.Count
                retainedTabCountBeforeRejoin = $retainedBadgesBeforeRejoin.Count
                liveTabCountBeforeRejoin = $liveBadgesBeforeRejoin.Count
            }
            committedBeforeExit = [ordered]@{
                operationId = $committedOperationId
                noteId = [string]$serverCommittedNote.id
                lane = [int]$serverCommittedNote.lane
                beat = $committedServerBeat
                denominator = [int]$serverCommittedNote.beat.denominator
                operationAttempts = $operationAttempts
                acceptedCount = $acceptedOperations.Count
                responseWasPendingAtExit = $true
                exactlyOnceAfterReplacement = $operationAttempts.Count -eq 1 -and
                    $acceptedOperations.Count -eq 1
                preKillServerState = $preKillState
            }
            retainedLocalBranch = [ordered]@{
                noteId = [string]$retainedLocalLive.selectedNoteId
                lane = [int]$retainedLocalLive.selectedNoteLane
                beat = [string]$retainedLocalLive.selectedNoteBeat
                source = $preservedRetainedSource
                playableNoteCount = $retainedPlayableNotes.Count
                containsLocalOnly = $retainedHasLocal -and -not $retainedHasServer
            }
            liveRecoveredBranch = [ordered]@{
                source = $liveMaterializedSource
                playableNoteCount = $livePlayableNotes.Count
                containsCommittedOnly = $liveHasServer -and -not $liveHasLocal
                selectedCommittedNoteAfterRejoin = $true
                retainedBadgeCount = $retainedBadgesAfterRejoin.Count
                liveBadgeCount = $liveBadgesAfterRejoin.Count
                tabCount = $tabsAfterRejoin.Count
                rejoinedServerState = $rejoinedState
            }
            normalShutdown = [ordered]@{
                replacementExitCode = $replacementExitCode
                closedUtc = $gracefulCloseAt.ToString("O")
                memberActiveBeforeClose =
                    @($stateBeforeGracefulClose.activeMemberIds) -contains 4202
                memberActiveAfterClose =
                    @($stateAfterGracefulClose.activeMemberIds) -contains 4202
                gracefulLeavePassed =
                    @($stateAfterGracefulClose.activeMemberIds) -notcontains 4202
            }
            paths = [ordered]@{
                projectRoot = $projectRoot
                outputRoot = $outputFullPath
                application = $applicationFullPath
                serverAssembly = $serverAssemblyFullPath
                fixture = $fixtureFullPath
                materializedChart = $memberRoomChartPath
                retainedChart = $preservedRetainedSource
                workspaceManifest = $workspaceManifestPath
                temp = $projectTemp
                dotnetHome = $dotnetHome
                nugetPackages = $nugetPackages
                nugetHttpCache = $nugetHttpCache
            }
            hashes = [ordered]@{
                application =
                    (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
                applicationAssembly =
                    (Get-FileHash `
                        -LiteralPath ([IO.Path]::ChangeExtension($applicationFullPath, ".dll")) `
                        -Algorithm SHA256).Hash
                serverAssembly =
                    (Get-FileHash -LiteralPath $serverAssemblyFullPath -Algorithm SHA256).Hash
                fixtureBefore = $fixtureHashBefore
                fixtureAfter = $fixtureHashAfter
                materializedBefore = $materializedHashBefore
                materializedLiveAfter =
                    (Get-FileHash -LiteralPath $liveMaterializedSource -Algorithm SHA256).Hash
                retainedAfter =
                    (Get-FileHash -LiteralPath $preservedRetainedSource -Algorithm SHA256).Hash
            }
            baselineNoteCount = $baselineNoteCount
            finalServerState = $stateAfterGracefulClose
            physicalActions = $clientRestartActions.ToArray()
            captures = $captures
            screenshots = $screenshots
            passed = $true
        }
        $clientRestartEvidencePath = Join-Path $outputFullPath "evidence.json"
        $clientRestartEvidence | ConvertTo-Json -Depth 80 |
            Set-Content -LiteralPath $clientRestartEvidencePath -Encoding utf8NoBOM
        Write-Output "Windows Avalonia live client restart GUI capture: passed"
        Write-Output "Evidence: $clientRestartEvidencePath"
        return
    }

    if ($ResilienceOnly) {
        $afterSseRecovery = Wait-HarnessState $endpoint {
            param($state)
            [int]$state.faults.injectedSseDisconnectCount -eq 2 -and
            [int]$state.faults.pendingSseDisconnects -eq 0 -and
            [int]$state.sseConnectionCount -ge 4
        } "member SSE reconnect after two injected disconnects"
        [void](Set-HarnessFaults $endpoint @{
                failNextChartDeltaRequests = 2
                malformedNextChartDeltaResponses = 2
                disconnectNextSseConnections = 0
                dropNextChartOperationResponsesAfterCommit = 1
                delayNextChartOperationResponseMilliseconds = 0
            })
        $ownerStatus = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        $memberStatus = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        $afterDeltaFailures = Wait-HarnessState $endpoint {
            param($state)
            [int]$state.faults.injectedChartDeltaFailureCount -eq 2 -and
            [int]$state.faults.pendingChartDeltaFailures -eq 0 -and
            [int]$state.faults.injectedMalformedChartDeltaResponseCount -eq 2 -and
            [int]$state.faults.pendingMalformedChartDeltaResponses -eq 0
        } "two HTTP 503 and two malformed successful chart delta responses"
        Wait-Condition -Description "visible room chart retry status" -Seconds 12 -Condition {
            [string]$ownerStatus.Current.Name -like "*重试*" -or
            [string]$memberStatus.Current.Name -like "*重试*"
        }
        $observations.ownerDeltaRetryStatus = Observe-Element $ownerStatus
        $observations.memberDeltaRetryStatus = Observe-Element $memberStatus
        $captures.ownerDeltaRetry = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-delta-retry.png")
        $captures.memberDeltaRetry = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-delta-retry.png")
        Wait-Condition -Description "room chart recovery status after injected delta failures" `
            -Seconds 20 -Condition {
                [string]$ownerStatus.Current.Name -like "*已同步*" -and
                [string]$memberStatus.Current.Name -like "*已同步*"
            }
        $observations.ownerDeltaRecoveredStatus = Observe-Element $ownerStatus
        $observations.memberDeltaRecoveredStatus = Observe-Element $memberStatus
        $resilienceEvidence = [ordered]@{
            sse = [ordered]@{
                injectedDisconnectCount = [int]$afterSseRecovery.faults.injectedSseDisconnectCount
                connectionCountAfterRecovery = [int]$afterSseRecovery.sseConnectionCount
                visibleReconnectStatus = $observations.memberSseReconnectStatus
            }
            delta = [ordered]@{
                injectedFailureCount = [int]$afterDeltaFailures.faults.injectedChartDeltaFailureCount
                injectedMalformedResponseCount =
                    [int]$afterDeltaFailures.faults.injectedMalformedChartDeltaResponseCount
                ownerRetryStatus = $observations.ownerDeltaRetryStatus
                memberRetryStatus = $observations.memberDeltaRetryStatus
                ownerRecoveredStatus = $observations.ownerDeltaRecoveredStatus
                memberRecoveredStatus = $observations.memberDeltaRecoveredStatus
            }
            ackLoss = $null
        }
    }

    $selected = @($ownerRuntime.timeline.selectedNotes)[0]
    if (-not $selected) { throw "Owner runtime did not expose a selected real Note." }
    $selectedId = [string]$selected.noteId
    Wait-File $member.RoomRuntime "member room-tab GUI runtime evidence" 95
    $memberRoomRuntime = Get-Content -Raw -LiteralPath $member.RoomRuntime | ConvertFrom-Json
    $memberRoomChartPath = [string]$memberRoomRuntime.chart.sourcePath
    if (-not $memberRoomChartPath.StartsWith($member.LocalData, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Member room evidence did not capture the downloaded/materialized MC tab."
    }

    if ($ApplicationCloseRetentionOnly) {
        $applicationCloseActions = [Collections.Generic.List[string]]::new()
        try { Close-Community $owner } catch { }
        try { Close-Community $member } catch { }
        $ownerStatus = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        $memberStatus = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        $initialCloseRevision = [long](Get-HarnessState $endpoint).revision
        Wait-Condition -Description "both clients structurally synchronized before application close" `
            -Seconds 30 -Condition {
                [long](Get-TimelineLiveState $owner.Process.Id).roomSyncRevision -ge
                    $initialCloseRevision -and
                [long](Get-TimelineLiveState $member.Process.Id).roomSyncRevision -ge
                    $initialCloseRevision
            }

        # Joining and synchronizing a room does not itself make the source tab
        # dirty. Exercise one real owner Note edit so the main-window close
        # deterministically traverses the WPF prompt order:
        # unsaved source decision, then live-room exit decision.
        $ownerNoteTab = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Inspector.NoteTab" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerNoteTab $ownerHandle
        $ownerNoteVolume = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Inspector.Note.Volume" -TimeoutMilliseconds 10000
        $ownerVolumeBeforeClose = [int](Get-ElementValue $ownerNoteVolume)
        $ownerVolumeAfterCloseEdit = if ($ownerVolumeBeforeClose -eq 99) { 98 } else { 99 }
        Set-ElementValue $ownerNoteVolume $ownerVolumeAfterCloseEdit
        $ownerNoteApply = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Inspector.Note.Apply" -TimeoutMilliseconds 10000
        Invoke-Element $ownerNoteApply
        $applicationCloseActions.Add("owner-uia-apply-note-volume-before-application-close")
        $stateAfterDirtyEdit = Wait-HarnessState $endpoint {
            param($state)
            @($state.acceptedOperations | Where-Object {
                    [long]$_.actorUserId -eq 4101 -and
                    @($_.upsertNotes | Where-Object {
                            [string]$_.id -ceq $selectedId -and
                            [int]$_.volume -eq $ownerVolumeAfterCloseEdit
                        }).Count -eq 1
                }).Count -eq 1
        } "owner Note edit before application close"
        $dirtyCloseRevision = [long]$stateAfterDirtyEdit.revision
        Wait-Condition -Description "both clients structurally synchronized after dirty close preparation" `
            -Seconds 30 -Condition {
                [long](Get-TimelineLiveState $owner.Process.Id).roomSyncRevision -ge
                    $dirtyCloseRevision -and
                [long](Get-TimelineLiveState $member.Process.Id).roomSyncRevision -ge
                    $dirtyCloseRevision
            }
        Wait-Condition -Description "owner source tab marked unsaved before application close" `
            -Seconds 15 -Condition {
                $owner.Process.Refresh()
                [string]$owner.Process.MainWindowTitle -match '\*'
            }

        $fixtureHashBefore =
            (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
        $ownerInputHashBefore =
            (Get-FileHash -LiteralPath $owner.InputChart -Algorithm SHA256).Hash
        $memberMaterializedHashBefore =
            (Get-FileHash -LiteralPath $memberRoomChartPath -Algorithm SHA256).Hash
        $stateBeforeClose = Get-HarnessState $endpoint
        if (-not [bool]$stateBeforeClose.roomCreated -or
            @($stateBeforeClose.activeMemberIds).Count -ne 2 -or
            [int]$stateBeforeClose.ownerCloseCount -ne 0) {
            throw "Application-close retention gate did not begin with one active two-client room."
        }
        $roomName = [string]$stateBeforeClose.room.name
        $roomNumber = [long]$stateBeforeClose.room.roomNumber
        $expectedExitMessage =
            '你是“{0}”的房主。关闭后其他成员会离开；当前谱面不会关闭，并将恢复为本地编辑。' -f
                $roomName
        $captures.ownerBeforeApplicationClose = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-before-application-close.png")
        $captures.memberBeforeOwnerApplicationClose = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-before-owner-application-close.png")

        $ownerTitleClose = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Title.Close" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerTitleClose $ownerHandle
        $applicationCloseActions.Add("owner-physically-click-main-window-close-for-cancel")
        $unsavedDialog = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "UnsavedChanges.Dialog" -TimeoutMilliseconds 15000
        $unsavedDialogHandle = [IntPtr]$unsavedDialog.Current.NativeWindowHandle
        if ($unsavedDialogHandle -eq [IntPtr]::Zero) {
            $unsavedDialogHandle = $ownerHandle
        }
        $unsavedDiscard = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "UnsavedChanges.Discard"
        if ([string]$unsavedDialog.Current.Name -cne "未保存的更改" -or
            [string]$unsavedDiscard.Current.Name -cne "放弃更改") {
            throw "Application close did not present the WPF unsaved prompt before room exit."
        }
        $observations.applicationCloseUnsavedDialog = Observe-Element $unsavedDialog
        $observations.applicationCloseUnsavedDiscard = Observe-Element $unsavedDiscard
        $captures.ownerApplicationCloseUnsavedPrompt = Capture-Window $unsavedDialogHandle `
            (Join-Path $outputFullPath "owner-application-close-unsaved-prompt.png")
        Invoke-PhysicalElementClick $unsavedDiscard $unsavedDialogHandle
        $applicationCloseActions.Add("owner-physically-discard-source-save-before-room-exit-cancel")
        $exitDialog = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.ExitDialog" -TimeoutMilliseconds 15000
        $exitDialogHandle = [IntPtr]$exitDialog.Current.NativeWindowHandle
        if ($exitDialogHandle -eq [IntPtr]::Zero) { $exitDialogHandle = $ownerHandle }
        $exitMessage = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.ExitDialog.Message"
        $exitCancel = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.ExitDialog.Cancel"
        $exitConfirm = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.ExitDialog.Confirm"
        $observations.applicationCloseDialog = Observe-Element $exitDialog
        $observations.applicationCloseDialogMessage = Observe-Element $exitMessage
        $observations.applicationCloseCancel = Observe-Element $exitCancel
        $observations.applicationCloseConfirm = Observe-Element $exitConfirm
        if ([string]$exitDialog.Current.Name -cne "关闭联机房间" -or
            [string]$exitMessage.Current.Name -cne $expectedExitMessage -or
            [string]$exitCancel.Current.Name -cne "取消" -or
            [string]$exitConfirm.Current.Name -cne "关闭房间" -or
            [string]$exitCancel.Current.HelpText -notlike "*默认=True*取消=True*") {
            throw "The main-window room-exit confirmation did not match WPF 1.1.0 copy or safe defaults."
        }
        $captures.ownerApplicationCloseConfirmation = Capture-Window $exitDialogHandle `
            (Join-Path $outputFullPath "owner-application-close-confirmation.png")

        Invoke-PhysicalElementClick $exitCancel $exitDialogHandle
        $applicationCloseActions.Add("owner-physically-cancel-main-window-close")
        Wait-Condition -Description "application close cancellation keeps owner running" `
            -Seconds 10 -Condition {
                if ($owner.Process.HasExited) { return $false }
                try {
                    [void](Find-ElementById -ProcessId $owner.Process.Id `
                        -AutomationId "OnlineRooms.ExitDialog" -TimeoutMilliseconds 250)
                    return $false
                }
                catch { return $true }
            }
        $stateAfterCancel = Get-HarnessState $endpoint
        if (-not [bool]$stateAfterCancel.roomCreated -or
            [int]$stateAfterCancel.ownerCloseCount -ne 0 -or
            @($stateAfterCancel.activeMemberIds).Count -ne 2) {
            throw "Cancelling the main-window close changed live room state."
        }

        $ownerTitleClose = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Title.Close" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerTitleClose $ownerHandle
        $applicationCloseActions.Add("owner-physically-click-main-window-close-for-confirm")
        $unsavedDialog = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "UnsavedChanges.Dialog" -TimeoutMilliseconds 15000
        $unsavedDialogHandle = [IntPtr]$unsavedDialog.Current.NativeWindowHandle
        if ($unsavedDialogHandle -eq [IntPtr]::Zero) {
            $unsavedDialogHandle = $ownerHandle
        }
        $unsavedDiscard = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "UnsavedChanges.Discard"
        Invoke-PhysicalElementClick $unsavedDiscard $unsavedDialogHandle
        $applicationCloseActions.Add("owner-physically-discard-source-save-before-room-exit-confirm")
        $exitDialog = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.ExitDialog" -TimeoutMilliseconds 15000
        $exitDialogHandle = [IntPtr]$exitDialog.Current.NativeWindowHandle
        if ($exitDialogHandle -eq [IntPtr]::Zero) { $exitDialogHandle = $ownerHandle }
        $exitConfirm = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.ExitDialog.Confirm"
        Invoke-PhysicalElementClick $exitConfirm $exitDialogHandle
        $applicationCloseActions.Add("owner-physically-confirm-main-window-room-close")
        if (-not $owner.Process.WaitForExit(45000)) {
            throw "Owner application did not exit after confirmed room close."
        }
        $ownerFirstProcessId = $owner.Process.Id
        $ownerFirstExitCode = $owner.Process.ExitCode
        if ($ownerFirstExitCode -ne 0) {
            throw "Owner application exited with code $ownerFirstExitCode after confirmed room close."
        }
        $stateAfterConfirmedClose = Wait-HarnessState $endpoint {
            param($state)
            -not [bool]$state.roomCreated -and
            [int]$state.ownerCloseCount -eq 1 -and
            @($state.activeMemberIds).Count -eq 0 -and
            @($state.roomLifecycleEvents | Where-Object {
                    [string]$_.action -ceq "owner-closed"
                }).Count -eq 1
        } "confirmed application close ends room and evicts members"

        $memberRetainedTab = Find-ElementByIdAndNameLike `
            -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab" `
            -Like "*房间留存*" `
            -TimeoutMilliseconds 40000
        $memberRetainedBadge = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab.RetainedBadge" -TimeoutMilliseconds 10000
        $observations.memberRetainedTabAfterOwnerApplicationClose =
            Observe-Element $memberRetainedTab
        $observations.memberRetainedBadgeAfterOwnerApplicationClose =
            Observe-Element $memberRetainedBadge
        $captures.memberRetainedAfterOwnerApplicationClose = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-retained-after-owner-application-close.png")

        $ownerWorkspacePath =
            Join-Path $owner.Editing "desktop-workspace\workspace.json"
        $script:applicationCloseWorkspaceResult = $null
        Wait-Condition -Description "owner retained-room workspace persisted before restart" `
            -Seconds 20 -Condition {
                if (-not (Test-Path -LiteralPath $ownerWorkspacePath -PathType Leaf)) {
                    return $false
                }
                try {
                    $manifest =
                        Get-Content -Raw -LiteralPath $ownerWorkspacePath |
                            ConvertFrom-Json
                    $retained = @($manifest.Tabs | Where-Object {
                            [bool]$_.IsPreservedRoomDraft
                        })
                    if ($retained.Count -eq 1 -and
                        [long]$retained[0].PreservedRoomNumber -eq $roomNumber -and
                        [string]$retained[0].PreservedRoomName -ceq $roomName -and
                        $null -ne $retained[0].PreservedRoomEndedUtc) {
                        $script:applicationCloseWorkspaceResult = $manifest
                        return $true
                    }
                }
                catch { }
                return $false
            }
        $ownerWorkspaceBeforeRestart = $script:applicationCloseWorkspaceResult
        $script:applicationCloseWorkspaceResult = $null
        $ownerRetainedManifestTab = @(
            $ownerWorkspaceBeforeRestart.Tabs | Where-Object {
                [bool]$_.IsPreservedRoomDraft
            })[0]
        $ownerWorkingPath = Join-Path `
            (Join-Path `
                (Join-Path $owner.Editing "desktop-workspace\documents") `
                ([string]$ownerRetainedManifestTab.CacheDirectoryName)) `
            "working.mc"
        if (-not (Test-Path -LiteralPath $ownerWorkingPath -PathType Leaf)) {
            throw "Confirmed application close did not atomically persist the retained working MC."
        }
        $ownerRetainedDocument =
            Get-Content -Raw -LiteralPath $ownerWorkingPath | ConvertFrom-Json
        $ownerRetainedNoteCount = @($ownerRetainedDocument.note | Where-Object {
                $null -ne $_.column
            }).Count
        if ($ownerRetainedNoteCount -ne 2753) {
            throw "Retained owner working MC did not preserve the real 2,753-Note room snapshot."
        }

        $ownerFirst = $owner
        $ownerFirst.Process.Dispose()
        $owner = Start-Client `
            -Name "owner-a" `
            -Token ([string]$ready.ownerToken) `
            -Profile "windows-avalonia-online-owner" `
            -Endpoint $endpoint `
            -FollowRoomEvidence $false `
            -ReuseExistingRoots $true `
            -Generation 2 `
            -RestoreWorkspaceOnly $true
        $ownerHandle = [IntPtr](Wait-MainWindowHandle $owner.Process)
        [void](Wait-AuthenticatedAccountButton $owner.Process.Id "房主" 30)
        $ownerRestoredRetainedTab = Find-ElementByIdAndNameLike `
            -ProcessId $owner.Process.Id `
            -AutomationId "Editor.ChartTab" `
            -Like "*房间留存*" `
            -TimeoutMilliseconds 40000
        $ownerRestoredRetainedBadge = Find-ElementById `
            -ProcessId $owner.Process.Id `
            -AutomationId "Editor.ChartTab.RetainedBadge" `
            -TimeoutMilliseconds 10000
        $ownerLiveBadgesAfterRestart = @(
            Find-ElementsById -ProcessId $owner.Process.Id `
                -AutomationId "Editor.ChartTab.LiveBadge")
        if ($ownerLiveBadgesAfterRestart.Count -ne 0) {
            throw "Restored owner room draft incorrectly rebound as a live room tab."
        }
        $observations.ownerRetainedTabAfterRestart =
            Observe-Element $ownerRestoredRetainedTab
        $observations.ownerRetainedBadgeAfterRestart =
            Observe-Element $ownerRestoredRetainedBadge
        $captures.ownerRetainedTabVisibleAfterApplicationRestart = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-retained-after-application-restart.png")
        $ownerRetainedTabInvokeFallbackUsed = $false
        Invoke-PhysicalElementClick $ownerRestoredRetainedTab $ownerHandle
        $applicationCloseActions.Add("owner-physically-open-restored-retained-tab-after-restart")
        try {
            [void](Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "Timeline.Surface" -TimeoutMilliseconds 3000)
        }
        catch {
            Invoke-Element $ownerRestoredRetainedTab
            $ownerRetainedTabInvokeFallbackUsed = $true
            $applicationCloseActions.Add("owner-uia-open-restored-retained-tab-fallback")
            [void](Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "Timeline.Surface" -TimeoutMilliseconds 20000)
        }
        $ownerRestoredTimeline = Get-TimelineLiveState $owner.Process.Id
        $ownerRestoredStatus = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        $observations.ownerRestoredRetainedEditorStatus =
            Observe-Element $ownerRestoredStatus
        $captures.ownerRetainedEditorAfterApplicationRestart = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-retained-editor-after-application-restart.png")

        $ownerWorkspaceAfterRestart =
            Get-Content -Raw -LiteralPath $ownerWorkspacePath | ConvertFrom-Json
        $ownerRetainedAfterRestart = @(
            $ownerWorkspaceAfterRestart.Tabs | Where-Object {
                [bool]$_.IsPreservedRoomDraft -and
                [long]$_.PreservedRoomNumber -eq $roomNumber -and
                [string]$_.PreservedRoomName -ceq $roomName
            })
        $fixtureHashAfter =
            (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
        $ownerInputHashAfter =
            (Get-FileHash -LiteralPath $owner.InputChart -Algorithm SHA256).Hash
        $memberMaterializedHashAfter =
            (Get-FileHash -LiteralPath $memberRoomChartPath -Algorithm SHA256).Hash
        if ($fixtureHashBefore -cne $fixtureHashAfter -or
            $ownerInputHashBefore -cne $ownerInputHashAfter -or
            $memberMaterializedHashBefore -cne $memberMaterializedHashAfter -or
            $ownerRetainedAfterRestart.Count -ne 1) {
            throw "Application-close retention changed source files or lost persisted room metadata."
        }

        $screenshots = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
            $screenshots[$file.BaseName] = [ordered]@{
                path = $file.FullName
                length = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        $finalState = Get-HarnessState $endpoint
        $applicationCloseEvidence = [ordered]@{
            schema =
                "lumachart.windows.avalonia.application-close-room-retention-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = if ($FormalMigrationAuthority) {
                "passed-migration-incomplete"
            } else {
                "preflight-passed-nonformal"
            }
            formalMigrationAuthority = [bool]$FormalMigrationAuthority
            completion = $false
            migrationComplete = $false
            windowsAvaloniaOnly = $true
            productionServerMutationPerformed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            applicationCloseRetentionOnly = $true
            automationDiagnosticNonFormal = $false
            physicalMouseInputUsed = $true
            chineseImeGlobalEnterEscapeHandlerAdded = $false
            endpoint = $endpoint
            processIds = [ordered]@{
                server = $server.Id
                ownerFirst = $ownerFirstProcessId
                ownerRestarted = $owner.Process.Id
                member = $member.Process.Id
            }
            room = [ordered]@{
                roomNumber = $roomNumber
                roomName = $roomName
                ownerCloseCount = [int]$finalState.ownerCloseCount
                activeMemberIds = @($finalState.activeMemberIds)
                lifecycleEvents = $finalState.roomLifecycleEvents
            }
            confirmation = [ordered]@{
                promptOrder = @(
                    "UnsavedChanges.Dialog",
                    "OnlineRooms.ExitDialog"
                )
                dirtyPreparation = [ordered]@{
                    selectedNoteId = $selectedId
                    volumeBefore = $ownerVolumeBeforeClose
                    volumeAfter = $ownerVolumeAfterCloseEdit
                    acceptedOperationCount =
                        @($stateAfterDirtyEdit.acceptedOperations | Where-Object {
                                [long]$_.actorUserId -eq 4101
                            }).Count
                    sourceTabMarkedUnsaved = $true
                }
                sourceSaveDiscardedBeforeRoomRetention = $true
                memberResourceEntryPhysicalAttempts =
                    $memberResourcePhysicalAttemptCount
                memberResourceEntryUiaFallbackUsed =
                    $memberResourceApplicationCloseFallbackUsed
                title = [string]$observations.applicationCloseDialog.name
                message = [string]$observations.applicationCloseDialogMessage.name
                expectedMessage = $expectedExitMessage
                cancelSafeDefault =
                    [string]$observations.applicationCloseCancel.helpText -like
                        "*默认=True*取消=True*"
                firstAttemptCancelledWithoutMutation =
                    [bool]$stateAfterCancel.roomCreated -and
                    [int]$stateAfterCancel.ownerCloseCount -eq 0 -and
                    @($stateAfterCancel.activeMemberIds).Count -eq 2
                confirmedOwnerExitCode = $ownerFirstExitCode
            }
            retention = [ordered]@{
                memberRetainedTab =
                    $observations.memberRetainedTabAfterOwnerApplicationClose
                ownerRestoredRetainedTab =
                    $observations.ownerRetainedTabAfterRestart
                ownerRestoredLiveBadgeCount = $ownerLiveBadgesAfterRestart.Count
                workspaceManifest = $ownerWorkspacePath
                retainedWorkingChart = $ownerWorkingPath
                retainedPlayableNoteCount = $ownerRetainedNoteCount
                restoredTabPhysicalClickAttempted = $true
                restoredTabUiaFallbackUsed =
                    $ownerRetainedTabInvokeFallbackUsed
                restoredTimeline = $ownerRestoredTimeline
                restoredEditorStatus =
                    $observations.ownerRestoredRetainedEditorStatus
                manifestBeforeRestart = $ownerWorkspaceBeforeRestart
                manifestAfterRestart = $ownerWorkspaceAfterRestart
            }
            paths = [ordered]@{
                projectRoot = $projectRoot
                outputRoot = $outputFullPath
                application = $applicationFullPath
                serverAssembly = $serverAssemblyFullPath
                fixture = $fixtureFullPath
                ownerInputChart = $owner.InputChart
                memberMaterializedChart = $memberRoomChartPath
                ownerWorkspace = $ownerWorkspacePath
                ownerRetainedWorkingChart = $ownerWorkingPath
                temp = $projectTemp
                dotnetHome = $dotnetHome
                nugetPackages = $nugetPackages
                nugetHttpCache = $nugetHttpCache
            }
            hashes = [ordered]@{
                application =
                    (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
                applicationAssembly =
                    (Get-FileHash `
                        -LiteralPath ([IO.Path]::ChangeExtension($applicationFullPath, ".dll")) `
                        -Algorithm SHA256).Hash
                serverAssembly =
                    (Get-FileHash -LiteralPath $serverAssemblyFullPath -Algorithm SHA256).Hash
                fixtureBefore = $fixtureHashBefore
                fixtureAfter = $fixtureHashAfter
                ownerInputBefore = $ownerInputHashBefore
                ownerInputAfter = $ownerInputHashAfter
                memberMaterializedBefore = $memberMaterializedHashBefore
                memberMaterializedAfter = $memberMaterializedHashAfter
                retainedWorkingChart =
                    (Get-FileHash -LiteralPath $ownerWorkingPath -Algorithm SHA256).Hash
            }
            physicalActions = $applicationCloseActions.ToArray()
            controls = $observations
            captures = $captures
            screenshots = $screenshots
            finalServerState = $finalState
            passed = $true
        }
        $applicationCloseEvidencePath = Join-Path $outputFullPath "evidence.json"
        $applicationCloseEvidence | ConvertTo-Json -Depth 80 |
            Set-Content -LiteralPath $applicationCloseEvidencePath -Encoding utf8NoBOM
        Write-Output "Windows Avalonia application-close room retention GUI capture: passed"
        Write-Output "Evidence: $applicationCloseEvidencePath"
        return
    }

    if ($CreatorMarkerOnly) {
        $creatorPhysicalActions = [Collections.Generic.List[string]]::new()
        $fixtureHashBefore = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
        $ownerStatus = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        $memberStatus = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        Wait-Condition -Description "both clients synchronized before creator-marker gate" `
            -Seconds 30 -Condition {
                [string]$ownerStatus.Current.Name -like "*已同步*" -and
                [string]$memberStatus.Current.Name -like "*已同步*"
            }

        $baselineSnapshot = Get-ChartSnapshot $endpoint $member.Token
        $baselineNoteCount = @($baselineSnapshot.notes).Count
        $baselineTimingCount = @($baselineSnapshot.timing).Count
        if (@($baselineSnapshot.notes | Where-Object { [long]$_.creatorUserId -ne 4101 }).Count -ne 0 -or
            @($baselineSnapshot.timing | Where-Object { [long]$_.creatorUserId -ne 4101 }).Count -ne 0) {
            throw "The initialized real chart did not attribute every Note/Timing row to the owner."
        }

        $script:creatorOwnerReadyResult = $null
        $script:creatorMemberReadyResult = $null
        Wait-Condition -Description "both timelines preload two creator avatars" -Seconds 30 -Condition {
            $ownerLive = Get-TimelineLiveState $owner.Process.Id
            $memberLive = Get-TimelineLiveState $member.Process.Id
            if ([int]$ownerLive.onlineCreatorCount -eq 2 -and
                [int]$memberLive.onlineCreatorCount -eq 2 -and
                [int]$ownerLive.onlineCreatorAvatarCount -eq 2 -and
                [int]$memberLive.onlineCreatorAvatarCount -eq 2 -and
                [int]$ownerLive.creatorAttributedNoteCount -eq $baselineNoteCount -and
                [int]$memberLive.creatorAttributedNoteCount -eq $baselineNoteCount -and
                [int]$ownerLive.creatorAttributedTimingCount -eq $baselineTimingCount -and
                [int]$memberLive.creatorAttributedTimingCount -eq $baselineTimingCount) {
                $script:creatorOwnerReadyResult = $ownerLive
                $script:creatorMemberReadyResult = $memberLive
                return $true
            }
            return $false
        }
        $ownerCreatorReady = $script:creatorOwnerReadyResult
        $memberCreatorReady = $script:creatorMemberReadyResult
        $script:creatorOwnerReadyResult = $null
        $script:creatorMemberReadyResult = $null
        $avatarStateBeforePlacement = Wait-HarnessState $endpoint {
            param($state)
            [int]$state.avatarDownloadCount -ge 4 -and
            @($state.avatarDownloadKeys | Where-Object { $_ -ceq "owner-avatar-v1" }).Count -ge 2 -and
            @($state.avatarDownloadKeys | Where-Object { $_ -ceq "member-avatar-v1" }).Count -ge 2
        } "two clients download both creator avatars"

        $placement = Find-FreeTimelineTapPlacement `
            -Notes @($baselineSnapshot.notes) `
            -CurrentBeat ([double]$memberCreatorReady.currentBeat) `
            -PreferredLanes @(0, 1, 2, 3) `
            -Offsets @(.5, .75, 1, 1.25, 1.5, -.5, -.75, -1) `
            -MinimumClearanceBeats .24
        $memberTapTool = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickTool.Tap" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberTapTool $memberHandle
        $creatorPhysicalActions.Add("member-physically-select-tap-tool")
        $memberPlacementPoint = Get-TimelinePoint `
            $memberRoomRuntime `
            ([int]$placement.lane) `
            ([double]$placement.offset) `
            $member.Process.Id `
            ([double]$memberCreatorReady.pixelsPerBeat)
        Invoke-PhysicalClick `
            ([int]$memberPlacementPoint.x) `
            ([int]$memberPlacementPoint.y) `
            $memberHandle
        $creatorPhysicalActions.Add("member-physically-place-attributed-tap")

        $knownNoteIds = @{}
        foreach ($note in @($baselineSnapshot.notes)) { $knownNoteIds[[string]$note.id] = $true }
        $script:creatorCreatedMemberNoteResult = $null
        Wait-Condition -Description "member-created Note committed with creator 4202" `
            -Seconds 30 -Condition {
                $snapshot = Get-ChartSnapshot $endpoint $member.Token
                $created = @($snapshot.notes | Where-Object {
                        -not $knownNoteIds.ContainsKey([string]$_.id)
                    })
                if ($created.Count -eq 1 -and [long]$created[0].creatorUserId -eq 4202) {
                    $script:creatorCreatedMemberNoteResult = $created[0]
                    return $true
                }
                return $false
            }
        $createdMemberNote = $script:creatorCreatedMemberNoteResult
        $script:creatorCreatedMemberNoteResult = $null
        $createdBeat = [double]$createdMemberNote.beat.bar +
            [double]$createdMemberNote.beat.numerator /
            [double]$createdMemberNote.beat.denominator

        $script:creatorOwnerAfterMemberPlacementResult = $null
        $script:creatorMemberAfterMemberPlacementResult = $null
        Wait-Condition -Description "member attribution reaches both custom timelines" `
            -Seconds 30 -Condition {
                $ownerLive = Get-TimelineLiveState $owner.Process.Id
                $memberLive = Get-TimelineLiveState $member.Process.Id
                if ([int]$ownerLive.creatorAttributedNoteCount -eq $baselineNoteCount + 1 -and
                    [int]$memberLive.creatorAttributedNoteCount -eq $baselineNoteCount + 1) {
                    $script:creatorOwnerAfterMemberPlacementResult = $ownerLive
                    $script:creatorMemberAfterMemberPlacementResult = $memberLive
                    return $true
                }
                return $false
            }
        $ownerAfterMemberPlacement = $script:creatorOwnerAfterMemberPlacementResult
        $memberAfterMemberPlacement = $script:creatorMemberAfterMemberPlacementResult
        $script:creatorOwnerAfterMemberPlacementResult = $null
        $script:creatorMemberAfterMemberPlacementResult = $null

        $memberSelectTool = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickTool.Select" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberSelectTool $memberHandle
        $creatorPhysicalActions.Add("member-physically-select-hover-tool")
        $memberHoverPoint = Get-TimelinePoint `
            $memberRoomRuntime `
            ([int]$createdMemberNote.lane) `
            ($createdBeat - [double]$memberAfterMemberPlacement.currentBeat) `
            $member.Process.Id `
            ([double]$memberAfterMemberPlacement.pixelsPerBeat)
        Move-PhysicalPointer `
            ([int]$memberHoverPoint.x) `
            ([int]$memberHoverPoint.y) `
            $memberHandle `
            160
        $creatorPhysicalActions.Add("member-physically-hover-own-created-note")
        Wait-Condition -Description "member physical hover resolves creator 4202" `
            -Seconds 15 -Condition {
                [long](Get-TimelineLiveState $member.Process.Id).lastCreatorHoverUserId -eq 4202
            }
        $memberHoverStatus = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 5000
        $memberHoverLive = Get-TimelineLiveState $member.Process.Id
        if ([long]$memberHoverLive.lastCreatorHoverUserId -ne 4202) {
            throw "Member hover did not expose creator user id 4202."
        }
        $memberCreatorTooltip = [ordered]@{
            name = [string]$memberHoverLive.creatorHoverTooltip
            rendering = "single-custom-timeline-overlay"
            physicalPointerHit = $true
        }
        $observations.memberCreatorHoverStatus = Observe-Element $memberHoverStatus
        $observations.memberCreatorTooltip = $memberCreatorTooltip
        $captures.memberOwnCreatorHover = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-own-creator-avatar-hover.png")

        $ownerLiveForMemberHover = Get-TimelineLiveState $owner.Process.Id
        $ownerMemberHoverPoint = Get-TimelinePoint `
            $ownerRuntime `
            ([int]$createdMemberNote.lane) `
            ($createdBeat - [double]$ownerLiveForMemberHover.currentBeat) `
            $owner.Process.Id `
            ([double]$ownerLiveForMemberHover.pixelsPerBeat)
        Move-PhysicalPointer `
            ([int]$ownerMemberHoverPoint.x) `
            ([int]$ownerMemberHoverPoint.y) `
            $ownerHandle `
            160
        $creatorPhysicalActions.Add("owner-physically-hover-member-created-note")
        Wait-Condition -Description "owner physical hover resolves member creator 4202" `
            -Seconds 15 -Condition {
                [long](Get-TimelineLiveState $owner.Process.Id).lastCreatorHoverUserId -eq 4202
            }
        $ownerMemberHoverStatus = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 5000
        $ownerMemberHoverLive = Get-TimelineLiveState $owner.Process.Id
        if ([long]$ownerMemberHoverLive.lastCreatorHoverUserId -ne 4202) {
            throw "Owner hover of the member Note did not expose creator user id 4202."
        }
        $ownerMemberTooltip = [ordered]@{
            name = [string]$ownerMemberHoverLive.creatorHoverTooltip
            rendering = "single-custom-timeline-overlay"
            physicalPointerHit = $true
        }
        $observations.ownerMemberCreatorHoverStatus = Observe-Element $ownerMemberHoverStatus
        $observations.ownerMemberCreatorTooltip = $ownerMemberTooltip
        $captures.ownerMemberCreatorHover = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-member-creator-avatar-hover.png")

        $ownerInitialBeat = [double]$selected.beat.value
        $ownerLiveForOwnerHover = Get-TimelineLiveState $owner.Process.Id
        $ownerInitialPoint = Get-TimelinePoint `
            $ownerRuntime `
            ([int]$selected.lane) `
            ($ownerInitialBeat - [double]$ownerLiveForOwnerHover.currentBeat) `
            $owner.Process.Id `
            ([double]$ownerLiveForOwnerHover.pixelsPerBeat)
        Move-PhysicalPointer `
            ([int]$ownerInitialPoint.x) `
            ([int]$ownerInitialPoint.y) `
            $ownerHandle `
            160
        $creatorPhysicalActions.Add("owner-physically-hover-owner-created-note")
        Wait-Condition -Description "owner physical hover resolves owner creator 4101" `
            -Seconds 15 -Condition {
                [long](Get-TimelineLiveState $owner.Process.Id).lastCreatorHoverUserId -eq 4101
            }
        $ownerOwnHoverStatus = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 5000
        $ownerOwnHoverLive = Get-TimelineLiveState $owner.Process.Id
        if ([long]$ownerOwnHoverLive.lastCreatorHoverUserId -ne 4101) {
            throw "Owner hover of the initialized Note did not expose creator user id 4101."
        }
        $ownerOwnTooltip = [ordered]@{
            name = [string]$ownerOwnHoverLive.creatorHoverTooltip
            rendering = "single-custom-timeline-overlay"
            physicalPointerHit = $true
        }
        $observations.ownerOwnCreatorHoverStatus = Observe-Element $ownerOwnHoverStatus
        $observations.ownerOwnCreatorTooltip = $ownerOwnTooltip
        $captures.ownerOwnCreatorHover = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-own-creator-avatar-hover.png")

        $ownerPlayPause = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.QuickPlayPause" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerPlayPause $ownerHandle
        $creatorPhysicalActions.Add("owner-physically-start-playback")
        $script:creatorOwnerPlaybackLiveResult = $null
        Wait-Condition -Description "creator markers suppressed during playback" -Seconds 15 -Condition {
            $live = Get-TimelineLiveState $owner.Process.Id
            if ([bool]$live.creatorMarkersPlaybackSuppressed) {
                $script:creatorOwnerPlaybackLiveResult = $live
                return $true
            }
            return $false
        }
        $ownerPlaybackLive = $script:creatorOwnerPlaybackLiveResult
        $script:creatorOwnerPlaybackLiveResult = $null
        $captures.ownerCreatorMarkersPlaybackSuppressed = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-creator-markers-playback-suppressed.png")
        $ownerPlayPause = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.QuickPlayPause" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerPlayPause $ownerHandle
        $creatorPhysicalActions.Add("owner-physically-pause-playback")
        Wait-Condition -Description "creator markers restored after pause" -Seconds 15 -Condition {
            -not [bool](Get-TimelineLiveState $owner.Process.Id).creatorMarkersPlaybackSuppressed
        }
        $ownerAfterPauseLive = Get-TimelineLiveState $owner.Process.Id
        $ownerMemberHoverPoint = Get-TimelinePoint `
            $ownerRuntime `
            ([int]$createdMemberNote.lane) `
            ($createdBeat - [double]$ownerAfterPauseLive.currentBeat) `
            $owner.Process.Id `
            ([double]$ownerAfterPauseLive.pixelsPerBeat)
        Move-PhysicalPointer `
            ([int]$ownerMemberHoverPoint.x) `
            ([int]$ownerMemberHoverPoint.y) `
            $ownerHandle `
            160
        $creatorPhysicalActions.Add("owner-physically-hover-member-note-after-pause")
        Wait-Condition -Description "member creator marker hover restored after pause" `
            -Seconds 15 -Condition {
                [long](Get-TimelineLiveState $owner.Process.Id).lastCreatorHoverUserId -eq 4202
            }
        $ownerRestoredLive = Get-TimelineLiveState $owner.Process.Id
        $captures.ownerCreatorMarkersRestored = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-creator-markers-restored.png")

        $finalSnapshot = Get-ChartSnapshot $endpoint $owner.Token
        $finalState = Get-HarnessState $endpoint
        $fixtureHashAfter = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
        $screenshots = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
            $screenshots[$file.BaseName] = [ordered]@{
                path = $file.FullName
                length = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        $creatorPassed =
            $baselineNoteCount -eq 2753 -and
            @($finalSnapshot.notes).Count -eq $baselineNoteCount + 1 -and
            [long]$createdMemberNote.creatorUserId -eq 4202 -and
            [int]$ownerCreatorReady.onlineCreatorCount -eq 2 -and
            [int]$memberCreatorReady.onlineCreatorCount -eq 2 -and
            [int]$ownerCreatorReady.onlineCreatorAvatarCount -eq 2 -and
            [int]$memberCreatorReady.onlineCreatorAvatarCount -eq 2 -and
            [int]$finalState.avatarDownloadCount -ge 4 -and
            [long]$memberHoverLive.lastCreatorHoverUserId -eq 4202 -and
            [long]$ownerMemberHoverLive.lastCreatorHoverUserId -eq 4202 -and
            [long]$ownerOwnHoverLive.lastCreatorHoverUserId -eq 4101 -and
            [bool]$ownerPlaybackLive.creatorMarkersPlaybackSuppressed -and
            -not [bool]$ownerRestoredLive.creatorMarkersPlaybackSuppressed -and
            [string]$observations.memberCreatorTooltip.name -ceq
                "创建者  Avalonia 成员" -and
            [string]$observations.ownerMemberCreatorTooltip.name -ceq
                "创建者  Avalonia 成员" -and
            [string]$observations.ownerOwnCreatorTooltip.name -ceq
                "创建者  Avalonia 房主" -and
            $screenshots.Count -ge 5 -and
            $fixtureHashBefore -ceq $fixtureHashAfter
        if (-not $creatorPassed) {
            throw "Online creator avatar/marker/hover/playback gates were incomplete."
        }

        $creatorEvidence = [ordered]@{
            schema = "lumachart.windows.avalonia.two-client-online-creator-marker-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed"
            formalMigrationAuthority = $true
            completion = $false
            migrationComplete = $false
            windowsAvaloniaOnly = $true
            productionServerMutationPerformed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            physicalMouseInputUsed = $true
            creatorMarkerContract = "wpf-1.1.0-online-creator-marker-r1"
            endpoint = $endpoint
            processIds = [ordered]@{
                server = $server.Id
                owner = $owner.Process.Id
                member = $member.Process.Id
            }
            paths = [ordered]@{
                projectRoot = $projectRoot
                outputRoot = $outputFullPath
                application = $applicationFullPath
                serverAssembly = $serverAssemblyFullPath
                fixture = $fixtureFullPath
                ownerRuntime = $owner.Runtime
                memberRoomRuntime = $member.RoomRuntime
                memberMaterializedChart = $memberRoomChartPath
                temp = $projectTemp
                dotnetHome = $dotnetHome
                nugetPackages = $nugetPackages
                nugetHttpCache = $nugetHttpCache
            }
            hashes = [ordered]@{
                application = (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
                applicationAssembly = (Get-FileHash `
                    -LiteralPath ([IO.Path]::ChangeExtension($applicationFullPath, ".dll")) `
                    -Algorithm SHA256).Hash
                serverAssembly = (Get-FileHash -LiteralPath $serverAssemblyFullPath -Algorithm SHA256).Hash
                fixtureBefore = $fixtureHashBefore
                fixtureAfter = $fixtureHashAfter
                memberMaterializedChart = (Get-FileHash `
                    -LiteralPath $memberRoomChartPath -Algorithm SHA256).Hash
            }
            realChart = [ordered]@{
                noteCountBefore = $baselineNoteCount
                timingCountBefore = $baselineTimingCount
                noteCountAfter = @($finalSnapshot.notes).Count
                initializedRowsCreatorUserId = 4101
                memberCreatedNote = $createdMemberNote
                memberCreatedNoteCreatorUserId = [long]$createdMemberNote.creatorUserId
            }
            avatars = [ordered]@{
                serverDownloadCountBeforePlacement = [int]$avatarStateBeforePlacement.avatarDownloadCount
                serverDownloadCountFinal = [int]$finalState.avatarDownloadCount
                downloadKeys = @($finalState.avatarDownloadKeys)
                ownerTimelineAvatarCount = [int]$ownerCreatorReady.onlineCreatorAvatarCount
                memberTimelineAvatarCount = [int]$memberCreatorReady.onlineCreatorAvatarCount
            }
            creatorTimelines = [ordered]@{
                ownerReady = $ownerCreatorReady
                memberReady = $memberCreatorReady
                ownerAfterMemberPlacement = $ownerAfterMemberPlacement
                memberAfterMemberPlacement = $memberAfterMemberPlacement
                memberHover = $memberHoverLive
                ownerMemberHover = $ownerMemberHoverLive
                ownerOwnHover = $ownerOwnHoverLive
                ownerPlayback = $ownerPlaybackLive
                ownerRestored = $ownerRestoredLive
            }
            physicalActions = $creatorPhysicalActions.ToArray()
            controls = $observations
            captures = $captures
            screenshots = $screenshots
            finalServerState = $finalState
            passed = $creatorPassed
        }
        $creatorEvidencePath = Join-Path $outputFullPath "evidence.json"
        $creatorEvidence | ConvertTo-Json -Depth 60 | Set-Content `
            -LiteralPath $creatorEvidencePath -Encoding utf8NoBOM
        Write-Output "Windows Avalonia two-client creator marker GUI capture: passed"
        Write-Output "Evidence: $creatorEvidencePath"
        return
    }

    if ($MultiLockOnly) {
        $multiLockPhysicalActions = [Collections.Generic.List[string]]::new()
        $ownerStatus = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        $memberStatus = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        Wait-Condition -Description "both clients synchronized before multi-selection lock" `
            -Seconds 30 -Condition {
                [string]$ownerStatus.Current.Name -like "*已同步*" -and
                [string]$memberStatus.Current.Name -like "*已同步*"
            }
        $roomStateBeforeLock = Get-HarnessState $endpoint
        $roomId = [string]$roomStateBeforeLock.room.id
        $snapshotBeforeLock = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $ownerLiveBeforeSelection = Get-TimelineLiveState $owner.Process.Id

        $ownerSelectTool = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.QuickTool.Select"
        Invoke-PhysicalElementClick $ownerSelectTool $ownerHandle
        $multiLockPhysicalActions.Add("owner-select-tool-before-marquee")
        foreach ($toggleId in @("Editor.QuickPalette.Toggle", "Editor.QuickValues.Toggle")) {
            $toggle = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId $toggleId -TimeoutMilliseconds 10000
            if ([string]$toggle.Current.Name -ceq "−") {
                Invoke-PhysicalElementClick $toggle $ownerHandle
                $multiLockPhysicalActions.Add("owner-collapse-$toggleId")
                Wait-Condition -Description "$toggleId collapsed" -Seconds 10 -Condition {
                    [string](Find-ElementById -ProcessId $owner.Process.Id `
                        -AutomationId $toggleId -TimeoutMilliseconds 1000).Current.Name -ceq "+"
                }
            }
        }

        $timelineGeometry = $ownerRuntime.timeline.geometry
        $ownerPixelsPerBeat = [double]$ownerLiveBeforeSelection.pixelsPerBeat
        $viewportTopBeat = [double]$ownerLiveBeforeSelection.currentBeat +
            ([double]$timelineGeometry.judgmentLineYWindowDip -
                [double]$timelineGeometry.topWindowDip) / $ownerPixelsPerBeat
        $viewportBottomBeat = [double]$ownerLiveBeforeSelection.currentBeat -
            ([double]$timelineGeometry.bottomWindowDip -
                [double]$timelineGeometry.judgmentLineYWindowDip) / $ownerPixelsPerBeat
        $visualHalfBeat = [Math]::Max(.065, 14.0 / $ownerPixelsPerBeat)
        $visibleObjects = @(
            foreach ($note in @($snapshotBeforeLock.notes)) {
                if ([bool]$note.isDraft) { continue }
                $startValue = [double]$note.beat.bar +
                    [double]$note.beat.numerator / [double]$note.beat.denominator
                $endValue = if ($null -ne $note.endBeat) {
                    [double]$note.endBeat.bar +
                        [double]$note.endBeat.numerator / [double]$note.endBeat.denominator
                } else { $startValue }
                $visualStart = [Math]::Min($startValue, $endValue) - $visualHalfBeat
                $visualEnd = [Math]::Max($startValue, $endValue) + $visualHalfBeat
                if ($visualEnd -lt $viewportBottomBeat -or $visualStart -gt $viewportTopBeat) { continue }
                [pscustomobject]@{
                    note = $note
                    lane = [int]$note.lane
                    startValue = $startValue
                    endValue = $endValue
                    visualStart = $visualStart
                    visualEnd = $visualEnd
                }
            })
        $visibleObjects = @($visibleObjects | Sort-Object startValue, lane)
        $marqueePlan = $null
        for ($index = 0; $index -le $visibleObjects.Count - 5; $index++) {
            $group = [Collections.Generic.List[object]]::new()
            for ($offset = 0; $offset -lt 5; $offset++) { $group.Add($visibleObjects[$index + $offset]) }
            $lowerBeat = [double](($group | Measure-Object startValue -Minimum).Minimum) - .105
            $upperBeat = [double](($group | Measure-Object endValue -Maximum).Maximum) + .105
            $hits = @($visibleObjects | Where-Object {
                    [double]$_.visualStart -le $upperBeat -and
                    [double]$_.visualEnd -ge $lowerBeat
                })
            $laneCount = @($hits | Group-Object lane).Count
            if ($hits.Count -eq 5 -and $laneCount -eq 4 -and
                $upperBeat - $lowerBeat -le 1.25 -and
                $lowerBeat -gt $viewportBottomBeat + .14 -and
                $upperBeat -lt $viewportTopBeat - .14) {
                $marqueePlan = [ordered]@{
                    lowerBeat = $lowerBeat
                    upperBeat = $upperBeat
                    hits = $hits
                    laneCount = $laneCount
                }
                break
            }
        }
        if ($null -eq $marqueePlan) {
            throw "No isolated five-Note/four-lane marquee existed in the real visible chart window."
        }

        $selectedRanges = @(
            foreach ($item in @($marqueePlan.hits)) {
                $note = $item.note
                $rangeEnd = $note.endBeat
                if ($null -eq $rangeEnd) {
                    $denominator = [int]$note.beat.denominator
                    $division = [int]$ownerRuntime.timeline.snapDivision
                    $left = [Math]::Abs($denominator)
                    $right = [Math]::Abs($division)
                    while ($right -ne 0) {
                        $remainder = $left % $right
                        $left = $right
                        $right = $remainder
                    }
                    $greatestCommonDivisor = [Math]::Max(1, $left)
                    $commonDenominator = [int]($denominator / $greatestCommonDivisor * $division)
                    $scaledNumerator = [int]$note.beat.numerator *
                        [int]($commonDenominator / $denominator)
                    $rangeEnd = [pscustomobject]@{
                        bar = [int]$note.beat.bar
                        numerator = $scaledNumerator + 1
                        denominator = $commonDenominator
                    }
                }
                [pscustomobject]@{
                    note = $note
                    startBeat = $note.beat
                    endBeat = $rangeEnd
                    startValue = [double]$note.beat.bar +
                        [double]$note.beat.numerator / [double]$note.beat.denominator
                    endValue = [double]$rangeEnd.bar +
                        [double]$rangeEnd.numerator / [double]$rangeEnd.denominator
                }
            })
        $expectedStartBeat = ($selectedRanges | Sort-Object startValue | Select-Object -First 1).startBeat
        $expectedEndBeat = ($selectedRanges | Sort-Object endValue -Descending | Select-Object -First 1).endBeat

        $scale = [double]$ownerRuntime.window.screenScaling
        $proGeometry = $ownerRuntime.timeline.proEditor.geometry
        $marqueeStartX = [int][Math]::Round(
            [double]$ownerRuntime.window.positionXPixels +
            ([double]$proGeometry.officialTrackLeftWindowDip - 2) * $scale)
        $marqueeEndX = [int][Math]::Round(
            [double]$ownerRuntime.window.positionXPixels +
            ([double]$proGeometry.officialTrackRightWindowDip - 4) * $scale)
        $judgmentY = [double]$ownerRuntime.window.positionYPixels +
            [double]$timelineGeometry.judgmentLineYWindowDip * $scale
        $marqueeStartY = [int][Math]::Round(
            $judgmentY -
            ([double]$marqueePlan.lowerBeat - [double]$ownerLiveBeforeSelection.currentBeat) *
            $ownerPixelsPerBeat * $scale)
        $marqueeEndY = [int][Math]::Round(
            $judgmentY -
            ([double]$marqueePlan.upperBeat - [double]$ownerLiveBeforeSelection.currentBeat) *
            $ownerPixelsPerBeat * $scale)
        Invoke-PhysicalDrag $marqueeStartX $marqueeStartY $marqueeEndX $marqueeEndY $ownerHandle
        $multiLockPhysicalActions.Add("owner-marquee-exactly-five-real-notes")
        Wait-Condition -Description "five-Note marquee selection" -Seconds 15 -Condition {
            $live = Get-TimelineLiveState $owner.Process.Id
            # Room-sync status may legitimately replace the transient marquee
            # sentence before UIA observes it. The stable timeline diagnostics
            # are the authoritative selection gate.
            [int]$live.selectedNoteCount -eq 5 -and [int]$live.selectedTimingCount -eq 0
        }
        $ownerLiveAfterSelection = Get-TimelineLiveState $owner.Process.Id
        $observations.ownerFiveNoteSelectionStatus = Observe-Element $ownerStatus
        $observations.ownerTimelineAfterFiveNoteSelection = Observe-Element `
            (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "Timeline.Surface")
        $captures.ownerFiveNoteSelection = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-five-note-marquee-selection.png")

        $ownerQuickPaletteToggle = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.QuickPalette.Toggle"
        if ([string]$ownerQuickPaletteToggle.Current.Name -ceq "+") {
            Invoke-PhysicalElementClick $ownerQuickPaletteToggle $ownerHandle
            $multiLockPhysicalActions.Add("owner-expand-quick-palette-for-lock")
        }
        $script:multiLockOwnerButton = $null
        Wait-Condition -Description "enabled owner lock action after palette expansion" -Seconds 15 -Condition {
            $candidate = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "Editor.QuickOwnerLock" -TimeoutMilliseconds 1000
            if ($candidate.Current.IsEnabled -and
                [string]$candidate.Current.Name -like "*锁定选区*") {
                $script:multiLockOwnerButton = $candidate
                return $true
            }
            return $false
        }
        $ownerLockButton = $script:multiLockOwnerButton
        $script:multiLockOwnerButton = $null
        Invoke-PhysicalElementClick $ownerLockButton $ownerHandle
        $multiLockPhysicalActions.Add("owner-lock-five-note-selection")
        $lockedState = Wait-HarnessState $endpoint {
            param($state)
            [int]$state.lockCount -eq 1 -and [int]$state.lockSelectionToggleCount -eq 1
        } "one raw lock range and one resulting continuous lock"
        $lockedState | ConvertTo-Json -Depth 60 | Set-Content `
            -LiteralPath (Join-Path $outputFullPath "server-state-multi-locked.json") -Encoding utf8NoBOM
        $lock = @($lockedState.locks)[0]
        $lockToggle = @($lockedState.lockSelectionToggles)[0]
        $requestedRanges = @($lockToggle.requestedRanges)
        $sameStart = [int]$lock.startBeat.bar -eq [int]$expectedStartBeat.bar -and
            [int]$lock.startBeat.numerator -eq [int]$expectedStartBeat.numerator -and
            [int]$lock.startBeat.denominator -eq [int]$expectedStartBeat.denominator
        $sameEnd = [int]$lock.endBeat.bar -eq [int]$expectedEndBeat.bar -and
            [int]$lock.endBeat.numerator -eq [int]$expectedEndBeat.numerator -and
            [int]$lock.endBeat.denominator -eq [int]$expectedEndBeat.denominator
        $rawSameStart = $requestedRanges.Count -eq 1 -and
            [int]$requestedRanges[0].startBeat.bar -eq [int]$expectedStartBeat.bar -and
            [int]$requestedRanges[0].startBeat.numerator -eq [int]$expectedStartBeat.numerator -and
            [int]$requestedRanges[0].startBeat.denominator -eq [int]$expectedStartBeat.denominator
        $rawSameEnd = $requestedRanges.Count -eq 1 -and
            [int]$requestedRanges[0].endBeat.bar -eq [int]$expectedEndBeat.bar -and
            [int]$requestedRanges[0].endBeat.numerator -eq [int]$expectedEndBeat.numerator -and
            [int]$requestedRanges[0].endBeat.denominator -eq [int]$expectedEndBeat.denominator
        if ($requestedRanges.Count -ne 1 -or -not $sameStart -or -not $sameEnd -or
            -not $rawSameStart -or -not $rawSameEnd -or [bool]$lockToggle.isUnlock) {
            throw "Five selected objects did not produce one exact raw/authoritative continuous Beat range."
        }
        Wait-Condition -Description "member received the single owner-protected region" -Seconds 30 -Condition {
            [int](Get-TimelineLiveState $member.Process.Id).ownerProtectedRegionCount -eq 1
        }
        $ownerLiveLocked = Get-TimelineLiveState $owner.Process.Id
        $memberLiveLocked = Get-TimelineLiveState $member.Process.Id
        $observations.ownerLockActionAfterLock = Observe-Element `
            (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "Editor.QuickOwnerLock")
        $captures.ownerContinuousLock = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-one-continuous-lock.png")

        $blockedTarget = @($marqueePlan.hits | Where-Object { $null -eq $_.note.endBeat } |
            Sort-Object startValue, lane | Select-Object -First 1)[0]
        if ($null -eq $blockedTarget) { throw "The five-Note marquee exposed no Tap for the member lock gate." }
        $memberSelectTool = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickTool.Select"
        Invoke-PhysicalElementClick $memberSelectTool $memberHandle
        $multiLockPhysicalActions.Add("member-select-tool-under-owner-lock")
        $memberLiveBeforeBlockedDrag = Get-TimelineLiveState $member.Process.Id
        $blockedOffset = [double]$blockedTarget.startValue -
            [double]$memberLiveBeforeBlockedDrag.currentBeat
        $blockedPoint = Get-TimelinePoint $memberRoomRuntime ([int]$blockedTarget.lane) `
            $blockedOffset $member.Process.Id ([double]$memberLiveBeforeBlockedDrag.pixelsPerBeat)
        $memberOperationCountBeforeBlockedDrag = @(
            $lockedState.acceptedOperations | Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $blockedDragPixels = [int][Math]::Round(
            .25 * [double]$memberLiveBeforeBlockedDrag.pixelsPerBeat * [double]$blockedPoint.scale)
        Invoke-PhysicalDrag $blockedPoint.x $blockedPoint.y `
            $blockedPoint.x ($blockedPoint.y - $blockedDragPixels) $memberHandle
        $multiLockPhysicalActions.Add("member-attempt-drag-inside-continuous-lock")
        Wait-Condition -Description "member locked Note remains selected" -Seconds 15 -Condition {
            $live = Get-TimelineLiveState $member.Process.Id
            [string]$live.selectedNoteId -ceq [string]$blockedTarget.note.id -and
            [int]$live.ownerProtectedRegionCount -eq 1
        }
        $memberLockedInspector = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Inspector.Note.SelectionHint" -TimeoutMilliseconds 10000
        if ([string]$memberLockedInspector.Current.Name -notlike "*房主锁定*") {
            throw "Member Note inspector did not expose the visible owner-lock state."
        }
        $memberLockAction = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickOwnerLock" -TimeoutMilliseconds 10000
        if ($memberLockAction.Current.IsEnabled -or
            [string]$memberLockAction.Current.Name -cne "仅房主可锁定") {
            throw "Member lock UI did not remain visibly fail-closed after the physical drag attempt."
        }
        Start-Sleep -Milliseconds 900
        $afterBlockedDragState = Get-HarnessState $endpoint
        $memberOperationCountAfterBlockedDrag = @(
            $afterBlockedDragState.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        if ($memberOperationCountAfterBlockedDrag -ne $memberOperationCountBeforeBlockedDrag) {
            throw "A member drag inside the continuous owner lock reached the server."
        }
        $snapshotAfterBlockedDrag = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $blockedTargetAfter = @($snapshotAfterBlockedDrag.notes | Where-Object {
                [string]$_.id -ceq [string]$blockedTarget.note.id
            })[0]
        $blockedTargetUnchanged = $blockedTargetAfter -and
            (Get-OnlineNoteIdentityJson $blockedTargetAfter) -ceq
            (Get-OnlineNoteIdentityJson $blockedTarget.note)
        if (-not $blockedTargetUnchanged) {
            throw "The member's physically dragged Note changed despite the continuous owner lock."
        }
        $observations.memberBlockedStatus = Observe-Element $memberStatus
        $observations.memberLockedInspector = Observe-Element $memberLockedInspector
        $observations.memberLockAction = Observe-Element $memberLockAction
        $observations.memberTimelineUnderLock = Observe-Element `
            (Find-ElementById -ProcessId $member.Process.Id -AutomationId "Timeline.Surface")
        $captures.memberBlockedByContinuousLock = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-blocked-by-continuous-lock.png")

        # Exercise the remaining direct editing entry points against the same
        # exact owner region. Every rejected gesture must remain client-local:
        # no operation, no Note/Timing mutation and no partial target write.
        $lockStartValue = [double]$lock.startBeat.bar +
            [double]$lock.startBeat.numerator / [double]$lock.startBeat.denominator
        $lockEndValue = [double]$lock.endBeat.bar +
            [double]$lock.endBeat.numerator / [double]$lock.endBeat.denominator
        $memberKeyCount = [int]$snapshotAfterBlockedDrag.keyCount
        $memberSnapDivision = [int](Get-TimelineLiveState $member.Process.Id).snapDivision
        $placementCandidate = $null
        $firstCell = [int][Math]::Ceiling(($lockStartValue + .0000001) * $memberSnapDivision)
        $lastCellExclusive = [int][Math]::Ceiling(($lockEndValue - .0000001) * $memberSnapDivision)
        for ($cell = $firstCell; $cell -lt $lastCellExclusive -and
            $null -eq $placementCandidate; $cell++) {
            $candidateValue = [double]$cell / [double]$memberSnapDivision
            for ($lane = 0; $lane -lt $memberKeyCount; $lane++) {
                $blockedByVisibleNote = @($snapshotAfterBlockedDrag.notes | Where-Object {
                        if ([bool]$_.isDraft -or [int]$_.lane -ne $lane) { return $false }
                        $start = [double]$_.beat.bar +
                            [double]$_.beat.numerator / [double]$_.beat.denominator
                        $end = if ($null -ne $_.endBeat) {
                            [double]$_.endBeat.bar +
                                [double]$_.endBeat.numerator / [double]$_.endBeat.denominator
                        } else { $start }
                        [Math]::Abs($start - $candidateValue) -lt .08 -or
                            ($null -ne $_.endBeat -and
                                $candidateValue -gt [Math]::Min($start, $end) -and
                                $candidateValue -lt [Math]::Max($start, $end))
                    }).Count -gt 0
                if (-not $blockedByVisibleNote) {
                    $placementCandidate = [ordered]@{
                        lane = $lane
                        value = $candidateValue
                    }
                    break
                }
            }
        }
        if ($null -eq $placementCandidate) {
            throw "No empty snapped placement target existed inside the continuous owner lock."
        }

        $memberTapTool = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickTool.Tap" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberTapTool $memberHandle
        $multiLockPhysicalActions.Add("member-select-tap-tool-under-owner-lock")
        $memberLiveBeforeLockedPlacement = Get-TimelineLiveState $member.Process.Id
        $lockedPlacementPoint = Get-TimelinePoint $memberRoomRuntime `
            ([int]$placementCandidate.lane) `
            ([double]$placementCandidate.value -
                [double]$memberLiveBeforeLockedPlacement.currentBeat) `
            $member.Process.Id ([double]$memberLiveBeforeLockedPlacement.pixelsPerBeat)
        $lockedPlacementStateBefore = Get-HarnessState $endpoint
        $lockedPlacementSnapshotBefore = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $lockedPlacementMemberOpsBefore = @(
            $lockedPlacementStateBefore.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        Invoke-PhysicalClick $lockedPlacementPoint.x $lockedPlacementPoint.y $memberHandle
        $multiLockPhysicalActions.Add("member-attempt-tap-placement-inside-owner-lock")
        $observations.memberLockedPlacementImmediateStatus = Observe-Element $memberStatus
        if ([string]$memberStatus.Current.Name -notlike "*房主锁定选区*" -or
            [string]$memberStatus.Current.Name -notlike "*不能放置 Note*") {
            throw "Locked Tap placement did not expose the precise owner-lock rejection."
        }
        Start-Sleep -Milliseconds 900
        $lockedPlacementStateAfter = Get-HarnessState $endpoint
        $lockedPlacementSnapshotAfter = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $lockedPlacementMemberOpsAfter = @(
            $lockedPlacementStateAfter.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $lockedPlacementNotesUnchanged =
            (@($lockedPlacementSnapshotBefore.notes | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress) -ceq
            (@($lockedPlacementSnapshotAfter.notes | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress)
        if ($lockedPlacementMemberOpsAfter -ne $lockedPlacementMemberOpsBefore -or
            -not $lockedPlacementNotesUnchanged) {
            throw "Locked Tap placement reached the server or mutated the chart."
        }

        $lockedLongNote = @($marqueePlan.hits |
                Where-Object { $null -ne $_.note.endBeat } |
                Sort-Object startValue, lane |
                Select-Object -First 1)[0]
        if ($null -eq $lockedLongNote) {
            throw "The continuous owner lock exposed no LN for the tail-resize gate."
        }
        $memberSelectTool = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickTool.Select" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberSelectTool $memberHandle
        $multiLockPhysicalActions.Add("member-select-tool-before-locked-ln-tail")
        $memberLiveBeforeLockedTail = Get-TimelineLiveState $member.Process.Id
        $lockedTailPoint = Get-TimelinePoint $memberRoomRuntime `
            ([int]$lockedLongNote.lane) `
            ([double]$lockedLongNote.endValue -
                [double]$memberLiveBeforeLockedTail.currentBeat) `
            $member.Process.Id ([double]$memberLiveBeforeLockedTail.pixelsPerBeat)
        $lockedTailStateBefore = Get-HarnessState $endpoint
        $lockedTailSnapshotBefore = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $lockedTailMemberOpsBefore = @(
            $lockedTailStateBefore.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $lockedTailDragPixels = [int][Math]::Round(
            (1.0 / [double]$memberSnapDivision) *
            [double]$memberLiveBeforeLockedTail.pixelsPerBeat *
            [double]$lockedTailPoint.scale)
        Invoke-PhysicalDrag $lockedTailPoint.x $lockedTailPoint.y `
            $lockedTailPoint.x ($lockedTailPoint.y - $lockedTailDragPixels) $memberHandle
        $multiLockPhysicalActions.Add("member-attempt-locked-ln-tail-resize")
        # Pointer hover at the drag destination legitimately replaces the
        # transient rejection sentence. Click the unchanged tail once more
        # without movement so the user-visible owner-lock message remains
        # observable while the server/no-mutation checks still cover the drag.
        Invoke-PhysicalClick $lockedTailPoint.x $lockedTailPoint.y $memberHandle
        $multiLockPhysicalActions.Add("member-click-locked-ln-tail-for-visible-rejection")
        $observations.memberLockedTailImmediateStatus = Observe-Element $memberStatus
        if ([string]$memberStatus.Current.Name -notlike "*房主锁定选区*" -or
            [string]$memberStatus.Current.Name -notlike "*不能调整面尾*") {
            throw "Locked LN-tail drag did not expose the precise owner-lock rejection."
        }
        Start-Sleep -Milliseconds 900
        $lockedTailStateAfter = Get-HarnessState $endpoint
        $lockedTailSnapshotAfter = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $lockedTailMemberOpsAfter = @(
            $lockedTailStateAfter.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $lockedTailBefore = @($lockedTailSnapshotBefore.notes | Where-Object {
                [string]$_.id -ceq [string]$lockedLongNote.note.id
            })[0]
        $lockedTailAfter = @($lockedTailSnapshotAfter.notes | Where-Object {
                [string]$_.id -ceq [string]$lockedLongNote.note.id
            })[0]
        $lockedTailUnchanged = $lockedTailBefore -and $lockedTailAfter -and
            (Get-OnlineNoteIdentityJson $lockedTailBefore) -ceq
                (Get-OnlineNoteIdentityJson $lockedTailAfter)
        if ($lockedTailMemberOpsAfter -ne $lockedTailMemberOpsBefore -or
            -not $lockedTailUnchanged) {
            throw "Locked LN-tail resize reached the server or changed the LN."
        }

        # The loopback room intentionally starts this editor with Note-only
        # permission. Grant Timing through the real owner GUI before proving
        # that the owner lock (rather than a coarse permission denial) rejects
        # the member's physical Timing add.
        $memberBeforeLockedTimingPermission = @(
            (Get-HarnessState $endpoint).members |
                Where-Object { [long]$_.userId -eq 4202 })[0]
        if ($null -eq $memberBeforeLockedTimingPermission) {
            throw "The member was missing before the locked Timing permission gate."
        }
        if (-not [bool]$memberBeforeLockedTimingPermission.canEditTiming) {
            $ownerOnlineNavigation = Find-VisibleElementById `
                -ProcessId $owner.Process.Id `
                -AutomationId "Title.Online" `
                -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick $ownerOnlineNavigation $ownerHandle
            $multiLockPhysicalActions.Add(
                "owner-open-online-community-before-locked-timing")
            $ownerCommunityForLockedTiming = Find-ElementById `
                -ProcessId $owner.Process.Id `
                -AutomationId "OnlineCommunity.Dialog" `
                -TimeoutMilliseconds 30000
            $ownerCommunityForLockedTimingHandle =
                [IntPtr]$ownerCommunityForLockedTiming.Current.NativeWindowHandle
            $ownerRoomsNavigation = Find-ElementById `
                -ProcessId $owner.Process.Id `
                -AutomationId "OnlineCommunity.Navigation.Rooms" `
                -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick `
                $ownerRoomsNavigation `
                $ownerCommunityForLockedTimingHandle
            $multiLockPhysicalActions.Add(
                "owner-open-room-management-before-locked-timing")
            $ownerManageMemberForLockedTiming = Find-ElementById `
                -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.4202.Manage" `
                -TimeoutMilliseconds 20000
            Invoke-PhysicalElementClick `
                $ownerManageMemberForLockedTiming `
                $ownerCommunityForLockedTimingHandle
            $multiLockPhysicalActions.Add(
                "owner-open-member-permissions-before-locked-timing")
            $ownerTimingPermissionForLockedTiming = Find-ElementById `
                -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Timing" `
                -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick `
                $ownerTimingPermissionForLockedTiming `
                $ownerCommunityForLockedTimingHandle
            $multiLockPhysicalActions.Add(
                "owner-enable-member-timing-before-lock-gate")
            $ownerSavePermissionForLockedTiming = Find-ElementById `
                -ProcessId $owner.Process.Id `
                -AutomationId "OnlineRooms.Member.Save" `
                -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick `
                $ownerSavePermissionForLockedTiming `
                $ownerCommunityForLockedTimingHandle
            $multiLockPhysicalActions.Add(
                "owner-save-member-timing-before-lock-gate")
            $lockedTimingPermissionState = Wait-HarnessState $endpoint {
                param($state)
                $candidate = @($state.members |
                    Where-Object { [long]$_.userId -eq 4202 })[0]
                $candidate -and
                    [string]$candidate.memberRole -ceq "editor" -and
                    [bool]$candidate.canEditTiming -and
                    [bool]$candidate.canEditNotes
            } "member Timing permission before owner-lock gate"

            $memberTimingPermissionNoticeTitle = Find-ElementById `
                -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Title" `
                -TimeoutMilliseconds 30000
            $memberTimingPermissionNoticeMessage = Find-ElementById `
                -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Message" `
                -TimeoutMilliseconds 10000
            if ([string]$memberTimingPermissionNoticeTitle.Current.Name -cne
                    "房间权限已更新" -or
                [string]$memberTimingPermissionNoticeMessage.Current.Name -notlike
                    "*Effect / Timing Edit：允许编辑*") {
                throw "The member did not receive the precise Timing permission notice."
            }
            $observations.memberTimingPermissionNotice = [ordered]@{
                title = Observe-Element $memberTimingPermissionNoticeTitle
                message = Observe-Element $memberTimingPermissionNoticeMessage
            }
            $memberTimingPermissionDismiss = Find-ElementById `
                -ProcessId $member.Process.Id `
                -AutomationId "OnlineRoom.PermissionNotice.Dismiss" `
                -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick `
                $memberTimingPermissionDismiss `
                $memberHandle
            $multiLockPhysicalActions.Add(
                "member-dismiss-timing-permission-notice")

            $ownerCommunityCloseForLockedTiming = Find-ElementById `
                -ProcessId $owner.Process.Id `
                -AutomationId "OnlineCommunity.Navigation.Close" `
                -TimeoutMilliseconds 10000
            Invoke-PhysicalElementClick `
                $ownerCommunityCloseForLockedTiming `
                $ownerCommunityForLockedTimingHandle
            $multiLockPhysicalActions.Add(
                "owner-return-editor-before-locked-timing")
            Wait-Condition `
                -Description "owner community closes before locked Timing" `
                -Seconds 15 `
                -Condition {
                try {
                    [void](Find-ElementById `
                        -ProcessId $owner.Process.Id `
                        -AutomationId "OnlineCommunity.Dialog" `
                        -TimeoutMilliseconds 300)
                    return $false
                }
                catch { return $true }
            }
        }
        else {
            $lockedTimingPermissionState = Get-HarnessState $endpoint
        }
        $memberAfterLockedTimingPermission = @(
            $lockedTimingPermissionState.members |
                Where-Object { [long]$_.userId -eq 4202 })[0]
        if ($null -eq $memberAfterLockedTimingPermission -or
            -not [bool]$memberAfterLockedTimingPermission.canEditTiming) {
            throw "Timing permission was not active before the owner-lock gate."
        }

        $memberTimelineForLockedTiming = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Timeline.Surface" -TimeoutMilliseconds 10000
        $memberLiveBeforeLockedTimingSeek = Get-TimelineLiveState $member.Process.Id
        $lockedTimingSeekPlan = Get-LockedGridSeekPlan `
            -CurrentBeat ([double]$memberLiveBeforeLockedTimingSeek.currentBeat) `
            -Division $memberSnapDivision `
            -LockStart $lockStartValue `
            -LockEnd $lockEndValue
        $lockedTimingWheelNotches = [int]$lockedTimingSeekPlan.wheelNotches
        Invoke-PhysicalElementWheel $memberTimelineForLockedTiming `
            $lockedTimingWheelNotches $memberHandle
        if ($lockedTimingWheelNotches -ne 0) {
            $multiLockPhysicalActions.Add(
                "member-wheel-redline-to-reachable-owner-lock-grid-for-timing")
        }
        Wait-Condition -Description "member red line at reachable owner-lock grid for Timing" `
            -Seconds 15 -PollMilliseconds 50 -Condition {
                [Math]::Abs(
                    [double](Get-TimelineLiveState $member.Process.Id).currentBeat -
                    [double]$lockedTimingSeekPlan.expectedCurrentBeat) -lt .0000001
            }
        $memberTimingTab = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Inspector.TimingTab" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberTimingTab $memberHandle
        $multiLockPhysicalActions.Add("member-open-timing-inspector-under-owner-lock")
        $memberTimingBeat = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Inspector.Timing.Beat" -TimeoutMilliseconds 10000
        $memberTimingBpm = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Inspector.Timing.Bpm" -TimeoutMilliseconds 10000
        $lockedTimingBeatText = [string]$lockedTimingSeekPlan.snappedBeatText
        Set-ElementValue $memberTimingBeat $lockedTimingBeatText
        Set-ElementValue $memberTimingBpm "180"
        $multiLockPhysicalActions.Add("member-set-locked-timing-fields-with-value-pattern")
        $lockedTimingStateBefore = Get-HarnessState $endpoint
        $lockedTimingSnapshotBefore = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $lockedTimingMemberOpsBefore = @(
            $lockedTimingStateBefore.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $memberTimingAdd = Find-VisibleElementById -ProcessId $member.Process.Id `
            -AutomationId "Inspector.Timing.Add" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberTimingAdd $memberHandle
        $multiLockPhysicalActions.Add("member-attempt-timing-add-inside-owner-lock")
        $observations.memberLockedTimingImmediateStatus = Observe-Element $memberStatus
        if ([string]$memberStatus.Current.Name -notlike
                "*新增 Timing / Effect 失败*" -or
            [string]$memberStatus.Current.Name -notlike
                "*触及房主锁定选区*" -or
            [string]$memberStatus.Current.Name -notlike
                "*成员不能在其中新增*") {
            throw "Locked Timing add did not expose the precise lock rejection."
        }
        Start-Sleep -Milliseconds 900
        $lockedTimingStateAfter = Get-HarnessState $endpoint
        $lockedTimingSnapshotAfter = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $lockedTimingMemberOpsAfter = @(
            $lockedTimingStateAfter.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $lockedTimingUnchanged =
            (@($lockedTimingSnapshotBefore.timing | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress) -ceq
            (@($lockedTimingSnapshotAfter.timing | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress)
        if ($lockedTimingMemberOpsAfter -ne $lockedTimingMemberOpsBefore -or
            -not $lockedTimingUnchanged) {
            throw "Locked Timing add reached the server or mutated Timing."
        }

        # Seed one exact Timing row inside the owner lock and one row at the
        # end-exclusive boundary through the real owner GUI. The member then
        # exercises update-source rejection, update-target rejection, locked
        # delete no-op and mixed locked/unlocked batch-delete filtering.
        $ownerTimelineForTimingBoundary = Find-ElementById `
            -ProcessId $owner.Process.Id `
            -AutomationId "Timeline.Surface" `
            -TimeoutMilliseconds 10000
        $ownerLiveBeforeTimingSeed = Get-TimelineLiveState $owner.Process.Id
        $ownerTimingDivision = [int]$ownerLiveBeforeTimingSeed.snapDivision
        $ownerLockedTimingSeekPlan = Get-ExactGridSeekPlan `
            -CurrentBeat ([double]$ownerLiveBeforeTimingSeed.currentBeat) `
            -Division $ownerTimingDivision `
            -TargetBeat ([double]$lockedTimingSeekPlan.snappedBeatValue)
        Invoke-PhysicalElementWheel `
            $ownerTimelineForTimingBoundary `
            ([int]$ownerLockedTimingSeekPlan.wheelNotches) `
            $ownerHandle
        if ([int]$ownerLockedTimingSeekPlan.wheelNotches -ne 0) {
            $multiLockPhysicalActions.Add(
                "owner-wheel-redline-to-locked-timing-seed")
        }
        Wait-Condition -Description "owner red line at locked Timing seed" `
            -Seconds 15 -PollMilliseconds 50 -Condition {
                [Math]::Abs(
                    [double](Get-TimelineLiveState $owner.Process.Id).currentBeat -
                    [double]$ownerLockedTimingSeekPlan.expectedCurrentBeat) -lt .0000001
            }

        $ownerTimingTabForBoundary = Find-ElementById `
            -ProcessId $owner.Process.Id `
            -AutomationId "Inspector.TimingTab" `
            -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerTimingTabForBoundary $ownerHandle
        $multiLockPhysicalActions.Add(
            "owner-open-timing-inspector-for-lock-boundaries")
        $ownerTimingBpmForBoundary = Find-ElementById `
            -ProcessId $owner.Process.Id `
            -AutomationId "Inspector.Timing.Bpm" `
            -TimeoutMilliseconds 10000
        $ownerTimingAddForBoundary = Find-VisibleElementById `
            -ProcessId $owner.Process.Id `
            -AutomationId "Inspector.Timing.Add" `
            -TimeoutMilliseconds 10000
        $timingSeedSnapshotBefore = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $timingSeedIdsBefore = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal)
        foreach ($timing in @($timingSeedSnapshotBefore.timing)) {
            [void]$timingSeedIdsBefore.Add([string]$timing.id)
        }
        $timingSeedStateBefore = Get-HarnessState $endpoint
        $timingSeedOwnerOpsBefore = @(
            $timingSeedStateBefore.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4101 }).Count
        Set-ElementValue $ownerTimingBpmForBoundary "172"
        Invoke-PhysicalElementClick $ownerTimingAddForBoundary $ownerHandle
        $multiLockPhysicalActions.Add(
            "owner-add-exact-timing-inside-own-lock")
        $timingLockedSeedState = Wait-HarnessState $endpoint {
            param($state)
            @($state.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4101 }).Count -gt
                $timingSeedOwnerOpsBefore
        } "owner locked Timing seed accepted"
        $timingLockedSeedSnapshot = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $lockedTimingSeeds = @($timingLockedSeedSnapshot.timing | Where-Object {
                -not $timingSeedIdsBefore.Contains([string]$_.id)
            })
        if ($lockedTimingSeeds.Count -ne 1) {
            throw "Owner locked Timing seed did not create exactly one authoritative row."
        }
        $lockedTimingSeed = $lockedTimingSeeds[0]
        $lockedTimingSeedValue = [double]$lockedTimingSeed.beat.bar +
            [double]$lockedTimingSeed.beat.numerator /
                [double]$lockedTimingSeed.beat.denominator
        if ($lockedTimingSeedValue -lt $lockStartValue -or
            $lockedTimingSeedValue -ge $lockEndValue) {
            throw "Owner locked Timing seed was not inside the exact half-open lock."
        }

        $unlockedTimingUnits = [long][Math]::Ceiling(
            $lockEndValue * [double]$ownerTimingDivision - .000000001)
        $unlockedTimingValue =
            [double]$unlockedTimingUnits / [double]$ownerTimingDivision
        if ($unlockedTimingValue -lt $lockEndValue) {
            $unlockedTimingUnits++
            $unlockedTimingValue =
                [double]$unlockedTimingUnits / [double]$ownerTimingDivision
        }
        $ownerLiveBeforeUnlockedTiming = Get-TimelineLiveState $owner.Process.Id
        $ownerUnlockedTimingSeekPlan = Get-ExactGridSeekPlan `
            -CurrentBeat ([double]$ownerLiveBeforeUnlockedTiming.currentBeat) `
            -Division $ownerTimingDivision `
            -TargetBeat $unlockedTimingValue
        Invoke-PhysicalElementWheel `
            $ownerTimelineForTimingBoundary `
            ([int]$ownerUnlockedTimingSeekPlan.wheelNotches) `
            $ownerHandle
        if ([int]$ownerUnlockedTimingSeekPlan.wheelNotches -ne 0) {
            $multiLockPhysicalActions.Add(
                "owner-wheel-redline-to-end-exclusive-timing-seed")
        }
        Wait-Condition -Description "owner red line at end-exclusive Timing seed" `
            -Seconds 15 -PollMilliseconds 50 -Condition {
                [Math]::Abs(
                    [double](Get-TimelineLiveState $owner.Process.Id).currentBeat -
                    [double]$ownerUnlockedTimingSeekPlan.expectedCurrentBeat) -lt .0000001
            }
        Set-ElementValue $ownerTimingBpmForBoundary "174"
        $timingUnlockedSeedStateBefore = Get-HarnessState $endpoint
        $timingUnlockedSeedOwnerOpsBefore = @(
            $timingUnlockedSeedStateBefore.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4101 }).Count
        Invoke-PhysicalElementClick $ownerTimingAddForBoundary $ownerHandle
        $multiLockPhysicalActions.Add(
            "owner-add-timing-at-end-exclusive-boundary")
        $timingUnlockedSeedState = Wait-HarnessState $endpoint {
            param($state)
            @($state.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4101 }).Count -gt
                $timingUnlockedSeedOwnerOpsBefore
        } "owner end-exclusive Timing seed accepted"
        $timingUnlockedSeedSnapshot = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $lockedTimingSeedIds = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal)
        foreach ($timing in @($timingLockedSeedSnapshot.timing)) {
            [void]$lockedTimingSeedIds.Add([string]$timing.id)
        }
        $unlockedTimingSeeds = @($timingUnlockedSeedSnapshot.timing | Where-Object {
                -not $lockedTimingSeedIds.Contains([string]$_.id)
            })
        if ($unlockedTimingSeeds.Count -ne 1) {
            throw "Owner end-exclusive Timing seed did not create exactly one authoritative row."
        }
        $unlockedTimingSeed = $unlockedTimingSeeds[0]
        $unlockedTimingSeedValue = [double]$unlockedTimingSeed.beat.bar +
            [double]$unlockedTimingSeed.beat.numerator /
                [double]$unlockedTimingSeed.beat.denominator
        if ($unlockedTimingSeedValue -lt $lockEndValue) {
            throw "The end-exclusive Timing seed was incorrectly placed inside the lock."
        }

        $memberLockedTimingRow = Find-ElementById `
            -ProcessId $member.Process.Id `
            -AutomationId (
                "Inspector.Timing.Row." +
                ([string]$lockedTimingSeed.id).ToLowerInvariant()) `
            -TimeoutMilliseconds 30000
        Invoke-PhysicalElementClick $memberLockedTimingRow $memberHandle
        $multiLockPhysicalActions.Add(
            "member-select-owner-locked-timing-row")
        $memberTimingBpmForBoundary = Find-ElementById `
            -ProcessId $member.Process.Id `
            -AutomationId "Inspector.Timing.Bpm" `
            -TimeoutMilliseconds 10000
        $memberTimingBeatForBoundary = Find-ElementById `
            -ProcessId $member.Process.Id `
            -AutomationId "Inspector.Timing.Beat" `
            -TimeoutMilliseconds 10000
        $memberTimingApplyForBoundary = Find-VisibleElementById `
            -ProcessId $member.Process.Id `
            -AutomationId "Inspector.Timing.Apply" `
            -TimeoutMilliseconds 10000
        $timingLockedUpdateStateBefore = Get-HarnessState $endpoint
        $timingLockedUpdateSnapshotBefore =
            Get-ChartSnapshot $endpoint $owner.Token $roomId
        $timingLockedUpdateMemberOpsBefore = @(
            $timingLockedUpdateStateBefore.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        Set-ElementValue $memberTimingBpmForBoundary "173"
        Invoke-PhysicalElementClick $memberTimingApplyForBoundary $memberHandle
        $multiLockPhysicalActions.Add(
            "member-attempt-update-owner-locked-timing")
        $observations.memberLockedTimingUpdateStatus = Observe-Element $memberStatus
        if ([string]$memberStatus.Current.Name -notlike
                "*应用 Timing / Effect 失败*" -or
            [string]$memberStatus.Current.Name -notlike
                "*房主锁定选区*") {
            throw "Locked Timing update did not expose the precise owner-lock rejection."
        }
        Start-Sleep -Milliseconds 900
        $timingLockedUpdateStateAfter = Get-HarnessState $endpoint
        $timingLockedUpdateSnapshotAfter =
            Get-ChartSnapshot $endpoint $owner.Token $roomId
        $timingLockedUpdateMemberOpsAfter = @(
            $timingLockedUpdateStateAfter.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $timingLockedUpdateUnchanged =
            (@($timingLockedUpdateSnapshotBefore.timing | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress) -ceq
            (@($timingLockedUpdateSnapshotAfter.timing | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress)
        if ($timingLockedUpdateMemberOpsAfter -ne
                $timingLockedUpdateMemberOpsBefore -or
            -not $timingLockedUpdateUnchanged) {
            throw "Locked Timing update reached the server or partially mutated Timing."
        }

        $memberUnlockedTimingRow = Find-ElementById `
            -ProcessId $member.Process.Id `
            -AutomationId (
                "Inspector.Timing.Row." +
                ([string]$unlockedTimingSeed.id).ToLowerInvariant()) `
            -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberUnlockedTimingRow $memberHandle
        $multiLockPhysicalActions.Add(
            "member-select-end-exclusive-timing-row")
        $timingTargetUpdateStateBefore = Get-HarnessState $endpoint
        $timingTargetUpdateSnapshotBefore =
            Get-ChartSnapshot $endpoint $owner.Token $roomId
        $timingTargetUpdateMemberOpsBefore = @(
            $timingTargetUpdateStateBefore.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        Set-ElementValue `
            $memberTimingBeatForBoundary `
            ([string]$ownerLockedTimingSeekPlan.snappedBeatText)
        Invoke-PhysicalElementClick $memberTimingApplyForBoundary $memberHandle
        $multiLockPhysicalActions.Add(
            "member-attempt-move-unlocked-timing-into-owner-lock")
        $observations.memberLockedTimingTargetStatus = Observe-Element $memberStatus
        if ([string]$memberStatus.Current.Name -notlike
                "*应用 Timing / Effect 失败*" -or
            [string]$memberStatus.Current.Name -notlike
                "*房主锁定选区*") {
            throw "Timing update into the lock did not expose the precise target rejection."
        }
        Start-Sleep -Milliseconds 900
        $timingTargetUpdateStateAfter = Get-HarnessState $endpoint
        $timingTargetUpdateSnapshotAfter =
            Get-ChartSnapshot $endpoint $owner.Token $roomId
        $timingTargetUpdateMemberOpsAfter = @(
            $timingTargetUpdateStateAfter.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $timingTargetUpdateUnchanged =
            (@($timingTargetUpdateSnapshotBefore.timing | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress) -ceq
            (@($timingTargetUpdateSnapshotAfter.timing | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress)
        if ($timingTargetUpdateMemberOpsAfter -ne
                $timingTargetUpdateMemberOpsBefore -or
            -not $timingTargetUpdateUnchanged) {
            throw "Timing update into the owner lock reached the server or partially committed."
        }

        Invoke-PhysicalElementClick $memberLockedTimingRow $memberHandle
        $multiLockPhysicalActions.Add(
            "member-reselect-owner-locked-timing-before-delete")
        $memberTimingDeleteForBoundary = Find-VisibleElementById `
            -ProcessId $member.Process.Id `
            -AutomationId "Inspector.Timing.Delete" `
            -TimeoutMilliseconds 10000
        $timingLockedDeleteStateBefore = Get-HarnessState $endpoint
        $timingLockedDeleteSnapshotBefore =
            Get-ChartSnapshot $endpoint $owner.Token $roomId
        $timingLockedDeleteMemberOpsBefore = @(
            $timingLockedDeleteStateBefore.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        Invoke-PhysicalElementClick $memberTimingDeleteForBoundary $memberHandle
        $multiLockPhysicalActions.Add(
            "member-attempt-delete-owner-locked-timing")
        $observations.memberLockedTimingDeleteStatus = Observe-Element $memberStatus
        Start-Sleep -Milliseconds 900
        $timingLockedDeleteStateAfter = Get-HarnessState $endpoint
        $timingLockedDeleteSnapshotAfter =
            Get-ChartSnapshot $endpoint $owner.Token $roomId
        $timingLockedDeleteMemberOpsAfter = @(
            $timingLockedDeleteStateAfter.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $timingLockedDeleteUnchanged =
            (@($timingLockedDeleteSnapshotBefore.timing | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress) -ceq
            (@($timingLockedDeleteSnapshotAfter.timing | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress)
        if ($timingLockedDeleteMemberOpsAfter -ne
                $timingLockedDeleteMemberOpsBefore -or
            -not $timingLockedDeleteUnchanged -or
            [string]$observations.memberLockedTimingDeleteStatus.name -notlike
                "*没有可删除的 Timing / Effect 条目*") {
            throw "Locked Timing delete did not remain an exact source-filtered no-op."
        }

        # SelectionItemPattern only establishes the second row in the existing
        # WPF-style multi-selection. The delete command itself remains a visible
        # physical button click; shortcuts/focus parity is intentionally deferred.
        Add-ElementToSelection $memberUnlockedTimingRow
        Wait-Condition -Description "two Timing rows selected for mixed delete" `
            -Seconds 10 -Condition {
                [int](Get-TimelineLiveState $member.Process.Id).selectedTimingCount -eq 2
            }
        $timingMixedDeleteStateBefore = Get-HarnessState $endpoint
        $timingMixedDeleteSnapshotBefore =
            Get-ChartSnapshot $endpoint $owner.Token $roomId
        $timingMixedDeleteMemberOpsBefore = @(
            $timingMixedDeleteStateBefore.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        Invoke-PhysicalElementClick $memberTimingDeleteForBoundary $memberHandle
        $multiLockPhysicalActions.Add(
            "member-delete-mixed-locked-unlocked-timing-selection")
        $timingMixedDeleteStateAfter = Wait-HarnessState $endpoint {
            param($state)
            @($state.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count -gt
                $timingMixedDeleteMemberOpsBefore
        } "member mixed Timing delete accepted once"
        $timingMixedDeleteSnapshotAfter =
            Get-ChartSnapshot $endpoint $owner.Token $roomId
        $timingMixedDeleteMemberOpsAfter = @(
            $timingMixedDeleteStateAfter.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $lockedTimingRemains = @($timingMixedDeleteSnapshotAfter.timing |
            Where-Object { [string]$_.id -ceq [string]$lockedTimingSeed.id }).Count -eq 1
        $unlockedTimingRemoved = @($timingMixedDeleteSnapshotAfter.timing |
            Where-Object { [string]$_.id -ceq [string]$unlockedTimingSeed.id }).Count -eq 0
        if ($timingMixedDeleteMemberOpsAfter -ne
                $timingMixedDeleteMemberOpsBefore + 1 -or
            -not $lockedTimingRemains -or
            -not $unlockedTimingRemoved -or
            @($timingMixedDeleteSnapshotAfter.timing).Count -ne
                @($timingMixedDeleteSnapshotBefore.timing).Count - 1) {
            throw "Mixed Timing delete did not remove exactly the unlocked source row."
        }
        $observations.memberMixedTimingDeleteStatus = Observe-Element $memberStatus
        $captures.memberTimingLockBoundaries = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-timing-lock-boundaries.png")

        $memberUndoAfterTimingDelete = Find-ElementById `
            -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickUndo" `
            -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberUndoAfterTimingDelete $memberHandle
        $multiLockPhysicalActions.Add(
            "member-undo-mixed-timing-delete")
        $timingMixedDeleteUndoState = Wait-HarnessState $endpoint {
            param($state)
            @($state.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count -gt
                $timingMixedDeleteMemberOpsAfter
        } "member mixed Timing delete undo accepted"
        $timingMixedDeleteUndoSnapshot =
            Get-ChartSnapshot $endpoint $owner.Token $roomId
        $timingMixedDeleteUndoMemberOpsAfter = @(
            $timingMixedDeleteUndoState.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $timingMixedDeleteUndoRestored =
            (@($timingMixedDeleteSnapshotBefore.timing | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress) -ceq
            (@($timingMixedDeleteUndoSnapshot.timing | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress)
        if (-not $timingMixedDeleteUndoRestored) {
            throw "Undo after mixed Timing delete did not restore the exact Timing structure."
        }
        $captures.memberTimingMixedDeleteUndone = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-timing-mixed-delete-undone.png")

        $ownerTimingDeleteForCleanup = Find-VisibleElementById `
            -ProcessId $owner.Process.Id `
            -AutomationId "Inspector.Timing.Delete" `
            -TimeoutMilliseconds 10000
        $timingCleanupStateBefore = Get-HarnessState $endpoint
        $timingCleanupOwnerOpsBefore = @(
            $timingCleanupStateBefore.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4101 }).Count
        $ownerLockedTimingRowForCleanup = Find-ElementById `
            -ProcessId $owner.Process.Id `
            -AutomationId (
                "Inspector.Timing.Row." +
                ([string]$lockedTimingSeed.id).ToLowerInvariant()) `
            -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerLockedTimingRowForCleanup $ownerHandle
        Invoke-PhysicalElementClick $ownerTimingDeleteForCleanup $ownerHandle
        $multiLockPhysicalActions.Add(
            "owner-delete-locked-timing-seed-after-boundary-gate")
        $timingCleanupFirstState = Wait-HarnessState $endpoint {
            param($state)
            @($state.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4101 }).Count -gt
                $timingCleanupOwnerOpsBefore
        } "owner first Timing seed cleanup"
        $timingCleanupFirstOwnerOps = @(
            $timingCleanupFirstState.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4101 }).Count
        $ownerUnlockedTimingRowForCleanup = Find-ElementById `
            -ProcessId $owner.Process.Id `
            -AutomationId (
                "Inspector.Timing.Row." +
                ([string]$unlockedTimingSeed.id).ToLowerInvariant()) `
            -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerUnlockedTimingRowForCleanup $ownerHandle
        Invoke-PhysicalElementClick $ownerTimingDeleteForCleanup $ownerHandle
        $multiLockPhysicalActions.Add(
            "owner-delete-end-exclusive-timing-seed-after-boundary-gate")
        $timingCleanupFinalState = Wait-HarnessState $endpoint {
            param($state)
            @($state.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4101 }).Count -gt
                $timingCleanupFirstOwnerOps
        } "owner second Timing seed cleanup"
        $timingCleanupSnapshot = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $timingSeedsRemoved =
            @($timingCleanupSnapshot.timing | Where-Object {
                    [string]$_.id -ceq [string]$lockedTimingSeed.id -or
                    [string]$_.id -ceq [string]$unlockedTimingSeed.id
                }).Count -eq 0
        if (-not $timingSeedsRemoved -or
            @($timingCleanupSnapshot.timing).Count -ne
                @($timingSeedSnapshotBefore.timing).Count) {
            throw "Owner cleanup did not remove exactly the two Timing boundary seeds."
        }
        Wait-Condition -Description "member removed Timing seed labels before Note marquee" `
            -Seconds 30 -Condition {
                [int](Get-TimelineLiveState $member.Process.Id).creatorAttributedTimingCount -eq
                    @($timingSeedSnapshotBefore.timing).Count
            }

        $memberNoteTab = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Inspector.NoteTab" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberNoteTab $memberHandle
        $multiLockPhysicalActions.Add("member-return-note-inspector-after-locked-timing")
        $captures.memberLockedPlacementTailTiming = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-locked-placement-tail-timing.png")

        # WPF source-lock parity: a mixed marquee may contain locked and unlocked
        # Notes. Quick Mirror must submit only visible unlocked sources, while all
        # locked rows and every unrelated row remain byte-for-byte unchanged.
        $snapshotBeforeMixedMirror = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $memberLiveBeforeMixedMirror = Get-TimelineLiveState $member.Process.Id
        $memberPixelsPerBeat = [double]$memberLiveBeforeMixedMirror.pixelsPerBeat
        $memberTimelineGeometry = $memberRoomRuntime.timeline.geometry
        $memberViewportTopBeat = [double]$memberLiveBeforeMixedMirror.currentBeat +
            ([double]$memberTimelineGeometry.judgmentLineYWindowDip -
                [double]$memberTimelineGeometry.topWindowDip) / $memberPixelsPerBeat
        $memberViewportBottomBeat = [double]$memberLiveBeforeMixedMirror.currentBeat -
            ([double]$memberTimelineGeometry.bottomWindowDip -
                [double]$memberTimelineGeometry.judgmentLineYWindowDip) / $memberPixelsPerBeat
        $memberVisualHalfBeat = [Math]::Max(.065, 14.0 / $memberPixelsPerBeat)
        $memberVisibleObjects = @(
            foreach ($note in @($snapshotBeforeMixedMirror.notes)) {
                if ([bool]$note.isDraft) { continue }
                $startValue = [double]$note.beat.bar +
                    [double]$note.beat.numerator / [double]$note.beat.denominator
                $endValue = if ($null -ne $note.endBeat) {
                    [double]$note.endBeat.bar +
                        [double]$note.endBeat.numerator / [double]$note.endBeat.denominator
                } else { $startValue }
                $visualStart = [Math]::Min($startValue, $endValue) - $memberVisualHalfBeat
                $visualEnd = [Math]::Max($startValue, $endValue) + $memberVisualHalfBeat
                if ($visualEnd -lt $memberViewportBottomBeat -or
                    $visualStart -gt $memberViewportTopBeat) { continue }
                $isPoint = [Math]::Abs($endValue - $startValue) -lt .000000001
                $sourceLocked = if ($isPoint) {
                    $startValue -ge $lockStartValue -and $startValue -lt $lockEndValue
                } else {
                    $startValue -lt $lockEndValue -and $endValue -gt $lockStartValue
                }
                [pscustomobject]@{
                    note = $note
                    lane = [int]$note.lane
                    startValue = $startValue
                    endValue = $endValue
                    visualStart = $visualStart
                    visualEnd = $visualEnd
                    sourceLocked = [bool]$sourceLocked
                }
            })
        $lockedVisibleObjects = @($memberVisibleObjects | Where-Object sourceLocked)
        $unlockedVisibleObjects = @($memberVisibleObjects | Where-Object { -not $_.sourceLocked })
        if ($lockedVisibleObjects.Count -eq 0 -or $unlockedVisibleObjects.Count -eq 0) {
            throw "The member viewport did not expose both locked and unlocked real Notes for mixed-source mirror."
        }
        $lockedLower = [double](($lockedVisibleObjects | Measure-Object startValue -Minimum).Minimum) - .105
        $lockedUpper = [double](($lockedVisibleObjects | Measure-Object endValue -Maximum).Maximum) + .105
        $mixedMarqueeCandidates = @(
            foreach ($candidate in $unlockedVisibleObjects) {
                $lowerBeat = [Math]::Min($lockedLower, [double]$candidate.startValue - .105)
                $upperBeat = [Math]::Max($lockedUpper, [double]$candidate.endValue + .105)
                if ($lowerBeat -le $memberViewportBottomBeat + .14 -or
                    $upperBeat -ge $memberViewportTopBeat - .14) { continue }
                $hits = @($memberVisibleObjects | Where-Object {
                        [double]$_.visualStart -le $upperBeat -and
                        [double]$_.visualEnd -ge $lowerBeat
                    })
                $lockedHits = @($hits | Where-Object sourceLocked)
                $editableHits = @($hits | Where-Object { -not $_.sourceLocked })
                if ($lockedHits.Count -eq 0 -or $editableHits.Count -eq 0 -or
                    $hits.Count -gt 18) { continue }
                [pscustomobject]@{
                    lowerBeat = $lowerBeat
                    upperBeat = $upperBeat
                    width = $upperBeat - $lowerBeat
                    hits = $hits
                    lockedHits = $lockedHits
                    editableHits = $editableHits
                }
            })
        $mixedMarqueePlan = @($mixedMarqueeCandidates |
                Sort-Object @{ Expression = { @($_.hits).Count } }, width |
                Select-Object -First 1)[0]
        if ($null -eq $mixedMarqueePlan) {
            throw "No bounded member marquee could combine owner-locked and unlocked real Notes."
        }

        $memberScale = [double]$memberRoomRuntime.window.screenScaling
        $memberProGeometry = $memberRoomRuntime.timeline.proEditor.geometry
        $mixedMarqueeStartX = [int][Math]::Round(
            [double]$memberRoomRuntime.window.positionXPixels +
            ([double]$memberProGeometry.officialTrackLeftWindowDip - 2) * $memberScale)
        $mixedMarqueeEndX = [int][Math]::Round(
            [double]$memberRoomRuntime.window.positionXPixels +
            ([double]$memberProGeometry.officialTrackRightWindowDip - 4) * $memberScale)
        $memberJudgmentY = [double]$memberRoomRuntime.window.positionYPixels +
            [double]$memberTimelineGeometry.judgmentLineYWindowDip * $memberScale
        $mixedMarqueeStartY = [int][Math]::Round(
            $memberJudgmentY -
            ([double]$mixedMarqueePlan.lowerBeat -
                [double]$memberLiveBeforeMixedMirror.currentBeat) *
            $memberPixelsPerBeat * $memberScale)
        $mixedMarqueeEndY = [int][Math]::Round(
            $memberJudgmentY -
            ([double]$mixedMarqueePlan.upperBeat -
                [double]$memberLiveBeforeMixedMirror.currentBeat) *
            $memberPixelsPerBeat * $memberScale)
        Invoke-PhysicalDrag $mixedMarqueeStartX $mixedMarqueeStartY `
            $mixedMarqueeEndX $mixedMarqueeEndY $memberHandle
        $multiLockPhysicalActions.Add("member-marquee-locked-and-unlocked-real-notes")
        Wait-Condition -Description "member mixed locked/unlocked marquee selection" -Seconds 15 -Condition {
            $live = Get-TimelineLiveState $member.Process.Id
            [int]$live.selectedNoteCount -gt @($lockedVisibleObjects).Count -and
            [int]$live.selectedTimingCount -eq 0
        }
        $memberLiveAfterMixedSelection = Get-TimelineLiveState $member.Process.Id
        $expectedEditableSourceCount =
            [int]$memberLiveAfterMixedSelection.selectedNoteCount -
            @($lockedVisibleObjects).Count
        if ($expectedEditableSourceCount -le 0) {
            throw "The physical mixed marquee selected no unlocked source Note."
        }

        $memberQuickPaletteToggle = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickPalette.Toggle" -TimeoutMilliseconds 10000
        if ([string]$memberQuickPaletteToggle.Current.Name -ceq "+") {
            Invoke-PhysicalElementClick $memberQuickPaletteToggle $memberHandle
            $multiLockPhysicalActions.Add("member-expand-quick-palette-for-mixed-mirror")
        }
        $memberCopyButton = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickCopy" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberCopyButton $memberHandle
        $multiLockPhysicalActions.Add("member-copy-mixed-locked-unlocked-selection")
        $memberPasteButton = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickPaste" -TimeoutMilliseconds 10000
        if (-not $memberPasteButton.Current.IsEnabled) {
            throw "Mixed selection copy did not enable Quick Paste."
        }
        $memberTimelineForLockedPaste = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Timeline.Surface" -TimeoutMilliseconds 10000
        $memberLiveBeforeLockedPasteSeek = Get-TimelineLiveState $member.Process.Id
        $lockedPasteSeekPlan = Get-LockedGridSeekPlan `
            -CurrentBeat ([double]$memberLiveBeforeLockedPasteSeek.currentBeat) `
            -Division $memberSnapDivision `
            -LockStart $lockStartValue `
            -LockEnd $lockEndValue
        $lockedPasteWheelNotches = [int]$lockedPasteSeekPlan.wheelNotches
        Invoke-PhysicalElementWheel $memberTimelineForLockedPaste `
            $lockedPasteWheelNotches $memberHandle
        if ($lockedPasteWheelNotches -ne 0) {
            $multiLockPhysicalActions.Add(
                "member-wheel-redline-to-reachable-owner-lock-grid-for-paste")
        }
        Wait-Condition -Description "member red line at reachable owner-lock grid for paste" `
            -Seconds 15 -PollMilliseconds 50 -Condition {
                [Math]::Abs(
                    [double](Get-TimelineLiveState $member.Process.Id).currentBeat -
                    [double]$lockedPasteSeekPlan.expectedCurrentBeat) -lt .0000001
            }
        $lockedPasteStateBefore = Get-HarnessState $endpoint
        $lockedPasteSnapshotBefore = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $lockedPasteMemberOpsBefore = @(
            $lockedPasteStateBefore.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        Invoke-PhysicalElementClick $memberPasteButton $memberHandle
        $multiLockPhysicalActions.Add("member-attempt-mixed-paste-at-owner-lock-start")
        $observations.memberLockedPasteImmediateStatus = Observe-Element $memberStatus
        Start-Sleep -Milliseconds 900
        $lockedPasteStateAfter = Get-HarnessState $endpoint
        $lockedPasteSnapshotAfter = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $lockedPasteMemberOpsAfter = @(
            $lockedPasteStateAfter.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $lockedPasteNotesUnchanged =
            (@($lockedPasteSnapshotBefore.notes | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress) -ceq
            (@($lockedPasteSnapshotAfter.notes | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress)
        $lockedPasteTimingUnchanged =
            (@($lockedPasteSnapshotBefore.timing | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress) -ceq
            (@($lockedPasteSnapshotAfter.timing | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress)
        if ($lockedPasteMemberOpsAfter -ne $lockedPasteMemberOpsBefore -or
            -not $lockedPasteNotesUnchanged -or -not $lockedPasteTimingUnchanged) {
            throw "Mixed paste at the owner-lock start reached the server or partially mutated the chart."
        }
        $captures.memberLockedMixedPaste = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-locked-mixed-paste.png")

        $memberMirrorButton = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickMirror" -TimeoutMilliseconds 10000
        if (-not $memberMirrorButton.Current.IsEnabled) {
            throw "Member Quick Mirror was disabled for a mixed locked/unlocked Note selection."
        }
        $mixedMirrorStateBefore = Get-HarnessState $endpoint
        $memberOperationCountBeforeMixedMirror = @(
            $mixedMirrorStateBefore.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        Invoke-PhysicalElementClick $memberMirrorButton $memberHandle
        $multiLockPhysicalActions.Add("member-quick-mirror-mixed-source-selection")
        $observations.memberMixedMirrorImmediateStatus = Observe-Element $memberStatus
        $mixedMirrorStateAfter = Wait-HarnessState $endpoint {
            param($state)
            @($state.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count -gt
                $memberOperationCountBeforeMixedMirror
        } "member mixed-source mirror accepted once"
        $snapshotAfterMixedMirror = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $beforeById = @{}
        foreach ($note in @($snapshotBeforeMixedMirror.notes)) {
            $beforeById[[string]$note.id] = $note
        }
        $candidateEditableIds = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal)
        foreach ($item in @($mixedMarqueePlan.editableHits)) {
            [void]$candidateEditableIds.Add([string]$item.note.id)
        }
        $lockedIds = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal)
        foreach ($item in @($mixedMarqueePlan.lockedHits)) {
            [void]$lockedIds.Add([string]$item.note.id)
        }
        $changedIds = [Collections.Generic.List[string]]::new()
        $unexpectedChangedIds = [Collections.Generic.List[string]]::new()
        $keyCount = [int]$snapshotBeforeMixedMirror.keyCount
        foreach ($after in @($snapshotAfterMixedMirror.notes)) {
            $id = [string]$after.id
            $before = $beforeById[$id]
            if ($null -eq $before) {
                $unexpectedChangedIds.Add($id)
                continue
            }
            if ($candidateEditableIds.Contains($id)) {
                if ((Get-OnlineNoteIdentityJson $before) -ceq
                    (Get-OnlineNoteIdentityJson $after)) {
                    # The geometry plan is deliberately a superset. Stable
                    # SelectedNoteCount below determines how many unlocked rows
                    # were actually inside Avalonia's exact note bounds.
                    continue
                }
                $sourceColumn = if ([bool]$before.isDraft) {
                    [int]$before.draftColumn
                } else { [int]$before.lane }
                $targetColumn = $keyCount - 1 - $sourceColumn
                $expectedDraft = $targetColumn -lt 0 -or $targetColumn -ge $keyCount
                $expectedLane = if ($expectedDraft) { 0 } else { $targetColumn }
                $expectedDraftColumn = if ($expectedDraft) { $targetColumn } else { 0 }
                $payloadPreserved =
                    ($before.beat | ConvertTo-Json -Depth 5 -Compress) -ceq
                        ($after.beat | ConvertTo-Json -Depth 5 -Compress) -and
                    ($before.endBeat | ConvertTo-Json -Depth 5 -Compress) -ceq
                        ($after.endBeat | ConvertTo-Json -Depth 5 -Compress) -and
                    [string]$before.sound -ceq [string]$after.sound -and
                    [int]$before.volume -eq [int]$after.volume -and
                    [int]$before.group -eq [int]$after.group -and
                    ($before.unknownJson | ConvertTo-Json -Depth 8 -Compress) -ceq
                        ($after.unknownJson | ConvertTo-Json -Depth 8 -Compress)
                if ([bool]$after.isDraft -ne $expectedDraft -or
                    [int]$after.lane -ne $expectedLane -or
                    [int]$after.draftColumn -ne $expectedDraftColumn -or
                    -not $payloadPreserved) {
                    $unexpectedChangedIds.Add($id)
                    continue
                }
                $changedIds.Add($id)
                continue
            }
            if ((Get-OnlineNoteIdentityJson $before) -cne
                (Get-OnlineNoteIdentityJson $after)) {
                $unexpectedChangedIds.Add($id)
            }
        }
        if ($changedIds.Count -ne $expectedEditableSourceCount -or
            $unexpectedChangedIds.Count -ne 0 -or
            @($snapshotAfterMixedMirror.notes).Count -ne
                @($snapshotBeforeMixedMirror.notes).Count) {
            throw "Mixed-source mirror changed locked/unselected Notes or failed to mirror every unlocked source."
        }
        $memberOperationCountAfterMixedMirror = @(
            $mixedMirrorStateAfter.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $observations.memberMixedMirrorStatus = Observe-Element $memberStatus
        $observations.memberTimelineAfterMixedMirror = Observe-Element `
            (Find-ElementById -ProcessId $member.Process.Id -AutomationId "Timeline.Surface")
        $captures.memberMixedSourceMirror = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-mixed-source-mirror.png")

        $mixedDeleteStateBefore = Get-HarnessState $endpoint
        $mixedDeleteMemberOpsBefore = @(
            $mixedDeleteStateBefore.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $memberMixedDeleteButton = Find-VisibleElementById `
            -ProcessId $member.Process.Id `
            -AutomationId "Inspector.Note.Delete" `
            -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberMixedDeleteButton $memberHandle
        $multiLockPhysicalActions.Add("member-delete-mixed-locked-unlocked-selection")
        $mixedDeleteStateAfter = Wait-HarnessState $endpoint {
            param($state)
            @($state.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count -gt
                $mixedDeleteMemberOpsBefore
        } "member mixed-source delete accepted once"
        $mixedDeleteMemberOpsAfter = @(
            $mixedDeleteStateAfter.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $snapshotAfterMixedDelete = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $afterMirrorById = @{}
        foreach ($note in @($snapshotAfterMixedMirror.notes)) {
            $afterMirrorById[[string]$note.id] = $note
        }
        $afterDeleteById = @{}
        foreach ($note in @($snapshotAfterMixedDelete.notes)) {
            $afterDeleteById[[string]$note.id] = $note
        }
        $deletedEditableIds = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal)
        foreach ($id in $changedIds) { [void]$deletedEditableIds.Add([string]$id) }
        $mixedDeleteUnexpectedIds = [Collections.Generic.List[string]]::new()
        foreach ($entry in $afterMirrorById.GetEnumerator()) {
            $id = [string]$entry.Key
            if ($deletedEditableIds.Contains($id)) {
                if ($afterDeleteById.ContainsKey($id)) {
                    $mixedDeleteUnexpectedIds.Add($id)
                }
                continue
            }
            if (-not $afterDeleteById.ContainsKey($id) -or
                (Get-OnlineNoteIdentityJson $entry.Value) -cne
                    (Get-OnlineNoteIdentityJson $afterDeleteById[$id])) {
                $mixedDeleteUnexpectedIds.Add($id)
            }
        }
        if ($mixedDeleteMemberOpsAfter -ne $mixedDeleteMemberOpsBefore + 1 -or
            @($snapshotAfterMixedDelete.notes).Count -ne
                @($snapshotAfterMixedMirror.notes).Count - $changedIds.Count -or
            $mixedDeleteUnexpectedIds.Count -ne 0) {
            throw "Mixed-source delete did not remove exactly the unlocked selected Notes."
        }
        $observations.memberMixedDeleteStatus = Observe-Element $memberStatus
        $captures.memberMixedSourceDelete = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-mixed-source-delete.png")

        $memberUndoButton = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickUndo" -TimeoutMilliseconds 10000
        if (-not $memberUndoButton.Current.IsEnabled) {
            throw "Quick Undo was disabled after the accepted mixed-source delete."
        }
        Invoke-PhysicalElementClick $memberUndoButton $memberHandle
        $multiLockPhysicalActions.Add("member-undo-mixed-source-delete")
        $mixedDeleteUndoState = Wait-HarnessState $endpoint {
            param($state)
            @($state.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count -gt
                $mixedDeleteMemberOpsAfter
        } "member mixed-source delete undo accepted"
        $snapshotAfterMixedDeleteUndo = Get-ChartSnapshot $endpoint $owner.Token $roomId
        $mixedDeleteUndoRestored =
            (@($snapshotAfterMixedMirror.notes | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress) -ceq
            (@($snapshotAfterMixedDeleteUndo.notes | Sort-Object id) |
                ConvertTo-Json -Depth 20 -Compress)
        if (-not $mixedDeleteUndoRestored) {
            throw "Undo after mixed-source delete did not restore the exact post-mirror chart."
        }
        $mixedDeleteUndoMemberOpsAfter = @(
            $mixedDeleteUndoState.acceptedOperations |
                Where-Object { [long]$_.actorUserId -eq 4202 }).Count
        $observations.memberMixedDeleteUndoStatus = Observe-Element $memberStatus
        $captures.memberMixedDeleteUndone = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-mixed-delete-undone.png")

        $ownerSelectToolBeforeUnlock = Find-ElementById `
            -ProcessId $owner.Process.Id `
            -AutomationId "Editor.QuickTool.Select" `
            -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $ownerSelectToolBeforeUnlock $ownerHandle
        $multiLockPhysicalActions.Add(
            "owner-select-tool-before-reselecting-lock")
        foreach ($toggleId in @("Editor.QuickPalette.Toggle", "Editor.QuickValues.Toggle")) {
            $toggle = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId $toggleId -TimeoutMilliseconds 10000
            if ([string]$toggle.Current.Name -ceq "−") {
                Invoke-PhysicalElementClick $toggle $ownerHandle
                $multiLockPhysicalActions.Add("owner-collapse-$toggleId-before-reselecting-lock")
                Wait-Condition -Description "$toggleId collapsed before reselecting lock" `
                    -Seconds 10 -Condition {
                        [string](Find-ElementById -ProcessId $owner.Process.Id `
                            -AutomationId $toggleId `
                            -TimeoutMilliseconds 1000).Current.Name -ceq "+"
                    }
            }
        }
        $ownerTimelineBeforeLockReselect = Find-ElementById `
            -ProcessId $owner.Process.Id `
            -AutomationId "Timeline.Surface" `
            -TimeoutMilliseconds 10000
        $ownerLiveBeforeLockReselect = Get-TimelineLiveState $owner.Process.Id
        $ownerReselectDivision = [int]$ownerLiveBeforeLockReselect.snapDivision
        $ownerReselectTargetBeat =
            $lockStartValue + (1.0 / [double]$ownerReselectDivision)
        $ownerReselectSeekPlan = Get-ExactGridSeekPlan `
            -CurrentBeat ([double]$ownerLiveBeforeLockReselect.currentBeat) `
            -Division $ownerReselectDivision `
            -TargetBeat $ownerReselectTargetBeat
        Invoke-PhysicalElementWheel `
            $ownerTimelineBeforeLockReselect `
            ([int]$ownerReselectSeekPlan.wheelNotches) `
            $ownerHandle
        if ([int]$ownerReselectSeekPlan.wheelNotches -ne 0) {
            $multiLockPhysicalActions.Add(
                "owner-wheel-redline-to-center-original-lock-before-unlock")
        }
        Wait-Condition `
            -Description "owner red line centered for lock reselection" `
            -Seconds 15 `
            -PollMilliseconds 50 `
            -Condition {
                [Math]::Abs(
                    [double](Get-TimelineLiveState `
                        $owner.Process.Id).currentBeat -
                    [double]$ownerReselectSeekPlan.expectedCurrentBeat) -lt
                    .0000001
            }
        $ownerLiveBeforeLockReselect = Get-TimelineLiveState $owner.Process.Id
        $ownerTimelineBeforeLockReselect = Find-ElementById `
            -ProcessId $owner.Process.Id `
            -AutomationId "Timeline.Surface" `
            -TimeoutMilliseconds 10000
        $ownerTimelineReselectBounds =
            $ownerTimelineBeforeLockReselect.Current.BoundingRectangle
        $ownerTimelineLeftDip = [double]$timelineGeometry.leftWindowDip
        $ownerTimelineTopDip = [double]$timelineGeometry.topWindowDip
        $ownerReselectStartX = [int][Math]::Round(
            [double]$ownerTimelineReselectBounds.Left +
            (
                [double]$proGeometry.officialTrackLeftWindowDip -
                $ownerTimelineLeftDip -
                2.0
            ) * $scale)
        $ownerReselectEndX = [int][Math]::Round(
            [double]$ownerTimelineReselectBounds.Left +
            (
                [double]$proGeometry.officialTrackRightWindowDip -
                $ownerTimelineLeftDip -
                4.0
            ) * $scale)
        $ownerReselectJudgmentY =
            [double]$ownerTimelineReselectBounds.Top +
            (
                [double]$timelineGeometry.judgmentLineYWindowDip -
                $ownerTimelineTopDip
            ) * $scale
        $ownerReselectLowerBeat = [double]$marqueePlan.lowerBeat
        $ownerReselectUpperBeat = [double]$marqueePlan.upperBeat
        $ownerReselectStartY = [int][Math]::Round(
            $ownerReselectJudgmentY -
            ($ownerReselectLowerBeat -
                [double]$ownerLiveBeforeLockReselect.currentBeat) *
                [double]$ownerLiveBeforeLockReselect.pixelsPerBeat * $scale)
        $ownerReselectEndY = [int][Math]::Round(
            $ownerReselectJudgmentY -
            ($ownerReselectUpperBeat -
                [double]$ownerLiveBeforeLockReselect.currentBeat) *
                [double]$ownerLiveBeforeLockReselect.pixelsPerBeat * $scale)
        if ($ownerReselectStartY -lt
                [int][Math]::Floor($ownerTimelineReselectBounds.Top) -or
            $ownerReselectStartY -gt
                [int][Math]::Ceiling($ownerTimelineReselectBounds.Bottom) -or
            $ownerReselectEndY -lt
                [int][Math]::Floor($ownerTimelineReselectBounds.Top) -or
            $ownerReselectEndY -gt
                [int][Math]::Ceiling($ownerTimelineReselectBounds.Bottom)) {
            throw (
                "Centered owner lock-reselection rectangle was outside the " +
                "live TimelineSurface bounds.")
        }
        Invoke-PhysicalDrag $ownerReselectStartX $ownerReselectStartY `
            $ownerReselectEndX $ownerReselectEndY $ownerHandle
        $multiLockPhysicalActions.Add(
            "owner-reselect-same-five-notes-before-unlock")
        Wait-Condition -Description "same owner five-Note selection restored before unlock" `
            -Seconds 15 -Condition {
                $live = Get-TimelineLiveState $owner.Process.Id
                [int]$live.selectedNoteCount -eq 5 -and
                    [int]$live.selectedTimingCount -eq 0
            }
        $ownerQuickPaletteBeforeUnlock = Find-ElementById `
            -ProcessId $owner.Process.Id `
            -AutomationId "Editor.QuickPalette.Toggle" `
            -TimeoutMilliseconds 10000
        if ([string]$ownerQuickPaletteBeforeUnlock.Current.Name -ceq "+") {
            Invoke-PhysicalElementClick $ownerQuickPaletteBeforeUnlock $ownerHandle
            $multiLockPhysicalActions.Add(
                "owner-expand-quick-palette-before-unlock")
        }

        $complexDifferenceTarget = @(
            $marqueePlan.hits |
                Where-Object {
                    $null -eq $_.note.endBeat -and
                    [double]$_.startValue -gt $lockStartValue + .000000001 -and
                    [double]$_.startValue -lt $lockEndValue - .000000001
                } |
                Sort-Object startValue, lane |
                Select-Object -First 1)[0]
        if ($null -eq $complexDifferenceTarget) {
            throw "The five-Note selection exposed no internal Tap for the complex lock difference."
        }
        $ownerLiveBeforeDifference = Get-TimelineLiveState $owner.Process.Id
        $complexDifferencePoint = Get-TimelinePoint `
            $ownerRuntime `
            ([int]$complexDifferenceTarget.lane) `
            ([double]$complexDifferenceTarget.startValue -
                [double]$ownerLiveBeforeDifference.currentBeat) `
            $owner.Process.Id `
            ([double]$ownerLiveBeforeDifference.pixelsPerBeat)
        Invoke-PhysicalClick `
            $complexDifferencePoint.x `
            $complexDifferencePoint.y `
            $ownerHandle
        $multiLockPhysicalActions.Add(
            "owner-select-internal-tap-for-complex-lock-difference")
        Wait-Condition `
            -Description "single internal owner Tap selected for lock difference" `
            -Seconds 15 `
            -Condition {
                $live = Get-TimelineLiveState $owner.Process.Id
                [int]$live.selectedNoteCount -eq 1 -and
                    [int]$live.selectedTimingCount -eq 0 -and
                    [string]$live.selectedNoteId -ceq
                        [string]$complexDifferenceTarget.note.id
            }

        $script:complexDifferenceUnlockButton = $null
        Wait-Condition `
            -Description "internal covered Tap exposes unlock action" `
            -Seconds 15 `
            -Condition {
                $candidate = Find-ElementById `
                    -ProcessId $owner.Process.Id `
                    -AutomationId "Editor.QuickOwnerLock" `
                    -TimeoutMilliseconds 1000
                if ($candidate.Current.IsEnabled -and
                    [string]$candidate.Current.Name -like "*解除选区*") {
                    $script:complexDifferenceUnlockButton = $candidate
                    return $true
                }
                return $false
            }
        Invoke-PhysicalElementClick `
            $script:complexDifferenceUnlockButton `
            $ownerHandle
        $script:complexDifferenceUnlockButton = $null
        $multiLockPhysicalActions.Add(
            "owner-unlock-internal-tap-row-from-existing-continuous-lock")
        $complexDifferenceState = Wait-HarnessState $endpoint {
            param($state)
            [int]$state.lockCount -eq 2 -and
                [int]$state.lockSelectionToggleCount -eq 2 -and
                [bool](@($state.lockSelectionToggles)[1].isUnlock)
        } "complex existing lock difference retains two remnants"
        $complexDifferenceToggle =
            @($complexDifferenceState.lockSelectionToggles)[1]
        $complexDifferenceRequested =
            @($complexDifferenceToggle.requestedRanges)
        $complexDifferenceLocks = @(
            $complexDifferenceState.locks |
                Sort-Object {
                    [double]$_.startBeat.bar +
                        [double]$_.startBeat.numerator /
                        [double]$_.startBeat.denominator
                })
        if ($complexDifferenceRequested.Count -ne 1 -or
            $complexDifferenceLocks.Count -ne 2 -or
            -not (Test-ExactOnlineBeat `
                $complexDifferenceLocks[0].startBeat `
                $expectedStartBeat) -or
            -not (Test-ExactOnlineBeat `
                $complexDifferenceLocks[0].endBeat `
                $complexDifferenceRequested[0].startBeat) -or
            -not (Test-ExactOnlineBeat `
                $complexDifferenceLocks[1].startBeat `
                $complexDifferenceRequested[0].endBeat) -or
            -not (Test-ExactOnlineBeat `
                $complexDifferenceLocks[1].endBeat `
                $expectedEndBeat)) {
            throw "Internal Tap unlock did not preserve both exact outside lock remnants."
        }
        Wait-Condition `
            -Description "both clients received the two lock remnants" `
            -Seconds 30 `
            -Condition {
                [int](Get-TimelineLiveState `
                    $owner.Process.Id).ownerProtectedRegionCount -eq 2 -and
                    [int](Get-TimelineLiveState `
                        $member.Process.Id).ownerProtectedRegionCount -eq 2
            }
        $captures.ownerComplexLockDifference = Capture-Window `
            $ownerHandle `
            (Join-Path $outputFullPath "owner-complex-lock-two-remnants.png")

        $script:complexDifferenceRelockButton = $null
        Wait-Condition `
            -Description "internal unlocked Tap exposes lock action" `
            -Seconds 15 `
            -Condition {
                $candidate = Find-ElementById `
                    -ProcessId $owner.Process.Id `
                    -AutomationId "Editor.QuickOwnerLock" `
                    -TimeoutMilliseconds 1000
                if ($candidate.Current.IsEnabled -and
                    [string]$candidate.Current.Name -like "*锁定选区*") {
                    $script:complexDifferenceRelockButton = $candidate
                    return $true
                }
                return $false
            }
        Invoke-PhysicalElementClick `
            $script:complexDifferenceRelockButton `
            $ownerHandle
        $script:complexDifferenceRelockButton = $null
        $multiLockPhysicalActions.Add(
            "owner-relock-internal-tap-row-and-merge-remnants")
        $complexRelockedState = Wait-HarnessState $endpoint {
            param($state)
            [int]$state.lockCount -eq 1 -and
                [int]$state.lockSelectionToggleCount -eq 3 -and
                -not [bool](@($state.lockSelectionToggles)[2].isUnlock)
        } "complex lock difference gap merged back into one range"
        $complexRelockedLock = @($complexRelockedState.locks)[0]
        if (-not (Test-ExactOnlineBeat `
                $complexRelockedLock.startBeat `
                $expectedStartBeat) -or
            -not (Test-ExactOnlineBeat `
                $complexRelockedLock.endBeat `
                $expectedEndBeat)) {
            throw "Relocking the internal Tap did not restore the exact original continuous lock."
        }
        Wait-Condition `
            -Description "both clients received the merged continuous lock" `
            -Seconds 30 `
            -Condition {
                [int](Get-TimelineLiveState `
                    $owner.Process.Id).ownerProtectedRegionCount -eq 1 -and
                    [int](Get-TimelineLiveState `
                        $member.Process.Id).ownerProtectedRegionCount -eq 1
            }
        $captures.ownerComplexLockRelocked = Capture-Window `
            $ownerHandle `
            (Join-Path $outputFullPath "owner-complex-lock-merged-again.png")

        Invoke-PhysicalDrag $ownerReselectStartX $ownerReselectStartY `
            $ownerReselectEndX $ownerReselectEndY $ownerHandle
        $multiLockPhysicalActions.Add(
            "owner-reselect-five-notes-after-complex-lock-difference")
        Wait-Condition `
            -Description "owner five-Note selection restored after lock difference" `
            -Seconds 15 `
            -Condition {
                $live = Get-TimelineLiveState $owner.Process.Id
                [int]$live.selectedNoteCount -eq 5 -and
                    [int]$live.selectedTimingCount -eq 0
            }

        $script:multiUnlockOwnerButton = $null
        Wait-Condition -Description "enabled owner unlock action" -Seconds 15 -Condition {
            $candidate = Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "Editor.QuickOwnerLock" -TimeoutMilliseconds 1000
            if ($candidate.Current.IsEnabled -and
                [string]$candidate.Current.Name -like "*解除选区*") {
                $script:multiUnlockOwnerButton = $candidate
                return $true
            }
            return $false
        }
        $ownerLockButton = $script:multiUnlockOwnerButton
        $script:multiUnlockOwnerButton = $null
        Invoke-PhysicalElementClick $ownerLockButton $ownerHandle
        $multiLockPhysicalActions.Add("owner-unlock-same-five-note-selection")
        $unlockedState = Wait-HarnessState $endpoint {
            param($state)
            [int]$state.lockCount -eq 0 -and [int]$state.lockSelectionToggleCount -eq 4 -and
            [bool](@($state.lockSelectionToggles)[3].isUnlock)
        } "exact continuous selection unlock"
        Wait-Condition -Description "member received owner-lock removal" -Seconds 30 -Condition {
            [int](Get-TimelineLiveState $member.Process.Id).ownerProtectedRegionCount -eq 0
        }
        $unlockedState | ConvertTo-Json -Depth 60 | Set-Content `
            -LiteralPath (Join-Path $outputFullPath "server-state-multi-unlocked.json") -Encoding utf8NoBOM
        $observations.ownerUnlockAction = Observe-Element `
            (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "Editor.QuickOwnerLock")
        $captures.ownerContinuousUnlock = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-continuous-lock-removed.png")

        $finalState = Get-HarnessState $endpoint
        $finalState | ConvertTo-Json -Depth 60 | Set-Content `
            -LiteralPath $statePath -Encoding utf8NoBOM
        $screenshots = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
            $screenshots[$file.BaseName] = [ordered]@{
                path = $file.FullName
                length = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        $multiLockEvidence = [ordered]@{
            schema = "lumachart.windows.avalonia.two-client-multi-object-continuous-lock-gui-evidence.v5"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed"
            formalMigrationAuthority = $true
            completion = $false
            migrationComplete = $false
            windowsAvaloniaOnly = $true
            productionServerMutationPerformed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            multiLockOnly = $true
            automationDiagnosticNonFormal = $false
            mouseInputUsed = $true
            physicalMouseInputUsed = $true
            uiAutomationValuePatternUsedForTimingFields = $true
            uiAutomationSelectionItemPatternUsedForSecondTimingRow = $true
            chineseImeGlobalEnterEscapeHandlerAdded = $false
            paths = [ordered]@{
                projectRoot = $projectRoot
                outputRoot = $outputFullPath
                application = $applicationFullPath
                serverAssembly = $serverAssemblyFullPath
                fixture = $fixtureFullPath
                temp = $projectTemp
                dotnetHome = $dotnetHome
                nugetPackages = $nugetPackages
                nugetHttpCache = $nugetHttpCache
            }
            hashes = [ordered]@{
                application = (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
                applicationAssembly = (Get-FileHash `
                    -LiteralPath ([IO.Path]::ChangeExtension($applicationFullPath, ".dll")) `
                    -Algorithm SHA256).Hash
                serverAssembly = (Get-FileHash -LiteralPath $serverAssemblyFullPath -Algorithm SHA256).Hash
                fixture = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
            }
            selection = [ordered]@{
                realChartNoteCount = @($snapshotBeforeLock.notes).Count
                selectedNoteCount = [int]$ownerLiveAfterSelection.selectedNoteCount
                selectedTimingCount = [int]$ownerLiveAfterSelection.selectedTimingCount
                selectedNotes = @($marqueePlan.hits | ForEach-Object { $_.note })
                selectedObjectRanges = $selectedRanges
                fourLaneCoverage = [int]$marqueePlan.laneCount -eq 4
                marqueeBeatBounds = [ordered]@{
                    lower = [double]$marqueePlan.lowerBeat
                    upper = [double]$marqueePlan.upperBeat
                }
                physicalStart = [ordered]@{ x = $marqueeStartX; y = $marqueeStartY }
                physicalEnd = [ordered]@{ x = $marqueeEndX; y = $marqueeEndY }
                visibleStatus = $observations.ownerFiveNoteSelectionStatus
            }
            continuousLock = [ordered]@{
                expectedStartBeat = $expectedStartBeat
                expectedEndBeat = $expectedEndBeat
                rawRequestedRangeCount = $requestedRanges.Count
                rawRequestedRanges = $requestedRanges
                authoritativeLockCount = [int]$lockedState.lockCount
                authoritativeLock = $lock
                exactStart = $sameStart -and $rawSameStart
                exactEnd = $sameEnd -and $rawSameEnd
                ownerRegionCount = [int]$ownerLiveLocked.ownerProtectedRegionCount
                memberRegionCount = [int]$memberLiveLocked.ownerProtectedRegionCount
            }
            memberBlockedEdit = [ordered]@{
                targetNote = $blockedTarget.note
                point = $blockedPoint
                acceptedOperationCountBefore = $memberOperationCountBeforeBlockedDrag
                acceptedOperationCountAfter = $memberOperationCountAfterBlockedDrag
                serverUnaffected = $memberOperationCountAfterBlockedDrag -eq
                    $memberOperationCountBeforeBlockedDrag
                serverNoteAfter = $blockedTargetAfter
                serverNoteUnchanged = [bool]$blockedTargetUnchanged
                visibleStatus = $observations.memberBlockedStatus
                visibleInspector = $observations.memberLockedInspector
                visibleLockAction = $observations.memberLockAction
            }
            memberBlockedPlacement = [ordered]@{
                lane = [int]$placementCandidate.lane
                beatValue = [double]$placementCandidate.value
                point = $lockedPlacementPoint
                acceptedOperationCountBefore = $lockedPlacementMemberOpsBefore
                acceptedOperationCountAfter = $lockedPlacementMemberOpsAfter
                notesUnchanged = [bool]$lockedPlacementNotesUnchanged
                visibleStatus = $observations.memberLockedPlacementImmediateStatus
            }
            memberBlockedLnTail = [ordered]@{
                targetNoteId = [string]$lockedLongNote.note.id
                originalEndBeat = $lockedLongNote.note.endBeat
                point = $lockedTailPoint
                acceptedOperationCountBefore = $lockedTailMemberOpsBefore
                acceptedOperationCountAfter = $lockedTailMemberOpsAfter
                serverNoteUnchanged = [bool]$lockedTailUnchanged
                visibleStatus = $observations.memberLockedTailImmediateStatus
            }
            memberBlockedTimingAdd = [ordered]@{
                targetBeat = $lockedTimingBeatText
                redLineBeatValue = [double]$lockedTimingSeekPlan.expectedCurrentBeat
                snappedBeatValue = [double]$lockedTimingSeekPlan.snappedBeatValue
                physicalWheelNotches = $lockedTimingWheelNotches
                timingPermissionBefore = [bool]$memberBeforeLockedTimingPermission.canEditTiming
                timingPermissionAfter = [bool]$memberAfterLockedTimingPermission.canEditTiming
                bpm = 180
                acceptedOperationCountBefore = $lockedTimingMemberOpsBefore
                acceptedOperationCountAfter = $lockedTimingMemberOpsAfter
                timingUnchanged = [bool]$lockedTimingUnchanged
                visibleStatus = $observations.memberLockedTimingImmediateStatus
            }
            memberTimingLockBoundaries = [ordered]@{
                lockedSeed = $lockedTimingSeed
                endExclusiveSeed = $unlockedTimingSeed
                lockedSeedInsideHalfOpenRange =
                    $lockedTimingSeedValue -ge $lockStartValue -and
                    $lockedTimingSeedValue -lt $lockEndValue
                endExclusiveSeedOutsideLock =
                    $unlockedTimingSeedValue -ge $lockEndValue
                lockedUpdate = [ordered]@{
                    acceptedOperationCountBefore =
                        $timingLockedUpdateMemberOpsBefore
                    acceptedOperationCountAfter =
                        $timingLockedUpdateMemberOpsAfter
                    exactTimingUnchanged =
                        [bool]$timingLockedUpdateUnchanged
                    visibleStatus =
                        $observations.memberLockedTimingUpdateStatus
                }
                targetMoveIntoLock = [ordered]@{
                    requestedBeat =
                        [string]$ownerLockedTimingSeekPlan.snappedBeatText
                    acceptedOperationCountBefore =
                        $timingTargetUpdateMemberOpsBefore
                    acceptedOperationCountAfter =
                        $timingTargetUpdateMemberOpsAfter
                    exactTimingUnchanged =
                        [bool]$timingTargetUpdateUnchanged
                    visibleStatus =
                        $observations.memberLockedTimingTargetStatus
                }
                lockedDelete = [ordered]@{
                    acceptedOperationCountBefore =
                        $timingLockedDeleteMemberOpsBefore
                    acceptedOperationCountAfter =
                        $timingLockedDeleteMemberOpsAfter
                    exactTimingUnchanged =
                        [bool]$timingLockedDeleteUnchanged
                    visibleStatus =
                        $observations.memberLockedTimingDeleteStatus
                }
                mixedDelete = [ordered]@{
                    selectionItemPatternUsedForSecondRow = $true
                    acceptedOperationCountBefore =
                        $timingMixedDeleteMemberOpsBefore
                    acceptedOperationCountAfter =
                        $timingMixedDeleteMemberOpsAfter
                    lockedTimingRemains = [bool]$lockedTimingRemains
                    unlockedTimingRemoved = [bool]$unlockedTimingRemoved
                    exactSourceFiltering =
                        $lockedTimingRemains -and $unlockedTimingRemoved
                    visibleStatus =
                        $observations.memberMixedTimingDeleteStatus
                }
                undo = [ordered]@{
                    acceptedOperationCountBefore =
                        $timingMixedDeleteMemberOpsAfter
                    acceptedOperationCountAfter =
                        $timingMixedDeleteUndoMemberOpsAfter
                    exactTimingStructureRestored =
                        [bool]$timingMixedDeleteUndoRestored
                }
                ownerSeedCleanup = [ordered]@{
                    acceptedOperationCountBefore =
                        $timingCleanupOwnerOpsBefore
                    acceptedOperationCountAfter = @(
                        $timingCleanupFinalState.acceptedOperations |
                            Where-Object {
                                [long]$_.actorUserId -eq 4101
                            }).Count
                    exactTwoSeedsRemoved = [bool]$timingSeedsRemoved
                    finalTimingCount =
                        @($timingCleanupSnapshot.timing).Count
                }
            }
            memberBlockedMixedPaste = [ordered]@{
                redLineBeatValue = [double]$lockedPasteSeekPlan.expectedCurrentBeat
                snappedBeatValue = [double]$lockedPasteSeekPlan.snappedBeatValue
                physicalWheelNotches = $lockedPasteWheelNotches
                acceptedOperationCountBefore = $lockedPasteMemberOpsBefore
                acceptedOperationCountAfter = $lockedPasteMemberOpsAfter
                notesUnchanged = [bool]$lockedPasteNotesUnchanged
                timingUnchanged = [bool]$lockedPasteTimingUnchanged
                visibleStatus = $observations.memberLockedPasteImmediateStatus
            }
            memberMixedSourceMirror = [ordered]@{
                selectedNoteCount = [int]$memberLiveAfterMixedSelection.selectedNoteCount
                lockedSourceCount = $lockedIds.Count
                candidateEditableSourceCount = $candidateEditableIds.Count
                editableSourceCount = $expectedEditableSourceCount
                acceptedOperationCountBefore = $memberOperationCountBeforeMixedMirror
                acceptedOperationCountAfter = $memberOperationCountAfterMixedMirror
                accepted = $memberOperationCountAfterMixedMirror -gt
                    $memberOperationCountBeforeMixedMirror
                changedNoteIds = $changedIds.ToArray()
                unexpectedChangedNoteIds = $unexpectedChangedIds.ToArray()
                lockedAndUnselectedServerNotesUnchanged =
                    $unexpectedChangedIds.Count -eq 0
                exactSourceFiltering = $changedIds.Count -eq $expectedEditableSourceCount
                physicalStart = [ordered]@{
                    x = $mixedMarqueeStartX
                    y = $mixedMarqueeStartY
                }
                physicalEnd = [ordered]@{
                    x = $mixedMarqueeEndX
                    y = $mixedMarqueeEndY
                }
                visibleStatus = $observations.memberMixedMirrorStatus
                immediateVisibleStatus = $observations.memberMixedMirrorImmediateStatus
            }
            memberMixedSourceDelete = [ordered]@{
                editableSourceCount = $changedIds.Count
                deletedNoteIds = $changedIds.ToArray()
                acceptedOperationCountBefore = $mixedDeleteMemberOpsBefore
                acceptedOperationCountAfter = $mixedDeleteMemberOpsAfter
                unexpectedChangedNoteIds = $mixedDeleteUnexpectedIds.ToArray()
                exactSourceFiltering =
                    @($snapshotAfterMixedDelete.notes).Count -eq
                        @($snapshotAfterMixedMirror.notes).Count - $changedIds.Count -and
                    $mixedDeleteUnexpectedIds.Count -eq 0
                visibleStatus = $observations.memberMixedDeleteStatus
            }
            memberMixedDeleteUndo = [ordered]@{
                acceptedOperationCountBefore = $mixedDeleteMemberOpsAfter
                acceptedOperationCountAfter = $mixedDeleteUndoMemberOpsAfter
                exactPostMirrorChartRestored = [bool]$mixedDeleteUndoRestored
                visibleStatus = $observations.memberMixedDeleteUndoStatus
            }
            complexExistingLockDifference = [ordered]@{
                targetNote = $complexDifferenceTarget.note
                physicalPoint = $complexDifferencePoint
                requestedRange = $complexDifferenceRequested[0]
                splitToggleIndex = 2
                splitWasUnlock = [bool]$complexDifferenceToggle.isUnlock
                splitAuthoritativeLockCount =
                    [int]$complexDifferenceState.lockCount
                exactLeftRemnant = [ordered]@{
                    startBeat = $complexDifferenceLocks[0].startBeat
                    endBeat = $complexDifferenceLocks[0].endBeat
                }
                exactRightRemnant = [ordered]@{
                    startBeat = $complexDifferenceLocks[1].startBeat
                    endBeat = $complexDifferenceLocks[1].endBeat
                }
                ownerRegionCountAfterSplit = 2
                memberRegionCountAfterSplit = 2
                relockToggleIndex = 3
                relockWasUnlock =
                    [bool](@(
                        $complexRelockedState.lockSelectionToggles)[2].isUnlock)
                relockedAuthoritativeLockCount =
                    [int]$complexRelockedState.lockCount
                exactOriginalRangeRestored =
                    (Test-ExactOnlineBeat `
                        $complexRelockedLock.startBeat `
                        $expectedStartBeat) -and
                    (Test-ExactOnlineBeat `
                        $complexRelockedLock.endBeat `
                        $expectedEndBeat)
            }
            unlock = [ordered]@{
                rawToggleCount = [int]$unlockedState.lockSelectionToggleCount
                authoritativeLockCount = [int]$unlockedState.lockCount
                memberRegionCount = [int](Get-TimelineLiveState $member.Process.Id).ownerProtectedRegionCount
                reselection = [ordered]@{
                    division = $ownerReselectDivision
                    targetBeat = $ownerReselectTargetBeat
                    wheelNotches = $ownerReselectSeekPlan.wheelNotches
                    expectedCurrentBeat =
                        $ownerReselectSeekPlan.expectedCurrentBeat
                    actualCurrentBeat =
                        $ownerLiveBeforeLockReselect.currentBeat
                    lowerBeat = $ownerReselectLowerBeat
                    upperBeat = $ownerReselectUpperBeat
                    timelineBounds = [ordered]@{
                        left = $ownerTimelineReselectBounds.Left
                        top = $ownerTimelineReselectBounds.Top
                        right = $ownerTimelineReselectBounds.Right
                        bottom = $ownerTimelineReselectBounds.Bottom
                    }
                    physicalStart = [ordered]@{
                        x = $ownerReselectStartX
                        y = $ownerReselectStartY
                    }
                    physicalEnd = [ordered]@{
                        x = $ownerReselectEndX
                        y = $ownerReselectEndY
                    }
                }
                passed = [int]$unlockedState.lockCount -eq 0
            }
            physicalActions = $multiLockPhysicalActions.ToArray()
            finalServerState = $finalState
            controls = $observations
            captures = $captures
            screenshots = $screenshots
        }
        $evidencePath = Join-Path $outputFullPath "evidence.json"
        $multiLockEvidence | ConvertTo-Json -Depth 70 | Set-Content `
            -LiteralPath $evidencePath -Encoding utf8NoBOM
        Write-Output "Windows Avalonia multi-object continuous lock GUI capture: passed"
        Write-Output "Evidence: $evidencePath"
        return
    }

    if ($LifecycleOnly) {
        $lifecyclePhysicalActions = [Collections.Generic.List[string]]::new()
        $ownerStatus = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        $memberStatus = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        Wait-Condition -Description "both first-generation room charts synchronized" -Seconds 30 -Condition {
            [string]$ownerStatus.Current.Name -like "*已同步*" -and
            [string]$memberStatus.Current.Name -like "*已同步*"
        }
        $firstRoomState = Get-HarnessState $endpoint
        $firstRoomId = [string]$firstRoomState.room.id
        $firstRoomNumber = [long]$firstRoomState.room.roomNumber

        $beforeSharedPlacement = Get-ChartSnapshot $endpoint $member.Token
        $sharedKnownIds = @{}
        foreach ($note in @($beforeSharedPlacement.notes)) { $sharedKnownIds[[string]$note.id] = $true }
        $sharedPlacementLiveState = Get-TimelineLiveState $member.Process.Id
        $sharedPlacementLane = -1
        $sharedPlacementOffset = 0.0
        foreach ($offset in @(.5, .75, 1.0, 1.25, 1.5)) {
            foreach ($lane in 0..3) {
                $occupied = @($beforeSharedPlacement.notes | Where-Object {
                        if ([int]$_.lane -ne $lane) { return $false }
                        $value = [double]$_.beat.bar +
                            [double]$_.beat.numerator / [double]$_.beat.denominator
                        return [Math]::Abs(
                            $value - ([double]$sharedPlacementLiveState.currentBeat + $offset)) -lt .0000001
                    }).Count -gt 0
                if (-not $occupied) {
                    $sharedPlacementLane = $lane
                    $sharedPlacementOffset = $offset
                    break
                }
            }
            if ($sharedPlacementLane -ge 0) { break }
        }
        if ($sharedPlacementLane -lt 0) { throw "No visible free cell existed for the pre-close shared edit." }
        $memberTapTool = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickTool.Tap"
        Invoke-PhysicalElementClick $memberTapTool $memberHandle
        $lifecyclePhysicalActions.Add("member-select-tap-before-close")
        $sharedPlacementPoint = Get-TimelinePoint $memberRoomRuntime $sharedPlacementLane `
            $sharedPlacementOffset $member.Process.Id ([double]$sharedPlacementLiveState.pixelsPerBeat)
        Invoke-PhysicalClick $sharedPlacementPoint.x $sharedPlacementPoint.y $memberHandle
        $lifecyclePhysicalActions.Add("member-place-shared-note-before-close")
        $afterSharedCommit = Wait-HarnessState $endpoint {
            param($state)
            @($state.acceptedOperations | Where-Object { [long]$_.actorUserId -eq 4202 }).Count -ge 1
        } "member shared operation before owner close"
        $beforeCloseSnapshot = Get-ChartSnapshot $endpoint $owner.Token
        $sharedNotes = @(
            $beforeCloseSnapshot.notes | Where-Object { -not $sharedKnownIds.ContainsKey([string]$_.id) })
        if ($sharedNotes.Count -ne 1) {
            throw "The pre-close member edit did not create exactly one shared Note."
        }
        $sharedNote = $sharedNotes[0]
        Wait-Condition -Description "both clients synchronized before owner close" -Seconds 30 -Condition {
            [string]$ownerStatus.Current.Name -like "*已同步*" -and
            [string]$memberStatus.Current.Name -like "*已同步*"
        }
        $captures.ownerBeforeRoomClose = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-before-room-close.png")
        $captures.memberBeforeRoomClose = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-before-room-close.png")

        $ownerCommunity = Open-Community $owner
        $ownerCommunityHandle = [IntPtr]$ownerCommunity.Current.NativeWindowHandle
        Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineCommunity.Navigation.Rooms")
        $ownerLeave = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Active.Leave" -TimeoutMilliseconds 15000
        if ([string]$ownerLeave.Current.Name -cne "关闭房间") {
            throw "Owner room action label was '$($ownerLeave.Current.Name)' instead of '关闭房间'."
        }
        Invoke-PhysicalElementClick $ownerLeave $ownerCommunityHandle
        $lifecyclePhysicalActions.Add("owner-open-close-confirmation")
        $exitDialog = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.ExitDialog" -TimeoutMilliseconds 10000
        $exitDialogHandle = [IntPtr]$exitDialog.Current.NativeWindowHandle
        $exitTitle = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.ExitDialog.Title"
        $exitMessage = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.ExitDialog.Message"
        if ([string]$exitTitle.Current.Name -cne "关闭联机房间" -or
            [string]$exitMessage.Current.Name -notlike "*其他成员会离开*当前谱面不会关闭*") {
            throw "Owner close confirmation did not match the WPF lifecycle warning."
        }
        $observations.ownerCloseAction = Observe-Element $ownerLeave
        $observations.ownerCloseDialogTitle = Observe-Element $exitTitle
        $observations.ownerCloseDialogMessage = Observe-Element $exitMessage
        $captures.ownerCloseConfirmation = Capture-Window $exitDialogHandle `
            (Join-Path $outputFullPath "owner-close-confirmation.png")
        $exitCancel = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.ExitDialog.Cancel"
        Invoke-PhysicalElementClick $exitCancel $exitDialogHandle
        $lifecyclePhysicalActions.Add("owner-cancel-close-once")
        Wait-Condition -Description "owner close confirmation cancellation" -Seconds 10 -Condition {
            try {
                [void](Find-ElementById -ProcessId $owner.Process.Id `
                    -AutomationId "OnlineRooms.ExitDialog" -TimeoutMilliseconds 250)
                return $false
            }
            catch { return $true }
        }
        $afterCancelState = Get-HarnessState $endpoint
        if (-not [bool]$afterCancelState.roomCreated -or [int]$afterCancelState.ownerCloseCount -ne 0) {
            throw "Cancelling the owner close confirmation changed server room state."
        }

        $ownerLeave = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Active.Leave"
        Invoke-PhysicalElementClick $ownerLeave $ownerCommunityHandle
        $lifecyclePhysicalActions.Add("owner-reopen-close-confirmation")
        $exitDialog = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.ExitDialog" -TimeoutMilliseconds 10000
        $exitDialogHandle = [IntPtr]$exitDialog.Current.NativeWindowHandle
        $exitConfirm = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.ExitDialog.Confirm"
        if ([string]$exitConfirm.Current.Name -cne "关闭房间") {
            throw "Owner confirmation action did not expose the WPF '关闭房间' label."
        }
        Invoke-PhysicalElementClick $exitConfirm $exitDialogHandle
        $lifecyclePhysicalActions.Add("owner-confirm-room-close")
        $afterCloseState = Wait-HarnessState $endpoint {
            param($state)
            -not [bool]$state.roomCreated -and [int]$state.ownerCloseCount -eq 1 -and
            @($state.activeMemberIds).Count -eq 0 -and
            @($state.roomLifecycleEvents | Where-Object { [string]$_.action -ceq "owner-closed" }).Count -eq 1
        } "owner close and all-member eviction"
        Close-Community $owner

        $ownerRetainedTab = Find-ElementByIdAndNameLike -ProcessId $owner.Process.Id `
            -AutomationId "Editor.ChartTab" -Like "*房间留存*" -TimeoutMilliseconds 40000
        $memberRetainedTab = Find-ElementByIdAndNameLike -ProcessId $member.Process.Id `
            -AutomationId "Editor.ChartTab" -Like "*房间留存*" -TimeoutMilliseconds 40000
        $observations.ownerRetainedTabAfterClose = Observe-Element $ownerRetainedTab
        $observations.memberRetainedTabAfterClose = Observe-Element $memberRetainedTab
        $captures.ownerRetainedAfterClose = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-retained-after-close.png")
        $captures.memberRetainedAfterClose = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-retained-after-close.png")

        $ownerRetainedChartPath = [string]$ownerRuntime.chart.sourcePath
        $memberRetainedChartPath = $memberRoomChartPath
        $ownerHashBeforeLocal = (Get-FileHash -LiteralPath $ownerRetainedChartPath -Algorithm SHA256).Hash
        $memberHashBeforeLocal = (Get-FileHash -LiteralPath $memberRetainedChartPath -Algorithm SHA256).Hash
        $retainedKnownIds = @{}
        foreach ($note in @($beforeCloseSnapshot.notes)) { $retainedKnownIds[[string]$note.id] = $true }

        $ownerLocalLive = Get-TimelineLiveState $owner.Process.Id
        $localPlacementOffsets = @(.375, .5, .625, .75, .875, 1.0, 1.125, 1.25, 1.375, 1.5, 1.625, 1.75, 1.875, 2.0)
        $ownerPreferredLanes = @(
            (($sharedPlacementLane + 1) % 4),
            (($sharedPlacementLane + 2) % 4),
            (($sharedPlacementLane + 3) % 4),
            $sharedPlacementLane)
        $ownerLocalPlacement = Find-FreeTimelineTapPlacement `
            -Notes @($beforeCloseSnapshot.notes) `
            -CurrentBeat ([double]$ownerLocalLive.currentBeat) `
            -PreferredLanes $ownerPreferredLanes `
            -Offsets $localPlacementOffsets
        $ownerLocalLane = [int]$ownerLocalPlacement.lane
        $ownerLocalOffset = [double]$ownerLocalPlacement.offset
        $ownerTapTool = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.QuickTool.Tap"
        Invoke-PhysicalElementClick $ownerTapTool $ownerHandle
        $lifecyclePhysicalActions.Add("owner-select-local-tap-after-close")
        $ownerLocalPoint = Get-TimelinePoint $ownerRuntime $ownerLocalLane $ownerLocalOffset `
            $owner.Process.Id ([double]$ownerLocalLive.pixelsPerBeat)
        Invoke-PhysicalClick $ownerLocalPoint.x $ownerLocalPoint.y $ownerHandle
        $lifecyclePhysicalActions.Add("owner-local-tap-after-close")
        Wait-Condition -Description "owner retained local Note selection" -Seconds 15 -Condition {
            $id = [string](Get-TimelineLiveState $owner.Process.Id).selectedNoteId
            -not [string]::IsNullOrWhiteSpace($id) -and -not $retainedKnownIds.ContainsKey($id)
        }
        $ownerLocalNoteId = [string](Get-TimelineLiveState $owner.Process.Id).selectedNoteId
        $retainedKnownIds[$ownerLocalNoteId] = $true

        $memberLocalLive = Get-TimelineLiveState $member.Process.Id
        $memberPreferredLanes = @(
            (($sharedPlacementLane + 2) % 4),
            (($sharedPlacementLane + 3) % 4),
            $sharedPlacementLane,
            (($sharedPlacementLane + 1) % 4))
        $memberLocalPlacement = Find-FreeTimelineTapPlacement `
            -Notes @($beforeCloseSnapshot.notes) `
            -CurrentBeat ([double]$memberLocalLive.currentBeat) `
            -PreferredLanes $memberPreferredLanes `
            -Offsets $localPlacementOffsets
        $memberLocalLane = [int]$memberLocalPlacement.lane
        $memberLocalOffset = [double]$memberLocalPlacement.offset
        $memberTapTool = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickTool.Tap"
        Invoke-PhysicalElementClick $memberTapTool $memberHandle
        $lifecyclePhysicalActions.Add("member-select-local-tap-after-close")
        $memberLocalPoint = Get-TimelinePoint $memberRoomRuntime $memberLocalLane $memberLocalOffset `
            $member.Process.Id ([double]$memberLocalLive.pixelsPerBeat)
        Invoke-PhysicalClick $memberLocalPoint.x $memberLocalPoint.y $memberHandle
        $lifecyclePhysicalActions.Add("member-local-tap-after-close")
        Wait-Condition -Description "member retained local Note selection" -Seconds 15 -Condition {
            $id = [string](Get-TimelineLiveState $member.Process.Id).selectedNoteId
            -not [string]::IsNullOrWhiteSpace($id) -and -not $retainedKnownIds.ContainsKey($id)
        }
        $memberLocalNoteId = [string](Get-TimelineLiveState $member.Process.Id).selectedNoteId
        $afterLocalEditState = Get-HarnessState $endpoint
        if ([int]$afterLocalEditState.acceptedOperationCount -ne [int]$afterCloseState.acceptedOperationCount) {
            throw "A retained local edit reached the closed room server."
        }
        Invoke-EditorSave $owner
        [void](Wait-EditorSavedState $owner.Process.Id 30)
        Invoke-EditorSave $member
        [void](Wait-EditorSavedState $member.Process.Id 30)
        $ownerHashAfterLocal = (Get-FileHash -LiteralPath $ownerRetainedChartPath -Algorithm SHA256).Hash
        $memberHashAfterLocal = (Get-FileHash -LiteralPath $memberRetainedChartPath -Algorithm SHA256).Hash
        if ($ownerHashAfterLocal -ceq $ownerHashBeforeLocal -or $memberHashAfterLocal -ceq $memberHashBeforeLocal) {
            throw "One of the retained local charts did not persist its post-close physical edit."
        }
        $captures.ownerRetainedLocalSaved = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-retained-local-saved.png")
        $captures.memberRetainedLocalSaved = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-retained-local-saved.png")

        $ownerCommunity = Open-Community $owner
        $ownerCommunityHandle = [IntPtr]$ownerCommunity.Current.NativeWindowHandle
        Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineCommunity.Navigation.Rooms")
        $recreateName = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Create.Name" -TimeoutMilliseconds 15000
        Set-ElementValue $recreateName "Windows Avalonia 房主重建房间"
        $recreateSubmit = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Create.Submit"
        Invoke-PhysicalElementClick $recreateSubmit $ownerCommunityHandle
        $lifecyclePhysicalActions.Add("owner-prepare-recreated-room-resources")
        [void](Wait-ElementName -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Create.Submit" `
            -Like "*创建并上传*" -Seconds 30)
        $recreateSubmit = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "OnlineRooms.Create.Submit"
        Invoke-PhysicalElementClick $recreateSubmit $ownerCommunityHandle
        $lifecyclePhysicalActions.Add("owner-confirm-recreate-room-from-retained-tab")
        $afterRecreate = Wait-HarnessState $endpoint {
            param($state)
            [bool]$state.roomCreated -and [int]$state.roomCreateCount -eq 2 -and
            [int]$state.ownerCloseCount -eq 1 -and [bool]$state.room.resourcesReady -and
            [long]$state.revision -ge 1 -and @($state.activeMemberIds) -contains 4101
        } "owner second room creation and chart rebind"
        $secondRoomId = [string]$afterRecreate.room.id
        $secondRoomNumber = [long]$afterRecreate.room.roomNumber
        if ($secondRoomId -ceq $firstRoomId -or $secondRoomNumber -eq $firstRoomNumber) {
            throw "The recreated room reused the first room identity."
        }
        $ownerRecreatedSnapshot = Get-ChartSnapshot $endpoint $owner.Token $secondRoomId
        $ownerLocalInRecreatedRoom = @(
            $ownerRecreatedSnapshot.notes | Where-Object { [string]$_.id -eq $ownerLocalNoteId })[0]
        $memberLocalInRecreatedRoom = @(
            $ownerRecreatedSnapshot.notes | Where-Object { [string]$_.id -eq $memberLocalNoteId })[0]
        if (-not $ownerLocalInRecreatedRoom -or $memberLocalInRecreatedRoom) {
            throw "The recreated room did not use only the owner's retained local chart as its new baseline."
        }
        $ownerReboundTab = Find-ElementByIdAndNameLike -ProcessId $owner.Process.Id `
            -AutomationId "Editor.ChartTab" -Like "*联机*" -TimeoutMilliseconds 40000
        $observations.ownerReboundTab = Observe-Element $ownerReboundTab
        $captures.ownerRecreatedAndRebound = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-recreated-and-rebound.png")

        $memberWorkspacePath = Join-Path $member.Editing "desktop-workspace\workspace.json"
        $memberCommunity = Open-Community $member
        $memberCommunityHandle = [IntPtr]$memberCommunity.Current.NativeWindowHandle
        Invoke-Element (Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineCommunity.Navigation.Rooms")
        $memberSecondJoin = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineRooms.Room.$secondRoomNumber.Join" -TimeoutMilliseconds 30000
        Invoke-PhysicalElementClick $memberSecondJoin $memberCommunityHandle
        $lifecyclePhysicalActions.Add("member-open-second-room-join")
        $memberSecondSubmit = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "OnlineRooms.Join.Submit" -TimeoutMilliseconds 10000
        Invoke-PhysicalElementClick $memberSecondSubmit $memberCommunityHandle
        $lifecyclePhysicalActions.Add("member-join-second-room")
        $afterSecondJoin = Wait-HarnessState $endpoint {
            param($state)
            [int]$state.roomCreateCount -eq 2 -and @($state.activeMemberIds) -contains 4202 -and
            [bool]$state.room.resourcesReady -and [int]$state.resourceEntryCount -ge 3
        } "member join and resource availability for recreated room"
        Wait-Condition -Description "member second room workspace persistence" -Seconds 40 -Condition {
            if (-not (Test-Path -LiteralPath $memberWorkspacePath -PathType Leaf)) { return $false }
            $workspace = Get-Content -Raw -LiteralPath $memberWorkspacePath | ConvertFrom-Json
            @($workspace.Tabs | Where-Object {
                    [string]$_.SourcePath -like "*room_$($secondRoomId.Replace('-', ''))*"
                }).Count -eq 1
        }
        $memberSecondWorkspace = Get-Content -Raw -LiteralPath $memberWorkspacePath | ConvertFrom-Json
        $memberSecondWorkspaceTab = @(
            $memberSecondWorkspace.Tabs | Where-Object {
                [string]$_.SourcePath -like "*room_$($secondRoomId.Replace('-', ''))*"
            })[0]
        $memberSecondChartPath = [string]$memberSecondWorkspaceTab.SourcePath
        if ($memberSecondChartPath -ceq $memberRetainedChartPath -or
            -not $memberSecondChartPath.Contains($secondRoomId.Replace("-", ""), [StringComparison]::OrdinalIgnoreCase)) {
            throw "Member rejoin did not create a distinct second-generation room document."
        }
        $memberSecondRoomDirectory = [IO.Path]::GetFullPath(
            (Split-Path -Parent $memberSecondChartPath))
        $memberSecondResourceFiles = [Collections.Generic.List[object]]::new()
        foreach ($resource in @($afterSecondJoin.resourceEntries)) {
            $resourcePath = [IO.Path]::GetFullPath(
                (Join-Path $memberSecondRoomDirectory ([string]$resource.path)))
            if (-not $resourcePath.StartsWith(
                    $memberSecondRoomDirectory + [IO.Path]::DirectorySeparatorChar,
                    [StringComparison]::OrdinalIgnoreCase)) {
                throw "Recreated-room resource escaped its materialized document directory."
            }
            if (-not (Test-Path -LiteralPath $resourcePath -PathType Leaf)) {
                throw "Recreated-room resource was not materialized: $resourcePath"
            }
            $resourceFile = Get-Item -LiteralPath $resourcePath
            $resourceSha256 = (Get-FileHash -LiteralPath $resourcePath -Algorithm SHA256).Hash
            if ([long]$resourceFile.Length -ne [long]$resource.length -or
                $resourceSha256 -cne ([string]$resource.sha256).ToUpperInvariant()) {
                throw "Recreated-room resource bytes differed from the server manifest: $resourcePath"
            }
            $memberSecondResourceFiles.Add([ordered]@{
                    path = $resourcePath
                    length = [long]$resourceFile.Length
                    sha256 = $resourceSha256
                })
        }
        Wait-Condition -Description "member retained and second-room tabs coexist" -Seconds 30 -Condition {
            $tabs = @(Find-ElementsById -ProcessId $member.Process.Id -AutomationId "Editor.ChartTab")
            @($tabs | Where-Object { [string]$_.Current.Name -like "*房间留存*" }).Count -ge 1 -and
            @($tabs | Where-Object { [string]$_.Current.Name -like "*联机*" }).Count -ge 1
        }
        $memberTabs = @(Find-ElementsById -ProcessId $member.Process.Id -AutomationId "Editor.ChartTab")
        $memberRetainedTabFinal = @(
            $memberTabs | Where-Object { [string]$_.Current.Name -like "*房间留存*" })[0]
        $memberRejoinedTab = @(
            $memberTabs | Where-Object { [string]$_.Current.Name -like "*联机*" })[0]
        $observations.memberRetainedTabFinal = Observe-Element $memberRetainedTabFinal
        $observations.memberRejoinedTab = Observe-Element $memberRejoinedTab
        $ownerStatus = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        $memberStatus = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        Wait-Condition -Description "both recreated-room clients synchronized" -Seconds 40 -Condition {
            [string]$ownerStatus.Current.Name -like "*已同步*" -and
            [string]$memberStatus.Current.Name -like "*已同步*"
        }

        $ownerLocalValue = [double]$ownerLocalInRecreatedRoom.beat.bar +
            [double]$ownerLocalInRecreatedRoom.beat.numerator /
            [double]$ownerLocalInRecreatedRoom.beat.denominator
        $recreatedMaximumBeat = 4.0
        foreach ($note in @($ownerRecreatedSnapshot.notes)) {
            $head = [double]$note.beat.bar +
                [double]$note.beat.numerator / [double]$note.beat.denominator
            $recreatedMaximumBeat = [Math]::Max($recreatedMaximumBeat, $head)
            if ($null -ne $note.endBeat) {
                $tail = [double]$note.endBeat.bar +
                    [double]$note.endBeat.numerator / [double]$note.endBeat.denominator
                $recreatedMaximumBeat = [Math]::Max($recreatedMaximumBeat, $tail)
            }
        }
        $recreatedMaximumBeat += 1.0
        $memberOverview = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.Overview" -TimeoutMilliseconds 10000
        $memberOverviewBounds = $memberOverview.Current.BoundingRectangle
        if ($memberOverviewBounds.Width -le 1 -or $memberOverviewBounds.Height -le 1) {
            throw "Member recreated-room density overview did not expose usable physical bounds."
        }
        $memberOverviewSeekX = [int][Math]::Round(
            $memberOverviewBounds.Left + $memberOverviewBounds.Width / 2)
        $memberOverviewSeekY = [int][Math]::Round(
            $memberOverviewBounds.Bottom -
            [Math]::Clamp($ownerLocalValue / $recreatedMaximumBeat, 0.0, 1.0) *
            $memberOverviewBounds.Height)
        Invoke-PhysicalClick $memberOverviewSeekX $memberOverviewSeekY $memberHandle
        $lifecyclePhysicalActions.Add("member-seek-owner-retained-note-via-overview")
        Start-Sleep -Milliseconds 800
        $memberAfterOverviewSeek = Get-TimelineLiveState $member.Process.Id
        if ([Math]::Abs(
                [double]$memberAfterOverviewSeek.currentBeat - $ownerLocalValue) -ge 1.0) {
            throw "Member overview seek did not expose the owner's retained Note."
        }
        $memberSelectTool = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickTool.Select"
        Invoke-PhysicalElementClick $memberSelectTool $memberHandle
        $lifecyclePhysicalActions.Add("member-select-tool-in-recreated-room")
        $memberSecondLive = $memberAfterOverviewSeek
        $ownerLocalOffsetForMember = $ownerLocalValue - [double]$memberSecondLive.currentBeat
        $ownerLocalPointForMember = Get-TimelinePoint $memberRoomRuntime `
            ([int]$ownerLocalInRecreatedRoom.lane) $ownerLocalOffsetForMember `
            $member.Process.Id ([double]$memberSecondLive.pixelsPerBeat)
        Invoke-PhysicalClick $ownerLocalPointForMember.x $ownerLocalPointForMember.y $memberHandle
        $lifecyclePhysicalActions.Add("member-select-owner-retained-note-in-recreated-room")
        Wait-Condition -Description "member local document contains recreated owner Note" -Seconds 15 -Condition {
            [string](Get-TimelineLiveState $member.Process.Id).selectedNoteId -ceq $ownerLocalNoteId
        }
        $memberSelectedOwnerLive = Get-TimelineLiveState $member.Process.Id
        if ((Get-FileHash -LiteralPath $memberRetainedChartPath -Algorithm SHA256).Hash -cne
            $memberHashAfterLocal) {
            throw "Joining the recreated room overwrote the member's retained first-generation chart."
        }
        $captures.memberRetainedAndRejoined = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-retained-and-rejoined.png")
        $captures.ownerFinalRecreatedRoom = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-final-recreated-room.png")

        $finalState = Get-HarnessState $endpoint
        $createdEvents = @($finalState.roomLifecycleEvents | Where-Object { [string]$_.action -ceq "created" })
        $closedEvents = @($finalState.roomLifecycleEvents | Where-Object { [string]$_.action -ceq "owner-closed" })
        $lifecyclePassed =
            [int]$finalState.roomCreateCount -eq 2 -and [int]$finalState.ownerCloseCount -eq 1 -and
            $createdEvents.Count -eq 2 -and $closedEvents.Count -eq 1 -and
            [string]$createdEvents[0].roomId -cne [string]$createdEvents[1].roomId -and
            [int]$afterLocalEditState.acceptedOperationCount -eq [int]$afterCloseState.acceptedOperationCount -and
            $ownerLocalInRecreatedRoom -and -not $memberLocalInRecreatedRoom -and
            [string]$memberSelectedOwnerLive.selectedNoteId -ceq $ownerLocalNoteId -and
            @($finalState.activeMemberIds) -contains 4101 -and @($finalState.activeMemberIds) -contains 4202
        if (-not $lifecyclePassed) {
            throw "Owner close, retained local editing and second-generation room rebind did not fully converge."
        }

        $finalState | ConvertTo-Json -Depth 60 | Set-Content `
            -LiteralPath $statePath -Encoding utf8NoBOM
        $screenshots = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
            $screenshots[$file.BaseName] = [ordered]@{
                path = $file.FullName
                length = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        $lifecycleEvidence = [ordered]@{
            schema = "lumachart.windows.avalonia.two-client-room-lifecycle-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed"
            formalMigrationAuthority = $true
            completion = $false
            migrationComplete = $false
            windowsAvaloniaOnly = $true
            productionServerMutationPerformed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            lifecycleOnly = $true
            automationDiagnosticNonFormal = $false
            mouseInputUsed = $true
            physicalMouseInputUsed = $true
            chineseImeGlobalEnterEscapeHandlerAdded = $false
            paths = [ordered]@{
                projectRoot = $projectRoot
                outputRoot = $outputFullPath
                application = $applicationFullPath
                serverAssembly = $serverAssemblyFullPath
                fixture = $fixtureFullPath
                temp = $projectTemp
                dotnetHome = $dotnetHome
                nugetPackages = $nugetPackages
                nugetHttpCache = $nugetHttpCache
            }
            hashes = [ordered]@{
                application = (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
                applicationAssembly = (Get-FileHash `
                    -LiteralPath ([IO.Path]::ChangeExtension($applicationFullPath, ".dll")) `
                    -Algorithm SHA256).Hash
                serverAssembly = (Get-FileHash -LiteralPath $serverAssemblyFullPath -Algorithm SHA256).Hash
                fixture = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
            }
            roomGenerations = [ordered]@{
                firstRoomId = $firstRoomId
                firstRoomNumber = $firstRoomNumber
                secondRoomId = $secondRoomId
                secondRoomNumber = $secondRoomNumber
                distinctIdentity = $firstRoomId -cne $secondRoomId -and $firstRoomNumber -ne $secondRoomNumber
                createCount = [int]$finalState.roomCreateCount
                ownerCloseCount = [int]$finalState.ownerCloseCount
                lifecycleEvents = $finalState.roomLifecycleEvents
            }
            ownerCloseConfirmation = [ordered]@{
                action = $observations.ownerCloseAction
                title = $observations.ownerCloseDialogTitle
                message = $observations.ownerCloseDialogMessage
                cancellationPreservedRoom = [bool]$afterCancelState.roomCreated -and
                    [int]$afterCancelState.ownerCloseCount -eq 0
                confirmedCloseRemovedAllActiveMembers = @($afterCloseState.activeMemberIds).Count -eq 0
            }
            preCloseSharedNote = [ordered]@{
                note = $sharedNote
                placementPoint = $sharedPlacementPoint
                acceptedOperationCount = [int]$afterSharedCommit.acceptedOperationCount
            }
            retainedLocalEditing = [ordered]@{
                serverAcceptedOperationCountBefore = [int]$afterCloseState.acceptedOperationCount
                serverAcceptedOperationCountAfter = [int]$afterLocalEditState.acceptedOperationCount
                serverUnaffected = [int]$afterCloseState.acceptedOperationCount -eq
                    [int]$afterLocalEditState.acceptedOperationCount
                owner = [ordered]@{
                    tab = $observations.ownerRetainedTabAfterClose
                    noteId = $ownerLocalNoteId
                    plannedPlacement = $ownerLocalPlacement
                    point = $ownerLocalPoint
                    chartPath = $ownerRetainedChartPath
                    sha256Before = $ownerHashBeforeLocal
                    sha256After = $ownerHashAfterLocal
                    saved = $ownerHashBeforeLocal -cne $ownerHashAfterLocal
                }
                member = [ordered]@{
                    tab = $observations.memberRetainedTabAfterClose
                    noteId = $memberLocalNoteId
                    plannedPlacement = $memberLocalPlacement
                    point = $memberLocalPoint
                    chartPath = $memberRetainedChartPath
                    sha256Before = $memberHashBeforeLocal
                    sha256After = $memberHashAfterLocal
                    saved = $memberHashBeforeLocal -cne $memberHashAfterLocal
                    unchangedAfterSecondJoin = $true
                }
            }
            recreatedRoom = [ordered]@{
                ownerReboundTab = $observations.ownerReboundTab
                ownerRetainedNoteBecameNewBaseline = $null -ne $ownerLocalInRecreatedRoom
                memberRetainedNoteExcludedFromOwnerBaseline = $null -eq $memberLocalInRecreatedRoom
                memberRetainedTab = $observations.memberRetainedTabFinal
                memberRejoinedTab = $observations.memberRejoinedTab
                memberSecondChartPath = $memberSecondChartPath
                distinctMemberRoomDocument = $memberSecondChartPath -cne $memberRetainedChartPath
                serverBlobDownloads = [int]$afterSecondJoin.downloadedBlobCount
                contentAddressedCacheReuseObserved =
                    [int]$afterSecondJoin.downloadedBlobCount -lt [int]$afterSecondJoin.resourceEntryCount
                materializedResources = $memberSecondResourceFiles.ToArray()
                memberSelectedOwnerRetainedNote =
                    [string]$memberSelectedOwnerLive.selectedNoteId -ceq $ownerLocalNoteId
                ownerStatus = Observe-Element $ownerStatus
                memberStatus = Observe-Element $memberStatus
            }
            finalConvergence = [ordered]@{
                passed = $lifecyclePassed
                finalRevision = [long]$finalState.revision
                activeMemberIds = $finalState.activeMemberIds
            }
            physicalActions = $lifecyclePhysicalActions.ToArray()
            finalServerState = $finalState
            controls = $observations
            captures = $captures
            screenshots = $screenshots
        }
        $lifecycleEvidencePath = Join-Path $outputFullPath "evidence.json"
        $lifecycleEvidence | ConvertTo-Json -Depth 70 | Set-Content `
            -LiteralPath $lifecycleEvidencePath -Encoding utf8NoBOM
        Write-Output "Windows Avalonia two-client owner-close/recreate GUI capture: passed"
        Write-Output "Evidence: $lifecycleEvidencePath"
        return
    }

    if ($LateResponseOnly) {
        $lateResponseDelayMilliseconds = 12000
        $latePhysicalActions = [Collections.Generic.List[string]]::new()
        $ownerStatus = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        $memberStatus = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.Status" -TimeoutMilliseconds 10000
        Wait-Condition -Description "both room charts synchronized before late-response injection" `
            -Seconds 30 -Condition {
                [string]$ownerStatus.Current.Name -like "*已同步*" -and
                [string]$memberStatus.Current.Name -like "*已同步*"
            }
        $observations.ownerSynchronizedBefore = Observe-Element $ownerStatus
        $observations.memberSynchronizedBefore = Observe-Element $memberStatus

        $baselineState = Get-HarnessState $endpoint
        $baselineSnapshot = Get-ChartSnapshot $endpoint $owner.Token
        $ownerNoteBefore = @(
            $baselineSnapshot.notes | Where-Object { [string]$_.id -eq $selectedId })[0]
        if (-not $ownerNoteBefore) {
            throw "Late-response owner target $selectedId was absent from the baseline snapshot."
        }
        $ownerNoteValueBefore = [double]$ownerNoteBefore.beat.bar +
            [double]$ownerNoteBefore.beat.numerator / [double]$ownerNoteBefore.beat.denominator
        $ownerSelectTool = Find-ElementById -ProcessId $owner.Process.Id `
            -AutomationId "Editor.QuickTool.Select"
        Invoke-PhysicalElementClick $ownerSelectTool $ownerHandle
        $latePhysicalActions.Add("owner-select-tool")
        $ownerSelectLiveState = Get-TimelineLiveState $owner.Process.Id
        $ownerSelectOffset = $ownerNoteValueBefore - [double]$ownerSelectLiveState.currentBeat
        $ownerSelectPoint = Get-TimelinePoint $ownerRuntime ([int]$ownerNoteBefore.lane) `
            $ownerSelectOffset $owner.Process.Id ([double]$ownerSelectLiveState.pixelsPerBeat)
        Invoke-PhysicalClick $ownerSelectPoint.x $ownerSelectPoint.y $ownerHandle
        $latePhysicalActions.Add("owner-select-real-note")
        Wait-Condition -Description "owner real Note selection before delayed drag" -Seconds 10 -Condition {
            [string](Get-TimelineLiveState $owner.Process.Id).selectedNoteId -ceq $selectedId
        }

        [void](Set-HarnessFaults $endpoint @{
                failNextChartDeltaRequests = 0
                disconnectNextSseConnections = 0
                dropNextChartOperationResponsesAfterCommit = 0
                delayNextChartOperationResponseMilliseconds = $lateResponseDelayMilliseconds
            })
        $ownerLiveState = Get-TimelineLiveState $owner.Process.Id
        $ownerOffset = $ownerNoteValueBefore - [double]$ownerLiveState.currentBeat
        $ownerPoint = Get-TimelinePoint $ownerRuntime ([int]$ownerNoteBefore.lane) `
            $ownerOffset $owner.Process.Id ([double]$ownerLiveState.pixelsPerBeat)
        $ownerPoint.liveState = $ownerLiveState
        $ownerDragPixels = [int][Math]::Round(
            .25 * [double]$ownerLiveState.pixelsPerBeat * [double]$ownerPoint.scale)
        Invoke-PhysicalDrag $ownerPoint.x $ownerPoint.y $ownerPoint.x `
            ($ownerPoint.y - $ownerDragPixels) $ownerHandle
        $latePhysicalActions.Add("owner-drag-note-with-delayed-response")

        $afterOwnerCommit = Wait-HarnessState $endpoint {
            param($state)
            @($state.faults.chartOperationAttempts | Where-Object {
                    [int]$_.responseDelayMilliseconds -eq $lateResponseDelayMilliseconds
                }).Count -eq 1 -and
            @($state.acceptedOperations | Where-Object { [long]$_.actorUserId -eq 4101 }).Count -ge 1
        } "owner operation commit with delayed HTTP response"
        $delayedAttempt = @(
            $afterOwnerCommit.faults.chartOperationAttempts | Where-Object {
                [int]$_.responseDelayMilliseconds -eq $lateResponseDelayMilliseconds
            })[0]
        $ownerAcceptedOperation = @(
            $afterOwnerCommit.acceptedOperations | Where-Object {
                [string]$_.operationId -ceq [string]$delayedAttempt.operationId
            })[0]
        if (-not $ownerAcceptedOperation) {
            throw "The delayed owner operation was not committed before its response delay."
        }
        if (@($afterOwnerCommit.faults.chartOperationResponseCompletions | Where-Object {
                    [string]$_.operationId -ceq [string]$delayedAttempt.operationId
                }).Count -ne 0) {
            throw "The delayed owner response completed before the interleaving member edit began."
        }
        $captures.ownerDelayedResponsePending = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-delayed-response-pending.png")

        $beforeMemberPlacement = Get-ChartSnapshot $endpoint $member.Token
        $knownIds = @{}
        foreach ($note in @($beforeMemberPlacement.notes)) { $knownIds[[string]$note.id] = $true }
        $memberPlacementLiveState = Get-TimelineLiveState $member.Process.Id
        $memberCurrentBeat = [double]$memberPlacementLiveState.currentBeat
        $placementLane = -1
        $placementOffset = 0.0
        foreach ($offset in @(.5, .75, 1.0, 1.25, 1.5)) {
            foreach ($lane in 0..3) {
                $occupied = @($beforeMemberPlacement.notes | Where-Object {
                        if ([int]$_.lane -ne $lane) { return $false }
                        $value = [double]$_.beat.bar +
                            [double]$_.beat.numerator / [double]$_.beat.denominator
                        return [Math]::Abs($value - ($memberCurrentBeat + $offset)) -lt .0000001
                    }).Count -gt 0
                if (-not $occupied) {
                    $placementLane = $lane
                    $placementOffset = $offset
                    break
                }
            }
            if ($placementLane -ge 0) { break }
        }
        if ($placementLane -lt 0) {
            throw "Could not find a visible free lane/Beat for the late-response member edit."
        }
        $memberTapTool = Find-ElementById -ProcessId $member.Process.Id `
            -AutomationId "Editor.QuickTool.Tap"
        Invoke-PhysicalElementClick $memberTapTool $memberHandle
        $latePhysicalActions.Add("member-select-tap-tool-during-owner-delay")
        $placementPoint = Get-TimelinePoint $memberRoomRuntime $placementLane $placementOffset `
            $member.Process.Id ([double]$memberPlacementLiveState.pixelsPerBeat)
        Invoke-PhysicalClick $placementPoint.x $placementPoint.y $memberHandle
        $latePhysicalActions.Add("member-place-note-during-owner-delay")

        $afterMemberCommit = Wait-HarnessState $endpoint {
            param($state)
            @($state.acceptedOperations | Where-Object {
                    [long]$_.actorUserId -eq 4202 -and
                    [long]$_.revision -gt [long]$ownerAcceptedOperation.revision
                }).Count -ge 1
        } "member operation committed before delayed owner response"
        $memberAcceptedOperation = @(
            $afterMemberCommit.acceptedOperations | Where-Object {
                [long]$_.actorUserId -eq 4202 -and
                [long]$_.revision -gt [long]$ownerAcceptedOperation.revision
            } | Select-Object -Last 1)[0]
        $afterMemberPlacement = Get-ChartSnapshot $endpoint $member.Token
        $newNotes = @(
            $afterMemberPlacement.notes | Where-Object { -not $knownIds.ContainsKey([string]$_.id) })
        if ($newNotes.Count -ne 1) {
            throw "The interleaving member Tap did not create exactly one server Note; found $($newNotes.Count)."
        }
        $placedNote = $newNotes[0]
        if (@($afterMemberCommit.faults.chartOperationResponseCompletions | Where-Object {
                    [string]$_.operationId -ceq [string]$delayedAttempt.operationId
                }).Count -ne 0) {
            throw "The owner response was no longer pending when the member revision committed."
        }
        $captures.ownerInterleavedRevisionPending = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-interleaved-revision-pending.png")
        $captures.memberInterleavedRevisionCommitted = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-interleaved-revision-committed.png")

        $afterDelayedCompletion = Wait-HarnessState $endpoint {
            param($state)
            @($state.faults.chartOperationResponseCompletions | Where-Object {
                    [string]$_.operationId -ceq [string]$delayedAttempt.operationId
                }).Count -eq 1
        } "delayed owner operation response completion"
        $delayedCompletion = @(
            $afterDelayedCompletion.faults.chartOperationResponseCompletions | Where-Object {
                [string]$_.operationId -ceq [string]$delayedAttempt.operationId
            })[0]
        $completionAt = [DateTimeOffset]::Parse([string]$delayedCompletion.completedAt)
        $afterOwnerCatchUp = Wait-HarnessState $endpoint {
            param($state)
            @($state.faults.chartDeltaAttempts | Where-Object {
                    [long]$_.userId -eq 4101 -and
                    -not [bool]$_.failed -and
                    [long]$_.afterRevision -lt [long]$memberAcceptedOperation.revision -and
                    [long]$_.currentRevision -ge [long]$memberAcceptedOperation.revision -and
                    [int]$_.returnedOperationCount -ge 1 -and
                    [DateTimeOffset]::Parse([string]$_.receivedAt) -ge $completionAt
                }).Count -ge 1
        } "owner delta catch-up after stale delayed response"
        $ownerCatchUpDelta = @(
            $afterOwnerCatchUp.faults.chartDeltaAttempts | Where-Object {
                [long]$_.userId -eq 4101 -and
                -not [bool]$_.failed -and
                [long]$_.afterRevision -lt [long]$memberAcceptedOperation.revision -and
                [long]$_.currentRevision -ge [long]$memberAcceptedOperation.revision -and
                [int]$_.returnedOperationCount -ge 1 -and
                [DateTimeOffset]::Parse([string]$_.receivedAt) -ge $completionAt
            } | Select-Object -First 1)[0]
        Wait-Condition -Description "both room charts converged after delayed stale response" `
            -Seconds 30 -Condition {
                [string]$ownerStatus.Current.Name -like "*已同步*" -and
                [string]$memberStatus.Current.Name -like "*已同步*"
            }
        $observations.ownerSynchronizedAfter = Observe-Element $ownerStatus
        $observations.memberSynchronizedAfter = Observe-Element $memberStatus

        $finalSnapshot = Get-ChartSnapshot $endpoint $owner.Token
        $ownerNoteAfter = @(
            $finalSnapshot.notes | Where-Object { [string]$_.id -eq $selectedId })[0]
        $memberNoteAfter = @(
            $finalSnapshot.notes | Where-Object { [string]$_.id -eq [string]$placedNote.id })[0]
        if (-not $ownerNoteAfter -or -not $memberNoteAfter) {
            throw "The converged server snapshot lost the owner move or interleaving member Note."
        }
        $ownerNoteValueAfter = [double]$ownerNoteAfter.beat.bar +
            [double]$ownerNoteAfter.beat.numerator / [double]$ownerNoteAfter.beat.denominator
        $ownerExactMove =
            [int]$ownerNoteBefore.beat.denominator -eq [int]$ownerNoteAfter.beat.denominator -and
            [Math]::Abs(($ownerNoteValueAfter - $ownerNoteValueBefore) - .25) -lt .000000001

        Invoke-PhysicalElementClick $ownerSelectTool $ownerHandle
        $latePhysicalActions.Add("owner-reselect-tool-after-catch-up")
        $memberNoteValue = [double]$memberNoteAfter.beat.bar +
            [double]$memberNoteAfter.beat.numerator / [double]$memberNoteAfter.beat.denominator
        $ownerCatchUpLiveState = Get-TimelineLiveState $owner.Process.Id
        $memberNoteOffset = $memberNoteValue - [double]$ownerCatchUpLiveState.currentBeat
        $memberNotePoint = Get-TimelinePoint $ownerRuntime ([int]$memberNoteAfter.lane) `
            $memberNoteOffset $owner.Process.Id ([double]$ownerCatchUpLiveState.pixelsPerBeat)
        Invoke-PhysicalClick $memberNotePoint.x $memberNotePoint.y $ownerHandle
        $latePhysicalActions.Add("owner-select-member-note-after-catch-up")
        Wait-Condition -Description "owner local document contains the member Note" -Seconds 15 -Condition {
            [string](Get-TimelineLiveState $owner.Process.Id).selectedNoteId -ceq [string]$memberNoteAfter.id
        }
        $ownerSelectedMemberLiveState = Get-TimelineLiveState $owner.Process.Id
        $captures.ownerConvergedMemberNoteSelected = Capture-Window $ownerHandle `
            (Join-Path $outputFullPath "owner-converged-member-note-selected.png")
        $captures.memberConverged = Capture-Window $memberHandle `
            (Join-Path $outputFullPath "member-converged.png")

        $finalState = Get-HarnessState $endpoint
        $ownerAttemptCount = @(
            $finalState.faults.chartOperationAttempts | Where-Object {
                [string]$_.operationId -ceq [string]$delayedAttempt.operationId
            }).Count
        $ownerCompletionCount = @(
            $finalState.faults.chartOperationResponseCompletions | Where-Object {
                [string]$_.operationId -ceq [string]$delayedAttempt.operationId
            }).Count
        $ownerCommitCount = @(
            $finalState.acceptedOperations | Where-Object {
                [string]$_.operationId -ceq [string]$delayedAttempt.operationId
            }).Count
        $memberCommitBeforeCompletion =
            [DateTimeOffset]::Parse([string]$memberAcceptedOperation.createdAt) -lt $completionAt
        $staleAtCompletion =
            [long]$delayedCompletion.responseRevision -eq [long]$ownerAcceptedOperation.revision -and
            [long]$delayedCompletion.serverRevisionAtCompletion -ge [long]$memberAcceptedOperation.revision
        $lateResponsePassed =
            $memberCommitBeforeCompletion -and $staleAtCompletion -and
            $ownerAttemptCount -eq 1 -and $ownerCompletionCount -eq 1 -and $ownerCommitCount -eq 1 -and
            $ownerExactMove -and
            [string]$ownerSelectedMemberLiveState.selectedNoteId -ceq [string]$memberNoteAfter.id -and
            [long]$ownerCatchUpDelta.currentRevision -ge [long]$memberAcceptedOperation.revision
        if (-not $lateResponsePassed) {
            throw "Late-response interleaving did not preserve exactly-once commit and final client convergence."
        }

        $finalState | ConvertTo-Json -Depth 50 | Set-Content `
            -LiteralPath $statePath -Encoding utf8NoBOM
        $screenshots = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
            $screenshots[$file.BaseName] = [ordered]@{
                path = $file.FullName
                length = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        $lateEvidence = [ordered]@{
            schema = "lumachart.windows.avalonia.two-client-late-response-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed"
            formalMigrationAuthority = $true
            completion = $false
            migrationComplete = $false
            windowsAvaloniaOnly = $true
            productionServerMutationPerformed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            pureDotnetRelease = $true
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
            lateResponseOnly = $true
            automationDiagnosticNonFormal = $false
            mouseInputUsed = $true
            physicalMouseInputUsed = $true
            chineseImeGlobalEnterEscapeHandlerAdded = $false
            delayMilliseconds = $lateResponseDelayMilliseconds
            paths = [ordered]@{
                projectRoot = $projectRoot
                outputRoot = $outputFullPath
                application = $applicationFullPath
                serverAssembly = $serverAssemblyFullPath
                fixture = $fixtureFullPath
                temp = $projectTemp
                dotnetHome = $dotnetHome
                nugetPackages = $nugetPackages
                nugetHttpCache = $nugetHttpCache
            }
            hashes = [ordered]@{
                application = (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
                applicationAssembly = (Get-FileHash `
                    -LiteralPath ([IO.Path]::ChangeExtension($applicationFullPath, ".dll")) `
                    -Algorithm SHA256).Hash
                serverAssembly = (Get-FileHash -LiteralPath $serverAssemblyFullPath -Algorithm SHA256).Hash
                fixture = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
            }
            endpoint = $endpoint
            processIds = [ordered]@{
                server = $server.Id
                owner = $owner.Process.Id
                member = $member.Process.Id
            }
            chronology = [ordered]@{
                baselineRevision = [long]$baselineState.revision
                ownerAttempt = $delayedAttempt
                ownerAcceptedOperation = $ownerAcceptedOperation
                memberAcceptedOperation = $memberAcceptedOperation
                memberCommittedBeforeOwnerResponseCompleted = $memberCommitBeforeCompletion
                delayedResponseCompletion = $delayedCompletion
                delayedResponseWasStaleAtCompletion = $staleAtCompletion
                ownerCatchUpDelta = $ownerCatchUpDelta
            }
            exactlyOnce = [ordered]@{
                ownerOperationAttemptCount = $ownerAttemptCount
                ownerOperationResponseCompletionCount = $ownerCompletionCount
                ownerAcceptedCommitCount = $ownerCommitCount
                passed = $ownerAttemptCount -eq 1 -and
                    $ownerCompletionCount -eq 1 -and $ownerCommitCount -eq 1
            }
            exactRationalOwnerMove = [ordered]@{
                noteId = $selectedId
                before = $ownerNoteBefore.beat
                after = $ownerNoteAfter.beat
                expectedDelta = .25
                actualDelta = $ownerNoteValueAfter - $ownerNoteValueBefore
                denominatorPreserved =
                    [int]$ownerNoteBefore.beat.denominator -eq [int]$ownerNoteAfter.beat.denominator
                passed = $ownerExactMove
            }
            interleavingMemberNote = [ordered]@{
                note = $memberNoteAfter
                placementPoint = $placementPoint
                ownerSelectionPoint = $memberNotePoint
                ownerLocalSelectedNoteId = [string]$ownerSelectedMemberLiveState.selectedNoteId
                ownerLocalDocumentContainsNote =
                    [string]$ownerSelectedMemberLiveState.selectedNoteId -ceq [string]$memberNoteAfter.id
            }
            finalConvergence = [ordered]@{
                ownerStatus = $observations.ownerSynchronizedAfter
                memberStatus = $observations.memberSynchronizedAfter
                finalRevision = [long]$finalState.revision
                ownerMovePresent = $null -ne $ownerNoteAfter
                memberNotePresent = $null -ne $memberNoteAfter
                passed = $lateResponsePassed
            }
            physicalActions = $latePhysicalActions.ToArray()
            finalFaultState = $finalState.faults
            controls = $observations
            captures = $captures
            screenshots = $screenshots
        }
        $lateEvidencePath = Join-Path $outputFullPath "evidence.json"
        $lateEvidence | ConvertTo-Json -Depth 60 | Set-Content `
            -LiteralPath $lateEvidencePath -Encoding utf8NoBOM
        Write-Output "Windows Avalonia two-client late-response GUI capture: passed"
        Write-Output "Evidence: $lateEvidencePath"
        return
    }

    $frozenSoundName = "Resound - Nhato.ogg"
    $frozenSourcePath = Join-Path (Split-Path -Parent $owner.InputChart) $frozenSoundName
    if (-not (Test-Path -LiteralPath $frozenSourcePath -PathType Leaf)) {
        throw "The real frozen Note Sound fixture is missing: $frozenSourcePath"
    }
    $expectedFrozenSoundHash = (Get-FileHash -LiteralPath $frozenSourcePath -Algorithm SHA256).Hash
    $beforeFrozenSound = Get-ChartSnapshot $endpoint $owner.Token
    $frozenTargetBefore = @($beforeFrozenSound.notes | Where-Object { [string]$_.id -eq $selectedId })[0]
    if (-not $frozenTargetBefore) { throw "Frozen Note Sound target $selectedId was absent from server state." }
    $runtimeTargetMatchesRoomBind =
        [int]$frozenTargetBefore.lane -eq [int]$selected.lane -and
        [int]$frozenTargetBefore.beat.bar -eq [int]$selected.beat.bar -and
        [int]$frozenTargetBefore.beat.numerator -eq [int]$selected.beat.numerator -and
        [int]$frozenTargetBefore.beat.denominator -eq [int]$selected.beat.denominator
    if (-not $runtimeTargetMatchesRoomBind) {
        throw "Room binding changed the selected Note identity before the frozen Sound interaction."
    }
    $frozenTargetIdentityBeforeSelection = Get-OnlineNoteIdentityJson $frozenTargetBefore
    $frozenTargetNonSoundIdentityBeforeAssignment =
        Get-OnlineNoteNonSoundIdentityJson $frozenTargetBefore
    $targetBeatValue = [double]$frozenTargetBefore.beat.bar +
        [double]$frozenTargetBefore.beat.numerator / [double]$frozenTargetBefore.beat.denominator
    $memberTargetLiveState = Get-TimelineLiveState $member.Process.Id
    $memberTargetOffset = $targetBeatValue - [double]$memberTargetLiveState.currentBeat
    $memberTargetPoint = Get-TimelinePoint `
        $memberRoomRuntime ([int]$frozenTargetBefore.lane) $memberTargetOffset `
        $member.Process.Id ([double]$memberTargetLiveState.pixelsPerBeat)
    Invoke-Element (Find-ElementById -ProcessId $member.Process.Id -AutomationId "Editor.QuickTool.Select")
    Invoke-PhysicalClick $memberTargetPoint.x $memberTargetPoint.y $memberHandle
    Start-Sleep -Milliseconds 500
    $afterMemberSelection = Get-ChartSnapshot $endpoint $member.Token
    $frozenTargetAfterMemberSelection = @(
        $afterMemberSelection.notes | Where-Object { [string]$_.id -eq $selectedId })[0]
    if ((Get-OnlineNoteIdentityJson $frozenTargetAfterMemberSelection) -cne
        $frozenTargetIdentityBeforeSelection) {
        throw "Selecting the frozen Sound target changed its non-Sound fields before assignment."
    }
    $memberSoundBox = Find-ElementById -ProcessId $member.Process.Id -AutomationId "Inspector.Note.Sound"
    if (-not $memberSoundBox.Current.IsEnabled) {
        throw "The member could not select the owner Note for frozen-resource synchronization."
    }

    $resourceStateBeforeSound = Get-HarnessState $endpoint
    $operationCountBeforeSound = [int]$resourceStateBeforeSound.acceptedOperationCount
    $ownerSoundButton = Find-ElementById -ProcessId $owner.Process.Id -AutomationId "Inspector.Note.SoundExisting"
    Invoke-Element $ownerSoundButton
    $ownerSoundItem = Find-ElementByName -ProcessId $owner.Process.Id -Name $frozenSoundName -TimeoutMilliseconds 10000
    Invoke-PhysicalElementClick $ownerSoundItem $ownerHandle
    Wait-Condition -Description "owner frozen Note Sound operation" -Seconds 30 -Condition {
        $snapshot = Get-ChartSnapshot $endpoint $owner.Token
        $note = @($snapshot.notes | Where-Object { [string]$_.id -eq $selectedId })[0]
        return $note -and [string]$note.sound -ceq $frozenSoundName
    }
    [void](Wait-ElementValue $member.Process.Id "Inspector.Note.Sound" $frozenSoundName 30)
    $ownerFrozenPath = Join-Path $outputFullPath "owner-frozen-note-sound.png"
    $memberRemoteFrozenPath = Join-Path $outputFullPath "member-remote-frozen-note-sound.png"
    $captures.ownerFrozenNoteSound = Capture-Window $ownerHandle $ownerFrozenPath
    $captures.memberRemoteFrozenNoteSound = Capture-Window $memberHandle $memberRemoteFrozenPath

    $memberSoundButton = Find-ElementById -ProcessId $member.Process.Id -AutomationId "Inspector.Note.SoundExisting"
    Invoke-Element $memberSoundButton
    $memberClearSound = Find-ElementByName -ProcessId $member.Process.Id `
        -Name "清除当前 Note 的 Key 音引用" -TimeoutMilliseconds 10000
    Invoke-PhysicalElementClick $memberClearSound $memberHandle
    Wait-Condition -Description "member frozen Note Sound clear operation" -Seconds 30 -Condition {
        $snapshot = Get-ChartSnapshot $endpoint $member.Token
        $note = @($snapshot.notes | Where-Object { [string]$_.id -eq $selectedId })[0]
        return $note -and $null -eq $note.sound
    }
    [void](Wait-ElementValue $owner.Process.Id "Inspector.Note.Sound" "" 30)

    Invoke-Element $memberSoundButton
    $memberSoundItem = Find-ElementByName -ProcessId $member.Process.Id -Name $frozenSoundName -TimeoutMilliseconds 10000
    Invoke-PhysicalElementClick $memberSoundItem $memberHandle
    Wait-Condition -Description "member frozen Note Sound re-assignment" -Seconds 30 -Condition {
        $snapshot = Get-ChartSnapshot $endpoint $member.Token
        $note = @($snapshot.notes | Where-Object { [string]$_.id -eq $selectedId })[0]
        return $note -and [string]$note.sound -ceq $frozenSoundName
    }
    [void](Wait-ElementValue $owner.Process.Id "Inspector.Note.Sound" $frozenSoundName 30)
    $memberAssignedFrozenPath = Join-Path $outputFullPath "member-assigned-frozen-note-sound.png"
    $captures.memberAssignedFrozenNoteSound = Capture-Window $memberHandle $memberAssignedFrozenPath

    $resourceStateAfterSound = Get-HarnessState $endpoint
    $afterBidirectionalSound = Get-ChartSnapshot $endpoint $owner.Token
    $frozenTargetAfter = @($afterBidirectionalSound.notes | Where-Object { [string]$_.id -eq $selectedId })[0]
    $materializedSoundPath = Join-Path (Split-Path -Parent $memberRoomChartPath) $frozenSoundName
    $memberWorkingSoundFiles = @(Get-ChildItem -LiteralPath $member.Editing -File -Recurse -Filter $frozenSoundName)
    $ownerWorkingSoundFiles = @(Get-ChildItem -LiteralPath $owner.Editing -File -Recurse -Filter $frozenSoundName)
    $materializedHash = if (Test-Path -LiteralPath $materializedSoundPath -PathType Leaf) {
        (Get-FileHash -LiteralPath $materializedSoundPath -Algorithm SHA256).Hash
    } else { $null }
    $memberWorkingHashes = @($memberWorkingSoundFiles | ForEach-Object {
        [ordered]@{ path = $_.FullName; length = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
    $ownerWorkingHashes = @($ownerWorkingSoundFiles | ForEach-Object {
        [ordered]@{ path = $_.FullName; length = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
    $soundOperationCountAfter = [int]$resourceStateAfterSound.acceptedOperationCount
    $soundAssignmentsPreservedIdentity =
        (Get-OnlineNoteNonSoundIdentityJson $frozenTargetAfter) -ceq
        $frozenTargetNonSoundIdentityBeforeAssignment
    $resourceUploadUnchanged =
        [int]$resourceStateBeforeSound.uploadedBlobCount -eq [int]$resourceStateAfterSound.uploadedBlobCount -and
        [int]$resourceStateBeforeSound.resourceCommitCount -eq [int]$resourceStateAfterSound.resourceCommitCount
    $allWorkingHashesMatch = $memberWorkingHashes.Count -ge 1 -and $ownerWorkingHashes.Count -ge 1 -and
        @($memberWorkingHashes | Where-Object { [string]$_.sha256 -cne $expectedFrozenSoundHash }).Count -eq 0 -and
        @($ownerWorkingHashes | Where-Object { [string]$_.sha256 -cne $expectedFrozenSoundHash }).Count -eq 0
    if (-not $resourceUploadUnchanged -or
        $soundOperationCountAfter -lt $operationCountBeforeSound + 3 -or
        -not $frozenTargetAfter -or [string]$frozenTargetAfter.sound -cne $frozenSoundName -or
        -not $soundAssignmentsPreservedIdentity -or
        [string]$materializedHash -cne $expectedFrozenSoundHash -or
        -not $allWorkingHashesMatch) {
        throw "Frozen Note Sound did not preserve the uploaded resource or bidirectional operation chain."
    }
    $frozenNoteSoundEvidence = [ordered]@{
        noteId = $selectedId
        sound = $frozenSoundName
        sourcePath = $frozenSourcePath
        sourceSha256 = $expectedFrozenSoundHash
        serverNoteAfterBidirectionalAssignment = $frozenTargetAfter
        serverNoteIdentityBeforeSelection = $frozenTargetIdentityBeforeSelection
        serverNoteNonSoundIdentityBeforeAssignment =
            $frozenTargetNonSoundIdentityBeforeAssignment
        serverNoteAfterMemberSelection = $frozenTargetAfterMemberSelection
        roomBindingPreservedRuntimeTarget = $runtimeTargetMatchesRoomBind
        soundAssignmentsPreservedIdentity = $soundAssignmentsPreservedIdentity
        memberMaterializedPath = $materializedSoundPath
        memberMaterializedSha256 = $materializedHash
        ownerWorkingFiles = $ownerWorkingHashes
        memberWorkingFiles = $memberWorkingHashes
        ownerPhysicalSelection = $true
        memberPhysicalClearAndSelection = $true
        memberRemoteInspectorObserved = $true
        ownerRemoteInspectorObserved = $true
        ownerInspectorValue = Get-ElementValue (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "Inspector.Note.Sound")
        memberInspectorValue = Get-ElementValue (Find-ElementById -ProcessId $member.Process.Id -AutomationId "Inspector.Note.Sound")
        acceptedOperationCountBefore = $operationCountBeforeSound
        acceptedOperationCountAfter = $soundOperationCountAfter
        expectedMinimumNewOperations = 3
        uploadedBlobCountBefore = [int]$resourceStateBeforeSound.uploadedBlobCount
        uploadedBlobCountAfter = [int]$resourceStateAfterSound.uploadedBlobCount
        resourceCommitCountBefore = [int]$resourceStateBeforeSound.resourceCommitCount
        resourceCommitCountAfter = [int]$resourceStateAfterSound.resourceCommitCount
        resourceUploadUnchanged = $resourceUploadUnchanged
        exactBytesOnBothClients = $allWorkingHashesMatch -and [string]$materializedHash -ceq $expectedFrozenSoundHash
    }

    $ownerStateBeforeMove = Get-HarnessState $endpoint
    $ownerOperationCountBeforeMove = @(
        $ownerStateBeforeMove.acceptedOperations |
            Where-Object { [long]$_.actorUserId -eq 4101 }).Count
    $beforeOwnerMove = Get-ChartSnapshot $endpoint $owner.Token
    $serverNoteBefore = @($beforeOwnerMove.notes | Where-Object { [string]$_.id -eq $selectedId })[0]
    if (-not $serverNoteBefore) { throw "Selected owner Note $selectedId was absent from server state." }
    $beforeValue = [double]$serverNoteBefore.beat.bar +
        [double]$serverNoteBefore.beat.numerator / [double]$serverNoteBefore.beat.denominator
    $ownerLiveState = Get-TimelineLiveState $owner.Process.Id
    if ([string]$ownerLiveState.selectedNoteId -cne $selectedId) {
        throw "Owner Timeline UIA selected '$($ownerLiveState.selectedNoteId)' instead of '$selectedId'."
    }
    $ownerOffset = $beforeValue - [double]$ownerLiveState.currentBeat
    $ownerPoint = Get-TimelinePoint $ownerRuntime ([int]$serverNoteBefore.lane) `
        $ownerOffset $owner.Process.Id ([double]$ownerLiveState.pixelsPerBeat)
    $ownerPoint.liveState = $ownerLiveState
    $ownerDragPixels = [int][Math]::Round(
        .25 * [double]$ownerLiveState.pixelsPerBeat * [double]$ownerPoint.scale)
    Invoke-PhysicalDrag $ownerPoint.x $ownerPoint.y $ownerPoint.x ($ownerPoint.y - $ownerDragPixels) $ownerHandle
    $afterOwnerMoveState = Wait-HarnessState $endpoint {
        param($state)
        @($state.acceptedOperations | Where-Object { [long]$_.actorUserId -eq 4101 }).Count `
            -gt $ownerOperationCountBeforeMove
    } "owner chart delta"
    $afterOwnerMove = Get-ChartSnapshot $endpoint $owner.Token
    $serverNoteAfter = @($afterOwnerMove.notes | Where-Object { [string]$_.id -eq $selectedId })[0]
    $afterValue = [double]$serverNoteAfter.beat.bar +
        [double]$serverNoteAfter.beat.numerator / [double]$serverNoteAfter.beat.denominator
    $exactBeatEvidence = [ordered]@{
        noteId = $selectedId
        before = $serverNoteBefore.beat
        after = $serverNoteAfter.beat
        expectedDelta = .25
        actualDelta = $afterValue - $beforeValue
        denominatorPreserved = [int]$serverNoteBefore.beat.denominator -eq [int]$serverNoteAfter.beat.denominator
        exactValuePassed = [Math]::Abs(($afterValue - $beforeValue) - .25) -lt 0.000000001
        realMouseDrag = $true
        point = $ownerPoint
    }
    if (-not $exactBeatEvidence.denominatorPreserved -or -not $exactBeatEvidence.exactValuePassed -or
        [string]$serverNoteAfter.sound -cne $frozenSoundName) {
        throw "Owner Note drag did not preserve the authored rational denominator, exact +1/4 Beat and frozen Sound."
    }

    $beforeMemberPlacement = Get-ChartSnapshot $endpoint $member.Token
    $knownIds = @{}
    foreach ($note in @($beforeMemberPlacement.notes)) { $knownIds[[string]$note.id] = $true }
    $memberPlacementLiveState = Get-TimelineLiveState $member.Process.Id
    $currentBeat = [double]$memberPlacementLiveState.currentBeat
    $placementLane = -1
    $placementOffset = 0.0
    foreach ($offset in @(.5, .75, 1.0, 1.25, 1.5)) {
        foreach ($lane in 0..3) {
            $occupied = @($beforeMemberPlacement.notes | Where-Object {
                    if ([int]$_.lane -ne $lane) { return $false }
                    $value = [double]$_.beat.bar +
                        [double]$_.beat.numerator / [double]$_.beat.denominator
                    return [Math]::Abs($value - ($currentBeat + $offset)) -lt .0000001
                }).Count -gt 0
            if (-not $occupied) { $placementLane = $lane; $placementOffset = $offset; break }
        }
        if ($placementLane -ge 0) { break }
    }
    if ($placementLane -lt 0) { throw "Could not find a visible free lane/Beat for member placement." }
    $memberStateBeforePlacement = Get-HarnessState $endpoint
    $memberOperationCountBeforePlacement = @(
        $memberStateBeforePlacement.acceptedOperations |
            Where-Object { [long]$_.actorUserId -eq 4202 }).Count
    Invoke-Element (Find-ElementById -ProcessId $member.Process.Id -AutomationId "Editor.QuickTool.Tap")
    $placementPoint = Get-TimelinePoint $memberRoomRuntime $placementLane $placementOffset `
        $member.Process.Id ([double]$memberPlacementLiveState.pixelsPerBeat)
    Invoke-PhysicalClick $placementPoint.x $placementPoint.y $memberHandle
    $afterMemberPlacementState = Wait-HarnessState $endpoint {
        param($state)
        @($state.acceptedOperations | Where-Object { [long]$_.actorUserId -eq 4202 }).Count `
            -gt $memberOperationCountBeforePlacement
    } "member Tap placement delta"
    $afterMemberPlacement = Get-ChartSnapshot $endpoint $member.Token
    $newNotes = @($afterMemberPlacement.notes | Where-Object { -not $knownIds.ContainsKey([string]$_.id) })
    if ($newNotes.Count -ne 1) { throw "Member Tap did not create exactly one server Note; found $($newNotes.Count)." }
    $placedNote = $newNotes[0]
    $placedValue = [double]$placedNote.beat.bar +
        [double]$placedNote.beat.numerator / [double]$placedNote.beat.denominator
    Invoke-Element (Find-ElementById -ProcessId $member.Process.Id -AutomationId "Editor.QuickTool.Select")
    $memberSelectLiveState = Get-TimelineLiveState $member.Process.Id
    $placedOffset = $placedValue - [double]$memberSelectLiveState.currentBeat
    $placedPoint = Get-TimelinePoint $memberRoomRuntime ([int]$placedNote.lane) $placedOffset `
        $member.Process.Id ([double]$memberSelectLiveState.pixelsPerBeat)
    Invoke-PhysicalClick $placedPoint.x $placedPoint.y $memberHandle
    Start-Sleep -Milliseconds 250
    $memberOperationCountBeforeMove = @(
        $afterMemberPlacementState.acceptedOperations |
            Where-Object { [long]$_.actorUserId -eq 4202 }).Count
    $memberMoveLiveState = Get-TimelineLiveState $member.Process.Id
    if ([string]$memberMoveLiveState.selectedNoteId -cne [string]$placedNote.id) {
        throw "Member Timeline UIA selected '$($memberMoveLiveState.selectedNoteId)' instead of '$($placedNote.id)'."
    }
    $placedOffset = $placedValue - [double]$memberMoveLiveState.currentBeat
    $placedPoint = Get-TimelinePoint $memberRoomRuntime ([int]$placedNote.lane) $placedOffset `
        $member.Process.Id ([double]$memberMoveLiveState.pixelsPerBeat)
    $placedPoint.liveState = $memberMoveLiveState
    $memberDragPixels = [int][Math]::Round(
        .25 * [double]$memberMoveLiveState.pixelsPerBeat * [double]$placedPoint.scale)
    Invoke-PhysicalDrag $placedPoint.x $placedPoint.y $placedPoint.x ($placedPoint.y - $memberDragPixels) $memberHandle
    $afterMemberMoveState = Wait-HarnessState $endpoint {
        param($state)
        @($state.acceptedOperations | Where-Object { [long]$_.actorUserId -eq 4202 }).Count `
            -gt $memberOperationCountBeforeMove
    } "member selected Note drag delta"
    $afterMemberMove = Get-ChartSnapshot $endpoint $member.Token
    $movedMemberNote = @($afterMemberMove.notes | Where-Object { [string]$_.id -eq [string]$placedNote.id })[0]
    $memberPlacementEvidence = [ordered]@{
        noteId = [string]$placedNote.id
        placed = $placedNote
        moved = $movedMemberNote
        placementPoint = $placementPoint
        movePoint = $placedPoint
        realTapClick = $true
        realSelectAndDrag = $true
    }

    $ownerLockButton = Find-ElementById -ProcessId $owner.Process.Id -AutomationId "Editor.QuickOwnerLock"
    Invoke-Element $ownerLockButton
    $lockedState = Wait-HarnessState $endpoint { param($state) [int]$state.lockCount -eq 1 } "owner precise selection lock"
    $lockedState | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $outputFullPath "server-state-locked.json") -Encoding utf8NoBOM
    $observations.ownerLockArmed = Observe-Element (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "Editor.QuickOwnerLock")
    $ownerLockPath = Join-Path $outputFullPath "owner-editor-locked.png"
    $captures.ownerLocked = Capture-Window $ownerHandle $ownerLockPath
    Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "Editor.QuickOwnerLock")
    $unlockedState = Wait-HarnessState $endpoint { param($state) [int]$state.lockCount -eq 0 } "owner precise selection unlock"
    $unlockedState | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $outputFullPath "server-state-unlocked.json") -Encoding utf8NoBOM

    Invoke-EditorSave $owner
    [void](Wait-EditorSavedState $owner.Process.Id 30)
    Invoke-EditorSave $member
    [void](Wait-EditorSavedState $member.Process.Id 30)

    $memberCommunity = Open-Community $member
    Invoke-Element (Find-ElementById -ProcessId $member.Process.Id -AutomationId "OnlineCommunity.Navigation.Rooms")
    Set-ElementValue (Find-ElementById -ProcessId $member.Process.Id -AutomationId "OnlineRooms.Active.ChatText" -TimeoutMilliseconds 20000) `
        "来自 Windows Avalonia 成员 B 的真实消息"
    Invoke-Element (Find-ElementById -ProcessId $member.Process.Id -AutomationId "OnlineRooms.Active.ChatSend")
    [void](Wait-HarnessState $endpoint { param($state) [int]$state.chatCount -ge 1 } "member chat message")
    Close-Community $member

    $ownerCommunity = Open-Community $owner
    Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineCommunity.Navigation.Rooms")
    Set-ElementValue (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineRooms.Active.ChatText" -TimeoutMilliseconds 20000) `
        "来自 Windows Avalonia 房主 A 的真实消息"
    Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineRooms.Active.ChatSend")
    [void](Wait-HarnessState $endpoint { param($state) [int]$state.chatCount -ge 2 } "owner chat message")
    Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineRooms.Active.Refresh")
    Start-Sleep -Milliseconds 750
    $ownerChatPath = Join-Path $outputFullPath "owner-room-chat.png"
    $captures.ownerChat = Capture-Window $ownerHandle $ownerChatPath

    Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineRooms.Active.Snapshots")
    $snapshotName = Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineRooms.Snapshots.Name" -TimeoutMilliseconds 20000
    Set-ElementValue $snapshotName "双客户端 revision 验收快照"
    Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineRooms.Snapshots.Create")
    [void](Wait-HarnessState $endpoint { param($state) [int]$state.savedSnapshotCount -ge 1 } "manual room snapshot")
    $rollback = Find-ElementByIdPrefix -ProcessId $owner.Process.Id -Prefix "OnlineRooms.Snapshot." -Suffix ".Rollback" -TimeoutMilliseconds 20000
    $ownerSnapshotsPath = Join-Path $outputFullPath "owner-room-snapshots.png"
    $captures.ownerSnapshots = Capture-Window $ownerHandle $ownerSnapshotsPath
    Invoke-Element $rollback
    Start-Sleep -Milliseconds 250
    Invoke-Element $rollback
    $afterRollback = Wait-HarnessState $endpoint {
        param($state)
        [int]$state.savedSnapshotCount -ge 2 -and [int]$state.acceptedOperationCount -ge 3
    } "room rollback with safety snapshot and retained operation audit"
    $afterRollback | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $outputFullPath "server-state-after-rollback.json") -Encoding utf8NoBOM
    Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineRooms.Snapshots.Back")
    $manageMember = Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineRooms.Member.4202.Manage" -TimeoutMilliseconds 20000
    Invoke-Element $manageMember
    foreach ($id in @(
            "OnlineRooms.Member.Role", "OnlineRooms.Member.Metadata", "OnlineRooms.Member.Timing",
            "OnlineRooms.Member.Notes", "OnlineRooms.Member.Save", "OnlineRooms.Member.Kick")) {
        $observations[$id] = Observe-Element (Find-ElementById -ProcessId $owner.Process.Id -AutomationId $id)
    }
    $ownerMemberPath = Join-Path $outputFullPath "owner-member-management.png"
    $captures.ownerMemberManagement = Capture-Window $ownerHandle $ownerMemberPath
    Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id -AutomationId "OnlineRooms.Member.Kick")
    $afterKick = Wait-HarnessState $endpoint {
        param($state)
        -not (@($state.activeMemberIds) -contains 4202) -and @($state.offlineSeatIds) -contains 4202
    } "member kick and offline seat retention"
    Close-Community $owner

    $memberRetainedTab = Find-ElementByIdAndNameLike `
        -ProcessId $member.Process.Id -AutomationId "Editor.ChartTab" `
        -Like "*房间留存*" -TimeoutMilliseconds 40000
    [void](Wait-ElementName $member.Process.Id "OnlineAccount.Navigation" "账号 · Avalonia 成员" 20)
    $serverOperationCountBeforeLocal = [int](Get-HarnessState $endpoint).acceptedOperationCount
    Invoke-Element (Find-ElementById -ProcessId $member.Process.Id -AutomationId "Editor.QuickTool.Tap")
    $memberLocalLiveState = Get-TimelineLiveState $member.Process.Id
    $localPoint = Get-TimelinePoint $memberRoomRuntime (($placementLane + 1) % 4) 1.75 `
        $member.Process.Id ([double]$memberLocalLiveState.pixelsPerBeat)
    Invoke-PhysicalClick $localPoint.x $localPoint.y $memberHandle
    Start-Sleep -Milliseconds 1000
    Invoke-EditorSave $member
    $memberSaveStatus = Wait-EditorSavedState $member.Process.Id 30
    Start-Sleep -Milliseconds 1500
    $serverOperationCountAfterLocal = [int](Get-HarnessState $endpoint).acceptedOperationCount
    if ($serverOperationCountAfterLocal -ne $serverOperationCountBeforeLocal) {
        throw "Kicked member local edit unexpectedly reached the room server."
    }
    $memberRetainedPath = Join-Path $outputFullPath "member-retained-local-edit.png"
    $captures.memberRetained = Capture-Window $memberHandle $memberRetainedPath
    $localRetentionEvidence = [ordered]@{
        kickedMemberStillAuthenticated = $true
        retainedTab = Observe-Element $memberRetainedTab
        editorStatus = Observe-Element $memberSaveStatus
        realLocalTap = $true
        localTapPoint = $localPoint
        serverAcceptedOperationCountBefore = $serverOperationCountBeforeLocal
        serverAcceptedOperationCountAfter = $serverOperationCountAfterLocal
        serverUnaffected = $serverOperationCountBeforeLocal -eq $serverOperationCountAfterLocal
        savedMcPath = $memberRoomChartPath
        savedMcExists = Test-Path -LiteralPath $memberRoomChartPath
        savedMcSha256 = (Get-FileHash -LiteralPath $memberRoomChartPath -Algorithm SHA256).Hash
    }

    $finalState = Get-HarnessState $endpoint
    $finalState | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $statePath -Encoding utf8NoBOM
    $ownerOps = @($finalState.acceptedOperations | Where-Object { [long]$_.actorUserId -eq 4101 }).Count
    $memberOps = @($finalState.acceptedOperations | Where-Object { [long]$_.actorUserId -eq 4202 }).Count
    if ($ResilienceOnly) {
        $attempts = @($finalState.faults.chartOperationAttempts)
        $droppedAttempt = @($attempts | Where-Object { [bool]$_.responseDropped })[0]
        $retryAttempt = if ($droppedAttempt) {
            @($attempts | Where-Object {
                    [int]$_.attempt -gt [int]$droppedAttempt.attempt -and
                    [string]$_.operationId -ceq [string]$droppedAttempt.operationId -and
                    [bool]$_.duplicateReceipt
                })[0]
        } else { $null }
        $stableCanonicalPayload = $retryAttempt -and
            [string]$retryAttempt.canonicalRequestSha256 -ceq
            [string]$droppedAttempt.canonicalRequestSha256
        $acceptedForRetriedOperation = @($finalState.acceptedOperations | Where-Object {
                [string]$_.operationId -ceq [string]$droppedAttempt.operationId
            }).Count
        $resilienceEvidence["ackLoss"] = [ordered]@{
            droppedAttempt = $droppedAttempt
            retryAttempt = $retryAttempt
            stableOperationId = $retryAttempt -and
                [string]$retryAttempt.operationId -ceq [string]$droppedAttempt.operationId
            stableCanonicalPayload = [bool]$stableCanonicalPayload
            acceptedOperationCount = $acceptedForRetriedOperation
            exactlyOnceCommit = $acceptedForRetriedOperation -eq 1
        }
        $resilienceEvidence["finalFaultState"] = $finalState.faults
        $resilienceEvidence["passed"] =
            [int]$finalState.faults.injectedSseDisconnectCount -eq 2 -and
            [int]$finalState.faults.injectedChartDeltaFailureCount -eq 2 -and
            [int]$finalState.faults.injectedMalformedChartDeltaResponseCount -eq 2 -and
            [int]$finalState.faults.injectedDroppedChartOperationResponseCount -eq 1 -and
            [int]$finalState.faults.pendingSseDisconnects -eq 0 -and
            [int]$finalState.faults.pendingChartDeltaFailures -eq 0 -and
            [int]$finalState.faults.pendingMalformedChartDeltaResponses -eq 0 -and
            [int]$finalState.faults.pendingDroppedChartOperationResponses -eq 0 -and
            $retryAttempt -and [bool]$stableCanonicalPayload -and
            $acceptedForRetriedOperation -eq 1
        if (-not $resilienceEvidence.passed) {
            throw "Injected SSE/delta/ACK-loss recovery did not preserve idempotency or fully converge."
        }
    }
    if ($ownerOps -lt 2 -or $memberOps -lt 4 -or [int]$finalState.chatCount -lt 2 -or
        [int]$finalState.savedSnapshotCount -lt 2 -or -not $localRetentionEvidence.serverUnaffected -or
        -not $frozenNoteSoundEvidence.resourceUploadUnchanged -or
        -not $frozenNoteSoundEvidence.exactBytesOnBothClients) {
        throw "Final two-client online gates were incomplete."
    }

    $screenshots = [ordered]@{}
    foreach ($file in Get-ChildItem -LiteralPath $outputFullPath -File -Filter *.png) {
        $screenshots[$file.BaseName] = [ordered]@{
            path = $file.FullName
            length = $file.Length
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        }
    }
    $evidence = [ordered]@{
        schema = if ($ResilienceOnly) {
            "lumachart.windows.avalonia.two-client-online-resilience-gui-evidence.v2"
        } else {
            "lumachart.windows.avalonia.two-client-online-gui-evidence.v2"
        }
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        formalMigrationAuthority = -not [bool]$AutomationDiagnostic
        completion = $false
        migrationComplete = $false
        windowsAvaloniaOnly = $true
        productionServerMutationPerformed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        resilienceOnly = [bool]$ResilienceOnly
        mouseInputUsed = $true
        physicalMouseInputUsed = $true
        automationDiagnosticNonFormal = [bool]$AutomationDiagnostic
        chineseImeGlobalEnterEscapeHandlerAdded = $false
        paths = [ordered]@{
            projectRoot = $projectRoot
            outputRoot = $outputFullPath
            application = $applicationFullPath
            serverAssembly = $serverAssemblyFullPath
            fixture = $fixtureFullPath
            temp = $projectTemp
            dotnetHome = $dotnetHome
            nugetPackages = $nugetPackages
            nugetHttpCache = $nugetHttpCache
        }
        hashes = [ordered]@{
            application = (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
            applicationAssembly = (Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($applicationFullPath, ".dll")) -Algorithm SHA256).Hash
            serverAssembly = (Get-FileHash -LiteralPath $serverAssemblyFullPath -Algorithm SHA256).Hash
            fixture = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
        }
        endpoint = $endpoint
        processIds = [ordered]@{ server = $server.Id; owner = $owner.Process.Id; member = $member.Process.Id }
        isolatedClients = @(
            [ordered]@{
                role = "owner"
                profile = $owner.Profile
                localData = $owner.LocalData
                editing = $owner.Editing
                workspace = $owner.Workspace
                startupRuntime = $owner.Runtime
                sessionTokenPath = (Join-Path $owner.LocalData "online-session.bin")
            },
            [ordered]@{
                role = "member"
                profile = $member.Profile
                localData = $member.LocalData
                editing = $member.Editing
                workspace = $member.Workspace
                startupRuntime = $member.Runtime
                roomRuntime = $member.RoomRuntime
                sessionTokenPath = (Join-Path $member.LocalData "online-session.bin")
            }
        )
        exactRationalOwnerMove = $exactBeatEvidence
        frozenNoteSound = $frozenNoteSoundEvidence
        memberTapAndMove = $memberPlacementEvidence
        kickedMemberLocalRetention = $localRetentionEvidence
        resilienceFaultRecovery = $resilienceEvidence
        finalServerState = $finalState
        controls = $observations
        captures = $captures
        screenshots = $screenshots
    }
    $evidencePath = Join-Path $outputFullPath "evidence.json"
    $evidence | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Write-Output "Windows Avalonia two-client online GUI capture: passed"
    Write-Output "Evidence: $evidencePath"
}
catch {
    $failure = [ordered]@{
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        message = $_.Exception.Message
        serverState = $null
        ownerAccount = $null
        memberAccount = $null
        lifecycleDiagnostics = [ordered]@{
            ownerTimelineBeforeLocalPlacement = $ownerLocalLive
            ownerPlannedLocalPlacement = $ownerLocalPlacement
            ownerLocalPoint = $ownerLocalPoint
            ownerTimelineAtFailure = $null
            ownerStatusAtFailure = $null
            memberTimelineBeforeLocalPlacement = $memberLocalLive
            memberPlannedLocalPlacement = $memberLocalPlacement
            memberLocalPoint = $memberLocalPoint
            memberTimelineAtFailure = $null
            memberStatusAtFailure = $null
        }
        multiLockDiagnostics = [ordered]@{
            marqueePlan = $marqueePlan
            marqueeStartX = $marqueeStartX
            marqueeStartY = $marqueeStartY
            marqueeEndX = $marqueeEndX
            marqueeEndY = $marqueeEndY
            expectedStartBeat = $expectedStartBeat
            expectedEndBeat = $expectedEndBeat
        }
    }
    try { if ($endpoint) { $failure.serverState = Get-HarnessState $endpoint } } catch { }
    try {
        if ($owner) {
            $failure.ownerAccount = Observe-Element (Find-ElementById -ProcessId $owner.Process.Id `
                -AutomationId "OnlineAccount.Navigation" -TimeoutMilliseconds 1000)
        }
    } catch { }
    try {
        if ($member) {
            $failure.memberAccount = Observe-Element (Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineAccount.Navigation" -TimeoutMilliseconds 1000)
        }
    } catch { }
    try {
        if ($owner) {
            $failure.lifecycleDiagnostics.ownerTimelineAtFailure =
                Get-TimelineLiveState $owner.Process.Id
            $failure.lifecycleDiagnostics.ownerStatusAtFailure = Observe-Element `
                (Find-ElementById -ProcessId $owner.Process.Id `
                    -AutomationId "Editor.Status" -TimeoutMilliseconds 1000)
            $failure.lifecycleDiagnostics.ownerFailureCapture = Capture-Window `
                $ownerHandle (Join-Path $outputFullPath "owner-failure.png")
        }
    } catch { }
    try {
        if ($member) {
            $failure.lifecycleDiagnostics.memberTimelineAtFailure =
                Get-TimelineLiveState $member.Process.Id
            $failure.lifecycleDiagnostics.memberStatusAtFailure = Observe-Element `
                (Find-ElementById -ProcessId $member.Process.Id `
                    -AutomationId "Editor.Status" -TimeoutMilliseconds 1000)
            $failure.lifecycleDiagnostics.memberFailureCapture = Capture-Window `
                $memberHandle (Join-Path $outputFullPath "member-failure.png")
        }
    } catch { }
    $failure | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $outputFullPath "failure.json") -Encoding utf8NoBOM
    throw
}
finally {
    if ($probe) {
        try {
            if (-not $probe.HasExited) {
                $probe.Kill($true)
                [void]$probe.WaitForExit(5000)
            }
        }
        catch { }
        finally { $probe.Dispose() }
    }
    foreach ($client in @($member, $owner)) {
        if ($client -and $client.Process) {
            try {
                if (-not $client.Process.HasExited) {
                    [void]$client.Process.CloseMainWindow()
                    if (-not $client.Process.WaitForExit(10000)) {
                        $client.Process.Kill($true)
                        [void]$client.Process.WaitForExit(5000)
                    }
                }
            }
            catch { }
            finally { $client.Process.Dispose() }
        }
    }
    if ($server) {
        try {
            if (-not $server.HasExited) {
                $server.Kill($true)
                [void]$server.WaitForExit(5000)
            }
            $stdout = $server.StandardOutput.ReadToEnd()
            $stderr = $server.StandardError.ReadToEnd()
            ($stdout + $stderr) | Set-Content -LiteralPath $serverLogPath -Encoding utf8NoBOM
        }
        catch { }
        finally { $server.Dispose() }
    }
}
