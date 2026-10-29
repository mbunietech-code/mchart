; One-file Windows installer (MChart-Setup.exe), built with Inno Setup 6:
;   ISCC.exe /DAppVersion=1.0.12 windows\installer\mchart.iss
; after `flutter build windows --release`. Replaces the MSI (mchart.wxs) as
; what the downloads page offers; the AppId must never change between
; releases so new versions upgrade in place.

#ifndef AppVersion
  #define AppVersion "1.0.12"
#endif
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{5E0C3B8A-6B1E-4F0B-9D7C-4D2B8C1A9E77}
AppName=MChart
AppVersion={#AppVersion}
AppVerName=MChart {#AppVersion}
AppPublisher=Mbunietech Technologies Limited
AppPublisherURL=https://chart.mbunie.tech
DefaultDirName={autopf}\MChart
DefaultGroupName=MChart
DisableProgramGroupPage=yes
; Installs for the current user without admin rights; admins may choose all users.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile=license.rtf
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\mchart.exe
OutputDir=..\..\build\installer
OutputBaseFilename=MChart-Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\MChart"; Filename: "{app}\mchart.exe"
Name: "{group}\Uninstall MChart"; Filename: "{uninstallexe}"
Name: "{autodesktop}\MChart"; Filename: "{app}\mchart.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\mchart.exe"; Description: "{cm:LaunchProgram,MChart}"; Flags: nowait postinstall skipifsilent
; The in-app updater runs this setup with /SILENT: start the new version after.
Filename: "{app}\mchart.exe"; Flags: nowait; Check: WizardSilent
