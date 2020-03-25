unit uConst;
interface

const
  // de OpenGL far-plane van het frustum
  MaxViewDistance = 5000.0;

  // de grootte van de skybox
  // Dit is de afstand camera-SkyBox (de helft van de totale grootte dus)
  //  => Size² + sqrt(Size² + Size²) = MaxViewDistance
  SkyBoxSize = MaxViewDistance / 1.75; // in uOpenGL

implementation

end.
