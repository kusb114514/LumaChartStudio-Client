param(
    [Parameter(Mandatory = $true)][string]$ArtifactRoot
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "The Windows Avalonia Note Inspector parity gate requires PowerShell Core on Windows."
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
    & pwsh -NoLogo -NoProfile -File ".\tools\Capture-WindowsAvaloniaInspectorParityGui.ps1" `
        -OutputRoot $artifactRootFullPath 2>&1 | Tee-Object -FilePath $guiLog
    if ($LASTEXITCODE -ne 0) {
        throw "Windows Avalonia Inspector parity GUI gate failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$avaloniaSpecs = Get-Content -LiteralPath $avaloniaSpecsEvidencePath -Raw | ConvertFrom-Json -Depth 100
$passedAvaloniaSpecs = @($avaloniaSpecs.Checks | Where-Object Passed).Count
$failedAvaloniaSpecs = @($avaloniaSpecs.Checks | Where-Object { -not $_.Passed }).Count
if ($avaloniaSpecs.Status -ne "passed" -or $passedAvaloniaSpecs -ne 388 -or
    $avaloniaSpecs.Checks.Count -ne 388 -or $failedAvaloniaSpecs -ne 0) {
    throw "Avalonia Specs are not exactly 388/388 passed."
}
$mainSpecsText = Get-Content -LiteralPath $runMainSpecsLog -Raw
if ($mainSpecsText -notmatch '79/79 specs passed') {
    throw "Main Specs are not exactly 79/79 passed."
}

$requiredInspectorSpecs = @(
    "inspector-wpf-tab-order-is-exact-and-does-not-wrap-with-audio-tab",
    "timing-inspector-wpf-layout-metrics-and-action-order-are-exact",
    "timing-list-shortcuts-route-delete-copy-and-paste",
    "timing-list-shortcuts-recover-physical-keys-under-chinese-ime",
    "timing-editor-preserves-unapplied-draft-during-same-item-refresh",
    "note-inspector-wpf-layout-actions-and-key-sound-entry-are-exact",
    "group-inspector-and-floating-palettes-stay-in-wpf-layout-boundaries")
$inspectorSpecEvidence = @(
    $avaloniaSpecs.Checks |
        Where-Object { $_.Name -in $requiredInspectorSpecs } |
        Sort-Object { [Array]::IndexOf($requiredInspectorSpecs, $_.Name) } |
        ForEach-Object { [ordered]@{ name = $_.Name; passed = [bool]$_.Passed; detail = $_.Detail } })
if ($inspectorSpecEvidence.Count -ne $requiredInspectorSpecs.Count -or
    @($inspectorSpecEvidence | Where-Object { -not $_.passed }).Count -ne 0) {
    throw "The seven required Inspector parity Specs are incomplete."
}

$guiEvidencePath = Join-Path $artifactRootFullPath "inspector-parity-gui-evidence.json"
$guiRuntimePath = Join-Path $artifactRootFullPath "inspector-runtime.json"
$gui = Get-Content -LiteralPath $guiEvidencePath -Raw | ConvertFrom-Json -Depth 100
$runtime = Get-Content -LiteralPath $guiRuntimePath -Raw | ConvertFrom-Json -Depth 100
if ($gui.schema -ne "lumachart.windows.avalonia.inspector-parity-gui-evidence.v1" -or
    $gui.status -ne "passed-migration-incomplete" -or
    -not [bool]$gui.source.unchanged -or
    [string]$gui.source.sha256Before -cne [string]$gui.source.sha256After -or
    [string]$gui.source.sha256Before -cne "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E" -or
    [int]$gui.source.noteCount -ne 2753 -or
    @($gui.inspector.tabs).Count -ne 5 -or
    -not [bool]$gui.inspector.singleRow -or
    -not [bool]$gui.inspector.wpfOrder -or
    -not [bool]$gui.inspector.avaloniaOnlyAudioTabAbsent -or
    [int]$gui.inspector.timingCountBefore -ne 1 -or
    -not [bool]$gui.inspector.effectCreatedThroughGui -or
    -not [bool]$gui.inspector.buttonCopyPaste -or
    -not [bool]$gui.inspector.buttonPasteUndo -or
    -not [bool]$gui.inspector.shortcutCopyPaste -or
    -not [bool]$gui.inspector.shortcutPasteUndo -or
    -not [bool]$gui.inspector.textInputFocusLossWithoutEnter -or
    -not [bool]$gui.inspector.timingListSingleVirtualizedControl -or
    -not [bool]$gui.inspector.defaultFloatingPalettesClearInspector -or
    -not [bool]$gui.inspector.defaultFloatingPalettesClearEachOther -or
    -not [bool]$gui.inspector.noteWpfLayoutAndHintVisible -or
    -not [bool]$gui.inspector.existingNoteSoundPickerAssignedAndUndone -or
    -not [bool]$gui.inspector.nativeNoteSoundPickerEntryEnabled -or
    [string]$gui.inspector.nativeNoteSoundPicker.title -cne "选择 Note Key 音" -or
    [string]$gui.inspector.nativeNoteSoundPicker.fileNameControlType -cne "ControlType.Edit" -or
    -not [bool]$gui.inspector.nativeNoteSoundPicker.dialogClosed -or
    -not [bool]$gui.inspector.importedNoteSound.bytesMatch -or
    -not [bool]$gui.inspector.importedNoteSound.assignmentUndone -or
    -not [bool]$gui.inspector.importedNoteSound.sourceUnchanged -or
    [string]$gui.inspector.importedNoteSound.fixtureSha256 -cne
        [string]$gui.inspector.importedNoteSound.workingSha256 -or
    [int]$runtime.chart.structure.noteCount -ne 2753 -or
    -not [bool]$runtime.timeline.singleCustomControl -or
    [int]$runtime.timeline.perNoteAvaloniaControlCount -ne 0 -or
    -not [bool]$runtime.timeline.visibleAreaClipping) {
    throw "Inspector parity GUI evidence is incomplete."
}

$screenshotNames = @(
    "avalonia-inspector-timing.png",
    "avalonia-inspector-timing-pasted.png",
    "avalonia-inspector-note.png",
    "avalonia-inspector-note-sound-menu.png",
    "avalonia-inspector-note-sound.png",
    "avalonia-inspector-note-imported-sound.png",
    "avalonia-inspector-group.png",
    "avalonia-inspector-settings.png",
    "avalonia-inspector-timing-final.png")
Add-Type -AssemblyName System.Drawing
$screenshotEvidence = @()
foreach ($name in $screenshotNames) {
    $path = Join-Path $artifactRootFullPath $name
    $fileEvidence = Get-FileEvidence $path
    $bitmap = [Drawing.Bitmap]::FromFile($path)
    try {
        if ($bitmap.Width -ne 2560 -or $bitmap.Height -ne 1528) {
            throw "Inspector screenshot has unexpected dimensions: $name ($($bitmap.Width)x$($bitmap.Height))."
        }
        $fileEvidence["width"] = $bitmap.Width
        $fileEvidence["height"] = $bitmap.Height
    }
    finally {
        $bitmap.Dispose()
    }
    $screenshotEvidence += $fileEvidence
}

$installerPath = Join-Path $repositoryRoot "release\LumaChartStudio-Setup.exe"
$installerHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
if ($installerHash -cne "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
    throw "The frozen WPF installer hash changed."
}

$previousAuthorityPath = Join-Path $repositoryRoot `
    "artifacts\windows-avalonia-inspector-parity-slice-20260724-r28\evidence.json"
$sourceFiles = @(
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia\Editing\WindowsNotePropertyCommand.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsInspectorParityPolicy.cs",
    "LumaChart.Avalonia.Specs\WindowsInspectorParitySpecs.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "tools\Capture-WindowsAvaloniaInspectorParityGui.ps1",
    "tools\Test-WindowsAvaloniaInspectorParitySlice.ps1")
$wpfTruthFiles = @(
    "LumaChart.App\MainWindow.xaml",
    "LumaChart.App\MainWindow.xaml.cs")

$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.note-inspector-slice-evidence.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    authority = [ordered]@{
        slice = "wpf-note-group-inspector-key-sound-and-floating-palette-parity"
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
        standardDotnetReleaseBuildOnly = $true
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
            status = "passed"; passed = 388; total = 388; failed = 0
            evidence = Get-FileEvidence $avaloniaSpecsEvidencePath
            inspectorParity = $inspectorSpecEvidence
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
        realFixture = $gui.source
        inspector = $gui.inspector
        singleTimelineCustomControl = [bool]$runtime.timeline.singleCustomControl
        perNoteAvaloniaControlCount = [int]$runtime.timeline.perNoteAvaloniaControlCount
        visibleAreaClipping = [bool]$runtime.timeline.visibleAreaClipping
        screenshots = $screenshotEvidence
    }
    implementation = [ordered]@{
        inspectorTabsSingleRowAndWpfOrder = $true
        avaloniaOnlyAudioInspectorTabRemoved = $true
        timingEffectButtonAndKeyboardCopyPasteUndo = $true
        timingDraftSurvivesBackgroundRefreshAndFocusLoss = $true
        chineseImePhysicalShortcutFallbackRetained = $true
        noteAndGroupInspectorUseWpfLayoutBoundaries = $true
        existingAndNativeNoteSoundPickersExercised = $true
        noteSoundAssignmentUsesSingleUndo = $true
        nativeNoteSoundImportCopiesExactBytesToWorkingCache = $true
        floatingPalettesClearInspectorAndEachOtherByDefault = $true
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
        "The current Note/Group Inspector and Key-sound vertical slice passes, but the remaining Windows UI and shortcut matrix is not yet one-to-one.",
        "Online frozen-resource Note Key-sound selection still needs full two-client failure, reconnect and resource-recovery GUI coverage.",
        "Final two-client online, format compatibility, ordinary ClientSecurity, installer/update/uninstall, physical resolution/DPI/60-120 Hz WPF A/B and user replacement approval remain incomplete."
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

Write-Host "WINDOWS_AVALONIA_INSPECTOR_PARITY_SLICE_OK"
Write-Host "Evidence: $evidencePath"
