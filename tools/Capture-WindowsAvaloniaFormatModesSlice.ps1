param(
    [string]$Root =
        "artifacts\windows-avalonia-format-modes-slice-20260729-r1"
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia format-mode evidence requires PowerShell Core on Windows."
}

$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-format-modes-slice-20260729-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals(
        $expectedRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal format-mode root must be exactly $expectedRoot"
}
if (Test-Path -LiteralPath $formalRoot) {
    throw "Formal format-mode root already exists: $formalRoot"
}
if ($env:LUMACHART_FOREGROUND_AUTOMATION_CONSENT -cne
    "USER_CONFIRMED_DESKTOP_AVAILABLE") {
    throw "Explicit foreground GUI automation consent is required."
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Write-Utf8([string]$Path, [string]$Text) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "Missing file: $full"
    $item = Get-Item -LiteralPath $full
    [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $full)
        length = [long]$item.Length
        lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString("O")
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Wait-ForegroundAutomationConsent {
    $deadline = [DateTimeOffset]::UtcNow.AddMinutes(10)
    do {
        try {
            . (Join-Path $PSScriptRoot (
                "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1"))
            return [long]$script:WindowsAvaloniaForegroundAutomationIdleMilliseconds
        }
        catch {
            if ($_.Exception.Message -notlike
                "*requires at least 3000 ms of system idle time*") {
                throw
            }
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "No safe three-second foreground-automation idle window appeared within ten minutes."
}

function Invoke-ForegroundCaptureWithRetry(
    [Parameter(Mandatory = $true)][scriptblock]$Action) {
    $deadline = [DateTimeOffset]::UtcNow.AddMinutes(10)
    do {
        $idle = Wait-ForegroundAutomationConsent
        try {
            $captureOutput = @(& $Action)
            return [pscustomobject]@{
                IdleMilliseconds = [long]$idle
                Output = $captureOutput
            }
        }
        catch {
            if ($_.Exception.Message -notlike
                "*requires at least 3000 ms of system idle time*") {
                throw
            }
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw (
        "No race-free three-second foreground-automation idle window " +
        "appeared within ten minutes.")
}

function Invoke-DotnetLogged(
    [string]$LogPath,
    [Parameter(Mandatory = $true)][scriptblock]$Action) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($LogPath)) |
        Out-Null
    & $Action 2>&1 | Tee-Object -FilePath $LogPath
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet command failed with exit code $LASTEXITCODE; log=$LogPath"
    }
}

function Invoke-ChartExportCapture(
    [string]$Name,
    [ValidateSet("Malody", "OsuMania")][string]$Format,
    [ValidateSet("SingleChart", "SingleRatePackage", "RatePack")][string]$Mode,
    [string]$DestinationName,
    [double]$Rate = 1.2,
    [double]$MinimumRate = 0.8,
    [double]$MaximumRate = 1.1,
    [double]$RateStep = 0.1,
    [bool]$PreservePitch = $false) {
    $root = Join-Path $formalRoot $Name
    $destination = Join-Path (Join-Path $root "export") $DestinationName
    $parameters = @{
        ChartPath = $sourceChartPath
        EvidencePath = Join-Path $root "runtime.json"
        ScreenshotPath = Join-Path $root "07-final.png"
        WorkspaceRoot = Join-Path $root "workspace"
        LocalDataRoot = Join-Path $root "local-data"
        EditingRoot = Join-Path $root "editing"
        ExerciseChartExportModes = $true
        ChartExportModesDefaultScreenshotPath =
            Join-Path $root "01-default.png"
        ChartExportModesSingleChartScreenshotPath =
            Join-Path $root "02-single-chart.png"
        ChartExportModesSingleRateScreenshotPath =
            Join-Path $root "03-single-rate.png"
        ChartExportModesRatePackScreenshotPath =
            Join-Path $root "04-rate-pack.png"
        ChartExportModesHiddenValidationScreenshotPath =
            Join-Path $root "05-hidden-validation.png"
        ChartExportModesContinueToExport = $true
        ChartExportModesExportFormat = $Format
        ChartExportModesExportMode = $Mode
        ChartExportModesExportPath = $destination
        ChartExportModesExportRate = $Rate
        ChartExportModesExportMinimumRate = $MinimumRate
        ChartExportModesExportMaximumRate = $MaximumRate
        ChartExportModesExportRateStep = $RateStep
        ChartExportModesExportPreservePitch = $PreservePitch
        ChartExportModesExportResultScreenshotPath =
            Join-Path $root "06-result.png"
        InteractionDelayMilliseconds = 40000
        TimeoutSeconds = 120
    }
    $capture = Invoke-ForegroundCaptureWithRetry {
        & (Join-Path $PSScriptRoot "Capture-WindowsAvaloniaGui.ps1") @parameters
    }
    $idle = $capture.IdleMilliseconds
    $output = @($capture.Output)
    Write-Utf8 (Join-Path $root "capture-result.json") ($output -join [Environment]::NewLine)
    Assert (Test-Path -LiteralPath $destination -PathType Leaf) (
        "Actual GUI export is missing: $destination")
    $screenshotNames = @(
        "default.png"
        "single-chart.png"
        "single-rate.png"
        "rate-pack.png"
        "hidden-validation.png"
        "result.png"
        "final.png")
    [ordered]@{
        name = $Name
        format = $Format
        mode = $Mode
        idleMillisecondsBeforeCapture = $idle
        destination = File-Evidence $destination
        captureResult = File-Evidence (Join-Path $root "capture-result.json")
        runtime = File-Evidence (Join-Path $root "runtime.json")
        screenshots = @(
            1..7 | ForEach-Object {
                File-Evidence (Join-Path $root (
                    "{0:D2}-{1}" -f $_, $screenshotNames[$_ - 1]))
            })
    }
}

function Invoke-FormatImportCapture(
    [string]$Name,
    [string]$InputPath,
    [int]$ExpectedTabCount,
    [ValidateSet("Calibrate", "Preserve")]
    [string]$OsuImportMode = "Calibrate") {
    $root = Join-Path $formalRoot $Name
    $capture = Invoke-ForegroundCaptureWithRetry {
        & (Join-Path $PSScriptRoot "Capture-WindowsAvaloniaFormatImportGui.ps1") `
            -InputPath $InputPath `
            -OutputRoot $root `
            -ExpectedTabCount $ExpectedTabCount `
            -OsuImportMode $OsuImportMode `
            -TimeoutSeconds 180
    }
    $idle = $capture.IdleMilliseconds
    $output = @($capture.Output)
    Write-Utf8 (Join-Path $root "capture-run.log") (
        $output -join [Environment]::NewLine)
    [ordered]@{
        name = $Name
        input = File-Evidence $InputPath
        expectedTabCount = $ExpectedTabCount
        osuImportMode = $OsuImportMode
        idleMillisecondsBeforeCapture = $idle
        evidence = File-Evidence (Join-Path $root "evidence.json")
        captureRun = File-Evidence (Join-Path $root "capture-run.log")
        finalScreenshot =
            File-Evidence (Join-Path $root "fresh-import-editor.png")
        archiveDialogScreenshot = if (
            Test-Path -LiteralPath (Join-Path $root "archive-import-dialog.png")) {
            File-Evidence (Join-Path $root "archive-import-dialog.png")
        } else { $null }
    }
}

$sourceChartPath = 'D:\osu!\Songs\Resound\0\1781536331.mc'
$installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$sourceBefore = File-Evidence $sourceChartPath
$installerBefore = File-Evidence $installerPath
Assert ($sourceBefore.sha256 -ceq
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") (
    "Real Resound MC baseline hash mismatch.")
Assert ($installerBefore.sha256 -ceq
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") (
    "Frozen WPF installer baseline hash mismatch.")

[IO.Directory]::CreateDirectory($formalRoot) | Out-Null
$buildRoot = Join-Path $formalRoot "build"
$testsRoot = Join-Path $formalRoot "tests"
$env:DOTNET_CLI_HOME = Join-Path $projectRoot ".codex-dotnet-home"
$env:NUGET_PACKAGES = Join-Path $projectRoot ".codex-nuget-packages"
$env:NUGET_HTTP_CACHE_PATH = Join-Path $projectRoot ".codex-nuget-http-cache"
$env:TEMP = Join-Path $projectRoot ".codex-temp"
$env:TMP = $env:TEMP

Invoke-DotnetLogged (Join-Path $buildRoot "avalonia-build.log") {
    dotnet build (Join-Path $projectRoot (
        "LumaChart.Avalonia\LumaChart.Avalonia.csproj")) `
        -c Release --no-restore -p:TreatWarningsAsErrors=true -warnaserror
}
Invoke-DotnetLogged (Join-Path $buildRoot "avalonia-specs-build.log") {
    dotnet build (Join-Path $projectRoot (
        "LumaChart.Avalonia.Specs\LumaChart.Avalonia.Specs.csproj")) `
        -c Release --no-restore -p:TreatWarningsAsErrors=true -warnaserror
}
Invoke-DotnetLogged (Join-Path $buildRoot "main-specs-build.log") {
    dotnet build (Join-Path $projectRoot (
        "LumaChart.Specs\LumaChart.Specs.csproj")) `
        -c Release --no-restore -p:TreatWarningsAsErrors=true -warnaserror
}
Invoke-DotnetLogged (Join-Path $testsRoot "avalonia-specs-run.log") {
    dotnet run --project (Join-Path $projectRoot (
        "LumaChart.Avalonia.Specs\LumaChart.Avalonia.Specs.csproj")) `
        -c Release --no-build -- `
        --output (Join-Path $testsRoot "avalonia-specs-evidence.json")
}
Invoke-DotnetLogged (Join-Path $testsRoot "main-specs-run.log") {
    dotnet run --project (Join-Path $projectRoot (
        "LumaChart.Specs\LumaChart.Specs.csproj")) `
        -c Release --no-build
}

$exports = [Collections.Generic.List[object]]::new()
$exports.Add((Invoke-ChartExportCapture `
    -Name "malody-single-chart-export" `
    -Format Malody `
    -Mode SingleChart `
    -DestinationName "Resound.mc"))
$exports.Add((Invoke-ChartExportCapture `
    -Name "malody-rate-pack-export" `
    -Format Malody `
    -Mode RatePack `
    -DestinationName "Resound 0.8-1.1.mcz"))
$exports.Add((Invoke-ChartExportCapture `
    -Name "osu-single-chart-export" `
    -Format OsuMania `
    -Mode SingleChart `
    -DestinationName "Resound.osu"))
$exports.Add((Invoke-ChartExportCapture `
    -Name "osu-single-rate-export" `
    -Format OsuMania `
    -Mode SingleRatePackage `
    -DestinationName "Resound 1.2x.osz" `
    -Rate 1.2 `
    -PreservePitch $true))
$exports.Add((Invoke-ChartExportCapture `
    -Name "osu-rate-pack-export" `
    -Format OsuMania `
    -Mode RatePack `
    -DestinationName "Resound 0.8-1.1.osz" `
    -PreservePitch $true))

$imports = [Collections.Generic.List[object]]::new()
$imports.Add((Invoke-FormatImportCapture `
    -Name "malody-single-chart-import" `
    -InputPath (Join-Path $formalRoot (
        "malody-single-chart-export\export\Resound.mc")) `
    -ExpectedTabCount 1))
$imports.Add((Invoke-FormatImportCapture `
    -Name "malody-rate-pack-import" `
    -InputPath (Join-Path $formalRoot (
        "malody-rate-pack-export\export\Resound 0.8-1.1.mcz")) `
    -ExpectedTabCount 4))
$imports.Add((Invoke-FormatImportCapture `
    -Name "osu-single-chart-calibrate-import" `
    -InputPath (Join-Path $formalRoot (
        "osu-single-chart-export\export\Resound.osu")) `
    -ExpectedTabCount 1 `
    -OsuImportMode Calibrate))
$imports.Add((Invoke-FormatImportCapture `
    -Name "osu-single-chart-preserve-import" `
    -InputPath (Join-Path $formalRoot (
        "osu-single-chart-export\export\Resound.osu")) `
    -ExpectedTabCount 1 `
    -OsuImportMode Preserve))
$imports.Add((Invoke-FormatImportCapture `
    -Name "osu-single-rate-import" `
    -InputPath (Join-Path $formalRoot (
        "osu-single-rate-export\export\Resound 1.2x.osz")) `
    -ExpectedTabCount 1 `
    -OsuImportMode Preserve))
$imports.Add((Invoke-FormatImportCapture `
    -Name "osu-rate-pack-import" `
    -InputPath (Join-Path $formalRoot (
        "osu-rate-pack-export\export\Resound 0.8-1.1.osz")) `
    -ExpectedTabCount 4 `
    -OsuImportMode Calibrate))

$sourceAfter = File-Evidence $sourceChartPath
$installerAfter = File-Evidence $installerPath
Assert ($sourceAfter.sha256 -ceq $sourceBefore.sha256 -and
        $sourceAfter.length -eq $sourceBefore.length -and
        $sourceAfter.lastWriteTimeUtc -ceq $sourceBefore.lastWriteTimeUtc) (
    "Real Resound MC changed during formal format evidence.")
Assert ($installerAfter.sha256 -ceq $installerBefore.sha256) (
    "Frozen WPF installer changed during formal format evidence.")

$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.format-modes-slice-capture.v1"
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    platform = "Windows Avalonia only"
    windowsAvaloniaOnly = $true
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    productionServerMutationPerformed = $false
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    migrationComplete = $false
    source = [ordered]@{
        before = $sourceBefore
        after = $sourceAfter
        unchanged = $true
    }
    immutableInstaller = [ordered]@{
        before = $installerBefore
        after = $installerAfter
    }
    builds = [ordered]@{
        avalonia = File-Evidence (Join-Path $buildRoot "avalonia-build.log")
        avaloniaSpecs =
            File-Evidence (Join-Path $buildRoot "avalonia-specs-build.log")
        mainSpecs = File-Evidence (Join-Path $buildRoot "main-specs-build.log")
    }
    tests = [ordered]@{
        avaloniaSpecs =
            File-Evidence (Join-Path $testsRoot "avalonia-specs-evidence.json")
        avaloniaSpecsRun =
            File-Evidence (Join-Path $testsRoot "avalonia-specs-run.log")
        mainSpecs = File-Evidence (Join-Path $testsRoot "main-specs-run.log")
    }
    exports = $exports.ToArray()
    imports = $imports.ToArray()
}
$evidencePath = Join-Path $formalRoot "capture-evidence.json"
Write-Utf8 $evidencePath ($evidence | ConvertTo-Json -Depth 50)
Write-Output "Windows Avalonia format-mode formal capture: passed-migration-incomplete"
Write-Output "Evidence: $evidencePath"
