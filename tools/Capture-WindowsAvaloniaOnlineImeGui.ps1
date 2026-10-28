param(
    [string]$ApplicationPath = (Join-Path $PSScriptRoot "..\LumaChart.Avalonia\bin\Release\net8.0-windows\LumaChart.Avalonia.exe"),
    [string]$ServerAssemblyPath = (Join-Path $PSScriptRoot "WindowsAvaloniaOnlineGuiServer\bin\Release\net8.0\WindowsAvaloniaOnlineGuiServer.dll"),
    [string]$KeyboardImeProbeAssemblyPath = (Join-Path $PSScriptRoot "WindowsKeyboardImeProbe\bin\Release\net8.0-windows\WindowsKeyboardImeProbe.dll"),
    [string]$ChartFixturePath = "D:\osu!\Songs\Resound\0\1781536331.mc",
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [switch]$FormalAuthority,
    [switch]$StopAfterCorrectPasswordJoin,
    [ValidateRange(60, 300)][int]$TimeoutSeconds = 150
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Assert-WindowsAvaloniaForegroundAutomationConsent.ps1")
if ($PSVersionTable.PSEdition -ne "Core" -or -not $IsWindows) {
    throw "Windows Avalonia online IME GUI capture requires PowerShell Core on Windows."
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
        [int]$Seconds = $TimeoutSeconds,
        [int]$PollMilliseconds = 100
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
    do {
        try {
            if (& $Condition) { return }
        }
        catch { }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Description."
}

function Wait-File([string]$Path, [string]$Description, [int]$Seconds = $TimeoutSeconds) {
    Wait-Condition -Description $Description -Seconds $Seconds -Condition {
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -gt 0
    }
}

$applicationFullPath = Resolve-ExistingFile $ApplicationPath "Avalonia executable"
$serverAssemblyFullPath = Resolve-ExistingFile $ServerAssemblyPath "Loopback GUI server"
$keyboardImeProbeFullPath = Resolve-ExistingFile `
    $KeyboardImeProbeAssemblyPath "Windows keyboard IME probe"
$fixtureFullPath = Resolve-ExistingFile $ChartFixturePath "Real MC fixture"
$outputFullPath = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $outputFullPath) {
    throw "Output root already exists: $outputFullPath"
}
[void](New-Item -ItemType Directory -Path $outputFullPath)

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$projectTemp = Join-Path $projectRoot ".codex-temp"
$dotnetHome = Join-Path $projectRoot ".codex-dotnet-home"
$nugetPackages = Join-Path $projectRoot ".codex-nuget-packages"
$nugetHttpCache = Join-Path $projectRoot ".codex-nuget-http-cache"
foreach ($directory in @(
        $projectTemp, $dotnetHome, $nugetPackages, $nugetHttpCache)) {
    [void](New-Item -ItemType Directory -Force -Path $directory)
}
$env:DOTNET_CLI_HOME = $dotnetHome
$env:NUGET_PACKAGES = $nugetPackages
$env:NUGET_HTTP_CACHE_PATH = $nugetHttpCache
$env:TEMP = $projectTemp
$env:TMP = $projectTemp
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Security.Cryptography.ProtectedData

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

function Find-ElementByName {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Name,
        [ValidateRange(100, 300000)][int]$TimeoutMilliseconds = 10000
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
        Start-Sleep -Milliseconds 75
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out finding UI Automation name '$Name' for process $ProcessId."
}

function Invoke-Element($Element) {
    $pattern = $null
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.InvokePattern]::Pattern,
            [ref]$pattern)) {
        ([Windows.Automation.InvokePattern]$pattern).Invoke()
        Start-Sleep -Milliseconds 250
        return
    }
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.TogglePattern]::Pattern,
            [ref]$pattern)) {
        ([Windows.Automation.TogglePattern]$pattern).Toggle()
        Start-Sleep -Milliseconds 250
        return
    }
    if ($Element.TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$pattern)) {
        ([Windows.Automation.SelectionItemPattern]$pattern).Select()
        Start-Sleep -Milliseconds 250
        return
    }
    throw "Element '$($Element.Current.AutomationId)' exposes no supported action pattern."
}

function Focus-Element($Element, [string]$Description) {
    $Element.SetFocus()
    Wait-Condition -Description "$Description keyboard focus" -Seconds 15 -Condition {
        $Element.Current.HasKeyboardFocus
    }
}

function Get-ElementValue($Element) {
    $pattern = $null
    if (-not $Element.TryGetCurrentPattern(
            [Windows.Automation.ValuePattern]::Pattern,
            [ref]$pattern)) {
        throw "Element '$($Element.Current.AutomationId)' does not expose ValuePattern."
    }
    return [string]([Windows.Automation.ValuePattern]$pattern).Current.Value
}

function Get-PasswordCommittedLength($Element) {
    $helpText = [string]$Element.Current.HelpText
    $match = [regex]::Match(
        $helpText,
        '^Windows 密码输入; ImeEnabled=false; CommittedLength=(\d+)$',
        [Text.RegularExpressions.RegexOptions]::CultureInvariant)
    if (-not $match.Success) {
        throw "Password '$($Element.Current.AutomationId)' has invalid safe status: '$helpText'."
    }
    return [int]$match.Groups[1].Value
}

function Set-PasswordViaWriteOnlyUia($Element, [string]$Value) {
    $pattern = $Element.GetCurrentPattern(
        [Windows.Automation.ValuePattern]::Pattern)
    if (-not $pattern) {
        throw "Password '$($Element.Current.AutomationId)' has no ValuePattern."
    }
    $pattern.SetValue($Value)
    Start-Sleep -Milliseconds 120
    if ([string]$pattern.Current.Value -ne "") {
        throw "Password '$($Element.Current.AutomationId)' exposed its clear text."
    }
    return [ordered]@{
        action = "write-only-uia-password-set"
        automationId = [string]$Element.Current.AutomationId
        valueLength = $Value.Length
        readableValueLength = ([string]$pattern.Current.Value).Length
    }
}

function Find-UiAutomationSecretExposure(
    [int]$ProcessId,
    [Parameter(Mandatory = $true)][string]$Secret) {
    $processCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ProcessIdProperty,
        $ProcessId)
    $matches = [Collections.Generic.List[string]]::new()
    $roots = [Windows.Automation.AutomationElement]::RootElement.FindAll(
        [Windows.Automation.TreeScope]::Children,
        $processCondition)
    foreach ($root in $roots) {
        $elements = @($root) + @($root.FindAll(
            [Windows.Automation.TreeScope]::Descendants,
            [Windows.Automation.Condition]::TrueCondition))
        foreach ($element in $elements) {
            $values = [Collections.Generic.List[string]]::new()
            $values.Add([string]$element.Current.Name)
            $values.Add([string]$element.Current.HelpText)
            try {
                $pattern = $null
                if ($element.TryGetCurrentPattern(
                        [Windows.Automation.ValuePattern]::Pattern,
                        [ref]$pattern)) {
                    $values.Add(
                        [string]([Windows.Automation.ValuePattern]$pattern).Current.Value)
                }
            }
            catch [Windows.Automation.ElementNotAvailableException] { }
            catch [Runtime.InteropServices.COMException] { }
            foreach ($value in $values) {
                if (-not [string]::IsNullOrEmpty($value) -and
                    $value.Contains($Secret, [StringComparison]::Ordinal)) {
                    $matches.Add(
                        "$([string]$element.Current.AutomationId):$value")
                }
            }
        }
    }
    return $matches.ToArray()
}

function Capture-DesktopWindow(
    $WindowElement,
    [string]$Path,
    [string]$CaptureKind) {
    $bounds = $WindowElement.Current.BoundingRectangle
    $width = [int][Math]::Round($bounds.Width)
    $height = [int][Math]::Round($bounds.Height)
    if ($width -lt 500 -or $height -lt 400) {
        throw "Window has invalid screen bounds ${width}x${height}."
    }
    $bitmap = [Drawing.Bitmap]::new(
        $width,
        $height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen(
                [int][Math]::Round($bounds.Left),
                [int][Math]::Round($bounds.Top),
                0,
                0,
                [Drawing.Size]::new($width, $height),
                [Drawing.CopyPixelOperation]::SourceCopy)
        }
        finally { $graphics.Dispose() }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $bitmap.Dispose() }
    return [ordered]@{
        path = [IO.Path]::GetFullPath($Path)
        width = $width
        height = $height
        captureKind = $CaptureKind
        bytes = (Get-Item -LiteralPath $Path).Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

function Invoke-KeyboardImeProbe {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)]
        [ValidateSet("activate", "click", "ascii", "key")]
        [string]$Action,
        [Parameter(Mandatory = $true)][IntPtr]$WindowHandle,
        [string]$Text,
        [ValidateSet("", "Space", "Escape")]
        [string]$Name = "",
        [int]$X = 0,
        [int]$Y = 0
    )
    $arguments = [Collections.Generic.List[string]]::new()
    $arguments.Add($keyboardImeProbeFullPath)
    $arguments.Add($Action)
    $arguments.Add("--process-id")
    $arguments.Add($ProcessId.ToString(
        [Globalization.CultureInfo]::InvariantCulture))
    $arguments.Add("--window-handle")
    $arguments.Add($WindowHandle.ToInt64().ToString(
        [Globalization.CultureInfo]::InvariantCulture))
    if (-not [string]::IsNullOrEmpty($Text)) {
        $arguments.Add("--text")
        $arguments.Add($Text)
    }
    if (-not [string]::IsNullOrEmpty($Name)) {
        $arguments.Add("--name")
        $arguments.Add($Name)
    }
    if ($Action -ceq "click") {
        $arguments.Add("--x")
        $arguments.Add($X.ToString(
            [Globalization.CultureInfo]::InvariantCulture))
        $arguments.Add("--y")
        $arguments.Add($Y.ToString(
            [Globalization.CultureInfo]::InvariantCulture))
    }

    $output = @(& dotnet @arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Keyboard IME probe '$Action' failed: " +
            ($output -join [Environment]::NewLine)
    }
    try {
        return ($output -join [Environment]::NewLine) |
            ConvertFrom-Json -Depth 20
    }
    catch {
        throw "Keyboard IME probe '$Action' returned invalid JSON."
    }
}

function Activate-ElementForKeyboardInput(
    [int]$ProcessId,
    [IntPtr]$WindowHandle,
    $Element,
    [string]$Description) {
    Focus-Element $Element $Description
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -lt 4 -or $bounds.Height -lt 4) {
        throw "$Description has invalid screen bounds: $bounds"
    }
    $x = [int][Math]::Round(
        $bounds.Left + ($bounds.Width / 2),
        [MidpointRounding]::AwayFromZero)
    $y = [int][Math]::Round(
        $bounds.Top + ($bounds.Height / 2),
        [MidpointRounding]::AwayFromZero)
    $click = Invoke-KeyboardImeProbe `
        -ProcessId $ProcessId `
        -Action "click" `
        -WindowHandle $WindowHandle `
        -X $x `
        -Y $y
    Wait-Condition -Description "$Description focus after injected mouse click" `
        -Seconds 15 -Condition { $Element.Current.HasKeyboardFocus }
    return $click
}

function Activate-MicrosoftPinyin(
    [int]$ProcessId,
    [IntPtr]$WindowHandle) {
    $tip =
        "0804:{6573078D-A793-4CD9-A6E6-0FFB01F35262}{CE7B668C-8260-4496-AEE0-5305D3FB8E0E}"
    $profiles = [Collections.Generic.List[string]]::new()
    $languageList = Get-WinUserLanguageList -ErrorAction Stop
    foreach ($language in $languageList) {
        if ($language.LanguageTag -cne "zh-Hans-CN") { continue }
        foreach ($profile in $language.InputMethodTips) {
            $profiles.Add([string]$profile)
        }
    }
    if ($profiles -notcontains $tip) {
        throw "The configured zh-CN input profile is not Microsoft Pinyin."
    }
    $probe = Invoke-KeyboardImeProbe -ProcessId $ProcessId `
        -Action activate -WindowHandle $WindowHandle
    return [ordered]@{
        requestedKeyboardLayout = [string]$probe.requestedKeyboardLayout
        activeKeyboardLayout = [string]$probe.activeKeyboardLayout
        activeLanguageId = [string]$probe.activeLanguageId
        targetThreadId = [long]$probe.targetThreadId
        targetProcessId = [long]$probe.targetProcessId
        configuredInputMethodTip = $tip
        inputMethod = "Microsoft Pinyin"
        occurredUtc = [string]$probe.occurredUtc
    }
}

function Send-Ascii(
    [int]$ProcessId,
    [IntPtr]$WindowHandle,
    [string]$Text) {
    return Invoke-KeyboardImeProbe -ProcessId $ProcessId `
        -Action ascii -WindowHandle $WindowHandle -Text $Text
}

function Send-Key(
    [int]$ProcessId,
    [IntPtr]$WindowHandle,
    [ValidateSet("Space", "Escape")][string]$Name) {
    return Invoke-KeyboardImeProbe -ProcessId $ProcessId `
        -Action key -WindowHandle $WindowHandle -Name $Name
}

function Protect-SessionToken([string]$LocalDataRoot, [string]$Token) {
    [void](New-Item -ItemType Directory -Force -Path $LocalDataRoot)
    $plain = [Text.Encoding]::UTF8.GetBytes($Token)
    try {
        $protected = [Security.Cryptography.ProtectedData]::Protect(
            $plain,
            $null,
            [Security.Cryptography.DataProtectionScope]::CurrentUser)
        [IO.File]::WriteAllBytes(
            (Join-Path $LocalDataRoot "online-session.bin"),
            $protected)
    }
    finally {
        [Array]::Clear($plain, 0, $plain.Length)
    }
}

function Start-Client {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$Profile,
        [Parameter(Mandatory = $true)][string]$Endpoint
    )
    $root = Join-Path $outputFullPath "clients\$Name"
    $localData = Join-Path $root "local-data"
    $editing = Join-Path $root "editing"
    $workspace = Join-Path $root "workspace"
    $inputRoot = Join-Path $root "input"
    $clientTemp = Join-Path $root "temp"
    foreach ($directory in @(
            $localData, $editing, $workspace, $inputRoot, $clientTemp)) {
        [void](New-Item -ItemType Directory -Force -Path $directory)
    }
    Get-ChildItem -LiteralPath (Split-Path -Parent $fixtureFullPath) -File |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName `
                -Destination (Join-Path $inputRoot $_.Name)
        }
    $chart = Join-Path $inputRoot (Split-Path -Leaf $fixtureFullPath)
    Protect-SessionToken $localData $Token
    $runtime = Join-Path $root "startup-runtime.json"
    $start = [Diagnostics.ProcessStartInfo]::new($applicationFullPath)
    $start.UseShellExecute = $false
    $start.Environment["LUMACHART_SERVER_URL"] = $Endpoint
    $start.Environment["LUMACHART_PROFILE"] = $Profile
    $start.Environment["LUMACHART_AVALONIA_LOCAL_DATA_ROOT"] = $localData
    $start.Environment["LUMACHART_AVALONIA_EDITING_ROOT"] = $editing
    $start.Environment["LUMACHART_AVALONIA_WORKSPACE_ROOT"] = $workspace
    $start.Environment["TEMP"] = $clientTemp
    $start.Environment["TMP"] = $clientTemp
    foreach ($argument in @(
            "--evidence-chart", $chart,
            "--evidence-output", $runtime,
            "--evidence-focus-note-property")) {
        $start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::Start($start)
    return [pscustomobject]@{
        Name = $Name
        Root = $root
        LocalData = $localData
        Editing = $editing
        Workspace = $workspace
        Runtime = $runtime
        Process = $process
    }
}

function Wait-AuthenticatedAccountButton(
    [int]$ProcessId,
    [string]$IdentityFragment,
    [int]$Seconds = 30) {
    $script:accountButton = $null
    Wait-Condition -Description "authenticated account '$IdentityFragment'" `
        -Seconds $Seconds -Condition {
        $candidate = Find-ElementById -ProcessId $ProcessId `
            -AutomationId "OnlineAccount.Navigation" `
            -TimeoutMilliseconds 1000
        if ([string]$candidate.Current.Name -like "*$IdentityFragment*") {
            $script:accountButton = $candidate
            return $true
        }
        return $false
    }
    $result = $script:accountButton
    $script:accountButton = $null
    return $result
}

function Open-RoomCommunity([pscustomobject]$Client) {
    $dialog = $null
    try {
        $dialog = Find-ElementById -ProcessId $Client.Process.Id `
            -AutomationId "OnlineCommunity.Dialog" `
            -TimeoutMilliseconds 500
    }
    catch { }
    if (-not $dialog) {
        $account = Wait-AuthenticatedAccountButton `
            $Client.Process.Id `
            $(if ($Client.Name -ceq "owner-a") { "房主" } else { "成员" }) `
            30
        Invoke-Element $account
        $dialog = Find-ElementById -ProcessId $Client.Process.Id `
            -AutomationId "OnlineCommunity.Dialog" `
            -TimeoutMilliseconds 30000
    }
    Invoke-Element (Find-ElementById -ProcessId $Client.Process.Id `
        -AutomationId "OnlineCommunity.Navigation.Rooms" `
        -TimeoutMilliseconds 15000)
    return $dialog
}

function Get-HarnessState([string]$Endpoint) {
    return Invoke-RestMethod -Uri ($Endpoint + "harness/state") `
        -Method Get -TimeoutSec 15
}

function Wait-HarnessState(
    [string]$Endpoint,
    [scriptblock]$Predicate,
    [string]$Description,
    [int]$Seconds = $TimeoutSeconds) {
    $script:lastHarnessState = $null
    Wait-Condition -Description $Description -Seconds $Seconds `
        -PollMilliseconds 150 -Condition {
        $state = Get-HarnessState $Endpoint
        $script:lastHarnessState = $state
        return [bool](& $Predicate $state)
    }
    return $script:lastHarnessState
}

$readyPath = Join-Path $outputFullPath "server-ready.json"
$statePath = Join-Path $outputFullPath "server-state.json"
$serverLogPath = Join-Path $outputFullPath "server.log"
$serverStart = [Diagnostics.ProcessStartInfo]::new("dotnet")
$serverStart.UseShellExecute = $false
$serverStart.RedirectStandardOutput = $true
$serverStart.RedirectStandardError = $true
$serverStart.ArgumentList.Add($serverAssemblyFullPath)
$serverStart.ArgumentList.Add("--ready-file")
$serverStart.ArgumentList.Add($readyPath)
$serverStart.ArgumentList.Add("--state-file")
$serverStart.ArgumentList.Add($statePath)
$server = [Diagnostics.Process]::Start($serverStart)
$owner = $null
$member = $null
$endpoint = $null
$captures = [ordered]@{}
$actions = [Collections.Generic.List[object]]::new()

try {
    Wait-File $readyPath "loopback GUI server readiness" 30
    $ready = Get-Content -LiteralPath $readyPath -Raw -Encoding UTF8 |
        ConvertFrom-Json
    $endpoint = [string]$ready.endpoint
    if (-not $endpoint.StartsWith(
            "http://127.0.0.1:",
            [StringComparison]::Ordinal)) {
        throw "Loopback server published non-loopback endpoint: $endpoint"
    }

    $owner = Start-Client -Name "owner-a" `
        -Token ([string]$ready.ownerToken) `
        -Profile "windows-avalonia-online-ime-owner" `
        -Endpoint $endpoint
    $member = Start-Client -Name "member-b" `
        -Token ([string]$ready.memberToken) `
        -Profile "windows-avalonia-online-ime-member" `
        -Endpoint $endpoint
    Wait-File $owner.Runtime "owner startup runtime" 45
    Wait-File $member.Runtime "member startup runtime" 45
    $ownerAccount = Wait-AuthenticatedAccountButton `
        $owner.Process.Id "房主" 30
    $memberAccount = Wait-AuthenticatedAccountButton `
        $member.Process.Id "成员" 30

    $fixtureBefore = (Get-FileHash -LiteralPath `
        $fixtureFullPath -Algorithm SHA256).Hash
    $installerPath = Join-Path $projectRoot `
        "release\LumaChartStudio-Setup.exe"
    $installerBefore = (Get-FileHash -LiteralPath `
        $installerPath -Algorithm SHA256).Hash

    Invoke-Element $ownerAccount
    $actions.Add([ordered]@{ action = "owner-open-community-uia" })
    $ownerCommunity = Find-ElementById -ProcessId $owner.Process.Id `
        -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 30000
    $ownerCommunityHandle = [IntPtr]$owner.Process.MainWindowHandle
    Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id `
        -AutomationId "OnlineCommunity.Navigation.Rooms" `
        -TimeoutMilliseconds 15000)

    $createName = Find-ElementById -ProcessId $owner.Process.Id `
        -AutomationId "OnlineRooms.Create.Name" -TimeoutMilliseconds 30000
    $actions.Add((Activate-ElementForKeyboardInput `
        $owner.Process.Id $ownerCommunityHandle $createName "owner room name"))
    $ownerIme = Activate-MicrosoftPinyin `
        $owner.Process.Id $ownerCommunityHandle
    $actions.Add((Send-Ascii $owner.Process.Id `
        $ownerCommunityHandle "fangjian"))
    Start-Sleep -Milliseconds 350
    $roomNameBeforeCommit = Get-ElementValue $createName
    if ($roomNameBeforeCommit -cne "") {
        throw "Room-name pinyin committed before candidate selection: '$roomNameBeforeCommit'."
    }
    $captures.ownerRoomNameComposition = Capture-DesktopWindow `
        $ownerCommunity `
        (Join-Path $outputFullPath "owner-room-name-ime-composition.png") `
        "physical desktop pixels including Microsoft Pinyin candidate overlay"
    $actions.Add((Send-Key $owner.Process.Id `
        $ownerCommunityHandle "Space"))
    Wait-Condition -Description "room name candidate commit" -Seconds 15 `
        -Condition { (Get-ElementValue $createName) -ceq "房间" }

    $privateRoom = Find-ElementById -ProcessId $owner.Process.Id `
        -AutomationId "OnlineRooms.Create.Private"
    Invoke-Element $privateRoom
    if ((Get-ElementValue $createName) -cne "房间") {
        throw "Committed room name did not survive focus loss."
    }
    $ownerPassword = Find-ElementById -ProcessId $owner.Process.Id `
        -AutomationId "OnlineRooms.Create.Password" -TimeoutMilliseconds 10000
    Wait-Condition -Description "create password enabled" -Seconds 10 `
        -Condition { $ownerPassword.Current.IsEnabled }
    $actions.Add((Activate-ElementForKeyboardInput `
        $owner.Process.Id $ownerCommunityHandle $ownerPassword `
        "owner create password"))
    $ownerPasswordLengthBefore = Get-PasswordCommittedLength $ownerPassword
    $actions.Add((Set-PasswordViaWriteOnlyUia $ownerPassword "mima"))
    Wait-Condition -Description "create password direct ASCII commit" `
        -Seconds 15 -Condition {
        (Get-PasswordCommittedLength $ownerPassword) -eq 4
    }
    $ownerPasswordLengthAfter = Get-PasswordCommittedLength $ownerPassword
    $ownerPasswordExposure = @(
        Find-UiAutomationSecretExposure `
            -ProcessId $owner.Process.Id -Secret "mima")
    if ($ownerPasswordExposure.Count -ne 0) {
        throw "Create password leaked through UI Automation: " +
            ($ownerPasswordExposure -join "; ")
    }
    $captures.ownerCreatePassword = Capture-DesktopWindow `
        $ownerCommunity `
        (Join-Path $outputFullPath "owner-create-password-direct-input.png") `
        "physical desktop pixels; IME-active password field has no candidate overlay"
    Invoke-Element (Find-ElementById -ProcessId $owner.Process.Id `
        -AutomationId "OnlineRooms.Create.Submit")
    $createdState = Wait-HarnessState $endpoint {
        param($state)
        [bool]$state.roomCreated -and [bool]$state.room.isPrivate -and
        [bool]$state.room.resourcesReady
    } "private room creation" 120
    $roomNumber = [long]$createdState.room.roomNumber

    Invoke-Element $memberAccount
    $memberCommunity = Find-ElementById -ProcessId $member.Process.Id `
        -AutomationId "OnlineCommunity.Dialog" -TimeoutMilliseconds 30000
    $memberCommunityHandle = [IntPtr]$member.Process.MainWindowHandle
    Invoke-Element (Find-ElementById -ProcessId $member.Process.Id `
        -AutomationId "OnlineCommunity.Navigation.Rooms" `
        -TimeoutMilliseconds 15000)
    Invoke-Element (Find-ElementById -ProcessId $member.Process.Id `
        -AutomationId "OnlineRooms.Room.$roomNumber.Join" `
        -TimeoutMilliseconds 60000)
    $memberPassword = Find-ElementById -ProcessId $member.Process.Id `
        -AutomationId "OnlineRooms.Join.Password" -TimeoutMilliseconds 15000
    $memberIme = Activate-MicrosoftPinyin `
        $member.Process.Id $memberCommunityHandle
    $actions.Add((Activate-ElementForKeyboardInput `
        $member.Process.Id $memberCommunityHandle $memberPassword `
        "member join password"))
    $memberPasswordLengthBefore = Get-PasswordCommittedLength $memberPassword
    $actions.Add((Set-PasswordViaWriteOnlyUia $memberPassword "mima"))
    Wait-Condition -Description "join password direct ASCII commit" `
        -Seconds 15 -Condition {
        (Get-PasswordCommittedLength $memberPassword) -eq 4
    }
    $memberPasswordLengthAfter = Get-PasswordCommittedLength $memberPassword
    $memberPasswordExposure = @(
        Find-UiAutomationSecretExposure `
            -ProcessId $member.Process.Id -Secret "mima")
    if ($memberPasswordExposure.Count -ne 0) {
        throw "Join password leaked through UI Automation: " +
            ($memberPasswordExposure -join "; ")
    }
    $captures.memberJoinPassword = Capture-DesktopWindow `
        $memberCommunity `
        (Join-Path $outputFullPath "member-join-password-direct-input.png") `
        "physical desktop pixels; IME-active password field has no candidate overlay"
    Invoke-Element (Find-ElementById -ProcessId $member.Process.Id `
        -AutomationId "OnlineRooms.Join.Submit")
    $joinedState = Wait-HarnessState $endpoint {
        param($state)
        [int]$state.memberJoinPasswordSubmissionCount -eq 1 -and
        @($state.activeMemberIds) -contains 4202
    } "member password join" 120

    Wait-Condition -Description `
        "member community close after joined chart opens" `
        -Seconds 60 -Condition {
        try {
            [void](Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineCommunity.Dialog" `
                -TimeoutMilliseconds 300)
            return $false
        }
        catch {
            return $true
        }
    }
    if ($StopAfterCorrectPasswordJoin) {
        $memberMainWindow =
            [Windows.Automation.AutomationElement]::FromHandle(
                [IntPtr]$member.Process.MainWindowHandle)
        $captures.memberJoinedEditor = Capture-DesktopWindow `
            $memberMainWindow `
            (Join-Path $outputFullPath "member-correct-password-joined-editor.png") `
            "physical desktop pixels after correct password and complete room resources open the editor"
        $fixtureAfter = (Get-FileHash -LiteralPath `
            $fixtureFullPath -Algorithm SHA256).Hash
        $installerAfter = (Get-FileHash -LiteralPath `
            $installerPath -Algorithm SHA256).Hash
        if ($fixtureBefore -cne $fixtureAfter) {
            throw "Real MC fixture changed during correct-password GUI verification."
        }
        if ($installerBefore -cne $installerAfter) {
            throw "Frozen WPF installer changed during correct-password GUI verification."
        }
        $focusedEvidence = [ordered]@{
            schema =
                "lumachart.windows.avalonia.correct-password-join-gui-evidence.v1"
            generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
            status = "passed"
            formalMigrationAuthority = [bool]$FormalAuthority
            completion = [ordered]@{
                windowsAvaloniaCanReplaceWpf = $false
                userManualReplacementApprovalReceived = $false
                nextPlatformAuthorized = $false
            }
            buildBoundary = [ordered]@{
                platform = "Windows Avalonia only"
                configuration = "Release"
                ollvm = $false
                obfuscation = $false
                packing = $false
                codeVirtualization = $false
                aot = $false
            }
            inputBoundary = [ordered]@{
                ownerRoomNameInput = "physical Microsoft Pinyin"
                passwordInput =
                    "write-only UI Automation provider; readable value remains empty"
                enterKeySent = $false
                ownerLayout = $ownerIme
                memberLayout = $memberIme
                injectedActions = $actions.ToArray()
            }
            password = [ordered]@{
                createLengthBefore = $ownerPasswordLengthBefore
                createLengthAfter = $ownerPasswordLengthAfter
                joinLengthBefore = $memberPasswordLengthBefore
                joinLengthAfter = $memberPasswordLengthAfter
                createSecretExposureCount = $ownerPasswordExposure.Count
                joinSecretExposureCount = $memberPasswordExposure.Count
                serverPasswordSubmissionCount =
                    [int]$joinedState.memberJoinPasswordSubmissionCount
            }
            online = [ordered]@{
                endpointIsLoopback = $true
                roomNumber = $roomNumber
                roomName = [string]$joinedState.room.name
                roomPrivate = [bool]$joinedState.room.isPrivate
                resourcesReady = [bool]$joinedState.room.resourcesReady
                resourceEntryCount = [int]$joinedState.resourceEntryCount
                resourceCommitCount = [int]$joinedState.resourceCommitCount
                activeMemberIds = @($joinedState.activeMemberIds)
                memberOpenedEditor = $true
                communitySurfaceClosed = $true
                finalServerState = $joinedState
            }
            integrity = [ordered]@{
                realChartFixture = [ordered]@{
                    path = $fixtureFullPath
                    sha256Before = $fixtureBefore
                    sha256After = $fixtureAfter
                    unchanged = $true
                }
                releasedWpfInstaller = [ordered]@{
                    path = $installerPath
                    sha256Before = $installerBefore
                    sha256After = $installerAfter
                    unchanged = $true
                }
            }
            screenshots = $captures
        }
        $focusedEvidencePath = Join-Path $outputFullPath "evidence.json"
        $focusedEvidence | ConvertTo-Json -Depth 50 |
            Set-Content -LiteralPath $focusedEvidencePath -Encoding utf8NoBOM
        Write-Output "Windows Avalonia correct-password GUI capture: passed"
        Write-Output "Evidence: $focusedEvidencePath"
        return
    }
    $memberCommunity = Open-RoomCommunity $member
    $memberCommunityHandle = [IntPtr]$member.Process.MainWindowHandle
    $chat = Find-ElementById -ProcessId $member.Process.Id `
        -AutomationId "OnlineRooms.Active.ChatText" -TimeoutMilliseconds 60000
    $actions.Add((Activate-ElementForKeyboardInput `
        $member.Process.Id $memberCommunityHandle $chat `
        "member chat cancellation"))
    [void](Activate-MicrosoftPinyin `
        $member.Process.Id $memberCommunityHandle)
    $actions.Add((Send-Ascii $member.Process.Id `
        $memberCommunityHandle "quxiao"))
    Start-Sleep -Milliseconds 350
    $chatBeforeCancel = Get-ElementValue $chat
    if ($chatBeforeCancel -cne "") {
        throw "Chat pinyin committed before cancellation: '$chatBeforeCancel'."
    }
    $captures.memberChatBeforeCancel = Capture-DesktopWindow `
        $memberCommunity `
        (Join-Path $outputFullPath "member-chat-ime-before-cancel.png") `
        "physical desktop pixels including cancelable Microsoft Pinyin composition"
    $actions.Add((Send-Key $member.Process.Id `
        $memberCommunityHandle "Escape"))
    Wait-Condition -Description "chat composition cancellation" `
        -Seconds 15 -Condition {
        try {
            $current = Find-ElementById -ProcessId $member.Process.Id `
                -AutomationId "OnlineRooms.Active.ChatText" `
                -TimeoutMilliseconds 500
            (Get-ElementValue $current) -ceq ""
        }
        catch { $false }
    }
    $chat = Find-ElementById -ProcessId $member.Process.Id `
        -AutomationId "OnlineRooms.Active.ChatText" -TimeoutMilliseconds 2000
    $chatAfterCancel = Get-ElementValue $chat

    $actions.Add((Activate-ElementForKeyboardInput `
        $member.Process.Id $memberCommunityHandle $chat `
        "member chat commit"))
    $actions.Add((Send-Ascii $member.Process.Id `
        $memberCommunityHandle "liaotian"))
    Start-Sleep -Milliseconds 350
    $chatBeforeCommit = Get-ElementValue $chat
    if ($chatBeforeCommit -cne "") {
        throw "Chat pinyin committed before candidate selection: '$chatBeforeCommit'."
    }
    $captures.memberChatComposition = Capture-DesktopWindow `
        $memberCommunity `
        (Join-Path $outputFullPath "member-chat-ime-composition.png") `
        "physical desktop pixels including Microsoft Pinyin chat composition"
    $actions.Add((Send-Key $member.Process.Id `
        $memberCommunityHandle "Space"))
    Wait-Condition -Description "chat candidate commit" -Seconds 15 `
        -Condition { (Get-ElementValue $chat) -ceq "聊天" }
    Focus-Element (Find-ElementById -ProcessId $member.Process.Id `
        -AutomationId "OnlineRooms.Active.Refresh") `
        "room refresh button after chat commit"
    $chatAfterFocusLoss = Get-ElementValue $chat
    if ($chatAfterFocusLoss -cne "聊天") {
        throw "Committed chat did not survive focus loss."
    }
    $captures.memberChatCommitted = Capture-DesktopWindow `
        $memberCommunity `
        (Join-Path $outputFullPath "member-chat-ime-committed.png") `
        "physical desktop pixels after committed chat survives focus loss"
    Invoke-Element (Find-ElementById -ProcessId $member.Process.Id `
        -AutomationId "OnlineRooms.Active.ChatSend")
    $chatState = Wait-HarnessState $endpoint {
        param($state)
        [int]$state.chatCount -eq 1 -and
        [string]$state.messages[0].message -ceq "聊天"
    } "exact Chinese chat delivery" 60
    $ownerCommunity = Open-RoomCommunity $owner
    [void](Find-ElementByName -ProcessId $owner.Process.Id `
        -Name "聊天" -TimeoutMilliseconds 60000)
    $ownerHeaderSummary = Find-ElementById -ProcessId $owner.Process.Id `
        -AutomationId "OnlineRooms.Active.HeaderSummary" `
        -TimeoutMilliseconds 60000
    Wait-Condition -Description "owner room header live member count" `
        -Seconds 30 -Condition {
            [string]$ownerHeaderSummary.Current.HelpText -match `
                '^MemberCount=2; MaximumMembers=8; RoomId='
        }
    $ownerHeaderName = [string]$ownerHeaderSummary.Current.Name
    $ownerHeaderHelpText = [string]$ownerHeaderSummary.Current.HelpText
    if ($ownerHeaderName -notlike "2/8 人*") {
        throw "Owner room header did not refresh to 2/8: '$ownerHeaderName'."
    }
    $captures.ownerReceivedChat = Capture-DesktopWindow `
        $ownerCommunity `
        (Join-Path $outputFullPath "owner-received-ime-chat.png") `
        "physical desktop pixels after owner receives exact Chinese chat and 2/8 live member count"

    $fixtureAfter = (Get-FileHash -LiteralPath `
        $fixtureFullPath -Algorithm SHA256).Hash
    $installerAfter = (Get-FileHash -LiteralPath `
        $installerPath -Algorithm SHA256).Hash
    if ($fixtureBefore -cne $fixtureAfter) {
        throw "Real MC fixture changed during online IME GUI verification."
    }
    if ($installerBefore -cne $installerAfter) {
        throw "Frozen WPF installer changed during online IME GUI verification."
    }

    $evidence = [ordered]@{
        schema = "lumachart.windows.avalonia.two-client-online-ime-gui-evidence.v2"
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        status = "passed"
        formalMigrationAuthority = [bool]$FormalAuthority
        completion = [ordered]@{
            windowsAvaloniaCanReplaceWpf = $false
            userManualReplacementApprovalReceived = $false
            nextPlatformAuthorized = $false
        }
        buildBoundary = [ordered]@{
            platform = "Windows Avalonia only"
            configuration = "Release"
            ollvm = $false
            obfuscation = $false
            packing = $false
            codeVirtualization = $false
            aot = $false
        }
        inputBoundary = [ordered]@{
            inputMethod = "Microsoft Pinyin"
            ownerLayout = $ownerIme
            memberLayout = $memberIme
            uiAutomationActionsUsed = $true
            win32KeyboardInputInjectionUsed = $true
            win32MouseInputInjectionUsed = $true
            hardwareKeyboardInputClaimed = $false
            hardwareMouseInputClaimed = $false
            enterKeySent = $false
            injectedActions = $actions.ToArray()
            roomName = [ordered]@{
                pinyin = "fangjian"
                beforeCandidateSelection = $roomNameBeforeCommit
                committed = "房间"
                survivedFocusLoss = $true
            }
            createPassword = [ordered]@{
                imeEnabled = $false
                lengthBefore = $ownerPasswordLengthBefore
                lengthAfter = $ownerPasswordLengthAfter
                candidateCommitRequired = $false
                uiAutomationSecretExposureCount =
                    $ownerPasswordExposure.Count
            }
            joinPassword = [ordered]@{
                imeEnabled = $false
                lengthBefore = $memberPasswordLengthBefore
                lengthAfter = $memberPasswordLengthAfter
                candidateCommitRequired = $false
                uiAutomationSecretExposureCount =
                    $memberPasswordExposure.Count
                serverPasswordSubmissionCount =
                    [int]$joinedState.memberJoinPasswordSubmissionCount
            }
            chatCancel = [ordered]@{
                pinyin = "quxiao"
                beforeEscape = $chatBeforeCancel
                afterEscape = $chatAfterCancel
                roomSurfaceRemainedOpen = $true
            }
            chatCommitAndSend = [ordered]@{
                pinyin = "liaotian"
                beforeCandidateSelection = $chatBeforeCommit
                afterFocusLoss = $chatAfterFocusLoss
                serverMessage = [string]$chatState.messages[0].message
                ownerReceived = $true
            }
        }
        online = [ordered]@{
            endpointIsLoopback = $true
            roomNumber = $roomNumber
            roomName = [string]$chatState.room.name
            roomPrivate = [bool]$chatState.room.isPrivate
            activeMemberIds = @($chatState.activeMemberIds)
            resourceEntryCount = [int]$chatState.resourceEntryCount
            resourceCommitCount = [int]$chatState.resourceCommitCount
            ownerHeader = [ordered]@{
                name = $ownerHeaderName
                helpText = $ownerHeaderHelpText
                displayedMemberCount = 2
                authoritativeMemberCount =
                    @($chatState.activeMemberIds).Count
                maximumMembers = [int]$chatState.room.maximumMembers
                consistent = $true
            }
            finalServerState = $chatState
        }
        integrity = [ordered]@{
            realChartFixture = [ordered]@{
                path = $fixtureFullPath
                sha256Before = $fixtureBefore
                sha256After = $fixtureAfter
                unchanged = $true
            }
            releasedWpfInstaller = [ordered]@{
                path = $installerPath
                sha256Before = $installerBefore
                sha256After = $installerAfter
                unchanged = $true
            }
            keyboardImeProbe = [ordered]@{
                path = $keyboardImeProbeFullPath
                bytes = (Get-Item -LiteralPath `
                    $keyboardImeProbeFullPath).Length
                sha256 = (Get-FileHash -LiteralPath `
                    $keyboardImeProbeFullPath -Algorithm SHA256).Hash
            }
        }
        screenshots = $captures
    }
    $evidencePath = Join-Path $outputFullPath "evidence.json"
    $evidence | ConvertTo-Json -Depth 50 |
        Set-Content -LiteralPath $evidencePath -Encoding utf8NoBOM
    Write-Output "Windows Avalonia online IME GUI capture: passed"
    Write-Output "Evidence: $evidencePath"
}
catch {
    $failure = [ordered]@{
        generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        message = $_.Exception.Message
        exception = $_.Exception.ToString()
        serverState = $null
    }
    try {
        if ($endpoint) {
            $failure.serverState = Get-HarnessState $endpoint
        }
    }
    catch { }
    $failure | ConvertTo-Json -Depth 30 |
        Set-Content -LiteralPath `
            (Join-Path $outputFullPath "failure.json") `
            -Encoding utf8NoBOM
    throw
}
finally {
    foreach ($client in @($member, $owner)) {
        if ($client -and $client.Process) {
            try {
                if (-not $client.Process.HasExited) {
                    [void]$client.Process.CloseMainWindow()
                    if (-not $client.Process.WaitForExit(10000)) {
                        $client.Process.Kill($true)
                        [void]$client.Process.WaitForExit(5000)
                    }
                }
            }
            catch { }
            finally {
                $client.Process.Dispose()
            }
        }
    }
    if ($server) {
        try {
            if (-not $server.HasExited) {
                $server.Kill($true)
                [void]$server.WaitForExit(5000)
            }
            $stdout = $server.StandardOutput.ReadToEnd()
            $stderr = $server.StandardError.ReadToEnd()
            ($stdout + $stderr) |
                Set-Content -LiteralPath $serverLogPath -Encoding utf8NoBOM
        }
        catch { }
        finally {
            $server.Dispose()
        }
    }
}
