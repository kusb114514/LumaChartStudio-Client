param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$Mp3FixturePath = "D:\osu!\Songs\1005389 Minori Chihara - Michishirube\audio.mp3",
    [string]$VariableTempoAudioPath = "D:\osu!\Songs\_song_38474\0\1770113980.ogg",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(60, 300)][int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia audio/tempo GUI capture requires PowerShell Core on Windows."
}

function Resolve-ExistingFile([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "$Label not found: $full" }
    return $full
}

function Wait-Condition {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Condition,
        [Parameter(Mandatory = $true)][string]$Description,
        [int]$Seconds = $TimeoutSeconds
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try { if (& $Condition) { return } } catch { }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartAudioTempoGuiNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr window, IntPtr deviceContext, uint flags);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr window, int command);
}
'@

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 300000)][int]$TimeoutMilliseconds = 10000
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children, $processCondition)
            foreach ($root in $roots) {
                if ([string]$root.Current.AutomationId -ceq $AutomationId) { return $root }
                $candidate = $root.FindFirst([Windows.Automation.TreeScope]::Descendants, $idCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Find-ElementByName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [ValidateRange(100, 300000)][int]$TimeoutMilliseconds = 10000
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty, $ProcessId)
    $nameCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty, $Name)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children, $processCondition)
            foreach ($root in $roots) {
                if ([string]$root.Current.Name -ceq $Name) { return $root }
                $candidate = $root.FindFirst([Windows.Automation.TreeScope]::Descendants, $nameCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation name '$Name' for process $ProcessId."
}

function Set-ElementValue($Element, [string]$Value) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose ValuePattern."
    }
    ([Windows.Automation.ValuePattern]$pattern).SetValue($Value)
}

function Get-ElementValue($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose ValuePattern."
    }
    return ([Windows.Automation.ValuePattern]$pattern).Current.Value
}

function Invoke-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Select-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose SelectionItemPattern."
    }
    ([Windows.Automation.SelectionItemPattern]$pattern).Select()
}

function Wait-ElementName([int]$ProcessId, [string]$AutomationId, [string]$Like, [int]$Seconds = 60) {
    $script:audioTempoWaitElement = $null
    Wait-Condition -Description "'$AutomationId' name '$Like'" -Seconds $Seconds -Condition {
        $candidate = Find-ElementById -ProcessId $ProcessId -AutomationId $AutomationId -TimeoutMilliseconds 1000
        if ([string]$candidate.Current.Name -like $Like) {
            $script:audioTempoWaitElement = $candidate
            return $true
        }
        return $false
    }
    $result = $script:audioTempoWaitElement
    $script:audioTempoWaitElement = $null
    return $result
}

function Wait-MainWindowHandle([Diagnostics.Process]$Process) {
    Wait-Condition -Description "main window for process $($Process.Id)" -Condition {
        $Process.Refresh()
        -not $Process.HasExited -and $Process.MainWindowHandle -ne [IntPtr]::Zero
    }
    return $Process.MainWindowHandle
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartAudioTempoGuiNative+RECT]::new()
    if (-not [LumaChartAudioTempoGuiNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 300 -or $height -lt 180) { throw "Window has invalid bounds: ${width}x${height}." }
    $bitmap = [Drawing.Bitmap]::new($width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $dc = $graphics.GetHdc()
            try {
                if (-not [LumaChartAudioTempoGuiNative]::PrintWindow($Handle, $dc, 2)) {
                    throw "PrintWindow failed for $Handle."
                }
            }
            finally { $graphics.ReleaseHdc($dc) }
        }
        finally { $graphics.Dispose() }
        $colors = [Collections.Generic.HashSet[int]]::new()
        for ($y = 0; $y -lt 16; $y++) {
            for ($x = 0; $x -lt 16; $x++) {
                $pixel = $bitmap.GetPixel(
                    [Math]::Min($width - 1, [int](($x + .5) * $width / 16)),
                    [Math]::Min($height - 1, [int](($y + .5) * $height / 16)))
                [void]$colors.Add($pixel.ToArgb())
            }
        }
        if ($colors.Count -lt 6) { throw "Screenshot is near-uniform: $($colors.Count) sampled colors." }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{ width = $width; height = $height; sampledUniqueColors = $colors.Count }
    }
    finally { $bitmap.Dispose() }
}

function Start-AudioTempoClient([string]$Profile, [string]$ChartPath, [string]$ClientRoot) {
    $localData = Join-Path $ClientRoot "local-data"
    $editing = Join-Path $ClientRoot "editing"
    $workspace = Join-Path $ClientRoot "workspace"
    foreach ($directory in @($localData, $editing, $workspace)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $applicationFullPath
    $start.UseShellExecute = $false
    $start.WorkingDirectory = Split-Path -Parent $applicationFullPath
    $start.ArgumentList.Add("--evidence-chart")
    $start.ArgumentList.Add($ChartPath)
    $start.Environment["LUMACHART_PROFILE"] = $Profile
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localData
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
    $start.Environment["DOTNET_CLI_HOME"] = $dotnetHome
    $start.Environment["NUGET_PACKAGES"] = $nugetPackages
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
    $start.Environment["TEMP"] = $projectTemp
    $start.Environment["TMP"] = $projectTemp
    $process = [Diagnostics.Process]::Start($start)
    if (-not $process) { throw "Unable to start Windows Avalonia audio/tempo client." }
    return $process
}

function Stop-TrackedClient([Diagnostics.Process]$Process) {
    if (-not $Process -or $Process.HasExited) { return }
    [void]$Process.CloseMainWindow()
    if (-not $Process.WaitForExit(10000)) {
        $Process.Kill($true)
        [void]$Process.WaitForExit(5000)
    }
}

function Submit-NativeOpenPicker([int]$ProcessId, [string]$Path) {
    $dialog = Find-ElementByName -ProcessId $ProcessId -Name "选择音乐" -TimeoutMilliseconds 15000
    $handle = [IntPtr]$dialog.Current.NativeWindowHandle
    if ($handle -eq [IntPtr]::Zero) { throw "Native Open picker has no window handle." }

    $edit = $null
    $hostCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty, "FileNameControlHost")
    $fileNameHost = $dialog.FindFirst([Windows.Automation.TreeScope]::Descendants, $hostCondition)
    if ($fileNameHost) {
        $legacyEditCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty, "1001")
        $edit = $fileNameHost.FindFirst(
            [Windows.Automation.TreeScope]::Descendants,
            $legacyEditCondition)
    }

    if (-not $edit) {
        $modernEditCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty, "1148")
        $allIdMatches = $dialog.FindAll(
            [Windows.Automation.TreeScope]::Descendants,
            $modernEditCondition)
        for ($index = 0; $index -lt $allIdMatches.Count; $index++) {
            $candidate = $allIdMatches.Item($index)
            $valuePattern = $null
            if ($candidate.Current.IsEnabled -and
                $candidate.Current.ControlType -eq [Windows.Automation.ControlType]::Edit -and
                $candidate.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$valuePattern)) {
                $edit = $candidate
                break
            }
        }
    }

    if (-not $edit) {
        $allControls = $dialog.FindAll(
            [Windows.Automation.TreeScope]::Descendants,
            [Windows.Automation.Condition]::TrueCondition)
        for ($index = 0; $index -lt $allControls.Count; $index++) {
            $candidate = $allControls.Item($index)
            $candidatePattern = $null
            $hasValue = $candidate.TryGetCurrentPattern(
                [Windows.Automation.ValuePattern]::Pattern,
                [ref]$candidatePattern)
            if ($hasValue -or
                $candidate.Current.ControlType -eq [Windows.Automation.ControlType]::Edit -or
                $candidate.Current.ControlType -eq [Windows.Automation.ControlType]::ComboBox) {
                Write-Host ("PICKER_CONTROL id='{0}' name='{1}' class='{2}' type='{3}' valuePattern={4}" -f
                    [string]$candidate.Current.AutomationId,
                    [string]$candidate.Current.Name,
                    [string]$candidate.Current.ClassName,
                    [string]$candidate.Current.ControlType.ProgrammaticName,
                    $hasValue)
            }
        }
        throw "Native Open picker did not expose an editable filename child (legacy 1001 or current 1148)."
    }
    Set-ElementValue $edit $Path
    $button = $null
    foreach ($id in @("1", "CommandButton_1")) {
        $condition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty, $id)
        $candidate = $dialog.FindFirst([Windows.Automation.TreeScope]::Descendants, $condition)
        if ($candidate) { $button = $candidate; break }
    }
    if (-not $button) { throw "Native Open picker did not expose its Open button." }
    Invoke-Element $button
    return [ordered]@{
        title = [string]$dialog.Current.Name
        nativeWindowHandle = $handle.ToInt64()
        fileNameAutomationId = [string]$edit.Current.AutomationId
        submittedPath = $Path
        submission = "ValuePattern + explicit Open button"
    }
}

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$chartFixtureFullPath = Resolve-ExistingFile $ChartFixturePath "Real MC fixture"
$mp3FixtureFullPath = Resolve-ExistingFile $Mp3FixturePath "Real MP3 fixture"
$variableTempoAudioFullPath = Resolve-ExistingFile $VariableTempoAudioPath "Real variable-tempo OGG fixture"
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
if (-not (Test-Path -LiteralPath $outputFullPath -PathType Container)) {
    throw "Output root must already exist: $outputFullPath"
}
$guiRoot = Join-Path $outputFullPath "gui-runtime"
if (Test-Path -LiteralPath $guiRoot) { throw "GUI output root already exists: $guiRoot" }
New-Item -ItemType Directory -Path $guiRoot | Out-Null

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$projectTemp = Join-Path $projectRoot ".codex-temp"
$dotnetHome = Join-Path $projectRoot ".codex-dotnet-home"
$nugetPackages = Join-Path $projectRoot ".codex-nuget-packages"
$nugetHttpCache = Join-Path $projectRoot ".codex-nuget-http-cache"
foreach ($directory in @($projectTemp, $dotnetHome, $nugetPackages, $nugetHttpCache)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$workingRoot = Join-Path $guiRoot "working"
$clientRoot = Join-Path $guiRoot "client"
New-Item -ItemType Directory -Path $workingRoot | Out-Null
$workingChart = Join-Path $workingRoot "audio-tempo-real.mc"
Copy-Item -LiteralPath $chartFixtureFullPath -Destination $workingChart
$fixtureHashesBefore = [ordered]@{
    chart = (Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash
    mp3 = (Get-FileHash -LiteralPath $mp3FixtureFullPath -Algorithm SHA256).Hash
    variableTempoOgg = (Get-FileHash -LiteralPath $variableTempoAudioFullPath -Algorithm SHA256).Hash
}
$workingHashBefore = (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash
$first = $null
$second = $null

try {
    $first = Start-AudioTempoClient -Profile "windows-avalonia-audio-tempo-first" -ChartPath $workingChart -ClientRoot $clientRoot
    $firstHandle = Wait-MainWindowHandle $first
    [void][LumaChartAudioTempoGuiNative]::ShowWindow($firstHandle, 3)
    Select-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Inspector.MetadataTab" -TimeoutMilliseconds 30000)
    Start-Sleep -Milliseconds 500

    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.AudioSelect")
    $mp3Picker = Submit-NativeOpenPicker -ProcessId $first.Id -Path $mp3FixtureFullPath
    $modeDialog = Find-ElementById -ProcessId $first.Id -AutomationId "AudioImport.ModeDialog" -TimeoutMilliseconds 15000
    $modeHandle = [IntPtr]$modeDialog.Current.NativeWindowHandle
    $modeScreenshot = Join-Path $guiRoot "audio-import-mode.png"
    $modeCapture = Capture-Window $modeHandle $modeScreenshot
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "AudioImport.KeepOriginal")

    $cancelActionObserved = $false
    Wait-Condition -Description "enabled single-tempo cancel action" -Seconds 30 -Condition {
        $candidate = Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.AnalyzeSingleTempo" -TimeoutMilliseconds 1000
        if ($candidate.Current.IsEnabled -and
            [string]$candidate.Current.Name -ceq "取消 BPM 分析") {
            $script:audioTempoCancelButton = $candidate
            return $true
        }
        return $false
    }
    $cancelActionObserved = $true
    Invoke-Element $script:audioTempoCancelButton
    $script:audioTempoCancelButton = $null
    $cancelStatus = Wait-ElementName -ProcessId $first.Id -AutomationId "Metadata.AudioAnalysisStatus" -Like "*BPM 分析已取消*" -Seconds 30
    Wait-Condition -Description "single-tempo action to reset after cancellation" -Seconds 30 -Condition {
        $candidate = Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.AnalyzeSingleTempo" -TimeoutMilliseconds 1000
        $candidate.Current.IsEnabled -and
            [string]$candidate.Current.Name -ceq "检测 BPM 与 Offset"
    }
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.AnalyzeSingleTempo")
    $mp3ResultDialog = Find-ElementById -ProcessId $first.Id -AutomationId "Tempo.SingleResultDialog" -TimeoutMilliseconds 180000
    $mp3SingleResult = [string](Find-ElementById -ProcessId $first.Id -AutomationId "Tempo.SingleResult").Current.Name
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Tempo.SingleCancel")
    Wait-Condition -Description "MP3 reference in Metadata" -Seconds 30 -Condition {
        (Get-ElementValue (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.AudioFile" -TimeoutMilliseconds 1000)) -ceq "audio.mp3"
    }

    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.AudioSelect")
    $oggPicker = Submit-NativeOpenPicker -ProcessId $first.Id -Path $variableTempoAudioFullPath
    $positiveSingleDialog = Find-ElementById -ProcessId $first.Id -AutomationId "Tempo.SingleResultDialog" -TimeoutMilliseconds 180000
    $positiveSingleResult = [string](Find-ElementById -ProcessId $first.Id -AutomationId "Tempo.SingleResult").Current.Name
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Tempo.SingleCancel")
    Wait-Condition -Description "OGG reference in Metadata" -Seconds 30 -Condition {
        (Get-ElementValue (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.AudioFile" -TimeoutMilliseconds 1000)) -ceq "1770113980.ogg"
    }

    Wait-Condition -Description "variable-tempo button to be enabled" -Seconds 30 -Condition {
        (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.AnalyzeVariableTempo" -TimeoutMilliseconds 1000).Current.IsEnabled
    }
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.AnalyzeVariableTempo")
    $variableDialog = Find-ElementById -ProcessId $first.Id -AutomationId "Tempo.VariableResultDialog" -TimeoutMilliseconds 180000
    $variableHandle = [IntPtr]$variableDialog.Current.NativeWindowHandle
    $variablePreview = [string](Find-ElementById -ProcessId $first.Id -AutomationId "Tempo.VariablePreview").Current.Name
    $variableScreenshot = Join-Path $guiRoot "variable-tempo-preview.png"
    $variableCapture = Capture-Window $variableHandle $variableScreenshot
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Tempo.VariableCompensate")
    $appliedStatus = Wait-ElementName -ProcessId $first.Id -AutomationId "Metadata.AudioAnalysisStatus" -Like "*生成 Scroll 流速补正*" -Seconds 45

    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.Save")
    Wait-Condition -Description "saved MC hash to change" -Seconds 60 -Condition {
        (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash -cne $workingHashBefore
    }
    $copiedVariableAudio = Join-Path $workingRoot "1770113980.ogg"
    Wait-Condition -Description "localized variable-tempo OGG beside saved chart" -Seconds 60 -Condition {
        Test-Path -LiteralPath $copiedVariableAudio -PathType Leaf
    }
    $appliedScreenshot = Join-Path $guiRoot "audio-tempo-applied-saved.png"
    $appliedCapture = Capture-Window $firstHandle $appliedScreenshot
    Stop-TrackedClient $first

    $second = Start-AudioTempoClient -Profile "windows-avalonia-audio-tempo-reopen" -ChartPath $workingChart -ClientRoot (Join-Path $guiRoot "client-reopen")
    $secondHandle = Wait-MainWindowHandle $second
    [void][LumaChartAudioTempoGuiNative]::ShowWindow($secondHandle, 3)
    Select-Element (Find-ElementById -ProcessId $second.Id -AutomationId "Inspector.MetadataTab" -TimeoutMilliseconds 30000)
    Start-Sleep -Milliseconds 700
    $reopenedAudio = Get-ElementValue (Find-ElementById -ProcessId $second.Id -AutomationId "Metadata.AudioFile")
    $reopenedOffset = Get-ElementValue (Find-ElementById -ProcessId $second.Id -AutomationId "Metadata.Offset")
    $reopenedScreenshot = Join-Path $guiRoot "audio-tempo-reopened.png"
    $reopenedCapture = Capture-Window $secondHandle $reopenedScreenshot
    Stop-TrackedClient $second

    $coreAssembly = Join-Path $projectRoot "LumaChart.Core\bin\Release\net8.0\LumaChart.Core.dll"
    [void][Reflection.Assembly]::LoadFrom($coreAssembly)
    $document = [LumaChart.Core.IO.MalodyMcSerializer]::Load($workingChart)
    # PowerShell unwraps Nullable<double> properties returned from C#; test for
    # null and cast the value directly instead of reading HasValue/Value.
    $bpmTiming = @($document.Timing | Where-Object { $null -ne $_.Bpm } | Sort-Object { $_.Beat.Value })
    $scrollTiming = @($document.Timing | Where-Object { $_.Effect -eq [LumaChart.Core.Models.TimingEffectKind]::Scroll })
    $bpmSequence = @($bpmTiming | ForEach-Object { [double]$_.Bpm })
    $beatSequence = @($bpmTiming | ForEach-Object { [string]$_.Beat.ToString() })
    if ($bpmSequence.Count -ne 4 -or
        ($bpmSequence -join ',') -cne '105,155,105,155' -or
        ($beatSequence -join ',') -cne '0:0/1,57:1/2,129:1/2,165:1/2') {
        throw "Saved variable-tempo timeline does not match the four formal Positive Parade candidates."
    }
    if ([string]$document.Metadata.AudioFile -cne "1770113980.ogg" -or
        [string]$reopenedAudio -cne "1770113980.ogg") {
        throw "Saved/reopened audio reference did not remain on the imported OGG."
    }

    $fixtureHashesAfter = [ordered]@{
        chart = (Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash
        mp3 = (Get-FileHash -LiteralPath $mp3FixtureFullPath -Algorithm SHA256).Hash
        variableTempoOgg = (Get-FileHash -LiteralPath $variableTempoAudioFullPath -Algorithm SHA256).Hash
    }
    foreach ($name in $fixtureHashesBefore.Keys) {
        if ([string]$fixtureHashesBefore[$name] -cne [string]$fixtureHashesAfter[$name]) {
            throw "Immutable fixture '$name' changed during GUI acceptance."
        }
    }
    $copiedOggHash = (Get-FileHash -LiteralPath $copiedVariableAudio -Algorithm SHA256).Hash
    if ($copiedOggHash -cne $fixtureHashesBefore.variableTempoOgg) {
        throw "Localized OGG differs from the selected real fixture."
    }

    $screenshots = @{}
    foreach ($path in @($modeScreenshot, $variableScreenshot, $appliedScreenshot, $reopenedScreenshot)) {
        $item = Get-Item -LiteralPath $path
        $screenshots[$item.BaseName] = [ordered]@{
            path = $item.FullName
            length = $item.Length
            sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        }
    }
    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.audio-tempo-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("o")
        status = "passed-migration-incomplete"
        windowsAvaloniaOnly = $true
        productionServerMutationPerformed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        ollvmExecutedOrRequired = $false
        chineseImeGlobalEnterEscapeHandlerAdded = $false
        textInputMethod = "UIAutomation ValuePattern with explicit picker/dialog buttons"
        fixtures = [ordered]@{
            chart = [ordered]@{ path = $chartFixtureFullPath; sha256Before = $fixtureHashesBefore.chart; sha256After = $fixtureHashesAfter.chart; unchanged = $true }
            mp3 = [ordered]@{ path = $mp3FixtureFullPath; sha256Before = $fixtureHashesBefore.mp3; sha256After = $fixtureHashesAfter.mp3; unchanged = $true }
            variableTempoOgg = [ordered]@{ path = $variableTempoAudioFullPath; sha256Before = $fixtureHashesBefore.variableTempoOgg; sha256After = $fixtureHashesAfter.variableTempoOgg; unchanged = $true }
        }
        nativePickers = [ordered]@{ mp3 = $mp3Picker; variableTempoOgg = $oggPicker }
        firstImport = [ordered]@{
            mode = "KeepOriginal"
            finalReferenceBeforeSecondImport = "audio.mp3"
            activeAnalysisCancelActionObserved = $cancelActionObserved
            cancellationStatus = [string]$cancelStatus.Current.Name
            analysisRestartedAfterCancellation = $true
            singleResult = $mp3SingleResult
            analysisApplyAccepted = $false
        }
        variableTempoImport = [ordered]@{
            finalReference = [string]$document.Metadata.AudioFile
            copiedPath = $copiedVariableAudio
            copiedLength = (Get-Item -LiteralPath $copiedVariableAudio).Length
            copiedSha256 = $copiedOggHash
            singleResult = $positiveSingleResult
            singleApplyAccepted = $false
        }
        variableTempo = [ordered]@{
            previewText = $variablePreview
            bpmSequence = $bpmSequence
            beatSequence = $beatSequence
            scrollCount = $scrollTiming.Count
            initialOffset = [double]$bpmTiming[0].Delay
            applyChoice = "ApplyWithScrollCompensation"
            appliedStatus = [string]$appliedStatus.Current.Name
        }
        reopened = [ordered]@{
            audioReference = [string]$reopenedAudio
            offset = [string]$reopenedOffset
            bpmSequence = $bpmSequence
            beatSequence = $beatSequence
        }
        captures = [ordered]@{
            audioImportMode = $modeCapture
            variableTempoPreview = $variableCapture
            appliedSaved = $appliedCapture
            reopened = $reopenedCapture
        }
        screenshots = $screenshots
        completion = [ordered]@{
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
        }
        remainingDifferences = @(
            "Convert-to-OGG GUI branch, import cancellation/failure, single-result accepted GUI and online permission races still need full Windows evidence.",
            "The full WPF matrix, physical display performance, ClientSecurity and installer gates remain incomplete."
        )
    }
    $evidencePath = Join-Path $outputFullPath "audio-tempo-gui-evidence.json"
    $evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    Write-Host "Windows Avalonia audio/tempo GUI acceptance: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    Stop-TrackedClient $second
    Stop-TrackedClient $first
}
