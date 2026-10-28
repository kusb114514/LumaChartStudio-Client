param(
    [string]$FormalRoot = (
        Join-Path $PSScriptRoot `
            "..\artifacts\windows-avalonia-metadata-copy-labels-slice-20260728-r1")
)

$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$formalRoot = [IO.Path]::GetFullPath($FormalRoot)
$projectBoundary = $projectRoot.TrimEnd('\') + '\'
if (-not $formalRoot.StartsWith(
        $projectBoundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Formal root must stay below the project root: $formalRoot"
}
if (-not (Test-Path -LiteralPath $formalRoot -PathType Container)) {
    throw "Formal root not found: $formalRoot"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Read-Json([string]$Path) {
    Assert (Test-Path -LiteralPath $Path -PathType Leaf) "Missing JSON: $Path"
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 |
        ConvertFrom-Json -Depth 100
}

function File-Evidence([string]$Path) {
    Assert (Test-Path -LiteralPath $Path -PathType Leaf) "Missing file: $Path"
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        bytes = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
}

function Assert-StrictBuild([string]$Path) {
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $zeroWarnings =
        $text.Contains("0 个警告", [StringComparison]::Ordinal) -or
        $text.Contains("0 Warning(s)", [StringComparison]::OrdinalIgnoreCase)
    $zeroErrors =
        $text.Contains("0 个错误", [StringComparison]::Ordinal) -or
        $text.Contains("0 Error(s)", [StringComparison]::OrdinalIgnoreCase)
    Assert (
        $zeroWarnings -and
        $zeroErrors -and
        $text.Contains("已成功生成", [StringComparison]::Ordinal)) (
        "Strict build is not 0 warning / 0 error: $Path")
    foreach ($forbidden in @(
            "OLLVM",
            "Obfuscator",
            "NativeAOT",
            "PublishAot=true",
            "code virtualization")) {
        Assert (
            -not $text.Contains(
                $forbidden,
                [StringComparison]::OrdinalIgnoreCase)) (
            "Strict build contains forbidden text '$forbidden': $Path")
    }
    return File-Evidence $Path
}

$guiPath = Join-Path $formalRoot "gui\inspector-option-labels\evidence.json"
$specsPath = Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$specsLogPath = Join-Path $formalRoot "tests\avalonia-specs.log"
$mainSpecsPath = Join-Path $formalRoot "tests\main-specs.log"
$gui = Read-Json $guiPath
$specs = Read-Json $specsPath

Assert (
    $gui.schema -ceq
        "lumachart.windows.avalonia.inspector-option-labels-gui.v3" -and
    $gui.status -ceq "passed" -and
    $gui.platform -ceq "Windows Avalonia" -and
    $gui.buildMode -ceq "ordinary .NET Release") (
    "Inspector option-label GUI evidence boundary drifted.")

$expectedValues = @("None", "Scroll", "Jump", "HS", "Sign", "Custom")
$expectedLabels = @("无", "Scroll", "Jump", "HS", "Sign", "自定义字段")
Assert (
    @($gui.wpfReference.timingEffect.values).Count -eq 6 -and
    -not (Compare-Object `
        -ReferenceObject $expectedValues `
        -DifferenceObject @($gui.wpfReference.timingEffect.values) `
        -SyncWindow 0) -and
    @($gui.wpfReference.timingEffect.labels).Count -eq 6 -and
    -not (Compare-Object `
        -ReferenceObject $expectedLabels `
        -DifferenceObject @($gui.wpfReference.timingEffect.labels) `
        -SyncWindow 0)) (
    "WPF Timing Effect value/label contract drifted.")
Assert (
    [string]$gui.gui.timingEffect.initialSelectedLabel -ceq "无" -and
    [string]$gui.gui.timingEffect.customSelectedLabel -ceq "自定义字段" -and
    [bool]$gui.gui.timingEffect.customFieldVisible -and
    [string]$gui.gui.timingEffect.restoredSelectedLabel -ceq "无" -and
    [bool]$gui.gui.timingEffect.customFieldHiddenAfterRestore) (
    "Timing Effect selected-label or custom-field behavior drifted.")
Assert (
    @($gui.gui.timingEffect.expandedLabels).Count -eq 6 -and
    -not (Compare-Object `
        -ReferenceObject $expectedLabels `
        -DifferenceObject @($gui.gui.timingEffect.expandedLabels) `
        -SyncWindow 0)) (
    "Expanded Timing Effect labels drifted.")

$expectedKeyCountValues = @(4, 5, 6, 7, 8, 9, 10)
$expectedKeyCountLabels = @(
    "4 Keys",
    "5 Keys",
    "6 Keys",
    "7 Keys",
    "8 Keys",
    "9 Keys",
    "10 Keys")
Assert (
    [string]$gui.wpfReference.metadataKeyCount.fieldLabel -ceq "轨道数" -and
    @($gui.wpfReference.metadataKeyCount.values).Count -eq 7 -and
    -not (Compare-Object `
        -ReferenceObject $expectedKeyCountValues `
        -DifferenceObject @($gui.wpfReference.metadataKeyCount.values) `
        -SyncWindow 0) -and
    @($gui.wpfReference.metadataKeyCount.labels).Count -eq 7 -and
    -not (Compare-Object `
        -ReferenceObject $expectedKeyCountLabels `
        -DifferenceObject @($gui.wpfReference.metadataKeyCount.labels) `
        -SyncWindow 0)) (
    "WPF Metadata KeyCount value/label contract drifted.")
Assert (
    [string]$gui.gui.metadataKeyCount.fieldLabel -ceq "轨道数" -and
    [string]$gui.gui.metadataKeyCount.initialSelectedLabel -ceq "4 Keys" -and
    [string]$gui.gui.metadataKeyCount.restoredSelectedLabel -ceq "4 Keys" -and
    -not [bool]$gui.gui.metadataKeyCount.selectionChanged -and
    @($gui.gui.metadataKeyCount.expandedLabels).Count -eq 7 -and
    -not (Compare-Object `
        -ReferenceObject $expectedKeyCountLabels `
        -DifferenceObject @($gui.gui.metadataKeyCount.expandedLabels) `
        -SyncWindow 0)) (
    "Metadata KeyCount selected or expanded labels drifted.")

Assert (
    [string]$gui.wpfReference.metadataCopy.title -ceq "谱面信息" -and
    [double]$gui.wpfReference.metadataCopy.titleFontSize -eq 25 -and
    [string]$gui.wpfReference.metadataCopy.subtitle -ceq
        "Malody Key / osu!mania 元数据" -and
    [string]$gui.wpfReference.metadataCopy.titleAsciiLabel -ceq
        "歌曲名（ASCII 英文字符）" -and
    [string]$gui.wpfReference.metadataCopy.artistAsciiLabel -ceq
        "艺术家（ASCII 英文字符）" -and
    [string]$gui.wpfReference.metadataCopy.keyCountLabel -ceq "轨道数" -and
    [string]$gui.wpfReference.metadataCopy.applyLabel -ceq "应用谱面信息" -and
    [double]$gui.wpfReference.metadataCopy.statValueFontSize -eq 20 -and
    @($gui.wpfReference.metadataCopy.statLabels).Count -eq 3 -and
    -not (Compare-Object `
        -ReferenceObject @("Notes", "Holds", "Timing") `
        -DifferenceObject @($gui.wpfReference.metadataCopy.statLabels) `
        -SyncWindow 0)) (
    "WPF Metadata visible-copy contract drifted.")
Assert (
    [string]$gui.gui.metadataCopy.title -ceq "谱面信息" -and
    [string]$gui.gui.metadataCopy.subtitle -ceq
        "Malody Key / osu!mania 元数据" -and
    [string]$gui.gui.metadataCopy.titleAsciiLabel -ceq
        "歌曲名（ASCII 英文字符）" -and
    [string]$gui.gui.metadataCopy.artistAsciiLabel -ceq
        "艺术家（ASCII 英文字符）" -and
    [string]$gui.gui.metadataCopy.keyCountLabel -ceq "轨道数" -and
    [string]$gui.gui.metadataCopy.applyLabel -ceq "应用谱面信息" -and
    [bool]$gui.gui.metadataCopy.applyVisibleAfterScroll -and
    [int]$gui.gui.metadataCopy.stats.notes -eq 2753 -and
    [int]$gui.gui.metadataCopy.stats.holds -eq 771 -and
    [int]$gui.gui.metadataCopy.stats.timing -eq 1 -and
    [string]$gui.gui.metadataCopy.stats.notesValueName -ceq "2753" -and
    [string]$gui.gui.metadataCopy.stats.holdsValueName -ceq "771" -and
    [string]$gui.gui.metadataCopy.stats.timingValueName -ceq "1" -and
    [string]$gui.gui.metadataCopy.stats.notesLabelName -ceq "Notes" -and
    [string]$gui.gui.metadataCopy.stats.holdsLabelName -ceq "Holds" -and
    [string]$gui.gui.metadataCopy.stats.timingLabelName -ceq "Timing" -and
    [bool]$gui.gui.metadataCopy.stats.allVisibleAfterScroll) (
    "Metadata visible copy or footer visibility drifted.")

$actions = @($gui.gui.actions)
Assert (
    [int]$gui.gui.actionCount -eq 10 -and
    $actions.Count -eq 10 -and
    @($actions | Where-Object {
        $_.input -ceq "UI Automation ExpandCollapsePattern.Expand"
    }).Count -eq 3 -and
    @($actions | Where-Object {
        $_.input -ceq "UI Automation ExpandCollapsePattern.Collapse"
    }).Count -eq 3 -and
    @($actions | Where-Object {
        $_.input -ceq "UI Automation SelectionItemPattern.Select"
    }).Count -eq 3 -and
    @($actions | Where-Object {
        $_.input -ceq "UI Automation ScrollItemPattern.ScrollIntoView"
    }).Count -eq 1) (
    "Inspector option-label GUI action accounting drifted.")
Assert (
    -not [bool]$gui.gui.persistentTopmostUsed -and
    -not [bool]$gui.gui.enterKeySent -and
    -not [bool]$gui.gui.inputInjectionUsed) (
    "Inspector option-label GUI input/topmost boundary drifted.")
Assert (
    [string]$gui.runtime.schema -ceq
        "lumachart.windows.avalonia.gui-evidence.v14" -and
    [int]$gui.runtime.chartNoteCount -eq 2753 -and
    [int]$gui.runtime.chartTimingCount -eq 1 -and
    [int]$gui.runtime.perNoteAvaloniaControls -eq 0) (
    "Real MC or single-surface runtime evidence drifted.")

$realMcSha256 =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$installerSha256 =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
Assert (
    [bool]$gui.immutable.sourceMc.unchanged -and
    [string]$gui.immutable.sourceMc.sha256Before -ceq $realMcSha256 -and
    [string]$gui.immutable.sourceMc.sha256After -ceq $realMcSha256 -and
    [bool]$gui.immutable.copiedMc.unchanged -and
    [string]$gui.immutable.copiedMc.sha256Before -ceq $realMcSha256 -and
    [string]$gui.immutable.copiedMc.sha256After -ceq $realMcSha256 -and
    [bool]$gui.immutable.installer.unchanged -and
    [string]$gui.immutable.installer.sha256Before -ceq $installerSha256 -and
    [string]$gui.immutable.installer.sha256After -ceq $installerSha256) (
    "Immutable MC or installer fingerprint drifted.")

$screenshots = @(
    $gui.screenshots.noneSelected,
    $gui.screenshots.optionsExpanded,
    $gui.screenshots.customSelected,
    $gui.screenshots.noneRestored,
    $gui.screenshots.keyCountSelected,
    $gui.screenshots.keyCountOptionsExpanded,
    $gui.screenshots.metadataFooter)
Assert ($screenshots.Count -eq 7) "Expected seven GUI screenshots."
foreach ($screenshot in $screenshots) {
    $actual = File-Evidence ([string]$screenshot.path)
    Assert (
        $actual.bytes -eq [long]$screenshot.bytes -and
        $actual.sha256 -ceq [string]$screenshot.sha256 -and
        [int]$screenshot.width -ge 1280 -and
        [int]$screenshot.height -ge 720 -and
        $actual.bytes -ge 100000) (
        "Inspector option-label screenshot drifted: $($actual.path)")
}

$checks = @($specs.checks)
$newCheck = @($checks | Where-Object {
    $_.name -ceq
        "timing-effect-display-labels-preserve-wpf-text-and-internal-values"
})
$keyCountCheck = @($checks | Where-Object {
    $_.name -ceq "metadata-key-count-display-labels-match-wpf-110"
})
$metadataCopyCheck = @($checks | Where-Object {
    $_.name -ceq "metadata-visible-copy-and-title-typography-match-wpf-110"
})
Assert (
    $specs.status -ceq "passed" -and
    $checks.Count -eq 508 -and
    @($checks | Where-Object passed).Count -eq 508 -and
    $newCheck.Count -eq 1 -and
    [bool]$newCheck[0].passed -and
    [string]$newCheck[0].detail -ceq
        "None→无 / Scroll→Scroll / Jump→Jump / HS→HS / Sign→Sign / Custom→自定义字段" -and
    $keyCountCheck.Count -eq 1 -and
    [bool]$keyCountCheck[0].passed -and
    [string]$keyCountCheck[0].detail -ceq
        "4→4 Keys / 5→5 Keys / 6→6 Keys / 7→7 Keys / 8→8 Keys / 9→9 Keys / 10→10 Keys" -and
    $metadataCopyCheck.Count -eq 1 -and
    [bool]$metadataCopyCheck[0].passed -and
    [string]$metadataCopyCheck[0].detail -ceq
        "谱面信息@25 / Malody Key / osu!mania 元数据 / 歌曲名（ASCII 英文字符） / 艺术家（ASCII 英文字符） / 轨道数 / 应用谱面信息 / Notes-Holds-Timing@20") (
    "Avalonia Specs inspector-label gates drifted.")
$specsLog = Get-Content -LiteralPath $specsLogPath -Raw -Encoding UTF8
$mainSpecs = Get-Content -LiteralPath $mainSpecsPath -Raw -Encoding UTF8
Assert (
    $specsLog.Contains("Avalonia slice verification: passed") -and
    $mainSpecs.Contains("79/79 specs passed.")) (
    "Specs run log drifted.")

$builds = [ordered]@{
    avalonia = Assert-StrictBuild (
        Join-Path $formalRoot "build\build-avalonia.log")
    avaloniaSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\build-avalonia_specs.log")
    mainSpecs = Assert-StrictBuild (
        Join-Path $formalRoot "build\build-main_specs.log")
    onlineGuiServer = Assert-StrictBuild (
        Join-Path $formalRoot "build\build-loopback_gui_server.log")
}

$sourceChecks = [ordered]@{
    wpfXaml = File-Evidence (
        Join-Path $projectRoot "LumaChart.App\MainWindow.xaml")
    inspectorPolicy = File-Evidence (
        Join-Path $projectRoot `
            "LumaChart.Avalonia\Infrastructure\WindowsInspectorParityPolicy.cs")
    avaloniaMainWindow = File-Evidence (
        Join-Path $projectRoot "LumaChart.Avalonia\MainWindow.cs")
    inspectorSpecs = File-Evidence (
        Join-Path $projectRoot `
            "LumaChart.Avalonia.Specs\WindowsInspectorParitySpecs.cs")
    focusedGuiTool = File-Evidence (
        Join-Path $projectRoot `
            "tools\Capture-WindowsAvaloniaTimingEffectLabelsGui.ps1")
    existingInspectorGuiTool = File-Evidence (
        Join-Path $projectRoot `
            "tools\Capture-WindowsAvaloniaInspectorParityGui.ps1")
}
$wpfXamlText = Get-Content -LiteralPath $sourceChecks.wpfXaml.path -Raw -Encoding UTF8
Assert (
    $wpfXamlText.Contains(
        'Content="无" Tag="None"',
        [StringComparison]::Ordinal) -and
    $wpfXamlText.Contains(
        'Content="自定义字段" Tag="Custom"',
        [StringComparison]::Ordinal) -and
    $wpfXamlText.Contains(
        '<TextBlock Text="轨道数" Style="{StaticResource FieldLabel}" />',
        [StringComparison]::Ordinal) -and
    $wpfXamlText.Contains(
        '<ComboBoxItem Content="4 Keys" Tag="4" />',
        [StringComparison]::Ordinal) -and
    $wpfXamlText.Contains(
        '<ComboBoxItem Content="10 Keys" Tag="10" />',
        [StringComparison]::Ordinal) -and
    $wpfXamlText.Contains(
        '<TextBlock Text="谱面信息" FontSize="25" FontWeight="SemiBold" />',
        [StringComparison]::Ordinal) -and
    $wpfXamlText.Contains(
        '<TextBlock Text="Malody Key / osu!mania 元数据"',
        [StringComparison]::Ordinal) -and
    $wpfXamlText.Contains(
        '<TextBlock Text="歌曲名（ASCII 英文字符）"',
        [StringComparison]::Ordinal) -and
    $wpfXamlText.Contains(
        '<TextBlock Text="艺术家（ASCII 英文字符）"',
        [StringComparison]::Ordinal) -and
    $wpfXamlText.Contains(
        'Content="应用谱面信息"',
        [StringComparison]::Ordinal)) (
    "WPF 1.1.0 inspector option-label source reference drifted.")

Assert (
    -not [bool]$gui.scope.productionServerDeployed -and
    -not [bool]$gui.scope.mobileProjectsTouched -and
    -not [bool]$gui.scope.protectionObfuscationVirtualizationOrAotUsed -and
    -not [bool]$gui.scope.releaseInstallerOverwritten -and
    -not [bool]$gui.scope.windowsAvaloniaCanReplaceWpf -and
    -not [bool]$gui.scope.userManualReplacementApprovalReceived) (
    "Inspector option-label scope boundary drifted.")

$outputPath = Join-Path $formalRoot "verification-evidence.json"
$evidence = [ordered]@{
    schema =
        "lumachart.windows.avalonia.metadata-copy-labels-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    scope = [ordered]@{
        platform = "Windows Avalonia only"
        buildMode = "ordinary .NET Release"
        productionServerDeployed = $false
        mobileProjectsTouched = $false
        protectionObfuscationVirtualizationOrAotUsed = $false
        releaseInstallerOverwritten = $false
        windowsAvaloniaCanReplaceWpf = $false
        userManualReplacementApprovalReceived = $false
    }
    results = [ordered]@{
        strictBuildWarnings = 0
        strictBuildErrors = 0
        avaloniaSpecsPassed = 508
        avaloniaSpecsTotal = 508
        mainSpecsPassed = 79
        mainSpecsTotal = 79
        dedicatedTimingEffectLabelSpecsPassed = 1
        dedicatedMetadataKeyCountLabelSpecsPassed = 1
        dedicatedMetadataCopySpecsPassed = 1
        guiActions = 10
        guiScreenshotsVisuallyInspected = 7
        realMcNoteCount = 2753
        realMcTimingCount = 1
        perNoteAvaloniaControls = 0
        internalValues = $expectedValues
        wpfDisplayLabels = $expectedLabels
        metadataKeyCountValues = $expectedKeyCountValues
        metadataKeyCountDisplayLabels = $expectedKeyCountLabels
        metadataTitleFontSizeDip = 25
        metadataSubtitle = "Malody Key / osu!mania 元数据"
        metadataApplyLabel = "应用谱面信息"
        metadataStatsNotes = 2753
        metadataStatsHolds = 771
        metadataStatsTiming = 1
        customFieldVisibilityPassed = $true
        realMcUnchanged = $true
        frozenInstallerUnchanged = $true
    }
    evidenceFiles = [ordered]@{
        gui = File-Evidence $guiPath
        avaloniaSpecs = File-Evidence $specsPath
        avaloniaSpecsRun = File-Evidence $specsLogPath
        mainSpecsRun = File-Evidence $mainSpecsPath
        builds = $builds
        screenshots = @($screenshots | ForEach-Object {
            File-Evidence ([string]$_.path)
        })
    }
    sourceChecks = $sourceChecks
    remainingDifferences = @(
        "This slice closes the WPF Metadata title typography, subtitle, ASCII field labels and apply-button copy; the complete UI matrix is not yet passed.",
        "Physical pointer/keyboard, all DPI/resolutions and same-machine full-application pixel A/B remain open.",
        "Installation, update, ClientSecurity, display Present performance and user replacement approval remain open."
    )
}
$evidence | ConvertTo-Json -Depth 30 |
    Set-Content -LiteralPath $outputPath -Encoding utf8NoBOM

$roundTrip = Read-Json $outputPath
Assert (
    $roundTrip.status -ceq "passed-migration-incomplete" -and
    [int]$roundTrip.results.avaloniaSpecsPassed -eq 508 -and
    [int]$roundTrip.results.mainSpecsPassed -eq 79 -and
    [int]$roundTrip.results.guiScreenshotsVisuallyInspected -eq 7 -and
    -not [bool]$roundTrip.scope.windowsAvaloniaCanReplaceWpf) (
    "Verification evidence round-trip drifted.")
Write-Output $outputPath
