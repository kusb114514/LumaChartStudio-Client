param(
    [string]$ApplicationPath = (
        Join-Path $PSScriptRoot `
            "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(1000, 20000)][int]$FolderCount = 9184,
    [ValidateRange(60, 300)][int]$TimeoutSeconds = 240,
    [switch]$AllowForegroundAutomation
)

$ErrorActionPreference = "Stop"
if (-not $AllowForegroundAutomation) {
    throw "Pass -AllowForegroundAutomation only after the user gives current-turn desktop consent."
}
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia library virtualization GUI capture requires PowerShell Core on Windows."
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartLibraryVirtualizationNative
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
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    private static extern IntPtr GetWindowLongPtr64(IntPtr window, int index);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
    private static extern int GetWindowLong32(IntPtr window, int index);

    public static bool IsTopmost(IntPtr window)
    {
        const int GWL_EXSTYLE = -20;
        const long WS_EX_TOPMOST = 0x00000008L;
        var value = IntPtr.Size == 8
            ? GetWindowLongPtr64(window, GWL_EXSTYLE).ToInt64()
            : GetWindowLong32(window, GWL_EXSTYLE);
        return (value & WS_EX_TOPMOST) != 0;
    }
}
'@

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Resolve-ExistingFile([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "$Label not found: $full"
    return $full
}

function Resolve-NewDirectory([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Output already exists: $full" }
    [IO.Directory]::CreateDirectory($full) | Out-Null
    return $full
}

function Wait-Condition {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Condition,
        [Parameter(Mandatory = $true)][string]$Description,
        [int]$Seconds = $TimeoutSeconds,
        [int]$PollMilliseconds = 75
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try { if (& $Condition) { return } } catch { }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

function Get-Fingerprint([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        bytes = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
}

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 120000)][int]$TimeoutMilliseconds = 10000
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children,
                $processCondition)
            foreach ($root in $roots) {
                if ([string]$root.Current.AutomationId -ceq $AutomationId) {
                    return $root
                }
                $candidate = $root.FindFirst(
                    [Windows.Automation.TreeScope]::Descendants,
                    $idCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Find-ElementByIdAndName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [Parameter(Mandatory = $true)][string]$NameContains,
        [ValidateRange(100, 120000)][int]$TimeoutMilliseconds = 10000
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        $fallback = $null
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children,
                $processCondition)
            foreach ($root in $roots) {
                $matches = $root.FindAll(
                    [Windows.Automation.TreeScope]::Descendants,
                    $idCondition)
                foreach ($match in $matches) {
                    if ([string]$match.Current.Name -like "*$NameContains*") {
                        if ($null -eq $fallback) { $fallback = $match }
                        $bounds = $match.Current.BoundingRectangle
                        if (-not [bool]$match.Current.IsOffscreen -and
                            [bool]$match.Current.IsEnabled -and
                            $bounds.Width -gt 0 -and
                            $bounds.Height -gt 0) {
                            return $match
                        }
                    }
                }
            }
            if ($null -ne $fallback) { return $fallback }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw (
        "Timed out finding UI Automation id '$AutomationId' containing " +
        "'$NameContains' for process $ProcessId.")
}

function Invoke-Element {
    param(
        [Parameter(Mandatory = $true)]
        [Windows.Automation.AutomationElement]$Element
    )
    $pattern = $null
    Assert (
        $Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$pattern)) (
        "Element '$($Element.Current.AutomationId)' does not expose InvokePattern.")
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Get-VisibleElementsById {
    param(
        [Parameter(Mandatory = $true)]
        [Windows.Automation.AutomationElement]$Root,
        [Parameter(Mandatory = $true)][string]$AutomationId
    )
    $condition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    return @($Root.FindAll(
        [Windows.Automation.TreeScope]::Descendants,
        $condition) | Where-Object { -not [bool]$_.Current.IsOffscreen })
}

function Capture-PhysicalWindow([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartLibraryVirtualizationNative+RECT]::new()
    Assert (
        [LumaChartLibraryVirtualizationNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) "GetWindowRect failed."
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    Assert ($width -ge 800 -and $height -ge 500) (
        "Invalid window bounds ${width}x${height}.")
    $bitmap = [Drawing.Bitmap]::new(
        $width,
        $height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen(
                $rectangle.Left,
                $rectangle.Top,
                0,
                0,
                [Drawing.Size]::new($width, $height),
                [Drawing.CopyPixelOperation]::SourceCopy)
        }
        finally { $graphics.Dispose() }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            path = [IO.Path]::GetFullPath($Path)
            bytes = [long](Get-Item -LiteralPath $Path).Length
            width = $width
            height = $height
            sha256 =
                (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
            captureKind = "physical desktop window"
        }
    }
    finally { $bitmap.Dispose() }
}

function Close-WindowWithUia([int]$ProcessId) {
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $window = [Windows.Automation.AutomationElement]::RootElement.FindFirst(
        [Windows.Automation.TreeScope]::Children,
        $processCondition)
    Assert ($null -ne $window) "Application UI Automation root was not found."
    $pattern = $window.GetCurrentPattern(
        [Windows.Automation.WindowPattern]::Pattern)
    ([Windows.Automation.WindowPattern]$pattern).Close()
}

$application = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$output = [IO.Path]::GetFullPath($OutputRoot)
$projectBoundary = $projectRoot.TrimEnd('\') + '\'
Assert (
    $output.StartsWith(
        $projectBoundary,
        [StringComparison]::OrdinalIgnoreCase)) (
    "Output must stay below the project root: $output")
$output = Resolve-NewDirectory $output

$fixtureRoot = Join-Path (
    Join-Path $projectRoot ".codex-temp") (
    "library-virtualization-" + [Guid]::NewGuid().ToString("N"))
$fixtureRoot = [IO.Path]::GetFullPath($fixtureRoot)
$tempBoundary = [IO.Path]::GetFullPath(
    (Join-Path $projectRoot ".codex-temp")).TrimEnd('\') + '\'
Assert (
    $fixtureRoot.StartsWith(
        $tempBoundary,
        [StringComparison]::OrdinalIgnoreCase)) (
    "Fixture root escaped .codex-temp: $fixtureRoot")
$workspace = Join-Path $fixtureRoot "workspace"
$localData = Join-Path $fixtureRoot "local-data"
$editing = Join-Path $fixtureRoot "editing"
$processTemp = Join-Path $fixtureRoot "temp"
foreach ($directory in @($workspace, $localData, $editing, $processTemp)) {
    [IO.Directory]::CreateDirectory($directory) | Out-Null
}

$manifest = [Text.StringBuilder]::new($FolderCount * 96)
$fixtureBytes = 0L
for ($index = 0; $index -lt $FolderCount; $index++) {
    $token = $index.ToString("D5", [Globalization.CultureInfo]::InvariantCulture)
    $relativeFolder = "Song-$token"
    $folder = Join-Path $workspace $relativeFolder
    [IO.Directory]::CreateDirectory($folder) | Out-Null
    $chartName = "chart-$token.mc"
    $chartPath = Join-Path $folder $chartName
    $payload = (
        '{"meta":{"creator":"virtualization","version":"Stress",' +
        '"mode_ext":{"column":4},"song":{"title":"Virtual Chart ' +
        $token + '","artist":"LumaChart"}},"time":[],"note":[]}')
    [IO.File]::WriteAllText(
        $chartPath,
        $payload,
        [Text.UTF8Encoding]::new($false))
    $fixtureBytes += [Text.Encoding]::UTF8.GetByteCount($payload)
    [void]$manifest.Append($relativeFolder)
    [void]$manifest.Append('\')
    [void]$manifest.Append($chartName)
    [void]$manifest.Append('|')
    [void]$manifest.Append($payload)
    [void]$manifest.Append("`n")
}
$sha = [Security.Cryptography.SHA256]::Create()
try {
    $manifestBytes = [Text.Encoding]::UTF8.GetBytes($manifest.ToString())
    $fixtureManifestSha256 = [Convert]::ToHexString(
        $sha.ComputeHash($manifestBytes))
}
finally { $sha.Dispose() }

$installer = Resolve-ExistingFile (
    Join-Path $projectRoot "release\LumaChartStudio-Setup.exe") "frozen installer"
$realMc = Resolve-ExistingFile (
    "D:\osu!\Songs\Resound\0\1781536331.mc") "real MC fixture"
$installerBefore = Get-Fingerprint $installer
$realMcBefore = Get-Fingerprint $realMc
$runtimeEvidencePath = Join-Path $output "runtime-evidence.json"
$guiEvidencePath = Join-Path $output "gui-evidence.json"
$process = $null
$cleanupSucceeded = $false
try {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $application
    $start.WorkingDirectory = Split-Path -Parent $application
    $start.UseShellExecute = $false
    foreach ($argument in @(
            "--evidence-focus-library-virtualization",
            "--evidence-output", $runtimeEvidencePath)) {
        $start.ArgumentList.Add($argument)
    }
    $start.Environment["LUMACHART_PROFILE"] =
        "windows-avalonia-library-virtualization"
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localData
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
    $start.Environment["DOTNET_CLI_HOME"] =
        Join-Path $projectRoot ".codex-dotnet-home"
    $start.Environment["NUGET_PACKAGES"] =
        Join-Path $projectRoot ".codex-nuget-packages"
    $start.Environment["NUGET_HTTP_CACHE_PATH"] =
        Join-Path $projectRoot ".codex-nuget-http-cache"
    $start.Environment["TEMP"] = $processTemp
    $start.Environment["TMP"] = $processTemp
    $startedUtc = [DateTimeOffset]::UtcNow
    $process = [Diagnostics.Process]::Start($start)
    Assert ($null -ne $process) "Failed to start Windows Avalonia client."

    Wait-Condition -Description "Avalonia main window" -Condition {
        $process.Refresh()
        -not $process.HasExited -and
            $process.MainWindowHandle -ne [IntPtr]::Zero
    }
    $handle = $process.MainWindowHandle
    [void][LumaChartLibraryVirtualizationNative]::ShowWindow($handle, 3)
    [void][LumaChartLibraryVirtualizationNative]::SetForegroundWindow($handle)
    $topmostAtStart =
        [LumaChartLibraryVirtualizationNative]::IsTopmost($handle)

    Wait-Condition -Description "library virtualization runtime evidence" -Condition {
        Test-Path -LiteralPath $runtimeEvidencePath -PathType Leaf
    }
    $evidenceReadyUtc = [DateTimeOffset]::UtcNow
    $runtime = Get-Content -LiteralPath $runtimeEvidencePath -Raw |
        ConvertFrom-Json -Depth 30
    $list = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Library.List"
    $listHelpText = [string]$list.Current.HelpText

    $scrollPattern = $list.GetCurrentPattern(
        [Windows.Automation.ScrollPattern]::Pattern)
    $probeItems = @(Get-VisibleElementsById `
        -Root $list `
        -AutomationId "Library.FolderItem")
    $probeNames = @($probeItems | ForEach-Object { [string]$_.Current.Name })
    $folderTitle = [string]$runtime.evidenceExpandedDisplayTitle
    $expandAction = [ordered]@{
        automationId = "Library.FolderExpand"
        name = $folderTitle
        input = "controlled in-process SetExpanded on the current rebound card"
    }
    $targetChart = Find-ElementByIdAndName `
        -ProcessId $process.Id `
        -AutomationId "Library.ChartOpen" `
        -NameContains $folderTitle `
        -TimeoutMilliseconds 5000
    if ([bool]$targetChart.Current.IsOffscreen) {
        $scrollItem = $null
        if ($targetChart.TryGetCurrentPattern(
                [Windows.Automation.ScrollItemPattern]::Pattern,
                [ref]$scrollItem)) {
            ([Windows.Automation.ScrollItemPattern]$scrollItem).ScrollIntoView()
            Start-Sleep -Milliseconds 250
        }
    }
    $targetChartName = [string]$targetChart.Current.Name
    $chartTitle = [regex]::Match(
        $targetChartName,
        'Virtual Chart \d+').Value
    Assert (
        $folderTitle.Length -gt 0 -and
        $folderTitle -ceq $chartTitle) (
        "Recycled GUI action resolved a stale chart: folder='$folderTitle', chart='$chartTitle'.")

    $screenshot = Capture-PhysicalWindow `
        $handle `
        (Join-Path $output "library-virtualization-bottom-expanded.png")
    $topmostBeforeClose =
        [LumaChartLibraryVirtualizationNative]::IsTopmost($handle)

    Assert (
        [string]$runtime.schema -ceq
            "lumachart.windows.avalonia.library-virtualization-runtime.v1") (
        "Runtime evidence schema drifted.")
    Assert (
        [int]$runtime.indexedChartCount -eq $FolderCount -and
        [int]$runtime.indexedFolderCount -eq $FolderCount -and
        [int]$runtime.visibleFolderCount -eq $FolderCount) (
        "Runtime did not load exactly $FolderCount isolated folders/charts.")
    Assert ([bool]$runtime.containerTemplateOwnsStableCard) (
        "Runtime container template did not own a stable card.")
    Assert (-not [bool]$runtime.funcDataTemplateUsed) (
        "Runtime still used a FuncDataTemplate for library cards.")
    Assert (
        [string]$runtime.itemsPanelType -like "*VirtualizingStackPanel*") (
        "Runtime items panel is not a VirtualizingStackPanel.")
    Assert ([int]$runtime.scrollSampleCount -eq 180) (
        "Runtime did not record all 180 scroll samples.")
    Assert ([int]$runtime.maximumRealizedContainerCount -le 64) (
        "Realized container count exceeded 64.")
    Assert ([int]$runtime.uniqueListBoxItemInstances -le 96) (
        "ListBoxItem instance pool exceeded 96.")
    Assert ([int]$runtime.uniqueCardInstances -le 96) (
        "LibraryFolderCard instance pool exceeded 96.")
    Assert ([int]$runtime.staleBindingMismatchCount -eq 0) (
        "A stale recyclable-card binding was observed.")
    Assert (
        [int]$runtime.maximumMaterializedCollapsedChartRows -eq 0) (
        "Collapsed recycled cards retained materialized chart rows.")
    Assert (
        [bool]$runtime.evidenceExpandedBindingMatched -and
        [int]$runtime.evidenceExpandedChartRowCount -eq 1) (
        "Controlled GUI expansion did not match the current rebound folder.")
    Assert ([double]$runtime.scrollSettleMilliseconds.p95 -le 50) (
        "Scroll settle P95 exceeded 50 ms.")
    Assert ([double]$runtime.scrollSettleMilliseconds.p99 -le 100) (
        "Scroll settle P99 exceeded 100 ms.")
    Assert ([double]$runtime.inputQueueDelayMilliseconds.p95 -le 25) (
        "Input queue delay P95 exceeded 25 ms.")
    Assert ([double]$runtime.inputQueueDelayMilliseconds.p99 -le 50) (
        "Input queue delay P99 exceeded 50 ms.")
    Assert (
        [long]$runtime.memory.managedBytesAfter -le 268435456) (
        "Managed memory after probe exceeded 256 MiB.")
    Assert (
        [long]$runtime.memory.workingSetBytesAfter -le 1073741824) (
        "Working set after probe exceeded 1 GiB.")
    Assert ($listHelpText -like "folders=$FolderCount;*stale=0") (
        "Library UIA runtime diagnostics did not match the evidence.")
    Assert (-not $topmostAtStart -and -not $topmostBeforeClose) (
        "Persistent topmost was observed.")

    Close-WindowWithUia $process.Id
    Assert ($process.WaitForExit(15000)) (
        "Avalonia process did not exit after UIA Window close.")
    $processExitCode = $process.ExitCode
    Assert ($processExitCode -eq 0) (
        "Avalonia process exited with code $processExitCode.")

    $installerAfter = Get-Fingerprint $installer
    $realMcAfter = Get-Fingerprint $realMc
    Assert (
        $installerAfter.sha256 -ceq $installerBefore.sha256 -and
        $installerAfter.bytes -eq $installerBefore.bytes) (
        "Frozen installer changed during library virtualization GUI verification.")
    Assert (
        $realMcAfter.sha256 -ceq $realMcBefore.sha256 -and
        $realMcAfter.bytes -eq $realMcBefore.bytes) (
        "Real MC source changed during library virtualization GUI verification.")

    $refreshRate = @(
        Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue |
            ForEach-Object { [int]$_.CurrentRefreshRate } |
            Where-Object { $_ -gt 0 }
    ) | Select-Object -First 1
    $guiEvidence = [ordered]@{
        schema =
            "lumachart.windows.avalonia.library-virtualization-gui.v2"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed-migration-incomplete"
        platform = "Windows Avalonia only"
        process = [ordered]@{
            id = $process.Id
            exitCode = $processExitCode
            applicationPath = $application
            topmostAtStart = $topmostAtStart
            topmostBeforeClose = $topmostBeforeClose
            processToEvidenceMilliseconds =
                [Math]::Round(
                    ($evidenceReadyUtc - $startedUtc).TotalMilliseconds,
                    3)
        }
        input = [ordered]@{
            currentTurnDesktopConsent = $true
            minimumIdleMilliseconds = 3000
            initialIdleMilliseconds =
                $script:WindowsAvaloniaForegroundAutomationIdleMilliseconds
            uiaScrollPatternObserved = ($null -ne $scrollPattern)
            externalScrollIssued = $false
            uiaSetFocusUsed = $false
            uiaInvokeUsed = $false
            uiaInvokeStateChanged = $false
            uiaWindowCloseUsed = $true
            postedTargetPointerMessagesUsed = $false
            win32MouseInputInjectionUsed = $false
            win32KeyboardInputInjectionUsed = $false
            hardwareMouseInputClaimed = $false
            hardwareKeyboardInputClaimed = $false
            enterKeySent = $false
            persistentTopmostUsed = $false
            actions = @($expandAction)
        }
        fixture = [ordered]@{
            kind = "isolated generated valid Malody metadata files"
            folderCount = $FolderCount
            chartCount = $FolderCount
            payloadBytes = $fixtureBytes
            manifestSha256 = $fixtureManifestSha256
            retainedInArtifacts = $false
        }
        runtime = Get-Fingerprint $runtimeEvidencePath
        runtimeSummary = $runtime
        guiRebind = [ordered]@{
            probeVisibleNames = $probeNames
            expandedFolderName = $folderTitle
            materializedChartActionName = $targetChartName
            currentBindingMatched = ($folderTitle -ceq $chartTitle)
            listHelpText = $listHelpText
        }
        display = [ordered]@{
            reportedRefreshRate = $refreshRate
            renderScaling = [double]$runtime.renderScaling
        }
        screenshot = $screenshot
        frozenInputs = [ordered]@{
            installerBefore = $installerBefore
            installerAfter = $installerAfter
            realMcBefore = $realMcBefore
            realMcAfter = $realMcAfter
        }
        remainingGates = @(
            "Complete 214-row WPF parity matrix",
            "Physical 120 Hz and true 4K display gates",
            "Same-machine WPF/Avalonia large-library A/B",
            "Remaining UI, online, format-game, security and installer gates",
            "User manual replacement approval"
        )
    }
    [IO.File]::WriteAllText(
        $guiEvidencePath,
        ($guiEvidence | ConvertTo-Json -Depth 40),
        [Text.UTF8Encoding]::new($false))
    Get-Content -LiteralPath $guiEvidencePath -Raw
}
finally {
    if ($process -and -not $process.HasExited) {
        try {
            Close-WindowWithUia $process.Id
            [void]$process.WaitForExit(5000)
        }
        catch { }
        if (-not $process.HasExited) {
            $process.Kill($true)
            [void]$process.WaitForExit(5000)
        }
    }
    if ($null -ne $process) {
        $process.Dispose()
    }
    if (Test-Path -LiteralPath $fixtureRoot -PathType Container) {
        $resolvedFixtureRoot = [IO.Path]::GetFullPath($fixtureRoot)
        Assert (
            $resolvedFixtureRoot.StartsWith(
                $tempBoundary,
                [StringComparison]::OrdinalIgnoreCase)) (
            "Refusing to clean fixture outside .codex-temp: $resolvedFixtureRoot")
        Remove-Item -LiteralPath $resolvedFixtureRoot -Recurse -Force
    }
    $cleanupSucceeded = -not (Test-Path -LiteralPath $fixtureRoot)
    if (-not $cleanupSucceeded) {
        Write-Warning "Library virtualization fixture cleanup did not complete."
    }
}
