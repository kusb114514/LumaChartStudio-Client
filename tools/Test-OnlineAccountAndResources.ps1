param(
    # No default. This script creates accounts and rooms and uploads files, and
    # it used to aim at production when the argument was left out. Name the
    # server on every run.
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$BaseUrl,
    [string]$ClientVersion = "",
    [string]$Username = "",
    [string]$Password = "",
    [switch]$CreateTemporaryAccount,
    [string]$RegistrationEmail = "",
    [switch]$RunMutationTests,
    [switch]$RunPasswordChangeTest,
    [string]$AvatarPath = "",
    [string]$AudioPath = "",
    [string]$FirstChartPath = "",
    [string]$SecondChartPath = "",
    [string]$CaptchaArtifactDirectory = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Resolve-ClientVersion([string]$RequestedVersion) {
    $resolved = ([string]$RequestedVersion).Trim()
    if ([string]::IsNullOrWhiteSpace($resolved)) {
        # The retired WPF LumaChart.App project used to supply this; the
        # Avalonia client is the one that talks to the server now.
        $projectFile = Join-Path $projectRoot 'LumaChart.Avalonia\LumaChart.Avalonia.csproj'
        [xml]$projectXml = Get-Content -LiteralPath $projectFile
        $resolved = [string](@($projectXml.Project.PropertyGroup |
            ForEach-Object { $_.Version } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) | Select-Object -First 1)
        $resolved = $resolved.Trim()
    }
    if ($resolved -notmatch '^\d+\.\d+\.\d+(\.\d+)?$') {
        throw "ClientVersion must use a three- or four-part version such as 1.2.1.3. Actual: '$resolved'."
    }
    return $resolved
}

$ClientVersion = Resolve-ClientVersion $ClientVersion
if (-not $CaptchaArtifactDirectory) {
    $CaptchaArtifactDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) "audit-artifacts\auth-captcha"
}
$suffix = ([Guid]::NewGuid().ToString("N")).Substring(0, 10)
$roomIds = [System.Collections.Generic.List[Guid]]::new()
$sessionTokens = [System.Collections.Generic.List[string]]::new()

function Assert-InteractiveCaptcha {
    if ([Console]::IsInputRedirected) {
        throw "Human captcha input is required. Run this script in an interactive PowerShell console; no production captcha bypass is available. Supply -Username (and optionally -Password), or use -CreateTemporaryAccount -RegistrationEmail <address>."
    }
}

function Read-Secret([string]$Prompt) {
    $secure = Read-Host $Prompt -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

function Invoke-Json([string]$Method, [string]$Path, $Body = $null, [string]$Token = "") {
    $headers = @{ "X-LumaChart-Version" = $ClientVersion }
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    $parameters = @{ Method = $Method; Uri = ([Uri]::new([Uri]$BaseUrl, $Path)); Headers = $headers }
    if ($null -ne $Body) {
        $parameters.ContentType = "application/json"
        $parameters.Body = ($Body | ConvertTo-Json -Depth 12 -Compress)
    }
    Invoke-RestMethod @parameters
}

function Read-Captcha([string]$Purpose) {
    Assert-InteractiveCaptcha
    $challenge = Invoke-Json Get "api/auth/captcha"
    New-Item -ItemType Directory -Path $CaptchaArtifactDirectory -Force | Out-Null
    $safePurpose = $Purpose -replace '[^A-Za-z0-9_-]', '_'
    $imagePath = Join-Path $CaptchaArtifactDirectory "captcha-$safePurpose-$($challenge.id).png"
    [IO.File]::WriteAllBytes($imagePath, [Convert]::FromBase64String($challenge.imageBase64))
    try {
        Write-Host "Captcha image: $imagePath"
        $answer = Read-Host "Enter the five digits shown for $Purpose"
        if ([string]::IsNullOrWhiteSpace($answer)) { throw "Captcha answer is required." }
        [pscustomobject]@{ Id = [Guid]$challenge.id; Answer = $answer.Trim() }
    }
    finally {
        Remove-Item -LiteralPath $imagePath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-Login([string]$LoginUsername, [string]$LoginPassword, [switch]$AllowHttpError) {
    $captcha = Read-Captcha "login"
    $body = @{
        username = $LoginUsername
        password = $LoginPassword
        captchaId = $captcha.Id
        captchaAnswer = $captcha.Answer
    }
    if (-not $AllowHttpError) { return Invoke-Json Post "api/auth/login" $body }
    Invoke-WebRequest -Method Post -Uri ([Uri]::new([Uri]$BaseUrl, "api/auth/login")) `
        -Headers @{ "X-LumaChart-Version" = $ClientVersion } -ContentType "application/json" `
        -Body ($body | ConvertTo-Json -Compress) -SkipHttpErrorCheck
}

function File-Entry([string]$Path, [string]$Name) {
    $item = Get-Item -LiteralPath $Path
    [pscustomobject]@{
        path = $Name
        length = $item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function Upload-Blob([Guid]$RoomId, $Entry, [string]$SourcePath, [string]$Token) {
    Invoke-WebRequest -Method Put -Uri ([Uri]::new([Uri]$BaseUrl, "api/rooms/$RoomId/resources/blobs/$($Entry.sha256)")) `
        -Headers @{ Authorization = "Bearer $Token"; "X-LumaChart-Version" = $ClientVersion } `
        -ContentType "application/octet-stream" -InFile $SourcePath | Out-Null
}

Assert-InteractiveCaptcha
if ($CreateTemporaryAccount) {
    if (-not $RegistrationEmail) {
        throw "-CreateTemporaryAccount requires -RegistrationEmail. The script never invents or bypasses an email verification code."
    }
    $Username = "itest_$suffix"
    $Password = "Before_$suffix!"
    $emailCaptcha = Read-Captcha "registration email"
    Invoke-Json Post "api/auth/email-codes" @{
        email = $RegistrationEmail
        purpose = "register"
        captchaId = $emailCaptcha.Id
        captchaAnswer = $emailCaptcha.Answer
    } | Out-Null
    $emailCode = Read-Host "Enter the six-digit code sent to the registration email"
    if ([string]::IsNullOrWhiteSpace($emailCode)) { throw "Registration email code is required." }
    $registration = Invoke-Json Post "api/auth/register" @{
        username = $Username
        password = $Password
        displayName = $Username
        email = $RegistrationEmail
        emailCode = $emailCode.Trim()
    }
    $token = $registration.accessToken
    $registeredUser = $registration.user
}
else {
    if (-not $Username) {
        throw "Provide -Username for the default non-mutating verification, or explicitly use -CreateTemporaryAccount -RegistrationEmail <address>."
    }
    if (-not $Password) { $Password = Read-Secret "Password" }
    $login = Invoke-Login $Username $Password
    $token = $login.accessToken
    $registeredUser = $login.user
}

if (-not $token) { throw "Authentication did not return an access token." }
$sessionTokens.Add($token)
$me = Invoke-Json Get "api/me" $null $token
if ($me.id -ne $registeredUser.id -or -not $me.email) {
    throw "The current-user profile did not match the login response or omitted its private email."
}

if (-not $RunMutationTests) {
    Invoke-Json Post "api/auth/logout" $null $token | Out-Null
    [pscustomobject]@{
        Success = $true
        ClientVersion = $ClientVersion
        Mode = "NonMutatingAuthentication"
        UserId = $me.id
        CaptchaRequired = $true
        PrivateEmailReturned = $true
        SessionRevoked = $true
    } | ConvertTo-Json -Compress
    return
}

if (-not $CreateTemporaryAccount) {
    throw "-RunMutationTests is restricted to an explicitly created temporary account so it cannot overwrite a real user's avatar or password. Add -CreateTemporaryAccount -RegistrationEmail <address>."
}
foreach ($requiredPath in @($AvatarPath, $AudioPath, $FirstChartPath, $SecondChartPath)) {
    if (-not $requiredPath -or -not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Mutation tests require valid -AvatarPath, -AudioPath, -FirstChartPath and -SecondChartPath files."
    }
}

$passwordChanged = $false
$plan1 = $null
$plan2 = $null
$manifest2 = $null
try {
    $avatar = Invoke-WebRequest -Method Put -Uri ([Uri]::new([Uri]$BaseUrl, "api/me/avatar")) `
        -Headers @{ Authorization = "Bearer $token"; "X-LumaChart-Version" = $ClientVersion } `
        -ContentType "application/octet-stream" -InFile $AvatarPath
    if ($avatar.StatusCode -ne 200 -or ($avatar.Content | ConvertFrom-Json).avatarKey -eq "default") {
        throw "Avatar upload failed."
    }

    if ($RunPasswordChangeTest) {
        $newPassword = "After_$suffix!"
        Invoke-Json Post "api/me/password" @{ currentPassword = $Password; newPassword = $newPassword } $token | Out-Null
        $currentSession = Invoke-Json Get "api/me" $null $token
        if ($currentSession.id -ne $registeredUser.id) { throw "Current session was revoked by password change." }
        $oldLogin = Invoke-Login $Username $Password -AllowHttpError
        if ($oldLogin.StatusCode -ne 401) { throw "Old password still works." }
        $newLogin = Invoke-Login $Username $newPassword
        if (-not $newLogin.accessToken) { throw "New password login failed." }
        $sessionTokens.Add($newLogin.accessToken)
        $Password = $newPassword
        $passwordChanged = $true
    }

    $audio = File-Entry $AudioPath "audio/test-audio.bin"
    $image = File-Entry $AvatarPath "images/cover.png"
    $chart1 = File-Entry $FirstChartPath "working.mc"
    $entries1 = @($chart1, $audio, $image)
    $room1 = Invoke-Json Post "api/rooms" @{ name = "Cache test 1"; isPrivate = $false; password = $null; isHidden = $true } $token
    $room1Id = [Guid]$room1.room.id
    $roomIds.Add($room1Id)
    $plan1 = Invoke-Json Post "api/rooms/$room1Id/resources/plan" @{ entries = $entries1 } $token
    foreach ($entry in $entries1 | Where-Object { $plan1.missingSha256 -contains $_.sha256 }) {
        $source = if ($entry.path -eq "working.mc") { $FirstChartPath } elseif ($entry.path -like "audio/*") { $AudioPath } else { $AvatarPath }
        Upload-Blob $room1Id $entry $source $token
    }
    Invoke-Json Post "api/rooms/$room1Id/resources/commit" @{ entries = $entries1 } $token | Out-Null

    $chart2 = File-Entry $SecondChartPath "working.mc"
    $entries2 = @($chart2, $audio, $image)
    $room2 = Invoke-Json Post "api/rooms" @{ name = "Cache test 2"; isPrivate = $false; password = $null; isHidden = $true } $token
    $room2Id = [Guid]$room2.room.id
    $roomIds.Add($room2Id)
    $plan2 = Invoke-Json Post "api/rooms/$room2Id/resources/plan" @{ entries = $entries2 } $token
    if ($plan2.missingSha256 -contains $audio.sha256 -or $plan2.missingSha256 -contains $image.sha256) {
        throw "Second room did not reuse cached audio/image blobs."
    }
    if ($plan2.missingSha256 -notcontains $chart2.sha256) { throw "Changed chart blob was not requested." }
    Upload-Blob $room2Id $chart2 $SecondChartPath $token
    $manifest2 = Invoke-Json Post "api/rooms/$room2Id/resources/commit" @{ entries = $entries2 } $token

    $download = Join-Path ([IO.Path]::GetTempPath()) "lumachart-itest-$suffix.bin"
    try {
        Invoke-WebRequest -Method Get -Uri ([Uri]::new([Uri]$BaseUrl, "api/rooms/$room2Id/resources/files/$($audio.sha256)")) `
            -Headers @{ Authorization = "Bearer $token"; "X-LumaChart-Version" = $ClientVersion } -OutFile $download
        if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant() -ne $audio.sha256) {
            throw "Downloaded resource hash mismatch."
        }
    }
    finally { Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue }
}
finally {
    foreach ($roomId in $roomIds) {
        Invoke-WebRequest -Method Delete -Uri ([Uri]::new([Uri]$BaseUrl, "api/rooms/$roomId")) `
            -Headers @{ Authorization = "Bearer $token"; "X-LumaChart-Version" = $ClientVersion } `
            -SkipHttpErrorCheck | Out-Null
    }
    foreach ($sessionToken in $sessionTokens) {
        try { Invoke-Json Post "api/auth/logout" $null $sessionToken | Out-Null } catch { }
    }
}

[pscustomobject]@{
    Success = $true
    ClientVersion = $ClientVersion
    Mode = "ExplicitTemporaryAccountMutations"
    TemporaryUserId = $registeredUser.id
    TemporaryUsername = $Username
    FirstMissingBytes = $plan1.missingBytes
    SecondMissingBytes = $plan2.missingBytes
    ReusedAudioAndImage = $true
    AvatarKeyChanged = $true
    PasswordChanged = $passwordChanged
    DownloadHashVerified = $true
    EntryCount = $manifest2.entries.Count
} | ConvertTo-Json -Compress
