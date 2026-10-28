param(
    [Parameter(Mandatory = $true)][string]$AuthorityRoot,
    [Parameter(Mandatory = $true)][string]$FrameProbePath,
    [Parameter(Mandatory = $true)][string]$FrozenInstallerPath,
    [string]$ExpectedFrozenInstallerSha256 =
        "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4",
    [string]$ExpectedChartSha256 =
        "FA830C2BFE0FF2750FDC56F685B5BDFE23EEAF05B2D0EEDE1D5896F83F3D5DD5"
)

$ErrorActionPreference = "Stop"

function Resolve-ExistingPath([string]$Path, [string]$Label, [switch]$Directory) {
    $full = [IO.Path]::GetFullPath($Path)
    $pathType = if ($Directory) { "Container" } else { "Leaf" }
    if (-not (Test-Path -LiteralPath $full -PathType $pathType)) {
        throw "$Label is missing: $full"
    }
    return $full
}

$authorityRoot = Resolve-ExistingPath $AuthorityRoot "Authority root" -Directory
$frameProbePath = Resolve-ExistingPath $FrameProbePath "Frame probe"
$frozenInstallerPath = Resolve-ExistingPath $FrozenInstallerPath "Frozen installer"
$verificationPath = Join-Path $authorityRoot "verification-evidence.json"
if (Test-Path -LiteralPath $verificationPath) {
    throw "Verification evidence already exists: $verificationPath"
}

$checks = [Collections.Generic.List[object]]::new()
function Add-Check([string]$Name, [bool]$Passed, [string]$Detail) {
    $checks.Add([ordered]@{
        name = $Name
        passed = $Passed
        detail = $Detail
    })
}

function Read-Json([string]$RelativePath) {
    $path = Resolve-ExistingPath (Join-Path $authorityRoot $RelativePath) $RelativePath
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Read-DoubleField([string]$Text, [string]$Name) {
    $escaped = [Regex]::Escape($Name)
    $match = [Regex]::Match($Text, "(?:^|;\s*)$escaped=(?<value>[^;]+)")
    if (-not $match.Success) { throw "Performance field is missing: $Name" }
    return [double]::Parse(
        $match.Groups["value"].Value.Trim(),
        [Globalization.CultureInfo]::InvariantCulture)
}

function Assert-Capture(
    [object]$Capture,
    [int]$RefreshHz,
    [double]$FrameP50Maximum,
    [double]$FrameP95Maximum,
    [double]$FrameP99Maximum,
    [double]$InputP95Maximum,
    [double]$InputP99Maximum) {
    $prefix = "$RefreshHz-hz"
    Add-Check "$prefix-schema" `
        ($Capture.schema -eq "lumachart.windows.avalonia.performance-gui.v2") `
        ([string]$Capture.schema)
    Add-Check "$prefix-display" `
        ($Capture.display.Width -eq 2560 -and
         $Capture.display.Height -eq 1600 -and
         $Capture.display.RefreshHz -eq $RefreshHz) `
        "$($Capture.display.Width)x$($Capture.display.Height)@$($Capture.display.RefreshHz)"
    Add-Check "$prefix-chart-hash" `
        ($Capture.chart.sha256 -ceq $ExpectedChartSha256 -and
         $Capture.chart.length -eq 3537394) `
        "bytes=$($Capture.chart.length); sha256=$($Capture.chart.sha256)"
    Add-Check "$prefix-note-count" `
        ($Capture.avalonia.noteCountAutomationName -eq "100,000" -and
         $Capture.wpf.noteCountAutomationName -eq "100000") `
        "Avalonia=$($Capture.avalonia.noteCountAutomationName); WPF=$($Capture.wpf.noteCountAutomationName)"

    $avaloniaRate = $Capture.avalonia.playbackSummary.frameRate
    $wpfRate = $Capture.wpf.playbackSummary.frameRate
    Add-Check "$prefix-playback-samples" `
        ($avaloniaRate.samples -ge 8 -and $wpfRate.samples -ge 8) `
        "Avalonia=$($avaloniaRate.samples); WPF=$($wpfRate.samples)"
    Add-Check "$prefix-playback-p50-parity" `
        ($avaloniaRate.p50 -ge $wpfRate.p50 * 0.95) `
        "Avalonia=$($avaloniaRate.p50); WPF=$($wpfRate.p50)"
    $minimumExpected = if ($RefreshHz -eq 165) { 150.0 } else { 58.0 }
    Add-Check "$prefix-playback-p50-floor" `
        ($avaloniaRate.p50 -ge $minimumExpected) `
        "p50=$($avaloniaRate.p50); floor=$minimumExpected"

    $helpText = [string]$Capture.avalonia.playbackSummary.peakRenderHelpText
    $renderSamples = Read-DoubleField $helpText "RenderSamples"
    $renderP95 = Read-DoubleField $helpText "RenderMsP95"
    $renderP99 = Read-DoubleField $helpText "RenderMsP99"
    $frameP50 = Read-DoubleField $helpText "FrameMsP50"
    $frameP95 = Read-DoubleField $helpText "FrameMsP95"
    $frameP99 = Read-DoubleField $helpText "FrameMsP99"
    $maximumVisited = Read-DoubleField $helpText "MaximumVisitedNotes"
    Add-Check "$prefix-render-samples" `
        ($renderSamples -ge $(if ($RefreshHz -eq 165) { 700 } else { 300 })) `
        "samples=$renderSamples"
    Add-Check "$prefix-frame-p50" ($frameP50 -le $FrameP50Maximum) `
        "p50=$frameP50; maximum=$FrameP50Maximum"
    Add-Check "$prefix-frame-p95" ($frameP95 -le $FrameP95Maximum) `
        "p95=$frameP95; maximum=$FrameP95Maximum"
    Add-Check "$prefix-frame-p99" ($frameP99 -le $FrameP99Maximum) `
        "p99=$frameP99; maximum=$FrameP99Maximum"
    Add-Check "$prefix-cpu-render-tail" `
        ($renderP95 -le 1.0 -and $renderP99 -le 2.0) `
        "p95=$renderP95; p99=$renderP99"
    Add-Check "$prefix-visible-culling" `
        ($maximumVisited -le 512) `
        "maximumVisitedNotes=$maximumVisited"

    $input = $Capture.avalonia.inputToRenderProbe
    Add-Check "$prefix-avalonia-input-probe" `
        ($input.status -eq "passed" -and
         $input.input.completedTrials -eq 12 -and
         $input.input.timeoutTrials -eq 0) `
        "status=$($input.status); completed=$($input.input.completedTrials); timeouts=$($input.input.timeoutTrials)"
    Add-Check "$prefix-input-p95" `
        ($input.input.latencyMilliseconds.P95 -le $InputP95Maximum) `
        "p95=$($input.input.latencyMilliseconds.P95); maximum=$InputP95Maximum"
    Add-Check "$prefix-input-p99" `
        ($input.input.latencyMilliseconds.P99 -le $InputP99Maximum) `
        "p99=$($input.input.latencyMilliseconds.P99); maximum=$InputP99Maximum"

    $wpfProbe = $Capture.wpf.visibleProbe
    Add-Check "$prefix-wpf-reference-probe" `
        ($wpfProbe.status -eq "passed" -and
         $wpfProbe.input.CompletedTrials -eq 12 -and
         $wpfProbe.input.TimeoutTrials -eq 0) `
        "status=$($wpfProbe.status); completed=$($wpfProbe.input.CompletedTrials); timeouts=$($wpfProbe.input.TimeoutTrials)"

    foreach ($client in "avalonia", "wpf") {
        $screenshot = $Capture.$client.screenshot
        $screenshotPath = Resolve-ExistingPath $screenshot.path "$prefix $client screenshot"
        $insideAuthority = $screenshotPath.StartsWith(
            $authorityRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)
        $actualHash = (Get-FileHash -LiteralPath $screenshotPath -Algorithm SHA256).Hash
        $actualLength = (Get-Item -LiteralPath $screenshotPath).Length
        Add-Check "$prefix-$client-screenshot" `
            ($insideAuthority -and
             $screenshot.width -eq 1980 -and
             $screenshot.height -eq 1200 -and
             $screenshot.sampledUniqueColors -ge 12 -and
             $actualLength -eq $screenshot.length -and
             $actualHash -ceq $screenshot.sha256) `
            "inside=$insideAuthority; colors=$($screenshot.sampledUniqueColors); bytes=$actualLength; sha256=$actualHash"
    }
}

$capture165 = Read-Json "gui-165\capture-evidence.json"
$capture60 = Read-Json "gui-60\capture-evidence.json"
Assert-Capture $capture165 165 7.5 12.5 18.0 30.0 35.0
Assert-Capture $capture60 60 18.5 21.0 25.0 45.0 55.0

$avaloniaSpecs = Read-Json "tests\avalonia-specs-evidence.json"
$failedAvaloniaChecks = @($avaloniaSpecs.Checks | Where-Object { -not $_.Passed })
Add-Check "avalonia-specs-528-of-528" `
    ($avaloniaSpecs.Status -eq "passed" -and
     @($avaloniaSpecs.Checks).Count -eq 528 -and
     $failedAvaloniaChecks.Count -eq 0) `
    "status=$($avaloniaSpecs.Status); total=$(@($avaloniaSpecs.Checks).Count); failed=$($failedAvaloniaChecks.Count)"

$mainSpecsPath = Resolve-ExistingPath (
    Join-Path $authorityRoot "tests\main-specs.log") "Main Specs log"
$mainSpecsText = Get-Content -LiteralPath $mainSpecsPath -Raw
Add-Check "main-specs-79-of-79" `
    ($mainSpecsText.Contains("79/79 specs passed.", [StringComparison]::Ordinal)) `
    "Expected terminal summary is present."

$buildLogs = @(
    "avalonia-release.log",
    "avalonia-specs-release.log",
    "main-specs-release.log",
    "windows-frame-probe-release.log"
)
foreach ($buildLog in $buildLogs) {
    $path = Resolve-ExistingPath (
        Join-Path $authorityRoot "build\$buildLog") "Build log $buildLog"
    $text = Get-Content -LiteralPath $path -Raw
    Add-Check "strict-build-$buildLog" `
        ($text.Contains("0 个警告", [StringComparison]::Ordinal) -and
         $text.Contains("0 个错误", [StringComparison]::Ordinal)) `
        "ordinary dotnet Release; 0 warning / 0 error summary required"
}

$ordinaryBuildSources = @(
    "LumaChart.Avalonia\LumaChart.Avalonia.csproj",
    "LumaChart.Avalonia.Specs\LumaChart.Avalonia.Specs.csproj",
    "tools\WindowsFrameProbe\WindowsFrameProbe.csproj"
)
$forbiddenBuildPattern =
    "(?i)OLLVM|PublishAot|NativeAOT|PublishReadyToRun|VMProtect|Confuser|Obfuscat"
foreach ($relativePath in $ordinaryBuildSources) {
    $sourcePath = Resolve-ExistingPath (
        Join-Path (Split-Path $authorityRoot -Parent | Split-Path -Parent) $relativePath) `
        "Build source $relativePath"
    $text = Get-Content -LiteralPath $sourcePath -Raw
    Add-Check "ordinary-dotnet-no-protection-$relativePath" `
        (-not [Regex]::IsMatch($text, $forbiddenBuildPattern)) `
        "No OLLVM, obfuscation, packing, code virtualization, AOT or NativeAOT marker."
}

$installerHash = (Get-FileHash -LiteralPath $frozenInstallerPath -Algorithm SHA256).Hash
Add-Check "frozen-wpf-installer-unchanged" `
    ($installerHash -ceq $ExpectedFrozenInstallerSha256) `
    "sha256=$installerHash"

$displayCapabilities = (& $frameProbePath display-list | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0) { throw "Could not read display capabilities." }
$modeLabels = @($displayCapabilities.modes | ForEach-Object {
    "$($_.Width)x$($_.Height)@$($_.RefreshHz)"
})
Add-Check "display-restored-165-hz" `
    ($displayCapabilities.current.Width -eq 2560 -and
     $displayCapabilities.current.Height -eq 1600 -and
     $displayCapabilities.current.RefreshHz -eq 165) `
    "$($displayCapabilities.current.Width)x$($displayCapabilities.current.Height)@$($displayCapabilities.current.RefreshHz)"
Add-Check "hardware-modes-recorded" `
    ($modeLabels -contains "2560x1600@60" -and
     $modeLabels -contains "2560x1600@165") `
    ($modeLabels -join ", ")

$appliedDpi = try {
    [int](Get-ItemPropertyValue `
        -LiteralPath "HKCU:\Control Panel\Desktop\WindowMetrics" `
        -Name "AppliedDPI")
}
catch {
    $null
}

$failedChecks = @($checks | Where-Object { -not $_.passed })
$files = @(
    Get-ChildItem -LiteralPath $authorityRoot -Recurse -File |
        Where-Object { $_.FullName -cne $verificationPath } |
        Sort-Object FullName |
        ForEach-Object {
            [ordered]@{
                path = [IO.Path]::GetRelativePath($authorityRoot, $_.FullName)
                length = $_.Length
                sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            }
        }
)

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.performance-parity-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
    platformScope = "Windows Avalonia only"
    buildPolicy = [ordered]@{
        configuration = "Release"
        ordinaryDotnet = $true
        ollvm = $false
        obfuscation = $false
        packing = $false
        codeVirtualization = $false
        aot = $false
        nativeAot = $false
        wpfSourceBuildPerformed = $false
    }
    methodology = [ordered]@{
        chartNotes = 100000
        chartLongNotes = 14286
        sameMachineWpfReference = $true
        avaloniaPlayback =
            "real audio-clock playback; TimelineSurface composition-frame instrumentation"
        avaloniaInput =
            "Win32 SendInput QPC to first UIA observation of changed beat and TimelineSurface render sample"
        wpfReferenceProbe =
            "DwmFlush plus desktop BitBlt visible-change probe"
        presentMon = $false
        physicalInputLatencyClaimed = $false
        gpuPresentAttributionClaimed = $false
    }
    hardware = [ordered]@{
        current = $displayCapabilities.current
        modes = $displayCapabilities.modes
        appliedDpi = $appliedDpi
        appliedScalePercent = if ($null -eq $appliedDpi) {
            $null
        } else {
            [Math]::Round($appliedDpi / 96.0 * 100.0, 2)
        }
        unavailableForThisSlice = @(
            "120 Hz mode",
            "true 3840x2160 display mode",
            "elevated PresentMon per-process GPU-present attribution"
        )
    }
    results = [ordered]@{
        hz165 = [ordered]@{
            avaloniaPlaybackFps = $capture165.avalonia.playbackSummary.frameRate
            wpfPlaybackFps = $capture165.wpf.playbackSummary.frameRate
            avaloniaPeakRender = $capture165.avalonia.playbackSummary.peakRenderHelpText
            avaloniaInputLatency = $capture165.avalonia.inputToRenderProbe.input.latencyMilliseconds
            wpfReferenceInputLatency = $capture165.wpf.visibleProbe.input.LatencyMilliseconds
        }
        hz60 = [ordered]@{
            avaloniaPlaybackFps = $capture60.avalonia.playbackSummary.frameRate
            wpfPlaybackFps = $capture60.wpf.playbackSummary.frameRate
            avaloniaPeakRender = $capture60.avalonia.playbackSummary.peakRenderHelpText
            avaloniaInputLatency = $capture60.avalonia.inputToRenderProbe.input.latencyMilliseconds
            wpfReferenceInputLatency = $capture60.wpf.visibleProbe.input.LatencyMilliseconds
        }
    }
    tests = [ordered]@{
        avaloniaSpecs = "528/528"
        mainSpecs = "79/79"
        strictBuilds = "4/4; 0 warning; 0 error"
    }
    checks = $checks
    failedCheckCount = $failedChecks.Count
    files = $files
    remainingHardwareValidation = @(
        "Repeat the same 100,000-Note gate on native 120 Hz hardware.",
        "Repeat 1080p, 1440p and true 4K at required Windows scale factors.",
        "Add elevated PresentMon capture when a suitable controlled session is available."
    )
}

$temporaryPath = $verificationPath + ".tmp-" + [Guid]::NewGuid().ToString("N")
$verification | ConvertTo-Json -Depth 16 |
    Set-Content -LiteralPath $temporaryPath -Encoding utf8
Move-Item -LiteralPath $temporaryPath -Destination $verificationPath

[ordered]@{
    path = $verificationPath
    status = $verification.status
    checks = $checks.Count
    failed = $failedChecks.Count
    length = (Get-Item -LiteralPath $verificationPath).Length
    sha256 = (Get-FileHash -LiteralPath $verificationPath -Algorithm SHA256).Hash
} | ConvertTo-Json

if ($failedChecks.Count -ne 0) { exit 3 }
