unit u3DModel;
interface
uses OpenGL, u3DTypes, uCalc, Math, uCamera{, FormOpenGL};

type
  TObjMaterials = class(TObject)
                  private
                  public
                    Material: array of TMaterial;
                    // object
                    constructor Create;
                    destructor Destroy; override;
                    //
                    procedure Clear;
                    function Len : Integer;
                    procedure Add(var aMaterial: TMaterial);
                    function NameToIndex(Name: string) : integer;
                  end;

  TObjNamed = class(TObject)
              private
              public
                NamedObjects: array of TNamedObj;
                // object
                constructor Create;
                destructor Destroy; override;
                //
                procedure Clear;
                function Len : Integer;
                procedure Allocate(Name: string);
                procedure Allocate_TriObj;
                function Len_TriObj : Integer;
              end;

  TObjHierarchy = class(TObject)
                  private
                  public
                    Hierarchy: array of THierarchy;
                    // object
                    constructor Create;
                    destructor Destroy; override;
                    //
                    procedure Clear;
                    function Len : Integer;
                    procedure Add(var aHierarchy: THierarchy);
                    function ObjIndexToHierarchyIndex(var Index: SmallInt) : SmallInt;
                  end;

  TObjAnimation = class(TObject)
                  private
                  public
                    Animation: array of TAnimation;
                    // object
                    constructor Create;
                    destructor Destroy; override;
                    //
                    procedure Clear;
                    function Len : Integer;
                    function Len_PosKeyHeader : Integer;
                    function Len_RotKeyHeader : Integer;
                    function Len_Position : Integer;
                    function Len_Rotation : Integer;
                    procedure Allocate;
                    procedure Allocate_Pos(Elements: Integer);  // alloceer 'Elements' elementen in de arrays PosKeyHeaders & Position
                    procedure Allocate_Rot(Elements: Integer);  // alloceer 'Elements' elementen in de arrays RotKeyHeaders & Rotation
                    function ObjIndexToAnimationIndex(Index: SmallInt): SmallInt;
                  end;

  T3DModel = class(TObject)
             private
               ModelLoaded : boolean;
               Frame, MaxFrames: integer;  //huidige frame (& laatst mogelijke frame index)
             public
               Materials: TObjMaterials;
               NamedObjs: TObjNamed;
               Hierarchy: TObjHierarchy;
               Animation: TObjAnimation;
               //
               Center: TVector;
               BoundingBox: TBoundingBox;
               WireFrame: boolean;
               AlreadyDrawn: array of integer;
               // object
               constructor Create;
               destructor Destroy; override;
               //
               procedure Clear;
               procedure SetModelLoaded;
               function IsModelLoaded : boolean;
               //
               procedure DisplayModel;
               procedure DisplayObject(Index: SmallInt);
               procedure DisplayTreeObject(Index: SmallInt); // een parent met (evt) children tekenen
               //
               procedure CorrectHierarchyIndexes;
               procedure CorrectPositionAndScale(Scale: Single);  //1.0=1 virtuele meter
               procedure CalculateSmoothFaces;
               procedure CorrectTransparentOrder;
               procedure CalculateFaceNormals;
               procedure CorrectAnimations;
               //
               procedure CreateDisplayLists;
               procedure DeleteDisplayLists;
               procedure InitTextures; //kan alleen als OpenGL actief is (geldige RC nodig)
               procedure FreeTextures; //kan alleen als OpenGL actief is (geldige RC nodig)
             end;

var Obj3DModel : T3DModel;


implementation
uses uTexture, uOpenGL;


{ TObjMaterials }
constructor TObjMaterials.Create;
begin
  // Object initiëren
  inherited;
  // Data initialiseren
  Clear;
end;

destructor TObjMaterials.Destroy;
begin
  // Data finaliseren
  Clear;
  // Object finaliseren
  inherited;
end;

procedure TObjMaterials.Clear;
begin
  SetLength(Material,0)
end;

function TObjMaterials.Len: Integer;
begin
  Result := Length(Material)
end;

procedure TObjMaterials.Add(var aMaterial: TMaterial);
var L: integer;
begin
  L := Length(Material);
  SetLength(Material, L+1);
  Material[L] := aMaterial;
end;

function TObjMaterials.NameToIndex(Name: string): integer;
var i: integer;
begin
  Result := -1; // ongeldige waarde
  for i:=0 to Length(Material)-1 do
    if Material[i].Name = Name then begin
      Result := i;
      break;
    end;
end;






{ TObjNamed }
constructor TObjNamed.Create;
begin
  // object initiëren
  inherited;
  // Data initialiseren
  Clear;
end;

destructor TObjNamed.Destroy;
begin
  // Data finaliseren
  Clear;
  // object vrijgeven
  inherited;
end;

procedure TObjNamed.Clear;
var i,j,k: integer;
begin
  for i:=0 to Length(NamedObjects)-1 do
    with NamedObjects[i] do begin
      for j:=0 to Length(TriObjs)-1 do
        with TriObjs[j] do begin
          SetLength(Points, 0);
          SetLength(Faces, 0);
          SetLength(Normals, 0);                 // Face-Normals
          SetLength(TexCoords, 0);
          SetLength(Flags, 0);
          for k:=0 to Length(FaceGroups)-1 do SetLength(FaceGroups[k].FaceIndex, 0);
          SetLength(FaceGroups, 0);
          //
          SetLength(SmoothingGroups, 0);         // smoothing per Face
          SetLength(SPoints, 0);                 // smoothed vertices
          SetLength(SNormals, 0);                // Vertex-Normals
          SetLength(STexCoords, 0);              // smoothed vertex-texture coordinaten
          SetLength(SSmooth, 0);                 // smoothgroup voor elke vertex
        end;
      SetLength(TriObjs, 0);
      with Animation do begin
        Index := -1;
        Name := '';
        SetLength(PosKeyHeaders, 0);
        SetLength(Position, 0);
        SetLength(RotKeyHeaders, 0);
        SetLength(Rotation, 0);
      end;
    end;
  SetLength(NamedObjects, 0);
end;

function TObjNamed.Len: Integer;
begin
  Result := Length(NamedObjects)
end;

procedure TObjNamed.Allocate(Name: string);
var L: integer;
begin
  L := Length(NamedObjects);
  SetLength(NamedObjects, L+1);
  NamedObjects[L].Name := Name;
end;

procedure TObjNamed.Allocate_TriObj;
var L,L2: integer;
begin
  L := Length(NamedObjects);
  with NamedObjects[L-1] do begin
    L2 := Length(TriObjs);
    SetLength(TriObjs, L2+1);
  end;
end;

function TObjNamed.Len_TriObj: Integer;
var L: integer;
begin
  L := Length(NamedObjects);
  Result := Length(NamedObjects[L-1].TriObjs);
end;







{ TObjHierarchy }
constructor TObjHierarchy.Create;
begin
  // object initiëren
  inherited;
  // Data initialiseren
  Clear;
end;

destructor TObjHierarchy.Destroy;
begin
  // Data finaliseren
  Clear;
  // object vrijgeven
  inherited;
end;

procedure TObjHierarchy.Clear;
var i: integer;
begin
  for i:=0 to Length(Hierarchy)-1 do SetLength(Hierarchy[i].Children, 0);
  SetLength(Hierarchy, 0);
end;

function TObjHierarchy.Len: Integer;
begin
  Result := Length(Hierarchy)
end;

procedure TObjHierarchy.Add(var aHierarchy: THierarchy);
var L: integer;
begin
  L := Length(Hierarchy);
  SetLength(Hierarchy, L+1);
  Hierarchy[L] := aHierarchy;
  SetLength(Hierarchy[L].Children, 0);
end;

function TObjHierarchy.ObjIndexToHierarchyIndex(var Index: SmallInt): SmallInt;
var i: integer;
begin
  Result := -1;
  for i:=0 to Length(Hierarchy)-1 do
    if (Hierarchy[i].Index = Index) then begin
      // Hierarchy[i].Name = Obj3DModel.NamedObjs.NamedObjects[Index].Name
      Result := i;
      break;
    end;
end;







{ TObjAnimation }
constructor TObjAnimation.Create;
begin
  // object initiëren
  inherited;
  // Data initialiseren
  Clear;
end;

destructor TObjAnimation.Destroy;
begin
  // Data finaliseren
  Clear;
  // object vrijgeven
  inherited;
end;

procedure TObjAnimation.Clear;
var i: integer;
begin
  for i:=0 to Length(Animation)-1 do begin
    SetLength(Animation[i].PosKeyHeaders, 0);
    SetLength(Animation[i].Position, 0);
    SetLength(Animation[i].RotKeyHeaders, 0);
    SetLength(Animation[i].Rotation, 0);
  end;
  SetLength(Animation, 0);
end;

function TObjAnimation.Len: Integer;
begin
  Result := Length(Animation)
end;

function TObjAnimation.Len_PosKeyHeader: Integer;
var L: integer;
begin
  L := Length(Animation);
  Result := Length(Animation[L-1].PosKeyHeaders);
end;

function TObjAnimation.Len_Position: Integer;
var L: integer;
begin
  L := Length(Animation);
  Result := Length(Animation[L-1].Position);
end;

function TObjAnimation.Len_RotKeyHeader: Integer;
var L: integer;
begin
  L := Length(Animation);
  Result := Length(Animation[L-1].RotKeyHeaders);
end;

function TObjAnimation.Len_Rotation: Integer;
var L: integer;
begin
  L := Length(Animation);
  Result := Length(Animation[L-1].Rotation);
end;

procedure TObjAnimation.Allocate;
var L: integer;
begin
  L := Length(Animation);
  SetLength(Animation, L+1);
  with Animation[L] do begin
    Index := -1;
    Name := '';
    SetLength(PosKeyHeaders, 0);
    SetLength(Position, 0);
    SetLength(RotKeyHeaders, 0);
    SetLength(Rotation, 0);
  end;
end;

procedure TObjAnimation.Allocate_Pos(Elements: Integer);
var L: integer;
begin
  L := Length(Animation);
  with Animation[L-1] do begin
    SetLength(PosKeyHeaders, Elements);
    SetLength(Position, Elements);
  end;
end;

procedure TObjAnimation.Allocate_Rot(Elements: Integer);
var L: integer;
begin
  L := Length(Animation);
  with Animation[L-1] do begin
    SetLength(RotKeyHeaders, Elements);
    SetLength(Rotation, Elements);
  end;
end;

function TObjAnimation.ObjIndexToAnimationIndex(Index: SmallInt): SmallInt;
var i: integer;
begin
  Result := -1;
  for i:=0 to Length(Animation)-1 do begin
    if Animation[i].Index = Index then begin
      Result := i;
      Exit;
    end;
  end;
end;

{ T3DModel }
constructor T3DModel.Create;
begin
  // object initiëren
  inherited;
  // Data initialiseren
  Materials := TObjMaterials.Create;
  NamedObjs := TObjNamed.Create;
  Hierarchy := TObjHierarchy.Create;
  Animation := TObjAnimation.Create;
  //
  Clear;
end;

destructor T3DModel.Destroy;
begin
  // Data finaliseren
  Clear;
  Materials.Free;
  NamedObjs.Free;
  Hierarchy.Free;
  Animation.Free;
  // object vrijgeven
  inherited;
end;

procedure T3DModel.Clear;
begin
  DeleteDisplayLists;
  Materials.Clear;
  NamedObjs.Clear;
  Hierarchy.Clear;
  Animation.Clear;
  Center := NullVector;
  BoundingBox.Min := NullVector;
  BoundingBox.Max := NullVector;
  WireFrame := false;
  ModelLoaded := false;
  Frame := 0;
  MaxFrames := 0; //de grootste aniamtie in dit model (voor alle NamedObjects)
end;

procedure T3DModel.SetModelLoaded;
begin
  ModelLoaded := true;
end;

function T3DModel.IsModelLoaded: boolean;
begin
  Result := ModelLoaded;
end;

procedure T3DModel.CorrectHierarchyIndexes;
var i,j,k,L: integer;
    H: array of THierarchy;
begin
  // Na het laden van een 3DS-file de Hierarchy-indexes aanpassen
  // van 3DS-indexes naar de indexes van mijn eigen array 'NamedObjs'.
  SetLength(H, Hierarchy.Len);
  for i:=0 to Hierarchy.Len-1 do H[i] := Hierarchy.Hierarchy[i];
  // Index
  for i:=0 to Hierarchy.Len-1 do
    for j:= 0 to NamedObjs.Len-1 do
      if NamedObjs.NamedObjects[j].Name = Hierarchy.Hierarchy[i].Name then begin
        // de index in het animatie-object
        for k:=0 to Length(Animation.Animation)-1 do
          if Animation.Animation[k].Name = NamedObjs.NamedObjects[j].Name then begin
            Animation.Animation[k].Index := j;
            Break;
          end;
        //
        Hierarchy.Hierarchy[i].Index := j;
        break;
      end;
  // ParentIndex
  for i:=0 to Hierarchy.Len-1 do
    if Hierarchy.Hierarchy[i].ParentIndex <> -1 then
      for j:=0 to Hierarchy.Len-1 do
        if H[j].Index = Hierarchy.Hierarchy[i].ParentIndex then begin
          Hierarchy.Hierarchy[i].ParentIndex := Hierarchy.Hierarchy[j].Index;
          break;
        end;
  SetLength(H, 0);
  //root-objecten bepalen..
  for i:=0 to Hierarchy.Len-1 do
    // test of dit een root-object is
    if Hierarchy.Hierarchy[i].ParentIndex = -1 then begin
      //
      if Hierarchy.Hierarchy[i].Index = -1 then
        Hierarchy.Hierarchy[i].Root := -1 //dit object is niet zichtbaar (bv een camera,light ed.)
      else
        // heeft het een af te beelden TRI_OBJ?
        if Length(NamedObjs.NamedObjects[Hierarchy.Hierarchy[i].Index].TriObjs) > 0 then
          Hierarchy.Hierarchy[i].Root := Hierarchy.Hierarchy[i].Index
        else
          Hierarchy.Hierarchy[i].Root := -1; //dit object is niet zichtbaar (bv een camera,light ed.)
    end;
  //children bepalen..
  for i:=0 to Hierarchy.Len-1 do
    //heeft dit object een parent?
    if Hierarchy.Hierarchy[i].ParentIndex <> -1 then begin
      //dit object als child toevoegen van zijn parent..
      j := Hierarchy.Hierarchy[i].ParentIndex;
      for k:=0 to Hierarchy.Len-1 do
        if Hierarchy.Hierarchy[k].Index = j then begin
          L := Length(Hierarchy.Hierarchy[k].Children);
          SetLength(Hierarchy.Hierarchy[k].Children, L+1);
          Hierarchy.Hierarchy[k].Children[L] := Hierarchy.Hierarchy[i].Index;
        end;
    end;
end;

procedure T3DModel.CorrectPositionAndScale(Scale: Single);
var i,j,k,
    NPoints: integer;
    MaxBounding: TVector;
    ScaleFactor: Single;
begin
  with Obj3DModel.NamedObjs do
    for k:=0 to Len-1 do
      with NamedObjects[k] do begin
        Center := NullVector;
        BoundingBox.Min := NullVector;
        BoundingBox.Max := NullVector;
        NPoints := 0;
        for i:=0 to Length(TriObjs)-1 do begin
          with TriObjs[i] do begin
            for j:=0 to Length(Points)-1 do begin
              // center bepalen
              Center := AddVector(Center, Points[j]);
              // boundingbox bepalen tbv. positionering om de oorsprong
              if Points[j].X < BoundingBox.Min.X then BoundingBox.Min.X := Points[j].X;
              if Points[j].Y < BoundingBox.Min.Y then BoundingBox.Min.Y := Points[j].Y;
              if Points[j].Z < BoundingBox.Min.Z then BoundingBox.Min.Z := Points[j].Z;
              if Points[j].X > BoundingBox.Max.X then BoundingBox.Max.X := Points[j].X;
              if Points[j].Y > BoundingBox.Max.Y then BoundingBox.Max.Y := Points[j].Y;
              if Points[j].Z > BoundingBox.Max.Z then BoundingBox.Max.Z := Points[j].Z;
            end;
            Inc(NPoints, Length(TriObjs[i].Points));
          end;
        end;
        if NPoints > 0 then Center := ScaleVector(Center, 1/NPoints)
                       else Center := NullVector;
        // de mesh schalen zodat de grootste afstand (bounding.max-bounding.min) gelijk aan 1 wordt...
        MaxBounding := AbsVector(SubVector(BoundingBox.Min, BoundingBox.Max));
        ScaleFactor := Scale * (1.0 / Max(Max(MaxBounding.X, MaxBounding.Y), MaxBounding.Z));
        // object aanpassen...
        for i:=0 to Length(TriObjs)-1 do
          with TriObjs[i] do
            for j:=0 to Length(Points)-1 do
              Points[j] := ScaleVector(SubVector(Points[j], Center), ScaleFactor);
      end;
end;

procedure T3DModel.CalculateFaceNormals;
var i,j,k: integer;
begin
  with Obj3DModel.NamedObjs do
    for j:=0 to Length(NamedObjects)-1 do
      for k:=0 to Length(NamedObjects[j].TriObjs)-1 do
        with NamedObjects[j].TriObjs[k] do
          for i:=0 to Length(Faces)-1 do
            Faces[i].Normal := PlaneNormal(Points[Faces[i].V1], Points[Faces[i].V2], Points[Faces[i].V3]);
end;

procedure T3DModel.CalculateSmoothFaces;
type SharedFaces = array of Integer;
var N,T,FG,FI,F, i,L: integer;
    VI1,VI2,VI3: word;
    FN: TVector;
    NewLength, NrSmooths: integer;
    useTexturing: boolean;
    Shared: array of SharedFaces;
begin
  // elke Face heeft een eigen SmoothGroup toegekend.
  // De SmoothGroup-waarde kan ook 0 (nul) zijn, dan wordt voor die Face geen smoothing gebruikt.
  // Misschien moet een vertex, in zo'n Face, nog wel worden gedupliceerd,
  // als een aangrenzende Face aan die vertex wel smoothing gebruikt (waarde<>0).
  // (De noodzaak om te dupliceren duikt wel op bij de Faces die sowieso smoothing gebruiken.)
  //
  // stap 1: dupliceer punten zodat elk vlak naar 3 unieke vertex-indices verwijst..
  with NamedObjs do
    for N:=0 to Length(NamedObjects)-1 do                                       // alle meshes in 3DS
      for T:=0 to Length(NamedObjects[N].TriObjs)-1 do                          // alle triangle-objecten in mesh
        with NamedObjects[N].TriObjs[T] do begin
          NewLength := Length(Faces)*3;
          //
          useTexturing := (Length(TexCoords)>0);
          // elk vlak heeft 3 punten, met elk punt een normaal en texture-coordinaten, en een smoothgroup
          SetLength(SPoints, NewLength);         //array met smoothed vertices
          if useTexturing then
            SetLength(STexCoords, NewLength);    //array met smoothed vertex-texture coordinaten
          SetLength(SSmooth, NewLength);         //array met smoothgroup per vertex
          // alle punten (en referenties naar die punten) uniek maken..
          for FG:=0 to Length(FaceGroups)-1 do                                  // alle facegroups (faces met hetzelfde materiaal) in triangle-object
            for FI:=0 to Length(FaceGroups[FG].FaceIndex)-1 do begin            // alle faces in de facegroup
              // face-index
              F := FaceGroups[FG].FaceIndex[FI];
              // de vertex-index
              VI1 := Faces[F].V1;
              VI2 := Faces[F].V2;
              VI3 := Faces[F].V3;
              // smoothed vertices
              SPoints[VI1*3] := Points[VI1];
              SPoints[VI2*3] := Points[VI2];
              SPoints[VI3*3] := Points[VI3];
              // texture coordinaten
              if useTexturing then begin
                STexCoords[VI1*3] := TexCoords[VI1];
                STexCoords[VI2*3] := TexCoords[VI2];
                STexCoords[VI3*3] := TexCoords[VI3];
              end;
              // smoothgroup voor elke vertex
              if Length(SmoothingGroups) > 0 then begin
                SSmooth[VI1*3] := SmoothingGroups[F];
                SSmooth[VI2*3] := SmoothingGroups[F];
                SSmooth[VI3*3] := SmoothingGroups[F];
              end;
              // de face vertex-indices
              Faces[F].V1 := VI1*3;
              Faces[F].V2 := VI2*3;
              Faces[F].V3 := VI3*3;
            end;
          // alle nieuwe (hulp) arrays overnemen naar de "gewone" arrays
          SetLength(Points, NewLength);
          for i:=0 to NewLength-1 do Points[i] := SPoints[i];
          if useTexturing then begin
            SetLength(TexCoords, NewLength);
            for i:=0 to NewLength-1 do TexCoords[i] := STexCoords[i];
          end;
          // alle hulp-arrays legen
          SetLength(SPoints, 0);
          SetLength(STexCoords, 0);
        end;
  // stap 2: doorloop alle punten, maak arrays aan voor elk punt met daarin de
  //         vlakken die worden gedeeld door dat ene punt.
  with NamedObjs do
    for N:=0 to Length(NamedObjects)-1 do                                       // alle meshes in 3DS
      for T:=0 to Length(NamedObjects[N].TriObjs)-1 do                          // alle triangle-objecten in mesh
        with NamedObjects[N].TriObjs[T] do begin
          // de arrays voor gedeelde vlakken alloceren..
          SetLength(Shared, Length(Points));
          for i:=0 to Length(Shared)-1 do SetLength(Shared[i], 0);
          // alle faces doorlopen..
          for FG:=0 to Length(FaceGroups)-1 do                                  // alle facegroups (faces met hetzelfde materiaal) in triangle-object
            for FI:=0 to Length(FaceGroups[FG].FaceIndex)-1 do begin            // alle faces in de facegroup
              F := FaceGroups[FG].FaceIndex[FI];
              // de vertex-index
              VI1 := Faces[F].V1;
              VI2 := Faces[F].V2;
              VI3 := Faces[F].V3;
              // Face[F] wordt bevat punten VI1, VI2 & VI3..
              L := Length(Shared[VI1]);
              SetLength(Shared[VI1], L+1);
              Shared[VI1][L] := F;
              //
              L := Length(Shared[VI2]);
              SetLength(Shared[VI2], L+1);
              Shared[VI2][L] := F;
              //
              L := Length(Shared[VI3]);
              SetLength(Shared[VI3], L+1);
              Shared[VI3][L] := F;
            end;
          // stap 3: doorloop de gedeelde vlakken array,
          //         als een vlak smoothing gebruikt dan wordt de normaal van elk punt in het vlak
          //         gelijk aan het gemiddelde van de normalen van alle aangrenzende vlakken.
          //         (Maar dan alleen als de smoothing-group gelijk is van de aangrenzende vlakken.)
          NewLength := Length(Faces)*3;
          SetLength(SNormals, NewLength);
          for i:=0 to Length(Shared)-1 do begin
            SNormals[i] := NullVector;
            if Length(Shared[i])=0 then
              SNormals[i] := NullVector //zou niet voor moeten vallen, losse punten in space..
            else begin
              // smooth een aantal punten van verschillende vlakken
              NrSmooths := 0;
              for F:=0 to Length(Shared[i])-1 do begin
                FN := Faces[Shared[i][F]].Normal;
                // smoothing voor dit vlak gebruiken?
                if Length(SmoothingGroups) > 0 then begin
                  if SmoothingGroups[Shared[i][F]] = SSmooth[i] then begin
                    Inc(NrSmooths);
                    SNormals[i] := AddVector(SNormals[i], FN);
                  end;
                end else
                  SNormals[i] := FN;
              end;
              SNormals[i] := Unitvector(ScaleVector(SNormals[i], 1/NrSmooths));
            end;
          end;
          // de hulp-array SSmooth kan weg..
          SetLength(SSmooth, 0);
          // de final Normals array overnemen
          SetLength(Normals, NewLength);
          for i:=0 to NewLength-1 do Normals[i] := SNormals[i];
          SetLength(SNormals, 0);
        end;
end;

procedure T3DModel.CorrectTransparentOrder;
var N,T,M,FG: integer;
    AFaceGroup: TFaceGroup;
begin
  with NamedObjs do
    for N:=0 to Length(NamedObjects)-1 do                                       // alle meshes in 3DS
      for T:=0 to Length(NamedObjects[N].TriObjs)-1 do                          // alle triangle-objecten in mesh
        with NamedObjects[N].TriObjs[T] do begin
          for FG:=0 to Length(FaceGroups)-1 do begin                            // alle facegroups (faces met hetzelfde materiaal) in triangle-object
            M := Materials.NameToIndex(FaceGroups[FG].MaterialName);
            if M > Materials.Len-1 then Continue; //ongeldig materiaal? volgende pakken..
            if Materials.Material[M].Transparency > 0.0 then begin
              // deze facegroup verplaatsen naar het laatste element in de array
              // zodat transparante objecten als laatst worden getekend, over de
              // rest van dit NamedObject..
              AFaceGroup := FaceGroups[FG];
              FaceGroups[FG] := FaceGroups[Length(FaceGroups)-1];
              FaceGroups[Length(FaceGroups)-1] := AFaceGroup;
            end;
          end;
        end;
end;

procedure T3DModel.CorrectAnimations;
var M,RM: TMatrix4x4;
    Index,HI,PI: SmallInt;
    //--------------------------------------------------------------------------
    function MatrixConv(M1: TMatrix) : TMatrix4x4;
    begin
      Result := Matrix4x4(  M1.V[0].X,  M1.V[0].Y,  M1.V[0].Z,  0.0,
                            M1.V[1].X,  M1.V[1].Y,  M1.V[1].Z,  0.0,
                            M1.V[2].X,  M1.V[2].Y,  M1.V[2].Z,  0.0,
                            M1.V[3].X,  M1.V[3].Y,  M1.V[3].Z,  1.0 );
    end;
    //--------------------------------------------------------------------------
begin
  // doorloop alle objecten..
  for Index:=0 to NamedObjs.Len-1 do begin
    // is er wel een animatie voor dit object(Index)?
    // ..anders staat het object al in zijn goede stand.
    with NamedObjs.NamedObjects[Index] do begin
      M := IdentityMatrix4x4;
      if (Length(Animation.Rotation)>0) or (Length(Animation.Position)>0) then begin
        // is dit een child-object met een parent??
        // Indien niet het geval, dan is dit object al juist getransformeerd (frame 0) en hoeven we niets te doen.
        HI := Hierarchy.ObjIndexToHierarchyIndex(Index);
        if HI <> -1 then begin
          PI := Hierarchy.Hierarchy[HI].ParentIndex;
          if PI <> -1 then begin

            // De keyframer data converteren naar een transformatie-matrix (frame 0)
            // Punten zijn al op hun eind-positie (world-coords), en we moeten ze terug zien te krijgen naar
            // hun orginele posities om ze verder te kunnen transformeren.
            M := MatrixConv(MeshMatrix);
            InverseMatrix(M);
            // het pivot-point
            M[3,0] := M[3,0] - PivotPoint.X;
            M[3,1] := M[3,1] - PivotPoint.Y;
            M[3,2] := M[3,2] - PivotPoint.Z;

            //---schaling
            {}
            //---rotatie
            if (Length(Animation.RotKeyHeaders)>0) and (Animation.RotKeyHeaders[0].Time=0) then begin
              with Animation.Rotation[0] do
                RM := MultiplyMatrix(MultiplyMatrix(XRotationMatrix(X*Angle), YRotationMatrix(Y*Angle)), ZRotationMatrix(Z*Angle));
              M := MultiplyMatrix(M, RM);
            end;
            //---translatie
            if (Length(Animation.PosKeyHeaders)>0) and (Animation.PosKeyHeaders[0].Time=0) then begin
              with Animation.Position[0] do begin
                M[3,0] := M[3,0] + X;
                M[3,1] := M[3,1] + Y;
                M[3,2] := M[3,2] + Z;
              end;
            end;

            // Hele transformatie van alle parents doorvoeren..
            // voor dit child-object.
            while (PI<>-1) do begin
              with NamedObjs.NamedObjects[PI] do begin
                if (Length(Animation.Rotation)>0) or (Length(Animation.Position)>0) then begin
                  //---schaling
                  {}
                  //---rotatie
                  if (Length(Animation.RotKeyHeaders)>0) and (Animation.RotKeyHeaders[0].Time=0) then begin
                    with Animation.Rotation[0] do
                      RM := MultiplyMatrix(MultiplyMatrix(XRotationMatrix(X*Angle), YRotationMatrix(Y*Angle)), ZRotationMatrix(Z*Angle));
                    M := MultiplyMatrix(M, RM);
                  end;
                  //---translatie
                  if (Length(Animation.PosKeyHeaders)>0) and (Animation.PosKeyHeaders[0].Time=0) then begin
                    with Animation.Position[0] do begin
                      M[3,0] := M[3,0] + X;
                      M[3,1] := M[3,1] + Y;
                      M[3,2] := M[3,2] + Z;
                    end;
                  end;

                  // de parent van dit child..
                  HI := Hierarchy.ObjIndexToHierarchyIndex(PI);
                  if HI = -1 then PI := -1
                             else PI := Hierarchy.Hierarchy[HI].ParentIndex;
                end;
              end;
            end;

          end;
        end;
      end;

      // de inverse matrix is nu berekend, opslaan in het object
      InverseMeshMatrix := M;

    end;
  end;

end;




procedure T3DModel.InitTextures;
var i: integer;
begin
  // laad de textures
  for i:=0 to Materials.Len-1 do
    with Materials.Material[i] do begin
      // texture
      if Texture.Name <> '' then
        Texture.Handle := {fOpenGL.}OGL.Textures.LoadTexture(Texture.Name, 1.0)
      else
        Texture.Handle := 0;
      // reflectie texture
      if Reflection.Name <> '' then
        Reflection.Handle := {fOpenGL.}OGL.Textures.LoadTexture(Reflection.Name, 1.0)
      else
        Reflection.Handle := 0;
    end;
end;

procedure T3DModel.FreeTextures;
var i: integer;
begin
  for i:=0 to Materials.Len-1 do
    with Materials.Material[i] do begin
      {fOpenGL.}OGL.Textures.DeleteTexture(Texture.Handle);
      {fOpenGL.}OGL.Textures.DeleteTexture(Reflection.Handle);
    end;
end;



procedure T3DModel.DisplayModel;
var i,R: integer;
begin
  if not ModelLoaded then Exit;
  glDepthFunc(GL_LESS);
  glPolygonMode(GL_FRONT, GL_FILL);
  glFrontFace(GL_CCW);
  glCullFace(GL_BACK);
  glEnable(GL_CULL_FACE);
  glColor3f(1.0, 1.0, 1.0);
  glDisable(GL_BLEND);
  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);

  // Alle root-objecten afbeelden (met hun children)..
  SetLength(AlreadyDrawn, 0);  //markeringen "object al getekend" uit
(*test
    for i:=0 to NamedObjs.Len-1 do
      with NamedObjs.NamedObjects[i] do
        if DisplayList<>0 then DisplayTreeObject(i); //glCallList(DisplayList);
*)
  if Hierarchy.Len = 0 then begin
    // Er is geen (root)parent met evt. children; Teken alle objecten..
    // (een object zonder parent staat al in positie..op frame 0)
    for i:=0 to NamedObjs.Len-1 do
      with NamedObjs.NamedObjects[i] do
        if DisplayList<>0 then glCallList(DisplayList);
  end else
    for i:=0 to Hierarchy.Len-1 do begin
      R := Hierarchy.Hierarchy[i].Root;
      if R <> -1 then DisplayTreeObject(R); //teken (sub)tree vanaf deze root
    end;
    
  // volgende frame selecteren voor alle NamedObjects in dit hele Model
  Inc(Frame);
  if Frame>MaxFrames then Frame := 0;
end;

procedure T3DModel.DisplayObject(Index: SmallInt);
var j,k, HI,
    Tri,FG,F,FI,M,C,
    P1,P2,P3: integer;
    useNormals,useTextures,useReflection: boolean;
    ReflectionNormal: TVector;
begin
  //glPushMatrix;
  // de transformatie van dit object instellen..

  //
  j := Length(NamedObjs.NamedObjects[Index].TriObjs);
  // alle TRI_OBJs doorlopen van dit object..
  for Tri:=0 to j-1 do begin
    with NamedObjs.NamedObjects[Index].TriObjs[Tri] do begin
      // Normalen gebruiken?
      useNormals := {(Length(Normals)>0)} true;  //zelf berekend, altijd gebruikt..
      // Het aantal FaceGroups doorlopen..
      k := Length(FaceGroups);
      for FG:=0 to k-1 do begin
        // Materiaal-eigenschappen instellen..
        M := Materials.NameToIndex(FaceGroups[FG].MaterialName);
        if (M<0) or (M>Materials.Len-1) then Continue; //ongeldig materiaal? volgende pakken..
        // textures gebruiken?
        useTextures := ((Length(TexCoords)>0) and (Materials.Material[M].Texture.Handle>0));
        // reflectie-map gebruiken?
        useReflection := ((Length(TexCoords)>0) and (Materials.Material[M].Reflection.Handle>0));
        //
        glColor3fv(@Materials.Material[M].Diffuse); //standaard kleur
        glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, @Materials.Material[M].Ambient);
        glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, @Materials.Material[M].Diffuse);
        glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, @Materials.Material[M].Specular);
        glMaterialfv(GL_FRONT_AND_BACK, GL_SHININESS, @Materials.Material[M].Shininess);

        // doorzichtigheid
        if Materials.Material[M].Transparency < 1.0 {> 0.0} then begin
          with Materials.Material[M] do glColor4f(Diffuse.R,Diffuse.G,Diffuse.B,Transparency); //alpha transparant
          {glDepthMask(GL_FALSE);}
          glDepthFunc(GL_LEQUAL);
          glDepthMask(GL_TRUE);
          glEnable(GL_BLEND);
          glBlendFunc(GL_ONE_MINUS_SRC_ALPHA, GL_SRC_ALPHA);
          {glBlendFunc(GL_ONE_MINUS_SRC_COLOR, GL_SRC_COLOR);}
          glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, @Materials.Material[M].Emission);
        end else begin
          glColor3fv(@Materials.Material[M].Diffuse); //standaard kleur
          {with Materials.Material[M] do glColor4f(Diffuse.R,Diffuse.G,Diffuse.B,1.0); //alpha transparant}
          glBlendFunc(GL_ONE, GL_ZERO);
          glDisable(GL_BLEND);
          glDepthMask(GL_TRUE);
          // Zelf-oplichtende objecten (self-illuminant) worden als wit afgebeeld als
          // ze ook transparant zijn (tenminste nu nog!). Daarom worden vooralsnog
          // alleen objecten die niet transparant zijn, ingesteld op emission.
          glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, @Materials.Material[M].Emission);
        end;
        // punt-richting
        {if version3DS >= 3 then glFrontFace(GL_CCW) else glFrontFace(GL_CW);}
        glFrontFace(GL_CCW);
        // WireFrame afbeelden
        if WireFrame then begin
          glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
          glDisable(GL_CULL_FACE);
        end else
          // Twee-Zijdig afbeelden
          if Materials.Material[M].TwoSided then begin
            glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
            glDisable(GL_CULL_FACE);
          end else begin
            glPolygonMode(GL_FRONT, GL_FILL);
            glEnable(GL_CULL_FACE);
          end;
        // texturing instellen
        if useTextures then begin
          glEnable(GL_TEXTURE_2D);
          glBindTexture(GL_TEXTURE_2D, Materials.Material[M].Texture.Handle);
        end else
          glDisable(GL_TEXTURE_2D);
        // teken de faces die zijn opgenomen in de FaceGroup..
        for F:=0 to Length(FaceGroups[FG].FaceIndex)-1 do begin
          FI := FaceGroups[FG].FaceIndex[F];
          P1 := Faces[FI].V1;
          P2 := Faces[FI].V2;
          P3 := Faces[FI].V3;
          glBegin(GL_TRIANGLES);
            glNormal3f(Normals[P1].X, Normals[P1].Y, Normals[P1].Z);
            if useTextures then glTexCoord2f(TexCoords[P1].U, TexCoords[P1].V);
            glVertex3f(Points[P1].X, Points[P1].Y, Points[P1].Z);
            glNormal3f(Normals[P2].X, Normals[P2].Y, Normals[P2].Z);
            if useTextures then glTexCoord2f(TexCoords[P2].U, TexCoords[P2].V);
            glVertex3f(Points[P2].X, Points[P2].Y, Points[P2].Z);
            glNormal3f(Normals[P3].X, Normals[P3].Y, Normals[P3].Z);
            if useTextures then glTexCoord2f(TexCoords[P3].U, TexCoords[P3].V);
            glVertex3f(Points[P3].X, Points[P3].Y, Points[P3].Z);
          glEnd;
        end;
        // reflectie texture instellen -----------------------------------------
        if useReflection then begin
          glDisable(GL_LIGHTING);
          glEnable(GL_TEXTURE_2D);
          // blending instellen
          glDepthFunc(GL_LEQUAL);
          glEnable(GL_BLEND);
          glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ONE);    //GL_ONE,GL_ONE
          // env.mapping aanzetten
          glEnable(GL_TEXTURE_GEN_S);
          glEnable(GL_TEXTURE_GEN_T);
          // de kleur en andere reflectie-eigenschappen instellen
          glColor3f(1,1,1);
          glMaterialf(GL_FRONT, GL_SHININESS, Materials.Material[M].Reflection.Blend);
          // de reflectie texture
          glBindTexture(GL_TEXTURE_2D, Materials.Material[M].Reflection.Handle);
          // teken de faces die zijn opgenomen in de FaceGroup..
          for F:=0 to Length(FaceGroups[FG].FaceIndex)-1 do begin
            FI := FaceGroups[FG].FaceIndex[F];
            P1 := Faces[FI].V1;
            P2 := Faces[FI].V2;
            P3 := Faces[FI].V3;
            glBegin(GL_TRIANGLES);
              ReflectionNormal := ScaleVector(Normals[P1], 0.5);
              glNormal3f(ReflectionNormal.X, ReflectionNormal.Y, ReflectionNormal.Z);
              glVertex3f(Points[P1].X, Points[P1].Y, Points[P1].Z);
              //
              ReflectionNormal := ScaleVector(Normals[P2], 0.5);
              glNormal3f(ReflectionNormal.X, ReflectionNormal.Y, ReflectionNormal.Z);
              glVertex3f(Points[P2].X, Points[P2].Y, Points[P2].Z);
              //
              ReflectionNormal := ScaleVector(Normals[P3], 0.5);
              glNormal3f(ReflectionNormal.X, ReflectionNormal.Y, ReflectionNormal.Z);
              glVertex3f(Points[P3].X, Points[P3].Y, Points[P3].Z);
            glEnd;
          end;
          // environment-mapping uitschakelen
          glDisable(GL_TEXTURE_GEN_S);
          glDisable(GL_TEXTURE_GEN_T);
          glDisable(GL_BLEND);
          glBlendFunc(GL_ONE, GL_ZERO);
          glDepthFunc(GL_LESS);
        end;
      end;
    end;
  end;

  // Teken de children van dit object..
  HI := Obj3DModel.Hierarchy.ObjIndexToHierarchyIndex(Index);
  if HI <> -1 then begin
    //Hierarchy.Hierarchy[HI].Name == Obj3DModel.NamedObjs.NamedObjects[Hierarchy.Hierarchy[HI].Index].Name
    j := Length(Hierarchy.Hierarchy[HI].Children);
    for C:=0 to j-1 do DisplayObject(Hierarchy.Hierarchy[HI].Children[C]);
  end;

  //glPopMatrix;
end;


procedure T3DModel.DisplayTreeObject(Index: SmallInt);
var C: integer;
    HI: SmallInt;
    Done: boolean;
begin
  if Index = -1 then Exit;
  // OpenGL matrix bewaren
  glPushMatrix;
  with NamedObjs.NamedObjects[Index] do begin
    // is dit object al getekend?
    Done := false;
    for C:=0 to Length(AlreadyDrawn)-1 do
      if AlreadyDrawn[C] = Index then begin
        Done := true;
        Break;
      end;
    if not Done then begin

      {// object centreren
      with Center do glTranslatef(-X,-Y,-Z);}

      // transformatie van het dit object:
      {GoToFrame(Index, Frame);}

      // teken dit object
      if DisplayList<>0 then begin
        // tekenen..
        glCallList(DisplayList);
(*
        // de inverse pivot-points tekenen als dikke groene punten..
        with inversePivotPoint do begin
          glPointSize(10);
          glBegin(GL_POINTS);
            glColor3f(0,0.7,0);
            glVertex3f(X,Y,Z);
          glEnd
        end;
*)        
(*
        // de pivot-points tekenen als dikke rode punten..
        with PivotPoint do begin
          glPointSize(10);
          glBegin(GL_POINTS);
            glColor3f(0.7,0,0);
            glVertex3f(X,Y,Z);
          glEnd
        end;
*)
      end;
      // markering aan object getekend..
      C := Length(AlreadyDrawn);
      SetLength(AlreadyDrawn, C+1);
      AlreadyDrawn[C] := Index;
    end;
  end;

  // Teken de children van dit object..
  HI := Hierarchy.ObjIndexToHierarchyIndex(Index);
  if HI <> -1 then
    for C:=0 to Length(Hierarchy.Hierarchy[HI].Children)-1 do
      DisplayTreeObject(Hierarchy.Hierarchy[HI].Children[C]);

  // OpenGL matrix herstellen
  glPopMatrix;
end;







procedure T3DModel.CreateDisplayLists;
var N: integer;
    DL: GLuint;
begin
  // OpenGL display-lists aanmaken voor elke NamedObject
  with NamedObjs do
    for N:=0 to Length(NamedObjects)-1 do                                       // alle meshes in 3DS
      with NamedObjects[N] do begin
        DisplayList := 0;
        if Length(TriObjs) > 0 then begin
          DL := glGenLists(1);
          // de displaylist handle overnemen naar dit object
          DisplayList := DL;
          //0 = niet gelukt een DisplayList te maken door OpenGL
          if DL <> 0 then begin
            glNewList(DL, GL_COMPILE);  // een nieuwe displaylist aanmaken met handle DL
              glPushMatrix;
              //glMultMatrixf(@InverseMeshMatrix);
              DisplayObject(N);         // dit Named-Object tekenen
              glPopMatrix;
            glEndList;                  // einde displaylist.
          end;
        end;
      end;
end;

procedure T3DModel.DeleteDisplayLists;
var N: integer;
begin
  // OpenGL display-lists aanmaken voor elke NamedObject
  with NamedObjs do
    for N:=0 to Length(NamedObjects)-1 do                                       // alle meshes in 3DS
      with NamedObjects[N] do begin
        if DisplayList <> 0 then glDeleteLists(DisplayList, 1);
      end;
end;

initialization
  Obj3DModel := T3DModel.Create;

finalization
  Obj3DModel.Clear;
  Obj3DModel.Free;


end.
