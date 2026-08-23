//castle-engine.io/modern_pascal

program Make;
{$mode objfpc}{$H+}

uses
  Classes,
  SysUtils,
  StrUtils,
  FileUtil,
  LazFileUtils,
  Zipper,
  fphttpclient,
  RegExpr,
  openssl,
  LazUTF8,
  opensslsockets,
  eventlog,
  Process;

function OutLog(const Knd: TEventType; const Msg: string): string;
var Line: string;
begin
  case Knd of
    etError: Result := #27'[31m%s'#27'[0m';
    etInfo:  Result := #27'[32m%s'#27'[0m';
    etDebug: Result := #27'[33m%s'#27'[0m';
    else     Result := '%s';
  end;
  if (Knd = etError) and
     (ExitCode < 125) then
       ExitCode += 1;
  for Line in Msg.Split(LineEnding) do
    if not Line.Contains('/usr/lib/lazarus/') and
       not Line.Contains('/units/') then
         Writeln(stderr, UTF8ToConsole(Result.Format([Line])));
end;

function SelectString(const Input, Reg: string): string;
var Line: string;
begin
  Result := EmptyStr;
  with TRegExpr.Create do begin
    try
      Expression := Reg;
      for Line in Input.Split(LineEnding) do
        if Exec(Line) then Result += Line + LineEnding;
    finally
      Free;
    end;
  end;
end;

function RunShell(const Command: String): string;
begin
  OutLog(etDebug, #9'Run:'#9 + Command + #10);
  if not RunCommand(
  {$IFDEF MSWINDOWS}
  'pwsh', [
      '-NonInteractive',
      '-Command',
      '$ErrorActionPreference = "stop"; Set-PSDebug -Strict; ' + Command
    ]
  {$ELSE}
  'bash', ['-c', 'set -euo pipefail; ' + Command]
  {$ENDIF}
  , Result, [poStderrToOutPut, poWaitOnExit]) then
    OutLog(etError, Result);
end;

function AddPackage(const Path: string; const Link: boolean): string;
var Line: string;
begin
  if Link then Line := '--add-package-link'
  else Line := '--build-all';
  Result := {$IFDEF MSWINDOWS}
    '(cocoa|x11|_template)' {$ELSE}
    '(cocoa|gdi|_template)' {$ENDIF};
  OutLog(etDebug, 'AddPackage:'#9 + Path);
  if SelectString(Path, Result) = EmptyStr then
    RunShell('lazbuild --recursive %s %s'.Format([Line, Path]));
end;

function AddLibrary(const Path: String): string;
begin
  {$IFDEF MSWINDOWS}
  Result := ExtractFilePath(ParamStr(0));
  OutLog(etDebug, 'AddLibrary:'#9 + Path);
  if not FileExists(Result + ExtractFileName(Path)) then
    RunShell('Copy-Item %s %s -Force'.Format([Path, Result]));
  {$ELSE}
  Result := '/usr/lib/';
  OutLog(etDebug, 'AddLibrary:'#9 + Path);
  if not FileExists(Result + ExtractFileName(Path)) then begin
    RunShell('sudo -n cp %s %s && sudo -n ldconfig'.Format([Path, Result]));
  end;
  {$ENDIF}
end;

function BuildProject(const Path: string): string; cdecl;
var Text: string;
begin
  OutLog(etDebug, 'BuildProject from:'#9 + Path);
  if not RunCommand('lazbuild',
    ['--build-all', '--recursive', {$IFDEF UNIX} {'--widgetset=qt',} '--opt=-dWITH_GTK2_IM', {$ENDIF} '--no-write-project', Path], Result, [poStderrToOutPut, poWaitOnExit])
  then OutLog(etError, SelectString(Result, '(Fatal|Error|/ld(\.[a-z]+)?):'))
  else begin
    Result := SelectString(Result, 'Linking').Replace(LineEnding, EmptyStr);
    OutLog(etInfo, #9'to:'#9 + Result + #10);
    Text := ReadFileToString(ChangeFileExt(Path, '.lpr'));
    if Text.Contains('program') and
       Text.Contains('consoletestrunner') then
         RunShell('%s --all --format=plain'.Format([Result]))
    else if Text.Contains('library') and Text.Contains('exports') then
      AddLibrary(Result);
  end;
end;

function ExtractPackage(const ZipFile, Package: string): string;
begin
  Result := GetEnvironmentVariable({$IFDEF MSWINDOWS}'APPDATA'{$ELSE}'HOME'{$ENDIF})
    + '/.lazarus/onlinepackagemanager/packages/'.Replace('/', DirectorySeparator)
    + Package;
  OutLog(etDebug, 'ExtPackage from:'#9 + ZipFile + #10#9'to:'#9 + Result);
  if not DirectoryExists(Result) and
     ForceDirectories(Result) then
       with TUnZipper.Create do begin
         try
           FileName := ZipFile;
           OutputPath := Result;
           Examine;
           UnZipAllFiles;
           DeleteFile(ZipFile);
         finally
           Free;
         end;
       end;
end;

function IsValidZip(const FilePath: string): boolean;
var
  FS: TFileStream;
  Magic: array[0..1] of byte;
begin
  Result := False;
  if not FileExists(FilePath) or (FileSize(FilePath) < 22) then Exit; // 22 bytes = smallest possible zip (EOCD record)
  FS := TFileStream.Create(FilePath, fmOpenRead);
  try
    FS.ReadBuffer(Magic, 2);
    Result := (Magic[0] = Ord('P')) and (Magic[1] = Ord('K')); // local file header / empty-archive signature
  finally
    FS.Free;
  end;
end;

function GetPackage(const Uri, Package: string): string;
const
  MaxAttempts = 3;
var
  FileStream: TStream;
  Attempt: integer;
  Url: string;
begin
  Result := '%s_%s'.Format([GetTempFileName, Package]);
  Url := Uri + Package + '.zip';
  OutLog(etDebug, 'GetPackage from'#9 + Url + #10#9'to:'#9 + Result);
  for Attempt := 1 to MaxAttempts do begin
    try
      {$IFDEF MSWINDOWS}
        RunShell('Invoke-WebRequest -Uri %s -OutFile %s'.Format([Url, Result]));
      {$ELSE}
        InitSSLInterface;
        FileStream := TFileStream.Create(Result, fmCreate or fmOpenWrite);
        with TFPHttpClient.Create(nil) do begin
          try
            AddHeader('User-Agent', 'Mozilla/5.0 (compatible; fpweb)');
            AllowRedirect := True;
            Get(Url, FileStream);
            if ResponseStatusCode >= 300 then
              raise Exception.CreateFmt('HTTP %d fetching %s', [ResponseStatusCode, Url]);
          finally
            Free;
            FileStream.Free;
          end;
        end;
      {$ENDIF}
      if not IsValidZip(Result) then
        raise Exception.CreateFmt('downloaded file is not a valid zip: %s', [Result]);
      Exit; // success
    except
      on E: Exception do begin
        OutLog(etDebug, 'GetPackage: attempt %d/%d for %s failed: %s'.Format([Attempt, MaxAttempts, Package, E.Message]));
        if Attempt = MaxAttempts then
          raise Exception.CreateFmt('GetPackage: giving up on %s after %d attempts (%s)', [Url, MaxAttempts, E.Message]);
        Sleep(1000 * Attempt); // simple linear backoff: 1s, 2s, ...
      end;
    end;
  end;
end;

function BuildAll(const OutDep: array of string): string;
var
  DT: TDateTime;
  List: TStringList;
  Item: string;
begin
  DT := Time;
  List :=  TStringList.Create;
  try
    OutLog(etDebug, #10'#----------------------------------[GET EXTERNAL DEPENDENCIES]--------------------------#'#10);
    for Item in OutDep do
      FindAllFiles(List, ExtractPackage(GetPackage('https://packages.lazarus-ide.org/', Item), Item), '*.lpk');
    FindAllFiles(List, GetCurrentDir + PathDelim + 'use', '*.lpk');
    for Item in List do
      AddPackage(Item, true);
    List.Clear;
    OutLog(etDebug, #10'#----------------------------------[BUILD            PROJECTS]--------------------------#'#10);
    FindAllFiles(List, GetCurrentDir, '*.lpi');
    for Item in List do
      if not Item.Contains(PathDelim + 'use' + PathDelim) then
           BuildProject(Item);
  finally
    FreeAndNil(List);
  end;
  OutLog(etDebug, #10'#----------------------------------[      RESULT      ]----------------------------------#'#10);
  OutLog(etDebug, 'Duration:'#9 + FormatDateTime('hh:nn:ss', Time - DT));
  case ExitCode of
    0: OutLog(etInfo,    #9'Errors:'#9 + ExitCode.ToString);
    else OutLog(etError, #9'Errors:'#9 + ExitCode.ToString);
  end;
end;

begin
  try
    if ParamCount > 0 then
      case ParamStr(1) of
        'build': BuildAll([]);
        else
          OutLog(etError, 'Unknown command: "' + ParamStr(1) + '". Usage: main.pas build');
      end
    else
      OutLog(etError, 'Usage: main.pas build');
  except
    on E: Exception do
      OutLog(etError, E.ClassName + #9 + E.Message);
  end;
end.
