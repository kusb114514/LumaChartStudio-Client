param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia workspace-safety GUI capture requires PowerShell Core on Windows."
}

function Resolve-ExistingFile([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "$Label not found: $full"
    }
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
        try {
            if (& $Condition) { return }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
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

public static class LumaChartWorkspaceSafetyNative
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
    public static extern bool PrintWindow(IntPtr window, IntPtr deviceContext, uint flags);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool IsWindowEnabled(IntPtr window);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    public static extern IntPtr GetWindowLongPtr(IntPtr window, int index);
}
'@

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 300000)][int]$TimeoutMilliseconds = 10000
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
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
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Try-FindElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [int]$TimeoutMilliseconds = 600
    )
    try {
        return Find-ElementById `
            -ProcessId $ProcessId `
            -AutomationId $AutomationId `
            -TimeoutMilliseconds $TimeoutMilliseconds
    }
    catch {
        return $null
    }
}

function Invoke-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Wait-MainWindowHandle([Diagnostics.Process]$Process) {
    Wait-Condition -Description "main window for process $($Process.Id)" -Condition {
        $Process.Refresh()
        -not $Process.HasExited -and $Process.MainWindowHandle -ne [IntPtr]::Zero
    }
    return $Process.MainWindowHandle
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartWorkspaceSafetyNative+RECT]::new()
    if (-not [LumaChartWorkspaceSafetyNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -le 0 -or $height -le 0) {
        throw "Window rectangle is empty: ${width}x${height}."
    }
    $bitmap = [Drawing.Bitmap]::new($width, $height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $deviceContext = $graphics.GetHdc()
        try {
            if (-not [LumaChartWorkspaceSafetyNative]::PrintWindow(
                    $Handle,
                    $deviceContext,
                    2)) {
                throw "PrintWindow failed for $Handle."
            }
        }
        finally {
            $graphics.ReleaseHdc($deviceContext)
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function Start-Client {
    param(
        [string]$Profile,
        [string]$ChartPath = ""
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $applicationFullPath
    $start.WorkingDirectory = Split-Path -Parent $applicationFullPath
    $start.UseShellExecute = $false
    if (-not [string]::IsNullOrWhiteSpace($ChartPath)) {
        $start.ArgumentList.Add("--evidence-chart")
        $start.ArgumentList.Add($ChartPath)
    }
    $start.Environment["LUMACHART_PROFILE"] = $Profile
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceRoot
    $start.Environment["LUMACHART_ONLINE_ENDPOINT"] = "http://127.0.0.1:1"
    $start.Environment["DOTNET_CLI_HOME"] = $dotnetHome
    $start.Environment["NUGET_PACKAGES"] = $nugetPackages
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
    $start.Environment["TEMP"] = $projectTemp
    $start.Environment["TMP"] = $projectTemp
    $process = [Diagnostics.Process]::Start($start)
    if (-not $process) { throw "Unable to start Windows Avalonia client." }
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

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$fixtureFullPath = Resolve-ExistingFile $ChartFixturePath "Real MC fixture"
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
if (-not (Test-Path -LiteralPath $outputFullPath -PathType Container)) {
    throw "Output root must already exist: $outputFullPath"
}
$guiRoot = Join-Path $outputFullPath "workspace-safety-gui"
if (Test-Path -LiteralPath $guiRoot) {
    throw "GUI output root already exists: $guiRoot"
}

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$projectTemp = Join-Path $projectRoot ".codex-temp"
$dotnetHome = Join-Path $projectRoot ".codex-dotnet-home"
$nugetPackages = Join-Path $projectRoot ".codex-nuget-packages"
$nugetHttpCache = Join-Path $projectRoot ".codex-nuget-http-cache"
$clientRoot = Join-Path $guiRoot "client"
$localDataRoot = Join-Path $clientRoot "local-data"
$editingRoot = Join-Path $clientRoot "editing"
$workspaceRoot = Join-Path $clientRoot "workspace"
$onlineChartRoot = Join-Path $localDataRoot "online-room-documents\retained-room"
$screenshotsRoot = Join-Path $guiRoot "screenshots"
foreach ($directory in @(
        $projectTemp,
        $dotnetHome,
        $nugetPackages,
        $nugetHttpCache,
        $editingRoot,
        $workspaceRoot,
        $onlineChartRoot,
        $screenshotsRoot)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$workingChart = Join-Path $onlineChartRoot "retained.mc"
Copy-Item -LiteralPath $fixtureFullPath -Destination $workingChart
$fixtureHashBefore = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
$workingHashBefore = (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash
$dialogScreenshot = Join-Path $screenshotsRoot "retained-room-close-dialog.png"
$first = $null
$second = $null

try {
    $first = Start-Client -Profile "workspace-safety-first" -ChartPath $workingChart
    [void](Wait-MainWindowHandle $first)
    [void](Find-ElementById `
        -ProcessId $first.Id `
        -AutomationId "Editor.ChartTab.Close" `
        -TimeoutMilliseconds 30000)
    Stop-TrackedClient $first
    $first = $null

    $workspaceManifest = Join-Path $editingRoot "desktop-workspace\workspace.json"
    if (-not (Test-Path -LiteralPath $workspaceManifest -PathType Leaf)) {
        throw "First launch did not persist the desktop workspace."
    }

    $second = Start-Client -Profile "workspace-safety-reopen"
    $mainHandle = Wait-MainWindowHandle $second
    [void][LumaChartWorkspaceSafetyNative]::ShowWindow($mainHandle, 3)
    $offline = Try-FindElementById `
        -ProcessId $second.Id `
        -AutomationId "OnlineAccount.ContinueOffline" `
        -TimeoutMilliseconds 2500
    if ($offline) { Invoke-Element $offline }

    $retainedBadge = Find-ElementById `
        -ProcessId $second.Id `
        -AutomationId "Editor.ChartTab.RetainedBadge" `
        -TimeoutMilliseconds 30000
    $retainedName = [string]$retainedBadge.Current.Name
    $close = Find-ElementById `
        -ProcessId $second.Id `
        -AutomationId "Editor.ChartTab.Close"
    Invoke-Element $close

    $dialog = Find-ElementById `
        -ProcessId $second.Id `
        -AutomationId "PreservedRoomDraftClose.Dialog" `
        -TimeoutMilliseconds 15000
    $dialogHandle = [IntPtr]::new([int64]$dialog.Current.NativeWindowHandle)
    if ($dialogHandle -eq [IntPtr]::Zero) {
        throw "Retained-room close dialog has no native window handle."
    }
    if ([LumaChartWorkspaceSafetyNative]::IsWindowEnabled($mainHandle)) {
        throw "Owner remained enabled while the retained-room close dialog was modal."
    }
    $message = [string](Find-ElementById `
        -ProcessId $second.Id `
        -AutomationId "Dialog.Message").Current.Name
    foreach ($expected in @(
            "只存在持久编辑缓存中",
            "另存到正式谱面目录",
            "明确选择放弃")) {
        if (-not $message.Contains($expected, [StringComparison]::Ordinal)) {
            throw "Retained-room warning is missing '$expected'."
        }
    }
    foreach ($id in @(
            "PreservedRoomDraftClose.SaveAs",
            "PreservedRoomDraftClose.Discard",
            "PreservedRoomDraftClose.Cancel")) {
        [void](Find-ElementById -ProcessId $second.Id -AutomationId $id)
    }
    $extendedStyle = [LumaChartWorkspaceSafetyNative]::GetWindowLongPtr(
        $dialogHandle,
        -20).ToInt64()
    $isTopmost = ($extendedStyle -band 0x8) -ne 0
    if ($isTopmost) {
        throw "Retained-room close dialog unexpectedly has WS_EX_TOPMOST."
    }
    Capture-Window $dialogHandle $dialogScreenshot

    Invoke-Element (Find-ElementById `
        -ProcessId $second.Id `
        -AutomationId "PreservedRoomDraftClose.Cancel")
    Wait-Condition -Description "retained-room dialog cancellation" -Condition {
        -not (Try-FindElementById `
            -ProcessId $second.Id `
            -AutomationId "PreservedRoomDraftClose.Dialog" `
            -TimeoutMilliseconds 150)
    }
    if (-not [LumaChartWorkspaceSafetyNative]::IsWindowEnabled($mainHandle)) {
        throw "Owner did not re-enable after cancelling retained-room close."
    }
    [void](Find-ElementById `
        -ProcessId $second.Id `
        -AutomationId "Editor.ChartTab.RetainedBadge")
    if (-not (Test-Path -LiteralPath $workingChart -PathType Leaf)) {
        throw "Cancelling the close removed the retained source."
    }

    Stop-TrackedClient $second
    $second = $null
    $fixtureHashAfter = (Get-FileHash -LiteralPath $fixtureFullPath -Algorithm SHA256).Hash
    $workingHashAfter = (Get-FileHash -LiteralPath $workingChart -Algorithm SHA256).Hash
    if ($fixtureHashBefore -cne $fixtureHashAfter -or
        $workingHashBefore -cne $workingHashAfter) {
        throw "Retained-room GUI safety check changed an immutable chart."
    }
    $cacheFiles = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $editingRoot "desktop-workspace\documents") `
            -Recurse `
            -File `
            -ErrorAction Stop)
    if ($cacheFiles.Count -eq 0) {
        throw "Retained editing cache disappeared after cancelling close."
    }

    $screenshotItem = Get-Item -LiteralPath $dialogScreenshot
    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.workspace-safety-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("o")
        status = "passed-migration-incomplete"
        windowsAvaloniaOnly = $true
        productionServerMutationPerformed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        ollvmExecutedOrRequired = $false
        fixture = [ordered]@{
            path = $fixtureFullPath
            sha256Before = $fixtureHashBefore
            sha256After = $fixtureHashAfter
            unchanged = $fixtureHashBefore -ceq $fixtureHashAfter
        }
        retainedChart = [ordered]@{
            path = $workingChart
            sha256Before = $workingHashBefore
            sha256After = $workingHashAfter
            unchanged = $workingHashBefore -ceq $workingHashAfter
            badgeName = $retainedName
            editingCacheFileCountAfterCancel = $cacheFiles.Count
        }
        dialog = [ordered]@{
            automationId = "PreservedRoomDraftClose.Dialog"
            ownerDisabledWhileModal = $true
            ownerReenabledAfterCancel = $true
            hasSaveAsDiscardCancel = $true
            message = $message
            wsExTopmost = $isTopmost
            cancelPreservedTabAndCache = $true
        }
        screenshot = [ordered]@{
            path = $screenshotItem.FullName
            length = $screenshotItem.Length
            sha256 = (Get-FileHash -LiteralPath $screenshotItem.FullName -Algorithm SHA256).Hash
        }
        completion = [ordered]@{
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
        }
    }
    $evidencePath = Join-Path $outputFullPath "workspace-safety-gui-evidence.json"
    [IO.File]::WriteAllText(
        $evidencePath,
        ($evidence | ConvertTo-Json -Depth 8),
        [Text.UTF8Encoding]::new($false))
    Write-Host "Windows Avalonia workspace-safety GUI acceptance: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    if ($first) { Stop-TrackedClient $first }
    if ($second) { Stop-TrackedClient $second }
}
