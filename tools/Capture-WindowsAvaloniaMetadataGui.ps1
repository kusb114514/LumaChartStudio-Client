param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$OsuFixturePath = "D:\osu!\Songs\1005389 Minori Chihara - Michishirube\Minori Chihara - Michishirube (eZmmR) [Dear You,  Gilbert Bougainvillea .].osu",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia Metadata GUI capture requires PowerShell Core on Windows."
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

public static class LumaChartMetadataGuiNative
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

function Select-ComboItemByName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)]$ComboBox,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $expand = $null
    if (-not $ComboBox.TryGetCurrentPattern(
            [Windows.Automation.ExpandCollapsePattern]::Pattern,
            [ref]$expand)) {
        throw "Element '$($ComboBox.Current.AutomationId)' does not expose ExpandCollapsePattern."
    }
    ([Windows.Automation.ExpandCollapsePattern]$expand).Expand()
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $nameCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty,
        $Name)
    $typeCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ControlTypeProperty,
        [Windows.Automation.ControlType]::ListItem)
    $targetCondition = [Windows.Automation.AndCondition]::new(
        $nameCondition,
        $typeCondition)
    $selected = $null
    $script:metadataComboTarget = $null
    Wait-Condition -Description "ComboBox item '$Name'" -Seconds 20 -Condition {
        $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
            [Windows.Automation.TreeScope]::Children,
            $processCondition)
        foreach ($root in $roots) {
            $candidate = $root.FindFirst(
                [Windows.Automation.TreeScope]::Descendants,
                $targetCondition)
            if ($candidate) {
                $script:metadataComboTarget = $candidate
                return $true
            }
        }
        return $false
    }
    $selected = $script:metadataComboTarget
    $script:metadataComboTarget = $null
    Select-Element $selected
}

function Wait-ElementName([int]$ProcessId, [string]$AutomationId, [string]$Like, [int]$Seconds = 30) {
    $script:metadataWaitElement = $null
    Wait-Condition -Description "'$AutomationId' name '$Like'" -Seconds $Seconds -Condition {
        $candidate = Find-ElementById -ProcessId $ProcessId -AutomationId $AutomationId -TimeoutMilliseconds 1000
        if ([string]$candidate.Current.Name -like $Like) {
            $script:metadataWaitElement = $candidate
            return $true
        }
        return $false
    }
    $result = $script:metadataWaitElement
    $script:metadataWaitElement = $null
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
    $rectangle = [LumaChartMetadataGuiNative+RECT]::new()
    if (-not [LumaChartMetadataGuiNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 500 -or $height -lt 400) { throw "Window has invalid bounds: ${width}x${height}." }
    $bitmap = [Drawing.Bitmap]::new($width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $dc = $graphics.GetHdc()
            try {
                if (-not [LumaChartMetadataGuiNative]::PrintWindow($Handle, $dc, 2)) {
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
        if ($colors.Count -lt 8) { throw "Screenshot is near-uniform: $($colors.Count) sampled colors." }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{ width = $width; height = $height; sampledUniqueColors = $colors.Count }
    }
    finally { $bitmap.Dispose() }
}

function Start-MetadataClient([string]$Profile, [string]$ChartPath, [string]$ClientRoot) {
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
    if (-not $process) { throw "Unable to start Windows Avalonia Metadata client." }
    return $process
}

function Stop-TrackedClient([Diagnostics.Process]$Process) {
    if (-not $Process -or $Process.HasExited) { return }
    [void]$Process.CloseMainWindow()
    if (-not $Process.WaitForExit(8000)) {
        $Process.Kill($true)
        [void]$Process.WaitForExit(5000)
    }
}

function Get-MetadataFields([int]$ProcessId) {
    return [ordered]@{
        title = Get-ElementValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Metadata.Title")
        titleOriginal = Get-ElementValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Metadata.TitleOriginal")
        artist = Get-ElementValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Metadata.Artist")
        artistOriginal = Get-ElementValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Metadata.ArtistOriginal")
        creator = Get-ElementValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Metadata.Creator")
        version = Get-ElementValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Metadata.Version")
        bpm = Get-ElementValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Metadata.Bpm")
        previewTime = Get-ElementValue (Find-ElementById -ProcessId $ProcessId -AutomationId "Metadata.PreviewTime")
    }
}

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$fixtureFullPath = Resolve-ExistingFile $OsuFixturePath "Real osu fixture"
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
$workingChart = Join-Path $workingRoot "metadata-real.osu"
Copy-Item -LiteralPath $fixtureFullPath -Destination $workingChart
$fixtureHashBefore = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
$workingHashBefore = (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash
$first = $null
$second = $null

try {
    $first = Start-MetadataClient -Profile "windows-avalonia-metadata-first" -ChartPath $workingChart -ClientRoot $clientRoot
    $firstHandle = Wait-MainWindowHandle $first
    [void][LumaChartMetadataGuiNative]::ShowWindow($firstHandle, 3)
    $metadataTab = Find-ElementById -ProcessId $first.Id -AutomationId "Inspector.MetadataTab" -TimeoutMilliseconds 30000
    Select-Element $metadataTab
    Start-Sleep -Milliseconds 500

    $previewButton = Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.PreviewHere"
    Invoke-Element $previewButton
    Start-Sleep -Milliseconds 300
    $previewFromRedLine = Get-ElementValue (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.PreviewTime")

    $values = [ordered]@{
        "Metadata.Title" = "Metadata GUI Spec"
        "Metadata.TitleOriginal" = "谱面 GUI 原名"
        "Metadata.Artist" = "Luma Artist"
        "Metadata.ArtistOriginal" = "艺术家 GUI 原名"
        "Metadata.Creator" = "Avalonia Creator"
        "Metadata.Version" = "GUI Atomic"
        "Metadata.Bpm" = "137.5"
    }
    foreach ($entry in $values.GetEnumerator()) {
        Set-ElementValue (Find-ElementById -ProcessId $first.Id -AutomationId $entry.Key) $entry.Value
    }
    $keyCountBox = Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.KeyCount"
    Select-ComboItemByName -ProcessId $first.Id -ComboBox $keyCountBox -Name "5 Keys"
    $applyStatus = Wait-ElementName -ProcessId $first.Id -AutomationId "Metadata.Status" -Like "*谱面信息已原子应用*"
    Set-ElementValue (
        Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.Version"
    ) "GUI Auto Save"
    $appliedFields = Get-MetadataFields $first.Id
    Invoke-Element (
        Find-ElementById -ProcessId $first.Id -AutomationId "Editor.CommandMenuToggle"
    )
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.Save")
    Wait-Condition -Description "working osu to be structurally saved" -Seconds 45 -Condition {
        (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash -cne $workingHashBefore
    }
    $saveStatus = Find-ElementById -ProcessId $first.Id -AutomationId "Editor.Status"
    $appliedScreenshot = Join-Path $guiRoot "metadata-applied-saved.png"
    $appliedCapture = Capture-Window $firstHandle $appliedScreenshot
    $appliedStatusObservation = [ordered]@{
        metadata = [string]$applyStatus.Current.Name
        editor = [string]$saveStatus.Current.Name
    }
    Stop-TrackedClient $first

    $second = Start-MetadataClient -Profile "windows-avalonia-metadata-reopen" -ChartPath $workingChart -ClientRoot (Join-Path $guiRoot "client-reopen")
    $secondHandle = Wait-MainWindowHandle $second
    [void][LumaChartMetadataGuiNative]::ShowWindow($secondHandle, 3)
    Select-Element (Find-ElementById -ProcessId $second.Id -AutomationId "Inspector.MetadataTab" -TimeoutMilliseconds 30000)
    Start-Sleep -Milliseconds 500
    $reopenedFields = Get-MetadataFields $second.Id
    $reopenedScreenshot = Join-Path $guiRoot "metadata-reopened.png"
    $reopenedCapture = Capture-Window $secondHandle $reopenedScreenshot

    foreach ($name in $appliedFields.Keys) {
        if ([string]$appliedFields[$name] -cne [string]$reopenedFields[$name]) {
            throw "Reopened Metadata field '$name' differs: '$($appliedFields[$name])' vs '$($reopenedFields[$name])'."
        }
    }
    Stop-TrackedClient $second

    $coreAssembly = Join-Path $projectRoot "LumaChart.Core\bin\Release\net8.0\LumaChart.Core.dll"
    [void][Reflection.Assembly]::LoadFrom($coreAssembly)
    $document = [LumaChart.Core.IO.OsuManiaSerializer]::Load($workingChart)
    $structure = [ordered]@{
        title = $document.Metadata.Title
        titleOriginal = $document.Metadata.TitleOriginal
        artist = $document.Metadata.Artist
        artistOriginal = $document.Metadata.ArtistOriginal
        creator = $document.Metadata.Creator
        version = $document.Metadata.Version
        bpm = $document.Metadata.Bpm
        previewTime = $document.Metadata.PreviewTime
        overallDifficulty = $document.Metadata.OverallDifficulty
        hpDrainRate = $document.Metadata.HpDrainRate
        keyCount = $document.KeyCount
        noteCount = $document.Notes.Count
        timingCount = $document.Timing.Count
    }
    if ($structure.title -cne "Metadata GUI Spec" -or $structure.artist -cne "Luma Artist" -or
        $structure.creator -cne "Avalonia Creator" -or $structure.version -cne "GUI Auto Save" -or
        [int]$structure.keyCount -ne 5 -or
        [Math]::Abs([double]$structure.bpm - 137.5) -gt 0.000000001) {
        throw "Structured reopened osu metadata does not match the GUI edit."
    }
    $fixtureHashAfter = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
    if ($fixtureHashBefore -cne $fixtureHashAfter) { throw "The immutable real osu fixture changed." }

    $screenshots = @{}
    foreach ($path in @($appliedScreenshot, $reopenedScreenshot)) {
        $item = Get-Item -LiteralPath $path
        $screenshots[$item.BaseName] = [ordered]@{
            path = $item.FullName
            length = $item.Length
            sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        }
    }
    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.metadata-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("o")
        status = "passed-migration-incomplete"
        windowsAvaloniaOnly = $true
        productionServerMutationPerformed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        chineseImeGlobalEnterEscapeHandlerAdded = $false
        textInputMethod = "UIAutomation ValuePattern; KeyCount SelectionItem applies immediately; Editor.Save commits the final pending Metadata field without pressing Apply"
        fixture = [ordered]@{
            path = $fixtureFullPath
            sha256Before = $fixtureHashBefore
            sha256After = $fixtureHashAfter
            unchanged = $fixtureHashBefore -ceq $fixtureHashAfter
        }
        workingChart = [ordered]@{
            path = $workingChart
            sha256Before = $workingHashBefore
            sha256After = (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash
        }
        previewFromRedLineMilliseconds = [int]$previewFromRedLine
        keyCountImmediateApply = [ordered]@{
            selected = 5
            status = [string]$applyStatus.Current.Name
            structuredReopen = [int]$structure.keyCount
        }
        saveCommittedPendingMetadataWithoutApply = $structure.version -ceq "GUI Auto Save"
        appliedFields = $appliedFields
        reopenedFields = $reopenedFields
        structuredReopen = $structure
        statuses = $appliedStatusObservation
        captures = [ordered]@{
            applied = $appliedCapture
            reopened = $reopenedCapture
        }
        screenshots = $screenshots
        completion = [ordered]@{
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
        }
        remainingDifferences = @(
            "Romanization, audio/image resource pickers and Timing Offset remain outside this Metadata slice.",
            "The complete WPF matrix, physical display performance, ClientSecurity and installer gates remain incomplete."
        )
    }
    $evidencePath = Join-Path $outputFullPath "metadata-gui-evidence.json"
    [IO.File]::WriteAllText($evidencePath, ($evidence | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Write-Host "Metadata GUI capture passed: $evidencePath"
}
finally {
    if ($first) { Stop-TrackedClient $first }
    if ($second) { Stop-TrackedClient $second }
}
