unit FormOpenGL;
interface
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, AppEvnts, ExtCtrls, Menus;

type
  TfOpenGL = class(TForm)
    TimerFPS: TTimer;
    popupView: TPopupMenu;
    viewFullScreen: TMenuItem;
    viewWindowed: TMenuItem;
    view800x600: TMenuItem;
    view1024x768: TMenuItem;
    view1280x1024: TMenuItem;
    N1: TMenuItem;
    viewMouseLook: TMenuItem;
    viewFog: TMenuItem;
    viewSkyBox: TMenuItem;
    viewWireFrame: TMenuItem;
    viewPointFrame: TMenuItem;
    viewLightMaps: TMenuItem;
    viewTextures: TMenuItem;
    viewCollisions: TMenuItem;
    viewGravity: TMenuItem;
    N2: TMenuItem;
    viewResetCamera: TMenuItem;
    N3: TMenuItem;
    viewHiddenLineRemoval: TMenuItem;
    view1TU: TMenuItem;
    view2TU: TMenuItem;
    viewHelp: TMenuItem;
    Stayontop1: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormResize(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormDestroy(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormCanResize(Sender: TObject; var NewWidth, NewHeight: Integer; var Resize: Boolean);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure TimerFPSTimer(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  private
    // muis bewegingen
    CenterX, CenterY: integer;  //het midden van het scherm in scherm-coördinaten
    LastX, LastY: Integer;       //vorige muiscursor-positie
    DeltaX, DeltaY: Single;      //laatste verschillen in cursor-positie.
(*
    // snelheid meting
    PerformanceFreq, PerformanceCount, LastPerformanceCount: Int64;
    FrameTime: Single;           //de tijdsduur voor het tekenen van het laatste frame
    FPS_, FPSCount: Integer;     //aantal beelden per seconde
*)
    // thread priorities
    PriorityClass, Priority: integer;
    // fullscreen wissels
    FormLeft, FormTop, FormWidth, FormHeight: integer;
    // speciale events waarvoor geen standaard delphi form-event is gedefiniëerd..
    procedure WMEraseBkgnd(var Msg: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMSysCommand(var Msg : TWMSysCommand); message WM_SYSCOMMAND;
    procedure WMMove(var Msg: TWMMove); message WM_MOVE;  //een form-move
    (*procedure WMNCHitTest(var Msg: TWMNCHitTest); message WM_NCHITTEST;*)
    //
    procedure ToggleMouseControl;
    procedure ToggleFullScreen;
    procedure ToggleHelp;
    procedure CalculateCenter;
    procedure HideForm;
  public
    HelpText: TStringList;  //de help tekst
//    OGL: TOGL;              //het OpenGL object
    procedure HandleMouseControl;
(*
    procedure MeasureFPS;
    function FPS : integer;
    function GetFrameTime : Single;
    function VerticalRefreshRate : Integer;
*)
    // het form initialiseren bij overschakeling naar graphische OpenGL modus
    // (dwz. OpenGL activeren en textures aanmaken)
    procedure InitGraphics;
  end;

var fOpenGL: TfOpenGL;



implementation
uses u3DTypes, uCalc, uOpenGL, uCamera, uLight, uSkyBox, u3DModel, uQuake3BSP, uDisplay, uGame, uPlayer, uParticles, uTerrain;
{$R *.dfm}

procedure TfOpenGL.WMEraseBkgnd(var Msg: TWMEraseBkgnd);
begin
  Msg.Result := 1;  //form achtergrond paint-event als "klaar" markeren..
end;

procedure TfOpenGL.WMSysCommand(var Msg: TWMSysCommand);
begin
  // geen screensaver toestaan..
  if Msg.cmdType = SC_SCREENSAVE then Msg.Result := 1
                                 else inherited;
end;

procedure TfOpenGL.WMMove(var Msg: TWMMove);
begin
  inherited; //Left & Top porperties laten bijwerken..
  CalculateCenter;
end;

(*
procedure TfOpenGL.WMNCHitTest(var Msg: TWMNCHitTest);
begin
  Msg.Result := HTCAPTION;
end;
*)



procedure TfOpenGL.CreateParams(var Params: TCreateParams);
begin
  inherited;
  // OWNDC vlag zetten om tegen te gaan dat bij elk Paint-event de RC opnieuw wordt aangemaakt
  // maar dat dit maar 1 keer gebeurd tijdens het Create-event.
  // VREDRAW & HREDRAW vlaggen zetten als er tijdens een resize moet worden getekend..
  Params.WindowClass.style := (Params.WindowClass.style or CS_OWNDC {or CS_VREDRAW or CS_HREDRAW});
  // !NB: CS_OWNDC gaat mis tijdens een fullscreen-swap..daarom dan even GL uitschakelen..

  // fullscreen venster eigenschappen
  //Params.WindowClass.style := (Params.WindowClass.style {or WS_POPUP or WS_CLIPSIBLINGS or WS_CLIPCHILDREN});
end;


procedure TfOpenGL.FormCreate(Sender: TObject);
var AppPath: string;
begin
  Top := 250;
  Left := 100;
  // het OpenGL-object instantiëren
  OGL := TOGL.Create;
  // de helptext stringlist
  HelpText := TStringList.Create;
  // texture zoekpaden instellen
  AppPath := ExtractFilePath(Application.ExeName);
  OGL.Textures.AddSearchDir(AppPath +'textures\');
  OGL.Textures.AddSearchDir(AppPath +'textures\BG\');
  OGL.Textures.AddSearchDir(AppPath +'textures\Env\');
  OGL.Textures.AddSearchDir(AppPath +'models\');
  OGL.Textures.AddSearchDir(AppPath +'maps\');
  OGL.Textures.AddSearchDir('E:\install\Wolfenstein\pak0.pk3\textures\');
  OGL.Textures.AddSearchDir(AppPath);
  // de standaard muiscursor gebruiken
  Cursor := crDefault;
  // de standaard camera gebruiken
//  OGL.Camera.Default;
  Player.Camera.Default;
(*
  // FPS-meting
  FPS_ := 0;
  FPSCount := 0;
  PerformanceCount := 0;
  QueryPerformanceFrequency(PerformanceFreq);
*)
(*
  // stel de priority van dit process in..
  //   NORMAL_PRIORITY_CLASS:
  //     Specify this class for a process with no special scheduling needs.
  //   IDLE_PRIORITY_CLASS:
  //     Specify this class for a process whose threads run only when the system is idle.
  //   HIGH_PRIORITY_CLASS:
  //     Specify this class for a process that performs time-critical tasks that must be executed immediately.
  //   REALTIME_PRIORITY_CLASS:
  //     Specify this class for a process that has the highest possible priority.
  PriorityClass := GetPriorityClass(GetCurrentProcess);
  Priority      := GetThreadPriority(GetCurrentThread);
  SetPriorityClass(GetCurrentProcess, REALTIME_PRIORITY_CLASS);
  SetThreadPriority(GetCurrentThread, THREAD_PRIORITY_TIME_CRITICAL);
*)
end;

procedure TfOpenGL.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
(*
  // priority herstellen..
  SetThreadPriority(GetCurrentThread, Priority);
  SetPriorityClass(GetCurrentProcess, PriorityClass)
*)
  TimerFPS.Enabled := false;
  Player.Camera.MouseControlled := false;
  {OGL.MouseLook := false;}
  // OpenGL uitschakelen
  if OGL.Active then begin
    {Quake3BSP.FreeTextures;
    Obj3DModel.FreeTextures;
    SkyBox.FreeTextures;}
    OGL.Disable;
  end;
end;

procedure TfOpenGL.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  // de standaard muiscursor gebruiken
  Cursor := crDefault; //ShowCursor(true);
end;

procedure TfOpenGL.FormDestroy(Sender: TObject);
{var Dummy: integer;}
begin
  // het OpenGL-object vrijgeven
  OGL.Free;
  // de Helptext stringList vrijgeven
  HelpText.Free;
(*
  // ALT-TAB & CTRL-ALT-DEL gebruik inschakelen
  SystemParametersInfo(SPI_SCREENSAVERRUNNING, word(false), @Dummy, 0);
*)
end;

procedure TfOpenGL.FormPaint(Sender: TObject);
begin
  {if OGL.glPaused then DrawFrame;}
end;

procedure TfOpenGL.FormCanResize(Sender: TObject; var NewWidth, NewHeight: Integer; var Resize: Boolean);
var W,H: integer;
begin
  W := Width - ClientWidth;   // de ruimte die windiws-onderdelen innemen (border,caption..)
  H := Height - ClientHeight; //
  if (NewWidth <= W) or (NewHeight <= H) then begin
    // de client ruimte wordt te klein..de resize mag niet doorgaan.
    Resize := false;
  end else begin
  end;
//  if NewHeight = 0 then NewHeight := 1;
  Resize := true;
end;

procedure TfOpenGL.FormResize(Sender: TObject);
begin
  // het midden van het form bepalen
  CalculateCenter;
  // vorige cursor-positie
  if Player.Camera.MouseControlled then begin
    LastX := CenterY;
    LastY := CenterX;
  end else begin
    LastX := 0;
    LastY := 0;
  end;
  // OpenGL projectie
  // width-8, height-27 in dit geval..aan deze comp in Uje
  OGL.Resize(ClientWidth, ClientHeight);
  if OGL.Active then DrawFrame;  //afbeelden tijdens een resize..
end;

procedure TfOpenGL.FormShow(Sender: TObject);
begin
  HelpText.Clear;
  // opengl initiëren
  InitGraphics;
  //ShowWindow(Application.Handle, SW_HIDE);
end;

procedure TfOpenGL.InitGraphics;
begin
  if not OGL.Active then begin
    OGL.Enable(Handle);

    // belichting instellen
    Lights.Clear;
(*
    //een stilstaand licht.
    Lights.Add(Vector(-3.0, 3.0, 30.0), DefaultLightDiffuse); //positie,kleur
*)
(*
    //een koplamp aan de camera
    Lights.Add(NullVector, DefaultLightDiffuse); //positie,kleur
    Lights.SetAsFloating(0);
    Lights.AlignToCamera(0, Camera);
*)
(*
    //een spotlicht-koplamp aan de camera
    Lights.Add(NullVector, DefaultLightDiffuse); //positie,kleur
    Lights.SetAsSpot(0, NullVector, 30.0, 2.0);  //index, direction,cutoff,exponent
    Lights.SetAsFloating(0);
    Lights.AlignToCamera(0, Camera);
*)
    Lights.LightsOff;
    Lights.DoLighting;

    // SkyBox textures aanmaken..
//    OGL.SkyBox.Active := OGL.SkyBox.InitTextures('TerraLeft.bmp','TerraRight.bmp','TerraBottom.bmp','TerraTop.bmp','TerraFront.bmp','TerraBack.bmp');
    OGL.SkyBox.Active := OGL.SkyBox.InitTextures('Terra');
    {OGL.SkyBox.Active := OGL.SkyBox.InitTextures('badlandsLeft.tga','badlandsRight.tga','badlandsBottom.tga','badlandsTop.tga','badlandsFront.tga','badlandsBack.tga');}
    {OGL.SkyBox.Active := OGL.SkyBox.InitTextures('WijsthoekLeft.jpg','WijsthoekRight.jpg','WijsthoekBottom.jpg','WijsthoekTop.jpg','WijsthoekFront.jpg','WijsthoekBack.jpg');}

    // radar textures aanmaken..
    Radar_TextureHandle := {fOpenGL.}OGL.Textures.LoadTexture('radar.bmp');
    {RadarMask_TextureHandle := fOpenGL.OGL.Textures.LoadTexture('radarmask.bmp');}

    {Spark_TextureHandle := fOpenGL.OGL.Textures.LoadTexture('spark.bmp');}
    Spark_TextureHandle := {fOpenGL.}OGL.Textures.LoadTexture('LensFlare0.jpg'); //dit plaatje is mooier.. :-)

    LensFlare.Flare_TextureHandle[0] := {fOpenGL.}OGL.Textures.LoadTexture('LensFlare0.jpg');
    LensFlare.Flare_TextureHandle[1] := {fOpenGL.}OGL.Textures.LoadTexture('LensFlare1.jpg');
    LensFlare.Flare_TextureHandle[2] := {fOpenGL.}OGL.Textures.LoadTexture('LensFlare2.jpg');
    LensFlare.Flare_TextureHandle[3] := {fOpenGL.}OGL.Textures.LoadTexture('LensFlare3.jpg');

    // 3D-object textures aanmaken..
    Obj3DModel.InitTextures;

    // De map
    Quake3BSP.TextureUnitsToUse(OGL.GetMaxTextureUnits); //zo veel mogelijk texture-units gebruiken..
    Quake3BSP.DrawWireFrame(false);                      //geen wireframe afbeelden
    Quake3BSP.DrawPointFrame(false);                     //geen pointframe afbeelden
    Quake3BSP.DrawHiddenLineRemoval(false);              //geen hidden-line removal
    Quake3BSP.DrawTextures(true);                        //textures afbeelden
    Quake3BSP.DrawLightMaps(true);                       //lightmaps afbeelden
    {Quake3BSP.LoadBSP('maps\Quake3.bsp');}

    //terrein
//    Terrain.Init(ExtractFilePath(Application.ExeName) + 'textures\TerrainHeightmap.bmp');

OGL.Textures.AddSearchDir('E:\install\Wolfenstein\pak0.pk3\textures\');
  end;
end;

procedure TfOpenGL.HideForm;
begin
  // camera mbv. muisbesturing uitschakelen..
  Player.Camera.MouseControlled := false;
  SetCaptureControl(nil);      //mouse-event capture opheffen..
  Cursor := crDefault;
  // evt. fullscreenmode uitschakelen
  if OGL.FullScreen then ToggleFullScreen;
  //
  Hide;
end;

(*
function TfOpenGL.VerticalRefreshRate: Integer;
var Desktop: HDC;
begin
  Desktop := GetDC(0);
  Result := GetDeviceCaps(Desktop, VREFRESH);
  ReleaseDC(0, Desktop);
end;
*)

procedure TfOpenGL.HandleMouseControl;
begin
  if not Visible then Exit;
end;

procedure TfOpenGL.CalculateCenter;
var {W,}H: integer;
begin
  // het midden van het form bepalen in scherm-coördinaten
  {W := Width - ClientWidth;}
  H := Height - ClientHeight;
  CenterX := Left+(Width div 2);
  CenterY := Top+(Height div 2);
end;

procedure TfOpenGL.ToggleMouseControl;
begin
  Player.Camera.ToggleMouseControl;
  if Player.Camera.MouseControlled then begin
    Cursor := crNone;
    SetCaptureControl(fOpenGL);    //mouse-event capture
    SetCursorPos(CenterX, CenterY);
  end else begin
    {SetCaptureControl(nil);}      //mouse-event capture opheffen..
    ReleaseCapture;                //mouse-event capture opheffen..
    Cursor := crDefault;
  end;
end;

procedure TfOpenGL.ToggleFullScreen;
var f,m: boolean;
    Dummy: integer;
begin
  if not OGL.Active then Exit;
  //
  f := OGL.FullScreen;
  m := Player.Camera.MouseControlled;

  // mouseLook uitschakelen tijdens een fullscreen-wissel
  if m then Player.Camera.ToggleMouseControl;

  // opengl tijdelijk afsluiten tijdens een fullscreen-wissel
  OGL.Paused := true;
  {Quake3BSP.FreeTextures;
  Obj3DModel.FreeTextures;
  SkyBox.FreeTextures;}
  OGL.Disable;  //OpenGL stoppen

  // form instellen en swappen
  if not f then begin
    //--- naar FullScreen omschakelen..
    BorderStyle := bsNone;
    // huidige positie en grootte bewaren..
    FormLeft := Left;
    FormTop := Top;
    FormWidth := Width;
    FormHeight := Height;
    // nieuwe positie en grootte instellen..
    Left := 0;
    Top := 0;
    Width := Screen.Width;
    Height := Screen.Height;
  end;

  // displaymode omschakelen
  OGL.ToggleFullScreen;

  if f then begin
    //--- naar windowed overschakelen
    BorderStyle := bsSizeable;
    Top := FormTop;
    Left := FormLeft;
    Width := FormWidth;
    Height := FormHeight;
  end;
  OGL.Paused := false;
  InitGraphics;
  if Quake3BSP.GetLastLoadedMap <> '' then Quake3BSP.LoadBSP(Quake3BSP.GetLastLoadedMap);

  // mouseLook evt. weer inschakelen na de fullscreen-wissel
  if m then Player.Camera.ToggleMouseControl;

(*
  // ALT-TAB & CTRL-ALT-DEL..
  if OGL.glFullScreen then begin
    // ..uitschakelen tijdens fullscreen mode..
    SystemParametersInfo(SPI_SCREENSAVERRUNNING, word(true), @Dummy, 0);
  end else begin
    // ..inschakelen tijdens windowed mode..
    SystemParametersInfo(SPI_SCREENSAVERRUNNING, word(false), @Dummy, 0);
  end;
*)
end;

procedure TfOpenGL.ToggleHelp;
begin
  if HelpText.Count = 0 then begin
    // help tekst opmaken..
    HelpText.Add('ESC          hide OpenGL-window');
    HelpText.Add('F1           Help');
    HelpText.Add('F            Fullscreen');
    HelpText.Add('M            Mouse-look');
    HelpText.Add('F4           Lens-flare');
    HelpText.Add('F8           Fog');
    HelpText.Add('B F9         SkyBox');
    HelpText.Add('1            Use 1 texture-unit');
    HelpText.Add('2            Use 2 texture-units');
    HelpText.Add('L            toggle Lightmaps');
    HelpText.Add('T            toggle Textures');
    HelpText.Add('H F10        toggle Hidden-line-removal');
    HelpText.Add('NumPad-0 F11 toggle Wireframe');
    HelpText.Add('NumPad-. F12 toggle Pointframe');
    HelpText.Add('F6           toggle Floating Camera');
    HelpText.Add('C F7         toggle BSP Collision detection');
    HelpText.Add('V            toggle Monitor Vertical Retrace Sync');
    HelpText.Add('R            Reset camera');
  end else
    // help tekst verwijderen
    HelpText.Clear;
end;




//--- FPS meting ---------------------------------------------------------------
procedure TfOpenGL.TimerFPSTimer(Sender: TObject);
//var s: string;
//    Interval: Int64;
begin
  // elke seconde de Frames-Per-Second teller bijwerken
  OGL.FPSTimer;
(*
  Interval := PerformanceCount - LastPerformanceCount;
  FrameTime := 1/(PerformanceFreq / Interval);    //tijdsduur in seconden..
  {FPS_ := round(int(1/FrameTime));               //FPS tijdens allerlaatste frame}
  FPS_ := FPSCount;                               //gemiddelde FPS de afgelopen seconde
  FPSCount := 0; //opnieuw tellen..
*)
end;

(*
procedure TfOpenGL.MeasureFPS;
begin
  Inc(FPSCount);  //het gemiddeld aantal FPS berekenen (per seconde)
  // meet de tijdsduur nodig voor het tekenen van het laatste frame
  LastPerformanceCount := PerformanceCount;
  QueryPerformanceCounter(PerformanceCount);
end;

function TfOpenGL.FPS: integer;
begin
  Result := FPS_;
end;

function TfOpenGL.GetFrameTime: Single;
begin
  Result := FrameTime;
end;
*)
//------------------------------------------------------------------------------

procedure TfOpenGL.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
  //---
  procedure DoMouse();
  var R: TVector;
  begin
      // rekening houden met de bewegings-gevoeligheid
      DeltaX := DeltaX * Player.Camera.SensitivityX;
      DeltaY := DeltaY * Player.Camera.SensitivityY;
      // draai de camera rond op de huidige positie om de Y-as (linksom/rechtsom)
      R := Vector(0.0, DeltaX, 0.0);
      Player.Camera.RotateLineOfSight(R);
      // verplaats LookAt voor bewegingen omhoog/omlaag
      Player.Camera.Target.Y := Player.Camera.Target.Y - DeltaY/200.0;
  end;
  //---
begin
  if not Visible then Exit;
  // linksom/rechtsom roteren van de camera gaat prima om de Y-as.
  // Als we willen roteren om de X-as (boven/onder), dan moet de UpY-vector
  // ook worden aangepast, anders komt de camera nooit op z'n kop!..
  // Het beeld van een player-model in-game flipt nooit over (zodat het beeld nooit op z'n kop zal zijn).
  // Als de camera omhoog moet kijken, en nooit moet flippen, dan verhoog ik de
  // Camera.LookAt Y-positie. De richting van kijken zal dan nooit flippen want
  // de camera blijft dan altijd vooruit kijken (alleen wat hoger steeds).
  // De lengte van de LineOfSight-vector wordt ook steeds groter (bij verhogen van
  // de Cam.LookAt.Y coördinaat)..Evt. een UnitVector van maken indien nodig..

  // camera-besturing met de muis?
  if Player.Camera.MouseControlled then begin
    //de muis delta's..
    DeltaX := Mouse.CursorPos.X - CenterX;
    DeltaY := Mouse.CursorPos.Y - CenterY;
    if (DeltaX<>0) or (DeltaY<>0) then begin
      // cursor weer in het midden van het scherm/form plaatsen.
      Mouse.CursorPos := Point(CenterX, CenterY);
      DoMouse;
    end;
  end else begin // geen camera-besturing met de muis..
    // rechter muisknop ingedrukt?
    if (ssRight in Shift) then begin
      //de muis delta's..
      DeltaX := X - LastX;
      DeltaY := Y - LastY;
      DoMouse;
    end;
  end;
  // laatste cursor-positie onthouden..
  LastX := X;
  LastY := Y;
end;


procedure TfOpenGL.FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var P: TPoint;
begin
  case Button of
    mbLeft : begin
        // Een lijn trekken (raytracing) vanaf Camera.Eye in richting Camera.LineOfSight.
        // De lijn stopt als deze op een brush.texture botst.
        Shoot(Player.Camera.Position, Player.Camera.LineOfSight);
      end;
    mbMiddle : begin
      end;
    mbRight : begin
(*
        P := ClientToScreen(Point(X,Y));
        popupView.Popup(P.X,P.Y);
*)        
      end;
  end;
end;


procedure TfOpenGL.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    // form
    VK_ESCAPE: HideForm;
    VK_F1: ToggleHelp;
    Ord('f'), Ord('F'): ToggleFullScreen;                          //volledig scherm of windowed
    Ord('m'), Ord('M'): ToggleMouseControl;                        //camera rotatie met de muis besturen
    VK_F8: OGL.ToggleFog;                                          //(bijna zwarte) mist of geen mist
    VK_F4: LensFlare.ToggleFlare;                                  //een lens-flare afbeelden
    // SkyBox
    Ord('b'), Ord('B'), VK_F9: OGL.SkyBox.TogglePaused;            //een skybox afbeelden of zwarte achtergrond
    // BSP
    Ord('1'): Quake3BSP.TextureUnitsToUse(1);                      //1 texture-unit gebruiken bij afbeelden BSP..;
    Ord('2'): Quake3BSP.TextureUnitsToUse(OGL.GetMaxTextureUnits);    //2 texture-units gebruiken bij afbeelden BSP..;
    Ord('h'), Ord('H'), VK_F10: Quake3BSP.ToggleHiddenLineRemoval; //and hidden-line removal..
    VK_NUMPAD0, VK_F11: Quake3BSP.ToggleWireFrame;                 //and wireframe
    VK_DECIMAL, VK_F12: Quake3BSP.TogglePointFrame;                //or pointframe
    Ord('l'), Ord('L'): Quake3BSP.ToggleLightMaps;                 //lightmaps afbeelden;
    Ord('t'), Ord('T'): Quake3BSP.ToggleTextures;                  //textures afbeelden;
    // camera
    Ord('c'), Ord('C'), VK_F7: Player.Camera.ToggleCollide;        //camera collisions
    VK_F6: Player.Camera.ToggleFloating;                           //zwevende camera (zonder zwaartekracht)
    Ord('r'), Ord('R'): Player.Camera.Default;                     //standaard camera instellingen
    {Ord('v'),} Ord('V'): OGL.ToggleVSync;                         //monitor Vertical Sync
(*
    // speciale toetsen..zijn verhuisd naar unit uDisplay
    // dwz. "W","S","A","D" & " "
*)
    VK_CONTROL: Player.Crouch(true);
  end;
end;


procedure TfOpenGL.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_CONTROL: Player.Crouch(false);
  end;
end;

end.
