unit uDisplay;
interface
uses OpenGL, uCalc, u3DModel, uLight, uSkyBox, uMap;




procedure DrawFrame;
procedure CheckSpecialKeys;



implementation
uses windows, u3DTypes, uFont, SysUtils, Classes, uCamera, uQuake3BSP, uGame, uPlayer, uParticles, uTerrain, uOpenGL, FormOpenGL;



procedure DrawFrame;
var s: string;
    i: integer;
    vsyncOn: boolean;
begin
  // RenderContext actief maken..
  {wglMakeCurrent(fOpenGL.OGL.DC, fOpenGL.OGL.RC);}

  glEnable(GL_DEPTH_TEST);

  //--- scherm wissen ----------------------------------------------------------
  if OGL.SkyBox.Active and (not OGL.SkyBox.Paused) then
    glClear(GL_DEPTH_BUFFER_BIT)
  else
    glClear(GL_COLOR_BUFFER_BIT OR GL_DEPTH_BUFFER_BIT);

  glLoadIdentity;

  //--- tov de map bewegende lichten -------------------------------------------
  glPushMatrix;
    Lights.DisplayFloating;
  glPopMatrix;

  //--- camera plaatsen --------------------------------------------------------
  with Player.Camera do gluLookAt(Position.X,Position.Y,Position.Z, Target.X,Target.Y,Target.Z, UpY.X,UpY.Y,UpY.Z);
  // de frustum clipping-planes berekenen 
  OGL.Frustum.Calculate_glFrustumPlanes;

  //--- tov de map stationaire lichten -----------------------------------------
  glPushMatrix;
    Lights.DisplayFixed;
  glPopMatrix;

  //--- map --------------------------------------------------------------------
  glPushMatrix;
    // De Quake3 BSP afbeelden vanaf het camera-oogpunt
    Quake3BSP.DisplayMap(Player.Camera.Position);
    // De .map file
    LevelMap.DisplayMap(Player.Camera.Position);
  glPopMatrix;

  //--- model(len) -------------------------------------------------------------
  glPushMatrix;
    // positioneren..

    //
    Obj3DModel.DisplayModel;
  glPopMatrix;

  //--- Terrain ----------------------------------------------------------------
  Terrain.DisplayTerrain(Player.Camera.Position);

  //--- Game stuff -------------------------------------------------------------
  DisplayShooter;

  //=== Particles tekenen ======================================================
  Sparks.Render(Player.Camera.LineOfSight);

  //--- de achtergrond ---------------------------------------------------------
  OGL.SkyBox.Render(Player.Camera);

  //=== vanaf nu 2D tekenen ====================================================
  LensFlare.Render(Vector(150000000.0,140000000.0,-250000000.0), Player.Camera.Position, Player.Camera.LineOfSight);

  DisplayCrosshair;
  DisplayRadar;


(*
  fOpenGL.OGL.SetupFor2D;
  if fOpenGL.HelpText.Count > 0 then
    fOpenGL.OGL.AlphaRectangle2D(Rect(0,0,150,186), 0.5,0.5,0.5,0.5);
*)
  //--- de teksten -------------------------------------------------------------
  OGL.PrintLine(0, '', laTop, 1,1,1); //DUMMY!!!!!DEBUG!!!!!
  //
  if fOpenGL.HelpText.Count > 0 then begin
    // Help afbeelden ipv. enig andere tekst
    for i:=0 to fOpenGL.HelpText.Count-1 do
      OGL.PrintLine(i, fOpenGL.HelpText.Strings[i], laTop, 0.85,0.8,0.8);
    //
  end else begin
    {glPushMatrix;}
    // 3D (dus in de virtuele wereld op de aangeduide positie)
    {OGL.Fonts.PrintTextXYZ('Keigoed', 0.0, 300.0, 0.0);}  //3d

    // 2D
    //bovenaan
    s := BoolToStr(Player.Grounded, true);
    OGL.PrintLine(0, 'Grounded: '+ s, laTop, 1.0,0.7,0.1);  //255 180 30
    with fOpenGL do begin
      s := 'FPS: '+ IntToStr(OGL.GetFPS {FPS});
      if OGL.GetVSync(vsyncOn) then
        if vsyncOn then s := s +' VSync';
      s := s +' @ '+ IntToStr(OGL.MonitorRefreshRate {VerticalRefreshRate}) +'Hz';
      s := s +'  '+ IntToStr(OGL.Width) +'x'+ IntToStr(OGL.Height);
      s := s +'   FrameTime: '+ FloatToStrF(OGL.GetLastFrameTime {GetFrameTime}, ffFixed, 6,5);
      OGL.PrintLine(1, s, laTop, 0.8,0.8,0.9);
    end;
    with Player.Camera.Position do begin
      s := FloatToStrF(X, ffFixed, 6,0);
      s := s +','+ FloatToStrF(Y, ffFixed, 6,0);
      s := s +','+ FloatToStrF(Z, ffFixed, 6,0);
      s := 'Position XYZ['+ s + ']';
      OGL.PrintLine(2, s, laTop, 1.0,1.0,0.5);
    end;
    with Player.Camera.Target do begin
      s := FloatToStrF(X, ffFixed, 6,0);
      s := s +','+ FloatToStrF(Y, ffFixed, 6,4);
      s := s +','+ FloatToStrF(Z, ffFixed, 6,4);
      s := 'Target XYZ['+ s + ']';
      OGL.PrintLine(3, s, laTop, 1.0,1.0,0.5);
    end;
    //onderaan
    if LevelMap.IsMapLoaded then begin
      s := 'MAP-Faces drawn/total: '+ IntToStr(LevelMap.GetNFacesDrawn) +'/'+ IntToStr(LevelMap.GetNFaces);
      OGL.PrintLine(0, s, laBottom, 0.6,0.6,0.6);
    end else
    if Quake3BSP.IsMapLoaded then begin
      s := 'BSP-Faces drawn/total: '+ IntToStr(Quake3BSP.GetNFacesDrawn) +'/'+ IntToStr(Quake3BSP.GetNFaces);
      OGL.PrintLine(1, s, laBottom, 0.6,0.8,0.8);
      s := 'BSP Current leaf-node index: '+ IntToStr(Quake3BSP.GetCurrentLeafNode);
      OGL.PrintLine(0, s, laBottom, 0.6,0.8,0.9);
    end;
    //
    {glPopMatrix;}
  end;


  // Frame afhandelen ----------------------------------------------------------
  glFlush;
  // buffers wisselen
  OGL.DoBufferSwap;

  //FPS meting
  OGL.MeasureFPS;
end;





procedure CheckSpecialKeys;
// Test de status van bepaalde toetsen (ingedrukt/uitgedrukt).
// De toetsen voor besturing in de 3D-wereld gaan nl. repeteren als ze even worden
// ingehouden. Besturing gaat dan niet zoals gewenst.
// Toetsen die niets met de besturing te maken hebben (bv. toggle-toetsen) worden
// in de procedure niet getest omdat het niet van belang is of deze repeteren.
// GetKeyState levert een byte terug waarvan het hoogste bit aangeeft of een toets
// is ingedrukt of uitgedrukt op het moment van aanroep van GetKeyState.
// Als bit 7 is gezet dan is de toets ingedrukt, anders uitgedrukt.
// Bit 0 geeft aan of er een toets-toggle is voorgevallen.
// !NB: hoofdletters gebruiken bij testen van toetsen (indien van toepassing)
//
// Bewegings-snelheid in-game is ook bepaald door het behaalde aantal FPS.
// Om geen verschillen per computer te verkrijgen, wordt een factor berekend die
// afhankelijk is van de laatste FrameTime om een constante snelheid voor de camera
// te verkrijgen. Stel: iemand met een framerate van 2 FPS heeft een FrameTime van
// een halve seconde; Deze persoon gaat in 2 stappen 250 units verder.
// Iemand met een framerate van 10 FPS gaat in 10 stappen ook 250 units vooruit.
var speed: Single;
    NewPosition: TVector;
    KeyPress, MovedByGravity: boolean;
begin
//  if not (Quake3BSP.IsMapLoaded or LevelMap.IsMapLoaded) then Exit;

  // de snelheid berekenen relatief aan de laatste frametime
  speed := {fOpenGL.GetFrameTime} OGL.GetLastFrameTime * Player.Camera.Speed;
  if speed = 0 then speed := Player.Camera.Speed/100;

  // toetsenstatus testen.. met C's (ray-)collision detection, en quake's AABB cd.
  if Player.Camera.GetCollide then begin // moet de camera botsen met brushes?..

    NewPosition := Player.Camera.Position;

    // natuurlijke bewegingen..(vallen, zwaartekracht, springen etc)
    MovedByGravity := false;
    if not Player.Camera.Floating then
      NewPosition := Player.HandleMovement(NewPosition, MovedByGravity);

    // bewegingen optellen..
    KeyPress := false;
    // Vooruit
    if (GetKeyState(Ord('W')) and $80)<>0 then begin
      NewPosition := Player.Camera.NextMove_Position(NewPosition, speed);
      KeyPress := true;
    end;
    // Achteruit
    if (GetKeyState(Ord('S')) and $80)<>0 then begin
      NewPosition := Player.Camera.NextMove_Position(NewPosition, -speed);
      KeyPress := true;
    end;
    // Links
    if (GetKeyState(Ord('A')) and $80)<>0 then begin
      NewPosition := Player.Camera.NextStrafe_Position(NewPosition, speed);
      KeyPress := true;
    end;
    // Rechts
    if (GetKeyState(Ord('D')) and $80)<>0 then begin
      NewPosition := Player.Camera.NextStrafe_Position(NewPosition, -speed);
      KeyPress := true;
    end;
    // Springen
    if (GetKeyState(Ord(' ')) and $80)<>0 then begin
      Player.Jump;
      KeyPress := true;
    end;
    // Kruipen
    if (GetKeyState(VK_CONTROL) and $80)<>0 then begin
      // zorgen dat het model gaat bukken..(dat het wordt afgebeeld iig)..
      KeyPress := true;
    end;

    // ..en 1 keer tracen
    // als er een toets is gedrukt, of als de zwaartekracht nog werkt..
    if KeyPress or MovedByGravity then begin
      {NewPosition := Quake3BSP.TraceSphere(Player.Camera.Position, NewPosition, Player.Camera.SphereRadius);}
      NewPosition := Quake3BSP.TraceBox(Player.Camera.Position, NewPosition, Player.Camera.BoundingBox[bbMin], Player.Camera.BoundingBox[bbMax]);
      Player.Camera.SetPosition(NewPosition);
      Player.Grounded := Quake3BSP.CollisionTest.Grounded;
    end;

  end else begin
    //geen botsingen..
    if (GetKeyState(Ord('W')) and $80)<>0 then Player.Camera.Move(speed);
    if (GetKeyState(Ord('S')) and $80)<>0 then Player.Camera.Move(-speed);
    if (GetKeyState(Ord('A')) and $80)<>0 then Player.Camera.Strafe(speed);
    if (GetKeyState(Ord('D')) and $80)<>0 then Player.Camera.Strafe(-speed);
  end;

end;




end.
