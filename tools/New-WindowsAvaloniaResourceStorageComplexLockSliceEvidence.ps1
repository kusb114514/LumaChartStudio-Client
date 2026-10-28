param(
    [string]$Root =
        "artifacts\windows-avalonia-resource-storage-complex-lock-slice-20260729-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedSplitScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedMergedScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia resource/lock verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-resource-storage-complex-lock-slice-20260729-r1"))).
    TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal resource/lock root must be exactly $expectedRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
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
        } else {
            $full
        }
        bytes = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -Raw -LiteralPath $Path
    Assert ($text -match "0 个警告") "Strict build lacks zero warnings: $Path"
    Assert ($text -match "0 个错误") "Strict build lacks zero errors: $Path"
    File-Evidence $Path
}

function Assert-Beat(
    $Beat,
    [int]$Bar,
    [int]$Numerator,
    [int]$Denominator,
    [string]$Label) {
    Assert (
        [int]$Beat.bar -eq $Bar -and
        [int]$Beat.numerator -eq $Numerator -and
        [int]$Beat.denominator -eq $Denominator
    ) "$Label differs from ${Bar}:${Numerator}/${Denominator}."
}

foreach ($hash in @(
        $ExpectedSplitScreenshotSha256,
        $ExpectedMergedScreenshotSha256)) {
    Assert ($hash -match '^[0-9A-Fa-f]{64}$') "Invalid screenshot SHA-256: $hash"
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$strictBuilds = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $formalRoot "gates\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "gates\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "gates\main-specs-build.log")
    loopbackGuiServer = Assert-StrictBuild (
        Join-Path $formalRoot "gates\gui-server-build.log")
}

$avaloniaSpecsPath = Join-Path $formalRoot "gates\avalonia-specs-evidence.json"
$avaloniaSpecs = Get-Content -Raw -LiteralPath $avaloniaSpecsPath |
    ConvertFrom-Json
$avaloniaChecks = @($avaloniaSpecs.checks)
$avaloniaPassed = @($avaloniaChecks | Where-Object passed)
Assert ($avaloniaSpecs.status -ceq "passed") "Avalonia Specs status is not passed."
Assert ($avaloniaChecks.Count -eq 555 -and $avaloniaPassed.Count -eq 555) (
    "Avalonia Specs count mismatch: $($avaloniaPassed.Count)/$($avaloniaChecks.Count)")
$resourceCheck = @($avaloniaChecks | Where-Object {
        $_.name -ceq (
            "windows-room-resource-real-http-interruption-concurrency-atomic-repair")
    })
Assert ($resourceCheck.Count -eq 1 -and $resourceCheck[0].passed) (
    "The real filesystem/HTTP room-resource resilience check did not pass.")
Assert ([string]$resourceCheck[0].detail -like (
        "*real NTFS destination denial propagated without cache misclassification*" +
        "recovered from the verified cache*")) (
    "The resource check did not prove real NTFS denial classification and recovery.")

$mainSpecsPath = Join-Path $formalRoot "gates\main-specs.log"
$mainSpecsText = Get-Content -Raw -LiteralPath $mainSpecsPath
Assert ($mainSpecsText -match "79/79 specs passed") "Main Specs did not pass 79/79."
Assert ($mainSpecsText -match (
        "PASS\s+Room chart lock selections toggle exact unions and differences atomically")) (
    "The authoritative exact union/difference main spec did not pass.")

$guiPath = Join-Path $formalRoot "gui\evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -ceq (
    "lumachart.windows.avalonia.two-client-multi-object-continuous-lock-gui-evidence.v5")) (
    "Unexpected GUI evidence schema: $($gui.schema)")
Assert ($gui.status -ceq "passed" -and $gui.formalMigrationAuthority -eq $true) (
    "GUI evidence is not passed formal authority.")
Assert ($gui.windowsAvaloniaOnly -eq $true -and
    $gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false -and
    $gui.productionServerMutationPerformed -eq $false) (
    "GUI evidence escaped the Windows-only isolated scope.")
Assert ($gui.pureDotnetRelease -eq $true -and
    $gui.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "GUI evidence used a forbidden build/protection mode.")
Assert ($gui.physicalMouseInputUsed -eq $true -and
    $gui.automationDiagnosticNonFormal -eq $false) (
    "GUI evidence was not a physical-input formal gate.")
Assert (@($gui.physicalActions).Count -eq 54) (
    "Expected exactly 54 physical actions, got $(@($gui.physicalActions).Count).")

$continuous = $gui.continuousLock
Assert ([int]$continuous.rawRequestedRangeCount -eq 1 -and
    [int]$continuous.authoritativeLockCount -eq 1 -and
    $continuous.exactStart -eq $true -and
    $continuous.exactEnd -eq $true -and
    [int]$continuous.ownerRegionCount -eq 1 -and
    [int]$continuous.memberRegionCount -eq 1) (
    "The original five-object selection was not one exact continuous lock.")
Assert-Beat $continuous.authoritativeLock.startBeat 320 0 4 "Initial lock start"
Assert-Beat $continuous.authoritativeLock.endBeat 320 9 12 "Initial lock end"

$difference = $gui.complexExistingLockDifference
Assert ($difference.splitWasUnlock -eq $true -and
    [int]$difference.splitAuthoritativeLockCount -eq 2 -and
    [int]$difference.ownerRegionCountAfterSplit -eq 2 -and
    [int]$difference.memberRegionCountAfterSplit -eq 2) (
    "The internal exact Tap unlock did not converge on two remnants.")
Assert-Beat $difference.requestedRange.startBeat 320 2 12 "Difference start"
Assert-Beat $difference.requestedRange.endBeat 320 3 12 "Difference end"
Assert-Beat $difference.exactLeftRemnant.startBeat 320 0 4 "Left remnant start"
Assert-Beat $difference.exactLeftRemnant.endBeat 320 2 12 "Left remnant end"
Assert-Beat $difference.exactRightRemnant.startBeat 320 3 12 "Right remnant start"
Assert-Beat $difference.exactRightRemnant.endBeat 320 9 12 "Right remnant end"
Assert ($difference.relockWasUnlock -eq $false -and
    [int]$difference.relockedAuthoritativeLockCount -eq 1 -and
    $difference.exactOriginalRangeRestored -eq $true) (
    "Relocking the exact gap did not merge back to the original range.")
Assert ($gui.unlock.passed -eq $true -and
    [int]$gui.unlock.rawToggleCount -eq 4 -and
    [int]$gui.unlock.authoritativeLockCount -eq 0 -and
    [int]$gui.unlock.memberRegionCount -eq 0) (
    "The final fourth physical toggle did not remove the lock everywhere.")

$screenshotEvidence = @()
$screenshotProperties = @($gui.screenshots.PSObject.Properties)
Assert ($screenshotProperties.Count -eq 18) (
    "Expected 18 declared GUI screenshots, got $($screenshotProperties.Count).")
$formalGuiRoot = (Join-Path $formalRoot "gui").TrimEnd('\') + '\'
foreach ($property in $screenshotProperties) {
    $declared = $property.Value
    $full = [IO.Path]::GetFullPath([string]$declared.path)
    Assert ($full.StartsWith(
        $formalGuiRoot,
        [StringComparison]::OrdinalIgnoreCase)) (
        "Screenshot escaped the formal GUI root: $full")
    $actual = File-Evidence $full
    Assert ($actual.bytes -eq [long]$declared.length) (
        "Screenshot length mismatch: $full")
    Assert ($actual.sha256 -ceq [string]$declared.sha256) (
        "Screenshot hash mismatch: $full")
    $screenshotEvidence += [ordered]@{
        name = $property.Name
        file = $actual
        visuallyInspected = $true
    }
}

$splitScreenshot = File-Evidence (
    Join-Path $formalRoot "gui\owner-complex-lock-two-remnants.png")
$mergedScreenshot = File-Evidence (
    Join-Path $formalRoot "gui\owner-complex-lock-merged-again.png")
Assert ($splitScreenshot.sha256 -ceq
    $ExpectedSplitScreenshotSha256.ToUpperInvariant()) (
    "Visually inspected split-lock screenshot hash changed.")
Assert ($mergedScreenshot.sha256 -ceq
    $ExpectedMergedScreenshotSha256.ToUpperInvariant()) (
    "Visually inspected merged-lock screenshot hash changed.")
Assert (-not (Test-Path -LiteralPath (
        Join-Path $formalRoot "gui\failure.json"))) (
    "Formal GUI root contains failure.json.")

$realChart = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
Assert ($realChart.sha256 -ceq (
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E")) (
    "Frozen real MC hash changed.")
$installer = File-Evidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
Assert ($installer.sha256 -ceq (
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4")) (
    "Frozen WPF installer hash changed.")
$predecessor = File-Evidence (
    Join-Path $projectRoot (
        "artifacts\windows-avalonia-resource-download-revision-slice-20260729-r1\" +
        "verification-evidence.json"))
Assert ($predecessor.sha256 -ceq (
    "1EF8908076926D2CEA96869E085472A36592EF9DCB941D5F4A89C05C96E776D7")) (
    "Predecessor formal authority hash changed.")

$sourceFiles = @(
    "LumaChart.Avalonia\Services\WindowsOnlineRoomResourceService.cs",
    "LumaChart.Avalonia.Specs\WindowsRoomResourceResilienceSpecs.cs",
    "LumaChart.Specs\Program.cs",
    "tools\Capture-WindowsAvaloniaTwoClientOnlineGui.ps1",
    "tools\New-WindowsAvaloniaResourceStorageComplexLockSliceEvidence.ps1"
) | ForEach-Object { File-Evidence (Join-Path $projectRoot $_) }

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.resource-storage-complex-lock-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = "windows-avalonia-room-resource-storage-classification-and-complex-lock-difference"
    formalMigrationAuthority = $true
    completion = $false
    migrationComplete = $false
    windowsAvaloniaCanReplaceWpf = $false
    userManualReplacementApprovalReceived = $false
    nextPlatformAuthorized = $false
    windowsAvaloniaOnly = $true
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    productionServerMutationPerformed = $false
    releasedInstallerOverwritten = $false
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    runtimeStorage = [ordered]@{
        dotnetCliHome = Join-Path $projectRoot ".codex-dotnet-home"
        nugetPackages = Join-Path $projectRoot ".codex-nuget-packages"
        nugetHttpCache = Join-Path $projectRoot ".codex-nuget-http-cache"
        temp = Join-Path $projectRoot ".codex-temp"
        systemDriveProjectCacheUsed = $false
    }
    changedFiles = @(
        "LumaChart.Avalonia\Services\WindowsOnlineRoomResourceService.cs",
        "LumaChart.Avalonia.Specs\WindowsRoomResourceResilienceSpecs.cs",
        "LumaChart.Specs\Program.cs",
        "tools\Capture-WindowsAvaloniaTwoClientOnlineGui.ps1",
        "tools\New-WindowsAvaloniaResourceStorageComplexLockSliceEvidence.ps1",
        "AVALONIA-FUNCTION-MATRIX.md",
        "PROJECT-HANDOFF.md",
        "README.md",
        "NEXT-CHAT-PROMPT.md")
    strictBuilds = $strictBuilds
    avaloniaSpecs = [ordered]@{
        status = $avaloniaSpecs.status
        passed = $avaloniaPassed.Count
        total = $avaloniaChecks.Count
        evidence = File-Evidence $avaloniaSpecsPath
        realNtfsDestinationDenial = $resourceCheck[0]
    }
    mainSpecs = [ordered]@{
        passed = 79
        total = 79
        log = File-Evidence $mainSpecsPath
        complexExactRationalDifferenceAdded = $true
        extremeDenominator = 999983
    }
    realGui = [ordered]@{
        status = $gui.status
        schema = $gui.schema
        realChartNoteCount = [int]$gui.selection.realChartNoteCount
        selectedNoteCount = [int]$gui.selection.selectedNoteCount
        selectedTimingCount = [int]$gui.selection.selectedTimingCount
        physicalActionCount = @($gui.physicalActions).Count
        screenshotCount = $screenshotProperties.Count
        screenshotsVisuallyInspected = $true
        splitScreenshot = $splitScreenshot
        mergedScreenshot = $mergedScreenshot
        continuousLock = $continuous
        complexExistingLockDifference = $difference
        finalUnlock = $gui.unlock
        evidence = File-Evidence $guiPath
    }
    integrity = [ordered]@{
        realChart = $realChart
        frozenWpfInstaller = $installer
        predecessorAuthority = $predecessor
        sourceFiles = $sourceFiles
        screenshots = $screenshotEvidence
    }
    remainingMigrationDifferences = @(
        "This slice closes destination ACL/storage error classification and one complex existing-lock difference/remerge path, not the complete WPF/Avalonia feature matrix.",
        "A true bounded-volume low-space/disk-full gate remains external.",
        "Real account/community/room failure chains still require additional closure.",
        "1080p, 1440p, true 4K, multiple scaling factors and 120 Hz hardware gates remain incomplete.",
        "Final UI/font/icon/focus/IME/shortcut parity, installer/security replacement audit and user manual replacement approval remain open.")
}

$verification | ConvertTo-Json -Depth 80 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
Write-Output "Windows Avalonia resource/storage and complex-lock verification: passed"
Write-Output "Evidence: $verificationPath"
