; Funzor 安装包脚本（需要 Inno Setup 7.1.1+）
; 本地构建：pwsh scripts/build-installer.ps1
; CI 构建：.github/workflows/release.yml 会传入 /DAppVersion、/DPublishDir
;          以及 /DOutputBaseFilename

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#ifndef PublishDir
  #define PublishDir "..\artifacts\publish"
#endif

#ifndef OutputBaseFilename
  #define OutputBaseFilename "FunzorSetup-v" + AppVersion + "-x64"
#endif

#define AppName "Funzor"
#define AppExe "Funzor.exe"

[Setup]
; 固定 GUID，永不修改：一旦改了就变成并存两个程序
AppId={{6F3B2C0A-5D4E-4A8B-9C71-2D5E8F1A7B34}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=Output
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#AppExe}
CloseApplications=yes
RestartApplications=no
; 升级只覆盖程序文件，{app} 之外的用户数据不会被改动

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
; 以后要做中文安装界面：把官方 ChineseSimplified.isl 放到 installer\lang\ 下，再取消下面一行注释
; Name: "chinesesimplified"; MessagesFile: "lang\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; 静默升级后也重新拉起程序，更新完成用户直接回到应用
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait
