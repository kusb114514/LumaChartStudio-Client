param(
    [Parameter(Mandatory = $true)][string]$SourceMc,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [string]$AudioPath = "",
    [string]$ImagePath = ""
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia mixed-archive fixture generation requires PowerShell Core on Windows."
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $item = Get-Item -LiteralPath $full
    [ordered]@{
        path = $full
        bytes = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$artifactsBoundary =
    [IO.Path]::GetFullPath((Join-Path $projectRoot "artifacts")).TrimEnd('\') + '\'
$codexTempBoundary =
    [IO.Path]::GetFullPath((Join-Path $projectRoot ".codex-temp")).TrimEnd('\') + '\'
$sourceFullPath = [IO.Path]::GetFullPath($SourceMc)
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = [IO.Path]::GetDirectoryName($outputFullPath)

Assert (Test-Path -LiteralPath $sourceFullPath -PathType Leaf) (
    "Source MC not found: $sourceFullPath")
Assert ([IO.Path]::GetExtension($sourceFullPath) -ieq ".mc") (
    "Source chart must be an MC file.")
Assert ([IO.Path]::GetExtension($outputFullPath) -ieq ".mcz") (
    "Output fixture must use the MCZ extension.")
Assert (($outputFullPath + '\').StartsWith(
        $artifactsBoundary,
        [StringComparison]::OrdinalIgnoreCase) -or
    ($outputFullPath + '\').StartsWith(
        $codexTempBoundary,
        [StringComparison]::OrdinalIgnoreCase)) (
    "Fixture output must stay under artifacts or .codex-temp.")
Assert (-not (Test-Path -LiteralPath $outputFullPath)) (
    "Fixture output already exists: $outputFullPath")

$validBytes = [IO.File]::ReadAllBytes($sourceFullPath)
$validJson = [Text.Encoding]::UTF8.GetString($validBytes) | ConvertFrom-Json
Assert ($null -ne $validJson.meta) "Source MC does not contain metadata."
$validJson.meta.mode = 4
$unsupportedText = $validJson | ConvertTo-Json -Depth 100 -Compress
$unsupportedBytes = [Text.UTF8Encoding]::new($false).GetBytes($unsupportedText)
$brokenBytes = [Text.UTF8Encoding]::new($false).GetBytes("{not-json")

$audioFullPath = ""
if (-not [string]::IsNullOrWhiteSpace($AudioPath)) {
    $audioFullPath = [IO.Path]::GetFullPath($AudioPath)
    Assert (Test-Path -LiteralPath $audioFullPath -PathType Leaf) (
        "Audio resource not found: $audioFullPath")
}
$imageFullPath = ""
if (-not [string]::IsNullOrWhiteSpace($ImagePath)) {
    $imageFullPath = [IO.Path]::GetFullPath($ImagePath)
    Assert (Test-Path -LiteralPath $imageFullPath -PathType Leaf) (
        "Image resource not found: $imageFullPath")
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [IO.File]::Open(
    $outputFullPath,
    [IO.FileMode]::CreateNew,
    [IO.FileAccess]::ReadWrite,
    [IO.FileShare]::None)
try {
    $archive = [IO.Compression.ZipArchive]::new(
        $stream,
        [IO.Compression.ZipArchiveMode]::Create,
        $true)
    try {
        $entries = @(
            [ordered]@{ name = "charts/resound-valid.mc"; bytes = $validBytes }
            [ordered]@{ name = "charts/unsupported-mode-4.mc"; bytes = $unsupportedBytes }
            [ordered]@{ name = "charts/broken.mc"; bytes = $brokenBytes }
        )
        if (-not [string]::IsNullOrEmpty($audioFullPath)) {
            $entries += [ordered]@{
                name = "charts/" + [IO.Path]::GetFileName($audioFullPath)
                bytes = [IO.File]::ReadAllBytes($audioFullPath)
            }
        }
        if (-not [string]::IsNullOrEmpty($imageFullPath)) {
            $entries += [ordered]@{
                name = "charts/" + [IO.Path]::GetFileName($imageFullPath)
                bytes = [IO.File]::ReadAllBytes($imageFullPath)
            }
        }
        foreach ($item in $entries) {
            $entry = $archive.CreateEntry(
                [string]$item.name,
                [IO.Compression.CompressionLevel]::Optimal)
            $entryStream = $entry.Open()
            try {
                $entryStream.Write([byte[]]$item.bytes)
            }
            finally {
                $entryStream.Dispose()
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}
finally {
    $stream.Dispose()
}

$manifest = [ordered]@{
    schema = "lumachart.windows.avalonia.mixed-archive-fixture.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    windowsOnly = $true
    sourceMc = File-Evidence $sourceFullPath
    audio = if ([string]::IsNullOrEmpty($audioFullPath)) {
        $null
    }
    else {
        File-Evidence $audioFullPath
    }
    image = if ([string]::IsNullOrEmpty($imageFullPath)) {
        $null
    }
    else {
        File-Evidence $imageFullPath
    }
    expected = [ordered]@{
        supportedCharts = 1
        unsupportedCharts = 1
        brokenCharts = 1
        openedTabs = 1
    }
    output = File-Evidence $outputFullPath
}
$manifestPath = $outputFullPath + ".fixture.json"
[IO.File]::WriteAllText(
    $manifestPath,
    ($manifest | ConvertTo-Json -Depth 10) + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false))

Write-Output "Mixed MCZ fixture: $outputFullPath"
Write-Output "Manifest: $manifestPath"
