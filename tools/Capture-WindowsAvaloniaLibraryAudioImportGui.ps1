param(
    [Parameter(Mandatory = $true)][string]$ApplicationPath,
    [Parameter(Mandatory = $true)][string]$AudioPath,
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [string]$RequestedName = "主功能音频导入",
    [ValidateRange(30, 180)][int]$TimeoutSeconds = 120
)

if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia library-audio GUI capture requires PowerShell Core on Windows."
}

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")

$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$applicationFullPath = [IO.Path]::GetFullPath($ApplicationPath)
$audioFullPath = [IO.Path]::GetFullPath($AudioPath)
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
$allowedRoots = @(
    ([IO.Path]::GetFullPath((Join-Path $projectRoot ".codex-temp")).TrimEnd('\') + '\')
    ([IO.Path]::GetFullPath((Join-Path $projectRoot "artifacts")).TrimEnd('\') + '\'))
$matchingAllowedRoots = @($allowedRoots | Where-Object {
    $outputFullPath.StartsWith($_, [StringComparison]::OrdinalIgnoreCase)
})
if ($matchingAllowedRoots.Count -eq 0) {
    throw "The isolated GUI output root must stay under .codex-temp or artifacts."
}
if (-not (Test-Path -LiteralPath $applicationFullPath -PathType Leaf)) {
    throw "Avalonia executable not found: $applicationFullPath"
}
if (-not (Test-Path -LiteralPath $audioFullPath -PathType Leaf)) {
    throw "Audio fixture not found: $audioFullPath"
}
if ([IO.Path]::GetExtension($audioFullPath) -ine ".ogg") {
    throw "This focused normal-chain gate requires a real OGG so no conversion-choice branch obscures library creation."
}
if (Test-Path -LiteralPath $outputFullPath) {
    if ((Get-ChildItem -LiteralPath $outputFullPath -Force | Measure-Object).Count -ne 0) {
        throw "The focused GUI output root must be empty: $outputFullPath"
    }
} else {
    [void](New-Item -ItemType Directory -Path $outputFullPath)
}

$workspaceRoot = Join-Path $outputFullPath "workspace"
$localDataRoot = Join-Path $outputFullPath "local-data"
$editingRoot = Join-Path $outputFullPath "editing"
[void](New-Item -ItemType Directory -Path $workspaceRoot)

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LumaLibraryAudioGuiNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr handle, out RECT rectangle);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr handle);

    [DllImport("user32.dll")]
    public static extern bool IsWindowEnabled(IntPtr handle);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr handle, IntPtr deviceContext, uint flags);
}
'@

function Find-AutomationId {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$AutomationId,
        [ValidateRange(100, 180000)][int]$TimeoutMilliseconds = 15000
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
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding AutomationId '$AutomationId' for process $ProcessId."
}

function Find-AutomationName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [ValidateRange(100, 180000)][int]$TimeoutMilliseconds = 15000
    )

    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $nameCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::NameProperty,
        $Name)
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        try {
            $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
                [Windows.Automation.TreeScope]::Children,
                $processCondition)
            foreach ($root in $roots) {
                if ([string]$root.Current.Name -ceq $Name) { return $root }
                $candidate = $root.FindFirst(
                    [Windows.Automation.TreeScope]::Descendants,
                    $nameCondition)
                if ($candidate) { return $candidate }
            }
        }
        catch [Windows.Automation.ElementNotAvailableException] { }
        catch [Runtime.InteropServices.COMException] { }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding Automation name '$Name' for process $ProcessId."
}

function Invoke-AutomationElement {
    param([Parameter(Mandatory = $true)]$Element)

    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$pattern)) {
        throw "Automation element '$($Element.Current.AutomationId)' has no InvokePattern."
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Set-AutomationValue {
    param(
        [Parameter(Mandatory = $true)]$Element,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value
    )

    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$pattern)) {
        throw "Automation element '$($Element.Current.AutomationId)' has no ValuePattern."
    }
    ([Windows.Automation.ValuePattern]$pattern).SetValue($Value)
}

function Submit-NativeOpenPicker {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $dialog = Find-AutomationName `
        -ProcessId $ProcessId `
        -Name "选择要导入曲库的音频" `
        -TimeoutMilliseconds 15000
    $handle = [IntPtr]$dialog.Current.NativeWindowHandle
    if ($handle -eq [IntPtr]::Zero) {
        throw "The native audio picker has no HWND."
    }

    $edit = $null
    foreach ($automationId in @("1148", "1001")) {
        $condition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty,
            $automationId)
        $matches = $dialog.FindAll(
            [Windows.Automation.TreeScope]::Descendants,
            $condition)
        for ($index = 0; $index -lt $matches.Count; $index++) {
            $candidate = $matches.Item($index)
            $pattern = $null
            if ($candidate.Current.IsEnabled -and
                $candidate.TryGetCurrentPattern(
                    [Windows.Automation.ValuePattern]::Pattern,
                    [ref]$pattern)) {
                $edit = $candidate
                break
            }
        }
        if ($edit) { break }
    }
    if (-not $edit) {
        throw "The native audio picker has no editable file-name field."
    }
    Set-AutomationValue -Element $edit -Value $Path

    $openButton = $null
    foreach ($automationId in @("1", "CommandButton_1")) {
        $condition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::AutomationIdProperty,
            $automationId)
        $openButton = $dialog.FindFirst(
            [Windows.Automation.TreeScope]::Descendants,
            $condition)
        if ($openButton) { break }
    }
    if (-not $openButton) {
        throw "The native audio picker has no Open button."
    }
    Invoke-AutomationElement $openButton

    return [ordered]@{
        title = [string]$dialog.Current.Name
        nativeWindowHandle = $handle.ToInt64()
        fileNameAutomationId = [string]$edit.Current.AutomationId
        submittedPath = $Path
        submission = "ValuePattern + explicit Open button"
    }
}

function Save-WindowScreenshot {
    param(
        [Parameter(Mandatory = $true)][Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $Process.Refresh()
    if ($Process.HasExited -or $Process.MainWindowHandle -eq [IntPtr]::Zero) {
        throw "The Avalonia main window is unavailable for screenshot capture."
    }
    [void][LumaLibraryAudioGuiNative]::SetForegroundWindow($Process.MainWindowHandle)
    Start-Sleep -Milliseconds 500
    $rectangle = [LumaLibraryAudioGuiNative+RECT]::new()
    if (-not [LumaLibraryAudioGuiNative]::GetWindowRect(
            $Process.MainWindowHandle,
            [ref]$rectangle)) {
        throw "GetWindowRect failed."
    }
    $width = $rectangle.Right - $rectangle.Left
    $height = $rectangle.Bottom - $rectangle.Top
    $bitmap = [Drawing.Bitmap]::new(
        $width,
        $height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $deviceContext = $graphics.GetHdc()
            try {
                if (-not [LumaLibraryAudioGuiNative]::PrintWindow(
                        $Process.MainWindowHandle,
                        $deviceContext,
                        2)) {
                    throw "PrintWindow failed."
                }
            }
            finally {
                $graphics.ReleaseHdc($deviceContext)
            }
        }
        finally {
            $graphics.Dispose()
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
}

$audioSourceSha256 = (Get-FileHash -LiteralPath $audioFullPath -Algorithm SHA256).Hash
$processStart = [Diagnostics.ProcessStartInfo]::new($applicationFullPath)
$processStart.UseShellExecute = $false
$processStart.WorkingDirectory = [IO.Path]::GetDirectoryName($applicationFullPath)
$processStart.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localDataRoot
$processStart.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editingRoot
$processStart.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspaceRoot
$processStart.Environment["LUMACHART_AVALONIA_DISABLE_SINGLE_INSTANCE"] = "1"
$processStart.ArgumentList.Add("--evidence-focus-library-launcher")

$process = [Diagnostics.Process]::Start($processStart)
if (-not $process) {
    throw "Unable to start the isolated Windows Avalonia client."
}

try {
    $importButton = Find-AutomationId `
        -ProcessId $process.Id `
        -AutomationId "Library.ImportAudio" `
        -TimeoutMilliseconds 30000
    Invoke-AutomationElement $importButton
    $pickerEvidence = Submit-NativeOpenPicker `
        -ProcessId $process.Id `
        -Path $audioFullPath

    $nameBox = Find-AutomationId `
        -ProcessId $process.Id `
        -AutomationId "Library.AudioImport.Name" `
        -TimeoutMilliseconds 15000
    Set-AutomationValue -Element $nameBox -Value $RequestedName
    $nameScreenshotPath = Join-Path $outputFullPath "audio-name-prompt.png"
    Save-WindowScreenshot -Process $process -Path $nameScreenshotPath

    $confirmButton = Find-AutomationId `
        -ProcessId $process.Id `
        -AutomationId "Library.AudioImport.Confirm" `
        -TimeoutMilliseconds 5000
    Invoke-AutomationElement $confirmButton

    $tempoCancel = Find-AutomationId `
        -ProcessId $process.Id `
        -AutomationId "Tempo.SingleCancel" `
        -TimeoutMilliseconds ($TimeoutSeconds * 1000)
    Invoke-AutomationElement $tempoCancel

    $dialogCloseDeadline = [DateTimeOffset]::UtcNow.AddSeconds(10)
    do {
        $process.Refresh()
        if ([LumaLibraryAudioGuiNative]::IsWindowEnabled($process.MainWindowHandle)) {
            break
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTimeOffset]::UtcNow -lt $dialogCloseDeadline)
    if (-not [LumaLibraryAudioGuiNative]::IsWindowEnabled($process.MainWindowHandle)) {
        throw "The editor did not regain input after dismissing the BPM result."
    }

    $unsavedEditorScreenshotPath =
        Join-Path $outputFullPath "audio-imported-unsaved-editor.png"
    Save-WindowScreenshot -Process $process -Path $unsavedEditorScreenshotPath
    $saveSubmission = "AutomationId Editor.Save"
    try {
        $saveButton = Find-AutomationId `
            -ProcessId $process.Id `
            -AutomationId "Editor.Save" `
            -TimeoutMilliseconds 3000
        Invoke-AutomationElement $saveButton
    }
    catch {
        try {
            $saveButton = Find-AutomationName `
                -ProcessId $process.Id `
                -Name "保存" `
                -TimeoutMilliseconds 3000
            Invoke-AutomationElement $saveButton
            $saveSubmission = "UIA Name 保存 fallback"
        }
        catch {
            [void][LumaLibraryAudioGuiNative]::SetForegroundWindow(
                $process.MainWindowHandle)
            Start-Sleep -Milliseconds 250
            [Windows.Forms.SendKeys]::SendWait("^s")
            $saveSubmission = "focused Ctrl+S fallback"
        }
    }

    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(20)
    $chart = $null
    do {
        $chart = Get-ChildItem -LiteralPath $workspaceRoot -Recurse -File -Filter "*.mc" |
            Select-Object -First 1
        $process.Refresh()
        if ($chart -and $process.MainWindowTitle -notmatch "\*") { break }
        Start-Sleep -Milliseconds 200
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    if (-not $chart) {
        throw "The library-audio flow did not create an MC in the isolated workspace."
    }

    $editorScreenshotPath = Join-Path $outputFullPath "audio-imported-editor.png"
    Save-WindowScreenshot -Process $process -Path $editorScreenshotPath
    $document = Get-Content -LiteralPath $chart.FullName -Raw | ConvertFrom-Json
    $audioReference = [string]$document.meta.song.file
    $copiedAudioPath = Join-Path $chart.DirectoryName $audioReference
    $fatalDiagnostics = @(
        Get-ChildItem -LiteralPath (Join-Path $localDataRoot "Logs") -File -ErrorAction SilentlyContinue |
            Select-String -Pattern '"Event":"application-fatal-exception"')

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.library-audio-import-gui.v1"
        generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
        platformScope = "Windows Avalonia only"
        processId = $process.Id
        nativePicker = $pickerEvidence
        requestedName = $RequestedName
        finalWindowTitle = $process.MainWindowTitle
        chartPath = $chart.FullName
        chartBytes = $chart.Length
        chartTitle = [string]$document.meta.song.title
        chartTitleOriginal = [string]$document.meta.song.titleorg
        creator = [string]$document.meta.creator
        audioReference = $audioReference
        audioSourcePath = $audioFullPath
        audioSourceBytes = (Get-Item -LiteralPath $audioFullPath).Length
        audioSourceSha256 = $audioSourceSha256
        copiedAudioPath = $copiedAudioPath
        copiedAudioExists = Test-Path -LiteralPath $copiedAudioPath -PathType Leaf
        copiedAudioSha256 = if (Test-Path -LiteralPath $copiedAudioPath -PathType Leaf) {
            (Get-FileHash -LiteralPath $copiedAudioPath -Algorithm SHA256).Hash
        } else { $null }
        tempoResultDismissed = $true
        saveSubmission = $saveSubmission
        fatalDiagnosticCount = $fatalDiagnostics.Count
        screenshots = @(
            [ordered]@{
                path = $nameScreenshotPath
                bytes = (Get-Item -LiteralPath $nameScreenshotPath).Length
                sha256 = (Get-FileHash -LiteralPath $nameScreenshotPath -Algorithm SHA256).Hash
            },
            [ordered]@{
                path = $unsavedEditorScreenshotPath
                bytes = (Get-Item -LiteralPath $unsavedEditorScreenshotPath).Length
                sha256 = (Get-FileHash -LiteralPath $unsavedEditorScreenshotPath -Algorithm SHA256).Hash
            },
            [ordered]@{
                path = $editorScreenshotPath
                bytes = (Get-Item -LiteralPath $editorScreenshotPath).Length
                sha256 = (Get-FileHash -LiteralPath $editorScreenshotPath -Algorithm SHA256).Hash
            })
    }
    $evidence.status = if (
        $evidence.copiedAudioExists -and
        $evidence.copiedAudioSha256 -ceq $audioSourceSha256 -and
        $evidence.fatalDiagnosticCount -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($evidence.audioReference)) {
        "passed"
    } else {
        "failed"
    }
    $evidencePath = Join-Path $outputFullPath "evidence.json"
    $evidence | ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    if ($evidence.status -ne "passed") {
        throw "Library-audio GUI evidence failed its structural checks."
    }
    Write-Host "Library-audio Windows GUI evidence: passed"
    Write-Host "Evidence: $evidencePath"
}
finally {
    if (-not $process.HasExited) {
        [void]$process.CloseMainWindow()
        if (-not $process.WaitForExit(8000)) {
            $process.Kill($true)
            [void]$process.WaitForExit(5000)
        }
    }
    $process.Dispose()
}
