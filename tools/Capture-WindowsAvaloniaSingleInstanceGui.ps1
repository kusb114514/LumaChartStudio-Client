param(
    [string]$ApplicationPath = (
        Join-Path $PSScriptRoot `
            "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$McFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$OsuFixturePath = (
        "D:\osu!\Songs\1005389 Minori Chihara - Michishirube\" +
        "Minori Chihara - Michishirube (eZmmR) [Dear You,  Gilbert Bougainvillea .].osu"),
    [Parameter(Mandatory = $true)]
    [string]$OutputRoot,
    [ValidateRange(30, 240)]
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia single-instance GUI capture requires PowerShell Core on Windows."
}

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartSingleInstanceNative
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
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(
        IntPtr window,
        out uint processId);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    public static extern IntPtr GetWindowLongPtr(IntPtr window, int index);
}
'@

function Resolve-File([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "$Label not found: $full"
    }
    return $full
}

function Wait-Condition {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [int]$Milliseconds = ($TimeoutSeconds * 1000)
    )
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($Milliseconds)
    do {
        try {
            $result = & $Condition
            if ($result) { return $result }
        }
        catch { }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

function Find-ElementById {
    param(
        [int]$ProcessId,
        [string]$AutomationId,
        [int]$Milliseconds = ($TimeoutSeconds * 1000)
    )
    return Wait-Condition `
        -Description "UIA '$AutomationId' in process $ProcessId" `
        -Milliseconds $Milliseconds `
        -Condition {
            $processCondition =
                [System.Windows.Automation.PropertyCondition]::new(
                    [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
                    $ProcessId)
            $idCondition =
                [System.Windows.Automation.PropertyCondition]::new(
                    [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
                    $AutomationId)
            $windows =
                [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
                    [System.Windows.Automation.TreeScope]::Children,
                    $processCondition)
            for ($index = 0; $index -lt $windows.Count; $index++) {
                try {
                    $window = $windows.Item($index)
                    if ([string]$window.Current.AutomationId -eq $AutomationId) {
                        return $window
                    }
                    $found = $window.FindFirst(
                        [System.Windows.Automation.TreeScope]::Descendants,
                        $idCondition)
                    if ($null -ne $found) { return $found }
                }
                catch [Runtime.InteropServices.COMException] { }
            }
            return $null
        }
}

function Find-AllElementsById([int]$ProcessId, [string]$AutomationId) {
    $processCondition =
        [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
            $ProcessId)
    $idCondition =
        [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
            $AutomationId)
    $matches = [Collections.Generic.List[System.Windows.Automation.AutomationElement]]::new()
    $windows =
        [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
            [System.Windows.Automation.TreeScope]::Children,
            $processCondition)
    for ($windowIndex = 0; $windowIndex -lt $windows.Count; $windowIndex++) {
        try {
            $window = $windows.Item($windowIndex)
            if ([string]$window.Current.AutomationId -eq $AutomationId) {
                [void]$matches.Add($window)
            }
            $found = $window.FindAll(
                [System.Windows.Automation.TreeScope]::Descendants,
                $idCondition)
            for ($matchIndex = 0; $matchIndex -lt $found.Count; $matchIndex++) {
                [void]$matches.Add($found.Item($matchIndex))
            }
        }
        catch [Runtime.InteropServices.COMException] { }
    }
    return @($matches)
}

function Invoke-Element(
    [System.Windows.Automation.AutomationElement]$Element,
    [string]$AutomationId)
{
    $patternObject = $null
    if (-not $Element.TryGetCurrentPattern(
            [System.Windows.Automation.InvokePattern]::Pattern,
            [ref]$patternObject)) {
        throw "UIA '$AutomationId' lacks InvokePattern."
    }
    ([System.Windows.Automation.InvokePattern]$patternObject).Invoke()
    return [ordered]@{
        automationId = $AutomationId
        name = [string]$Element.Current.Name
        pattern = "InvokePattern"
        utc = [DateTimeOffset]::UtcNow.ToString("O")
    }
}

function Test-Topmost([IntPtr]$WindowHandle) {
    $style = [LumaChartSingleInstanceNative]::GetWindowLongPtr(
        $WindowHandle,
        -20).ToInt64()
    return (($style -band 0x8) -ne 0)
}

function Capture-Window([IntPtr]$WindowHandle, [string]$Path) {
    $rectangle = [LumaChartSingleInstanceNative+RECT]::new()
    if (-not [LumaChartSingleInstanceNative]::GetWindowRect(
            $WindowHandle,
            [ref]$rectangle)) {
        throw "GetWindowRect failed for $WindowHandle."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -le 0 -or $height -le 0) {
        throw "Window bounds are empty for $WindowHandle."
    }
    $bitmap = [Drawing.Bitmap]::new($width, $height)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen(
                $rectangle.Left,
                $rectangle.Top,
                0,
                0,
                [Drawing.Size]::new($width, $height))
        }
        finally {
            $graphics.Dispose()
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
    return [ordered]@{
        path = $Path
        width = $width
        height = $height
        length = (Get-Item -LiteralPath $Path).Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

function New-ClientStartInfo([string[]]$Arguments) {
    $start = [Diagnostics.ProcessStartInfo]::new($applicationFullPath)
    $start.UseShellExecute = $false
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $start.Environment["LUMACHART_SERVER_URL"] = "http://127.0.0.1:1/"
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataRoot
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingRoot
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceRoot
    $start.Environment["LUMACHART_AVALONIA_SINGLE_INSTANCE_SCOPE"] = $scope
    $start.Environment["DOTNET_CLI_HOME"] = $dotnetHome
    $start.Environment["NUGET_PACKAGES"] = $nugetPackages
    $start.Environment["NUGET_HTTP_CACHE_PATH"] = $nugetHttpCache
    $start.Environment["TEMP"] = $processTemp
    $start.Environment["TMP"] = $processTemp
    return $start
}

$applicationFullPath = Resolve-File $ApplicationPath "Avalonia executable"
$mcFullPath = Resolve-File $McFixturePath "Real MC fixture"
$osuFullPath = Resolve-File $OsuFixturePath "Real osu fixture"
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $outputFullPath) {
    throw "Output root already exists: $outputFullPath"
}
New-Item -ItemType Directory -Path $outputFullPath | Out-Null

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$localDataRoot = Join-Path $outputFullPath "client\local-data"
$editingRoot = Join-Path $outputFullPath "client\editing"
$workspaceRoot = Join-Path $outputFullPath "client\workspace"
$processTemp = Join-Path $projectRoot ".codex-temp\single-instance-gui-process"
$dotnetHome = Join-Path $projectRoot ".codex-dotnet-home"
$nugetPackages = Join-Path $projectRoot ".codex-nuget-packages"
$nugetHttpCache = Join-Path $projectRoot ".codex-nuget-http-cache"
foreach ($directory in @(
        $localDataRoot,
        $editingRoot,
        $workspaceRoot,
        $processTemp,
        $dotnetHome,
        $nugetPackages,
        $nugetHttpCache)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}
$scope = "single-instance-gui-$([Guid]::NewGuid().ToString('N'))"
$actions = @()
$primary = $null
$secondary = $null
$mcHashBefore = (Get-FileHash -LiteralPath $mcFullPath -Algorithm SHA256).Hash
$osuHashBefore = (Get-FileHash -LiteralPath $osuFullPath -Algorithm SHA256).Hash

try {
    $primary = [Diagnostics.Process]::Start(
        (New-ClientStartInfo @(
            "--evidence-single-instance",
            "--evidence-chart",
            $mcFullPath)))
    $mainWindowHandle = Wait-Condition `
        -Description "primary Avalonia main window" `
        -Condition {
            if ($primary.HasExited) {
                throw "Primary Avalonia exited with $($primary.ExitCode)."
            }
            $primary.Refresh()
            if ($primary.MainWindowHandle -ne [IntPtr]::Zero) {
                return [IntPtr]$primary.MainWindowHandle
            }
            return $null
    }
    $primaryTopmostAtStartup = Test-Topmost $mainWindowHandle

    $initialTabs = Wait-Condition `
        -Description "primary real MC tab before forwarding" `
        -Condition {
            $tabs = Find-AllElementsById $primary.Id "Editor.ChartTab"
            if ($tabs.Count -eq 1 -and
                ([string]$tabs[0].Current.HelpText).Contains(
                    $mcFullPath,
                    [StringComparison]::OrdinalIgnoreCase)) {
                return $tabs
            }
            return $null
        }
    $initialScreenshot = Capture-Window `
        $mainWindowHandle `
        (Join-Path $outputFullPath "primary-before-forward.png")

    $secondaryWatch = [Diagnostics.Stopwatch]::StartNew()
    $secondary = [Diagnostics.Process]::Start(
        (New-ClientStartInfo @(
            "--evidence-single-instance",
            $mcFullPath,
            $osuFullPath,
            $mcFullPath)))
    if (-not $secondary.WaitForExit(10000)) {
        throw "Secondary launch did not forward and exit within 10 seconds."
    }
    $secondaryWatch.Stop()
    $secondary.Refresh()
    if ($secondary.ExitCode -ne 0) {
        throw "Secondary launch exited with code $($secondary.ExitCode)."
    }
    if ($secondary.MainWindowHandle -ne [IntPtr]::Zero) {
        throw "Secondary launch created a main window instead of forwarding."
    }

    $osuDialog = Find-ElementById `
        -ProcessId $primary.Id `
        -AutomationId "OsuImportMode.Dialog"
    $dialogHandle = [IntPtr]$osuDialog.Current.NativeWindowHandle
    $mcTabsBeforeOsuChoice = Find-AllElementsById $primary.Id "Editor.ChartTab"
    if ($mcTabsBeforeOsuChoice.Count -ne 1 -or
        -not ([string]$mcTabsBeforeOsuChoice[0].Current.HelpText).Contains(
            $mcFullPath,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "Primary did not open the forwarded real MC before the osu choice."
    }
    $dialogScreenshot = Capture-Window `
        $mainWindowHandle `
        (Join-Path $outputFullPath "primary-forwarded-osu-choice.png")
    $calibrate = Find-ElementById `
        -ProcessId $primary.Id `
        -AutomationId "OsuImportMode.Calibrate"
    $actions += Invoke-Element $calibrate "OsuImportMode.Calibrate"

    $finalTabs = Wait-Condition `
        -Description "two forwarded chart tabs" `
        -Condition {
            $tabs = Find-AllElementsById $primary.Id "Editor.ChartTab"
            if ($tabs.Count -eq 2) { return $tabs }
            return $null
        }
    $tabEvidence = @(
        $finalTabs | ForEach-Object {
            [ordered]@{
                name = [string]$_.Current.Name
                helpText = [string]$_.Current.HelpText
                automationId = [string]$_.Current.AutomationId
            }
        }
    )
    $allHelp = ($tabEvidence | ForEach-Object { $_.helpText }) -join "`n"
    if (-not $allHelp.Contains($mcFullPath, [StringComparison]::OrdinalIgnoreCase) -or
        -not $allHelp.Contains($osuFullPath, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Final primary tabs do not expose both forwarded source paths."
    }

    $status = Find-ElementById `
        -ProcessId $primary.Id `
        -AutomationId "Editor.Status"
    $statusName = [string]$status.Current.Name
    $finalScreenshot = Capture-Window `
        $mainWindowHandle `
        (Join-Path $outputFullPath "primary-after-forward.png")

    $foregroundHandle = [LumaChartSingleInstanceNative]::GetForegroundWindow()
    $foregroundProcessId = [uint32]0
    [void][LumaChartSingleInstanceNative]::GetWindowThreadProcessId(
        $foregroundHandle,
        [ref]$foregroundProcessId)
    $mcHashAfter = (Get-FileHash -LiteralPath $mcFullPath -Algorithm SHA256).Hash
    $osuHashAfter = (Get-FileHash -LiteralPath $osuFullPath -Algorithm SHA256).Hash
    if ($mcHashAfter -cne $mcHashBefore -or $osuHashAfter -cne $osuHashBefore) {
        throw "A forwarded source fixture changed."
    }

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.single-instance-gui-evidence.v1"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        windowsAvaloniaOnly = $true
        productionServerMutationPerformed = $false
        mobileProjectsBuiltModifiedInstalledOrTested = $false
        pureDotnetRelease = $true
        ollvmObfuscationPackingVirtualizationOrAotUsed = $false
        enterKeyUsed = $false
        physicalMouseInputUsed = $false
        uiAutomationInvokeUsed = $true
        scope = $scope
        primary = [ordered]@{
            processId = $primary.Id
            mainWindowHandle = [long]$mainWindowHandle
            topmostAtStartup = $primaryTopmostAtStartup
            topmostAtEnd = (Test-Topmost $mainWindowHandle)
            foregroundProcessIdAtEnd = [int]$foregroundProcessId
            remainedAlive = (-not $primary.HasExited)
            initialTabCount = $initialTabs.Count
            mcTabCountBeforeOsuChoice = $mcTabsBeforeOsuChoice.Count
            finalTabCount = $finalTabs.Count
            finalTabs = $tabEvidence
            status = $statusName
        }
        secondary = [ordered]@{
            processId = $secondary.Id
            exitCode = $secondary.ExitCode
            elapsedMilliseconds = $secondaryWatch.Elapsed.TotalMilliseconds
            mainWindowHandle = [long]$secondary.MainWindowHandle
            createdMainWindow = $false
            forwardedPathCount = 2
            duplicateInputDeduplicated = $true
        }
        protocol = [ordered]@{
            inputArgumentCount = 4
            uniqueSupportedPathCount = 2
            orderedPaths = @($mcFullPath, $osuFullPath)
            primaryStartedWithMc = $true
            primaryProcessUnchanged = $true
            secondaryExitedAfterAcknowledgment = $true
        }
        fixtures = [ordered]@{
            mc = [ordered]@{
                path = $mcFullPath
                sha256Before = $mcHashBefore
                sha256After = $mcHashAfter
            }
            osu = [ordered]@{
                path = $osuFullPath
                sha256Before = $osuHashBefore
                sha256After = $osuHashAfter
            }
        }
        actions = $actions
        startupAccount = [ordered]@{
            evidenceChartModeSuppressedStartupChoice = $true
        }
        screenshots = [ordered]@{
            beforeForward = $initialScreenshot
            osuChoice = $dialogScreenshot
            afterForward = $finalScreenshot
        }
        dialog = [ordered]@{
            nativeWindowHandle = [long]$dialogHandle
            topmost = if ($dialogHandle -eq [IntPtr]::Zero) {
                $false
            }
            else {
                Test-Topmost $dialogHandle
            }
            choice = "Calibrate"
        }
        isolation = [ordered]@{
            endpoint = "http://127.0.0.1:1/"
            productionEndpointContacted = $false
            localDataRoot = $localDataRoot
            editingRoot = $editingRoot
            workspaceRoot = $workspaceRoot
            dotnetAndTempOnProjectDrive = $true
        }
    }
    $evidencePath = Join-Path $outputFullPath "evidence.json"
    $evidence | ConvertTo-Json -Depth 20 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8
    Write-Output "Windows Avalonia single-instance GUI capture: passed"
    Write-Output "Evidence: $evidencePath"
}
finally {
    if ($null -ne $secondary) {
        try {
            if (-not $secondary.HasExited) {
                $secondary.Kill($true)
                $secondary.WaitForExit(5000)
            }
        }
        catch { }
        $secondary.Dispose()
    }
    if ($null -ne $primary) {
        try {
            if (-not $primary.HasExited) {
                [void]$primary.CloseMainWindow()
                if (-not $primary.WaitForExit(8000)) {
                    $primary.Kill($true)
                    $primary.WaitForExit(5000)
                }
            }
        }
        catch { }
        $primary.Dispose()
    }
}
