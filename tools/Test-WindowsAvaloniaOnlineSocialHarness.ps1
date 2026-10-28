param(
    [string]$ServerAssemblyPath = (
        Join-Path $PSScriptRoot (
            "WindowsAvaloniaOnlineGuiServer\bin\Release\net8.0\" +
            "WindowsAvaloniaOnlineGuiServer.dll")),
    [Parameter(Mandatory = $true)]
    [string]$OutputRoot,
    [ValidateRange(10, 60)]
    [int]$TimeoutSeconds = 20
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "The Windows Avalonia social harness smoke requires PowerShell Core on Windows."
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Wait-File([string]$Path, [string]$Description) {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTimeOffset]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) { return }
        Start-Sleep -Milliseconds 100
    }
    throw "Timed out waiting for $Description."
}

$serverAssembly = [IO.Path]::GetFullPath($ServerAssemblyPath)
Assert (Test-Path -LiteralPath $serverAssembly -PathType Leaf) (
    "Server assembly not found: $serverAssembly")
$output = [IO.Path]::GetFullPath($OutputRoot)
Assert (-not (Test-Path -LiteralPath $output)) (
    "Output root already exists: $output")
New-Item -ItemType Directory -Path $output | Out-Null

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$projectTemp = Join-Path $projectRoot ".codex-temp"
$dotnetHome = Join-Path $projectRoot ".codex-dotnet-home"
$nugetPackages = Join-Path $projectRoot ".codex-nuget-packages"
$nugetHttpCache = Join-Path $projectRoot ".codex-nuget-http-cache"
foreach ($directory in @(
        $projectTemp,
        $dotnetHome,
        $nugetPackages,
        $nugetHttpCache)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$readyPath = Join-Path $output "ready.json"
$statePath = Join-Path $output "server-state.json"
$evidencePath = Join-Path $output "evidence.json"
$server = $null
try {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "dotnet"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.WorkingDirectory = Split-Path -Parent $serverAssembly
    foreach ($argument in @(
            $serverAssembly,
            "--ready-file", $readyPath,
            "--state-file", $statePath,
            "--listen-url", "http://127.0.0.1:0")) {
        $start.ArgumentList.Add($argument)
    }
    $start.Environment["DOTNET_CLI_HOME"] = $dotnetHome
    $start.Environment["NUGET_PACKAGES"] = $nugetPackages
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
    $start.Environment["TEMP"] = $projectTemp
    $start.Environment["TMP"] = $projectTemp
    $server = [Diagnostics.Process]::Start($start)
    Assert ($null -ne $server) "Failed to start the isolated loopback GUI Server."
    Wait-File $readyPath "loopback GUI Server readiness"

    $ready = Get-Content -LiteralPath $readyPath -Raw | ConvertFrom-Json
    $ownerHeaders = @{ Authorization = "Bearer $($ready.ownerToken)" }
    $memberHeaders = @{ Authorization = "Bearer $($ready.memberToken)" }
    $endpoint = [string]$ready.endpoint

    $initialPlayers = Invoke-RestMethod -Uri ($endpoint + "api/players?page=1") `
        -Headers $ownerHeaders
    $initialSearch = Invoke-RestMethod -Uri (
        $endpoint + "api/players/search?page=1&q=%E6%88%90%E5%91%98") `
        -Headers $ownerHeaders
    $initialLeaderboard = Invoke-RestMethod -Uri (
        $endpoint + "api/players/leaderboard?limit=50") `
        -Headers $ownerHeaders
    $initialFriends = Invoke-RestMethod -Uri ($endpoint + "api/me/friends") `
        -Headers $ownerHeaders
    $initialFollowing = Invoke-RestMethod -Uri (
        $endpoint + "api/me/following?page=1") -Headers $ownerHeaders
    $initialFollowers = Invoke-RestMethod -Uri (
        $endpoint + "api/me/followers?page=1") -Headers $ownerHeaders
    $initialMember = Invoke-RestMethod -Uri ($endpoint + "api/players/4202") `
        -Headers $ownerHeaders

    $unfollow = Invoke-RestMethod -Method Delete -Uri (
        $endpoint + "api/players/4202/follow") -Headers $ownerHeaders
    $unfollowIdempotent = Invoke-RestMethod -Method Delete -Uri (
        $endpoint + "api/players/4202/follow") -Headers $ownerHeaders
    $friendsAfterDelete = Invoke-RestMethod -Uri ($endpoint + "api/me/friends") `
        -Headers $ownerHeaders
    $followingAfterDelete = Invoke-RestMethod -Uri (
        $endpoint + "api/me/following?page=1") -Headers $ownerHeaders
    $memberAfterDelete = Invoke-RestMethod -Uri ($endpoint + "api/players/4202") `
        -Headers $ownerHeaders

    $refollow = Invoke-RestMethod -Method Put -Uri (
        $endpoint + "api/players/4202/follow") -Headers $ownerHeaders
    $refollowIdempotent = Invoke-RestMethod -Method Put -Uri (
        $endpoint + "api/players/4202/follow") -Headers $ownerHeaders
    $friendsAfterPut = Invoke-RestMethod -Uri ($endpoint + "api/me/friends") `
        -Headers $ownerHeaders
    $memberAfterPut = Invoke-RestMethod -Uri ($endpoint + "api/players/4202") `
        -Headers $ownerHeaders
    $memberNotifications = Invoke-RestMethod -Uri (
        $endpoint + "api/me/notifications?after=0&limit=50") `
        -Headers $memberHeaders
    $selfFollow = Invoke-WebRequest -Method Put -Uri (
        $endpoint + "api/players/4101/follow") -Headers $ownerHeaders `
        -SkipHttpErrorCheck

    Wait-File $statePath "social harness state"
    Start-Sleep -Milliseconds 200
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $followNotifications = @(
        $memberNotifications.notifications |
            Where-Object { $_.type -ceq "follow" })

    Assert ([int]$initialPlayers.totalCount -eq 2) (
        "The all-player directory did not expose both harness users.")
    Assert ([int]$initialSearch.totalCount -eq 1 -and
        [long]$initialSearch.players[0].id -eq 4202) (
        "Unicode player search did not isolate the member.")
    Assert ([long]$initialLeaderboard.players[0].id -eq 4101) (
        "The charting-time leaderboard did not rank the owner first.")
    Assert ([int]$initialFriends.totalCount -eq 1 -and
        [int]$initialFollowing.totalCount -eq 1 -and
        [int]$initialFollowers.totalCount -eq 1) (
        "The initial mutual relationship directories were inconsistent.")
    Assert ($initialMember.isFollowing -eq $true -and
        $initialMember.isMutual -eq $true) (
        "The initial member profile was not mutual.")
    Assert ([int]$unfollow.followingCount -eq 0 -and
        [int]$unfollowIdempotent.followingCount -eq 0 -and
        [int]$friendsAfterDelete.totalCount -eq 0 -and
        [int]$followingAfterDelete.totalCount -eq 0 -and
        $memberAfterDelete.isFollowing -eq $false -and
        $memberAfterDelete.isMutual -eq $false) (
        "Unfollow did not atomically remove following, mutual and friend state.")
    Assert ([int]$refollow.followingCount -eq 1 -and
        [int]$refollowIdempotent.followingCount -eq 1 -and
        [int]$friendsAfterPut.totalCount -eq 1 -and
        $memberAfterPut.isFollowing -eq $true -and
        $memberAfterPut.isMutual -eq $true) (
        "Follow did not atomically restore following, mutual and friend state.")
    Assert ($followNotifications.Count -eq 1 -and
        [long]$followNotifications[0].actorUserId -eq 4101) (
        "A new follow did not emit exactly one member notification.")
    Assert ([int]$selfFollow.StatusCode -eq 400) (
        "Self-follow did not fail closed with HTTP 400.")
    Assert ([int]$state.followRequestCount -eq 5 -and
        [int]$state.followMutationCount -eq 2 -and
        [int]$state.followNotificationCount -eq 1 -and
        @($state.follows).Count -eq 2) (
        "Server social counters do not prove idempotent two-way mutation.")

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.online-social-harness-smoke.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        windowsAvaloniaOnly = $true
        productionServerMutationPerformed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        endpoint = $endpoint
        initial = [ordered]@{
            players = [int]$initialPlayers.totalCount
            unicodeSearchPlayers = [int]$initialSearch.totalCount
            leaderboardFirstUserId = [long]$initialLeaderboard.players[0].id
            friends = [int]$initialFriends.totalCount
            following = [int]$initialFollowing.totalCount
            followers = [int]$initialFollowers.totalCount
            targetIsFollowing = [bool]$initialMember.isFollowing
            targetIsMutual = [bool]$initialMember.isMutual
        }
        afterUnfollow = [ordered]@{
            actingFollowingCount = [int]$unfollow.followingCount
            idempotentActingFollowingCount = [int]$unfollowIdempotent.followingCount
            friends = [int]$friendsAfterDelete.totalCount
            following = [int]$followingAfterDelete.totalCount
            targetIsFollowing = [bool]$memberAfterDelete.isFollowing
            targetIsMutual = [bool]$memberAfterDelete.isMutual
        }
        afterRefollow = [ordered]@{
            actingFollowingCount = [int]$refollow.followingCount
            idempotentActingFollowingCount = [int]$refollowIdempotent.followingCount
            friends = [int]$friendsAfterPut.totalCount
            targetIsFollowing = [bool]$memberAfterPut.isFollowing
            targetIsMutual = [bool]$memberAfterPut.isMutual
            followNotifications = $followNotifications.Count
        }
        selfFollowHttpStatus = [int]$selfFollow.StatusCode
        counters = [ordered]@{
            requests = [int]$state.followRequestCount
            mutations = [int]$state.followMutationCount
            notifications = [int]$state.followNotificationCount
            relationships = @($state.follows).Count
        }
        hashes = [ordered]@{
            serverAssembly = (
                Get-FileHash -LiteralPath $serverAssembly -Algorithm SHA256).Hash
            frozenWpfInstaller = (
                Get-FileHash -LiteralPath (
                    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe") `
                    -Algorithm SHA256).Hash
        }
    }
    $evidence | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Write-Host "Windows Avalonia online social harness smoke: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    if ($server -and -not $server.HasExited) {
        $server.Kill($true)
        [void]$server.WaitForExit(5000)
    }
}
