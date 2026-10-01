; Inno Setup script for FlSony. Built by tool/package_windows.ps1, which
; passes AppVersion and SourceDir (the Flutter release folder).

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

[Setup]
; Never change AppId: it's how upgrades find the existing install.
AppId={{954EAA6D-261D-40B5-AECB-82C954A8839E}
AppName=FlSony
AppVersion={#AppVersion}
AppPublisher=Amey Reghu
AppPublisherURL=https://github.com/ameyreghu/flsony
AppSupportURL=https://github.com/ameyreghu/flsony/issues
; Per-user install by default (no admin prompt); {autopf} then means
; %LOCALAPPDATA%\Programs.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\FlSony
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile=..\..\LICENSE
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\flsony.exe
UninstallDisplayName=FlSony
OutputBaseFilename=FlSony-{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\FlSony"; Filename: "{app}\flsony.exe"
Name: "{autodesktop}\FlSony"; Filename: "{app}\flsony.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\flsony.exe"; Description: "{cm:LaunchProgram,FlSony}"; Flags: nowait postinstall skipifsilent
