[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectPrefix = $projectRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$testRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'artifacts\chart-library-link-test'))
$assemblyPath = Join-Path $projectRoot "LumaChart.App\bin\$Configuration\net8.0-windows\LumaChart.App.dll"

function Assert-ProjectChild([string] $Path) {
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify a path outside the project: $fullPath"
    }
    return $fullPath
}

function Remove-TestItem([string] $Path, [switch] $Recurse) {
    $verifiedPath = Assert-ProjectChild $Path
    $item = Get-Item -LiteralPath $verifiedPath -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return }
    if ($Recurse) {
        Remove-Item -LiteralPath $verifiedPath -Recurse -Force
    }
    else {
        Remove-Item -LiteralPath $verifiedPath -Force
    }
}

function Test-PathsEqual([string] $Left, [string] $Right) {
    $leftFull = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($Left))
    $rightFull = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($Right))
    return $leftFull.Equals($rightFull, [StringComparison]::OrdinalIgnoreCase)
}

if (-not (Test-Path -LiteralPath $assemblyPath -PathType Leaf)) {
    throw "Build LumaChart.App first; assembly not found: $assemblyPath"
}

Remove-TestItem $testRoot -Recurse
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

$targetRoot = Join-Path $testRoot 'target'
$outsideRoot = Join-Path $testRoot 'outside'
$selectedRoot = Join-Path $testRoot 'selected-link'
$descendantLink = Join-Path $targetRoot 'escaped-link'
$brokenTarget = Join-Path $testRoot 'broken-target'
$brokenRoot = Join-Path $testRoot 'broken-link'

try {
    New-Item -ItemType Directory -Path $targetRoot, $outsideRoot, $brokenTarget -Force | Out-Null
    $fixture = @"
osu file format v14

[General]
Mode:3
AudioFilename:test.ogg

[Metadata]
Title:Link Root Test
Artist:LumaChart
Creator:Test
Version:Inside

[Difficulty]
CircleSize:4

[Events]
"@
    [IO.File]::WriteAllText((Join-Path $targetRoot 'inside.osu'), $fixture)
    [IO.File]::WriteAllText((Join-Path $outsideRoot 'must-not-scan.osu'), $fixture.Replace('Inside', 'Outside'))

    New-Item -ItemType Junction -Path $selectedRoot -Target $targetRoot | Out-Null
    New-Item -ItemType Junction -Path $descendantLink -Target $outsideRoot | Out-Null
    New-Item -ItemType Junction -Path $brokenRoot -Target $brokenTarget | Out-Null
    Remove-TestItem $brokenTarget -Recurse

    $assembly = [Reflection.Assembly]::LoadFrom($assemblyPath)
    $serviceType = $assembly.GetType('LumaChart.App.ProjectManagement.ChartLibraryService', $true)
    $preferencesType = $assembly.GetType('LumaChart.App.ProjectManagement.WorkspacePreferencesStore', $true)
    $resolveMethod = $serviceType.GetMethod('ResolveRoot', [Reflection.BindingFlags]'Public, Static')
    $scanMethod = $serviceType.GetMethod('ScanAsync', [Reflection.BindingFlags]'Public, Static')
    $groupMethod = $serviceType.GetMethod('GroupByFolder', [Reflection.BindingFlags]'Public, Static')
    $ensureMethod = $preferencesType.GetMethod('EnsureWorkspace', [Reflection.BindingFlags]'Public, Static')

    $resolveArguments = [object[]]::new(1)
    $resolveArguments[0] = [string]$selectedRoot
    $resolution = $resolveMethod.Invoke($null, $resolveArguments)
    if (-not $resolution.FollowedLink -or -not (Test-PathsEqual $resolution.ResolvedRoot $targetRoot)) {
        throw "Linked root did not resolve to its final target: $($resolution.ResolvedRoot)"
    }

    $scanArguments = [object[]]::new(3)
    $scanArguments[0] = [string]$selectedRoot
    $scanArguments[1] = $null
    $scanArguments[2] = [Threading.CancellationToken]::None
    $scanTask = $scanMethod.Invoke($null, $scanArguments)
    $scanResults = $scanTask.GetAwaiter().GetResult()
    $entries = @($scanResults)
    if ($entries.Count -ne 1) {
        throw "Expected exactly one in-root chart; descendant junction escape produced $($entries.Count) results."
    }
    if (-not (Test-PathsEqual $entries[0].ChartPath (Join-Path $targetRoot 'inside.osu'))) {
        throw "Scanner returned an unexpected chart path: $($entries[0].ChartPath)"
    }

    $groupArguments = [object[]]::new(2)
    $groupArguments[0] = $scanResults
    $groupArguments[1] = [string]$selectedRoot
    $groups = @($groupMethod.Invoke($null, $groupArguments))
    if ($groups.Count -ne 1) {
        throw "Expected one library folder after grouping; got $($groups.Count)."
    }

    $brokenWasRejected = $false
    try
    {
        $brokenArguments = [object[]]::new(1)
        $brokenArguments[0] = [string]$brokenRoot
        $null = $resolveMethod.Invoke($null, $brokenArguments)
    }
    catch
    {
        $failure = $_.Exception
        while ($null -ne $failure.InnerException) { $failure = $failure.InnerException }
        $message = $failure.Message
        $brokenWasRejected = $message -match '断开|不存在|无法访问'
    }
    if (-not $brokenWasRejected) {
        throw 'A broken linked root was not rejected with an explicit diagnostic.'
    }

    $workspaceGuardRejected = $false
    try
    {
        $ensureArguments = [object[]]::new(1)
        $ensureArguments[0] = [string]$brokenRoot
        $null = $ensureMethod.Invoke($null, $ensureArguments)
    }
    catch
    {
        $failure = $_.Exception
        while ($null -ne $failure.InnerException) { $failure = $failure.InnerException }
        $workspaceGuardRejected = $failure.Message -match '目录链接|断开|无法访问'
    }
    if (-not $workspaceGuardRejected) {
        throw 'Workspace initialization did not preserve an explicit broken-link diagnostic.'
    }

    [pscustomobject]@{
        Success = $true
        RequestedRoot = $resolution.RequestedRoot
        ResolvedRoot = $resolution.ResolvedRoot
        ChartCount = $entries.Count
        DescendantLinkSkipped = $true
        BrokenLinkRejected = $true
        WorkspaceGuardRejected = $true
    } | ConvertTo-Json
}
finally {
    # Remove link objects before recursively deleting the controlled fixture tree.
    Remove-TestItem $descendantLink
    Remove-TestItem $selectedRoot
    Remove-TestItem $brokenRoot
    Remove-TestItem $testRoot -Recurse
}
