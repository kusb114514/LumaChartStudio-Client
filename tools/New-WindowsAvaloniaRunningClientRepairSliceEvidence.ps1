param(
    [string]$Root =
        "artifacts\windows-avalonia-running-client-repair-slice-20260729-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedBeforeRepairScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedAfterRepairScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia running-client repair verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-running-client-repair-slice-20260729-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals(
        $expectedRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal running-client repair root must be exactly $expectedRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Write-Utf8([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText(
        $Path,
        $Text,
        [Text.UTF8Encoding]::new($false))
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
    $text = Get-Content -LiteralPath $Path -Raw
    Assert ($text -match "(0 个警告|0 Warning\(s\))") (
        "Strict build log lacks zero-warning result: $Path")
    Assert ($text -match "(0 个错误|0 Error\(s\))") (
        "Strict build log lacks zero-error result: $Path")
    Assert ($text -notmatch (
        "(?i)ollvm|obfuscat|virtuali[sz]ation|nativeaot|publish-aot")) (
        "Strict build log contains forbidden protection or AOT markers: $Path")
    File-Evidence $Path
}

foreach ($hash in @(
        $ExpectedBeforeRepairScreenshotSha256,
        $ExpectedAfterRepairScreenshotSha256)) {
    Assert ($hash -match "^[0-9A-Fa-f]{64}$") (
        "A reviewed running-client repair screenshot SHA-256 is invalid.")
}
$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")
$capturePath = Join-Path $formalRoot "capture-evidence.json"
$capture =
    Get-Content -LiteralPath $capturePath -Raw |
        ConvertFrom-Json -Depth 100
Assert ($capture.schema -ceq
        "lumachart.windows.avalonia.running-client-repair-slice-capture.v1" -and
    $capture.status -ceq "passed-migration-incomplete" -and
    $capture.formalMigrationAuthority -eq $true -and
    $capture.windowsAvaloniaOnly -eq $true -and
    $capture.pureDotnetRelease -eq $true -and
    $capture.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false -and
    $capture.mobileProjectsBuiltModifiedInstalledOrTested -eq $false -and
    $capture.productionServerMutationPerformed -eq $false) (
    "Formal running-client repair scope or build policy differs.")

$buildLogs = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\main-specs-build.log")
}
$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs =
    Get-Content -LiteralPath $specsPath -Raw |
        ConvertFrom-Json -Depth 100
$checks = @($specs.checks)
$passedChecks = @($checks | Where-Object passed)
$runningRepairCheck = @($checks | Where-Object {
        $_.name -ceq
            "avalonia-installer-running-client-repair-closes-only-isolated-client-and-reopens-real-chart"
    })
Assert ($specs.status -ceq "passed" -and
    $checks.Count -eq 543 -and
    $passedChecks.Count -eq 543 -and
    $runningRepairCheck.Count -eq 1 -and
    $runningRepairCheck[0].passed -eq $true) (
    "Avalonia Specs count/status differs: $($passedChecks.Count)/$($checks.Count)")
$mainSpecsPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainSpecsText = Get-Content -LiteralPath $mainSpecsPath -Raw
Assert ($mainSpecsText -match "79/79 specs passed") (
    "Main Specs did not pass 79/79.")
$safetyPath = Join-Path $formalRoot "tests\gui-automation-safety.json"
$safety =
    Get-Content -LiteralPath $safetyPath -Raw |
        ConvertFrom-Json -Depth 50
Assert ($safety.status -ceq "passed" -and
    $safety.persistentTopmostUsed -eq $false -and
    @($safety.captureScripts |
        Where-Object { [long]$_.persistentTopmostPatternCount -ne 0 }).Count -eq 0 -and
    @($safety.automationHelperSources |
        Where-Object { [long]$_.persistentTopmostPatternCount -ne 0 }).Count -eq 0) (
    "GUI automation safety evidence differs.")

$buildEvidencePath = Join-Path $formalRoot (
    "installer-build\build-evidence.json")
$buildEvidence =
    Get-Content -LiteralPath $buildEvidencePath -Raw |
        ConvertFrom-Json -Depth 100
Assert ($buildEvidence.status -ceq "passed-migration-incomplete" -and
    $buildEvidence.previewVersion -ceq "1.1.0" -and
    $buildEvidence.pureDotnetRelease -eq $true -and
    $buildEvidence.selfContained -eq $true -and
    $buildEvidence.publishSingleFile -eq $false -and
    $buildEvidence.publishTrimmed -eq $false -and
    $buildEvidence.publishAot -eq $false -and
    $buildEvidence.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "Fresh Preview installer build evidence differs.")
$setupPath = Join-Path $formalRoot (
    "installer-build\installer\LumaChartStudio-Avalonia-Preview-Setup.exe")
$setup = File-Evidence $setupPath
Assert ($setup.sha256 -ceq $capture.setup.beforeLifecycle.sha256 -and
    $setup.sha256 -ceq $capture.setup.afterLifecycle.sha256 -and
    $setup.sha256 -ceq $buildEvidence.installer.file.sha256 -and
    [long]$setup.length -gt 80MB) (
    "Fresh setup hash or size differs.")
Assert (-not (Test-Path -LiteralPath (
        Join-Path $formalRoot "installer-build\publish")) -and
    -not (Test-Path -LiteralPath (
        Join-Path $formalRoot "installer-build\temp")) -and
    -not (Test-Path -LiteralPath (
        Join-Path $formalRoot "lifecycle\temp"))) (
    "Regenerable installer staging remains in the formal root.")

$lifecyclePath = Join-Path $formalRoot "lifecycle\evidence.json"
$lifecycle =
    Get-Content -LiteralPath $lifecyclePath -Raw |
        ConvertFrom-Json -Depth 100
$repair = $lifecycle.lifecycle.runningClientRepair
Assert ($lifecycle.status -ceq "passed-migration-incomplete" -and
    $lifecycle.formalMigrationAuthority -eq $true -and
    $repair.processExitedDuringRepair -eq $true -and
    [int]$repair.processExitCode -eq 0 -and
    [int]$repair.repairExitCode -eq 0 -and
    $repair.restartRequired -eq $false -and
    $repair.shutdownCloseReason -ceq "WindowClosing" -and
    $repair.shutdownWasProgrammatic -eq $false -and
    $repair.realChartAndAudioReopened -eq $true -and
    $repair.sourceUnchanged -eq $true -and
    $repair.installedAppBefore.sha256 -ceq
        $repair.installedAppAfter.sha256 -and
    $repair.editingCacheBefore.sha256 -ceq
        $repair.editingCacheAfter.sha256) (
    "Formal running-client repair lifecycle evidence differs.")

$shutdownPath = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    $repair.shutdownDecision.path)))
$shutdown =
    Get-Content -LiteralPath $shutdownPath -Raw |
        ConvertFrom-Json -Depth 30
Assert ($shutdown.schema -ceq
        "lumachart.windows.avalonia.external-application-shutdown.v1" -and
    $shutdown.closeReason -ceq "WindowClosing" -and
    $shutdown.IsProgrammatic -eq $false -and
    $shutdown.hasUnsavedDocuments -eq $false -and
    $shutdown.hasBlockingWork -eq $false -and
    $shutdown.hasActiveOnlineRoom -eq $false -and
    $shutdown.canCloseImmediately -eq $true -and
    @($shutdown.blockingWork.psobject.Properties |
        Where-Object Value).Count -eq 0) (
    "The recorded clean external shutdown decision differs.")

$beforeRuntimePath = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    $repair.beforeRuntime.path)))
$afterRuntimePath = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    $repair.afterRuntime.path)))
$beforeRuntime =
    Get-Content -LiteralPath $beforeRuntimePath -Raw |
        ConvertFrom-Json -Depth 100
$afterRuntime =
    Get-Content -LiteralPath $afterRuntimePath -Raw |
        ConvertFrom-Json -Depth 100
foreach ($runtime in @($beforeRuntime, $afterRuntime)) {
    Assert ([long]$runtime.chart.structure.noteCount -eq 2753 -and
        [long]$runtime.chart.structure.longNoteCount -eq 771 -and
        [long]$runtime.chart.structure.timingCount -eq 1 -and
        $runtime.audio.sourceExists -eq $true -and
        $runtime.timeline.sessionIsDirty -eq $false) (
        "A running-client repair runtime did not contain the clean real Resound MC/OGG.")
}

$repairLogPath = Join-Path $formalRoot "lifecycle\lifecycle\repair-install.log"
$repairLogText = Get-Content -LiteralPath $repairLogPath -Raw
Assert ($repairLogText.Contains(
        "RestartManager found an application using one of our files: LumaChart.Avalonia",
        [StringComparison]::Ordinal) -and
    $repairLogText.Contains(
        "Shutting down applications using our files.",
        [StringComparison]::Ordinal) -and
    $repairLogText.Contains(
        "Installation process succeeded.",
        [StringComparison]::Ordinal) -and
    $repairLogText.Contains(
        "Need to restart Windows? No",
        [StringComparison]::Ordinal) -and
    !$repairLogText.Contains(
        "Some applications could not be shut down.",
        [StringComparison]::Ordinal)) (
    "Inno Restart Manager repair log differs.")

$screenshots = @(
    [ordered]@{
        name = "before-repair"
        declaration = $repair.beforeScreenshot
        expected = $ExpectedBeforeRepairScreenshotSha256
    },
    [ordered]@{
        name = "after-repair"
        declaration = $repair.afterScreenshot
        expected = $ExpectedAfterRepairScreenshotSha256
    })
$reviewedScreenshots = foreach ($entry in $screenshots) {
    $path = [IO.Path]::GetFullPath((Join-Path $projectRoot (
        $entry.declaration.path)))
    Assert ($path.StartsWith(
            $formalRoot + '\',
            [StringComparison]::OrdinalIgnoreCase)) (
        "Running-client repair screenshot escaped the formal root: $path")
    $actual = File-Evidence $path
    Assert ($actual.sha256 -ceq [string]$entry.declaration.sha256 -and
        $actual.sha256 -ceq $entry.expected.ToUpperInvariant() -and
        [long]$actual.length -gt 500000) (
        "Reviewed running-client repair screenshot differs: $($entry.name)")
    [ordered]@{
        name = $entry.name
        file = $actual
        manualVisualReviewPassed = $true
    }
}

$realMc = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
$realOgg = File-Evidence "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg"
$frozenInstaller = File-Evidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert ($realMc.sha256 -ceq
        "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E" -and
    $realOgg.sha256 -ceq
        "00AA7780330A022D7F5D0C4C2BEA23625D31F48BA8CAC2AF25117249BEA05151" -and
    $frozenInstaller.sha256 -ceq
        "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") (
    "A frozen real input changed.")
Assert (-not (Test-Path -LiteralPath $lifecycle.paths.lifecycleInstall) -and
    -not (Test-Path -LiteralPath (
        "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\AE886E9E-335F-4F03-B891-75591AC6CB57_is1"))) (
    "Preview install or uninstall registry residue remains.")
$ownedProcess = Get-Process -Id ([int]$repair.processId) -ErrorAction SilentlyContinue
Assert ($null -eq $ownedProcess) (
    "Evidence-owned installed client process remains.")

$formalFiles = @(
    Get-ChildItem -LiteralPath $formalRoot -Recurse -File -Force)
$formalBytes = [long]($formalFiles | Measure-Object Length -Sum).Sum
$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.running-client-repair-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    formalMigrationAuthority = $true
    completion = $false
    migrationComplete = $false
    windowsAvaloniaCanReplaceWpf = $false
    userManualReplacementApprovalReceived = $false
    nextPlatformAuthorized = $false
    windowsAvaloniaOnly = $true
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    builds = $buildLogs
    tests = [ordered]@{
        avaloniaSpecsPassed = $passedChecks.Count
        avaloniaSpecsTotal = $checks.Count
        mainSpecsPassed = 79
        mainSpecsTotal = 79
        guiAutomationSafety = File-Evidence $safetyPath
    }
    installer = [ordered]@{
        setup = $setup
        restartManagerFoundExactClient = $true
        exactOwnedProcessExitedCleanly = $true
        repairExitCode = 0
        restartRequired = $false
        installedApplicationBytesPreserved = $true
        editingCacheSentinelPreserved = $true
        installAndRegistryResidueCount = 0
    }
    shutdown = [ordered]@{
        decision = File-Evidence $shutdownPath
        closeReason = [string]$shutdown.closeReason
        isProgrammatic = [bool]$shutdown.IsProgrammatic
        cleanIdleExternalCloseAccepted = $true
        dirtyOrBusyOrOnlineCloseStillBlocked = $true
    }
    realChartAndAudio = [ordered]@{
        beforeRepair = File-Evidence $beforeRuntimePath
        afterRepair = File-Evidence $afterRuntimePath
        noteCount = 2753
        holdCount = 771
        timingCount = 1
        sourceAudioExists = $true
        reopenedAfterRepair = $true
    }
    screenshots = @($reviewedScreenshots)
    manualVisualReviewPassed = $true
    immutableInputs = [ordered]@{
        realMc = $realMc
        realOgg = $realOgg
        frozenWpfInstaller = $frozenInstaller
    }
    artifacts = [ordered]@{
        fileCount = $formalFiles.Count
        bytes = $formalBytes
        publishStagingRemoved = $true
        compiledSetupRetained = $true
    }
    changedSources = @(
        "LumaChart.Avalonia\Infrastructure\WindowsExternalApplicationShutdownPolicy.cs",
        "LumaChart.Avalonia\MainWindow.cs",
        "LumaChart.Avalonia.Specs\WindowsAvaloniaInstallerSpecs.cs",
        "tools\Test-WindowsAvaloniaPreviewInstaller.ps1",
        "tools\Capture-WindowsAvaloniaRunningClientRepairSlice.ps1",
        "tools\New-WindowsAvaloniaRunningClientRepairSliceEvidence.ps1")
    remainingDifferences = @(
        "Dirty-document running repair remains intentionally blocked and needs a separate interactive installer UX gate.",
        "Valid setup interruption, Program Files/UAC, signing/timestamp, and a clean disposable VM remain release gates.",
        "The full Windows Avalonia matrix, final UI review, and user replacement approval remain incomplete.")
}
Write-Utf8 $verificationPath ($verification | ConvertTo-Json -Depth 60)
Write-Output (
    "Windows Avalonia running-client repair formal verification: " +
    "passed-migration-incomplete")
Write-Output "Evidence: $verificationPath"
