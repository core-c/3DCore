unit uOpenGL;
interface
uses Windows, OpenGL, uConst, uFrustum, uTexture, uFont, uCamera, uSkyBox;

const
  {===== ERROR CONSTANTS =====}
  error_GetDC = -1;
  error_ChoosePixelFormat = -2;   //describePixelFormat erbij nog ?..
  error_SetPixelFormat = -3;
  error_MakeRC = -4;
  error_MakeCurrent = -5;
  error_CreatingTexture = -6;
  error_GenList = -7;


//  DefaultFogColor : TGLArrayf4 = (0.1, 0.1, 0.1, 1.0);
  DefaultFogColor : TGLArrayf4 = (1.0, 1.0, 1.0, 1.0);

const
  // Projectie Typen
  ptOrthogonal  = 1;
  ptPerspective = 2;
  ptFrustum     = 3;

type
  TRightAngle = (Angle0=0,Angle90=90,Angle180=180,Angle270=270);


  // een rectangle met floating point boundries (in bereik[0.0 .. 1.0])
  TFRect = record
    // padding (percentages van de gehele venster-breedte & -hoogte)
    top, left, bottom, right: Single;
    // vaste padding waarden (in pixels)
    pxTop, pxLeft, pxBottom, pxRight: Integer;
  end;

  TProjection = record
    ProjectionType: integer;
    Width, Height: integer;
    Center: TPoint;
    // De padding (tussen venster en viewport)
    // (waarden in bereik[0..1])
    // Dit zijn percentages van de gehele viewport-breedte & -hoogte.
    // Een waarde van 0.5 voor .left zorgt ervoor dat er aan de linkerkant
    // langs de viewport een ruimte open is, die de helft van het venster breed is.
    ViewPortRect: TFRect;
    //
    Left,Right,
    Bottom,Top,
    zNear,zFar: Extended;
    FOVY: Extended;
  end;

  TOGL = class(TObject)
    private
      // Camera's
      local_Camera: TCamera;                       // de camera voor intern OpenGL gebruik
      // tbv. de properties
      local_WinHandle: HWND;                       // Windows handle Form
      local_DC: HDC;                               // Windows handle Device-Context
      local_RC: HGLRC;                             // OpenGL handle Render-Context
      local_Width,                                 // huidige form breedte
      local_Height: integer;                       // huidige form hoogte
      local_Active,                                // actief
      local_Paused,                                // gepauzeerd
      local_FullScreen,                            // volledig scherm
      local_Fog: boolean;                          // mist
      local_Projection: TProjection;               // projectie
      local_FPS,                                   // het aantal beelden per seconde
      local_FPSCount: integer;                     //
      local_LastFrameTime: single;                 // de tijdsduur die nodig was om het laatste beeld te renderen
      PerformanceFreq, PerformanceCount, LastPerformanceCount: Int64;
      // de camera(-rotatie) met de muis besturen
      local_MouseLook: boolean;
      //-- /properties
      Palette : hPalette;           //OpenGL palette
      local_VSync,
      OldVSync: GLint;              // de instelling van de VSync opvragen om te herstellen na afloop App.
      N_TextureUnits: Integer;      //aantal texture units aanwezig..
      procedure SetupFullScreen(State: boolean);    // van/naar volledig scherm omschakelen
      procedure SetupFog(State: boolean); overload; // mist in/uitschakelen
      procedure Init;                               // OpenGL instellingen
      // tbv. de properties
      {procedure SetWinHandle(const Value: HWND);}
      function GetActive : Boolean;
      {procedure SetActive(const Value: boolean);}
      procedure SetPaused(const Value: boolean);
      procedure SetFullScreen(const Value: boolean);
      procedure SetMouseLook(const Value: boolean);
      procedure SetFog(const Value: boolean);
      function GetCenter: TPoint;
      function GetHeight: integer;
      function GetWidth: integer;
      // OpenGL EXTENSIONS
      procedure GetExtensionProcs;
      //
    published
      property WinHandle: HWND     read local_WinHandle;
      property DC: HDC             read local_DC;
      property RC: HGLRC           read local_RC;
      property Active: boolean     read GetActive;
      property Paused: boolean     read local_Paused     write SetPaused;
      property FullScreen: boolean read local_FullScreen write SetFullScreen;
      property MouseLook: boolean  read local_MouseLook  write SetMouseLook;
      property Fog: boolean        read local_Fog        write SetFog;
      property Width: integer      read GetWidth;   // breedte van het hele grafische scherm
      property Height: integer     read GetHeight;  // hoogte van het hele grafische scherm
      property Center: TPoint      read GetCenter;  // centrum van het hele grafische scherm
    public
      // objecten
      Frustum: TFrustum;                            // het frustum
      Textures: TObjTexture;                        // textures
      Fonts: TGLFont;                               // lettertypen
      Camera: PCamera;                              // Een pointer naar de camera
      SkyBox: TSkyBox;                              // de SkyBox
      // this.object
      constructor Create;
      destructor Destroy; override;
      // projectie
      procedure SetupViewPort(aProjection: TProjection);
      procedure Resize(NewWidth, NewHeight: integer);
      procedure SetupProjection; overload;
      procedure SetupProjection(Width,Height: integer; fLeft,fRight,fBottom,fTop,fNear,fFar: Extended); overload; //frustum
      procedure SetupProjection(Width,Height: integer; FOVY, pNear,pFar: Extended); overload; //perspective
      procedure SetupProjection(Width,Height: integer; oLeft,oRight,oBottom,oTop: Extended); overload; //ortho
      procedure SetupFor2D;
      // fullscreen
      procedure ToggleFullScreen;
      //de camera(-rotatie) met de muis besturen
      procedure ToggleMouseLook;
      // fog
      procedure SetupFog(Mode: Cardinal; Density, StartDepth,EndDepth: Single; const FogColor: TGLArrayf4; Hint: Cardinal); overload;
      procedure SetupFog(Density, StartDepth, EndDepth: Single; const FogColor: TGLArrayf4); overload;
      procedure ToggleFog;

      // OpenGL in-/uit-schakelen
      procedure Enable(WindowHandle: HWND);         // OpenGL inschakelen
      procedure Disable;                            // OpenGL uitschakelen
      procedure DoBufferSwap;                       // doublebuffer swap
      procedure ReportErrorAndQuit(ErrorCode: integer);
      // OpenGL EXTENSIONS
      function ExtensionSupported(Ext: string) : boolean;

      procedure PushMatrices;  // push de projection- & modelview-matrices
      procedure PopMatrices;   // pop  de modelview- & projection-matrices

      // Windows fonts 3D & 2D
      procedure PrintXY(X, Y: integer; const Value: string; R,G,B: Single);
      procedure PrintLine(Row: integer; const Value: string; VAlign: TLineVAlignment; R,G,B: Single);

      // monitor refresh rate control
      function MonitorRefreshRate: Integer;
      function GetVSync(var OnOff: boolean) : boolean;          //resultaat = true als het instellen is gelukt, anders false
      function SetVSync(OnOff: boolean) : boolean; overload;    //resultaat = true als het instellen is gelukt, anders false
      function SetVSync(OnOff: integer) : boolean; overload;    //resultaat = true als het instellen is gelukt, anders false
      procedure ToggleVSync;
      //
      function GetMaxTextureUnits : GLint;
      // FPS meting
      procedure FPSTimer;    // de routine die elke seconde dient te worden aangeroepen
      procedure MeasureFPS;  // de routine die na elke frame-render dient te worden aangeroepen
      function GetFPS : integer;
      function GetLastFrameTime : single;

      //=== sub-routines die werken met 2D scherm-coördinaten
      // 2D vlakken tekenen (met alpha-blending)
      procedure AlphaRectangle2D(Rectangle: TRect; R,G,B,A: Single); overload;
      procedure AlphaRectangle2D(Rectangle: TRect; R,G,B,A: Single; BlendSRC,BlendDST: Cardinal); overload;
      // 2D vlakken tekenen (met texture)
      procedure TexturedRectangle2D(Rectangle: TRect; R,G,B,A: Single; TextureHandle: GLuint; AngleCCW: TRightAngle);
      // 2D punt tekenen
      procedure Point2D(ScrPx_X, ScrPx_Y: integer; R,G,B,A: Single; PointSize: single);
      // 2D lijn tekenen
      procedure Line2D(ScrP1,ScrP2: TPoint; R,G,B,A: Single; LineWidth: single);
    end;


// OpenGL 1.2, 1.4 & 2.0 constanten, functies & procedures
const
  // Multi-texturing
  GL_MAX_TEXTURE_UNITS_ARB        = $84E2;
  GL_TEXTURE0_ARB                 = $84C0;
  GL_TEXTURE0                     = $84C0;
  GL_TEXTURE1_ARB                 = $84C1;
  GL_TEXTURE1                     = $84C1;
  GL_TEXTURE2_ARB                 = $84C2;
  GL_TEXTURE2                     = $84C2;
  GL_TEXTURE3_ARB                 = $84C3;
  GL_TEXTURE3                     = $84C3;

  // Fog extensions
  GL_FOG_COORDINATE_SOURCE_EXT    = $8450;
  GL_FOG_COORDINATE_SOURCE        = $8450;
  GL_FOG_COORD_SOURCE             = $8450;
  GL_FOG_COORD_SRC                = $8450;
  GL_FOG_COORDINATE_EXT           = $8451;
  GL_FOG_COORDINATE               = $8451;
  GL_FOG_COORD                    = $8451;
  GL_FRAGMENT_DEPTH               = $8452;
  GL_CURRENT_FOG_COORDINATE       = $8453;
  GL_CURRENT_FOG_COORD            = $8453;
  GL_FOG_COORDINATE_ARRAY_TYPE    = $8454;
  GL_FOG_COORD_ARRAY_TYPE         = $8454;
  GL_FOG_COORDINATE_ARRAY_STRIDE  = $8455;
  GL_FOG_COORD_ARRAY_STRIDE       = $8455;
  GL_FOG_COORDINATE_ARRAY_POINTER = $8456;
  GL_FOG_COORD_ARRAY_POINTER      = $8456;
  GL_FOG_COORDINATE_ARRAY         = $8457;
  GL_FOG_COORD_ARRAY              = $8457;


  GL_VERTEX_ARRAY                 = $8074;
  GL_NORMAL_ARRAY                 = $8075;
  GL_TEXTURE_COORD_ARRAY          = $8078;

  GL_CLAMP_TO_EDGE                = $812F; // GL 1.2

  GL_POLYGON_OFFSET_UNITS         = $2A00;
  GL_POLYGON_OFFSET_POINT         = $2A01;
  GL_POLYGON_OFFSET_LINE          = $2A02;
  GL_POLYGON_OFFSET_FILL          = $8037;
  GL_POLYGON_OFFSET_FACTOR        = $8038;

  GL_COMBINE                      = $8570;
  GL_COMBINE_RGB                  = $8571;
  GL_COMBINE_ALPHA                = $8572;
  GL_RGB_SCALE                    = $8573;
  GL_ADD_SIGNED                   = $8574;
  GL_INTERPOLATE                  = $8575;
  GL_CONSTANT                     = $8576;
  GL_PRIMARY_COLOR                = $8577;
  GL_PREVIOUS                     = $8578;
  GL_SOURCE0_RGB                  = $8580;
  GL_SOURCE1_RGB                  = $8581;
  GL_SOURCE2_RGB                  = $8582;
  GL_SOURCE0_ALPHA                = $8588;
  GL_SOURCE1_ALPHA                = $8589;
  GL_SOURCE2_ALPHA                = $858A;
  GL_OPERAND0_RGB                 = $8590;
  GL_OPERAND1_RGB                 = $8591;
  GL_OPERAND2_RGB                 = $8592;
  GL_OPERAND0_ALPHA               = $8598;
  GL_OPERAND1_ALPHA               = $8599;
  GL_OPERAND2_ALPHA               = $859A;
  GL_SUBTRACT                     = $84E7;
  //
  GL_COMBINE_EXT                  = $8570;
  GL_COMBINE_RGB_EXT              = $8571;
  GL_COMBINE_ALPHA_EXT            = $8572;
  GL_RGB_SCALE_EXT                = $8573;
  GL_ADD_SIGNED_EXT               = $8574;
  GL_INTERPOLATE_EXT              = $8575;
  GL_CONSTANT_EXT                 = $8576;
  GL_PRIMARY_COLOR_EXT            = $8577;
  GL_PREVIOUS_EXT                 = $8578;
  GL_SOURCE0_RGB_EXT              = $8580;
  GL_SOURCE1_RGB_EXT              = $8581;
  GL_SOURCE2_RGB_EXT              = $8582;
  GL_SOURCE0_ALPHA_EXT            = $8588;
  GL_SOURCE1_ALPHA_EXT            = $8589;
  GL_SOURCE2_ALPHA_EXT            = $858A;
  GL_OPERAND0_RGB_EXT             = $8590;
  GL_OPERAND1_RGB_EXT             = $8591;
  GL_OPERAND2_RGB_EXT             = $8592;
  GL_OPERAND0_ALPHA_EXT           = $8598;
  GL_OPERAND1_ALPHA_EXT           = $8599;
  GL_OPERAND2_ALPHA_EXT           = $859A;
  //
  GL_COMBINE_ARB                  = $8570;
  GL_COMBINE_RGB_ARB              = $8571;
  GL_COMBINE_ALPHA_ARB            = $8572;
  GL_SOURCE0_RGB_ARB              = $8580;
  GL_SOURCE1_RGB_ARB              = $8581;
  GL_SOURCE2_RGB_ARB              = $8582;
  GL_SOURCE0_ALPHA_ARB            = $8588;
  GL_SOURCE1_ALPHA_ARB            = $8589;
  GL_SOURCE2_ALPHA_ARB            = $858A;
  GL_OPERAND0_RGB_ARB             = $8590;
  GL_OPERAND1_RGB_ARB             = $8591;
  GL_OPERAND2_RGB_ARB             = $8592;
  GL_OPERAND0_ALPHA_ARB           = $8598;
  GL_OPERAND1_ALPHA_ARB           = $8599;
  GL_OPERAND2_ALPHA_ARB           = $859A;
  GL_RGB_SCALE_ARB                = $8573;
  GL_ADD_SIGNED_ARB               = $8574;
  GL_INTERPOLATE_ARB              = $8575;
  GL_SUBTRACT_ARB                 = $84E7;
  GL_CONSTANT_ARB                 = $8576;
  GL_PRIMARY_COLOR_ARB            = $8577;
  GL_PREVIOUS_ARB                 = $8578;

  GL_CONSTANT_COLOR_EXT           = $8001;
  GL_CONSTANT_ALPHA               = $8003;
  GL_ONE_MINUS_CONSTANT_ALPHA     = $8004;

  GL_CONSTANT_ALPHA_EXT           = $8003;
  GL_ONE_MINUS_CONSTANT_ALPHA_EXT = $8004;


  procedure glPolygonOffset(factor, units: GLfloat); stdcall; external 'opengl32.dll';

  procedure glDrawElements(mode: GLenum; count: GLsizei; atype: GLenum; indices: Pointer); stdcall; external 'opengl32.dll';
  procedure glDrawArrays(mode: GLenum; first: GLint; count: GLsizei); stdcall; external 'opengl32.dll';
  procedure glVertexPointer(size: GLint; atype: GLenum; stride : GLsizei; const pointer: Pointer); stdcall; external 'opengl32.dll';
  procedure glNormalPointer(atype: GLenum; stride: GLsizei; data: pointer); stdcall; external 'opengl32.dll';
  procedure glTexCoordPointer(size: GLint; atype: GLenum; stride : GLsizei; const pointer: Pointer); stdcall; external 'opengl32.dll';
  procedure glEnableClientState(id: GLuint); stdcall; external 'opengl32.dll';
  procedure glDisableClientState(id: GLuint); stdcall; external 'opengl32.dll';

  procedure glGenTextures(n: GLsizei; var textures: GLuint); stdcall; external 'opengl32.dll';
  procedure glBindTexture(target: GLenum; texture: GLuint); stdcall; external 'opengl32.dll';
  function glIsTexture(texture: GLuint): GLboolean; stdcall; external 'opengl32.dll';
  procedure glDeleteTextures(n: GLsizei; textures: PGLuint); stdcall; external 'opengl32.dll';
  function gluBuild2DMipmaps(Target: GLenum; Components, Width, Height: GLint; Format, atype: GLenum; Data: Pointer): GLint; stdcall; external 'glu32.dll';


var // Extensions
  glFogCoordfEXT           : procedure(coord: GLfloat); stdcall;
  // WGL_EXT_swap_control
  wglSwapIntervalEXT       : function(interval: GLint) : Boolean; stdcall;
  wglGetSwapIntervalEXT    : function : GLint; stdcall;
  // multi-texturing
  glClientActiveTextureARB : procedure(target: GLenum); stdcall;
  glActiveTextureARB       : procedure(target: GLenum); stdcall;
  glMultiTexCoord2f        : procedure(target: GLenum; s: GLfloat; t: GLfloat); stdcall;
  glMultiTexCoord2fv       : procedure(target: GLenum; const v: PGLfloat); stdcall;
  //
  glBlendColorEXT          : procedure(red: GLclampf; green: GLclampf; blue: GLclampf; alpha: GLclampf); stdcall;


var OGL: TOGL;


implementation
uses Forms, Types, uCalc;


{ TOGL }
//-- properties lezen en aanpassen/schijven
{procedure TOGL.SetWinHandle(const Value: HWND);
begin
  if Value <> local_WinHandle then begin
    if Active then begin
      Disable;                     // OpenGL uitschakelen..
      FullScreen := false;         // evt. de volledige scherm modus uitschakelen..
    end;
    local_WinHandle := Value;
  end;
end;}

function TOGL.GetActive: Boolean;
begin
  local_Active := ((local_DC<>0) and (local_RC<>0));
  Result := local_Active;
end;
{procedure TOGL.SetActive(const Value: boolean);
begin
  if Value <> local_Active then
    local_Active := Value;
end;}

procedure TOGL.SetPaused(const Value: boolean);
begin
  if Value <> local_Paused then
    local_Paused := Value;
end;

procedure TOGL.SetFullScreen(const Value: boolean);
begin
  if not Active then Exit;
  if Value <> local_FullScreen then begin
    local_FullScreen := Value;
    SetupFullScreen(local_FullScreen);
  end;
end;

procedure TOGL.SetMouseLook(const Value: boolean);
begin
  if Value <> local_MouseLook then local_MouseLook := Value;
end;
procedure TOGL.ToggleMouseLook;
begin
  local_MouseLook := not local_MouseLook;
end;

procedure TOGL.SetFog(const Value: boolean);
begin
  if not Active then Exit;
  if Value <> local_Fog then begin
    local_Fog := Value;
    SetupFog(local_Fog);
  end;
end;
function TOGL.GetWidth: integer;
begin
  Result := local_Projection.Width;
end;
function TOGL.GetHeight: integer;
begin
  Result := local_Projection.Height;
end;
function TOGL.GetCenter: TPoint;
begin
  Result := local_Projection.Center;
end;
//-- /properties



constructor TOGL.Create;
begin
  // Object initiëren
  inherited;
  // Data initialiseren
  local_WinHandle := 0;                // nog geen Window-handle toegewezen..
  local_DC := 0;                       // nog geen Device-Context toegewezen..
  local_RC := 0;                       // nog geen RenderContext toegewezen..
  local_Width := 0;                    // form breedte
  local_Height := 0;                   // form hoogte
  local_Active := false;               // OpenGL niet actief
  local_Paused := false;               // niet gepauzeerd
  local_FullScreen := false;           // windowed
  local_Fog := false;                  // mist uitschakelen

  local_VSync := 1;                    // standaard Vertical Retrace Sync aan
  OldVSync := local_VSync;

  local_FPS := 0;                      // 0 beelden per seconde
  local_FPSCount := 0;                 //
  local_LastFrameTime := 0.0;          // de tijdsduur die nodig was om het laatste beeld te renderen
  PerformanceCount := 0;
  QueryPerformanceFrequency(PerformanceFreq);

  local_MouseLook := false;

  with local_Projection do begin       // Projectie
    ProjectionType := ptPerspective;
    Width := local_Width;
    Height := local_Height;

    //FOVY := 65.0;
    FOVY := GetAngleFOV(MaxViewDistance, MaxViewDistance);

    zNear := 1.0;
    zFar := MaxViewDistance;
    Center := Point(0,0);
    // De padding (tussen venster en viewport)
    // (waarden in bereik[0..1])
    // Dit zijn percentages van de gehele viewport-breedte & -hoogte.
    // Een waarde van 0.5 voor .left zorgt ervoor dat er aan de linkerkant
    // langs de viewport een ruimte open is, die de helft van het venster breed is.
    ViewPortRect.top := 0.0;
    ViewPortRect.left := 0.0;
    ViewPortRect.bottom := 0.0;
    ViewPortRect.right := 0.0;
    // de vaste padding waarden (in pixels)
    ViewPortRect.pxTop := 0;
    ViewPortRect.pxLeft := 0;
    ViewPortRect.pxBottom := 0;
    ViewPortRect.pxRight := 0;
  end;
  N_TextureUnits := -1; //ongeldige waarde
  // objecten instantieren
  Frustum := TFrustum.Create;          // het frustum-object
  Textures := TObjTexture.Create;      // textures-object
  Fonts := TGLFont.Create;             // lettertypen-object
  local_Camera := TCamera.Create;      // het camera-object
  Camera := @local_Camera;             // gebruik local_Camera als de huidige camera
  SkyBox := TSkyBox.Create;            // SkyBox-object

  // Extensions
  glFogCoordfEXT := nil;
  wglSwapIntervalEXT := nil;
  wglGetSwapIntervalEXT := nil;
  glClientActiveTextureARB := nil;
  glActiveTextureARB := nil;
  glMultiTexCoord2f := nil;
  glMultiTexCoord2fv := nil;
  glBlendColorEXT := nil;
end;

destructor TOGL.Destroy;
begin
  // Data finaliseren
  SkyBox.Free;                         // SkyBox-object
  if local_Camera<>nil then begin
    local_Camera.Free;                 // het local_camera-object
    local_Camera := nil;
  end;
  if Camera<>nil then begin
//    Camera.Free;                       // het camera-object
    Camera := nil;
  end;
  Fonts.Free;                          // lettertypen
  Textures.Free;                       // het texture-object
  Frustum.Free;                        // het frustum-object
  Disable;                             // evt. OpenGL uitschakelen..
  // Object finaliseren
  inherited;
end;






procedure TOGL.Enable(WindowHandle: HWND);
var pfd: PIXELFORMATDESCRIPTOR;
    iFormat: integer;
    f: integer;
    aRect: TRect;
begin
  if Active then Exit;  //al actief? dan niet nog eens activeren..

  // Zoek het form met handle WindowHandle, en bepaal de dimensies..
(*  for f:=0 to Screen.FormCount-1 do
    if Screen.Forms[f].Handle = WindowHandle then begin
      local_Width := Screen.Forms[f].Width;
      local_Height := Screen.Forms[f].Height;
      Break;
    end;*)
  GetWindowRect(WindowHandle, aRect);
  local_Width := aRect.Right - aRect.Left;
  local_Height := aRect.Bottom - aRect.Top;

  // De DeviceContext (DC) opvragen
  local_WinHandle := WindowHandle;
  local_DC := GetDC(local_WinHandle);
  if (local_DC=0) then ReportErrorAndQuit(error_GetDC);
  // Het pixelformat voor de DC instellen
  ZeroMemory(@pfd, sizeof(pfd));
  pfd.nSize := sizeof(pfd);
  pfd.nVersion := 1;
  pfd.dwFlags := (PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER);
  pfd.iPixelType := PFD_TYPE_RGBA;
  pfd.cColorBits := 32;   //8 bits per bitplane
  pfd.cDepthBits := 24;   //24-bits Z-buffer
  pfd.iLayerType := PFD_MAIN_PLANE;
  iFormat := ChoosePixelFormat(DC,@pfd);
  if (iFormat=0) then ReportErrorAndQuit(error_ChoosePixelFormat);
  if (not SetPixelFormat(local_DC, iFormat, @pfd)) then ReportErrorAndQuit(error_SetPixelFormat);
  // Het palette instellen
  {setupPalette(DC);}
  // De RenderContext instellen
  local_RC := wglCreateContext(local_DC);
  if (local_RC=0) then ReportErrorAndQuit(error_MakeRC);
  if (not wglMakeCurrent(local_DC,local_RC)) then ReportErrorAndQuit(error_MakeCurrent);

  // De OpenGL-DLL entry-points opvragen voor de extensions
  GetExtensionProcs;
  
  // OpenGL instellingen
  Init;
end;

procedure TOGL.Disable;
begin
  if Active then begin // OpenGL actief? dan uitschakelen..
    // evt. aangemaakte textures wissen..
    Textures.DeleteTextures;
    // evt. aangemaakte font displaylists wissen..
{    Fonts.DeleteFont;}
    // OpenGL RC vrijgeven
    wglMakeCurrent(0,0);
    wglDeleteContext(local_RC);
    // het palette vrijgeven
    if (Palette<>0) then DeleteObject(Palette);
    // De DeviceContext vrijgeven
    ReleaseDC(WinHandle, local_DC);
  end;
  FullScreen := false; // evt. de volledige scherm modus uitschakelen..
  local_DC := 0;
  local_RC := 0;
  // VSync herstellen
  if ExtensionSupported('WGL_EXT_swap_control') then wglSwapIntervalEXT(OldVSync);
  local_VSync := OldVSync;
end;

procedure TOGL.DoBufferSwap;
begin
  // Ook een bufferswap als OpenGL is gepauzeerd..
  if Active then SwapBuffers(local_DC);
end;


function TOGL.ExtensionSupported(Ext: string): boolean;
var s: string;
begin
  s := glGetString(GL_EXTENSIONS);
  Result := (Pos(Ext, s)>0);
end;

procedure TOGL.GetExtensionProcs;
begin
  // de OpenGL-DLL procedure entry-points opvragen voor de extensions
  if ExtensionSupported('EXT_fog_coord') then
    glFogCoordfEXT := wglGetProcAddress('glFogCoordfEXT');

  if ExtensionSupported('WGL_EXT_swap_control') then begin
    wglSwapIntervalEXT := wglGetProcAddress('wglSwapIntervalEXT');
    wglGetSwapIntervalEXT := wglGetProcAddress('wglGetSwapIntervalEXT');
    // de huidige VSync instelling onthouden
    OldVSync := wglGetSwapIntervalEXT;
  end;

  // GL_ARB_multitexture
  if ExtensionSupported('GL_ARB_multitexture') then begin
    glClientActiveTextureARB := wglGetProcAddress('glClientActiveTextureARB');
    glActiveTextureARB := wglGetProcAddress('glActiveTextureARB');
    glMultiTexCoord2f := wglGetProcAddress('glMultiTexCoord2f');
    glMultiTexCoord2fv := wglGetProcAddress('glMultiTexCoord2fv');
  end;

  // GL_EXT_blend_color
  if ExtensionSupported('GL_EXT_blend_color') then begin
    glBlendColorEXT := wglGetProcAddress('glBlendColorEXT');
  end;
end;






procedure TOGL.Init;
begin
  if not Active then Exit;

  // Verticale beeldscherm refresh uitschakelen
  SetVSync(local_VSync);

  //het aantal texture units bepalen
  GetMaxTextureUnits;

  // projectie instellen
  SetupProjection;

  // mist standaard inschakelen..

//  SetupFog(GL_EXP, 0.0001, MaxViewDistance/2,MaxViewDistance, DefaultFogColor, GL_FASTEST);
  SetupFog(GL_LINEAR, 1.0, 0.0,1.0, DefaultFogColor, GL_FASTEST);
  SetupFog(local_Fog);

  // fonts
  Fonts.CreateFontDLs(local_DC, local_RC, 'Arial', 12, false); //2D-Arial 12px

  // Z-Buffer (diepte)
  glDepthFunc(GL_LESS);
  glDepthRange(0.0, 1.0);
  glDepthMask(GL_TRUE);         // depth-buffer is writable
  glEnable(GL_DEPTH_TEST);

  // culling
  glFrontFace(GL_CCW);
  glCullFace(GL_BACK);
  glEnable(GL_CULL_FACE);

  // form achtergrond
  glPolygonMode(GL_FRONT, GL_FILL);
  {glPolygonOffset(1.0, 1.0);}
  glDisable(GL_POLYGON_OFFSET_FILL);
  glClearDepth(1.0);
  glClearColor(0.0, 0.0, 0.0,  0.0);
  glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_FALSE);
  glDrawBuffer(GL_FRONT_AND_BACK);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT {or GL_STENCIL_BUFFER_BIT} );
  glDrawBuffer(GL_BACK);

  // render-performance
  glHint(GL_POINT_SMOOTH_HINT, GL_NICEST);  //GL_FASTEST, GL_NICEST, GL_DONT_CARE
  glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
  glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
  {glHint(GL_FOG_HINT, GL_NICEST);}
  glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);  //moet zijn GL_NICEST in-game..
  glDisable(GL_NORMALIZE); // normalen gebruik ik zelf
  glShadeModel(GL_SMOOTH);
  glDisable(GL_DITHER);
  glDisable(GL_BLEND);     // blending uit

  // environment-mapping
  glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
  glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
  glDisable(GL_TEXTURE_GEN_S);
  glDisable(GL_TEXTURE_GEN_T);

  //
  DoBufferSwap;
end;



procedure TOGL.ReportErrorAndQuit(ErrorCode: integer);
var s : PChar;
begin
  case ErrorCode of
    error_GetDC : s:='The device-context could not be determined';
    error_ChoosePixelFormat : s:='The pixel-format could not be determined.';
    error_SetPixelFormat : s:='The pixel-format could not be set.';
    error_MakeRC : s:='The render-context could not be made.';
    error_MakeCurrent : s:='The render-context could not be made current.';
    error_CreatingTexture : s:='A texture could not be created.';
    error_GenList : s:='A compiled list could not be created';
  else
    s := 'OpenGL Error';
  end;
  MessageBox(WindowFromDC(DC), s, 'OpenGL Error', MB_ICONERROR or MB_OK);
  if ErrorCode<>error_CreatingTexture then PostQuitMessage(ErrorCode);
end;


//--- VSync --------------------------------------------------------------------
function TOGL.MonitorRefreshRate: Integer;
var Desktop: HDC;
begin
  Desktop := GetDC(0);
  Result := GetDeviceCaps(Desktop, VREFRESH);
  ReleaseDC(0, Desktop);
end;

function TOGL.GetVSync(var OnOff: boolean): boolean;
begin
  Result := ExtensionSupported('WGL_EXT_swap_control');
  if Result then OnOff := (local_VSync=1);
end;

function TOGL.SetVSync(OnOff: boolean): boolean;
begin
  Result := ExtensionSupported('WGL_EXT_swap_control');
  if Result then begin
    if OnOff then begin
      local_VSync := 1;
      wglSwapIntervalEXT(1);
    end else begin
      local_VSync := 0;
      wglSwapIntervalEXT(0);
    end;
  end;
end;

function TOGL.SetVSync(OnOff: integer): boolean;
begin
  Result := SetVSync(OnOff<>0);
end;


procedure TOGL.ToggleVSync;
begin
  if ExtensionSupported('WGL_EXT_swap_control') then begin
    // de huidige VSync instelling onthouden
    if local_VSync = 0 then begin
      local_VSync := 1;
      wglSwapIntervalEXT(1);
    end else begin
      local_VSync := 0;
      wglSwapIntervalEXT(0);
    end;
  end;
end;



//-- FPS meting ----------------------------------------------------------------
procedure TOGL.FPSTimer;
begin
  local_FPS := local_FPSCount; //gemiddelde FPS de afgelopen seconde
  local_FPSCount := 0; //opnieuw tellen..
end;

procedure TOGL.MeasureFPS;
var Interval: Int64;
begin
  //het gemiddeld aantal FPS berekenen (per seconde)
  Inc(local_FPSCount);
  //tijdsduur laatste frame-render (in seconden)
  QueryPerformanceCounter(PerformanceCount);
  Interval := PerformanceCount - LastPerformanceCount;
  local_LastFrameTime := 1/(PerformanceFreq / Interval);
  //timing
  LastPerformanceCount := PerformanceCount;
end;

function TOGL.GetFPS: integer;
begin
  Result := local_FPS;
end;

function TOGL.GetLastFrameTime: single;
begin
  Result := local_LastFrameTime;
end;
//--


function TOGL.GetMaxTextureUnits: GLint;
begin
  if not Active then
    Result := -1
  else begin
    glGetIntegerv(GL_MAX_TEXTURE_UNITS_ARB, @N_TextureUnits);
    Result := N_TextureUnits;
  end;
end;



//--- Projection ---------------------------------------------------------------
procedure TOGL.SetupViewPort(aProjection: TProjection);
var Left,Top, Right,Bottom, W,H: Integer;
begin
  // viewport berekenen
  Left := Round(aProjection.ViewPortRect.left * aProjection.Width);
  Bottom := Round(aProjection.ViewPortRect.top * aProjection.Height); //!
  Right := Round(aProjection.ViewPortRect.right * aProjection.Width);
  Top := Round(aProjection.ViewPortRect.bottom * aProjection.Height); //!
  W := aProjection.Width - Right - Left;
  H := aProjection.Height - Bottom - Top;

  W := W - aProjection.ViewPortRect.pxLeft - aProjection.ViewPortRect.pxRight;
  H := H - aProjection.ViewPortRect.pxTop - aProjection.ViewPortRect.pxBottom;

  Left := Left + aProjection.ViewPortRect.pxLeft;
  Top := Top + aProjection.ViewPortRect.pxTop;

  // en instellen
  glViewPort(Left,Top, W,H);
end;

procedure TOGL.Resize(NewWidth, NewHeight: integer);
begin
  if (NewWidth=local_Projection.Width) and (NewHeight=local_Projection.Height) then Exit;
  //projectie
  local_Projection.Width := NewWidth;
  local_Projection.Height := NewHeight;
  local_Projection.Center := Point(NewWidth div 2, NewHeight div 2);
  //form
  local_Width := NewWidth;
  local_Height := NewHeight;
  SetupProjection;
end;

procedure TOGL.SetupProjection;
begin
  if not Active then Exit;
  // De huidige projectie instellen/herstellen
  with local_Projection do begin
    case ProjectionType of
      ptOrthogonal: SetupProjection(Width,Height, Left,Right, Bottom,Top);
      ptPerspective: SetupProjection(Width,Height, FOVY, zNear,zFar);
      ptFrustum: SetupProjection(Width,Height, Left,Right, Bottom,Top, zNear,zFar);
    end;
  end;
(*
  // de frustum clip-planes herberekenen
  Frustum.ClipPlanesFromFrustum;
*)  
end;

procedure TOGL.SetupProjection(Width, Height: integer; oLeft,oRight,  oBottom,oTop: Extended);
begin
  if not Active then Exit;
  // viewport berekenen
  SetupViewPort(local_Projection);
  // Orthogonaal
  {glViewPort(0,0, Width,Height);}
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  gluOrtho2D(oLeft,oRight, oBottom,oTop);  //Z-coördinaten moeten in bereik [-1..1] liggen !
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
end;

procedure TOGL.SetupProjection(Width, Height: integer; FOVY, pNear,pFar: Extended);
begin
  if not Active then Exit;
  // Perspective
  // viewport berekenen
  SetupViewPort(local_Projection);
  {glViewPort(0,0, Width,Height);}
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  {aspect := (Width * (local_Projection.ViewPortRect.right-local_Projection.ViewPortRect.left)) / (Height * (local_Projection.ViewPortRect.top-local_Projection.ViewPortRect.bottom));}
  gluPerspective(FOVY, Width/Height, pNear,pFar);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
end;

procedure TOGL.SetupProjection(Width,Height: integer; fLeft,fRight, fBottom,fTop, fNear,fFar: Extended);
begin
  if not Active then Exit;
  // Frustum
  // viewport berekenen
  SetupViewPort(local_Projection);
  {glViewPort(0,0, Width,Height);}
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glFrustum(fLeft,fRight, fBottom,fTop, fNear,fFar);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
end;

procedure TOGL.SetupFor2D;
begin
  if not Active then Exit;
  // orthogonaal afbeelden (geen perspectief)
  // !NB. De huidige projectie instellingen niet aanpassen..
  // viewport berekenen
  SetupViewPort(local_Projection);
  {glViewPort(0,0, local_Projection.Width,local_Projection.Height);}
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(0,local_Projection.Width, 0,local_Projection.Height, -1,1);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
end;




procedure TOGL.PushMatrices;
begin
  glMatrixMode(GL_PROJECTION);
  glPushMatrix;
  glMatrixMode(GL_MODELVIEW);
  glPushMatrix;
end;

procedure TOGL.PopMatrices;
begin
  glMatrixMode(GL_MODELVIEW);
  glPopMatrix;
  glMatrixMode(GL_PROJECTION);
  glPopMatrix;
end;





//--- FullScreen ---------------------------------------------------------------
procedure TOGL.SetupFullScreen(State: boolean);
const ENUM_CURRENT_SETTINGS  = $FFFFFFFF; //-1;
      ENUM_REGISTRY_SETTINGS = $FFFFFFFE; //-2;
var DM: TDeviceMode;
begin
  if not State then begin
    //volledig scherm uitschakelen
    ChangeDisplaySettings(TDeviceMode(nil^), 0);
  end else begin
    //volledig scherm inschakelen
    ZeroMemory(@DM, sizeof(DM));
    if not EnumDisplaySettings(nil, ENUM_CURRENT_SETTINGS, DM) then begin
      //ShowMessage('Volledig scherm modus is niet mogelijk');
      Exit;
    end;
    DM.dmPelsWidth := Screen.Width;
    DM.dmPelsHeight := Screen.Height;
    DM.dmFields := (DM_BITSPERPEL or DM_PELSWIDTH or DM_PELSHEIGHT or DM_DISPLAYFREQUENCY);
    if ChangeDisplaySettings(DM, CDS_FULLSCREEN) <> DISP_CHANGE_SUCCESSFUL then begin
      //ShowMessage('Volledig scherm modus is niet mogelijk');
      Exit;
    end;
  end;
end;

procedure TOGL.ToggleFullScreen;
begin
  FullScreen := not FullScreen;
end;




//--- Fog ----------------------------------------------------------------------
procedure TOGL.SetupFog(State: boolean);
begin
  if not Active then Exit;
  if State then glEnable(GL_FOG)
           else glDisable(GL_FOG);
end;

procedure TOGL.SetupFog(Mode: Cardinal; Density, StartDepth,EndDepth: Single; const FogColor: TGLArrayf4; Hint: Cardinal);
begin
  if not Active then Exit;
  glHint(GL_FOG_HINT, Hint);         //GL_NICEST, GL_FASTEST
  glFogf(GL_FOG_DENSITY, Density);
  glFogf(GL_FOG_START, StartDepth);
  glFogf(GL_FOG_END, EndDepth);
  glFogfv(GL_FOG_COLOR, @FogColor);
  glFog(GL_FOG_MODE, Mode);
  // extension
  glFogi(GL_FOG_COORDINATE_SOURCE_EXT, GL_FOG_COORDINATE_EXT);
end;

procedure TOGL.SetupFog(Density, StartDepth, EndDepth: Single; const FogColor: TGLArrayf4);
begin
  if not Active then Exit;
  glFogf(GL_FOG_DENSITY, Density);
  glFogf(GL_FOG_START, StartDepth);
  glFogf(GL_FOG_END, EndDepth);
  glFogfv(GL_FOG_COLOR, @FogColor);
  // extension
  glFogi(GL_FOG_COORDINATE_SOURCE_EXT, GL_FOG_COORDINATE_EXT);
end;

procedure TOGL.ToggleFog;
begin
  Fog := not Fog;
end;





//--- Fonts --------------------------------------------------------------------
procedure TOGL.PrintXY(X, Y: integer; const Value: string; R,G,B: Single);
begin
  if not (Active and (not Paused) and Fonts.IsFontLoaded) then Exit;
  glColor3f(R,G,B);
  Fonts.PrintXY(X,Y, Value, local_Width,local_Height);
  SetupProjection; //projectie herstellen met de laatst gebruikte lokale instellingen..
end;

procedure TOGL.PrintLine(Row: integer; const Value: string; VAlign: TLineVAlignment; R, G, B: Single);
begin
  if not (Active and (not Paused) and Fonts.IsFontLoaded) then Exit;
  glColor3f(R,G,B);
  Fonts.PrintLine(Row, Value, Valign, local_Width,local_Height);
  SetupProjection; //projectie herstellen met de laatst gebruikte lokale instellingen..
end;





//--- 2D Vlakken tekenen -------------------------------------------------------
procedure TOGL.AlphaRectangle2D(Rectangle: TRect; R,G,B,A: Single);
begin
  AlphaRectangle2D(Rectangle, R,G,B,A, GL_ONE,GL_SRC_ALPHA);
end;

procedure TOGL.AlphaRectangle2D(Rectangle: TRect; R, G, B, A: Single;  BlendSRC, BlendDST: Cardinal);
begin
  PushMatrices;
  SetupFor2D;

  glFrontFace(GL_CW);
  glCullFace(GL_BACK);
  glEnable(GL_CULL_FACE);
  glPolygonMode(GL_FRONT, GL_FILL);
  glDisable(GL_DEPTH_TEST);

  glDisable(GL_TEXTURE_2D);

  glEnable(GL_BLEND);
  //glBlendFunc(GL_ONE, GL_DST_ALPHA);
  //glBlendFunc(GL_ONE, GL_SRC_ALPHA);
  glBlendFunc(BlendSRC, BlendDST);

  glBegin(GL_QUADS);
    glColor4f(R, G, B, A);
    with Rectangle do begin
      glVertex2i(Left,  local_Projection.Height - Bottom);
      glVertex2i(Left,  local_Projection.Height - Top);
      glVertex2i(Right, local_Projection.Height - Top);
      glVertex2i(Right, local_Projection.Height - Bottom);
    end;
  glEnd;
  glDisable(GL_BLEND);

  PopMatrices;

end;


procedure TOGL.TexturedRectangle2D(Rectangle: TRect; R,G,B,A: Single; TextureHandle: GLuint; AngleCCW: TRightAngle);
begin
  PushMatrices;
  SetupFor2D;

  glActiveTextureARB(GL_TEXTURE0_ARB);

  glFrontFace(GL_CW);
  glCullFace(GL_BACK);
  glEnable(GL_CULL_FACE);
  glPolygonMode(GL_FRONT, GL_FILL);
  glDisable(GL_DEPTH_TEST);
  // alpha waarde
  if A = 1 then
    glDisable(GL_BLEND)
  else begin
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_DST_ALPHA);
  end;
  // de texture
  glEnable(GL_TEXTURE_2D);
  glBindTexture(GL_TEXTURE_2D, TextureHandle);
  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE); // de standaard vertex kleur vervangen..
  //
  glBegin(GL_QUADS);
    glColor4f(R, G, B, A);
    with Rectangle do begin
     {glTexCoord2f(0,0);  //90° CCW volgorde: (0,0),(1,0),(1,1),(0,1)}
      case AngleCCW of
        Angle0:   glTexCoord2f(0,0);
        Angle90:  glTexCoord2f(1,0);
        Angle180: glTexCoord2f(1,1);
        Angle270: glTexCoord2f(0,1);
      end;
      glVertex2i(Left,  local_Projection.Height - Bottom);
      {glTexCoord2f(0,1);  //90° CCW volgorde: (0,1),(0,0),(1,0),(1,1)}
      case AngleCCW of
        Angle0:   glTexCoord2f(0,1);
        Angle90:  glTexCoord2f(0,0);
        Angle180: glTexCoord2f(1,0);
        Angle270: glTexCoord2f(1,1);
      end;
      glVertex2i(Left,  local_Projection.Height - Top);
      {glTexCoord2f(1,1);  //90° CCW volgorde: (1,1),(0,1),(0,0),(1,0)}
      case AngleCCW of
        Angle0:   glTexCoord2f(1,1);
        Angle90:  glTexCoord2f(0,1);
        Angle180: glTexCoord2f(0,0);
        Angle270: glTexCoord2f(1,0);
      end;
      glVertex2i(Right, local_Projection.Height - Top);
      {glTexCoord2f(1,0);  //90° CCW volgorde: (1,0),(1,1),(0,1),(0,0)}
      case AngleCCW of
        Angle0:   glTexCoord2f(1,0);
        Angle90:  glTexCoord2f(1,1);
        Angle180: glTexCoord2f(0,1);
        Angle270: glTexCoord2f(0,0);
      end;
      glVertex2i(Right, local_Projection.Height - Bottom);
    end;
  glEnd;
  glDisable(GL_BLEND);

  PopMatrices;
end;


procedure TOGL.Point2D(ScrPx_X, ScrPx_Y: integer; R,G,B,A: Single; PointSize: single);
var noAlpha: boolean;
begin
  PushMatrices;
  SetupFor2D;

  glActiveTextureARB(GL_TEXTURE0_ARB);

  glDisable(GL_TEXTURE_2D);
  glDisable(GL_LIGHTING);
  glDisable(GL_DEPTH_TEST);
  // alpha waarde
  noAlpha := (A = 1);
  if noAlpha then
    glDisable(GL_BLEND)
  else begin
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
//    glBlendFunc(GL_ZERO, GL_ONE);
  end;
  //
  glPointSize(PointSize);
  glBegin(GL_POINTS);
    glColor4f(R, G, B, A);
    glVertex2i(ScrPx_X,  local_Projection.Height - ScrPx_Y);
  glEnd;

  PopMatrices;
end;

procedure TOGL.Line2D(ScrP1, ScrP2: TPoint; R, G, B, A, LineWidth: single);
var noAlpha: boolean;
begin
  PushMatrices;
  SetupFor2D;

  glActiveTextureARB(GL_TEXTURE0_ARB);

  glDisable(GL_TEXTURE_2D);
  glDisable(GL_LIGHTING);
  glDisable(GL_DEPTH_TEST);
  // alpha waarde
  noAlpha := (A = 1);
  if noAlpha then
    glDisable(GL_BLEND)
  else begin
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
//    glBlendFunc(GL_ZERO, GL_ONE);
  end;
  //
  glLineWidth(LineWidth);
  glBegin(GL_LINES);
    glColor4f(R, G, B, A);
    glVertex2i(ScrP1.X,  local_Projection.Height - ScrP1.Y);
    glVertex2i(ScrP2.X,  local_Projection.Height - ScrP2.Y);
  glEnd;

  PopMatrices;
end;







(*
initialization
  OGL := TOGL.Create;

finalization
  //OGL.Disable;
  OGL.Free;
*)

end.
