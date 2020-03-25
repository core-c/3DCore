unit uQuake3BSP;
interface
uses OpenGL, u3DTypes, uFrustum, uCamera, uTexture, StdCtrls{, FormOpenGL};
{$DEFINE SSE_OPCODES} // gebruik SSE routines
{$A8}

// Het bestandsformaat van een Quake3 BSP bestand is te vinden op url:
//   http://www.gametutorials.com/Tutorials/OpenGL/Quake3Format.htm

const
  // de texture die gebruikt wordt om te mappen als de toegewezen texture niet kan worden geladen
  RevertToTexture : string = '-0out_rk3.jpg';

  // Collision Volume typen
  vtRay       = 0;
  vtSphere    = 1;
  vtBox       = 2;
  // BoundingBox
  bbMin     = 0;
  bbMax     = 1;
  bbExtends = 2;
type
  TCollisionTest = record
    Camera: PCamera; //^TCamera;
    //
    CurrentPosition,                                 // de huidige camera-positie
    Movement,                                        // de (gewenste) verplaatsing van de camera
    NextPosition: TVector;                           // de volgende positie na (evt. gecorrigeerde) beweging
    VolumeType: byte;                                // Collision Volume
    Volume: Single;                                  // als VolumeType = ctRay of ctSphere
    BoundingBox: array[bbMin..bbExtends] of TVector; // als VolumeType = ctBox  [Min,Max,Extends]
    //
    StartRatio, EndRatio, TraceRatio,
    StartDistance, EndDistance: extended;
    VStart, VEnd, VCollisionNormal: TVector;
    VCollisionPlaneDistance: single;
    CollisionFaceIndex: integer;
    //
    Colliding, Grounded, TryStepping: boolean;
    MaxStepHeight: single;
  end;

const
  Epsilon = 0.03125;  //best groot nog..(tbv. correctie FP-afrondingsfouten)


const
  // Chunks in 3DS, lumps in Q3BSP..
  q3Entities     = 0;    // Player/object posities, etc...
  q3Textures     = 1;    // Texture info
  q3Planes       = 2;    // Splitting planes
  q3Nodes        = 3;    // BSP nodes
  q3Leafs        = 4;    // Leafs van de nodes
  q3LeafFaces    = 5;    // Leaf's indices naar de faces
  q3LeafBrushes  = 6;    // Leaf's indices naar de brushes
  q3Models       = 7;    // World models info
  q3Brushes      = 8;    // Brushes info (tbv. collision-detection)
  q3BrushSides   = 9;    // Brush surfaces info
  q3Vertices     = 10;   // Level vertices
  q3MeshVerts    = 11;   // Model vertices offsets
  q3Shaders      = 12;   // Shader files (blending, animaties..)
  q3Faces        = 13;   // Faces van de map
  q3Lightmaps    = 14;   // Lightmaps van de map (de ruwe RGB pixeldata voor alle opgenomen lightmaps)
  q3LightVolumes = 15;   // World lighting info
  q3VisData      = 16;   // PVS and cluster info (visibility)
  q3MaxLumps     = 17;   // Aantal lumps


  // Face typen
  ftPolygon   = 1;
  ftPatch     = 2;
  ftMesh      = 3;
  ftBillboard = 4;

  // Texture contents typen
  tcSolid     = 1;
  tcWater     = 2;



type
  TBSPLump = packed record
    Offset : Integer;                      // De offset in de file voor de start van deze lump
    Length : Integer;                      // De lengte in bytes voor deze lump
  end;

  TBSPHeader = packed record
    strID   : array[0..3] of Char;         // Dit moet altijd 'IBSP' zijn..
    Version : Integer;                     // Dit moet $2E zijn voor Quake3 BSP-bestanden
  end;

  TBSPVertex = packed record
    Position      : TVector3f;             // (x, y, z) positie
    TextureCoord  : TVector2f;             // (u, v) texture coordinaten
    LightmapCoord : TVector2f;             // (u, v) lightmap coordinaten
    Normal        : TVector3f;             // (x, y, z) normaal vector
    Color         : array[0..3] of Byte;   // RGBA kleur voor deze vertex
  end;

  TBSPFace = Record
    textureID      : Integer;                  // De index in de texture array
    effect         : Integer;                  // De index voor de effecten (of -1 indien niet gebruikt)
    FaceType       : Integer;                  // 1=polygon, 2=patch, 3=mesh, 4=billboard
    startVertIndex : Integer;                  // De start-index van de 1e face-vertex
    N_Vertices     : Integer;                  // Het aantal vertices van deze face
    meshVertIndex  : Integer;                  // De index van de 1e mesh-vertex
    N_MeshVertices : Integer;                  // Het aantal mesh-vertices
    // lightmap
    lightmapID     : Integer;                  // De texture-index voor de lightmap
    lMapCorner     : Array[0..1] of Integer;   // De lightmap-hoek van de face (in de texture)
    lMapSize       : Array[0..1] of Integer;   // De grootte van de lightmap-sectie
    lMapPos        : TVector3f;                // De 3D-positie van de lightmap
    lMapVecs       : Array[0..1] of TVector3f; // De 3D-ruimte voor s & t unit vectors
    //
    vNormal        : TVector3f;                // De normaal van deze face
    Size           : Array[0..1] of Integer;   // Bezier patch dimensies
  end;

  TBSPTexture = packed record
    TextureName : array[0..63] of Char;    // De naam van de texture, zonder extensie (ASCIIZ)
    flags       : Integer;                 // Surface flags (verder onbekend..)
    contents    : Integer;                 // Content flags (bit 0: 1=solid, 0=non-solid (bv water))
  end;

  TBSPLightmap = array[0..127, 0..127, 0..2] of Byte;   // RGB pixeldata voor een 128x128 texture

  TBSPNode = packed record
    Plane : Integer;                       // De index in de plane-array
    Front : Integer;                       // De child-index voor de front-node
    Back  : Integer;                       // De child-index voor de back-node
    Min   : TVector3i;                     // De boundingbox min positie
    Max   : TVector3i;                     // De boundingbox max positie
  end;

  TBSPLeaf = packed record
    Cluster       : Integer;               // Visibility cluster
    Area          : Integer;               // Area portal
    Min           : TVector3i;             // De boundingbox min positie
    Max           : TVector3i;             // De boundingbox max positie
    LeafFace      : Integer;               // De 1e index in de face-array
    N_LeafFaces   : Integer;               // Het aantal faces voor deze leaf
    LeafBrush     : Integer;               // De 1e index in de brush-array
    N_LeafBrushes : Integer;               // Het aantal brushes voor deze leaf
  end;

  TBSPPlane = packed record
    vNormal : TVector;                     // Plane normaal
    d       : Single;                      // De afstand: plane - oorsprong
  end;

  TBSPVisData = packed record
    N_Clusters      : Integer;             // Het aantal clusters
    BytesPerCluster : Integer;             // Het aantal bytes (8 bits) per cluster-bitset
    pBitSets        : Pointer; //^Byte     // Een pointer naar de cluster-bitsets
  end;

  TBSPBrush = packed record
    BrushSide       : Integer;             // De start-side voor deze brush
    N_BrushSides    : Integer;             // Het aantal brush-sides voor deze brush
    TextureID       : Integer;             // De texture-index voor deze brush
  end;

  TBSPBrushSide = packed record
    Plane     : Integer;                   // De plane-index
    TextureID : Integer;                   // De texture-index
  end;

  TBSPModel = packed record
    Min          : TVector3f;              // De boundingbox min positie
    Max          : TVector3f;              // De boundingbox max positie
    FaceIndex    : Integer;                // De 1e face-index voor het model
    N_Faces      : Integer;                // Het aantal faces in dit model
    BrushIndex   : Integer;                // De 1e brush-index voor dit model
    N_Brushes    : Integer;                // Het aantal brushes in dit model
  end;

  TBSPShader = packed record
    StrName    : array[0..63] of Char;     // De naam van het shader-bestand
    BrushIndex : Integer;                  // De brush-index voor deze shader
    Unknown    : Integer;                  // (In 99% van alle gevallen de waarde: 5)
  end;

  TBSPLights = packed record
    Ambient     : array[0..2] of byte;     // De ambient kleur in RGB
    Directional : array[0..2] of byte;     // De richting-licht kleur in RGB
    Direction   : array[0..1] of byte;     // De richting van het licht: [phi,theta]
  end;


  TQuake3BSP = class(TObject)
    private
      pMemo: TMemo; //tbv. scherm-uitvoer
      //
      N_Vertices     : Integer;             // Het aantal vertices
      N_Faces        : Integer;             // Het aantal faces
      N_Textures     : Integer;             // Het aantal textures
      N_Lightmaps    : Integer;             // Het aantal lightmaps
      N_Nodes        : Integer;             // Het aantal nodes
      N_Leafs        : Integer;             // Het aantal leafs
      N_LeafFaces    : Integer;             // Het aantal leaffaces
      N_Planes       : Integer;             // Het aantal planes
      N_Brushes      : Integer;             // Het aantal brushes
      N_BrushSides   : Integer;             // Het aantal brushsides
      N_LeafBrushes  : Integer;             // Het aantal leafbrushes
      Vertices       : array of TBSPVertex; // Vertices
      Faces          : array of TBSPFace;   // Faces
      BSPTextures    : array of TBSPTexture; // Textures
      TextureIDs     : array of GLuint;     // Texture handles
      LightMapIDs    : array of GLuint;     // LightMap handles
      Nodes          : array of TBSPNode;   // Nodes
      Leafs          : array of TBSPLeaf;   // Leafs
      LeafFaces      : array of integer;    // LeafFaces
      Planes         : array of TBSPPlane;  // Planes
      Clusters       : TBSPVisData;         // Clusters
      ClusterBitSets : array of byte;       // Cluster visibility-bitsets
      FaceDrawn      : array of byte;       // bitset voor markering van reeds getekende faces
      Brushes        : array of TBSPBrush;  // Brushes
      BrushSides     : array of TBSPBrushSide; // BrushSides
      LeafBrushes    : array of integer;    // LeafBrushes (indices in de brush-array)
      // booleans
      MapLoaded,
      DoPointFrame,
      DoWireFrame,
      DoHiddenLineRemoval,
      DoTextures,
      DoLightMaps : Boolean;
      //
      Use_N_TextureUnits: GLuint;           // Het aantal texture-units te gebruiken bij afbeelden
      N_FacesDrawn: integer;                // Het aantal getekende faces (per aanroep: DisplayMap)
      LastLoadedMap: string;                // de bestandsnaam van de laatst geladen map
      local_CurrentLeafNodeIndex: integer;  // de leafnode waarin de camera zich bevindt
      //
      procedure RenderFace(FaceIndex : Integer);
      procedure RenderFaces(CameraPosition: TVector);
      function FindLeaf(Position: TVector) : integer;
      function IsClusterVisible(Current, Test: integer) : Byte;
      // collision detection
      function Trace(VStart,VEnd: TVector) : TVector;
      procedure CheckNode(NodeIndex: integer; StartRatio, EndRatio: Extended; var VStart,VEnd: TVector);
      procedure CheckBrush(BrushIndex: integer; var VStart,VEnd: TVector);
      function TryToStep(var VStart,VEnd: TVector) : TVector;
      function TryToSlide(var VStart,VEnd, PlaneNormal: TVector) : TVector;
    public
      CollisionTest: TCollisionTest;
      //
      constructor Create;
      destructor Destroy; override;
      // Memo output
      procedure Set_StdOut(var aMemo: TMemo);
      procedure Clear_StdOut;
      procedure Print_StdOut(s: string);
      //
      procedure Clear;
      procedure FreeTextures;
      function IsMapLoaded : boolean;
      procedure TextureUnitsToUse(N: GLuint);
      function GetNFaces : integer;
      function GetNFacesDrawn : integer;
      function GetLastLoadedMap : string;
      function GetCurrentLeafNode : integer;
      //
      procedure DrawPointFrame(State: boolean);
      procedure DrawWireFrame(State: boolean);
      procedure DrawHiddenLineRemoval(State: boolean);
      procedure DrawTextures(State: boolean);
      procedure DrawLightMaps(State: boolean);
      function GetPointFrame : boolean;
      function GetWireFrame : boolean;
      function GetHiddenLineRemoval : boolean;
      function GetTextures : boolean;
      function GetLightMaps : boolean;
      procedure TogglePointFrame;
      procedure ToggleWireFrame;
      procedure ToggleHiddenLineRemoval;
      procedure ToggleTextures;
      procedure ToggleLightMaps;
      //
      function  LoadBSP(const Filename : String) : Boolean;
      procedure DisplayMap(CameraPosition: TVector);
      //
      function Collision(NewPosition: TVector) : boolean; //raytracer
      function TraceRay(VStart,VEnd: TVector) : TVector;
      function TraceSphere(VStart,VEnd: TVector; Radius: single) : TVector;
      function TraceBox(VStart,VEnd, VMin,VMax: TVector) : TVector;
  end;


var Quake3BSP : TQuake3BSP;


implementation
uses Windows, SysUtils, uCalc, uLight, Math, mmsystem, uOpenGL;

{ TQuake3BSP }
constructor TQuake3BSP.Create;
begin
  Clear;
  pMemo := nil;
  Use_N_TextureUnits := 1;   //tenminste 1 TU heeft iedereen..
  local_CurrentLeafNodeIndex := -1;
  //
  with CollisionTest do begin
    Colliding := false;
    Grounded := false;
    TryStepping := false;
    MaxStepHeight := 10.0;
    VolumeType := vtRay;
    VCollisionNormal := NullVector;
  end;
  // booleans..
  DoPointFrame := false;
  DoWireFrame := false;
  DoHiddenLineRemoval := false;
  DoTextures := true;
  DoLightMaps := true;
end;

destructor TQuake3BSP.Destroy;
begin
  Clear;
  inherited;
end;


procedure TQuake3BSP.Clear;
begin
  FreeTextures;
  // arrays legen..
  N_Vertices := 0;
  N_Faces := 0;
  N_Textures := 0;
  N_Lightmaps := 0;
  N_Nodes := 0;
  N_Leafs := 0;
  N_LeafFaces := 0;
  N_Planes := 0;
  N_Brushes := 0;
  N_BrushSides := 0;
  N_LeafBrushes := 0;
  SetLength(Vertices, 0);
  SetLength(Faces, 0);
  SetLength(BSPTextures, 0);
  SetLength(TextureIDs, 0);
  SetLength(LightMapIDs, 0);
  SetLength(Nodes, 0);
  SetLength(Leafs, 0);
  SetLength(LeafFaces, 0);
  SetLength(Planes, 0);
  //if Assigned(Clusters.pBitSets) then begin
    SetLength(ClusterBitSets, 0);
    Clusters.pBitSets := nil;
  //end;
  SetLength(FaceDrawn, 0);  //mijn bitset voor afbeelden faces
  SetLength(Brushes, 0);
  SetLength(BrushSides, 0);
  SetLength(LeafBrushes, 0);
  //
  LastLoadedMap := '';
  MapLoaded := false;
end;


{Memo}
procedure TQuake3BSP.Set_StdOut(var aMemo: TMemo);
begin
  pMemo := aMemo;
end;

procedure TQuake3BSP.Clear_StdOut;
begin
  if pMemo <> nil then pMemo.lines.Clear
end;

procedure TQuake3BSP.Print_StdOut(s: string);
begin
  if pMemo <> nil then pMemo.lines.add(s)
end;



procedure TQuake3BSP.FreeTextures;
var i: integer;
begin
	// Textures vrijgeven..
  for i:=0 to N_Textures-1 do OGL.Textures.DeleteTexture(TextureIDs[i]);
  // lightmaps zijn apart aangemaakt (geen texturebestanden aanwezig)
  for i:=0 to N_Lightmaps-1 do OGL.Textures.DeleteTexture(LightMapIDs[i])
end;


procedure TQuake3BSP.DrawPointFrame(State: boolean);
begin
  DoPointFrame := State;
end;
procedure TQuake3BSP.DrawWireFrame(State: boolean);
begin
  DoWireFrame := State;
end;
procedure TQuake3BSP.DrawHiddenLineRemoval(State: boolean);
begin
  DoHiddenLineRemoval := State;
end;
procedure TQuake3BSP.DrawTextures(State: boolean);
begin
  DoTextures := State;
end;
procedure TQuake3BSP.DrawLightMaps(State: boolean);
begin
  DoLightMaps := State;
end;


procedure TQuake3BSP.TogglePointFrame;
begin
  DoPointFrame := not DoPointFrame;
end;
procedure TQuake3BSP.ToggleWireFrame;
begin
  DoWireFrame := not DoWireFrame;
end;
procedure TQuake3BSP.ToggleHiddenLineRemoval;
begin
  DoHiddenLineRemoval := not DoHiddenLineRemoval;
end;
procedure TQuake3BSP.ToggleTextures;
begin
  DoTextures := not DoTextures;
end;
procedure TQuake3BSP.ToggleLightMaps;
begin
  DoLightMaps := not DoLightMaps;
end;


function TQuake3BSP.GetPointFrame: boolean;
begin
  Result := DoPointFrame;
end;
function TQuake3BSP.GetWireFrame: boolean;
begin
  Result := DoWireFrame;
end;
function TQuake3BSP.GetHiddenLineRemoval: boolean;
begin
  Result := DoHiddenLineRemoval;
end;
function TQuake3BSP.GetTextures: boolean;
begin
  Result := DoTextures;
end;
function TQuake3BSP.GetLightMaps: boolean;
begin
  Result := DoLightMaps;
end;



function TQuake3BSP.IsMapLoaded: boolean;
begin
  Result := MapLoaded;
end;

function TQuake3BSP.GetLastLoadedMap: string;
begin
  Result := LastLoadedMap;
end;

procedure TQuake3BSP.TextureUnitsToUse(N: GLuint);
begin
  Use_N_TextureUnits := N;
end;

function TQuake3BSP.GetNFaces: integer;
begin
  Result := Length(Faces);
end;

function TQuake3BSP.GetNFacesDrawn: integer;
begin
  Result := N_FacesDrawn;
end;

function TQuake3BSP.GetCurrentLeafNode: integer;
begin
  Result := local_CurrentLeafNodeIndex;
end;







function TQuake3BSP.LoadBSP(const Filename: String): Boolean;
var F : File;
    I, J, ITemp : Integer;
    Temp : glFloat;
    Header : TBSPHeader;
    Lumps  : Array of TBSPLump;
    LightMaps : Array of TBSPLightmap;
    s,sTemp : string;
    V: TVector;
    tmpV: TBSPVertex;
begin
  MapLoaded := false;
  result := false;

  // Controleer of het .bsp bestand ge-opend kan worden
  AssignFile(F, FileName);
  {$I-}
  Reset(F,1);
  {$I+}
  if IOResult <> 0 then begin
    //MessageBox(0, 'BSP niet gevonden!', 'Error', MB_OK);
    Exit;
  end;
  Print_StdOut('BSP-file: '+ Filename);

  //=== Alle info lezen over opgeslagen gegevens en geheugen alloceren =========

  SetLength(Lumps, q3MaxLumps);
  // Lees de header & lump-data
  BlockRead(F, Header, Sizeof(Header));
  BlockRead(F, Lumps[0], q3MaxLumps*sizeof(TBSPLump));

  // Alloceer geheugen voor de vertices
  N_Vertices := Round(lumps[q3Vertices].length / sizeof(TBSPVertex));
  SetLength(Vertices, N_Vertices);
  Print_StdOut('N_Vertices: '+ IntToStr(N_Vertices));

  // Alloceer geheugen voor de faces
  N_Faces := Round(lumps[q3Faces].length / sizeof(TBSPFace));
  SetLength(Faces, N_Faces);
  Print_StdOut('N_Faces: '+ IntToStr(N_Faces));

  // Alloceer geheugen voor de texture-info
  N_Textures := Round(lumps[q3Textures].length / sizeof(TBSPTexture));
  SetLength(BSPTextures, N_Textures);
  SetLength(TextureIDs, N_Textures);
  Print_StdOut('N_Textures: '+ IntToStr(N_Textures));

  // Alloceer geheugen voor de lightmap-data.
	N_Lightmaps := Round(lumps[q3Lightmaps].length / sizeof(tBSPLightmap));
  SetLength(LightMapIDs, N_Lightmaps);
  SetLength(LightMaps, N_Lightmaps);
  if N_Lightmaps = 0 then DrawLightMaps(false)
                     else DrawLightMaps(true);
  Print_StdOut('N_LightMaps: '+ IntToStr(N_Lightmaps));

  // Alloceer geheugen voor de nodes
  N_Nodes := Round(lumps[q3Nodes].length / sizeof(tBSPNode));
  SetLength(Nodes, N_Nodes);
  Print_StdOut('N_Nodes: '+ IntToStr(N_Nodes));

  // Alloceer geheugen voor de leafs
  N_Leafs := Round(lumps[q3Leafs].length / sizeof(tBSPLeaf));
  SetLength(Leafs, N_Leafs);
  Print_StdOut('N_Leafs: '+ IntToStr(N_Leafs));

  // Alloceer geheugen voor de leaf-faces
  N_LeafFaces := Round(lumps[q3LeafFaces].length / sizeof(integer));
  SetLength(LeafFaces, N_LeafFaces);
  Print_StdOut('N_LeafFaces: '+ IntToStr(N_LeafFaces));

  // Alloceer geheugen voor de planes
  N_Planes := Round(lumps[q3Planes].length / sizeof(TBSPPlane));
  SetLength(Planes, N_Planes);
  Print_StdOut('N_Planes: '+ IntToStr(N_Planes));

  // Alloceer geheugen voor de brushes
  N_Brushes := Round(lumps[q3Brushes].length / sizeof(TBSPBrush));
  SetLength(Brushes, N_Brushes);
  Print_StdOut('N_Brushes: '+ IntToStr(N_Brushes));

  // Alloceer geheugen voor de brushsides
  N_BrushSides := Round(lumps[q3BrushSides].length / sizeof(TBSPBrushSide));  //!!
  SetLength(BrushSides, N_BrushSides);
  Print_StdOut('N_BrushSides: '+ IntToStr(N_BrushSides));

  // Alloceer geheugen voor de leafbrushes
  N_LeafBrushes := Round(lumps[q3LeafBrushes].length / sizeof(integer));
  SetLength(LeafBrushes, N_LeafBrushes);
  Print_StdOut('N_LeafBrushes: '+ IntToStr(N_LeafBrushes));


  //=== data lezen in de rereserveerde ruimte ==================================

  // Zoek de bestands-positie voor de vertex-data
  Seek(F, lumps[q3Vertices].offset);
  // Alle vertices inlezen en verwissel assen
  for I :=0 to N_Vertices-1 do begin
    // Lees de huidige vertex
    BlockRead(F, Vertices[i], sizeOf(TBSPVertex));
    // Verwissel de y & z waarden, en wissel de nieuwe z-waarde van teken/sign (Y moet omhoog)
    Temp := Vertices[i].Position.Y;
    Vertices[i].Position.Y := Vertices[i].Position.Z;
    Vertices[i].Position.Z := -Temp;
    // Wissel de t texture-coordinaat (anders zal de texture op z'n kop komen)
    Vertices[i].TextureCoord.Y := -Vertices[i].TextureCoord.Y;
  end;

  // Zoek de bestands-positie voor de face-data
  Seek(F, lumps[q3Faces].offset);
  BlockRead(F, Faces[0], N_Faces*sizeOf(TBSPFace));

  // Zoek de bestands-positie voor de texture-data
  Seek(F, lumps[q3Textures].offset);
  BlockRead(F, BSPTextures[0], N_Textures*sizeOf(TBSPTexture));
  // Alle textures doorlopen..
  for I:=0 to N_Textures-1 do begin
    // ..Texture namen worden blijkbaar zonder extensie opgeslagen in de bsp
    s := BSPTextures[i].TextureName;
    sTemp := 'Texture['+ IntToStr(i) +']: '+ s;
    if OGL.Textures.FindTexture(s) then
      TextureIDs[i] := OGL.Textures.LoadTexture(s, 1.0)
    else begin
      s := RevertToTexture;
      if OGL.Textures.FindTexture(s) then
        TextureIDs[i] := OGL.Textures.LoadTexture(s, 1.0)
      else
        TextureIDs[i] := 0;
    end;
    if TextureIDs[i] <> 0 then Print_StdOut(sTemp +' -> '+ s);
  end;

  // Zoek de bestands-positie voor de lightmap-data
  Seek(F, lumps[q3Lightmaps].offset);
  BlockRead(F, LightMaps[0], N_Lightmaps*sizeOf(tBSPLightmap));
  OGL.Textures.Set_GammaFactor(5.0);
	// Alle lightmaps doorlopen..
  for I:=0 to N_Lightmaps-1 do begin
    // Een texture aanmaken met de gelezen lightmap-pixeldata (altijd 128x128)
    LightMapIDs[i] := OGL.Textures.TextureFromPixelData(128,128, GL_RGB,GL_RGB, true, @LightMaps[i]);
    {Textures.SaveToFile(@LightMaps[i], 128,128, GL_RGB, 'c:\Lightmap.bmp');}
  end;
	// De pixeldata kan weer weg; De textures voor de lightmaps zijn aangemaakt..
  SetLength(LightMaps, 0);
  OGL.Textures.Set_GammaFactor(1.0);

  // Zoek de bestands-positie voor de node-data
  Seek(F, lumps[q3Nodes].offset);
  BlockRead(F, Nodes[0], N_Nodes*sizeOf(tBSPNode));

  // Zoek de bestands-positie voor de leaf-data
  Seek(F, lumps[q3Leafs].offset);
  BlockRead(F, Leafs[0], N_Leafs*sizeOf(tBSPLeaf));
  // Alle leafs doorlopen en assen verwisselen voor de boundingboxes
  for i:=0 to N_Leafs-1 do begin
    // Verwissel de y & z waarden, en wissel de nieuwe z-waarde van teken/sign (Y moet omhoog)
    with Leafs[i] do begin
      ITemp := Min.Y;
      Min.Y := Min.Z;
      Min.Z := -ITemp;
    end;
		// ook voor de (max) boundingbox-punten..
    with Leafs[i] do begin
      ITemp := Max.Y;
      Max.Y := Max.Z;
      Max.Z := -ITemp;
    end;
  end;

  // Zoek de bestands-positie voor de leafface-data
  Seek(F, lumps[q3LeafFaces].offset);
  BlockRead(F, LeafFaces[0], N_LeafFaces*sizeOf(integer));

  // Zoek de bestands-positie voor de plane-data
  Seek(F, lumps[q3Planes].offset);
  BlockRead(F, Planes[0], N_Planes*sizeOf(TBSPPlane));
	// Doorloop alle planes..
  for i:=0 to N_Planes-1 do
    // Verwissel de y & z waarden, en wissel de nieuwe z-waarde van teken/sign (Y moet omhoog)
    with Planes[i] do begin
      Temp := vNormal.Y;
      vNormal.Y := vNormal.Z;
      vNormal.Z := -Temp;
    end;

  // Zoek de bestands-positie voor de visibility-data
  Seek(F, lumps[q3VisData].offset);
  // Controleer eerst of er wel visibility-info is..
  if lumps[q3VisData].Length > 0 then begin
    // Lees het aantal clusters en de grootte per cluster
    BlockRead(F, Clusters.N_Clusters, sizeOf(integer));
    BlockRead(F, Clusters.BytesPerCluster, sizeOf(integer));
    // Alloceer geheugen voor de cluster-bitsets
    ITemp := Clusters.N_Clusters * Clusters.BytesPerCluster;
    SetLength(ClusterBitSets, ITemp);
    Clusters.pBitSets := @ClusterBitSets[0];  //pointer zetten in het visdata-record
    // Alle visibility-bitsets voor de clusters inlezen
    BlockRead(F, ClusterBitSets[0], ITemp);
    Print_StdOut('N_Clusters: '+ IntToStr(Clusters.N_Clusters));
    Print_StdOut('N_BytesPerClusters: '+ IntToStr(Clusters.BytesPerCluster));
  end else begin
    // Er is geen visibility-data aanwezig in de bsp
    Clusters.pBitSets := nil;
    Print_StdOut('No visibility data');
  end;

  // Zoek de bestands-positie voor de brush data
  Seek(F, lumps[q3Brushes].offset);
  BlockRead(F, Brushes[0], N_Brushes*sizeOf(TBSPBrush));

  // Zoek de bestands-positie voor de brush-sides data
  Seek(F, lumps[q3BrushSides].offset);
  BlockRead(F, BrushSides[0], N_BrushSides*sizeOf(TBSPBrushSide));

  // Zoek de bestands-positie voor de leafbrushes data
  Seek(F, lumps[q3LeafBrushes].offset);
  BlockRead(F, LeafBrushes[0], N_LeafBrushes*sizeOf(integer));

  // Sluit het .bsp bestand
  CloseFile(F);

  // Alloceer geheugen voor de bitset voor markering reeds getekende faces
  SetLength(FaceDrawn, (N_Faces div 8 + 1));  //misschien 1 byte teveel (niet erg)    if (N_Faces mod 8)>0 1 erbij

  SetLength(Lumps, 0);
  LastLoadedMap := Filename;
  MapLoaded := true;
  result := true;
end;





function TQuake3BSP.FindLeaf(Position: TVector): integer;
  // Deze functie zoekt de leaf-node waarin de opgegeven Position zich bevindt,
  // (bv. de camera- of player-positie).
  // Alle BSP-nodes worden doorlopen, beginnend vanaf de bsp root-node, waarbij
  // voor elke node wordt getest of de Position zich bevindt VOOR of ACHTER de
  // geteste node's splitting-plane.
  // Als Position zich bevindt VOOR de node, dan wordt de volgende te testen node getest,
  // de node die VOOR de huidige node ligt (die info is al in de BSP opgeslagen).
  // Als Position ACHTER de node valt, testen we de back-node van de huidige node.
  // Als er een node-index (i) is gevonden die een NEGATIEF nummer oplevert, wil dat
  // zeggen dat we de index van een andere leaf-node te pakken hebben (niet een
  // andere BSP-node). De daadwerkelijke leafnode-index is dan te berekenen met
  // de formule -(i+1), of mbv. een binaire NOT op een integer, wat hetzelfde oplevert.
  // (De index-nummers beginnen nl. vanaf 0 en zijn nooit negatief..).
  // Uiteindelijk wordt zo de leaf-node gevonden waarin Position zich bevindt.
  // Als de leaf-node eenmaal is gevonden kan direct worden gelezen (uit BSP)
  // in welke CLUSTER Position valt.
  // Mbv. de cluster visibility-bitsets kan dan worden bepaald welke andere clusters
  // er zichtbaar zijn vanaf de gevonden cluster.

var i: integer;
    distance: Single;
    Node: ^TBSPNode;
    Plane: ^TBSPPlane;
(*
{$ALIGN 4}
testje:array[0..3] of single;
AdrTestje:pointer;
d:single;
*)
begin
  i := 0;
	// Doorgaan met zoeken totdat er een negatieve index wordt gevonden..
  // Een negatieve index verwijst naar een LeafNode.
  // (tot nu toe met de huidige maps wordt de lus hooguit 20x uitgevoerd)
  while i>=0 do begin
    // Bepaal de huidige node, en lees daarna de node's splitter-plane mbv. de
    // node.plane index.
    Node := @Nodes[i];
    Plane := @Planes[Node.Plane];
    // Gebruik de wiskundige vergelijking voor een vlak om uit te zoeken of
    // de opgegeven Position zich bevindt VOOR of ACHTER de splitter-plane.
    // De vergelijking voor een vlak: (Ax + By + Cz + D = 0) waarbij geldt:
    // D is de afstand vlak-oorsprong.
    // Als de uitkomst = 0 dan ligt Position precies op het vlak.
    // Als de uitkomst < 0 dan ligt Position ACHTER het vlak.
    // Als de uitkomst > 0 dan ligt Position VOOR het vlak.
    distance := DotProduct(Plane.vNormal, Position)- Plane.d;
		// Als Position op of voor het vlak ligt..
    if distance >= 0 then
      // ..Zoek verder vanaf de node die ligt voor de huidige node
      i := Node.Front
    else // Als Position achter het vlak ligt..
      // ..Zoek verder vanaf de node die ligt achter de huidige node
      i := Node.Back;
  end;
	// Resulteer de  leaf-index
  Result := (not i);  //-(i+1);
end;




function TQuake3BSP.IsClusterVisible(Current, Test: integer): Byte;
  // Deze functie test of een cluster(Test) kan worden gezien vanuit de cluster(Current).
  // Het resultaat van deze functie is een byte die de waarde 0 heeft als de
  // geteste cluster NIET zichtbaar is vanuit de huidige (anders 1 voor wel zichtbaar).
  // Elke cluster heeft een bitset (ookwel vector genoemd ooit.. lekker handig)
  // met daarin een bit voor elke andere cluster in de bsp. Een bit op 1 wil (dus)
  // zeggen dat een cluster zichtbaar is vanuit de huidige cluster (0 is onzichtbaar).
  // Als een map bv. 11 clusters heeft gedefiniëerd, heeft elke cluster dus een bitset
  // met daarin 11 bits, voor een verwijzing naar elke andere cluster.
var AddrClusterBitSet: Pointer;
begin
  // test of er wel cluster visibility-bitsets zijn gedefiniëerd in de bsp..
  // De huidige cluster-index moet ook >0 zijn..
  // Indien niet aan deze voorwaarden wordt voldaan een 1 resulteren (voor zichtbaar).
  if (not Assigned(Clusters.pBitSets)) or (Current<0) then begin
    Result := 1;
    Exit;
  end;
  // Lees bit(Test) uit de bitset voor cluster(Current)
  // Alle bitsets zijn evenlang (Clusters.BytesPerCluster) en staan direct achter elkaar
  // in het geheugen. Bepaal eerst het basis-adres voor cluster(Current), en lees
  // vanaf dat adres het "Test'de" bit..
  AddrClusterBitSet := @ClusterBitSets[Current*Clusters.BytesPerCluster];  // Clusters.pBitSets + (Current*Clusters.BytesPerCluster)
  asm
    mov   eax, AddrClusterBitSet            // eax = basis-adres BitSet voor Cluster[Current]
    mov   ecx, Test
    bt    [eax], ecx                        // BitTest: bit ecx vanaf [eax], resultaat in carry-flag
    setc  Result                            // carry naar functie-resultaat (byte waarde: 0 of 1)
  end;
end;





procedure TQuake3BSP.RenderFace(FaceIndex: Integer);
var Face: ^TBSPFace;
begin
  // De face met index FaceIndex benaderen
  Face := @Faces[FaceIndex];

  // het aantal texture-units bepaalt het aantal tekengangen
  if Use_N_TextureUnits = 1 then begin //=== 1 TEXTURE UNIT GEBRUIKEN ==============

    //--- Hidden-line removal
    if DoHiddenLineRemoval then begin
      //1e pass
//      glDisableClientState(GL_TEXTURE_COORD_ARRAY);
      glEnable(GL_DEPTH_TEST);
      glPolygonMode(GL_BACK, GL_LINE);
      glColor3f(1.0, 1.0, 1.0); //witte lijnen..
      glDisable(GL_TEXTURE_2D);
      glDisable(GL_BLEND);
      glDrawArrays(GL_TRIANGLE_FAN, Face.startVertIndex, Face.N_Vertices);
      //2e pass
      glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
      glPolygonMode(GL_BACK, GL_FILL);
      glEnable(GL_POLYGON_OFFSET_FILL);
      glPolygonOffset(1.0, 1.0);
      glColor3f(0.0, 0.0, 0.0); //..op een zwarte achtergrond
      glDrawArrays(GL_TRIANGLE_FAN, Face.startVertIndex, Face.N_Vertices);
      glDisable(GL_POLYGON_OFFSET_FILL);
      glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
      Exit;
    end;

    //--- Wire/Point-Frames
    if DoWireFrame then begin
      glPolygonMode(GL_BACK, GL_LINE);
      //glDisable(GL_CULL_FACE);
    end else begin
      glPolygonMode(GL_BACK, GL_FILL);
      //glEnable(GL_CULL_FACE);
    end;

    //--- Texturing ---
    if DoTextures then begin
      glEnable(GL_TEXTURE_2D);
      glDepthFunc(GL_LESS);     //z-buffer 1e gang..(alles wat dichterbij ligt, dan wat al getekend is)
      glDisable(GL_BLEND);
      if TextureIDs[Face.textureID]>0 then begin
        glBindTexture(GL_TEXTURE_2D, TextureIDs[Face.textureID]);
        // De (materiaal)texture coordinaten aanleveren..
        glTexCoordPointer(2, GL_FLOAT, sizeof(TBSPVertex), @Vertices[0].TextureCoord);
      end else begin
        glDisable(GL_TEXTURE_2D);
      end;
    end else begin
      glDisable(GL_TEXTURE_2D);
    end;
    //tekenen 1e gang..
    glDrawArrays(GL_TRIANGLE_FAN, Face.startVertIndex, Face.N_Vertices);

    //--- LightMaps ---
    if DoLightMaps then begin
      //tekenen 2e gang..
      glEnable(GL_TEXTURE_2D);
      {glDepthMask(GL_FALSE);   //read-only diepte-buffer}
      glDepthFunc(GL_LEQUAL);   //z-buffer 2e gang..(alles wat evenver of dichterbij ligt..)
      glEnable(GL_BLEND);       //mix de lightmap met de reeds getekende texture
      glBlendFunc(GL_DST_COLOR, GL_SRC_COLOR); //een lightmap heeft geen alpha-kanaal, dus alleen kleuren mixen
      glBindTexture(GL_TEXTURE_2D, LightMapIDs[Face.lightmapID]);
      // De (lightmap)texture coordinaten aanleveren..
      glTexCoordPointer(2, GL_FLOAT, sizeof(TBSPVertex), @Vertices[0].LightmapCoord);
      //tekenen 2e gang
      glDrawArrays(GL_TRIANGLE_FAN, Face.startVertIndex, Face.N_Vertices);
      //
      glDisable(GL_BLEND);
    end else begin
      glDisable(GL_TEXTURE_2D);
    end;

    //--- Wire/Point-Frames
    // Eventueel nog (witte) punten tekenen in een aparte gang (2e of 3e)..
    if DoPointFrame then begin
      glDisable(GL_BLEND);
      glDisable(GL_TEXTURE_2D);
      {glDisableClientState(GL_TEXTURE_COORD_ARRAY);}
      glPolygonMode(GL_BACK, GL_POINT);
      glColor3f(1.0, 1.0, 0.0);  //gele punten..
      glDrawArrays(GL_TRIANGLE_FAN, Face.startVertIndex, Face.N_Vertices);
      glColor3f(1.0, 1.0, 1.0);
      glPolygonMode(GL_BACK, GL_FILL);
    end;

  end else begin //=== 2 TEXTURE UNITS GEBRUIKEN ===============================
    //--- LightMaps ---
    // De lightmap wordt getekend door texture-unit(1)
    glActiveTextureARB(GL_TEXTURE1_ARB);
    if DoLightMaps then begin
      glEnable(GL_TEXTURE_2D);
      // De lightmap als huidige texture gebruiken voor de face
      glBindTexture(GL_TEXTURE_2D,  LightMapIDs[Face.lightmapID]);
    end else begin
      // Geen lightmaps tekenen, dus texturing uitschakelen voor texture-unit(1)
      glDisable(GL_TEXTURE_2D);
    end;
    //--- Texturing ---
    // De (materiaal)texture wordt getekend door texture-unit(0)
    glActiveTextureARB(GL_TEXTURE0_ARB);
    if DoTextures then begin
      if TextureIDs[Face.textureID]>0 then begin
        glEnable(GL_TEXTURE_2D);
        // De (materiaal)texture als huidige texture gebruiken voor de face
        glBindTexture(GL_TEXTURE_2D, TextureIDs[Face.textureID]);
      end else
        glDisable(GL_TEXTURE_2D);
    end else begin
      // Geen (materiaal)textures tekenen, dus texturing uitschakelen voor texture-unit(0)
      glDisable(GL_TEXTURE_2D);
    end;
    // Teken de face als een triangle-fan, beginnend met de Face.startVertex,
    // over face.N_Vertices vertices.
    glDrawArrays(GL_TRIANGLE_FAN, Face.startVertIndex, Face.N_Vertices);
  end;
end;





procedure TQuake3BSP.RenderFaces(CameraPosition: TVector);
label FaceIsDrawn;
var i,lfi: integer;
    LeafIndex,
    Cluster,
    FaceIndex: integer;
    Leaf: ^TBSPLeaf;
    AddrFaceDrawn: Pointer;
    {BoolFaceDrawn: Byte;}
    BoundingBox: TBoundingBox;
begin
  N_FacesDrawn := 0;  //het aantal getekende faces bijhouden
(*
  //  methode 1
  // Alle faces in de hele bsp doorlopen en afbeelden.
  // Zonder verder enige (optimalisatie)test..
  i := N_Faces;
  while i > 0 do begin
    Dec(I);
    // Teken wel alleen de faces die iets zichtbaars opleveren..
    if Faces[i].Facetype = ftPolygon then RenderFace(i);
    if Faces[i].Facetype = ftMesh then RenderFace(i);  //test..
    //if Faces[i].Facetype = ftBillboard then RenderFace(i);
  end;
*)
  // methode 2
  // Doorloop leafs ipv. alle faces van de bsp.
  // De functie FindLeaf() levert de huidige leaf-index voor de opgegeven (camera-)positie.
  // Met de gevonden leaf-index is dan weer de cluster-index te lezen uit de bsp.
  // Met de gevonden cluster-index is dan weer de visibility-bitset voor die cluster
  // te lezen uit de bsp. De vis-bitset van een cluster bevat de info over de
  // zichtbaarheid van alle andere clusters vanuit die cluster.
  // Als een leaf-cluster zichtbaar is vanuit de huidige cluster, worden alle
  // faces van dat leaf getekend.
  // Een verdere optimalisatie zou zijn om de leaf-boundingbox te testen tegen
  // de frustum-boundingbox. Als de leaf-boundingbox helemaal buiten het frustum
  // valt, dan hoeft niets te worden getekend.

  // Achterhaal de leaf-index van de leaf waarin de camera zich bevindt
  LeafIndex := FindLeaf(CameraPosition);
  local_CurrentLeafNodeIndex := LeafIndex; //lokaal bewaren..
  // lees de cluster waarin deze leaf is opgenomen
  Cluster := Leafs[LeafIndex].Cluster;
  // Doorloop alle leafs van de gevonden cluster en test de zichtbaarheid van de
  // leafs vanuit de gevonden cluster.
  for i:=0 to N_Leafs-1 do begin
		// Het te testen leaf
    Leaf := @Leafs[i];
    // Als het leaf niet zichtbaar is vanuit de cluster, dan het volgende leaf testen..
    if IsClusterVisible(Cluster, Leaf.Cluster)=0 then Continue;
(*
    // Als het leaf niet zich niet in het frustum bevindt, dan het volgende leaf testen..
    BoundingBox.Min.X := 1.0*Leaf.Min.X;
    BoundingBox.Max.X := 1.0*Leaf.Max.X;
    BoundingBox.Min.Y := 1.0*Leaf.Min.Y;
    BoundingBox.Max.Y := 1.0*Leaf.Max.Y;
    BoundingBox.Min.Z := 1.0*Leaf.Min.Z;
    BoundingBox.Max.Z := 1.0*Leaf.Max.Z;
    if not Frustum.BoxInFrustum(BoundingBox) then Continue;
*)
    // Het leaf moet dus nu zichtbaar zijn vanuit de camera-positie.
    // Nu alle leaf-faces doorlopen en afbeelden..
    for lfi:=0 to Leaf.N_LeafFaces-1 do begin
      // de huidige face-index lezen uit de leaffaces-array
      FaceIndex := LeafFaces[Leaf.LeafFace + lfi];
      // Alleen gewone polygons tekenen..
      if not (Faces[FaceIndex].Facetype = ftPolygon) then Continue;  //ftMesh, ftBillboard
      // Omdat er veel faces zijn die ook voorkomen in andere leafs, moeten we er
      // voor zorgen dat diezelfde face maar 1 keer wordt getekend.
      // Daarvoor gebruik ik ook een bitset (een bit voor elke bestaande face)
      AddrFaceDrawn := @FaceDrawn[0];
      asm
        mov   eax, AddrFaceDrawn
        mov   ecx, FaceIndex
        bts   [eax], ecx                        // BitTest en Set: bit ecx vanaf [eax], resultaat in carry-flag
        jc    FaceIsDrawn
       {setc  BoolFaceDrawn                     // carry naar BoolFaceDrawn (byte-waarde: 0 of 1)}
      end;
      // Als het bit nog niet was gezet, dan nu de face afbeelden.
      // (inmiddels is het bit ook gezet mbv de bts opcode)
      {if BoolFaceDrawn=0 then begin}
        RenderFace(FaceIndex);
        Inc(N_FacesDrawn);                      //het aantal getekende faces verhogen
      {end;}
      asm
        FaceIsDrawn:
      end;
    end;
  end;
end;





procedure TQuake3BSP.DisplayMap(CameraPosition: TVector);
var N : Integer;
begin
  if not MapLoaded then Exit;
  N := Use_N_TextureUnits;

  glFrontFace(GL_CCW);
  glCullFace(GL_FRONT);
  glEnable(GL_CULL_FACE);
  glDisable(GL_LIGHTING);
  glPointSize(6.0);  //tbv pointframes
  glColor3f(1,1,1);

  // bij wire/point-frames altijd 1 TU gebruiken..
  if (DoWireFrame or DoPointFrame or DoHiddenLineRemoval) then begin
    N := Use_N_TextureUnits;
    //forceren in 2 gangen te tekenen
    Use_N_TextureUnits := 1;
  end;

  // het aantal texture-units bepaalt het aantal tekengangen
  if Use_N_TextureUnits = 1 then begin //=== 1 TEXTURE UNIT GEBRUIKEN ==============
    if DoTextures or DoLightMaps then begin
      glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
      glEnableClientState(GL_TEXTURE_COORD_ARRAY)
    end else begin
      glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    end;
  end else begin //=== 2 TEXTURE UNITS GEBRUIKEN ===============================
    // De lightmap wordt getekend door texture-unit(1)
    glClientActiveTextureARB(GL_TEXTURE1_ARB);
    if DoLightMaps then begin
      glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
      // De (lightmap)texture coordinaten aanleveren..
      glTexCoordPointer(2, GL_FLOAT, sizeof(TBSPVertex), @Vertices[0].LightmapCoord);
      glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    end else
      glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    // De (materiaal)texture wordt getekend door texture-unit(0)
    glClientActiveTextureARB(GL_TEXTURE0_ARB);
    if DoTextures then begin
      glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
      // De (materiaal)texture coordinaten aanleveren..
      glTexCoordPointer(2, GL_FLOAT, sizeof(TBSPVertex), @Vertices[0].TextureCoord);
      glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    end else
      glDisableClientState(GL_TEXTURE_COORD_ARRAY);
  end;
  // glClientState instellen voor OpenGL vertices-coordinaten arrays
  glVertexPointer(3, GL_FLOAT, sizeof(TBSPVertex), @Vertices[0].Position);
  glEnableClientState(GL_VERTEX_ARRAY);

  // De bitset voor markering van reeds getekende faces resetten (allemaal nog niet getekend)
  ZeroMemory(@FaceDrawn[0], Length(FaceDrawn));

  // Alle faces tekenen die moeten worden getekend
  RenderFaces(CameraPosition);

  //aantal te gebruiken texture-units herstellen (indien van toepassing)..
  if (DoWireFrame or DoPointFrame or DoHiddenLineRemoval) then Use_N_TextureUnits := N;

  if Use_N_TextureUnits > 1 then begin //=== 2 TEXTURE UNITS
    glActiveTextureARB(GL_TEXTURE1_ARB); //selecteer texture unit 1
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    glDepthFunc(GL_LESS);
    glDisable(GL_BLEND);
    //glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
    glDisable(GL_TEXTURE_2D);
    glActiveTextureARB(GL_TEXTURE0_ARB); //selecteer texture unit 0
  end;
  glDisable(GL_BLEND);
  glDepthFunc(GL_LESS);
  //glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
  glDisable(GL_TEXTURE_2D);
  glDisableClientState(GL_TEXTURE_COORD_ARRAY);

  glDisableClientState(GL_VERTEX_ARRAY);

  glPolygonMode(GL_FRONT, GL_FILL);
  glFrontFace(GL_CCW);
  glCullFace(GL_BACK);
  glEnable(GL_CULL_FACE);
  {glDepthMask(GL_TRUE);      //writable depte-buffer}

  {if Lights.Enabled then glEnable(GL_LIGHTING) else glDisable(GL_LIGHTING);}
end;






//--- Collision Detection ------------------------------------------------------

// dit is mijn ray-trace collision-test
function TQuake3BSP.Collision(NewPosition: TVector) : boolean;
// Nodig: LeafIndex van de leaf waarin de camera/player zich bevindt. (-> brushes)
//        Richting en snelheid van beweging van de camera/player.
// !NB: distance<0 en distance>0 check is net andersom als quake3 CW triangles gebruikt..
var LeafIndex: integer;
    Leaf: ^TBSPLeaf;
    Brush: ^TBSPBrush;
    i: integer;
begin
  Result := false;
  // Achterhaal de leaf-index van de leaf waarin de camera zich bevindt na beweging..
  LeafIndex := FindLeaf(NewPosition);
  Leaf := @Leafs[LeafIndex];
  // Doorloop alle brushes van dit leaf..
  for i:=0 to Leaf.N_LeafBrushes-1 do begin
    Brush := @Brushes[LeafBrushes[Leaf.LeafBrush + i]];
    // Heeft de brush wel zijden? en is de zijde wel solid?..
    if (Brush.N_BrushSides > 0) and ((BSPTextures[Brush.TextureID].contents and tcSolid)<>0) then begin
//    if (Brush.N_BrushSides > 0) and ((BSPTextures[Brush.TextureID].contents and tcWater)<>0) then begin
      // Als het camera-oogpunt in een brush komt (met een solid texture.contents)
      // dan is er een botsing. auw!
      result := true;
      Exit;
    end;
  end;
end;








function TQuake3BSP.TryToStep(var VStart, VEnd: TVector): TVector;
var Height: single;
    VStepStart, VStepEnd, VStepPosition: TVector;
begin
  Height := 1.0;
  while Height <= CollisionTest.MaxStepHeight do begin
    {CollisionTest.Grounded := false;}
    CollisionTest.Colliding := false;
    CollisionTest.TryStepping := false;
    VStepStart := Vector(VStart.X, VStart.Y+Height, VStart.Z);
    VStepEnd := Vector(VEnd.X, VStepStart.Y, VEnd.Z);
    VStepPosition := Trace(VStepStart, VStepEnd);
    if not CollisionTest.Colliding then begin
      Result := VStepPosition;
      Exit;
    end;
    Height := Height + 1.0;
  end;
  Result := VStart;  //geen opstapje..
end;


function TQuake3BSP.TryToSlide(var VStart,VEnd, PlaneNormal: TVector): TVector;
var Movement, NewPosition: TVector;
    distance: single;
begin
  Movement := SubVector(VEnd, VStart);
  distance := DotProduct(Movement, PlaneNormal);
  NewPosition := SubVector(VEnd, ScaleVector(PlaneNormal, distance));
  Result := Trace(VStart, NewPosition);
end;



function TQuake3BSP.Trace(VStart, VEnd: TVector) : TVector;
var NewPosition: TVector;
begin
  CollisionTest.TraceRatio := 1.0;
  CheckNode(0, 0.0,1.0, VStart,VEnd);    // begin bij de root-node(0) van de BSP-tree
  if CollisionTest.TraceRatio = 1.0 then // geen botsing
    Result := VEnd
  else begin //botsing!
    // de "nieuwe" positie op het vlak van botsing
    NewPosition := AddVector(VStart, ScaleVector(SubVector(VEnd, VStart), CollisionTest.TraceRatio));
    // het glijden langs de vlakken (in geval van een botsing).
    if (CollisionTest.VolumeType <> vtRay) and CollisionTest.Colliding then
      NewPosition := TryToSlide(NewPosition, VEnd, CollisionTest.VCollisionNormal);
    //
    with CollisionTest do
      Grounded := (Grounded or (Colliding and (VCollisionNormal.Y > 0.2)));
    //
    Result := NewPosition;
  end;
end;

function TQuake3BSP.TraceRay(VStart, VEnd: TVector): TVector;
begin
  CollisionTest.Colliding := false;
  CollisionTest.Grounded := false;
  CollisionTest.TryStepping := false;
  //
  CollisionTest.VolumeType := vtRay;
  CollisionTest.Volume := 0.0;
  Result := Trace(VStart, VEnd);
end;

function TQuake3BSP.TraceSphere(VStart, VEnd: TVector; Radius: single): TVector;
var NewPosition: TVector;
begin
  CollisionTest.Colliding := false;
  CollisionTest.Grounded := false;
  CollisionTest.TryStepping := false;
  //
  CollisionTest.VolumeType := vtSphere;
  CollisionTest.Volume := Radius;
  NewPosition := Trace(VStart, VEnd);
  //
  if CollisionTest.Colliding and CollisionTest.TryStepping then
    NewPosition := TryToStep(NewPosition, VEnd);
  //
  Result := NewPosition;
end;

function TQuake3BSP.TraceBox(VStart, VEnd, VMin, VMax: TVector): TVector;
var NewPosition: TVector;
begin
  CollisionTest.Colliding := false;
  CollisionTest.Grounded := false;
  CollisionTest.TryStepping := false;
  //
  CollisionTest.VolumeType := vtBox;
  CollisionTest.BoundingBox[bbMin] := VMin;
  CollisionTest.BoundingBox[bbMax] := VMax;
  CollisionTest.BoundingBox[bbExtends].X := Max(-VMin.X, VMax.X);
  CollisionTest.BoundingBox[bbExtends].Y := Max(-VMin.Y, VMax.Y);
  CollisionTest.BoundingBox[bbExtends].Z := Max(-VMin.Z, VMax.Z);
  NewPosition := Trace(VStart, VEnd);
  //
  if CollisionTest.Colliding and CollisionTest.TryStepping then
    NewPosition := TryToStep(NewPosition, VEnd);
  //
  Result := NewPosition;
end;


procedure TQuake3BSP.CheckNode(NodeIndex: integer; StartRatio,EndRatio: Extended; var VStart,VEnd: TVector);
var Leaf: ^TBSPLeaf;
    Brush: ^TBSPBrush;
    Plane: ^TBSPPlane;
    Node: ^TBSPNode;
    i, BrushIndex, Side: integer;
    distanceStart, distanceEnd, offset: extended;
    Ratio1, Ratio2, RatioMiddle, InverseDistance: extended;
    VMiddle: TVector;
    V1,V2: TVector4f;
begin
  // Een negatieve NodeIndex verwijst naar een LeafNode met Brushes
  if NodeIndex < 0 then begin
    Leaf := @Leafs[not NodeIndex];
    // Doorloop alle brushes van dit leaf..
    for i:=0 to Leaf.N_LeafBrushes-1 do begin
      BrushIndex := LeafBrushes[Leaf.LeafBrush + i];
      Brush := @Brushes[BrushIndex];
      // Heeft de brush wel zijden? en is de zijde wel solid?..
      if (Brush.N_BrushSides > 0) and ((BSPTextures[Brush.TextureID].contents and tcSolid)<>0) then begin
        // Als het camera-oogpunt in een brush komt (met een solid texture.contents)
        // dan is er een botsing. auw!
        CheckBrush(BrushIndex, VStart,VEnd);
      end;
    end;
    Exit;
  end else begin
    // een NodeIndex die niet negatief is, verwijst naar een BSP-Node zonder leafs/brushes.
    // We doorzoeken alle nodes die tussen de camera-positie en next-position liggen
    // op brushes die misschien zijn geraakt.
    Node := @Nodes[NodeIndex];
    Plane := @Planes[Node.Plane];
    // dotproduct gebruiken om te testen of het Plane voor de camera ligt, of erachter..
    distanceStart := DotProduct(VStart, Plane.vNormal) - Plane.d;
    distanceEnd := DotProduct(VEnd, Plane.vNormal) - Plane.d;
    // volume van de camera bij botsingen..
    case CollisionTest.VolumeType of
      vtRay,
      vtSphere: offset := CollisionTest.Volume;
      vtBox:    offset := abs(CollisionTest.BoundingBox[bbExtends].X * Plane.vNormal.X) +
                          abs(CollisionTest.BoundingBox[bbExtends].Y * Plane.vNormal.Y) +
                          abs(CollisionTest.BoundingBox[bbExtends].Z * Plane.vNormal.Z);
      else offset := 0;
    end;
    //
    if (distanceStart >= offset) and (distanceEnd >= offset) then
      CheckNode(Node.Front, distanceStart,distanceEnd, VStart,VEnd)
    else
    if (distanceStart < -offset) and (distanceEnd < -offset) then
      CheckNode(Node.Back, distanceStart,distanceEnd, VStart,VEnd)
    else begin
      Ratio1 := 1.0;  Ratio2 := 0.0;  {RatioMiddle := 0.0;}
      Side := Node.Front;
      //
      if (distanceStart < distanceEnd) then begin
        Side := Node.Back;
        InverseDistance := 1.0 / (distanceStart - distanceEnd);
        Ratio1 := (distanceStart - offset - Epsilon) * InverseDistance;
        Ratio2 := (distanceStart + offset + Epsilon) * InverseDistance;
      end else
      if (distanceStart > distanceEnd) then begin
        InverseDistance := 1.0 / (distanceStart - distanceEnd);
        Ratio1 := (distanceStart + offset + Epsilon) * InverseDistance;
        Ratio2 := (distanceStart - offset - Epsilon) * InverseDistance;
      end;
      //
      if Ratio1 < 0.0 then Ratio1 := 0.0 else
      if Ratio1 > 1.0 then Ratio1 := 1.0;
      if Ratio2 < 0.0 then Ratio2 := 0.0 else
      if Ratio2 > 1.0 then Ratio2 := 1.0;
      //
      RatioMiddle := StartRatio + ((EndRatio - StartRatio) * Ratio1);
      VMiddle := AddVector(VStart, ScaleVector(SubVector(VEnd, VStart), Ratio1));
      CheckNode(Side, StartRatio,RatioMiddle, VStart,VMiddle);
      //
      RatioMiddle := StartRatio + ((EndRatio - StartRatio) * Ratio2);
      VMiddle := AddVector(VStart, ScaleVector(SubVector(VEnd, VStart), Ratio2));
      if Side = Node.Front then CheckNode(Node.Back, RatioMiddle,EndRatio, VMiddle,VEnd)
                           else CheckNode(Node.Front, RatioMiddle,EndRatio, VMiddle,VEnd);
    end;
  end;
end;




procedure TQuake3BSP.CheckBrush(BrushIndex: integer; var VStart,VEnd: TVector);
var bs: integer;
    Brush: ^TBSPBrush;
    BrushSide: ^TBSPBrushSide;
    Plane: ^TBSPPlane;
    distanceStart, distanceEnd, offset: extended;
    StartRatio, EndRatio, Ratio1, Ratio: extended;
    StartsOutside: boolean;
    VOffset: TVector;
begin
  //
  StartsOutside := false;
  //
  StartRatio := -1.0;
  EndRatio := 1.0;
  //CollisionTest.Collision := false;
  Brush := @Brushes[BrushIndex];
  // doorloop alle sides van deze brush
  for bs:=0 to Brush.N_BrushSides-1 do begin
    BrushSide := @BrushSides[Brush.BrushSide + bs];
    Plane := @Planes[BrushSide.Plane];
    // volume van de camera bij botsingen..
    case CollisionTest.VolumeType of
      vtRay, vtSphere: begin
          offset := CollisionTest.Volume;
          // dotproduct gebruiken om te testen of het Plane voor de camera ligt, of erachter..
          distanceStart := DotProduct(VStart, Plane.vNormal) - (Plane.d + offset);
          distanceEnd := DotProduct(VEnd, Plane.vNormal) - (Plane.d + offset);
        end;
      vtBox: begin
          if Plane.vNormal.X < 0 then VOffset.X := CollisionTest.BoundingBox[bbMax].X
                                 else VOffset.X := CollisionTest.BoundingBox[bbMin].X;
          if Plane.vNormal.Y < 0 then VOffset.Y := CollisionTest.BoundingBox[bbMax].Y
                                 else VOffset.Y := CollisionTest.BoundingBox[bbMin].Y;
          if Plane.vNormal.Z < 0 then VOffset.Z := CollisionTest.BoundingBox[bbMax].Z
                                 else VOffset.Z := CollisionTest.BoundingBox[bbMin].Z;
          //
          distanceStart := DotProduct(AddVector(VStart, VOffset), Plane.vNormal) - Plane.d;
          distanceEnd := DotProduct(AddVector(VEnd, VOffset), Plane.vNormal) - Plane.d;
        end;
    end;
    //
    if (distanceStart>0) then StartsOutside := true;
    //
    if (distanceStart > 0) and (distanceEnd > 0) then Exit;
    //
    if (distanceStart <= 0) and (distanceEnd <= 0) then Continue;
    //
    if distanceStart > distanceEnd then begin
      Ratio1 := (distanceStart - Epsilon) / (distanceStart - distanceEnd);
      if Ratio1 > StartRatio then begin
        StartRatio := Ratio1;
        //botsing..
        CollisionTest.Colliding := true;
        CollisionTest.VCollisionNormal := Plane.vNormal;
        CollisionTest.VCollisionPlaneDistance := Plane.d;
        //
        {CollisionTest.CollisionFaceIndex := ;}
        //
        if CollisionTest.VCollisionNormal.Y > 0.2 then
          CollisionTest.Grounded := true;
        //if (((VStart.X <> VEnd.X) or (VStart.Z <> VEnd.Z)) and (Plane.vNormal.Y <> 1)) then
        //if (CollisionTest.Grounded and ((VStart.X <> VEnd.X) or (VStart.Z <> VEnd.Z)) and (abs(Plane.vNormal.Y) < 0.8)) then
        if (CollisionTest.Grounded and ((VStart.X <> VEnd.X) or (VStart.Z <> VEnd.Z)) and (Plane.vNormal.Y < 0.8) ) then
          CollisionTest.TryStepping := true;
        //
      end;
    end else begin
      Ratio := (distanceStart + Epsilon) / (distanceStart - distanceEnd);
      if Ratio < EndRatio then EndRatio := Ratio;
    end;
    //
    if not StartsOutside then Exit;
    //
    if StartRatio < EndRatio then begin
      if (StartRatio > -1) and (StartRatio < CollisionTest.TraceRatio) then begin
        if StartRatio < 0 then StartRatio := 0;
        CollisionTest.TraceRatio := StartRatio;
      end;
    end;
  end;
end;














initialization
  Quake3BSP := TQuake3BSP.Create;

finalization
  Quake3BSP.Free;




end.
