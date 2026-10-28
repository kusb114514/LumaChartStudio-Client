[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$BaseUrl,

    [string]$ProfileA = "Test-Client-A",
    [string]$ProfileB = "Test-Client-B",
    [string]$ClientVersion = "",

    [ValidateRange(135, 600)]
    [int]$ProbeSeconds = 150,

    [ValidateRange(16, 30)]
    [int]$PollSeconds = 20,

    [ValidateRange(1, 1440)]
    [int]$BanMinutes = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Security.Cryptography.ProtectedData

$requestedBaseUrl = $BaseUrl.Trim()
try {
    $baseUri = [Uri]::new($requestedBaseUrl.TrimEnd('/') + '/', [UriKind]::Absolute)
}
catch {
    throw "BaseUrl must be an absolute HTTP(S) URL."
}
if ($baseUri.Scheme -notin @('http', 'https') -or
    -not [string]::IsNullOrEmpty($baseUri.Query) -or
    -not [string]::IsNullOrEmpty($baseUri.Fragment)) {
    throw "BaseUrl must be an absolute HTTP(S) URL without a query or fragment."
}

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$roomIds = [System.Collections.Generic.List[Guid]]::new()
$http = [Net.Http.HttpClient]::new()
$http.Timeout = [TimeSpan]::FromSeconds(45)
$script:explicitHeartbeatRequests = 0
$tokenA = $null
$tokenB = $null
$roomPassword = $null
$chartBytes = $null
$primaryFailure = $null
$cleanupFailures = [System.Collections.Generic.List[string]]::new()
$result = $null

function Resolve-ClientVersion([string]$RequestedVersion) {
    $resolved = ([string]$RequestedVersion).Trim()
    if ([string]::IsNullOrWhiteSpace($resolved)) {
        $projectFile = Join-Path $projectRoot 'LumaChart.App\LumaChart.App.csproj'
        [xml]$projectXml = Get-Content -LiteralPath $projectFile -Raw
        $resolved = [string]($projectXml.Project.PropertyGroup.Version | Select-Object -First 1)
        $resolved = $resolved.Trim()
    }
    if ($resolved -notmatch '^\d+\.\d+\.\d+$') {
        throw "ClientVersion must use a three-part version such as 1.1.0. Actual: '$resolved'."
    }
    return $resolved
}

function Get-ProfileToken([string]$Profile) {
    $path = Join-Path $env:LOCALAPPDATA "LumaChart Studio\Profiles\$Profile\online-session.bin"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Profile session is missing: $Profile"
    }

    $protectedBytes = [IO.File]::ReadAllBytes($path)
    $plainBytes = $null
    try {
        $plainBytes = [Security.Cryptography.ProtectedData]::Unprotect(
            $protectedBytes,
            $null,
            [Security.Cryptography.DataProtectionScope]::CurrentUser)
        return [Text.Encoding]::UTF8.GetString($plainBytes)
    }
    finally {
        if ($protectedBytes.Length -gt 0) {
            [Array]::Clear($protectedBytes, 0, $protectedBytes.Length)
        }
        if ($null -ne $plainBytes -and $plainBytes.Length -gt 0) {
            [Array]::Clear($plainBytes, 0, $plainBytes.Length)
        }
    }
}

function Assert-NoExplicitHeartbeatPath([string]$Path) {
    if ($Path -match '(?i)(?:^|/)heartbeat(?:[/?#]|$)') {
        $script:explicitHeartbeatRequests++
        throw "This gate forbids the explicit room heartbeat endpoint."
    }
}

function Get-JsonCode($Json) {
    if ($null -eq $Json) {
        return ""
    }
    $property = $Json.PSObject.Properties['code']
    if ($null -eq $property -or $null -eq $property.Value) {
        return ""
    }
    return [string]$property.Value
}

function Invoke-Api(
    [string]$Method,
    [string]$Path,
    [string]$Token,
    $Body = $null
) {
    Assert-NoExplicitHeartbeatPath $Path
    $headers = @{ "X-LumaChart-Version" = $clientVersion }
    if (-not [string]::IsNullOrEmpty($Token)) {
        $headers.Authorization = "Bearer $Token"
    }
    $parameters = @{
        Method = $Method
        Uri = [Uri]::new($baseUri, $Path)
        Headers = $headers
        SkipHttpErrorCheck = $true
        TimeoutSec = 45
    }
    if ($null -ne $Body) {
        $parameters.ContentType = "application/json"
        $parameters.Body = $Body | ConvertTo-Json -Depth 30 -Compress
    }

    try {
        $response = Invoke-WebRequest @parameters
    }
    catch {
        throw "$Method $Path transport failed: $($_.Exception.Message)"
    }

    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        try {
            $json = $response.Content | ConvertFrom-Json -Depth 30
        }
        catch {
            $json = $null
        }
    }
    return [pscustomobject]@{
        Status = [int]$response.StatusCode
        Json = $json
        Text = $response.Content
    }
}

function Assert-Status($Response, [int[]]$Expected, [string]$Stage) {
    if ($Expected -notcontains $Response.Status) {
        $code = Get-JsonCode $Response.Json
        if ([string]::IsNullOrEmpty($code)) { $code = "no-code" }
        throw "$Stage returned HTTP $($Response.Status) ($code)."
    }
}

function Invoke-Ok(
    [string]$Method,
    [string]$Path,
    [string]$Token,
    $Body = $null,
    [int[]]$Status = @(200)
) {
    $response = Invoke-Api $Method $Path $Token $Body
    Assert-Status $response $Status "$Method $Path"
    return $response
}

function Invoke-BlobUpload(
    [Guid]$RoomId,
    [string]$Hash,
    [byte[]]$Bytes,
    [string]$Token
) {
    $path = "api/rooms/$RoomId/resources/blobs/$Hash"
    Assert-NoExplicitHeartbeatPath $path
    $request = [Net.Http.HttpRequestMessage]::new(
        [Net.Http.HttpMethod]::Put,
        [Uri]::new($baseUri, $path))
    try {
        $request.Headers.TryAddWithoutValidation("Authorization", "Bearer $Token") | Out-Null
        $request.Headers.TryAddWithoutValidation("X-LumaChart-Version", $clientVersion) | Out-Null
        $request.Content = [Net.Http.ByteArrayContent]::new($Bytes)
        $request.Content.Headers.ContentType =
            [Net.Http.Headers.MediaTypeHeaderValue]::new("application/octet-stream")
        try {
            $response = $http.SendAsync($request).GetAwaiter().GetResult()
        }
        catch {
            throw "Resource blob upload transport failed: $($_.Exception.Message)"
        }
        try {
            if ([int]$response.StatusCode -ne 204) {
                $errorText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                throw "Resource blob upload returned HTTP $([int]$response.StatusCode): $errorText"
            }
        }
        finally {
            $response.Dispose()
        }
    }
    finally {
        $request.Dispose()
    }
}

function New-Beat([int]$Bar, [int]$Numerator = 0, [int]$Denominator = 1) {
    return [ordered]@{
        bar = $Bar
        numerator = $Numerator
        denominator = $Denominator
    }
}

function New-Note([Guid]$Id, [int]$Lane, [int]$Beat) {
    return [ordered]@{
        id = $Id
        lane = $Lane
        beat = (New-Beat $Beat)
        endBeat = $null
        sound = ""
        volume = 100
        group = 0
        isDraft = $false
        draftColumn = 0
        unknownJson = $null
        creatorUserId = 0
    }
}

function New-Timing([Guid]$Id, [int]$Beat, [double]$Bpm) {
    return [ordered]@{
        id = $Id
        beat = (New-Beat $Beat)
        bpm = $Bpm
        delay = 0
        effect = $null
        effectValue = 0
        effectValueText = "0"
        effectFieldName = ""
        unknownJson = $null
        creatorUserId = 0
    }
}

function New-Metadata {
    return [ordered]@{
        title = "Room lease gate"
        titleOriginal = ""
        artist = "LumaChart"
        artistOriginal = ""
        creator = "lease-gate"
        version = "Regression"
        audioFile = ""
        coverFile = ""
        backgroundFile = ""
        previewTime = 0
        overallDifficulty = 5.0
        hpDrainRate = 5.0
    }
}

function Find-OnlyMember($LiveState, [long]$UserId, [string]$Stage) {
    $matches = @($LiveState.members | Where-Object { [long]$_.userId -eq $UserId })
    if ($matches.Count -ne 1) {
        throw "$Stage expected exactly one member row for user $UserId; found $($matches.Count)."
    }
    return $matches[0]
}

function Assert-ActiveRoomState(
    $LiveState,
    [long]$OwnerUserId,
    [long]$MemberUserId,
    [string]$Stage
) {
    if ([int]$LiveState.room.memberCount -ne 2) {
        throw "$Stage expected room.memberCount=2; actual $($LiveState.room.memberCount)."
    }
    $owner = Find-OnlyMember $LiveState $OwnerUserId $Stage
    $member = Find-OnlyMember $LiveState $MemberUserId $Stage
    if ($owner.isOnline -ne $true -or $member.isOnline -ne $true) {
        throw "$Stage expected both users to be online."
    }
}

function Assert-KickedRoomState(
    $LiveState,
    [long]$OwnerUserId,
    [long]$MemberUserId,
    [string]$Stage
) {
    if ([int]$LiveState.room.memberCount -ne 1) {
        throw "$Stage expected room.memberCount=1; actual $($LiveState.room.memberCount)."
    }
    $owner = Find-OnlyMember $LiveState $OwnerUserId $Stage
    $member = Find-OnlyMember $LiveState $MemberUserId $Stage
    if ($owner.isOnline -ne $true) {
        throw "$Stage expected the owner to remain online."
    }
    if ($member.isOnline -ne $false) {
        throw "$Stage expected the kicked historical member to remain offline."
    }
}

function Assert-MemberRequired($Response, [string]$Stage) {
    Assert-Status $Response @(403) $Stage
    $code = Get-JsonCode $Response.Json
    if ($code -cne "member_required") {
        throw "$Stage expected error code 'member_required'; actual '$code'."
    }
}

$clientVersion = Resolve-ClientVersion $ClientVersion

try {
    $tokenA = Get-ProfileToken $ProfileA
    $tokenB = Get-ProfileToken $ProfileB
    $meA = (Invoke-Ok Get "api/me" $tokenA).Json
    $meB = (Invoke-Ok Get "api/me" $tokenB).Json
    if ([long]$meA.id -eq [long]$meB.id) {
        throw "ProfileA and ProfileB resolve to the same account."
    }

    $roomPassword = "lease-$([Guid]::NewGuid().ToString('N'))"
    $roomName = "Lease gate $([DateTimeOffset]::UtcNow.ToString('MMdd-HHmmss'))"
    $created = (Invoke-Ok Post "api/rooms" $tokenA @{
        name = $roomName
        isPrivate = $true
        password = $roomPassword
        isHidden = $true
    } @(201)).Json
    $roomId = [Guid]$created.room.id
    $roomIds.Add($roomId)
    if ([int]$created.room.memberCount -ne 1) {
        throw "New room expected memberCount=1; actual $($created.room.memberCount)."
    }
    if ($created.room.isPrivate -ne $true -or $created.room.isHidden -ne $true) {
        throw "Lease gate room was not created as private and hidden."
    }

    $chartBytes = [Text.Encoding]::UTF8.GetBytes('{"meta":{"mode":0},"time":[],"note":[]}')
    $chartHash = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($chartBytes)).ToLowerInvariant()
    $entries = @(
        [ordered]@{
            path = "working.mc"
            length = $chartBytes.Length
            sha256 = $chartHash
        }
    )
    $plan = (Invoke-Ok Post "api/rooms/$roomId/resources/plan" $tokenA @{
        entries = $entries
    }).Json
    foreach ($missingHash in @($plan.missingSha256)) {
        if ([string]$missingHash -cne $chartHash) {
            throw "Resource plan requested an unexpected hash."
        }
        Invoke-BlobUpload $roomId $chartHash $chartBytes $tokenA
    }
    $manifest = (Invoke-Ok Post "api/rooms/$roomId/resources/commit" $tokenA @{
        entries = $entries
    }).Json
    if (@($manifest.entries).Count -ne 1) {
        throw "Committed room resource manifest is incomplete."
    }

    $initial = [ordered]@{
        keyCount = 4
        notes = @((New-Note ([Guid]::NewGuid()) 0 1))
        timing = @((New-Timing ([Guid]::NewGuid()) 0 120.0))
        metadata = (New-Metadata)
    }
    $snapshot = (Invoke-Ok Put "api/rooms/$roomId/chart" $tokenA $initial).Json
    if ([long]$snapshot.revision -ne 0) {
        throw "Initial chart revision expected zero; actual $($snapshot.revision)."
    }

    $joined = (Invoke-Ok Post "api/rooms/$roomId/join" $tokenB @{
        password = $roomPassword
        memberRole = "editor"
    }).Json
    if ([int]$joined.memberCount -ne 2) {
        throw "Joined room expected memberCount=2; actual $($joined.memberCount)."
    }

    $initialDelta = Invoke-Ok Get "api/rooms/$roomId/chart/delta?after=0" $tokenB
    if ($null -eq $initialDelta.Json) {
        throw "Initial chart delta returned no JSON payload."
    }
    $initialLive = (Invoke-Ok Get "api/rooms/$roomId/live?after=0" $tokenA).Json
    Assert-ActiveRoomState $initialLive ([long]$meA.id) ([long]$meB.id) "initial live state"

    $probeClock = [Diagnostics.Stopwatch]::StartNew()
    $pollCount = 0
    $lastLive = $initialLive
    while ($probeClock.Elapsed.TotalSeconds -lt $ProbeSeconds) {
        $remainingSeconds = $ProbeSeconds - $probeClock.Elapsed.TotalSeconds
        $sleepMilliseconds = [int][Math]::Ceiling(
            [Math]::Min([double]$PollSeconds, $remainingSeconds) * 1000.0)
        if ($sleepMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $sleepMilliseconds
        }

        # Account B proves that chart-delta alone renews a non-owner member.
        $delta = Invoke-Ok Get "api/rooms/$roomId/chart/delta?after=0" $tokenB
        if ($null -eq $delta.Json) {
            throw "Lease poll $($pollCount + 1) returned no chart delta payload."
        }

        # Account A proves that live alone renews the owner and therefore the room.
        $lastLive = (Invoke-Ok Get "api/rooms/$roomId/live?after=0" $tokenA).Json
        $pollCount++
        Assert-ActiveRoomState $lastLive ([long]$meA.id) ([long]$meB.id) "lease poll $pollCount"
    }
    $probeClock.Stop()
    if ($probeClock.Elapsed.TotalSeconds -lt $ProbeSeconds) {
        throw "Lease probe ended before the required $ProbeSeconds seconds."
    }
    if ($script:explicitHeartbeatRequests -ne 0) {
        throw "Lease probe attempted $script:explicitHeartbeatRequests explicit heartbeat requests."
    }

    Invoke-Ok Delete "api/rooms/$roomId/members/$($meB.id)?banMinutes=$BanMinutes" `
        $tokenA $null @(204) | Out-Null

    for ($attempt = 1; $attempt -le 2; $attempt++) {
        $kickedLive = Invoke-Api Get "api/rooms/$roomId/live?after=0" $tokenB
        Assert-MemberRequired $kickedLive "kicked member live attempt $attempt"
        $kickedDelta = Invoke-Api Get "api/rooms/$roomId/chart/delta?after=0" $tokenB
        Assert-MemberRequired $kickedDelta "kicked member delta attempt $attempt"

        $ownerLive = (Invoke-Ok Get "api/rooms/$roomId/live?after=0" $tokenA).Json
        Assert-KickedRoomState $ownerLive ([long]$meA.id) ([long]$meB.id) `
            "post-kick state $attempt"
        if ($attempt -eq 1) {
            Start-Sleep -Seconds 17
        }
    }

    if ($script:explicitHeartbeatRequests -ne 0) {
        throw "Gate attempted $script:explicitHeartbeatRequests explicit heartbeat requests."
    }

    $result = [pscustomobject]@{
        Success = $true
        ClientVersion = $clientVersion
        OwnerUserId = [long]$meA.id
        MemberUserId = [long]$meB.id
        RoomId = $roomId
        ProbeSeconds = $ProbeSeconds
        ElapsedSeconds = [Math]::Round($probeClock.Elapsed.TotalSeconds, 3)
        PollSeconds = $PollSeconds
        PollCount = $pollCount
        RetainedMemberCount = [int]$lastLive.room.memberCount
        PostKickMemberCount = 1
        KickedHistoricalMemberRetained = $true
        KickedLiveRejected = $true
        KickedDeltaRejected = $true
        ExplicitHeartbeatRequests = $script:explicitHeartbeatRequests
        PrivateRoom = $true
        HiddenRoom = $true
    }
}
catch {
    $primaryFailure = $_
}
finally {
    foreach ($trackedRoomId in @($roomIds)) {
        if ([string]::IsNullOrEmpty($tokenA)) {
            $cleanupFailures.Add("Room $trackedRoomId could not be cleaned because ProfileA had no token.")
            continue
        }
        try {
            $cleanup = Invoke-Api Delete "api/rooms/$trackedRoomId" $tokenA
            if ($cleanup.Status -notin @(204, 404)) {
                $cleanupFailures.Add("Room $trackedRoomId cleanup returned HTTP $($cleanup.Status).")
            }
        }
        catch {
            $cleanupFailures.Add("Room $trackedRoomId cleanup failed: $($_.Exception.Message)")
        }
    }

    if ($null -ne $chartBytes -and $chartBytes.Length -gt 0) {
        [Array]::Clear($chartBytes, 0, $chartBytes.Length)
    }
    $http.Dispose()
    $roomPassword = $null
    $tokenA = $null
    $tokenB = $null
}

if ($null -ne $primaryFailure) {
    if ($cleanupFailures.Count -gt 0) {
        throw "$($primaryFailure.Exception.Message) Cleanup also failed: $($cleanupFailures -join ' ')"
    }
    throw $primaryFailure
}
if ($cleanupFailures.Count -gt 0) {
    throw "Lease gate passed but cleanup failed: $($cleanupFailures -join ' ')"
}
if ($null -eq $result) {
    throw "Lease gate completed without a result."
}

$result | ConvertTo-Json -Compress
