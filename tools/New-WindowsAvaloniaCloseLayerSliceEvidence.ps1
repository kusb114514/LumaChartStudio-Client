param(
    [string]$Root =
        "artifacts\windows-avalonia-close-layer-recheck-20260728-r2",
    [string]$StrictGateRoot =
        "artifacts\windows-avalonia-library-launcher-slice-20260728-r3",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedGuiEvidenceSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedCancelScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedDiscardScreenshotSha256
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia close-layer verification requires PowerShell Core on Windows."
}

$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-close-layer-recheck-20260728-r2"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals(
        $expectedRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal close-layer root must be exactly $expectedRoot"
}
$expectedGateRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-library-launcher-slice-20260728-r3"))).TrimEnd('\')
$gateRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $StrictGateRoot)).TrimEnd('\')
if (-not $gateRoot.Equals(
        $expectedGateRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Close-layer strict gates must come from exactly $expectedGateRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-HashArgument([string]$Hash, [string]$Label) {
    Assert ($Hash -match '^[0-9A-Fa-f]{64}$') "$Label SHA-256 is invalid."
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "Missing file: $full"
    $item = Get-Item -LiteralPath $full
    [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $full)
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Read-Json([string]$Path) {
    Assert (Test-Path -LiteralPath $Path -PathType Leaf) "Missing JSON: $Path"
    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    Assert ($text -match "(0 个警告|0 Warning\(s\))") (
        "Strict build log lacks zero-warning result: $Path")
    Assert ($text -match "(0 个错误|0 Error\(s\))") (
        "Strict build log lacks zero-error result: $Path")
    Assert ($text -notmatch (
        "(?i)ollvm|obfuscat|virtuali[sz]ation|nativeaot|publish-aot")) (
        "Strict build log contains a forbidden protection or AOT marker: $Path")
    File-Evidence $Path
}

foreach ($hashArgument in @(
        @($ExpectedGuiEvidenceSha256, "GUI evidence"),
        @($ExpectedCancelScreenshotSha256, "Cancel screenshot"),
        @($ExpectedDiscardScreenshotSha256, "Discard screenshot"))) {
    Assert-HashArgument $hashArgument[0] $hashArgument[1]
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists: $verificationPath")

$guiRoot = Join-Path $formalRoot "close-layer-gui"
$guiEvidencePath = Join-Path $guiRoot "close-layer-gui-evidence.json"
$guiEvidenceFile = File-Evidence $guiEvidencePath
Assert ($guiEvidenceFile.sha256 -ceq
        $ExpectedGuiEvidenceSha256.ToUpperInvariant()) (
    "Close-layer GUI evidence differs from the reviewed file.")
$gui = Read-Json $guiEvidencePath
Assert ($gui.schema -ceq
        "lumachart.windows.avalonia.close-layer-gui-evidence.v1" -and
        $gui.status -ceq "passed-migration-incomplete" -and
        $gui.platform -ceq "Windows Avalonia only" -and
        [bool]$gui.windowsAvaloniaOnly -and
        -not [bool]$gui.mobileProjectsBuiltModifiedInstalledOrTested -and
        -not [bool]$gui.productionServerMutationPerformed -and
        [bool]$gui.pureDotnetRelease -and
        -not [bool]$gui.ollvmObfuscationPackingVirtualizationOrAotUsed -and
        -not [bool]$gui.migrationComplete) (
    "Close-layer GUI evidence did not pass the authorized Windows-only scope.")

Assert ([int]$gui.physicalInput.mouseButtonActionCount -eq 4 -and
        [int]$gui.physicalInput.keyboardActionCount -eq 3 -and
        -not [bool]$gui.physicalInput.uiAutomationInvokePatternUsedForBusinessActions -and
        -not [bool]$gui.physicalInput.hardwareInputClaimed) (
    "Close-layer input evidence is not the expected physical pointer/key path.")
Assert (-not [bool]$gui.zOrder.mainTopmostBeforeFullscreen -and
        -not [bool]$gui.zOrder.mainTopmostDuringFullscreen -and
        -not [bool]$gui.zOrder.mainTopmostAfterCanceledClose -and
        [bool]$gui.zOrder.ownerModalWithoutPersistentTopmost) (
    "Main window gained persistent topmost behavior.")
foreach ($dialog in @(
        $gui.zOrder.cancelDialog,
        $gui.zOrder.discardDialog)) {
    Assert ([long]$dialog.dialogHandle -ne 0 -and
            [long]$dialog.ownerHandle -ne 0 -and
            [long]$dialog.foregroundHandle -eq [long]$dialog.dialogHandle -and
            [long]$dialog.lastActivePopupHandle -eq [long]$dialog.dialogHandle -and
            -not [bool]$dialog.mainEnabled -and
            -not [bool]$dialog.mainTopmostStyle -and
            -not [bool]$dialog.dialogTopmostStyle -and
            [bool]$dialog.mainIsZoomed -and
            $dialog.dialogName -ceq "未保存的更改") (
        "Close confirmation is not a foreground owner-modal, non-topmost dialog.")
}
Assert ([bool]$gui.fullscreenClosePreflight.enteredFromMaximized -and
        [bool]$gui.fullscreenClosePreflight.firstDialogOwnerRestoredMaximized -and
        [bool]$gui.fullscreenClosePreflight.cancelRestoredFullscreen -and
        [bool]$gui.fullscreenClosePreflight.secondDialogOwnerRestoredMaximized) (
    "Fullscreen close preflight did not restore the expected owner states.")
$before = $gui.fullscreenClosePreflight.fullscreenBoundsBeforeCancel
$after = $gui.fullscreenClosePreflight.fullscreenBoundsAfterCancel
Assert ([int]$before.left -eq [int]$after.left -and
        [int]$before.top -eq [int]$after.top -and
        [int]$before.right -eq [int]$after.right -and
        [int]$before.bottom -eq [int]$after.bottom) (
    "Cancel did not restore the exact fullscreen bounds.")
Assert ([bool]$gui.process.exitedAfterDiscard -and
        [int]$gui.process.exitCode -eq 0) (
    "Discard did not close the client cleanly.")

$expectedChartHash =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$expectedInstallerHash =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
Assert ($gui.chart.sourceFixtureSha256Before -ceq $expectedChartHash -and
        $gui.chart.sourceFixtureSha256After -ceq $expectedChartHash -and
        $gui.chart.isolatedChartSha256Before -ceq $expectedChartHash -and
        $gui.chart.isolatedChartSha256After -ceq $expectedChartHash -and
        [bool]$gui.chart.discardLeftSourceUnchanged) (
    "Close/discard GUI changed the real or isolated MC source.")
Assert ($gui.installer.sha256Before -ceq $expectedInstallerHash -and
        $gui.installer.sha256After -ceq $expectedInstallerHash) (
    "Frozen WPF installer changed.")

$cancelScreenshotPath = Join-Path $guiRoot (
    "fullscreen-close-cancel-dialog.png")
$cancelScreenshot = File-Evidence $cancelScreenshotPath
Assert ($cancelScreenshot.sha256 -ceq
        $ExpectedCancelScreenshotSha256.ToUpperInvariant() -and
        $cancelScreenshot.sha256 -ceq $gui.screenshots.cancel.sha256 -and
        [int]$gui.screenshots.cancel.width -eq 2560 -and
        [int]$gui.screenshots.cancel.height -eq 1528 -and
        [int]$gui.screenshots.cancel.sampledUniqueColors -ge 20) (
    "Cancel-dialog screenshot differs from the visually reviewed image.")
$discardScreenshotPath = Join-Path $guiRoot (
    "fullscreen-close-discard-dialog.png")
$discardScreenshot = File-Evidence $discardScreenshotPath
Assert ($discardScreenshot.sha256 -ceq
        $ExpectedDiscardScreenshotSha256.ToUpperInvariant() -and
        $discardScreenshot.sha256 -ceq $gui.screenshots.discard.sha256 -and
        [int]$gui.screenshots.discard.width -eq 2560 -and
        [int]$gui.screenshots.discard.height -eq 1528 -and
        [int]$gui.screenshots.discard.sampledUniqueColors -ge 20) (
    "Discard-dialog screenshot differs from the visually reviewed image.")

$safetyPath = Join-Path $formalRoot "gui-automation-safety.json"
$safety = Read-Json $safetyPath
Assert ($safety.schema -ceq
        "lumachart.windows.avalonia.gui-automation-safety.v1" -and
        $safety.status -ceq "passed" -and
        [bool]$safety.windowsAvaloniaOnly -and
        [bool]$safety.foregroundAutomationRequiresExplicitUserConsent -and
        [int]$safety.minimumSystemIdleMilliseconds -ge 3000 -and
        [bool]$safety.heldModifierGateRequired -and
        -not [bool]$safety.persistentTopmostUsed) (
    "Close-layer GUI automation safety boundaries drifted.")
Assert (@($safety.scripts | Where-Object {
            $_.path -match "Capture-WindowsAvaloniaCloseLayerGui\.ps1$"
        }).Count -eq 1) (
    "Close-layer capture is absent from its safety scan.")

$gateBuildRoot = Join-Path $gateRoot "build"
$gateBuilds = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $gateBuildRoot "build-avalonia.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $gateBuildRoot "build-avalonia_specs.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $gateBuildRoot "build-main_specs.log")
    onlineGuiServer = Assert-StrictBuild (
        Join-Path $gateBuildRoot "build-loopback_gui_server.log")
}
$gateTestsRoot = Join-Path $gateRoot "tests"
$avaloniaSpecsPath = Join-Path $gateTestsRoot "avalonia-specs-evidence.json"
$avaloniaSpecs = Read-Json $avaloniaSpecsPath
Assert ($avaloniaSpecs.Status -ceq "passed" -and
        @($avaloniaSpecs.Checks).Count -eq 503 -and
        @($avaloniaSpecs.Checks | Where-Object {
            -not [bool]$_.Passed
        }).Count -eq 0) (
    "Latest strict Avalonia Specs gate is not 503/503.")
$mainSpecsPath = Join-Path $gateTestsRoot "main-specs.log"
$mainSpecsText = Get-Content -LiteralPath $mainSpecsPath -Raw -Encoding UTF8
Assert ($mainSpecsText -match "79/79 specs passed\.") (
    "Latest strict main Specs gate is not 79/79.")

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.close-layer-slice-verification.v1"
    status = "passed-migration-incomplete"
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    platform = "Windows Avalonia only"
    windowsAvaloniaOnly = $true
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    productionServerMutationPerformed = $false
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    migrationComplete = $false
    guiEvidence = $guiEvidenceFile
    screenshots = [ordered]@{
        cancel = $cancelScreenshot
        discard = $discardScreenshot
    }
    guiAutomationSafety = File-Evidence $safetyPath
    behavior = [ordered]@{
        mainWindowPersistentTopmost = $false
        ownerModalDialogPersistentTopmost = $false
        fullscreenClosePreflightExitsFullscreenBeforeDialog = $true
        cancelRestoresFullscreen = $true
        discardClosesClient = $true
    }
    strictGateAuthority = [ordered]@{
        root = [IO.Path]::GetRelativePath($projectRoot, $gateRoot)
        builds = $gateBuilds
        avaloniaSpecs = File-Evidence $avaloniaSpecsPath
        avaloniaSpecsPassed = 503
        avaloniaSpecsFailed = 0
        mainSpecs = File-Evidence $mainSpecsPath
        mainSpecsPassed = 79
        mainSpecsFailed = 0
    }
    frozenChartSha256 = $expectedChartHash
    frozenInstallerSha256 = $expectedInstallerHash
}
[IO.File]::WriteAllText(
    $verificationPath,
    ($verification | ConvertTo-Json -Depth 18),
    [Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    status = $verification.status
    verificationPath = $verificationPath
    verificationSha256 = (
        Get-FileHash -LiteralPath $verificationPath -Algorithm SHA256).Hash
    guiEvidenceSha256 = $guiEvidenceFile.sha256
    cancelScreenshotSha256 = $cancelScreenshot.sha256
    discardScreenshotSha256 = $discardScreenshot.sha256
    strictAvaloniaSpecs = "503/503"
    strictMainSpecs = "79/79"
}
