{ Character generation, party management (add/drop/train), the top-level game FUNCTION menu, the icon editor, the
  Knights of Solamnia advancement path and the mouse/joystick setup. }
{$O+,F+,I-}
unit CharGen;
interface

{ Runs the top-level FUNCTION menu until play begins: Create, Drop, Modify, Train and Knight (while the zone trains or
  free training is on), View, Add, Remove (saving a player character first; an NPC is dropped), Load, Save, Begin, Init
  mouse/joystick and Exit, the entries offered depending on whether there is a party. Begin restores the interface state
  the menu was entered from and redraws its frame and the party. Exit asks again for an unsaved party, saving it on No.
  With the developer keyword as the second parameter, J turns free training on or off. }
procedure MainMenu;

{ Unlinks the current character from the party roster and frees it. Its predecessor, or else the roster head, becomes
  the current character. A character that is not in the roster is left untouched.
  @param(suppressSizeDec True leaves the party size alone.)
  @param(freeAnim True also frees the character's icon animation.) }
procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);

{ Runs the icon editor for the current character, showing the old and new icons side by side: Parts picks a head or
  body, colors 1 and 2 change the six icon colors (not on CGA), and Size switches between small and large; each change
  is kept or undone. It repeats until the player accepts the icon. }
procedure CustomizeIcon;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeCharGen;

implementation

uses Types, ViewChar, Magic, FxEngine, CharHlp, ClassCal, MenuCore, Portrait, CbtMap, MapTiles, Debug, SaveLoad,
  GDConsts, GDVars, Border, GameIo, TextRend, Blit, Mouse, Joystick, Crt, C_Keys, C_Class, C_Race,
  C_Status, C_Ifc, C_Stat, C_Npc;

const
  KEY_DEL = #83;
  { Multiclass values in the classNames order, as in C_Class. }
  CLASS_CLERIC_MAGE = 11;
  CLASS_CLERIC_THIEF = 12;
  CLASS_FIGHTER_MAGE = 13;

procedure PrimeCharGen;
begin
  CharHlp.PrimeCharHlp;
  ViewChar.PrimeViewChar;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  Portrait.PrimePortrait;
  MapTiles.PrimeMapTiles;
  SaveLoad.PrimeSaveLoad;
  MenuCore.PrimeMenuCore;
  CbtMap.PrimeCbtMap;
  Debug.PrimeDebug;
  ClassCal.PrimeClassCal;
end;

{ Frees a creature record with its combat record, items and effects.
  @param(cr The creature; nil on return.) }
procedure FreeCreature(var cr: Types.PCharRecord);
var
  hold: Types.PItemRec;
  it: Types.PItemRec;
  holdE: Types.PEffectRec;
  eff: Types.PEffectRec;
begin
  with cr^ do begin
    if combatAddr <> nil then
      FreeMem(combatAddr, SizeOf(Types.TCombatRec));
    it := itemsAddr;
    while it <> nil do begin
      hold := it;
      it := it^.next;
      FreeMem(hold, SizeOf(Types.TItemRec));
    end;
    eff := effects;
    while eff <> nil do begin
      holdE := eff;
      eff := eff^.next;
      FreeMem(holdE, SizeOf(Types.TEffectRec));
    end;
  end;
  FreeMem(cr, SizeOf(Types.TCharRecord));
  cr := nil;
end;

procedure CreateCharacterMenu; forward;

function ConHpBonus(charClass: Byte): ShortInt; forward;

procedure DropCharacterMenu; forward;

procedure ModifyCharacterMenu; forward;

procedure AddCharacterMenu; forward;

procedure RollFirstLevelHp(cr: Types.PCharRecord; mask, divisor: Byte); forward;

procedure TrainingMenu; forward;

procedure InitStartingMoney(cr: Types.PCharRecord); forward;

procedure AdvanceKnightOrder(cr: Types.PCharRecord); forward;

procedure KnightPromotionMenu; forward;

procedure InitMouseJoystick; forward;

procedure CalibrateJoystickInWindow; forward;

function HpMinimum(cr: Types.PCharRecord): Byte; forward;

function HpMaximum(cr: Types.PCharRecord): Byte; forward;

procedure SetDefaultIcon; forward;

procedure MainMenu;
var
  i: Byte;
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  ext: Byte;
  redraw: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  menuEnabled: array[1..9] of Byte;
  n: ShortInt;
  buildMenu: Boolean;
  oldIfc: Byte;
  { Unused in this version; see the other implementations of this routine. }
  stateB: Byte;
  list: Types.PItemRec;
  sel: Types.PItemRec;
  walk: Types.PItemRec;
  idx: Integer;
begin
  GDVars.partyPickEnabled := 0;
  oldIfc := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.MAIN_MENU;
  buildMenu := True;
  GDVars.stingMode := 0;
  idx := 0;
  while True do begin
    if buildMenu then begin
      Border.DrawWindowFrame(True);
      if GDVars.curChar <> nil then begin
        CharHlp.DisplayParty(GDVars.curChar);
        GDConsts.mainMenuEntries[1].enabled := 1;
        GDConsts.mainMenuEntries[2].enabled := 1;
        GDConsts.mainMenuEntries[3].enabled := Byte((GDVars.zone1^.trainMask > 0) or (GDVars.stingMode <> 0));
        GDConsts.mainMenuEntries[4].enabled := GDConsts.mainMenuEntries[3].enabled;
        GDConsts.mainMenuEntries[5].enabled := 1;
        GDConsts.mainMenuEntries[7].enabled := 1;
        GDConsts.mainMenuEntries[8].enabled := 0;
        GDConsts.mainMenuEntries[9].enabled := 1;
        GDConsts.mainMenuEntries[10].enabled := 1;
        GDConsts.mainMenuEntries[11].enabled := 0;
      end else begin
        GDConsts.mainMenuEntries[1].enabled := 0;
        GDConsts.mainMenuEntries[2].enabled := 0;
        GDConsts.mainMenuEntries[3].enabled := 0;
        GDConsts.mainMenuEntries[4].enabled := 0;
        GDConsts.mainMenuEntries[5].enabled := 0;
        GDConsts.mainMenuEntries[7].enabled := 0;
        GDConsts.mainMenuEntries[8].enabled := 1;
        GDConsts.mainMenuEntries[9].enabled := 0;
        GDConsts.mainMenuEntries[10].enabled := 0;
        GDConsts.mainMenuEntries[11].enabled := 1;
      end;
      n := 0;
      for i := 0 to 12 do
        if GDConsts.mainMenuEntries[i].enabled <> 0 then Inc(n);
      MenuCore.AllocStringList(n, list);
      walk := list;
      for i := 0 to 12 do
        if GDConsts.mainMenuEntries[i].enabled <> 0 then begin
          walk^.name := GDConsts.mainMenuEntries[i].name;
          walk := walk^.next;
        end;
    end;

    redraw := True;
    ch := MenuCore.MenuVertical('Choose a FUNCTION ', 'Select ', LightMagenta, LightGreen, White, 9, 12, 38, 22, list,
                                False, redraw, idx, sel);
    ch := sel^.name[1];
    if buildMenu then MenuCore.FreeStringList(list);
    if not (ch in ['E', 'S']) then GDVars.recentlySaved := 0;

    case ch of
      'C': if GDConsts.mainMenuEntries[0].enabled <> 0 then CharGen.CreateCharacterMenu;
      'D': if GDConsts.mainMenuEntries[1].enabled <> 0 then CharGen.DropCharacterMenu;
      'M': if GDConsts.mainMenuEntries[2].enabled <> 0 then CharGen.ModifyCharacterMenu;
      'T': if GDConsts.mainMenuEntries[3].enabled <> 0 then CharGen.TrainingMenu;
      'K': if GDConsts.mainMenuEntries[4].enabled <> 0 then CharGen.KnightPromotionMenu;
      'V': if GDConsts.mainMenuEntries[5].enabled <> 0 then
             if ViewChar.PickCharacter then ViewChar.ViewCharMenu(redraw);
      'A': if GDConsts.mainMenuEntries[6].enabled <> 0 then CharGen.AddCharacterMenu;
      'R': if (GDConsts.mainMenuEntries[7].enabled <> 0) and (GDVars.curChar <> nil) then
             if ViewChar.PickCharacter then
               if GDVars.curChar^.npc < C_Npc.NON_PLAYER then begin
                 SaveLoad.SaveChar(GDVars.curChar, '');
                 CharGen.RemoveCreature(False, True);
               end else
                 CharGen.DropCharacterMenu;
      'L': if GDConsts.mainMenuEntries[8].enabled <> 0 then SaveLoad.LoadGame;
      'S': if (GDConsts.mainMenuEntries[9].enabled <> 0) and (GDVars.partyHead <> nil) then
             SaveLoad.SaveGame;
      'B': if GDConsts.mainMenuEntries[10].enabled <> 0 then
           begin
             GDVars.partyPickEnabled := 1;
             if (GDVars.partyHead <> nil) or (GDVars.demoFlag <> 0) then begin
               GDVars.interfaceState := oldIfc;
               if (GDVars.loadedSave = 0) or (GDVars.picArcId = 9) then begin
                 if (GDVars.interfaceState = C_Ifc.OVERLAND) and (GDVars.zone0^.areaView = 0) then
                   Border.DrawRowDivider
                 else
                   Border.DrawViewFrame;
                 CharHlp.DisplayParty(GDVars.curChar);
               end else if (GDVars.zone0^.prevEcl = 0) or (GDVars.zone0^.areaView <> 0) then begin
                 Border.DrawViewFrame;
                 CharHlp.DisplayParty(GDVars.curChar);
               end;
               MenuCore.ClearBottomLine;
               GDVars.zone1^.trainMask := 0;
               Exit;
             end;
           end;
      'I': if GDConsts.mainMenuEntries[11].enabled <> 0 then CharGen.InitMouseJoystick;
      'E': if GDConsts.mainMenuEntries[12].enabled <> 0 then
           begin
             ch := MenuCore.YesNoMenu('Quit to DOS ', Yellow, LightGreen, White);
             if ch = 'Y' then
             begin
               if (GDVars.partyHead <> nil) and (GDVars.recentlySaved = 0) then begin
                 ch := MenuCore.YesNoMenu('Game NOT saved.  Quit anyway? ', Yellow, LightGreen, White);
                 if ch = 'N' then SaveLoad.SaveGame;
               end;
               if ch = 'Y' then GameIo.ExitGame;
             end;
           end;
      'J': if ParamStr(2) = GDVars.cmpStr then
           begin
             GDVars.stingMode := Byte(GDVars.stingMode = 0);
             if GDVars.stingMode <> 0 then
               CharHlp.PrintBottomLine('Free training on')
             else
               CharHlp.PrintBottomLine('Free training off');
           end;
    end;
  end;
end;

{ Creates a character: picks race (with its racial effects), gender, class (with starting levels and experience), deity
  for a cleric (the dwarves' only choice is deity 6) and alignment, rolls the starting age and the six abilities (best
  of six rolls, adjusted for age and held within the race and class limits), sets up spells, starting money and
  first-level hit points, and trains as far as the experience allows; the abilities can be rerolled. It then takes a
  name and an icon and offers to save the character (a knight gets its starting equipment). Escape at any pick abandons
  it. Note: the racial ability adjustments test the race list's loop counter, which ends at human, so they never apply;
  and the money step tests the class loop's counter, which ends at the knight, so the per-class average is never
  taken. }
procedure CreateCharacterMenu;
var
  cr: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  list: Types.PItemRec;
  m: Types.PItemRec;
  sel: Integer;
  slot: Byte;
  j: Byte;
  roll: Byte;
  ch: Char;
  k: ShortInt;
  g: ShortInt;
  cls: ShortInt;
  i: ShortInt;
  cnt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  statIndex: Byte;
  { Unused in this version; see the other implementations of this routine. }
  conB: Integer;
  clsCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hpRoll: Byte;
  addExit: Boolean;
  redraw: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  haveLevelText: Byte;
  keepFlag: Boolean;
  line: String[40];
  savedPanel: Byte;
  alignmentIds: array[0..5] of Byte;
  spellMask: Byte;
  bitValue: Byte;
  hpTotal: Byte;
  { Unused in this version; see the other implementations of this routine. }
  rollIndex: Byte;
begin
  GetMem(cr, SizeOf(Types.TCharRecord));
  FillChar(cr^, SizeOf(Types.TCharRecord), 0);
  with Types.PCharRecord(cr)^ do begin
    for slot := 1 to 6 do
      iconColors[slot] := GDConsts.defIconColors[slot]
                          + (GDConsts.defIconColors[slot] + 8) * 16;
    acBase := 50;
    thac0Base := 40;
    status := C_Status.OKAY;
    inPlay := 1;
    iconDimensions := 1;
    creatureId := Random(256);
    orderNumber := 10;
  end;

  MenuCore.AllocStringList(8, list);
  list^.inUse := 1;
  list^.name := 'Pick Race';
  for k := 0 to 6 do begin
    m := MenuCore.FindListMember(k + 1, list);
    m^.name := '  ' + GDConsts.raceNames[k];
  end;
  m := list;
  sel := 1;
  redraw := True;
  addExit := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, addExit, redraw,
                                sel, m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(list);
      CharGen.FreeCreature(cr);
      Exit;
    end;
  until ch = 'S';
  with Types.PCharRecord(cr)^ do begin
    race := sel - 1;
    case race of
      C_Race.KENDER: begin
           iconSize := 1;
           FxEngine.AddEffect(cr, 92, 0, 255, False);
           FxEngine.AddEffect(cr, 94, 0, 255, False);
         end;
      C_Race.MOUNTAIN_DWARF, C_Race.HILL_DWARF: begin
           iconSize := 1;
           FxEngine.AddEffect(cr, 94, 0, 255, False);
           FxEngine.AddEffect(cr, 26, 0, 255, False);
           FxEngine.AddEffect(cr, 47, 0, 255, False);
         end;
      C_Race.SILVANESTI_ELF, C_Race.QUALINESTI_ELF: begin
           iconSize := 2;
           FxEngine.AddEffect(cr, 95, 0, 255, False);
         end;
      C_Race.HALF_ELF: begin
           iconSize := 2;
           FxEngine.AddEffect(cr, 18, 0, 255, False);
         end;
    else
      iconSize := 2;
    end;
  end;

  MenuCore.FreeStringList(list);
  MenuCore.AllocStringList(3, list);
  list^.inUse := 1;
  list^.name := 'Pick Gender';
  for g := 0 to 1 do begin
    m := MenuCore.FindListMember(g + 1, list);
    m^.name := '  ' + GDConsts.genderNames[g];
  end;
  m := list;
  sel := 1;
  addExit := True;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, addExit, redraw,
                                sel, m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(list);
      CharGen.FreeCreature(cr);
      Exit;
    end;
  until ch = 'S';
  Types.PCharRecord(cr)^.gender := sel - 1;
  MenuCore.FreeStringList(list);

  cnt := GDConsts.raceClass[Types.PCharRecord(cr)^.race, 0];
  MenuCore.AllocStringList(cnt + 1, list);
  list^.inUse := 1;
  list^.name := 'Pick Class';
  for slot := 1 to cnt do begin
    m := MenuCore.FindListMember(slot, list);
    m^.name := '  ' + GDConsts.classNames[GDConsts.raceClass[Types.PCharRecord(cr)^.race, slot]];
  end;
  m := list;
  sel := 1;
  addExit := True;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, addExit, redraw,
                                sel, m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(list);
      CharGen.FreeCreature(cr);
      Exit;
    end;
  until ch = 'S';
  with Types.PCharRecord(cr)^ do begin
    experience := 0;
    charClass := GDConsts.raceClass[race, sel];
    case charClass of
      C_Class.CLERIC: classLevels[C_Class.CLERIC] := 1;
      C_Class.THIEF: begin classLevels[C_Class.THIEF] := 2; experience := 1251 end;
      C_Class.FIGHTER: begin classLevels[C_Class.FIGHTER] := 2; experience := 2001 end;
      C_Class.MAGE: begin classLevels[C_Class.MAGE] := 2; experience := 5000 end;
      C_Class.RANGER: begin
           classLevels[C_Class.RANGER] := 2;
           experience := 2251;
           FxEngine.AddEffect(cr, 105, 0, 255, False)
         end;
      C_Class.KNIGHT: begin
           classLevels[C_Class.KNIGHT] := 1;
           experience := 2500;
           knightOrder := 1
         end;
      C_Class.CLERIC_FIGHTER: begin
           classLevels[C_Class.CLERIC] := 1; classLevels[C_Class.FIGHTER] := 1;
           experience := 2001
         end;
      C_Class.CLERIC_FIGHTER_MAGE: begin
           classLevels[C_Class.CLERIC] := 1; classLevels[C_Class.FIGHTER] := 1;
           classLevels[C_Class.MAGE] := 1; experience := 5000
         end;
      C_Class.CLERIC_RANGER: begin
            classLevels[C_Class.CLERIC] := 1; classLevels[C_Class.RANGER] := 1;
            FxEngine.AddEffect(cr, 105, 0, 255, False);
            experience := 2251
          end;
      CharGen.CLASS_CLERIC_MAGE: begin
            classLevels[C_Class.CLERIC] := 1; classLevels[C_Class.MAGE] := 1;
            experience := 5000
          end;
      CharGen.CLASS_CLERIC_THIEF: begin
            classLevels[C_Class.CLERIC] := 1; classLevels[C_Class.THIEF] := 1
          end;
      CharGen.CLASS_FIGHTER_MAGE: begin
            classLevels[C_Class.FIGHTER] := 1; classLevels[C_Class.MAGE] := 1;
            experience := 5000
          end;
      C_Class.FIGHTER_THIEF: begin
            classLevels[C_Class.FIGHTER] := 1; classLevels[C_Class.THIEF] := 1;
            experience := 2001
          end;
      C_Class.FIGHTER_MAGE_THIEF: begin
            classLevels[C_Class.FIGHTER] := 1; classLevels[C_Class.MAGE] := 1;
            classLevels[C_Class.THIEF] := 1; experience := 5000
          end;
      C_Class.MAGE_THIEF: begin
            classLevels[C_Class.MAGE] := 1; classLevels[C_Class.THIEF] := 1;
            experience := 5000
          end;
    end;
    if classLevels[C_Class.THIEF] > 0 then
      ClassCal.RecalcThiefSkills(cr);
    classMask := 0;
    thac0Base := 0;
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        if GDConsts.thac0Table[cls, classLevels[cls]] > thac0Base then
          thac0Base := GDConsts.thac0Table[cls, classLevels[cls]];
        Inc(classMask, GDConsts.classMaskTable[cls])
      end;
  end;
  ClassCal.RecalcSaves(cr);

  if Types.PCharRecord(cr)^.classLevels[C_Class.CLERIC] > 0 then begin
    MenuCore.FreeStringList(list);
    if (Types.PCharRecord(cr)^.race = C_Race.MOUNTAIN_DWARF) or
        (Types.PCharRecord(cr)^.race = C_Race.HILL_DWARF) then begin
      MenuCore.AllocStringList(2, list);
      list^.inUse := 1;
      list^.name := 'Pick God';
      m := MenuCore.FindListMember(1, list);
      m^.name := '  ' + GDConsts.deityNames[6]
    end else begin
      MenuCore.AllocStringList(8, list);
      list^.inUse := 1;
      list^.name := 'Pick God';
      for slot := 1 to 7 do begin
        m := MenuCore.FindListMember(slot, list);
        m^.name := '  ' + GDConsts.deityNames[ShortInt(slot)]
      end
    end;
    m := list;
    sel := 1;
    addExit := True;
    redraw := True;
    repeat
      ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, addExit, redraw,
                                  sel, m);
      if ch = C_Keys.NONE then begin
        MenuCore.FreeStringList(list);
        CharGen.FreeCreature(cr);
        Exit;
      end;
    until ch = 'S';
    if (Types.PCharRecord(cr)^.race = C_Race.MOUNTAIN_DWARF) or
        (Types.PCharRecord(cr)^.race = C_Race.HILL_DWARF) then
      Types.PCharRecord(cr)^.deity := 6
    else
      Types.PCharRecord(cr)^.deity := sel;
    case Types.PCharRecord(cr)^.deity of
      1: begin spellMask := $15; Types.PCharRecord(cr)^.spellsKnown[101] := 1 end;
      2: begin spellMask := $15; Types.PCharRecord(cr)^.spellsKnown[102] := 1 end;
      3: begin
           spellMask := $15;
           Types.PCharRecord(cr)^.spellsKnown[103] := 1;
           Inc(Types.PCharRecord(cr)^.thac0Base)
         end;
      4: begin
           spellMask := $15;
           Types.PCharRecord(cr)^.spellsKnown[104] := 1;
           Types.PCharRecord(cr)^.spellsKnown[105] := 1;
           Types.PCharRecord(cr)^.spellsKnown[106] := 1
         end;
      5: begin spellMask := $2E; Types.PCharRecord(cr)^.spellsKnown[107] := 1 end;
      6: begin
           spellMask := $2E;
           if (Types.PCharRecord(cr)^.race = C_Race.MOUNTAIN_DWARF) or
               (Types.PCharRecord(cr)^.race = C_Race.HILL_DWARF) then
             Inc(Types.PCharRecord(cr)^.thac0Base)
         end;
      7: begin spellMask := $2E; Types.PCharRecord(cr)^.spellsKnown[106] := 1 end;
    end
  end else begin
    Types.PCharRecord(cr)^.deity := 0;
    spellMask := $FF
  end;
  MenuCore.FreeStringList(list);

  GetMem(list, SizeOf(Types.TCharacterListNode));
  list^.next := nil;
  list^.inUse := 1;
  list^.name := 'Pick Alignment';
  m := list;
  j := 0;
  for slot := 0 to 5 do begin
    bitValue := (GDConsts.classAlignMask[Types.PCharRecord(cr)^.charClass] and spellMask) shr slot;
    if (bitValue and $01) <> 0 then begin
      GetMem(m^.next, SizeOf(Types.TCharacterListNode));
      m := m^.next;
      m^.next := nil;
      m^.inUse := 0;
      m^.name := '  ' + GDConsts.alignmentNames[ShortInt(GDConsts.alignmentChoices[slot])];
      alignmentIds[j] := GDConsts.alignmentChoices[slot];
      Inc(j)
    end
  end;
  m := list;
  sel := 1;
  addExit := True;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, addExit, redraw,
                                sel, m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(list);
      CharGen.FreeCreature(cr);
      Exit;
    end;
  until ch = 'S';
  Types.PCharRecord(cr)^.alignment := alignmentIds[sel - 1];
  case Types.PCharRecord(cr)^.alignment of
    0, 3, 6:
      begin
        if (Types.PCharRecord(cr)^.experience = 0) and
            (Types.PCharRecord(cr)^.classLevels[C_Class.CLERIC] > 0) then
          Types.PCharRecord(cr)^.experience := 2000;
        if Types.PCharRecord(cr)^.classLevels[C_Class.MAGE] > 0 then
          Types.PCharRecord(cr)^.robeOrder := 1
      end;
    1, 4, 7:
      begin
        if (Types.PCharRecord(cr)^.experience = 0) and
            (Types.PCharRecord(cr)^.classLevels[C_Class.CLERIC] > 0) then
          Types.PCharRecord(cr)^.experience := 1500;
        if Types.PCharRecord(cr)^.classLevels[C_Class.MAGE] > 0 then
          Types.PCharRecord(cr)^.robeOrder := 2
      end
  end;
  MenuCore.FreeStringList(list);
  if Types.PCharRecord(cr)^.charClass <= C_Class.KNIGHT then
    with GDConsts.startAge[Types.PCharRecord(cr)^.race, Types.PCharRecord(cr)^.charClass] do
      Types.PCharRecord(cr)^.age := FxEngine.RollDice(dice, sides) + base
  else
    with Types.PCharRecord(cr)^ do
      case charClass of
        C_Class.CLERIC_FIGHTER, C_Class.CLERIC_FIGHTER_MAGE, CharGen.CLASS_CLERIC_MAGE,
          C_Class.CLERIC_RANGER:
          age := GDConsts.startAge[race, C_Class.CLERIC].base
                 + GDConsts.startAge[race, C_Class.CLERIC].sides
                   * GDConsts.startAge[race, C_Class.CLERIC].dice;
        CharGen.CLASS_FIGHTER_MAGE, C_Class.FIGHTER_MAGE_THIEF, C_Class.MAGE_THIEF,
          CharGen.CLASS_CLERIC_THIEF:
          age := GDConsts.startAge[race, C_Class.MAGE].base
                 + GDConsts.startAge[race, C_Class.MAGE].sides
                   * GDConsts.startAge[race, C_Class.MAGE].dice;
        C_Class.FIGHTER_THIEF:
          age := GDConsts.startAge[race, C_Class.FIGHTER].base
                 + GDConsts.startAge[race, C_Class.FIGHTER].sides
                   * GDConsts.startAge[race, C_Class.FIGHTER].dice
      end;
  savedCur := GDVars.curChar;
  GDVars.curChar := cr;
  ViewChar.DisplayChar;
  repeat
    for cls := 0 to 7 do
      if Types.PCharRecord(GDVars.curChar)^.classLevels[cls] > 0 then
        Types.PCharRecord(GDVars.curChar)^.classLevels[cls] := 1;
    Types.PCharRecord(cr)^.strExc := 0;
    for i := 0 to 5 do begin
      Types.PCharRecord(cr)^.stats[i].cur := 0;
      for j := 1 to 6 do begin
        roll := FxEngine.RollDice(3, 6) + 1;
        case k of
          C_Race.MOUNTAIN_DWARF, C_Race.HILL_DWARF:
            case i of
              C_Stat.CONSTITUTION: Inc(roll);
              C_Stat.CHARISMA: Dec(roll)
            end;
          C_Race.SILVANESTI_ELF, C_Race.QUALINESTI_ELF:
            case i of
              C_Stat.DEXTERITY: Inc(roll);
              C_Stat.CONSTITUTION: Dec(roll)
            end;
          C_Race.HALF_ELF:
            case i of
              C_Stat.DEXTERITY: Inc(roll, 2)
            end;
          C_Race.KENDER:
            case i of
              C_Stat.STRENGTH: Dec(roll);
              C_Stat.DEXTERITY: Inc(roll, 2)
            end
        end;
        if Types.PCharRecord(cr)^.stats[i].cur < roll then
          Types.PCharRecord(cr)^.stats[i].cur := roll
      end;
      with Types.PCharRecord(cr)^ do
        case i of
          C_Stat.STRENGTH: begin
               if (stats[i].cur > 0) and (GDConsts.ageLimit[race].limit[0] < age) then
                 Inc(stats[i].cur);
               if (stats[i].cur > 0) and (GDConsts.ageLimit[race].limit[1] < age) then
                 Dec(stats[i].cur);
               if (stats[i].cur > 0) and (GDConsts.ageLimit[race].limit[2] < age) then
                 Dec(stats[i].cur, 2);
               if (stats[i].cur > 0) and (GDConsts.ageLimit[race].limit[3] < age) then
                 Dec(stats[i].cur);
               if stats[i].cur < GDConsts.raceLimits[race].strMin[gender] then
                 stats[i].cur := GDConsts.raceLimits[race].strMin[gender];
               if stats[i].cur > GDConsts.raceLimits[race].strMax[gender] then
                 stats[i].cur := GDConsts.raceLimits[race].strMax[gender];
               if stats[i].cur < GDConsts.classMin[charClass, i] then
                 stats[i].cur := GDConsts.classMin[charClass, i];
               if stats[C_Stat.STRENGTH].cur = 18 then
                 if (classLevels[C_Class.FIGHTER] > 0) or (classLevels[C_Class.RANGER] > 0) or
                     (classLevels[C_Class.KNIGHT] > 0) then begin
                   strExc := Random(100) + 1;
                   if GDConsts.raceLimits[race].strExcMax[gender] < strExc then
                     strExc := GDConsts.raceLimits[race].strExcMax[gender]
                 end
             end;
          C_Stat.INTELLIGENCE: begin
               if GDConsts.ageLimit[race].limit[1] < age then Inc(stats[i].cur);
               if GDConsts.ageLimit[race].limit[3] < age then Inc(stats[i].cur);
               if stats[i].cur < GDConsts.raceLimits[race].intMin then
                 stats[i].cur := GDConsts.raceLimits[race].intMin;
               if stats[i].cur > GDConsts.raceLimits[race].intMax then
                 stats[i].cur := GDConsts.raceLimits[race].intMax;
               if stats[i].cur < GDConsts.classMin[charClass, i] then
                 stats[i].cur := GDConsts.classMin[charClass, i]
             end;
          C_Stat.WISDOM: begin
               if GDConsts.ageLimit[race].limit[0] >= age then Dec(stats[i].cur);
               if GDConsts.ageLimit[race].limit[1] < age then Inc(stats[i].cur);
               if GDConsts.ageLimit[race].limit[2] < age then Inc(stats[i].cur);
               if GDConsts.ageLimit[race].limit[3] < age then Inc(stats[i].cur);
               if stats[i].cur < GDConsts.raceLimits[race].wisMin then
                 stats[i].cur := GDConsts.raceLimits[race].wisMin;
               if stats[i].cur > GDConsts.raceLimits[race].wisMax then
                 stats[i].cur := GDConsts.raceLimits[race].wisMax;
               if stats[i].cur < GDConsts.classMin[charClass, i] then
                 stats[i].cur := GDConsts.classMin[charClass, i];
               if (stats[i].cur < 13) and
                   (charClass in
                    [C_Class.CLERIC_FIGHTER, C_Class.CLERIC_FIGHTER_MAGE, C_Class.CLERIC_RANGER,
                     CharGen.CLASS_CLERIC_MAGE, CharGen.CLASS_CLERIC_THIEF]) then
                 stats[i].cur := 13
             end;
          C_Stat.DEXTERITY: begin
               if GDConsts.ageLimit[race].limit[2] < age then Dec(stats[i].cur, 2);
               if GDConsts.ageLimit[race].limit[3] < age then Dec(stats[i].cur);
               if stats[i].cur < GDConsts.raceLimits[race].dexMin then
                 stats[i].cur := GDConsts.raceLimits[race].dexMin;
               if stats[i].cur > GDConsts.raceLimits[race].dexMax then
                 stats[i].cur := GDConsts.raceLimits[race].dexMax;
               if stats[i].cur < GDConsts.classMin[charClass, i] then
                 stats[i].cur := GDConsts.classMin[charClass, i]
             end;
          C_Stat.CONSTITUTION: begin
               if GDConsts.ageLimit[race].limit[1] < age then Dec(stats[i].cur);
               if GDConsts.ageLimit[race].limit[2] < age then Dec(stats[i].cur);
               if GDConsts.ageLimit[race].limit[3] < age then Dec(stats[i].cur);
               if stats[i].cur < GDConsts.raceLimits[race].conMin then
                 stats[i].cur := GDConsts.raceLimits[race].conMin;
               if stats[i].cur > GDConsts.raceLimits[race].conMax then
                 stats[i].cur := GDConsts.raceLimits[race].conMax;
               if stats[i].cur < GDConsts.classMin[charClass, i] then
                 stats[i].cur := GDConsts.classMin[charClass, i]
             end;
          C_Stat.CHARISMA: begin
               if stats[i].cur < GDConsts.raceLimits[race].chaMin then
                 stats[i].cur := GDConsts.raceLimits[race].chaMin;
               if stats[i].cur > GDConsts.raceLimits[race].chaMax then
                 stats[i].cur := GDConsts.raceLimits[race].chaMax;
               if stats[i].cur < GDConsts.classMin[charClass, i] then
                 stats[i].cur := GDConsts.classMin[charClass, i]
             end
        end;
      Types.PCharRecord(cr)^.stats[i].base := Types.PCharRecord(cr)^.stats[i].cur;
      if i = C_Stat.STRENGTH then Types.PCharRecord(cr)^.strExcBase := Types.PCharRecord(cr)^.strExc;
      ViewChar.PrintStat(i, False)
    end;
    with Types.PCharRecord(cr)^ do begin
      hpCur := hpMax;
      attacks := 2;
      unarmedRolls[1] := 1;
      unarmedDice[1] := 2;
      useStrength := 1;
      movementBase := 12;
      hpRoll := 0;
      clsCount := 0;
      hpTotal := 0;
      FillChar(slots, SizeOf(slots), 0);
      for cls := 0 to 7 do
        if classLevels[cls] > 0 then begin
          case cls of
            C_Class.CLERIC: if deity <= 4 then slots[0, 1] := 1
               else slots[0, 1] := 2;
            C_Class.MAGE: slots[3, 1] := 1
          end;
          case cls of
            C_Class.KNIGHT: hpTotal := FxEngine.RollDice(1, 4);
            C_Class.FIGHTER, C_Class.RANGER: Inc(hpTotal, FxEngine.RollDice(5, 4));
            C_Class.CLERIC: begin
                 Inc(hpTotal, FxEngine.RollDice(3, 6));
                 ClassCal.RecalcClericSlots(cr);
                 slot := 1;
                 j := 255;
                 while (slot <= 10) and (j <> 0) do begin
                   j := GDConsts.knownSpellTable[1, 1, slot];
                   if j <> 0 then
                     spellsKnown[j] := 1;
                   Inc(slot)
                 end
               end;
            C_Class.MAGE: begin
                 Inc(hpTotal, FxEngine.RollDice(2, 4));
                 spellsKnown[11] := 1;
                 spellsKnown[18] := 1;
                 spellsKnown[12] := 1;
                 spellsKnown[15] := 1;
                 spellsKnown[21] := 1
               end;
            C_Class.THIEF: Inc(hpTotal, FxEngine.RollDice(2, 6))
          end;
          Inc(clsCount)
        end;
      if cls <> C_Class.KNIGHT then hpTotal := (hpTotal div clsCount) * 5;
      Inc(hpTotal, (hpTotal * 20) div 100);
      coinsA[4] := hpTotal
    end;
    Types.PCharRecord(cr)^.hpMax := 0;
    Types.PCharRecord(cr)^.hpRolled := 0;
    Types.PCharRecord(cr)^.hpCur := 0;
    CharGen.RollFirstLevelHp(cr, 255, clsCount);
    savedPanel := Byte(GDVars.zone1^.trainMask);
    GDVars.zone1^.trainMask := $FF;
    GDVars.trainMenuDone := 0;
    GDVars.knightTrainingMode := 1;
    repeat
      CharGen.TrainingMenu
    until GDVars.trainMenuDone <> 0;
    GDVars.zone1^.trainMask := savedPanel;
    GDVars.knightTrainingMode := 0;
    keepFlag := False;
    line := '';
    for cls := 0 to 7 do
      if (Types.PCharRecord(GDVars.curChar)^.classLevels[cls] > 0) or
         ((Types.PCharRecord(GDVars.curChar)^.classLevels2[cls] <
           ClassCal.CurrentDualClassLevel(GDVars.curChar)) and
          (Types.PCharRecord(GDVars.curChar)^.classLevels2[cls] > 0)) then begin
        if keepFlag then line := line + '/';
        line :=
          line + CharHlp.Uint8Str(Types.PCharRecord(GDVars.curChar)^.classLevels[cls] +
                                  Types.PCharRecord(GDVars.curChar)^.classLevels2[cls]);
        keepFlag := True
      end;
    TextRend.displayString(7, 7, White, Black, line);
    ViewChar.PrintCombatStats;
    ViewChar.PrintMoney;
    ch := MenuCore.YesNoMenu('Reroll stats? ', LightMagenta, LightGreen, White)
  until ch = 'N';
  ViewChar.DisplayChar;
  repeat
    Types.PCharRecord(cr)^.name := TextRend.readString('Character name: ', LightMagenta, Black, 15)
  until Types.PCharRecord(cr)^.name <> '';
  CharGen.SetDefaultIcon;
  CharGen.CustomizeIcon;
  for i := 0 to 5 do
    Types.PCharRecord(cr)^.stats[i].base := Types.PCharRecord(cr)^.stats[i].cur;
  Types.PCharRecord(cr)^.strExcBase := Types.PCharRecord(cr)^.strExc;
  ch := MenuCore.YesNoMenu('Save ' + Types.PCharRecord(cr)^.name + '? ', LightMagenta, LightGreen, White);
  if ch = 'N' then
  begin
    CharGen.FreeCreature(cr);
    GDVars.curChar := savedCur
  end else begin
    if Types.PCharRecord(cr)^.classLevels[C_Class.KNIGHT] > 0 then
      CharGen.InitStartingMoney(cr);
    SaveLoad.SaveChar(cr, '');
    CharGen.FreeCreature(cr);
    GDVars.curChar := savedCur
  end
end;

{ Looks up the current character's Constitution hit-point bonus for a class: -2 at 3, -1 at 4..6, 0 at 7..14, 1 at 15, 2
  at 16, and at 17..19 Constitution - 14 for a fighter, ranger or knight and 2 for others. Note: other values leave the
  result undefined.
  @param(charClass The class.)
  @returns(The bonus per hit die.) }
function ConHpBonus(charClass: Byte): ShortInt;
var
  bonus: ShortInt;
begin
  case Types.PCharRecord(GDVars.curChar)^.stats[C_Stat.CONSTITUTION].cur of
    3: bonus := -2;
    4..6: bonus := -1;
    7..14: bonus := 0;
    15: bonus := 1;
    16: bonus := 2;
    17..19:
      if (charClass = C_Class.FIGHTER) or (charClass = C_Class.RANGER) or
          (charClass = C_Class.KNIGHT) then
        bonus := Types.PCharRecord(GDVars.curChar)^.stats[C_Stat.CONSTITUTION].cur - 14
      else
        bonus := 2;
  end;
  ConHpBonus := bonus;
end;

{ Drops the selected character for good after asking twice: deletes its saved files and removes it from the party. }
procedure DropCharacterMenu;
var
  { Unused in this version; see the other implementations of this routine. }
  answer: Byte;
begin
  if ViewChar.PickCharacter then begin
    if GDVars.curChar <> nil then
      with Types.PCharRecord(GDVars.curChar)^ do begin
        if (MenuCore.YesNoMenu('Drop ' + name + ' forever? ', Yellow, LightGreen, White) = 'Y')
           and (MenuCore.YesNoMenu('Are you sure? ', Yellow, LightGreen, White) = 'Y') then
        begin
          if inPlay = 0 then
            CharHlp.PrintBottomLine('You dump ' + name + ' out back.')
          else
            CharHlp.PrintBottomLine(name + ' bids you farewell.');
          SaveLoad.DeleteCharacterFiles(GDVars.curChar);
          CharGen.RemoveCreature(False, True);
        end else
          CharHlp.PrintBottomLine(name + ' breathes a sigh of relief.');
      end;
    CharHlp.DisplayParty(GDVars.curChar);
  end;
end;

{ Lets the player adjust a picked new character (one still at a starting experience total and never dual-classed): its
  six abilities within the race and class limits, its maximum hit points between HpMinimum and HpMaximum, and its name.
  The arrow keys or a mouse click move between fields, Add and Subtract change them, Keep accepts and Exit or Escape
  undoes every change. Keeping recalculates the spell slots, marks the character modified and works out its rolled hit
  points again. }
procedure ModifyCharacterMenu;
var
  savedStats: array[0..5] of Byte;
  savedStr: Byte;
  savedHp: Byte;
  savedName: String[40];
  { Unused in this version; see the other implementations of this routine. }
  nameIdx: Byte;
  cls: ShortInt;
  i: ShortInt;
  key: Char;
  ext: Boolean;
  field: Byte;
  { Unused in this version; see the other implementations of this routine. }
  statRows: array[1..7] of Byte;
  cursorCol: Byte;
  j: Byte;

  { Draws the field being modified, highlighted when idx is nonzero. }
  procedure DisplayModifyField(idx: Byte);
  begin
    case field of
      0..5: ViewChar.PrintStat(field, Boolean(idx));
      7: CharHlp.PrintHitPoints(GDVars.curChar, 31, 3, Boolean(idx), False);
      6: if idx <> 0 then begin
           TextRend.printSpaces(Length(GDVars.curChar^.name) + 1, 1, Black, 1);
           TextRend.displayString(1, 1, LightMagenta, Black, GDVars.curChar^.name);
           if GDVars.curChar^.name[cursorCol] = ' ' then
             TextRend.displayString(cursorCol, 1, White, Black, '%')
           else
             TextRend.displayString(cursorCol, 1, White, Black, GDVars.curChar^.name[cursorCol])
         end else
           TextRend.displayString(1, 1, LightGreen, Black, GDVars.curChar^.name)
    end
  end;
begin
  if not ViewChar.PickCharacter then Exit;
  if not (((GDVars.curChar^.experience = 1500) or (GDVars.curChar^.experience = 1251) or
           (GDVars.curChar^.experience = 2000) or (GDVars.curChar^.experience = 2001) or
           (GDVars.curChar^.experience = 2251) or (GDVars.curChar^.experience = 2500) or
           (GDVars.curChar^.experience = 5000)) and (GDVars.curChar^.dualClassThreshold = 0)) then begin
    TextRend.printAndPause(GDVars.curChar^.name + ' can''t be modified.', Yellow, Black);
    Exit
  end;
  GDVars.modifyMouseRow := 255;
  GDVars.modifyActive := 1;
  ViewChar.DisplayChar;
  for i := 0 to 5 do savedStats[i] := GDVars.curChar^.stats[i].cur;
  savedStr := GDVars.curChar^.strExc;
  savedHp := GDVars.curChar^.hpMax;
  savedName := GDVars.curChar^.name;
  cursorCol := 1;
  field := 7;
  DisplayModifyField(0);
  field := C_Stat.STRENGTH;
  DisplayModifyField(1);
  with GDVars.curChar^ do
  repeat
    if field = 6 then begin
      ext := False;
      repeat until GameIo.InputPending;
      key := GameIo.ReadGameKey;
      if key in ['1'..'9', '\'] then
      begin
        if key = '\' then key := '7'
        else key := Chr(GDConsts.digitScanCodes[Ord(key) - Ord('1')]);
        ext := True
      end;
      if key = #0 then begin
        key := GameIo.ReadGameKey;
        ext := True
      end;
      if key = C_Keys.ESCAPE then key := C_Keys.NONE
    end else
      key := MenuCore.MenuHorizontal('Modify: ', 'Add Subtract Keep Exit', LightMagenta, LightGreen, White, True, False,
                                     ext);
    DisplayModifyField(0);
    if ext then
      case key of
        CharGen.KEY_DEL: if (field = 6) and (Length(GDVars.curChar^.name) > 1) then begin
                if cursorCol = Length(GDVars.curChar^.name) then begin
                  Dec(GDVars.curChar^.name[0]);
                  cursorCol := Length(GDVars.curChar^.name)
                end else begin
                  for j := cursorCol to Length(GDVars.curChar^.name) - 1 do
                    GDVars.curChar^.name[j] := GDVars.curChar^.name[j + 1];
                  Dec(GDVars.curChar^.name[0])
                end
              end;
        C_Keys.DOWN: begin
                GDVars.modifyMouseRow := 255;
                Inc(field);
                if field > 7 then field := 0
              end;
        C_Keys.UP: begin
                GDVars.modifyMouseRow := 255;
                Dec(field);
                if field = 255 then field := 7
              end;
        C_Keys.HOME: if (GDVars.mouseButtonSeen <> 0) and (GDVars.modifyMouseRow <> 255) then
                field := GDVars.modifyMouseRow
      end else
      case key of
        'S': if field < 6 then
             begin
               i := field;
               Dec(stats[i].cur);
               case i of
                 C_Stat.STRENGTH: begin
                      if strExc > 0 then
                      begin Dec(strExc); Inc(stats[i].cur) end
                      else if stats[i].cur < GDConsts.raceLimits[race].strMin[gender] then
                        stats[i].cur := GDConsts.raceLimits[race].strMin[gender];
                      if stats[i].cur < GDConsts.classMin[charClass, C_Stat.STRENGTH] then
                        stats[i].cur := GDConsts.classMin[charClass, C_Stat.STRENGTH]
                    end;
                 C_Stat.INTELLIGENCE: begin
                      if stats[i].cur < GDConsts.raceLimits[race].intMin then
                        stats[i].cur := GDConsts.raceLimits[race].intMin;
                      if stats[i].cur < GDConsts.classMin[charClass, C_Stat.INTELLIGENCE] then
                        stats[i].cur := GDConsts.classMin[charClass, C_Stat.INTELLIGENCE]
                    end;
                 C_Stat.WISDOM: begin
                      if stats[i].cur < GDConsts.raceLimits[race].wisMin then
                        stats[i].cur := GDConsts.raceLimits[race].wisMin;
                      if stats[i].cur < GDConsts.classMin[charClass, C_Stat.WISDOM] then
                        stats[i].cur := GDConsts.classMin[charClass, C_Stat.WISDOM];
                      if slots[0, 1] > 0 then slots[0, 1] := 1
                    end;
                 C_Stat.DEXTERITY: begin
                      if stats[i].cur < GDConsts.raceLimits[race].dexMin then
                        stats[i].cur := GDConsts.raceLimits[race].dexMin;
                      if stats[i].cur < GDConsts.classMin[charClass, C_Stat.DEXTERITY] then
                        stats[i].cur := GDConsts.classMin[charClass, C_Stat.DEXTERITY]
                    end;
                 C_Stat.CONSTITUTION: begin
                      if stats[i].cur < GDConsts.raceLimits[race].conMin then
                        stats[i].cur := GDConsts.raceLimits[race].conMin;
                      if stats[i].cur < GDConsts.classMin[charClass, C_Stat.CONSTITUTION] then
                        stats[i].cur := GDConsts.classMin[charClass, C_Stat.CONSTITUTION];
                      if CharGen.HpMaximum(Types.PCharRecord(GDVars.curChar)) < hpMax then
                        hpMax := CharGen.HpMaximum(Types.PCharRecord(GDVars.curChar));
                      hpCur := hpMax;
                      field := 6; DisplayModifyField(0); field := C_Stat.CONSTITUTION
                    end;
                 C_Stat.CHARISMA: begin
                      if stats[i].cur < GDConsts.raceLimits[race].chaMin then
                        stats[i].cur := GDConsts.raceLimits[race].chaMin;
                      if stats[i].cur < GDConsts.classMin[charClass, C_Stat.CHARISMA] then
                        stats[i].cur := GDConsts.classMin[charClass, C_Stat.CHARISMA]
                    end
               end
             end else if field = 7 then begin
               Dec(hpMax);
               if CharGen.HpMinimum(Types.PCharRecord(GDVars.curChar)) > hpMax then
                 hpMax := CharGen.HpMinimum(Types.PCharRecord(GDVars.curChar));
               hpCur := hpMax
             end else if cursorCol = 1 then cursorCol := Length(GDVars.curChar^.name)
             else Dec(cursorCol);
        'A': if field < 6 then
             begin
               i := field;
               Inc(stats[i].cur);
               case i of
                 C_Stat.STRENGTH: if stats[i].cur > GDConsts.raceLimits[race].strMax[gender] then begin
                      if stats[i].cur > 18 then
                        if (classLevels[C_Class.FIGHTER] > 0) or (classLevels[C_Class.KNIGHT] > 0)
                           or (classLevels[C_Class.RANGER] > 0) then
                          if GDConsts.raceLimits[race].strExcMax[gender] > strExc then Inc(strExc);
                      stats[i].cur := GDConsts.raceLimits[race].strMax[gender]
                    end;
                 C_Stat.INTELLIGENCE: if stats[i].cur > GDConsts.raceLimits[race].intMax then
                      stats[i].cur := GDConsts.raceLimits[race].intMax;
                 C_Stat.WISDOM: begin
                      if stats[i].cur > GDConsts.raceLimits[race].wisMax then
                        stats[i].cur := GDConsts.raceLimits[race].wisMax;
                      if slots[0, 1] > 0 then slots[0, 1] := 1
                    end;
                 C_Stat.DEXTERITY: if stats[i].cur > GDConsts.raceLimits[race].dexMax then
                      stats[i].cur := GDConsts.raceLimits[race].dexMax;
                 C_Stat.CONSTITUTION: begin
                      if stats[i].cur > GDConsts.raceLimits[race].conMax then
                        stats[i].cur := GDConsts.raceLimits[race].conMax;
                      if CharGen.HpMinimum(Types.PCharRecord(GDVars.curChar)) > hpMax then
                        hpMax := CharGen.HpMinimum(Types.PCharRecord(GDVars.curChar));
                      hpCur := hpMax;
                      field := 6; DisplayModifyField(0); field := C_Stat.CONSTITUTION
                    end;
                 C_Stat.CHARISMA: if stats[i].cur > GDConsts.raceLimits[race].chaMax then
                      stats[i].cur := GDConsts.raceLimits[race].chaMax
               end
             end else if field = 7 then begin
               Inc(hpMax);
               if CharGen.HpMaximum(Types.PCharRecord(GDVars.curChar)) < hpMax then
                 hpMax := CharGen.HpMaximum(Types.PCharRecord(GDVars.curChar));
               hpCur := hpMax
             end else if cursorCol = Length(GDVars.curChar^.name) then cursorCol := 1
             else Inc(cursorCol);
        C_Keys.ENTER: begin Inc(field); if field > 7 then field := 0 end;
        C_Keys.BACKSPACE: if (cursorCol > 1) and (field = 6) then begin
                for j := cursorCol to Length(GDVars.curChar^.name) do
                  GDVars.curChar^.name[j - 1] := GDVars.curChar^.name[j];
                Dec(GDVars.curChar^.name[0]);
                if cursorCol > Length(GDVars.curChar^.name) then
                  cursorCol := Length(GDVars.curChar^.name)
              end;
        #32..#122:
          if field = 6 then begin
            if cursorCol <= 15 then begin
              GDVars.curChar^.name[cursorCol] := key;
              Inc(cursorCol);
              if cursorCol > 15 then cursorCol := 15;
              if cursorCol > Length(GDVars.curChar^.name) then begin
                Inc(GDVars.curChar^.name[0]);
                GDVars.curChar^.name[cursorCol] := ' '
              end
            end
          end else if key = 'E' then
          begin
            for i := 0 to 5 do GDVars.curChar^.stats[i].cur := savedStats[i];
            GDVars.curChar^.strExc := savedStr;
            GDVars.curChar^.hpMax := savedHp;
            GDVars.curChar^.hpCur := hpMax;
            GDVars.curChar^.name := savedName;
            CharHlp.RecalcStats(GDVars.curChar);
            GDVars.modifyActive := 0;
            Exit
          end;
        C_Keys.NONE: begin
              for i := 0 to 5 do GDVars.curChar^.stats[i].cur := savedStats[i];
              GDVars.curChar^.strExc := savedStr;
              GDVars.curChar^.hpMax := savedHp;
              GDVars.curChar^.name := savedName;
              GDVars.curChar^.hpCur := hpMax;
              CharHlp.RecalcStats(GDVars.curChar);
              GDVars.modifyActive := 0;
              Exit
            end
      end;
    CharHlp.RecalcStats(GDVars.curChar);
    ViewChar.PrintCombatStats;
    DisplayModifyField(1)
  until (not ext) and (key = 'K');
  ClassCal.RecalcClericSlots(GDVars.curChar);
  GDVars.curChar^.modified := 1;
  with GDVars.curChar^ do begin
    savedHp := 0;
    j := 0;
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        if Byte(classLevels[cls]) < GDConsts.hitDiceLimit[cls] then begin
          if cls = C_Class.RANGER then
            Inc(savedHp, CharGen.ConHpBonus(cls) * (classLevels[cls] + 1))
          else
            Inc(savedHp, CharGen.ConHpBonus(cls) * classLevels[cls])
        end else
          Inc(savedHp, CharGen.ConHpBonus(cls) * (GDConsts.hitDiceLimit[cls] - 1));
        Inc(j)
      end;
    savedHp := savedHp div j;
    hpRolled := hpMax - savedHp
  end;
  for i := 0 to 5 do GDVars.curChar^.stats[i].base := GDVars.curChar^.stats[i].cur;
  GDVars.curChar^.strExcBase := GDVars.curChar^.strExc;
  GDVars.modifyActive := 0
end;

{ Lists the saved characters and adds the chosen ones to the party until Exit or the party is full (six player
  characters or eight members). A character already listed with a star, already in the party, a paladin joining evil
  members, a fourth ranger, or an evil character joining a paladin is refused, the last three with a message. Note: the
  flag that offers Exit is never set, so whether Exit is offered depends on whatever the local held. }
procedure AddCharacterMenu;
var
  list: Types.PCharacterListNode;
  files: Types.PCharacterListNode;
  m: Types.PItemRec;
  fileNode: Types.PItemRec;
  cr: Types.PCharRecord;
  walk: Types.PCharRecord;
  idx: Integer;
  key: Char;
  addExit: Boolean;
  redraw: Boolean;
  nonNpc: Byte;
  rangerCount: Byte;
  evilPresent: Byte;
  paladinPresent: Byte;
  paladinName: String[40];
  { Unused in this version; see the other implementations of this routine. }
  ext: Byte;
begin
  evilPresent := 0;
  paladinPresent := 0;
  rangerCount := 0;
  GDVars.importFormat := 0;
  SaveLoad.LoadCharlist(list, files);
  if list = nil then Exit;
  idx := 0;
  m := Types.PItemRec(list);
  redraw := True;
  repeat
    key := MenuCore.MenuVertical('Add a character: ', 'Add ', LightMagenta, LightGreen, White, 1, 2, 38, 22,
                                 Types.PItemRec(list), addExit, redraw, idx, m);
    if (key = C_Keys.ENTER) or (key = 'A') then
      if m^.name[1] <> '*' then
      begin
        MenuCore.ClearBottomLine;
        GetMem(cr, SizeOf(Types.TCharRecord));
        fileNode := MenuCore.FindListMember(idx, Types.PItemRec(files));
        SaveLoad.LoadChar(fileNode^.name, Types.PCharRecord(cr), False, True);
        m^.name := '* ' + m^.name;
        nonNpc := 0;
        if GDVars.partyHead = nil then begin
          GDVars.zone1^.partySize := 0;
          SaveLoad.AddCharToParty(Types.PCharRecord(cr));
          SaveLoad.LoadCharIconAnim(True);
        end else begin
          walk := Types.PCharRecord(GDVars.partyHead);
          rangerCount := 0;
          while (walk <> nil) and ((walk^.name <> cr^.name) or (walk^.creatureId <> cr^.creatureId)) do begin
            if walk^.npc < C_Npc.NON_PLAYER then Inc(nonNpc);
            if walk^.classLevels[C_Class.RANGER] > 0 then Inc(rangerCount);
            if Byte((walk^.alignment + 1) mod 3) = 0 then evilPresent := 1;
            if walk^.classLevels[C_Class.PALADIN] > 0 then begin
              paladinPresent := 1;
              paladinName := walk^.name;
            end;
            walk := walk^.next;
          end;
          if (walk = nil) and
              (((cr^.npc < C_Npc.NON_PLAYER) and (nonNpc < 6)) or
               ((cr^.npc > $7F) and (GDVars.zone1^.partySize < 8))) and
              ((cr^.classLevels[C_Class.PALADIN] = 0) or (evilPresent = 0)) and
              ((cr^.classLevels[C_Class.RANGER] = 0) or (rangerCount < 3)) and
              ((Byte((cr^.alignment + 1) mod 3) <> 0) or (paladinPresent = 0)) then begin
            SaveLoad.AddCharToParty(Types.PCharRecord(cr));
            SaveLoad.LoadCharIconAnim(True);
            if cr^.npc < C_Npc.NON_PLAYER then Inc(nonNpc);
          end else begin
            Delete(m^.name, 1, 2);
            if (cr^.classLevels[C_Class.PALADIN] > 0) and (evilPresent <> 0) then begin
              CharHlp.PrintBottomLine('paladins do not join with evil scum');
              TextRend.pauseOnly;
            end else if (cr^.classLevels[C_Class.RANGER] > 0) and (rangerCount > 2) then
              CharHlp.PrintBottomLine('too many rangers in party')
            else if (Byte((cr^.alignment + 1) mod 3) = 0) and (paladinPresent <> 0) then
              CharHlp.PrintBottomLine(paladinName + ' will tolerate no evil!');
            FreeMem(cr, SizeOf(Types.TCharRecord));
          end;
        end;
      end;
  until (key = 'E') or (key = C_Keys.NONE) or (nonNpc > 5) or (GDVars.zone1^.partySize > 7);
  MenuCore.FreeStringList(Types.PItemRec(list));
end;

procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);
var
  cur: Types.PCharRecord;
begin
  if GDVars.partyHead <> nil then begin
    cur := GDVars.partyHead;
    if cur <> GDVars.curChar then begin
      while (cur^.next <> GDVars.curChar) and (cur^.next <> nil) do
        cur := cur^.next;
      if cur^.next <> nil then begin
        if freeAnim then MapTiles.FreeIconAnim(GDVars.curChar^.orderNumber);
        cur^.next := GDVars.curChar^.next;
        CharGen.FreeCreature(GDVars.curChar);
        GDVars.curChar := cur;
        if not suppressSizeDec then Dec(GDVars.zone1^.partySize);
      end;
    end else begin
      if freeAnim then MapTiles.FreeIconAnim(GDVars.curChar^.orderNumber);
      GDVars.partyHead := GDVars.curChar^.next;
      cur := GDVars.curChar^.next;
      CharGen.FreeCreature(GDVars.curChar);
      GDVars.curChar := cur;
      if not suppressSizeDec then Dec(GDVars.zone1^.partySize);
    end;
    if GDVars.curChar = nil then GDVars.curChar := GDVars.partyHead;
  end;
end;

{ Picks the current character's default icon head from its race, gender and icon size, and its body from its classes. }
procedure SetDefaultIcon;
begin
  with Types.PCharRecord(GDVars.curChar)^ do begin
    if race = C_Race.KENDER then
      iconHead := 3
    else if gender = 1 then
      if iconSize = 2 then iconHead := 9 else iconHead := 7
    else if iconSize = 2 then
      iconHead := 5
    else
      iconHead := 0;

    if classLevels[C_Class.CLERIC] > 0 then
      iconBody := 23
    else if classLevels[C_Class.RANGER] > 0 then
      iconBody := 1
    else if (classLevels[C_Class.KNIGHT] > 0) or (classLevels[C_Class.FIGHTER] > 0) then
      iconBody := 24
    else if classLevels[C_Class.MAGE] > 0 then
      iconBody := 29
    else
      iconBody := 5;
  end;
end;

procedure CustomizeIcon;
var
  { Unused in this version; see the other implementations of this routine. }
  oldState: Byte;
  key: Char;
  ext: Boolean;
  savedHead: Byte;
  savedBody: Byte;
  savedSize: Byte;
  savedOrd: Byte;
  state: Byte;
  sizeStr: String[5];
  { Unused in this version; see the other implementations of this routine. }
  partIdx: Byte;
  savedCols: Types.TIconColors;
  slot: Byte;
  which: Byte;
  lowColor: Byte;
  highColor: Byte;
  lastState: Byte;
  partKey: Char;

  { Draws the edited icon's two frames at a map cell, over a cursor backdrop outside CGA. }
  procedure ShowIconFrames(y, x: Byte);
  begin
    if GDVars.displayMode = Types.Cga then
      Blit.FillPicRect(y * 3, x * 24, 12, 24, 3, GDConsts.cmapStd, GDVars.egaDest)
    else begin
      Blit.FillPicRect(y * 3, x * 24, 12, 24, 0, GDConsts.cmapStd, GDVars.egaDest);
      MapTiles.DrawIconAnimSprite(y, x, 0, 0, 25);
      MapTiles.DrawIconAnimSprite(y + 3, x, 0, 0, 25);
    end;
    MapTiles.DrawIconAnimSprite(y, x, 0, 0, 12);
    MapTiles.DrawIconAnimSprite(y + 3, x, 0, 1, 12);
    Blit.FlushView;
  end;

  { Copies an icon slot's two frames to another, recoloring them with the character's icon colors when asked. }
  procedure CopyIconPics(src, dst: Byte; applyColors: Boolean);
  var
    i: Byte;
    { Unused in this version; see the other implementations of this routine. }
    frameIdx: Byte;
    fromT: Types.TColorTab;
    toT: Types.TColorTab;
    sizeT: Word;
  begin
    sizeT := GDVars.iconAnims[dst, 0]^.imgSize;
    Move(GDVars.iconAnims[src, 0]^.data, GDVars.iconAnims[dst, 0]^.data, GDVars.iconAnims[dst, 0]^.imgSize);
    Move(GDVars.iconAnims[src, 1]^.data, GDVars.iconAnims[dst, 1]^.data, GDVars.iconAnims[dst, 1]^.imgSize);
    Move(GDVars.iconAnims[src, 0]^.transp^, GDVars.iconAnims[dst, 0]^.transp^, sizeT);
    Move(GDVars.iconAnims[src, 1]^.transp^, GDVars.iconAnims[dst, 1]^.transp^, sizeT);
    if applyColors then
      with Types.PCharRecord(GDVars.curChar)^ do begin
        for i := 0 to 15 do begin fromT[i] := i; toT[i] := i end;
        for i := 1 to 6 do begin
          toT[GDConsts.defIconColors[i]] := iconColors[i] and $0F;
          toT[GDConsts.defIconColors[i] + 8] := (iconColors[i] and $F0) shr 4;
        end;
        Blit.RemapPic(fromT, toT, 0, False, GDVars.iconAnims[dst, 0]);
        Blit.RemapPic(fromT, toT, 0, False, GDVars.iconAnims[dst, 1]);
      end;
  end;
begin
  Border.DrawWindowFrame(True);
  CbtMap.SetCombatPalette;
  repeat
    SaveLoad.LoadCharIconAnim(False);
    with Types.PCharRecord(GDVars.curChar)^ do begin
      state := 1;
      savedCols := iconColors;
      savedOrd := orderNumber;
      orderNumber := 12;
      SaveLoad.LoadCharIconAnim(False);
      orderNumber := savedOrd;
      savedHead := iconHead; savedBody := iconBody; savedSize := iconSize;
      CopyIconPics(orderNumber, 12, True);
      ShowIconFrames(1, 2);
      TextRend.displayString(8, 6, White, Black, 'old');
      TextRend.displayString(3, 10, White, Black, 'ready   action');
      TextRend.displayString(8, 12, White, Black, 'new');
      TextRend.displayString(3, 16, White, Black, 'ready   action');
      repeat
        ShowIconFrames(1, 4);
        sizeStr := '';
        if state = 4 then
          if iconSize = 2 then sizeStr := 'Small' else sizeStr := 'Large';
        key := MenuCore.MenuHorizontal('', sizeStr + GDConsts.iconMenuTexts[state], LightMagenta, LightGreen, White,
                                       False, False, ext);
        if not ext then
          case state of
            1: begin
                 lastState := 1;
                 case key of
                   'P': state := 2;
                   '1': if GDVars.displayMode = Types.Cga then
                          TextRend.printAndPause('Sorry, not in CGA', Yellow, Black)
                        else begin
                          state := 3; which := 0;
                          Delete(GDConsts.iconMenuTexts[3], 13, 4);
                          Insert('Hair', GDConsts.iconMenuTexts[3], 13)
                        end;
                   '2': if GDVars.displayMode = Types.Cga then
                          TextRend.printAndPause('Sorry, not in CGA', Yellow, Black)
                        else begin
                          state := 3; which := 1;
                          Delete(GDConsts.iconMenuTexts[3], 13, 4);
                          Insert('Face', GDConsts.iconMenuTexts[3], 13)
                        end;
                   'S': state := 4
                 end
               end;
            2: begin
                 lastState := 2;
                 if key in [C_Keys.NONE, 'E'] then state := 1
                 else begin partKey := key; state := 5 end
               end;
            3: begin
                 lastState := 3;
                 case key of
                   'W': slot := 6; 'B': slot := 1; 'H': slot := 4;
                   'F': slot := 4;
                   'S': slot := 5; 'A': slot := 2; 'L': slot := 3
                   else slot := 1
                 end;
                 if key in [C_Keys.NONE, 'E'] then state := 1 else state := 5
               end;
            4: begin
                 case key of
                   'L': begin iconSize := 2; SaveLoad.LoadCharIconAnim(False) end;
                   'S': begin iconSize := 1; SaveLoad.LoadCharIconAnim(False) end;
                   'K': begin savedSize := iconSize; state := 1; key := ' ' end;
                   'E', C_Keys.NONE: begin iconSize := savedSize; state := 1; key := ' ' end
                 end;
                 SaveLoad.LoadCharIconAnim(False)
               end;
            5: case lastState of
                 2: case partKey of
                      'H': begin
                        case key of
                          'P': if iconHead > 0 then Dec(iconHead) else iconHead := 13;
                          'N': if iconHead < 13 then Inc(iconHead) else iconHead := 0;
                          'K': begin
                            with Types.PCharRecord(GDVars.curChar)^ do savedHead := iconHead;
                            state := lastState; key := ' '
                          end;
                          'E', C_Keys.NONE: begin iconHead := savedHead; state := lastState; key := ' ' end
                        end;
                        SaveLoad.LoadCharIconAnim(False)
                      end;
                      'W': begin
                        case key of
                          'P': if iconBody > 0 then Dec(iconBody) else iconBody := 31;
                          'N': if iconBody < 31 then Inc(iconBody) else iconBody := 0;
                          'K': begin
                            with Types.PCharRecord(GDVars.curChar)^ do savedBody := iconBody;
                            state := lastState; key := ' '
                          end;
                          'E', C_Keys.NONE: begin iconBody := savedBody; state := lastState; key := ' ' end
                        end;
                        SaveLoad.LoadCharIconAnim(False)
                      end
                    end;
                 3: begin
                      lowColor := iconColors[slot] and $0F;
                      highColor := (iconColors[slot] and $F0) shr 4;
                      case key of
                        'N': begin
                          if which <> 0 then highColor := (highColor + 1) mod 16
                          else lowColor := (lowColor + 1) mod 16;
                          iconColors[slot] := highColor shl 4 + lowColor
                        end;
                        'P': begin
                          if which <> 0 then highColor := (highColor - 1) and $0F
                          else lowColor := (lowColor - 1) and $0F;
                          iconColors[slot] := highColor shl 4 + lowColor
                        end;
                        'K': begin savedCols := iconColors; state := lastState; key := ' ' end;
                        'E', C_Keys.NONE: begin iconColors := savedCols; state := lastState; key := ' ' end
                      end
                    end
               end
          end;
        CopyIconPics(orderNumber, 12, True)
      until (lastState = 1) and (key in [C_Keys.NONE, 'E']);
      iconHead := savedHead; iconBody := savedBody; iconSize := savedSize;
      iconColors := savedCols;
      CopyIconPics(orderNumber, 12, True);
      CopyIconPics(12, orderNumber, False)
    end;
    MenuCore.ClearBottomLine;
    MapTiles.FreeIconAnim(12);
    key := MenuCore.YesNoMenu('Is this icon ok? ', LightMagenta, LightGreen, White)
  until key = 'Y';
  CbtMap.SetNoncombatPalette
end;

{ Looks up a creature's Constitution hit-point bonus for one class from conHpTable; a fighter, knight or ranger gets 1
  to 5 more at Constitution 17 to 25.
  @param(cr The creature.)
  @param(charClass The class.)
  @returns(The bonus per hit die.) }
function ClassConHpBonus(cr: Types.PCharRecord; charClass: Byte): Byte;
var
  bonus: Byte;
  { Unused in this version; see the other implementations of this routine. }
  tableBonus: Word;
begin
  bonus := 0;
  Inc(bonus, GDConsts.conHpTable[cr^.stats[C_Stat.CONSTITUTION].cur]);
  if (charClass = C_Class.FIGHTER) or (charClass = C_Class.KNIGHT) or
      (charClass = C_Class.RANGER) then
    case cr^.stats[C_Stat.CONSTITUTION].cur of
      17: Inc(bonus);
      18: Inc(bonus, 2);
      19, 20: Inc(bonus, 3);
      21..23: Inc(bonus, 4);
      24, 25: Inc(bonus, 5)
    end;
  ClassConHpBonus := bonus
end;

{ Works out the lowest maximum hit points a character may be given: one point per level of each class (a level more for
  a ranger or knight) plus each class's Constitution bonus, averaged over the classes, at least 1 when the bonus is
  negative.
  @param(cr The character.)
  @returns(The minimum.) }
function HpMinimum(cr: Types.PCharRecord): Byte;
var
  clsCount: Byte;
  conB: ShortInt;
  sum: Byte;
  cls: ShortInt;
begin
  with cr^ do begin
    conB := 0;
    clsCount := 0;
    sum := 0;
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        Inc(sum, classLevels[cls]);
        Inc(clsCount);
        case cls of
          C_Class.RANGER: Inc(sum);
          C_Class.KNIGHT: Inc(sum)
        end;
        Inc(conB, CharGen.ClassConHpBonus(Types.PCharRecord(cr), cls))
      end
  end;
  if conB < 0 then begin
    if sum > Abs(conB) + clsCount then
      sum := (sum + conB) div clsCount
    else
      sum := 1
  end else
    sum := (sum + conB) div clsCount;
  HpMinimum := sum
end;

{ Works out the highest maximum hit points a character may be given: per class, its hit die's top value plus the
  Constitution bonus for each level (a level more for a ranger, a knight and a cleric of deity 4 or below), or a fixed
  figure past the class's hit-dice limit, averaged over the classes.
  @param(cr The character.)
  @returns(The maximum.) }
function HpMaximum(cr: Types.PCharRecord): Byte;
var
  clsCount: Byte;
  sum: Byte;
  conB: ShortInt;
  cls: ShortInt;
  overCap: Byte;
begin
  with cr^ do begin
    clsCount := 0;
    sum := 0;
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        conB := CharGen.ConHpBonus(cls);
        if Byte(classLevels[cls]) < GDConsts.hitDiceLimit[cls] then begin
          Inc(clsCount);
          case cls of
            C_Class.CLERIC: if ShortInt(deity) <= 4 then
                 Inc(sum, (conB + 8) * (classLevels[cls] + 1))
               else
                 Inc(sum, (conB + 8) * classLevels[cls]);
            1: Inc(sum, (conB + 8) * classLevels[cls]);
            C_Class.FIGHTER, C_Class.PALADIN: Inc(sum, (conB + 10) * classLevels[cls]);
            C_Class.KNIGHT: Inc(sum, (conB + 10) * (classLevels[cls] + 1));
            C_Class.RANGER: Inc(sum, (conB + 8) * (classLevels[cls] + 1));
            C_Class.MAGE: Inc(sum, (conB + 4) * classLevels[cls]);
            C_Class.THIEF: Inc(sum, (conB + 6) * classLevels[cls])
          end
        end else begin
          Inc(clsCount);
          overCap := classLevels[cls] - GDConsts.hitDiceLimit[cls] + 1;
          case cls of
            C_Class.CLERIC: sum := overCap * 2 + 72;
            1: sum := 112;
            C_Class.FIGHTER, C_Class.PALADIN, C_Class.KNIGHT: sum := overCap * 3 + 90;
            C_Class.RANGER: sum := overCap * 2 + 88;
            C_Class.MAGE: sum := overCap + 44;
            C_Class.THIEF: sum := overCap * 2 + 60
          end
        end
      end
  end;
  sum := sum div clsCount;
  HpMaximum := sum
end;

{ Rolls hit points for the classes in mask that are below their hit-dice limit, keeping the better of two rolls (one die
  past first level, or for a cleric of deity 5 and up), or a fixed gain past the limit, plus the Constitution bonus per
  die; both are divided among divisor classes. The gain goes to the rolled and maximum hit points, keeping the damage
  taken.
  @param(cr The character.)
  @param(mask Class bits of the classes rolled for.)
  @param(divisor The number of classes the gain is shared among.) }
procedure RollFirstLevelHp(cr: Types.PCharRecord; mask, divisor: Byte);
var
  roll1: Byte;
  roll2: Byte;
  sum: Byte;
  diceCount: Byte;
  bonusSum: Byte;
  cls: ShortInt;
begin
  sum := 0;
  bonusSum := 0;
  for cls := 0 to 7 do
    if cr^.classLevels[cls] > 0 then
      if GDConsts.classBits[cls] and mask > 0 then
        if Byte(cr^.classLevels[cls]) < GDConsts.hitDiceLimit[cls] then begin
          if cr^.classLevels[cls] > 1 then
            diceCount := 1
          else if (cls = C_Class.CLERIC) and (cr^.deity > 4) then
            diceCount := 1
          else
            diceCount := GDConsts.hpDice[cls];
          roll1 := FxEngine.RollDice(diceCount, GDConsts.hpSides[cls]);
          roll2 := FxEngine.RollDice(diceCount, GDConsts.hpSides[cls]);
          if roll2 > roll1 then
            roll1 := roll2;
          Inc(sum, roll1);
          Inc(bonusSum, diceCount * ShortInt(CharGen.ClassConHpBonus(cr, cls)))
        end else
          case cls of
            C_Class.FIGHTER, C_Class.KNIGHT: sum := 3;
            C_Class.RANGER, C_Class.CLERIC, C_Class.THIEF: sum := 2;
            C_Class.MAGE: sum := 1
          end;
  with cr^ do begin
    sum := sum div divisor;
    if sum < 1 then
      sum := 1;
    Inc(hpRolled, sum);
    bonusSum := bonusSum div divisor;
    roll1 := hpMax - hpCur;
    Inc(hpMax, sum + bonusSum);
    hpCur := hpMax - roll1
  end
end;

{ Trains a character a level in each class it has the experience for (or each class under free training, which raises
  the experience to match), within the kender fighter and ranger limits and the classes the zone trains; outside
  creation it picks the character, trains conscious ones only, asks first and trims experience past the level after next
  to one point below it. A class level gained recovers a drained level, recalculates the class values, lets a magic-user
  (or a ranger above level 8) pick a new spell, or during creation gives a magic-user its fixed spells, and rolls the
  new hit points. When nothing can be trained, creation's training loop is told to stop. Note: the second pass over the
  trainable classes reads the sub-order and level of the last class examined for each of them. }
procedure TrainingMenu;
var
  atLimit: Boolean;
  bestXp: LongInt;
  xpTmp: LongInt;
  maskA: Byte;
  maskB: Byte;
  trainHere: Byte;
  classCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hpTotal: Integer;
  { Unused in this version; see the other implementations of this routine. }
  avgHp: Integer;
  { Unused in this version; see the other implementations of this routine. }
  hpDelta: Byte;
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  conBonusV: Integer;
  row: Byte;
  oldLvl5: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  oldRangerLevel: ShortInt;
  curLvl: ShortInt;
  selResult: Byte;
  sentinel: Integer;
  selIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  selClass: Byte;
  trainableHere: Byte;
  bestXp2: LongInt;
  bestClass: ShortInt;
  subOrder: ShortInt;
begin
  if GDVars.knightTrainingMode = 0 then
    if not ViewChar.PickCharacter then Exit;
  if (Types.PCharRecord(GDVars.curChar)^.status <> C_Status.OKAY) and (GDVars.stingMode = 0) then begin
    TextRend.printAndPause('we only train conscious people', Yellow, Black);
    Exit
  end;
  maskA := 0;
  maskB := 0;
  bestXp := 0;
  trainableHere := Lo(GDVars.zone1^.trainMask);
  with Types.PCharRecord(GDVars.curChar)^ do begin
    bestXp := 0;
    for i := 0 to 7 do
      if classLevels[i] > 0 then begin
        Inc(maskB, GDConsts.classBits[i]);
        atLimit := False;
        curLvl := classLevels[i];
        if race = C_Race.KENDER then
          if (i = C_Class.FIGHTER) or (i = C_Class.RANGER) then
            if (curLvl = 7)
               or ((curLvl = 6) and (stats[C_Stat.STRENGTH].base = 17))
               or ((curLvl = 5) and (stats[C_Stat.STRENGTH].base < 17)) then
              atLimit := True;
        subOrder := CharHlp.ClassSuborderIndex(GDVars.curChar, i);
        if not atLimit then
          if (GDConsts.classProgression[subOrder].nextLevelXp[Succ(curLvl)] <= experience)
             or (GDVars.stingMode <> 0) then
            if GDConsts.classProgression[subOrder].nextLevelXp[Succ(curLvl)] > 0 then begin
              if GDVars.stingMode <> 0 then
                if GDConsts.classProgression[subOrder].nextLevelXp[Succ(curLvl)] > 0 then
                  if GDConsts.classProgression[subOrder].nextLevelXp[Succ(curLvl)] > experience then
                    experience := GDConsts.classProgression[subOrder].nextLevelXp[Succ(curLvl)];
              Inc(maskA, GDConsts.classBits[i]);
              xpTmp := GDConsts.classProgression[subOrder].nextLevelXp[Succ(Succ(curLvl))];
              if (xpTmp > 0) and (experience >= xpTmp)
                 and (xpTmp > bestXp) then
                bestXp := xpTmp - 1
            end
      end;
    if GDVars.knightTrainingMode = 0 then begin
      bestXp2 := 0;
      xpTmp := 0;
      for i := 0 to 7 do
        if (GDConsts.classBits[i] and maskA) <> 0 then
          if GDConsts.classProgression[subOrder].nextLevelXp[Succ(curLvl)] > bestXp2 then begin
            bestXp2 := GDConsts.classProgression[subOrder].nextLevelXp[Succ(curLvl)];
            bestClass := i
          end;
      if bestXp2 > 0 then begin
        maskA := maskA or GDConsts.classBits[bestClass];
        xpTmp := GDConsts.classProgression[subOrder].nextLevelXp[Succ(Succ(curLvl))];
        if (xpTmp > 0) and (experience >= xpTmp)
           and (xpTmp > bestXp) then
          bestXp := xpTmp - 1
      end
    end;
    if (bestXp > 0) and (GDVars.knightTrainingMode = 0) then
      experience := bestXp;
    if GDVars.stingMode = 0 then begin
      if ((maskB and trainableHere) = 0) and (GDVars.knightTrainingMode = 0) then begin
        TextRend.printAndPause('We don''t train that class here', Yellow, Black);
        Exit
      end else if (maskA and trainableHere) = 0 then begin
        GDVars.trainMenuDone := 1;
        if GDVars.knightTrainingMode = 0 then
          TextRend.printAndPause('Not Enough Experience', Yellow, Black);
        Exit
      end
    end;
    if GDVars.stingMode = 0 then
      trainHere := maskA and trainableHere
    else
      trainHere := maskA;
    if GDVars.knightTrainingMode = 0 then begin
      Border.ClearBox(1, 1, 38, 22);
      row := 4;
      CharHlp.DisplayCreatureName(GDVars.curChar, 4, row, False);
      TextRend.displayString(Length(name) + 4, row, LightGreen, Black, ' will become:');
      for i := 0 to 7 do
        if classLevels[i] > 0 then
          if (GDConsts.classBits[i] and trainHere) > 0 then begin
            Inc(row);
            if row = 5 then
              TextRend.displayString(6, row, 10, 0,
                                     '    a level ' + CharHlp.Uint8Str(classLevels[i] + 1) + ' ' +
                                     GDConsts.classNames[i])
            else
              TextRend.displayString(6, row, 10, 0,
                                     'and a level ' + CharHlp.Uint8Str(classLevels[i] + 1) + ' ' +
                                     GDConsts.classNames[i])
          end;
      if MenuCore.YesNoMenu('Do you wish to train? ', LightMagenta, LightGreen, White) <> 'Y' then
        Exit;
      CharHlp.PrintBottomLine('Congratulations...')
    end;
    classCount := 0;
    oldLvl5 := classLevels[C_Class.MAGE];
    oldRangerLevel := classLevels[C_Class.RANGER];
    classMask := 0;
    for i := 0 to 7 do
      if classLevels[i] > 0 then begin
        Inc(classCount);
        if (GDConsts.classBits[i] and trainHere) > 0 then begin
          Inc(classLevels[i]);
          if drainedLevels > 0 then begin
            Dec(drainedHps, drainedHps div drainedLevels);
            Dec(drainedLevels)
          end
        end
      end;
    ClassCal.RecalcClassStats(GDVars.curChar);
    if GDVars.knightTrainingMode = 0 then
      if (classLevels[C_Class.MAGE] > oldLvl5) or (classLevels[C_Class.RANGER] > 8) then begin
        sentinel := -1;
        repeat
          selResult := ViewChar.SpellMenu(4, 4, sentinel, Boolean(selIdx))
        until (selResult > 0) or (selIdx = 0);
        if selResult > 0 then
          spellsKnown[selResult] := 1
      end;
    if GDVars.knightTrainingMode <> 0 then
      case classLevels[C_Class.MAGE] of
        2: spellsKnown[15] := 1;
        3: begin spellsKnown[34] := 1; spellsKnown[10] := 1 end;
        4: spellsKnown[31] := 1;
        5: spellsKnown[47] := 1
      end;
    if levelHighest > dualClassThreshold then
      CharGen.RollFirstLevelHp(GDVars.curChar, trainHere, classCount)
  end
end;

{ Gives a new knight its starting equipment: three unidentified items, types 36, 18 and 37, at the front of its item
  list.
  @param(cr The knight.) }
procedure InitStartingMoney(cr: Types.PCharRecord);
var
  item: Types.PItemRec;
  i: Byte;
begin
  for i := 1 to 3 do begin
    GetMem(item, SizeOf(Types.TItemRec));
    FillChar(item^, SizeOf(Types.TItemRec), 0);
    with item^ do begin
      next := nil;
      inUse := 0;
      equipped := 0;
      cursed := 0;
      case i of
        1: begin
             itemType := 36;
             nameIds[3] := 36;
             nameIds[2] := 47;
             weight := 450;
             value := 0
           end;
        2: begin
             itemType := 18;
             nameIds[3] := 18;
             weight := 50;
             value := 0
           end;
        3: begin
             itemType := 37;
             nameIds[3] := 37;
             weight := 60;
             value := 0
           end
      end
    end;
    if cr^.itemsAddr = nil then
      cr^.itemsAddr := item
    else begin
      item^.next := cr^.itemsAddr^.next;
      cr^.itemsAddr^.next := item
    end
  end;
  cr^.itemCount := 3
end;

{ Moves a knight up to the next order. When its experience falls short of its level in the new order's progression, it
  loses a level with the hit points that level gave.
  @param(cr The knight.) }
procedure AdvanceKnightOrder(cr: Types.PCharRecord);
var
  oldLevel: ShortInt;
  order: ShortInt;
  hpLoss: Byte;
  conLoss: ShortInt;
begin
  oldLevel := cr^.classLevels[C_Class.KNIGHT];
  if cr^.knightOrder = 1 then
    order := 4
  else
    order := 5;
  if GDConsts.classProgression[order].nextLevelXp[oldLevel] > cr^.experience then begin
    Dec(cr^.classLevels[C_Class.KNIGHT]);
    hpLoss := cr^.hpRolled div (oldLevel + 1);
    Dec(cr^.hpRolled, hpLoss);
    conLoss := CharGen.ConHpBonus(C_Class.KNIGHT);
    Dec(cr^.hpMax, hpLoss + conLoss);
    if cr^.hpCur >= cr^.hpMax then
      cr^.hpCur := cr^.hpMax
  end;
  Inc(cr^.knightOrder);
  ClassCal.RecalcClassStats(cr)
end;

{ Lets a picked knight below the Rose petition for the next order: the Sword needs knight level 3 and that level's
  experience, the Rose level 4, and the minimum base abilities of its order; a knight that qualifies may Change
  (AdvanceKnightOrder). }
procedure KnightPromotionMenu;
var
  orderName: String[5];
  exitMenu: String[11];
  i: ShortInt;
  qualifies: Boolean;
  ch: Char;
  done: Boolean;
  ext: Boolean;
  col: Byte;
  cr: Types.PCharRecord;
begin
  if not ViewChar.PickCharacter then Exit;
  cr := Types.PCharRecord(GDVars.curChar);
  Border.DrawWindowFrame(True);
  if (cr^.classLevels[C_Class.KNIGHT] = 0)
     or ((cr^.classLevels[C_Class.KNIGHT] > 0) and (cr^.knightOrder = 3)) then Exit;
  done := False;
  exitMenu := 'Exit';
  with cr^ do begin
    col := 19 - Length(name) div 2;
    TextRend.displayString(col, 3, LightGreen, Black, name);
    TextRend.displayString(7, 5, LightGreen, Black, 'is petitioning to become a');
    case knightOrder of
      1: orderName := 'sword';
      2: orderName := 'rose'
    end;
    TextRend.displayString(10, 7, LightGreen, Black, 'Knight Of The ' + orderName);
    case knightOrder of
    1: begin
      col := 19 - (Length(name) + 21) div 2;
      if (classLevels[C_Class.KNIGHT] < 3)
         or (experience < GDConsts.classProgression[4].nextLevelXp[3]) then
        TextRend.displayString(col, 9, LightGreen, Black, name + ' is too inexperienced.')
      else begin
        col := 19 - (Length(name) + 18) div 2;
        qualifies := True;
        for i := 0 to 5 do
          if stats[i].base < GDConsts.swordReq[i] then qualifies := False;
        if not qualifies then
          TextRend.displayString(col, 9, LightGreen, Black, name + ' does not qualify.')
        else begin
          col := 19 - (Length(name) + 13) div 2;
          TextRend.displayString(col, 9, LightGreen, Black, name + ' may become a');
          TextRend.displayString(10, 11, LightGreen, Black, 'Knight Of The Sword');
          exitMenu := 'Change Exit'
        end
      end
    end;
    2: begin
      col := 20 - (Length(name) + 21) div 2;
      if (classLevels[C_Class.KNIGHT] < 4)
         or (experience < GDConsts.classProgression[5].nextLevelXp[4]) then
        TextRend.displayString(col, 9, LightGreen, Black, name + ' is too inexperienced')
      else begin
        col := 20 - (Length(name) + 18) div 2;
        qualifies := True;
        for i := 0 to 5 do
          if stats[i].base < GDConsts.roseReq[i] then qualifies := False;
        if not qualifies then
          TextRend.displayString(col, 9, LightGreen, Black, name + ' does not qualify.')
        else begin
          col := 19 - (Length(name) + 13) div 2;
          TextRend.displayString(col, 9, LightGreen, Black, name + ' may become a');
          TextRend.displayString(10, 11, LightGreen, Black, 'Knight Of The Rose');
          exitMenu := 'Change Exit'
        end
      end
    end
    end;
    repeat
      ch := MenuCore.MenuHorizontal('', exitMenu, LightMagenta, LightGreen, White, False, False, ext);
      case ch of
        'C': begin
               CharGen.AdvanceKnightOrder(cr);
               done := True
             end;
        'E', C_Keys.NONE: done := True
      end
    until done
  end
end;

{ Lets the player turn the mouse or joystick on or off, or disable both, calibrating the joystick when it is turned on.
  Each change rewrites the configuration file: line 3 holds the input mode (M, J, or N) and the joystick calibration, or
  zeros, follow the five header lines. }
procedure InitMouseJoystick;
var
  list: Types.PItemRec;
  node: Types.PItemRec;
  done: Byte;
  key: Char;
  redraw: Boolean;
  sel: Integer;
  mb: Integer;
  mx: Integer;
  my: Integer;
  cur: Types.PItemRec;
  cfgIn: Text;
  cfgOut: Text;
  i: Byte;
  line: array[1..5] of String;
  items: array[1..3] of Types.TStr40;
begin
  MenuCore.AllocStringList(3, list);
  redraw := True;
  done := 0;
  cur := list;
  sel := 0;
  repeat
    Assign(cfgIn, 'krynn.cfg');
    Reset(cfgIn);
    for i := 1 to 5 do ReadLn(cfgIn, line[i]);
    Close(cfgIn);
    if GDVars.mouseOn then items[1] := 'mouse ON'
    else items[1] := 'mouse OFF';
    if GDVars.joyOn then items[2] := 'joystick ON'
    else items[2] := 'joystick OFF';
    items[3] := 'disable both';
    node := list;
    for i := 1 to 3 do begin
      node^.name := items[i];
      node^.inUse := 0;
      node := node^.next
    end;
    redraw := True;
    key := MenuCore.MenuVertical('Init Mouse/Joystick: ', 'Select', LightMagenta, LightGreen, White, 9, 12, 38, 22,
                                 list, True, redraw, sel, cur);
    if key = 'S' then
      case sel of
        0: begin
             GDVars.mouseOn := not GDVars.mouseOn;
             Assign(cfgOut, 'krynn.cfg');
             Rewrite(cfgOut);
             if GDVars.mouseOn then begin
               GDVars.partyPickEnabled := 1;
               GDVars.mouseButtonCount := 0;
               Mouse.InitMouse;
               if GDVars.mouseOn then begin
                 if GDVars.displayMode = Types.Cga then GDVars.cursorMask := @GDConsts.cursorMaskCga
                 else GDVars.cursorMask := @GDConsts.cursorMaskEga;
                 Mouse.SetMouseCursor(0, 0, GDVars.cursorMask);
                 GDVars.mouseScaled := True;
                 Mouse.SetMouse(639, 100);
                 Mouse.GetMouse(mb, mx, my);
                 GDVars.mouseScaled := (mx >= 321) = False;
                 GDVars.joyOn := False;
                 Mouse.ShowMouse;
                 line[3] := 'M';
                 for i := 1 to 5 do WriteLn(cfgOut, line[i]);
                 for i := 0 to 13 do WriteLn(cfgOut, '0');
                 Close(cfgOut);
                 GDVars.mouseX := 160;
                 GDVars.mouseY := 100;
                 GDVars.mouseOldX := 0;
                 GDVars.mouseOldY := 0
               end
             end;
             if not GDVars.mouseOn then begin
               line[3] := 'N';
               for i := 1 to 5 do WriteLn(cfgOut, line[i]);
               for i := 0 to 13 do WriteLn(cfgOut, '0');
               Close(cfgOut);
               GDVars.mouseOn := True;
               Mouse.HideMouse;
               GDVars.mouseOn := False
             end
           end;
        1: begin
             GDVars.joyOn := not GDVars.joyOn;
             Assign(cfgOut, 'krynn.cfg');
             Rewrite(cfgOut);
             if GDVars.joyOn then begin
               CharGen.CalibrateJoystickInWindow;
               if GDVars.joyOn then begin
                 line[3] := 'J';
                 for i := 1 to 5 do WriteLn(cfgOut, line[i]);
                 for i := 0 to 6 do begin
                   WriteLn(cfgOut, GDVars.joyCalib[1].x[i]);
                   WriteLn(cfgOut, GDVars.joyCalib[1].y[i])
                 end;
                 Close(cfgOut);
                 if GDVars.joyOn then begin
                   Mouse.HideMouse;
                   GDVars.mouseOn := False
                 end
               end
             end;
             if not GDVars.joyOn then begin
               line[3] := 'N';
               for i := 1 to 5 do WriteLn(cfgOut, line[i]);
               for i := 0 to 13 do WriteLn(cfgOut, '0');
               Close(cfgOut)
             end
           end;
        2: begin
             GDVars.joyOn := False;
             Mouse.HideMouse;
             GDVars.mouseOn := False;
             Assign(cfgOut, 'krynn.cfg');
             Rewrite(cfgOut);
             line[3] := 'N';
             for i := 1 to 5 do WriteLn(cfgOut, line[i]);
             for i := 0 to 13 do WriteLn(cfgOut, '0');
             Close(cfgOut)
           end
      end else done := 1
  until done <> 0;
  MenuCore.FreeStringList(list)
end;

{ Calibrates joystick 1 in the text window, like Joystick.CalibrateJoystick: exits at once when Joystick.ProbeJoystick
  finds no stick; otherwise the center from 20 readings, then the upper-left and lower-right extremes with button 1
  down, and boundaries a third and two thirds of the way to the center. 20000 polls without a press, or a failed read,
  abort with "Unable to read joystick"; success enables the joystick. }
procedure CalibrateJoystickInWindow;
var
  sumX: Word;
  sumY: Word;
  ok: Byte;
  x: Word;
  y: Word;
  { Unused in this version; see the other implementations of this routine. }
  sampleIndex: Byte;
  j: Word;
  buttons: Byte;
begin
  Joystick.ProbeJoystick;
  if not GDVars.joyOn then Exit;
  sumX := 0;
  sumY := 0;
  for j := 1 to 20 do begin
    ok := Byte(Joystick.ReadJoystick(1, x, y, buttons));
    Inc(sumX, x);
    Inc(sumY, y)
  end;
  GDVars.joyCalib[1].x[3] := sumX div 20;
  GDVars.joyCalib[1].y[3] := sumY div 20;
  repeat
    Border.ClearBox(1, 1, 38, 22);
    TextRend.displayString(1, 3, LightMagenta, Black, 'Push JOYSTICK #1 to the extreme upper');
    TextRend.displayString(1, 5, LightMagenta, Black, 'left position and press button #1.');
    j := 0;
    repeat
      ok := Byte(Joystick.ReadJoystick(1, x, y, buttons));
      Inc(j)
    until (j > 20000) or ((ok <> 0) and ((buttons and $01) <> 0));
    if j > 20000 then begin
      Border.ClearBox(1, 1, 38, 22);
      TextRend.displayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
      Delay(2000);
      Exit
    end;
    sumX := 65535;
    sumY := 65535;
    for GDVars.scratchIndex := 1 to 20 do
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and $01) <> 0 then begin
          if x < sumX then sumX := x;
          if y < sumY then sumY := y
        end
      end else begin
        Border.ClearBox(1, 1, 38, 22);
        TextRend.displayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
        Delay(2000);
        Exit
      end
  until ok <> 0;
  GDVars.joyCalib[1].x[0] := sumX;
  GDVars.joyCalib[1].x[1] := GDVars.joyCalib[1].x[0] + (GDVars.joyCalib[1].x[3] - GDVars.joyCalib[1].x[0]) div 3;
  GDVars.joyCalib[1].x[2] := GDVars.joyCalib[1].x[0] + (GDVars.joyCalib[1].x[3] - GDVars.joyCalib[1].x[0]) * 2 div 3;
  GDVars.joyCalib[1].y[0] := sumY;
  GDVars.joyCalib[1].y[1] := GDVars.joyCalib[1].y[0] + (GDVars.joyCalib[1].y[3] - GDVars.joyCalib[1].y[0]) div 3;
  GDVars.joyCalib[1].y[2] := GDVars.joyCalib[1].y[0] + (GDVars.joyCalib[1].y[3] - GDVars.joyCalib[1].y[0]) * 2 div 3;
  repeat until not Joystick.JoyButton(1, 1);
  repeat
    Border.ClearBox(1, 1, 38, 22);
    TextRend.displayString(1, 3, LightMagenta, Black, 'Push JOYSTICK #1 to the extreme lower');
    TextRend.displayString(1, 5, LightMagenta, Black, 'right position and press button #1.');
    j := 0;
    repeat
      ok := Byte(Joystick.ReadJoystick(1, x, y, buttons));
      Inc(j)
    until (j > 20000) or ((ok <> 0) and ((buttons and $01) <> 0));
    if j > 20000 then begin
      Border.ClearBox(1, 1, 38, 22);
      TextRend.displayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
      Delay(2000);
      Exit
    end;
    sumX := 0;
    sumY := 0;
    for GDVars.scratchIndex := 1 to 20 do
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and $01) <> 0 then begin
          if x > sumX then sumX := x;
          if y > sumY then sumY := y
        end
      end else begin
        Border.ClearBox(1, 1, 38, 22);
        TextRend.displayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
        Delay(2000);
        Exit
      end
  until ok <> 0;
  GDVars.joyCalib[1].x[6] := sumX;
  GDVars.joyCalib[1].x[4] := GDVars.joyCalib[1].x[3] + (GDVars.joyCalib[1].x[6] - GDVars.joyCalib[1].x[3]) div 3;
  GDVars.joyCalib[1].x[5] := GDVars.joyCalib[1].x[3] + (GDVars.joyCalib[1].x[6] - GDVars.joyCalib[1].x[3]) * 2 div 3;
  GDVars.joyCalib[1].y[6] := sumY;
  GDVars.joyCalib[1].y[4] := GDVars.joyCalib[1].y[3] + (GDVars.joyCalib[1].y[6] - GDVars.joyCalib[1].y[3]) div 3;
  GDVars.joyCalib[1].y[5] := GDVars.joyCalib[1].y[3] + (GDVars.joyCalib[1].y[6] - GDVars.joyCalib[1].y[3]) * 2 div 3;
  GDVars.joyOn := True
end;

begin
end.
