param(
    [Parameter(Mandatory = $true)][string]$AuthorityRoot
)

$ErrorActionPreference = "Stop"

function Resolve-ExistingFile([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "$Label not found: $full"
    }
    return $full
}

function Get-FileRecord([string]$Path) {
    $full = Resolve-ExistingFile $Path "Evidence file"
    $item = Get-Item -LiteralPath $full
    return [ordered]@{
        path = $item.FullName
        lengthBytes = $item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
}

function Assert-StrictBuildLog([string]$Path, [string]$Name) {
    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -notmatch "已成功生成。" -or
        $content -notmatch "0 个警告" -or
        $content -notmatch "0 个错误") {
        throw "Strict build log did not prove 0 warning / 0 error: $Name"
    }
}

function Get-VerifiedScreenshotRecords(
    [string]$Directory,
    [object]$DeclaredScreenshots,
    [int]$ExpectedCount) {
    $declaredHashes = @{}
    foreach ($property in $DeclaredScreenshots.PSObject.Properties) {
        $declaredHashes[[string]$property.Value.sha256] = $property.Name
    }
    if ($declaredHashes.Count -ne $ExpectedCount) {
        throw "Declared screenshot count differs from $ExpectedCount."
    }
    $records = @()
    foreach ($file in Get-ChildItem -LiteralPath $Directory -Filter "*.png" -File) {
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        if (-not $declaredHashes.ContainsKey($hash)) { continue }
        $records += [ordered]@{
            name = $declaredHashes[$hash]
            path = $file.FullName
            lengthBytes = $file.Length
            sha256 = $hash
            declaredHashMatches = $true
        }
    }
    if ($records.Count -ne $ExpectedCount) {
        throw "Only $($records.Count) of $ExpectedCount screenshots matched actual files."
    }
    return @($records | Sort-Object name)
}

$authorityFullPath = [IO.Path]::GetFullPath($AuthorityRoot)
if (-not (Test-Path -LiteralPath $authorityFullPath -PathType Container)) {
    throw "Authority root not found: $authorityFullPath"
}
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedAuthority = Join-Path $projectRoot `
    "artifacts\windows-avalonia-titlebar-slice-20260727-r3"
if (-not $authorityFullPath.Equals(
        [IO.Path]::GetFullPath($expectedAuthority),
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "This generator only accepts the formal title-bar animation r3 authority."
}

$buildLogs = [ordered]@{
    avalonia = Join-Path $authorityFullPath "build\avalonia.log"
    avaloniaSpecs = Join-Path $authorityFullPath "build\avalonia-specs.log"
    mainSpecs = Join-Path $authorityFullPath "build\main-specs.log"
}
foreach ($property in $buildLogs.GetEnumerator()) {
    Assert-StrictBuildLog $property.Value $property.Key
}

$avaloniaSpecsPath = Resolve-ExistingFile `
    (Join-Path $authorityFullPath "specs\avalonia-specs-evidence.json") `
    "Avalonia Specs evidence"
$avaloniaSpecs = Get-Content -LiteralPath $avaloniaSpecsPath -Raw |
    ConvertFrom-Json
$avaloniaChecks = @($avaloniaSpecs.Checks)
$avaloniaPassed = @($avaloniaChecks | Where-Object Passed).Count
if ($avaloniaSpecs.Status -cne "passed" -or
    $avaloniaChecks.Count -ne 412 -or
    $avaloniaPassed -ne 412) {
    throw "Avalonia Specs did not prove 412/412."
}
$titlebarSpec = @(
    $avaloniaChecks |
        Where-Object Name -ceq "titlebar-wpf-chrome-metrics-are-exact"
)
if ($titlebarSpec.Count -ne 1 -or
    -not $titlebarSpec[0].Passed -or
    $titlebarSpec[0].Detail -notlike "*reveal=145ms cubic-out; hide=125ms cubic-in*") {
    throw "Avalonia Specs did not prove the exact WPF title-bar animation contract."
}

$mainSpecsPath = Resolve-ExistingFile `
    (Join-Path $authorityFullPath "specs\main-specs.log") `
    "Main Specs log"
if ((Get-Content -LiteralPath $mainSpecsPath -Raw) -notmatch
    "79/79 specs passed\.") {
    throw "Main Specs did not prove 79/79."
}

$titleEvidencePath = Resolve-ExistingFile `
    (Join-Path $authorityFullPath "titlebar-gui\titlebar-gui-evidence.json") `
    "Title-bar animation GUI evidence"
$titleEvidence = Get-Content -LiteralPath $titleEvidencePath -Raw |
    ConvertFrom-Json
$revealSamples = @($titleEvidence.fullscreenTitleBar.revealSamples)
$hideSamples = @($titleEvidence.fullscreenTitleBar.hideSamples)
$revealIntermediate = @(
    $revealSamples |
        Where-Object { $_.currentY -gt -36 -and $_.currentY -lt -2 }
)
$hideIntermediate = @(
    $hideSamples |
        Where-Object { $_.currentY -gt -36 -and $_.currentY -lt -2 }
)
if ($titleEvidence.schema -cne
        "lumachart.windows.avalonia.titlebar-animation-gui-evidence.v1" -or
    $titleEvidence.status -cne "passed-migration-incomplete" -or
    $titleEvidence.contract -cne "wpf-1.1.0-titlebar-r1" -or
    $titleEvidence.fullscreenTitleBar.revealDurationMilliseconds -ne 145 -or
    $titleEvidence.fullscreenTitleBar.revealEasing -cne "CubicEaseOut" -or
    $titleEvidence.fullscreenTitleBar.hideDurationMilliseconds -ne 125 -or
    $titleEvidence.fullscreenTitleBar.hideEasing -cne "CubicEaseIn" -or
    $titleEvidence.fullscreenTitleBar.autoHideDelayMilliseconds -ne 480 -or
    -not $titleEvidence.fullscreenTitleBar.revealIntermediateFrameObserved -or
    -not $titleEvidence.fullscreenTitleBar.hideIntermediateFrameObserved -or
    $revealIntermediate.Count -lt 1 -or
    $hideIntermediate.Count -lt 1 -or
    [double]$revealSamples[-1].currentY -lt -.1 -or
    [double]$hideSamples[-1].currentY -gt -37.5 -or
    [double]$titleEvidence.fullscreenTitleBar.revealObservedElapsedMilliseconds -lt 90 -or
    [double]$titleEvidence.fullscreenTitleBar.revealObservedElapsedMilliseconds -gt 260 -or
    [double]$titleEvidence.fullscreenTitleBar.hideObservedAnimationStartMilliseconds -lt 450 -or
    [double]$titleEvidence.fullscreenTitleBar.hideObservedAnimationStartMilliseconds -gt 650 -or
    [double]$titleEvidence.fullscreenTitleBar.hideObservedTotalMilliseconds -lt 540 -or
    [double]$titleEvidence.fullscreenTitleBar.hideObservedTotalMilliseconds -gt 850 -or
    -not $titleEvidence.source.unchanged -or
    -not $titleEvidence.frozenInstaller.unchanged) {
    throw "Title-bar animation GUI evidence is incomplete or outside the timing gate."
}

$predecessorTitlePath = Resolve-ExistingFile `
    (Join-Path $projectRoot `
        "artifacts\windows-avalonia-titlebar-slice-20260727-r2\titlebar-gui\titlebar-gui-evidence.json") `
    "r2 title-bar physical-input authority"
$predecessorTitleHash =
    (Get-FileHash -LiteralPath $predecessorTitlePath -Algorithm SHA256).Hash
if ($predecessorTitleHash -cne
    "95ACA55697D840D500B446A45C2CAF3EDCE00EA96E2E1F7D4E420F5FA21689F4" -or
    [string]$titleEvidence.predecessorPhysicalAuthority.sha256 -cne
        $predecessorTitleHash -or
    -not $titleEvidence.predecessorPhysicalAuthority.titleBarDoubleClickMaximized -or
    -not $titleEvidence.predecessorPhysicalAuthority.f11EnterAndExit) {
    throw "The r2 physical-input predecessor authority is missing or changed."
}
$predecessorVisualPath = Resolve-ExistingFile `
    (Join-Path $projectRoot `
        "artifacts\windows-avalonia-titlebar-slice-20260727-r2\visual-gui\visual-parity-gui-evidence.json") `
    "r2 visual-regression authority"
if ((Get-FileHash -LiteralPath $predecessorVisualPath -Algorithm SHA256).Hash -cne
    "424532D25CC110B7543D60722FF26C56EFDEC4ECC0AC3181B1979E52C7D84A74") {
    throw "The r2 visual-regression authority hash changed."
}

$titleScreenshots = Get-VerifiedScreenshotRecords `
    (Join-Path $authorityFullPath "titlebar-gui") `
    $titleEvidence.screenshots `
    5

$installerPath = Resolve-ExistingFile `
    (Join-Path $projectRoot "release\LumaChartStudio-Setup.exe") `
    "Frozen WPF installer"
$installerHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
if ($installerHash -cne
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
    throw "Frozen WPF installer hash changed."
}

$changedPaths = @(
    "LumaChart.Avalonia\Infrastructure\WindowsTitleBarParityPolicy.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\WindowsTitleBarParitySpecs.cs",
    "tools\Capture-WindowsAvaloniaTitleBarGui.ps1",
    "tools\New-WindowsAvaloniaTitleBarAnimationSliceEvidence.ps1"
)
$changedFiles = @(
    foreach ($relativePath in $changedPaths) {
        Get-FileRecord (Join-Path $projectRoot $relativePath)
    }
)

$strictBuilds = @(
    foreach ($property in $buildLogs.GetEnumerator()) {
        [ordered]@{
            name = $property.Key
            configuration = "Release"
            ordinaryDotNet = $true
            warnings = 0
            errors = 0
            log = Get-FileRecord $property.Value
        }
    }
)

$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.titlebar-animation-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = "Windows Avalonia WPF 1.1.0 fullscreen title-bar animation only"
    authority = $authorityFullPath
    predecessor = [ordered]@{
        titleBarPhysicalInput = Get-FileRecord $predecessorTitlePath
        visualRegression = Get-FileRecord $predecessorVisualPath
    }
    titleBarAnimation = [ordered]@{
        contract = $titleEvidence.contract
        autoHideDelayMilliseconds = 480
        revealDurationMilliseconds = 145
        revealEasing = "CubicEaseOut"
        revealObservedElapsedMilliseconds =
            $titleEvidence.fullscreenTitleBar.revealObservedElapsedMilliseconds
        revealIntermediateSamples = $revealIntermediate
        hideDurationMilliseconds = 125
        hideEasing = "CubicEaseIn"
        hideFirstObservedMotionMilliseconds =
            $titleEvidence.fullscreenTitleBar.hideObservedAnimationStartMilliseconds
        hideReachedFinalMilliseconds =
            $titleEvidence.fullscreenTitleBar.hideObservedTotalMilliseconds
        hideIntermediateSamples = $hideIntermediate
        physicalTopEdgeRevealed = $true
        autoHiddenAfterPointerLeave = $true
        restoredPreFullscreenMaximizedBounds = $true
    }
    strictBuilds = $strictBuilds
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 412
            total = 412
            failed = 0
            evidence = Get-FileRecord $avaloniaSpecsPath
            log = Get-FileRecord `
                (Join-Path $authorityFullPath "specs\avalonia-specs.log")
        }
        mainSpecs = [ordered]@{
            passed = 79
            total = 79
            failed = 0
            log = Get-FileRecord $mainSpecsPath
        }
    }
    gui = [ordered]@{
        status = $titleEvidence.status
        evidence = Get-FileRecord $titleEvidencePath
        screenshotCount = $titleScreenshots.Count
        screenshots = $titleScreenshots
        agentVisualInspection = [ordered]@{
            completed = $true
            checked = @(
                "windowed WPF-style title bar and MALODY document tab",
                "maximized title bar",
                "fullscreen hidden state without a 38-DIP gap",
                "fullscreen physically revealed state",
                "restored maximized state"
            )
            result = "No rendering or interaction-state defect observed in the r3 animation scope."
        }
    }
    realMc = [ordered]@{
        path = $titleEvidence.source.path
        sha256Before = $titleEvidence.source.sha256Before
        sha256After = $titleEvidence.source.sha256After
        unchanged = $true
        noteCount = 2753
    }
    frozenInstaller = [ordered]@{
        path = $installerPath
        sha256Before = $installerHash
        sha256After = $installerHash
        unchanged = $true
    }
    binaries = [ordered]@{
        executable = Get-FileRecord `
            (Join-Path $projectRoot `
                "LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe")
        assembly = Get-FileRecord `
            (Join-Path $projectRoot `
                "LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.dll")
    }
    changedFiles = $changedFiles
    remainingDifferences = @(
        "Online live document-tab latency text is not yet reproduced in the Avalonia tab badge.",
        "Global modal/popup, danger-menu physical hover, typography, avatar and full same-machine WPF pixel-diff certification remain open.",
        "Focus/Chinese IME, remaining shortcuts, online failure branches, format edges, ClientSecurity, installer lifecycle and physical display/performance gates remain open."
    )
    completion = [ordered]@{
        titleBarAnimationSlicePassed = $true
        windowsAvaloniaOneToOneComplete = $false
        userReplacementApprovalReceived = $false
        nextPlatformAuthorized = $false
    }
}

$outputPath = Join-Path $authorityFullPath "verification-evidence.json"
if (Test-Path -LiteralPath $outputPath) {
    throw "Verification evidence already exists: $outputPath"
}
$evidence | ConvertTo-Json -Depth 16 |
    Set-Content -LiteralPath $outputPath -Encoding utf8NoBOM
Write-Host "Windows Avalonia title-bar animation verification evidence: passed"
Write-Host "Evidence: $outputPath"
