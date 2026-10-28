param(
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$consentHelper = Join-Path `
    $PSScriptRoot `
    "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1"
if (-not (Test-Path -LiteralPath $consentHelper -PathType Leaf)) {
    throw "Foreground automation consent helper is missing: $consentHelper"
}
$consentHelperText =
    Get-Content -LiteralPath $consentHelper -Raw -Encoding UTF8
foreach ($requiredConsentContract in @(
        'MinimumIdleMilliseconds = 3000',
        'GetLastInputInfo',
        'GetAsyncKeyState',
        'USER_CONFIRMED_DESKTOP_AVAILABLE',
        'USER_CONFIRMED_ALL_DESKTOP_INPUT_RESERVED')) {
    if (-not $consentHelperText.Contains(
            $requiredConsentContract,
            [StringComparison]::Ordinal)) {
        throw (
            "Foreground automation consent helper is missing contract: " +
            $requiredConsentContract)
    }
}

$captureScripts = @(
    Get-ChildItem `
        -LiteralPath $PSScriptRoot `
        -File `
        -Filter "Capture-WindowsAvalonia*Gui*.ps1" |
        Sort-Object Name
)
if ($captureScripts.Count -eq 0) {
    throw "No Windows Avalonia GUI capture scripts were found."
}

$persistentTopmostPattern =
    '(?i)(?:new\s+IntPtr|\[IntPtr\])\s*\(\s*-1\s*\)|' +
    '(?:new\s*\(\s*-1\s*\)|new\s+nint\s*\(\s*-1\s*\))|' +
    'HWND_TOPMOST|\btopmost\s*=\s*(?:true|\$true)'
$records = foreach ($script in $captureScripts) {
    $text = Get-Content -LiteralPath $script.FullName -Raw -Encoding UTF8
    [void][scriptblock]::Create($text)

    $consentReferences = @(
        [regex]::Matches(
            $text,
            'Assert-WindowsAvaloniaForegroundAutomationConsent\.ps1',
            [Text.RegularExpressions.RegexOptions]::CultureInvariant)
    )
    if ($consentReferences.Count -ne 1) {
        throw (
            "$($script.Name) must invoke the foreground consent helper " +
            "exactly once; found $($consentReferences.Count).")
    }

    $topmostMatches = @(
        [regex]::Matches(
            $text,
            $persistentTopmostPattern,
            [Text.RegularExpressions.RegexOptions]::CultureInvariant)
    )
    if ($topmostMatches.Count -ne 0) {
        throw (
            "$($script.Name) contains a persistent topmost pattern: " +
            $topmostMatches[0].Value)
    }

    [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $script.FullName)
        sha256 = (Get-FileHash -LiteralPath $script.FullName -Algorithm SHA256).Hash
        parsed = $true
        consentGuardCount = $consentReferences.Count
        persistentTopmostPatternCount = $topmostMatches.Count
    }
}

$automationHelperSources = @(
    Get-ChildItem `
        -LiteralPath $PSScriptRoot `
        -Recurse `
        -File `
        -Filter "*.cs" |
        Where-Object {
            $_.FullName -notmatch '[\\/](?:bin|obj)[\\/]'
        } |
        Sort-Object FullName
)
$helperRecords = foreach ($source in $automationHelperSources) {
    $text = Get-Content -LiteralPath $source.FullName -Raw -Encoding UTF8
    $topmostMatches = @(
        [regex]::Matches(
            $text,
            $persistentTopmostPattern,
            [Text.RegularExpressions.RegexOptions]::CultureInvariant)
    )
    if ($topmostMatches.Count -ne 0) {
        throw (
            "$([IO.Path]::GetRelativePath($projectRoot, $source.FullName)) " +
            "contains a persistent topmost pattern: " +
            $topmostMatches[0].Value)
    }

    [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $source.FullName)
        sha256 = (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash
        persistentTopmostPatternCount = $topmostMatches.Count
    }
}

$keyboardProbeSource = Join-Path `
    $PSScriptRoot `
    "WindowsKeyboardImeProbe\Program.cs"
if (-not (Test-Path -LiteralPath $keyboardProbeSource -PathType Leaf)) {
    throw "Windows keyboard/IME probe source is missing: $keyboardProbeSource"
}
$keyboardProbeText =
    Get-Content -LiteralPath $keyboardProbeSource -Raw -Encoding UTF8
foreach ($requiredKeyboardProbeContract in @(
        'WindowInsertAfterNotTopmost',
        'targetPromotedTopmost = false',
        'targetForcedNonTopmost = forcedNonTopmost')) {
    if (-not $keyboardProbeText.Contains(
            $requiredKeyboardProbeContract,
            [StringComparison]::Ordinal)) {
        throw (
            "Windows keyboard/IME probe is missing non-topmost contract: " +
            $requiredKeyboardProbeContract)
    }
}

$evidence = [ordered]@{
    schema = "lumachart.windows.avalonia.gui-automation-safety.v1"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed"
    windowsAvaloniaOnly = $true
    foregroundAutomationRequiresExplicitUserConsent = $true
    minimumSystemIdleMilliseconds = 3000
    continuouslyInjectedInputRequiresReservedDesktopConsent = $true
    heldModifierGateRequired = $true
    persistentTopmostUsed = $false
    captureScriptCount = $captureScripts.Count
    automationHelperSourceCount = $automationHelperSources.Count
    consentHelper = [ordered]@{
        path = [IO.Path]::GetRelativePath($projectRoot, $consentHelper)
        sha256 = (Get-FileHash -LiteralPath $consentHelper -Algorithm SHA256).Hash
    }
    scripts = @($records)
    automationHelperSources = @($helperRecords)
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputFullPath = [IO.Path]::GetFullPath($OutputPath)
    if (Test-Path -LiteralPath $outputFullPath) {
        throw "Safety evidence output already exists: $outputFullPath"
    }
    $outputDirectory = [IO.Path]::GetDirectoryName($outputFullPath)
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    }
    $evidence |
        ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath $outputFullPath -Encoding UTF8
}

$evidence
