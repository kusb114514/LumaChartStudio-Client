param(
    [string]$ApplicationPath = (
        Join-Path $PSScriptRoot `
            "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ServerAssemblyPath = (
        Join-Path $PSScriptRoot `
            "WindowsAvaloniaOnlineGuiServer\bin\Release\net8.0\WindowsAvaloniaOnlineGuiServer.dll"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 120)][int]$TimeoutSeconds = 60,
    [switch]$AllowForegroundAutomation,
    [switch]$ExerciseSocialRelations
)

$ErrorActionPreference = "Stop"
if (-not $AllowForegroundAutomation) {
    throw "Pass -AllowForegroundAutomation only after the user gives current-turn desktop consent."
}
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia follow-notification GUI capture requires PowerShell Core on Windows."
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Security.Cryptography.ProtectedData
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartFollowNotificationGuiNative
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
    public static extern bool PrintWindow(IntPtr window, IntPtr deviceContext, uint flags);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(
        uint flags,
        uint dx,
        uint dy,
        uint data,
        UIntPtr extraInfo);

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
}
'@

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Resolve-NewDirectory([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Output already exists: $full" }
    New-Item -ItemType Directory -Force -Path $full | Out-Null
    return $full
}

function Wait-Condition {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Condition,
        [Parameter(Mandatory = $true)][string]$Description,
        [int]$Seconds = $TimeoutSeconds,
        [int]$PollMilliseconds = 80)
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try {
            if (& $Condition) { return }
        }
        catch {
        }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

function Wait-File([string]$Path, [string]$Description, [int]$Seconds) {
    Wait-Condition `
        -Condition { Test-Path -LiteralPath $Path -PathType Leaf } `
        -Description $Description `
        -Seconds $Seconds
}

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId)
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
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
    return $null
}

function Get-ElementHelpText([Windows.Automation.AutomationElement]$Element) {
    return [string]$Element.GetCurrentPropertyValue(
        [Windows.Automation.AutomationElement]::HelpTextProperty,
        $true)
}

function Observe-Element([Windows.Automation.AutomationElement]$Element) {
    $bounds = $Element.Current.BoundingRectangle
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        helpText = Get-ElementHelpText $Element
        isOffscreen = [bool]$Element.Current.IsOffscreen
        bounds = [ordered]@{
            x = [double]$bounds.X
            y = [double]$bounds.Y
            width = [double]$bounds.Width
            height = [double]$bounds.Height
        }
    }
}

function Invoke-Element([Windows.Automation.AutomationElement]$Element) {
    $pattern = $null
    Assert (
        $Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$pattern)) (
        "Element does not expose InvokePattern: " +
        [string]$Element.Current.AutomationId)
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Invoke-ElementPhysical(
    [Windows.Automation.AutomationElement]$Element,
    [IntPtr]$WindowHandle,
    [string]$Action,
    [Collections.Generic.List[object]]$Actions) {
    Assert ($Element.Current.IsEnabled -and -not $Element.Current.IsOffscreen) (
        "Physical action target is unavailable: $Action")
    [void][LumaChartFollowNotificationGuiNative]::ShowWindow($WindowHandle, 9)
    [void][LumaChartFollowNotificationGuiNative]::BringWindowToTop($WindowHandle)
    $foregroundDeadline = [DateTimeOffset]::UtcNow.AddSeconds(3)
    do {
        [void][LumaChartFollowNotificationGuiNative]::SetForegroundWindow($WindowHandle)
        if ([LumaChartFollowNotificationGuiNative]::GetForegroundWindow() -eq
            $WindowHandle) {
            break
        }
        Start-Sleep -Milliseconds 50
    } while ([DateTimeOffset]::UtcNow -lt $foregroundDeadline)
    Assert (
        [LumaChartFollowNotificationGuiNative]::GetForegroundWindow() -eq
            $WindowHandle) "Could not foreground the Avalonia window for: $Action"
    $Element.SetFocus()
    Start-Sleep -Milliseconds 100
    $bounds = $Element.Current.BoundingRectangle
    Assert ($bounds.Width -ge 2 -and $bounds.Height -ge 2) (
        "Physical action target has invalid bounds: $Action")
    $x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    Assert ([LumaChartFollowNotificationGuiNative]::SetCursorPos($x, $y)) (
        "SetCursorPos failed for: $Action")
    Start-Sleep -Milliseconds 75
    $occurredUtc = [DateTimeOffset]::UtcNow.ToString("O")
    [LumaChartFollowNotificationGuiNative]::mouse_event(
        0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 35
    [LumaChartFollowNotificationGuiNative]::mouse_event(
        0x0004, 0, 0, 0, [UIntPtr]::Zero)
    $Actions.Add([ordered]@{
        action = $Action
        automationId = [string]$Element.Current.AutomationId
        input = "physical-win32-left-click"
        x = $x
        y = $y
        occurredUtc = $occurredUtc
    })
}

function Get-DescendantNames([Windows.Automation.AutomationElement]$Element) {
    return @(
        $Element.FindAll(
            [Windows.Automation.TreeScope]::Descendants,
            [Windows.Automation.Condition]::TrueCondition) |
            ForEach-Object { [string]$_.Current.Name } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique)
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = New-Object LumaChartFollowNotificationGuiNative+RECT
    Assert (
        [LumaChartFollowNotificationGuiNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) "GetWindowRect failed."
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    Assert ($width -gt 0 -and $height -gt 0) "Window bounds are empty."
    $bitmap = [Drawing.Bitmap]::new(
        $width,
        $height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $deviceContext = $graphics.GetHdc()
            try {
                Assert (
                    [LumaChartFollowNotificationGuiNative]::PrintWindow(
                        $Handle,
                        $deviceContext,
                        2)) "PrintWindow failed."
            }
            finally {
                $graphics.ReleaseHdc($deviceContext)
            }
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
    }
}

function Write-SessionToken([string]$Root, [string]$Token) {
    $plain = [Text.Encoding]::UTF8.GetBytes($Token)
    try {
        $protected = [Security.Cryptography.ProtectedData]::Protect(
            $plain,
            $null,
            [Security.Cryptography.DataProtectionScope]::CurrentUser)
        [IO.File]::WriteAllBytes(
            (Join-Path $Root "online-session.bin"),
            $protected)
    }
    finally {
        [Array]::Clear($plain, 0, $plain.Length)
    }
}

function Close-ApplicationWindow([Diagnostics.Process]$Process) {
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $Process.Id)
    $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
        [Windows.Automation.TreeScope]::Children,
        $processCondition)
    foreach ($root in $roots) {
        try {
            $pattern = $null
            if ($root.TryGetCurrentPattern(
                    [Windows.Automation.WindowPattern]::Pattern,
                    [ref]$pattern)) {
                ([Windows.Automation.WindowPattern]$pattern).Close()
                return "uia-window-pattern"
            }
        }
        catch {
            # A transient Avalonia popup can disappear while enumerating roots.
        }
    }

    if ($Process.CloseMainWindow()) {
        return "process-close-main-window"
    }

    throw "Application did not expose a closeable top-level window."
}

$applicationFullPath = [IO.Path]::GetFullPath($ApplicationPath)
$serverFullPath = [IO.Path]::GetFullPath($ServerAssemblyPath)
$chartFullPath = [IO.Path]::GetFullPath($ChartFixturePath)
Assert (
    Test-Path -LiteralPath $applicationFullPath -PathType Leaf) (
    "Avalonia executable not found: $applicationFullPath")
Assert (
    Test-Path -LiteralPath $serverFullPath -PathType Leaf) (
    "Loopback server assembly not found: $serverFullPath")
Assert (
    Test-Path -LiteralPath $chartFullPath -PathType Leaf) (
    "Real chart fixture not found: $chartFullPath")
$outputFullPath = Resolve-NewDirectory $OutputRoot
$readyPath = Join-Path $outputFullPath "server-ready.json"
$statePath = Join-Path $outputFullPath "server-state.json"
$firstScreenshotPath = Join-Path $outputFullPath "follow-toast-first.png"
$secondScreenshotPath = Join-Path $outputFullPath "follow-toast-second.png"
$communityScreenshotPath = Join-Path $outputFullPath "community-notification-history.png"
$unfollowScreenshotPath = Join-Path $outputFullPath "social-unfollowed-player.png"
$emptyFriendsScreenshotPath = Join-Path $outputFullPath "social-empty-friends.png"
$restoredFriendsScreenshotPath = Join-Path $outputFullPath "social-restored-friends.png"
$evidencePath = Join-Path $outputFullPath "evidence.json"
$localData = Join-Path $outputFullPath "local-data"
$editing = Join-Path $outputFullPath "editing"
$workspace = Join-Path $outputFullPath "workspace"
$clientTemp = Join-Path $outputFullPath "temp"
foreach ($path in @($localData, $editing, $workspace, $clientTemp)) {
    New-Item -ItemType Directory -Force -Path $path | Out-Null
}

$chartHashBefore = (Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
$installerPath = [IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..\release\LumaChartStudio-Setup.exe"))
$installerHashBefore = (
    Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
$server = $null
$client = $null
$socialActions = [Collections.Generic.List[object]]::new()
$socialEvidence = $null
try {
    $serverStart = [Diagnostics.ProcessStartInfo]::new("dotnet")
    $serverStart.UseShellExecute = $false
    $serverStart.ArgumentList.Add($serverFullPath)
    $serverStart.ArgumentList.Add("--ready-file")
    $serverStart.ArgumentList.Add($readyPath)
    $serverStart.ArgumentList.Add("--state-file")
    $serverStart.ArgumentList.Add($statePath)
    $serverStart.Environment["TEMP"] = $clientTemp
    $serverStart.Environment["TMP"] = $clientTemp
    $server = [Diagnostics.Process]::Start($serverStart)
    Wait-File $readyPath "loopback server ready file" 30
    $ready = Get-Content -Raw -LiteralPath $readyPath | ConvertFrom-Json
    $endpoint = [string]$ready.endpoint
    Assert (
        $endpoint.StartsWith(
            "http://127.0.0.1:",
            [StringComparison]::Ordinal)) (
        "Loopback server published a non-loopback endpoint: $endpoint")
    Write-SessionToken $localData ([string]$ready.ownerToken)

    $start = [Diagnostics.ProcessStartInfo]::new($applicationFullPath)
    $start.UseShellExecute = $false
    $start.ArgumentList.Add("--evidence-chart")
    $start.ArgumentList.Add($chartFullPath)
    $start.Environment["LUMACHART_SERVER_URL"] = $endpoint
    $start.Environment["LUMACHART_PROFILE"] = "windows-avalonia-follow-toast"
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localData
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
    $start.Environment["TEMP"] = $clientTemp
    $start.Environment["TMP"] = $clientTemp
    $client = [Diagnostics.Process]::Start($start)

    Wait-Condition `
        -Condition {
            $client.Refresh()
            $client.MainWindowHandle -ne [IntPtr]::Zero
        } `
        -Description "Avalonia main window"
    $handle = $client.MainWindowHandle
    $topmostAtStart =
        [LumaChartFollowNotificationGuiNative]::IsTopmost($handle)
    Assert (-not $topmostAtStart) "Avalonia main window unexpectedly started topmost."

    $initialState = $null
    Wait-Condition `
        -Condition {
            $script:initialState = Invoke-RestMethod -Uri ($endpoint + "harness/state")
            [int]$script:initialState.notificationFetchCount -ge 1
        } `
        -Description "notification high-water bootstrap"
    $initialFetchCount = [int]$initialState.notificationFetchCount
    Assert (
        [int]$initialState.notificationInjectionCount -eq 0) (
        "Notification harness was not empty before injection.")

    $firstInjectionUtc = [DateTimeOffset]::UtcNow
    $firstInjection = Invoke-RestMethod `
        -Method Post `
        -Uri ($endpoint + "harness/notifications") `
        -ContentType "application/json" `
        -Body (@{
            targetUserId = 4101
            actorUserId = 4202
            actorDisplayName = "Avalonia 成员"
            type = "follow"
        } | ConvertTo-Json -Compress)
    $secondInjection = Invoke-RestMethod `
        -Method Post `
        -Uri ($endpoint + "harness/notifications") `
        -ContentType "application/json" `
        -Body (@{
            targetUserId = 4101
            actorUserId = 4203
            actorDisplayName = ""
            type = "follow"
        } | ConvertTo-Json -Compress)

    $firstToast = $null
    $firstVisibleUtc = [DateTimeOffset]::MinValue
    Wait-Condition `
        -Condition {
            $candidate = Find-ElementById `
                -ProcessId $client.Id `
                -AutomationId "Online.FollowNotificationToast"
            if (-not $candidate -or $candidate.Current.IsOffscreen) { return $false }
            $help = Get-ElementHelpText $candidate
            if (-not $help.Contains(
                    "Message=Avalonia 成员关注了你。",
                    [StringComparison]::Ordinal)) {
                return $false
            }
            $script:firstToast = $candidate
            $script:firstVisibleUtc = [DateTimeOffset]::UtcNow
            return $true
        } `
        -Description "first real follow notification toast"
    $firstObservation = Observe-Element $firstToast
    Assert (
        [string]$firstObservation.helpText -ceq
            "Visible=True; Message=Avalonia 成员关注了你。; DurationMilliseconds=4000; Width=360; Top=50; Right=14; Pending=1") (
        "First follow-notification Toast contract drifted: " +
        [string]$firstObservation.helpText)
    $firstCaptureStopwatch = [Diagnostics.Stopwatch]::StartNew()
    $firstScreenshot = Capture-Window $handle $firstScreenshotPath
    $firstCaptureStopwatch.Stop()
    $firstScreenshotCaptureMilliseconds =
        $firstCaptureStopwatch.Elapsed.TotalMilliseconds

    $secondToast = $null
    $secondVisibleUtc = [DateTimeOffset]::MinValue
    Wait-Condition `
        -Condition {
            $candidate = Find-ElementById `
                -ProcessId $client.Id `
                -AutomationId "Online.FollowNotificationToast"
            if (-not $candidate -or $candidate.Current.IsOffscreen) { return $false }
            $help = Get-ElementHelpText $candidate
            if (-not $help.Contains(
                    "Message=匿名用户关注了你。",
                    [StringComparison]::Ordinal)) {
                return $false
            }
            $script:secondToast = $candidate
            $script:secondVisibleUtc = [DateTimeOffset]::UtcNow
            return $true
        } `
        -Description "second queued follow notification toast"
    $firstVisibleDurationMilliseconds =
        ($secondVisibleUtc - $firstVisibleUtc).TotalMilliseconds
    $secondObservation = Observe-Element $secondToast
    Assert (
        [string]$secondObservation.helpText -ceq
            "Visible=True; Message=匿名用户关注了你。; DurationMilliseconds=4000; Width=360; Top=50; Right=14; Pending=0") (
        "Second follow-notification Toast contract drifted: " +
        [string]$secondObservation.helpText)
    $secondCaptureStopwatch = [Diagnostics.Stopwatch]::StartNew()
    $secondScreenshot = Capture-Window $handle $secondScreenshotPath
    $secondCaptureStopwatch.Stop()
    $secondScreenshotCaptureMilliseconds =
        $secondCaptureStopwatch.Elapsed.TotalMilliseconds

    Wait-Condition `
        -Condition {
            $candidate = Find-ElementById `
                -ProcessId $client.Id `
                -AutomationId "Online.FollowNotificationToast"
            -not $candidate -or $candidate.Current.IsOffscreen
        } `
        -Description "queued follow notification toast dismissal"
    $secondHiddenUtc = [DateTimeOffset]::UtcNow
    $secondVisibleDurationMilliseconds =
        ($secondHiddenUtc - $secondVisibleUtc).TotalMilliseconds
    $firstCaptureAdjustedDurationMilliseconds =
        $firstVisibleDurationMilliseconds - $firstScreenshotCaptureMilliseconds
    $secondCaptureAdjustedDurationMilliseconds =
        $secondVisibleDurationMilliseconds - $secondScreenshotCaptureMilliseconds
    Assert (
        $firstCaptureAdjustedDurationMilliseconds -ge 3200 -and
        $firstCaptureAdjustedDurationMilliseconds -le 5000) (
        "First queued Toast capture-adjusted duration was " +
        "$firstCaptureAdjustedDurationMilliseconds ms " +
        "(wall clock $firstVisibleDurationMilliseconds ms, " +
        "capture $firstScreenshotCaptureMilliseconds ms).")
    Assert (
        $secondCaptureAdjustedDurationMilliseconds -ge 3200 -and
        $secondCaptureAdjustedDurationMilliseconds -le 5000) (
        "Second queued Toast capture-adjusted duration was " +
        "$secondCaptureAdjustedDurationMilliseconds ms " +
        "(wall clock $secondVisibleDurationMilliseconds ms, " +
        "capture $secondScreenshotCaptureMilliseconds ms).")

    $accountNavigation = $null
    Wait-Condition `
        -Condition {
            $script:accountNavigation = Find-ElementById `
                -ProcessId $client.Id `
                -AutomationId "OnlineAccount.Navigation"
            $null -ne $script:accountNavigation -and
                -not $script:accountNavigation.Current.IsOffscreen
        } `
        -Description "authenticated account navigation"
    Invoke-Element $accountNavigation
    $notificationNavigation = $null
    Wait-Condition `
        -Condition {
            $script:notificationNavigation = Find-ElementById `
                -ProcessId $client.Id `
                -AutomationId "OnlineCommunity.Navigation.Notifications"
            $null -ne $script:notificationNavigation -and
                -not $script:notificationNavigation.Current.IsOffscreen
        } `
        -Description "community notification navigation"
    Invoke-Element $notificationNavigation
    $notificationList = $null
    $notificationNames = @()
    Wait-Condition `
        -Condition {
            $candidate = Find-ElementById `
                -ProcessId $client.Id `
                -AutomationId "OnlineCommunity.Notifications.List"
            if (-not $candidate -or $candidate.Current.IsOffscreen) { return $false }
            $names = @(Get-DescendantNames $candidate)
            if (@($names | Where-Object {
                        $_.Contains(
                            "Avalonia 成员关注了你。",
                            [StringComparison]::Ordinal)
                    }).Count -ne 1 -or
                @($names | Where-Object {
                        $_.Contains(
                            "匿名用户关注了你。",
                            [StringComparison]::Ordinal)
                    }).Count -ne 1) {
                return $false
            }
            $script:notificationList = $candidate
            $script:notificationNames = $names
            return $true
        } `
        -Description "community history retained after main-shell polling"
    $communityObservation = Observe-Element $notificationList
    $communityScreenshot = Capture-Window $handle $communityScreenshotPath

    if ($ExerciseSocialRelations) {
        $playersNavigation = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Navigation.Players"
        Assert ($null -ne $playersNavigation) "Player-directory navigation is missing."
        Invoke-ElementPhysical `
            $playersNavigation `
            $handle `
            "open player directory" `
            $socialActions

        $memberOpen = $null
        Wait-Condition `
            -Condition {
                $script:memberOpen = Find-ElementById `
                    -ProcessId $client.Id `
                    -AutomationId "OnlineCommunity.Player.4202.Open"
                $null -ne $script:memberOpen -and
                    -not $script:memberOpen.Current.IsOffscreen
            } `
            -Description "member row in all-player directory"
        Invoke-ElementPhysical `
            $memberOpen `
            $handle `
            "open mutual member profile" `
            $socialActions

        $followButton = $null
        Wait-Condition `
            -Condition {
                $script:followButton = Find-ElementById `
                    -ProcessId $client.Id `
                    -AutomationId "OnlineCommunity.Player.Follow"
                $null -ne $script:followButton -and
                    [string]$script:followButton.Current.Name -ceq "取消关注"
            } `
            -Description "initial mutual follow state"
        Invoke-ElementPhysical `
            $followButton `
            $handle `
            "unfollow mutual member" `
            $socialActions

        $unfollowedButton = $null
        Wait-Condition `
            -Condition {
                $script:unfollowedButton = Find-ElementById `
                    -ProcessId $client.Id `
                    -AutomationId "OnlineCommunity.Player.Follow"
                $null -ne $script:unfollowedButton -and
                    [string]$script:unfollowedButton.Current.Name -ceq "关注"
            } `
            -Description "unfollowed player profile"
        $unfollowedProfile = Observe-Element $unfollowedButton
        $unfollowScreenshot = Capture-Window $handle $unfollowScreenshotPath

        $friendsNavigation = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Navigation.Friends"
        Invoke-ElementPhysical `
            $friendsNavigation `
            $handle `
            "open empty friends directory" `
            $socialActions
        $emptyFriendsStatus = $null
        Wait-Condition `
            -Condition {
                $script:emptyFriendsStatus = Find-ElementById `
                    -ProcessId $client.Id `
                    -AutomationId "OnlineCommunity.Directory.Status"
                $null -ne $script:emptyFriendsStatus -and
                    [string]$script:emptyFriendsStatus.Current.Name -ceq (
                        "在线 0 · 0 名玩家")
            } `
            -Description "friends removal after unfollow"
        $emptyFriendsObservation = Observe-Element $emptyFriendsStatus
        $emptyFriendsScreenshot = Capture-Window $handle $emptyFriendsScreenshotPath

        $followingNavigation = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Navigation.Following"
        Invoke-ElementPhysical `
            $followingNavigation `
            $handle `
            "open empty following directory" `
            $socialActions
        $emptyFollowingStatus = $null
        Wait-Condition `
            -Condition {
                $script:emptyFollowingStatus = Find-ElementById `
                    -ProcessId $client.Id `
                    -AutomationId "OnlineCommunity.Directory.Status"
                $null -ne $script:emptyFollowingStatus -and
                    [string]$script:emptyFollowingStatus.Current.Name -ceq (
                        "在线 0 · 第 1/1 页 · 共 0 名")
            } `
            -Description "following removal after unfollow"

        $followersNavigation = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Navigation.Followers"
        Invoke-ElementPhysical `
            $followersNavigation `
            $handle `
            "open followers directory" `
            $socialActions
        $followerOpen = $null
        Wait-Condition `
            -Condition {
                $script:followerOpen = Find-ElementById `
                    -ProcessId $client.Id `
                    -AutomationId "OnlineCommunity.Player.4202.Open"
                $null -ne $script:followerOpen -and
                    -not $script:followerOpen.Current.IsOffscreen
            } `
            -Description "member retained as owner follower"
        $followersList = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Directory.List"
        $followerNames = @(Get-DescendantNames $followersList)

        $leaderboardNavigation = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Navigation.Leaderboard"
        Invoke-ElementPhysical `
            $leaderboardNavigation `
            $handle `
            "open charting leaderboard" `
            $socialActions
        $leaderboardOwner = $null
        Wait-Condition `
            -Condition {
                $script:leaderboardOwner = Find-ElementById `
                    -ProcessId $client.Id `
                    -AutomationId "OnlineCommunity.Player.4101.Open"
                $null -ne $script:leaderboardOwner -and
                    -not $script:leaderboardOwner.Current.IsOffscreen
            } `
            -Description "owner in leaderboard"
        $leaderboardList = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Directory.List"
        $leaderboardNames = @(Get-DescendantNames $leaderboardList)

        $playersNavigation = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Navigation.Players"
        Invoke-ElementPhysical `
            $playersNavigation `
            $handle `
            "return to player directory" `
            $socialActions
        Wait-Condition `
            -Condition {
                $script:memberOpen = Find-ElementById `
                    -ProcessId $client.Id `
                    -AutomationId "OnlineCommunity.Player.4202.Open"
                $null -ne $script:memberOpen -and
                    -not $script:memberOpen.Current.IsOffscreen
            } `
            -Description "member row before refollow"
        Invoke-ElementPhysical `
            $memberOpen `
            $handle `
            "reopen member profile before refollow" `
            $socialActions
        Wait-Condition `
            -Condition {
                $script:followButton = Find-ElementById `
                    -ProcessId $client.Id `
                    -AutomationId "OnlineCommunity.Player.Follow"
                $null -ne $script:followButton -and
                    [string]$script:followButton.Current.Name -ceq "关注"
            } `
            -Description "refollow action"
        Invoke-ElementPhysical `
            $followButton `
            $handle `
            "restore mutual follow" `
            $socialActions
        $restoredFollowButton = $null
        Wait-Condition `
            -Condition {
                $script:restoredFollowButton = Find-ElementById `
                    -ProcessId $client.Id `
                    -AutomationId "OnlineCommunity.Player.Follow"
                $null -ne $script:restoredFollowButton -and
                    [string]$script:restoredFollowButton.Current.Name -ceq "取消关注"
            } `
            -Description "restored mutual profile"

        $friendsNavigation = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Navigation.Friends"
        Invoke-ElementPhysical `
            $friendsNavigation `
            $handle `
            "open restored friends directory" `
            $socialActions
        $restoredFriendOpen = $null
        Wait-Condition `
            -Condition {
                $script:restoredFriendOpen = Find-ElementById `
                    -ProcessId $client.Id `
                    -AutomationId "OnlineCommunity.Player.4202.Open"
                $null -ne $script:restoredFriendOpen -and
                    -not $script:restoredFriendOpen.Current.IsOffscreen
            } `
            -Description "restored mutual friend row"
        $restoredFriendsStatus = Find-ElementById `
            -ProcessId $client.Id `
            -AutomationId "OnlineCommunity.Directory.Status"
        Assert (
            [string]$restoredFriendsStatus.Current.Name -ceq (
                "在线 1 · 1 名玩家")) (
            "Restored friends directory count is incorrect.")
        $restoredFriendsObservation = Observe-Element $restoredFriendsStatus
        $restoredFriendsScreenshot = Capture-Window `
            $handle `
            $restoredFriendsScreenshotPath

        $memberHeaders = @{
            Authorization = "Bearer $([string]$ready.memberToken)"
        }
        $memberNotifications = Invoke-RestMethod `
            -Uri ($endpoint + "api/me/notifications?after=0&limit=50") `
            -Headers $memberHeaders
        $actualFollowNotifications = @(
            $memberNotifications.notifications |
                Where-Object {
                    $_.type -ceq "follow" -and
                    [long]$_.actorUserId -eq 4101
                })
        Assert ($actualFollowNotifications.Count -eq 1) (
            "Refollow did not create exactly one authoritative member notification.")

        $socialEvidence = [ordered]@{
            physicalActionCount = $socialActions.Count
            actions = @($socialActions)
            unfollowedProfile = $unfollowedProfile
            emptyFriends = $emptyFriendsObservation
            emptyFollowing = Observe-Element $emptyFollowingStatus
            followerNames = $followerNames
            leaderboardNames = $leaderboardNames
            restoredProfile = Observe-Element $restoredFollowButton
            restoredFriends = $restoredFriendsObservation
            actualFollowNotificationCount = $actualFollowNotifications.Count
            screenshots = [ordered]@{
                unfollowed = $unfollowScreenshot
                emptyFriends = $emptyFriendsScreenshot
                restoredFriends = $restoredFriendsScreenshot
            }
        }
    }

    $serverState = Invoke-RestMethod -Uri ($endpoint + "harness/state")
    $expectedNotificationCount = if ($ExerciseSocialRelations) { 3 } else { 2 }
    Assert (
        [int]$serverState.notificationInjectionCount -eq 2 -and
        [int]$serverState.notificationFetchCount -ge 2 -and
        @($serverState.notifications).Count -eq $expectedNotificationCount) (
        "Loopback notification injection/poll evidence is incomplete.")
    if ($ExerciseSocialRelations) {
        Assert (
            [int]$serverState.followRequestCount -eq 2 -and
            [int]$serverState.followMutationCount -eq 2 -and
            [int]$serverState.followNotificationCount -eq 1 -and
            @($serverState.follows).Count -eq 2) (
            "Physical social relation mutations were not exact and idempotent.")
    }
    $topmostBeforeClose =
        [LumaChartFollowNotificationGuiNative]::IsTopmost($handle)
    Assert (-not $topmostBeforeClose) "Avalonia main window became topmost."

    $windowCloseMethod = Close-ApplicationWindow $client
    Assert ($client.WaitForExit(15000)) "Avalonia process did not exit after window close."
    $chartHashAfter = (
        Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
    $installerHashAfter = (
        Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
    Assert ($chartHashAfter -ceq $chartHashBefore) "Real chart fixture changed."
    Assert (
        $installerHashAfter -ceq $installerHashBefore) (
        "Frozen WPF installer changed.")

    $evidence = [ordered]@{
        schema = if ($ExerciseSocialRelations) {
            "lumachart.windows.avalonia.online-social-relations-gui-evidence.v1"
        } else {
            "lumachart.windows.avalonia.follow-notification-gui-evidence.v1"
        }
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        platform = "Windows Avalonia only"
        buildMode = "ordinary .NET Release"
        safety = [ordered]@{
            explicitCurrentTurnConsent = $true
            minimumIdleMilliseconds = 3000
            observedIdleMilliseconds =
                [long]$script:WindowsAvaloniaForegroundAutomationIdleMilliseconds
            heldModifierGate = $true
            productionServerDeployed = $false
            mobileProjectsBuiltModifiedInstalledOrTested = $false
            ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        }
        gui = [ordered]@{
            applicationPath = $applicationFullPath
            applicationSha256 = (
                Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
            processId = $client.Id
            processExitCode = $client.ExitCode
            realChart = [ordered]@{
                path = $chartFullPath
                sha256Before = $chartHashBefore
                sha256After = $chartHashAfter
                sourceUnchanged = $true
            }
            loopbackEndpoint = $endpoint
            highWaterFetchCount = $initialFetchCount
            firstInjection = [ordered]@{
                utc = $firstInjectionUtc.ToString("O")
                id = [long]$firstInjection.id
                actorDisplayName = [string]$firstInjection.actorDisplayName
            }
            secondInjection = [ordered]@{
                id = [long]$secondInjection.id
                actorDisplayName = [string]$secondInjection.actorDisplayName
            }
            firstToast = [ordered]@{
                observation = $firstObservation
                visibleDurationMilliseconds = $firstVisibleDurationMilliseconds
                screenshotCaptureMilliseconds =
                    $firstScreenshotCaptureMilliseconds
                captureAdjustedVisibleDurationMilliseconds =
                    $firstCaptureAdjustedDurationMilliseconds
                screenshot = $firstScreenshot
            }
            secondToast = [ordered]@{
                observation = $secondObservation
                visibleDurationMilliseconds = $secondVisibleDurationMilliseconds
                screenshotCaptureMilliseconds =
                    $secondScreenshotCaptureMilliseconds
                captureAdjustedVisibleDurationMilliseconds =
                    $secondCaptureAdjustedDurationMilliseconds
                screenshot = $secondScreenshot
            }
            communityHistory = [ordered]@{
                observation = $communityObservation
                descendantNames = $notificationNames
                firstNotificationRetained = $true
                anonymousNotificationRetained = $true
                screenshot = $communityScreenshot
            }
            socialRelations = $socialEvidence
            server = $serverState
            uiaInvokePatternUsed = $true
            windowCloseMethod = $windowCloseMethod
            uiaWindowClosePatternUsed =
                $windowCloseMethod -ceq "uia-window-pattern"
            processCloseMainWindowUsed =
                $windowCloseMethod -ceq "process-close-main-window"
            win32InputInjectionUsed = [bool]$ExerciseSocialRelations
            hardwareMouseInputClaimed = $false
            hardwareKeyboardInputClaimed = $false
            enterKeySent = $false
            persistentTopmostUsed = $false
            topmostAtStart = $topmostAtStart
            topmostBeforeClose = $topmostBeforeClose
        }
        frozenInstaller = [ordered]@{
            path = $installerPath
            sha256Before = $installerHashBefore
            sha256After = $installerHashAfter
        }
        completion = [ordered]@{
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
        }
    }
    $evidence | ConvertTo-Json -Depth 16 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    $evidence | ConvertTo-Json -Depth 16
}
finally {
    if ($client) {
        try {
            if (-not $client.HasExited) {
                Close-ApplicationWindow $client | Out-Null
                if (-not $client.WaitForExit(5000)) {
                    $client.Kill($true)
                    $client.WaitForExit(5000) | Out-Null
                }
            }
        }
        catch {
            try {
                if (-not $client.HasExited) {
                    $client.Kill($true)
                    $client.WaitForExit(5000) | Out-Null
                }
            }
            catch {
            }
        }
        $client.Dispose()
    }
    if ($server) {
        try {
            if (-not $server.HasExited) {
                $server.Kill($true)
                $server.WaitForExit(5000) | Out-Null
            }
        }
        catch {
        }
        $server.Dispose()
    }
}
