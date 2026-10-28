param(
    [string]$FormalRoot = (
        Join-Path $PSScriptRoot `
            "..\artifacts\windows-avalonia-editor-toast-slice-20260728-r1")
)

$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$formalRoot = [IO.Path]::GetFullPath($FormalRoot)
$projectBoundary = $projectRoot.TrimEnd('\') + '\'
if (-not $formalRoot.StartsWith(
        $projectBoundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal root must stay below the project root: $formalRoot"
}
if (-not (Test-Path -LiteralPath $formalRoot -PathType Container)) {
    throw "Formal root not found: $formalRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Read-Json([string]$Path) {
    Assert (Test-Path -LiteralPath $Path -PathType Leaf) "Missing JSON: $Path"
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function File-Evidence([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        bytes = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
}

function Assert-OrdinaryStrictBuild([string]$Path) {
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    Assert (
        $text.Contains("0 个警告", [StringComparison]::Ordinal) -and
        $text.Contains("0 个错误", [StringComparison]::Ordinal)) (
        "Strict build log is not 0 warning / 0 error: $Path")
    foreach ($forbidden in @(
            "OLLVM",
            "Obfuscator",
            "NativeAOT",
            "PublishAot=true",
            "code virtualization")) {
        Assert (
            -not $text.Contains(
                $forbidden,
                [StringComparison]::OrdinalIgnoreCase)) (
            "Strict build log contains forbidden protection/AOT text '$forbidden': $Path")
    }
    return File-Evidence $Path
}

$guiPath = Join-Path $formalRoot "editor-toast-gui\evidence.json"
$avaloniaSpecsPath = Join-Path `
    $formalRoot `
    "tests\avalonia-specs-evidence.json"
$mainSpecsLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$gui = Read-Json $guiPath
$avaloniaSpecs = Read-Json $avaloniaSpecsPath

Assert (
    $gui.schema -ceq
        "lumachart.windows.avalonia.editor-toast-gui-evidence.v1" -and
    $gui.status -ceq "passed-migration-incomplete" -and
    $gui.platform -ceq "Windows Avalonia only" -and
    $gui.buildMode -ceq "ordinary .NET Release") (
    "Editor-toast GUI evidence boundary drifted.")
Assert (
    [bool]$gui.safety.explicitCurrentTurnConsent -and
    [int]$gui.safety.minimumIdleMilliseconds -ge 3000 -and
    [bool]$gui.safety.heldModifierGate -and
    -not [bool]$gui.safety.productionServerDeployed -and
    -not [bool]$gui.safety.mobileProjectsBuiltModifiedInstalledOrTested -and
    -not [bool]$gui.safety.ollvmObfuscationPackingVirtualizationOrAotUsed) (
    "GUI safety or platform boundary drifted.")
Assert (
    -not [bool]$gui.completion.windowsAvaloniaCanReplaceWpf -and
    -not [bool]$gui.completion.userManualReplacementApprovalReceived -and
    -not [bool]$gui.completion.nextPlatformAuthorized) (
    "Completion boundary drifted.")

$realMcSha256 =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$installerSha256 =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
Assert (
    [string]$gui.gui.realChart.sha256Before -ceq $realMcSha256 -and
    [string]$gui.gui.realChart.sha256After -ceq $realMcSha256 -and
    [bool]$gui.gui.realChart.sourceUnchangedAfterDiscard) (
    "Real MC fixture changed or was not discarded.")
Assert (
    [string]$gui.frozenInstaller.sha256Before -ceq $installerSha256 -and
    [string]$gui.frozenInstaller.sha256After -ceq $installerSha256) (
    "Frozen WPF installer changed.")

$toast = $gui.gui.editorToast
Assert (
    [string]$toast.helpText -ceq
        "Visible=True; Message=自动备份成功; DurationMilliseconds=3000; Right=18; Bottom=18" -and
    [string]$toast.message -ceq "自动备份成功" -and
    [int]$toast.requestedDurationMilliseconds -eq 3000 -and
    [double]$toast.visibleDurationMilliseconds -ge 2400 -and
    [double]$toast.visibleDurationMilliseconds -le 4500 -and
    [bool]$toast.nonInteractive) (
    "WPF 1.1.0 transient editor-toast contract drifted.")

$screenshotPath = [string]$toast.screenshot.path
$screenshot = File-Evidence $screenshotPath
Assert (
    $screenshot.sha256 -ceq [string]$toast.screenshot.sha256 -and
    $screenshot.bytes -eq [long]$toast.screenshot.bytes -and
    [int]$toast.screenshot.width -eq 1980 -and
    [int]$toast.screenshot.height -eq 1200) (
    "Editor-toast screenshot hash, length or dimensions drifted.")
Assert (
    [double]$toast.bounds.width -gt 0 -and
    [double]$toast.bounds.height -gt 0) (
    "Editor-toast UIA bounds are empty.")

$actions = @($gui.gui.actions)
Assert (
    [int]$gui.gui.actionCount -eq 4 -and
    $actions.Count -eq 4 -and
    [string]$actions[0].action -ceq "uia-value-pattern" -and
    [string]$actions[0].target -ceq "Inspector.Note.Volume" -and
    [string]$actions[0].value -ceq "73" -and
    [string]$actions[1].action -ceq "uia-invoke-pattern" -and
    [string]$actions[1].target -ceq "Inspector.Note.Apply" -and
    [string]$actions[2].action -ceq "uia-window-close-pattern" -and
    [string]$actions[3].target -ceq "UnsavedChanges.Discard" -and
    [bool]$gui.gui.uiaControlPatternsUsed -and
    -not [bool]$gui.gui.win32InputInjectionUsed -and
    -not [bool]$gui.gui.hardwareMouseInputClaimed -and
    -not [bool]$gui.gui.hardwareKeyboardInputClaimed -and
    -not [bool]$gui.gui.enterKeySent -and
    -not [bool]$gui.gui.persistentTopmostUsed -and
    [int]$gui.gui.processExitCode -eq 0) (
    "Editor-toast GUI action or non-topmost evidence drifted.")

$backupPath = [string]$gui.gui.automaticBackup.file
$backupRoot = Join-Path $formalRoot "editor-toast-gui\local-data\Backups"
$backupRootBoundary = [IO.Path]::GetFullPath($backupRoot).TrimEnd('\') + '\'
$resolvedBackupPath = [IO.Path]::GetFullPath($backupPath)
Assert (
    $resolvedBackupPath.StartsWith(
        $backupRootBoundary,
        [StringComparison]::OrdinalIgnoreCase)) (
    "Automatic backup escaped the isolated backup root.")
$backupFiles = @(
    Get-ChildItem `
        -LiteralPath $backupRoot `
        -File `
        -Recurse `
        -Filter "*.mcbackup")
Assert (
    $backupFiles.Count -eq 1 -and
    $backupFiles[0].FullName -ceq $resolvedBackupPath) (
    "Expected exactly one isolated automatic backup.")
$backupFile = File-Evidence $resolvedBackupPath
Assert (
    $backupFile.bytes -eq [long]$gui.gui.automaticBackup.bytes -and
    $backupFile.sha256 -ceq [string]$gui.gui.automaticBackup.sha256 -and
    [int]$gui.gui.automaticBackup.fileCount -eq 1) (
    "Automatic-backup file hash, size or count drifted.")

$backup = Read-Json $resolvedBackupPath
$backupNotes = @($backup.note)
$playableNotes = @(
    $backupNotes | Where-Object {
        $null -ne $_.column -and $null -eq $_.type
    })
$backgroundNotes = @(
    $backupNotes | Where-Object { [int]$_.type -eq 1 })
$firstBeat = @($backupNotes[0].beat)
Assert (
    $backupNotes.Count -eq 2754 -and
    $playableNotes.Count -eq 2753 -and
    $backgroundNotes.Count -eq 1 -and
    @($backup.time).Count -eq 1 -and
    $firstBeat.Count -eq 3 -and
    [int]$firstBeat[0] -eq 10 -and
    [int]$firstBeat[1] -eq 0 -and
    [int]$firstBeat[2] -eq 4 -and
    [int]$backupNotes[0].column -eq 0 -and
    [int]$backupNotes[0].vol -eq 73) (
    "Structured automatic backup did not preserve the real 2,753-Note chart edit.")
$backupMarker = $backup.'_luma_backup'
Assert (
    [string]$backupMarker.editor -ceq "LumaChart Studio" -and
    [IO.Path]::GetFullPath([string]$backupMarker.original_path) -ceq
        [IO.Path]::GetFullPath([string]$gui.gui.realChart.path) -and
    -not [string]::IsNullOrWhiteSpace([string]$backupMarker.created_at)) (
    "Automatic-backup provenance marker drifted.")

$checks = @($avaloniaSpecs.Checks)
Assert (
    $avaloniaSpecs.Schema -ceq "lumachart.windows.avalonia.slice-specs.v2" -and
    $avaloniaSpecs.Status -ceq "passed" -and
    $checks.Count -eq 483 -and
    @($checks | Where-Object { -not $_.Passed }).Count -eq 0) (
    "Avalonia Specs are not 483/483.")
$toastSpec = @(
    $checks | Where-Object {
        $_.Name -ceq
            "editor-auto-backup-toast-matches-wpf-110-transient-contract"
    })
Assert (
    $toastSpec.Count -eq 1 -and
    [bool]$toastSpec[0].Passed -and
    [string]$toastSpec[0].Detail -ceq
        "right/bottom=18; padding=13/9; duration=3000ms") (
    "Dedicated WPF editor-toast parity spec drifted.")
$mainSpecsText =
    Get-Content -LiteralPath $mainSpecsLogPath -Raw -Encoding UTF8
Assert (
    $mainSpecsText.Contains(
        "79/79 specs passed.",
        [StringComparison]::Ordinal)) (
    "Main Specs are not 79/79.")

$buildEvidence = [ordered]@{}
foreach ($buildName in @(
        "avalonia-build.log",
        "avalonia-specs-build.log",
        "main-specs-build.log",
        "online-gui-server-build.log")) {
    $buildEvidence[$buildName] =
        Assert-OrdinaryStrictBuild (Join-Path $formalRoot "build\$buildName")
}

$sourceEvidence = [ordered]@{}
foreach ($relativePath in @(
        "LumaChart.Avalonia\Infrastructure\WindowsTransientToastParityPolicy.cs",
        "LumaChart.Avalonia\MainWindow.cs",
        "LumaChart.Avalonia.Specs\WindowsInspectorParitySpecs.cs",
        "tools\Capture-WindowsAvaloniaEditorToastGui.ps1",
        "tools\New-WindowsAvaloniaEditorToastSliceEvidence.ps1")) {
    $sourceEvidence[$relativePath] =
        File-Evidence (Join-Path $projectRoot $relativePath)
}

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.editor-toast-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    platform = "Windows Avalonia only"
    buildMode = "ordinary .NET Release"
    buildBoundary = [ordered]@{
        ollvm = $false
        obfuscation = $false
        packing = $false
        codeVirtualization = $false
        aot = $false
        nativeAot = $false
        strictBuilds = $buildEvidence
    }
    automatedTests = [ordered]@{
        avalonia = [ordered]@{
            passed = 483
            total = 483
            evidence = File-Evidence $avaloniaSpecsPath
        }
        main = [ordered]@{
            passed = 79
            total = 79
            log = File-Evidence $mainSpecsLogPath
        }
    }
    gui = [ordered]@{
        realChart = [ordered]@{
            sha256 = $realMcSha256
            playableNotes = 2753
            changedVolumeAtBeat = "10:0/4"
            changedVolume = 73
            sourceUnchangedAfterDiscard = $true
        }
        automaticBackup = [ordered]@{
            file = $backupFile
            structurallyParsed = $true
            playableNotes = 2753
            backgroundNotes = 1
            provenanceMarkerValidated = $true
        }
        editorToast = [ordered]@{
            message = "自动备份成功"
            durationMilliseconds =
                [double]$toast.visibleDurationMilliseconds
            requestedDurationMilliseconds = 3000
            rightDip = 18
            bottomDip = 18
            nonInteractive = $true
            screenshotVisuallyInspected = $true
            screenshot = $screenshot
        }
        uiaControlPatternsUsed = $true
        physicalInputClaimed = $false
        persistentTopmostUsed = $false
        processExitCode = 0
        evidence = File-Evidence $guiPath
    }
    source = $sourceEvidence
    integrity = [ordered]@{
        realMcSha256 = $realMcSha256
        frozenInstallerSha256 = $installerSha256
        productionServerDeployed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
    }
    completion = [ordered]@{
        windowsAvaloniaCanReplaceWpf = $false
        userManualReplacementApprovalReceived = $false
        nextPlatformAuthorized = $false
    }
    remainingDifferences = @(
        "The complete Windows parity matrix remains open.",
        "Other WPF transient surfaces, popup focus paths and shortcut interactions remain open.",
        "Two-client online combinations, multi-DPI/display-present performance, format/game, ClientSecurity and install/upgrade/uninstall final gates remain open.")
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
$verification |
    ConvertTo-Json -Depth 24 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
[pscustomobject]@{
    verificationPath = $verificationPath
    verificationBytes = (Get-Item -LiteralPath $verificationPath).Length
    verificationSha256 =
        (Get-FileHash -LiteralPath $verificationPath -Algorithm SHA256).Hash
    status = "passed-migration-incomplete"
}
