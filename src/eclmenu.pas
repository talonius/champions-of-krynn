{ ECL virtual-machine support: operand decoding, GBVM access, scripted menus, party movement, theft, and damage. }
{$O+,F+}
unit EclMenu;

interface

uses Types, C_Class, GDConsts, GDVars, Portrait, TextRend, DaxIo, SaveLoad, ViewChar, FxEngine, CharHlp,
  ClassCal, MenuCore, MapView, View3D, MapTiles, Debug, Crt, C_Keys, C_Gbvm, C_Status, C_Dir, C_Stat, C_Ifc, C_Effect,
  C_Side;

{ Reads the value of a loaded script argument: type 0 is an immediate byte, types 1, 3 and $80 read the GBVM word at the
  argument's address, and types 2 and $81 are an immediate word. Other types leave the result undefined.
  @param(variableIndex The argument, from 1.)
  @returns(The argument's value.) }
function GetEclVar(variableIndex: ShortInt): Word;

{ Decodes the arguments of the current script command: each has a type byte and a low byte, and types 1..3 add a high
  byte. Type $80 is an inline packed string of that length and $81 the address of a string; both go to the next script
  string. Leaves the instruction pointer on the next command.
  @param(count The number of arguments.) }
procedure LoadEclVars(count: Byte);

{ Resets the script interpreter for a new script: its graphics and protection flags, two status flags, the view color
  selectors, monster flags, icon animation slot (8), instruction pointer, return stack and comparison flags, and a few
  zone words (no picture, rest timers off, anti-magic off), then reads the script's five entry addresses. For a new game
  (not a loaded one) it also clears zone-0 words $4C00..$4C1F and zone-1 words $7F79..$7F82. }
procedure EclInit;

{ Loads a script block from ECL<disk>.DAX into the cleared script zone, skipping its 2-byte header, and keeps retrying
  (with disk prompts on) until the block loads.
  @param(scriptId The script's block in the file.) }
procedure LoadEclScript(scriptId: Byte);

{ Allocates a creature record and loads a monster into it.
  @param(creatureId The monster's record number.)
  @param(character Receives the new record.)
  @param(inventory Receives its item list.)
  @param(effectNode Receives its effect list.) }
procedure InitCreature(creatureId: Byte; var character: Types.PCharRecord; var inventory: Types.PItemRec;
                       var effectNode: Types.PEffectRec);

{ Works out how far ahead a monster can appear. Outside the 3D view it is 2, also stored as the zone's monster distance;
  in it, the number of open cells (at most 2) walking from the position in the facing before a wall.
  @param(mapX The starting column.)
  @param(mapY The starting row.)
  @param(facing The direction, 0, 2, 4 or 6.)
  @returns(The distance in cells, 0..2.) }
function MaxMonsterDist(mapX, mapY, facing: Byte): Byte;

{ Records a portrait's head and body, loads them and shows them at cell (3, 3).
  @param(headId The head picture.)
  @param(bodyId The body picture.) }
procedure DisplayPortrait(headId, bodyId: Byte);

{ Shows an encounter's monster. Until its close-up is shown, it turns off the automap and loads the sprite animation in
  the 3D view the first time (redrawing the map view on later calls), and draws the sprite at distance distance + 1 in
  the 3D interface. At distance 0 in the 3D interface (unless the encounter menu is open with monster pictures off) it
  shows the close-up: picture pictureId when the zone's picture word is 255, else a portrait with that word as the head
  and pictureId as the body, skipping one already shown.
  @param(spriteId The sprite animation.)
  @param(pictureId The close-up picture, or the portrait's body.)
  @param(distance The monster's distance, 0 when it is next to the party.)
  @param(monsterFlags The encounter's monster flags: [0] marks the sprite loaded and [1] the close-up shown.) }
procedure DisplayMonster(spriteId, pictureId, distance: Byte; var monsterFlags: Types.TMonFlags);

{ Joins two bytes into a word.
  @param(lowByte The low byte.)
  @param(highByte The high byte.)
  @returns(The high byte times 256 plus the low byte.) }
function CombineBytesToWord(lowByte, highByte: Byte): Word;

{ Turns a 6-bit game character into ASCII: codes below 32 gain 64, and higher codes stay as they are.
  @param(charCode The game character.)
  @returns(The ASCII character.) }
function DecodeGameCharacter(charCode: Byte): Char;

{ Finds the GBVM zone holding an address; the ranges are tested in order, so a later one wins.
  @param(address The GBVM address.)
  @returns(The zone, 0..3 (3 is the script), or 4 for an address outside the zones.) }
function GbvmZone(address: Word): Byte;

{ Finds a creature's place in the creature list.
  @param(character The creature.)
  @returns(Its place from 0; the list's length when it is not there.) }
function FindCurCharIdx(character: Types.PCharRecord): Byte;

{ Reads the zone-1 addresses that map onto the current character: Intelligence, Constitution, Charisma, knight order,
  race, class, maximum hit points, a saving throw, highest level, thief skills, NPC byte, coins, magic-user level
  (counting an earlier class once passed), fighter, knight and ranger levels, gender, alignment, experience fields,
  status ($100: 1 okay up to 7 stoned, or 0 after a character-not-found), side and quick fight ($10C), hit points,
  movement, party position, a Charisma value (0..60), the current disk and the party size.
  @param(address The zone-1 address.)
  @param(found Set False for an ordinary zone-1 word, else True.)
  @returns(The value; undefined for $10D and for an ordinary word.) }
function SpecialReadZ1(address: Word; var found: Boolean): Word;

{ Applies the side effects of a zone-1 write to the current character: clearing its name (0 at the zone's base),
  memorized spells, NPC byte (values above $B2 lowered by 50), coins, experience fields, status (1 makes it okay and in
  play), side and quick fight, hit points, the current disk (PushState), and the three wall sets (values above $80, less
  bit 7).
  @param(address The zone-1 address.)
  @param(value The value written.) }
procedure SpecialWriteZ1(address, value: Word);

{ Writes a GBVM word. A zone-0 write to a sky color asks for a sky redraw, and one that changes the 3D flag switches
  between the overland and 3D interface states, remembering the previous one; zone-1 writes go on to SpecialWriteZ1.
  Outside the zones, the addresses that do anything are the sound effect, two script registers, and from $BF68 up the
  party's map position and facing (marking the party moved) and the floor and horizon color selectors.
  @param(address The GBVM address.)
  @param(value The value written.) }
procedure WriteGbvm(address, value: Word);

{ Reads a GBVM word: zone 1 through SpecialReadZ1 first, and the zone-0 facing word gives the party's facing. Outside
  the zones it serves three script registers, the facing, and from $C04B the party's map position, facing (0..3 in 3D),
  wall ahead and cell event.
  @param(address The GBVM address.)
  @returns(The word; undefined for any other address outside the zones.) }
function ReadGbvm(address: Word): Word;

{ Writes a string, zero-terminated, at a GBVM address in any zone; the zone-1 base address sets the current character's
  name instead. Addresses outside the zones are ignored.
  @param(address The GBVM address.)
  @param(value The string.) }
procedure WriteGbvmString(address: Word; value: String);

{ Decodes packed 6-bit game characters at the script's instruction pointer into a script string, four characters to
  three bytes; zero characters are dropped. The instruction pointer ends on the last byte read.
  @param(textLength The number of packed bytes.)
  @param(stringIndex The script string to fill.) }
procedure ConvGbString(textLength, stringIndex: Byte);

{ Copies the zero-terminated string at a GBVM address into a script string. The zone-1 base address gives the current
  character's name; addresses outside the zones give an empty string.
  @param(stringIndex The script string filled.)
  @param(address The GBVM address.) }
procedure DerefGbString(stringIndex: Byte; address: Word);

{ Runs a horizontal menu with ~ hotkeys; extended keys select the previous or next character.
  @param(query The prompt.)
  @param(menu The menu, with ~ before each hotkey.)
  @param(queryColor The prompt's color.)
  @param(menuColor The menu's color.)
  @param(highlightColor The hotkeys' color.)
  @param(enterOk True to accept Enter.)
  @param(animate True to animate the menu picture while waiting.)
  @returns(The hotkey's place from 0; 0 for Enter; 255 for a letter or digit that is not a hotkey.) }
function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; queryColor, menuColor, highlightColor: Byte;
                                       enterOk, animate: Boolean): Byte;

{ Runs MenuCore.MenuVertical over a list with the command menu Select; the key it returns is discarded. The menu string
  is prepared for hotkeys but not shown.
  @param(query The prompt.)
  @param(menu The script's menu string, with '~' before each hotkey.)
  @param(queryColor The labels' and prompt's color.)
  @param(menuColor The choices' color.)
  @param(highlightColor The highlight color.)
  @param(upperLeftColumn The window's left column.)
  @param(upperLeftRow The window's top row.)
  @param(lowerRightColumn The window's right column.)
  @param(lowerRightRow The window's bottom row.)
  @param(itemList The members listed.)
  @param(addExit True to offer Exit.)
  @param(menuRedraw True to redraw the window first; cleared on return unless the list is nil.)
  @param(selectionIndex The highlighted member, kept between calls.)
  @param(selection Receives the chosen member, or nil.) }
procedure EclVerticalMenu(query: Types.TStr40; menu: String; queryColor, menuColor, highlightColor: Byte;
                          upperLeftColumn, upperLeftRow, lowerRightColumn, lowerRightRow: ShortInt;
                          itemList: Types.PItemRec; addExit: Boolean; var menuRedraw: Boolean;
                          var selectionIndex: Integer; var selection: Types.PItemRec);

{ Sets the six comparison flags from two strings: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareStr(leftOperand, rightOperand: String);

{ Sets the six comparison flags from two numbers: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareInt(leftOperand, rightOperand: Word);

{ Pushes the instruction pointer on the script return stack and jumps to the address in a loaded argument.
  @param(variableIndex The argument holding the address.) }
procedure EclGosub(variableIndex: Byte);

{ Moves the party one cell the way it faces, wrapping on the 16x16 map, refreshes the cell event and the wall ahead, and
  marks the party moved. }
procedure EclMoveForward;

{ Keeps a share of each of a character's coins, gems and jewelry.
  @param(fraction The share kept.)
  @param(character The character robbed.) }
procedure RobMoney(fraction: Real; character: Types.PCharRecord);

{ Takes each of a character's items with a chance in percent, unreadying it first. An item heavier than 255 lowers the
  chance by 90 and one heavier than 24 by 50, to no less than 0. Note: the lowered chance carries over to the items
  after it.
  @param(chance The chance in percent.)
  @param(character The character robbed.) }
procedure RobItems(chance: Byte; character: Types.PCharRecord);

{ Skips the current script command, decoding as many arguments as its opcode takes. Note: VERTICAL MENU, HORIZONTAL
  MENU, ON GOTO and ON GOSUB are skipped as if they had no arguments, so the bytes of their arguments are read as the
  next commands. }
procedure SkipEclCmd;

{ Finds the party's highest and lowest movement, haste doubling and otherwise slow halving it. Both start from the first
  member's unadjusted movement, so that value always lies within them. Note: the first member is read before the check
  for nil, so an empty party is read through nil.
  @param(maximum Receives the highest movement.)
  @param(minimum Receives the lowest movement.) }
procedure MoveExtremes(var maximum, minimum: Byte);

{ Deals script damage to a creature with a message, then redraws the party panel; a dead creature is skipped. The
  creature dies when the damage is more than 10 above its hit points; otherwise the message gives the damage, at most
  three digits. When the message window is full it waits for a key first.
  @param(damage The damage.)
  @param(character The creature.) }
procedure EclInflictDamage(damage: Word; character: Types.PCharRecord);

{ Calls the priming entries of SaveLoad, Portrait, FxEngine, MapView, ViewChar, CharHlp, MenuCore, MapTiles and the
  trace overlay, so the overlay manager loads them; View3D and ClassCal, also used, are not primed. }
procedure PrimeEclMenu;

implementation

const
  { GBVM cells this unit names }
  { zone 1 }
  GBVM_MONSTER_DIST = $7EC1;
  GBVM_REST_SAFE_TIME = $7ED2;
  GBVM_REST_INTERRUPT = $7ED3;
  GBVM_PIC_LOADING = $7EE1;

procedure PrimeEclMenu;
begin
  SaveLoad.PrimeSaveLoad;
  Portrait.PrimePortrait;
  FxEngine.PrimeFxEngine;
  MapView.PrimeMapView;
  ViewChar.PrimeViewChar;
  CharHlp.PrimeCharHlp;
  Debug.PrimeDebug;
  MenuCore.PrimeMenuCore;
  MapTiles.PrimeMapTiles;
end;

procedure LoadEclVars(count: Byte);
var
  index: Byte;
  stringIndex: Byte;
  value: Word;
  textLength: Word;
begin
  stringIndex := 0;
  for index := 1 to count do begin
    GDVars.varTypes[index] := GDVars.zone3^[GDVars.eclIp + 1];
    GDVars.varLo[index] := GDVars.zone3^[GDVars.eclIp + 2];
    GDVars.eclIp := GDVars.eclIp + 2;
    case GDVars.varTypes[index] of
      1, 2, 3: begin
        Inc(GDVars.eclIp);
        GDVars.varHi[index] := GDVars.zone3^[GDVars.eclIp];
      end;
      $80: begin
        Inc(stringIndex);
        textLength := GDVars.varLo[index];
        if textLength > 0 then
          EclMenu.ConvGbString(textLength, stringIndex)
        else
          GDVars.gbStrings[stringIndex] := '';
      end;
      $81: begin
        Inc(stringIndex);
        Inc(GDVars.eclIp);
        GDVars.varHi[index] := GDVars.zone3^[GDVars.eclIp];
        value := EclMenu.CombineBytesToWord(GDVars.varLo[index], GDVars.varHi[index]);
        EclMenu.DerefGbString(stringIndex, value);
      end;
    end;
  end;
  Inc(GDVars.eclIp);
end;

function GetEclVar(variableIndex: ShortInt): Word;
var
  { Unused in this version; see the other implementations of this routine. }
  address: Word;
  { Unused in this version; see the other implementations of this routine. }
  value: Word;
  { Unused in this version; see the other implementations of this routine. }
  kind: Word;
  lowByte: Byte;
  highByte: Byte;
begin
  lowByte := GDVars.varLo[variableIndex];
  highByte := GDVars.varHi[variableIndex];
  case GDVars.varTypes[variableIndex] of
    0: GetEclVar := lowByte;
    1, 3, $80: GetEclVar := EclMenu.ReadGbvm(highByte * 256 + lowByte);
    2, $81: GetEclVar := EclMenu.CombineBytesToWord(lowByte, highByte);
  end;
end;

procedure EclInit;
var
  { Unused in this version; see the other implementations of this routine. }
  scriptId: Byte;
  index: Word;
begin
  GDVars.eclGraphics := False;
  GDVars.protShown := 0;
  GDVars.removeCharPending := False;
  GDVars.charNameCleared := False;
  GDVars.floorColorSel := 65;
  GDVars.horizonColorSel := 9;
  GDVars.viewColorsChanged := True;
  FillChar(GDVars.monFlags, SizeOf(GDVars.monFlags), 0);
  GDVars.iconAnimId := 8;
  GDVars.eclIp := C_Gbvm.ZONE3_BASE;
  GDVars.scratchFlag := 0;
  GDVars.eclStack := nil;
  GDVars.previousEclStack := nil;
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  GDVars.zone1^.vars[EclMenu.GBVM_PIC_LOADING] := 255;
  GDVars.zone1^.vars[EclMenu.GBVM_REST_SAFE_TIME] := 0;
  GDVars.zone1^.vars[EclMenu.GBVM_REST_INTERRUPT] := 0;
  GDVars.zone0^.vars[C_Gbvm.ANTI_MAGIC] := 0;
  EclMenu.LoadEclVars(1);
  GDVars.eclEntryPoints.entries[1] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.eclEntryPoints.entries[2] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.eclEntryPoints.entries[3] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.eclEntryPoints.entries[4] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.eclEntryPoints.entries[5] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  if GDVars.loadedSave = 0 then begin
    for index := 1 to 32 do
      { GBVM $4C00..$4C1F }
      GDVars.zone0^.vars[index + $4BFF] := 0;
    for index := 0 to 9 do
      { GBVM $7F79..$7F82 }
      GDVars.zone1^.vars[index + $7F79] := 0;
  end;
end;

procedure LoadEclScript(scriptId: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  scriptSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  scriptOffset: Word;
  diskSuffix: String[1];
  sizeRead: Word;
  data: Types.PBytes;
begin
  FillChar(GDVars.zone3^, SizeOf(Types.TZone3), 0);
  GDVars.suppressPrompt := #0;
  repeat
    MenuCore.ClearBottomLine;
    TextRend.displayString(0, 24, LightGreen, Black, 'Loading...Please Wait');
    Str(GDVars.currentDisk, diskSuffix);
    DaxIo.LoadDax('ECL' + diskSuffix, '.dax', scriptId, sizeRead, data);
  until sizeRead >= 2;
  Move(data^[2], GDVars.zone3^, sizeRead - 2);
  FreeMem(data, sizeRead);
  MenuCore.ClearBottomLine;
end;

procedure InitCreature(creatureId: Byte; var character: Types.PCharRecord; var inventory: Types.PItemRec;
                       var effectNode: Types.PEffectRec);
var
  { Unused in this version; see the other implementations of this routine. }
  item: Pointer;
begin
  character := nil;
  GetMem(character, SizeOf(Types.TCharRecord));
  SaveLoad.LoadCreatureData(creatureId, Types.PCharRecord(character));
  inventory := character^.itemsAddr;
  effectNode := character^.effects;
end;

function MaxMonsterDist(mapX, mapY, facing: Byte): Byte;
var
  blocked: Boolean;
  distance: Byte;
begin
  distance := 0;
  blocked := False;
  MaxMonsterDist := 0;
  if GDVars.zone0^.vars[C_Gbvm.VIEW_3D] = 0 then begin
    MaxMonsterDist := 2;
    GDVars.zone1^.vars[EclMenu.GBVM_MONSTER_DIST] := 2;
  end else
    while (distance < 2) and (not blocked) do begin
      if View3D.GetWallType(mapX, mapY, facing) = 0 then begin
        Inc(distance);
        MaxMonsterDist := distance;
        case facing of
          C_Dir.NORTH: Dec(mapY);
          C_Dir.EAST: Inc(mapX);
          C_Dir.SOUTH: Inc(mapY);
          C_Dir.WEST: Dec(mapX);
        end;
      end else
        blocked := True;
    end;
end;

procedure DisplayPortrait(headId, bodyId: Byte);
begin
  GDVars.pictureDrawn := 0;
  GDVars.portraitHeadId := headId;
  GDVars.portraitBodyId := bodyId;
  Portrait.LoadPortraitBufs(headId, bodyId);
  Portrait.DisplayPortraitBufs(3, 3, True);
end;

procedure DisplayMonster(spriteId, pictureId, distance: Byte; var monsterFlags: Types.TMonFlags);
var
  { Unused in this version; see the other implementations of this routine. }
  headPic: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  bodyPic: Pointer;
  distancePlusOne: Byte;
begin
  distancePlusOne := distance + 1;
  if not monsterFlags[1] then begin
    if not monsterFlags[0] then begin
      if GDVars.automapOn then begin
        GDVars.automapOn := False;
        GDVars.pictureRedrawRequested := 1;
        MapView.DisplayMapView;
      end;
      if GDVars.zone0^.vars[C_Gbvm.VIEW_3D] <> 0 then begin
        Portrait.LoadAnimation('SPRIT', spriteId, 1, GDVars.bigAnim);
        monsterFlags[0] := True;
        GDVars.spriteShown := True;
      end;
    end else begin
      GDVars.pictureRedrawRequested := 1;
      MapView.DisplayMapView;
    end;
    if GDVars.interfaceState = C_Ifc.VIEW_3D then
      Portrait.Show3DSprite(distancePlusOne, GDVars.bigAnim);
  end;
  if monsterFlags[1] then
    if GDVars.pictureIdShown = GDVars.zone1^.vars[EclMenu.GBVM_PIC_LOADING] then
      Exit;
  if distance <> 0 then Exit;
  if GDVars.interfaceState <> C_Ifc.VIEW_3D then Exit;
  if (GDVars.inEncounterMenu <> 0) and (GDVars.monsterPictureCount = 0) then Exit;
  GDVars.pictureIdShown := Byte(GDVars.zone1^.vars[EclMenu.GBVM_PIC_LOADING]);
  GDVars.eclGraphics := True;
  if GDVars.zone1^.vars[EclMenu.GBVM_PIC_LOADING] = 255 then begin
    Portrait.LoadAnimation('PIC', pictureId, 0, GDVars.bigAnim);
    monsterFlags[1] := True;
    Portrait.DisplayImageBuf(3, 3, True, GDVars.bigAnim.frames[1].image);
  end else begin
    EclMenu.DisplayPortrait(Byte(GDVars.zone1^.vars[EclMenu.GBVM_PIC_LOADING]), pictureId);
    monsterFlags[1] := True;
    GDVars.pictureDrawn := 0;
  end;
end;

function CombineBytesToWord(lowByte, highByte: Byte): Word;
begin
  CombineBytesToWord := highByte * 256 + lowByte;
end;

function DecodeGameCharacter(charCode: Byte): Char;
begin
  if charCode > 31 then
    DecodeGameCharacter := Chr(charCode)
  else
    DecodeGameCharacter := Chr(charCode + 64);
end;

function GbvmZone(address: Word): Byte;
begin
  GbvmZone := 4;
  if (address >= C_Gbvm.ZONE0_BASE) and (address <= C_Gbvm.ZONE0_TOP) then GbvmZone := 0;
  if (address >= C_Gbvm.ZONE1_BASE) and (address <= C_Gbvm.ZONE1_TOP) then GbvmZone := 1;
  if (address >= C_Gbvm.ZONE2_BASE) and (address <= C_Gbvm.ZONE2_TOP) then GbvmZone := 2;
  if (address >= C_Gbvm.ZONE3_BASE) and (address <= C_Gbvm.ZONE3_TOP) then GbvmZone := 3;
end;

function FindCurCharIdx(character: Types.PCharRecord): Byte;
var
  index: Byte;
  partyMember: Types.PCharRecord;
  found: Boolean;
begin
  partyMember := GDVars.partyHead;
  found := False;
  index := 0;
  while (partyMember <> nil) and (not found) do begin
    if partyMember = character then
      found := True
    else begin
      Inc(index);
      partyMember := partyMember^.next;
    end;
  end;
  FindCurCharIdx := index;
end;

function SpecialReadZ1(address: Word; var found: Boolean): Word;
var
  fieldIndex: Byte;
begin
  found := True;
  address := address - C_Gbvm.ZONE1_BASE;
  case address of
    $15: SpecialReadZ1 := GDVars.curChar^.stats[C_Stat.INTELLIGENCE].cur;
    $18: SpecialReadZ1 := GDVars.curChar^.stats[C_Stat.CONSTITUTION].cur;
    $19: SpecialReadZ1 := GDVars.curChar^.stats[C_Stat.CHARISMA].cur;
    $61: SpecialReadZ1 := GDVars.curChar^.knightOrder;
    $72: SpecialReadZ1 := GDVars.curChar^.race;
    $73: SpecialReadZ1 := GDVars.curChar^.charClass;
    $76: SpecialReadZ1 := GDVars.curChar^.hpMax;
    $9B: SpecialReadZ1 := GDVars.curChar^.saves[1];
    $A0: SpecialReadZ1 := GDVars.curChar^.levelHighest;
    $A5..$AC: begin
      fieldIndex := address - $A4;
      SpecialReadZ1 := GDVars.curChar^.thiefSkills[fieldIndex];
    end;
    $B8: SpecialReadZ1 := GDVars.curChar^.npc;
    $BB: SpecialReadZ1 := GDVars.curChar^.coinsA[0];
    $BD: SpecialReadZ1 := GDVars.curChar^.coinsA[1];
    $BF: SpecialReadZ1 := GDVars.curChar^.coinsA[2];
    $C1: SpecialReadZ1 := GDVars.curChar^.coinsA[3];
    $C3: SpecialReadZ1 := GDVars.curChar^.coinsA[4];
    $C9: SpecialReadZ1 := GDVars.curChar^.classLevels[C_Class.MAGE] +
        GDVars.curChar^.classLevels2[C_Class.MAGE]
                                 * ShortInt(ClassCal.EarlierClassActive(GDVars.curChar));
    $CC: SpecialReadZ1 := GDVars.curChar^.classLevels[C_Class.FIGHTER];
    $CD: SpecialReadZ1 := GDVars.curChar^.classLevels[C_Class.KNIGHT];
    $D0: SpecialReadZ1 := GDVars.curChar^.classLevels[C_Class.RANGER];
    $D6: SpecialReadZ1 := GDVars.curChar^.gender;
    $D8: SpecialReadZ1 := GDVars.curChar^.alignment;
    $F7: SpecialReadZ1 := GDVars.curChar^.xpAward;
    $F9: SpecialReadZ1 := GDVars.curChar^.xpBonusPerHp;
    $100:
      if GDVars.charNotFound <> 0 then
        SpecialReadZ1 := 0
      else
        case GDVars.curChar^.status of
          C_Status.OKAY: SpecialReadZ1 := 1;
          C_Status.RUNNING: SpecialReadZ1 := 6;
          C_Status.UNCONSCIOUS: SpecialReadZ1 := 5;
          C_Status.DYING: SpecialReadZ1 := 4;
          C_Status.DEAD_STATUS: SpecialReadZ1 := 3;
          C_Status.STONED: SpecialReadZ1 := 7;
          C_Status.GONE: SpecialReadZ1 := 2;
        else
          SpecialReadZ1 := 0;
        end;
    $10C:
      if (GDVars.curChar^.hostile = C_Side.PLAYER) and (GDVars.curChar^.quickfight <> 0) then
        SpecialReadZ1 := $80
      else if GDVars.curChar^.hostile = C_Side.ENEMY then
        SpecialReadZ1 := $81
      else
        SpecialReadZ1 := 0;
    { Note: the result is left undefined }
    $10D: ;
    $119: SpecialReadZ1 := GDVars.curChar^.hpCur;
    $11B: SpecialReadZ1 := GDVars.curChar^.movementCur;
    $2B1: SpecialReadZ1 := EclMenu.FindCurCharIdx(GDVars.curChar);
    $2B4: SpecialReadZ1 := EclMenu.FindCurCharIdx(GDVars.curChar);
    $2CF:
      { charisma -> loyalty base }
      case GDVars.curChar^.stats[C_Stat.CHARISMA].cur of
        3: SpecialReadZ1 := 0;
        4: SpecialReadZ1 := 5;
        5: SpecialReadZ1 := 10;
        6: SpecialReadZ1 := 15;
        7: SpecialReadZ1 := 20;
        8..12: SpecialReadZ1 := 25;
        13: SpecialReadZ1 := 30;
        14: SpecialReadZ1 := 35;
        15: SpecialReadZ1 := 40;
        16: SpecialReadZ1 := 50;
        17: SpecialReadZ1 := 55;
        18..25: SpecialReadZ1 := 60;
      end;
    $312: SpecialReadZ1 := GDVars.currentDisk;
    $33E: SpecialReadZ1 := GDVars.zone1^.vars[C_Gbvm.PARTY_SIZE];
  else
    found := False;
  end;
end;

procedure SpecialWriteZ1(address, value: Word);
var
  fieldIndex: Byte;
begin
  address := address - C_Gbvm.ZONE1_BASE;
  case address of
    0:
      if value = 0 then GDVars.charNameCleared := True;
    { raw window into the memorized-spell bytes }
    $20..$59: begin
      fieldIndex := address - $20;
      GDVars.curChar^.memorized[fieldIndex] := value;
    end;
    $B8: begin
      if value > $B2 then Dec(value, 50);
      GDVars.curChar^.npc := value;
    end;
    $BB: GDVars.curChar^.coinsA[0] := value;
    $BD: GDVars.curChar^.coinsA[1] := value;
    $BF: GDVars.curChar^.coinsA[2] := value;
    $C1: GDVars.curChar^.coinsA[3] := value;
    $C3: GDVars.curChar^.coinsA[4] := value;
    $F7: GDVars.curChar^.xpAward := value;
    $F9: GDVars.curChar^.xpBonusPerHp := value;
    $100:
      case value of
        1: begin
          GDVars.curChar^.status := C_Status.OKAY;
          GDVars.curChar^.inPlay := 1;
        end;
      end;
    $10C:
      case value of
        0: begin
          GDVars.curChar^.hostile := C_Side.PLAYER;
          GDVars.curChar^.quickfight := 0;
        end;
        $80: begin
          GDVars.curChar^.hostile := C_Side.PLAYER;
          GDVars.curChar^.quickfight := 1;
        end;
        $81: begin
          GDVars.curChar^.hostile := C_Side.ENEMY;
          GDVars.curChar^.quickfight := 1;
        end;
      end;
    $119: GDVars.curChar^.hpCur := value;
    $312: DaxIo.PushState(value);
    $322:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 1);
      end;
    $324:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 2);
      end;
    $326:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 3);
      end;
  end;
end;

procedure WriteGbvm(address, value: Word);
var
  gbvmRegion: Byte;
  facingValid: Boolean;
begin
  gbvmRegion := EclMenu.GbvmZone(address);
  case gbvmRegion of
    0: begin
      case address - C_Gbvm.ZONE0_BASE of
        $FD, $FE:
          GDVars.redrawSky := True;
        $E6:
          if GDVars.zone0^.vars[C_Gbvm.VIEW_3D] <> value then begin
            GDVars.previousLocationType := GDVars.interfaceState;
            if value = 0 then
              GDVars.interfaceState := C_Ifc.OVERLAND
            else
              GDVars.interfaceState := C_Ifc.VIEW_3D;
          end;
      end;
      GDVars.zone0^.vars[address] := value;
    end;
    1: begin
      GDVars.zone1^.vars[address] := value;
      EclMenu.SpecialWriteZ1(address, value);
    end;
    2:
      GDVars.zone2^[address] := value;
    3:
      GDVars.zone3^[address] := value;
    4:
      if address < $BF68 then
        case address of
          $FB: ;
          $FC: ;
          $B1: ;
          $3DE: GDVars.sndEffect := value;
          $B8: GDVars.writeRegister1 := value;
          $B9: GDVars.writeRegister2 := value;
        end else begin
        address := address - $BF68;
        case address of
          { $C04B: party X }
          $E3: begin
            GDVars.partyMoved := True;
            GDVars.mapState.x := value;
          end;
          { $C04C: party Y }
          $E4: begin
            GDVars.mapState.y := value;
            GDVars.partyMoved := True;
          end;
          { $C04D: facing, mod-4 loop }
          $E5: begin
            repeat
              facingValid := True;
              case value of
                0: GDVars.mapState.facing := C_Dir.NORTH;
                1: GDVars.mapState.facing := C_Dir.EAST;
                2: GDVars.mapState.facing := C_Dir.SOUTH;
                3: GDVars.mapState.facing := C_Dir.WEST;
              else begin
                facingValid := False;
                Dec(value, 4);
              end;
              end;
            until facingValid = True;
            GDVars.partyMoved := True;
          end;
          { $C059 }
          $F1: begin
            GDVars.floorColorSel := value;
            GDVars.viewColorsChanged := True;
          end;
          { $C05F }
          $F7: begin
            GDVars.horizonColorSel := value;
            GDVars.viewColorsChanged := True;
          end;
          { $D022: accepted, ignored }
          $10BA: ;
        end;
      end;
  end;
end;

function ReadGbvm(address: Word): Word;
var
  gbvmRegion: Byte;
  found: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  offset: Word;
begin
  gbvmRegion := EclMenu.GbvmZone(address);
  found := False;
  case gbvmRegion of
    0:
      if address = $4BEA then
        ReadGbvm := GDVars.mapState.facing
      else
        ReadGbvm := GDVars.zone0^.vars[address];
    1: begin
      ReadGbvm := EclMenu.SpecialReadZ1(address, found);
      if not found then
        ReadGbvm := GDVars.zone1^.vars[address];
    end;
    2:
      ReadGbvm := GDVars.zone2^[address];
    3:
      ReadGbvm := GDVars.zone3^[address];
    4:
      if address < $C04B then
        case address of
          $B1: ReadGbvm := GDVars.readRegister3;
          $FB: ReadGbvm := GDVars.readRegister1;
          $FC: ReadGbvm := GDVars.readRegister2;
          $33D: ReadGbvm := GDVars.mapState.facing;
          { empty }
          $35F: ;
        end else begin
        address := address - $C04B;
        case address of
          { sign-extends (ShortInt) }
          0: ReadGbvm := GDVars.mapState.x;
          1: ReadGbvm := GDVars.mapState.y;
          2:
            if GDVars.zone0^.vars[C_Gbvm.VIEW_3D] = 0 then
              ReadGbvm := GDVars.mapState.facing
            else
              ReadGbvm := Word(GDVars.mapState.facing) div 2;
          3: ReadGbvm := GDVars.mapState.wallAhead;
          4: ReadGbvm := GDVars.mapState.event;
          { $C059: empty (write-only) }
          $E: ;
        end;
      end;
  end;
end;

procedure WriteGbvmString(address: Word; value: String);
var
  gbvmRegion: Byte;
  textLength: Byte;
  index: Byte;
begin
  gbvmRegion := EclMenu.GbvmZone(address);
  textLength := Length(value);
  { Each explicit nonempty guard skips only its copy loop; the terminating zero store always runs. }
  case gbvmRegion of
    0: begin
      if textLength > 0 then
        for index := 0 to textLength - 1 do
          GDVars.zone0^.vars[address + index] := Ord(value[index + 1]);
      GDVars.zone0^.vars[address + textLength] := 0;
    end;
    1:
      if address = C_Gbvm.ZONE1_BASE then
        GDVars.curChar^.name := value
      else begin
        if textLength > 0 then
          for index := 0 to textLength - 1 do
            GDVars.zone1^.vars[address + index] := Ord(value[index + 1]);
        GDVars.zone1^.vars[address + textLength] := 0;
      end;
    2: begin
      if textLength > 0 then
        for index := 0 to textLength - 1 do
          GDVars.zone2^[address + index] := Ord(value[index + 1]);
      GDVars.zone2^[address + textLength] := 0;
    end;
    3: begin
      if textLength > 0 then
        for index := 0 to textLength - 1 do
          GDVars.zone3^[address + index] := Ord(value[index + 1]);
      GDVars.zone3^[address + textLength] := 0;
    end;
  end;
end;

procedure ConvGbString(textLength, stringIndex: Byte);
var
  index: Byte;
  { Unused in this version; see the other implementations of this routine. }
  outPos: Byte;
  currentByte: Byte;
  previousByte: Byte;
  sixBitCharacter: Byte;
  decodePhase: Byte;
  characterValue: Char;
begin
  GDVars.gbStrings[stringIndex] := '';
  index := 0;
  decodePhase := 1;
  while index < textLength do begin
    if decodePhase < 4 then begin
      Inc(GDVars.eclIp);
      previousByte := currentByte;
      currentByte := GDVars.zone3^[GDVars.eclIp];
      Inc(index);
    end;
    case decodePhase of
      1:
        sixBitCharacter := currentByte shr 2;
      2: begin
        sixBitCharacter := previousByte shl 6 + currentByte shr 2;
        sixBitCharacter := sixBitCharacter shr 2;
      end;
      3: begin
        sixBitCharacter := previousByte shl 4 + currentByte shr 4;
        sixBitCharacter := sixBitCharacter shr 2;
      end;
      4:
        sixBitCharacter := currentByte and $3F;
    end;
    if decodePhase < 4 then Inc(decodePhase) else decodePhase := 1;
    if sixBitCharacter <> 0 then begin
      characterValue := EclMenu.DecodeGameCharacter(sixBitCharacter);
      GDVars.gbStrings[stringIndex] := Concat(GDVars.gbStrings[stringIndex], characterValue);
    end;
  end;
  if decodePhase = 4 then begin
    sixBitCharacter := currentByte and $3F;
    if sixBitCharacter <> 0 then begin
      characterValue := EclMenu.DecodeGameCharacter(sixBitCharacter);
      GDVars.gbStrings[stringIndex] := Concat(GDVars.gbStrings[stringIndex], characterValue);
    end;
  end;
end;

procedure DerefGbString(stringIndex: Byte; address: Word);
var
  gbvmRegion: Byte;
  index: Byte;
begin
  gbvmRegion := EclMenu.GbvmZone(address);
  GDVars.gbStrings[stringIndex] := '';
  index := 0;
  case gbvmRegion of
    0:
      while GDVars.zone0^.vars[address + index] <> 0 do begin
        GDVars.gbStrings[stringIndex] := Concat(GDVars.gbStrings[stringIndex],
                                                Char(GDVars.zone0^.vars[address + index]));
        Inc(index);
      end;
    1:
      if address = C_Gbvm.ZONE1_BASE then
        GDVars.gbStrings[stringIndex] := GDVars.curChar^.name
      else
        while GDVars.zone1^.vars[address + index] <> 0 do begin
          GDVars.gbStrings[stringIndex] := Concat(GDVars.gbStrings[stringIndex],
                                                  Char(GDVars.zone1^.vars[address + index]));
          Inc(index);
        end;
    2:
      while GDVars.zone2^[address + index] <> 0 do begin
        GDVars.gbStrings[stringIndex] := Concat(GDVars.gbStrings[stringIndex], Char(GDVars.zone2^[address + index]));
        Inc(index);
      end;
    3:
      while GDVars.zone3^[address + index] <> 0 do begin
        GDVars.gbStrings[stringIndex] := Concat(GDVars.gbStrings[stringIndex], Char(GDVars.zone3^[address + index]));
        Inc(index);
      end;
  end;
end;

{ Prepares a script menu string: lowercases it, removes each '~' and uppercases the letter after it as a hotkey. Note:
  the lowercasing adds $20 to digits too, turning them into letters P..Y.
  @param(menu The menu string, prepared in place.)
  @param(options Receives the hotkeys in order.) }
procedure MenuToOptions(var menu: String; var options: Types.TStr40);
var
  index: Byte;
begin
  options := '';
  for index := 1 to Length(menu) do begin
    if menu[index] in ['0'..'9', 'A'..'Z'] then
      menu[index] := Chr(Ord(menu[index]) + 32);
    if menu[index] = '~' then begin
      Delete(menu, index, 1);
      menu[index] := UpCase(menu[index]);
      options := options + menu[index];
    end;
  end;
end;

function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; queryColor, menuColor, highlightColor: Byte;
                                       enterOk, animate: Boolean): Byte;
var
  options: Types.TStr40;
  index: Byte;
  characterValue: Char;
  extendedKey: Boolean;
begin
  EclMenu.MenuToOptions(menu, options);
  repeat
    characterValue := MenuCore.MenuHorizontal(query, menu, queryColor, menuColor, highlightColor, True, animate,
                                              extendedKey);
    if extendedKey then begin
      ViewChar.SelectPrevNextChar(characterValue);
      CharHlp.DisplayParty(GDVars.curChar);
      characterValue := #0;
    end;
  until (characterValue in ['0'..'9', 'A'..'Z']) or ((characterValue = C_Keys.ENTER) and enterOk);
  case characterValue of
    C_Keys.ENTER: MenuHorizontalCharacterSelect := 0;
  else begin
    index := 1;
    while (index <= Length(options)) and (options[index] <> characterValue) do
      Inc(index);
    if index <= Length(options) then
      MenuHorizontalCharacterSelect := index - 1
    else
      MenuHorizontalCharacterSelect := 255;
  end;
  end;
end;

procedure EclVerticalMenu(query: Types.TStr40; menu: String; queryColor, menuColor, highlightColor: Byte;
                          upperLeftColumn, upperLeftRow, lowerRightColumn, lowerRightRow: ShortInt;
                          itemList: Types.PItemRec; addExit: Boolean; var menuRedraw: Boolean;
                          var selectionIndex: Integer; var selection: Types.PItemRec);
var
  { Unused in this version; see the other implementations of this routine. }
  characterValue: Char;
  options: Types.TStr40;
begin
  EclMenu.MenuToOptions(menu, options);
  characterValue := MenuCore.MenuVertical(query, 'Select', queryColor, menuColor, highlightColor, upperLeftColumn,
                                          upperLeftRow, lowerRightColumn, lowerRightRow, Types.PItemRec(itemList),
                                          addExit, menuRedraw, selectionIndex, Types.PItemRec(selection));
end;

procedure EclCompareStr(leftOperand, rightOperand: String);
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  if leftOperand = rightOperand then GDVars.cmpFlags[0] := True;
  if leftOperand <> rightOperand then GDVars.cmpFlags[1] := True;
  if leftOperand < rightOperand then GDVars.cmpFlags[2] := True;
  if leftOperand > rightOperand then GDVars.cmpFlags[3] := True;
  if leftOperand <= rightOperand then GDVars.cmpFlags[4] := True;
  if leftOperand >= rightOperand then GDVars.cmpFlags[5] := True;
end;

procedure EclCompareInt(leftOperand, rightOperand: Word);
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  if leftOperand = rightOperand then GDVars.cmpFlags[0] := True;
  if leftOperand <> rightOperand then GDVars.cmpFlags[1] := True;
  if leftOperand < rightOperand then GDVars.cmpFlags[2] := True;
  if leftOperand > rightOperand then GDVars.cmpFlags[3] := True;
  if leftOperand <= rightOperand then GDVars.cmpFlags[4] := True;
  if leftOperand >= rightOperand then GDVars.cmpFlags[5] := True;
end;

procedure EclGosub(variableIndex: Byte);
begin
  if GDVars.eclStack = nil then begin
    GetMem(GDVars.eclStack, SizeOf(Types.TEclRet));
    GDVars.eclStack^.next := nil;
  end else begin
    GDVars.previousEclStack := GDVars.eclStack;
    GetMem(GDVars.eclStack, SizeOf(Types.TEclRet));
    GDVars.eclStack^.next := GDVars.previousEclStack;
  end;
  GDVars.eclStack^.address := GDVars.eclIp;
  GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.varLo[variableIndex], GDVars.varHi[variableIndex]);
end;

procedure EclMoveForward;
begin
  case GDVars.mapState.facing of
    C_Dir.NORTH: if GDVars.mapState.y > 0 then Dec(GDVars.mapState.y) else GDVars.mapState.y := 15;
    C_Dir.EAST: if GDVars.mapState.x < 15 then Inc(GDVars.mapState.x) else GDVars.mapState.x := 0;
    C_Dir.SOUTH: if GDVars.mapState.y < 15 then Inc(GDVars.mapState.y) else GDVars.mapState.y := 0;
    C_Dir.WEST: if GDVars.mapState.x > 0 then Dec(GDVars.mapState.x) else GDVars.mapState.x := 15;
  end;
  GDVars.mapState.event := View3D.GetMapEvent(GDVars.mapState.x, GDVars.mapState.y);
  GDVars.mapState.wallAhead := View3D.GetWallType(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
  GDVars.partyMoved := True;
end;

procedure RobMoney(fraction: Real; character: Types.PCharRecord);
begin
  character^.coinsA[0] := Trunc(character^.coinsA[0] * fraction);
  character^.coinsA[1] := Trunc(character^.coinsA[1] * fraction);
  character^.coinsA[2] := Trunc(character^.coinsA[2] * fraction);
  character^.coinsA[3] := Trunc(character^.coinsA[3] * fraction);
  character^.coinsA[4] := Trunc(character^.coinsA[4] * fraction);
  character^.coinsA[5] := Trunc(character^.coinsA[5] * fraction);
  character^.coinsA[6] := Trunc(character^.coinsA[6] * fraction);
end;

procedure RobItems(chance: Byte; character: Types.PCharRecord);
var
  theftRoll: Byte;
  item: Types.PItemRec;
  nextItem: Types.PItemRec;
begin
  item := character^.itemsAddr;
  while item <> nil do begin
    if item^.weight > 255 then begin
      if chance > 90 then
        chance := chance - 90
      else
        chance := 0;
    end else if item^.weight > 24 then begin
      if chance > 50 then
        chance := chance - 50
      else
        chance := 0;
    end;
    theftRoll := FxEngine.RollDice(1, 100);
    nextItem := item^.next;
    if theftRoll <= chance then begin
      if item^.equipped <> 0 then
        ViewChar.ToggleReadyItem(item);
      CharHlp.RemoveItem(character, item);
    end;
    item := nextItem;
  end;
end;

procedure SkipEclCmd;
begin
  GDVars.eclOpcode := GDVars.zone3^[GDVars.eclIp];
  case GDVars.eclOpcode of
    1, 2, $A, $E, $11, $12, $1D, $20, $2D, $32, $34, $36, $38, $39,
    $3C, $3F, $40:
      EclMenu.LoadEclVars(1);
    3, 8, 9, $F, $10, $1F, $22, $41:
      EclMenu.LoadEclVars(2);
    4..7, $B, $C, $21, $28, $2A, $2F, $30, $35, $37, $3B:
      EclMenu.LoadEclVars(3);
    $14, $23:
      EclMenu.LoadEclVars(4);
    $2E:
      EclMenu.LoadEclVars(5);
    $1E, $2C:
      EclMenu.LoadEclVars(6);
    $27:
      EclMenu.LoadEclVars(8);
    $29:
      EclMenu.LoadEclVars(14);
  else
    Inc(GDVars.eclIp);
  end;
end;

procedure MoveExtremes(var maximum, minimum: Byte);
var
  partyMember: Types.PCharRecord;
  effectNode: Types.PEffectRec;
  movement: Byte;
begin
  partyMember := GDVars.partyHead;
  maximum := partyMember^.movementCur;
  minimum := partyMember^.movementCur;
  while partyMember <> nil do begin
    movement := partyMember^.movementCur;
    if CharHlp.HasEffect(partyMember, C_Effect.HASTED, effectNode) then
      movement := movement * 2
    else if CharHlp.HasEffect(partyMember, C_Effect.SLOWED, effectNode) then
      movement := movement div 2;
    if movement > maximum then maximum := movement;
    if movement < minimum then minimum := movement;
    partyMember := partyMember^.next;
  end;
end;

procedure EclInflictDamage(damage: Word; character: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  damageType: Byte;
  messageText: String;
  damageText: String[3];
  pauseAfterMessage: Boolean;
begin
  if character^.status = C_Status.DEAD_STATUS then Exit;
  pauseAfterMessage := False;
  Str(damage, damageText);
  if character^.hpCur + 10 < damage then
    messageText := '  ' + character^.name + ' dies. '
  else
    messageText := '  ' + character^.name + ' is hit FOR ' + damageText + ' points of Damage.';
  if GDVars.curRow > 22 then begin
    GDVars.curRow := 17;
    pauseAfterMessage := True;
    TextRend.displayAndPause(White, Black, 'press <enter>/<return> to continue');
  end else
    pauseAfterMessage := False;
  GDVars.curCol := 38;
  TextRend.displayMessageWindow(1, 17, 38, 22, White, Black, pauseAfterMessage, messageText);
  CharHlp.InflictDamage(character, damage);
  TextRend.ClearRect(17, 1, 38, 15);
  CharHlp.DisplayParty(GDVars.curChar);
end;

begin
end.
