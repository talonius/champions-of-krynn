{ The ECL virtual machine: the encounter/parlay driver and the ECL script interpreter. }
{$O+,F+}
unit EclVm;
interface

{ Runs the game from the current ECL block until the party is destroyed: loads the block (the start block, the demo's,
  or the one last entered), runs its entry script, and in the demo removes the party at once. Otherwise it repeats the
  map menu: Encamp enters camp and Look searches through the block's search script, then the block's run script, the
  party's step (ResolveMovement) with the step sound when the party moved, and the search script again; a NEWECL from
  any script loads the next block through NewEclDone. The party is removed at the end. }
procedure GameLoop;

{ Calls the priming entries of ViewChar, Portrait, MapTiles, GameTime, MenuCore, SaveLoad, FxEngine, Explore, CharHlp,
  MapView, EclMenu, Money, ClassCal, CopyProt and the trace overlay, so the overlay manager loads them; the other
  overlays this unit uses are not primed here. }
procedure PrimeEclVm;

implementation

uses Types, CopyProt, Temple, PostCbt, Shop, EclMenu, Combat, CombatAi, CombatSt, CbtActs, Explore, MapCurs, Camp,
  SaveLoad, CharGen, ViewChar, GameTime, Money, FxEngine, CharHlp, Border, ClassCal, MenuCore, MapView, Portrait,
  View3D, Pathing, CbtMap, MapTiles, Debug, DaxIo, GameIo, Mouse, SoundDrv, TextRend, GDConsts, GDVars, Crt, C_Class,
  C_Ifc, C_Side;

procedure EnterCamp; forward;

procedure CallEclScript(address: Word); forward;

procedure NewEclDone; forward;

procedure DispatchEclCommand; forward;

procedure PrimeEclVm;
begin
  ViewChar.PrimeViewChar;
  Portrait.PrimePortrait;
  MapTiles.PrimeMapTiles;
  GameTime.PrimeGameTime;
  MenuCore.PrimeMenuCore;
  SaveLoad.PrimeSaveLoad;
  FxEngine.PrimeFxEngine;
  Explore.PrimeExplore;
  CharHlp.PrimeCharHlp;
  MapView.PrimeMapView;
  EclMenu.PrimeEclMenu;
  Money.PrimeMoney;
  Debug.PrimeDebug;
  ClassCal.PrimeClassCal;
  CopyProt.PrimeCopyProt;
end;

{ EXIT, opcode $00: ends the script. Redraws the view frame if the copy protection showed, restores the saved current
  character, clears the monster flags and the graphics flag, stops the interpreter, empties the gosub stack and puts the
  text cursor back at row 17, column 1. }
procedure EclExit;
begin
  if GDVars.protShown <> 0 then
    Border.DrawViewFrame;
  if GDVars.restoreChar <> 0 then begin
    GDVars.curChar := GDVars.savedChar;
    GDVars.restoreChar := 0
  end;
  FillChar(GDVars.monFlags, SizeOf(GDVars.monFlags), 0);
  GDVars.eclGraphics := False;
  GDVars.protShown := 0;
  GDVars.eclStop := 1;
  Inc(GDVars.eclIp);
  while GDVars.eclStack <> nil do begin
    GDVars.previousEclStack := GDVars.eclStack^.next;
    FreeMem(GDVars.eclStack, SizeOf(Types.TEclRet));
    GDVars.eclStack := GDVars.previousEclStack
  end;
  GDVars.curRow := 17;
  GDVars.curCol := 1;
  GDVars.boxCleared := 0
end;

{ GOTO, opcode $01: jumps to the address in its argument. }
procedure EclGoto;
begin
  EclMenu.LoadEclVars(1);
  GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1])
end;

{ GOSUB, opcode $02: pushes the return address and jumps to the address in its argument. }
procedure EclGosubCmd;
begin
  EclMenu.LoadEclVars(1);
  EclMenu.EclGosub(1)
end;

{ COMPARE, opcode $03: compares its two arguments, as strings when either is a string type ($80 and up), else as
  integers, and sets the comparison flags. }
procedure EclCompare;
var
  lhs: Word;
  rhs: Word;
  lhsStr: String;
  rhsStr: String;
begin
  EclMenu.LoadEclVars(2);
  if (GDVars.varTypes[1] >= $80) or (GDVars.varTypes[2] >= $80) then begin
    lhsStr := GDVars.gbStrings[1];
    rhsStr := GDVars.gbStrings[2];
    EclMenu.EclCompareStr(lhsStr, rhsStr)
  end else begin
    lhs := EclMenu.GetEclVar(1);
    rhs := EclMenu.GetEclVar(2);
    EclMenu.EclCompareInt(lhs, rhs)
  end
end;

{ ADD, SUBTRACT, DIVIDE and MULTIPLY, opcodes $04..$07: combines its first two arguments and stores the result at the
  GBVM address in its third. SUBTRACT takes the first from the second; DIVIDE leaves the remainder in the zone's
  division remainder. }
procedure EclArithmetic;
var
  address: Word;
  v: array[1..2] of Word;
  i: ShortInt;
  r: Word;
begin
  EclMenu.LoadEclVars(3);
  for i := 1 to 2 do
    v[i] := EclMenu.GetEclVar(i);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  case GDVars.eclOpcode of
    4: r := v[1] + v[2];
    5: r := v[2] - v[1];
    6: begin
         r := v[1] div v[2];
         GDVars.zone1^.divRem := v[1] mod v[2]
       end;
    7: r := v[1] * v[2]
  end;
  EclMenu.WriteGbvm(address, r)
end;

{ RANDOM, opcode $08: stores a random number from 0 to its first argument (0 to 254 when that is 255) at the address in
  its second. }
procedure EclRandom;
var
  n: Byte;
  roll: Byte;
  address: Word;
begin
  EclMenu.LoadEclVars(2);
  n := EclMenu.GetEclVar(1);
  if n < 255 then Inc(n);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  roll := Trunc(Random(n));
  EclMenu.WriteGbvm(address, roll)
end;

{ SAVE, opcode $09: stores its first argument, a number or a string (type bit 7 set), at the address in its second. }
procedure EclSave;
var
  v: Word;
  address: Word;
begin
  EclMenu.LoadEclVars(2);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  if GDVars.varTypes[1] < $80 then begin
    v := EclMenu.GetEclVar(1);
    EclMenu.WriteGbvm(address, v)
  end else
    EclMenu.WriteGbvmString(address, GDVars.gbStrings[1])
end;

{ LOAD CHARACTER, opcode $0A: makes the party member at the position in the low 7 bits of its argument current, or sets
  the character-not-found flag when there is none. With bit 7 set and both removal flags raised, that member is removed
  from the party and the party redrawn. }
procedure EclLoadCharacter;
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  savedIdx: Byte;
  idx: Byte;
  i: Byte;
  highBit: Byte;
begin
  GDVars.restoreChar := 1;
  EclMenu.LoadEclVars(1);
  i := 0;
  idx := EclMenu.GetEclVar(1);
  p := GDVars.partyHead;
  highBit := idx and $80;
  idx := idx and $7F;
  if idx > 0 then
    while (i < idx) and (p <> nil) do begin
      p := p^.next;
      Inc(i)
    end;
  if p <> nil then begin
    GDVars.curChar := p;
    GDVars.charNotFound := 0
  end else
    GDVars.charNotFound := 1;
  if (highBit <> 0) and (GDVars.removeCharPending) and (GDVars.charNameCleared) then begin
    if GDVars.savedChar = GDVars.curChar then
      GDVars.restoreChar := 0;
    CharGen.RemoveCreature(False, True);
    CharHlp.DisplayParty(GDVars.curChar);
    GDVars.removeCharPending := False;
    GDVars.charNameCleared := False
  end
end;

{ SETUP MONSTER, opcode $0C: sets the monster and its picture, stores the requested monster distance and the actual one
  (capped by the open distance ahead), and draws the monster. }
procedure EclSetupMonster;
var
  { Unused in this version; see the other implementations of this routine. }
  distance: Word;
begin
  EclMenu.LoadEclVars(3);
  GDVars.approachA := EclMenu.GetEclVar(1);
  GDVars.zone1^.distReq := EclMenu.GetEclVar(2);
  GDVars.approachB := EclMenu.GetEclVar(3);
  GDVars.zone1^.monsterDist := EclMenu.MaxMonsterDist(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
  if GDVars.zone1^.distReq < GDVars.zone1^.monsterDist then
    GDVars.zone1^.monsterDist := GDVars.zone1^.distReq;
  EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.monsterDist), GDVars.monFlags)
end;

{ LOAD MONSTER, opcode $0B: adds the monster its first argument names to the creature list, its hit points scaled by
  (dungeon level + 1) / 4 (at least 1) when it is an enemy on dungeon levels 1..5, with as many copies as its second
  argument asks (at least one, stopping at 63 creatures), each with its own copies of the items and effects (in reverse
  order). Its third argument picks the combat icon (CPIC), loaded into the next icon slot. Nothing is added once 63
  creatures are loaded. }
procedure EclLoadMonster;
var
  id: Byte;
  count: Byte;
  picId: Byte;
  i: Byte;
  p: Types.PCharRecord;
  q: Types.PCharRecord;
  cr: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  tmpl: Types.TCharRecord;
  nm: String[12];
  it: Types.PItemRec;
  tmpIt: Types.PItemRec;
  invHead: Types.PItemRec;
  ef: Types.PEffectRec;
  tmpEf: Types.PEffectRec;
  effHead: Types.PEffectRec;
begin
  savedCur := Types.PCharRecord(GDVars.curChar);
  i := 1;
  EclMenu.LoadEclVars(3);
  if GDVars.creatureCnt >= 63 then Exit;
  p := nil;
  q := nil;
  id := EclMenu.GetEclVar(1);
  EclMenu.InitCreature(id, cr, it, ef);
  if (cr^.hostile = C_Side.ENEMY) and (GDVars.zone0^.dungeonLevel > 0) and (GDVars.zone0^.dungeonLevel < 6) then begin
    cr^.hpCur := cr^.hpCur * (GDVars.zone0^.dungeonLevel + 1) div 4;
    cr^.hpMax := cr^.hpMax * (GDVars.zone0^.dungeonLevel + 1) div 4;
    if (cr^.hpCur = 0) or (cr^.hpMax = 0) then begin
      cr^.hpCur := 1;
      cr^.hpMax := 1
    end
  end;
  if cr^.levelUndead <> 0 then Inc(GDVars.undeadCount);
  tmpl := cr^;
  invHead := it;
  effHead := ef;
  count := EclMenu.GetEclVar(2);
  if count <= 0 then count := 1;
  picId := EclMenu.GetEclVar(3);
  p := Types.PCharRecord(GDVars.partyHead);
  nm := 'CPIC';
  MapTiles.LoadIconAnim(nm, picId, GDVars.iconAnimId);
  while p^.next <> nil do p := p^.next;
  p^.next := cr;
  p := p^.next;
  p^.orderNumber := GDVars.iconAnimId;
  p^.next := nil;
  Inc(GDVars.creatureCnt);
  Inc(i);
  while (i <= count) and (GDVars.creatureCnt < 63) do begin
    GetMem(q, SizeOf(Types.TCharRecord));
    p^.next := q;
    p := p^.next;
    p^ := tmpl;
    p^.orderNumber := GDVars.iconAnimId;
    p^.next := nil;
    p^.effects := nil;
    p^.itemsAddr := nil;
    Inc(i);
    Inc(GDVars.creatureCnt);
    while it <> nil do begin
      if p^.itemsAddr = nil then begin
        GetMem(p^.itemsAddr, SizeOf(Types.TItemRec));
        p^.itemsAddr^ := it^;
        p^.itemsAddr^.next := nil
      end else begin
        tmpIt := p^.itemsAddr;
        GetMem(p^.itemsAddr, SizeOf(Types.TItemRec));
        p^.itemsAddr^ := it^;
        p^.itemsAddr^.next := tmpIt
      end;
      it := it^.next
    end;
    it := invHead;
    while ef <> nil do begin
      if p^.effects = nil then begin
        GetMem(p^.effects, SizeOf(Types.TEffectRec));
        p^.effects^ := ef^;
        p^.effects^.next := nil
      end else begin
        tmpEf := p^.effects;
        GetMem(p^.effects, SizeOf(Types.TEffectRec));
        p^.effects^ := ef^;
        p^.effects^.next := tmpEf
      end;
      ef := ef^.next
    end;
    ef := effHead
  end;
  Inc(GDVars.iconAnimId);
  GDVars.monstersOn := 1;
  GDVars.curChar := Types.PCharRecord(savedCur)
end;

{ APPROACH, opcode $0D: brings the monster one step nearer and redraws it, unless it is already adjacent. }
procedure EclApproach;
begin
  if GDVars.zone1^.monsterDist > 0 then begin
    Dec(GDVars.zone1^.monsterDist);
    EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.monsterDist), GDVars.monFlags)
  end;
  Inc(GDVars.eclIp)
end;

{ PICTURE, opcode $0E: picture 255 redraws the area view when an ECL picture or a sprite is up (unless the saved
  interface was the 3D view and the current one is not) and clears the monster flags. Any other picture sets the monster
  and ECL-graphics flags; when no portrait is staged in zone 1 (255) it shows pictures 112 and above as a big picture
  (121 also drawing the map cursor, the others setting the special-view flag) and lower ones as the first frame of a PIC
  animation in the picture box, and with a staged portrait it draws that portrait with this picture instead. }
procedure EclPicture;
var
  picId: Byte;
begin
  EclMenu.LoadEclVars(1);
  picId := EclMenu.GetEclVar(1);
  if picId <> 255 then begin
    GDVars.monFlags[1] := True;
    GDVars.eclGraphics := True;
    if GDVars.zone1^.picLoading = 255 then begin
      GDVars.pictureDrawn := 1;
      if picId >= 112 then begin
        Portrait.LoadBigPic(picId);
        Portrait.DisplayBigPic;
        if picId = 121 then MapCurs.DrawCursor
        else GDVars.specialView := 1;
        GDVars.pictureRedrawRequested := 0
      end else begin
        Portrait.LoadAnimation('PIC', picId, 0, GDVars.bigAnim);
        Portrait.DisplayImageBuf(3, 3, True, GDVars.bigAnim.frames[1].image)
      end
    end else
      EclMenu.DisplayPortrait(Byte(GDVars.zone1^.picLoading), picId)
  end else begin
    if ((GDVars.previousLocationType <> C_Ifc.VIEW_3D) or (GDVars.interfaceState = C_Ifc.VIEW_3D)) and
        ((GDVars.eclGraphics) or (GDVars.spriteShown)) then begin
      GDVars.pictureRedrawRequested := 1;
      MapView.DisplayMapView;
      GDVars.eclGraphics := False;
      GDVars.spriteShown := False;
      GDVars.pictureDrawn := 1
    end;
    GDVars.monFlags[0] := False;
    GDVars.monFlags[1] := False
  end
end;

{ INPUT NUMBER, opcode $0F: reads a number and stores it at the GBVM address in its second argument. }
procedure EclInputNumber;
var
  q: String[1];
  v: Word;
  address: Word;
begin
  EclMenu.LoadEclVars(2);
  q := '';
  address := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  v := TextRend.ReadNumber(q, 10, 0);
  EclMenu.WriteGbvm(address, v)
end;

{ INPUT STRING, opcode $10: reads up to 40 characters, a space when nothing is typed, and stores them at the GBVM
  address in its second argument. }
procedure EclInputString;
var
  q: String[1];
  address: Word;
  s: String;
begin
  EclMenu.LoadEclVars(2);
  q := '';
  address := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  s := TextRend.readString(q, LightGreen, Black, 40);
  if s = '' then s := ' ';
  EclMenu.WriteGbvmString(address, s)
end;

{ PRINT and PRINTCLEAR, opcodes $11 and $12: shows its argument, a number or a string, in the message window; PRINTCLEAR
  first clears the window and starts at its top. }
procedure EclPrint;
begin
  EclMenu.LoadEclVars(1);
  GDVars.bottomClear := 0;
  GDVars.slowText := 1;
  if GDVars.varTypes[1] < $80 then
    GDVars.gbStrings[1] := CharHlp.Uint16Str(EclMenu.GetEclVar(1));
  if GDVars.eclOpcode = $11 then
    TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, False, GDVars.gbStrings[1])
  else begin
    GDVars.curRow := 17;
    GDVars.curCol := 1;
    TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, True, GDVars.gbStrings[1])
  end;
  GDVars.slowText := 0
end;

{ RETURN, opcode $13: pops the gosub stack and returns to its address, or ends the script like EXIT when the stack is
  empty. }
procedure EclReturn;
begin
  Inc(GDVars.eclIp);
  if GDVars.eclStack <> nil then begin
    GDVars.eclIp := GDVars.eclStack^.address;
    GDVars.previousEclStack := GDVars.eclStack^.next;
    FreeMem(GDVars.eclStack, SizeOf(Types.TEclRet));
    GDVars.eclStack := GDVars.previousEclStack
  end else
    EclVm.EclExit
end;

{ COMPARE AND, opcode $14: clears the comparison flags, then sets the equal flag when its first two arguments are equal
  and so are its last two, else the not-equal flag. }
procedure EclCompareAnd;
var
  v: array[1..4] of Word;
  i: Byte;
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  EclMenu.LoadEclVars(4);
  for i := 1 to 4 do v[i] := EclMenu.GetEclVar(i);
  if (v[1] = v[2]) and (v[3] = v[4]) then
    GDVars.cmpFlags[0] := True
  else
    GDVars.cmpFlags[1] := True
end;

{ IF, opcodes $16..$1B (=, <>, <, >, <=, >=): skips the next command unless its comparison flag is set. }
procedure EclIf;
begin
  Inc(GDVars.eclIp);
  case GDVars.eclOpcode of
    $16: if not GDVars.cmpFlags[0] then EclMenu.SkipEclCmd;
    $17: if not GDVars.cmpFlags[1] then EclMenu.SkipEclCmd;
    $18: if not GDVars.cmpFlags[2] then EclMenu.SkipEclCmd;
    $19: if not GDVars.cmpFlags[3] then EclMenu.SkipEclCmd;
    $1A: if not GDVars.cmpFlags[4] then EclMenu.SkipEclCmd;
    $1B: if not GDVars.cmpFlags[5] then EclMenu.SkipEclCmd
  end
end;

{ NEWECL, opcode $20: loads the script its argument names, remembering the current one in the zone, and stops the
  interpreter so the game loop starts the new script. }
procedure EclNewEcl;
var
  newId: Byte;
begin
  EclMenu.LoadEclVars(1);
  GDVars.zone0^.prevEcl := GDVars.curEclId;
  newId := EclMenu.GetEclVar(1);
  GDVars.curEclId := newId;
  EclMenu.LoadEclScript(newId);
  EclMenu.EclInit;
  GDVars.eclStop := 1;
  GDVars.newEclFlag := 1;
  FillChar(GDVars.monFlags, SizeOf(GDVars.monFlags), 0)
end;

{ LOAD FILES and LOAD PIECES, opcodes $21 and $37. LOAD FILES, in the 3D view, loads the 3D map its first argument names
  (not 127 or 255) and unlocks movement. LOAD PIECES loads the wall sets its three arguments name into slots 1..3: 127
  in the first loads set 0 into slot 1 alone; with both area graphics words set, slots 1 and 3 alone are loaded, slot 3
  refusing 127 as well; 255 empties a slot. Once both have run after the overland map, the view frame, the party and the
  status line are redrawn when the interface has left the overland map while the game loop is being entered, and that
  entering flag is cleared. }
procedure EclLoadFiles;
var
  f: array[1..3] of Byte;
  i: Byte;
begin
  EclMenu.LoadEclVars(3);
  GDVars.filesLoaded := 1;
  for i := 1 to 3 do f[i] := EclMenu.GetEclVar(i);
  if GDVars.eclOpcode = $21 then begin
    GDVars.mapLoaded := 1;
    if (f[1] <> 255) and (f[1] <> 127) and (GDVars.zone0^.view3dFlag <> 0) then begin
      GDVars.zone0^.mapId := f[1];
      View3D.Load3DMap(f[1]);
      GDVars.zone1^.moveLocked := 0
    end
  end else begin
    GDVars.piecesLoaded := 1;
    if f[1] = 127 then
      View3D.LoadWallSet(0, 1)
    else if (GDVars.zone0^.gfx1 <> 0) and (GDVars.zone0^.gfx2 <> 0) then begin
      if f[1] <> 255 then View3D.LoadWallSet(f[1], 1)
      else begin
        GDVars.wallSlots[1].id := -1;
        GDVars.wallSlots[1].slot := -1
      end;
      if (f[3] <> 255) and (f[3] <> 127) then
        View3D.LoadWallSet(f[3], 3)
      else begin
        GDVars.wallSlots[3].id := -1;
        GDVars.wallSlots[3].slot := -1
      end
    end else
      for i := 1 to 3 do
        if f[i] <> 255 then
          View3D.LoadWallSet(f[i], i)
        else begin
          GDVars.wallSlots[i].id := -1;
          GDVars.wallSlots[i].slot := -1
        end
  end;
  if (GDVars.piecesLoaded <> 0) and (GDVars.mapLoaded <> 0) and
      (GDVars.previousLocationType = C_Ifc.OVERLAND) then begin
    if (GDVars.interfaceState <> C_Ifc.OVERLAND) and (GDVars.enteringLoop <> 0) then begin
      Border.DrawViewFrame;
      CharHlp.DisplayParty(GDVars.curChar);
      CharHlp.PrintPositionAndTime
    end;
    GDVars.enteringLoop := 0
  end
end;

{ AND and OR, opcodes $2F and $30: combines its first two arguments bitwise, truncates the result to a byte, sets the
  comparison flags as for COMPARE of 0 with the result, and stores it at the address in its third. }
procedure EclAndOr;
var
  address: Word;
  rhs: Word;
  lhs: Word;
  r: Byte;
begin
  EclMenu.LoadEclVars(3);
  lhs := EclMenu.GetEclVar(1);
  rhs := EclMenu.GetEclVar(2);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  if GDVars.eclOpcode = $2F then r := lhs and rhs
  else r := lhs or rhs;
  EclMenu.EclCompareInt(0, r);
  EclMenu.WriteGbvm(address, r)
end;

{ GETTABLE, opcode $2A: reads the GBVM entry at its first argument's address plus its second and stores it at the
  address in its third. }
procedure EclGetTable;
var
  addr1: Word;
  addr2: Word;
  sum: Word;
  v: Word;
  idx: Byte;
begin
  EclMenu.LoadEclVars(3);
  addr1 := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  idx := EclMenu.GetEclVar(2);
  addr2 := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  sum := idx + addr1;
  v := EclMenu.ReadGbvm(sum);
  EclMenu.WriteGbvm(addr2, v)
end;

{ SAVETABLE, opcode $35: stores its first argument at the GBVM entry at its second argument's address plus its third. }
procedure EclSaveTable;
var
  idx: Word;
  address: Word;
  v: Word;
  sum: Word;
begin
  EclMenu.LoadEclVars(3);
  v := EclMenu.GetEclVar(1);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  idx := EclMenu.GetEclVar(3);
  sum := address + idx;
  EclMenu.WriteGbvm(sum, v)
end;

{ VERTICAL MENU, opcode $15: shows its message, then a vertical menu of as many strings as its third argument says, and
  stores the choice at the GBVM address in its first. }
procedure EclVMenu;
var
  count: Byte;
  i: Byte;
  msg: String;
  list: Types.PItemRec;
  head: Types.PItemRec;
  q: String[1];
  idx: Integer;
  redraw: Boolean;
  address: Word;
begin
  GDVars.horizontalChoice := 1;
  GDVars.bottomClear := 0;
  redraw := True;
  q := '';
  i := 1;
  EclMenu.LoadEclVars(3);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  msg := GDVars.gbStrings[1];
  count := EclMenu.GetEclVar(3);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  MenuCore.AllocStringList(count, list);
  head := list;
  GDVars.curCol := 1;
  GDVars.curRow := 17;
  TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, True, msg);
  while list <> nil do begin
    list^.name := GDVars.gbStrings[i];
    list^.inUse := 0;
    list := list^.next;
    Inc(i)
  end;
  list := head;
  idx := 0;
  EclMenu.EclVerticalMenu(q, q, LightMagenta, LightGreen, White, 1, GDVars.curRow + 1, 38, 22, Types.PItemRec(list),
                          False, redraw, idx, Types.PItemRec(list));
  EclMenu.WriteGbvm(address, idx);
  MenuCore.FreeStringList(list);
  TextRend.ClearRect(1, 17, 38, 22)
end;

{ HORIZONTAL MENU, opcode $2B: builds a '~A ~B ~C' horizontal menu from the strings that follow, as many as its second
  argument says, and stores the chosen index at the address in its first. A single choice also accepts Enter, and the
  joystick wording of the continue prompt becomes the keyboard wording. }
procedure EclHMenu;
var
  count: Byte;
  ch: Byte;
  i: Byte;
  q: String[1];
  menu: String[50];
  address: Word;
  enterOk: Boolean;
  anim: Boolean;
  hlCol: Byte;
  mCol: Byte;
begin
  GDVars.horizontalChoice := 1;
  q := '';
  menu := '';
  EclMenu.LoadEclVars(2);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  count := EclMenu.GetEclVar(2);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  menu := '';
  if count = 1 then begin
    enterOk := True;
    hlCol := 15;
    mCol := 15;
    if GDVars.gbStrings[1] = 'PRESS BUTTON OR RETURN TO CONTINUE.' then
      GDVars.gbStrings[1] := 'PRESS <ENTER>/<RETURN> TO CONTINUE'
  end else begin
    enterOk := False;
    hlCol := 15;
    mCol := 10
  end;
  anim := (GDVars.eclGraphics) and (GDVars.pictureDrawn <> 0);
  for i := 1 to count - 1 do
    menu := menu + '~' + GDVars.gbStrings[i] + ' ';
  menu := menu + '~' + GDVars.gbStrings[count];
  ch := EclMenu.MenuHorizontalCharacterSelect(q, menu, LightMagenta, mCol, hlCol, enterOk, anim);
  EclMenu.WriteGbvm(address, ch);
  TextRend.ClearRect(0, 24, 39, 24)
end;

{ CLEAR MONSTERS, opcode $1C: forgets the loaded monsters and undead, resets the icon slots to 8, and empties the pool
  and the treasure. }
procedure EclClearMonsters;
var
  next: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  count: Word;
begin
  Inc(GDVars.eclIp);
  GDVars.undeadCount := 0;
  GDVars.creatureCnt := 0;
  GDVars.monstersOn := 0;
  GDVars.iconAnimId := 8;
  FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
  while GDVars.treasureItems <> nil do begin
    next := GDVars.treasureItems^.next;
    FreeMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
    GDVars.treasureItems := next
  end
end;

{ PARTY STRENGTH, opcode $1D: stores the party's rating at the address in its first argument: for each member, (4 per
  cleric level + hit points + 5 per point of armor class below 0 + 5 per point of THAC0 below 21 + 8 per magic-user
  level) div 10, from the stored, 60-biased armor class and THAC0; the magic-user and cleric levels add the former-class
  levels when the earlier class's abilities count again. Note: the byte sum can overflow. }
procedure EclPartyStrength;
var
  hp: Byte;
  th: Byte;
  mage: Byte;
  cleric: Byte;
  ac: Byte;
  partyStrength: Byte;
  address: Word;
  p: Types.PCharRecord;
begin
  EclMenu.LoadEclVars(1);
  partyStrength := 0;
  p := GDVars.partyHead;
  while p <> nil do begin
    hp := p^.hpCur;
    ac := p^.acCur[0];
    th := p^.thac0Adj;
    mage :=
      p^.classLevels[C_Class.MAGE] +
      p^.classLevels2[C_Class.MAGE] * ShortInt(ClassCal.EarlierClassActive(p));
    cleric :=
      p^.classLevels[C_Class.CLERIC] +
      p^.classLevels2[C_Class.CLERIC] * ShortInt(ClassCal.EarlierClassActive(p));
    if ac > 60 then ac := ac - 60 else ac := 0;
    if th > 39 then th := th - 39 else th := 0;
    Inc(partyStrength, (cleric * 4 + (hp + ac * 5 + th * 5 + mage * 8)) div 10);
    p := p^.next
  end;
  address := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.WriteGbvm(address, partyStrength)
end;

{ PARTY CHECK, opcode $1E: measures the party on the attribute its first argument names -- with none, whether anyone
  carries the effect in its second; otherwise charisma, one of the eight thief skills or current movement -- and stores
  the lowest, highest and average values and the found flag at the GBVM addresses in its other four arguments. Other
  attributes do nothing. }
procedure EclCheckParty;
var
  attr: Integer;
  sum: Integer;
  effId: Byte;
  p: Types.PCharRecord;
  found: Byte;
  eff: Pointer;
  outv: array[1..3] of Byte;
  addr1: Word;
  addr2: Word;
  addr3: Word;
  addr4: Word;
  count: Byte;
  idx: Byte;

  { Stores the three results and the found flag at the four result addresses. }
  procedure Write4Gbvm;
  begin
    EclMenu.WriteGbvm(addr1, outv[1]);
    EclMenu.WriteGbvm(addr2, outv[2]);
    EclMenu.WriteGbvm(addr3, outv[3]);
    EclMenu.WriteGbvm(addr4, ShortInt(found))
  end;

begin
  EclMenu.LoadEclVars(6);
  p := GDVars.partyHead;
  found := 0;
  if GDVars.varTypes[1] = 1 then
    attr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1])
  else
    attr := EclMenu.GetEclVar(1);
  effId := EclMenu.GetEclVar(2);
  addr1 := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.varLo[4], GDVars.varHi[4]);
  addr3 := EclMenu.CombineBytesToWord(GDVars.varLo[5], GDVars.varHi[5]);
  addr4 := EclMenu.CombineBytesToWord(GDVars.varLo[6], GDVars.varHi[6]);
  sum := 0;
  count := 0;
  outv[1] := 255;
  outv[2] := 0;
  Dec(attr, $7C00);
  case attr of
    { key $8400 }
    -31744:
      begin
        while (p <> nil) and (found = 0) do begin
          found := Byte(CharHlp.HasEffect(p, effId, eff));
          p := p^.next
        end;
        FillChar(outv, SizeOf(outv), 0);
        Write4Gbvm
      end;
    $19:
      begin
        while p <> nil do begin
          Inc(count);
          if p^.stats[5].cur > outv[2] then outv[2] := p^.stats[5].cur;
          if p^.stats[5].cur < outv[1] then outv[1] := p^.stats[5].cur;
          Inc(sum, p^.stats[5].cur);
          p := p^.next
        end;
        outv[3] := sum div count;
        Write4Gbvm
      end;
    $A5..$AC:
      begin
        idx := attr - $A4;
        while p <> nil do begin
          Inc(count);
          if p^.thiefSkills[idx] < outv[1] then outv[1] := p^.thiefSkills[idx];
          if p^.thiefSkills[idx] > outv[2] then outv[2] := p^.thiefSkills[idx];
          Inc(sum, p^.thiefSkills[idx]);
          p := p^.next
        end;
        outv[3] := sum div count;
        Write4Gbvm
      end;
    $9F:
      begin
        while p <> nil do begin
          Inc(count);
          if p^.movementCur < outv[1] then outv[1] := p^.movementCur;
          if p^.movementCur > outv[2] then outv[2] := p^.movementCur;
          Inc(sum, p^.movementCur);
          p := p^.next
        end;
        outv[3] := sum div count;
        Write4Gbvm
      end
  end
end;

{ PARTY SURPRISE, opcode $22: stores 1 at its first argument's address when the party holds a ranger or a cleric/ranger,
  else 0, and 0 at its second's. }
procedure EclPartySurprise;
var
  p: Types.PCharRecord;
  mod1: Byte;
  mod2: Byte;
  { Unused in this version; see the other implementations of this routine. }
  rangerDead: Byte;
  addr1: Word;
  addr2: Word;
begin
  EclMenu.LoadEclVars(2);
  p := GDVars.partyHead;
  mod1 := 0;
  mod2 := 0;
  rangerDead := 0;
  while p <> nil do begin
    if (p^.charClass = C_Class.RANGER) or (p^.charClass = C_Class.CLERIC_RANGER) then begin
      mod1 := 1;
      rangerDead := 1
    end;
    p := p^.next
  end;
  addr1 := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  EclMenu.WriteGbvm(addr1, mod1);
  EclMenu.WriteGbvm(addr2, mod2)
end;

{ SURPRISE, opcode $23: rolls a six-sided die for each side against v4 + 2 - v1 and v2 + 2 - v3 and writes which side is
  surprised (1 or 2, 0 when neither is) to a fixed script address. Note: the final test overrides the both-sides result
  3, and the address lies outside the GBVM banks, where writes store nothing, so the result is lost. }
procedure EclSurprise;
var
  rollA: Byte;
  rollB: Byte;
  i: Byte;
  result: Byte;
  v: array[1..4] of Byte;
  needA: ShortInt;
  needB: ShortInt;
begin
  EclMenu.LoadEclVars(4);
  result := 0;
  for i := 1 to 4 do v[i] := EclMenu.GetEclVar(i);
  needA := v[4] + 2 - v[1];
  needB := v[2] + 2 - v[3];
  rollA := FxEngine.RollDice(1, 6);
  rollB := FxEngine.RollDice(1, 6);
  if rollA <= needA then
    if rollB <= needB then result := 3 else result := 1;
  if rollB <= needB then result := 2;
  EclMenu.WriteGbvm($2CB, result)
end;

{ COMBAT, opcode $24: with no monsters loaded and no duel, runs the shop or the temple when the zone asks for one
  (clearing the request), and otherwise settles the encounter (PostCbt.PostCombat); with monsters it caps the monster
  distance at the open distance ahead, runs the fight, settles it and ends any duel. Then it returns to the overland or
  3D view (showing the overland picture, 121, after a fight), keeps the search bit alone, clears the monster flags and
  the graphics flag, and redraws the interface (not after a shop or temple overland), with the map cursor overland. Each
  overlay is primed with the sound driver stopped. }
procedure EclCombat;
var
  dist: Word;
  redraw: Boolean;
  savedStep: Byte;
begin
  GDVars.specialView := 0;
  savedStep := GDVars.extendedMode;
  GDVars.extendedMode := 0;
  Inc(GDVars.eclIp);
  redraw := True;
  if (GDVars.monstersOn = 0) and (GDVars.duelFlag = 0) then begin
    if GDVars.zone1^.enterShop = 1 then begin
      GDVars.zone1^.enterShop := 0;
      if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sndStop);
      Shop.PrimeShop;
      if GDVars.soundActive = 0 then SoundDrv.StartSound;
      Shop.ShopMainMenu;
      if GDVars.zone0^.view3dFlag = 0 then begin
        redraw := False;
        if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sndStop);
        MapCurs.PrimeMapCurs;
        if GDVars.soundActive = 0 then SoundDrv.StartSound
      end else begin
        if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sndStop);
        View3D.PrimeView3D;
        if GDVars.soundActive = 0 then SoundDrv.StartSound
      end
    end else if GDVars.zone1^.enterTemple = 1 then begin
      GDVars.zone1^.enterTemple := 0;
      if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sndStop);
      Temple.PrimeTemple;
      if GDVars.soundActive = 0 then SoundDrv.StartSound;
      Temple.TempleMainMenu;
      if GDVars.zone0^.view3dFlag = 0 then begin
        redraw := False;
        if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sndStop);
        MapCurs.PrimeMapCurs;
        if GDVars.soundActive = 0 then SoundDrv.StartSound
      end else begin
        if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sndStop);
        View3D.PrimeView3D;
        if GDVars.soundActive = 0 then SoundDrv.StartSound
      end
    end else begin
      if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sndStop);
      PostCbt.PrimePostCbt;
      if GDVars.soundActive = 0 then SoundDrv.StartSound;
      PostCbt.PostCombat;
      if GDVars.zone0^.view3dFlag = 0 then begin
        if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sndStop);
        MapCurs.PrimeMapCurs;
        if GDVars.soundActive = 0 then SoundDrv.StartSound
      end else begin
        if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sndStop);
        View3D.PrimeView3D;
        if GDVars.soundActive = 0 then SoundDrv.StartSound
      end
    end
  end else begin
    if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sndStop);
    Combat.PrimeCombat;
    CombatSt.PrimeCombatSt;
    CombatAi.PrimeCombatAi;
    CbtActs.PrimeCbtActs;
    CbtMap.PrimeCbtMap;
    Pathing.PrimePathing;
    if GDVars.soundActive = 0 then SoundDrv.StartSound;
    dist := EclMenu.MaxMonsterDist(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
    if dist < GDVars.zone1^.monsterDist then GDVars.zone1^.monsterDist := dist;
    Combat.CombatMain;
    if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sndStop);
    PostCbt.PrimePostCbt;
    PostCbt.PostCombat;
    if GDVars.soundActive = 0 then SoundDrv.StartSound;
    if GDVars.zone0^.view3dFlag = 0 then begin
      if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sndStop);
      MapCurs.PrimeMapCurs;
      if GDVars.soundActive = 0 then SoundDrv.StartSound;
      Portrait.LoadBigPic(121)
    end else begin
      if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sndStop);
      View3D.PrimeView3D;
      if GDVars.soundActive = 0 then SoundDrv.StartSound
    end;
    if GDVars.duelFlag <> 0 then GDVars.duelFlag := 0
  end;
  if GDVars.zone0^.view3dFlag = 0 then GDVars.interfaceState := C_Ifc.OVERLAND
  else GDVars.interfaceState := C_Ifc.VIEW_3D;
  GDVars.zone1^.searchFlags := GDVars.zone1^.searchFlags and $01;
  FillChar(GDVars.monFlags, SizeOf(GDVars.monFlags), 0);
  GDVars.eclGraphics := False;
  if redraw then begin
    CharHlp.DisplayNoncombatInterface;
    if (GDVars.zone0^.view3dFlag = 0) and (not GDVars.partyDefeated) and (GDVars.zone0^.areaView = 0) then
      MapCurs.DrawCursor
  end;
  GDVars.extendedMode := savedStep
end;

{ ON GOTO and ON GOSUB, opcodes $25 and $26: jumps to, or calls, the address its first argument picks from the list
  whose length its second gives; an index past the list does nothing. }
procedure EclOnGoto;
var
  sel: Byte;
  count: Byte;
  { Unused in this version; see the other implementations of this routine. }
  target: Byte;
  i: Byte;
  found: Byte;
begin
  found := 0;
  EclMenu.LoadEclVars(2);
  sel := EclMenu.GetEclVar(1);
  count := EclMenu.GetEclVar(2);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  i := 0;
  while (i < count) and (found = 0) do begin
    if sel = i then begin
      if GDVars.eclOpcode = $25 then
        GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.varLo[i + 1], GDVars.varHi[i + 1])
      else
        EclMenu.EclGosub(i + 1);
      found := 1
    end else
      Inc(i)
  end
end;

{ TREASURE, opcode $27: sets the treasure money from its first seven arguments. The eighth adds items: below $80 the
  item list in that block of ITEM<disk>.DAX (quitting the game when it is missing), $80 + n that many random items,
  whose display names are then built, and 255 nothing. Items are added at the front of the treasure. }
procedure EclTreasure;
var
  i: ShortInt;
  tId: Byte;
  j: Byte;
  { Unused in this version; see the other implementations of this routine. }
  treasureMsg: String[22];
  it: Types.TItemRec;
  tmp: Types.PItemRec;
  walk: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  roll3: Byte;
  roll: Byte;
  roll2: Byte;
  { Unused in this version; see the other implementations of this routine. }
  roll4: Byte;
  itemId: Byte;
  offset: Word;
  sizeRead: Word;
  s: String[1];
  data: Types.PBytes;
begin
  EclMenu.LoadEclVars(8);
  for i := 0 to 6 do
    GDVars.treasureMoney[i] := EclMenu.GetEclVar(Byte(i) + 1);
  tId := EclMenu.GetEclVar(8);
  if tId < $80 then begin
    Str(GDVars.currentDisk, s);
    DaxIo.LoadDax('ITEM' + s, '.dax', tId, sizeRead, data);
    if sizeRead = 0 then begin
      TextRend.displayAndPause(White, Black, 'Unable to find item file');
      GameIo.ExitGame
    end;
    offset := 0;
    repeat
      Move(data^[offset], it, SizeOf(it));
      it.next := nil;
      Inc(offset, SizeOf(Types.TItemRec));
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it
      end else begin
        tmp := GDVars.treasureItems;
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := tmp
      end
    until offset >= sizeRead;
    FreeMem(data, sizeRead)
  end else begin
    if tId = 255 then Exit;
    i := tId - $80;
    for j := 1 to i do begin
      roll := FxEngine.RollDice(1, 100);
      case roll of
        1..20:
          begin
            roll2 := FxEngine.RollDice(1, 100);
            case roll2 of
              1..10:
                begin
                  roll2 := FxEngine.RollDice(1, 10);
                  case roll2 of
                    1, 2: itemId := 6;
                    3..6: itemId := 8;
                    7, 8: itemId := 70;
                    9: itemId := 15;
                    10: itemId := 29
                  end
                end;
              11..25:
                begin
                  roll2 := FxEngine.RollDice(1, 20);
                  case roll2 of
                    1..3: itemId := 5;
                    4, 5: itemId := 7;
                    6..8: itemId := 24;
                    9, 10: itemId := 22;
                    11, 12: itemId := 25;
                    13, 14: itemId := 23;
                    15, 16: itemId := 28;
                    17, 18: itemId := 29;
                    19, 20: itemId := 30
                  end
                end;
              26..100:
                begin
                  roll2 := FxEngine.RollDice(1, 4);
                  if roll2 < 4 then begin
                    roll2 := FxEngine.RollDice(1, 20);
                    case roll2 of
                      1..8: itemId := 18;
                      9..13: itemId := 17;
                      14: itemId := 13;
                      15: itemId := 16;
                      16..18: itemId := 19;
                      19, 20: itemId := 20
                    end
                  end else begin
                    roll2 := FxEngine.RollDice(1, 8);
                    case roll2 of
                      1: itemId := 1;
                      2, 3: itemId := 4;
                      4, 5: itemId := 8;
                      6: itemId := 10;
                      7: itemId := 14;
                      8: itemId := 71
                    end
                  end
                end
            end
          end;
        21..65: itemId := 39;
        66..70: itemId := 40;
        71..80: itemId := 37;
        81..85: itemId := 59;
        86..95:
          begin
            roll2 := FxEngine.RollDice(1, 20);
            case roll2 of
              1..3: itemId := 31;
              4..11: itemId := 35;
              12..16: itemId := 36;
              17: itemId := 32;
              18: itemId := 33;
              19, 20: itemId := 34
            end
          end;
        96..100:
          begin
            roll2 := FxEngine.RollDice(1, 6);
            case roll2 of
              1, 2: itemId := 50;
              3, 4: itemId := 48;
              5: itemId := 52;
              6: itemId := 53
            end
          end
      end;
      Money.GenerateRandomItem(itemId, it);
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := nil
      end else begin
        tmp := GDVars.treasureItems;
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := tmp
      end
    end;
    walk := GDVars.treasureItems;
    while walk <> nil do begin
      CharHlp.PrintItemString(GDVars.curChar, walk, 0, 0, False, False);
      walk := walk^.next
    end
  end
end;

{ ROB, opcode $28: takes the percentage of money in its second argument and, with the chance in its third, items from
  the current character, or from every member when its first is non-zero. }
procedure EclRob;
var
  whole: Byte;
  pct: Byte;
  chance: Byte;
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  inv: Types.PItemRec;
  fraction: Real;
begin
  EclMenu.LoadEclVars(3);
  whole := EclMenu.GetEclVar(1);
  pct := EclMenu.GetEclVar(2);
  fraction := (100 - pct) / 100;
  chance := EclMenu.GetEclVar(3);
  if whole = 0 then begin
    EclMenu.RobMoney(fraction, Types.PCharRecord(GDVars.curChar));
    EclMenu.RobItems(chance, Types.PCharRecord(GDVars.curChar))
  end else begin
    p := GDVars.partyHead;
    while p <> nil do begin
      inv := p^.itemsAddr;
      EclMenu.RobMoney(fraction, Types.PCharRecord(p));
      EclMenu.RobItems(chance, Types.PCharRecord(p));
      p := p^.next
    end
  end
end;

{ ENCOUNTER MENU, opcode $29: runs the encounter menu until combat, flight, parley or the monsters' retreat ends it;
  WAIT and ADVANCE update the encounter and repeat. Stores the outcome at the address in its fourth argument: 0 when the
  monsters flee, 1 for combat, 2 when the party flees, 3 for parley. }
procedure EclEncounter;
var
  sel: Byte;
  resp: array[0..4] of Byte;
  msgs: array[1..3] of String;
  msg: String;
  fleePar: Byte;
  fleeMon: Byte;
  i: Byte;
  hiMove: Byte;
  loMove: Byte;
  waited: Boolean;
  clearW: Boolean;
  anim: Boolean;
  menu: String[40];
  q: String[1];
  choice: Byte;
  k: Byte;
  address: Word;
begin
  GDVars.inEncounterMenu := 1;
  GDVars.bottomClear := 0;
  GDVars.slowText := 1;
  EclMenu.MoveExtremes(hiMove, loMove);
  q := '';
  EclMenu.LoadEclVars(14);
  GDVars.approachA := EclMenu.GetEclVar(1);
  GDVars.zone1^.distReq := EclMenu.GetEclVar(2);
  GDVars.approachB := EclMenu.GetEclVar(3);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[4], GDVars.varHi[4]);
  for i := 0 to 4 do resp[i] := EclMenu.GetEclVar(i + 5);
  for i := 1 to 3 do msgs[i] := GDVars.gbStrings[i];
  fleePar := EclMenu.GetEclVar(13);
  fleeMon := EclMenu.GetEclVar(14);
  GDVars.zone1^.monsterDist := EclMenu.MaxMonsterDist(GDVars.mapState.x, GDVars.mapState.y, GDVars.mapState.facing);
  if GDVars.zone1^.distReq < GDVars.zone1^.monsterDist then
    GDVars.zone1^.monsterDist := GDVars.zone1^.distReq;
  EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.monsterDist), GDVars.monFlags);
  repeat
    anim := (GDVars.eclGraphics) and (GDVars.pictureDrawn <> 0) and (GDVars.zone0^.view3dFlag <> 0) and
      (GDVars.picArcId <> 9);
    clearW := GDVars.zone0^.view3dFlag <> 0;
    waited := False;
    GDVars.curCol := 1;
    GDVars.curRow := 17;
    case GDVars.zone1^.monsterDist of
      0:
        begin
          k := 1;
          repeat
            msg := msgs[k];
            Inc(k)
          until (msg <> '') or (k > 3)
        end;
      1:
        begin
          k := 2;
          repeat
            msg := msgs[k];
            Inc(k);
            if k > 3 then k := 1
          until (msg <> '') or (k = 2)
        end;
      2:
        begin
          k := 3;
          repeat
            msg := msgs[k];
            Inc(k);
            if k > 3 then k := 1
          until (msg <> '') or (k = 3)
        end
    end;
    if msg = '' then clearW := False;
    TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, clearW, msg);
    if (GDVars.zone1^.monsterDist = 0) or (GDVars.zone0^.view3dFlag = 0) then
      menu := '~COMBAT ~WAIT ~FLEE ~PARLAY'
    else
      menu := '~COMBAT ~WAIT ~FLEE ~ADVANCE';
    sel := EclMenu.MenuHorizontalCharacterSelect(q, menu, LightMagenta, LightGreen, White, False, anim);
    if ((GDVars.zone1^.monsterDist = 0) or (GDVars.zone0^.view3dFlag = 0)) and (sel = 3) then sel := 4;
    choice := resp[sel];
    case choice of
      0:
        if sel <> 2 then
          EclMenu.WriteGbvm(address, 1)
        else if loMove >= fleePar then
          EclMenu.WriteGbvm(address, 2)
        else
          EclMenu.WriteGbvm(address, 1);
      1:
        case sel of
          0: EclMenu.WriteGbvm(address, 1);
          1:
            begin
              waited := True;
              TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, True, 'Both sides wait.')
            end;
          2: EclMenu.WriteGbvm(address, 2);
          3:
            begin
              if GDVars.zone1^.monsterDist <> 0 then begin
                Dec(GDVars.zone1^.monsterDist);
                EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.monsterDist),
                                       GDVars.monFlags)
              end else
                TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, True, 'Both sides wait.');
              waited := True
            end;
          4:
            if GDVars.zone1^.monsterDist <= 0 then
              EclMenu.WriteGbvm(address, 3)
            else begin
              Dec(GDVars.zone1^.monsterDist);
              EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.monsterDist),
                                     GDVars.monFlags);
              waited := True
            end
        end;
      2:
        case sel of
          0:
            if fleeMon > hiMove then begin
              EclMenu.WriteGbvm(address, 0);
              GDVars.curCol := 1;
              GDVars.curRow := 17;
              TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, True, 'The monsters flee.')
            end else
              EclMenu.WriteGbvm(address, 1);
          1..4:
            begin
              EclMenu.WriteGbvm(address, 0);
              GDVars.curCol := 1;
              GDVars.curRow := 17;
              TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, True, 'The monsters flee.')
            end
        end;
      3:
        case sel of
          0: EclMenu.WriteGbvm(address, 1);
          1, 3:
            begin
              if GDVars.zone1^.monsterDist <> 0 then begin
                Dec(GDVars.zone1^.monsterDist);
                EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.monsterDist),
                                       GDVars.monFlags)
              end else
                TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, True, 'Both sides wait.');
              waited := True
            end;
          2: EclMenu.WriteGbvm(address, 2);
          4:
            if GDVars.zone1^.monsterDist <= 0 then
              EclMenu.WriteGbvm(address, 3)
            else begin
              Dec(GDVars.zone1^.monsterDist);
              EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.monsterDist),
                                     GDVars.monFlags);
              waited := True
            end
        end;
      4:
        case sel of
          0: EclMenu.WriteGbvm(address, 1);
          1, 3, 4:
            if GDVars.zone1^.monsterDist <= 0 then
              EclMenu.WriteGbvm(address, 3)
            else begin
              Dec(GDVars.zone1^.monsterDist);
              EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.monsterDist),
                                     GDVars.monFlags);
              waited := True
            end;
          2: EclMenu.WriteGbvm(address, 2)
        end
    end
  until not waited;
  MenuCore.ClearBottomLine;
  GDVars.slowText := 0;
  GDVars.inEncounterMenu := 0
end;

{ PARLAY: offers Haughty, Sly, Nice, Meek and Abusive and stores the script's value for the chosen attitude at the sixth
  argument's address. }
procedure EclParlay;
var
  sel: Byte;
  value: Byte;
  i: Byte;
  vals: array[0..4] of Byte;
  address: Word;
  q: Char;
begin
  EclMenu.LoadEclVars(6);
  q := ' ';
  for i := 0 to 4 do
    vals[i] := EclMenu.GetEclVar(i + 1);
  sel := EclMenu.MenuHorizontalCharacterSelect(q, '~HAUGHTY ~SLY ~NICE ~MEEK ~ABUSIVE', LightMagenta, LightGreen, White,
                                               False, False);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[6], GDVars.varHi[6]);
  value := vals[sel];
  EclMenu.WriteGbvm(address, value)
end;

{ FIND ITEM, opcode $32: sets the equal flag when a party member carries an item of the type in its argument, the
  not-equal flag otherwise. }
procedure EclFindItem;
var
  target: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemCount: Byte;
  p: Types.PCharRecord;
  item: Types.PItemRec;
  found: Byte;
begin
  EclMenu.LoadEclVars(1);
  found := 0;
  target := EclMenu.GetEclVar(1);
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  GDVars.cmpFlags[1] := True;
  p := GDVars.partyHead;
  while (p <> nil) and (found = 0) do begin
    item := p^.itemsAddr;
    while (item <> nil) and (found = 0) do begin
      if target = item^.itemType then begin
        GDVars.cmpFlags[0] := True;
        GDVars.cmpFlags[1] := False;
        found := 1
      end;
      item := item^.next
    end;
    p := p^.next
  end
end;

{ DELAY, opcode $3A: waits the message delay; no key is read. }
procedure EclDelay;
begin
  Inc(GDVars.eclIp);
  TextRend.pauseOnly
end;

{ DAMAGE, opcode $2E: deals damage of its second operand's count of dice with its third's sides, plus its fourth. With
  bit 7 of its first operand set, the damage goes to the whole party (bit 6), the current character (bit 7 of the fifth
  operand) or a random member, and a saving throw of the type in the fifth operand's low three bits (one less for the
  current character, for whom 0 allows none), modified by the first operand's low five bits, avoids it unless bit 4 is
  set; bit 5 skips the whole party's saves. Otherwise the first operand is a number of attacks on random members, each
  rolled to hit against the fifth operand and each with fresh damage. When no member is left in play, it shows that the
  party is killed. }
procedure EclDamage;
var
  attack: Byte;
  dice: Byte;
  sides: Byte;
  i: Byte;
  atkLo: Byte;
  varOp: Byte;
  bonus: Byte;
  target: Byte;
  saveTy: Byte;
  j: Byte;
  dmg: Word;
  p: Types.PCharRecord;
  q: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  damageType: Byte;
  areaAtk: Byte;
  saveBit: Byte;
begin
  savedCur := GDVars.curChar;
  damageType := 0;
  areaAtk := 0;
  p := GDVars.partyHead;
  EclMenu.LoadEclVars(5);
  attack := EclMenu.GetEclVar(1);
  dice := EclMenu.GetEclVar(2);
  sides := EclMenu.GetEclVar(3);
  bonus := EclMenu.GetEclVar(4);
  varOp := EclMenu.GetEclVar(5);
  dmg := FxEngine.RollDice(dice, sides) + bonus;
  saveBit := attack and $10;
  if (attack and $40) <> 0 then
    areaAtk := 1
  else
    target := FxEngine.RollDice(1, Byte(GDVars.zone1^.partySize));
  if (attack and $80) <> 0 then begin
    atkLo := attack and $1F;
    saveTy := varOp and $07;
    if areaAtk <> 0 then begin
      while p <> nil do begin
        if (attack and $20) <> 0 then
          EclMenu.EclInflictDamage(dmg, Types.PCharRecord(p))
        else if not FxEngine.RollSavingThrow(p, saveTy, atkLo) then
          EclMenu.EclInflictDamage(dmg, Types.PCharRecord(p))
        else if saveBit <> 0 then
          EclMenu.EclInflictDamage(dmg, Types.PCharRecord(p));
        p := p^.next
      end
    end else if (varOp and $80) <> 0 then begin
      if (saveTy = 0) or not FxEngine.RollSavingThrow(GDVars.curChar, saveTy - 1, atkLo) then
        EclMenu.EclInflictDamage(dmg, Types.PCharRecord(GDVars.curChar))
      else if saveBit <> 0 then
        EclMenu.EclInflictDamage(dmg, Types.PCharRecord(GDVars.curChar))
    end else begin
      for i := 2 to target do p := p^.next;
      if not FxEngine.RollSavingThrow(p, saveTy, atkLo) then
        EclMenu.EclInflictDamage(dmg, Types.PCharRecord(p))
      else if saveBit <> 0 then
        EclMenu.EclInflictDamage(dmg, Types.PCharRecord(p))
    end
  end else begin
    for i := 1 to attack do begin
      p := GDVars.partyHead;
      target := FxEngine.RollDice(1, Byte(GDVars.zone1^.partySize));
      j := 1;
      while j < target do begin
        p := p^.next;
        Inc(j)
      end;
      if FxEngine.AttackRollNoAttacker(p, varOp) then
        EclMenu.EclInflictDamage(dmg, Types.PCharRecord(p));
      dmg := FxEngine.RollDice(dice, sides) + bonus
    end
  end;
  q := GDVars.partyHead;
  GDVars.partyDefeated := True;
  while q <> nil do begin
    if q^.inPlay <> 0 then GDVars.partyDefeated := False;
    q := q^.next
  end;
  if GDVars.partyDefeated then begin
    Border.DrawWindowFrame(True);
    GDVars.curCol := 2;
    GDVars.curRow := 2;
    TextRend.displayMessageWindow(1, 1, 38, 22, LightGreen, Black, True, 'The entire party is killed!');
    Delay(3000)
  end;
  GDVars.curChar := savedCur;
  TextRend.displayAndPause(White, Black, 'press <enter>/<return> to continue')
end;

{ SPRITE OFF, opcode $31: when a sprite is showing, redraws the map view over it. }
procedure EclSpriteOff;
begin
  Inc(GDVars.eclIp);
  if GDVars.spriteShown then begin
    GDVars.pictureRedrawRequested := 1;
    MapView.DisplayMapView;
    GDVars.spriteShown := False;
    GDVars.eclGraphics := False
  end
end;

{ CLOCK, opcode $34: advances the clock by its first argument in the unit its second names. }
procedure EclClock;
var
  amount: Byte;
  unitId: Byte;
begin
  EclMenu.LoadEclVars(2);
  amount := EclMenu.GetEclVar(1);
  unitId := EclMenu.GetEclVar(2);
  GameTime.AdvanceTime(amount, unitId)
end;

{ PRINT RETURN, opcode $33: moves the message cursor to the start of the next line and clears the print-return flag. }
procedure EclPrintReturn;
begin
  Inc(GDVars.eclIp);
  if GDVars.printReturnFlag <> 0 then begin
    GDVars.curCol := 1;
    Inc(GDVars.curRow);
    GDVars.printReturnFlag := 0
  end else begin
    GDVars.curCol := 1;
    Inc(GDVars.curRow)
  end
end;

{ CLEAR BOX, opcode $3D: redraws the view frame, the party and the picture box (not in a demo). }
procedure EclClearBox;
begin
  Inc(GDVars.eclIp);
  GDVars.specialView := 0;
  Border.DrawViewFrame;
  CharHlp.DisplayParty(GDVars.curChar);
  CharHlp.PrintPositionAndTime;
  if GDVars.demoFlag = 0 then
    Portrait.DisplayImageBuf(3, 3, True, GDVars.bigAnim.frames[1].image);
  CharHlp.PrintPositionAndTime;
  GDVars.enteringLoop := 0;
  GDVars.boxCleared := 1
end;

{ WHO, opcode $39: asks the player to pick a party member, with its argument as the prompt, and makes that member
  current. }
procedure EclWho;
var
  msg: String;
  saved: Byte;
begin
  saved := GDVars.extendedMode;
  GDVars.extendedMode := 0;
  GDVars.charNotFound := 0;
  EclMenu.LoadEclVars(1);
  TextRend.ClearRect(1, 17, 38, 22);
  msg := GDVars.gbStrings[1];
  CharHlp.SelectChar(msg, False, False, GDVars.curChar);
  GDVars.extendedMode := saved
end;

{ ADD NPC, opcode $36: adds the monster its first argument names to the party as a non-player character whose morale is
  half its second argument. }
procedure EclAddNpc;
var
  { Unused in this version; see the other implementations of this routine. }
  npc: Pointer;
  id: Byte;
  morale: Byte;
begin
  EclMenu.LoadEclVars(2);
  id := EclMenu.GetEclVar(1);
  SaveLoad.AddCreatureToParty(id);
  morale := EclMenu.GetEclVar(2);
  morale := morale div 2;
  morale := morale or $80;
  Types.PCharRecord(GDVars.curChar)^.npc := morale;
  CharHlp.RecalcStats(GDVars.curChar);
  CharHlp.DisplayParty(GDVars.curChar)
end;

{ SPELL, opcode $3B: finds the first party member with the spell in its first argument memorized and writes the slot and
  the member's party position (from 0) to the GBVM addresses in its second and third; when no member has it, the slot is
  255 and the position the last member's. }
procedure EclSpell;
var
  spellId: Byte;
  slot: Byte;
  idx: Byte;
  p: Types.PCharRecord;
  found: Byte;
  innerDone: Byte;
  addr1: Word;
  addr2: Word;
begin
  innerDone := 0;
  found := 0;
  EclMenu.LoadEclVars(3);
  spellId := EclMenu.GetEclVar(1);
  addr1 := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  slot := 1;
  idx := 0;
  p := Types.PCharRecord(GDVars.partyHead);
  while (p <> nil) and (found = 0) do begin
    slot := 0;
    repeat
      if p^.memorized[slot] = spellId then
        found := 1
      else if slot < 57 then
        Inc(slot)
      else
        innerDone := 1
    until (innerDone <> 0) or (found <> 0);
    innerDone := 0;
    p := p^.next;
    if (p <> nil) and (found = 0) then Inc(idx)
  end;
  if found = 0 then slot := 255;
  EclMenu.WriteGbvm(addr1, slot);
  EclMenu.WriteGbvm(addr2, idx);
  Debug.PrintDebug('spell', slot, idx, spellId)
end;

{ CALL, opcode $2D: runs the engine routine its argument's address, less $7FFF, selects: $AE11 refreshes the cell event
  and, when the view has changed, the map view, the status line and the wall ahead; $3204 plays sound slot 6, or slot 7
  for sound effect 10; $401F moves the party forward; $4019 refreshes the wall ahead outside the 3D view; $E804 shows
  the next frame of the big animation and pauses. }
procedure EclCall;
var
  address: Word;
  magicKey: Word;
begin
  EclMenu.LoadEclVars(1);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  magicKey := address - $7FFF;
  case magicKey of
    $AE11:
      begin
        GDVars.mapState.event := View3D.GetMapEvent(GDVars.mapState.x, GDVars.mapState.y);
        if (GDVars.eclGraphics) or (GDVars.spriteShown) or (GDVars.viewColorsChanged) or
            (GDVars.partyMoved) or (GDVars.redrawSky) then begin
          FillChar(GDVars.monFlags, SizeOf(GDVars.monFlags), 0);
          GDVars.pictureRedrawRequested := 1;
          MapView.DisplayMapView;
          CharHlp.PrintPositionAndTime;
          GDVars.redrawSky := False;
          GDVars.viewColorsChanged := False;
          GDVars.partyMoved := False;
          GDVars.eclGraphics := False;
          GDVars.spriteShown := False;
          GDVars.mapState.wallAhead := View3D.GetWallType(GDVars.mapState.x, GDVars.mapState.y,
                                                           GDVars.mapState.facing)
        end
      end;
    $3204:
      case GDVars.sndEffect of
        8: SoundDrv.SoundCommand(GDConsts.soundIds[6]);
        10: SoundDrv.SoundCommand(GDConsts.soundIds[7]);
      else
        SoundDrv.SoundCommand(GDConsts.soundIds[6])
      end;
    $401F: EclMenu.EclMoveForward;
    $4019:
      if GDVars.zone0^.view3dFlag = 0 then
        GDVars.mapState.wallAhead := View3D.GetWallType(GDVars.mapState.x, GDVars.mapState.y,
                                                         GDVars.mapState.facing);
    $E804:
      begin
        Mouse.HideMouse;
        Portrait.DisplayImageBuf(3, 3, True, GDVars.bigAnim.frames[GDVars.bigAnim.currentFrame].image);
        Mouse.ShowMouse;
        Inc(GDVars.bigAnim.currentFrame);
        if GDVars.bigAnim.currentFrame > GDVars.bigAnim.frameCount then
          GDVars.bigAnim.currentFrame := 1;
        TextRend.pauseOnly
      end
  end
end;

{ Runs the pre-camp script and the camp menu, then, when the rest was interrupted, redraws the interface and runs the
  camp-interrupted script. Afterwards it redraws the map view (and the cursor overland) unless an area view is up, and
  clears the recently-saved flag. }
procedure EnterCamp;
var
  interrupted: Boolean;
begin
  Camp.PrimeCamp;
  interrupted := False;
  EclVm.CallEclScript(GDVars.eclEntryPoints.preCampCheck);
  Camp.CampMainMenu(interrupted);
  if interrupted then begin
    CharHlp.DisplayNoncombatInterface;
    EclVm.CallEclScript(GDVars.eclEntryPoints.campInterrupted)
  end;
  GDVars.pictureRedrawRequested := 1;
  if GDVars.zone0^.areaView = 0 then MapView.DisplayMapView;
  GDVars.recentlySaved := 0;
  if (GDVars.zone0^.view3dFlag = 0) and (GDVars.zone0^.areaView = 0) then MapCurs.DrawCursor
end;

{ PROGRAM, opcode $38: after restoring the saved current character, runs the party menu (program 0, redrawing the
  interface overland unless picture 9 or an area view is up) or camp (program 9, keeping the instruction pointer, which
  ends the script unless an area view is up). Other programs do nothing. }
procedure EclProgram;
var
  prog: Byte;
  savedIp: Word;
  { Unused in this version; see the other implementations of this routine. }
  p: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  key: Byte;
  savedStep: Byte;
begin
  savedStep := GDVars.extendedMode;
  GDVars.extendedMode := 0;
  if GDVars.restoreChar <> 0 then begin
    GDVars.curChar := GDVars.savedChar;
    GDVars.restoreChar := 0
  end;
  EclMenu.LoadEclVars(1);
  prog := EclMenu.GetEclVar(1);
  case prog of
    0:
      begin
        CharGen.PrimeCharGen;
        CharGen.MainMenu;
        if (GDVars.picArcId <> 9) and (GDVars.zone0^.view3dFlag = 0) and
            (GDVars.zone0^.areaView = 0) then CharHlp.DisplayNoncombatInterface
      end;
    9:
      begin
        savedIp := GDVars.eclIp;
        EclVm.EnterCamp;
        GDVars.eclIp := savedIp;
        if GDVars.zone0^.areaView = 0 then EclVm.EclExit
      end
  end;
  GDVars.extendedMode := savedStep
end;

{ PROTECTION, opcode $3C: does nothing. }
procedure EclProtection;
begin
end;

{ DUMP, opcode $3E: removes the current character from the party, keeps the character that becomes current as the saved
  character to restore, and redraws the party. }
procedure EclDump;
var
  { Unused in this version; see the other implementations of this routine. }
  count: Word;
begin
  Inc(GDVars.eclIp);
  CharGen.RemoveCreature(False, True);
  GDVars.savedChar := GDVars.curChar;
  CharHlp.DisplayParty(GDVars.curChar)
end;

{ FIND SPECIAL, opcode $3F: clears the compare flags, then sets the equal flag when the current character has the effect
  in its argument, the not-equal flag otherwise. }
procedure EclFindSpecial;
var
  node: Pointer;
  value: Byte;
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  EclMenu.LoadEclVars(1);
  value := EclMenu.GetEclVar(1);
  if CharHlp.HasEffect(GDVars.curChar, value, node) then
    GDVars.cmpFlags[0] := True
  else
    GDVars.cmpFlags[1] := True
end;

{ DESTROY ITEMS, opcode $40: removes each item matching its argument from every party member, unreadying it first when
  it is readied, and recalculates each member; the current character is restored afterwards. }
procedure EclDestroyItems;
var
  target: Byte;
  p: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  item: Types.PItemRec;
  nextItem: Types.PItemRec;
begin
  EclMenu.LoadEclVars(1);
  target := EclMenu.GetEclVar(1);
  savedCur := GDVars.curChar;
  p := GDVars.partyHead;
  while p <> nil do begin
    item := p^.itemsAddr;
    while item <> nil do begin
      nextItem := item^.next;
      if target = item^.itemType then begin
        GDVars.curChar := p;
        if item^.equipped <> 0 then ViewChar.ToggleReadyItem(item);
        CharHlp.RemoveItem(p, item)
      end;
      item := nextItem
    end;
    CharHlp.RecalcStats(p);
    p := p^.next
  end;
  GDVars.curChar := savedCur
end;

{ AWARD EXPERIENCE, opcode $41: gives the experience in its second argument, divided by each recipient's number of
  classes, to each member in play when its first is nonzero, otherwise to the current character if it is in play, and
  announces it. }
procedure EclAwardExperience;
var
  xpTotal: Word;
  mode: Byte;
  p: Types.PCharRecord;
  i: ShortInt;
  count: Byte;
  share: Word;
begin
  EclMenu.LoadEclVars(2);
  xpTotal := EclMenu.GetEclVar(2);
  mode := EclMenu.GetEclVar(1);
  GDVars.curRow := 17;
  GDVars.curCol := 1;
  if mode <> 0 then begin
    TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, True,
                                  'Congratulations the party gains experience!');
    TextRend.pauseOnly;
    p := Types.PCharRecord(GDVars.partyHead);
    while p <> nil do begin
      count := 0;
      for i := 0 to 7 do
        if p^.classLevels[i] > 0 then Inc(count);
      share := xpTotal div count;
      if p^.inPlay <> 0 then Inc(p^.experience, share);
      p := p^.next
    end
  end else begin
    p := Types.PCharRecord(GDVars.curChar);
    TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, True,
                                  'Congratulations ' + p^.name + ' gains experience!');
    TextRend.pauseOnly;
    count := 0;
    for i := 0 to 7 do
      if p^.classLevels[i] > 0 then Inc(count);
    share := xpTotal div count;
    if p^.inPlay <> 0 then Inc(p^.experience, share)
  end
end;

{ Runs the handler for the current opcode. }
procedure DispatchEclCommand;
begin
  case GDVars.eclOpcode of
    $00: EclVm.EclExit;
    $01: EclVm.EclGoto;
    $02: EclVm.EclGosubCmd;
    $03: EclVm.EclCompare;
    $04, $05, $06, $07: EclVm.EclArithmetic;
    $08: EclVm.EclRandom;
    $09: EclVm.EclSave;
    $0A: EclVm.EclLoadCharacter;
    $0B: EclVm.EclLoadMonster;
    $0C: EclVm.EclSetupMonster;
    $0D: EclVm.EclApproach;
    $0E: EclVm.EclPicture;
    $0F: EclVm.EclInputNumber;
    $10: EclVm.EclInputString;
    $11, $12: EclVm.EclPrint;
    $13: EclVm.EclReturn;
    $14: EclVm.EclCompareAnd;
    $15: EclVm.EclVMenu;
    $16, $17, $18, $19, $1A, $1B: EclVm.EclIf;
    $1C: EclVm.EclClearMonsters;
    $1D: EclVm.EclPartyStrength;
    $1E: EclVm.EclCheckParty;
    $20: EclVm.EclNewEcl;
    $21, $37: EclVm.EclLoadFiles;
    $22: EclVm.EclPartySurprise;
    $23: EclVm.EclSurprise;
    $24: EclVm.EclCombat;
    $25, $26: EclVm.EclOnGoto;
    $27: EclVm.EclTreasure;
    $28: EclVm.EclRob;
    $29: EclVm.EclEncounter;
    $2A: EclVm.EclGetTable;
    $2B: EclVm.EclHMenu;
    $2C: EclVm.EclParlay;
    $2D: EclVm.EclCall;
    $2E: EclVm.EclDamage;
    $2F, $30: EclVm.EclAndOr;
    $31: EclVm.EclSpriteOff;
    $32: EclVm.EclFindItem;
    $33: EclVm.EclPrintReturn;
    $34: EclVm.EclClock;
    $35: EclVm.EclSaveTable;
    $36: EclVm.EclAddNpc;
    $38: EclVm.EclProgram;
    $39: EclVm.EclWho;
    $3A: EclVm.EclDelay;
    $3B: EclVm.EclSpell;
    $3C: EclVm.EclProtection;
    $3D: EclVm.EclClearBox;
    $3E: EclVm.EclDump;
    $3F: EclVm.EclFindSpecial;
    $40: EclVm.EclDestroyItems;
    $41: EclVm.EclAwardExperience
  end
end;

{ Runs ECL commands from an address until EXIT or the party is destroyed, logging each opcode to the debug trace.
  @param(address The script address to start at.) }
procedure CallEclScript(address: Word);
var
  { Unused in this version; see the other implementations of this routine. }
  commandCount: Byte;
begin
  GDVars.scratchIndex := 1;
  GDVars.eclIp := address;
  GDVars.eclStop := 0;
  while (GDVars.eclStop = 0) and (not GDVars.partyDefeated) do begin
    GDVars.previousOpcode := Boolean(GDVars.eclOpcode);
    GDVars.eclOpcode := GDVars.zone3^[GDVars.eclIp];
    EclVm.DispatchEclCommand;
    Debug.PrintDebug(Debug.OpcodeName(GDVars.eclOpcode), 0, 0, 0)
  end;
  GDVars.eclStop := 0
end;

{ Finishes a NEWECL: for each newly loaded block it frees the animation, forgets the saved picture, refreshes the cell
  event, clears the zone-1 leave-map word and runs the block's on-load entry script. If that loads no further block, it
  records the block as the last one entered, redraws the map view (when the view's files are loaded and the party has
  not just left the 3D view, or when it stays in the 3D view), runs two more of the block's entry scripts, then restores
  and redisplays the selected character. A NEWECL in any of those scripts repeats it for the next block. The interface
  state is remembered at the end. }
procedure NewEclDone;
begin
  repeat
    Portrait.FreeAnimation(GDVars.bigAnim);
    GDVars.savedPictureName[0] := #0;
    GDVars.savedPictureId := 255;
    GDVars.newEclFlag := 0;
    GDVars.mapState.event := View3D.GetMapEvent(GDVars.mapState.x, GDVars.mapState.y);
    GDVars.zone1^.leaveMap := 0;
    GDVars.savedChar := GDVars.curChar;
    EclVm.CallEclScript(GDVars.eclEntryPoints.initialEntry);
    if GDVars.newEclFlag = 0 then
      GDVars.zone0^.prevEcl := GDVars.curEclId;
    if GDVars.newEclFlag = 0 then begin
      if (((GDVars.previousLocationType <> C_Ifc.VIEW_3D) or (GDVars.interfaceState = C_Ifc.VIEW_3D)) and
          (GDVars.filesLoaded <> 0)) or
          ((GDVars.previousLocationType = C_Ifc.VIEW_3D) and (GDVars.interfaceState = C_Ifc.VIEW_3D)) then
        MapView.DisplayMapView;
      GDVars.newEclFlag := 0;
      EclVm.CallEclScript(GDVars.eclEntryPoints.vmRun);
      if GDVars.newEclFlag = 0 then begin
        EclVm.CallEclScript(GDVars.eclEntryPoints.searchLocation);
        if GDVars.newEclFlag = 0 then begin
          GDVars.curChar := GDVars.savedChar;
          CharHlp.DisplayParty(GDVars.curChar)
        end
      end
    end
  until GDVars.newEclFlag = 0;
  GDVars.previousLocationType := GDVars.interfaceState
end;

procedure GameLoop;
var
  cmd: Char;
  p: Types.PCharRecord;
begin
  GDVars.savedChar := GDVars.curChar;
  GDVars.pictureRedrawRequested := 1;
  GDVars.protShown := 0;
  GDVars.piecesLoaded := 0;
  GDVars.mapLoaded := 0;
  GDVars.restoreChar := 0;
  GDVars.filesLoaded := 0;
  GDVars.enteringLoop := 1;
  GDVars.interfaceState := C_Ifc.VIEW_3D;
  GDVars.newEclFlag := 0;
  if GDVars.zone0^.prevEcl = 0 then begin
    GDVars.enteringLoop := 0;
    if GDVars.demoFlag <> 0 then
      GDVars.curEclId := 57
    else begin
      GDVars.curEclId := 36;
      CharHlp.DisplayParty(GDVars.curChar);
    end
  end else
    GDVars.curEclId := Byte(GDVars.zone0^.prevEcl);
  if GDVars.zone0^.view3dFlag = 0 then
    GDVars.interfaceState := C_Ifc.OVERLAND;
  EclMenu.LoadEclScript(GDVars.curEclId);
  EclMenu.EclInit;
  EclVm.CallEclScript(GDVars.eclEntryPoints.initialEntry);
  if GDVars.demoFlag <> 0 then begin
    p := GDVars.partyHead;
    while p <> nil do begin
      GDVars.curChar := p;
      p := p^.next;
      CharGen.RemoveCreature(True, True)
    end
  end else begin
    if GDVars.newEclFlag = 0 then
      GDVars.zone0^.prevEcl := GDVars.curEclId
    else
      EclVm.NewEclDone;
    if (GDVars.interfaceState <> C_Ifc.OVERLAND) and (GDVars.loadedSave <> 0) then begin
      if GDVars.enteringLoop = 1 then
        CharHlp.DisplayNoncombatInterface;
      GDVars.pictureRedrawRequested := 1;
      MapView.DisplayMapView
    end;
    GDVars.loadedSave := 0;
    GDVars.extendedMode := 0;
    repeat
      cmd := Explore.MapMainMenu;
      GDVars.savedChar := GDVars.curChar;
      if GDVars.newEclFlag = 0 then
        GDVars.zone0^.prevEcl := GDVars.curEclId;
      while ((GDVars.zone1^.searchFlags > 1) or (UpCase(cmd) = 'E')) and (not GDVars.partyDefeated) do begin
        if UpCase(cmd) = 'E' then
        begin
          Camp.PrimeCamp;
          EclVm.EnterCamp
        end else begin
          GDVars.searchBackup := GDVars.zone1^.searchFlags and $01;
          GDVars.zone1^.searchFlags := 1;
          GDVars.pictureRedrawRequested := 1;
          MapView.DisplayMapView;
          EclVm.CallEclScript(GDVars.eclEntryPoints.searchLocation);
          if GDVars.newEclFlag <> 0 then
            EclVm.NewEclDone;
          GDVars.zone1^.searchFlags := GDVars.searchBackup
        end;
        if not GDVars.partyDefeated then begin
          cmd := Explore.MapMainMenu;
          GDVars.savedChar := GDVars.curChar
        end
      end;
      if not GDVars.partyDefeated then
        EclVm.CallEclScript(GDVars.eclEntryPoints.vmRun);
      if GDVars.newEclFlag <> 0 then
        EclVm.NewEclDone
      else if not GDVars.partyDefeated then begin
        GDVars.zone0^.prevX := GDVars.mapState.x;
        GDVars.zone0^.prevY := GDVars.mapState.y;
        Explore.ResolveMovement;
        MapView.DisplayMapView;
        if (GDVars.mapState.x <> GDVars.zone0^.prevX) or (GDVars.mapState.y <> GDVars.zone0^.prevY) then
          SoundDrv.SoundCommand(GDConsts.soundIds[6]);
        GDVars.eclGraphics := False;
        GDVars.pictureDrawn := 1;
        EclVm.CallEclScript(GDVars.eclEntryPoints.searchLocation);
        if GDVars.newEclFlag <> 0 then
          EclVm.NewEclDone
      end
    until GDVars.partyDefeated;
    GDVars.partyDefeated := False;
    p := GDVars.partyHead;
    while p <> nil do begin
      GDVars.curChar := p;
      p := p^.next;
      CharGen.RemoveCreature(False, True)
    end
  end
end;

begin
end.
