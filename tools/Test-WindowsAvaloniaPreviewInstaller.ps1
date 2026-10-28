param(
    [Parameter(Mandatory = $true)]
    [string]$SetupPath,
    [Parameter(Mandatory = $true)]
    [string]$OutputRoot,
    [string]$UpgradeFromSetupPath,
    [switch]$FormalMigrationAuthority,
    [switch]$ExerciseInstalledGui,
    [switch]$ExerciseInstalledAssociationsGui,
    [switch]$ExerciseRunningClientRepair,
    [string]$InstalledGuiChartPath =
        "D:\osu!\Songs\Resound\0\1781536331.mc",
    [string]$InstalledMczPath =
        "D:\Project\LumaChartStudio\artifacts\windows-avalonia-format-modes-slice-20260729-r1\malody-rate-pack-export\export\Resound 0.8-1.1.mcz",
    [string]$InstalledOsuPath =
        "D:\Project\LumaChartStudio\artifacts\windows-avalonia-format-modes-slice-20260729-r1\osu-single-chart-export\export\Resound.osu",
    [string]$InstalledOszPath =
        "D:\Project\LumaChartStudio\artifacts\windows-avalonia-format-modes-slice-20260729-r1\osu-rate-pack-export\export\Resound 0.8-1.1.osz",
    [ValidateRange(30, 300)]
    [int]$TimeoutSeconds = 120
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia installer verification requires PowerShell Core on Windows."
}
$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$setup = [IO.Path]::GetFullPath($SetupPath)
$upgradeFromSetup = if ([string]::IsNullOrWhiteSpace($UpgradeFromSetupPath)) {
    $null
}
else {
    [IO.Path]::GetFullPath($UpgradeFromSetupPath)
}
$output = [IO.Path]::GetFullPath($OutputRoot)
$artifactsBoundary = [IO.Path]::GetFullPath(
    (Join-Path $projectRoot "artifacts")).TrimEnd('\') + '\'
$frozenWpfInstaller = Join-Path $projectRoot "release\LumaChartStudio-Setup.exe"
$expectedFrozenWpfSha256 =
    "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4"
$previewAppId = "AE886E9E-335F-4F03-B891-75591AC6CB57"
$associationMap = [ordered]@{
    ".mc" = "LumaChartStudio.AvaloniaPreview.mc"
    ".mcz" = "LumaChartStudio.AvaloniaPreview.mcz"
    ".osu" = "LumaChartStudio.AvaloniaPreview.osu"
    ".osz" = "LumaChartStudio.AvaloniaPreview.osz"
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function File-Evidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert (Test-Path -LiteralPath $full -PathType Leaf) "Missing file: $full"
    $item = Get-Item -LiteralPath $full
    [ordered]@{
        path = if ($full.StartsWith(
                $projectRoot + '\',
                [StringComparison]::OrdinalIgnoreCase)) {
            [IO.Path]::GetRelativePath($projectRoot, $full)
        }
        else {
            $full
        }
        length = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

Add-Type -AssemblyName System.Drawing
if (-not ("LumaChartInstallerRunningClientNative" -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartInstallerRunningClientNative
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
        uint attach,
        uint attachTo,
        bool attachInput);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr window);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr window, int command);

    public static bool ActivateAndVerify(IntPtr window, int timeoutMilliseconds)
    {
        if (window == IntPtr.Zero)
            throw new ArgumentException("Window handle is zero.", nameof(window));
        if (timeoutMilliseconds < 1)
            throw new ArgumentOutOfRangeException(nameof(timeoutMilliseconds));

        var deadline = Environment.TickCount64 + timeoutMilliseconds;
        do
        {
            var foreground = GetForegroundWindow();
            if (foreground == window)
                return true;

            var currentThread = GetCurrentThreadId();
            var targetThread = GetWindowThreadProcessId(window, out _);
            var foregroundThread = foreground == IntPtr.Zero
                ? 0
                : GetWindowThreadProcessId(foreground, out _);
            var attachedForeground =
                foregroundThread != 0 &&
                foregroundThread != currentThread &&
                AttachThreadInput(currentThread, foregroundThread, true);
            var attachedTarget =
                targetThread != 0 &&
                targetThread != currentThread &&
                targetThread != foregroundThread &&
                AttachThreadInput(currentThread, targetThread, true);
            try
            {
                ShowWindowAsync(window, 9);
                BringWindowToTop(window);
                SetForegroundWindow(window);
            }
            finally
            {
                if (attachedTarget)
                    AttachThreadInput(currentThread, targetThread, false);
                if (attachedForeground)
                    AttachThreadInput(currentThread, foregroundThread, false);
            }

            System.Threading.Thread.Sleep(25);
        }
        while (Environment.TickCount64 < deadline);

        return GetForegroundWindow() == window;
    }
}
'@
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
        $result = & $Condition
        if ($result) { return $result }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

function Capture-ExistingWindow([IntPtr]$Handle, [string]$Path) {
    $rectangle = [LumaChartInstallerRunningClientNative+RECT]::new()
    Assert ([LumaChartInstallerRunningClientNative]::GetWindowRect(
            $Handle,
            [ref]$rectangle)) (
        "GetWindowRect failed for the isolated installed client.")
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    Assert ($width -ge 1000 -and $height -ge 700) (
        "Isolated installed client bounds are too small: ${width}x${height}.")
    Assert ([LumaChartInstallerRunningClientNative]::ActivateAndVerify(
            $Handle,
            3000)) (
        "The isolated installed client could not become the verified foreground window.")
    Start-Sleep -Milliseconds 250
    Assert ([LumaChartInstallerRunningClientNative]::GetForegroundWindow() -eq
            $Handle) (
        "Foreground ownership changed before the installed-client screenshot.")
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
    File-Evidence $Path
}

function Invoke-HiddenProcess(
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$Label)
{
    $start = [Diagnostics.ProcessStartInfo]::new($FilePath)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    try {
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try { $process.Kill($true) } catch { }
            throw "$Label exceeded $TimeoutSeconds seconds."
        }
        if ($process.ExitCode -ne 0) {
            throw "$Label failed with exit code $($process.ExitCode)."
        }
        return $process.ExitCode
    }
    finally {
        $process.Dispose()
    }
}

function Invoke-HiddenProcessExpectFailure(
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$Label)
{
    $start = [Diagnostics.ProcessStartInfo]::new($FilePath)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $process = $null
    try {
        try {
            $process = [Diagnostics.Process]::Start($start)
        }
        catch {
            return [ordered]@{
                rejected = $true
                processStarted = $false
                exitCode = $null
                failureType = $_.Exception.GetType().FullName
                failureMessage = $_.Exception.Message
            }
        }
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try { $process.Kill($true) } catch { }
            throw "$Label did not reject the invalid package within $TimeoutSeconds seconds."
        }
        Assert ($process.ExitCode -ne 0) (
            "$Label unexpectedly returned success for an invalid package.")
        return [ordered]@{
            rejected = $true
            processStarted = $true
            exitCode = [int]$process.ExitCode
            failureType = "nonzero-exit"
            failureMessage = "$Label returned exit code $($process.ExitCode)."
        }
    }
    finally {
        if ($process) { $process.Dispose() }
    }
}

function Wait-ForegroundAutomationConsent {
    $deadline = [DateTimeOffset]::UtcNow.AddMinutes(10)
    do {
        try {
            . (Join-Path $PSScriptRoot (
                "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1"))
            return [long]$script:WindowsAvaloniaForegroundAutomationIdleMilliseconds
        }
        catch {
            if ($_.Exception.Message -notlike
                "*requires at least 3000 ms of system idle time*") {
                throw
            }
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "No safe three-second foreground-automation idle window appeared within ten minutes."
}

function Invoke-ForegroundCaptureWithRetry(
    [Parameter(Mandatory = $true)][scriptblock]$Action) {
    $deadline = [DateTimeOffset]::UtcNow.AddMinutes(10)
    do {
        $idle = Wait-ForegroundAutomationConsent
        try {
            $captureOutput = @(& $Action)
            return [pscustomobject]@{
                IdleMilliseconds = [long]$idle
                Output = $captureOutput
            }
        }
        catch {
            if ($_.Exception.Message -notlike
                "*requires at least 3000 ms of system idle time*") {
                throw
            }
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw (
        "No race-free three-second foreground-automation idle window " +
        "appeared within ten minutes.")
}

function Get-CurrentUserClassDefault([string]$Extension) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
        "Software\Classes\$Extension")
    try {
        if ($null -eq $key) { return $null }
        return $key.GetValue(
            "",
            $null,
            [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    }
    finally {
        if ($key) { $key.Dispose() }
    }
}

function Test-CurrentUserClassValue([string]$Subkey, [string]$Name) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Subkey)
    try {
        return $null -ne $key -and @($key.GetValueNames()) -contains $Name
    }
    finally {
        if ($key) { $key.Dispose() }
    }
}

function Get-CurrentUserClassCommand([string]$ProgId) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
        "Software\Classes\$ProgId\shell\open\command")
    try {
        if ($null -eq $key) { return $null }
        return [string]$key.GetValue("")
    }
    finally {
        if ($key) { $key.Dispose() }
    }
}

function Invoke-PreviewUninstall([string]$InstallRoot, [string]$LogPath) {
    $uninstaller = Join-Path $InstallRoot "unins000.exe"
    Assert (Test-Path -LiteralPath $uninstaller -PathType Leaf) (
        "Preview uninstaller is missing: $uninstaller")
    Invoke-HiddenProcess $uninstaller @(
        "/VERYSILENT",
        "/NORESTART",
        "/SUPPRESSMSGBOXES",
        "/LOG=$LogPath") "Avalonia preview uninstall"
}

# The recoverable editing cache now lives per user under
# %LOCALAPPDATA%\LumaChart Studio\Avalonia\Editing Cache, which the installer
# never touches. {app}\LumaChart Editing Cache is the legacy location the client
# migrates from on its first launch, so the installer keeps it on uninstall
# (uninsneveruninstall): removing it could discard a session that was never
# migrated. An uninstall is therefore clean when nothing is left, or when only
# that folder is left and it holds no files; the harness then removes the empty
# folder itself. Returns whether the legacy folder had been kept.
$legacyEditingCacheFolder = "LumaChart Editing Cache"
function Remove-UninstalledInstallRoot([string]$InstallRoot, [string]$Label) {
    if (-not (Test-Path -LiteralPath $InstallRoot)) { return $false }
    $remaining = @(Get-ChildItem -LiteralPath $InstallRoot -Force)
    Assert ($remaining.Count -eq 1 -and
        $remaining[0].PSIsContainer -and
        $remaining[0].Name -ceq $legacyEditingCacheFolder) (
        "$Label uninstall left the installation directory.")
    Assert (@(Get-ChildItem -LiteralPath $remaining[0].FullName -Recurse -File -Force).Count -eq 0) (
        "$Label uninstall left files in the legacy editing cache.")
    Remove-Item -LiteralPath $InstallRoot -Recurse -Force
    return $true
}

Assert (Test-Path -LiteralPath $setup -PathType Leaf) (
    "Avalonia preview setup is missing: $setup")
if ($upgradeFromSetup) {
    Assert (Test-Path -LiteralPath $upgradeFromSetup -PathType Leaf) (
        "Avalonia preview upgrade fixture setup is missing: $upgradeFromSetup")
    Assert (-not $upgradeFromSetup.Equals(
            $setup,
            [StringComparison]::OrdinalIgnoreCase)) (
        "UpgradeFromSetupPath must differ from the current setup.")
}
Assert (Test-Path -LiteralPath $frozenWpfInstaller -PathType Leaf) (
    "Frozen WPF installer is missing.")
$requiresForegroundAutomation =
    $ExerciseInstalledGui -or
    $ExerciseInstalledAssociationsGui -or
    $ExerciseRunningClientRepair
if ($requiresForegroundAutomation) {
    Assert ($output.StartsWith(
            $artifactsBoundary,
            [StringComparison]::OrdinalIgnoreCase)) (
        "Installed GUI evidence must use a fresh root under $artifactsBoundary")
    $installedGuiChart = [IO.Path]::GetFullPath($InstalledGuiChartPath)
    Assert (Test-Path -LiteralPath $installedGuiChart -PathType Leaf) (
        "Installed GUI chart fixture is missing: $installedGuiChart")
}
if ($ExerciseInstalledGui) {
    Assert ([IO.Path]::GetExtension($installedGuiChart).ToLowerInvariant() -in
        @(".mc", ".osu")) (
        "Installed GUI smoke requires a real MC or osu chart.")
}
if ($ExerciseInstalledAssociationsGui) {
    Assert ([IO.Path]::GetExtension($installedGuiChart).ToLowerInvariant() -ceq
        ".mc") (
        "Installed association GUI coverage requires an MC chart fixture.")
    $installedAssociationInputs = [ordered]@{
        mc = [ordered]@{
            path = $installedGuiChart
            extension = ".mc"
            expectedTabs = 1
        }
        mcz = [ordered]@{
            path = [IO.Path]::GetFullPath($InstalledMczPath)
            extension = ".mcz"
            expectedTabs = 4
        }
        osu = [ordered]@{
            path = [IO.Path]::GetFullPath($InstalledOsuPath)
            extension = ".osu"
            expectedTabs = 1
        }
        osz = [ordered]@{
            path = [IO.Path]::GetFullPath($InstalledOszPath)
            extension = ".osz"
            expectedTabs = 4
        }
    }
    foreach ($entry in $installedAssociationInputs.GetEnumerator()) {
        Assert (Test-Path -LiteralPath $entry.Value.path -PathType Leaf) (
            "Installed association GUI fixture is missing: $($entry.Value.path)")
        Assert ([IO.Path]::GetExtension(
                $entry.Value.path).ToLowerInvariant() -ceq
            $entry.Value.extension) (
            "Installed association GUI fixture extension differs for $($entry.Key).")
    }
}
if ($requiresForegroundAutomation) {
    Assert ($env:LUMACHART_FOREGROUND_AUTOMATION_CONSENT -ceq
        "USER_CONFIRMED_DESKTOP_AVAILABLE") (
        "Explicit foreground GUI automation consent is required.")
}
Assert (-not (Test-Path -LiteralPath $output)) (
    "Installer evidence output root already exists: $output")
New-Item -ItemType Directory -Path $output | Out-Null
$runtimeTemp = Join-Path $output "temp"
New-Item -ItemType Directory -Path $runtimeTemp | Out-Null
$env:TEMP = $runtimeTemp
$env:TMP = $runtimeTemp

$wpfBefore = File-Evidence $frozenWpfInstaller
Assert ($wpfBefore.sha256 -ceq $expectedFrozenWpfSha256) (
    "Frozen WPF installer hash changed before the smoke.")
$setupEvidence = File-Evidence $setup
$setupVersion = (Get-Item -LiteralPath $setup).VersionInfo
Assert ($setupVersion.FileVersion.Trim() -ceq "1.1.0") (
    "Preview installer FileVersion is not 1.1.0.")
Assert ($setupVersion.ProductVersion.Trim() -ceq "1.1.0") (
    "Preview installer ProductVersion is not 1.1.0.")
$upgradeFromSetupEvidence = if ($upgradeFromSetup) {
    File-Evidence $upgradeFromSetup
}
else {
    $null
}
$upgradeFromSetupVersion = if ($upgradeFromSetup) {
    (Get-Item -LiteralPath $upgradeFromSetup).VersionInfo
}
else {
    $null
}
if ($upgradeFromSetupVersion) {
    $upgradeFixtureVersion = [Version]$upgradeFromSetupVersion.ProductVersion.Trim()
    Assert ($upgradeFixtureVersion -lt [Version]"1.1.0") (
        "Upgrade fixture version must be lower than 1.1.0.")
    Assert ($upgradeFromSetupVersion.FileVersion.Trim() -ceq
        $upgradeFromSetupVersion.ProductVersion.Trim()) (
        "Upgrade fixture setup FileVersion/ProductVersion do not match.")
}

$lifecycleRoot = Join-Path $output "lifecycle"
$lifecycleInstall = Join-Path $lifecycleRoot "installed"
New-Item -ItemType Directory -Path $lifecycleRoot | Out-Null
$lifecycleInstallLog = Join-Path $lifecycleRoot "install.log"
$lifecycleUpgradeLog = Join-Path $lifecycleRoot "upgrade-install.log"
$lifecycleRepairLog = Join-Path $lifecycleRoot "repair-install.log"
$lifecycleUninstallLog = Join-Path $lifecycleRoot "uninstall.log"
$corruptSetupPath = Join-Path $lifecycleRoot "corrupted-current-setup.exe"
# Kept in the legacy editing cache beside the executable: that folder is what
# an older client left its session in, and an upgrade or repair must not destroy
# it before the new client has migrated it to the per-user location.
$upgradeSentinel = Join-Path $lifecycleInstall (
    "$legacyEditingCacheFolder\upgrade-preservation-sentinel.json")
$lifecycleLegacyEditingCacheKept = $false
$associationLegacyEditingCacheKept = $false
$installedGuiEvidence = $null
$runningClientRepairEvidence = $null
$corruptUpgradeEvidence = $null
$lifecycleUninstalled = $false
try {
    $lifecycleInitialSetup = if ($upgradeFromSetup) {
        $upgradeFromSetup
    }
    else {
        $setup
    }
    $lifecycleInstallExitCode = Invoke-HiddenProcess $lifecycleInitialSetup @(
        "/CURRENTUSER",
        "/VERYSILENT",
        "/SP-",
        "/NORESTART",
        "/NOICONS",
        "/SUPPRESSMSGBOXES",
        "/TASKS=",
        "/DIR=$lifecycleInstall",
        "/LOG=$lifecycleInstallLog") "Avalonia preview lifecycle initial install"
    $installedApp = Join-Path $lifecycleInstall "LumaChart.Avalonia.exe"
    Assert (Test-Path -LiteralPath $installedApp -PathType Leaf) (
        "Installed Avalonia executable is missing.")
    $initialInstalledAppEvidence = File-Evidence $installedApp
    $initialInstalledVersion = (Get-Item -LiteralPath $installedApp).VersionInfo
    $installedFileCount = @(
        Get-ChildItem -LiteralPath $lifecycleInstall -Recurse -File).Count
    Assert ($installedFileCount -ge 500) (
        "Installed self-contained payload is unexpectedly small.")
    $expectedInitialProductVersion = if ($upgradeFromSetupVersion) {
        $upgradeFromSetupVersion.ProductVersion.Trim()
    }
    else {
        "1.1.0"
    }
    Assert ($initialInstalledVersion.FileVersion -ceq
            "$expectedInitialProductVersion.0" -and
        $initialInstalledVersion.ProductVersion -ceq
            $expectedInitialProductVersion) (
        "Initially installed Avalonia binary version metadata changed.")
    Assert (Test-Path -LiteralPath (
        Join-Path $lifecycleInstall "README.md") -PathType Leaf) (
        "Installed README.md is missing.")
    Assert (Test-Path -LiteralPath (
        Join-Path $lifecycleInstall "THIRD-PARTY-NOTICES.md") -PathType Leaf) (
        "Installed THIRD-PARTY-NOTICES.md is missing.")
    Assert (Test-Path -LiteralPath (
        Join-Path $lifecycleInstall $legacyEditingCacheFolder) -PathType Container) (
        "The legacy editing-cache folder the client migrates from is missing.")
    $desktopShortcut = Join-Path (
        [Environment]::GetFolderPath("Desktop")) (
        "LumaChart Studio Avalonia Preview.lnk")
    Assert (-not (Test-Path -LiteralPath $desktopShortcut)) (
        "No-icons lifecycle smoke created a desktop shortcut.")
    [ordered]@{
        schema = "lumachart.windows.avalonia.preview-upgrade-sentinel.v1"
        createdUtc = [DateTimeOffset]::UtcNow.ToString("O")
        exactBeat = "17:13/24"
    } | ConvertTo-Json -Compress |
        Set-Content -LiteralPath $upgradeSentinel -Encoding utf8NoBOM
    $upgradeSentinelBefore = File-Evidence $upgradeSentinel
    $lifecycleUpgradeExitCode = $null
    $installedAppAfterUpgrade = $initialInstalledAppEvidence
    $upgradeSentinelAfterUpgrade = $upgradeSentinelBefore
    if ($upgradeFromSetup) {
        $sourceStream = [IO.File]::OpenRead($setup)
        $corruptStream = [IO.File]::Create($corruptSetupPath)
        try {
            $corruptBytes = [byte[]]::new(
                [Math]::Min(4096, [int]$sourceStream.Length))
            $corruptByteCount = $sourceStream.Read(
                $corruptBytes,
                0,
                $corruptBytes.Length)
            $corruptStream.Write($corruptBytes, 0, $corruptByteCount)
            $corruptStream.Flush($true)
        }
        finally {
            $corruptStream.Dispose()
            $sourceStream.Dispose()
        }
        $corruptSetupEvidence = File-Evidence $corruptSetupPath
        Assert ($corruptSetupEvidence.length -lt $setupEvidence.length -and
            $corruptSetupEvidence.sha256 -cne $setupEvidence.sha256) (
            "Generated invalid upgrade package is not a distinct truncation.")
        $installedAppBeforeCorruptUpgrade = File-Evidence $installedApp
        $sentinelBeforeCorruptUpgrade = File-Evidence $upgradeSentinel
        $corruptRejection = Invoke-HiddenProcessExpectFailure (
            $corruptSetupPath) @(
            "/CURRENTUSER",
            "/VERYSILENT",
            "/SP-",
            "/NORESTART",
            "/NOICONS",
            "/SUPPRESSMSGBOXES",
            "/TASKS=",
            "/DIR=$lifecycleInstall") (
            "Avalonia preview corrupted higher-version upgrade")
        Start-Sleep -Milliseconds 300
        $installedAppAfterCorruptUpgrade = File-Evidence $installedApp
        $sentinelAfterCorruptUpgrade = File-Evidence $upgradeSentinel
        $versionAfterCorruptUpgrade =
            (Get-Item -LiteralPath $installedApp).VersionInfo
        Assert ($corruptRejection.rejected -eq $true) (
            "Corrupted higher-version setup was not rejected.")
        Assert ($installedAppAfterCorruptUpgrade.sha256 -ceq
            $installedAppBeforeCorruptUpgrade.sha256) (
            "Rejected corrupted upgrade changed the installed application.")
        Assert ($sentinelAfterCorruptUpgrade.sha256 -ceq
            $sentinelBeforeCorruptUpgrade.sha256) (
            "Rejected corrupted upgrade changed the recoverable editing cache.")
        Assert ($versionAfterCorruptUpgrade.ProductVersion -ceq
            $upgradeFromSetupVersion.ProductVersion.Trim()) (
            "Rejected corrupted upgrade changed the installed version.")
        $corruptUpgradeEvidence = [ordered]@{
            generatedTruncatedPackage = $corruptSetupEvidence
            validCurrentPackage = $setupEvidence
            rejection = $corruptRejection
            installedAppBefore = $installedAppBeforeCorruptUpgrade
            installedAppAfter = $installedAppAfterCorruptUpgrade
            installedVersionAfter =
                $versionAfterCorruptUpgrade.ProductVersion
            editingCacheBefore = $sentinelBeforeCorruptUpgrade
            editingCacheAfter = $sentinelAfterCorruptUpgrade
            installedAppUnchanged = $true
            editingCacheUnchanged = $true
            oldVersionPreserved = $true
        }
        $lifecycleUpgradeExitCode = Invoke-HiddenProcess $setup @(
            "/CURRENTUSER",
            "/VERYSILENT",
            "/SP-",
            "/NORESTART",
            "/NOICONS",
            "/SUPPRESSMSGBOXES",
            "/TASKS=",
            "/DIR=$lifecycleInstall",
            "/LOG=$lifecycleUpgradeLog") "Avalonia preview higher-version upgrade install"
        $installedAppAfterUpgrade = File-Evidence $installedApp
        $installedVersionAfterUpgrade =
            (Get-Item -LiteralPath $installedApp).VersionInfo
        $upgradeSentinelAfterUpgrade = File-Evidence $upgradeSentinel
        Assert ($installedVersionAfterUpgrade.FileVersion -ceq "1.1.0.0" -and
            $installedVersionAfterUpgrade.ProductVersion -ceq "1.1.0") (
            "Higher-version upgrade did not install the 1.1.0 application.")
        Assert ($installedAppAfterUpgrade.sha256 -cne
            $initialInstalledAppEvidence.sha256) (
            "Higher-version upgrade did not replace the old application binary.")
        Assert ($upgradeSentinelAfterUpgrade.sha256 -ceq
            $upgradeSentinelBefore.sha256) (
            "Higher-version upgrade discarded the recoverable editing-cache sentinel.")
    }
    $installedAppEvidence = $installedAppAfterUpgrade
    $installedVersion = (Get-Item -LiteralPath $installedApp).VersionInfo
    if ($ExerciseInstalledGui) {
        $installedGuiRoot = Join-Path $output "installed-gui"
        $installedGuiRuntimePath = Join-Path $installedGuiRoot "runtime-evidence.json"
        $installedGuiScreenshotPath = Join-Path $installedGuiRoot "editor.png"
        $installedGuiCaptureRunPath =
            Join-Path $installedGuiRoot "capture-run.log"
        $installedGuiSourceBefore = File-Evidence $installedGuiChart
        $installedGuiCapture = Invoke-ForegroundCaptureWithRetry {
            & (Join-Path $PSScriptRoot "Capture-WindowsAvaloniaGui.ps1") `
                -ApplicationExecutablePath $installedApp `
                -ChartPath $installedGuiChart `
                -EvidencePath $installedGuiRuntimePath `
                -ScreenshotPath $installedGuiScreenshotPath `
                -WorkspaceRoot (Join-Path $installedGuiRoot "workspace") `
                -LocalDataRoot (Join-Path $installedGuiRoot "local-data") `
                -EditingRoot (Join-Path $installedGuiRoot "editing") `
                -InteractionDelayMilliseconds 1800 `
                -TimeoutSeconds ([Math]::Min($TimeoutSeconds, 120))
        }
        $installedGuiCapture.Output |
            Set-Content -LiteralPath $installedGuiCaptureRunPath -Encoding utf8NoBOM
        Assert (Test-Path -LiteralPath $installedGuiRuntimePath -PathType Leaf) (
            "Installed Avalonia runtime evidence is missing.")
        Assert (Test-Path -LiteralPath $installedGuiScreenshotPath -PathType Leaf) (
            "Installed Avalonia GUI screenshot is missing.")
        $installedGuiRuntime = Get-Content -LiteralPath $installedGuiRuntimePath -Raw |
            ConvertFrom-Json -Depth 100
        $installedGuiCaptureReport =
            Get-Content -LiteralPath $installedGuiCaptureRunPath -Raw |
                ConvertFrom-Json -Depth 100
        Assert ($installedGuiRuntime.schema -like
                "lumachart.windows.avalonia.gui-evidence.v*" -and
            [IO.Path]::GetFullPath(
                [string]$installedGuiRuntime.chart.sourcePath) -ceq
                $installedGuiChart -and
            [long]$installedGuiRuntime.chart.structure.noteCount -gt 0 -and
            $installedGuiCaptureReport.mode -ceq "real-chart-editor" -and
            [IO.Path]::GetFullPath(
                [string]$installedGuiCaptureReport.chartPath) -ceq
                $installedGuiChart -and
            [long]$installedGuiCaptureReport.screenshotWidth -ge 1000 -and
            [long]$installedGuiCaptureReport.screenshotHeight -ge 700 -and
            [long]$installedGuiCaptureReport.screenshotSampledUniqueColors -ge
                [long]$installedGuiCaptureReport.screenshotMinimumSampleColors -and
            [double]$installedGuiCaptureReport.screenshotSampledLuminanceStdDev -ge
                [double]$installedGuiCaptureReport.screenshotMinimumLuminanceStdDev) (
            "Installed Avalonia real-chart runtime or screenshot evidence did not pass.")
        $installedGuiSourceAfter = File-Evidence $installedGuiChart
        Assert ($installedGuiSourceAfter.sha256 -ceq $installedGuiSourceBefore.sha256) (
            "Installed GUI smoke changed the real chart fixture.")
        $installedGuiEvidence = [ordered]@{
            chartBefore = $installedGuiSourceBefore
            chartAfter = $installedGuiSourceAfter
            runtimeEvidence = File-Evidence $installedGuiRuntimePath
            screenshot = File-Evidence $installedGuiScreenshotPath
            runtimeStatus = "passed"
            runtimeMode = [string]$installedGuiCaptureReport.mode
            sourceUnchanged = $true
            idleMillisecondsBeforeCapture =
                $installedGuiCapture.IdleMilliseconds
            captureRun = File-Evidence $installedGuiCaptureRunPath
            captureMode = [string]$installedGuiCaptureReport.mode
        }
    }
    $repairSentinelBefore = File-Evidence $upgradeSentinel
    if ($ExerciseRunningClientRepair) {
        $runningRoot = Join-Path $output "running-client-repair"
        $runningWorkspace = Join-Path $runningRoot "workspace-before"
        $runningLocalData = Join-Path $runningRoot "local-data-before"
        $runningEditing = Join-Path $runningRoot "editing-before"
        $runningTemp = Join-Path $runningRoot "temp-before"
        $runningRuntimePath = Join-Path $runningRoot "runtime-before.json"
        $runningShutdownPath = $runningRuntimePath + ".shutdown.json"
        $runningScreenshotPath = Join-Path $runningRoot "before-repair.png"
        New-Item -ItemType Directory -Path @(
            $runningRoot
            $runningWorkspace
            $runningLocalData
            $runningEditing
            $runningTemp
        ) | Out-Null
        $runningSourceBefore = File-Evidence $installedGuiChart
        $runningAppBefore = File-Evidence $installedApp
        $runningSentinelBefore = File-Evidence $upgradeSentinel
        $start = [Diagnostics.ProcessStartInfo]::new($installedApp)
        $start.UseShellExecute = $false
        $start.WorkingDirectory = $lifecycleInstall
        $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] =
            $runningWorkspace
        $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] =
            $runningLocalData
        $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] =
            $runningEditing
        $start.Environment["LUMACHART_SERVER_URL"] = "http://127.0.0.1:1/"
        $start.Environment["TEMP"] = $runningTemp
        $start.Environment["TMP"] = $runningTemp
        $start.ArgumentList.Add("--evidence-chart")
        $start.ArgumentList.Add($installedGuiChart)
        $start.ArgumentList.Add("--evidence-output")
        $start.ArgumentList.Add($runningRuntimePath)
        $runningProcess = [Diagnostics.Process]::Start($start)
        try {
            $runningHandle = Wait-Condition `
                -Description "isolated installed-client main window" `
                -Seconds ([Math]::Min($TimeoutSeconds, 120)) `
                -Condition {
                    $runningProcess.Refresh()
                    if ($runningProcess.HasExited) {
                        throw "Isolated installed client exited before repair."
                    }
                    if ($runningProcess.MainWindowHandle -ne 0) {
                        return [IntPtr]$runningProcess.MainWindowHandle
                    }
                    $false
                }
            [void](Wait-Condition `
                -Description "isolated installed-client runtime evidence" `
                -Seconds ([Math]::Min($TimeoutSeconds, 120)) `
                -Condition {
                    (Test-Path -LiteralPath $runningRuntimePath -PathType Leaf) -and
                    (Get-Item -LiteralPath $runningRuntimePath).Length -gt 0
                })
            $runningRuntime =
                Get-Content -Raw -LiteralPath $runningRuntimePath |
                    ConvertFrom-Json -Depth 100
            Assert ([long]$runningRuntime.chart.structure.noteCount -eq 2753 -and
                $runningRuntime.audio.sourceExists -eq $true) (
                "Isolated installed client did not load the real chart and audio.")
            $runningIdleMilliseconds = Wait-ForegroundAutomationConsent
            $runningScreenshot =
                Capture-ExistingWindow $runningHandle $runningScreenshotPath
            $lifecycleRepairExitCode = Invoke-HiddenProcess $setup @(
                "/CURRENTUSER",
                "/VERYSILENT",
                "/SP-",
                "/NORESTART",
                "/CLOSEAPPLICATIONS",
                "/NOICONS",
                "/SUPPRESSMSGBOXES",
                "/TASKS=",
                "/DIR=$lifecycleInstall",
                "/LOG=$lifecycleRepairLog") (
                "Avalonia preview running-client repair install")
            Assert ($runningProcess.WaitForExit(20000)) (
                "Repair completed without closing the isolated installed client.")
            Assert ($runningProcess.ExitCode -eq 0) (
                "Isolated installed client did not exit cleanly during repair.")
            Assert (Test-Path -LiteralPath $runningShutdownPath -PathType Leaf) (
                "The installed client did not record its external shutdown decision.")
            $runningShutdown =
                Get-Content -Raw -LiteralPath $runningShutdownPath |
                    ConvertFrom-Json -Depth 20
            Assert ($runningShutdown.canCloseImmediately -eq $true -and
                $runningShutdown.hasUnsavedDocuments -eq $false -and
                $runningShutdown.hasBlockingWork -eq $false -and
                $runningShutdown.hasActiveOnlineRoom -eq $false) (
                "The installed client did not take the safe clean external-shutdown path.")
            $repairLogText = Get-Content -Raw -LiteralPath $lifecycleRepairLog
            Assert ($repairLogText.Contains(
                    "Need to restart Windows? No",
                    [StringComparison]::Ordinal)) (
                "Running-client repair required a Windows restart.")
            $runningAppAfter = File-Evidence $installedApp
            $runningSentinelAfter = File-Evidence $upgradeSentinel
            Assert ($runningAppAfter.sha256 -ceq $runningAppBefore.sha256) (
                "Running-client repair changed the installed application bytes.")
            Assert ($runningSentinelAfter.sha256 -ceq
                $runningSentinelBefore.sha256) (
                "Running-client repair changed the editing-cache sentinel.")

            $afterRoot = Join-Path $runningRoot "after-repair"
            $afterRuntimePath = Join-Path $afterRoot "runtime-evidence.json"
            $afterScreenshotPath = Join-Path $afterRoot "editor.png"
            $afterCaptureRunPath = Join-Path $afterRoot "capture-run.log"
            $afterCapture = Invoke-ForegroundCaptureWithRetry {
                & (Join-Path $PSScriptRoot "Capture-WindowsAvaloniaGui.ps1") `
                    -ApplicationExecutablePath $installedApp `
                    -ChartPath $installedGuiChart `
                    -EvidencePath $afterRuntimePath `
                    -ScreenshotPath $afterScreenshotPath `
                    -WorkspaceRoot (Join-Path $afterRoot "workspace") `
                    -LocalDataRoot (Join-Path $afterRoot "local-data") `
                    -EditingRoot (Join-Path $afterRoot "editing") `
                    -InteractionDelayMilliseconds 1800 `
                    -TimeoutSeconds ([Math]::Min($TimeoutSeconds, 120))
            }
            $afterCapture.Output |
                Set-Content -LiteralPath $afterCaptureRunPath `
                    -Encoding utf8NoBOM
            $afterRuntime =
                Get-Content -Raw -LiteralPath $afterRuntimePath |
                    ConvertFrom-Json -Depth 100
            Assert ([long]$afterRuntime.chart.structure.noteCount -eq 2753 -and
                $afterRuntime.audio.sourceExists -eq $true) (
                "Repaired installed client did not reopen the real chart and audio.")
            $runningSourceAfter = File-Evidence $installedGuiChart
            Assert ($runningSourceAfter.sha256 -ceq
                $runningSourceBefore.sha256) (
                "Running-client repair GUI changed the real chart fixture.")
            $runningClientRepairEvidence = [ordered]@{
                processId = [int]$runningProcess.Id
                mainWindowHandle = $runningHandle.ToInt64()
                processExitedDuringRepair = $true
                processExitCode = [int]$runningProcess.ExitCode
                initialSystemIdleMilliseconds =
                    [long]$runningIdleMilliseconds
                reservedDesktopConsentUsed =
                    [bool]$script:WindowsAvaloniaForegroundAutomationReservedDesktopConsentUsed
                beforeRuntime = File-Evidence $runningRuntimePath
                shutdownDecision = File-Evidence $runningShutdownPath
                shutdownCloseReason = [string]$runningShutdown.closeReason
                shutdownWasProgrammatic = [bool]$runningShutdown.isProgrammatic
                beforeScreenshot = $runningScreenshot
                installedAppBefore = $runningAppBefore
                editingCacheBefore = $runningSentinelBefore
                repairExitCode = [int]$lifecycleRepairExitCode
                restartRequired = $false
                installedAppAfter = $runningAppAfter
                editingCacheAfter = $runningSentinelAfter
                afterRuntime = File-Evidence $afterRuntimePath
                afterScreenshot = File-Evidence $afterScreenshotPath
                afterCaptureRun = File-Evidence $afterCaptureRunPath
                sourceBefore = $runningSourceBefore
                sourceAfter = $runningSourceAfter
                sourceUnchanged = $true
                realChartAndAudioReopened = $true
            }
        }
        finally {
            if ($runningProcess) {
                try {
                    if (-not $runningProcess.HasExited) {
                        $runningProcess.Kill($true)
                        [void]$runningProcess.WaitForExit(5000)
                    }
                }
                catch { }
                finally {
                    $runningProcess.Dispose()
                }
            }
        }
    }
    else {
        $lifecycleRepairExitCode = Invoke-HiddenProcess $setup @(
            "/CURRENTUSER",
            "/VERYSILENT",
            "/SP-",
            "/NORESTART",
            "/NOICONS",
            "/SUPPRESSMSGBOXES",
            "/TASKS=",
            "/DIR=$lifecycleInstall",
            "/LOG=$lifecycleRepairLog") "Avalonia preview same-identity repair install"
    }
    $installedAppAfterRepair = File-Evidence $installedApp
    $upgradeSentinelAfter = File-Evidence $upgradeSentinel
    Assert ($installedAppAfterRepair.sha256 -ceq $installedAppEvidence.sha256) (
        "Same-identity repair changed the installed application unexpectedly.")
    Assert ($upgradeSentinelAfter.sha256 -ceq $repairSentinelBefore.sha256) (
        "Same-identity repair discarded or changed the recoverable editing-cache sentinel.")
    Remove-Item -LiteralPath $upgradeSentinel
    $lifecycleUninstallExitCode = Invoke-PreviewUninstall (
        $lifecycleInstall) $lifecycleUninstallLog
    $lifecycleUninstalled = $true
    Start-Sleep -Milliseconds 800
    $lifecycleLegacyEditingCacheKept = Remove-UninstalledInstallRoot $lifecycleInstall "Lifecycle"
    Assert (-not (Test-Path -LiteralPath $lifecycleInstall)) (
        "Lifecycle uninstall left the installation directory.")
}
finally {
    if (Test-Path -LiteralPath $upgradeSentinel -PathType Leaf) {
        Remove-Item -LiteralPath $upgradeSentinel
    }
    if (-not $lifecycleUninstalled -and
        (Test-Path -LiteralPath (
            Join-Path $lifecycleInstall "unins000.exe") -PathType Leaf)) {
        try {
            [void](Invoke-PreviewUninstall $lifecycleInstall (
                Join-Path $lifecycleRoot "failure-cleanup.log"))
        }
        catch { }
    }
}

$associationRoot = Join-Path $output "associations"
$associationInstall = Join-Path $associationRoot "installed"
New-Item -ItemType Directory -Path $associationRoot | Out-Null
$associationInstallLog = Join-Path $associationRoot "install.log"
$associationUninstallLog = Join-Path $associationRoot "uninstall.log"
$defaultsBefore = [ordered]@{}
foreach ($entry in $associationMap.GetEnumerator()) {
    $defaultsBefore[$entry.Key] = Get-CurrentUserClassDefault $entry.Key
    Assert (-not (Test-CurrentUserClassValue (
        "Software\Classes\$($entry.Key)\OpenWithProgids") $entry.Value)) (
        "Preview OpenWith value already exists: $($entry.Key)")
    Assert (-not (Test-Path -LiteralPath (
        "Registry::HKEY_CURRENT_USER\Software\Classes\$($entry.Value)"))) (
        "Preview ProgID already exists: $($entry.Value)")
}

$associationDuring = [ordered]@{}
$associationGuiEvidence = [ordered]@{}
$associationUninstalled = $false
try {
    $associationInstallExitCode = Invoke-HiddenProcess $setup @(
        "/CURRENTUSER",
        "/VERYSILENT",
        "/SP-",
        "/NORESTART",
        "/NOICONS",
        "/SUPPRESSMSGBOXES",
        "/TASKS=fileassoc",
        "/DIR=$associationInstall",
        "/LOG=$associationInstallLog") "Avalonia preview association install"
    foreach ($entry in $associationMap.GetEnumerator()) {
        $default = Get-CurrentUserClassDefault $entry.Key
        $openWith = Test-CurrentUserClassValue (
            "Software\Classes\$($entry.Key)\OpenWithProgids") $entry.Value
        $command = Get-CurrentUserClassCommand $entry.Value
        $expectedCommand =
            "`"$(Join-Path $associationInstall 'LumaChart.Avalonia.exe')`" `"%1`""
        Assert ($default -ceq $defaultsBefore[$entry.Key]) (
            "Default handler changed for $($entry.Key).")
        Assert ($openWith) "OpenWith registration is missing for $($entry.Key)."
        Assert ($command -ceq $expectedCommand) (
            "Open command changed for $($entry.Key): $command")
        $associationDuring[$entry.Key] = [ordered]@{
            default = $default
            openWithPresent = $openWith
            command = $command
        }
    }
    if ($ExerciseInstalledAssociationsGui) {
        $associationApp = Join-Path $associationInstall "LumaChart.Avalonia.exe"
        Assert (Test-Path -LiteralPath $associationApp -PathType Leaf) (
            "Association-installed Avalonia executable is missing.")
        foreach ($entry in $installedAssociationInputs.GetEnumerator()) {
            $name = [string]$entry.Key
            $formatInput = $entry.Value
            $captureRoot = Join-Path $associationRoot (
                "fresh-open-$name")
            $capture = Invoke-ForegroundCaptureWithRetry {
                & (Join-Path $PSScriptRoot (
                    "Capture-WindowsAvaloniaFormatImportGui.ps1")) `
                    -ApplicationPath $associationApp `
                    -InputPath $formatInput["path"] `
                    -OutputRoot $captureRoot `
                    -ExpectedTabCount $formatInput["expectedTabs"] `
                    -OsuImportMode "Calibrate" `
                    -TimeoutSeconds ([Math]::Min($TimeoutSeconds, 180))
            }
            $capture.Output |
                Set-Content -LiteralPath (
                    Join-Path $captureRoot "capture-run.log") -Encoding utf8NoBOM
            $captureEvidencePath = Join-Path $captureRoot "evidence.json"
            $captureEvidence =
                Get-Content -LiteralPath $captureEvidencePath -Raw |
                    ConvertFrom-Json -Depth 100
            Assert ($captureEvidence.status -ceq "passed" -and
                [long]$captureEvidence.expectedTabCount -eq
                    [long]$formatInput["expectedTabs"] -and
                @($captureEvidence.tabs).Count -eq
                    [long]$formatInput["expectedTabs"] -and
                $captureEvidence.input.unchanged -eq $true) (
                "Installed OpenWith target fresh import did not pass for $name.")
            $associationGuiEvidence[$name] = [ordered]@{
                registeredCommand =
                    $associationDuring[$formatInput["extension"]].command
                input = File-Evidence $formatInput["path"]
                expectedTabCount = [int]$formatInput["expectedTabs"]
                actualTabCount = @($captureEvidence.tabs).Count
                inputUnchanged = $true
                idleMillisecondsBeforeCapture =
                    $capture.IdleMilliseconds
                evidence = File-Evidence $captureEvidencePath
                captureRun = File-Evidence (
                    Join-Path $captureRoot "capture-run.log")
                editorScreenshot = File-Evidence (
                    Join-Path $captureRoot "fresh-import-editor.png")
                archiveDialogScreenshot = if (Test-Path -LiteralPath (
                    Join-Path $captureRoot "archive-import-dialog.png")) {
                    File-Evidence (
                        Join-Path $captureRoot "archive-import-dialog.png")
                }
                else {
                    $null
                }
            }
        }
        Assert ($associationGuiEvidence.Count -eq 4) (
            "Installed association GUI coverage did not exercise four formats.")
    }
    $associationUninstallExitCode = Invoke-PreviewUninstall (
        $associationInstall) $associationUninstallLog
    $associationUninstalled = $true
    Start-Sleep -Milliseconds 800
    foreach ($entry in $associationMap.GetEnumerator()) {
        Assert ((Get-CurrentUserClassDefault $entry.Key) -ceq
            $defaultsBefore[$entry.Key]) (
            "Default handler changed after uninstall for $($entry.Key).")
        Assert (-not (Test-CurrentUserClassValue (
            "Software\Classes\$($entry.Key)\OpenWithProgids") $entry.Value)) (
            "OpenWith residue remained for $($entry.Key).")
        Assert (-not (Test-Path -LiteralPath (
            "Registry::HKEY_CURRENT_USER\Software\Classes\$($entry.Value)"))) (
            "ProgID residue remained for $($entry.Key).")
    }
    $associationLegacyEditingCacheKept = Remove-UninstalledInstallRoot $associationInstall "Association"
    Assert (-not (Test-Path -LiteralPath $associationInstall)) (
        "Association uninstall left the installation directory.")
}
finally {
    if (-not $associationUninstalled -and
        (Test-Path -LiteralPath (
            Join-Path $associationInstall "unins000.exe") -PathType Leaf)) {
        try {
            [void](Invoke-PreviewUninstall $associationInstall (
                Join-Path $associationRoot "failure-cleanup.log"))
        }
        catch { }
    }
}

$wpfAfter = File-Evidence $frozenWpfInstaller
Assert ($wpfAfter.sha256 -ceq $expectedFrozenWpfSha256) (
    "Frozen WPF installer changed during the smoke.")
$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.preview-installer-lifecycle.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = if ($FormalMigrationAuthority) {
        "passed-migration-incomplete"
    }
    else {
        "preflight-passed-nonformal"
    }
    formalMigrationAuthority = [bool]$FormalMigrationAuthority
    completion = $false
    migrationComplete = $false
    windowsAvaloniaOnly = $true
    pureDotnetRelease = $true
    ollvmObfuscationPackingVirtualizationOrAotUsed = $false
    productionServerMutationPerformed = $false
    mobileProjectsBuiltModifiedInstalledOrTested = $false
    previewAppId = $previewAppId
    paths = [ordered]@{
        setup = $setup
        upgradeFromSetup = $upgradeFromSetup
        outputRoot = $output
        temp = $runtimeTemp
        lifecycleInstall = $lifecycleInstall
        associationInstall = $associationInstall
    }
    setup = [ordered]@{
        file = $setupEvidence
        fileVersion = $setupVersion.FileVersion.Trim()
        productVersion = $setupVersion.ProductVersion.Trim()
        authenticodeStatus = [string](
            Get-AuthenticodeSignature -LiteralPath $setup).Status
        upgradeFrom = if ($upgradeFromSetup) {
            [ordered]@{
                file = $upgradeFromSetupEvidence
                fileVersion = $upgradeFromSetupVersion.FileVersion.Trim()
                productVersion = $upgradeFromSetupVersion.ProductVersion.Trim()
                authenticodeStatus = [string](
                    Get-AuthenticodeSignature -LiteralPath $upgradeFromSetup).Status
            }
        }
        else {
            $null
        }
    }
    lifecycle = [ordered]@{
        installExitCode = $lifecycleInstallExitCode
        installedFileCount = $installedFileCount
        initialInstalledApp = $initialInstalledAppEvidence
        initialFileVersion = $initialInstalledVersion.FileVersion
        initialProductVersion = $initialInstalledVersion.ProductVersion
        higherVersionUpgradePerformed = [bool]$upgradeFromSetup
        higherVersionUpgradeInstallExitCode = $lifecycleUpgradeExitCode
        higherVersionUpgradeInstalledApp = $installedAppAfterUpgrade
        higherVersionUpgradeChangedApplication = [bool]$upgradeFromSetup
        higherVersionUpgradePreservedEditingCache = [bool](
            $upgradeSentinelAfterUpgrade.sha256 -ceq
                $upgradeSentinelBefore.sha256)
        corruptedHigherVersionPackage = $corruptUpgradeEvidence
        installedApp = $installedAppEvidence
        readmePresent = $true
        thirdPartyNoticesPresent = $true
        editingCachePresent = $true
        desktopShortcutCreated = $false
        clientStarted = [bool]$ExerciseInstalledGui
        installedGui = $installedGuiEvidence
        runningClientRepair = $runningClientRepairEvidence
        sameIdentityRepairInstallExitCode = $lifecycleRepairExitCode
        sameIdentityRepairPreservedInstalledApp = $true
        sameIdentityRepairPreservedEditingCache = $true
        upgradeSentinelBefore = $upgradeSentinelBefore
        upgradeSentinelAfter = $upgradeSentinelAfter
        uninstallExitCode = $lifecycleUninstallExitCode
        installDirectoryRemoved = $true
        legacyEditingCacheKeptByUninstall = [bool]$lifecycleLegacyEditingCacheKept
        installLog = File-Evidence $lifecycleInstallLog
        upgradeInstallLog = if ($upgradeFromSetup) {
            File-Evidence $lifecycleUpgradeLog
        }
        else {
            $null
        }
        repairInstallLog = File-Evidence $lifecycleRepairLog
        uninstallLog = File-Evidence $lifecycleUninstallLog
    }
    associations = [ordered]@{
        installExitCode = $associationInstallExitCode
        defaultsBefore = $defaultsBefore
        during = $associationDuring
        defaultsPreserved = $true
        installedOpenWithTargetGuiExercised =
            [bool]$ExerciseInstalledAssociationsGui
        installedOpenWithTargetGui = $associationGuiEvidence
        uninstallExitCode = $associationUninstallExitCode
        previewRegistryRemoved = $true
        installDirectoryRemoved = $true
        legacyEditingCacheKeptByUninstall = [bool]$associationLegacyEditingCacheKept
        installLog = File-Evidence $associationInstallLog
        uninstallLog = File-Evidence $associationUninstallLog
    }
    immutableInputs = [ordered]@{
        frozenWpfInstallerBefore = $wpfBefore
        frozenWpfInstallerAfter = $wpfAfter
    }
    remainingDifferences = @(
        if (-not $ExerciseInstalledGui) {
            "This slice verifies isolated current-user install and uninstall without launching the client."
        }
        if ($upgradeFromSetup) {
            "A truncated current setup is rejected before install and preserves the old binary/cache; interruption during a valid setup transaction still requires a disposable VM fault-injection gate."
        }
        else {
            "Same-version same-identity repair preserves the editing cache; a real higher-version upgrade and failure rollback remain open."
        }
        if ($ExerciseInstalledGui) {
            "Installed real-MC GUI startup is covered; all-users Program Files/UAC, VM, signing, and user approval remain open."
        }
        else {
            "Installed GUI startup, all-users Program Files/UAC, VM, signing, and user approval remain open."
        }
        if ($ExerciseInstalledAssociationsGui) {
            "The installed OpenWith command target fresh-opens MC/MCZ/osu/OSZ while existing default handlers remain untouched."
        }
        else {
            "Installed OpenWith target GUI launch for MC/MCZ/osu/OSZ remains open."
        }
        if ($ExerciseRunningClientRepair) {
            "A clean isolated installed client is closed by same-identity repair without restart and reopens the real MC/OGG; dirty-document prompts and interrupted setup remain open."
        }
        else {
            "Running-client repair remains open."
        }
        "The preview AppId intentionally coexists with WPF until replacement is approved."
    )
}
$evidencePath = Join-Path $output "evidence.json"
$evidence | ConvertTo-Json -Depth 30 |
    Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
Write-Output (
    "Windows Avalonia preview installer lifecycle: " + $evidence.status)
Write-Output "Evidence: $evidencePath"
