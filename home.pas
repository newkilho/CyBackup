unit home;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.WinXCtrls, Vcl.Buttons,
  JvExStdCtrls, JvHtControls, Vcl.StdCtrls, K.HTTP, K.Strings, K.Thread;

type
  TFrmHome = class(TForm)
    LabelTitle: TLabel;
    LabelContent: TJvHTLabel;
    BtnStart: TSpeedButton;
    Indicator: TActivityIndicator;
    Edit_ID: TEdit;
    Edit_PW: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Memo_JS: TMemo;
    procedure BtnStartClick(Sender: TObject);
  private
    procedure Get_RSA(UserID: string; UserPW: string; var UserID_rsa: string; var UserPW_rsa: string);
    procedure Get_ImageList(HTTP: THTTP; HomeID: string; ImageList: TStringList);
    procedure Save_Image(HTTP: THTTP; ImageList: TStringList);

    function Get_HomeID(HTTP: THTTP; UserID: string; UserPW: string): string;
  public
    { Public declarations }
  end;

var
  FrmHome: TFrmHome;

implementation

{$R *.dfm}

// http://delphidabbler.com/tips/61
function GetDosOutput(CommandLine: string; CurrentDir: string = 'C:\'): string;
var
  SA: TSecurityAttributes;
  SI: TStartupInfo;
  PI: TProcessInformation;
  StdOutPipeRead, StdOutPipeWrite: THandle;
  WasOK: Boolean;
  Buffer: array[0..255] of AnsiChar;
  BytesRead: Cardinal;
  Handle: Boolean;
begin
  Result := '';
  with SA do begin
    nLength := SizeOf(SA);
    bInheritHandle := True;
    lpSecurityDescriptor := nil;
  end;
  CreatePipe(StdOutPipeRead, StdOutPipeWrite, @SA, 0);
  try
    with SI do
    begin
      FillChar(SI, SizeOf(SI), 0);
      cb := SizeOf(SI);
      dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      wShowWindow := SW_HIDE;
      hStdInput := GetStdHandle(STD_INPUT_HANDLE); // don't redirect stdin
      hStdOutput := StdOutPipeWrite;
      hStdError := StdOutPipeWrite;
    end;
    Handle := CreateProcess(nil, PChar('cmd.exe /C ' + CommandLine),
                            nil, nil, True, 0, nil,
                            PChar(CurrentDir), SI, PI);
    CloseHandle(StdOutPipeWrite);

    if Handle then
      try
        repeat
          WasOK := ReadFile(StdOutPipeRead, Buffer, 255, BytesRead, nil);
          if BytesRead > 0 then
          begin
            Buffer[BytesRead] := #0;
            Result := Result + string(Buffer);
          end;
        until not WasOK or (BytesRead = 0);
        WaitForSingleObject(PI.hProcess, INFINITE);
      finally
        CloseHandle(PI.hThread);
        CloseHandle(PI.hProcess);
      end;
  finally
    CloseHandle(StdOutPipeRead);
  end;
end;

function DownloadFile(HTTP: THTTP; URL: string; FileName: string): boolean;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate or fmShareDenyWrite);
  Result := HTTP.Download(URL, Stream);
  Stream.Free;
end;

procedure TFrmHome.BtnStartClick(Sender: TObject);
var
  HTTP: THTTP;
  ImageList: TStringList;
  UserID_rsa, UserPW_rsa, HomeID: string;
begin
  if Edit_ID.Text = '' then Exit;
  if Edit_PW.Text = '' then Exit;

  BtnStart.Caption := '';
  BtnStart.Enabled := False;
  Edit_ID.Enabled := False;
  Edit_PW.Enabled := False;
  Indicator.Animate := True;
  Indicator.Visible := True;

  CreateDir(ExtractFilePath(ParamStr(0))+'Images');
  if not DirectoryExists(ExtractFilePath(ParamStr(0))+'Images') then
  begin
    Showmessage('파일을 생성할 수 없습니다.');
    Halt;
  end;

  HTTP := THTTP.Create;

  Get_RSA(Edit_ID.Text, Edit_PW.Text, UserID_rsa, UserPW_rsa);
  HomeID := Get_HomeID(HTTP, UserID_rsa, UserPW_rsa);
  if HomeID = '' then
  begin
    Showmessage('인증이 실패하였습니다.');

    BtnStart.Caption := '실행하기';
    BtnStart.Enabled := True;
    Edit_ID.Enabled := True;
    Edit_PW.Enabled := True;
    Indicator.Animate := False;
    Indicator.Visible := False;

    HTTP.Free;

    Exit;
  end;

  ImageList := TStringList.Create;
  Get_ImageList(HTTP, HomeID, ImageList);
  Save_Image(HTTP, ImageList);
  ImageList.Free;

  HTTP.Free;

  Halt;
end;

function TFrmHome.Get_HomeID(HTTP: THTTP; UserID, UserPW: string): string;
var
  Data: string;
  Post: TStringList;
begin
  Post := TStringList.Create;

  Post.Add('redirection=//cy.cyworld.com/cyMainS');
  Post.Add('passwd=');
  Post.Add('email=');
  Post.Add('passwd_rsa='+UserPW);
  Post.Add('email_rsa='+UserID);

  HTTP.CustomHeaders['Referer'] := 'https://cy.cyworld.com/cyMain';

  Wait(procedure()
  begin
    Data := HTTP.Post('http://cyxso.cyworld.com/LoginAuthNew.sk', Post);
    Data := HTTP.Get('http://club.cyworld.com/club/clubsection2/home.asp');
  end);

  Result := Parsing(Data, '<dt><a href="javascript:PZPopup('+#39, #39);
end;

procedure TFrmHome.Get_ImageList(HTTP: THTTP; HomeID: string; ImageList: TStringList);
var
  Data, Item, LastDate, LastID: string;
  ItemPos: Integer;
begin
  LastDate := '';
  LastID := '';

  HTTP.CustomHeaders['Accept'] := 'application/json, text/javascript, */*; q=0.01';
  HTTP.CustomHeaders['Refer'] := 'https://cy.cyworld.com/home/new/'+HomeID;

  while True do
  begin
    Wait(procedure()
    begin
      Data := HTTP.Get('https://cy.cyworld.com/home/'+HomeId+'/posts?folderid=&tagname=&lastid='+LastID+'&lastdate='+LastDate+'&listsize=20&homeId=29546158&airepageno=0&airecase=D&airelastdate=&searchType=R&search=&_='+Random(99999999).ToString);
    end);

    LastDate := Parsing(Data, '"lastdate":', '}');

    Data := Parsing(Data, '"postList":[{', '}]');
    if Data = '' then Break;

    ItemPos := 1;
    while True do
    begin
      Item := Parsing(Data, '{"identity":"', ',"searchAccess"', ItemPos);
      if Item = '' then Break;

      LastID := Parsing(Item, '', '"');

      Item := Parsing(Item, '"image":"', '"');
      if Item = '' then Continue;

      Item := 'http://nthumb.cyworld.com/thumb?v=0&width=810&url='+UrlEncode(Item);
      ImageList.Add(Item);
    end;
  end;
end;

procedure TFrmHome.Get_RSA(UserID, UserPW: string; var UserID_rsa,
  UserPW_rsa: string);
var
  Script: TStringList;
  Data: string;
begin
  Script := TStringList.Create;
  Script.Text := Memo_JS.Lines.Text;

  Script.Add('var mail = "'+UserID+'";');
  Script.Add('var pass = "'+UserPW+'";');
  Script.Add('var pass_rsa = xRSA.encrypt(mail, pass);');
  Script.Add('var mail_rsa = xRSA.encrypt(mail, mail);');
  Script.Add('WScript.Echo("<pass_rsa>"+pass_rsa+"</pass_rsa>");');
  Script.Add('WScript.Echo("<mail_rsa>"+mail_rsa+"</mail_rsa>");');

  Script.SaveToFile(ExtractFilePath(ParamStr(0))+'CyBackup.js');
  Script.Free;

  Data := GetDosOutput('cscript.exe "'+ExtractFilePath(ParamStr(0))+'CyBackup.js"');
  UserID_rsa := Parsing(Data, '<mail_rsa>', '</mail_rsa>');
  UserPW_rsa := Parsing(Data, '<pass_rsa>', '</pass_rsa>');

  DeleteFile(ExtractFilePath(ParamStr(0))+'CyBackup.js');
end;

procedure TFrmHome.Save_Image(HTTP: THTTP; ImageList: TStringList);
var
  URL, Output: string;
  Loop: Integer;
begin
  for Loop := 0 to ImageList.Count-1 do
  begin
    URL := ImageList.Strings[Loop];
    Output := ExtractFilePath(ParamStr(0))+'Images\cy-'+Format('%0.6d', [Loop+1])+'.jpg';

    Wait(procedure()
    begin
      DownloadFile(HTTP, URL, Output);
    end);
  end;
end;

end.
