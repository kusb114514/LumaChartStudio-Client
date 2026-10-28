param(
    [string]$SourceOsuPath =
        "D:\osu!\Songs\1005389 Minori Chihara - Michishirube\" +
        "Minori Chihara - Michishirube (eZmmR) [Dear You,  Gilbert Bougainvillea .].osu",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [Parameter(Mandatory = $true)][string]$TemporaryFixtureRoot,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 90,
    [switch]$AllowForegroundAutomation
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia osu in-place GUI capture requires PowerShell Core on Windows."
}
if (-not $AllowForegroundAutomation) {
    throw (
        "Foreground GUI automation is disabled. Pass " +
        "-AllowForegroundAutomation only after the user explicitly confirms " +
        "that the desktop is available.")
}

$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$artifactBoundary =
    [IO.Path]::GetFullPath((Join-Path $projectRoot "artifacts")).TrimEnd('\') + '\'
$temporaryBoundary =
    [IO.Path]::GetFullPath((Join-Path $projectRoot ".codex-temp")).TrimEnd('\') + '\'
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot).TrimEnd('\')
$temporaryFullPath = [IO.Path]::GetFullPath($TemporaryFixtureRoot).TrimEnd('\')
if (-not ($outputFullPath + '\').StartsWith(
        $artifactBoundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal GUI output must stay under $artifactBoundary"
}
if (-not ($temporaryFullPath + '\').StartsWith(
        $temporaryBoundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Isolated real-osu fixture must stay under $temporaryBoundary"
}
if (Test-Path -LiteralPath $outputFullPath) {
    throw "GUI output root must be new: $outputFullPath"
}
if (Test-Path -LiteralPath $temporaryFullPath) {
    throw "Temporary fixture root must be new: $temporaryFullPath"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Compute-Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "Missing file: $full"
    $item = Get-Item -LiteralPath $full
    [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $full)
        length = [long]$item.Length
        sha256 = Compute-Hash $full
    }
}

function Write-Json([string]$Path, [object]$Value) {
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 24),
        [Text.UTF8Encoding]::new($false))
}

function Read-Json([string]$Path) {
    Assert (Test-Path -LiteralPath $Path -PathType Leaf) "Missing JSON: $Path"
    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Capture-Tree([string]$Root) {
    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    @(
        Get-ChildItem -LiteralPath $fullRoot -Recurse -File |
            Sort-Object FullName |
            ForEach-Object {
                [ordered]@{
                    relativePath = [IO.Path]::GetRelativePath(
                        $fullRoot,
                        $_.FullName)
                    length = [long]$_.Length
                    sha256 = Compute-Hash $_.FullName
                }
            }
    )
}

function Copy-Directory([string]$Source, [string]$Destination) {
    $sourceFullPath = [IO.Path]::GetFullPath($Source).TrimEnd('\')
    New-Item -ItemType Directory -Path $Destination | Out-Null
    foreach ($directory in Get-ChildItem -LiteralPath $sourceFullPath -Recurse -Directory) {
        $relative = [IO.Path]::GetRelativePath($sourceFullPath, $directory.FullName)
        New-Item -ItemType Directory -Force -Path (
            Join-Path $Destination $relative) | Out-Null
    }
    foreach ($file in Get-ChildItem -LiteralPath $sourceFullPath -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($sourceFullPath, $file.FullName)
        $destinationPath = Join-Path $Destination $relative
        $destinationDirectory = Split-Path -Parent $destinationPath
        New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destinationPath
    }
}

function Assert-TreesEqual(
    [object[]]$Expected,
    [object[]]$Actual,
    [string]$Description) {
    $expectedJson = $Expected | ConvertTo-Json -Depth 5 -Compress
    $actualJson = $Actual | ConvertTo-Json -Depth 5 -Compress
    Assert ($expectedJson -ceq $actualJson) "$Description changed."
}

function Assert-SiblingTreeUnchanged(
    [object[]]$Before,
    [object[]]$After,
    [string]$EditedRelativePath) {
    $beforeSiblings = @(
        $Before | Where-Object {
            -not $_.relativePath.Equals(
                $EditedRelativePath,
                [StringComparison]::OrdinalIgnoreCase)
        })
    $afterSiblings = @(
        $After | Where-Object {
            -not $_.relativePath.Equals(
                $EditedRelativePath,
                [StringComparison]::OrdinalIgnoreCase)
        })
    Assert-TreesEqual $beforeSiblings $afterSiblings "Isolated osu sibling tree"
}

function Get-SectionLines([string[]]$Lines, [string]$Section) {
    $header = "[$Section]"
    $inside = $false
    $result = [Collections.Generic.List[string]]::new()
    foreach ($line in $Lines) {
        if ($line -match '^\[[^\]]+\]$') {
            if ($inside) { break }
            $inside = $line -ceq $header
            continue
        }
        if ($inside -and -not [string]::IsNullOrWhiteSpace($line) -and
            -not $line.StartsWith("//", [StringComparison]::Ordinal)) {
            $result.Add($line)
        }
    }
    @($result)
}

function Parse-IndependentOsuEvidence([string]$Path) {
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $lines = [IO.File]::ReadAllLines($Path)
    Assert ($lines.Count -gt 0 -and
        $lines[0].StartsWith(
            "osu file format v14",
            [StringComparison]::Ordinal)) (
        "Saved chart is not osu file format v14.")

    $difficulty = Get-SectionLines $lines "Difficulty"
    $circleSizeLine = @($difficulty | Where-Object {
        $_.StartsWith("CircleSize:", [StringComparison]::Ordinal)
    })
    Assert ($circleSizeLine.Count -eq 1) "Saved osu lacks one CircleSize."
    $keyCount = [int]::Parse(
        $circleSizeLine[0].Substring("CircleSize:".Length),
        $culture)

    $timingLines = Get-SectionLines $lines "TimingPoints"
    $bpmPoints = [Collections.Generic.List[object]]::new()
    $scrollPoints = [Collections.Generic.List[object]]::new()
    foreach ($line in $timingLines) {
        $parts = $line.Split(',')
        Assert ($parts.Count -ge 8) "Malformed TimingPoint: $line"
        $point = [ordered]@{
            time = [double]::Parse($parts[0], $culture)
            beatLength = [double]::Parse($parts[1], $culture)
            uninherited = [int]::Parse($parts[6], $culture)
            raw = $line
        }
        if ($point.uninherited -eq 1 -and $point.beatLength -gt 0) {
            $bpmPoints.Add($point)
        }
        elseif ($point.uninherited -eq 0 -and $point.beatLength -lt 0) {
            $scrollPoints.Add($point)
        }
    }

    $hitObjectLines = Get-SectionLines $lines "HitObjects"
    $objects = [Collections.Generic.List[object]]::new()
    foreach ($line in $hitObjectLines) {
        $parts = $line.Split(',')
        Assert ($parts.Count -ge 6) "Malformed HitObject: $line"
        $type = [int]::Parse($parts[3], $culture)
        $x = [int]::Parse($parts[0], $culture)
        $objects.Add([ordered]@{
            x = $x
            lane = [Math]::Min(
                $keyCount - 1,
                [Math]::Floor($x * $keyCount / 512.0))
            time = [int]::Parse($parts[2], $culture)
            type = $type
            isLongNote = ($type -band 128) -ne 0
            sample = $parts[5]
            raw = $line
        })
    }

    Assert ($bpmPoints.Count -gt 0) "Saved osu lacks a BPM point."
    $targetBeat = 15.0 + 5.0 / 6.0
    $firstBpm = $bpmPoints[0]
    $targetTime = [int][Math]::Round(
        [double]$firstBpm.time + $targetBeat * [double]$firstBpm.beatLength,
        [MidpointRounding]::AwayFromZero)
    $targets = @($objects | Where-Object {
        [int]$_.lane -eq 2 -and
        [int]$_.time -eq $targetTime -and
        -not [bool]$_.isLongNote
    })
    Assert ($targets.Count -eq 1) (
        "Independent parser found $($targets.Count) target Tap objects.")
    $sampleParts = ([string]$targets[0].sample).Split(':')
    Assert ($sampleParts.Count -ge 4) "Target Tap sample set is malformed."
    $targetVolume = [int]::Parse($sampleParts[3], $culture)

    [ordered]@{
        parser = "independent PowerShell osu text parser"
        fileHeader = $lines[0]
        keyCount = $keyCount
        timingPointCount = $timingLines.Count
        bpmCount = $bpmPoints.Count
        inheritedScrollCount = $scrollPoints.Count
        hitObjectCount = $objects.Count
        longNoteCount = @($objects | Where-Object isLongNote).Count
        target = [ordered]@{
            authoredBeat = "15:5/6"
            expectedLane = 2
            expectedUiLane = 3
            calculatedTimeMilliseconds = $targetTime
            volume = $targetVolume
            raw = $targets[0].raw
        }
    }
}

function Invoke-GenericCapture([string[]]$Arguments, [string]$ResultPath) {
    $output = & pwsh -NoProfile -File (
        Join-Path $PSScriptRoot "Capture-WindowsAvaloniaGui.ps1") @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Generic Windows Avalonia GUI capture failed with exit code $LASTEXITCODE."
    }
    $text = $output -join [Environment]::NewLine
    $result = $text | ConvertFrom-Json
    Write-Json $ResultPath $result
    $result
}

$sourceFullPath = [IO.Path]::GetFullPath($SourceOsuPath)
Assert (Test-Path -LiteralPath $sourceFullPath -PathType Leaf) (
    "Real osu source fixture not found: $sourceFullPath")
Assert ([IO.Path]::GetExtension($sourceFullPath).Equals(
        ".osu",
        [StringComparison]::OrdinalIgnoreCase)) (
    "Source fixture must be an osu chart.")
$expectedSourceSha256 =
    "511866870F99BDC7443006FA7420C7A9D21198F49B9EC13B50A32293E7F58E57"
$expectedInstallerSha256 =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
$sourceDirectory = Split-Path -Parent $sourceFullPath
$sourceRelativePath = [IO.Path]::GetRelativePath($sourceDirectory, $sourceFullPath)
$sourceTreeBefore = Capture-Tree $sourceDirectory
Assert ((Compute-Hash $sourceFullPath) -ceq $expectedSourceSha256) (
    "Real osu source fixture hash differs from the frozen fixture.")

New-Item -ItemType Directory -Path $outputFullPath | Out-Null
Copy-Directory $sourceDirectory $temporaryFullPath
$isolatedPath = Join-Path $temporaryFullPath $sourceRelativePath
$isolatedTreeBefore = Capture-Tree $temporaryFullPath
Assert ((Compute-Hash $isolatedPath) -ceq $expectedSourceSha256) (
    "Isolated osu copy hash differs from the source fixture.")

$initialRuntimePath = Join-Path $outputFullPath "initial-runtime.json"
$savedRuntimePath = Join-Path $outputFullPath "saved-runtime.json"
$savedScreenshotPath = Join-Path $outputFullPath "saved-editor.png"
$firstCaptureResultPath = Join-Path $outputFullPath "save-capture-result.json"
$firstCapture = Invoke-GenericCapture @(
    "-ChartPath", $isolatedPath,
    "-EvidencePath", $initialRuntimePath,
    "-InteractionEvidencePath", $savedRuntimePath,
    "-ScreenshotPath", $savedScreenshotPath,
    "-WorkspaceRoot", (Join-Path $outputFullPath "save-workspace"),
    "-LocalDataRoot", (Join-Path $outputFullPath "save-local"),
    "-EditingRoot", (Join-Path $outputFullPath "save-editing"),
    "-FocusNoteProperty",
    "-FocusNotePropertyBeat", "15:5/6",
    "-ExerciseNoteProperty",
    "-SaveAfterNoteProperty",
    "-NotePropertyBeat", "15:5/6",
    "-NotePropertyEndBeat", "",
    "-NotePropertyLane", "3",
    "-NotePropertyVolume", "73",
    "-NotePropertySound", "",
    "-NotePropertyGroup", "0",
    "-InteractionDelayMilliseconds", "6500",
    "-TimeoutSeconds", $TimeoutSeconds.ToString(
        [Globalization.CultureInfo]::InvariantCulture)
) $firstCaptureResultPath

# The second foreground script has its own 3-second idle safety gate. Leave
# a quiet interval after the preceding physical clicks before it begins.
Start-Sleep -Seconds 4

$reopenedRuntimePath = Join-Path $outputFullPath "reopened-runtime.json"
$reopenedScreenshotPath = Join-Path $outputFullPath "reopened-editor.png"
$reopenCaptureResultPath = Join-Path $outputFullPath "reopen-capture-result.json"
$reopenCapture = Invoke-GenericCapture @(
    "-ChartPath", $isolatedPath,
    "-EvidencePath", $reopenedRuntimePath,
    "-ScreenshotPath", $reopenedScreenshotPath,
    "-WorkspaceRoot", (Join-Path $outputFullPath "reopen-workspace"),
    "-LocalDataRoot", (Join-Path $outputFullPath "reopen-local"),
    "-EditingRoot", (Join-Path $outputFullPath "reopen-editing"),
    "-FocusNoteProperty",
    "-FocusNotePropertyBeat", "15:5/6",
    "-TimeoutSeconds", $TimeoutSeconds.ToString(
        [Globalization.CultureInfo]::InvariantCulture)
) $reopenCaptureResultPath

$initialRuntime = Read-Json $initialRuntimePath
$savedRuntime = Read-Json $savedRuntimePath
$reopenedRuntime = Read-Json $reopenedRuntimePath
$initialNote = @($initialRuntime.timeline.selectedNotes)
$savedNote = @($savedRuntime.timeline.selectedNotes)
$reopenedNote = @($reopenedRuntime.timeline.selectedNotes)
Assert ($initialNote.Count -eq 1 -and $savedNote.Count -eq 1 -and
        $reopenedNote.Count -eq 1) (
    "The save/reopen GUI runs did not select exactly one target Note.")
Assert ($initialNote[0].beat.bar -eq 15 -and
        $initialNote[0].beat.numerator -eq 5 -and
        $initialNote[0].beat.denominator -eq 6 -and
        [int]$initialNote[0].lane -eq 2 -and
        [int]$initialNote[0].volume -eq 100) (
    "Initial GUI target differs from Beat 15:5/6, UI lane 3, volume 100.")
Assert ([long]$savedRuntime.timeline.sessionChangeSerial -eq
        ([long]$initialRuntime.timeline.sessionChangeSerial + 1) -and
        -not [bool]$savedRuntime.timeline.sessionIsDirty -and
        [int]$savedNote[0].volume -eq 73) (
    "The physical Apply/Save path did not leave exactly one clean volume edit.")
Assert (-not [bool]$reopenedRuntime.timeline.sessionIsDirty -and
        [int]$reopenedNote[0].volume -eq 73 -and
        [int]$reopenedNote[0].lane -eq 2 -and
        $reopenedNote[0].beat.bar -eq 15 -and
        $reopenedNote[0].beat.numerator -eq 5 -and
        $reopenedNote[0].beat.denominator -eq 6) (
    "Fresh-process reopen did not restore the exact saved Note.")
Assert ([bool]$firstCapture.notePropertyExercised -and
        [bool]$firstCapture.notePropertySaved -and
        @($firstCapture.notePropertyPhysicalActions).Count -eq 3) (
    "The first capture lacks three physical Apply/menu/Save actions.")
Assert (@($firstCapture.notePropertyPhysicalActions | Where-Object {
            $_.input -ceq
                "physical Win32 mouse click at UI Automation bounds"
        }).Count -eq 3) (
    "A Note-property save action was not a physical Win32 mouse click.")

$independentParser = Parse-IndependentOsuEvidence $isolatedPath
Assert ([int]$independentParser.keyCount -eq 4) "Saved osu key count is not 4."
Assert ([int]$independentParser.hitObjectCount -eq 2468) (
    "Saved osu HitObject count is not 2,468.")
Assert ([int]$independentParser.longNoteCount -eq 303) (
    "Saved osu LN count is not 303.")
Assert ([int]$independentParser.bpmCount -eq 2) (
    "Saved osu BPM point count is not 2.")
Assert ([int]$independentParser.inheritedScrollCount -eq 11) (
    "Saved osu inherited Scroll count is not 11.")
Assert ([int]$independentParser.target.volume -eq 73) (
    "Saved osu target volume is not 73.")

$isolatedTreeAfter = Capture-Tree $temporaryFullPath
Assert-SiblingTreeUnchanged `
    $isolatedTreeBefore `
    $isolatedTreeAfter `
    $sourceRelativePath
$savedHash = Compute-Hash $isolatedPath
Assert ($savedHash -ne $expectedSourceSha256) (
    "The discriminating GUI edit did not change the isolated osu bytes.")
Assert ($savedRuntime.chart.sourceSha256 -ceq $savedHash -and
        $reopenedRuntime.chart.sourceSha256 -ceq $savedHash) (
    "Runtime evidence source hashes differ from the saved osu bytes.")
Assert ([int]$savedRuntime.chart.structure.keyCount -eq 4 -and
        [int]$savedRuntime.chart.structure.noteCount -eq 2468 -and
        [int]$savedRuntime.chart.structure.longNoteCount -eq 303 -and
        $savedRuntime.chart.structure.sha256 -ceq
            $reopenedRuntime.chart.structure.sha256) (
    "Saved/reopened runtime structures differ.")

$scratchFiles = @(
    Get-ChildItem -LiteralPath $temporaryFullPath -Recurse -File |
        Where-Object {
            $_.Name.EndsWith(".tmp", [StringComparison]::OrdinalIgnoreCase) -or
            $_.Name.EndsWith(
                ".luma-part",
                [StringComparison]::OrdinalIgnoreCase)
        })
Assert ($scratchFiles.Count -eq 0) (
    "Atomic-save scratch files remain in the isolated osu project.")

$sourceTreeAfter = Capture-Tree $sourceDirectory
Assert-TreesEqual $sourceTreeBefore $sourceTreeAfter "Frozen real osu source tree"
Assert ((Compute-Hash $sourceFullPath) -ceq $expectedSourceSha256) (
    "Frozen real osu source fixture changed.")
$installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
Assert ((Compute-Hash $installerPath) -ceq $expectedInstallerSha256) (
    "Frozen WPF installer changed.")

$savedSnapshotPath = Join-Path $outputFullPath "saved-osu-snapshot.osu"
Copy-Item -LiteralPath $isolatedPath -Destination $savedSnapshotPath
Assert ((Compute-Hash $savedSnapshotPath) -ceq $savedHash) (
    "Saved osu evidence snapshot differs from the GUI-edited file.")

$guiEvidence = [ordered]@{
    schema = "lumachart.windows.avalonia.osu-in-place-save-gui-evidence.v1"
    status = "passed-migration-incomplete"
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    platform = "Windows Avalonia only"
    windowsAvaloniaOnly = $true
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    productionServerMutationPerformed = $false
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    migrationComplete = $false
    chart = [ordered]@{
        originalSource = [ordered]@{
            path = $sourceFullPath
            sha256Before = $expectedSourceSha256
            sha256After = Compute-Hash $sourceFullPath
            treeBefore = $sourceTreeBefore
            treeAfter = $sourceTreeAfter
        }
        isolatedSource = [ordered]@{
            path = $isolatedPath
            sha256Before = $expectedSourceSha256
            sha256After = $savedHash
            siblingTreeUnchanged = $true
            scratchFileCount = $scratchFiles.Count
        }
        savedSnapshot = File-Evidence $savedSnapshotPath
        independentParser = $independentParser
    }
    gui = [ordered]@{
        initialRuntime = File-Evidence $initialRuntimePath
        savedRuntime = File-Evidence $savedRuntimePath
        reopenedRuntime = File-Evidence $reopenedRuntimePath
        initialTarget = $initialNote[0]
        savedTarget = $savedNote[0]
        reopenedTarget = $reopenedNote[0]
        physicalActions = @($firstCapture.notePropertyPhysicalActions)
        saveCaptureResult = File-Evidence $firstCaptureResultPath
        reopenCaptureResult = File-Evidence $reopenCaptureResultPath
        savedScreenshot = File-Evidence $savedScreenshotPath
        reopenedScreenshot = File-Evidence $reopenedScreenshotPath
        freshProcessReopen = $true
        savedSessionClean = -not [bool]$savedRuntime.timeline.sessionIsDirty
        reopenedSessionClean =
            -not [bool]$reopenedRuntime.timeline.sessionIsDirty
        exactRationalBeatPreserved = $true
        structureSha256EqualAfterReopen =
            $savedRuntime.chart.structure.sha256 -ceq
                $reopenedRuntime.chart.structure.sha256
    }
    installer = [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $installerPath)
        sha256Before = $expectedInstallerSha256
        sha256After = Compute-Hash $installerPath
    }
}
$guiEvidencePath = Join-Path $outputFullPath (
    "osu-in-place-save-gui-evidence.json")
Write-Json $guiEvidencePath $guiEvidence

[pscustomobject]@{
    status = $guiEvidence.status
    evidencePath = $guiEvidencePath
    evidenceSha256 = Compute-Hash $guiEvidencePath
    savedOsuSha256 = $savedHash
    initialVolume = [int]$initialNote[0].volume
    savedVolume = [int]$savedNote[0].volume
    reopenedVolume = [int]$reopenedNote[0].volume
    physicalActionCount = @($firstCapture.notePropertyPhysicalActions).Count
    keyCount = [int]$independentParser.keyCount
    hitObjectCount = [int]$independentParser.hitObjectCount
    longNoteCount = [int]$independentParser.longNoteCount
    bpmCount = [int]$independentParser.bpmCount
    inheritedScrollCount = [int]$independentParser.inheritedScrollCount
}
