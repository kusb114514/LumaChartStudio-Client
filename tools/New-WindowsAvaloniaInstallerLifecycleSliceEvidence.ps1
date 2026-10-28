param(
    [string]$Root =
        "artifacts\windows-avalonia-installer-lifecycle-slice-20260729-r2",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedInstalledEditorScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedMcEditorScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedMczDialogScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedMczEditorScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedOsuEditorScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedOszDialogScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedOszEditorScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia installer lifecycle verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-installer-lifecycle-slice-20260729-r2"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals(
        $expectedRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal installer lifecycle root must be exactly $expectedRoot"
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

function Get-CurrentUserClassDefault([string]$Extension) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
        "Software\Classes\$Extension")
    try {
        if ($null -eq $key) { return $null }
        return $key.GetValue(
            "",
            $null,
            [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    }
    finally {
        if ($key) { $key.Dispose() }
    }
}

function Test-CurrentUserClassValue([string]$Subkey, [string]$Name) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Subkey)
    try {
        return $null -ne $key -and @($key.GetValueNames()) -contains $Name
    }
    finally {
        if ($key) { $key.Dispose() }
    }
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")
$expectedScreenshotHashes = [ordered]@{
    installedEditor = $ExpectedInstalledEditorScreenshotSha256
    mcEditor = $ExpectedMcEditorScreenshotSha256
    mczDialog = $ExpectedMczDialogScreenshotSha256
    mczEditor = $ExpectedMczEditorScreenshotSha256
    osuEditor = $ExpectedOsuEditorScreenshotSha256
    oszDialog = $ExpectedOszDialogScreenshotSha256
    oszEditor = $ExpectedOszEditorScreenshotSha256
}
foreach ($hash in $expectedScreenshotHashes.Values) {
    Assert ($hash -match "^[0-9A-Fa-f]{64}$") (
        "A reviewed installer lifecycle screenshot SHA-256 is invalid.")
}

$capturePath = Join-Path $formalRoot "capture-evidence.json"
$capture = Get-Content -LiteralPath $capturePath -Raw |
    ConvertFrom-Json -Depth 100
Assert ($capture.schema -ceq
    "lumachart.windows.avalonia.installer-lifecycle-slice-capture.v1") (
    "Unexpected installer lifecycle capture schema.")
Assert ($capture.status -ceq "passed-migration-incomplete" -and
    $capture.formalMigrationAuthority -eq $true -and
    $capture.windowsAvaloniaOnly -eq $true -and
    $capture.pureDotnetRelease -eq $true -and
    $capture.publishSingleFile -eq $false -and
    $capture.publishTrimmed -eq $false -and
    $capture.publishAot -eq $false -and
    $capture.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false -and
    $capture.mobileProjectsBuiltModifiedInstalledOrTested -eq $false -and
    $capture.productionServerMutationPerformed -eq $false) (
    "Formal installer lifecycle scope or build policy differs.")

$buildLogs = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\main-specs-build.log")
}
$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specs = Get-Content -LiteralPath $specsPath -Raw |
    ConvertFrom-Json -Depth 100
$checks = @($specs.checks)
$passedChecks = @($checks | Where-Object passed)
$installerChecks = @($checks | Where-Object {
    $_.name -like "avalonia-installer-*"
})
$expectedManagedSecurityCheckNames = @(
    "windows-dpapi-session-token-round-trips-and-deletes",
    "windows-dpapi-corrupt-ciphertext-fails-closed",
    "windows-online-endpoint-rejects-remote-http-and-allows-loopback-http",
    "managed-client-security-owner-admin-routes-fail-closed-without-native-policy",
    "windows-room-resource-real-http-interruption-corruption-atomic-repair",
    "app-update-policy-has-no-native-clientsecurity-or-ollvm-dependency")
$managedSecurityChecks = @($checks | Where-Object {
    $_.name -in $expectedManagedSecurityCheckNames
})
Assert ($specs.status -ceq "passed" -and
    $checks.Count -eq 527 -and
    $passedChecks.Count -eq 527) (
    "Avalonia Specs count/status differs: $($passedChecks.Count)/$($checks.Count)")
Assert ($installerChecks.Count -eq 8 -and
    @($installerChecks | Where-Object passed).Count -eq 8) (
    "One or more installer lifecycle Specs did not pass.")
Assert ($managedSecurityChecks.Count -eq 6 -and
    @($managedSecurityChecks | Where-Object passed).Count -eq 6) (
    "One or more ordinary managed ClientSecurity Specs did not pass.")
$mainSpecsPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainSpecsText = Get-Content -LiteralPath $mainSpecsPath -Raw
Assert ($mainSpecsText -match "79/79 specs passed") (
    "Main Specs did not pass 79/79.")

$buildEvidencePath = Join-Path $formalRoot (
    "installer-build\build-evidence.json")
$buildEvidence = Get-Content -LiteralPath $buildEvidencePath -Raw |
    ConvertFrom-Json -Depth 100
Assert ($buildEvidence.schema -ceq
        "lumachart.windows.avalonia.preview-installer-build.v1" -and
    $buildEvidence.status -ceq "passed-migration-incomplete" -and
    $buildEvidence.formalMigrationAuthority -eq $true -and
    $buildEvidence.previewVersion -ceq "1.1.0" -and
    $buildEvidence.pureDotnetRelease -eq $true -and
    $buildEvidence.selfContained -eq $true -and
    $buildEvidence.publishSingleFile -eq $false -and
    $buildEvidence.publishTrimmed -eq $false -and
    $buildEvidence.publishAot -eq $false -and
    $buildEvidence.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false -and
    $buildEvidence.publish.nativeClientSecurityPresent -eq $false -and
    [long]$buildEvidence.publish.fileCount -ge 500) (
    "Fresh installer build evidence differs.")
$setupPath = Join-Path $formalRoot (
    "installer-build\installer\LumaChartStudio-Avalonia-Preview-Setup.exe")
$setup = File-Evidence $setupPath
Assert ($setup.sha256 -ceq $capture.setup.beforeLifecycle.sha256 -and
    $setup.sha256 -ceq $capture.setup.afterLifecycle.sha256 -and
    $setup.sha256 -ceq $buildEvidence.installer.file.sha256 -and
    [long]$setup.length -gt 80MB) (
    "Fresh compiled setup hash or size differs.")
$setupVersion = (Get-Item -LiteralPath $setupPath).VersionInfo
Assert ($setupVersion.FileVersion.Trim() -ceq "1.1.0" -and
    $setupVersion.ProductVersion.Trim() -ceq "1.1.0") (
    "Fresh compiled setup version differs.")
Assert (-not (Test-Path -LiteralPath (
        Join-Path $formalRoot "installer-build\publish"))) (
    "Regenerable published payload remains in the formal artifact.")
Assert (-not (Test-Path -LiteralPath (
        Join-Path $formalRoot "installer-build\temp"))) (
    "Installer compile temp remains in the formal artifact.")
Assert ($capture.artifactSizeControl.compiledSetupRetained -eq $true -and
    $capture.artifactSizeControl.publishedPayloadRetained -eq $false -and
    $capture.artifactSizeControl.publishedStagingCleanup.removed -eq $true -and
    [long]$capture.artifactSizeControl.publishedStagingCleanup.bytes -gt 100MB) (
    "Installer artifact-size control evidence differs.")

$lifecyclePath = Join-Path $formalRoot "lifecycle\evidence.json"
$lifecycle = Get-Content -LiteralPath $lifecyclePath -Raw |
    ConvertFrom-Json -Depth 100
Assert ($lifecycle.schema -ceq
        "lumachart.windows.avalonia.preview-installer-lifecycle.v1" -and
    $lifecycle.status -ceq "passed-migration-incomplete" -and
    $lifecycle.formalMigrationAuthority -eq $true -and
    $lifecycle.pureDotnetRelease -eq $true -and
    $lifecycle.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "Formal installer lifecycle evidence differs.")
$corrupt = $lifecycle.lifecycle.corruptedHigherVersionPackage
Assert ($corrupt.rejection.rejected -eq $true -and
    [long]$corrupt.generatedTruncatedPackage.length -eq 4096 -and
    $corrupt.generatedTruncatedPackage.sha256 -cne
        $corrupt.validCurrentPackage.sha256 -and
    $corrupt.installedAppUnchanged -eq $true -and
    $corrupt.editingCacheUnchanged -eq $true -and
    $corrupt.oldVersionPreserved -eq $true -and
    $corrupt.installedAppBefore.sha256 -ceq
        $corrupt.installedAppAfter.sha256 -and
    $corrupt.editingCacheBefore.sha256 -ceq
        $corrupt.editingCacheAfter.sha256 -and
    $corrupt.installedVersionAfter -ceq "1.0.9") (
    "Corrupted setup did not fail closed while preserving the old install/cache.")
Assert ($lifecycle.lifecycle.initialProductVersion -ceq "1.0.9" -and
    $lifecycle.lifecycle.higherVersionUpgradePerformed -eq $true -and
    $lifecycle.lifecycle.higherVersionUpgradeChangedApplication -eq $true -and
    $lifecycle.lifecycle.higherVersionUpgradePreservedEditingCache -eq $true -and
    $lifecycle.lifecycle.sameIdentityRepairPreservedInstalledApp -eq $true -and
    $lifecycle.lifecycle.sameIdentityRepairPreservedEditingCache -eq $true -and
    $lifecycle.lifecycle.installDirectoryRemoved -eq $true -and
    $lifecycle.lifecycle.clientStarted -eq $true -and
    $lifecycle.lifecycle.installedGui.runtimeStatus -ceq "passed" -and
    $lifecycle.lifecycle.installedGui.runtimeMode -ceq "real-chart-editor" -and
    $lifecycle.lifecycle.installedGui.sourceUnchanged -eq $true) (
    "Valid upgrade, repair, installed real-MC GUI, or uninstall evidence differs.")

$expectedFormatTabs = [ordered]@{
    mc = 1
    mcz = 4
    osu = 1
    osz = 4
}
$associationGui =
    $lifecycle.associations.installedOpenWithTargetGui
$associationProperties = @($associationGui.psobject.Properties)
Assert ($lifecycle.associations.installedOpenWithTargetGuiExercised -eq $true -and
    $associationProperties.Count -eq 4 -and
    $lifecycle.associations.defaultsPreserved -eq $true -and
    $lifecycle.associations.previewRegistryRemoved -eq $true -and
    $lifecycle.associations.installDirectoryRemoved -eq $true) (
    "Installed OpenWith target or registry cleanup evidence differs.")
foreach ($entry in $expectedFormatTabs.GetEnumerator()) {
    $format = $associationGui.($entry.Key)
    Assert ($null -ne $format -and
        [long]$format.expectedTabCount -eq [long]$entry.Value -and
        [long]$format.actualTabCount -eq [long]$entry.Value -and
        $format.inputUnchanged -eq $true -and
        [string]$format.registeredCommand -like
            '*LumaChart.Avalonia.exe" "%1"') (
        "Installed OpenWith target GUI evidence differs for $($entry.Key).")
    $formatCapture = Get-Content -LiteralPath (
        [IO.Path]::GetFullPath((Join-Path $projectRoot $format.evidence.path))) -Raw |
        ConvertFrom-Json -Depth 100
    Assert ($formatCapture.status -ceq "passed" -and
        @($formatCapture.tabs).Count -eq [long]$entry.Value -and
        $formatCapture.input.unchanged -eq $true -and
        $formatCapture.process.normalExit -eq $true -and
        [long]$formatCapture.process.exitCode -eq 0) (
        "Installed fresh-format process evidence differs for $($entry.Key).")
}

$associationMap = [ordered]@{
    ".mc" = "LumaChartStudio.AvaloniaPreview.mc"
    ".mcz" = "LumaChartStudio.AvaloniaPreview.mcz"
    ".osu" = "LumaChartStudio.AvaloniaPreview.osu"
    ".osz" = "LumaChartStudio.AvaloniaPreview.osz"
}
foreach ($entry in $associationMap.GetEnumerator()) {
    Assert ((Get-CurrentUserClassDefault $entry.Key) -ceq
        $lifecycle.associations.defaultsBefore.($entry.Key)) (
        "Current default handler changed for $($entry.Key).")
    Assert (-not (Test-CurrentUserClassValue (
            "Software\Classes\$($entry.Key)\OpenWithProgids") $entry.Value)) (
        "Preview OpenWith residue remains for $($entry.Key).")
    Assert (-not (Test-Path -LiteralPath (
            "Registry::HKEY_CURRENT_USER\Software\Classes\$($entry.Value)"))) (
        "Preview ProgID residue remains for $($entry.Key).")
}
Assert (-not (Test-Path -LiteralPath $lifecycle.paths.lifecycleInstall) -and
    -not (Test-Path -LiteralPath $lifecycle.paths.associationInstall)) (
    "A lifecycle installation directory remains.")

$screenshotDeclarations = [ordered]@{
    installedEditor = $lifecycle.lifecycle.installedGui.screenshot
    mcEditor = $associationGui.mc.editorScreenshot
    mczDialog = $associationGui.mcz.archiveDialogScreenshot
    mczEditor = $associationGui.mcz.editorScreenshot
    osuEditor = $associationGui.osu.editorScreenshot
    oszDialog = $associationGui.osz.archiveDialogScreenshot
    oszEditor = $associationGui.osz.editorScreenshot
}
$screenshots = @()
foreach ($name in $screenshotDeclarations.Keys) {
    $declared = $screenshotDeclarations[$name]
    Assert ($null -ne $declared) "Missing screenshot declaration: $name"
    $path = [IO.Path]::GetFullPath((Join-Path $projectRoot $declared.path))
    Assert ($path.StartsWith(
            $formalRoot + '\',
            [StringComparison]::OrdinalIgnoreCase)) (
        "Installer lifecycle screenshot escaped the formal root: $path")
    $actual = File-Evidence $path
    Assert ($actual.sha256 -ceq [string]$declared.sha256 -and
        $actual.sha256 -ceq
            $expectedScreenshotHashes[$name].ToUpperInvariant() -and
        [long]$actual.length -gt 20000) (
        "Reviewed installer lifecycle screenshot differs: $name")
    $screenshots += [ordered]@{
        name = $name
        file = $actual
    }
}
Assert ($screenshots.Count -eq 7) (
    "Expected exactly seven reviewed installer lifecycle screenshots.")

$realMcHash =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$frozenInstallerHash =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
$upgradeFixtureHash =
    "0064F79585F4AED8A0B9EB8F4BA265B6F156606FB818234EF0885D31A39A2353"
$realMc = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
$frozenInstaller = File-Evidence (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
$upgradeFixture = File-Evidence (
    [IO.Path]::GetFullPath($lifecycle.paths.upgradeFromSetup))
Assert ($realMc.sha256 -ceq $realMcHash -and
    $capture.immutableInputs.realMcBefore.sha256 -ceq $realMcHash -and
    $capture.immutableInputs.realMcAfter.sha256 -ceq $realMcHash) (
    "Real MC baseline changed.")
Assert ($frozenInstaller.sha256 -ceq $frozenInstallerHash -and
    $capture.immutableInputs.frozenWpfInstallerBefore.sha256 -ceq
        $frozenInstallerHash -and
    $capture.immutableInputs.frozenWpfInstallerAfter.sha256 -ceq
        $frozenInstallerHash) (
    "Frozen WPF installer changed.")
Assert ($upgradeFixture.sha256 -ceq $upgradeFixtureHash -and
    $capture.immutableInputs.controlledUpgradeFixture.sha256 -ceq
        $upgradeFixtureHash) (
    "Controlled 1.0.9 upgrade fixture changed.")

$processIds = [Collections.Generic.HashSet[int]]::new()
if ($lifecycle.lifecycle.installedGui) {
    $installedCapturePath = [IO.Path]::GetFullPath((Join-Path $projectRoot (
        $lifecycle.lifecycle.installedGui.captureRun.path)))
    $installedCapture =
        Get-Content -LiteralPath $installedCapturePath -Raw |
            ConvertFrom-Json -Depth 100
    Assert ([int]$installedCapture.processId -gt 0) (
        "Installed GUI capture did not record a positive process ID.")
    [void]$processIds.Add([int]$installedCapture.processId)
}
foreach ($property in $associationProperties) {
    $formatEvidencePath = [IO.Path]::GetFullPath((Join-Path $projectRoot (
        $property.Value.evidence.path)))
    $formatEvidence =
        Get-Content -LiteralPath $formatEvidencePath -Raw |
            ConvertFrom-Json -Depth 100
    Assert ([int]$formatEvidence.process.id -gt 0) (
        "Installed association GUI capture did not record a positive process ID: $($property.Name)")
    [void]$processIds.Add([int]$formatEvidence.process.id)
}
$leftovers = @($processIds | Where-Object {
    $candidate = Get-Process -Id $_ -ErrorAction SilentlyContinue
    $null -ne $candidate -and
        $candidate.ProcessName -ceq "LumaChart.Avalonia"
})
Assert ($leftovers.Count -eq 0) (
    "Evidence-owned installed client process remains: $leftovers")

$formalFiles = @(
    Get-ChildItem -LiteralPath $formalRoot -Recurse -File -Force)
$formalBytes = [long]($formalFiles | Measure-Object Length -Sum).Sum
$sourcePaths = @(
    "LumaChart.Avalonia.Specs\WindowsAvaloniaInstallerSpecs.cs",
    "tools\Test-WindowsAvaloniaPreviewInstaller.ps1",
    "tools\Capture-WindowsAvaloniaInstallerLifecycleSlice.ps1",
    "tools\New-WindowsAvaloniaInstallerLifecycleSliceEvidence.ps1")
$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.installer-lifecycle-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        windowsAvaloniaOnly = $true
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        productionServerMutationPerformed = $false
        formalAuthority = "installer-lifecycle-20260729-r2"
    }
    builds = [ordered]@{
        warnings = 0
        errors = 0
        logs = $buildLogs
        installerBuildEvidence = File-Evidence $buildEvidencePath
        setup = $setup
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 527
            total = 527
            failed = 0
            installerChecks = $installerChecks
            evidence = File-Evidence $specsPath
            log = File-Evidence (
                Join-Path $formalRoot "tests\avalonia-specs-run.log")
        }
        mainSpecs = [ordered]@{
            passed = 79
            total = 79
            failed = 0
            log = File-Evidence $mainSpecsPath
        }
        ordinaryManagedClientSecurity = [ordered]@{
            passed = 6
            total = 6
            failed = 0
            checks = $managedSecurityChecks
        }
    }
    lifecycle = [ordered]@{
        lowerVersionInstalled = $true
        corruptedCurrentPackageRejected = $true
        oldBinaryPreservedAfterCorruptPackage = $true
        editingCachePreservedAfterCorruptPackage = $true
        validUpgradeTo110Passed = $true
        sameIdentityRepairPassed = $true
        installedRealMcGuiPassed = $true
        installedOpenWithTargetMcMczOsuOszPassed = $true
        lifecycleUninstallPassed = $true
        fileAssociationInstallUninstallPassed = $true
        defaultHandlersPreserved = $true
        registryResidueCount = 0
        installDirectoryResidueCount = 0
        manualVisualReviewPassed = $true
        screenshotCount = 7
        screenshots = $screenshots
        leftoverEvidenceOwnedProcessIds = $leftovers
        evidence = File-Evidence $lifecyclePath
    }
    ordinaryManagedClientSecurity = [ordered]@{
        dpapiCurrentUserRoundTripAndDelete = $true
        corruptOrOversizedCiphertextFailsClosed = $true
        productionEndpointRequiresHttps = $true
        loopbackHttpRemainsTestOnly = $true
        ownerAdminRoutesAuthorizeBeforeHttp = $true
        roomResourceLengthAndSha256AtomicRepair = $true
        updateVersionPolicyIsPureManaged = $true
        nativeClientSecurityOrOllvmRequired = $false
        formalSpecs = $managedSecurityChecks
    }
    artifactSizeControl = [ordered]@{
        compiledSetupRetained = $true
        regenerablePublishStagingRemoved = $true
        formalFileCountBeforeVerification = $formalFiles.Count
        formalBytesBeforeVerification = $formalBytes
        cleanup = $capture.artifactSizeControl
    }
    source = [ordered]@{
        changedFiles = $sourcePaths
        files = @($sourcePaths | ForEach-Object {
            File-Evidence (Join-Path $projectRoot $_)
        })
    }
    frozenBaselines = [ordered]@{
        realMc = $realMc
        frozenWpfInstaller = $frozenInstaller
        controlledUpgradeFixture = $upgradeFixture
    }
    captureEvidence = File-Evidence $capturePath
    remainingDifferences = @(
        "All-users Program Files/UAC and clean disposable-VM install/upgrade/uninstall remain external gates because the current process is medium integrity.",
        "Valid-setup mid-transaction interruption still requires disposable-VM fault injection; corrupted-package pre-mutation rejection is covered here.",
        "The preview setup remains unsigned and keeps an independent AppId until user replacement approval.",
        "WPF 1.1.0 only opens the server-provided http/https update link, so an in-client package downloader is not a parity requirement; production signing and release-link operations remain release gates.",
        "UI/focus/Chinese IME/shortcut parity is deliberately deferred until main-function closure per user direction.")
    completion = [ordered]@{
        thisSlicePassed = $true
        fullWindowsMigrationComplete = $false
        userReplacementApproval = $false
        otherPlatformAuthorization = $false
    }
}
$verification | ConvertTo-Json -Depth 50 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
File-Evidence $verificationPath | ConvertTo-Json -Depth 6
