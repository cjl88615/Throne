#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef AppVersionMajor
  #define AppVersionMajor "0"
#endif
#ifndef AppVersionMinor
  #define AppVersionMinor "0"
#endif
#ifndef AppVersionPatch
  #define AppVersionPatch "0"
#endif
#ifndef AppVersionBuild
  #define AppVersionBuild "0"
#endif

[Setup]
AppId={{A4F89B8E-2CF2-4D84-B7D2-7A6E9483C201}
AppName=TaliabuVPN
AppVersion={#AppVersion}
AppVerName=TaliabuVPN {#AppVersion}
AppPublisher=Taliabu
VersionInfoVersion={#AppVersionMajor}.{#AppVersionMinor}.{#AppVersionPatch}.{#AppVersionBuild}
VersionInfoProductName=TaliabuVPN
VersionInfoDescription=TaliabuVPN Setup
VersionInfoCopyright=Taliabu
SourceDir=..
OutputDir=deployment
OutputBaseFilename=TaliabuVPNSetup
SetupIconFile=res\Throne.ico
UninstallDisplayName=TaliabuVPN
UninstallDisplayIcon={app}\TaliabuVPN.exe
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={code:DefaultInstallDir}
DirExistsWarning=no
DisableProgramGroupPage=yes
ArchitecturesInstallIn64BitMode=win64
CloseApplications=force
RestartApplications=no
; Uninstall removes the associations TaliabuVPN registers at runtime, so Explorer has to reload them.
ChangesAssociations=yes
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMANumBlockThreads=4
; The default block is 4x the dictionary (256 MB), which would leave two of the four threads idle.
LZMABlockSize=118784

[Messages]
SelectDirBrowseLabel=To continue, click Next. If the folder you choose is not named TaliabuVPN, Setup creates a TaliabuVPN folder inside it, so uninstalling only ever removes TaliabuVPN's own folder.

[Files]
Source: "deployment\windows-amd64\*"; DestDir: "{app}"; Excludes: "*.pdb"; Flags: ignoreversion; Check: IsX64OS; MinVersion: 10.0.17763
Source: "deployment\windowslegacy-amd64\*"; DestDir: "{app}"; Excludes: "*.pdb"; Flags: ignoreversion; Check: IsX64OS; OnlyBelowVersion: 10.0.17763
Source: "deployment\windows-arm64\*"; DestDir: "{app}"; Excludes: "*.pdb"; Flags: ignoreversion; Check: IsArm64
Source: "deployment\windowslegacy-386\*"; DestDir: "{app}"; Excludes: "*.pdb"; Flags: ignoreversion; Check: IsX86OS

[Icons]
Name: "{autoprograms}\TaliabuVPN"; Filename: "{app}\TaliabuVPN.exe"
Name: "{autodesktop}\TaliabuVPN"; Filename: "{app}\TaliabuVPN.exe"

[Registry]
Root: HKA; Subkey: "Software\TaliabuVPN"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey

[UninstallDelete]
Type: files; Name: "{app}\updater.old"

[Run]
Filename: "{app}\TaliabuVPN.exe"; Description: "{cm:LaunchProgram,TaliabuVPN}"; Flags: postinstall nowait skipifsilent

[Code]
const
  LegacyUninstall = 'Microsoft\Windows\CurrentVersion\Uninstall\TaliabuVPN';

var
  DeleteUserData: Boolean;

// The NSIS installer was 32-bit, so on 64-bit Windows its HKLM keys sit under WOW6432Node of this installer's 64-bit view.
function LegacyKey(const SubKey: String): String;
begin
  if IsAdminInstallMode and Is64BitInstallMode then
    Result := 'Software\WOW6432Node\' + SubKey
  else
    Result := 'Software\' + SubKey;
end;

function LegacyValue(const SubKey, Name: String; var Value: String): Boolean;
begin
  if IsAdminInstallMode then
    Result := RegQueryStringValue(HKEY_LOCAL_MACHINE, LegacyKey(SubKey), Name, Value)
  else
    Result := RegQueryStringValue(HKEY_CURRENT_USER, LegacyKey(SubKey), Name, Value);
  Result := Result and (Value <> '');
end;

function SameAsApp(const Dir: String): Boolean;
begin
  Result := CompareText(RemoveBackslashUnlessRoot(Dir), RemoveBackslashUnlessRoot(ExpandConstant('{app}'))) = 0;
end;

// An NSIS install keeps its folder, since TaliabuVPN's config lives next to the exe.
function DefaultInstallDir(Param: String): String;
begin
  if LegacyValue('TaliabuVPN', 'InstallPath', Result) then
    Exit;
  if IsAdminInstallMode then
    Result := ExpandConstant('{autopf}\TaliabuVPN')
  else
    Result := ExpandConstant('{localappdata}\TaliabuVPN');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Dir, Probe: String;
  Created: Boolean;
begin
  Result := True;
  if CurPageID <> wpSelectDir then
    Exit;
  Dir := RemoveBackslashUnlessRoot(WizardDirValue);
  // Uninstalling can delete <dir>\config, so TaliabuVPN must get a folder of its own.
  if CompareText(ExtractFileName(Dir), 'TaliabuVPN') <> 0 then
  begin
    Dir := AddBackslash(Dir) + 'TaliabuVPN';
    WizardForm.DirEdit.Text := Dir;
  end;
  if IsAdminInstallMode then
    Exit;
  Created := not DirExists(Dir);
  Probe := AddBackslash(Dir) + '.throne-write-test';
  Result := ForceDirectories(Dir) and SaveStringToFile(Probe, '', False);
  DeleteFile(Probe);
  if Created then
    RemoveDir(Dir);
  if not Result then
    SuppressibleMsgBox('You do not have permission to install to "' + Dir + '".' + #13#10#13#10 +
      'Choose a different folder, or restart Setup and choose to install for all users.', mbError, MB_OK, IDOK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Dir: String;
begin
  if CurStep <> ssPostInstall then
    Exit;
  // Otherwise the NSIS installer's Apps & Features entry and uninstall.exe outlive the migration and remove these files.
  if LegacyValue(LegacyUninstall, 'InstallLocation', Dir) and SameAsApp(Dir) then
    if IsAdminInstallMode then
      RegDeleteKeyIncludingSubkeys(HKEY_LOCAL_MACHINE, LegacyKey(LegacyUninstall))
    else
      RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, LegacyKey(LegacyUninstall));
  DeleteFile(ExpandConstant('{app}\uninstall.exe'));
end;

procedure StopTaliabuVPN;
var
  Locator, Service, Processes, Process: Variant;
  Prefix, ExePath: String;
  I: Integer;
  Stopped: Boolean;
begin
  Prefix := Lowercase(AddBackslash(ExpandConstant('{app}')));
  Stopped := False;
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Service := Locator.ConnectServer('.', 'root\CIMV2');
    Processes := Service.ExecQuery('SELECT * FROM Win32_Process WHERE Name = ''TaliabuVPN.exe'' OR Name = ''ThroneCore.exe''');
    for I := 0 to Processes.Count - 1 do
    begin
      Process := Processes.ItemIndex(I);
      if not VarIsNull(Process.ExecutablePath) then
      begin
        // Pascal Script converts a Variant to String on assignment, but not when passed as a String parameter.
        ExePath := Process.ExecutablePath;
        if Pos(Prefix, Lowercase(ExePath)) = 1 then
        begin
          Process.Terminate(0);
          Stopped := True;
        end;
      end;
    end;
  except
    Log('Could not stop TaliabuVPN: ' + GetExceptionMessage);
  end;
  if Stopped then
    Sleep(1000);
end;

// TaliabuVPN writes these at runtime; an entry that points at another copy by now belongs to that copy.
function PointsAtApp(const SubKey: String): Boolean;
var
  Command: String;
begin
  Result := RegQueryStringValue(HKEY_CURRENT_USER, SubKey + '\shell\open\command', '', Command) and
    (Pos(Lowercase(ExpandConstant('{app}\TaliabuVPN.exe')), Lowercase(Command)) > 0);
end;

procedure RemoveOpenWith(const Ext: String);
begin
  RegDeleteValue(HKEY_CURRENT_USER, 'Software\Classes\' + Ext + '\OpenWithProgids', 'Throne.Config');
end;

procedure RemoveAssociations;
begin
  if PointsAtApp('Software\Classes\throne') then
    RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, 'Software\Classes\throne');
  if PointsAtApp('Software\Classes\Applications\TaliabuVPN.exe') then
    RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, 'Software\Classes\Applications\TaliabuVPN.exe');
  if not PointsAtApp('Software\Classes\Throne.Config') then
    Exit;
  RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, 'Software\Classes\Throne.Config');
  RemoveOpenWith('.json');
  RemoveOpenWith('.conf');
  RemoveOpenWith('.yaml');
  RemoveOpenWith('.yml');
  // Claimed before 1.3.
  RemoveOpenWith('.ini');
  RemoveOpenWith('.txt');
end;

// TaliabuVPN writes these to HKLM when it runs elevated, so a per-user uninstall lacks the rights to remove them.
procedure RemoveCrashDumpKey(const ExeName: String);
var
  SubKey, Folder: String;
begin
  SubKey := 'SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\' + ExeName;
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE, SubKey, 'DumpFolder', Folder) then
    Exit;
  Folder := Lowercase(AddBackslash(Folder));
  if (Pos(Lowercase(AddBackslash(ExpandConstant('{app}'))), Folder) = 1) or
     (Pos(Lowercase(ExpandConstant('{localappdata}\TaliabuVPN\')), Folder) = 1) then
    RegDeleteKeyIncludingSubkeys(HKEY_LOCAL_MACHINE, SubKey);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  App: String;
begin
  App := ExpandConstant('{app}');
  if CurUninstallStep = usUninstall then
  begin
    StopTaliabuVPN;
    RemoveAssociations;
    RemoveCrashDumpKey('TaliabuVPN.exe');
    RemoveCrashDumpKey('ThroneCore.exe');
    DeleteUserData := SuppressibleMsgBox('Also delete your TaliabuVPN profiles, settings and logs?' + #13#10#13#10 +
      'Choose No if you plan to reinstall TaliabuVPN later and want to keep them.', mbConfirmation, MB_YESNO, IDYES) = IDYES;
  end
  else if (CurUninstallStep = usPostUninstall) and DeleteUserData then
  begin
    if FileExists(App + '\config\throne.db') then
      DelTree(App + '\config', True, True, True);
    // Where TaliabuVPN keeps its config when its own folder is not writable (Qt's AppConfigLocation).
    DelTree(ExpandConstant('{localappdata}\TaliabuVPN\config'), True, True, True);
    RemoveDir(ExpandConstant('{localappdata}\TaliabuVPN'));
    DelTree(ExpandConstant('{userappdata}\TaliabuVPN'), True, True, True);
    RemoveDir(App);
  end;
end;
