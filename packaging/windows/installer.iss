; E — Windows installer (Inno Setup 6).
; Built in CI with:
;   ISCC /DMyAppVersion=<ver> packaging\windows\installer.iss
; The installed binary is e.exe (project name in pubspec.yaml).
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#define MyAppName "E"

[Setup]
AppId={{3E4B5C6D-7E8F-4A1B-9C2D-E5F6A7B8C9D0}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=E Contributors
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir={#SourcePath}\..\..\installer-output
OutputBaseFilename=e-windows-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourcePath}\..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\e.exe"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\e.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; Flags: unchecked

[Run]
Filename: "{app}\e.exe"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
