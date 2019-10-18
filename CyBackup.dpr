program CyBackup;

uses
  WinApi.Windows,
  Vcl.Forms,
  main in 'main.pas' {FrmCyBackup},
  home in 'home.pas' {FrmHome},
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

const
  MutexName = 'CyBackupMutex';
var
  Mutex: THandle;
begin
  Mutex := OpenMutex( MUTEX_ALL_ACCESS, False, MutexName );
  if Mutex <> 0 Then Exit;

  CreateMutex(nil, True, MutexName);

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Tablet Light');
  Application.CreateForm(TFrmCyBackup, FrmCyBackup);
  //Application.CreateForm(TFrmHome, FrmHome);
  Application.Run;
end.
