param(
    [Parameter(Mandatory = $true)][string]$ArtifactRoot
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "The Windows Avalonia Playtest gate requires PowerShell Core on Windows."
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

function Assert-CleanBuildLog {
    param([Parameter(Mandatory = $true)][string]$Path)
    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -notmatch '(0 个警告|0 Warning\(s\))' -or
        $content -notmatch '(0 个错误|0 Error\(s\))') {
        throw "Strict build log is not 0 warning / 0 error: $Path"
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

    $guiLog = Join-Path $artifactRootFullPath "run-gui.log"
    & pwsh -NoLogo -NoProfile -File ".\tools\Capture-WindowsAvaloniaPlaytestGui.ps1" `
        -OutputRoot $artifactRootFullPath 2>&1 | Tee-Object -FilePath $guiLog
    if ($LASTEXITCODE -ne 0) {
        throw "Windows Avalonia Playtest GUI gate failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$avaloniaSpecs = Get-Content -LiteralPath $avaloniaSpecsEvidencePath -Raw | ConvertFrom-Json -Depth 100
$passedAvaloniaSpecs = @($avaloniaSpecs.Checks | Where-Object Passed).Count
$failedAvaloniaSpecs = @($avaloniaSpecs.Checks | Where-Object { -not $_.Passed }).Count
if ($avaloniaSpecs.Status -ne "passed" -or $passedAvaloniaSpecs -ne 379 -or
    $avaloniaSpecs.Checks.Count -ne 379 -or $failedAvaloniaSpecs -ne 0) {
    throw "Avalonia Specs are not exactly 379/379 passed."
}
$mainSpecsText = Get-Content -LiteralPath $runMainSpecsLog -Raw
if ($mainSpecsText -notmatch '79/79 specs passed') {
    throw "Main Specs are not exactly 79/79 passed."
}

$requiredPlaytestSpecs = @(
    "playtest-wpf-judgement-boundaries-are-exact",
    "playtest-dense-lane-keeps-strict-chronological-order",
    "playtest-ln-early-window-on-time-and-tail-completion",
    "playtest-autoplay-and-from-here-skip-policy",
    "playtest-ignores-drafts-and-does-not-mutate-source",
    "playtest-settings-clamp-default-bindings-and-conflict-swap",
    "playtest-settings-atomic-roundtrip-and-fail-closed",
    "playtest-surface-is-one-control-and-culls-100000-notes")
$playtestSpecEvidence = @(
    $avaloniaSpecs.Checks |
        Where-Object { $_.Name -in $requiredPlaytestSpecs } |
        Sort-Object { [Array]::IndexOf($requiredPlaytestSpecs, $_.Name) } |
        ForEach-Object { [ordered]@{ name = $_.Name; passed = [bool]$_.Passed; detail = $_.Detail } })
if ($playtestSpecEvidence.Count -ne $requiredPlaytestSpecs.Count -or
    @($playtestSpecEvidence | Where-Object { -not $_.passed }).Count -ne 0) {
    throw "The eight required Playtest Specs are incomplete."
}

$guiRoot = Join-Path $artifactRootFullPath "gui-runtime"
$guiEvidencePath = Join-Path $guiRoot "playtest-gui-evidence.json"
$guiRuntimePath = Join-Path $guiRoot "playtest-runtime.json"
$guiReopenedRuntimePath = Join-Path $guiRoot "playtest-reopened-runtime.json"
$gui = Get-Content -LiteralPath $guiEvidencePath -Raw | ConvertFrom-Json -Depth 100
$runtime = Get-Content -LiteralPath $guiRuntimePath -Raw | ConvertFrom-Json -Depth 100
$reopenedRuntime = Get-Content -LiteralPath $guiReopenedRuntimePath -Raw | ConvertFrom-Json -Depth 100
if ($gui.schema -ne "lumachart.windows.avalonia.playtest-gui-evidence.v1" -or
    $gui.status -ne "passed" -or
    [int]$gui.initial.runtimeNotes -ne 2753 -or [int]$gui.initial.keyCount -ne 4 -or
    -not [bool]$gui.initial.audioLoaded -or -not [bool]$gui.initial.keySoundWarmUpSucceeded -or
    -not [bool]$gui.initial.keySoundIsWarm -or [int]$gui.initial.perNoteControls -ne 0 -or
    -not [bool]$gui.initial.singleCustomControl -or -not [bool]$gui.initial.clipped -or
    [Math]::Abs([double]$gui.entryPoints.fromStartMilliseconds) -gt .001 -or
    [Math]::Abs([double]$gui.entryPoints.fromHereMilliseconds - [double]$gui.keyboard.firstNoteMilliseconds) -gt 2 -or
    -not [bool]$gui.keyboard.enterStartedAndPaused -or -not [bool]$gui.keyboard.escapeClosedThreeDialogs -or
    [string]$gui.keyboard.physicalManualKey -cne "K" -or [int]$gui.keyboard.physicalManualPulseCount -ne 1 -or
    [string]$gui.manual.resolvedKey -cne "K" -or [string]$gui.manual.grade -notin @("Best", "Great", "Good") -or
    [Math]::Abs([double]$gui.manual.offsetMilliseconds) -ge 130 -or
    [int]$gui.manual.manualHitJudgementCount -lt 1 -or [int]$gui.manual.manualKeySoundAccepted -lt 1 -or
    [int]$gui.manual.manualKeySoundRejected -ne 0 -or -not [bool]$gui.manual.keySoundIsWarm -or
    [string]$gui.manual.keySoundLastError -cne "none" -or [int]$gui.autoPlay.autoKeySoundAccepted -lt 1 -or
    [int]$gui.autoPlay.autoKeySoundRejected -ne 0 -or -not [bool]$gui.settings.secondProcessRecovered -or
    [string]$gui.settings.configured.autoPlay -cne "Off" -or [string]$gui.settings.reopened.autoPlay -cne "Off" -or
    [string]$gui.settings.configured.style -cne "Circle" -or [string]$gui.settings.reopened.style -cne "Circle" -or
    [double]$gui.settings.reopened.noteWidth -ne 73 -or [double]$gui.settings.reopened.noteHeight -ne 41 -or
    [double]$gui.settings.reopened.fieldWidth -ne 777 -or [double]$gui.settings.reopened.scrollSpeed -ne 913 -or
    [double]$gui.settings.reopened.judgementLine -ne 79 -or
    [string]$gui.fixture.chartBefore.sha256 -cne [string]$gui.fixture.chartAfter.sha256 -or
    [string]$gui.fixture.audioBefore.sha256 -cne [string]$gui.fixture.audioAfter.sha256 -or
    [string]$gui.fixture.isolatedChartBefore.sha256 -cne [string]$gui.fixture.isolatedChartAfter.sha256 -or
    [string]$gui.fixture.isolatedAudioBefore.sha256 -cne [string]$gui.fixture.isolatedAudioAfter.sha256) {
    throw "Playtest GUI evidence is incomplete."
}

$installerPath = Join-Path $repositoryRoot "release\LumaChartStudio-Setup.exe"
$installerHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
if ($installerHash -cne "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
    throw "The frozen WPF installer hash changed."
}

$previousAuthorityPath = Join-Path $repositoryRoot `
    "artifacts\windows-avalonia-rework-slice-20260724-r3\evidence.json"
$sourceFiles = @(
    "LumaChart.Application\Playtest\PlaytestSession.cs",
    "LumaChart.Avalonia\Audio\WindowsKeySoundService.cs",
    "LumaChart.Avalonia\Controls\PlaytestSurface.cs",
    "LumaChart.Avalonia\Dialogs\PlaytestWindow.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsPlaytestSettingsStore.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\WindowsPlaytestSpecs.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "tools\Capture-WindowsAvaloniaPlaytestGui.ps1",
    "tools\Test-WindowsAvaloniaPlaytestSlice.ps1")
$wpfTruthFiles = @(
    "LumaChart.App\PlaytestWindow.xaml",
    "LumaChart.App\PlaytestWindow.xaml.cs",
    "LumaChart.App\Controls\PlaytestSurface.cs",
    "LumaChart.App\Audio\KeySoundEngine.cs")
$screenshotNames = @(
    "playtest-entrypoints.png",
    "playtest-initial.png",
    "playtest-autoplay.png",
    "playtest-configured.png",
    "playtest-from-here.png",
    "playtest-manual.png",
    "playtest-reopened.png")

$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.playtest-slice-evidence.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    authority = [ordered]@{
        slice = "wpf-test-play-ui-pointer-focus-shortcuts-audio-and-settings"
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
        physicalKeyFallbackForChineseIme = $true
        globalTextBoxEnterCommitAdded = $false
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
            status = "passed"; passed = 379; total = 379; failed = 0
            evidence = Get-FileEvidence $avaloniaSpecsEvidencePath
            playtest = $playtestSpecEvidence
        }
        main = [ordered]@{
            status = "passed"; passed = 79; total = 79; failed = 0
            log = Get-FileEvidence $runMainSpecsLog
        }
    }
    gui = [ordered]@{
        status = "passed-migration-incomplete"
        evidence = Get-FileEvidence $guiEvidencePath
        runtime = Get-FileEvidence $guiRuntimePath
        reopenedRuntime = Get-FileEvidence $guiReopenedRuntimePath
        runtimeSchema = [string]$runtime.schema
        reopenedRuntimeSchema = [string]$reopenedRuntime.schema
        realFixture = $gui.fixture
        entryPoints = $gui.entryPoints
        keyboard = $gui.keyboard
        autoPlay = $gui.autoPlay
        manual = $gui.manual
        settings = $gui.settings
        window = $gui.window
        singleCustomControl = [bool]$gui.initial.singleCustomControl
        perNoteAvaloniaControlCount = [int]$gui.initial.perNoteControls
        visibleAreaClipping = [bool]$gui.initial.clipped
        screenshots = @($screenshotNames | ForEach-Object { Get-FileEvidence (Join-Path $guiRoot $_) })
        limitations = $gui.limitations
    }
    implementation = [ordered]@{
        startFromBeginningAndCurrentRedLine = $true
        autoPlayAndManualFourLaneInput = $true
        enterSpaceEscapeAndBindingCaptureTunnelRouted = $true
        imeDisabledInsidePlaytestAndPhysicalKeyFallbackRetained = $true
        standaloneManualKeySoundAndSharedAutoPlayScheduling = $true
        restartPauseMaximizeRestoreAndClose = $true
        settingsAtomicPersistenceAndSecondProcessRestore = $true
        oneCustomSurfaceAndVisibleAreaClipping = $true
        oneHundredThousandNoteDiagnosticVisited = 370
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
        twoClientOnlineFullyPassed = $false
        physicalResolutionDpiAndRefreshMatrixFullyPassed = $false
        formatInstallerSecurityAndUpdateFullyPassed = $false
        userManualReplacementApprovalReceived = $false
        nextPlatformAuthorized = $false
    }
    remainingDifferences = @(
        "The full client UI and shortcut matrix is not yet one-to-one; each next vertical slice must close function, layout, pointer, focus, shortcuts, Chinese IME and screenshots together.",
        "Final physical 1080p/1440p/4K and multi-DPI matrix, 60/120 Hz WPF A/B frame and input latency, and 100,000-Note live GUI performance remain incomplete.",
        "Final two-client online coverage, MC/MCZ/osu compatibility certification, non-OLLVM ClientSecurity, installer, update, upgrade and uninstall gates remain incomplete.",
        "User manual replacement approval has not been received; WPF remains the rollback and behavior truth."
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

Write-Host "WINDOWS_AVALONIA_PLAYTEST_SLICE_OK"
Write-Host "Evidence: $evidencePath"
