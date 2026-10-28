#ifndef SourceDir
  #error SourceDir must point to the published Windows Avalonia application directory.
#endif
#ifndef OutputDir
  #error OutputDir must point to a non-release installer output directory.
#endif
#ifndef IconFile
  #error IconFile must point to the installer icon.
#endif
#ifndef AppVersion
  #define AppVersion "1.1.0"
#endif
#ifndef AppFileVersion
  #define AppFileVersion "1.1.0.0"
#endif

#define AppName "LumaChart Studio Avalonia (Windows Preview)"
#define AppExeName "LumaChart.Avalonia.exe"
#define PublisherName "LumaChart"
#define PublisherUrl "https://lumachart.cc"
#define McProgId "LumaChartStudio.AvaloniaPreview.mc"
#define MczProgId "LumaChartStudio.AvaloniaPreview.mcz"
#define OsuProgId "LumaChartStudio.AvaloniaPreview.osu"
#define OszProgId "LumaChartStudio.AvaloniaPreview.osz"

[Setup]
; This preview identity deliberately coexists with the frozen WPF 1.1.0
; installation. It must not reuse the WPF AppId until replacement is approved.
AppId={{AE886E9E-335F-4F03-B891-75591AC6CB57}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#PublisherName}
AppPublisherURL={#PublisherUrl}
AppSupportURL={#PublisherUrl}
AppUpdatesURL={#PublisherUrl}
DefaultDirName={autopf}\LumaChart Studio Avalonia Preview
DefaultGroupName=LumaChart Studio Avalonia Preview
DisableDirPage=no
DisableProgramGroupPage=yes
AllowNoIcons=yes
OutputDir={#OutputDir}
OutputBaseFilename=LumaChartStudio-Avalonia-Preview-Setup
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
SetupLogging=yes
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousTasks=yes
DirExistsWarning=auto
ChangesAssociations=yes
VersionInfoVersion={#AppFileVersion}
VersionInfoCompany={#PublisherName}
VersionInfoDescription={#AppName} Windows Installer
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppFileVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "快捷方式："; Flags: checkedonce
Name: "fileassoc"; Description: "将 Avalonia 预览版加入 MC、MCZ、osu 和 OSZ 的“打开方式”"; GroupDescription: "文件关联："; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Dirs]
; Recoverable documents and export scratch now live per Windows user under
; %LOCALAPPDATA%\LumaChart Studio\Avalonia\Editing Cache. The legacy subtree
; beside the executable is no longer granted Users-modify; it is kept (readable,
; never removed by uninstall) only so the first launch after an upgrade can
; migrate a cache that earlier versions wrote there.
Name: "{app}\LumaChart Editing Cache"; Permissions: users-readexec; Flags: uninsneveruninstall

[Icons]
Name: "{autodesktop}\LumaChart Studio Avalonia Preview"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
; Do not replace the user's current default handler (normally the frozen WPF
; installation). Register only OpenWithProgids; Windows/user choice owns the
; default association and uninstall can remove this preview without orphaning it.
Root: HKA; Subkey: "Software\Classes\.mc\OpenWithProgids"; ValueType: string; ValueName: "{#McProgId}"; ValueData: ""; Flags: uninsdeletevalue; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#McProgId}"; ValueType: string; ValueName: ""; ValueData: "Malody MC 谱面"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#McProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"",0"; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#McProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Tasks: fileassoc

Root: HKA; Subkey: "Software\Classes\.mcz\OpenWithProgids"; ValueType: string; ValueName: "{#MczProgId}"; ValueData: ""; Flags: uninsdeletevalue; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#MczProgId}"; ValueType: string; ValueName: ""; ValueData: "Malody MCZ 谱包"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#MczProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"",0"; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#MczProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Tasks: fileassoc

Root: HKA; Subkey: "Software\Classes\.osu\OpenWithProgids"; ValueType: string; ValueName: "{#OsuProgId}"; ValueData: ""; Flags: uninsdeletevalue; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#OsuProgId}"; ValueType: string; ValueName: ""; ValueData: "osu!mania 谱面"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#OsuProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"",0"; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#OsuProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Tasks: fileassoc

Root: HKA; Subkey: "Software\Classes\.osz\OpenWithProgids"; ValueType: string; ValueName: "{#OszProgId}"; ValueData: ""; Flags: uninsdeletevalue; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#OszProgId}"; ValueType: string; ValueName: ""; ValueData: "osu! OSZ 谱包"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#OszProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"",0"; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\{#OszProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Tasks: fileassoc

[Run]
Filename: "{app}\{#AppExeName}"; Description: "启动 LumaChart Studio Avalonia Preview"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent
