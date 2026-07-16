; ============================================================
;  SIMUL — Windows installer (Inno Setup script)
; ============================================================
; This file is ready to compile as-is, as long as your folder
; layout matches what's described in the tutorial below.
;
; 1. Install Inno Setup (free): https://jrsoftware.org/isinfo.php
; 2. Put this .iss file, and the assets\simul.ico next to it,
;    ONE LEVEL ABOVE your project's `build` folder — see the
;    tutorial for the exact layout.
; 3. Open this file in Inno Setup -> Build -> Compile.
; 4. Output: Output\simul-setup.exe

#define MyAppName "SIMUL"
#define MyAppVersion "1.3.4"
#define MyAppPublisher "Arsalan Kaleem"
#define MyAppURL "https://github.com/ArsalanKaleem/simul-watch-together-app"
#define MyAppExeName "simul.exe"

[Setup]
AppId={{B7E2B7B0-6C3B-4B7E-9C7A-2F1B9F5E3A11}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=simul-setup
SetupIconFile=assets\simul.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
; Everything Flutter produced for the Windows release — the exe, the data\
; folder, and every required DLL — gets copied as-is. Do not cherry-pick
; individual files here; the app needs the whole folder to run.
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
