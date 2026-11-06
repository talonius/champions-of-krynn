{ Game initialization, persistent graphics allocation, and soft-reset state. }
{$O+,F+,I-}
unit GameInit;

interface

{ One-time startup: forces Num Lock on, seeds Random, starts the mouse (probing whether its driver reports 640-wide
  coordinates) or centers the joystick, allocates the memory zones, font, wall graphics, map and the persistent picture
  buffers, builds the per-scanline CGA, EGA and Tandy address tables, and sets every game variable to its starting
  value. It then loads the font, the 8x8 symbol sets, the combat sprites, the sky tiles (not on CGA) and the mouse
  cursor, reads the base item table from ITEMS, and installs the spell and effect handlers. }
procedure InitializeGame;

{ Returns the game state to its starting values for a new game, keeping the buffers and artwork InitializeGame loaded:
  marks a game active, clears the dirty spans and the memory zones, places the party at its starting cell facing east,
  and resets the flags, counters and pointers that a game changes. }
procedure ResetGameState;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeGameInit;

implementation

uses Types, Crt, Blit, TextRend, Mouse, DaxIo, GDConsts, GDVars, EffHndlr, Explore,
  Magic, MenuCore, Portrait, MapTiles, Debug, Sym8x8, C_Dir, C_Gbvm, C_Ifc;

const
  INITIAL_MAP_X = 7;
  INITIAL_MAP_Y = 13;
  EMPTY_WALL_SLOT = -1;

var
  biosKbdFlags: Byte absolute $0000:$0417;

procedure PrimeGameInit;
begin
  Explore.PrimeExplore;
  Magic.PrimeMagic;
  Sym8x8.PrimeSym8x8;
  MapTiles.PrimeMapTiles;
  Portrait.PrimePortrait;
  EffHndlr.PrimeEffHndlr;
  MenuCore.PrimeMenuCore;
  Debug.PrimeDebug;
end;

procedure InitializeGame;
var
  { Unused in this version; see the other implementations of this routine. }
  inputLine: string;
begin
  { force Num Lock on }
  biosKbdFlags := biosKbdFlags or $20;
  Randomize;
  if GDVars.mouseOn then begin
    GDVars.partyPickEnabled := 1;
    GDVars.mouseButtonCount := 0;
    Mouse.InitMouse;
    if GDVars.mouseOn then begin
      GDVars.mouseScaled := True;
      if GDVars.displayMode = Types.Cga then
        GDVars.cursorMask := @GDConsts.cursorMaskCga
      else
        GDVars.cursorMask := @GDConsts.cursorMaskEga;
      Mouse.SetMouseCursor(0, 0, GDVars.cursorMask);
      { Probe the driver's X range: put the cursor at x = 639 and read it back. A reading of 321 or more means 640-wide
        coordinates, so mouseScaled stays False and Mouse halves X. }
      Mouse.SetMouse(639, 100);
      Mouse.GetMouse(GDVars.mouseButtons, GDVars.mouseSampleX, GDVars.mouseSampleY);
      GDVars.mouseScaled := (GDVars.mouseSampleX >= 321) = False;
      Mouse.ShowMouse;
    end;
    GDVars.mouseX := 160;
    GDVars.mouseY := 100;
    Mouse.SetMouse(GDVars.mouseX, GDVars.mouseY);
    GDVars.mouseOldX := 0;
    GDVars.mouseOldY := 0;
  end;
  if GDVars.joyOn then begin
    GDVars.joystickCenterX := 160;
    GDVars.joystickCenterY := 100;
  end;
  GetMem(GDVars.zone0, SizeOf(Types.TZone0));
  GetMem(GDVars.zone1, SizeOf(Types.TZone1));
  GetMem(GDVars.zone2, SizeOf(Types.TZone2));
  GetMem(GDVars.zone3, SizeOf(Types.TZone3));
  GetMem(GDVars.gameFont, SizeOf(Types.TFontTable));
  GetMem(GDVars.wallGfx, 2340);
  GetMem(GDVars.geo, SizeOf(Types.TGeoMap));
  Blit.AllocPic(8, 1, 1, 0, GDVars.cur8x8Buf);
  Blit.AllocPic(8, 1, 1, 0, GDVars.cursorBackground);
  Blit.AllocPic(8, 1, 1, 0, GDVars.cursorComposite);
  GDVars.cursorImg := nil;
  Blit.AllocPic(168, 21, 1, 0, GDVars.egaDest);
  Blit.AllocPic(24, 3, 1, 0, GDVars.saveUnder);
  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanY, SizeOf(GDVars.spanY), 0);
  FillChar(GDVars.spanX0, SizeOf(GDVars.spanX0), 255);
  FillChar(GDVars.spanX1, SizeOf(GDVars.spanX1), 0);
  for GDVars.initIndex := 0 to 199 do begin
    if Odd(GDVars.initIndex) then
      GDVars.cgaRowSeg[GDVars.initIndex] := (GDVars.initIndex div 2) * 5 + $BA00
    else
      GDVars.cgaRowSeg[GDVars.initIndex] := (GDVars.initIndex div 2) * 5 + $B800;
    GDVars.fbRowOfs[GDVars.initIndex] := GDVars.initIndex * 40;
    case GDVars.initIndex mod 4 of
      0: GDVars.tandyRowSeg[GDVars.initIndex] := (GDVars.initIndex div 4) * 10 + $B800;
      1: GDVars.tandyRowSeg[GDVars.initIndex] := (GDVars.initIndex div 4) * 10 + $BA00;
      2: GDVars.tandyRowSeg[GDVars.initIndex] := (GDVars.initIndex div 4) * 10 + $BC00;
      3: GDVars.tandyRowSeg[GDVars.initIndex] := (GDVars.initIndex div 4) * 10 + $BE00;
    end;
  end;
  FillChar(GDVars.symbolSetPtrs, SizeOf(GDVars.symbolSetPtrs), 0);
  FillChar(GDVars.tileSet1, SizeOf(GDVars.tileSet1) + SizeOf(GDVars.tileSet2), 0);
  Blit.AllocPic(24, 3, 48, 0, GDVars.tileSet1);
  FillChar(GDVars.zone0^, SizeOf(GDVars.zone0^), 0);
  GDVars.zone0^.vars[$4CF4] := 3;
  GDVars.zone0^.vars[C_Gbvm.VIEW_3D] := 1;
  GDVars.zone0^.vars[$4BF2] := 0;
  GDVars.zone0^.vars[$4CF9] := 2;
  GDVars.zone0^.vars[$4CFA] := 2;
  GDVars.zone0^.vars[$4CFB] := 2;
  FillChar(GDVars.zone1^, SizeOf(GDVars.zone1^), 0);
  FillChar(GDVars.zone2^, SizeOf(GDVars.zone2^), 0);
  FillChar(GDVars.zone3^, SizeOf(GDVars.zone3^), 0);
  FillChar(GDVars.iconAnims, SizeOf(GDVars.iconAnims), 0);
  for GDVars.initIndex := 1 to 2 do begin
    GDVars.portraits[GDVars.initIndex].fileId := 255;
    GDVars.portraits[GDVars.initIndex].pic := nil;
  end;
  FillChar(GDVars.bigAnim, SizeOf(GDVars.bigAnim), 0);
  GDVars.bigPicBuf := nil;
  GDVars.treasureItems := nil;
  FillChar(GDVars.mapState, SizeOf(Types.TMapState), 0);
  GDVars.mapState.x := GameInit.INITIAL_MAP_X;
  GDVars.mapState.y := GameInit.INITIAL_MAP_Y;
  GDVars.mapState.facing := C_Dir.NORTH;
  FillChar(GDVars.doorOpen, SizeOf(GDVars.doorOpen), 1);
  GDVars.wallSlots[1].id := 0;
  GDVars.wallSlots[1].slot := 1;
  for GDVars.initIndex := 2 to 3 do begin
    GDVars.wallSlots[GDVars.initIndex].id := GameInit.EMPTY_WALL_SLOT;
    GDVars.wallSlots[GDVars.initIndex].slot := GameInit.EMPTY_WALL_SLOT;
  end;
  GDVars.gameActive := 0;
  GDVars.soundDisabled := 0;
  GDVars.animationsEnabled := 1;
  GDVars.picturesEnabled := 1;
  GDVars.debugActive := 0;
  GDVars.slowText := 1;
  GDVars.loadedSave := 0;
  GDVars.restTicks := 0;
  GDVars.partyHead := nil;
  GDVars.curChar := nil;
  GDVars.eclIp := $8000;
  GDVars.gameDelay := 4;
  GDVars.demoFlag := 0;
  GDVars.currentDisk := 1;
  GDVars.prevDisk := 1;
  GDVars.automapOn := False;
  LastMode := 1;
  GDVars.zone1^.vars[C_Gbvm.PARTY_SIZE] := 0;
  GDVars.firstVisibleIndex := 1;
  GDVars.duelFlag := 0;
  GDVars.noBorder := 0;
  GDVars.searchBackup := 0;
  GDVars.boxCleared := 0;
  GDVars.printReturnFlag := 0;
  GDVars.eclGraphics := False;
  GDVars.partyDefeated := False;
  GDVars.initFlag := 1;
  GDVars.spriteShown := False;
  GDVars.suppressPrompt := #0;
  GDVars.picArcName[0] := #0;
  GDVars.savedPictureName[0] := #0;
  GDVars.picArcId := 255;
  GDVars.savedPictureId := 255;
  GDVars.recentlySaved := 0;
  GDVars.horizonColorSel := 232;
  GDVars.floorColorSel := 219;
  GDVars.inEncounterMenu := 0;
  GDVars.useAlternateSelection := 0;
  GDVars.gfxEnabled := 1;
  GDVars.bigPicId := 255;
  GDVars.cursorImageId := 0;
  GDVars.knightTrainingMode := 0;
  GDVars.horizontalChoice := 1;
  GDVars.interfaceState := C_Ifc.VIEW_3D;
  GDVars.previousLocationType := C_Ifc.MAIN_MENU;
  GDVars.soundActive := 1;
  GDVars.overrideFlag := 0;
  GDVars.specialView := 0;
  GDVars.frontTile := nil;
  GDVars.edgeTile := nil;
  GDVars.skyTile := nil;
  GDVars.bankHead := nil;
  GDVars.encounterStateFlag := 0;
  GDVars.creatureCursorActive := 0;
  GDVars.mapCursorActive := 0;
  GDVars.extendedMode := 0;
  GDVars.mouseButtonSeen := 0;
  GDVars.modifyActive := 0;
  FillChar(GDVars.explosionQueue, SizeOf(GDVars.explosionQueue), 0);
  GDVars.explosionCount := 0;
  GDVars.explosionBusy := 0;
  TextRend.loadGameFont;
  MenuCore.ClearBottomLine;
  TextRend.displayString(0, 24, LightGreen, Black, 'Loading...Please Wait');
  Sym8x8.Load8x8Set(202, 4);
  Sym8x8.Load8x8Set(203, 0);
  for GDVars.initIndex := 0 to 11 do
    MapTiles.LoadIconAnim('COMSPR', GDVars.initIndex, GDVars.initIndex + 13);
  MapTiles.LoadIconAnim('COMSPR', 25, 25);
  if GDVars.displayMode <> Types.Cga then begin
    Blit.LoadPic('sky', 250, True, LightMagenta, GDVars.frontTile);
    Blit.LoadPic('sky', 251, True, LightMagenta, GDVars.edgeTile);
    Blit.LoadPic('sky', 252, True, LightMagenta, GDVars.skyTile);
  end;
  Blit.LoadPic('cursor', 1, True, LightMagenta, GDVars.cursorImg);
  GDVars.itemsOk := DaxIo.OpenWithRetry('ITEMS', GDConsts.insertDiskMsg[GDVars.currentDisk], #0, GDVars.itemsFile);
  Reset(GDVars.itemsFile, 1);
  Seek(GDVars.itemsFile, 2);
  BlockRead(GDVars.itemsFile, GDVars.baseItems, SizeOf(GDVars.baseItems), GDVars.itemsRead);
  Close(GDVars.itemsFile);
  Magic.InitSpellFns;
  EffHndlr.InitEffectHandlers;
end;

procedure ResetGameState;
begin
  GDVars.gameActive := 1;
  GDVars.explosionBusy := 0;
  GDVars.soundDisabled := 0;
  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanY, SizeOf(GDVars.spanY), 0);
  FillChar(GDVars.spanX0, SizeOf(GDVars.spanX0), 255);
  FillChar(GDVars.spanX1, SizeOf(GDVars.spanX1), 0);
  FillChar(GDVars.zone0^, SizeOf(GDVars.zone0^), 0);
  GDVars.zone0^.vars[$4CF4] := 3;
  GDVars.zone0^.vars[C_Gbvm.VIEW_3D] := 1;
  GDVars.zone0^.vars[$4BF2] := 0;
  FillChar(GDVars.zone1^, SizeOf(GDVars.zone1^), 0);
  FillChar(GDVars.zone2^, SizeOf(GDVars.zone2^), 0);
  FillChar(GDVars.zone3^, SizeOf(GDVars.zone3^), 0);
  FillChar(GDVars.mapState, SizeOf(Types.TMapState), 0);
  GDVars.mapState.x := GameInit.INITIAL_MAP_X;
  GDVars.mapState.y := GameInit.INITIAL_MAP_Y;
  GDVars.mapState.facing := C_Dir.EAST;
  FillChar(GDVars.doorOpen, SizeOf(GDVars.doorOpen), 1);
  GDVars.partyPickEnabled := 1;
  GDVars.wallSlots[1].id := 0;
  GDVars.wallSlots[1].slot := 1;
  for GDVars.initIndex := 2 to 3 do begin
    GDVars.wallSlots[GDVars.initIndex].id := GameInit.EMPTY_WALL_SLOT;
    GDVars.wallSlots[GDVars.initIndex].slot := GameInit.EMPTY_WALL_SLOT;
  end;
  GDVars.debugActive := 0;
  GDVars.zone0^.vars[$4CF9] := 2;
  GDVars.zone0^.vars[$4CFA] := 2;
  GDVars.zone0^.vars[$4CFB] := 2;
  GDVars.slowText := 1;
  GDVars.loadedSave := 0;
  GDVars.restTicks := 0;
  GDVars.partyHead := nil;
  GDVars.curChar := nil;
  GDVars.eclIp := $8000;
  GDVars.gameDelay := 4;
  GDVars.currentDisk := 1;
  GDVars.prevDisk := 1;
  GDVars.automapOn := False;
  LastMode := 1;
  GDVars.zone1^.vars[C_Gbvm.PARTY_SIZE] := 0;
  GDVars.firstVisibleIndex := 1;
  GDVars.duelFlag := 0;
  GDVars.noBorder := 0;
  GDVars.searchBackup := 0;
  GDVars.boxCleared := 0;
  GDVars.printReturnFlag := 0;
  GDVars.eclGraphics := False;
  GDVars.partyDefeated := False;
  GDVars.initFlag := 1;
  GDVars.spriteShown := False;
  GDVars.suppressPrompt := #0;
  GDVars.picArcName[0] := #0;
  GDVars.savedPictureName[0] := #0;
  GDVars.picArcId := 255;
  GDVars.savedPictureId := 255;
  GDVars.recentlySaved := 0;
  GDVars.horizonColorSel := 232;
  GDVars.floorColorSel := 219;
  GDVars.inEncounterMenu := 0;
  GDVars.gfxEnabled := 1;
  GDVars.bigPicId := 255;
  GDVars.cursorImageId := 0;
  GDVars.knightTrainingMode := 0;
  MenuCore.ClearBottomLine;
  GDVars.horizontalChoice := 1;
  GDVars.interfaceState := C_Ifc.VIEW_3D;
  GDVars.previousLocationType := C_Ifc.MAIN_MENU;
  GDVars.soundActive := 1;
  GDVars.overrideFlag := 0;
  GDVars.encounterStateFlag := 0;
  GDVars.bankHead := nil;
  GDVars.creatureCursorActive := 0;
  GDVars.mapCursorActive := 0;
  GDVars.extendedMode := 0;
  GDVars.mouseButtonSeen := 0;
  GDVars.useAlternateSelection := 0;
  GDVars.modifyActive := 0;
  GDVars.specialView := 0;
end;

begin
end.
