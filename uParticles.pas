unit uParticles;
interface
uses OpenGL, u3DTypes, uCalc{, FormOpenGL};

const
  MaxSparks      = 20;      // max. 20 vonken tegelijkertijd
  SparkSize      = 7;       // textures zijn zoveel punten groot in beeld
  MaxSparksTrail = 10;      // iedere vonk heeft zoveel vonken in zijn staart
  RotateTex      = false;   // textures roteren?

type
  TRGBA = record
    R,G,B,A: single;
  end;

const
  wit   : TRGBA = (R:1.0; G:1.0; B:1.0; A:1.0;);
  zwart : TRGBA = (R:0.0; G:0.0; B:0.0; A:1.0;);
  startKleur  : TRGBA = (R:1.0; G:1.0; B:0.0; A:1.0;);
  eindKleur   : TRGBA = (R:0.6; G:0.0; B:0.0; A:1.0;);

type
  TSparkRec = record
    Position,
    Direction: TVector;                 // unitvector
    Color, ColorDelta : TRGBA;          // de kleur (Rood Groen Blauw Alpha)
    Size, SizeDelta,                    // de huidige grootte van de vonken (en delta)
    Speed,                              // de snelheid van de vonken
    Gravity: single;                    // de zwaartekracht op de vonken (zodat ze vallen in een boog)
    Alive: boolean;                     // deze particle nog levend?
    StartTime, TimeOfDeath: Int64;      // queryperformancecounter-tijd van dood vonk
  end;

  TMainSparkRec = record
    MainSpark: TSparkRec;
    TailLength: integer;
    SparkTrail: array[0..MaxSparksTrail-1] of TSparkRec;
  end;

  TSpark = class(TObject)
  private
    Position,
    Direction: TVector;
    Speed,
    MaxAngle: Single;                   // de maximale hoek verschil op Direction van de vonken in het bereik[0..180]
    N_Sparks: integer;                  // Het aantal vonken tegelijkertijd zichtbaar
    TimeOfDeath: Int64;                 // Het tijdstip waarop de vonken stoppen..
    Trail: boolean;                     // een spark trail produceren?
    //
    {Sparks: array of TSparkRec;}
    Sparks: array of TMainSparkRec;
    procedure RenderSpark(var Spark: TSparkRec; LineOfSight: TVector);
  public
    // object
    constructor Create;
    destructor Destroy; override;
    // start een vonken effect..vanaf aPosition,
    //                          in richting aDirection,
    //                          (evt) de normaal van het geraakte vlak
    //                          het aantal vonken
    //                          de snelheid van de vonken
    //                          de tijdsduur waarover de vonken zichtbaar zijn
    //                          een "komeetstaart" aan de vonken?
    procedure Start(aPosition,aDirection, PlaneNormal: TVector; PlaneDistance: Single; NumberOfSparks: integer; aSpeed: Single; aDurationMS: Integer; aTrail: boolean);
    //
    procedure KillSpark(i: integer);
    procedure KillSparks;
    procedure Render(LineOfSight: TVector);
  end;






  TLensFlare = class(TObject)
  private
    local_Active: boolean;
  public
    Flare_TextureHandle: array[0..3] of GLuint;  // 4 textures tbv. de lens-flare
    // object
    constructor Create;
    destructor Destroy; override;
    //
    procedure ToggleFlare;
    procedure Render(SunPosition, CameraPosition, LineOfSight: TVector);
  end;



Var
  Spark_TextureHandle: GLuint;
  Sparks: TSpark;
  LensFlare: TLensFlare;


implementation
uses Math, Windows, uQuake3BSP, uPlayer, uTexture, uOpenGL;



{ TSpark }
constructor TSpark.Create;
begin
  SetLength(Sparks, 0);
  Trail := false;
end;

destructor TSpark.Destroy;
begin
  SetLength(Sparks, 0);
  //
  inherited;
end;






procedure TSpark.Start(aPosition, aDirection, PlaneNormal: TVector; PlaneDistance: Single; NumberOfSparks: integer; aSpeed: Single; aDurationMS: Integer; aTrail: boolean);
var i: integer;
    Freq, STime, ETime, duration: Int64;
    TPms, distance: single;
    V: TVector;
    ColDelta: TRGBA;
begin
  Position := aPosition;
  Direction := aDirection;
  Trail := aTrail;
  QueryPerformanceFrequency(Freq);
  QueryPerformanceCounter(STime);
  TPms := Freq/1000;  // het aantal ticks per milliseconde

  // alle vonken dezelfde duration
//  duration := Round(aDurationMS * TPms);
//  TimeOfDeath := STime + duration;

  // niet meer dan het maximum aantal vonken laten produceren..
  N_Sparks := Min(NumberOfSparks, MaxSparks);
  SetLength(Sparks, N_Sparks);  //de dynamische array alloceren..
  // vonk begin-posities vastleggen..
  for i:=0 to Length(Sparks)-1 do begin
    duration := Random(Round(aDurationMS * TPms));

    Sparks[i].MainSpark.Position := aPosition;

    V := RandomizeVector(ReflectVectorOnPlane(aDirection, PlaneNormal), 30); // 30 graden willekeurige richting
    Sparks[i].MainSpark.Direction := V;

    Sparks[i].MainSpark.Size := Random(SparkSize);
    Sparks[i].MainSpark.SizeDelta := Sparks[i].MainSpark.Size / duration;
    Sparks[i].MainSpark.Speed := Random(Round(aSpeed*1000))/1000;
    Sparks[i].MainSpark.Alive := true;
    Sparks[i].MainSpark.StartTime := STime;

//    Sparks[i].MainSpark.TimeOfDeath := TimeOfDeath;
    Sparks[i].MainSpark.TimeOfDeath := STime + duration;

    Sparks[i].MainSpark.Gravity := 0;
    Sparks[i].MainSpark.Color := startKleur;
    // de kleur delta's voor RGB per performanceCounter-tick
    Sparks[i].MainSpark.ColorDelta.A := 0.0; //alpha niet aanpassen..
    Sparks[i].MainSpark.ColorDelta.R := (eindKleur.R - startKleur.R) / duration;
    Sparks[i].MainSpark.ColorDelta.G := (eindKleur.G - startKleur.G) / duration;
    Sparks[i].MainSpark.ColorDelta.B := (eindKleur.B - startKleur.B) / duration;
    Sparks[i].TailLength := 0;
  end;
end;

procedure TSpark.KillSpark(i: integer);
begin
  Sparks[i].MainSpark.Alive := false;
end;

procedure TSpark.KillSparks;
begin
  // "gewoon" alle vonken wissen..
  SetLength(Sparks, 0);
end;




procedure TSpark.RenderSpark(var Spark: TSparkRec; LineOfSight: TVector);
var V1,V2,V3,V4: TVector;
begin
  with Spark do begin
    // is er een texture?..
    if Spark_TextureHandle <> 0 then begin

      // Een billboard, altijd loodrecht op de LineOfSight van de camera..
      BillBoard(Position,LineOfSight,Size,V1,V2,V3,V4);

      if RotateTex then begin //textures rondraaien?
        glMatrixMode(GL_TEXTURE);
        glPushMatrix;
        glLoadIdentity();
        glRotatef(random(360), 0, 0, 1);
        glMatrixMode(GL_MODELVIEW);
      end;
      glDisable(GL_CULL_FACE);
      glEnable(GL_TEXTURE_2D);
      glBindTexture(GL_TEXTURE_2D, Spark_TextureHandle);
      //blending en fog... dan zie ik dat het mixen anders gaat dan verwacht..:|
      glEnable(GL_BLEND);
      glBlendFunc(GL_SRC_COLOR, GL_DST_ALPHA {GL_ONE}); //GL_SRC_COLOR, GL_DST_ALPHA
      glBegin(GL_QUADS);
        glColor3f(Color.R, Color.G, Color.B);
        {glNormal3f(Direction.X, Direction.Y, Direction.Z);}
        glTexCoord2D(0,0);
        glVertex3f(V1.X, V1.Y, V1.Z);
        glTexCoord2D(1,0);
        glVertex3f(V2.X, V2.Y, V2.Z);
        glTexCoord2D(1,1);
        glVertex3f(V3.X, V3.Y, V3.Z);
        glTexCoord2D(0,1);
        glVertex3f(V4.X, V4.Y, V4.Z); //glVertex3f(Position.X-Size, Position.Y+Size, Position.Z);
      glEnd;
      if RotateTex then begin //textures rondraaien?
        glMatrixMode(GL_TEXTURE);
        glPopMatrix;
        glMatrixMode(GL_MODELVIEW);
      end;

    end else begin // er is geen texture..
      glDisable(GL_TEXTURE_2D);
      glDisable(GL_BLEND);
      glPointSize(2.0);
      glBegin(GL_POINTS);
        glColor3f(Color.R, Color.G, Color.B);
        glVertex3f(Position.X, Position.Y, Position.Z);
      glEnd;
    end;
  end;
end;

procedure TSpark.Render(LineOfSight: TVector);
var i, j: integer;
    T: Int64;
    speed_, grav, perc : single;
    OldPosition, NewPosition, V: TVector;
begin
  // zijn er welvonken om af te beelden?
  if Length(Sparks) = 0 then Exit;
  grav := {fOpenGL.GetFrameTime} OGL.GetLastFrameTime * 9.81;
  // de actuele tijd-teller ophalen
  QueryPerformanceCounter(T);

  glPushMatrix;
  //
  glDisable(GL_LIGHTING);
  glDepthMask(GL_FALSE);  //niet in de z-buffer schrijven, wel lezen..
  // alle vonken doorlopen en afbeelden als ze nog leven..
  for i:=0 to Length(Sparks)-1 do begin
    with Sparks[i].MainSpark do begin
      // nog levend die vonk?
      if Alive and (T < TimeOfDeath) then begin
        OldPosition := Position; //even bewaren voor de raytrace..
        //
        speed_ := {fOpenGL.GetFrameTime} OGL.GetLastFrameTime * Speed;
        // met een snelheid in een richting afschieten die vonken
        V := ScaleVector(UnitVector(Direction), speed_);
        NewPosition := AddVector(OldPosition, V);
        // omlaag laten vallen die vonken..
        NewPosition.Y := NewPosition.Y - Gravity;
        Gravity := Gravity + grav;

        // een lijn raytracen..zodat het geraakte vlak bekend is
        NewPosition := Quake3BSP.TraceRay(OldPosition, NewPosition);
        if Quake3BSP.CollisionTest.Colliding then begin
          Direction := ReflectVectorOnPlane(Direction, Quake3BSP.CollisionTest.VCollisionNormal);
          //beetje foppen die zwaartekracht..
          if Quake3BSP.CollisionTest.VCollisionNormal.Y > 0.8 then
            Gravity := -Gravity*0.7;
        end;

        Position := NewPosition;

        // afbeelden..
        RenderSpark(Sparks[i].MainSpark, LineOfSight);

        // kleuren veranderen..
        perc := TimeOfDeath-T;
        Color.R := eindKleur.R - perc*ColorDelta.R;  if Color.R<0 then Color.R:=0;
        Color.G := eindKleur.G - perc*ColorDelta.G;  if Color.G<0 then Color.G:=0;
        Color.B := eindKleur.B - perc*ColorDelta.B;  if Color.B<0 then Color.B:=0;
        //grootte veranderen..
        Size := perc*SizeDelta;  if Size<0 then Size:=0;

        // de spark-trail
        if Trail then begin
          // trail lengte met 1 verhogen..
          Inc(Sparks[i].TailLength); if Sparks[i].TailLength > MaxSparksTrail then Sparks[i].TailLength := MaxSparksTrail;
          // trail-array aanpassen..
          for j:=Sparks[i].TailLength-1 downto 1 do begin
            Sparks[i].SparkTrail[j] := Sparks[i].SparkTrail[j-1];
            with Sparks[i].SparkTrail[j] do begin
              // kleur van het spoor aanpassen..
              Color.R := eindKleur.R - (perc / j)*ColorDelta.R;  if Color.R<0 then Color.R:=0;
              Color.G := eindKleur.G - (perc / j)*ColorDelta.G;  if Color.G<0 then Color.G:=0;
              Color.B := eindKleur.B - (perc / j)*ColorDelta.B;  if Color.B<0 then Color.B:=0;
             {//grootte veranderen..
             Size := Size - (perc / j)*SizeDelta;  if Size<0 then Size:=0;}
            end;
          end;
          Sparks[i].SparkTrail[0] :=  Sparks[i].MainSpark;
          // afbeelden..
          for j:=0 to Sparks[i].TailLength-1 do
            RenderSpark(Sparks[i].SparkTrail[j] , LineOfSight);
        end;

      end else begin
        KillSpark(i);
        //break;
      end;
    end;
  end;
  glDepthMask(GL_TRUE);
  glPopMatrix;
end;








{ TLensFlare }
constructor TLensFlare.Create;
begin
  local_Active := true;
end;

destructor TLensFlare.Destroy;
begin
  //
  inherited;
end;

procedure TLensFlare.ToggleFlare;
begin
  local_Active := not local_Active;
end;

procedure TLensFlare.Render(SunPosition, CameraPosition, LineOfSight: TVector);
var M, P: array[0..15] of glDouble;        // modelview- & projection-matrix
    V: array[0..3] of glInt;
    SunX,SunY,SunZ: glDouble;
    V1,V2,V3,V4, SunPos2D, Dir, Pos, NewPosition: TVector;
    Xminus,Xplus, Yminus,Yplus: Single;
    TheSize, Size, DirLen: Single;
    ShowFlare: boolean;
begin
  if not local_Active then Exit;
  if Flare_TextureHandle[0] <= 0 then Exit;
  glPushMatrix;
  // de 2D scherm-coordinaten van de zon berekenen
  glGetDoublev(GL_MODELVIEW_MATRIX, @M);
  glGetDoublev(GL_PROJECTION_MATRIX, @P);
  glGetIntegerv(GL_VIEWPORT, @V);
  //
  with Player.Camera.Position do glTranslatef(X, Y, Z);

  //is de zon zichtbaar (voor de camera)??
  if DotProduct(InverseVector(LineOfSight), SunPosition) - VectorLength(CameraPosition) <= 0 then begin
(*
    // de lens-flare verbergen als de zon wordt bedekt door een vlak in de bsp
    ShowFlare := true;
    if Quake3BSP.IsMapLoaded then begin // collision test in BSP
      ShowFlare := false;
      // een lijn schieten..tot aan de eerste brush die de lijn raakt.
      NewPosition := CameraPosition;
      while not Quake3BSP.Collision(NewPosition) do begin
        NewPosition := AddVector(NewPosition, LineOfSight);
        // NewPosition buiten frustum? dan stoppen met de shooter..
        if VectorLength(SubVector(NewPosition, CameraPosition)) > 5000 then begin
          ShowFlare := true;
          break;
        end;
      end;
    end;

    if ShowFlare then
*)
      if gluProject(SunPosition.X, SunPosition.Y, SunPosition.Z,
                    @M, @P, @V,
                    SunX, SunY, SunZ) > 0 then begin

        SunPos2D := Vector(SunX,SunY,0);
        // de lijn Sun-CenterScreen
        Dir := Vector({fOpenGL.}OGL.Center.X-SunX, {fOpenGL.}OGL.Center.Y-SunY, 0);
        // de grootte van de zon-texture is relatief aan de grootte van de viewport
        TheSize := Sqrt(Sqr(OGL.Width/3) + Sqr(OGL.Height/3));

        // plat tekenen
        {fOpenGL.}OGL.SetupFor2D;

        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);
        glEnable(GL_TEXTURE_2D);
        //blending en fog... dan zie ik dat het mixen anders gaat dan verwacht..:|
        glEnable(GL_BLEND);
        glBlendFunc(GL_COLOR, GL_ONE_MINUS_SRC_ALPHA);

        // De eerste flare
        // de 2D-positie van de texture(s)
        Pos := SunPos2D;
        Size := TheSize/2;
        Xminus := Pos.X-Size;
        Xplus := Pos.X+Size;
        Yminus := Pos.Y-Size;
        Yplus := Pos.Y+Size;
        V1 := Vector(Xminus,Yplus,0);
        V2 := Vector(Xplus,Yplus,0);
        V3 := Vector(Xplus,Yminus,0);
        V4 := Vector(Xminus,Yminus,0);
        glBindTexture(GL_TEXTURE_2D, Flare_TextureHandle[0]);
        glBegin(GL_QUADS);
          glColor3f(1,1,1);
          //glNormal3f(InverseVector(LineOfSight).X, InverseVector(LineOfSight).Y, InverseVector(LineOfSight).Z);
          glTexCoord2D(0,0);
          glVertex2f(V1.X, V1.Y); //glVertex3f(Position.X-Size, Position.Y-Size, Position.Z);
          glTexCoord2D(1,0);
          glVertex2f(V2.X, V2.Y); //glVertex3f(Position.X+Size, Position.Y-Size, Position.Z);
          glTexCoord2D(1,1);
          glVertex2f(V3.X, V3.Y); //glVertex3f(Position.X+Size, Position.Y+Size, Position.Z);
          glTexCoord2D(0,1);
          glVertex2f(V4.X, V4.Y); //glVertex3f(Position.X-Size, Position.Y+Size, Position.Z);
        glEnd;

        // de zon in beeld (binnen viewport)??
        if (SunX >= V[0]) and (SunX <= V[2]) and (SunY >= V[1]) and (SunY <= V[3]) then begin

          // de 1e halo
          Pos := AddVector(SunPos2D, ScaleVector(Dir, 0.7));
          Size := TheSize*0.5/4;
          Xminus := Pos.X-Size;
          Xplus := Pos.X+Size;
          Yminus := Pos.Y-Size;
          Yplus := Pos.Y+Size;
          V1 := Vector(Xminus,Yplus,0);
          V2 := Vector(Xplus,Yplus,0);
          V3 := Vector(Xplus,Yminus,0);
          V4 := Vector(Xminus,Yminus,0);
          glBindTexture(GL_TEXTURE_2D, Flare_TextureHandle[1]);
          glBegin(GL_QUADS);
            glColor3f(1,1,1);
            //glNormal3f(InverseVector(LineOfSight).X, InverseVector(LineOfSight).Y, InverseVector(LineOfSight).Z);
            glTexCoord2D(0,0);
            glVertex2f(V1.X, V1.Y); //glVertex3f(Position.X-Size, Position.Y-Size, Position.Z);
            glTexCoord2D(1,0);
            glVertex2f(V2.X, V2.Y); //glVertex3f(Position.X+Size, Position.Y-Size, Position.Z);
            glTexCoord2D(1,1);
            glVertex2f(V3.X, V3.Y); //glVertex3f(Position.X+Size, Position.Y+Size, Position.Z);
            glTexCoord2D(0,1);
            glVertex2f(V4.X, V4.Y); //glVertex3f(Position.X-Size, Position.Y+Size, Position.Z);
          glEnd;

          // de 1e burst
          Pos := AddVector(SunPos2D, ScaleVector(Dir, 0.33));
          Size := TheSize*0.25/4;
          Xminus := Pos.X-Size;
          Xplus := Pos.X+Size;
          Yminus := Pos.Y-Size;
          Yplus := Pos.Y+Size;
          V1 := Vector(Xminus,Yplus,0);
          V2 := Vector(Xplus,Yplus,0);
          V3 := Vector(Xplus,Yminus,0);
          V4 := Vector(Xminus,Yminus,0);
          glBindTexture(GL_TEXTURE_2D, Flare_TextureHandle[2]);
          glBegin(GL_QUADS);
            glColor3f(1,1,1);
            //glNormal3f(InverseVector(LineOfSight).X, InverseVector(LineOfSight).Y, InverseVector(LineOfSight).Z);
            glTexCoord2D(0,0);
            glVertex2f(V1.X, V1.Y); //glVertex3f(Position.X-Size, Position.Y-Size, Position.Z);
            glTexCoord2D(1,0);
            glVertex2f(V2.X, V2.Y); //glVertex3f(Position.X+Size, Position.Y-Size, Position.Z);
            glTexCoord2D(1,1);
            glVertex2f(V3.X, V3.Y); //glVertex3f(Position.X+Size, Position.Y+Size, Position.Z);
            glTexCoord2D(0,1);
            glVertex2f(V4.X, V4.Y); //glVertex3f(Position.X-Size, Position.Y+Size, Position.Z);
          glEnd;

          // de 2e halo
          Pos := AddVector(SunPos2D, ScaleVector(Dir, 0.125));
          Size := TheSize/4;
          Xminus := Pos.X-Size;
          Xplus := Pos.X+Size;
          Yminus := Pos.Y-Size;
          Yplus := Pos.Y+Size;
          V1 := Vector(Xminus,Yplus,0);
          V2 := Vector(Xplus,Yplus,0);
          V3 := Vector(Xplus,Yminus,0);
          V4 := Vector(Xminus,Yminus,0);
          glBindTexture(GL_TEXTURE_2D, Flare_TextureHandle[1]);
          glBegin(GL_QUADS);
            glColor3f(1,1,1);
            //glNormal3f(InverseVector(LineOfSight).X, InverseVector(LineOfSight).Y, InverseVector(LineOfSight).Z);
            glTexCoord2D(0,0);
            glVertex2f(V1.X, V1.Y); //glVertex3f(Position.X-Size, Position.Y-Size, Position.Z);
            glTexCoord2D(1,0);
            glVertex2f(V2.X, V2.Y); //glVertex3f(Position.X+Size, Position.Y-Size, Position.Z);
            glTexCoord2D(1,1);
            glVertex2f(V3.X, V3.Y); //glVertex3f(Position.X+Size, Position.Y+Size, Position.Z);
            glTexCoord2D(0,1);
            glVertex2f(V4.X, V4.Y); //glVertex3f(Position.X-Size, Position.Y+Size, Position.Z);
          glEnd;

          // de 2e burst
          Pos := AddVector(SunPos2D, ScaleVector(Dir, 1.5));
          Size := TheSize*0.5/4;
          Xminus := Pos.X-Size;
          Xplus := Pos.X+Size;
          Yminus := Pos.Y-Size;
          Yplus := Pos.Y+Size;
          V1 := Vector(Xminus,Yplus,0);
          V2 := Vector(Xplus,Yplus,0);
          V3 := Vector(Xplus,Yminus,0);
          V4 := Vector(Xminus,Yminus,0);
          glBindTexture(GL_TEXTURE_2D, Flare_TextureHandle[2]);
          glBegin(GL_QUADS);
            glColor3f(1,1,1);
            //glNormal3f(InverseVector(LineOfSight).X, InverseVector(LineOfSight).Y, InverseVector(LineOfSight).Z);
            glTexCoord2D(0,0);
            glVertex2f(V1.X, V1.Y); //glVertex3f(Position.X-Size, Position.Y-Size, Position.Z);
            glTexCoord2D(1,0);
            glVertex2f(V2.X, V2.Y); //glVertex3f(Position.X+Size, Position.Y-Size, Position.Z);
            glTexCoord2D(1,1);
            glVertex2f(V3.X, V3.Y); //glVertex3f(Position.X+Size, Position.Y+Size, Position.Z);
            glTexCoord2D(0,1);
            glVertex2f(V4.X, V4.Y); //glVertex3f(Position.X-Size, Position.Y+Size, Position.Z);
          glEnd;

          // de 3e halo
          Pos := AddVector(SunPos2D, ScaleVector(Dir, 1.1));
          Size := TheSize*0.25/4;
          Xminus := Pos.X-Size;
          Xplus := Pos.X+Size;
          Yminus := Pos.Y-Size;
          Yplus := Pos.Y+Size;
          V1 := Vector(Xminus,Yplus,0);
          V2 := Vector(Xplus,Yplus,0);
          V3 := Vector(Xplus,Yminus,0);
          V4 := Vector(Xminus,Yminus,0);
          glBindTexture(GL_TEXTURE_2D, Flare_TextureHandle[1]);
          glBegin(GL_QUADS);
            glColor3f(1,1,1);
            //glNormal3f(InverseVector(LineOfSight).X, InverseVector(LineOfSight).Y, InverseVector(LineOfSight).Z);
            glTexCoord2D(0,0);
            glVertex2f(V1.X, V1.Y); //glVertex3f(Position.X-Size, Position.Y-Size, Position.Z);
            glTexCoord2D(1,0);
            glVertex2f(V2.X, V2.Y); //glVertex3f(Position.X+Size, Position.Y-Size, Position.Z);
            glTexCoord2D(1,1);
            glVertex2f(V3.X, V3.Y); //glVertex3f(Position.X+Size, Position.Y+Size, Position.Z);
            glTexCoord2D(0,1);
            glVertex2f(V4.X, V4.Y); //glVertex3f(Position.X-Size, Position.Y+Size, Position.Z);
          glEnd;

          // de 3e burst
          Pos := AddVector(SunPos2D, ScaleVector(Dir, 1.2));
          Size := TheSize*0.2/4;
          Xminus := Pos.X-Size;
          Xplus := Pos.X+Size;
          Yminus := Pos.Y-Size;
          Yplus := Pos.Y+Size;
          V1 := Vector(Xminus,Yplus,0);
          V2 := Vector(Xplus,Yplus,0);
          V3 := Vector(Xplus,Yminus,0);
          V4 := Vector(Xminus,Yminus,0);
          glBindTexture(GL_TEXTURE_2D, Flare_TextureHandle[3]);
          glBegin(GL_QUADS);
            glColor3f(1,1,1);
            //glNormal3f(InverseVector(LineOfSight).X, InverseVector(LineOfSight).Y, InverseVector(LineOfSight).Z);
            glTexCoord2D(0,0);
            glVertex2f(V1.X, V1.Y); //glVertex3f(Position.X-Size, Position.Y-Size, Position.Z);
            glTexCoord2D(1,0);
            glVertex2f(V2.X, V2.Y); //glVertex3f(Position.X+Size, Position.Y-Size, Position.Z);
            glTexCoord2D(1,1);
            glVertex2f(V3.X, V3.Y); //glVertex3f(Position.X+Size, Position.Y+Size, Position.Z);
            glTexCoord2D(0,1);
            glVertex2f(V4.X, V4.Y); //glVertex3f(Position.X-Size, Position.Y+Size, Position.Z);
          glEnd;
        end;
      end;
  end;
  glPopMatrix;
end;




initialization
  Sparks := TSpark.Create;
  LensFlare := TLensFlare.Create;

finalization
  Sparks.Free;
  LensFlare.Free;

end.
