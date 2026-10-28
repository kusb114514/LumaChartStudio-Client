param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$CoverFixturePath = "D:\osu!\Songs\1005389 Minori Chihara - Michishirube\BG1.jpg",
    [string]$BackgroundFixturePath = "D:\osu!\Songs\1005389 Minori Chihara - Michishirube\BG3.png",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia metadata/assets GUI capture requires PowerShell Core on Windows."
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

public static class LumaChartMetadataAssetsGuiNative
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
        [ValidateRange(100, 180000)][int]$TimeoutMilliseconds = 10000
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
        [ValidateRange(100, 180000)][int]$TimeoutMilliseconds = 10000
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

function Get-ElementValue($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose ValuePattern."
    }
    return ([Windows.Automation.ValuePattern]$pattern).Current.Value
}

function Set-ElementValue($Element, [string]$Value) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose ValuePattern."
    }
    ([Windows.Automation.ValuePattern]$pattern).SetValue($Value)
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

function Wait-MainWindowHandle([Diagnostics.Process]$Process) {
    Wait-Condition -Description "main window for process $($Process.Id)" -Condition {
        $Process.Refresh()
        -not $Process.HasExited -and $Process.MainWindowHandle -ne [IntPtr]::Zero
    }
    return $Process.MainWindowHandle
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartMetadataAssetsGuiNative+RECT]::new()
    if (-not [LumaChartMetadataAssetsGuiNative]::GetWindowRect($Handle, [ref]$rectangle)) {
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
                if (-not [LumaChartMetadataAssetsGuiNative]::PrintWindow($Handle, $dc, 2)) {
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
    if (-not $process) { throw "Unable to start Windows Avalonia metadata client." }
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
    $dialog = Find-ElementByName -ProcessId $ProcessId -Name "选择图片" -TimeoutMilliseconds 15000
    $edit = $null
    $modernEditCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty, "1148")
    $matches = $dialog.FindAll([Windows.Automation.TreeScope]::Descendants, $modernEditCondition)
    for ($index = 0; $index -lt $matches.Count; $index++) {
        $candidate = $matches.Item($index)
        $valuePattern = $null
        if ($candidate.Current.IsEnabled -and
            $candidate.Current.ControlType -eq [Windows.Automation.ControlType]::Edit -and
            $candidate.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$valuePattern) -and
            ([string]$candidate.Current.Name -match '文件名|File name')) {
            $edit = $candidate
            break
        }
    }
    if (-not $edit) {
        for ($index = 0; $index -lt $matches.Count; $index++) {
            $candidate = $matches.Item($index)
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
        $hostCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty, "FileNameControlHost")
        $host = $dialog.FindFirst([Windows.Automation.TreeScope]::Descendants, $hostCondition)
        if ($host) {
            $legacyCondition = [Windows.Automation.PropertyCondition]::new(
                [Windows.Automation.AutomationElement]::AutomationIdProperty, "1001")
            $edit = $host.FindFirst([Windows.Automation.TreeScope]::Descendants, $legacyCondition)
        }
    }
    if (-not $edit) { throw "Native Open picker did not expose filename edit 1148 or 1001." }
    $edit.SetFocus()
    Start-Sleep -Milliseconds 150
    Set-ElementValue $edit $Path
    if ((Get-ElementValue $edit) -cne $Path) {
        throw "Native Open picker filename did not retain the submitted absolute path."
    }
    Start-Sleep -Milliseconds 350
    $fileNameCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty,
        [IO.Path]::GetFileName($Path))
    $fileItem = $dialog.FindFirst(
        [Windows.Automation.TreeScope]::Descendants,
        $fileNameCondition)
    if (-not $fileItem) {
        throw "Native Open picker did not expose the requested file-list item '$([IO.Path]::GetFileName($Path))'."
    }
    $selectionPattern = $null
    if (-not $fileItem.TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$selectionPattern)) {
        throw "Native Open picker file-list item does not expose SelectionItemPattern."
    }
    ([Windows.Automation.SelectionItemPattern]$selectionPattern).Select()
    Start-Sleep -Milliseconds 250
    if (-not ([Windows.Automation.SelectionItemPattern]$selectionPattern).Current.IsSelected) {
        throw "Native Open picker did not select the requested file-list item."
    }
    $submittedAutomationId = [string]$edit.Current.AutomationId
    $selectedFileItemName = [string]$fileItem.Current.Name
    $fileInvokePattern = $null
    if (-not $fileItem.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$fileInvokePattern)) {
        throw "Native Open picker file-list item does not expose InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$fileInvokePattern).Invoke()
    return [ordered]@{
        title = "选择图片"
        fileNameAutomationId = $submittedAutomationId
        submittedPath = $Path
        selectedFileItem = $selectedFileItemName
        submission = "ValuePattern + SelectionItemPattern + file-item InvokePattern"
    }

}

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$chartFixtureFullPath = Resolve-ExistingFile $ChartFixturePath "Real MC fixture"
$coverFixtureFullPath = Resolve-ExistingFile $CoverFixturePath "Real cover fixture"
$backgroundFixtureFullPath = Resolve-ExistingFile $BackgroundFixturePath "Real background fixture"
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
New-Item -ItemType Directory -Path $workingRoot | Out-Null
$workingChart = Join-Path $workingRoot "metadata-assets-real.mc"
Copy-Item -LiteralPath $chartFixtureFullPath -Destination $workingChart
$fixtureHashesBefore = [ordered]@{
    chart = (Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash
    cover = (Get-FileHash -LiteralPath $coverFixtureFullPath -Algorithm SHA256).Hash
    background = (Get-FileHash -LiteralPath $backgroundFixtureFullPath -Algorithm SHA256).Hash
}
Write-Host "Metadata/assets fixtures: chart='$chartFixtureFullPath'; cover='$coverFixtureFullPath'; background='$backgroundFixtureFullPath'"
$workingHashBefore = (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash
$first = $null
$second = $null

try {
    $first = Start-MetadataClient -Profile "windows-avalonia-metadata-assets-first" -ChartPath $workingChart -ClientRoot (Join-Path $guiRoot "client")
    $firstHandle = Wait-MainWindowHandle $first
    [void][LumaChartMetadataAssetsGuiNative]::ShowWindow($firstHandle, 3)
    Select-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Inspector.MetadataTab" -TimeoutMilliseconds 30000)

    Set-ElementValue (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.TitleOriginal") "みちしるべ"
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.RomanizeTitle")
    Wait-Condition -Description "hiragana title romanization" -Condition {
        (Get-ElementValue (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.Title" -TimeoutMilliseconds 1000)) -ceq "Michishirube"
    }
    Set-ElementValue (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.ArtistOriginal") "道標"
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.RomanizeArtist")
    Wait-Condition -Description "offline Kanji artist romanization" -Condition {
        $value = Get-ElementValue (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.Artist" -TimeoutMilliseconds 1000)
        -not [string]::IsNullOrWhiteSpace($value) -and $value -cmatch '^[\x20-\x7E]+$'
    }
    $romanizedTitle = Get-ElementValue (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.Title")
    $romanizedArtist = Get-ElementValue (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.Artist")

    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.CoverSelect")
    $coverPicker = Submit-NativeOpenPicker -ProcessId $first.Id -Path $coverFixtureFullPath
    Wait-Condition -Description "cover reference in metadata draft" -Condition {
        (Get-ElementValue (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.CoverFile" -TimeoutMilliseconds 1000)) -ceq "BG1.jpg"
    }
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.BackgroundSelect")
    $backgroundPicker = Submit-NativeOpenPicker -ProcessId $first.Id -Path $backgroundFixtureFullPath
    Wait-Condition -Description "background reference and decoded preview" -Condition {
        $reference = Get-ElementValue (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.BackgroundFile" -TimeoutMilliseconds 1000)
        $status = [string](Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.Status" -TimeoutMilliseconds 1000).Current.Name
        $reference -ceq "BG3.png" -and $status -like "背景预览已加载：BG3.png*"
    }
    $backgroundPreviewStatusBeforeApply =
        [string](Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.Status").Current.Name
    $draftScreenshot = Join-Path $guiRoot "metadata-assets-draft-preview.png"
    $draftCapture = Capture-Window $firstHandle $draftScreenshot

    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.Apply")
    Wait-Condition -Description "atomic metadata apply" -Condition {
        [string](Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.Status" -TimeoutMilliseconds 1000).Current.Name -like "谱面信息已原子应用*"
    }
    $applyStatus = [string](Find-ElementById -ProcessId $first.Id -AutomationId "Metadata.Status").Current.Name
    Invoke-Element (Find-ElementById -ProcessId $first.Id -AutomationId "Editor.Save")
    Wait-Condition -Description "saved MC hash to change" -Condition {
        (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash -cne $workingHashBefore
    }
    $savedCover = Join-Path $workingRoot "BG1.jpg"
    $savedBackground = Join-Path $workingRoot "BG3.png"
    Wait-Condition -Description "localized cover and background beside saved chart" -Condition {
        (Test-Path -LiteralPath $savedCover -PathType Leaf) -and
        (Test-Path -LiteralPath $savedBackground -PathType Leaf)
    }
    $savedScreenshot = Join-Path $guiRoot "metadata-assets-applied-saved.png"
    $savedCapture = Capture-Window $firstHandle $savedScreenshot
    Stop-TrackedClient $first

    $second = Start-MetadataClient -Profile "windows-avalonia-metadata-assets-reopen" -ChartPath $workingChart -ClientRoot (Join-Path $guiRoot "client-reopen")
    $secondHandle = Wait-MainWindowHandle $second
    [void][LumaChartMetadataAssetsGuiNative]::ShowWindow($secondHandle, 3)
    Select-Element (Find-ElementById -ProcessId $second.Id -AutomationId "Inspector.MetadataTab" -TimeoutMilliseconds 30000)
    Wait-Condition -Description "reopened background preview" -Condition {
        [string](Find-ElementById -ProcessId $second.Id -AutomationId "Metadata.Status" -TimeoutMilliseconds 1000).Current.Name -like "背景预览已加载：BG3.png*"
    }
    $reopened = [ordered]@{
        title = Get-ElementValue (Find-ElementById -ProcessId $second.Id -AutomationId "Metadata.Title")
        titleOriginal = Get-ElementValue (Find-ElementById -ProcessId $second.Id -AutomationId "Metadata.TitleOriginal")
        artist = Get-ElementValue (Find-ElementById -ProcessId $second.Id -AutomationId "Metadata.Artist")
        artistOriginal = Get-ElementValue (Find-ElementById -ProcessId $second.Id -AutomationId "Metadata.ArtistOriginal")
        cover = Get-ElementValue (Find-ElementById -ProcessId $second.Id -AutomationId "Metadata.CoverFile")
        background = Get-ElementValue (Find-ElementById -ProcessId $second.Id -AutomationId "Metadata.BackgroundFile")
        backgroundPreviewStatus =
            [string](Find-ElementById -ProcessId $second.Id -AutomationId "Metadata.Status").Current.Name
    }
    $reopenedScreenshot = Join-Path $guiRoot "metadata-assets-reopened.png"
    $reopenedCapture = Capture-Window $secondHandle $reopenedScreenshot
    Stop-TrackedClient $second

    if ([string]$reopened.title -cne $romanizedTitle -or
        [string]$reopened.artist -cne $romanizedArtist -or
        [string]$reopened.titleOriginal -cne "みちしるべ" -or
        [string]$reopened.artistOriginal -cne "道標" -or
        [string]$reopened.cover -cne "BG1.jpg" -or
        [string]$reopened.background -cne "BG3.png") {
        throw "Second-process metadata did not match the applied title, artist, cover and background."
    }

    $coreAssembly = Join-Path $projectRoot "LumaChart.Core\bin\Release\net8.0\LumaChart.Core.dll"
    [void][Reflection.Assembly]::LoadFrom($coreAssembly)
    $document = [LumaChart.Core.IO.MalodyMcSerializer]::Load($workingChart)
    if ([string]$document.Metadata.Title -cne $romanizedTitle -or
        [string]$document.Metadata.Artist -cne $romanizedArtist -or
        [string]$document.Metadata.CoverFile -cne "BG1.jpg" -or
        [string]$document.Metadata.BackgroundFile -cne "BG3.png") {
        throw "Structured MC reopen did not preserve applied metadata resource references."
    }

    $fixtureHashesAfter = [ordered]@{
        chart = (Get-FileHash -LiteralPath $chartFixtureFullPath -Algorithm SHA256).Hash
        cover = (Get-FileHash -LiteralPath $coverFixtureFullPath -Algorithm SHA256).Hash
        background = (Get-FileHash -LiteralPath $backgroundFixtureFullPath -Algorithm SHA256).Hash
    }
    foreach ($name in $fixtureHashesBefore.Keys) {
        if ([string]$fixtureHashesBefore[$name] -cne [string]$fixtureHashesAfter[$name]) {
            throw "Immutable fixture '$name' changed during GUI acceptance."
        }
    }
    if ((Get-FileHash -LiteralPath $savedCover -Algorithm SHA256).Hash -cne $fixtureHashesBefore.cover -or
        (Get-FileHash -LiteralPath $savedBackground -Algorithm SHA256).Hash -cne $fixtureHashesBefore.background) {
        throw "Saved cover/background bytes differ from the native-picker fixtures."
    }

    $screenshots = @{}
    foreach ($path in @($draftScreenshot, $savedScreenshot, $reopenedScreenshot)) {
        $item = Get-Item -LiteralPath $path
        $screenshots[$item.BaseName] = [ordered]@{
            path = $item.FullName
            length = $item.Length
            sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        }
    }
    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.metadata-assets-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("o")
        status = "passed-migration-incomplete"
        windowsAvaloniaOnly = $true
        productionServerMutationPerformed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        ollvmExecutedOrRequired = $false
        chineseImeGlobalEnterEscapeHandlerAdded = $false
        textInputMethod = "UIAutomation ValuePattern with explicit buttons; no synthetic global Enter/Escape"
        fixtures = [ordered]@{
            chart = [ordered]@{ path = $chartFixtureFullPath; sha256Before = $fixtureHashesBefore.chart; sha256After = $fixtureHashesAfter.chart; unchanged = $true }
            cover = [ordered]@{ path = $coverFixtureFullPath; sha256Before = $fixtureHashesBefore.cover; sha256After = $fixtureHashesAfter.cover; unchanged = $true }
            background = [ordered]@{ path = $backgroundFixtureFullPath; sha256Before = $fixtureHashesBefore.background; sha256After = $fixtureHashesAfter.background; unchanged = $true }
        }
        nativePickers = [ordered]@{ cover = $coverPicker; background = $backgroundPicker }
        romanization = [ordered]@{
            titleOriginal = "みちしるべ"
            title = $romanizedTitle
            artistOriginal = "道標"
            artist = $romanizedArtist
            offlineDictionary = $true
        }
        applied = [ordered]@{
            status = $applyStatus
            coverReference = [string]$document.Metadata.CoverFile
            backgroundReference = [string]$document.Metadata.BackgroundFile
            coverPath = $savedCover
            backgroundPath = $savedBackground
            backgroundPreviewStatusBeforeApply = $backgroundPreviewStatusBeforeApply
        }
        reopened = $reopened
        captures = [ordered]@{ draftPreview = $draftCapture; appliedSaved = $savedCapture; reopened = $reopenedCapture }
        screenshots = $screenshots
        completion = [ordered]@{
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
        }
        remainingDifferences = @(
            "Settings/cache/editor-offset and Rework/test-play remain the next Windows Avalonia parity slices.",
            "The full WPF matrix, two-client final online gate, physical display performance, ClientSecurity and installer gates remain incomplete."
        )
    }
    $evidencePath = Join-Path $outputFullPath "metadata-assets-gui-evidence.json"
    $evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    Write-Host "Windows Avalonia metadata/assets GUI acceptance: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    Stop-TrackedClient $second
    Stop-TrackedClient $first
}
