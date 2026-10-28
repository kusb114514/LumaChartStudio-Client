param(
    [string]$FormalRoot = (
        Join-Path $PSScriptRoot `
            "..\artifacts\windows-avalonia-diagnostic-logging-slice-20260728-r1")
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
    Assert (
        Test-Path -LiteralPath $Path -PathType Leaf) (
        "Missing JSON: $Path")
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 |
        ConvertFrom-Json
}

function File-Evidence([string]$Path) {
    Assert (
        Test-Path -LiteralPath $Path -PathType Leaf) (
        "Missing evidence file: $Path")
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        bytes = [long]$item.Length
        sha256 = (
            Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    Assert (
        $text.Contains("0 个警告", [StringComparison]::Ordinal) -and
        $text.Contains("0 个错误", [StringComparison]::Ordinal)) (
        "Strict build is not 0 warning / 0 error: $Path")
    Assert (
        -not $text.Contains(
            "System.Collections.Hashtable.Artifact",
            [StringComparison]::Ordinal)) (
        "Strict build used the invalid hashtable artifact path: $Path")
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
            "Strict build contains forbidden protection/AOT text '$forbidden': $Path")
    }
    return File-Evidence $Path
}

$guiPath = Join-Path $formalRoot "diagnostic-fatal-gui\gui-evidence.json"
$avaloniaSpecsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$mainSpecsLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$automationSafetyPath = Join-Path $formalRoot "tests\gui-automation-safety.json"
$gui = Read-Json $guiPath
$avaloniaSpecs = Read-Json $avaloniaSpecsPath
$automationSafety = Read-Json $automationSafetyPath

Assert (
    $gui.schema -ceq
        "lumachart.windows.avalonia.diagnostic-fatal-gui.v1" -and
    $gui.status -ceq "passed") (
    "Diagnostic fatal GUI evidence boundary drifted.")
Assert (
    [int]$gui.application.exitCode -eq 1 -and
    [bool]$gui.consent.explicitCurrentTurnConsent -and
    [long]$gui.consent.idleMillisecondsBeforeStart -ge 3000 -and
    [int]$gui.consent.heldModifiers -eq 0) (
    "Controlled-fatal exit or consent evidence drifted.")
Assert (
    [string]$gui.dialog.className -ceq "#32770" -and
    [bool]$gui.dialog.ownerDisabled -and
    [bool]$gui.dialog.lastActivePopup -and
    -not [bool]$gui.dialog.ownerTopmostStyle -and
    -not [bool]$gui.dialog.dialogTopmostStyle) (
    "Fatal dialog owner modality or non-topmost contract drifted.")
Assert (
    [string]$gui.dialog.text -clike
        "*LumaChart Studio - 运行错误*" -and
    [string]$gui.dialog.text -clike "*已安全停止*" -and
    [string]$gui.dialog.text -clike "*诊断日志：*" -and
    -not ([string]$gui.dialog.text).Contains(
        "diagnostic-secret-token",
        [StringComparison]::Ordinal) -and
    -not ([string]$gui.dialog.text).Contains(
        "diagnostic-room-password",
        [StringComparison]::Ordinal)) (
    "Fatal user notice or secret boundary drifted.")
Assert (
    [string]$gui.action.name -ceq "WM_CLOSE" -and
    [string]$gui.action.input -ceq
        "Win32 WM_CLOSE posted to verified owned native dialog" -and
    -not [bool]$gui.inputSafety.hardwareInputClaimed -and
    -not [bool]$gui.inputSafety.win32InputInjectionUsed -and
    -not [bool]$gui.inputSafety.enterSent -and
    -not [bool]$gui.inputSafety.persistentTopmostUsed -and
    [bool]$gui.inputSafety.targetedWindowCloseMessageUsed) (
    "Diagnostic GUI input-safety contract drifted.")
Assert (
    [string]$automationSafety.schema -ceq
        "lumachart.windows.avalonia.gui-automation-safety.v1" -and
    [string]$automationSafety.status -ceq "passed" -and
    [bool]$automationSafety.windowsAvaloniaOnly -and
    [bool]$automationSafety.foregroundAutomationRequiresExplicitUserConsent -and
    [long]$automationSafety.minimumSystemIdleMilliseconds -ge 3000 -and
    [bool]$automationSafety.heldModifierGateRequired -and
    -not [bool]$automationSafety.persistentTopmostUsed -and
    [int]$automationSafety.captureScriptCount -eq 30 -and
    [int]$automationSafety.automationHelperSourceCount -eq 3) (
    "Formal GUI automation safety evidence drifted.")

$diagnosticFiles = @($gui.diagnostic.files)
Assert (
    [int]$gui.diagnostic.fileCount -eq 1 -and
    $diagnosticFiles.Count -eq 1 -and
    [int]$gui.diagnostic.recordCount -eq 4 -and
    [int]$gui.diagnostic.fatalRecordCount -eq 1 -and
    [bool]$gui.diagnostic.controlledTokenAbsent -and
    [bool]$gui.diagnostic.controlledRoomPasswordAbsent -and
    [bool]$gui.diagnostic.redactionMarkerPresent -and
    [int]$gui.diagnostic.maximumFiles -eq 8 -and
    [long]$gui.diagnostic.maximumFileBytes -eq 1048576) (
    "Diagnostic file, retention, record-count or redaction evidence drifted.")
$diagnosticPath = [IO.Path]::GetFullPath(
    [string]$diagnosticFiles[0].path)
Assert (
    $diagnosticPath.StartsWith(
        $formalRoot.TrimEnd('\') + '\',
        [StringComparison]::OrdinalIgnoreCase)) (
    "Diagnostic JSONL escaped the formal root.")
$diagnosticEvidence = File-Evidence $diagnosticPath
Assert (
    $diagnosticEvidence.sha256 -ceq
        [string]$diagnosticFiles[0].sha256 -and
    $diagnosticEvidence.bytes -eq
        [long]$diagnosticFiles[0].bytes -and
    $diagnosticEvidence.bytes -le 1048576) (
    "Diagnostic JSONL hash, length or size limit drifted.")
$diagnosticText =
    Get-Content -LiteralPath $diagnosticPath -Raw -Encoding UTF8
Assert (
    -not $diagnosticText.Contains(
        "diagnostic-secret-token",
        [StringComparison]::Ordinal) -and
    -not $diagnosticText.Contains(
        "diagnostic-room-password",
        [StringComparison]::Ordinal) -and
    $diagnosticText.Contains("[REDACTED]", [StringComparison]::Ordinal)) (
    "Diagnostic JSONL leaked the controlled secret or lost redaction markers.")
$records = @(
    Get-Content -LiteralPath $diagnosticPath -Encoding UTF8 |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_ | ConvertFrom-Json })
$expectedEvents = @(
    "application-starting",
    "controlled-fatal-fault-scheduled",
    "application-fatal-exception",
    "application-stopped")
Assert ($records.Count -eq 4) "Expected four diagnostic JSONL records."
for ($index = 0; $index -lt $expectedEvents.Count; $index++) {
    Assert (
        [string]$records[$index].Schema -ceq
            "lumachart.windows.avalonia.diagnostic.v1" -and
        [string]$records[$index].Event -ceq $expectedEvents[$index]) (
        "Diagnostic JSONL event order drifted at index $index.")
}
$fatalRecords = @(
    $records |
    Where-Object { [string]$_.Event -ceq "application-fatal-exception" })
Assert (
    $fatalRecords.Count -eq 1 -and
    [bool]$fatalRecords[0].Fatal -and
    [string]$fatalRecords[0].Severity -ceq "fatal" -and
    [string]$fatalRecords[0].ExceptionType -ceq
        "System.InvalidOperationException" -and
    [string]$fatalRecords[0].Message -clike "*[[]REDACTED[]]*") (
    "Fatal diagnostic record drifted.")

$screenshotPath = [IO.Path]::GetFullPath([string]$gui.screenshot.path)
Assert (
    $screenshotPath.StartsWith(
        $formalRoot.TrimEnd('\') + '\',
        [StringComparison]::OrdinalIgnoreCase)) (
    "Diagnostic screenshot escaped the formal root.")
$screenshotEvidence = File-Evidence $screenshotPath
Assert (
    $screenshotEvidence.sha256 -ceq [string]$gui.screenshot.sha256 -and
    $screenshotEvidence.bytes -eq [long]$gui.screenshot.bytes -and
    [int]$gui.screenshot.width -eq 1980 -and
    [int]$gui.screenshot.height -eq 1200 -and
    [string]$gui.screenshot.captureKind -ceq
        "physical owner window including native fatal dialog") (
    "Diagnostic screenshot hash, size, dimensions or capture kind drifted.")

$checks = @($avaloniaSpecs.checks)
Assert (
    $avaloniaSpecs.schema -ceq
        "lumachart.windows.avalonia.slice-specs.v2" -and
    $avaloniaSpecs.status -ceq "passed" -and
    $checks.Count -eq 492 -and
    @($checks | Where-Object { -not $_.passed }).Count -eq 0) (
    "Avalonia Specs are not 492/492.")
$dedicatedSpecs = @(
    "windows-diagnostic-structured-jsonl",
    "windows-diagnostic-secret-redaction",
    "windows-diagnostic-retention-bound",
    "windows-diagnostic-controlled-fault-guard",
    "windows-diagnostic-fatal-notice")
foreach ($name in $dedicatedSpecs) {
    $matches = @($checks | Where-Object { $_.name -ceq $name })
    Assert (
        $matches.Count -eq 1 -and [bool]$matches[0].passed) (
        "Dedicated diagnostic spec missing or failed: $name")
}

$mainSpecsText =
    Get-Content -LiteralPath $mainSpecsLogPath -Raw -Encoding UTF8
Assert (
    $mainSpecsText.Contains(
        "79/79 specs passed.",
        [StringComparison]::Ordinal)) (
    "Main Specs are not 79/79.")

$builds = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $formalRoot "builds\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "builds\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "builds\main-specs-build.log")
    onlineGuiServer = Assert-StrictBuild (
        Join-Path $formalRoot "builds\online-gui-server-build.log")
}

$realMc = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
$installer = File-Evidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert (
    $realMc.sha256 -ceq
        "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") (
    "Frozen real MC fixture changed.")
Assert (
    $installer.sha256 -ceq
        "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") (
    "Frozen WPF installer changed.")

$sourceFiles = @(
    "LumaChart.Avalonia\Infrastructure\WindowsDiagnosticLog.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsFatalErrorPolicy.cs",
    "LumaChart.Avalonia\Infrastructure\AvaloniaAppPaths.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsNativeMessageBox.cs",
    "LumaChart.Avalonia\Program.cs",
    "LumaChart.Avalonia.Specs\WindowsDiagnosticLogSpecs.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "tools\Capture-WindowsAvaloniaDiagnosticFatalGui.ps1",
    "tools\New-WindowsAvaloniaDiagnosticLoggingSliceEvidence.ps1")
$sourceEvidence = @(
    $sourceFiles |
    ForEach-Object { File-Evidence (Join-Path $projectRoot $_) })

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.diagnostic-logging-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    platform = "Windows Avalonia only"
    buildMode = "ordinary .NET Release"
    formalRoot = $formalRoot
    results = [ordered]@{
        avaloniaStrictBuildWarnings = 0
        avaloniaStrictBuildErrors = 0
        avaloniaSpecsStrictBuildWarnings = 0
        avaloniaSpecsStrictBuildErrors = 0
        mainSpecsStrictBuildWarnings = 0
        mainSpecsStrictBuildErrors = 0
        onlineGuiServerStrictBuildWarnings = 0
        onlineGuiServerStrictBuildErrors = 0
        avaloniaSpecsPassed = 492
        avaloniaSpecsTotal = 492
        mainSpecsPassed = 79
        mainSpecsTotal = 79
        diagnosticFiles = 1
        diagnosticRecords = 4
        fatalRecords = 1
        fatalDialogClass = "#32770"
        fatalDialogOwnerDisabled = $true
        fatalDialogLastActivePopup = $true
        fatalDialogPersistentTopmost = $false
        controlledFaultProcessExitCode = 1
        controlledSecretsRedacted = $true
        maximumDiagnosticFiles = 8
        maximumDiagnosticFileBytes = 1048576
        guiAutomationCaptureScripts = 30
        guiAutomationHelperSources = 3
        physicalInputClaimed = $false
        win32InputInjectionUsed = $false
        enterKeySent = $false
        productionServerDeployed = $false
        mobileProjectsTouched = $false
        protectionOrAotUsed = $false
        releaseInstallerOverwritten = $false
        windowsAvaloniaCanReplaceWpf = $false
        userManualReplacementApprovalReceived = $false
    }
    immutable = [ordered]@{
        realMc = $realMc
        frozenWpfInstaller = $installer
    }
    files = [ordered]@{
        guiEvidence = File-Evidence $guiPath
        diagnosticJsonl = $diagnosticEvidence
        screenshot = $screenshotEvidence
        avaloniaSpecsEvidence = File-Evidence $avaloniaSpecsPath
        avaloniaSpecsRun = File-Evidence (
            Join-Path $formalRoot "tests\avalonia-specs-run.log")
        mainSpecsRun = File-Evidence $mainSpecsLogPath
        diagnosticGuiRun = File-Evidence (
            Join-Path $formalRoot "tests\diagnostic-fatal-gui-run.log")
        guiAutomationSafety = File-Evidence $automationSafetyPath
        builds = $builds
        sourceAndTools = $sourceEvidence
    }
}

$outputPath = Join-Path $formalRoot "verification-evidence.json"
$verification | ConvertTo-Json -Depth 14 |
    Set-Content -LiteralPath $outputPath -Encoding utf8NoBOM
$verification | ConvertTo-Json -Depth 14
