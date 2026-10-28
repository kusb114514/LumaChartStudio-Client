[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',
    [switch] $NoRestore,
    # Lets a Release build fall back to the per-machine debug key. Such an APK
    # cannot update an installed release; use it only for builds that are never
    # handed to anyone.
    [switch] $AllowDebugSigning
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$toolchainRoot = Join-Path $repositoryRoot 'artifacts\android-toolchain'
$projectPath = Join-Path $repositoryRoot 'LumaChart.Android\LumaChart.Android.csproj'
$portableDotnet = Join-Path $toolchainRoot 'dotnet-full\dotnet.exe'
$dotnetRoot = Split-Path -Parent $portableDotnet
$dotnetCliHome = Join-Path $toolchainRoot 'cli-home'
$nugetPackages = Join-Path $dotnetCliHome '.nuget\packages'
$toolchainTemp = Join-Path $toolchainRoot 'temp'
$androidSdkRoot = if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_SDK_ROOT)) {
    [IO.Path]::GetFullPath($env:ANDROID_SDK_ROOT)
} elseif (-not [string]::IsNullOrWhiteSpace($env:ANDROID_HOME)) {
    [IO.Path]::GetFullPath($env:ANDROID_HOME)
} else {
    'D:\Tool\Android\Sdk'
}
$javaHome = @(
    'C:\Program Files\Microsoft\jdk-21.0.8.9-hotspot',
    'C:\Program Files\Android\Android Studio\jbr'
) | Where-Object {
    Test-Path -LiteralPath (Join-Path $_ 'bin\javac.exe') -PathType Leaf
} | Select-Object -First 1

foreach ($requiredFile in @(
    $projectPath,
    $portableDotnet)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Android build input is missing: $requiredFile"
    }
}

if (-not (Test-Path -LiteralPath $androidSdkRoot -PathType Container)) {
    throw "Android SDK root is missing: $androidSdkRoot"
}
if ([string]::IsNullOrWhiteSpace($javaHome)) {
    throw 'A compatible JDK 21 installation was not found.'
}

# Release signing. LumaChart.Android.csproj takes the key from these variables
# (the passwords by env: reference, so they stay out of logs). Without them
# .NET for Android signs with a debug key it generates per machine, and an APK
# signed that way cannot update an installed release: the user would have to
# uninstall, which deletes the chart library. Never commit a keystore.
$signingVariables = @(
    'LUMACHART_ANDROID_KEYSTORE',
    'LUMACHART_ANDROID_KEY_ALIAS',
    'LUMACHART_ANDROID_STORE_PASS',
    'LUMACHART_ANDROID_KEY_PASS')
$missingSigningVariables = @($signingVariables | Where-Object {
    [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_))
})
$releaseSigned = $missingSigningVariables.Count -eq 0
if (-not $releaseSigned -and $missingSigningVariables.Count -lt $signingVariables.Count) {
    throw "Android release signing is only partly configured; missing: $($missingSigningVariables -join ', ')."
}
if ($releaseSigned) {
    $releaseKeystore = [IO.Path]::GetFullPath($env:LUMACHART_ANDROID_KEYSTORE)
    if (-not (Test-Path -LiteralPath $releaseKeystore -PathType Leaf)) {
        throw "Android release keystore was not found: $releaseKeystore"
    }
    # Absolute, so the signer does not resolve it against the project folder.
    $env:LUMACHART_ANDROID_KEYSTORE = $releaseKeystore
} elseif ($Configuration -eq 'Release' -and -not $AllowDebugSigning) {
    throw ("A Release APK must be signed with the release key. Set " +
        ($signingVariables -join ', ') +
        ", or pass -AllowDebugSigning for a build that will not be distributed.")
}

foreach ($directory in @($dotnetCliHome, $nugetPackages, $toolchainTemp)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$env:DOTNET_ROOT = $dotnetRoot
$env:DOTNET_CLI_HOME = $dotnetCliHome
$env:DOTNET_MULTILEVEL_LOOKUP = '0'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'
$env:NUGET_PACKAGES = $nugetPackages
$env:ANDROID_HOME = $androidSdkRoot
$env:ANDROID_SDK_ROOT = $androidSdkRoot
$env:JAVA_HOME = $javaHome
$env:TEMP = $toolchainTemp
$env:TMP = $toolchainTemp
$env:Path = "$dotnetRoot;$(Join-Path $javaHome 'bin');$env:Path"

$resolvedDotnet = (Get-Command dotnet -ErrorAction Stop).Source
if (-not [IO.Path]::GetFullPath($resolvedDotnet).Equals(
        [IO.Path]::GetFullPath($portableDotnet),
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "The Android build resolved an unexpected dotnet host: $resolvedDotnet"
}

# Obfuscation is retired: the Android editor never loaded the native ClientSecurity
# module (that P/Invoke lives only in the deprecated WPF LumaChart.App), so there is
# no ELF gate here anymore and no OLLVM step participates in the Android build.

Push-Location $repositoryRoot
try {
    if (-not $NoRestore) {
        & $portableDotnet restore $projectPath -r android-arm64
        if ($LASTEXITCODE -ne 0) {
            throw "Android restore failed with exit code $LASTEXITCODE."
        }
    }

    # Candidate APKs must never reuse Java/JNI typemaps or marshal tables from
    # an earlier Android build. A stale incremental graph can still compile and
    # pass static APK inspection while failing at MainActivity.n_onCreate on a
    # device, so clean is an unconditional part of the candidate build chain.
    & $portableDotnet clean $projectPath `
        -c $Configuration `
        -r android-arm64 `
        -m:1
    if ($LASTEXITCODE -ne 0) {
        throw "Android clean failed with exit code $LASTEXITCODE."
    }

    & $portableDotnet build $projectPath `
        -c $Configuration `
        -r android-arm64 `
        --no-restore `
        -warnaserror `
        -m:1
    if ($LASTEXITCODE -ne 0) {
        throw "Android build failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

$apkPath = Join-Path $repositoryRoot (
    "LumaChart.Android\bin\$Configuration\net10.0-android\android-arm64\cc.lumachart.studio-Signed.apk")
if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
    throw "The signed Android APK was not produced: $apkPath"
}

# Prove which key actually signed the APK. The certificate digest is what an
# installed copy is matched against, so it is printed for every build and a
# release build signed with a debug certificate is refused outright.
$apkSigner = Get-ChildItem -LiteralPath (Join-Path $androidSdkRoot 'build-tools') -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'apksigner.bat') -PathType Leaf } |
    Sort-Object -Descending -Property @{ Expression = {
        $parsed = $null
        if ([Version]::TryParse($_.Name, [ref]$parsed)) { $parsed } else { [Version]'0.0' }
    } } |
    Select-Object -First 1 |
    ForEach-Object { Join-Path $_.FullName 'apksigner.bat' }
if ([string]::IsNullOrWhiteSpace($apkSigner)) {
    throw "apksigner was not found under $(Join-Path $androidSdkRoot 'build-tools')."
}
$signerReport = @(& $apkSigner verify --print-certs $apkPath 2>&1 | ForEach-Object { [string]$_ })
if ($LASTEXITCODE -ne 0) {
    $signerReport | Write-Output
    throw "apksigner rejected the APK with exit code $LASTEXITCODE."
}
$certificateDigests = @($signerReport | ForEach-Object {
    if ($_ -match 'certificate SHA-256 digest:\s*([0-9A-Fa-f]+)') { $Matches[1].ToUpperInvariant() }
})
$certificateNames = @($signerReport | ForEach-Object {
    if ($_ -match 'certificate DN:\s*(.+)$') { $Matches[1].Trim() }
})
if ($certificateDigests.Count -eq 0) {
    $signerReport | Write-Output
    throw 'apksigner did not report a signing certificate digest.'
}
$debugCertificate = @($certificateNames | Where-Object { $_ -match '(^|,\s*)CN=Android Debug(,|$)' }).Count -gt 0
if ($releaseSigned -and $debugCertificate) {
    throw 'The release signing variables were set, but the APK carries the Android debug certificate.'
}

$apk = Get-Item -LiteralPath $apkPath
$hash = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash
Write-Output "ANDROID_APK_BUILD=OK"
Write-Output "APK=$apkPath"
Write-Output "BYTES=$($apk.Length)"
Write-Output "SHA256=$hash"
Write-Output "SIGNING=$(if ($releaseSigned) { 'release' } else { 'debug' })"
foreach ($name in $certificateNames) { Write-Output "SIGNER_CERT_DN=$name" }
foreach ($digest in $certificateDigests) { Write-Output "SIGNER_CERT_SHA256=$digest" }
if ($debugCertificate) {
    Write-Warning 'This APK is signed with a debug certificate and cannot update a release install.'
}
