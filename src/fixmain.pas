{ The main program: the title menu, character generation, the copy-protection check and the game loop, repeated until
  the player quits. }
{$F+,O+,I-,R-,S-}
program FixMain;

uses
  Overlay,
  Dos,
  Crt,
  GDConsts, GDVars,
  ModeInit,
  SoundDrv,
  Joystick,
  Mouse,
  GameIo,
  DaxIo,
  SndLoad,
  TextRend,
  Blit,
  GameBoot,
  Sym8x8,
  Border,
  Debug,
  MapTiles,
  CbtMap,
  Pathing,
  EmptyC,
  View3D,
  Portrait,
  MapView,
  MenuCore,
  ClassCal,
  CharHlp,
  FxEngine,
  Magic,
  Money,
  GameTime,
  ViewChar,
  SaveLoad,
  CharGen,
  Camp,
  MapCurs,
  Explore,
  CbtActs,
  EffHndlr,
  GameInit,
  CombatSt,
  CombatAi,
  Combat,
  EclMenu,
  Shop,
  PostCbt,
  Temple,
  CopyProt,
  EclVm,
  Intro,
  HeapErr,
  C_Ifc, Types;

{$O HeapErr}
{$O Intro}
{$O EclVm}
{$O CopyProt}
{$O Temple}
{$O PostCbt}
{$O Shop}
{$O EclMenu}
{$O Combat}
{$O CombatAi}
{$O CombatSt}
{$O GameInit}
{$O EffHndlr}
{$O CbtActs}
{$O Explore}
{$O MapCurs}
{$O Camp}
{$O SaveLoad}
{$O CharGen}
{$O ViewChar}
{$O GameTime}
{$O Money}
{$O Magic}
{$O FxEngine}
{$O CharHlp}
{$O ClassCal}
{$O MenuCore}
{$O MapView}
{$O Portrait}
{$O View3D}
{$O Pathing}
{$O CbtMap}
{$O MapTiles}
{$O Debug}
{$O Sym8x8}

begin
  InitializeGame;
  { cheat gate }
  if ParamStr(1) <> 'Woof' then Introduction;
  StartSound;
  GDVars.autoTimeout := 3000; GDVars.timerCh := 'D';
  GDVars.menuSelection := MenuHorizontal('Champions of Krynn v1.0', 'Play Demo', LightMagenta,
                                  LightGreen, White, False, False, GDVars.extendedKey);
  GDVars.autoTimeout := 0; GDVars.timerCh := #0;
  if GDVars.menuSelection = 'D' then GDVars.demoFlag := 1;
  repeat
    if GDVars.demoFlag <> 0 then begin GDVars.currentDisk := 2; GDVars.gameDelay := 9 end
    else GDVars.currentDisk := 1;
    if GDVars.soundActive <> 0 then SoundCommand(GDConsts.sndStop);
    PrimeCharGen;
    if GDVars.soundActive = 0 then StartSound;
    if GDVars.demoFlag = 0 then begin
      MainMenu;
      { the cheat compare }
      if ParamStr(2) <> GDVars.cmpStr then begin
        if CopyProtection <> 1 then GameIo.ExitGame;
        for GDVars.partySlot := 1 to 4 do
          if GDVars.protMark[GDVars.partySlot] = 0 then GameIo.ExitGame;
      end;
      if (GDVars.interfaceState = C_Ifc.OVERLAND) and (GDVars.zone0^.areaView = 0)
        then DrawRowDivider
        else DrawViewFrame;
      DisplayParty(GDVars.curChar);
    end;
    if GDVars.soundActive <> 0 then SoundCommand(GDConsts.sndStop);
    View3D.PrimeView3D;
    if GDVars.soundActive = 0 then StartSound;
    View3D.SetView3DColors(GDVars.viewColSky, GDVars.viewHorizonUpper, GDVars.viewHorizonLower,
                           GDVars.viewColFloor);
    if GDVars.soundActive <> 0 then SoundCommand(GDConsts.sndStop);
    PrimeEclVm;
    if GDVars.soundActive = 0 then StartSound;
    GameLoop;
    if GDVars.soundActive <> 0 then SoundCommand(GDConsts.sndStop);
    PrimeGameInit;
    if GDVars.soundActive = 0 then StartSound;
    ResetGameState;
    { demo exit }
    if GDVars.demoFlag <> 0 then begin
      SoundCommand(GDConsts.sndStop);
      Introduction;
      StartSound;
      FlushKeys;
      GDVars.autoTimeout := 1000; GDVars.timerCh := 'D';
      GDVars.menuSelection := MenuHorizontal('Champions Of Krynn v1.0', 'Play Demo', LightMagenta, LightGreen, White,
                                      False, False, GDVars.extendedKey);
      GDVars.autoTimeout := 0; GDVars.timerCh := #0;
      GDVars.demoFlag := Ord(GDVars.menuSelection = 'D');
      SoundCommand(GDConsts.sndSilence);
    end;
  until False;
end.
