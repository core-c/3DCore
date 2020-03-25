unit uLight;
interface
uses OpenGL, u3DTypes, uCamera;

type TGLcolor = array[0..3] of GLfloat;
     TPosition = array[0..3] of GLfloat;

const
  SpotCutOff_Disabled = 180.0;

  ltFixed = 1;          // Een licht dat stil hangt op een vaste positie tov. de 3D-wereld
  ltFloating = 2;       // een licht dat beweegt als een model
  ltSpot = 4;           // een spotlicht

  DefaultLightAmbient : TGLcolor  = (0.2, 0.2, 0.2, 1.0);
  DefaultLightDiffuse : TGLcolor  = (1.0, 1.0, 1.0, 1.0);
  DefaultLightSpecular : TGLcolor = (1.0, 1.0, 1.0, 1.0);
  DefaultLightPosition : TVector = (X:0.0; Y:0.0; Z:0.0);  //in Eye-coordinates..(dus relatief vanaf het camera-oogpunt)

type
  TLight = record
             Enabled: boolean; // Dit licht in- of uitgeschakeld
             //licht type
             LightType: Byte;
             //positie
             Position: TVector;
             Rotation: TVector;
             //kleur
             Ambient,
             Diffuse,
             Specular: TGLcolor;
             Attenuation: GLfloat;  //verloop in helderheid GL_CONSTANT_ATTENUATION
             //spotlicht eigenschappen
             SpotDirection: TVector;
             SpotCutOff,
             SpotExponent: GLfloat; //verloop van de hotspot (hoe hoger de waarde, hoe meer hotspot)
           end;

  TLights = class(TObject)
            private
              Light: array of TLight;
              Enabled: boolean;  //lighting in- of uitgeschakeld
            public
              // object
              constructor Create;
              destructor Destroy; override;
              //
              procedure Clear;
              procedure Default(Index: integer);
              function Len : integer;
              procedure Add(aLight: TLight); overload;
              procedure Add(aPosition: TVector; Color: TGLcolor); overload;   //stationary
              procedure Add(aPosition: TVector; AmbientColor, DiffuseColor, SpecularColor: TGLcolor); overload;  //stationary
              //
              procedure SetAsSpot(Index: integer; Direction: TVector; CutOff, Exponent: GLfloat);
              procedure SetAsNoSpot(Index: integer);
              procedure SetAsFixed(Index: integer);
              procedure SetAsFloating(Index: integer);
              function IsSpot(Index: integer) : boolean;
              function IsFixed(Index: integer) : boolean;
              function IsFloating(Index: integer) : boolean;
              //
              procedure AlignToCamera(Index: integer; var Camera: TCamera);
              function GetRotation(Index: integer) : TVector;
              procedure Rotate(Index: integer; R: TVector);
              function GetPosition(Index: integer) : TVector;
              procedure Translate(Index: integer; T: TVector);
              //
              procedure LightsOn;
              procedure LightsOff;
              procedure LightOn(Index: integer);
              procedure LightOff(Index: integer);
              function IsOn(Index: integer) : boolean;
              //
              procedure DoLighting;
              procedure DisplayFixed;
              procedure DisplayFloating;
            end;

var Lights : TLights;


implementation
uses uCalc;

{ TLight }
constructor TLights.Create;
begin
  // Object initiëren
  inherited;
  // Data initialiseren
  Clear;
end;

destructor TLights.Destroy;
begin
  // Data finaliseren
  Clear;
  // Object finaliseren
  inherited;
end;

procedure TLights.Clear;
begin
  Enabled := false;
  SetLength(Light, 0);
end;

function TLights.Len: integer;
begin
  Result := Length(Light);
end;



procedure TLights.Add(aLight: TLight);
var L: integer;
begin
  L := Length(Light);
  if L<8 then SetLength(Light, L+1);
  //valideren
  with aLight do begin
    if not ((LightType and (ltFixed or ltFloating))>0) then LightType := ltFixed;
    if ((SpotCutOff<>180) and (SpotExponent<>0) and ((SpotDirection.X<>0) or (SpotDirection.Y<>0) or (SpotDirection.Z<>0))) then
      LightType := LightType or ltSpot;
    if (Attenuation=0) then Attenuation := 1.0;
    Enabled := true;
  end;
  Light[L] := aLight;
end;

procedure TLights.Add(aPosition: TVector; Color: TGLcolor);
var L: integer;
begin
  L := Length(Light);
  if L<8 then SetLength(Light, L+1);
  //
  Default(L);
  with Light[L] do begin
    Position := aPosition;
    Ambient[0] := Color[0] / 10.0;
    Ambient[1] := Color[1] / 10.0;
    Ambient[2] := Color[2] / 10.0;
    Ambient[3] := Color[3];
    Diffuse := Color;
    Specular := Color;
    Enabled := true;
  end;
end;

procedure TLights.Add(aPosition: TVector; AmbientColor, DiffuseColor, SpecularColor: TGLcolor);
var L: integer;
begin
  L := Length(Light);
  if L<8 then SetLength(Light, L+1);
  //
  Default(L);
  with Light[L] do begin
    Position := aPosition;
    Ambient := AmbientColor;
    Diffuse := DiffuseColor;
    Specular := SpecularColor;
    Enabled := true;
  end;
end;

function TLights.IsSpot(Index: integer): boolean;
begin
  if (Index>=0) and (Index<Len) then
    Result := ((Light[Index].LightType and ltSpot)>0)
  else Result := false;
end;

function TLights.IsFixed(Index: integer): boolean;
begin
  if (Index>=0) and (Index<Len) then
    Result := ((Light[Index].LightType and ltFixed)>0)
  else Result := false;
end;

function TLights.IsFloating(Index: integer): boolean;
begin
  if (Index>=0) and (Index<Len) then
    Result := ((Light[Index].LightType and ltFloating)>0)
  else Result := false;
end;

function TLights.IsOn(Index: integer): boolean;
begin
  if (Index>=0) and (Index<Len) then
    Result := Light[Index].Enabled
  else Result := false;
end;







procedure TLights.Default(Index: integer);
begin
  with Light[Index] do begin
    LightType := ltFixed;
    Ambient := DefaultLightAmbient;
    Diffuse := DefaultLightDiffuse;
    Specular := DefaultLightSpecular;
    Position := DefaultLightPosition;
    Rotation := NullVector;
    Attenuation := 1.0;
    SpotDirection := NullVector;
    SpotCutOff := SpotCutOff_Disabled;  //graden  ([0..90], 180=uitgeschakeld)
    SpotExponent := 0.0;  //geen hotspot
  end;
end;

procedure TLights.SetAsFixed(Index: integer);
begin
  if (Index>=0) and (Index<Len) then
    with Light[Index] do
      LightType := ((LightType and ltSpot) or ltFixed);
end;

procedure TLights.SetAsFloating(Index: integer);
begin
  if (Index>=0) and (Index<Len) then
    with Light[Index] do
      LightType := ((LightType and ltSpot) or ltFloating);
end;

procedure TLights.SetAsSpot(Index: integer; Direction: TVector; CutOff, Exponent: GLfloat);
begin
  if not ((Index>=0) and (Index<Len)) then Exit;
  if (CutOff<>180) then
    with Light[Index] do begin
      LightType := LightType or ltSpot;
      SpotCutOff := CutOff;
      SpotExponent := Exponent;
      SpotDirection := Direction;
    end;
end;

procedure TLights.SetAsNoSpot(Index: integer);
begin
  if not ((Index>=0) and (Index<Len)) then Exit;
  with Light[Index] do begin
    LightType := LightType and (ltFixed or ltFloating);
    SpotCutOff := 180.0;
    SpotDirection := NullVector;
    SpotExponent := 0.0;
  end;
end;





procedure TLights.AlignToCamera(Index: integer; var Camera: TCamera);
begin
  if not ((Index>=0) and (Index<Len)) then Exit;
  // licht-posities zijn in oog-coördinaten..
  // dwz. relatief vanaf het camera-oogpunt.
  Light[Index].Position := Camera.Position;
  // Als dit een spotlicht is, dan ook de Camera.LineOfSight overnemen naar de Spot.Direction
  // Zo wordt het Camera.LookAt target altijd belicht.
  if IsSpot(Index) then Light[Index].SpotDirection := UnitVector(Camera.LineOfSight);
end;

function TLights.GetRotation(Index: integer): TVector;
begin
  Result := Light[Index].Rotation;
end;

procedure TLights.Rotate(Index: integer; R: TVector);
begin
  Light[Index].Rotation := R;
end;

function TLights.GetPosition(Index: integer): TVector;
begin
  Result := Light[Index].Position;
end;

procedure TLights.Translate(Index: integer; T: TVector);
begin
  Light[Index].Position := AddVector(Light[Index].Position, T);
end;





procedure TLights.LightsOff;
begin
  Enabled := false;
  glDisable(GL_LIGHTING);
end;

procedure TLights.LightsOn;
begin
  Enabled := true;
  glEnable(GL_LIGHTING);
end;

procedure TLights.LightOff(Index: integer);
begin
  glEnable(GL_LIGHT0+Index);
  Light[Index].Enabled := false;
end;

procedure TLights.LightOn(Index: integer);
begin
  glDisable(GL_LIGHT0+Index);
  Light[Index].Enabled := true;
end;

procedure TLights.DoLighting;
var i: integer;
    P: TPosition;
begin
  //belichting initialiseren..
  glLightModeli(GL_LIGHT_MODEL_TWO_SIDE, ord(GL_FALSE));
  glLightModeli(GL_LIGHT_MODEL_LOCAL_VIEWER, ord(GL_FALSE));
  for i:=0 to Len-1 do
    with Light[i] do begin
      P[0] := Position.X;
      P[1] := Position.Y;
      P[2] := Position.Z;
      P[3] := 1.0;
      //positie en kleur
      glLightfv(GL_LIGHT0+i, GL_POSITION, @P);   //nodig in init?..
      glLightfv(GL_LIGHT0+i, GL_AMBIENT, @Ambient);
      glLightfv(GL_LIGHT0+i, GL_DIFFUSE, @Diffuse);
      glLightfv(GL_LIGHT0+i, GL_SPECULAR, @Specular);
      //helderheid fall-off
      glLightf(GL_LIGHT0+i, GL_CONSTANT_ATTENUATION, Attenuation);
      //spotlichten
      if IsSpot(i) then begin
        glLightf(GL_LIGHT0+i, GL_SPOT_CUTOFF, SpotCutOff);
        glLightfv(GL_LIGHT0+i, GL_SPOT_DIRECTION, @SpotDirection);
        glLightf(GL_LIGHT0+i, GL_SPOT_EXPONENT, SpotExponent);
      end else
        glLightf(GL_LIGHT0+i, GL_SPOT_CUTOFF, SpotCutOff_Disabled);
      //licht aan/uit
      if Enabled then glEnable(GL_LIGHT0+i) else glDisable(GL_LIGHT0+i);
    end;
  //belichting aan?
  if Enabled then glEnable(GL_LIGHTING) else glDisable(GL_LIGHTING);
end;

procedure TLights.DisplayFixed;
var i: integer;
begin
  //alle stationaire lichten "afbeelden"
  for i:=0 to Len-1 do
    with Light[i] do
      if Enabled and IsFixed(i) then
        glLightfv(GL_LIGHT0+i, GL_POSITION, @Position);
end;

procedure TLights.DisplayFloating;
var i: integer;
begin
  //alle bewegende lichten "afbeelden"
  for i:=0 to Len-1 do
    with Light[i] do
      if Enabled and IsFloating(i) then 
        glLightfv(GL_LIGHT0+i, GL_POSITION, @Position);
end;


initialization
  Lights := TLights.Create;

finalization
  Lights.Free;


end.
