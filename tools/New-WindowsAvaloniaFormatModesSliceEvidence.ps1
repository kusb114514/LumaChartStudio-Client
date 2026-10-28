param(
    [string]$Root =
        "artifacts\windows-avalonia-format-modes-slice-20260729-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedCaptureEvidenceSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedVisualReviewSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia format-mode verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-format-modes-slice-20260729-r1"))).TrimEnd('\')
$formalRoot = if ([IO.Path]::IsPathRooted($Root)) {
    [IO.Path]::GetFullPath($Root).TrimEnd('\')
}
else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
}
if (-not $formalRoot.Equals(
        $expectedRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal format-mode root must be exactly $expectedRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Write-Utf8([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "Missing file: $full"
    $item = Get-Item -LiteralPath $full
    [ordered]@{
        path = if ($full.StartsWith(
                $projectRoot + '\',
                [StringComparison]::OrdinalIgnoreCase)) {
            [IO.Path]::GetRelativePath($projectRoot, $full)
        }
        else {
            $full
        }
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Resolve-FormalPath([string]$Path, [string]$Label) {
    $full = if ([IO.Path]::IsPathRooted($Path)) {
        [IO.Path]::GetFullPath($Path)
    }
    else {
        [IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
    }
    Assert ($full.StartsWith(
            $formalRoot + '\',
            [StringComparison]::OrdinalIgnoreCase)) (
        "$Label escaped the formal root: $full")
    $full
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -Raw -LiteralPath $Path
    Assert ($text -match "0 个警告|0 Warning") (
        "Strict build log lacks a zero-warning result: $Path")
    Assert ($text -match "0 个错误|0 Error") (
        "Strict build log lacks a zero-error result: $Path")
    Assert ($text -notmatch (
            "(?i)(PublishAot|NativeAOT|ReadyToRun|OLLVM|obfuscat|code virtualization)" +
            "\s*[:=]\s*(true|1)")) (
        "Strict build log enabled forbidden protection or AOT: $Path")
    File-Evidence $Path
}

function Assert-ExpectedHash([string]$Hash, [string]$Label) {
    Assert ($Hash -match '^[0-9A-Fa-f]{64}$') "$Label is not a SHA-256."
}

function Test-CompactMcText([string]$Text, [string]$Label) {
    Assert (-not [string]::IsNullOrWhiteSpace($Text)) "$Label is empty."
    $nonEmptyLines = @(
        $Text -split '\r?\n' | Where-Object { $_.Length -gt 0 })
    Assert ($nonEmptyLines.Count -eq 1) (
        "$Label is not the compact one-line game-compatible format.")
    $document = $Text | ConvertFrom-Json -Depth 100
    foreach ($property in @("meta", "time", "note", "extra")) {
        Assert ($null -ne $document.PSObject.Properties[$property]) (
            "$Label lacks root property '$property'.")
    }
    $playable = @($document.note | Where-Object { $null -ne $_.column })
    Assert ($playable.Count -eq 2753) (
        "$Label has $($playable.Count) playable Notes, expected 2753.")
    Assert (@($document.time).Count -ge 1) "$Label has no timing points."
    [ordered]@{
        compactOneLine = $true
        playableNoteCount = $playable.Count
        timingCount = @($document.time).Count
        rootProperties = @("meta", "time", "note", "extra")
    }
}

function Test-OsuText([string]$Text, [string]$Label) {
    Assert ($Text -match '(?m)^osu file format v14\s*$') (
        "$Label is not osu! file format v14.")
    Assert ($Text -match '(?m)^Mode\s*:\s*3\s*$') "$Label is not mania Mode 3."
    Assert ($Text -match '(?m)^CircleSize\s*:\s*4(?:\.0+)?\s*$') (
        "$Label is not 4K.")
    Assert ($Text -match '(?m)^OverallDifficulty\s*:\s*8(?:\.0+)?\s*$') (
        "$Label did not retain OD 8.")
    Assert ($Text -match '(?m)^HPDrainRate\s*:\s*8(?:\.0+)?\s*$') (
        "$Label did not retain HP 8.")
    $hitSection = [regex]::Match($Text, '(?m)^\[HitObjects\]\s*$')
    Assert $hitSection.Success "$Label lacks [HitObjects]."
    $hitLines = @(
        $Text.Substring($hitSection.Index + $hitSection.Length) -split '\r?\n' |
            ForEach-Object { $_.Trim() } |
            Where-Object {
                $_.Length -gt 0 -and
                -not $_.StartsWith("//", [StringComparison]::Ordinal)
            })
    Assert ($hitLines.Count -eq 2753) (
        "$Label has $($hitLines.Count) HitObjects, expected 2753.")
    [ordered]@{
        version = 14
        mode = 3
        keyCount = 4
        overallDifficulty = 8
        hpDrainRate = 8
        hitObjectCount = $hitLines.Count
    }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Read-ZipEntryText([IO.Compression.ZipArchiveEntry]$Entry) {
    $stream = $Entry.Open()
    $reader = [IO.StreamReader]::new($stream)
    try {
        $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }
}

function Zip-EntryEvidence([IO.Compression.ZipArchiveEntry]$Entry) {
    $stream = $Entry.Open()
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = [Convert]::ToHexString($sha.ComputeHash($stream))
    }
    finally {
        $sha.Dispose()
        $stream.Dispose()
    }
    [ordered]@{
        name = $Entry.FullName
        length = [long]$Entry.Length
        compressedLength = [long]$Entry.CompressedLength
        sha256 = $hash
    }
}

function Inspect-Archive(
    [string]$Path,
    [int]$ExpectedMcCount,
    [int]$ExpectedOsuCount,
    [int]$ExpectedOggCount,
    [int]$ExpectedImageCount,
    [string[]]$RequiredNameFragments,
    [string]$Label) {
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entries = @($archive.Entries | Where-Object {
            -not [string]::IsNullOrEmpty($_.Name)
        })
        $duplicates = @(
            $entries |
                Group-Object { $_.FullName.ToUpperInvariant() } |
                Where-Object Count -gt 1)
        Assert ($duplicates.Count -eq 0) "$Label contains duplicate entry names."
        foreach ($entry in $entries) {
            $normalized = $entry.FullName.Replace('\', '/')
            Assert (-not $normalized.StartsWith("/", [StringComparison]::Ordinal)) (
                "$Label contains an absolute entry: $normalized")
            Assert (-not (@($normalized.Split('/')) -contains "..")) (
                "$Label contains a traversal entry: $normalized")
        }
        foreach ($fragment in $RequiredNameFragments) {
            Assert (@($entries | Where-Object {
                        $_.FullName.Contains(
                            $fragment,
                            [StringComparison]::OrdinalIgnoreCase)
                    }).Count -ge 1) (
                "$Label lacks required entry fragment '$fragment'.")
        }
        $mcEntries = @($entries | Where-Object {
            $_.Name.EndsWith(".mc", [StringComparison]::OrdinalIgnoreCase)
        })
        $osuEntries = @($entries | Where-Object {
            $_.Name.EndsWith(".osu", [StringComparison]::OrdinalIgnoreCase)
        })
        $oggEntries = @($entries | Where-Object {
            $_.Name.EndsWith(".ogg", [StringComparison]::OrdinalIgnoreCase)
        })
        $imageEntries = @($entries | Where-Object {
            $_.Name.EndsWith(".jpg", [StringComparison]::OrdinalIgnoreCase) -or
            $_.Name.EndsWith(".jpeg", [StringComparison]::OrdinalIgnoreCase) -or
            $_.Name.EndsWith(".png", [StringComparison]::OrdinalIgnoreCase)
        })
        Assert ($mcEntries.Count -eq $ExpectedMcCount) (
            "$Label MC count is $($mcEntries.Count), expected $ExpectedMcCount.")
        Assert ($osuEntries.Count -eq $ExpectedOsuCount) (
            "$Label osu count is $($osuEntries.Count), expected $ExpectedOsuCount.")
        Assert ($oggEntries.Count -eq $ExpectedOggCount) (
            "$Label OGG count is $($oggEntries.Count), expected $ExpectedOggCount.")
        Assert ($imageEntries.Count -eq $ExpectedImageCount) (
            "$Label image count is $($imageEntries.Count), expected $ExpectedImageCount.")
        $mcChecks = @(
            foreach ($entry in $mcEntries) {
                [ordered]@{
                    name = $entry.FullName
                    structure =
                        Test-CompactMcText (Read-ZipEntryText $entry) (
                            "$Label/$($entry.FullName)")
                }
            })
        $osuChecks = @(
            foreach ($entry in $osuEntries) {
                [ordered]@{
                    name = $entry.FullName
                    structure =
                        Test-OsuText (Read-ZipEntryText $entry) (
                            "$Label/$($entry.FullName)")
                }
            })
        [ordered]@{
            file = File-Evidence $Path
            entryCount = $entries.Count
            mcCount = $mcEntries.Count
            osuCount = $osuEntries.Count
            oggCount = $oggEntries.Count
            imageCount = $imageEntries.Count
            duplicateEntryCount = $duplicates.Count
            traversalEntryCount = 0
            entries = @($entries | ForEach-Object { Zip-EntryEvidence $_ })
            mcChecks = $mcChecks
            osuChecks = $osuChecks
        }
    }
    finally {
        $archive.Dispose()
    }
}

Assert-ExpectedHash $ExpectedCaptureEvidenceSha256 "Expected capture evidence hash"
Assert-ExpectedHash $ExpectedVisualReviewSha256 "Expected visual-review hash"
$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$capturePath = Join-Path $formalRoot "capture-evidence.json"
$captureFile = File-Evidence $capturePath
Assert ($captureFile.sha256 -ceq $ExpectedCaptureEvidenceSha256.ToUpperInvariant()) (
    "Capture evidence hash differs from the reviewed authority.")
$capture = Get-Content -Raw -LiteralPath $capturePath | ConvertFrom-Json -Depth 100
Assert ($capture.schema -ceq (
    "lumachart.windows.avalonia.format-modes-slice-capture.v1")) (
    "Unexpected capture schema: $($capture.schema)")
Assert ($capture.status -ceq "passed-migration-incomplete") (
    "Capture status is not passed-migration-incomplete.")
Assert ($capture.windowsAvaloniaOnly -eq $true -and
    $capture.mobileProjectsBuiltModifiedInstalledOrTested -eq $false -and
    $capture.productionServerMutationPerformed -eq $false) (
    "Capture crossed the Windows-only or production-Server boundary.")
Assert ($capture.pureDotnetRelease -eq $true -and
    $capture.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "Capture did not use ordinary unprotected .NET Release.")
Assert (@($capture.exports).Count -eq 5 -and
    @($capture.imports).Count -eq 6) (
    "Capture does not contain five exports and six fresh imports.")

$builds = [ordered]@{
    avalonia =
        Assert-StrictBuild (Join-Path $formalRoot "build\avalonia-build.log")
    avaloniaSpecs =
        Assert-StrictBuild (Join-Path $formalRoot "build\avalonia-specs-build.log")
    mainSpecs =
        Assert-StrictBuild (Join-Path $formalRoot "build\main-specs-build.log")
}

$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs = Get-Content -Raw -LiteralPath $specsPath | ConvertFrom-Json -Depth 100
$checks = @($specs.Checks)
$passedChecks = @($checks | Where-Object Passed)
Assert ($specs.Status -ceq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 520 -and $passedChecks.Count -eq 520) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
$focusedSpecNames = @(
    "format-gui-direct-osu-evidence-exercises-real-import-choice",
    "format-gui-all-export-modes-have-physical-and-bounded-completion-paths")
foreach ($name in $focusedSpecNames) {
    $match = @($checks | Where-Object Name -ceq $name)
    Assert ($match.Count -eq 1 -and $match[0].Passed -eq $true) (
        "Focused format harness Spec did not pass: $name")
}
$mainSpecsPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainSpecsText = Get-Content -Raw -LiteralPath $mainSpecsPath
Assert ($mainSpecsText -match "79/79 specs passed") (
    "Main Specs did not pass 79/79.")

$expectedExports = @(
    [ordered]@{
        name = "malody-single-chart-export"
        format = "Malody"
        mode = "SingleChart"
        preservePitch = $false
        extension = ".mc"
    }
    [ordered]@{
        name = "malody-rate-pack-export"
        format = "Malody"
        mode = "RatePack"
        preservePitch = $false
        extension = ".mcz"
    }
    [ordered]@{
        name = "osu-single-chart-export"
        format = "OsuMania"
        mode = "SingleChart"
        preservePitch = $false
        extension = ".osu"
    }
    [ordered]@{
        name = "osu-single-rate-export"
        format = "OsuMania"
        mode = "SingleRatePackage"
        preservePitch = $true
        extension = ".osz"
    }
    [ordered]@{
        name = "osu-rate-pack-export"
        format = "OsuMania"
        mode = "RatePack"
        preservePitch = $true
        extension = ".osz"
    })

$exportChecks = [Collections.Generic.List[object]]::new()
foreach ($expected in $expectedExports) {
    $matches = @($capture.exports | Where-Object name -ceq $expected.name)
    Assert ($matches.Count -eq 1) "Missing unique export '$($expected.name)'."
    $entry = $matches[0]
    Assert ([string]$entry.format -ceq $expected.format -and
        [string]$entry.mode -ceq $expected.mode) (
        "Capture export mode mismatch for $($expected.name).")
    $destination = Resolve-FormalPath $entry.destination.path (
        "$($expected.name) destination")
    $destinationFile = File-Evidence $destination
    Assert ($destinationFile.sha256 -ceq [string]$entry.destination.sha256 -and
        $destinationFile.length -eq [long]$entry.destination.length) (
        "Export file changed after capture: $($expected.name)")
    Assert ([IO.Path]::GetExtension($destination) -ceq $expected.extension) (
        "Export extension mismatch for $($expected.name).")

    $captureResultPath = Resolve-FormalPath $entry.captureResult.path (
        "$($expected.name) capture result")
    $gui = Get-Content -Raw -LiteralPath $captureResultPath |
        ConvertFrom-Json -Depth 100
    $actual = $gui.chartExportModes.actualExport
    Assert ($gui.chartExportModesExercised -eq $true -and
        $gui.chartExportModes.verified -eq $true -and
        $actual.verified -eq $true) (
        "GUI export mode evidence did not verify $($expected.name).")
    Assert ([string]$actual.requested.format -ceq $expected.format -and
        [string]$actual.requested.mode -ceq $expected.mode -and
        [bool]$actual.requested.preservePitch -eq $expected.preservePitch) (
        "Actual GUI request differs for $($expected.name).")
    Assert ([string]$actual.file.sha256 -ceq $destinationFile.sha256 -and
        [string]$actual.file.extension -ceq $expected.extension) (
        "GUI result file differs from the independently hashed export.")
    Assert ($actual.modeSelection.physicalSelectionRetained -eq $true -and
        $actual.modeSelection.automationSelectionFallbackUsed -eq $false -and
        $actual.formatSelection.physicalSelectionRetained -eq $true -and
        $actual.formatSelection.automationSelectionFallbackUsed -eq $false) (
        "Actual format/mode selection was not retained physical input.")
    Assert ($actual.nativeSave.physicalInputRetained -eq $true -and
        $actual.nativeSave.automationValueFallbackUsed -eq $false -and
        $actual.nativeSave.explicitEnterSubmitted -eq $true -and
        $actual.nativeSave.dialogClosedAfterSubmit -eq $true) (
        "Native Save picker did not use the committed physical filename path.")
    Assert ($actual.result.physicalConfirmClickRetained -eq $true -and
        $actual.result.closeAutomationFallbackUsed -eq $false) (
        "Export result was not confirmed through retained physical input.")
    Assert (@($entry.screenshots).Count -eq 7) (
        "$($expected.name) does not contain seven screenshots.")
    foreach ($screenshot in @($entry.screenshots)) {
        $screenshotPath = Resolve-FormalPath $screenshot.path (
            "$($expected.name) screenshot")
        $current = File-Evidence $screenshotPath
        Assert ($current.sha256 -ceq [string]$screenshot.sha256 -and
            $current.length -eq [long]$screenshot.length) (
            "Screenshot changed after capture: $($screenshot.path)")
    }

    $structure = switch ($expected.name) {
        "malody-single-chart-export" {
            Test-CompactMcText (Get-Content -Raw -LiteralPath $destination) (
                "Malody single-chart export")
        }
        "malody-rate-pack-export" {
            Inspect-Archive $destination 4 0 4 1 @(
                "_0.8x.mc", "_0.9x.mc", "_1x.mc", "_1.1x.mc",
                "_0.8x.ogg", "_0.9x.ogg", "_1.1x.ogg",
                "Resound - Nhato.ogg", "Resound - Nhato.jpg") (
                "Malody rate pack")
        }
        "osu-single-chart-export" {
            Test-OsuText (Get-Content -Raw -LiteralPath $destination) (
                "osu single-chart export")
        }
        "osu-single-rate-export" {
            Inspect-Archive $destination 0 1 1 1 @(
                "1.2x].osu", "_1.2x.ogg", "Resound - Nhato.jpg") (
                "osu single-rate package")
        }
        "osu-rate-pack-export" {
            Inspect-Archive $destination 0 4 4 1 @(
                "0.8x].osu", "0.9x].osu", "1.1x].osu",
                "_0.8x.ogg", "_0.9x.ogg", "_1.1x.ogg",
                "Resound - Nhato.ogg", "Resound - Nhato.jpg") (
                "osu rate pack")
        }
        default { throw "Unhandled export '$($expected.name)'." }
    }
    $exportChecks.Add([ordered]@{
        name = $expected.name
        format = $expected.format
        mode = $expected.mode
        preservePitch = $expected.preservePitch
        file = $destinationFile
        captureResult = File-Evidence $captureResultPath
        physicalFormatAndModeSelection = $true
        nativeSaveFilenameCommittedWithExplicitEnter = $true
        structure = $structure
    })
}

$expectedImports = @(
    [ordered]@{
        name = "malody-single-chart-import"
        tabs = 1
        osuDialogs = 0
        actions = 0
        archive = $false
        mode = "Calibrate"
        workspaceFiles = 1
    }
    [ordered]@{
        name = "malody-rate-pack-import"
        tabs = 4
        osuDialogs = 0
        actions = 1
        archive = $true
        mode = "Calibrate"
        workspaceFiles = 9
    }
    [ordered]@{
        name = "osu-single-chart-calibrate-import"
        tabs = 1
        osuDialogs = 1
        actions = 1
        archive = $false
        mode = "Calibrate"
        workspaceFiles = 1
    }
    [ordered]@{
        name = "osu-single-chart-preserve-import"
        tabs = 1
        osuDialogs = 1
        actions = 1
        archive = $false
        mode = "Preserve"
        workspaceFiles = 1
    }
    [ordered]@{
        name = "osu-single-rate-import"
        tabs = 1
        osuDialogs = 1
        actions = 2
        archive = $true
        mode = "Preserve"
        workspaceFiles = 3
    }
    [ordered]@{
        name = "osu-rate-pack-import"
        tabs = 4
        osuDialogs = 4
        actions = 5
        archive = $true
        mode = "Calibrate"
        workspaceFiles = 9
    })

$importChecks = [Collections.Generic.List[object]]::new()
foreach ($expected in $expectedImports) {
    $matches = @($capture.imports | Where-Object name -ceq $expected.name)
    Assert ($matches.Count -eq 1) "Missing unique import '$($expected.name)'."
    $entry = $matches[0]
    $evidencePath = Resolve-FormalPath $entry.evidence.path (
        "$($expected.name) evidence")
    $gui = Get-Content -Raw -LiteralPath $evidencePath |
        ConvertFrom-Json -Depth 100
    Assert ($gui.schema -ceq (
        "lumachart.windows.avalonia.format-fresh-import-gui-evidence.v1")) (
        "Unexpected fresh-import schema for $($expected.name).")
    Assert ($gui.status -ceq "passed" -and $gui.passed -eq $true -and
        $gui.windowsAvaloniaOnly -eq $true -and
        $gui.productionServerMutationPerformed -eq $false -and
        $gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false) (
        "Fresh import violated its passed Windows-only boundary.")
    Assert ($gui.pureDotnetRelease -eq $true -and
        $gui.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
        "Fresh import was not ordinary unprotected .NET Release.")
    $expectedPhysicalMouse = $expected.actions -gt 0
    Assert ($gui.physicalMouseInputUsed -eq $expectedPhysicalMouse -and
        $gui.enterKeyUsed -eq $false) (
        "$($expected.name) did not preserve its physical-pointer/no-Enter boundary.")
    Assert ($gui.process.normalExit -eq $true -and
        [int]$gui.process.exitCode -eq 0 -and
        $gui.input.unchanged -eq $true -and
        [string]$gui.input.before.sha256 -ceq [string]$gui.input.after.sha256) (
        "Fresh import failed normal exit or changed its input.")
    Assert ([int]$gui.expectedTabCount -eq $expected.tabs -and
        @($gui.tabs).Count -eq $expected.tabs) (
        "$($expected.name) tab count mismatch.")
    Assert (@($gui.osuDialogs).Count -eq $expected.osuDialogs -and
        @($gui.physicalActions).Count -eq $expected.actions -and
        [string]$gui.osuImportMode -ceq $expected.mode) (
        "$($expected.name) dialog/action/mode count mismatch.")
    foreach ($dialog in @($gui.osuDialogs)) {
        $expectedAction = if ($expected.mode -ceq "Calibrate") {
            "OsuImportMode.Calibrate"
        } else { "OsuImportMode.Preserve" }
        Assert ([string]$dialog.action.automationId -ceq $expectedAction -and
            $dialog.action.isEnabled -eq $true -and
            $dialog.action.isOffscreen -eq $false) (
            "$($expected.name) did not use the requested visible osu action.")
    }
    Assert (($null -ne $gui.archiveDialog) -eq $expected.archive) (
        "$($expected.name) archive-dialog presence mismatch.")
    if ($expected.archive) {
        Assert ($gui.archiveDialog.open.isEnabled -eq $true -and
            $gui.archiveDialog.open.isOffscreen -eq $false -and
            $null -ne $gui.archiveDialogScreenshot) (
            "$($expected.name) archive-open action was not visibly enabled.")
    }
    Assert (@($gui.workspaceTree).Count -eq $expected.workspaceFiles) (
        "$($expected.name) workspace file count mismatch.")
    Assert ([int]$gui.runtime.chart.structure.noteCount -eq 2753 -and
        $gui.runtime.timeline.singleCustomControl -eq $true -and
        [int]$gui.runtime.timeline.perNoteAvaloniaControlCount -eq 0 -and
        $gui.runtime.timeline.visibleAreaClipping -eq $true) (
        "$($expected.name) did not open the real chart in the virtualized editor.")
    $finalPath = Resolve-FormalPath $entry.finalScreenshot.path (
        "$($expected.name) final screenshot")
    $finalFile = File-Evidence $finalPath
    Assert ($finalFile.sha256 -ceq [string]$gui.finalScreenshot.sha256) (
        "$($expected.name) final screenshot changed after capture.")
    $importChecks.Add([ordered]@{
        name = $expected.name
        input = File-Evidence (Resolve-FormalPath $entry.input.path (
                "$($expected.name) input"))
        evidence = File-Evidence $evidencePath
        tabCount = @($gui.tabs).Count
        osuDialogCount = @($gui.osuDialogs).Count
        physicalActionCount = @($gui.physicalActions).Count
        archiveDialogPassed = if ($expected.archive) { $true } else { $null }
        inputUnchanged = $true
        noteCount = [int]$gui.runtime.chart.structure.noteCount
        timelineSingleCustomControl = $true
        finalScreenshot = $finalFile
    })
}

$visualReviewPath = Join-Path $formalRoot "visual-review.json"
$visualReviewFile = File-Evidence $visualReviewPath
Assert ($visualReviewFile.sha256 -ceq $ExpectedVisualReviewSha256.ToUpperInvariant()) (
    "Visual review hash differs from the reviewed authority.")
$visualReview = Get-Content -Raw -LiteralPath $visualReviewPath |
    ConvertFrom-Json -Depth 20
Assert ($visualReview.schema -ceq (
    "lumachart.windows.avalonia.format-modes-visual-review.v1") -and
    $visualReview.status -ceq "passed" -and
    $visualReview.allPassed -eq $true -and
    @($visualReview.screenshots).Count -eq 19) (
    "Visual review is not a passed 19-screenshot review.")
foreach ($screenshot in @($visualReview.screenshots)) {
    Assert ($screenshot.passed -eq $true) (
        "Visual review contains a failed screenshot: $($screenshot.path)")
    $path = [IO.Path]::GetFullPath((Join-Path $formalRoot $screenshot.path))
    Assert ($path.StartsWith(
            $formalRoot + '\',
            [StringComparison]::OrdinalIgnoreCase)) (
        "Visual review screenshot escaped the formal root.")
    $current = File-Evidence $path
    Assert ($current.sha256 -ceq [string]$screenshot.sha256 -and
        $current.length -eq [long]$screenshot.length) (
        "Visually reviewed screenshot changed: $($screenshot.path)")
}

$sourcePath = 'D:\osu!\Songs\Resound\0\1781536331.mc'
$source = File-Evidence $sourcePath
Assert ($source.sha256 -ceq
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") (
    "Real Resound MC changed.")
Assert ([string]$capture.source.before.sha256 -ceq $source.sha256 -and
    [string]$capture.source.after.sha256 -ceq $source.sha256 -and
    $capture.source.unchanged -eq $true) (
    "Capture did not preserve the real Resound MC.")
$installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$installer = File-Evidence $installerPath
Assert ($installer.sha256 -ceq
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") (
    "Frozen WPF installer changed.")
Assert ([string]$capture.immutableInstaller.before.sha256 -ceq $installer.sha256 -and
    [string]$capture.immutableInstaller.after.sha256 -ceq $installer.sha256) (
    "Capture did not preserve the frozen installer.")

$temporaryResidue = @(
    Get-ChildItem -LiteralPath $formalRoot -Recurse -Force |
        Where-Object {
            $_.Name -like "*.luma-part" -or
            $_.Name -like "*.luma-export.tmp" -or
            $_.FullName -like "*\_scratch\*"
        })
Assert ($temporaryResidue.Count -eq 0) (
    "Formal format evidence contains temporary export residue.")

$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.format-modes-slice-verification.v1"
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    formalMigrationAuthority = $true
    platform = "Windows Avalonia only"
    windowsAvaloniaOnly = $true
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    productionServerMutationPerformed = $false
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    migrationComplete = $false
    captureEvidence = $captureFile
    builds = $builds
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            file = File-Evidence $specsPath
            passed = $passedChecks.Count
            total = $checks.Count
            focusedChecks = $focusedSpecNames
        }
        mainSpecs = [ordered]@{
            file = File-Evidence $mainSpecsPath
            passed = 79
            total = 79
        }
    }
    exports = $exportChecks.ToArray()
    imports = $importChecks.ToArray()
    visualReview = [ordered]@{
        file = $visualReviewFile
        screenshotCount = @($visualReview.screenshots).Count
        allPassed = $true
        observations = @($visualReview.observations)
    }
    immutability = [ordered]@{
        realResoundMc = $source
        frozenWpfInstaller = $installer
    }
    atomicExportResidue = [ordered]@{
        lumaPartOrExportTmpOrScratchCount = $temporaryResidue.Count
        passed = $true
    }
    remainingDifferences = @(
        "This closes the focused MC/MCZ/osu/OSZ GUI format-mode slice, not the full migration.",
        "Installer/update/uninstall and ordinary ClientSecurity gates remain.",
        "60/120 Hz, 4K, 100,000-Note and same-machine WPF A/B performance gates remain.",
        "Remaining main-function matrix rows and two-client scenarios remain.",
        "Pixel UI, focus, Chinese IME and shortcut parity are intentionally scheduled last per user direction.",
        "User manual replacement confirmation remains required.")
}
Write-Utf8 $verificationPath ($evidence | ConvertTo-Json -Depth 100)
Write-Output "Windows Avalonia format-mode verification: passed-migration-incomplete"
Write-Output "Evidence: $verificationPath"
