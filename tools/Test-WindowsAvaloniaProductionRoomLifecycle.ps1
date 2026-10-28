param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$RelayAssemblyPath = (Join-Path $PSScriptRoot "WindowsAvaloniaProductionRelay\bin\Release\net8.0\WindowsAvaloniaProductionRelay.dll"),
    [string]$OwnerProfilePath = (Join-Path $env:LOCALAPPDATA "LumaChart Studio\Profiles\Test-Client-A"),
    [string]$MemberProfilePath = (Join-Path $env:LOCALAPPDATA "LumaChart Studio\Profiles\Test-Client-B"),
    [string]$ChartPath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$SecondaryChartPath = "D:\steam\steamapps\common\MalodyV\chart\Step into a trance EP\0\Natural_BIA.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(180, 360)][int]$DwellSeconds = 190
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "This acceptance test requires PowerShell Core on Windows."
}

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LumaChartProductionRoomNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr handle);
    [DllImport("user32.dll")] public static extern bool MoveWindow(
        IntPtr handle, int x, int y, int width, int height, bool repaint);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(
        IntPtr handle, out RECT rectangle);
    [DllImport("user32.dll")] public static extern bool PrintWindow(
        IntPtr handle, IntPtr deviceContext, uint flags);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(
        uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
    public const uint LeftDown = 0x0002;
    public const uint LeftUp = 0x0004;
}
'@

function Resolve-File([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "$Label not found: $full"
    }
    return $full
}

function Resolve-Directory([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        throw "$Label not found: $full"
    }
    return $full
}

function Wait-Until(
    [scriptblock]$Condition,
    [string]$Description,
    [int]$Seconds = 30,
    [int]$PollMilliseconds = 150) {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try {
            if (& $Condition) { return }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

function Find-Elements([int]$ProcessId, [string]$AutomationId) {
    try {
        $processCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::ProcessIdProperty,
            $ProcessId)
        $idCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty,
            $AutomationId)
        $results = [Collections.Generic.List[object]]::new()
        $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
            [Windows.Automation.TreeScope]::Children,
            $processCondition)
        foreach ($root in $roots) {
            if ([string]$root.Current.AutomationId -ceq $AutomationId) {
                $results.Add($root)
            }
            foreach ($element in $root.FindAll(
                    [Windows.Automation.TreeScope]::Descendants,
                    $idCondition)) {
                $results.Add($element)
            }
        }
        return @($results)
    }
    catch [Windows.Automation.ElementNotAvailableException] { return @() }
    catch [Runtime.InteropServices.COMException] { return @() }
}

function Find-Element(
    [int]$ProcessId,
    [string]$AutomationId,
    [int]$Seconds = 30,
    [switch]$Visible) {
    $script:foundElement = $null
    Wait-Until -Description "'$AutomationId' in process $ProcessId" -Seconds $Seconds -Condition {
        foreach ($candidate in Find-Elements $ProcessId $AutomationId) {
            if (-not $Visible -or
                (-not $candidate.Current.IsOffscreen -and
                 $candidate.Current.BoundingRectangle.Width -gt 1 -and
                 $candidate.Current.BoundingRectangle.Height -gt 1)) {
                $script:foundElement = $candidate
                return $true
            }
        }
        return $false
    }
    return $script:foundElement
}

function Find-ElementByIdPattern(
    [int]$ProcessId,
    [string]$Pattern,
    [int]$Seconds = 30) {
    $script:foundPatternElement = $null
    Wait-Until -Description "'$Pattern' in process $ProcessId" -Seconds $Seconds -Condition {
        $processCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::ProcessIdProperty,
            $ProcessId)
        $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
            [Windows.Automation.TreeScope]::Children,
            $processCondition)
        foreach ($root in $roots) {
            foreach ($candidate in $root.FindAll(
                    [Windows.Automation.TreeScope]::Descendants,
                    [Windows.Automation.Condition]::TrueCondition)) {
                if ([string]$candidate.Current.AutomationId -like $Pattern -and
                    -not $candidate.Current.IsOffscreen) {
                    $script:foundPatternElement = $candidate
                    return $true
                }
            }
        }
        return $false
    }
    return $script:foundPatternElement
}

function Find-ElementByNamePattern(
    [int]$ProcessId,
    [string]$Pattern,
    [int]$Seconds = 30) {
    $script:foundNameElement = $null
    Wait-Until -Description "name '$Pattern' in process $ProcessId" `
        -Seconds $Seconds -Condition {
        $processCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::ProcessIdProperty,
            $ProcessId)
        $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
            [Windows.Automation.TreeScope]::Children,
            $processCondition)
        foreach ($root in $roots) {
            foreach ($candidate in $root.FindAll(
                    [Windows.Automation.TreeScope]::Descendants,
                    [Windows.Automation.Condition]::TrueCondition)) {
                if ([string]$candidate.Current.Name -like $Pattern -and
                    -not $candidate.Current.IsOffscreen) {
                    $script:foundNameElement = $candidate
                    return $true
                }
            }
        }
        return $false
    }
    return $script:foundNameElement
}

function Invoke-Element($Element) {
    $pattern = $null
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$pattern)) {
        ([Windows.Automation.InvokePattern]$pattern).Invoke()
        Start-Sleep -Milliseconds 250
        return
    }
    $pattern = $null
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$pattern)) {
        ([Windows.Automation.SelectionItemPattern]$pattern).Select()
        Start-Sleep -Milliseconds 250
        return
    }
    $bounds = $Element.Current.BoundingRectangle
    if (-not [double]::IsFinite($bounds.Left) -or
        -not [double]::IsFinite($bounds.Top) -or
        -not [double]::IsFinite($bounds.Width) -or
        -not [double]::IsFinite($bounds.Height)) {
        throw "Element '$($Element.Current.AutomationId)' has no InvokePattern " +
            "and an invalid physical rectangle: $bounds."
    }
    Invoke-PhysicalClick `
        ([int][Math]::Round($bounds.Left + $bounds.Width / 2)) `
        ([int][Math]::Round($bounds.Top + $bounds.Height / 2)) `
        ([IntPtr]$Element.Current.NativeWindowHandle)
}

function Set-ElementValue($Element, [string]$Value) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' has no ValuePattern."
    }
    ([Windows.Automation.ValuePattern]$pattern).SetValue($Value)
    Start-Sleep -Milliseconds 150
}

function Set-Toggle($Element, [bool]$Checked) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.TogglePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' has no TogglePattern."
    }
    $toggle = [Windows.Automation.TogglePattern]$pattern
    $expected = if ($Checked) {
        [Windows.Automation.ToggleState]::On
    } else {
        [Windows.Automation.ToggleState]::Off
    }
    if ($toggle.Current.ToggleState -ne $expected) {
        $toggle.Toggle()
        Start-Sleep -Milliseconds 180
    }
}

function Get-ElementValue($Element) {
    $pattern = $null
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$pattern)) {
        return ([Windows.Automation.ValuePattern]$pattern).Current.Value
    }
    return [string]$Element.Current.Name
}

function Invoke-PhysicalClick(
    [int]$X,
    [int]$Y,
    [IntPtr]$ForegroundWindow) {
    if ($ForegroundWindow -ne [IntPtr]::Zero) {
        [void][LumaChartProductionRoomNative]::SetForegroundWindow($ForegroundWindow)
        Start-Sleep -Milliseconds 120
    }
    if (-not [LumaChartProductionRoomNative]::SetCursorPos($X, $Y)) {
        throw "SetCursorPos failed."
    }
    Start-Sleep -Milliseconds 80
    [LumaChartProductionRoomNative]::mouse_event(
        [LumaChartProductionRoomNative]::LeftDown, 0, 0, 0, [UIntPtr]::Zero)
    [LumaChartProductionRoomNative]::mouse_event(
        [LumaChartProductionRoomNative]::LeftUp, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 250
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = New-Object LumaChartProductionRoomNative+RECT
    if (-not [LumaChartProductionRoomNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) {
        throw "GetWindowRect failed."
    }
    $width = [Math]::Max(1, $rectangle.Right - $rectangle.Left)
    $height = [Math]::Max(1, $rectangle.Bottom - $rectangle.Top)
    $bitmap = [Drawing.Bitmap]::new($width, $height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $dc = $graphics.GetHdc()
        try {
            [void][LumaChartProductionRoomNative]::PrintWindow($Handle, $dc, 2)
        }
        finally {
            $graphics.ReleaseHdc($dc)
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function Start-Relay([int]$Port, [string]$Root) {
    $process = Start-Process -FilePath "dotnet" `
        -ArgumentList @($relayFullPath, "--port", "$Port") `
        -RedirectStandardOutput (Join-Path $Root "relay-$Port.stdout.log") `
        -RedirectStandardError (Join-Path $Root "relay-$Port.stderr.log") `
        -WindowStyle Hidden -PassThru
    Wait-Until -Description "relay $Port" -Seconds 20 -Condition {
        try {
            $health = Invoke-RestMethod `
                -Uri "http://127.0.0.1:$Port/__relay/health" `
                -TimeoutSec 2
            return $health.status -eq "ready"
        }
        catch { return $false }
    }
    return $process
}

function Start-Client(
    [string]$Name,
    [string]$SourceProfile,
    [string]$ProfileName,
    [int]$Port,
    [string]$Root) {
    $local = Join-Path $Root "local"
    $editing = Join-Path $Root "editing"
    $workspace = Join-Path $Root "workspace"
    $temp = Join-Path $Root "temp"
    foreach ($directory in @($local, $editing, $workspace, $temp)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    foreach ($entry in Get-ChildItem -LiteralPath $SourceProfile -Force) {
        Copy-Item -LiteralPath $entry.FullName `
            -Destination $local -Recurse -Force
    }
    $start = [Diagnostics.ProcessStartInfo]::new($applicationFullPath)
    $start.UseShellExecute = $false
    $start.Environment["LUMACHART_SERVER_URL"] = "http://127.0.0.1:$Port/"
    $start.Environment["LUMACHART_PROFILE"] = $ProfileName
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $local
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
    $start.Environment["LUMACHART_AVALONIA_ALLOW_MULTIPLE_INSTANCES"] = "1"
    $start.Environment["TEMP"] = $temp
    $start.Environment["TMP"] = $temp
    if (Test-Path -LiteralPath $secondaryChartFullPath -PathType Leaf) {
        $start.ArgumentList.Add($secondaryChartFullPath)
    }
    $start.ArgumentList.Add($chartFullPath)
    $process = [Diagnostics.Process]::Start($start)
    $client = [pscustomobject]@{
        Name = $Name
        Process = $process
        Root = $Root
        Local = $local
        Endpoint = "http://127.0.0.1:$Port/"
    }
    [void](Find-Element $process.Id "OnlineAccount.Navigation" 60)
    [void](Find-Element $process.Id "Timeline.Surface" 60)
    return $client
}

function Open-Rooms($Client) {
    Invoke-Element (Find-Element $Client.Process.Id "OnlineAccount.Navigation" 30)
    [void](Find-Element $Client.Process.Id "OnlineCommunity.Dialog" 30)
    Invoke-Element (Find-Element $Client.Process.Id "OnlineCommunity.Navigation.Rooms" 30)
}

function Close-Community($Client) {
    if (@(Find-Elements $Client.Process.Id "OnlineCommunity.Dialog").Count -eq 0) {
        return
    }
    Invoke-Element (
        Find-Element $Client.Process.Id "OnlineCommunity.Navigation.Close" 15)
    Wait-Until -Description "$($Client.Name) community close" -Seconds 20 -Condition {
        return @(Find-Elements $Client.Process.Id "OnlineCommunity.Dialog").Count -eq 0
    }
}

function Get-LiveState([int]$ProcessId) {
    $timeline = Find-Element $ProcessId "Timeline.Surface" 15
    $help = [string]$timeline.Current.HelpText
    $state = [ordered]@{}
    foreach ($part in $help.Split(";")) {
        $pair = $part.Trim().Split("=", 2)
        if ($pair.Count -eq 2) { $state[$pair[0]] = $pair[1] }
    }
    return [pscustomobject]$state
}

function Wait-MemberCount($Client, [string]$Expected, [int]$Seconds = 30) {
    Wait-Until -Description "$($Client.Name) member count $Expected" `
        -Seconds $Seconds -Condition {
        $count = Find-Element $Client.Process.Id "RoomCollaboration.MemberCount" 2
        return [string]$count.Current.Name -ceq $Expected
    }
}

function Add-PhysicalNote($Client) {
    Write-Output "stage: note-edit-start"
    $before = Get-LiveState $Client.Process.Id
    $beforeRevision = [long]$before.RoomSyncRevision
    $roomPanel = Find-Element $Client.Process.Id "RoomCollaboration.Panel" 20
    if ([string]$roomPanel.Current.HelpText -like "*Collapsed=False*") {
        Invoke-Element (
            Find-Element $Client.Process.Id "RoomCollaboration.Toggle" 20)
    }
    Write-Output "stage: note-room-panel-collapsed"
    Invoke-Element (Find-Element $Client.Process.Id "Editor.QuickTool.Tap" 20)
    Write-Output "stage: note-tap-tool-selected"
    [void](Find-Element $Client.Process.Id "Timeline.Surface" 20 -Visible)
    $windowRect = New-Object LumaChartProductionRoomNative+RECT
    if (-not [LumaChartProductionRoomNative]::GetWindowRect(
            $Client.Process.MainWindowHandle,
            [ref]$windowRect)) {
        throw "Could not read the client window rectangle for Note placement."
    }
    $windowWidth = $windowRect.Right - $windowRect.Left
    $windowHeight = $windowRect.Bottom - $windowRect.Top
    Write-Output (
        "stage: note-window-rect " +
        "$($windowRect.Left),$($windowRect.Top),$windowWidth,$windowHeight")
    foreach ($yFraction in @(.70, .76, .64)) {
        foreach ($xFraction in @(.50, .54, .46)) {
            Invoke-PhysicalClick `
                ([int][Math]::Round($windowRect.Left + $windowWidth * $xFraction)) `
                ([int][Math]::Round($windowRect.Top + $windowHeight * $yFraction)) `
                $Client.Process.MainWindowHandle
            try {
                Wait-Until -Description "room Note revision" -Seconds 5 -Condition {
                    return [long](Get-LiveState $Client.Process.Id).RoomSyncRevision `
                        -gt $beforeRevision
                }
                return Get-LiveState $Client.Process.Id
            }
            catch { }
        }
    }
    throw "Physical Note placement did not create a room revision."
}

function Add-TimingAndMetadata($Client, [string]$Marker) {
    Invoke-Element (Find-Element $Client.Process.Id "Inspector.MetadataTab" 20)
    $version = Find-Element $Client.Process.Id "Metadata.Version" 20
    Set-ElementValue $version $Marker
    Invoke-Element (Find-Element $Client.Process.Id "Metadata.Apply" 20)
    $metadataRevision = [long](Get-LiveState $Client.Process.Id).RoomSyncRevision

    Invoke-Element (Find-Element $Client.Process.Id "Inspector.TimingTab" 20)
    Set-ElementValue (Find-Element $Client.Process.Id "Inspector.Timing.Beat" 20) `
        "999:0/1"
    Set-ElementValue (Find-Element $Client.Process.Id "Inspector.Timing.Bpm" 20) `
        "137"
    Invoke-Element (Find-Element $Client.Process.Id "Inspector.Timing.Add" 20)
    Wait-Until -Description "Timing revision" -Seconds 20 -Condition {
        return [long](Get-LiveState $Client.Process.Id).RoomSyncRevision `
            -gt $metadataRevision
    }
}

function Switch-AwayAndBack($Client) {
    $script:switchTabs = @()
    Wait-Until -Description "two editor tabs before room tab switch" `
        -Seconds 20 -Condition {
        $script:switchTabs = @(
            Find-Elements $Client.Process.Id "Editor.ChartTab" |
                Where-Object { -not $_.Current.IsOffscreen }
        )
        return $script:switchTabs.Count -ge 2
    }
    $tabs = $script:switchTabs
    if ($tabs.Count -lt 2) {
        return [pscustomobject]@{ performed = $false; reason = "only one tab" }
    }
    $roomTab = @($tabs | Where-Object {
            [string]$_.Current.HelpText -like "*房间同步*" -or
            [string]$_.Current.Name -like "*联机*"
        } | Select-Object -First 1)
    if ($roomTab.Count -eq 0) { $roomTab = @($tabs[-1]) }
    $roomIdentity = [string]$roomTab[0].Current.HelpText
    $other = @($tabs | Where-Object {
                [string]$_.Current.HelpText -cne $roomIdentity
            } |
            Select-Object -First 1)
    Invoke-Element $other[0]
    Start-Sleep -Seconds 8
    $script:reacquiredRoomTab = @()
    Wait-Until -Description "room chart tab after switching away" `
        -Seconds 20 -Condition {
        $script:reacquiredRoomTab = @(
            Find-Elements $Client.Process.Id "Editor.ChartTab" |
                Where-Object {
                    [string]$_.Current.HelpText -like "*房间同步*" -or
                    [string]$_.Current.Name -like "*联机*"
                } |
                Select-Object -First 1
        )
        return $script:reacquiredRoomTab.Count -gt 0
    }
    $roomTab = $script:reacquiredRoomTab
    Invoke-Element $roomTab[0]
    Start-Sleep -Seconds 3
    return [pscustomobject]@{
        performed = $true
        other = [string]$other[0].Current.Name
        room = [string]$roomTab[0].Current.Name
    }
}

$applicationFullPath = Resolve-File $ApplicationPath "Avalonia executable"
$relayFullPath = Resolve-File $RelayAssemblyPath "Production relay"
$ownerProfileFullPath = Resolve-Directory $OwnerProfilePath "Owner test profile"
$memberProfileFullPath = Resolve-Directory $MemberProfilePath "Member test profile"
$chartFullPath = Resolve-File $ChartPath "Room chart fixture"
$secondaryChartFullPath = [IO.Path]::GetFullPath($SecondaryChartPath)
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $outputFullPath) {
    throw "Output root already exists: $outputFullPath"
}
New-Item -ItemType Directory -Path $outputFullPath | Out-Null
$ownerRoot = Join-Path $outputFullPath "owner"
$memberRoot = Join-Path $outputFullPath "member"
New-Item -ItemType Directory -Path $ownerRoot,$memberRoot | Out-Null

$relayOwner = $null
$relayMember = $null
$owner = $null
$member = $null
$roomClosed = $false
$actions = [Collections.Generic.List[string]]::new()
$samples = [Collections.Generic.List[object]]::new()
$started = [DateTimeOffset]::UtcNow
$roomNumber = $null
$roomName = "Codex Avalonia 租约验收 " + [DateTime]::Now.ToString("HHmm")
$password = "LC-room-0731"
$metadataMarker = "Lease Acceptance " + [DateTime]::Now.ToString("HHmmss")

try {
    $relayOwner = Start-Relay 48731 $outputFullPath
    $relayMember = Start-Relay 48732 $outputFullPath
    $owner = Start-Client "owner" $ownerProfileFullPath "Test-Client-A" 48731 $ownerRoot
    $member = Start-Client "member" $memberProfileFullPath "Test-Client-B" 48732 $memberRoot
    [void][LumaChartProductionRoomNative]::MoveWindow(
        $owner.Process.MainWindowHandle, 0, 0, 1280, 900, $true)
    [void][LumaChartProductionRoomNative]::MoveWindow(
        $member.Process.MainWindowHandle, 1280, 0, 1280, 900, $true)

    Open-Rooms $owner
    Set-ElementValue (
        Find-Element $owner.Process.Id "OnlineRooms.Create.Name" 30) $roomName
    Set-Toggle (
        Find-Element $owner.Process.Id "OnlineRooms.Create.Private" 20) $true
    Set-ElementValue (
        Find-Element $owner.Process.Id "OnlineRooms.Create.Password" 20) $password
    Set-Toggle (
        Find-Element $owner.Process.Id "OnlineRooms.Create.Hidden" 20) $true
    Invoke-Element (
        Find-Element $owner.Process.Id "OnlineRooms.Create.Submit" 20)
    Invoke-Element (
        Find-Element $owner.Process.Id `
            "OnlineRooms.Create.UploadDialog.Confirm" 60 -Visible)
    # Successful room resource binding closes the Online surface and returns to
    # the editor. Wait for that completed state before reopening Rooms; invoking
    # the title navigation while the modal upload continuation still owns the
    # Online surface can otherwise race its final close.
    [void](Find-Element $owner.Process.Id "RoomCollaboration.Panel" 180)
    Wait-MemberCount $owner "1 / 8" 60
    Open-Rooms $owner
    $ownerHeader = Find-Element `
        $owner.Process.Id "OnlineRooms.Active.HeaderSummary" 120
    $headerStatus = [string]$ownerHeader.Current.HelpText
    if ($headerStatus -notmatch "RoomNumber=(?<number>[0-9]+)") {
        throw "Could not parse the created room number from '$headerStatus'."
    }
    $roomNumber = [long]$Matches.number
    $actions.Add("owner-created-hidden-password-room-$roomNumber")

    Open-Rooms $member
    Set-ElementValue (
        Find-Element $member.Process.Id "OnlineRooms.JoinByNumber.Number" 30) `
        "$roomNumber"
    Set-ElementValue (
        Find-Element $member.Process.Id "OnlineRooms.JoinByNumber.Password" 30) `
        $password
    $joinDeadline = [DateTimeOffset]::UtcNow.AddSeconds(120)
    $openChart = $null
    do {
        Invoke-Element (
            Find-Element $member.Process.Id "OnlineRooms.JoinByNumber.Find" 10)
        Start-Sleep -Seconds 2
        $openCandidates = @(
            Find-Elements $member.Process.Id "OnlineRooms.Active.OpenChart" |
                Where-Object { -not $_.Current.IsOffscreen -and $_.Current.IsEnabled }
        )
        if ($openCandidates.Count -gt 0) {
            $openChart = $openCandidates[0]
            break
        }
    } while ([DateTimeOffset]::UtcNow -lt $joinDeadline)
    if (-not $openChart) {
        throw "Member did not reach the active room after resource readiness retries."
    }
    Invoke-Element $openChart
    # The first action may only download/prepare the immutable room package.
    # When the active-room surface remains, invoke the now-ready Open action.
    Start-Sleep -Seconds 2
    $secondOpen = @(
        Find-Elements $member.Process.Id "OnlineRooms.Active.OpenChart" |
            Where-Object { -not $_.Current.IsOffscreen -and $_.Current.IsEnabled }
    )
    if ($secondOpen.Count -gt 0) {
        Invoke-Element $secondOpen[0]
    }
    Wait-Until -Description "member room chart tab" -Seconds 120 -Condition {
        return @(
            Find-Elements $member.Process.Id "Editor.ChartTab" |
                Where-Object {
                    [string]$_.Current.Name -like "*联机*" -or
                    [string]$_.Current.HelpText -like "*房间同步*"
                }
        ).Count -gt 0
    }
    [void](Find-Element $member.Process.Id "Timeline.Surface" 120 -Visible)
    $actions.Add("member-joined-by-number-and-opened-room-chart")

    Close-Community $owner
    Close-Community $member
    Wait-MemberCount $owner "2 / 8" 45
    Wait-MemberCount $member "2 / 8" 45
    Capture-Window $owner.Process.MainWindowHandle (
        Join-Path $outputFullPath "01-owner-two-members.png")
    Capture-Window $member.Process.MainWindowHandle (
        Join-Path $outputFullPath "02-member-two-members.png")

    Invoke-Element (
        Find-Element $owner.Process.Id "RoomCollaboration.Toggle" 20)
    Set-ElementValue (
        Find-Element $member.Process.Id "RoomCollaboration.ChatInput" 20) `
        "房间租约验收消息 0731"
    Invoke-Element (
        Find-Element $member.Process.Id "RoomCollaboration.Send" 20)
    Wait-Until -Description "collapsed room chat unread dot" -Seconds 30 -Condition {
        $panel = Find-Element $owner.Process.Id "RoomCollaboration.Panel" 2
        return [string]$panel.Current.HelpText -like "*Unread=True*"
    }
    $actions.Add("collapsed-chat-unread-red-dot")
    Invoke-Element (
        Find-Element $owner.Process.Id "RoomCollaboration.Toggle" 20)
    Wait-Until -Description "room chat unread clear" -Seconds 20 -Condition {
        $panel = Find-Element $owner.Process.Id "RoomCollaboration.Panel" 2
        return [string]$panel.Current.HelpText -like "*Unread=False*"
    }

    $noteState = Add-PhysicalNote $owner
    $actions.Add("owner-physical-note-edit")
    Add-TimingAndMetadata $owner $metadataMarker
    $actions.Add("owner-timing-and-metadata-edit")
    $switchEvidence = Switch-AwayAndBack $owner
    if ($switchEvidence.performed) { $actions.Add("owner-switched-editor-tabs") }

    $dwellStart = [DateTimeOffset]::UtcNow
    $blackoutStarted = $false
    $blackoutRecovered = $false
    $ownerUnfocused = $false
    $ownerRefocused = $false
    while (([DateTimeOffset]::UtcNow - $dwellStart).TotalSeconds -lt $DwellSeconds) {
        $elapsed = [int]([DateTimeOffset]::UtcNow - $dwellStart).TotalSeconds
        if (-not $blackoutStarted -and $elapsed -ge 65) {
            Invoke-RestMethod -Method Put `
                -Uri "http://127.0.0.1:48732/__relay/blackout/true" `
                -TimeoutSec 5 | Out-Null
            $blackoutStarted = $true
            $actions.Add("member-network-blackout-start")
        }
        if ($blackoutStarted -and -not $blackoutRecovered -and $elapsed -ge 77) {
            Invoke-RestMethod -Method Put `
                -Uri "http://127.0.0.1:48732/__relay/blackout/false" `
                -TimeoutSec 5 | Out-Null
            $blackoutRecovered = $true
            $actions.Add("member-network-blackout-recovered")
        }
        if (-not $ownerUnfocused -and $elapsed -ge 105) {
            [void][LumaChartProductionRoomNative]::SetForegroundWindow(
                $member.Process.MainWindowHandle)
            $ownerUnfocused = $true
            $actions.Add("owner-window-unfocused")
        }
        if ($ownerUnfocused -and -not $ownerRefocused -and $elapsed -ge 135) {
            [void][LumaChartProductionRoomNative]::SetForegroundWindow(
                $owner.Process.MainWindowHandle)
            $ownerRefocused = $true
        }

        $ownerCount = [string](
            Find-Element $owner.Process.Id "RoomCollaboration.MemberCount" 5
        ).Current.Name
        $memberCount = [string](
            Find-Element $member.Process.Id "RoomCollaboration.MemberCount" 5
        ).Current.Name
        $ownerLive = Get-LiveState $owner.Process.Id
        $memberLive = Get-LiveState $member.Process.Id
        $samples.Add([pscustomobject][ordered]@{
            elapsedSeconds = $elapsed
            ownerCount = $ownerCount
            memberCount = $memberCount
            ownerRevision = [long]$ownerLive.RoomSyncRevision
            memberRevision = [long]$memberLive.RoomSyncRevision
            ownerFeed = [string]$ownerLive.RoomSyncFeedStatus
            memberFeed = [string]$memberLive.RoomSyncFeedStatus
            memberBlackout = $blackoutStarted -and -not $blackoutRecovered
        })
        if (-not ($blackoutStarted -and -not $blackoutRecovered) -and
            ($ownerCount -cne "2 / 8" -or $memberCount -cne "2 / 8")) {
            throw "Room count drifted at $elapsed seconds: $ownerCount / $memberCount."
        }
        Start-Sleep -Seconds 5
    }
    Wait-MemberCount $owner "2 / 8" 45
    Wait-MemberCount $member "2 / 8" 45
    Wait-Until -Description "final room revision convergence" -Seconds 45 -Condition {
        $left = Get-LiveState $owner.Process.Id
        $right = Get-LiveState $member.Process.Id
        return [long]$left.RoomSyncRevision -gt 0 -and
            [long]$left.RoomSyncRevision -eq [long]$right.RoomSyncRevision
    }

    Invoke-Element (Find-Element $member.Process.Id "Inspector.MetadataTab" 20)
    $memberVersion = Get-ElementValue (
        Find-Element $member.Process.Id "Metadata.Version" 20)
    if ($memberVersion -cne $metadataMarker) {
        throw "Metadata did not converge: '$memberVersion'."
    }
    Invoke-Element (Find-Element $member.Process.Id "Inspector.TimingTab" 20)
    $timingRow = Find-ElementByIdPattern `
        $member.Process.Id "Inspector.Timing.Row.*" 30
    $finalOwner = Get-LiveState $owner.Process.Id
    $finalMember = Get-LiveState $member.Process.Id
    Capture-Window $owner.Process.MainWindowHandle (
        Join-Path $outputFullPath "03-owner-after-three-minutes.png")
    Capture-Window $member.Process.MainWindowHandle (
        Join-Path $outputFullPath "04-member-after-recovery.png")

    Open-Rooms $owner
    $manage = Find-ElementByIdPattern `
        $owner.Process.Id "OnlineRooms.Member.*.Manage" 45
    Invoke-Element $manage
    Invoke-Element (
        Find-Element $owner.Process.Id "OnlineRooms.Member.Kick" 30)
    $actions.Add("owner-kicked-member")
    Close-Community $owner
    Wait-MemberCount $owner "1 / 8" 45
    Wait-Until -Description "kicked member retention" -Seconds 45 -Condition {
        $tabs = @(Find-Elements $member.Process.Id "Editor.ChartTab")
        return @($tabs | Where-Object {
                [string]$_.Current.Name -like "*房间留存*" -or
                [string]$_.Current.HelpText -like "*房间留存*"
            }).Count -gt 0
    }
    $revisionBeforeKickedEdit = [long](Get-LiveState $owner.Process.Id).RoomSyncRevision
    try { [void](Add-PhysicalNote $member) } catch { }
    Start-Sleep -Seconds 8
    $revisionAfterKickedEdit = [long](Get-LiveState $owner.Process.Id).RoomSyncRevision
    if ($revisionAfterKickedEdit -ne $revisionBeforeKickedEdit) {
        throw "Kicked member still changed the authoritative room revision."
    }
    Wait-MemberCount $owner "1 / 8" 20

    Open-Rooms $owner
    Invoke-Element (
        Find-Element $owner.Process.Id "OnlineRooms.Active.Leave" 30)
    Invoke-Element (
        Find-Element $owner.Process.Id "OnlineRooms.ExitDialog.Confirm" 30)
    $actions.Add("owner-closed-room")
    $roomClosed = $true
    Wait-Until -Description "owner room retention" -Seconds 45 -Condition {
        $tabs = @(Find-Elements $owner.Process.Id "Editor.ChartTab")
        return @($tabs | Where-Object {
                [string]$_.Current.Name -like "*房间留存*" -or
                [string]$_.Current.HelpText -like "*房间留存*"
            }).Count -gt 0
    }
    Capture-Window $owner.Process.MainWindowHandle (
        Join-Path $outputFullPath "05-owner-room-retention.png")
    Capture-Window $member.Process.MainWindowHandle (
        Join-Path $outputFullPath "06-member-kicked-retention.png")

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.production-room-lifecycle.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        windowsAvaloniaOnly = $true
        serverDeploymentPerformed = $false
        productionReleaseBaseline = "20260722005907"
        room = [ordered]@{
            number = $roomNumber
            name = $roomName
            hidden = $true
            passwordRoom = $true
            closed = $roomClosed
        }
        durationSeconds = [int]([DateTimeOffset]::UtcNow - $started).TotalSeconds
        dwellSeconds = $DwellSeconds
        finalRevision = [long]$finalOwner.RoomSyncRevision
        finalMemberRevision = [long]$finalMember.RoomSyncRevision
        metadataMarker = $metadataMarker
        timingRowObserved = [string]$timingRow.Current.Name
        revisionUnaffectedByKickedClient =
            $revisionBeforeKickedEdit -eq $revisionAfterKickedEdit
        switchEvidence = $switchEvidence
        actions = $actions.ToArray()
        samples = $samples.ToArray()
        processIds = [ordered]@{
            owner = $owner.Process.Id
            member = $member.Process.Id
            ownerRelay = $relayOwner.Id
            memberRelay = $relayMember.Id
        }
        hashes = [ordered]@{
            application = (
                Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256
            ).Hash
            chart = (
                Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256
            ).Hash
        }
    }
    $json = $evidence | ConvertTo-Json -Depth 20
    if ($json.Contains($password, [StringComparison]::Ordinal)) {
        throw "Room password leaked into evidence."
    }
    $json | Set-Content -LiteralPath (
        Join-Path $outputFullPath "evidence.json") -Encoding utf8NoBOM
    Write-Output "Windows Avalonia production room lifecycle acceptance: passed"
    Write-Output "Evidence: $(Join-Path $outputFullPath 'evidence.json')"
}
catch {
    Write-Error (
        "Acceptance failure: $($_.Exception.Message)`n" +
        "$($_.ScriptStackTrace)")
    throw
}
finally {
    if (-not $roomClosed -and $owner -and -not $owner.Process.HasExited) {
        try {
            Open-Rooms $owner
            Invoke-Element (
                Find-Element $owner.Process.Id "OnlineRooms.Active.Leave" 10)
            Invoke-Element (
                Find-Element $owner.Process.Id "OnlineRooms.ExitDialog.Confirm" 10)
        }
        catch { }
    }
    foreach ($client in @($owner, $member)) {
        if ($client -and -not $client.Process.HasExited) {
            try {
                $client.Process.CloseMainWindow() | Out-Null
                if (-not $client.Process.WaitForExit(8000)) {
                    $client.Process.Kill($true)
                }
            }
            catch { }
        }
    }
    foreach ($relay in @($relayOwner, $relayMember)) {
        if ($relay -and -not $relay.HasExited) {
            try { $relay.Kill($true) } catch { }
        }
    }
}
