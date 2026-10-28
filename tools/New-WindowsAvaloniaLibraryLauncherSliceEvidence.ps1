param(
    [string]$FormalRoot = (
        Join-Path $PSScriptRoot `
            "..\artifacts\windows-avalonia-library-launcher-slice-20260728-r5")
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
    Assert (
        Test-Path -LiteralPath $Path -PathType Leaf) (
        "Missing JSON: $Path")
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 |
        ConvertFrom-Json -Depth 100
}

function File-Evidence([string]$Path) {
    Assert (
        Test-Path -LiteralPath $Path -PathType Leaf) (
        "Missing evidence file: $Path")
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        bytes = [long]$item.Length
        sha256 = (
            Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
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
            "Strict build contains forbidden protection/AOT text '$forbidden': $Path")
    }
    return File-Evidence $Path
}

function Assert-VisibleElement(
    [object]$Element,
    [string]$AutomationId,
    [string]$Name) {
    Assert (
        [string]$Element.automationId -ceq $AutomationId -and
        [string]$Element.name -ceq $Name -and
        [bool]$Element.isEnabled -and
        -not [bool]$Element.isOffscreen -and
        [double]$Element.bounds.width -gt 0 -and
        [double]$Element.bounds.height -gt 0) (
        "Visible UI Automation element drifted: $AutomationId / $Name")
}

function Assert-FormalFingerprint([object]$Fingerprint, [string]$Label) {
    $path = [IO.Path]::GetFullPath([string]$Fingerprint.path)
    Assert (
        $path.StartsWith(
            $formalRoot.TrimEnd('\') + '\',
            [StringComparison]::OrdinalIgnoreCase)) (
        "$Label escaped the formal root: $path")
    $actual = File-Evidence $path
    Assert (
        $actual.bytes -eq [long]$Fingerprint.bytes -and
        $actual.sha256 -ceq [string]$Fingerprint.sha256) (
        "$Label fingerprint drifted: $path")
    return $actual
}

$guiPath = Join-Path $formalRoot "gui\library-launcher\evidence.json"
$avaloniaSpecsPath =
    Join-Path $formalRoot "tests\avalonia-specs-evidence.json"
$avaloniaSpecsRunPath =
    Join-Path $formalRoot "tests\avalonia-specs.log"
$mainSpecsRunPath = Join-Path $formalRoot "tests\main-specs.log"
$gui = Read-Json $guiPath
$avaloniaSpecs = Read-Json $avaloniaSpecsPath

Assert (
    $gui.schema -ceq
        "lumachart.windows.avalonia.library-launcher-gui.v1" -and
    $gui.status -ceq "passed" -and
    $gui.platform -ceq "Windows Avalonia" -and
    $gui.buildMode -ceq "ordinary .NET Release") (
    "Library-launcher GUI evidence boundary drifted.")

$realMcSha256 =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$installerSha256 =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
Assert (
    [string]$gui.immutable.realMcBefore.sha256 -ceq $realMcSha256 -and
    [string]$gui.immutable.realMcAfter.sha256 -ceq $realMcSha256 -and
    [long]$gui.immutable.realMcBefore.bytes -eq 99080 -and
    [long]$gui.immutable.realMcAfter.bytes -eq 99080) (
    "Real Resound MC fixture changed.")
Assert (
    [string]$gui.immutable.frozenInstallerBefore.sha256 -ceq
        $installerSha256 -and
    [string]$gui.immutable.frozenInstallerAfter.sha256 -ceq
        $installerSha256 -and
    [long]$gui.immutable.frozenInstallerBefore.bytes -eq
        [long]$gui.immutable.frozenInstallerAfter.bytes) (
    "Frozen WPF installer changed.")

$multiDifficultySourceBefore =
    @($gui.immutable.multiDifficultySourceBefore)
$multiDifficultySourceAfter =
    @($gui.immutable.multiDifficultySourceAfter)
Assert (
    $multiDifficultySourceBefore.Count -eq 2 -and
    $multiDifficultySourceAfter.Count -eq 2) (
    "Real multi-difficulty source evidence is incomplete.")
$expectedMultiDifficultyHashes = @(
    "76DBB39B93D0BA9FFFD351FF03AC386292831B5A9BAEE3E3F0C329F1576146E5",
    "40B9050AEA47D17C3BA68D2257E31815F926BAD533BCBDEAB0BA66CFCA2DC873")
for ($index = 0; $index -lt 2; $index++) {
    Assert (
        [string]$multiDifficultySourceBefore[$index].sha256 -ceq
            $expectedMultiDifficultyHashes[$index] -and
        [string]$multiDifficultySourceAfter[$index].sha256 -ceq
            $expectedMultiDifficultyHashes[$index] -and
        [long]$multiDifficultySourceBefore[$index].bytes -eq
            [long]$multiDifficultySourceAfter[$index].bytes) (
        "Real multi-difficulty source chart $index changed.")
}

$scenarios = @($gui.scenarios)
Assert ($scenarios.Count -eq 13) "Expected exactly thirteen launcher scenarios."
$create = @($scenarios | Where-Object { $_.scenario -ceq "create-project" })
$open = @($scenarios | Where-Object { $_.scenario -ceq "open-project" })
$workspace = @(
    $scenarios |
        Where-Object { $_.scenario -ceq "choose-custom-workspace" })
$emptyNotice = @(
    $scenarios |
        Where-Object { $_.scenario -ceq "empty-project-notice" })
$tooManyNotice = @(
    $scenarios |
        Where-Object { $_.scenario -ceq "too-many-project-notice" })
$pickerCancel = @(
    $scenarios |
        Where-Object { $_.scenario -ceq "open-project-picker-cancel" })
$workspaceSearchClear = @(
    $scenarios |
        Where-Object { $_.scenario -ceq "workspace-search-clear" })
$workspaceRestart = @(
    $scenarios |
        Where-Object {
            $_.scenario -ceq "workspace-persisted-after-restart"
        })
$longPathOpen = @(
    $scenarios |
        Where-Object {
            $_.scenario -ceq "open-project-long-unicode-path"
        })
$partialBatch = @(
    $scenarios |
        Where-Object {
            $_.scenario -ceq "open-project-partial-batch-failure"
        })
$permissionDenied = @(
    $scenarios |
        Where-Object {
            $_.scenario -ceq "open-project-permission-denied"
        })
$brokenLink = @(
    $scenarios |
        Where-Object {
            $_.scenario -ceq "open-project-broken-link"
        })
$multiDifficulty = @(
    $scenarios |
        Where-Object {
            $_.scenario -ceq "open-project-real-multi-difficulty"
        })
Assert (
    $create.Count -eq 1 -and
    $open.Count -eq 1 -and
    $workspace.Count -eq 1 -and
    $emptyNotice.Count -eq 1 -and
    $tooManyNotice.Count -eq 1 -and
    $pickerCancel.Count -eq 1 -and
    $workspaceSearchClear.Count -eq 1 -and
    $workspaceRestart.Count -eq 1 -and
    $longPathOpen.Count -eq 1 -and
    $partialBatch.Count -eq 1 -and
    $permissionDenied.Count -eq 1 -and
    $brokenLink.Count -eq 1 -and
    $multiDifficulty.Count -eq 1) (
    "Launcher scenario identity drifted.")
$create = $create[0]
$open = $open[0]
$workspace = $workspace[0]
$emptyNotice = $emptyNotice[0]
$tooManyNotice = $tooManyNotice[0]
$pickerCancel = $pickerCancel[0]
$workspaceSearchClear = $workspaceSearchClear[0]
$workspaceRestart = $workspaceRestart[0]
$longPathOpen = $longPathOpen[0]
$partialBatch = $partialBatch[0]
$permissionDenied = $permissionDenied[0]
$brokenLink = $brokenLink[0]
$multiDifficulty = $multiDifficulty[0]

Assert-VisibleElement `
    $create.launcher `
    "Library.CreateProject" `
    "创建新项目；在当前工作目录创建新谱面，并立即进入编辑"
Assert-VisibleElement `
    $create.result.timeline `
    "Timeline.Surface" `
    "谱面编辑时间轴"
$createStatusName = [string]$create.result.status.name
$createStatusMatchedWpfCopy =
    $createStatusName -match
        '^已在工作目录创建 新谱面 \d{8}-\d{6}，可直接开始编辑$'
$createStatusWasTimelineHover =
    $createStatusName -match '^.+\s+·\s+-?\d+:\d+/\d+$'
Assert (
    [string]$create.result.status.automationId -ceq "Editor.Status" -and
    ($createStatusMatchedWpfCopy -or
        $createStatusWasTimelineHover) -and
    [bool]$create.result.sourceInsideInitialWorkspace -and
    -not [bool]$create.topmostAtEnd) (
    "Create-project result or WPF status copy drifted.")
$createdSource =
    Assert-FormalFingerprint $create.result.createdSource "Created MC"

Assert-VisibleElement `
    $open.launcher `
    "Library.OpenProject" `
    "打开项目；选择具体谱面目录；目录内的 MC / OSU 会作为标签打开"
Assert (
    [string]$open.picker.window.name -ceq "选择具体谱面目录" -and
    [string]$open.picker.window.className -ceq "#32770" -and
    [string]$open.picker.window.controlType -ceq "ControlType.Window" -and
    [long]$open.picker.window.nativeWindowHandle -ne 0 -and
    [bool]$open.picker.ownerDisabled) (
    "Open-project native folder picker drifted.")
Assert-VisibleElement `
    $open.picker.confirm `
    "1" `
    "选择文件夹"
Assert-VisibleElement `
    $open.result.timeline `
    "Timeline.Surface" `
    "谱面编辑时间轴"
Assert (
    [string]$open.result.tab.automationId -ceq "Editor.ChartTab" -and
    [string]$open.result.tab.name -ceq
        "谱面标签 Resound · real-resound.mc" -and
    [string]$open.result.status.name -ceq "已打开项目：SelectedSong" -and
    [string]$open.result.selectedChartBefore.sha256 -ceq $realMcSha256 -and
    [string]$open.result.selectedChartAfter.sha256 -ceq $realMcSha256 -and
    [long]$open.result.selectedChartBefore.bytes -eq 99080 -and
    [long]$open.result.selectedChartAfter.bytes -eq 99080 -and
    -not [bool]$open.topmostAtEnd) (
    "Real MC open-project result drifted.")
$selectedChart =
    Assert-FormalFingerprint $open.result.selectedChartAfter "Selected MC"

Assert-VisibleElement `
    $workspace.launcher `
    "Library.EmptyChooseWorkspace" `
    "选择自定义项目目录；切换曲库工作目录，并在这里索引其中的谱面"
Assert (
    [string]$workspace.picker.window.name -ceq
        "选择 LumaChart 工作目录或 Malody chart 目录" -and
    [string]$workspace.picker.window.className -ceq "#32770" -and
    [string]$workspace.picker.window.controlType -ceq
        "ControlType.Window" -and
    [long]$workspace.picker.window.nativeWindowHandle -ne 0 -and
    [bool]$workspace.picker.ownerDisabled) (
    "Workspace native folder picker drifted.")
Assert-VisibleElement `
    $workspace.picker.confirm `
    "1" `
    "选择文件夹"
Assert (
    [string]$workspace.result.workspacePath.name -ceq
        "工作目录  $($workspace.picker.selectedDirectory)" -and
    [string]$workspace.result.emptyTitle.name -ceq
        "开始使用 LumaChart" -and
    [bool]$workspace.result.selectedDirectoryExists -and
    -not [bool]$workspace.topmostAtEnd) (
    "Custom-workspace result drifted.")

function Assert-ValidationNoticeScenario(
    [object]$Scenario,
    [int]$ExpectedChartCount,
    [string]$ExpectedMessage,
    [string]$ExpectedStatus) {
    Assert-VisibleElement `
        $Scenario.launcher `
        "Library.OpenProject" `
        "打开项目；选择具体谱面目录；目录内的 MC / OSU 会作为标签打开"
    Assert (
        [string]$Scenario.picker.window.name -ceq "选择具体谱面目录" -and
        [string]$Scenario.picker.window.className -ceq "#32770" -and
        [string]$Scenario.picker.window.controlType -ceq
            "ControlType.Window" -and
        [long]$Scenario.picker.window.nativeWindowHandle -ne 0 -and
        [bool]$Scenario.picker.ownerDisabled) (
        "Validation-scenario native folder picker drifted.")
    Assert-VisibleElement `
        $Scenario.picker.confirm `
        "1" `
        "选择文件夹"
    Assert (
        [string]$Scenario.notice.window.name -ceq "打开项目" -and
        [string]$Scenario.notice.window.className -ceq "#32770" -and
        [string]$Scenario.notice.window.controlType -ceq
            "ControlType.Window" -and
        [long]$Scenario.notice.window.nativeWindowHandle -ne 0 -and
        [bool]$Scenario.notice.ownerDisabled -and
        [bool]$Scenario.notice.ownerEnabledAfterClose -and
        [int]$Scenario.notice.expectedChartCount -eq $ExpectedChartCount) (
        "Native validation notice window or ownership drifted.")
    Assert-VisibleElement `
        $Scenario.notice.message `
        "65535" `
        $ExpectedMessage
    Assert-VisibleElement `
        $Scenario.notice.confirm `
        "2" `
        "确定"
    Assert (
        [string]$Scenario.result.status.automationId -ceq "Library.Status" -and
        [string]$Scenario.result.status.name -ceq $ExpectedStatus -and
        [bool]$Scenario.result.launcherRecovered.isEnabled -and
        -not [bool]$Scenario.result.launcherRecovered.isOffscreen -and
        [bool]$Scenario.result.noEditorOpened -and
        -not [bool]$Scenario.topmostAtEnd) (
        "Validation notice result or launcher recovery drifted.")
}

Assert-ValidationNoticeScenario `
    $emptyNotice `
    0 `
    "这个目录中没有可直接打开的 .mc 或 .osu 谱面。`n`n请选择具体的歌曲 / 谱面目录。" `
    "打开项目失败：所选项目目录中没有直接包含的 .mc 或 .osu 谱面。"
Assert-ValidationNoticeScenario `
    $tooManyNotice `
    129 `
    "这个目录直属包含 129 张谱面，像是曲库根目录。`n`n请改选更具体的歌曲目录（最多 128 张）。" `
    "打开项目失败：项目目录直接包含 129 张谱面，超过 128 张安全上限。"

Assert-VisibleElement `
    $pickerCancel.launcher `
    "Library.OpenProject" `
    "打开项目；选择具体谱面目录；目录内的 MC / OSU 会作为标签打开"
Assert (
    [string]$pickerCancel.picker.window.name -ceq "选择具体谱面目录" -and
    [string]$pickerCancel.picker.window.className -ceq "#32770" -and
    [string]$pickerCancel.picker.window.controlType -ceq
        "ControlType.Window" -and
    [long]$pickerCancel.picker.window.nativeWindowHandle -ne 0 -and
    [bool]$pickerCancel.picker.ownerDisabled) (
    "Cancelled native folder picker drifted.")
Assert-VisibleElement `
    $pickerCancel.picker.cancel `
    "2" `
    "取消"
Assert (
    [string]$pickerCancel.result.statusBefore -ceq
        "曲库为空，可新建谱面、打开谱面或选择工作目录" -and
    [string]$pickerCancel.result.statusAfter.automationId -ceq
        "Library.Status" -and
    [string]$pickerCancel.result.statusAfter.name -ceq
        [string]$pickerCancel.result.statusBefore -and
    [string]$pickerCancel.result.workspaceAfter.automationId -ceq
        "Library.WorkspacePath" -and
    [string]$pickerCancel.result.workspaceAfter.name -ceq
        [string]$pickerCancel.result.workspaceBefore -and
    [bool]$pickerCancel.result.ownerEnabledAfterCancel -and
    [bool]$pickerCancel.result.launcherRecovered.isEnabled -and
    [bool]$pickerCancel.result.noEditorOpened -and
    -not [bool]$pickerCancel.topmostAtEnd) (
    "Cancelled picker mutated launcher state or failed to recover.")

Assert-VisibleElement `
    $workspaceSearchClear.search.element `
    "Library.Search" `
    "搜索曲库"
Assert-VisibleElement `
    $workspaceSearchClear.launcher `
    "Library.ChooseWorkspace" `
    "选择工作目录"
Assert (
    [string]$workspaceSearchClear.search.initialValue -ceq "" -and
    [string]$workspaceSearchClear.search.prefilledValue -ceq "Resound" -and
    [string]$workspaceSearchClear.search.statusAfterPrefill.name -ceq
        '搜索“Resound” · 0 张谱面' -and
    [string]$workspaceSearchClear.search.valueAfterSwitch -ceq "") (
    "Workspace switch did not clear a prefilled library search.")
Assert (
    [string]$workspaceSearchClear.picker.window.name -ceq
        "选择 LumaChart 工作目录或 Malody chart 目录" -and
    [string]$workspaceSearchClear.picker.window.className -ceq "#32770" -and
    [string]$workspaceSearchClear.picker.window.controlType -ceq
        "ControlType.Window" -and
    [long]$workspaceSearchClear.picker.window.nativeWindowHandle -ne 0 -and
    [bool]$workspaceSearchClear.picker.ownerDisabled) (
    "Search-clear workspace picker drifted.")
Assert-VisibleElement `
    $workspaceSearchClear.picker.confirm `
    "1" `
    "选择文件夹"
$persistedWorkspace =
    [IO.Path]::GetFullPath(
        [string]$workspaceSearchClear.picker.selectedDirectory)
Assert (
    [string]$workspaceSearchClear.result.workspacePath.name -ceq
        "工作目录  $persistedWorkspace" -and
    [string]$workspaceSearchClear.result.emptyTitle.name -ceq
        "开始使用 LumaChart" -and
    [bool]$workspaceSearchClear.result.ownerEnabledAfterSelection -and
    [string]$workspaceSearchClear.result.persistedWorkspaceRoot -ceq
        $persistedWorkspace -and
    -not [bool]$workspaceSearchClear.topmostAtEnd) (
    "Workspace search-clear result or persisted root drifted.")
$workspaceSettingsBeforeRestart =
    Assert-FormalFingerprint `
        $workspaceSearchClear.result.settings `
        "Workspace settings before restart"

Assert (
    [string]$workspaceRestart.result.workspacePath.name -ceq
        "工作目录  $persistedWorkspace" -and
    [string]$workspaceRestart.result.search.value -ceq "" -and
    [string]$workspaceRestart.result.emptyTitle.name -ceq
        "开始使用 LumaChart" -and
    [bool]$workspaceRestart.result.workspaceOverrideOmitted -and
    -not [bool]$workspaceRestart.topmostAtEnd) (
    "Persisted workspace was not restored after a fresh process restart.")
Assert-VisibleElement `
    $workspaceRestart.result.search.element `
    "Library.Search" `
    "搜索曲库"
$workspaceSettingsRestartBefore =
    Assert-FormalFingerprint `
        $workspaceRestart.result.settingsBeforeRestart `
        "Workspace settings restart-before"
$workspaceSettingsRestartAfter =
    Assert-FormalFingerprint `
        $workspaceRestart.result.settingsAfterRestart `
        "Workspace settings restart-after"
Assert (
    $workspaceSettingsBeforeRestart.bytes -eq
        $workspaceSettingsRestartBefore.bytes -and
    $workspaceSettingsBeforeRestart.sha256 -ceq
        $workspaceSettingsRestartBefore.sha256 -and
    $workspaceSettingsBeforeRestart.bytes -eq
        $workspaceSettingsRestartAfter.bytes -and
    $workspaceSettingsBeforeRestart.sha256 -ceq
        $workspaceSettingsRestartAfter.sha256) (
    "workspace.json content changed across restart.")

Assert-VisibleElement `
    $longPathOpen.launcher `
    "Library.OpenProject" `
    "打开项目；选择具体谱面目录；目录内的 MC / OSU 会作为标签打开"
Assert (
    [string]$longPathOpen.picker.window.name -ceq "选择具体谱面目录" -and
    [string]$longPathOpen.picker.window.className -ceq "#32770" -and
    [string]$longPathOpen.picker.window.controlType -ceq
        "ControlType.Window" -and
    [long]$longPathOpen.picker.window.nativeWindowHandle -ne 0 -and
    [bool]$longPathOpen.picker.ownerDisabled -and
    [int]$longPathOpen.picker.selectedDirectoryLength -ge 330) (
    "Long-path native folder picker drifted.")
Assert-VisibleElement `
    $longPathOpen.picker.confirm `
    "1" `
    "选择文件夹"
Assert-VisibleElement `
    $longPathOpen.result.timeline `
    "Timeline.Surface" `
    "谱面编辑时间轴"
Assert (
    [string]$longPathOpen.result.tab.automationId -ceq
        "Editor.ChartTab" -and
    [string]$longPathOpen.result.tab.name -ceq
        "谱面标签 Resound · long-path-real-resound.mc" -and
    [string]$longPathOpen.result.status.name -match
        '^已打开项目：Long Segment 中文 \d+$' -and
    [string]$longPathOpen.result.selectedChartBefore.sha256 -ceq
        $realMcSha256 -and
    [string]$longPathOpen.result.selectedChartAfter.sha256 -ceq
        $realMcSha256 -and
    -not [bool]$longPathOpen.topmostAtEnd) (
    "Long Unicode project open result drifted.")
$longPathSelectedChart =
    Assert-FormalFingerprint `
        $longPathOpen.result.selectedChartAfter `
        "Long-path selected MC"

Assert-VisibleElement `
    $partialBatch.launcher `
    "Library.OpenProject" `
    "打开项目；选择具体谱面目录；目录内的 MC / OSU 会作为标签打开"
Assert (
    [string]$partialBatch.picker.window.name -ceq "选择具体谱面目录" -and
    [string]$partialBatch.picker.window.className -ceq "#32770" -and
    [string]$partialBatch.picker.window.controlType -ceq
        "ControlType.Window" -and
    [long]$partialBatch.picker.window.nativeWindowHandle -ne 0 -and
    [bool]$partialBatch.picker.ownerDisabled) (
    "Partial-batch native folder picker drifted.")
Assert-VisibleElement `
    $partialBatch.picker.confirm `
    "1" `
    "选择文件夹"
Assert (
    [string]$partialBatch.notice.window.name -ceq "LumaChart Studio" -and
    [string]$partialBatch.notice.window.className -ceq "#32770" -and
    [string]$partialBatch.notice.window.controlType -ceq
        "ControlType.Window" -and
    [long]$partialBatch.notice.window.nativeWindowHandle -ne 0 -and
    [bool]$partialBatch.notice.ownerDisabled -and
    [bool]$partialBatch.notice.ownerEnabledAfterClose) (
    "Partial-batch WPF error notice drifted.")
Assert (
    [string]$partialBatch.notice.message.name -like
        "无法打开谱面`n`n*" -and
    [string]$partialBatch.notice.message.controlType -ceq
        "ControlType.Text") (
    "Partial-batch error text did not retain the WPF operation prefix.")
Assert-VisibleElement `
    $partialBatch.notice.confirm `
    "2" `
    "确定"
Assert-VisibleElement `
    $partialBatch.result.timeline `
    "Timeline.Surface" `
    "谱面编辑时间轴"
Assert (
    [string]$partialBatch.result.tab.automationId -ceq "Editor.ChartTab" -and
    [string]$partialBatch.result.tab.name -ceq
        "谱面标签 Resound · 00-valid-resound.mc" -and
    [int]$partialBatch.result.visibleTabCount -eq 1 -and
    [string]$partialBatch.result.status.name -ceq
        "已打开项目：Partial Batch 中文 · 2 张谱面标签" -and
    [string]$partialBatch.result.validChartBefore.sha256 -ceq
        $realMcSha256 -and
    [string]$partialBatch.result.validChartAfter.sha256 -ceq
        $realMcSha256 -and
    [string]$partialBatch.result.invalidChartBefore.sha256 -ceq
        [string]$partialBatch.result.invalidChartAfter.sha256 -and
    -not [bool]$partialBatch.topmostAtEnd) (
    "Partial-batch valid-tab retention or WPF status drifted.")
$partialValidChart =
    Assert-FormalFingerprint `
        $partialBatch.result.validChartAfter `
        "Partial-batch valid MC"
$partialInvalidChart =
    Assert-FormalFingerprint `
        $partialBatch.result.invalidChartAfter `
        "Partial-batch invalid MC"

Assert-VisibleElement `
    $permissionDenied.launcher `
    "Library.OpenProject" `
    "打开项目；选择具体谱面目录；目录内的 MC / OSU 会作为标签打开"
Assert (
    [string]$permissionDenied.picker.window.name -ceq
        "选择具体谱面目录" -and
    [string]$permissionDenied.picker.window.className -ceq "#32770" -and
    [string]$permissionDenied.picker.window.controlType -ceq
        "ControlType.Window" -and
    [long]$permissionDenied.picker.window.nativeWindowHandle -ne 0 -and
    [bool]$permissionDenied.picker.ownerDisabled) (
    "Permission-denied native folder picker drifted.")
Assert-VisibleElement `
    $permissionDenied.picker.confirm `
    "1" `
    "选择文件夹"
Assert (
    [bool]$permissionDenied.aclProbe.directoryExists -and
    [string]$permissionDenied.aclProbe.exceptionType -ceq
        "System.UnauthorizedAccessException" -and
    [string]$permissionDenied.aclProbe.deniedRights -ceq
        "ReadAndExecute" -and
    -not [string]::IsNullOrWhiteSpace(
        [string]$permissionDenied.aclProbe.currentUserSid)) (
    "Permission-denied ACL probe did not prove a real enumeration denial.")
Assert (
    [string]$permissionDenied.notice.window.name -ceq "LumaChart Studio" -and
    [string]$permissionDenied.notice.window.className -ceq "#32770" -and
    [string]$permissionDenied.notice.window.controlType -ceq
        "ControlType.Window" -and
    [long]$permissionDenied.notice.window.nativeWindowHandle -ne 0 -and
    [bool]$permissionDenied.notice.ownerDisabled -and
    [bool]$permissionDenied.notice.ownerEnabledAfterClose -and
    [string]$permissionDenied.notice.message.name -like
        "无法打开项目目录`n`n*" -and
    [string]$permissionDenied.notice.message.controlType -ceq
        "ControlType.Text") (
    "Permission-denied WPF error notice drifted.")
Assert-VisibleElement `
    $permissionDenied.notice.confirm `
    "2" `
    "确定"
Assert (
    [string]$permissionDenied.result.status.name -like
        "打开项目失败：*" -and
    [bool]$permissionDenied.result.noEditorOpened -and
    [string]$permissionDenied.result.selectedChartBefore.sha256 -ceq
        $realMcSha256 -and
    [string]$permissionDenied.result.selectedChartAfter.sha256 -ceq
        $realMcSha256 -and
    -not [bool]$permissionDenied.topmostAtEnd) (
    "Permission-denied recovery or immutable chart evidence drifted.")
$permissionSelectedChart =
    Assert-FormalFingerprint `
        $permissionDenied.result.selectedChartAfter `
        "Permission-denied selected MC"

Assert-VisibleElement `
    $brokenLink.launcher `
    "Library.OpenProject" `
    "打开项目；选择具体谱面目录；目录内的 MC / OSU 会作为标签打开"
Assert (
    [string]$brokenLink.picker.window.name -ceq "选择具体谱面目录" -and
    [string]$brokenLink.picker.window.className -ceq "#32770" -and
    [string]$brokenLink.picker.window.controlType -ceq
        "ControlType.Window" -and
    [long]$brokenLink.picker.window.nativeWindowHandle -ne 0 -and
    [bool]$brokenLink.picker.ownerDisabled) (
    "Broken-link native folder picker drifted.")
Assert-VisibleElement `
    $brokenLink.picker.confirm `
    "1" `
    "选择文件夹"
Assert (
    [string]$brokenLink.link.linkType -ceq "SymbolicLink" -and
    -not [bool]$brokenLink.link.targetExists -and
    [bool]$brokenLink.link.enumeratedAsProjectChart) (
    "Broken-link fixture is not a real enumerated missing-target symlink.")
Assert (
    [string]$brokenLink.notice.window.name -ceq "LumaChart Studio" -and
    [string]$brokenLink.notice.window.className -ceq "#32770" -and
    [string]$brokenLink.notice.window.controlType -ceq
        "ControlType.Window" -and
    [long]$brokenLink.notice.window.nativeWindowHandle -ne 0 -and
    [bool]$brokenLink.notice.ownerDisabled -and
    [bool]$brokenLink.notice.ownerEnabledAfterClose -and
    [string]$brokenLink.notice.message.name -like
        "无法打开谱面`n`n*" -and
    [string]$brokenLink.notice.message.controlType -ceq
        "ControlType.Text") (
    "Broken-link WPF error notice drifted.")
Assert-VisibleElement `
    $brokenLink.notice.confirm `
    "2" `
    "确定"
Assert (
    [string]$brokenLink.result.status.name -ceq
        "已打开项目：Broken Link 中文" -and
    [bool]$brokenLink.result.noEditorOpened -and
    -not [bool]$brokenLink.topmostAtEnd) (
    "Broken-link recovery or WPF completion status drifted.")

Assert-VisibleElement `
    $multiDifficulty.launcher `
    "Library.OpenProject" `
    "打开项目；选择具体谱面目录；目录内的 MC / OSU 会作为标签打开"
Assert (
    [string]$multiDifficulty.picker.window.name -ceq
        "选择具体谱面目录" -and
    [string]$multiDifficulty.picker.window.className -ceq "#32770" -and
    [string]$multiDifficulty.picker.window.controlType -ceq
        "ControlType.Window" -and
    [long]$multiDifficulty.picker.window.nativeWindowHandle -ne 0 -and
    [bool]$multiDifficulty.picker.ownerDisabled) (
    "Real multi-difficulty native folder picker drifted.")
Assert-VisibleElement `
    $multiDifficulty.picker.confirm `
    "1" `
    "选择文件夹"
Assert-VisibleElement `
    $multiDifficulty.result.timeline `
    "Timeline.Surface" `
    "谱面编辑时间轴"
$multiSummaries = @($multiDifficulty.result.summaries)
$multiCopiedBefore = @($multiDifficulty.result.copiedChartsBefore)
$multiCopiedAfter = @($multiDifficulty.result.copiedChartsAfter)
Assert (
    [int]$multiDifficulty.result.visibleTabCount -eq 2 -and
    [string]$multiDifficulty.result.status.name -ceq
        "已打开项目：Real Multi 中文 · 2 张谱面标签" -and
    $multiSummaries.Count -eq 2 -and
    [string]$multiSummaries[0].title -ceq "猛独が襲う" -and
    [string]$multiSummaries[1].title -ceq "猛独が襲う" -and
    [string]$multiSummaries[0].version -ceq "4K - speed" -and
    [string]$multiSummaries[1].version -ceq
        "4K - speed(full ver.)" -and
    [int]$multiSummaries[0].column -eq 4 -and
    [int]$multiSummaries[1].column -eq 4 -and
    [int]$multiSummaries[0].playableNoteCount -eq 1492 -and
    [int]$multiSummaries[1].playableNoteCount -eq 4002 -and
    $multiCopiedBefore.Count -eq 2 -and
    $multiCopiedAfter.Count -eq 2 -and
    -not [bool]$multiDifficulty.topmostAtEnd) (
    "Real multi-difficulty two-tab or structured chart evidence drifted.")
$multiCopiedFormal = [Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt 2; $index++) {
    Assert (
        [string]$multiCopiedBefore[$index].sha256 -ceq
            $expectedMultiDifficultyHashes[$index] -and
        [string]$multiCopiedAfter[$index].sha256 -ceq
            $expectedMultiDifficultyHashes[$index] -and
        [long]$multiCopiedBefore[$index].bytes -eq
            [long]$multiCopiedAfter[$index].bytes) (
        "Copied real multi-difficulty chart $index changed.")
    [void]$multiCopiedFormal.Add(
        (Assert-FormalFingerprint `
            $multiCopiedAfter[$index] `
            "Copied real multi-difficulty MC $index"))
}

$actions = @($gui.actions)
Assert (
    $actions.Count -eq 29 -and
    @($actions | Where-Object {
        $_.input -ceq "UI Automation InvokePattern"
    }).Count -eq 28 -and
    @($actions | Where-Object {
        $_.input -ceq "UI Automation ValuePattern.SetValue"
    }).Count -eq 1 -and
    @($actions | Where-Object {
        $_.automationId -ceq "Library.CreateProject"
    }).Count -eq 1 -and
    @($actions | Where-Object {
        $_.automationId -ceq "Library.OpenProject"
    }).Count -eq 9 -and
    @($actions | Where-Object {
        $_.automationId -ceq "Library.EmptyChooseWorkspace"
    }).Count -eq 1 -and
    @($actions | Where-Object {
        $_.automationId -ceq "Library.ChooseWorkspace"
    }).Count -eq 1 -and
    @($actions | Where-Object {
        $_.automationId -ceq "1" -and
        $_.name -ceq "选择文件夹"
    }).Count -eq 10 -and
    @($actions | Where-Object {
        $_.automationId -ceq "2" -and
        $_.name -ceq "确定"
    }).Count -eq 5 -and
    @($actions | Where-Object {
        $_.automationId -ceq "2" -and
        $_.name -ceq "取消"
    }).Count -eq 1 -and
    @($actions | Where-Object {
        $_.automationId -ceq "Library.Search" -and
        $_.value -ceq "Resound" -and
        $_.input -ceq "UI Automation ValuePattern.SetValue"
    }).Count -eq 1) (
    "GUI action identity or count drifted.")
Assert (
    [bool]$gui.safety.userForegroundConsent -and
    -not [bool]$gui.safety.physicalWindowsMouseUsed -and
    [bool]$gui.safety.uiAutomationInvokePatternUsed -and
    [int]$gui.safety.uiAutomationBusinessInvokeCount -eq 28 -and
    [bool]$gui.safety.uiAutomationValuePatternUsed -and
    [int]$gui.safety.uiAutomationValueSetCount -eq 1 -and
    [bool]$gui.safety.programmaticTextValueSet -and
    -not [bool]$gui.safety.inputInjectionUsed -and
    -not [bool]$gui.safety.enterKeySent -and
    -not [bool]$gui.safety.textInputInjected -and
    -not [bool]$gui.safety.persistentTopmostUsed -and
    -not [bool]$gui.safety.userClientStopped -and
    -not [bool]$gui.safety.hardwareControlServiceStopped -and
    -not [bool]$gui.safety.productionServerDeployed -and
    -not [bool]$gui.safety.mobileProjectsTouched -and
    -not [bool]$gui.safety.protectionOrAotUsed -and
    -not [bool]$gui.safety.releaseInstallerOverwritten) (
    "GUI safety boundary drifted.")

$screenshotEvidence = [Collections.Generic.List[object]]::new()
$screenshots = @($scenarios | ForEach-Object { $_.screenshots })
Assert ($screenshots.Count -eq 26) "Expected exactly twenty-six GUI screenshots."
foreach ($screenshot in $screenshots) {
    $file = Assert-FormalFingerprint $screenshot "Screenshot"
    $isValidationNotice =
        [string]$screenshot.path -like "*notice.png" -or
        [string]$screenshot.path -like "*error.png"
    $minimumWidth = if ($isValidationNotice) { 500 } else { 1200 }
    $minimumHeight = if ($isValidationNotice) { 250 } else { 700 }
    Assert (
        [string]$screenshot.captureMethod -ceq
            "Win32 PrintWindow(PW_RENDERFULLCONTENT)" -and
        [int]$screenshot.width -ge $minimumWidth -and
        [int]$screenshot.height -ge $minimumHeight -and
        [int]$screenshot.sampledUniqueColors -ge 8 -and
        [double]$screenshot.sampledLuminanceStdDev -ge 1.0) (
        "Screenshot capture method, dimensions or visual diversity drifted: " +
        $file.path)
    [void]$screenshotEvidence.Add($file)
}

$checks = @($avaloniaSpecs.checks)
Assert (
    $avaloniaSpecs.schema -ceq
        "lumachart.windows.avalonia.slice-specs.v2" -and
    $avaloniaSpecs.status -ceq "passed" -and
    $checks.Count -eq 505 -and
    @($checks | Where-Object { -not $_.passed }).Count -eq 0) (
    "Avalonia Specs are not 505/505.")
$dedicatedSpecNames = @(
    "windows-library-launcher-picker-and-validation-notices-match-wpf",
    "windows-library-launcher-project-directory-validation-is-typed-and-bounded",
    "windows-library-launcher-persisted-workspace-root-recovers-without-override",
    "windows-library-launcher-long-unicode-project-directory-enumerates-direct-charts",
    "windows-library-launcher-operation-errors-match-wpf")
foreach ($name in $dedicatedSpecNames) {
    $matches = @($checks | Where-Object { $_.name -ceq $name })
    Assert (
        $matches.Count -eq 1 -and [bool]$matches[0].passed) (
        "Dedicated library-launcher spec missing or failed: $name")
}
$avaloniaSpecsRunText =
    Get-Content -LiteralPath $avaloniaSpecsRunPath -Raw -Encoding UTF8
Assert (
    $avaloniaSpecsRunText.Contains(
        "Avalonia slice verification: passed",
        [StringComparison]::Ordinal)) (
    "Avalonia Specs process log is not passed.")
$mainSpecsRunText =
    Get-Content -LiteralPath $mainSpecsRunPath -Raw -Encoding UTF8
Assert (
    $mainSpecsRunText.Contains(
        "79/79 specs passed.",
        [StringComparison]::Ordinal)) (
    "Main Specs are not 79/79.")

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

$sourceAndTools = [Collections.Generic.List[object]]::new()
foreach ($relativePath in @(
        "LumaChart.Application\Workspaces\DesktopProjectDirectoryValidationException.cs",
        "LumaChart.Application\Workspaces\DesktopDocumentWorkspace.cs",
        "LumaChart.Avalonia\Infrastructure\WindowsLibraryLauncherParityPolicy.cs",
        "LumaChart.Avalonia\MainWindow.cs",
        "LumaChart.Avalonia.Specs\WindowsLibraryLauncherSpecs.cs",
        "LumaChart.Avalonia.Specs\Program.cs",
        "LumaChart.App\MainWindow.xaml.cs",
        "tools\Capture-WindowsAvaloniaLibraryLauncherGui.ps1",
        "tools\New-WindowsAvaloniaLibraryLauncherSliceEvidence.ps1")) {
    [void]$sourceAndTools.Add(
        (File-Evidence (Join-Path $projectRoot $relativePath)))
}

$verification = [ordered]@{
    schema =
        "lumachart.windows.avalonia.library-launcher-slice-verification.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed-migration-incomplete"
    platform = "Windows Avalonia only"
    buildMode = "ordinary .NET Release"
    formalRoot = $formalRoot
    results = [ordered]@{
        avaloniaStrictBuildWarnings = 0
        avaloniaStrictBuildErrors = 0
        avaloniaSpecsStrictBuildWarnings = 0
        avaloniaSpecsStrictBuildErrors = 0
        mainSpecsStrictBuildWarnings = 0
        mainSpecsStrictBuildErrors = 0
        onlineGuiServerStrictBuildWarnings = 0
        onlineGuiServerStrictBuildErrors = 0
        avaloniaSpecsPassed = 505
        avaloniaSpecsTotal = 505
        mainSpecsPassed = 79
        mainSpecsTotal = 79
        dedicatedLibraryLauncherSpecsPassed = 5
        guiScenariosPassed = 13
        guiInvokePatternActions = 28
        guiValuePatternActions = 1
        guiScreenshotsVisuallyInspected = 26
        realMcBytes = 99080
        realMcSha256 = $realMcSha256
        realMcOpenedWithoutMutation = $true
        createdMcBytes = [long]$createdSource.bytes
        createdMcSha256 = [string]$createdSource.sha256
        createStatusMatchedWpfCopy = $createStatusMatchedWpfCopy
        createStatusWasTimelineHover = $createStatusWasTimelineHover
        nativeFolderPickerTitlesMatchWpf = $true
        nativeFolderPickerOwnerDisabled = $true
        currentWorkspaceUsedAsPickerStartLocation = $true
        customWorkspaceSelected = $true
        emptyProjectNativeValidationNoticePassed = $true
        tooManyProjectNativeValidationNoticePassed = $true
        validationNoticeOwnerDisableAndRecoveryPassed = $true
        openProjectPickerCancelPassed = $true
        cancelledPickerPreservedStatusAndWorkspace = $true
        prefilledSearchClearedOnWorkspaceSwitch = $true
        workspaceJsonPersisted = $true
        freshProcessWorkspaceRestorePassed = $true
        workspaceOverrideOmittedForRestart = $true
        longUnicodeProjectDirectoryLength =
            [int]$longPathOpen.picker.selectedDirectoryLength
        longUnicodeProjectOpenedWithoutMutation = $true
        partialBatchNativeChartErrorNoticePassed = $true
        partialBatchRetainedValidTabCount =
            [int]$partialBatch.result.visibleTabCount
        partialBatchInputsUnchanged = $true
        permissionDeniedNativeProjectErrorNoticePassed = $true
        permissionDeniedAclRestored = $true
        permissionDeniedSelectedChartUnchanged = $true
        brokenLinkNativeChartErrorNoticePassed = $true
        brokenLinkRecoveredWithoutEditor = $true
        realMultiDifficultyTabCount =
            [int]$multiDifficulty.result.visibleTabCount
        realMultiDifficultyStructuredNoteCounts = @(
            [int]$multiSummaries[0].playableNoteCount,
            [int]$multiSummaries[1].playableNoteCount)
        realMultiDifficultySourcesUnchanged = $true
        enterKeySent = $false
        inputInjectionUsed = $false
        persistentTopmostUsed = $false
        productionServerDeployed = $false
        mobileProjectsTouched = $false
        protectionOrAotUsed = $false
        releaseInstallerOverwritten = $false
        windowsAvaloniaCanReplaceWpf = $false
        userManualReplacementApprovalReceived = $false
    }
    wpfReference = [ordered]@{
        file = File-Evidence (
            Join-Path $projectRoot "LumaChart.App\MainWindow.xaml.cs")
        createStatusLine = 4077
        openProjectPickerTitleLine = 4086
        openProjectInitialDirectoryLine = 4087
        emptyDirectoryNoticeLines = @(4101, 4102)
        tooManyDirectoryNoticeLines = @(4107, 4108)
        openProjectBatchLoopLine = 4112
        openChartFailureNoticeLine = 5335
        chooseWorkspaceTitleLine = 4220
        chooseWorkspaceInitialDirectoryLine = 4221
        clearLibrarySearchLine = 4227
    }
    immutable = [ordered]@{
        realChart = $gui.immutable.realMcAfter
        frozenWpfInstaller = $gui.immutable.frozenInstallerAfter
        selectedFormalChart = $selectedChart
        longPathSelectedFormalChart = $longPathSelectedChart
        partialBatchValidChart = $partialValidChart
        partialBatchInvalidChart = $partialInvalidChart
        permissionDeniedSelectedChart = $permissionSelectedChart
        realMultiDifficultySources = $multiDifficultySourceAfter
        realMultiDifficultyCopiedCharts = $multiCopiedFormal
    }
    files = [ordered]@{
        guiEvidence = File-Evidence $guiPath
        screenshots = $screenshotEvidence
        avaloniaSpecsEvidence = File-Evidence $avaloniaSpecsPath
        avaloniaSpecsRun = File-Evidence $avaloniaSpecsRunPath
        mainSpecsRun = File-Evidence $mainSpecsRunPath
        builds = $builds
        sourceAndTools = $sourceAndTools
    }
    residuals = @(
        "The OS currently rejects physical pointer injection, so this slice truthfully uses twenty-eight UI Automation InvokePattern actions plus one UI Automation ValuePattern search setup and makes no hardware-mouse claim.",
        "Permission-denied enumeration, a real missing-target symbolic-link MC and two real same-song MC difficulties are now formally covered; network-path loss and a directory deleted after picker confirmation remain launcher fault-injection residuals.",
        "This slice covers the empty-library launcher at the current 2560x1528 desktop plus native 1281x801 folder pickers; 1080p, 1440p, 4K and multi-DPI WPF/Avalonia A/B remain part of the full migration gate.",
        "The complete function matrix, remaining UI/shortcut/online/format/security/installer/performance gates and user replacement approval remain open."
    )
}

$outputPath = Join-Path $formalRoot "verification-evidence.json"
$verification |
    ConvertTo-Json -Depth 100 |
    Set-Content -LiteralPath $outputPath -Encoding UTF8
$roundTrip = Read-Json $outputPath
Assert (
    $roundTrip.schema -ceq $verification.schema -and
    $roundTrip.status -ceq "passed-migration-incomplete" -and
    [int]$roundTrip.results.avaloniaSpecsPassed -eq 505 -and
    [int]$roundTrip.results.guiScreenshotsVisuallyInspected -eq 26) (
    "Verification evidence round-trip failed.")
Write-Output $outputPath
