param(
    [string]$Root =
        "artifacts\windows-avalonia-online-resource-concurrency-slice-20260729-r3",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedInterruptedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedHashRejectedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedCacheRepairedScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia online-resource verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-online-resource-concurrency-slice-20260729-r3"))).
    TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal online-resource root must be exactly $expectedRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "Missing file: $full"
    $item = Get-Item -LiteralPath $full
    [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $full)
        bytes = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -Raw -LiteralPath $Path
    Assert ($text -match "0 个警告") "Strict build lacks zero warnings: $Path"
    Assert ($text -match "0 个错误") "Strict build lacks zero errors: $Path"
    File-Evidence $Path
}

foreach ($hash in @(
        $ExpectedInterruptedScreenshotSha256,
        $ExpectedHashRejectedScreenshotSha256,
        $ExpectedCacheRepairedScreenshotSha256)) {
    Assert ($hash -match '^[0-9A-Fa-f]{64}$') "Invalid screenshot SHA-256: $hash"
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$strictBuilds = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-release-warnaserror.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-specs-release-warnaserror.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\main-specs-release-warnaserror.log")
    loopbackGuiServer = Assert-StrictBuild (
        Join-Path $formalRoot "build\online-gui-server-release-warnaserror.log")
}

$avaloniaSpecsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$avaloniaSpecs = Get-Content -Raw -LiteralPath $avaloniaSpecsPath |
    ConvertFrom-Json
$avaloniaChecks = @($avaloniaSpecs.checks)
$avaloniaPassed = @($avaloniaChecks | Where-Object { $_.passed })
$resourceCheck = @($avaloniaChecks | Where-Object {
        $_.name -ceq (
            "windows-room-resource-real-http-interruption-concurrency-atomic-repair")
    })
Assert ($avaloniaSpecs.status -ceq "passed") "Avalonia Specs status is not passed."
Assert ($avaloniaChecks.Count -eq 541 -and $avaloniaPassed.Count -eq 541) (
    "Avalonia Specs count mismatch: $($avaloniaPassed.Count)/$($avaloniaChecks.Count)")
Assert ($resourceCheck.Count -eq 1 -and $resourceCheck[0].passed) (
    "Online-resource concurrency/resilience check did not pass.")
$resourceDetail = [string]$resourceCheck[0].detail
foreach ($requiredDetail in @(
        "concurrent duplicate joins",
        "same-hash cross-name content",
        "occupied invalid cache",
        "same-name replacement",
        "real MC reopen passed")) {
    Assert ($resourceDetail.Contains($requiredDetail, [StringComparison]::Ordinal)) (
        "Online-resource check detail lacks '$requiredDetail'.")
}

$mainSpecsPath = Join-Path $formalRoot "tests\main-specs.log"
$mainSpecsText = Get-Content -Raw -LiteralPath $mainSpecsPath
Assert ($mainSpecsText -match "79/79 specs passed") "Main Specs did not pass 79/79."

$guiPath = Join-Path $formalRoot "gui\evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -ceq (
    "lumachart.windows.avalonia.two-client-resource-resilience-gui-evidence.v1")) (
    "Unexpected GUI evidence schema: $($gui.schema)")
Assert ($gui.status -ceq "passed") "GUI evidence status is not passed."
Assert ($gui.formalMigrationAuthority -eq $true) "GUI run is not formal authority."
Assert ($gui.windowsAvaloniaOnly -eq $true) "GUI evidence is not Windows-only."
Assert ($gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false) (
    "GUI evidence touched a mobile project.")
Assert ($gui.productionServerMutationPerformed -eq $false) (
    "GUI evidence mutated the production server.")
Assert ($gui.pureDotnetRelease -eq $true) "GUI evidence is not pure .NET Release."
Assert ($gui.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "GUI evidence used a prohibited protection or AOT mode.")
Assert ($gui.resourceResilienceOnly -eq $true) (
    "GUI evidence is not the focused resource-resilience flow.")
Assert ($gui.physicalMouseInputUsed -eq $true) "GUI evidence did not use physical mouse input."
Assert ($gui.recovery.passed -eq $true) "GUI resource recovery did not pass."
Assert ($gui.recovery.noPartFiles -eq $true) "GUI resource recovery left .part files."
Assert ([int]$gui.recovery.disconnect.state.injectedDisconnectedResourceDownloadCount -eq 1) (
    "GUI did not inject exactly one disconnected resource response.")
Assert ([int]$gui.recovery.corruptResponse.state.injectedCorruptedResourceDownloadCount -eq 1) (
    "GUI did not inject exactly one same-length corrupt response.")
Assert ([string]$gui.recovery.sameLengthCacheTamper.expectedSha256 -ceq
        [string]$gui.recovery.sameLengthCacheTamper.repairedSha256) (
    "GUI same-length cache tamper was not repaired to the exact expected SHA-256.")
Assert ([string]$gui.recovery.sameLengthCacheTamper.tamperedSha256 -cne
        [string]$gui.recovery.sameLengthCacheTamper.repairedSha256) (
    "GUI cache-tamper fixture did not differ from the repaired SHA-256.")
Assert ($gui.recovery.materializedChartExists -eq $true) (
    "GUI recovery did not leave a materialized real MC.")
Assert (@($gui.recovery.physicalActions).Count -ge 4) (
    "GUI resource flow recorded too few physical actions.")

$screenshotExpectations = [ordered]@{
    "member-resource-download-interrupted" =
        $ExpectedInterruptedScreenshotSha256.ToUpperInvariant()
    "member-resource-sha256-rejected" =
        $ExpectedHashRejectedScreenshotSha256.ToUpperInvariant()
    "member-resource-cache-repaired" =
        $ExpectedCacheRepairedScreenshotSha256.ToUpperInvariant()
}
$screenshotEvidence = [ordered]@{}
foreach ($name in $screenshotExpectations.Keys) {
    $path = Join-Path $formalRoot "gui\$name.png"
    $file = File-Evidence $path
    Assert ($file.sha256 -ceq $screenshotExpectations[$name]) (
        "Screenshot SHA-256 mismatch for $name.")
    $screenshotEvidence[$name] = $file
}
$allScreenshots = @(Get-ChildItem -LiteralPath (Join-Path $formalRoot "gui") `
        -File -Filter "*.png")
Assert ($allScreenshots.Count -eq 7) (
    "Expected 7 GUI screenshots, found $($allScreenshots.Count).")

$fixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc"
$fixture = File-Evidence $fixturePath
Assert ($fixture.sha256 -ceq (
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E")) (
    "The immutable Resound MC fixture changed.")
$installer = File-Evidence (Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert ($installer.sha256 -ceq (
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4")) (
    "The frozen WPF installer changed.")

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.online-resource-concurrency-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed"
    scope = "windows-avalonia-online-resource-concurrency-and-recovery"
    formalMigrationAuthority = $true
    completion = $false
    migrationComplete = $false
    windowsAvaloniaOnly = $true
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    productionServerMutationPerformed = $false
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    priorityPolicy = "main-functions-first-ui-focus-ime-shortcuts-dialog-layer-last"
    strictBuilds = $strictBuilds
    avaloniaSpecs = [ordered]@{
        status = $avaloniaSpecs.status
        passed = $avaloniaPassed.Count
        total = $avaloniaChecks.Count
        failed = $avaloniaChecks.Count - $avaloniaPassed.Count
        evidence = File-Evidence $avaloniaSpecsPath
        log = File-Evidence (Join-Path $formalRoot "tests\avalonia-specs.log")
        onlineResourceCheck = [ordered]@{
            name = [string]$resourceCheck[0].name
            passed = [bool]$resourceCheck[0].passed
            detail = $resourceDetail
        }
    }
    mainSpecs = [ordered]@{
        status = "passed"
        passed = 79
        total = 79
        log = File-Evidence $mainSpecsPath
    }
    physicalGui = [ordered]@{
        status = $gui.status
        evidence = File-Evidence $guiPath
        physicalMouseInputUsed = [bool]$gui.physicalMouseInputUsed
        injectedDisconnects =
            [int]$gui.recovery.disconnect.state.injectedDisconnectedResourceDownloadCount
        injectedCorruptResponses =
            [int]$gui.recovery.corruptResponse.state.injectedCorruptedResourceDownloadCount
        sameLengthCacheTamperRecovered = $true
        temporaryPartFilesRemaining = 0
        physicalActionCount = @($gui.recovery.physicalActions).Count
        screenshotCount = $allScreenshots.Count
        screenshots = $screenshotEvidence
    }
    immutableInputs = [ordered]@{
        resoundMc = $fixture
        releasedWpfInstaller = $installer
    }
    knownRemainingDifferences = @(
        "disk-full recovery still requires a deterministic constrained-volume or injectable filesystem gate",
        "cross-process shared-cache contention is not enabled because each Windows client uses its own local-data root",
        "pixel UI, focus, Chinese IME, shortcuts and external-game dialog layering are intentionally deferred until main functions close"
    )
}

$json = $verification | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText(
    $verificationPath,
    $json + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false))
$written = File-Evidence $verificationPath
Write-Output "Online-resource verification evidence: $($written.path)"
Write-Output "Bytes: $($written.bytes)"
Write-Output "SHA-256: $($written.sha256)"
