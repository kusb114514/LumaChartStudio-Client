param(
    [Parameter(Mandatory = $true)][string]$ApplicationPath,
    [Parameter(Mandatory = $true)][string]$ScreenshotPath,
    [Parameter(Mandatory = $true)][string]$RegistrationScreenshotPath,
    [Parameter(Mandatory = $true)][string]$ResetScreenshotPath,
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
    [Parameter(Mandatory = $true)][string]$LocalDataRoot,
    [Parameter(Mandatory = $true)][string]$EditingRoot,
    [ValidateRange(10, 90)][int]$TimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia account GUI capture requires PowerShell Core on Windows."
}

function Resolve-NewOutput([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Output already exists: $full" }
    New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($full)) | Out-Null
    return $full
}

$applicationFullPath = [IO.Path]::GetFullPath($ApplicationPath)
if (-not (Test-Path -LiteralPath $applicationFullPath -PathType Leaf)) {
    throw "Avalonia executable not found: $applicationFullPath"
}
$screenshotFullPath = Resolve-NewOutput $ScreenshotPath
$registrationScreenshotFullPath = Resolve-NewOutput $RegistrationScreenshotPath
$resetScreenshotFullPath = Resolve-NewOutput $ResetScreenshotPath
$evidenceFullPath = Resolve-NewOutput $EvidencePath
$workspaceFullPath = [IO.Path]::GetFullPath($WorkspaceRoot)
$localDataFullPath = [IO.Path]::GetFullPath($LocalDataRoot)
$editingFullPath = [IO.Path]::GetFullPath($EditingRoot)
foreach ($directory in @($workspaceFullPath, $localDataFullPath, $editingFullPath)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LumaChartAccountCaptureNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr window, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr window, IntPtr deviceContext, uint flags);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr window, int command);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(
        uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
}
'@

function Find-ElementById {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 90000)][int]$TimeoutMilliseconds
    )
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $idCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::AutomationIdProperty,
        $AutomationId)
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children,
                $processCondition)
            foreach ($root in $roots) {
                if ([string]::Equals(
                        [string]$root.Current.AutomationId,
                        $AutomationId,
                        [StringComparison]::Ordinal)) { return $root }
                $candidate = $root.FindFirst(
                    [Windows.Automation.TreeScope]::Descendants,
                    $idCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 75
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation id '$AutomationId' for process $ProcessId."
}

function Observe-Element($Element) {
    $bounds = $Element.Current.BoundingRectangle
    return [ordered]@{
        automationId = [string]$Element.Current.AutomationId
        name = [string]$Element.Current.Name
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

function Invoke-Element($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose InvokePattern."
    }
    $lastFailure = $null
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        try {
            ([Windows.Automation.InvokePattern]$pattern).Invoke()
            return
        }
        catch {
            $lastFailure = $_.Exception
            Start-Sleep -Milliseconds 150
        }
    }
    throw "InvokePattern failed for '$($Element.Current.AutomationId)': $($lastFailure.Message)"
}

function Click-ElementPhysical($Element, [IntPtr]$WindowHandle) {
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -le 1 -or $bounds.Height -le 1 -or $Element.Current.IsOffscreen) {
        throw "Element '$($Element.Current.AutomationId)' has no physical click target."
    }
    [void][LumaChartAccountCaptureNative]::SetForegroundWindow($WindowHandle)
    Start-Sleep -Milliseconds 120
    $x = [int][Math]::Round($bounds.Left + $bounds.Width / 2)
    $y = [int][Math]::Round($bounds.Top + $bounds.Height / 2)
    if (-not [LumaChartAccountCaptureNative]::SetCursorPos($x, $y)) {
        throw "SetCursorPos failed for '$($Element.Current.AutomationId)'."
    }
    [LumaChartAccountCaptureNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 45
    [LumaChartAccountCaptureNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 180
}

function Capture-Window([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartAccountCaptureNative+RECT]::new()
    if (-not [LumaChartAccountCaptureNative]::GetWindowRect($Handle, [ref]$rectangle)) {
        throw "GetWindowRect failed for $Handle."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    if ($width -lt 400 -or $height -lt 300) {
        throw "Account window has invalid bounds: ${width}x${height}."
    }
    $bitmap = [Drawing.Bitmap]::new(
        $width,
        $height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $dc = $graphics.GetHdc()
            try {
                if (-not [LumaChartAccountCaptureNative]::PrintWindow($Handle, $dc, 2)) {
                    throw "PrintWindow failed for account dialog."
                }
            }
            finally { $graphics.ReleaseHdc($dc) }
        }
        finally { $graphics.Dispose() }

        $colors = [Collections.Generic.HashSet[int]]::new()
        $luminance = [Collections.Generic.List[double]]::new()
        for ($y = 0; $y -lt 16; $y++) {
            $pixelY = [Math]::Min($height - 1, [int](($y + .5) * $height / 16))
            for ($x = 0; $x -lt 16; $x++) {
                $pixelX = [Math]::Min($width - 1, [int](($x + .5) * $width / 16))
                $pixel = $bitmap.GetPixel($pixelX, $pixelY)
                [void]$colors.Add($pixel.ToArgb())
                $luminance.Add(.2126 * $pixel.R + .7152 * $pixel.G + .0722 * $pixel.B)
            }
        }
        $mean = ($luminance | Measure-Object -Average).Average
        $variance = ($luminance | ForEach-Object {
            $difference = $_ - $mean
            $difference * $difference
        } | Measure-Object -Average).Average
        $stdDev = [Math]::Sqrt([double]$variance)
        if ($colors.Count -lt 8 -or $stdDev -lt 1.0) {
            throw "Account screenshot is near-uniform: colors=$($colors.Count); stdDev=$stdDev."
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
        return [ordered]@{
            width = $width
            height = $height
            sampledUniqueColors = $colors.Count
            sampledLuminanceStdDev = $stdDev
        }
    }
    finally { $bitmap.Dispose() }
}

# The user's requested capture protocol keeps Codex out of the rendered desktop.
$foreground = [LumaChartAccountCaptureNative]::GetForegroundWindow()
$controllerMinimized = $false
if ($foreground -ne [IntPtr]::Zero) {
    [uint32]$foregroundProcessId = 0
    [void][LumaChartAccountCaptureNative]::GetWindowThreadProcessId(
        $foreground,
        [ref]$foregroundProcessId)
    try {
        $foregroundProcess = Get-Process -Id $foregroundProcessId -ErrorAction Stop
        if ($foregroundProcess.ProcessName -match "Codex") {
            $controllerMinimized = [LumaChartAccountCaptureNative]::ShowWindowAsync($foreground, 6)
        }
    }
    catch { }
}

$start = [Diagnostics.ProcessStartInfo]::new($applicationFullPath)
$start.UseShellExecute = $false
$start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataFullPath
$start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingFullPath
$start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceFullPath
$process = [Diagnostics.Process]::Start($start)
$dialog = $null
$dialogHandle = [IntPtr]::Zero
try {
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($process.MainWindowHandle -eq [IntPtr]::Zero -and [DateTime]::UtcNow -lt $deadline) {
        if ($process.HasExited) { throw "Avalonia exited before opening its main window." }
        $process.Refresh()
        Start-Sleep -Milliseconds 100
    }
    if ($process.MainWindowHandle -eq [IntPtr]::Zero) { throw "Avalonia main window was unavailable." }

    $accountButton = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Navigation" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $accountButtonBefore = Observe-Element $accountButton
    if (-not $accountButton.Current.IsEnabled) { throw "Account navigation was disabled." }
    Click-ElementPhysical $accountButton $process.MainWindowHandle

    $dialog = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Dialog" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $dialogHandle = [IntPtr]$dialog.Current.NativeWindowHandle
    if ($dialogHandle -ne [IntPtr]::Zero) {
        throw "Account surface unexpectedly opened a separate native window."
    }
    $captureHandle = [IntPtr]$process.MainWindowHandle
    $surfaceLayer = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "Online.SurfaceLayer" `
        -TimeoutMilliseconds 3000
    $accountLayer = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Layer" `
        -TimeoutMilliseconds 3000
    $surfaceLayerBefore = Observe-Element $surfaceLayer
    $accountLayerBefore = Observe-Element $accountLayer
    $dialogBefore = Observe-Element $dialog

    $requiredIds = @(
        "OnlineAccount.Login.Username",
        "OnlineAccount.Login.Password",
        "OnlineAccount.Login.CaptchaImage",
        "OnlineAccount.Login.CaptchaAnswer",
        "OnlineAccount.Login.CaptchaRefresh",
        "OnlineAccount.Login.ResetPassword",
        "OnlineAccount.Login.Submit",
        "OnlineAccount.Login.Register",
        "OnlineAccount.Login.Status")
    $controls = [ordered]@{}
    foreach ($id in $requiredIds) {
        $element = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId $id `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $controls[$id] = Observe-Element $element
    }

    $statusDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $status = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "OnlineAccount.Login.Status" `
            -TimeoutMilliseconds 2000
        $statusName = [string]$status.Current.Name
        if ($statusName -like "请输入用户名、密码和图片中的*") { break }
        Start-Sleep -Milliseconds 150
    } while ([DateTime]::UtcNow -lt $statusDeadline)
    if ($statusName -notlike "请输入用户名、密码和图片中的*") {
        throw "Production captcha did not become ready: '$statusName'."
    }
    $controls["OnlineAccount.Login.Status"] = Observe-Element $status
    Start-Sleep -Milliseconds 300
    $capture = Capture-Window $captureHandle $screenshotFullPath

    # Production captcha challenges enforce the same short refresh throttle as
    # WPF 1.1.0. Keep separate workflows outside that server-side interval.
    Start-Sleep -Milliseconds 3200

    Click-ElementPhysical (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Login.Register" `
        -TimeoutMilliseconds 3000) $captureHandle
    $registrationIds = @(
        "OnlineAccount.Workflow.Title",
        "OnlineAccount.Workflow.Username",
        "OnlineAccount.Workflow.DisplayName",
        "OnlineAccount.Workflow.Email",
        "OnlineAccount.Workflow.CaptchaImage",
        "OnlineAccount.Workflow.CaptchaAnswer",
        "OnlineAccount.Workflow.CaptchaRefresh",
        "OnlineAccount.Workflow.EmailCode",
        "OnlineAccount.Workflow.SendEmailCode",
        "OnlineAccount.Workflow.Password",
        "OnlineAccount.Workflow.PasswordConfirm",
        "OnlineAccount.Workflow.Status",
        "OnlineAccount.Workflow.Cancel",
        "OnlineAccount.Workflow.Submit")
    $registrationControls = [ordered]@{}
    foreach ($id in $registrationIds) {
        $element = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId $id `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $registrationControls[$id] = Observe-Element $element
    }
    $workflowStatus = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Workflow.Status" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $workflowDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([string]$workflowStatus.Current.Name -notlike "请输入图片中的*" -and
           [DateTime]::UtcNow -lt $workflowDeadline) {
        Start-Sleep -Milliseconds 150
        $workflowStatus = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "OnlineAccount.Workflow.Status" `
            -TimeoutMilliseconds 2000
    }
    $registrationStatus = [string]$workflowStatus.Current.Name
    if ($registrationStatus -notlike "请输入图片中的*") {
        throw "Registration captcha did not become ready: '$registrationStatus'."
    }
    $registrationControls["OnlineAccount.Workflow.Status"] = Observe-Element $workflowStatus
    $registrationCapture = Capture-Window $captureHandle $registrationScreenshotFullPath
    Start-Sleep -Milliseconds 3200

    # WPF keeps registration/reset inside the same shell overlay. Physically
    # cancel back to login instead of closing and reopening a native modal.
    Click-ElementPhysical (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Workflow.Cancel" `
        -TimeoutMilliseconds 3000) $captureHandle
    $reopenedLoginStatus = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Login.Status" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $reopenedDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([string]$reopenedLoginStatus.Current.Name -notlike "请输入用户名、密码和图片中的*" -and
           [DateTime]::UtcNow -lt $reopenedDeadline) {
        Start-Sleep -Milliseconds 150
        $reopenedLoginStatus = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "OnlineAccount.Login.Status" `
            -TimeoutMilliseconds 2000
    }
    if ([string]$reopenedLoginStatus.Current.Name -notlike "请输入用户名、密码和图片中的*") {
        throw "Reopened login captcha did not become ready."
    }
    Click-ElementPhysical (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Login.ResetPassword" `
        -TimeoutMilliseconds 3000) $captureHandle
    $resetIds = @(
        "OnlineAccount.Workflow.Title",
        "OnlineAccount.Workflow.Email",
        "OnlineAccount.Workflow.CaptchaImage",
        "OnlineAccount.Workflow.CaptchaAnswer",
        "OnlineAccount.Workflow.CaptchaRefresh",
        "OnlineAccount.Workflow.EmailCode",
        "OnlineAccount.Workflow.SendEmailCode",
        "OnlineAccount.Workflow.Password",
        "OnlineAccount.Workflow.PasswordConfirm",
        "OnlineAccount.Workflow.Status",
        "OnlineAccount.Workflow.Cancel",
        "OnlineAccount.Workflow.Submit")
    $resetControls = [ordered]@{}
    foreach ($id in $resetIds) {
        $element = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId $id `
            -TimeoutMilliseconds ($TimeoutSeconds * 1000)
        $resetControls[$id] = Observe-Element $element
    }
    $resetTitle = [string](Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Workflow.Title" `
        -TimeoutMilliseconds 3000).Current.Name
    if ($resetTitle -ne "找回密码") { throw "Reset workflow title mismatch: '$resetTitle'." }
    $workflowStatus = Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Workflow.Status" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    $workflowDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([string]$workflowStatus.Current.Name -notlike "请输入图片中的*" -and
           [DateTime]::UtcNow -lt $workflowDeadline) {
        Start-Sleep -Milliseconds 150
        $workflowStatus = Find-ElementById `
            -ProcessId $process.Id `
            -AutomationId "OnlineAccount.Workflow.Status" `
            -TimeoutMilliseconds 2000
    }
    $resetStatus = [string]$workflowStatus.Current.Name
    if ($resetStatus -notlike "请输入图片中的*") {
        throw "Reset captcha did not become ready: '$resetStatus'."
    }
    $resetControls["OnlineAccount.Workflow.Status"] = Observe-Element $workflowStatus
    $resetCapture = Capture-Window $captureHandle $resetScreenshotFullPath

    Click-ElementPhysical (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.Workflow.Cancel" `
        -TimeoutMilliseconds 3000) $captureHandle
    Click-ElementPhysical (Find-ElementById `
        -ProcessId $process.Id `
        -AutomationId "OnlineAccount.ContinueOffline" `
        -TimeoutMilliseconds 3000) $captureHandle
    $offlineDeadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 100
        $accountLayerHidden = $surfaceLayer.Current.IsOffscreen
    } while (-not $accountLayerHidden -and [DateTime]::UtcNow -lt $offlineDeadline)
    if (-not $accountLayerHidden) {
        throw "Physical offline action did not close the hosted account layer."
    }

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.account-gui-evidence.v2"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        applicationPath = $applicationFullPath
        applicationSha256 = (Get-FileHash -LiteralPath $applicationFullPath -Algorithm SHA256).Hash
        applicationAssemblySha256 = (Get-FileHash -LiteralPath (
            [IO.Path]::ChangeExtension($applicationFullPath, ".dll")) -Algorithm SHA256).Hash
        processId = $process.Id
        controllerMinimized = $controllerMinimized
        mouseInputUsed = $true
        keyboardInputUsed = $false
        physicalActionCount = 6
        mainWindowHandle = [long]$process.MainWindowHandle
        hostedInMainWindow = $true
        separateNativeWindowCreated = $false
        onlineSurfaceLayerBeforeClose = $surfaceLayerBefore
        accountLayerBeforeClose = $accountLayerBefore
        dialog = $dialogBefore
        accountNavigationBeforeInvoke = $accountButtonBefore
        controls = $controls
        captchaReadyStatus = $statusName
        registration = [ordered]@{
            controls = $registrationControls
            captchaReadyStatus = $registrationStatus
            screenshotPath = $registrationScreenshotFullPath
            screenshotSha256 = (Get-FileHash -LiteralPath $registrationScreenshotFullPath -Algorithm SHA256).Hash
            screenshot = $registrationCapture
        }
        resetPassword = [ordered]@{
            controls = $resetControls
            captchaReadyStatus = $resetStatus
            screenshotPath = $resetScreenshotFullPath
            screenshotSha256 = (Get-FileHash -LiteralPath $resetScreenshotFullPath -Algorithm SHA256).Hash
            screenshot = $resetCapture
        }
        offlineAction = [ordered]@{
            invokedPhysically = $true
            accountLayerHidden = $accountLayerHidden
            sessionTokenExists = (Test-Path -LiteralPath (
                Join-Path $localDataFullPath "online-session.bin"))
        }
        endpoint = "https://api.lumachart.cc/"
        screenshotPath = $screenshotFullPath
        screenshotSha256 = (Get-FileHash -LiteralPath $screenshotFullPath -Algorithm SHA256).Hash
        screenshot = $capture
    }
    $evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $evidenceFullPath -Encoding utf8NoBOM
    $evidence | ConvertTo-Json -Depth 12
}
finally {
    Start-Sleep -Milliseconds 250
    if (-not $process.HasExited) {
        $process.CloseMainWindow() | Out-Null
        if (-not $process.WaitForExit(5000)) {
            $process.Kill($true)
            $process.WaitForExit(5000) | Out-Null
        }
    }
    $process.Dispose()
}
