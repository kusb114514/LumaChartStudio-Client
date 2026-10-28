param(
    [string]$ApplicationPath =
        (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(1, 100)][int]$ExpectedTabCount = 1,
    [ValidateRange(-1, 100)][int]$ExpectedSupportedArchiveCharts = -1,
    [ValidateRange(-1, 100)][int]$ExpectedUnsupportedArchiveCharts = -1,
    [ValidateRange(-1, 100)][int]$ExpectedBrokenArchiveCharts = -1,
    [ValidateSet("Calibrate", "Preserve")][string]$OsuImportMode = "Calibrate",
    [ValidateRange(30, 300)][int]$TimeoutSeconds = 180,
    [switch]$AllowCodexTempEvidenceRoot
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia format-import GUI capture requires PowerShell Core on Windows."
}

$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$artifactsBoundary =
    [IO.Path]::GetFullPath((Join-Path $projectRoot "artifacts")).TrimEnd('\') + '\'
$codexTempBoundary =
    [IO.Path]::GetFullPath((Join-Path $projectRoot ".codex-temp")).TrimEnd('\') + '\'
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot).TrimEnd('\')
$insideArtifacts = ($outputFullPath + '\').StartsWith(
    $artifactsBoundary,
    [StringComparison]::OrdinalIgnoreCase)
$insideCodexTemp = $AllowCodexTempEvidenceRoot -and
    ($outputFullPath + '\').StartsWith(
        $codexTempBoundary,
        [StringComparison]::OrdinalIgnoreCase)
if (-not $insideArtifacts -and -not $insideCodexTemp) {
    throw "Format-import GUI output must stay under an approved project evidence root."
}
if (Test-Path -LiteralPath $outputFullPath) {
    throw "Format-import GUI output root already exists: $outputFullPath"
}

$applicationFullPath = [IO.Path]::GetFullPath($ApplicationPath)
$inputFullPath = [IO.Path]::GetFullPath($InputPath)
if (-not (Test-Path -LiteralPath $applicationFullPath -PathType Leaf)) {
    throw "Avalonia executable not found: $applicationFullPath"
}
if (-not (Test-Path -LiteralPath $inputFullPath -PathType Leaf)) {
    throw "Format input not found: $inputFullPath"
}
$extension = [IO.Path]::GetExtension($inputFullPath).ToLowerInvariant()
if ($extension -notin @(".mc", ".osu", ".mcz", ".osz")) {
    throw "Unsupported format-import GUI input: $extension"
}
$isArchive = $extension -in @(".mcz", ".osz")
$osuChoiceCount = if ($extension -eq ".osu") {
    1
}
elseif ($extension -eq ".osz") {
    $ExpectedTabCount
}
else {
    0
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Wait-Condition {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Condition,
        [Parameter(Mandatory = $true)][string]$Description,
        [int]$Seconds = $TimeoutSeconds,
        [int]$PollMilliseconds = 100
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try {
            $result = & $Condition
            if ($result) { return $result }
        }
        catch { }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "Missing file: $full"
    $item = Get-Item -LiteralPath $full
    [ordered]@{
        path = $full
        length = [long]$item.Length
        lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString("O")
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Capture-Tree([string]$Root) {
    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    @(
        Get-ChildItem -LiteralPath $fullRoot -File -Recurse -Force |
            Sort-Object FullName |
            ForEach-Object {
                [ordered]@{
                    relativePath = [IO.Path]::GetRelativePath(
                        $fullRoot,
                        $_.FullName)
                    length = [long]$_.Length
                    sha256 = (
                        Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
                }
            }
    )
}

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Drawing
if (-not ("LumaChartFormatImportNative" -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartFormatImportNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

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
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(
        uint flags,
        uint dx,
        uint dy,
        uint data,
        UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rect);

    public static void Click(int x, int y)
    {
        if (!SetCursorPos(x, y))
            throw new InvalidOperationException("SetCursorPos failed.");
        mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);
        mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);
    }

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
        var attachedForeground = false;
        var attachedTarget = false;
        try
        {
            if (foregroundThread != 0 && foregroundThread != currentThread)
                attachedForeground =
                    AttachThreadInput(currentThread, foregroundThread, true);
            if (targetThread != 0 &&
                targetThread != currentThread &&
                targetThread != foregroundThread)
                attachedTarget =
                    AttachThreadInput(currentThread, targetThread, true);
            ShowWindowAsync(window, 9);
            BringWindowToTop(window);
            SetForegroundWindow(window);
            return GetForegroundWindow() == window;
        }
        finally
        {
            if (attachedTarget)
                AttachThreadInput(currentThread, targetThread, false);
            if (attachedForeground)
                AttachThreadInput(currentThread, foregroundThread, false);
        }
    }
}
'@
}

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [int]$TimeoutMilliseconds = 10000
    )
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    $processCondition =
        [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::ProcessIdProperty,
            $ProcessId)
    $idCondition =
        [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty,
            $AutomationId)
    do {
        $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
            [Windows.Automation.TreeScope]::Children,
            $processCondition)
        foreach ($root in $roots) {
            if ([string]$root.Current.AutomationId -ceq $AutomationId) {
                return $root
            }
            $match = $root.FindFirst(
                [Windows.Automation.TreeScope]::Descendants,
                $idCondition)
            if ($match) { return $match }
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out finding UIA id '$AutomationId' for PID $ProcessId."
}

function Find-AllElementsById([int]$ProcessId, [string]$AutomationId) {
    $processCondition =
        [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::ProcessIdProperty,
            $ProcessId)
    $idCondition =
        [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty,
            $AutomationId)
    $found = [Collections.Generic.List[object]]::new()
    $seenRuntimeIds =
        [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal)
    $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
        [Windows.Automation.TreeScope]::Children,
        $processCondition)
    foreach ($root in $roots) {
        if ([string]$root.Current.AutomationId -ceq $AutomationId) {
            $rootRuntimeId = $root.GetRuntimeId() -join "."
            if ($seenRuntimeIds.Add($rootRuntimeId)) {
                $found.Add($root)
            }
        }
        foreach ($element in $root.FindAll(
                [Windows.Automation.TreeScope]::Descendants,
                $idCondition)) {
            try {
                $runtimeId = $element.GetRuntimeId() -join "."
                if ($seenRuntimeIds.Add($runtimeId)) {
                    $found.Add($element)
                }
            }
            catch {
                # Ignore a stale peer removed while walking multiple top-level
                # UIA roots for the same installed application process.
            }
        }
    }
    $found.ToArray()
}

function Find-VisibleElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [string]$ExcludedRuntimeId = "",
        [int]$TimeoutMilliseconds = 10000
    )
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        foreach ($element in @(Find-AllElementsById $ProcessId $AutomationId)) {
            try {
                $bounds = $element.Current.BoundingRectangle
                $runtimeId = $element.GetRuntimeId() -join "."
                if (-not $element.Current.IsOffscreen -and
                    $bounds.Width -gt 2 -and
                    $bounds.Height -gt 2 -and
                    ([string]::IsNullOrEmpty($ExcludedRuntimeId) -or
                     $runtimeId -cne $ExcludedRuntimeId)) {
                    return $element
                }
            }
            catch {
                # A just-closed owner-modal may remain briefly in a UIA result
                # collection. Ignore that stale peer and wait for the new window.
            }
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding visible UIA id '$AutomationId' for PID $ProcessId."
}

function Find-VisibleDescendantById {
    param(
        [Parameter(Mandatory = $true)][object]$Root,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [int]$TimeoutMilliseconds = 10000
    )
    $condition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            foreach ($element in $Root.FindAll(
                    [Windows.Automation.TreeScope]::Descendants,
                    $condition)) {
                $bounds = $element.Current.BoundingRectangle
                if (-not $element.Current.IsOffscreen -and
                    $bounds.Width -gt 2 -and $bounds.Height -gt 2) {
                    return $element
                }
            }
        }
        catch {
            # The root is closing; its caller will time out or discover the next
            # owner-modal window instead of clicking a stale global peer.
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding visible descendant UIA id '$AutomationId'."
}

function Observe-Element([object]$Element) {
    $bounds = $Element.Current.BoundingRectangle
    $nativeWindowHandle = Get-UiaNativeWindowHandle $Element
    [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
        controlType = [string]$Element.Current.ControlType.ProgrammaticName
        nativeWindowHandle = $nativeWindowHandle.ToInt64()
        isEnabled = [bool]$Element.Current.IsEnabled
        isOffscreen = [bool]$Element.Current.IsOffscreen
        bounds = [ordered]@{
            left = [double]$bounds.Left
            top = [double]$bounds.Top
            width = [double]$bounds.Width
            height = [double]$bounds.Height
        }
    }
}

function Get-UiaNativeWindowHandle([object]$Element) {
    $raw = [long]$Element.Current.NativeWindowHandle
    if ($raw -eq 0) { return [IntPtr]::Zero }
    # UI Automation exposes NativeWindowHandle as a signed 32-bit integer.
    # HWND values with bit 31 set must be zero-extended before use in a
    # 64-bit PowerShell process.
    [IntPtr]::new($raw -band 0xFFFFFFFFL)
}

function Set-ForegroundVerified([IntPtr]$Window) {
    Assert ($Window -ne [IntPtr]::Zero) "Cannot foreground a zero HWND."
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(5)
    do {
        if ([LumaChartFormatImportNative]::GetForegroundWindow() -eq $Window) {
            return
        }
        [void][LumaChartFormatImportNative]::TryActivateWindow($Window)
        Start-Sleep -Milliseconds 40
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out foregrounding HWND $Window; foreground is " +
        [LumaChartFormatImportNative]::GetForegroundWindow() + "."
}

function Invoke-PhysicalElementClick(
    [object]$Element,
    [IntPtr]$PreferredWindow) {
    $bounds = $Element.Current.BoundingRectangle
    Assert (-not $Element.Current.IsOffscreen -and
        $bounds.Width -gt 2 -and $bounds.Height -gt 2) (
        "Physical target is offscreen or has empty bounds.")
    $window = Get-UiaNativeWindowHandle $Element
    if ($window -eq [IntPtr]::Zero) { $window = $PreferredWindow }
    Assert ($window -ne [IntPtr]::Zero) "Physical target has no window."
    Set-ForegroundVerified $window
    Start-Sleep -Milliseconds 150
    [LumaChartFormatImportNative]::Click(
        [int][Math]::Round($bounds.Left + $bounds.Width / 2),
        [int][Math]::Round($bounds.Top + $bounds.Height / 2))
}

function Capture-Window([IntPtr]$Window, [string]$Path) {
    $rect = [LumaChartFormatImportNative+RECT]::new()
    $capturedBounds = $false
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(2)
    do {
        $capturedBounds =
            [LumaChartFormatImportNative]::GetWindowRect($Window, [ref]$rect)
        if ($capturedBounds) { break }
        Start-Sleep -Milliseconds 50
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    Assert $capturedBounds (
        "GetWindowRect failed for HWND $($Window.ToInt64()).")
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    Assert ($width -gt 100 -and $height -gt 100) "Window capture bounds are invalid."
    $bitmap = [Drawing.Bitmap]::new($width, $height)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen(
                $rect.Left,
                $rect.Top,
                0,
                0,
                [Drawing.Size]::new($width, $height))
        }
        finally { $graphics.Dispose() }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $bitmap.Dispose() }
    File-Evidence $Path
}

$workspaceRoot = Join-Path $outputFullPath "workspace"
$localDataRoot = Join-Path $outputFullPath "local-data"
$editingRoot = Join-Path $outputFullPath "editing"
$tempRoot = Join-Path $outputFullPath "temp"
$runtimePath = Join-Path $outputFullPath "runtime.json"
$archiveDialogScreenshotPath =
    Join-Path $outputFullPath "archive-import-dialog.png"
$finalScreenshotPath = Join-Path $outputFullPath "fresh-import-editor.png"
$inputBefore = File-Evidence $inputFullPath
$installerPath = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$installerBefore = File-Evidence $installerPath
New-Item -ItemType Directory -Path @(
    $outputFullPath
    $workspaceRoot
    $localDataRoot
    $editingRoot
    $tempRoot
) | Out-Null

$start = [Diagnostics.ProcessStartInfo]::new($applicationFullPath)
$start.UseShellExecute = $false
$start.WorkingDirectory = [IO.Path]::GetDirectoryName($applicationFullPath)
$start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceRoot
$start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataRoot
$start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingRoot
$start.Environment["TEMP"] = $tempRoot
$start.Environment["TMP"] = $tempRoot
$start.Environment["LUMACHART_SERVER_URL"] = "http://127.0.0.1:1/"
$start.ArgumentList.Add("--evidence-chart")
$start.ArgumentList.Add($inputFullPath)
$start.ArgumentList.Add("--evidence-output")
$start.ArgumentList.Add($runtimePath)
if ($extension -eq ".osu") {
    $start.ArgumentList.Add("--evidence-osu-import-dialog")
}
$process = [Diagnostics.Process]::Start($start)
$archiveDialogEvidence = $null
$archiveDialogScreenshot = $null
$osuDialogs = [Collections.Generic.List[object]]::new()
$physicalActions = [Collections.Generic.List[string]]::new()
$normalExit = $false
try {
    $mainHandle = Wait-Condition -Description "Avalonia main window handle" -Seconds 30 -Condition {
        $process.Refresh()
        if ($process.HasExited) { throw "Avalonia exited during startup." }
        if ($process.MainWindowHandle -ne 0) {
            return [IntPtr]$process.MainWindowHandle
        }
        $false
    }

    if ($isArchive) {
        $archiveDialog = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "ArchiveImport.Dialog" `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $archiveDialogEvidence = Observe-Element $archiveDialog
        Assert ([string]$archiveDialogEvidence.name -ceq "谱包导入完成") (
            "Unexpected archive-import dialog title.")
        $archiveMessage = Find-VisibleDescendantById `
            -Root $archiveDialog `
            -AutomationId "Dialog.Message" `
            -TimeoutMilliseconds 10000
        $archiveMessageEvidence = Observe-Element $archiveMessage
        $archiveMessageText = [string]$archiveMessageEvidence.name
        if ($ExpectedSupportedArchiveCharts -ge 0) {
            Assert ($archiveMessageText.Contains(
                    "可编辑下落式键音谱面：$ExpectedSupportedArchiveCharts 张",
                    [StringComparison]::Ordinal)) (
                "Archive dialog did not report the expected supported-chart count.")
        }
        if ($ExpectedUnsupportedArchiveCharts -ge 0) {
            Assert ($archiveMessageText.Contains(
                    "已忽略其他游玩模式：$ExpectedUnsupportedArchiveCharts 张",
                    [StringComparison]::Ordinal)) (
                "Archive dialog did not report the expected unsupported-chart count.")
        }
        if ($ExpectedBrokenArchiveCharts -ge 0) {
            Assert ($archiveMessageText.Contains(
                    "无法识别或已损坏：$ExpectedBrokenArchiveCharts 张",
                    [StringComparison]::Ordinal)) (
                "Archive dialog did not report the expected broken-chart count.")
        }
        $archiveDialogEvidence["message"] = $archiveMessageEvidence
        $archiveDialogEvidence["expectedCounts"] = [ordered]@{
            supported = $ExpectedSupportedArchiveCharts
            unsupported = $ExpectedUnsupportedArchiveCharts
            broken = $ExpectedBrokenArchiveCharts
        }
        $archiveWindow = Get-UiaNativeWindowHandle $archiveDialog
        if ($archiveWindow -eq [IntPtr]::Zero) { $archiveWindow = $mainHandle }
        Set-ForegroundVerified $archiveWindow
        Start-Sleep -Milliseconds 250
        $archiveDialogScreenshot =
            Capture-Window $archiveWindow $archiveDialogScreenshotPath
        $open = Find-VisibleDescendantById `
            -Root $archiveDialog `
            -AutomationId "ArchiveImport.Open" `
            -TimeoutMilliseconds 10000
        $archiveDialogEvidence["open"] = Observe-Element $open
        Invoke-PhysicalElementClick $open $archiveWindow
        $physicalActions.Add("archive-import-open-all-supported-charts")
    }

    $previousChoiceRuntimeId = ""
    for ($index = 0; $index -lt $osuChoiceCount; $index++) {
        $choice = Find-VisibleElementById `
            -ProcessId $process.Id `
            -AutomationId "OsuImportMode.Dialog" `
            -ExcludedRuntimeId $previousChoiceRuntimeId `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $choiceEvidence = Observe-Element $choice
        $choiceWindow = Get-UiaNativeWindowHandle $choice
        if ($choiceWindow -eq [IntPtr]::Zero) { $choiceWindow = $mainHandle }
        Set-ForegroundVerified $choiceWindow
        Start-Sleep -Milliseconds 120
        $buttonId = if ($OsuImportMode -eq "Preserve") {
            "OsuImportMode.Preserve"
        } else {
            "OsuImportMode.Calibrate"
        }
        $button = Find-VisibleDescendantById `
            -Root $choice `
            -AutomationId $buttonId `
            -TimeoutMilliseconds 10000
        $choiceEvidence["action"] = Observe-Element $button
        $osuDialogs.Add($choiceEvidence)
        Invoke-PhysicalElementClick $button $choiceWindow
        $physicalActions.Add(
            "osu-import-$($OsuImportMode.ToLowerInvariant())-$($index + 1)")
        $previousChoiceRuntimeId = $choice.GetRuntimeId() -join "."
        Start-Sleep -Milliseconds 120
    }

    $tabs = Wait-Condition -Description "$ExpectedTabCount imported editor tabs" -Seconds $TimeoutSeconds -Condition {
        $candidate = @(Find-AllElementsById $process.Id "Editor.ChartTab")
        if ($candidate.Count -eq $ExpectedTabCount) { return $candidate }
        $false
    }
    [void](Wait-Condition -Description "runtime evidence" -Seconds $TimeoutSeconds -Condition {
        if ((Test-Path -LiteralPath $runtimePath -PathType Leaf) -and
            (Get-Item -LiteralPath $runtimePath).Length -gt 0) {
            return $true
        }
        $false
    })
    Assert (@(Find-AllElementsById $process.Id "ArchiveImport.Dialog").Count -eq 0) (
        "Archive dialog remained open after import.")
    Assert (@(Find-AllElementsById $process.Id "OsuImportMode.Dialog").Count -eq 0) (
        "osu import-mode dialog remained open after import.")
    $tabEvidence = @($tabs | ForEach-Object { Observe-Element $_ })
    $status = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Editor.Status" `
        -TimeoutMilliseconds 10000
    $statusText = [string]$status.Current.Name
    $currentMainHandle = [IntPtr]$process.MainWindowHandle
    if ($currentMainHandle -eq [IntPtr]::Zero) { $currentMainHandle = $mainHandle }
    Set-ForegroundVerified $currentMainHandle
    Start-Sleep -Milliseconds 250
    $finalScreenshot = Capture-Window $currentMainHandle $finalScreenshotPath

    [void]$process.CloseMainWindow()
    if (-not $process.WaitForExit(20000)) {
        throw "Imported Avalonia client did not close normally."
    }
    $processId = $process.Id
    $exitCode = $process.ExitCode
    $normalExit = $exitCode -eq 0
    Assert $normalExit "Imported Avalonia client exit code was $exitCode."

    $inputAfter = File-Evidence $inputFullPath
    $installerAfter = File-Evidence $installerPath
    Assert ($inputBefore.length -eq $inputAfter.length -and
        $inputBefore.sha256 -ceq $inputAfter.sha256 -and
        $inputBefore.lastWriteTimeUtc -ceq $inputAfter.lastWriteTimeUtc) (
        "Format input changed during fresh GUI import.")
    Assert ($installerBefore.sha256 -ceq $installerAfter.sha256) (
        "Frozen WPF installer changed during fresh GUI import.")
    $workspaceTree = Capture-Tree $workspaceRoot
    $runtime = Get-Content -Raw -LiteralPath $runtimePath | ConvertFrom-Json
    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.format-fresh-import-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        windowsAvaloniaOnly = $true
        productionServerMutationPerformed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        foregroundAutomation = [ordered]@{
            initialSystemIdleMilliseconds =
                [long]$script:WindowsAvaloniaForegroundAutomationIdleMilliseconds
            reservedDesktopConsentUsed =
                [bool]$script:WindowsAvaloniaForegroundAutomationReservedDesktopConsentUsed
            heldModifierGatePassed = $true
            persistentTopmostUsed = $false
        }
        physicalMouseInputUsed = $physicalActions.Count -gt 0
        enterKeyUsed = $false
        input = [ordered]@{
            extension = $extension
            archive = $isArchive
            before = $inputBefore
            after = $inputAfter
            unchanged = $true
        }
        process = [ordered]@{
            id = $processId
            normalExit = $normalExit
            exitCode = $exitCode
        }
        archiveDialog = $archiveDialogEvidence
        archiveDialogScreenshot = $archiveDialogScreenshot
        osuImportMode = $OsuImportMode
        osuDialogs = $osuDialogs.ToArray()
        expectedTabCount = $ExpectedTabCount
        tabs = $tabEvidence
        statusText = $statusText
        physicalActions = $physicalActions.ToArray()
        finalScreenshot = $finalScreenshot
        runtime = $runtime
        workspaceTree = $workspaceTree
        immutableInstaller = [ordered]@{
            before = $installerBefore
            after = $installerAfter
        }
        passed = $true
    }
    $evidencePath = Join-Path $outputFullPath "evidence.json"
    $evidence | ConvertTo-Json -Depth 50 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Write-Output "Windows Avalonia format fresh-import GUI capture: passed"
    Write-Output "Evidence: $evidencePath"
}
finally {
    if ($process) {
        try {
            if (-not $process.HasExited) {
                $process.Kill($true)
                [void]$process.WaitForExit(5000)
            }
        }
        catch { }
        finally { $process.Dispose() }
    }
}
