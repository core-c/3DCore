unit uTerrain;
interface
uses OpenGL, u3DTypes, uCalc, uOpenGL, FormOpenGL, Graphics;

const
  // de pixeldimensies van de heightmap-afbeelding
  HeightMapWidth  = 128;
  HeightMapDepth  = 128;
  // de dimensies van het terrein
  TerrainWidth    = 2000;  //X
  TerrainDepth    = 2000;  //Z

type
  TVector3i = packed record
    X,Y,Z: Integer;
  end;

  TTerrainVertex = record
    Position: TVector3f;
    TexCoord,
    RoadCoord: TVector2f;
    Color: TRGB;
  end;

  TTerrain = class(TObject)
  private
    HeightMap: TBitmap;
    Vertex: array[0..HeightMapWidth-1, 0..HeightMapDepth-1] of TTerrainVertex;
    RatioW, RatioD: single;
    //
    local_TerrainLoaded: boolean;
    //
    procedure GenerateTriangleStrip;
    function ColorToHeight(C: TColor): single;
  public
    //
    constructor Create;
    destructor Destroy; override;
    //
    procedure Init(TerrainTextureFilename: string);
    procedure Clear;
    function IsTerrainLoaded: boolean;
    procedure LoadBitmap(Filename: string);
    procedure DisplayTerrain(Position: TVector);
  end;


var Terrain: TTerrain;
    Terrain0_TextureHandle,
    Terrain1_TextureHandle: GLuint;



implementation
uses uTexture{, Math};

{ TTerrain }
constructor TTerrain.Create;
begin
  HeightMap := TBitmap.Create;
  local_TerrainLoaded := false;
end;

destructor TTerrain.Destroy;
begin
  HeightMap.Free;
  //
  inherited;
end;



function TTerrain.IsTerrainLoaded: boolean;
begin
  Result := local_TerrainLoaded;
end;

procedure TTerrain.Clear;
begin
  local_TerrainLoaded := false; 
end;

function TTerrain.ColorToHeight(C: TColor): single;
begin
  Result := ((C shr 16 and $FF) + (C shr 8 and $FF) + (C and $FF)) / 3;
end;

procedure TTerrain.GenerateTriangleStrip;
var x,y,z: single;
    i,j: integer;
    RW,RD: single;
begin
  RatioW := TerrainWidth / HeightMapWidth;
  RatioD := TerrainDepth / HeightMapDepth;
  RW := 1 / HeightMapWidth;
  RD := 1 / HeightMapDepth;
  for i:=0 to HeightMapWidth-1 do begin
    for j:=0 to HeightMapDepth-1 do begin
      Vertex[i,j].Position.X := i * RatioW;
      Vertex[i,j].Position.Y := ColorToHeight(HeightMap.Canvas.Pixels[i,j]);
      Vertex[i,j].Position.Z := j * RatioD;
      Vertex[i,j].TexCoord.X := i*RW; //texture
      Vertex[i,j].TexCoord.Y := j*RD;
    end;
  end;
end;

procedure TTerrain.LoadBitmap(Filename: string);
begin
  HeightMap.LoadFromFile(Filename);
end;

procedure TTerrain.Init(TerrainTextureFilename: string);
begin
  // de afbeelding met de hoogtemap.
  // kleur(0,0,0) = hoogte 0, kleur(255,255,255) = hoogte 255 (gemiddelde van RGB)
  Terrain.LoadBitmap(TerrainTextureFilename);
  // De tringle_strips aanmaken
  RatioW := TerrainWidth / HeightMapWidth;
  RatioD := TerrainDepth / HeightMapDepth;
  Terrain.GenerateTriangleStrip;
  // texture aanmaken..
  Terrain0_TextureHandle := {fOpenGL.}OGL.Textures.LoadTexture('terrain0.jpg');
  Terrain1_TextureHandle := {fOpenGL.}OGL.Textures.LoadTexture('terrain1.jpg');
  local_TerrainLoaded := true;
end;

procedure TTerrain.DisplayTerrain(Position: TVector);
const MinCamHeightAboveTerrain = 54.0;
var i,j: integer;
    d, s,s2,resti,restj: single;
    N,V: TVector;
    rW,rD: single;
begin
  if not local_TerrainLoaded then Exit;

  glPushMatrix;
  // als Position Y boven het terrain en binnen de X,Z-boundries
  // dan collision-detection gebruiken..
  if (Position.X > 0) and (Position.X < TerrainWidth) then
    if (Position.Z > 0) and (Position.Z < TerrainDepth) then begin
      RatioW := TerrainWidth / HeightMapWidth;
      RatioD := TerrainDepth / HeightMapDepth;
      // Position ligt binnen de grenzen van het terrein, recht boven het terrein nu..
      // test of de hoogte van Position < dan de terrein-hoogte is, dan herstellen tot net boven de oppervlakte.
      // dwz. de oppervlakte van het huidige triangle_stripje van de strip..
      i := Trunc(Position.X / RatioW);    resti := Frac(Position.X / RatioW);
      j := Trunc(Position.Z / RatioD);    restj := Frac(Position.Z / RatioD);

      {s := Vertex[i,j].Y;}
      {s := (Vertex[i,j].Y + Vertex[i+1,j].Y + Vertex[i,j+1].Y + Vertex[i+1,j+1].Y) / 4;}
      {s := Max(Max(Max(Vertex[i,j].Y, Vertex[i+1,j].Y), Vertex[i,j+1].Y), Vertex[i+1,j+1].Y);}

      if resti * restj <= 0.5 then begin
        s := (resti * (Vertex[i+1,j].Position.Y - Vertex[i,j].Position.Y));
        s2 := (restj * (Vertex[i,j+1].Position.Y - Vertex[i,j].Position.Y));
        s := Vertex[i,j].Position.Y + (s+s2);
      end else begin
        s := (resti * (Vertex[i+1,j].Position.Y - Vertex[i+1,j+1].Position.Y));
        s2 := (restj * (Vertex[i,j+1].Position.Y - Vertex[i+1,j+1].Position.Y));
        s := Vertex[i+1,j+1].Position.Y + (s+s2);
      end;

      if Position.Y < s+MinCamHeightAboveTerrain then begin
        glTranslatef(0, -(s+MinCamHeightAboveTerrain-Position.Y), 0);
      end;
    end;

  glEnable(GL_CULL_FACE);
  glFrontFace(GL_CW);
  glDisable(GL_BLEND);
  //textures..
  if (Terrain0_TextureHandle = 0) and (Terrain1_TextureHandle = 0) then begin
    glDisable(GL_TEXTURE_2D);
    for i:=0 to HeightMapWidth-2 do begin
      glBegin(GL_TRIANGLE_STRIP);
        j:=0;
        glVertex3f(Vertex[i,j].Position.X,     Vertex[i,j].Position.Y,     Vertex[i,j].Position.Z);
        glVertex3f(Vertex[i+1,j].Position.X,   Vertex[i+1,j].Position.Y,   Vertex[i+1,j].Position.Z);
        for j:=1 to HeightMapDepth-2 do begin
          glVertex3f(Vertex[i,j+1].Position.X,   Vertex[i,j+1].Position.Y,   Vertex[i,j+1].Position.Z);
          glVertex3f(Vertex[i+1,j+1].Position.X, Vertex[i+1,j+1].Position.Y, Vertex[i+1,j+1].Position.Z);
        end;
      glEnd;
    end;
  end else begin
    glEnable(GL_TEXTURE_2D);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE); // mixen met de standaard vertex kleur..
    glBindTexture(GL_TEXTURE_2D, Terrain0_TextureHandle);
    for i:=0 to HeightMapWidth-2 do begin
      glBegin(GL_TRIANGLE_STRIP);
        j:=0;
        s := Vertex[i,j].Position.Y / 255;   glColor3f(s, s, s); //kleur
        glTexCoord2f(Vertex[i,j].TexCoord.X, Vertex[i,j].TexCoord.Y); //texture
        glVertex3f(Vertex[i,j].Position.X,     Vertex[i,j].Position.Y,     Vertex[i,j].Position.Z); //punt
        s := Vertex[i+1,j].Position.Y / 255;   glColor3f(s, s, s); //--
        glTexCoord2f(Vertex[i+1,j].TexCoord.X, Vertex[i+1,j].TexCoord.Y); //texture
        glVertex3f(Vertex[i+1,j].Position.X,   Vertex[i+1,j].Position.Y,   Vertex[i+1,j].Position.Z);
        for j:=1 to HeightMapDepth-2 do begin
          s := Vertex[i,j+1].Position.Y / 255;   glColor3f(s, s, s); //--
          glTexCoord2f(Vertex[i,j+1].TexCoord.X, Vertex[i,j+1].TexCoord.Y); //texture
          glVertex3f(Vertex[i,j+1].Position.X,   Vertex[i,j+1].Position.Y,   Vertex[i,j+1].Position.Z);
          s := Vertex[i+1,j+1].Position.Y / 255;   glColor3f(s, s, s); //--
          glTexCoord2f(Vertex[i+1,j+1].TexCoord.X, Vertex[i+1,j+1].TexCoord.Y); //texture
          glVertex3f(Vertex[i+1,j+1].Position.X, Vertex[i+1,j+1].Position.Y, Vertex[i+1,j+1].Position.Z);
        end;
      glEnd;
    end;

    // wegen tekenen..
    RatioW := 1 / HeightMapWidth;
    RatioD := 1 / HeightMapDepth;
    glDepthFunc(GL_LEQUAL);
    //glDepthMask(GL_FALSE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR);  //one,one
    glBindTexture(GL_TEXTURE_2D, Terrain1_TextureHandle);
    for i:=0 to HeightMapWidth-2 do begin
      glBegin(GL_TRIANGLE_STRIP);
        j:=0;
        s := 1.0;   glColor3f(s, s, s); //kleur
        glTexCoord2f(i*RatioW, j*RatioD); //texture
        glVertex3f(Vertex[i,j].Position.X,     Vertex[i,j].Position.Y,     Vertex[i,j].Position.Z); //punt
        s := 1.0;   glColor3f(s, s, s); //--
        glTexCoord2f((i+1)*RatioW, j*RatioD);
        glVertex3f(Vertex[i+1,j].Position.X,   Vertex[i+1,j].Position.Y,   Vertex[i+1,j].Position.Z);
        for j:=1 to HeightMapDepth-2 do begin
          s := 1.0;   glColor3f(s, s, s); //--
          glTexCoord2f(i*RatioW, (j+1)*RatioD);
          glVertex3f(Vertex[i,j+1].Position.X,   Vertex[i,j+1].Position.Y,   Vertex[i,j+1].Position.Z);
          s := 1.0;   glColor3f(s, s, s); //--
          glTexCoord2f((i+1)*RatioW, (j+1)*RatioD);
          glVertex3f(Vertex[i+1,j+1].Position.X, Vertex[i+1,j+1].Position.Y, Vertex[i+1,j+1].Position.Z);
        end;
      glEnd;
    end;
    //glDepthMask(GL_TRUE);

  end;
  glPopMatrix;
end;







initialization
  Terrain := TTerrain.Create;

finalization
  Terrain.Free;

end.
