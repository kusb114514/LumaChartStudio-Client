param(
    [string]$BaseUrl = "https://api.lumachart.cc/",
    [string]$ProfileA = "Test-Client-A",
    [string]$ProfileB = "Test-Client-B",
    [string]$ClientVersion = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Security.Cryptography.ProtectedData

$baseUri = [Uri]::new($BaseUrl)
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Resolve-ClientVersion([string]$RequestedVersion) {
    $resolved = ([string]$RequestedVersion).Trim()
    if ([string]::IsNullOrWhiteSpace($resolved)) {
        $projectFile = Join-Path $projectRoot 'LumaChart.App\LumaChart.App.csproj'
        [xml]$projectXml = Get-Content -LiteralPath $projectFile
        $resolved = [string]($projectXml.Project.PropertyGroup.Version | Select-Object -First 1)
        $resolved = $resolved.Trim()
    }
    if ($resolved -notmatch '^\d+\.\d+\.\d+$') {
        throw "ClientVersion must use a three-part version such as 1.1.0. Actual: '$resolved'."
    }
    return $resolved
}

$clientVersion = Resolve-ClientVersion $ClientVersion
$roomIds = [System.Collections.Generic.List[Guid]]::new()
$http = [Net.Http.HttpClient]::new()
$http.Timeout = [TimeSpan]::FromSeconds(45)

function Get-ProfileToken([string]$profile) {
    $path = Join-Path $env:LOCALAPPDATA "LumaChart Studio\Profiles\$profile\online-session.bin"
    if (-not (Test-Path -LiteralPath $path)) { throw "Profile session is missing: $profile" }
    $plain = [Security.Cryptography.ProtectedData]::Unprotect(
        [IO.File]::ReadAllBytes($path), $null,
        [Security.Cryptography.DataProtectionScope]::CurrentUser)
    try { [Text.Encoding]::UTF8.GetString($plain) }
    finally { [Array]::Clear($plain, 0, $plain.Length) }
}

function Invoke-Api(
    [string]$method,
    [string]$path,
    [string]$token,
    $body = $null
) {
    $headers = @{ "X-LumaChart-Version" = $clientVersion }
    if ($token) { $headers.Authorization = "Bearer $token" }
    $parameters = @{
        Method = $method
        Uri = [Uri]::new($baseUri, $path)
        Headers = $headers
        SkipHttpErrorCheck = $true
    }
    if ($null -ne $body) {
        $parameters.ContentType = "application/json"
        $parameters.Body = $body | ConvertTo-Json -Depth 30 -Compress
    }
    $response = Invoke-WebRequest @parameters
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        try { $json = $response.Content | ConvertFrom-Json -Depth 30 }
        catch { }
    }
    [pscustomobject]@{
        Status = [int]$response.StatusCode
        Json = $json
        Text = $response.Content
    }
}

function Assert-Status($response, [int[]]$expected, [string]$stage) {
    if ($expected -notcontains $response.Status) {
        $code = if ($response.Json -and $response.Json.code) { $response.Json.code } else { "no-code" }
        throw "$stage returned HTTP $($response.Status) ($code)."
    }
}

function Invoke-Ok([string]$method, [string]$path, [string]$token, $body = $null, [int[]]$status = @(200)) {
    $response = Invoke-Api $method $path $token $body
    Assert-Status $response $status "$method $path"
    $response
}

function New-Beat([int]$bar, [int]$numerator = 0, [int]$denominator = 1) {
    [ordered]@{ bar = $bar; numerator = $numerator; denominator = $denominator }
}

function New-Note([Guid]$id, [int]$lane, [int]$beat, $endBeat = $null, [string]$sound = "") {
    [ordered]@{
        id = $id; lane = $lane; beat = (New-Beat $beat); endBeat = $endBeat
        sound = $sound; volume = 100; group = 0; isDraft = $false
        draftColumn = 0; unknownJson = $null; creatorUserId = 0
    }
}

function New-Timing(
    [Guid]$id, [int]$beat, $bpm, $effect,
    [double]$value = 0, [string]$valueText = "0", [string]$field = ""
) {
    [ordered]@{
        id = $id; beat = (New-Beat $beat); bpm = $bpm; delay = 0
        effect = $effect; effectValue = $value; effectValueText = $valueText
        effectFieldName = $field; unknownJson = $null; creatorUserId = 0
    }
}

function New-Metadata([string]$title, [string]$artist) {
    [ordered]@{
        title = $title; titleOriginal = ""; artist = $artist; artistOriginal = ""
        creator = "A-B Audit"; version = "Regression"; audioFile = "audio/test.bin"
        coverFile = ""; backgroundFile = ""; previewTime = 0
        overallDifficulty = 5.0; hpDrainRate = 5.0
    }
}

function New-Batch(
    [long]$revision,
    [Guid]$operationId,
    $notes = @(),
    $deleteNotes = @(),
    $timing = @(),
    $deleteTiming = @(),
    $metadata = $null,
    $keyCount = $null
) {
    [ordered]@{
        baseRevision = $revision; upsertNotes = @($notes); deleteNoteIds = @($deleteNotes)
        upsertTiming = @($timing); deleteTimingIds = @($deleteTiming)
        operationId = $operationId; metadata = $metadata; keyCount = $keyCount
    }
}

function New-JsonRequest([string]$method, [string]$path, [string]$token, $body) {
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new($method), [Uri]::new($baseUri, $path))
    $request.Headers.TryAddWithoutValidation("Authorization", "Bearer $token") | Out-Null
    $request.Headers.TryAddWithoutValidation("X-LumaChart-Version", $clientVersion) | Out-Null
    $json = $body | ConvertTo-Json -Depth 30 -Compress
    $request.Content = [Net.Http.StringContent]::new($json, [Text.Encoding]::UTF8, "application/json")
    $request
}

function Read-HttpResult([Net.Http.HttpResponseMessage]$response) {
    $text = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    $json = if ([string]::IsNullOrWhiteSpace($text)) { $null } else { $text | ConvertFrom-Json -Depth 30 }
    [pscustomobject]@{ Status = [int]$response.StatusCode; Json = $json; Text = $text }
}

function Read-SseRevision([IO.StreamReader]$reader, [int]$timeoutMilliseconds = 15000) {
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($timeoutMilliseconds)
    [long]$parsed = 0
    while ([DateTimeOffset]::UtcNow -lt $deadline) {
        $task = $reader.ReadLineAsync()
        $remaining = [Math]::Max(1, [int]($deadline - [DateTimeOffset]::UtcNow).TotalMilliseconds)
        if (-not $task.Wait($remaining)) { break }
        $line = $task.Result
        if ($null -eq $line) { break }
        if ($line.StartsWith("data: ") -and [long]::TryParse($line.Substring(6), [ref]$parsed)) { return $parsed }
    }
    throw "Timed out waiting for an SSE revision."
}

$tokenA = Get-ProfileToken $ProfileA
$tokenB = Get-ProfileToken $ProfileB
$resourceBytes = [Security.Cryptography.RandomNumberGenerator]::GetBytes(2 * 1024 * 1024)
$resourceHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($resourceBytes)).ToLowerInvariant()
$chartBytes = [Text.Encoding]::UTF8.GetBytes('{"meta":{"mode":0},"time":[],"note":[]}')
$chartHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($chartBytes)).ToLowerInvariant()

try {
    $meA = (Invoke-Ok Get "api/me" $tokenA).Json
    $meB = (Invoke-Ok Get "api/me" $tokenB).Json
    if ($meA.id -eq $meB.id) { throw "Client-A and Client-B resolve to the same account." }

    $created = (Invoke-Ok Post "api/rooms" $tokenA @{
        name = "A-B final audit"; isPrivate = $false; password = $null; isHidden = $true
    } @(201)).Json
    $roomId = [Guid]$created.room.id
    $roomIds.Add($roomId)

    $entries = @(
        [ordered]@{ path = "working.mc"; length = $chartBytes.Length; sha256 = $chartHash },
        [ordered]@{ path = "copy/working-copy.mc"; length = $chartBytes.Length; sha256 = $chartHash },
        [ordered]@{ path = "audio/test.bin"; length = $resourceBytes.Length; sha256 = $resourceHash }
    )
    $plan = (Invoke-Ok Post "api/rooms/$roomId/resources/plan" $tokenA @{ entries = $entries }).Json
    foreach ($hash in $plan.missingSha256) {
        $bytes = if ([string]$hash -eq $chartHash) { $chartBytes } else { $resourceBytes }
        $uploadRequest = [Net.Http.HttpRequestMessage]::new(
            [Net.Http.HttpMethod]::Put,
            [Uri]::new($baseUri, "api/rooms/$roomId/resources/blobs/$hash"))
        $uploadRequest.Headers.TryAddWithoutValidation("Authorization", "Bearer $tokenA") | Out-Null
        $uploadRequest.Headers.TryAddWithoutValidation("X-LumaChart-Version", $clientVersion) | Out-Null
        $uploadRequest.Content = [Net.Http.ByteArrayContent]::new($bytes)
        $uploadRequest.Content.Headers.ContentType = [Net.Http.Headers.MediaTypeHeaderValue]::new("application/octet-stream")
        $upload = $http.SendAsync($uploadRequest).GetAwaiter().GetResult()
        if ([int]$upload.StatusCode -ne 204) {
            $uploadError = $upload.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            throw "Resource blob upload failed with HTTP $([int]$upload.StatusCode): $uploadError"
        }
        $upload.Dispose()
        $uploadRequest.Dispose()
    }
    $manifest = (Invoke-Ok Post "api/rooms/$roomId/resources/commit" $tokenA @{ entries = $entries }).Json
    if ($manifest.entries.Count -ne 3) { throw "Committed resource manifest is incomplete." }

    $tapId = [Guid]::NewGuid()
    $holdId = [Guid]::NewGuid()
    $bpmId = [Guid]::NewGuid()
    $effectId = [Guid]::NewGuid()
    $signId = [Guid]::NewGuid()
    $customId = [Guid]::NewGuid()
    $metadata = New-Metadata "Audit start" "Artist start"
    $initial = [ordered]@{
        keyCount = 4
        notes = @(
            (New-Note $tapId 0 1 $null "audio/test.bin"),
            (New-Note $holdId 1 5 (New-Beat 7))
        )
        timing = @(
            (New-Timing $bpmId 0 120.0 $null 0 "0"),
            (New-Timing $effectId 1 $null 0 1 "1"),
            (New-Timing $signId 5 $null 3 -1 "-1"),
            (New-Timing $customId 6 $null 4 0.5 "0.5" "luma.audit")
        )
        metadata = $metadata
    }
    $snapshot = (Invoke-Ok Put "api/rooms/$roomId/chart" $tokenA $initial).Json
    if ($snapshot.revision -ne 0) { throw "Initial chart revision is not zero." }
    $lateInitialization = [ordered]@{
        keyCount = 8
        notes = @()
        timing = @()
        metadata = (New-Metadata "Late initialize must be ignored" "Late actor")
    }
    $duplicateInitialize = (Invoke-Ok Put "api/rooms/$roomId/chart" $tokenA $lateInitialization).Json
    if ($duplicateInitialize.revision -ne 0 -or $duplicateInitialize.keyCount -ne 4 -or
        $duplicateInitialize.notes.Count -ne 2 -or $duplicateInitialize.timing.Count -ne 4 -or
        $duplicateInitialize.metadata.title -ne $metadata.title) {
        throw "A duplicate or late chart initialization replaced the authoritative room state."
    }

    Invoke-Ok Post "api/rooms/$roomId/join" $tokenB @{ password = $null; memberRole = "editor" } | Out-Null
    Invoke-Ok Put "api/rooms/$roomId/members/$($meB.id)/access" $tokenA @{
        memberRole = "viewer"; canEditMetadata = $true; canEditTiming = $true; canEditNotes = $true
    } @(204) | Out-Null
    $viewerAttempt = Invoke-Api Post "api/rooms/$roomId/chart/operations" $tokenB `
        (New-Batch 0 ([Guid]::NewGuid()) @((New-Note ([Guid]::NewGuid()) 2 8)))
    Assert-Status $viewerAttempt @(403) "viewer write rejection"

    Invoke-Ok Put "api/rooms/$roomId/members/$($meB.id)/access" $tokenA @{
        memberRole = "editor"; canEditMetadata = $false; canEditTiming = $false; canEditNotes = $true
    } @(204) | Out-Null
    $bNoteId = [Guid]::NewGuid()
    $noteResult = (Invoke-Ok Post "api/rooms/$roomId/chart/operations" $tokenB `
        (New-Batch 0 ([Guid]::NewGuid()) @((New-Note $bNoteId 2 8)))).Json
    $revision = [long]$noteResult.snapshot.revision
    $timingDenied = Invoke-Api Post "api/rooms/$roomId/chart/operations" $tokenB `
        (New-Batch $revision ([Guid]::NewGuid()) @() @() @((New-Timing ([Guid]::NewGuid()) 9 $null 2 1 "1")))
    Assert-Status $timingDenied @(403) "timing permission rejection"
    $metadataDenied = Invoke-Api Post "api/rooms/$roomId/chart/operations" $tokenB `
        (New-Batch $revision ([Guid]::NewGuid()) @() @() @() @() (New-Metadata "Denied" "Artist start"))
    Assert-Status $metadataDenied @(403) "metadata permission rejection"

    Invoke-Ok Put "api/rooms/$roomId/members/$($meB.id)/access" $tokenA @{
        memberRole = "editor"; canEditMetadata = $true; canEditTiming = $true; canEditNotes = $true
    } @(204) | Out-Null

    $base = [long](Invoke-Ok Get "api/rooms/$roomId/chart" $tokenA).Json.revision
    $extend = New-Batch $base ([Guid]::NewGuid()) @((New-Note $holdId 1 5 (New-Beat 9)))
    $signUpdate = New-Batch $base ([Guid]::NewGuid()) @() @() @((New-Timing $signId 5 $null 3 -2 "-2"))
    $requestA = New-JsonRequest Post "api/rooms/$roomId/chart/operations" $tokenA $extend
    $requestB = New-JsonRequest Post "api/rooms/$roomId/chart/operations" $tokenB $signUpdate
    $taskA = $http.SendAsync($requestA)
    $taskB = $http.SendAsync($requestB)
    [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($taskA, $taskB))
    $resultA = Read-HttpResult $taskA.Result
    $resultB = Read-HttpResult $taskB.Result
    Assert-Status $resultA @(200) "concurrent Client-A LN extension"
    Assert-Status $resultB @(200) "concurrent Client-B Sign update"
    $taskA.Result.Dispose(); $taskB.Result.Dispose(); $requestA.Dispose(); $requestB.Dispose()

    $afterConcurrent = (Invoke-Ok Get "api/rooms/$roomId/chart" $tokenA).Json
    if ([long]$afterConcurrent.revision -ne $base + 2) { throw "Concurrent operations did not produce exactly two revisions." }
    $metadataBase = $afterConcurrent.metadata
    $metaRevision = [long]$afterConcurrent.revision
    $titleMetadata = New-Metadata "Title from A" $metadataBase.artist
    $artistMetadata = New-Metadata $metadataBase.title "Artist from B"
    Invoke-Ok Post "api/rooms/$roomId/chart/operations" $tokenA `
        (New-Batch $metaRevision ([Guid]::NewGuid()) @() @() @() @() $titleMetadata) | Out-Null
    Invoke-Ok Post "api/rooms/$roomId/chart/operations" $tokenB `
        (New-Batch $metaRevision ([Guid]::NewGuid()) @() @() @() @() $artistMetadata 6) | Out-Null
    $metadataMerged = (Invoke-Ok Get "api/rooms/$roomId/chart" $tokenB).Json
    if ($metadataMerged.metadata.title -ne "Title from A" -or
        $metadataMerged.metadata.artist -ne "Artist from B" -or $metadataMerged.keyCount -ne 6) {
        throw "Stale metadata field merge or KeyCount synchronization failed."
    }

    $revision = [long]$metadataMerged.revision
    Invoke-Ok Post "api/rooms/$roomId/chart/operations" $tokenA `
        (New-Batch $revision ([Guid]::NewGuid()) @((New-Note $holdId 1 5 (New-Beat 8)))) | Out-Null
    $revision = [long](Invoke-Ok Get "api/rooms/$roomId/chart" $tokenA).Json.revision
    $retryId = [Guid]::NewGuid()
    $retryNoteId = [Guid]::NewGuid()
    $retryBatch = New-Batch $revision $retryId @((New-Note $retryNoteId 3 11))
    $lostResponseRequest = New-JsonRequest Post "api/rooms/$roomId/chart/operations" $tokenB $retryBatch
    $lostResponse = $http.SendAsync($lostResponseRequest).GetAwaiter().GetResult()
    $lostResponse.Dispose(); $lostResponseRequest.Dispose()
    Start-Sleep -Seconds 5
    $retried = (Invoke-Ok Post "api/rooms/$roomId/chart/operations" $tokenB $retryBatch).Json
    if ([long]$retried.snapshot.revision -ne $revision + 1) { throw "Idempotent retry incremented revision more than once." }
    $changedReuse = Invoke-Api Post "api/rooms/$roomId/chart/operations" $tokenB `
        (New-Batch $revision $retryId @((New-Note $retryNoteId 3 12)))
    Assert-Status $changedReuse @(400) "OperationId immutable payload enforcement"

    Invoke-Ok Post "api/rooms/$roomId/chart/locks/toggle" $tokenA @{
        startBeat = (New-Beat 0); endBeat = (New-Beat 4)
    } | Out-Null
    $lockedRevision = [long](Invoke-Ok Get "api/rooms/$roomId/chart" $tokenA).Json.revision
    $lockedNote = Invoke-Api Post "api/rooms/$roomId/chart/operations" $tokenB `
        (New-Batch $lockedRevision ([Guid]::NewGuid()) @((New-Note $tapId 0 2 $null "audio/test.bin")))
    Assert-Status $lockedNote @(403) "server Note lock enforcement"
    $lockedEffect = Invoke-Api Post "api/rooms/$roomId/chart/operations" $tokenB `
        (New-Batch $lockedRevision ([Guid]::NewGuid()) @() @() @((New-Timing $effectId 1 $null 0 2 "2")))
    Assert-Status $lockedEffect @(403) "server Effect lock enforcement"
    Invoke-Ok Post "api/rooms/$roomId/chart/locks/toggle" $tokenA @{
        startBeat = (New-Beat 0); endBeat = (New-Beat 4)
    } | Out-Null

    $sseRequest = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get,
        [Uri]::new($baseUri, "api/rooms/$roomId/chart/events"))
    $sseRequest.Headers.TryAddWithoutValidation("Authorization", "Bearer $tokenB") | Out-Null
    $sseRequest.Headers.TryAddWithoutValidation("X-LumaChart-Version", $clientVersion) | Out-Null
    $sseResponse = $http.SendAsync($sseRequest, [Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    if (-not $sseResponse.IsSuccessStatusCode) { throw "SSE connection failed." }
    $sseStream = $sseResponse.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
    $sseReader = [IO.StreamReader]::new($sseStream)
    $sseInitial = Read-SseRevision $sseReader
    $sseBatch = New-Batch $sseInitial ([Guid]::NewGuid()) @() @() @(
        (New-Timing $customId 10 $null 4 0.75 "0.75" "luma.audit")
    )
    $sseApplied = (Invoke-Ok Post "api/rooms/$roomId/chart/operations" $tokenB $sseBatch).Json
    $sseExpected = [long]$sseApplied.snapshot.revision
    $sseObserved = Read-SseRevision $sseReader
    if ($sseObserved -lt $sseExpected) { throw "SSE did not publish the applied revision." }
    $sseReader.Dispose(); $sseResponse.Dispose(); $sseRequest.Dispose()

    $downloadRequest = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get,
        [Uri]::new($baseUri, "api/rooms/$roomId/resources/files/$resourceHash"))
    $downloadRequest.Headers.TryAddWithoutValidation("Authorization", "Bearer $tokenB") | Out-Null
    $downloadResponse = $http.SendAsync($downloadRequest, [Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    if (-not $downloadResponse.IsSuccessStatusCode) { throw "Room resource download failed." }
    $downloadStream = $downloadResponse.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
    $downloadHash = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
    $buffer = [byte[]]::new(32768)
    $firstRead = $downloadStream.Read($buffer, 0, $buffer.Length)
    $downloadHash.AppendData($buffer, 0, $firstRead)
    $duringDownloadRevision = [long](Invoke-Ok Get "api/rooms/$roomId/chart" $tokenA).Json.revision
    Invoke-Ok Post "api/rooms/$roomId/chart/operations" $tokenA `
        (New-Batch $duringDownloadRevision ([Guid]::NewGuid()) @((New-Note ([Guid]::NewGuid()) 4 13))) | Out-Null
    while (($read = $downloadStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $downloadHash.AppendData($buffer, 0, $read)
        Start-Sleep -Milliseconds 2
    }
    $actualDownloadHash = [Convert]::ToHexString($downloadHash.GetHashAndReset()).ToLowerInvariant()
    $downloadHash.Dispose(); $downloadStream.Dispose(); $downloadResponse.Dispose(); $downloadRequest.Dispose()
    if ($actualDownloadHash -ne $resourceHash) { throw "Resource hash changed during concurrent chart editing." }

    Invoke-Ok Post "api/rooms/$roomId/chat" $tokenB @{ message = "A/B weak-network audit ok" } @(201) | Out-Null
    $invalidChat = Invoke-Api Post "api/rooms/$roomId/chat" $tokenB @{ message = "hidden$([char]0x202E)text" }
    Assert-Status $invalidChat @(400) "hidden-control chat rejection"
    $foreignRoom = [Guid]::NewGuid()
    Assert-Status (Invoke-Api Get "api/rooms/$foreignRoom/chart" $tokenB) @(403) "cross-room chart access"
    Invoke-Ok Delete "api/rooms/$roomId" $tokenB $null @(204) | Out-Null
    Invoke-Ok Get "api/rooms/$roomId/chart" $tokenA | Out-Null
    Invoke-Ok Post "api/rooms/$roomId/join" $tokenB @{ password = $null; memberRole = "editor" } | Out-Null

    $beforeSnapshot = (Invoke-Ok Get "api/rooms/$roomId/chart" $tokenA).Json
    $saved = (Invoke-Ok Post "api/rooms/$roomId/chart/snapshots" $tokenA @{ name = "A-B rollback audit" } @(201)).Json
    $beforeRollbackRevision = [long]$beforeSnapshot.revision
    Invoke-Ok Post "api/rooms/$roomId/chart/operations" $tokenA `
        (New-Batch $beforeRollbackRevision ([Guid]::NewGuid()) @((New-Note ([Guid]::NewGuid()) 5 14))) | Out-Null
    $rollbackOperationId = [Guid]::NewGuid()
    $rollbackRequest = @{ operationId = $rollbackOperationId }
    $rollback = (Invoke-Ok Post "api/rooms/$roomId/chart/snapshots/$($saved.id)/rollback" $tokenA $rollbackRequest).Json
    $rollbackRetry = (Invoke-Ok Post "api/rooms/$roomId/chart/snapshots/$($saved.id)/rollback" $tokenA $rollbackRequest).Json
    if ($rollbackRetry.snapshot.revision -ne $rollback.snapshot.revision -or
        $rollbackRetry.safetySnapshotId -ne $rollback.safetySnapshotId) {
        throw "A repeated rollback OperationId created a second revision or safety snapshot."
    }
    $rollbackRevision = [long]$rollback.snapshot.revision
    $rollbackDelta = (Invoke-Ok Get "api/rooms/$roomId/chart/delta?after=$beforeRollbackRevision" $tokenB).Json
    $rollbackRequiresFullSnapshot = $rollbackDelta.requiresFullSnapshot -eq $true -and
        [long]$rollbackDelta.currentRevision -eq $rollbackRevision -and
        [long]$rollbackDelta.authoritativeBaselineRevision -eq $rollbackRevision
    $rollbackCarriesBaselineOperation = [long]$rollbackDelta.authoritativeBaselineRevision -eq $rollbackRevision -and
        ($rollbackDelta.operations | Where-Object { [long]$_.revision -eq $rollbackRevision })
    if (-not $rollbackRequiresFullSnapshot -and -not $rollbackCarriesBaselineOperation) {
        throw "Member delta did not carry a provable authoritative rollback baseline."
    }
    $lateCommittedRetry = (Invoke-Ok Post "api/rooms/$roomId/chart/operations" $tokenB $retryBatch).Json
    $lateRetryOperationId = if ($null -ne $lateCommittedRetry.appliedOperation) {
        [Guid]$lateCommittedRetry.appliedOperation.batch.operationId
    } else {
        [Guid]::Empty
    }
    if ([long]$lateCommittedRetry.snapshot.revision -ne $rollbackRevision -or
        ($lateRetryOperationId -ne [Guid]::Empty -and $lateRetryOperationId -ne $retryId)) {
        throw "An exact committed OperationId retry was rejected or replayed after rollback advanced the baseline."
    }
    $staleAfterRollback = Invoke-Api Post "api/rooms/$roomId/chart/operations" $tokenB `
        (New-Batch $beforeRollbackRevision ([Guid]::NewGuid()) @((New-Note ([Guid]::NewGuid()) 0 15)))
    Assert-Status $staleAfterRollback @(409) "post-rollback stale operation barrier"
    if ($staleAfterRollback.Json.code -ne "chart_baseline_changed") {
        throw "Post-rollback stale operation did not return the authoritative baseline recovery code."
    }

    $finalA = (Invoke-Ok Get "api/rooms/$roomId/chart" $tokenA).Json
    $finalB = (Invoke-Ok Get "api/rooms/$roomId/chart" $tokenB).Json
    $jsonA = $finalA | ConvertTo-Json -Depth 30 -Compress
    $jsonB = $finalB | ConvertTo-Json -Depth 30 -Compress
    $hashA = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($jsonA)))
    $hashB = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($jsonB)))
    if ($hashA -ne $hashB -or $finalA.revision -ne $finalB.revision -or
        $finalA.notes.Count -ne $finalB.notes.Count -or $finalA.timing.Count -ne $finalB.timing.Count -or
        $finalA.keyCount -ne $finalB.keyCount -or $finalA.metadata.title -ne $finalB.metadata.title) {
        throw "Client-A and Client-B final chart snapshots differ."
    }

    Invoke-Ok Put "api/rooms/$roomId/members/$($meB.id)/access" $tokenA @{
        memberRole = "viewer"; canEditMetadata = $true; canEditTiming = $true; canEditNotes = $true
    } @(204) | Out-Null
    $live = (Invoke-Ok Get "api/rooms/$roomId/live" $tokenA).Json
    $viewer = $live.members | Where-Object userId -eq $meB.id
    if ($viewer.memberRole -ne "viewer" -or -not $viewer.canEditMetadata -or
        -not $viewer.canEditTiming -or -not $viewer.canEditNotes) {
        throw "Viewer role discarded the member's saved granular permissions."
    }
    $viewerAttempt = Invoke-Api Post "api/rooms/$roomId/chart/operations" $tokenB `
        (New-Batch ([long]$finalA.revision) ([Guid]::NewGuid()) @((New-Note ([Guid]::NewGuid()) 0 16)))
    Assert-Status $viewerAttempt @(403) "viewer effective read-only guard"
    if ($viewerAttempt.Json.code -ne "viewer_read_only") {
        throw "Viewer chart write was not rejected by the role-level read-only guard."
    }
    Invoke-Ok Put "api/rooms/$roomId/members/$($meB.id)/access" $tokenA @{
        memberRole = "editor"; canEditMetadata = $viewer.canEditMetadata
        canEditTiming = $viewer.canEditTiming; canEditNotes = $viewer.canEditNotes
    } @(204) | Out-Null
    $restoredLive = (Invoke-Ok Get "api/rooms/$roomId/live" $tokenA).Json
    $restoredEditor = $restoredLive.members | Where-Object userId -eq $meB.id
    if ($restoredEditor.memberRole -ne "editor" -or -not $restoredEditor.canEditMetadata -or
        -not $restoredEditor.canEditTiming -or -not $restoredEditor.canEditNotes) {
        throw "Returning a viewer to editor did not restore the saved granular permissions."
    }
    Invoke-Ok Delete "api/rooms/$roomId/members/$($meB.id)?banMinutes=1" $tokenA $null @(204) | Out-Null
    Assert-Status (Invoke-Api Get "api/rooms/$roomId/live" $tokenB) @(403) "kicked member live access"
    Assert-Status (Invoke-Api Post "api/rooms/$roomId/join" $tokenB @{ password = $null; memberRole = "editor" }) @(403) "temporary room ban"
    Invoke-Ok Delete "api/rooms/$roomId" $tokenA $null @(204) | Out-Null
    $roomIds.Remove($roomId) | Out-Null

    $rebuilt = (Invoke-Ok Post "api/rooms" $tokenA @{
        name = "A-B rebuilt room"; isPrivate = $false; password = $null; isHidden = $true
    } @(201)).Json
    $rebuiltId = [Guid]$rebuilt.room.id
    $roomIds.Add($rebuiltId)
    $replan = (Invoke-Ok Post "api/rooms/$rebuiltId/resources/plan" $tokenA @{ entries = $entries }).Json
    if ($replan.missingBytes -ne 0) { throw "24-hour resource cache did not deduplicate the rebuilt room." }
    Invoke-Ok Post "api/rooms/$rebuiltId/resources/commit" $tokenA @{ entries = $entries } | Out-Null
    Invoke-Ok Post "api/rooms/$rebuiltId/join" $tokenB @{ password = $null; memberRole = "editor" } | Out-Null
    Invoke-Ok Delete "api/rooms/$rebuiltId" $tokenA $null @(204) | Out-Null
    $roomIds.Remove($rebuiltId) | Out-Null

    [pscustomobject]@{
        Success = $true
        ClientVersion = $clientVersion
        ClientAUserId = $meA.id
        ClientBUserId = $meB.id
        FinalRevision = [long]$finalA.revision
        NoteCount = $finalA.notes.Count
        TimingCount = $finalA.timing.Count
        KeyCount = $finalA.keyCount
        SnapshotHash = $hashA
        SseRevision = $sseObserved
        ResourceHashVerified = $true
        DuplicateBlobPathsVerified = $true
        DuplicateInitializePreserved = $true
        RollbackIdempotencyVerified = $true
        RollbackDeltaBaselineVerified = $true
        LateCommittedRetryVerified = $true
        RollbackSafetySnapshotId = $rollback.safetySnapshotId
    } | ConvertTo-Json -Compress
}
finally {
    foreach ($roomId in @($roomIds)) {
        try { Invoke-Api Delete "api/rooms/$roomId" $tokenA | Out-Null } catch { }
    }
    if ($resourceBytes) { [Array]::Clear($resourceBytes, 0, $resourceBytes.Length) }
    $http.Dispose()
    $tokenA = $null
    $tokenB = $null
}
