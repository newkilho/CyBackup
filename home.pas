unit home;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.WinXCtrls, Vcl.Buttons, WinAPI.ShellAPI, System.DateUtils,
  Vcl.StdCtrls, URLMon, JvHtControls, JvExStdCtrls, K.HTTP, K.Strings, K.Thread;

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
    Edit_HomeID: TEdit;
    Label3: TLabel;
    Radio_Auth: TRadioButton;
    Radio_NotAuth: TRadioButton;
    Chk_Detail: TCheckBox;
    procedure BtnStartClick(Sender: TObject);
    procedure Radio_AuthClick(Sender: TObject);
  private
    procedure GetRSA(UserID: string; UserPW: string; var UserID_rsa: string; var UserPW_rsa: string);
    procedure GetRSA_CScript(UserID: string; UserPW: string; var UserID_rsa: string; var UserPW_rsa: string);
    procedure GetPostList(HTTP: THTTP; HomeID: string; PostList: TStrings; Detail: Boolean);
    procedure GetPostItem(HTTP: THTTP; HomeID: string; PostList, ImageList: TStrings; Detail: Boolean);
    procedure SetImage(HTTP: THTTP; ImageList: TStringList);

    function GetHomeID(HTTP: THTTP; UserID_rsa: string; UserPW_rsa: string): string;
  public
    { Public declarations }
  end;

var
  FrmHome: TFrmHome;

implementation

{$R *.dfm}

uses main;

function GetFileMimeType(AFileName: string): string;
const
  MAX_COUNT = 256;
var
  LFileName  : PWideChar;
  LStream    : TFileStream;
  LMimeType  : PWideChar;
  LBinReader : TBinaryReader;
  LBinArray  : TArray<Byte>;
  LReadSize  : Cardinal;
begin
  Result := '';

  LFileName := PWideChar(AFileName);

  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  if LStream.Size > MAX_COUNT then begin
    LReadSize := MAX_COUNT;
  end else begin
    LReadSize := LStream.Size;
  end;

  LBinReader := TBinaryReader.Create(LStream, TEncoding.Default, False);
  try
    LBinArray := LBinReader.ReadBytes(LReadSize);

    LMimeType := nil;
    if FindMimeFromData(nil, LFileName, LBinArray, LReadSize, nil, 0, LMimeType, 0) = S_OK then
      Result := LMimeType;

    if (Result = 'text/plain') and (Pos('{"message":"Error downloading', TEncoding.Ansi.GetString(LBinArray)) > 0) then
      Result := 'text/error';
  finally
    FreeAndNil(LBinReader);
    FreeAndNil(LStream);
  end;
end;

procedure Log(Str: string);
var
  LogFile: TextFile;
  LogName: string;
begin
  try
    LogName := ExtractFilePath(ParamStr(0))+'Images\CyBackup.txt';
    AssignFile(LogFile, LogName);
    if FileExists(LogName) then Append(LogFile) else Rewrite(LogFile);
    WriteLn(LogFile, Str);
  finally
    CloseFile(LogFile)
  end;
end;

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

procedure TFrmHome.GetRSA(UserID, UserPW: string; var UserID_rsa,
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
  Script.Add('console.log("<pass_rsa>"+pass_rsa+"</pass_rsa><mail_rsa>"+mail_rsa+"</mail_rsa>");');

  Data := GetHTTP('http://execjs.kilho.net/', Script.Text);

  Script.Free;

  UserID_rsa := Parsing(Data, '<mail_rsa>', '</mail_rsa>');
  UserPW_rsa := Parsing(Data, '<pass_rsa>', '</pass_rsa>');

  DeleteFile(ExtractFilePath(ParamStr(0))+'CyBackup.js');
end;

procedure TFrmHome.GetRSA_CScript(UserID, UserPW: string; var UserID_rsa,
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

  Data := GetDosOutput('cscript.exe "'+ExtractFilePath(ParamStr(0))+'CyBackup.js"', '\');
  UserID_rsa := Parsing(Data, '<mail_rsa>', '</mail_rsa>');
  UserPW_rsa := Parsing(Data, '<pass_rsa>', '</pass_rsa>');

  DeleteFile(ExtractFilePath(ParamStr(0))+'CyBackup.js');
end;

function TFrmHome.GetHomeID(HTTP: THTTP; UserID_rsa, UserPW_rsa: string): string;
var
  Data: string;
  Post: TStringList;
begin
  Post := TStringList.Create;

  Post.Add('redirection=//cy.cyworld.com/cyMainS');
  Post.Add('passwd=');
  Post.Add('email=');
  Post.Add('passwd_rsa='+UserPW_rsa);
  Post.Add('email_rsa='+UserID_rsa);

  Showmessage(UserID_rsa+#13+UserPW_rsa);

  HTTP.CustomHeaders['Referer'] := 'https://cy.cyworld.com/cyMain';

  Wait(procedure()
  begin
    Data := HTTP.Post('https://cyxso.cyworld.com/LoginAuthNew.sk', Post);

    //Data := HTTP.Get('https://cymember.cyworld.com/helpdesk/exMemberInfo.sk?pgcode=myinfo');
    Data := HTTP.Get('https://cy.cyworld.com/home/new/29546158');
  end);

  //Result := Parsing(Data, '<dt><a href="javascript:PZPopup('+#39, #39);
  Result := Parsing(Data, '<a href="/home/new/', '"');
end;

procedure TFrmHome.GetPostList(HTTP: THTTP; HomeID: string; PostList: TStrings; Detail: Boolean);
var
  Data, Item, Thumb, Title, Content, RegDate, LastDate, LastID: string;
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
      Data := HTTP.Get('https://cy.cyworld.com/home/'+HomeId+'/posts?folderid=&tagname=&lastid='+LastID+'&lastdate='+LastDate+'&listsize=20&homeId='+HomeID+'&airepageno=0&airecase=D&airelastdate=&searchType=R&search=&_='+Random(99999999).ToString);
    end);

    LastDate := Parsing(Data, '"lastdate":', '}');

    Data := Parsing(Data, '"postList":[{', '}]');
    if Data = '' then Break;

    ItemPos := 1;
    while True do
    begin
      Item := Parsing(Data, '"identity":"', ',"searchAccess"', ItemPos);
      if Item = '' then Break;

      Thumb := Trim(Parsing(Item, '"image":"', '"'));

      if not Detail then
      begin
        Title := Trim(EscapeDecode(Parsing(Item, '"title":"', '"')));
        Content := EscapeDecode(Parsing(Item, '"summary":"', '"'));
        Content := EscapeDecode(Parsing(Content, '"text":"', '"'));
        Content := Trim(Content);
        DateTimeToString(RegDate, 'yyyy/mm/dd', UnixToDateTime(StrToInt64Def(Parsing(Item, '"publishedDate":', ','), 0) div 1000)); //1970-01-01

        Log('===============================================================================');
        if Title <> '' then Log('제목 : '+Title);
        if RegDate <> '' then Log('작성일 : '+RegDate);
        if Content <> '' then Log(Content);
        Log('===============================================================================');
        Log('');
        Log('');
      end;

      Item := Parsing(Item, '', '"');
      if Item = '' then Continue;
      if PostList.IndexOf(Item) > -1 then Continue;

      PostList.Add(Item+'='+Thumb);
      LastID := Item;
    end;
  end;

  FrmCyBackup.ProgressBar1.Max := PostList.Count;
  FrmCyBackup.ProgressBar1.Visible := True;
end;

procedure TFrmHome.GetPostItem(HTTP: THTTP; HomeID: string; PostList, ImageList: TStrings; Detail: Boolean);
var
  Data, Item: string;
  Loop, ItemPos: Integer;
begin
  HTTP.CustomHeaders['Accept'] := 'text/html';
  HTTP.CustomHeaders['Refer'] := 'https://cy.cyworld.com/home/new/'+HomeID;

  for Loop := 0 to PostList.Count-1 do
  begin
    FrmCyBackup.ProgressBar1.Position := FrmCyBackup.ProgressBar1.Position+1;

    Item := PostList.ValueFromIndex[Loop];
    if (Item <> '') and (ImageList.IndexOf(Item) < 0) then
      ImageList.Add(PostList.ValueFromIndex[Loop]);

    if not Detail then Continue;

    Wait(procedure()
    begin
      Data := HTTP.Get('https://cy.cyworld.com/home/'+HomeId+'/post/'+PostList.Names[Loop]+'/layer');
    end);

    //Memo1.Lines.Add(Data); Break;

    // 제목
    Item := Parsing(Data, '<h3 id="cyco-post-title">', '</h3>');
    Item := Trim(Item);
    if Item = '' then Continue;

    Log('===============================================================================');
    Log('제목 : '+Item);

    // 작성일
    Item := Parsing(Data, '<section class="outSection">', '</p>');
    Item := Parsing(Item, '</strong>', '');
    Item := Trim(Item);
    if Item = '' then Continue;

    Log('작성일 : '+Item);

    // 내용
    ItemPos := 1;
    while True do
    begin
      Item := Parsing(Data, '<div class="textData">', '</div>', ItemPos);
      if Item = '' then Break;

      Item := StringReplace(Item, '<br />', #13#10, [rfReplaceAll]);
      Item := Trim(Item);
      if Item = '' then Continue;

      Log(Item);
    end;

    // 첨부파일
    ItemPos := 1;
    while True do
    begin
      Item := Parsing(Data, '<figure>', '</figure>', ItemPos);
      if Item = '' then Break;

      Item := Parsing(Item, 'srctext="', '"');
      if Item = '' then Continue;

      Item := URLDecode(Item);
      if ImageList.IndexOf(Item) < 0 then
        ImageList.Add(Item);
    end;

    Log('===============================================================================');
    Log('');
    Log('');
  end;

  FrmCyBackup.ProgressBar1.Max := PostList.Count+ImageList.Count;
end;

procedure TFrmHome.SetImage(HTTP: THTTP; ImageList: TStringList);
var
  URL, Mime, Ext, Output: string;
  Loop: Integer;
begin
  for Loop := 0 to ImageList.Count-1 do
  begin
    FrmCyBackup.ProgressBar1.Position := FrmCyBackup.ProgressBar1.Position+1;

    URL := ImageList.Strings[Loop];

    Output := ExtractFilePath(ParamStr(0))+'Images\cy-'+Format('%0.6d', [Loop+1]);
    URL := 'http://nthumb.cyworld.com/thumb?v=0&width=810&url='+URLEncode(URL);

    Wait(procedure()
    begin
      DownloadFile(HTTP, URL, Output);
    end);

    Ext := '.jpg';

    Mime := GetFileMimeType(Output);
    if Mime = 'image/gif' then Ext := '.gif';
    if Mime = 'text/html' then Ext := '.htm';
    if Mime = 'image/png' then Ext := '.png';
    if Mime = 'text/plain' then Ext := '.txt';
    if Mime = 'text/error' then Ext := '.$$$';

    if Ext = '.$$$' then
    begin
      DeleteFile(Output);
      Continue;
    end;

    if FileExists(Output+Ext) then DeleteFile(Output+Ext);
    RenameFile(Output, Output+Ext);
  end;
end;

procedure TFrmHome.BtnStartClick(Sender: TObject);
var
  HTTP: THTTP;
  PostList, ImageList: TStringList;
  UserID_rsa, UserPW_rsa, HomeID: string;
begin
  if Radio_Auth.Checked then
  begin
    if Edit_ID.Text = '' then Exit;
    if Edit_PW.Text = '' then Exit;
  end
  else
  begin
    if Edit_HomeID.Text = '' then Exit;
  end;

  BtnStart.Caption := '';
  BtnStart.Enabled := False;
  Edit_ID.Enabled := False;
  Edit_PW.Enabled := False;
  Indicator.Animate := True;
  Indicator.Visible := True;

  HTTP := THTTP.Create;

  if Radio_Auth.Checked then
  begin
    GetRSA_CScript(Edit_ID.Text, Edit_PW.Text, UserID_rsa, UserPW_rsa);
    if (UserID_rsa = '') or (UserPW_rsa = '') then
    begin
      GetRSA(Edit_ID.Text, Edit_PW.Text, UserID_rsa, UserPW_rsa);
    end;

    if (UserID_rsa = '') or (UserPW_rsa = '') then
    begin
      Showmessage('인증 처리에 문제가 발생했습니다.');

      HTTP.Free;
      Halt;
    end;

    HomeID := GetHomeID(HTTP, UserID_rsa, UserPW_rsa);
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
  end
  else
  begin
    HomeID := Edit_HomeID.Text;
  end;

  CreateDir(ExtractFilePath(ParamStr(0))+'Images');
  if not DirectoryExists(ExtractFilePath(ParamStr(0))+'Images') then
  begin
    Showmessage('파일을 생성할 수 없습니다.');
    Halt;
  end;

  if FileExists(ExtractFilePatH(ParamStr(0))+'싸이월드.txt') then
    DeleteFile(ExtractFilePatH(ParamStr(0))+'싸이월드.txt');

  PostList := TStringList.Create;
  ImageList := TStringList.Create;

  GetPostList(HTTP, HomeID, PostList, Chk_Detail.Checked);
  GetPostItem(HTTP, HomeID, PostList, ImageList, Chk_Detail.Checked);

  SetImage(HTTP, ImageList);

  ImageList.Free;
  PostList.Free;

  HTTP.Free;

  ShellExecute(0,PCHAR('open'),PCHAR('explorer.exe'),PCHAR(ExtractFilePath(ParamStr(0))+'Images'),NIL,SW_SHOW);

  Halt;
end;

procedure TFrmHome.Radio_AuthClick(Sender: TObject);
var
  Auth: Boolean;
begin
  Auth := TRadioButton(Sender).Name = 'Radio_Auth';
  Edit_ID.Enabled := Auth;
  Edit_PW.Enabled := Auth;
  Edit_HomeID.Enabled := Not Auth;
end;

end.
