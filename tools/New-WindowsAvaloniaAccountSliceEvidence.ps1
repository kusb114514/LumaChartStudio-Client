param(
    [Parameter(Mandatory = $true)][string]$ArtifactRoot,
    [Parameter(Mandatory = $true)][string]$RepositoryRoot
)

$ErrorActionPreference = "Stop"
$artifact = [IO.Path]::GetFullPath($ArtifactRoot)
$repository = [IO.Path]::GetFullPath($RepositoryRoot)
if (-not (Test-Path -LiteralPath $artifact -PathType Container)) {
    throw "Artifact root does not exist: $artifact"
}

function Get-FileEvidence([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "Required evidence file is missing: $full"
    }
    $item = Get-Item -LiteralPath $full
    return [ordered]@{
        path = $full
        bytes = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
}

function Get-SourceEvidence([string]$RelativePath) {
    $file = Get-FileEvidence (Join-Path $repository $RelativePath)
    $file.path = $RelativePath.Replace("\", "/")
    return $file
}

function Get-BuildEvidence([string]$Name) {
    $file = Get-FileEvidence (Join-Path $artifact $Name)
    $content = Get-Content -LiteralPath (Join-Path $artifact $Name) -Raw
    if ($content -notmatch "0 个警告" -or $content -notmatch "0 个错误") {
        throw "Strict build log is not clean: $Name"
    }
    return [ordered]@{
        status = "passed"
        warnings = 0
        errors = 0
        log = $file
    }
}

$specsPath = Join-Path $artifact "specs-evidence.json"
$specs = Get-Content -LiteralPath $specsPath -Raw | ConvertFrom-Json
if ($specs.status -ne "passed" -or $specs.checks.Count -ne 308 -or
    @($specs.checks | Where-Object { -not $_.passed }).Count -ne 0) {
    throw "Avalonia Specs evidence is not 308/308 passed."
}
$mainSpecsPath = Join-Path $artifact "main-specs.log"
$mainSpecsText = Get-Content -LiteralPath $mainSpecsPath -Raw
if ($mainSpecsText -notmatch "79/79 specs passed") {
    throw "Main Specs log is not 79/79 passed."
}
$guiPath = Join-Path $artifact "account-gui-evidence.json"
$gui = Get-Content -LiteralPath $guiPath -Raw | ConvertFrom-Json
if ($gui.status -ne "passed" -or
    $gui.captchaReadyStatus -notlike "请输入用户名、密码和图片中的*" -or
    $gui.registration.captchaReadyStatus -notlike "请输入图片中的*" -or
    $gui.resetPassword.captchaReadyStatus -notlike "请输入图片中的*") {
    throw "Account GUI evidence is incomplete."
}

$sourceFiles = @(
    "LumaChart.Online\OnlineAccountSession.cs",
    "LumaChart.Avalonia\Infrastructure\AvaloniaAppPaths.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsAvaloniaAppStorageLocations.cs",
    "LumaChart.Avalonia\Infrastructure\WindowsDpapiSessionTokenStore.cs",
    "LumaChart.Avalonia\Services\WindowsOnlineAccountHost.cs",
    "LumaChart.Avalonia\Services\AvaloniaWorkspaceController.cs",
    "LumaChart.Avalonia\ViewModels\MainWindowViewModel.cs",
    "LumaChart.Avalonia\Dialogs\OnlineAccountDialog.cs",
    "LumaChart.Avalonia\MainWindow.cs",
    "LumaChart.Avalonia\LumaChart.Avalonia.csproj",
    "LumaChart.Avalonia\server-endpoint.txt",
    "LumaChart.Avalonia.Specs\WindowsAccountSessionSpecs.cs",
    "LumaChart.Avalonia.Specs\Program.cs",
    "tools\Capture-WindowsAvaloniaAccountGui.ps1",
    "tools\New-WindowsAvaloniaAccountSliceEvidence.ps1")

$previousAuthority = Get-FileEvidence (Join-Path $repository (
    "artifacts\windows-avalonia-export-modes-slice-20260723-r1\evidence.json"))
$installer = Get-FileEvidence (Join-Path $repository "release\LumaChartStudio-Setup.exe")
if ($installer.sha256 -ne "02C1184E6F3CF12DD0BECD323BF64B5B698ADA38C89C572D48DE60527582EDA4") {
    throw "Frozen WPF installer hash changed."
}

$document = [ordered]@{
    schema = "lumachart.windows.avalonia.slice-evidence.v24"
    generatedUtc = [DateTimeOffset]::UtcNow.ToString("O")
    status = "passed"
    authority = [ordered]@{
        slice = "account-session-and-authentication-ui"
        previous = $previousAuthority
        supersedesPreviousForCurrentWorktree = $true
    }
    scope = [ordered]@{
        platform = "Windows Avalonia only"
        otherPlatformsBuiltInstalledOrTested = $false
        productionServerDeployed = $false
        frozenWpfInstallerModified = $false
        ollvmRequired = $false
        ollvmDisposition = "Explicitly waived by the user for the future open-source Avalonia client."
    }
    baseline = [ordered]@{
        wpfVersion = "1.1.0"
        productionServerRelease = "20260722005907"
        frozenInstaller = $installer
    }
    builds = [ordered]@{
        application = Get-BuildEvidence "build-application.log"
        avalonia = Get-BuildEvidence "build-avalonia.log"
        avaloniaSpecs = Get-BuildEvidence "build-avalonia-specs.log"
    }
    tests = [ordered]@{
        avaloniaSpecs = [ordered]@{
            status = "passed"
            passed = 308
            total = 308
            evidence = Get-FileEvidence $specsPath
            accountChecks = @(
                $specs.checks |
                    Where-Object { $_.name -like "account-*" -or $_.name -like "windows-dpapi-*" -or
                        $_.name -like "windows-online-endpoint-*" -or
                        $_.name -like "windows-avalonia-new-chart-*" } |
                    ForEach-Object { [ordered]@{ name = $_.name; passed = [bool]$_.passed; detail = $_.detail } })
        }
        mainSpecs = [ordered]@{
            status = "passed"
            passed = 79
            total = 79
            log = Get-FileEvidence $mainSpecsPath
        }
    }
    account = [ordered]@{
        sharedSession = [ordered]@{
            captcha = $true
            login = $true
            register = $true
            emailVerificationCode = $true
            passwordReset = $true
            restore = $true
            logout = $true
            restore401ClearsToken = $true
            restoreTransportFailurePreservesToken = $true
            invalidLoginResponseRejected = $true
        }
        windowsSecurity = [ordered]@{
            dpapiCurrentUser = $true
            plaintextPasswordStored = $false
            tokenVisibleOnlyAfterProtectedWrite = $true
            corruptCiphertextFailsClosed = $true
            remotePlaintextHttpRejected = $true
            loopbackDevelopmentHttpAllowed = $true
        }
        gui = [ordered]@{
            status = "passed"
            endpoint = $gui.endpoint
            productionMutationPerformed = $false
            operation = "Read-only production captcha challenges; no credentials or email codes submitted."
            mouseInputUsed = [bool]$gui.mouseInputUsed
            keyboardInputUsed = [bool]$gui.keyboardInputUsed
            evidence = Get-FileEvidence $guiPath
            screenshots = [ordered]@{
                login = Get-FileEvidence (Join-Path $artifact "account-login.png")
                register = Get-FileEvidence (Join-Path $artifact "account-register.png")
                resetPassword = Get-FileEvidence (Join-Path $artifact "account-reset-password.png")
            }
        }
        newChartCreatorMatchesWpf = $true
    }
    source = @($sourceFiles | ForEach-Object { Get-SourceEvidence $_ })
    remainingDifferences = @(
        "No credential-backed real account login was performed in this slice; transport and state installation are covered by isolated fake HTTP specs.",
        "Profile editing, avatar, email/password changes, tags, following/followers/friends and notifications remain to be migrated.",
        "Room directory, invitations, chat, members, permissions, resources and live revision/delta UI remain to be migrated.",
        "The Avalonia account surface is currently a modal Window rather than the WPF in-shell startup overlay; final visual parity remains open.",
        "Installer/update/uninstall, two-client online, multi-resolution and final 60/120 Hz completion gates remain open."
    )
    completion = [ordered]@{
        featureMatrixAllPassed = $false
        twoClientWindowsOnlinePassed = $false
        windowsAvaloniaCanReplaceWpf = $false
        userConfirmedReplacement = $false
    }
}

$output = Join-Path $artifact "evidence.json"
$document | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $output -Encoding utf8NoBOM
$final = Get-FileEvidence $output
[ordered]@{
    status = "passed"
    evidence = $final
    avaloniaSpecs = "308/308"
    mainSpecs = "79/79"
} | ConvertTo-Json -Depth 5
