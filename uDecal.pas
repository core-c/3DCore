unit uDecal;
interface
uses OpenGL, u3DTypes, uCalc;

const MAX_DECALS    = 20;
      DECAL_SIZE    = 48;     //48x48 pixels
      DECAL_TIMEOUT = 30000;  //30 seconden

type
  // Een face waarop decals worden afgebeeld, heeft een (gevulde) array van TDecalRec's.
  TDecalRec = record
    // de texture-handle van de decal
    TextureID: GLuint;
    // de 3D-positie van de decal op het vlak/face (inslag-positie van de kogel bv.)
    Origin: TVector;
    // de 4 (3D)hoekpunten van de (decal)texture
    Quad: array[0..3] of TVector;
    // De timestamp van het tijdstip voor wissen van deze decal
    TimeOfDeath: Int64;
  end;



  TObjDecals = class(TObject)
  private
    Active: boolean;    // decals afbeelden??
    // de array met alle decals
    Decal: array of TDecalRec;
    N_Decals: Integer;  // overall aantal decals
  public
    // object
    constructor Create;
    destructor Destroy; override;
    // een nieuwe decal berekenen en toevoegen aan de wereld
    // resulteer de index in de array Decal.
    function Add_BulletHit(DecalOrigin, PlaneNormal, LineOfSight: TVector) : Integer;
    procedure KillDecal(DecalIndex: Integer);
    // teken Decal[Index], en check de TimeOfDeletion
    procedure Render(DecalIndex: Integer);
  end;


var Decals : TObjDecals;




implementation
uses Windows;

constructor TObjDecals.Create;
begin
  Active := false;  //zolang even uit..
  N_Decals := 0;
  SetLength(Decal, 0);
end;

destructor TObjDecals.Destroy;
begin
  SetLength(Decal, 0);
  //
  inherited;
end;

function TObjDecals.Add_BulletHit(DecalOrigin, PlaneNormal, LineOfSight: TVector): Integer;
var Vx,Vy: TVector;
    Freq,T: Int64;
    TPms: Single;
begin
  Result := -1;
  if N_Decals >= MAX_DECALS then Exit;

  // een element toevoegen aan de array Decal
  Inc(N_Decals);
  SetLength(Decal, N_Decals);
  Result := N_Decals-1;

  // een projectie van de decal, evenwijdig aan de normaal, op de face
  // (zou eigenlijk evenwijdig aan de LineOfSight moeten zijn..)
  Vx := ScaleVector(UnitVector(CrossProduct(Vector(0,1,0), PlaneNormal)), DECAL_SIZE);
  // de lijn loodrecht op Vx en lineofsight..
  Vy := ScaleVector(UnitVector(CrossProduct(Vx, PlaneNormal)), DECAL_SIZE);
  // de 4 punten van de (decal)face
  with Decal[Result] do begin
    Quad[0] := AddVector(AddVector(DecalOrigin, InverseVector(Vx)), InverseVector(Vy));
    Quad[1] := AddVector(AddVector(DecalOrigin, Vx), InverseVector(Vy));
    Quad[2] := AddVector(AddVector(DecalOrigin, Vx), Vy);
    Quad[3] := AddVector(AddVector(DecalOrigin, InverseVector(Vx)), Vy);
    //
    Origin := DecalOrigin;
    // de actuele tijd-teller ophalen, en verhogen met de decal-timeout
    QueryPerformanceFrequency(Freq);
    TPms := Freq/1000;  // het aantal ticks per milliseconde
    QueryPerformanceCounter(TimeOfDeath);
    TimeOfDeath := TimeOfDeath + Round(DECAL_TIMEOUT * TPms);
    // kies een texture uit voor de BulletHit
    TextureID := 1; //zolang maar even een willekeurige texture {!!!!!DEBUG!!!!!}
  end;
end;

procedure TObjDecals.KillDecal(DecalIndex: Integer);
begin
  // wis het element[DecalIndex] uit de array Decal..
  // (verwissel het element met het laatste element uit de array, en maak de array 1 element korter)
  Decal[DecalIndex] := Decal[N_Decals-1];
  Dec(N_Decals);
  SetLength(Decal, N_Decals);
end;


procedure TObjDecals.Render(DecalIndex: Integer);
var Freq, T: Int64;
begin
  // De OpenGL programming guide geeft 2 methoden voor het afbeelden van decals

  //--- methode 1:
  // depth buffer test inschakelen
  // depth buffer writing uitschakelen
  // teken de face
  // depth buffer writing inschakelen
  // teken de decal
  // color buffer writing uitschakelen
  // teken de face
  // color buffer writing aanzetten

  //--- methode 2:
  // stencil-buffer instellen om:
  //   een 1 te schrijven, als de depth-test "passes", en een 0 schrijven in de andere gevallen
  // teken de face
  // stencil-buffer instellen om:
  //   geen veranderingen maken aan de stencil waarden, maar alleen tekenen als de stencil-waarde == 1
  // de depth-buffer-test uitschakelen (en de updates ervan)
  // teken de decal
  // herstel stencil- & depth-buffer instellingen


  // controleer of de decal nog zichtbaar is, en zonodig verwijderen
  QueryPerformanceCounter(T);
  if T > Decal[DecalIndex].TimeOfDeath then KillDecal(DecalIndex);
end;






initialization
  Decals := TObjDecals.Create;

finalization
  Decals.Free;

end.
