; ─────────────────────────────────────────────────────────────────────────────
; Inno Setup Script — Wellness on Wellington
; ─────────────────────────────────────────────────────────────────────────────
; Run with Inno Setup 6 on Windows:
;   iscc WellnessOnWellington_Setup.iss
; Or open in the Inno Setup IDE and press Compile (Ctrl+F9).
;
; Prerequisites:
;   1. flutter build windows --release  has already been run.
;   2. .env has been copied into the Release folder (see README steps).
;   3. The app_icon.ico is present at windows\runner\resources\app_icon.ico.
;
; Output: installer\Output\WellnessOnWellington_Setup.exe
; ─────────────────────────────────────────────────────────────────────────────

#define AppName      "Wellness on Wellington"
#define AppVersion   "1.0.0"
#define AppPublisher "Wellness on Wellington"
#define AppExeName   "wellness_on_wellington.exe"
; Path to the Flutter Windows release build — relative to this .iss file,
; which lives one level up from the project root, so we go up one folder first.
#define ReleaseDir   "..\build\windows\x64\runner\Release"

[Setup]
; ── Identity ─────────────────────────────────────────────────────────────────
AppId={{A3F2C1D4-7E6B-4A9F-B8C2-1D3E5F7A9B0C}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://wellnessonwellington.com
AppSupportURL=https://wellnessonwellington.com
AppUpdatesURL=https://wellnessonwellington.com

; ── Install location ──────────────────────────────────────────────────────────
; Defaults to C:\Program Files\Wellness on Wellington
DefaultDirName={autopf}\{#AppName}
; No start-menu folder customisation needed — we create one entry below.
DefaultGroupName={#AppName}
; Allow the user to choose a different install directory.
DisableDirPage=no

; ── Output ────────────────────────────────────────────────────────────────────
; The finished installer lands in installer\Output\ next to this .iss file.
OutputDir=Output
OutputBaseFilename=WellnessOnWellington_Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
; Use the modern wizard style (Inno Setup 6+).
WizardStyle=modern

; ── Platform ──────────────────────────────────────────────────────────────────
; Require 64-bit Windows 10 or later.
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763

; ── Privileges ────────────────────────────────────────────────────────────────
; Install to Program Files — requires admin elevation.
PrivilegesRequired=admin

; ── Uninstall ─────────────────────────────────────────────────────────────────
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; Desktop shortcut is opt-in (unchecked by default).
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
; ── Main executable ───────────────────────────────────────────────────────────
Source: "{#ReleaseDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; ── Flutter engine DLLs ───────────────────────────────────────────────────────
Source: "{#ReleaseDir}\flutter_windows.dll";     DestDir: "{app}"; Flags: ignoreversion
Source: "{#ReleaseDir}\msvcp140.dll";            DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#ReleaseDir}\vcruntime140.dll";        DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#ReleaseDir}\vcruntime140_1.dll";      DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; ── SQLite native library ─────────────────────────────────────────────────────
Source: "{#ReleaseDir}\sqlite3.dll";             DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; ── Flutter plugin DLLs (connectivity, shared_preferences, url_launcher …) ───
Source: "{#ReleaseDir}\connectivity_plus_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#ReleaseDir}\shared_preferences_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#ReleaseDir}\url_launcher_windows_plugin.dll";      DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; ── Flutter data directory (fonts, assets, shaders) ──────────────────────────
Source: "{#ReleaseDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; ── .env secrets file (must be placed in Release folder before running iscc) ──
Source: "{#ReleaseDir}\.env"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Start Menu shortcut
Name: "{group}\{#AppName}";          Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"
; Start Menu uninstall shortcut
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
; Optional desktop shortcut (only created if the task above is ticked)
Name: "{autodesktop}\{#AppName}";    Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
; Offer to launch the app immediately after installation.
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Remove the SQLite database and any runtime files the app writes to its folder.
Type: filesandordirs; Name: "{app}\data\databases"
