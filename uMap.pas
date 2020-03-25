// Een (level-editor) .MAP file inlezen in mijn MAP-object. ("mapversion" "220")
//
// Alle informatie is opgeslagen in blokken tussen "{" en "}" tekens (op aparte regels).
// Elke informatie-blok bevat als eerste info de classname van de opgeslagen informatie.
// De "classname" "worldspawn" blok bevat alle brushes met texturenamen/normalen ed.
// Elke brush binnen de "worldspawn"-blok is weer apart gemarkeerd; Tussen "{" & "}".
// Een voorbeeld van 2 brush definities:
//   {
//   ( 720 1136 -128 ) ( 752 1136 -128 ) ( 752 1168 -128 ) AAATRIGGER [ 1 0 0 0 ] [ 0 -1 0 -16 ] 0 1 1
//   ( 752 1136 -64 ) ( 720 1136 -64 ) ( 720 1168 -64 ) AAATRIGGER [ 1 0 0 0 ] [ 0 -1 0 -16 ] 0 1 1
//   ( 752 1136 -128 ) ( 720 1136 -128 ) ( 720 1136 -64 ) AAATRIGGER [ 1 0 0 0 ] [ 0 0 -1 -32 ] 0 1 1
//   ( 752 1168 -128 ) ( 752 1136 -128 ) ( 752 1136 -64 ) AAATRIGGER [ 0 1 0 16 ] [ 0 0 -1 -32 ] 0 1 1
//   ( 720 1168 -128 ) ( 752 1168 -128 ) ( 752 1168 -64 ) AAATRIGGER [ 1 0 0 0 ] [ 0 0 -1 -32 ] 0 1 1
//   ( 720 1136 -128 ) ( 720 1168 -128 ) ( 720 1168 -64 ) AAATRIGGER [ 0 1 0 16 ] [ 0 0 -1 -32 ] 0 1 1
//   }
//   {
//   ( 132 629 -109 ) ( 132 629 -48 ) ( 138 629 -48 ) COMMON/0_CLIP [ 6.12303e-017 0 -1 0 ] [ -1 0 -6.12303e-017 -30 ] 90 1 -1.2
//   ( 132 633 -48 ) ( 132 633 -109 ) ( 138 633 -109 ) COMMON/0_CLIP [ 6.12303e-017 0 -1 0 ] [ -1 0 -6.12303e-017 -30 ] 90 1 -1.2
//   ( 132 629 -48 ) ( 132 629 -109 ) ( 132 633 -109 ) COMMON/0_CLIP [ 0 6.12303e-017 -1 0 ] [ 0 -1 -6.12303e-017 5 ] 90 1 1.2
//   ( 138 629 -48 ) ( 132 629 -48 ) ( 132 633 -48 ) COMMON/0_CLIP [ -1 -1.22461e-016 0 29 ] [ -1.22461e-016 1 0 5 ] 180 1 -1.2
//   ( 138 633 -48 ) ( 138 633 -109 ) ( 138 629 -109 ) COMMON/0_CLIP [ 0 6.12303e-017 -1 0 ] [ 0 -1 -6.12303e-017 5 ] 90 1 1.2
//   ( 138 633 -109 ) ( 132 633 -109 ) ( 132 629 -109 ) COMMON/0_CLIP [ -1 -1.22461e-016 0 29 ] [ -1.22461e-016 1 0 5 ] 180 1 -1.2
//   }
// De eerste 3 vectoren (tussen "(" & ")" tekens) bevatten de punten van een triangle (CCW).
// Daarna volgt de naam van de gebruikte texture (zonder extensie).
// Tussen de 1e stel brackets "[" & "]": texture-coord-axis [ U.x U.y U.z shift[0] ]
// Tussen de 2e stel brackets: [ V.x V.y V.z shift[1] ]
// De laatste 3 cijfers op een regel bevatten: texture.rotate, texture.scale[0] & texture.scale[1]
//
// Vanwege variaties in .MAP file-formats tussen (bv) HalfLife- & Wolfenstein- .MAPs,
// hier enige uitleg:
//
//  HalfLife brush-regel:
//   ( 720 1136 -128 ) ( 720 1168 -128 ) ( 720 1168 -64 ) AAATRIGGER [ 0 1 0 16 ] [ 0 0 -1 -32 ] 0 1 1
//   ( V1(x,y,z) ) ( V2(x,y,z) ) ( V3(x,y,z) ) texture [ U-as-normaal(x,y,z) U-shift ] [ V-as-normaal(x,y,z) V-shift ] Rotatie U-scale V-scale
//
//  Quake3 (Wolfenstein) brush-regel:
//   ( 1008 -80 128 ) ( 1008 -80 144 ) ( 704 -80 144 ) tobruk_wall_sd/tobruk_wall_base1 0.000000 0.000000 0.000000 0.500000 0.500000 134217728 0 0
//   ( V1(x,y,z) ) ( V2(x,y,z) ) ( V3(x,y,z) ) texture normal-x normal-y normal-z U-scale V-scale ??rotatie?? U-shift V-shift
//


unit uMap;
interface
uses OpenGL, u3DTypes, uFrustum, uCalc, StdCtrls, Classes, uTexture{, FormOpenGL}, Unit1;

const
  MaxWorld = 16384;
  MapFormat_Unknown  = '';
  MapFormat_HalfLife = 'HalfLife';
  MapFormat_Quake3   = 'Quake3';

  Classname_info         = '"info_';
  Classname_func         = '"func_';
  Classname_trigger      = '"trigger_';
  Classname_script       = '"script_';
  Classname_misc         = '"misc_';
  Classname_light        = '"light"';
  Classname_lightJunior  = '"lightJunior"';
  Classname_target       = '"target_';
  Classname_corona       = '"corona"';
  Classname_team         = '"team_';

  DontShow : array[0..9] of string = ('common\clip','common\trigger','common\hint','common\skip','common\caulk',
                                      'common/clip','common/trigger','common/hint','common/skip','common/caulk');

type
  TMapVertex = packed record
    Color          : array[0..3] of Single;    // RGBA kleur voor deze vertex
    Normal         : TVector3f;                // (x, y, z) normaal vector
    TextureCoord   : TVector2f;                // (u, v) texture coordinaten
    Position       : TVector3f;                // (x, y, z) positie
  end;

  TMapFace = record
    Normal         : TVector3f;                // De normaal van deze face
    N_Vertices     : Integer;                  // Het aantal vertices van deze face
    startVertIndex : Integer;                  // De start-index van de 1e face-vertex
    TextureIndex   : Integer;                  // De index van de texture in de array Textures
  end;

  TMapPlane = record
    Normal           : TVector3f;
    Distance         : Single;
    P0,P1,P2, Center : TVector;                 // de eerste 3 punten zoals opgegeven in de .MAP file + face-center
    TextureIndex     : Integer;                 // De index van de texture in de array Textures
    TextureAxisU,
    TextureAxisV     : TVector;
    TextureRotation,
    TextureShiftU,
    TextureShiftV    : Single;
    TextureScaleU,
    TextureScaleV    : Single;
  end;

  TMapTexture = record
    Filename      : string;
    TextureWidth,
    TextureHeight : Integer;
    Handle        : GLuint;
  end;

  TLevelMap = class(TObject)
    private
      pMemo: TMemo; //tbv. scherm-uitvoer
      //
      N_Vertices     : Integer;              // Het aantal vertices
      Vertices       : array of TMapVertex;  // Vertices
      N_Faces        : Integer;              // Het aantal faces
      Faces          : array of TMapFace;    // Faces
      N_Textures     : Integer;              // Het aantal textures
      Textures       : array of TMapTexture; // Textures
      //
      MapLoaded : boolean;
      MapFormat: string;
      formatQuake3,
      formatHalfLife: boolean;
      N_FacesDrawn   : Integer;              // Het aantal getekende faces

      //hulpfuncties..
      function SplitString(const s: string; var ToStringList: TStringList) : string;
      function StringToFloatDef(const s: string; DefaultValue: Single) : Single;
      function StringToIntDef(const s: string; DefaultValue: Integer) : Integer;

      procedure CalcUVAxis(aPlane: TMapPlane; P1,P2,P3, Normal: TVector; RotDeg: Single; var AxisU, AxisV: TVector);
      function Vector3iToVector3f(V3i: TVector3i) : TVector;
      function GetVertex(i: integer; const s: string) : TVector3i;     //resulteer punt[i].XYZ uit een regel
      function GetTextureFilename(const s: string) : string;           //resulteer de texture-filename uit een regel

      //-- HalfLife
      function GetTextureAxisU(const s : string) : TVector4f;          //resulteer de texture U-as
      function GetTextureAxisV(const s : string) : TVector4f;          //resulteer de texture V-as
      function GetTextureScaleU(const s: string) : Single;             //resulteer de texture U-scale
      function GetTextureScaleV(const s: string) : Single;             //resulteer de texture V-scale
      //-- Quake3
      function GetTextureScaleU_Q3(const s: string) : Single;          //resulteer de texture U-scale
      function GetTextureScaleV_Q3(const s: string) : Single;          //resulteer de texture V-scale
      function GetTextureShiftU_Q3(const s: string) : Single;          //resulteer de texture U-shift
      function GetTextureShiftV_Q3(const s: string) : Single;          //resulteer de texture V-shift
      function GetTextureRotation_Q3(const s: string) : Single;        //resulteer de texture rotatie

      // texture-coordinaten uitrekenen voor 1 punt (van een vlak met een texture)
      function CalcTextureCoords(var aPlane: TMapPlane; aVertex: TVector; aTextureIndex: Integer) : TVector2f;
      procedure CorrectTextureCoords(startVertexIndex, N_Verts: Integer);
      // texture al opgenomen in de array Textures??  zoja: resulteer het index-nummer, anders -1
      function IsTextureInList(var Filename: string) : Integer;
      // voeg een nieuwe texture toe aan de lijst Textures, en resulteer het index-nummer
      function AddTextureToList(Filename: string; Width,Height: Integer) : Integer;
      //
      procedure ProcessBrush(var SLB: TStringList);
      procedure ProcessClass(var SL: TStringList);
      //
      function validTexture(const Filename: string): boolean;
      procedure InitTextures;
      procedure FreeTextures;
    public
      constructor Create;
      destructor Destroy; override;
      procedure Clear;
      // memo uitvoer
      procedure Set_StdOut(var aMemo: TMemo);
      procedure Clear_StdOut;
      procedure Print_StdOut(s: string);
      //
      function IsMapLoaded : boolean;
      function GetNFaces : integer;
      function GetNFacesDrawn : integer;
      //
      procedure DisplayMap(CameraPosition: TVector);
      //
      function GetMapFormat(const Filename : string) : string;
      function LoadMAP(const Filename : string) : Boolean;
  end;

var LevelMAP : TLevelMap;

implementation
uses StrUtils, SysUtils, Math, uOpenGL;



{ TLevelMap }
constructor TLevelMap.Create;
//var LCID: integer;
begin
  pMemo := nil;
(*
  // omzetten van strings in engelse cijfernotatie naar floats
  LCID :=
  GetLocaleFormatSettings(LCID, fformat);
*)  
  //
  Clear;
end;

destructor TLevelMap.Destroy;
begin
  Clear;
  //
  inherited;
end;

procedure TLevelMap.Clear;
begin
  // alle textures van deze map kunnen weg
  FreeTextures;
  //
  MapLoaded := false;
  formatHalfLife := false;
  formatQuake3 := false;
  MapFormat := '';
  // het hele object legen..
  N_Vertices := 0;
  SetLength(Vertices, 0);
  N_Faces := 0;
  SetLength(Faces, 0);
  N_Textures := 0;
  SetLength(Textures, 0);
  N_FacesDrawn := 0;
end;




{Memo}
procedure TLevelMap.Set_StdOut(var aMemo: TMemo);
begin
  pMemo := aMemo;
end;

procedure TLevelMap.Clear_StdOut;
begin
  if pMemo <> nil then pMemo.lines.Clear
end;

procedure TLevelMap.Print_StdOut(s: string);
begin
  if pMemo <> nil then pMemo.lines.add(s)
end;





function TLevelMap.IsMapLoaded: boolean;
begin
  Result := MapLoaded;
end;

function TLevelMap.GetNFaces: integer;
begin
  Result := Length(Faces);
end;

function TLevelMap.GetNFacesDrawn: integer;
begin
  Result := N_FacesDrawn;
end;



function TLevelMap.Vector3iToVector3f(V3i: TVector3i): TVector;
begin
  Result.X := V3i.X * 1.0;
  Result.Y := V3i.Y * 1.0;
  Result.Z := V3i.Z * 1.0;
end;


function TLevelMap.SplitString(const s: string; var ToStringList: TStringList): string;
const SpaceDelimiter = [' '];
var Len: Integer;
begin
  Len := ExtractStrings( SpaceDelimiter, SpaceDelimiter, pchar(s), ToStringList );
end;

function TLevelMap.StringToFloatDef(const s: string; DefaultValue: Single) : Single;
var code: integer;
    Value: Single;
begin
  Result := DefaultValue;
  try
    Val(s, Value, code);
    if code=0 then Result := Value;
  except
    Exit;
  end;
end;

function TLevelMap.StringToIntDef(const s: string; DefaultValue: Integer) : Integer;
var code: integer;
    Value: Integer;
begin
  Result := DefaultValue;
  try
    Val(s, Value, code);
    if code=0 then Result := Value;
  except
    Exit;
  end;
end;



function TLevelMap.GetVertex(i: integer; const s: string): TVector3i;
  //---
  function GetCoord(var P: integer; const s: string; var CoordValue: Integer) : boolean;
  var P2, Value, Code: integer;
      coord: string;
  begin
    Result := false; //bij voorbaat..
    P2 := PosEx(' ', s, P);
    if P2=0 then Exit; //fout opgetreden..
    coord := MidStr(s, P, P2-P);
    Val(coord, Value, Code);
    if Code<>0 then Exit;
    CoordValue := Value {*1.0}; //integers laten tot na de vertex-index optimalisatie..
    P := P2+1;
    Result := true; //gelukt
  end;
  //---
var P, Temp: integer;
    V: TVector3i;
begin
  Result.X := 0;  Result.Y := 0;  Result.Z := 0;  //NullVector;
  // ( 720 1136 -128 ) ( 752 1136 -128 ) ( 752 1168 -128 ) AAATRIGGER [ 1 0 0 0 ] [ 0 -1 0 -16 ] 0 1 1
  // Na de eerste "(" volgt een spatie, en voor elke ")" staat ook een spatie;
  // Daartussen staan de coördinaten, ook weer gescheiden door spaties.
  // Zet eerst P op de positie in string(s) van het [i]'de stel coördinaten..
  P := 0;
  while i>0 do begin
    P := PosEx('(', s, P+1);
    if P=0 then Exit; //fout opgetreden..
    Dec(i);
  end;
  Inc(P, 2);
  // P bevat nu de positie (in s) van de te lezen X-coördinaat (van vertex[i])
  // X-coördinaat
  if not GetCoord(P,s, V.X) then Exit;
  // Y-coördinaat
  if not GetCoord(P,s, V.Y) then Exit;
  // Z-coördinaat
  if not GetCoord(P,s, V.Z) then Exit;
(*
  // as-coördinaten aanpassen naar OpenGL formaat
  Temp := V.Y;
  V.Y := V.Z;
  V.Z := -Temp;
*)
  //
  {Print_StdOut('Vertex: '+ IntToStr(V.X) +','+ IntToStr(V.Y) +','+ IntToStr(V.Z));}
  Result := V;
end;


function TLevelMap.GetTextureFilename(const s: string): string;
var P,P2,i: integer;
begin
  Result := '';
  // De texture bestandsnaam begint 2 posities na de 3e ")" op de regel.
  P := 0;
  i := 3;
  while i>0 do begin
    P := PosEx(')', s, P+1);
    if P=0 then Exit; //fout opgetreden..
    Dec(i);
  end;
  Inc(P, 2);
  // nu zoeken naar de eerstvolgende spatie..
  P2 := PosEx(' ', s, P);
  if P2=0 then Exit; //fout opgetreden..
  Result := MidStr(s, P, P2-P);
end;





//-- HalfLife
function TLevelMap.GetTextureAxisU(const s: string): TVector4f;
var P,P2,i: integer;
    S2,S3: string;
    F1,F2,F3,F4: Single;
begin
  Result.X := 0;
  Result.Y := 0;
  Result.Z := 0;
  Result.W := 0;
  // De vertex texture U-as begint op na eerste "[" van de regel.
  P := Pos('[', s);
  if P=0 then Exit; //fout opgetreden..
  // nu zoeken naar het eerstvolgende "]" teken..
  P2 := PosEx(']', s, P);
  if P2=0 then Exit; //fout opgetreden..
  S2 := MidStr(s, P+2, P2-P-4+1); // "[ " & " ]" eraf laten
  // de 4 floats eruit halen
  try
    // de 1e float
    P := Pos(' ', S2);
    if P=0 then Exit;
    S3 := MidStr(S2, 1, P-1);
    F1 := StrToFloat(S3);
    // de 2e float
    P2 := PosEx(' ', S2, P+1);
    if P2=0 then Exit;
    S3 := MidStr(S2, P+1, P2-P-1);
    F2 := StrToFloat(S3);
    // de 3e float
    P := PosEx(' ', S2, P2+1);
    if P=0 then Exit;
    S3 := MidStr(S2, P2+1, P-P2-1);
    F3 := StrToFloat(S3);
    // de 4e float
    S3 := MidStr(S2, P+1, Length(S2)-P);
    F4 := StrToFloat(S3);
    // de as
    Result.X := F1;
    Result.Y := F2;
    Result.Z := F3;
    Result.W := F4;
  except
    Exit;
  end;
end;

function TLevelMap.GetTextureAxisV(const s: string): TVector4f;
var P,P2,i: integer;
    S2,S3: string;
    F1,F2,F3,F4: Single;
begin
  Result.X := 0;
  Result.Y := 0;
  Result.Z := 0;
  Result.W := 0;
  // De vertex texture V-as begint op na tweede "[" van de regel.
  P := Pos('[', s);
  if P=0 then Exit; //fout opgetreden..
  P := PosEx('[', s, P+1);
  if P=0 then Exit; //fout opgetreden..
  // nu zoeken naar het eerstvolgende "]" teken..
  P2 := PosEx(']', s, P);
  if P2=0 then Exit; //fout opgetreden..
  S2 := MidStr(s, P+2, P2-P-4+1); // "[ " & " ]" eraf laten
  // de 4 floats eruit halen
  try
    // de 1e float
    P := Pos(' ', S2);
    if P=0 then Exit;
    S3 := MidStr(S2, 1, P-1);
    F1 := StrToFloat(S3);
    // de 2e float
    P2 := PosEx(' ', S2, P+1);
    if P2=0 then Exit;
    S3 := MidStr(S2, P+1, P2-P-1);
    F2 := StrToFloat(S3);
    // de 3e float
    P := PosEx(' ', S2, P2+1);
    if P=0 then Exit;
    S3 := MidStr(S2, P2+1, P-P2-1);
    F3 := StrToFloat(S3);
    // de 4e float
    S3 := MidStr(S2, P+1, Length(S2)-P);
    F4 := StrToFloat(S3);
    // de as
    Result.X := F1;
    Result.Y := F2;
    Result.Z := F3;
    Result.W := F4;
  except
    Exit;
  end;
end;


function TLevelMap.GetTextureScaleU(const s: string): Single;
var P,P2: integer;
    S2: string;
begin
  Result := 1.0;
  // de texture Scale-U begint, achter de tweede ']', dan na de tweede spatie
  P := Pos(']', s);
  if P=0 then Exit;
  P := PosEx(']', s, P+1);
  if P=0 then Exit;
  // zoek de 2e spatie
  P2 := PosEx(' ', s, P+2);
  if P2=0 then Exit;
  // zoek het eind van het getal (in string-vorm)
  P := PosEx(' ', s, P2+1);
  if P=0 then Exit;
  //
  S2 := MidStr(s, P2+1, P-P2-1);
  Result := StrToFloatDef(S2, 1.0);
end;


function TLevelMap.GetTextureScaleV(const s: string): Single;
var P,P2: integer;
    S2: string;
begin
  Result := 1.0;
  // de texture Scale-V begint, achter de tweede ']', dan na de derde spatie
  P := Pos(']', s);
  if P=0 then Exit;
  P := PosEx(']', s, P+1);
  if P=0 then Exit;
  // zoek de 2e spatie
  P2 := PosEx(' ', s, P+2);
  if P2=0 then Exit;
  // zoek de 3e spatie
  P := PosEx(' ', s, P2+1);
  if P=0 then Exit;
  // zoek het einde van het getal (in string-vorm)
  P2 := PosEx(' ', s, P+1);
  if P2=0 then Exit;
  //
  S2 := MidStr(s, P+1, P2-P-1);
  Result := StrToFloatDef(S2, 1.0);
end;
//-- /HalfLife


//-- Quake3
function TLevelMap.GetTextureScaleU_Q3(const s: string): Single;
const defval = 0.5;
var P,P2, code: integer;
    S2: string;
begin
  // "... ) texture 0.000000 0.000000 0.000000 0.500000 0.500000 0 0 0"
  //                                           ^------- ^-------
  //                                     scale U        V
  //
  Result := defval;
  // de texture Scale-U begint, achter de derde ')', dan na de vijfde spatie
  P := Pos(')', s);
  if P=0 then Exit;
  P := PosEx(')', s, P+1);
  if P=0 then Exit;
  P := PosEx(')', s, P+1);
  if P=0 then Exit;
  // zoek de 5e spatie
  P2 := PosEx(' ', s, P+2);
  if P2=0 then Exit;
  P2 := PosEx(' ', s, P2+1);
  if P2=0 then Exit;
  P2 := PosEx(' ', s, P2+1);
  if P2=0 then Exit;
  P2 := PosEx(' ', s, P2+1);
  if P2=0 then Exit;
  // zoek het eind van het getal (in string-vorm)
  P := PosEx(' ', s, P2+1);
  if P=0 then Exit;
  //
  S2 := MidStr(s, P2+1, P-P2-1);
  val(S2, Result, code);
  if code>0 then Result := defval;
//  Result := StrToFloatDef(S2, 1.0);
end;

function TLevelMap.GetTextureScaleV_Q3(const s: string): Single;
const defval = 0.5;
var P,P2, code: integer;
    S2: string;
begin
  // "... ) texture 0.000000 0.000000 0.000000 0.500000 0.500000 0 0 0"
  //                                           ^------- ^-------
  //                                     scale U        V
  //
  Result := defval;
  // de texture Scale-U begint, achter de derde ')', dan na de zesde spatie
  P := Pos(')', s);
  if P=0 then Exit;
  P := PosEx(')', s, P+1);
  if P=0 then Exit;
  P := PosEx(')', s, P+1);
  if P=0 then Exit;
  // zoek de 6e spatie
  P2 := PosEx(' ', s, P+2);
  if P2=0 then Exit;
  P2 := PosEx(' ', s, P2+1);
  if P2=0 then Exit;
  P2 := PosEx(' ', s, P2+1);
  if P2=0 then Exit;
  P2 := PosEx(' ', s, P2+1);
  if P2=0 then Exit;
  P2 := PosEx(' ', s, P2+1);
  if P2=0 then Exit;
  // zoek het eind van het getal (in string-vorm)
  P := PosEx(' ', s, P2+1);
  if P=0 then Exit;
  //
  S2 := MidStr(s, P2+1, P-P2-1);
  val(S2, Result, code);
  if code>0 then Result := defval;
//  Result := StrToFloatDef(S2, 1.0);
end;



function TLevelMap.GetTextureShiftU_Q3(const s: string): Single;
const defval = 0.0;
var P,P2, code: integer;
    S2: string;
begin
  Result := defval;
  // "... ) texture 0.000000 0.000000 0.000000 0.500000 0.500000 0 0 0"
  //                ^        ^
  //          shift U        V
  //
  // de texture shift-U begint, achter de derde ')', dan na de tweede spatie
  P := Pos(')', s);
  if P=0 then Exit;
  P := PosEx(')', s, P+1);
  if P=0 then Exit;
  P := PosEx(')', s, P+1);
  if P=0 then Exit;
  // zoek de 2e spatie
  P2 := PosEx(' ', s, P+2); //2e
  if P2=0 then Exit;
  // zoek het eind van het getal (in string-vorm)
  P := PosEx(' ', s, P2+1);
  if P=0 then Exit;
  //
  S2 := MidStr(s, P2+1, P-P2-1);
  val(S2, Result, code);
  if code>0 then Result := defval;
//  Result := StrToFloatDef(S2, 0.0);
end;

function TLevelMap.GetTextureShiftV_Q3(const s: string): Single;
const defval = 0.0;
var P,P2, code: integer;
    S2: string;
begin
  Result := defval;
  // "... ) texture 0.000000 0.000000 0.000000 0.500000 0.500000 0 0 0"
  //                ^        ^
  //          shift U        V
  //
  // de texture shift-U begint, achter de derde ')', dan na de derde spatie
  P := Pos(')', s);
  if P=0 then Exit;
  P := PosEx(')', s, P+1);
  if P=0 then Exit;
  P := PosEx(')', s, P+1);
  if P=0 then Exit;
  // zoek de 3e spatie
  P2 := PosEx(' ', s, P+2); //2e
  if P2=0 then Exit;
  P2 := PosEx(' ', s, P2+1);
  if P2=0 then Exit;
  // zoek het eind van het getal (in string-vorm)
  P := PosEx(' ', s, P2+1);
  if P=0 then P := Length(s)+1;
  //
  S2 := MidStr(s, P2+1, P-P2-1);
  val(S2, Result, code);
  if code>0 then Result := defval;
//  Result := StrToFloatDef(S2, 0.0);
end;

function TLevelMap.GetTextureRotation_Q3(const s: string): Single;
const defval = 0.0;
var P,P2, code: integer;
    S2: string;
begin
  Result := defval;
  // "... ) texture 0.000000 0.000000 0.000000 0.500000 0.500000 0 0 0"
  //                                  ^
  //                                  Rotatie
  //
  // de texture shift-U begint, achter de derde ')', dan na de vierde spatie
  P := Pos(')', s);
  if P=0 then Exit;
  P := PosEx(')', s, P+1);
  if P=0 then Exit;
  P := PosEx(')', s, P+1);
  if P=0 then Exit;
  // zoek de 4e spatie
  P2 := PosEx(' ', s, P+2); //2e
  if P2=0 then Exit;
  P2 := PosEx(' ', s, P2+1);
  if P2=0 then Exit;
  P2 := PosEx(' ', s, P2+1);
  if P2=0 then Exit;
  // zoek het eind van het getal (in string-vorm)
  P := PosEx(' ', s, P2+1);
  if P=0 then P := Length(s)+1;
  //
  S2 := MidStr(s, P2+1, P-P2-1);
  val(S2, Result, code);
  if code>0 then Result := defval;
//  Result := StrToFloatDef(S2, 0.0);
end;


//-- /Quake3




procedure TLevelMap.CalcUVAxis(aPlane: TMapPlane; P1,P2,P3, Normal: TVector; RotDeg: Single; var AxisU, AxisV: TVector);
  //----------------------------------------------------------------------------
  function ShiftCoord(P, origin, AxisU,AxisV: TVector) : TVector;
  var D: TVector;
  begin
     D :=  SubVector(P, origin);
     Result.X := DotProduct(D, AxisU);
     Result.Y := DotProduct(D, AxisV);
     Result.Z := 0.0;
  end;
  //----------------------------------------------------------------------------
  function InvertDenom(P0,P1,P2: TVector) : Double;
  begin
    Result :=  -P2.X*P1.Y + P2.X*P0.Y + P2.Y*P1.X
              - P2.Y*P0.X + P0.X*P1.Y - P0.Y*P1.X;
  end;
  //----------------------------------------------------------------------------
const Xas=1; Yas=2; Zas=3;
var N, V, V1,V2,V3, origin: TVector;
    RotX,RotY,RotZ, Det: Double;
    MaxAs: Integer;
    i: integer;
    M: TMatrix4x4;
    S,C,tmp: Single;
begin
  N := Normal;

  if Abs(N.X) < 1E-6 then N.X := 0.0;
  if Abs(N.Y) < 1E-6 then N.Y := 0.0;
  if Abs(N.Z) < 1E-6 then N.Z := 0.0;

  if 1.0-Abs(N.X) < 1E-6 then N.X := Sign(N.X) {* 1.0};
  if 1.0-Abs(N.Y) < 1E-6 then N.Y := Sign(N.Y) {* 1.0};
  if 1.0-Abs(N.Z) < 1E-6 then N.Z := Sign(N.Z) {* 1.0};

//--methode C1
  // 2 assen (U & V) zoeken die loodrecht staan op de normaal N.
  // maximale coordinaat/richting zoeken
  if (abs(N.X)>abs(N.Y)) and (abs(N.X)>abs(N.Z)) then MaxAs:=Xas else
  if (abs(N.Y)>abs(N.X)) and (abs(N.Y)>abs(N.Z)) then MaxAs:=Yas else
  {if (abs(N.Z)>abs(N.X)) and (abs(N.Z)>abs(N.Y)) then} MaxAs:=Zas;
  // de normaal N wijst dus het meest in de richting MaxAs

  if AxisAlignedVector(N) then begin

    // org. C code
    if MaxAs = Zas then begin
      AxisU := Vector(1,0,0);
      AxisV := Vector(0,1,0);
    end else
    if MaxAs = Xas then begin
      AxisU := Vector(0,0,-1);
      AxisV := Vector(0,1,0);
    end else
   {if MaxAs = Yas then} begin
      AxisU := Vector(1,0,0);
      AxisV := Vector(0,0,-1);
    end;

    // rotatie van de texture op het vlak(AxisU,AxisV)
    if RotDeg = 180.0 then RotDeg := -180.0;
    if MaxAs = Zas then
      M := AxisRotationMatrix(N, -Sign(N.Z) * RotDeg)
    else
      if MaxAs = Yas then
        M := AxisRotationMatrix(N, -Sign(N.Y) * RotDeg)
      else
        M := AxisRotationMatrix(N, RotDeg);
    // roteer de assen / vermenigvuldig het punt met de rotatie-matrix
    AxisU := TransformVector(AxisU, M);
    AxisV := TransformVector(AxisV, M);

  end else begin

    // standaard as-stelsel / basis
    AxisU := UnitVector(CrossProduct(Vector(0,-1,0),N));
    AxisV := UnitVector(CrossProduct(N, AxisU));

(*
M := AxisRotationMatrix(N, RotDeg);
// roteer de assen / vermenigvuldig het punt met de rotatie-matrix
AxisU := TransformVector(AxisU, M);
AxisV := TransformVector(AxisV, M);
*)

  end;
//--methode C1
end;


function TLevelMap.CalcTextureCoords(var aPlane: TMapPlane; aVertex: TVector; aTextureIndex: Integer): TVector2f;
var tmp,
    S,C,
    InvW,InvH,
    ShiftW,ShiftH,
    InvScaleW,InvScaleH,
    U,V: Single;
    M,M2,M3: TMatrix4x4;
    origin, Vec,Vx,Vy,Vz,
    aU,aV: TVector;
begin
  // De texture-coördinaten voor 1 vertex:
  // Tu = (V · Nu)        Ou           Tu & Tv: 2 texture-coördinaten
  //       _______ / Su + __                 V: vertex waarvan de texCoords worden berekend
  //         w            w            Nu & Nv: texture as-normalen
  //                                     w & h: texture breedte & hoogte (pixels)
  // Tv = (V · Nv)        Ov           Su & Sv: texture scale
  //       _______ / Sv + __           Ou & Ov: texture offset (shift)
  //         h            h

  Result.X := 0;
  Result.Y := 0;
  if aTextureIndex < 0 then Exit;
  if Textures[aTextureIndex].Filename = '' then Exit;

  InvW := 1.0 / Textures[aTextureIndex].TextureWidth;
  InvH := 1.0 / Textures[aTextureIndex].TextureHeight;

  InvScaleW := 1.0 / aPlane.TextureScaleU;
  InvScaleH := 1.0 / aPlane.TextureScaleV;

  ShiftW := aPlane.TextureShiftU * InvW;
  ShiftH := aPlane.TextureShiftV * InvH;

  // origin van het plane's coordinaten-systeem
//  origin := ScaleVector(aPlane.Normal, aPlane.Distance);


(*
// org
  Result.X := DotProduct(aVertex, aPlane.TextureAxisU) * InvW * InvScaleW + ShiftW;
  Result.Y := DotProduct(aVertex, aPlane.TextureAxisV) * InvH * InvScaleH - ShiftH;
*)

  if AxisAlignedVector(aPlane.Normal) then begin

    //org C
    Result.X := DotProduct(aVertex, aPlane.TextureAxisU) * InvW * InvScaleW + ShiftW;
    Result.Y := DotProduct(aVertex, aPlane.TextureAxisV) * InvH * InvScaleH - ShiftH;

  end else begin

    // De relatieve positie in het as-stelsel AxisU-V bepalen voor het punt aVertex
    // Quark documentatie:  v = (xr*v)*xr + (yr*v)*yr + (zr*v)*zr
    Vx := ScaleVector(aPlane.TextureAxisU, DotProduct(aPlane.TextureAxisU, aVertex));
    Vy := ScaleVector(aPlane.TextureAxisV, DotProduct(aPlane.TextureAxisV, aVertex));
    Vz := ScaleVector(aPlane.Normal, DotProduct(aPlane.Normal, aVertex));
    Vec := AddVector(AddVector(Vx, Vy), Vz);

    Result.X := DotProduct(Vec, aPlane.TextureAxisU) * InvW * InvScaleW + ShiftW;
    Result.Y := -DotProduct(Vec, aPlane.TextureAxisV) * InvH * InvScaleH - ShiftH;
(*
//if aPlane.Normal.Z < 0 then ShiftH := -ShiftH;
    Result.X := DotProduct(aVertex, aPlane.TextureAxisU) * InvW * InvScaleW + ShiftW;
    Result.Y := DotProduct(aVertex, aPlane.TextureAxisV) * InvH * InvScaleH - ShiftH;
*)
  end;

end;

procedure TLevelMap.CorrectTextureCoords(startVertexIndex, N_Verts: Integer);
var Nearest: Single;
    NearestIndex, j: Integer;
    U,V: Single;
begin
  // doorloop alle punten van 1 polygon/face
  // en pas de texture-coords. aan in een bereik -1..1

  // Eerst de U-coördinaat
  Nearest := Vertices[startVertexIndex].TextureCoord.X;
  NearestIndex := startVertexIndex;
  for j:=0 to N_Verts-1 do begin
    U := Vertices[startVertexIndex+j].TextureCoord.X;
    // coord. niet in bereik -1..1 ??, anders is ie al goed..
    if Abs(U) > 1 then begin
      if Abs(U) < Abs(Nearest) then begin
        Nearest := U;
        NearestIndex := startVertexIndex+j;
      end;
    end else begin
      // alle coords. zijn al goed.
      Exit;
    end;
  end;
  for j:=0 to N_Verts-1 do
    Vertices[startVertexIndex+j].TextureCoord.X := Vertices[startVertexIndex+j].TextureCoord.X - Nearest;

  // de V-coördinaat
  Nearest := Vertices[startVertexIndex].TextureCoord.Y;
  NearestIndex := startVertexIndex;
  for j:=0 to N_Verts-1 do begin
    V := Vertices[startVertexIndex+j].TextureCoord.Y;
    // coord. niet in bereik -1..1 ??, anders is ie al goed..
    if Abs(V) > 1 then begin
      if Abs(V) < Abs(Nearest) then begin
        Nearest := V;
        NearestIndex := startVertexIndex+j;
      end;
    end else begin
      // alle coords. zijn al goed.
      Exit;
    end;
  end;
  for j:=0 to N_Verts-1 do
    Vertices[startVertexIndex+j].TextureCoord.Y := Vertices[startVertexIndex+j].TextureCoord.Y - Nearest;
end;


function TLevelMap.IsTextureInList(var Filename: string): Integer;
var i: integer;
    n: string;
begin
  Result := -1;
  n := Filename;
  if not OGL.Textures.FindTexture(n) then Exit;
  Filename := n;
  for i:=0 to N_Textures-1 do begin
    if Textures[i].Filename = n then begin
      Result := i;
      Exit;
    end;
  end;
end;

function TLevelMap.AddTextureToList(Filename: string; Width,Height: Integer): Integer;
begin
  Inc(N_Textures);
  SetLength(Textures, N_Textures);
  Result := N_Textures-1;
  Textures[Result].Filename := Filename;
  Textures[Result].TextureWidth := Width;
  Textures[Result].TextureHeight := Height;
  Textures[Result].Handle := 0;
end;


function TLevelMap.validTexture(const Filename: string): boolean;
var i: integer;
begin
  Result := true;
  for i:=0 to Length(DontShow)-1 do begin
    Result := (Pos(DontShow[i], Filename)=0);
    if not Result then Exit;
  end;
end;

procedure TLevelMap.InitTextures;
var i: integer;
begin
  for i:=0 to N_Textures-1 do
    if Textures[i].Handle = 0 then
      Textures[i].Handle := OGL.Textures.LoadTexture(Textures[i].Filename);
end;

procedure TLevelMap.FreeTextures;
var i: integer;
begin
  for i:=0 to N_Textures-1 do
    OGL.Textures.DeleteTexture(Textures[i].Handle);
  N_Textures := 0;
  SetLength(Textures, 0);
end;





procedure TLevelMap.ProcessBrush(var SLB: TStringList);
type VectorList = array of TVector;
var Vi1, Vi2, Vi3: TVector3i;
    Vf1, Vf2, Vf3: TVector;
    TextureFilename, TextureExtension: string;
    TextureWidth, TextureHeight: Integer;
    TextureAxisU4, TextureAxisV4: TVector4f;
    TextureIndex: Integer;
    i,j,k,L,m,Len,LF,LV: integer;
    BrushPlanes: array of TMapPlane;
    Plane1, Plane2, Plane3: TPlane;
    N_PlanesA, N_FacesA: Integer;
    FacesA: array of VectorList; // voor elke plane, een array met face-vertices
    tmpList: VectorList;
    valid, reSort: boolean;
    N, V, tmpV, BestAxis: TVector;
    s,s2: string;
    AxisN: Integer;
    tmpFloat: Single;
    LineSL: TStringList;
  //--------------------------------------------------------------------------
  function VectorInWorld(aV: TVector): boolean;
  begin
    Result := false;
    if (aV.X < -MaxWorld) or (aV.X > MaxWorld) then Exit;
    if (aV.Y < -MaxWorld) or (aV.Y > MaxWorld) then Exit;
    if (aV.Z < -MaxWorld) or (aV.Z > MaxWorld) then Exit;
    Result := true;
  end;
  //--------------------------------------------------------------------------
  function VectorInList(var VL: VectorList; aV: TVector): boolean;
  var m: integer;
  begin
    Result := true;
    for m:=0 to Length(VL)-1 do begin
      if (aV.X <= VL[m].X - EPSILON) or (aV.X >= VL[m].X + EPSILON) then continue;
      if (aV.Y <= VL[m].Y - EPSILON) or (aV.Y >= VL[m].Y + EPSILON) then continue;
      if (aV.Z <= VL[m].Z - EPSILON) or (aV.Z >= VL[m].Z + EPSILON) then continue;
      Exit;
    end;
    Result := false;
  end;
  //--------------------------------------------------------------------------
  procedure AddVectorToList(var VL: VectorList; aV: TVector);
  var Len: integer;
  begin
    Len := Length(VL);
    SetLength(VL, Len+1);
    VL[Len] := aV;
  end;
  //--------------------------------------------------------------------------
  // punten rangschikken op volgorde in de polygon
  procedure SortVectorList(var VL: VectorList; N: TVector);
  const FrontFaced = GL_CCW;
  var Center, chkN, A,B, tmpV: TVector;
      i,j, Smallest: integer;
      SmallestAngle, Angle: Double;
      Plane: TPlane;
  begin
    // het centrum van de face bepalen
    Len := Length(VL);


    Center := NullVector;
    for i:=0 to Len-1 do Center := AddVector(Center, VL[i]);
    Center := ScaleVector(Center, 1.0/Len);

    // alle punten in deze face doorlopen
    for i:=0 to Len-2 do begin
      Smallest := -1;
      SmallestAngle := -1.0;  // 180 graden

      // het vlak, loodrecht op de te checken plane,
      // tbv testen de volgorde in de polygon
      chkN := PlaneNormal(VL[i], Center, AddVector(Center,N));
      Plane.Normal := chkN;
      Plane.d := PlaneDistance(chkN, VL[i]);

      // een vector samenstellen, die loopt vanuit Center naar punt[i] in de polygon
      A := SubVector(VL[i], Center);
      A := UnitVector(A);

      for j:=i+1 to Len-1 do begin
        // ligt het punt voor?-, of achter het vlak P?
        if DotProduct(Plane.Normal, VL[j]) + Plane.d >= 0 then begin
          // het punt ligt ervoor..

          // een vector samenstellen, die loopt vanuit Center naar punt[i] in de polygon
          B := SubVector(VL[j], Center);
          B := UnitVector(B);

          // bereken de hoek tussen de vectoren A & B..
          // vector A loopt van het Center naar punt[i],
          // vector B loopt van het Center naar punt[j].
          Angle := DotProduct(A,B);
          // Angle bevat nu de invCos van de hoek tussen A&B.
          // cos   0 graden =  1
          // cos  90 graden =  0
          // cos 180 graden = -1
          // cos 270 graden =  0

          // Als de hoek kleiner is, is de invCos groter
          if Angle >= SmallestAngle then begin
            SmallestAngle := Angle;
            Smallest := j;
          end;
        end;
      end;

      // swap punt[i+1] met punt[Smallest]
      if (Smallest<>i+1) and (Smallest<>-1) then begin
        tmpV := VL[i+1];
        VL[i+1] := VL[Smallest];
        VL[Smallest] := tmpV;
      end;
    end;
    
(*
//    if not IsCCW(VL, Center) then begin
      // vertices volgorde in de face omkeren
      for j:=0 to (Len div 2)-1 do begin
        tmpV := VL[j];
        VL[j] := VL[Len-1-j];
        VL[Len-1-j] := tmpV;
      end;
//    end;
*)
  end;
  //--------------------------------------------------------------------------
begin
  if (SLB.Count<=1) then begin
    SLB.Clear;
    Exit;
  end;
//  if Pos('TRIGGER', SLB.Strings[0]) <> 0 then Exit;
//  if Pos('common/', SLB.Strings[0]) > 0 then Exit;

  N_PlanesA := SLB.Count-1;

  // !NB: SLB.Strings[0] = de eerste regel met brush-info (dus <>'{' !!)
  //      SLB.Strings[SLB.Count-1] = '}'
{ Print_StdOut('Brush: '+ IntToStr(N_PlanesA) +' planes');}

  // De planes in deze brush converteren naar TPlane's..
  SetLength(BrushPlanes, N_PlanesA);
  for i:=0 to N_PlanesA-1 do begin


    // de string, (1 regel van de brush uit de .MAP-file), opsplitsen in een lijst met losse "woorden"/getallen
    LineSL := TStringList.Create;
    LineSL.Clear;
    try
      //HL
      //( 720 1136 -128 ) ( 752 1136 -128 ) ( 752 1168 -128 ) AAATRIGGER [ 1 0 0 0 ] [ 0 -1 0 -16 ] 0 1 1
      //
      //Q3
      //( 2296 -1928 32 ) ( 2296 -1912 32 ) ( 2296 -1928 224 ) egypt_walls_sd/stucco01_decor01 0 -16 0 0.500000 -0.500000 134217728 0 0
      SplitString(SLB.Strings[i], LineSL);
      if LineSL.Count<15 then Continue; //volgende plane testen..
      //
      Vf1.X := StringToFloatDef(LineSL.Strings[1], 0);
      Vf1.Y := StringToFloatDef(LineSL.Strings[2], 0);
      Vf1.Z := StringToFloatDef(LineSL.Strings[3], 0);
      Vf2.X := StringToFloatDef(LineSL.Strings[6], 0);
      Vf2.Y := StringToFloatDef(LineSL.Strings[7], 0);
      Vf2.Z := StringToFloatDef(LineSL.Strings[8], 0);
      Vf3.X := StringToFloatDef(LineSL.Strings[11], 0);
      Vf3.Y := StringToFloatDef(LineSL.Strings[12], 0);
      Vf3.Z := StringToFloatDef(LineSL.Strings[13], 0);
      // map-coordinaten zijn afwijkend van de OpenGL-coordinaten
      Vf1.X := -Vf1.X;
      tmpFloat := Vf1.Y;
      Vf1.Y := -Vf1.Z;
      Vf1.Z := tmpFloat;
      //
      Vf2.X := -Vf2.X;
      tmpFloat := Vf2.Y;
      Vf2.Y := -Vf2.Z;
      Vf2.Z := tmpFloat;
      //
      Vf3.X := -Vf3.X;
      tmpFloat := Vf3.Y;
      Vf3.Y := -Vf3.Z;
      Vf3.Z := tmpFloat;
      // map-coordinaten zijn afwijkend van de OpenGL-coordinaten
      tmpV := Vf1; //!!!!!!!!!!!!!!!!!!!!!!
      Vf1 := Vf3;  // orientatie omkeren //
      Vf3 := tmpV; //!!!!!!!!!!!!!!!!!!!!!!

      // de opgegeven punten uit de .map file onthouden..
      BrushPlanes[i].P0 := Vf1;
      BrushPlanes[i].P1 := Vf2;
      BrushPlanes[i].P2 := Vf3;
      // een vlak maken
      N := PlaneNormal(Vf1, Vf2, Vf3);
      BrushPlanes[i].Normal := N;
      BrushPlanes[i].Distance := PlaneDistance(N, Vf1);

      //
      TextureFilename := LineSL.Strings[15];

      // HalfLife
      if MapFormat = MapFormat_HalfLife then begin
        BrushPlanes[i].TextureAxisU := Vector( StringToFloatDef(LineSL.Strings[17], 0),
                                               StringToFloatDef(LineSL.Strings[18], 0),
                                               StringToFloatDef(LineSL.Strings[19], 0) );
        BrushPlanes[i].TextureShiftU := StringToFloatDef(LineSL.Strings[20], 0);
        BrushPlanes[i].TextureAxisV := Vector( StringToFloatDef(LineSL.Strings[23], 0),
                                               StringToFloatDef(LineSL.Strings[24], 0),
                                               StringToFloatDef(LineSL.Strings[25], 0) );
        BrushPlanes[i].TextureShiftV := StringToFloatDef(LineSL.Strings[26], 0);
        // ..rotation, :s .. die is al verwerkt in de AxisU & AxisV..
        BrushPlanes[i].TextureScaleU := StringToFloatDef(LineSL.Strings[29], 1);
        BrushPlanes[i].TextureScaleV := StringToFloatDef(LineSL.Strings[30], 1);
      end else
      // Quake3
      if MapFormat = MapFormat_Quake3 then begin
        BrushPlanes[i].TextureShiftU := StringToFloatDef(LineSL.Strings[16], 0);
        BrushPlanes[i].TextureShiftV := StringToFloatDef(LineSL.Strings[17], 0);
        BrushPlanes[i].TextureRotation := StringToFloatDef(LineSL.Strings[18], 0);
        BrushPlanes[i].TextureScaleU := StringToFloatDef(LineSL.Strings[19], 1);
        BrushPlanes[i].TextureScaleV := StringToFloatDef(LineSL.Strings[20], 1);
        // correcties
        if BrushPlanes[i].TextureScaleU = 0 then BrushPlanes[i].TextureScaleU := 1;
        if BrushPlanes[i].TextureScaleV = 0 then BrushPlanes[i].TextureScaleV := 1;
      end;

    finally
      LineSL.Free;
    end;


(*
    //planes in de .map-file zijn CCW geöriënteerd
    Vi1 := GetVertex(1, SLB.Strings[i]);
    Vi2 := GetVertex(2, SLB.Strings[i]);
    Vi3 := GetVertex(3, SLB.Strings[i]);
    TextureFilename := GetTextureFilename(SLB.Strings[i]);

    // map-coordinaten zijn afwijkend van de OpenGL-coordinaten
    Vi1.X := -Vi1.X;
    j := Vi1.Y;
    Vi1.Y := -Vi1.Z;
    Vi1.Z := j;
    //
    Vi2.X := -Vi2.X;
    j := Vi2.Y;
    Vi2.Y := -Vi2.Z;
    Vi2.Z := j;
    //
    Vi3.X := -Vi3.X;
    j := Vi3.Y;
    Vi3.Y := -Vi3.Z;
    Vi3.Z := j;
    //
    Vf1 := Vector3iToVector3f(Vi3); //!!!!!!!!!!!!!!!!!!!!!!
    Vf2 := Vector3iToVector3f(Vi2); // orientatie omkeren //
    Vf3 := Vector3iToVector3f(Vi1); //!!!!!!!!!!!!!!!!!!!!!!

    // de opgegeven punten uit de .map file onthouden..
    BrushPlanes[i].P0 := Vf1;
    BrushPlanes[i].P1 := Vf2;
    BrushPlanes[i].P2 := Vf3;


    // een vlak maken
    N := PlaneNormal(Vf1, Vf2, Vf3);
    BrushPlanes[i].Normal := N;
    BrushPlanes[i].Distance := PlaneDistance(N, Vf1);

    // HalfLife
    if MapFormat = MapFormat_HalfLife then begin
      TextureAxisU4 := GetTextureAxisU(SLB.Strings[i]);
      TextureAxisV4 := GetTextureAxisV(SLB.Strings[i]);
      BrushPlanes[i].TextureAxisU := Vector(TextureAxisU4.X, TextureAxisU4.Y, TextureAxisU4.Z);
      BrushPlanes[i].TextureAxisV := Vector(TextureAxisV4.X, TextureAxisV4.Y, TextureAxisV4.Z);
      BrushPlanes[i].TextureShiftU := TextureAxisU4.W;
      BrushPlanes[i].TextureShiftV := TextureAxisV4.W;
      BrushPlanes[i].TextureScaleU := GetTextureScaleU(SLB.Strings[i]);
      BrushPlanes[i].TextureScaleV := GetTextureScaleV(SLB.Strings[i]);
    end else
      // Quake3
    if MapFormat = MapFormat_Quake3 then begin
      BrushPlanes[i].TextureShiftU := GetTextureShiftU_Q3(SLB.Strings[i]);
      BrushPlanes[i].TextureShiftV := GetTextureShiftV_Q3(SLB.Strings[i]);
      BrushPlanes[i].TextureRotation := GetTextureRotation_Q3(SLB.Strings[i]);
      BrushPlanes[i].TextureScaleU := GetTextureScaleU_Q3(SLB.Strings[i]);
      BrushPlanes[i].TextureScaleV := GetTextureScaleV_Q3(SLB.Strings[i]);
      // correcties
      if BrushPlanes[i].TextureScaleU = 0 then BrushPlanes[i].TextureScaleU := 1;
      if BrushPlanes[i].TextureScaleV = 0 then BrushPlanes[i].TextureScaleV := 1;
    end;
*)


    // de texture van dit vlak/face
    // check of de texture al is opgenomen in de array Textures,
    // en geef meteen de absolute TextureFilename terug (indien de texture bestaat in 1 van de zoekpaden)
    // (indien texture niet is gevonden, de TextureFilename onveranderd laten)
    TextureIndex := IsTextureInList(TextureFilename);
    // texture nog niet in de lijst met textures??
    if TextureIndex = -1 then
      // texture toevoegen aan de array Textures (als de texture bestaat en dus de info ervan kan worden opgevraagd)
      if OGL.Textures.GetTextureInfo(TextureFilename, TextureExtension, TextureWidth, TextureHeight) then
        TextureIndex := AddTextureToList(TextureFilename, TextureWidth, TextureHeight);
(*
    // alle aparte (onzichtbare) textures negeren
    if TextureIndex <> -1 then
      if (Pos('common\', TextureFilename)>0) and (Pos('common\caulk', TextureFilename)=0) then TextureIndex := -1;
*)
    BrushPlanes[i].TextureIndex := TextureIndex;
  end;

  // De planes van deze brush omzetten naar faces (met hoekpunten).
  SetLength(FacesA, N_PlanesA);
  for i:=0 to N_PlanesA-1 do SetLength(FacesA[i], 0);

  // Daarvoor alle mogelijke combinaties van planes doorlopen van deze brush..
  for i:=0 to N_PlanesA-3 do begin
    for j:=i+1 to N_PlanesA-2 do begin
      for k:=j+1 to N_PlanesA-1 do begin
        // niet dezelfde planes vergelijken..
        if (i<>j) and (i<>k) and (j<>k) then begin
          // de 3 planes
          Plane1.Normal := BrushPlanes[i].Normal;
          Plane1.d := BrushPlanes[i].Distance;
          Plane2.Normal := BrushPlanes[j].Normal;
          Plane2.d := BrushPlanes[j].Distance;
          Plane3.Normal := BrushPlanes[k].Normal;
          Plane3.d := BrushPlanes[k].Distance;
          // snijden de planes??
          if PlanesIntersectionPoint(Plane1, Plane2, Plane3, V) {and VectorInWorld(V)} then begin
            // is het snijpunt V in de brush??
            valid := true;
            for L:=0 to N_PlanesA-1 do begin
              if (L<>i) and (L<>j) and (L<>k) then begin
                // punt buiten de brush?
                if DotProduct(BrushPlanes[L].Normal, V) - BrushPlanes[L].Distance > 0  then begin
                  valid := false;
                  break;
                end;
              end;
            end;
            if valid then begin
              // snijpunt nog niet opgenomen in de Faces-array??
              if not VectorInList(FacesA[i], V) then AddVectorToList(FacesA[i], V);
              if not VectorInList(FacesA[j], V) then AddVectorToList(FacesA[j], V);
              if not VectorInList(FacesA[k], V) then AddVectorToList(FacesA[k], V);
            end;
          end;
        end;
      end;
    end;
  end;

  // Nu hebben we een array FacesA, met N_PlanesA elementen.
  // Voor elk vlak is er een array van punten (in dat vlak).
  for i:=0 to N_PlanesA-1 do begin
    Len := Length(FacesA[i]);
    if Len>=3 then begin
      // CCW ordenen
      SortVectorList(FacesA[i], BrushPlanes[i].Normal);
      // U- & V-as voor het texture-coordinaat-stelsel uitrekenen
      CalcUVAxis(BrushPlanes[i], Vf1,Vf1,Vf3, BrushPlanes[i].Normal, BrushPlanes[i].TextureRotation, BrushPlanes[i].TextureAxisU, BrushPlanes[i].TextureAxisV);

      //
      LF := Length(Faces);
      LV := Length(Vertices);
      // punten toevoegen als een face van de map..
      SetLength(Faces, LF+1);
      N_Faces := LF+1;
      Faces[LF].N_Vertices := Len;
      Faces[LF].startVertIndex := LV;
      Faces[LF].Normal := BrushPlanes[i].Normal;
      Faces[LF].TextureIndex := BrushPlanes[i].TextureIndex;
      // Deze vertices toevoegen..
      SetLength(Vertices, LV+Len);
      N_Vertices := LV+Len;
      for j:=0 to Len-1 do begin
        Vertices[LV+j].Normal := BrushPlanes[i].Normal;
        Vertices[LV+j].Position := FacesA[i][j];
        // de texture-coördinaten uitrekenen
        Vertices[LV+j].TextureCoord := CalcTextureCoords(BrushPlanes[i], Vertices[LV+j].Position, BrushPlanes[i].TextureIndex);
      end;
      // de texture-coördinaten normaliseren naar een bereik[-1..1]
      // Dit moet per polygon worden verwerkt.
//      CorrectTextureCoords(LV, Len);
    end;
  end;

  for i:=0 to N_PlanesA-1 do SetLength(FacesA[i], 0);
  SetLength(FacesA, 0);
  SetLength(BrushPlanes, 0);
  // na verwerking van de brush, de stringlist legen voor de volgende verwerking
  SLB.Clear;
end;


procedure TLevelMap.ProcessClass(var SL: TStringList);
var i: integer;
    SLB: TStringList;
    Level: integer;
    isClassname,
    isPatchDef,
    is_info,
    is_func,
    is_trigger,
    is_script: boolean;
begin
  // bepaal de classname voor deze gelezen class info-blok..
  // dat is de eerste regel in de stringlist.
  if SL.Count <= 0 then Exit;
  // !NB: SL.Strings[0] = '{' nu..
  //      SL.Strings[SL.Count-1] = '}'

  // brushes zoeken en verwerken..
  // Maar dan alleen als ze onderdeel zijn van de blok: "classname" "worldspawn".
  // Al die andere info is game-gerelateerd, en daar heb ik niks aan.

  f3DS.Refresh;  //Unit1
  f3DS.ProgressBarClass.Position := 0;  //Unit1
  f3DS.ProgressBarClass.Max := SL.Count;  //Unit1

  i := 0;
  repeat
    isClassname := (Pos('"classname"', SL.Strings[i])>0);
    isPatchDef := (Pos('patchDef', SL.Strings[i])>0);
    if isClassname then begin
      Print_StdOut(SL.Strings[i]);  //classname afbeelden
      // func_ info_ trigger_ ??
      is_func     := (Pos(Classname_func, SL.Strings[i])>0);
      is_info     := (Pos(Classname_info, SL.Strings[i])>0);
      is_trigger  := (Pos(Classname_trigger, SL.Strings[i])>0);
      is_script   := (Pos(Classname_script, SL.Strings[i])>0);
      Break;
    end;
    Inc(i);
  until (i>SL.Count-1) or (SL.Strings[i]='{');

  if isClassname {and not (is_trigger or is_script)} then begin
    SLB := TStringList.Create;
    SLB.Clear;
    Level := 0;
    for i:=1 to SL.Count-2 do begin

      f3DS.ProgressBarClass.Position := i;  //Unit1

      if Level = 1 then SLB.Add(SL.Strings[i]);
      if SL.Strings[i] = '{' then Inc(Level) else
      if SL.Strings[i] = '}' then begin
        Dec(Level);
        // Is er een compleet Brush-blok ingelezen in de stringlist?..dan verwerken.
        if Level = 0 then
          // info- & trigger-brushes negeren
//          if not (is_info or is_trigger or is_script) then begin
            ProcessBrush(SLB);
//          end;
      end;
    end;
    SLB.Free;
  end;
  // na verwerking van de class, de stringlist legen voor de volgende verwerking
  SL.Clear;

  f3DS.ProgressBarClass.Position := 0;  //Unit1

end;


function TLevelMap.LoadMAP(const Filename: string): Boolean;
var F : TextFile;
    s: string;
    sl, slFile: TStringList;
    Level, LineNr: integer;
begin
  Result := false;
  MapLoaded := false;

  // object legen..
  Clear;

  MapFormat := GetMapFormat(Filename);
  formatHalfLife := (MapFormat=MapFormat_HalfLife);
  formatQuake3 := (MapFormat=MapFormat_Quake3);
  if not (formatHalfLife or formatQuake3) then Exit;

  // Controleer of het .map bestand ge-opend kan worden
  AssignFile(F, Filename);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult <> 0 then begin
    //MessageBox(0, 'MAP niet gevonden!', 'Error', MB_OK);
    Exit;
  end;
  // Sluit het .map bestand
  CloseFile(F);
  //
  Print_StdOut('MAP-file: '+ Filename);

  // eerst de hele file inlezen in een stringlist
  slFile := TStringList.Create;
  slFile.Clear;
  slFile.LoadFromFile(Filename);
  // tbv. per regel lezen & verwerken van het ASCII-bestand..
  sl := TStringList.Create; //de stringlist aanmaken..
  sl.Clear;

  SetLength(Faces, 0);
  SetLength(Vertices, 0);
  N_Faces := 0;
  N_Vertices := 0;

  try

    f3DS.ProgressBarTotal.Position := 0;  //Unit1
    f3DS.ProgressBarTotal.Max := slFile.Count;  //Unit1

    LineNr := 0;
    Level := 0; //voor verwerking {} binnen {}
    while {not EOF(F)} LineNr<slFile.Count-1 do begin

      f3DS.ProgressBarTotal.Position := LineNr;  //Unit1

      // Lees een compleet blok tussen de eerstvolgend gevonden { } tekens
      {ReadLn(F, s);}  s := slFile.Strings[LineNr];

      Inc(LineNr);

      // commentaar negeren..
      if Pos('//', s) = 0 then begin //geen commentaar = 0, wel commentaar > 0
        sl.Add(s);
        if s = '{' then Inc(Level) else    // Het begin van een blok?..
        if s = '}' then begin              // Het einde van een blok?..
          Dec(Level);
          // Is er een compleet ClassName-blok ingelezen in de stringlist?..dan verwerken.
          if Level = 0 then ProcessClass(sl);
        end;
      end;
    end;

    f3DS.ProgressBarTotal.Position := 0;  //Unit1

    // Alle textures van deze map laden en aanmaken in OpenGL
    InitTextures;
  finally
    //de stringlists verwijderen.
    sl.Free;
    slFile.Free;
  end;
  MapLoaded := true;
  Result := true;
end;


function TLevelMap.GetMapFormat(const Filename: string): string;
var F : TextFile;
    s: string;
    P1,P2,P3: Integer;
begin
  Result := MapFormat_Unknown;

  // Controleer of het .map bestand ge-opend kan worden
  AssignFile(F, Filename);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult <> 0 then begin
    //MessageBox(0, 'MAP niet gevonden!', 'Error', MB_OK);
    Exit;
  end;

  try
    // zoek de eerste brush
    repeat
      ReadLn(F, s); // Lees een regel
      if s = '{' then begin
        // volgende regel 3 punten opgegeven??   "( 256 -80 104 ) ( 192 -80 104 ) ( 192 -112 104 )"
        ReadLn(F, s); // Lees een regel
        // test of er zich 3x een '(' in de regel bevindt
        P1 := Pos('(', s);
        if P1=0 then Continue; //volgende regel testen..
        P2 := PosEx('(', s, P1+1);
        if P2=0 then Continue;
        P3 := PosEx('(', s, P2+1);
        if P3=0 then Continue;
        // test of er zich 3x een ')' in de regel bevindt
        P1 := Pos(')', s);
        if P1=0 then Continue;
        P2 := PosEx(')', s, P1+1);
        if P2=0 then Continue;
        P3 := PosEx(')', s, P2+1);
        if P3=0 then Continue;
        // als er na positie P3 (in string s) geen '[' tekens komen, is het een Q3-map, anders is het een HL-map
        P1 := PosEx('[', s, P3+1);
        if P1=0 then begin
          // 9 spaties in de string s, na positie P3 ?? dan is het een Q3-map
          Result := MapFormat_Quake3;
          Break;
        end else begin
          //
          Result := MapFormat_HalfLife;
          Break;
        end;
      end;
    until EOF(F);
  finally
    // Sluit het .map bestand
    CloseFile(F);
  end;
  Print_StdOut('MAP-file format: '+ Filename +' is '+ Result);
end;



procedure TLevelMap.DisplayMap(CameraPosition: TVector);
var i,j: integer;
    N,V1,V2,V3: TVector;
    doTexturing, doDrawFace: boolean;
begin
  if not MapLoaded then Exit;

  glDepthFunc(GL_LESS);     //z-buffer 1e gang..(alles wat dichterbij ligt, dan wat al getekend is)
  glDisable(GL_LIGHTING);
  glDisable(GL_BLEND);
  glFrontFace(GL_CCW);
  glCullFace(GL_BACK);
  glEnable(GL_CULL_FACE);
  glPolygonMode(GL_FRONT, GL_FILL);
  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE); //GL_DECAL, GL_MODULATE, GL_REPLACE
(*
  glVertexPointer(3, GL_FLOAT, sizeof(TMapVertex), @Vertices[0].Position);
  glEnableClientState(GL_VERTEX_ARRAY);

  glNormalPointer(GL_FLOAT, sizeof(TMapVertex), @Vertices[0].Normal);
  glEnableClientState(GL_NORMAL_ARRAY);

  glDisableClientState(GL_TEXTURE_COORD_ARRAY);
*)

  // het aantal getekende faces resetten
  N_FacesDrawn := 0;

  // alle faces doorlopen
  for i:=0 to Length(Faces)-1 do begin

    // ligt er 1 punt van de face binnen het frustum?  dan tekenen..
    doDrawFace := false;
    for j:=0 to Faces[i].N_Vertices-1 do begin
      if OGL.Frustum.PointInFrustum(Vertices[Faces[i].startVertIndex+j].Position) then begin
        doDrawFace := true;
        Break;
      end;
    end;

    //alleen tekenen als de face in het frustum is
    if doDrawFace then begin
      Inc(N_FacesDrawn);
//    glDrawArrays(GL_TRIANGLE_FAN, Faces[i].startVertIndex, Faces[i].N_Vertices);
//      glDrawArrays(GL_POLYGON, Faces[i].startVertIndex, Faces[i].N_Vertices);

      // texture
      doTexturing := (Faces[i].TextureIndex > -1);
      if doTexturing then begin
        // opac afbeelden
        glDepthMask(GL_TRUE);
        glDepthFunc(GL_LESS);
        glDisable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE);
        //
        if validTexture(Textures[Faces[i].TextureIndex].Filename) then begin
          glEnable(GL_TEXTURE_2D);
          glBindTexture(GL_TEXTURE_2D, Textures[Faces[i].TextureIndex].Handle);
          // de textured face afbeelden
          glBegin(GL_POLYGON);
            glColor3f(1.0, 1.0, 1.0);
            glNormal3f(Faces[i].Normal.X, Faces[i].Normal.Y, Faces[i].Normal.Z);
            for j:=0 to Faces[i].N_Vertices-1 do begin
              if doTexturing then glTexCoord2f(Vertices[Faces[i].startVertIndex+j].TextureCoord.X, Vertices[Faces[i].startVertIndex+j].TextureCoord.Y);
              glVertex3fv(@Vertices[Faces[i].startVertIndex+j].Position);
            end;
          glEnd;
       {end else begin
          glDisable(GL_TEXTURE_2D);}
        end;

      end else begin
        // transparant afbeelden
        glDepthMask(GL_TRUE);
        glDepthFunc(GL_LEQUAL);
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE_MINUS_SRC_ALPHA, GL_SRC_ALPHA);
        //
        glDisable(GL_TEXTURE_2D);
        glBegin(GL_POLYGON);
          glColor4f(1,1,1, 0.2); //entity kleur
          glNormal3f(Faces[i].Normal.X, Faces[i].Normal.Y, Faces[i].Normal.Z);
          for j:=0 to Faces[i].N_Vertices-1 do begin
            glVertex3fv(@Vertices[Faces[i].startVertIndex+j].Position);
          end;
        glEnd;

      end;

    end;
  end;

  glDepthFunc(GL_LESS);
  glDisable(GL_BLEND);
  glBlendFunc(GL_ONE, GL_ONE);

  glDisableClientState(GL_VERTEX_ARRAY);
  glDisableClientState(GL_NORMAL_ARRAY);
end;









initialization
  LevelMAP := TLevelMap.Create;

finalization
  LevelMAP.Free;

end.


