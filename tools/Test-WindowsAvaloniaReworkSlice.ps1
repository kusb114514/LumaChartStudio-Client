param(
    [Parameter(Mandatory = $true)][string]$ArtifactRoot
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "The Windows Avalonia Rework gate requires PowerShell Core on Windows."
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$artifactRootFullPath = [IO.Path]::GetFullPath($ArtifactRoot)
$artifactBoundary = [IO.Path]::GetFullPath((Join-Path $repositoryRoot "artifacts")).TrimEnd('\') + '\'
if (-not $artifactRootFullPath.StartsWith($artifactBoundary, [StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactRoot must stay under $artifactBoundary"
}
if (Test-Path -LiteralPath $artifactRootFullPath) {
    if (Get-ChildItem -LiteralPath $artifactRootFullPath -Force | Select-Object -First 1) {
        throw "Formal artifact root must be new and empty: $artifactRootFullPath"
    }
}
New-Item -ItemType Directory -Path $artifactRootFullPath -Force | Out-Null

$dotnetHome = Join-Path $repositoryRoot ".codex-dotnet-home"
$nugetPackages = Join-Path $repositoryRoot ".codex-nuget-packages"
$nugetHttpCache = Join-Path $repositoryRoot ".codex-nuget-http-cache"
$projectTemp = Join-Path $repositoryRoot ".codex-temp"
foreach ($directory in @($dotnetHome, $nugetPackages, $nugetHttpCache, $projectTemp)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
$env:DOTNET_CLI_HOME = $dotnetHome
$env:NUGET_PACKAGES = $nugetPackages
$env:NUGET_HTTP_CACHE_PATH = $nugetHttpCache
$env:TEMP = $projectTemp
$env:TMP = $projectTemp

function Invoke-DotnetLogged {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$LogPath
    )
    & dotnet @Arguments 2>&1 | Tee-Object -FilePath $LogPath
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

function Get-FileEvidence {
    param([Parameter(Mandatory = $true)][string]$Path)
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Required evidence file is missing: $fullPath"
    }
    $item = Get-Item -LiteralPath $fullPath
    return [ordered]@{
        path = [IO.Path]::GetRelativePath($artifactRootFullPath, $fullPath).Replace('\', '/')
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    }
}

function Get-SourceEvidence {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $fullPath = Join-Path $repositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Required source file is missing: $fullPath"
    }
    $item = Get-Item -LiteralPath $fullPath
    return [ordered]@{
        path = $RelativePath.Replace('\', '/')
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    }
}

function Assert-CleanBuildLog {
    param([Parameter(Mandatory = $true)][string]$Path)
    $content = Get-Content -LiteralPath $Path -Raw
    $zeroWarnings = $content -match '(0 个警告|0 Warning\(s\))'
    $zeroErrors = $content -match '(0 个错误|0 Error\(s\))'
    if (-not $zeroWarnings -or -not $zeroErrors) {
        throw "Strict build log is not 0 warning / 0 error: $Path"
    }
}

Push-Location $repositoryRoot
try {
    $buildAvaloniaLog = Join-Path $artifactRootFullPath "build-avalonia.log"
    Invoke-DotnetLogged -LogPath $buildAvaloniaLog -Arguments @(
        "build", ".\LumaChart.Avalonia\LumaChart.Avalonia.csproj",
        "-c", "Release", "--no-restore", "-m:1",
        "-p:TreatWarningsAsErrors=true", "-p:UseSharedCompilation=false", "-nr:false")

    $buildAvaloniaSpecsLog = Join-Path $artifactRootFullPath "build-avalonia-specs.log"
    Invoke-DotnetLogged -LogPath $buildAvaloniaSpecsLog -Arguments @(
        "build", ".\LumaChart.Avalonia.Specs\LumaChart.Avalonia.Specs.csproj",
        "-c", "Release", "--no-restore", "-m:1",
        "-p:TreatWarningsAsErrors=true", "-p:UseSharedCompilation=false", "-nr:false")

    $avaloniaSpecsEvidencePath = Join-Path $artifactRootFullPath "avalonia-specs-evidence.json"
    $runAvaloniaSpecsLog = Join-Path $artifactRootFullPath "run-avalonia-specs.log"
    Invoke-DotnetLogged -LogPath $runAvaloniaSpecsLog -Arguments @(
        "run", "--project", ".\LumaChart.Avalonia.Specs\LumaChart.Avalonia.Specs.csproj",
        "-c", "Release", "--no-build", "--", "--output", $avaloniaSpecsEvidencePath)

    $buildMainSpecsLog = Join-Path $artifactRootFullPath "build-main-specs.log"
    Invoke-DotnetLogged -LogPath $buildMainSpecsLog -Arguments @(
        "build", ".\LumaChart.Specs\LumaChart.Specs.csproj",
        "-c", "Release", "--no-restore", "-m:1",
        "-p:TreatWarningsAsErrors=true", "-p:UseSharedCompilation=false", "-nr:false")

    $runMainSpecsLog = Join-Path $artifactRootFullPath "run-main-specs.log"
    Invoke-DotnetLogged -LogPath $runMainSpecsLog -Arguments @(
        "run", "--project", ".\LumaChart.Specs\LumaChart.Specs.csproj",
        "-c", "Release", "--no-build")

    foreach ($log in @($buildAvaloniaLog, $buildAvaloniaSpecsLog, $buildMainSpecsLog)) {
        Assert-CleanBuildLog $log
    }

    $guiRoot = Join-Path $artifactRootFullPath "gui-runtime"
    $guiLog = Join-Path $artifactRootFullPath "run-gui.log"
    & pwsh -NoLogo -NoProfile -File ".\tools\Capture-WindowsAvaloniaDifficultyGui.ps1" `
        -OutputRoot $artifactRootFullPath 2>&1 | Tee-Object -FilePath $guiLog
    if ($LASTEXITCODE -ne 0) {
        throw "Windows Avalonia Rework GUI gate failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$avaloniaSpecs = Get-Content -LiteralPath $avaloniaSpecsEvidencePath -Raw | ConvertFrom-Json -Depth 100
$passedAvaloniaSpecs = @($avaloniaSpecs.Checks | Where-Object Passed).Count
$failedAvaloniaSpecs = @($avaloniaSpecs.Checks | Where-Object { -not $_.Passed }).Count
if ($avaloniaSpecs.Status -ne "passed" -or $passedAvaloniaSpecs -ne 371 -or
    $avaloniaSpecs.Checks.Count -ne 371 -or $failedAvaloniaSpecs -ne 0) {
    throw "Avalonia Specs are not exactly 371/371 passed."
}
$mainSpecsText = Get-Content -LiteralPath $runMainSpecsLog -Raw
if ($mainSpecsText -notmatch '79/79 specs passed') {
    throw "Main Specs are not exactly 79/79 passed."
}

$requiredReworkSpecs = @(
    "rework-real-resound-4k-counts-peaks-and-source-immutable",
    "rework-drafts-are-ignored-and-analysis-does-not-create-history",
    "rework-non-4k-and-fewer-than-two-official-notes-fail-closed",
    "rework-od-clamps-to-zero-ten-and-supports-tenth-step-recalculation",
    "rework-stale-tab-or-change-serial-result-is-rejected",
    "difficulty-overview-is-single-control-eight-peak-clipped-and-invertible",
    "difficulty-card-avoids-track-auto-collapses-and-clamps-drag")
$reworkSpecEvidence = @(
    $avaloniaSpecs.Checks |
        Where-Object { $_.Name -in $requiredReworkSpecs } |
        Sort-Object { [Array]::IndexOf($requiredReworkSpecs, $_.Name) } |
        ForEach-Object { [ordered]@{ name = $_.Name; passed = [bool]$_.Passed; detail = $_.Detail } })
if ($reworkSpecEvidence.Count -ne $requiredReworkSpecs.Count -or
    @($reworkSpecEvidence | Where-Object { -not $_.passed }).Count -ne 0) {
    throw "The seven required Rework Specs are incomplete."
}

$guiEvidencePath = Join-Path $guiRoot "difficulty-gui-evidence.json"
$guiRuntimePath = Join-Path $guiRoot "difficulty-runtime.json"
$guiReopenRuntimePath = Join-Path $guiRoot "difficulty-reopened-runtime.json"
$gui = Get-Content -LiteralPath $guiEvidencePath -Raw | ConvertFrom-Json -Depth 100
$runtime = Get-Content -LiteralPath $guiRuntimePath -Raw | ConvertFrom-Json -Depth 100
$requiredGuiChecks = @(
    "realResoundGuiOpened",
    "resultDialogVisualAndMetrics",
    "escapeShortcut",
    "odMouseAutomationAndKeyboard",
    "peakNavigation",
    "diffOverviewPhysicalClickAndDrag",
    "cardPhysicalCollapseExpandAndDrag",
    "cardSecondProcessRestore",
    "sourceAndWorkingFixturesUnchanged")
if ($gui.schema -ne "lumachart.windows.avalonia.rework-gui-evidence.v1" -or
    $gui.status -ne "passed" -or
    [int]$gui.analysis.peakButtonCount -ne 8 -or
    [string]$gui.analysis.odRangeValueRecalculation -cne "7.3" -or
    [string]$gui.analysis.odKeyboardRightRecalculation -cne "7.4" -or
    [int]$gui.overview.perPeakControls -ne 0 -or
    [Math]::Abs([double]$gui.card.dragDelta.x) -lt 20 -or
    [Math]::Abs([double]$gui.card.dragDelta.y) -lt 20 -or
    -not [bool]$gui.card.secondProcessRestore -or
    [string]$gui.chart.sourceSha256Before -cne [string]$gui.chart.sourceSha256After -or
    [string]$gui.chart.workingSha256Before -cne [string]$gui.chart.workingSha256After) {
    throw "Rework GUI evidence is incomplete."
}
foreach ($check in $requiredGuiChecks) {
    if (-not [bool]$gui.checks.$check) {
        throw "Required Rework GUI check failed: $check"
    }
}

$installerPath = Join-Path $repositoryRoot "release\LumaChartStudio-Setup.exe"
$installerHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
if ($installerHash -cne "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
    throw "The frozen WPF installer hash changed."
}

$previousAuthorityPath = Join-Path $repositoryRoot `
    "artifacts\windows-avalonia-command-palette-slice-20260724-r1\evidence.json"
$sourceFiles = @(
    "LumaChart.Avalonia\Controls\AutomationBorder.cs",
    "LumaChart.Avalonia\Controls\DifficultyOverviewSurface.cs",
    "LumaChart.Avalonia\Dialogs\DifficultyAnalysisWindow.cs",
    "LumaChart.Avalonia\Editing\WindowsDifficultyUiPolicy.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsEditorViewSettingsStore.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\WindowsDifficultySpecs.cs",
    "LumaChart.Avalonia.Specs\WindowsSettingsCacheSpecs.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "tools\Capture-WindowsAvaloniaDifficultyGui.ps1",
    "tools\Test-WindowsAvaloniaReworkSlice.ps1")
$wpfTruthFiles = @(
    "LumaChart.App\Controls\DifficultyOverviewSurface.cs",
    "LumaChart.App\DifficultyAnalysisWindow.xaml",
    "LumaChart.App\DifficultyAnalysisWindow.xaml.cs")
$screenshotNames = @(
    "difficulty-card-before.png",
    "difficulty-card-collapsed.png",
    "difficulty-card-dragged.png",
    "difficulty-card-reopened.png",
    "difficulty-dialog-initial.png",
    "difficulty-dialog-od74.png")

$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.rework-slice-evidence.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    authority = [ordered]@{
        slice = "wpf-4k-rework-dialog-overview-card-and-navigation"
        previous = [ordered]@{
            path = [IO.Path]::GetRelativePath($repositoryRoot, $previousAuthorityPath).Replace('\', '/')
            length = (Get-Item -LiteralPath $previousAuthorityPath).Length
            sha256 = (Get-FileHash -LiteralPath $previousAuthorityPath -Algorithm SHA256).Hash
        }
        supersedesPreviousForCurrentWorktree = $true
    }
    scope = [ordered]@{
        windowsAvaloniaOnly = $true
        androidIosMacosLinuxWebModifiedBuiltInstalledOrTested = $false
        mobileWorkloadInstalled = $false
        productionServerDeployed = $false
        releaseInstallerOverwritten = $false
        ollvmExecutedOrRequired = $false
        userRunningClientsClosed = $false
        chineseImeGlobalEnterEscapeHandlerAdded = $false
    }
    cacheBoundary = [ordered]@{
        dotnetCliHome = $dotnetHome
        nugetPackages = $nugetPackages
        nugetHttpCache = $nugetHttpCache
        temp = $projectTemp
        cDriveDotnetNugetTempCacheUsedForThisSlice = $false
    }
    builds = [ordered]@{
        avalonia = [ordered]@{ warnings = 0; errors = 0; log = Get-FileEvidence $buildAvaloniaLog }
        avaloniaSpecs = [ordered]@{ warnings = 0; errors = 0; log = Get-FileEvidence $buildAvaloniaSpecsLog }
        mainSpecs = [ordered]@{ warnings = 0; errors = 0; log = Get-FileEvidence $buildMainSpecsLog }
    }
    tests = [ordered]@{
        avalonia = [ordered]@{
            status = "passed"
            passed = 371
            total = 371
            failed = 0
            evidence = Get-FileEvidence $avaloniaSpecsEvidencePath
            rework = $reworkSpecEvidence
        }
        main = [ordered]@{
            status = "passed"
            passed = 79
            total = 79
            failed = 0
            log = Get-FileEvidence $runMainSpecsLog
        }
    }
    gui = [ordered]@{
        status = "passed-migration-incomplete"
        evidence = Get-FileEvidence $guiEvidencePath
        runtime = Get-FileEvidence $guiRuntimePath
        reopenedRuntime = Get-FileEvidence $guiReopenRuntimePath
        runtimeSchema = [string]$runtime.schema
        realChart = $gui.chart
        physicalWindow = [ordered]@{
            screenPixels = "$($runtime.window.screenWidthPixels)x$($runtime.window.screenHeightPixels)"
            workAreaPixels = "$($runtime.window.workAreaWidthPixels)x$($runtime.window.workAreaHeightPixels)"
            scaling = [double]$runtime.window.screenScaling
        }
        analysis = $gui.analysis
        overview = $gui.overview
        card = $gui.card
        checks = $gui.checks
        screenshots = @($screenshotNames | ForEach-Object { Get-FileEvidence (Join-Path $guiRoot $_) })
        singleTimelineCustomControl = [bool]$runtime.timeline.singleCustomControl
        perNoteAvaloniaControlCount = [int]$runtime.timeline.perNoteAvaloniaControlCount
        visibleAreaClipping = [bool]$runtime.timeline.visibleAreaClipping
        performance = $runtime.timeline.performance
        performanceScope = "Internal CPU/render-entry/synthetic-marker proxies only; not display Present, physical input, 60/120 Hz or WPF A/B."
    }
    implementation = [ordered]@{
        backgroundCloneAnalysisDoesNotMutateDocumentOrHistory = $true
        staleTabOrChangeSerialResultRejected = $true
        fourKeyOnlyFailClosed = $true
        odDebounceMilliseconds = 180
        odKeyboardStep = 0.1
        overviewSingleCustomControl = $true
        perPeakAvaloniaControlCount = 0
        cardPositionAndCollapsePersisted = $true
        commandPaletteLayerOrderMatchesWpf = $true
        sourceFiles = @($sourceFiles | ForEach-Object { Get-SourceEvidence $_ })
        wpfTruthFiles = @($wpfTruthFiles | ForEach-Object { Get-SourceEvidence $_ })
    }
    frozenReleaseInstaller = [ordered]@{
        path = "release/LumaChartStudio-Setup.exe"
        length = (Get-Item -LiteralPath $installerPath).Length
        sha256 = $installerHash
        unchanged = $true
    }
    completion = [ordered]@{
        windowsAvaloniaCanReplaceWpf = $false
        functionMatrixFullyPassed = $false
        userManualReplacementApprovalReceived = $false
        nextPlatformAuthorized = $false
    }
    remainingDifferences = @(
        "Rework is now active; both WPF test-play entries remain disabled until the next real vertical slice implements their UI, pointer, focus and shortcut behavior.",
        "Inspector/control-template typography, spacing and pixel-level parity remain incomplete and must be closed alongside each remaining functional slice.",
        "Final two-client online, physical 1080p/1440p/4K and DPI matrix, 60/120 Hz WPF A/B, format, non-OLLVM ClientSecurity and installer gates remain incomplete."
    )
}

$evidencePath = Join-Path $artifactRootFullPath "evidence.json"
$temporaryEvidencePath = "$evidencePath.tmp-$([Guid]::NewGuid().ToString('N'))"
try {
    $json = $evidence | ConvertTo-Json -Depth 32
    [IO.File]::WriteAllText($temporaryEvidencePath, $json, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryEvidencePath -Destination $evidencePath
}
finally {
    if (Test-Path -LiteralPath $temporaryEvidencePath) {
        Remove-Item -LiteralPath $temporaryEvidencePath -Force
    }
}

Write-Host "WINDOWS_AVALONIA_REWORK_SLICE_OK"
Write-Host "Evidence: $evidencePath"
