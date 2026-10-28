param(
    [string]$Root =
        "artifacts\windows-avalonia-permission-notice-slice-20260727-r3"
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia permission-notice verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-permission-notice-slice-20260727-r3"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal permission-notice root must be exactly $expectedRoot"
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
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -Raw -LiteralPath $Path
    Assert ($text -match "0 个警告") "Strict build log lacks zero-warning result: $Path"
    Assert ($text -match "0 个错误") "Strict build log lacks zero-error result: $Path"
    File-Evidence $Path
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$builds = [ordered]@{
    avalonia = Assert-StrictBuild (Join-Path $formalRoot "build\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (Join-Path $formalRoot "build\main-specs-build.log")
    loopbackServer = Assert-StrictBuild (
        Join-Path $formalRoot "build\loopback-server-build.log")
}

$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs = Get-Content -Raw -LiteralPath $specsPath | ConvertFrom-Json
$checks = @($specs.checks)
$passedChecks = @($checks | Where-Object { $_.passed })
$focusedChecks = @($checks | Where-Object {
    $_.name -in @(
        "room-permission-notice-geometry-and-colors-match-wpf-110",
        "room-permission-notice-copy-matches-wpf-110")
})
Assert ($specs.status -eq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 431 -and $passedChecks.Count -eq 431) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
Assert ($focusedChecks.Count -eq 2 -and @($focusedChecks | Where-Object {
    -not $_.passed
}).Count -eq 0) "Permission notice focused specs did not both pass."

$mainLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainText = Get-Content -Raw -LiteralPath $mainLogPath
Assert ($mainText -match "79/79 specs passed") "Main Specs did not pass 79/79."

$guiPath = Join-Path $formalRoot "gui\evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -eq (
    "lumachart.windows.avalonia.hidden-private-observer-gui-evidence.v1")) (
    "Unexpected GUI schema: $($gui.schema)")
Assert ($gui.status -eq "passed") "GUI evidence status is not passed."
Assert ($gui.windowsAvaloniaOnly -eq $true) "GUI evidence is not Windows-only."
Assert ($gui.productionServerMutationPerformed -eq $false) (
    "GUI evidence mutated production Server.")
Assert ($gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false) (
    "GUI evidence touched mobile projects.")
Assert ($gui.pureDotnetRelease -eq $true) "GUI evidence is not ordinary Release."
Assert ($gui.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "GUI evidence used forbidden protection/AOT.")
Assert ($gui.physicalMouseInputUsed -eq $true) "Physical mouse input was not used."
Assert ($gui.automationDiagnosticNonFormal -eq $false) (
    "Automation diagnostic output cannot be formal authority.")
Assert (@($gui.physicalActions).Count -eq 23) (
    "Expected exactly 23 physical actions.")

Assert ($gui.controls.observerPermissionNotice.name -ceq (
    "没有编辑权限：无编辑 Note 的权限，请向房主索要。")) (
    "Permission notice accessible name differs from WPF.")
Assert ($gui.controls.observerPermissionTitle.name -ceq "没有编辑权限") (
    "Permission notice title differs from WPF.")
Assert ($gui.controls.observerPermissionMessage.name -ceq (
    "无编辑 Note 的权限，请向房主索要。")) (
    "Permission notice message differs from WPF.")
Assert ($gui.controls.observerPermissionDismiss.name -ceq "知道了") (
    "Permission notice dismiss label differs from WPF.")
Assert ($gui.controls.observerPermissionDismiss.isEnabled -eq $true) (
    "Permission notice dismiss button was disabled.")

Assert ($gui.observerReadOnly.memberRole -eq "viewer") (
    "Permission notice was not exercised by a viewer.")
Assert ($gui.observerReadOnly.operationCountBefore -eq 0 -and
    $gui.observerReadOnly.operationCountAfter -eq 0) (
    "Observer permission attempts changed Server operation count.")
Assert ($gui.observerReadOnly.serverChartEqualBeforeAfter -eq $true) (
    "Observer permission attempts changed the authoritative chart.")
Assert ($gui.observerReadOnly.passed -eq $true) (
    "Observer read-only aggregate did not pass.")
Assert (@($gui.room.activeMemberIds).Count -eq 2 -and
    $gui.room.activeMemberIds -contains 4101 -and
    $gui.room.activeMemberIds -contains 4202) (
    "Expected owner/member active seats are missing.")
Assert ($gui.room.finalServerState.resourceEntryCount -eq 3 -and
    $gui.room.finalServerState.downloadedBlobCount -ge 3) (
    "Room resources were not fully synchronized.")

$screenshotEvidence = @()
$screenshotProperties = @($gui.screenshots.PSObject.Properties)
Assert ($screenshotProperties.Count -eq 17) (
    "Expected 17 declared GUI screenshots, got $($screenshotProperties.Count).")
foreach ($property in $screenshotProperties) {
    $declared = $property.Value
    $full = [IO.Path]::GetFullPath([string]$declared.path)
    Assert ($full.StartsWith(
        (Join-Path $formalRoot "gui") + '\',
        [StringComparison]::OrdinalIgnoreCase)) (
        "Screenshot escaped formal GUI root: $full")
    $actual = File-Evidence $full
    Assert ($actual.length -eq [long]$declared.length) (
        "Screenshot length mismatch: $full")
    Assert ($actual.sha256 -ceq [string]$declared.sha256) (
        "Screenshot hash mismatch: $full")
    $screenshotEvidence += [ordered]@{
        name = $property.Name
        file = $actual
    }
}

$noticeShot = $screenshotEvidence | Where-Object {
    $_.name -eq "member-observer-permission-notice"
}
Assert ($noticeShot.file.sha256 -ceq (
    "7377761A2ED9BC7F88E4D1C39D6E142740C4341481E2245488EA72B61A6EA315")) (
    "Formal permission notice screenshot hash changed.")

$fixture = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
Assert ($fixture.sha256 -ceq (
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E")) (
    "Frozen real MC hash changed.")
$installer = File-Evidence (Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert ($installer.sha256 -ceq (
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4")) (
    "Frozen installer hash changed.")
$predecessor = File-Evidence (
    Join-Path $projectRoot (
        "artifacts\windows-avalonia-avatar-latency-slice-20260727-r1\" +
        "verification-evidence.json"))
Assert ($predecessor.sha256 -ceq (
    "09524E329C43AF1CA0F8056463170C0A4CCE348D7FA02FFE2AC842ADB58D6774")) (
    "Predecessor authority hash changed.")

$leftovers = @()
foreach ($processId in @(
    [int]$gui.processIds.server,
    [int]$gui.processIds.owner,
    [int]$gui.processIds.member)) {
    if (Get-Process -Id $processId -ErrorAction SilentlyContinue) {
        $leftovers += $processId
    }
}
Assert ($leftovers.Count -eq 0) "Evidence-owned processes remain: $leftovers"

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.permission-notice-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        windowsAvaloniaOnly = $true
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        formalAuthority = "permission-notice-r3"
        abortedRootsExcluded = @(
            "windows-avalonia-permission-notice-slice-20260727-r1",
            "windows-avalonia-permission-notice-slice-20260727-r2")
    }
    builds = [ordered]@{
        warnings = 0
        errors = 0
        logs = $builds
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 431
            total = 431
            failed = 0
            focusedChecks = $focusedChecks
            evidence = File-Evidence $specsPath
            log = File-Evidence (Join-Path $formalRoot "tests\avalonia-specs-run.log")
        }
        mainSpecs = [ordered]@{
            passed = 79
            total = 79
            failed = 0
            log = File-Evidence $mainLogPath
        }
    }
    gui = [ordered]@{
        cleanRerunAfterUserMouseClarification = $true
        permissionNoticePassed = $true
        physicalActionCount = 23
        screenshotCount = 17
        serverOperationCountBefore = 0
        serverOperationCountAfter = 0
        authoritativeChartUnchanged = $true
        manualVisualReviewPassed = $true
        evidence = File-Evidence $guiPath
        screenshots = $screenshotEvidence
        leftoverEvidenceOwnedProcessIds = $leftovers
    }
    source = [ordered]@{
        changedFiles = @(
            "LumaChart.Avalonia\Infrastructure\WindowsRoomPermissionNoticePolicy.cs",
            "LumaChart.Avalonia\Controls\TimelineSurface.cs",
            "LumaChart.Avalonia\MainWindow.cs",
            "LumaChart.Avalonia.Specs\WindowsRoomPermissionNoticeSpecs.cs",
            "LumaChart.Avalonia.Specs\Program.cs",
            "tools\Capture-WindowsAvaloniaTwoClientOnlineGui.ps1",
            "tools\New-WindowsAvaloniaPermissionNoticeSliceEvidence.ps1")
    }
    frozenBaselines = [ordered]@{
        realChart = $fixture
        installer = $installer
        predecessor = $predecessor
    }
    completion = [ordered]@{
        thisSlicePassed = $true
        fullWindowsMigrationComplete = $false
        userReplacementApproval = $false
        otherPlatformAuthorization = $false
    }
}
$verification | ConvertTo-Json -Depth 30 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
File-Evidence $verificationPath | ConvertTo-Json -Depth 6
