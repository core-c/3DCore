unit uGame;
interface
uses u3DTypes, OpenGL, mmsystem;

//--- de shooter ---------------------------------------------------------------
type
  // een hulplijn "schieten"
  TShooter = record
    VStart, VEnd: TVector;               // het begin- & eind-punt van de hulplijn
  end;

procedure DisplayShooter;
procedure Shoot(Position,Direction: TVector);

var
  Shooter: TShooter;


//--- de crosshair -------------------------------------------------------------
procedure DisplayCrosshair;


//--- het radar ----------------------------------------------------------------
var
  Radar_TextureHandle,
  RadarMask_TextureHandle: GLuint;

procedure DisplayRadar;


//--- OpenGL -------------------------------------------------------------------
procedure glBindTexture(target: GLenum; texture: GLuint); stdcall; external 'opengl32.dll';



implementation
uses uCalc, uQuake3BSP{, FormOpenGL}, Types, uCamera, uPlayer, uParticles, uOpenGL;


//--- de shooter ---------------------------------------------------------------
procedure DisplayShooter;
begin
  // de shooter lijn tekenen..
  glBegin(GL_LINES);
    glColor3f(1.0, 0.6, 0.0);
    with Shooter.VStart do glVertex3f(X, Y, Z);
    with Shooter.VEnd do glVertex3f(X, Y, Z);
  glEnd;
end;


procedure Shoot(Position,Direction: TVector);
var NewPosition, P: TVector; //CollisionTest : TCollisionTest;
    V, PlaneNormal: TVector;
    PlaneDistance: single;
begin
  // Een geluidje voor de fun..!!!!!DEBUG!!!!!
  SndPlaySound(PChar('sounds\shooter.wav'), SND_ASYNC or SND_FILENAME);
  //
  V := ScaleVector(Direction, 1);
  NewPosition := AddVector(Position, V);
  //
  if Quake3BSP.IsMapLoaded then begin // collision test in BSP

    // een lijn schieten..tot aan de eerste brush die de lijn raakt.
    P := NewPosition;
    while not Quake3BSP.Collision(P) do begin
      P := AddVector(P, V);
      // NewPosition buiten frustum? dan stoppen met de shooter..
      if VectorLength(SubVector(P, Position)) > 5000 then break;
    end;
//    NewPosition := P;                 // net nadat de botsing heeft plaatsgevonden
    NewPosition := SubVector(P, V);   // net voordat de botsing zal plaatsvinden

    // een lijn raytracen..zodat het geraakte vlak bekend is,
    // dus tracen van (New)Position -> P
    NewPosition := Quake3BSP.TraceRay(NewPosition, P);
    if Quake3BSP.CollisionTest.Colliding then begin
      PlaneNormal := Quake3BSP.CollisionTest.VCollisionNormal;
      PlaneDistance := Quake3BSP.CollisionTest.VCollisionPlaneDistance;
    end;

    // Een stel vonken afbeelden
    Sparks.Start(P, Direction, PlaneNormal,PlaneDistance, 13, 300, 1500, true);     //1500 milliseconde lang 13 vonken met snelheid 300, met een staartje..

  end else begin // geen collision test..
    // een lijn schieten..tot aan de frustum boundry
    while (VectorLength(SubVector(NewPosition, Position)) < 5000) do
      NewPosition := AddVector(NewPosition, V);
  end;
  // de berekende lijn gegevens bewaren, voor gebruik in displaymap()
  Shooter.VStart := Position;
  Shooter.VEnd := NewPosition;
end;




//--- de crosshair -------------------------------------------------------------
procedure DisplayCrosshair;
const InnerSize=4; OuterSize=10;
var W,H: integer;
    C: TPoint;
begin
  with {fOpenGL.}OGL do begin
    W := Width;
    H := Height;
    C := Center;
    // instellen om 2D te tekenen
    SetupFor2D;
  end;
  // teken de crosshair
  glDisable(GL_LIGHTING);
  glDisable(GL_TEXTURE_2D);
  glDisable(GL_BLEND);
  glBegin(GL_LINES);
    glColor4f(1.0,1.0,0.0, 1.0);
    // boven
    glVertex2i(C.X, C.Y+OuterSize);
    glVertex2i(C.X, C.Y+InnerSize);
    // onder
    glVertex2i(C.X, C.Y-InnerSize);
    glVertex2i(C.X, C.Y-OuterSize);
    // links
    glVertex2i(C.X-OuterSize, C.Y);
    glVertex2i(C.X-InnerSize, C.Y);
    // rechts
    glVertex2i(C.X+InnerSize, C.Y);
    glVertex2i(C.X+OuterSize, C.Y);
  glEnd;
end;




//--- het radar ----------------------------------------------------------------
procedure DisplayRadar;
const MarginTop=10;  MarginRight=10;  IndicatorLength=8;
var X,Y: integer;
    V: TVector;
begin
  if Radar_TextureHandle = 0 then Exit;
  // 2D tekenen..
  {fOpenGL.}OGL.SetupFor2D;
  X := {fOpenGL.}OGL.Width-96-MarginRight;
  Y := {fOpenGL.}OGL.Height-96-MarginTop;

  glScissor(X, Y, 96, 96);
  glEnable(GL_SCISSOR_TEST);

  glFrontFace(GL_CCW);
  {glCullFace(GL_FRONT);}
  glDisable(GL_CULL_FACE);
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_LIGHTING);
  glEnable(GL_BLEND);
  glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR);  //one,one
  glEnable(GL_TEXTURE_2D);
  glBindTexture(GL_TEXTURE_2D, Radar_TextureHandle);
  glBegin(GL_QUADS);
    glTexCoord2f(0,0);  glVertex2f(X,Y+96);
    glTexCoord2f(0,1);  glVertex2f(X,Y);
    glTexCoord2f(1,1);  glVertex2f(X+96,Y);
    glTexCoord2f(1,0);  glVertex2f(X+96,Y+96);
  glEnd;

  glDisable(GL_BLEND);
  glDisable(GL_TEXTURE_2D);
  // rest nog de camera/player-positie & -richting markeren..
  // De player staat relatief gezien altijd in het midden van het radarbeeld.
  // Een punt zetten in het midden van het radarbeeld..
  glPointSize(3);
  X := X + 48;
  Y := Y + 48;
  glBegin(GL_POINTS);
    glColor3f(1.0, 1.0, 0.0);
    glVertex2f(X, Y);
  glEnd;
  // Een lijntje tekenen in de richting waarin de camera kijkt
  // De negatieve Z-as wijst in de richting van het noorden op het radar.
  V := Player.Camera.LineOfSight;
  glBegin(GL_LINES);
    glVertex2f(X, Y);
    glVertex2f(X+(V.X*IndicatorLength), Y-(V.Z*IndicatorLength));
  glEnd;
  //
  glDisable(GL_SCISSOR_TEST);

(*
  // het radar staat in de rechter-bovenhoek van het scherm.
  // Het radar-masker is 96x96 pixels.
  // Scissor de rehterbovenhoek van het scherm..
  X := fOpenGL.OGL.Width-96  -100;
  Y := fOpenGL.OGL.Height    -100;
  glClearStencil(0);
  glEnable(GL_STENCIL_TEST);
  // het masker tekenen
  glClear(GL_STENCIL_BUFFER_BIT);
  glStencilFunc(GL_ALWAYS, 1, 1);
  glStencilOp(GL_REPLACE, GL_REPLACE, GL_REPLACE);
  // teken de circel vorm van het masker
  glFrontFace(GL_CW);
  glBegin(GL_TRIANGLES);
    glColor3f(0.0, 0.0, 0.0);
    glVertex2f(X+0,Y+0);
    glVertex2f(X+100,Y+100);
    glVertex2f(X+100,Y+0);
  glEnd;
  // teken het radar
  glStencilFunc(GL_NOTEQUAL, 1, 1);
  glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
  glBegin(GL_QUADS);
    glColor4f(1.0,1.0,1.0,1.0);
    glVertex2f(X+0,Y+0);
    glVertex2f(X+0,Y+300);
    glVertex2f(X+300,Y+300);
    glVertex2f(X+300,Y+0);
  glEnd;
  //
  glDisable(GL_STENCIL_TEST);
*)
end;

end.
