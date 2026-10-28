param(
    [Parameter(Mandatory = $true)][string]$ApplicationPath,
    [Parameter(Mandatory = $true)][string]$ProfileScreenshotPath,
    [Parameter(Mandatory = $true)][string]$DirectoryScreenshotPath,
    [Parameter(Mandatory = $true)][string]$PlayerScreenshotPath,
    [Parameter(Mandatory = $true)][string]$SettingsScreenshotPath,
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
    [Parameter(Mandatory = $true)][string]$LocalDataRoot,
    [Parameter(Mandatory = $true)][string]$EditingRoot,
    [string]$RoomLobbyScreenshotPath,
    [string]$RoomActiveScreenshotPath,
    [string]$RoomMemberScreenshotPath,
    [switch]$TitleFriendsOnlineNavigationOnly,
    [ValidateRange(10, 90)][int]$TimeoutSeconds = 40
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia community GUI capture requires PowerShell Core on Windows."
}

function Resolve-NewOutput([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Output already exists: $full" }
    New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($full)) | Out-Null
    return $full
}

$applicationFullPath = [IO.Path]::GetFullPath($ApplicationPath)
if (-not (Test-Path -LiteralPath $applicationFullPath -PathType Leaf)) {
    throw "Avalonia executable not found: $applicationFullPath"
}
$profileScreenshotFullPath = Resolve-NewOutput $ProfileScreenshotPath
$directoryScreenshotFullPath = Resolve-NewOutput $DirectoryScreenshotPath
$playerScreenshotFullPath = Resolve-NewOutput $PlayerScreenshotPath
$settingsScreenshotFullPath = Resolve-NewOutput $SettingsScreenshotPath
$includeRooms = -not [string]::IsNullOrWhiteSpace($RoomLobbyScreenshotPath) -or
    -not [string]::IsNullOrWhiteSpace($RoomActiveScreenshotPath) -or
    -not [string]::IsNullOrWhiteSpace($RoomMemberScreenshotPath)
if ($includeRooms -and (
        [string]::IsNullOrWhiteSpace($RoomLobbyScreenshotPath) -or
        [string]::IsNullOrWhiteSpace($RoomActiveScreenshotPath) -or
        [string]::IsNullOrWhiteSpace($RoomMemberScreenshotPath))) {
    throw "Room lobby, active-room and member-management screenshot paths must be supplied together."
}
$roomLobbyScreenshotFullPath = if ($includeRooms) { Resolve-NewOutput $RoomLobbyScreenshotPath } else { $null }
$roomActiveScreenshotFullPath = if ($includeRooms) { Resolve-NewOutput $RoomActiveScreenshotPath } else { $null }
$roomMemberScreenshotFullPath = if ($includeRooms) { Resolve-NewOutput $RoomMemberScreenshotPath } else { $null }
$evidenceFullPath = Resolve-NewOutput $EvidencePath
$workspaceFullPath = [IO.Path]::GetFullPath($WorkspaceRoot)
$localDataFullPath = [IO.Path]::GetFullPath($LocalDataRoot)
$editingFullPath = [IO.Path]::GetFullPath($EditingRoot)
foreach ($directory in @($workspaceFullPath, $localDataFullPath, $editingFullPath)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Collections.Concurrent;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;

public sealed class LumaChartCommunityMockServer : IDisposable
{
    private readonly TcpListener listener;
    private readonly Thread thread;
    private volatile bool stopping;
    public ConcurrentQueue<string> Requests { get; } = new ConcurrentQueue<string>();
    public int Port { get; }

    public LumaChartCommunityMockServer()
    {
        listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        Port = ((IPEndPoint)listener.LocalEndpoint).Port;
        thread = new Thread(Run) { IsBackground = true, Name = "LumaChart community GUI mock" };
        thread.Start();
    }

    private void Run()
    {
        while (!stopping)
        {
            TcpClient client;
            try { client = listener.AcceptTcpClient(); }
            catch (SocketException) when (stopping) { return; }
            catch (ObjectDisposedException) { return; }
            using (client)
            {
                try { Handle(client.GetStream()); }
                catch (IOException) { }
                catch (SocketException) { }
            }
        }
    }

    private void Handle(NetworkStream stream)
    {
        var header = ReadHeader(stream);
        if (header.Length == 0) return;
        var lines = header.Split(new[] { "\r\n" }, StringSplitOptions.None);
        var first = lines[0].Split(' ');
        if (first.Length < 2) return;
        var method = first[0];
        var rawPath = first[1];
        Requests.Enqueue(method + " " + rawPath);
        var contentLength = 0;
        var chunked = false;
        foreach (var line in lines)
        {
            if (line.StartsWith("Content-Length:", StringComparison.OrdinalIgnoreCase))
                int.TryParse(line.Substring("Content-Length:".Length).Trim(), out contentLength);
            if (line.StartsWith("Transfer-Encoding:", StringComparison.OrdinalIgnoreCase) &&
                line.IndexOf("chunked", StringComparison.OrdinalIgnoreCase) >= 0)
                chunked = true;
        }
        if (chunked)
        {
            ReadChunkedBody(stream);
        }
        else
        {
            var remaining = contentLength;
            var buffer = new byte[8192];
            while (remaining > 0)
            {
                var read = stream.Read(buffer, 0, Math.Min(buffer.Length, remaining));
                if (read <= 0) break;
                remaining -= read;
            }
        }

        var path = rawPath.Split('?')[0].TrimStart('/');
        var status = 200;
        string body;
        if (path == "api/auth/captcha")
        {
            body = "{\"id\":\"11111111-2222-3333-4444-555555555555\"," +
                   "\"imageBase64\":\"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=\"," +
                   "\"expiresAt\":\"2099-07-24T12:00:00Z\"}";
        }
        else if (path == "api/auth/login")
        {
            body = "{\"accessToken\":\"community-gui-token\"," +
                   "\"expiresAt\":\"2099-07-24T12:00:00Z\"," +
                   "\"user\":" + UserJson(41, "gui-user", "界面验收用户", 2, 3) + "}";
        }
        else if (path == "api/me/notifications")
        {
            body = "{\"nextCursor\":0,\"hasMore\":false,\"notifications\":[]}";
        }
        else if (path == "api/rooms" && method == "GET")
        {
            body = "{\"rooms\":[" + RoomJson() + "],\"page\":1,\"pageSize\":10,\"totalCount\":1}";
        }
        else if (path == "api/me/invitations")
        {
            body = "[]";
        }
        else if (path == "api/rooms/91111111-2222-3333-4444-555555555555/join")
        {
            body = RoomJson();
        }
        else if (path == "api/rooms/91111111-2222-3333-4444-555555555555/live")
        {
            body = LiveRoomJson();
        }
        else if (path == "api/rooms/91111111-2222-3333-4444-555555555555/heartbeat")
        {
            status = 204;
            body = "";
        }
        else if (path == "api/players/72")
        {
            body = PlayerJson(72, "在线制谱师", true, true, true);
        }
        else if (path == "api/players" ||
                 path == "api/players/search" ||
                 path == "api/players/leaderboard" ||
                 path == "api/me/friends" ||
                 path == "api/me/following" ||
                 path == "api/me/followers")
        {
            body = "{\"onlineCount\":2,\"players\":[" +
                   PlayerJson(72, "在线制谱师", true, true, true) + "," +
                   PlayerJson(73, "节奏玩家", false, false, false) +
                   "],\"page\":1,\"pageSize\":100,\"totalCount\":2}";
        }
        else if (path == "api/auth/logout")
        {
            status = 204;
            body = "";
        }
        else
        {
            status = 404;
            body = "{\"code\":\"not_found\",\"message\":\"Mock route not found.\"}";
        }
        WriteResponse(stream, status, body);
    }

    private static string UserJson(long id, string username, string displayName, int following, int followers)
    {
        return "{\"id\":" + id +
               ",\"username\":\"" + username + "\"" +
               ",\"displayName\":\"" + displayName + "\"" +
               ",\"role\":\"user\",\"avatarKey\":\"default\"," +
               "\"createdAt\":\"2025-01-02T03:04:05Z\",\"chartingSeconds\":98765," +
               "\"bio\":\"用于 Windows Avalonia 个人主页与社区界面验收。\"," +
               "\"hidePublicAvatar\":false,\"hidePublicName\":false," +
               "\"followingCount\":" + following + ",\"followerCount\":" + followers + "," +
               "\"customLabel\":\"\",\"tags\":[{\"name\":\"制谱师\",\"color\":\"#79B8BD\",\"isNameColor\":true}]," +
               "\"email\":\"gui@example.invalid\"}";
    }

    private static string PlayerJson(long id, string displayName, bool online, bool following, bool mutual)
    {
        var nameColor = id == 72
            ? "{\"name\":\"名字色\",\"color\":\"#37B8E8\",\"isNameColor\":true}"
            : "{\"name\":\"玩家\",\"color\":\"#8FC4A5\",\"isNameColor\":false}";
        return "{\"id\":" + id + ",\"displayName\":\"" + displayName + "\"," +
               "\"avatarKey\":\"default\",\"bio\":\"公开玩家资料与关注关系验收。\"," +
               "\"chartingSeconds\":45678,\"followingCount\":4,\"followerCount\":5," +
               "\"isFollowing\":" + following.ToString().ToLowerInvariant() + "," +
               "\"isMutual\":" + mutual.ToString().ToLowerInvariant() + "," +
               "\"isOnline\":" + online.ToString().ToLowerInvariant() + "," +
               "\"isNameHidden\":false,\"isAvatarHidden\":false,\"customLabel\":\"\"," +
               "\"tags\":[" + nameColor + "]}";
    }

    private static string RoomJson()
    {
        return "{\"id\":\"91111111-2222-3333-4444-555555555555\"," +
               "\"roomNumber\":654321,\"name\":\"Windows Avalonia 协作房\"," +
               "\"ownerUserId\":41,\"ownerDisplayName\":\"界面验收用户\"," +
               "\"memberCount\":2,\"maximumMembers\":16,\"isPrivate\":true,\"isHidden\":false," +
               "\"resourcesReady\":true,\"resourceBytes\":2048,\"createdAt\":\"2026-07-23T10:00:00Z\"}";
    }

    private static string LiveRoomJson()
    {
        return "{\"room\":" + RoomJson() + ",\"members\":[" +
               "{\"userId\":41,\"username\":\"gui-user\",\"displayName\":\"界面验收用户\"," +
               "\"avatarKey\":\"default\",\"memberRole\":\"owner\",\"joinedAt\":\"2026-07-23T10:00:00Z\"," +
               "\"isOnline\":true,\"customLabel\":\"\",\"tags\":[]," +
               "\"canEditMetadata\":true,\"canEditTiming\":true,\"canEditNotes\":true}," +
               "{\"userId\":72,\"username\":\"mapper72\",\"displayName\":\"离线制谱师\"," +
               "\"avatarKey\":\"default\",\"memberRole\":\"editor\",\"joinedAt\":\"2026-07-23T10:01:00Z\"," +
               "\"isOnline\":false,\"customLabel\":\"\",\"tags\":[]," +
               "\"canEditMetadata\":false,\"canEditTiming\":true,\"canEditNotes\":true}]," +
               "\"messages\":[{\"id\":1,\"userId\":72,\"username\":\"mapper72\"," +
               "\"displayName\":\"离线制谱师\",\"avatarKey\":\"default\",\"memberRole\":\"editor\"," +
               "\"message\":\"欢迎进入协作房间。\",\"createdAt\":\"2026-07-23T10:02:00Z\"," +
               "\"customLabel\":\"\",\"tags\":[]}],\"latestMessageId\":1}";
    }

    private static string ReadHeader(NetworkStream stream)
    {
        using (var memory = new MemoryStream())
        {
            var state = 0;
            while (memory.Length < 64 * 1024)
            {
                var value = stream.ReadByte();
                if (value < 0) break;
                memory.WriteByte((byte)value);
                state = state == 0 && value == 13 ? 1 :
                        state == 1 && value == 10 ? 2 :
                        state == 2 && value == 13 ? 3 :
                        state == 3 && value == 10 ? 4 :
                        value == 13 ? 1 : 0;
                if (state == 4) break;
            }
            return Encoding.ASCII.GetString(memory.ToArray());
        }
    }

    private static void ReadChunkedBody(NetworkStream stream)
    {
        while (true)
        {
            var sizeLine = ReadAsciiLine(stream);
            var semicolon = sizeLine.IndexOf(';');
            if (semicolon >= 0) sizeLine = sizeLine.Substring(0, semicolon);
            var size = Convert.ToInt32(sizeLine.Trim(), 16);
            if (size == 0)
            {
                while (ReadAsciiLine(stream).Length != 0) { }
                return;
            }
            var remaining = size;
            var buffer = new byte[8192];
            while (remaining > 0)
            {
                var read = stream.Read(buffer, 0, Math.Min(buffer.Length, remaining));
                if (read <= 0) throw new EndOfStreamException();
                remaining -= read;
            }
            if (stream.ReadByte() != 13 || stream.ReadByte() != 10)
                throw new InvalidDataException("Invalid chunk terminator.");
        }
    }

    private static string ReadAsciiLine(NetworkStream stream)
    {
        using (var memory = new MemoryStream())
        {
            while (true)
            {
                var value = stream.ReadByte();
                if (value < 0) throw new EndOfStreamException();
                if (value == 13)
                {
                    if (stream.ReadByte() != 10) throw new InvalidDataException("Invalid line ending.");
                    return Encoding.ASCII.GetString(memory.ToArray());
                }
                memory.WriteByte((byte)value);
            }
        }
    }

    private static void WriteResponse(NetworkStream stream, int status, string body)
    {
        var bytes = Encoding.UTF8.GetBytes(body);
        var reason = status == 200 ? "OK" : status == 204 ? "No Content" : "Not Found";
        var header = "HTTP/1.1 " + status + " " + reason + "\r\n" +
                     "Content-Type: application/json; charset=utf-8\r\n" +
                     "Content-Length: " + bytes.Length + "\r\n" +
                     "Connection: close\r\n\r\n";
        var headerBytes = Encoding.ASCII.GetBytes(header);
        stream.Write(headerBytes, 0, headerBytes.Length);
        if (bytes.Length > 0) stream.Write(bytes, 0, bytes.Length);
        stream.Flush();
    }

    public void Dispose()
    {
        stopping = true;
        listener.Stop();
        if (!thread.Join(TimeSpan.FromSeconds(3))) thread.Interrupt();
    }
}

public static class LumaChartCommunityCaptureNative
{
    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr window, IntPtr deviceContext, uint flags);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr window, int command);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr value);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern void mouse_event(
        uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
}
'@
[LumaChartCommunityCaptureNative]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 90000)][int]$TimeoutMilliseconds
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId)
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children, $processCondition)
            foreach ($root in $roots) {
                if ([string]::Equals([string]$root.Current.AutomationId, $AutomationId,
                        [StringComparison]::Ordinal)) { return $root }
                $candidate = $root.FindFirst([Windows.Automation.TreeScope]::Descendants, $idCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Wait-ElementUnavailable {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 90000)][int]$TimeoutMilliseconds
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId)
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        $candidate = $null
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children, $processCondition)
            foreach ($root in $roots) {
                $candidate = $root.FindFirst(
                    [Windows.Automation.TreeScope]::Descendants,
                    $idCondition)
                if ($candidate) { break }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { $candidate = $null }
        catch [Runtime.InteropServices.COMException] { $candidate = $null }
        if (-not $candidate) { return }
        Start-Sleep -Milliseconds 75
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out waiting for UI Automation id '$AutomationId' to close."
}

function Observe-Element($Element) {
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

function Invoke-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Click-ElementPhysical($Element, [IntPtr]$WindowHandle) {
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -le 1 -or $bounds.Height -le 1 -or $Element.Current.IsOffscreen) {
        throw "Element '$($Element.Current.AutomationId)' has no physical click target."
    }
    [void][LumaChartCommunityCaptureNative]::SetForegroundWindow($WindowHandle)
    Start-Sleep -Milliseconds 120
    $x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    if (-not [LumaChartCommunityCaptureNative]::SetCursorPos($x, $y)) {
        throw "SetCursorPos failed for '$($Element.Current.AutomationId)'."
    }
    [LumaChartCommunityCaptureNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 45
    [LumaChartCommunityCaptureNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 180
}

function Set-ElementValue($Element, [string]$Value) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose ValuePattern."
    }
    ([Windows.Automation.ValuePattern]$pattern).SetValue($Value)
}

function Wait-ElementName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][string]$Like,
        [ValidateRange(100, 90000)][int]$TimeoutMilliseconds
    )
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        $element = Find-ElementById -ProcessId $ProcessId -AutomationId $AutomationId -TimeoutMilliseconds 2000
        if ([string]$element.Current.Name -like $Like) { return $element }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Element '$AutomationId' did not reach expected name '$Like'."
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartCommunityCaptureNative+RECT]::new()
    if (-not [LumaChartCommunityCaptureNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 700 -or $height -lt 500) {
        throw "Community window has invalid bounds: $($width)x$($height)."
    }
    $bitmap = [Drawing.Bitmap]::new($width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $dc = $graphics.GetHdc()
            try {
                if (-not [LumaChartCommunityCaptureNative]::PrintWindow($Handle, $dc, 2)) {
                    throw "PrintWindow failed for community dialog."
                }
            }
            finally { $graphics.ReleaseHdc($dc) }
        }
        finally { $graphics.Dispose() }
        $colors = [Collections.Generic.HashSet[int]]::new()
        $luminance = [Collections.Generic.List[double]]::new()
        for ($y = 0; $y -lt 16; $y++) {
            $pixelY = [Math]::Min($height - 1, [int](($y + .5) * $height / 16))
            for ($x = 0; $x -lt 16; $x++) {
                $pixelX = [Math]::Min($width - 1, [int](($x + .5) * $width / 16))
                $pixel = $bitmap.GetPixel($pixelX, $pixelY)
                [void]$colors.Add($pixel.ToArgb())
                $luminance.Add(.2126 * $pixel.R + .7152 * $pixel.G + .0722 * $pixel.B)
            }
        }
        $mean = ($luminance | Measure-Object -Average).Average
        $variance = ($luminance | ForEach-Object {
            $difference = $_ - $mean
            $difference * $difference
        } | Measure-Object -Average).Average
        $stdDev = [Math]::Sqrt([double]$variance)
        if ($colors.Count -lt 8 -or $stdDev -lt 1.0) {
            throw "Community screenshot is near-uniform: colors=$($colors.Count); stdDev=$stdDev."
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            width = $width
            height = $height
            sampledUniqueColors = $colors.Count
            sampledLuminanceStdDev = $stdDev
        }
    }
    finally { $bitmap.Dispose() }
}

$server = [LumaChartCommunityMockServer]::new()
$endpoint = "http://127.0.0.1:$($server.Port)/"
$start = [Diagnostics.ProcessStartInfo]::new($applicationFullPath)
$start.UseShellExecute = $false
$start.Environment["LUMACHART_SERVER_URL"] = $endpoint
$start.Environment["LUMACHART_PROFILE"] = "community-gui-evidence"
$start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataFullPath
$start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingFullPath
$start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceFullPath
$process = [Diagnostics.Process]::Start($start)
$captures = [ordered]@{}
$controls = [ordered]@{}
try {
    if ($TitleFriendsOnlineNavigationOnly) {
        $windowDeadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutSeconds * 1000)
        do {
            $process.Refresh()
            if ($process.MainWindowHandle -ne [IntPtr]::Zero) { break }
            Start-Sleep -Milliseconds 75
        } while ([DateTime]::UtcNow -lt $windowDeadline)
        if ($process.MainWindowHandle -eq [IntPtr]::Zero) {
            throw "Application main window handle was unavailable."
        }
        [void][LumaChartCommunityCaptureNative]::ShowWindowAsync($process.MainWindowHandle, 3)
        [void][LumaChartCommunityCaptureNative]::SetForegroundWindow($process.MainWindowHandle)
        Start-Sleep -Milliseconds 350
        $communityHandle = [IntPtr]$process.MainWindowHandle
    }
    else {
        $accountButton = Find-ElementById -ProcessId $process.Id -AutomationId "OnlineAccount.Navigation" -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        Invoke-Element $accountButton
    }
    [void](Wait-ElementName -ProcessId $process.Id -AutomationId "OnlineAccount.Login.Status" -Like "请输入用户名、密码和图片中的*" -TimeoutMilliseconds ($TimeoutSeconds * 1000))
    Set-ElementValue (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineAccount.Login.Username" -TimeoutMilliseconds 3000) "gui-user"
    Set-ElementValue (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineAccount.Login.Password" -TimeoutMilliseconds 3000) "gui-password-value"
    Set-ElementValue (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineAccount.Login.CaptchaAnswer" -TimeoutMilliseconds 3000) "12345"
    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineAccount.Login.Submit" -TimeoutMilliseconds 3000)

    if ($TitleFriendsOnlineNavigationOnly) {
        Wait-ElementUnavailable -ProcessId $process.Id -AutomationId "OnlineAccount.Layer" -TimeoutMilliseconds 5000
        $friendsTitleButton = Find-ElementById -ProcessId $process.Id -AutomationId "Title.Friends" -TimeoutMilliseconds 3000
        Invoke-Element $friendsTitleButton
        $process.Refresh()
        $communityHandle = [IntPtr]$process.MainWindowHandle
        if ($communityHandle -eq [IntPtr]::Zero) { throw "Application main window handle was unavailable." }
        $friendsOnlineCount = Wait-ElementName -ProcessId $process.Id -AutomationId "FriendsPanel.OnlineCount" -Like "在线 2*" -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $friendsStatus = Wait-ElementName -ProcessId $process.Id -AutomationId "FriendsPanel.Status" -Like "共 * 名好友" -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $friendsPanel = Find-ElementById -ProcessId $process.Id -AutomationId "FriendsPanel" -TimeoutMilliseconds 3000
        $friendsPanelBounds = $friendsPanel.Current.BoundingRectangle
        if ($friendsPanel.Current.IsOffscreen -or
            $friendsPanelBounds.Width -lt 250 -or
            $friendsPanelBounds.Width -gt 700 -or
            $friendsPanelBounds.Height -gt 900) {
            throw "The compact Friends panel did not match its anchored 330x520 maximum contract."
        }
        $friendsOnlineCountName = [string]$friendsOnlineCount.Current.Name
        $friendsStatusName = [string]$friendsStatus.Current.Name
        $friendsPanelObservation = Observe-Element $friendsPanel
        $captures.friends = Capture-Window $communityHandle $profileScreenshotFullPath

        $onlineTitleButton = Find-ElementById -ProcessId $process.Id -AutomationId "Title.Online" -TimeoutMilliseconds 3000
        Invoke-Element $onlineTitleButton
        $roomsStatus = Wait-ElementName -ProcessId $process.Id -AutomationId "OnlineRooms.Directory.Status" -Like "第 1/1 页*" -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $captures.rooms = Capture-Window $communityHandle $directoryScreenshotFullPath
        if ($process.HasExited) {
            throw "Application exited after the title Friends -> Online navigation chain."
        }

        $requests = @($server.Requests.ToArray())
        foreach ($required in @(
            "GET /api/me/friends",
            "GET /api/rooms?page=1&q=",
            "GET /api/me/invitations")) {
            if (-not ($requests -contains $required)) { throw "Mock request was not observed: $required" }
        }
        $fatalDiagnostics = @(
            Get-ChildItem -LiteralPath $localDataFullPath -Recurse -File -ErrorAction SilentlyContinue |
                Select-String -SimpleMatch '"Fatal":true' -ErrorAction SilentlyContinue
        )
        if ($fatalDiagnostics.Count -ne 0) {
            throw "A fatal diagnostic was recorded during title Friends -> Online navigation."
        }
        $evidence = [ordered]@{
            schema = "lumachart.windows.avalonia.compact-friends-online-navigation-gui-evidence.v2"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed"
            applicationPath = $applicationFullPath
            applicationSha256 = (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
            applicationAssemblySha256 = (Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($applicationFullPath, ".dll")) -Algorithm SHA256).Hash
            endpoint = $endpoint
            isolatedLoopbackMock = $true
            productionMutationPerformed = $false
            mouseInputUsed = $false
            physicalActionCount = 0
            uiaInvokeActionCount = 2
            keyboardInputUsed = $false
            processId = $process.Id
            hostedInMainWindow = $true
            compactFriendsPanel = [ordered]@{
                automationId = "FriendsPanel"
                onlineCount = $friendsOnlineCountName
                status = $friendsStatusName
                width = [double]$friendsPanelObservation.bounds.width
                height = [double]$friendsPanelObservation.bounds.height
                isOffscreen = [bool]$friendsPanelObservation.isOffscreen
            }
            processAliveAfterNavigation = -not $process.HasExited
            fatalDiagnosticCount = $fatalDiagnostics.Count
            actions = @(
                [ordered]@{
                    automationId = "Title.Friends"
                    resultAutomationId = "FriendsPanel.Status"
                    resultName = $friendsStatusName
                },
                [ordered]@{
                    automationId = "Title.Online"
                    resultAutomationId = "OnlineRooms.Directory.Status"
                    resultName = [string]$roomsStatus.Current.Name
                }
            )
            requests = $requests
            screenshots = [ordered]@{
                friends = [ordered]@{
                    path = $profileScreenshotFullPath
                    sha256 = (Get-FileHash -LiteralPath $profileScreenshotFullPath -Algorithm SHA256).Hash
                    capture = $captures.friends
                }
                rooms = [ordered]@{
                    path = $directoryScreenshotFullPath
                    sha256 = (Get-FileHash -LiteralPath $directoryScreenshotFullPath -Algorithm SHA256).Hash
                    capture = $captures.rooms
                }
            }
        }
        $evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $evidenceFullPath -Encoding utf8NoBOM
        Write-Output "Windows Avalonia title Friends -> Online GUI capture: passed"
        Write-Output "Evidence: $evidenceFullPath"
        return
    }

    $community = Find-ElementById -ProcessId $process.Id -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $communityNativeHandle = [IntPtr]$community.Current.NativeWindowHandle
    $hostedInMainWindow = $communityNativeHandle -eq [IntPtr]::Zero
    $communityHandle = if ($hostedInMainWindow) {
        [IntPtr]$process.MainWindowHandle
    } else {
        $communityNativeHandle
    }
    if ($communityHandle -eq [IntPtr]::Zero) { throw "Community capture window handle was unavailable." }
    foreach ($id in @(
        "OnlineCommunity.Identity",
        "OnlineCommunity.Navigation.Profile",
        "OnlineCommunity.Navigation.Players",
        "OnlineCommunity.Navigation.Leaderboard",
        "OnlineCommunity.Navigation.Friends",
        "OnlineCommunity.Navigation.Following",
        "OnlineCommunity.Navigation.Followers",
        "OnlineCommunity.Navigation.Notifications",
        "OnlineCommunity.Navigation.Settings",
        "OnlineCommunity.Profile.DisplayName",
        "OnlineCommunity.Profile.Bio",
        "OnlineCommunity.Profile.HideAvatar",
        "OnlineCommunity.Profile.HideName",
        "OnlineCommunity.Profile.UploadAvatar",
        "OnlineCommunity.Profile.Save",
        "OnlineCommunity.Profile.NameColor",
        "OnlineCommunity.Profile.NameColorApply")) {
        $controls[$id] = Observe-Element (Find-ElementById -ProcessId $process.Id -AutomationId $id -TimeoutMilliseconds ($TimeoutSeconds * 1000))
    }
    $captures.profile = Capture-Window $communityHandle $profileScreenshotFullPath

    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineCommunity.Navigation.Players" -TimeoutMilliseconds 3000)
    $directoryStatus = Wait-ElementName -ProcessId $process.Id -AutomationId "OnlineCommunity.Directory.Status" -Like "在线 2*" -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    foreach ($id in @(
        "OnlineCommunity.Directory.SearchText",
        "OnlineCommunity.Directory.Search",
        "OnlineCommunity.Directory.List",
        "OnlineCommunity.Directory.Previous",
        "OnlineCommunity.Directory.Next",
        "OnlineCommunity.Player.72.Open")) {
        $controls[$id] = Observe-Element (Find-ElementById -ProcessId $process.Id -AutomationId $id -TimeoutMilliseconds ($TimeoutSeconds * 1000))
    }
    $controls["OnlineCommunity.Directory.Status"] = Observe-Element $directoryStatus
    $playersName = Find-ElementById -ProcessId $process.Id -AutomationId "OnlineCommunity.Player.72.Name" -TimeoutMilliseconds 3000
    if ([string]$playersName.Current.HelpText -notlike "NameColor=#37B8E8; Source=selected-tag*") {
        throw "All-players row did not expose the selected #37B8E8 name color."
    }
    $controls["OnlineCommunity.Players.NameColor"] = Observe-Element $playersName
    $captures.directory = Capture-Window $communityHandle $directoryScreenshotFullPath

    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineCommunity.Navigation.Leaderboard" -TimeoutMilliseconds 3000)
    [void](Wait-ElementName -ProcessId $process.Id -AutomationId "OnlineCommunity.Directory.Status" -Like "在线 2*" -TimeoutMilliseconds ($TimeoutSeconds * 1000))
    $leaderboardName = Find-ElementById -ProcessId $process.Id -AutomationId "OnlineCommunity.Player.72.Name" -TimeoutMilliseconds 3000
    if ([string]$leaderboardName.Current.HelpText -notlike "NameColor=#37B8E8; Source=selected-tag*") {
        throw "Leaderboard row did not expose the selected #37B8E8 name color."
    }
    $controls["OnlineCommunity.Leaderboard.NameColor"] = Observe-Element $leaderboardName

    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineCommunity.Navigation.Players" -TimeoutMilliseconds 3000)
    [void](Wait-ElementName -ProcessId $process.Id -AutomationId "OnlineCommunity.Directory.Status" -Like "在线 2*" -TimeoutMilliseconds ($TimeoutSeconds * 1000))
    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineCommunity.Player.72.Open" -TimeoutMilliseconds 3000)
    foreach ($id in @(
        "OnlineCommunity.Player.Follow",
        "OnlineCommunity.Player.Back",
        "OnlineCommunity.Player.Status")) {
        $controls[$id] = Observe-Element (Find-ElementById -ProcessId $process.Id -AutomationId $id -TimeoutMilliseconds ($TimeoutSeconds * 1000))
    }
    $captures.player = Capture-Window $communityHandle $playerScreenshotFullPath

    Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineCommunity.Navigation.Settings" -TimeoutMilliseconds 3000)
    [void](Wait-ElementName -ProcessId $process.Id -AutomationId "OnlineCommunity.Settings.Email.Status" -Like "请输入图片中的*" -TimeoutMilliseconds ($TimeoutSeconds * 1000))
    foreach ($id in @(
        "OnlineCommunity.Settings.Email.CurrentPassword",
        "OnlineCommunity.Settings.Email.NewEmail",
        "OnlineCommunity.Settings.Email.CaptchaImage",
        "OnlineCommunity.Settings.Email.CaptchaAnswer",
        "OnlineCommunity.Settings.Email.CaptchaRefresh",
        "OnlineCommunity.Settings.Email.SendCode",
        "OnlineCommunity.Settings.Email.Code",
        "OnlineCommunity.Settings.Email.Apply",
        "OnlineCommunity.Settings.Password.Current",
        "OnlineCommunity.Settings.Password.New",
        "OnlineCommunity.Settings.Password.Confirm",
        "OnlineCommunity.Settings.Password.Apply",
        "OnlineCommunity.Settings.Logout")) {
        $controls[$id] = Observe-Element (Find-ElementById -ProcessId $process.Id -AutomationId $id -TimeoutMilliseconds ($TimeoutSeconds * 1000))
    }
    $captures.settings = Capture-Window $communityHandle $settingsScreenshotFullPath

    if ($includeRooms) {
        Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineCommunity.Navigation.Rooms" -TimeoutMilliseconds 3000)
        $roomDirectoryStatus = Wait-ElementName -ProcessId $process.Id -AutomationId "OnlineRooms.Directory.Status" -Like "第 1/1 页*" -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        foreach ($id in @(
            "OnlineRooms.Directory.SearchText",
            "OnlineRooms.Directory.Search",
            "OnlineRooms.Directory.List",
            "OnlineRooms.Directory.Previous",
            "OnlineRooms.Directory.Next",
            "OnlineRooms.Room.654321.Join",
            "OnlineRooms.Create.Name",
            "OnlineRooms.Create.Private",
            "OnlineRooms.Create.Password",
            "OnlineRooms.Create.Hidden",
            "OnlineRooms.Create.Submit",
            "OnlineRooms.JoinByNumber.Number",
            "OnlineRooms.JoinByNumber.Password",
            "OnlineRooms.JoinByNumber.Find",
            "OnlineRooms.Invitations.List",
            "OnlineRooms.Invitations.Refresh")) {
            $controls[$id] = Observe-Element (Find-ElementById -ProcessId $process.Id -AutomationId $id -TimeoutMilliseconds ($TimeoutSeconds * 1000))
        }
        $controls["OnlineRooms.Directory.Status"] = Observe-Element $roomDirectoryStatus
        $captures.roomLobby = Capture-Window $communityHandle $roomLobbyScreenshotFullPath

        Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineRooms.Room.654321.Join" -TimeoutMilliseconds 3000)
        Set-ElementValue (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineRooms.Join.Password" -TimeoutMilliseconds 3000) "room-password"
        Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineRooms.Join.Submit" -TimeoutMilliseconds 3000)
        $activeStatus = Find-ElementById -ProcessId $process.Id -AutomationId "OnlineRooms.Active.Status" -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        foreach ($id in @(
            "OnlineRooms.Active.InviteFriend",
            "OnlineRooms.Active.Refresh",
            "OnlineRooms.Active.Leave",
            "OnlineRooms.Active.Members",
            "OnlineRooms.Active.Chat",
            "OnlineRooms.Active.ChatText",
            "OnlineRooms.Active.ChatSend",
            "OnlineRooms.Member.72.Manage")) {
            $controls[$id] = Observe-Element (Find-ElementById -ProcessId $process.Id -AutomationId $id -TimeoutMilliseconds ($TimeoutSeconds * 1000))
        }
        $controls["OnlineRooms.Active.Status"] = Observe-Element $activeStatus
        $captures.roomActive = Capture-Window $communityHandle $roomActiveScreenshotFullPath

        Invoke-Element (Find-ElementById -ProcessId $process.Id -AutomationId "OnlineRooms.Member.72.Manage" -TimeoutMilliseconds 3000)
        foreach ($id in @(
            "OnlineRooms.Member.Role",
            "OnlineRooms.Member.Metadata",
            "OnlineRooms.Member.Timing",
            "OnlineRooms.Member.Notes",
            "OnlineRooms.Member.Save",
            "OnlineRooms.Member.Kick",
            "OnlineRooms.Member.Ban",
            "OnlineRooms.Member.Back",
            "OnlineRooms.Member.Status")) {
            $controls[$id] = Observe-Element (Find-ElementById -ProcessId $process.Id -AutomationId $id -TimeoutMilliseconds ($TimeoutSeconds * 1000))
        }
        $captures.roomMember = Capture-Window $communityHandle $roomMemberScreenshotFullPath
    }

    $requests = @($server.Requests.ToArray())
    foreach ($required in @(
        "GET /api/auth/captcha",
        "POST /api/auth/login",
        "GET /api/me/notifications?limit=50",
        "GET /api/players?page=1",
        "GET /api/players/leaderboard",
        "GET /api/players/72")) {
        if (-not ($requests -contains $required)) { throw "Mock request was not observed: $required" }
    }
    if ($includeRooms) {
        foreach ($required in @(
            "GET /api/rooms?page=1&q=",
            "GET /api/me/invitations",
            "POST /api/rooms/91111111-2222-3333-4444-555555555555/join",
            "GET /api/rooms/91111111-2222-3333-4444-555555555555/live?after=0")) {
            if (-not ($requests -contains $required)) { throw "Room mock request was not observed: $required" }
        }
    }
    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.community-gui-evidence.v2"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        applicationPath = $applicationFullPath
        applicationSha256 = (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
        applicationAssemblySha256 = (Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($applicationFullPath, ".dll")) -Algorithm SHA256).Hash
        endpoint = $endpoint
        isolatedLoopbackMock = $true
        productionMutationPerformed = $false
        mouseInputUsed = $false
        keyboardInputUsed = $false
        processId = $process.Id
        hostedInMainWindow = $hostedInMainWindow
        separateNativeWindowCreated = -not $hostedInMainWindow
        captureWindowHandle = $communityHandle.ToInt64()
        dialog = Observe-Element $community
        controls = $controls
        requests = $requests
        screenshots = [ordered]@{
            profile = [ordered]@{
                path = $profileScreenshotFullPath
                sha256 = (Get-FileHash -LiteralPath $profileScreenshotFullPath -Algorithm SHA256).Hash
                capture = $captures.profile
            }
            directory = [ordered]@{
                path = $directoryScreenshotFullPath
                sha256 = (Get-FileHash -LiteralPath $directoryScreenshotFullPath -Algorithm SHA256).Hash
                capture = $captures.directory
            }
            player = [ordered]@{
                path = $playerScreenshotFullPath
                sha256 = (Get-FileHash -LiteralPath $playerScreenshotFullPath -Algorithm SHA256).Hash
                capture = $captures.player
            }
            settings = [ordered]@{
                path = $settingsScreenshotFullPath
                sha256 = (Get-FileHash -LiteralPath $settingsScreenshotFullPath -Algorithm SHA256).Hash
                capture = $captures.settings
            }
        }
    }
    if ($includeRooms) {
        $evidence.screenshots.Add("roomLobby", [ordered]@{
            path = $roomLobbyScreenshotFullPath
            sha256 = (Get-FileHash -LiteralPath $roomLobbyScreenshotFullPath -Algorithm SHA256).Hash
            capture = $captures.roomLobby
        })
        $evidence.screenshots.Add("roomActive", [ordered]@{
            path = $roomActiveScreenshotFullPath
            sha256 = (Get-FileHash -LiteralPath $roomActiveScreenshotFullPath -Algorithm SHA256).Hash
            capture = $captures.roomActive
        })
        $evidence.screenshots.Add("roomMember", [ordered]@{
            path = $roomMemberScreenshotFullPath
            sha256 = (Get-FileHash -LiteralPath $roomMemberScreenshotFullPath -Algorithm SHA256).Hash
            capture = $captures.roomMember
        })
    }
    $evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $evidenceFullPath -Encoding utf8NoBOM
    Write-Output "Windows Avalonia community GUI capture: passed"
    Write-Output "Evidence: $evidenceFullPath"
}
catch {
    $loginStatusName = "<unavailable>"
    try {
        $loginStatusName = [string](Find-ElementById -ProcessId $process.Id -AutomationId "OnlineAccount.Login.Status" -TimeoutMilliseconds 500).Current.Name
    }
    catch { }
    Write-Host ("Community GUI capture failed. Mock requests: " +
        [string]::Join(" | ", @($server.Requests.ToArray())) +
        "; login status: " + $loginStatusName)
    throw
}
finally {
    if ($process -and -not $process.HasExited) {
        [void]$process.CloseMainWindow()
        if (-not $process.WaitForExit(5000)) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            [void]$process.WaitForExit(3000)
        }
    }
    $process.Dispose()
    $server.Dispose()
}
