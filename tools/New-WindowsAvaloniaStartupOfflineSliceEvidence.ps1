param(
    [string]$Root =
        "artifacts\windows-avalonia-startup-offline-slice-20260727-r1"
)

$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root))
if (-not (Test-Path -LiteralPath $formalRoot -PathType Container)) {
    throw "Formal startup/offline root not found: $formalRoot"
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

$builds = [ordered]@{
    avalonia = Assert-BuildLog (
        Join-Path $formalRoot "build\avalonia-build.log")
    avaloniaSpecs = Assert-BuildLog (
        Join-Path $formalRoot "build\avalonia-specs-build.log")
    mainSpecs = Assert-BuildLog (
        Join-Path $formalRoot "build\main-specs-build.log")
}

$avaloniaSpecsPath = Join-Path (
    $formalRoot) "tests\avalonia-specs-evidence.json"
$avaloniaSpecs = Get-Content -Raw -LiteralPath $avaloniaSpecsPath |
    ConvertFrom-Json
$avaloniaChecks = @($avaloniaSpecs.Checks)
$failedAvaloniaChecks = @($avaloniaChecks | Where-Object { -not $_.Passed })
if ($avaloniaSpecs.Status -ne "passed" -or
    $avaloniaChecks.Count -ne 425 -or
    $failedAvaloniaChecks.Count -ne 0) {
    throw "Avalonia Specs are not 425/425 passed."
}
$startupChecks = @($avaloniaChecks | Where-Object {
    $_.Name -eq
        "online-startup-restores-session-or-requires-explicit-offline-choice"
})
if ($startupChecks.Count -ne 1 -or -not $startupChecks[0].Passed) {
    throw "Startup account-choice parity check is not 1/1 passed."
}

$mainSpecsPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainPasses = @(
    Select-String -LiteralPath $mainSpecsPath -Pattern "^PASS "
).Count
$mainFailures = @(
    Select-String -LiteralPath $mainSpecsPath -Pattern "^FAIL "
).Count
if ($mainPasses -ne 79 -or $mainFailures -ne 0) {
    throw "Main Specs are not 79/79 passed."
}

$guiPath = Join-Path $formalRoot "gui\gui-evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
if ($gui.schema -ne
        "lumachart.windows.avalonia.startup-offline-gui-evidence.v1" -or
    $gui.status -ne "passed" -or
    -not $gui.endpointIsLoopback -or
    $gui.productionEndpointContacted -or
    -not $gui.hostedInMainWindow -or
    $gui.separateNativeWindowCreated -or
    [int]$gui.navigationClickCount -ne 0 -or
    [int]$gui.offlineClickCount -ne 1 -or
    -not $gui.mouseInputUsed -or
    $gui.keyboardInputUsed -or
    -not $gui.startup.automaticSurfaceObserved -or
    $gui.startup.layer.isOffscreen -or
    $gui.startup.dialog.isOffscreen -or
    [long]$gui.startup.dialog.nativeWindowHandle -ne 0 -or
    $gui.startup.offlineButton.isOffscreen -or
    -not $gui.offlineAction.layerHidden -or
    $gui.offlineAction.library.isOffscreen -or
    $gui.offlineAction.sessionTokenExists -or
    -not $gui.isolation.ordinaryReleaseOnly -or
    $gui.isolation.ollvmUsed -or
    $gui.isolation.obfuscationUsed -or
    $gui.isolation.codeVirtualizationUsed -or
    $gui.isolation.aotUsed -or
    $gui.isolation.mobilePlatformTouched) {
    throw "Formal startup/offline GUI evidence is incomplete."
}

$screenshots = @(
    File-Evidence (
        Join-Path $formalRoot "gui\startup-account-choice.png")
    File-Evidence (
        Join-Path $formalRoot "gui\offline-library.png")
)
if ($screenshots[0].sha256 -ne [string]$gui.startup.screenshotSha256 -or
    $screenshots[1].sha256 -ne
        [string]$gui.offlineAction.screenshotSha256) {
    throw "Startup/offline screenshot hashes differ from GUI evidence."
}

$application = File-Evidence (
    Join-Path $projectRoot (
        "LumaChart.Avalonia\bin\Release\net8.0-windows\" +
        "LumaChart.Avalonia.exe"))
$applicationAssembly = File-Evidence (
    Join-Path $projectRoot (
        "LumaChart.Avalonia\bin\Release\net8.0-windows\" +
        "LumaChart.Avalonia.dll"))
if ($application.sha256 -ne [string]$gui.applicationSha256 -or
    $applicationAssembly.sha256 -ne
        [string]$gui.applicationAssemblySha256) {
    throw "Formal GUI binary hashes differ from current Release binaries."
}

$installer = File-Evidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
if ($installer.sha256 -ne
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
    throw "Frozen WPF installer hash changed."
}
$realChart = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
if ($realChart.sha256 -ne
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") {
    throw "Real Resound MC fixture hash changed."
}

$sourcePaths = @(
    "LumaChart.Avalonia\Infrastructure\WindowsOnlineSurfaceParityPolicy.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\WindowsOnlineSurfaceParitySpecs.cs",
    "tools\Capture-WindowsAvaloniaStartupOfflineGui.ps1",
    "tools\New-WindowsAvaloniaStartupOfflineSliceEvidence.ps1"
)
$changedFiles = @($sourcePaths | ForEach-Object {
    File-Evidence (Join-Path $projectRoot $_)
})

$remainingProcesses = @(
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessName -like "LumaChart.Avalonia*" -or
            $_.ProcessName -like "WindowsAvaloniaOnlineGuiServer*"
        } |
        Select-Object -ExpandProperty Id
)
if ($remainingProcesses.Count -ne 0) {
    throw "Formal verification found remaining Avalonia test processes."
}

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.startup-offline-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        platform = "Windows Avalonia only"
        contract = "wpf-1.1.0-online-surface-r4"
        covered = @(
            "normal unauthenticated startup automatically opens the account layer",
            "WPF-compatible eight-second session restore policy",
            "hosted account surface with no separate native dialog",
            "one physical offline click returns to the library",
            "isolated loopback failure path creates no session token",
            "evidence mode suppresses production account access"
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
            passed = 425
            total = 425
            evidence = File-Evidence $avaloniaSpecsPath
            focusedCheck = [ordered]@{
                name = [string]$startupChecks[0].Name
                detail = [string]$startupChecks[0].Detail
            }
        }
        mainSpecs = [ordered]@{
            passed = $mainPasses
            total = 79
            log = File-Evidence $mainSpecsPath
        }
    }
    gui = [ordered]@{
        evidence = File-Evidence $guiPath
        screenshots = $screenshots
        navigationClicks = 0
        physicalOfflineClicks = 1
        hostedInMainWindow = $true
        sessionTokenCreated = $false
        productionEndpointContacted = $false
    }
    binaries = [ordered]@{
        application = $application
        applicationAssembly = $applicationAssembly
    }
    immutableInputs = [ordered]@{
        frozenWpfInstaller = $installer
        realResoundMc = $realChart
    }
    changedFiles = $changedFiles
    processesAfter = $remainingProcesses
    completion = [ordered]@{
        windowsAvaloniaCanReplaceWpf = $false
        userManualReplacementApprovalReceived = $false
        nextPlatformAuthorized = $false
    }
}
$verification | ConvertTo-Json -Depth 12 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
$verification | ConvertTo-Json -Depth 12
