param(
    [string]$Root = "artifacts\windows-avalonia-online-surface-slice-20260727-r1",
    [switch]$RoomPasswordScenario,
    [switch]$CorrectPasswordJoinScenario,
    [switch]$InvitationToastScenario
)

$ErrorActionPreference = "Stop"
if (([int][bool]$RoomPasswordScenario +
        [int][bool]$CorrectPasswordJoinScenario +
        [int][bool]$InvitationToastScenario) -gt 1) {
    throw "Choose only one focused online-surface verification scenario."
}
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root))
if (-not (Test-Path -LiteralPath $formalRoot -PathType Container)) {
    throw "Formal online-surface root not found: $formalRoot"
}
$verificationPath = Join-Path $formalRoot "verification-evidence.json"
if (Test-Path -LiteralPath $verificationPath) {
    throw "Verification evidence already exists: $verificationPath"
}

function Relative-Path([string]$Path) {
    return [IO.Path]::GetRelativePath(
        $projectRoot,
        [IO.Path]::GetFullPath($Path)).Replace("/", "\")
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "Required evidence file not found: $full"
    }
    $item = Get-Item -LiteralPath $full
    return [ordered]@{
        path = Relative-Path $full
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Assert-BuildLog([string]$Path) {
    $text = Get-Content -Raw -LiteralPath $Path
    if ($text -notmatch "0 个警告" -or $text -notmatch "0 个错误") {
        throw "Strict build log does not report zero warnings/errors: $Path"
    }
    return File-Evidence $Path
}

$buildPaths = [ordered]@{
    avalonia = Join-Path $formalRoot "build\avalonia.log"
    avaloniaSpecs = Join-Path $formalRoot "build\avalonia-specs.log"
    mainSpecs = Join-Path $formalRoot "build\main-specs.log"
    onlineGuiServer = Join-Path $formalRoot "build\online-gui-server.log"
}
if ($CorrectPasswordJoinScenario) {
    $buildPaths.keyboardImeProbe =
        Join-Path $formalRoot "build\keyboard-ime-probe.log"
}
$builds = [ordered]@{}
foreach ($entry in $buildPaths.GetEnumerator()) {
    $builds[$entry.Key] = Assert-BuildLog $entry.Value
}

$avaloniaSpecsPath = Join-Path $formalRoot "specs\avalonia-specs-evidence.json"
$avaloniaSpecs = Get-Content -Raw -LiteralPath $avaloniaSpecsPath | ConvertFrom-Json
$expectedAvaloniaSpecCount =
    if ($InvitationToastScenario) { 424 }
    elseif ($RoomPasswordScenario -or $CorrectPasswordJoinScenario) { 423 }
    else { 421 }
if ($avaloniaSpecs.status -ne "passed" -or
    @($avaloniaSpecs.checks).Count -ne $expectedAvaloniaSpecCount) {
    throw "Avalonia Specs are not $expectedAvaloniaSpecCount/$expectedAvaloniaSpecCount passed."
}
$onlineChecks = @($avaloniaSpecs.checks | Where-Object {
    $_.name -like "online-shell-*"
})
if ($onlineChecks.Count -ne 3 -or @($onlineChecks | Where-Object {
    -not $_.passed
}).Count -ne 0) {
    throw "Online-surface parity checks are not 3/3 passed."
}

$mainSpecsPath = Join-Path $formalRoot "specs\main-specs.log"
$mainPasses = @(Select-String -LiteralPath $mainSpecsPath -Pattern "^PASS ").Count
$mainFailures = @(Select-String -LiteralPath $mainSpecsPath -Pattern "^FAIL ").Count
if ($mainPasses -ne 79 -or $mainFailures -ne 0) {
    throw "Main Specs are not 79/79 passed."
}

if ($InvitationToastScenario) {
    $invitationChecks = @($avaloniaSpecs.checks | Where-Object {
        $_.name -eq "online-invitation-toast-geometry-matches-wpf-110"
    })
    if ($invitationChecks.Count -ne 1 -or
        @($invitationChecks | Where-Object { -not $_.passed }).Count -ne 0) {
        throw "Invitation-toast parity check is not 1/1 passed."
    }

    $guiEvidencePath = Join-Path $formalRoot "gui\evidence.json"
    $gui = Get-Content -Raw -LiteralPath $guiEvidencePath | ConvertFrom-Json
    $activeMemberIds = @($gui.room.activeMemberIds)
    $geometry = $gui.invitation.wpfToastGeometry
    if ($gui.schema -ne
            "lumachart.windows.avalonia.hidden-private-invitation-gui-evidence.v1" -or
        $gui.status -ne "passed" -or
        -not $gui.windowsAvaloniaOnly -or
        $gui.productionServerMutationPerformed -or
        $gui.mobileProjectsBuiltModifiedInstalledOrTested -or
        -not $gui.pureDotnetRelease -or
        $gui.ollvmObfuscationPackingVirtualizationOrAotUsed -or
        -not $gui.physicalMouseInputUsed -or
        $gui.automationDiagnosticNonFormal -or
        [int]@($gui.physicalActions).Count -ne 10 -or
        $gui.invitation.action -ne "join" -or
        [int]$gui.invitation.joinCount -ne 1 -or
        [int]$gui.invitation.memberNormalJoinRequestCount -ne 0 -or
        [int]$gui.invitation.memberJoinPasswordSubmissionCount -ne 0 -or
        -not $gui.invitation.passwordAbsentFromMemberUiAutomation -or
        -not $geometry.passed -or
        [double]$geometry.toast.width -ne [double]$geometry.toast.expectedWidth -or
        [double]$geometry.toast.topOffset -ne [double]$geometry.toast.expectedTopOffset -or
        [double]$geometry.toast.rightInset -ne [double]$geometry.toast.expectedRightInset -or
        [double]$geometry.buttons.cancelHeight -ne [double]$geometry.buttons.expectedHeight -or
        [double]$geometry.buttons.watchHeight -ne [double]$geometry.buttons.expectedHeight -or
        [double]$geometry.buttons.joinHeight -ne [double]$geometry.buttons.expectedHeight -or
        [double]$geometry.buttons.cancelWatchGap -ne [double]$geometry.buttons.expectedGap -or
        [double]$geometry.buttons.watchJoinGap -ne [double]$geometry.buttons.expectedGap -or
        -not $geometry.buttons.wpfColumnMarginsPassed -or
        [string]$geometry.contract -notlike
            "*contract=wpf-1.1.0-online-surface-r3*" -or
        -not $gui.room.finalServerState.room.resourcesReady -or
        [int]$gui.room.finalServerState.resourceEntryCount -ne 3 -or
        $gui.room.memberRole -ne "editor" -or
        $activeMemberIds.Count -ne 2 -or
        $activeMemberIds -notcontains 4101 -or
        $activeMemberIds -notcontains 4202) {
        throw "Formal WPF invitation-toast GUI evidence is incomplete."
    }

    $application = File-Evidence (
        Join-Path $projectRoot (
            "LumaChart.Avalonia\bin\Release\net8.0-windows\" +
            "LumaChart.Avalonia.exe"))
    $serverAssembly = File-Evidence (
        Join-Path $projectRoot (
            "tools\WindowsAvaloniaOnlineGuiServer\bin\Release\net8.0\" +
            "WindowsAvaloniaOnlineGuiServer.dll"))
    if ($application.sha256 -ne [string]$gui.hashes.application -or
        $serverAssembly.sha256 -ne [string]$gui.hashes.serverAssembly) {
        throw "Formal invitation GUI application/server hash differs from current binaries."
    }

    $installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
    $installer = File-Evidence $installerPath
    if ($installer.sha256 -ne
        "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
        throw "Frozen WPF installer hash changed."
    }
    $realChartPath = "D:\osu!\Songs\Resound\0\1781536331.mc"
    $realChart = File-Evidence $realChartPath
    if ($realChart.sha256 -ne
        "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") {
        throw "Real Resound MC fixture hash changed."
    }

    $sourcePaths = @(
        "LumaChart.Avalonia\Infrastructure\WindowsOnlineSurfaceParityPolicy.cs",
        "LumaChart.Avalonia\MainWindow.cs",
        "LumaChart.Avalonia.Specs\WindowsOnlineSurfaceParitySpecs.cs",
        "tools\Capture-WindowsAvaloniaTwoClientOnlineGui.ps1",
        "tools\New-WindowsAvaloniaOnlineSurfaceSliceEvidence.ps1"
    )
    $changedFiles = @($sourcePaths | ForEach-Object {
        File-Evidence (Join-Path $projectRoot $_)
    })
    $screenshots = @(
        File-Evidence (Join-Path $formalRoot "gui\owner-hidden-private-room-create.png")
        File-Evidence (Join-Path $formalRoot "gui\owner-hidden-room-editor-bound.png")
        File-Evidence (Join-Path $formalRoot "gui\owner-friend-invite-list.png")
        File-Evidence (Join-Path $formalRoot "gui\owner-hidden-room-invitation-sent.png")
        File-Evidence (Join-Path $formalRoot "gui\member-main-window-invitation-toast.png")
        File-Evidence (Join-Path $formalRoot "gui\member-editor-after-hidden-invitation.png")
        File-Evidence (Join-Path $formalRoot "gui\owner-members-after-hidden-invite.png")
        File-Evidence (Join-Path $formalRoot "gui\member-room-unread-red-dot.png")
        File-Evidence (Join-Path $formalRoot "gui\member-room-members-and-chat.png")
    )
    $predecessor = File-Evidence (
        Join-Path $projectRoot (
            "artifacts\windows-avalonia-room-password-join-slice-20260727-r1\" +
            "verification-evidence.json"))
    $verification = [ordered]@{
        schema =
            "lumachart.windows.avalonia.invitation-toast-slice-verification.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        scope = [ordered]@{
            platform = "Windows Avalonia only"
            contract = "wpf-1.1.0-online-surface-r3"
            covered = @(
                "WPF 360 DIP top-right invitation toast geometry and colors",
                "DPI-aware 50/14 DIP placement and 14/6 DIP padding/radius",
                "WPF 10/14/12 typography flow and 34 DIP three-column actions",
                "physical hidden-private-room invitation join from the main window",
                "password bypass, three resources, editor role and two active members"
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
            logs = $builds
        }
        tests = [ordered]@{
            avaloniaSpecs = [ordered]@{
                passed = $expectedAvaloniaSpecCount
                total = $expectedAvaloniaSpecCount
                failed = 0
                invitationCheck = $invitationChecks[0]
                evidence = File-Evidence $avaloniaSpecsPath
                log = File-Evidence (
                    Join-Path $formalRoot "specs\avalonia-specs.log")
            }
            mainSpecs = [ordered]@{
                passed = 79
                total = 79
                failed = 0
                log = File-Evidence $mainSpecsPath
            }
        }
        gui = [ordered]@{
            status = "passed"
            interaction =
                "ten physical pointer actions across two hosted Windows Avalonia clients"
            evidence = File-Evidence $guiEvidencePath
            geometry = $geometry
            screenshots = $screenshots
        }
        source = [ordered]@{
            changedFiles = $changedFiles
        }
        frozenBaselines = [ordered]@{
            installer = $installer
            realChart = $realChart
            predecessor = $predecessor
        }
        completion = [ordered]@{
            fullWindowsMigrationComplete = $false
            userReplacementApproval = $false
            otherPlatformAuthorization = $false
        }
    }
    $verification | ConvertTo-Json -Depth 14 |
        Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
    $verification | ConvertTo-Json -Depth 14
    exit 0
}

if ($CorrectPasswordJoinScenario) {
    $guiEvidencePath = Join-Path $formalRoot "gui\evidence.json"
    $gui = Get-Content -Raw -LiteralPath $guiEvidencePath | ConvertFrom-Json
    $activeMemberIds = @($gui.online.activeMemberIds)
    if ($gui.schema -ne
            "lumachart.windows.avalonia.correct-password-join-gui-evidence.v1" -or
        $gui.status -ne "passed" -or
        -not $gui.formalMigrationAuthority -or
        $gui.completion.windowsAvaloniaCanReplaceWpf -or
        $gui.completion.userManualReplacementApprovalReceived -or
        $gui.completion.nextPlatformAuthorized -or
        [int]$gui.password.createLengthBefore -ne 0 -or
        [int]$gui.password.createLengthAfter -ne 4 -or
        [int]$gui.password.joinLengthBefore -ne 0 -or
        [int]$gui.password.joinLengthAfter -ne 4 -or
        [int]$gui.password.createSecretExposureCount -ne 0 -or
        [int]$gui.password.joinSecretExposureCount -ne 0 -or
        [int]$gui.password.serverPasswordSubmissionCount -ne 1 -or
        -not $gui.online.roomPrivate -or
        -not $gui.online.resourcesReady -or
        [int]$gui.online.resourceEntryCount -ne 3 -or
        [int]$gui.online.resourceCommitCount -ne 1 -or
        $activeMemberIds.Count -ne 2 -or
        $activeMemberIds -notcontains 4101 -or
        $activeMemberIds -notcontains 4202 -or
        -not $gui.online.memberOpenedEditor -or
        -not $gui.online.communitySurfaceClosed -or
        -not $gui.integrity.realChartFixture.unchanged -or
        -not $gui.integrity.releasedWpfInstaller.unchanged) {
        throw "Formal correct-password resource-backed GUI evidence is incomplete."
    }

    $installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
    $installer = File-Evidence $installerPath
    if ($installer.sha256 -ne
        "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
        throw "Frozen WPF installer hash changed."
    }
    $realChartPath = "D:\osu!\Songs\Resound\0\1781536331.mc"
    $realChart = File-Evidence $realChartPath
    if ($realChart.sha256 -ne
        "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") {
        throw "Real Resound MC fixture hash changed."
    }
    $sourcePaths = @(
        "tools\Capture-WindowsAvaloniaOnlineImeGui.ps1",
        "tools\New-WindowsAvaloniaOnlineSurfaceSliceEvidence.ps1"
    )
    $changedFiles = @($sourcePaths | ForEach-Object {
        File-Evidence (Join-Path $projectRoot $_)
    })
    $screenshots = @(
        File-Evidence (Join-Path $formalRoot "gui\owner-room-name-ime-composition.png")
        File-Evidence (Join-Path $formalRoot "gui\owner-create-password-direct-input.png")
        File-Evidence (Join-Path $formalRoot "gui\member-join-password-direct-input.png")
        File-Evidence (Join-Path $formalRoot "gui\member-correct-password-joined-editor.png")
    )
    $predecessor = File-Evidence (
        Join-Path $projectRoot (
            "artifacts\windows-avalonia-room-password-slice-20260727-r1\" +
            "verification-evidence.json"))
    $verification = [ordered]@{
        schema =
            "lumachart.windows.avalonia.correct-password-join-slice-verification.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        scope = [ordered]@{
            platform = "Windows Avalonia only"
            contract = "wpf-1.1.0-online-surface-r2"
            covered = @(
                "real Resound chart and three room resources",
                "private-room creation after physical Microsoft Pinyin room-name commit",
                "write-only create and join password input without Enter",
                "exactly one correct-password member submission",
                "two active members and member editor opened from the hosted password layer"
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
            logs = $builds
        }
        tests = [ordered]@{
            avaloniaSpecs = [ordered]@{
                passed = $expectedAvaloniaSpecCount
                total = $expectedAvaloniaSpecCount
                failed = 0
                evidence = File-Evidence $avaloniaSpecsPath
                log = File-Evidence (
                    Join-Path $formalRoot "specs\avalonia-specs.log")
            }
            mainSpecs = [ordered]@{
                passed = 79
                total = 79
                failed = 0
                log = File-Evidence $mainSpecsPath
            }
        }
        gui = [ordered]@{
            status = "passed"
            interaction =
                "physical Microsoft Pinyin room-name commit plus write-only password providers; no Enter"
            evidence = File-Evidence $guiEvidencePath
            screenshots = $screenshots
        }
        source = [ordered]@{
            changedFiles = $changedFiles
        }
        frozenBaselines = [ordered]@{
            installer = $installer
            realChart = $realChart
            predecessor = $predecessor
        }
        completion = [ordered]@{
            fullWindowsMigrationComplete = $false
            userReplacementApproval = $false
            otherPlatformAuthorization = $false
        }
    }
    $verification | ConvertTo-Json -Depth 14 |
        Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
    $verification | ConvertTo-Json -Depth 14
    exit 0
}

if ($RoomPasswordScenario) {
    $roomPasswordChecks = @($avaloniaSpecs.checks | Where-Object {
        $_.name -like "online-room-password-*"
    })
    if ($roomPasswordChecks.Count -ne 2 -or
        @($roomPasswordChecks | Where-Object { -not $_.passed }).Count -ne 0) {
        throw "Room-password parity checks are not 2/2 passed."
    }

    $guiEvidencePath =
        Join-Path $formalRoot "gui\online-surface-gui-evidence.json"
    $gui = Get-Content -Raw -LiteralPath $guiEvidencePath | ConvertFrom-Json
    if ($gui.schema -ne
            "lumachart.windows.avalonia.room-password-gui-evidence.v1" -or
        $gui.status -ne "passed" -or
        -not $gui.hostedInMainWindow -or
        $gui.separateNativeWindowCreated -or
        -not $gui.mouseInputUsed -or
        $gui.keyboardInputUsed -or
        [int]$gui.physicalActionCount -ne 8 -or
        -not $gui.close.surfaceHidden -or
        $gui.roomPassword.editorAction.name -ne "输入密码" -or
        $gui.roomPassword.viewerAction.name -ne "旁观" -or
        $gui.roomPassword.viewerPrompt.helpText -notlike "MemberRole=viewer;*" -or
        $gui.roomPassword.editorPrompt.helpText -notlike "MemberRole=editor;*" -or
        -not $gui.roomPassword.directoryPreservedUnderLayer -or
        $gui.roomPassword.separateNativeWindowCreated -or
        $gui.roomPassword.clearTextExposedThroughUia -or
        $gui.roomPassword.wrongPasswordError -ne "房间密码错误。" -or
        -not $gui.roomPassword.wrongPasswordKeptLayerOpen -or
        [int]$gui.roomPassword.wrongPasswordJoinRequestCount -ne 1 -or
        [int]$gui.roomPassword.wrongPasswordSubmissionCount -ne 1 -or
        $gui.roomPassword.wrongPasswordJoinedMember -or
        -not $gui.roomPassword.viewerCancelRestoredDirectory -or
        -not $gui.roomPassword.editorErrorCancelRestoredDirectory) {
        throw "Formal room-password GUI evidence is incomplete."
    }

    $installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
    $installer = File-Evidence $installerPath
    if ($installer.sha256 -ne
        "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
        throw "Frozen WPF installer hash changed."
    }
    $realChartPath = "D:\osu!\Songs\Resound\0\1781536331.mc"
    $realChart = File-Evidence $realChartPath
    if ($realChart.sha256 -ne
        "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") {
        throw "Real Resound MC fixture hash changed."
    }

    $sourcePaths = @(
        "LumaChart.Avalonia\Dialogs\OnlineCommunityDialog.cs",
        "LumaChart.Avalonia\Infrastructure\WindowsOnlineSurfaceParityPolicy.cs",
        "LumaChart.Avalonia.Specs\WindowsOnlineSurfaceParitySpecs.cs",
        "tools\Capture-WindowsAvaloniaOnlineSurfaceGui.ps1",
        "tools\New-WindowsAvaloniaOnlineSurfaceSliceEvidence.ps1"
    )
    $changedFiles = @($sourcePaths | ForEach-Object {
        File-Evidence (Join-Path $projectRoot $_)
    })
    $screenshots = @(
        File-Evidence (Join-Path $formalRoot "gui\community-profile.png")
        File-Evidence (Join-Path $formalRoot "gui\community-rooms.png")
        File-Evidence (Join-Path $formalRoot "gui\room-password.png")
        File-Evidence (Join-Path $formalRoot "gui\room-password-error.png")
        File-Evidence (Join-Path $formalRoot "gui\room-password-cancelled.png")
    )
    $predecessor = File-Evidence (
        Join-Path $projectRoot (
            "artifacts\windows-avalonia-online-surface-slice-20260727-r1\" +
            "verification-evidence.json"))

    $verification = [ordered]@{
        schema =
            "lumachart.windows.avalonia.room-password-slice-verification.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        scope = [ordered]@{
            platform = "Windows Avalonia only"
            contract = "wpf-1.1.0-online-surface-r2"
            covered = @(
                "distinct editor and viewer room-list actions",
                "390 DIP hosted password overlay while the lobby stays mounted",
                "password IME disabled and UI Automation clear-text suppression",
                "wrong-password fail-closed response with one server request",
                "physical viewer cancel, editor error cancel and header return"
            )
            excluded = @(
                "correct-password resource-backed join in this focused slice",
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
            logs = $builds
        }
        tests = [ordered]@{
            avaloniaSpecs = [ordered]@{
                passed = $expectedAvaloniaSpecCount
                total = $expectedAvaloniaSpecCount
                failed = 0
                onlineShellChecks = $onlineChecks
                roomPasswordChecks = $roomPasswordChecks
                evidence = File-Evidence $avaloniaSpecsPath
                log = File-Evidence (
                    Join-Path $formalRoot "specs\avalonia-specs.log")
            }
            mainSpecs = [ordered]@{
                passed = 79
                total = 79
                failed = 0
                log = File-Evidence $mainSpecsPath
            }
        }
        gui = [ordered]@{
            status = "passed"
            interaction =
                "eight physical pointer clicks; password value set through a write-only UIA provider; no keyboard input"
            hostedInMainWindow = $true
            separateNativeWindowCreated = $false
            evidence = File-Evidence $guiEvidencePath
            screenshots = $screenshots
        }
        source = [ordered]@{
            changedFiles = $changedFiles
        }
        frozenBaselines = [ordered]@{
            installer = $installer
            realChart = $realChart
            predecessor = $predecessor
        }
        completion = [ordered]@{
            fullWindowsMigrationComplete = $false
            userReplacementApproval = $false
            otherPlatformAuthorization = $false
        }
    }
    $verification | ConvertTo-Json -Depth 14 |
        Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
    $verification | ConvertTo-Json -Depth 14
    exit 0
}

$accountEvidencePath = Join-Path $formalRoot "account\account-overlay-gui-evidence.json"
$account = Get-Content -Raw -LiteralPath $accountEvidencePath | ConvertFrom-Json
if ($account.status -ne "passed" -or
    -not $account.hostedInMainWindow -or
    $account.separateNativeWindowCreated -or
    -not $account.mouseInputUsed -or
    [int]$account.physicalActionCount -ne 6 -or
    -not $account.offlineAction.accountLayerHidden -or
    $account.offlineAction.sessionTokenExists) {
    throw "Formal account overlay GUI evidence is incomplete."
}

$communityEvidencePath = Join-Path $formalRoot "community\gui\online-surface-gui-evidence.json"
$community = Get-Content -Raw -LiteralPath $communityEvidencePath | ConvertFrom-Json
if ($community.status -ne "passed" -or
    -not $community.sessionRestored -or
    -not $community.hostedInMainWindow -or
    $community.separateNativeWindowCreated -or
    -not $community.mouseInputUsed -or
    [int]$community.physicalActionCount -ne 3 -or
    -not $community.close.surfaceHidden) {
    throw "Formal community overlay GUI evidence is incomplete."
}

$installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$installer = File-Evidence $installerPath
if ($installer.sha256 -ne
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
    throw "Frozen WPF installer hash changed."
}
$realChartPath = "D:\osu!\Songs\Resound\0\1781536331.mc"
$realChart = File-Evidence $realChartPath
if ($realChart.sha256 -ne
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") {
    throw "Real Resound MC fixture hash changed."
}

$sourcePaths = @(
    "LumaChart.Avalonia\Dialogs\OnlineAccountDialog.cs",
    "LumaChart.Avalonia\Dialogs\OnlineCommunityDialog.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsOnlineSurfaceParityPolicy.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "LumaChart.Avalonia.Specs\WindowsOnlineSurfaceParitySpecs.cs",
    "tools\Capture-WindowsAvaloniaAccountGui.ps1",
    "tools\Capture-WindowsAvaloniaOnlineSurfaceGui.ps1",
    "tools\New-WindowsAvaloniaOnlineSurfaceSliceEvidence.ps1"
)
$changedFiles = @($sourcePaths | ForEach-Object {
    File-Evidence (Join-Path $projectRoot $_)
})

$screenshots = @(
    File-Evidence (Join-Path $formalRoot "account\login.png")
    File-Evidence (Join-Path $formalRoot "account\registration.png")
    File-Evidence (Join-Path $formalRoot "account\reset.png")
    File-Evidence (Join-Path $formalRoot "community\gui\community-profile.png")
    File-Evidence (Join-Path $formalRoot "community\gui\community-rooms.png")
)

$predecessor = File-Evidence (
    Join-Path $projectRoot (
        "artifacts\windows-avalonia-dialog-slice-20260727-r3\" +
        "verification-evidence.json"))

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.online-surface-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        platform = "Windows Avalonia only"
        contract = "wpf-1.1.0-online-surface-r1"
        covered = @(
            "account/login/register/reset hosted inside the main shell",
            "physical cancel back to the cached login surface",
            "physical offline return without creating a session token",
            "loopback DPAPI owner restore",
            "community profile and room directory hosted inside the main shell",
            "physical header return to the editor",
            "editor shortcut routing suppressed while online overlay is visible"
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
        logs = $builds
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 421
            total = 421
            failed = 0
            onlineSurfaceChecks = $onlineChecks
            evidence = File-Evidence $avaloniaSpecsPath
            log = File-Evidence (
                Join-Path $formalRoot "specs\avalonia-specs.log")
        }
        mainSpecs = [ordered]@{
            passed = 79
            total = 79
            failed = 0
            log = File-Evidence $mainSpecsPath
        }
    }
    gui = [ordered]@{
        status = "passed"
        account = [ordered]@{
            interaction = "six physical pointer clicks; no keyboard input"
            hostedInMainWindow = $true
            separateNativeWindowCreated = $false
            evidence = File-Evidence $accountEvidencePath
        }
        community = [ordered]@{
            interaction = "three physical pointer clicks against an isolated loopback owner session"
            hostedInMainWindow = $true
            separateNativeWindowCreated = $false
            evidence = File-Evidence $communityEvidencePath
        }
        screenshots = $screenshots
    }
    source = [ordered]@{
        changedFiles = $changedFiles
    }
    frozenBaselines = [ordered]@{
        installer = $installer
        realChart = $realChart
        predecessor = $predecessor
    }
    completion = [ordered]@{
        fullWindowsMigrationComplete = $false
        userReplacementApproval = $false
        otherPlatformAuthorization = $false
    }
}

$verification | ConvertTo-Json -Depth 14 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
$verification | ConvertTo-Json -Depth 14
