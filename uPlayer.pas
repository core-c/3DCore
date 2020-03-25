unit uPlayer;
interface
uses u3DTypes, uCalc, uCamera, uQuake3BSP;

const
  // standaard zwaartekracht op een speler
  DefaultGravity = 9.81;
  // standaard bewegings-snelheid van een speler
  DefaultPlayerMaxSpeed = 300.0;
  // de standaard opstap-hoogte (bij trappen ed..)
  // Dit is de maximale afstand die een speler nog kan opstappen zonder te springen).
  DefaultMaxStepHeight = 10.0;
  // springen
  DefaultJumpAcceleration = 3.0;


  // BoundingBox
  bbMin     = 0;
  bbMax     = 1;
  bbExtends = 2;
  // De standaard boudingbox afmetingen. Voor een rechtop staand model
  // (Een camera zal geprojecteerd worden op punt(0,0,0) van de boundingbox)
  DefaultBoundingBoxMax : TVector = (X:12;  Y:8;   Z:12;);
  DefaultBoundingBoxMin : TVector = (X:-12; Y:-56; Z:-12;);
  // De standaard boudingbox afmetingen. Voor een kruipend model
  DefaultBoundingBoxMax_Crouch : TVector = (X:12;  Y:8;   Z:12;);
  DefaultBoundingBoxMin_Crouch : TVector = (X:-12; Y:-24; Z:-12;);


type
  TPlayer = class(TObject)
  private
  public
    Camera: TCamera;
    // zwaartekracht
    Gravity: Single;
    // bewegingsrichting (geen unitvector)
    Movement: TVector;
    //
    Grounded: boolean;
    //
    constructor Create;
    destructor Destroy; override;
    //
    procedure Jump;                           // springen
    procedure Crouch(Value: boolean);         // bukken/kruipen
    function HandleMovement(FromPosition: TVector; var MovedByGravity: boolean) : TVector;
  end;

var Player: TPlayer;



implementation
uses {FormOpenGL} uOpenGL;

{ TPlayer }
constructor TPlayer.Create;
begin
  Camera := TCamera.Create;
  Camera.SetSpeed(DefaultPlayerMaxSpeed);
  Camera.BoundingBox[bbMin] := DefaultBoundingBoxMin;  //staand model
  Camera.BoundingBox[bbMax] := DefaultBoundingBoxMax;  //staand model
  Camera.SetCollide(false);
  Camera.Floating := true;
  //
  Gravity := DefaultGravity;
  Movement := NullVector; {Vector(0,-1,0);}
  Grounded := false;
  //
  Quake3BSP.CollisionTest.Camera := @Camera;
  Quake3BSP.CollisionTest.MaxStepHeight := DefaultMaxStepHeight;
end;

destructor TPlayer.Destroy;
begin
  Camera.Free;
  Camera := nil;
  //
  inherited;
end;



procedure TPlayer.Jump;
begin
  // alleen springen als de speler op de grond staat..
  if not Grounded then Exit;
  // de huidige beweging + jump
  Movement := AddVector(Camera.LineOfSight, Vector(0,DefaultJumpAcceleration,0));
  {Movement := Vector(0,DefaultJumpAcceleration,0);}
end;

procedure TPlayer.Crouch(Value: boolean);
begin
  if Value then begin //bukken?..
    Camera.BoundingBox[bbMin] := DefaultBoundingBoxMin_Crouch;  //staand model
    Camera.BoundingBox[bbMax] := DefaultBoundingBoxMax_Crouch;  //kruipend model
  end else begin      //of weer rechtop staan?..
    // Als de speler rechtop gaat staan na het kruipen, moet de
    // camera eerst 32 units omhoog geplaatst worden (vooralsnog).
    // Anders verdwijnt de onderste helft van de boundingbox in de vloer
    // en zakt het model omlaag..
    Camera.SetPosition(AddVector(Camera.Position, Vector(0,32,0)));
    Camera.BoundingBox[bbMin] := DefaultBoundingBoxMin;         //staand model
    Camera.BoundingBox[bbMax] := DefaultBoundingBoxMax;         //
  end;
end;



function TPlayer.HandleMovement(FromPosition: TVector; var MovedByGravity: boolean) : TVector;
var grav: single;
begin
  // verwerk bewegingen die niet direct door de user zelf worden geregeld.
  // Dwz. jump, gravity etc..
  // Staat het speler-model NIET op de "grond"?, dan is ie aan het vallen..
  MovedByGravity := (not Grounded);
  if not Grounded then begin
    grav := {fOpenGL.GetFrameTime} OGL.GetLastFrameTime * Gravity;
    Movement.Y := Movement.Y - grav;
    Result := AddVector(FromPosition, Movement);
  end else begin
    Movement := NullVector;
    Result := FromPosition;
  end;
end;









initialization
  Player := TPlayer.Create;

finalization
  Player.Free;


end.
