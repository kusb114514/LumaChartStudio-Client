# Publishes two identical Windows clients, test-clients\Client-A and Client-B,
# each marked with a client-profile.txt. The Avalonia client reads that file at
# startup (AvaloniaAppPaths.ConfigureSiblingClientProfileEnvironment) and gives
# each copy its own data roots and single-instance scope, so both can run side
# by side against one server. This used to publish the retired WPF
# LumaChart.App, whose project no longer exists.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectFile = Join-Path $projectRoot 'LumaChart.Avalonia\LumaChart.Avalonia.csproj'
$clientExecutable = 'LumaChart.Avalonia.exe'
$stagingRoot = Join-Path $projectRoot 'artifacts\dual-client-staging'
$buildArtifactsRoot = Join-Path $projectRoot 'artifacts\dual-client-build'
$outputRoot = Join-Path $projectRoot 'test-clients'
$projectPrefix = $projectRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar

function Assert-ProjectChild([string] $Path) {
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify a path outside the project: $fullPath"
    }
    return $fullPath
}

function Remove-ProjectDirectory([string] $Path) {
    $verifiedPath = Assert-ProjectChild $Path
    if (Test-Path -LiteralPath $verifiedPath) {
        Remove-Item -LiteralPath $verifiedPath -Recurse -Force
    }
}

function Get-CanonicalPayloadManifestLines([string] $Root) {
    $fullRoot = [IO.Path]::GetFullPath($Root)
    [string[]] $relativePaths = @(
        Get-ChildItem -LiteralPath $fullRoot -Recurse -File | ForEach-Object {
            [IO.Path]::GetRelativePath($fullRoot, $_.FullName).Replace([char]'\', [char]'/')
        } | Where-Object {
            # These two files describe/identify a generated client rather than the shared
            # application payload. The profile intentionally differs between Client-A/B.
            $_ -ne 'client-profile.txt' -and $_ -ne 'payload-manifest.sha256'
        }
    )
    [Array]::Sort($relativePaths, [StringComparer]::Ordinal)

    foreach ($relativePath in $relativePaths) {
        $nativeRelativePath = $relativePath.Replace([char]'/', [IO.Path]::DirectorySeparatorChar)
        $file = Get-Item -LiteralPath (Join-Path $fullRoot $nativeRelativePath)
        $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
        $length = $file.Length.ToString([Globalization.CultureInfo]::InvariantCulture)
        "$($hash.Hash)  $length  $relativePath"
    }
}

Remove-ProjectDirectory $stagingRoot
Remove-ProjectDirectory $buildArtifactsRoot
Remove-ProjectDirectory $outputRoot
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

dotnet publish $projectFile `
    -c Release `
    -r win-x64 `
    --self-contained true `
    --artifacts-path $buildArtifactsRoot `
    -o $stagingRoot
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE."
}

$utf8NoBom = New-Object Text.UTF8Encoding($false)
$requiredPayload = @(
    $clientExecutable,
    'LumaChart.Avalonia.dll',
    'LumaChart.Core.dll',
    'LumaChart.Avalonia.deps.json',
    'LumaChart.Avalonia.runtimeconfig.json'
)
foreach ($relativePath in $requiredPayload) {
    if (-not (Test-Path -LiteralPath (Join-Path $stagingRoot $relativePath) -PathType Leaf)) {
        throw "Published payload is missing required file: $relativePath"
    }
}

$projectXml = [xml](Get-Content -LiteralPath $projectFile -Raw)
$expectedVersion = [string](@($projectXml.Project.PropertyGroup |
    ForEach-Object { $_.Version } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($expectedVersion)) {
    throw 'LumaChart.Avalonia.csproj does not declare Version.'
}
$expectedVersion = $expectedVersion.Trim()
$publishedVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo(
    (Join-Path $stagingRoot $clientExecutable)).ProductVersion
if (-not $publishedVersion.StartsWith($expectedVersion, [StringComparison]::Ordinal)) {
    throw "Published client version mismatch. Expected '$expectedVersion'; actual '$publishedVersion'."
}

$manifestLines = @(Get-CanonicalPayloadManifestLines $stagingRoot)
if ($manifestLines.Count -eq 0) {
    throw 'Published payload manifest is empty.'
}
$manifestPath = Join-Path $stagingRoot 'payload-manifest.sha256'
$manifestText = [string]::Join("`n", $manifestLines) + "`n"
[IO.File]::WriteAllText($manifestPath, $manifestText, $utf8NoBom)
$payloadIdentity = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
$corePayloadHash = (Get-FileHash -LiteralPath (Join-Path $stagingRoot 'LumaChart.Core.dll') -Algorithm SHA256).Hash

$clients = @(
    @{ Folder = 'Client-A'; Profile = 'Test-Client-A' },
    @{ Folder = 'Client-B'; Profile = 'Test-Client-B' }
)
foreach ($client in $clients) {
    $clientRoot = Join-Path $outputRoot $client.Folder
    New-Item -ItemType Directory -Path $clientRoot -Force | Out-Null
    Copy-Item -Path (Join-Path $stagingRoot '*') -Destination $clientRoot -Recurse -Force
    [IO.File]::WriteAllText(
        (Join-Path $clientRoot 'client-profile.txt'),
        $client.Profile + [Environment]::NewLine,
        $utf8NoBom)
}

Remove-ProjectDirectory $stagingRoot
Remove-ProjectDirectory $buildArtifactsRoot

foreach ($client in $clients) {
    $clientRoot = Join-Path $outputRoot $client.Folder
    $executable = Get-Item -LiteralPath (Join-Path $clientRoot $clientExecutable)
    $clientManifest = Get-Item -LiteralPath (Join-Path $clientRoot 'payload-manifest.sha256')
    $clientIdentity = (Get-FileHash -LiteralPath $clientManifest.FullName -Algorithm SHA256).Hash
    if (-not $clientIdentity.Equals($payloadIdentity, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$($client.Folder) payload manifest differs from the published staging payload."
    }
    $actualManifestLines = @(Get-CanonicalPayloadManifestLines $clientRoot)
    $actualManifestText = [string]::Join("`n", $actualManifestLines) + "`n"
    if (-not $actualManifestText.Equals($manifestText, [StringComparison]::Ordinal)) {
        throw "$($client.Folder) files do not match the canonical payload manifest."
    }
    Write-Output "$($client.Folder)=$($executable.FullName)"
    Write-Output "$($client.Folder)-Profile=$($client.Profile)"
    Write-Output "$($client.Folder)-Payload-Manifest=$($clientManifest.FullName)"
    Write-Output "$($client.Folder)-Payload-Files=$($manifestLines.Count)"
    Write-Output "$($client.Folder)-Core-SHA256=$corePayloadHash"
    Write-Output "$($client.Folder)-Payload-SHA256=$clientIdentity"
    Write-Output "$($client.Folder)-Version=$publishedVersion"
}
