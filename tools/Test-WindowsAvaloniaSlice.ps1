param(
    [string]$ArtifactRoot = "D:\Project\LumaChartStudio\artifacts\windows-avalonia-export-edge-slice-20260723-r1"
)

if ($PSVersionTable.PSEdition -ne "Core") {
    throw "Windows Avalonia verification requires PowerShell Core. Run this script with pwsh."
}
if (-not $IsWindows) {
    throw "Windows Avalonia verification is Windows-only."
}

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$artifactFullPath = [System.IO.Path]::GetFullPath($ArtifactRoot)
$artifactBoundary = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "artifacts")).TrimEnd('\') + '\'
if (-not $artifactFullPath.StartsWith($artifactBoundary, [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must stay under $artifactBoundary"
}
$formalKeySoundR2Root = [System.IO.Path]::GetFullPath((Join-Path $projectRoot `
    "artifacts\windows-avalonia-key-sound-slice-20260722-r2"))
$formalKeySoundR2Boundary = $formalKeySoundR2Root.TrimEnd('\') + '\'
if ($artifactFullPath.Equals($formalKeySoundR2Root, [StringComparison]::OrdinalIgnoreCase) -or
    $artifactFullPath.StartsWith($formalKeySoundR2Boundary, [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must not reuse or nest under the formal Key-sound r2 authority: $formalKeySoundR2Root"
}
$formalDisplayScaleR2Root = [System.IO.Path]::GetFullPath((Join-Path $projectRoot `
    "artifacts\windows-avalonia-display-scale-slice-20260722-r2"))
$formalDisplayScaleR2Boundary = $formalDisplayScaleR2Root.TrimEnd('\') + '\'
if ($artifactFullPath.Equals($formalDisplayScaleR2Root, [StringComparison]::OrdinalIgnoreCase) -or
    $artifactFullPath.StartsWith($formalDisplayScaleR2Boundary, [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must not reuse or nest under the formal display-scale r2 authority: $formalDisplayScaleR2Root"
}
$formalLibrarySearchR1Root = [System.IO.Path]::GetFullPath((Join-Path $projectRoot `
    "artifacts\windows-avalonia-library-search-slice-20260722-r1"))
$formalLibrarySearchR1Boundary = $formalLibrarySearchR1Root.TrimEnd('\') + '\'
if ($artifactFullPath.Equals($formalLibrarySearchR1Root, [StringComparison]::OrdinalIgnoreCase) -or
    $artifactFullPath.StartsWith($formalLibrarySearchR1Boundary, [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must not reuse or nest under the formal library-search r1 authority: $formalLibrarySearchR1Root"
}
$formalAudioPanelsR3Root = [System.IO.Path]::GetFullPath((Join-Path $projectRoot `
    "artifacts\windows-avalonia-audio-panels-slice-20260722-r3"))
$formalAudioPanelsR3Boundary = $formalAudioPanelsR3Root.TrimEnd('\') + '\'
if ($artifactFullPath.Equals($formalAudioPanelsR3Root, [StringComparison]::OrdinalIgnoreCase) -or
    $artifactFullPath.StartsWith($formalAudioPanelsR3Boundary, [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must not reuse or nest under the formal audio-panels r3 authority: $formalAudioPanelsR3Root"
}
$formalLibraryDeletionR2Root = [System.IO.Path]::GetFullPath((Join-Path $projectRoot `
    "artifacts\windows-avalonia-library-deletion-slice-20260722-r2"))
$formalLibraryDeletionR2Boundary = $formalLibraryDeletionR2Root.TrimEnd('\') + '\'
if ($artifactFullPath.Equals($formalLibraryDeletionR2Root, [StringComparison]::OrdinalIgnoreCase) -or
    $artifactFullPath.StartsWith($formalLibraryDeletionR2Boundary, [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must not reuse or nest under the formal library-deletion r2 authority: $formalLibraryDeletionR2Root"
}
$formalChartValidationR2Root = [System.IO.Path]::GetFullPath((Join-Path $projectRoot `
    "artifacts\windows-avalonia-chart-validation-slice-20260722-r2"))
$formalChartValidationR2Boundary = $formalChartValidationR2Root.TrimEnd('\') + '\'
if ($artifactFullPath.Equals($formalChartValidationR2Root, [StringComparison]::OrdinalIgnoreCase) -or
    $artifactFullPath.StartsWith($formalChartValidationR2Boundary, [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must not reuse or nest under the formal chart-validation r2 authority: $formalChartValidationR2Root"
}
$formalLibraryBatchDeletionR3Root = [System.IO.Path]::GetFullPath((Join-Path $projectRoot `
    "artifacts\windows-avalonia-library-batch-deletion-slice-20260722-r3"))
$formalLibraryBatchDeletionR3Boundary = $formalLibraryBatchDeletionR3Root.TrimEnd('\') + '\'
if ($artifactFullPath.Equals(
        $formalLibraryBatchDeletionR3Root,
        [StringComparison]::OrdinalIgnoreCase) -or
    $artifactFullPath.StartsWith(
        $formalLibraryBatchDeletionR3Boundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must not reuse or nest under the formal library-batch-deletion r3 authority: $formalLibraryBatchDeletionR3Root"
}
$formalMalodyFullPackageR3Root = [System.IO.Path]::GetFullPath((Join-Path $projectRoot `
    "artifacts\windows-avalonia-mcz-full-package-slice-20260723-r3"))
$formalMalodyFullPackageR3Boundary = $formalMalodyFullPackageR3Root.TrimEnd('\') + '\'
if ($artifactFullPath.Equals(
        $formalMalodyFullPackageR3Root,
        [StringComparison]::OrdinalIgnoreCase) -or
    $artifactFullPath.StartsWith(
        $formalMalodyFullPackageR3Boundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must not reuse or nest under the formal Malody FullPackage r3 authority: $formalMalodyFullPackageR3Root"
}
$formalOsuFullPackageR2Root = [System.IO.Path]::GetFullPath((Join-Path $projectRoot `
    "artifacts\windows-avalonia-osz-full-package-slice-20260723-r2"))
$formalOsuFullPackageR2Boundary = $formalOsuFullPackageR2Root.TrimEnd('\') + '\'
if ($artifactFullPath.Equals(
        $formalOsuFullPackageR2Root,
        [StringComparison]::OrdinalIgnoreCase) -or
    $artifactFullPath.StartsWith(
        $formalOsuFullPackageR2Boundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must not reuse or nest under the formal osu! FullPackage r2 authority: $formalOsuFullPackageR2Root"
}
$formalCrossFormatFullPackageR1Root = [System.IO.Path]::GetFullPath((Join-Path $projectRoot `
    "artifacts\windows-avalonia-cross-format-full-package-slice-20260723-r1"))
$formalCrossFormatFullPackageR1Boundary =
    $formalCrossFormatFullPackageR1Root.TrimEnd('\') + '\'
if ($artifactFullPath.Equals(
        $formalCrossFormatFullPackageR1Root,
        [StringComparison]::OrdinalIgnoreCase) -or
    $artifactFullPath.StartsWith(
        $formalCrossFormatFullPackageR1Boundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must not reuse or nest under the formal cross-format FullPackage r1 authority: $formalCrossFormatFullPackageR1Root"
}
$formalOsuToMalodyFullPackageR7Root = [System.IO.Path]::GetFullPath((Join-Path $projectRoot `
    "artifacts\windows-avalonia-osu-to-mcz-full-package-slice-20260723-r7"))
$formalOsuToMalodyFullPackageR7Boundary =
    $formalOsuToMalodyFullPackageR7Root.TrimEnd('\') + '\'
if ($artifactFullPath.Equals(
        $formalOsuToMalodyFullPackageR7Root,
        [StringComparison]::OrdinalIgnoreCase) -or
    $artifactFullPath.StartsWith(
        $formalOsuToMalodyFullPackageR7Boundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must not reuse or nest under the formal osu-to-Malody FullPackage r7 authority: $formalOsuToMalodyFullPackageR7Root"
}
$formalChartExportModesR1Root = [System.IO.Path]::GetFullPath((Join-Path $projectRoot `
    "artifacts\windows-avalonia-export-modes-slice-20260723-r1"))
$formalChartExportModesR1Boundary = $formalChartExportModesR1Root.TrimEnd('\') + '\'
if ($artifactFullPath.Equals(
        $formalChartExportModesR1Root,
        [StringComparison]::OrdinalIgnoreCase) -or
    $artifactFullPath.StartsWith(
        $formalChartExportModesR1Boundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must not reuse or nest under the formal chart-export modes r1 authority: $formalChartExportModesR1Root"
}
if (Test-Path -LiteralPath $artifactFullPath) {
    if (Get-ChildItem -LiteralPath $artifactFullPath -Force | Select-Object -First 1) {
        throw "Formal artifact root must be new and empty: $artifactFullPath"
    }
}
New-Item -ItemType Directory -Path $artifactFullPath -Force | Out-Null

function Get-TempDirectoryMetadataEvidence {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $fullPath -PathType Container)) {
        return [pscustomobject][ordered]@{
            path = $fullPath
            exists = $false
            entryCount = 0
            fileCount = 0
            totalBytes = 0L
            rootCreationTimeUtc = $null
            rootLastWriteTimeUtc = $null
            metadataSha256 = [Convert]::ToHexString(
                [Security.Cryptography.SHA256]::HashData([byte[]]::new(0)))
        }
    }
    $entries = @(
        Get-ChildItem -LiteralPath $fullPath -Recurse -Force |
            Sort-Object FullName |
            ForEach-Object {
                $isFile = -not [bool]$_.PSIsContainer
                [pscustomobject][ordered]@{
                    relativePath = [IO.Path]::GetRelativePath($fullPath, $_.FullName).
                        Replace([IO.Path]::DirectorySeparatorChar, '/')
                    type = if ($isFile) { "file" } else { "directory" }
                    length = if ($isFile) { [long]$_.Length } else { 0L }
                    creationTimeUtc = $_.CreationTimeUtc.ToString("O")
                    lastWriteTimeUtc = $_.LastWriteTimeUtc.ToString("O")
                }
            })
    $rootItem = Get-Item -LiteralPath $fullPath -Force
    $rootCreationTimeUtc = $rootItem.CreationTimeUtc.ToString("O")
    $rootLastWriteTimeUtc = $rootItem.LastWriteTimeUtc.ToString("O")
    $metadataLines = @(
        "<root>|directory|0|$rootCreationTimeUtc|$rootLastWriteTimeUtc"
        $entries | ForEach-Object {
            "{0}|{1}|{2}|{3}|{4}" -f
                $_.relativePath,
                $_.type,
                $_.length,
                $_.creationTimeUtc,
                $_.lastWriteTimeUtc
        })
    $metadataBytes = [Text.Encoding]::UTF8.GetBytes(($metadataLines -join "`n"))
    [pscustomobject][ordered]@{
        path = $fullPath
        exists = $true
        entryCount = $entries.Count
        fileCount = @($entries | Where-Object type -eq "file").Count
        totalBytes = [long](($entries | Where-Object type -eq "file" |
            Measure-Object length -Sum).Sum ?? 0L)
        rootCreationTimeUtc = $rootCreationTimeUtc
        rootLastWriteTimeUtc = $rootLastWriteTimeUtc
        metadataSha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($metadataBytes))
    }
}

$originalProcessTemp = [Environment]::GetEnvironmentVariable("TEMP", "Process")
$originalProcessTmp = [Environment]::GetEnvironmentVariable("TMP", "Process")
$originalUserTemp = [Environment]::GetEnvironmentVariable("TEMP", "User")
$originalUserTmp = [Environment]::GetEnvironmentVariable("TMP", "User")
$originalMachineTemp = [Environment]::GetEnvironmentVariable("TEMP", "Machine")
$originalMachineTmp = [Environment]::GetEnvironmentVariable("TMP", "Machine")
$originalProcessTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$batchTempRoot = [IO.Path]::GetFullPath((Join-Path $artifactFullPath "temp")).TrimEnd('\')
if (-not $batchTempRoot.StartsWith(
        $artifactFullPath.TrimEnd('\') + '\',
        [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetPathRoot($batchTempRoot) -ieq "C:\") {
    throw "The formal process TEMP/TMP root must stay under the D-drive artifact root: $batchTempRoot"
}
New-Item -ItemType Directory -Path $batchTempRoot -Force | Out-Null
$batchAvaloniaSpecsTempRoot = Join-Path $batchTempRoot "LumaChart-Avalonia-Specs"
$legacyProcessAvaloniaSpecsTempRoot =
    Join-Path $originalProcessTempRoot "LumaChart-Avalonia-Specs"
$legacyProcessAvaloniaSpecsTempBefore =
    Get-TempDirectoryMetadataEvidence -Path $legacyProcessAvaloniaSpecsTempRoot

$officialInstallerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$officialInstallerSha256 = (Get-FileHash -LiteralPath $officialInstallerPath -Algorithm SHA256).Hash
if ($officialInstallerSha256 -ne "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
    throw "The trusted Windows/WPF installer changed."
}
$wpfProcessBefore = @(Get-Process -Name "LumaChart.App" -ErrorAction SilentlyContinue |
    Sort-Object Id)
$wpfProcessesBaseline = @($wpfProcessBefore | ForEach-Object {
        [pscustomobject][ordered]@{
            processId = [int]$_.Id
            processName = [string]$_.ProcessName
            startTimeUtc = $_.StartTime.ToUniversalTime().ToString("O")
            mainWindowHandle = [long]$_.MainWindowHandle
            mainWindowTitle = [string]$_.MainWindowTitle
            responding = [bool]$_.Responding
            observedAtUtc = [DateTimeOffset]::UtcNow
        }
    })
$sharedWpfWorkspacePath = Join-Path $projectRoot "LumaChart.Application\Workspaces\LocalDocumentWorkspace.cs"
$sharedWpfWorkspaceSha256 = (Get-FileHash -LiteralPath $sharedWpfWorkspacePath -Algorithm SHA256).Hash
if ($sharedWpfWorkspaceSha256 -ne "E44EB7BD2A79D721358F2F69BD19EBD08C1A3516DD70F3D04984590E0F1D5BDB") {
    throw "The WPF LocalDocumentWorkspace baseline changed during the independent desktop migration."
}
$captureHarnessPath = Join-Path $projectRoot "tools\Capture-WindowsAvaloniaGui.ps1"
$captureHarnessSha256 = (Get-FileHash -LiteralPath $captureHarnessPath -Algorithm SHA256).Hash
if ($captureHarnessSha256 -cne
    "88F459F81B3CA83C7F2B3BEB8B6D340CF0098CDE6A727BD64695C2CE854DB916") {
    throw "The audited Windows Avalonia GUI capture harness changed."
}
$captureHarnessTokens = $null
$captureHarnessAstErrors = $null
$captureHarnessAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $captureHarnessPath,
    [ref]$captureHarnessTokens,
    [ref]$captureHarnessAstErrors)
if ($captureHarnessAstErrors.Count -ne 0) {
    throw "The audited Windows Avalonia GUI capture harness has PowerShell AST errors."
}
$nestedIndexerDirectCastPattern =
    '\[\s*\[[A-Za-z_][A-Za-z0-9_.\[\], ]*\]\s*\$[A-Za-z_][A-Za-z0-9_]*\.'
$captureHarnessSourceText = Get-Content -LiteralPath $captureHarnessPath -Raw
$captureHarnessNestedIndexerDirectCasts = @(
    [regex]::Matches($captureHarnessSourceText, $nestedIndexerDirectCastPattern))
$captureHarnessDirectCastMethodCalls = @(
    $captureHarnessAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.ConvertExpressionAst] -and
            [string]$node.Type.TypeName.FullName -cne 'void' -and
            $node.Child -is
                [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
            -not [bool]$node.Child.Static
        }, $true))

$formalWrapperPath = [IO.Path]::GetFullPath($PSCommandPath)
$formalWrapperTokens = $null
$formalWrapperAstErrors = $null
$formalWrapperAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $formalWrapperPath,
    [ref]$formalWrapperTokens,
    [ref]$formalWrapperAstErrors)
$formalWrapperSourceText = Get-Content -LiteralPath $formalWrapperPath -Raw
$formalWrapperNestedIndexerDirectCasts = @(
    [regex]::Matches($formalWrapperSourceText, $nestedIndexerDirectCastPattern))
$formalWrapperDirectCastMethodCalls = @(
    $formalWrapperAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.ConvertExpressionAst] -and
            [string]$node.Type.TypeName.FullName -cne 'void' -and
            $node.Child -is
                [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
            -not [bool]$node.Child.Static
        }, $true))
if ($captureHarnessNestedIndexerDirectCasts.Count -ne 0 -or
    $captureHarnessDirectCastMethodCalls.Count -ne 0 -or
    $formalWrapperAstErrors.Count -ne 0 -or
    $formalWrapperNestedIndexerDirectCasts.Count -ne 0 -or
    $formalWrapperDirectCastMethodCalls.Count -ne 0) {
    throw "The formal wrapper or GUI capture harness contains an audited PowerShell cast-precedence hazard."
}

function Invoke-DotNetGate {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $startedAt = [DateTimeOffset]::UtcNow
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $previousTemp = [Environment]::GetEnvironmentVariable("TEMP", "Process")
    $previousTmp = [Environment]::GetEnvironmentVariable("TMP", "Process")
    try {
        [Environment]::SetEnvironmentVariable("TEMP", $batchTempRoot, "Process")
        [Environment]::SetEnvironmentVariable("TMP", $batchTempRoot, "Process")
        $effectiveTempRoot =
            [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
        if (-not (Test-PathEvidenceEqual -Left $effectiveTempRoot -Right $batchTempRoot)) {
            throw "Gate '$Name' did not receive the isolated D-drive process TEMP/TMP root."
        }
        $lines = @(& dotnet @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    }
    finally {
        [Environment]::SetEnvironmentVariable("TEMP", $previousTemp, "Process")
        [Environment]::SetEnvironmentVariable("TMP", $previousTmp, "Process")
        $timer.Stop()
    }
    $logPath = Join-Path $artifactFullPath "$Name.log"
    [IO.File]::WriteAllLines($logPath, $lines, [Text.UTF8Encoding]::new($false))
    if ($exitCode -ne 0) {
        throw "Gate '$Name' failed with exit code $exitCode. See $logPath"
    }
    [pscustomobject]@{
        name = $Name
        startedAtUtc = $startedAt
        durationMilliseconds = $timer.Elapsed.TotalMilliseconds
        exitCode = $exitCode
        logPath = $logPath
        logSha256 = (Get-FileHash -LiteralPath $logPath -Algorithm SHA256).Hash
        childProcessTempRoot = $effectiveTempRoot
        tempAndTmpProcessOverride = $true
    }
}

function Get-RequiredJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Required evidence is missing: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function ConvertTo-EvidenceDateTimeOffset {
    param([Parameter(Mandatory = $true)]$Value)

    if ($Value -is [DateTime]) { return [DateTimeOffset]$Value }
    return [DateTimeOffset]::Parse(
        [string]$Value,
        [Globalization.CultureInfo]::InvariantCulture)
}

function Test-BeatEvidenceEqual {
    param($Left, $Right)

    return $null -ne $Left -and $null -ne $Right -and
        [int]$Left.bar -eq [int]$Right.bar -and
        [int]$Left.numerator -eq [int]$Right.numerator -and
        [int]$Left.denominator -eq [int]$Right.denominator
}

function Test-ExactEvidencePropertyNames {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string[]]$Expected
    )

    if ($null -eq $Value) { return $false }
    $actual = @($Value.PSObject.Properties.Name)
    return $actual.Count -eq $Expected.Count -and
        ($actual -join "`n") -ceq ($Expected -join "`n")
}

function Test-ExactIntegerArray {
    param(
        $Value,
        [Parameter(Mandatory = $true)][int[]]$Expected
    )

    $actual = @($Value)
    if ($actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ([int]$actual[$index] -ne $Expected[$index]) { return $false }
    }
    return $true
}

function Test-ExactStringArray {
    param(
        $Value,
        [Parameter(Mandatory = $true)][string[]]$Expected,
        [switch]$IgnoreCase
    )

    $actual = @($Value)
    if ($actual.Count -ne $Expected.Count) { return $false }
    $comparison = if ($IgnoreCase) {
        [StringComparison]::OrdinalIgnoreCase
    } else {
        [StringComparison]::Ordinal
    }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if (-not [string]::Equals(
                [string]$actual[$index],
                [string]$Expected[$index],
                $comparison)) {
            return $false
        }
    }
    return $true
}

function Get-OrdinalSortedStrings {
    param($Value)

    [string[]]$sorted = @($Value | ForEach-Object { [string]$_ })
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    return $sorted
}

function Test-OrdinalStringOrder {
    param($Value)

    $actual = @($Value | ForEach-Object { [string]$_ })
    $sorted = @(Get-OrdinalSortedStrings -Value $actual)
    return Test-ExactStringArray -Value $actual -Expected $sorted
}

function Test-CaseInsensitiveStringSetUnique {
    param($Value)

    $set = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($Value)) {
        if (-not $set.Add([string]$item)) { return $false }
    }
    return $true
}

function Get-OrdinalSortedEvidenceRows {
    param(
        [Parameter(Mandatory = $true)][object[]]$Rows,
        [string]$PropertyName = 'relativePath'
    )

    $map = [Collections.Generic.SortedDictionary[string, object]]::new(
        [StringComparer]::Ordinal)
    foreach ($row in $Rows) {
        $property = $row.PSObject.Properties[$PropertyName]
        if ($null -eq $property) {
            throw "Formal evidence row is missing sort property '$PropertyName'."
        }
        $key = [string]$property.Value
        if ($map.ContainsKey($key)) {
            throw "Formal evidence rows contain duplicate Ordinal key '$key'."
        }
        $map.Add($key, $row)
    }
    return @($map.Values)
}

function Get-FormalOrdinalContentManifestSha256 {
    param([Parameter(Mandatory = $true)][object[]]$Rows)

    $orderedRows = @(
        Get-OrdinalSortedEvidenceRows -Rows $Rows -PropertyName 'relativePath')
    $canonicalLines = @($orderedRows | ForEach-Object {
            "{0}|{1}|{2}" -f
                [string]$_.relativePath,
                [long]$_.length,
                [string]$_.sha256
        })
    $bytes = [Text.Encoding]::UTF8.GetBytes(($canonicalLines -join "`n"))
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes))
}

function Add-FormalJsonSemanticMapNode {
    param(
        $Value,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Path,
        [Parameter(Mandatory = $true)]$Map
    )

    $nodePath = if ([string]::IsNullOrEmpty($Path)) { '/' } else { $Path }
    if ($null -eq $Value) {
        $Map[$nodePath] = 'null'
        return
    }
    if ($Value -is [pscustomobject]) {
        $properties = @($Value.PSObject.Properties | Sort-Object Name)
        $Map[$nodePath] = "object:$($properties.Count)"
        foreach ($property in $properties) {
            $escapedName = ([string]$property.Name).Replace('~', '~0').Replace('/', '~1')
            $childPath = if ([string]::IsNullOrEmpty($Path)) {
                "/$escapedName"
            } else {
                "$Path/$escapedName"
            }
            Add-FormalJsonSemanticMapNode `
                -Value $property.Value `
                -Path $childPath `
                -Map $Map
        }
        return
    }
    if ($Value -is [Collections.IDictionary]) {
        $keys = @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)
        $Map[$nodePath] = "object:$($keys.Count)"
        foreach ($key in $keys) {
            $escapedName = $key.Replace('~', '~0').Replace('/', '~1')
            $childPath = if ([string]::IsNullOrEmpty($Path)) {
                "/$escapedName"
            } else {
                "$Path/$escapedName"
            }
            Add-FormalJsonSemanticMapNode `
                -Value $Value[$key] `
                -Path $childPath `
                -Map $Map
        }
        return
    }
    if ($Value -is [Collections.IList] -and $Value -isnot [string]) {
        $Map[$nodePath] = "array:$($Value.Count)"
        for ($index = 0; $index -lt $Value.Count; $index++) {
            $childPath = if ([string]::IsNullOrEmpty($Path)) {
                "/$index"
            } else {
                "$Path/$index"
            }
            Add-FormalJsonSemanticMapNode `
                -Value $Value[$index] `
                -Path $childPath `
                -Map $Map
        }
        return
    }
    if ($Value -is [bool]) {
        $Map[$nodePath] = if ([bool]$Value) { 'boolean:true' } else { 'boolean:false' }
        return
    }
    if ($Value -is [string]) {
        $Map[$nodePath] = 'string:' + [string]$Value
        return
    }
    if ($Value -is [IFormattable]) {
        $Map[$nodePath] = 'number:' + $Value.ToString(
            $null,
            [Globalization.CultureInfo]::InvariantCulture)
        return
    }
    $Map[$nodePath] = 'value:' + [string]$Value
}

function ConvertTo-FormalJsonSemanticMap {
    param([Parameter(Mandatory = $true)]$Value)

    $map = [Collections.Generic.SortedDictionary[string, string]]::new(
        [StringComparer]::Ordinal)
    Add-FormalJsonSemanticMapNode -Value $Value -Path '' -Map $map
    return ,$map
}

function Compare-FormalJsonSemanticMaps {
    param(
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)]$Actual
    )

    $keys = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    foreach ($key in $Expected.Keys) { [void]$keys.Add([string]$key) }
    foreach ($key in $Actual.Keys) { [void]$keys.Add([string]$key) }
    $differences = [Collections.Generic.List[object]]::new()
    foreach ($key in $keys) {
        $hasExpected = $Expected.ContainsKey($key)
        $hasActual = $Actual.ContainsKey($key)
        $expectedValue = if ($hasExpected) { [string]$Expected[$key] } else { $null }
        $actualValue = if ($hasActual) { [string]$Actual[$key] } else { $null }
        if (-not $hasExpected -or -not $hasActual -or
            -not [string]::Equals(
                $expectedValue,
                $actualValue,
                [StringComparison]::Ordinal)) {
            $differences.Add([pscustomobject][ordered]@{
                    path = $key
                    kind = if (-not $hasExpected) {
                        'unexpected'
                    } elseif (-not $hasActual) {
                        'missing'
                    } else {
                        'changed'
                    }
                    expected = $expectedValue
                    actual = $actualValue
                }) | Out-Null
        }
    }
    return @($differences)
}

function Get-FormalJsonSemanticSha256 {
    param([Parameter(Mandatory = $true)]$Value)

    $map = ConvertTo-FormalJsonSemanticMap -Value $Value
    $memory = [IO.MemoryStream]::new()
    try {
        $writer = [IO.BinaryWriter]::new(
            $memory,
            [Text.UTF8Encoding]::new($false),
            $true)
        try {
            foreach ($entry in $map.GetEnumerator()) {
                $pathBytes = [Text.Encoding]::UTF8.GetBytes([string]$entry.Key)
                $valueBytes = [Text.Encoding]::UTF8.GetBytes([string]$entry.Value)
                $writer.Write([int]$pathBytes.Length)
                $writer.Write($pathBytes, 0, $pathBytes.Length)
                $writer.Write([int]$valueBytes.Length)
                $writer.Write($valueBytes, 0, $valueBytes.Length)
            }
            $writer.Flush()
        }
        finally {
            $writer.Dispose()
        }
        return [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($memory.ToArray()))
    }
    finally {
        $memory.Dispose()
    }
}

function Get-FormalContentManifestSha256 {
    param([Parameter(Mandatory = $true)][object[]]$Rows)

    $canonicalLines = @($Rows | Sort-Object relativePath | ForEach-Object {
            "{0}|{1}|{2}" -f
                [string]$_.relativePath,
                [long]$_.length,
                [string]$_.sha256
        })
    $bytes = [Text.Encoding]::UTF8.GetBytes(($canonicalLines -join "`n"))
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes))
}

function Get-FormalZipFileManifestEvidence {
    param([Parameter(Mandatory = $true)][string]$Path)

    Add-Type -AssemblyName System.IO.Compression
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Required formal ZIP is missing: $fullPath"
    }
    $rows = [Collections.Generic.List[object]]::new()
    $directoryEntries = [Collections.Generic.List[string]]::new()
    $archive = [IO.Compression.ZipFile]::OpenRead($fullPath)
    try {
        foreach ($entry in $archive.Entries | Sort-Object FullName) {
            $relativePath = ([string]$entry.FullName).Replace('\', '/')
            if ([string]::IsNullOrWhiteSpace([string]$entry.Name)) {
                $directoryEntries.Add($relativePath) | Out-Null
                continue
            }
            $memory = [IO.MemoryStream]::new()
            try {
                $stream = $entry.Open()
                try {
                    $stream.CopyTo($memory)
                }
                finally {
                    $stream.Dispose()
                }
                $bytes = $memory.ToArray()
            }
            finally {
                $memory.Dispose()
            }
            if ([long]$bytes.LongLength -ne [long]$entry.Length) {
                throw "Formal ZIP entry length changed while reading '$relativePath'."
            }
            $isMalodyChart = [IO.Path]::GetExtension($relativePath).Equals(
                '.mc',
                [StringComparison]::OrdinalIgnoreCase)
            $semanticSha256 = $null
            if ($isMalodyChart) {
                $jsonText = [Text.Encoding]::UTF8.GetString($bytes)
                $json = $jsonText | ConvertFrom-Json
                $semanticSha256 = Get-FormalJsonSemanticSha256 -Value $json
            }
            $rows.Add([pscustomobject][ordered]@{
                    relativePath = $relativePath
                    length = [long]$bytes.LongLength
                    sha256 = [Convert]::ToHexString(
                        [Security.Cryptography.SHA256]::HashData($bytes))
                    isMalodyChart = $isMalodyChart
                    semanticSha256 = $semanticSha256
                }) | Out-Null
        }
    }
    finally {
        $archive.Dispose()
    }
    $ordinalRows = @(Get-OrdinalSortedEvidenceRows -Rows @($rows))
    return [pscustomobject][ordered]@{
        path = $fullPath
        fileCount = $ordinalRows.Count
        directoryEntryCount = $directoryEntries.Count
        directoryEntries = @($directoryEntries)
        contentSha256 = Get-FormalContentManifestSha256 -Rows $ordinalRows
        rows = $ordinalRows
    }
}

function Get-FormalFlatFileManifestEvidence {
    param([Parameter(Mandatory = $true)][string]$Root)

    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $fullRoot -PathType Container)) {
        throw "Required formal file tree is missing: $fullRoot"
    }
    $directories = @(
        Get-ChildItem -LiteralPath $fullRoot -Recurse -Directory -Force |
            Sort-Object FullName |
            ForEach-Object {
                [IO.Path]::GetRelativePath($fullRoot, $_.FullName).
                    Replace([IO.Path]::DirectorySeparatorChar, '/')
            })
    $rows = @(
        Get-ChildItem -LiteralPath $fullRoot -Recurse -File -Force |
            Sort-Object FullName |
            ForEach-Object {
                $relativePath = [IO.Path]::GetRelativePath($fullRoot, $_.FullName).
                    Replace([IO.Path]::DirectorySeparatorChar, '/')
                $isMalodyChart = [IO.Path]::GetExtension($relativePath).Equals(
                    '.mc',
                    [StringComparison]::OrdinalIgnoreCase)
                $semanticSha256 = $null
                if ($isMalodyChart) {
                    $json = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
                    $semanticSha256 = Get-FormalJsonSemanticSha256 -Value $json
                }
                [pscustomobject][ordered]@{
                    relativePath = $relativePath
                    path = $_.FullName
                    length = [long]$_.Length
                    sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
                    isMalodyChart = $isMalodyChart
                    semanticSha256 = $semanticSha256
                }
            })
    $ordinalRows = @(Get-OrdinalSortedEvidenceRows -Rows $rows)
    return [pscustomobject][ordered]@{
        root = $fullRoot
        fileCount = $ordinalRows.Count
        directoryCount = $directories.Count
        directories = $directories
        contentSha256 = Get-FormalContentManifestSha256 -Rows $ordinalRows
        rows = $ordinalRows
    }
}

function Get-FormalChartExportModesSingleRateEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$AudioAssemblyRoot
    )

    $archiveFullPath = [IO.Path]::GetFullPath($ArchivePath)
    $sourceFullRoot = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\')
    $archiveManifest = Get-FormalZipFileManifestEvidence -Path $archiveFullPath
    $mcRows = @($archiveManifest.rows | Where-Object {
            [IO.Path]::GetExtension([string]$_.relativePath).Equals(
                '.mc',
                [StringComparison]::OrdinalIgnoreCase)
        })
    $oggRows = @($archiveManifest.rows | Where-Object {
            [IO.Path]::GetExtension([string]$_.relativePath).Equals(
                '.ogg',
                [StringComparison]::OrdinalIgnoreCase)
        })
    if ($archiveManifest.fileCount -ne 5 -or
        $archiveManifest.directoryEntryCount -ne 0 -or
        $mcRows.Count -ne 1 -or
        $oggRows.Count -ne 1) {
        throw "Formal chart-export SingleRate package must contain exactly five flat files, one MC and one Ogg."
    }

    $mainChartName = [string]$mcRows[0].relativePath
    $oggName = [string]$oggRows[0].relativePath
    if ($mainChartName -cnotmatch '^\d+_1\.25x\.mc$' -or
        $mainChartName -cne [IO.Path]::GetFileName($mainChartName) -or
        $oggName -cne 'audio_1.25x.ogg') {
        throw "Formal chart-export SingleRate package did not retain its exact dynamic MC and 1.25x Ogg names."
    }

    $entryNameSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    $duplicateEntryNames = [Collections.Generic.List[string]]::new()
    foreach ($row in $archiveManifest.rows) {
        $entryName = [string]$row.relativePath
        if ($entryName -cne [IO.Path]::GetFileName($entryName)) {
            throw "Formal chart-export SingleRate package contains a non-flat entry."
        }
        if (-not $entryNameSet.Add($entryName)) {
            $duplicateEntryNames.Add($entryName) | Out-Null
        }
    }
    if ($duplicateEntryNames.Count -ne 0) {
        throw "Formal chart-export SingleRate package contains a case-insensitive duplicate entry."
    }

    $expectedResourceSources = [ordered]@{
        'cover.png' = 'cover.png'
        'background.jpg' = 'background.jpg'
        'key.wav' = 'key.wav'
    }
    $resourceRows = [Collections.Generic.List[object]]::new()
    foreach ($mapping in $expectedResourceSources.GetEnumerator()) {
        $sourcePath = Join-Path $sourceFullRoot ([string]$mapping.Value)
        $matches = @($archiveManifest.rows | Where-Object {
                [string]$_.relativePath -ceq [string]$mapping.Key
            })
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -or
            $matches.Count -ne 1) {
            throw "Formal chart-export resource is missing from source or archive: $($mapping.Key)"
        }
        $sourceItem = Get-Item -LiteralPath $sourcePath
        $sourceSha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        if ([long]$matches[0].length -ne [long]$sourceItem.Length -or
            [string]$matches[0].sha256 -cne $sourceSha256) {
            throw "Formal chart-export source/archive resource bytes differ: $($mapping.Key)"
        }
        $resourceRows.Add([pscustomobject][ordered]@{
                entryName = [string]$mapping.Key
                sourcePath = $sourcePath
                length = [long]$sourceItem.Length
                sha256 = $sourceSha256
                exact = $true
            }) | Out-Null
    }
    $expectedEntryNames = @($mainChartName, $oggName) + @($expectedResourceSources.Keys)
    $unexpectedEntries = @($archiveManifest.rows | Where-Object {
            [string]$_.relativePath -cnotin $expectedEntryNames
        } | ForEach-Object { [string]$_.relativePath })
    if ($unexpectedEntries.Count -ne 0 -or
        $expectedEntryNames.Count -ne $archiveManifest.fileCount -or
        $entryNameSet.Contains('audio.wav') -or
        @($archiveManifest.rows | Where-Object {
                [string]$_.relativePath -match
                    '(?i)\.(?:osu|mcz|osz|luma-part|luma-export\.tmp)$'
            }).Count -ne 0) {
        throw "Formal chart-export SingleRate package leaked an unexpected chart, source audio, archive or temporary entry."
    }

    Add-Type -AssemblyName System.IO.Compression
    $archive = [IO.Compression.ZipFile]::OpenRead($archiveFullPath)
    try {
        $mainEntries = @($archive.Entries | Where-Object {
                [string]$_.FullName -ceq $mainChartName -and
                -not [string]::IsNullOrWhiteSpace([string]$_.Name)
            })
        $oggEntries = @($archive.Entries | Where-Object {
                [string]$_.FullName -ceq $oggName -and
                -not [string]::IsNullOrWhiteSpace([string]$_.Name)
            })
        if ($mainEntries.Count -ne 1 -or $oggEntries.Count -ne 1) {
            throw "Formal chart-export SingleRate package did not expose one exact MC and Ogg stream."
        }

        $mainMemory = [IO.MemoryStream]::new()
        try {
            $mainStream = $mainEntries[0].Open()
            try { $mainStream.CopyTo($mainMemory) } finally { $mainStream.Dispose() }
            $mainBytes = $mainMemory.ToArray()
        }
        finally { $mainMemory.Dispose() }

        $oggMemory = [IO.MemoryStream]::new()
        try {
            $oggStream = $oggEntries[0].Open()
            try { $oggStream.CopyTo($oggMemory) } finally { $oggStream.Dispose() }
            $oggBytes = $oggMemory.ToArray()
        }
        finally { $oggMemory.Dispose() }
    }
    finally { $archive.Dispose() }

    $mainText = [Text.Encoding]::UTF8.GetString($mainBytes)
    if ($mainText.Contains("`r") -or $mainText.Contains("`n")) {
        throw "Formal chart-export SingleRate MC is not compact single-line JSON."
    }
    $chart = $mainText | ConvertFrom-Json
    $timingRows = @($chart.time)
    $playableNotes = @($chart.note | Where-Object { $null -ne $_.column })
    $targetNotes = @($playableNotes | Where-Object {
            [int]$_.column -eq 2 -and $null -eq $_.endbeat -and
            (Test-ExactIntegerArray -Value @($_.beat) -Expected @(3, 10, 12)) -and
            [string]$_.sound -ceq 'key.wav'
        })
    $longNotes = @($playableNotes | Where-Object {
            [int]$_.column -eq 1 -and
            (Test-ExactIntegerArray -Value @($_.beat) -Expected @(5, 3, 8)) -and
            (Test-ExactIntegerArray -Value @($_.endbeat) -Expected @(6, 7, 8))
        })
    $audioNotes = @($chart.note | Where-Object {
            [int]$_.type -eq 1 -and
            [string]$_.sound -ceq $oggName -and
            [Math]::Abs([double]$_.offset - 80) -le .000001
        })
    if ([int]$chart.meta.mode -ne 0 -or
        [int]$chart.meta.mode_ext.column -ne 4 -or
        [string]$chart.meta.version -cne 'Disk version 1.25x' -or
        [int]$chart.meta.preview -ne 987 -or
        [string]$chart.meta.cover -cne 'cover.png' -or
        [string]$chart.meta.background -cne 'background.jpg' -or
        [string]$chart.meta.song.file -cne $oggName -or
        [Math]::Abs([double]$chart.meta.song.bpm - 150) -gt .000001 -or
        $timingRows.Count -ne 1 -or
        -not (Test-ExactIntegerArray -Value @($timingRows[0].beat) -Expected @(0, 0, 1)) -or
        [Math]::Abs([double]$timingRows[0].bpm - 150) -gt .000001 -or
        [Math]::Abs([double]$timingRows[0].delay - 64) -gt .000001 -or
        $playableNotes.Count -ne 2 -or
        $targetNotes.Count -ne 1 -or
        $longNotes.Count -ne 1 -or
        $audioNotes.Count -ne 1) {
        throw "Formal chart-export SingleRate MC did not retain the exact 1.25x WPF timing/resource transform and authored rational Beats."
    }

    if ($oggBytes.Length -le 256 -or
        [Text.Encoding]::ASCII.GetString($oggBytes, 0, 4) -cne 'OggS') {
        throw "Formal chart-export SingleRate audio is not a non-empty Ogg stream."
    }
    $audioAssemblyPaths = @(
        'NAudio.Core.dll',
        'NVorbis.dll',
        'NAudio.Vorbis.dll' | ForEach-Object {
            Join-Path $AudioAssemblyRoot $_
        })
    foreach ($assemblyPath in $audioAssemblyPaths) {
        if (-not (Test-Path -LiteralPath $assemblyPath -PathType Leaf)) {
            throw "Required formal Ogg validation assembly is missing: $assemblyPath"
        }
        [Reflection.Assembly]::LoadFrom([IO.Path]::GetFullPath($assemblyPath)) | Out-Null
    }
    $decodeMemory = [IO.MemoryStream]::new()
    try {
        $decodeMemory.Write($oggBytes, 0, $oggBytes.Length)
        $decodeMemory.Position = 0
        $reader = $null
        try {
            $reader = [NAudio.Vorbis.VorbisWaveReader]::new($decodeMemory, $true)
            $oggDurationSeconds = [double]$reader.TotalTime.TotalSeconds
            $oggSampleRate = [int]$reader.WaveFormat.SampleRate
            $oggChannels = [int]$reader.WaveFormat.Channels
        }
        finally {
            if ($null -ne $reader) { $reader.Dispose() }
        }
    }
    finally { $decodeMemory.Dispose() }
    if ($oggSampleRate -ne 44100 -or
        $oggChannels -ne 2 -or
        $oggDurationSeconds -le .45 -or
        $oggDurationSeconds -ge .75) {
        throw "Formal chart-export SingleRate Ogg did not decode as the expected 44.1 kHz stereo 1.25x stream."
    }

    return [pscustomobject][ordered]@{
        path = $archiveFullPath
        length = [long](Get-Item -LiteralPath $archiveFullPath).Length
        sha256 = (Get-FileHash -LiteralPath $archiveFullPath -Algorithm SHA256).Hash
        manifest = $archiveManifest
        mainChart = [ordered]@{
            entryName = $mainChartName
            length = [long]$mainBytes.LongLength
            sha256 = [Convert]::ToHexString(
                [Security.Cryptography.SHA256]::HashData($mainBytes))
            semanticSha256 = [string]$mcRows[0].semanticSha256
            compactSingleLine = $true
            version = [string]$chart.meta.version
            bpm = [double]$chart.meta.song.bpm
            preview = [int]$chart.meta.preview
            timingBpm = [double]$timingRows[0].bpm
            timingDelay = [double]$timingRows[0].delay
            audioNoteOffset = [double]$audioNotes[0].offset
            targetBeat = @($targetNotes[0].beat)
            targetColumn = [int]$targetNotes[0].column
            longNoteBeat = @($longNotes[0].beat)
            longNoteEndBeat = @($longNotes[0].endbeat)
            audioReference = [string]$chart.meta.song.file
        }
        ogg = [ordered]@{
            entryName = $oggName
            length = [long]$oggBytes.LongLength
            sha256 = [Convert]::ToHexString(
                [Security.Cryptography.SHA256]::HashData($oggBytes))
            header = 'OggS'
            sampleRate = $oggSampleRate
            channels = $oggChannels
            durationSeconds = $oggDurationSeconds
            decoded = $true
            audibleOrPitchValidated = $false
        }
        resources = @($resourceRows)
        unexpectedEntries = @($unexpectedEntries)
        exactEntryCount = 5
        preservePitchMeaning =
            'The GUI requested PreservePitch and produced a decodable Ogg; audible pitch was not measured.'
        verified = $true
    }
}

function Get-FormalOsuToMalodyArchiveEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$SourceRoot
    )

    $archiveManifest = Get-FormalZipFileManifestEvidence -Path $ArchivePath
    $mcRows = @($archiveManifest.rows | Where-Object { [bool]$_.isMalodyChart })
    if ($archiveManifest.fileCount -ne 6 -or
        $archiveManifest.directoryEntryCount -ne 0 -or
        $mcRows.Count -ne 1) {
        throw "Formal osu-to-MCZ archive must contain exactly six flat files and one target MC."
    }
    $mainChartFileName = [IO.Path]::GetFileName([string]$mcRows[0].relativePath)
    if ([string]$mcRows[0].relativePath -cne $mainChartFileName -or
        $mainChartFileName -cnotmatch '^\d+_1x\.mc$') {
        throw "Formal osu-to-MCZ archive main chart did not use one exact flat Unix-time *_1x.mc name."
    }

    $entryNameSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    $caseInsensitiveDuplicates = [Collections.Generic.List[string]]::new()
    foreach ($row in $archiveManifest.rows) {
        if ([string]$row.relativePath -cne
                [IO.Path]::GetFileName([string]$row.relativePath)) {
            throw "Formal osu-to-MCZ archive contains a non-flat entry."
        }
        if (-not $entryNameSet.Add([string]$row.relativePath)) {
            $caseInsensitiveDuplicates.Add([string]$row.relativePath)
        }
    }
    if ($caseInsensitiveDuplicates.Count -ne 0) {
        throw "Formal osu-to-MCZ archive contains a case-insensitive duplicate entry."
    }

    $expectedResourceSourceNames = [ordered]@{
        "audio.mp3" = "audio.mp3"
        "audio_2.mp3" = "audio.mp3"
        "BG1.jpg" = "BG1.jpg"
        "BG1_2.jpg" = "BG1.jpg"
        "BG3.png" = "BG3.png"
    }
    $resourceRows = [Collections.Generic.List[object]]::new()
    foreach ($mapping in $expectedResourceSourceNames.GetEnumerator()) {
        $sourcePath = Join-Path $SourceRoot ([string]$mapping.Value)
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Formal osu-to-MCZ source resource is missing: $sourcePath"
        }
        $sourceItem = Get-Item -LiteralPath $sourcePath
        $sourceSha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        $matches = @($archiveManifest.rows | Where-Object {
                [string]$_.relativePath -ceq [string]$mapping.Key
            })
        if ($matches.Count -ne 1 -or
            [long]$matches[0].length -ne [long]$sourceItem.Length -or
            [string]$matches[0].sha256 -cne $sourceSha256) {
            throw "Formal osu-to-MCZ resource source/archive chain failed for '$($mapping.Key)'."
        }
        $resourceRows.Add([pscustomobject][ordered]@{
                entryName = [string]$mapping.Key
                sourceName = [string]$mapping.Value
                sourcePath = $sourcePath
                length = [long]$sourceItem.Length
                sha256 = $sourceSha256
                exact = $true
            }) | Out-Null
    }
    $expectedEntryNames = @($mainChartFileName) + @($expectedResourceSourceNames.Keys)
    $unexpectedEntryNames = @($archiveManifest.rows | Where-Object {
            [string]$_.relativePath -cnotin $expectedEntryNames
        } | ForEach-Object { [string]$_.relativePath })
    if ($unexpectedEntryNames.Count -ne 0 -or
        $expectedEntryNames.Count -ne $archiveManifest.fileCount) {
        throw "Formal osu-to-MCZ archive entry identity set is not the exact dynamic MC plus five resources."
    }

    $sourceArtifactFiles = @(Get-ChildItem -LiteralPath $SourceRoot -File | Where-Object {
            $_.Extension -in '.osu', '.mc', '.mcz', '.osz', '.luma-part'
        })
    $leakedSourceArtifacts = @($sourceArtifactFiles | Where-Object {
            $entryNameSet.Contains($_.Name)
        } | ForEach-Object { $_.Name })
    $unexpectedChartArtifacts = @($archiveManifest.rows | Where-Object {
            $extension = [IO.Path]::GetExtension([string]$_.relativePath)
            $extension -in '.osu', '.mcz', '.osz', '.mc_', '.luma-part'
        } | ForEach-Object { [string]$_.relativePath })
    if ($leakedSourceArtifacts.Count -ne 0 -or
        $unexpectedChartArtifacts.Count -ne 0) {
        throw "Formal osu-to-MCZ archive leaked a source chart/archive decoy."
    }

    Add-Type -AssemblyName System.IO.Compression
    $zip = [IO.Compression.ZipFile]::OpenRead([IO.Path]::GetFullPath($ArchivePath))
    try {
        $mainEntries = @($zip.Entries | Where-Object {
                [string]$_.FullName -ceq $mainChartFileName -and
                -not [string]::IsNullOrWhiteSpace([string]$_.Name)
            })
        if ($mainEntries.Count -ne 1) {
            throw "Formal osu-to-MCZ archive did not expose one exact dynamic main entry stream."
        }
        $memory = [IO.MemoryStream]::new()
        try {
            $stream = $mainEntries[0].Open()
            try { $stream.CopyTo($memory) } finally { $stream.Dispose() }
            $mainBytes = $memory.ToArray()
        }
        finally { $memory.Dispose() }
    }
    finally { $zip.Dispose() }
    $mainText = [Text.Encoding]::UTF8.GetString($mainBytes)
    if ($mainText.Contains("`r") -or $mainText.Contains("`n")) {
        throw "Formal osu-to-MCZ target MC is not compact single-line JSON."
    }
    $mainChart = $mainText | ConvertFrom-Json
    $playableNotes = @($mainChart.note | Where-Object {
            $null -ne $_.column -and $null -ne $_.beat -and @($_.beat).Count -ge 3
        })
    $exactTargetNotes = @($playableNotes | Where-Object {
            [int]($_.column) -eq 3 -and $null -eq $_.endbeat -and
            [int]($_.beat[0]) -eq 15 -and
            [int]($_.beat[1]) -eq 10 -and
            [int]($_.beat[2]) -eq 12
        })
    $originalTargetNotes = @($playableNotes | Where-Object {
            [int]($_.column) -eq 2 -and $null -eq $_.endbeat -and
            [int]($_.beat[0]) -eq 15 -and
            [int]($_.beat[1]) -eq 5 -and
            [int]($_.beat[2]) -eq 6
        })
    $keySoundNodes = [Collections.Generic.List[object]]::new()
    for ($noteIndex = 0; $noteIndex -lt @($mainChart.note).Count; $noteIndex++) {
        $candidate = $mainChart.note[$noteIndex]
        $candidateSound = [string]($candidate.sound)
        if ([string]::IsNullOrWhiteSpace($candidateSound)) {
            continue
        }
        $hasColumnProperty = $null -ne $candidate.PSObject.Properties['column']
        $keySoundNodes.Add([pscustomobject][ordered]@{
                index = $noteIndex
                beat = @($candidate.beat)
                type = if ($null -eq $candidate.type) { $null } else { [int]($candidate.type) }
                offset = if ($null -eq $candidate.offset) { $null } else { [int]($candidate.offset) }
                hasColumnProperty = $hasColumnProperty
                column = if ($hasColumnProperty) { $candidate.column } else { $null }
                sound = $candidateSound
            }) | Out-Null
    }
    $exactKeySoundNodes = @($keySoundNodes | Where-Object {
            [int]$_.index -eq 2468 -and
            @($_.beat).Count -eq 3 -and
            [int]($_.beat[0]) -eq 0 -and
            [int]($_.beat[1]) -eq 0 -and
            [int]($_.beat[2]) -eq 1 -and
            [int]$_.type -eq 1 -and
            [int]$_.offset -eq -1000 -and
            -not [bool]$_.hasColumnProperty -and
            $null -eq $_.column -and
            [string]$_.sound -ceq 'audio_2.mp3'
        })
    $longNoteCount = @($playableNotes | Where-Object { $null -ne $_.endbeat }).Count
    $timingCount = @($mainChart.time).Count
    $effectCount = @($mainChart.effect).Count
    $keyCount = [int]($mainChart.meta.mode_ext.column)
    $audioReference = [string]($mainChart.meta.song.file)
    $backgroundReference = [string]($mainChart.meta.background)
    $referencedResourceNames = @(
        $audioReference,
        $backgroundReference,
        @($mainChart.note | ForEach-Object { [string]($_.sound) } |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })) |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
        Sort-Object -Unique
    $missingReferencedResources = @($referencedResourceNames | Where-Object {
            -not $entryNameSet.Contains([string]$_)
        })
    if ($exactTargetNotes.Count -ne 1 -or
        $originalTargetNotes.Count -ne 0 -or
        $keyCount -ne 4 -or
        $playableNotes.Count -ne 2468 -or
        $longNoteCount -ne 303 -or
        $timingCount -ne 2 -or
        $effectCount -ne 11 -or
        ($timingCount + $effectCount) -ne 13 -or
        $audioReference -cne 'audio_2.mp3' -or
        $backgroundReference -cne 'BG1_2.jpg' -or
        $keySoundNodes.Count -ne 1 -or
        $exactKeySoundNodes.Count -ne 1 -or
        $referencedResourceNames.Count -lt 2 -or
        $missingReferencedResources.Count -ne 0) {
        throw "Formal osu-to-MCZ target MC failed exact Beat/lane, structure, or resource-reference validation."
    }

    return [pscustomobject][ordered]@{
        archive = $archiveManifest
        sha256 = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash
        length = [long](Get-Item -LiteralPath $ArchivePath).Length
        mainChartFileName = $mainChartFileName
        mainChartLength = [long]$mainBytes.LongLength
        mainChartSha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($mainBytes))
        compactJson = $true
        exactTargetTapCount = $exactTargetNotes.Count
        originalTargetTapCount = $originalTargetNotes.Count
        structure = [ordered]@{
            keyCount = $keyCount
            playableNoteCount = $playableNotes.Count
            longNoteCount = $longNoteCount
            serializedTimingCount = $timingCount
            serializedEffectCount = $effectCount
            timingAndEffectCount = $timingCount + $effectCount
        }
        audioReference = $audioReference
        backgroundReference = $backgroundReference
        keySoundNodes = @($keySoundNodes)
        keySoundNodeVerified = $exactKeySoundNodes.Count -eq 1
        referencedResourceNames = $referencedResourceNames
        resourceNameToSha256 = @($resourceRows)
        sourceArtifactNames = @($sourceArtifactFiles | ForEach-Object { $_.Name } | Sort-Object)
        leakedSourceArtifacts = $leakedSourceArtifacts
        unexpectedChartArtifacts = $unexpectedChartArtifacts
        allFlatSafeUnique = $true
        verified = $true
    }
}

function Get-IndependentMalodyFullPackageChartManifestEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$FreshWorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$MainEditingRoot,
        [Parameter(Mandatory = $true)][string]$MainChartFileName,
        [Parameter(Mandatory = $true)][object[]]$ImportedTabs
    )

    $sourceRootFullPath = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\')
    $archiveFullPath = [IO.Path]::GetFullPath($ArchivePath)
    $freshWorkspaceFullPath = [IO.Path]::GetFullPath($FreshWorkspaceRoot).TrimEnd('\')
    $mainEditingFullPath = [IO.Path]::GetFullPath($MainEditingRoot).TrimEnd('\')
    $freshExtractionRoot = [IO.Path]::GetFullPath(
        (Join-Path `
            $freshWorkspaceFullPath `
            ([IO.Path]::GetFileNameWithoutExtension($archiveFullPath)))).TrimEnd('\')
    $expectedChartNames = @(
        '1622528438.mc'
        '1627794161.mc'
        '1677938697.mc'
        '1712333795.mc'
        '1779163459.mc'
        'HyuN - Infinity Heaven (HXJ_Crafter) [4K Future Lv.25].mc'
        'HyuN - Infinity Heaven (HXJ_Crafter) [4K Past Lv.7].mc'
        'HyuN - Infinity Heaven (HXJ_Crafter) [4K Present].mc'
    )
    $expectedResourceNames = @(
        'InfinityHeaven.jpg'
        'InfinityHeaven_2.jpg'
        'InfinityHeaven.ogg'
        'InfinityHeaven_2.ogg'
        'ih2.jpg'
    )
    $expectedPackageNames = @(
        Get-OrdinalSortedStrings `
            -Value (@($expectedChartNames) + @($expectedResourceNames)))

    $sourceChartFiles = @(
        Get-ChildItem `
            -LiteralPath $sourceRootFullPath `
            -Recurse `
            -File `
            -Filter '*.mc' |
            Sort-Object FullName)
    $sourceChartNames = @($sourceChartFiles | ForEach-Object { $_.Name })
    $sourceRelativePaths = @($sourceChartFiles | ForEach-Object {
            [IO.Path]::GetRelativePath($sourceRootFullPath, $_.FullName).
                Replace([IO.Path]::DirectorySeparatorChar, '/')
        })
    if (-not (Test-ExactStringArray `
            -Value $sourceChartNames `
            -Expected $expectedChartNames) -or
        -not (Test-OrdinalStringOrder -Value $sourceChartNames) -or
        -not (Test-CaseInsensitiveStringSetUnique -Value $sourceChartNames) -or
        -not (Test-OrdinalStringOrder -Value $sourceRelativePaths) -or
        -not (Test-CaseInsensitiveStringSetUnique -Value $sourceRelativePaths) -or
        @($sourceRelativePaths | Where-Object {
                [string]$_ -cnotmatch '^0/[^/]+\.mc$'
            }).Count -ne 0) {
        throw 'Independent MCZ manifest did not find the exact eight case-preserved source chart names under 0/.'
    }

    $archiveManifest = Get-FormalZipFileManifestEvidence -Path $archiveFullPath
    $freshManifest = Get-FormalFlatFileManifestEvidence -Root $freshExtractionRoot
    $archiveTreeRows = @(Get-OrdinalSortedEvidenceRows -Rows @(
        $archiveManifest.rows | ForEach-Object {
            [pscustomobject][ordered]@{
                relativePath = [string]$_.relativePath
                length = [long]$_.length
                sha256 = [string]$_.sha256
            }
        }))
    $freshTreeRows = @(Get-OrdinalSortedEvidenceRows -Rows @(
        $freshManifest.rows | ForEach-Object {
            [pscustomobject][ordered]@{
                relativePath = [string]$_.relativePath
                length = [long]$_.length
                sha256 = [string]$_.sha256
            }
        }))
    $archivePackageNames = @($archiveTreeRows | ForEach-Object {
            [string]$_.relativePath
        })
    $freshPackageNames = @($freshTreeRows | ForEach-Object {
            [string]$_.relativePath
        })
    $workspaceTopLevelChildren = @(
        Get-ChildItem -LiteralPath $freshWorkspaceFullPath -Force)
    if ($archiveManifest.fileCount -ne 13 -or
        $archiveManifest.directoryEntryCount -ne 0 -or
        $freshManifest.fileCount -ne 13 -or
        $freshManifest.directoryCount -ne 0 -or
        $workspaceTopLevelChildren.Count -ne 1 -or
        -not [bool]$workspaceTopLevelChildren[0].PSIsContainer -or
        -not (Test-PathEvidenceEqual `
            -Left $workspaceTopLevelChildren[0].FullName `
            -Right $freshExtractionRoot) -or
        -not (Test-ExactStringArray `
            -Value $archivePackageNames `
            -Expected $expectedPackageNames) -or
        -not (Test-ExactStringArray `
            -Value $freshPackageNames `
            -Expected $expectedPackageNames) -or
        -not (Test-OrdinalStringOrder -Value $archivePackageNames) -or
        -not (Test-OrdinalStringOrder -Value $freshPackageNames) -or
        -not (Test-CaseInsensitiveStringSetUnique -Value $archivePackageNames) -or
        -not (Test-CaseInsensitiveStringSetUnique -Value $freshPackageNames) -or
        [string]$archiveManifest.contentSha256 -cne
            [string]$freshManifest.contentSha256 -or
        (Get-FormalOrdinalContentManifestSha256 -Rows $archiveTreeRows) -cne
            (Get-FormalOrdinalContentManifestSha256 -Rows $freshTreeRows) -or
        (($archiveTreeRows | ConvertTo-Json -Depth 4 -Compress) -cne
         ($freshTreeRows | ConvertTo-Json -Depth 4 -Compress))) {
        throw 'Independent MCZ manifest did not prove the exact flat 13-file archive-to-fresh byte tree.'
    }

    $archiveChartRows = @(Get-OrdinalSortedEvidenceRows -Rows @(
        $archiveManifest.rows | Where-Object {
            [bool]$_.isMalodyChart
        }))
    $freshChartRows = @(Get-OrdinalSortedEvidenceRows -Rows @(
        $freshManifest.rows | Where-Object {
            [bool]$_.isMalodyChart
        }))
    $archiveChartNames = @($archiveChartRows | ForEach-Object {
            [string]$_.relativePath
        })
    $freshChartNames = @($freshChartRows | ForEach-Object {
            [string]$_.relativePath
        })
    if (-not (Test-ExactStringArray `
            -Value $archiveChartNames `
            -Expected $expectedChartNames) -or
        -not (Test-ExactStringArray `
            -Value $freshChartNames `
            -Expected $expectedChartNames) -or
        -not (Test-OrdinalStringOrder -Value $archiveChartNames) -or
        -not (Test-OrdinalStringOrder -Value $freshChartNames) -or
        -not (Test-CaseInsensitiveStringSetUnique -Value $archiveChartNames) -or
        -not (Test-CaseInsensitiveStringSetUnique -Value $freshChartNames)) {
        throw 'Independent MCZ manifest archive/fresh chart identities did not equal the exact eight source leaf names.'
    }

    $expectedFreshChartPaths = @(Get-OrdinalSortedStrings -Value @(
        $expectedChartNames | ForEach-Object {
            [IO.Path]::GetFullPath((Join-Path $freshExtractionRoot $_))
        }))
    $actualImportedTabPaths = @(Get-OrdinalSortedStrings -Value @(
        $ImportedTabs | ForEach-Object {
            [IO.Path]::GetFullPath([string]$_.sourcePath)
        }))
    if (-not (Test-ExactStringArray `
            -Value $actualImportedTabPaths `
            -Expected $expectedFreshChartPaths `
            -IgnoreCase) -or
        -not (Test-OrdinalStringOrder -Value $expectedFreshChartPaths) -or
        -not (Test-OrdinalStringOrder -Value $actualImportedTabPaths) -or
        -not (Test-CaseInsensitiveStringSetUnique -Value $expectedFreshChartPaths) -or
        -not (Test-CaseInsensitiveStringSetUnique -Value $actualImportedTabPaths)) {
        throw 'Independent MCZ manifest imported-tab paths did not exactly cover the eight fresh chart paths.'
    }

    $postExitWorkingFiles = @(
        Get-ChildItem `
            -LiteralPath $mainEditingFullPath `
            -Recurse `
            -File `
            -Filter 'working.mc')
    if ($postExitWorkingFiles.Count -ne 1) {
        throw "Independent MCZ manifest expected one post-exit working.mc; found $($postExitWorkingFiles.Count)."
    }
    $postExitWorkingPath = [IO.Path]::GetFullPath($postExitWorkingFiles[0].FullName)
    $postExitWorkingRaw = Get-Content -LiteralPath $postExitWorkingPath -Raw
    $postExitWorkingChart = $postExitWorkingRaw | ConvertFrom-Json
    $postExitWorkingSha256 =
        (Get-FileHash -LiteralPath $postExitWorkingPath -Algorithm SHA256).Hash
    $postExitWorkingSemanticSha256 =
        Get-FormalJsonSemanticSha256 -Value $postExitWorkingChart
    $postExitNotes = @($postExitWorkingChart.note)
    if ($postExitNotes.Count -le 1608) {
        throw 'Independent MCZ manifest post-exit working.mc does not contain the target Note/resource indices.'
    }
    $submittedBeatIndices = @(
        for ($noteIndex = 0; $noteIndex -lt $postExitNotes.Count; $noteIndex++) {
            $note = $postExitNotes[$noteIndex]
            if ($null -ne $note.column -and
                [int]$note.column -eq 1 -and
                @($note.beat).Count -ge 3 -and
                [int]$note.beat[0] -eq 182 -and
                [int]$note.beat[1] -eq 2 -and
                [int]$note.beat[2] -eq 8) {
                $noteIndex
            }
        })
    $originalBeatIndices = @(
        for ($noteIndex = 0; $noteIndex -lt $postExitNotes.Count; $noteIndex++) {
            $note = $postExitNotes[$noteIndex]
            if ($null -ne $note.column -and
                [int]$note.column -eq 1 -and
                @($note.beat).Count -ge 3 -and
                [int]$note.beat[0] -eq 182 -and
                [int]$note.beat[1] -eq 1 -and
                [int]$note.beat[2] -eq 4) {
                $noteIndex
            }
        })
    if ($submittedBeatIndices.Count -ne 1 -or
        [int]$submittedBeatIndices[0] -ne 804 -or
        $originalBeatIndices.Count -ne 0) {
        throw 'Independent MCZ manifest post-exit working.mc did not preserve exactly one submitted 182:2/8 lane-1 Note at /note/804 and zero original representations.'
    }

    $reconstructedCleanChart = $postExitWorkingRaw | ConvertFrom-Json
    $reconstructedCleanChart.note[804].beat = @(182, 1, 4)
    $reconstructedCleanMap = ConvertTo-FormalJsonSemanticMap `
        -Value $reconstructedCleanChart
    $postExitWorkingMap = ConvertTo-FormalJsonSemanticMap `
        -Value $postExitWorkingChart
    $dirtyProjectionDifferences = @(
        Compare-FormalJsonSemanticMaps `
            -Expected $reconstructedCleanMap `
            -Actual $postExitWorkingMap)
    $expectedDirtyProjectionDifferences = @(
        [pscustomobject][ordered]@{
            path = '/note/804/beat/1'
            kind = 'changed'
            expected = 'number:1'
            actual = 'number:2'
        }
        [pscustomobject][ordered]@{
            path = '/note/804/beat/2'
            kind = 'changed'
            expected = 'number:4'
            actual = 'number:8'
        }
    )
    if (($dirtyProjectionDifferences | ConvertTo-Json -Depth 4 -Compress) -cne
        ($expectedDirtyProjectionDifferences | ConvertTo-Json -Depth 4 -Compress)) {
        throw 'Independent MCZ manifest could not reconstruct the exact two-component rational Beat projection from the post-exit working file.'
    }

    $backgroundReference = [string]$postExitWorkingChart.meta.background
    $songReference = [string]$postExitWorkingChart.meta.song.file
    $keySoundIndices = @(
        for ($noteIndex = 0; $noteIndex -lt $postExitNotes.Count; $noteIndex++) {
            $sound = [string]$postExitNotes[$noteIndex].sound
            if (-not [string]::IsNullOrWhiteSpace($sound) -and
                [string]::Equals(
                    $sound,
                    $songReference,
                    [StringComparison]::Ordinal)) {
                $noteIndex
            }
        })
    if ($backgroundReference -cne 'InfinityHeaven.jpg' -or
        $songReference -cne 'InfinityHeaven.ogg' -or
        $keySoundIndices.Count -ne 1 -or
        [int]$keySoundIndices[0] -ne 1608) {
        throw 'Independent MCZ manifest post-exit working.mc did not expose the exact background/song/Key-sound source references.'
    }
    $packagedBackgroundReference = 'InfinityHeaven_2.jpg'
    $packagedSongReference = 'InfinityHeaven_2.ogg'
    $projectedMainChart = $postExitWorkingRaw | ConvertFrom-Json
    $projectedMainChart.meta.background = $packagedBackgroundReference
    $projectedMainChart.meta.song.file = $packagedSongReference
    $projectedMainChart.note[1608].sound = $packagedSongReference
    $projectedMainMap = ConvertTo-FormalJsonSemanticMap -Value $projectedMainChart
    $projectedMainSemanticSha256 =
        Get-FormalJsonSemanticSha256 -Value $projectedMainChart
    $resourceProjectionDifferences = @(
        Compare-FormalJsonSemanticMaps `
            -Expected $postExitWorkingMap `
            -Actual $projectedMainMap)
    $expectedResourceProjectionDifferences = @(
        [pscustomobject][ordered]@{
            path = '/meta/background'
            kind = 'changed'
            expected = 'string:InfinityHeaven.jpg'
            actual = 'string:InfinityHeaven_2.jpg'
        }
        [pscustomobject][ordered]@{
            path = '/meta/song/file'
            kind = 'changed'
            expected = 'string:InfinityHeaven.ogg'
            actual = 'string:InfinityHeaven_2.ogg'
        }
        [pscustomobject][ordered]@{
            path = '/note/1608/sound'
            kind = 'changed'
            expected = 'string:InfinityHeaven.ogg'
            actual = 'string:InfinityHeaven_2.ogg'
        }
    )
    if (($resourceProjectionDifferences | ConvertTo-Json -Depth 4 -Compress) -cne
        ($expectedResourceProjectionDifferences | ConvertTo-Json -Depth 4 -Compress)) {
        throw 'Independent MCZ manifest main projection was not exactly the three deterministic WPF-compatible _2 resource references.'
    }

    $entries = [Collections.Generic.List[object]]::new()
    foreach ($sourceChartFile in $sourceChartFiles) {
        $sourceRelativePath = [IO.Path]::GetRelativePath(
            $sourceRootFullPath,
            $sourceChartFile.FullName).
                Replace([IO.Path]::DirectorySeparatorChar, '/')
        $chartName = $sourceChartFile.Name
        $archiveMatches = @($archiveChartRows | Where-Object {
                [string]$_.relativePath -ceq $chartName
            })
        $freshMatches = @($freshChartRows | Where-Object {
                [string]$_.relativePath -ceq $chartName
            })
        if ($archiveMatches.Count -ne 1 -or $freshMatches.Count -ne 1) {
            throw "Independent MCZ manifest did not find one archive/fresh chart row for '$chartName'."
        }
        $archiveRow = $archiveMatches[0]
        $freshRow = $freshMatches[0]
        $sourceChart = Get-Content -LiteralPath $sourceChartFile.FullName -Raw |
            ConvertFrom-Json
        $freshChart = Get-Content -LiteralPath $freshRow.path -Raw |
            ConvertFrom-Json
        $sourceSemanticSha256 = Get-FormalJsonSemanticSha256 -Value $sourceChart
        $freshSemanticSha256 = Get-FormalJsonSemanticSha256 -Value $freshChart
        $isMain = $chartName -ceq $MainChartFileName
        $expectedChart = if ($isMain) { $projectedMainChart } else { $sourceChart }
        $expectedMap = ConvertTo-FormalJsonSemanticMap -Value $expectedChart
        $freshMap = ConvertTo-FormalJsonSemanticMap -Value $freshChart
        $semanticDifferences = @(
            Compare-FormalJsonSemanticMaps -Expected $expectedMap -Actual $freshMap)
        $expectedSemanticSha256 = if ($isMain) {
            $projectedMainSemanticSha256
        } else {
            $sourceSemanticSha256
        }
        $archiveFreshBytesExact =
            [long]$archiveRow.length -eq [long]$freshRow.length -and
            [string]$archiveRow.sha256 -ceq [string]$freshRow.sha256
        $verified =
            $semanticDifferences.Count -eq 0 -and
            [string]$archiveRow.semanticSha256 -ceq $expectedSemanticSha256 -and
            $freshSemanticSha256 -ceq $expectedSemanticSha256 -and
            $archiveFreshBytesExact -and
            ($isMain -or $sourceSemanticSha256 -ceq $expectedSemanticSha256)
        if (-not $verified) {
            throw "Independent MCZ chart semantic/byte chain failed for '$chartName'."
        }
        $entries.Add([pscustomobject][ordered]@{
                isMain = $isMain
                sourceRelativePath = $sourceRelativePath
                sourcePath = $sourceChartFile.FullName
                sourceLength = [long]$sourceChartFile.Length
                sourceSha256 =
                    (Get-FileHash -LiteralPath $sourceChartFile.FullName -Algorithm SHA256).Hash
                sourceSemanticSha256 = $sourceSemanticSha256
                semanticBaselineKind = if ($isMain) {
                    'postExitWorkingPlusResourceProjection'
                } else {
                    'sourceMc'
                }
                semanticBaselinePath = if ($isMain) {
                    $postExitWorkingPath
                } else {
                    $sourceChartFile.FullName
                }
                expectedSemanticSha256 = $expectedSemanticSha256
                archiveEntry = $chartName
                archiveLength = [long]$archiveRow.length
                archiveSha256 = [string]$archiveRow.sha256
                archiveSemanticSha256 = [string]$archiveRow.semanticSha256
                freshRelativePath = $chartName
                freshPath = $freshRow.path
                freshLength = [long]$freshRow.length
                freshSha256 = [string]$freshRow.sha256
                freshSemanticSha256 = $freshSemanticSha256
                semanticDifferenceCount = $semanticDifferences.Count
                semanticDifferences = $semanticDifferences
                archiveFreshBytesExact = $archiveFreshBytesExact
                verified = $verified
            }) | Out-Null
    }
    $mainEntries = @($entries | Where-Object { [bool]$_.isMain })
    $siblingEntries = @($entries | Where-Object { -not [bool]$_.isMain })
    if ($entries.Count -ne 8 -or
        $mainEntries.Count -ne 1 -or
        $siblingEntries.Count -ne 7 -or
        @($entries | Where-Object { -not [bool]$_.verified }).Count -ne 0) {
        throw 'Independent MCZ manifest did not prove one main and seven sibling chart chains.'
    }

    return [pscustomobject][ordered]@{
        schema = 'lumachart.windows.avalonia.mcz-chart-manifest-independent.v1'
        verificationBasis =
            'wrapper independently rereads source MC, post-exit working.mc, ZIP entry bytes, fresh extracted files and imported-tab paths'
        sourceRoot = $sourceRootFullPath
        archivePath = $archiveFullPath
        freshExtractionRoot = $freshExtractionRoot
        expectedChartCount = 8
        expectedPackageFileCount = 13
        expectedChartNames = $expectedChartNames
        sourceRelativePaths = $sourceRelativePaths
        archiveChartEntries = $archiveChartNames
        freshChartPaths = $expectedFreshChartPaths
        importedTabPaths = $actualImportedTabPaths
        postExitWorking = [pscustomobject][ordered]@{
            path = $postExitWorkingPath
            length = [long]$postExitWorkingFiles[0].Length
            sha256 = $postExitWorkingSha256
            semanticSha256 = $postExitWorkingSemanticSha256
            submittedBeatJsonPointer = '/note/804/beat'
            submittedBeat = @(182, 2, 8)
            submittedBeatMatchCount = $submittedBeatIndices.Count
            originalBeatMatchCount = $originalBeatIndices.Count
            evidenceMeaning =
                'post-exit persistence only; capture-time clean working baseline remains a separately timestamped Capture snapshot'
        }
        dirtyProjection = [pscustomobject][ordered]@{
            reconstruction = 'reverse projected from post-exit working.mc'
            logicalJsonPointer = '/note/804/beat'
            baselineBeat = @(182, 1, 4)
            submittedBeat = @(182, 2, 8)
            rawDifferences = $dirtyProjectionDifferences
            verified = $true
        }
        resourceProjection = [pscustomobject][ordered]@{
            rule = 'WPF-compatible deterministic same-name resource collision suffix _2'
            background = [pscustomobject][ordered]@{
                source = $backgroundReference
                packaged = $packagedBackgroundReference
            }
            song = [pscustomobject][ordered]@{
                source = $songReference
                packaged = $packagedSongReference
            }
            keySoundJsonPointer = '/note/1608/sound'
            differences = $resourceProjectionDifferences
            projectedMainSemanticSha256 = $projectedMainSemanticSha256
            verified = $true
        }
        archiveFreshTree = [pscustomobject][ordered]@{
            rowOrder = 'StringComparer.Ordinal by relativePath'
            archive = $archiveManifest
            fresh = $freshManifest
            archiveRows = $archiveTreeRows
            freshRows = $freshTreeRows
            contentSha256 = $archiveManifest.contentSha256
            ordinalContentSha256 =
                Get-FormalOrdinalContentManifestSha256 -Rows $archiveTreeRows
            exact = $true
        }
        entries = @($entries)
        entryOrder = 'StringComparer.Ordinal by source relative path'
        caseInsensitiveIdentityUnique = $true
        siblingSourceSemanticExactCount = $siblingEntries.Count
        importedTabPathsExact = $true
        verified = $true
    }
}

function Test-PathEvidenceEqual {
    param($Left, $Right)

    if ([string]::IsNullOrWhiteSpace([string]$Left) -or
        [string]::IsNullOrWhiteSpace([string]$Right)) {
        return $false
    }
    try {
        $leftFullPath = [IO.Path]::GetFullPath([string]$Left)
        $rightFullPath = [IO.Path]::GetFullPath([string]$Right)
        return [string]::Equals(
            $leftFullPath,
            $rightFullPath,
            [StringComparison]::OrdinalIgnoreCase)
    }
    catch {
        return $false
    }
}

function Test-TimestampEvidenceEqual {
    param($Left, $Right)

    if ($null -eq $Left -or $null -eq $Right) {
        return $false
    }
    try {
        $leftTimestamp = if ($Left -is [DateTimeOffset]) {
            [DateTimeOffset]$Left
        } elseif ($Left -is [DateTime]) {
            [DateTimeOffset]([DateTime]$Left)
        } else {
            [DateTimeOffset]::Parse(
                [string]$Left,
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::RoundtripKind)
        }
        $rightTimestamp = if ($Right -is [DateTimeOffset]) {
            [DateTimeOffset]$Right
        } elseif ($Right -is [DateTime]) {
            [DateTimeOffset]([DateTime]$Right)
        } else {
            [DateTimeOffset]::Parse(
                [string]$Right,
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::RoundtripKind)
        }
        return $leftTimestamp.UtcDateTime.Ticks -eq
            $rightTimestamp.UtcDateTime.Ticks
    }
    catch {
        return $false
    }
}

function Test-NativeFileNameFocusEvidence {
    param(
        [Parameter(Mandatory = $true)]$Evidence,
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)]
        [ValidateSet("CommonSave", "LegacyOpen")]
        [string]$Provider
    )

    if ($null -eq $Evidence -or
        [int]$Evidence.processId -ne $ProcessId -or
        -not [bool]$Evidence.hasKeyboardFocus) {
        return $false
    }
    if ($Provider -ceq "CommonSave") {
        return [string]$Evidence.automationId -ceq "FileNameControlHost" -or
            ([string]$Evidence.automationId -ceq "1001" -and
             [string]$Evidence.className -ceq "Edit")
    }
    return [string]$Evidence.automationId -ceq "1148" -and
        [string]$Evidence.className -cin @("Edit", "ComboBox", "ComboBoxEx32")
}

function Test-PlacementTargetEvidenceEqual {
    param($Left, $Right)

    return $null -ne $Left -and $null -ne $Right -and
        [int]$Left.lane -eq [int]$Right.lane -and
        (Test-BeatEvidenceEqual -Left $Left.beat -Right $Right.beat) -and
        $null -ne $Left.windowPointDip -and $null -ne $Right.windowPointDip -and
        [double]$Left.windowPointDip.x -eq [double]$Right.windowPointDip.x -and
        [double]$Left.windowPointDip.y -eq [double]$Right.windowPointDip.y
}

function Test-ProEditorTargetEvidenceEqual {
    param($Left, $Right)

    return $null -ne $Left -and $null -ne $Right -and
        [int]$Left.workspaceColumn -eq [int]$Right.workspaceColumn -and
        [bool]$Left.isDraft -eq [bool]$Right.isDraft -and
        (Test-BeatEvidenceEqual -Left $Left.beat -Right $Right.beat) -and
        $null -ne $Left.windowPointDip -and $null -ne $Right.windowPointDip -and
        [double]$Left.windowPointDip.x -eq [double]$Right.windowPointDip.x -and
        [double]$Left.windowPointDip.y -eq [double]$Right.windowPointDip.y
}

function Get-ImageEvidence {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Required screenshot is missing: $Path" }
    Add-Type -AssemblyName System.Drawing
    $image = [Drawing.Bitmap]::new($Path)
    try {
        $sampleColors = [Collections.Generic.HashSet[int]]::new()
        $sampleLuminance = [Collections.Generic.List[double]]::new()
        $sampleOpaquePixels = 0
        for ($sampleY = 0; $sampleY -lt 16; $sampleY++) {
            $pixelY = [Math]::Min($image.Height - 1, [int](($sampleY + .5) * $image.Height / 16))
            for ($sampleX = 0; $sampleX -lt 16; $sampleX++) {
                $pixelX = [Math]::Min($image.Width - 1, [int](($sampleX + .5) * $image.Width / 16))
                $pixel = $image.GetPixel($pixelX, $pixelY)
                [void]$sampleColors.Add($pixel.ToArgb())
                if ($pixel.A -gt 0) { $sampleOpaquePixels++ }
                $sampleLuminance.Add(.2126 * $pixel.R + .7152 * $pixel.G + .0722 * $pixel.B)
            }
        }
        $sampleMean = ($sampleLuminance | Measure-Object -Average).Average
        $sampleVariance = ($sampleLuminance | ForEach-Object {
            $difference = $_ - $sampleMean
            $difference * $difference
        } | Measure-Object -Average).Average
        [pscustomobject]@{
            path = [IO.Path]::GetFullPath($Path)
            widthPixels = $image.Width
            heightPixels = $image.Height
            sizeBytes = (Get-Item -LiteralPath $Path).Length
            sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
            sampledPixels = $sampleLuminance.Count
            sampledUniqueColors = $sampleColors.Count
            sampledOpaquePixels = $sampleOpaquePixels
            sampledLuminanceStdDev = [Math]::Sqrt([double]$sampleVariance)
        }
    }
    finally {
        $image.Dispose()
    }
}

function Get-DirectoryTreeEvidence {
    param([Parameter(Mandatory = $true)][string]$Path)

    $root = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "Required evidence tree is missing: $root"
    }
    $rootItem = Get-Item -LiteralPath $root -Force
    $rootLastWriteTimeUtc = $rootItem.LastWriteTimeUtc.ToString("O")
    $boundary = $root.TrimEnd('\') + '\'
    $entries = @(
        Get-ChildItem -LiteralPath $root -Recurse -Force | ForEach-Object {
            $relative = $_.FullName.Substring($boundary.Length).Replace('\', '/')
            if ($_.PSIsContainer) {
                [pscustomobject][ordered]@{
                    type = "directory"
                    relativePath = $relative
                    sizeBytes = 0L
                    sha256 = $null
                    lastWriteTimeUtc = $_.LastWriteTimeUtc.ToString("O")
                }
            } else {
                [pscustomobject][ordered]@{
                    type = "file"
                    relativePath = $relative
                    sizeBytes = [long]$_.Length
                    sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
                    lastWriteTimeUtc = $_.LastWriteTimeUtc.ToString("O")
                }
            }
        } | Sort-Object type, relativePath
    )
    $canonical = @(
        "root`t$rootLastWriteTimeUtc"
        $entries | ForEach-Object {
            "{0}`t{1}`t{2}`t{3}`t{4}" -f
                $_.type, $_.relativePath, $_.sizeBytes, $_.sha256, $_.lastWriteTimeUtc
        }
    ) -join "`n"
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($canonical)
    $treeSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
    [pscustomobject][ordered]@{
        path = $root
        rootLastWriteTimeUtc = $rootLastWriteTimeUtc
        entryCount = $entries.Count
        directoryCount = @($entries | Where-Object type -eq "directory").Count
        fileCount = @($entries | Where-Object type -eq "file").Count
        sizeBytes = [long](($entries | Where-Object type -eq "file" |
            Measure-Object sizeBytes -Sum).Sum)
        sha256 = $treeSha256
        entries = $entries
    }
}

function Test-DirectoryTreeEvidenceEqual {
    param(
        [Parameter(Mandatory = $true)]$Before,
        [Parameter(Mandatory = $true)]$After
    )

    return (Test-PathEvidenceEqual -Left $Before.path -Right $After.path) -and
        [string]$Before.rootLastWriteTimeUtc -ceq [string]$After.rootLastWriteTimeUtc -and
        [int]$Before.entryCount -eq [int]$After.entryCount -and
        [int]$Before.directoryCount -eq [int]$After.directoryCount -and
        [int]$Before.fileCount -eq [int]$After.fileCount -and
        [long]$Before.sizeBytes -eq [long]$After.sizeBytes -and
        [string]$Before.sha256 -ceq [string]$After.sha256 -and
        (($Before.entries | ConvertTo-Json -Depth 8 -Compress) -ceq
            ($After.entries | ConvertTo-Json -Depth 8 -Compress))
}

function Get-IndependentCaptureDirectoryTreeEvidence {
    param([Parameter(Mandatory = $true)][string]$Path)

    $root = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "Required capture-style evidence tree is missing: $root"
    }
    $files = @(
        Get-ChildItem -LiteralPath $root -Recurse -File -Force |
            Sort-Object FullName |
            ForEach-Object {
                $relative = [IO.Path]::GetRelativePath($root, $_.FullName).
                    Replace([IO.Path]::DirectorySeparatorChar, '/')
                [pscustomobject][ordered]@{
                    relativePath = $relative
                    length = [long]$_.Length
                    lastWriteTimeUtc = $_.LastWriteTimeUtc.ToString(
                        'O',
                        [Globalization.CultureInfo]::InvariantCulture)
                    sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
                }
            })
    $contentLines = @($files | ForEach-Object {
            "{0}|{1}|{2}" -f $_.relativePath, $_.length, $_.sha256
        })
    $fullLines = @($files | ForEach-Object {
            "{0}|{1}|{2}|{3}" -f
                $_.relativePath, $_.length, $_.lastWriteTimeUtc, $_.sha256
        })
    [pscustomobject][ordered]@{
        root = $root
        fileCount = $files.Count
        totalBytes = [long](($files | Measure-Object -Property length -Sum).Sum ?? 0)
        contentSha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes(($contentLines -join "`n"))))
        fullSha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes(($fullLines -join "`n"))))
        files = $files
    }
}

function Test-CaptureDirectoryTreeEvidenceEqual {
    param($Before, $After)

    $treeShape = @(
        'root', 'fileCount', 'totalBytes', 'contentSha256',
        'fullSha256', 'files')
    $fileShape = @('relativePath', 'length', 'lastWriteTimeUtc', 'sha256')
    if ($null -eq $Before -or $null -eq $After -or
        -not (Test-ExactEvidencePropertyNames `
            -Value $Before `
            -Expected $treeShape) -or
        -not (Test-ExactEvidencePropertyNames `
            -Value $After `
            -Expected $treeShape) -or
        [string]::IsNullOrWhiteSpace([string]$Before.root) -or
        [string]::IsNullOrWhiteSpace([string]$After.root)) {
        return $false
    }

    $beforeFiles = @($Before.files)
    $afterFiles = @($After.files)
    if ([int]$Before.fileCount -le 0 -or
        [int]$After.fileCount -le 0 -or
        [long]$Before.totalBytes -le 0 -or
        [long]$After.totalBytes -le 0 -or
        $beforeFiles.Count -ne [int]$Before.fileCount -or
        $afterFiles.Count -ne [int]$After.fileCount) {
        return $false
    }
    foreach ($file in @($beforeFiles) + @($afterFiles)) {
        if (-not (Test-ExactEvidencePropertyNames `
                -Value $file `
                -Expected $fileShape) -or
            [string]::IsNullOrWhiteSpace([string]$file.relativePath) -or
            [long]$file.length -lt 0 -or
            [string]::IsNullOrWhiteSpace([string]$file.lastWriteTimeUtc) -or
            [string]$file.sha256 -cnotmatch '^[0-9A-F]{64}$') {
            return $false
        }
    }

    $beforeMeasuredTotal = [long](
        ($beforeFiles | Measure-Object -Property length -Sum).Sum ?? 0)
    $afterMeasuredTotal = [long](
        ($afterFiles | Measure-Object -Property length -Sum).Sum ?? 0)
    for ($fileIndex = 0; $fileIndex -lt $beforeFiles.Count; $fileIndex++) {
        $beforeFile = $beforeFiles[$fileIndex]
        $afterFile = $afterFiles[$fileIndex]
        if ([string]$beforeFile.relativePath -cne
                [string]$afterFile.relativePath -or
            [long]$beforeFile.length -ne [long]$afterFile.length -or
            -not (Test-TimestampEvidenceEqual `
                -Left $beforeFile.lastWriteTimeUtc `
                -Right $afterFile.lastWriteTimeUtc) -or
            [string]$beforeFile.sha256 -cne [string]$afterFile.sha256) {
            return $false
        }
    }
    return (Test-PathEvidenceEqual -Left $Before.root -Right $After.root) -and
        [int]$Before.fileCount -eq [int]$After.fileCount -and
        [long]$Before.totalBytes -eq [long]$After.totalBytes -and
        [long]$Before.totalBytes -eq $beforeMeasuredTotal -and
        [long]$After.totalBytes -eq $afterMeasuredTotal -and
        [string]$Before.contentSha256 -cmatch '^[0-9A-F]{64}$' -and
        [string]$Before.contentSha256 -ceq [string]$After.contentSha256 -and
        [string]$Before.fullSha256 -cmatch '^[0-9A-F]{64}$' -and
        [string]$Before.fullSha256 -ceq [string]$After.fullSha256
}

function Get-ExactRecycleBinItemEvidence {
    param([Parameter(Mandatory = $true)][string]$TargetPath)

    $target = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($TargetPath))
    $targetName = [IO.Path]::GetFileName($target)
    $targetParent = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetDirectoryName($target))
    $shell = $null
    $recycleFolder = $null
    $items = $null
    $matches = [Collections.Generic.List[object]]::new()
    try {
        $shell = New-Object -ComObject Shell.Application
        $recycleFolder = $shell.Namespace(10)
        if ($null -eq $recycleFolder) {
            throw "Windows Recycle Bin namespace 10 is unavailable."
        }
        $items = $recycleFolder.Items()
        for ($index = 0; $index -lt [int]$items.Count; $index++) {
            $item = $null
            try {
                $item = $items.Item($index)
                if ($null -eq $item) { continue }
                $originalName = [string]$item.Name
                $deletedFrom = [string](
                    $item.ExtendedProperty("System.Recycle.DeletedFrom"))
                if ([string]::IsNullOrWhiteSpace($originalName) -or
                    [string]::IsNullOrWhiteSpace($deletedFrom) -or
                    $originalName -cne $targetName) {
                    continue
                }
                try {
                    $normalizedDeletedFrom = [IO.Path]::TrimEndingDirectorySeparator(
                        [IO.Path]::GetFullPath($deletedFrom))
                    $originalPath = [IO.Path]::TrimEndingDirectorySeparator(
                        [IO.Path]::GetFullPath((Join-Path $normalizedDeletedFrom $originalName)))
                }
                catch {
                    continue
                }
                if (-not $normalizedDeletedFrom.Equals(
                        $targetParent,
                        [StringComparison]::OrdinalIgnoreCase) -or
                    -not $originalPath.Equals($target, [StringComparison]::OrdinalIgnoreCase)) {
                    continue
                }
                $matches.Add([pscustomobject][ordered]@{
                    originalName = $originalName
                    deletedFrom = $normalizedDeletedFrom
                    originalPath = $originalPath
                    recyclePath = [string]$item.Path
                    dateDeleted = [string](
                        $item.ExtendedProperty("System.Recycle.DateDeleted"))
                })
            }
            finally {
                if ($null -ne $item -and [Runtime.InteropServices.Marshal]::IsComObject($item)) {
                    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($item)
                }
            }
        }
    }
    finally {
        foreach ($comObject in @($items, $recycleFolder, $shell)) {
            if ($null -ne $comObject -and [Runtime.InteropServices.Marshal]::IsComObject($comObject)) {
                [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($comObject)
            }
        }
    }

    [pscustomobject][ordered]@{
        namespace = 10
        targetPath = $target
        exactName = $targetName
        exactDeletedFrom = $targetParent
        matchCount = $matches.Count
        matches = $matches.ToArray()
        observedAtUtc = [DateTimeOffset]::UtcNow
    }
}

function Wait-ExactRecycleBinItemCount {
    param(
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][ValidateRange(0, 8)][int]$ExpectedCount,
        [ValidateRange(1, 45)][int]$TimeoutSeconds = 30
    )

    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        $observation = Get-ExactRecycleBinItemEvidence -TargetPath $TargetPath
        if ([int]$observation.matchCount -eq $ExpectedCount) {
            $timer.Stop()
            return [pscustomobject][ordered]@{
                expectedCount = $ExpectedCount
                waitMilliseconds = $timer.Elapsed.TotalMilliseconds
                observation = $observation
            }
        }
        Start-Sleep -Milliseconds 200
    } while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds)
    $timer.Stop()
    throw "Recycle Bin exact-match timeout for '$TargetPath': expected $ExpectedCount, observed $($observation.matchCount)."
}

function Invoke-ExactRecycleBinRestore {
    param([Parameter(Mandatory = $true)][string]$TargetPath)

    $target = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($TargetPath))
    $targetName = [IO.Path]::GetFileName($target)
    $targetParent = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetDirectoryName($target))
    $shell = $null
    $recycleFolder = $null
    $items = $null
    $invoked = [Collections.Generic.List[object]]::new()
    try {
        $shell = New-Object -ComObject Shell.Application
        $recycleFolder = $shell.Namespace(10)
        if ($null -eq $recycleFolder) {
            throw "Windows Recycle Bin namespace 10 is unavailable during restore."
        }
        $items = $recycleFolder.Items()
        for ($index = [int]$items.Count - 1; $index -ge 0; $index--) {
            $item = $null
            try {
                $item = $items.Item($index)
                if ($null -eq $item) { continue }
                $originalName = [string]$item.Name
                $deletedFrom = [string](
                    $item.ExtendedProperty("System.Recycle.DeletedFrom"))
                if ([string]::IsNullOrWhiteSpace($deletedFrom) -or $originalName -cne $targetName) {
                    continue
                }
                try {
                    $normalizedDeletedFrom = [IO.Path]::TrimEndingDirectorySeparator(
                        [IO.Path]::GetFullPath($deletedFrom))
                    $originalPath = [IO.Path]::TrimEndingDirectorySeparator(
                        [IO.Path]::GetFullPath((Join-Path $normalizedDeletedFrom $originalName)))
                }
                catch {
                    continue
                }
                if (-not $normalizedDeletedFrom.Equals(
                        $targetParent,
                        [StringComparison]::OrdinalIgnoreCase) -or
                    -not $originalPath.Equals($target, [StringComparison]::OrdinalIgnoreCase)) {
                    continue
                }
                $invoked.Add([pscustomobject][ordered]@{
                    originalName = $originalName
                    deletedFrom = $normalizedDeletedFrom
                    originalPath = $originalPath
                    recyclePath = [string]$item.Path
                })
                $item.InvokeVerb("undelete")
            }
            finally {
                if ($null -ne $item -and [Runtime.InteropServices.Marshal]::IsComObject($item)) {
                    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($item)
                }
            }
        }
    }
    finally {
        foreach ($comObject in @($items, $recycleFolder, $shell)) {
            if ($null -ne $comObject -and [Runtime.InteropServices.Marshal]::IsComObject($comObject)) {
                [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($comObject)
            }
        }
    }

    [pscustomobject][ordered]@{
        targetPath = $target
        invokedCount = $invoked.Count
        exactItems = $invoked.ToArray()
        invokedAtUtc = [DateTimeOffset]::UtcNow
    }
}

function Wait-DirectoryExists {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateRange(1, 45)][int]$TimeoutSeconds = 30
    )

    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        if (Test-Path -LiteralPath $Path -PathType Container) {
            $timer.Stop()
            return $timer.Elapsed.TotalMilliseconds
        }
        Start-Sleep -Milliseconds 200
    } while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds)
    $timer.Stop()
    throw "Restored directory did not reappear within $TimeoutSeconds seconds: $Path"
}

function Write-JsonArtifact {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith(
            $artifactFullPath.TrimEnd('\') + '\',
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "JSON evidence artifact must stay under the current formal artifact root: $fullPath"
    }
    $parent = Split-Path -Parent $fullPath
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $temporaryPath = "$fullPath.tmp-$([Guid]::NewGuid().ToString('N'))"
    try {
        [IO.File]::WriteAllText(
            $temporaryPath,
            ($Value | ConvertTo-Json -Depth 30),
            [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporaryPath -Destination $fullPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
    return $fullPath
}

function Test-LibrarySelectionObservation {
    param(
        [Parameter(Mandatory = $true)]$Observation,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ExpectedNames
    )

    $selectedItems = @($Observation.selectedItems)
    $actualNames = @($selectedItems | ForEach-Object { [string]$_.name } | Sort-Object)
    $sortedExpectedNames = @($ExpectedNames | Sort-Object)
    $selectionPatternItems = @($Observation.selectionPatternSelectedItems)
    $selectionPatternNames = @(
        $selectionPatternItems | ForEach-Object { [string]$_.name } | Sort-Object)
    $patternMatchesRealized =
        $selectionPatternItems.Count -eq $selectedItems.Count -and
        ($selectionPatternNames -join "`n") -ceq ($actualNames -join "`n")
    $reportedEvidenceSourceIsExact = if ($patternMatchesRealized) {
        [bool]$Observation.selectionPatternMatchesRealized -and
        [string]$Observation.selectionEvidenceSource -ceq
            "SelectionPattern+SelectionItemPattern"
    } else {
        -not [bool]$Observation.selectionPatternMatchesRealized -and
        [string]$Observation.selectionEvidenceSource -ceq
            "SelectionItemPatternRealizedPeers"
    }
    return [string]$Observation.listAutomationId -ceq "Library.List" -and
        [string]$Observation.listControlType -ceq "ControlType.List" -and
        [bool]$Observation.selectionPattern -and
        [bool]$Observation.canSelectMultiple -and
        -not [bool]$Observation.isSelectionRequired -and
        [int]$Observation.selectionPatternSelectedCount -eq $selectionPatternItems.Count -and
        [int]$Observation.realizedFolderItemCount -ge $selectedItems.Count -and
        $reportedEvidenceSourceIsExact -and
        [int]$Observation.selectedCount -eq $sortedExpectedNames.Count -and
        ($actualNames -join "`n") -ceq ($sortedExpectedNames -join "`n") -and
        @($selectedItems | Where-Object {
            [string]$_.automationId -cne "Library.FolderItem" -or
            [string]$_.controlType -cne "ControlType.ListItem" -or
            -not [bool]$_.isSelected -or
            [string]$_.selectionContainer.automationId -cne "Library.List" -or
            [string]$_.selectionContainer.controlType -cne "ControlType.List" -or
            @($_.selectionContainer.runtimeId).Count -eq 0
        }).Count -eq 0
}

function Test-LibraryDialogScaleEvidence {
    param([Parameter(Mandatory = $true)]$Scale)

    return $null -ne $Scale -and [bool]$Scale.usesLayoutTransform -and
        [Math]::Abs([double]$Scale.requestedUiScale - 1.35) -le .000001 -and
        [Math]::Abs([double]$Scale.requestedFontScale - 1.25) -le .000001 -and
        [Math]::Abs([double]$Scale.actualRootScaleX - 1.35) -le .000001 -and
        [Math]::Abs([double]$Scale.actualRootScaleY - 1.35) -le .000001 -and
        [Math]::Abs([double]$Scale.messageFontSize - 16.25) -le .000001
}

function Test-IsolatedWindowDisplayScaleEvidence {
    param(
        [Parameter(Mandatory = $true)]$Runtime,
        [Parameter(Mandatory = $true)][string]$SettingsPath
    )

    $scale = $Runtime.window.displayScale
    if ($null -eq $scale) { return $false }
    try {
        $actualSettingsPath = [IO.Path]::GetFullPath([string]$scale.settingsPath)
        $expectedSettingsPath = [IO.Path]::GetFullPath($SettingsPath)
    }
    catch {
        return $false
    }
    return [bool]$scale.usesLayoutTransform -and
        [Math]::Abs([double]$scale.requestedUiScale - 1.35) -le .000001 -and
        [Math]::Abs([double]$scale.requestedFontScale - 1.25) -le .000001 -and
        [Math]::Abs([double]$scale.actualRootScaleX - 1.35) -le .000001 -and
        [Math]::Abs([double]$scale.actualRootScaleY - 1.35) -le .000001 -and
        [Math]::Abs([double]$scale.actualFontScale - 1.25) -le .000001 -and
        [bool]$scale.settingsFileExists -and [bool]$scale.settingsIsolatedFromWpf -and
        $actualSettingsPath.Equals($expectedSettingsPath, [StringComparison]::OrdinalIgnoreCase)
}

function Initialize-DisplayScaleRoot {
    param([Parameter(Mandatory = $true)][string]$LocalDataRoot)

    New-Item -ItemType Directory -Path $LocalDataRoot -Force | Out-Null
    $settingsPath = Join-Path $LocalDataRoot "display-scale-settings.json"
    $settings = [ordered]@{
        SchemaVersion = 1
        UiScale = 1.35
        FontScale = 1.25
        DisplayScaleInitialized = $true
    } | ConvertTo-Json
    [IO.File]::WriteAllText($settingsPath, $settings, [Text.UTF8Encoding]::new($false))
    return $settingsPath
}

function Invoke-GuiCaptureGate {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][hashtable]$Arguments
    )

    $captureScript = $captureHarnessPath
    $startedAt = [DateTimeOffset]::UtcNow
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $previousTemp = [Environment]::GetEnvironmentVariable("TEMP", "Process")
    $previousTmp = [Environment]::GetEnvironmentVariable("TMP", "Process")
    try {
        [Environment]::SetEnvironmentVariable("TEMP", $batchTempRoot, "Process")
        [Environment]::SetEnvironmentVariable("TMP", $batchTempRoot, "Process")
        $effectiveTempRoot =
            [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
        if (-not (Test-PathEvidenceEqual -Left $effectiveTempRoot -Right $batchTempRoot)) {
            throw "GUI gate '$Name' did not receive the isolated D-drive process TEMP/TMP root."
        }
        $output = @(& $captureScript @Arguments 2>&1 | ForEach-Object { [string]$_ })
    }
    catch {
        $output = @($_.Exception.ToString())
        $logPath = Join-Path $artifactFullPath "$Name.log"
        [IO.File]::WriteAllLines($logPath, $output, [Text.UTF8Encoding]::new($false))
        throw
    }
    finally {
        [Environment]::SetEnvironmentVariable("TEMP", $previousTemp, "Process")
        [Environment]::SetEnvironmentVariable("TMP", $previousTmp, "Process")
        $timer.Stop()
    }

    $logPath = Join-Path $artifactFullPath "$Name.log"
    [IO.File]::WriteAllLines($logPath, $output, [Text.UTF8Encoding]::new($false))
    $capture = ($output -join [Environment]::NewLine) | ConvertFrom-Json
    [pscustomobject]@{
        name = $Name
        startedAtUtc = $startedAt
        durationMilliseconds = $timer.Elapsed.TotalMilliseconds
        exitCode = 0
        logPath = $logPath
        logSha256 = (Get-FileHash -LiteralPath $logPath -Algorithm SHA256).Hash
        childProcessTempRoot = $effectiveTempRoot
        tempAndTmpProcessOverride = $true
        capture = $capture
    }
}

function Assert-StrictBuildGate {
    param([Parameter(Mandatory = $true)]$Gate)

    $text = Get-Content -LiteralPath $Gate.logPath -Raw
    $zeroWarnings = $text -match "0 Warning\(s\)" -or $text -match "0 个警告"
    $zeroErrors = $text -match "0 Error\(s\)" -or $text -match "0 个错误"
    if (-not $zeroWarnings -or -not $zeroErrors) {
        throw "Strict gate '$($Gate.name)' did not report 0 warnings and 0 errors."
    }
}

function Get-WindowsSliceSourceFileItems {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$CaptureHarnessPath,
        [Parameter(Mandatory = $true)][string]$FormalWrapperPath
    )

    $items = @(
        foreach ($relativeDirectory in @(
                "LumaChart.Core",
                "LumaChart.Application",
                "LumaChart.Online",
                "LumaChart.Storage.Abstractions",
                "LumaChart.Server",
                "LumaChart.Avalonia",
                "LumaChart.Avalonia.Specs",
                "LumaChart.Specs")) {
            Get-ChildItem `
                -LiteralPath (Join-Path $ProjectRoot $relativeDirectory) `
                -Recurse `
                -File |
                Where-Object {
                    $_.FullName -notmatch "\\(bin|obj|TestResults)\\" -and
                    $_.Extension -in ".cs", ".csproj"
                }
        }
        Get-Item -LiteralPath $CaptureHarnessPath
        Get-Item -LiteralPath $FormalWrapperPath
    )
    $items | Sort-Object FullName -Unique
}

function Get-SourceFileRuntimeEvidence {
    param([Parameter(Mandatory = $true)][object[]]$Items)

    $Items | ForEach-Object {
        [pscustomobject][ordered]@{
            path = [IO.Path]::GetFullPath([string]$_.FullName)
            sizeBytes = [long]$_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    }
}

$sourceBoundary = [IO.Path]::GetFullPath($projectRoot).TrimEnd('\') + '\'
$sourcePathsBefore = @(Get-WindowsSliceSourceFileItems `
        -ProjectRoot $projectRoot `
        -CaptureHarnessPath $captureHarnessPath `
        -FormalWrapperPath $formalWrapperPath)
$sourceHashesBefore = @(Get-SourceFileRuntimeEvidence -Items $sourcePathsBefore)
if ($sourceHashesBefore.Count -ne $sourcePathsBefore.Count -or
    @($sourceHashesBefore.path | Sort-Object -Unique).Count -ne
        $sourceHashesBefore.Count -or
    @($sourceHashesBefore | Where-Object {
            [string]$_.path -match "\\LumaChart\.(Android|iOS)(\\|$)"
        }).Count -ne 0 -or
    @($sourceHashesBefore | Where-Object {
            -not [IO.Path]::GetFullPath([string]$_.path).StartsWith(
                $sourceBoundary,
                [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $_.path -PathType Leaf)
        }).Count -ne 0) {
    throw "The initial sourceFiles snapshot is not a unique, complete Windows-only source set."
}

$avaloniaBuild = Invoke-DotNetGate -Name "avalonia-strict-build" -Arguments @(
    "build", ".\LumaChart.Avalonia\LumaChart.Avalonia.csproj",
    "-c", "Release", "--no-restore", "-warnaserror", "-m:1"
)
$avaloniaSpecsBuild = Invoke-DotNetGate -Name "avalonia-specs-strict-build" -Arguments @(
    "build", ".\LumaChart.Avalonia.Specs\LumaChart.Avalonia.Specs.csproj",
    "-c", "Release", "--no-restore", "-warnaserror", "-m:1"
)
$mainSpecsBuild = Invoke-DotNetGate -Name "main-specs-strict-build" -Arguments @(
    "build", ".\LumaChart.Specs\LumaChart.Specs.csproj",
    "-c", "Release", "--no-restore", "-warnaserror", "-m:1"
)
Assert-StrictBuildGate $avaloniaBuild
Assert-StrictBuildGate $avaloniaSpecsBuild
Assert-StrictBuildGate $mainSpecsBuild
$mainSpecsRun = Invoke-DotNetGate -Name "main-specs-run" -Arguments @(
    "run", "--project", ".\LumaChart.Specs\LumaChart.Specs.csproj",
    "-c", "Release", "--no-build"
)
$mainSpecsText = Get-Content -LiteralPath $mainSpecsRun.logPath -Raw
if ($mainSpecsText -notmatch "79/79 specs passed") {
    throw "Main specs did not report 79/79. See $($mainSpecsRun.logPath)"
}

$verticalSlicePath = Join-Path $artifactFullPath "avalonia-vertical-slice-v2.json"
$verticalSliceRun = Invoke-DotNetGate -Name "avalonia-vertical-slice-run" -Arguments @(
    "run", "--project", ".\LumaChart.Avalonia.Specs\LumaChart.Avalonia.Specs.csproj",
    "-c", "Release", "--no-build", "--", "--output", $verticalSlicePath
)
$verticalSlice = Get-RequiredJson $verticalSlicePath
$formalKeySoundR2EvidencePath = Join-Path $formalKeySoundR2Root "evidence.json"
$formalKeySoundR2EvidenceSha256 = (Get-FileHash -LiteralPath $formalKeySoundR2EvidencePath -Algorithm SHA256).Hash
if ($formalKeySoundR2EvidenceSha256 -cne "922DC630BB62D330FD024D8FD14314F2EF4C3F1719156056E645A05C23FE5D74") {
    throw "The formal Key-sound r2 evidence authority changed."
}
$formalKeySoundR2Evidence = Get-RequiredJson $formalKeySoundR2EvidencePath
$formalKeySoundR2SpecsPath = Join-Path $formalKeySoundR2Root "avalonia-vertical-slice-v2.json"
$formalKeySoundR2SpecsSha256 = (Get-FileHash -LiteralPath $formalKeySoundR2SpecsPath -Algorithm SHA256).Hash
if ($formalKeySoundR2SpecsSha256 -cne "A9D5C12791146357C7DFF3D49EA3049DB8E562EDD7D971F421F964CB5B495A73") {
    throw "The formal Key-sound r2 Avalonia Specs authority changed."
}
$formalKeySoundR2Specs = Get-RequiredJson $formalKeySoundR2SpecsPath
$formalKeySoundR2Checks = @($formalKeySoundR2Specs.Checks)
$formalKeySoundR2CheckNames = @($formalKeySoundR2Checks | ForEach-Object { [string]$_.Name })
$formalDisplayScaleR2EvidencePath = Join-Path $formalDisplayScaleR2Root "evidence.json"
$formalDisplayScaleR2EvidenceSha256 =
    (Get-FileHash -LiteralPath $formalDisplayScaleR2EvidencePath -Algorithm SHA256).Hash
if ($formalDisplayScaleR2EvidenceSha256 -cne
    "34D21EE8FBAB11A91D3DB44D16001173D4B40FDC91B9E5B5403C637248256A7B") {
    throw "The formal display-scale r2 evidence authority changed."
}
$formalDisplayScaleR2Evidence = Get-RequiredJson $formalDisplayScaleR2EvidencePath
$formalDisplayScaleR2SpecsPath = Join-Path $formalDisplayScaleR2Root "avalonia-vertical-slice-v2.json"
$formalDisplayScaleR2SpecsSha256 =
    (Get-FileHash -LiteralPath $formalDisplayScaleR2SpecsPath -Algorithm SHA256).Hash
if ($formalDisplayScaleR2SpecsSha256 -cne
    "DF82432245051C18F35489944AD8BB2E1D246C82CF807828F0A0B8616B071ADF") {
    throw "The formal display-scale r2 Avalonia Specs authority changed."
}
$formalDisplayScaleR2Specs = Get-RequiredJson $formalDisplayScaleR2SpecsPath
$formalDisplayScaleR2Checks = @($formalDisplayScaleR2Specs.Checks)
$formalDisplayScaleR2CheckNames = @($formalDisplayScaleR2Checks | ForEach-Object { [string]$_.Name })
$formalLibrarySearchR1EvidencePath = Join-Path $formalLibrarySearchR1Root "evidence.json"
$formalLibrarySearchR1EvidenceSha256 =
    (Get-FileHash -LiteralPath $formalLibrarySearchR1EvidencePath -Algorithm SHA256).Hash
if ($formalLibrarySearchR1EvidenceSha256 -cne
    "7AF2C09E96D177F311D5F27AA303F30BF0A8E7F388D80A40132D72672812ACEC") {
    throw "The formal library-search r1 evidence authority changed."
}
$formalLibrarySearchR1Evidence = Get-RequiredJson $formalLibrarySearchR1EvidencePath
$formalLibrarySearchR1SpecsPath = Join-Path $formalLibrarySearchR1Root "avalonia-vertical-slice-v2.json"
$formalLibrarySearchR1SpecsSha256 =
    (Get-FileHash -LiteralPath $formalLibrarySearchR1SpecsPath -Algorithm SHA256).Hash
if ($formalLibrarySearchR1SpecsSha256 -cne
    "03DA3A548AFB65551A6FA3C48FF9B9EC7BD203453D87964D65261AFEED186421") {
    throw "The formal library-search r1 Avalonia Specs authority changed."
}
$formalLibrarySearchR1Specs = Get-RequiredJson $formalLibrarySearchR1SpecsPath
$formalLibrarySearchR1Checks = @($formalLibrarySearchR1Specs.Checks)
$formalLibrarySearchR1CheckNames = @(
    $formalLibrarySearchR1Checks | ForEach-Object { [string]$_.Name })
$formalAudioPanelsR3EvidencePath = Join-Path $formalAudioPanelsR3Root "evidence.json"
$formalAudioPanelsR3EvidenceSha256 =
    (Get-FileHash -LiteralPath $formalAudioPanelsR3EvidencePath -Algorithm SHA256).Hash
if ($formalAudioPanelsR3EvidenceSha256 -cne
    "325A7253931A7355E05C984DDEDE85C8B0DF3C901B815AE50549215C59AEA000") {
    throw "The formal audio-panels r3 evidence authority changed."
}
$formalAudioPanelsR3Evidence = Get-RequiredJson $formalAudioPanelsR3EvidencePath
$formalAudioPanelsR3SpecsPath = Join-Path $formalAudioPanelsR3Root "avalonia-vertical-slice-v2.json"
$formalAudioPanelsR3SpecsSha256 =
    (Get-FileHash -LiteralPath $formalAudioPanelsR3SpecsPath -Algorithm SHA256).Hash
if ($formalAudioPanelsR3SpecsSha256 -cne
    "DA7A7D063078AEB3D2BB173877F4707177EA43EE089034AD6BC94F574087B328") {
    throw "The formal audio-panels r3 Avalonia Specs authority changed."
}
$formalAudioPanelsR3Specs = Get-RequiredJson $formalAudioPanelsR3SpecsPath
$formalAudioPanelsR3Checks = @($formalAudioPanelsR3Specs.Checks)
$formalAudioPanelsR3CheckNames = @(
    $formalAudioPanelsR3Checks | ForEach-Object { [string]$_.Name })
$formalLibraryDeletionR2EvidencePath = Join-Path $formalLibraryDeletionR2Root "evidence.json"
$formalLibraryDeletionR2EvidenceSha256 =
    (Get-FileHash -LiteralPath $formalLibraryDeletionR2EvidencePath -Algorithm SHA256).Hash
if ($formalLibraryDeletionR2EvidenceSha256 -cne
    "ACEA47D0E551D30A125AC3FE042A4CE6FDAAEE65D4156E9AC93B642C70C4E497") {
    throw "The formal library-deletion r2 evidence authority changed."
}
$formalLibraryDeletionR2Evidence = Get-RequiredJson $formalLibraryDeletionR2EvidencePath
$formalLibraryDeletionR2SpecsPath = Join-Path $formalLibraryDeletionR2Root "avalonia-vertical-slice-v2.json"
$formalLibraryDeletionR2SpecsSha256 =
    (Get-FileHash -LiteralPath $formalLibraryDeletionR2SpecsPath -Algorithm SHA256).Hash
if ($formalLibraryDeletionR2SpecsSha256 -cne
    "CD5E65349FD68BEF04DC637205C4821BB912AE3B1B2375507366221DA2A372D5") {
    throw "The formal library-deletion r2 Avalonia Specs authority changed."
}
$formalLibraryDeletionR2Specs = Get-RequiredJson $formalLibraryDeletionR2SpecsPath
$formalLibraryDeletionR2Checks = @($formalLibraryDeletionR2Specs.Checks)
$formalLibraryDeletionR2CheckNames = @(
    $formalLibraryDeletionR2Checks | ForEach-Object { [string]$_.Name })
$formalChartValidationR2EvidencePath = Join-Path $formalChartValidationR2Root "evidence.json"
$formalChartValidationR2EvidenceSha256 =
    (Get-FileHash -LiteralPath $formalChartValidationR2EvidencePath -Algorithm SHA256).Hash
if ($formalChartValidationR2EvidenceSha256 -cne
    "5658FA3A4B3CF334FF3FCCF8E3E3C1132772CFA19D4295566C50C8E9DE786578") {
    throw "The formal chart-validation r2 evidence authority changed."
}
$formalChartValidationR2Evidence = Get-RequiredJson $formalChartValidationR2EvidencePath
$formalChartValidationR2SpecsPath =
    Join-Path $formalChartValidationR2Root "avalonia-vertical-slice-v2.json"
$formalChartValidationR2SpecsSha256 =
    (Get-FileHash -LiteralPath $formalChartValidationR2SpecsPath -Algorithm SHA256).Hash
if ($formalChartValidationR2SpecsSha256 -cne
    "333BEC3850E0C49D3B68015FAD710D878C08A54BDF754F83ED3A0A0BEAF13E10") {
    throw "The formal chart-validation r2 Avalonia Specs authority changed."
}
$formalChartValidationR2Specs = Get-RequiredJson $formalChartValidationR2SpecsPath
$formalChartValidationR2Checks = @($formalChartValidationR2Specs.Checks)
$formalChartValidationR2CheckNames = @(
    $formalChartValidationR2Checks | ForEach-Object { [string]$_.Name })
$formalLibraryBatchDeletionR3EvidencePath =
    Join-Path $formalLibraryBatchDeletionR3Root "evidence.json"
$formalLibraryBatchDeletionR3EvidenceSha256 =
    (Get-FileHash -LiteralPath $formalLibraryBatchDeletionR3EvidencePath -Algorithm SHA256).Hash
if ($formalLibraryBatchDeletionR3EvidenceSha256 -cne
    "1820FFF08EA0EE08CFDDCF8277DB780B72BA37A244D1DB12CACB04F612DEFE81") {
    throw "The formal library-batch-deletion r3 evidence authority changed."
}
$formalLibraryBatchDeletionR3Evidence =
    Get-RequiredJson $formalLibraryBatchDeletionR3EvidencePath
$formalLibraryBatchDeletionR3SpecsPath =
    Join-Path $formalLibraryBatchDeletionR3Root "avalonia-vertical-slice-v2.json"
$formalLibraryBatchDeletionR3SpecsSha256 =
    (Get-FileHash -LiteralPath $formalLibraryBatchDeletionR3SpecsPath -Algorithm SHA256).Hash
if ($formalLibraryBatchDeletionR3SpecsSha256 -cne
    "53CBEBAB9D8B69D0342E99B8F44B5AD2DD5F825EFD987E05F784A1F6C3FC8E28") {
    throw "The formal library-batch-deletion r3 Avalonia Specs authority changed."
}
$formalLibraryBatchDeletionR3Specs =
    Get-RequiredJson $formalLibraryBatchDeletionR3SpecsPath
$formalLibraryBatchDeletionR3Checks = @($formalLibraryBatchDeletionR3Specs.Checks)
$formalLibraryBatchDeletionR3CheckNames = @(
    $formalLibraryBatchDeletionR3Checks | ForEach-Object { [string]$_.Name })
$formalMalodyFullPackageR3EvidencePath =
    Join-Path $formalMalodyFullPackageR3Root "evidence.json"
$formalMalodyFullPackageR3EvidenceSha256 =
    (Get-FileHash -LiteralPath $formalMalodyFullPackageR3EvidencePath -Algorithm SHA256).Hash
if ($formalMalodyFullPackageR3EvidenceSha256 -cne
    "B3E14C5155CC279A4CF765FBC22470859D62C29EB5E074920BD80C7ED14E4497") {
    throw "The formal Malody FullPackage r3 evidence authority changed."
}
$formalMalodyFullPackageR3Evidence =
    Get-RequiredJson $formalMalodyFullPackageR3EvidencePath
$formalMalodyFullPackageR3SpecsPath =
    Join-Path $formalMalodyFullPackageR3Root "avalonia-vertical-slice-v2.json"
$formalMalodyFullPackageR3SpecsSha256 =
    (Get-FileHash -LiteralPath $formalMalodyFullPackageR3SpecsPath -Algorithm SHA256).Hash
if ($formalMalodyFullPackageR3SpecsSha256 -cne
    "6E284C7B400FD08CBCF170D64061701DBE085A19CA4AB9C264C293250039B632") {
    throw "The formal Malody FullPackage r3 Avalonia Specs authority changed."
}
$formalMalodyFullPackageR3Specs =
    Get-RequiredJson $formalMalodyFullPackageR3SpecsPath
$formalMalodyFullPackageR3Checks = @($formalMalodyFullPackageR3Specs.Checks)
$formalMalodyFullPackageR3CheckNames = @(
    $formalMalodyFullPackageR3Checks | ForEach-Object { [string]$_.Name })
$formalMalodyFullPackageR3CheckNameSet =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateFormalMalodyFullPackageR3CheckNames = [Collections.Generic.List[string]]::new()
foreach ($checkName in $formalMalodyFullPackageR3CheckNames) {
    if (-not $formalMalodyFullPackageR3CheckNameSet.Add($checkName)) {
        $duplicateFormalMalodyFullPackageR3CheckNames.Add($checkName)
    }
}
$formalOsuFullPackageR2EvidencePath =
    Join-Path $formalOsuFullPackageR2Root "evidence.json"
$formalOsuFullPackageR2EvidenceSha256 =
    (Get-FileHash -LiteralPath $formalOsuFullPackageR2EvidencePath -Algorithm SHA256).Hash
if ($formalOsuFullPackageR2EvidenceSha256 -cne
    "4823B66CC1992626C2D334BDD81A15CD06C1BD1D6D13188F9DF3F401A9CED1B1") {
    throw "The formal osu! FullPackage r2 evidence authority changed."
}
$formalOsuFullPackageR2Evidence =
    Get-RequiredJson $formalOsuFullPackageR2EvidencePath
$formalOsuFullPackageR2SpecsPath =
    Join-Path $formalOsuFullPackageR2Root "avalonia-vertical-slice-v2.json"
$formalOsuFullPackageR2SpecsSha256 =
    (Get-FileHash -LiteralPath $formalOsuFullPackageR2SpecsPath -Algorithm SHA256).Hash
if ($formalOsuFullPackageR2SpecsSha256 -cne
    "555850881C6FFF7287FDDF83F18A182773EE946FB21323E0DFF95EB26CD6FE30") {
    throw "The formal osu! FullPackage r2 Avalonia Specs authority changed."
}
$formalOsuFullPackageR2Specs =
    Get-RequiredJson $formalOsuFullPackageR2SpecsPath
$formalOsuFullPackageR2Checks = @($formalOsuFullPackageR2Specs.Checks)
$formalOsuFullPackageR2CheckNames = @(
    $formalOsuFullPackageR2Checks | ForEach-Object { [string]$_.Name })
$formalOsuFullPackageR2CheckNameSet =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateFormalOsuFullPackageR2CheckNames = [Collections.Generic.List[string]]::new()
foreach ($checkName in $formalOsuFullPackageR2CheckNames) {
    if (-not $formalOsuFullPackageR2CheckNameSet.Add($checkName)) {
        $duplicateFormalOsuFullPackageR2CheckNames.Add($checkName)
    }
}
$formalCrossFormatFullPackageR1EvidencePath =
    Join-Path $formalCrossFormatFullPackageR1Root "evidence.json"
$formalCrossFormatFullPackageR1EvidenceSha256 =
    (Get-FileHash -LiteralPath $formalCrossFormatFullPackageR1EvidencePath -Algorithm SHA256).Hash
if ($formalCrossFormatFullPackageR1EvidenceSha256 -cne
    "37770CFD4ACB0F809175B5F120EBFAC520C0E6F422EE4D200A9AF1B3DE63CF7F") {
    throw "The formal cross-format FullPackage r1 evidence authority changed."
}
$formalCrossFormatFullPackageR1Evidence =
    Get-RequiredJson $formalCrossFormatFullPackageR1EvidencePath
$formalCrossFormatFullPackageR1SpecsPath =
    Join-Path $formalCrossFormatFullPackageR1Root "avalonia-vertical-slice-v2.json"
$formalCrossFormatFullPackageR1SpecsSha256 =
    (Get-FileHash -LiteralPath $formalCrossFormatFullPackageR1SpecsPath -Algorithm SHA256).Hash
if ($formalCrossFormatFullPackageR1SpecsSha256 -cne
    "C4D16F26D60FA0B08EE9053B6A50EA201DCB2F2FCB71642C6E685E11478A7513") {
    throw "The formal cross-format FullPackage r1 Avalonia Specs authority changed."
}
$formalCrossFormatFullPackageR1Specs =
    Get-RequiredJson $formalCrossFormatFullPackageR1SpecsPath
$formalCrossFormatFullPackageR1Checks = @($formalCrossFormatFullPackageR1Specs.Checks)
$formalCrossFormatFullPackageR1CheckNames = @(
    $formalCrossFormatFullPackageR1Checks | ForEach-Object { [string]$_.Name })
$formalCrossFormatFullPackageR1CheckNameSet =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateFormalCrossFormatFullPackageR1CheckNames =
    [Collections.Generic.List[string]]::new()
foreach ($checkName in $formalCrossFormatFullPackageR1CheckNames) {
    if (-not $formalCrossFormatFullPackageR1CheckNameSet.Add($checkName)) {
        $duplicateFormalCrossFormatFullPackageR1CheckNames.Add($checkName)
    }
}
$formalOsuToMalodyFullPackageR7EvidencePath =
    Join-Path $formalOsuToMalodyFullPackageR7Root "evidence.json"
$formalOsuToMalodyFullPackageR7EvidenceSha256 =
    (Get-FileHash -LiteralPath $formalOsuToMalodyFullPackageR7EvidencePath -Algorithm SHA256).Hash
if ($formalOsuToMalodyFullPackageR7EvidenceSha256 -cne
    "0BC6B04F9C52EDEF4657BC970B9BEA5B06AD9EE73636F3581E7A06FD43DBD434") {
    throw "The formal osu-to-Malody FullPackage r7 evidence authority changed."
}
$formalOsuToMalodyFullPackageR7Evidence =
    Get-RequiredJson $formalOsuToMalodyFullPackageR7EvidencePath
$formalOsuToMalodyFullPackageR7SpecsPath =
    Join-Path $formalOsuToMalodyFullPackageR7Root "avalonia-vertical-slice-v2.json"
$formalOsuToMalodyFullPackageR7SpecsSha256 =
    (Get-FileHash -LiteralPath $formalOsuToMalodyFullPackageR7SpecsPath -Algorithm SHA256).Hash
if ($formalOsuToMalodyFullPackageR7SpecsSha256 -cne
    "5EC687E4C96D7CA1C3981B91C27304A4CF741CAA0EFE39E7D04F3B01D2CE3A72") {
    throw "The formal osu-to-Malody FullPackage r7 Avalonia Specs authority changed."
}
$formalOsuToMalodyFullPackageR7Specs =
    Get-RequiredJson $formalOsuToMalodyFullPackageR7SpecsPath
$formalOsuToMalodyFullPackageR7Checks = @($formalOsuToMalodyFullPackageR7Specs.Checks)
$formalOsuToMalodyFullPackageR7CheckNames = @(
    $formalOsuToMalodyFullPackageR7Checks | ForEach-Object { [string]$_.Name })
$formalOsuToMalodyFullPackageR7CheckNameSet =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateFormalOsuToMalodyFullPackageR7CheckNames =
    [Collections.Generic.List[string]]::new()
foreach ($checkName in $formalOsuToMalodyFullPackageR7CheckNames) {
    if (-not $formalOsuToMalodyFullPackageR7CheckNameSet.Add($checkName)) {
        $duplicateFormalOsuToMalodyFullPackageR7CheckNames.Add($checkName)
    }
}
$formalChartExportModesR1EvidencePath =
    Join-Path $formalChartExportModesR1Root "evidence.json"
$formalChartExportModesR1EvidenceSha256 =
    (Get-FileHash -LiteralPath $formalChartExportModesR1EvidencePath -Algorithm SHA256).Hash
if ($formalChartExportModesR1EvidenceSha256 -cne
    "BA3FE5560D1FC1E9C6EFD915F67DDFF8F5D362CB951B024D97BB41EC01EE746E") {
    throw "The formal chart-export modes r1 evidence authority changed."
}
$formalChartExportModesR1Evidence =
    Get-RequiredJson $formalChartExportModesR1EvidencePath
$formalChartExportModesR1SpecsPath =
    Join-Path $formalChartExportModesR1Root "avalonia-vertical-slice-v2.json"
$formalChartExportModesR1SpecsSha256 =
    (Get-FileHash -LiteralPath $formalChartExportModesR1SpecsPath -Algorithm SHA256).Hash
if ($formalChartExportModesR1SpecsSha256 -cne
    "1DE0878032371C2CD87E7F19DB76E012BE70016C81725EA3AE7B2FAFF74B62C4") {
    throw "The formal chart-export modes r1 Avalonia Specs authority changed."
}
$formalChartExportModesR1Specs = Get-RequiredJson $formalChartExportModesR1SpecsPath
$formalChartExportModesR1Checks = @($formalChartExportModesR1Specs.Checks)
$formalChartExportModesR1CheckNames = @(
    $formalChartExportModesR1Checks | ForEach-Object { [string]$_.Name })
$formalChartExportModesR1CheckNameSet =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateFormalChartExportModesR1CheckNames =
    [Collections.Generic.List[string]]::new()
foreach ($checkName in $formalChartExportModesR1CheckNames) {
    if (-not $formalChartExportModesR1CheckNameSet.Add($checkName)) {
        $duplicateFormalChartExportModesR1CheckNames.Add($checkName)
    }
}
$osuPickerFilenameSupersessionZeroBasedIndex = 78
$osuPickerFilenameSupersessionOneBasedIndex = 79
$supersededOsuWrongExtensionCheckName =
    "osu-full-package-rejects-invalid-difficulty-and-wrong-extension-before-staging"
$replacementOsuPickerFilenameCheckName =
    "osu-full-package-rejects-invalid-difficulty-and-preserves-picker-filename"
$authoritySupersessionDefinitionMismatches = [Collections.Generic.List[string]]::new()
foreach ($authority in @(
        [pscustomobject]@{
            name = "formal-osu-full-package-r2"
            checkNames = $formalOsuFullPackageR2CheckNames
        },
        [pscustomobject]@{
            name = "formal-cross-format-full-package-r1"
            checkNames = $formalCrossFormatFullPackageR1CheckNames
        },
        [pscustomobject]@{
            name = "formal-osu-to-malody-full-package-r7"
            checkNames = $formalOsuToMalodyFullPackageR7CheckNames
        })) {
    $authorityCheckNames = @($authority.checkNames)
    if ($authorityCheckNames.Count -le $osuPickerFilenameSupersessionZeroBasedIndex -or
        [string]$authorityCheckNames[$osuPickerFilenameSupersessionZeroBasedIndex] -cne
            $supersededOsuWrongExtensionCheckName) {
        $authoritySupersessionDefinitionMismatches.Add([string]$authority.name)
    }
}
$currentChecks = @($verticalSlice.Checks)
$currentCheckNames = @($currentChecks | ForEach-Object { [string]$_.Name })
$formalChartExportModesR1PrefixMismatches = [Collections.Generic.List[string]]::new()
for ($checkIndex = 0;
     $checkIndex -lt $formalChartExportModesR1CheckNames.Count;
     $checkIndex++) {
    if ($checkIndex -ge $currentCheckNames.Count -or
        $currentCheckNames[$checkIndex] -cne
            $formalChartExportModesR1CheckNames[$checkIndex]) {
        $formalChartExportModesR1PrefixMismatches.Add([string]$checkIndex)
    }
}
$formalCrossFormatFullPackageR1OrdinalMismatches =
    [Collections.Generic.List[string]]::new()
for ($checkIndex = 0;
     $checkIndex -lt $formalCrossFormatFullPackageR1CheckNames.Count;
     $checkIndex++) {
    $expectedCheckName = if (
        $checkIndex -eq $osuPickerFilenameSupersessionZeroBasedIndex) {
        $replacementOsuPickerFilenameCheckName
    } else {
        $formalCrossFormatFullPackageR1CheckNames[$checkIndex]
    }
    if ($checkIndex -ge $currentCheckNames.Count -or
        $currentCheckNames[$checkIndex] -cne
            $expectedCheckName) {
        $formalCrossFormatFullPackageR1OrdinalMismatches.Add([string]$checkIndex)
    }
}
$formalOsuToMalodyFullPackageR7PrefixMismatches =
    [Collections.Generic.List[string]]::new()
for ($checkIndex = 0;
     $checkIndex -lt $formalOsuToMalodyFullPackageR7CheckNames.Count;
     $checkIndex++) {
    $expectedCheckName = if (
        $checkIndex -eq $osuPickerFilenameSupersessionZeroBasedIndex) {
        $replacementOsuPickerFilenameCheckName
    } else {
        $formalOsuToMalodyFullPackageR7CheckNames[$checkIndex]
    }
    if ($checkIndex -ge $currentCheckNames.Count -or
        $currentCheckNames[$checkIndex] -cne
            $expectedCheckName) {
        $formalOsuToMalodyFullPackageR7PrefixMismatches.Add([string]$checkIndex)
    }
}
$formalLibraryDeletionR2CheckNameSet =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateFormalLibraryDeletionR2CheckNames = [Collections.Generic.List[string]]::new()
foreach ($checkName in $formalLibraryDeletionR2CheckNames) {
    if (-not $formalLibraryDeletionR2CheckNameSet.Add($checkName)) {
        $duplicateFormalLibraryDeletionR2CheckNames.Add($checkName)
    }
}
$formalChartValidationR2CheckNameSet =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateFormalChartValidationR2CheckNames = [Collections.Generic.List[string]]::new()
foreach ($checkName in $formalChartValidationR2CheckNames) {
    if (-not $formalChartValidationR2CheckNameSet.Add($checkName)) {
        $duplicateFormalChartValidationR2CheckNames.Add($checkName)
    }
}
$formalLibraryBatchDeletionR3CheckNameSet =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateFormalLibraryBatchDeletionR3CheckNames = [Collections.Generic.List[string]]::new()
foreach ($checkName in $formalLibraryBatchDeletionR3CheckNames) {
    if (-not $formalLibraryBatchDeletionR3CheckNameSet.Add($checkName)) {
        $duplicateFormalLibraryBatchDeletionR3CheckNames.Add($checkName)
    }
}
$currentCheckNameSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateCurrentCheckNames = [Collections.Generic.List[string]]::new()
foreach ($checkName in $currentCheckNames) {
    if (-not $currentCheckNameSet.Add($checkName)) {
        $duplicateCurrentCheckNames.Add($checkName)
    }
}
$requiredWindowsDisplayScaleCheckNames = @($formalDisplayScaleR2CheckNames |
    Where-Object { $_ -notin $formalKeySoundR2CheckNames })
$requiredWindowsLibrarySearchCheckNames = @($formalLibrarySearchR1CheckNames |
    Where-Object { $_ -notin $formalDisplayScaleR2CheckNames })
$requiredWindowsAudioPanelCheckNames = @($formalAudioPanelsR3CheckNames |
    Where-Object { $_ -notin $formalLibrarySearchR1CheckNames })
$requiredWindowsLibraryDeletionCheckNames = @($formalLibraryDeletionR2CheckNames |
    Where-Object { $_ -notin $formalAudioPanelsR3CheckNames })
$requiredWindowsChartValidationCheckNames = @(
    "desktop-chart-validation-keeps-core-draft-ignore-contract"
    "desktop-chart-validation-manual-success-copy-matches-wpf"
    "desktop-chart-validation-preserves-core-beat-then-lane-order-and-exact-first-beat"
    "desktop-chart-validation-counts-overlap-and-crossing-from-core-results"
    "desktop-chart-validation-manual-error-copy-matches-wpf"
    "desktop-chart-validation-save-blocking-copy-matches-wpf"
    "desktop-chart-validation-navigation-selects-first-notes-and-reveals-hidden-groups"
)
$requiredWindowsChartValidationCheckNameSet =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateRequiredWindowsChartValidationCheckNames = [Collections.Generic.List[string]]::new()
foreach ($checkName in $requiredWindowsChartValidationCheckNames) {
    if (-not $requiredWindowsChartValidationCheckNameSet.Add($checkName)) {
        $duplicateRequiredWindowsChartValidationCheckNames.Add($checkName)
    }
}
$missingFormalLibraryDeletionR2CheckNames = @($formalLibraryDeletionR2CheckNames | Where-Object {
    -not $currentCheckNameSet.Contains($_)
})
$additionalWindowsChartValidationCheckNames = @($currentCheckNames | Where-Object {
    -not $formalLibraryDeletionR2CheckNameSet.Contains($_) -and
    $formalChartValidationR2CheckNameSet.Contains($_)
})
$unexpectedAdditionalWindowsChartValidationCheckNames = @(
    $additionalWindowsChartValidationCheckNames | Where-Object {
        -not $requiredWindowsChartValidationCheckNameSet.Contains($_)
    })
$currentFormalLibraryDeletionR2CheckNames = @($currentCheckNames | Where-Object {
    $formalLibraryDeletionR2CheckNameSet.Contains($_)
})
$formalLibraryDeletionR2OrdinalMismatches = [Collections.Generic.List[string]]::new()
for ($checkIndex = 0; $checkIndex -lt $formalLibraryDeletionR2CheckNames.Count; $checkIndex++) {
    if ($checkIndex -ge $currentFormalLibraryDeletionR2CheckNames.Count -or
        $currentFormalLibraryDeletionR2CheckNames[$checkIndex] -cne
            $formalLibraryDeletionR2CheckNames[$checkIndex]) {
        $formalLibraryDeletionR2OrdinalMismatches.Add([string]$checkIndex)
    }
}
$chartValidationOrdinalMismatches = [Collections.Generic.List[string]]::new()
for ($checkIndex = 0; $checkIndex -lt $requiredWindowsChartValidationCheckNames.Count; $checkIndex++) {
    if ($checkIndex -ge $additionalWindowsChartValidationCheckNames.Count -or
        $additionalWindowsChartValidationCheckNames[$checkIndex] -cne
            $requiredWindowsChartValidationCheckNames[$checkIndex]) {
        $chartValidationOrdinalMismatches.Add([string]$checkIndex)
    }
}
$missingFormalChartValidationR2CheckNames = @(
    $formalChartValidationR2CheckNames | Where-Object { -not $currentCheckNameSet.Contains($_) })
$additionalCurrentCheckNamesAfterChartValidationR2 = @(
    $currentCheckNames | Where-Object { -not $formalChartValidationR2CheckNameSet.Contains($_) })
$currentFormalChartValidationR2CheckNames = @(
    $currentCheckNames | Where-Object { $formalChartValidationR2CheckNameSet.Contains($_) })
$formalChartValidationR2OrdinalMismatches = [Collections.Generic.List[string]]::new()
for ($checkIndex = 0; $checkIndex -lt $formalChartValidationR2CheckNames.Count; $checkIndex++) {
    if ($checkIndex -ge $currentFormalChartValidationR2CheckNames.Count -or
        $currentFormalChartValidationR2CheckNames[$checkIndex] -cne
            $formalChartValidationR2CheckNames[$checkIndex]) {
        $formalChartValidationR2OrdinalMismatches.Add([string]$checkIndex)
    }
}
$requiredWindowsMalodyFullPackageCheckNames = @(
    "malody-full-package-real-source-has-eight-sibling-mc"
    "malody-full-package-sibling-compact-test-is-discriminating"
    "malody-full-package-dirty-working-snapshot-is-discriminating"
    "malody-full-package-result-points-to-original-main-name"
    "malody-full-package-keeps-eight-sibling-mc-and-compacts-every-entry"
    "malody-full-package-excludes-other-charts-archives-parts-and-shadow-mc"
    "malody-full-package-resolves-working-resources-and-preserves-source-collisions-as-suffix-two"
    "malody-full-package-result-entry-count-matches-archive"
    "malody-full-package-main-chart-is-current-dirty-document-with-exact-rational-beat"
    "malody-full-package-fresh-import-retains-structure-and-resources"
    "malody-full-package-export-does-not-save-dirty-tab-or-touch-source-tree"
    "malody-full-package-success-cleans-only-owned-scratch-directory"
    "malody-full-package-failure-cleans-owned-scratch-and-preserves-source"
    "malody-full-package-open-tab-can-export-after-source-file-is-externally-removed"
    "avalonia-normal-shutdown-cleanup-removes-only-owned-session-scratch"
    "malody-full-package-prunes-managed-scratch-when-source-contains-staging"
    "malody-full-package-file-symlink-direct-validation-capability-and-coverage-are-explicitly-recorded"
    "malody-full-package-materializes-source-contained-resource-when-reparse-or-pruning-omits-staging-copy"
    "malody-full-package-directory-junction-spec-created-real-reparse-point"
    "malody-full-package-materializes-directory-junction-resource-instead-of-emitting-broken-reference"
    "malody-full-package-directory-collision-uses-suffix-two-and-preserves-directory-content"
    "malody-full-package-cancellation-after-zip-validation-before-commit-preserves-old-target-and-cleans-temp-archive"
    "malody-full-package-failed-atomic-replace-preserves-old-target-and-cleans-temp-archive"
    "malody-full-package-successfully-replaces-old-target-from-same-directory-temp-with-valid-archive"
)
$requiredWindowsMalodyFullPackageCheckNameSet =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateRequiredWindowsMalodyFullPackageCheckNames = [Collections.Generic.List[string]]::new()
foreach ($checkName in $requiredWindowsMalodyFullPackageCheckNames) {
    if (-not $requiredWindowsMalodyFullPackageCheckNameSet.Add($checkName)) {
        $duplicateRequiredWindowsMalodyFullPackageCheckNames.Add($checkName)
    }
}
$requiredWindowsOsuFullPackageCheckNames = @(
    "osu-full-package-real-source-has-two-sibling-osu"
    "osu-full-package-dirty-working-snapshot-is-discriminating"
    "osu-full-package-result-points-to-original-main-name"
    "osu-full-package-keeps-osu-siblings-and-excludes-other-chart-artifacts"
    "osu-full-package-result-entry-count-matches-archive"
    "osu-full-package-main-entry-is-v14-with-requested-difficulty-and-dirty-metadata"
    "osu-full-package-fresh-import-retains-dirty-chart-difficulty-and-resources"
    "osu-full-package-sibling-osu-bytes-are-exact-source-archive-fresh"
    "osu-full-package-export-does-not-save-dirty-tab-or-touch-source-tree"
    "osu-full-package-success-cleans-only-owned-scratch-directory"
    "osu-full-package-rejects-invalid-difficulty-and-preserves-picker-filename"
)
$requiredWindowsOsuFullPackageCheckNameSet =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateRequiredWindowsOsuFullPackageCheckNames = [Collections.Generic.List[string]]::new()
foreach ($checkName in $requiredWindowsOsuFullPackageCheckNames) {
    if (-not $requiredWindowsOsuFullPackageCheckNameSet.Add($checkName)) {
        $duplicateRequiredWindowsOsuFullPackageCheckNames.Add($checkName)
    }
}
$requiredWindowsCrossFormatFullPackageCheckNames = @(
    "cross-format-mc-to-osz-real-dirty-source-is-discriminating"
    "cross-format-mc-to-osz-emits-one-target-chart-and-excludes-all-sibling-decoys"
    "cross-format-mc-to-osz-retains-dirty-snapshot-difficulty-and-resources"
    "cross-format-mc-to-osz-preserves-session-source-working-and-atomic-scratch"
    "cross-format-osu-to-mcz-real-dirty-source-is-discriminating"
    "cross-format-osu-to-mcz-emits-one-compact-target-chart-and-excludes-all-sibling-decoys"
    "cross-format-osu-to-mcz-retains-dirty-exact-beat-and-resources"
    "cross-format-osu-to-mcz-preserves-session-source-working-and-atomic-scratch"
)
$requiredWindowsCrossFormatFullPackageCheckNameSet =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateRequiredWindowsCrossFormatFullPackageCheckNames =
    [Collections.Generic.List[string]]::new()
foreach ($checkName in $requiredWindowsCrossFormatFullPackageCheckNames) {
    if (-not $requiredWindowsCrossFormatFullPackageCheckNameSet.Add($checkName)) {
        $duplicateRequiredWindowsCrossFormatFullPackageCheckNames.Add($checkName)
    }
}
$requiredWindowsEvidenceNoteFocusCheckName =
    "evidence-note-focus-preserves-exact-authored-beat-and-tap-fallback"
$requiredWindowsChartExportCheckNames = @(
    "four-mode-planner-defaults-extensions-and-hidden-rate-fields"
    "four-mode-rates-round-to-four-decimals-append-max-and-enforce-one-to-one-hundred"
    "rate-package-prefers-live-package-source-resources-over-localized-cache"
    "rate-package-one-x-core-runs-off-caller-thread"
    "single-chart-export-uses-dirty-clone-without-source-or-resource-mutation"
    "single-rate-package-transcoder-and-rational-transform-match-wpf"
    "rate-pack-transcoder-preserve-pitch-and-shared-resource-semantics"
    "malody-rate-package-is-compact-and-osz-package-is-flat-compatible"
    "rate-package-cancel-before-commit-preserves-target-and-cleans-scratch"
    "rate-package-cancel-during-compression-preserves-target-and-cleans-scratch"
    "rate-package-failed-atomic-replace-preserves-target-and-cleans-scratch"
    "windows-audio-adapter-transcodes-valid-rate-and-preserve-pitch-ogg"
    "windows-audio-adapter-rate-and-preserve-pitch-dominant-frequency"
    "single-chart-commit-boundary-does-not-report-late-cancellation"
    "single-chart-cancel-after-same-directory-staging-preserves-existing-target-and-cleans-part"
    "single-chart-failed-atomic-replace-preserves-existing-target-and-cleans-part"
    "single-chart-successfully-atomically-replaces-existing-target-from-same-directory-part"
)
$requiredWindowsChartExportCheckNameSet =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$duplicateRequiredWindowsChartExportCheckNames =
    [Collections.Generic.List[string]]::new()
foreach ($checkName in $requiredWindowsChartExportCheckNames) {
    if (-not $requiredWindowsChartExportCheckNameSet.Add($checkName)) {
        $duplicateRequiredWindowsChartExportCheckNames.Add($checkName)
    }
}
$currentWindowsChartExportCheckNames = @($currentCheckNames | Where-Object {
        $requiredWindowsChartExportCheckNameSet.Contains($_)
    })
$windowsChartExportOrdinalMismatches = [Collections.Generic.List[string]]::new()
for ($checkIndex = 0;
     $checkIndex -lt $requiredWindowsChartExportCheckNames.Count;
     $checkIndex++) {
    $expectedCurrentIndex = 277 + $checkIndex
    if ($checkIndex -ge $currentWindowsChartExportCheckNames.Count -or
        $currentWindowsChartExportCheckNames[$checkIndex] -cne
            $requiredWindowsChartExportCheckNames[$checkIndex] -or
        $expectedCurrentIndex -ge $currentCheckNames.Count -or
        $currentCheckNames[$expectedCurrentIndex] -cne
            $requiredWindowsChartExportCheckNames[$checkIndex]) {
        $windowsChartExportOrdinalMismatches.Add([string]$checkIndex)
    }
}
$missingFormalLibraryBatchDeletionR3CheckNames = @(
    $formalLibraryBatchDeletionR3CheckNames |
        Where-Object { -not $currentCheckNameSet.Contains($_) })
$currentFormalLibraryBatchDeletionR3CheckNames = @(
    $currentCheckNames |
        Where-Object { $formalLibraryBatchDeletionR3CheckNameSet.Contains($_) })
$formalLibraryBatchDeletionR3OrdinalMismatches = [Collections.Generic.List[string]]::new()
for ($checkIndex = 0;
     $checkIndex -lt $formalLibraryBatchDeletionR3CheckNames.Count;
     $checkIndex++) {
    if ($checkIndex -ge $currentFormalLibraryBatchDeletionR3CheckNames.Count -or
        $currentFormalLibraryBatchDeletionR3CheckNames[$checkIndex] -cne
            $formalLibraryBatchDeletionR3CheckNames[$checkIndex]) {
        $formalLibraryBatchDeletionR3OrdinalMismatches.Add([string]$checkIndex)
    }
}
$additionalCurrentCheckNamesAfterLibraryBatchDeletionR3 = @(
    $currentCheckNames | Where-Object {
        -not $formalLibraryBatchDeletionR3CheckNameSet.Contains($_)
    })
$currentMalodyFullPackageCheckIndices = [Collections.Generic.List[int]]::new()
$currentOsuFullPackageCheckIndices = [Collections.Generic.List[int]]::new()
$currentCrossFormatFullPackageCheckIndices = [Collections.Generic.List[int]]::new()
for ($currentCheckIndex = 0;
     $currentCheckIndex -lt $currentCheckNames.Count;
     $currentCheckIndex++) {
    if ($requiredWindowsMalodyFullPackageCheckNameSet.Contains(
            $currentCheckNames[$currentCheckIndex])) {
        $currentMalodyFullPackageCheckIndices.Add($currentCheckIndex)
    }
    if ($requiredWindowsOsuFullPackageCheckNameSet.Contains(
            $currentCheckNames[$currentCheckIndex])) {
        $currentOsuFullPackageCheckIndices.Add($currentCheckIndex)
    }
    if ($requiredWindowsCrossFormatFullPackageCheckNameSet.Contains(
            $currentCheckNames[$currentCheckIndex])) {
        $currentCrossFormatFullPackageCheckIndices.Add($currentCheckIndex)
    }
}
$expectedMalodyFullPackageStartIndex = 44
$malodyFullPackagePlacementMismatches = [Collections.Generic.List[string]]::new()
for ($checkIndex = 0;
     $checkIndex -lt $currentMalodyFullPackageCheckIndices.Count;
     $checkIndex++) {
    $expectedCurrentCheckIndex = $expectedMalodyFullPackageStartIndex + $checkIndex
    if ($currentMalodyFullPackageCheckIndices[$checkIndex] -ne
            $expectedCurrentCheckIndex) {
        $malodyFullPackagePlacementMismatches.Add(
            "$checkIndex=$($currentMalodyFullPackageCheckIndices[$checkIndex])")
    }
}
$expectedOsuFullPackageStartIndex = 68
$osuFullPackagePlacementMismatches = [Collections.Generic.List[string]]::new()
for ($checkIndex = 0;
     $checkIndex -lt $currentOsuFullPackageCheckIndices.Count;
     $checkIndex++) {
    $expectedCurrentCheckIndex = $expectedOsuFullPackageStartIndex + $checkIndex
    if ($currentOsuFullPackageCheckIndices[$checkIndex] -ne
            $expectedCurrentCheckIndex) {
        $osuFullPackagePlacementMismatches.Add(
            "$checkIndex=$($currentOsuFullPackageCheckIndices[$checkIndex])")
    }
}
$unexpectedAdditionalWindowsFullPackageCheckNames = @(
    $additionalCurrentCheckNamesAfterLibraryBatchDeletionR3 | Where-Object {
        -not $requiredWindowsMalodyFullPackageCheckNameSet.Contains($_) -and
        -not $requiredWindowsOsuFullPackageCheckNameSet.Contains($_) -and
        -not $requiredWindowsCrossFormatFullPackageCheckNameSet.Contains($_) -and
        -not $requiredWindowsChartExportCheckNameSet.Contains($_) -and
        [string]$_ -cne $requiredWindowsEvidenceNoteFocusCheckName
    })
$currentMalodyFullPackageCheckNames = @(
    $currentCheckNames | Where-Object {
        $requiredWindowsMalodyFullPackageCheckNameSet.Contains($_)
    })
$currentOsuFullPackageCheckNames = @(
    $currentCheckNames | Where-Object {
        $requiredWindowsOsuFullPackageCheckNameSet.Contains($_)
    })
$currentCrossFormatFullPackageCheckNames = @(
    $currentCheckNames | Where-Object {
        $requiredWindowsCrossFormatFullPackageCheckNameSet.Contains($_)
    })
$malodyFullPackageOrdinalMismatches = [Collections.Generic.List[string]]::new()
for ($checkIndex = 0;
     $checkIndex -lt $requiredWindowsMalodyFullPackageCheckNames.Count;
     $checkIndex++) {
    if ($checkIndex -ge $currentMalodyFullPackageCheckNames.Count -or
        $currentMalodyFullPackageCheckNames[$checkIndex] -cne
            $requiredWindowsMalodyFullPackageCheckNames[$checkIndex]) {
        $malodyFullPackageOrdinalMismatches.Add([string]$checkIndex)
    }
}
$osuFullPackageOrdinalMismatches = [Collections.Generic.List[string]]::new()
for ($checkIndex = 0;
     $checkIndex -lt $requiredWindowsOsuFullPackageCheckNames.Count;
     $checkIndex++) {
    if ($checkIndex -ge $currentOsuFullPackageCheckNames.Count -or
        $currentOsuFullPackageCheckNames[$checkIndex] -cne
            $requiredWindowsOsuFullPackageCheckNames[$checkIndex]) {
        $osuFullPackageOrdinalMismatches.Add([string]$checkIndex)
    }
}
$crossFormatFullPackageOrdinalMismatches = [Collections.Generic.List[string]]::new()
for ($checkIndex = 0;
     $checkIndex -lt $requiredWindowsCrossFormatFullPackageCheckNames.Count;
     $checkIndex++) {
    if ($checkIndex -ge $currentCrossFormatFullPackageCheckNames.Count -or
        $currentCrossFormatFullPackageCheckNames[$checkIndex] -cne
            $requiredWindowsCrossFormatFullPackageCheckNames[$checkIndex]) {
        $crossFormatFullPackageOrdinalMismatches.Add([string]$checkIndex)
    }
}
$crossFormatFullPackagePlacementMismatches = [Collections.Generic.List[string]]::new()
$expectedCrossFormatFullPackageStartIndex = 268
for ($checkIndex = 0;
     $checkIndex -lt $currentCrossFormatFullPackageCheckIndices.Count;
     $checkIndex++) {
    $expectedCurrentCheckIndex = $expectedCrossFormatFullPackageStartIndex + $checkIndex
    if ($currentCrossFormatFullPackageCheckIndices[$checkIndex] -ne
            $expectedCurrentCheckIndex) {
        $crossFormatFullPackagePlacementMismatches.Add(
            "$checkIndex=$($currentCrossFormatFullPackageCheckIndices[$checkIndex])")
    }
}
$formalOsuFullPackageR2PrefixMismatches = [Collections.Generic.List[string]]::new()
for ($checkIndex = 0; $checkIndex -lt $formalOsuFullPackageR2CheckNames.Count; $checkIndex++) {
    $expectedCheckName = if (
        $checkIndex -eq $osuPickerFilenameSupersessionZeroBasedIndex) {
        $replacementOsuPickerFilenameCheckName
    } else {
        $formalOsuFullPackageR2CheckNames[$checkIndex]
    }
    if ($checkIndex -ge $currentCheckNames.Count -or
        $currentCheckNames[$checkIndex] -cne $expectedCheckName) {
        $formalOsuFullPackageR2PrefixMismatches.Add([string]$checkIndex)
    }
}
$verticalSliceCheckCount = $currentChecks.Count
if ($formalLibraryDeletionR2Evidence.schema -cne "lumachart.windows.avalonia.slice-evidence.v14" -or
    $formalLibraryDeletionR2Evidence.status -cne "slice-passed-migration-incomplete" -or
    [bool]$formalLibraryDeletionR2Evidence.completion.windowsAvaloniaCanReplaceWpf -or
    [bool]$formalLibraryDeletionR2Evidence.completion.userManualReplacementApprovalReceived -or
    [bool]$formalLibraryDeletionR2Evidence.completion.nextPlatformAuthorized -or
    $formalLibraryDeletionR2Specs.Schema -cne "lumachart.windows.avalonia.slice-specs.v2" -or
    $formalLibraryDeletionR2Specs.Status -cne "passed" -or
    $formalLibraryDeletionR2Checks.Count -ne 226 -or
    @($formalLibraryDeletionR2Checks | Where-Object { -not $_.Passed }).Count -ne 0 -or
    $duplicateFormalLibraryDeletionR2CheckNames.Count -ne 0) {
    throw "The formal library-deletion r2 baseline is not the expected unique 226/226 authority."
}
if ($formalChartValidationR2Evidence.schema -cne
        "lumachart.windows.avalonia.slice-evidence.v15" -or
    $formalChartValidationR2Evidence.status -cne "slice-passed-migration-incomplete" -or
    [bool]$formalChartValidationR2Evidence.completion.windowsAvaloniaCanReplaceWpf -or
    [bool]$formalChartValidationR2Evidence.completion.userManualReplacementApprovalReceived -or
    [bool]$formalChartValidationR2Evidence.completion.nextPlatformAuthorized -or
    $formalChartValidationR2Specs.Schema -cne "lumachart.windows.avalonia.slice-specs.v2" -or
    $formalChartValidationR2Specs.Status -cne "passed" -or
    $formalChartValidationR2Checks.Count -ne 233 -or
    @($formalChartValidationR2Checks | Where-Object { -not $_.Passed }).Count -ne 0 -or
    $duplicateFormalChartValidationR2CheckNames.Count -ne 0) {
    throw "The formal chart-validation r2 baseline is not the expected unique 233/233 authority."
}
if ($formalLibraryBatchDeletionR3Evidence.schema -cne
        "lumachart.windows.avalonia.slice-evidence.v16" -or
    $formalLibraryBatchDeletionR3Evidence.status -cne "slice-passed-migration-incomplete" -or
    [bool]$formalLibraryBatchDeletionR3Evidence.completion.windowsAvaloniaCanReplaceWpf -or
    [bool]$formalLibraryBatchDeletionR3Evidence.completion.userManualReplacementApprovalReceived -or
    [bool]$formalLibraryBatchDeletionR3Evidence.completion.nextPlatformAuthorized -or
    $formalLibraryBatchDeletionR3Specs.Schema -cne
        "lumachart.windows.avalonia.slice-specs.v2" -or
    $formalLibraryBatchDeletionR3Specs.Status -cne "passed" -or
    $formalLibraryBatchDeletionR3Checks.Count -ne 233 -or
    @($formalLibraryBatchDeletionR3Checks | Where-Object { -not $_.Passed }).Count -ne 0 -or
    $duplicateFormalLibraryBatchDeletionR3CheckNames.Count -ne 0) {
    throw "The formal library-batch-deletion r3 baseline is not the expected unique 233/233 authority."
}
if ($formalMalodyFullPackageR3Evidence.schema -cne
        "lumachart.windows.avalonia.slice-evidence.v18" -or
    $formalMalodyFullPackageR3Evidence.status -cne "slice-passed-migration-incomplete" -or
    [bool]$formalMalodyFullPackageR3Evidence.completion.windowsAvaloniaCanReplaceWpf -or
    [bool]$formalMalodyFullPackageR3Evidence.completion.userManualReplacementApprovalReceived -or
    [bool]$formalMalodyFullPackageR3Evidence.completion.nextPlatformAuthorized -or
    $formalMalodyFullPackageR3Specs.Schema -cne
        "lumachart.windows.avalonia.slice-specs.v2" -or
    $formalMalodyFullPackageR3Specs.Status -cne "passed" -or
    $formalMalodyFullPackageR3Checks.Count -ne 257 -or
    @($formalMalodyFullPackageR3Checks | Where-Object { -not $_.Passed }).Count -ne 0 -or
    $duplicateFormalMalodyFullPackageR3CheckNames.Count -ne 0) {
    throw "The formal Malody FullPackage r3 baseline is not the expected unique 257/257 authority."
}
if ($formalOsuFullPackageR2Evidence.schema -cne
        "lumachart.windows.avalonia.slice-evidence.v19" -or
    $formalOsuFullPackageR2Evidence.status -cne "slice-passed-migration-incomplete" -or
    [bool]$formalOsuFullPackageR2Evidence.completion.windowsAvaloniaCanReplaceWpf -or
    [bool]$formalOsuFullPackageR2Evidence.completion.userManualReplacementApprovalReceived -or
    [bool]$formalOsuFullPackageR2Evidence.completion.nextPlatformAuthorized -or
    $formalOsuFullPackageR2Specs.Schema -cne
        "lumachart.windows.avalonia.slice-specs.v2" -or
    $formalOsuFullPackageR2Specs.Status -cne "passed" -or
    $formalOsuFullPackageR2Checks.Count -ne 268 -or
    @($formalOsuFullPackageR2Checks | Where-Object { -not $_.Passed }).Count -ne 0 -or
    $duplicateFormalOsuFullPackageR2CheckNames.Count -ne 0) {
    throw "The formal osu! FullPackage r2 baseline is not the expected unique 268/268 authority."
}
if ($formalCrossFormatFullPackageR1Evidence.schema -cne
        "lumachart.windows.avalonia.slice-evidence.v20" -or
    $formalCrossFormatFullPackageR1Evidence.status -cne
        "slice-passed-migration-incomplete" -or
    [bool]$formalCrossFormatFullPackageR1Evidence.completion.windowsAvaloniaCanReplaceWpf -or
    [bool]$formalCrossFormatFullPackageR1Evidence.completion.userManualReplacementApprovalReceived -or
    [bool]$formalCrossFormatFullPackageR1Evidence.completion.nextPlatformAuthorized -or
    $formalCrossFormatFullPackageR1Specs.Schema -cne
        "lumachart.windows.avalonia.slice-specs.v2" -or
    $formalCrossFormatFullPackageR1Specs.Status -cne "passed" -or
    $formalCrossFormatFullPackageR1Checks.Count -ne 276 -or
    @($formalCrossFormatFullPackageR1Checks | Where-Object { -not $_.Passed }).Count -ne 0 -or
    $duplicateFormalCrossFormatFullPackageR1CheckNames.Count -ne 0) {
    throw "The formal cross-format FullPackage r1 baseline is not the expected unique 276/276 authority."
}
if ($formalOsuToMalodyFullPackageR7Evidence.schema -cne
        "lumachart.windows.avalonia.slice-evidence.v22" -or
    $formalOsuToMalodyFullPackageR7Evidence.status -cne
        "slice-passed-migration-incomplete" -or
    [bool]$formalOsuToMalodyFullPackageR7Evidence.completion.windowsAvaloniaCanReplaceWpf -or
    [bool]$formalOsuToMalodyFullPackageR7Evidence.completion.userManualReplacementApprovalReceived -or
    [bool]$formalOsuToMalodyFullPackageR7Evidence.completion.nextPlatformAuthorized -or
    $formalOsuToMalodyFullPackageR7Specs.Schema -cne
        "lumachart.windows.avalonia.slice-specs.v2" -or
    $formalOsuToMalodyFullPackageR7Specs.Status -cne "passed" -or
    $formalOsuToMalodyFullPackageR7Checks.Count -ne 277 -or
    @($formalOsuToMalodyFullPackageR7Checks | Where-Object { -not $_.Passed }).Count -ne 0 -or
    $duplicateFormalOsuToMalodyFullPackageR7CheckNames.Count -ne 0) {
    throw "The formal osu-to-Malody FullPackage r7 baseline is not the expected unique 277/277 authority."
}
if ($verticalSlice.Schema -cne "lumachart.windows.avalonia.slice-specs.v2" -or
    $verticalSlice.Status -cne "passed" -or
    @($currentChecks | Where-Object { -not $_.Passed }).Count -ne 0 -or
    $duplicateCurrentCheckNames.Count -ne 0 -or
    $missingFormalLibraryDeletionR2CheckNames.Count -ne 0 -or
    $formalLibraryDeletionR2OrdinalMismatches.Count -ne 0 -or
    $requiredWindowsChartValidationCheckNames.Count -ne 7 -or
    $duplicateRequiredWindowsChartValidationCheckNames.Count -ne 0 -or
    $additionalWindowsChartValidationCheckNames.Count -ne 7 -or
    $unexpectedAdditionalWindowsChartValidationCheckNames.Count -ne 0 -or
    $chartValidationOrdinalMismatches.Count -ne 0 -or
    $missingFormalChartValidationR2CheckNames.Count -ne 0 -or
    $formalChartValidationR2OrdinalMismatches.Count -ne 0 -or
    $missingFormalLibraryBatchDeletionR3CheckNames.Count -ne 0 -or
    $formalLibraryBatchDeletionR3OrdinalMismatches.Count -ne 0 -or
    $requiredWindowsMalodyFullPackageCheckNames.Count -ne 24 -or
    $duplicateRequiredWindowsMalodyFullPackageCheckNames.Count -ne 0 -or
    $requiredWindowsOsuFullPackageCheckNames.Count -ne 11 -or
    $duplicateRequiredWindowsOsuFullPackageCheckNames.Count -ne 0 -or
    $additionalCurrentCheckNamesAfterChartValidationR2.Count -ne 61 -or
    $additionalCurrentCheckNamesAfterLibraryBatchDeletionR3.Count -ne 61 -or
    $currentMalodyFullPackageCheckIndices.Count -ne 24 -or
    $malodyFullPackagePlacementMismatches.Count -ne 0 -or
    $currentOsuFullPackageCheckIndices.Count -ne 11 -or
    $osuFullPackagePlacementMismatches.Count -ne 0 -or
    $unexpectedAdditionalWindowsFullPackageCheckNames.Count -ne 0 -or
    $malodyFullPackageOrdinalMismatches.Count -ne 0 -or
    $osuFullPackageOrdinalMismatches.Count -ne 0 -or
    $requiredWindowsCrossFormatFullPackageCheckNames.Count -ne 8 -or
    $duplicateRequiredWindowsCrossFormatFullPackageCheckNames.Count -ne 0 -or
    $currentCrossFormatFullPackageCheckIndices.Count -ne 8 -or
    $crossFormatFullPackagePlacementMismatches.Count -ne 0 -or
    $crossFormatFullPackageOrdinalMismatches.Count -ne 0 -or
    $formalOsuFullPackageR2PrefixMismatches.Count -ne 0 -or
    $formalCrossFormatFullPackageR1OrdinalMismatches.Count -ne 0 -or
    $formalOsuToMalodyFullPackageR7PrefixMismatches.Count -ne 0 -or
    $authoritySupersessionDefinitionMismatches.Count -ne 0 -or
    $duplicateRequiredWindowsChartExportCheckNames.Count -ne 0 -or
    $currentWindowsChartExportCheckNames.Count -ne 17 -or
    $windowsChartExportOrdinalMismatches.Count -ne 0 -or
    $currentCheckNames.Count -ne 294 -or
    [string]$currentCheckNames[276] -cne $requiredWindowsEvidenceNoteFocusCheckName -or
    $verticalSliceCheckCount -ne 294) {
    throw "Avalonia vertical-slice evidence is not the exact ordered r7 277-check authority with only the explicit ordinal-79 picker-filename contract supersession, followed by the seventeen ordered Windows chart-export checks at ordinals 278-294 (294/294)."
}

$windowsChartExportChecks = @($currentChecks | Where-Object {
        $requiredWindowsChartExportCheckNameSet.Contains([string]$_.Name)
    })
if ($windowsChartExportChecks.Count -ne 17 -or
    @($windowsChartExportChecks | Where-Object { -not [bool]$_.Passed }).Count -ne 0) {
    throw "The seventeen Windows chart-export contract checks are not present as exact passed evidence."
}
$verticalSliceIsolationRoot = [IO.Path]::GetFullPath([string]$verticalSlice.IsolationRoot)
$batchAvaloniaSpecsBoundary =
    [IO.Path]::GetFullPath($batchAvaloniaSpecsTempRoot).TrimEnd('\') + '\'
if (-not $verticalSliceIsolationRoot.StartsWith(
        $batchAvaloniaSpecsBoundary,
        [StringComparison]::OrdinalIgnoreCase) -or
    -not (Test-Path -LiteralPath $verticalSliceIsolationRoot -PathType Container)) {
    throw "The current Specs isolation root did not stay under the formal D-drive Avalonia Specs TEMP boundary."
}
$chartExportSpecsRoot =
    Join-Path $verticalSliceIsolationRoot "four-mode-chart-export"
$chartExportSpecsSourceRoot = Join-Path $chartExportSpecsRoot "source"
$chartExportSpecsFixtureMcPath =
    Join-Path $chartExportSpecsSourceRoot "fixture.mc"
$chartExportSpecsCoverPath = Join-Path $chartExportSpecsSourceRoot "cover.png"
$chartExportSpecsBackgroundPath =
    Join-Path $chartExportSpecsSourceRoot "background.jpg"
$chartExportSpecsKeySoundPath = Join-Path $chartExportSpecsSourceRoot "key.wav"
$chartExportSpecsRealWavePath =
    Join-Path $chartExportSpecsRoot "windows-audio-adapter\source.wav"
$chartExportSpecsInputAuthorities = [ordered]@{
    fixtureMc = [ordered]@{
        path = $chartExportSpecsFixtureMcPath
        length = 535L
        sha256 = "ADCAEB7955158DC9EA024FE96FAD0FFBC8EA65CC4E93117AF4258F8C26A00EAA"
    }
    cover = [ordered]@{
        path = $chartExportSpecsCoverPath
        length = 13L
        sha256 = "60C65A30689DF94FB07714BEDA0E0314ECB03A67906E24BE94B1C87DE322D7BF"
    }
    background = [ordered]@{
        path = $chartExportSpecsBackgroundPath
        length = 18L
        sha256 = "ED757A59A4E7E0EF242534270F40E792E502DCE641B6CE502723418A6F7EC313"
    }
    keySound = [ordered]@{
        path = $chartExportSpecsKeySoundPath
        length = 17L
        sha256 = "0C7E33359A9DE9D83AEBB0F3407D22AA0B8C7296F2AE297C0D2E3249DEFA2B20"
    }
    realWave = [ordered]@{
        path = $chartExportSpecsRealWavePath
        length = 132344L
        sha256 = "40DB4A07537AA02444C571D57B93C99216043316BC2BD0C9137CE9A0FB49B67B"
    }
}
foreach ($authority in $chartExportSpecsInputAuthorities.Values) {
    if (-not (Test-Path -LiteralPath $authority.path -PathType Leaf)) {
        throw "A current Specs chart-export input authority is missing: $($authority.path)"
    }
    $authorityItem = Get-Item -LiteralPath $authority.path
    $authorityHash = (Get-FileHash -LiteralPath $authority.path -Algorithm SHA256).Hash
    if ([long]$authorityItem.Length -ne [long]$authority.length -or
        $authorityHash -cne [string]$authority.sha256) {
        throw "A current Specs chart-export input authority changed: $($authority.path)"
    }
}
$chartExportSpecsWaveHeader = [IO.File]::ReadAllBytes($chartExportSpecsRealWavePath)
if ($chartExportSpecsWaveHeader.Length -lt 12 -or
    [Text.Encoding]::ASCII.GetString($chartExportSpecsWaveHeader, 0, 4) -cne 'RIFF' -or
    [Text.Encoding]::ASCII.GetString($chartExportSpecsWaveHeader, 8, 4) -cne 'WAVE') {
    throw "The current Specs chart-export real audio authority is not a valid RIFF/WAVE fixture."
}

$malodyFullPackageFileSymlinkCapabilityCheckName =
    $requiredWindowsMalodyFullPackageCheckNames[16]
$malodyFullPackageFallbackResourceCheckName =
    $requiredWindowsMalodyFullPackageCheckNames[17]
$malodyFullPackageDirectoryJunctionCapabilityCheckName =
    $requiredWindowsMalodyFullPackageCheckNames[18]
$malodyFullPackageDirectoryJunctionResourceCheckName =
    $requiredWindowsMalodyFullPackageCheckNames[19]
$malodyFullPackageDirectoryCollisionCheckName =
    $requiredWindowsMalodyFullPackageCheckNames[20]
$malodyFullPackageCommitCancellationCheckName =
    $requiredWindowsMalodyFullPackageCheckNames[21]
$malodyFullPackageFailedReplaceCheckName =
    $requiredWindowsMalodyFullPackageCheckNames[22]
$malodyFullPackageSuccessfulReplaceCheckName =
    $requiredWindowsMalodyFullPackageCheckNames[23]
$malodyFullPackageSafetyCheckNames = @(
    $malodyFullPackageFileSymlinkCapabilityCheckName
    $malodyFullPackageFallbackResourceCheckName
    $malodyFullPackageDirectoryJunctionCapabilityCheckName
    $malodyFullPackageDirectoryJunctionResourceCheckName
    $malodyFullPackageDirectoryCollisionCheckName
    $malodyFullPackageCommitCancellationCheckName
    $malodyFullPackageFailedReplaceCheckName
    $malodyFullPackageSuccessfulReplaceCheckName
)
$malodyFullPackageSafetyChecksByName = @{}
foreach ($safetyCheckName in $malodyFullPackageSafetyCheckNames) {
    $matchingSafetyChecks = @($currentChecks | Where-Object {
            [string]$_.Name -ceq $safetyCheckName
        })
    if ($matchingSafetyChecks.Count -ne 1 -or
        -not [bool]$matchingSafetyChecks[0].Passed) {
        throw "The successful 276-check authority did not contain one exact passed safety check '$safetyCheckName'."
    }
    $malodyFullPackageSafetyChecksByName.Add(
        $safetyCheckName,
        $matchingSafetyChecks[0])
}
$malodyFullPackageFileSymlinkCapabilityCheck =
    $malodyFullPackageSafetyChecksByName[$malodyFullPackageFileSymlinkCapabilityCheckName]
$malodyFullPackageFallbackResourceCheck =
    $malodyFullPackageSafetyChecksByName[$malodyFullPackageFallbackResourceCheckName]
$malodyFullPackageDirectoryJunctionCapabilityCheck =
    $malodyFullPackageSafetyChecksByName[$malodyFullPackageDirectoryJunctionCapabilityCheckName]
$malodyFullPackageDirectoryJunctionResourceCheck =
    $malodyFullPackageSafetyChecksByName[$malodyFullPackageDirectoryJunctionResourceCheckName]
$malodyFullPackageDirectoryCollisionCheck =
    $malodyFullPackageSafetyChecksByName[$malodyFullPackageDirectoryCollisionCheckName]
$malodyFullPackageCommitCancellationCheck =
    $malodyFullPackageSafetyChecksByName[$malodyFullPackageCommitCancellationCheckName]
$malodyFullPackageFailedReplaceCheck =
    $malodyFullPackageSafetyChecksByName[$malodyFullPackageFailedReplaceCheckName]
$malodyFullPackageSuccessfulReplaceCheck =
    $malodyFullPackageSafetyChecksByName[$malodyFullPackageSuccessfulReplaceCheckName]
$malodyFullPackageSafetyChecks = @($malodyFullPackageSafetyCheckNames | ForEach-Object {
        $malodyFullPackageSafetyChecksByName[$_]
    })
$malodyFullPackageFileSymlinkCapabilityDetail =
    [string]($malodyFullPackageFileSymlinkCapabilityCheck.Detail)
$malodyFullPackageFallbackResourceDetail =
    [string]($malodyFullPackageFallbackResourceCheck.Detail)
$malodyFullPackageDirectoryJunctionCapabilityDetail =
    [string]($malodyFullPackageDirectoryJunctionCapabilityCheck.Detail)
$malodyFullPackageDirectoryJunctionResourceDetail =
    [string]($malodyFullPackageDirectoryJunctionResourceCheck.Detail)
$malodyFullPackageDirectoryCollisionDetail =
    [string]($malodyFullPackageDirectoryCollisionCheck.Detail)
$malodyFullPackageCommitCancellationDetail =
    [string]($malodyFullPackageCommitCancellationCheck.Detail)
$malodyFullPackageFailedReplaceDetail =
    [string]($malodyFullPackageFailedReplaceCheck.Detail)
$malodyFullPackageSuccessfulReplaceDetail =
    [string]($malodyFullPackageSuccessfulReplaceCheck.Detail)
if ($malodyFullPackageFileSymlinkCapabilityDetail -cnotmatch
        '^directValidationAvailable=False; directCoverage=False; fallbackCoverage=managed-scratch-pruning; IOException; hresult=0x80070522; privilegeUnavailable=True;' -or
    $malodyFullPackageFallbackResourceDetail -cne
        'mechanism=managed-scratch-pruning; directFileSymlinkCoverage=False; originalReference=managed-scratch\session_specs\pruned-audio.ogg; reference=pruned-audio.ogg; entry=pruned-audio.ogg; bytes=8' -or
    $malodyFullPackageDirectoryJunctionCapabilityDetail -cnotmatch
        '^exit=0; exists=True; attributes=Directory, ReparsePoint;' -or
    $malodyFullPackageDirectoryJunctionResourceDetail -cne
        'originalReference=junction-assets\junction-audio.ogg; reference=junction-audio_2.ogg; entry=junction-audio_2.ogg; bytes=8' -or
    $malodyFullPackageDirectoryCollisionDetail -cne
        'resourceReference=junction-audio_2.ogg; directoryEntry=junction-audio.ogg/directory-content.sentinel; archivedSentinel=8; sourceSentinel=8' -or
    $malodyFullPackageCommitCancellationDetail -cne
        'afterZipValidationBeforeCommit=True; temporaryArchiveObservedBeforeCommit=True; canceled=True; commitBoundary=token-check-immediately-before-file-move; oldPreserved=True; temporaryArchives=0' -or
    $malodyFullPackageFailedReplaceDetail -cne
        'failure=UnauthorizedAccessException; oldPreserved=True; temporaryArchives=0' -or
    $malodyFullPackageSuccessfulReplaceDetail -cnotmatch
        '^bytes=[1-9][0-9]*; temporaryArchives=0; reference=atomic\.ogg; entry=atomic\.ogg; bytes=8$') {
    throw "The successful MCZ safety Specs did not retain the exact local file-symlink limitation, direct junction/directory-collision coverage, commit-boundary cancellation, and atomic replacement evidence."
}

$fixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc"
$fixtureSha256 = (Get-FileHash -LiteralPath $fixturePath -Algorithm SHA256).Hash
if ($fixtureSha256 -ne "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") {
    throw "The required real chart fixture hash changed."
}
$osuFixturePath = "D:\osu!\Songs\1005389 Minori Chihara - Michishirube\Minori Chihara - Michishirube (eZmmR) [Dear You,  Gilbert Bougainvillea .].osu"
$osuFixtureSha256 = (Get-FileHash -LiteralPath $osuFixturePath -Algorithm SHA256).Hash
if ($osuFixtureSha256 -ne "511866870F99BDC7443006FA7420C7A9D21198F49B9EC13B50A32293E7F58E57") {
    throw "The required real osu fixture hash changed."
}
$archiveFixturePath = "D:\Project\malody_tool\mc2osu\Infinity_Heaven.mcz"
$archiveFixtureSha256 = (Get-FileHash -LiteralPath $archiveFixturePath -Algorithm SHA256).Hash
if ($archiveFixtureSha256 -ne "03A50A7C7750CE4CB4C176B6A9BCB6193F7DC186C15D2C290971C3DE5748D3BD") {
    throw "The required real MCZ fixture hash changed."
}
$proEditorFixturePath = Join-Path $projectRoot "TestFixtures\malody-noteref-test.mc"
$proEditorFixtureSha256 = (Get-FileHash -LiteralPath $proEditorFixturePath -Algorithm SHA256).Hash
if ($proEditorFixtureSha256 -ne "9EF6FD8A61A602DA651C5E4F5F1B5CF7DCC3D1992A76C4A953A9E67AB0B7305C") {
    throw "The trusted ProEditor noteref fixture hash changed."
}
$keySoundFlatFixturePath = Join-Path $projectRoot "TestFixtures\flat-visual-test.mc"
$keySoundFlatFixtureSha256 = (Get-FileHash -LiteralPath $keySoundFlatFixturePath -Algorithm SHA256).Hash
if ($keySoundFlatFixtureSha256 -cne "B11DBDBEFD344EF5DBB4DD1B3A3ACBE0163E2D95B5C61FA126F25861D3E5BCF6") {
    throw "The trusted flat Key-sound fixture hash changed."
}
$keySoundSampleSourcePath = "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg"
$keySoundSampleSourceSha256 = (Get-FileHash -LiteralPath $keySoundSampleSourcePath -Algorithm SHA256).Hash
if ($keySoundSampleSourceSha256 -cne "00AA7780330A022D7F5D0C4C2BEA23625D31F48BA8CAC2AF25117249BEA05151") {
    throw "The trusted Key-sound sample source hash changed."
}
$resoundCoverSourcePath = "D:\osu!\Songs\Resound\0\Resound - Nhato.jpg"
$resoundCoverSourceSha256 =
    (Get-FileHash -LiteralPath $resoundCoverSourcePath -Algorithm SHA256).Hash
$guiRoot = Join-Path $artifactFullPath "gui-runtime"
$libraryRoot = Join-Path $guiRoot "library"
$mcLibraryDirectory = Join-Path $libraryRoot "_song_Resound\0"
$osuLibraryDirectory = Join-Path $libraryRoot "Michishirube"
$propertyFixtureRoot = Join-Path $guiRoot "note-property-fixture"
$propertyMcDirectory = Join-Path $propertyFixtureRoot "_song_Resound\0"
$groupFixtureRoot = Join-Path $guiRoot "group-fixture"
$groupMcDirectory = Join-Path $groupFixtureRoot "_song_Resound\0"
$proEditorFixtureRoot = Join-Path $guiRoot "proeditor-fixture"
$proEditorPanDirectory = Join-Path $proEditorFixtureRoot "pan"
$proEditorEditDirectory = Join-Path $proEditorFixtureRoot "edit"
$keySoundSharedFixtureRoot = Join-Path $guiRoot "key-sound-shared-fixture"
$keySoundSharedMcDirectory = Join-Path $keySoundSharedFixtureRoot "_song_Resound\0"
$keySoundSilentFixtureRoot = Join-Path $guiRoot "key-sound-silent-fixture"
$chartValidationFixtureRoot = Join-Path $guiRoot "chart-validation-fixture"
$chartValidationMcDirectory = Join-Path $chartValidationFixtureRoot "_song_Resound\0"
$malodyFullPackageRoot = Join-Path $guiRoot "malody-full-package"
$malodyFullPackageSourceRoot = Join-Path $malodyFullPackageRoot "source"
$malodyFullPackageMainChartPath =
    Join-Path $malodyFullPackageSourceRoot "0\1622528438.mc"
$malodyFullPackageExportPath =
    Join-Path $malodyFullPackageRoot "output\out.mcz"
$malodyFullPackageMainLocalDataRoot =
    Join-Path $malodyFullPackageRoot "sessions\export\local-data"
$malodyFullPackageMainEditingRoot =
    Join-Path $malodyFullPackageRoot "sessions\export\editing"
$malodyFullPackageFreshWorkspaceRoot =
    Join-Path $malodyFullPackageRoot "fresh-import\workspace"
$malodyFullPackageFreshLocalDataRoot =
    Join-Path $malodyFullPackageRoot "fresh-import\local-data"
$malodyFullPackageFreshEditingRoot =
    Join-Path $malodyFullPackageRoot "fresh-import\editing"
$malodyFullPackageGuiPath =
    Join-Path $malodyFullPackageRoot "runtime\export-primary-v1.json"
$malodyFullPackageInteractionGuiPath =
    Join-Path $malodyFullPackageRoot "runtime\export-interaction-v1.json"
$malodyFullPackageScreenshotPath =
    Join-Path $malodyFullPackageRoot "screenshots\export-final-v1.png"
$malodyFullPackageOptionsScreenshotPath =
    Join-Path $malodyFullPackageRoot "screenshots\export-options-v1.png"
$malodyFullPackageResultScreenshotPath =
    Join-Path $malodyFullPackageRoot "screenshots\export-result-v1.png"
$malodyFullPackageFreshGuiPath =
    Join-Path $malodyFullPackageRoot "fresh-import\runtime\primary-v1.json"
$malodyFullPackageFreshInteractionGuiPath =
    Join-Path $malodyFullPackageRoot "fresh-import\runtime\interaction-v1.json"
$malodyFullPackageFreshDialogScreenshotPath =
    Join-Path $malodyFullPackageRoot "screenshots\fresh-import-preview-v1.png"
$malodyFullPackageFreshScreenshotPath =
    Join-Path $malodyFullPackageRoot "screenshots\fresh-import-main-chart-v1.png"
$malodyToOsuFullPackageRoot = Join-Path $guiRoot "malody-to-osu-full-package"
$malodyToOsuFullPackageSourceRoot = Join-Path $malodyToOsuFullPackageRoot "source"
$malodyToOsuFullPackageMainChartPath =
    Join-Path $malodyToOsuFullPackageSourceRoot "1622528438.mc"
$malodyToOsuFullPackageMainFileName =
    "HyuN - Infinity Heaven (舞线Ignite) [4K Stream Lv.28].osu"
$malodyToOsuFullPackageExportPath =
    Join-Path $malodyToOsuFullPackageRoot "output\out.osz"
$malodyToOsuFullPackageMainLocalDataRoot =
    Join-Path $malodyToOsuFullPackageRoot "sessions\export\local-data"
$malodyToOsuFullPackageMainEditingRoot =
    Join-Path $malodyToOsuFullPackageRoot "sessions\export\editing"
$malodyToOsuFullPackageFreshWorkspaceRoot =
    Join-Path $malodyToOsuFullPackageRoot "fresh-import\workspace"
$malodyToOsuFullPackageFreshLocalDataRoot =
    Join-Path $malodyToOsuFullPackageRoot "fresh-import\local-data"
$malodyToOsuFullPackageFreshEditingRoot =
    Join-Path $malodyToOsuFullPackageRoot "fresh-import\editing"
$malodyToOsuFullPackageGuiPath =
    Join-Path $malodyToOsuFullPackageRoot "runtime\export-primary-v1.json"
$malodyToOsuFullPackageInteractionGuiPath =
    Join-Path $malodyToOsuFullPackageRoot "runtime\export-interaction-v1.json"
$malodyToOsuFullPackageScreenshotPath =
    Join-Path $malodyToOsuFullPackageRoot "screenshots\export-final-v1.png"
$malodyToOsuFullPackageOptionsScreenshotPath =
    Join-Path $malodyToOsuFullPackageRoot "screenshots\export-options-v1.png"
$malodyToOsuFullPackageResultScreenshotPath =
    Join-Path $malodyToOsuFullPackageRoot "screenshots\export-result-v1.png"
$malodyToOsuFullPackageFreshGuiPath =
    Join-Path $malodyToOsuFullPackageRoot "fresh-import\runtime\primary-v1.json"
$malodyToOsuFullPackageFreshInteractionGuiPath =
    Join-Path $malodyToOsuFullPackageRoot "fresh-import\runtime\interaction-v1.json"
$malodyToOsuFullPackageFreshDialogScreenshotPath =
    Join-Path $malodyToOsuFullPackageRoot "screenshots\fresh-import-preview-v1.png"
$malodyToOsuFullPackageFirstCalibrationScreenshotPath =
    Join-Path $malodyToOsuFullPackageRoot "screenshots\fresh-import-calibration-1-v1.png"
$malodyToOsuFullPackageFreshScreenshotPath =
    Join-Path $malodyToOsuFullPackageRoot "screenshots\fresh-import-main-chart-v1.png"
$osuFullPackageTrustedSourceRoot =
    "D:\osu!\Songs\1005389 Minori Chihara - Michishirube"
$osuToMalodyFullPackageRoot = Join-Path $guiRoot "osu-to-malody-full-package"
$osuToMalodyFullPackageSourceRoot =
    Join-Path $osuToMalodyFullPackageRoot "source"
$osuToMalodyFullPackageMainFileName =
    "Minori Chihara - Michishirube (eZmmR) [Dear You,  Gilbert Bougainvillea .].osu"
$osuToMalodyFullPackageSiblingFileName =
    "Minori Chihara - Michishirube (eZmmR) [Dear You,  Violet Evergarden .].osu"
$osuToMalodyFullPackageMainChartPath =
    Join-Path $osuToMalodyFullPackageSourceRoot $osuToMalodyFullPackageMainFileName
$osuToMalodyFullPackageExportPath =
    Join-Path $osuToMalodyFullPackageRoot "output\out.mcz"
$osuToMalodyFullPackageMainLocalDataRoot =
    Join-Path $osuToMalodyFullPackageRoot "sessions\export\local-data"
$osuToMalodyFullPackageMainEditingRoot =
    Join-Path $osuToMalodyFullPackageRoot "sessions\export\editing"
$osuToMalodyFullPackageFreshWorkspaceRoot =
    Join-Path $osuToMalodyFullPackageRoot "fresh-import\workspace"
$osuToMalodyFullPackageFreshLocalDataRoot =
    Join-Path $osuToMalodyFullPackageRoot "fresh-import\local-data"
$osuToMalodyFullPackageFreshEditingRoot =
    Join-Path $osuToMalodyFullPackageRoot "fresh-import\editing"
$osuToMalodyFullPackageGuiPath =
    Join-Path $osuToMalodyFullPackageRoot "runtime\export-primary-v1.json"
$osuToMalodyFullPackageInteractionGuiPath =
    Join-Path $osuToMalodyFullPackageRoot "runtime\export-interaction-v1.json"
$osuToMalodyFullPackageScreenshotPath =
    Join-Path $osuToMalodyFullPackageRoot "screenshots\export-final-v1.png"
$osuToMalodyFullPackageOptionsScreenshotPath =
    Join-Path $osuToMalodyFullPackageRoot "screenshots\export-options-v1.png"
$osuToMalodyFullPackageResultScreenshotPath =
    Join-Path $osuToMalodyFullPackageRoot "screenshots\export-result-v1.png"
$osuToMalodyFullPackageFreshGuiPath =
    Join-Path $osuToMalodyFullPackageRoot "fresh-import\runtime\primary-v1.json"
$osuToMalodyFullPackageFreshInteractionGuiPath =
    Join-Path $osuToMalodyFullPackageRoot "fresh-import\runtime\interaction-v1.json"
$osuToMalodyFullPackageFreshDialogScreenshotPath =
    Join-Path $osuToMalodyFullPackageRoot "screenshots\fresh-import-preview-v1.png"
$osuToMalodyFullPackageFreshScreenshotPath =
    Join-Path $osuToMalodyFullPackageRoot "screenshots\fresh-import-target-note-v1.png"
$osuFullPackageRoot = Join-Path $guiRoot "osu-full-package"
$osuFullPackageSourceRoot = Join-Path $osuFullPackageRoot "source"
$osuFullPackageMainFileName =
    "Minori Chihara - Michishirube (eZmmR) [Dear You,  Gilbert Bougainvillea .].osu"
$osuFullPackageSiblingFileName =
    "Minori Chihara - Michishirube (eZmmR) [Dear You,  Violet Evergarden .].osu"
$osuFullPackageMainChartPath = Join-Path $osuFullPackageSourceRoot $osuFullPackageMainFileName
$osuFullPackageSiblingChartPath = Join-Path $osuFullPackageSourceRoot $osuFullPackageSiblingFileName
$osuFullPackageExportPath = Join-Path $osuFullPackageRoot "output\out.osz"
$osuFullPackageMainLocalDataRoot = Join-Path $osuFullPackageRoot "sessions\export\local-data"
$osuFullPackageMainEditingRoot = Join-Path $osuFullPackageRoot "sessions\export\editing"
$osuFullPackageFreshWorkspaceRoot = Join-Path $osuFullPackageRoot "fresh-import\workspace"
$osuFullPackageFreshLocalDataRoot = Join-Path $osuFullPackageRoot "fresh-import\local-data"
$osuFullPackageFreshEditingRoot = Join-Path $osuFullPackageRoot "fresh-import\editing"
$osuFullPackageGuiPath = Join-Path $osuFullPackageRoot "runtime\export-primary-v1.json"
$osuFullPackageInteractionGuiPath =
    Join-Path $osuFullPackageRoot "runtime\export-interaction-v1.json"
$osuFullPackageScreenshotPath = Join-Path $osuFullPackageRoot "screenshots\export-final-v1.png"
$osuFullPackageOptionsScreenshotPath =
    Join-Path $osuFullPackageRoot "screenshots\export-options-v1.png"
$osuFullPackageResultScreenshotPath =
    Join-Path $osuFullPackageRoot "screenshots\export-result-v1.png"
$osuFullPackageFreshGuiPath = Join-Path $osuFullPackageRoot "fresh-import\runtime\primary-v1.json"
$osuFullPackageFreshInteractionGuiPath =
    Join-Path $osuFullPackageRoot "fresh-import\runtime\interaction-v1.json"
$osuFullPackageFreshDialogScreenshotPath =
    Join-Path $osuFullPackageRoot "screenshots\fresh-import-preview-v1.png"
$osuFullPackageFirstCalibrationScreenshotPath =
    Join-Path $osuFullPackageRoot "screenshots\fresh-import-calibration-1-v1.png"
$osuFullPackageSecondCalibrationScreenshotPath =
    Join-Path $osuFullPackageRoot "screenshots\fresh-import-calibration-2-v1.png"
$osuFullPackageFreshScreenshotPath =
    Join-Path $osuFullPackageRoot "screenshots\fresh-import-main-chart-v1.png"
$chartExportModesRoot = Join-Path $guiRoot "chart-export-modes"
$chartExportModesSourceRoot = Join-Path $chartExportModesRoot "source"
$chartExportModesChartPath =
    Join-Path $chartExportModesSourceRoot "fixture.mc"
$chartExportModesAudioPath = Join-Path $chartExportModesSourceRoot "audio.wav"
$chartExportModesCoverPath = Join-Path $chartExportModesSourceRoot "cover.png"
$chartExportModesBackgroundPath =
    Join-Path $chartExportModesSourceRoot "background.jpg"
$chartExportModesKeySoundPath = Join-Path $chartExportModesSourceRoot "key.wav"
$chartExportModesExportPath = Join-Path $chartExportModesRoot "output\out.mcz"
$chartExportModesLocalDataRoot =
    Join-Path $chartExportModesRoot "session\local-data"
$chartExportModesEditingRoot =
    Join-Path $chartExportModesRoot "session\editing"
$chartExportModesGuiPath =
    Join-Path $chartExportModesRoot "runtime\primary-v1.json"
$chartExportModesInteractionGuiPath =
    Join-Path $chartExportModesRoot "runtime\interaction-v1.json"
$chartExportModesScreenshotPath =
    Join-Path $chartExportModesRoot "screenshots\editor-final-v1.png"
$chartExportModesDefaultScreenshotPath =
    Join-Path $chartExportModesRoot "screenshots\default-full-package-v1.png"
$chartExportModesSingleChartScreenshotPath =
    Join-Path $chartExportModesRoot "screenshots\single-chart-v1.png"
$chartExportModesSingleRateScreenshotPath =
    Join-Path $chartExportModesRoot "screenshots\single-rate-package-v1.png"
$chartExportModesRatePackScreenshotPath =
    Join-Path $chartExportModesRoot "screenshots\rate-pack-v1.png"
$chartExportModesHiddenValidationScreenshotPath =
    Join-Path $chartExportModesRoot "screenshots\hidden-field-validation-v1.png"
$chartExportModesResultScreenshotPath =
    Join-Path $chartExportModesRoot "screenshots\single-rate-result-v1.png"
$libraryBatchToken = [Guid]::NewGuid().ToString("N")
$libraryBatchWorkspaceRoot =
    Join-Path $guiRoot "library-batch-deletion-workspace-$libraryBatchToken"
$libraryBatchAName = "batch-A-$libraryBatchToken"
$libraryBatchBName = "batch-B-$libraryBatchToken"
$libraryBatchOpenName = "open-$libraryBatchToken"
$libraryBatchAPath = Join-Path $libraryBatchWorkspaceRoot $libraryBatchAName
$libraryBatchBPath = Join-Path $libraryBatchWorkspaceRoot $libraryBatchBName
$libraryBatchOpenPath = Join-Path $libraryBatchWorkspaceRoot $libraryBatchOpenName
New-Item -ItemType Directory -Path `
    $mcLibraryDirectory, $osuLibraryDirectory, $propertyMcDirectory, $groupMcDirectory,
    $proEditorPanDirectory, $proEditorEditDirectory, $keySoundSharedMcDirectory,
    $keySoundSilentFixtureRoot, $chartValidationMcDirectory, $malodyFullPackageRoot,
    $malodyToOsuFullPackageSourceRoot,
    $osuToMalodyFullPackageSourceRoot,
    $osuFullPackageSourceRoot,
    $chartExportModesSourceRoot,
    $libraryBatchAPath,
    $libraryBatchBPath, $libraryBatchOpenPath -Force | Out-Null
Copy-Item -LiteralPath $fixturePath -Destination $mcLibraryDirectory
Copy-Item -LiteralPath "D:\osu!\Songs\Resound\0\Resound - Nhato.jpg" -Destination $mcLibraryDirectory
Copy-Item -LiteralPath "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg" -Destination $mcLibraryDirectory
Copy-Item -LiteralPath $osuFixturePath -Destination $osuLibraryDirectory
Copy-Item -LiteralPath "D:\osu!\Songs\1005389 Minori Chihara - Michishirube\audio.mp3" -Destination $osuLibraryDirectory
Copy-Item -LiteralPath "D:\osu!\Songs\1005389 Minori Chihara - Michishirube\BG1.jpg" -Destination $osuLibraryDirectory
Copy-Item -LiteralPath $fixturePath -Destination $propertyMcDirectory
Copy-Item -LiteralPath "D:\osu!\Songs\Resound\0\Resound - Nhato.jpg" -Destination $propertyMcDirectory
Copy-Item -LiteralPath "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg" -Destination $propertyMcDirectory
Copy-Item -LiteralPath $fixturePath -Destination $groupMcDirectory
Copy-Item -LiteralPath "D:\osu!\Songs\Resound\0\Resound - Nhato.jpg" -Destination $groupMcDirectory
Copy-Item -LiteralPath "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg" -Destination $groupMcDirectory
Copy-Item -LiteralPath $proEditorFixturePath -Destination (Join-Path $proEditorPanDirectory "proeditor-pan.mc")
Copy-Item -LiteralPath $proEditorFixturePath -Destination (Join-Path $proEditorEditDirectory "proeditor-edit.mc")
Copy-Item -LiteralPath $fixturePath -Destination $keySoundSharedMcDirectory
Copy-Item -LiteralPath "D:\osu!\Songs\Resound\0\Resound - Nhato.jpg" -Destination $keySoundSharedMcDirectory
Copy-Item -LiteralPath $keySoundSampleSourcePath -Destination $keySoundSharedMcDirectory
Copy-Item -LiteralPath $keySoundFlatFixturePath -Destination $keySoundSilentFixtureRoot
Copy-Item -LiteralPath $keySoundSampleSourcePath -Destination (Join-Path $keySoundSilentFixtureRoot "kick.ogg")
Copy-Item -LiteralPath $fixturePath -Destination $chartValidationMcDirectory
Copy-Item -LiteralPath "D:\osu!\Songs\Resound\0\Resound - Nhato.jpg" `
    -Destination $chartValidationMcDirectory
Copy-Item -LiteralPath $keySoundSampleSourcePath -Destination $chartValidationMcDirectory
Add-Type -AssemblyName System.IO.Compression.ZipFile
[IO.Compression.ZipFile]::ExtractToDirectory(
    $archiveFixturePath,
    $malodyFullPackageSourceRoot,
    [Text.Encoding]::UTF8,
    $false)
foreach ($crossSourceName in @(
        "1622528438.mc",
        "1627794161.mc",
        "1677938697.mc",
        "InfinityHeaven.jpg",
        "InfinityHeaven.ogg")) {
    Copy-Item `
        -LiteralPath (Join-Path $malodyFullPackageSourceRoot "0\$crossSourceName") `
        -Destination $malodyToOsuFullPackageSourceRoot
}
foreach ($decoy in @(
        @{ Name = "cross-format-decoy.mcz"; Bytes = [byte[]](1, 2, 3) },
        @{ Name = "cross-format-decoy.osz"; Bytes = [byte[]](4, 5, 6) },
        @{ Name = "cross-format-decoy.luma-part"; Bytes = [byte[]](7, 8, 9) })) {
    [IO.File]::WriteAllBytes(
        (Join-Path $malodyToOsuFullPackageSourceRoot ([string]$decoy.Name)),
        [byte[]]$decoy.Bytes)
}
foreach ($osuSourceName in @(
        $osuFullPackageMainFileName,
        $osuFullPackageSiblingFileName,
        "audio.mp3",
        "BG1.jpg",
        "BG3.png")) {
    Copy-Item `
        -LiteralPath (Join-Path $osuFullPackageTrustedSourceRoot $osuSourceName) `
        -Destination $osuFullPackageSourceRoot
}
foreach ($osuSourceName in @(
        $osuToMalodyFullPackageMainFileName,
        $osuToMalodyFullPackageSiblingFileName,
        "audio.mp3",
        "BG1.jpg",
        "BG3.png")) {
    Copy-Item `
        -LiteralPath (Join-Path $osuFullPackageTrustedSourceRoot $osuSourceName) `
        -Destination $osuToMalodyFullPackageSourceRoot
}
Copy-Item -LiteralPath $fixturePath `
    -Destination (Join-Path $osuToMalodyFullPackageSourceRoot "cross-format-decoy.mc")
foreach ($decoy in @(
        @{ Name = "cross-format-decoy.mcz"; Bytes = [byte[]](10, 11, 12) },
        @{ Name = "cross-format-decoy.osz"; Bytes = [byte[]](13, 14, 15) },
        @{ Name = "cross-format-decoy.luma-part"; Bytes = [byte[]](16, 17, 18) })) {
    [IO.File]::WriteAllBytes(
        (Join-Path $osuToMalodyFullPackageSourceRoot ([string]$decoy.Name)),
        [byte[]]$decoy.Bytes)
}
Copy-Item -LiteralPath $chartExportSpecsFixtureMcPath `
    -Destination $chartExportModesChartPath
Copy-Item -LiteralPath $chartExportSpecsCoverPath `
    -Destination $chartExportModesCoverPath
Copy-Item -LiteralPath $chartExportSpecsBackgroundPath `
    -Destination $chartExportModesBackgroundPath
Copy-Item -LiteralPath $chartExportSpecsKeySoundPath `
    -Destination $chartExportModesKeySoundPath
Copy-Item -LiteralPath $chartExportSpecsRealWavePath `
    -Destination $chartExportModesAudioPath
foreach ($libraryBatchFolder in @($libraryBatchAPath, $libraryBatchBPath, $libraryBatchOpenPath)) {
    Copy-Item -LiteralPath $fixturePath -Destination $libraryBatchFolder
    Copy-Item -LiteralPath $resoundCoverSourcePath -Destination $libraryBatchFolder
    Copy-Item -LiteralPath $keySoundSampleSourcePath -Destination $libraryBatchFolder
}
# Stable, strictly ordered creation times keep the two batch targets adjacent in the
# default newest-first library while the open document remains a separate first card.
$libraryBatchCreationAnchor = [DateTime]::UtcNow.AddMinutes(-10)
[IO.Directory]::SetCreationTimeUtc($libraryBatchAPath, $libraryBatchCreationAnchor)
[IO.Directory]::SetCreationTimeUtc($libraryBatchBPath, $libraryBatchCreationAnchor.AddSeconds(10))
[IO.Directory]::SetCreationTimeUtc($libraryBatchOpenPath, $libraryBatchCreationAnchor.AddSeconds(20))

$isolatedMcPath = Join-Path $mcLibraryDirectory (Split-Path -Leaf $fixturePath)
$isolatedOsuPath = Join-Path $osuLibraryDirectory (Split-Path -Leaf $osuFixturePath)
$isolatedPropertyMcPath = Join-Path $propertyMcDirectory (Split-Path -Leaf $fixturePath)
$isolatedGroupMcPath = Join-Path $groupMcDirectory (Split-Path -Leaf $fixturePath)
$isolatedProEditorPanPath = Join-Path $proEditorPanDirectory "proeditor-pan.mc"
$isolatedProEditorEditPath = Join-Path $proEditorEditDirectory "proeditor-edit.mc"
$isolatedKeySoundSharedMcPath = Join-Path $keySoundSharedMcDirectory (Split-Path -Leaf $fixturePath)
$isolatedKeySoundSharedAudioPath = Join-Path $keySoundSharedMcDirectory (Split-Path -Leaf $keySoundSampleSourcePath)
$isolatedKeySoundSilentMcPath = Join-Path $keySoundSilentFixtureRoot (Split-Path -Leaf $keySoundFlatFixturePath)
$isolatedKeySoundKickPath = Join-Path $keySoundSilentFixtureRoot "kick.ogg"
$isolatedChartValidationMcPath =
    Join-Path $chartValidationMcDirectory (Split-Path -Leaf $fixturePath)
$libraryBatchAChartPath = Join-Path $libraryBatchAPath (Split-Path -Leaf $fixturePath)
$libraryBatchBChartPath = Join-Path $libraryBatchBPath (Split-Path -Leaf $fixturePath)
$libraryBatchOpenChartPath = Join-Path $libraryBatchOpenPath (Split-Path -Leaf $fixturePath)
$libraryBatchAAudioPath = Join-Path $libraryBatchAPath (Split-Path -Leaf $keySoundSampleSourcePath)
$libraryBatchBAudioPath = Join-Path $libraryBatchBPath (Split-Path -Leaf $keySoundSampleSourcePath)
$libraryBatchOpenAudioPath = Join-Path $libraryBatchOpenPath (Split-Path -Leaf $keySoundSampleSourcePath)
$libraryBatchACoverPath = Join-Path $libraryBatchAPath (Split-Path -Leaf $resoundCoverSourcePath)
$libraryBatchBCoverPath = Join-Path $libraryBatchBPath (Split-Path -Leaf $resoundCoverSourcePath)
$libraryBatchOpenCoverPath = Join-Path $libraryBatchOpenPath (Split-Path -Leaf $resoundCoverSourcePath)
$malodyFullPackageSourceTreeBefore =
    Get-DirectoryTreeEvidence -Path $malodyFullPackageSourceRoot
$malodyFullPackageMainSourceSha256 =
    (Get-FileHash -LiteralPath $malodyFullPackageMainChartPath -Algorithm SHA256).Hash
$malodyFullPackageSourceMcFiles = @(
    Get-ChildItem -LiteralPath $malodyFullPackageSourceRoot -Recurse -File -Filter "*.mc")
$malodyFullPackageSourceShadowMcFiles = @(
    Get-ChildItem -LiteralPath $malodyFullPackageSourceRoot -Recurse -File -Filter "*.mc_")
$malodyFullPackageMainSourceJson =
    Get-Content -LiteralPath $malodyFullPackageMainChartPath -Raw | ConvertFrom-Json
$malodyFullPackageFocusSourceMatches = @(
    $malodyFullPackageMainSourceJson.note | Where-Object {
        $null -ne $_.column -and
        [int]$_.column -eq 1 -and
        @($_.beat).Count -ge 3 -and
        [int]$_.beat[0] -eq 182 -and
        [int]$_.beat[1] -eq 1 -and
        [int]$_.beat[2] -eq 4 -and
        $null -eq $_.endbeat
    })
if ($malodyFullPackageSourceTreeBefore.fileCount -ne 19 -or
    $malodyFullPackageSourceTreeBefore.directoryCount -ne 1 -or
    $malodyFullPackageSourceMcFiles.Count -ne 8 -or
    $malodyFullPackageSourceShadowMcFiles.Count -ne 8 -or
    $malodyFullPackageFocusSourceMatches.Count -ne 1 -or
    -not (Test-Path -LiteralPath $malodyFullPackageMainChartPath -PathType Leaf) -or
    $malodyFullPackageMainSourceSha256 -cne
        "72755927BC97EF334747343E61FF00FA9E1E5A134F1455A7EDF18DB779CBE2CF") {
    throw "The isolated real Infinity MCZ source did not contain the expected 8 MC, 8 shadow MC, and 3 resource files."
}
$malodyToOsuFullPackageSourceTreeBefore =
    Get-DirectoryTreeEvidence -Path $malodyToOsuFullPackageSourceRoot
$malodyToOsuFullPackageMainSourceSha256 =
    (Get-FileHash -LiteralPath $malodyToOsuFullPackageMainChartPath -Algorithm SHA256).Hash
$malodyToOsuFullPackageSourceMcFiles = @(
    Get-ChildItem -LiteralPath $malodyToOsuFullPackageSourceRoot -File -Filter "*.mc")
$malodyToOsuFullPackageSourceShadowMcFiles = @(
    Get-ChildItem -LiteralPath $malodyToOsuFullPackageSourceRoot -File -Filter "*.mc_")
$malodyToOsuFullPackageSourceArchiveDecoys = @(
    Get-ChildItem -LiteralPath $malodyToOsuFullPackageSourceRoot -File | Where-Object {
        $_.Extension -in ".mcz", ".osz", ".luma-part"
    })
if ($malodyToOsuFullPackageSourceTreeBefore.fileCount -ne 8 -or
    $malodyToOsuFullPackageSourceTreeBefore.directoryCount -ne 0 -or
    $malodyToOsuFullPackageSourceMcFiles.Count -ne 3 -or
    $malodyToOsuFullPackageSourceShadowMcFiles.Count -ne 0 -or
    $malodyToOsuFullPackageSourceArchiveDecoys.Count -ne 3 -or
    $malodyToOsuFullPackageMainSourceSha256 -cne
        "72755927BC97EF334747343E61FF00FA9E1E5A134F1455A7EDF18DB779CBE2CF") {
    throw "The isolated real flat Infinity cross-format source did not retain one main MC, two real sibling MC decoys, two referenced resources, and three archive decoys."
}
$osuFullPackageSourceTreeBefore =
    Get-DirectoryTreeEvidence -Path $osuFullPackageSourceRoot
$osuFullPackageExpectedSourceHashes = [ordered]@{
    $osuFullPackageMainFileName =
        "511866870F99BDC7443006FA7420C7A9D21198F49B9EC13B50A32293E7F58E57"
    $osuFullPackageSiblingFileName =
        "D5C3F84A592614985754B1C491AD89515AE4EA049D7B3FAA2E87ED66D05E26D1"
    "audio.mp3" = "9FCDCFE8016197E6BC8427E8C7992FFF701D3714851EB367894E674E42EA7606"
    "BG1.jpg" = "D859A93B1E758AF13581C18719E3B6E27E9019A369351D32B96C4FFCF383480B"
    "BG3.png" = "A2B9F1D6101A8B02043C6E7B8C80C21A0E21BC44FD5C60A946E4EBB8EE2097F5"
}
$osuFullPackageSourceHashMismatches = @(
    foreach ($entry in $osuFullPackageExpectedSourceHashes.GetEnumerator()) {
        $stagedPath = Join-Path $osuFullPackageSourceRoot ([string]$entry.Key)
        $trustedPath = Join-Path $osuFullPackageTrustedSourceRoot ([string]$entry.Key)
        if (-not (Test-Path -LiteralPath $stagedPath -PathType Leaf) -or
            -not (Test-Path -LiteralPath $trustedPath -PathType Leaf) -or
            (Get-FileHash -LiteralPath $stagedPath -Algorithm SHA256).Hash -cne
                [string]$entry.Value -or
            (Get-FileHash -LiteralPath $trustedPath -Algorithm SHA256).Hash -cne
                [string]$entry.Value) {
            [string]$entry.Key
        }
    })
if ($osuFullPackageSourceTreeBefore.fileCount -ne 5 -or
    $osuFullPackageSourceTreeBefore.directoryCount -ne 0 -or
    $osuFullPackageSourceHashMismatches.Count -ne 0) {
    throw "The isolated osu FullPackage source is not the exact trusted five-file Michishirube tree."
}
$osuToMalodyFullPackageSourceTreeBefore =
    Get-DirectoryTreeEvidence -Path $osuToMalodyFullPackageSourceRoot
$osuToMalodyFullPackageExpectedSourceHashes = [ordered]@{
    $osuToMalodyFullPackageMainFileName =
        "511866870F99BDC7443006FA7420C7A9D21198F49B9EC13B50A32293E7F58E57"
    $osuToMalodyFullPackageSiblingFileName =
        "D5C3F84A592614985754B1C491AD89515AE4EA049D7B3FAA2E87ED66D05E26D1"
    "audio.mp3" = "9FCDCFE8016197E6BC8427E8C7992FFF701D3714851EB367894E674E42EA7606"
    "BG1.jpg" = "D859A93B1E758AF13581C18719E3B6E27E9019A369351D32B96C4FFCF383480B"
    "BG3.png" = "A2B9F1D6101A8B02043C6E7B8C80C21A0E21BC44FD5C60A946E4EBB8EE2097F5"
    "cross-format-decoy.mc" =
        "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
    "cross-format-decoy.mcz" =
        "9909EC831E2CF6D0C73FB5480F31945A80987A13FAEE005704166CB53A26CECA"
    "cross-format-decoy.osz" =
        "D41470F8FE2547D6C4D4802D484FE7FF5A5BBECD5612EEEB1360DF0C4781D95E"
    "cross-format-decoy.luma-part" =
        "29076AE7ED6040C5991A47529AA02EB702578C4C6DA21F3B975574154B0EE303"
}
$osuToMalodyFullPackageSourceHashMismatches = @(
    foreach ($entry in $osuToMalodyFullPackageExpectedSourceHashes.GetEnumerator()) {
        $stagedPath =
            Join-Path $osuToMalodyFullPackageSourceRoot ([string]$entry.Key)
        if (-not (Test-Path -LiteralPath $stagedPath -PathType Leaf) -or
            (Get-FileHash -LiteralPath $stagedPath -Algorithm SHA256).Hash -cne
                [string]$entry.Value) {
            [string]$entry.Key
        }
    })
$osuToMalodyFullPackageSourceOsuFiles = @(
    Get-ChildItem -LiteralPath $osuToMalodyFullPackageSourceRoot -File -Filter "*.osu")
$osuToMalodyFullPackageSourceMcFiles = @(
    Get-ChildItem -LiteralPath $osuToMalodyFullPackageSourceRoot -File -Filter "*.mc")
$osuToMalodyFullPackageSourceArchiveDecoys = @(
    Get-ChildItem -LiteralPath $osuToMalodyFullPackageSourceRoot -File | Where-Object {
        $_.Extension -in ".mcz", ".osz", ".luma-part"
    })
if ($osuToMalodyFullPackageSourceTreeBefore.fileCount -ne 9 -or
    $osuToMalodyFullPackageSourceTreeBefore.directoryCount -ne 0 -or
    $osuToMalodyFullPackageSourceOsuFiles.Count -ne 2 -or
    $osuToMalodyFullPackageSourceMcFiles.Count -ne 1 -or
    $osuToMalodyFullPackageSourceArchiveDecoys.Count -ne 3 -or
    $osuToMalodyFullPackageSourceHashMismatches.Count -ne 0) {
    throw "The isolated osu-to-MCZ source is not the exact trusted five-file Michishirube tree plus one MC and three archive decoys."
}
if ((Get-FileHash -LiteralPath $isolatedMcPath -Algorithm SHA256).Hash -ne $fixtureSha256 -or
    (Get-FileHash -LiteralPath $isolatedOsuPath -Algorithm SHA256).Hash -ne $osuFixtureSha256 -or
    (Get-FileHash -LiteralPath $isolatedPropertyMcPath -Algorithm SHA256).Hash -ne $fixtureSha256 -or
    (Get-FileHash -LiteralPath $isolatedGroupMcPath -Algorithm SHA256).Hash -ne $fixtureSha256 -or
    (Get-FileHash -LiteralPath $isolatedProEditorPanPath -Algorithm SHA256).Hash -ne $proEditorFixtureSha256 -or
    (Get-FileHash -LiteralPath $isolatedProEditorEditPath -Algorithm SHA256).Hash -ne $proEditorFixtureSha256 -or
    (Get-FileHash -LiteralPath $isolatedKeySoundSharedMcPath -Algorithm SHA256).Hash -ne $fixtureSha256 -or
    (Get-FileHash -LiteralPath $isolatedKeySoundSharedAudioPath -Algorithm SHA256).Hash -ne
        $keySoundSampleSourceSha256 -or
    (Get-FileHash -LiteralPath $isolatedKeySoundSilentMcPath -Algorithm SHA256).Hash -ne
        $keySoundFlatFixtureSha256 -or
    (Get-FileHash -LiteralPath $isolatedKeySoundKickPath -Algorithm SHA256).Hash -ne
        $keySoundSampleSourceSha256 -or
    (Get-FileHash -LiteralPath $isolatedChartValidationMcPath -Algorithm SHA256).Hash -ne
        $fixtureSha256 -or
    (Get-FileHash -LiteralPath $libraryBatchAChartPath -Algorithm SHA256).Hash -ne
        $fixtureSha256 -or
    (Get-FileHash -LiteralPath $libraryBatchBChartPath -Algorithm SHA256).Hash -ne
        $fixtureSha256 -or
    (Get-FileHash -LiteralPath $libraryBatchOpenChartPath -Algorithm SHA256).Hash -ne
        $fixtureSha256 -or
    @(@($libraryBatchAAudioPath, $libraryBatchBAudioPath, $libraryBatchOpenAudioPath) |
        Where-Object {
            (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash -cne
                $keySoundSampleSourceSha256
        }).Count -ne 0 -or
    @(@($libraryBatchACoverPath, $libraryBatchBCoverPath, $libraryBatchOpenCoverPath) |
        Where-Object {
            (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash -cne
                $resoundCoverSourceSha256
        }).Count -ne 0) {
    throw "An isolated GUI fixture copy does not match its trusted source."
}
$chartExportModesSourceTreeBefore =
    Get-DirectoryTreeEvidence -Path $chartExportModesSourceRoot
$chartExportModesExpectedSourceHashes = [ordered]@{
    'fixture.mc' = [string]$chartExportSpecsInputAuthorities.fixtureMc.sha256
    'audio.wav' = [string]$chartExportSpecsInputAuthorities.realWave.sha256
    'cover.png' = [string]$chartExportSpecsInputAuthorities.cover.sha256
    'background.jpg' = [string]$chartExportSpecsInputAuthorities.background.sha256
    'key.wav' = [string]$chartExportSpecsInputAuthorities.keySound.sha256
}
$chartExportModesSourceHashMismatches = @(
    foreach ($entry in $chartExportModesExpectedSourceHashes.GetEnumerator()) {
        $sourcePath = Join-Path $chartExportModesSourceRoot ([string]$entry.Key)
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -or
            (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -cne
                [string]$entry.Value) {
            [string]$entry.Key
        }
    })
$chartExportModesSourceJson =
    Get-Content -LiteralPath $chartExportModesChartPath -Raw | ConvertFrom-Json
$chartExportModesSourceTargetNotes = @(
    $chartExportModesSourceJson.note | Where-Object {
        [int]$_.column -eq 2 -and $null -eq $_.endbeat -and
        (Test-ExactIntegerArray -Value @($_.beat) -Expected @(3, 10, 12)) -and
        [string]$_.sound -ceq 'key.wav'
    })
$chartExportModesSourceLongNotes = @(
    $chartExportModesSourceJson.note | Where-Object {
        [int]$_.column -eq 1 -and
        (Test-ExactIntegerArray -Value @($_.beat) -Expected @(5, 3, 8)) -and
        (Test-ExactIntegerArray -Value @($_.endbeat) -Expected @(6, 7, 8))
    })
$chartExportModesSourceAudioNotes = @(
    $chartExportModesSourceJson.note | Where-Object {
        [int]$_.type -eq 1 -and [string]$_.sound -ceq 'audio.wav' -and
        [Math]::Abs([double]$_.offset - 80) -le .000001
    })
if ($chartExportModesSourceTreeBefore.directoryCount -ne 0 -or
    $chartExportModesSourceTreeBefore.fileCount -ne 5 -or
    $chartExportModesSourceHashMismatches.Count -ne 0 -or
    [string]$chartExportModesSourceJson.meta.version -cne 'Disk version' -or
    [int]$chartExportModesSourceJson.meta.preview -ne 1234 -or
    [Math]::Abs([double]$chartExportModesSourceJson.meta.song.bpm - 120) -gt .000001 -or
    [string]$chartExportModesSourceJson.meta.song.file -cne 'audio.wav' -or
    @($chartExportModesSourceJson.time).Count -ne 1 -or
    [Math]::Abs([double]$chartExportModesSourceJson.time[0].bpm - 120) -gt .000001 -or
    [Math]::Abs([double]$chartExportModesSourceJson.time[0].delay - 80) -gt .000001 -or
    $chartExportModesSourceTargetNotes.Count -ne 1 -or
    $chartExportModesSourceLongNotes.Count -ne 1 -or
    $chartExportModesSourceAudioNotes.Count -ne 1) {
    throw "The isolated formal chart-export GUI fixture is not the exact five-file real-WAV discriminating source."
}
$libraryBatchTreesBefore = [pscustomobject][ordered]@{
    batchA = Get-DirectoryTreeEvidence -Path $libraryBatchAPath
    batchB = Get-DirectoryTreeEvidence -Path $libraryBatchBPath
    open = Get-DirectoryTreeEvidence -Path $libraryBatchOpenPath
}
if (@(@($libraryBatchTreesBefore.batchA, $libraryBatchTreesBefore.batchB,
        $libraryBatchTreesBefore.open) | Where-Object {
            [int]$_.directoryCount -ne 0 -or [int]$_.fileCount -ne 3 -or
            [long]$_.sizeBytes -le 0 -or [string]::IsNullOrWhiteSpace([string]$_.sha256)
        }).Count -ne 0) {
    throw "The isolated library batch-deletion fixtures are not complete three-file real Resound trees."
}
$libraryBatchOpenSourceBeforeItem = Get-Item -LiteralPath $libraryBatchOpenChartPath
$libraryBatchOpenSourceBefore = [pscustomobject][ordered]@{
    path = $libraryBatchOpenSourceBeforeItem.FullName
    length = [long]$libraryBatchOpenSourceBeforeItem.Length
    sha256 = (Get-FileHash -LiteralPath $libraryBatchOpenChartPath -Algorithm SHA256).Hash
    lastWriteTimeUtc = $libraryBatchOpenSourceBeforeItem.LastWriteTimeUtc.ToString("O")
}

$libraryScreenshotPath = Join-Path $guiRoot "avalonia-library-grouped.png"
$libraryCapture = Invoke-GuiCaptureGate -Name "avalonia-library-gui-capture" -Arguments @{
    LibraryHome = $true
    ScreenshotPath = $libraryScreenshotPath
    WorkspaceRoot = $libraryRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\library\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\library\editing")
}
$libraryNoResultsEvidencePath = Join-Path $guiRoot "avalonia-library-search-zero-runtime-v1.json"
$libraryNoResultsScreenshotPath = Join-Path $guiRoot "avalonia-library-search-zero-v1.png"
$libraryNoResultsQuery = "zzzz-lumachart-no-result-zzzz"
$libraryNoResultsCapture = Invoke-GuiCaptureGate -Name "avalonia-library-search-zero-gui-capture" -Arguments @{
    LibraryHome = $true
    ExerciseLibraryNoResults = $true
    LibraryNoResultsQuery = $libraryNoResultsQuery
    InteractionEvidencePath = $libraryNoResultsEvidencePath
    ScreenshotPath = $libraryNoResultsScreenshotPath
    WorkspaceRoot = $libraryRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\library-search-zero\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\library-search-zero\editing")
    TimeoutSeconds = 60
}
$realGuiPath = Join-Path $guiRoot "avalonia-real-mc-ln-tail-runtime-v1.json"
$realInteractionGuiPath = Join-Path $guiRoot "avalonia-real-mc-ln-tail-interaction-runtime-v1.json"
$realScreenshotPath = Join-Path $guiRoot "avalonia-real-mc-ln-tail-v1.png"
$realCapture = Invoke-GuiCaptureGate -Name "avalonia-real-mc-gui-capture" -Arguments @{
    ChartPath = $isolatedMcPath
    EvidencePath = $realGuiPath
    InteractionEvidencePath = $realInteractionGuiPath
    ScreenshotPath = $realScreenshotPath
    WorkspaceRoot = $libraryRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\real-mc\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\real-mc\editing")
    FocusHoldTail = $true
    ExerciseHoldTailResize = $true
    EnableBackgroundWaveform = $true
    EnableBackgroundSpectrogram = $true
    InteractionDelayMilliseconds = 8000
    TimeoutSeconds = 90
}
$transformGuiPath = Join-Path $guiRoot "avalonia-real-mc-note-transform-runtime-v1.json"
$transformInteractionGuiPath = Join-Path $guiRoot "avalonia-real-mc-note-transform-interaction-runtime-v1.json"
$transformScreenshotPath = Join-Path $guiRoot "avalonia-real-mc-note-transform-v1.png"
$transformCapture = Invoke-GuiCaptureGate -Name "avalonia-real-mc-note-transform-gui-capture" -Arguments @{
    ChartPath = $isolatedMcPath
    EvidencePath = $transformGuiPath
    InteractionEvidencePath = $transformInteractionGuiPath
    ScreenshotPath = $transformScreenshotPath
    WorkspaceRoot = $libraryRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\real-mc-transform\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\real-mc-transform\editing")
    FocusHoldTail = $true
    ExerciseLongToTap = $true
    EnableBackgroundWaveform = $true
    EnableBackgroundSpectrogram = $true
    InteractionDelayMilliseconds = 3500
}
$propertyGuiPath = Join-Path $guiRoot "avalonia-real-mc-note-property-runtime-v1.json"
$propertyInteractionGuiPath = Join-Path $guiRoot "avalonia-real-mc-note-property-saved-runtime-v1.json"
$propertyScreenshotPath = Join-Path $guiRoot "avalonia-real-mc-note-property-saved-v1.png"
$propertyCapture = Invoke-GuiCaptureGate -Name "avalonia-real-mc-note-property-gui-capture" -Arguments @{
    ChartPath = $isolatedPropertyMcPath
    EvidencePath = $propertyGuiPath
    InteractionEvidencePath = $propertyInteractionGuiPath
    ScreenshotPath = $propertyScreenshotPath
    WorkspaceRoot = $propertyFixtureRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\real-mc-note-property\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\real-mc-note-property\editing")
    FocusNoteProperty = $true
    ExerciseNoteProperty = $true
    SaveAfterNoteProperty = $true
    DeriveNotePropertyFromSelection = $true
    NotePropertyVolume = "73"
    NotePropertySound = ""
    NotePropertyGroup = "7"
    EnableBackgroundWaveform = $true
    EnableBackgroundSpectrogram = $true
    InteractionDelayMilliseconds = 6000
    TimeoutSeconds = 90
}
$propertySavedSha256 = (Get-FileHash -LiteralPath $isolatedPropertyMcPath -Algorithm SHA256).Hash
if ($propertySavedSha256 -eq $fixtureSha256) {
    throw "The real MC Note-property GUI exercise did not save a changed isolated source file."
}
$propertyReopenGuiPath = Join-Path $guiRoot "avalonia-real-mc-note-property-reopened-runtime-v1.json"
$propertyReopenScreenshotPath = Join-Path $guiRoot "avalonia-real-mc-note-property-reopened-v1.png"
$propertyReopenCapture = Invoke-GuiCaptureGate -Name "avalonia-real-mc-note-property-reopen-gui-capture" -Arguments @{
    ChartPath = $isolatedPropertyMcPath
    EvidencePath = $propertyReopenGuiPath
    ScreenshotPath = $propertyReopenScreenshotPath
    WorkspaceRoot = $propertyFixtureRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\real-mc-note-property-reopen\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\real-mc-note-property-reopen\editing")
    FocusNoteProperty = $true
    FocusNotePropertyBeat = $propertyCapture.capture.notePropertySubmitted.beat
    EnableBackgroundWaveform = $true
    EnableBackgroundSpectrogram = $true
    TimeoutSeconds = 90
}
$groupAssignGuiPath = Join-Path $guiRoot "avalonia-real-mc-group-assign-runtime-v1.json"
$groupSavedGuiPath = Join-Path $guiRoot "avalonia-real-mc-group-saved-runtime-v1.json"
$groupSavedScreenshotPath = Join-Path $guiRoot "avalonia-real-mc-group-saved-v1.png"
$groupAssignCapture = Invoke-GuiCaptureGate -Name "avalonia-real-mc-group-assign-gui-capture" -Arguments @{
    ChartPath = $isolatedGroupMcPath
    EvidencePath = $groupAssignGuiPath
    InteractionEvidencePath = $groupSavedGuiPath
    ScreenshotPath = $groupSavedScreenshotPath
    WorkspaceRoot = $groupFixtureRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\real-mc-group-assign\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\real-mc-group-assign\editing")
    FocusGroup = $true
    ExerciseGroupAssign = $true
    SaveAfterGroupAssign = $true
    GroupId = "7"
    EnableBackgroundWaveform = $true
    EnableBackgroundSpectrogram = $true
    InteractionDelayMilliseconds = 12000
    TimeoutSeconds = 120
}
$groupSavedSha256 = (Get-FileHash -LiteralPath $isolatedGroupMcPath -Algorithm SHA256).Hash
if ($groupSavedSha256 -eq $fixtureSha256) {
    throw "The real MC Group GUI exercise did not save a changed isolated source file."
}
$groupVisibilityGuiPath = Join-Path $guiRoot "avalonia-real-mc-group-visibility-runtime-v1.json"
$groupHiddenGuiPath = Join-Path $guiRoot "avalonia-real-mc-group-hidden-runtime-v1.json"
$groupHiddenScreenshotPath = Join-Path $guiRoot "avalonia-real-mc-group-hidden-v1.png"
$groupVisibilityCapture = Invoke-GuiCaptureGate -Name "avalonia-real-mc-group-visibility-gui-capture" -Arguments @{
    ChartPath = $isolatedGroupMcPath
    EvidencePath = $groupVisibilityGuiPath
    InteractionEvidencePath = $groupHiddenGuiPath
    ScreenshotPath = $groupHiddenScreenshotPath
    WorkspaceRoot = $groupFixtureRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\real-mc-group-visibility\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\real-mc-group-visibility\editing")
    FocusGroup = $true
    FocusGroupBeat = $groupAssignCapture.capture.groupSubmitted.focusBeat
    ExerciseGroupVisibility = $true
    GroupId = "7"
    EnableBackgroundWaveform = $true
    EnableBackgroundSpectrogram = $true
    InteractionDelayMilliseconds = 15000
    TimeoutSeconds = 120
}
$groupPlacementGuiPath = Join-Path $guiRoot "avalonia-real-mc-group-placement-runtime-v1.json"
$groupPlacedGuiPath = Join-Path $guiRoot "avalonia-real-mc-group-tap-hold-placed-runtime-v1.json"
$groupPlacedScreenshotPath = Join-Path $guiRoot "avalonia-real-mc-group-tap-hold-placed-v1.png"
$groupPlacementCapture = Invoke-GuiCaptureGate -Name "avalonia-real-mc-group-placement-gui-capture" -Arguments @{
    ChartPath = $isolatedGroupMcPath
    EvidencePath = $groupPlacementGuiPath
    InteractionEvidencePath = $groupPlacedGuiPath
    ScreenshotPath = $groupPlacedScreenshotPath
    WorkspaceRoot = $groupFixtureRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\real-mc-group-placement\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\real-mc-group-placement\editing")
    FocusGroup = $true
    FocusGroupBeat = $groupAssignCapture.capture.groupSubmitted.focusBeat
    ExerciseGroupPlacement = $true
    GroupId = "7"
    EnableBackgroundWaveform = $true
    EnableBackgroundSpectrogram = $true
    InteractionDelayMilliseconds = 20000
    TimeoutSeconds = 120
}
$osuGuiPath = Join-Path $guiRoot "avalonia-real-osu-timing-mixed-runtime-v1.json"
$osuInteractionGuiPath = Join-Path $guiRoot "avalonia-real-osu-edge-scroll-runtime-v1.json"
$osuScreenshotPath = Join-Path $guiRoot "avalonia-real-osu-timing-mixed-v1.png"
$osuCapture = Invoke-GuiCaptureGate -Name "avalonia-real-osu-gui-capture" -Arguments @{
    ChartPath = $isolatedOsuPath
    EvidencePath = $osuGuiPath
    InteractionEvidencePath = $osuInteractionGuiPath
    ScreenshotPath = $osuScreenshotPath
    WorkspaceRoot = $libraryRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\real-osu\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\real-osu\editing")
    FocusTiming = $true
    ExerciseEdgeScroll = $true
    EnableBackgroundWaveform = $true
    EnableBackgroundSpectrogram = $true
    InteractionDelayMilliseconds = 3500
}
$hundredKGuiPath = Join-Path $guiRoot "avalonia-100000-note-timing-mixed-runtime-v1.json"
$hundredKScreenshotPath = Join-Path $guiRoot "avalonia-100000-note-timing-mixed-v1.png"
$hundredKCapture = Invoke-GuiCaptureGate -Name "avalonia-100000-note-gui-capture" -Arguments @{
    ChartPath = $isolatedMcPath
    EvidencePath = $hundredKGuiPath
    ScreenshotPath = $hundredKScreenshotPath
    WorkspaceRoot = $libraryRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\100000-note\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\100000-note\editing")
    SyntheticNoteCount = 100000
}

$keySoundSharedGuiPath = Join-Path $guiRoot "avalonia-key-sound-shared-runtime-v1.json"
$keySoundSharedInteractionGuiPath = Join-Path $guiRoot "avalonia-key-sound-shared-submitted-runtime-v1.json"
$keySoundSharedScreenshotPath = Join-Path $guiRoot "avalonia-key-sound-shared-v1.png"
$keySoundSharedCapture = Invoke-GuiCaptureGate -Name "avalonia-key-sound-shared-gui-capture" -Arguments @{
    ChartPath = $isolatedKeySoundSharedMcPath
    EvidencePath = $keySoundSharedGuiPath
    InteractionEvidencePath = $keySoundSharedInteractionGuiPath
    ScreenshotPath = $keySoundSharedScreenshotPath
    WorkspaceRoot = $keySoundSharedFixtureRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\key-sound-shared\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\key-sound-shared\editing")
    FocusKeySound = $true
    ExerciseKeySoundRuntime = $true
    InteractionDelayMilliseconds = 30000
    TimeoutSeconds = 120
}

$keySoundSilentGuiPath = Join-Path $guiRoot "avalonia-key-sound-silent-runtime-v1.json"
$keySoundSilentInteractionGuiPath = Join-Path $guiRoot "avalonia-key-sound-silent-submitted-runtime-v1.json"
$keySoundSilentScreenshotPath = Join-Path $guiRoot "avalonia-key-sound-silent-v1.png"
$keySoundSilentCapture = Invoke-GuiCaptureGate -Name "avalonia-key-sound-silent-gui-capture" -Arguments @{
    ChartPath = $isolatedKeySoundSilentMcPath
    EvidencePath = $keySoundSilentGuiPath
    InteractionEvidencePath = $keySoundSilentInteractionGuiPath
    ScreenshotPath = $keySoundSilentScreenshotPath
    WorkspaceRoot = $keySoundSilentFixtureRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\key-sound-silent\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\key-sound-silent\editing")
    FocusKeySound = $true
    ExerciseKeySoundRuntime = $true
    InteractionDelayMilliseconds = 30000
    TimeoutSeconds = 120
}

$displayScaleLocalDataRoot = Join-Path $guiRoot "sessions\display-scale\local-data"
$displayScaleSettingsPath = Join-Path $displayScaleLocalDataRoot "display-scale-settings.json"
$displayScaleGuiPath = Join-Path $guiRoot "avalonia-display-scale-runtime-v1.json"
$displayScaleInteractionGuiPath = Join-Path $guiRoot "avalonia-display-scale-submitted-runtime-v1.json"
$displayScaleScreenshotPath = Join-Path $guiRoot "avalonia-display-scale-submitted-v1.png"
$displayScaleCapture = Invoke-GuiCaptureGate -Name "avalonia-display-scale-gui-capture" -Arguments @{
    ChartPath = $isolatedMcPath
    EvidencePath = $displayScaleGuiPath
    InteractionEvidencePath = $displayScaleInteractionGuiPath
    ScreenshotPath = $displayScaleScreenshotPath
    WorkspaceRoot = $libraryRoot
    LocalDataRoot = $displayScaleLocalDataRoot
    EditingRoot = (Join-Path $guiRoot "sessions\display-scale\first-editing")
    FocusDisplayScale = $true
    ExerciseDisplayScale = $true
    DisplayScaleUiPercent = 135
    DisplayScaleFontPercent = 125
    InteractionDelayMilliseconds = 12000
    TimeoutSeconds = 90
}
if (-not (Test-Path -LiteralPath $displayScaleSettingsPath -PathType Leaf)) {
    throw "The display-scale GUI exercise did not persist its isolated settings file."
}
$displayScaleSettingsSha256AfterSubmit =
    (Get-FileHash -LiteralPath $displayScaleSettingsPath -Algorithm SHA256).Hash

$displayScaleReopenGuiPath = Join-Path $guiRoot "avalonia-display-scale-reopened-runtime-v1.json"
$displayScaleReopenScreenshotPath = Join-Path $guiRoot "avalonia-display-scale-reopened-v1.png"
$displayScaleReopenCapture = Invoke-GuiCaptureGate -Name "avalonia-display-scale-reopen-gui-capture" -Arguments @{
    ChartPath = $isolatedMcPath
    EvidencePath = $displayScaleReopenGuiPath
    ScreenshotPath = $displayScaleReopenScreenshotPath
    WorkspaceRoot = $libraryRoot
    LocalDataRoot = $displayScaleLocalDataRoot
    EditingRoot = (Join-Path $guiRoot "sessions\display-scale\reopen-editing")
    FocusDisplayScale = $true
    DisplayScaleUiPercent = 135
    DisplayScaleFontPercent = 125
    AllowExistingLocalDataRoot = $true
    TimeoutSeconds = 90
}
$displayScaleSettingsSha256AfterReopen =
    (Get-FileHash -LiteralPath $displayScaleSettingsPath -Algorithm SHA256).Hash
if ($displayScaleSettingsSha256AfterReopen -cne $displayScaleSettingsSha256AfterSubmit) {
    throw "The read-only display-scale reopen unexpectedly rewrote its persisted settings."
}

$displayScaleCorruptRoot = Join-Path $guiRoot "sessions\display-scale-corrupt"
$displayScaleCorruptLocalDataRoot = Join-Path $displayScaleCorruptRoot "local-data"
$displayScaleCorruptSettingsPath = Join-Path $displayScaleCorruptLocalDataRoot "display-scale-settings.json"
New-Item -ItemType Directory -Path $displayScaleCorruptLocalDataRoot -Force | Out-Null
[IO.File]::WriteAllText(
    $displayScaleCorruptSettingsPath,
    "{not-json",
    [Text.UTF8Encoding]::new($false))
$displayScaleCorruptSettingsSha256Before =
    (Get-FileHash -LiteralPath $displayScaleCorruptSettingsPath -Algorithm SHA256).Hash
$displayScaleCorruptGuiPath = Join-Path $guiRoot "avalonia-display-scale-corrupt-recovered-runtime-v1.json"
$displayScaleCorruptScreenshotPath = Join-Path $guiRoot "avalonia-display-scale-corrupt-recovered-v1.png"
$displayScaleCorruptCapture = Invoke-GuiCaptureGate `
    -Name "avalonia-display-scale-corrupt-recovery-gui-capture" `
    -Arguments @{
        ChartPath = $isolatedMcPath
        EvidencePath = $displayScaleCorruptGuiPath
        ScreenshotPath = $displayScaleCorruptScreenshotPath
        WorkspaceRoot = $libraryRoot
        LocalDataRoot = $displayScaleCorruptLocalDataRoot
        EditingRoot = (Join-Path $displayScaleCorruptRoot "editing")
        FocusDisplayScale = $true
        DisplayScaleUiPercent = 100
        DisplayScaleFontPercent = 100
        AllowExistingLocalDataRoot = $true
        TimeoutSeconds = 90
    }
if (-not (Test-Path -LiteralPath $displayScaleCorruptSettingsPath -PathType Leaf)) {
    throw "The corrupt display-scale recovery did not atomically rewrite its settings file."
}
$displayScaleCorruptSettingsSha256After =
    (Get-FileHash -LiteralPath $displayScaleCorruptSettingsPath -Algorithm SHA256).Hash
if ($displayScaleCorruptSettingsSha256After -ceq $displayScaleCorruptSettingsSha256Before) {
    throw "The corrupt display-scale recovery left the invalid settings bytes unchanged."
}
$displayScaleCorruptTemporaryFiles = @(Get-ChildItem `
    -LiteralPath $displayScaleCorruptLocalDataRoot `
    -Filter ".display-scale-settings.json.*.tmp" `
    -File `
    -Force)
if ($displayScaleCorruptTemporaryFiles.Count -ne 0) {
    throw "The corrupt display-scale recovery left an atomic-save temporary file behind."
}

$audioPanelDefaultLocalDataRoot = Join-Path $guiRoot "sessions\audio-panels-default\local-data"
$audioPanelDefaultSettingsPath = Join-Path $audioPanelDefaultLocalDataRoot "audio-panel-settings.json"
$audioPanelDefaultGuiPath = Join-Path $guiRoot "avalonia-audio-panels-default-runtime-v1.json"
$audioPanelDefaultScreenshotPath = Join-Path $guiRoot "avalonia-audio-panels-default-v1.png"
$audioPanelDefaultCapture = Invoke-GuiCaptureGate -Name "avalonia-audio-panels-default-gui-capture" -Arguments @{
    ChartPath = $isolatedMcPath
    EvidencePath = $audioPanelDefaultGuiPath
    ScreenshotPath = $audioPanelDefaultScreenshotPath
    WorkspaceRoot = $libraryRoot
    LocalDataRoot = $audioPanelDefaultLocalDataRoot
    EditingRoot = (Join-Path $guiRoot "sessions\audio-panels-default\editing")
    FocusAudioPanels = $true
    TimeoutSeconds = 90
}
if (-not (Test-Path -LiteralPath $audioPanelDefaultSettingsPath -PathType Leaf)) {
    throw "The default audio-panel GUI focus did not persist its isolated settings file."
}
$audioPanelDefaultSettingsSha256 =
    (Get-FileHash -LiteralPath $audioPanelDefaultSettingsPath -Algorithm SHA256).Hash

$audioPanelLocalDataRoot = Join-Path $guiRoot "sessions\audio-panels\local-data"
$audioPanelSettingsPath = Join-Path $audioPanelLocalDataRoot "audio-panel-settings.json"
$audioPanelGuiPath = Join-Path $guiRoot "avalonia-audio-panels-runtime-v1.json"
$audioPanelInteractionGuiPath = Join-Path $guiRoot "avalonia-audio-panels-interaction-runtime-v1.json"
$audioPanelScreenshotPath = Join-Path $guiRoot "avalonia-audio-panels-interaction-v1.png"
$audioPanelCapture = Invoke-GuiCaptureGate -Name "avalonia-audio-panels-gui-capture" -Arguments @{
    ChartPath = $isolatedMcPath
    EvidencePath = $audioPanelGuiPath
    InteractionEvidencePath = $audioPanelInteractionGuiPath
    ScreenshotPath = $audioPanelScreenshotPath
    WorkspaceRoot = $libraryRoot
    LocalDataRoot = $audioPanelLocalDataRoot
    EditingRoot = (Join-Path $guiRoot "sessions\audio-panels\editing")
    ExerciseAudioPanels = $true
    InteractionDelayMilliseconds = 12000
    TimeoutSeconds = 90
}
if (-not (Test-Path -LiteralPath $audioPanelSettingsPath -PathType Leaf)) {
    throw "The audio-panel GUI exercise did not persist its isolated settings file."
}
$audioPanelSettingsSha256AfterInteraction =
    (Get-FileHash -LiteralPath $audioPanelSettingsPath -Algorithm SHA256).Hash

$audioPanelReopenGuiPath = Join-Path $guiRoot "avalonia-audio-panels-reopened-runtime-v1.json"
$audioPanelReopenScreenshotPath = Join-Path $guiRoot "avalonia-audio-panels-reopened-v1.png"
$audioPanelReopenCapture = Invoke-GuiCaptureGate -Name "avalonia-audio-panels-reopen-gui-capture" -Arguments @{
    ChartPath = $isolatedMcPath
    EvidencePath = $audioPanelReopenGuiPath
    ScreenshotPath = $audioPanelReopenScreenshotPath
    WorkspaceRoot = $libraryRoot
    LocalDataRoot = $audioPanelLocalDataRoot
    EditingRoot = (Join-Path $guiRoot "sessions\audio-panels-reopen\editing")
    FocusAudioPanels = $true
    AllowExistingLocalDataRoot = $true
    TimeoutSeconds = 90
}
$audioPanelSettingsSha256AfterReopen =
    (Get-FileHash -LiteralPath $audioPanelSettingsPath -Algorithm SHA256).Hash
if ($audioPanelSettingsSha256AfterReopen -cne $audioPanelSettingsSha256AfterInteraction) {
    throw "The fresh audio-panel reopen changed its persisted settings bytes."
}

$chartValidationLocalDataRoot =
    Join-Path $guiRoot "sessions\chart-validation\local-data"
$chartValidationScaleSettingsPath =
    Initialize-DisplayScaleRoot $chartValidationLocalDataRoot
$chartValidationGuiPath =
    Join-Path $guiRoot "avalonia-chart-validation-primary-runtime-v1.json"
$chartValidationInteractionGuiPath =
    Join-Path $guiRoot "avalonia-chart-validation-interaction-runtime-v1.json"
$chartValidationScreenshotPath =
    Join-Path $guiRoot "avalonia-chart-validation-final-v1.png"
$chartValidationManualDialogScreenshotPath =
    Join-Path $guiRoot "avalonia-chart-validation-manual-dialog-v1.png"
$chartValidationSaveBlockedDialogScreenshotPath =
    Join-Path $guiRoot "avalonia-chart-validation-save-blocked-dialog-v1.png"
$chartValidationSourceItemBefore = Get-Item -LiteralPath $isolatedChartValidationMcPath
$chartValidationSourceBefore = [pscustomobject][ordered]@{
    path = $chartValidationSourceItemBefore.FullName
    length = [long]$chartValidationSourceItemBefore.Length
    sha256 = (Get-FileHash -LiteralPath $isolatedChartValidationMcPath -Algorithm SHA256).Hash
    lastWriteTimeUtc = $chartValidationSourceItemBefore.LastWriteTimeUtc.ToString("O")
}
$chartValidationCapture = Invoke-GuiCaptureGate `
    -Name "avalonia-chart-validation-gui-capture" `
    -Arguments @{
        ChartPath = $isolatedChartValidationMcPath
        EvidencePath = $chartValidationGuiPath
        InteractionEvidencePath = $chartValidationInteractionGuiPath
        ScreenshotPath = $chartValidationScreenshotPath
        WorkspaceRoot = $chartValidationFixtureRoot
        LocalDataRoot = $chartValidationLocalDataRoot
        EditingRoot = (Join-Path $guiRoot "sessions\chart-validation\editing")
        FocusChartValidation = $true
        ExerciseChartValidation = $true
        ChartValidationManualDialogScreenshotPath =
            $chartValidationManualDialogScreenshotPath
        ChartValidationSaveBlockedDialogScreenshotPath =
            $chartValidationSaveBlockedDialogScreenshotPath
        AllowExistingLocalDataRoot = $true
        InteractionDelayMilliseconds = 18000
        TimeoutSeconds = 90
    }
$chartValidationGui = Get-RequiredJson $chartValidationGuiPath
$chartValidationInteractionGui = Get-RequiredJson $chartValidationInteractionGuiPath
$chartValidationSourceItemAfter = Get-Item -LiteralPath $isolatedChartValidationMcPath
$chartValidationSourceAfter = [pscustomobject][ordered]@{
    path = $chartValidationSourceItemAfter.FullName
    length = [long]$chartValidationSourceItemAfter.Length
    sha256 = (Get-FileHash -LiteralPath $isolatedChartValidationMcPath -Algorithm SHA256).Hash
    lastWriteTimeUtc = $chartValidationSourceItemAfter.LastWriteTimeUtc.ToString("O")
}
if ($chartValidationSourceBefore.length -ne $chartValidationSourceAfter.length -or
    $chartValidationSourceBefore.sha256 -cne $chartValidationSourceAfter.sha256 -or
    $chartValidationSourceBefore.lastWriteTimeUtc -cne
        $chartValidationSourceAfter.lastWriteTimeUtc -or
    $chartValidationSourceAfter.sha256 -cne $fixtureSha256 -or
    (Get-FileHash -LiteralPath $fixturePath -Algorithm SHA256).Hash -cne $fixtureSha256) {
    throw "Chart-validation manual check and blocked Save changed an isolated or official real Resound source."
}

$chartValidationPrimary = $chartValidationGui.validation
$chartValidationInteraction = $chartValidationInteractionGui.validation
$chartValidationFirstIssue = $chartValidationInteraction.firstIssue
$chartValidationBeat = $chartValidationFirstIssue.beat
$chartValidationExpectedNoteIds = @($chartValidationFirstIssue.noteIds |
    ForEach-Object { [string]$_ } | Sort-Object)
$chartValidationSelectedNoteIds = @($chartValidationInteractionGui.timeline.selectedNotes |
    ForEach-Object { [string]$_.noteId } | Sort-Object)
$chartValidationNavigationNoteIds = @($chartValidationInteraction.navigation.noteIds |
    ForEach-Object { [string]$_ } | Sort-Object)
$chartValidationPrimaryHiddenGroups = @($chartValidationGui.timeline.hiddenGroups |
    ForEach-Object { [int]$_ })
$chartValidationInteractionHiddenGroups = @(
    $chartValidationInteractionGui.timeline.hiddenGroups | ForEach-Object { [int]$_ })
$chartValidationExpectedManualMessage =
    "发现 2 项错误：重叠键 1，LN 交叉 1。`n`n" +
    "已定位最靠下的一项：$($chartValidationFirstIssue.message)" +
    "（$($chartValidationBeat.bar):$($chartValidationBeat.numerator)/$($chartValidationBeat.denominator)）。"
$chartValidationExpectedSaveMessage =
    "保存已暂停：发现 2 项谱面错误。`n`n" +
    "重叠键：1`nLN 交叉：1`n`n" +
    "已定位并选中最靠下的一项，请修复后再次保存。"
$chartValidationExpectedStatus =
    "谱面错误：$($chartValidationFirstIssue.message) · " +
    "$($chartValidationBeat.bar):$($chartValidationBeat.numerator)/$($chartValidationBeat.denominator)"
$chartValidationExpectedBeatDisplay = ([double]$chartValidationBeat.value).ToString(
    "F3",
    [Globalization.CultureInfo]::InvariantCulture)
$chartValidationAction = $chartValidationCapture.capture.chartValidationAction
$chartValidationManualScale = $chartValidationInteraction.manualDialogScale
$chartValidationSaveScale = $chartValidationInteraction.saveDialogScale
$chartValidationPrimaryDisplayScale = $chartValidationGui.window.displayScale
$chartValidationInteractionDisplayScale = $chartValidationInteractionGui.window.displayScale
$chartValidationCapturedSourceBeforeLastWriteTimeUtc =
    ([datetime]$chartValidationCapture.capture.chartValidationSourceBefore.lastWriteTimeUtc).
        ToUniversalTime().ToString("O")
$chartValidationCapturedSourceAfterLastWriteTimeUtc =
    ([datetime]$chartValidationCapture.capture.chartValidationSourceAfter.lastWriteTimeUtc).
        ToUniversalTime().ToString("O")
$chartValidationBaselineGuardSourcePath =
    Join-Path $projectRoot "LumaChart.Avalonia\MainWindow.cs"
$chartValidationBaselineGuardSource =
    Get-Content -LiteralPath $chartValidationBaselineGuardSourcePath -Raw
if (-not $chartValidationBaselineGuardSource.Contains(
        "var baseline = DesktopChartValidationPresenter.Create(document, []);") -or
    -not $chartValidationBaselineGuardSource.Contains("if (!baseline.CanSave)") -or
    -not $chartValidationBaselineGuardSource.Contains(
        "document.Notes.Any(note => note.Group is 7 or 8)") -or
    -not $chartValidationBaselineGuardSource.Contains(
        "injected.TotalIssueCount != 2") -or
    -not $chartValidationBaselineGuardSource.Contains(
        "injected.OverlappingNoteCount != 1") -or
    -not $chartValidationBaselineGuardSource.Contains(
        "injected.CrossingLongNoteCount != 1")) {
    throw "The guarded chart-validation evidence workload no longer fails closed on a nonzero baseline, occupied groups 7/8, or a non-exact two-issue injection."
}
$chartValidationBaselineIssueCount = 0
if (-not [bool]$chartValidationCapture.capture.focusChartValidation -or
    -not [bool]$chartValidationCapture.capture.chartValidationExercised -or
    -not [bool]$chartValidationCapture.capture.interactionCapturedAfterActions -or
    [string]$chartValidationGui.schema -cne "lumachart.windows.avalonia.gui-evidence.v12" -or
    [string]$chartValidationInteractionGui.schema -cne
        "lumachart.windows.avalonia.gui-evidence.v12" -or
    $chartValidationBaselineIssueCount -ne 0 -or
    [int]$chartValidationPrimary.totalIssueCount -ne 2 -or
    [int]$chartValidationPrimary.overlappingNoteCount -ne 1 -or
    [int]$chartValidationPrimary.crossingLongNoteCount -ne 1 -or
    [bool]$chartValidationPrimary.canSave -or
    [int]$chartValidationInteraction.totalIssueCount -ne 2 -or
    [int]$chartValidationInteraction.overlappingNoteCount -ne 1 -or
    [int]$chartValidationInteraction.crossingLongNoteCount -ne 1 -or
    [bool]$chartValidationInteraction.canSave -or
    @($chartValidationInteraction.issues).Count -ne 2 -or
    [string]$chartValidationFirstIssue.kind -cne "OverlappingNotes" -or
    [string]$chartValidationInteraction.issues[1].kind -cne "CrossingLongNotes" -or
    $chartValidationExpectedNoteIds.Count -ne 2 -or
    -not [bool]$chartValidationInteraction.timeline.matchesPresentation -or
    [int]$chartValidationInteraction.timeline.totalIssueCount -ne 2 -or
    [int]$chartValidationInteraction.timeline.overlappingNoteCount -ne 1 -or
    [int]$chartValidationInteraction.timeline.crossingLongNoteCount -ne 1 -or
    -not [bool]$chartValidationInteraction.lastNavigationMatchesPresentation -or
    @($chartValidationPrimary.navigation.hiddenGroupsToReveal).Count -ne 1 -or
    [int]$chartValidationPrimary.navigation.hiddenGroupsToReveal[0] -ne 7 -or
    @($chartValidationInteraction.navigation.hiddenGroupsToReveal).Count -ne 0 -or
    -not ($chartValidationPrimaryHiddenGroups -contains 7) -or
    -not ($chartValidationPrimaryHiddenGroups -contains 8) -or
    [int]$chartValidationGui.timeline.selectedNoteCount -ne 0 -or
    -not [bool]$chartValidationGui.timeline.sessionIsDirty -or
    -not [bool]$chartValidationInteractionGui.timeline.sessionIsDirty -or
    [long]$chartValidationGui.timeline.sessionChangeSerial -ne
        [long]$chartValidationInteractionGui.timeline.sessionChangeSerial -or
    [string]$chartValidationGui.chart.structure.sha256 -cne
        [string]$chartValidationInteractionGui.chart.structure.sha256 -or
    ($chartValidationInteractionHiddenGroups -contains 7) -or
    -not ($chartValidationInteractionHiddenGroups -contains 8) -or
    [int]$chartValidationInteractionGui.timeline.selectedNoteCount -ne 2 -or
    ($chartValidationExpectedNoteIds -join "|") -cne
        ($chartValidationSelectedNoteIds -join "|") -or
    ($chartValidationExpectedNoteIds -join "|") -cne
        ($chartValidationNavigationNoteIds -join "|") -or
    -not (Test-BeatEvidenceEqual `
        -Left $chartValidationInteraction.navigation.exactBeat `
        -Right $chartValidationBeat) -or
    [Math]::Abs([double]$chartValidationInteractionGui.timeline.currentBeat -
        [double]$chartValidationBeat.value) -gt .000001 -or
    -not [bool]$chartValidationInteraction.manualCheckShown -or
    -not [bool]$chartValidationInteraction.saveBlockedShown -or
    [string]$chartValidationInteraction.lastDialogMode -cne "save-warning" -or
    ([string]$chartValidationInteraction.manualCheckMessage -replace "`r", "") -cne
        $chartValidationExpectedManualMessage -or
    ([string]$chartValidationInteraction.saveBlockingMessage -replace "`r", "") -cne
        $chartValidationExpectedSaveMessage -or
    ([string]$chartValidationAction.manualMessage.name -replace "`r", "") -cne
        $chartValidationExpectedManualMessage -or
    ([string]$chartValidationAction.saveBlockedMessage.name -replace "`r", "") -cne
        $chartValidationExpectedSaveMessage -or
    [string]$chartValidationAction.checkButton.automationId -cne "Editor.ChartCheck" -or
    [string]$chartValidationAction.saveButton.automationId -cne "Editor.Save" -or
    [string]$chartValidationAction.noteInspectorTab.automationId -cne "Inspector.NoteTab" -or
    -not [bool]$chartValidationAction.noteInspectorSelected -or
    [string]$chartValidationAction.manualStatus.automationId -cne "Editor.Status" -or
    [string]$chartValidationAction.manualStatus.name -cne $chartValidationExpectedStatus -or
    [string]$chartValidationAction.status.automationId -cne "Editor.Status" -or
    [string]$chartValidationAction.status.name -cne $chartValidationExpectedStatus -or
    [string]$chartValidationInteraction.navigation.hoverStatusText -cne
        $chartValidationExpectedStatus -or
    [string]$chartValidationAction.manualDialog.automationId -cne "ChartValidation.Dialog" -or
    [string]$chartValidationAction.saveBlockedDialog.automationId -cne "ChartValidation.Dialog" -or
    @(@($chartValidationPrimaryDisplayScale, $chartValidationInteractionDisplayScale) |
        Where-Object {
            $null -eq $_ -or
            -not [bool]$_.usesLayoutTransform -or
            [Math]::Abs([double]$_.requestedUiScale - 1.35) -gt .000001 -or
            [Math]::Abs([double]$_.requestedFontScale - 1.25) -gt .000001 -or
            [Math]::Abs([double]$_.actualRootScaleX - 1.35) -gt .000001 -or
            [Math]::Abs([double]$_.actualRootScaleY - 1.35) -gt .000001 -or
            [Math]::Abs([double]$_.actualFontScale - 1.25) -gt .000001 -or
            -not (Test-PathEvidenceEqual `
                -Left $_.settingsPath `
                -Right $chartValidationScaleSettingsPath)
        }).Count -ne 0 -or
    $null -eq $chartValidationManualScale -or
    -not [bool]$chartValidationManualScale.usesLayoutTransform -or
    [Math]::Abs([double]$chartValidationManualScale.requestedUiScale - 1.35) -gt .000001 -or
    [Math]::Abs([double]$chartValidationManualScale.requestedFontScale - 1.25) -gt .000001 -or
    [Math]::Abs([double]$chartValidationManualScale.actualRootScaleX - 1.35) -gt .000001 -or
    [Math]::Abs([double]$chartValidationManualScale.actualRootScaleY - 1.35) -gt .000001 -or
    [Math]::Abs([double]$chartValidationManualScale.messageFontSize - 16.25) -gt .000001 -or
    $null -eq $chartValidationSaveScale -or
    -not [bool]$chartValidationSaveScale.usesLayoutTransform -or
    [Math]::Abs([double]$chartValidationSaveScale.requestedUiScale - 1.35) -gt .000001 -or
    [Math]::Abs([double]$chartValidationSaveScale.requestedFontScale - 1.25) -gt .000001 -or
    [Math]::Abs([double]$chartValidationSaveScale.actualRootScaleX - 1.35) -gt .000001 -or
    [Math]::Abs([double]$chartValidationSaveScale.actualRootScaleY - 1.35) -gt .000001 -or
    [Math]::Abs([double]$chartValidationSaveScale.messageFontSize - 16.25) -gt .000001 -or
    [string]$chartValidationCapture.capture.chartValidationSourceBefore.sha256 -cne
        $chartValidationSourceBefore.sha256 -or
    [long]$chartValidationCapture.capture.chartValidationSourceBefore.length -ne
        $chartValidationSourceBefore.length -or
    $chartValidationCapturedSourceBeforeLastWriteTimeUtc -cne
        $chartValidationSourceBefore.lastWriteTimeUtc -or
    $chartValidationCapturedSourceBeforeLastWriteTimeUtc -cne
        $chartValidationCapturedSourceAfterLastWriteTimeUtc -or
    [string]$chartValidationInteractionGui.chart.sourceSha256 -cne
        $chartValidationSourceBefore.sha256) {
    throw "Chart-validation GUI did not prove baseline-zero guarded injection, exact 2-issue WPF copy/navigation, Note UIA/status selection, independent scaled dialogs, timeline cross-check, and fail-closed source preservation."
}

$libraryBatchOpenGuiPath =
    Join-Path $guiRoot "avalonia-library-open-document-block-runtime-v1.json"
$libraryBatchOpenInteractionGuiPath =
    Join-Path $guiRoot "avalonia-library-open-document-block-interaction-runtime-v1.json"
$libraryBatchOpenScreenshotPath =
    Join-Path $guiRoot "avalonia-library-open-document-block-final-v1.png"
$libraryBatchOpenMenuScreenshotPath =
    Join-Path $guiRoot "avalonia-library-open-document-block-menu-v1.png"
$libraryBatchOpenDialogScreenshotPath =
    Join-Path $guiRoot "avalonia-library-open-document-block-dialog-v1.png"
$libraryBatchOpenLocalDataRoot =
    Join-Path $guiRoot "sessions\library-open-document-block\local-data"
$libraryBatchOpenSettingsPath = Initialize-DisplayScaleRoot $libraryBatchOpenLocalDataRoot

$libraryBatchDeleteGuiPath =
    Join-Path $guiRoot "avalonia-library-batch-delete-runtime-v1.json"
$libraryBatchDeleteInteractionGuiPath =
    Join-Path $guiRoot "avalonia-library-batch-delete-interaction-runtime-v1.json"
$libraryBatchDeleteScreenshotPath =
    Join-Path $guiRoot "avalonia-library-batch-delete-final-v1.png"
$libraryBatchDeleteMenuScreenshotPath =
    Join-Path $guiRoot "avalonia-library-batch-delete-menu-v1.png"
$libraryBatchDeleteDialogScreenshotPath =
    Join-Path $guiRoot "avalonia-library-batch-delete-dialog-v1.png"
$libraryBatchDeleteLocalDataRoot =
    Join-Path $guiRoot "sessions\library-batch-delete\local-data"
$libraryBatchDeleteSettingsPath = Initialize-DisplayScaleRoot $libraryBatchDeleteLocalDataRoot

$libraryBatchRestoredGuiPath =
    Join-Path $guiRoot "avalonia-library-batch-restored-runtime-v1.json"
$libraryBatchRestoredScreenshotPath =
    Join-Path $guiRoot "avalonia-library-batch-restored-final-v1.png"
$libraryBatchRestoredLocalDataRoot =
    Join-Path $guiRoot "sessions\library-batch-restored\local-data"
$libraryBatchRestoredSettingsPath = Initialize-DisplayScaleRoot $libraryBatchRestoredLocalDataRoot

$libraryBatchExpectedOpenBlockMessage =
    "选中文件夹中有正在编辑的谱面：Resound。`n`n请先关闭对应谱面标签，再执行删除。"
$libraryBatchRecycleBefore = $null
$libraryBatchRecycleAfterOpenBlock = $null
$libraryBatchRecycleAfterBatch = $null
$libraryBatchRecycleAfterRestore = $null
$libraryBatchRestoreActions = $null
$libraryBatchRestoreWaits = $null
$libraryBatchTreesAfterRestore = $null
$libraryBatchOpenSourceAfterRestore = $null
$libraryBatchOpenCapture = $null
$libraryBatchDeleteCapture = $null
$libraryBatchOpenGui = $null
$libraryBatchOpenInteractionGui = $null
$libraryBatchDeleteGui = $null
$libraryBatchDeleteInteractionGui = $null
try {
    $libraryBatchRecycleBefore = [pscustomobject][ordered]@{
        batchA = (Wait-ExactRecycleBinItemCount `
            -TargetPath $libraryBatchAPath -ExpectedCount 0).observation
        batchB = (Wait-ExactRecycleBinItemCount `
            -TargetPath $libraryBatchBPath -ExpectedCount 0).observation
        open = (Wait-ExactRecycleBinItemCount `
            -TargetPath $libraryBatchOpenPath -ExpectedCount 0).observation
    }
    if (@(@($libraryBatchRecycleBefore.batchA, $libraryBatchRecycleBefore.batchB,
            $libraryBatchRecycleBefore.open) | Where-Object {
                [int]$_.matchCount -ne 0
            }).Count -ne 0) {
        throw "A random isolated library target already had an exact Recycle Bin match before action."
    }

    $libraryBatchOpenCapture = Invoke-GuiCaptureGate `
        -Name "avalonia-library-open-document-block-gui-capture" -Arguments @{
            ChartPath = $libraryBatchOpenChartPath
            EvidencePath = $libraryBatchOpenGuiPath
            InteractionEvidencePath = $libraryBatchOpenInteractionGuiPath
            ScreenshotPath = $libraryBatchOpenScreenshotPath
            WorkspaceRoot = $libraryBatchWorkspaceRoot
            LocalDataRoot = $libraryBatchOpenLocalDataRoot
            EditingRoot = (Join-Path $guiRoot "sessions\library-open-document-block\editing")
            AllowExistingLocalDataRoot = $true
            FocusLibraryDeletion = $true
            ExerciseLibraryOpenDocumentBlock = $true
            LibraryDeleteTargetName = $libraryBatchOpenName
            LibraryDeleteTargetPath = $libraryBatchOpenPath
            LibraryContextMenuScreenshotPath = $libraryBatchOpenMenuScreenshotPath
            LibraryDeleteDialogScreenshotPath = $libraryBatchOpenDialogScreenshotPath
            InteractionDelayMilliseconds = 18000
            TimeoutSeconds = 120
        }
    $libraryBatchOpenGui = Get-RequiredJson $libraryBatchOpenGuiPath
    $libraryBatchOpenInteractionGui = Get-RequiredJson $libraryBatchOpenInteractionGuiPath
    $libraryBatchOpenAction = $libraryBatchOpenCapture.capture.libraryDeletionAction
    $libraryBatchOpenPlan = $libraryBatchOpenInteractionGui.library.lastDeletion
    $libraryBatchOpenPeerName = [string]$libraryBatchOpenAction.targetCard.name
    $libraryBatchOpenSourceAfterBlockItem = Get-Item -LiteralPath $libraryBatchOpenChartPath
    $libraryBatchOpenSourceAfterBlock = [pscustomobject][ordered]@{
        path = $libraryBatchOpenSourceAfterBlockItem.FullName
        length = [long]$libraryBatchOpenSourceAfterBlockItem.Length
        sha256 = (Get-FileHash -LiteralPath $libraryBatchOpenChartPath -Algorithm SHA256).Hash
        lastWriteTimeUtc = $libraryBatchOpenSourceAfterBlockItem.LastWriteTimeUtc.ToString("O")
    }
    $libraryBatchRecycleAfterOpenBlock = [pscustomobject][ordered]@{
        batchA = (Wait-ExactRecycleBinItemCount `
            -TargetPath $libraryBatchAPath -ExpectedCount 0).observation
        batchB = (Wait-ExactRecycleBinItemCount `
            -TargetPath $libraryBatchBPath -ExpectedCount 0).observation
        open = (Wait-ExactRecycleBinItemCount `
            -TargetPath $libraryBatchOpenPath -ExpectedCount 0).observation
    }
    if ([string]$libraryBatchOpenGui.schema -cne
            "lumachart.windows.avalonia.gui-evidence.v12" -or
        [string]$libraryBatchOpenInteractionGui.schema -cne
            "lumachart.windows.avalonia.gui-evidence.v12" -or
        -not [bool]$libraryBatchOpenCapture.capture.focusLibraryDeletion -or
        -not [bool]$libraryBatchOpenCapture.capture.libraryDeletionExercised -or
        -not [bool]$libraryBatchOpenCapture.capture.libraryOpenDocumentBlockExercised -or
        [bool]$libraryBatchOpenCapture.capture.libraryBatchDeleteConfirmExercised -or
        [string]$libraryBatchOpenCapture.capture.libraryDeletionRequestedOutcome -cne "Blocked" -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchOpenCapture.capture.libraryDeleteTargetPath `
            -Right $libraryBatchOpenPath) -or
        $null -ne $libraryBatchOpenCapture.capture.libraryDeleteSecondTargetPath -or
        -not [bool]$libraryBatchOpenCapture.capture.interactionCapturedAfterActions -or
        [string]$libraryBatchOpenAction.mode -cne "open-document-block" -or
        [string]$libraryBatchOpenAction.requestedOutcome -cne "Blocked" -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchOpenAction.targetPath `
            -Right $libraryBatchOpenPath) -or
        [bool]$libraryBatchOpenAction.selectionPatternOnly -or
        -not [bool]$libraryBatchOpenAction.selectionItemPatternReadOnly -or
        -not [bool]$libraryBatchOpenAction.parentSelectionPatternBridgeMismatchObserved -or
        [bool]$libraryBatchOpenAction.selectionAutomationFallbackUsed -or
        @($libraryBatchOpenAction.selectionSteps).Count -ne 0 -or
        -not (Test-LibrarySelectionObservation `
            -Observation $libraryBatchOpenAction.selectionBeforeRightClick `
            -ExpectedNames @()) -or
        -not (Test-LibrarySelectionObservation `
            -Observation $libraryBatchOpenAction.selectionAfterRightClick `
            -ExpectedNames @($libraryBatchOpenPeerName)) -or
        [string]$libraryBatchOpenAction.targetCard.automationId -cne "Library.FolderItem" -or
        [string]$libraryBatchOpenAction.targetCard.controlType -cne "ControlType.ListItem" -or
        -not [bool]$libraryBatchOpenAction.targetCard.selectionItemPattern -or
        [string]$libraryBatchOpenAction.contextMenuItem.automationId -cne
            "Library.DeleteContextMenuItem" -or
        [string]$libraryBatchOpenAction.contextMenuItem.name -cne "删除此歌曲文件夹" -or
        [string]$libraryBatchOpenAction.dialog.automationId -cne "Library.DeleteDialog" -or
        [string]$libraryBatchOpenAction.dialog.name -cne "无法删除" -or
        [string]$libraryBatchOpenAction.dialogMessage.automationId -cne
            "Library.DeleteDialog.Message" -or
        (([string]$libraryBatchOpenAction.dialogMessage.name) -replace "`r", "") -cne
            $libraryBatchExpectedOpenBlockMessage -or
        [string]$libraryBatchOpenAction.dialogIcon.automationId -cne "Library.DeleteDialog.Icon" -or
        [string]$libraryBatchOpenAction.dialogIcon.name -cne "!" -or
        [string]$libraryBatchOpenAction.dialogIcon.helpText -cne "警告" -or
        -not [bool]$libraryBatchOpenAction.warningTone -or
        [bool]$libraryBatchOpenAction.questionTone -or
        -not [bool]$libraryBatchOpenAction.cancelAbsent -or
        -not [bool]$libraryBatchOpenAction.recycleAbsent -or
        [bool]$libraryBatchOpenAction.confirmAbsent -or
        $null -ne $libraryBatchOpenAction.dialogCancel -or
        $null -ne $libraryBatchOpenAction.dialogRecycle -or
        [string]$libraryBatchOpenAction.dialogConfirm.automationId -cne
            "Library.DeleteDialog.Confirm" -or
        [string]$libraryBatchOpenAction.dialogConfirm.name -cne "确定" -or
        [string]$libraryBatchOpenAction.dialogButton.automationId -cne
            "Library.DeleteDialog.Confirm" -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchOpenAction.contextMenuScreenshotPath `
            -Right $libraryBatchOpenMenuScreenshotPath) -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchOpenAction.dialogScreenshotPath `
            -Right $libraryBatchOpenDialogScreenshotPath) -or
        [string]$libraryBatchOpenAction.clipboardInput.chord -cne "Ctrl+C" -or
        [string]$libraryBatchOpenAction.clipboardInput.input -cne "keybd_event" -or
        [bool]$libraryBatchOpenAction.clipboardInput.automationKeyboardFallbackUsed -or
        -not [bool]$libraryBatchOpenAction.clipboardInput.controlReleasedInFinally -or
        -not [bool]$libraryBatchOpenAction.clipboardInput.cReleasedInFinally -or
        -not [bool]$libraryBatchOpenAction.clipboardExactMessage -or
        (([string]$libraryBatchOpenAction.clipboardText) -replace "`r", "") -cne
            $libraryBatchExpectedOpenBlockMessage -or
        -not [bool]$libraryBatchOpenAction.targetExistedBefore -or
        -not [bool]$libraryBatchOpenAction.targetExistsAfter -or
        -not (Test-IsolatedWindowDisplayScaleEvidence `
            -Runtime $libraryBatchOpenGui -SettingsPath $libraryBatchOpenSettingsPath) -or
        -not (Test-IsolatedWindowDisplayScaleEvidence `
            -Runtime $libraryBatchOpenInteractionGui -SettingsPath $libraryBatchOpenSettingsPath) -or
        [int]$libraryBatchOpenGui.library.indexedFolderCount -ne 3 -or
        [int]$libraryBatchOpenGui.library.visibleFolderCount -ne 3 -or
        [string]$libraryBatchOpenGui.library.selectionMode -cne "Multiple" -or
        [int]$libraryBatchOpenInteractionGui.library.indexedFolderCount -ne 3 -or
        [int]$libraryBatchOpenInteractionGui.library.visibleFolderCount -ne 3 -or
        [int]$libraryBatchOpenInteractionGui.library.selectedFolderCount -ne 1 -or
        [bool]$libraryBatchOpenPlan.canExecute -or
        [string]$libraryBatchOpenPlan.blockReason -cne "OpenDocument" -or
        (([string]$libraryBatchOpenPlan.blockMessage) -replace "`r", "") -cne
            $libraryBatchExpectedOpenBlockMessage -or
        [int]$libraryBatchOpenPlan.folderCount -ne 1 -or
        [int]$libraryBatchOpenPlan.chartCount -ne 0 -or
        @($libraryBatchOpenPlan.targetFullPaths).Count -ne 1 -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchOpenPlan.targetFullPaths[0] `
            -Right $libraryBatchOpenPath) -or
        @($libraryBatchOpenPlan.blockingDocumentTitles).Count -ne 1 -or
        [string]$libraryBatchOpenPlan.blockingDocumentTitles[0] -cne "Resound" -or
        @($libraryBatchOpenPlan.previewItems).Count -ne 0 -or
        $null -ne $libraryBatchOpenPlan.confirmationMessage -or
        [bool]$libraryBatchOpenPlan.confirmed -or [bool]$libraryBatchOpenPlan.canceled -or
        @($libraryBatchOpenPlan.recycleResults).Count -ne 0 -or
        @($libraryBatchOpenPlan.failureMessages).Count -ne 0 -or
        -not (Test-LibraryDialogScaleEvidence $libraryBatchOpenPlan.dialogScale) -or
        $libraryBatchOpenSourceBefore.length -ne $libraryBatchOpenSourceAfterBlock.length -or
        $libraryBatchOpenSourceBefore.sha256 -cne $libraryBatchOpenSourceAfterBlock.sha256 -or
        $libraryBatchOpenSourceBefore.lastWriteTimeUtc -cne
            $libraryBatchOpenSourceAfterBlock.lastWriteTimeUtc -or
        [string]$libraryBatchOpenInteractionGui.chart.sourceSha256 -cne
            $libraryBatchOpenSourceBefore.sha256 -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchOpenInteractionGui.chart.sourcePath `
            -Right $libraryBatchOpenChartPath) -or
        @(@($libraryBatchRecycleAfterOpenBlock.batchA,
            $libraryBatchRecycleAfterOpenBlock.batchB,
            $libraryBatchRecycleAfterOpenBlock.open) | Where-Object {
                [int]$_.matchCount -ne 0
            }).Count -ne 0) {
        throw "Open-document library deletion did not prove exact Confirm-only warning, Ctrl+C copy, OpenDocument plan, source preservation, and zero Recycle Bin changes."
    }

    $libraryBatchDeleteCapture = Invoke-GuiCaptureGate `
        -Name "avalonia-library-batch-delete-gui-capture" -Arguments @{
            ChartPath = $libraryBatchOpenChartPath
            EvidencePath = $libraryBatchDeleteGuiPath
            InteractionEvidencePath = $libraryBatchDeleteInteractionGuiPath
            ScreenshotPath = $libraryBatchDeleteScreenshotPath
            WorkspaceRoot = $libraryBatchWorkspaceRoot
            LocalDataRoot = $libraryBatchDeleteLocalDataRoot
            EditingRoot = (Join-Path $guiRoot "sessions\library-batch-delete\editing")
            AllowExistingLocalDataRoot = $true
            FocusLibraryDeletion = $true
            ExerciseLibraryBatchDeleteConfirm = $true
            LibraryDeleteTargetName = $libraryBatchAName
            LibraryDeleteTargetPath = $libraryBatchAPath
            LibraryDeleteSecondTargetName = $libraryBatchBName
            LibraryDeleteSecondTargetPath = $libraryBatchBPath
            LibraryContextMenuScreenshotPath = $libraryBatchDeleteMenuScreenshotPath
            LibraryDeleteDialogScreenshotPath = $libraryBatchDeleteDialogScreenshotPath
            InteractionDelayMilliseconds = 26000
            TimeoutSeconds = 120
        }
    $libraryBatchDeleteGui = Get-RequiredJson $libraryBatchDeleteGuiPath
    $libraryBatchDeleteInteractionGui = Get-RequiredJson $libraryBatchDeleteInteractionGuiPath
    $libraryBatchDeleteAction = $libraryBatchDeleteCapture.capture.libraryDeletionAction
    $libraryBatchDeletePlan = $libraryBatchDeleteInteractionGui.library.lastDeletion
    $libraryBatchFirstPeerName = [string]$libraryBatchDeleteAction.targetCard.name
    $libraryBatchSecondPeerName = [string]$libraryBatchDeleteAction.secondTargetCard.name
    $libraryBatchStepActions = @(
        "plain-left-click-first",
        "shift-left-click-second",
        "control-left-click-second-remove",
        "control-left-click-second-restore")
    $libraryBatchStepCounts = @(1, 2, 1, 2)
    $libraryBatchSelectionSteps = @($libraryBatchDeleteAction.selectionSteps)
    if ($libraryBatchSelectionSteps.Count -ne 4) {
        throw "The library batch-delete action did not record all four physical selection steps."
    }
    for ($selectionStepIndex = 0; $selectionStepIndex -lt 4; $selectionStepIndex++) {
        $selectionStep = $libraryBatchSelectionSteps[$selectionStepIndex]
        $expectedSelectionNamesForStep = if ($selectionStepIndex -in 0, 2) {
            @($libraryBatchFirstPeerName)
        } else {
            @($libraryBatchFirstPeerName, $libraryBatchSecondPeerName)
        }
        if ([int]$selectionStep.sequence -ne ($selectionStepIndex + 1) -or
            [string]$selectionStep.action -cne $libraryBatchStepActions[$selectionStepIndex] -or
            -not (Test-LibrarySelectionObservation `
                -Observation $selectionStep.selection `
                -ExpectedNames $expectedSelectionNamesForStep) -or
            [int]$selectionStep.selection.selectedCount -ne
                $libraryBatchStepCounts[$selectionStepIndex] -or
            [string]$selectionStep.target.automationId -cne "Library.FolderItem" -or
            [string]$selectionStep.target.controlType -cne "ControlType.ListItem" -or
            -not [bool]$selectionStep.target.selectionItemPattern) {
            throw "Library batch-delete selection step $($selectionStepIndex + 1) failed exact SelectionPattern evidence."
        }
        if ($selectionStepIndex -eq 0) {
            if ([string]$selectionStep.input -cne "physical-left-click" -or
                [bool]$selectionStep.automationSelectionFallbackUsed) {
                throw "The first library batch selection step did not use an unfallbacked physical click."
            }
        } else {
            $expectedModifier = if ($selectionStepIndex -eq 1) { "Shift" } else { "Control" }
            if ([string]$selectionStep.input.modifier -cne $expectedModifier -or
                [string]$selectionStep.input.input -cne "keybd_event+physical-left-click" -or
                -not [bool]$selectionStep.input.keyReleasedInFinally -or
                [bool]$selectionStep.input.automationSelectionFallbackUsed) {
                throw "Library batch-delete selection step $($selectionStepIndex + 1) used an automation fallback or wrong modifier."
            }
        }
    }
    $libraryBatchExpectedTargetPaths = @(
        [IO.Path]::GetFullPath($libraryBatchAPath),
        [IO.Path]::GetFullPath($libraryBatchBPath)) | Sort-Object
    $libraryBatchActualTargetPaths = @($libraryBatchDeletePlan.targetFullPaths |
        ForEach-Object { [IO.Path]::GetFullPath([string]$_) })
    $libraryBatchExpectedPreviewItems = @($libraryBatchActualTargetPaths | ForEach-Object {
        "• Resound  ($([IO.Path]::GetFileName($_)))"
    })
    $libraryBatchExpectedConfirmationMessage =
        "确定将 2 个歌曲文件夹移入回收站吗？`n" +
        "其中包含 2 张谱面，并会一起移除文件夹内的音频和图片。`n`n" +
        ($libraryBatchExpectedPreviewItems -join "`n")
    if ([string]$libraryBatchDeleteGui.schema -cne
            "lumachart.windows.avalonia.gui-evidence.v12" -or
        [string]$libraryBatchDeleteInteractionGui.schema -cne
            "lumachart.windows.avalonia.gui-evidence.v12" -or
        -not [bool]$libraryBatchDeleteCapture.capture.focusLibraryDeletion -or
        -not [bool]$libraryBatchDeleteCapture.capture.libraryDeletionExercised -or
        -not [bool]$libraryBatchDeleteCapture.capture.libraryBatchDeleteConfirmExercised -or
        [bool]$libraryBatchDeleteCapture.capture.libraryOpenDocumentBlockExercised -or
        [string]$libraryBatchDeleteCapture.capture.libraryDeletionRequestedOutcome -cne "Recycle" -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchDeleteCapture.capture.libraryDeleteTargetPath `
            -Right $libraryBatchAPath) -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchDeleteCapture.capture.libraryDeleteSecondTargetPath `
            -Right $libraryBatchBPath) -or
        -not [bool]$libraryBatchDeleteCapture.capture.interactionCapturedAfterActions -or
        [int]$libraryBatchDeleteCapture.capture.processId -eq
            [int]$libraryBatchOpenCapture.capture.processId -or
        [string]$libraryBatchDeleteAction.mode -cne "batch-delete-confirm" -or
        [string]$libraryBatchDeleteAction.requestedOutcome -cne "Recycle" -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchDeleteAction.targetPath `
            -Right $libraryBatchAPath) -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchDeleteAction.secondTargetPath `
            -Right $libraryBatchBPath) -or
        [bool]$libraryBatchDeleteAction.selectionPatternOnly -or
        -not [bool]$libraryBatchDeleteAction.selectionItemPatternReadOnly -or
        -not [bool]$libraryBatchDeleteAction.parentSelectionPatternBridgeMismatchObserved -or
        [bool]$libraryBatchDeleteAction.selectionAutomationFallbackUsed -or
        -not [bool]$libraryBatchDeleteAction.rightClickPreservedSelection -or
        -not (Test-LibrarySelectionObservation `
            -Observation $libraryBatchDeleteAction.selectionBeforeRightClick `
            -ExpectedNames @($libraryBatchFirstPeerName, $libraryBatchSecondPeerName)) -or
        -not (Test-LibrarySelectionObservation `
            -Observation $libraryBatchDeleteAction.selectionAfterRightClick `
            -ExpectedNames @($libraryBatchFirstPeerName, $libraryBatchSecondPeerName)) -or
        [string]$libraryBatchDeleteAction.contextMenuItem.automationId -cne
            "Library.DeleteContextMenuItem" -or
        [string]$libraryBatchDeleteAction.contextMenuItem.name -cne
            "删除所选 2 个歌曲文件夹" -or
        [string]$libraryBatchDeleteAction.dialog.automationId -cne "Library.DeleteDialog" -or
        [string]$libraryBatchDeleteAction.dialog.name -cne "删除歌曲" -or
        [string]$libraryBatchDeleteAction.dialogMessage.automationId -cne
            "Library.DeleteDialog.Message" -or
        [string]$libraryBatchDeleteAction.dialogIcon.automationId -cne
            "Library.DeleteDialog.Icon" -or
        [string]$libraryBatchDeleteAction.dialogIcon.name -cne "?" -or
        [string]$libraryBatchDeleteAction.dialogIcon.helpText -cne "问题" -or
        -not [bool]$libraryBatchDeleteAction.questionTone -or
        [bool]$libraryBatchDeleteAction.warningTone -or
        -not [bool]$libraryBatchDeleteAction.neutralCancelRecycleDecision -or
        [bool]$libraryBatchDeleteAction.cancelAbsent -or
        [bool]$libraryBatchDeleteAction.recycleAbsent -or
        -not [bool]$libraryBatchDeleteAction.confirmAbsent -or
        [string]$libraryBatchDeleteAction.dialogCancel.automationId -cne
            "Library.DeleteDialog.Cancel" -or
        [string]$libraryBatchDeleteAction.dialogCancel.name -cne "取消" -or
        [string]$libraryBatchDeleteAction.dialogRecycle.automationId -cne
            "Library.DeleteDialog.Recycle" -or
        [string]$libraryBatchDeleteAction.dialogRecycle.name -cne "移入回收站" -or
        $null -ne $libraryBatchDeleteAction.dialogConfirm -or
        [string]$libraryBatchDeleteAction.dialogButton.automationId -cne
            "Library.DeleteDialog.Recycle" -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchDeleteAction.contextMenuScreenshotPath `
            -Right $libraryBatchDeleteMenuScreenshotPath) -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchDeleteAction.dialogScreenshotPath `
            -Right $libraryBatchDeleteDialogScreenshotPath) -or
        (([string]$libraryBatchDeleteAction.dialogMessage.name) -replace "`r", "") -cne
            $libraryBatchExpectedConfirmationMessage -or
        -not [bool]$libraryBatchDeleteAction.targetExistedBefore -or
        [bool]$libraryBatchDeleteAction.targetExistsAfter -or
        -not [bool]$libraryBatchDeleteAction.secondTargetExistedBefore -or
        [bool]$libraryBatchDeleteAction.secondTargetExistsAfter -or
        -not (Test-IsolatedWindowDisplayScaleEvidence `
            -Runtime $libraryBatchDeleteGui -SettingsPath $libraryBatchDeleteSettingsPath) -or
        -not (Test-IsolatedWindowDisplayScaleEvidence `
            -Runtime $libraryBatchDeleteInteractionGui -SettingsPath $libraryBatchDeleteSettingsPath) -or
        [int]$libraryBatchDeleteGui.library.indexedFolderCount -ne 3 -or
        [int]$libraryBatchDeleteGui.library.visibleFolderCount -ne 3 -or
        [string]$libraryBatchDeleteGui.library.selectionMode -cne "Multiple" -or
        [int]$libraryBatchDeleteInteractionGui.library.indexedFolderCount -ne 1 -or
        [int]$libraryBatchDeleteInteractionGui.library.visibleFolderCount -ne 1 -or
        [string]$libraryBatchDeleteInteractionGui.chart.sourceSha256 -cne
            $libraryBatchOpenSourceBefore.sha256 -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchDeleteInteractionGui.chart.sourcePath `
            -Right $libraryBatchOpenChartPath) -or
        -not [bool]$libraryBatchDeletePlan.canExecute -or
        [string]$libraryBatchDeletePlan.blockReason -cne "None" -or
        $null -ne $libraryBatchDeletePlan.blockMessage -or
        [int]$libraryBatchDeletePlan.folderCount -ne 2 -or
        [int]$libraryBatchDeletePlan.chartCount -ne 2 -or
        (($libraryBatchActualTargetPaths | Sort-Object) -join "`n") -cne
            ($libraryBatchExpectedTargetPaths -join "`n") -or
        @($libraryBatchDeletePlan.blockingDocumentTitles).Count -ne 0 -or
        ($libraryBatchDeletePlan.previewItems -join "`n") -cne
            ($libraryBatchExpectedPreviewItems -join "`n") -or
        [int]$libraryBatchDeletePlan.omittedPreviewCount -ne 0 -or
        (([string]$libraryBatchDeletePlan.confirmationMessage) -replace "`r", "") -cne
            $libraryBatchExpectedConfirmationMessage -or
        -not [bool]$libraryBatchDeletePlan.confirmed -or
        [bool]$libraryBatchDeletePlan.canceled -or
        @($libraryBatchDeletePlan.recycleResults).Count -ne 2 -or
        @($libraryBatchDeletePlan.recycleResults | Where-Object {
            [int]$_.shellResult -ne 0 -or [bool]$_.anyOperationsAborted -or
            -not [bool]$_.allowUndoRequested
        }).Count -ne 0 -or
        ((@($libraryBatchDeletePlan.recycleResults | ForEach-Object {
            [IO.Path]::GetFullPath([string]$_.fullPath)
        } | Sort-Object)) -join "`n") -cne ($libraryBatchExpectedTargetPaths -join "`n") -or
        @($libraryBatchDeletePlan.failureMessages).Count -ne 0 -or
        -not (Test-LibraryDialogScaleEvidence $libraryBatchDeletePlan.dialogScale) -or
        (Test-Path -LiteralPath $libraryBatchAPath) -or
        (Test-Path -LiteralPath $libraryBatchBPath) -or
        -not (Test-Path -LiteralPath $libraryBatchOpenPath -PathType Container)) {
        throw "Library batch deletion did not prove four-step physical multi-selection, preserved selected-item right-click, exact question plan, and two successful undo-enabled shell operations."
    }

    $libraryBatchRecycleAfterBatch = [pscustomobject][ordered]@{
        batchA = (Wait-ExactRecycleBinItemCount `
            -TargetPath $libraryBatchAPath -ExpectedCount 1).observation
        batchB = (Wait-ExactRecycleBinItemCount `
            -TargetPath $libraryBatchBPath -ExpectedCount 1).observation
        open = (Wait-ExactRecycleBinItemCount `
            -TargetPath $libraryBatchOpenPath -ExpectedCount 0).observation
    }
    if ([int]$libraryBatchRecycleAfterBatch.batchA.matchCount -ne 1 -or
        [int]$libraryBatchRecycleAfterBatch.batchB.matchCount -ne 1 -or
        [int]$libraryBatchRecycleAfterBatch.open.matchCount -ne 0 -or
        [string]$libraryBatchRecycleAfterBatch.batchA.matches[0].originalName -cne
            $libraryBatchAName -or
        [string]$libraryBatchRecycleAfterBatch.batchB.matches[0].originalName -cne
            $libraryBatchBName -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchRecycleAfterBatch.batchA.matches[0].deletedFrom `
            -Right $libraryBatchWorkspaceRoot) -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchRecycleAfterBatch.batchB.matches[0].deletedFrom `
            -Right $libraryBatchWorkspaceRoot) -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchRecycleAfterBatch.batchA.matches[0].originalPath `
            -Right $libraryBatchAPath) -or
        -not (Test-PathEvidenceEqual `
            -Left $libraryBatchRecycleAfterBatch.batchB.matches[0].originalPath `
            -Right $libraryBatchBPath)) {
        throw "The batch action did not create exactly one strict Recycle Bin match per deleted target."
    }
}
finally {
    $cleanupFailures = [Collections.Generic.List[string]]::new()
    $libraryBatchRestoreActions = [ordered]@{}
    $libraryBatchRestoreWaits = [ordered]@{}
    $libraryBatchRecycleAfterRestore = [ordered]@{}
    $cleanupTargets = @(
        [pscustomobject]@{ role = "batchA"; path = $libraryBatchAPath },
        [pscustomobject]@{ role = "batchB"; path = $libraryBatchBPath },
        [pscustomobject]@{ role = "open"; path = $libraryBatchOpenPath })
    foreach ($cleanupTarget in $cleanupTargets) {
        try {
            $libraryBatchRestoreActions[$cleanupTarget.role] =
                Invoke-ExactRecycleBinRestore -TargetPath $cleanupTarget.path
        }
        catch {
            $cleanupFailures.Add("restore $($cleanupTarget.role): $($_.Exception.Message)")
        }
    }
    foreach ($cleanupTarget in $cleanupTargets) {
        try {
            $libraryBatchRecycleAfterRestore[$cleanupTarget.role] =
                (Wait-ExactRecycleBinItemCount `
                    -TargetPath $cleanupTarget.path -ExpectedCount 0).observation
        }
        catch {
            $cleanupFailures.Add("Recycle Bin zero-match $($cleanupTarget.role): $($_.Exception.Message)")
        }
        try {
            $libraryBatchRestoreWaits[$cleanupTarget.role] =
                Wait-DirectoryExists -Path $cleanupTarget.path
        }
        catch {
            $cleanupFailures.Add("directory restore $($cleanupTarget.role): $($_.Exception.Message)")
        }
    }
    if (@($cleanupTargets | Where-Object {
            -not (Test-Path -LiteralPath $_.path -PathType Container)
        }).Count -eq 0) {
        try {
            $libraryBatchTreesAfterRestore = [pscustomobject][ordered]@{
                batchA = Get-DirectoryTreeEvidence -Path $libraryBatchAPath
                batchB = Get-DirectoryTreeEvidence -Path $libraryBatchBPath
                open = Get-DirectoryTreeEvidence -Path $libraryBatchOpenPath
            }
            if (-not (Test-DirectoryTreeEvidenceEqual `
                    -Before $libraryBatchTreesBefore.batchA `
                    -After $libraryBatchTreesAfterRestore.batchA) -or
                -not (Test-DirectoryTreeEvidenceEqual `
                    -Before $libraryBatchTreesBefore.batchB `
                    -After $libraryBatchTreesAfterRestore.batchB) -or
                -not (Test-DirectoryTreeEvidenceEqual `
                    -Before $libraryBatchTreesBefore.open `
                    -After $libraryBatchTreesAfterRestore.open)) {
                $cleanupFailures.Add("restored directory trees differ in entries, bytes, SHA-256, or mtime")
            }
            $libraryBatchOpenSourceAfterRestoreItem =
                Get-Item -LiteralPath $libraryBatchOpenChartPath
            $libraryBatchOpenSourceAfterRestore = [pscustomobject][ordered]@{
                path = $libraryBatchOpenSourceAfterRestoreItem.FullName
                length = [long]$libraryBatchOpenSourceAfterRestoreItem.Length
                sha256 = (Get-FileHash -LiteralPath $libraryBatchOpenChartPath -Algorithm SHA256).Hash
                lastWriteTimeUtc =
                    $libraryBatchOpenSourceAfterRestoreItem.LastWriteTimeUtc.ToString("O")
            }
            if ($libraryBatchOpenSourceBefore.length -ne
                    $libraryBatchOpenSourceAfterRestore.length -or
                $libraryBatchOpenSourceBefore.sha256 -cne
                    $libraryBatchOpenSourceAfterRestore.sha256 -or
                $libraryBatchOpenSourceBefore.lastWriteTimeUtc -cne
                    $libraryBatchOpenSourceAfterRestore.lastWriteTimeUtc) {
                $cleanupFailures.Add("open-document source length/SHA-256/mtime changed")
            }
        }
        catch {
            $cleanupFailures.Add("tree/source verification: $($_.Exception.Message)")
        }
    }
    if ($cleanupFailures.Count -gt 0) {
        throw "Library batch-deletion cleanup failed closed after exact per-item undelete: " +
            ($cleanupFailures -join "; ")
    }
}

if ([int]$libraryBatchRestoreActions.batchA.invokedCount -ne 1 -or
    [int]$libraryBatchRestoreActions.batchB.invokedCount -ne 1 -or
    [int]$libraryBatchRestoreActions.open.invokedCount -ne 0 -or
    @($libraryBatchRestoreActions.batchA.exactItems).Count -ne 1 -or
    @($libraryBatchRestoreActions.batchB.exactItems).Count -ne 1 -or
    [string]$libraryBatchRestoreActions.batchA.exactItems[0].originalName -cne
        $libraryBatchAName -or
    [string]$libraryBatchRestoreActions.batchB.exactItems[0].originalName -cne
        $libraryBatchBName -or
    -not (Test-PathEvidenceEqual `
        -Left $libraryBatchRestoreActions.batchA.exactItems[0].deletedFrom `
        -Right $libraryBatchWorkspaceRoot) -or
    -not (Test-PathEvidenceEqual `
        -Left $libraryBatchRestoreActions.batchB.exactItems[0].deletedFrom `
        -Right $libraryBatchWorkspaceRoot) -or
    -not (Test-PathEvidenceEqual `
        -Left $libraryBatchRestoreActions.batchA.exactItems[0].originalPath `
        -Right $libraryBatchAPath) -or
    -not (Test-PathEvidenceEqual `
        -Left $libraryBatchRestoreActions.batchB.exactItems[0].originalPath `
        -Right $libraryBatchBPath) -or
    [int]$libraryBatchRecycleAfterRestore.batchA.matchCount -ne 0 -or
    [int]$libraryBatchRecycleAfterRestore.batchB.matchCount -ne 0 -or
    [int]$libraryBatchRecycleAfterRestore.open.matchCount -ne 0) {
    throw "Exact finally cleanup did not prove one undelete per recycled target, no open-target undelete, and zero remaining exact matches."
}

$libraryBatchRestoredCapture = Invoke-GuiCaptureGate `
    -Name "avalonia-library-batch-restored-gui-capture" -Arguments @{
        ChartPath = $libraryBatchOpenChartPath
        EvidencePath = $libraryBatchRestoredGuiPath
        ScreenshotPath = $libraryBatchRestoredScreenshotPath
        WorkspaceRoot = $libraryBatchWorkspaceRoot
        LocalDataRoot = $libraryBatchRestoredLocalDataRoot
        EditingRoot = (Join-Path $guiRoot "sessions\library-batch-restored\editing")
        AllowExistingLocalDataRoot = $true
        FocusLibraryDeletion = $true
        TimeoutSeconds = 90
    }
$libraryBatchRestoredGui = Get-RequiredJson $libraryBatchRestoredGuiPath
$libraryBatchRecycleAfterFresh = [pscustomobject][ordered]@{
    batchA = (Wait-ExactRecycleBinItemCount `
        -TargetPath $libraryBatchAPath -ExpectedCount 0).observation
    batchB = (Wait-ExactRecycleBinItemCount `
        -TargetPath $libraryBatchBPath -ExpectedCount 0).observation
    open = (Wait-ExactRecycleBinItemCount `
        -TargetPath $libraryBatchOpenPath -ExpectedCount 0).observation
}
$libraryBatchTreesAfterFresh = [pscustomobject][ordered]@{
    batchA = Get-DirectoryTreeEvidence -Path $libraryBatchAPath
    batchB = Get-DirectoryTreeEvidence -Path $libraryBatchBPath
    open = Get-DirectoryTreeEvidence -Path $libraryBatchOpenPath
}
$libraryBatchOpenSourceAfterFreshItem = Get-Item -LiteralPath $libraryBatchOpenChartPath
$libraryBatchOpenSourceAfterFresh = [pscustomobject][ordered]@{
    path = $libraryBatchOpenSourceAfterFreshItem.FullName
    length = [long]$libraryBatchOpenSourceAfterFreshItem.Length
    sha256 = (Get-FileHash -LiteralPath $libraryBatchOpenChartPath -Algorithm SHA256).Hash
    lastWriteTimeUtc = $libraryBatchOpenSourceAfterFreshItem.LastWriteTimeUtc.ToString("O")
}
if ([string]$libraryBatchRestoredGui.schema -cne
        "lumachart.windows.avalonia.gui-evidence.v12" -or
    -not [bool]$libraryBatchRestoredCapture.capture.focusLibraryDeletion -or
    [bool]$libraryBatchRestoredCapture.capture.libraryDeletionExercised -or
    [bool]$libraryBatchRestoredCapture.capture.libraryBatchDeleteConfirmExercised -or
    [bool]$libraryBatchRestoredCapture.capture.libraryOpenDocumentBlockExercised -or
    $null -ne $libraryBatchRestoredCapture.capture.libraryDeletionRequestedOutcome -or
    $null -ne $libraryBatchRestoredCapture.capture.libraryDeletionAction -or
    [int]$libraryBatchRestoredGui.library.indexedFolderCount -ne 3 -or
    [int]$libraryBatchRestoredGui.library.visibleFolderCount -ne 3 -or
    [int]$libraryBatchRestoredGui.library.selectedFolderCount -ne 0 -or
    [string]$libraryBatchRestoredGui.library.selectionMode -cne "Multiple" -or
    $null -ne $libraryBatchRestoredGui.library.lastDeletion -or
    -not (Test-IsolatedWindowDisplayScaleEvidence `
        -Runtime $libraryBatchRestoredGui -SettingsPath $libraryBatchRestoredSettingsPath) -or
    [int]$libraryBatchOpenCapture.capture.processId -eq
        [int]$libraryBatchRestoredCapture.capture.processId -or
    [int]$libraryBatchDeleteCapture.capture.processId -eq
        [int]$libraryBatchRestoredCapture.capture.processId -or
    @(@($libraryBatchRecycleAfterFresh.batchA, $libraryBatchRecycleAfterFresh.batchB,
        $libraryBatchRecycleAfterFresh.open) | Where-Object {
            [int]$_.matchCount -ne 0
        }).Count -ne 0 -or
    -not (Test-DirectoryTreeEvidenceEqual `
        -Before $libraryBatchTreesBefore.batchA -After $libraryBatchTreesAfterFresh.batchA) -or
    -not (Test-DirectoryTreeEvidenceEqual `
        -Before $libraryBatchTreesBefore.batchB -After $libraryBatchTreesAfterFresh.batchB) -or
    -not (Test-DirectoryTreeEvidenceEqual `
        -Before $libraryBatchTreesBefore.open -After $libraryBatchTreesAfterFresh.open) -or
    $libraryBatchOpenSourceBefore.length -ne $libraryBatchOpenSourceAfterFresh.length -or
    $libraryBatchOpenSourceBefore.sha256 -cne $libraryBatchOpenSourceAfterFresh.sha256 -or
    $libraryBatchOpenSourceBefore.lastWriteTimeUtc -cne
        $libraryBatchOpenSourceAfterFresh.lastWriteTimeUtc -or
    [string]$libraryBatchRestoredGui.chart.sourceSha256 -cne
        $libraryBatchOpenSourceBefore.sha256) {
    throw "Fresh read-only FocusLibraryDeletion process did not re-index all three exact restored trees with zero Recycle Bin matches and unchanged open source."
}

$libraryBatchRecoveryEvidencePath =
    Join-Path $guiRoot "library-batch-deletion-recovery-v1.json"
$libraryBatchRecoveryEvidence = [pscustomobject][ordered]@{
    schema = "lumachart.windows.avalonia.library-batch-deletion-recovery.v1"
    generatedAtUtc = [DateTimeOffset]::UtcNow
    randomToken = $libraryBatchToken
    workspaceRoot = $libraryBatchWorkspaceRoot
    roles = [ordered]@{
        batchA = [ordered]@{ name = $libraryBatchAName; path = $libraryBatchAPath }
        batchB = [ordered]@{ name = $libraryBatchBName; path = $libraryBatchBPath }
        open = [ordered]@{ name = $libraryBatchOpenName; path = $libraryBatchOpenPath }
    }
    treesBefore = $libraryBatchTreesBefore
    recycleBefore = $libraryBatchRecycleBefore
    recycleAfterOpenBlock = $libraryBatchRecycleAfterOpenBlock
    recycleAfterBatch = $libraryBatchRecycleAfterBatch
    restoreActions = $libraryBatchRestoreActions
    restoreWaitMilliseconds = $libraryBatchRestoreWaits
    recycleAfterRestore = $libraryBatchRecycleAfterRestore
    treesAfterRestore = $libraryBatchTreesAfterRestore
    recycleAfterFreshProcess = $libraryBatchRecycleAfterFresh
    treesAfterFreshProcess = $libraryBatchTreesAfterFresh
    openSourceBefore = $libraryBatchOpenSourceBefore
    openSourceAfterRestore = $libraryBatchOpenSourceAfterRestore
    openSourceAfterFreshProcess = $libraryBatchOpenSourceAfterFresh
    openDocumentBlock = [ordered]@{
        action = $libraryBatchOpenCapture.capture.libraryDeletionAction
        runtime = $libraryBatchOpenInteractionGui.library
    }
    batchDelete = [ordered]@{
        action = $libraryBatchDeleteCapture.capture.libraryDeletionAction
        runtime = $libraryBatchDeleteInteractionGui.library
    }
    freshProcess = [ordered]@{
        processId = $libraryBatchRestoredCapture.capture.processId
        runtime = $libraryBatchRestoredGui.library
    }
}
[void](Write-JsonArtifact `
    -Path $libraryBatchRecoveryEvidencePath -Value $libraryBatchRecoveryEvidence)

$proEditorPanGuiPath = Join-Path $guiRoot "avalonia-proeditor-pan-runtime-v1.json"
$proEditorPannedGuiPath = Join-Path $guiRoot "avalonia-proeditor-panned-runtime-v1.json"
$proEditorPanScreenshotPath = Join-Path $guiRoot "avalonia-proeditor-panned-v1.png"
$proEditorPanCapture = Invoke-GuiCaptureGate -Name "avalonia-proeditor-pan-gui-capture" -Arguments @{
    ChartPath = $isolatedProEditorPanPath
    EvidencePath = $proEditorPanGuiPath
    InteractionEvidencePath = $proEditorPannedGuiPath
    ScreenshotPath = $proEditorPanScreenshotPath
    WorkspaceRoot = $proEditorFixtureRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\proeditor-pan\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\proeditor-pan\editing")
    FocusProEditor = $true
    ExerciseProEditorPan = $true
    InteractionDelayMilliseconds = 18000
    TimeoutSeconds = 90
}
$proEditorEditGuiPath = Join-Path $guiRoot "avalonia-proeditor-edit-runtime-v1.json"
$proEditorSavedGuiPath = Join-Path $guiRoot "avalonia-proeditor-saved-runtime-v1.json"
$proEditorEditScreenshotPath = Join-Path $guiRoot "avalonia-proeditor-saved-v1.png"
$proEditorEditCapture = Invoke-GuiCaptureGate -Name "avalonia-proeditor-edit-gui-capture" -Arguments @{
    ChartPath = $isolatedProEditorEditPath
    EvidencePath = $proEditorEditGuiPath
    InteractionEvidencePath = $proEditorSavedGuiPath
    ScreenshotPath = $proEditorEditScreenshotPath
    WorkspaceRoot = $proEditorFixtureRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\proeditor-edit\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\proeditor-edit\editing")
    FocusProEditor = $true
    ExerciseProEditorEdit = $true
    SaveAfterProEditorEdit = $true
    InteractionDelayMilliseconds = 22000
    TimeoutSeconds = 90
}
$proEditorSavedSha256 = (Get-FileHash -LiteralPath $isolatedProEditorEditPath -Algorithm SHA256).Hash
if ($proEditorSavedSha256 -ne "6995CDE6268B0BF071718286363C45112E50829D9C063AC12A82D01EED50E68B" -or
    (Get-Item -LiteralPath $isolatedProEditorEditPath).Length -ne 591) {
    throw "The ProEditor GUI edit did not save the trusted compact MC result."
}

$proEditorReopenGuiPath = Join-Path $guiRoot "avalonia-proeditor-reopened-runtime-v1.json"
$proEditorReopenInteractionGuiPath = Join-Path $guiRoot "avalonia-proeditor-reopened-revealed-runtime-v1.json"
$proEditorReopenScreenshotPath = Join-Path $guiRoot "avalonia-proeditor-reopened-v1.png"
$proEditorReopenCapture = Invoke-GuiCaptureGate -Name "avalonia-proeditor-reopen-gui-capture" -Arguments @{
    ChartPath = $isolatedProEditorEditPath
    EvidencePath = $proEditorReopenGuiPath
    InteractionEvidencePath = $proEditorReopenInteractionGuiPath
    ScreenshotPath = $proEditorReopenScreenshotPath
    WorkspaceRoot = $proEditorFixtureRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\proeditor-reopen\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\proeditor-reopen\editing")
    FocusProEditor = $true
    ExerciseProEditorReveal = $true
    InteractionDelayMilliseconds = 18000
    TimeoutSeconds = 90
}

$isolatedProEditorOsuPath = Join-Path $proEditorEditDirectory "proeditor.osu"
$proEditorSaveAsGuiPath = Join-Path $guiRoot "avalonia-proeditor-saveas-runtime-v1.json"
$proEditorSavedAsGuiPath = Join-Path $guiRoot "avalonia-proeditor-saved-as-osu-runtime-v1.json"
$proEditorSaveAsScreenshotPath = Join-Path $guiRoot "avalonia-proeditor-saved-as-osu-v1.png"
$proEditorSaveAsCapture = Invoke-GuiCaptureGate -Name "avalonia-proeditor-saveas-gui-capture" -Arguments @{
    ChartPath = $isolatedProEditorEditPath
    EvidencePath = $proEditorSaveAsGuiPath
    InteractionEvidencePath = $proEditorSavedAsGuiPath
    ScreenshotPath = $proEditorSaveAsScreenshotPath
    WorkspaceRoot = $proEditorFixtureRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\proeditor-saveas\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\proeditor-saveas\editing")
    FocusProEditor = $true
    ExerciseProEditorSaveAsOsu = $true
    ProEditorSaveAsOsuPath = $isolatedProEditorOsuPath
    InteractionDelayMilliseconds = 18000
    TimeoutSeconds = 100
}
$proEditorOsuSha256 = (Get-FileHash -LiteralPath $isolatedProEditorOsuPath -Algorithm SHA256).Hash
$proEditorOsuText = Get-Content -LiteralPath $isolatedProEditorOsuPath -Raw
if (-not $proEditorOsuText.Contains("[HitObjects]")) {
    throw "The ProEditor native Save As output is not an osu chart."
}

$proEditorOsuReopenGuiPath = Join-Path $guiRoot "avalonia-proeditor-osu-reopened-runtime-v1.json"
$proEditorOsuReopenInteractionGuiPath = Join-Path $guiRoot "avalonia-proeditor-osu-reopened-revealed-runtime-v1.json"
$proEditorOsuReopenScreenshotPath = Join-Path $guiRoot "avalonia-proeditor-osu-reopened-v1.png"
$proEditorOsuReopenCapture = Invoke-GuiCaptureGate -Name "avalonia-proeditor-osu-reopen-gui-capture" -Arguments @{
    ChartPath = $isolatedProEditorOsuPath
    EvidencePath = $proEditorOsuReopenGuiPath
    InteractionEvidencePath = $proEditorOsuReopenInteractionGuiPath
    ScreenshotPath = $proEditorOsuReopenScreenshotPath
    WorkspaceRoot = $proEditorFixtureRoot
    LocalDataRoot = (Join-Path $guiRoot "sessions\proeditor-osu-reopen\local-data")
    EditingRoot = (Join-Path $guiRoot "sessions\proeditor-osu-reopen\editing")
    FocusProEditor = $true
    ExerciseProEditorReveal = $true
    InteractionDelayMilliseconds = 18000
    TimeoutSeconds = 90
}

$chartExportModesCapture = Invoke-GuiCaptureGate `
    -Name "avalonia-chart-export-modes-gui-capture" `
    -Arguments @{
        ChartPath = $chartExportModesChartPath
        EvidencePath = $chartExportModesGuiPath
        InteractionEvidencePath = $chartExportModesInteractionGuiPath
        ScreenshotPath = $chartExportModesScreenshotPath
        WorkspaceRoot = $chartExportModesSourceRoot
        LocalDataRoot = $chartExportModesLocalDataRoot
        EditingRoot = $chartExportModesEditingRoot
        ExerciseChartExportModes = $true
        ChartExportModesDefaultScreenshotPath =
            $chartExportModesDefaultScreenshotPath
        ChartExportModesSingleChartScreenshotPath =
            $chartExportModesSingleChartScreenshotPath
        ChartExportModesSingleRateScreenshotPath =
            $chartExportModesSingleRateScreenshotPath
        ChartExportModesRatePackScreenshotPath =
            $chartExportModesRatePackScreenshotPath
        ChartExportModesHiddenValidationScreenshotPath =
            $chartExportModesHiddenValidationScreenshotPath
        ChartExportModesContinueToExport = $true
        ChartExportModesExportFormat = "Malody"
        ChartExportModesExportMode = "SingleRatePackage"
        ChartExportModesExportPath = $chartExportModesExportPath
        ChartExportModesExportRate = 1.25
        ChartExportModesExportPreservePitch = $true
        ChartExportModesExportResultScreenshotPath =
            $chartExportModesResultScreenshotPath
        InteractionDelayMilliseconds = 40000
        TimeoutSeconds = 120
    }

$malodyFullPackageCapture = Invoke-GuiCaptureGate `
    -Name "avalonia-malody-full-package-gui-capture" `
    -Arguments @{
        ChartPath = $malodyFullPackageMainChartPath
        EvidencePath = $malodyFullPackageGuiPath
        InteractionEvidencePath = $malodyFullPackageInteractionGuiPath
        ScreenshotPath = $malodyFullPackageScreenshotPath
        WorkspaceRoot = $malodyFullPackageSourceRoot
        LocalDataRoot = $malodyFullPackageMainLocalDataRoot
        EditingRoot = $malodyFullPackageMainEditingRoot
        FocusNoteProperty = $true
        FocusNotePropertyBeat = "182:1/4"
        ExerciseMalodyFullPackageExport = $true
        MalodyFullPackageExportPath = $malodyFullPackageExportPath
        MalodyFullPackageSourceRoot = $malodyFullPackageSourceRoot
        MalodyFullPackageOptionsScreenshotPath =
            $malodyFullPackageOptionsScreenshotPath
        MalodyFullPackageResultScreenshotPath =
            $malodyFullPackageResultScreenshotPath
        MalodyFullPackageFreshImportEvidencePath =
            $malodyFullPackageFreshGuiPath
        MalodyFullPackageFreshImportInteractionEvidencePath =
            $malodyFullPackageFreshInteractionGuiPath
        MalodyFullPackageFreshImportDialogScreenshotPath =
            $malodyFullPackageFreshDialogScreenshotPath
        MalodyFullPackageFreshImportScreenshotPath =
            $malodyFullPackageFreshScreenshotPath
        MalodyFullPackageFreshImportWorkspaceRoot =
            $malodyFullPackageFreshWorkspaceRoot
        MalodyFullPackageFreshImportLocalDataRoot =
            $malodyFullPackageFreshLocalDataRoot
        MalodyFullPackageFreshImportEditingRoot =
            $malodyFullPackageFreshEditingRoot
        MalodyFullPackageExpectedChartCount = 8
        InteractionDelayMilliseconds = 30000
        TimeoutSeconds = 120
    }
$osuFullPackageCapture = Invoke-GuiCaptureGate `
    -Name "avalonia-osu-full-package-gui-capture" `
    -Arguments @{
        ChartPath = $osuFullPackageMainChartPath
        EvidencePath = $osuFullPackageGuiPath
        InteractionEvidencePath = $osuFullPackageInteractionGuiPath
        ScreenshotPath = $osuFullPackageScreenshotPath
        WorkspaceRoot = $osuFullPackageSourceRoot
        LocalDataRoot = $osuFullPackageMainLocalDataRoot
        EditingRoot = $osuFullPackageMainEditingRoot
        FocusNoteProperty = $true
        FocusNotePropertyBeat = "15:5/6"
        ExerciseOsuFullPackageExport = $true
        OsuFullPackageExportPath = $osuFullPackageExportPath
        OsuFullPackageSourceRoot = $osuFullPackageSourceRoot
        OsuFullPackageOptionsScreenshotPath = $osuFullPackageOptionsScreenshotPath
        OsuFullPackageResultScreenshotPath = $osuFullPackageResultScreenshotPath
        OsuFullPackageFreshImportEvidencePath = $osuFullPackageFreshGuiPath
        OsuFullPackageFreshImportInteractionEvidencePath =
            $osuFullPackageFreshInteractionGuiPath
        OsuFullPackageFreshImportDialogScreenshotPath =
            $osuFullPackageFreshDialogScreenshotPath
        OsuFullPackageFreshImportFirstCalibrationScreenshotPath =
            $osuFullPackageFirstCalibrationScreenshotPath
        OsuFullPackageFreshImportSecondCalibrationScreenshotPath =
            $osuFullPackageSecondCalibrationScreenshotPath
        OsuFullPackageFreshImportScreenshotPath = $osuFullPackageFreshScreenshotPath
        OsuFullPackageFreshImportWorkspaceRoot = $osuFullPackageFreshWorkspaceRoot
        OsuFullPackageFreshImportLocalDataRoot = $osuFullPackageFreshLocalDataRoot
        OsuFullPackageFreshImportEditingRoot = $osuFullPackageFreshEditingRoot
        OsuFullPackageExpectedChartCount = 2
        OsuFullPackageOverallDifficulty = 8.75
        OsuFullPackageHpDrainRate = 9
        InteractionDelayMilliseconds = 30000
        TimeoutSeconds = 120
    }
$malodyToOsuFullPackageCapture = Invoke-GuiCaptureGate `
    -Name "avalonia-malody-to-osu-full-package-gui-capture" `
    -Arguments @{
        ChartPath = $malodyToOsuFullPackageMainChartPath
        EvidencePath = $malodyToOsuFullPackageGuiPath
        InteractionEvidencePath = $malodyToOsuFullPackageInteractionGuiPath
        ScreenshotPath = $malodyToOsuFullPackageScreenshotPath
        WorkspaceRoot = $malodyToOsuFullPackageSourceRoot
        LocalDataRoot = $malodyToOsuFullPackageMainLocalDataRoot
        EditingRoot = $malodyToOsuFullPackageMainEditingRoot
        FocusNoteProperty = $true
        FocusNotePropertyBeat = "182:1/4"
        ExerciseMalodyToOsuFullPackageExport = $true
        OsuFullPackageExportPath = $malodyToOsuFullPackageExportPath
        OsuFullPackageSourceRoot = $malodyToOsuFullPackageSourceRoot
        OsuFullPackageOptionsScreenshotPath =
            $malodyToOsuFullPackageOptionsScreenshotPath
        OsuFullPackageResultScreenshotPath =
            $malodyToOsuFullPackageResultScreenshotPath
        OsuFullPackageFreshImportEvidencePath =
            $malodyToOsuFullPackageFreshGuiPath
        OsuFullPackageFreshImportInteractionEvidencePath =
            $malodyToOsuFullPackageFreshInteractionGuiPath
        OsuFullPackageFreshImportDialogScreenshotPath =
            $malodyToOsuFullPackageFreshDialogScreenshotPath
        OsuFullPackageFreshImportFirstCalibrationScreenshotPath =
            $malodyToOsuFullPackageFirstCalibrationScreenshotPath
        OsuFullPackageFreshImportScreenshotPath =
            $malodyToOsuFullPackageFreshScreenshotPath
        OsuFullPackageFreshImportWorkspaceRoot =
            $malodyToOsuFullPackageFreshWorkspaceRoot
        OsuFullPackageFreshImportLocalDataRoot =
            $malodyToOsuFullPackageFreshLocalDataRoot
        OsuFullPackageFreshImportEditingRoot =
            $malodyToOsuFullPackageFreshEditingRoot
        OsuFullPackageExpectedChartCount = 1
        OsuFullPackageOverallDifficulty = 8.75
        OsuFullPackageHpDrainRate = 9
        InteractionDelayMilliseconds = 30000
        TimeoutSeconds = 120
    }
$osuToMalodyFullPackageCapture = Invoke-GuiCaptureGate `
    -Name "avalonia-osu-to-malody-full-package-gui-capture" `
    -Arguments @{
        ChartPath = $osuToMalodyFullPackageMainChartPath
        EvidencePath = $osuToMalodyFullPackageGuiPath
        InteractionEvidencePath = $osuToMalodyFullPackageInteractionGuiPath
        ScreenshotPath = $osuToMalodyFullPackageScreenshotPath
        WorkspaceRoot = $osuToMalodyFullPackageSourceRoot
        LocalDataRoot = $osuToMalodyFullPackageMainLocalDataRoot
        EditingRoot = $osuToMalodyFullPackageMainEditingRoot
        FocusNoteProperty = $true
        FocusNotePropertyBeat = "15:5/6"
        ExerciseOsuToMalodyFullPackageExport = $true
        MalodyFullPackageExportPath = $osuToMalodyFullPackageExportPath
        MalodyFullPackageSourceRoot = $osuToMalodyFullPackageSourceRoot
        MalodyFullPackageOptionsScreenshotPath =
            $osuToMalodyFullPackageOptionsScreenshotPath
        MalodyFullPackageResultScreenshotPath =
            $osuToMalodyFullPackageResultScreenshotPath
        MalodyFullPackageFreshImportEvidencePath =
            $osuToMalodyFullPackageFreshGuiPath
        MalodyFullPackageFreshImportInteractionEvidencePath =
            $osuToMalodyFullPackageFreshInteractionGuiPath
        MalodyFullPackageFreshImportDialogScreenshotPath =
            $osuToMalodyFullPackageFreshDialogScreenshotPath
        MalodyFullPackageFreshImportScreenshotPath =
            $osuToMalodyFullPackageFreshScreenshotPath
        MalodyFullPackageFreshImportWorkspaceRoot =
            $osuToMalodyFullPackageFreshWorkspaceRoot
        MalodyFullPackageFreshImportLocalDataRoot =
            $osuToMalodyFullPackageFreshLocalDataRoot
        MalodyFullPackageFreshImportEditingRoot =
            $osuToMalodyFullPackageFreshEditingRoot
        MalodyFullPackageExpectedChartCount = 1
        InteractionDelayMilliseconds = 30000
        TimeoutSeconds = 120
    }

$libraryNoResultsGui = Get-RequiredJson $libraryNoResultsEvidencePath
if ($libraryNoResultsGui.schema -cne "lumachart.windows.avalonia.library-search-evidence.v1" -or
    $libraryNoResultsGui.status -cne "passed" -or
    -not [bool]$libraryNoResultsGui.passed -or
    [string]$libraryNoResultsGui.query -cne $libraryNoResultsQuery -or
    [string]$libraryNoResultsGui.searchValue -cne $libraryNoResultsQuery -or
    -not [bool]$libraryNoResultsGui.physicalPointerFocusAttempted -or
    -not [bool]$libraryNoResultsGui.physicalKeyboardInput -or
    [bool]$libraryNoResultsGui.initialVisibleList.isOffscreen -or
    [double]$libraryNoResultsGui.initialVisibleList.bounds.width -le 1 -or
    [double]$libraryNoResultsGui.initialVisibleList.bounds.height -le 1 -or
    [string]$libraryNoResultsGui.emptyTitle.automationId -cne "Library.EmptyTitle" -or
    [string]$libraryNoResultsGui.emptyTitle.name -cne "没有符合筛选条件的项目" -or
    [string]$libraryNoResultsGui.emptySubtitle.automationId -cne "Library.EmptySubtitle" -or
    [string]$libraryNoResultsGui.emptySubtitle.name -cne
        "当前搜索没有匹配结果；请清空搜索或更换筛选条件。" -or
    [bool]$libraryNoResultsGui.launcherVisible -or
    [bool]$libraryNoResultsGui.listVisibleAfterSearch -or
    -not [bool]$libraryNoResultsCapture.capture.libraryNoResultsExercised -or
    -not [bool]$libraryNoResultsCapture.capture.interactionCapturedAfterActions) {
    throw "The library search-zero GUI did not retain WPF's no-result copy and hidden launcher/list semantics."
}

$realGui = Get-RequiredJson $realGuiPath
$realInteractionGui = Get-RequiredJson $realInteractionGuiPath
$transformGui = Get-RequiredJson $transformGuiPath
$transformInteractionGui = Get-RequiredJson $transformInteractionGuiPath
$propertyGui = Get-RequiredJson $propertyGuiPath
$propertyInteractionGui = Get-RequiredJson $propertyInteractionGuiPath
$propertyReopenGui = Get-RequiredJson $propertyReopenGuiPath
$groupAssignGui = Get-RequiredJson $groupAssignGuiPath
$groupSavedGui = Get-RequiredJson $groupSavedGuiPath
$groupVisibilityGui = Get-RequiredJson $groupVisibilityGuiPath
$groupHiddenGui = Get-RequiredJson $groupHiddenGuiPath
$groupPlacementGui = Get-RequiredJson $groupPlacementGuiPath
$groupPlacedGui = Get-RequiredJson $groupPlacedGuiPath
$osuGui = Get-RequiredJson $osuGuiPath
$osuInteractionGui = Get-RequiredJson $osuInteractionGuiPath
$hundredKGui = Get-RequiredJson $hundredKGuiPath
$keySoundSharedGui = Get-RequiredJson $keySoundSharedGuiPath
$keySoundSharedInteractionGui = Get-RequiredJson $keySoundSharedInteractionGuiPath
$keySoundSilentGui = Get-RequiredJson $keySoundSilentGuiPath
$keySoundSilentInteractionGui = Get-RequiredJson $keySoundSilentInteractionGuiPath
$displayScaleGui = Get-RequiredJson $displayScaleGuiPath
$displayScaleInteractionGui = Get-RequiredJson $displayScaleInteractionGuiPath
$displayScaleReopenGui = Get-RequiredJson $displayScaleReopenGuiPath
$displayScaleCorruptGui = Get-RequiredJson $displayScaleCorruptGuiPath
$audioPanelDefaultGui = Get-RequiredJson $audioPanelDefaultGuiPath
$audioPanelGui = Get-RequiredJson $audioPanelGuiPath
$audioPanelInteractionGui = Get-RequiredJson $audioPanelInteractionGuiPath
$audioPanelReopenGui = Get-RequiredJson $audioPanelReopenGuiPath
$proEditorPanGui = Get-RequiredJson $proEditorPanGuiPath
$proEditorPannedGui = Get-RequiredJson $proEditorPannedGuiPath
$proEditorEditGui = Get-RequiredJson $proEditorEditGuiPath
$proEditorSavedGui = Get-RequiredJson $proEditorSavedGuiPath
$proEditorReopenGui = Get-RequiredJson $proEditorReopenGuiPath
$proEditorReopenInteractionGui = Get-RequiredJson $proEditorReopenInteractionGuiPath
$proEditorSaveAsGui = Get-RequiredJson $proEditorSaveAsGuiPath
$proEditorSavedAsGui = Get-RequiredJson $proEditorSavedAsGuiPath
$proEditorOsuReopenGui = Get-RequiredJson $proEditorOsuReopenGuiPath
$proEditorOsuReopenInteractionGui = Get-RequiredJson $proEditorOsuReopenInteractionGuiPath
$chartExportModesGui = Get-RequiredJson $chartExportModesGuiPath
$chartExportModesInteractionGui =
    Get-RequiredJson $chartExportModesInteractionGuiPath
$malodyFullPackageGui = Get-RequiredJson $malodyFullPackageGuiPath
$malodyFullPackageInteractionGui =
    Get-RequiredJson $malodyFullPackageInteractionGuiPath
$malodyFullPackageFreshGui = Get-RequiredJson $malodyFullPackageFreshGuiPath
$malodyFullPackageFreshInteractionGui =
    Get-RequiredJson $malodyFullPackageFreshInteractionGuiPath
$osuFullPackageGui = Get-RequiredJson $osuFullPackageGuiPath
$osuFullPackageInteractionGui = Get-RequiredJson $osuFullPackageInteractionGuiPath
$osuFullPackageFreshGui = Get-RequiredJson $osuFullPackageFreshGuiPath
$osuFullPackageFreshInteractionGui =
    Get-RequiredJson $osuFullPackageFreshInteractionGuiPath
$malodyToOsuFullPackageGui = Get-RequiredJson $malodyToOsuFullPackageGuiPath
$malodyToOsuFullPackageInteractionGui =
    Get-RequiredJson $malodyToOsuFullPackageInteractionGuiPath
$malodyToOsuFullPackageFreshGui =
    Get-RequiredJson $malodyToOsuFullPackageFreshGuiPath
$malodyToOsuFullPackageFreshInteractionGui =
    Get-RequiredJson $malodyToOsuFullPackageFreshInteractionGuiPath
$osuToMalodyFullPackageGui = Get-RequiredJson $osuToMalodyFullPackageGuiPath
$osuToMalodyFullPackageInteractionGui =
    Get-RequiredJson $osuToMalodyFullPackageInteractionGuiPath
$osuToMalodyFullPackageFreshGui =
    Get-RequiredJson $osuToMalodyFullPackageFreshGuiPath
$osuToMalodyFullPackageFreshInteractionGui =
    Get-RequiredJson $osuToMalodyFullPackageFreshInteractionGuiPath
foreach ($guiEvidence in $realGui, $realInteractionGui, $transformGui, $transformInteractionGui,
        $propertyGui, $propertyInteractionGui, $propertyReopenGui,
        $groupAssignGui, $groupSavedGui, $groupVisibilityGui, $groupHiddenGui,
        $groupPlacementGui, $groupPlacedGui,
        $osuGui, $osuInteractionGui, $hundredKGui,
        $keySoundSharedGui, $keySoundSharedInteractionGui,
        $keySoundSilentGui, $keySoundSilentInteractionGui,
        $displayScaleGui, $displayScaleInteractionGui, $displayScaleReopenGui,
        $displayScaleCorruptGui, $audioPanelDefaultGui, $audioPanelGui,
        $audioPanelInteractionGui, $audioPanelReopenGui,
        $chartValidationGui, $chartValidationInteractionGui,
        $proEditorPanGui, $proEditorPannedGui, $proEditorEditGui, $proEditorSavedGui,
        $proEditorReopenGui, $proEditorReopenInteractionGui,
        $proEditorSaveAsGui, $proEditorSavedAsGui,
        $proEditorOsuReopenGui, $proEditorOsuReopenInteractionGui,
        $chartExportModesGui, $chartExportModesInteractionGui,
        $malodyFullPackageGui, $malodyFullPackageInteractionGui,
        $malodyFullPackageFreshGui, $malodyFullPackageFreshInteractionGui,
        $osuFullPackageGui, $osuFullPackageInteractionGui,
        $osuFullPackageFreshGui, $osuFullPackageFreshInteractionGui,
        $malodyToOsuFullPackageGui, $malodyToOsuFullPackageInteractionGui,
        $malodyToOsuFullPackageFreshGui,
        $malodyToOsuFullPackageFreshInteractionGui,
        $osuToMalodyFullPackageGui, $osuToMalodyFullPackageInteractionGui,
        $osuToMalodyFullPackageFreshGui,
        $osuToMalodyFullPackageFreshInteractionGui) {
    if ($guiEvidence.schema -cne "lumachart.windows.avalonia.gui-evidence.v12" -or
        -not $guiEvidence.timeline.targetReached -or
        $guiEvidence.timeline.performance.renderMilliseconds.samples -lt 240) {
        throw "A GUI performance probe did not produce a complete 240-sample result."
    }
}
foreach ($audioEvidence in $realGui.audio, $realInteractionGui.audio, $transformGui.audio,
        $transformInteractionGui.audio, $propertyGui.audio, $propertyInteractionGui.audio,
        $propertyReopenGui.audio, $groupAssignGui.audio, $groupSavedGui.audio,
        $groupVisibilityGui.audio, $groupHiddenGui.audio, $groupPlacementGui.audio,
        $groupPlacedGui.audio, $osuGui.audio, $osuInteractionGui.audio, $hundredKGui.audio,
        $chartExportModesGui.audio, $chartExportModesInteractionGui.audio) {
    if (-not $audioEvidence.uiIntegrated -or
        -not $audioEvidence.sourceExists -or
        $audioEvidence.state -notin "Stopped", "Paused" -or
        $audioEvidence.durationMilliseconds -le 0 -or
        $audioEvidence.lastErrorType) {
        throw "A real-chart GUI probe did not load its referenced Windows audio into the transport UI."
    }
}
if ($realGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $realInteractionGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $transformGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $transformInteractionGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $propertyGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $propertyInteractionGui.chart.sourceSha256 -ne $propertySavedSha256 -or
    $propertyReopenGui.chart.sourceSha256 -ne $propertySavedSha256 -or
    $groupAssignGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $groupSavedGui.chart.sourceSha256 -ne $groupSavedSha256 -or
    $groupVisibilityGui.chart.sourceSha256 -ne $groupSavedSha256 -or
    $groupHiddenGui.chart.sourceSha256 -ne $groupSavedSha256 -or
    $groupPlacementGui.chart.sourceSha256 -ne $groupSavedSha256 -or
    $groupPlacedGui.chart.sourceSha256 -ne $groupSavedSha256 -or
    $osuGui.chart.sourceSha256 -ne $osuFixtureSha256 -or
    $osuInteractionGui.chart.sourceSha256 -ne $osuFixtureSha256 -or
    $hundredKGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $hundredKGui.chart.syntheticNoteCount -ne 100000 -or
    $keySoundSharedGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $keySoundSharedInteractionGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $keySoundSilentGui.chart.sourceSha256 -ne $keySoundFlatFixtureSha256 -or
    $keySoundSilentInteractionGui.chart.sourceSha256 -ne $keySoundFlatFixtureSha256 -or
    $displayScaleGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $displayScaleInteractionGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $displayScaleReopenGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $displayScaleCorruptGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $audioPanelDefaultGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $audioPanelGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $audioPanelInteractionGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $audioPanelReopenGui.chart.sourceSha256 -ne $fixtureSha256 -or
    $chartExportModesGui.chart.sourceSha256 -cne
        [string]$chartExportModesExpectedSourceHashes['fixture.mc'] -or
    $chartExportModesInteractionGui.chart.sourceSha256 -cne
        [string]$chartExportModesExpectedSourceHashes['fixture.mc']) {
    throw "A GUI probe did not use the required isolated fixture/workload."
}
if ($proEditorPanGui.chart.sourceSha256 -ne $proEditorFixtureSha256 -or
    $proEditorPannedGui.chart.sourceSha256 -ne $proEditorFixtureSha256 -or
    $proEditorEditGui.chart.sourceSha256 -ne $proEditorFixtureSha256 -or
    $proEditorSavedGui.chart.sourceSha256 -ne $proEditorSavedSha256 -or
    $proEditorReopenGui.chart.sourceSha256 -ne $proEditorSavedSha256 -or
    $proEditorReopenInteractionGui.chart.sourceSha256 -ne $proEditorSavedSha256 -or
    $proEditorSaveAsGui.chart.sourceSha256 -ne $proEditorSavedSha256 -or
    $proEditorSavedAsGui.chart.sourceSha256 -ne $proEditorOsuSha256 -or
    $proEditorOsuReopenGui.chart.sourceSha256 -ne $proEditorOsuSha256 -or
    $proEditorOsuReopenInteractionGui.chart.sourceSha256 -ne $proEditorOsuSha256) {
    throw "A ProEditor GUI probe did not retain the expected MC/Save-As source hash chain."
}

function Assert-KeySoundGuiCase {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Capture,
        [Parameter(Mandatory = $true)]$PrimaryEvidence,
        [Parameter(Mandatory = $true)]$InteractionEvidence,
        [Parameter(Mandatory = $true)][string]$ExpectedChartPath,
        [Parameter(Mandatory = $true)][bool]$ExpectedAudioSourceExists,
        [Parameter(Mandatory = $true)][ValidateSet("shared", "standalone")][string]$ExpectedOutput,
        [int]$ExpectedEventCount = -1,
        [int]$ExpectedHeadEventCount = -1,
        [int]$ExpectedLongNoteTailEventCount = -1,
        [int]$ExpectedCustomSampleEventCount = -1,
        [int]$ExpectedPresetFallbackEventCount = -1,
        [int]$ExpectedPreloadCount = -1
    )

    $captureEvidence = $Capture.capture
    $primaryKeySound = $PrimaryEvidence.audio.keySound
    $interactionKeySound = $InteractionEvidence.audio.keySound
    if (-not [bool]$captureEvidence.focusKeySound -or
        -not [bool]$captureEvidence.keySoundRuntimeExercised -or
        -not [bool]$captureEvidence.keySoundPreviewCompleted -or
        -not [bool]$captureEvidence.keySoundPlayCompleted -or
        -not [bool]$captureEvidence.keySoundStopCompleted -or
        -not [bool]$captureEvidence.interactionCapturedAfterActions -or
        [bool]$captureEvidence.keySoundAudibleOrLoopbackValidated -or
        $null -eq $captureEvidence.interactionActionsCompletedAtUtc -or
        $null -eq $primaryKeySound -or $null -eq $interactionKeySound -or
        -not [bool]$primaryKeySound.uiIntegrated -or
        -not [bool]$interactionKeySound.uiIntegrated) {
        throw "$Name did not complete the required real Key-sound UIA/mouse Preview, Play and Stop workflow."
    }

    $requiredControlIds = @(
        "Inspector.AudioTab",
        "KeySound.Panel",
        "KeySound.Enabled",
        "KeySound.Preset",
        "KeySound.Volume",
        "KeySound.LongNoteEnd",
        "KeySound.GlobalOffset",
        "KeySound.ChartOffset",
        "KeySound.Preview",
        "Audio.PlayPause",
        "Audio.Stop")
    foreach ($automationId in $requiredControlIds) {
        $controlProperty = $captureEvidence.keySoundControls.PSObject.Properties[$automationId]
        if ($null -eq $controlProperty -or
            [string]$controlProperty.Value.automationId -cne $automationId -or
            -not [bool]$controlProperty.Value.isEnabled -or
            [bool]$controlProperty.Value.isOffscreen -or
            [double]$controlProperty.Value.bounds.width -le 1 -or
            [double]$controlProperty.Value.bounds.height -le 1) {
            throw "$Name did not expose enabled, on-screen UI Automation control '$automationId'."
        }
    }

    $submitted = $captureEvidence.keySoundSubmittedSettings
    $settings = $interactionKeySound.settings
    if (-not [bool]$submitted.enabled -or
        [string]$submitted.preset -cne "Snare" -or
        [string]::IsNullOrWhiteSpace([string]$submitted.observedPreset) -or
        [Math]::Abs([double]$submitted.volume - 70) -gt .001 -or
        -not [bool]$submitted.playLongNoteEndSound -or
        [Math]::Abs([double]$submitted.globalOffsetMilliseconds - (-15)) -gt .001 -or
        [Math]::Abs([double]$submitted.chartOffsetMilliseconds - 5) -gt .001 -or
        -not [bool]$settings.enabled -or
        [string]$settings.preset -cne "Snare" -or
        [Math]::Abs([double]$settings.volume - .7) -gt .0001 -or
        $null -ne $settings.customFilePath -or
        [bool]$settings.customFileExists -or
        -not [bool]$settings.playLongNoteEndSound -or
        [double]$settings.globalOffsetMilliseconds -ne -15 -or
        [double]$settings.chartOffsetMilliseconds -ne 5 -or
        [double]$settings.effectiveOffsetMilliseconds -ne -10) {
        throw "$Name did not retain the exact submitted Key-sound settings."
    }

    $plan = $interactionKeySound.plan
    $expectedFullPath = [IO.Path]::GetFullPath($ExpectedChartPath)
    $planFullPath = [IO.Path]::GetFullPath([string]$plan.sourcePath)
    if (-not $planFullPath.Equals($expectedFullPath, [StringComparison]::OrdinalIgnoreCase) -or
        [long]$plan.sessionChangeSerial -ne [long]$InteractionEvidence.timeline.sessionChangeSerial -or
        (@($plan.hiddenGroups) -join ',') -cne (@($InteractionEvidence.timeline.hiddenGroups) -join ',') -or
        [int]$plan.eventCount -le 0 -or
        [int]$plan.headEventCount -ne [int]$InteractionEvidence.chart.structure.noteCount -or
        [int]$plan.longNoteTailEventCount -ne [int]$InteractionEvidence.chart.structure.longNoteCount -or
        [int]$plan.eventCount -ne
            ([int]$plan.headEventCount + [int]$plan.longNoteTailEventCount) -or
        [int]$plan.eventCount -ne
            ([int]$plan.customSampleEventCount + [int]$plan.presetFallbackEventCount) -or
        [int]$plan.runtimeEventCount -ne [int]$plan.eventCount -or
        [int]$plan.runtimePreloadCount -ne [int]$plan.preloadCount -or
        -not [bool]$plan.runtimeRequestedTabMatches -or
        -not [bool]$plan.runtimePlannedTabMatches -or
        -not [bool]$plan.runtimeEventCountMatches -or
        -not [bool]$plan.runtimePreloadCountMatches -or
        -not [bool]$plan.runtimeEnabledMatches -or
        -not [bool]$plan.runtimePlanMatchesExpected -or
        $null -ne $plan.expectedPlanErrorType) {
        throw "$Name expected cold-path plan did not match the published runtime plan."
    }
    $exactPlanCounts = [ordered]@{
        eventCount = $ExpectedEventCount
        headEventCount = $ExpectedHeadEventCount
        longNoteTailEventCount = $ExpectedLongNoteTailEventCount
        customSampleEventCount = $ExpectedCustomSampleEventCount
        presetFallbackEventCount = $ExpectedPresetFallbackEventCount
        preloadCount = $ExpectedPreloadCount
    }
    foreach ($entry in $exactPlanCounts.GetEnumerator()) {
        if ([int]$entry.Value -ge 0 -and [int]$plan.($entry.Key) -ne [int]$entry.Value) {
            throw "$Name plan $($entry.Key) was $($plan.($entry.Key)); expected $($entry.Value)."
        }
    }

    $beforeScheduler = $primaryKeySound.scheduler
    $afterScheduler = $interactionKeySound.scheduler
    $beforeOutput = $primaryKeySound.output
    $afterOutput = $interactionKeySound.output
    $dueDelta = [long]$afterScheduler.due - [long]$beforeScheduler.due
    $acceptedDelta = [long]$afterScheduler.accepted - [long]$beforeScheduler.accepted
    $rejectedDelta = [long]$afterScheduler.rejected - [long]$beforeScheduler.rejected
    $submittedVoiceDelta = [long]$afterScheduler.submittedVoices -
        [long]$beforeScheduler.submittedVoices
    $sharedAcceptedDelta = [long]$afterOutput.sharedAccepted - [long]$beforeOutput.sharedAccepted
    $standaloneAcceptedDelta = [long]$afterOutput.standaloneAccepted -
        [long]$beforeOutput.standaloneAccepted
    $sharedRejectedDelta = [long]$afterOutput.sharedRejected - [long]$beforeOutput.sharedRejected
    $standaloneRejectedDelta = [long]$afterOutput.standaloneRejected -
        [long]$beforeOutput.standaloneRejected
    $auditionAcceptedDelta = [long]$afterOutput.auditionAccepted -
        [long]$beforeOutput.auditionAccepted
    if ([bool]$afterScheduler.preparing -or
        -not [bool]$afterScheduler.hasPlan -or
        -not [bool]$afterScheduler.enabled -or
        [long]$afterScheduler.generation -le [long]$beforeScheduler.generation -or
        [long]$afterScheduler.clockSamplesPublished -le
            [long]$beforeScheduler.clockSamplesPublished -or
        [long]$afterScheduler.clockSamplesProcessed -le
            [long]$beforeScheduler.clockSamplesProcessed -or
        $dueDelta -le 0 -or $acceptedDelta -le 0 -or
        $dueDelta -ne ($acceptedDelta + $rejectedDelta) -or
        $submittedVoiceDelta -le 0 -or $submittedVoiceDelta -gt $acceptedDelta -or
        $acceptedDelta -ne ($sharedAcceptedDelta + $standaloneAcceptedDelta) -or
        $rejectedDelta -ne ($sharedRejectedDelta + $standaloneRejectedDelta) -or
        $auditionAcceptedDelta -le 0 -or
        [string]$interactionKeySound.validationLevel -cne "scheduler-and-output-submission" -or
        [bool]$primaryKeySound.audibleOrLoopbackValidated -or
        [bool]$interactionKeySound.audibleOrLoopbackValidated -or
        $null -ne $interactionKeySound.lastErrorType) {
        throw "$Name did not prove coherent logical trigger accounting and output submission."
    }
    if ($ExpectedOutput -ceq "shared") {
        if ($sharedAcceptedDelta -le 0 -or $standaloneAcceptedDelta -ne 0 -or
            [string]$afterOutput.transportMode -cne "shared-music-clock-observed" -or
            [string]$captureEvidence.keySoundSourceMode -cne "shared-audio-candidate") {
            throw "$Name did not submit Key-sound triggers through the shared music clock."
        }
    }
    elseif ($standaloneAcceptedDelta -le 0 -or $sharedAcceptedDelta -ne 0 -or
            [string]$afterOutput.transportMode -cne "silent-editor-clock-observed" -or
            [string]$captureEvidence.keySoundSourceMode -cne "silent-clock-candidate") {
        throw "$Name did not submit Key-sound triggers through the silent editor clock."
    }
    if ([bool]$PrimaryEvidence.audio.sourceExists -ne $ExpectedAudioSourceExists -or
        [bool]$InteractionEvidence.audio.sourceExists -ne $ExpectedAudioSourceExists -or
        $null -ne $PrimaryEvidence.audio.lastErrorType -or
        $null -ne $InteractionEvidence.audio.lastErrorType -or
        ($ExpectedAudioSourceExists -and
         ([double]$PrimaryEvidence.audio.durationMilliseconds -le 0 -or
          [double]$InteractionEvidence.audio.durationMilliseconds -le 0))) {
        throw "$Name did not retain the expected music-source availability for its transport mode."
    }
}

Assert-KeySoundGuiCase `
    -Name "Real Resound shared-clock Key-sound GUI" `
    -Capture $keySoundSharedCapture `
    -PrimaryEvidence $keySoundSharedGui `
    -InteractionEvidence $keySoundSharedInteractionGui `
    -ExpectedChartPath $isolatedKeySoundSharedMcPath `
    -ExpectedAudioSourceExists $true `
    -ExpectedOutput "shared"
Assert-KeySoundGuiCase `
    -Name "Flat fixture silent-clock Key-sound GUI" `
    -Capture $keySoundSilentCapture `
    -PrimaryEvidence $keySoundSilentGui `
    -InteractionEvidence $keySoundSilentInteractionGui `
    -ExpectedChartPath $isolatedKeySoundSilentMcPath `
    -ExpectedAudioSourceExists $false `
    -ExpectedOutput "standalone" `
    -ExpectedEventCount 14 `
    -ExpectedHeadEventCount 12 `
    -ExpectedLongNoteTailEventCount 2 `
    -ExpectedCustomSampleEventCount 3 `
    -ExpectedPresetFallbackEventCount 11 `
    -ExpectedPreloadCount 1

function Assert-DisplayScaleRuntime {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Runtime,
        [Parameter(Mandatory = $true)][string]$ExpectedLocalDataRoot,
        [Parameter(Mandatory = $true)][string]$ExpectedSettingsPath,
        [Parameter(Mandatory = $true)][double]$ExpectedUiScale,
        [Parameter(Mandatory = $true)][double]$ExpectedFontScale,
        [switch]$ExpectStartupBounds
    )

    $window = $Runtime.window
    $scale = $window.displayScale
    if ($null -eq $scale -or
        [Math]::Abs([double]$scale.requestedUiScale - $ExpectedUiScale) -gt .0001 -or
        [Math]::Abs([double]$scale.requestedFontScale - $ExpectedFontScale) -gt .0001 -or
        [Math]::Abs([double]$scale.actualRootScaleX - $ExpectedUiScale) -gt .0001 -or
        [Math]::Abs([double]$scale.actualRootScaleY - $ExpectedUiScale) -gt .0001 -or
        [Math]::Abs([double]$scale.actualFontScale - $ExpectedFontScale) -gt .0001 -or
        -not [bool]$scale.usesLayoutTransform -or
        [double]$scale.screenScaling -le 0 -or
        [double]$window.screenScaling -le 0 -or
        [Math]::Abs([double]$scale.screenScaling - [double]$window.screenScaling) -gt .0001 -or
        [double]$window.screenWidthPixels -le 0 -or
        [double]$window.screenHeightPixels -le 0 -or
        [double]$window.workAreaWidthPixels -le 0 -or
        [double]$window.workAreaHeightPixels -le 0 -or
        [double]$scale.effectiveScreenWidth -le 0 -or
        [double]$scale.effectiveScreenHeight -le 0 -or
        [double]$scale.effectiveWorkAreaWidth -le 0 -or
        [double]$scale.effectiveWorkAreaHeight -le 0 -or
        -not [bool]$scale.displayScaleInitialized -or
        -not [bool]$scale.settingsFileExists -or
        -not [bool]$scale.settingsIsolatedFromWpf -or
        $null -eq $scale.fontDiagnostics -or
        [double]$scale.fontDiagnostics.windowFontSize -le 0 -or
        [int]$scale.fontDiagnostics.scannedObjectCount -le 0 -or
        [int]$scale.fontDiagnostics.candidateCount -le 0 -or
        [int]$scale.fontDiagnostics.scaledElementCount -le 0 -or
        $null -eq $scale.fontDiagnostics.inheritedOrDefaultSkippedCount -or
        [int]$scale.fontDiagnostics.inheritedOrDefaultSkippedCount -lt 0 -or
        [int]$scale.fontDiagnostics.capturedBaselineCount -le 0) {
        throw "$Name did not expose the exact persisted $ExpectedUiScale/$ExpectedFontScale real layout/font-scale diagnostics."
    }

    $expectedLocalRoot = [IO.Path]::GetFullPath($ExpectedLocalDataRoot)
    $actualLocalRoot = [IO.Path]::GetFullPath([string]$scale.localDataRoot)
    $expectedSettings = [IO.Path]::GetFullPath($ExpectedSettingsPath)
    $actualSettings = [IO.Path]::GetFullPath([string]$scale.settingsPath)
    $wpfViewSettings = [IO.Path]::GetFullPath([string]$scale.wpfViewSettingsPath)
    if (-not $actualLocalRoot.Equals($expectedLocalRoot, [StringComparison]::OrdinalIgnoreCase) -or
        -not $actualSettings.Equals($expectedSettings, [StringComparison]::OrdinalIgnoreCase) -or
        $actualSettings.Equals($wpfViewSettings, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Name did not isolate display-scale settings under the requested Avalonia LocalDataRoot."
    }

    $expectedEffectiveScreenWidth = [double]$window.screenWidthPixels / [double]$window.screenScaling
    $expectedEffectiveScreenHeight = [double]$window.screenHeightPixels / [double]$window.screenScaling
    $expectedEffectiveWorkAreaWidth = [double]$window.workAreaWidthPixels / [double]$window.screenScaling
    $expectedEffectiveWorkAreaHeight = [double]$window.workAreaHeightPixels / [double]$window.screenScaling
    $expectedMinimumWidth = [Math]::Min(1080 * $ExpectedUiScale, $expectedEffectiveWorkAreaWidth)
    $expectedMinimumHeight = [Math]::Min(680 * $ExpectedUiScale, $expectedEffectiveWorkAreaHeight)
    if ([Math]::Abs([double]$window.effectiveScreenWidthDip - $expectedEffectiveScreenWidth) -gt .01 -or
        [Math]::Abs([double]$window.effectiveScreenHeightDip - $expectedEffectiveScreenHeight) -gt .01 -or
        [Math]::Abs([double]$window.effectiveWorkAreaWidthDip - $expectedEffectiveWorkAreaWidth) -gt .01 -or
        [Math]::Abs([double]$window.effectiveWorkAreaHeightDip - $expectedEffectiveWorkAreaHeight) -gt .01 -or
        [Math]::Abs([double]$scale.effectiveScreenWidth - $expectedEffectiveScreenWidth) -gt .01 -or
        [Math]::Abs([double]$scale.effectiveScreenHeight - $expectedEffectiveScreenHeight) -gt .01 -or
        [Math]::Abs([double]$scale.effectiveWorkAreaWidth - $expectedEffectiveWorkAreaWidth) -gt .01 -or
        [Math]::Abs([double]$scale.effectiveWorkAreaHeight - $expectedEffectiveWorkAreaHeight) -gt .01 -or
        [Math]::Abs([double]$scale.windowMinimumWidth - $expectedMinimumWidth) -gt .01 -or
        [Math]::Abs([double]$scale.windowMinimumHeight - $expectedMinimumHeight) -gt .01 -or
        [Math]::Abs([double]$window.minimumWidthDip - [double]$scale.windowMinimumWidth) -gt .01 -or
        [Math]::Abs([double]$window.minimumHeightDip - [double]$scale.windowMinimumHeight) -gt .01) {
        throw "$Name did not retain physical-pixel to effective-DIP conversion and scaled window minimums."
    }

    if ($ExpectStartupBounds) {
        $expectedStartupWidth = [Math]::Min(
            1320 * $ExpectedUiScale,
            $expectedEffectiveWorkAreaWidth * .94)
        $expectedStartupHeight = [Math]::Min(
            800 * $ExpectedUiScale,
            $expectedEffectiveWorkAreaHeight * .94)
        # Avalonia converts the requested DIP bounds through physical pixels,
        # so permit one DIP for platform rounding at non-integral DPI scales.
        if ([Math]::Abs([double]$window.clientWidthDip - $expectedStartupWidth) -gt 1 -or
            [Math]::Abs([double]$window.clientHeightDip - $expectedStartupHeight) -gt 1) {
            throw "$Name did not retain WPF's scaled 1320x800 startup bounds and 94% work-area cap."
        }

        $expectedPositionX = [double]$window.workAreaXPixels + [Math]::Max(
            0,
            ([double]$window.workAreaWidthPixels -
                [double]$window.clientWidthDip * [double]$window.screenScaling) / 2)
        $expectedPositionY = [double]$window.workAreaYPixels + [Math]::Max(
            0,
            ([double]$window.workAreaHeightPixels -
                [double]$window.clientHeightDip * [double]$window.screenScaling) / 2)
        if ([Math]::Abs([double]$window.positionXPixels - $expectedPositionX) -gt 2 -or
            [Math]::Abs([double]$window.positionYPixels - $expectedPositionY) -gt 2) {
            throw "$Name did not retain centered physical startup bounds inside the primary work area."
        }
    }
}

$displayScaleSettings = Get-RequiredJson $displayScaleSettingsPath
if ([int]$displayScaleSettings.SchemaVersion -ne 1 -or
    [Math]::Abs([double]$displayScaleSettings.UiScale - 1.35) -gt .0001 -or
    [Math]::Abs([double]$displayScaleSettings.FontScale - 1.25) -gt .0001 -or
    -not [bool]$displayScaleSettings.DisplayScaleInitialized) {
    throw "The display-scale GUI exercise did not persist the exact isolated schema/value tuple."
}
$displayScaleCorruptSettings = Get-RequiredJson $displayScaleCorruptSettingsPath
if ([int]$displayScaleCorruptSettings.SchemaVersion -ne 1 -or
    [Math]::Abs([double]$displayScaleCorruptSettings.UiScale - 1) -gt .0001 -or
    [Math]::Abs([double]$displayScaleCorruptSettings.FontScale - 1) -gt .0001 -or
    -not [bool]$displayScaleCorruptSettings.DisplayScaleInitialized) {
    throw "The corrupt display-scale recovery did not fail closed and atomically persist schema 1 / UI 1 / font 1 / initialized true."
}
$requiredDisplayScaleControlIds = @(
    "Inspector.SettingsTab",
    "Settings.UiScale",
    "Settings.FontScale",
    "Settings.UiScaleValue",
    "Settings.FontScaleValue")
$displayScaleCaptureCases = @(
    [pscustomobject]@{
        name = "change-and-persist"
        capture = $displayScaleCapture.capture
        uiPercent = 135
        fontPercent = 125
    },
    [pscustomobject]@{
        name = "fresh-process-reopen"
        capture = $displayScaleReopenCapture.capture
        uiPercent = 135
        fontPercent = 125
    },
    [pscustomobject]@{
        name = "corrupt-settings-recovery"
        capture = $displayScaleCorruptCapture.capture
        uiPercent = 100
        fontPercent = 100
    })
foreach ($captureCaseSpec in $displayScaleCaptureCases) {
    $captureCase = $captureCaseSpec.capture
    foreach ($automationId in $requiredDisplayScaleControlIds) {
        $property = $captureCase.displayScaleControls.PSObject.Properties[$automationId]
        if ($null -eq $property -or
            [string]$property.Value.automationId -cne $automationId -or
            -not [bool]$property.Value.isEnabled -or
            [bool]$property.Value.isOffscreen -or
            [double]$property.Value.bounds.width -le 1 -or
            [double]$property.Value.bounds.height -le 1) {
            throw "Display-scale GUI capture '$($captureCaseSpec.name)' did not expose enabled on-screen control '$automationId'."
        }
    }
    if (-not [bool]$captureCase.focusDisplayScale -or
        [Math]::Abs([double]$captureCase.displayScaleRequested.uiPercent - $captureCaseSpec.uiPercent) -gt .001 -or
        [Math]::Abs([double]$captureCase.displayScaleRequested.fontPercent - $captureCaseSpec.fontPercent) -gt .001 -or
        [Math]::Abs([double]$captureCase.displayScaleActual.uiPercent - $captureCaseSpec.uiPercent) -gt .001 -or
        [Math]::Abs([double]$captureCase.displayScaleActual.fontPercent - $captureCaseSpec.fontPercent) -gt .001 -or
        [string]$captureCase.displayScaleActual.uiValueText -notmatch ([string]$captureCaseSpec.uiPercent) -or
        [string]$captureCase.displayScaleActual.fontValueText -notmatch ([string]$captureCaseSpec.fontPercent) -or
        $null -eq $captureCase.displayScaleAutomationFallbackUsed) {
        throw "Display-scale GUI capture '$($captureCaseSpec.name)' did not retain exact requested/actual UIA values and value text."
    }
}
$displayScaleIsolationCases = @(
    [pscustomobject]@{
        name = "change-and-persist"
        capture = $displayScaleCapture.capture
        localDataRoot = $displayScaleLocalDataRoot
        settingsPath = $displayScaleSettingsPath
        settingsSha256 = $displayScaleSettingsSha256AfterSubmit
        existingRootAllowed = $false
    },
    [pscustomobject]@{
        name = "fresh-process-reopen"
        capture = $displayScaleReopenCapture.capture
        localDataRoot = $displayScaleLocalDataRoot
        settingsPath = $displayScaleSettingsPath
        settingsSha256 = $displayScaleSettingsSha256AfterReopen
        existingRootAllowed = $true
    },
    [pscustomobject]@{
        name = "corrupt-settings-recovery"
        capture = $displayScaleCorruptCapture.capture
        localDataRoot = $displayScaleCorruptLocalDataRoot
        settingsPath = $displayScaleCorruptSettingsPath
        settingsSha256 = $displayScaleCorruptSettingsSha256After
        existingRootAllowed = $true
    })
foreach ($isolationCase in $displayScaleIsolationCases) {
    $isolation = $isolationCase.capture.displayScaleIsolation
    if ($null -eq $isolation -or
        -not [bool]$isolation.settingsExists -or
        [bool]$isolation.existingLocalDataRootExplicitlyAllowed -ne
            [bool]$isolationCase.existingRootAllowed -or
        -not (Test-PathEvidenceEqual `
            -Left $isolation.localDataRoot `
            -Right $isolationCase.localDataRoot) -or
        -not (Test-PathEvidenceEqual `
            -Left $isolation.settingsPath `
            -Right $isolationCase.settingsPath) -or
        [string]$isolation.settingsSha256 -cne [string]$isolationCase.settingsSha256) {
        throw "Display-scale GUI capture '$($isolationCase.name)' did not retain its exact isolated settings path/hash."
    }
}
if (-not [bool]$displayScaleCapture.capture.displayScaleExercised -or
    -not [bool]$displayScaleCapture.capture.interactionCapturedAfterActions -or
    $null -eq $displayScaleCapture.capture.interactionActionsCompletedAtUtc -or
    [int]$displayScaleCapture.capture.displayScaleDebounceWaitMilliseconds -le 600 -or
    -not [bool]$displayScaleCapture.capture.displayScalePointer.uiScale.pointerClickAttempted -or
    -not [bool]$displayScaleCapture.capture.displayScalePointer.fontScale.pointerClickAttempted -or
    [bool]$displayScaleReopenCapture.capture.displayScaleExercised -or
    -not [bool]$displayScaleReopenCapture.capture.displayScaleIsolation.existingLocalDataRootExplicitlyAllowed -or
    [bool]$displayScaleCorruptCapture.capture.displayScaleExercised -or
    -not [bool]$displayScaleCorruptCapture.capture.displayScaleIsolation.existingLocalDataRootExplicitlyAllowed -or
    $displayScaleCapture.capture.processId -eq $displayScaleReopenCapture.capture.processId -or
    $displayScaleCapture.capture.processId -eq $displayScaleCorruptCapture.capture.processId -or
    $displayScaleReopenCapture.capture.processId -eq $displayScaleCorruptCapture.capture.processId) {
    throw "Display-scale GUI capture did not prove debounced real UIA/pointer change, fresh-process read-only reopen, and independent corrupt-root recovery."
}
$displayScaleActionCompleted = [DateTimeOffset]::Parse(
    [string]$displayScaleCapture.capture.interactionActionsCompletedAtUtc,
    [Globalization.CultureInfo]::InvariantCulture)
$displayScaleCapturedAt = [DateTimeOffset]::Parse(
    [string]$displayScaleInteractionGui.generatedAtUtc,
    [Globalization.CultureInfo]::InvariantCulture)
if ($displayScaleCapturedAt -lt $displayScaleActionCompleted) {
    throw "Display-scale interaction evidence was captured before the debounced UI actions completed."
}
Assert-DisplayScaleRuntime `
    -Name "Submitted display-scale runtime" `
    -Runtime $displayScaleInteractionGui `
    -ExpectedLocalDataRoot $displayScaleLocalDataRoot `
    -ExpectedSettingsPath $displayScaleSettingsPath `
    -ExpectedUiScale 1.35 `
    -ExpectedFontScale 1.25
Assert-DisplayScaleRuntime `
    -Name "Fresh-process display-scale runtime" `
    -Runtime $displayScaleReopenGui `
    -ExpectedLocalDataRoot $displayScaleLocalDataRoot `
    -ExpectedSettingsPath $displayScaleSettingsPath `
    -ExpectedUiScale 1.35 `
    -ExpectedFontScale 1.25 `
    -ExpectStartupBounds
Assert-DisplayScaleRuntime `
    -Name "Corrupt-settings recovered display-scale runtime" `
    -Runtime $displayScaleCorruptGui `
    -ExpectedLocalDataRoot $displayScaleCorruptLocalDataRoot `
    -ExpectedSettingsPath $displayScaleCorruptSettingsPath `
    -ExpectedUiScale 1 `
    -ExpectedFontScale 1 `
    -ExpectStartupBounds
if ($displayScaleInteractionGui.timeline.sessionChangeSerial -ne 0 -or
    $displayScaleReopenGui.timeline.sessionChangeSerial -ne 0 -or
    $displayScaleCorruptGui.timeline.sessionChangeSerial -ne 0 -or
    $displayScaleInteractionGui.timeline.sessionIsDirty -or
    $displayScaleReopenGui.timeline.sessionIsDirty -or
    $displayScaleCorruptGui.timeline.sessionIsDirty -or
    $displayScaleInteractionGui.chart.structure.sha256 -ne $displayScaleReopenGui.chart.structure.sha256 -or
    $displayScaleInteractionGui.chart.structure.sha256 -ne $displayScaleCorruptGui.chart.structure.sha256) {
    throw "Display-scale change/reopen/corrupt-recovery mutated the isolated chart document."
}

function Assert-AudioPanelRuntimeCommon {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Runtime,
        [Parameter(Mandatory = $true)][string]$ExpectedSettingsPath
    )

    $panels = $Runtime.audio.panels
    if ($null -eq $panels) {
        throw "$Name is missing audio.panels runtime evidence."
    }
    $actualSettingsPath = [IO.Path]::GetFullPath([string]$panels.settingsPath)
    $expectedSettingsPath = [IO.Path]::GetFullPath($ExpectedSettingsPath)
    $wpfViewSettingsPath = [IO.Path]::GetFullPath([string]$panels.wpfViewSettingsPath)
    if (-not $actualSettingsPath.Equals($expectedSettingsPath, [StringComparison]::OrdinalIgnoreCase) -or
        $actualSettingsPath.Equals($wpfViewSettingsPath, [StringComparison]::OrdinalIgnoreCase) -or
        -not [bool]$panels.settingsFileExists -or
        -not [bool]$panels.settingsIsolatedFromWpf -or
        [int]$panels.sideCustomSurfaceCount -ne 2 -or
        [int]$panels.perSampleAvaloniaControlCount -ne 0 -or
        -not [bool]$panels.visibleAreaClipping -or
        -not [bool]$Runtime.audio.uiIntegrated -or
        -not [bool]$Runtime.audio.sourceExists -or
        [double]$Runtime.audio.durationMilliseconds -le 0 -or
        $Runtime.audio.lastErrorType -or
        [string]$Runtime.audio.visualization.state -cne "Ready" -or
        [int]$Runtime.audio.visualization.waveformCount -le 0 -or
        [int]$Runtime.audio.visualization.spectrogramFrameCount -le 0 -or
        [int]$Runtime.audio.visualization.spectrogramFrequencyBands -ne 96 -or
        $Runtime.audio.visualization.lastErrorType) {
        throw "$Name did not prove isolated settings, two clipped custom surfaces, zero per-sample Controls and a ready real-audio visualization."
    }
    foreach ($panel in $panels.waveform, $panels.spectrogram) {
        if ([string]::IsNullOrWhiteSpace([string]$panel.kind) -or
            [string]::IsNullOrWhiteSpace([string]$panel.mode) -or
            $null -eq $panel.actualWindowXDip -or $null -eq $panel.actualWindowYDip -or
            [double]$panel.actualWidthDip -le 1 -or [double]$panel.actualHeightDip -le 1 -or
            [double]$panel.rememberedWidthDip -le 1 -or
            -not [bool]$panel.surfaceClipToBounds -or
            $null -eq $panel.diagnostics -or
            -not [bool]$panel.diagnostics.visualizationAttached) {
            throw "$Name did not expose finite actual Window geometry and attached diagnostics for both panels."
        }
    }
    return $panels
}

function Assert-AudioPanelDefaultRuntime {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Runtime,
        [Parameter(Mandatory = $true)][string]$ExpectedSettingsPath
    )

    $panels = Assert-AudioPanelRuntimeCommon `
        -Name $Name `
        -Runtime $Runtime `
        -ExpectedSettingsPath $ExpectedSettingsPath
    $wave = $panels.waveform
    $spectrum = $panels.spectrogram
    if ([string]$wave.kind -cne "Waveform" -or [string]$wave.mode -cne "Side" -or
        [bool]$wave.collapsed -or -not [bool]$wave.docked -or
        [Math]::Abs([double]$wave.rememberedXDip - 4000) -gt .001 -or
        [Math]::Abs([double]$wave.rememberedWidthDip - 92) -gt .001 -or
        [double]$wave.actualWindowXDip -ge [double]$Runtime.window.clientWidthDip -or
        -not [bool]$wave.surfaceVisible -or [bool]$wave.backgroundEnabled -or
        -not [bool]$wave.diagnostics.sceneReady -or [bool]$wave.diagnostics.buildPending -or
        [int]$wave.diagnostics.waveformRows -le 0 -or
        [string]$spectrum.kind -cne "Spectrogram" -or [string]$spectrum.mode -cne "Side" -or
        -not [bool]$spectrum.collapsed -or -not [bool]$spectrum.docked -or
        [Math]::Abs([double]$spectrum.rememberedXDip - 4000) -gt .001 -or
        [Math]::Abs([double]$spectrum.rememberedWidthDip - 132) -gt .001 -or
        [double]$spectrum.actualWindowXDip -ge [double]$Runtime.window.clientWidthDip -or
        [bool]$spectrum.surfaceVisible -or [bool]$spectrum.backgroundEnabled) {
        throw "$Name did not retain WPF's default expanded Side Waveform and collapsed Side Spectrogram state with a ready waveform scene."
    }
}

function Assert-AudioPanelFinalRuntime {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Runtime,
        [Parameter(Mandatory = $true)][string]$ExpectedSettingsPath
    )

    $panels = Assert-AudioPanelRuntimeCommon `
        -Name $Name `
        -Runtime $Runtime `
        -ExpectedSettingsPath $ExpectedSettingsPath
    $wave = $panels.waveform
    $spectrum = $panels.spectrogram
    $background = $Runtime.timeline.audioBackground
    if ([string]$wave.kind -cne "Waveform" -or [string]$wave.mode -cne "Background" -or
        [bool]$wave.collapsed -or [bool]$wave.docked -or [bool]$wave.surfaceVisible -or
        -not [bool]$wave.backgroundEnabled -or
        [string]$spectrum.kind -cne "Spectrogram" -or [string]$spectrum.mode -cne "Side" -or
        [bool]$spectrum.collapsed -or -not [bool]$spectrum.docked -or
        [Math]::Abs([double]$spectrum.rememberedXDip - 4000) -gt .001 -or
        -not [bool]$spectrum.surfaceVisible -or [bool]$spectrum.backgroundEnabled -or
        -not [bool]$spectrum.diagnostics.sceneReady -or
        [bool]$spectrum.diagnostics.buildPending -or
        [int]$spectrum.diagnostics.spectrogramWidth -ne 96 -or
        [int]$spectrum.diagnostics.spectrogramRows -le 0 -or
        -not [bool]$spectrum.diagnostics.spectrogramBitmapReady -or
        -not [bool]$background.visualizationAttached -or
        -not [bool]$background.waveformVisible -or [bool]$background.spectrogramVisible -or
        -not [bool]$background.sceneReady -or [bool]$background.buildPending -or
        [int]$background.waveformRows -le 0) {
        throw "$Name did not retain a ready Background Waveform plus expanded ready Side Spectrogram."
    }
    return $panels
}

$audioPanelDefaultSettings = Get-RequiredJson $audioPanelDefaultSettingsPath
$audioPanelSettings = Get-RequiredJson $audioPanelSettingsPath
if ([int]$audioPanelDefaultSettings.SchemaVersion -ne 1 -or
    [string]$audioPanelDefaultSettings.Waveform.Mode -cne "Side" -or
    [bool]$audioPanelDefaultSettings.Waveform.Collapsed -or
    -not [bool]$audioPanelDefaultSettings.Waveform.Docked -or
    [Math]::Abs([double]$audioPanelDefaultSettings.Waveform.X - 4000) -gt .001 -or
    [Math]::Abs([double]$audioPanelDefaultSettings.Waveform.Width - 92) -gt .001 -or
    [string]$audioPanelDefaultSettings.Spectrogram.Mode -cne "Side" -or
    -not [bool]$audioPanelDefaultSettings.Spectrogram.Collapsed -or
    -not [bool]$audioPanelDefaultSettings.Spectrogram.Docked -or
    [Math]::Abs([double]$audioPanelDefaultSettings.Spectrogram.X - 4000) -gt .001 -or
    [Math]::Abs([double]$audioPanelDefaultSettings.Spectrogram.Width - 132) -gt .001) {
    throw "The focused default audio-panel process did not persist the exact WPF-compatible schema 1 state."
}
if ([int]$audioPanelSettings.SchemaVersion -ne 1 -or
    [string]$audioPanelSettings.Waveform.Mode -cne "Background" -or
    [bool]$audioPanelSettings.Waveform.Collapsed -or
    [bool]$audioPanelSettings.Waveform.Docked -or
    [Math]::Abs([double]$audioPanelSettings.Waveform.Width - 92) -gt .001 -or
    [Math]::Abs([double]$audioPanelSettings.Waveform.Y) -lt 5 -or
    [string]$audioPanelSettings.Spectrogram.Mode -cne "Side" -or
    [bool]$audioPanelSettings.Spectrogram.Collapsed -or
    -not [bool]$audioPanelSettings.Spectrogram.Docked -or
    [Math]::Abs([double]$audioPanelSettings.Spectrogram.X - 4000) -gt .001 -or
    [Math]::Abs([double]$audioPanelSettings.Spectrogram.Width - 132) -gt .001) {
    throw "The exercised audio-panel process did not persist Background Waveform, expanded Side Spectrogram and the free toolbar drag."
}

Assert-AudioPanelDefaultRuntime `
    -Name "Independent default audio-panel runtime" `
    -Runtime $audioPanelDefaultGui `
    -ExpectedSettingsPath $audioPanelDefaultSettingsPath
Assert-AudioPanelDefaultRuntime `
    -Name "Exercise primary audio-panel runtime" `
    -Runtime $audioPanelGui `
    -ExpectedSettingsPath $audioPanelSettingsPath
$audioPanelInteractionPanels = Assert-AudioPanelFinalRuntime `
    -Name "Exercise interaction audio-panel runtime" `
    -Runtime $audioPanelInteractionGui `
    -ExpectedSettingsPath $audioPanelSettingsPath
$audioPanelReopenPanels = Assert-AudioPanelFinalRuntime `
    -Name "Fresh-process reopened audio-panel runtime" `
    -Runtime $audioPanelReopenGui `
    -ExpectedSettingsPath $audioPanelSettingsPath
foreach ($propertyName in "rememberedXDip", "rememberedYDip", "rememberedWidthDip") {
    if ([Math]::Abs(
            [double]$audioPanelInteractionPanels.waveform.$propertyName -
            [double]$audioPanelReopenPanels.waveform.$propertyName) -gt .001 -or
        [Math]::Abs(
            [double]$audioPanelInteractionPanels.spectrogram.$propertyName -
            [double]$audioPanelReopenPanels.spectrogram.$propertyName) -gt .001) {
        throw "The fresh audio-panel process did not restore persisted $propertyName exactly."
    }
}

$audioPanelCaptureCases = @(
    [pscustomobject]@{
        name = "independent-default"
        capture = $audioPanelDefaultCapture.capture
        settingsPath = $audioPanelDefaultSettingsPath
        settingsSha256 = $audioPanelDefaultSettingsSha256
        exercised = $false
    },
    [pscustomobject]@{
        name = "exercise"
        capture = $audioPanelCapture.capture
        settingsPath = $audioPanelSettingsPath
        settingsSha256 = $audioPanelSettingsSha256AfterInteraction
        exercised = $true
    },
    [pscustomobject]@{
        name = "fresh-reopen"
        capture = $audioPanelReopenCapture.capture
        settingsPath = $audioPanelSettingsPath
        settingsSha256 = $audioPanelSettingsSha256AfterReopen
        exercised = $false
    })
foreach ($audioPanelCaptureCase in $audioPanelCaptureCases) {
    $capture = $audioPanelCaptureCase.capture
    if (-not [bool]$capture.focusAudioPanels -or
        [bool]$capture.audioPanelsExercised -ne [bool]$audioPanelCaptureCase.exercised -or
        -not [bool]$capture.audioPanelSettings.exists -or
        -not (Test-PathEvidenceEqual `
            -Left $capture.audioPanelSettings.path `
            -Right $audioPanelCaptureCase.settingsPath) -or
        [string]$capture.audioPanelSettings.sha256 -cne
            [string]$audioPanelCaptureCase.settingsSha256 -or
        [string]$capture.audioPanelSettingsSha256 -cne
            [string]$audioPanelCaptureCase.settingsSha256 -or
        $null -eq $capture.audioPanelRuntime) {
        throw "Audio-panel capture '$($audioPanelCaptureCase.name)' did not report the exact isolated settings path/hash and runtime."
    }
}
$audioPanelActions = @($audioPanelCapture.capture.audioPanelActions)
$audioPanelInitialUiState = $audioPanelCapture.capture.audioPanelStateInitial
$audioPanelFinalUiState = $audioPanelCapture.capture.audioPanelStateFinal
if (-not [bool]$audioPanelCapture.capture.interactionCapturedAfterActions -or
    $null -eq $audioPanelCapture.capture.interactionActionsCompletedAtUtc -or
    -not [bool]$audioPanelCapture.capture.audioPanelsExercised -or
    $audioPanelActions.Count -ne 3 -or
    [string]$audioPanelInitialUiState.waveform.mode -cne "Side" -or
    [bool]$audioPanelInitialUiState.waveform.collapsed -or
    [string]$audioPanelInitialUiState.spectrogram.mode -cne "Side" -or
    -not [bool]$audioPanelInitialUiState.spectrogram.collapsed -or
    [string]$audioPanelFinalUiState.waveform.mode -cne "Background" -or
    [bool]$audioPanelFinalUiState.waveform.collapsed -or
    [string]$audioPanelFinalUiState.spectrogram.mode -cne "Side" -or
    [bool]$audioPanelFinalUiState.spectrogram.collapsed -or
    (@($audioPanelActions | ForEach-Object { [string]$_.action }) -join ',') -cne
        "waveform-side-to-background,spectrogram-collapsed-to-expanded,waveform-background-toolbar-drag" -or
    @($audioPanelActions | Where-Object {
        -not [bool]$_.physicalPointerAttempted -or -not [bool]$_.transitionObserved
    }).Count -ne 0 -or
    [bool]$audioPanelCapture.capture.audioPanelDragAutomationFallbackUsed -or
    $audioPanelDefaultCapture.capture.processId -eq $audioPanelCapture.capture.processId -or
    $audioPanelDefaultCapture.capture.processId -eq $audioPanelReopenCapture.capture.processId -or
    $audioPanelCapture.capture.processId -eq $audioPanelReopenCapture.capture.processId) {
    throw "The audio-panel GUI chain did not prove three real pointer actions and three distinct Windows processes."
}
$audioPanelActionCompleted = ConvertTo-EvidenceDateTimeOffset `
    $audioPanelCapture.capture.interactionActionsCompletedAtUtc
$audioPanelInteractionCapturedAt = ConvertTo-EvidenceDateTimeOffset `
    $audioPanelInteractionGui.generatedAtUtc
if ($audioPanelInteractionCapturedAt -lt $audioPanelActionCompleted -or
    $audioPanelDefaultGui.timeline.sessionChangeSerial -ne 0 -or
    $audioPanelGui.timeline.sessionChangeSerial -ne 0 -or
    $audioPanelInteractionGui.timeline.sessionChangeSerial -ne 0 -or
    $audioPanelReopenGui.timeline.sessionChangeSerial -ne 0 -or
    $audioPanelDefaultGui.timeline.sessionIsDirty -or
    $audioPanelGui.timeline.sessionIsDirty -or
    $audioPanelInteractionGui.timeline.sessionIsDirty -or
    $audioPanelReopenGui.timeline.sessionIsDirty -or
    $audioPanelGui.chart.structure.sha256 -ne $audioPanelInteractionGui.chart.structure.sha256 -or
    $audioPanelInteractionGui.chart.structure.sha256 -ne $audioPanelReopenGui.chart.structure.sha256) {
    throw "The audio-panel interaction evidence was early or the non-document UI workflow mutated the chart."
}

if (-not $realCapture.capture.focusHoldTail -or
    -not $realCapture.capture.holdTailResizeExercised -or
    -not $realGui.timeline.selectedHoldTail -or
    -not $realInteractionGui.timeline.selectedHoldTail -or
    $realGui.timeline.selectedHoldTail.noteId -ne $realInteractionGui.timeline.selectedHoldTail.noteId -or
    $realGui.timeline.selectedHoldTail.endBeat.value -eq $realInteractionGui.timeline.selectedHoldTail.endBeat.value -or
    $realInteractionGui.timeline.sessionChangeSerial -le $realGui.timeline.sessionChangeSerial) {
    throw "The real MC GUI probe did not complete one captured-pointer LN-tail resize."
}
$visualizedGuiEvidence = @(
    $realGui,
    $realInteractionGui,
    $transformGui,
    $transformInteractionGui,
    $propertyGui,
    $propertyInteractionGui,
    $propertyReopenGui,
    $groupAssignGui,
    $groupSavedGui,
    $groupVisibilityGui,
    $groupHiddenGui,
    $groupPlacementGui,
    $groupPlacedGui,
    $osuGui,
    $osuInteractionGui
)
foreach ($guiEvidence in $visualizedGuiEvidence) {
    if ($guiEvidence.audio.visualization.state -ne "Ready" -or
        $guiEvidence.audio.visualization.waveformCount -le 0 -or
        $guiEvidence.audio.visualization.waveformBucketMilliseconds -le 0 -or
        $guiEvidence.audio.visualization.spectrogramFrameCount -le 0 -or
        $guiEvidence.audio.visualization.spectrogramFrequencyBands -ne 96 -or
        $guiEvidence.audio.visualization.lastErrorType -or
        -not $guiEvidence.timeline.audioBackground.visualizationAttached -or
        -not $guiEvidence.timeline.audioBackground.waveformVisible -or
        -not $guiEvidence.timeline.audioBackground.spectrogramVisible -or
        -not $guiEvidence.timeline.audioBackground.sceneReady -or
        $guiEvidence.timeline.audioBackground.buildPending -or
        $guiEvidence.timeline.audioBackground.waveformRows -le 0 -or
        $guiEvidence.timeline.audioBackground.spectrogramWidth -ne 96 -or
        $guiEvidence.timeline.audioBackground.spectrogramRows -le 0 -or
        -not $guiEvidence.timeline.audioBackground.spectrogramBitmapReady) {
        throw "A real-chart GUI probe did not render both waveform and spectrogram backgrounds."
    }
}
if (-not $transformCapture.capture.focusHoldTail -or
    -not $transformCapture.capture.longToTapExercised -or
    @($transformGui.timeline.selectedNotes).Count -ne 1 -or
    @($transformInteractionGui.timeline.selectedNotes).Count -ne 2 -or
    -not $transformGui.timeline.selectedHoldTail -or
    $transformInteractionGui.timeline.selectedHoldTail -or
    $transformInteractionGui.timeline.sessionChangeSerial -ne
        ($transformGui.timeline.sessionChangeSerial + 1) -or
    $transformGui.timeline.sessionIsDirty -or
    -not $transformInteractionGui.timeline.sessionIsDirty -or
    $transformInteractionGui.chart.structure.noteCount -ne
        ($transformGui.chart.structure.noteCount + 1) -or
    $transformInteractionGui.chart.structure.longNoteCount -ne
        ($transformGui.chart.structure.longNoteCount - 1)) {
    throw "The real MC GUI probe did not complete one LN-to-Tap IncludeTail transform."
}
if (-not $propertyCapture.capture.focusNoteProperty -or
    -not $propertyCapture.capture.notePropertyExercised -or
    -not $propertyCapture.capture.notePropertySaved -or
    -not $propertyCapture.capture.notePropertySubmitted.derivedFromSelection -or
    @($propertyGui.timeline.selectedNotes).Count -ne 1 -or
    @($propertyInteractionGui.timeline.selectedNotes).Count -ne 1 -or
    $propertyGui.timeline.selectedNotes[0].endBeat -or
    $propertyInteractionGui.timeline.sessionChangeSerial -ne
        ($propertyGui.timeline.sessionChangeSerial + 1) -or
    $propertyGui.timeline.sessionIsDirty -or
    $propertyInteractionGui.timeline.sessionIsDirty -or
    $propertyInteractionGui.chart.structure.sha256 -eq $propertyGui.chart.structure.sha256 -or
    $propertyReopenGui.chart.structure.sha256 -ne $propertyInteractionGui.chart.structure.sha256 -or
    $propertyReopenGui.timeline.sessionIsDirty -or
    @($propertyReopenGui.timeline.selectedNotes).Count -ne 1) {
    throw "The real MC Note-property GUI probe did not apply, save and reopen one atomic property edit."
}
$propertyBeforeNote = @($propertyGui.timeline.selectedNotes)[0]
$propertyAfterNote = @($propertyInteractionGui.timeline.selectedNotes)[0]
$propertyExpectedBeatDenominator = [int]$propertyBeforeNote.beat.denominator * 2
$propertyExpectedBeatNumerator = [int]$propertyBeforeNote.beat.numerator * 2
$propertyExpectedEndDenominator = [int]$propertyBeforeNote.beat.denominator * 100
$propertyExpectedEndNumerator = [int]$propertyBeforeNote.beat.numerator * 100 + 1
$propertyReopenNote = @($propertyReopenGui.timeline.selectedNotes)[0]
if ($propertyAfterNote.noteId -ne $propertyBeforeNote.noteId -or
    $propertyAfterNote.beat.bar -ne $propertyBeforeNote.beat.bar -or
    $propertyAfterNote.beat.numerator -ne $propertyExpectedBeatNumerator -or
    $propertyAfterNote.beat.denominator -ne $propertyExpectedBeatDenominator -or
    $propertyAfterNote.endBeat.bar -ne $propertyBeforeNote.beat.bar -or
    $propertyAfterNote.endBeat.numerator -ne $propertyExpectedEndNumerator -or
    $propertyAfterNote.endBeat.denominator -ne $propertyExpectedEndDenominator -or
    $propertyAfterNote.lane -ne $propertyBeforeNote.lane -or
    $propertyAfterNote.volume -ne 73 -or
    $propertyAfterNote.group -ne 7 -or
    $propertyAfterNote.sound -ne $propertyBeforeNote.sound -or
    $propertyReopenNote.beat.bar -ne $propertyAfterNote.beat.bar -or
    $propertyReopenNote.beat.numerator -ne $propertyAfterNote.beat.numerator -or
    $propertyReopenNote.beat.denominator -ne $propertyAfterNote.beat.denominator -or
    $propertyReopenNote.endBeat.bar -ne $propertyAfterNote.endBeat.bar -or
    $propertyReopenNote.endBeat.numerator -ne $propertyAfterNote.endBeat.numerator -or
    $propertyReopenNote.endBeat.denominator -ne $propertyAfterNote.endBeat.denominator -or
    $propertyReopenNote.lane -ne $propertyAfterNote.lane -or
    $propertyReopenNote.volume -ne $propertyAfterNote.volume -or
    $propertyReopenNote.group -ne $propertyAfterNote.group -or
    $propertyReopenNote.sound -ne $propertyAfterNote.sound) {
    throw "The real MC Note-property edit did not retain the exact authored Beat and requested Note fields."
}
$groupBeforeNote = @($groupAssignGui.timeline.selectedNotes)[0]
$groupSavedNote = @($groupSavedGui.timeline.selectedNotes)[0]
$groupVisibilityNote = @($groupVisibilityGui.timeline.selectedNotes)[0]
$groupPlacementFocusNote = @($groupPlacementGui.timeline.selectedNotes)[0]
if (-not $groupAssignCapture.capture.focusGroup -or
    -not $groupAssignCapture.capture.groupAssignExercised -or
    -not $groupAssignCapture.capture.groupAssignSaved -or
    -not $groupAssignCapture.capture.interactionCapturedAfterActions -or
    [string]::IsNullOrWhiteSpace([string]$groupAssignCapture.capture.groupSubmitted.focusBeat) -or
    @($groupAssignGui.timeline.selectedNotes).Count -ne 1 -or
    @($groupSavedGui.timeline.selectedNotes).Count -ne 1 -or
    $groupBeforeNote.endBeat -or $groupSavedNote.endBeat -or
    $groupBeforeNote.group -ne 0 -or $groupSavedNote.group -ne 7 -or
    $groupSavedNote.noteId -ne $groupBeforeNote.noteId -or
    $groupSavedNote.lane -ne $groupBeforeNote.lane -or
    $groupSavedNote.beat.bar -ne $groupBeforeNote.beat.bar -or
    $groupSavedNote.beat.numerator -ne $groupBeforeNote.beat.numerator -or
    $groupSavedNote.beat.denominator -ne $groupBeforeNote.beat.denominator -or
    $groupSavedGui.timeline.sessionChangeSerial -ne
        ($groupAssignGui.timeline.sessionChangeSerial + 1) -or
    $groupAssignGui.timeline.sessionIsDirty -or $groupSavedGui.timeline.sessionIsDirty -or
    $groupSavedGui.timeline.activePlacementGroup -ne 0 -or
    @($groupSavedGui.timeline.hiddenGroups) -contains 7 -or
    $groupSavedGui.chart.structure.sha256 -eq $groupAssignGui.chart.structure.sha256 -or
    $groupSavedGui.chart.structure.keyCount -ne $groupAssignGui.chart.structure.keyCount -or
    $groupSavedGui.chart.structure.noteCount -ne $groupAssignGui.chart.structure.noteCount -or
    $groupSavedGui.chart.structure.longNoteCount -ne $groupAssignGui.chart.structure.longNoteCount -or
    $groupSavedGui.chart.structure.timingCount -ne $groupAssignGui.chart.structure.timingCount) {
    throw "The real MC Group assignment GUI probe did not apply and save one isolated Group 7 mutation."
}
if (-not $groupVisibilityCapture.capture.focusGroup -or
    -not $groupVisibilityCapture.capture.groupVisibilityExercised -or
    $groupVisibilityCapture.capture.PSObject.Properties.Name -notcontains
        "groupVisibilityAutomationFallbackUsed" -or
    -not ($groupVisibilityCapture.capture.groupVisibilityAutomationFallbackUsed -is [bool]) -or
    -not $groupVisibilityCapture.capture.interactionCapturedAfterActions -or
    @($groupVisibilityGui.timeline.selectedNotes).Count -ne 1 -or
    $groupVisibilityNote.group -ne 7 -or
    $groupVisibilityNote.lane -ne $groupSavedNote.lane -or
    $groupVisibilityNote.beat.bar -ne $groupSavedNote.beat.bar -or
    $groupVisibilityNote.beat.numerator -ne $groupSavedNote.beat.numerator -or
    $groupVisibilityNote.beat.denominator -ne $groupSavedNote.beat.denominator -or
    $groupVisibilityGui.chart.structure.sha256 -ne $groupSavedGui.chart.structure.sha256 -or
    $groupVisibilityGui.timeline.sessionChangeSerial -ne 0 -or
    $groupVisibilityGui.timeline.sessionIsDirty -or
    $groupVisibilityGui.timeline.activePlacementGroup -ne 0 -or
    @($groupVisibilityGui.timeline.hiddenGroups).Count -ne 0 -or
    $groupHiddenGui.timeline.selectedNoteCount -ne 0 -or
    $groupHiddenGui.timeline.visibleSelectedNoteCount -ne 0 -or
    @($groupHiddenGui.timeline.selectedNotes).Count -ne 0 -or
    @($groupHiddenGui.timeline.hiddenGroups) -notcontains 7 -or
    @($groupHiddenGui.timeline.hiddenGroups) -contains 0 -or
    $groupHiddenGui.timeline.sessionChangeSerial -ne $groupVisibilityGui.timeline.sessionChangeSerial -or
    $groupHiddenGui.timeline.sessionIsDirty -or
    $groupHiddenGui.timeline.activePlacementGroup -ne 0 -or
    $groupHiddenGui.chart.structure.sha256 -ne $groupVisibilityGui.chart.structure.sha256 -or
    $groupHiddenGui.chart.sourceSha256 -ne $groupVisibilityGui.chart.sourceSha256 -or
    $groupHiddenGui.timeline.visibleDocumentNoteCount -ne
        ($groupVisibilityGui.timeline.visibleDocumentNoteCount - 1)) {
    throw "The fresh real MC Group GUI probe did not hide Group 7, clear selection and preserve serial/structure."
}
$groupPlacementBeforeProbe = $groupPlacementGui.timeline.placementProbe
$groupPlacementAfterProbe = $groupPlacedGui.timeline.placementProbe
$groupPlacedTap = $groupPlacementAfterProbe.tapObservation
$groupPlacedHold = $groupPlacementAfterProbe.holdObservation
$groupPlacementBeforeRows = @($groupPlacementGui.timeline.groupManager.rows |
    Where-Object { [int]$_.group -eq 7 })
$groupPlacementAfterRows = @($groupPlacedGui.timeline.groupManager.rows |
    Where-Object { [int]$_.group -eq 7 })
$groupPlacedSelection = @($groupPlacedGui.timeline.selectedNotes)
if (-not $groupPlacementCapture.capture.focusGroup -or
    -not $groupPlacementCapture.capture.groupPlacementExercised -or
    $groupPlacementCapture.capture.PSObject.Properties.Name -notcontains
        "groupPlacementHideAutomationFallbackUsed" -or
    -not ($groupPlacementCapture.capture.groupPlacementHideAutomationFallbackUsed -is [bool]) -or
    -not $groupPlacementCapture.capture.interactionCapturedAfterActions -or
    [int]$groupPlacementCapture.capture.groupSubmitted.group -ne 7 -or
    @($groupPlacementGui.timeline.selectedNotes).Count -ne 1 -or
    $groupPlacementFocusNote.group -ne 7 -or
    $groupPlacementFocusNote.lane -ne $groupSavedNote.lane -or
    $groupPlacementFocusNote.beat.bar -ne $groupSavedNote.beat.bar -or
    $groupPlacementFocusNote.beat.numerator -ne $groupSavedNote.beat.numerator -or
    $groupPlacementFocusNote.beat.denominator -ne $groupSavedNote.beat.denominator -or
    $groupPlacementGui.chart.structure.sha256 -ne $groupSavedGui.chart.structure.sha256 -or
    $groupPlacementGui.timeline.sessionChangeSerial -ne 0 -or
    $groupPlacementGui.timeline.sessionIsDirty -or
    $groupPlacementGui.timeline.activePlacementGroup -ne 0 -or
    $groupPlacementGui.timeline.groupManager.activePlacementGroup -ne 0 -or
    $groupPlacementGui.timeline.groupManager.visibleEditableSelectionCount -ne 1 -or
    @($groupPlacementGui.timeline.hiddenGroups).Count -ne 0 -or
    $null -eq $groupPlacementBeforeProbe -or
    $null -ne $groupPlacementBeforeProbe.tapObservation -or
    $null -ne $groupPlacementBeforeProbe.holdObservation -or
    $groupPlacementBeforeRows.Count -ne 1 -or
    $groupPlacementBeforeRows[0].noteCount -ne 1 -or
    -not $groupPlacementBeforeRows[0].isVisible -or
    $groupPlacementBeforeRows[0].isCurrent) {
    throw "The fresh Group placement process did not reopen the saved Group 7 note from a clean view state."
}
if ($null -eq $groupPlacementAfterProbe -or
    -not (Test-PlacementTargetEvidenceEqual `
        -Left $groupPlacementBeforeProbe.tapTarget `
        -Right $groupPlacementAfterProbe.tapTarget) -or
    -not (Test-PlacementTargetEvidenceEqual `
        -Left $groupPlacementBeforeProbe.holdStartTarget `
        -Right $groupPlacementAfterProbe.holdStartTarget) -or
    -not (Test-PlacementTargetEvidenceEqual `
        -Left $groupPlacementBeforeProbe.holdEndTarget `
        -Right $groupPlacementAfterProbe.holdEndTarget) -or
    $null -eq $groupPlacedTap -or $null -eq $groupPlacedHold -or
    $groupPlacedTap.noteId -eq $groupPlacedHold.noteId -or
    $null -ne $groupPlacedTap.endBeat -or
    $groupPlacedTap.group -ne 7 -or
    $groupPlacedTap.lane -ne $groupPlacementAfterProbe.tapTarget.lane -or
    -not (Test-BeatEvidenceEqual `
        -Left $groupPlacedTap.beat `
        -Right $groupPlacementAfterProbe.tapTarget.beat) -or
    $null -eq $groupPlacedHold.endBeat -or
    $groupPlacedHold.group -ne 7 -or
    $groupPlacedHold.lane -ne $groupPlacementAfterProbe.holdStartTarget.lane -or
    -not (Test-BeatEvidenceEqual `
        -Left $groupPlacedHold.beat `
        -Right $groupPlacementAfterProbe.holdStartTarget.beat) -or
    -not (Test-BeatEvidenceEqual `
        -Left $groupPlacedHold.endBeat `
        -Right $groupPlacementAfterProbe.holdEndTarget.beat) -or
    $groupPlacedSelection.Count -ne 1 -or
    $groupPlacedSelection[0].noteId -ne $groupPlacedHold.noteId -or
    $groupPlacedGui.timeline.currentTool -ne "Hold" -or
    $groupPlacedGui.timeline.activePlacementGroup -ne 7 -or
    $groupPlacedGui.timeline.groupManager.activePlacementGroup -ne 7 -or
    $groupPlacedGui.timeline.groupManager.visibleEditableSelectionCount -ne 1 -or
    @($groupPlacedGui.timeline.hiddenGroups) -contains 7 -or
    $groupPlacedGui.timeline.sessionChangeSerial -ne
        ($groupPlacementGui.timeline.sessionChangeSerial + 2) -or
    -not $groupPlacedGui.timeline.sessionIsDirty -or
    $groupPlacedGui.chart.sourceSha256 -ne $groupPlacementGui.chart.sourceSha256 -or
    $groupPlacedGui.chart.structure.sha256 -eq $groupPlacementGui.chart.structure.sha256 -or
    $groupPlacedGui.chart.structure.noteCount -ne
        ($groupPlacementGui.chart.structure.noteCount + 2) -or
    $groupPlacedGui.chart.structure.longNoteCount -ne
        ($groupPlacementGui.chart.structure.longNoteCount + 1) -or
    $groupPlacedGui.chart.structure.keyCount -ne $groupPlacementGui.chart.structure.keyCount -or
    $groupPlacedGui.chart.structure.timingCount -ne $groupPlacementGui.chart.structure.timingCount -or
    $groupPlacedGui.timeline.visibleDocumentNoteCount -ne
        ($groupPlacementGui.timeline.visibleDocumentNoteCount + 2) -or
    $groupPlacementAfterRows.Count -ne 1 -or
    $groupPlacementAfterRows[0].noteCount -ne 3 -or
    -not $groupPlacementAfterRows[0].isVisible -or
    -not $groupPlacementAfterRows[0].isCurrent) {
    throw "The real mouse Group GUI probe did not hide/unhide Group 7 and place exact grouped Tap/Hold notes."
}
$transformBeforeNote = @($transformGui.timeline.selectedNotes)[0]
$transformAfterNotes = @($transformInteractionGui.timeline.selectedNotes)
$transformAfterHead = $transformAfterNotes | Where-Object { $_.noteId -eq $transformBeforeNote.noteId }
$transformAfterTail = $transformAfterNotes | Where-Object { $_.noteId -ne $transformBeforeNote.noteId }
if (@($transformAfterHead).Count -ne 1 -or @($transformAfterTail).Count -ne 1 -or
    $transformAfterHead.endBeat -or $transformAfterTail.endBeat -or
    $transformAfterHead.lane -ne $transformBeforeNote.lane -or
    $transformAfterTail.lane -ne $transformBeforeNote.lane -or
    $transformAfterHead.beat.bar -ne $transformBeforeNote.beat.bar -or
    $transformAfterHead.beat.numerator -ne $transformBeforeNote.beat.numerator -or
    $transformAfterHead.beat.denominator -ne $transformBeforeNote.beat.denominator -or
    $transformAfterTail.beat.bar -ne $transformBeforeNote.endBeat.bar -or
    $transformAfterTail.beat.numerator -ne $transformBeforeNote.endBeat.numerator -or
    $transformAfterTail.beat.denominator -ne $transformBeforeNote.endBeat.denominator -or
    $transformAfterHead.volume -ne $transformBeforeNote.volume -or
    $transformAfterTail.volume -ne $transformBeforeNote.volume -or
    $transformAfterHead.group -ne $transformBeforeNote.group -or
    $transformAfterTail.group -ne $transformBeforeNote.group -or
    $transformAfterHead.sound -ne $transformBeforeNote.sound -or
    $transformAfterTail.sound -ne $transformBeforeNote.sound) {
    throw "The real MC LN-to-Tap transform did not preserve exact authored Beat and Note properties."
}
if (-not $osuCapture.capture.focusTiming -or
    -not $osuCapture.capture.edgeScrollExercised -or
    $osuGui.timeline.selectedTimingCount -lt 1 -or
    $osuInteractionGui.timeline.currentBeat -le ($osuGui.timeline.currentBeat + .25)) {
    throw "The real osu GUI probe did not focus Timing and complete captured-pointer edge scrolling."
}

$proBefore = $proEditorEditGui.timeline.proEditor
$proSaved = $proEditorSavedGui.timeline.proEditor
$proBeforeProbe = $proBefore.probe
$proSavedProbe = $proSaved.probe
$proMoved = $proSavedProbe.movedOfficialObservation
$proHold = $proSavedProbe.draftHoldObservation
$proPanBeforeGeometry = $proEditorPanGui.timeline.proEditor.geometry
$proPanAfterGeometry = $proEditorPannedGui.timeline.proEditor.geometry
$proPanVisibleDraftNotes = @($proEditorPannedGui.timeline.proEditor.documentNotes |
    Where-Object { $_.isDraft } |
    Where-Object {
        $center = [double]$proPanAfterGeometry.officialTrackLeftWindowDip +
            (([double]$_.workspaceColumn + .5) * [double]$proPanAfterGeometry.laneWidthDip)
        $center -gt [double]$proPanAfterGeometry.timelineViewportLeftWindowDip -and
        $center -lt [double]$proPanAfterGeometry.timelineViewportRightWindowDip
    })
$proPanDraftColumns = @($proEditorPannedGui.timeline.proEditor.documentNotes |
    Where-Object { $_.isDraft } |
    ForEach-Object { [int]$_.workspaceColumn } |
    Sort-Object)
function Test-ProEditorPhysicalActivationEvidence {
    param([Parameter(Mandatory = $true)]$Activation)

    $attempts = @($Activation.attempts)
    if ([string]$Activation.path -cne
            "foreground verification + physical Win32 mouse clicks + UI Automation state observation" -or
        [int]$Activation.maximumAttempts -ne 3 -or
        [int]$Activation.attemptCount -ne $attempts.Count -or
        $attempts.Count -lt 1 -or $attempts.Count -gt 3 -or
        [bool]$Activation.retryUsed -ne ($attempts.Count -gt 1) -or
        [int]$Activation.boundedTargetWaitBudgetMilliseconds -ne 8500 -or
        -not [bool]$Activation.allPhysicalClicks -or
        [bool]$Activation.automationFallbackUsed -or
        -not [bool]$Activation.targetFound -or
        [string]$Activation.targetAutomationId -cne "ProEditor.HorizontalPan") {
        return $false
    }

    $expectedWaitBudgets = @(1500, 2000, 5000)
    for ($index = 0; $index -lt $attempts.Count; $index++) {
        $attempt = $attempts[$index]
        $isFinalAttempt = $index -eq ($attempts.Count - 1)
        $timeoutMessage = [string]$attempt.timeoutMessage
        if ([int]$attempt.attempt -ne ($index + 1) -or
            -not [bool]$attempt.mainWindowForegroundVerified -or
            [string]$attempt.toggle.automationId -cne "ProEditor.Toggle" -or
            [string]$attempt.toggle.name -cne "Pro Editor Toggle" -or
            [string]$attempt.toggle.controlType -cne "ControlType.Button" -or
            -not [bool]$attempt.toggle.isEnabled -or
            [bool]$attempt.toggle.isOffscreen -or
            [double]$attempt.toggle.bounds.width -le 1 -or
            [double]$attempt.toggle.bounds.height -le 1 -or
            [string]$attempt.input -cne
                "physical Win32 mouse click at UI Automation bounds" -or
            [string]$attempt.targetAutomationId -cne "ProEditor.HorizontalPan" -or
            [int]$attempt.targetWaitBudgetMilliseconds -ne $expectedWaitBudgets[$index] -or
            [bool]$attempt.targetFound -ne $isFinalAttempt -or
            [bool]$attempt.timedOut -eq $isFinalAttempt -or
            ($isFinalAttempt -and -not [string]::IsNullOrEmpty($timeoutMessage)) -or
            (-not $isFinalAttempt -and $timeoutMessage -notmatch
                "^Timed out finding UI Automation id 'ProEditor\.HorizontalPan' for process [0-9]+\.$")) {
            return $false
        }
    }
    return $true
}

$proEditorActivationCaptures = @(
    $proEditorPanCapture.capture,
    $proEditorEditCapture.capture,
    $proEditorReopenCapture.capture,
    $proEditorOsuReopenCapture.capture)
if (@($proEditorActivationCaptures | Where-Object {
            -not (Test-ProEditorPhysicalActivationEvidence $_.proEditorActivation)
        }).Count -ne 0 -or
    $null -ne $proEditorSaveAsCapture.capture.proEditorActivation) {
    throw "The ProEditor GUI gates did not prove bounded, state-confirmed physical activation without automation fallback."
}
if (-not $proEditorPanCapture.capture.focusProEditor -or
    -not $proEditorPanCapture.capture.proEditorPanExercised -or
    $proEditorPanGui.timeline.proEditor.enabled -or
    -not $proEditorPannedGui.timeline.proEditor.enabled -or
    $proEditorPanGui.timeline.sessionChangeSerial -ne 0 -or
    $proEditorPannedGui.timeline.sessionChangeSerial -ne 0 -or
    $proEditorPanGui.timeline.sessionIsDirty -or $proEditorPannedGui.timeline.sessionIsDirty -or
    $proEditorPanGui.chart.structure.sha256 -ne
        "DA19D6668A4DCCD99281651ACAA10D0AD93CE2D567EABE0AC8A8D68C04C41938" -or
    $proEditorPannedGui.chart.structure.sha256 -ne $proEditorPanGui.chart.structure.sha256 -or
    -not $proEditorPannedGui.timeline.proEditor.horizontalPan.enabled -or
    [double]$proEditorPannedGui.timeline.proEditor.horizontalPan.value -ge -1 -or
    $null -eq $proPanBeforeGeometry.officialTrackLeftWindowDip -or
    $null -eq $proPanAfterGeometry.officialTrackLeftWindowDip -or
    $null -eq $proPanAfterGeometry.timelineViewportLeftWindowDip -or
    $null -eq $proPanAfterGeometry.timelineViewportRightWindowDip -or
    [double]$proPanAfterGeometry.officialTrackLeftWindowDip -ge
        [double]$proPanBeforeGeometry.officialTrackLeftWindowDip -or
    $proEditorPannedGui.timeline.proEditor.visibleDraftNoteCount -ne 3 -or
    ($proPanDraftColumns -join ',') -ne '8,9,10' -or
    $proPanVisibleDraftNotes.Count -ne 3) {
    throw "The ProEditor GUI pan gate did not reveal all three high draft columns through a real nonmutating negative slider drag."
}
if (-not $proEditorEditCapture.capture.focusProEditor -or
    -not $proEditorEditCapture.capture.proEditorEditExercised -or
    -not $proEditorEditCapture.capture.proEditorEditSaved -or
    $proEditorEditGui.timeline.proEditor.enabled -or
    -not $proEditorSavedGui.timeline.proEditor.enabled -or
    $proEditorEditGui.timeline.sessionChangeSerial -ne 0 -or
    $proEditorSavedGui.timeline.sessionChangeSerial -ne 3 -or
    $proEditorEditGui.timeline.sessionIsDirty -or $proEditorSavedGui.timeline.sessionIsDirty -or
    $proEditorEditGui.chart.structure.sha256 -ne
        "DA19D6668A4DCCD99281651ACAA10D0AD93CE2D567EABE0AC8A8D68C04C41938" -or
    $proEditorSavedGui.chart.structure.sha256 -ne
        "6995CDE6268B0BF071718286363C45112E50829D9C063AC12A82D01EED50E68B" -or
    $proSaved.officialDocumentNoteCount -ne 3 -or
    $proSaved.draftDocumentNoteCount -ne 4 -or
    $proEditorSavedGui.chart.structure.noteCount -ne 7 -or
    $proEditorSavedGui.chart.structure.longNoteCount -ne 1 -or
    $null -eq $proBeforeProbe -or $null -eq $proSavedProbe -or
    -not (Test-ProEditorTargetEvidenceEqual `
        -Left $proBeforeProbe.draftTapTarget -Right $proSavedProbe.draftTapTarget) -or
    -not (Test-ProEditorTargetEvidenceEqual `
        -Left $proBeforeProbe.officialMoveTarget -Right $proSavedProbe.officialMoveTarget) -or
    -not (Test-ProEditorTargetEvidenceEqual `
        -Left $proBeforeProbe.draftHoldStartTarget -Right $proSavedProbe.draftHoldStartTarget) -or
    -not (Test-ProEditorTargetEvidenceEqual `
        -Left $proBeforeProbe.draftHoldEndTarget -Right $proSavedProbe.draftHoldEndTarget) -or
    $null -eq $proMoved -or $proMoved.isDraft -or $proMoved.workspaceColumn -ne 3 -or
    $proMoved.endBeat -or
    $null -eq $proHold -or -not $proHold.isDraft -or $proHold.workspaceColumn -ne 4 -or
    $null -eq $proHold.endBeat -or
    -not (Test-BeatEvidenceEqual -Left $proMoved.beat -Right $proSavedProbe.officialMoveTarget.beat) -or
    -not (Test-BeatEvidenceEqual -Left $proHold.beat -Right $proSavedProbe.draftHoldStartTarget.beat) -or
    -not (Test-BeatEvidenceEqual -Left $proHold.endBeat -Right $proSavedProbe.draftHoldEndTarget.beat)) {
    throw "The ProEditor GUI edit gate did not prove exact Tap, official/draft crossing, Hold and compact save."
}
if (-not $proEditorReopenCapture.capture.proEditorRevealExercised -or
    $proEditorReopenGui.timeline.sessionChangeSerial -ne 0 -or
    $proEditorReopenInteractionGui.timeline.sessionChangeSerial -ne 0 -or
    $proEditorReopenGui.timeline.sessionIsDirty -or
    $proEditorReopenInteractionGui.timeline.sessionIsDirty -or
    $proEditorReopenGui.chart.structure.sha256 -ne
        "6995CDE6268B0BF071718286363C45112E50829D9C063AC12A82D01EED50E68B" -or
    $proEditorReopenInteractionGui.chart.structure.sha256 -ne
        $proEditorSavedGui.chart.structure.sha256 -or
    $proEditorReopenInteractionGui.timeline.proEditor.officialDocumentNoteCount -ne 3 -or
    $proEditorReopenInteractionGui.timeline.proEditor.draftDocumentNoteCount -ne 4 -or
    -not $proEditorReopenInteractionGui.timeline.proEditor.enabled) {
    throw "The fresh MC reopen did not retain the exact saved ProEditor structure."
}
if (-not $proEditorSaveAsCapture.capture.proEditorSaveAsOsuExercised -or
    -not $proEditorSaveAsCapture.capture.proEditorSaveAsInitialDirectoryVerified -or
    $proEditorSaveAsCapture.capture.proEditorSaveAsVisibleSourceName -ne
        [IO.Path]::GetFileName($isolatedProEditorEditPath) -or
    $proEditorSaveAsGui.timeline.sessionChangeSerial -ne 0 -or
    $proEditorSavedAsGui.timeline.sessionChangeSerial -ne 0 -or
    $proEditorSaveAsGui.timeline.sessionIsDirty -or $proEditorSavedAsGui.timeline.sessionIsDirty -or
    [IO.Path]::GetFullPath([string]$proEditorSavedAsGui.chart.sourcePath) -ne
        [IO.Path]::GetFullPath($isolatedProEditorOsuPath) -or
    $proEditorSavedAsGui.chart.sourceSha256 -ne $proEditorOsuSha256 -or
    $proEditorSavedAsGui.chart.structure.sha256 -ne $proEditorSaveAsGui.chart.structure.sha256 -or
    $proEditorSavedAsGui.timeline.proEditor.draftDocumentNoteCount -ne 4 -or
    -not $proEditorSavedAsGui.timeline.proEditor.enabled) {
    throw "The native ProEditor Save As gate did not preserve the live document while exporting osu."
}
if (-not $proEditorOsuReopenCapture.capture.proEditorRevealExercised -or
    $proEditorOsuReopenGui.timeline.sessionChangeSerial -ne 0 -or
    $proEditorOsuReopenInteractionGui.timeline.sessionChangeSerial -ne 0 -or
    $proEditorOsuReopenGui.timeline.sessionIsDirty -or
    $proEditorOsuReopenInteractionGui.timeline.sessionIsDirty -or
    [IO.Path]::GetFullPath([string]$proEditorOsuReopenInteractionGui.chart.sourcePath) -ne
        [IO.Path]::GetFullPath($isolatedProEditorOsuPath) -or
    $proEditorOsuReopenInteractionGui.chart.sourceSha256 -ne $proEditorOsuSha256 -or
    $proEditorOsuReopenInteractionGui.chart.structure.noteCount -ne 3 -or
    $proEditorOsuReopenInteractionGui.chart.structure.longNoteCount -ne 0 -or
    $proEditorOsuReopenInteractionGui.timeline.proEditor.officialDocumentNoteCount -ne 3 -or
    $proEditorOsuReopenInteractionGui.timeline.proEditor.draftDocumentNoteCount -ne 0 -or
    -not $proEditorOsuReopenInteractionGui.timeline.proEditor.enabled) {
    throw "The fresh osu reopen did not prove all draft Notes were excluded from export."
}

$chartExportModesEvidence = $chartExportModesCapture.capture.chartExportModes
$chartExportModesActualExport = $chartExportModesEvidence.actualExport
$chartExportModesSourceTreeAfter =
    Get-DirectoryTreeEvidence -Path $chartExportModesSourceRoot
$chartExportModesArchiveEvidence =
    Get-FormalChartExportModesSingleRateEvidence `
        -ArchivePath $chartExportModesExportPath `
        -SourceRoot $chartExportModesSourceRoot `
        -AudioAssemblyRoot (Join-Path $projectRoot `
            "LumaChart.Avalonia\bin\Release\net8.0-windows")
$chartExportModesExportItem = Get-Item -LiteralPath $chartExportModesExportPath
$chartExportModesScratchRoot =
    Join-Path $chartExportModesEditingRoot "_scratch"
$chartExportModesScratchEntries = if (
    Test-Path -LiteralPath $chartExportModesScratchRoot -PathType Container) {
    @(Get-ChildItem -LiteralPath $chartExportModesScratchRoot -Recurse -Force)
} else { @() }
$chartExportModesTemporaryArchives = @(
    Get-ChildItem `
        -LiteralPath ([IO.Path]::GetDirectoryName($chartExportModesExportPath)) `
        -File `
        -Force |
        Where-Object { $_.Name -like '*.luma-export.tmp' })
$chartExportModesProcess = @(
    Get-Process `
        -Id ([int]$chartExportModesCapture.capture.processId) `
        -ErrorAction SilentlyContinue)
$chartExportModesExpectedValidation =
    "倍速范围为 0.2–3，结束值不能小于起始值，间隔范围为 0.01–1。"
if (-not [bool]$chartExportModesCapture.capture.chartExportModesExercised -or
    -not [bool]$chartExportModesCapture.capture.interactionCapturedAfterActions -or
    $null -eq $chartExportModesCapture.capture.interactionActionsCompletedAtUtc -or
    $null -eq $chartExportModesEvidence -or
    -not [bool]$chartExportModesEvidence.verified -or
    [int]$chartExportModesEvidence.modeSwitchCount -ne 5 -or
    [string]$chartExportModesEvidence.dialog.automationId -cne
        'Export.MalodyFullPackage.Dialog' -or
    -not [bool]$chartExportModesEvidence.launch.physicalClickAttempted -or
    -not [bool]$chartExportModesEvidence.defaultFullPackage.verified -or
    -not [bool]$chartExportModesEvidence.singleChart.verified -or
    -not [bool]$chartExportModesEvidence.singleRatePackage.verified -or
    -not [bool]$chartExportModesEvidence.ratePack.verified -or
    -not [bool]$chartExportModesEvidence.hiddenFieldValidation.verified -or
    [string]$chartExportModesEvidence.defaultFullPackage.format.name -cne
        'Malody (.mc / .mcz)' -or
    [bool]$chartExportModesEvidence.defaultFullPackage.state.singleRatePanelVisible -or
    [bool]$chartExportModesEvidence.defaultFullPackage.state.ratePackPanelVisible -or
    [bool]$chartExportModesEvidence.defaultFullPackage.state.preservePitch.isEnabled -or
    [bool]$chartExportModesEvidence.defaultFullPackage.state.preservePitch.isChecked -or
    [bool]$chartExportModesEvidence.singleChart.state.singleRatePanelVisible -or
    [bool]$chartExportModesEvidence.singleChart.state.ratePackPanelVisible -or
    [bool]$chartExportModesEvidence.singleChart.state.preservePitch.isEnabled -or
    [string]$chartExportModesEvidence.singleRatePackage.stateBeforePitch.singleRate.value -cne
        '1.2' -or
    -not [bool]$chartExportModesEvidence.singleRatePackage.stateBeforePitch.preservePitch.isEnabled -or
    [bool]$chartExportModesEvidence.singleRatePackage.stateBeforePitch.preservePitch.isChecked -or
    [string]$chartExportModesEvidence.singleRatePackage.state.singleRate.value -cne '1.2' -or
    -not [bool]$chartExportModesEvidence.singleRatePackage.state.preservePitch.isEnabled -or
    -not [bool]$chartExportModesEvidence.singleRatePackage.state.preservePitch.isChecked -or
    [string]$chartExportModesEvidence.ratePack.state.minimumRate.value -cne '0.8' -or
    [string]$chartExportModesEvidence.ratePack.state.maximumRate.value -cne '1.2' -or
    [string]$chartExportModesEvidence.ratePack.state.rateStep.value -cne '0.1' -or
    -not [bool]$chartExportModesEvidence.ratePack.state.preservePitch.isEnabled -or
    -not [bool]$chartExportModesEvidence.ratePack.state.preservePitch.isChecked -or
    [string]$chartExportModesEvidence.hiddenFieldValidation.invalidInput.after.value -cne
        'invalid' -or
    [string]$chartExportModesEvidence.hiddenFieldValidation.expectedMessage -cne
        $chartExportModesExpectedValidation -or
    [string]$chartExportModesEvidence.hiddenFieldValidation.validation.name -cne
        $chartExportModesExpectedValidation -or
    -not [bool]$chartExportModesEvidence.hiddenFieldValidation.validationBeforeConfirm.empty -or
    -not [bool]$chartExportModesEvidence.hiddenFieldValidation.preservedPitchCheckedWhileDisabled -or
    -not [bool]$chartExportModesEvidence.hiddenFieldValidation.hiddenSingleRateRejected) {
    throw "The actual chart-export dialog did not retain the exact four WPF modes, defaults, PreservePitch retention, and hidden-field validation."
}
$chartExportModeSelections = @(
    $chartExportModesEvidence.singleChart.selection,
    $chartExportModesEvidence.singleRatePackage.selection,
    $chartExportModesEvidence.ratePack.selection,
    $chartExportModesEvidence.hiddenFieldValidation.returnToSingleRateSelection,
    $chartExportModesEvidence.hiddenFieldValidation.returnToFullPackageSelection,
    $chartExportModesActualExport.modeSelection)
if (@($chartExportModeSelections | Where-Object {
            $null -eq $_ -or -not [bool]$_.physicalClickAttempted -or
            [string]::IsNullOrWhiteSpace([string]$_.after.name)
        }).Count -ne 0) {
    throw "The chart-export mode changes did not record physical pointer attempts and retained UI values."
}
if ($null -eq $chartExportModesActualExport -or
    -not [bool]$chartExportModesActualExport.verified -or
    [string]$chartExportModesActualExport.requested.format -cne 'Malody' -or
    [string]$chartExportModesActualExport.requested.mode -cne 'SingleRatePackage' -or
    -not (Test-PathEvidenceEqual `
        -Left ([string]$chartExportModesActualExport.requested.path) `
        -Right $chartExportModesExportPath) -or
    [Math]::Abs([double]$chartExportModesActualExport.requested.rate - 1.25) -gt
        .000001 -or
    -not [bool]$chartExportModesActualExport.requested.preservePitch -or
    [string]$chartExportModesActualExport.modeSelection.after.name -cne
        '单一倍速压缩包' -or
    [string]$chartExportModesActualExport.rateInput.after.value -cne '1.25' -or
    [string]$chartExportModesActualExport.rateInput.imeCommitGuard -cne
        'Unicode input bypasses the IME composition buffer and an explicit pointer focus loss commits the field' -or
    (-not [bool]$chartExportModesActualExport.rateInput.physicalInputRetained -and
     -not [bool]$chartExportModesActualExport.rateInput.automationValueFallbackUsed) -or
    [string]$chartExportModesActualExport.formatSelection.after.name -cne
        'Malody (.mc / .mcz)' -or
    -not [bool]$chartExportModesActualExport.preservePitch.after.isEnabled -or
    -not [bool]$chartExportModesActualExport.preservePitch.after.isChecked -or
    -not [bool]$chartExportModesActualExport.confirm.control.isEnabled -or
    -not [bool]$chartExportModesActualExport.nativeSave.directory.exactDirectoryVerified -or
    -not (Test-PathEvidenceEqual `
        -Left ([string]$chartExportModesActualExport.nativeSave.directory.requestedDirectory) `
        -Right ([IO.Path]::GetDirectoryName($chartExportModesExportPath))) -or
    -not (Test-PathEvidenceEqual `
        -Left ([string]$chartExportModesActualExport.nativeSave.directory.reportedDirectory) `
        -Right ([IO.Path]::GetDirectoryName($chartExportModesExportPath))) -or
    [string]$chartExportModesActualExport.nativeSave.filename -cne
        [IO.Path]::GetFileName($chartExportModesExportPath) -or
    -not [bool]$chartExportModesActualExport.nativeSave.explicitEnterSubmitted -or
    -not [bool]$chartExportModesActualExport.nativeSave.dialogClosedAfterSubmit -or
    [bool]$chartExportModesActualExport.nativeSave.physicalInputRetained -eq
        [bool]$chartExportModesActualExport.nativeSave.automationValueFallbackUsed -or
    -not (Test-PathEvidenceEqual `
        -Left ([string]$chartExportModesActualExport.file.path) `
        -Right $chartExportModesExportPath) -or
    [long]$chartExportModesActualExport.file.length -ne
        [long]$chartExportModesExportItem.Length -or
    [string]$chartExportModesActualExport.file.sha256 -cne
        [string]$chartExportModesArchiveEvidence.sha256 -or
    [string]$chartExportModesActualExport.result.dialogAutomationId -cne
        'Export.MalodyFullPackage.Result.Dialog' -or
    -not ([string]$chartExportModesActualExport.result.message.name).TrimStart().StartsWith(
        '导出完成',
        [StringComparison]::Ordinal) -or
    -not ([string]$chartExportModesActualExport.result.message.name).Contains(
        [IO.Path]::GetFileName($chartExportModesExportPath),
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "The actual Malody SingleRate 1.25x PreservePitch native Save/result path was not exact."
}
if (-not [bool]$chartExportModesArchiveEvidence.verified -or
    [long]$chartExportModesArchiveEvidence.length -ne
        [long]$chartExportModesExportItem.Length -or
    [string]$chartExportModesArchiveEvidence.sha256 -cne
        (Get-FileHash -LiteralPath $chartExportModesExportPath -Algorithm SHA256).Hash -or
    -not (Test-DirectoryTreeEvidenceEqual `
        -Before $chartExportModesSourceTreeBefore `
        -After $chartExportModesSourceTreeAfter) -or
    $chartExportModesSourceHashMismatches.Count -ne 0 -or
    $chartExportModesScratchEntries.Count -ne 0 -or
    $chartExportModesTemporaryArchives.Count -ne 0 -or
    $chartExportModesProcess.Count -ne 0) {
    throw "The chart-export package, source tree, process-owned scratch, or atomic archive boundary was not exact after normal GUI exit."
}

$malodyFullPackageExportEvidence =
    $malodyFullPackageCapture.capture.malodyFullPackageExport
$malodyFullPackageFreshEvidence =
    $malodyFullPackageExportEvidence.freshImport
$malodyFullPackageArchiveEvidence =
    $malodyFullPackageExportEvidence.archive
$malodyFullPackageDirtyInjection =
    $malodyFullPackageExportEvidence.dirtyInjection
$malodyFullPackageSourceTreeAfter =
    Get-DirectoryTreeEvidence -Path $malodyFullPackageSourceRoot
$malodyFullPackageFreshMcFiles = @(
    Get-ChildItem `
        -LiteralPath $malodyFullPackageFreshWorkspaceRoot `
        -Recurse `
        -File `
        -Filter "*.mc")
$malodyFullPackageForbiddenArchiveEntries = @(
    $malodyFullPackageArchiveEvidence.entries | Where-Object {
        [string]$_.fullName -match '(?i)(\.mc_|\.osu|\.mcz|\.osz|\.luma-part)$'
    })
$malodyFullPackageResourceHashPairs = @(
    foreach ($resourceSpec in @(
            [pscustomobject]@{ name = "InfinityHeaven.ogg"; expectCollision = $true },
            [pscustomobject]@{ name = "InfinityHeaven.jpg"; expectCollision = $true },
            [pscustomobject]@{ name = "ih2.jpg"; expectCollision = $false })) {
        $resourceName = [string]$resourceSpec.name
        $resourcePath = Join-Path $malodyFullPackageSourceRoot "0\$resourceName"
        $sourceResourceSha256 =
            (Get-FileHash -LiteralPath $resourcePath -Algorithm SHA256).Hash
        $resourceStem = [IO.Path]::GetFileNameWithoutExtension($resourceName)
        $resourceExtension = [IO.Path]::GetExtension($resourceName)
        $collisionName = "${resourceStem}_2${resourceExtension}"
        $baseEntries = @($malodyFullPackageArchiveEvidence.entries | Where-Object {
                [string]$_.fullName -ieq $resourceName
            })
        $collisionEntries = @($malodyFullPackageArchiveEvidence.entries | Where-Object {
                [string]$_.fullName -ieq $collisionName
            })
        [pscustomobject][ordered]@{
            resourceName = $resourceName
            collisionName = $collisionName
            expectCollision = [bool]$resourceSpec.expectCollision
            sourcePath = $resourcePath
            sourceSha256 = $sourceResourceSha256
            baseEntryCount = $baseEntries.Count
            baseEntrySha256 = if ($baseEntries.Count -eq 1) {
                [string]$baseEntries[0].sha256
            } else { $null }
            collisionEntryCount = $collisionEntries.Count
            collisionEntrySha256 = if ($collisionEntries.Count -eq 1) {
                [string]$collisionEntries[0].sha256
            } else { $null }
            hashesMatch = $baseEntries.Count -eq 1 -and
                [string]$baseEntries[0].sha256 -ceq $sourceResourceSha256 -and
                (([bool]$resourceSpec.expectCollision -and
                  $collisionEntries.Count -eq 1 -and
                  [string]$collisionEntries[0].sha256 -ceq $sourceResourceSha256) -or
                 (-not [bool]$resourceSpec.expectCollision -and
                  $collisionEntries.Count -eq 0))
        }
    })
$malodyFullPackageFreshResourceHashPairs = @(
    foreach ($resourcePair in $malodyFullPackageResourceHashPairs) {
        $baseFiles = @(
            Get-ChildItem `
                -LiteralPath $malodyFullPackageFreshWorkspaceRoot `
                -Recurse `
                -File |
                Where-Object { $_.Name -ieq [string]$resourcePair.resourceName })
        $collisionFiles = @(
            Get-ChildItem `
                -LiteralPath $malodyFullPackageFreshWorkspaceRoot `
                -Recurse `
                -File |
                Where-Object { $_.Name -ieq [string]$resourcePair.collisionName })
        [pscustomobject][ordered]@{
            resourceName = [string]$resourcePair.resourceName
            collisionName = [string]$resourcePair.collisionName
            expectCollision = [bool]$resourcePair.expectCollision
            sourceSha256 = [string]$resourcePair.sourceSha256
            baseFileCount = $baseFiles.Count
            basePath = if ($baseFiles.Count -eq 1) { $baseFiles[0].FullName } else { $null }
            baseSha256 = if ($baseFiles.Count -eq 1) {
                (Get-FileHash -LiteralPath $baseFiles[0].FullName -Algorithm SHA256).Hash
            } else { $null }
            collisionFileCount = $collisionFiles.Count
            collisionPath = if ($collisionFiles.Count -eq 1) {
                $collisionFiles[0].FullName
            } else { $null }
            collisionSha256 = if ($collisionFiles.Count -eq 1) {
                (Get-FileHash -LiteralPath $collisionFiles[0].FullName -Algorithm SHA256).Hash
            } else { $null }
            hashesMatch = $baseFiles.Count -eq 1 -and
                (Get-FileHash -LiteralPath $baseFiles[0].FullName -Algorithm SHA256).Hash -ceq
                    [string]$resourcePair.sourceSha256 -and
                (([bool]$resourcePair.expectCollision -and
                  $collisionFiles.Count -eq 1 -and
                  (Get-FileHash -LiteralPath $collisionFiles[0].FullName -Algorithm SHA256).Hash -ceq
                    [string]$resourcePair.sourceSha256) -or
                 (-not [bool]$resourcePair.expectCollision -and
                  $collisionFiles.Count -eq 0))
        }
    })
$malodyFullPackageImportedMainTabs = @(
    $malodyFullPackageFreshEvidence.importedTabs | Where-Object { [bool]$_.isMain })
$malodyFullPackageMainProcess = @(
    Get-Process -Id ([int]$malodyFullPackageCapture.capture.processId) `
        -ErrorAction SilentlyContinue)
$malodyFullPackageFreshProcess = @(
    Get-Process -Id ([int]$malodyFullPackageFreshEvidence.processId) `
        -ErrorAction SilentlyContinue)
$malodyFullPackagePrimarySourcePath =
    [IO.Path]::GetFullPath([string]$malodyFullPackageGui.chart.sourcePath)
$malodyFullPackageInteractionSourcePath =
    [IO.Path]::GetFullPath([string]$malodyFullPackageInteractionGui.chart.sourcePath)
$malodyFullPackageDestinationPath =
    [IO.Path]::GetFullPath([string]$malodyFullPackageExportEvidence.destinationPath)
$malodyFullPackageDestinationDirectory =
    [IO.Path]::GetDirectoryName($malodyFullPackageDestinationPath)
$malodyFullPackageDestinationFileName =
    [IO.Path]::GetFileName($malodyFullPackageDestinationPath)
$malodyFullPackageUnexpectedSuggestedPath =
    Join-Path `
        $malodyFullPackageDestinationDirectory `
        "HyuN - Infinity Heaven [4K Stream Lv.28].mcz"
$malodyFullPackageRequestedNativePath =
    [IO.Path]::GetFullPath([string]$malodyFullPackageExportEvidence.nativeSave.requestedPath)
$malodyFullPackageFreshRequestedPath =
    [IO.Path]::GetFullPath([string]$malodyFullPackageFreshEvidence.nativeOpen.requestedPath)
$malodyFullPackageFreshImportedSourcePath =
    [IO.Path]::GetFullPath([string]$malodyFullPackageFreshEvidence.importedSourcePath)
$malodyFullPackageFreshWorkspaceBoundary =
    [IO.Path]::GetFullPath($malodyFullPackageFreshWorkspaceRoot).TrimEnd('\') + '\'
$malodyFullPackageFreshFilenameProvider =
    [string]$malodyFullPackageFreshEvidence.nativeOpen.filenameProvider
$malodyFullPackageFreshFilenameControl =
    $malodyFullPackageFreshEvidence.nativeOpen.filenameControl
$malodyFullPackageFreshFilenameEditValue =
    [string]$malodyFullPackageFreshFilenameControl.value
$malodyFullPackageFreshFilenameEditValueAvailable =
    $malodyFullPackageFreshFilenameEditValue.Length -gt 0
$malodyFullPackageFreshFilenameEditMirrorsSelection =
    $malodyFullPackageFreshFilenameEditValueAvailable -and
    [string]::Equals(
        $malodyFullPackageFreshFilenameEditValue,
        $malodyFullPackageDestinationFileName,
        [StringComparison]::OrdinalIgnoreCase)
$malodyFullPackageFreshFileListSelection =
    $malodyFullPackageFreshEvidence.nativeOpen.fileListSelection
$malodyFullPackageUnicodeCharCount = $malodyFullPackageDestinationFileName.Length
$malodyFullPackageUnicodeEventCount = $malodyFullPackageUnicodeCharCount * 2
$malodyFullPackageNativeSaveInputAttempts = @(
    $malodyFullPackageExportEvidence.nativeSave.filenameInputAttempts)
$malodyFullPackageNativeSaveInputAttemptMismatches =
    [Collections.Generic.List[string]]::new()
for ($attemptIndex = 0;
     $attemptIndex -lt $malodyFullPackageNativeSaveInputAttempts.Count;
     $attemptIndex++) {
    $attempt = $malodyFullPackageNativeSaveInputAttempts[$attemptIndex]
    $expectedAttempt = $attemptIndex + 1
    $attemptFilenameExact = [string]::Equals(
        [string]$attempt.afterName,
        $malodyFullPackageDestinationFileName,
        [StringComparison]::OrdinalIgnoreCase)
    if ([int]$attempt.attempt -ne $expectedAttempt -or
        [long]$attempt.expectedForegroundHandle -eq 0 -or
        [long]$attempt.expectedForegroundHandle -ne
            [long]$malodyFullPackageExportEvidence.nativeSave.nativeWindowHandle -or
        [long]$attempt.foregroundBeforeClick -ne
            [long]$attempt.expectedForegroundHandle -or
        -not [bool]$attempt.physicalFilenameClickAttempted -or
        [long]$attempt.foregroundAfterClick -ne
            [long]$attempt.expectedForegroundHandle -or
        [string]$attempt.mnemonic -cne "Alt+N native filename accelerator" -or
        [long]$attempt.foregroundAfterMnemonic -ne
            [long]$attempt.expectedForegroundHandle -or
        -not (Test-NativeFileNameFocusEvidence `
            -Evidence $attempt.focusAfterHostSetFocus `
            -ProcessId ([int]$malodyFullPackageCapture.capture.processId) `
            -Provider "CommonSave") -or
        -not (Test-NativeFileNameFocusEvidence `
            -Evidence $attempt.focusBeforeInput `
            -ProcessId ([int]$malodyFullPackageCapture.capture.processId) `
            -Provider "CommonSave") -or
        [string]$attempt.keyboardInput -cne
            "Ctrl+A + Win32 SendInput KEYEVENTF_UNICODE exact leaf" -or
        -not (Test-NativeFileNameFocusEvidence `
            -Evidence $attempt.focusAfterUnicodeInput `
            -ProcessId ([int]$malodyFullPackageCapture.capture.processId) `
            -Provider "CommonSave") -or
        [int]$attempt.inputStructSize -ne 40 -or
        [int]$attempt.unicodeCharCount -ne $malodyFullPackageUnicodeCharCount -or
        [int]$attempt.expectedUnicodeEventCount -ne
            $malodyFullPackageUnicodeEventCount -or
        [int]$attempt.returnedUnicodeEventCount -ne
            $malodyFullPackageUnicodeEventCount -or
        [int]$attempt.win32LastError -ne 0 -or
        [bool]$attempt.imeCommitRequired -or
        [bool]$attempt.imeCommitEnter -or
        -not [bool]$attempt.dialogOpenAfterUnicodeInput -or
        [bool]$attempt.exactUiaNameRetained -ne $attemptFilenameExact -or
        [long]$attempt.foregroundAfterKeyboard -ne
            [long]$attempt.expectedForegroundHandle) {
        $malodyFullPackageNativeSaveInputAttemptMismatches.Add(
            [string]$expectedAttempt)
    }
}
$malodyFullPackageNativeSaveSuccessfulInputAttempts = @(
    $malodyFullPackageNativeSaveInputAttempts | Where-Object {
        [bool]$_.exactUiaNameRetained
    })
$malodyFullPackageNativeSaveLastInputAttempt = if (
    $malodyFullPackageNativeSaveInputAttempts.Count -gt 0) {
    $malodyFullPackageNativeSaveInputAttempts[-1]
} else { $null }
$malodyFullPackageNativeSaveLastAttemptMatchesTopLevel =
    $null -ne $malodyFullPackageNativeSaveLastInputAttempt -and
    [int]$malodyFullPackageNativeSaveLastInputAttempt.inputStructSize -eq
        [int]$malodyFullPackageExportEvidence.nativeSave.inputStructSize -and
    [int]$malodyFullPackageNativeSaveLastInputAttempt.unicodeCharCount -eq
        [int]$malodyFullPackageExportEvidence.nativeSave.unicodeCharCount -and
    [int]$malodyFullPackageNativeSaveLastInputAttempt.expectedUnicodeEventCount -eq
        [int]$malodyFullPackageExportEvidence.nativeSave.expectedUnicodeEventCount -and
    [int]$malodyFullPackageNativeSaveLastInputAttempt.returnedUnicodeEventCount -eq
        [int]$malodyFullPackageExportEvidence.nativeSave.returnedUnicodeEventCount -and
    [int]$malodyFullPackageNativeSaveLastInputAttempt.win32LastError -eq
        [int]$malodyFullPackageExportEvidence.nativeSave.win32LastError -and
    [bool]$malodyFullPackageNativeSaveLastInputAttempt.imeCommitRequired -eq
        [bool]$malodyFullPackageExportEvidence.nativeSave.imeCommitRequired -and
    [bool]$malodyFullPackageNativeSaveLastInputAttempt.imeCommitEnter -eq
        [bool]$malodyFullPackageExportEvidence.nativeSave.imeCommitEnter -and
    [bool]$malodyFullPackageNativeSaveLastInputAttempt.dialogOpenAfterUnicodeInput -eq
        [bool]$malodyFullPackageExportEvidence.nativeSave.dialogOpenAfterUnicodeInput -and
    [string]$malodyFullPackageNativeSaveLastInputAttempt.afterName -ceq
        [string]$malodyFullPackageExportEvidence.nativeSave.filenameValue
$malodyFullPackageFreshFilenameProviderVerified =
    $malodyFullPackageFreshFilenameProvider -ceq
        "Legacy GetOpenFileName 1148/Edit" -and
     [string]$malodyFullPackageFreshFilenameControl.automationId -ceq "1148" -and
     [string]$malodyFullPackageFreshFilenameControl.className -ceq "Edit" -and
     [string]$malodyFullPackageFreshFilenameControl.controlType -ceq
        "ControlType.Pane" -and
     [bool]$malodyFullPackageFreshFilenameControl.isEnabled -and
     -not [bool]$malodyFullPackageFreshFilenameControl.isOffscreen -and
     [long]$malodyFullPackageFreshFilenameControl.nativeWindowHandle -ne 0 -and
     [string]$malodyFullPackageFreshFilenameControl.readApi -ceq "GetWindowTextW" -and
     [bool]$malodyFullPackageFreshFilenameControl.valueAvailable -eq
        $malodyFullPackageFreshFilenameEditValueAvailable -and
     [bool]$malodyFullPackageFreshFilenameControl.mirrorsSelection -eq
        $malodyFullPackageFreshFilenameEditMirrorsSelection -and
     (-not $malodyFullPackageFreshFilenameEditValueAvailable -or
      $malodyFullPackageFreshFilenameEditMirrorsSelection) -and
     [string]$malodyFullPackageFreshEvidence.nativeOpen.inputMode -ceq
        "exact native output-directory out.mcz UIItem/ListItem physical click + SelectionItemPattern IsSelected + exact address/selected-item path; legacy 1148/Edit mirror recorded and validated only when non-empty; no keyboard/IME/clipboard/value injection" -and
     [string]$malodyFullPackageFreshEvidence.nativeOpen.selectionSource -ceq
        "exact selected native file ListItem" -and
     $null -ne $malodyFullPackageFreshFileListSelection -and
     $malodyFullPackageFreshFileListSelection.PSObject.Properties.Name -ccontains
        "isSelectedBeforeClick" -and
     [string]$malodyFullPackageFreshFileListSelection.name -ceq
        $malodyFullPackageDestinationFileName -and
     [string]$malodyFullPackageFreshFileListSelection.className -ceq "UIItem" -and
     [string]$malodyFullPackageFreshFileListSelection.controlType -ceq
        "ControlType.ListItem" -and
     [double]$malodyFullPackageFreshFileListSelection.bounds.width -gt 1 -and
     [double]$malodyFullPackageFreshFileListSelection.bounds.height -gt 1 -and
     [bool]$malodyFullPackageFreshFileListSelection.selectionItemPatternAvailable -and
     [bool]$malodyFullPackageFreshFileListSelection.physicalClickAttempted -and
     [bool]$malodyFullPackageFreshFileListSelection.isSelectedAfterClick -and
     -not [bool]$malodyFullPackageFreshEvidence.nativeOpen.keyboardInputUsed -and
     -not [bool]$malodyFullPackageFreshEvidence.nativeOpen.imeCommitRequired -and
     -not [bool]$malodyFullPackageFreshEvidence.nativeOpen.imeCommitEnter -and
     -not [bool]$malodyFullPackageFreshEvidence.nativeOpen.clipboardUsed -and
     -not [bool]$malodyFullPackageFreshEvidence.nativeOpen.valueInjectionUsed -and
     [bool]$malodyFullPackageFreshEvidence.nativeOpen.dialogOpenAfterFileListSelection -and
     $null -eq $malodyFullPackageFreshEvidence.nativeOpen.focusBeforeInput -and
     $null -eq $malodyFullPackageFreshEvidence.nativeOpen.focusAfterUnicodeInput -and
     $null -eq $malodyFullPackageFreshEvidence.nativeOpen.inputStructSize -and
     $null -eq $malodyFullPackageFreshEvidence.nativeOpen.returnedUnicodeEventCount

$malodyFullPackagePreviewUiaFindAll =
    $malodyFullPackageFreshEvidence.preview.uiaFindAll
$malodyFullPackageTabPolling = $malodyFullPackageFreshEvidence.tabPolling
$malodyFullPackagePreviewTransientFailures = @(
    $malodyFullPackagePreviewUiaFindAll.transientFailures)
$malodyFullPackageTabTransientFailures = @(
    $malodyFullPackageTabPolling.transientFailures)
$allowedUiaTransientExceptionTypes =
    [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
[void]$allowedUiaTransientExceptionTypes.Add(
    "System.Runtime.InteropServices.COMException")
[void]$allowedUiaTransientExceptionTypes.Add(
    "System.Windows.Automation.ElementNotAvailableException")
$malodyFullPackagePreviewAttemptCount =
    [int]$malodyFullPackagePreviewUiaFindAll.attemptCount
$malodyFullPackagePreviewRetryBudgetMilliseconds =
    [int]$malodyFullPackagePreviewUiaFindAll.retryBudgetMilliseconds
$malodyFullPackagePreviewRetryDelayMilliseconds =
    [int]$malodyFullPackagePreviewUiaFindAll.retryDelayMilliseconds
$malodyFullPackagePreviewMaximumAttemptCount = 1 + [int][Math]::Ceiling(
    $malodyFullPackagePreviewRetryBudgetMilliseconds /
        [double]$malodyFullPackagePreviewRetryDelayMilliseconds)
$malodyFullPackagePreviewRetryMismatches = [Collections.Generic.List[string]]::new()
$malodyFullPackagePreviewFailureAttempts =
    [Collections.Generic.HashSet[int]]::new()
foreach ($failure in $malodyFullPackagePreviewTransientFailures) {
    $failureAttempt = [int]$failure.attempt
    if ($failureAttempt -lt 1 -or
        $failureAttempt -ge $malodyFullPackagePreviewAttemptCount -or
        -not $malodyFullPackagePreviewFailureAttempts.Add($failureAttempt) -or
        -not $allowedUiaTransientExceptionTypes.Contains(
            [string]$failure.exceptionType) -or
        [string]$failure.hResult -cnotmatch '^0x[0-9A-F]{8}$') {
        $malodyFullPackagePreviewRetryMismatches.Add([string]$failureAttempt)
    }
}
$malodyFullPackageTabFindAllAttemptCount =
    [int]$malodyFullPackageTabPolling.findAllAttemptCount
$malodyFullPackageTabTotalDeadlineMilliseconds =
    [int]$malodyFullPackageTabPolling.totalDeadlineMilliseconds
$malodyFullPackageTabPollDelayMilliseconds =
    [int]$malodyFullPackageTabPolling.pollDelayMilliseconds
$malodyFullPackageTabMaximumAttemptCount = [int][Math]::Ceiling(
    $malodyFullPackageTabTotalDeadlineMilliseconds /
        [double]$malodyFullPackageTabPollDelayMilliseconds)
$malodyFullPackageTabRetryMismatches = [Collections.Generic.List[string]]::new()
$malodyFullPackageTabFailureAttempts = [Collections.Generic.HashSet[int]]::new()
$malodyFullPackageTabFailureWindowHandles = [Collections.Generic.HashSet[long]]::new()
foreach ($failure in $malodyFullPackageTabTransientFailures) {
    $failureAttempt = [int]$failure.attempt
    $failureWindowHandle = [long]$failure.mainWindowHandle
    if ($failureAttempt -lt 1 -or
        $failureAttempt -ge $malodyFullPackageTabFindAllAttemptCount -or
        -not $malodyFullPackageTabFailureAttempts.Add($failureAttempt) -or
        $failureWindowHandle -eq 0 -or
        -not $allowedUiaTransientExceptionTypes.Contains(
            [string]$failure.exceptionType) -or
        [string]$failure.hResult -cnotmatch '^0x[0-9A-F]{8}$') {
        $malodyFullPackageTabRetryMismatches.Add([string]$failureAttempt)
    }
    if ($failureWindowHandle -ne 0) {
        [void]$malodyFullPackageTabFailureWindowHandles.Add($failureWindowHandle)
    }
}
if ($malodyFullPackagePreviewRetryBudgetMilliseconds -ne 5000 -or
    $malodyFullPackagePreviewRetryDelayMilliseconds -ne 100 -or
    $malodyFullPackagePreviewAttemptCount -lt 1 -or
    $malodyFullPackagePreviewAttemptCount -gt
        $malodyFullPackagePreviewMaximumAttemptCount -or
    $malodyFullPackagePreviewTransientFailures.Count -ge
        $malodyFullPackagePreviewAttemptCount -or
    $malodyFullPackagePreviewRetryMismatches.Count -ne 0 -or
    [int]$malodyFullPackageTabPolling.expectedChartCount -ne 8 -or
    $malodyFullPackageTabTotalDeadlineMilliseconds -ne 15000 -or
    $malodyFullPackageTabPollDelayMilliseconds -ne 180 -or
    $malodyFullPackageTabFindAllAttemptCount -lt 1 -or
    $malodyFullPackageTabFindAllAttemptCount -gt
        $malodyFullPackageTabMaximumAttemptCount -or
    $malodyFullPackageTabTransientFailures.Count -ge
        $malodyFullPackageTabFindAllAttemptCount -or
    $malodyFullPackageTabRetryMismatches.Count -ne 0 -or
    $malodyFullPackageTabFailureWindowHandles.Count -gt 1) {
    throw "Fresh MCZ UIA preview/tab polling did not stay within the explicit 5 s/15 s retry budgets or recorded a non-whitelisted/unstructured transient failure."
}

$malodyFullPackageStructuralEquivalence =
    $malodyFullPackageFreshEvidence.structuralEquivalence
$malodyFullPackageWorkingBaseline =
    $malodyFullPackageStructuralEquivalence.workingBaseline
$malodyFullPackageDirtyBeatProjection =
    $malodyFullPackageStructuralEquivalence.dirtyBeatProjection
$malodyFullPackageRawCompact =
    $malodyFullPackageStructuralEquivalence.rawCompact
$malodyFullPackageStructuralCounts =
    $malodyFullPackageStructuralEquivalence.counts
$malodyFullPackageResourceNormalization =
    $malodyFullPackageStructuralEquivalence.resourceReferenceNormalization
$malodyFullPackageBaselineBeat = @(
    $malodyFullPackageDirtyBeatProjection.baselineBeat)
$malodyFullPackageSubmittedBeat = @(
    $malodyFullPackageDirtyBeatProjection.submittedBeat)
$malodyFullPackageAllowedResourcePointers = @(
    $malodyFullPackageResourceNormalization.allowedJsonPointers)
$malodyFullPackageResourceDifferencesBefore = @(
    $malodyFullPackageResourceNormalization.differencesBefore)
$malodyFullPackageResourceMappings = @(
    $malodyFullPackageResourceNormalization.mappings)
$malodyFullPackageResourceDifferencesAfter = @(
    $malodyFullPackageResourceNormalization.differencesAfter)
$malodyFullPackageWorkingBaselinePath =
    [string]($malodyFullPackageWorkingBaseline.path)
$malodyFullPackageWorkingBaselineFullPath = if (
    [string]::IsNullOrWhiteSpace($malodyFullPackageWorkingBaselinePath)) {
    $null
} else {
    [IO.Path]::GetFullPath($malodyFullPackageWorkingBaselinePath)
}
$malodyFullPackageWorkingDocumentsBoundary =
    [IO.Path]::GetFullPath((Join-Path `
        $malodyFullPackageMainEditingRoot `
        "desktop-workspace\documents")).TrimEnd('\') + '\'
$malodyFullPackagePostExitWorkingSha256 = if (
    $null -ne $malodyFullPackageWorkingBaselineFullPath -and
    (Test-Path -LiteralPath $malodyFullPackageWorkingBaselineFullPath -PathType Leaf)) {
    (Get-FileHash `
        -LiteralPath $malodyFullPackageWorkingBaselineFullPath `
        -Algorithm SHA256).Hash
} else {
    $null
}
$malodyFullPackageExpectedResourceDifferencePaths = @(
    "/meta/background"
    "/meta/song/file"
    "/note/1608/sound"
)
$malodyFullPackageExpectedResourceDifferenceValues = @(
    [pscustomobject][ordered]@{
        expected = "string:InfinityHeaven.jpg"
        actual = "string:InfinityHeaven_2.jpg"
    }
    [pscustomobject][ordered]@{
        expected = "string:InfinityHeaven.ogg"
        actual = "string:InfinityHeaven_2.ogg"
    }
    [pscustomobject][ordered]@{
        expected = "string:InfinityHeaven.ogg"
        actual = "string:InfinityHeaven_2.ogg"
    }
)
$malodyFullPackageResourceDifferenceMismatches =
    [Collections.Generic.List[string]]::new()
for ($differenceIndex = 0;
     $differenceIndex -lt $malodyFullPackageResourceDifferencesBefore.Count;
     $differenceIndex++) {
    $difference = $malodyFullPackageResourceDifferencesBefore[$differenceIndex]
    if ($differenceIndex -ge $malodyFullPackageExpectedResourceDifferencePaths.Count -or
        -not (Test-ExactEvidencePropertyNames `
            -Value $difference `
            -Expected @("path", "kind", "expected", "actual")) -or
        [string]$difference.path -cne
            $malodyFullPackageExpectedResourceDifferencePaths[$differenceIndex] -or
        [string]$difference.kind -cne "changed" -or
        [string]$difference.expected -cne
            [string]$malodyFullPackageExpectedResourceDifferenceValues[$differenceIndex].expected -or
        [string]$difference.actual -cne
            [string]$malodyFullPackageExpectedResourceDifferenceValues[$differenceIndex].actual) {
        $malodyFullPackageResourceDifferenceMismatches.Add(
            [string]$differenceIndex)
    }
}
$malodyFullPackageBackgroundMappings = @(
    $malodyFullPackageResourceMappings | Where-Object {
        [string]$_.jsonPointer -ceq "/meta/background"
    })
$malodyFullPackageSongMappings = @(
    $malodyFullPackageResourceMappings | Where-Object {
        [string]$_.jsonPointer -ceq "/meta/song/file"
    })
$malodyFullPackageKeySoundMappings = @(
    $malodyFullPackageResourceMappings | Where-Object {
        [string]$_.jsonPointer -ceq "/note/1608/sound"
    })
$malodyFullPackageBackgroundMapping = if (
    $malodyFullPackageBackgroundMappings.Count -eq 1) {
    $malodyFullPackageBackgroundMappings[0]
} else { $null }
$malodyFullPackageSongMapping = if ($malodyFullPackageSongMappings.Count -eq 1) {
    $malodyFullPackageSongMappings[0]
} else { $null }
$malodyFullPackageKeySoundMapping = if (
    $malodyFullPackageKeySoundMappings.Count -eq 1) {
    $malodyFullPackageKeySoundMappings[0]
} else { $null }
$malodyFullPackageExpectedBackgroundSourcePath =
    Join-Path $malodyFullPackageSourceRoot "0\InfinityHeaven.jpg"
$malodyFullPackageExpectedSongSourcePath =
    Join-Path $malodyFullPackageSourceRoot "0\InfinityHeaven.ogg"
$malodyFullPackageExpectedBackgroundFreshPath =
    Join-Path $malodyFullPackageFreshWorkspaceRoot "out\InfinityHeaven_2.jpg"
$malodyFullPackageExpectedSongFreshPath =
    Join-Path $malodyFullPackageFreshWorkspaceRoot "out\InfinityHeaven_2.ogg"
$malodyFullPackageBackgroundArchiveEntries = @(
    $malodyFullPackageArchiveEvidence.entries | Where-Object {
        [string]$_.fullName -ceq "InfinityHeaven_2.jpg"
    })
$malodyFullPackageSongArchiveEntries = @(
    $malodyFullPackageArchiveEvidence.entries | Where-Object {
        [string]$_.fullName -ceq "InfinityHeaven_2.ogg"
    })
$malodyFullPackageBackgroundSourceSha256 =
    (Get-FileHash `
        -LiteralPath $malodyFullPackageExpectedBackgroundSourcePath `
        -Algorithm SHA256).Hash
$malodyFullPackageSongSourceSha256 =
    (Get-FileHash `
        -LiteralPath $malodyFullPackageExpectedSongSourcePath `
        -Algorithm SHA256).Hash
$malodyFullPackageBackgroundFreshSha256 =
    (Get-FileHash `
        -LiteralPath $malodyFullPackageExpectedBackgroundFreshPath `
        -Algorithm SHA256).Hash
$malodyFullPackageSongFreshSha256 =
    (Get-FileHash `
        -LiteralPath $malodyFullPackageExpectedSongFreshPath `
        -Algorithm SHA256).Hash
$malodyFullPackageBackgroundMappingShape = @(
    "jsonPointer", "sourceReference", "packagedReference", "sourcePath",
    "sourceLength", "sourceSha256", "archiveEntry", "archiveLength",
    "archiveSha256", "freshPath", "freshLength", "freshSha256")
$malodyFullPackageKeySoundMappingShape = @(
    "jsonPointer", "sourceReference", "packagedReference",
    "sharedResourcePointer", "sourceSha256", "archiveSha256", "freshSha256")

if (-not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageStructuralEquivalence `
        -Expected @(
            "preExportSessionStructureSha256", "workingBaseline",
            "dirtyBeatProjection", "rawCompact", "counts",
            "resourceReferenceNormalization", "verified")) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageWorkingBaseline `
        -Expected @("path", "sha256")) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageDirtyBeatProjection `
        -Expected @(
            "jsonPointer", "baselineBeat", "baselineAlreadySubmitted",
            "submittedBeat", "exactFreshMatchCount", "originalFreshMatchCount")) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageRawCompact `
        -Expected @(
            "archiveMainEntry", "archiveMainEntryLength",
            "archiveMainEntrySha256", "freshSourcePath", "freshSourceSha256",
            "freshEvidenceSourceSha256", "freshEvidenceStructureSha256", "allExact")) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageStructuralCounts `
        -Expected @("expected", "fresh")) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageStructuralCounts.expected `
        -Expected @("keyCount", "noteCount", "longNoteCount", "timingCount")) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageStructuralCounts.fresh `
        -Expected @("keyCount", "noteCount", "longNoteCount", "timingCount")) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageResourceNormalization `
        -Expected @(
            "rule", "allowedJsonPointers", "differenceCountBefore",
            "differencesBefore", "mappings", "differenceCountAfter",
            "differencesAfter", "resourceBytesVerified")) -or
    -not [bool]$malodyFullPackageStructuralEquivalence.verified -or
    [string]$malodyFullPackageStructuralEquivalence.preExportSessionStructureSha256 -cne
        [string]$malodyFullPackageInteractionGui.chart.structure.sha256 -or
    [string]$malodyFullPackageWorkingBaseline.sha256 -cne
        [string]$malodyFullPackageGui.chart.structure.sha256 -or
    $null -eq $malodyFullPackageWorkingBaselineFullPath -or
    -not $malodyFullPackageWorkingBaselineFullPath.StartsWith(
        $malodyFullPackageWorkingDocumentsBoundary,
        [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetFileName($malodyFullPackageWorkingBaselineFullPath) -cne
        "working.mc" -or
    $malodyFullPackagePostExitWorkingSha256 -cne
        [string]$malodyFullPackageStructuralEquivalence.preExportSessionStructureSha256 -or
    [string]$malodyFullPackageDirtyBeatProjection.jsonPointer -cne
        "/note/804/beat" -or
    -not (Test-ExactIntegerArray `
        -Value $malodyFullPackageBaselineBeat `
        -Expected @(182, 1, 4)) -or
    [bool]$malodyFullPackageDirtyBeatProjection.baselineAlreadySubmitted -or
    -not (Test-ExactIntegerArray `
        -Value $malodyFullPackageSubmittedBeat `
        -Expected @(182, 2, 8)) -or
    [int]$malodyFullPackageDirtyBeatProjection.exactFreshMatchCount -ne 1 -or
    [int]$malodyFullPackageDirtyBeatProjection.originalFreshMatchCount -ne 0 -or
    [string]$malodyFullPackageRawCompact.archiveMainEntry -cne
        [IO.Path]::GetFileName($malodyFullPackageMainChartPath) -or
    [long]$malodyFullPackageRawCompact.archiveMainEntryLength -ne 48852 -or
    [long]$malodyFullPackageRawCompact.archiveMainEntryLength -ne
        [long]$malodyFullPackageArchiveEvidence.mainChartEntry.length -or
    [string]$malodyFullPackageRawCompact.archiveMainEntrySha256 -cne
        [string]$malodyFullPackageArchiveEvidence.mainChartEntry.sha256 -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageRawCompact.freshSourcePath `
        -Right $malodyFullPackageFreshImportedSourcePath) -or
    [long](Get-Item -LiteralPath $malodyFullPackageFreshImportedSourcePath).Length -ne
        [long]$malodyFullPackageRawCompact.archiveMainEntryLength -or
    [string]$malodyFullPackageRawCompact.freshSourceSha256 -cne
        [string]$malodyFullPackageRawCompact.archiveMainEntrySha256 -or
    [string]$malodyFullPackageRawCompact.freshEvidenceSourceSha256 -cne
        [string]$malodyFullPackageRawCompact.archiveMainEntrySha256 -or
    [string]$malodyFullPackageRawCompact.freshEvidenceStructureSha256 -cne
        [string]$malodyFullPackageRawCompact.archiveMainEntrySha256 -or
    -not [bool]$malodyFullPackageRawCompact.allExact -or
    [string]$malodyFullPackageFreshEvidence.structureSha256 -cne
        [string]$malodyFullPackageRawCompact.freshEvidenceStructureSha256 -or
    [string]$malodyFullPackageFreshEvidence.sourceSha256 -cne
        [string]$malodyFullPackageRawCompact.freshSourceSha256 -or
    [string]$malodyFullPackageFreshInteractionGui.chart.sourceSha256 -cne
        [string]$malodyFullPackageRawCompact.freshEvidenceSourceSha256 -or
    [string]$malodyFullPackageFreshInteractionGui.chart.structure.sha256 -cne
        [string]$malodyFullPackageRawCompact.freshEvidenceStructureSha256 -or
    [int]$malodyFullPackageStructuralCounts.expected.keyCount -ne 4 -or
    [int]$malodyFullPackageStructuralCounts.expected.noteCount -ne 1608 -or
    [int]$malodyFullPackageStructuralCounts.expected.longNoteCount -ne 18 -or
    [int]$malodyFullPackageStructuralCounts.expected.timingCount -ne 1 -or
    [int]$malodyFullPackageStructuralCounts.fresh.keyCount -ne 4 -or
    [int]$malodyFullPackageStructuralCounts.fresh.noteCount -ne 1608 -or
    [int]$malodyFullPackageStructuralCounts.fresh.longNoteCount -ne 18 -or
    [int]$malodyFullPackageStructuralCounts.fresh.timingCount -ne 1 -or
    [int]$malodyFullPackageFreshInteractionGui.chart.structure.keyCount -ne 4 -or
    [int]$malodyFullPackageFreshInteractionGui.chart.structure.noteCount -ne 1608 -or
    [int]$malodyFullPackageFreshInteractionGui.chart.structure.longNoteCount -ne 18 -or
    [int]$malodyFullPackageFreshInteractionGui.chart.structure.timingCount -ne 1) {
    throw "Fresh MCZ structural equivalence did not prove the exact dirty session projection, compact main-entry bytes/counts, and clean post-import structure."
}

if ([string]$malodyFullPackageResourceNormalization.rule -cne
        "WPF-compatible deterministic same-name resource collision suffix _2" -or
    $malodyFullPackageAllowedResourcePointers.Count -ne 3 -or
    ($malodyFullPackageAllowedResourcePointers -join "`n") -cne
        ($malodyFullPackageExpectedResourceDifferencePaths -join "`n") -or
    [int]$malodyFullPackageResourceNormalization.differenceCountBefore -ne 3 -or
    $malodyFullPackageResourceDifferencesBefore.Count -ne 3 -or
    $malodyFullPackageResourceDifferenceMismatches.Count -ne 0 -or
    $malodyFullPackageResourceMappings.Count -ne 3 -or
    $malodyFullPackageBackgroundMappings.Count -ne 1 -or
    $malodyFullPackageSongMappings.Count -ne 1 -or
    $malodyFullPackageKeySoundMappings.Count -ne 1 -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageBackgroundMapping `
        -Expected $malodyFullPackageBackgroundMappingShape) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageSongMapping `
        -Expected $malodyFullPackageBackgroundMappingShape) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageKeySoundMapping `
        -Expected $malodyFullPackageKeySoundMappingShape) -or
    [string]$malodyFullPackageBackgroundMapping.sourceReference -cne
        "InfinityHeaven.jpg" -or
    [string]$malodyFullPackageBackgroundMapping.packagedReference -cne
        "InfinityHeaven_2.jpg" -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageBackgroundMapping.sourcePath `
        -Right $malodyFullPackageExpectedBackgroundSourcePath) -or
    [long]$malodyFullPackageBackgroundMapping.sourceLength -ne 122654 -or
    [long]$malodyFullPackageBackgroundMapping.sourceLength -ne
        [long](Get-Item -LiteralPath $malodyFullPackageExpectedBackgroundSourcePath).Length -or
    [string]$malodyFullPackageBackgroundMapping.sourceSha256 -cne
        $malodyFullPackageBackgroundSourceSha256 -or
    [string]$malodyFullPackageBackgroundMapping.archiveEntry -cne
        "InfinityHeaven_2.jpg" -or
    $malodyFullPackageBackgroundArchiveEntries.Count -ne 1 -or
    [long]$malodyFullPackageBackgroundMapping.archiveLength -ne 122654 -or
    [long]$malodyFullPackageBackgroundMapping.archiveLength -ne
        [long]$malodyFullPackageBackgroundArchiveEntries[0].length -or
    [string]$malodyFullPackageBackgroundMapping.archiveSha256 -cne
        [string]$malodyFullPackageBackgroundArchiveEntries[0].sha256 -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageBackgroundMapping.freshPath `
        -Right $malodyFullPackageExpectedBackgroundFreshPath) -or
    [long]$malodyFullPackageBackgroundMapping.freshLength -ne 122654 -or
    [long]$malodyFullPackageBackgroundMapping.freshLength -ne
        [long](Get-Item -LiteralPath $malodyFullPackageExpectedBackgroundFreshPath).Length -or
    [string]$malodyFullPackageBackgroundMapping.freshSha256 -cne
        $malodyFullPackageBackgroundFreshSha256 -or
    [string]$malodyFullPackageBackgroundMapping.sourceSha256 -cne
        [string]$malodyFullPackageBackgroundMapping.archiveSha256 -or
    [string]$malodyFullPackageBackgroundMapping.sourceSha256 -cne
        [string]$malodyFullPackageBackgroundMapping.freshSha256 -or
    [string]$malodyFullPackageSongMapping.sourceReference -cne
        "InfinityHeaven.ogg" -or
    [string]$malodyFullPackageSongMapping.packagedReference -cne
        "InfinityHeaven_2.ogg" -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageSongMapping.sourcePath `
        -Right $malodyFullPackageExpectedSongSourcePath) -or
    [long]$malodyFullPackageSongMapping.sourceLength -ne 3103260 -or
    [long]$malodyFullPackageSongMapping.sourceLength -ne
        [long](Get-Item -LiteralPath $malodyFullPackageExpectedSongSourcePath).Length -or
    [string]$malodyFullPackageSongMapping.sourceSha256 -cne
        $malodyFullPackageSongSourceSha256 -or
    [string]$malodyFullPackageSongMapping.archiveEntry -cne
        "InfinityHeaven_2.ogg" -or
    $malodyFullPackageSongArchiveEntries.Count -ne 1 -or
    [long]$malodyFullPackageSongMapping.archiveLength -ne 3103260 -or
    [long]$malodyFullPackageSongMapping.archiveLength -ne
        [long]$malodyFullPackageSongArchiveEntries[0].length -or
    [string]$malodyFullPackageSongMapping.archiveSha256 -cne
        [string]$malodyFullPackageSongArchiveEntries[0].sha256 -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageSongMapping.freshPath `
        -Right $malodyFullPackageExpectedSongFreshPath) -or
    [long]$malodyFullPackageSongMapping.freshLength -ne 3103260 -or
    [long]$malodyFullPackageSongMapping.freshLength -ne
        [long](Get-Item -LiteralPath $malodyFullPackageExpectedSongFreshPath).Length -or
    [string]$malodyFullPackageSongMapping.freshSha256 -cne
        $malodyFullPackageSongFreshSha256 -or
    [string]$malodyFullPackageSongMapping.sourceSha256 -cne
        [string]$malodyFullPackageSongMapping.archiveSha256 -or
    [string]$malodyFullPackageSongMapping.sourceSha256 -cne
        [string]$malodyFullPackageSongMapping.freshSha256 -or
    [string]$malodyFullPackageKeySoundMapping.sourceReference -cne
        "InfinityHeaven.ogg" -or
    [string]$malodyFullPackageKeySoundMapping.packagedReference -cne
        "InfinityHeaven_2.ogg" -or
    [string]$malodyFullPackageKeySoundMapping.sharedResourcePointer -cne
        "/meta/song/file" -or
    [string]$malodyFullPackageKeySoundMapping.sourceSha256 -cne
        [string]$malodyFullPackageSongMapping.sourceSha256 -or
    [string]$malodyFullPackageKeySoundMapping.archiveSha256 -cne
        [string]$malodyFullPackageSongMapping.archiveSha256 -or
    [string]$malodyFullPackageKeySoundMapping.freshSha256 -cne
        [string]$malodyFullPackageSongMapping.freshSha256 -or
    [int]$malodyFullPackageResourceNormalization.differenceCountAfter -ne 0 -or
    $malodyFullPackageResourceDifferencesAfter.Count -ne 0 -or
    -not [bool]$malodyFullPackageResourceNormalization.resourceBytesVerified) {
    throw "Fresh MCZ semantic normalization was not exactly the three WPF-compatible _2 reference mappings with source/archive/import bytes preserved and zero remaining differences."
}

$malodyFullPackageCapturedChartManifest =
    $malodyFullPackageFreshEvidence.chartManifest
$malodyFullPackageCapturedChartManifestEntries = @(
    $malodyFullPackageCapturedChartManifest.entries)
if (-not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageCapturedChartManifest `
        -Expected @(
            'schema', 'identityRule', 'sourceRoot', 'archivePath',
            'freshExtractionRoot', 'expectedChartCount', 'entryCount',
            'mainEntry', 'sourceRelativePaths', 'archiveChartEntries',
            'freshChartPaths', 'importedTabPaths', 'dirtyProjection',
            'resourceProjection', 'archiveFreshTree', 'entries',
            'importedTabPathsExact', 'verified')) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageCapturedChartManifest.dirtyProjection `
        -Expected @(
            'logicalJsonPointer', 'baselineBeat', 'submittedBeat',
            'logicalDifferenceCount', 'rawDifferenceCount', 'rawDifferences',
            'verified')) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageCapturedChartManifest.resourceProjection `
        -Expected @('rule', 'differenceCount', 'differences', 'mappings', 'verified')) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageCapturedChartManifest.archiveFreshTree `
        -Expected @(
            'expectedEntryCount', 'archiveEntryCount', 'freshFileCount',
            'freshDirectoryCount', 'workspaceTopLevelChildCount',
            'workspaceTopLevelDirectoryName', 'archiveContentSha256',
            'freshContentSha256', 'exact'))) {
    throw 'Fresh MCZ Capture chartManifest did not expose the exact v1 field contract.'
}

$malodyFullPackageIndependentChartManifestEvidence =
    Get-IndependentMalodyFullPackageChartManifestEvidence `
        -SourceRoot $malodyFullPackageSourceRoot `
        -ArchivePath $malodyFullPackageExportPath `
        -FreshWorkspaceRoot $malodyFullPackageFreshWorkspaceRoot `
        -MainEditingRoot $malodyFullPackageMainEditingRoot `
        -MainChartFileName ([IO.Path]::GetFileName($malodyFullPackageMainChartPath)) `
        -ImportedTabs @($malodyFullPackageFreshEvidence.importedTabs)

$malodyFullPackageCapturedChartEntryShape = @(
    'isMain', 'sourceRelativePath', 'sourcePath', 'sourceLength',
    'sourceSha256', 'sourceSemanticSha256', 'semanticBaselineKind',
    'semanticBaselinePath', 'expectedSemanticSha256', 'archiveEntry',
    'archiveLength', 'archiveSha256', 'archiveSemanticSha256',
    'freshRelativePath', 'freshPath', 'freshLength', 'freshSha256',
    'freshSemanticSha256', 'semanticDifferenceCount', 'semanticDifferences',
    'archiveFreshBytesExact', 'verified')
$malodyFullPackageCapturedChartEntryMismatches =
    [Collections.Generic.List[object]]::new()
if ($malodyFullPackageCapturedChartManifestEntries.Count -eq 8) {
    for ($entryIndex = 0; $entryIndex -lt 8; $entryIndex++) {
        $capturedEntry = $malodyFullPackageCapturedChartManifestEntries[$entryIndex]
        $independentEntry =
            $malodyFullPackageIndependentChartManifestEvidence.entries[$entryIndex]
        $expectedBaselineKind = if ([bool]$independentEntry.isMain) {
            'workingProjected'
        } else {
            'sourceMc'
        }
        if (-not (Test-ExactEvidencePropertyNames `
                -Value $capturedEntry `
                -Expected $malodyFullPackageCapturedChartEntryShape) -or
            [bool]$capturedEntry.isMain -ne [bool]$independentEntry.isMain -or
            [string]$capturedEntry.sourceRelativePath -cne
                [string]$independentEntry.sourceRelativePath -or
            -not (Test-PathEvidenceEqual `
                -Left $capturedEntry.sourcePath `
                -Right $independentEntry.sourcePath) -or
            [long]$capturedEntry.sourceLength -ne
                [long]$independentEntry.sourceLength -or
            [string]$capturedEntry.sourceSha256 -cne
                [string]$independentEntry.sourceSha256 -or
            [string]$capturedEntry.sourceSemanticSha256 -cne
                [string]$independentEntry.sourceSemanticSha256 -or
            [string]$capturedEntry.semanticBaselineKind -cne
                $expectedBaselineKind -or
            -not (Test-PathEvidenceEqual `
                -Left $capturedEntry.semanticBaselinePath `
                -Right $independentEntry.semanticBaselinePath) -or
            [string]$capturedEntry.expectedSemanticSha256 -cne
                [string]$independentEntry.expectedSemanticSha256 -or
            [string]$capturedEntry.archiveEntry -cne
                [string]$independentEntry.archiveEntry -or
            [long]$capturedEntry.archiveLength -ne
                [long]$independentEntry.archiveLength -or
            [string]$capturedEntry.archiveSha256 -cne
                [string]$independentEntry.archiveSha256 -or
            [string]$capturedEntry.archiveSemanticSha256 -cne
                [string]$independentEntry.archiveSemanticSha256 -or
            [string]$capturedEntry.freshRelativePath -cne
                [string]$independentEntry.freshRelativePath -or
            -not (Test-PathEvidenceEqual `
                -Left $capturedEntry.freshPath `
                -Right $independentEntry.freshPath) -or
            [long]$capturedEntry.freshLength -ne
                [long]$independentEntry.freshLength -or
            [string]$capturedEntry.freshSha256 -cne
                [string]$independentEntry.freshSha256 -or
            [string]$capturedEntry.freshSemanticSha256 -cne
                [string]$independentEntry.freshSemanticSha256 -or
            [int]$capturedEntry.semanticDifferenceCount -ne 0 -or
            @($capturedEntry.semanticDifferences).Count -ne 0 -or
            -not [bool]$capturedEntry.archiveFreshBytesExact -or
            -not [bool]$capturedEntry.verified) {
            $malodyFullPackageCapturedChartEntryMismatches.Add(
                [pscustomobject][ordered]@{
                    index = $entryIndex
                    sourceRelativePath = [string]$independentEntry.sourceRelativePath
                }) | Out-Null
        }
    }
}

$malodyFullPackageIndependentArchiveFreshTree =
    $malodyFullPackageIndependentChartManifestEvidence.archiveFreshTree
$malodyFullPackageIndependentDirtyProjection =
    $malodyFullPackageIndependentChartManifestEvidence.dirtyProjection
$malodyFullPackageIndependentResourceProjection =
    $malodyFullPackageIndependentChartManifestEvidence.resourceProjection
$malodyFullPackageCapturedDirtyProjectionJson = ConvertTo-Json `
    -InputObject @($malodyFullPackageCapturedChartManifest.dirtyProjection.rawDifferences) `
    -Depth 4 `
    -Compress
$malodyFullPackageIndependentDirtyProjectionJson = ConvertTo-Json `
    -InputObject @($malodyFullPackageIndependentDirtyProjection.rawDifferences) `
    -Depth 4 `
    -Compress
$malodyFullPackageCapturedResourceProjectionJson = ConvertTo-Json `
    -InputObject @($malodyFullPackageCapturedChartManifest.resourceProjection.differences) `
    -Depth 4 `
    -Compress
$malodyFullPackageIndependentResourceProjectionJson = ConvertTo-Json `
    -InputObject @($malodyFullPackageIndependentResourceProjection.differences) `
    -Depth 4 `
    -Compress
$malodyFullPackageCapturedEntrySourceRelativePaths = @(
    $malodyFullPackageCapturedChartManifestEntries | ForEach-Object {
        [string]$_.sourceRelativePath
    })
$malodyFullPackageCapturedEntryArchiveNames = @(
    $malodyFullPackageCapturedChartManifestEntries | ForEach-Object {
        [string]$_.archiveEntry
    })
$malodyFullPackageCapturedDirtyProjectionPaths = @(
    $malodyFullPackageCapturedChartManifest.dirtyProjection.rawDifferences |
        ForEach-Object { [string]$_.path })
$malodyFullPackageCapturedResourceProjectionPaths = @(
    $malodyFullPackageCapturedChartManifest.resourceProjection.differences |
        ForEach-Object { [string]$_.path })

if ([string]$malodyFullPackageCapturedChartManifest.schema -cne
        'lumachart.windows.avalonia.mcz-chart-manifest.v1' -or
    [string]$malodyFullPackageCapturedChartManifest.identityRule -cne
        'exact source relative path + case-preserved flat archive leaf + exact fresh relative path + imported-tab source path' -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageCapturedChartManifest.sourceRoot `
        -Right $malodyFullPackageIndependentChartManifestEvidence.sourceRoot) -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageCapturedChartManifest.archivePath `
        -Right $malodyFullPackageIndependentChartManifestEvidence.archivePath) -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageCapturedChartManifest.freshExtractionRoot `
        -Right $malodyFullPackageIndependentChartManifestEvidence.freshExtractionRoot) -or
    [int]$malodyFullPackageCapturedChartManifest.expectedChartCount -ne 8 -or
    [int]$malodyFullPackageCapturedChartManifest.entryCount -ne 8 -or
    [string]$malodyFullPackageCapturedChartManifest.mainEntry -cne
        [IO.Path]::GetFileName($malodyFullPackageMainChartPath) -or
    -not (Test-ExactStringArray `
        -Value @($malodyFullPackageCapturedChartManifest.sourceRelativePaths) `
        -Expected @($malodyFullPackageIndependentChartManifestEvidence.sourceRelativePaths)) -or
    -not (Test-ExactStringArray `
        -Value @($malodyFullPackageCapturedChartManifest.archiveChartEntries) `
        -Expected @($malodyFullPackageIndependentChartManifestEvidence.archiveChartEntries)) -or
    -not (Test-ExactStringArray `
        -Value @($malodyFullPackageCapturedChartManifest.freshChartPaths) `
        -Expected @($malodyFullPackageIndependentChartManifestEvidence.freshChartPaths) `
        -IgnoreCase) -or
    -not (Test-ExactStringArray `
        -Value @($malodyFullPackageCapturedChartManifest.importedTabPaths) `
        -Expected @($malodyFullPackageIndependentChartManifestEvidence.importedTabPaths) `
        -IgnoreCase) -or
    -not (Test-OrdinalStringOrder `
        -Value $malodyFullPackageCapturedEntrySourceRelativePaths) -or
    -not (Test-OrdinalStringOrder `
        -Value $malodyFullPackageCapturedEntryArchiveNames) -or
    -not (Test-CaseInsensitiveStringSetUnique `
        -Value $malodyFullPackageCapturedEntrySourceRelativePaths) -or
    -not (Test-CaseInsensitiveStringSetUnique `
        -Value $malodyFullPackageCapturedEntryArchiveNames) -or
    -not (Test-CaseInsensitiveStringSetUnique `
        -Value @($malodyFullPackageCapturedChartManifest.importedTabPaths)) -or
    [string]$malodyFullPackageCapturedChartManifest.dirtyProjection.logicalJsonPointer -cne
        '/note/804/beat' -or
    -not (Test-ExactIntegerArray `
        -Value @($malodyFullPackageCapturedChartManifest.dirtyProjection.baselineBeat) `
        -Expected @(182, 1, 4)) -or
    -not (Test-ExactIntegerArray `
        -Value @($malodyFullPackageCapturedChartManifest.dirtyProjection.submittedBeat) `
        -Expected @(182, 2, 8)) -or
    [int]$malodyFullPackageCapturedChartManifest.dirtyProjection.logicalDifferenceCount -ne 1 -or
    [int]$malodyFullPackageCapturedChartManifest.dirtyProjection.rawDifferenceCount -ne 2 -or
    -not (Test-ExactStringArray `
        -Value $malodyFullPackageCapturedDirtyProjectionPaths `
        -Expected @('/note/804/beat/1', '/note/804/beat/2')) -or
    $malodyFullPackageCapturedDirtyProjectionJson -cne
        $malodyFullPackageIndependentDirtyProjectionJson -or
    -not [bool]$malodyFullPackageCapturedChartManifest.dirtyProjection.verified -or
    [string]$malodyFullPackageCapturedChartManifest.resourceProjection.rule -cne
        'WPF-compatible deterministic same-name resource collision suffix _2' -or
    [int]$malodyFullPackageCapturedChartManifest.resourceProjection.differenceCount -ne 3 -or
    -not (Test-ExactStringArray `
        -Value $malodyFullPackageCapturedResourceProjectionPaths `
        -Expected @(
            '/meta/background', '/meta/song/file', '/note/1608/sound')) -or
    $malodyFullPackageCapturedResourceProjectionJson -cne
        $malodyFullPackageIndependentResourceProjectionJson -or
    ((ConvertTo-Json `
        -InputObject @($malodyFullPackageCapturedChartManifest.resourceProjection.mappings) `
        -Depth 8 `
        -Compress) -cne
     (ConvertTo-Json `
        -InputObject @($malodyFullPackageResourceMappings) `
        -Depth 8 `
        -Compress)) -or
    -not [bool]$malodyFullPackageCapturedChartManifest.resourceProjection.verified -or
    [int]$malodyFullPackageCapturedChartManifest.archiveFreshTree.expectedEntryCount -ne 13 -or
    [int]$malodyFullPackageCapturedChartManifest.archiveFreshTree.archiveEntryCount -ne 13 -or
    [int]$malodyFullPackageCapturedChartManifest.archiveFreshTree.freshFileCount -ne 13 -or
    [int]$malodyFullPackageCapturedChartManifest.archiveFreshTree.freshDirectoryCount -ne 0 -or
    [int]$malodyFullPackageCapturedChartManifest.archiveFreshTree.workspaceTopLevelChildCount -ne 1 -or
    [string]$malodyFullPackageCapturedChartManifest.archiveFreshTree.workspaceTopLevelDirectoryName -cne
        [IO.Path]::GetFileName(
            $malodyFullPackageIndependentChartManifestEvidence.freshExtractionRoot) -or
    [string]$malodyFullPackageCapturedChartManifest.archiveFreshTree.archiveContentSha256 -cne
        [string]$malodyFullPackageIndependentArchiveFreshTree.contentSha256 -or
    [string]$malodyFullPackageCapturedChartManifest.archiveFreshTree.freshContentSha256 -cne
        [string]$malodyFullPackageIndependentArchiveFreshTree.contentSha256 -or
    -not [bool]$malodyFullPackageCapturedChartManifest.archiveFreshTree.exact -or
    $malodyFullPackageCapturedChartManifestEntries.Count -ne 8 -or
    $malodyFullPackageCapturedChartEntryMismatches.Count -ne 0 -or
    -not [bool]$malodyFullPackageCapturedChartManifest.importedTabPathsExact -or
    -not [bool]$malodyFullPackageCapturedChartManifest.verified -or
    -not [bool]$malodyFullPackageIndependentChartManifestEvidence.verified -or
    [string]$malodyFullPackageIndependentChartManifestEvidence.entryOrder -cne
        'StringComparer.Ordinal by source relative path' -or
    -not [bool]$malodyFullPackageIndependentChartManifestEvidence.caseInsensitiveIdentityUnique -or
    [string]$malodyFullPackageIndependentArchiveFreshTree.rowOrder -cne
        'StringComparer.Ordinal by relativePath' -or
    [int]$malodyFullPackageIndependentArchiveFreshTree.archiveRows.Count -ne 13 -or
    [int]$malodyFullPackageIndependentArchiveFreshTree.freshRows.Count -ne 13 -or
    [int]$malodyFullPackageIndependentArchiveFreshTree.archive.directoryEntryCount -ne 0 -or
    [int]$malodyFullPackageIndependentArchiveFreshTree.fresh.directoryCount -ne 0 -or
    [int]$malodyFullPackageIndependentChartManifestEvidence.siblingSourceSemanticExactCount -ne 7 -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageIndependentChartManifestEvidence.postExitWorking.path `
        -Right $malodyFullPackageWorkingBaselineFullPath) -or
    [string]$malodyFullPackageIndependentChartManifestEvidence.postExitWorking.sha256 -cne
        [string]$malodyFullPackageStructuralEquivalence.preExportSessionStructureSha256) {
    throw 'Fresh MCZ chartManifest did not exactly match the wrapper-independent 8-chart semantic, 13-file archive/fresh byte-tree, post-exit working projection, and 8-tab path reconstruction.'
}

if (-not [bool]$malodyFullPackageCapture.capture.malodyFullPackageExportExercised -or
    -not [bool]$malodyFullPackageExportEvidence.explorerRevealSuppressedForEvidence -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageDestinationPath `
        -Right $malodyFullPackageExportPath) -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageExportEvidence.sourceRoot `
        -Right $malodyFullPackageSourceRoot) -or
    [int]$malodyFullPackageExportEvidence.expectedChartCount -ne 8 -or
    -not (Test-Path -LiteralPath $malodyFullPackageExportPath -PathType Leaf) -or
    [string]$malodyFullPackageGui.schema -cne
        "lumachart.windows.avalonia.gui-evidence.v12" -or
    [string]$malodyFullPackageInteractionGui.schema -cne
        "lumachart.windows.avalonia.gui-evidence.v12" -or
    -not [bool]$malodyFullPackageGui.evidenceExportRevealSuppressed -or
    -not [bool]$malodyFullPackageInteractionGui.evidenceExportRevealSuppressed -or
    -not [bool]$malodyFullPackageGui.evidenceFilePickerStartDirectoryInjected -or
    -not [bool]$malodyFullPackageInteractionGui.evidenceFilePickerStartDirectoryInjected -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageGui.evidenceFilePickerStartDirectory `
        -Right $malodyFullPackageDestinationDirectory) -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageInteractionGui.evidenceFilePickerStartDirectory `
        -Right $malodyFullPackageDestinationDirectory) -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackagePrimarySourcePath `
        -Right $malodyFullPackageMainChartPath) -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageInteractionSourcePath `
        -Right $malodyFullPackagePrimarySourcePath) -or
    [string]$malodyFullPackageGui.chart.sourceSha256 -cne
        $malodyFullPackageMainSourceSha256 -or
    [string]$malodyFullPackageInteractionGui.chart.sourceSha256 -cne
        $malodyFullPackageMainSourceSha256 -or
    [bool]$malodyFullPackageGui.timeline.sessionIsDirty -or
    -not [bool]$malodyFullPackageInteractionGui.timeline.sessionIsDirty -or
    [long]$malodyFullPackageGui.timeline.sessionChangeSerial -ne 0 -or
    [long]$malodyFullPackageInteractionGui.timeline.sessionChangeSerial -ne 1 -or
    [string]$malodyFullPackageInteractionGui.chart.structure.sha256 -ceq
        [string]$malodyFullPackageGui.chart.structure.sha256 -or
    [int]$malodyFullPackageInteractionGui.chart.structure.keyCount -ne
        [int]$malodyFullPackageGui.chart.structure.keyCount -or
    [int]$malodyFullPackageInteractionGui.chart.structure.noteCount -ne
        [int]$malodyFullPackageGui.chart.structure.noteCount -or
    [int]$malodyFullPackageInteractionGui.chart.structure.longNoteCount -ne
        [int]$malodyFullPackageGui.chart.structure.longNoteCount -or
    [int]$malodyFullPackageInteractionGui.chart.structure.timingCount -ne
        [int]$malodyFullPackageGui.chart.structure.timingCount) {
    throw "The real Malody FullPackage GUI did not preserve source identity while retaining exactly one unsaved committed document change."
}

$malodyFullPackageBeforeSelectedNotes = @($malodyFullPackageGui.timeline.selectedNotes)
$malodyFullPackageAfterSelectedNotes = @(
    $malodyFullPackageInteractionGui.timeline.selectedNotes)
if ($malodyFullPackageBeforeSelectedNotes.Count -ne 1 -or
    $malodyFullPackageAfterSelectedNotes.Count -ne 1 -or
    [string]$malodyFullPackageDirtyInjection.input -cne
        "UI Automation ValuePattern fields + state-confirmed physical Apply button click" -or
    [string]$malodyFullPackageCapture.capture.focusNotePropertyBeat -cne "182:1/4" -or
    [string]$malodyFullPackageBeforeSelectedNotes[0].noteId -cne
        [string]$malodyFullPackageAfterSelectedNotes[0].noteId -or
    [string]$malodyFullPackageDirtyInjection.noteId -cne
        [string]$malodyFullPackageAfterSelectedNotes[0].noteId -or
    -not [bool]$malodyFullPackageDirtyInjection.exactFocusedTapVerified -or
    [int]$malodyFullPackageBeforeSelectedNotes[0].lane -ne 1 -or
    [int]$malodyFullPackageAfterSelectedNotes[0].lane -ne 1 -or
    $null -ne $malodyFullPackageBeforeSelectedNotes[0].endBeat -or
    $null -ne $malodyFullPackageAfterSelectedNotes[0].endBeat -or
    -not (Test-BeatEvidenceEqual `
        -Left $malodyFullPackageDirtyInjection.beforeBeat `
        -Right $malodyFullPackageBeforeSelectedNotes[0].beat) -or
    [int]$malodyFullPackageDirtyInjection.beforeBeat.bar -ne 182 -or
    [int]$malodyFullPackageDirtyInjection.beforeBeat.numerator -ne 1 -or
    [int]$malodyFullPackageDirtyInjection.beforeBeat.denominator -ne 4 -or
    -not [bool]$malodyFullPackageDirtyInjection.submittedBeat.mathematicallyEquivalent -or
    -not [bool]$malodyFullPackageDirtyInjection.submittedBeat.expressionExpanded -or
    -not [bool]$malodyFullPackageDirtyInjection.submittedBeat.numeratorNonZero -or
    -not [bool]$malodyFullPackageDirtyInjection.submittedBeat.deliberatelyNonReduced -or
    -not [bool]$malodyFullPackageDirtyInjection.submittedBeat.exactExpansionVerified -or
    -not [bool]$malodyFullPackageDirtyInjection.submittedBeat.expectedExpressionVerified -or
    [int]$malodyFullPackageDirtyInjection.submittedBeat.greatestCommonDivisor -le 1 -or
    [int]$malodyFullPackageDirtyInjection.submittedBeat.bar -ne
        [int]$malodyFullPackageDirtyInjection.beforeBeat.bar -or
    [int]$malodyFullPackageDirtyInjection.submittedBeat.numerator -ne
        (2 * [int]$malodyFullPackageDirtyInjection.beforeBeat.numerator) -or
    [int]$malodyFullPackageDirtyInjection.submittedBeat.denominator -ne
        (2 * [int]$malodyFullPackageDirtyInjection.beforeBeat.denominator) -or
    [int]$malodyFullPackageDirtyInjection.submittedBeat.bar -ne 182 -or
    [int]$malodyFullPackageDirtyInjection.submittedBeat.numerator -ne 2 -or
    [int]$malodyFullPackageDirtyInjection.submittedBeat.denominator -ne 8 -or
    -not (Test-BeatEvidenceEqual `
        -Left $malodyFullPackageDirtyInjection.submittedBeat `
        -Right $malodyFullPackageAfterSelectedNotes[0].beat) -or
    [bool]$malodyFullPackageDirtyInjection.saveInvoked -or
    -not [bool]$malodyFullPackageDirtyInjection.otherFieldsPreserved) {
    throw "The Malody FullPackage dirty Note was not retained as the exact expanded rational Beat in the unsaved interaction runtime."
}

$malodyFullPackageExpectedApplyStatus =
    "已应用 Note 属性 · Beat 182:2/8 · 轨道 2 · Tap"
$malodyFullPackageApply = $malodyFullPackageDirtyInjection.apply
$malodyFullPackageApplyAttempts = @($malodyFullPackageApply.attempts)
$malodyFullPackageApplyInitialStatus = $malodyFullPackageApply.statusBeforeFirstClick
$malodyFullPackageApplyInitialStatusName =
    [string]$malodyFullPackageApplyInitialStatus.name
$malodyFullPackageApplyAttemptMismatches = [Collections.Generic.List[string]]::new()
for ($index = 0; $index -lt $malodyFullPackageApplyAttempts.Count; $index++) {
    $attempt = $malodyFullPackageApplyAttempts[$index]
    $isFinalAttempt = $index -eq ($malodyFullPackageApplyAttempts.Count - 1)
    $expectedWaitBudget = if ($index -eq 0) { 3000 } else { 5000 }
    $observedStatusNames = @($attempt.observedStatusNames)
    $unexpectedStatusNames = @($observedStatusNames | Where-Object {
            [string]$_ -cne $malodyFullPackageApplyInitialStatusName -and
            [string]$_ -cne $malodyFullPackageExpectedApplyStatus
        })
    $expectedStatusObservationCount = @($observedStatusNames | Where-Object {
            [string]$_ -ceq $malodyFullPackageExpectedApplyStatus
        }).Count
    $baselineStatusObservationCount = @($observedStatusNames | Where-Object {
            [string]$_ -ceq $malodyFullPackageApplyInitialStatusName
        }).Count
    if ([int]$attempt.attempt -ne ($index + 1) -or
        -not [bool]$attempt.mainWindowForegroundVerified -or
        [string]$attempt.button.name -cne "应用 Note" -or
        [string]$attempt.button.controlType -cne "ControlType.Button" -or
        -not [bool]$attempt.button.isEnabled -or
        [bool]$attempt.button.isOffscreen -or
        [double]$attempt.button.bounds.width -le 1 -or
        [double]$attempt.button.bounds.height -le 1 -or
        [string]$attempt.input -cne
            "physical Win32 mouse click at UI Automation bounds" -or
        [string]$attempt.statusBeforeClick.automationId -cne "Editor.Status" -or
        [string]$attempt.statusBeforeClick.name -cne
            $malodyFullPackageApplyInitialStatusName -or
        [string]$attempt.statusBeforeClick.controlType -cne "ControlType.Text" -or
        -not [bool]$attempt.statusBeforeClick.isEnabled -or
        [bool]$attempt.statusBeforeClick.isOffscreen -or
        [double]$attempt.statusBeforeClick.bounds.width -le 1 -or
        [double]$attempt.statusBeforeClick.bounds.height -le 1 -or
        -not [bool]$attempt.statusCheckedImmediatelyBeforeClick -or
        [bool]$attempt.scrollAfterStatusCheck -or
        [int]$attempt.statusWaitBudgetMilliseconds -ne $expectedWaitBudget -or
        [int]$attempt.statusObservationCount -lt 1 -or
        [long]$attempt.waitElapsedMilliseconds -lt 0 -or
        [long]$attempt.waitElapsedMilliseconds -gt ($expectedWaitBudget + 1500) -or
        -not [bool]$attempt.allStatusReadsSucceeded -or
        -not [bool]$attempt.baselineRetainedThroughout -or
        [string]$attempt.expectedStatus -cne $malodyFullPackageExpectedApplyStatus -or
        $observedStatusNames.Count -lt 1 -or
        $unexpectedStatusNames.Count -ne 0 -or
        [bool]$attempt.statusMatched -ne $isFinalAttempt -or
        [bool]$attempt.timedOut -eq $isFinalAttempt -or
        [bool]$attempt.retryEligible -eq $isFinalAttempt -or
        ($isFinalAttempt -and $expectedStatusObservationCount -lt 1) -or
        (-not $isFinalAttempt -and
            ([int]$attempt.statusObservationCount -lt 2 -or
             [long]$attempt.waitElapsedMilliseconds -lt $expectedWaitBudget -or
             $expectedStatusObservationCount -ne 0 -or
             $baselineStatusObservationCount -lt 1 -or
             $null -ne $attempt.status)) -or
        ($isFinalAttempt -and
            ([string]$attempt.status.automationId -cne "Editor.Status" -or
             [string]$attempt.status.name -cne $malodyFullPackageExpectedApplyStatus -or
             [string]$attempt.status.controlType -cne "ControlType.Text" -or
             -not [bool]$attempt.status.isEnabled -or
             [bool]$attempt.status.isOffscreen -or
             [double]$attempt.status.bounds.width -le 1 -or
             [double]$attempt.status.bounds.height -le 1))) {
        $malodyFullPackageApplyAttemptMismatches.Add("attempt-$($index + 1)")
    }
}

if ([string]$malodyFullPackageApply.path -cne
        "foreground verification + physical Win32 mouse clicks + exact Editor.Status observation" -or
    [int]$malodyFullPackageApply.maximumAttempts -ne 2 -or
    [int]$malodyFullPackageApply.attemptCount -ne
        $malodyFullPackageApplyAttempts.Count -or
    $malodyFullPackageApplyAttempts.Count -lt 1 -or
    $malodyFullPackageApplyAttempts.Count -gt 2 -or
    [bool]$malodyFullPackageApply.retryUsed -ne
        ($malodyFullPackageApplyAttempts.Count -gt 1) -or
    [int]$malodyFullPackageApply.boundedWaitBudgetMilliseconds -ne 8000 -or
    -not [bool]$malodyFullPackageApply.allPhysicalClicks -or
    [bool]$malodyFullPackageApply.automationFallbackUsed -or
    -not [bool]$malodyFullPackageApply.singleShotStatusReads -or
    -not [bool]$malodyFullPackageApply.retryRequiresStableBaseline -or
    -not [bool]$malodyFullPackageApply.duplicateHistoryMutationPrevented -or
    [string]$malodyFullPackageApply.expectedStatus -cne
        $malodyFullPackageExpectedApplyStatus -or
    -not [bool]$malodyFullPackageApply.statusMatched -or
    [string]$malodyFullPackageApplyInitialStatus.automationId -cne "Editor.Status" -or
    [string]::IsNullOrWhiteSpace($malodyFullPackageApplyInitialStatusName) -or
    $malodyFullPackageApplyInitialStatusName -ceq $malodyFullPackageExpectedApplyStatus -or
    $malodyFullPackageApplyInitialStatusName -cmatch '^应用 Note 属性失败：' -or
    [string]$malodyFullPackageApplyInitialStatus.controlType -cne "ControlType.Text" -or
    -not [bool]$malodyFullPackageApplyInitialStatus.isEnabled -or
    [bool]$malodyFullPackageApplyInitialStatus.isOffscreen -or
    [double]$malodyFullPackageApplyInitialStatus.bounds.width -le 1 -or
    [double]$malodyFullPackageApplyInitialStatus.bounds.height -le 1 -or
    [string]$malodyFullPackageApply.status.automationId -cne "Editor.Status" -or
    [string]$malodyFullPackageApply.status.name -cne
        $malodyFullPackageExpectedApplyStatus -or
    [string]$malodyFullPackageApply.status.controlType -cne "ControlType.Text" -or
    -not [bool]$malodyFullPackageApply.status.isEnabled -or
    [bool]$malodyFullPackageApply.status.isOffscreen -or
    [double]$malodyFullPackageApply.status.bounds.width -le 1 -or
    [double]$malodyFullPackageApply.status.bounds.height -le 1 -or
    $malodyFullPackageApplyAttemptMismatches.Count -ne 0) {
    throw "The Malody FullPackage dirty Note Apply action was not proven by bounded physical clicks and the exact successful Editor.Status transition."
}

$malodyFullPackageOptionsLaunch = $malodyFullPackageExportEvidence.options.launch
$malodyFullPackageOptionsLaunchAttempts = @($malodyFullPackageOptionsLaunch.attempts)
$malodyFullPackageOptionsLaunchAttemptMismatches = [Collections.Generic.List[string]]::new()
for ($index = 0; $index -lt $malodyFullPackageOptionsLaunchAttempts.Count; $index++) {
    $attempt = $malodyFullPackageOptionsLaunchAttempts[$index]
    $isFinalAttempt = $index -eq ($malodyFullPackageOptionsLaunchAttempts.Count - 1)
    $expectedWaitBudget = if ($index -eq 0) { 4500 } else { 6500 }
    $timeoutMessage = [string]$attempt.timeoutMessage
    if ([int]$attempt.attempt -ne ($index + 1) -or
        -not [bool]$attempt.mainWindowForegroundVerified -or
        [string]$attempt.button.automationId -cne "Editor.Export" -or
        [string]$attempt.button.name -cne "导出" -or
        [string]$attempt.button.helpText -cne
            "导出 Malody 或 osu!mania 单谱、整谱或倍速谱包" -or
        [string]$attempt.button.controlType -cne "ControlType.Button" -or
        -not [bool]$attempt.button.isEnabled -or
        [bool]$attempt.button.isOffscreen -or
        [double]$attempt.button.bounds.width -le 1 -or
        [double]$attempt.button.bounds.height -le 1 -or
        [string]$attempt.input -cne
            "physical Win32 mouse click at UI Automation bounds" -or
        [int]$attempt.dialogWaitBudgetMilliseconds -ne $expectedWaitBudget -or
        [bool]$attempt.dialogFound -ne $isFinalAttempt -or
        [bool]$attempt.timedOut -eq $isFinalAttempt -or
        ($isFinalAttempt -and -not [string]::IsNullOrEmpty($timeoutMessage)) -or
        (-not $isFinalAttempt -and $timeoutMessage -notmatch
            "^Timed out finding UI Automation id 'Export\.MalodyFullPackage\.Dialog' for process [0-9]+\.$")) {
        $malodyFullPackageOptionsLaunchAttemptMismatches.Add("attempt-$($index + 1)")
    }
}

if ([string]$malodyFullPackageExportEvidence.options.automationId -cne
        "Export.MalodyFullPackage.Dialog" -or
    [string]$malodyFullPackageOptionsLaunch.path -cne
        "foreground verification + physical Win32 mouse clicks + UI Automation observation" -or
    [int]$malodyFullPackageOptionsLaunch.maximumAttempts -ne 2 -or
    [int]$malodyFullPackageOptionsLaunch.attemptCount -ne
        $malodyFullPackageOptionsLaunchAttempts.Count -or
    $malodyFullPackageOptionsLaunchAttempts.Count -lt 1 -or
    $malodyFullPackageOptionsLaunchAttempts.Count -gt 2 -or
    [bool]$malodyFullPackageOptionsLaunch.retryUsed -ne
        ($malodyFullPackageOptionsLaunchAttempts.Count -gt 1) -or
    [int]$malodyFullPackageOptionsLaunch.boundedWaitBudgetMilliseconds -ne 11000 -or
    -not [bool]$malodyFullPackageOptionsLaunch.allPhysicalClicks -or
    [bool]$malodyFullPackageOptionsLaunch.automationFallbackUsed -or
    -not [bool]$malodyFullPackageOptionsLaunch.dialogFound -or
    $malodyFullPackageOptionsLaunchAttemptMismatches.Count -ne 0 -or
    [string]$malodyFullPackageExportEvidence.options.format.automationId -cne
        "Export.MalodyFullPackage.Dialog.Format" -or
    [string]$malodyFullPackageExportEvidence.options.format.name -cne
        "Malody (.mc / .mcz)" -or
    [string]$malodyFullPackageExportEvidence.options.mode.automationId -cne
        "Export.MalodyFullPackage.Dialog.Mode" -or
    [string]$malodyFullPackageExportEvidence.options.mode.name -cne
        "整谱压缩包" -or
    $null -ne $malodyFullPackageExportEvidence.options.rate -or
    $null -ne $malodyFullPackageExportEvidence.options.availability -or
    [string]$malodyFullPackageExportEvidence.options.preservePitch.automationId -cne
        "Export.MalodyFullPackage.Dialog.PreservePitch" -or
    [string]$malodyFullPackageExportEvidence.options.preservePitch.name -cne
        "音频变速不变调" -or
    [string]$malodyFullPackageExportEvidence.options.preservePitch.controlType -cne
        "ControlType.CheckBox" -or
    [bool]$malodyFullPackageExportEvidence.options.preservePitch.isEnabled -or
    [bool]$malodyFullPackageExportEvidence.options.preservePitch.isOffscreen -or
    [double]$malodyFullPackageExportEvidence.options.preservePitch.bounds.width -le 1 -or
    [double]$malodyFullPackageExportEvidence.options.preservePitch.bounds.height -le 1 -or
    -not [bool]$malodyFullPackageExportEvidence.options.defaultsVerified -or
    [string]$malodyFullPackageExportEvidence.nativeSave.title -cne "选择导出位置" -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageRequestedNativePath `
        -Right $malodyFullPackageDestinationPath) -or
    [string]$malodyFullPackageExportEvidence.nativeSave.requestedFileName -cne
        $malodyFullPackageDestinationFileName -or
    [string]$malodyFullPackageExportEvidence.nativeSave.initialFilenameValue -cne
        "HyuN - Infinity Heaven [4K Stream Lv.28].mcz" -or
    [string]$malodyFullPackageExportEvidence.nativeSave.expectedInitialFilenameValue -cne
        "HyuN - Infinity Heaven [4K Stream Lv.28].mcz" -or
    -not [bool]$malodyFullPackageExportEvidence.nativeSave.initialSuggestedFileNameVerified -or
    [string]$malodyFullPackageExportEvidence.nativeSave.filenameInput -cne
        "verified foreground + physical FileNameControlHost/1001 focus + Alt+N native filename focus + Ctrl+A + Win32 SendInput KEYEVENTF_UNICODE exact leaf; no Enter/value injection" -or
    [int]$malodyFullPackageExportEvidence.nativeSave.inputStructSize -ne 40 -or
    [int]$malodyFullPackageExportEvidence.nativeSave.unicodeCharCount -ne
        $malodyFullPackageUnicodeCharCount -or
    [int]$malodyFullPackageExportEvidence.nativeSave.expectedUnicodeEventCount -ne
        $malodyFullPackageUnicodeEventCount -or
    [int]$malodyFullPackageExportEvidence.nativeSave.returnedUnicodeEventCount -ne
        $malodyFullPackageUnicodeEventCount -or
    [int]$malodyFullPackageExportEvidence.nativeSave.win32LastError -ne 0 -or
    [bool]$malodyFullPackageExportEvidence.nativeSave.imeCommitRequired -or
    [bool]$malodyFullPackageExportEvidence.nativeSave.imeCommitEnter -or
    -not [bool]$malodyFullPackageExportEvidence.nativeSave.dialogOpenAfterUnicodeInput -or
    [int]$malodyFullPackageExportEvidence.nativeSave.filenameInputAttemptCount -ne
        $malodyFullPackageNativeSaveInputAttempts.Count -or
    $malodyFullPackageNativeSaveInputAttempts.Count -lt 1 -or
    $malodyFullPackageNativeSaveInputAttempts.Count -gt 3 -or
    $malodyFullPackageNativeSaveInputAttemptMismatches.Count -ne 0 -or
    $malodyFullPackageNativeSaveSuccessfulInputAttempts.Count -ne 1 -or
    $null -eq $malodyFullPackageNativeSaveLastInputAttempt -or
    -not $malodyFullPackageNativeSaveLastAttemptMatchesTopLevel -or
    [string]$malodyFullPackageNativeSaveInputAttempts[0].beforeName -cne
        "HyuN - Infinity Heaven [4K Stream Lv.28].mcz" -or
    -not [bool]$malodyFullPackageNativeSaveLastInputAttempt.exactUiaNameRetained -or
    [string]$malodyFullPackageNativeSaveLastInputAttempt.afterName -cne
        $malodyFullPackageDestinationFileName -or
    [string]$malodyFullPackageExportEvidence.nativeSave.filenameProvider -cne
        "Common Item Dialog FileNameControlHost/1001 UIA Name after Win32 SendInput KEYEVENTF_UNICODE" -or
    [string]$malodyFullPackageExportEvidence.nativeSave.filenameControl.automationId -cne
        "1001" -or
    [string]$malodyFullPackageExportEvidence.nativeSave.filenameControl.className -cne
        "Edit" -or
    [string]$malodyFullPackageExportEvidence.nativeSave.filenameControl.controlType -cne
        "ControlType.Pane" -or
    -not [bool]$malodyFullPackageExportEvidence.nativeSave.filenameControl.isEnabled -or
    [bool]$malodyFullPackageExportEvidence.nativeSave.filenameControl.isOffscreen -or
    [long]$malodyFullPackageExportEvidence.nativeSave.filenameControl.nativeWindowHandle -eq 0 -or
    [double]$malodyFullPackageExportEvidence.nativeSave.filenameControl.bounds.width -le 1 -or
    [double]$malodyFullPackageExportEvidence.nativeSave.filenameControl.bounds.height -le 1 -or
    [string]$malodyFullPackageExportEvidence.nativeSave.filenameValue -cne
        $malodyFullPackageDestinationFileName -or
    $null -ne $malodyFullPackageExportEvidence.nativeSave.valuePatternAvailable -or
    $null -ne $malodyFullPackageExportEvidence.nativeSave.filenameValuePattern -or
    [int]$malodyFullPackageExportEvidence.nativeSave.filenameWindowTextLength -ne
        ([string]$malodyFullPackageExportEvidence.nativeSave.filenameWindowText).Length -or
    [bool]$malodyFullPackageExportEvidence.nativeSave.filenameWindowTextAvailable -ne
        (-not [string]::IsNullOrWhiteSpace(
            [string]$malodyFullPackageExportEvidence.nativeSave.filenameWindowText)) -or
    ([bool]$malodyFullPackageExportEvidence.nativeSave.filenameWindowTextAvailable -and
     [string]$malodyFullPackageExportEvidence.nativeSave.filenameWindowText -cne
        $malodyFullPackageDestinationFileName) -or
    (Test-Path -LiteralPath $malodyFullPackageUnexpectedSuggestedPath) -or
    -not [bool]$malodyFullPackageExportEvidence.nativeSave.startDirectory.injected -or
    -not [bool]$malodyFullPackageExportEvidence.nativeSave.startDirectory.exactDirectoryVerified -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageExportEvidence.nativeSave.startDirectory.requestedDirectory `
        -Right $malodyFullPackageDestinationDirectory) -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageExportEvidence.nativeSave.startDirectory.reportedDirectory `
        -Right $malodyFullPackageDestinationDirectory) -or
    [string]$malodyFullPackageExportEvidence.nativeSave.extension -cne ".mcz" -or
    [string]$malodyFullPackageExportEvidence.nativeSave.filenameValue -notmatch
        '(?i)\.mcz$' -or
    [string]::IsNullOrWhiteSpace(
        [string]$malodyFullPackageExportEvidence.nativeSave.submitPath) -or
    [string]$malodyFullPackageExportEvidence.nativeSave.submitPath -cne
        "unique enabled visible native id=1 Save Button physical click" -or
    [string]$malodyFullPackageExportEvidence.nativeSave.submitControl.automationId -cne "1" -or
    [string]$malodyFullPackageExportEvidence.nativeSave.submitControl.className -cne
        "Button" -or
    [string]$malodyFullPackageExportEvidence.nativeSave.submitControl.controlType -cne
        "ControlType.Pane" -or
    -not [bool]$malodyFullPackageExportEvidence.nativeSave.submitControl.isEnabled -or
    [bool]$malodyFullPackageExportEvidence.nativeSave.submitControl.isOffscreen -or
    [long]$malodyFullPackageExportEvidence.nativeSave.submitControl.nativeWindowHandle -eq 0 -or
    [string]$malodyFullPackageExportEvidence.nativeSave.submitControl.name -notmatch
        '^(保存|Save)' -or
    [double]$malodyFullPackageExportEvidence.nativeSave.submitControl.bounds.width -le 1 -or
    [double]$malodyFullPackageExportEvidence.nativeSave.submitControl.bounds.height -le 1 -or
    -not [bool]$malodyFullPackageExportEvidence.nativeSave.dialogClosedAfterSubmit -or
    [string]$malodyFullPackageExportEvidence.result.automationId -cne
        "Export.MalodyFullPackage.Result.Dialog" -or
    [string]$malodyFullPackageExportEvidence.result.message.automationId -cne
        "Export.MalodyFullPackage.Result.Message" -or
    -not [bool]$malodyFullPackageExportEvidence.result.destinationMentioned -or
    -not [bool]$malodyFullPackageExportEvidence.result.visibleMessageSuccess -or
    -not [bool]$malodyFullPackageExportEvidence.result.resultIdentityVerified -or
    -not [bool]$malodyFullPackageExportEvidence.result.helpTextCompatible -or
    -not [bool]$malodyFullPackageExportEvidence.result.successTone) {
    throw "The Malody/FullPackage/1.0x options, native Windows Save picker, or owner-bound result dialog was not exercised with the actual destination."
}

if (-not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageArchiveEvidence.path `
        -Right $malodyFullPackageExportPath) -or
    [string]$malodyFullPackageArchiveEvidence.sha256 -cne
        (Get-FileHash -LiteralPath $malodyFullPackageExportPath -Algorithm SHA256).Hash -or
    [long]$malodyFullPackageArchiveEvidence.sizeBytes -ne
        [long](Get-Item -LiteralPath $malodyFullPackageExportPath).Length -or
    [int]$malodyFullPackageArchiveEvidence.entryCount -ne 13 -or
    [int]$malodyFullPackageArchiveEvidence.chartEntryCount -ne 8 -or
    @($malodyFullPackageArchiveEvidence.entries | Where-Object {
            -not [bool]$_.isMalodyChart
        }).Count -ne 5 -or
    -not [bool]$malodyFullPackageArchiveEvidence.allChartsValidJson -or
    -not [bool]$malodyFullPackageArchiveEvidence.allChartsCompact -or
    [int]$malodyFullPackageArchiveEvidence.mainChartEntryCount -ne 1 -or
    [IO.Path]::GetFileName(
        [string]$malodyFullPackageArchiveEvidence.mainChartEntry.fullName) -cne
        [IO.Path]::GetFileName($malodyFullPackageMainChartPath) -or
    [int]$malodyFullPackageArchiveEvidence.mainChartExactBeatMatchCount -ne 1 -or
    [int]$malodyFullPackageArchiveEvidence.mainChartOriginalBeatMatchCount -ne 0 -or
    [int]$malodyFullPackageArchiveEvidence.collisionEntryCount -ne 2 -or
    [int]$malodyFullPackageArchiveEvidence.unsafeEntryCount -ne 0 -or
    $malodyFullPackageForbiddenArchiveEntries.Count -ne 0 -or
    $malodyFullPackageResourceHashPairs.Count -ne 3 -or
    @($malodyFullPackageResourceHashPairs | Where-Object { -not $_.hashesMatch }).Count -ne 0 -or
    @($malodyFullPackageArchiveEvidence.entries | Where-Object {
            [string]::IsNullOrWhiteSpace([string]$_.sha256) -or
            [long]$_.length -le 0
        }).Count -ne 0) {
    throw "The actual MCZ is not the expected safe 13-entry package with 8 compact sibling MC files, five source/working resources, two collision suffixes, and the exact dirty main-chart Beat."
}

$malodyFullPackageCloseEvidence = $malodyFullPackageExportEvidence.close
$malodyFullPackageCloseAttempts = @($malodyFullPackageCloseEvidence.attempts)
$malodyFullPackageCloseAttemptMismatches =
    [Collections.Generic.List[object]]::new()
$malodyFullPackageCloseShape = @(
    'method', 'requestedAtUtc', 'closeMainWindowReturned',
    'waitBudgetMilliseconds', 'retryEarliestMilliseconds',
    'maximumAttemptCount', 'initialDialog', 'attemptCount', 'retryUsed',
    'attempts', 'dialogWasObservedClosed', 'dialogIdentityWasLost',
    'retryButtonUnavailableObservationCount', 'dialogStillPresent',
    'finalDialog', 'processExit', 'processExitObservedWithinBudget',
    'processExitObservedAtUtc', 'elapsedMilliseconds', 'exitCode',
    'invokePatternUsed', 'blindRetryUsed')
$malodyFullPackageCloseDialogShape = @(
    'expectedName', 'targetProcessId', 'nativeWindowHandle',
    'observedNativeWindowHandle', 'nativeWindowHandleMatches', 'isWindow',
    'uiaAvailable', 'name', 'processId', 'isEnabled', 'isOffscreen', 'bounds',
    'identityMatches', 'verified')
$malodyFullPackageCloseBoundsShape = @('left', 'top', 'width', 'height')
$malodyFullPackageCloseAttemptShape = @(
    'attemptNumber', 'reason', 'sameDialogAsInitial', 'observedAtUtc',
    'dialog', 'foregroundBeforeActivation', 'foregroundAtClick', 'button',
    'hitTest', 'physicalClick', 'invokePatternUsed', 'clickedAtUtc')
$malodyFullPackageCloseButtonShape = @(
    'expectedName', 'candidateCount', 'eligibleCount', 'name',
    'automationId', 'className', 'controlType', 'processId', 'isEnabled',
    'isOffscreen', 'bounds', 'verified')
$malodyFullPackageCloseHitTestShape = @(
    'cursorPoint', 'foregroundWindowHandle', 'expectedDialogWindowHandle',
    'hitWindowHandle', 'rootWindowHandle', 'rootThreadId', 'rootProcessId',
    'targetProcessId', 'hitWindowIsWindow', 'rootWindowIsWindow',
    'foregroundMatchesExpectedDialog', 'rootMatchesExpectedDialog',
    'rootProcessMatchesTarget', 'verified', 'observedAtUtc')
$malodyFullPackageCloseHitPointShape = @('x', 'y')
if ($null -eq $malodyFullPackageCloseEvidence -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageCloseEvidence `
        -Expected $malodyFullPackageCloseShape) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageCloseEvidence.initialDialog `
        -Expected $malodyFullPackageCloseDialogShape) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageCloseEvidence.initialDialog.bounds `
        -Expected $malodyFullPackageCloseBoundsShape) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageCloseEvidence.finalDialog `
        -Expected $malodyFullPackageCloseDialogShape) -or
    -not (Test-ExactEvidencePropertyNames `
        -Value $malodyFullPackageCloseEvidence.finalDialog.bounds `
        -Expected $malodyFullPackageCloseBoundsShape)) {
    throw 'Malody FullPackage close evidence did not expose the exact state-confirmed v1 field contract.'
}
for ($closeAttemptIndex = 0;
     $closeAttemptIndex -lt $malodyFullPackageCloseAttempts.Count;
     $closeAttemptIndex++) {
    $closeAttempt = $malodyFullPackageCloseAttempts[$closeAttemptIndex]
    $expectedCloseAttemptNumber = $closeAttemptIndex + 1
    $expectedCloseAttemptReason = if ($expectedCloseAttemptNumber -eq 1) {
        'initial state-confirmed physical discard'
    } else {
        'same-dialog state-confirmed retry after bounded wait'
    }
    $expectedHitPointX = [int][Math]::Round(
        [double]$closeAttempt.button.bounds.left +
            [double]$closeAttempt.button.bounds.width / 2)
    $expectedHitPointY = [int][Math]::Round(
        [double]$closeAttempt.button.bounds.top +
            [double]$closeAttempt.button.bounds.height / 2)
    $closeAttemptHitObservedAt =
        [DateTimeOffset]$closeAttempt.hitTest.observedAtUtc
    $closeAttemptObservedAt = [DateTimeOffset]$closeAttempt.observedAtUtc
    $closeAttemptClickedAt = [DateTimeOffset]$closeAttempt.clickedAtUtc
    if (-not (Test-ExactEvidencePropertyNames `
            -Value $closeAttempt `
            -Expected $malodyFullPackageCloseAttemptShape) -or
        -not (Test-ExactEvidencePropertyNames `
            -Value $closeAttempt.dialog `
            -Expected $malodyFullPackageCloseDialogShape) -or
        -not (Test-ExactEvidencePropertyNames `
            -Value $closeAttempt.dialog.bounds `
            -Expected $malodyFullPackageCloseBoundsShape) -or
        -not (Test-ExactEvidencePropertyNames `
            -Value $closeAttempt.button `
            -Expected $malodyFullPackageCloseButtonShape) -or
        -not (Test-ExactEvidencePropertyNames `
            -Value $closeAttempt.button.bounds `
            -Expected $malodyFullPackageCloseBoundsShape) -or
        -not (Test-ExactEvidencePropertyNames `
            -Value $closeAttempt.hitTest `
            -Expected $malodyFullPackageCloseHitTestShape) -or
        -not (Test-ExactEvidencePropertyNames `
            -Value $closeAttempt.hitTest.cursorPoint `
            -Expected $malodyFullPackageCloseHitPointShape) -or
        [int]$closeAttempt.attemptNumber -ne $expectedCloseAttemptNumber -or
        [string]$closeAttempt.reason -cne $expectedCloseAttemptReason -or
        -not [bool]$closeAttempt.sameDialogAsInitial -or
        [string]::IsNullOrWhiteSpace([string]$closeAttempt.observedAtUtc) -or
        [string]::IsNullOrWhiteSpace([string]$closeAttempt.clickedAtUtc) -or
        [string]$closeAttempt.dialog.expectedName -cne '未保存的更改' -or
        [int]$closeAttempt.dialog.targetProcessId -ne
            [int]$malodyFullPackageCapture.capture.processId -or
        [long]$closeAttempt.dialog.nativeWindowHandle -ne
            [long]$malodyFullPackageCloseEvidence.initialDialog.nativeWindowHandle -or
        [long]$closeAttempt.dialog.observedNativeWindowHandle -ne
            [long]$malodyFullPackageCloseEvidence.initialDialog.nativeWindowHandle -or
        -not [bool]$closeAttempt.dialog.nativeWindowHandleMatches -or
        -not [bool]$closeAttempt.dialog.isWindow -or
        -not [bool]$closeAttempt.dialog.uiaAvailable -or
        [string]$closeAttempt.dialog.name -cne '未保存的更改' -or
        [int]$closeAttempt.dialog.processId -ne
            [int]$malodyFullPackageCapture.capture.processId -or
        -not [bool]$closeAttempt.dialog.isEnabled -or
        [bool]$closeAttempt.dialog.isOffscreen -or
        [double]$closeAttempt.dialog.bounds.width -le 1 -or
        [double]$closeAttempt.dialog.bounds.height -le 1 -or
        -not [bool]$closeAttempt.dialog.identityMatches -or
        -not [bool]$closeAttempt.dialog.verified -or
        [long]$closeAttempt.foregroundAtClick -ne
            [long]$malodyFullPackageCloseEvidence.initialDialog.nativeWindowHandle -or
        [string]$closeAttempt.button.expectedName -cne '放弃更改' -or
        [int]$closeAttempt.button.candidateCount -lt 1 -or
        [int]$closeAttempt.button.eligibleCount -ne 1 -or
        [string]$closeAttempt.button.name -cne '放弃更改' -or
        [string]$closeAttempt.button.controlType -cne 'ControlType.Button' -or
        [int]$closeAttempt.button.processId -ne
            [int]$malodyFullPackageCapture.capture.processId -or
        -not [bool]$closeAttempt.button.isEnabled -or
        [bool]$closeAttempt.button.isOffscreen -or
        [double]$closeAttempt.button.bounds.width -le 1 -or
        [double]$closeAttempt.button.bounds.height -le 1 -or
        -not [bool]$closeAttempt.button.verified -or
        [int]$closeAttempt.hitTest.cursorPoint.x -ne $expectedHitPointX -or
        [int]$closeAttempt.hitTest.cursorPoint.y -ne $expectedHitPointY -or
        [long]$closeAttempt.hitTest.foregroundWindowHandle -ne
            [long]$malodyFullPackageCloseEvidence.initialDialog.nativeWindowHandle -or
        [long]$closeAttempt.hitTest.expectedDialogWindowHandle -ne
            [long]$malodyFullPackageCloseEvidence.initialDialog.nativeWindowHandle -or
        [long]$closeAttempt.hitTest.hitWindowHandle -eq 0 -or
        [long]$closeAttempt.hitTest.rootWindowHandle -ne
            [long]$malodyFullPackageCloseEvidence.initialDialog.nativeWindowHandle -or
        [uint32]$closeAttempt.hitTest.rootThreadId -eq 0 -or
        [uint32]$closeAttempt.hitTest.rootProcessId -ne
            [uint32]$malodyFullPackageCapture.capture.processId -or
        [int]$closeAttempt.hitTest.targetProcessId -ne
            [int]$malodyFullPackageCapture.capture.processId -or
        -not [bool]$closeAttempt.hitTest.hitWindowIsWindow -or
        -not [bool]$closeAttempt.hitTest.rootWindowIsWindow -or
        -not [bool]$closeAttempt.hitTest.foregroundMatchesExpectedDialog -or
        -not [bool]$closeAttempt.hitTest.rootMatchesExpectedDialog -or
        -not [bool]$closeAttempt.hitTest.rootProcessMatchesTarget -or
        -not [bool]$closeAttempt.hitTest.verified -or
        [string]::IsNullOrWhiteSpace(
            [string]$closeAttempt.hitTest.observedAtUtc) -or
        $closeAttemptHitObservedAt -gt $closeAttemptObservedAt -or
        $closeAttemptObservedAt -gt $closeAttemptClickedAt -or
        -not [bool]$closeAttempt.physicalClick -or
        [bool]$closeAttempt.invokePatternUsed) {
        $malodyFullPackageCloseAttemptMismatches.Add(
            [pscustomobject][ordered]@{
                index = $closeAttemptIndex
                attemptNumber = [int]$closeAttempt.attemptNumber
            }) | Out-Null
    }
}
$malodyFullPackageCloseRequestedAt =
    [DateTimeOffset]$malodyFullPackageCloseEvidence.requestedAtUtc
$malodyFullPackageRetryClickedAfterMilliseconds = if (
    $malodyFullPackageCloseAttempts.Count -eq 2) {
    ([DateTimeOffset]$malodyFullPackageCloseAttempts[1].clickedAtUtc -
        $malodyFullPackageCloseRequestedAt).TotalMilliseconds
} else { $null }
if ([string]$malodyFullPackageCloseEvidence.method -cne
        'CloseMainWindow + state-confirmed bounded physical discard click' -or
    -not [bool]$malodyFullPackageCloseEvidence.closeMainWindowReturned -or
    [int]$malodyFullPackageCloseEvidence.waitBudgetMilliseconds -ne 45000 -or
    [int]$malodyFullPackageCloseEvidence.retryEarliestMilliseconds -ne 15000 -or
    [int]$malodyFullPackageCloseEvidence.maximumAttemptCount -ne 2 -or
    [int]$malodyFullPackageCloseEvidence.attemptCount -lt 1 -or
    [int]$malodyFullPackageCloseEvidence.attemptCount -gt 2 -or
    [int]$malodyFullPackageCloseEvidence.attemptCount -ne
        $malodyFullPackageCloseAttempts.Count -or
    [bool]$malodyFullPackageCloseEvidence.retryUsed -ne
        ($malodyFullPackageCloseAttempts.Count -eq 2) -or
    ($malodyFullPackageCloseAttempts.Count -eq 2 -and
     [double]$malodyFullPackageRetryClickedAfterMilliseconds -lt 14500) -or
    [bool]$malodyFullPackageCloseEvidence.dialogIdentityWasLost -or
    [int]$malodyFullPackageCloseEvidence.retryButtonUnavailableObservationCount -lt 0 -or
    [bool]$malodyFullPackageCloseEvidence.dialogStillPresent -or
    -not [bool]$malodyFullPackageCloseEvidence.processExit -or
    -not [bool]$malodyFullPackageCloseEvidence.processExitObservedWithinBudget -or
    [string]::IsNullOrWhiteSpace(
        [string]$malodyFullPackageCloseEvidence.processExitObservedAtUtc) -or
    [double]$malodyFullPackageCloseEvidence.elapsedMilliseconds -le 0 -or
    [double]$malodyFullPackageCloseEvidence.elapsedMilliseconds -gt 45100 -or
    [int]$malodyFullPackageCloseEvidence.exitCode -ne 0 -or
    [bool]$malodyFullPackageCloseEvidence.invokePatternUsed -or
    [bool]$malodyFullPackageCloseEvidence.blindRetryUsed -or
    [string]$malodyFullPackageCloseEvidence.initialDialog.expectedName -cne
        '未保存的更改' -or
    [int]$malodyFullPackageCloseEvidence.initialDialog.targetProcessId -ne
        [int]$malodyFullPackageCapture.capture.processId -or
    [long]$malodyFullPackageCloseEvidence.initialDialog.nativeWindowHandle -eq 0 -or
    [long]$malodyFullPackageCloseEvidence.initialDialog.observedNativeWindowHandle -ne
        [long]$malodyFullPackageCloseEvidence.initialDialog.nativeWindowHandle -or
    -not [bool]$malodyFullPackageCloseEvidence.initialDialog.nativeWindowHandleMatches -or
    -not [bool]$malodyFullPackageCloseEvidence.initialDialog.isWindow -or
    -not [bool]$malodyFullPackageCloseEvidence.initialDialog.uiaAvailable -or
    [string]$malodyFullPackageCloseEvidence.initialDialog.name -cne
        '未保存的更改' -or
    [int]$malodyFullPackageCloseEvidence.initialDialog.processId -ne
        [int]$malodyFullPackageCapture.capture.processId -or
    -not [bool]$malodyFullPackageCloseEvidence.initialDialog.isEnabled -or
    [bool]$malodyFullPackageCloseEvidence.initialDialog.isOffscreen -or
    [double]$malodyFullPackageCloseEvidence.initialDialog.bounds.width -le 1 -or
    [double]$malodyFullPackageCloseEvidence.initialDialog.bounds.height -le 1 -or
    -not [bool]$malodyFullPackageCloseEvidence.initialDialog.identityMatches -or
    -not [bool]$malodyFullPackageCloseEvidence.initialDialog.verified -or
    [string]$malodyFullPackageCloseEvidence.finalDialog.expectedName -cne
        '未保存的更改' -or
    [int]$malodyFullPackageCloseEvidence.finalDialog.targetProcessId -ne
        [int]$malodyFullPackageCapture.capture.processId -or
    [long]$malodyFullPackageCloseEvidence.finalDialog.nativeWindowHandle -ne
        [long]$malodyFullPackageCloseEvidence.initialDialog.nativeWindowHandle -or
    [long]$malodyFullPackageCloseEvidence.finalDialog.observedNativeWindowHandle -ne 0 -or
    [bool]$malodyFullPackageCloseEvidence.finalDialog.nativeWindowHandleMatches -or
    [bool]$malodyFullPackageCloseEvidence.finalDialog.isWindow -or
    [bool]$malodyFullPackageCloseEvidence.finalDialog.uiaAvailable -or
    [int]$malodyFullPackageCloseEvidence.finalDialog.processId -ne 0 -or
    [bool]$malodyFullPackageCloseEvidence.finalDialog.isEnabled -or
    -not [bool]$malodyFullPackageCloseEvidence.finalDialog.isOffscreen -or
    [bool]$malodyFullPackageCloseEvidence.finalDialog.identityMatches -or
    [bool]$malodyFullPackageCloseEvidence.finalDialog.verified -or
    $malodyFullPackageCloseAttemptMismatches.Count -ne 0) {
    throw 'Malody FullPackage main process did not use the strict one-or-two-attempt state-confirmed physical discard close path.'
}

if (-not [bool]$malodyFullPackageExportEvidence.sourceTreeUnchanged -or
    -not [bool]$malodyFullPackageExportEvidence.workingTreeUnchangedByExport -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageExportEvidence.workingTreeAfterDirty.root `
        -Right $malodyFullPackageMainEditingRoot) -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageExportEvidence.workingTreeAfterExport.root `
        -Right $malodyFullPackageMainEditingRoot) -or
    -not (Test-CaptureDirectoryTreeEvidenceEqual `
        -Before $malodyFullPackageExportEvidence.workingTreeAfterDirty `
        -After $malodyFullPackageExportEvidence.workingTreeAfterExport) -or
    -not [bool]$malodyFullPackageExportEvidence.scratch.clean -or
    [int]$malodyFullPackageExportEvidence.scratch.childCount -ne 0 -or
    -not [bool]$malodyFullPackageExportEvidence.mainProcessNormalExit -or
    -not [bool]$malodyFullPackageExportEvidence.mainSessionScratchRemovedAfterExit -or
    $malodyFullPackageMainProcess.Count -ne 0 -or
    (Test-Path -LiteralPath ([string]$malodyFullPackageExportEvidence.scratch.sessionScratchRoot)) -or
    -not (Test-DirectoryTreeEvidenceEqual `
        -Before $malodyFullPackageSourceTreeBefore `
        -After $malodyFullPackageSourceTreeAfter) -or
    (Get-FileHash -LiteralPath $malodyFullPackageMainChartPath -Algorithm SHA256).Hash -cne
        $malodyFullPackageMainSourceSha256) {
    throw "Malody FullPackage export changed the isolated source/dirty working tree or left its owned process/GUID scratch staging behind."
}

if (-not [bool]$malodyFullPackageFreshEvidence.verified -or
    -not [bool]$malodyFullPackageFreshEvidence.normalExit -or
    -not [bool]$malodyFullPackageFreshEvidence.sessionScratchRemovedAfterExit -or
    $malodyFullPackageFreshProcess.Count -ne 0 -or
    (Test-Path -LiteralPath ([string]$malodyFullPackageFreshEvidence.sessionScratchRoot)) -or
    [string]$malodyFullPackageFreshEvidence.nativeOpen.title -cne
        "打开 Malody / osu! 谱面或谱包" -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageFreshRequestedPath `
        -Right $malodyFullPackageDestinationPath) -or
    -not [bool]$malodyFullPackageFreshEvidence.nativeOpen.startDirectory.injected -or
    -not [bool]$malodyFullPackageFreshEvidence.nativeOpen.startDirectory.exactDirectoryVerified -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageFreshEvidence.nativeOpen.startDirectory.requestedDirectory `
        -Right $malodyFullPackageDestinationDirectory) -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageFreshEvidence.nativeOpen.startDirectory.reportedDirectory `
        -Right $malodyFullPackageDestinationDirectory) -or
    -not $malodyFullPackageFreshFilenameProviderVerified -or
    [double]$malodyFullPackageFreshFilenameControl.bounds.width -le 1 -or
    [double]$malodyFullPackageFreshFilenameControl.bounds.height -le 1 -or
    [string]$malodyFullPackageFreshEvidence.nativeOpen.filenameValue -cne
        $malodyFullPackageDestinationFileName -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageFreshEvidence.nativeOpen.resolvedSelectionPath `
        -Right $malodyFullPackageDestinationPath) -or
    [string]::IsNullOrWhiteSpace(
        [string]$malodyFullPackageFreshEvidence.nativeOpen.submitPath) -or
    [string]$malodyFullPackageFreshEvidence.nativeOpen.submitPath -cne
        "unique native id=1 Open Button physical click" -or
    [string]$malodyFullPackageFreshEvidence.nativeOpen.submitControl.automationId -cne "1" -or
    [string]$malodyFullPackageFreshEvidence.nativeOpen.submitControl.className -cne "Button" -or
    [string]$malodyFullPackageFreshEvidence.nativeOpen.submitControl.controlType -cne
        "ControlType.Pane" -or
    -not [bool]$malodyFullPackageFreshEvidence.nativeOpen.submitControl.isEnabled -or
    [bool]$malodyFullPackageFreshEvidence.nativeOpen.submitControl.isOffscreen -or
    [string]$malodyFullPackageFreshEvidence.nativeOpen.submitControl.name -notmatch
        '^(打开|Open)' -or
    [long]$malodyFullPackageFreshEvidence.nativeOpen.submitControl.nativeWindowHandle -eq 0 -or
    [double]$malodyFullPackageFreshEvidence.nativeOpen.submitControl.bounds.width -le 1 -or
    [double]$malodyFullPackageFreshEvidence.nativeOpen.submitControl.bounds.height -le 1 -or
    -not [bool]$malodyFullPackageFreshEvidence.nativeOpen.dialogClosedAfterSubmit -or
    [string]$malodyFullPackageFreshEvidence.preview.title -cne "谱包已导入" -or
    [string]$malodyFullPackageFreshEvidence.preview.countText -notlike
        "8 张键音谱可打开*0 张其他模式*0 张损坏*" -or
    [string]$malodyFullPackageFreshEvidence.preview.openButton -cne "打开 8 张" -or
    [int]$malodyFullPackageFreshEvidence.importedTabCount -ne 8 -or
    $malodyFullPackageImportedMainTabs.Count -ne 1 -or
    $malodyFullPackageFreshMcFiles.Count -ne 8 -or
    $malodyFullPackageFreshResourceHashPairs.Count -ne 3 -or
    @($malodyFullPackageFreshResourceHashPairs | Where-Object {
            -not $_.hashesMatch
        }).Count -ne 0 -or
    -not $malodyFullPackageFreshImportedSourcePath.StartsWith(
        $malodyFullPackageFreshWorkspaceBoundary,
        [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetFileName($malodyFullPackageFreshImportedSourcePath) -cne
        [IO.Path]::GetFileName($malodyFullPackageMainChartPath) -or
    [string]$malodyFullPackageFreshEvidence.sourceSha256 -cne
        [string]$malodyFullPackageArchiveEvidence.mainChartEntry.sha256 -or
    -not [bool]$malodyFullPackageFreshEvidence.cleanSession -or
    -not [bool]$malodyFullPackageFreshEvidence.exactBeat.verified -or
    [int]$malodyFullPackageFreshEvidence.exactBeat.bar -ne 182 -or
    [int]$malodyFullPackageFreshEvidence.exactBeat.numerator -ne 2 -or
    [int]$malodyFullPackageFreshEvidence.exactBeat.denominator -ne 8 -or
    [int]$malodyFullPackageFreshEvidence.exactBeat.lane -ne 1 -or
    [int]$malodyFullPackageFreshEvidence.exactBeat.exactMatchCount -ne 1 -or
    [int]$malodyFullPackageFreshEvidence.exactBeat.originalRepresentationMatchCount -ne 0 -or
    [bool]$malodyFullPackageFreshInteractionGui.timeline.sessionIsDirty -or
    [long]$malodyFullPackageFreshInteractionGui.timeline.sessionChangeSerial -ne 0 -or
    [string]$malodyFullPackageFreshInteractionGui.chart.sourceSha256 -cne
        [string]$malodyFullPackageArchiveEvidence.mainChartEntry.sha256 -or
    -not [bool]$malodyFullPackageFreshGui.evidenceInteractionFollowsActiveTab -or
    -not [bool]$malodyFullPackageFreshInteractionGui.evidenceInteractionFollowsActiveTab -or
    -not [bool]$malodyFullPackageFreshGui.evidenceFilePickerStartDirectoryInjected -or
    -not [bool]$malodyFullPackageFreshInteractionGui.evidenceFilePickerStartDirectoryInjected -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageFreshGui.evidenceFilePickerStartDirectory `
        -Right $malodyFullPackageDestinationDirectory) -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyFullPackageFreshInteractionGui.evidenceFilePickerStartDirectory `
        -Right $malodyFullPackageDestinationDirectory)) {
    throw "A fresh second Avalonia process did not use native Open, preview 8 valid charts, open 8 imported tabs, explicitly select the main chart, preserve structure/hash, stay clean, and exit without scratch."
}

if ((Get-FileHash -LiteralPath $malodyFullPackageGuiPath -Algorithm SHA256).Hash -cne
        [string]$malodyFullPackageCapture.capture.evidenceSha256 -or
    (Get-FileHash -LiteralPath $malodyFullPackageInteractionGuiPath -Algorithm SHA256).Hash -cne
        [string]$malodyFullPackageCapture.capture.interactionEvidenceSha256 -or
    (Get-FileHash -LiteralPath $malodyFullPackageFreshGuiPath -Algorithm SHA256).Hash -cne
        [string]$malodyFullPackageFreshEvidence.primaryEvidenceSha256 -or
    (Get-FileHash -LiteralPath $malodyFullPackageFreshInteractionGuiPath -Algorithm SHA256).Hash -cne
        [string]$malodyFullPackageFreshEvidence.interactionEvidenceSha256) {
    throw "The Malody FullPackage primary/interaction/fresh runtime files do not match their capture-reported SHA-256 values."
}

$osuFullPackageExportEvidence =
    $osuFullPackageCapture.capture.malodyFullPackageExport
$osuFullPackageFreshEvidence = $osuFullPackageExportEvidence.freshImport
$osuFullPackageArchiveEvidence = $osuFullPackageExportEvidence.archive
$osuFullPackageSourceTreeAfter = Get-DirectoryTreeEvidence -Path $osuFullPackageSourceRoot
$osuFullPackageArchiveManifest =
    Get-FormalZipFileManifestEvidence -Path $osuFullPackageExportPath
$osuFullPackageFreshTopFiles = @(
    Get-ChildItem -LiteralPath $osuFullPackageFreshWorkspaceRoot -File -Force)
$osuFullPackageFreshTopDirectories = @(
    Get-ChildItem -LiteralPath $osuFullPackageFreshWorkspaceRoot -Directory -Force)
if ($osuFullPackageFreshTopFiles.Count -ne 0 -or
    $osuFullPackageFreshTopDirectories.Count -ne 1) {
    throw "Fresh OSZ extraction did not produce one exact top-level package directory."
}
$osuFullPackageFreshManifest = Get-FormalFlatFileManifestEvidence `
    -Root $osuFullPackageFreshTopDirectories[0].FullName
$osuFullPackageArchiveFreshMismatches = @(
    foreach ($archiveRow in $osuFullPackageArchiveManifest.rows) {
        $freshMatches = @($osuFullPackageFreshManifest.rows | Where-Object {
                [string]$_.relativePath -ceq [string]$archiveRow.relativePath
            })
        if ($freshMatches.Count -ne 1 -or
            [long]$freshMatches[0].length -ne [long]$archiveRow.length -or
            [string]$freshMatches[0].sha256 -cne [string]$archiveRow.sha256) {
            [string]$archiveRow.relativePath
        }
    })
$osuFullPackageMainArchiveRows = @($osuFullPackageArchiveManifest.rows | Where-Object {
        [string]$_.relativePath -ceq $osuFullPackageMainFileName
    })
$osuFullPackageSiblingArchiveRows = @($osuFullPackageArchiveManifest.rows | Where-Object {
        [string]$_.relativePath -ceq $osuFullPackageSiblingFileName
    })
$osuFullPackageMainFreshPath =
    Join-Path $osuFullPackageFreshTopDirectories[0].FullName $osuFullPackageMainFileName
$osuFullPackageSiblingFreshPath =
    Join-Path $osuFullPackageFreshTopDirectories[0].FullName $osuFullPackageSiblingFileName
$osuFullPackageMainText = Get-Content -LiteralPath $osuFullPackageMainFreshPath -Raw
$osuFullPackageExpectedHitCount = @($osuFullPackageMainText -split "`r?`n" |
    Where-Object { $_ -match '^448,192,11920,(1|128),' }).Count
$osuFullPackageOriginalHitCount = @($osuFullPackageMainText -split "`r?`n" |
    Where-Object { $_ -match '^320,192,11920,(1|128),' }).Count
$osuFullPackageExpectedResourceMultiplicity = [ordered]@{
    "audio.mp3" = 2
    "BG1.jpg" = 2
    "BG3.png" = 1
}
$osuFullPackageResourceMismatches = @(
    foreach ($entry in $osuFullPackageExpectedResourceMultiplicity.GetEnumerator()) {
        $resourceName = [string]$entry.Key
        $sourceHash = [string]$osuFullPackageExpectedSourceHashes[$resourceName]
        $archiveMatches = @($osuFullPackageArchiveManifest.rows | Where-Object {
                [IO.Path]::GetExtension([string]$_.relativePath) -ceq
                    [IO.Path]::GetExtension([string]$entry.Key) -and
                [string]$_.sha256 -ceq $sourceHash
            })
        if ($archiveMatches.Count -ne [int]$entry.Value) {
            [string]$entry.Key
        }
    })
$osuFullPackageCalibration = $osuFullPackageFreshEvidence.osuImportModes
$osuFullPackageCalibrationDialogs = @($osuFullPackageCalibration.dialogs)
$osuFullPackageExpectedCalibrationNames = @(
    $osuFullPackageMainFileName,
    $osuFullPackageSiblingFileName)
$osuFullPackageMainProcess = @(
    Get-Process -Id ([int]$osuFullPackageCapture.capture.processId) -ErrorAction SilentlyContinue)
$osuFullPackageFreshProcess = @(
    Get-Process -Id ([int]$osuFullPackageFreshEvidence.processId) -ErrorAction SilentlyContinue)
if ([string]$osuFullPackageCapture.capture.fullPackageExportFormat -cne "OsuMania" -or
    -not [bool]$osuFullPackageCapture.capture.malodyFullPackageExportExercised -or
    [string]$osuFullPackageExportEvidence.format -cne "OsuMania" -or
    -not (Test-PathEvidenceEqual `
        -Left $osuFullPackageExportEvidence.destinationPath `
        -Right $osuFullPackageExportPath) -or
    -not [bool]$osuFullPackageExportEvidence.options.defaultsVerified -or
    -not [bool]$osuFullPackageExportEvidence.options.formatSelection.physicalClick -or
    [string]$osuFullPackageExportEvidence.options.format.name -cne
        "osu!mania v14 (.osu / .osz)" -or
    -not [bool]$osuFullPackageExportEvidence.options.osuDifficulty.retained -or
    [string]$osuFullPackageExportEvidence.options.osuDifficulty.retainedOverallDifficulty -cne
        "8.75" -or
    [string]$osuFullPackageExportEvidence.options.osuDifficulty.retainedHpDrainRate -cne "9" -or
    -not [bool]$osuFullPackageExportEvidence.result.successTone -or
    -not [bool]$osuFullPackageExportEvidence.sourceTreeUnchanged -or
    -not [bool]$osuFullPackageExportEvidence.workingTreeUnchangedByExport -or
    -not [bool]$osuFullPackageExportEvidence.scratch.clean -or
    [int]$osuFullPackageExportEvidence.scratch.childCount -ne 0 -or
    -not [bool]$osuFullPackageExportEvidence.mainProcessNormalExit -or
    -not [bool]$osuFullPackageExportEvidence.mainSessionScratchRemovedAfterExit -or
    -not [bool]$osuFullPackageExportEvidence.close.processExit -or
    [int]$osuFullPackageExportEvidence.close.exitCode -ne 0 -or
    $osuFullPackageMainProcess.Count -ne 0 -or
    (Test-Path -LiteralPath ([string]$osuFullPackageExportEvidence.scratch.sessionScratchRoot)) -or
    -not (Test-DirectoryTreeEvidenceEqual `
        -Before $osuFullPackageSourceTreeBefore `
        -After $osuFullPackageSourceTreeAfter)) {
    throw "OSZ export did not retain its physical options path, dirty working/source trees, normal exit, and owned-scratch cleanup."
}
if ($osuFullPackageArchiveManifest.fileCount -ne 7 -or
    $osuFullPackageArchiveManifest.directoryEntryCount -ne 0 -or
    $osuFullPackageMainArchiveRows.Count -ne 1 -or
    $osuFullPackageSiblingArchiveRows.Count -ne 1 -or
    $osuFullPackageFreshManifest.fileCount -ne 7 -or
    $osuFullPackageFreshManifest.directoryCount -ne 0 -or
    $osuFullPackageArchiveFreshMismatches.Count -ne 0 -or
    (Get-FileHash -LiteralPath $osuFullPackageSiblingChartPath -Algorithm SHA256).Hash -cne
        [string]$osuFullPackageExpectedSourceHashes[$osuFullPackageSiblingFileName] -or
    [string]$osuFullPackageSiblingArchiveRows[0].sha256 -cne
        [string]$osuFullPackageExpectedSourceHashes[$osuFullPackageSiblingFileName] -or
    (Get-FileHash -LiteralPath $osuFullPackageSiblingFreshPath -Algorithm SHA256).Hash -cne
        [string]$osuFullPackageExpectedSourceHashes[$osuFullPackageSiblingFileName] -or
    $osuFullPackageResourceMismatches.Count -ne 0 -or
    -not $osuFullPackageMainText.Contains("osu file format v14", [StringComparison]::Ordinal) -or
    -not $osuFullPackageMainText.Contains("Mode: 3", [StringComparison]::Ordinal) -or
    -not $osuFullPackageMainText.Contains("OverallDifficulty:8.75", [StringComparison]::Ordinal) -or
    -not $osuFullPackageMainText.Contains("HPDrainRate:9", [StringComparison]::Ordinal) -or
    $osuFullPackageExpectedHitCount -ne 1 -or
    $osuFullPackageOriginalHitCount -ne 0) {
    throw "OSZ archive/fresh trees did not retain the exact flat seven entries, sibling/resources, v14 difficulty, or moved HitObject."
}
if ([string]$osuFullPackageFreshEvidence.archiveFormat -cne "OsuMania" -or
    -not [bool]$osuFullPackageFreshEvidence.verified -or
    -not [bool]$osuFullPackageFreshEvidence.normalExit -or
    -not [bool]$osuFullPackageFreshEvidence.sessionScratchRemovedAfterExit -or
    $osuFullPackageFreshProcess.Count -ne 0 -or
    (Test-Path -LiteralPath ([string]$osuFullPackageFreshEvidence.sessionScratchRoot)) -or
    [string]$osuFullPackageFreshEvidence.preview.countText -notlike
        "2 张键音谱可打开*0 张其他模式*0 张损坏*" -or
    [string]$osuFullPackageFreshEvidence.preview.openButton -cne "打开 2 张" -or
    [int]$osuFullPackageFreshEvidence.importedTabCount -ne 2 -or
    -not [bool]$osuFullPackageFreshEvidence.chartManifest.verified -or
    -not [bool]$osuFullPackageFreshEvidence.chartManifest.archiveFreshTree.exact -or
    -not [bool]$osuFullPackageFreshEvidence.structuralEquivalence.verified -or
    [int]$osuFullPackageCalibration.expectedCount -ne 2 -or
    [int]$osuFullPackageCalibration.observedCount -ne 2 -or
    -not [bool]$osuFullPackageCalibration.allCalibratePhysical -or
    $osuFullPackageCalibrationDialogs.Count -ne 2 -or
    (($osuFullPackageCalibration.expectedChartNames -join "`n") -cne
        ($osuFullPackageExpectedCalibrationNames -join "`n")) -or
    @($osuFullPackageCalibrationDialogs | Where-Object {
            [string]$_.dialogAutomationId -cne "OsuImportMode.Dialog" -or
            [string]$_.action -cne "Calibrate" -or
            -not [bool]$_.physicalClick -or
            [bool]$_.invokePatternUsed -or
            -not [bool]$_.dismissedAfterPhysicalClick
        }).Count -ne 0 -or
    [bool]$osuFullPackageFreshInteractionGui.timeline.sessionIsDirty -or
    [long]$osuFullPackageFreshInteractionGui.timeline.sessionChangeSerial -ne 0) {
    throw "Fresh OSZ GUI import did not preview/open two charts, physically calibrate both, remain clean, and exit normally without scratch."
}
if ((Get-FileHash -LiteralPath $osuFullPackageGuiPath -Algorithm SHA256).Hash -cne
        [string]$osuFullPackageCapture.capture.evidenceSha256 -or
    (Get-FileHash -LiteralPath $osuFullPackageInteractionGuiPath -Algorithm SHA256).Hash -cne
        [string]$osuFullPackageCapture.capture.interactionEvidenceSha256 -or
    (Get-FileHash -LiteralPath $osuFullPackageFreshGuiPath -Algorithm SHA256).Hash -cne
        [string]$osuFullPackageFreshEvidence.primaryEvidenceSha256 -or
    (Get-FileHash -LiteralPath $osuFullPackageFreshInteractionGuiPath -Algorithm SHA256).Hash -cne
        [string]$osuFullPackageFreshEvidence.interactionEvidenceSha256) {
    throw "OSZ primary/interaction/fresh runtime files do not match capture-reported SHA-256 values."
}

$malodyToOsuFullPackageExportEvidence =
    $malodyToOsuFullPackageCapture.capture.malodyFullPackageExport
$malodyToOsuFullPackageFreshEvidence =
    $malodyToOsuFullPackageExportEvidence.freshImport
$malodyToOsuFullPackageArchiveEvidence =
    $malodyToOsuFullPackageExportEvidence.archive
$malodyToOsuFullPackageSourceTreeAfter =
    Get-DirectoryTreeEvidence -Path $malodyToOsuFullPackageSourceRoot
$malodyToOsuFullPackageArchiveManifest =
    Get-FormalZipFileManifestEvidence -Path $malodyToOsuFullPackageExportPath
$malodyToOsuFullPackageFreshTopFiles = @(
    Get-ChildItem -LiteralPath $malodyToOsuFullPackageFreshWorkspaceRoot -File -Force)
$malodyToOsuFullPackageFreshTopDirectories = @(
    Get-ChildItem -LiteralPath $malodyToOsuFullPackageFreshWorkspaceRoot -Directory -Force)
if ($malodyToOsuFullPackageFreshTopFiles.Count -ne 0 -or
    $malodyToOsuFullPackageFreshTopDirectories.Count -ne 1) {
    throw "Fresh MC-to-OSZ extraction did not produce one exact top-level package directory."
}
$malodyToOsuFullPackageFreshManifest = Get-FormalFlatFileManifestEvidence `
    -Root $malodyToOsuFullPackageFreshTopDirectories[0].FullName
$malodyToOsuFullPackageArchiveFreshMismatches = @(
    foreach ($archiveRow in $malodyToOsuFullPackageArchiveManifest.rows) {
        $freshMatches = @($malodyToOsuFullPackageFreshManifest.rows | Where-Object {
                [string]$_.relativePath -ceq [string]$archiveRow.relativePath
            })
        if ($freshMatches.Count -ne 1 -or
            [long]$freshMatches[0].length -ne [long]$archiveRow.length -or
            [string]$freshMatches[0].sha256 -cne [string]$archiveRow.sha256) {
            [string]$archiveRow.relativePath
        }
    })
$malodyToOsuFullPackageMainArchiveRows = @(
    $malodyToOsuFullPackageArchiveManifest.rows | Where-Object {
        [string]$_.relativePath -ceq $malodyToOsuFullPackageMainFileName
    })
$malodyToOsuFullPackageMainFreshPath = Join-Path `
    $malodyToOsuFullPackageFreshTopDirectories[0].FullName `
    $malodyToOsuFullPackageMainFileName
$malodyToOsuFullPackageMainText =
    Get-Content -LiteralPath $malodyToOsuFullPackageMainFreshPath -Raw
$malodyToOsuFullPackageExpectedHitCount = @(
    $malodyToOsuFullPackageMainText -split "`r?`n" | Where-Object {
        $_ -match '^320,192,68066,(1|128),'
    }).Count
$malodyToOsuFullPackageOriginalHitCount = @(
    $malodyToOsuFullPackageMainText -split "`r?`n" | Where-Object {
        $_ -match '^192,192,68066,(1|128),'
    }).Count
$malodyToOsuFullPackageExpectedResourceHashes = [ordered]@{
    "InfinityHeaven.jpg" =
        "098A20B6C432A78A2E73B83BDBA43773CC441F22EBB9E571B2D4D4FE02D27BE6"
    "InfinityHeaven.ogg" =
        "BDD1B6806CE8815907158572329371E3F0A826D4087FA6FD0BFFCDC2E17AE81E"
}
$malodyToOsuFullPackageExpectedResourceEntries = [ordered]@{
    "InfinityHeaven.jpg" =
        "098A20B6C432A78A2E73B83BDBA43773CC441F22EBB9E571B2D4D4FE02D27BE6"
    "InfinityHeaven_2.jpg" =
        "098A20B6C432A78A2E73B83BDBA43773CC441F22EBB9E571B2D4D4FE02D27BE6"
    "InfinityHeaven.ogg" =
        "BDD1B6806CE8815907158572329371E3F0A826D4087FA6FD0BFFCDC2E17AE81E"
    "InfinityHeaven_2.ogg" =
        "BDD1B6806CE8815907158572329371E3F0A826D4087FA6FD0BFFCDC2E17AE81E"
}
$malodyToOsuFullPackageExpectedResourceNames = @(
    $malodyToOsuFullPackageExpectedResourceEntries.Keys)
$malodyToOsuFullPackageMissingResourceNames = @(
    foreach ($entry in $malodyToOsuFullPackageExpectedResourceEntries.GetEnumerator()) {
        $expectedName = [string]$entry.Key
        $expectedHash = [string]$entry.Value
        $matchingRows = @($malodyToOsuFullPackageArchiveManifest.rows | Where-Object {
                [string]$_.relativePath -ceq $expectedName
            })
        if ($matchingRows.Count -ne 1 -or
            [string]$matchingRows[0].sha256 -cne $expectedHash) {
            $expectedName
        }
    })
$malodyToOsuFullPackageResourceMismatches = @(
    foreach ($entry in $malodyToOsuFullPackageExpectedResourceHashes.GetEnumerator()) {
        $sourcePath = Join-Path $malodyToOsuFullPackageSourceRoot ([string]$entry.Key)
        $archiveMatches = @($malodyToOsuFullPackageArchiveManifest.rows | Where-Object {
                [string]$_.sha256 -ceq [string]$entry.Value
            })
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -or
            (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -cne
                [string]$entry.Value -or
            $archiveMatches.Count -ne 2) {
            [string]$entry.Key
        }
    })
$malodyToOsuFullPackageLeakedChartArtifacts = @(
    $malodyToOsuFullPackageArchiveManifest.rows | Where-Object {
        $extension = [IO.Path]::GetExtension([string]$_.relativePath)
        $extension -ieq ".mc" -or
        $extension -ieq ".mc_" -or
        $extension -ieq ".mcz" -or
        $extension -ieq ".osz" -or
        [string]$_.relativePath -ilike "*.luma-part" -or
        ($extension -ieq ".osu" -and
         [string]$_.relativePath -cne $malodyToOsuFullPackageMainFileName)
    })
$malodyToOsuFullPackageCalibration =
    $malodyToOsuFullPackageFreshEvidence.osuImportModes
$malodyToOsuFullPackageCalibrationDialogs = @(
    $malodyToOsuFullPackageCalibration.dialogs)
$malodyToOsuFullPackageMainProcess = @(
    Get-Process -Id ([int]$malodyToOsuFullPackageCapture.capture.processId) `
        -ErrorAction SilentlyContinue)
$malodyToOsuFullPackageFreshProcess = @(
    Get-Process -Id ([int]$malodyToOsuFullPackageFreshEvidence.processId) `
        -ErrorAction SilentlyContinue)
if ([string]$malodyToOsuFullPackageCapture.capture.fullPackageExportFormat -cne
        "OsuMania" -or
    [string]$malodyToOsuFullPackageCapture.capture.fullPackageSourceFormat -cne
        "Malody" -or
    -not [bool]$malodyToOsuFullPackageCapture.capture.fullPackageCrossFormat -or
    -not [bool]$malodyToOsuFullPackageCapture.capture.malodyFullPackageExportExercised -or
    [string]$malodyToOsuFullPackageExportEvidence.format -cne "OsuMania" -or
    [string]$malodyToOsuFullPackageExportEvidence.sourceFormat -cne "Malody" -or
    -not [bool]$malodyToOsuFullPackageExportEvidence.crossFormat -or
    [string]$malodyToOsuFullPackageExportEvidence.expectedMainChartFileName -cne
        $malodyToOsuFullPackageMainFileName -or
    [int]$malodyToOsuFullPackageExportEvidence.expectedArchiveEntryCount -ne 5 -or
    -not (Test-PathEvidenceEqual `
        -Left $malodyToOsuFullPackageExportEvidence.destinationPath `
        -Right $malodyToOsuFullPackageExportPath) -or
    -not [bool]$malodyToOsuFullPackageExportEvidence.options.defaultsVerified -or
    -not [bool]$malodyToOsuFullPackageExportEvidence.options.formatSelection.physicalClick -or
    -not [bool]$malodyToOsuFullPackageExportEvidence.options.osuDifficulty.retained -or
    [string]$malodyToOsuFullPackageExportEvidence.options.osuDifficulty.retainedOverallDifficulty -cne
        "8.75" -or
    [string]$malodyToOsuFullPackageExportEvidence.options.osuDifficulty.retainedHpDrainRate -cne
        "9" -or
    -not [bool]$malodyToOsuFullPackageExportEvidence.result.successTone -or
    -not [bool]$malodyToOsuFullPackageExportEvidence.sourceTreeUnchanged -or
    -not [bool]$malodyToOsuFullPackageExportEvidence.workingTreeUnchangedByExport -or
    -not [bool]$malodyToOsuFullPackageExportEvidence.scratch.clean -or
    [int]$malodyToOsuFullPackageExportEvidence.scratch.childCount -ne 0 -or
    -not [bool]$malodyToOsuFullPackageExportEvidence.mainProcessNormalExit -or
    -not [bool]$malodyToOsuFullPackageExportEvidence.mainSessionScratchRemovedAfterExit -or
    -not [bool]$malodyToOsuFullPackageExportEvidence.close.processExit -or
    [int]$malodyToOsuFullPackageExportEvidence.close.exitCode -ne 0 -or
    $malodyToOsuFullPackageMainProcess.Count -ne 0 -or
    (Test-Path -LiteralPath `
        ([string]$malodyToOsuFullPackageExportEvidence.scratch.sessionScratchRoot)) -or
    -not (Test-DirectoryTreeEvidenceEqual `
        -Before $malodyToOsuFullPackageSourceTreeBefore `
        -After $malodyToOsuFullPackageSourceTreeAfter)) {
    throw "MC-to-OSZ export did not retain its physical options path, exact source/target formats, dirty working/source trees, normal exit, and owned-scratch cleanup."
}
if ($malodyToOsuFullPackageArchiveManifest.fileCount -ne 5 -or
    $malodyToOsuFullPackageArchiveManifest.directoryEntryCount -ne 0 -or
    $malodyToOsuFullPackageMainArchiveRows.Count -ne 1 -or
    $malodyToOsuFullPackageFreshManifest.fileCount -ne 5 -or
    $malodyToOsuFullPackageFreshManifest.directoryCount -ne 0 -or
    $malodyToOsuFullPackageArchiveFreshMismatches.Count -ne 0 -or
    $malodyToOsuFullPackageLeakedChartArtifacts.Count -ne 0 -or
    $malodyToOsuFullPackageMissingResourceNames.Count -ne 0 -or
    $malodyToOsuFullPackageResourceMismatches.Count -ne 0 -or
    -not $malodyToOsuFullPackageMainText.Contains(
        "osu file format v14", [StringComparison]::Ordinal) -or
    -not $malodyToOsuFullPackageMainText.Contains(
        "Mode: 3", [StringComparison]::Ordinal) -or
    -not $malodyToOsuFullPackageMainText.Contains(
        "OverallDifficulty:8.75", [StringComparison]::Ordinal) -or
    -not $malodyToOsuFullPackageMainText.Contains(
        "HPDrainRate:9", [StringComparison]::Ordinal) -or
    $malodyToOsuFullPackageExpectedHitCount -ne 1 -or
    $malodyToOsuFullPackageOriginalHitCount -ne 0 -or
    [int]$malodyToOsuFullPackageArchiveEvidence.entryCount -ne 5 -or
    [int]$malodyToOsuFullPackageArchiveEvidence.chartEntryCount -ne 1 -or
    [int]$malodyToOsuFullPackageArchiveEvidence.malodyChartEntryCount -ne 0 -or
    [int]$malodyToOsuFullPackageArchiveEvidence.siblingChartEntryCount -ne 0 -or
    [int]$malodyToOsuFullPackageArchiveEvidence.mainChartEntryCount -ne 1 -or
    -not [bool]$malodyToOsuFullPackageArchiveEvidence.mainChartFormatVerified -or
    -not [bool]$malodyToOsuFullPackageArchiveEvidence.allExcludedSourceArtifactsAbsent -or
    [int]$malodyToOsuFullPackageArchiveEvidence.collisionEntryCount -lt 2 -or
    [int]$malodyToOsuFullPackageArchiveEvidence.unsafeEntryCount -ne 0) {
    throw "MC-to-OSZ archive/fresh trees did not retain the exact flat five entries, filtered chart/archive decoys, v14 difficulty, duplicate resource-byte pairs, or moved HitObject."
}
if ([string]$malodyToOsuFullPackageFreshEvidence.archiveFormat -cne "OsuMania" -or
    [string]$malodyToOsuFullPackageFreshEvidence.sourceChartFormat -cne "Malody" -or
    -not [bool]$malodyToOsuFullPackageFreshEvidence.crossFormat -or
    -not [bool]$malodyToOsuFullPackageFreshEvidence.verified -or
    -not [bool]$malodyToOsuFullPackageFreshEvidence.normalExit -or
    -not [bool]$malodyToOsuFullPackageFreshEvidence.sessionScratchRemovedAfterExit -or
    $malodyToOsuFullPackageFreshProcess.Count -ne 0 -or
    (Test-Path -LiteralPath `
        ([string]$malodyToOsuFullPackageFreshEvidence.sessionScratchRoot)) -or
    [string]$malodyToOsuFullPackageFreshEvidence.preview.countText -notlike
        "1 张键音谱可打开*0 张其他模式*0 张损坏*" -or
    [string]$malodyToOsuFullPackageFreshEvidence.preview.openButton -cne "打开 1 张" -or
    [int]$malodyToOsuFullPackageFreshEvidence.importedTabCount -ne 1 -or
    -not [bool]$malodyToOsuFullPackageFreshEvidence.chartManifest.verified -or
    -not [bool]$malodyToOsuFullPackageFreshEvidence.chartManifest.archiveFreshTree.exact -or
    -not [bool]$malodyToOsuFullPackageFreshEvidence.structuralEquivalence.verified -or
    [int]$malodyToOsuFullPackageCalibration.expectedCount -ne 1 -or
    [int]$malodyToOsuFullPackageCalibration.observedCount -ne 1 -or
    -not [bool]$malodyToOsuFullPackageCalibration.allCalibratePhysical -or
    $malodyToOsuFullPackageCalibrationDialogs.Count -ne 1 -or
    [string]$malodyToOsuFullPackageCalibration.expectedChartNames[0] -cne
        $malodyToOsuFullPackageMainFileName -or
    [string]$malodyToOsuFullPackageCalibrationDialogs[0].dialogAutomationId -cne
        "OsuImportMode.Dialog" -or
    [string]$malodyToOsuFullPackageCalibrationDialogs[0].action -cne "Calibrate" -or
    -not [bool]$malodyToOsuFullPackageCalibrationDialogs[0].physicalClick -or
    [bool]$malodyToOsuFullPackageCalibrationDialogs[0].invokePatternUsed -or
    -not [bool]$malodyToOsuFullPackageCalibrationDialogs[0].dismissedAfterPhysicalClick -or
    [bool]$malodyToOsuFullPackageFreshInteractionGui.timeline.sessionIsDirty -or
    [long]$malodyToOsuFullPackageFreshInteractionGui.timeline.sessionChangeSerial -ne 0) {
    throw "Fresh MC-to-OSZ GUI import did not preview/open one chart, physically calibrate it, remain clean, and exit normally without scratch."
}
if ((Get-FileHash -LiteralPath $malodyToOsuFullPackageGuiPath -Algorithm SHA256).Hash -cne
        [string]$malodyToOsuFullPackageCapture.capture.evidenceSha256 -or
    (Get-FileHash -LiteralPath $malodyToOsuFullPackageInteractionGuiPath -Algorithm SHA256).Hash -cne
        [string]$malodyToOsuFullPackageCapture.capture.interactionEvidenceSha256 -or
    (Get-FileHash -LiteralPath $malodyToOsuFullPackageFreshGuiPath -Algorithm SHA256).Hash -cne
        [string]$malodyToOsuFullPackageFreshEvidence.primaryEvidenceSha256 -or
    (Get-FileHash -LiteralPath $malodyToOsuFullPackageFreshInteractionGuiPath -Algorithm SHA256).Hash -cne
        [string]$malodyToOsuFullPackageFreshEvidence.interactionEvidenceSha256) {
    throw "MC-to-OSZ primary/interaction/fresh runtime files do not match capture-reported SHA-256 values."
}

$osuToMalodyFullPackageExportEvidence =
    $osuToMalodyFullPackageCapture.capture.malodyFullPackageExport
$osuToMalodyFullPackageFreshEvidence =
    $osuToMalodyFullPackageExportEvidence.freshImport
$osuToMalodyFullPackageArchiveEvidence =
    $osuToMalodyFullPackageExportEvidence.archive
$osuToMalodyFullPackageSourceTreeAfter =
    Get-DirectoryTreeEvidence -Path $osuToMalodyFullPackageSourceRoot
$osuToMalodyFullPackageIndependentArchive =
    Get-FormalOsuToMalodyArchiveEvidence `
        -ArchivePath $osuToMalodyFullPackageExportPath `
        -SourceRoot $osuToMalodyFullPackageSourceRoot
$osuToMalodyFullPackageMainTargetFileName =
    [string]$osuToMalodyFullPackageIndependentArchive.mainChartFileName
$osuToMalodyFullPackageArchiveManifest =
    $osuToMalodyFullPackageIndependentArchive.archive
$osuToMalodyFullPackageFreshTopFiles = @(
    Get-ChildItem -LiteralPath $osuToMalodyFullPackageFreshWorkspaceRoot -File -Force)
$osuToMalodyFullPackageFreshTopDirectories = @(
    Get-ChildItem -LiteralPath $osuToMalodyFullPackageFreshWorkspaceRoot -Directory -Force)
if ($osuToMalodyFullPackageFreshTopFiles.Count -ne 0 -or
    $osuToMalodyFullPackageFreshTopDirectories.Count -ne 1 -or
    $osuToMalodyFullPackageFreshTopDirectories[0].Name -cne 'out') {
    throw "Fresh osu-to-MCZ extraction did not produce one exact top-level out directory."
}
$osuToMalodyFullPackageFreshManifest = Get-FormalFlatFileManifestEvidence `
    -Root $osuToMalodyFullPackageFreshTopDirectories[0].FullName
$osuToMalodyFullPackageArchiveFreshMismatches = @(
    foreach ($archiveRow in $osuToMalodyFullPackageArchiveManifest.rows) {
        $freshMatches = @($osuToMalodyFullPackageFreshManifest.rows | Where-Object {
                [string]$_.relativePath -ceq [string]$archiveRow.relativePath
            })
        if ($freshMatches.Count -ne 1 -or
            [long]$freshMatches[0].length -ne [long]$archiveRow.length -or
            [string]$freshMatches[0].sha256 -cne [string]$archiveRow.sha256 -or
            [string]$freshMatches[0].semanticSha256 -cne
                [string]$archiveRow.semanticSha256) {
            [string]$archiveRow.relativePath
        }
    })
$osuToMalodyFullPackageFreshMainRows = @(
    $osuToMalodyFullPackageFreshManifest.rows | Where-Object {
        [string]$_.relativePath -ceq $osuToMalodyFullPackageMainTargetFileName
    })
if ($osuToMalodyFullPackageFreshManifest.fileCount -ne 6 -or
    $osuToMalodyFullPackageFreshManifest.directoryCount -ne 0 -or
    $osuToMalodyFullPackageFreshManifest.contentSha256 -cne
        $osuToMalodyFullPackageArchiveManifest.contentSha256 -or
    $osuToMalodyFullPackageArchiveFreshMismatches.Count -ne 0 -or
    $osuToMalodyFullPackageFreshMainRows.Count -ne 1 -or
    [string]$osuToMalodyFullPackageFreshMainRows[0].sha256 -cne
        [string]$osuToMalodyFullPackageIndependentArchive.mainChartSha256) {
    throw "Fresh osu-to-MCZ tree is not the exact flat six-file archive byte/semantic manifest."
}
$osuToMalodyFullPackageMainProcess = @(
    Get-Process -Id ([int]$osuToMalodyFullPackageCapture.capture.processId) `
        -ErrorAction SilentlyContinue)
$osuToMalodyFullPackageFreshProcess = @(
    Get-Process -Id ([int]$osuToMalodyFullPackageFreshEvidence.processId) `
        -ErrorAction SilentlyContinue)
$osuToMalodyFullPackageArchiveKeySoundNodes = @(
    $osuToMalodyFullPackageArchiveEvidence.keySoundNodes)
if ($osuToMalodyFullPackageArchiveKeySoundNodes.Count -ne 1) {
    throw "osu-to-MCZ Capture archive evidence did not contain exactly one KeySound node."
}
$osuToMalodyFullPackageArchiveKeySoundNode =
    $osuToMalodyFullPackageArchiveKeySoundNodes[0]
$osuToMalodyFullPackageProjectionPaths = @(
    $osuToMalodyFullPackageFreshEvidence.structuralEquivalence.projectionDifferences |
        ForEach-Object { [string]($_.path) })
$osuToMalodyFullPackageTargetSelectedNotes = @(
    $osuToMalodyFullPackageFreshEvidence.targetNavigation.selectedNotes)
if ($osuToMalodyFullPackageTargetSelectedNotes.Count -ne 1) {
    throw "Fresh osu-to-MCZ target navigation did not expose exactly one selected Note."
}
$osuToMalodyFullPackageTargetSelectedNote =
    $osuToMalodyFullPackageTargetSelectedNotes[0]
$osuToMalodyFullPackageArchiveFreshTree =
    $osuToMalodyFullPackageFreshEvidence.archiveFreshTree
$osuToMalodyFullPackagePreservation =
    $osuToMalodyFullPackageFreshEvidence.preservation
$osuToMalodyFullPackageWorkspaceTreePreExit =
    $osuToMalodyFullPackageFreshEvidence.workspaceTreePreExit
$osuToMalodyFullPackageWorkspaceTreeAfterExit =
    $osuToMalodyFullPackageFreshEvidence.workspaceTreeAfterExit
$osuToMalodyFullPackageFinalCaptureState =
    $osuToMalodyFullPackageExportEvidence.finalStateAfterMainProcessExit
$osuToMalodyFullPackageFinalCaptureWorking =
    $osuToMalodyFullPackageFinalCaptureState.workingMc
$osuToMalodyFullPackageFinalCaptureWorkingFile =
    $osuToMalodyFullPackageFinalCaptureWorking.finalFile
$osuToMalodyFullPackageFinalWorkingPath =
    [IO.Path]::GetFullPath([string]$osuToMalodyFullPackageFinalCaptureWorkingFile.path)
$expectedFinalWorkingBoundary =
    [IO.Path]::GetFullPath($osuToMalodyFullPackageMainEditingRoot).TrimEnd('\') + '\'
if (-not $osuToMalodyFullPackageFinalWorkingPath.StartsWith(
        $expectedFinalWorkingBoundary,
        [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetFileName($osuToMalodyFullPackageFinalWorkingPath) -cne 'working.mc' -or
    -not (Test-Path -LiteralPath $osuToMalodyFullPackageFinalWorkingPath -PathType Leaf)) {
    throw "osu-to-MCZ Capture did not report one final working.mc under the isolated main editing root."
}
$osuToMalodyFullPackageFinalWorkingMatches = @(
    Get-ChildItem `
        -LiteralPath $osuToMalodyFullPackageMainEditingRoot `
        -Recurse `
        -File `
        -Filter 'working.mc' | Where-Object {
            -not $_.FullName.StartsWith(
                (Join-Path $osuToMalodyFullPackageMainEditingRoot '_scratch'),
                [StringComparison]::OrdinalIgnoreCase)
        })
if ($osuToMalodyFullPackageFinalWorkingMatches.Count -ne 1 -or
    -not (Test-PathEvidenceEqual `
        -Left $osuToMalodyFullPackageFinalWorkingMatches[0].FullName `
        -Right $osuToMalodyFullPackageFinalWorkingPath)) {
    throw "osu-to-MCZ final-state gate did not find exactly the Capture-reported working.mc."
}
$osuToMalodyFullPackageFinalWorkingRoot =
    [IO.Path]::GetDirectoryName($osuToMalodyFullPackageFinalWorkingPath)
$osuToMalodyFullPackageIndependentFinalWorkingTree =
    Get-IndependentCaptureDirectoryTreeEvidence `
        -Path $osuToMalodyFullPackageFinalWorkingRoot
$osuToMalodyFullPackageIndependentFinalSourceTree =
    Get-IndependentCaptureDirectoryTreeEvidence `
        -Path $osuToMalodyFullPackageSourceRoot
$osuToMalodyFullPackageFinalWorkingItem =
    Get-Item -LiteralPath $osuToMalodyFullPackageFinalWorkingPath
$osuToMalodyFullPackageFinalWorkingChart =
    Get-Content -LiteralPath $osuToMalodyFullPackageFinalWorkingPath -Raw |
        ConvertFrom-Json
$osuToMalodyFullPackageFinalWorkingSemanticMap =
    ConvertTo-FormalJsonSemanticMap -Value $osuToMalodyFullPackageFinalWorkingChart
$osuToMalodyFullPackageFinalWorkingSemanticSha256 =
    Get-FormalJsonSemanticSha256 -Value $osuToMalodyFullPackageFinalWorkingChart
$osuToMalodyFullPackageFinalWorkingNotes =
    @($osuToMalodyFullPackageFinalWorkingChart.note)
$osuToMalodyFullPackageIndependentFinalTargetIndices = @(
    for ($noteIndex = 0;
         $noteIndex -lt $osuToMalodyFullPackageFinalWorkingNotes.Count;
         $noteIndex++) {
        $candidate = $osuToMalodyFullPackageFinalWorkingNotes[$noteIndex]
        $candidateBeat = @($candidate.beat)
        if ($null -ne $candidate.column -and $candidateBeat.Count -ge 3 -and
            $null -eq $candidate.endbeat -and
            [int]$candidate.column -eq 3 -and
            [int]$candidateBeat[0] -eq 15 -and
            [int]$candidateBeat[1] -eq 10 -and
            [int]$candidateBeat[2] -eq 12) {
            $noteIndex
        }
    })
$osuToMalodyFullPackageIndependentFinalOriginalIndices = @(
    for ($noteIndex = 0;
         $noteIndex -lt $osuToMalodyFullPackageFinalWorkingNotes.Count;
         $noteIndex++) {
        $candidate = $osuToMalodyFullPackageFinalWorkingNotes[$noteIndex]
        $candidateBeat = @($candidate.beat)
        if ($null -ne $candidate.column -and $candidateBeat.Count -ge 3 -and
            $null -eq $candidate.endbeat -and
            [int]$candidate.column -eq 2 -and
            [int]$candidateBeat[0] -eq 15 -and
            [int]$candidateBeat[1] -eq 5 -and
            [int]$candidateBeat[2] -eq 6) {
            $noteIndex
        }
    })
if ($osuToMalodyFullPackageIndependentFinalTargetIndices.Count -ne 1 -or
    $osuToMalodyFullPackageIndependentFinalOriginalIndices.Count -ne 0) {
    throw "osu-to-MCZ final working.mc did not retain exactly one 15:10/12 lane-3 Tap and zero original 15:5/6 lane-2 Taps."
}
$osuToMalodyFullPackageIndependentFinalTargetIndex =
    [int]$osuToMalodyFullPackageIndependentFinalTargetIndices[0]
$osuToMalodyFullPackageFinalCleanBaseline =
    $osuToMalodyFullPackageFinalCaptureWorking.cleanBaseline
if ($osuToMalodyFullPackageIndependentFinalTargetIndex -ne
        [int]$osuToMalodyFullPackageFinalCleanBaseline.noteIndex -or
    [string]$osuToMalodyFullPackageFinalCleanBaseline.beatJsonPointer -cne
        "/note/$osuToMalodyFullPackageIndependentFinalTargetIndex/beat" -or
    [string]$osuToMalodyFullPackageFinalCleanBaseline.laneJsonPointer -cne
        "/note/$osuToMalodyFullPackageIndependentFinalTargetIndex/column") {
    throw "osu-to-MCZ final working.mc target did not retain the Capture-established clean Note index."
}
$osuToMalodyFullPackageFinalAudioReference =
    [string]$osuToMalodyFullPackageFinalWorkingChart.meta.song.file
$osuToMalodyFullPackageFinalBackgroundReference =
    [string]$osuToMalodyFullPackageFinalWorkingChart.meta.background
if ($osuToMalodyFullPackageFinalWorkingNotes.Count -le 2468) {
    throw "osu-to-MCZ final working.mc lost the trusted /note/2468 Key-sound node."
}
$osuToMalodyFullPackageFinalKeySoundNode =
    $osuToMalodyFullPackageFinalWorkingNotes[2468]
$osuToMalodyFullPackageFinalKeySoundReference =
    [string]$osuToMalodyFullPackageFinalKeySoundNode.sound
$osuToMalodyFullPackageFinalResourcesOriginal =
    $osuToMalodyFullPackageFinalAudioReference.Equals(
        [string]$osuToMalodyFullPackageFinalCleanBaseline.resources.audio,
        [StringComparison]::Ordinal) -and
    $osuToMalodyFullPackageFinalBackgroundReference.Equals(
        [string]$osuToMalodyFullPackageFinalCleanBaseline.resources.background,
        [StringComparison]::Ordinal) -and
    $osuToMalodyFullPackageFinalKeySoundReference.Equals(
        [string]$osuToMalodyFullPackageFinalCleanBaseline.resources.keySound,
        [StringComparison]::Ordinal) -and
    $osuToMalodyFullPackageFinalAudioReference.Equals(
        'audio.mp3',
        [StringComparison]::Ordinal) -and
    $osuToMalodyFullPackageFinalBackgroundReference.Equals(
        'BG1.jpg',
        [StringComparison]::Ordinal) -and
    $osuToMalodyFullPackageFinalKeySoundReference.Equals(
        'audio.mp3',
        [StringComparison]::Ordinal) -and
    -not $osuToMalodyFullPackageFinalAudioReference.Equals(
        [string]$osuToMalodyFullPackageIndependentArchive.audioReference,
        [StringComparison]::Ordinal) -and
    -not $osuToMalodyFullPackageFinalBackgroundReference.Equals(
        [string]$osuToMalodyFullPackageIndependentArchive.backgroundReference,
        [StringComparison]::Ordinal)

$osuToMalodyFullPackageReconstructedCleanChart =
    $osuToMalodyFullPackageFinalWorkingChart
$osuToMalodyFullPackageReconstructedTargetNote =
    $osuToMalodyFullPackageFinalWorkingNotes[
        $osuToMalodyFullPackageIndependentFinalTargetIndex]
$osuToMalodyFullPackageReconstructedTargetNote.beat = @(15, 5, 6)
$osuToMalodyFullPackageReconstructedTargetNote.column = 2
$osuToMalodyFullPackageReconstructedCleanSemanticMap =
    ConvertTo-FormalJsonSemanticMap -Value $osuToMalodyFullPackageReconstructedCleanChart
$osuToMalodyFullPackageReconstructedCleanSemanticSha256 =
    Get-FormalJsonSemanticSha256 -Value $osuToMalodyFullPackageReconstructedCleanChart
$osuToMalodyFullPackageIndependentFinalSemanticDifferences = @(
    Compare-FormalJsonSemanticMaps `
        -Expected $osuToMalodyFullPackageReconstructedCleanSemanticMap `
        -Actual $osuToMalodyFullPackageFinalWorkingSemanticMap)
$osuToMalodyFullPackageExpectedFinalDifferencePaths = @(
    "/note/$osuToMalodyFullPackageIndependentFinalTargetIndex/beat/1",
    "/note/$osuToMalodyFullPackageIndependentFinalTargetIndex/beat/2",
    "/note/$osuToMalodyFullPackageIndependentFinalTargetIndex/column") |
    Sort-Object
$osuToMalodyFullPackageActualFinalDifferencePaths = @(
    $osuToMalodyFullPackageIndependentFinalSemanticDifferences |
        ForEach-Object { [string]$_.path } |
        Sort-Object)
$osuToMalodyFullPackageIndependentFinalWorkingFile = [ordered]@{
    path = $osuToMalodyFullPackageFinalWorkingPath
    length = [long]$osuToMalodyFullPackageFinalWorkingItem.Length
    lastWriteTimeUtc = $osuToMalodyFullPackageFinalWorkingItem.LastWriteTimeUtc.ToString(
        'O',
        [Globalization.CultureInfo]::InvariantCulture)
    sha256 = (Get-FileHash `
        -LiteralPath $osuToMalodyFullPackageFinalWorkingPath `
        -Algorithm SHA256).Hash
    semanticSha256 = $osuToMalodyFullPackageFinalWorkingSemanticSha256
}
$osuToMalodyFullPackageIndependentFinalArchiveItem =
    Get-Item -LiteralPath $osuToMalodyFullPackageExportPath
$osuToMalodyFullPackageIndependentFinalArchive = [ordered]@{
    path = $osuToMalodyFullPackageExportPath
    length = [long]$osuToMalodyFullPackageIndependentFinalArchiveItem.Length
    lastWriteTimeUtc =
        $osuToMalodyFullPackageIndependentFinalArchiveItem.LastWriteTimeUtc.ToString(
            'O',
            [Globalization.CultureInfo]::InvariantCulture)
    sha256 = (Get-FileHash `
        -LiteralPath $osuToMalodyFullPackageExportPath `
        -Algorithm SHA256).Hash
}
$osuToMalodyFullPackageIndependentFinalState = [ordered]@{
    sampledAfterCaptureReturnedAndBothProcessesExited = $true
    sourceTree = $osuToMalodyFullPackageIndependentFinalSourceTree
    workingTree = $osuToMalodyFullPackageIndependentFinalWorkingTree
    workingMc = [ordered]@{
        file = $osuToMalodyFullPackageIndependentFinalWorkingFile
        reconstructedCleanSemanticSha256 =
            $osuToMalodyFullPackageReconstructedCleanSemanticSha256
        expectedSemanticDifferencePaths =
            $osuToMalodyFullPackageExpectedFinalDifferencePaths
        semanticDifferenceCount =
            $osuToMalodyFullPackageIndependentFinalSemanticDifferences.Count
        semanticDifferences =
            $osuToMalodyFullPackageIndependentFinalSemanticDifferences
        exactTargetCount =
            $osuToMalodyFullPackageIndependentFinalTargetIndices.Count
        originalTargetCount =
            $osuToMalodyFullPackageIndependentFinalOriginalIndices.Count
        targetNoteIndex = $osuToMalodyFullPackageIndependentFinalTargetIndex
        resourceReferences = [ordered]@{
            audio = $osuToMalodyFullPackageFinalAudioReference
            background = $osuToMalodyFullPackageFinalBackgroundReference
            keySound = $osuToMalodyFullPackageFinalKeySoundReference
            retainedOriginalNames = $osuToMalodyFullPackageFinalResourcesOriginal
        }
    }
    archive = $osuToMalodyFullPackageIndependentFinalArchive
}
if (-not [bool]$osuToMalodyFullPackageFinalCaptureState.sampledAfterMainProcessExit -or
    [int]$osuToMalodyFullPackageFinalCaptureState.processExitCode -ne 0 -or
    -not [bool]$osuToMalodyFullPackageFinalCaptureState.sourceTreeUnchanged -or
    -not [bool]$osuToMalodyFullPackageFinalCaptureState.archiveUnchanged -or
    -not [bool]$osuToMalodyFullPackageFinalCaptureWorking.verified -or
    -not [bool]$osuToMalodyFullPackageFinalCaptureState.verified -or
    -not (Test-CaptureDirectoryTreeEvidenceEqual `
        -Before $osuToMalodyFullPackageFinalCaptureState.sourceTree `
        -After $osuToMalodyFullPackageIndependentFinalSourceTree) -or
    -not (Test-CaptureDirectoryTreeEvidenceEqual `
        -Before $osuToMalodyFullPackageFinalCaptureState.workingTree `
        -After $osuToMalodyFullPackageIndependentFinalWorkingTree) -or
    [long]$osuToMalodyFullPackageFinalCaptureWorkingFile.length -ne
        [long]$osuToMalodyFullPackageIndependentFinalWorkingFile.length -or
    -not (Test-TimestampEvidenceEqual `
        -Left $osuToMalodyFullPackageFinalCaptureWorkingFile.lastWriteTimeUtc `
        -Right $osuToMalodyFullPackageIndependentFinalWorkingFile.lastWriteTimeUtc) -or
    [string]$osuToMalodyFullPackageFinalCaptureWorkingFile.sha256 -cne
        [string]$osuToMalodyFullPackageIndependentFinalWorkingFile.sha256 -or
    [string]$osuToMalodyFullPackageFinalCaptureWorkingFile.semanticSha256 -cne
        [string]$osuToMalodyFullPackageIndependentFinalWorkingFile.semanticSha256 -or
    $osuToMalodyFullPackageIndependentFinalSemanticDifferences.Count -ne 3 -or
    ($osuToMalodyFullPackageExpectedFinalDifferencePaths -join '|') -cne
        ($osuToMalodyFullPackageActualFinalDifferencePaths -join '|') -or
    [string]$osuToMalodyFullPackageReconstructedCleanSemanticSha256 -cne
        [string]$osuToMalodyFullPackageFinalCleanBaseline.semanticSha256 -or
    -not $osuToMalodyFullPackageFinalResourcesOriginal -or
    [long]$osuToMalodyFullPackageFinalCaptureState.archive.length -ne
        [long]$osuToMalodyFullPackageIndependentFinalArchive.length -or
    -not (Test-TimestampEvidenceEqual `
        -Left $osuToMalodyFullPackageFinalCaptureState.archive.lastWriteTimeUtc `
        -Right $osuToMalodyFullPackageIndependentFinalArchive.lastWriteTimeUtc) -or
    [string]$osuToMalodyFullPackageFinalCaptureState.archive.sha256 -cne
        [string]$osuToMalodyFullPackageIndependentFinalArchive.sha256 -or
    [long]$osuToMalodyFullPackageIndependentFinalArchive.length -ne
        [long]$osuToMalodyFullPackageIndependentArchive.length -or
    [string]$osuToMalodyFullPackageIndependentFinalArchive.sha256 -cne
        [string]$osuToMalodyFullPackageIndependentArchive.sha256) {
    throw "osu-to-MCZ wrapper independent final-state recomputation did not match Capture, the clean semantic baseline, or final source/archive bytes."
}
if ([string]$osuToMalodyFullPackageCapture.capture.fullPackageExportFormat -cne
        'Malody' -or
    [string]$osuToMalodyFullPackageCapture.capture.fullPackageSourceFormat -cne
        'OsuMania' -or
    -not [bool]$osuToMalodyFullPackageCapture.capture.fullPackageCrossFormat -or
    -not [bool]$osuToMalodyFullPackageCapture.capture.malodyFullPackageExportExercised -or
    [string]$osuToMalodyFullPackageExportEvidence.format -cne 'Malody' -or
    [string]$osuToMalodyFullPackageExportEvidence.sourceFormat -cne 'OsuMania' -or
    -not [bool]$osuToMalodyFullPackageExportEvidence.crossFormat -or
    [string]$osuToMalodyFullPackageExportEvidence.expectedMainChartFileName -cne
        $osuToMalodyFullPackageMainTargetFileName -or
    [int]$osuToMalodyFullPackageExportEvidence.expectedArchiveEntryCount -ne 6 -or
    -not (Test-PathEvidenceEqual `
        -Left $osuToMalodyFullPackageExportEvidence.destinationPath `
        -Right $osuToMalodyFullPackageExportPath) -or
    -not [bool]$osuToMalodyFullPackageExportEvidence.options.defaultsVerified -or
    -not [bool]$osuToMalodyFullPackageExportEvidence.options.formatSelection.physicalClick -or
    [string]$osuToMalodyFullPackageExportEvidence.options.formatSelection.selectedItem.name -cne
        'Malody (.mc / .mcz)' -or
    $null -ne $osuToMalodyFullPackageExportEvidence.options.osuDifficulty -or
    -not [bool]$osuToMalodyFullPackageExportEvidence.result.successTone -or
    -not [bool]$osuToMalodyFullPackageExportEvidence.sourceTreeUnchanged -or
    -not [bool]$osuToMalodyFullPackageExportEvidence.workingTreeUnchangedByExport -or
    -not [bool]$osuToMalodyFullPackageExportEvidence.scratch.clean -or
    [int]$osuToMalodyFullPackageExportEvidence.scratch.childCount -ne 0 -or
    -not [bool]$osuToMalodyFullPackageExportEvidence.mainProcessNormalExit -or
    -not [bool]$osuToMalodyFullPackageExportEvidence.mainSessionScratchRemovedAfterExit -or
    -not [bool]$osuToMalodyFullPackageExportEvidence.close.processExit -or
    [int]$osuToMalodyFullPackageExportEvidence.close.exitCode -ne 0 -or
    $osuToMalodyFullPackageMainProcess.Count -ne 0 -or
    (Test-Path -LiteralPath `
        ([string]$osuToMalodyFullPackageExportEvidence.scratch.sessionScratchRoot)) -or
    -not (Test-DirectoryTreeEvidenceEqual `
        -Before $osuToMalodyFullPackageSourceTreeBefore `
        -After $osuToMalodyFullPackageSourceTreeAfter)) {
    throw "osu-to-MCZ export did not retain its physical Malody selection, cross-format identity, source/working trees, normal exit, and owned-scratch cleanup."
}
$osuToMalodyDirtyInjection = $osuToMalodyFullPackageExportEvidence.dirtyInjection
if ([int]$osuToMalodyDirtyInjection.beforeBeat.bar -ne 15 -or
    [int]$osuToMalodyDirtyInjection.beforeBeat.numerator -ne 5 -or
    [int]$osuToMalodyDirtyInjection.beforeBeat.denominator -ne 6 -or
    [int]$osuToMalodyDirtyInjection.beforeLane -ne 2 -or
    [int]$osuToMalodyDirtyInjection.submittedBeat.bar -ne 15 -or
    [int]$osuToMalodyDirtyInjection.submittedBeat.numerator -ne 10 -or
    [int]$osuToMalodyDirtyInjection.submittedBeat.denominator -ne 12 -or
    [int]$osuToMalodyDirtyInjection.submittedLane -ne 3 -or
    -not [bool]$osuToMalodyDirtyInjection.laneChanged -or
    -not [bool]$osuToMalodyDirtyInjection.submittedBeat.deliberatelyNonReduced -or
    -not [bool]$osuToMalodyDirtyInjection.submittedBeat.exactExpansionVerified -or
    -not [bool]$osuToMalodyDirtyInjection.submittedBeat.expectedExpressionVerified -or
    [bool]$osuToMalodyDirtyInjection.saveInvoked -or
    -not [bool]$osuToMalodyDirtyInjection.apply.allPhysicalClicks -or
    [bool]$osuToMalodyDirtyInjection.apply.automationFallbackUsed) {
    throw "osu-to-MCZ dirty GUI mutation did not prove one physical lane-2 15:5/6 to lane-3 exact 15:10/12 move without save."
}
if ([int]$osuToMalodyFullPackageArchiveEvidence.entryCount -ne 6 -or
    [int]$osuToMalodyFullPackageArchiveEvidence.chartEntryCount -ne 1 -or
    [int]$osuToMalodyFullPackageArchiveEvidence.mainChartEntryCount -ne 1 -or
    [string]$osuToMalodyFullPackageArchiveEvidence.mainChartFileName -cne
        $osuToMalodyFullPackageMainTargetFileName -or
    -not [bool]$osuToMalodyFullPackageArchiveEvidence.mainChartDynamicNameVerified -or
    -not [bool]$osuToMalodyFullPackageArchiveEvidence.allChartsValidJson -or
    -not [bool]$osuToMalodyFullPackageArchiveEvidence.allChartsCompact -or
    [int]$osuToMalodyFullPackageArchiveEvidence.mainChartExactBeatMatchCount -ne 1 -or
    [int]$osuToMalodyFullPackageArchiveEvidence.exactTargetTapCount -ne 1 -or
    [int]$osuToMalodyFullPackageArchiveEvidence.originalTargetTapCount -ne 0 -or
    [int]$osuToMalodyFullPackageArchiveEvidence.keyCount -ne 4 -or
    [int]$osuToMalodyFullPackageArchiveEvidence.playableNoteCount -ne 2468 -or
    [int]$osuToMalodyFullPackageArchiveEvidence.longNoteCount -ne 303 -or
    [int]$osuToMalodyFullPackageArchiveEvidence.serializedTimingCount -ne 2 -or
    [int]$osuToMalodyFullPackageArchiveEvidence.serializedEffectCount -ne 11 -or
    [int]$osuToMalodyFullPackageArchiveEvidence.serializedTimingAndEffectCount -ne 13 -or
    -not [bool]$osuToMalodyFullPackageArchiveEvidence.allSourceArtifactsExcluded -or
    -not [bool]$osuToMalodyFullPackageArchiveEvidence.resourceChainsVerified -or
    -not [bool]$osuToMalodyFullPackageArchiveEvidence.allReferencedResourcesResolved -or
    -not [bool]$osuToMalodyFullPackageArchiveEvidence.allEntriesFlat -or
    [int]$osuToMalodyFullPackageArchiveEvidence.unsafeEntryCount -ne 0 -or
    [int]$osuToMalodyFullPackageArchiveEvidence.caseInsensitiveDuplicateCount -ne 0 -or
    [int]$osuToMalodyFullPackageArchiveEvidence.unexpectedChartArtifactCount -ne 0 -or
    [int]$osuToMalodyFullPackageArchiveEvidence.collisionEntryCount -lt 2 -or
    [string]$osuToMalodyFullPackageArchiveEvidence.audioReference -cne 'audio_2.mp3' -or
    [string]$osuToMalodyFullPackageArchiveEvidence.backgroundReference -cne 'BG1_2.jpg' -or
    -not [bool]$osuToMalodyFullPackageArchiveEvidence.keySoundNodeVerified -or
    [int]$osuToMalodyFullPackageArchiveKeySoundNode.index -ne 2468 -or
    -not (Test-ExactIntegerArray `
        -Value $osuToMalodyFullPackageArchiveKeySoundNode.beat `
        -Expected @(0, 0, 1)) -or
    [int]$osuToMalodyFullPackageArchiveKeySoundNode.type -ne 1 -or
    [int]$osuToMalodyFullPackageArchiveKeySoundNode.offset -ne -1000 -or
    [bool]$osuToMalodyFullPackageArchiveKeySoundNode.hasColumnProperty -or
    $null -ne $osuToMalodyFullPackageArchiveKeySoundNode.column -or
    [string]$osuToMalodyFullPackageArchiveKeySoundNode.sound -cne 'audio_2.mp3') {
    throw "osu-to-MCZ Capture archive evidence did not match the independent unique dynamic MC, exact Beat/lane, 4K/2468/303/13 structure, exact KeySound, resources, or decoy filter."
}
if ([string]$osuToMalodyFullPackageFreshEvidence.archiveFormat -cne 'Malody' -or
    [string]$osuToMalodyFullPackageFreshEvidence.sourceChartFormat -cne 'OsuMania' -or
    -not [bool]$osuToMalodyFullPackageFreshEvidence.crossFormat -or
    [string]$osuToMalodyFullPackageFreshEvidence.dynamicMainChartFileName -cne
        $osuToMalodyFullPackageMainTargetFileName -or
    -not [bool]$osuToMalodyFullPackageFreshEvidence.verified -or
    -not [bool]$osuToMalodyFullPackageFreshEvidence.normalExit -or
    [int]$osuToMalodyFullPackageFreshEvidence.exitCode -ne 0 -or
    -not [bool]$osuToMalodyFullPackageFreshEvidence.sessionScratchRemovedAfterExit -or
    $osuToMalodyFullPackageFreshProcess.Count -ne 0 -or
    (Test-Path -LiteralPath `
        ([string]$osuToMalodyFullPackageFreshEvidence.sessionScratchRoot)) -or
    [int]$osuToMalodyFullPackageFreshEvidence.preview.validChartCount -ne 1 -or
    [int]$osuToMalodyFullPackageFreshEvidence.preview.otherModeCount -ne 0 -or
    [int]$osuToMalodyFullPackageFreshEvidence.preview.corruptCount -ne 0 -or
    [int]$osuToMalodyFullPackageFreshEvidence.importedTabCount -ne 1 -or
    [bool]$osuToMalodyFullPackageFreshEvidence.osuCalibration.expected -or
    [int]$osuToMalodyFullPackageFreshEvidence.osuCalibration.observedCount -ne 0 -or
    -not [bool]$osuToMalodyFullPackageFreshEvidence.osuCalibration.verifiedAbsent -or
    [int]$osuToMalodyFullPackageArchiveFreshTree.archiveEntryCount -ne 6 -or
    [string]$osuToMalodyFullPackageArchiveFreshTree.archiveContentSha256 -cne
        [string]$osuToMalodyFullPackageArchiveManifest.contentSha256 -or
    [int]$osuToMalodyFullPackageArchiveFreshTree.preExit.freshFileCount -ne 6 -or
    [int]$osuToMalodyFullPackageArchiveFreshTree.preExit.freshDirectoryCount -ne 0 -or
    [string]$osuToMalodyFullPackageArchiveFreshTree.preExit.freshContentSha256 -cne
        [string]$osuToMalodyFullPackageArchiveManifest.contentSha256 -or
    -not [bool]$osuToMalodyFullPackageArchiveFreshTree.preExit.exact -or
    [int]$osuToMalodyFullPackageArchiveFreshTree.afterExit.freshFileCount -ne 6 -or
    [int]$osuToMalodyFullPackageArchiveFreshTree.afterExit.freshDirectoryCount -ne 0 -or
    [string]$osuToMalodyFullPackageArchiveFreshTree.afterExit.freshContentSha256 -cne
        [string]$osuToMalodyFullPackageArchiveManifest.contentSha256 -or
    -not [bool]$osuToMalodyFullPackageArchiveFreshTree.afterExit.exact -or
    -not [bool]$osuToMalodyFullPackageArchiveFreshTree.sampledAfterFreshProcessExit -or
    -not [bool]$osuToMalodyFullPackageArchiveFreshTree.exact -or
    -not [bool]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.verified -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.projectionDifferenceCount -ne 6 -or
    -not (Test-ExactStringArray `
        -Value $osuToMalodyFullPackageProjectionPaths `
        -Expected @(
            '/meta/background',
            '/meta/song/file',
            '/note/14/beat/1',
            '/note/14/beat/2',
            '/note/14/column',
            '/note/2468/sound')) -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.semanticDifferenceCount -ne 0 -or
    @($osuToMalodyFullPackageFreshEvidence.structuralEquivalence.semanticDifferences).Count -ne 0 -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.counts.expected.keyCount -ne 4 -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.counts.expected.noteCount -ne 2468 -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.counts.expected.longNoteCount -ne 303 -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.counts.expected.timingCount -ne 13 -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.counts.expected.serializedTimingCount -ne 2 -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.counts.expected.serializedEffectCount -ne 11 -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.counts.fresh.keyCount -ne 4 -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.counts.fresh.noteCount -ne 2468 -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.counts.fresh.longNoteCount -ne 303 -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.counts.fresh.timingCount -ne 13 -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.counts.fresh.serializedTimingCount -ne 2 -or
    [int]$osuToMalodyFullPackageFreshEvidence.structuralEquivalence.counts.fresh.serializedEffectCount -ne 11 -or
    -not [bool]$osuToMalodyFullPackageFreshEvidence.dirtyProjection.verified -or
    [string]$osuToMalodyFullPackageFreshEvidence.dirtyProjection.beatJsonPointer -cne '/note/14/beat' -or
    [string]$osuToMalodyFullPackageFreshEvidence.dirtyProjection.laneJsonPointer -cne '/note/14/column' -or
    -not (Test-ExactIntegerArray `
        -Value $osuToMalodyFullPackageFreshEvidence.dirtyProjection.originalBeat `
        -Expected @(15, 5, 6)) -or
    [int]$osuToMalodyFullPackageFreshEvidence.dirtyProjection.originalLane -ne 2 -or
    -not (Test-ExactIntegerArray `
        -Value $osuToMalodyFullPackageFreshEvidence.dirtyProjection.expectedBeat `
        -Expected @(15, 10, 12)) -or
    [int]$osuToMalodyFullPackageFreshEvidence.dirtyProjection.expectedLane -ne 3 -or
    [int]$osuToMalodyFullPackageFreshEvidence.dirtyProjection.exactFreshMatchCount -ne 1 -or
    [int]$osuToMalodyFullPackageFreshEvidence.dirtyProjection.originalFreshMatchCount -ne 0 -or
    -not [bool]$osuToMalodyFullPackageFreshEvidence.dirtyProjection.deliberatelyNonReduced -or
    -not [bool]$osuToMalodyFullPackageFreshEvidence.targetNavigation.verified -or
    [int]$osuToMalodyFullPackageTargetSelectedNote.lane -ne 3 -or
    [int]$osuToMalodyFullPackageTargetSelectedNote.beat.bar -ne 15 -or
    [int]$osuToMalodyFullPackageTargetSelectedNote.beat.numerator -ne 10 -or
    [int]$osuToMalodyFullPackageTargetSelectedNote.beat.denominator -ne 12 -or
    [Math]::Abs(
        [double]$osuToMalodyFullPackageTargetSelectedNote.beat.value - (95.0 / 6.0)) -gt 1e-12 -or
    [Math]::Abs(
        [double]$osuToMalodyFullPackageFreshEvidence.targetNavigation.currentBeat - (95.0 / 6.0)) -gt 1e-12 -or
    -not [bool]$osuToMalodyFullPackageFreshEvidence.resources.verified -or
    [string]$osuToMalodyFullPackageFreshEvidence.resources.baselineAudioReference -cne 'audio.mp3' -or
    [string]$osuToMalodyFullPackageFreshEvidence.resources.packagedAudioReference -cne 'audio_2.mp3' -or
    [string]$osuToMalodyFullPackageFreshEvidence.resources.baselineBackgroundReference -cne 'BG1.jpg' -or
    [string]$osuToMalodyFullPackageFreshEvidence.resources.packagedBackgroundReference -cne 'BG1_2.jpg' -or
    [string]$osuToMalodyFullPackageFreshEvidence.resources.keySoundJsonPointer -cne '/note/2468/sound' -or
    [string]$osuToMalodyFullPackageFreshEvidence.resources.keySoundBaselineReference -cne 'audio.mp3' -or
    [string]$osuToMalodyFullPackageFreshEvidence.resources.keySoundPackagedReference -cne 'audio_2.mp3' -or
    -not (Test-ExactIntegerArray `
        -Value $osuToMalodyFullPackageFreshEvidence.resources.keySoundBeat `
        -Expected @(0, 0, 1)) -or
    [int]$osuToMalodyFullPackageFreshEvidence.resources.keySoundType -ne 1 -or
    [int]$osuToMalodyFullPackageFreshEvidence.resources.keySoundOffset -ne -1000 -or
    [bool]$osuToMalodyFullPackageFreshEvidence.resources.keySoundHasColumnProperty -or
    -not [bool]$osuToMalodyFullPackageFreshEvidence.resources.keySoundNodeVerified -or
    -not [bool]$osuToMalodyFullPackagePreservation.sourceTreeUnchangedBeforeFreshProcessExit -or
    -not [bool]$osuToMalodyFullPackagePreservation.sourceTreeUnchangedByFreshProcessExit -or
    -not (Test-CaptureDirectoryTreeEvidenceEqual `
        -Before $osuToMalodyFullPackagePreservation.sourceTreeBefore `
        -After $osuToMalodyFullPackagePreservation.sourceTreeBeforeFreshProcessExit) -or
    -not (Test-CaptureDirectoryTreeEvidenceEqual `
        -Before $osuToMalodyFullPackagePreservation.sourceTreeBefore `
        -After $osuToMalodyFullPackagePreservation.sourceTreeAfterFreshProcessExit) -or
    -not [bool]$osuToMalodyFullPackagePreservation.workingTreeUnchangedBeforeFreshProcessExit -or
    -not [bool]$osuToMalodyFullPackagePreservation.workingTreeUnchangedByFreshProcessExit -or
    -not (Test-CaptureDirectoryTreeEvidenceEqual `
        -Before $osuToMalodyFullPackagePreservation.workingTreeBefore `
        -After $osuToMalodyFullPackagePreservation.workingTreeBeforeFreshProcessExit) -or
    -not (Test-CaptureDirectoryTreeEvidenceEqual `
        -Before $osuToMalodyFullPackagePreservation.workingTreeBefore `
        -After $osuToMalodyFullPackagePreservation.workingTreeAfterFreshProcessExit) -or
    -not [bool]$osuToMalodyFullPackagePreservation.archiveUnchangedBeforeFreshProcessExit -or
    -not [bool]$osuToMalodyFullPackagePreservation.archiveUnchangedByFreshProcessExit -or
    [long]$osuToMalodyFullPackagePreservation.archiveBefore.length -ne
        [long]$osuToMalodyFullPackageIndependentArchive.length -or
    [string]$osuToMalodyFullPackagePreservation.archiveBefore.sha256 -cne
        [string]$osuToMalodyFullPackageIndependentArchive.sha256 -or
    [long]$osuToMalodyFullPackagePreservation.archiveBeforeFreshProcessExit.length -ne
        [long]$osuToMalodyFullPackagePreservation.archiveBefore.length -or
    [string]$osuToMalodyFullPackagePreservation.archiveBeforeFreshProcessExit.lastWriteTimeUtc -cne
        [string]$osuToMalodyFullPackagePreservation.archiveBefore.lastWriteTimeUtc -or
    [string]$osuToMalodyFullPackagePreservation.archiveBeforeFreshProcessExit.sha256 -cne
        [string]$osuToMalodyFullPackagePreservation.archiveBefore.sha256 -or
    [long]$osuToMalodyFullPackagePreservation.archiveAfterFreshProcessExit.length -ne
        [long]$osuToMalodyFullPackagePreservation.archiveBefore.length -or
    [string]$osuToMalodyFullPackagePreservation.archiveAfterFreshProcessExit.lastWriteTimeUtc -cne
        [string]$osuToMalodyFullPackagePreservation.archiveBefore.lastWriteTimeUtc -or
    [string]$osuToMalodyFullPackagePreservation.archiveAfterFreshProcessExit.sha256 -cne
        [string]$osuToMalodyFullPackagePreservation.archiveBefore.sha256 -or
    -not [bool]$osuToMalodyFullPackagePreservation.sampledAfterFreshProcessExit -or
    [int]$osuToMalodyFullPackageWorkspaceTreePreExit.fileCount -ne 6 -or
    [int]$osuToMalodyFullPackageWorkspaceTreeAfterExit.fileCount -ne 6 -or
    -not (Test-CaptureDirectoryTreeEvidenceEqual `
        -Before $osuToMalodyFullPackageWorkspaceTreePreExit `
        -After $osuToMalodyFullPackageWorkspaceTreeAfterExit) -or
    -not [bool]$osuToMalodyFullPackageFreshEvidence.cleanSession -or
    [bool]$osuToMalodyFullPackageFreshInteractionGui.timeline.sessionIsDirty -or
    [long]$osuToMalodyFullPackageFreshInteractionGui.timeline.sessionChangeSerial -ne 0) {
    throw "Fresh osu-to-MCZ GUI did not preview/open one chart without calibration, retain the exact pre/post-exit archive/workspace/source/working trees, prove six projected leaves including KeySound normalization, navigate the exact rational target Note, stay clean, and exit without scratch."
}
if ((Get-FileHash -LiteralPath $osuToMalodyFullPackageGuiPath -Algorithm SHA256).Hash -cne
        [string]$osuToMalodyFullPackageCapture.capture.evidenceSha256 -or
    (Get-FileHash -LiteralPath $osuToMalodyFullPackageInteractionGuiPath -Algorithm SHA256).Hash -cne
        [string]$osuToMalodyFullPackageCapture.capture.interactionEvidenceSha256 -or
    (Get-FileHash -LiteralPath $osuToMalodyFullPackageFreshGuiPath -Algorithm SHA256).Hash -cne
        [string]$osuToMalodyFullPackageFreshEvidence.primaryEvidenceSha256 -or
    (Get-FileHash -LiteralPath $osuToMalodyFullPackageFreshInteractionGuiPath -Algorithm SHA256).Hash -cne
        [string]$osuToMalodyFullPackageFreshEvidence.interactionEvidenceSha256) {
    throw "osu-to-MCZ primary/interaction/fresh runtime files do not match capture-reported SHA-256 values."
}

$realScreenshot = Get-ImageEvidence $realScreenshotPath
$transformScreenshot = Get-ImageEvidence $transformScreenshotPath
$propertyScreenshot = Get-ImageEvidence $propertyScreenshotPath
$propertyReopenScreenshot = Get-ImageEvidence $propertyReopenScreenshotPath
$groupSavedScreenshot = Get-ImageEvidence $groupSavedScreenshotPath
$groupHiddenScreenshot = Get-ImageEvidence $groupHiddenScreenshotPath
$groupPlacedScreenshot = Get-ImageEvidence $groupPlacedScreenshotPath
$osuScreenshot = Get-ImageEvidence $osuScreenshotPath
$libraryScreenshot = Get-ImageEvidence $libraryScreenshotPath
$libraryNoResultsScreenshot = Get-ImageEvidence $libraryNoResultsScreenshotPath
$hundredKScreenshot = Get-ImageEvidence $hundredKScreenshotPath
$keySoundSharedScreenshot = Get-ImageEvidence $keySoundSharedScreenshotPath
$keySoundSilentScreenshot = Get-ImageEvidence $keySoundSilentScreenshotPath
$displayScaleScreenshot = Get-ImageEvidence $displayScaleScreenshotPath
$displayScaleReopenScreenshot = Get-ImageEvidence $displayScaleReopenScreenshotPath
$displayScaleCorruptScreenshot = Get-ImageEvidence $displayScaleCorruptScreenshotPath
$audioPanelDefaultScreenshot = Get-ImageEvidence $audioPanelDefaultScreenshotPath
$audioPanelScreenshot = Get-ImageEvidence $audioPanelScreenshotPath
$audioPanelReopenScreenshot = Get-ImageEvidence $audioPanelReopenScreenshotPath
$chartValidationScreenshot = Get-ImageEvidence $chartValidationScreenshotPath
$chartValidationManualDialogScreenshot =
    Get-ImageEvidence $chartValidationManualDialogScreenshotPath
$chartValidationSaveBlockedDialogScreenshot =
    Get-ImageEvidence $chartValidationSaveBlockedDialogScreenshotPath
$libraryBatchOpenScreenshot = Get-ImageEvidence $libraryBatchOpenScreenshotPath
$libraryBatchOpenMenuScreenshot = Get-ImageEvidence $libraryBatchOpenMenuScreenshotPath
$libraryBatchOpenDialogScreenshot = Get-ImageEvidence $libraryBatchOpenDialogScreenshotPath
$libraryBatchDeleteScreenshot = Get-ImageEvidence $libraryBatchDeleteScreenshotPath
$libraryBatchDeleteMenuScreenshot = Get-ImageEvidence $libraryBatchDeleteMenuScreenshotPath
$libraryBatchDeleteDialogScreenshot = Get-ImageEvidence $libraryBatchDeleteDialogScreenshotPath
$libraryBatchRestoredScreenshot = Get-ImageEvidence $libraryBatchRestoredScreenshotPath
$proEditorPanScreenshot = Get-ImageEvidence $proEditorPanScreenshotPath
$proEditorEditScreenshot = Get-ImageEvidence $proEditorEditScreenshotPath
$proEditorReopenScreenshot = Get-ImageEvidence $proEditorReopenScreenshotPath
$proEditorSaveAsScreenshot = Get-ImageEvidence $proEditorSaveAsScreenshotPath
$proEditorOsuReopenScreenshot = Get-ImageEvidence $proEditorOsuReopenScreenshotPath
$chartExportModesScreenshot = Get-ImageEvidence $chartExportModesScreenshotPath
$chartExportModesDefaultScreenshot =
    Get-ImageEvidence $chartExportModesDefaultScreenshotPath
$chartExportModesSingleChartScreenshot =
    Get-ImageEvidence $chartExportModesSingleChartScreenshotPath
$chartExportModesSingleRateScreenshot =
    Get-ImageEvidence $chartExportModesSingleRateScreenshotPath
$chartExportModesRatePackScreenshot =
    Get-ImageEvidence $chartExportModesRatePackScreenshotPath
$chartExportModesHiddenValidationScreenshot =
    Get-ImageEvidence $chartExportModesHiddenValidationScreenshotPath
$chartExportModesResultScreenshot =
    Get-ImageEvidence $chartExportModesResultScreenshotPath
$malodyFullPackageScreenshot =
    Get-ImageEvidence $malodyFullPackageScreenshotPath
$malodyFullPackageOptionsScreenshot =
    Get-ImageEvidence $malodyFullPackageOptionsScreenshotPath
$malodyFullPackageResultScreenshot =
    Get-ImageEvidence $malodyFullPackageResultScreenshotPath
$malodyFullPackageFreshDialogScreenshot =
    Get-ImageEvidence $malodyFullPackageFreshDialogScreenshotPath
$malodyFullPackageFreshScreenshot =
    Get-ImageEvidence $malodyFullPackageFreshScreenshotPath
$osuFullPackageScreenshot = Get-ImageEvidence $osuFullPackageScreenshotPath
$osuFullPackageOptionsScreenshot = Get-ImageEvidence $osuFullPackageOptionsScreenshotPath
$osuFullPackageResultScreenshot = Get-ImageEvidence $osuFullPackageResultScreenshotPath
$osuFullPackageFreshDialogScreenshot =
    Get-ImageEvidence $osuFullPackageFreshDialogScreenshotPath
$osuFullPackageFirstCalibrationScreenshot =
    Get-ImageEvidence $osuFullPackageFirstCalibrationScreenshotPath
$osuFullPackageSecondCalibrationScreenshot =
    Get-ImageEvidence $osuFullPackageSecondCalibrationScreenshotPath
$osuFullPackageFreshScreenshot = Get-ImageEvidence $osuFullPackageFreshScreenshotPath
$malodyToOsuFullPackageScreenshot =
    Get-ImageEvidence $malodyToOsuFullPackageScreenshotPath
$malodyToOsuFullPackageOptionsScreenshot =
    Get-ImageEvidence $malodyToOsuFullPackageOptionsScreenshotPath
$malodyToOsuFullPackageResultScreenshot =
    Get-ImageEvidence $malodyToOsuFullPackageResultScreenshotPath
$malodyToOsuFullPackageFreshDialogScreenshot =
    Get-ImageEvidence $malodyToOsuFullPackageFreshDialogScreenshotPath
$malodyToOsuFullPackageFirstCalibrationScreenshot =
    Get-ImageEvidence $malodyToOsuFullPackageFirstCalibrationScreenshotPath
$malodyToOsuFullPackageFreshScreenshot =
    Get-ImageEvidence $malodyToOsuFullPackageFreshScreenshotPath
$osuToMalodyFullPackageScreenshot =
    Get-ImageEvidence $osuToMalodyFullPackageScreenshotPath
$osuToMalodyFullPackageOptionsScreenshot =
    Get-ImageEvidence $osuToMalodyFullPackageOptionsScreenshotPath
$osuToMalodyFullPackageResultScreenshot =
    Get-ImageEvidence $osuToMalodyFullPackageResultScreenshotPath
$osuToMalodyFullPackageFreshDialogScreenshot =
    Get-ImageEvidence $osuToMalodyFullPackageFreshDialogScreenshotPath
$osuToMalodyFullPackageFreshScreenshot =
    Get-ImageEvidence $osuToMalodyFullPackageFreshScreenshotPath
$allScreenshots = @(
    $libraryScreenshot,
    $libraryNoResultsScreenshot,
    $realScreenshot,
    $transformScreenshot,
    $propertyScreenshot,
    $propertyReopenScreenshot,
    $groupSavedScreenshot,
    $groupHiddenScreenshot,
    $groupPlacedScreenshot,
    $osuScreenshot,
    $hundredKScreenshot,
    $keySoundSharedScreenshot,
    $keySoundSilentScreenshot,
    $displayScaleScreenshot,
    $displayScaleReopenScreenshot,
    $displayScaleCorruptScreenshot,
    $audioPanelDefaultScreenshot,
    $audioPanelScreenshot,
    $audioPanelReopenScreenshot,
    $chartValidationScreenshot,
    $chartValidationManualDialogScreenshot,
    $chartValidationSaveBlockedDialogScreenshot,
    $libraryBatchOpenScreenshot,
    $libraryBatchOpenMenuScreenshot,
    $libraryBatchOpenDialogScreenshot,
    $libraryBatchDeleteScreenshot,
    $libraryBatchDeleteMenuScreenshot,
    $libraryBatchDeleteDialogScreenshot,
    $libraryBatchRestoredScreenshot,
    $proEditorPanScreenshot,
    $proEditorEditScreenshot,
    $proEditorReopenScreenshot,
    $proEditorSaveAsScreenshot,
    $proEditorOsuReopenScreenshot,
    $chartExportModesScreenshot,
    $chartExportModesDefaultScreenshot,
    $chartExportModesSingleChartScreenshot,
    $chartExportModesSingleRateScreenshot,
    $chartExportModesRatePackScreenshot,
    $chartExportModesHiddenValidationScreenshot,
    $chartExportModesResultScreenshot,
    $malodyFullPackageScreenshot,
    $malodyFullPackageOptionsScreenshot,
    $malodyFullPackageResultScreenshot,
    $malodyFullPackageFreshDialogScreenshot,
    $malodyFullPackageFreshScreenshot,
    $osuFullPackageScreenshot,
    $osuFullPackageOptionsScreenshot,
    $osuFullPackageResultScreenshot,
    $osuFullPackageFreshDialogScreenshot,
    $osuFullPackageFirstCalibrationScreenshot,
    $osuFullPackageSecondCalibrationScreenshot,
    $osuFullPackageFreshScreenshot,
    $malodyToOsuFullPackageScreenshot,
    $malodyToOsuFullPackageOptionsScreenshot,
    $malodyToOsuFullPackageResultScreenshot,
    $malodyToOsuFullPackageFreshDialogScreenshot,
    $malodyToOsuFullPackageFirstCalibrationScreenshot,
    $malodyToOsuFullPackageFreshScreenshot,
    $osuToMalodyFullPackageScreenshot,
    $osuToMalodyFullPackageOptionsScreenshot,
    $osuToMalodyFullPackageResultScreenshot,
    $osuToMalodyFullPackageFreshDialogScreenshot,
    $osuToMalodyFullPackageFreshScreenshot)
if (@($allScreenshots | Where-Object {
        $isLibraryNoResults = Test-PathEvidenceEqual `
            -Left $_.path `
            -Right $libraryNoResultsScreenshotPath
        $minimumColors = if ($isLibraryNoResults) { 3 } else { 8 }
        $minimumStdDev = if ($isLibraryNoResults) { .25 } else { 1.5 }
        $_.widthPixels -lt 64 -or
        $_.heightPixels -lt 64 -or
        $_.sizeBytes -le 0 -or
        [string]::IsNullOrWhiteSpace([string]$_.sha256) -or
        $_.sampledUniqueColors -lt $minimumColors -or
        $_.sampledOpaquePixels -lt 240 -or
        $_.sampledLuminanceStdDev -lt $minimumStdDev
    }).Count -gt 0) {
    throw "A GUI screenshot was empty or near-uniform."
}
$chartExportModeDialogScreenshots = @(
    $chartExportModesDefaultScreenshot,
    $chartExportModesSingleChartScreenshot,
    $chartExportModesSingleRateScreenshot,
    $chartExportModesRatePackScreenshot,
    $chartExportModesHiddenValidationScreenshot)
$chartExportModeDialogWidth =
    [int]$chartExportModeDialogScreenshots[0].widthPixels
$chartExportModeDialogHeight =
    [int]$chartExportModeDialogScreenshots[0].heightPixels
if (@($chartExportModeDialogScreenshots | Where-Object {
            [int]$_.widthPixels -ne $chartExportModeDialogWidth -or
            [int]$_.heightPixels -ne $chartExportModeDialogHeight
        }).Count -ne 0 -or
    $chartExportModesScreenshot.sha256 -cne
        [string]$chartExportModesCapture.capture.screenshotSha256 -or
    $chartExportModesScreenshot.widthPixels -ne
        [int]$chartExportModesCapture.capture.screenshotWidth -or
    $chartExportModesScreenshot.heightPixels -ne
        [int]$chartExportModesCapture.capture.screenshotHeight -or
    $chartExportModesDefaultScreenshot.sha256 -cne
        [string]$chartExportModesEvidence.defaultFullPackage.screenshotSha256 -or
    $chartExportModesSingleChartScreenshot.sha256 -cne
        [string]$chartExportModesEvidence.singleChart.screenshotSha256 -or
    $chartExportModesSingleRateScreenshot.sha256 -cne
        [string]$chartExportModesEvidence.singleRatePackage.screenshotSha256 -or
    $chartExportModesRatePackScreenshot.sha256 -cne
        [string]$chartExportModesEvidence.ratePack.screenshotSha256 -or
    $chartExportModesHiddenValidationScreenshot.sha256 -cne
        [string]$chartExportModesEvidence.hiddenFieldValidation.screenshotSha256 -or
    $chartExportModesResultScreenshot.sha256 -cne
        [string]$chartExportModesActualExport.result.screenshotSha256 -or
    (Get-FileHash -LiteralPath $chartExportModesGuiPath -Algorithm SHA256).Hash -cne
        [string]$chartExportModesCapture.capture.evidenceSha256 -or
    (Get-FileHash -LiteralPath $chartExportModesInteractionGuiPath -Algorithm SHA256).Hash -cne
        [string]$chartExportModesCapture.capture.interactionEvidenceSha256) {
    throw "Chart-export mode/result/editor screenshots or runtime evidence do not match the capture-reported hashes and DPI-consistent dimensions."
}
if ($chartValidationScreenshot.sha256 -cne
        [string]$chartValidationCapture.capture.screenshotSha256 -or
    $chartValidationScreenshot.widthPixels -ne
        [int]$chartValidationCapture.capture.screenshotWidth -or
    $chartValidationScreenshot.heightPixels -ne
        [int]$chartValidationCapture.capture.screenshotHeight -or
    $chartValidationManualDialogScreenshot.sha256 -cne
        [string]$chartValidationCapture.capture.chartValidationManualDialogScreenshotSha256 -or
    $chartValidationSaveBlockedDialogScreenshot.sha256 -cne
        [string]$chartValidationCapture.capture.chartValidationSaveBlockedDialogScreenshotSha256) {
    throw "Chart-validation screenshots do not match the capture-reported hashes or dimensions."
}
if ($libraryBatchOpenScreenshot.sha256 -cne
        [string]$libraryBatchOpenCapture.capture.screenshotSha256 -or
    $libraryBatchOpenScreenshot.widthPixels -ne
        [int]$libraryBatchOpenCapture.capture.screenshotWidth -or
    $libraryBatchOpenScreenshot.heightPixels -ne
        [int]$libraryBatchOpenCapture.capture.screenshotHeight -or
    $libraryBatchOpenMenuScreenshot.sha256 -cne
        [string]$libraryBatchOpenCapture.capture.libraryContextMenuScreenshotSha256 -or
    $libraryBatchOpenDialogScreenshot.sha256 -cne
        [string]$libraryBatchOpenCapture.capture.libraryDeleteDialogScreenshotSha256 -or
    $libraryBatchDeleteScreenshot.sha256 -cne
        [string]$libraryBatchDeleteCapture.capture.screenshotSha256 -or
    $libraryBatchDeleteScreenshot.widthPixels -ne
        [int]$libraryBatchDeleteCapture.capture.screenshotWidth -or
    $libraryBatchDeleteScreenshot.heightPixels -ne
        [int]$libraryBatchDeleteCapture.capture.screenshotHeight -or
    $libraryBatchDeleteMenuScreenshot.sha256 -cne
        [string]$libraryBatchDeleteCapture.capture.libraryContextMenuScreenshotSha256 -or
    $libraryBatchDeleteDialogScreenshot.sha256 -cne
        [string]$libraryBatchDeleteCapture.capture.libraryDeleteDialogScreenshotSha256 -or
    $libraryBatchRestoredScreenshot.sha256 -cne
        [string]$libraryBatchRestoredCapture.capture.screenshotSha256 -or
    $libraryBatchRestoredScreenshot.widthPixels -ne
        [int]$libraryBatchRestoredCapture.capture.screenshotWidth -or
    $libraryBatchRestoredScreenshot.heightPixels -ne
        [int]$libraryBatchRestoredCapture.capture.screenshotHeight -or
    (Get-FileHash -LiteralPath $libraryBatchOpenGuiPath -Algorithm SHA256).Hash -cne
        [string]$libraryBatchOpenCapture.capture.evidenceSha256 -or
    (Get-FileHash -LiteralPath $libraryBatchOpenInteractionGuiPath -Algorithm SHA256).Hash -cne
        [string]$libraryBatchOpenCapture.capture.interactionEvidenceSha256 -or
    (Get-FileHash -LiteralPath $libraryBatchDeleteGuiPath -Algorithm SHA256).Hash -cne
        [string]$libraryBatchDeleteCapture.capture.evidenceSha256 -or
    (Get-FileHash -LiteralPath $libraryBatchDeleteInteractionGuiPath -Algorithm SHA256).Hash -cne
        [string]$libraryBatchDeleteCapture.capture.interactionEvidenceSha256 -or
    (Get-FileHash -LiteralPath $libraryBatchRestoredGuiPath -Algorithm SHA256).Hash -cne
        [string]$libraryBatchRestoredCapture.capture.evidenceSha256) {
    throw "Library open-block, batch-delete, and restored screenshots/runtime files do not match capture-reported hashes or dimensions."
}
if ($malodyFullPackageScreenshot.sha256 -cne
        [string]$malodyFullPackageCapture.capture.screenshotSha256 -or
    $malodyFullPackageScreenshot.widthPixels -ne
        [int]$malodyFullPackageCapture.capture.screenshotWidth -or
    $malodyFullPackageScreenshot.heightPixels -ne
        [int]$malodyFullPackageCapture.capture.screenshotHeight -or
    $malodyFullPackageOptionsScreenshot.sha256 -cne
        [string]$malodyFullPackageExportEvidence.optionsScreenshotSha256 -or
    $malodyFullPackageResultScreenshot.sha256 -cne
        [string]$malodyFullPackageExportEvidence.resultScreenshotSha256 -or
    $malodyFullPackageFreshDialogScreenshot.sha256 -cne
        [string]$malodyFullPackageFreshEvidence.preview.screenshotSha256 -or
    $malodyFullPackageFreshScreenshot.sha256 -cne
        [string]$malodyFullPackageFreshEvidence.finalScreenshotSha256) {
    throw "The Malody FullPackage options/result/final and fresh import-preview/main screenshots do not match capture-reported hashes or dimensions."
}
if ($osuFullPackageScreenshot.sha256 -cne
        [string]$osuFullPackageCapture.capture.screenshotSha256 -or
    $osuFullPackageScreenshot.widthPixels -ne
        [int]$osuFullPackageCapture.capture.screenshotWidth -or
    $osuFullPackageScreenshot.heightPixels -ne
        [int]$osuFullPackageCapture.capture.screenshotHeight -or
    $osuFullPackageOptionsScreenshot.sha256 -cne
        [string]$osuFullPackageExportEvidence.optionsScreenshotSha256 -or
    $osuFullPackageResultScreenshot.sha256 -cne
        [string]$osuFullPackageExportEvidence.resultScreenshotSha256 -or
    $osuFullPackageFreshDialogScreenshot.sha256 -cne
        [string]$osuFullPackageFreshEvidence.preview.screenshotSha256 -or
    $osuFullPackageFirstCalibrationScreenshot.sha256 -cne
        [string]$osuFullPackageCalibrationDialogs[0].screenshotSha256 -or
    $osuFullPackageSecondCalibrationScreenshot.sha256 -cne
        [string]$osuFullPackageCalibrationDialogs[1].screenshotSha256 -or
    $osuFullPackageFreshScreenshot.sha256 -cne
        [string]$osuFullPackageFreshEvidence.finalScreenshotSha256) {
    throw "OSZ export/options/result/preview/calibration/fresh screenshots do not match capture-reported hashes or dimensions."
}
if ($malodyToOsuFullPackageScreenshot.sha256 -cne
        [string]$malodyToOsuFullPackageCapture.capture.screenshotSha256 -or
    $malodyToOsuFullPackageScreenshot.widthPixels -ne
        [int]$malodyToOsuFullPackageCapture.capture.screenshotWidth -or
    $malodyToOsuFullPackageScreenshot.heightPixels -ne
        [int]$malodyToOsuFullPackageCapture.capture.screenshotHeight -or
    $malodyToOsuFullPackageOptionsScreenshot.sha256 -cne
        [string]$malodyToOsuFullPackageExportEvidence.optionsScreenshotSha256 -or
    $malodyToOsuFullPackageResultScreenshot.sha256 -cne
        [string]$malodyToOsuFullPackageExportEvidence.resultScreenshotSha256 -or
    $malodyToOsuFullPackageFreshDialogScreenshot.sha256 -cne
        [string]$malodyToOsuFullPackageFreshEvidence.preview.screenshotSha256 -or
    $malodyToOsuFullPackageFirstCalibrationScreenshot.sha256 -cne
        [string]$malodyToOsuFullPackageCalibrationDialogs[0].screenshotSha256 -or
    $malodyToOsuFullPackageFreshScreenshot.sha256 -cne
        [string]$malodyToOsuFullPackageFreshEvidence.finalScreenshotSha256) {
    throw "MC-to-OSZ export/options/result/preview/calibration/fresh screenshots do not match capture-reported hashes or dimensions."
}
if ($osuToMalodyFullPackageScreenshot.sha256 -cne
        [string]$osuToMalodyFullPackageCapture.capture.screenshotSha256 -or
    $osuToMalodyFullPackageScreenshot.widthPixels -ne
        [int]$osuToMalodyFullPackageCapture.capture.screenshotWidth -or
    $osuToMalodyFullPackageScreenshot.heightPixels -ne
        [int]$osuToMalodyFullPackageCapture.capture.screenshotHeight -or
    $osuToMalodyFullPackageOptionsScreenshot.sha256 -cne
        [string]$osuToMalodyFullPackageExportEvidence.optionsScreenshotSha256 -or
    $osuToMalodyFullPackageResultScreenshot.sha256 -cne
        [string]$osuToMalodyFullPackageExportEvidence.resultScreenshotSha256 -or
    $osuToMalodyFullPackageFreshDialogScreenshot.sha256 -cne
        [string]$osuToMalodyFullPackageFreshEvidence.preview.screenshotSha256 -or
    $osuToMalodyFullPackageFreshScreenshot.sha256 -cne
        [string]$osuToMalodyFullPackageFreshEvidence.finalScreenshotSha256) {
    throw "osu-to-MCZ export/options/result/preview/target-note screenshots do not match capture-reported hashes or dimensions."
}
if ((Get-FileHash -LiteralPath $fixturePath -Algorithm SHA256).Hash -ne $fixtureSha256 -or
    (Get-FileHash -LiteralPath $osuFixturePath -Algorithm SHA256).Hash -ne $osuFixtureSha256 -or
    (Get-FileHash -LiteralPath $archiveFixturePath -Algorithm SHA256).Hash -ne $archiveFixtureSha256 -or
    (Get-FileHash -LiteralPath $proEditorFixturePath -Algorithm SHA256).Hash -ne $proEditorFixtureSha256 -or
    (Get-FileHash -LiteralPath $keySoundFlatFixturePath -Algorithm SHA256).Hash -ne
        $keySoundFlatFixtureSha256 -or
    (Get-FileHash -LiteralPath $keySoundSampleSourcePath -Algorithm SHA256).Hash -ne
        $keySoundSampleSourceSha256 -or
    (Get-FileHash -LiteralPath $resoundCoverSourcePath -Algorithm SHA256).Hash -ne
        $resoundCoverSourceSha256 -or
    (Get-FileHash -LiteralPath $isolatedProEditorPanPath -Algorithm SHA256).Hash -ne $proEditorFixtureSha256 -or
    (Get-FileHash -LiteralPath $isolatedProEditorEditPath -Algorithm SHA256).Hash -ne $proEditorSavedSha256 -or
    (Get-FileHash -LiteralPath $isolatedProEditorOsuPath -Algorithm SHA256).Hash -ne $proEditorOsuSha256 -or
    (Get-FileHash -LiteralPath $isolatedGroupMcPath -Algorithm SHA256).Hash -ne $groupSavedSha256 -or
    (Get-FileHash -LiteralPath $isolatedKeySoundSharedMcPath -Algorithm SHA256).Hash -ne $fixtureSha256 -or
    (Get-FileHash -LiteralPath $isolatedKeySoundSharedAudioPath -Algorithm SHA256).Hash -ne
        $keySoundSampleSourceSha256 -or
    (Get-FileHash -LiteralPath $isolatedKeySoundSilentMcPath -Algorithm SHA256).Hash -ne
        $keySoundFlatFixtureSha256 -or
    (Get-FileHash -LiteralPath $isolatedKeySoundKickPath -Algorithm SHA256).Hash -ne
        $keySoundSampleSourceSha256 -or
    (Get-FileHash -LiteralPath $isolatedChartValidationMcPath -Algorithm SHA256).Hash -ne
        $fixtureSha256 -or
    @(@($libraryBatchAChartPath, $libraryBatchBChartPath, $libraryBatchOpenChartPath) |
        Where-Object {
            (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash -cne $fixtureSha256
        }).Count -ne 0 -or
    @(@($libraryBatchAAudioPath, $libraryBatchBAudioPath, $libraryBatchOpenAudioPath) |
        Where-Object {
            (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash -cne
                $keySoundSampleSourceSha256
        }).Count -ne 0 -or
    @(@($libraryBatchACoverPath, $libraryBatchBCoverPath, $libraryBatchOpenCoverPath) |
        Where-Object {
            (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash -cne
                $resoundCoverSourceSha256
        }).Count -ne 0) {
    throw "A trusted real fixture changed during Windows Avalonia verification."
}

$wpfProcessAfter = @(Get-Process -Name "LumaChart.App" -ErrorAction SilentlyContinue |
    Sort-Object Id)
$wpfProcessesFinal = @($wpfProcessAfter | ForEach-Object {
        [pscustomobject][ordered]@{
            processId = [int]$_.Id
            processName = [string]$_.ProcessName
            startTimeUtc = $_.StartTime.ToUniversalTime().ToString("O")
            mainWindowHandle = [long]$_.MainWindowHandle
            mainWindowTitle = [string]$_.MainWindowTitle
            responding = [bool]$_.Responding
            observedAtUtc = [DateTimeOffset]::UtcNow
        }
    })
$wpfProcessPreservationMismatches = [Collections.Generic.List[string]]::new()
$wpfBaselineProcessIds = @($wpfProcessesBaseline.processId)
$wpfFinalProcessIds = @($wpfProcessesFinal.processId)
if (($wpfBaselineProcessIds -join '|') -cne ($wpfFinalProcessIds -join '|')) {
    $wpfProcessPreservationMismatches.Add("process-id-set")
}
foreach ($baselineProcess in $wpfProcessesBaseline) {
    $matchingFinalProcesses = @($wpfProcessesFinal | Where-Object {
            [int]$_.processId -eq [int]$baselineProcess.processId
        })
    if ($matchingFinalProcesses.Count -ne 1) {
        $wpfProcessPreservationMismatches.Add(
            "missing-or-duplicate-$([int]$baselineProcess.processId)")
        continue
    }
    $finalProcess = $matchingFinalProcesses[0]
    if ([string]$finalProcess.processName -cne [string]$baselineProcess.processName -or
        [string]$finalProcess.startTimeUtc -cne [string]$baselineProcess.startTimeUtc -or
        ([bool]$baselineProcess.responding -and -not [bool]$finalProcess.responding)) {
        $wpfProcessPreservationMismatches.Add(
            "identity-or-responsive-state-$([int]$baselineProcess.processId)")
    }
}
if ($wpfProcessPreservationMismatches.Count -ne 0) {
    throw "The dynamic pre-existing Windows/WPF process set changed during the Avalonia formal slice."
}
$officialInstallerSha256After =
    (Get-FileHash -LiteralPath $officialInstallerPath -Algorithm SHA256).Hash
if ($officialInstallerSha256After -cne $officialInstallerSha256 -or
    $officialInstallerSha256After -cne
        "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
    throw "The trusted Windows/WPF installer changed during the Avalonia formal slice."
}

$formalWpfRoot = Join-Path $projectRoot "artifacts\windows-release-1.1.0-final-20260721-r2"
$formalWpfStrict = Get-RequiredJson (Join-Path $formalWpfRoot "strict-gate.json")
$formalInstaller = Get-RequiredJson (Join-Path $formalWpfRoot "final-installer.json")
$display = Get-CimInstance Win32_VideoController |
    Where-Object { $_.CurrentHorizontalResolution -and $_.CurrentVerticalResolution } |
    Select-Object -First 1
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$presentMonPath = "C:\Program Files\NVIDIA Corporation\FrameViewSDK\bin\PresentMon_x64.exe"

$currentProcessTemp = [Environment]::GetEnvironmentVariable("TEMP", "Process")
$currentProcessTmp = [Environment]::GetEnvironmentVariable("TMP", "Process")
$currentUserTemp = [Environment]::GetEnvironmentVariable("TEMP", "User")
$currentUserTmp = [Environment]::GetEnvironmentVariable("TMP", "User")
$currentMachineTemp = [Environment]::GetEnvironmentVariable("TEMP", "Machine")
$currentMachineTmp = [Environment]::GetEnvironmentVariable("TMP", "Machine")
$currentProcessTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$legacyProcessAvaloniaSpecsTempAfter =
    Get-TempDirectoryMetadataEvidence -Path $legacyProcessAvaloniaSpecsTempRoot
$batchTempAfter = Get-TempDirectoryMetadataEvidence -Path $batchTempRoot
if ($currentProcessTemp -cne $originalProcessTemp -or
    $currentProcessTmp -cne $originalProcessTmp -or
    $currentUserTemp -cne $originalUserTemp -or
    $currentUserTmp -cne $originalUserTmp -or
    $currentMachineTemp -cne $originalMachineTemp -or
    $currentMachineTmp -cne $originalMachineTmp -or
    -not (Test-PathEvidenceEqual `
        -Left $currentProcessTempRoot `
        -Right $originalProcessTempRoot) -or
    -not (Test-Path -LiteralPath $batchAvaloniaSpecsTempRoot -PathType Container) -or
    -not [bool]$batchTempAfter.exists -or
    [int]$batchTempAfter.entryCount -lt 1 -or
    [bool]$legacyProcessAvaloniaSpecsTempBefore.exists -ne
        [bool]$legacyProcessAvaloniaSpecsTempAfter.exists -or
    [int]$legacyProcessAvaloniaSpecsTempBefore.entryCount -ne
        [int]$legacyProcessAvaloniaSpecsTempAfter.entryCount -or
    [int]$legacyProcessAvaloniaSpecsTempBefore.fileCount -ne
        [int]$legacyProcessAvaloniaSpecsTempAfter.fileCount -or
    [long]$legacyProcessAvaloniaSpecsTempBefore.totalBytes -ne
        [long]$legacyProcessAvaloniaSpecsTempAfter.totalBytes -or
    [string]$legacyProcessAvaloniaSpecsTempBefore.metadataSha256 -cne
        [string]$legacyProcessAvaloniaSpecsTempAfter.metadataSha256) {
    throw "Formal dotnet/Specs/GUI child processes did not stay inside the isolated D-drive TEMP/TMP root or changed the legacy process temp Specs cache."
}
$tempIsolationEvidence = [ordered]@{
    validationLevel = "per-child-process-temp-and-tmp-override-with-legacy-c-temp-metadata-unchanged"
    processEnvironmentRestored = $true
    originalProcessTemp = $originalProcessTemp
    originalProcessTmp = $originalProcessTmp
    originalProcessTempRoot = $originalProcessTempRoot
    restoredProcessTemp = $currentProcessTemp
    restoredProcessTmp = $currentProcessTmp
    restoredProcessTempRoot = $currentProcessTempRoot
    userEnvironmentBefore = [ordered]@{
        temp = $originalUserTemp
        tmp = $originalUserTmp
    }
    userEnvironmentAfter = [ordered]@{
        temp = $currentUserTemp
        tmp = $currentUserTmp
    }
    machineEnvironmentBefore = [ordered]@{
        temp = $originalMachineTemp
        tmp = $originalMachineTmp
    }
    machineEnvironmentAfter = [ordered]@{
        temp = $currentMachineTemp
        tmp = $currentMachineTmp
    }
    batchTempRoot = $batchTempRoot
    batchTempDrive = [IO.Path]::GetPathRoot($batchTempRoot)
    batchAvaloniaSpecsTempRoot = $batchAvaloniaSpecsTempRoot
    batchAvaloniaSpecsTempRootObserved = $true
    batchTempAfter = $batchTempAfter
    legacyProcessAvaloniaSpecsTempBefore = $legacyProcessAvaloniaSpecsTempBefore
    legacyProcessAvaloniaSpecsTempAfter = $legacyProcessAvaloniaSpecsTempAfter
    legacyProcessAvaloniaSpecsTempUnchanged = $true
    systemOrUserEnvironmentModified = $false
    wpfProcessEnvironmentModified = $false
    nugetGlobalPackagesCache = [ordered]@{
        processOverride = [Environment]::GetEnvironmentVariable("NUGET_PACKAGES", "Process")
        policy = "existing global cache may be read; it is not copied, cleared, or redirected by this formal wrapper"
    }
}
$tempIsolationEvidencePath = Write-JsonArtifact `
    -Path (Join-Path $artifactFullPath "process-temp-isolation.json") `
    -Value $tempIsolationEvidence

$sourcePathsAfter = @(Get-WindowsSliceSourceFileItems `
        -ProjectRoot $projectRoot `
        -CaptureHarnessPath $captureHarnessPath `
        -FormalWrapperPath $formalWrapperPath)
$sourceHashesAfter = @(Get-SourceFileRuntimeEvidence -Items $sourcePathsAfter)
$sourcePathSetUnchanged =
    $sourceHashesBefore.Count -eq $sourceHashesAfter.Count -and
    (($sourceHashesBefore.path -join "`n") -ceq
        ($sourceHashesAfter.path -join "`n"))
$sourceHashesAfterByPath = @{}
foreach ($sourceHashAfter in $sourceHashesAfter) {
    $sourceHashAfterPath = [string]$sourceHashAfter.path
    if ($sourceHashesAfterByPath.ContainsKey($sourceHashAfterPath)) {
        throw "The final sourceFiles snapshot contains a duplicate path: $sourceHashAfterPath"
    }
    $sourceHashesAfterByPath.Add($sourceHashAfterPath, $sourceHashAfter)
}
$sourceHashes = @($sourceHashesBefore | ForEach-Object {
        $sourceHashBefore = $_
        $sourceHashBeforePath = [string]($sourceHashBefore.path)
        $sourceHashAfter = $sourceHashesAfterByPath[$sourceHashBeforePath]
        $unchangedDuringBatch =
            $null -ne $sourceHashAfter -and
            [long]$sourceHashBefore.sizeBytes -eq [long]$sourceHashAfter.sizeBytes -and
            [string]$sourceHashBefore.sha256 -ceq [string]$sourceHashAfter.sha256
        [pscustomobject][ordered]@{
            path = [string]$sourceHashBefore.path
            sizeBytes = [long]$sourceHashBefore.sizeBytes
            sha256 = [string]$sourceHashBefore.sha256
            batchAfterSizeBytes = if ($null -eq $sourceHashAfter) {
                $null
            } else {
                [long]$sourceHashAfter.sizeBytes
            }
            batchAfterSha256 = if ($null -eq $sourceHashAfter) {
                $null
            } else {
                [string]$sourceHashAfter.sha256
            }
            unchangedDuringBatch = $unchangedDuringBatch
        }
    })
if (-not $sourcePathSetUnchanged -or
    $sourceHashes.Count -ne $sourcePathsBefore.Count -or
    @($sourceHashes.path | Sort-Object -Unique).Count -ne $sourceHashes.Count -or
    @($sourceHashes | Where-Object {
            [string]$_.path -match "\\LumaChart\.(Android|iOS)(\\|$)"
        }).Count -ne 0 -or
    @($sourceHashes | Where-Object {
            -not [IO.Path]::GetFullPath([string]$_.path).StartsWith(
                $sourceBoundary,
                [StringComparison]::OrdinalIgnoreCase) -or
            -not [bool]$_.unchangedDuringBatch
        }).Count -ne 0) {
    throw "sourceFiles changed during the formal Windows batch or are not a unique, complete, hash/size-consistent Windows-only source set."
}
$malodyFullPackageServiceSourceEvidence = @($sourceHashes | Where-Object {
        Test-PathEvidenceEqual `
            -Left $_.path `
            -Right (Join-Path $projectRoot `
                "LumaChart.Application\Exporting\MalodyFullPackageExportService.cs")
    })
$avaloniaSpecsProgramSourceEvidence = @($sourceHashes | Where-Object {
        Test-PathEvidenceEqual `
            -Left $_.path `
            -Right (Join-Path $projectRoot "LumaChart.Avalonia.Specs\Program.cs")
    })
$evidenceNoteFocusPolicySourceEvidence = @($sourceHashes | Where-Object {
        Test-PathEvidenceEqual `
            -Left $_.path `
            -Right (Join-Path $projectRoot `
                "LumaChart.Avalonia\Evidence\EvidenceNoteFocusPolicy.cs")
    })
$windowsChartExportSourcePaths = [ordered]@{
    contracts = Join-Path $projectRoot `
        "LumaChart.Application\Exporting\ChartExportContracts.cs"
    service = Join-Path $projectRoot `
        "LumaChart.Application\Exporting\ChartExportService.cs"
    windowsAudioTranscoder = Join-Path $projectRoot `
        "LumaChart.Avalonia\Services\WindowsAudioTranscoder.cs"
    windowsRateProvider = Join-Path $projectRoot `
        "LumaChart.Avalonia\Services\WindowsRateAdjustingSampleProvider.cs"
    windowsChartExportAdapter = Join-Path $projectRoot `
        "LumaChart.Avalonia\Services\WindowsChartExportAudioTranscoder.cs"
    dialog = Join-Path $projectRoot `
        "LumaChart.Avalonia\Dialogs\MalodyFullPackageExportDialog.cs"
}
$windowsChartExportSourceEvidence = [ordered]@{}
foreach ($mapping in $windowsChartExportSourcePaths.GetEnumerator()) {
    $matches = @($sourceHashes | Where-Object {
            Test-PathEvidenceEqual -Left $_.path -Right ([string]$mapping.Value)
        })
    if ($matches.Count -ne 1) {
        throw "The runtime sourceFiles snapshot did not contain one exact Windows chart-export source: $($mapping.Value)"
    }
            $windowsChartExportSourceKey = [string]$mapping.Key
            $windowsChartExportSourceEvidence[$windowsChartExportSourceKey] = $matches[0]
}
if ($malodyFullPackageServiceSourceEvidence.Count -ne 1 -or
    $avaloniaSpecsProgramSourceEvidence.Count -ne 1 -or
    $evidenceNoteFocusPolicySourceEvidence.Count -ne 1 -or
    $windowsChartExportSourceEvidence.Count -ne
        $windowsChartExportSourcePaths.Count) {
    throw "The runtime sourceFiles snapshot did not contain one unique MCZ/export service, Avalonia Specs program, Evidence Note-focus policy, and Windows chart-export source set."
}
$avaloniaApplicationPath = Join-Path $projectRoot "LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"
$libraryBatchSessionArtifactPaths = @(
    Get-ChildItem -LiteralPath (
        Join-Path $guiRoot "sessions\library-open-document-block") -Recurse -File
    Get-ChildItem -LiteralPath (
        Join-Path $guiRoot "sessions\library-batch-delete") -Recurse -File
    Get-ChildItem -LiteralPath (
        Join-Path $guiRoot "sessions\library-batch-restored") -Recurse -File
) | ForEach-Object { $_.FullName }
$malodyFullPackageArtifactPaths = @(
    Get-ChildItem -LiteralPath $malodyFullPackageRoot -Recurse -File |
        ForEach-Object { $_.FullName })
$osuFullPackageArtifactPaths = @(
    Get-ChildItem -LiteralPath $osuFullPackageRoot -Recurse -File |
        ForEach-Object { $_.FullName })
$malodyToOsuFullPackageArtifactPaths = @(
    Get-ChildItem -LiteralPath $malodyToOsuFullPackageRoot -Recurse -File |
        ForEach-Object { $_.FullName })
$osuToMalodyFullPackageArtifactPaths = @(
    Get-ChildItem -LiteralPath $osuToMalodyFullPackageRoot -Recurse -File |
        ForEach-Object { $_.FullName })
$chartExportModesArtifactPaths = @(
    Get-ChildItem -LiteralPath $chartExportModesRoot -Recurse -File |
        ForEach-Object { $_.FullName })
$gateOutputPaths = @(
    $avaloniaBuild.logPath,
    $avaloniaSpecsBuild.logPath,
    $mainSpecsBuild.logPath,
    $mainSpecsRun.logPath,
    $verticalSliceRun.logPath,
    $verticalSlicePath,
    $tempIsolationEvidencePath,
    $libraryCapture.logPath,
    $libraryNoResultsCapture.logPath,
    $realCapture.logPath,
    $transformCapture.logPath,
    $propertyCapture.logPath,
    $propertyReopenCapture.logPath,
    $groupAssignCapture.logPath,
    $groupVisibilityCapture.logPath,
    $groupPlacementCapture.logPath,
    $osuCapture.logPath,
    $hundredKCapture.logPath,
    $keySoundSharedCapture.logPath,
    $keySoundSilentCapture.logPath,
    $displayScaleCapture.logPath,
    $displayScaleReopenCapture.logPath,
    $displayScaleCorruptCapture.logPath,
    $audioPanelDefaultCapture.logPath,
    $audioPanelCapture.logPath,
    $audioPanelReopenCapture.logPath,
    $chartValidationCapture.logPath,
    $libraryBatchOpenCapture.logPath,
    $libraryBatchDeleteCapture.logPath,
    $libraryBatchRestoredCapture.logPath,
    $proEditorPanCapture.logPath,
    $proEditorEditCapture.logPath,
    $proEditorReopenCapture.logPath,
    $proEditorSaveAsCapture.logPath,
    $proEditorOsuReopenCapture.logPath,
    $chartExportModesCapture.logPath,
    $malodyFullPackageCapture.logPath,
    $osuFullPackageCapture.logPath,
    $malodyToOsuFullPackageCapture.logPath,
    $osuToMalodyFullPackageCapture.logPath,
    $realGuiPath,
    $realInteractionGuiPath,
    $transformGuiPath,
    $transformInteractionGuiPath,
    $propertyGuiPath,
    $propertyInteractionGuiPath,
    $propertyReopenGuiPath,
    $groupAssignGuiPath,
    $groupSavedGuiPath,
    $groupVisibilityGuiPath,
    $groupHiddenGuiPath,
    $groupPlacementGuiPath,
    $groupPlacedGuiPath,
    $osuGuiPath,
    $osuInteractionGuiPath,
    $hundredKGuiPath,
    $keySoundSharedGuiPath,
    $keySoundSharedInteractionGuiPath,
    $keySoundSilentGuiPath,
    $keySoundSilentInteractionGuiPath,
    $displayScaleGuiPath,
    $displayScaleInteractionGuiPath,
    $displayScaleReopenGuiPath,
    $displayScaleCorruptGuiPath,
    $audioPanelDefaultGuiPath,
    $audioPanelGuiPath,
    $audioPanelInteractionGuiPath,
    $audioPanelReopenGuiPath,
    $chartValidationGuiPath,
    $chartValidationInteractionGuiPath,
    $libraryBatchOpenGuiPath,
    $libraryBatchOpenInteractionGuiPath,
    $libraryBatchDeleteGuiPath,
    $libraryBatchDeleteInteractionGuiPath,
    $libraryBatchRestoredGuiPath,
    $libraryBatchRecoveryEvidencePath,
    $proEditorPanGuiPath,
    $proEditorPannedGuiPath,
    $proEditorEditGuiPath,
    $proEditorSavedGuiPath,
    $proEditorReopenGuiPath,
    $proEditorReopenInteractionGuiPath,
    $proEditorSaveAsGuiPath,
    $proEditorSavedAsGuiPath,
    $proEditorOsuReopenGuiPath,
    $proEditorOsuReopenInteractionGuiPath,
    $libraryNoResultsEvidencePath,
    $libraryScreenshot.path,
    $libraryNoResultsScreenshot.path,
    $realScreenshot.path,
    $transformScreenshot.path,
    $propertyScreenshot.path,
    $propertyReopenScreenshot.path,
    $groupSavedScreenshot.path,
    $groupHiddenScreenshot.path,
    $groupPlacedScreenshot.path,
    $osuScreenshot.path,
    $hundredKScreenshot.path,
    $keySoundSharedScreenshot.path,
    $keySoundSilentScreenshot.path,
    $displayScaleScreenshot.path,
    $displayScaleReopenScreenshot.path,
    $displayScaleCorruptScreenshot.path,
    $audioPanelDefaultScreenshot.path,
    $audioPanelScreenshot.path,
    $audioPanelReopenScreenshot.path,
    $chartValidationScreenshot.path,
    $chartValidationManualDialogScreenshot.path,
    $chartValidationSaveBlockedDialogScreenshot.path,
    $libraryBatchOpenScreenshot.path,
    $libraryBatchOpenMenuScreenshot.path,
    $libraryBatchOpenDialogScreenshot.path,
    $libraryBatchDeleteScreenshot.path,
    $libraryBatchDeleteMenuScreenshot.path,
    $libraryBatchDeleteDialogScreenshot.path,
    $libraryBatchRestoredScreenshot.path,
    $proEditorPanScreenshot.path,
    $proEditorEditScreenshot.path,
    $proEditorReopenScreenshot.path,
    $proEditorSaveAsScreenshot.path,
    $proEditorOsuReopenScreenshot.path,
    $isolatedPropertyMcPath,
    $isolatedGroupMcPath,
    $isolatedProEditorEditPath,
    $isolatedProEditorOsuPath,
    $isolatedChartValidationMcPath,
    $libraryBatchAChartPath,
    $libraryBatchAAudioPath,
    $libraryBatchACoverPath,
    $libraryBatchBChartPath,
    $libraryBatchBAudioPath,
    $libraryBatchBCoverPath,
    $libraryBatchOpenChartPath,
    $libraryBatchOpenAudioPath,
    $libraryBatchOpenCoverPath,
    $displayScaleSettingsPath,
    $displayScaleCorruptSettingsPath,
    $audioPanelDefaultSettingsPath,
    $audioPanelSettingsPath,
    $chartValidationScaleSettingsPath,
    $libraryBatchOpenSettingsPath,
    $libraryBatchDeleteSettingsPath,
    $libraryBatchRestoredSettingsPath
    $libraryBatchSessionArtifactPaths
    $malodyFullPackageArtifactPaths
    $osuFullPackageArtifactPaths
    $malodyToOsuFullPackageArtifactPaths
    $osuToMalodyFullPackageArtifactPaths
    $chartExportModesArtifactPaths
) | Sort-Object -Unique
$artifactOutputs = @($gateOutputPaths | ForEach-Object {
    $item = Get-Item -LiteralPath $_
    [pscustomobject]@{
        path = $item.FullName
        sizeBytes = $item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
})
if ($artifactOutputs.Count -ne $gateOutputPaths.Count -or
    @($artifactOutputs.path | Sort-Object -Unique).Count -ne $artifactOutputs.Count -or
    @($artifactOutputs | Where-Object {
        -not [IO.Path]::GetFullPath([string]$_.path).StartsWith(
            $artifactFullPath.TrimEnd('\') + '\',
            [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $_.path -PathType Leaf) -or
        [long](Get-Item -LiteralPath $_.path).Length -ne [long]$_.sizeBytes -or
        (Get-FileHash -LiteralPath $_.path -Algorithm SHA256).Hash -cne [string]$_.sha256
    }).Count -ne 0) {
    throw "artifactOutputs is not a unique, complete, hash/size-consistent formal output set."
}
$osuToMalodyFinalWorkingArtifactRows = @($artifactOutputs | Where-Object {
        Test-PathEvidenceEqual `
            -Left ([string]$_.path) `
            -Right $osuToMalodyFullPackageFinalWorkingPath
    })
$osuToMalodyFinalWorkingArtifactCrossCheck = [ordered]@{
    path = $osuToMalodyFullPackageFinalWorkingPath
    exactArtifactRowCount = $osuToMalodyFinalWorkingArtifactRows.Count
    captureSha256 =
        [string]$osuToMalodyFullPackageFinalCaptureWorkingFile.sha256
    independentSha256 =
        [string]$osuToMalodyFullPackageIndependentFinalWorkingFile.sha256
    artifactSha256 = if ($osuToMalodyFinalWorkingArtifactRows.Count -eq 1) {
        [string]$osuToMalodyFinalWorkingArtifactRows[0].sha256
    } else { $null }
    exact = $osuToMalodyFinalWorkingArtifactRows.Count -eq 1 -and
        [long]$osuToMalodyFinalWorkingArtifactRows[0].sizeBytes -eq
            [long]$osuToMalodyFullPackageIndependentFinalWorkingFile.length -and
        [string]$osuToMalodyFinalWorkingArtifactRows[0].sha256 -ceq
            [string]$osuToMalodyFullPackageIndependentFinalWorkingFile.sha256 -and
        [string]$osuToMalodyFinalWorkingArtifactRows[0].sha256 -ceq
            [string]$osuToMalodyFullPackageFinalCaptureWorkingFile.sha256
}
if (-not [bool]$osuToMalodyFinalWorkingArtifactCrossCheck.exact) {
    throw "osu-to-MCZ final working.mc changed between Capture, wrapper recomputation, and artifactOutputs enumeration."
}

$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.slice-evidence.v23"
    generatedAtUtc = [DateTimeOffset]::UtcNow
    status = "slice-passed-migration-incomplete"
    scope = [ordered]@{
        platform = "Windows Avalonia only"
        androidBuiltModifiedInstalledOrTested = $false
        iosBuiltModifiedInstalledOrTested = $false
        macosLinuxWebAssemblyProcessed = $false
        mobileWorkloadsInstalled = $false
        ollvmWaivedByUser = $true
        ollvmMigratedBuiltOrExecuted = $false
        ollvmCountsAsRemainingGate = $false
        productionServerDeployed = $false
        officialInstallerOverwritten = $false
    }
    trustedWpfBaseline = [ordered]@{
        version = "1.1.0"
        installerPath = $formalInstaller.installer.path
        installerSha256 = $formalInstaller.installer.sha256
        specsPassed = $formalWpfStrict.specsExecution.passed
        specsTotal = $formalWpfStrict.specsExecution.total
        warnings = $formalWpfStrict.windowsAppBuild.warnings
        errors = $formalWpfStrict.windowsAppBuild.errors
        productionServerRelease = "20260721200836"
        source = "artifacts/windows-release-1.1.0-final-20260721-r2 formal evidence JSON"
        installerReverifiedSha256 = $officialInstallerSha256
        installerReverifiedAfterSha256 = $officialInstallerSha256After
        sharedWpfWorkspaceReverifiedSha256 = $sharedWpfWorkspaceSha256
        runningWpfProcessesBefore = $wpfProcessesBaseline
        runningWpfProcessesAfter = $wpfProcessesFinal
        wpfProcessSetPreservation = [ordered]@{
            result = "pass"
            dynamicBaseline = $true
            hardcodedProcessId = $false
            preExistingProcessCount = $wpfProcessesBaseline.Count
            finalProcessCount = $wpfProcessesFinal.Count
            exactProcessIdSetPreserved = $true
            responsiveProcessDegraded = $false
            processStartedOrStoppedByThisSlice = $false
            preExistingProcessPreservationProofAvailable =
                $wpfProcessesBaseline.Count -gt 0
            limitation = if ($wpfProcessesBaseline.Count -eq 0) {
                "No WPF process existed at formal-run start, so no specific live WPF PID preservation claim is made; the empty dynamic set remained empty."
            } else {
                "Every dynamically observed pre-existing WPF process retained the same PID/start identity and did not degrade from responsive to unresponsive."
            }
            mismatches = @($wpfProcessPreservationMismatches)
        }
    }
    serverContext = [ordered]@{
        currentProductionRelease = "20260722005907"
        currentReleaseMeaning = "pre-existing explicitly authorized room-lease hotfix; not deployed by this Avalonia slice"
        trustedWpfBaselineRecordedRelease = "20260721200836"
        productionServerDeployedByThisSlice = $false
    }
    gates = [ordered]@{
        captureHarness = [ordered]@{
            path = $captureHarnessPath
            sha256 = $captureHarnessSha256
            astErrors = $captureHarnessAstErrors.Count
            nestedIndexerDirectCastHazards =
                $captureHarnessNestedIndexerDirectCasts.Count
            nonVoidInstanceDirectCastMethodHazards =
                $captureHarnessDirectCastMethodCalls.Count
        }
        formalWrapperStaticAudit = [ordered]@{
            path = $formalWrapperPath
            sha256 = (Get-FileHash -LiteralPath $formalWrapperPath -Algorithm SHA256).Hash
            astErrors = $formalWrapperAstErrors.Count
            nestedIndexerDirectCastHazards =
                $formalWrapperNestedIndexerDirectCasts.Count
            nonVoidInstanceDirectCastMethodHazards =
                $formalWrapperDirectCastMethodCalls.Count
        }
        sourceFilesSelfCheck = [ordered]@{
            result = "pass"
            hashPolicy =
                "runtime before/after SHA-256 and size equality; no hardcoded current product-source SHA"
            hardcodedProductSourceSha256 = $false
            beforeFileCount = $sourceHashesBefore.Count
            afterFileCount = $sourceHashesAfter.Count
            exactPathSetUnchanged = $sourcePathSetUnchanged
            allFilesUnchangedDuringBatch =
                @($sourceHashes | Where-Object {
                        -not [bool]$_.unchangedDuringBatch
                    }).Count -eq 0
            malodyFullPackageExportService =
                $malodyFullPackageServiceSourceEvidence[0]
            avaloniaSpecsProgram = $avaloniaSpecsProgramSourceEvidence[0]
            evidenceNoteFocusPolicy = $evidenceNoteFocusPolicySourceEvidence[0]
            windowsChartExportSources = $windowsChartExportSourceEvidence
        }
        processTempIsolation = [ordered]@{
            result = "pass"
            evidencePath = $tempIsolationEvidencePath
            evidenceSha256 =
                (Get-FileHash -LiteralPath $tempIsolationEvidencePath -Algorithm SHA256).Hash
            details = $tempIsolationEvidence
        }
        avaloniaStrictBuild = [ordered]@{ warnings = 0; errors = 0; run = $avaloniaBuild }
        avaloniaSpecsStrictBuild = [ordered]@{ warnings = 0; errors = 0; run = $avaloniaSpecsBuild }
        mainSpecsStrictBuild = [ordered]@{ warnings = 0; errors = 0; run = $mainSpecsBuild }
        mainSpecsExecution = [ordered]@{ passed = 79; total = 79; result = "pass"; run = $mainSpecsRun }
        verticalSliceExecution = [ordered]@{
            passed = $verticalSliceCheckCount
            total = $verticalSliceCheckCount
            result = "pass"
            formalKeySoundR2RequiredChecks = $formalKeySoundR2Checks.Count
            requiredWindowsDisplayScaleChecks = $requiredWindowsDisplayScaleCheckNames.Count
            formalDisplayScaleR2RequiredChecks = $formalDisplayScaleR2Checks.Count
            requiredWindowsLibrarySearchChecks = $requiredWindowsLibrarySearchCheckNames.Count
            formalLibrarySearchR1RequiredChecks = $formalLibrarySearchR1Checks.Count
            requiredWindowsAudioPanelChecks = $requiredWindowsAudioPanelCheckNames.Count
            formalAudioPanelsR3RequiredChecks = $formalAudioPanelsR3Checks.Count
            requiredWindowsLibraryDeletionChecks = $requiredWindowsLibraryDeletionCheckNames.Count
            formalLibraryDeletionR2RequiredChecks = $formalLibraryDeletionR2Checks.Count
            requiredWindowsChartValidationChecks = $requiredWindowsChartValidationCheckNames.Count
            formalChartValidationR2RequiredChecks = $formalChartValidationR2Checks.Count
            formalLibraryBatchDeletionR3RequiredChecks =
                $formalLibraryBatchDeletionR3Checks.Count
            requiredWindowsMalodyFullPackageChecks =
                $requiredWindowsMalodyFullPackageCheckNames.Count
            malodyFullPackageCheckPlacement = [ordered]@{
                firstOneBasedIndex = $expectedMalodyFullPackageStartIndex + 1
                lastOneBasedIndex =
                    $expectedMalodyFullPackageStartIndex +
                    $requiredWindowsMalodyFullPackageCheckNames.Count
                contiguous = $malodyFullPackagePlacementMismatches.Count -eq 0
                zeroBasedIndices = @($currentMalodyFullPackageCheckIndices)
                mismatches = @($malodyFullPackagePlacementMismatches)
            }
            requiredWindowsOsuFullPackageChecks =
                $requiredWindowsOsuFullPackageCheckNames.Count
            formalOsuFullPackageR2RequiredChecks =
                $formalOsuFullPackageR2Checks.Count
            osuFullPackageCheckPlacement = [ordered]@{
                firstOneBasedIndex = $expectedOsuFullPackageStartIndex + 1
                lastOneBasedIndex =
                    $expectedOsuFullPackageStartIndex +
                    $requiredWindowsOsuFullPackageCheckNames.Count
                contiguous = $osuFullPackagePlacementMismatches.Count -eq 0
                zeroBasedIndices = @($currentOsuFullPackageCheckIndices)
                mismatches = @($osuFullPackagePlacementMismatches)
            }
            requiredWindowsCrossFormatFullPackageChecks =
                $requiredWindowsCrossFormatFullPackageCheckNames.Count
            crossFormatFullPackageCheckPlacement = [ordered]@{
                firstOneBasedIndex = $expectedCrossFormatFullPackageStartIndex + 1
                lastOneBasedIndex =
                    $expectedCrossFormatFullPackageStartIndex +
                    $requiredWindowsCrossFormatFullPackageCheckNames.Count
                contiguous = $crossFormatFullPackagePlacementMismatches.Count -eq 0
                zeroBasedIndices = @($currentCrossFormatFullPackageCheckIndices)
                placementMismatches = @($crossFormatFullPackagePlacementMismatches)
                ordinalMismatches = @($crossFormatFullPackageOrdinalMismatches)
            }
            evidenceNoteFocusContract = [ordered]@{
                oneBasedIndex = 277
                name = $requiredWindowsEvidenceNoteFocusCheckName
                exact = $currentCheckNames.Count -ge 277 -and
                    [string]$currentCheckNames[276] -ceq
                        $requiredWindowsEvidenceNoteFocusCheckName
            }
            authorityCheckSupersession = [ordered]@{
                scope = "one explicit contract replacement; all other predecessor names remain ordinal-exact"
                zeroBasedIndex = $osuPickerFilenameSupersessionZeroBasedIndex
                oneBasedIndex = $osuPickerFilenameSupersessionOneBasedIndex
                supersededName = $supersededOsuWrongExtensionCheckName
                replacementName = $replacementOsuPickerFilenameCheckName
                predecessorAuthorities = @(
                    "formal-osu-full-package-r2",
                    "formal-cross-format-full-package-r1",
                    "formal-osu-to-malody-full-package-r7")
                definitionMismatches = @($authoritySupersessionDefinitionMismatches)
                r7OtherCheckCount =
                    $formalOsuToMalodyFullPackageR7CheckNames.Count - 1
                r7AllOtherChecksOrdinalExact =
                    $authoritySupersessionDefinitionMismatches.Count -eq 0 -and
                    $formalOsuToMalodyFullPackageR7PrefixMismatches.Count -eq 0
            }
            windowsChartExportContracts = [ordered]@{
                firstOneBasedIndex = 278
                lastOneBasedIndex = 294
                requiredCheckCount = $requiredWindowsChartExportCheckNames.Count
                exact = $currentWindowsChartExportCheckNames.Count -eq 17 -and
                    $windowsChartExportOrdinalMismatches.Count -eq 0
                requiredNames = $requiredWindowsChartExportCheckNames
                ordinalMismatches = @($windowsChartExportOrdinalMismatches)
            }
            formalOsuFullPackageR2PrefixAuthority = [ordered]@{
                requiredPrefixCount = $formalOsuFullPackageR2CheckNames.Count
                exactWithOrdinal79Supersession =
                    $formalOsuFullPackageR2PrefixMismatches.Count -eq 0
                mismatches = @($formalOsuFullPackageR2PrefixMismatches)
            }
            formalKeySoundR2EvidencePath = $formalKeySoundR2EvidencePath
            formalKeySoundR2EvidenceSha256 = $formalKeySoundR2EvidenceSha256
            formalKeySoundR2SpecsPath = $formalKeySoundR2SpecsPath
            formalKeySoundR2SpecsSha256 = $formalKeySoundR2SpecsSha256
            formalDisplayScaleR2EvidencePath = $formalDisplayScaleR2EvidencePath
            formalDisplayScaleR2EvidenceSha256 = $formalDisplayScaleR2EvidenceSha256
            formalDisplayScaleR2SpecsPath = $formalDisplayScaleR2SpecsPath
            formalDisplayScaleR2SpecsSha256 = $formalDisplayScaleR2SpecsSha256
            formalLibrarySearchR1EvidencePath = $formalLibrarySearchR1EvidencePath
            formalLibrarySearchR1EvidenceSha256 = $formalLibrarySearchR1EvidenceSha256
            formalLibrarySearchR1SpecsPath = $formalLibrarySearchR1SpecsPath
            formalLibrarySearchR1SpecsSha256 = $formalLibrarySearchR1SpecsSha256
            formalAudioPanelsR3EvidencePath = $formalAudioPanelsR3EvidencePath
            formalAudioPanelsR3EvidenceSha256 = $formalAudioPanelsR3EvidenceSha256
            formalAudioPanelsR3SpecsPath = $formalAudioPanelsR3SpecsPath
            formalAudioPanelsR3SpecsSha256 = $formalAudioPanelsR3SpecsSha256
            formalLibraryDeletionR2EvidencePath = $formalLibraryDeletionR2EvidencePath
            formalLibraryDeletionR2EvidenceSha256 = $formalLibraryDeletionR2EvidenceSha256
            formalLibraryDeletionR2SpecsPath = $formalLibraryDeletionR2SpecsPath
            formalLibraryDeletionR2SpecsSha256 = $formalLibraryDeletionR2SpecsSha256
            formalChartValidationR2EvidencePath = $formalChartValidationR2EvidencePath
            formalChartValidationR2EvidenceSha256 = $formalChartValidationR2EvidenceSha256
            formalChartValidationR2SpecsPath = $formalChartValidationR2SpecsPath
            formalChartValidationR2SpecsSha256 = $formalChartValidationR2SpecsSha256
            formalLibraryBatchDeletionR3EvidencePath =
                $formalLibraryBatchDeletionR3EvidencePath
            formalLibraryBatchDeletionR3EvidenceSha256 =
                $formalLibraryBatchDeletionR3EvidenceSha256
            formalLibraryBatchDeletionR3SpecsPath =
                $formalLibraryBatchDeletionR3SpecsPath
            formalLibraryBatchDeletionR3SpecsSha256 =
                $formalLibraryBatchDeletionR3SpecsSha256
            formalMalodyFullPackageR3EvidencePath =
                $formalMalodyFullPackageR3EvidencePath
            formalMalodyFullPackageR3EvidenceSha256 =
                $formalMalodyFullPackageR3EvidenceSha256
            formalMalodyFullPackageR3SpecsPath =
                $formalMalodyFullPackageR3SpecsPath
            formalMalodyFullPackageR3SpecsSha256 =
                $formalMalodyFullPackageR3SpecsSha256
            formalOsuFullPackageR2EvidencePath =
                $formalOsuFullPackageR2EvidencePath
            formalOsuFullPackageR2EvidenceSha256 =
                $formalOsuFullPackageR2EvidenceSha256
            formalOsuFullPackageR2SpecsPath =
                $formalOsuFullPackageR2SpecsPath
            formalOsuFullPackageR2SpecsSha256 =
                $formalOsuFullPackageR2SpecsSha256
            formalCrossFormatFullPackageR1Authority = [ordered]@{
                evidencePath = $formalCrossFormatFullPackageR1EvidencePath
                evidenceSha256 = $formalCrossFormatFullPackageR1EvidenceSha256
                specsPath = $formalCrossFormatFullPackageR1SpecsPath
                specsSha256 = $formalCrossFormatFullPackageR1SpecsSha256
                requiredCheckCount = $formalCrossFormatFullPackageR1Checks.Count
                exactOrderedCurrentCheckNamesWithOrdinal79Supersession =
                    $formalCrossFormatFullPackageR1OrdinalMismatches.Count -eq 0
                predecessorPrefixOfCurrent294 = $true
                ordinalMismatches = @($formalCrossFormatFullPackageR1OrdinalMismatches)
                completionRemainsFalse = $true
            }
            formalOsuToMalodyFullPackageR7Authority = [ordered]@{
                evidencePath = $formalOsuToMalodyFullPackageR7EvidencePath
                evidenceSha256 = $formalOsuToMalodyFullPackageR7EvidenceSha256
                specsPath = $formalOsuToMalodyFullPackageR7SpecsPath
                specsSha256 = $formalOsuToMalodyFullPackageR7SpecsSha256
                requiredPrefixCount = $formalOsuToMalodyFullPackageR7CheckNames.Count
                exactOrderedPrefixWithOrdinal79Supersession =
                    $formalOsuToMalodyFullPackageR7PrefixMismatches.Count -eq 0
                prefixMismatches = @($formalOsuToMalodyFullPackageR7PrefixMismatches)
                completionRemainsFalse = $true
            }
            exactOrdinalAuthority = $true
            run = $verticalSliceRun
        }
    }
    verticalSlice = $verticalSlice
    implementedEditingSlice = [ordered]@{
        timingEdit = "Combined BPM/delay/effect add, update and delete with exact authored Beat/JSON number text, WPF defaults and culture parsing"
        timingPreflight = "Read-only, Timing permission, original/target owner-lock checks before mutation"
        timingTimeline = "Visible-range indexed WPF-style labels, same-beat stacking, hit testing, mixed marquee selection and release-only Timing movement"
        timelineTools = "Select marquee, Tap, Hold and continuous Erase on one custom-drawn virtualized control"
        exactPlacement = "Cell-center Tap/LN uses PreserveAuthoredBeat; reverse LN normalizes; movement and mixed erase commit once"
        noteMoveGuard = "Pure exact-rational preview clamps lanes/Beat zero, retains the last legal owner-lock destination and cancels on ChangeSerial mismatch"
        edgeScroll = "One dispatcher timer covers marquee, Note/Timing drag, Tap/LN placement and continuous erase with WPF's 42 DIP band and 8 Beat/s curve"
        lnTailResize = "EndBeat-indexed tail hit testing, exact cell-center pure preview, owner-lock last-legal retention, ChangeSerial cancellation, edge scroll, captured-pointer release/capture-loss single commit and Tap collapse"
        noteTypeTransform = "Shared NoteTypeTransformService powers LN-to-Tap IncludeTail/Fill/HeadOnly and Tap-to-LN with source/target owner-lock preflight, exact authored Beat, one mutation/undo and result selection; IncludeTail is exercised by actual Windows pointer input"
        notePropertyInspector = "A thin Windows Note-property command and visible inspector apply exact authored Beat/EndBeat, official or D: draft lane, clamped volume, validated Sound and Group in one mutation/undo after source/target owner-lock preflight; a real MC is edited through UI Automation plus actual mouse input, saved and reopened"
        groupManager = "Per-tab Group placement and visibility state, visible/unlocked assignment, dissolve, fixed color badges, keyboard-nudge filtering and linear-time hidden-selection pruning share thin Windows commands; a real isolated MC is assigned to Group 7 and saved, reopened in fresh processes, hidden without history, then receives exact grouped Tap/LN placement through actual mouse input"
        proEditor = "A single custom TimelineSurface reveals configured and fixture-extended draft columns, pans horizontally without document mutation, places a draft Tap, crosses it into an official lane with exact rational Beat, places a draft LN, saves compact MC, fresh-reopens, exports through the native Windows Save As dialog and proves fresh osu reopen excludes drafts"
        mixedCommands = "Persistent Note plus Effect selection, WPF payload copy, red-line aligned paste, list/right-click/global batch delete and text-focus-safe shortcuts"
        ownerProtectionUi = "Continuous owner-region drawing plus read-only, Note, Timing, metadata and lock counts in the editor inspector"
        windowsAudioCore = "Decoder, serialized transport, preserve-pitch rate, owner-bound playback epochs and strict shared-output Key-sound submission pass deterministic Windows Specs; audible/device/loopback validation remains open"
        windowsAudioGui = "Real MC/osu relative audio resolves beside the source chart and loads into visible play/pause, stop, seek, volume, 0.2-1.0x, preserve-pitch and device-refresh controls; no audible-playback pass is claimed"
        windowsAudioVisualization = "WPF-capacity 2,000,000-bucket waveform and 180,000-frame spectrum decode asynchronously with revision latest-wins; one TimelineSurface plus two clipped side custom surfaces draw retained three-viewport scenes without per-sample Controls"
        windowsAudioPanels = "WPF-compatible default Side waveform/spectrogram state, opposite-side docking, free toolbar drag, Background mode, collapse/expand and independent atomic settings are proven by eight deterministic Specs plus three real Windows launches; display-present, audible output and full hardware performance gates remain open"
        windowsKeySound = "WPF-matched Note/LN filtering, custom-sample fallback/preload, exact offset/lookahead/chord scheduling, generation invalidation and capacity-one clock sampling feed either the shared music output or a silent editor clock; real UIA/mouse Preview, Play and Stop submit logical triggers on both paths, without claiming audible or loopback validation"
        windowsDisplayScale = "Visible Settings UIA RangeValue controls apply 135% UI and 125% font scaling through a real LayoutTransform/font baseline controller, persist under an isolated Avalonia LocalDataRoot, restore unchanged in a fresh process, and independently recover corrupt JSON to schema 1 / UI 1 / font 1 without a leftover atomic-save temporary file; PrintWindow and runtime diagnostics are not display-present or full multi-DPI acceptance"
        windowsLibrarySearch = "A real indexed Windows library now distinguishes zero filtered results from a truly empty workspace: exact WPF title/subtitle appear while the in-panel launcher actions and filtered list stay hidden; the isolated GUI chain records visible UIA peers, query submission and a real screenshot"
        windowsLibraryDeletion = "A random unique three-folder real Resound workspace proves open-document deletion blocking with exact warning/Ctrl+C copy, four physical Shift/Ctrl multi-selection states, selected-item right-click preservation, a two-folder question plan and two undo-enabled shell recycle results; Namespace(10) is queried only by exact original Name plus System.Recycle.DeletedFrom, every target is undeleted in finally, full entries/bytes/SHA-256/mtime trees match, and a fresh read-only process re-indexes all three folders"
        windowsChartValidation = "The real Resound baseline is required to validate clean before guarded evidence injection; exactly one overlap and one crossing-LN issue then prove exact WPF manual/save-block copy, first-issue Group 7 reveal while Group 8 remains hidden, exact rational navigation, two-Note selection, Note inspector/status UIA, timeline issue rendering cross-check, 135%/125% dialogs and byte/length/mtime-preserving fail-closed Save"
        windowsChartExportModes = "The shared four-mode planner/service and Windows audio adapter cover the tested WPF SingleChart, FullPackage, SingleRatePackage and RatePack planning, exact rational chart transforms, compact MC/flat archives and atomic replacement. The exact 294-check authority proves source-first package-resource resolution without localized-cache fallback after source deletion, a 1.0x core path off the caller thread, cancellation during compression with target/scratch preservation, and dominant-frequency observations of 551.3 Hz rate-adjusted versus 441.0 Hz PreservePitch-requested output. Actual GUI closure remains limited to Malody SingleRatePackage 1.25x PreservePitch-requested native Save/result plus independent package decode; no audible validation is claimed."
        windowsMalodyFullPackage = "The actual Windows Avalonia Export toolbar opens the owner-bound Malody/FullPackage/1.0x dialog, uses verified native Pane-backed Save/Open filename and submit controls, packages an unsaved exact expanded rational Beat into the explicit 1622528438.mc main entry with all eight compact sibling MC files and collision-suffixed resources, preserves source/working/dirty/serial identity, removes owned scratch on normal discard/exit, then a fresh second process validates the 8/0/0 preview, opens the exact eight chart paths, and is independently rechecked against one main plus seven sibling semantics and the flat 13-file archive/fresh byte tree"
        windowsOsuFullPackage = "A second actual Windows Avalonia Export run physically selects osu!mania FullPackage 1.0x, submits OD 8.75 / HP 9, exports a dirty moved HitObject into a flat seven-entry OSZ from the exact five-file Michishirube source, then a fresh process previews two charts, physically calibrates both ordered import dialogs, verifies archive/fresh hashes and exits normally without owned scratch."
        windowsMalodyToOsuFullPackage = "A third actual Windows Avalonia Export run opens the trusted 1622528438.mc, physically moves the unique 182:1/4 tap from internal lane 1 to lane 2 while retaining the authored 182:2/8 representation in the dirty session, physically selects osu!mania FullPackage 1.0x with OD 8.75 / HP 9, emits exactly one v14 osu chart plus four byte-verified collision resources and no source chart/archive decoys, then a fresh process previews one chart, performs exactly one physical Calibrate click, proves 4K / 1,608 Note / 18 LN / 1 Timing structural equivalence and exits normally without owned scratch."
        windowsOsuToMalodyFullPackage = "A fourth actual Windows Avalonia Export run opens the trusted flat Michishirube osu source, physically moves the unique lane-2 15:5/6 tap to lane 3 while retaining the exact deliberately non-reduced 15:10/12 representation, physically selects Malody FullPackage 1.0x, emits one dynamically named compact *_1x.mc plus five byte-verified resource entries and no osu/MC/archive decoys, then a fresh process previews exactly one chart without calibration, proves the exact six-file archive/fresh byte tree, 4K / 2,468 Note / 303 LN / 13 Timing+Effect structure, exact target-note navigation and normal scratch-free exit."
        windowsCrossFormatFullPackageSpecs = "The v20 276/276 predecessor authority remains ordinal-exact except for the single recorded ordinal-79 osu picker-filename contract supersession and includes eight contiguous checks 269..276 covering MC-to-OSZ and osu-to-MCZ export semantics; current 294 Specs retain the unique ordinal-277 Note-focus policy contract and append seventeen exact Windows chart-export checks at ordinals 278..294, while both cross-format directions have separate actual native Save/Open GUI closure."
        scopeStatus = "passed slice; full WPF editor parity remains incomplete"
    }
    fixtures = [ordered]@{
        realMc = [ordered]@{ path = $fixturePath; sha256BeforeAndAfter = $fixtureSha256; isolatedPath = $isolatedMcPath }
        realMcNoteProperty = [ordered]@{
            path = $fixturePath
            trustedSha256BeforeAndAfter = $fixtureSha256
            isolatedPath = $isolatedPropertyMcPath
            isolatedSha256Before = $fixtureSha256
            isolatedSha256AfterSave = $propertySavedSha256
        }
        realMcGroupManager = [ordered]@{
            path = $fixturePath
            trustedSha256BeforeAndAfter = $fixtureSha256
            isolatedPath = $isolatedGroupMcPath
            isolatedSha256Before = $fixtureSha256
            isolatedSha256AfterGroupAssignmentSave = $groupSavedSha256
            isolatedSha256AfterUnsavedVisibilityAndPlacement = `
                (Get-FileHash -LiteralPath $isolatedGroupMcPath -Algorithm SHA256).Hash
        }
        realOsu = [ordered]@{ path = $osuFixturePath; sha256BeforeAndAfter = $osuFixtureSha256; isolatedPath = $isolatedOsuPath }
        realChartExportModes = [ordered]@{
            sourceRoot = $chartExportModesSourceRoot
            sourceTreeBefore = $chartExportModesSourceTreeBefore
            sourceTreeAfter = $chartExportModesSourceTreeAfter
            expectedSourceHashes = $chartExportModesExpectedSourceHashes
            exportedPackagePath = $chartExportModesExportPath
            exportedPackageSha256 = $chartExportModesArchiveEvidence.sha256
            package = $chartExportModesArchiveEvidence
        }
        realMcz = [ordered]@{
            path = $archiveFixturePath
            sha256BeforeAndAfter = $archiveFixtureSha256
            isolatedSourceRoot = $malodyFullPackageSourceRoot
            isolatedSourceTreeBefore = $malodyFullPackageSourceTreeBefore
            isolatedSourceTreeAfter = $malodyFullPackageSourceTreeAfter
            isolatedMainChartPath = $malodyFullPackageMainChartPath
            isolatedMainChartSha256BeforeAndAfter = $malodyFullPackageMainSourceSha256
            siblingMcCount = $malodyFullPackageSourceMcFiles.Count
            shadowMcCount = $malodyFullPackageSourceShadowMcFiles.Count
            exactFocusTap = [ordered]@{
                beat = "182:1/4"
                lane = 1
                matchCount = $malodyFullPackageFocusSourceMatches.Count
                longNote = $false
            }
            exportedPackagePath = $malodyFullPackageExportPath
            exportedPackageSha256 = $malodyFullPackageArchiveEvidence.sha256
        }
        realOsz = [ordered]@{
            trustedSourceRoot = $osuFullPackageTrustedSourceRoot
            isolatedSourceRoot = $osuFullPackageSourceRoot
            isolatedSourceTreeBefore = $osuFullPackageSourceTreeBefore
            isolatedSourceTreeAfter = $osuFullPackageSourceTreeAfter
            exactStagedSourceFileCount = 5
            mainChartPath = $osuFullPackageMainChartPath
            siblingChartPath = $osuFullPackageSiblingChartPath
            expectedSourceHashes = $osuFullPackageExpectedSourceHashes
            exportedPackagePath = $osuFullPackageExportPath
            exportedPackageSha256 =
                (Get-FileHash -LiteralPath $osuFullPackageExportPath -Algorithm SHA256).Hash
            archiveFileCount = $osuFullPackageArchiveManifest.fileCount
            freshFileCount = $osuFullPackageFreshManifest.fileCount
        }
        realMalodyToOsz = [ordered]@{
            trustedMczPath = $archiveFixturePath
            trustedMczSha256BeforeAndAfter = $archiveFixtureSha256
            isolatedSourceRoot = $malodyToOsuFullPackageSourceRoot
            isolatedSourceTreeBefore = $malodyToOsuFullPackageSourceTreeBefore
            isolatedSourceTreeAfter = $malodyToOsuFullPackageSourceTreeAfter
            exactStagedSourceFileCount = $malodyToOsuFullPackageSourceTreeBefore.fileCount
            siblingMcCount = $malodyToOsuFullPackageSourceMcFiles.Count
            shadowMcCount = $malodyToOsuFullPackageSourceShadowMcFiles.Count
            archiveDecoyCount = $malodyToOsuFullPackageSourceArchiveDecoys.Count
            mainChartPath = $malodyToOsuFullPackageMainChartPath
            mainChartSha256BeforeAndAfter = $malodyToOsuFullPackageMainSourceSha256
            dirtyInjection = $malodyToOsuFullPackageExportEvidence.dirtyInjection
            expectedMainChartFileName = $malodyToOsuFullPackageMainFileName
            exportedPackagePath = $malodyToOsuFullPackageExportPath
            exportedPackageSha256 =
                (Get-FileHash -LiteralPath $malodyToOsuFullPackageExportPath -Algorithm SHA256).Hash
            archiveManifest = $malodyToOsuFullPackageArchiveManifest
            freshManifest = $malodyToOsuFullPackageFreshManifest
            archiveFreshMismatches = @($malodyToOsuFullPackageArchiveFreshMismatches)
        }
        realOsuToMcz = [ordered]@{
            trustedSourceRoot = $osuFullPackageTrustedSourceRoot
            trustedMainChartPath = $osuFixturePath
            trustedMainChartSha256BeforeAndAfter = $osuFixtureSha256
            isolatedSourceRoot = $osuToMalodyFullPackageSourceRoot
            isolatedSourceTreeBefore = $osuToMalodyFullPackageSourceTreeBefore
            isolatedSourceTreeAfter = $osuToMalodyFullPackageSourceTreeAfter
            exactStagedSourceFileCount = $osuToMalodyFullPackageSourceTreeBefore.fileCount
            sourceOsuCount = $osuToMalodyFullPackageSourceOsuFiles.Count
            sourceMcDecoyCount = $osuToMalodyFullPackageSourceMcFiles.Count
            sourceArchiveDecoyCount = $osuToMalodyFullPackageSourceArchiveDecoys.Count
            expectedSourceHashes = $osuToMalodyFullPackageExpectedSourceHashes
            sourceHashMismatches = @($osuToMalodyFullPackageSourceHashMismatches)
            mainChartPath = $osuToMalodyFullPackageMainChartPath
            dirtyInjection = $osuToMalodyDirtyInjection
            dynamicMainChartFileName = $osuToMalodyFullPackageMainTargetFileName
            exportedPackagePath = $osuToMalodyFullPackageExportPath
            exportedPackageSha256 = $osuToMalodyFullPackageIndependentArchive.sha256
            archiveManifest = $osuToMalodyFullPackageArchiveManifest
            freshManifest = $osuToMalodyFullPackageFreshManifest
            archiveFreshMismatches = @($osuToMalodyFullPackageArchiveFreshMismatches)
        }
        keySoundSharedClock = [ordered]@{
            chartPath = $fixturePath
            chartSha256BeforeAndAfter = $fixtureSha256
            audioPath = $keySoundSampleSourcePath
            audioSha256BeforeAndAfter = $keySoundSampleSourceSha256
            isolatedChartPath = $isolatedKeySoundSharedMcPath
            isolatedAudioPath = $isolatedKeySoundSharedAudioPath
        }
        keySoundSilentClock = [ordered]@{
            chartPath = $keySoundFlatFixturePath
            chartSha256BeforeAndAfter = $keySoundFlatFixtureSha256
            sampleSourcePath = $keySoundSampleSourcePath
            sampleSourceSha256BeforeAndAfter = $keySoundSampleSourceSha256
            isolatedChartPath = $isolatedKeySoundSilentMcPath
            isolatedKickPath = $isolatedKeySoundKickPath
            isolatedKickSha256 = (Get-FileHash -LiteralPath $isolatedKeySoundKickPath -Algorithm SHA256).Hash
        }
        displayScale = [ordered]@{
            chartPath = $fixturePath
            chartSha256BeforeAndAfter = $fixtureSha256
            isolatedChartPath = $isolatedMcPath
            localDataRoot = $displayScaleLocalDataRoot
            settingsPath = $displayScaleSettingsPath
            settingsSha256AfterSubmitAndReopen = $displayScaleSettingsSha256AfterReopen
            requestedUiScale = 1.35
            requestedFontScale = 1.25
            corruptRecovery = [ordered]@{
                localDataRoot = $displayScaleCorruptLocalDataRoot
                settingsPath = $displayScaleCorruptSettingsPath
                settingsSha256Before = $displayScaleCorruptSettingsSha256Before
                settingsSha256After = $displayScaleCorruptSettingsSha256After
                temporaryFileCountAfter = $displayScaleCorruptTemporaryFiles.Count
                recoveredUiScale = 1
                recoveredFontScale = 1
                displayScaleInitialized = $true
            }
        }
        audioPanels = [ordered]@{
            chartPath = $fixturePath
            chartSha256BeforeAndAfter = $fixtureSha256
            isolatedChartPath = $isolatedMcPath
            defaultLocalDataRoot = $audioPanelDefaultLocalDataRoot
            defaultSettingsPath = $audioPanelDefaultSettingsPath
            defaultSettingsSha256 = $audioPanelDefaultSettingsSha256
            exercisedLocalDataRoot = $audioPanelLocalDataRoot
            exercisedSettingsPath = $audioPanelSettingsPath
            exercisedSettingsSha256AfterInteractionAndReopen = $audioPanelSettingsSha256AfterReopen
        }
        chartValidation = [ordered]@{
            chartPath = $fixturePath
            trustedSha256BeforeAndAfter = $fixtureSha256
            isolatedChartPath = $isolatedChartValidationMcPath
            sourceBefore = $chartValidationSourceBefore
            sourceAfter = $chartValidationSourceAfter
            baselineIssueCount = $chartValidationBaselineIssueCount
            baselineProof = "The successful --evidence-focus-chart-validation startup is paired with a source-asserted fail-closed baseline.CanSave and empty Group 7/8 guard before injection."
            baselineGuardSourcePath = $chartValidationBaselineGuardSourcePath
            baselineGuardSourceSha256 =
                (Get-FileHash -LiteralPath $chartValidationBaselineGuardSourcePath -Algorithm SHA256).Hash
            injectedIssueCount = 2
            injectedOverlappingNoteCount = 1
            injectedCrossingLongNoteCount = 1
            localDataRoot = $chartValidationLocalDataRoot
            settingsPath = $chartValidationScaleSettingsPath
            requestedUiScale = 1.35
            requestedFontScale = 1.25
        }
        libraryBatchDeletion = [ordered]@{
            validationLevel = "real-open-block-physical-multiselect-shell-recycle-exact-namespace-restore-fresh-index"
            randomToken = $libraryBatchToken
            workspaceRoot = $libraryBatchWorkspaceRoot
            realChartSourcePath = $fixturePath
            realChartSourceSha256BeforeAndAfter = $fixtureSha256
            realAudioSourcePath = $keySoundSampleSourcePath
            realAudioSourceSha256BeforeAndAfter = $keySoundSampleSourceSha256
            realCoverSourcePath = $resoundCoverSourcePath
            realCoverSourceSha256BeforeAndAfter = $resoundCoverSourceSha256
            roles = $libraryBatchRecoveryEvidence.roles
            treesBefore = $libraryBatchTreesBefore
            treesAfterRestore = $libraryBatchTreesAfterRestore
            treesAfterFreshProcess = $libraryBatchTreesAfterFresh
            openSourceBefore = $libraryBatchOpenSourceBefore
            openSourceAfterRestore = $libraryBatchOpenSourceAfterRestore
            openSourceAfterFreshProcess = $libraryBatchOpenSourceAfterFresh
            recoveryEvidencePath = $libraryBatchRecoveryEvidencePath
            recoveryEvidenceSha256 =
                (Get-FileHash -LiteralPath $libraryBatchRecoveryEvidencePath -Algorithm SHA256).Hash
        }
        authoritativeLibraryDeletionR2 = [ordered]@{
            evidencePath = $formalLibraryDeletionR2EvidencePath
            evidenceSha256 = $formalLibraryDeletionR2EvidenceSha256
            specsPath = $formalLibraryDeletionR2SpecsPath
            specsSha256 = $formalLibraryDeletionR2SpecsSha256
            rerunByThisSlice = $false
        }
        authoritativeChartValidationR2 = [ordered]@{
            evidencePath = $formalChartValidationR2EvidencePath
            evidenceSha256 = $formalChartValidationR2EvidenceSha256
            specsPath = $formalChartValidationR2SpecsPath
            specsSha256 = $formalChartValidationR2SpecsSha256
            rerunByThisSlice = $true
            rerunMeaning = "The complete existing chart-validation regression remains active while the immutable r2 authority is referenced exactly."
        }
        authoritativeLibraryBatchDeletionR3 = [ordered]@{
            evidencePath = $formalLibraryBatchDeletionR3EvidencePath
            evidenceSha256 = $formalLibraryBatchDeletionR3EvidenceSha256
            specsPath = $formalLibraryBatchDeletionR3SpecsPath
            specsSha256 = $formalLibraryBatchDeletionR3SpecsSha256
            rerunByThisSlice = $true
            rerunMeaning = "Every library-batch-deletion r3 build/Specs/GUI/recycle/restore/fresh-index gate remains active while the immutable r3 authority is referenced exactly."
        }
        proEditorNoteref = [ordered]@{
            path = $proEditorFixturePath
            trustedSha256BeforeAndAfter = $proEditorFixtureSha256
            isolatedPanPath = $isolatedProEditorPanPath
            isolatedEditPath = $isolatedProEditorEditPath
            compactSavedSha256 = $proEditorSavedSha256
            compactSavedBytes = (Get-Item -LiteralPath $isolatedProEditorEditPath).Length
            savedAsOsuPath = $isolatedProEditorOsuPath
            savedAsOsuSha256 = $proEditorOsuSha256
        }
    }
    gui = [ordered]@{
        captureMethod = "Win32 PrintWindow(PW_RENDERFULLCONTENT) of actually launched Windows Avalonia windows; four separate FullPackage paths are exercised: same-format MC-to-MCZ, same-format osu-to-OSZ with two physical calibrations, cross-format MC-to-OSZ with one physical calibration, and cross-format osu-to-MCZ with exact authored-Beat focus after fresh import. A fifth run exercises all four export modes plus an actual Malody SingleRate 1.25x PreservePitch-requested native Save/result path with IME-safe physical input. Explorer reveal is suppressed only under an explicit evidence argument; this is neither display scan-out nor audible/loopback/pitch validation"
        application = [ordered]@{
            path = $avaloniaApplicationPath
            sha256 = (Get-FileHash -LiteralPath $avaloniaApplicationPath -Algorithm SHA256).Hash
        }
        libraryHome = [ordered]@{ run = $libraryCapture; screenshot = $libraryScreenshot }
        librarySearchZero = [ordered]@{
            run = $libraryNoResultsCapture
            runtime = $libraryNoResultsGui
            screenshot = $libraryNoResultsScreenshot
        }
        realMc = [ordered]@{
            run = $realCapture
            runtime = $realGui
            lnTailRuntime = $realInteractionGui
            screenshot = $realScreenshot
        }
        realMcNoteTransform = [ordered]@{
            run = $transformCapture
            runtime = $transformGui
            transformedRuntime = $transformInteractionGui
            screenshot = $transformScreenshot
        }
        realMcNoteProperty = [ordered]@{
            run = $propertyCapture
            runtime = $propertyGui
            savedRuntime = $propertyInteractionGui
            screenshot = $propertyScreenshot
            isolatedSourceSha256AfterSave = $propertySavedSha256
            reopenRun = $propertyReopenCapture
            reopenedRuntime = $propertyReopenGui
            reopenedScreenshot = $propertyReopenScreenshot
        }
        realMcGroupManager = [ordered]@{
            assignAndSave = [ordered]@{
                run = $groupAssignCapture
                runtime = $groupAssignGui
                savedRuntime = $groupSavedGui
                screenshot = $groupSavedScreenshot
                isolatedSourceSha256AfterSave = $groupSavedSha256
            }
            freshReopenAndHide = [ordered]@{
                run = $groupVisibilityCapture
                reopenedRuntime = $groupVisibilityGui
                hiddenRuntime = $groupHiddenGui
                screenshot = $groupHiddenScreenshot
            }
            freshReopenAndPlaceTapHold = [ordered]@{
                run = $groupPlacementCapture
                reopenedRuntime = $groupPlacementGui
                placedRuntime = $groupPlacedGui
                screenshot = $groupPlacedScreenshot
            }
        }
        realOsuCalibrated = [ordered]@{
            run = $osuCapture
            runtime = $osuGui
            edgeScrollRuntime = $osuInteractionGui
            screenshot = $osuScreenshot
        }
        synthetic100000Note = [ordered]@{ run = $hundredKCapture; runtime = $hundredKGui; screenshot = $hundredKScreenshot }
        keySound = [ordered]@{
            validationLevel = "scheduler-and-output-submission"
            audibleOrLoopbackValidated = $false
            realResoundSharedMusicClock = [ordered]@{
                run = $keySoundSharedCapture
                initialRuntime = $keySoundSharedGui
                submittedRuntime = $keySoundSharedInteractionGui
                screenshot = $keySoundSharedScreenshot
            }
            flatFixtureSilentEditorClock = [ordered]@{
                run = $keySoundSilentCapture
                initialRuntime = $keySoundSilentGui
                submittedRuntime = $keySoundSilentInteractionGui
                screenshot = $keySoundSilentScreenshot
            }
        }
        displayScale = [ordered]@{
            requestedUiScale = 1.35
            requestedFontScale = 1.25
            settingsPath = $displayScaleSettingsPath
            settingsSha256AfterSubmitAndReopen = $displayScaleSettingsSha256AfterReopen
            changeAndPersist = [ordered]@{
                run = $displayScaleCapture
                initialRuntime = $displayScaleGui
                submittedRuntime = $displayScaleInteractionGui
                screenshot = $displayScaleScreenshot
            }
            freshProcessReopen = [ordered]@{
                run = $displayScaleReopenCapture
                reopenedRuntime = $displayScaleReopenGui
                screenshot = $displayScaleReopenScreenshot
            }
            corruptSettingsRecovery = [ordered]@{
                run = $displayScaleCorruptCapture
                recoveredRuntime = $displayScaleCorruptGui
                screenshot = $displayScaleCorruptScreenshot
                settingsSha256Before = $displayScaleCorruptSettingsSha256Before
                settingsSha256After = $displayScaleCorruptSettingsSha256After
                temporaryFileCountAfter = $displayScaleCorruptTemporaryFiles.Count
            }
        }
        audioPanels = [ordered]@{
            validationLevel = "real-window-layout-scene-persistence"
            settingsPath = $audioPanelSettingsPath
            settingsSha256AfterInteractionAndReopen = $audioPanelSettingsSha256AfterReopen
            independentDefault = [ordered]@{
                run = $audioPanelDefaultCapture
                runtime = $audioPanelDefaultGui
                screenshot = $audioPanelDefaultScreenshot
                settingsPath = $audioPanelDefaultSettingsPath
                settingsSha256 = $audioPanelDefaultSettingsSha256
            }
            modeCollapseDrag = [ordered]@{
                run = $audioPanelCapture
                initialRuntime = $audioPanelGui
                interactionRuntime = $audioPanelInteractionGui
                screenshot = $audioPanelScreenshot
            }
            freshProcessReopen = [ordered]@{
                run = $audioPanelReopenCapture
                reopenedRuntime = $audioPanelReopenGui
                screenshot = $audioPanelReopenScreenshot
            }
        }
        authoritativeLibraryDeletionR2 = [ordered]@{
            validationLevel = "referenced-immutable-formal-authority-not-rerun"
            evidencePath = $formalLibraryDeletionR2EvidencePath
            evidenceSha256 = $formalLibraryDeletionR2EvidenceSha256
            specsPath = $formalLibraryDeletionR2SpecsPath
            specsSha256 = $formalLibraryDeletionR2SpecsSha256
            rerunByThisSlice = $false
        }
        libraryBatchDeletion = [ordered]@{
            validationLevel = "real-open-document-block-and-two-folder-batch-recycle-with-finally-restore"
            workspaceRoot = $libraryBatchWorkspaceRoot
            randomToken = $libraryBatchToken
            openDocumentBlock = [ordered]@{
                run = $libraryBatchOpenCapture
                primaryRuntime = $libraryBatchOpenGui
                interactionRuntime = $libraryBatchOpenInteractionGui
                finalScreenshot = $libraryBatchOpenScreenshot
                contextMenuScreenshot = $libraryBatchOpenMenuScreenshot
                warningDialogScreenshot = $libraryBatchOpenDialogScreenshot
            }
            batchDeleteConfirm = [ordered]@{
                run = $libraryBatchDeleteCapture
                primaryRuntime = $libraryBatchDeleteGui
                interactionRuntime = $libraryBatchDeleteInteractionGui
                finalScreenshot = $libraryBatchDeleteScreenshot
                contextMenuScreenshot = $libraryBatchDeleteMenuScreenshot
                questionDialogScreenshot = $libraryBatchDeleteDialogScreenshot
            }
            exactRecycleBin = [ordered]@{
                namespace = 10
                matching = "case-exact original Name plus case-insensitive normalized System.Recycle.DeletedFrom reconstructed full original path"
                broadEnumerationUsedOnlyForExactFiltering = $true
                recycleBinCleared = $false
                fuzzyRestoreUsed = $false
                before = $libraryBatchRecycleBefore
                afterOpenBlock = $libraryBatchRecycleAfterOpenBlock
                afterBatch = $libraryBatchRecycleAfterBatch
                restoreActions = $libraryBatchRestoreActions
                afterRestore = $libraryBatchRecycleAfterRestore
                afterFreshProcess = $libraryBatchRecycleAfterFresh
            }
            freshReadOnlyIndex = [ordered]@{
                run = $libraryBatchRestoredCapture
                runtime = $libraryBatchRestoredGui
                screenshot = $libraryBatchRestoredScreenshot
                expectedIndexedFolderCount = 3
                expectedVisibleFolderCount = 3
            }
            fullRecoveryEvidencePath = $libraryBatchRecoveryEvidencePath
            fullRecoveryEvidenceSha256 =
                (Get-FileHash -LiteralPath $libraryBatchRecoveryEvidencePath -Algorithm SHA256).Hash
        }
        authoritativeLibraryBatchDeletionR3 = [ordered]@{
            validationLevel = "referenced-immutable-formal-authority-and-complete-regression-rerun"
            evidencePath = $formalLibraryBatchDeletionR3EvidencePath
            evidenceSha256 = $formalLibraryBatchDeletionR3EvidenceSha256
            specsPath = $formalLibraryBatchDeletionR3SpecsPath
            specsSha256 = $formalLibraryBatchDeletionR3SpecsSha256
            rerunByThisSlice = $true
        }
        chartValidation = [ordered]@{
            validationLevel = "real-chart-manual-check-and-fail-closed-save"
            baselineIssueCount = $chartValidationBaselineIssueCount
            injectedIssueCount = 2
            injectedOverlappingNoteCount = 1
            injectedCrossingLongNoteCount = 1
            requestedUiScale = 1.35
            requestedFontScale = 1.25
            run = $chartValidationCapture
            primaryRuntime = $chartValidationGui
            interactionRuntime = $chartValidationInteractionGui
            sourceBefore = $chartValidationSourceBefore
            sourceAfter = $chartValidationSourceAfter
            manualDialogScreenshot = $chartValidationManualDialogScreenshot
            saveBlockedDialogScreenshot = $chartValidationSaveBlockedDialogScreenshot
            finalScreenshot = $chartValidationScreenshot
        }
        authoritativeChartValidationR2 = [ordered]@{
            validationLevel = "referenced-immutable-formal-authority-and-complete-regression-rerun"
            evidencePath = $formalChartValidationR2EvidencePath
            evidenceSha256 = $formalChartValidationR2EvidenceSha256
            specsPath = $formalChartValidationR2SpecsPath
            specsSha256 = $formalChartValidationR2SpecsSha256
            rerunByThisSlice = $true
        }
        proEditor = [ordered]@{
            pan = [ordered]@{
                run = $proEditorPanCapture
                runtime = $proEditorPanGui
                pannedRuntime = $proEditorPannedGui
                screenshot = $proEditorPanScreenshot
            }
            editAndSave = [ordered]@{
                run = $proEditorEditCapture
                runtime = $proEditorEditGui
                savedRuntime = $proEditorSavedGui
                screenshot = $proEditorEditScreenshot
            }
            freshMcReopen = [ordered]@{
                run = $proEditorReopenCapture
                runtime = $proEditorReopenGui
                revealedRuntime = $proEditorReopenInteractionGui
                screenshot = $proEditorReopenScreenshot
            }
            nativeSaveAsOsu = [ordered]@{
                run = $proEditorSaveAsCapture
                runtime = $proEditorSaveAsGui
                savedAsRuntime = $proEditorSavedAsGui
                screenshot = $proEditorSaveAsScreenshot
            }
            freshOsuReopen = [ordered]@{
                run = $proEditorOsuReopenCapture
                runtime = $proEditorOsuReopenGui
                revealedRuntime = $proEditorOsuReopenInteractionGui
                screenshot = $proEditorOsuReopenScreenshot
            }
        }
        chartExportModes = [ordered]@{
            validationLevel = "actual-four-mode-dialog-hidden-validation-native-save-and-independent-single-rate-package-decode"
            sourceRoot = $chartExportModesSourceRoot
            sourceTreeBefore = $chartExportModesSourceTreeBefore
            sourceTreeAfter = $chartExportModesSourceTreeAfter
            expectedSourceHashes = $chartExportModesExpectedSourceHashes
            sourceHashMismatches = @($chartExportModesSourceHashMismatches)
            contractChecks = $windowsChartExportChecks
            run = $chartExportModesCapture
            primaryRuntime = $chartExportModesGui
            interactionRuntime = $chartExportModesInteractionGui
            dialogAndActualExport = $chartExportModesEvidence
            package = $chartExportModesArchiveEvidence
            cleanup = [ordered]@{
                scratchRoot = $chartExportModesScratchRoot
                scratchEntryCount = $chartExportModesScratchEntries.Count
                temporaryArchiveCount = $chartExportModesTemporaryArchives.Count
                processCountAfterCapture = $chartExportModesProcess.Count
            }
            screenshots = [ordered]@{
                editorFinal = $chartExportModesScreenshot
                defaultFullPackage = $chartExportModesDefaultScreenshot
                singleChart = $chartExportModesSingleChartScreenshot
                singleRatePackage = $chartExportModesSingleRateScreenshot
                ratePack = $chartExportModesRatePackScreenshot
                hiddenFieldValidation = $chartExportModesHiddenValidationScreenshot
                actualResult = $chartExportModesResultScreenshot
            }
            explorerRevealSuppressedOnlyForEvidence = $true
            normalProductBehaviorRevealsDestination = $true
        }
        malodyFullPackage = [ordered]@{
            validationLevel = "real-dirty-main-native-pane-save-eight-chart-manifest-flat-thirteen-file-tree-fresh-native-pane-import"
            productSafetySpecs = [ordered]@{
                validationLevel =
                    "exact current 294/294 runtime Specs: ordered v20 276-check predecessor with only the recorded ordinal-79 picker-filename contract supersession, one unique Note-focus policy check at ordinal 277, and seventeen ordered Windows chart-export checks at ordinals 278..294, with prior MCZ direct-coverage semantics preserved"
                specsPath = $verticalSlicePath
                specsSha256 =
                    (Get-FileHash -LiteralPath $verticalSlicePath -Algorithm SHA256).Hash
                selectedCheckCount = $malodyFullPackageSafetyChecks.Count
                selectedChecks = $malodyFullPackageSafetyChecks
                fileSymlink = [ordered]@{
                    status = "direct-validation-unavailable-not-complete"
                    directValidationAvailable = $false
                    directCoverage = $false
                    win32Error = 1314
                    hresult = "0x80070522"
                    privilegeUnavailable = $true
                    fallbackCoverage = "managed-scratch-pruning"
                    limitation =
                        "The current Windows token cannot create a file symbolic link, so direct file-symlink materialization is not claimed; capability failure is exact Win32 1314 and the staged-missing fallback branch is covered independently."
                    capabilityCheck = $malodyFullPackageFileSymlinkCapabilityCheck
                    fallbackCheck = $malodyFullPackageFallbackResourceCheck
                }
                directoryJunction = [ordered]@{
                    directCoverage = $true
                    realReparsePointCreated = $true
                    materializedResource = $true
                    capabilityCheck =
                        $malodyFullPackageDirectoryJunctionCapabilityCheck
                    materializationCheck =
                        $malodyFullPackageDirectoryJunctionResourceCheck
                }
                directoryCollision = [ordered]@{
                    directCoverage = $true
                    suffixTwoUsed = $true
                    existingDirectoryContentPreserved = $true
                    check = $malodyFullPackageDirectoryCollisionCheck
                }
                commitBoundaryCancellation = [ordered]@{
                    directCoverage = $true
                    afterZipValidationBeforeCommit = $true
                    temporaryArchiveObservedBeforeCommit = $true
                    cancellationObserved = $true
                    oldDestinationPreserved = $true
                    temporaryArchivesAfter = 0
                    check = $malodyFullPackageCommitCancellationCheck
                }
                atomicDestinationReplacement = [ordered]@{
                    failedReplacementOldDestinationPreserved = $true
                    successfulReplacementProducedValidArchive = $true
                    temporaryArchivesAfterEachPath = 0
                    failedReplacementCheck = $malodyFullPackageFailedReplaceCheck
                    successfulReplacementCheck =
                        $malodyFullPackageSuccessfulReplaceCheck
                }
            }
            sourceRoot = $malodyFullPackageSourceRoot
            sourceTreeBefore = $malodyFullPackageSourceTreeBefore
            sourceTreeAfter = $malodyFullPackageSourceTreeAfter
            mainChartPath = $malodyFullPackageMainChartPath
            mainChartSourceSha256 = $malodyFullPackageMainSourceSha256
            destinationPath = $malodyFullPackageExportPath
            resourceHashPairs = $malodyFullPackageResourceHashPairs
            run = $malodyFullPackageCapture
            primaryRuntime = $malodyFullPackageGui
            dirtyExportRuntime = $malodyFullPackageInteractionGui
            fullPackage = $malodyFullPackageExportEvidence
            nativeControlIdentity = [ordered]@{
                requiredControlType = "ControlType.Pane"
                requiredState = "exact class/id + enabled + visible + nonzero native HWND + nonempty bounds"
                saveFilename = $malodyFullPackageExportEvidence.nativeSave.filenameControl
                saveSubmit = $malodyFullPackageExportEvidence.nativeSave.submitControl
                openFilename = $malodyFullPackageFreshEvidence.nativeOpen.filenameControl
                openSubmit = $malodyFullPackageFreshEvidence.nativeOpen.submitControl
                verified = $true
            }
            chartManifest = [ordered]@{
                validationLevel =
                    "Capture manifest exactly matched wrapper-independent source/post-exit-working/ZIP/fresh/tab recomputation"
                captured = $malodyFullPackageCapturedChartManifest
                independent = $malodyFullPackageIndependentChartManifestEvidence
                exactChartNameCount = 8
                siblingSourceSemanticExactCount =
                    $malodyFullPackageIndependentChartManifestEvidence.siblingSourceSemanticExactCount
                archiveFreshFileCount =
                    $malodyFullPackageIndependentChartManifestEvidence.archiveFreshTree.archive.fileCount
                importedTabPathCount =
                    $malodyFullPackageIndependentChartManifestEvidence.importedTabPaths.Count
                capturedEntryMismatches = @($malodyFullPackageCapturedChartEntryMismatches)
                verified = $true
            }
            screenshots = [ordered]@{
                exportFinal = $malodyFullPackageScreenshot
                options = $malodyFullPackageOptionsScreenshot
                result = $malodyFullPackageResultScreenshot
                freshImportPreview = $malodyFullPackageFreshDialogScreenshot
                freshMainChart = $malodyFullPackageFreshScreenshot
            }
            freshSecondProcess = [ordered]@{
                primaryRuntime = $malodyFullPackageFreshGui
                mainChartRuntime = $malodyFullPackageFreshInteractionGui
                evidence = $malodyFullPackageFreshEvidence
                importedMcCount = $malodyFullPackageFreshMcFiles.Count
                resourceHashPairs = $malodyFullPackageFreshResourceHashPairs
            }
            explorerRevealSuppressedOnlyForEvidence = $true
            normalProductBehaviorRevealsDestination = $true
        }
        authoritativeMalodyFullPackageR3 = [ordered]@{
            validationLevel =
                "referenced-immutable-formal-authority-and-complete-MCZ-GUI-regression-rerun"
            evidencePath = $formalMalodyFullPackageR3EvidencePath
            evidenceSha256 = $formalMalodyFullPackageR3EvidenceSha256
            specsPath = $formalMalodyFullPackageR3SpecsPath
            specsSha256 = $formalMalodyFullPackageR3SpecsSha256
            rerunByThisSlice = $true
        }
        osuFullPackage = [ordered]@{
            validationLevel =
                "real-five-file-source-dirty-main-native-save-flat-seven-file-osz-two-calibrated-fresh-tabs"
            sourceRoot = $osuFullPackageSourceRoot
            sourceTreeBefore = $osuFullPackageSourceTreeBefore
            sourceTreeAfter = $osuFullPackageSourceTreeAfter
            destinationPath = $osuFullPackageExportPath
            run = $osuFullPackageCapture
            primaryRuntime = $osuFullPackageGui
            dirtyExportRuntime = $osuFullPackageInteractionGui
            fullPackage = $osuFullPackageExportEvidence
            archiveManifest = $osuFullPackageArchiveManifest
            freshManifest = $osuFullPackageFreshManifest
            archiveFreshMismatches = @($osuFullPackageArchiveFreshMismatches)
            calibration = $osuFullPackageCalibration
            screenshots = [ordered]@{
                exportFinal = $osuFullPackageScreenshot
                options = $osuFullPackageOptionsScreenshot
                result = $osuFullPackageResultScreenshot
                freshImportPreview = $osuFullPackageFreshDialogScreenshot
                firstCalibration = $osuFullPackageFirstCalibrationScreenshot
                secondCalibration = $osuFullPackageSecondCalibrationScreenshot
                freshMainChart = $osuFullPackageFreshScreenshot
            }
            freshSecondProcess = [ordered]@{
                primaryRuntime = $osuFullPackageFreshGui
                mainChartRuntime = $osuFullPackageFreshInteractionGui
                evidence = $osuFullPackageFreshEvidence
            }
            explorerRevealSuppressedOnlyForEvidence = $true
            normalProductBehaviorRevealsDestination = $true
        }
        authoritativeOsuFullPackageR2 = [ordered]@{
            validationLevel =
                "referenced-immutable-formal-authority-and-complete-MCZ-and-OSZ-GUI-regression-rerun"
            evidencePath = $formalOsuFullPackageR2EvidencePath
            evidenceSha256 = $formalOsuFullPackageR2EvidenceSha256
            specsPath = $formalOsuFullPackageR2SpecsPath
            specsSha256 = $formalOsuFullPackageR2SpecsSha256
            rerunByThisSlice = $true
            rerunMeaning = "All prior MCZ and same-format OSZ GUI gates remain active while the 268/268 r2 predecessor authority is referenced as the first 268 checks of the v20 276-check predecessor within this slice's current 294/294 Specs, allowing only the recorded ordinal-79 picker-filename contract supersession."
        }
        malodyToOsuFullPackage = [ordered]@{
            validationLevel =
                "real-dirty-mc-cross-format-native-save-flat-five-entry-osz-one-calibrated-fresh-chart"
            sourceRoot = $malodyToOsuFullPackageSourceRoot
            sourceTreeBefore = $malodyToOsuFullPackageSourceTreeBefore
            sourceTreeAfter = $malodyToOsuFullPackageSourceTreeAfter
            mainChartPath = $malodyToOsuFullPackageMainChartPath
            mainChartSourceSha256 = $malodyToOsuFullPackageMainSourceSha256
            destinationPath = $malodyToOsuFullPackageExportPath
            run = $malodyToOsuFullPackageCapture
            primaryRuntime = $malodyToOsuFullPackageGui
            dirtyExportRuntime = $malodyToOsuFullPackageInteractionGui
            fullPackage = $malodyToOsuFullPackageExportEvidence
            archive = $malodyToOsuFullPackageArchiveEvidence
            archiveManifest = $malodyToOsuFullPackageArchiveManifest
            freshManifest = $malodyToOsuFullPackageFreshManifest
            archiveFreshMismatches = @($malodyToOsuFullPackageArchiveFreshMismatches)
            expectedResourceNames = @($malodyToOsuFullPackageExpectedResourceNames)
            missingResourceNames = @($malodyToOsuFullPackageMissingResourceNames)
            resourceHashMismatches = @($malodyToOsuFullPackageResourceMismatches)
            leakedChartArtifacts = @($malodyToOsuFullPackageLeakedChartArtifacts)
            movedHitObject = [ordered]@{
                expectedX = 320
                originalX = 192
                timeMilliseconds = 68066
                expectedCount = $malodyToOsuFullPackageExpectedHitCount
                originalCount = $malodyToOsuFullPackageOriginalHitCount
            }
            calibration = $malodyToOsuFullPackageCalibration
            screenshots = [ordered]@{
                exportFinal = $malodyToOsuFullPackageScreenshot
                options = $malodyToOsuFullPackageOptionsScreenshot
                result = $malodyToOsuFullPackageResultScreenshot
                freshImportPreview = $malodyToOsuFullPackageFreshDialogScreenshot
                calibration = $malodyToOsuFullPackageFirstCalibrationScreenshot
                freshMainChart = $malodyToOsuFullPackageFreshScreenshot
            }
            freshSecondProcess = [ordered]@{
                primaryRuntime = $malodyToOsuFullPackageFreshGui
                mainChartRuntime = $malodyToOsuFullPackageFreshInteractionGui
                evidence = $malodyToOsuFullPackageFreshEvidence
                importedChartCount = $malodyToOsuFullPackageFreshEvidence.importedTabCount
            }
            explorerRevealSuppressedOnlyForEvidence = $true
            normalProductBehaviorRevealsDestination = $true
        }
        authoritativeCrossFormatFullPackageR1 = [ordered]@{
            validationLevel =
                "referenced-immutable-formal-authority-and-complete-MCZ-same-OSZ-and-MC-to-OSZ-GUI-regression-rerun"
            evidencePath = $formalCrossFormatFullPackageR1EvidencePath
            evidenceSha256 = $formalCrossFormatFullPackageR1EvidenceSha256
            specsPath = $formalCrossFormatFullPackageR1SpecsPath
            specsSha256 = $formalCrossFormatFullPackageR1SpecsSha256
            exactOrderedCheckCount = $formalCrossFormatFullPackageR1Checks.Count
            exactOrderedCurrentCheckNamesWithOrdinal79Supersession =
                $formalCrossFormatFullPackageR1OrdinalMismatches.Count -eq 0
            rerunByThisSlice = $true
            completionRemainsFalse = $true
        }
        osuToMalodyFullPackage = [ordered]@{
            validationLevel =
                "real-dirty-osu-cross-format-native-save-dynamic-compact-six-entry-mcz-fresh-reopen-and-final-main-exit-dirty-cache-projection"
            sourceRoot = $osuToMalodyFullPackageSourceRoot
            sourceTreeBefore = $osuToMalodyFullPackageSourceTreeBefore
            sourceTreeAfter = $osuToMalodyFullPackageSourceTreeAfter
            exactStagedSourceFileCount = $osuToMalodyFullPackageSourceTreeBefore.fileCount
            sourceOsuChartCount = $osuToMalodyFullPackageSourceOsuFiles.Count
            sourceMcDecoyCount = $osuToMalodyFullPackageSourceMcFiles.Count
            sourceArchiveDecoyCount = $osuToMalodyFullPackageSourceArchiveDecoys.Count
            sourceNameToSha256 = $osuToMalodyFullPackageExpectedSourceHashes
            sourceHashMismatches = @($osuToMalodyFullPackageSourceHashMismatches)
            mainChartPath = $osuToMalodyFullPackageMainChartPath
            mainChartSourceSha256 =
                $osuToMalodyFullPackageExpectedSourceHashes[$osuToMalodyFullPackageMainFileName]
            destinationPath = $osuToMalodyFullPackageExportPath
            destinationSha256 = $osuToMalodyFullPackageIndependentArchive.sha256
            destinationLength = $osuToMalodyFullPackageIndependentArchive.length
            dynamicMainChartFileName = $osuToMalodyFullPackageMainTargetFileName
            run = $osuToMalodyFullPackageCapture
            primaryRuntime = $osuToMalodyFullPackageGui
            dirtyExportRuntime = $osuToMalodyFullPackageInteractionGui
            dirtyInjection = $osuToMalodyDirtyInjection
            fullPackage = $osuToMalodyFullPackageExportEvidence
            captureArchive = $osuToMalodyFullPackageArchiveEvidence
            independentArchive = $osuToMalodyFullPackageIndependentArchive
            archiveManifest = $osuToMalodyFullPackageArchiveManifest
            freshManifest = $osuToMalodyFullPackageFreshManifest
            archiveFreshMismatches = @($osuToMalodyFullPackageArchiveFreshMismatches)
            resourceNameToSha256 =
                $osuToMalodyFullPackageIndependentArchive.resourceNameToSha256
            keySound = [ordered]@{
                independentArchiveNode =
                    $osuToMalodyFullPackageIndependentArchive.keySoundNodes[0]
                independentArchiveNodeVerified =
                    $osuToMalodyFullPackageIndependentArchive.keySoundNodeVerified
                captureArchiveNode = $osuToMalodyFullPackageArchiveKeySoundNode
                captureArchiveNodeVerified =
                    $osuToMalodyFullPackageArchiveEvidence.keySoundNodeVerified
                freshResources = $osuToMalodyFullPackageFreshEvidence.resources
            }
            exactSixLeafProjection = [ordered]@{
                count =
                    $osuToMalodyFullPackageFreshEvidence.structuralEquivalence.projectionDifferenceCount
                orderedPaths = $osuToMalodyFullPackageProjectionPaths
                semanticDifferenceCount =
                    $osuToMalodyFullPackageFreshEvidence.structuralEquivalence.semanticDifferenceCount
                verified =
                    $osuToMalodyFullPackageFreshEvidence.structuralEquivalence.verified
            }
            freshProcessPreservation = [ordered]@{
                archiveFreshTree = $osuToMalodyFullPackageArchiveFreshTree
                preservation = $osuToMalodyFullPackagePreservation
                workspaceTreePreExit = $osuToMalodyFullPackageWorkspaceTreePreExit
                workspaceTreeAfterExit = $osuToMalodyFullPackageWorkspaceTreeAfterExit
                sampledAfterFreshProcessExit =
                    $osuToMalodyFullPackagePreservation.sampledAfterFreshProcessExit
            }
            finalStateAfterMainProcessExit = [ordered]@{
                capture = $osuToMalodyFullPackageFinalCaptureState
                wrapperIndependent = $osuToMalodyFullPackageIndependentFinalState
                artifactOutputCrossCheck =
                    $osuToMalodyFinalWorkingArtifactCrossCheck
                verified = $true
            }
            movedTap = [ordered]@{
                originalBeat = "15:5/6"
                originalLane = 2
                targetBeat = "15:10/12"
                targetLane = 3
                exactTargetCount =
                    $osuToMalodyFullPackageIndependentArchive.exactTargetTapCount
                originalCount =
                    $osuToMalodyFullPackageIndependentArchive.originalTargetTapCount
            }
            structure = $osuToMalodyFullPackageIndependentArchive.structure
            screenshots = [ordered]@{
                exportFinal = $osuToMalodyFullPackageScreenshot
                options = $osuToMalodyFullPackageOptionsScreenshot
                result = $osuToMalodyFullPackageResultScreenshot
                freshImportPreview = $osuToMalodyFullPackageFreshDialogScreenshot
                freshTargetNote = $osuToMalodyFullPackageFreshScreenshot
            }
            freshSecondProcess = [ordered]@{
                primaryRuntime = $osuToMalodyFullPackageFreshGui
                targetNoteRuntime = $osuToMalodyFullPackageFreshInteractionGui
                evidence = $osuToMalodyFullPackageFreshEvidence
                importedChartCount = $osuToMalodyFullPackageFreshEvidence.importedTabCount
                calibrationObservedCount =
                    $osuToMalodyFullPackageFreshEvidence.osuCalibration.observedCount
                targetNavigation = $osuToMalodyFullPackageFreshEvidence.targetNavigation
            }
            explorerRevealSuppressedOnlyForEvidence = $true
            normalProductBehaviorRevealsDestination = $true
        }
    }
    performance = [ordered]@{
        auxiliaryTimelineMetrics = [ordered]@{
            status = "captured-not-display-present"
            renderMilliseconds = "CPU elapsed inside TimelineSurface.Render"
            frameIntervalMilliseconds = "interval between render entries on the live UI thread"
            inputToRenderMilliseconds = "synthetic marker to next render entry"
        }
        auxiliaryAudioPanelMetrics = [ordered]@{
            status = "captured-not-display-present"
            semantics = "CPU elapsed inside each AudioVisualizationSideSurface.Render; interval between that surface's render entries; synthetic viewport marker to its next render"
            bitmapMaterialization = "UI-thread CPU WriteableBitmap materialization/Lock/Marshal.Copy; not a GPU upload or present metric"
            interactionWaveform = $audioPanelInteractionGui.audio.panels.waveform.diagnostics
            interactionSpectrogram = $audioPanelInteractionGui.audio.panels.spectrogram.diagnostics
            reopenedWaveform = $audioPanelReopenGui.audio.panels.waveform.diagnostics
            reopenedSpectrogram = $audioPanelReopenGui.audio.panels.spectrogram.diagnostics
        }
        displayPresentGate = [ordered]@{
            status = "pending"
            reason = "PresentMon needs elevation; same-machine WPF workload and true 120 Hz / 4K hardware acceptance remain outstanding"
        }
    }
    environment = [ordered]@{
        operatingSystem = [Runtime.InteropServices.RuntimeInformation]::OSDescription
        framework = [Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
        processArchitecture = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
        displayWidthPixels = $display.CurrentHorizontalResolution
        displayHeightPixels = $display.CurrentVerticalResolution
        displayRefreshHz = $display.CurrentRefreshRate
        avaloniaObservedScaling = $realGui.window.screenScaling
        presentMonPath = $presentMonPath
        presentMonAvailable = Test-Path -LiteralPath $presentMonPath
        elevatedForPresentMon = $isAdministrator
        processTempIsolation = $tempIsolationEvidence
    }
    sourceFiles = $sourceHashes
    artifactOutputsPolicy = [ordered]@{
        enumeration = "explicit formal gate outputs selected by the wrapper"
        exhaustiveArtifactRootInventory = $false
        exclusions = "fixture and session-cache copies may be represented by nested tree/manifest evidence instead of duplicate top-level artifactOutputs entries; TEMP is intentionally excluded"
        integrityMeaning = "every listed artifactOutputs path must exist and match its recorded length and SHA-256; the array must not be described as an exhaustive inventory of every non-TEMP file under ArtifactRoot"
    }
    artifactOutputs = $artifactOutputs
    remainingGates = @(
        "Full WPF feature matrix is not yet all pass; see AVALONIA-FUNCTION-MATRIX.md.",
        "WPF-versus-Avalonia display-present and end-to-end input comparison needs an elevated PresentMon run.",
        "This machine exposes 60/165 Hz and 2560x1600 only; true 120 Hz and true 4K remain hardware acceptance gates.",
        "Two-client Windows Avalonia online collaboration is not implemented or tested.",
        "MCZ, same-format OSZ, cross-format MC-to-OSZ and cross-format osu-to-MCZ FullPackage 1.0x export are covered by four separate actual native Save/Open GUI paths; the four-mode dialog and an actual Malody SingleRatePackage 1.25x PreservePitch-requested native Save/result plus independent MCZ/MC/Ogg decode are covered, without claiming audible pitch validation. Actual Save/Open closure for SingleChart, RatePack and osu rate-mode exports remains unfinished.",
        "Direct file-symlink resource materialization is not covered under the current Windows token (exact Win32 1314 / 0x80070522); capability failure and the shared staged-missing fallback are proven, while directCoverage remains false and completion remains blocked.",
        "Advanced ProEditor commands, full online/frozen-resource Note Sound assignment, audible audio/Key-sound device and loopback validation, audio-panel manual width-resize/overlap GUI plus WPF/display-present performance comparison, BPM/transcode, accounts/community/rooms, ClientSecurity, installer/update/uninstall are not complete.",
        "1080p/1440p/4K and multiple scaling acceptance has not completed as a matrix."
    )
    completion = [ordered]@{
        windowsAvaloniaCanReplaceWpf = $false
        userManualReplacementApprovalReceived = $false
        nextPlatformAuthorized = $false
    }
}
if (-not [bool]$evidence.scope.ollvmWaivedByUser -or
    [bool]$evidence.scope.ollvmMigratedBuiltOrExecuted -or
    [bool]$evidence.scope.ollvmCountsAsRemainingGate -or
    @($evidence.remainingGates | Where-Object {
            [string]$_ -match '(?i)OLLVM|SubObf|StrCry|compiler-VM'
        }).Count -ne 0) {
    throw "The user-waived OLLVM toolchain must remain unexecuted and absent from remaining gates."
}

$evidencePath = Join-Path $artifactFullPath "evidence.json"
$temporaryEvidencePath = "$evidencePath.tmp-$([Guid]::NewGuid().ToString('N'))"
try {
    $json = $evidence | ConvertTo-Json -Depth 30
    [IO.File]::WriteAllText($temporaryEvidencePath, $json, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryEvidencePath -Destination $evidencePath -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryEvidencePath) {
        Remove-Item -LiteralPath $temporaryEvidencePath -Force
    }
}

Write-Host "WINDOWS_AVALONIA_SLICE_OK"
Write-Host "Evidence: $evidencePath"
