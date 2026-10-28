param(
    [Parameter(Mandatory = $true)][string]$ArtifactRoot
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "The Windows Avalonia extension-palette gate requires PowerShell Core on Windows."
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
    if ($content -notmatch '0 个警告' -or $content -notmatch '0 个错误') {
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
    & pwsh -NoProfile -File ".\tools\Capture-WindowsAvaloniaVisualParityGui.ps1" `
        -OutputRoot $guiRoot 2>&1 | Tee-Object -FilePath $guiLog
    if ($LASTEXITCODE -ne 0) {
        throw "Windows Avalonia extension-palette GUI gate failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$avaloniaSpecs = Get-Content -LiteralPath $avaloniaSpecsEvidencePath -Raw | ConvertFrom-Json -Depth 100
$passedAvaloniaSpecs = @($avaloniaSpecs.Checks | Where-Object Passed).Count
$failedAvaloniaSpecs = @($avaloniaSpecs.Checks | Where-Object { -not $_.Passed }).Count
if ($avaloniaSpecs.Status -ne "passed" -or $passedAvaloniaSpecs -ne 364 -or
    $avaloniaSpecs.Checks.Count -ne 364 -or $failedAvaloniaSpecs -ne 0) {
    throw "Avalonia Specs are not exactly 364/364 passed."
}
$mainSpecsText = Get-Content -LiteralPath $runMainSpecsLog -Raw
if ($mainSpecsText -notmatch '79/79 specs passed') {
    throw "Main Specs are not exactly 79/79 passed."
}

$guiEvidencePath = Join-Path $guiRoot "visual-parity-gui-evidence.json"
$guiRuntimePath = Join-Path $guiRoot "visual-parity-runtime.json"
$guiReopenRuntimePath = Join-Path $guiRoot "visual-parity-reopened-runtime.json"
$gui = Get-Content -LiteralPath $guiEvidencePath -Raw | ConvertFrom-Json -Depth 100
$runtime = Get-Content -LiteralPath $guiRuntimePath -Raw | ConvertFrom-Json -Depth 100
$expectedCommandPaletteIds = @(
    "Editor.New",
    "Editor.Open",
    "Editor.Save",
    "Editor.Export",
    "Editor.Backup",
    "Editor.RestoreBackup",
    "Editor.Command.PlayPause",
    "Editor.Command.Stop",
    "Editor.Command.Fullscreen",
    "Editor.Command.Undo",
    "Editor.Command.Redo",
    "Editor.ChartCheck",
    "Editor.DifficultyAnalysis",
    "Editor.Extension.Toggle",
    "Editor.Playtest.FromStart",
    "Editor.Playtest.FromHere",
    "ProEditor.Toggle")
$actualCommandPaletteIds = @($gui.shell.commandPalette.items | ForEach-Object automationId)
if ($gui.schema -ne "lumachart.windows.avalonia.visual-parity-gui-evidence.v3" -or
    $gui.status -ne "passed-migration-incomplete" -or
    -not [bool]$gui.realChart.unchanged -or
    -not [bool]$gui.shell.extensionPalette -or
    -not [bool]$gui.shell.extensionPaletteRealPointerDrag -or
    [int]$gui.shell.extensionPaletteRealChartSelection.longNotesExpected -ne 771 -or
    [int]$gui.shell.extensionPaletteRealChartSelection.tapsExpected -ne 1982 -or
    [string]$gui.shell.extensionPaletteRealChartSelection.longNotesHint -cne "已选择 771 个 Note" -or
    [string]$gui.shell.extensionPaletteRealChartSelection.tapsHint -cne "已选择 1982 个 Note" -or
    -not [bool]$gui.shell.commandPalette.wpfThreeGroupLayout -or
    [string]$gui.shell.commandPalette.toggleExpandedGlyph -cne "×" -or
    [string]$gui.shell.commandPalette.toggleCollapsedGlyph -cne "⚙" -or
    [bool]$gui.shell.commandPalette.extraDeveloperToolbarItemsVisible -or
    -not [bool]$gui.shell.commandPalette.proColumnsMovedToSettings -or
    ($actualCommandPaletteIds -join '|') -cne ($expectedCommandPaletteIds -join '|')) {
    throw "Extension/command-palette GUI evidence is incomplete."
}

$installerPath = Join-Path $repositoryRoot "release\LumaChartStudio-Setup.exe"
$installerHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
if ($installerHash -cne "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
    throw "The frozen WPF installer hash changed."
}

$previousAuthorityPath = Join-Path $repositoryRoot `
    "artifacts\windows-avalonia-extension-palette-slice-20260724-r3\evidence.json"
$sourceFiles = @(
    "LumaChart.Avalonia\Editing\WindowsNoteTypeTransformCommand.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "tools\Capture-WindowsAvaloniaVisualParityGui.ps1",
    "tools\Test-WindowsAvaloniaExtensionPaletteSlice.ps1")

$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.extension-and-command-palette-slice-evidence.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    authority = [ordered]@{
        slice = "wpf-extension-palette-and-three-group-command-palette"
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
            passed = 364
            total = 364
            failed = 0
            evidence = Get-FileEvidence $avaloniaSpecsEvidencePath
            extensionFilterCheck = @(
                $avaloniaSpecs.Checks |
                    Where-Object Name -eq "note-transform-extension-filter-keeps-only-visible-selected-type-without-history" |
                    ForEach-Object { [ordered]@{ name = $_.Name; passed = [bool]$_.Passed; detail = $_.Detail } })
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
        realChart = $gui.realChart
        physicalWindow = [ordered]@{
            screenPixels = "$($runtime.window.screenWidthPixels)x$($runtime.window.screenHeightPixels)"
            workAreaPixels = "$($runtime.window.workAreaWidthPixels)x$($runtime.window.workAreaHeightPixels)"
            scaling = [double]$runtime.window.screenScaling
        }
        extensionPalette = [ordered]@{
            wpfContentWidthDip = 194
            headerHeightDip = 28
            actionRowHeightDip = 38
            actions = @("只选中面", "只选中米", "面 → 米", "米 → 面")
            realPointerDrag = $true
            dragDeltaPhysicalPixels = $gui.shell.extensionPaletteDragDelta
            realChartSelection = $gui.shell.extensionPaletteRealChartSelection
            locationPersistedAcrossRestart = $false
            persistenceReason = "WPF 1.1.0 does not persist ExtensionPaletteTransform."
        }
        commandPalette = [ordered]@{
            groups = @("file-playback", "editing-analysis", "pro-editor")
            itemCount = $actualCommandPaletteIds.Count
            itemAutomationIds = $actualCommandPaletteIds
            itemEvidence = $gui.shell.commandPalette.items
            toggleExpandedGlyph = [string]$gui.shell.commandPalette.toggleExpandedGlyph
            toggleCollapsedGlyph = [string]$gui.shell.commandPalette.toggleCollapsedGlyph
            extraDeveloperToolbarItemsVisible = [bool]$gui.shell.commandPalette.extraDeveloperToolbarItemsVisible
            proColumnsMovedToSettings = [bool]$gui.shell.commandPalette.proColumnsMovedToSettings
            pendingFailClosed = @($gui.shell.commandPalette.pendingDisabled)
        }
        screenshots = [ordered]@{
            count = @($gui.screenshots.psobject.Properties).Count
            extensionOpened = Get-FileEvidence (Join-Path $guiRoot "avalonia-editor-extension-palette.png")
            extensionDragged = Get-FileEvidence (Join-Path $guiRoot "avalonia-editor-extension-palette-dragged.png")
        }
        singleTimelineCustomControl = [bool]$runtime.timeline.singleCustomControl
        perNoteAvaloniaControlCount = [int]$runtime.timeline.perNoteAvaloniaControlCount
        visibleAreaClipping = [bool]$runtime.timeline.visibleAreaClipping
        performance = $runtime.timeline.performance
        performanceScope = "Internal CPU/render-entry/synthetic-marker proxies only; not display Present, physical input, 60/120 Hz or WPF A/B."
    }
    implementation = [ordered]@{
        selectionFilteringCreatesHistory = $false
        hiddenGroupsExcluded = $true
        timingSelectionClearedByUiCommand = $true
        noteTypeConversionUsesExistingSharedEngine = $true
        commandPaletteMatchesWpfThreeGroupOrder = $true
        commandPaletteUsesVectorIcons = $true
        commandPaletteShortcutTooltipsAreDynamic = $true
        reworkAndPlaytestPlaceholdersFailClosed = $true
        sourceFiles = @($sourceFiles | ForEach-Object { Get-SourceEvidence $_ })
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
        "The WPF command palette visual structure is present; Rework and both test-play entries remain deliberately disabled until their real vertical slices are implemented.",
        "Inspector/control-template typography, spacing and pixel-level parity remain incomplete.",
        "Final two-client online, physical display/DPI/60-120 Hz WPF A/B, format, non-OLLVM ClientSecurity and installer gates remain incomplete."
    )
}

$evidencePath = Join-Path $artifactRootFullPath "evidence.json"
$temporaryEvidencePath = "$evidencePath.tmp-$([Guid]::NewGuid().ToString('N'))"
try {
    $json = $evidence | ConvertTo-Json -Depth 24
    [IO.File]::WriteAllText($temporaryEvidencePath, $json, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryEvidencePath -Destination $evidencePath
}
finally {
    if (Test-Path -LiteralPath $temporaryEvidencePath) {
        Remove-Item -LiteralPath $temporaryEvidencePath -Force
    }
}

Write-Host "WINDOWS_AVALONIA_EXTENSION_AND_COMMAND_PALETTE_SLICE_OK"
Write-Host "Evidence: $evidencePath"
