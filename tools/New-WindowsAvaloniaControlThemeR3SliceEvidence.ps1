param(
    [Parameter(Mandatory = $true)][string]$AuthorityRoot
)

$ErrorActionPreference = "Stop"

function Resolve-ExistingFile([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "$Label not found: $full"
    }
    return $full
}

function Get-FileRecord([string]$Path) {
    $full = Resolve-ExistingFile $Path "Evidence file"
    $item = Get-Item -LiteralPath $full
    return [ordered]@{
        path = $item.FullName
        lengthBytes = $item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
}

function Assert-StrictBuildLog([string]$Path, [string]$Name) {
    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -notmatch "已成功生成。" -or
        $content -notmatch "0 个警告" -or
        $content -notmatch "0 个错误") {
        throw "Strict build log did not prove 0 warning / 0 error: $Name"
    }
}

function Get-VerifiedScreenshotRecords(
    [string]$Directory,
    [object]$DeclaredScreenshots) {
    $records = @()
    foreach ($property in $DeclaredScreenshots.PSObject.Properties) {
        $declared = $property.Value
        $path = Resolve-ExistingFile $declared.path "Declared screenshot"
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if ($hash -cne [string]$declared.sha256) {
            throw "Screenshot hash differs: $($property.Name)"
        }
        $records += [ordered]@{
            name = $property.Name
            path = $path
            lengthBytes = (Get-Item -LiteralPath $path).Length
            sha256 = $hash
            declaredHashMatches = $true
        }
    }
    $actualPngCount = @(Get-ChildItem -LiteralPath $Directory -Filter "*.png" -File).Count
    if ($actualPngCount -ne $records.Count) {
        throw "Screenshot directory contains $actualPngCount PNGs, but evidence declares $($records.Count)."
    }
    return @($records | Sort-Object name)
}

$authorityFullPath = [IO.Path]::GetFullPath($AuthorityRoot)
if (-not (Test-Path -LiteralPath $authorityFullPath -PathType Container)) {
    throw "Authority root not found: $authorityFullPath"
}
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedAuthority = Join-Path $projectRoot `
    "artifacts\windows-avalonia-control-theme-slice-20260727-r3"
if (-not $authorityFullPath.Equals(
        [IO.Path]::GetFullPath($expectedAuthority),
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "This generator only accepts the formal control-theme r3 authority."
}

$buildLogs = [ordered]@{
    avalonia = Join-Path $authorityFullPath "build\avalonia.log"
    avaloniaSpecs = Join-Path $authorityFullPath "build\avalonia-specs.log"
    mainSpecs = Join-Path $authorityFullPath "build\main-specs.log"
}
foreach ($property in $buildLogs.GetEnumerator()) {
    Assert-StrictBuildLog $property.Value $property.Key
}

$avaloniaSpecsPath = Resolve-ExistingFile `
    (Join-Path $authorityFullPath "specs\avalonia-specs-evidence.json") `
    "Avalonia Specs evidence"
$avaloniaSpecs = Get-Content -LiteralPath $avaloniaSpecsPath -Raw |
    ConvertFrom-Json
$avaloniaChecks = @($avaloniaSpecs.Checks)
$avaloniaPassed = @($avaloniaChecks | Where-Object Passed).Count
if ($avaloniaSpecs.Status -cne "passed" -or
    $avaloniaChecks.Count -ne 414 -or
    $avaloniaPassed -ne 414) {
    throw "Avalonia Specs did not prove 414/414."
}
$tabSpec = @(
    $avaloniaChecks |
        Where-Object {
            $_.Name -ceq
                "control-theme-wpf-tabitem-states-and-metrics-are-global"
        }
)
$dangerSpec = @(
    $avaloniaChecks |
        Where-Object {
            $_.Name -ceq
                "control-theme-wpf-danger-menu-hover-is-exact"
        }
)
if ($tabSpec.Count -ne 1 -or -not $tabSpec[0].Passed -or
    $tabSpec[0].Detail -notlike "*global=true*" -or
    $tabSpec[0].Detail -notlike "*padding=7,10*" -or
    $dangerSpec.Count -ne 1 -or -not $dangerSpec[0].Passed -or
    $dangerSpec[0].Detail -notlike "*hover=#4A292B/#FFEEEE*" -or
    $dangerSpec[0].Detail -notlike "*minWidth=190*") {
    throw "Avalonia Specs did not prove the exact global TabItem and danger-menu contracts."
}

$mainSpecsPath = Resolve-ExistingFile `
    (Join-Path $authorityFullPath "specs\main-specs.log") `
    "Main Specs log"
if ((Get-Content -LiteralPath $mainSpecsPath -Raw) -notmatch
    "79/79 specs passed\.") {
    throw "Main Specs did not prove 79/79."
}

$inspectorEvidencePath = Resolve-ExistingFile `
    (Join-Path $authorityFullPath "inspector-gui\inspector-parity-gui-evidence.json") `
    "Inspector GUI evidence"
$inspectorEvidence = Get-Content -LiteralPath $inspectorEvidencePath -Raw |
    ConvertFrom-Json
if ($inspectorEvidence.schema -cne
        "lumachart.windows.avalonia.inspector-parity-gui-evidence.v4" -or
    $inspectorEvidence.status -cne "passed-migration-incomplete" -or
    $inspectorEvidence.controlTheme.contract -cne "wpf-1.1.0-controls-r3" -or
    -not $inspectorEvidence.source.unchanged -or
    [int]$inspectorEvidence.source.noteCount -ne 2753 -or
    -not $inspectorEvidence.inspector.singleRow -or
    -not $inspectorEvidence.inspector.wpfOrder -or
    -not $inspectorEvidence.controlTheme.tabItem.globalTheme -or
    -not $inspectorEvidence.controlTheme.tabItem.physicalPointerHoverCaptured -or
    [string]$inspectorEvidence.screenshots.timing.sha256 -ceq
        [string]$inspectorEvidence.screenshots.tabHover.sha256) {
    throw "Inspector GUI did not prove the global WPF TabItem states."
}
$inspectorScreenshots = Get-VerifiedScreenshotRecords `
    (Join-Path $authorityFullPath "inspector-gui") `
    $inspectorEvidence.screenshots
if ($inspectorScreenshots.Count -ne 18) {
    throw "Inspector GUI did not declare exactly 18 screenshots."
}

$dangerEvidencePath = Resolve-ExistingFile `
    (Join-Path $authorityFullPath "danger-gui-r5\danger-gui-evidence.json") `
    "Danger-menu GUI evidence"
$dangerEvidence = Get-Content -LiteralPath $dangerEvidencePath -Raw |
    ConvertFrom-Json
$dangerAction = $dangerEvidence.libraryDeletionAction
if (-not $dangerEvidence.libraryDeletionExercised -or
    -not $dangerEvidence.libraryOpenDocumentBlockExercised -or
    $dangerEvidence.libraryDeletionRequestedOutcome -cne "Blocked" -or
    $dangerAction.contextMenuItem.automationId -cne
        "Library.DeleteContextMenuItem" -or
    $dangerAction.contextMenuItem.name -cne "删除此歌曲文件夹" -or
    -not $dangerAction.dangerMenuPhysicalHover.screenshotCaptured -or
    $dangerAction.dangerMenuPhysicalHover.automationFallbackUsed -or
    -not $dangerAction.targetExistedBefore -or
    -not $dangerAction.targetExistsAfter -or
    $dangerAction.dialog.name -cne "无法删除" -or
    $dangerAction.dialogConfirm.name -cne "确定" -or
    -not $dangerAction.warningTone -or
    -not $dangerAction.clipboardExactMessage -or
    -not $dangerEvidence.interactionCapturedAfterActions) {
    throw "Danger-menu GUI did not prove physical hover and fail-closed deletion."
}

$dangerRuntimePath = Resolve-ExistingFile `
    (Join-Path $authorityFullPath "danger-gui-r5\runtime-evidence.json") `
    "Danger-menu runtime evidence"
$dangerInteractionPath = Resolve-ExistingFile `
    (Join-Path $authorityFullPath "danger-gui-r5\interaction-evidence.json") `
    "Danger-menu interaction evidence"
if ((Get-FileHash -LiteralPath $dangerRuntimePath -Algorithm SHA256).Hash -cne
        [string]$dangerEvidence.evidenceSha256 -or
    (Get-FileHash -LiteralPath $dangerInteractionPath -Algorithm SHA256).Hash -cne
        [string]$dangerEvidence.interactionEvidenceSha256) {
    throw "Danger-menu runtime or interaction evidence hash differs."
}
$dangerScreenshots = @(
    [ordered]@{
        name = "dangerMenuHover"
        path = Resolve-ExistingFile `
            $dangerAction.contextMenuScreenshotPath `
            "Danger-menu hover screenshot"
        sha256 = [string]$dangerAction.contextMenuScreenshotSha256
    },
    [ordered]@{
        name = "deleteDialog"
        path = Resolve-ExistingFile `
            $dangerAction.dialogScreenshotPath `
            "Delete dialog screenshot"
        sha256 = [string]$dangerAction.dialogScreenshotSha256
    },
    [ordered]@{
        name = "libraryFinal"
        path = Resolve-ExistingFile `
            $dangerEvidence.screenshotPath `
            "Final library screenshot"
        sha256 = [string]$dangerEvidence.screenshotSha256
    }
)
foreach ($screenshot in $dangerScreenshots) {
    $actualHash = (Get-FileHash -LiteralPath $screenshot.path -Algorithm SHA256).Hash
    if ($actualHash -cne $screenshot.sha256) {
        throw "Danger GUI screenshot hash differs: $($screenshot.name)"
    }
    $screenshot.lengthBytes = (Get-Item -LiteralPath $screenshot.path).Length
    $screenshot.declaredHashMatches = $true
}

$isolatedMcPath = Resolve-ExistingFile `
    (Join-Path $authorityFullPath `
        "danger-gui-r5\session\workspace\Danger Hover\1781536331.mc") `
    "Isolated real MC"
$isolatedMcHash =
    (Get-FileHash -LiteralPath $isolatedMcPath -Algorithm SHA256).Hash
if ($isolatedMcHash -cne
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E") {
    throw "Isolated real MC hash changed."
}

$installerPath = Resolve-ExistingFile `
    (Join-Path $projectRoot "release\LumaChartStudio-Setup.exe") `
    "Frozen WPF installer"
$installerHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
if ($installerHash -cne
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
    throw "Frozen WPF installer hash changed."
}

$predecessorControlThemePath = Resolve-ExistingFile `
    (Join-Path $projectRoot `
        "artifacts\windows-avalonia-control-theme-slice-20260726-r2\verification-evidence.json") `
    "Control-theme r2 predecessor"
if ((Get-FileHash -LiteralPath $predecessorControlThemePath -Algorithm SHA256).Hash -cne
    "3BB741ED640FA8419F962EEABD39C36EE151390E6D067F96CF1D501A4558C4C7") {
    throw "Control-theme r2 predecessor hash changed."
}
$predecessorTitleBarPath = Resolve-ExistingFile `
    (Join-Path $projectRoot `
        "artifacts\windows-avalonia-titlebar-slice-20260727-r3\verification-evidence.json") `
    "Title-bar r3 predecessor"
if ((Get-FileHash -LiteralPath $predecessorTitleBarPath -Algorithm SHA256).Hash -cne
    "CACEB90D30399D8636D54C7DB70E6DC2DEC3831D64A277B71992D2F8E223FFE7") {
    throw "Title-bar r3 predecessor hash changed."
}

$changedPaths = @(
    "LumaChart.Avalonia\Infrastructure\WindowsWpf110ControlTheme.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia.Specs\WindowsControlThemeSpecs.cs",
    "tools\Capture-WindowsAvaloniaGui.ps1",
    "tools\Capture-WindowsAvaloniaInspectorParityGui.ps1",
    "tools\New-WindowsAvaloniaControlThemeR3SliceEvidence.ps1"
)
$changedFiles = @(
    foreach ($relativePath in $changedPaths) {
        Get-FileRecord (Join-Path $projectRoot $relativePath)
    }
)

$strictBuilds = @(
    foreach ($property in $buildLogs.GetEnumerator()) {
        [ordered]@{
            name = $property.Key
            configuration = "Release"
            ordinaryDotNet = $true
            warnings = 0
            errors = 0
            log = Get-FileRecord $property.Value
        }
    }
)

$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.control-theme-r3-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = "Windows Avalonia WPF 1.1.0 global TabItem and danger MenuItem only"
    authority = $authorityFullPath
    predecessor = [ordered]@{
        controlThemeR2 = Get-FileRecord $predecessorControlThemePath
        titleBarR3 = Get-FileRecord $predecessorTitleBarPath
    }
    strictBuilds = $strictBuilds
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            passed = 414
            total = 414
            failed = 0
            tabItem = $tabSpec[0]
            dangerMenu = $dangerSpec[0]
            evidence = Get-FileRecord $avaloniaSpecsPath
            log = Get-FileRecord `
                (Join-Path $authorityFullPath "specs\avalonia-specs.log")
        }
        mainSpecs = [ordered]@{
            passed = 79
            total = 79
            failed = 0
            log = Get-FileRecord $mainSpecsPath
        }
    }
    gui = [ordered]@{
        inspector = [ordered]@{
            evidence = Get-FileRecord $inspectorEvidencePath
            screenshots = $inspectorScreenshots
            physicalTabHover = $true
            hoverHashDiffersFromBaseline = $true
            singleRowWpfOrder = $true
        }
        dangerMenu = [ordered]@{
            evidence = Get-FileRecord $dangerEvidencePath
            runtime = Get-FileRecord $dangerRuntimePath
            interaction = Get-FileRecord $dangerInteractionPath
            screenshots = $dangerScreenshots
            physicalRightClick = $true
            physicalPointerHover = $true
            automationFallbackUsed = $false
            deleteBlockedBecauseDocumentOpen = $true
            targetPreserved = $true
        }
    }
    sourceIntegrity = [ordered]@{
        realMc = Get-FileRecord $isolatedMcPath
        frozenInstaller = Get-FileRecord $installerPath
    }
    changedFiles = $changedFiles
    buildProtection = [ordered]@{
        ordinaryDotNetReleaseOnly = $true
        ollvmUsed = $false
        obfuscationUsed = $false
        packingUsed = $false
        codeVirtualizationUsed = $false
        aotUsed = $false
        nativeAotUsed = $false
    }
    exclusions = [ordered]@{
        androidTouched = $false
        iosTouched = $false
        macosTouched = $false
        linuxTouched = $false
        webAssemblyTouched = $false
        productionServerDeployed = $false
        frozenInstallerOverwritten = $false
    }
    completion = [ordered]@{
        windowsAvaloniaOneToOneComplete = $false
        windowsAvaloniaCanReplaceWpf = $false
        userReplacementApprovalReceived = $false
        otherPlatformsAuthorized = $false
    }
}

$outputPath = Join-Path $authorityFullPath "verification-evidence.json"
$evidence | ConvertTo-Json -Depth 14 |
    Set-Content -LiteralPath $outputPath -Encoding utf8NoBOM
Get-FileRecord $outputPath | ConvertTo-Json -Depth 4
