unit Unit1;
interface
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, ActnList, Menus, AppEvnts;

type
  Tf3DS = class(TForm)
    Memo: TMemo;
    bImport3DS: TButton;
    OpenDialog3DS: TOpenDialog;
    Tree3DS: TTreeView;
    StatusBar: TStatusBar;
    Label1: TLabel;
    bOpenGL: TButton;
    ActionList: TActionList;
    ActionDisplay: TAction;
    bSaveAsGM: TButton;
    ActionCloseGL: TAction;
    ActionDefaultCam: TAction;
    MainMenu: TMainMenu;
    MenuFile: TMenuItem;
    MenuExit: TMenuItem;
    ActionImport3DS: TAction;
    ActionSaveAsGM: TAction;
    eFPS: TEdit;
    ActionExit: TAction;
    bLoadBSP: TButton;
    ActionLoadBSP: TAction;
    OpenDialogBSP: TOpenDialog;
    bLoadMap: TButton;
    ActionLoadMap: TAction;
    OpenDialogMAP: TOpenDialog;
    bClearMap: TButton;
    bClearBSP: TButton;
    bGenerateTerrain: TButton;
    bClearTerrain: TButton;
    ActionGenerateTerrain: TAction;
    ProgressBarClass: TProgressBar;
    ProgressBarTotal: TProgressBar;
    procedure FormCreate(Sender: TObject);
    procedure ActionDisplayExecute(Sender: TObject);
    procedure ActionCloseGLExecute(Sender: TObject);
    procedure ActionDefaultCamExecute(Sender: TObject);
    procedure bOpenGLMouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer);
    procedure ActionImport3DSExecute(Sender: TObject);
    procedure ActionSaveAsGMExecute(Sender: TObject);
    procedure ActionExitExecute(Sender: TObject);
    procedure ActionLoadBSPExecute(Sender: TObject);
    procedure ActionLoadMapExecute(Sender: TObject);
    procedure MemoDblClick(Sender: TObject);
    procedure Tree3DSDblClick(Sender: TObject);
    procedure bClearMapClick(Sender: TObject);
    procedure bClearBSPClick(Sender: TObject);
    procedure bClearTerrainClick(Sender: TObject);
    procedure ActionGenerateTerrainExecute(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  f3DS: Tf3DS;

implementation
uses uCamera, uTexture, uSkyBox, uLight, u3DS, u3DModel, uMAP, uQuake3BSP, FormOpenGL, uOpenGL, uDisplay, uPlayer, uTerrain;
{$R *.dfm}

procedure Tf3DS.FormCreate(Sender: TObject);
var AppPath: string;
begin
  Top := 50;
  Left := 50;      
  //
  obj3DS.Set_StdOut(Memo);
  obj3DS.Set_StdTree(Tree3DS);
  Quake3BSP.Set_StdOut(Memo);
  LevelMap.Set_StdOut(Memo);
  //
  AppPath := ExtractFilePath(Application.ExeName);
  OpenDialog3DS.InitialDir := AppPath +'models\';
  OpenDialogBSP.InitialDir := AppPath +'maps\';
  OpenDialogMAP.InitialDir := AppPath +'maps\';
  //
  eFPS.Text := IntToStr({fOpenGL.VerticalRefreshRate} OGL.MonitorRefreshRate) +' Hz';
end;

procedure Tf3DS.bOpenGLMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  //lekker buggy  :|
  if fOpenGL.Showing then bOpenGL.Caption := 'Hide'
                     else bOpenGL.Caption := 'Show';
end;



procedure Tf3DS.MemoDblClick(Sender: TObject);
begin
  Memo.Lines.Clear;
end;

procedure Tf3DS.Tree3DSDblClick(Sender: TObject);
begin
  Tree3DS.Items.Clear;
end;



procedure Tf3DS.bClearMapClick(Sender: TObject);
begin
  LevelMap.Clear;
end;

procedure Tf3DS.bClearBSPClick(Sender: TObject);
begin
  Quake3BSP.Clear;
end;

procedure Tf3DS.bClearTerrainClick(Sender: TObject);
begin
  Terrain.Clear;
end;


{--- ACTIONS ------------------------------------------------------------------}
procedure Tf3DS.ActionDisplayExecute(Sender: TObject);
begin
  // het OpenGL venster laten zien,
  // en de 3DS-mesh afbeelden..
  if not fOpenGL.Showing then begin
    fOpenGL.Show;
    ActionDisplay.Caption := 'Hide';
  end else begin
    fOpenGL.Hide;
    ActionDisplay.Caption := 'Show';
  end;
  bOpenGL.Caption := ActionDisplay.Caption;
  if {fOpenGL.}OGL.Active then begin
    eFPS.Text := IntToStr({fOpenGL.}OGL.GetMaxTextureUnits) +'x TU';
  end;
end;

procedure Tf3DS.ActionCloseGLExecute(Sender: TObject);
begin
  with fOpenGL do begin
    {OGL.glPause(true);}
    if OGL.Active then begin
      // 3D-object textures vrijgeven..
      Obj3DModel.FreeTextures;
(*
      // SkyBox textures vrijgeven..
      OGL.SkyBox.FreeTextures;
*)
      //
      OGL.Disable;
    end;
    Hide;
    {OGL.glPause(false);}
  end;
end;

procedure Tf3DS.ActionDefaultCamExecute(Sender: TObject);
begin
  Player.Camera.Default;
end;

procedure Tf3DS.ActionImport3DSExecute(Sender: TObject);
begin
  if OpenDialog3DS.Execute then begin
    // eventueel aangemaakte textures wissen
    if {fOpenGL.}OGL.Active then Obj3DModel.FreeTextures;
    // Het model laden
    obj3DS.ReadFromFile(OpenDialog3DS.FileName);
    (*
    // textures aanmaken
    if fOpenGL.OGL.Active then Obj3DModel.InitTextures;
    *)
    if not fOpenGL.Showing then fOpenGL.Show;
    if fOpenGL.Showing then fOpenGL.SetFocus;
  end;
end;

procedure Tf3DS.ActionSaveAsGMExecute(Sender: TObject);
begin
  //
end;

procedure Tf3DS.ActionExitExecute(Sender: TObject);
begin
  ActionCloseGLExecute(nil);
  Close;
end;

procedure Tf3DS.ActionLoadBSPExecute(Sender: TObject);
begin
  // bsp's laden kan alleen als OpenGL actief is..
  if not {fOpenGL.}OGL.Active then Exit;
  if OpenDialogBSP.Execute then begin
    // evt. geladen map verwijderen..
    Quake3BSP.Clear;
    // De map laden
    Quake3BSP.LoadBSP(OpenDialogBSP.FileName);
    Player.Camera.SetCollide(Quake3BSP.IsMapLoaded); //nog niet botsen bij een map, alleen bij een bsp vooralsnog..
    if not fOpenGL.Showing then fOpenGL.Show;
    if fOpenGL.Showing then fOpenGL.SetFocus;
  end;
end;

procedure Tf3DS.ActionLoadMapExecute(Sender: TObject);
begin
  // maps laden kan alleen als OpenGL actief is..
  if not {fOpenGL.}OGL.Active then Exit;
  if OpenDialogMAP.Execute then begin
    // evt. geladen map verwijderen..
    LevelMap.Clear;
    // De map laden
    LevelMap.LoadMAP(OpenDialogMAP.FileName);
    if not fOpenGL.Showing then fOpenGL.Show;
    if fOpenGL.Showing then fOpenGL.SetFocus;
  end;
end;



procedure Tf3DS.ActionGenerateTerrainExecute(Sender: TObject);
begin
  //
end;

procedure Tf3DS.FormShow(Sender: TObject);
begin
  ActionDisplayExecute(Sender);
end;

end.
