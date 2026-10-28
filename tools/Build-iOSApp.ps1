<#
.SYNOPSIS
    Builds the unsigned iOS payload on the macOS VM and retrieves it as an .ipa.

.DESCRIPTION
    The build VM deliberately holds no Apple account, certificate or
    provisioning profile, so it can only ever produce an unsigned app. The user
    self-signs the resulting .ipa on their own machine and installs it on their
    own device.

    The .ipa is the standard `Payload/<App>.app` zip, which Sideloadly, AltStore
    and Xcode all accept and re-sign.

    Source is synced from Windows first; the macOS tree is a build mirror and is
    never edited in place.

.PARAMETER BundleId
    Overrides the bundle identifier. Free Apple IDs usually need this, because a
    personal team cannot claim cc.lumachart.studio.
#>
[CmdletBinding()]
param(
    [string]$Configuration = 'Release',
    [string]$BundleId = '',
    [string]$SshConfig = 'D:\Docker-OSX\state\ssh\config',
    [string]$SshAlias = 'lumachart-macos',
    [string]$RemoteRoot = '/Users/ddtt0/Developer/LumaChartStudio',
    [string]$OutputDirectory = '',
    [switch]$SkipSync,
    # Restores only from the VM's pinned package cache. Use when the VM has no
    # route to nuget.org — a proxy on the Windows host is enough to cause that —
    # and no package versions have changed.
    [switch]$Offline
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

if (-not $SkipSync) {
    Write-Host '== Syncing source to the macOS build mirror =='
    & pwsh -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $PSScriptRoot 'Sync-MacSource.ps1') -Delete | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Source sync failed.' }
}

Write-Host '== Building unsigned iOS payload =='
$remoteScript = "$RemoteRoot/tools/build-ios-remote.sh"
$offlineArgument = if ($Offline) { 'offline' } else { '' }
$output = & ssh -F $SshConfig $SshAlias "bash '$remoteScript' '$Configuration' '$BundleId' '$offlineArgument'" 2>&1
$output | ForEach-Object { Write-Host $_ }

if (-not ($output -match 'IOS_BUILD=OK')) { throw 'The iOS build did not complete.' }

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot 'artifacts\ios'
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$remoteIpa = ([regex]::Match(($output -join "`n"), 'IOS_IPA=(.+)')).Groups[1].Value.Trim()
$localIpa = Join-Path $OutputDirectory 'LumaChartStudio-unsigned.ipa'
Write-Host "== Retrieving $remoteIpa =="
& scp -F $SshConfig "${SshAlias}:$remoteIpa" $localIpa
if ($LASTEXITCODE -ne 0) { throw 'Retrieving the .ipa failed.' }

$hash = (Get-FileHash -Algorithm SHA256 $localIpa).Hash
$bytes = (Get-Item $localIpa).Length
Write-Host ''
Write-Host "IPA    : $localIpa"
Write-Host "BYTES  : $bytes"
Write-Host "SHA256 : $hash"
