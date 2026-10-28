param(
    [string]$Root =
        "artifacts\windows-avalonia-online-role-presentation-slice-20260728-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedMembersScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedManagementScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedViewerScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia online role-presentation verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-online-role-presentation-slice-20260728-r1"))).TrimEnd('\')
$formalRoot = if ([IO.Path]::IsPathRooted($Root)) {
    [IO.Path]::GetFullPath($Root).TrimEnd('\')
}
else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
}
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal online role-presentation root must be exactly $expectedRoot"
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
    Assert ($text -match "0 个警告|0 Warning") (
        "Strict build log lacks zero-warning result: $Path")
    Assert ($text -match "0 个错误|0 Error") (
        "Strict build log lacks zero-error result: $Path")
    File-Evidence $Path
}

foreach ($hash in @(
        $ExpectedMembersScreenshotSha256,
        $ExpectedManagementScreenshotSha256,
        $ExpectedViewerScreenshotSha256)) {
    Assert ($hash -match '^[0-9A-Fa-f]{64}$') "A screenshot SHA-256 is invalid."
}
$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$builds = [ordered]@{
    avalonia =
        Assert-StrictBuild (Join-Path $formalRoot "build\build-avalonia.log")
    avaloniaSpecs =
        Assert-StrictBuild (Join-Path $formalRoot "build\build-avalonia_specs.log")
    mainSpecs =
        Assert-StrictBuild (Join-Path $formalRoot "build\build-main_specs.log")
    loopbackServer =
        Assert-StrictBuild (Join-Path $formalRoot "build\build-loopback_gui_server.log")
}

$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs = Get-Content -Raw -LiteralPath $specsPath | ConvertFrom-Json
$checks = @($specs.checks)
$passedChecks = @($checks | Where-Object passed)
$focus = @($checks | Where-Object name -eq (
    "online-room-role-visible-copy-matches-wpf-110"))
Assert ($specs.status -eq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 509 -and $passedChecks.Count -eq 509) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
Assert ($focus.Count -eq 1 -and $focus[0].passed) (
    "Online role-presentation focused Spec did not pass.")

$mainSpecsPath = Join-Path $formalRoot "tests\main-specs.log"
$mainSpecsText = Get-Content -Raw -LiteralPath $mainSpecsPath
Assert ($mainSpecsText -match "79/79 specs passed") (
    "Main Specs did not pass 79/79.")

$guiPath = Join-Path $formalRoot "gui\evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -eq (
    "lumachart.windows.avalonia.online-role-presentation-gui-evidence.v1")) (
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
Assert ($gui.physicalMouseInputUsed -eq $false -and
    $gui.uiAutomationInvokeToggleSelectionItemUsed -eq $true) (
    "GUI input method was not recorded as honest UI Automation.")
Assert ($gui.enterKeyUsed -eq $false) "GUI evidence used Enter."
Assert ([long]$gui.foregroundIdleGateMilliseconds -ge 3000) (
    "Foreground idle safety gate did not pass.")
Assert (@($gui.actions).Count -eq 11) (
    "Expected exactly 11 GUI actions, got $(@($gui.actions).Count).")

Assert ($gui.visible.ownerState -ceq "房主" -and
    $gui.visible.memberState -ceq "编辑者" -and
    $gui.visible.selectedEditor -ceq "编辑者" -and
    $gui.visible.editorOption -ceq "编辑者" -and
    $gui.visible.viewerOption -ceq "观察者" -and
    $gui.visible.selectedViewer -ceq "观察者") (
    "Visible owner/editor/viewer role labels differ from WPF.")
Assert ($gui.visible.permissionHeading -ceq
        "房间编辑权限 · 由房主持久分配" -and
    $gui.visible.metadata -ceq "允许编辑谱面信息" -and
    $gui.visible.timing -ceq "允许编辑 Effect（Timing Edit 全部功能）" -and
    $gui.visible.notes -ceq "允许编辑 Note" -and
    $gui.visible.save -ceq "保存房间权限" -and
    $gui.visible.kick -ceq "踢出" -and
    $gui.visible.ban -ceq "暂时封禁 30 分钟" -and
    $gui.visible.viewerPermissionsDisabled -eq $true) (
    "Member-management visible copy or viewer disabled state differs from WPF.")
Assert ($gui.protocol.ownerRole -ceq "owner" -and
    $gui.protocol.memberRole -ceq "editor" -and
    [int]$gui.protocol.acceptedOperationCount -eq 0 -and
    [int]$gui.protocol.noteCount -eq 2753 -and
    [long]$gui.protocol.revision -eq 1) (
    "Visible role staging changed protocol state or chart.")

$screenshotEvidence = @()
$screenshotProperties = @($gui.screenshots.PSObject.Properties)
Assert ($screenshotProperties.Count -eq 11) (
    "Expected 11 declared screenshots, got $($screenshotProperties.Count).")
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

$membersShot = @(
    $screenshotEvidence |
        Where-Object { $_.name -eq "owner-role-presentation-members" }
)[0]
$managementShot = @(
    $screenshotEvidence |
        Where-Object { $_.name -eq "owner-role-presentation-management" }
)[0]
$viewerShot = @(
    $screenshotEvidence |
        Where-Object { $_.name -eq "owner-role-presentation-viewer" }
)[0]
Assert ($membersShot.file.sha256 -ceq
    $ExpectedMembersScreenshotSha256.ToUpperInvariant()) (
    "Formal member-role screenshot hash changed.")
Assert ($managementShot.file.sha256 -ceq
    $ExpectedManagementScreenshotSha256.ToUpperInvariant()) (
    "Formal management screenshot hash changed.")
Assert ($viewerShot.file.sha256 -ceq
    $ExpectedViewerScreenshotSha256.ToUpperInvariant()) (
    "Formal staged-viewer screenshot hash changed.")

$fixture = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
Assert ($fixture.sha256 -ceq
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") (
    "Real Resound MC fixture changed.")
$installer = File-Evidence (Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert ($installer.sha256 -ceq
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") (
    "Frozen WPF installer changed.")

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.online-role-presentation-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    windowsAvaloniaOnly = $true
    windowsAvaloniaCanReplaceWpf = $false
    userReplacementApprovalReceived = $false
    nextPlatformAuthorized = $false
    productionServerDeploymentPerformed = $false
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    builds = $builds
    tests = [ordered]@{
        avaloniaSpecs = File-Evidence $specsPath
        avaloniaSpecsPassed = 509
        avaloniaSpecsTotal = 509
        focused = $focus[0]
        mainSpecs = File-Evidence $mainSpecsPath
        mainSpecsPassed = 79
        mainSpecsTotal = 79
    }
    gui = [ordered]@{
        evidence = File-Evidence $guiPath
        actions = @($gui.actions).Count
        screenshots = $screenshotEvidence
        focusedScreenshotHashes = [ordered]@{
            members = $membersShot.file.sha256
            management = $managementShot.file.sha256
            viewer = $viewerShot.file.sha256
        }
        physicalMouseInputUsed = $false
        uiAutomationInvokeToggleSelectionItemUsed = $true
        foregroundIdleGateMilliseconds =
            [long]$gui.foregroundIdleGateMilliseconds
        protocol = $gui.protocol
        visible = $gui.visible
    }
    immutableInputs = [ordered]@{
        realMc = $fixture
        frozenInstaller = $installer
    }
    remainingDifferences = @(
        "完整 Windows Avalonia 功能矩阵、全部快捷操作、弹层焦点与像素级 WPF A/B 仍未全部闭合。",
        "房间成员管理的 WPF CompactPlayerProfile 整体布局尚未逐像素迁移；本片仅闭合角色、权限和封禁可见文案。",
        "当前环境的游戏/远程输入会持续刷新 LastInputInfo；本片诚实使用 UIA，不声明物理鼠标。",
        "完整安装升级卸载、ClientSecurity、格式游戏实开、全 DPI/多屏和物理 60/120 Hz/4K 终门禁仍开放。",
        "用户尚未人工确认 Avalonia Windows 版可替代 WPF。"
    )
}
$verification | ConvertTo-Json -Depth 60 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
Write-Output "Windows Avalonia online role-presentation slice verification: passed-migration-incomplete"
Write-Output "Evidence: $verificationPath"
