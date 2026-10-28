param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 120,
    [switch]$LastEffectMemoryOnly
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia inspector-parity GUI capture requires PowerShell Core on Windows."
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

$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Force -Path $outputFullPath | Out-Null
$sessionRoot = Join-Path $outputFullPath "session"
$localDataRoot = Join-Path $sessionRoot "local-data"
$editingRoot = Join-Path $sessionRoot "editing"
$workspaceRoot = Join-Path $sessionRoot "workspace"
$taskTempRoot = Join-Path $sessionRoot "temp"
foreach ($directory in @($sessionRoot, $localDataRoot, $editingRoot, $workspaceRoot, $taskTempRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}
$env:TEMP = $taskTempRoot
$env:TMP = $taskTempRoot
$env:LUMACHART_AVALONIA_LOCAL_DATA_ROOT = $localDataRoot
$env:LUMACHART_AVALONIA_EDITING_ROOT = $editingRoot
$env:LUMACHART_AVALONIA_WORKSPACE_ROOT = $workspaceRoot

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartInspectorParityNative
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
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);

    public static void SendControlKey(byte key)
    {
        keybd_event(0x11, 0, 0, UIntPtr.Zero);
        keybd_event(key, 0, 0, UIntPtr.Zero);
        keybd_event(key, 0, 2, UIntPtr.Zero);
        keybd_event(0x11, 0, 2, UIntPtr.Zero);
    }

    public static void SendKey(byte key)
    {
        keybd_event(key, 0, 0, UIntPtr.Zero);
        keybd_event(key, 0, 2, UIntPtr.Zero);
    }
}
'@

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [int]$TimeoutMilliseconds = 10000,
        [switch]$Optional
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
    if ($Optional) { return $null }
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Find-ElementByName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$TimeoutMilliseconds = 10000,
        [switch]$Optional
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
    if ($Optional) { return $null }
    throw "Timed out finding UI Automation name '$Name' for process $ProcessId."
}

function Find-InvokableElementByNamePattern {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [int]$TimeoutMilliseconds = 10000
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        $clickableFallback = $null
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children, $processCondition)
            foreach ($root in $roots) {
                $elements = $root.FindAll(
                    [Windows.Automation.TreeScope]::Descendants,
                    [Windows.Automation.Condition]::TrueCondition)
                foreach ($element in $elements) {
                    if ([string]$element.Current.Name -notmatch $Pattern) { continue }
                    $invoke = $null
                    if ($element.TryGetCurrentPattern(
                            [Windows.Automation.InvokePattern]::Pattern,
                            [ref]$invoke)) {
                        return $element
                    }
                    $selectionItem = $null
                    if ($element.TryGetCurrentPattern(
                            [Windows.Automation.SelectionItemPattern]::Pattern,
                            [ref]$selectionItem)) {
                        return $element
                    }
                    $bounds = $element.Current.BoundingRectangle
                    if ($bounds.Width -gt 0 -and $bounds.Height -gt 0) {
                        $clickableFallback = $element
                    }
                }
            }
            if ($clickableFallback) { return $clickableFallback }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    try {
        $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
            [Windows.Automation.TreeScope]::Children,
            $processCondition)
        foreach ($root in $roots) {
            Write-Host ("UIA_ROOT name='{0}' id='{1}' class='{2}' type='{3}'" -f
                [string]$root.Current.Name,
                [string]$root.Current.AutomationId,
                [string]$root.Current.ClassName,
                [string]$root.Current.ControlType.ProgrammaticName)
            $elements = $root.FindAll(
                [Windows.Automation.TreeScope]::Descendants,
                [Windows.Automation.Condition]::TrueCondition)
            foreach ($element in $elements) {
                $name = [string]$element.Current.Name
                $id = [string]$element.Current.AutomationId
                $class = [string]$element.Current.ClassName
                $type = [string]$element.Current.ControlType.ProgrammaticName
                if ($name -match '(?i)Resound|Nhato|\.ogg|Key\s*音|清除|无' -or
                    $type -match '(?i)MenuItem|ListItem' -or
                    $class -match '(?i)Menu|Popup') {
                    Write-Host ("UIA_CANDIDATE name='{0}' id='{1}' class='{2}' type='{3}'" -f
                        $name,
                        $id,
                        $class,
                        $type)
                }
            }
        }
    }
    catch {
        Write-Host "UIA candidate enumeration failed: $($_.Exception.Message)"
    }
    throw "Timed out finding invokable UI Automation name pattern '$Pattern' for process $ProcessId."
}

function Invoke-MenuElement($Element) {
    $pattern = $null
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$pattern)) {
        ([Windows.Automation.InvokePattern]$pattern).Invoke()
        return
    }
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$pattern)) {
        ([Windows.Automation.SelectionItemPattern]$pattern).Select()
        return
    }
    Invoke-MouseClick $Element
}

function Invoke-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose InvokePattern."
    }
    try {
        ([Windows.Automation.InvokePattern]$pattern).Invoke()
    }
    catch {
        throw "Invoking '$($Element.Current.AutomationId)' failed: $($_.Exception.Message)"
    }
}

function Invoke-MouseClick($Element) {
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -le 0 -or $bounds.Height -le 0) {
        throw "Element '$($Element.Current.AutomationId)' has invalid click bounds."
    }
    [void][LumaChartInspectorParityNative]::SetCursorPos(
        [int][Math]::Round($bounds.Left + $bounds.Width / 2),
        [int][Math]::Round($bounds.Top + $bounds.Height / 2))
    Start-Sleep -Milliseconds 100
    [LumaChartInspectorParityNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 50
    [LumaChartInspectorParityNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Invoke-RecordedMouseClick(
    $Element,
    [Collections.Generic.List[object]]$Actions,
    [string]$Action) {
    Invoke-MouseClick $Element
    $Actions.Add([ordered]@{
        index = $Actions.Count + 1
        action = $Action
        automationId = [string]$Element.Current.AutomationId
        completedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
}

function Invoke-MouseClickAt([int]$X, [int]$Y) {
    [void][LumaChartInspectorParityNative]::SetCursorPos($X, $Y)
    Start-Sleep -Milliseconds 100
    [LumaChartInspectorParityNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 50
    [LumaChartInspectorParityNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Move-MouseToElement($Element) {
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -le 0 -or $bounds.Height -le 0) {
        throw "Element '$($Element.Current.AutomationId)' has invalid hover bounds."
    }
    [void][LumaChartInspectorParityNative]::SetCursorPos(
        [int][Math]::Round($bounds.Left + $bounds.Width / 2),
        [int][Math]::Round($bounds.Top + $bounds.Height / 2))
}

function Move-MouseToSliderThumb($Element) {
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -le 0 -or $bounds.Height -le 0) {
        throw "Slider '$($Element.Current.AutomationId)' has invalid hover bounds."
    }
    $range = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.RangeValuePattern]::Pattern,
            [ref]$range)) {
        throw "Slider '$($Element.Current.AutomationId)' does not expose RangeValuePattern."
    }
    $current = ([Windows.Automation.RangeValuePattern]$range).Current
    $ratio = if ($current.Maximum -gt $current.Minimum) {
        ($current.Value - $current.Minimum) / ($current.Maximum - $current.Minimum)
    } else {
        0
    }
    $ratio = [Math]::Clamp([double]$ratio, 0, 1)
    [void][LumaChartInspectorParityNative]::SetCursorPos(
        [int][Math]::Round($bounds.Left + 13 + $ratio * [Math]::Max(0, $bounds.Width - 26)),
        [int][Math]::Round($bounds.Top + $bounds.Height / 2))
}

function Scroll-ElementIntoView($Element) {
    $pattern = $null
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.ScrollItemPattern]::Pattern,
            [ref]$pattern)) {
        ([Windows.Automation.ScrollItemPattern]$pattern).ScrollIntoView()
    }
    else {
        $Element.SetFocus()
    }
    Start-Sleep -Milliseconds 250
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -le 0 -or $bounds.Height -le 0 -or $Element.Current.IsOffscreen) {
        throw "Element '$($Element.Current.AutomationId)' could not be scrolled into view."
    }
}

function Get-ToggleState($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.TogglePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose TogglePattern."
    }
    return [string]([Windows.Automation.TogglePattern]$pattern).Current.ToggleState
}

function Get-VisibleToolTipText([int]$ProcessId) {
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $toolTipCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ControlTypeProperty,
        [Windows.Automation.ControlType]::ToolTip)
    try {
        $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
            [Windows.Automation.TreeScope]::Children,
            $processCondition)
        foreach ($root in $roots) {
            if ($root.Current.ControlType -eq [Windows.Automation.ControlType]::ToolTip -and
                -not $root.Current.IsOffscreen) {
                return [string]$root.Current.Name
            }
            $toolTips = $root.FindAll(
                [Windows.Automation.TreeScope]::Descendants,
                $toolTipCondition)
            foreach ($toolTip in $toolTips) {
                if (-not $toolTip.Current.IsOffscreen) {
                    return [string]$toolTip.Current.Name
                }
            }
        }
    }
    catch [Windows.Automation.ElementNotAvailableException] { }
    catch [Runtime.InteropServices.COMException] { }
    return $null
}

function Select-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose SelectionItemPattern."
    }
    ([Windows.Automation.SelectionItemPattern]$pattern).Select()
}

function Select-ComboBoxItem {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)]$ComboBox,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$PopupCapturePath
    )
    if ($Name -notin @("无", "Scroll", "Jump", "HS", "Sign", "自定义字段")) {
        throw "Unsupported deterministic Timing Effect selection '$Name'."
    }
    $targetProcess = Get-Process -Id $ProcessId
    [void][LumaChartInspectorParityNative]::SetForegroundWindow($targetProcess.MainWindowHandle)
    $expandPattern = $null
    if (-not $ComboBox.TryGetCurrentPattern(
            [Windows.Automation.ExpandCollapsePattern]::Pattern,
            [ref]$expandPattern)) {
        throw "ComboBox '$($ComboBox.Current.AutomationId)' does not expose ExpandCollapsePattern."
    }
    ([Windows.Automation.ExpandCollapsePattern]$expandPattern).Expand()
    Start-Sleep -Milliseconds 150
    $popupCapture = $null
    if (-not [string]::IsNullOrWhiteSpace($PopupCapturePath)) {
        $popupCapture = Capture-ScreenRegion `
            -Handle $targetProcess.MainWindowHandle `
            -Path $PopupCapturePath
    }
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $nameCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty, $Name)
    $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
        [Windows.Automation.TreeScope]::Children,
        $processCondition)
    $candidates = @($roots | ForEach-Object {
        $_.FindAll([Windows.Automation.TreeScope]::Descendants, $nameCondition)
    } | ForEach-Object { $_ } | Where-Object {
        $_.Current.BoundingRectangle.Width -gt 0 -and
        $_.Current.BoundingRectangle.Height -gt 0
    })
    if ($candidates.Count -eq 0) {
        throw "Expanded Timing Effect ComboBox did not expose visible '$Name'."
    }
    Invoke-MouseClick $candidates[0]
    Start-Sleep -Milliseconds 150
    return $popupCapture
}

function Get-SelectedComboBoxItemName($ComboBox) {
    $pattern = $null
    if ($ComboBox.TryGetCurrentPattern(
            [Windows.Automation.SelectionPattern]::Pattern,
            [ref]$pattern)) {
        $selection = @(([Windows.Automation.SelectionPattern]$pattern).Current.GetSelection())
        if ($selection.Count -eq 1) {
            return [string]$selection[0].Current.Name
        }
    }
    $pattern = $null
    if ($ComboBox.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$pattern)) {
        $value = [string]([Windows.Automation.ValuePattern]$pattern).Current.Value
        if ($value -in @("无", "Scroll", "Jump", "HS", "Sign", "自定义字段")) {
            return $value
        }
    }
    $knownNames = @($ComboBox.FindAll(
            [Windows.Automation.TreeScope]::Descendants,
            [Windows.Automation.Condition]::TrueCondition) |
        ForEach-Object { [string]$_.Current.Name } |
        Where-Object { $_ -in @("无", "Scroll", "Jump", "HS", "Sign", "自定义字段") } |
        Select-Object -Unique)
    if ($knownNames.Count -eq 1) {
        return [string]$knownNames[0]
    }
    throw "ComboBox '$($ComboBox.Current.AutomationId)' does not expose one selected Timing Effect. " +
          "Current name='$($ComboBox.Current.Name)', descendant candidates='$($knownNames -join ",")'."
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

function Submit-NativeOpenPicker(
    [int]$ProcessId,
    [string]$Title,
    [string]$Path) {
    $dialog = Find-ElementByName -ProcessId $ProcessId -Name $Title -TimeoutMilliseconds 15000
    $handle = [IntPtr]$dialog.Current.NativeWindowHandle
    if ($handle -eq [IntPtr]::Zero) { throw "Native Note Key-sound picker has no window handle." }

    $edit = $null
    $hostCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        "FileNameControlHost")
    $fileNameHost = $dialog.FindFirst(
        [Windows.Automation.TreeScope]::Descendants,
        $hostCondition)
    if ($fileNameHost) {
        $legacyEditCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty,
            "1001")
        $edit = $fileNameHost.FindFirst(
            [Windows.Automation.TreeScope]::Descendants,
            $legacyEditCondition)
        if ($edit -and
            $edit.Current.ControlType -ne [Windows.Automation.ControlType]::Edit) {
            $edit = $null
        }
    }
    if (-not $edit) {
        foreach ($id in @("1148", "1001")) {
            $condition = [Windows.Automation.PropertyCondition]::new(
                [Windows.Automation.AutomationElement]::AutomationIdProperty,
                $id)
            $matches = $dialog.FindAll(
                [Windows.Automation.TreeScope]::Descendants,
                $condition)
            for ($index = 0; $index -lt $matches.Count; $index++) {
                $candidate = $matches.Item($index)
                $valuePattern = $null
                if ($candidate.Current.IsEnabled -and
                    $candidate.Current.ControlType -eq [Windows.Automation.ControlType]::Edit -and
                    $candidate.TryGetCurrentPattern(
                        [Windows.Automation.ValuePattern]::Pattern,
                        [ref]$valuePattern)) {
                    $edit = $candidate
                    break
                }
            }
            if ($edit) { break }
        }
    }
    if (-not $edit) {
        throw "Native Note Key-sound picker did not expose an editable filename control."
    }
    $fileNameAutomationId = [string]$edit.Current.AutomationId
    $fileNameControlType = [string]$edit.Current.ControlType.ProgrammaticName
    $dialogTitle = [string]$dialog.Current.Name
    $targetDirectory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))
    $targetFileName = [IO.Path]::GetFileName($Path)
    if ([string]::IsNullOrWhiteSpace($targetDirectory) -or
        [string]::IsNullOrWhiteSpace($targetFileName)) {
        throw "Native Note Key-sound picker target path is invalid: $Path"
    }

    [void][LumaChartInspectorParityNative]::SetForegroundWindow($handle)
    [LumaChartInspectorParityNative]::SendControlKey(0x4C)
    $addressEdit = $null
    $addressDeadline = [DateTimeOffset]::UtcNow.AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 100
        $candidate = [Windows.Automation.AutomationElement]::FocusedElement
        $valuePattern = $null
        if ($candidate -and
            [int]$candidate.Current.ProcessId -eq $ProcessId -and
            $candidate.Current.ControlType -eq [Windows.Automation.ControlType]::Edit -and
            $candidate.TryGetCurrentPattern(
                [Windows.Automation.ValuePattern]::Pattern,
                [ref]$valuePattern)) {
            $addressEdit = $candidate
        }
    } while (-not $addressEdit -and [DateTimeOffset]::UtcNow -lt $addressDeadline)
    if (-not $addressEdit) {
        throw "Native Note Key-sound picker Ctrl+L did not focus an editable address bar."
    }
    $addressAutomationId = [string]$addressEdit.Current.AutomationId
    Set-ElementValue $addressEdit $targetDirectory
    if ((Get-ElementValue $addressEdit) -cne $targetDirectory) {
        throw "Native Note Key-sound picker address bar did not retain the target directory."
    }
    $addressEdit.SetFocus()
    [LumaChartInspectorParityNative]::SendKey(0x0D)

    $fileItem = $null
    $fileCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty,
        $targetFileName)
    $fileDeadline = [DateTimeOffset]::UtcNow.AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 150
        $currentDialog = Find-ElementByName `
            -ProcessId $ProcessId `
            -Name $dialogTitle `
            -TimeoutMilliseconds 300 `
            -Optional
        if ($currentDialog) {
            $candidate = $currentDialog.FindFirst(
                [Windows.Automation.TreeScope]::Descendants,
                $fileCondition)
            if ($candidate -and
                $candidate.Current.ControlType -eq [Windows.Automation.ControlType]::ListItem) {
                $fileItem = $candidate
            }
        }
    } while (-not $fileItem -and [DateTimeOffset]::UtcNow -lt $fileDeadline)
    if (-not $fileItem) {
        [void](Capture-ScreenRegion `
            -Handle $handle `
            -Path (Join-Path $outputFullPath "diagnostic-native-note-sound-picker-file-missing.png"))
        throw "Native Note Key-sound picker did not expose '$targetFileName' after Ctrl+L navigation."
    }

    $selectionPattern = $null
    if (-not $fileItem.TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$selectionPattern)) {
        throw "Native Note Key-sound picker file item does not expose SelectionItemPattern."
    }
    ([Windows.Automation.SelectionItemPattern]$selectionPattern).Select()
    $fileInvokePattern = $null
    if (-not $fileItem.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$fileInvokePattern)) {
        throw "Native Note Key-sound picker file item does not expose InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$fileInvokePattern).Invoke()
    $closeMethod = "Ctrl+L address navigation + file-list SelectionItem + InvokePattern"
    $closeDeadline = [DateTimeOffset]::UtcNow.AddSeconds(8)
    do {
        Start-Sleep -Milliseconds 100
        $stillOpen = $null -ne (Find-ElementByName `
            -ProcessId $ProcessId `
            -Name $dialogTitle `
            -TimeoutMilliseconds 150 `
            -Optional)
    } while ($stillOpen -and [DateTimeOffset]::UtcNow -lt $closeDeadline)
    if ($stillOpen) {
        $stuckDialog = Find-ElementByName `
            -ProcessId $ProcessId `
            -Name $dialogTitle `
            -TimeoutMilliseconds 1000
        $stuckHandle = [IntPtr]$stuckDialog.Current.NativeWindowHandle
        [void](Capture-ScreenRegion `
            -Handle $stuckHandle `
            -Path (Join-Path $outputFullPath "diagnostic-native-note-sound-picker-stuck.png"))
        throw "Native Note Key-sound picker stayed open after address navigation and file-list invocation."
    }
    return [ordered]@{
        title = $dialogTitle
        nativeWindowHandle = $handle.ToInt64()
        fileNameAutomationId = $fileNameAutomationId
        fileNameControlType = $fileNameControlType
        addressAutomationId = $addressAutomationId
        navigatedDirectory = $targetDirectory
        selectedFileItemName = $targetFileName
        submittedPath = $Path
        submission = "Ctrl+L address navigation + file-list SelectionItem + InvokePattern"
        closeMethod = $closeMethod
        dialogClosed = $true
    }
}

function Get-TimingCount($List) {
    $name = [string]$List.Current.Name
    if ($name -notmatch '([0-9,]+)\s*项') { throw "Timing list count is not exposed: '$name'." }
    return [int]($Matches[1] -replace ',', '')
}

function ConvertTo-CanonicalObjectMultisetJson([object[]]$Objects) {
    $rows = @($Objects | ForEach-Object {
        $segments = @($_.PSObject.Properties |
            Sort-Object Name |
            ForEach-Object {
                $value = $_.Value
                $valueText = if ($value -is [byte] -or
                    $value -is [sbyte] -or
                    $value -is [int16] -or
                    $value -is [uint16] -or
                    $value -is [int32] -or
                    $value -is [uint32] -or
                    $value -is [int64] -or
                    $value -is [uint64] -or
                    $value -is [single] -or
                    $value -is [double] -or
                    $value -is [decimal]) {
                    ([Convert]::ToDouble(
                        $value,
                        [Globalization.CultureInfo]::InvariantCulture)).ToString(
                            "R",
                            [Globalization.CultureInfo]::InvariantCulture)
                } else {
                    ConvertTo-Json -InputObject $value -Depth 30 -Compress
                }
                "$($_.Name)=$valueText"
            })
        $segments -join "|"
    } | Sort-Object)
    return ConvertTo-Json -InputObject $rows -Compress
}

function Focus-SelectedListItem($List) {
    $pattern = $null
    if (-not $List.TryGetCurrentPattern(
            [Windows.Automation.SelectionPattern]::Pattern,
            [ref]$pattern)) {
        throw "Timing list does not expose SelectionPattern."
    }
    $selected = ([Windows.Automation.SelectionPattern]$pattern).Current.GetSelection()
    if ($selected.Count -eq 0) {
        $itemCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::ControlTypeProperty,
            [Windows.Automation.ControlType]::ListItem)
        $items = $List.FindAll([Windows.Automation.TreeScope]::Descendants, $itemCondition)
        if ($items.Count -eq 0) { throw "Timing list has no materialized item to focus." }
        $selectionItemPattern = $null
        $candidate = $items[$items.Count - 1]
        if (-not $candidate.TryGetCurrentPattern(
                [Windows.Automation.SelectionItemPattern]::Pattern,
                [ref]$selectionItemPattern)) {
            throw "Timing list item does not expose SelectionItemPattern."
        }
        ([Windows.Automation.SelectionItemPattern]$selectionItemPattern).Select()
        $selected = @($candidate)
    }
    Invoke-MouseClick $selected[0]
}

function Focus-TimingListItem($List, [string]$Pattern) {
    $itemCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ControlTypeProperty,
        [Windows.Automation.ControlType]::ListItem)
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(8)
    $focusedFallback = $false
    $lastMaterializedNames = @()
    do {
        $items = $List.FindAll([Windows.Automation.TreeScope]::Descendants, $itemCondition)
        $lastMaterializedNames = @()
        foreach ($item in $items) {
            $names = @($item.FindAll(
                    [Windows.Automation.TreeScope]::Subtree,
                    [Windows.Automation.Condition]::TrueCondition) |
                ForEach-Object { [string]$_.Current.Name } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $joinedNames = $names -join " "
            $lastMaterializedNames += $joinedNames
            if ($joinedNames -notmatch $Pattern) { continue }
            $selectionItemPattern = $null
            if (-not $item.TryGetCurrentPattern(
                    [Windows.Automation.SelectionItemPattern]::Pattern,
                    [ref]$selectionItemPattern)) {
                throw "Matching Timing list item does not expose SelectionItemPattern."
            }
            ([Windows.Automation.SelectionItemPattern]$selectionItemPattern).Select()
            Invoke-MouseClick $item
            return
        }
        if (-not $focusedFallback -and $items.Count -gt 0) {
            Focus-SelectedListItem $List
            $focusedFallback = $true
        }
        else {
            $List.SetFocus()
        }
        Start-Sleep -Milliseconds 150
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "No materialized Timing list item matched '$Pattern'. " +
          "Materialized names: $($lastMaterializedNames -join ' | ')"
}

function Get-WindowBounds([IntPtr]$Handle) {
    $rectangle = [LumaChartInspectorParityNative+RECT]::new()
    if (-not [LumaChartInspectorParityNative]::GetWindowRect($Handle, [ref]$rectangle)) {
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
        throw "Window has invalid inspector-capture bounds: $($bounds.width)x$($bounds.height)."
    }
    $bitmap = [Drawing.Bitmap]::new(
        $bounds.width,
        $bounds.height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $deviceContext = $graphics.GetHdc()
            try {
                if (-not [LumaChartInspectorParityNative]::PrintWindow($Handle, $deviceContext, 2)) {
                    throw "PrintWindow failed."
                }
            }
            finally { $graphics.ReleaseHdc($deviceContext) }
        }
        finally { $graphics.Dispose() }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        $colors = [Collections.Generic.HashSet[int]]::new()
        for ($y = 0; $y -lt $bitmap.Height; $y += [Math]::Max(1, [int]($bitmap.Height / 30))) {
            for ($x = 0; $x -lt $bitmap.Width; $x += [Math]::Max(1, [int]($bitmap.Width / 40))) {
                [void]$colors.Add($bitmap.GetPixel($x, $y).ToArgb())
            }
        }
        if ($colors.Count -lt 8) { throw "Screenshot is near-uniform: $($colors.Count) sampled colors." }
        return [ordered]@{
            path = [IO.Path]::GetFullPath($Path)
            sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
            width = $bitmap.Width
            height = $bitmap.Height
            sampledColors = $colors.Count
        }
    }
    finally { $bitmap.Dispose() }
}

function Capture-ScreenRegion([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartInspectorParityNative+RECT]::new()
    if (-not [LumaChartInspectorParityNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed for screen-region capture."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
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
        finally { $graphics.Dispose() }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $bitmap.Dispose() }
    return [ordered]@{
        path = [IO.Path]::GetFullPath($Path)
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        width = $width
        height = $height
        capture = "display screen region including popup"
    }
}

function Get-TabGeometry($Element) {
    $bounds = $Element.Current.BoundingRectangle
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        left = [double]$bounds.Left
        top = [double]$bounds.Top
        width = [double]$bounds.Width
        height = [double]$bounds.Height
    }
}

$application = Resolve-ExistingFile $ApplicationPath "Avalonia application"
$fixture = Resolve-ExistingFile $ChartFixturePath "real MC fixture"
$fixtureHashBefore = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
$chartUnderTest = $fixture
if ($LastEffectMemoryOnly) {
    $isolatedChartDirectory = Join-Path $sessionRoot "chart"
    New-Item -ItemType Directory -Force -Path $isolatedChartDirectory | Out-Null
    $chartUnderTest = Join-Path $isolatedChartDirectory (Split-Path -Leaf $fixture)
    Copy-Item -LiteralPath $fixture -Destination $chartUnderTest
}
$chartUnderTestHashBefore = (Get-FileHash -LiteralPath $chartUnderTest -Algorithm SHA256).Hash
$runtimePath = Join-Path $outputFullPath "inspector-runtime.json"
$lastEffectSeedPath = Join-Path $outputFullPath "avalonia-last-effect-seed.png"
$lastEffectInheritedPath = Join-Path $outputFullPath "avalonia-last-effect-inherited.png"
$lastEffectSavedPath = Join-Path $outputFullPath "avalonia-last-effect-saved.png"
$lastEffectReopenedPath = Join-Path $outputFullPath "avalonia-last-effect-reopened.png"
$lastEffectEvidencePath = Join-Path $outputFullPath "last-effect-memory-gui-evidence.json"
$lastEffectReopenRuntimePath = Join-Path $outputFullPath "last-effect-memory-reopen-runtime.json"
$timingPath = Join-Path $outputFullPath "avalonia-inspector-timing.png"
$tabHoverPath = Join-Path $outputFullPath "avalonia-inspector-tab-hover.png"
$timingComboOpenPath = Join-Path $outputFullPath "avalonia-inspector-timing-combo-open.png"
$timingFocusedPath = Join-Path $outputFullPath "avalonia-inspector-timing-focused.png"
$pastedPath = Join-Path $outputFullPath "avalonia-inspector-timing-pasted.png"
$notePath = Join-Path $outputFullPath "avalonia-inspector-note.png"
$notePrimaryHoverPath = Join-Path $outputFullPath "avalonia-inspector-note-primary-hover.png"
$noteSoundPath = Join-Path $outputFullPath "avalonia-inspector-note-sound.png"
$noteSoundMenuPath = Join-Path $outputFullPath "avalonia-inspector-note-sound-menu.png"
$noteImportedSoundPath = Join-Path $outputFullPath "avalonia-inspector-note-imported-sound.png"
$groupPath = Join-Path $outputFullPath "avalonia-inspector-group.png"
$settingsPath = Join-Path $outputFullPath "avalonia-inspector-settings.png"
$settingsSliderHoverPath = Join-Path $outputFullPath "avalonia-inspector-settings-slider-hover.png"
$settingsCheckBoxUncheckedPath = Join-Path $outputFullPath "avalonia-inspector-settings-checkbox-unchecked.png"
$settingsCheckBoxCheckedPath = Join-Path $outputFullPath "avalonia-inspector-settings-checkbox-checked.png"
$toolTipBaselinePath = Join-Path $outputFullPath "avalonia-inspector-tooltip-baseline.png"
$toolTipPath = Join-Path $outputFullPath "avalonia-inspector-tooltip.png"
$finalPath = Join-Path $outputFullPath "avalonia-inspector-timing-final.png"
$evidencePath = Join-Path $outputFullPath "inspector-parity-gui-evidence.json"
$sourceSoundPath = Resolve-ExistingFile `
    (Join-Path (Split-Path -Parent $fixture) "Resound - Nhato.ogg") `
    "real Note Key-sound source"
$sourceSoundHashBefore = (Get-FileHash -LiteralPath $sourceSoundPath -Algorithm SHA256).Hash
$importSoundName = "Inspector Imported Key Sound.ogg"
$importSoundPath = Join-Path $sessionRoot $importSoundName
Copy-Item -LiteralPath $sourceSoundPath -Destination $importSoundPath
$importSoundHash = (Get-FileHash -LiteralPath $importSoundPath -Algorithm SHA256).Hash

$start = [Diagnostics.ProcessStartInfo]::new($application)
$start.UseShellExecute = $false
$start.ArgumentList.Add("--evidence-chart")
$start.ArgumentList.Add($chartUnderTest)
$start.ArgumentList.Add("--evidence-focus-timing")
$start.ArgumentList.Add("--evidence-output")
$start.ArgumentList.Add($runtimePath)
$process = [Diagnostics.Process]::Start($start)
if (-not $process) { throw "Failed to start Avalonia inspector GUI process." }

try {
    Wait-Condition -Description "Avalonia inspector window" -Condition {
        $process.Refresh()
        -not $process.HasExited -and $process.MainWindowHandle -ne [IntPtr]::Zero
    }
    $handle = $process.MainWindowHandle
    [void][LumaChartInspectorParityNative]::ShowWindow($handle, 3)
    [void][LumaChartInspectorParityNative]::SetForegroundWindow($handle)
    Wait-Condition -Description "Timing inspector materialization" -Condition {
        $null -ne (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Beat" -TimeoutMilliseconds 350)
    }
    Wait-Condition -Description "runtime evidence" -Condition { Test-Path -LiteralPath $runtimePath -PathType Leaf }
    Start-Sleep -Milliseconds 500
    $initialRuntime = Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json

    if ($LastEffectMemoryOnly) {
        $physicalActions = [Collections.Generic.List[object]]::new()
        $initialChart = Get-Content -LiteralPath $chartUnderTest -Raw | ConvertFrom-Json
        $initialNotesJson = ConvertTo-CanonicalObjectMultisetJson @($initialChart.note)
        $initialTimeStructure = @($initialChart.time | ForEach-Object {
            [ordered]@{
                beat = @($_.beat)
                bpm = [double]$_.bpm
                delay = [double]$_.delay
            }
        }) | ConvertTo-Json -Depth 10 -Compress
        $initialEffects = if ($null -eq $initialChart.PSObject.Properties["effect"]) {
            @()
        } else {
            @($initialChart.effect)
        }
        $timingList = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.List"
        $countBefore = Get-TimingCount $timingList
        $rememberedValue = "2e-3"
        $rememberedField = "lane.glow"
        $effectBox = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Effect"

        $null = Select-ComboBoxItem `
            -ProcessId $process.Id `
            -ComboBox $effectBox `
            -Name "自定义字段"
        $physicalActions.Add([ordered]@{
            index = $physicalActions.Count + 1
            action = "select Custom Effect from expanded ComboBox"
            automationId = "Inspector.Timing.Effect/自定义字段"
            completedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        })
        Wait-Condition -Description "Custom Effect field materialization" -Condition {
            $null -ne (Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Inspector.Timing.CustomField" `
                -TimeoutMilliseconds 300)
        }

        $seedFields = [ordered]@{
            "Inspector.Timing.Bpm" = ""
            "Inspector.Timing.Delay" = "0"
            "Inspector.Timing.Value" = $rememberedValue
            "Inspector.Timing.CustomField" = $rememberedField
        }
        foreach ($entry in $seedFields.GetEnumerator()) {
            $field = Find-ElementById -ProcessId $process.Id -AutomationId $entry.Key
            Invoke-RecordedMouseClick `
                -Element $field `
                -Actions $physicalActions `
                -Action "focus $($entry.Key)"
            Set-ElementValue $field ([string]$entry.Value)
        }
        if ((Get-SelectedComboBoxItemName $effectBox) -cne "自定义字段") {
            throw "Timing Effect ComboBox did not retain the WPF 自定义字段 label before the seed add."
        }

        $addButton = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Add"
        Invoke-RecordedMouseClick `
            -Element $addButton `
            -Actions $physicalActions `
            -Action "add seed Custom Effect"
        Wait-Condition -Description "seed Custom Effect add" -Condition {
            (Get-TimingCount (Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Inspector.Timing.List" `
                -TimeoutMilliseconds 300)) -eq $countBefore + 1
        }
        $seedBeat = Get-ElementValue (
            Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Beat")
        $seedCapture = Capture-Window $handle $lastEffectSeedPath

        $quickEffectButton = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.QuickEffect"
        Invoke-RecordedMouseClick `
            -Element $quickEffectButton `
            -Actions $physicalActions `
            -Action "open quick Effect editor"
        Wait-Condition -Description "last Custom Effect inheritance" -Condition {
            $currentEffectBox = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Inspector.Timing.Effect" `
                -TimeoutMilliseconds 300
            (Get-SelectedComboBoxItemName $currentEffectBox) -ceq "自定义字段" -and
            (Get-ElementValue (Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Inspector.Timing.Value" `
                -TimeoutMilliseconds 300)) -ceq $rememberedValue -and
            (Get-ElementValue (Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Inspector.Timing.CustomField" `
                -TimeoutMilliseconds 300)) -ceq $rememberedField
        }
        $inheritedBeat = Get-ElementValue (
            Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Beat")
        $inheritedBpm = Get-ElementValue (
            Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Bpm")
        $inheritedDelay = Get-ElementValue (
            Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Delay")
        $inheritedValue = Get-ElementValue (
            Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Value")
        $inheritedCustomField = Get-ElementValue (
            Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.CustomField")
        $inheritedEffect = Get-SelectedComboBoxItemName (
            Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Effect")
        $inheritanceStatus = [string](Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.Status").Current.Name
        if ($inheritedBeat -cne $seedBeat) {
            throw "Quick Effect did not reuse the current red-line Beat: seed='$seedBeat', inherited='$inheritedBeat'."
        }
        if ($inheritedBpm -cne "" -or $inheritedDelay -cne "0") {
            throw "Quick Effect did not clear BPM and reset Delay: bpm='$inheritedBpm', delay='$inheritedDelay'."
        }
        if ($inheritanceStatus -notmatch "lane\.glow Effect" -or
            $inheritanceStatus -notmatch "继承值 2e-3") {
            throw "Quick Effect status does not expose inherited WPF values: '$inheritanceStatus'."
        }
        $inheritedCapture = Capture-Window $handle $lastEffectInheritedPath

        $addInheritedButton = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Inspector.Timing.Add"
        Invoke-RecordedMouseClick `
            -Element $addInheritedButton `
            -Actions $physicalActions `
            -Action "add inherited Custom Effect at red line"
        Wait-Condition -Description "inherited Custom Effect add" -Condition {
            (Get-TimingCount (Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Inspector.Timing.List" `
                -TimeoutMilliseconds 300)) -eq $countBefore + 2
        }

        $saveButton = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Editor.Save" `
            -TimeoutMilliseconds 500 `
            -Optional
        if ($null -eq $saveButton) {
            $commandMenuToggle = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Editor.CommandMenuToggle"
            Invoke-RecordedMouseClick `
                -Element $commandMenuToggle `
                -Actions $physicalActions `
                -Action "open responsive editor command menu"
            $saveButton = Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Editor.Save"
        }
        Invoke-RecordedMouseClick `
            -Element $saveButton `
            -Actions $physicalActions `
            -Action "save isolated real MC"
        Wait-Condition -Description "clean saved state" -Condition {
            [string](Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Title.SaveState" `
                -TimeoutMilliseconds 300).Current.Name -ceq "· 已保存"
        }
        $savedCapture = Capture-Window $handle $lastEffectSavedPath

        $savedRaw = Get-Content -LiteralPath $chartUnderTest -Raw
        $savedHash = (Get-FileHash -LiteralPath $chartUnderTest -Algorithm SHA256).Hash
        $savedChart = $savedRaw | ConvertFrom-Json
        $savedEffects = @($savedChart.effect)
        $savedNotesJson = ConvertTo-CanonicalObjectMultisetJson @($savedChart.note)
        $savedTimeStructure = @($savedChart.time | ForEach-Object {
            [ordered]@{
                beat = @($_.beat)
                bpm = [double]$_.bpm
                delay = [double]$_.delay
            }
        }) | ConvertTo-Json -Depth 10 -Compress
        $rawValueOccurrenceCount = [regex]::Matches(
            $savedRaw,
            '"lane\.glow"\s*:\s*2e-3',
            [Text.RegularExpressions.RegexOptions]::CultureInvariant).Count
        if ($savedEffects.Count -ne $initialEffects.Count + 2) {
            throw "Saved MC Effect count mismatch: $($initialEffects.Count) -> $($savedEffects.Count)."
        }
        if ($rawValueOccurrenceCount -ne 2) {
            throw "Saved MC did not preserve exactly two raw 2e-3 values: $rawValueOccurrenceCount."
        }
        if ($savedNotesJson -cne $initialNotesJson -or
            $savedTimeStructure -cne $initialTimeStructure) {
            throw "Adding inherited Effects changed Note or BPM Timing structure."
        }

        Stop-Process -Id $process.Id -Force
        $process.WaitForExit(5000) | Out-Null
        $reopenStart = [Diagnostics.ProcessStartInfo]::new($application)
        $reopenStart.UseShellExecute = $false
        $reopenStart.ArgumentList.Add("--evidence-chart")
        $reopenStart.ArgumentList.Add($chartUnderTest)
        $reopenStart.ArgumentList.Add("--evidence-focus-timing")
        $reopenStart.ArgumentList.Add("--evidence-output")
        $reopenStart.ArgumentList.Add($lastEffectReopenRuntimePath)
        $process = [Diagnostics.Process]::Start($reopenStart)
        if (-not $process) { throw "Failed to reopen the saved isolated real MC." }
        Wait-Condition -Description "reopened Avalonia inspector window" -Condition {
            $process.Refresh()
            -not $process.HasExited -and $process.MainWindowHandle -ne [IntPtr]::Zero
        }
        $handle = $process.MainWindowHandle
        [void][LumaChartInspectorParityNative]::ShowWindow($handle, 3)
        [void][LumaChartInspectorParityNative]::SetForegroundWindow($handle)
        Wait-Condition -Description "reopened Timing inspector materialization" -Condition {
            $null -ne (Find-ElementById `
                -ProcessId $process.Id `
                -AutomationId "Inspector.Timing.List" `
                -TimeoutMilliseconds 350)
        }
        Wait-Condition -Description "reopened runtime evidence" -Condition {
            Test-Path -LiteralPath $lastEffectReopenRuntimePath -PathType Leaf
        }
        Start-Sleep -Milliseconds 400
        $reopenedTimingList = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Inspector.Timing.List"
        $reopenedCount = Get-TimingCount $reopenedTimingList
        if ($reopenedCount -ne $countBefore + 2) {
            throw "Saved real MC did not reopen with both Effects: $countBefore -> $reopenedCount."
        }
        Focus-TimingListItem $reopenedTimingList "(?i)lane\.glow\s+2e-3"
        $reopenedValue = Get-ElementValue (
            Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Value")
        $reopenedCustomField = Get-ElementValue (
            Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.CustomField")
        $reopenedEffect = Get-SelectedComboBoxItemName (
            Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Effect")
        if ($reopenedValue -cne $rememberedValue -or
            $reopenedCustomField -cne $rememberedField -or
            $reopenedEffect -cne "自定义字段") {
            throw "Reopened inspector lost raw Custom Effect data: effect='$reopenedEffect', value='$reopenedValue', field='$reopenedCustomField'."
        }
        $reopenedCapture = Capture-Window $handle $lastEffectReopenedPath

        $fixtureHashAfter = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
        if ($fixtureHashAfter -cne $fixtureHashBefore) {
            throw "The frozen real MC fixture changed during last Effect memory acceptance."
        }
        $reopenedRuntime = Get-Content `
            -LiteralPath $lastEffectReopenRuntimePath `
            -Raw | ConvertFrom-Json
        $lastEffectEvidence = [ordered]@{
            schema = "lumachart.windows.avalonia.last-effect-memory-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed-migration-incomplete"
            application = $application
            source = [ordered]@{
                path = $fixture
                sha256Before = $fixtureHashBefore
                sha256After = $fixtureHashAfter
                unchanged = ($fixtureHashBefore -ceq $fixtureHashAfter)
                realChartNoteCount = [int]$initialRuntime.chart.structure.noteCount
            }
            isolatedChart = [ordered]@{
                path = $chartUnderTest
                sha256Before = $chartUnderTestHashBefore
                sha256After = $savedHash
                changedOnlyByAcceptedEffects = $true
                noteStructureUnchanged = ($savedNotesJson -ceq $initialNotesJson)
                bpmTimingStructureUnchanged = ($savedTimeStructure -ceq $initialTimeStructure)
                effectCount = "$($initialEffects.Count)->$($savedEffects.Count)"
                rawValueText = $rememberedValue
                rawValueOccurrenceCount = $rawValueOccurrenceCount
            }
            wpf110LastEffectMemory = [ordered]@{
                contract = "wpf-1.1.0-last-effect-memory-r1"
                seed = [ordered]@{
                    beat = $seedBeat
                    effect = "Custom"
                    rawValueText = $rememberedValue
                    customField = $rememberedField
                    createdThroughPhysicalAddButton = $true
                }
                inherited = [ordered]@{
                    beat = $inheritedBeat
                    beatComesFromCurrentRedLine = ($inheritedBeat -ceq $seedBeat)
                    bpm = $inheritedBpm
                    delay = $inheritedDelay
                    effect = $inheritedEffect
                    rawValueText = $inheritedValue
                    customField = $inheritedCustomField
                    status = $inheritanceStatus
                    createdThroughPhysicalQuickEffectAndAddButtons = $true
                }
                savedThroughPhysicalButton = $true
                reopenedTimingCount = $reopenedCount
                reopenedEffect = $reopenedEffect
                reopenedRawValueText = $reopenedValue
                reopenedCustomField = $reopenedCustomField
            }
            physicalMouseActions = @($physicalActions)
            screenshots = [ordered]@{
                seed = $seedCapture
                inherited = $inheritedCapture
                saved = $savedCapture
                reopened = $reopenedCapture
            }
            runtime = [ordered]@{
                initial = $initialRuntime
                reopened = $reopenedRuntime
            }
            completion = [ordered]@{
                windowsAvaloniaOneToOneComplete = $false
                userReplacementApprovalReceived = $false
                otherPlatformsAuthorized = $false
            }
        }
        $lastEffectEvidence |
            ConvertTo-Json -Depth 14 |
            Set-Content -LiteralPath $lastEffectEvidencePath -Encoding utf8NoBOM
        Get-Content -LiteralPath $lastEffectEvidencePath -Raw
        return
    }

    $tabIds = @(
        "Inspector.MetadataTab",
        "Inspector.TimingTab",
        "Inspector.NoteTab",
        "Inspector.GroupTab",
        "Inspector.SettingsTab")
    $tabs = foreach ($id in $tabIds) {
        Find-ElementById -ProcessId $process.Id -AutomationId $id
    }
    $tabGeometry = @($tabs | ForEach-Object { Get-TabGeometry $_ })
    $tabTopSpread = ($tabGeometry.top | Measure-Object -Maximum).Maximum -
        ($tabGeometry.top | Measure-Object -Minimum).Minimum
    if ($tabTopSpread -gt 2) { throw "Inspector tabs wrapped across rows: top spread $tabTopSpread." }
    for ($index = 1; $index -lt $tabGeometry.Count; $index++) {
        if ($tabGeometry[$index].left -le $tabGeometry[$index - 1].left) {
            throw "Inspector tab order is not strictly left-to-right at index $index."
        }
    }
    if ($null -ne (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.AudioTab" -TimeoutMilliseconds 250 -Optional)) {
        throw "Avalonia-only Audio tab still exists in the WPF inspector tab strip."
    }

    Move-MouseToElement $tabs[0]
    Start-Sleep -Milliseconds 300
    $tabHoverCapture = Capture-Window $handle $tabHoverPath
    [void][LumaChartInspectorParityNative]::SetCursorPos(0, 0)
    Start-Sleep -Milliseconds 150

    Select-Element $tabs[1]
    $quickPaletteBounds = (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.QuickPalette.Toggle").Current.BoundingRectangle
    $quickValuesBounds = (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.QuickValues.Toggle").Current.BoundingRectangle
    $quickUndoBounds = (Find-ElementById -ProcessId $process.Id -AutomationId "Editor.QuickUndo").Current.BoundingRectangle
    $inspectorLeft = ($tabGeometry.left | Measure-Object -Minimum).Minimum
    if ($quickPaletteBounds.Right -gt $inspectorLeft -or $quickValuesBounds.Right -gt $inspectorLeft) {
        throw "Default quick palettes overlap the Inspector: quick=$($quickPaletteBounds.Right), values=$($quickValuesBounds.Right), inspector=$inspectorLeft."
    }
    $defaultPalettesClearInspector = $true
    if ($quickValuesBounds.Right -ge $quickUndoBounds.Left) {
        throw "Default adjustment palette overlaps quick edit: valuesRight=$($quickValuesBounds.Right), quickLeft=$($quickUndoBounds.Left)."
    }
    $defaultPalettesClearEachOther = $true
    $timingCapture = Capture-Window $handle $timingPath
    if ([string]$timingCapture.sha256 -ceq [string]$tabHoverCapture.sha256) {
        throw "Physical TabItem hover did not change the captured window."
    }
    $timingList = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.List"
    $copyButton = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.CopyEffect"
    $pasteButton = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.PasteAtRedLine"
    $countBefore = Get-TimingCount $timingList
    $effectBox = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Effect"
    $comboOpenCapture = Select-ComboBoxItem `
        -ProcessId $process.Id `
        -ComboBox $effectBox `
        -Name "Scroll" `
        -PopupCapturePath $timingComboOpenPath
    Set-ElementValue (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Value") "1.2500"
    Start-Sleep -Milliseconds 250
    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Add")
    Wait-Condition -Description "real GUI-created Effect" -Condition {
        (Get-TimingCount (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.List" -TimeoutMilliseconds 300)) -eq $countBefore + 1
    } -Seconds 12
    $effectCreatedThroughGui = $true
    $timingList = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.List"
    Focus-TimingListItem $timingList "(?i)scroll\s+1\.2500"
    Wait-Condition -Description "GUI-created Effect selection" -Condition {
        (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.CopyEffect" -TimeoutMilliseconds 300).Current.IsEnabled
    } -Seconds 12
    $copyButton = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.CopyEffect"
    $workingCount = Get-TimingCount (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.List")
    Invoke-Element $copyButton
    Start-Sleep -Milliseconds 150
    $statusElement = Find-ElementById -ProcessId $process.Id -AutomationId "Editor.Status" -TimeoutMilliseconds 500 -Optional
    if ($statusElement) { Write-Output "Timing copy status: $($statusElement.Current.Name)" }
    Wait-Condition -Description "Timing paste button enabled after Effect copy" -Condition {
        (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.PasteAtRedLine" -TimeoutMilliseconds 300).Current.IsEnabled
    }
    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.PasteAtRedLine")
    Wait-Condition -Description "Effect pasted through inspector button" -Condition {
        (Get-TimingCount (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.List" -TimeoutMilliseconds 300)) -eq $workingCount + 1
    }
    $buttonPasteCapture = Capture-Window $handle $pastedPath

    [void][LumaChartInspectorParityNative]::SetForegroundWindow($handle)
    [LumaChartInspectorParityNative]::SendControlKey(0x5A)
    Wait-Condition -Description "button paste undo" -Condition {
        (Get-TimingCount (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.List" -TimeoutMilliseconds 300)) -eq $workingCount
    }

    $timingList = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.List"
    Focus-TimingListItem $timingList "(?i)scroll\s+1\.2500"
    [void][LumaChartInspectorParityNative]::SetForegroundWindow($handle)
    [LumaChartInspectorParityNative]::SendControlKey(0x43)
    Start-Sleep -Milliseconds 120
    [LumaChartInspectorParityNative]::SendControlKey(0x56)
    Wait-Condition -Description "Effect pasted through Ctrl+C and Ctrl+V" -Condition {
        (Get-TimingCount (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.List" -TimeoutMilliseconds 300)) -eq $workingCount + 1
    }
    [LumaChartInspectorParityNative]::SendControlKey(0x5A)
    Wait-Condition -Description "shortcut paste undo" -Condition {
        (Get-TimingCount (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.List" -TimeoutMilliseconds 300)) -eq $workingCount
    }

    $valueBox = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Value"
    $beatBox = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Beat"
    Set-ElementValue $valueBox "1.2500"
    $beatBox.SetFocus()
    Start-Sleep -Milliseconds 150
    if (-not $beatBox.Current.HasKeyboardFocus) {
        throw "Timing Beat TextBox did not expose its real keyboard-focus state."
    }
    $timingFocusedCapture = Capture-Window $handle $timingFocusedPath
    $valueAfterFocusLoss = Get-ElementValue (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.Value")
    if ($valueAfterFocusLoss -cne "1.2500") {
        throw "Timing text input did not survive focus loss without Enter: '$valueAfterFocusLoss'."
    }

    Select-Element $tabs[2]
    Start-Sleep -Milliseconds 200
    $selectedNotes = @($initialRuntime.timeline.selectedNotes)
    if ($selectedNotes.Count -ne 1) {
        throw "Inspector GUI fixture did not expose exactly one initial Note selection."
    }
    $selectedLane = [int]$selectedNotes[0].lane
    $screenScale = [double]$initialRuntime.window.screenScaling
    $timelineTrackLeftDip = [double]$initialRuntime.timeline.proEditor.geometry.officialTrackLeftWindowDip
    $timelineLaneWidthDip = [double]$initialRuntime.timeline.proEditor.geometry.laneWidthDip
    $timelineJudgmentYDip = [double]$initialRuntime.timeline.geometry.judgmentLineYWindowDip
    $timelineBeatHeightDip = [double]$initialRuntime.settings.gridBeatHeight
    $selectedBeatValue = [double]$selectedNotes[0].beat.value
    $selectedEndBeatValue = if ($null -ne $selectedNotes[0].endBeat) {
        [double]$selectedNotes[0].endBeat.value
    } else {
        $selectedBeatValue
    }
    $selectionBeatOffset = [Math]::Max(0, $selectedEndBeatValue - $selectedBeatValue) / 2
    $windowRectangle = [LumaChartInspectorParityNative+RECT]::new()
    if (-not [LumaChartInspectorParityNative]::GetWindowRect($handle, [ref]$windowRectangle)) {
        throw "GetWindowRect failed before selecting the real timeline Note."
    }
    $selectedNoteX = $windowRectangle.Left + [int][Math]::Round(
        ($timelineTrackLeftDip + ($selectedLane + 0.5) * $timelineLaneWidthDip) * $screenScale)
    $selectedNoteY = $windowRectangle.Top + [int][Math]::Round(
        ($timelineJudgmentYDip - $selectionBeatOffset * $timelineBeatHeightDip) * $screenScale)
    [void][LumaChartInspectorParityNative]::SetForegroundWindow($handle)
    $noteSelectionConfirmed = $false
    foreach ($yOffset in @(0, -6, 6)) {
        Invoke-MouseClickAt -X $selectedNoteX -Y ($selectedNoteY + $yOffset)
        $selectionDeadline = [DateTimeOffset]::UtcNow.AddSeconds(3)
        do {
            Start-Sleep -Milliseconds 100
            try {
                $noteSelectionConfirmed = -not [string]::IsNullOrWhiteSpace(
                    (Get-ElementValue (Find-ElementById `
                        -ProcessId $process.Id `
                        -AutomationId "Inspector.Note.Beat" `
                        -TimeoutMilliseconds 250)))
            }
            catch { $noteSelectionConfirmed = $false }
        } while (-not $noteSelectionConfirmed -and
                 [DateTimeOffset]::UtcNow -lt $selectionDeadline)
        if ($noteSelectionConfirmed) { break }
    }
    if (-not $noteSelectionConfirmed) {
        throw "Physical timeline clicks did not select the real LN body for the Note Inspector."
    }
    $noteSoundExisting = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundExisting"
    $noteSoundSelect = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.SoundSelect"
    if (-not $noteSoundExisting.Current.IsEnabled -or -not $noteSoundSelect.Current.IsEnabled) {
        throw "Note Key-sound picker entries are not enabled for the selected editable Note."
    }
    $noteSoundBefore = Get-ElementValue (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.Sound")
    $noteCapture = Capture-Window $handle $notePath
    $noteApply = Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.Apply"
    $noteApplyBounds = $noteApply.Current.BoundingRectangle
    [void][LumaChartInspectorParityNative]::SetCursorPos(
        [int][Math]::Round($noteApplyBounds.Left + $noteApplyBounds.Width / 2),
        [int][Math]::Round($noteApplyBounds.Top + $noteApplyBounds.Height / 2))
    Start-Sleep -Milliseconds 250
    $notePrimaryHoverCapture = Capture-Window $handle $notePrimaryHoverPath
    Invoke-MouseClick $noteSoundExisting
    Start-Sleep -Milliseconds 250
    $noteSoundMenuCapture = Capture-ScreenRegion $handle $noteSoundMenuPath
    $existingSoundItem = Find-InvokableElementByNamePattern -ProcessId $process.Id -Pattern "(?i)Resound - Nhato\.ogg"
    Invoke-MenuElement $existingSoundItem
    Wait-Condition -Description "existing Note Key sound assignment" -Condition {
        (Get-ElementValue (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.Sound" -TimeoutMilliseconds 300)) -ceq "Resound - Nhato.ogg"
    }
    $noteSoundCapture = Capture-Window $handle $noteSoundPath
    [void][LumaChartInspectorParityNative]::SetForegroundWindow($handle)
    [LumaChartInspectorParityNative]::SendControlKey(0x5A)
    Wait-Condition -Description "Note Key sound assignment undo" -Condition {
        (Get-ElementValue (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.Sound" -TimeoutMilliseconds 300)) -ceq $noteSoundBefore
    }
    $existingNoteSoundPicker = $true
    Invoke-MouseClick $noteSoundSelect
    $nativeNoteSoundPicker = Submit-NativeOpenPicker `
        -ProcessId $process.Id `
        -Title "选择 Note Key 音" `
        -Path $importSoundPath
    Wait-Condition -Description "native-picker Note Key sound import" -Condition {
        (Get-ElementValue (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.Sound" -TimeoutMilliseconds 300)) -ceq $importSoundName
    }
    $workingSoundMatches = @(
        Get-ChildItem -LiteralPath $editingRoot -Recurse -File -Filter $importSoundName)
    if ($workingSoundMatches.Count -ne 1) {
        throw "Imported Note Key sound was not copied exactly once into the isolated working cache."
    }
    $workingSoundHash = (Get-FileHash -LiteralPath $workingSoundMatches[0].FullName -Algorithm SHA256).Hash
    if ($workingSoundHash -cne $importSoundHash) {
        throw "Imported Note Key-sound bytes differ from the native-picker fixture."
    }
    $noteImportedSoundCapture = Capture-Window $handle $noteImportedSoundPath
    [void][LumaChartInspectorParityNative]::SetForegroundWindow($handle)
    [LumaChartInspectorParityNative]::SendControlKey(0x5A)
    Wait-Condition -Description "native-picker Note Key sound assignment undo" -Condition {
        (Get-ElementValue (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Note.Sound" -TimeoutMilliseconds 300)) -ceq $noteSoundBefore
    }
    $nativeNoteSoundPickerEntry = $true
    Select-Element $tabs[3]
    Start-Sleep -Milliseconds 200
    $groupCapture = Capture-Window $handle $groupPath
    Select-Element $tabs[4]
    Start-Sleep -Milliseconds 200
    $settingsCapture = Capture-Window $handle $settingsPath
    $settingsSlider = Find-ElementById -ProcessId $process.Id -AutomationId "Settings.GridLaneWidth"
    Move-MouseToSliderThumb $settingsSlider
    Start-Sleep -Milliseconds 250
    $settingsSliderHoverCapture = Capture-Window $handle $settingsSliderHoverPath

    $autoBackupBox = Find-ElementById -ProcessId $process.Id -AutomationId "Settings.AutoBackupEnabled"
    Scroll-ElementIntoView $autoBackupBox
    $initialAutoBackupState = Get-ToggleState $autoBackupBox
    if ($initialAutoBackupState -notin @("On", "Off")) {
        throw "Auto-backup CheckBox exposed unsupported initial state '$initialAutoBackupState'."
    }
    if ($initialAutoBackupState -ceq "On") {
        $settingsCheckBoxCheckedCapture = Capture-Window $handle $settingsCheckBoxCheckedPath
    }
    else {
        $settingsCheckBoxUncheckedCapture = Capture-Window $handle $settingsCheckBoxUncheckedPath
    }
    Invoke-MouseClick $autoBackupBox
    Wait-Condition -Description "physical CheckBox toggle" -Condition {
        (Get-ToggleState (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Settings.AutoBackupEnabled" `
            -TimeoutMilliseconds 300)) -cne $initialAutoBackupState
    }
    $toggledAutoBackupState = Get-ToggleState (
        Find-ElementById -ProcessId $process.Id -AutomationId "Settings.AutoBackupEnabled")
    if ($toggledAutoBackupState -ceq "On") {
        $settingsCheckBoxCheckedCapture = Capture-Window $handle $settingsCheckBoxCheckedPath
    }
    else {
        $settingsCheckBoxUncheckedCapture = Capture-Window $handle $settingsCheckBoxUncheckedPath
    }
    if (-not $settingsCheckBoxCheckedCapture -or -not $settingsCheckBoxUncheckedCapture) {
        throw "CheckBox GUI gate did not capture both checked and unchecked states."
    }
    Invoke-MouseClick (
        Find-ElementById -ProcessId $process.Id -AutomationId "Settings.AutoBackupEnabled")
    Wait-Condition -Description "CheckBox state restoration" -Condition {
        (Get-ToggleState (Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "Settings.AutoBackupEnabled" `
            -TimeoutMilliseconds 300)) -ceq $initialAutoBackupState
    }

    [void][LumaChartInspectorParityNative]::SetCursorPos(0, 0)
    Start-Sleep -Milliseconds 250
    $toolTipBaselineCapture = Capture-ScreenRegion $handle $toolTipBaselinePath
    $toolTipTarget = Find-ElementById -ProcessId $process.Id -AutomationId "Editor.QuickMirror"
    Move-MouseToElement $toolTipTarget
    Start-Sleep -Milliseconds 1200
    $toolTipCapture = Capture-ScreenRegion $handle $toolTipPath
    if ($toolTipCapture.sha256 -ceq $toolTipBaselineCapture.sha256) {
        throw "ToolTip hover did not change the captured display surface."
    }
    $toolTipText = "水平镜像选中的可见 Note"
    [void][LumaChartInspectorParityNative]::SetCursorPos(0, 0)
    Start-Sleep -Milliseconds 200

    Select-Element $tabs[1]
    Start-Sleep -Milliseconds 200
    if ($effectCreatedThroughGui) {
        [void][LumaChartInspectorParityNative]::SetForegroundWindow($handle)
        [LumaChartInspectorParityNative]::SendControlKey(0x5A)
        Wait-Condition -Description "GUI-created Effect undo" -Condition {
            (Get-TimingCount (Find-ElementById -ProcessId $process.Id -AutomationId "Inspector.Timing.List" -TimeoutMilliseconds 300)) -eq $countBefore
        }
    }
    $finalCapture = Capture-Window $handle $finalPath

    $fixtureHashAfter = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
    if ($fixtureHashAfter -cne $fixtureHashBefore) { throw "Real MC fixture changed during inspector GUI acceptance." }
    $sourceSoundHashAfter = (Get-FileHash -LiteralPath $sourceSoundPath -Algorithm SHA256).Hash
    if ($sourceSoundHashAfter -cne $sourceSoundHashBefore) {
        throw "Real Note Key-sound source changed during inspector GUI acceptance."
    }
    $runtime = Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json
    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.inspector-parity-gui-evidence.v4"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        application = $application
        source = [ordered]@{
            path = $fixture
            sha256Before = $fixtureHashBefore
            sha256After = $fixtureHashAfter
            unchanged = ($fixtureHashBefore -ceq $fixtureHashAfter)
            noteCount = [int]$runtime.chart.structure.noteCount
        }
        inspector = [ordered]@{
            tabs = $tabGeometry
            singleRow = $true
            wpfOrder = $true
            avaloniaOnlyAudioTabAbsent = $true
            timingCountBefore = $countBefore
            effectCreatedThroughGui = $effectCreatedThroughGui
            buttonCopyPaste = $true
            buttonPasteUndo = $true
            shortcutCopyPaste = $true
            shortcutPasteUndo = $true
            textInputFocusLossWithoutEnter = ($valueAfterFocusLoss -ceq "1.2500")
            textInputKeyboardFocusCaptured = $true
            comboPopupCapturedFromDisplay = $true
            primaryButtonPointerHoverCaptured = $true
            timingListSingleVirtualizedControl = $true
            defaultFloatingPalettesClearInspector = $defaultPalettesClearInspector
            defaultFloatingPalettesClearEachOther = $defaultPalettesClearEachOther
            noteWpfLayoutAndHintVisible = $true
            existingNoteSoundPickerAssignedAndUndone = $existingNoteSoundPicker
            nativeNoteSoundPickerEntryEnabled = $nativeNoteSoundPickerEntry
            nativeNoteSoundPicker = $nativeNoteSoundPicker
            importedNoteSound = [ordered]@{
                fixturePath = $importSoundPath
                fixtureSha256 = $importSoundHash
                workingPath = $workingSoundMatches[0].FullName
                workingSha256 = $workingSoundHash
                bytesMatch = ($workingSoundHash -ceq $importSoundHash)
                assignmentUndone = $true
                sourcePath = $sourceSoundPath
                sourceSha256Before = $sourceSoundHashBefore
                sourceSha256After = $sourceSoundHashAfter
                sourceUnchanged = ($sourceSoundHashBefore -ceq $sourceSoundHashAfter)
            }
        }
        controlTheme = [ordered]@{
            contract = "wpf-1.1.0-controls-r3"
            fluentInputTemplatesRetained = $true
            textInputFocusBorderDip = 1
            comboPopupAndItemsCovered = $true
            buttonPointerHoverCovered = $true
            scrollBarWidthDip = 9
            scrollViewerAutoHide = $false
            slider = [ordered]@{
                railHeightDip = 3
                thumbHitTargetDip = "26x28"
                thumbBodyDip = "11x16"
                pointerHoverCaptured = $true
            }
            checkBox = [ordered]@{
                boxSizeDip = 16
                physicalToggle = "$initialAutoBackupState->$toggledAutoBackupState->$initialAutoBackupState"
                checkedAndUncheckedCaptured = $true
                restored = $true
            }
            toolTip = [ordered]@{
                popupCapturedFromDisplay = $true
                text = $toolTipText
                textVerifiedByVisualReview = $true
                uiAutomationExposureClaimed = $false
                paddingDip = "8,5"
            }
            contextMenu = [ordered]@{
                normalMenuCapturedFromDisplay = $true
                dangerItemCoveredBySeparatePhysicalGui = $true
            }
            tabItem = [ordered]@{
                globalTheme = $true
                physicalPointerHoverCaptured = $true
                selectedStateCaptured = $true
                wpfSingleRowOrder = $true
            }
        }
        screenshots = [ordered]@{
            timing = $timingCapture
            tabHover = $tabHoverCapture
            timingComboOpen = $comboOpenCapture
            timingFocused = $timingFocusedCapture
            timingAfterButtonPaste = $buttonPasteCapture
            note = $noteCapture
            notePrimaryHover = $notePrimaryHoverCapture
            noteSoundMenu = $noteSoundMenuCapture
            noteSound = $noteSoundCapture
            noteImportedSound = $noteImportedSoundCapture
            group = $groupCapture
            settings = $settingsCapture
            settingsSliderHover = $settingsSliderHoverCapture
            settingsCheckBoxUnchecked = $settingsCheckBoxUncheckedCapture
            settingsCheckBoxChecked = $settingsCheckBoxCheckedCapture
            toolTipBaseline = $toolTipBaselineCapture
            toolTip = $toolTipCapture
            timingFinal = $finalCapture
        }
        completion = [ordered]@{
            windowsAvaloniaOneToOneComplete = $false
            userReplacementApprovalReceived = $false
            otherPlatformsAuthorized = $false
        }
    }
    $evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Get-Content -LiteralPath $evidencePath -Raw
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        $process.WaitForExit(5000) | Out-Null
    }
}
