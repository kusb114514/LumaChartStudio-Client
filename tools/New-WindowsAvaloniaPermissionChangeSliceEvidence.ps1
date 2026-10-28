param(
    [string]$Root =
        "artifacts\windows-avalonia-permission-change-slice-20260727-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedPermissionUpdateScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedRoleUpdateScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia permission-change verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-permission-change-slice-20260727-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal permission-change root must be exactly $expectedRoot"
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

Assert ($ExpectedPermissionUpdateScreenshotSha256 -match '^[0-9A-Fa-f]{64}$') (
    "Permission-update screenshot SHA-256 is invalid.")
Assert ($ExpectedRoleUpdateScreenshotSha256 -match '^[0-9A-Fa-f]{64}$') (
    "Role-update screenshot SHA-256 is invalid.")
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
$focusedNames = @(
    "room-access-change-normalizes-role-and-suppresses-unchanged-state",
    "room-access-permission-update-copy-matches-wpf-110",
    "room-access-role-change-copy-matches-wpf-110")
$focusedChecks = @($checks | Where-Object { $_.name -in $focusedNames })
Assert ($specs.status -eq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 434 -and $passedChecks.Count -eq 434) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
Assert ($focusedChecks.Count -eq 3 -and @($focusedChecks | Where-Object {
    -not $_.passed
}).Count -eq 0) "Dynamic permission focused Specs did not all pass."

$mainLogPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainText = Get-Content -Raw -LiteralPath $mainLogPath
Assert ($mainText -match "79/79 specs passed") "Main Specs did not pass 79/79."

$guiPath = Join-Path $formalRoot "gui\evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -eq (
    "lumachart.windows.avalonia.room-permission-change-gui-evidence.v1")) (
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
Assert (@($gui.physicalActions).Count -eq 20) "Expected exactly 20 physical actions."

$permission = $gui.permissionChanges
Assert ($permission.initialBindingNoticeSuppressed -eq $true) (
    "Initial room binding displayed a false access-change notice.")
Assert ($permission.permissionUpdateTitle -ceq "房间权限已更新") (
    "Permission-update title differs from WPF.")
Assert ($permission.permissionUpdateMessage -ceq (
    "谱面信息：不可编辑`nEffect / Timing Edit：不可编辑`nNote：不可编辑")) (
    "Permission-update body differs from WPF.")
Assert ($permission.noteToolDisabledAfterPermissionUpdate -eq $true) (
    "Note tool remained enabled after permission removal.")
Assert ($permission.roleUpdateTitle -ceq "房间身份已修改") (
    "Role-update title differs from WPF.")
Assert ($permission.roleUpdateMessage -ceq (
    "你的身份已被修改为观察者。`n`n观察者只能浏览、播放与选择，不能修改谱面。")) (
    "Role-update body differs from WPF.")
Assert ($permission.finalRole -ceq "viewer") "Final member role is not viewer."
Assert ($permission.selectToolEnabledAsViewer -eq $true -and
    $permission.tapToolDisabledAsViewer -eq $true) (
    "Viewer tool availability differs from WPF.")
Assert ($permission.acceptedOperationCountBefore -eq 0 -and
    $permission.acceptedOperationCountAfter -eq 0) (
    "Access changes mutated chart operations.")
Assert ($permission.serverChartEqualBeforeAfter -eq $true -and
    $permission.passed -eq $true) (
    "Access changes mutated the authoritative chart or aggregate failed.")

$finalMember = @($gui.room.finalServerState.members | Where-Object {
    [long]$_.userId -eq 4202
})[0]
Assert ($finalMember -and $finalMember.memberRole -ceq "viewer" -and
    -not $finalMember.canEditMetadata -and
    -not $finalMember.canEditTiming -and
    -not $finalMember.canEditNotes) (
    "Server did not persist the final viewer access.")
Assert ($gui.room.finalServerState.resourceEntryCount -eq 3 -and
    $gui.room.finalServerState.downloadedBlobCount -ge 3) (
    "Room resources were not fully synchronized.")

$screenshotEvidence = @()
$screenshotProperties = @($gui.screenshots.PSObject.Properties)
Assert ($screenshotProperties.Count -eq 14) (
    "Expected 14 declared GUI screenshots, got $($screenshotProperties.Count).")
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

$permissionShot = $screenshotEvidence | Where-Object {
    $_.name -eq "member-note-permission-updated"
}
$roleShot = $screenshotEvidence | Where-Object {
    $_.name -eq "member-role-changed-to-viewer"
}
Assert ($permissionShot.file.sha256 -ceq
    $ExpectedPermissionUpdateScreenshotSha256.ToUpperInvariant()) (
    "Formal permission-update screenshot hash changed.")
Assert ($roleShot.file.sha256 -ceq
    $ExpectedRoleUpdateScreenshotSha256.ToUpperInvariant()) (
    "Formal role-update screenshot hash changed.")

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
        "artifacts\windows-avalonia-permission-notice-slice-20260727-r3\" +
        "verification-evidence.json"))
Assert ($predecessor.sha256 -ceq (
    "88FC31CE683F448EABB257B8ADF80E08A67B55A38375330995B7C4A385682164")) (
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
    schema = "lumachart.windows.avalonia.permission-change-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        windowsAvaloniaOnly = $true
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        formalAuthority = "permission-change-r1"
    }
    builds = [ordered]@{
        warnings = 0
        errors = 0
        logs = $builds
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 434
            total = 434
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
        cleanFormalRerun = $true
        initialBindingNoticeSuppressed = $true
        permissionUpdatePassed = $true
        roleUpdatePassed = $true
        physicalActionCount = 20
        screenshotCount = 14
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
            "LumaChart.Avalonia\MainWindow.cs",
            "LumaChart.Avalonia.Specs\WindowsRoomPermissionNoticeSpecs.cs",
            "tools\Capture-WindowsAvaloniaTwoClientOnlineGui.ps1",
            "tools\New-WindowsAvaloniaPermissionChangeSliceEvidence.ps1")
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
