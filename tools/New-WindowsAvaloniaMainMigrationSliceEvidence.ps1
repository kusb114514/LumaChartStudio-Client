param(
    [string]$Root =
        "artifacts\windows-avalonia-main-migration-slice-20260730-r1"
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia main-migration verification requires PowerShell Core on Windows."
}

$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-main-migration-slice-20260730-r1"))).
    TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal main-migration root must be exactly $expectedRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
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

function Assert-FileHash(
    [string]$Path,
    [long]$ExpectedBytes,
    [string]$ExpectedSha256) {
    $file = File-Evidence $Path
    Assert ($file.bytes -eq $ExpectedBytes) (
        "File length mismatch for ${Path}: $($file.bytes), expected $ExpectedBytes.")
    Assert ($file.sha256 -ceq $ExpectedSha256) (
        "File hash mismatch for ${Path}: $($file.sha256), expected $ExpectedSha256.")
    $file
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -Raw -LiteralPath $Path
    Assert ($text -match "0 个警告") "Strict build lacks zero warnings: $Path"
    Assert ($text -match "0 个错误") "Strict build lacks zero errors: $Path"
    Assert ($text -notmatch (
        "(?i)PublishAot\s*=\s*true|PublishTrimmed\s*=\s*true|" +
        "NativeAOT|OLLVM|obfuscat|代码虚拟化|加壳")) (
        "Strict build contains a forbidden release/protection mode: $Path")
    File-Evidence $Path
}

function Assert-ExactBounds($Actual, $Expected, [string]$Label) {
    Assert (
        [int]$Actual.left -eq [int]$Expected.left -and
        [int]$Actual.top -eq [int]$Expected.top -and
        [int]$Actual.width -eq [int]$Expected.width -and
        [int]$Actual.height -eq [int]$Expected.height
    ) "$Label did not match the monitor bounds."
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$guiPath = Join-Path $formalRoot "gui\evidence.json"
$guiFile = Assert-FileHash $guiPath 17088 (
    "37AE8E8E081BF114D9F510A6D715094D288D4846716AE7CCC5750DE26A4B45BE")
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -ceq (
    "lumachart.windows.avalonia.main-migration-gui-evidence.v1")) (
    "Unexpected GUI evidence schema: $($gui.schema)")
Assert ($gui.status -ceq "passed") "GUI evidence status is not passed."
Assert ($gui.windowsAvaloniaOnly -eq $true -and
    $gui.explicitForegroundConsentReceivedInCurrentConversation -eq $true -and
    $gui.reservedDesktopConsentUsed -eq $false -and
    $gui.persistentTopmostUsed -eq $false) (
    "GUI evidence did not remain inside the authorized non-topmost Windows scope.")
Assert ([long]$gui.foregroundAutomationIdleMilliseconds -ge 3000) (
    "GUI evidence did not satisfy the foreground idle gate.")
Assert ([int]$gui.physicalWin32ActionCount -eq 30) (
    "Expected exactly 30 physical Win32 actions.")
Assert ($gui.productionServerMutationPerformed -eq $false -and
    $gui.socialRelationshipNormalChainRepeated -eq $false -and
    $gui.keySoundSliceRepeated -eq $false -and
    $gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false) (
    "GUI evidence escaped scope or repeated an already closed slice.")
Assert ($gui.fixtures.unchanged -eq $true -and
    $gui.fixtures.before.chart -ceq (
        "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") -and
    $gui.fixtures.after.chart -ceq $gui.fixtures.before.chart) (
    "GUI fixture integrity was not preserved.")

$audioExpected = [ordered]@{
    mp3 = [ordered]@{
        sourceBytes = 11575678
        sourceSha256 = "9FCDCFE8016197E6BC8427E8C7992FFF701D3714851EB367894E674E42EA7606"
        convertedBytes = 5572672
        convertedSha256 = "F1D9BEA2E18B54DE2EBE62EAE92A6B93463569B1FE2D7E89975740BDDCB7A0AA"
    }
    wav = [ordered]@{
        sourceBytes = 1587646
        sourceSha256 = "6832A219EF7E31B7FD2A026F0FC8517BB127CBD746E7051D6DDD5C4E5DB55A6A"
        convertedBytes = 27733
        convertedSha256 = "C19808AE4CF1B55BD65895186CB91EFB3D52D02E509F7F95CF127F085B8F5049"
    }
    flac = [ordered]@{
        sourceBytes = 130200
        sourceSha256 = "E7D0249613CCF945CBED661096191AB74D1D45014BD1BC5DCCB5ADBD1A2B69BD"
        convertedBytes = 47404
        convertedSha256 = "7B07363CB7B826176704598C0229D455E2AE463579CDFBA527BEA5939F60405C"
    }
    m4a = [ordered]@{
        sourceBytes = 146765
        sourceSha256 = "A57EE0966F3EC9DC8C4AC7B15F1E93030021E59DCCEBD5B65852484CECACA864"
        convertedBytes = 28059
        convertedSha256 = "8A49406624C19C1615A4C7548A09646AB35C250528E37CF6DBD1AE302F677338"
    }
    aac = [ordered]@{
        sourceBytes = 363258
        sourceSha256 = "B6C9E4B0647A4E9DB186B109D389C316DD4576214396EDCE0F244C3CB20DDF8A"
        convertedBytes = 28004
        convertedSha256 = "3F88E6DC1885D7F023559B7DFAD99DDD3D4744E2504930AB2FF5BFCF62EB498C"
    }
}

$audioFiles = [ordered]@{}
foreach ($name in $audioExpected.Keys) {
    $expected = $audioExpected[$name]
    $actual = $gui.audioFormats.PSObject.Properties[$name].Value
    Assert ([long]$actual.sourceLength -eq [long]$expected.sourceBytes -and
        [string]$actual.sourceSha256 -ceq [string]$expected.sourceSha256) (
        "$name source evidence differs from the accepted run.")
    Assert ([string]$actual.finalReference -ceq "format-$name.ogg" -and
        [long]$actual.convertedLength -eq [long]$expected.convertedBytes -and
        [string]$actual.convertedSha256 -ceq [string]$expected.convertedSha256 -and
        [string]$actual.convertedPrefix -ceq "4F676753" -and
        [int]$actual.scratchCount -eq 0) (
        "$name was not atomically imported as the expected OGG.")
    $source = Assert-FileHash (
        Join-Path $formalRoot "gui\fixtures\format-$name.$name") (
        [long]$expected.sourceBytes) ([string]$expected.sourceSha256)
    $converted = Assert-FileHash (
        Join-Path $formalRoot "gui\converted\format-$name.ogg") (
        [long]$expected.convertedBytes) ([string]$expected.convertedSha256)
    $prefix = [IO.File]::ReadAllBytes(
        (Join-Path $formalRoot "gui\converted\format-$name.ogg"))[0..3]
    Assert (([Convert]::ToHexString($prefix)) -ceq "4F676753") (
        "$name formal converted file is not OggS.")
    $audioFiles[$name] = [ordered]@{
        source = $source
        converted = $converted
        automaticTempoBoundary = [string]$actual.automaticTempoBoundary
    }
}

$brokenFixture = Assert-FileHash (
    Join-Path $formalRoot "gui\fixtures\broken-codec.m4a") 8 (
    "FE942F6D44D09EBBC652CFE45CE2C2EA447EBB9FE243C6F4B5C6A83E28140CB9")
Assert ([string]$gui.codecFailure.status -ceq (
        "无法导入音频：媒体流无法处理更多的示例，因为流中没有更多的示例。 (0xC00D3E84)") -and
    $gui.codecFailure.metadataUnchanged -eq $true -and
    [string]$gui.codecFailure.referenceBefore -ceq "format-aac.ogg" -and
    [string]$gui.codecFailure.referenceAfter -ceq "format-aac.ogg" -and
    [int]$gui.codecFailure.importedOggCount -eq 0 -and
    [int]$gui.codecFailure.scratchCount -eq 0) (
    "Damaged-codec fail-closed boundary changed.")
Assert ([string]$gui.tabChange.status -ceq "音频导入已取消，未修改当前谱面。" -and
    $gui.tabChange.metadataUnchanged -eq $true -and
    [string]$gui.tabChange.referenceBefore -ceq "Resound - Nhato.ogg" -and
    [string]$gui.tabChange.referenceAfter -ceq "Resound - Nhato.ogg" -and
    [int]$gui.tabChange.importedOggCount -eq 0) (
    "Physical tab-switch cancellation boundary changed.")
Assert ([string]$gui.permissionRevocation.status -ceq (
        "选择谱面音频需要谱面信息权限。") -and
    [int]$gui.permissionRevocation.delayMilliseconds -eq 100 -and
    $gui.permissionRevocation.metadataUnchanged -eq $true -and
    [int]$gui.permissionRevocation.importedOggCount -eq 0) (
    "Late metadata-permission revocation boundary changed.")
Assert ([string]$gui.recoveryWarning.title -ceq "工作区恢复提示" -and
    [string]$gui.recoveryWarning.message -like (
        "*不会用这些缓存静默覆盖可读取的源谱面*另存为*") -and
    $gui.recoveryWarning.wsExTopmost -eq $false -and
    $gui.recoveryWarning.acknowledged -eq $true) (
    "Workspace recovery warning did not preserve the accepted visible boundary.")
Assert ([string]$gui.persistFailure.boundary -ceq "Playtest startup" -and
    [string]$gui.persistFailure.message -like "工作区缓存写入失败：*" -and
    $gui.persistFailure.workingUnchanged -eq $true -and
    [string]$gui.persistFailure.workingSha256Before -ceq (
        "C39D84305E6C50EF9974D3BD377912826056FB9CD695B6B8EE408CB9817E4099") -and
    [string]$gui.persistFailure.workingSha256After -ceq (
        [string]$gui.persistFailure.workingSha256Before) -and
    $gui.persistFailure.playtestOpened -eq $false -and
    $gui.persistFailure.wsExTopmost -eq $false) (
    "Workspace persist failure did not fail closed before Playtest.")
Assert ([string]$gui.fullscreenInheritance.physicalKey -ceq "F11" -and
    $gui.fullscreenInheritance.inherited -eq $true -and
    $gui.fullscreenInheritance.playtestWsExTopmost -eq $false -and
    $gui.fullscreenInheritance.playtestInnerF11Used -eq $false) (
    "Playtest fullscreen inheritance boundary changed.")
Assert-ExactBounds $gui.fullscreenInheritance.mainWindow (
    $gui.fullscreenInheritance.monitor) "Main window"
Assert-ExactBounds $gui.fullscreenInheritance.playtest (
    $gui.fullscreenInheritance.monitor) "Playtest"
Assert ([int]$gui.audioScratchResidueCount -eq 0) (
    "GUI run left audio import scratch residue.")

$screenshotProperties = @($gui.screenshots.PSObject.Properties)
Assert ($screenshotProperties.Count -eq 7) (
    "Expected exactly seven accepted screenshots.")
$screenshotEvidence = @()
foreach ($property in $screenshotProperties) {
    $declared = $property.Value
    $formalPath = Join-Path $formalRoot (
        "gui\screenshots\$($property.Name).png")
    $actual = Assert-FileHash $formalPath (
        [long]$declared.length) ([string]$declared.sha256)
    $screenshotEvidence += [ordered]@{
        name = $property.Name
        file = $actual
        visuallyInspected = $true
    }
}

$safetyPath = Join-Path $formalRoot "safety\gui-automation-safety.json"
$safetyFile = Assert-FileHash $safetyPath 12649 (
    "50341E1D6B236BADE94739215FE9EB1FFCAD1A3101550D2E993DFF1A526ED54B")
$safety = Get-Content -Raw -LiteralPath $safetyPath | ConvertFrom-Json
Assert ($safety.status -ceq "passed" -and
    $safety.windowsAvaloniaOnly -eq $true -and
    $safety.foregroundAutomationRequiresExplicitUserConsent -eq $true -and
    $safety.continuouslyInjectedInputRequiresReservedDesktopConsent -eq $true -and
    $safety.heldModifierGateRequired -eq $true -and
    $safety.persistentTopmostUsed -eq $false -and
    [int]$safety.captureScriptCount -eq 41) (
    "GUI automation safety evidence changed.")
$captureScript = @($safety.scripts | Where-Object {
        [string]$_.path -ceq "tools\Capture-WindowsAvaloniaMainMigrationGui.ps1"
    })
Assert ($captureScript.Count -eq 1 -and
    $captureScript[0].parsed -eq $true -and
    [int]$captureScript[0].consentGuardCount -eq 1 -and
    [int]$captureScript[0].persistentTopmostPatternCount -eq 0) (
    "The main-migration capture script did not pass the exact safety policy.")

$avaloniaSpecsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$avaloniaSpecsFile = Assert-FileHash $avaloniaSpecsPath 153357 (
    "6CDD08ADC89F721BEFADCFC818C7EB56E10CD3FC498C3A3FB90175F7080439C8")
$avaloniaSpecs = Get-Content -Raw -LiteralPath $avaloniaSpecsPath |
    ConvertFrom-Json
$checks = @($avaloniaSpecs.checks)
$passedChecks = @($checks | Where-Object passed)
Assert ($avaloniaSpecs.status -ceq "passed" -and
    $checks.Count -eq 582 -and $passedChecks.Count -eq 582) (
    "Avalonia Specs count mismatch: $($passedChecks.Count)/$($checks.Count)")

$mainSpecsPath = Join-Path $formalRoot "tests\main-specs-run.log"
$mainSpecsFile = Assert-FileHash $mainSpecsPath 5479 (
    "C881CCBC7BEB23F51FB8C52D369964C4303F68E74E9DC74FC99250226033429E")
$mainSpecsText = Get-Content -Raw -LiteralPath $mainSpecsPath
Assert ($mainSpecsText -match "79/79 specs passed") (
    "Main Specs did not pass 79/79.")
$mainSpecsError = Assert-FileHash (
    (Join-Path $formalRoot "tests\main-specs-error.log")) 0 (
    "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855")

$strictBuilds = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $formalRoot "builds\avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "builds\avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "builds\main-specs-build.log")
    onlineGuiServer = Assert-StrictBuild (
        Join-Path $formalRoot "builds\online-gui-server-build.log")
}
Assert ($strictBuilds.avalonia.sha256 -ceq (
        "2C334B0ECECE4900D04CE51B915E789711DBB81156C3E69EDECDE688A5AAA4B2") -and
    $strictBuilds.avaloniaSpecs.sha256 -ceq (
        "249225CB060FF87BEBA1C57B8B790B42A6C48AF412D7284716B1EEE8C9CC365D") -and
    $strictBuilds.mainSpecs.sha256 -ceq (
        "EF06492A6DF396D3B8DBA8B3EBD386A866D6ECEEEFC632A880580A47968164D6") -and
    $strictBuilds.onlineGuiServer.sha256 -ceq (
        "C034486CE82B2BB0E9C6B69772021D7A6082BD855EAFCF0539ECBBF21D99BE85")) (
    "One or more strict build logs changed.")

$realChart = Assert-FileHash "D:\osu!\Songs\Resound\0\1781536331.mc" 99080 (
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E")
$realOsu = Assert-FileHash (
    "D:\osu!\Songs\1005389 Minori Chihara - Michishirube\" +
    "Minori Chihara - Michishirube (eZmmR) [Dear You,  Gilbert Bougainvillea .].osu") 74487 (
    "511866870F99BDC7443006FA7420C7A9D21198F49B9EC13B50A32293E7F58E57")
$realMcz = Assert-FileHash "D:\Project\malody_tool\mc2osu\Infinity_Heaven.mcz" 4019880 (
    "03A50A7C7750CE4CB4C176B6A9BCB6193F7DC186C15D2C290971C3DE5748D3BD")
$installer = Assert-FileHash (
    (Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")) 62484320 (
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4")
$socialAuthority = Assert-FileHash (
    (Join-Path $projectRoot (
        "artifacts\windows-avalonia-online-social-relations-slice-20260730-r1\" +
        "verification-evidence.json"))) 7251 (
    "4DE5C0593738EB7201E82DE3F250E6943339D048734B5AC78DD3D078DF72F8E8")
$keySoundAuthority = Assert-FileHash (
    (Join-Path $projectRoot (
        "artifacts\windows-avalonia-key-sound-loopback-slice-20260730-r1\" +
        "verification-evidence.json"))) 6418 (
    "1C0BE1C2F609CE5C22398E3B485D688BAB1A77B2EBD05F89CD03F3ED782B9987")

$leftoverProcesses = @(Get-Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.ProcessName -like "LumaChart*" -or
        $_.ProcessName -like "WindowsAvaloniaOnlineGuiServer*"
    })
Assert ($leftoverProcesses.Count -eq 0) (
    "LumaChart/test processes remain after the formal GUI run: " +
    (($leftoverProcesses | ForEach-Object {
                "$($_.ProcessName)#$($_.Id)"
            }) -join ", "))

$sourcePaths = @(
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia\ViewModels\MainWindowViewModel.cs",
    "LumaChart.Avalonia\Services\WindowsChartAudioImportWorkflow.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsAudioLibraryCreationPolicy.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsWorkspaceRecoveryNoticePolicy.cs",
    "LumaChart.Avalonia\Dialogs\OnlineAccountDialog.cs",
    "LumaChart.Avalonia\Dialogs\OnlineCommunityDialog.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "LumaChart.Avalonia.Specs\WindowsAudioTempoSpecs.cs",
    "LumaChart.Avalonia.Specs\WindowsDialogParitySpecs.cs",
    "LumaChart.Avalonia.Specs\WindowsOnlineSurfaceParitySpecs.cs",
    "LumaChart.Avalonia.Specs\WindowsSaveFailureRecoverySpecs.cs",
    "LumaChart.Avalonia.Specs\WindowsWpfMainFunctionTruthSpecs.cs",
    "tools\Capture-WindowsAvaloniaMainMigrationGui.ps1",
    "tools\New-WindowsAvaloniaMainMigrationSliceEvidence.ps1"
)
$sourceFiles = @($sourcePaths | ForEach-Object {
        File-Evidence (Join-Path $projectRoot $_)
    })

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.main-migration-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope =
        "windows-avalonia-main-function-audio-workspace-recovery-persist-and-playtest-visible-boundaries"
    formalMigrationAuthority = $true
    formalBatchClosed = $true
    completion = $false
    migrationComplete = $false
    windowsAvaloniaCanReplaceWpf = $false
    userManualReplacementApprovalReceived = $false
    nextPlatformAuthorized = $false
    windowsAvaloniaOnly = $true
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    productionServerMutationPerformed = $false
    socialRelationshipNormalChainRepeated = $false
    keySoundSliceRepeated = $false
    releasedInstallerOverwritten = $false
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    manualVisualReviewPassed = $true
    changedFiles = @(
        $sourcePaths
        "AVALONIA-FUNCTION-MATRIX.md",
        "PROJECT-HANDOFF.md",
        "README.md",
        "NEXT-CHAT-PROMPT.md")
    strictBuilds = $strictBuilds
    avaloniaSpecs = [ordered]@{
        status = $avaloniaSpecs.status
        passed = $passedChecks.Count
        total = $checks.Count
        evidence = $avaloniaSpecsFile
    }
    mainSpecs = [ordered]@{
        passed = 79
        total = 79
        log = $mainSpecsFile
        errorLog = $mainSpecsError
    }
    realGui = [ordered]@{
        status = $gui.status
        schema = $gui.schema
        physicalWin32ActionCount = [int]$gui.physicalWin32ActionCount
        foregroundAutomationIdleMilliseconds =
            [long]$gui.foregroundAutomationIdleMilliseconds
        screenshotCount = $screenshotProperties.Count
        screenshotsVisuallyInspected = $true
        evidence = $guiFile
        stdout = File-Evidence (
            Join-Path $formalRoot "gui\stdout.log")
        stderr = File-Evidence (
            Join-Path $formalRoot "gui\stderr.log")
        screenshots = $screenshotEvidence
        audioFormats = $audioFiles
        damagedCodec = $gui.codecFailure
        tabChange = $gui.tabChange
        permissionRevocation = $gui.permissionRevocation
        workspaceRecoveryWarning = $gui.recoveryWarning
        workspacePersistFailure = $gui.persistFailure
        fullscreenInheritance = $gui.fullscreenInheritance
    }
    safety = [ordered]@{
        evidence = $safetyFile
        captureScript = $captureScript[0]
    }
    integrity = [ordered]@{
        realChart = $realChart
        realOsu = $realOsu
        realMcz = $realMcz
        frozenWpfInstaller = $installer
        socialRelationshipAuthority = $socialAuthority
        keySoundAuthority = $keySoundAuthority
        brokenCodecFixture = $brokenFixture
        sourceFiles = $sourceFiles
        noTestProcessesRemaining = $true
    }
    remainingMigrationDifferences = @(
        "This authority closes the named Windows Avalonia main-function batch, not the complete WPF/Avalonia replacement.",
        "Final WPF pixel-level UI, font, icon, focus, IME, shortcut, modal, multi-DPI and hardware visual review remains open.",
        "True 120 Hz, true 4K, physical scan-out, bounded-volume disk-full, Program Files/UAC, code signing/timestamp and clean-VM release gates remain external.",
        "Additional account, community, room and notification edge matrices remain outside this batch.",
        "Final installer/security replacement audit and explicit user manual replacement approval remain open.")
}

$verification | ConvertTo-Json -Depth 80 |
    Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
Write-Output "Windows Avalonia main-migration slice verification: passed-migration-incomplete"
Write-Output "Evidence: $verificationPath"
