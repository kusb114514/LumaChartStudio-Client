[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $ReleaseRoot,
    [Parameter(Mandatory = $true)] [string] $InstallerName,
    [string] $InitialProcessIds = ''
)

$ErrorActionPreference = 'Stop'
$separator = [IO.Path]::DirectorySeparatorChar
$alternateSeparator = [IO.Path]::AltDirectorySeparatorChar
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd($separator, $alternateSeparator)
$releaseRoot = [IO.Path]::GetFullPath($ReleaseRoot).TrimEnd($separator, $alternateSeparator)
$expectedReleaseRoot = Join-Path $projectRoot 'release'
$releasePrefix = $releaseRoot + $separator
$logRoot = Join-Path $projectRoot 'artifacts'
$logPath = Join-Path $logRoot 'last-installer-release.log'

# This script deletes everything in the release directory except the installer,
# so the directory must be exactly <project>\release. The old check only asked
# for "somewhere under the project": the project root itself, passed with a
# trailing backslash, satisfied it, and a file there named like -InstallerName
# was then enough to delete the rest of the project, .git included.
if ([string]::IsNullOrWhiteSpace($InstallerName) -or
    $InstallerName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
    $InstallerName -in @('.', '..')) {
    throw "InstallerName must be a plain file name: '$InstallerName'"
}
if (-not $releaseRoot.Equals($expectedReleaseRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean anything but $expectedReleaseRoot (got $releaseRoot)."
}
if (-not (Test-Path -LiteralPath $releaseRoot -PathType Container) -or
    (Get-Item -LiteralPath $releaseRoot -Force).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
    throw "The release directory is missing or is a link: $releaseRoot"
}

function Get-RunningReleaseClients {
    return @(
        Get-Process -Name 'LumaChart.App' -ErrorAction SilentlyContinue | Where-Object {
            try {
                $_.Path -and [IO.Path]::GetFullPath($_.Path).StartsWith(
                    $releasePrefix,
                    [StringComparison]::OrdinalIgnoreCase)
            }
            catch { $false }
        }
    )
}

try {
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    Set-Content -LiteralPath $logPath -Encoding utf8NoBOM -Value @(
        "WAITING $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "CLIENT_IDS $InitialProcessIds"
    )

    while ((Get-RunningReleaseClients).Count -gt 0) {
        Start-Sleep -Milliseconds 750
    }

    $installerPath = Join-Path $releaseRoot $InstallerName
    if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
        throw "Missing installer: $installerPath"
    }

    Get-ChildItem -LiteralPath $releaseRoot -Force | Where-Object {
        -not $_.PSIsContainer -and $_.Name -eq $InstallerName
    } | Out-Null

    Get-ChildItem -LiteralPath $releaseRoot -Force | Where-Object {
        $_.Name -ne $InstallerName
    } | ForEach-Object {
        # Checked again for each entry right before it goes: only a direct
        # child of the release directory is ever removed.
        $target = [IO.Path]::GetFullPath($_.FullName)
        $parent = [IO.Path]::GetDirectoryName($target.TrimEnd($separator, $alternateSeparator))
        if ($null -eq $parent -or
            -not $parent.Equals($releaseRoot, [StringComparison]::OrdinalIgnoreCase) -or
            -not $target.StartsWith($releasePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to delete an entry outside $releaseRoot`: $target"
        }
        Remove-Item -LiteralPath $target -Recurse -Force
    }

    Set-Content -LiteralPath $logPath -Encoding utf8NoBOM -Value "COMPLETE $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}
catch {
    Set-Content -LiteralPath $logPath -Encoding utf8NoBOM -Value @(
        "FAILED $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        $_.Exception.Message
    )
}
