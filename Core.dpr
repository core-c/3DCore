program Core;
uses
  windows,
  Messages,
  Forms,
  u3DTypes in 'u3DTypes.pas',
  uCalc in 'uCalc.pas',
  uCamera in 'uCamera.pas',
  uTexture in 'uTexture.pas',
  uOpenGL in 'uOpenGL.pas',
  uSkyBox in 'uSkyBox.pas',
  uLight in 'uLight.pas',
  uFont in 'uFont.pas',
  uMap in 'uMap.pas',
  uQuake3BSP in 'uQuake3BSP.pas',
  u3DModel in 'u3DModel.pas',
  u3DS in 'u3DS.pas',
  uPlayer in 'uPlayer.pas',
  FormOpenGL in 'FormOpenGL.pas',
  Unit1 in 'Unit1.pas',
  uDisplay in 'uDisplay.pas',
  uGame in 'uGame.pas',
  uParticles in 'uParticles.pas',
  uTerrain in 'uTerrain.pas';

{$R *.res}

var Msg: TMsg;
    AppTerminated: Boolean;

begin
  Application.Initialize;
  Application.Title := 'glCore';
  Application.CreateForm(Tf3DS, f3DS);
  Application.CreateForm(TfOpenGL, fOpenGL);
  // Ik wil een mainloop en heb daarvoor de TAppilication.Run procedure aangepast.
//  Application.Run;   //Run dan niet meer aanroepen..

  // Zelf het MainForm zichtbaar maken
  f3DS.Visible := True;

  // methode 1
  AppTerminated := false;
  repeat
    if (PeekMessage(Msg,0,0,0,PM_REMOVE)) then begin //een msg voor dit venster?
      if (Msg.message = WM_QUIT) then                //stoppen bij een WM_QUIT msg..
        AppTerminated := true
      else begin                                     //de msg verwerken
        TranslateMessage(Msg);
        DispatchMessage(Msg);
      end;
    end else begin
      // De routinés die ik in de mainloop wil laten uitvoeren..
      if {fOpenGL.}OGL.Active and (not {fOpenGL.}OGL.Paused) then begin
        // Een frame tekenen
        DrawFrame;
        // speciale toetsen status testen..
        CheckSpecialKeys;
      end;
    end;
  until AppTerminated;
(*
  // methode 2
  repeat
    try
      //Application.HandleMessage;  //onderbreek prg-uitvoer om msg's te verwerken
      Application.ProcessMessages;  //verwerk msg's "wanneer het uitkomt"..
    except
      Application.HandleException(Application);
    end;
    // De routinés die ik in de mainloop wil laten uitvoeren
    DrawFrame;
    //
  until Application.Terminated;
*)
end.
