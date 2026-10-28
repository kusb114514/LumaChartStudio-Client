param(
    [Parameter(Mandatory = $true)][string]$FormalRoot
)

if ($PSVersionTable.PSEdition -ne "Core") {
    throw "Dialog slice evidence requires PowerShell Core."
}
if (-not $IsWindows) {
    throw "Dialog slice evidence is Windows-only."
}

$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath(
    (Join-Path $projectRoot "artifacts\windows-avalonia-dialog-slice-20260727-r1"))
$formalFullPath = [IO.Path]::GetFullPath($FormalRoot).TrimEnd('\')
if (-not [string]::Equals(
        $formalFullPath,
        $expectedRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal dialog authority must be exactly $expectedRoot"
}
if (-not (Test-Path -LiteralPath $formalFullPath -PathType Container)) {
    throw "Formal dialog root does not exist: $formalFullPath"
}

$verificationPath = Join-Path $formalFullPath "verification-evidence.json"
if (Test-Path -LiteralPath $verificationPath) {
    throw "Verification output already exists: $verificationPath"
}

function Read-RequiredText {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required evidence file is missing: $Path"
    }
    return Get-Content -LiteralPath $Path -Raw
}

function Get-FileEvidence {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Required evidence file is missing: $fullPath"
    }
    $item = Get-Item -LiteralPath $fullPath
    return [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $fullPath)
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    }
}

$buildLogs = [ordered]@{}
foreach ($entry in ([ordered]@{
        avalonia = Join-Path $formalFullPath "build\avalonia.log"
        avaloniaSpecs = Join-Path $formalFullPath "build\avalonia-specs.log"
        mainSpecs = Join-Path $formalFullPath "build\main-specs.log"
    }).GetEnumerator()) {
    $text = Read-RequiredText $entry.Value
    if ($text -notmatch "0 个警告" -or
        $text -notmatch "0 个错误" -or
        $text -match "生成失败") {
        throw "Strict build log did not prove 0 warning / 0 error: $($entry.Value)"
    }
    $buildLogs[$entry.Key] = Get-FileEvidence $entry.Value
}

$avaloniaSpecsPath =
    Join-Path $formalFullPath "specs\avalonia-specs-evidence.json"
$avaloniaSpecs = Get-Content -LiteralPath $avaloniaSpecsPath -Raw |
    ConvertFrom-Json
$checks = @($avaloniaSpecs.checks)
$failedChecks = @($checks | Where-Object { -not [bool]$_.passed })
if ([string]$avaloniaSpecs.status -cne "passed" -or
    $checks.Count -ne 417 -or
    $failedChecks.Count -ne 0) {
    throw "Avalonia Specs did not prove 417/417."
}
$dialogChecks = @($checks | Where-Object { [string]$_.name -like "dialog-*" })
if ($dialogChecks.Count -ne 3 -or
    @($dialogChecks | Where-Object { -not [bool]$_.passed }).Count -ne 0) {
    throw "The three dialog parity Specs did not pass."
}

$mainSpecsPath = Join-Path $formalFullPath "specs\main-specs.log"
$mainSpecsText = Read-RequiredText $mainSpecsPath
if ($mainSpecsText -notmatch "79/79 specs passed\.") {
    throw "Main Specs did not prove 79/79."
}

$guiEvidencePath = Join-Path $formalFullPath "gui\evidence.json"
$guiEvidence = Get-Content -LiteralPath $guiEvidencePath -Raw |
    ConvertFrom-Json
if ([string]$guiEvidence.status -cne "passed" -or
    [string]$guiEvidence.contract -cne "wpf-1.1.0-dialog-r1" -or
    -not [bool]$guiEvidence.input.sourceUnchanged -or
    [string]$guiEvidence.input.isolatedChartSha256Before -cne
        "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E" -or
    [string]$guiEvidence.input.isolatedChartSha256After -cne
        "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E" -or
    [string]$guiEvidence.runtimeEvidence.schema -cne
        "lumachart.windows.avalonia.gui-evidence.v14" -or
    [string]$guiEvidence.runtimeEvidence.platformScope -cne "Windows-only" -or
    [int]$guiEvidence.runtimeEvidence.noteCount -ne 2753 -or
    [int]$guiEvidence.runtimeEvidence.longNoteCount -ne 771) {
    throw "Formal dialog GUI evidence did not prove the real Windows MC contract."
}
$actions = @($guiEvidence.actions)
if ($actions.Count -ne 4 -or
    -not [bool]$actions[2].dirtyTabPreserved -or
    -not [bool]$actions[3].dirtyTabRemoved -or
    [string]$actions[1].method -cne "foreground physical click" -or
    [string]$actions[2].method -cne "foreground physical pointer and click" -or
    [string]$actions[3].method -cne "foreground physical clicks") {
    throw "Formal GUI did not prove the physical open/hover/cancel/discard chain."
}

$screenshots = @($guiEvidence.screenshots)
if ($screenshots.Count -ne 5) {
    throw "Formal dialog GUI must contain exactly five declared screenshots."
}
$screenshotEvidence = [Collections.Generic.List[object]]::new()
foreach ($declared in $screenshots) {
    $actual = Get-FileEvidence ([string]$declared.path)
    if ([long]$actual.length -ne [long]$declared.length -or
        [string]$actual.sha256 -cne [string]$declared.sha256) {
        throw "Screenshot hash or length differs from GUI evidence: $($declared.path)"
    }
    $screenshotEvidence.Add($actual)
}
if ([string]$screenshots[1].sha256 -ceq [string]$screenshots[2].sha256) {
    throw "Physical discard hover screenshot is identical to baseline."
}

$changedPaths = @(
    "LumaChart.Avalonia\Dialogs\WindowsWpf110ChoiceDialog.cs",
    "LumaChart.Avalonia\Dialogs\UnsavedChangesDialog.cs",
    "LumaChart.Avalonia\Dialogs\OsuImportModeDialog.cs",
    "LumaChart.Avalonia\Dialogs\NoteTypeTransformDialog.cs",
    "LumaChart.Avalonia\Dialogs\ArchiveImportDialog.cs",
    "LumaChart.Avalonia\Dialogs\AudioTempoDialogs.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\WindowsDialogParitySpecs.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "tools\Capture-WindowsAvaloniaDialogParityGui.ps1",
    "tools\New-WindowsAvaloniaDialogSliceEvidence.ps1"
)
$changedFiles = [Collections.Generic.List[object]]::new()
foreach ($path in $changedPaths) {
    $changedFiles.Add((Get-FileEvidence (Join-Path $projectRoot $path)))
}

$installer = Get-FileEvidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
if ([string]$installer.sha256 -cne
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
    throw "Frozen WPF 1.1.0 installer hash changed."
}
$predecessor = Get-FileEvidence (
    Join-Path $projectRoot (
        "artifacts\windows-avalonia-control-theme-slice-20260727-r3\" +
        "verification-evidence.json"))
if ([string]$predecessor.sha256 -cne
    "D320BE9C2B46580F8E79171547B2028EEFD3315663AA96D6BF7CCB7430267037") {
    throw "Control-theme r3 predecessor authority changed."
}

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.dialog-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        platform = "Windows Avalonia only"
        contract = "wpf-1.1.0-dialog-r1"
        covered = @(
            "shared WPF LumaDialog chrome and tone palettes",
            "owner-modal no-system-decoration/no-taskbar window policy",
            "stable UI/font scale reapplication",
            "unsaved close physical open/hover/cancel/discard",
            "osu/audio/BPM/note-transform/archive wrappers"
        )
        excluded = @(
            "Android",
            "iOS",
            "macOS",
            "Linux",
            "WebAssembly",
            "production Server deployment",
            "installer replacement",
            "OLLVM",
            "obfuscation",
            "packing",
            "code virtualization",
            "AOT",
            "NativeAOT"
        )
    }
    builds = [ordered]@{
        configuration = "ordinary .NET Release"
        warnings = 0
        errors = 0
        logs = $buildLogs
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 417
            total = 417
            failed = 0
            dialogChecks = $dialogChecks
            evidence = Get-FileEvidence $avaloniaSpecsPath
            log = Get-FileEvidence (
                Join-Path $formalFullPath "specs\avalonia-specs.log")
        }
        mainSpecs = [ordered]@{
            passed = 79
            total = 79
            failed = 0
            log = Get-FileEvidence $mainSpecsPath
        }
    }
    gui = [ordered]@{
        evidence = Get-FileEvidence $guiEvidencePath
        runtime = Get-FileEvidence (
            Join-Path $formalFullPath "gui\runtime-evidence.json")
        screenshots = $screenshotEvidence
        physicalActions = 6
        physicalHoverBaselineDistinct = $true
        dirtyTabPreservedAfterCancel = $true
        dirtyTabRemovedAfterDiscard = $true
        realMcNoteCount = 2753
        realMcLongNoteCount = 771
        realMcSourceUnchanged = $true
        formalRunExcludedEarlierUserMouseInterference = $true
    }
    integrity = [ordered]@{
        frozenInstaller = $installer
        predecessorControlThemeR3 = $predecessor
    }
    changedFiles = $changedFiles
    remainingDifferences = @(
        "other popup/modal families not yet migrated to the shared contract",
        "fonts, avatar and online latency-label pixel parity",
        "remaining IME/focus and shortcut host edges",
        "online difficult branches and room Sound playback combinations",
        "format edges, ordinary ClientSecurity, installer/update/uninstall",
        "1080p/1440p/4K multi-DPI and physical 60/120 Hz WPF/Avalonia A-B"
    )
    completion = [ordered]@{
        migrationComplete = $false
        wpfReplacementApproved = $false
        otherPlatformsAuthorized = $false
    }
}

$verification | ConvertTo-Json -Depth 20 |
    Set-Content -LiteralPath $verificationPath -Encoding UTF8
$result = Get-FileEvidence $verificationPath
Write-Output "Windows Avalonia dialog verification: passed-migration-incomplete"
Write-Output "Verification: $verificationPath"
Write-Output "SHA-256: $($result.sha256)"
