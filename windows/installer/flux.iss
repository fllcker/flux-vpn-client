; Inno Setup script for Flux — installer that updates in place instead of
; the current portable Release-folder build (see ROADMAP.md, трек 13).
;
; Build with: iscc windows\installer\flux.iss
; (run scripts\build_release.ps1 first — see comment in that file for why.)
;
; #AppVersion is passed in from the build script via /DAppVersion=... so the
; installer version always matches pubspec.yaml without editing this file by
; hand on every release.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; Fixed GUID — this is what makes a later run of the installer recognize an
; existing install as "the same app" and update it in place instead of
; creating a second, parallel installation. Never regenerate this once a
; version has shipped.
AppId={{8EF5C60B-CBFC-4B32-9EF3-267C79268C4E}
AppName=Flux
AppVersion={#AppVersion}
AppPublisher=Flux
DefaultDirName={localappdata}\Flux
; Per-user install, no admin prompt for the installer itself — TUN mode
; already asks for elevation separately at runtime when needed (see
; lib/engines/xray/windows_elevation.dart), the installer doesn't need it.
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
OutputBaseFilename=FluxSetup-{#AppVersion}
OutputDir=..\..\build\installer
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Overwriting flux.exe/DLLs while the app is running would otherwise fail —
; Inno's Restart Manager integration detects processes holding a lock on
; files being replaced (no named mutex needed) and asks to close them.
CloseApplications=force
RestartApplications=no
UninstallDisplayIcon={app}\flux.exe

[Files]
; Whole Release output — xray-core/sing-box (assets/xray, assets/sing-box)
; are already copied in here by windows/CMakeLists.txt's install() rules, so
; this one line bundles everything the portable build has today.
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Flux"; Filename: "{app}\flux.exe"
Name: "{autodesktop}\Flux"; Filename: "{app}\flux.exe"; Tasks: desktopicon

[Tasks]
Name: desktopicon; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Дополнительные значки:"

[Run]
Filename: "{app}\flux.exe"; Description: "Запустить Flux"; Flags: nowait postinstall skipifsilent

; Deliberately NOT removing %AppData%\flux (settings, profile.json,
; ping_cache.json) on uninstall — that's user data, not part of the
; installation, see ROADMAP.md трек 13.
