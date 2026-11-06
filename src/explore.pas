{ Dungeon and wilderness movement, locked-door handling, and the map menu. }
{$O+,F+}
unit Explore;

interface

{ Carries out the step the map menu asked for. In 3D, an open way (barrier type 1) moves the party; a locked barrier
  (types 2 and 3) offers Bash, Pick and Knock as the door flags, the party's thieves and its memorized Knock spells
  allow, and a menu left with Exit alone walls the barrier off instead. On a held barrier (type 3) Pick only uses up the
  attempt. Overland, the party steps on the map. A locked step (moveLocked of 255) is canceled instead. The portraits
  and the big animation are freed on the way out. }
procedure ResolveMovement;

{ Runs the map menu until the party moves or leaves it. In 3D the menu offers Move, Area, Cast, View, Encamp, Search and
  Look: Move switches to arrow-key movement (forward, turn around, turn left, turn right) with Exit; Area turns the
  automap on or off where the area allows it or the second parameter matches cmpStr, else shows "Not Here"; Cast needs
  the current character to be okay; Search turns searching on or off; Look searches the spot for ten minutes and runs
  the ECL search entry. Overland, when the zone allows wilderness travel, the menu offers Move and Encamp, and Move
  takes an arrow key as the new facing. The bottom window is cleared once afterwards.
  @returns(The key that ended the menu.) }
function MapMainMenu: Char;

{ Calls the priming entries of FxEngine, CharHlp, ViewChar, MapView, SaveLoad, MapTiles, Portrait, GameTime, MenuCore,
  ClassCal and the trace overlay, so the overlay manager loads them; the other overlays this unit uses are not primed
  here. }
procedure PrimeExplore;

implementation

uses Types, Crt, SoundDrv, TextRend, Blit, Border, Mouse, MapCurs, Camp, SaveLoad, ViewChar, GameTime, FxEngine,
  CharHlp, ClassCal, MenuCore, MapView, Portrait, View3D, MapTiles, Debug, GDConsts, GDVars, C_Keys, C_Class, C_Dir,
  C_Stat, C_Status, C_Ifc;

procedure PrimeExplore;
begin
  FxEngine.PrimeFxEngine;
  CharHlp.PrimeCharHlp;
  ViewChar.PrimeViewChar;
  MapView.PrimeMapView;
  SaveLoad.PrimeSaveLoad;
  MapTiles.PrimeMapTiles;
  Portrait.PrimePortrait;
  GameTime.PrimeGameTime;
  Debug.PrimeDebug;
  MenuCore.PrimeMenuCore;
  ClassCal.PrimeClassCal;
end;

{ Meant to clear the barrier bits of one side of a map cell. Note: it exits at once, so nothing is changed.
  @param(x Cell column.)
  @param(y Cell row.)
  @param(facing Side of the cell.) }
procedure ChangeBarrierImpassable(x, y: ShortInt; facing: Byte);
begin
  Exit;
  case facing of
    C_Dir.WEST: GDVars.geo^.barriers[y, x] := GDVars.geo^.barriers[y, x] and $3F;
    C_Dir.SOUTH: GDVars.geo^.barriers[y, x] := GDVars.geo^.barriers[y, x] and $CF;
    C_Dir.EAST: GDVars.geo^.barriers[y, x] := GDVars.geo^.barriers[y, x] and $F3;
    C_Dir.NORTH: GDVars.geo^.barriers[y, x] := GDVars.geo^.barriers[y, x] and $FC;
  end;
end;

{ Opens the barrier on one side of a 3D map cell (barrier type 1). A cell outside the 16x16 map is ignored.
  @param(x Map column of the cell.)
  @param(y Map row of the cell.)
  @param(facing The side, a cardinal direction.) }
procedure ChangeBarrierPassable(x, y: ShortInt; facing: Byte);
begin
  if (x < 0) or (x > 15) or (y < 0) or (y > 15) then Exit;
  case facing of
    C_Dir.WEST: GDVars.geo^.barriers[y, x] := GDVars.geo^.barriers[y, x] and $3F or $40;
    C_Dir.SOUTH: GDVars.geo^.barriers[y, x] := GDVars.geo^.barriers[y, x] and $CF or $10;
    C_Dir.EAST: GDVars.geo^.barriers[y, x] := GDVars.geo^.barriers[y, x] and $F3 or $04;
    C_Dir.NORTH: GDVars.geo^.barriers[y, x] := GDVars.geo^.barriers[y, x] and $FC or $01;
  end;
end;

{ Tells whether any party member has levels in a class, counting a former class only while ClassCal.EarlierClassActive
  says it still applies.
  @param(classIndex The class.)
  @returns(True when a member has the class.) }
function PartyHasClass(classIndex: ShortInt): Boolean;
var
  character: Types.PCharRecord;
  found: Boolean;
begin
  found := False;
  character := GDVars.partyHead;
  while (character <> nil) and not found do begin
    if (character^.classLevels[classIndex] > 0) or
        ((character^.classLevels2[classIndex] > 0) and
         ClassCal.EarlierClassActive(character)) then
      found := True;
    character := character^.next;
  end;
  PartyHasClass := found;
end;

{ Has each party member in turn try to bash open the barrier ahead until one succeeds, by Strength: a held barrier (type
  3) needs Strength 18/91 or more, and a weaker member marks it unbashable; other barriers use the plain Strength table.
  On success both sides of the barrier become open.
  @returns(True when the barrier was opened.) }
function BashDoor: Boolean;
var
  character: Types.PCharRecord;
  success: Boolean;
begin
  success := False;
  character := GDVars.partyHead;
  while (character <> nil) and not success do begin
    with character^ do
    if View3D.GetBarrierType(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing) = 3 then begin
      case stats[C_Stat.STRENGTH].cur of
        18: case strExc of
               91..99: if FxEngine.RollDice(1, 6) = 1 then success := True;
               100: if FxEngine.RollDice(1, 6) <= 2 then success := True;
             else
               GDVars.doorOpen[0] := 0;
             end;
        19, 20: if FxEngine.RollDice(1, 6) <= 3 then success := True;
        21, 22: if FxEngine.RollDice(1, 6) <= 4 then success := True;
        23: if FxEngine.RollDice(1, 6) <= 5 then success := True;
        24: if FxEngine.RollDice(1, 8) <= 7 then success := True;
        25: success := True;
      else
        GDVars.doorOpen[0] := 0;
      end;
    end else
      case stats[C_Stat.STRENGTH].cur of
        3..7: if FxEngine.RollDice(1, 6) = 1 then success := True;
        8..15: if FxEngine.RollDice(1, 6) <= 2 then success := True;
        16..17: if FxEngine.RollDice(1, 6) <= 3 then success := True;
        18: case strExc of
               0..50: if FxEngine.RollDice(1, 6) <= 3 then success := True;
               51..99: if FxEngine.RollDice(1, 6) <= 4 then success := True;
               100: if FxEngine.RollDice(1, 6) <= 5 then success := True;
             end;
        19, 20: if FxEngine.RollDice(1, 8) <= 7 then success := True;
        21: if FxEngine.RollDice(1, 10) <= 9 then success := True;
        22, 23: if FxEngine.RollDice(1, 12) <= 11 then success := True;
        24: if FxEngine.RollDice(1, 20) <= 19 then success := True;
        25: success := True;
      end;
    character := character^.next;
  end;
  if success then begin
    Explore.ChangeBarrierPassable(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
    Explore.ChangeBarrierPassable(GDVars.mapState.x + GDConsts.dirDeltaX[GDVars.mapState.facing],
                          GDVars.mapState.y + GDConsts.dirDeltaY[GDVars.mapState.facing],
                          (GDVars.mapState.facing + 4) mod 8);
  end;
  BashDoor := success;
end;

{ Has the party pick the lock of the door ahead: each member in turn rolls d100 against its Open Locks skill, and the
  roll counts only for a member who is okay. The Pick choice closes at this door whatever the result. Success opens the
  door from both sides.
  @returns(True when the door was opened.) }
function PickLock: Boolean;
var
  character: Types.PCharRecord;
  success: Boolean;
begin
  success := False;
  character := GDVars.partyHead;
  while (character <> nil) and not success do begin
    with character^ do
      if (FxEngine.RollDice(1, 100) <= thiefSkills[2]) and (status = C_Status.OKAY) then
        success := True;
    character := character^.next;
  end;
  GDVars.doorOpen[1] := 0;
  if success then begin
    Explore.ChangeBarrierPassable(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
    Explore.ChangeBarrierPassable(GDVars.mapState.x + GDConsts.dirDeltaX[GDVars.mapState.facing],
                          GDVars.mapState.y + GDConsts.dirDeltaY[GDVars.mapState.facing],
                          (GDVars.mapState.facing + 4) mod 8);
  end;
  PickLock := success;
end;

{ Finds a memorized spell in a character's spell slots.
  @param(spellId The spell.)
  @param(character The character.)
  @returns(The slot, or 255 when the spell is not memorized.) }
function FindMemorizedSpell(spellId: Byte; character: Types.PCharRecord): Byte;
var
  spellIndex: Byte;
begin
  spellIndex := 0;
  while (spellIndex <= 57) and (character^.memorized[spellIndex] <> spellId) do
    Inc(spellIndex);
  if spellIndex <= 57 then
    FindMemorizedSpell := spellIndex
  else
    FindMemorizedSpell := 255;
end;

{ Finds a party member with a spell memorized.
  @param(spellId The spell.)
  @returns(The first party member with it memorized, or nil.) }
function FindCharWithSpell(spellId: Byte): Types.PCharRecord;
var
  character: Types.PCharRecord;
begin
  character := GDVars.partyHead;
  while (character <> nil) and (Explore.FindMemorizedSpell(spellId, character) = 255) do
    character := character^.next;
  FindCharWithSpell := character;
end;

{ Spends the first memorized Knock spell in the party.
  @returns(True when a member had Knock memorized.) }
function PartyCastsKnock: Boolean;
var
  character: Types.PCharRecord;
begin
  character := Explore.FindCharWithSpell(31);
  if character <> nil then begin
    character^.memorized[Explore.FindMemorizedSpell(31, character)] := 0;
    PartyCastsKnock := True;
  end else
    PartyCastsKnock := False;
end;

{ Clears the zone's leave-map flag, then, when the barrier ahead lets the party through and the step would leave the
  16x16 map, clamps the position to the edge and sets the flag. }
procedure MoveForward;
var
  nextX: Integer;
  nextY: Integer;
  facing: Integer;
begin
  nextX := GDVars.mapState.x;
  nextY := GDVars.mapState.y;
  facing := GDVars.mapState.facing;
  GDVars.zone1^.leaveMap := 0;
  if View3D.GetBarrierType(nextX, nextY, facing) <> 0 then begin
    Inc(nextX, GDConsts.dirDeltaX[facing]);
    Inc(nextY, GDConsts.dirDeltaY[facing]);
    if nextX > 15 then begin
      GDVars.mapState.x := 15;
      GDVars.zone1^.leaveMap := 1;
    end;
    if nextX < 0 then begin
      GDVars.mapState.x := 0;
      GDVars.zone1^.leaveMap := 1;
    end;
    if nextY > 15 then begin
      GDVars.mapState.y := 15;
      GDVars.zone1^.leaveMap := 1;
    end;
    if nextY < 0 then begin
      GDVars.mapState.y := 0;
      GDVars.zone1^.leaveMap := 1;
    end;
  end;
end;

{ Steps the party one cell forward on the 3D map with the step sound and a short pause, wrapping at the map's edges,
  refreshes the wall ahead and the cell's event, reopens the door choices and advances the clock one minute, or one turn
  while searching. }
procedure MovePartyForward3D;
begin
  SoundDrv.SoundCommand(GDConsts.soundIds[6]);
  Delay(50);
  Inc(GDVars.mapState.x, GDConsts.dirDeltaX[GDVars.mapState.facing]);
  Inc(GDVars.mapState.y, GDConsts.dirDeltaY[GDVars.mapState.facing]);
  if GDVars.mapState.x < 0 then GDVars.mapState.x := 15;
  if GDVars.mapState.x > 15 then GDVars.mapState.x := 0;
  if GDVars.mapState.y < 0 then GDVars.mapState.y := 15;
  if GDVars.mapState.y > 15 then GDVars.mapState.y := 0;
  GDVars.mapState.wallAhead := View3D.GetWallType(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
  FillChar(GDVars.doorOpen, SizeOf(GDVars.doorOpen), 1);
  GDVars.mapState.event := View3D.GetMapEvent(GDVars.mapState.x, GDVars.mapState.y);
  if GDVars.zone1^.searchFlags and $01 > 0 then
    GameTime.AdvanceTime(1, 2)
  else
    GameTime.AdvanceTime(1, 1);
end;

{ Moves the party cursor one cell on the overland map in its facing, kept within columns 0..37 and rows 0..14, remembers
  the previous position, and advances the clock 12 hours. }
procedure MovePartyWilderness;
var
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  nextX: ShortInt;
  nextY: ShortInt;
begin
  Mouse.HideMouse;
  MapCurs.RestoreCursorBackground;
  GDVars.zone0^.prevX := GDVars.zone0^.partyX;
  GDVars.zone0^.prevY := GDVars.zone0^.partyY;
  nextX := GDVars.zone0^.partyX + GDConsts.dirDeltaX[GDVars.mapState.facing];
  nextY := GDVars.zone0^.partyY + GDConsts.dirDeltaY[GDVars.mapState.facing];
  if nextX < 0 then nextX := 0;
  if nextX > 37 then nextX := 37;
  if nextY < 0 then nextY := 0;
  if nextY > 14 then nextY := 14;
  GDVars.zone0^.partyX := nextX;
  GDVars.zone0^.partyY := nextY;
  MapCurs.DrawCursor;
  Mouse.ShowMouse;
  GameTime.AdvanceTime(12, 3);
end;

function MapMainMenu: Char;
var
  finished: Boolean;
  choice: Char;
  extendedKey: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  menuText: String[40];
  viewDone: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  oldZone: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  oldWindow: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  oldPicture: Pointer;
begin
  GDVars.zone1^.moveLocked := 0;
  case GDVars.interfaceState of
    C_Ifc.VIEW_3D: begin
         finished := False;
         choice := C_Keys.NONE;
         repeat
           if GDVars.extendedMode = 0 then begin
             choice := MenuCore.MenuHorizontal('', 'Move Area Cast View Encamp Search Look', LightMagenta, LightGreen,
                                               White, True, False, extendedKey);
             if not extendedKey then begin
               case choice of
                 'M': begin
                        MenuCore.ClearBottomLine;
                        GDVars.extendedMode := 1;
                      end;
                 'A': begin
                        if (GDVars.zone0^.areaLock = 0) or (ParamStr(2) = GDVars.cmpStr) then begin
                          GDVars.automapOn := GDVars.automapOn = False;
                          View3D.Display3DMapView(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
                        end else
                          TextRend.printAndPause('Not Here', Yellow, Black);
                      end;
                 'C': if GDVars.curChar^.status = C_Status.OKAY then begin
                        GDVars.horizontalChoice := 1;
                        Camp.NoncombatCastMenu;
                      end;
                 'V': begin
                        GDVars.horizontalChoice := 1;
                        ViewChar.ViewCharMenu(viewDone);
                      end;
                 'E': begin
                        finished := True;
                        GDVars.horizontalChoice := 1;
                      end;
                 'S': begin
                        GDVars.zone1^.searchFlags := GDVars.zone1^.searchFlags xor $01;
                        CharHlp.PrintPositionAndTime;
                      end;
                 'L': begin
                        GDVars.zone1^.searchFlags := GDVars.zone1^.searchFlags or $02;
                        CharHlp.PrintPositionAndTime;
                        GameTime.AdvanceTime(1, 2);
                        GDVars.eclIp := GDVars.eclEntryPoints.searchLocation;
                        finished := True;
                      end;
               end;
             end else begin
               ViewChar.SelectPrevNextChar(choice);
               CharHlp.DisplayParty(GDVars.curChar);
               CharHlp.PrintPositionAndTime;
             end;
           end else begin
             choice := MenuCore.MenuHorizontal('', 'Exit', LightMagenta, LightGreen, White, True, False, extendedKey);
             if not extendedKey then begin
               case choice of
                 'E': GDVars.extendedMode := 0;
               end;
             end else begin
               case choice of
                 C_Keys.UP: begin
                        Explore.MoveForward;
                        finished := True;
                        CharHlp.PrintPositionAndTime;
                        choice := C_Keys.NONE;
                      end;
                 C_Keys.DOWN: begin
                        GDVars.mapState.facing := (GDVars.mapState.facing + 4) mod 8;
                        GDVars.mapState.wallAhead := View3D.GetWallType(GDVars.mapState.x, GDVars.mapState.y,
                                                                          GDVars.mapState.facing);
                        View3D.Display3DMapView(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
                        CharHlp.PrintPositionAndTime;
                        choice := C_Keys.NONE;
                      end;
                 C_Keys.LEFT: begin
                        GDVars.mapState.facing := (GDVars.mapState.facing + 6) mod 8;
                        SoundDrv.SoundCommand(GDConsts.soundIds[6]);
                        GDVars.mapState.wallAhead := View3D.GetWallType(GDVars.mapState.x, GDVars.mapState.y,
                                                                          GDVars.mapState.facing);
                        View3D.Display3DMapView(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
                        CharHlp.PrintPositionAndTime;
                        choice := C_Keys.NONE;
                      end;
                 C_Keys.RIGHT: begin
                        GDVars.mapState.facing := (GDVars.mapState.facing + 2) mod 8;
                        SoundDrv.SoundCommand(GDConsts.soundIds[6]);
                        GDVars.mapState.wallAhead := View3D.GetWallType(GDVars.mapState.x, GDVars.mapState.y,
                                                                          GDVars.mapState.facing);
                        View3D.Display3DMapView(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
                        CharHlp.PrintPositionAndTime;
                        choice := C_Keys.NONE;
                      end;
               end;
             end;
           end;
         until finished;
       end;
    C_Ifc.OVERLAND: if GDVars.zone0^.wildOn <> 0 then begin
         finished := False;
         repeat
           if GDVars.extendedMode = 0 then begin
             choice := MenuCore.MenuHorizontal('', 'Move Encamp', LightMagenta, LightGreen, White, True, False,
                                               extendedKey);
             if not extendedKey then begin
               case choice of
                 'M': begin
                        MenuCore.ClearBottomLine;
                        GDVars.extendedMode := 1;
                      end;
                 'E': begin
                        finished := True;
                        GDVars.horizontalChoice := 1;
                      end;
               end;
             end;
           end else begin
             choice := C_Keys.NONE;
             if choice = C_Keys.NONE then
               choice := MenuCore.MenuHorizontal('', 'Exit', LightMagenta, LightGreen, White, True, False, extendedKey);
             if not extendedKey then begin
               case choice of
                 'E': GDVars.extendedMode := 0;
               end;
             end else begin
               finished := True;
               case choice of
                 C_Keys.UP: GDVars.mapState.facing := C_Dir.NORTH;
                 C_Keys.PAGE_UP: GDVars.mapState.facing := C_Dir.NORTHEAST;
                 C_Keys.RIGHT: GDVars.mapState.facing := C_Dir.EAST;
                 C_Keys.PAGE_DOWN: GDVars.mapState.facing := C_Dir.SOUTHEAST;
                 C_Keys.DOWN: GDVars.mapState.facing := C_Dir.SOUTH;
                 C_Keys.END_KEY: GDVars.mapState.facing := C_Dir.SOUTHWEST;
                 C_Keys.LEFT: GDVars.mapState.facing := C_Dir.WEST;
                 C_Keys.HOME: GDVars.mapState.facing := C_Dir.NORTHWEST;
               end;
               CharHlp.PrintPositionAndTime;
             end;
           end;
         until finished;
       end;
  end;
  if GDVars.bottomClear = 0 then begin
    Border.ClearBox(1, 17, 38, 22);
    GDVars.bottomClear := 1;
  end;
  MapMainMenu := choice;
end;

procedure ResolveMovement;
var
  movementSucceeded: Boolean;
  extendedKey: Boolean;
  menuText: String[40];
  choice: Char;
begin
  movementSucceeded := False;
  case GDVars.interfaceState of
    C_Ifc.VIEW_3D: if GDVars.zone1^.moveLocked < 255 then begin
         GDVars.pictureRedrawRequested := 1;
         case View3D.GetBarrierType(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing) of
           1: movementSucceeded := True;
           2: begin
                menuText := '';
                if GDVars.doorOpen[0] <> 0 then
                  menuText := 'Bash';
                if (GDVars.doorOpen[1] <> 0) and Explore.PartyHasClass(C_Class.THIEF) then
                  menuText := menuText + ' Pick';
                if (GDVars.doorOpen[2] <> 0) and (Explore.FindCharWithSpell(31) <> nil) then
                  menuText := menuText + ' Knock';
                menuText := menuText + ' Exit';
                if menuText = ' Exit' then
                  Explore.ChangeBarrierImpassable(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing)
                else begin
                  choice := MenuCore.MenuHorizontal('Locked. ', menuText, LightMagenta, LightGreen, White, False, False,
                                                    extendedKey);
                  case choice of
                    'B': movementSucceeded := Explore.BashDoor;
                    'P': movementSucceeded := Explore.PickLock;
                    'K': movementSucceeded := Explore.PartyCastsKnock;
                  end;
                end;
              end;
           3: begin
                menuText := '';
                if GDVars.doorOpen[0] <> 0 then
                  menuText := 'Bash';
                if (GDVars.doorOpen[1] <> 0) and Explore.PartyHasClass(C_Class.THIEF) then
                  menuText := menuText + ' Pick';
                if (GDVars.doorOpen[2] <> 0) and (Explore.FindCharWithSpell(31) <> nil) then
                  menuText := menuText + ' Knock';
                menuText := menuText + ' Exit';
                if menuText = ' Exit' then
                  Explore.ChangeBarrierImpassable(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing)
                else begin
                  choice := MenuCore.MenuHorizontal('Locked. ', menuText, LightMagenta, LightGreen, White, False, False,
                                                    extendedKey);
                  case choice of
                    'B': movementSucceeded := Explore.BashDoor;
                    'P': GDVars.doorOpen[1] := 0;
                    'K': movementSucceeded := Explore.PartyCastsKnock;
                  end;
                end;
              end;
         end;
         if movementSucceeded then
           Explore.MovePartyForward3D;
         CharHlp.PrintPositionAndTime;
       end else
         GDVars.zone1^.moveLocked := 0;
    C_Ifc.OVERLAND: if GDVars.zone1^.moveLocked < 255 then begin
         Explore.MovePartyWilderness;
         CharHlp.PrintPositionAndTime;
       end;
  else
    GDVars.zone1^.moveLocked := 0;
  end;
  Portrait.FreeAnimation(GDVars.bigAnim);
  Blit.FreePic(GDVars.portraits[1].pic);
  Blit.FreePic(GDVars.portraits[2].pic);
  GDVars.portraits[1].fileId := 255;
  GDVars.portraits[2].fileId := 255;
end;

begin
end.
