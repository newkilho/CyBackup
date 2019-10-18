unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Imaging.pngimage, Vcl.ExtCtrls,
  Vcl.Buttons, Winapi.ShellAPI, K.HTTP, K.Strings, K.Thread,
  home;

type
  TFrmCyBackup = class(TForm)
    PanelMenu: TPanel;
    BtnStart: TSpeedButton;
    BtnConfig: TSpeedButton;
    ImageLogo: TImage;
    PanelMain: TPanel;
    procedure FormCreate(Sender: TObject);
  private
    FrmHome: TFrmHome;
  public
    { Public declarations }
  end;

var
  FrmCyBackup: TFrmCyBackup;

implementation

{$R *.dfm}

function VER(Display: string='%d.%d.%d.%d'): string;
var
  Size, Handle: DWORD;
  Buffer: TBytes;
  FixedPtr: PVSFixedFileInfo;
begin
  Size := GetFileVersionInfoSize(PChar(ParamStr(0)), Handle);
  if Size = 0 then RaiseLastOSError;

  SetLength(Buffer, Size);

  if not GetFileVersionInfo(PChar(ParamStr(0)), Handle, Size, Buffer) then RaiseLastOSError;
  if not VerQueryValue(Buffer, '\', Pointer(FixedPtr), Size) then RaiseLastOSError;

  Result := Format(Display, [LongRec(FixedPtr.dwFileVersionMS).Hi, LongRec(FixedPtr.dwFileVersionMS).Lo, LongRec(FixedPtr.dwFileVersionLS).Hi, LongRec(FixedPtr.dwFileVersionLS).Lo]);
end;

function GetHTTP(URL: String): string;
var
  Thread: TThread;
  Data: string;
begin
  Thread := TThread.CreateAnonymousThread(
    procedure
    var
      HTTP: THTTP;
    begin
      HTTP := THTTP.Create;
      HTTP.ConnectionTimeOut := 5000;
      HTTP.CustomHeaders['User-Version'] := VER;

      Data := HTTP.Get(URL);

      HTTP.Free;
    end
  );

  Thread.FreeOnTerminate := True;
  Thread.Start;
  while not Thread.Finished do Application.ProcessMessages;

  Result := Data;
end;

function CheckUpdate(URL: string): string;
var
  Data, Item: string;
begin
  Result := '<BR><BR><ALIGN CENTER><FONT COLOR="clRED">서버에서 정보를 받지 못했습니다.</FONT></ALIGN>';

  Data := GetHTTP(URL);
  if Data = '' then Exit;

  Result := EscapeDecode(Parsing(Data, '"content":"', '"'));

  Item := EscapeDecode(Parsing(Data, '"update":"', '"'));
  if Item <> '' then
  begin
    if MessageBox(Application.Handle, '업데이트가 정보가 있습니다.'+#13#13+'안정적으로 사용하기 위해 새로 다운받고 실행하는걸 권장합니다.'+#13#13+'다운받으시겠습니까?', PChar(Application.Title), MB_YESNO or MB_ICONINFORMATION) = IDYES then
    begin
      ShellExecute(Application.Handle, 'open', pChar(Item), nil, nil, SW_SHOWNORMAL);
      Halt;
    end;
  end;
end;

procedure TFrmCyBackup.FormCreate(Sender: TObject);
begin
  Application.Title := Caption;
  Caption := Caption+' v '+VER('%d.%d');
  DesktopFont := True;
  Position := poScreenCenter;

  BtnStart.Visible := True;
  BtnConfig.Visible := False;

  FrmHome := TFrmHome.Create(PanelMain);
  with FrmHome do
  begin
    Parent := PanelMain;
    Left := 0;
    Top := 0;
    BorderStyle := bsNone;
    LabelContent.Caption := '<BR><BR><ALIGN CENTER><FONT COLOR="clBLUE">준비중...</FONT></ALIGN>';
    Indicator.Visible := False;
    Visible := True;
  end;

  FrmHome.LabelContent.Caption := CheckUpdate('https://cybackup.kilho.net/api.init.php');
end;

end.
