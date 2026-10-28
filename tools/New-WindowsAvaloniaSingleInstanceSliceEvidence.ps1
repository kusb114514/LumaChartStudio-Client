param(
    [string]$Root =
        "artifacts\windows-avalonia-single-instance-slice-20260728-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedBeforeForwardScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedOsuChoiceScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedAfterForwardScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia single-instance verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-single-instance-slice-20260728-r1"))).TrimEnd('\')
$formalRoot = if ([IO.Path]::IsPathRooted($Root)) {
    [IO.Path]::GetFullPath($Root).TrimEnd('\')
}
else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
}
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal single-instance root must be exactly $expectedRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
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

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -Raw -LiteralPath $Path
    Assert ($text -match "0 个警告|0 Warning") (
        "Strict build log lacks zero-warning result: $Path")
    Assert ($text -match "0 个错误|0 Error") (
        "Strict build log lacks zero-error result: $Path")
    File-Evidence $Path
}

foreach ($hash in @(
        $ExpectedBeforeForwardScreenshotSha256,
        $ExpectedOsuChoiceScreenshotSha256,
        $ExpectedAfterForwardScreenshotSha256)) {
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
}

$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs = Get-Content -Raw -LiteralPath $specsPath | ConvertFrom-Json
$checks = @($specs.checks)
$passedChecks = @($checks | Where-Object passed)
$focus = @($checks | Where-Object name -eq (
    "windows-single-instance-forwards-deduplicated-mc-osu-to-primary"))
Assert ($specs.status -eq "passed") "Avalonia Specs status is not passed."
Assert ($checks.Count -eq 510 -and $passedChecks.Count -eq 510) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")
Assert ($focus.Count -eq 1 -and $focus[0].passed) (
    "Single-instance focused Spec did not pass.")

$mainSpecsPath = Join-Path $formalRoot "tests\main-specs.log"
$mainSpecsText = Get-Content -Raw -LiteralPath $mainSpecsPath
Assert ($mainSpecsText -match "79/79 specs passed") (
    "Main Specs did not pass 79/79.")

$guiPath = Join-Path $formalRoot "gui\evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -eq (
    "lumachart.windows.avalonia.single-instance-gui-evidence.v1")) (
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
Assert ($gui.enterKeyUsed -eq $false -and
    $gui.physicalMouseInputUsed -eq $false -and
    $gui.uiAutomationInvokeUsed -eq $true) (
    "GUI input method was not recorded as honest UI Automation.")
Assert (@($gui.actions).Count -eq 1 -and
    $gui.actions[0].automationId -ceq "OsuImportMode.Calibrate" -and
    $gui.actions[0].pattern -ceq "InvokePattern") (
    "Expected exactly one osu calibration UIA action.")

$mcPath = [IO.Path]::GetFullPath(
    "D:\osu!\Songs\Resound\0\1781536331.mc")
$osuPath = [IO.Path]::GetFullPath(
    "D:\osu!\Songs\1005389 Minori Chihara - Michishirube\" +
    "Minori Chihara - Michishirube (eZmmR) [Dear You,  Gilbert Bougainvillea .].osu")
Assert ([int]$gui.primary.initialTabCount -eq 1 -and
    [int]$gui.primary.mcTabCountBeforeOsuChoice -eq 1 -and
    [int]$gui.primary.finalTabCount -eq 2) (
    "Primary tab progression was not 1 -> 1 -> 2.")
Assert ($gui.primary.topmostAtStartup -eq $false -and
    $gui.primary.topmostAtEnd -eq $false) (
    "Primary window used a persistent topmost style.")
Assert ($gui.primary.remainedAlive -eq $true -and
    [int]$gui.primary.foregroundProcessIdAtEnd -eq
        [int]$gui.primary.processId) (
    "The original primary did not remain the foreground editor.")
$tabHelp = (@($gui.primary.finalTabs) |
    ForEach-Object { [string]$_.helpText }) -join "`n"
Assert ($tabHelp.Contains($mcPath, [StringComparison]::OrdinalIgnoreCase) -and
    $tabHelp.Contains($osuPath, [StringComparison]::OrdinalIgnoreCase)) (
    "Final tabs do not expose both exact source paths.")

Assert ([int]$gui.secondary.exitCode -eq 0 -and
    $gui.secondary.createdMainWindow -eq $false -and
    [long]$gui.secondary.mainWindowHandle -eq 0 -and
    [double]$gui.secondary.elapsedMilliseconds -gt 0 -and
    [double]$gui.secondary.elapsedMilliseconds -lt 10000) (
    "Secondary process did not acknowledge, forward, and exit cleanly.")
Assert ([int]$gui.protocol.inputArgumentCount -eq 4 -and
    [int]$gui.protocol.uniqueSupportedPathCount -eq 2 -and
    $gui.protocol.primaryStartedWithMc -eq $true -and
    $gui.protocol.primaryProcessUnchanged -eq $true -and
    $gui.protocol.secondaryExitedAfterAcknowledgment -eq $true -and
    $gui.secondary.duplicateInputDeduplicated -eq $true -and
    [int]$gui.secondary.forwardedPathCount -eq 2) (
    "Single-instance forwarding or duplicate suppression differs from the contract.")
$orderedPaths = @($gui.protocol.orderedPaths)
Assert ($orderedPaths.Count -eq 2 -and
    ([IO.Path]::GetFullPath([string]$orderedPaths[0])).Equals(
        $mcPath,
        [StringComparison]::OrdinalIgnoreCase) -and
    ([IO.Path]::GetFullPath([string]$orderedPaths[1])).Equals(
        $osuPath,
        [StringComparison]::OrdinalIgnoreCase)) (
    "Forwarded file order changed.")
Assert ($gui.startupAccount.evidenceChartModeSuppressedStartupChoice -eq $true) (
    "The evidence launch was obscured by the startup account choice.")
Assert ($gui.dialog.topmost -eq $false -and
    $gui.dialog.choice -ceq "Calibrate") (
    "The owned osu choice dialog state is unexpected.")
Assert ($gui.isolation.productionEndpointContacted -eq $false -and
    $gui.isolation.dotnetAndTempOnProjectDrive -eq $true) (
    "GUI isolation or D-drive cache contract failed.")

$screenshotEvidence = [ordered]@{}
$expectedScreenshotHashes = [ordered]@{
    beforeForward = $ExpectedBeforeForwardScreenshotSha256.ToUpperInvariant()
    osuChoice = $ExpectedOsuChoiceScreenshotSha256.ToUpperInvariant()
    afterForward = $ExpectedAfterForwardScreenshotSha256.ToUpperInvariant()
}
foreach ($property in @($gui.screenshots.PSObject.Properties)) {
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
    Assert ($actual.sha256 -ceq [string]$expectedScreenshotHashes[$property.Name]) (
        "Visually approved screenshot hash changed: $($property.Name)")
    $screenshotEvidence[$property.Name] = $actual
}
Assert ($screenshotEvidence.Count -eq 3) (
    "Expected exactly three formal screenshots.")

$fixtureMc = File-Evidence $mcPath
Assert ($fixtureMc.sha256 -ceq
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") (
    "Real Resound MC fixture changed.")
$fixtureOsu = File-Evidence $osuPath
Assert ($fixtureOsu.sha256 -ceq
    "511866870F99BDC7443006FA7420C7A9D21198F49B9EC13B50A32293E7F58E57") (
    "Real osu fixture changed.")
Assert ($gui.fixtures.mc.sha256Before -ceq $fixtureMc.sha256 -and
    $gui.fixtures.mc.sha256After -ceq $fixtureMc.sha256 -and
    $gui.fixtures.osu.sha256Before -ceq $fixtureOsu.sha256 -and
    $gui.fixtures.osu.sha256After -ceq $fixtureOsu.sha256) (
    "GUI fixture hashes were not stable.")
$installer = File-Evidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert ($installer.sha256 -ceq
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") (
    "Frozen WPF installer changed.")

$changedFiles = @(
    "LumaChart.Avalonia\Infrastructure\WindowsSingleInstanceCoordinator.cs",
    "LumaChart.Avalonia\Program.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\WindowsSingleInstanceSpecs.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "tools\Capture-WindowsAvaloniaSingleInstanceGui.ps1",
    "tools\New-WindowsAvaloniaSingleInstanceSliceEvidence.ps1"
) | ForEach-Object { File-Evidence (Join-Path $projectRoot $_) }

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.single-instance-slice-verification.v1"
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
    priority = "main-functions-first-ui-parity-deferred-by-user"
    builds = $builds
    tests = [ordered]@{
        avaloniaSpecs = File-Evidence $specsPath
        avaloniaSpecsPassed = 510
        avaloniaSpecsTotal = 510
        focused = $focus[0]
        mainSpecs = File-Evidence $mainSpecsPath
        mainSpecsPassed = 79
        mainSpecsTotal = 79
    }
    gui = [ordered]@{
        evidence = File-Evidence $guiPath
        actions = @($gui.actions).Count
        screenshots = $screenshotEvidence
        primary = $gui.primary
        secondary = $gui.secondary
        protocol = $gui.protocol
        physicalMouseInputUsed = $false
        uiAutomationInvokeUsed = $true
    }
    immutableInputs = [ordered]@{
        realMc = $fixtureMc
        realOsu = $fixtureOsu
        frozenInstaller = $installer
    }
    changedFiles = $changedFiles
    remainingDifferences = @(
        "主功能优先；像素级 UI、布局和快捷操作差异按用户要求后置并由用户后续人工反馈。",
        "单实例本片已实测 MC/osu 与重复路径；MCZ/OSZ 的外壳关联和归档转发仍需安装阶段实测。",
        "联机 Key 音实际可听同步、断线/Server 重启恢复和双客户端完整联机矩阵仍未全部闭合。",
        "完整安装升级卸载、ClientSecurity、游戏实开格式兼容、全 DPI/多屏和物理 60/120 Hz/4K 终门禁仍开放。",
        "用户尚未人工确认 Avalonia Windows 版可替代 WPF。"
    )
}
$verification | ConvertTo-Json -Depth 60 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
Write-Output "Windows Avalonia single-instance slice verification: passed-migration-incomplete"
Write-Output "Evidence: $verificationPath"
