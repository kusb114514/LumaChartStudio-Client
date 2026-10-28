[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Preinstall', 'Device', 'All')]
    [string] $Stage,

    [Parameter(Mandatory)]
    [string] $ApkPath,

    [string] $NativeManifestPath = '',
    [string] $NativeLibraryPath = '',
    [string] $PublishedNativeVerifierPath = '',
    [string] $AndroidSdkRoot = 'D:\Tool\Android\Sdk',
    [string] $AdbPath = 'D:\Tool\platform-tools\adb.exe',
    [string] $ArtifactsDirectory = '',
    [string] $PackageId = 'cc.lumachart.studio',
    [string] $ActivityName = 'cc.lumachart.studio.MainActivity',
    [string] $ExpectedVersionName = '1.0.0',
    [ValidateRange(1, [int]::MaxValue)]
    [int] $ExpectedVersionCode = 1,
    [ValidateRange(21, 100)]
    [int] $ExpectedMinSdk = 26,
    [ValidateRange(21, 100)]
    [int] $ExpectedTargetSdk = 36,
    [ValidateRange(5, 300)]
    [int] $ProbeTimeoutSeconds = 45
)

# Retired. Every stage of this harness gates on the native ClientSecurity module
# (its build manifest, the .so inside the APK, and the published verifier),
# which was removed from the Android build: the Avalonia editor never loaded it.
# Run on a current APK it can only fail, or worse, report a stale artifact.
# Build and check an APK with tools\Build-AndroidApk.ps1, which verifies the
# signature and prints the signing certificate; install it with
# `adb install -r <apk>`. The body is kept for reference only.
throw ('tools\Test-AndroidApkAndDevice.ps1 is retired: it verifies the removed native ' +
    'ClientSecurity module. Use tools\Build-AndroidApk.ps1 and adb install -r instead.')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$projectRoot = [IO.Path]::GetFullPath((Join-Path $scriptRoot '..'))
$requiredArtifactsRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'artifacts'))
$verificationRoot = if ([string]::IsNullOrWhiteSpace($ArtifactsDirectory)) {
    Join-Path $requiredArtifactsRoot 'android-apk-verification'
} else {
    [IO.Path]::GetFullPath($ArtifactsDirectory)
}
$nativeManifestPath = if ([string]::IsNullOrWhiteSpace($NativeManifestPath)) {
    Join-Path $requiredArtifactsRoot 'native\client-security\android-arm64\android-native-build-manifest.json'
} else {
    [IO.Path]::GetFullPath($NativeManifestPath)
}
$nativeLibraryPath = if ([string]::IsNullOrWhiteSpace($NativeLibraryPath)) {
    Join-Path $projectRoot 'LumaChart.ClientSecurity.Native\bin\android-arm64\libLumaChart.ClientSecurity.so'
} else {
    [IO.Path]::GetFullPath($NativeLibraryPath)
}
$publishedNativeVerifierPath = if ([string]::IsNullOrWhiteSpace($PublishedNativeVerifierPath)) {
    Join-Path $projectRoot 'LumaChart.ClientSecurity.Native\Verify-PublishedClientSecurityAndroid.ps1'
} else {
    [IO.Path]::GetFullPath($PublishedNativeVerifierPath)
}
$apkPath = [IO.Path]::GetFullPath($ApkPath)
$androidSdkRoot = [IO.Path]::GetFullPath($AndroidSdkRoot)
$adbPath = [IO.Path]::GetFullPath($AdbPath)

function Assert-PathIsWithin(
    [string] $Path,
    [string] $RequiredRoot,
    [string] $Description) {
    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullRoot = [IO.Path]::GetFullPath($RequiredRoot)
    $separator = [IO.Path]::DirectorySeparatorChar
    $prefix = $fullRoot.TrimEnd($separator) + $separator
    if (-not $fullPath.Equals($fullRoot, [StringComparison]::OrdinalIgnoreCase) -and
        -not $fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description must stay under $fullRoot. Actual path: $fullPath"
    }
}

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-TextEqual(
    [AllowNull()][object] $Actual,
    [AllowNull()][object] $Expected,
    [string] $Description) {
    $actualText = if ($null -eq $Actual) { '' } else { [string]$Actual }
    $expectedText = if ($null -eq $Expected) { '' } else { [string]$Expected }
    if (-not $actualText.Equals($expectedText, [StringComparison]::Ordinal)) {
        throw "$Description mismatch. Expected '$expectedText'; actual '$actualText'."
    }
}

function Write-JsonFile([string] $Path, [object] $Value) {
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $json = $Value | ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}

function Convert-OutputLines([object[]] $RawOutput) {
    return @(
        foreach ($item in $RawOutput) {
            if ($item -is [Management.Automation.ErrorRecord]) {
                $item.Exception.Message
            } else {
                [string]$item
            }
        }
    )
}

function Invoke-NativeTool(
    [string] $ToolPath,
    [string[]] $ArgumentList,
    [string] $LogPath,
    [string] $FailureMessage,
    [switch] $AllowFailure) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $rawOutput = @(& $ToolPath @ArgumentList 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    [string[]] $output = @(Convert-OutputLines $rawOutput)
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $logParent = Split-Path -Parent $LogPath
        New-Item -ItemType Directory -Path $logParent -Force | Out-Null
        [IO.File]::WriteAllLines($LogPath, $output, [Text.UTF8Encoding]::new($false))
    }
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        $detail = ($output | Out-String).Trim()
        throw "$FailureMessage Exit code: $exitCode. $detail"
    }
    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output = $output
        Text = ($output -join "`n")
    }
}

function Get-Sha256([string] $Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-StreamSha256([IO.Stream] $Stream) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = $algorithm.ComputeHash($Stream)
        return (($digest | ForEach-Object { $_.ToString('X2') }) -join '')
    } finally {
        $algorithm.Dispose()
    }
}

function Resolve-AndroidBuildTools([string] $SdkRoot) {
    $buildToolsRoot = Join-Path $SdkRoot 'build-tools'
    if (-not (Test-Path -LiteralPath $buildToolsRoot -PathType Container)) {
        throw "Android build-tools directory is missing: $buildToolsRoot"
    }
    $candidates = @(
        foreach ($directory in Get-ChildItem -LiteralPath $buildToolsRoot -Directory) {
            $parsedVersion = $null
            if (-not [Version]::TryParse($directory.Name, [ref]$parsedVersion)) {
                continue
            }
            $aapt2 = Join-Path $directory.FullName 'aapt2.exe'
            $apksigner = Join-Path $directory.FullName 'apksigner.bat'
            $zipalign = Join-Path $directory.FullName 'zipalign.exe'
            if ((Test-Path -LiteralPath $aapt2 -PathType Leaf) -and
                (Test-Path -LiteralPath $apksigner -PathType Leaf) -and
                (Test-Path -LiteralPath $zipalign -PathType Leaf)) {
                [PSCustomObject]@{
                    Version = $parsedVersion
                    VersionText = $directory.Name
                    Aapt2 = $aapt2
                    ApkSigner = $apksigner
                    ZipAlign = $zipalign
                }
            }
        }
    )
    if ($candidates.Count -eq 0) {
        throw "No complete Android build-tools installation containing aapt2, apksigner and zipalign was found under $buildToolsRoot."
    }
    return $candidates | Sort-Object Version -Descending | Select-Object -First 1
}

function Get-AaptQuotedValues([string] $Line) {
    return @(
        foreach ($match in [Regex]::Matches($Line, "'([^']+)'")) {
            $match.Groups[1].Value
        }
    )
}

function Test-Preinstall(
    [string] $PreinstallDirectory,
    [string] $TemporaryDirectory,
    [string] $ApkSha256,
    [object] $BuildTools) {
    New-Item -ItemType Directory -Path $PreinstallDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $TemporaryDirectory -Force | Out-Null

    $powerShellHost = (Get-Command pwsh.exe -ErrorAction Stop).Source
    $publishedGate = Invoke-NativeTool `
        -ToolPath $powerShellHost `
        -ArgumentList @(
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy', 'Bypass',
            '-File', $publishedNativeVerifierPath) `
        -LogPath (Join-Path $PreinstallDirectory 'published-native-verification.txt') `
        -FailureMessage 'The published Android ClientSecurity chain was rejected.'
    Assert-True (@($publishedGate.Output | Where-Object {
        $_.Trim() -ceq 'PUBLISHED_CLIENT_SECURITY_ANDROID=OK'
    }).Count -eq 1) 'Published Android ClientSecurity verifier did not emit its unique success token.'

    $manifest = Get-Content -LiteralPath $nativeManifestPath -Raw | ConvertFrom-Json
    Assert-True ([int]$manifest.schema -eq 1) 'Native build manifest schema must be 1.'
    Assert-TextEqual $manifest.platform 'android' 'Native build manifest platform'
    Assert-TextEqual $manifest.abi 'arm64-v8a' 'Native build manifest ABI'
    Assert-TextEqual $manifest.module_id 'LumaChart.ClientSecurity' 'Native build manifest module'
    Assert-True ([string]$manifest.target_triple -match '^aarch64-linux-android\d+$') 'Native build manifest target triple is not Android AArch64.'
    Assert-TextEqual $manifest.output 'LumaChart.ClientSecurity.Native/bin/android-arm64/libLumaChart.ClientSecurity.so' 'Native build manifest output'

    $nativeSha256 = Get-Sha256 $nativeLibraryPath
    Assert-TextEqual ([string]$manifest.output_sha256).ToUpperInvariant() $nativeSha256 'Native build manifest/SO SHA-256'

    $signer = Invoke-NativeTool `
        -ToolPath $BuildTools.ApkSigner `
        -ArgumentList @('verify', '--verbose', '--print-certs', $apkPath) `
        -LogPath (Join-Path $PreinstallDirectory 'apksigner-verify.txt') `
        -FailureMessage 'apksigner rejected the signed APK.'
    Assert-True ($signer.Text -match '(?m)^Verifies\s*$') 'apksigner did not report a successful verification.'
    Assert-True ($signer.Text -match '(?m)^Verified using v2 scheme \(APK Signature Scheme v2\): true\s*$') 'The APK must verify with APK Signature Scheme v2.'
    Assert-True ($signer.Text -match '(?m)^Number of signers: 1\s*$') 'The APK must have exactly one signer.'
    $signerDigestMatch = [Regex]::Match(
        $signer.Text,
        '(?im)^Signer #1 certificate SHA-256 digest:\s*([0-9a-f]{64})\s*$')
    Assert-True $signerDigestMatch.Success 'apksigner did not emit the signer certificate SHA-256 digest.'
    $signerCertificateSha256 = $signerDigestMatch.Groups[1].Value.ToUpperInvariant()

    $alignment = Invoke-NativeTool `
        -ToolPath $BuildTools.ZipAlign `
        -ArgumentList @('-c', '-P', '16', '-v', '4', $apkPath) `
        -LogPath (Join-Path $PreinstallDirectory 'zipalign-16k-verify.txt') `
        -FailureMessage 'zipalign rejected the APK for 16 KiB page alignment.'
    Assert-True ($alignment.Text -match '(?m)^Verification successful\s*$') 'zipalign did not report successful 16 KiB verification.'

    $badging = Invoke-NativeTool `
        -ToolPath $BuildTools.Aapt2 `
        -ArgumentList @('dump', 'badging', $apkPath) `
        -LogPath (Join-Path $PreinstallDirectory 'aapt2-badging.txt') `
        -FailureMessage 'aapt2 could not inspect APK badging.'
    $permissions = Invoke-NativeTool `
        -ToolPath $BuildTools.Aapt2 `
        -ArgumentList @('dump', 'permissions', $apkPath) `
        -LogPath (Join-Path $PreinstallDirectory 'aapt2-permissions.txt') `
        -FailureMessage 'aapt2 could not inspect APK permissions.'
    $xmlTree = Invoke-NativeTool `
        -ToolPath $BuildTools.Aapt2 `
        -ArgumentList @('dump', 'xmltree', $apkPath, '--file', 'AndroidManifest.xml') `
        -LogPath (Join-Path $PreinstallDirectory 'aapt2-manifest-xmltree.txt') `
        -FailureMessage 'aapt2 could not inspect AndroidManifest.xml.'

    $packageMatch = [Regex]::Match(
        $badging.Text,
        "(?m)^package: name='([^']+)' versionCode='([^']+)' versionName='([^']*)'.*$")
    Assert-True $packageMatch.Success 'aapt2 badging did not contain package/version identity.'
    Assert-TextEqual $packageMatch.Groups[1].Value $PackageId 'APK package ID'
    Assert-TextEqual $packageMatch.Groups[2].Value ([string]$ExpectedVersionCode) 'APK versionCode'
    Assert-TextEqual $packageMatch.Groups[3].Value $ExpectedVersionName 'APK versionName'

    $minSdkMatch = [Regex]::Match($badging.Text, "(?m)^minSdkVersion:'([^']+)'\s*$")
    $targetSdkMatch = [Regex]::Match($badging.Text, "(?m)^targetSdkVersion:'([^']+)'\s*$")
    Assert-True $minSdkMatch.Success 'aapt2 badging did not contain minSdkVersion.'
    Assert-True $targetSdkMatch.Success 'aapt2 badging did not contain targetSdkVersion.'
    Assert-TextEqual $minSdkMatch.Groups[1].Value ([string]$ExpectedMinSdk) 'APK minSdkVersion'
    Assert-TextEqual $targetSdkMatch.Groups[1].Value ([string]$ExpectedTargetSdk) 'APK targetSdkVersion'

    $launchableMatch = [Regex]::Match(
        $badging.Text,
        "(?m)^launchable-activity: name='([^']+)'.*$")
    Assert-True $launchableMatch.Success 'aapt2 badging did not contain a launchable activity.'
    Assert-TextEqual $launchableMatch.Groups[1].Value $ActivityName 'APK launchable activity'

    $nativeCodeMatch = [Regex]::Match($badging.Text, '(?m)^native-code:\s*(.+)\s*$')
    Assert-True $nativeCodeMatch.Success 'aapt2 badging did not report native-code ABIs.'
    $badgingAbis = @(Get-AaptQuotedValues $nativeCodeMatch.Groups[1].Value)
    Assert-True ($badgingAbis.Count -eq 1 -and $badgingAbis[0] -ceq 'arm64-v8a') `
        "APK native-code must be exactly arm64-v8a. Actual: $($badgingAbis -join ', ')"

    $forbiddenStoragePermissions = @(
        'android.permission.READ_EXTERNAL_STORAGE',
        'android.permission.WRITE_EXTERNAL_STORAGE',
        'android.permission.MANAGE_EXTERNAL_STORAGE',
        'android.permission.MANAGE_MEDIA',
        'android.permission.READ_MEDIA_AUDIO',
        'android.permission.READ_MEDIA_IMAGES',
        'android.permission.READ_MEDIA_VIDEO',
        'android.permission.READ_MEDIA_VISUAL_USER_SELECTED',
        'android.permission.ACCESS_MEDIA_LOCATION'
    )
    $manifestInspectionText = $badging.Text + "`n" + $permissions.Text + "`n" + $xmlTree.Text
    foreach ($permission in $forbiddenStoragePermissions) {
        if ($manifestInspectionText.IndexOf($permission, [StringComparison]::Ordinal) -ge 0) {
            throw "APK requests forbidden broad storage permission: $permission"
        }
    }
    if ($xmlTree.Text -match '(?i)requestLegacyExternalStorage[^\r\n]*=true' -or
        $xmlTree.Text -match '(?i)preserveLegacyExternalStorage[^\r\n]*=true') {
        throw 'APK enables a forbidden legacy external-storage escape hatch.'
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($apkPath)
    try {
        $libraryEntries = @($archive.Entries | Where-Object {
            $_.FullName.StartsWith('lib/', [StringComparison]::Ordinal)
        })
        Assert-True ($libraryEntries.Count -gt 0) 'APK contains no native library entries.'
        $apkAbis = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($entry in $libraryEntries) {
            $entryMatch = [Regex]::Match($entry.FullName, '^lib/([^/]+)/[^/]+$')
            Assert-True $entryMatch.Success "Unexpected native-library ZIP path: $($entry.FullName)"
            [void]$apkAbis.Add($entryMatch.Groups[1].Value)
        }
        $actualApkAbis = @($apkAbis | Sort-Object)
        Assert-True ($actualApkAbis.Count -eq 1 -and $actualApkAbis[0] -ceq 'arm64-v8a') `
            "APK ZIP native ABIs must be exactly arm64-v8a. Actual: $($actualApkAbis -join ', ')"

        $expectedSecurityEntryPath = 'lib/arm64-v8a/libLumaChart.ClientSecurity.so'
        $securityEntries = @($archive.Entries | Where-Object {
            [IO.Path]::GetFileName($_.FullName).Equals(
                'libLumaChart.ClientSecurity.so',
                [StringComparison]::Ordinal)
        })
        Assert-True ($securityEntries.Count -eq 1) `
            "APK must contain exactly one libLumaChart.ClientSecurity.so; found $($securityEntries.Count)."
        Assert-TextEqual $securityEntries[0].FullName $expectedSecurityEntryPath 'APK ClientSecurity ZIP entry path'
        $securityStream = $securityEntries[0].Open()
        try {
            $packagedNativeSha256 = Get-StreamSha256 $securityStream
        } finally {
            $securityStream.Dispose()
        }
    } finally {
        $archive.Dispose()
    }
    Assert-TextEqual $packagedNativeSha256 $nativeSha256 'Packaged/current ClientSecurity SO SHA-256'

    $reportPath = Join-Path $PreinstallDirectory 'preinstall-verification.json'
    $report = [ordered]@{
        SchemaVersion = 1
        Status = 'passed'
        Stage = 'preinstall'
        GeneratedAtUtc = [DateTime]::UtcNow.ToString('O')
        PackageId = $PackageId
        ActivityName = $ActivityName
        VersionName = $ExpectedVersionName
        VersionCode = $ExpectedVersionCode
        MinSdk = $ExpectedMinSdk
        TargetSdk = $ExpectedTargetSdk
        ApkSha256 = $ApkSha256
        SignerCertificateSha256 = $signerCertificateSha256
        SignatureSchemeV2 = $true
        ZipAlignmentPageSize = 16384
        ApkAbis = @('arm64-v8a')
        ClientSecurityZipEntry = 'lib/arm64-v8a/libLumaChart.ClientSecurity.so'
        ClientSecuritySha256 = $nativeSha256
        PublishedNativeChainVerified = $true
        NativeBuildId = [string]$manifest.build_id
        NativeManifestSha256 = Get-Sha256 $nativeManifestPath
        BroadStoragePermissions = @()
        AndroidBuildToolsVersion = [string]$BuildTools.VersionText
    }
    Write-JsonFile $reportPath $report
    return [PSCustomObject]@{
        ReportPath = $reportPath
        NativeSha256 = $nativeSha256
        SignerCertificateSha256 = $signerCertificateSha256
    }
}

function Invoke-Adb(
    [string[]] $ArgumentList,
    [string] $LogPath,
    [string] $FailureMessage,
    [switch] $AllowFailure) {
    return Invoke-NativeTool `
        -ToolPath $adbPath `
        -ArgumentList $ArgumentList `
        -LogPath $LogPath `
        -FailureMessage $FailureMessage `
        -AllowFailure:$AllowFailure
}

function Assert-DeviceDirectory([string] $DevicePath, [string] $LogPath) {
    $result = Invoke-Adb `
        -ArgumentList @('shell', 'test', '-d', $DevicePath) `
        -LogPath $LogPath `
        -FailureMessage "Required app-private external directory is missing: $DevicePath" `
        -AllowFailure
    if ($result.ExitCode -ne 0) {
        throw "Required app-private external directory is missing: $DevicePath"
    }
}

function Normalize-AndroidPath([string] $Path) {
    return $Path.Replace('\', '/').TrimEnd('/')
}

function Test-DeviceReport(
    [object] $Report,
    [string] $ExpectedExternalSuffix,
    [string] $ExpectedExternalCacheSuffix,
    [int] $ExpectedPid) {
    Assert-True ([int]$Report.SchemaVersion -eq 3) `
        'device-verification.json schema must include the P0-2 basic-editing slice.'
    Assert-TextEqual $Report.Status 'passed' 'Device probe status'
    Assert-TextEqual $Report.PackageId $PackageId 'Device probe package ID'
    Assert-TextEqual $Report.ApplicationVersion $ExpectedVersionName 'Device probe application version'
    Assert-TextEqual $Report.RuntimeArchitecture 'Arm64' 'Device runtime architecture'
    Assert-True ([int]$Report.AndroidApi -ge $ExpectedMinSdk) 'Device Android API is below the APK minSdk.'
    Assert-TextEqual $Report.Orientation 'landscape' 'Device probe orientation'
    $supportedAbis = @($Report.SupportedAbis)
    Assert-True (@($supportedAbis | Where-Object { [string]$_ -ceq 'arm64-v8a' }).Count -eq 1) `
        'Device probe SupportedAbis does not contain arm64-v8a exactly once.'

    Assert-True ($null -ne $Report.Storage -and [bool]$Report.Storage.DirectoriesReady) `
        'Device probe did not create all storage directories.'
    $externalRoot = Normalize-AndroidPath ([string]$Report.Storage.ExternalRoot)
    Assert-True ($externalRoot.EndsWith($ExpectedExternalSuffix, [StringComparison]::Ordinal)) `
        "Device external root is outside Android/data/$PackageId/files: $externalRoot"
    Assert-TextEqual (Normalize-AndroidPath ([string]$Report.Storage.Library)) "$externalRoot/Library" 'Device Library path'
    Assert-TextEqual (Normalize-AndroidPath ([string]$Report.Storage.PersistentEditing)) "$externalRoot/_editing" 'Device _editing path'
    $resourceCache = Normalize-AndroidPath ([string]$Report.Storage.ResourceCache)
    Assert-True ($resourceCache.EndsWith("$ExpectedExternalCacheSuffix/_resources", [StringComparison]::Ordinal)) `
        "Device _resources path is outside Android/data/$PackageId/cache: $resourceCache"
    $settingsPath = Normalize-AndroidPath ([string]$Report.Storage.Settings)
    Assert-True ($settingsPath -match "/$([Regex]::Escape($PackageId))/files/settings$") `
        "Device settings path is not app-internal: $settingsPath"
    $scratchPath = Normalize-AndroidPath ([string]$Report.Storage.SessionScratch)
    Assert-True ($scratchPath -match "/$([Regex]::Escape($PackageId))/cache/_scratch/session_$ExpectedPid$") `
        "Device session scratch path does not match the running process: $scratchPath"

    Assert-True ($null -ne $Report.Permissions) 'Device permission probe is missing.'
    Assert-True (-not [bool]$Report.Permissions.ReadExternalStorageGranted) `
        'READ_EXTERNAL_STORAGE must not be granted.'
    Assert-True (-not [bool]$Report.Permissions.ManageExternalStorageGranted) `
        'MANAGE_EXTERNAL_STORAGE must not be granted.'

    Assert-True ($null -ne $Report.Saf) 'Device SAF probe is missing.'
    Assert-True ([bool]$Report.Saf.OpenDocumentHandlerAvailable) 'ACTION_OPEN_DOCUMENT has no device handler.'
    Assert-True ([bool]$Report.Saf.CreateDocumentHandlerAvailable) 'ACTION_CREATE_DOCUMENT has no device handler.'
    Assert-True (-not [bool]$Report.Saf.ContentUriRetainedAsDocumentPath) `
        'A content URI was retained as a chart document path.'

    Assert-True ($null -ne $Report.SharedLayer -and [bool]$Report.SharedLayer.Success) `
        'Shared Core/Application/Online probe failed.'
    foreach ($property in @(
        'SourcePathsClean',
        'ExplicitCreatorFallback',
        'UndoPassed',
        'RedoPassed',
        'CodecPassed')) {
        Assert-True ([bool]$Report.SharedLayer.$property) "Shared-layer probe failed: $property"
    }
    Assert-True ([int]$Report.SharedLayer.McNoteCount -gt 0) 'Golden .mc probe parsed no notes.'
    Assert-True ([int]$Report.SharedLayer.OsuNoteCount -gt 0) 'Golden .osu probe parsed no notes.'
    $operationId = [Guid]::Empty
    Assert-True ([Guid]::TryParse([string]$Report.SharedLayer.StableOperationId, [ref]$operationId) -and
        $operationId -ne [Guid]::Empty) 'Shared-layer probe did not retain a stable non-empty operation ID.'

    Assert-True ($null -ne $Report.Workspace -and [bool]$Report.Workspace.Success) `
        'Local Library/workspace probe failed.'
    Assert-True ([int]$Report.Workspace.LibraryEntryCount -eq 2) `
        'Local workspace probe did not scan exactly two MC/OSU sources.'
    foreach ($property in @(
        'IndependentSessions',
        'IndependentUndo',
        'McSaveReloadPassed',
        'OsuSaveReloadPassed',
        'DirtyWorkspaceRestorePassed',
        'SourceChangeWon')) {
        Assert-True ([bool]$Report.Workspace.$property) "Local workspace probe failed: $property"
    }

    Assert-True ($null -ne $Report.BasicEditing -and [bool]$Report.BasicEditing.Success) `
        'P0-2 basic editing probe failed.'
    foreach ($property in @(
        'TapContinuousPassed',
        'HoldTailPassed',
        'SelectionBatchPassed',
        'TimingPassed',
        'MetadataKeyCountPassed',
        'ValidationSaveBlockPassed')) {
        Assert-True ([bool]$Report.BasicEditing.$property) "P0-2 basic editing probe failed: $property"
    }

    Assert-True ($null -ne $Report.NativeSecurity -and [bool]$Report.NativeSecurity.Success) `
        'Native ClientSecurity probe failed closed.'
    Assert-TextEqual $Report.NativeSecurity.AbiVersion '0x00010001' 'Native ClientSecurity ABI version'
    Assert-True ([int]$Report.NativeSecurity.Status -eq 0) 'Native ClientSecurity self-test status is not zero.'
    Assert-True ([bool]$Report.NativeSecurity.BindingProduced) 'Native ClientSecurity produced no binding.'
    Assert-True ([bool]$Report.NativeSecurity.OnlinePolicyFailClosed) 'Online policy is not declared fail-closed.'
    Assert-True (-not [bool]$Report.NativeSecurity.OnlineUiExposed) 'Unverified online UI is exposed.'

    Assert-True ($null -ne $Report.Keystore -and [bool]$Report.Keystore.Success) `
        'Android Keystore probe failed.'
    Assert-True ([bool]$Report.Keystore.PlaintextAbsent) 'Keystore probe found plaintext token material.'
    Assert-True ([bool]$Report.Keystore.RoundTripPassed) 'Keystore round-trip probe failed.'
    Assert-True ([bool]$Report.Keystore.ConcurrentInstancesPassed) `
        'Keystore concurrent first-store probe failed.'
    Assert-True ([bool]$Report.Keystore.ProbeBlobDeleted) 'Keystore probe blob was not deleted.'

    Assert-True ($null -ne $Report.Timeline -and [bool]$Report.Timeline.VirtualizationWorked) `
        '100,000-note timeline virtualization probe failed.'
    Assert-True ([int]$Report.Timeline.NoteCount -eq 100000) 'Timeline probe did not use exactly 100,000 notes.'
    Assert-True ([int]$Report.Timeline.DrawFrameCount -ge 120) 'Timeline probe captured fewer than 120 draw frames.'
    Assert-True ([int]$Report.Timeline.MaximumVisitedNotesPerFrame -lt 25000) `
        'Timeline probe visited at least one quarter of all notes in a frame.'
    Assert-True ([bool]$Report.Timeline.LongHoldIntersectionVisited) `
        'Timeline interval index skipped a long hold crossing the visible window.'
    Assert-True ([int]$Report.Timeline.SurfaceWidth -gt 0 -and
        [int]$Report.Timeline.SurfaceHeight -gt 0) 'Timeline probe has no real surface dimensions.'
    Assert-True ([double]$Report.Timeline.DatasetGenerationMilliseconds -ge 0 -and
        [long]$Report.Timeline.ManagedBytesAfterDataset -gt 0) `
        'Timeline probe did not record dataset/managed-memory evidence.'

    Assert-True ($null -ne $Report.Interaction) 'Device interaction probe is missing.'
    foreach ($property in @(
        'ToolbarAdds',
        'SurfaceTapAdds',
        'UndoSuccesses',
        'RedoSuccesses',
        'SafImportSuccesses',
        'SafExportSuccesses',
        'LibraryOpenSuccesses',
        'NewDocumentSuccesses',
        'TabSwitchSuccesses',
        'SourceSaveSuccesses',
        'WorkspacePersistSuccesses',
        'TapToolEdits',
        'LnToolEdits',
        'SelectionEdits',
        'TimingEdits',
        'MetadataEdits',
        'ValidatorChecks')) {
        Assert-True ([int]$Report.Interaction.$property -gt 0) `
            "Device interaction probe did not complete: $property"
    }

    Assert-True ($null -ne $Report.Lifecycle -and [bool]$Report.Lifecycle.RecoveryFileWritten) `
        'Lifecycle recovery was not written during the device flow.'
    Assert-True ([int]$Report.Lifecycle.CurrentNoteCount -gt 0) `
        'Lifecycle report contains no current notes.'
    Assert-True (@($Report.Errors).Count -eq 0) 'device-verification.json contains errors.'
}

function Test-Device(
    [string] $DeviceDirectory,
    [string] $TemporaryDirectory,
    [string] $ApkSha256,
    [string] $PreinstallReportPath) {
    if (-not (Test-Path -LiteralPath $PreinstallReportPath -PathType Leaf)) {
        throw "Preinstall verification report is required before device verification: $PreinstallReportPath"
    }
    $preinstall = Get-Content -LiteralPath $PreinstallReportPath -Raw | ConvertFrom-Json
    Assert-TextEqual $preinstall.Status 'passed' 'Preinstall report status'
    Assert-TextEqual ([string]$preinstall.ApkSha256).ToUpperInvariant() $ApkSha256 'Preinstall/local APK SHA-256'
    Assert-TextEqual $preinstall.PackageId $PackageId 'Preinstall report package ID'
    Assert-TextEqual $preinstall.VersionName $ExpectedVersionName 'Preinstall report versionName'
    Assert-True ([int]$preinstall.VersionCode -eq $ExpectedVersionCode) 'Preinstall report versionCode mismatch.'
    Assert-True ([int]$preinstall.MinSdk -eq $ExpectedMinSdk) 'Preinstall report minSdk mismatch.'
    Assert-True ([int]$preinstall.TargetSdk -eq $ExpectedTargetSdk) 'Preinstall report targetSdk mismatch.'
    Assert-True (@($preinstall.ApkAbis).Count -eq 1 -and [string]$preinstall.ApkAbis[0] -ceq 'arm64-v8a') `
        'Preinstall report is not arm64-v8a-only.'
    $currentNativeSha256 = Get-Sha256 $nativeLibraryPath
    $currentNativeManifestSha256 = Get-Sha256 $nativeManifestPath
    Assert-TextEqual ([string]$preinstall.ClientSecuritySha256).ToUpperInvariant() `
        $currentNativeSha256 `
        'Preinstall/current ClientSecurity SO SHA-256'
    Assert-TextEqual ([string]$preinstall.NativeManifestSha256).ToUpperInvariant() `
        $currentNativeManifestSha256 `
        'Preinstall/current native manifest SHA-256'
    $currentNativeManifest = Get-Content -LiteralPath $nativeManifestPath -Raw | ConvertFrom-Json
    Assert-TextEqual ([string]$currentNativeManifest.output_sha256).ToUpperInvariant() `
        $currentNativeSha256 `
        'Current native manifest/SO SHA-256'

    New-Item -ItemType Directory -Path $DeviceDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $TemporaryDirectory -Force | Out-Null
    if (-not (Test-Path -LiteralPath $adbPath -PathType Leaf)) {
        throw "ADB executable is missing: $adbPath"
    }

    $adbVersion = Invoke-Adb `
        -ArgumentList @('version') `
        -LogPath (Join-Path $DeviceDirectory 'adb-version.txt') `
        -FailureMessage 'ADB version query failed.'
    Assert-True ($adbVersion.Text -match '(?m)^Android Debug Bridge version ') 'Unexpected ADB version output.'
    $deviceState = Invoke-Adb `
        -ArgumentList @('get-state') `
        -LogPath (Join-Path $DeviceDirectory 'adb-state.txt') `
        -FailureMessage 'ADB cannot reach the authorized tablet.'
    Assert-TextEqual $deviceState.Text.Trim() 'device' 'ADB device state'

    $packagePaths = Invoke-Adb `
        -ArgumentList @('shell', 'pm', 'path', $PackageId) `
        -LogPath (Join-Path $DeviceDirectory 'pm-path.txt') `
        -FailureMessage "Package $PackageId is not installed."
    $remotePackagePaths = @(
        foreach ($line in $packagePaths.Output) {
            $trimmed = $line.Trim()
            if ($trimmed.Length -ne 0) {
                if (-not $trimmed.StartsWith('package:', [StringComparison]::Ordinal)) {
                    throw "Unexpected pm path output: $trimmed"
                }
                $trimmed.Substring('package:'.Length)
            }
        }
    )
    Assert-True ($remotePackagePaths.Count -eq 1) `
        "Installed package must contain one base APK and no splits; found $($remotePackagePaths.Count) paths."
    $remoteBaseApk = $remotePackagePaths[0]
    Assert-True ($remoteBaseApk.EndsWith('/base.apk', [StringComparison]::Ordinal)) `
        "Installed package path is not base.apk: $remoteBaseApk"

    $pulledBaseApk = Join-Path $DeviceDirectory 'installed-base.apk'
    $pullBase = Invoke-Adb `
        -ArgumentList @('pull', $remoteBaseApk, $pulledBaseApk) `
        -LogPath (Join-Path $DeviceDirectory 'adb-pull-base.txt') `
        -FailureMessage 'ADB could not pull the installed base.apk.'
    Assert-True (Test-Path -LiteralPath $pulledBaseApk -PathType Leaf) 'ADB reported success but did not pull base.apk.'
    $installedApkSha256 = Get-Sha256 $pulledBaseApk
    Assert-TextEqual $installedApkSha256 $ApkSha256 'Installed/local signed APK SHA-256'

    $packageDump = Invoke-Adb `
        -ArgumentList @('shell', 'dumpsys', 'package', $PackageId) `
        -LogPath (Join-Path $DeviceDirectory 'dumpsys-package.txt') `
        -FailureMessage 'ADB could not inspect the installed package.'
    Assert-True ($packageDump.Text -match "(?m)^\s*versionCode=$ExpectedVersionCode(?:\s|$)") `
        'Installed package versionCode does not match the verified APK.'
    Assert-True ($packageDump.Text -match "(?m)^\s*versionName=$([Regex]::Escape($ExpectedVersionName))\s*$") `
        'Installed package versionName does not match the verified APK.'
    Assert-True ($packageDump.Text -match '(?m)^\s*primaryCpuAbi=arm64-v8a\s*$') `
        'Installed package primaryCpuAbi is not arm64-v8a.'

    $deviceAbi = Invoke-Adb `
        -ArgumentList @('shell', 'getprop', 'ro.product.cpu.abi') `
        -LogPath (Join-Path $DeviceDirectory 'device-primary-abi.txt') `
        -FailureMessage 'ADB could not read the device primary ABI.'
    Assert-TextEqual $deviceAbi.Text.Trim() 'arm64-v8a' 'Device primary ABI'
    $deviceAbiList = Invoke-Adb `
        -ArgumentList @('shell', 'getprop', 'ro.product.cpu.abilist') `
        -LogPath (Join-Path $DeviceDirectory 'device-abi-list.txt') `
        -FailureMessage 'ADB could not read the device ABI list.'
    $abis = @($deviceAbiList.Text.Trim().Split(',') | Where-Object { $_.Length -ne 0 })
    Assert-True (@($abis | Where-Object { $_ -ceq 'arm64-v8a' }).Count -eq 1) `
        'Device ABI list does not contain arm64-v8a exactly once.'

    $forceStop = Invoke-Adb `
        -ArgumentList @('shell', 'am', 'force-stop', $PackageId) `
        -LogPath (Join-Path $DeviceDirectory 'am-force-stop.txt') `
        -FailureMessage 'ADB could not stop the package before the clean launch probe.'
    $deviceClock = Invoke-Adb `
        -ArgumentList @('shell', 'date', '+%s') `
        -LogPath (Join-Path $DeviceDirectory 'device-start-epoch.txt') `
        -FailureMessage 'ADB could not record the pre-launch device epoch.'
    $deviceStartEpoch = 0L
    Assert-True ([long]::TryParse($deviceClock.Text.Trim(), [ref]$deviceStartEpoch)) `
        'Device epoch output is not an integer.'

    $component = "$PackageId/$ActivityName"
    $launch = Invoke-Adb `
        -ArgumentList @('shell', 'am', 'start', '-W', '-n', $component) `
        -LogPath (Join-Path $DeviceDirectory 'am-start-w.txt') `
        -FailureMessage 'ADB am start -W failed.'
    Assert-True ($launch.Text -match '(?m)^Status:\s*ok\s*$') 'am start -W did not report Status: ok.'
    $shortActivity = $ActivityName.Substring($PackageId.Length)
    Assert-True ($launch.Text.IndexOf("Activity: $PackageId/$shortActivity", [StringComparison]::Ordinal) -ge 0 -or
        $launch.Text.IndexOf("Activity: $component", [StringComparison]::Ordinal) -ge 0) `
        'am start -W did not identify the expected MainActivity.'

    $processId = 0
    $pidClock = [Diagnostics.Stopwatch]::StartNew()
    while ($pidClock.Elapsed.TotalSeconds -lt 10) {
        $pidResult = Invoke-Adb `
            -ArgumentList @('shell', 'pidof', '-s', $PackageId) `
            -LogPath (Join-Path $DeviceDirectory 'pidof.txt') `
            -FailureMessage 'pidof failed.' `
            -AllowFailure
        if ($pidResult.ExitCode -eq 0 -and
            [int]::TryParse($pidResult.Text.Trim(), [ref]$processId) -and
            $processId -gt 0) {
            break
        }
        Start-Sleep -Milliseconds 250
    }
    Assert-True ($processId -gt 0) 'The launched package has no live PID.'

    $activities = Invoke-Adb `
        -ArgumentList @('shell', 'dumpsys', 'activity', 'activities', $PackageId) `
        -LogPath (Join-Path $DeviceDirectory 'dumpsys-activities.txt') `
        -FailureMessage 'ADB could not inspect the resumed activity.'
    $resumedLines = @($activities.Output | Where-Object {
        $_ -match '(?i)(topResumedActivity|mResumedActivity|ResumedActivity)' -and
        $_.IndexOf($PackageId, [StringComparison]::Ordinal) -ge 0 -and
        ($_.IndexOf($ActivityName, [StringComparison]::Ordinal) -ge 0 -or
         $_.IndexOf($shortActivity, [StringComparison]::Ordinal) -ge 0)
    })
    Assert-True ($resumedLines.Count -ge 1) 'The expected MainActivity is not the resumed activity.'

    $externalAlias = "/sdcard/Android/data/$PackageId/files"
    $externalCacheAlias = "/sdcard/Android/data/$PackageId/cache"
    $expectedExternalSuffix = "/Android/data/$PackageId/files"
    $expectedExternalCacheSuffix = "/Android/data/$PackageId/cache"
    Assert-DeviceDirectory "$externalAlias/Library" (Join-Path $DeviceDirectory 'directory-library.txt')
    Assert-DeviceDirectory "$externalAlias/_editing" (Join-Path $DeviceDirectory 'directory-editing.txt')
    Assert-DeviceDirectory "$externalCacheAlias/_resources" (Join-Path $DeviceDirectory 'directory-resources.txt')

    $remoteVerification = "$externalAlias/_editing/device-verification.json"
    $localVerification = Join-Path $DeviceDirectory 'device-verification.json'
    $probeClock = [Diagnostics.Stopwatch]::StartNew()
    $deviceReport = $null
    while ($probeClock.Elapsed.TotalSeconds -lt $ProbeTimeoutSeconds) {
        $stat = Invoke-Adb `
            -ArgumentList @('shell', 'stat', '-c', '%Y', $remoteVerification) `
            -LogPath (Join-Path $DeviceDirectory 'device-verification-mtime.txt') `
            -FailureMessage 'device-verification.json is not ready.' `
            -AllowFailure
        $modifiedEpoch = 0L
        if ($stat.ExitCode -eq 0 -and
            [long]::TryParse($stat.Text.Trim(), [ref]$modifiedEpoch) -and
            $modifiedEpoch -ge $deviceStartEpoch) {
            $pullReport = Invoke-Adb `
                -ArgumentList @('pull', $remoteVerification, $localVerification) `
                -LogPath (Join-Path $DeviceDirectory 'adb-pull-device-verification.txt') `
                -FailureMessage 'ADB could not pull device-verification.json.' `
                -AllowFailure
            if ($pullReport.ExitCode -eq 0 -and
                (Test-Path -LiteralPath $localVerification -PathType Leaf)) {
                try {
                    $candidate = Get-Content -LiteralPath $localVerification -Raw | ConvertFrom-Json
                    if ([string]$candidate.Status -ceq 'failed') {
                        $deviceReport = $candidate
                        break
                    }
                    if ([string]$candidate.Status -ceq 'passed') {
                        $deviceReport = $candidate
                        break
                    }
                } catch {
                    # The app publishes atomically, but retry a transient pull/read race.
                }
            }
        }
        Start-Sleep -Milliseconds 500
    }
    Assert-True ($null -ne $deviceReport) `
        "The app did not publish a terminal device-verification.json within $ProbeTimeoutSeconds seconds."
    Test-DeviceReport $deviceReport $expectedExternalSuffix $expectedExternalCacheSuffix $processId

    $recoveryFile = "$externalAlias/_editing/lifecycle-recovery.mc"
    $recoveryStat = Invoke-Adb `
        -ArgumentList @('shell', 'test', '-s', $recoveryFile) `
        -LogPath (Join-Path $DeviceDirectory 'lifecycle-recovery-file.txt') `
        -FailureMessage 'Lifecycle recovery file is missing or empty.' `
        -AllowFailure
    Assert-True ($recoveryStat.ExitCode -eq 0) 'Lifecycle recovery file is missing or empty.'

    $remoteWorkspaceManifest = "$externalAlias/_editing/local-workspace/workspace.json"
    $localWorkspaceManifest = Join-Path $DeviceDirectory 'local-workspace.json'
    $workspacePull = Invoke-Adb `
        -ArgumentList @('pull', $remoteWorkspaceManifest, $localWorkspaceManifest) `
        -LogPath (Join-Path $DeviceDirectory 'adb-pull-local-workspace.txt') `
        -FailureMessage 'ADB could not pull the local workspace manifest.' `
        -AllowFailure
    Assert-True ($workspacePull.ExitCode -eq 0 -and
        (Test-Path -LiteralPath $localWorkspaceManifest -PathType Leaf)) `
        'Local workspace manifest is missing from PersistentEditing.'
    $workspaceManifest = Get-Content -LiteralPath $localWorkspaceManifest -Raw | ConvertFrom-Json
    Assert-True ([int]$workspaceManifest.SchemaVersion -eq 1) 'Local workspace manifest schema is invalid.'
    Assert-True (@($workspaceManifest.Tabs).Count -ge 2) `
        'The device flow did not retain at least two document tabs.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$workspaceManifest.ActiveTabId)) `
        'The local workspace manifest has no active tab.'
    foreach ($tab in @($workspaceManifest.Tabs)) {
        $tabId = [Guid]::Empty
        Assert-True ([Guid]::TryParse([string]$tab.Id, [ref]$tabId) -and $tabId -ne [Guid]::Empty) `
            'A local workspace tab has no stable ID.'
        Assert-True (-not [string]::IsNullOrWhiteSpace([string]$tab.SourceRelativePath) -and
            -not ([string]$tab.SourceRelativePath).StartsWith('..', [StringComparison]::Ordinal) -and
            -not [IO.Path]::IsPathRooted([string]$tab.SourceRelativePath)) `
            'A local workspace source is not safely relative to Library.'
        $workingFile = "$externalAlias/_editing/local-workspace/documents/$($tabId.ToString('N'))/working.mc"
        $workingStat = Invoke-Adb `
            -ArgumentList @('shell', 'test', '-s', $workingFile) `
            -LogPath (Join-Path $DeviceDirectory "working-$($tabId.ToString('N')).txt") `
            -FailureMessage 'A local workspace MC working copy is missing.' `
            -AllowFailure
        Assert-True ($workingStat.ExitCode -eq 0) `
            "Local workspace working copy is missing for tab $tabId."
    }

    $pidAfterProbe = Invoke-Adb `
        -ArgumentList @('shell', 'pidof', '-s', $PackageId) `
        -LogPath (Join-Path $DeviceDirectory 'pidof-after-probe.txt') `
        -FailureMessage 'The app process exited during device verification.'
    Assert-TextEqual $pidAfterProbe.Text.Trim() ([string]$processId) 'App PID after device probe'

    $reportPath = Join-Path $DeviceDirectory 'device-installation-verification.json'
    $deviceGateReport = [ordered]@{
        SchemaVersion = 1
        Status = 'passed'
        Stage = 'device'
        GeneratedAtUtc = [DateTime]::UtcNow.ToString('O')
        PackageId = $PackageId
        ActivityName = $ActivityName
        VersionName = $ExpectedVersionName
        VersionCode = $ExpectedVersionCode
        LocalSignedApkSha256 = $ApkSha256
        InstalledBaseApkSha256 = $installedApkSha256
        HashChainMatched = $true
        DevicePrimaryAbi = 'arm64-v8a'
        InstalledPackageAbi = 'arm64-v8a'
        ProcessId = $processId
        ActivityResumed = $true
        AppPrivateExternalDirectories = @('Library', '_editing', '_resources')
        DeviceVerificationStatus = [string]$deviceReport.Status
        DeviceVerificationGeneratedAtUtc = [string]$deviceReport.GeneratedAtUtc
        PreinstallReportSha256 = Get-Sha256 $PreinstallReportPath
        DeviceVerificationSha256 = Get-Sha256 $localVerification
        LocalWorkspaceManifestSha256 = Get-Sha256 $localWorkspaceManifest
        LocalWorkspaceTabCount = @($workspaceManifest.Tabs).Count
    }
    Write-JsonFile $reportPath $deviceGateReport
    return [PSCustomObject]@{
        ReportPath = $reportPath
        DeviceVerificationPath = $localVerification
        InstalledApkSha256 = $installedApkSha256
        ProcessId = $processId
    }
}

foreach ($requiredFile in @(
    $apkPath,
    $nativeManifestPath,
    $nativeLibraryPath,
    $publishedNativeVerifierPath)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Android APK verification input is missing: $requiredFile"
    }
}
if (-not (Test-Path -LiteralPath $androidSdkRoot -PathType Container)) {
    throw "Android SDK root is missing: $androidSdkRoot"
}
Assert-PathIsWithin $verificationRoot $requiredArtifactsRoot 'Android APK verification output'
New-Item -ItemType Directory -Path $verificationRoot -Force | Out-Null

$apkSha256 = Get-Sha256 $apkPath
$artifactKey = $apkSha256.ToLowerInvariant()
$apkArtifactRoot = Join-Path $verificationRoot $artifactKey
$preinstallDirectory = Join-Path $apkArtifactRoot 'preinstall'
$deviceDirectory = Join-Path $apkArtifactRoot 'device'
$environmentDirectory = Join-Path $apkArtifactRoot 'environment'
$temporaryDirectory = Join-Path $apkArtifactRoot 'temp'
foreach ($directory in @(
    $preinstallDirectory,
    $deviceDirectory,
    $environmentDirectory,
    $temporaryDirectory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$previousTmpDir = $env:TMPDIR
$previousAndroidUserHome = $env:ANDROID_USER_HOME
$previousJavaToolOptions = $env:JAVA_TOOL_OPTIONS
try {
    $env:TEMP = $temporaryDirectory
    $env:TMP = $temporaryDirectory
    $env:TMPDIR = $temporaryDirectory
    $env:ANDROID_USER_HOME = $environmentDirectory
    $javaTemp = $temporaryDirectory.Replace('\', '/')
    $existingJavaOptions = if ([string]::IsNullOrWhiteSpace($previousJavaToolOptions)) {
        ''
    } else {
        $previousJavaToolOptions.Trim() + ' '
    }
    $env:JAVA_TOOL_OPTIONS = $existingJavaOptions + "-Djava.io.tmpdir=$javaTemp"

    $buildTools = Resolve-AndroidBuildTools $androidSdkRoot
    $preinstallResult = $null
    if ($Stage -in @('Preinstall', 'All')) {
        $preinstallResult = Test-Preinstall `
            -PreinstallDirectory $preinstallDirectory `
            -TemporaryDirectory $temporaryDirectory `
            -ApkSha256 $apkSha256 `
            -BuildTools $buildTools
        Write-Output 'ANDROID_APK_PREINSTALL=OK'
        Write-Output "PACKAGE_ID=$PackageId"
        Write-Output "APK_SHA256=$apkSha256"
        Write-Output "CLIENT_SECURITY_SHA256=$($preinstallResult.NativeSha256)"
        Write-Output "PREINSTALL_REPORT=$($preinstallResult.ReportPath)"
    }

    if ($Stage -in @('Device', 'All')) {
        $preinstallReportPath = Join-Path $preinstallDirectory 'preinstall-verification.json'
        $deviceResult = Test-Device `
            -DeviceDirectory $deviceDirectory `
            -TemporaryDirectory $temporaryDirectory `
            -ApkSha256 $apkSha256 `
            -PreinstallReportPath $preinstallReportPath
        Write-Output 'ANDROID_APK_DEVICE=OK'
        Write-Output "INSTALLED_APK_SHA256=$($deviceResult.InstalledApkSha256)"
        Write-Output "PROCESS_ID=$($deviceResult.ProcessId)"
        Write-Output "DEVICE_VERIFICATION=$($deviceResult.DeviceVerificationPath)"
        Write-Output "DEVICE_REPORT=$($deviceResult.ReportPath)"
    }
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    $env:TMPDIR = $previousTmpDir
    $env:ANDROID_USER_HOME = $previousAndroidUserHome
    $env:JAVA_TOOL_OPTIONS = $previousJavaToolOptions
}
