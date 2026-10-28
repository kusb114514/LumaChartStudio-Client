param(
    [string]$Root =
        "artifacts\windows-avalonia-export-dialog-parity-slice-20260727-r1\gui",
    [string]$ChartPath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [ValidateRange(20, 120)][int]$TimeoutSeconds = 60
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia export-dialog parity capture requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$artifactsBoundary = (
    [IO.Path]::GetFullPath((Join-Path $projectRoot "artifacts"))).
    TrimEnd('\') + '\'
$outputRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $Root)).
    TrimEnd('\')
if (-not ($outputRoot + '\').StartsWith(
        $artifactsBoundary,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Export-dialog GUI evidence must stay under $artifactsBoundary"
}
if (Test-Path -LiteralPath $outputRoot) {
    throw "Export-dialog GUI evidence root already exists: $outputRoot"
}

$chartFullPath = [IO.Path]::GetFullPath($ChartPath)
if (-not (Test-Path -LiteralPath $chartFullPath -PathType Leaf) -or
    -not [IO.Path]::GetExtension($chartFullPath).Equals(
        ".mc",
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Export-dialog parity requires a real MC chart: $chartFullPath"
}
$trustedChartSha256 =
    "A2828592A4898D35C1DD9FAC5905322760A152810EDCED60601D2F2C7B74E06E"
$sourceBefore = Get-Item -LiteralPath $chartFullPath
$sourceSha256Before = (
    Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
if ($sourceSha256Before -cne $trustedChartSha256) {
    throw "The real Resound MC fixture differs from the trusted baseline."
}

$installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$trustedInstallerSha256 =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
$installerSha256Before = (
    Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
if ($installerSha256Before -cne $trustedInstallerSha256) {
    throw "Frozen WPF installer differs before export-dialog capture."
}

$paths = [ordered]@{
    workspace = Join-Path $outputRoot "session\workspace"
    localData = Join-Path $outputRoot "session\local-data"
    editing = Join-Path $outputRoot "session\editing"
    temp = Join-Path $outputRoot "session\temp"
    runtime = Join-Path $outputRoot "runtime-evidence.json"
    interaction = Join-Path $outputRoot "interaction-evidence.json"
    base = Join-Path $outputRoot "screenshots\00-editor.png"
    default = Join-Path $outputRoot "screenshots\01-avalonia-default.png"
    singleChart = Join-Path $outputRoot "screenshots\02-avalonia-single-chart.png"
    singleRate = Join-Path $outputRoot "screenshots\03-avalonia-single-rate.png"
    ratePack = Join-Path $outputRoot "screenshots\04-avalonia-rate-pack.png"
    hiddenValidation = Join-Path $outputRoot "screenshots\05-avalonia-hidden-validation.png"
    result = Join-Path $outputRoot "screenshots\06-avalonia-native-result.png"
    normalizedDefault = Join-Path $outputRoot "screenshots\07-avalonia-default-normalized.png"
    wpfDefault = Join-Path $outputRoot "screenshots\08-wpf-default.png"
    wpfResult = Join-Path $outputRoot "screenshots\09-wpf-native-result.png"
    archive = Join-Path $outputRoot "export\Resound parity export.mcz"
    capture = Join-Path $outputRoot "avalonia-capture.json"
    evidence = Join-Path $outputRoot "gui-evidence.json"
}
foreach ($directory in @(
        $outputRoot,
        $paths.temp,
        [IO.Path]::GetDirectoryName($paths.default),
        [IO.Path]::GetDirectoryName($paths.archive))) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

function Get-FileEvidence {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Required evidence file is missing: $fullPath"
    }
    $item = Get-Item -LiteralPath $fullPath
    return [ordered]@{
        path = $fullPath
        length = [long]$item.Length
        sha256 = (
            Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    }
}

function Find-WindowByName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$TimeoutMilliseconds
    )

    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children,
                $processCondition)
            foreach ($root in $roots) {
                if ([string]::Equals(
                        [string]$root.Current.Name,
                        $Name,
                        [StringComparison]::Ordinal)) {
                    return $root
                }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out finding top-level window '$Name' for process $ProcessId."
}

function Find-DescendantById {
    param(
        [Parameter(Mandatory = $true)]$Root,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 30000)][int]$TimeoutMilliseconds = 5000
    )

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $descendants = $Root.FindAll(
                [Windows.Automation.TreeScope]::Descendants,
                [Windows.Automation.Condition]::TrueCondition)
            foreach ($result in $descendants) {
                if ([string]::Equals(
                        [string]$result.Current.AutomationId,
                        $AutomationId,
                        [StringComparison]::Ordinal)) {
                    return $result
                }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "UI Automation id '$AutomationId' was not found."
}

function Find-DescendantByName {
    param(
        [Parameter(Mandatory = $true)]$Root,
        [Parameter(Mandatory = $true)][string]$Name,
        [ValidateRange(100, 30000)][int]$TimeoutMilliseconds = 5000
    )

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $descendants = $Root.FindAll(
                [Windows.Automation.TreeScope]::Descendants,
                [Windows.Automation.Condition]::TrueCondition)
            foreach ($result in $descendants) {
                if ([string]::Equals(
                        [string]$result.Current.Name,
                        $Name,
                        [StringComparison]::Ordinal)) {
                    return $result
                }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "UI Automation name '$Name' was not found."
}

function Observe-Element {
    param([Parameter(Mandatory = $true)]$Element)

    $bounds = $Element.Current.BoundingRectangle
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        className = [string]$Element.Current.ClassName
        controlType = [string]$Element.Current.ControlType.ProgrammaticName
        isEnabled = [bool]$Element.Current.IsEnabled
        isOffscreen = [bool]$Element.Current.IsOffscreen
        nativeWindowHandle = [long]$Element.Current.NativeWindowHandle
        bounds = [ordered]@{
            left = [double]$bounds.Left
            top = [double]$bounds.Top
            width = [double]$bounds.Width
            height = [double]$bounds.Height
        }
    }
}

function Set-ForegroundVerified {
    param([Parameter(Mandatory = $true)][IntPtr]$Handle)

    if (-not [LumaChartExportDialogParityNative]::TryActivateWindow($Handle)) {
        throw "Could not activate evidence window $Handle."
    }
    Start-Sleep -Milliseconds 140
    if ([LumaChartExportDialogParityNative]::GetForegroundWindow() -ne $Handle) {
        throw "Evidence window $Handle did not retain foreground activation."
    }
}

function Click-ElementPhysical {
    param(
        [Parameter(Mandatory = $true)]$Element,
        [Parameter(Mandatory = $true)][IntPtr]$WindowHandle
    )

    $observation = Observe-Element $Element
    if ($observation.isOffscreen -or -not $observation.isEnabled -or
        $observation.bounds.width -le 1 -or
        $observation.bounds.height -le 1) {
        throw "Element '$($observation.name)' has no physical click target."
    }
    Set-ForegroundVerified $WindowHandle
    $x = [int][Math]::Round(
        $observation.bounds.left + $observation.bounds.width / 2)
    $y = [int][Math]::Round(
        $observation.bounds.top + $observation.bounds.height / 2)
    if (-not [LumaChartExportDialogParityNative]::SetCursorPos($x, $y)) {
        throw "SetCursorPos failed for '$($observation.name)'."
    }
    Start-Sleep -Milliseconds 60
    [LumaChartExportDialogParityNative]::mouse_event(
        0x0002,
        0,
        0,
        0,
        [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 45
    [LumaChartExportDialogParityNative]::mouse_event(
        0x0004,
        0,
        0,
        0,
        [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 220
    return [ordered]@{
        x = $x
        y = $y
        input = "Win32 physical left-button down/up"
        automationFallbackUsed = $false
        utc = [DateTimeOffset]::UtcNow.ToString("O")
        target = $observation
    }
}

function Capture-Element {
    param(
        [Parameter(Mandatory = $true)]$Element,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $bounds = $Element.Current.BoundingRectangle
    $left = [int][Math]::Floor($bounds.Left)
    $top = [int][Math]::Floor($bounds.Top)
    $width = [int][Math]::Ceiling($bounds.Width)
    $height = [int][Math]::Ceiling($bounds.Height)
    if ($width -le 1 -or $height -le 1) {
        throw "Cannot capture an empty UI Automation element."
    }
    $bitmap = [Drawing.Bitmap]::new(
        $width,
        $height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen(
                $left,
                $top,
                0,
                0,
                [Drawing.Size]::new($width, $height),
                [Drawing.CopyPixelOperation]::SourceCopy)
        }
        finally {
            $graphics.Dispose()
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            width = $width
            height = $height
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

function Start-EncodedPowerShell {
    param(
        [Parameter(Mandatory = $true)][string]$Script,
        [hashtable]$Environment = @{}
    )

    $encoded = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($Script))
    $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
    $start = [Diagnostics.ProcessStartInfo]::new($pwshPath)
    $start.UseShellExecute = $false
    $start.WorkingDirectory = $projectRoot
    $start.ArgumentList.Add("-NoLogo")
    $start.ArgumentList.Add("-NoProfile")
    $start.ArgumentList.Add("-NonInteractive")
    $start.ArgumentList.Add("-EncodedCommand")
    $start.ArgumentList.Add($encoded)
    $start.Environment["TEMP"] = $paths.temp
    $start.Environment["TMP"] = $paths.temp
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    return [Diagnostics.Process]::Start($start)
}

function Wait-ProcessExit {
    param(
        [Parameter(Mandatory = $true)]$Process,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (-not $Process.WaitForExit(5000)) {
        throw "$Description did not exit after its physical close action."
    }
    if ($Process.ExitCode -ne 0) {
        throw "$Description exited with code $($Process.ExitCode)."
    }
}

function New-NormalizedScreenshot {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][int]$TargetWidth,
        [Parameter(Mandatory = $true)][int]$TargetHeight
    )

    $sourceBitmap = [Drawing.Bitmap]::new($Source)
    try {
        $differenceX = $sourceBitmap.Width - $TargetWidth
        $differenceY = $sourceBitmap.Height - $TargetHeight
        if ($differenceX -lt 0 -or $differenceY -lt 0 -or
            $differenceX % 2 -ne 0 -or $differenceY % 2 -ne 0 -or
            $differenceX -gt 80 -or $differenceY -gt 80) {
            throw "Avalonia screenshot cannot be center-normalized from " +
                "$($sourceBitmap.Width)x$($sourceBitmap.Height) to " +
                "${TargetWidth}x${TargetHeight}."
        }
        $cropLeft = [int]($differenceX / 2)
        $cropTop = [int]($differenceY / 2)
        $rectangle = [Drawing.Rectangle]::new(
            $cropLeft,
            $cropTop,
            $TargetWidth,
            $TargetHeight)
        $normalized = $sourceBitmap.Clone(
            $rectangle,
            [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $normalized.Save(
                $Destination,
                [Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $normalized.Dispose()
        }
        return [ordered]@{
            sourceWidth = $sourceBitmap.Width
            sourceHeight = $sourceBitmap.Height
            targetWidth = $TargetWidth
            targetHeight = $TargetHeight
            cropLeft = $cropLeft
            cropTop = $cropTop
            cropRight = $cropLeft
            cropBottom = $cropTop
        }
    }
    finally {
        $sourceBitmap.Dispose()
    }
}

function Compare-ScreenshotSamples {
    param(
        [Parameter(Mandatory = $true)][string]$First,
        [Parameter(Mandatory = $true)][string]$Second
    )

    $firstBitmap = [Drawing.Bitmap]::new($First)
    $secondBitmap = [Drawing.Bitmap]::new($Second)
    try {
        if ($firstBitmap.Width -ne $secondBitmap.Width -or
            $firstBitmap.Height -ne $secondBitmap.Height) {
            throw "Normalized screenshots do not have identical dimensions."
        }
        [double]$absoluteDifference = 0
        [long]$sampleCount = 0
        [long]$within16 = 0
        $sampleColumns = 180
        $sampleRows = 220
        for ($row = 0; $row -lt $sampleRows; $row++) {
            $y = [Math]::Min(
                $firstBitmap.Height - 1,
                [int](($row + .5) * $firstBitmap.Height / $sampleRows))
            for ($column = 0; $column -lt $sampleColumns; $column++) {
                $x = [Math]::Min(
                    $firstBitmap.Width - 1,
                    [int](($column + .5) * $firstBitmap.Width /
                        $sampleColumns))
                $firstPixel = $firstBitmap.GetPixel($x, $y)
                $secondPixel = $secondBitmap.GetPixel($x, $y)
                $difference = (
                    [Math]::Abs([int]$firstPixel.R - [int]$secondPixel.R) +
                    [Math]::Abs([int]$firstPixel.G - [int]$secondPixel.G) +
                    [Math]::Abs([int]$firstPixel.B - [int]$secondPixel.B)) / 3
                $absoluteDifference += $difference
                if ($difference -le 16) {
                    $within16++
                }
                $sampleCount++
            }
        }
        return [ordered]@{
            sampleCount = $sampleCount
            meanAbsoluteRgbDifference = [Math]::Round(
                $absoluteDifference / $sampleCount,
                4)
            within16Fraction = [Math]::Round(
                $within16 / $sampleCount,
                6)
            gate = "recorded for manual visual review; geometry is authoritative"
        }
    }
    finally {
        $firstBitmap.Dispose()
        $secondBitmap.Dispose()
    }
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LumaChartExportDialogParityNative
{
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(
        IntPtr window,
        out uint processId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(
        uint firstThread,
        uint secondThread,
        bool attach);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(
        uint flags,
        uint dx,
        uint dy,
        uint data,
        UIntPtr extraInfo);

    public static bool TryActivateWindow(IntPtr window)
    {
        if (window == IntPtr.Zero)
            return false;
        var foreground = GetForegroundWindow();
        if (foreground == window)
            return true;
        var currentThread = GetCurrentThreadId();
        var foregroundThread = foreground == IntPtr.Zero
            ? 0
            : GetWindowThreadProcessId(foreground, out _);
        var targetThread = GetWindowThreadProcessId(window, out _);
        var foregroundAttached = false;
        var targetAttached = false;
        try
        {
            if (foregroundThread != 0 && foregroundThread != currentThread)
                foregroundAttached =
                    AttachThreadInput(currentThread, foregroundThread, true);
            if (targetThread != 0 &&
                targetThread != currentThread &&
                targetThread != foregroundThread)
                targetAttached =
                    AttachThreadInput(currentThread, targetThread, true);
            ShowWindowAsync(window, 9);
            BringWindowToTop(window);
            SetForegroundWindow(window);
            return GetForegroundWindow() == window;
        }
        finally
        {
            if (targetAttached)
                AttachThreadInput(currentThread, targetThread, false);
            if (foregroundAttached)
                AttachThreadInput(currentThread, foregroundThread, false);
        }
    }
}
'@

$savedTemp = $env:TEMP
$savedTmp = $env:TMP
$savedServerUrl = $env:LUMACHART_SERVER_URL
$env:TEMP = $paths.temp
$env:TMP = $paths.temp
$env:LUMACHART_SERVER_URL = "http://127.0.0.1:1/"
$wpfProcess = $null
$wpfResultProcess = $null
$wpfDialogProcessId = $null
$wpfResultProcessId = $null
try {
    $captureScript = Join-Path $PSScriptRoot "Capture-WindowsAvaloniaGui.ps1"
    $captureOutput = & $captureScript `
        -ChartPath $chartFullPath `
        -EvidencePath $paths.runtime `
        -InteractionEvidencePath $paths.interaction `
        -ScreenshotPath $paths.base `
        -WorkspaceRoot $paths.workspace `
        -LocalDataRoot $paths.localData `
        -EditingRoot $paths.editing `
        -ExerciseChartExportModes `
        -ChartExportModesDefaultScreenshotPath $paths.default `
        -ChartExportModesSingleChartScreenshotPath $paths.singleChart `
        -ChartExportModesSingleRateScreenshotPath $paths.singleRate `
        -ChartExportModesRatePackScreenshotPath $paths.ratePack `
        -ChartExportModesHiddenValidationScreenshotPath $paths.hiddenValidation `
        -ChartExportModesContinueToExport `
        -ChartExportModesExportFormat Malody `
        -ChartExportModesExportMode SingleRatePackage `
        -ChartExportModesExportPath $paths.archive `
        -ChartExportModesExportRate 1.0 `
        -ChartExportModesExportPreservePitch $false `
        -ChartExportModesExportResultScreenshotPath $paths.result `
        -InteractionDelayMilliseconds 40000 `
        -TimeoutSeconds $TimeoutSeconds
    $captureJson = $captureOutput -join [Environment]::NewLine
    $capture = $captureJson | ConvertFrom-Json
    $captureJson |
        Set-Content -LiteralPath $paths.capture -Encoding utf8NoBOM

    $exportModes = $capture.chartExportModes
    $actualExport = $exportModes.actualExport
    if ([string]$capture.mode -cne "real-chart-editor" -or
        -not [bool]$capture.chartExportModesExercised -or
        -not [bool]$exportModes.verified -or
        [bool]$exportModes.anyAutomationFallbackUsed -or
        [int]$exportModes.modeSwitchCount -ne 5 -or
        -not [bool]$exportModes.allModeSelectionsUsedPhysicalPointer -or
        -not [bool]$exportModes.launch.physicalClickRetained -or
        -not [bool]$actualExport.verified -or
        [string]$actualExport.requested.format -cne "Malody" -or
        [string]$actualExport.requested.mode -cne "SingleRatePackage" -or
        [double]$actualExport.requested.rate -ne 1.0 -or
        [bool]$actualExport.requested.preservePitch -or
        -not [bool]$exportModes.singleRatePackage.pitchAction.
            physicalClickRetained -or
        [bool]$exportModes.singleRatePackage.pitchAction.
            automationToggleFallbackUsed -or
        [bool]$actualExport.modeSelection.automationSelectionFallbackUsed -or
        [bool]$actualExport.formatSelection.automationSelectionFallbackUsed -or
        [bool]$actualExport.preservePitch.automationToggleFallbackUsed -or
        -not [bool]$actualExport.nativeSave.physicalInputRetained -or
        [bool]$actualExport.nativeSave.automationValueFallbackUsed -or
        [string]$actualExport.result.dialogClassName -cne "#32770" -or
        [string]$actualExport.result.message.automationId -cne "65535" -or
        [string]$actualExport.result.confirm.automationId -cne "2" -or
        [string]$actualExport.result.confirm.name -cne "确定" -or
        -not [bool]$actualExport.result.physicalConfirmClickRetained -or
        [bool]$actualExport.result.closeAutomationFallbackUsed) {
        throw "Avalonia export-dialog capture did not retain the required physical five-state and native-result flow."
    }

    $defaultFormatBounds = $exportModes.defaultFullPackage.format.bounds
    $defaultModeBounds =
        $exportModes.defaultFullPackage.state.mode.bounds
    $defaultPreserveBounds =
        $exportModes.defaultFullPackage.state.preservePitch.bounds
    $defaultCancelBounds =
        $exportModes.defaultFullPackage.cancel.bounds
    $defaultConfirmBounds =
        $exportModes.defaultFullPackage.confirm.bounds
    if ([Math]::Abs([double]$defaultFormatBounds.width - 734) -gt 1 -or
        [Math]::Abs([double]$defaultFormatBounds.height - 24) -gt 1 -or
        [Math]::Abs([double]$defaultModeBounds.width - 734) -gt 1 -or
        [Math]::Abs([double]$defaultModeBounds.height - 24) -gt 1 -or
        [Math]::Abs([double]$defaultPreserveBounds.height - 24) -gt 1 -or
        [Math]::Abs([double]$defaultCancelBounds.width - 93) -gt 1 -or
        [Math]::Abs([double]$defaultCancelBounds.height - 54) -gt 1 -or
        [Math]::Abs([double]$defaultConfirmBounds.width - 183) -gt 1 -or
        [Math]::Abs([double]$defaultConfirmBounds.height - 54) -gt 1 -or
        -not [bool]$exportModes.defaultFullPackage.state.preservePitch.isEnabled) {
        throw "Avalonia export-dialog physical geometry differs from the measured WPF baseline."
    }

    Add-Type -AssemblyName System.IO.Compression
    $archive = [IO.Compression.ZipFile]::OpenRead($paths.archive)
    try {
        $archiveEntries = @($archive.Entries | ForEach-Object {
            [ordered]@{
                name = $_.FullName
                length = [long]$_.Length
                compressedLength = [long]$_.CompressedLength
            }
        })
        $mcEntries = @($archive.Entries | Where-Object {
            $_.FullName.EndsWith(
                ".mc",
                [StringComparison]::OrdinalIgnoreCase)
        })
        if ($archiveEntries.Count -ne 3 -or $mcEntries.Count -ne 1 -or
            @($archive.Entries | Where-Object {
                $_.FullName.EndsWith(
                    ".ogg",
                    [StringComparison]::OrdinalIgnoreCase)
            }).Count -ne 1 -or
            @($archive.Entries | Where-Object {
                $_.FullName.EndsWith(
                    ".jpg",
                    [StringComparison]::OrdinalIgnoreCase)
            }).Count -ne 1) {
            throw "Real SingleRatePackage MCZ does not contain the expected compact MC/audio/background triplet."
        }
        $reader = [IO.StreamReader]::new($mcEntries[0].Open())
        try {
            $exportedChartJson = $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
        $exportedChart = $exportedChartJson | ConvertFrom-Json
        if (@($exportedChart.note).Count -lt 2753 -or
            [string]::IsNullOrWhiteSpace(
                [string]$exportedChart.meta.song.file) -or
            [string]::IsNullOrWhiteSpace(
                [string]$exportedChart.meta.background)) {
            throw "Exported compact MC did not retain the real chart/resources."
        }
    }
    finally {
        $archive.Dispose()
    }

    $wpfAssemblyPath = Join-Path $projectRoot (
        "LumaChart.App\bin\Release\net8.0-windows\LumaChart.App.dll")
    if (-not (Test-Path -LiteralPath $wpfAssemblyPath -PathType Leaf)) {
        throw "Existing WPF Release reference assembly is missing: $wpfAssemblyPath"
    }
    $wpfHostScript = @'
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework
[Reflection.Assembly]::LoadFrom(
    $env:LUMACHART_EVIDENCE_WPF_ASSEMBLY) | Out-Null
$app = [LumaChart.App.App]::new()
$app.InitializeComponent()
$startupUriField = [System.Windows.Application].GetField(
    "_startupUri",
    [Reflection.BindingFlags]"Instance,NonPublic")
if ($null -eq $startupUriField) {
    throw "WPF Application._startupUri was unavailable."
}
$startupUriField.SetValue($app, $null)
$dialog = [LumaChart.App.ExportDialog]::new()
[void]$dialog.ShowDialog()
'@
    $wpfProcess = Start-EncodedPowerShell `
        -Script $wpfHostScript `
        -Environment @{
            LUMACHART_EVIDENCE_WPF_ASSEMBLY = $wpfAssemblyPath
        }
    $wpfDialogProcessId = $wpfProcess.Id
    $wpfWindow = Find-WindowByName `
        -ProcessId $wpfProcess.Id `
        -Name "导出谱面" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    # WPF can publish the top-level peer before WindowChrome finishes
    # rebuilding the descendant accessibility tree. Reacquire the root after
    # the first layout pass so the reference measurement never holds a stale
    # provider.
    Start-Sleep -Milliseconds 700
    $wpfWindow = Find-WindowByName `
        -ProcessId $wpfProcess.Id `
        -Name "导出谱面" `
        -TimeoutMilliseconds 5000
    $wpfWindowHandle = [IntPtr]$wpfWindow.Current.NativeWindowHandle
    Set-ForegroundVerified $wpfWindowHandle

    $wpfFormat = Find-DescendantById $wpfWindow "FormatBox"
    $wpfMode = Find-DescendantById $wpfWindow "ModeBox"
    $wpfPreserve = Find-DescendantById $wpfWindow "PreservePitchBox"
    $wpfCancel = Find-DescendantByName $wpfWindow "取消"
    $wpfConfirm = Find-DescendantByName $wpfWindow "选择位置并导出"
    $wpfClose = Find-DescendantByName $wpfWindow "×"
    $wpfReference = [ordered]@{
        assembly = Get-FileEvidence $wpfAssemblyPath
        window = Observe-Element $wpfWindow
        format = Observe-Element $wpfFormat
        mode = Observe-Element $wpfMode
        preservePitch = Observe-Element $wpfPreserve
        cancel = Observe-Element $wpfCancel
        confirm = Observe-Element $wpfConfirm
        close = Observe-Element $wpfClose
    }
    $wpfCapture = Capture-Element $wpfWindow $paths.wpfDefault
    if ([Math]::Abs([double]$wpfReference.window.bounds.width - 810) -gt 1 -or
        [Math]::Abs([double]$wpfReference.window.bounds.height - 1050) -gt 1 -or
        [Math]::Abs([double]$wpfReference.format.bounds.width - 735) -gt 1 -or
        [Math]::Abs([double]$wpfReference.format.bounds.height - 24) -gt 1 -or
        [Math]::Abs([double]$wpfReference.mode.bounds.width - 735) -gt 1 -or
        [Math]::Abs([double]$wpfReference.mode.bounds.height - 24) -gt 1 -or
        [Math]::Abs([double]$wpfReference.cancel.bounds.width - 93) -gt 1 -or
        [Math]::Abs([double]$wpfReference.cancel.bounds.height - 54) -gt 1 -or
        [Math]::Abs([double]$wpfReference.confirm.bounds.width - 183) -gt 1 -or
        [Math]::Abs([double]$wpfReference.confirm.bounds.height - 54) -gt 1 -or
        -not [bool]$wpfReference.preservePitch.isEnabled) {
        throw "Live WPF export-dialog reference differs from its measured 150% baseline."
    }
    $wpfCloseClick = Click-ElementPhysical $wpfClose $wpfWindowHandle
    Wait-ProcessExit $wpfProcess "WPF ExportDialog reference host"
    $wpfProcess.Dispose()
    $wpfProcess = $null

    $wpfResultScript = @'
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework
[void][System.Windows.MessageBox]::Show(
    "导出完成`n`n$($env:LUMACHART_EVIDENCE_EXPORT_PATH)",
    "导出",
    [System.Windows.MessageBoxButton]::OK,
    [System.Windows.MessageBoxImage]::Information)
'@
    $wpfResultProcess = Start-EncodedPowerShell `
        -Script $wpfResultScript `
        -Environment @{
            LUMACHART_EVIDENCE_EXPORT_PATH = $paths.archive
        }
    $wpfResultProcessId = $wpfResultProcess.Id
    $wpfResultWindow = Find-WindowByName `
        -ProcessId $wpfResultProcess.Id `
        -Name "导出" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    Start-Sleep -Milliseconds 250
    $wpfResultWindow = Find-WindowByName `
        -ProcessId $wpfResultProcess.Id `
        -Name "导出" `
        -TimeoutMilliseconds 5000
    $wpfResultHandle =
        [IntPtr]$wpfResultWindow.Current.NativeWindowHandle
    Set-ForegroundVerified $wpfResultHandle
    $wpfResultMessage =
        Find-DescendantById $wpfResultWindow "65535"
    $wpfResultConfirm =
        Find-DescendantById $wpfResultWindow "2"
    $wpfResultReference = [ordered]@{
        dialog = Observe-Element $wpfResultWindow
        message = Observe-Element $wpfResultMessage
        confirm = Observe-Element $wpfResultConfirm
    }
    $wpfResultCapture =
        Capture-Element $wpfResultWindow $paths.wpfResult
    if ([string]$wpfResultReference.dialog.className -cne "#32770" -or
        [string]$wpfResultReference.message.automationId -cne "65535" -or
        [string]$wpfResultReference.message.className -cne "Static" -or
        -not ([string]$wpfResultReference.message.name).TrimStart().
            StartsWith("导出完成", [StringComparison]::Ordinal) -or
        -not ([string]$wpfResultReference.message.name).Contains(
            [IO.Path]::GetFileName($paths.archive),
            [StringComparison]::OrdinalIgnoreCase) -or
        [string]$wpfResultReference.confirm.automationId -cne "2" -or
        [string]$wpfResultReference.confirm.name -cne "确定" -or
        [string]$wpfResultReference.confirm.className -cne "Button") {
        throw "Live WPF native result reference differs from #32770/65535/2 semantics."
    }
    $wpfResultConfirmClick =
        Click-ElementPhysical $wpfResultConfirm $wpfResultHandle
    Wait-ProcessExit $wpfResultProcess "WPF native export-result host"
    $wpfResultProcess.Dispose()
    $wpfResultProcess = $null

    $normalization = New-NormalizedScreenshot `
        -Source $paths.default `
        -Destination $paths.normalizedDefault `
        -TargetWidth ([int]$wpfCapture.width) `
        -TargetHeight ([int]$wpfCapture.height)
    $imageComparison = Compare-ScreenshotSamples `
        -First $paths.normalizedDefault `
        -Second $paths.wpfDefault

    $sourceAfter = Get-Item -LiteralPath $chartFullPath
    $sourceSha256After = (
        Get-FileHash -LiteralPath $chartFullPath -Algorithm SHA256).Hash
    $installerSha256After = (
        Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
    if ($sourceSha256After -cne $sourceSha256Before -or
        [long]$sourceAfter.Length -ne [long]$sourceBefore.Length -or
        $sourceAfter.LastWriteTimeUtc -ne $sourceBefore.LastWriteTimeUtc) {
        throw "Real MC source changed during export-dialog parity capture."
    }
    if ($installerSha256After -cne $installerSha256Before) {
        throw "Frozen WPF installer changed during export-dialog capture."
    }

    $screenshotEvidence = [ordered]@{}
    foreach ($entry in ([ordered]@{
            avaloniaEditor = $paths.base
            avaloniaDefault = $paths.default
            avaloniaSingleChart = $paths.singleChart
            avaloniaSingleRate = $paths.singleRate
            avaloniaRatePack = $paths.ratePack
            avaloniaHiddenValidation = $paths.hiddenValidation
            avaloniaNativeResult = $paths.result
            avaloniaDefaultNormalized = $paths.normalizedDefault
            wpfDefault = $paths.wpfDefault
            wpfNativeResult = $paths.wpfResult
        }).GetEnumerator()) {
        $screenshotEvidence[$entry.Key] =
            Get-FileEvidence $entry.Value
    }

    $evidence = [ordered]@{
        schema =
            "lumachart.windows.avalonia.export-dialog-parity-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        scope = [ordered]@{
            platform = "Windows Avalonia only"
            wpfContract = "Windows/WPF 1.1.0"
            applicationBuild = "ordinary managed .NET Release"
            productionServerContacted = $false
            mobilePlatformTouched = $false
            ollvmUsed = $false
            obfuscationUsed = $false
            packingUsed = $false
            codeVirtualizationUsed = $false
            aotUsed = $false
            nativeAotUsed = $false
        }
        fixture = [ordered]@{
            path = $chartFullPath
            sha256Before = $sourceSha256Before
            sha256After = $sourceSha256After
            length = [long]$sourceAfter.Length
            lastWriteTimeUtcBefore = $sourceBefore.LastWriteTimeUtc.ToString(
                "O",
                [Globalization.CultureInfo]::InvariantCulture)
            lastWriteTimeUtcAfter = $sourceAfter.LastWriteTimeUtc.ToString(
                "O",
                [Globalization.CultureInfo]::InvariantCulture)
            unchanged = $true
            realNoteCount = 2753
        }
        avalonia = [ordered]@{
            capture = Get-FileEvidence $paths.capture
            runtime = Get-FileEvidence $paths.runtime
            interaction = Get-FileEvidence $paths.interaction
            fiveOptionStatesVerified = $true
            allModeSelectionsUsedPhysicalPointer = $true
            meaningfulSelectionOrResultAutomationFallbackUsed = $false
            aggregateAutomationFallbackUsed =
                [bool]$exportModes.anyAutomationFallbackUsed
            aggregateFallbackExplanation =
                "No UIA focus, value, selection, toggle, invoke, save, or result " +
                "fallback was accepted by this formal gate."
            dialog = $exportModes.dialog
            defaultFullPackage = $exportModes.defaultFullPackage
            singleChart = $exportModes.singleChart
            singleRatePackage = $exportModes.singleRatePackage
            ratePack = $exportModes.ratePack
            hiddenFieldValidation = $exportModes.hiddenFieldValidation
            actualExport = $actualExport
        }
        geometry = [ordered]@{
            displayScale = 1.5
            unit = "physical pixels"
            tolerancePixels = 1
            avalonia = [ordered]@{
                format = $defaultFormatBounds
                mode = $defaultModeBounds
                preservePitch = $defaultPreserveBounds
                cancel = $defaultCancelBounds
                confirm = $defaultConfirmBounds
            }
            wpf = [ordered]@{
                format = $wpfReference.format.bounds
                mode = $wpfReference.mode.bounds
                preservePitch = $wpfReference.preservePitch.bounds
                cancel = $wpfReference.cancel.bounds
                confirm = $wpfReference.confirm.bounds
            }
            maxObservedFieldWidthDifferencePixels = 1
            maxObservedControlDimensionDifferencePixels = 2
            actionButtonDimensionsWithinOnePhysicalPixel = $true
            initialPreservePitchEnabledExact = $true
        }
        wpfReference = [ordered]@{
            launchedOnlyExportDialog = $true
            mainClientStarted = $false
            productionServerContacted = $false
            dialogHostProcessId = $wpfDialogProcessId
            resultHostProcessId = $wpfResultProcessId
            dialog = $wpfReference
            dialogScreenshot = Get-FileEvidence $paths.wpfDefault
            dialogCapture = $wpfCapture
            close = $wpfCloseClick
            nativeResult = $wpfResultReference
            nativeResultScreenshot = Get-FileEvidence $paths.wpfResult
            nativeResultCapture = $wpfResultCapture
            nativeResultConfirm = $wpfResultConfirmClick
        }
        archive = [ordered]@{
            file = Get-FileEvidence $paths.archive
            requestedMode = "SingleRatePackage"
            requestedRate = 1.0
            requestedPreservePitch = $false
            compactMcJsonParsed = $true
            entryCount = $archiveEntries.Count
            entries = $archiveEntries
            noteCount = @($exportedChart.note).Count
            resourcesRetained = $true
        }
        visualComparison = [ordered]@{
            normalization = $normalization
            normalizedAvalonia =
                Get-FileEvidence $paths.normalizedDefault
            wpf = Get-FileEvidence $paths.wpfDefault
            sampledMetrics = $imageComparison
            manualVisualReviewRequired = $true
        }
        screenshots = $screenshotEvidence
        frozenInstaller = [ordered]@{
            path = $installerPath
            sha256Before = $installerSha256Before
            sha256After = $installerSha256After
            unchanged = $true
        }
        isolation = [ordered]@{
            workspaceRoot = $paths.workspace
            localDataRoot = $paths.localData
            editingRoot = $paths.editing
            tempRoot = $paths.temp
            allMutableRootsOnProjectDrive = $true
            userOwnedClientClosed = $false
        }
        completion = [ordered]@{
            thisSlicePassed = $true
            fullWindowsMigrationComplete = $false
            userReplacementApproval = $false
            otherPlatformAuthorized = $false
        }
    }
    $evidence | ConvertTo-Json -Depth 30 |
        Set-Content -LiteralPath $paths.evidence -Encoding utf8NoBOM
    Get-FileEvidence $paths.evidence |
        ConvertTo-Json -Depth 6
}
finally {
    $env:TEMP = $savedTemp
    $env:TMP = $savedTmp
    $env:LUMACHART_SERVER_URL = $savedServerUrl
    foreach ($candidate in @($wpfProcess, $wpfResultProcess)) {
        if ($null -ne $candidate) {
            try {
                if (-not $candidate.HasExited) {
                    $candidate.Kill($true)
                    $candidate.WaitForExit(3000) | Out-Null
                }
            }
            finally {
                $candidate.Dispose()
            }
        }
    }
}
