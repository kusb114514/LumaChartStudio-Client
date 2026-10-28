<#
.SYNOPSIS
    One-way source sync from the Windows source of truth to the macOS build VM.

.DESCRIPTION
    Windows `D:\Project\LumaChartStudio` is the only place source is edited. The
    macOS side is a build mirror, so this script never copies anything back.

    Windows has no rsync, so the selected files are streamed as a tar over the
    existing SSH alias.

    What is sent is an allow-list, not the working tree minus a few names: the
    files git knows as source -- tracked files, plus untracked files that are not
    ignored, which covers new source that has not been committed yet. The
    earlier version tarred the whole tree and excluded exactly one credentials
    file by name, so agent session folders (.claude/), local caches (.codex-*)
    and any other *.local.md or PRIVATE-OPERATIONS variant were copied to a VM
    that is documented as an untrusted isolated environment. The deny list below
    still applies on top of the allow-list, as a second line of defence and to
    leave out tracked trees the Mac build never uses.

    -Delete removes the remote tree before unpacking. The remote path is checked
    first: it must be an absolute path at least three levels deep, made of plain
    characters, so '/', '~', '/Users' or a home directory can never be the
    target of that rm -rf.
#>
[CmdletBinding()]
param(
    [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$SshConfig = 'D:\Docker-OSX\state\ssh\config',
    [string]$SshAlias = 'lumachart-macos',
    [string]$RemoteRoot = '/Users/ddtt0/Developer/LumaChartStudio',
    [switch]$Delete
)

$ErrorActionPreference = 'Stop'

# Path segments that exclude everything beneath them, at any depth.
$excludedDirectories = @(
    'bin', 'obj', 'artifacts', 'demo', 'release', 'test-clients', 'audit-artifacts',
    'deploy', '.deploy', '.temp', 'installer', 'TestFixtures',
    '.claude', '.dotnet-cli-home', '.git', '.vs'
)
# Wildcards matched against every path segment, the file name included.
$excludedSegmentPatterns = @('.codex-*')
# Wildcards matched against the file name.
$excludedFilePatterns = @('PRIVATE-OPERATIONS*', '*.local.md')

function Test-ExcludedPath([string] $RelativePath) {
    $segments = $RelativePath.Split('/')
    for ($index = 0; $index -lt $segments.Count; $index++) {
        $segment = $segments[$index]
        if ($index -lt $segments.Count - 1 -and $excludedDirectories -contains $segment) { return $true }
        foreach ($pattern in $excludedSegmentPatterns) {
            if ($segment -like $pattern) { return $true }
        }
    }
    $fileName = $segments[$segments.Count - 1]
    foreach ($pattern in $excludedFilePatterns) {
        if ($fileName -like $pattern) { return $true }
    }
    return $false
}

function Resolve-SafeRemoteRoot([string] $Path) {
    $candidate = if ($null -eq $Path) { '' } else { $Path.Trim() }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        throw 'RemoteRoot is empty.'
    }
    # The path is embedded in single quotes for the remote shell, inside a
    # double-quoted local bash command, so quotes, $, backticks and backslashes
    # are refused rather than escaped.
    if ($candidate -notmatch '^/[A-Za-z0-9._@+ /-]+$') {
        throw "RemoteRoot must be an absolute POSIX path of plain characters: '$Path'."
    }
    $segments = @($candidate.Split('/', [StringSplitOptions]::RemoveEmptyEntries))
    if (@($segments | Where-Object { $_ -eq '.' -or $_ -eq '..' -or $_.Trim().Length -eq 0 }).Count -gt 0) {
        throw "RemoteRoot must not contain empty, '.' or '..' segments: '$Path'."
    }
    if ($segments.Count -lt 3) {
        throw "RemoteRoot is too close to the filesystem root to be a sync target: '$Path'."
    }
    return '/' + ($segments -join '/')
}

$RemoteRoot = Resolve-SafeRemoteRoot $RemoteRoot
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)

Write-Host "Source : $SourceRoot"
Write-Host "Target : ${SshAlias}:$RemoteRoot"

# `tar` from Git Bash reads the listed files; the remote side unpacks in place.
# Both ends stream, so no multi-gigabyte intermediate archive is written.
$remoteCommand = if ($Delete) {
    "rm -rf '$RemoteRoot' && mkdir -p '$RemoteRoot' && tar -xf - -C '$RemoteRoot'"
} else {
    "mkdir -p '$RemoteRoot' && tar -xf - -C '$RemoteRoot'"
}

$listPath = Join-Path ([IO.Path]::GetTempPath()) (
    "lumachart-mac-sync-$([Guid]::NewGuid().ToString('N')).lst")
Push-Location $SourceRoot
try {
    # git writes the names as UTF-8; decode them that way whatever the console.
    $previousOutputEncoding = $null
    try {
        $previousOutputEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    }
    catch {
        $previousOutputEncoding = $null
    }
    try {
        $listing = & git -C $SourceRoot ls-files -z --cached --others --exclude-standard
        if ($LASTEXITCODE -ne 0) { throw "git ls-files failed with exit code $LASTEXITCODE." }
    }
    finally {
        if ($null -ne $previousOutputEncoding) { [Console]::OutputEncoding = $previousOutputEncoding }
    }

    $names = ([string]::Join("`n", @($listing))).Split(
        [char]0,
        [StringSplitOptions]::RemoveEmptyEntries)
    # Deleted-but-still-tracked files are dropped by the existence check, which
    # tar would otherwise fail on.
    $files = @($names | Where-Object {
        -not (Test-ExcludedPath $_) -and
        (Test-Path -LiteralPath (Join-Path $SourceRoot $_) -PathType Leaf)
    })
    if ($files.Count -eq 0) { throw 'No source files were selected for the sync.' }
    Write-Host "Files  : $($files.Count)"
    [IO.File]::WriteAllText(
        $listPath,
        [string]::Join([string][char]0, $files) + [char]0,
        [Text.UTF8Encoding]::new($false))

    # Must be Git Bash, not WSL bash: WSL has no drive-letter view of the
    # source tree, so a WSL bash silently fails to cd into it.
    $bash = @(
        'D:\Git\usr\bin\bash.exe',
        'D:\Git\bin\bash.exe',
        'C:\Program Files\Git\bin\bash.exe',
        'C:\Program Files\Git\usr\bin\bash.exe'
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $bash) { throw 'Git Bash was not found; it is required for the tar stream.' }

    # Git Bash accepts drive-letter paths in forward-slash form, which avoids
    # depending on how this particular install maps /d or /mnt/d.
    $bashSource = $SourceRoot -replace '\\', '/'
    $bashSshConfig = $SshConfig -replace '\\', '/'
    $bashList = $listPath -replace '\\', '/'

    # --no-recursion: only the listed files, never a directory's other contents.
    & $bash -lc "cd '$bashSource' && tar -cf - --null --no-recursion -T '$bashList' | ssh -F '$bashSshConfig' $SshAlias `"$remoteCommand`""
    if ($LASTEXITCODE -ne 0) { throw "Source sync failed with exit code $LASTEXITCODE." }
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $listPath -Force -ErrorAction SilentlyContinue
}

Write-Host 'Sync complete. Remote tree:'
& ssh -F $SshConfig $SshAlias "ls -1 '$RemoteRoot'"
