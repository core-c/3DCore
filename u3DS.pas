unit u3DS;
interface
uses stdCtrls, ComCtrls,
     u3DTypes, u3DModel, uCalc;

type
  // een 3DS bestand-portie
  TChunk = packed record
             ID: word;                          //2 bytes unsigned integer
             Length: Integer;                   //4 bytes signed integer
           end;


  T3DS = class(TObject)
         private
           F: File;
           pMemo: TMemo;
           pTree: TTreeView;
           //
           Version3DS,
           VersionMesh: Integer;
           MasterScale: Single;
           //
           BytesRead: Integer;
           ChunkLevel: integer;
           //
           rByte: Byte;
           rWord: Word;
           //rInt16: SmallInt;
           //rInt32: Integer;
           rSingle: Single;
           rString,
           rMapName: String;
           rColor: TRGB;
           rLinColor: TRGBA;
           rPercentage: Single;
           rVector: TVector;
           rMatrix: TMatrix;
           rMaterial: TMaterial;
           rHierarchy: THierarchy;
           rTrackHeader: T3DSTrackHeader;
           //rKeyHeader: T3DSKeyHeader;
           //
           function ValueToString(Value: array of const) : string;
           function RGBToString(Value: TRGB) : string;
           function RGBAToString(Value: TRGBA) : string;
           function VectorToString(Value: TVector) : string;
           procedure AddNodeValue(Node: TTreeNode; Value: array of const);
           function ColorToLinColor(Value: TRGB; Value2: TRGBA) : TRGBA;
           //
           procedure DefaultMaterial(var aMaterial: TMaterial);
           procedure DefaultHierarchy(var aHierarchy: THierarchy);
           //
           function ChunkDescription(ID: Integer) : string;
           function ReadSingle(var F: File) : Single;
           function ReadInt32(var F: File) : Integer;
           function ReadInt16(var F: File) : SmallInt;
           function ReadWord(var F: File) : Word;
           function ReadByte(var F: File) : Byte;
           function ReadASCIIZ(var F: File) : string;
           function ReadColor(var F: File) : TRGB;
           function ReadLinColor(var F: File) : TRGBA;
           function ReadVector(var F: File) : TVector;
           function ReadMatrix(var F: File) : TMatrix;
           function ReadTexCoords(var F: File) : TTexCoords;
           function ReadFace(var F: File) : TFace;
           function ReadTrackHeader(var F: File) : T3DSTrackHeader;
           function ReadKeyHeader(var F: File) : T3DSKeyHeader;
           function ReadRotationKey(var F: File) : T3DSKeyRotation;
           function ReadChunk(var F: File; ParentNode: TTreeNode) : boolean;
           function ReadSubChunks(var F: File; ToFP: Integer; ParentNode: TTreeNode) : boolean;
         public
           // object
           constructor Create;
           destructor Destroy; override;
           //
           procedure Clear;
           // Memo output
           procedure Set_StdOut(var aMemo: TMemo);
           procedure Clear_StdOut;
           procedure Print_StdOut(s: string);
           // TreeView output
           procedure Set_StdTree(var aTreeView: TTreeView);
           procedure Clear_StdTree;
           procedure Add_StdTree(ParentNode: TTreeNode; var Node: TTreeNode; ID: integer; Value: string);
           //
           procedure ReadFromFile(Filename: String);
         end;

var obj3DS: T3DS;

implementation
uses SysUtils, Math;

constructor T3DS.Create;
begin
  // object initiëren
  inherited;
  // Data initialiseren
  pMemo := nil;
  pTree := nil;
end;

destructor T3DS.Destroy;
begin
  // Data finaliseren
  pMemo := nil;
  pTree := nil;
  // object vrijgeven
  inherited;
end;

procedure T3DS.Clear;
begin
  SetLength(rHierarchy.Children, 0);
  pTree.Items.Clear;
end;



{Memo}
procedure T3DS.Set_StdOut(var aMemo: TMemo);
begin
  pMemo := aMemo
end;

procedure T3DS.Clear_StdOut;
begin
  if pMemo <> nil then pMemo.lines.Clear
end;

procedure T3DS.Print_StdOut(s: string);
begin
  if pMemo <> nil then pMemo.lines.add(s)
end;



{TreeView}
procedure T3DS.Set_StdTree(var aTreeView: TTreeView);
begin
  pTree := aTreeView
end;

procedure T3DS.Clear_StdTree;
begin
  if pTree <> nil then pTree.Items.Clear
end;

procedure T3DS.Add_StdTree(ParentNode: TTreeNode; var Node: TTreeNode; ID: integer; Value: string);
begin
  if pTree <> nil then
    if ID <> -1 then
      Node := pTree.Items.AddChild(ParentNode, IntToHex(ID,4) +'  '+ ChunkDescription(ID) +'  '+ Value)
    else
      Node := pTree.Items.AddChild(ParentNode, Value);
end;







function T3DS.ChunkDescription(ID: Integer): string;
begin
  Case ID of
    $4D4D: Result := 'M3DMAGIC'; //(root chunk)
    $3D3D: Result := 'MDATA, mesh data';
    $AFFF: Result := 'MAT_ENTRY, material';
    $B000: Result := 'KFDATA, keyframer data';
    //enkele algemene nodes die je door de hele file tegenkomt
    $0002: Result := 'M3D_VERSION';
    $3D3E: Result := 'MESH_VERSION';
    $0100: Result := 'MASTER_SCALE';
    $0011: Result := 'COLOR_24, (R,G,B-waarden van 0 to 255)';
    $0012: Result := 'LIN_COLOR_24, (R,G,B-waarden van 0.0..1.0)';
    $0030: Result := 'INT_PERCENTAGE';
    $0031: Result := 'FLOAT_PERCENTAGE';
    $1100: Result := 'BIT_MAP';
    $1101: Result := 'USE_BIT_MAP';
    $1200: Result := 'SOLID_BGND';
    $1201: Result := 'USE_SOLID_BGND';
    $1300: Result := 'V_GRADIENT';
    $1301: Result := 'USE_V_GRADIENT';
    $2100: Result := 'AMBIENT_LIGHT';
    $4600: Result := 'N_DIRECT_LIGHT';
    $4680: Result := 'N_AMBIENT_LIGHT';
    $4700: Result := 'N_CAMERA';
    $4F00: Result := 'HIERARCHY';
    //een aantal sub-nodes van MAT_ENTRY (AFFF)
    $A000: Result := 'MAT_NAME';
    $A010: Result := 'MAT_AMBIENT';
    $A020: Result := 'MAT_DIFFUSE';
    $A030: Result := 'MAT_SPECULAR';
    $A040: Result := 'MAT_SHININESS';
    $A041: Result := 'MAT_SHIN2PCT, (Shininess-Strength)';
    $A050: Result := 'MAT_TRANSPARENCY';
    $A084: Result := 'MAT_SELF_ILPCT';
    $A081: Result := 'MAT_TWO_SIDE';
    $A200: Result := 'MAT_TEXMAP';  //de texture voor het huidige materiaal
    $A300: Result := 'MAT_MAPNAME'; //de naam van de texture-file
    $A350: Result := 'MAT_MAP_TILINGOLD';
    $A351: Result := 'MAT_MAP_TILING';
    $A352: Result := 'MAT_MAP_TEXBLUR_OLD';
    $A353: Result := 'MAT_MAP_TEXBLUR';
    $A354: Result := 'MAT_MAP_USCALE';
    $A356: Result := 'MAT_MAP_VSCALE';
    $A358: Result := 'MAT_MAP_UOFFSET';
    $A35A: Result := 'MAT_MAP_VOFFSET';
    $A35C: Result := 'MAT_MAP_ANG';
    $A360: Result := 'MAT_MAP_COL1';
    $A362: Result := 'MAT_MAP_COL2';
    $A364: Result := 'MAT_MAP_RCOL';
    $A366: Result := 'MAT_MAP_GCOL';
    $A368: Result := 'MAT_MAP_BCOL';
    //De sub-nodes van de main editor-chunk (3D3D)
    $4000: Result := 'NAMED_OBJECT';
    $4100: Result := 'N_TRI_OBJECT';
    $4110: Result := 'POINT_ARRAY';
    $4140: Result := 'TEX_VERTS, texture coördinaten';
    $4170: Result := 'MESH_TEXTURE_INFO, texture mapping type [planar, spherical of cyl.]';
    $4111: Result := 'POINT_FLAG_ARRAY';
    $4160: Result := 'MESH_MATRIX, (local axis)';
    $4165: Result := 'MESH_COLOR';
    $4120: Result := 'FACE_ARRAY';
    $4130: Result := 'MSH_MAT_GROUP, (material)';
    $4150: Result := 'SMOOTH_GROUP';
    //een aantal sub-nodes van KFDATA, keyframer $B000
    $B001: Result := 'AMBIENT_NODE_TAG';
    $B002: Result := 'OBJECT_NODE_TAG';
    $B003: Result := 'CAMERA_NODE_TAG';
    $B004: Result := 'TARGET_NODE_TAG';
    $B005: Result := 'LIGHT_NODE_TAG';
    $B006: Result := 'L_TARGET_NODE_TAG';
    $B007: Result := 'SPOTLIGHT_NODE_TAG';
    $B008: Result := 'KFSEG';
    $B010: Result := 'NODE_HDR';
    $B00A: Result := 'KFHDR';
    $B030: Result := 'NODE_ID';
    $B011: Result := 'INSTANCE_NAME, onzichtbare dummies';
    $B014: Result := 'BOUNDBOX';
    $B013: Result := 'PIVOT, track-pivot';
    $8000: Result := 'XDATA_SECTION';
    $B015: Result := 'MORPH_SMOOTH';
    $B009: Result := 'KFCURTIME';
    $B020: Result := 'POS_TRACK_TAG';
    $B021: Result := 'ROT_TRACK_TAG';
    $B022: Result := 'SCL_TRACK_TAG';
    $B029: Result := 'HIDE_TRACK_TAG';
    $0000: Result := 'NULL_CHUNK (EOF)';
    else Result := '(Unknown)';
  end;
end;

function T3DS.ReadASCIIZ(var F: File): string;
var Ch: Char;
    s: string;
begin
  s := '';
  repeat
    BlockRead(F, Ch, SizeOf(Ch), BytesRead);
    if Ch<>#0 then s := s + Ch;
  until Ch = #0;
  Result := s;
end;

function T3DS.ReadByte(var F: File): Byte;
begin
  BlockRead(F, Result, SizeOf(Result), BytesRead);
end;

function T3DS.ReadInt16(var F: File): SmallInt;
begin
  BlockRead(F, Result, SizeOf(Result), BytesRead);
end;

function T3DS.ReadInt32(var F: File): Integer;
begin
  BlockRead(F, Result, SizeOf(Result), BytesRead);
end;

function T3DS.ReadKeyHeader(var F: File): T3DSKeyHeader;
begin
  BlockRead(F, Result, SizeOf(Result), BytesRead);
end;

function T3DS.ReadTrackHeader(var F: File): T3DSTrackHeader;
begin
  BlockRead(F, Result, SizeOf(Result), BytesRead);
end;

function T3DS.ReadRotationKey(var F: File): T3DSKeyRotation;
begin
  BlockRead(F, Result, SizeOf(Result), BytesRead);
end;

function T3DS.ReadSingle(var F: File): Single;
begin
  BlockRead(F, Result, SizeOf(Result), BytesRead);
end;

function T3DS.ReadWord(var F: File): Word;
begin
  BlockRead(F, Result, SizeOf(Result), BytesRead);
end;

function T3DS.ReadColor(var F: File): TRGB;
begin
  BlockRead(F, Result, SizeOf(Result), BytesRead);
end;

function T3DS.ReadLinColor(var F: File): TRGBA;
begin
  BlockRead(F, Result.R , SizeOf(Result.R), BytesRead);
  BlockRead(F, Result.G , SizeOf(Result.G), BytesRead);
  BlockRead(F, Result.B , SizeOf(Result.B), BytesRead);
  Result.R := Min(Max(Result.R, 0.0), 1.0);
  Result.G := Min(Max(Result.G, 0.0), 1.0);
  Result.B := Min(Max(Result.B, 0.0), 1.0);
  Result.A := 1.0;
end;

function T3DS.ReadVector(var F: File): TVector;
begin
  BlockRead(F, Result , SizeOf(Result), BytesRead);
end;

function T3DS.ReadMatrix(var F: File): TMatrix;
begin
  BlockRead(F, Result , SizeOf(Result), BytesRead);
end;

function T3DS.ReadTexCoords(var F: File): TTexCoords;
begin
  BlockRead(F, Result , SizeOf(Result), BytesRead);
end;

function T3DS.ReadFace(var F: File): TFace;
begin
  Result.V1 := ReadWord(F);
  Result.V2 := ReadWord(F);
  Result.V3 := ReadWord(F);
  Result.Flag := ReadWord(F);
  //BlockRead(F, Result , SizeOf(Result), BytesRead);
end;

function T3DS.ValueToString(Value: array of const): string;
begin
  //for i:=0 to High(Value) do
  //  with Value[i] do
    with Value[0] do
      case VType of
        vtInteger:    Result := IntToStr(VInteger);
        vtBoolean:    Result := BoolToStr(VBoolean);
        vtChar:       Result := VChar;
        vtExtended:   Result := FloatToStrF(VExtended^, ffFixed, 6,3);
        vtString:     Result := VString^;
        vtPChar:      Result := VPChar;
        vtObject:     Result := VObject.ClassName;
        vtClass:      Result := VClass.ClassName;
        vtAnsiString: Result := string(VAnsiString);
        vtCurrency:   Result := CurrToStr(VCurrency^);
        vtVariant:    Result := string(VVariant^);
        vtInt64:      Result := IntToStr(VInt64^);
      end;
end;

function T3DS.RGBToString(Value: TRGB): string;
begin
  Result := 'R:'+ IntToStr(Value.R) +',G:'+ IntToStr(Value.G) +',B:'+ IntToStr(Value.B)
end;

function T3DS.RGBAToString(Value: TRGBA): string;
begin
  Result := 'R:'+ FloatToStrF(Value.R, ffFixed, 6,3) +',G:'+ FloatToStrF(Value.G, ffFixed, 6,3) +',B:'+ FloatToStrF(Value.B, ffFixed, 6,3) +',A:'+ FloatToStrF(Value.A, ffFixed, 6,3)
end;

function T3DS.VectorToString(Value: TVector): string;
begin
  Result := 'X:'+ FloatToStrF(Value.X, ffFixed, 6,3) +',Y:'+ FloatToStrF(Value.Y, ffFixed, 6,3) +',Z:'+ FloatToStrF(Value.Z, ffFixed, 6,3)
end;

procedure T3DS.AddNodeValue(Node: TTreeNode; Value: array of const);
var N: TTreeNode;
begin
  Add_StdTree(Node, N, -1, ValueToString(Value))
end;

function T3DS.ColorToLinColor(Value: TRGB; Value2: TRGBA) : TRGBA;
begin
  if (Value.R=0) and (Value.G=0) and (Value.B=0) then
    Result := Value2
  else begin
    Result.R := (Value.R*1.0) / 255.0;
    Result.G := (Value.G*1.0) / 255.0;
    Result.B := (Value.B*1.0) / 255.0;
    Result.A := 1.0;
  end;

end;


procedure T3DS.DefaultMaterial(var aMaterial: TMaterial);
const ColorAmbient : TRGBA = (R:0.1; G:0.1; B:0.1; A:1.0);
      ColorDiffuse : TRGBA = (R:0.5; G:0.5; B:0.5; A:1.0);
      ColorSpecular : TRGBA = (R:0.7; G:0.7; B:0.7; A:1.0);
      ColorEmission : TRGBA = (R:0.0; G:0.0; B:0.0; A:0.0);
begin
  with aMaterial do begin
    Name := 'default';
    Ambient := ColorAmbient;
    Diffuse := ColorDiffuse;
    Specular := ColorSpecular;
    Emission := ColorEmission;
    Shininess := 4.0;          //[0.0 .. 128.0]  0=weid verspreid, 128=gefocused licht
    Transparency := 0.0;       //0=100% solid, 100=0% solid
    TwoSided := false;
    with Texture do begin
      Name := '';
      Handle := 0;
      Blend := 100.0;          //texture dekking
    end;
  end;
end;

procedure T3DS.DefaultHierarchy(var aHierarchy: THierarchy);
begin
  with aHierarchy do begin
    Name := '';
    Index := -1;
    ParentIndex := -1;
    Root := -1;
    SetLength(Children, 0);
  end;
end;


function T3DS.ReadChunk(var F: File; ParentNode: TTreeNode) : boolean;
var Chunk: TChunk;
    FP, FP2: Integer; //FilePointer
    i: integer;
    Node, N: TTreeNode;
    s:string;
begin
  FP := FilePos(F);
  BlockRead(F,Chunk,SizeOf(TChunk),BytesRead);
  Result := (BytesRead = SizeOf(TChunk));
  if Chunk.Length < 6 then Chunk.Length := 6;
  FP2 := FP + Chunk.Length;
  if Result then begin

    // een standaard materiaal toevoegen aan de Materials eigenschap van het 3DModel (unit u3DModel)
    if ParentNode = nil then begin
      DefaultMaterial(rMaterial);
      Obj3DModel.Materials.Add(rMaterial);
    end;

    // Toevoegen aan de treeview
    Add_StdTree(ParentNode, Node, Chunk.ID, '');
    // De chunk verwerken..
    Case Chunk.ID of
      $4D4D: begin //M3DMAGIC (root chunk)
               // deze chunk is de root-chunk. De lengte van deze chunk is
               // gelijk aan de lengte van de .3ds-file - de lengte van 1 chunk.header (6 bytes).
               // Alle verder roots in de file zijn sub-nodes van deze root-node.
               //
               ChunkLevel := 0;
               ReadSubChunks(F, FP2, Node);
             end;
      $3D3D: begin //MDATA (main chunk), mesh data, editor chunk
               ReadSubChunks(F, FP2, Node);
             end;
      $AFFF: begin //MAT_ENTRY (main chunk), materials
               DefaultMaterial(rMaterial);
               ReadSubChunks(F, FP2, Node);
               // het gelezen materiaal toevoegen aan de Materials eigenschap
               Obj3DModel.Materials.Add(rMaterial);
             end;
      $B000: begin //KFDATA (main chunk), keyframer
               ReadSubChunks(F, FP2, Node);
             end;

      //enkele algemene nodes die je door de hele file tegenkomt
      $0002: begin //M3D_VERSION
               Version3DS := ReadInt32(F);
               AddNodeValue(Node,[Version3DS]);
               Seek(F,FP2);
             end;
      $3D3E: begin //MESH_VERSION
               VersionMesh := ReadInt32(F);
               AddNodeValue(Node,[VersionMesh]);
               Seek(F,FP2);
             end;
      $0100: begin //MASTER_SCALE
               MasterScale := ReadSingle(F);
               AddNodeValue(Node,[MasterScale]);
               Seek(F,FP2);
             end;
      $0011: begin //COLOR_24 (R,G,B-waarden van 0 to 255)
               rColor := ReadColor(F);
               AddNodeValue(Node,[RGBToString(rColor)]);
               Seek(F,FP2);
             end;
      $0012: begin //LIN_COLOR_24 (R,G,B-waarden van 0.0..1.0)
               rLinColor := ReadLinColor(F);
               AddNodeValue(Node,[RGBAToString(rLinColor)]);
               Seek(F,FP2);
             end;
      $0030: begin //INT_PERCENTAGE
               rWord := ReadInt16(F);
               rPercentage := (rWord*1.0)/100.0;
               AddNodeValue(Node,[rWord]);
               Seek(F,FP2);
             end;
      $0031: begin //FLOAT_PERCENTAGE
               rPercentage := ReadSingle(F);
               AddNodeValue(Node,[rPercentage]);
               Seek(F,FP2);
             end;
      $1100: begin //BIT_MAP
               Seek(F,FP2);
             end;
      $1101: begin //USE_BIT_MAP
               Seek(F,FP2);
             end;
      $1200: begin //SOLID_BGND
               Seek(F,FP2);
             end;
      $1201: begin //USE_SOLID_BGND
               Seek(F,FP2);
             end;
      $1300: begin //V_GRADIENT
               Seek(F,FP2);
             end;
      $1301: begin //USE_V_GRADIENT
               Seek(F,FP2);
             end;
      $2100: begin //AMBIENT_LIGHT
               Seek(F,FP2);
             end;
      $4600: begin //N_DIRECT_LIGHT
               rVector := ReadVector(F);
               Seek(F,FP2);
             end;
      $4680: begin //N_AMBIENT_LIGHT
               Seek(F,FP2);
             end;
      $4700: begin //N_CAMERA
               Seek(F,FP2);
             end;
      $4F00: begin //HIERARCHY
               Seek(F,FP2);
             end;

      //een aantal sub-nodes van MAT_ENTRY (AFFF)
      $A000: begin //MAT_NAME
               rMaterial.Name := ReadASCIIZ(F);
               AddNodeValue(Node,[rMaterial.Name]);
               Seek(F,FP2);
             end;
      $A010: begin //MAT_AMBIENT
               ReadSubChunks(F, FP2, Node);
               rMaterial.Ambient := ColorToLinColor(rColor, rLinColor);
             end;
      $A020: begin //MAT_DIFFUSE
               ReadSubChunks(F, FP2, Node);
               rMaterial.Diffuse := ColorToLinColor(rColor, rLinColor);
             end;
      $A030: begin //MAT_SPECULAR
               ReadSubChunks(F, FP2, Node);
               {rLinColor.R := 0.0; //debug.test voor arctic model..}
               rMaterial.Specular := ColorToLinColor(rColor, rLinColor);
             end;
      $A040: begin //MAT_SHININESS
               // lees de sub-nodes (dat zal een INT_PERCENTAGE zijn (of een FLOAT_PERCENTAGE))
               ReadSubChunks(F, FP2, Node);
               rMaterial.Shininess := rPercentage * 128.0;  //omrekenen naar bereik (0.0 To 128.0)
             end;
      $A041: begin //MAT_SHIN2PCT (Shininess-Strength)
               Seek(F,FP2);
             end;
      $A050: begin //MAT_TRANSPARENCY
               // lees de sub-nodes (dat zal een INT_PERCENTAGE zijn (of een FLOAT_PERCENTAGE))
               ReadSubChunks(F, FP2, Node);
               // rPercentage is een getal in bereik[0..1]
               // hoe meer transparant, hoe lager de alpha waarde..
               rMaterial.Transparency := 1.0 - rPercentage;
             end;
      $A084: begin //MAT_SELF_ILPCT
               // lees de sub-nodes (dat zal een INT_PERCENTAGE zijn (of een FLOAT_PERCENTAGE))
               ReadSubChunks(F, FP2, Node);
               rMaterial.Emission.R := rPercentage;
               rMaterial.Emission.G := rPercentage;
               rMaterial.Emission.B := rPercentage;
               rMaterial.Emission.A := 1.0;
             end;
      $A081: begin //MAT_TWO_SIDE
               rMaterial.TwoSided := true;
               Seek(F,FP2);
             end;
      $A200: begin //MAT_TEXMAP  ''de texture voor het huidige materiaal
               // lees de sub-nodes..
               // (dat zal een INT_PERCENTAGE zijn (of een FLOAT_PERCENTAGE)..)
               // (..en een MAT_MAPNAME)
               ReadSubChunks(F, FP2, Node);
               rMaterial.Texture.Name := rMapName;
//               rMaterial.Texture.Handle := fOpenGL.OGL.LoadTexture(rMaterial.Texture.Name, 1.0);
               rMaterial.Texture.Blend := rPercentage;
             end;
      $A220: begin //MAT_REFLMAP
               ReadSubChunks(F, FP2, Node);
rMapName := 'RefMap_Base.jpg';
               rMaterial.Reflection.Name := rMapName;
//               rMaterial.Reflection.Handle := fOpenGL.OGL.LoadTexture(rMapName, 1.0);
               rMaterial.Reflection.Blend := rPercentage * 128.0;
             end;
      $A300: begin //MAT_MAPNAME '' de naam van de texture-file
               rMapName := ReadASCIIZ(F);
               // De texture in OpenGL aanmaken en de texturehandle opslaan in het 3D-model object.
               // !!!!!alleen uitvoeren als OpenGL actief is...
               {rMaterial.Texture.Handle := Obj3DModel.PrepareTexture(rMaterial.Texture.Name);}
               //
               AddNodeValue(Node,[rMapName]);
               Seek(F,FP2);
             end;
      $A351: begin
               ReadWord(F);
               Seek(F,FP2);
             end;

      //De sub-nodes van de main editor-chunk (3D3D)
      $4000: begin //NAMED_OBJECT
               rString := ReadASCIIZ(F);
               AddNodeValue(Node,[rString]);
               // Een Named-Object alloceren in het 3DModel-object
               Obj3DModel.NamedObjs.Allocate(rString);
               // subnodes verwerken..
               ReadSubChunks(F, FP2, Node);
             end;
      $4100: begin //N_TRI_OBJECT
               // Een Triangle-object alloceren in het 3DModel-object
               Obj3DModel.NamedObjs.Allocate_TriObj;
               //
               ReadSubChunks(F, FP2, Node);
             end;
      $4110: begin //POINT_ARRAY
               rWord := ReadWord(F); // het aantal punten
               AddNodeValue(Node,[rWord]);
               with Obj3DModel.NamedObjs do
                 with NamedObjects[Len-1].TriObjs[Len_TriObj-1] do begin
                   if rWord > 2 then begin
                     SetLength(Points, rWord);
                     for i:=0 to rWord-1 do begin
                       Points[i] := ReadVector(F);
                     end;
                   end else
                     SetLength(Points, 0);
                 end;
               Seek(F,FP2);
             end;
      $4140: begin //TEX_VERTS (mapping coords)
               rWord := ReadWord(F); // het aantal texture-coördinaten
               AddNodeValue(Node,[rWord]);
               with Obj3DModel.NamedObjs do
                 with NamedObjects[Len-1].TriObjs[Len_TriObj-1] do begin
                   if rWord > 0 then begin
                     SetLength(TexCoords, rWord);
                     for i:=0 to rWord-1 do TexCoords[i] := ReadTexCoords(F);
(*                     begin
                       TexCoords[i] := ReadTexCoords(F);
                       s := 'U:'+ floattostr(TexCoords[i].U) +',V:'+ floattostr(TexCoords[i].V);
                       AddNodeValue(Node,[s]);
                       end;*)
                   end else
                     SetLength(TexCoords, 0);
                 end;
               Seek(F,FP2);
             end;
      $4170: begin //MESH_TEXTURE_INFO (texture mapping type (planar, spherical of cyl.))
               ReadWord(F);                     //MapType
               ReadSingle(F);                   //XTiling
               ReadSingle(F);                   //YTiling
               ReadVector(F);                   //IconCenter Position
               ReadSingle(F);                   //IconScaling
               for i:=0 to 11 do ReadSingle(F); //orientation Matrix[I]
               ReadSingle(F);                   //planar IconWidth
               ReadSingle(F);                   //planar IconHeight
               ReadSingle(F);                   //Cylinder IconHeight
               Seek(F,FP2);
             end;
      $4111: begin //POINT_FLAG_ARRAY
               // er zijn evenveel point-flags als gelezen punten per sub-object..
               rWord := ReadWord(F); // het aantal point-flags
               AddNodeValue(Node,[rWord]);
               with Obj3DModel.NamedObjs do
                 with NamedObjects[Len-1].TriObjs[Len_TriObj-1] do begin
                   if rWord > 0 then begin
                     SetLength(Flags, rWord);
                     for i:=0 to rWord-1 do Flags[i] := ReadByte(F);
                   end else
                     SetLength(Flags, 0);
                 end;
               Seek(F,FP2);
             end;
      $4160: begin //MESH_MATRIX (local axis)
               rMatrix := ReadMatrix(F); // lees een 3x4 matrix
               // De laatste rij bevat het PivotPoint van dit object..
               with Obj3DModel.NamedObjs do
                 NamedObjects[Len-1].PivotPoint := rMatrix.V[3];
               Seek(F,FP2);
             end;
      $4165: begin //MESH_COLOR (de kleur in de editor)
               rByte := ReadByte(F);
               AddNodeValue(Node,[rByte]);
               Seek(F,FP2);
             end;
      $4120: begin //FACE_ARRAY
               rWord := ReadWord(F); // het aantal faces
               AddNodeValue(Node,[rWord]);
               with Obj3DModel.NamedObjs do
                 with NamedObjects[Len-1].TriObjs[Len_TriObj-1] do begin
                   if rWord > 0 then begin
                     SetLength(Faces, rWord);
                     for i:=0 to rWord-1 do Faces[i] := ReadFace(F);
                   end else
                     SetLength(Faces, 0);
                 end;
               //verwerk subnodes.. (4130, 4150)
               ReadSubChunks(F, FP2, Node);
               {Seek(F,FP2);}
             end;
      $4130: begin //MSH_MAT_GROUP (material)
               //Er kunnen meerdere MSH_MAT_GROUP's worden gedefinieerd binnen 1 FACE_ARRAY.
               rString := ReadASCIIZ(F);
               AddNodeValue(Node,[rString]);
               with Obj3DModel.NamedObjs do
                 with NamedObjects[Len-1].TriObjs[Len_TriObj-1] do begin
                   // een FaceGroup bijmaken..
                   SetLength(FaceGroups, Length(FaceGroups)+1);
                   with FaceGroups[Length(FaceGroups)-1] do begin
                     MaterialName := rString;
                     // FaceIndexes lezen
                     rWord := ReadWord(F); // het aantal face-indexes
                     if rWord > 0 then begin
                       SetLength(FaceIndex, rWord);
                       for i:=0 to rWord-1 do FaceIndex[i] := ReadInt16(F);
                     end else
                       SetLength(FaceIndex, 0);
                     // SmoothingGroups
                     SetLength(SmoothingGroups, 0);
                   end;
                 end;
               Seek(F,FP2);
             end;
      $4150: begin //SMOOTH_GROUP
               with Obj3DModel.NamedObjs do
                 with NamedObjects[Len-1].TriObjs[Len_TriObj-1] do begin
                   SetLength(SmoothingGroups, (Chunk.Length-6) div 4);
                   for i:=0 to Length(SmoothingGroups)-1 do SmoothingGroups[i] := ReadInt32(F);
                 end;
               Seek(F,FP2);
             end;
             
      //een aantal sub-nodes van KFDATA, keyframer $B000
      $B002: begin //OBJECT_NODE_TAG
               Obj3DModel.Animation.Allocate;
               DefaultHierarchy(rHierarchy);
               ReadSubChunks(F, FP2, Node);
               Obj3DModel.Hierarchy.Add(rHierarchy);
             end;
      $B030: begin //NODE_ID
               rHierarchy.Index := ReadInt16(F);
               AddNodeValue(Node,[rHierarchy.Index]);
               Seek(F,FP2);
             end;
      $B010: begin //NODE_HDR
               rHierarchy.Name := ReadASCIIZ(F);
               rWord := ReadWord(F);  // flags 1
               rWord := ReadWord(F);  // flags 2
               rHierarchy.ParentIndex := ReadInt16(F); // parent-index in object hierarchy (-1, FFFF, = root-node)
               rHierarchy.Root := -1;
               SetLength(rHierarchy.Children, 0);
               //
               {Obj3DModel.Hierarchy.Add(rHierarchy);}
               //
               AddNodeValue(Node,[rHierarchy.Name+'  index:'+IntToStr(rHierarchy.Index)+' parent-index:'+IntToStr(rHierarchy.ParentIndex)]);
               Seek(F,FP2);
             end;
      $B011: begin //INSTANCE_NAME ,  dit zijn de onzichtbare 3DS dummy objecten
               rString := ReadASCIIZ(F);
               AddNodeValue(Node,[rString]);
               Seek(F,FP2);
             end;
      $B014: begin //BOUNDBOX
               rVector := ReadVector(F);
               AddNodeValue(Node,[VectorToString(rVector)]);
               rVector := ReadVector(F);
               AddNodeValue(Node,[VectorToString(rVector)]);
               Seek(F,FP2);
             end;
      $B013: begin //PIVOT    (track-pivot tbv de keyframer animatie)
               rVector := ReadVector(F);
               AddNodeValue(Node,[VectorToString(rVector)]);
               Seek(F,FP2);
             end;
      $8000: begin //XDATA_SECTION
               Seek(F,FP2);
             end;
      $B015: begin //MORPH_SMOOTH
               rSingle := ReadSingle(F);
               AddNodeValue(Node,[rSingle]);
               Seek(F,FP2);
             end;
      $B009: begin //KFCURTIME
               rWord := ReadWord(F);
               AddNodeValue(Node,[rWord]);
               Seek(F,FP2);
             end;
      $B020: begin //POS_TRACK_TAG
               with Obj3DModel.Animation do Animation[Len-1].Index := rHierarchy.Index;
               rTrackHeader := ReadTrackHeader(F);
               if rTrackHeader.KeyCount > 0 then begin
                 //geheugen alloceren voor de key(header)s
                 Obj3DModel.Animation.Allocate_Pos(rTrackHeader.KeyCount);
                 //
                 for i:=0 to rTrackHeader.KeyCount-1 do
                   with Obj3DModel.Animation do
                     with Animation[Len-1] do begin
                       PosKeyHeaders[i] := ReadKeyHeader(F);
                       Position[i] := ReadVector(F);
                     end;
               end;
               Seek(F,FP2);
             end;
      $B021: begin //ROT_TRACK_TAG
               with Obj3DModel.Animation do Animation[Len-1].Index := rHierarchy.Index;
               rTrackHeader := ReadTrackHeader(F);
               if rTrackHeader.KeyCount > 0 then begin
                 //geheugen alloceren voor de key(header)s
                 Obj3DModel.Animation.Allocate_Rot(rTrackHeader.KeyCount);
                 //
                 for i:=0 to rTrackHeader.KeyCount-1 do
                   with Obj3DModel.Animation do
                     with Animation[Len-1] do begin
                       RotKeyHeaders[i] := ReadKeyHeader(F);
                       Rotation[i] := ReadRotationKey(F);
                     end;
               end;
               Seek(F,FP2);
             end;
      $B022: begin //SCL_TRACK_TAG
               Seek(F,FP2);
             end;
      $0000: begin //NULL_CHUNK (EOF)
               //
             end;
      else begin
             Seek(F,FP2);
           end;
    end;
  end;
end;


function T3DS.ReadSubChunks(var F: File; ToFP: Integer; ParentNode: TTreeNode): boolean;
begin
  Result := true;
  Inc(ChunkLevel);
  while (FilePos(F) < ToFP) and (not EOF(F)) do begin
    Result := ReadChunk(F, ParentNode);
    if not Result then break;
  end;
  Dec(ChunkLevel);
end;


procedure T3DS.ReadFromFile(Filename: String);
begin
  Obj3DModel.Clear;
  Clear;  //obj3DS
  Clear_StdOut;
  Clear_StdTree;
  Print_StdOut('3DS-file: '+ Filename);
  AssignFile(F, Filename);
  {I-}
  Reset(F,1);
  {I+}
  If IOResult = 0 then begin
    while not EOF(F) do
      if not ReadChunk(F,nil) then break;
    CloseFile(F);
  end;
  // Hierarchy bijwerken
  Obj3DModel.CorrectHierarchyIndexes;
  // Center op de oorsprong plaatsen & Scale bijwerken
  Obj3DModel.CorrectPositionAndScale(64);
  // Normalen voor de vlakken berekenen
  Obj3DModel.CalculateFaceNormals;
  // smoothing
  Obj3DModel.CalculateSmoothFaces;
  // de volgorde bij tekenen van transparante objecten
  Obj3DModel.CorrectTransparentOrder;
  //
  Obj3DModel.InitTextures;
  Obj3DModel.CreateDisplayLists;
  Obj3DModel.SetModelLoaded;
end;







initialization
  obj3DS := T3DS.Create;

finalization
  obj3DS.Free;

end.
