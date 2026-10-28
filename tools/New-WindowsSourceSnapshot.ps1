[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts\windows-release-1.1.0-final-20260721-r2\source-snapshot'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryPath = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
$artifactsPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryPath 'artifacts')).TrimEnd([System.IO.Path]::DirectorySeparatorChar)

if (-not (Test-Path -LiteralPath $repositoryPath -PathType Container)) {
    throw "Repository root does not exist: $repositoryPath"
}

if (-not $outputPath.StartsWith($artifactsPath + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Output must be a descendant of the repository artifacts directory: $artifactsPath"
}

if (Test-Path -LiteralPath $outputPath) {
    if (-not $Force) {
        throw "Snapshot output already exists. Use -Force to replace this exact snapshot directory: $outputPath"
    }

    Get-ChildItem -LiteralPath $outputPath -Recurse -Force -File | ForEach-Object {
        $_.IsReadOnly = $false
    }
    Remove-Item -LiteralPath $outputPath -Recurse -Force
}

$includedDirectories = @(
    'LumaChart.App',
    'LumaChart.Application',
    'LumaChart.ClientSecurity.Native',
    'LumaChart.ClientSecurity.Specs',
    'LumaChart.Core',
    'LumaChart.Online',
    'LumaChart.Server',
    'LumaChart.Specs',
    'LumaChart.Storage.Abstractions',
    'deploy',
    'installer',
    'tools'
)

$includedRootFiles = @(
    'CLIENT_SECURITY_AUDIT.md',
    'LumaChartStudio.slnx',
    'NEXT-CHAT-PROMPT.md',
    'PROJECT-HANDOFF.md',
    'README.md',
    'THIRD-PARTY-NOTICES.md'
)

$excludedDirectoryNames = @(
    '.deploy',
    '.git',
    '.idea',
    '.vs',
    '.vscode',
    'Android',
    'iOS',
    'artifacts',
    'audit-artifacts',
    'bin',
    'obj',
    'release',
    'test-clients'
)

function Test-IsExcludedRelativePath {
    param([Parameter(Mandatory)][string]$RelativePath)

    $segments = $RelativePath -split '[\\/]'
    foreach ($segment in $segments[0..([Math]::Max(0, $segments.Count - 2))]) {
        if ($excludedDirectoryNames -contains $segment) {
            return $true
        }
    }

    $fileName = $segments[-1]
    if ($fileName -match '(?i)^PRIVATE-OPERATIONS.*\.md$' -or
        $fileName -match '(?i)^\.env(?:\..*)?$' -or
        $fileName -match '(?i)^client-profile\.txt$' -or
        $fileName -match '(?i)^online-session\.bin$' -or
        $fileName -match '(?i)^(credentials?|secrets?)(?:\..*)?$' -or
        $fileName -match '(?i)\.(?:pfx|p12|jks|keystore|pem|key)$') {
        return $true
    }

    # Mobile-only build/test inputs are intentionally not part of the Windows freeze.
    if ($fileName -match '(?i)(?:android|ios)') {
        return $true
    }

    return $false
}

function Get-SnapshotSourceFiles {
    $files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

    foreach ($directory in $includedDirectories) {
        $directoryPath = Join-Path $repositoryPath $directory
        if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) {
            throw "Required source directory is missing: $directoryPath"
        }

        Get-ChildItem -LiteralPath $directoryPath -Recurse -Force -File | ForEach-Object {
            $relativePath = [System.IO.Path]::GetRelativePath($repositoryPath, $_.FullName)
            if (-not (Test-IsExcludedRelativePath -RelativePath $relativePath)) {
                $files.Add($_)
            }
        }
    }

    foreach ($rootFile in $includedRootFiles) {
        $filePath = Join-Path $repositoryPath $rootFile
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            throw "Required root source/document file is missing: $filePath"
        }

        if (-not (Test-IsExcludedRelativePath -RelativePath $rootFile)) {
            $files.Add((Get-Item -LiteralPath $filePath))
        }
    }

    return @($files | Sort-Object { [System.IO.Path]::GetRelativePath($repositoryPath, $_.FullName) })
}

$sourceFiles = @(Get-SnapshotSourceFiles)
if ($sourceFiles.Count -eq 0) {
    throw 'The Windows source snapshot selection is empty.'
}

$filesPath = Join-Path $outputPath 'files'
New-Item -ItemType Directory -Path $filesPath -Force | Out-Null

$manifestEntries = [System.Collections.Generic.List[object]]::new()
foreach ($sourceFile in $sourceFiles) {
    if (($sourceFile.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Reparse-point files are not permitted in the snapshot: $($sourceFile.FullName)"
    }

    $relativePath = [System.IO.Path]::GetRelativePath($repositoryPath, $sourceFile.FullName)
    $destinationPath = Join-Path $filesPath $relativePath
    $destinationParent = Split-Path -Parent $destinationPath
    New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    [System.IO.File]::Copy($sourceFile.FullName, $destinationPath, $false)

    $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
    $destinationHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash
    if ($sourceHash -ne $destinationHash) {
        throw "Source/destination hash mismatch: $relativePath"
    }

    $manifestEntries.Add([pscustomobject]@{
        Path = $relativePath.Replace([System.IO.Path]::DirectorySeparatorChar, '/')
        Bytes = $sourceFile.Length
        Sha256 = $sourceHash
    })
}

# Detect additions/removals during the copy and re-check every source byte after the copy.
$sourceFilesAfterCopy = @(Get-SnapshotSourceFiles)
$sourcePathsBefore = @($sourceFiles | ForEach-Object { [System.IO.Path]::GetRelativePath($repositoryPath, $_.FullName) })
$sourcePathsAfter = @($sourceFilesAfterCopy | ForEach-Object { [System.IO.Path]::GetRelativePath($repositoryPath, $_.FullName) })
if ([string]::Join("`n", $sourcePathsBefore) -cne [string]::Join("`n", $sourcePathsAfter)) {
    throw 'The selected source file set changed while the snapshot was being created.'
}

foreach ($entry in $manifestEntries) {
    $currentSourceHash = (Get-FileHash -LiteralPath (Join-Path $repositoryPath $entry.Path) -Algorithm SHA256).Hash
    if ($currentSourceHash -ne $entry.Sha256) {
        throw "Source changed while the snapshot was being created: $($entry.Path)"
    }
}

$manifestLines = @($manifestEntries | ForEach-Object { '{0}  {1}' -f $_.Sha256, $_.Path })
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$manifestPath = Join-Path $outputPath 'SHA256SUMS'
[System.IO.File]::WriteAllText($manifestPath, ([string]::Join("`n", $manifestLines) + "`n"), $utf8NoBom)
$manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
$manifestHashPath = Join-Path $outputPath 'SHA256SUMS.sha256'
[System.IO.File]::WriteAllText($manifestHashPath, "$manifestHash  SHA256SUMS`n", $utf8NoBom)

$forbiddenFiles = @(Get-ChildItem -LiteralPath $outputPath -Recurse -Force -File | Where-Object {
    $_.Name -match '(?i)^PRIVATE-OPERATIONS.*\.md$' -or
    $_.Name -match '(?i)^\.env(?:\..*)?$' -or
    $_.Name -match '(?i)^client-profile\.txt$' -or
    $_.Name -match '(?i)^online-session\.bin$' -or
    $_.Name -match '(?i)^(credentials?|secrets?)(?:\..*)?$' -or
    $_.Name -match '(?i)\.(?:pfx|p12|jks|keystore|pem|key)$'
})
if ($forbiddenFiles.Count -ne 0) {
    throw "Forbidden private/session/profile/credential file found in snapshot: $($forbiddenFiles.FullName -join ', ')"
}

$privateKeyMarkers = @(
    ('-----BEGIN ' + 'PRIVATE KEY-----'),
    ('-----BEGIN RSA ' + 'PRIVATE KEY-----'),
    ('-----BEGIN EC ' + 'PRIVATE KEY-----'),
    ('-----BEGIN OPENSSH ' + 'PRIVATE KEY-----')
)
$privateKeyHits = [System.Collections.Generic.List[string]]::new()
Get-ChildItem -LiteralPath $filesPath -Recurse -Force -File | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    foreach ($marker in $privateKeyMarkers) {
        if ($text.Contains($marker, [System.StringComparison]::Ordinal)) {
            $privateKeyHits.Add([System.IO.Path]::GetRelativePath($outputPath, $_.FullName))
            break
        }
    }
}
if ($privateKeyHits.Count -ne 0) {
    throw "Private-key material marker found in snapshot: $($privateKeyHits -join ', ')"
}

$provenance = [ordered]@{
    SchemaVersion = 1
    ReleaseVersion = '1.1.0'
    CreatedUtc = [DateTimeOffset]::UtcNow.ToString('O')
    RepositoryRoot = $repositoryPath
    SnapshotFilesRoot = 'files'
    FileCount = $manifestEntries.Count
    TotalBytes = [long](($manifestEntries | Measure-Object -Property Bytes -Sum).Sum)
    Manifest = 'SHA256SUMS'
    ManifestSha256 = $manifestHash
    Selection = [ordered]@{
        IncludedDirectories = $includedDirectories
        IncludedRootFiles = $includedRootFiles
        Excluded = @(
            'Android/iOS source, scripts, and dedicated documents',
            '.deploy, artifacts, audit-artifacts, release, and test-clients',
            'all bin/obj and editor metadata directories',
            'PRIVATE-OPERATIONS*.md, .env*, profiles, session payloads, credentials, secrets, and private keys'
        )
    }
    Verification = [ordered]@{
        SourceDestinationSha256Matched = $true
        SourceSetStableDuringCopy = $true
        SourceContentStableDuringCopy = $true
        ForbiddenFileNameHits = 0
        PrivateKeyMarkerHits = 0
    }
}
$provenancePath = Join-Path $outputPath 'snapshot-provenance.json'
[System.IO.File]::WriteAllText(
    $provenancePath,
    (($provenance | ConvertTo-Json -Depth 8) + "`n"),
    $utf8NoBom)

Get-ChildItem -LiteralPath $outputPath -Recurse -Force -File | ForEach-Object {
    $_.IsReadOnly = $true
}

Write-Output "SNAPSHOT_PATH=$outputPath"
Write-Output "FILE_COUNT=$($manifestEntries.Count)"
Write-Output "TOTAL_BYTES=$($provenance.TotalBytes)"
Write-Output "MANIFEST_SHA256=$manifestHash"
Write-Output 'FORBIDDEN_FILE_HITS=0'
Write-Output 'PRIVATE_KEY_MARKER_HITS=0'
Write-Output 'READ_ONLY=true'
