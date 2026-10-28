param(
    [string]$Root =
        "artifacts\windows-avalonia-format-resilience-slice-20260729-r2",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedArchiveDialogScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedEditorScreenshotSha256
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia format-resilience verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-format-resilience-slice-20260729-r2"))).
    TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal format-resilience root must be exactly $expectedRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "Missing file: $full"
    $item = Get-Item -LiteralPath $full
    [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $full)
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

foreach ($hash in @(
        $ExpectedArchiveDialogScreenshotSha256,
        $ExpectedEditorScreenshotSha256)) {
    Assert ($hash -match '^[0-9A-Fa-f]{64}$') "Invalid screenshot SHA-256: $hash"
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists; use a new formal root.")

$strictBuilds = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-release-warnaserror.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\avalonia-specs-release-warnaserror.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\main-specs-release-warnaserror.log")
}

$avaloniaSpecsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$avaloniaSpecs = Get-Content -Raw -LiteralPath $avaloniaSpecsPath |
    ConvertFrom-Json
$avaloniaChecks = @($avaloniaSpecs.checks)
$avaloniaPassed = @($avaloniaChecks | Where-Object passed)
$archiveCheck = @($avaloniaChecks | Where-Object {
        $_.name -ceq (
            "windows-chart-archive-abnormal-paths-fail-closed-and-remain-atomic")
    })
Assert ($avaloniaSpecs.status -ceq "passed") "Avalonia Specs status is not passed."
Assert ($avaloniaChecks.Count -eq 542 -and $avaloniaPassed.Count -eq 542) (
    "Avalonia Specs count mismatch: $($avaloniaPassed.Count)/$($avaloniaChecks.Count)")
Assert ($archiveCheck.Count -eq 1 -and $archiveCheck[0].passed) (
    "Chart archive abnormal-path check did not pass.")
$archiveDetail = [string]$archiveCheck[0].detail
foreach ($requiredDetail in @(
        "classified 1/1/1",
        "two same-name concurrent imports stayed independent",
        "traversal",
        "case-insensitive duplicates",
        "symbolic links",
        ">200x compression",
        "cancellation removed owned staging",
        "valid MC reopened")) {
    Assert ($archiveDetail.Contains($requiredDetail, [StringComparison]::Ordinal)) (
        "Chart archive check detail lacks '$requiredDetail'.")
}

$mainSpecsPath = Join-Path $formalRoot "tests\main-specs.log"
$mainSpecsText = Get-Content -Raw -LiteralPath $mainSpecsPath
Assert ($mainSpecsText -match "79/79 specs passed") "Main Specs did not pass 79/79."

$safetyPath = Join-Path $formalRoot "tests\gui-automation-safety.json"
$safety = Get-Content -Raw -LiteralPath $safetyPath | ConvertFrom-Json
Assert ($safety.status -ceq "passed") "GUI automation safety did not pass."
Assert ($safety.foregroundAutomationRequiresExplicitUserConsent -eq $true) (
    "GUI automation no longer requires explicit user consent.")
Assert ($safety.continuouslyInjectedInputRequiresReservedDesktopConsent -eq $true) (
    "Continuously injected input no longer requires reserved-desktop consent.")
Assert ($safety.heldModifierGateRequired -eq $true -and
        $safety.persistentTopmostUsed -eq $false) (
    "GUI automation modifier/topmost safety contract changed.")

$fixtureManifestPath =
    Join-Path $formalRoot "fixture\mixed-real-resound.mcz.fixture.json"
$fixtureManifest = Get-Content -Raw -LiteralPath $fixtureManifestPath |
    ConvertFrom-Json
Assert ($fixtureManifest.schema -ceq (
    "lumachart.windows.avalonia.mixed-archive-fixture.v1")) (
    "Unexpected mixed-archive fixture schema.")
Assert ($fixtureManifest.windowsOnly -eq $true) "Fixture is not Windows-only."
Assert ([int]$fixtureManifest.expected.supportedCharts -eq 1 -and
        [int]$fixtureManifest.expected.unsupportedCharts -eq 1 -and
        [int]$fixtureManifest.expected.brokenCharts -eq 1 -and
        [int]$fixtureManifest.expected.openedTabs -eq 1) (
    "Fixture expected counts changed.")
$fixtureArchivePath = Join-Path $formalRoot "fixture\mixed-real-resound.mcz"
$fixtureArchive = File-Evidence $fixtureArchivePath
Assert ($fixtureArchive.sha256 -ceq [string]$fixtureManifest.output.sha256) (
    "Mixed archive changed after generation.")

$guiPath = Join-Path $formalRoot "gui\evidence.json"
$gui = Get-Content -Raw -LiteralPath $guiPath | ConvertFrom-Json
Assert ($gui.schema -ceq (
    "lumachart.windows.avalonia.format-fresh-import-gui-evidence.v1")) (
    "Unexpected GUI evidence schema: $($gui.schema)")
Assert ($gui.status -ceq "passed" -and $gui.passed -eq $true) (
    "GUI mixed-archive import did not pass.")
Assert ($gui.windowsAvaloniaOnly -eq $true) "GUI evidence is not Windows-only."
Assert ($gui.mobileProjectsBuiltModifiedInstalledOrTested -eq $false) (
    "GUI evidence touched a mobile project.")
Assert ($gui.productionServerMutationPerformed -eq $false) (
    "GUI evidence mutated the production server.")
Assert ($gui.pureDotnetRelease -eq $true) "GUI evidence is not pure .NET Release."
Assert ($gui.ollvmObfuscationPackingVirtualizationOrAotUsed -eq $false) (
    "GUI evidence used a prohibited protection or AOT mode.")
Assert ($gui.physicalMouseInputUsed -eq $true -and
        @($gui.physicalActions).Count -eq 1) (
    "GUI evidence did not record exactly one physical archive-open action.")
Assert ($gui.foregroundAutomation.reservedDesktopConsentUsed -eq $true -and
        $gui.foregroundAutomation.heldModifierGatePassed -eq $true -and
        $gui.foregroundAutomation.persistentTopmostUsed -eq $false) (
    "GUI foreground automation did not use the reserved-desktop safe path.")
Assert ($gui.archiveDialog.name -ceq "谱包导入完成") (
    "Unexpected archive dialog title.")
$archiveMessage = [string]$gui.archiveDialog.message.name
foreach ($expectedLine in @(
        "可编辑下落式键音谱面：1 张",
        "已忽略其他游玩模式：1 张",
        "无法识别或已损坏：1 张")) {
    Assert ($archiveMessage.Contains($expectedLine, [StringComparison]::Ordinal)) (
        "Archive dialog lacks '$expectedLine'.")
}
Assert ([int]$gui.archiveDialog.expectedCounts.supported -eq 1 -and
        [int]$gui.archiveDialog.expectedCounts.unsupported -eq 1 -and
        [int]$gui.archiveDialog.expectedCounts.broken -eq 1) (
    "GUI archive expected counts changed.")
Assert ([int]$gui.expectedTabCount -eq 1 -and @($gui.tabs).Count -eq 1) (
    "GUI did not open exactly one supported editor tab.")
Assert ([string]$gui.runtime.chart.sourceSha256 -ceq (
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E")) (
    "GUI did not open the immutable real Resound MC.")
Assert ([int]$gui.runtime.chart.structure.noteCount -eq 2753 -and
        [int]$gui.runtime.chart.structure.longNoteCount -eq 771 -and
        [int]$gui.runtime.chart.structure.timingCount -eq 1) (
    "GUI real-chart structure mismatch.")
Assert ($gui.runtime.audio.sourceExists -eq $true -and
        [string]$gui.runtime.audio.state -ceq "Stopped" -and
        [string]$gui.runtime.audio.status -ceq (
            "音频已载入：Resound - Nhato.ogg")) (
    "GUI did not resolve and load the imported real OGG resource.")
$workspaceTree = @($gui.workspaceTree)
Assert ($workspaceTree.Count -eq 5) (
    "GUI workspace file count mismatch: $($workspaceTree.Count)")
Assert (@($workspaceTree | Where-Object {
            $_.relativePath -like "*.lumachart-importing*"
        }).Count -eq 0) (
    "GUI mixed archive left an owned staging directory.")
$workspaceByName = @{}
foreach ($file in $workspaceTree) {
    $workspaceByName[[string]$file.relativePath] = $file
}
foreach ($expectedFile in @(
        [ordered]@{
            suffix = "charts\resound-valid.mc"
            sha256 = "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
        }
        [ordered]@{
            suffix = "charts\Resound - Nhato.ogg"
            sha256 = "00AA7780330A022D7F5D0C4C2BEA23625D31F48BA8CAC2AF25117249BEA05151"
        }
        [ordered]@{
            suffix = "charts\Resound - Nhato.jpg"
            sha256 = "3A1D4D064756C3B23C91217B3909AD5181FEB0A3700BE9D74348C57283B43760"
        })) {
    $matches = @($workspaceTree | Where-Object {
            ([string]$_.relativePath).EndsWith(
                [string]$expectedFile.suffix,
                [StringComparison]::OrdinalIgnoreCase)
        })
    Assert ($matches.Count -eq 1 -and
            [string]$matches[0].sha256 -ceq [string]$expectedFile.sha256) (
        "GUI workspace resource mismatch: $($expectedFile.suffix)")
}
Assert ([string]$gui.input.before.sha256 -ceq $fixtureArchive.sha256 -and
        [string]$gui.input.after.sha256 -ceq $fixtureArchive.sha256 -and
        $gui.input.unchanged -eq $true) (
    "GUI changed the mixed archive input.")

$screenshotEvidence = [ordered]@{}
$screenshotExpectations = [ordered]@{
    "archive-import-dialog.png" =
        $ExpectedArchiveDialogScreenshotSha256.ToUpperInvariant()
    "fresh-import-editor.png" =
        $ExpectedEditorScreenshotSha256.ToUpperInvariant()
}
foreach ($name in $screenshotExpectations.Keys) {
    $file = File-Evidence (Join-Path $formalRoot "gui\$name")
    Assert ($file.sha256 -ceq $screenshotExpectations[$name]) (
        "Screenshot SHA-256 mismatch for $name.")
    $screenshotEvidence[$name] = $file
}
Assert (@(Get-ChildItem -LiteralPath (Join-Path $formalRoot "gui") `
        -File -Filter "*.png").Count -eq 2) (
    "Expected exactly two GUI screenshots.")

$immutableInputs = [ordered]@{
    resoundMc = File-Evidence "D:\osu!\Songs\Resound\0\1781536331.mc"
    resoundOgg = File-Evidence "D:\osu!\Songs\Resound\0\Resound - Nhato.ogg"
    resoundJpg = File-Evidence "D:\osu!\Songs\Resound\0\Resound - Nhato.jpg"
    releasedWpfInstaller =
        File-Evidence (Join-Path $projectRoot "release\LumaChartStudio-Setup.exe")
}
Assert ($immutableInputs.resoundMc.sha256 -ceq (
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E")) (
    "The immutable Resound MC changed.")
Assert ($immutableInputs.resoundOgg.sha256 -ceq (
    "00AA7780330A022D7F5D0C4C2BEA23625D31F48BA8CAC2AF25117249BEA05151")) (
    "The immutable Resound OGG changed.")
Assert ($immutableInputs.resoundJpg.sha256 -ceq (
    "3A1D4D064756C3B23C91217B3909AD5181FEB0A3700BE9D74348C57283B43760")) (
    "The immutable Resound JPG changed.")
Assert ($immutableInputs.releasedWpfInstaller.sha256 -ceq (
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4")) (
    "The frozen WPF installer changed.")

$verification = [ordered]@{
    schema = "lumachart.windows.avalonia.format-resilience-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed"
    scope = "windows-avalonia-mc-mcz-osz-abnormal-and-boundary-compatibility"
    formalMigrationAuthority = $true
    completion = $false
    migrationComplete = $false
    windowsAvaloniaOnly = $true
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    productionServerMutationPerformed = $false
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    priorityPolicy = "main-functions-first-ui-focus-ime-shortcuts-dialog-layer-last"
    strictBuilds = $strictBuilds
    avaloniaSpecs = [ordered]@{
        status = $avaloniaSpecs.status
        passed = $avaloniaPassed.Count
        total = $avaloniaChecks.Count
        failed = $avaloniaChecks.Count - $avaloniaPassed.Count
        evidence = File-Evidence $avaloniaSpecsPath
        log = File-Evidence (Join-Path $formalRoot "tests\avalonia-specs.log")
        archiveResilienceCheck = [ordered]@{
            name = [string]$archiveCheck[0].name
            passed = [bool]$archiveCheck[0].passed
            detail = $archiveDetail
        }
    }
    mainSpecs = [ordered]@{
        status = "passed"
        passed = 79
        total = 79
        log = File-Evidence $mainSpecsPath
    }
    guiAutomationSafety = File-Evidence $safetyPath
    fixture = [ordered]@{
        archive = $fixtureArchive
        manifest = File-Evidence $fixtureManifestPath
    }
    physicalGui = [ordered]@{
        status = $gui.status
        evidence = File-Evidence $guiPath
        physicalMouseInputUsed = [bool]$gui.physicalMouseInputUsed
        archiveClassification = "1 supported / 1 unsupported / 1 broken"
        openedTabs = @($gui.tabs).Count
        realChartNotes = [int]$gui.runtime.chart.structure.noteCount
        realChartLongNotes = [int]$gui.runtime.chart.structure.longNoteCount
        importedAudioResolved = [bool]$gui.runtime.audio.sourceExists
        workspaceFileCount = $workspaceTree.Count
        screenshotCount = 2
        screenshots = $screenshotEvidence
    }
    immutableInputs = $immutableInputs
    knownRemainingDifferences = @(
        "disk-full and ACL-denied archive destinations still need deterministic constrained-volume coverage",
        "legacy malformed MC/MCZ corpus breadth still depends on additional user-provided real-world files",
        "ClientSecurity, update and installer abnormal paths remain the next main-function priority",
        "pixel UI, focus, Chinese IME, shortcuts and external-game dialog layering are intentionally deferred until main functions close"
    )
}

$json = $verification | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText(
    $verificationPath,
    $json + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false))
$written = File-Evidence $verificationPath
Write-Output "Format-resilience verification evidence: $($written.path)"
Write-Output "Bytes: $($written.bytes)"
Write-Output "SHA-256: $($written.sha256)"
