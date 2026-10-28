param(
    [string]$Root =
        "artifacts\windows-avalonia-osu-in-place-save-slice-20260728-r1",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedGuiEvidenceSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedSavedScreenshotSha256,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedReopenedScreenshotSha256
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia osu in-place verification requires PowerShell Core on Windows."
}

$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot (
    "artifacts\windows-avalonia-osu-in-place-save-slice-20260728-r1"))).TrimEnd('\')
$formalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).TrimEnd('\')
if (-not $formalRoot.Equals(
        $expectedRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal osu in-place save root must be exactly $expectedRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-HashArgument([string]$Hash, [string]$Label) {
    Assert ($Hash -match '^[0-9A-Fa-f]{64}$') "$Label SHA-256 is invalid."
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "Missing file: $full"
    $item = Get-Item -LiteralPath $full
    [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $full)
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Read-Json([string]$Path) {
    Assert (Test-Path -LiteralPath $Path -PathType Leaf) "Missing JSON: $Path"
    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    Assert ($text -match "(0 个警告|0 Warning\(s\))") (
        "Strict build log lacks zero-warning result: $Path")
    Assert ($text -match "(0 个错误|0 Error\(s\))") (
        "Strict build log lacks zero-error result: $Path")
    Assert ($text -notmatch (
        "(?i)ollvm|obfuscat|virtuali[sz]ation|nativeaot|publish-aot")) (
        "Strict build log contains a forbidden protection or AOT marker: $Path")
    File-Evidence $Path
}

foreach ($hashArgument in @(
        @($ExpectedGuiEvidenceSha256, "GUI evidence"),
        @($ExpectedSavedScreenshotSha256, "Saved screenshot"),
        @($ExpectedReopenedScreenshotSha256, "Reopened screenshot"))) {
    Assert-HashArgument $hashArgument[0] $hashArgument[1]
}

$verificationPath = Join-Path $formalRoot "verification-evidence.json"
Assert (-not (Test-Path -LiteralPath $verificationPath)) (
    "Verification evidence already exists: $verificationPath")

$guiRoot = Join-Path $formalRoot "osu-in-place-save-gui"
$guiEvidencePath = Join-Path $guiRoot "osu-in-place-save-gui-evidence.json"
$guiEvidenceFile = File-Evidence $guiEvidencePath
Assert ($guiEvidenceFile.sha256 -ceq
        $ExpectedGuiEvidenceSha256.ToUpperInvariant()) (
    "GUI evidence hash differs from the reviewed formal evidence.")
$gui = Read-Json $guiEvidencePath
Assert ($gui.schema -ceq
    "lumachart.windows.avalonia.osu-in-place-save-gui-evidence.v1") (
    "osu in-place GUI evidence schema mismatch.")
Assert ($gui.status -ceq "passed-migration-incomplete" -and
        $gui.platform -ceq "Windows Avalonia only" -and
        [bool]$gui.windowsAvaloniaOnly) (
    "osu in-place GUI evidence did not pass Windows-only scope.")
Assert (-not [bool]$gui.mobileProjectsBuiltModifiedInstalledOrTested -and
        -not [bool]$gui.productionServerMutationPerformed -and
        [bool]$gui.pureDotnetRelease -and
        -not [bool]$gui.ollvmObfuscationPackingVirtualizationOrAotUsed -and
        -not [bool]$gui.migrationComplete) (
    "Formal GUI evidence drifted outside the authorized release scope.")

$expectedSourceHash =
    "511866870F99BDC7443006FA7420C7A9D21198F49B9EC13B50A32293E7F58E57"
$expectedSavedHash =
    "64784F23D5CF1F8C4F7DF3D790F526748034850627DFCF297DD03AD8BB1D3AC1"
$expectedInstallerHash =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
Assert ($gui.chart.originalSource.sha256Before -ceq $expectedSourceHash -and
        $gui.chart.originalSource.sha256After -ceq $expectedSourceHash) (
    "Frozen real osu source fixture changed.")
Assert ($gui.chart.isolatedSource.sha256Before -ceq $expectedSourceHash -and
        $gui.chart.isolatedSource.sha256After -ceq $expectedSavedHash -and
        [bool]$gui.chart.isolatedSource.siblingTreeUnchanged -and
        [int]$gui.chart.isolatedSource.scratchFileCount -eq 0) (
    "Isolated osu save did not preserve its source/sibling/scratch contract.")
Assert ($gui.chart.savedSnapshot.sha256 -ceq $expectedSavedHash) (
    "Saved osu evidence snapshot hash differs from the reviewed file.")

$parser = $gui.chart.independentParser
Assert ($parser.parser -ceq "independent PowerShell osu text parser" -and
        $parser.fileHeader -ceq "osu file format v14" -and
        [int]$parser.keyCount -eq 4 -and
        [int]$parser.hitObjectCount -eq 2468 -and
        [int]$parser.longNoteCount -eq 303 -and
        [int]$parser.bpmCount -eq 2 -and
        [int]$parser.inheritedScrollCount -eq 11) (
    "Independent osu parser structure differs from the formal fixture.")
Assert ($parser.target.authoredBeat -ceq "15:5/6" -and
        [int]$parser.target.expectedUiLane -eq 3 -and
        [int]$parser.target.calculatedTimeMilliseconds -eq 11920 -and
        [int]$parser.target.volume -eq 73 -and
        $parser.target.raw -ceq "320,192,11920,1,0,0:0:0:73:") (
    "Independent parser did not find the exact GUI-edited target Tap.")

Assert (@($gui.gui.physicalActions).Count -eq 3 -and
        @($gui.gui.physicalActions | Where-Object {
            $_.input -ceq
                "physical Win32 mouse click at UI Automation bounds"
        }).Count -eq 3) (
    "Apply, command-menu and Save were not all physical pointer actions.")
Assert ([int]$gui.gui.initialTarget.volume -eq 100 -and
        [int]$gui.gui.savedTarget.volume -eq 73 -and
        [int]$gui.gui.reopenedTarget.volume -eq 73 -and
        [bool]$gui.gui.savedSessionClean -and
        [bool]$gui.gui.reopenedSessionClean -and
        [bool]$gui.gui.freshProcessReopen -and
        [bool]$gui.gui.exactRationalBeatPreserved -and
        [bool]$gui.gui.structureSha256EqualAfterReopen) (
    "GUI save/close/fresh-process reopen contract did not pass.")
foreach ($target in @(
        $gui.gui.initialTarget,
        $gui.gui.savedTarget,
        $gui.gui.reopenedTarget)) {
    Assert ([int]$target.lane -eq 2 -and
            [int]$target.beat.bar -eq 15 -and
            [int]$target.beat.numerator -eq 5 -and
            [int]$target.beat.denominator -eq 6) (
        "A GUI phase lost the exact authored Beat 15:5/6 or UI lane 3.")
}

$savedScreenshotPath = Join-Path $guiRoot "saved-editor.png"
$savedScreenshot = File-Evidence $savedScreenshotPath
Assert ($savedScreenshot.sha256 -ceq
        $ExpectedSavedScreenshotSha256.ToUpperInvariant() -and
        $savedScreenshot.sha256 -ceq $gui.gui.savedScreenshot.sha256) (
    "Saved screenshot differs from the visually reviewed image.")
$reopenedScreenshotPath = Join-Path $guiRoot "reopened-editor.png"
$reopenedScreenshot = File-Evidence $reopenedScreenshotPath
Assert ($reopenedScreenshot.sha256 -ceq
        $ExpectedReopenedScreenshotSha256.ToUpperInvariant() -and
        $reopenedScreenshot.sha256 -ceq
            $gui.gui.reopenedScreenshot.sha256) (
    "Reopened screenshot differs from the visually reviewed image.")
$saveCapture = Read-Json (Join-Path $guiRoot "save-capture-result.json")
$reopenCapture = Read-Json (Join-Path $guiRoot "reopen-capture-result.json")
foreach ($capture in @($saveCapture, $reopenCapture)) {
    Assert ([int]$capture.screenshotWidth -eq 1980 -and
            [int]$capture.screenshotHeight -eq 1200 -and
            [int]$capture.screenshotSampledUniqueColors -ge 20 -and
            [double]$capture.screenshotSampledLuminanceStdDev -ge 1.5) (
        "A formal screenshot is visually degenerate or uses the wrong viewport.")
}

$safetyPath = Join-Path $formalRoot "gui-automation-safety.json"
$safety = Read-Json $safetyPath
Assert ($safety.schema -ceq
        "lumachart.windows.avalonia.gui-automation-safety.v1" -and
        $safety.status -ceq "passed" -and
        [bool]$safety.windowsAvaloniaOnly -and
        [bool]$safety.foregroundAutomationRequiresExplicitUserConsent -and
        [int]$safety.minimumSystemIdleMilliseconds -ge 3000 -and
        [bool]$safety.heldModifierGateRequired -and
        -not [bool]$safety.persistentTopmostUsed) (
    "GUI automation safety boundaries drifted.")
Assert ([int]$safety.captureScriptCount -ge 26 -and
        @($safety.scripts | Where-Object {
            $_.path -match
                "Capture-WindowsAvaloniaOsuInPlaceSaveGui\.ps1$"
        }).Count -eq 1) (
    "The osu in-place GUI capture is absent from the safety scan.")

$buildRoot = Join-Path $formalRoot "build"
$buildEvidence = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $buildRoot "avalonia-build.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $buildRoot "avalonia-specs-build.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $buildRoot "main-specs-build.log")
    onlineGuiServer = Assert-StrictBuild (
        Join-Path $buildRoot "online-gui-server-build.log")
}

$testsRoot = Join-Path $formalRoot "tests"
$avaloniaSpecsPath = Join-Path $testsRoot "avalonia-specs-evidence.json"
$avaloniaSpecs = Read-Json $avaloniaSpecsPath
Assert ($avaloniaSpecs.Status -ceq "passed" -and
        @($avaloniaSpecs.Checks).Count -eq 482 -and
        @($avaloniaSpecs.Checks | Where-Object {
            -not [bool]$_.Passed
        }).Count -eq 0) (
    "Avalonia Specs are not 482/482.")
$osuChecks = @($avaloniaSpecs.Checks | Where-Object {
    $_.Name -like "real-osu-in-place-*"
})
Assert ($osuChecks.Count -eq 3 -and
        @($osuChecks | Where-Object { -not [bool]$_.Passed }).Count -eq 0) (
    "The three automated real-osu in-place specs did not pass.")
$mainSpecsPath = Join-Path $testsRoot "main-specs-run.log"
$mainSpecsText = Get-Content -LiteralPath $mainSpecsPath -Raw -Encoding UTF8
Assert ($mainSpecsText -match "79/79 specs passed\.") (
    "Main Specs are not 79/79.")

Assert ($gui.installer.sha256Before -ceq $expectedInstallerHash -and
        $gui.installer.sha256After -ceq $expectedInstallerHash) (
    "Frozen WPF installer hash changed.")

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.osu-in-place-save-slice-verification.v1"
    status = "passed-migration-incomplete"
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    platform = "Windows Avalonia only"
    windowsAvaloniaOnly = $true
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    productionServerMutationPerformed = $false
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    migrationComplete = $false
    guiEvidence = $guiEvidenceFile
    screenshots = [ordered]@{
        saved = $savedScreenshot
        reopened = $reopenedScreenshot
    }
    guiAutomationSafety = File-Evidence $safetyPath
    builds = $buildEvidence
    tests = [ordered]@{
        avaloniaSpecs = File-Evidence $avaloniaSpecsPath
        avaloniaSpecsRun = File-Evidence (
            Join-Path $testsRoot "avalonia-specs-run.log")
        avaloniaSpecsPassed = 482
        avaloniaSpecsFailed = 0
        realOsuInPlaceChecksPassed = 3
        mainSpecs = File-Evidence $mainSpecsPath
        mainSpecsPassed = 79
        mainSpecsFailed = 0
    }
    fileCompatibility = [ordered]@{
        format = "osu file format v14"
        sourceSha256 = $expectedSourceHash
        savedSha256 = $expectedSavedHash
        keyCount = 4
        hitObjectCount = 2468
        longNoteCount = 303
        bpmCount = 2
        inheritedScrollCount = 11
        targetBeat = "15:5/6"
        targetUiLane = 3
        volumeBefore = 100
        volumeAfter = 73
        siblingResourcesUnchanged = $true
        freshProcessReopenPassed = $true
    }
    frozenInstallerSha256 = $expectedInstallerHash
}
[IO.File]::WriteAllText(
    $verificationPath,
    ($verification | ConvertTo-Json -Depth 20),
    [Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    status = $verification.status
    verificationPath = $verificationPath
    verificationSha256 = (
        Get-FileHash -LiteralPath $verificationPath -Algorithm SHA256).Hash
    guiEvidenceSha256 = $guiEvidenceFile.sha256
    savedScreenshotSha256 = $savedScreenshot.sha256
    reopenedScreenshotSha256 = $reopenedScreenshot.sha256
    avaloniaSpecs = "482/482"
    mainSpecs = "79/79"
}
