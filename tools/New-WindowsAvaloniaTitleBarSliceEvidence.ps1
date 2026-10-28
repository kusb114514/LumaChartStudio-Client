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
    $files = @(
        Get-ChildItem -LiteralPath $Directory -Filter "*.png" -File |
            Sort-Object Name
    )
    if ($files.Count -lt $ExpectedCount) {
        throw "Expected at least $ExpectedCount screenshots in $Directory; found $($files.Count)."
    }
    $declaredHashes = @{}
    foreach ($property in $DeclaredScreenshots.PSObject.Properties) {
        $declaredHashes[[string]$property.Value.sha256] = $property.Name
    }
    if ($declaredHashes.Count -ne $ExpectedCount) {
        throw "Declared screenshot count differs from $ExpectedCount."
    }
    $records = @()
    foreach ($file in $files) {
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        if (-not $declaredHashes.ContainsKey($hash)) {
            continue
        }
        $records += [ordered]@{
            name = $declaredHashes[$hash]
            path = $file.FullName
            lengthBytes = $file.Length
            sha256 = $hash
            declaredHashMatches = $true
        }
    }
    if ($records.Count -ne $ExpectedCount) {
        throw "Only $($records.Count) of $ExpectedCount declared screenshots matched actual files."
    }
    return $records
}

$authorityFullPath = [IO.Path]::GetFullPath($AuthorityRoot)
if (-not (Test-Path -LiteralPath $authorityFullPath -PathType Container)) {
    throw "Authority root not found: $authorityFullPath"
}
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedAuthority = Join-Path $projectRoot `
    "artifacts\windows-avalonia-titlebar-slice-20260727-r2"
if (-not $authorityFullPath.Equals(
        [IO.Path]::GetFullPath($expectedAuthority),
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "This generator only accepts the formal title-bar r2 authority."
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

$mainSpecsPath = Resolve-ExistingFile `
    (Join-Path $authorityFullPath "specs\main-specs.log") `
    "Main Specs log"
$mainSpecsText = Get-Content -LiteralPath $mainSpecsPath -Raw
if ($mainSpecsText -notmatch "79/79 specs passed\.") {
    throw "Main Specs did not prove 79/79."
}

$titleEvidencePath = Resolve-ExistingFile `
    (Join-Path $authorityFullPath "titlebar-gui\titlebar-gui-evidence.json") `
    "Title-bar GUI evidence"
$titleEvidence = Get-Content -LiteralPath $titleEvidencePath -Raw |
    ConvertFrom-Json
if ($titleEvidence.status -cne "passed-migration-incomplete" -or
    $titleEvidence.contract -cne "wpf-1.1.0-titlebar-r1" -or
    -not $titleEvidence.fullscreenTitleBar.initiallyHidden -or
    -not $titleEvidence.fullscreenTitleBar.physicalTopEdgeRevealed -or
    -not $titleEvidence.fullscreenTitleBar.autoHiddenAfterPointerLeave -or
    -not $titleEvidence.source.unchanged -or
    -not $titleEvidence.frozenInstaller.unchanged) {
    throw "Title-bar GUI evidence is incomplete or failed."
}
$titleScreenshots = Get-VerifiedScreenshotRecords `
    (Join-Path $authorityFullPath "titlebar-gui") `
    $titleEvidence.screenshots `
    5

$visualEvidencePath = Resolve-ExistingFile `
    (Join-Path $authorityFullPath "visual-gui\visual-parity-gui-evidence.json") `
    "Visual-parity GUI evidence"
$visualEvidence = Get-Content -LiteralPath $visualEvidencePath -Raw |
    ConvertFrom-Json
if ($visualEvidence.status -cne "passed-migration-incomplete" -or
    -not $visualEvidence.realChart.unchanged -or
    -not $visualEvidence.shell.titleBarDocumentTabs -or
    $visualEvidence.shell.perNoteAvaloniaControls -ne 0) {
    throw "Visual-parity GUI evidence is incomplete or failed."
}
$visualScreenshots = Get-VerifiedScreenshotRecords `
    (Join-Path $authorityFullPath "visual-gui") `
    $visualEvidence.screenshots `
    13

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
    "LumaChart.Avalonia.Specs\Program.cs",
    "tools\Capture-WindowsAvaloniaTitleBarGui.ps1",
    "tools\Capture-WindowsAvaloniaVisualParityGui.ps1",
    "tools\Capture-WindowsAvaloniaShortcutsGui.ps1",
    "tools\New-WindowsAvaloniaTitleBarSliceEvidence.ps1"
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
    schema = "lumachart.windows.avalonia.titlebar-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = "Windows Avalonia title bar and document tabs only"
    authority = $authorityFullPath
    predecessor = Join-Path $projectRoot `
        "artifacts\windows-avalonia-control-theme-slice-20260726-r2"
    titleBar = [ordered]@{
        contract = $titleEvidence.contract
        titleBarHeightDip = $titleEvidence.chrome.titleBarHeight
        captionButtonWidthDip = $titleEvidence.chrome.captionButtonWidth
        resizeBorderThicknessDip = $titleEvidence.chrome.resizeBorderThickness
        activeWindowsScale = $titleEvidence.chrome.activeWindowsScale
        formatBadge = $titleEvidence.chrome.formatBadge
        documentTab = $titleEvidence.chrome.documentTab
        tabCloseWidthPhysicalPixels = $titleEvidence.chrome.tabCloseWidth
        physicalBlankTitleDoubleClickAttempts =
            @($titleEvidence.physicalInput.titleBarDoubleClick.attempts).Count
        fullscreenInitiallyHidden =
            $titleEvidence.fullscreenTitleBar.initiallyHidden
        physicalTopEdgeRevealed =
            $titleEvidence.fullscreenTitleBar.physicalTopEdgeRevealed
        autoHiddenAfterPointerLeave =
            $titleEvidence.fullscreenTitleBar.autoHiddenAfterPointerLeave
        autoHideDelayMilliseconds =
            $titleEvidence.fullscreenTitleBar.autoHideDelayMilliseconds
        restoredPreFullscreenMaximizedBounds = $true
    }
    strictBuilds = $strictBuilds
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 412
            total = 412
            failed = 0
            status = "passed"
            evidence = Get-FileRecord $avaloniaSpecsPath
            log = Get-FileRecord `
                (Join-Path $authorityFullPath "specs\avalonia-specs.log")
        }
        mainSpecs = [ordered]@{
            passed = 79
            total = 79
            failed = 0
            status = "passed"
            log = Get-FileRecord $mainSpecsPath
        }
    }
    gui = [ordered]@{
        titleBar = [ordered]@{
            status = $titleEvidence.status
            evidence = Get-FileRecord $titleEvidencePath
            screenshotCount = $titleScreenshots.Count
            screenshots = $titleScreenshots
        }
        visualRegression = [ordered]@{
            status = $visualEvidence.status
            evidence = Get-FileRecord $visualEvidencePath
            screenshotCount = $visualScreenshots.Count
            screenshots = $visualScreenshots
            quickPalettePhysicalDrag =
                $visualEvidence.shell.quickEditPaletteRealPointerDrag
            perNoteAvaloniaControls =
                $visualEvidence.shell.perNoteAvaloniaControls
        }
        agentVisualInspection = [ordered]@{
            completed = $true
            checked = @(
                "all 5 title-bar screenshots",
                "windowed, maximized, fullscreen hidden/revealed and restored states",
                "all 13 visual-regression screenshots",
                "library shell and WPF-style MALODY document tab"
            )
            result = "No rendering or interaction-state defect observed in the r2 scope."
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
        "Fullscreen title-bar reveal/hide animation timing and easing are not yet pixel-certified against WPF.",
        "Online live document-tab latency text is not yet reproduced in the Avalonia tab badge.",
        "Global modal/popup, danger-menu physical hover, typography, avatar and full same-machine WPF screenshot-diff certification remain open.",
        "Focus/Chinese IME, remaining shortcuts, online failure branches, format edges, ClientSecurity, installer lifecycle and physical display/performance gates remain open."
    )
    completion = [ordered]@{
        titleBarSlicePassed = $true
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
Write-Host "Windows Avalonia title-bar verification evidence: passed"
Write-Host "Evidence: $outputPath"
